-- Fonts
surface.CreateFont("nsz_large", {
    size = 24,
    weight = 500,
    antialias = true
})
surface.CreateFont("nsz_normal", {
    size = 16,
    weight = 500,
    antialias = true
})

surface.CreateFont("WinLooseTitle", {
    font = "Aero Matics",
    size = 52,
    weight = 500,
    antialias = true
})

surface.CreateFont("WinLooseTitle_glow", {
    font = "Aero Matics",
    size = 52,
    weight = 500,
    antialias = true,
    shadow = true,
    blursize = 5,
})

--------------------------------[[ Fonctions ]]------------------------------------
local function W(s)
    return ScrW() / 1920 * s
end
local function H(s)
    return ScrH() / 1080 * s
end
--------------------------------[[ Fonctions ]]------------------------------------

net.Receive("DrawWinLoseMenu", function( len, ply )
    Status = net.ReadString()

    if !IsValid(WinLoseMenu) then
        vgui.Create( "WinLoseFightMenu" )
    end
end)

-- Rendering the zones
hook.Add("PostDrawOpaqueRenderables", "nsz_render_zones", function()
    if GetConVar("show_zones"):GetInt() > 0 then
        for i, zone in ipairs(nsz.trainzones) do
            if not istable(zone.points) then continue end
            local p1, p2 = zone.points[1], zone.points[2]
            if not (isvector(p1) or isvector(p2)) then continue end

            local center = (p1 + p2)/2
            local min = Vector(
                math.abs(p1[1] - center[1]),
                math.abs(p1[2] - center[2]),
                math.abs(p1[3] - center[3])
            )
            local max = Vector(
                math.abs(p2[1] - center[1]),
                math.abs(p2[2] - center[2]),
                math.abs(p2[3] - center[3])
            )

            local col = Color(255, 255, 255)
            if istable(nsz.trainzonestypes[zone.type]) then
                local z = table.Copy(nsz.trainzonestypes[zone.type])
                if IsColor(z.color) then
                    col = z.color
                end
            end
            -- Wireframe box
            local ang = Angle(0, 0, 0)
            render.DrawWireframeBox(center, ang, -min, max, col)

            -- Colored box with the wireframe as a visible edge
            render.SetColorMaterial()
            render.DrawBox(center, ang, -min, max, Color(col.r, col.g, col.b, 15))

            if istable(zone.corners) then
                for x, p in ipairs(zone.corners) do
                    render.DrawWireframeSphere(p, 1, 10, 10, col)
                end
            end

            local dist = 500
            if LocalPlayer():GetPos():DistToSqr(center) > (dist * dist) then continue end

            local tr = {}
            tr.start = LocalPlayer():GetShootPos()
            tr.endpos = center
            tr.filter = LocalPlayer()
            local trace = util.TraceLine(tr)

            local angle = EyeAngles()
            if trace.HitWorld or trace.HitNonWorld then
                angle = trace.HitNormal:Angle()
                angle:RotateAroundAxis(angle:Up(), 90)
            else
                angle:RotateAroundAxis(angle:Up(), -90)
            end
            angle:RotateAroundAxis(angle:Forward(), 90)

            cam.Start3D2D(trace.HitPos, angle, 0.25)
                local text = "Terrain d'entraînement " .. tostring(i)
                local font = "Default"

                surface.SetFont(font)
                local tW, tH = surface.GetTextSize(text)

                local pad = 5

                surface.SetDrawColor(100, 100, 100, 255)
                surface.DrawRect(-tW / 2 - pad, -pad, tW + pad * 2, tH + pad * 2)

                draw.SimpleText(text, font, -tW / 2, 0, Color(255, 93, 0, 255) )
            cam.End3D2D()
        end
    end

    if not IsValid(LocalPlayer():GetActiveWeapon()) then return end
    local class = LocalPlayer():GetActiveWeapon():GetClass()
    if class == "train_zone_creator" and istable(nsz.currentTrainZone) then
        local zone = table.Copy(nsz.currentTrainZone)
        if not istable(zone.points) then return end
        if not isvector(zone.points[1]) then return end

        local dist = 100
        if input.IsKeyDown(KEY_LALT) then dist = 100000000 end

        local tr = {}
        tr.start = LocalPlayer():GetShootPos()
        tr.endpos = LocalPlayer():GetShootPos() + LocalPlayer():GetAimVector() * dist
        tr.filter = LocalPlayer()
        local trace = util.TraceLine(tr)

        if not isvector(trace.HitPos) then return end

        local center = (zone.points[1] + trace.HitPos)/2
        local min = Vector(
            math.abs(zone.points[1][1] - center[1]),
            math.abs(zone.points[1][2] - center[2]),
            math.abs(zone.points[1][3] - center[3])
        )
        local max = Vector(
            math.abs(trace.HitPos[1] - center[1]),
            math.abs(trace.HitPos[2] - center[2]),
            math.abs(trace.HitPos[3] - center[3])
        )

        local col = Color(255, 255, 255)
        local ang = Angle(0, 0, 0)
        if istable(nsz.trainzonestypes) and istable(nsz.trainzonestypes[zone.type]) then
            if IsColor(nsz.trainzonestypes[zone.type].color) then
                col = nsz.trainzonestypes[zone.type].color
            end
        end
        render.DrawWireframeBox(center, ang, -min, max, col)

        render.SetColorMaterial()
        render.DrawBox(center, ang, -min, max, Color(col.r, col.g, col.b, 15))
    end
end)


---==================
-- local BackMenu = Material("zone/menu_zone.png", "noclamp smooth")
local PANEL = {}
    function PANEL:Init()
        if (IsValid(WinLoseMenu)) then
            WinLoseMenu:Remove()
            WinLoseMenu:SetVisible(false)
        end

        WinLoseMenu = self
        self:SetSize(W(680), H(180))
        self:SetPos(ScrW()/2 - W(680)/2 - W(20), H(90) )
        self:SetTitle("")
		self:SetDraggable(false)
        self:ShowCloseButton(false)
        self:SetAlpha( 0 )
        self:AlphaTo(255, 0.5)
    end

    function PANEL:Paint(w, h)
        if Status == "Winner" then
            -- surface.SetDrawColor(Color(4, 250, 0 ))
            -- surface.SetMaterial(BackMenu)
            surface.DrawTexturedRect(0,0,w,h)
            draw.SimpleText( "Tu as gagné !", "WinLooseTitle_glow", self:GetWide()/2,  self:GetTall()/2 - 7, Color(4, 250, 0 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            draw.SimpleText( "Tu as gagné !", "WinLooseTitle", self:GetWide()/2,  self:GetTall()/2 - 7, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
        elseif Status == "Looser" then
            -- surface.SetDrawColor(Color(192, 57, 43))
            -- surface.SetMaterial(BackMenu)
            surface.DrawTexturedRect(0,0,w,h)
            draw.SimpleText( "Tu as perdu !", "WinLooseTitle_glow", self:GetWide()/2,  self:GetTall()/2 - 7, Color(192, 57, 43), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            draw.SimpleText( "Tu as perdu !", "WinLooseTitle", self:GetWide()/2,  self:GetTall()/2 - 7, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
        end
    end

    function PANEL:Think()
        if (!IsValid(WinLoseMenu)) then return end
        if (IsValid(WinLoseMenu)) then
            timer.Simple(2, function()
                if (IsValid(WinLoseMenu)) then
                    self:AlphaTo(0, 0.25, 0.5, function()
                        self:Remove()
                        self:SetVisible(false)
                    end)
                end
            end)
        end
    end
vgui.Register("WinLoseFightMenu", PANEL, "DFrame")