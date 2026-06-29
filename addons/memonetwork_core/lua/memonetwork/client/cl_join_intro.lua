-- MemoNetwork Alpha 13.1 Join Intro
-- Shows the real player name and rank after the client has fully joined.

MemoNetwork = MemoNetwork or {}
MemoNetwork.JoinIntro = MemoNetwork.JoinIntro or {}

local intro = {
    active = false,
    start = 0,
    duration = 5.2
}

local function StartIntro()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    intro.active = true
    intro.start = CurTime()

    timer.Simple(intro.duration, function()
        intro.active = false
    end)
end

function MemoNetwork.JoinIntro.Play()
    StartIntro()
end

hook.Add("InitPostEntity", "MemoNetwork_JoinIntro_Start", function()
    timer.Simple(1.2, StartIntro)
end)

hook.Add("HUDPaint", "MemoNetwork_JoinIntro_Paint", function()
    if not intro.active then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local theme = MemoNetwork.Theme or {}
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = Color(255, 145, 0)}
    local elapsed = CurTime() - intro.start
    local duration = intro.duration

    if elapsed > duration then
        intro.active = false
        return
    end

    local fadeIn = math.Clamp(elapsed / 0.8, 0, 1)
    local fadeOut = math.Clamp((duration - elapsed) / 0.9, 0, 1)
    local alphaMul = math.min(fadeIn, fadeOut)
    local alpha = math.floor(255 * alphaMul)

    local sw, sh = ScrW(), ScrH()
    local w, h = 560, 230
    local x, y = (sw - w) / 2, sh * 0.24

    draw.RoundedBox(18, x, y, w, h, Color(10, 14, 22, math.floor(225 * alphaMul)))
    draw.RoundedBoxEx(18, x, y, w, 8, Color(255, 145, 0, alpha), true, true, false, false)

    draw.SimpleText("WELCOME BACK", "MN_Small", sw / 2, y + 42, Color(155, 165, 180, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(ply:Nick(), "MN_Title", sw / 2, y + 88, Color(245, 245, 245, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(rank.name or "PLAYER", "MN_Subtitle", sw / 2, y + 126, Color((rank.color or Color(255,145,0)).r, (rank.color or Color(255,145,0)).g, (rank.color or Color(255,145,0)).b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText((MemoNetwork.Config and MemoNetwork.Config.Subtitle) or "Industrial Sandbox", "MN_Text", sw / 2, y + 168, Color(170, 178, 190, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local barW = 360
    local progress = math.Clamp(elapsed / duration, 0, 1)
    draw.RoundedBox(6, sw / 2 - barW / 2, y + 196, barW, 6, Color(255, 255, 255, math.floor(25 * alphaMul)))
    draw.RoundedBox(6, sw / 2 - barW / 2, y + 196, barW * progress, 6, Color(255, 145, 0, alpha))
end)
