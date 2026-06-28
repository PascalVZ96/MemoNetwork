-- MemoNetwork Lite HUD
-- Alpha 10 restored from latest polished UI: rank, settings and no overflow.

hook.Add("HUDShouldDraw", "MemoNetwork_HideDefaultHUD", function(name)
    local hidden = {
        CHudHealth = true,
        CHudBattery = true
    }

    if hidden[name] then return false end
end)

local smoothHealth = 100
local smoothArmor = 0

local function ModuleEnabled(name)
    return not MemoNetwork.Modules or MemoNetwork.Modules:IsEnabled(name)
end

local function Setting(key, fallback)
    if MemoNetwork.Settings and MemoNetwork.Settings.Get then
        return MemoNetwork.Settings.Get(key)
    end

    return fallback
end

local function FitText(text, font, maxWidth)
    text = tostring(text or "")
    surface.SetFont(font)

    if surface.GetTextSize(text) <= maxWidth then return text end

    local suffix = "..."
    local suffixW = surface.GetTextSize(suffix)

    for i = #text, 1, -1 do
        local part = string.sub(text, 1, i)
        if surface.GetTextSize(part) + suffixW <= maxWidth then
            return part .. suffix
        end
    end

    return suffix
end

local function DrawBar(x, y, w, h, frac, color)
    frac = math.Clamp(frac, 0, 1)
    draw.RoundedBox(5, x, y, w, h, Color(35, 42, 52, 230))
    draw.RoundedBox(5, x, y, w * frac, h, color)
end

hook.Add("HUDPaint", "MemoNetwork_HUD", function()
    if not ModuleEnabled("HUD") then return end
    if not Setting("hud", true) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or cfg.DefaultRank

    local hp = math.max(ply:Health(), 0)
    local armor = math.max(ply:Armor(), 0)

    smoothHealth = Lerp(FrameTime() * 8, smoothHealth, hp)
    smoothArmor = Lerp(FrameTime() * 8, smoothArmor, armor)

    local x, y = 24, 24
    local w, h = 390, 260
    local pad = 18

    draw.RoundedBox(12, x, y, w, h, theme.Background)
    draw.RoundedBoxEx(12, x, y, w, 42, theme.Orange, true, true, false, false)

    draw.SimpleText(cfg.ServerName, "MN_Title", x + pad, y + 21, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if cfg.ShowFPS and Setting("fps", true) then
        draw.SimpleText(math.floor(1 / FrameTime()) .. " FPS", "MN_Small", x + w - pad, y + 22, Color(10, 10, 10), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local cy = y + 58

    draw.SimpleText("Health", "MN_Text", x + pad, cy, theme.Text, TEXT_ALIGN_LEFT)
    draw.SimpleText(tostring(hp), "MN_Text", x + w - pad, cy, theme.Text, TEXT_ALIGN_RIGHT)
    DrawBar(x + pad, cy + 24, w - pad * 2, 10, smoothHealth / 100, theme.Health)

    cy = cy + 52

    draw.SimpleText("Armor", "MN_Text", x + pad, cy, theme.Text, TEXT_ALIGN_LEFT)
    draw.SimpleText(tostring(armor), "MN_Text", x + w - pad, cy, theme.Text, TEXT_ALIGN_RIGHT)
    DrawBar(x + pad, cy + 24, w - pad * 2, 10, smoothArmor / 100, theme.Armor)

    local boxX = x + pad
    local boxY = y + 168
    local boxW = w - pad * 2
    local boxH = 74

    draw.RoundedBox(8, boxX, boxY, boxW, boxH, theme.PanelLight)

    local rightText = ""

    if cfg.ShowPing and Setting("ping", true) then
        rightText = ply:Ping() .. " ms"
    end

    if cfg.ShowPlayers and Setting("players", true) then
        if rightText ~= "" then rightText = rightText .. "  |  " end
        rightText = rightText .. #player.GetAll() .. "/" .. game.MaxPlayers()
    end

    local rightWidth = 128
    local leftMaxWidth = boxW - rightWidth - 26

    draw.SimpleText(FitText(ply:Nick(), "MN_Text", leftMaxWidth), "MN_Text", boxX + 12, boxY + 17, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(rank.name or "PLAYER", "MN_Small", boxX + 12, boxY + 38, rank.color or theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(FitText(game.GetMap(), "MN_Small", leftMaxWidth), "MN_Small", boxX + 12, boxY + 58, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(rightText, "MN_Small", boxX + boxW - 12, boxY + 58, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
