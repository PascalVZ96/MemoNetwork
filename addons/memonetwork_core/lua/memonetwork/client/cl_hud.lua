-- MemoNetwork Lite HUD

hook.Add("HUDShouldDraw", "MemoNetwork_HideDefaultHUD", function(name)
    local hidden = {
        CHudHealth = true,
        CHudBattery = true
    }

    if hidden[name] then return false end
end)

local smoothHealth = 100
local smoothArmor = 0

local function DrawBar(x, y, w, h, frac, color)
    frac = math.Clamp(frac, 0, 1)

    draw.RoundedBox(5, x, y, w, h, Color(35, 42, 52, 230))
    draw.RoundedBox(5, x, y, w * frac, h, color)
end

hook.Add("HUDPaint", "MemoNetwork_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config

    local hp = math.max(ply:Health(), 0)
    local armor = math.max(ply:Armor(), 0)

    smoothHealth = Lerp(FrameTime() * 8, smoothHealth, hp)
    smoothArmor = Lerp(FrameTime() * 8, smoothArmor, armor)

    local x, y = 24, 24
    local w, h = 330, 190
    local pad = 18

    draw.RoundedBox(12, x, y, w, h, theme.Background)
    draw.RoundedBoxEx(12, x, y, w, 42, theme.Orange, true, true, false, false)

    draw.SimpleText(cfg.ServerName, "MN_Title", x + pad, y + 21, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if cfg.ShowFPS then
        draw.SimpleText(math.floor(1 / FrameTime()) .. " FPS", "MN_Small", x + w - pad, y + 22, Color(10, 10, 10), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local cy = y + 58

    draw.SimpleText("Health", "MN_Text", x + pad, cy, theme.Text, TEXT_ALIGN_LEFT)
    draw.SimpleText(tostring(hp), "MN_Text", x + w - pad, cy, theme.Text, TEXT_ALIGN_RIGHT)
    DrawBar(x + pad, cy + 24, w - pad * 2, 10, smoothHealth / 100, theme.Health)

    cy = cy + 48

    draw.SimpleText("Armor", "MN_Text", x + pad, cy, theme.Text, TEXT_ALIGN_LEFT)
    draw.SimpleText(tostring(armor), "MN_Text", x + w - pad, cy, theme.Text, TEXT_ALIGN_RIGHT)
    DrawBar(x + pad, cy + 24, w - pad * 2, 10, smoothArmor / 100, theme.Armor)

    cy = cy + 52

    draw.RoundedBox(8, x + pad, cy - 5, w - pad * 2, 44, theme.PanelLight)

    draw.SimpleText(ply:Nick(), "MN_Text", x + pad + 10, cy + 5, theme.Text, TEXT_ALIGN_LEFT)
    draw.SimpleText(game.GetMap(), "MN_Small", x + pad + 10, cy + 25, theme.Muted, TEXT_ALIGN_LEFT)

    local rightText = ""
    if cfg.ShowPing then
        rightText = ply:Ping() .. " ms"
    end

    if cfg.ShowPlayers then
        rightText = rightText .. "  |  " .. #player.GetAll() .. "/" .. game.MaxPlayers()
    end

    draw.SimpleText(rightText, "MN_Small", x + w - pad - 10, cy + 25, theme.Muted, TEXT_ALIGN_RIGHT)
end)
