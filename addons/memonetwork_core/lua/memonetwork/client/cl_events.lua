-- MemoNetwork Lite Client Events
-- Displays join/leave notifications.

net.Receive("MemoNetwork_PlayerEvent", function()
    local kind = net.ReadString()
    local name = net.ReadString()
    local rank = net.ReadString()

    if not MemoNetwork.Notify then return end

    if kind == "join" then
        if rank == "OWNER" then
            MemoNetwork.Notify(name .. " joined as OWNER", "success", "Player Joined", 4)
        else
            MemoNetwork.Notify(name .. " joined the server", "info", "Player Joined", 4)
        end
    elseif kind == "leave" then
        MemoNetwork.Notify(name .. " left the server", "warning", "Player Left", 3)
    end
end)
