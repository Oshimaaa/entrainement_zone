-- This file is responsible for checking if players are in a safe zone
-- and running the NSZEnter and NSZLeave hooks

-- Following functions were copied from wiremod's expression 2 functions
local function cross(v1, v2)
    return Vector(
		v1[2] * v2[3] - v1[3] * v2[2],
		v1[3] * v2[1] - v1[1] * v2[3],
		v1[1] * v2[2] - v1[2] * v2[1]
	)
end
local function dot(v1, v2)
    return v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3]
end

-- Debugging
local times = {}
local checked = 0
local scans = 0
--[[util.AddNetworkString("train_zone_check") -- Used in the client cvar "nsz_show_zones", debug of the time it took to scan entities

timer.Create("nsz_check_times", 0.5, 0, function()
    -- Find the average time it took to scan
    local av = 0
    for i, t in ipairs(times) do
        av = av + t
    end
    av = av / #times

    -- Send the average to the client as well as how many scans it did
    net.Start("train_zone_check", true)
        net.WriteFloat(av)
        net.WriteString(tostring(checked) .. "/" .. tostring(scans))
    net.Broadcast()

    -- Reset the times and scans count
    times = {}
    checked = 0
    scans = 0
end)]]

-- This function returns what zones something is located in
-- nsz:InZone(ent, filter)
--     * Vector/Entity/Player ent: What to check
--         Vector: checks if this point is located in a zone
--         Entity/Player: Checks if the entity is in the zone by factoring its hitbox
--
--     string/table filter: Zones to include in the scan
--         string: Only checks if ent is in this zone
--         table: Checks if ent is in any of these zones
--
--     Returns: A table of zones that it is in.
function nsz:InZone(ent, filter)
    if not (isentity(ent) or isvector(ent)) then return end

    if not istable(nsz.trainzones) then return false end -- Somehow the zones table was removed or never registered
    if #nsz.trainzones == 0 then return false end -- No zones exist, so it can't be in a zone

    local zones = {}

    for i, zone in ipairs(nsz.trainzones) do
        -- No need to check this zone if it's already in a zone of this type
        if table.HasValue(zones, zone.type) then continue end

        if not istable(zone.points) then continue end -- Somehow the two defining corners don't exist
        if not (isvector(zone.points[1]) or isvector(zone.points[2])) then continue end -- Invalid points
        local p1, p2 = zone.points[1], zone.points[2]

        if isstring(filter) then
            if zone.type ~= typ then continue end
        elseif istable(filer) and table.IsSequential(filter) then
            if not table.HasValue(filter, zone.type) then continue end
        end

        if isvector(ent) then
            if ent:WithinAABox(p1, p2) then
                if not table.HasValue(zones, zone.type) then table.insert(zones, zone.type) end
            end
            continue
        end

        if isentity(ent) then
            if ent:GetPos():WithinAABox(p1, p2) or ent:LocalToWorld(ent:OBBCenter()):WithinAABox(p1, p2) then
                if not table.HasValue(zones, zone.type) then table.insert(zones, zone.type) end
                continue
            end

            local zoneCenter = (p1 + p2) / 2
            local sqrDist = zoneCenter:DistToSqr(ent:LocalToWorld(ent:OBBCenter()))
            local maxDist = (p2 - zoneCenter + (ent:OBBMaxs() - ent:OBBCenter())):LengthSqr()
            if sqrDist > maxDist then continue end

            -- All detection code beyond this point was made with the help of a friend

            local threshold = GetConVar("nsz_aabb_v_sat_sensitivity"):GetInt()
            local ang = ent:GetAngles()
            local useAABB = true
            for i = 1, 3 do
                if(math.abs(((ang[i] + 45) % 90) - 45) > threshold) then
                    useAABB = false
                    break
                end
            end

            if useAABB then -- AABB detection
                local min, max = ent:WorldSpaceAABB()
                local inzone = {}

                for i = 1, 3 do
                    inzone[i] =                       (min[i] < p1[i] and max[i] > p2[i])     -- Enveloping the zone
                    if not inzone[i] then inzone[i] = (min[i] < p2[i] and max[i] > p2[i]) end -- Touching the zone
                    if not inzone[i] then inzone[i] = (min[i] > p1[i] and max[i] < p2[i]) end -- Enveloped in the zone
                    if not inzone[i] then inzone[i] = (min[i] < p1[i] and max[i] > p1[i]) end -- Touching the zone
                end

                if inzone[1] and inzone[2] and inzone[3] then
                    if not table.HasValue(zones, zone.type) then table.insert(zones, zone.type) end
                    continue
                end
            else -- SAT (Separating Axis Theorem) detection
                if not istable(ent.nsz_scan) then
                    ent.nsz_scan = {corners = {}}

                    local c = ent:OBBCenter() -- Center of the end
                    local s = (ent:OBBMaxs() - ent:OBBMins()) / 2 -- Size of the ent
                    ent.nsz_scan.corners[1] = ent:LocalToWorld(Vector(c[1] + s[1], c[2] + s[2], c[3] + s[3]))
                    ent.nsz_scan.corners[2] = ent:LocalToWorld(Vector(c[1] - s[1], c[2] + s[2], c[3] + s[3]))
                    ent.nsz_scan.corners[3] = ent:LocalToWorld(Vector(c[1] + s[1], c[2] - s[2], c[3] + s[3]))
                    ent.nsz_scan.corners[4] = ent:LocalToWorld(Vector(c[1] - s[1], c[2] - s[2], c[3] + s[3]))
                    ent.nsz_scan.corners[5] = ent:LocalToWorld(Vector(c[1] + s[1], c[2] + s[2], c[3] - s[3]))
                    ent.nsz_scan.corners[6] = ent:LocalToWorld(Vector(c[1] - s[1], c[2] + s[2], c[3] - s[3]))
                    ent.nsz_scan.corners[7] = ent:LocalToWorld(Vector(c[1] + s[1], c[2] - s[2], c[3] - s[3]))
                    ent.nsz_scan.corners[8] = ent:LocalToWorld(Vector(c[1] - s[1], c[2] - s[2], c[3] - s[3]))

                    -- This is used for SAT (Separating Axis Theorem) detection
                    ent.nsz_scan.axes = {
                        -- Normals
                        Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1),
                        ent:GetForward(), ent:GetRight(), ent:GetUp(),
                        -- Crosses
                        cross(ent:GetForward(), Vector(1, 0, 0)), cross(ent:GetRight(), Vector(1, 0, 0)), cross(ent:GetUp(), Vector(1, 0, 0)),
                        cross(ent:GetForward(), Vector(0, 1, 0)), cross(ent:GetRight(), Vector(0, 1, 0)), cross(ent:GetUp(), Vector(0, 1, 0)),
                        cross(ent:GetForward(), Vector(0, 0, 1)), cross(ent:GetRight(), Vector(0, 0, 1)), cross(ent:GetUp(), Vector(0, 0, 1))
                    }
                end

                local inzone = true

                local corners = ent.nsz_scan.corners
                local axes = ent.nsz_scan.axes

                for x = 1, #axes do
                    local minA = math.huge
                    local maxA = -math.huge
                    local minB = math.huge
                    local maxB = -math.huge

                    for y = 1, 8 do
                        local p = dot(corners[y], axes[x])
                        minA = math.min(minA, p)
                        maxA = math.max(maxA, p)

                        p = dot(zone.corners[y], axes[x])
                        minB = math.min(minB, p)
                        maxB = math.max(maxB, p)
                    end

                    if maxA < minB then
                        inzone = false
                        break
                    end

                    if minA > maxB then
                        inzone = false
                        break
                    end
                end

                if inzone and not table.HasValue(zones, zone.type) then
                    table.insert(zones, zone.type)
                end
            end

            ent.nsz_scan = nil -- Remove the scan data since we want to refresh it next check.
        end
    end

    return zones
