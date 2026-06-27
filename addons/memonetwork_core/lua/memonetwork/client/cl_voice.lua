-- MemoNetwork Lite Voice HUD

local speakers = {}

hook.Add("PlayerStartVoice", "MemoNetwork_VoiceStart", function(ply)
    if IsValid(ply) and ply:IsPlayer() then
        speakers[ply] = true
    end

    return true
end)

hook.Add("PlayerEndVoice", "MemoNetwork_VoiceEnd", function(ply)
    if IsValid(ply) and ply:IsPlayer() then
        speakers[ply] = nil
    end

    return true
end)

hook.Add("HUDShouldDraw", "MemoNetwork_HideDefaultVoice", function(name)
    if name == "CHudVoiceStatus" then
        return false
    end
end)

hook.Add("InitPostEntity", "MemoNetwork_DisableDefaultVoicePanel", function()
    timer.Simple(1, function()
        if GAMEMODE then
            function GAMEMODE:PlayerStartVoice(ply) return true end
            function GAMEMODE:PlayerEndVoice(ply) return true end
        end
    end)
end)

hook.Add("HUDPaint", "MemoNetwork_VoiceHUD", function()
    local active = {}

    for ply in pairs(speakers) do
        if IsValid(ply) and ply:IsPlayer() and ply:IsSpeaking() then
            active[#active + 1] = ply
        else
            speakers[ply] = nil
        end
    end

    if #active == 0 then return end

    local theme = MemoNetwork.Theme
    local sw = ScrW()
    local x, y = sw - 260, 90
    local w = 230
    local h = 40 + (#active * 28)

    draw.RoundedBox(10, x, y, w, h, theme.Background)
    draw.RoundedBoxEx(10, x, y, w, 32, theme.Orange, true, true, false, false)
    draw.SimpleText("VOICE", "MN_Subtitle", x + 14, y + 16, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    for i, ply in ipairs(active) do
        local rowY = y + 40 + ((i - 1) * 28)
        draw.RoundedBox(6, x + 12, rowY, w - 24, 22, theme.PanelLight)
        draw.RoundedBox(4, x + 22, rowY + 7, 8, 8, theme.Orange)
        draw.SimpleText(ply:Nick(), "MN_Text", x + 42, rowY + 11, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end)
