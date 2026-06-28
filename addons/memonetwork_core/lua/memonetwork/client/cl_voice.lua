-- MemoNetwork Lite Voice HUD
-- Restored polished voice HUD with settings and rank display.

local speakers = {}

local function ModuleEnabled(name)
    return not MemoNetwork.Modules or MemoNetwork.Modules:IsEnabled(name)
end

local function Setting(key, fallback)
    if MemoNetwork.Settings and MemoNetwork.Settings.Get then
        return MemoNetwork.Settings.Get(key)
    end

    return fallback
end

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
    if not ModuleEnabled("VoiceHUD") then return end
    if not Setting("voice", true) then return end

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
    local x, y = sw - 280, 90
    local w = 250
    local rowH = 42
    local h = 40 + (#active * rowH)

    draw.RoundedBox(10, x, y, w, h, theme.Background)
    draw.RoundedBoxEx(10, x, y, w, 32, theme.Orange, true, true, false, false)
    draw.SimpleText("VOICE", "MN_Subtitle", x + 14, y + 16, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    for i, ply in ipairs(active) do
        local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = theme.Muted}
        local rowY = y + 40 + ((i - 1) * rowH)

        draw.RoundedBox(6, x + 12, rowY, w - 24, rowH - 6, theme.PanelLight)
        draw.RoundedBox(4, x + 22, rowY + 11, 8, 16, rank.color or theme.Orange)
        draw.SimpleText(ply:Nick(), "MN_Text", x + 42, rowY + 13, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Small", x + 42, rowY + 31, rank.color or theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end)
