-- MemoNetwork Lite Server Chat Commands

local responses = {
    ["!rules"] = "Rules: Be respectful, no griefing, and clean up your builds.",
    ["/rules"] = "Rules: Be respectful, no griefing, and clean up your builds.",
    ["!build"] = "Build Guide: Use Precision Tool, SmartSnap and Advanced Duplicator 2.",
    ["/build"] = "Build Guide: Use Precision Tool, SmartSnap and Advanced Duplicator 2.",
    ["!discord"] = "Discord: https://memocraft.nl/?c=Discord",
    ["/discord"] = "Discord: https://memocraft.nl/?c=Discord",
    ["!website"] = "Website: https://memocraft.nl",
    ["/website"] = "Website: https://memocraft.nl",
    ["!workshop"] = "Workshop: Coming soon.",
    ["/workshop"] = "Workshop: Coming soon."
}

hook.Add("PlayerSay", "MemoNetwork_ChatCommands", function(ply, text)
    local key = string.Trim(string.lower(text or ""))
    local response = responses[key]

    if response then
        ply:ChatPrint("[MemoNetwork] " .. response)
        return ""
    end
end)
