-- MemoNetwork Lite Admin Tools
-- Small owner/admin action system for a private Sandbox server.

util.AddNetworkString("MemoNetwork_AdminAction")
util.AddNetworkString("MemoNetwork_AdminResult")

local function IsAllowed(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if MemoNetwork and MemoNetwork.Ranks and MemoNetwork.Ranks.CanAdmin then
        return MemoNetwork.Ranks.CanAdmin(ply)
    end
    return ply:IsAdmin()
end

local function SendResult(ply, message, kind)
    net.Start("MemoNetwork_AdminResult")
        net.WriteString(message or "")
        net.WriteString(kind or "info")
    net.Send(ply)
end

net.Receive("MemoNetwork_AdminAction", function(_, ply)
    if not IsAllowed(ply) then
        SendResult(ply, "You do not have permission.", "error")
        return
    end

    local action = net.ReadString()

    if action == "cleanup" then
        game.CleanUpMap(false)
        SendResult(ply, "Map cleanup completed.", "success")
    elseif action == "god" then
        if ply:HasGodMode() then
            ply:GodDisable()
            SendResult(ply, "God mode disabled.", "warning")
        else
            ply:GodEnable()
            SendResult(ply, "God mode enabled.", "success")
        end
    elseif action == "noclip" then
        if ply:GetMoveType() == MOVETYPE_NOCLIP then
            ply:SetMoveType(MOVETYPE_WALK)
            SendResult(ply, "Noclip disabled.", "warning")
        else
            ply:SetMoveType(MOVETYPE_NOCLIP)
            SendResult(ply, "Noclip enabled.", "success")
        end
    elseif action == "health" then
        ply:SetHealth(100)
        ply:SetArmor(100)
        SendResult(ply, "Health and armor restored.", "success")
    else
        SendResult(ply, "Unknown admin action.", "error")
    end
end)
