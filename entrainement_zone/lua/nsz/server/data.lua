-- Networking string for saving a new zone
util.AddNetworkString("train_zone_upload") -- Used when a player uploads coords to be a safezone
util.AddNetworkString("train_zone_download") -- Sends zones to the player so they can view the safezones with `nsz_toggle_zones`

-- Create the data files
if not file.Exists("entrainement_zone", "DATA") then
    file.CreateDir("entrainement_zone")
    file.CreateDir("entrainement_zone/zones")
end

-- As the name implies, it saves all the zones on the map
function nsz:SaveZones()
    if not istable(nsz.trainzones) then return end

    file.Write("entrainement_zone/zones/" .. game.GetMap() .. ".txt", util.TableToJSON(nsz.trainzones))
end

-- This sends all the zones to everybody, or the player specified in the first argument
-- nsz:SendZones(Player ply)
--     Player ply - the player to send the zones to. Leave blank to send to all.
function nsz:SendZones(ply)
    net.Start("train_zone_download")
        net.WriteTable(nsz.trainzones or {})
        net.WriteTable(nsz.trainzonestypes or {})
    if IsValid(ply) and ply.IsPlayer and ply:IsPlayer() then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Auto refresh zones to the client every minute
timer.Create("nsz_refresh", 60, 0, function()
    nsz:SendZones()
end)

-- Loading data
local zones = file.Read("entrainement_zone/zones/" .. game.GetMap() .. ".txt")
if zones then
    nsz.trainzones = util.JSONToTable(zones) or {}
else
    nsz.trainzones = nsz.trainzones or {}
end

-- Player creating a zone
net.Receive("train_zone_upload", function(len, ply)
    local zone = net.ReadTable()

    -- First check if they have permission
    local can = ply:IsSuperAdmin() -- Default behavior is to let superadmins manage zones

    if not can then
        ply:ChatPrint("Erreur: Vous n’avez pas la permission de créer des zones.")
        return
    end

    if not isstring(zone.type) then -- They didn't send a string for the zone type
        ply:ChatPrint("Erreur: Vous avez besoin d’un type de zone.")
        return
    end

    if not istable(zone.points) then -- They didn't send valid corners for the zone
        ply:ChatPrint("Erreur: Vous avez besoin de deux positions pour une zone d'entrainement")
        return
    end

    -- The corners of the zone aren't Vectors
    if not isvector(zone.points[1]) or not isvector(zone.points[2]) then
        ply:ChatPrint("Erreur: Vous avez besoin de deux positions pour une zone d'entrainement.")
        return
    end


    -- Corners are used for detection, points are used for rendering
    zone.corners = {}
    local c = (zone.points[1] + zone.points[2]) / 2
    local s = (zone.points[2] - zone.points[1]) / 2

    table.insert(zone.corners, Vector(c[1] + s[1], c[2] + s[2], c[3] + s[3]))
    table.insert(zone.corners, Vector(c[1] - s[1], c[2] + s[2], c[3] + s[3]))
    table.insert(zone.corners, Vector(c[1] + s[1], c[2] - s[2], c[3] + s[3]))
    table.insert(zone.corners, Vector(c[1] - s[1], c[2] - s[2], c[3] + s[3]))
    table.insert(zone.corners, Vector(c[1] + s[1], c[2] + s[2], c[3] - s[3]))
    table.insert(zone.corners, Vector(c[1] - s[1], c[2] + s[2], c[3] - s[3]))
    table.insert(zone.corners, Vector(c[1] + s[1], c[2] - s[2], c[3] - s[3]))
    table.insert(zone.corners, Vector(c[1] - s[1], c[2] - s[2], c[3] - s[3]))

    table.insert(nsz.trainzones, zone)
    --ply:ChatPrint("NSZ: Success!")
    nsz:SendZones()
    nsz:SaveZones()
end)

hook.Add("PlayerInitialSpawn", "nsz_send_zones", function(ply)
    nsz:SendZones(ply)
end)
