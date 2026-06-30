-- MemoNetwork Alpha 19.1 Admin Physgun
-- Allows authorized admins/owners to pick up players with the physgun.

MemoNetwork = MemoNetwork or {}
MemoNetwork.AdminPhysgun = MemoNetwork.AdminPhysgun or {}

local function HasPermission(ply, permission)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        local ok, allowed = pcall(MemoNetwork.Ranks.HasPermission, ply, permission)
        if ok and allowed then return true end
    end

    -- Safe fallback for servers where the rank permission is not loaded yet.
    return ply:IsSuperAdmin() or ply:IsAdmin()
end

local function CanPhysgunPlayer(ply, target)
    if not IsValid(ply) or not IsValid(target) then return false end
    if not ply:IsPlayer() or not target:IsPlayer() then return false end
    if ply == target then return false end

    return HasPermission(ply, "players.physgun") or HasPermission(ply, "players.manage")
end

hook.Add("PhysgunPickup", "MemoNetwork_AdminPhysgun_PlayerPickup", function(ply, ent)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    return CanPhysgunPlayer(ply, ent)
end)

hook.Add("PhysgunDrop", "MemoNetwork_AdminPhysgun_PlayerDrop", function(ply, ent)
    if not IsValid(ent) or not ent:IsPlayer() then return end

    -- Stop weird stuck velocity after dropping a player.
    timer.Simple(0, function()
        if IsValid(ent) then
            ent:SetVelocity(-ent:GetVelocity() * 0.65)
        end
    end)
end)

-- Optional anti-abuse: players cannot be punted with right click unless allowed.
hook.Add("PhysgunPickup", "MemoNetwork_AdminPhysgun_BlockUnauthorized", function(ply, ent)
    if IsValid(ent) and ent:IsPlayer() and not CanPhysgunPlayer(ply, ent) then
        return false
    end
end)

concommand.Add("mn_physgun_test", function(ply)
    if IsValid(ply) then
        local allowed = HasPermission(ply, "players.physgun") or HasPermission(ply, "players.manage")
        ply:ChatPrint("[MemoNetwork] Player physgun: " .. (allowed and "allowed" or "blocked"))
    else
        print("[MemoNetwork] mn_physgun_test is for players in-game.")
    end
end)
