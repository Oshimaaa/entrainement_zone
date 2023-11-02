-- This network string is used for the clientside delete safe zone
util.AddNetworkString("train_zone_delete")

net.Receive("train_zone_delete", function(len, ply)
    local str = net.ReadString()
    if not ply:IsSuperAdmin() then ply:ChatPrint("Erreur: Vous devez être SA pour supprimer une zone.") return end

    if #nsz.trainzones == 0 then ply:ChatPrint("Erreur: Il n’y a pas de zones à supprimer sur cette carte.") return end

    local args = string.Explode(" +", str, true)
    if #args == 0 then
        ply:ChatPrint("Erreur: Vous avez besoin d’au moins un argument.")
        return
    end

    args[1] = string.lower(args[1])
    if args[1] == "all" then
        local deleted = #nsz.trainzones
        nsz.trainzones = {}
        nsz:SendZones()
        nsz:SaveZones()

        ply:ChatPrint("Suppression de " .. deleted .. " zones.")
        return
    else
        local zone = tonumber(args[1])
        if isnumber(zone) then
            if not istable(nsz.trainzones[zone]) then ply:ChatPrint("Erreur: Cette zone n’existe pas.") return end

            table.remove(nsz.trainzones, zone)
            nsz:SaveZones()
            nsz:SendZones()

            ply:ChatPrint("Zone " .. tostring(zone) .. " supprimée.")
        else
            local typ = args[1]

            local deleted = 0
            for i = #nsz.trainzones, 1, -1 do
                if nsz.trainzones[i].type == typ then
                    deleted = deleted + 1
                    table.remove(nsz.trainzones, i)
                end
            end
            nsz:SaveZones()
            nsz:SendZones()

            ply:ChatPrint("Removed " .. deleted .. " " .. typ .. " zones.")
        end
    end
end)

-- Convar for sensitivity
if not ConVarExists("nsz_aabb_v_sat_sensitivity") then
    CreateConVar("nsz_aabb_v_sat_sensitivity", 10, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The angle of which determines weather or not to use AABB vs SAT detection. 0 = always use SAT (slow, but accurate), 90 = always use AABB (fast, but has false positives)", 0, 90)
end
