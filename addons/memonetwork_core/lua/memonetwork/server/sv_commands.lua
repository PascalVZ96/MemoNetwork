-- MemoNetwork Lite Server Chat Commands
-- Adds clickable/openable links through a client net message.

util.AddNetworkString("MemoNetwork_OpenURL")

local links = {
    ["!discord"] = "https://memocraft.nl/?c=Discord",
    ["/discord"] = "https://memocraft.nl/?c=Discord",
    ["!website"] = "https://memocraft.nl",
    ["/website"] = "https://memocraft.nl"
}

local responses = {
    ["!rules"] = "Rules: Be respectful, no griefing, and clean up your builds.",
    ["/rules"] = "Rules: Be respectful, no griefing, and clean up your builds.",
    ["!build"] = "Build Guide: Use Precision Tool, SmartSnap and Advanced Duplicator 2.",
    ["/build"] = "Build Guide: Use Precision Tool, SmartSnap and Advanced Duplicator 2.",
    ["!workshop"] = "Workshop: Coming soon.",
    ["/workshop"] = "Workshop: Coming soon."
}

hook.Add("PlayerSay", "MemoNetwork_ChatCommands", function(ply, text)
    local key = string.Trim(string.lower(text or ""))

    if links[key] then
        ply:ChatPrint("[MemoNetwork] Opening: " .. links[key])

        net.Start("MemoNetwork_OpenURL")
            net.WriteString(links[key])
        net.Send(ply)

        return ""
    end

    local response = responses[key]
    if response then
        ply:ChatPrint("[MemoNetwork] " .. response)
        return ""
    end
end)
