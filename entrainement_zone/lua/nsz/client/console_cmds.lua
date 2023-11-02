-- Convars for the HUD
if not ConVarExists("show_zones") then
    CreateClientConVar("show_zones", 0, true, false, "Permet de déboguer et vous permet de voir des zones peu importe où vous vous trouvez.", 0, 1)
end

concommand.Add("delete_zone", function(ply, cmd, args, argStr)
    net.Start("train_zone_delete")
        net.WriteString(argStr)
    net.SendToServer()
end)

-- This is when the server sends zones to the client
net.Receive("train_zone_download", function()
    nsz.trainzones = net.ReadTable()
    nsz.trainzonestypes = net.ReadTable()
end)
