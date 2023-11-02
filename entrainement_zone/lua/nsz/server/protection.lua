-- This file is responsible for making sure no damage is done in safe zones.
util.AddNetworkString("DrawWinLoseMenu")

-- Block all damage
hook.Add( "EntityTakeDamage", "NoDieInside", function(targ, damage) 
    local attacker = damage:GetAttacker()
    local DamageCount = damage:GetDamage()
    local TargetHealth = targ:Health()
    local TargetNewHealth = TargetHealth - DamageCount

    -- Attacker is still in the zone, but shooting a weapon
    if IsValid(attacker) and attacker.IsWeapon and attacker:IsWeapon() then
        attacker = attacker.Owner
        if isentity(attacker) and attacker:IsPlayer() then
            if istable(nsz.cache[attacker:SteamID()]) then
                return true
            end
        end
    end

    -- Check if target and attacker are in zone
    if IsValid(attacker) and attacker:IsPlayer() then
        if IsValid(targ) and targ:IsPlayer() then
            if istable(nsz.cache[targ:SteamID()]) and istable(nsz.cache[attacker:SteamID()]) then
                for zone, _ in pairs(nsz.cache[targ:SteamID()]) do
                    if TargetNewHealth <= 10 then
                        return true, BouncePlayers(targ, attacker)
                    end
                end
            end
        end
    end
end)

function BouncePlayers(targ, attacker)
    -- Heals and Bounce Both Players
    if IsValid(targ) and targ:IsPlayer() then
        net.Start( "DrawWinLoseMenu" )
            net.WriteString("Looser")
        net.Send(targ)
        targ:SetHealth( targ:GetMaxHealth() )

        local newpos = ( attacker:GetPos() - targ:GetPos() )
		newpos = newpos / newpos:Length()
		targ:SetVelocity( newpos*-200 + Vector( 0, 0, 325 ) )
    end

    if IsValid(attacker) and attacker:IsPlayer() then
        net.Start( "DrawWinLoseMenu" )
            net.WriteString("Winner")
        net.Send(attacker)
        attacker:SetHealth( attacker:GetMaxHealth() )
        
        local newpos = ( targ:GetPos() - attacker:GetPos() )
		newpos = newpos / newpos:Length()
		attacker:SetVelocity( newpos*-200 + Vector( 0, 0, 325 ) )
    end
end