end

nsz.cache = {}
hook.Add("Think", "nsz_hooks", function()
    -- We don't want to loop anything if no zone exists
    if #nsz.trainzones == 0 then return end

    -- Used for nsz_show_zones debug
    local start = SysTime()

    -- Loop through all the players
    for i, ply in ipairs(player.GetAll()) do
        scans = scans + 1
        if not istable(nsz.cache[ply:SteamID()]) then nsz.cache[ply:SteamID()] = {} end

        -- Check if a player isn't moving (probably not needed tbh, over-optimization)
        local pos = {ply:GetPos()}
        if ply.nsz_lastPos == pos then continue end
        ply.nsz_lastPos = pos

        checked = checked + 1
        -- Check if they are in any zone and run if they're not in the cache
        local zones = nsz:InZone(ply)
        for id, info in pairs(nsz.trainzonestypes) do -- Loop through all the regisered zones
            if not istable(info) then continue end -- Invalid zone somewhow

            if table.HasValue(zones, info.type) and not nsz.cache[ply:SteamID()][info.type] then
                -- This is the hook you use to change the behavior of entering
                -- zones. Return true to allow, false to disallow
                --[[local allow = hook.Run("EntityZoneEnter", ply, info.type)
                if isbool(allow) then
                    ply:SetNWBool("nsz_in_zone_" .. info.type, allow)
                else
                    ply:SetNWBool("nsz_in_zone_" .. info.type, true)
                end]]

                nsz.cache[ply:SteamID()][info.type] = true
            elseif not table.HasValue(zones, info.type) and nsz.cache[ply:SteamID()][info.type] then
                --[[hook.Run("EntityZoneLeave", ply, info.type)

                ply:SetNWBool("nsz_in_zone_" .. info.type, false)]]
                nsz.cache[ply:SteamID()][info.type] = nil
            end
        end
    end

    local fin = SysTime()
    table.insert(times, fin - start)
end)