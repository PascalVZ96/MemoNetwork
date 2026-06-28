-- MemoNetwork Lite Server Events
-- Sends join/leave events to clients for notifications.

util.AddNetworkString("MemoNetwork_PlayerEvent")

local function BroadcastEvent(kind, plyName, rankName)
    net.Start("MemoNetwork_PlayerEvent")
        net.WriteString(kind)
        net.WriteString(plyName or "Unknown")
        net.WriteString(rankName or "PLAYER")
    net.Broadcast()
end

hook.Add("PlayerInitialSpawn", "MemoNetwork_Event_PlayerJoin", function(ply)
    timer.Simple(1.5, function()
        if not IsValid(ply) then return end

        local rank = "PLAYER"

        if MemoNetwork and MemoNetwork.Ranks and MemoNetwork.Ranks.GetName then
            rank = MemoNetwork.Ranks.GetName(ply)
        elseif ply:IsAdmin() then
            rank = "ADMIN"
        end

        BroadcastEvent("join", ply:Nick(), rank)
    end)
end)

hook.Add("PlayerDisconnected", "MemoNetwork_Event_PlayerLeave", function(ply)
    BroadcastEvent("leave", ply:Nick(), "PLAYER")
end)
