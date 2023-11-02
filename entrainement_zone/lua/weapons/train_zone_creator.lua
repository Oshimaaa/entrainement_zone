AddCSLuaFile()
nsz = nsz or {}
-- Setup of the weapon
SWEP.PrintName = "Zone d'entrainement"
SWEP.Category = "Entraînement"
SWEP.Author	   = ""
SWEP.Purpose   = ""

SWEP.Slot    = 0
SWEP.SlotPos = 4

SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.ViewModel    = Model("models/weapons/c_toolgun.mdl")
SWEP.WorldModel   = "models/weapons/w_toolgun.mdl"
SWEP.ViewModelFOV = 54

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.DrawAmmo = false
SWEP.UseHands = true

function SWEP:Initialize()
	if SERVER then
		-- Make sure the zones are updated
		nsz:SendZones(self.Owner)
	else
		-- For some reason, this runs on all clients, but we only want it to run
		-- on whoever got the zone creator
		if LocalPlayer() ~= self.Owner then return end

		LocalPlayer():ChatPrint("Clique gauche: Permet de créer un point")
		LocalPlayer():ChatPrint("Clique droit: Permet d'ouvrir le menu")
		LocalPlayer():ChatPrint("R: Permet de reset la zone en cours")
		LocalPlayer():ChatPrint("Alt + Clique gauche: Permet de créer le second point")

		if not istable(nsz.currentTrainZone) then
			nsz.currentTrainZone = {type = "", points = {}}
		end
		if not istable(nsz.currentTrainZone.points) then
			nsz.currentTrainZone.points = {}
		end
		nsz.currentTrainZone.type = ""
	end

	self:SetHoldType("pistol")
end

SWEP.nextPrimary = 0
function SWEP:PrimaryAttack()
	if CurTime() < self.nextPrimary then return end
	self.nextPrimary = CurTime() + 0.5

	if CLIENT then
		if LocalPlayer() ~= self.Owner then return end

		-- Make sure the zone information is correct
		if not istable(nsz.currentTrainZone) then
			nsz.currentTrainZone = {type = "", points = {}}
		end
		if not isstring(nsz.currentTrainZone.type) then
			nsz.currentTrainZone.type = ""
		end
		if not istable(nsz.currentTrainZone.points) then
			nsz.currentTrainZone.points = {}
		end

		-- Make sure they have the valid variables selected
		if not istable(nsz.trainzonestypes[nsz.currentTrainZone.type]) then
			LocalPlayer():ChatPrint("Erreur: Type de zone non valide sélectionné. Cliquer avec le bouton droit de la souris pour ouvrir le sélecteur")
			return
		end
		if not isstring(nsz.trainzonestypes[nsz.currentTrainZone.type].type) then -- This should never happen unless you mess with the zonetype table
			LocalPlayer():ChatPrint("Erreur: La zone que vous essayez de modifier n’est pas configurée correctement")
			return
		end

		local dist = 100000000
		if isvector(nsz.currentTrainZone.points[1]) and not input.IsKeyDown(KEY_LALT) then
			dist = 100
		end

		local tr = self.Owner:GetEyeTrace()
		tr.start = self.Owner:GetShootPos()
		tr.endpos = tr.start + self.Owner:GetAimVector() * dist
		tr.filter = self.Owner
		local trace = util.TraceLine(tr)

		if isvector(trace.HitPos) then
			table.insert(nsz.currentTrainZone.points, trace.HitPos)

			if #nsz.currentTrainZone.points == 2 then
				LocalPlayer():ChatPrint("La zone a bien été créee")
				net.Start("train_zone_upload")
					net.WriteTable(nsz.currentTrainZone)
				net.SendToServer()
				nsz.currentTrainZone.points = {}
			else
				LocalPlayer():ChatPrint("Point 1, cliquez ailleurs pour le deuxième point !")
			end
		else 
			LocalPlayer():ChatPrint("Erreur: Point non valide (impossible de localiser l’endroit où vous visez) !")
		end
	end
end

SWEP.nextReload = 0
function SWEP:Reload()
	if CurTime() < self.nextReload then return end
	self.nextReload = CurTime() + 0.5

	if CLIENT then
		if LocalPlayer() ~= self.Owner then return end

		nsz.currentTrainZone.points = {}
		chat.AddText("Réinitialisation de la zone actuelle !")
	end
end

SWEP.nextSecondary = 0
function SWEP:SecondaryAttack()
	if CurTime() < self.nextSecondary then return end
	self.nextSecondary = CurTime() + 1

	if CLIENT then
		if LocalPlayer() ~= self.Owner then return end

		local panel = vgui.Create("DFrame")
		panel:SetSize(ScrW()/5, 60)
		panel:Center()
		panel:SetTitle("Sélection de la zone")
		panel:SetSizable(false)
		panel:SetDraggable(false)
		panel:MakePopup()

		local dropdown = vgui.Create("DComboBox", panel)
		dropdown:SetPos(4, panel:GetTall() - 32)
		dropdown:SetSize(panel:GetWide() - 8, 28)
		dropdown:SetValue("Sélectionnez la zone souhaitée")
		for id, zone in pairs(nsz.trainzonestypes) do
			dropdown:AddChoice(zone.title .. " (" .. zone.type .. ")", zone.type)
		end
		function dropdown:OnSelect(index, value, data)
			nsz.currentTrainZone.type = data
			panel:Remove()
		end
	end
end
