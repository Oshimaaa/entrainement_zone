AddCSLuaFile();	
if SERVER then	
    nsz = nsz or {}
    nsz.trainzones = nsz.trainzones or {}
    nsz.trainzonestypes = nsz.trainzonestypes or {}
	// CL
	AddCSLuaFile("nsz/client/console_cmds.lua")
    AddCSLuaFile("nsz/client/hud.lua")
	// SV
	include("nsz/server/concmds.lua")
    include("nsz/server/data.lua")
    include("nsz/server/detection.lua")
    include("nsz/server/protection.lua")
    include("nsz/server/registration.lua")

elseif CLIENT then
    nsz = nsz or {}
    nsz.currentTrainZone = nsz.currentTrainZone or {}
    nsz.trainzonestypes = nsz.trainzonestypes or {}
    nsz.trainzones = nsz.trainzones or {}
	// CL
	include("nsz/client/console_cmds.lua")
    include("nsz/client/hud.lua")
end