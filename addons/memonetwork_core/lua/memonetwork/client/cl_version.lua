-- MemoNetwork Lite Version Watermark

hook.Add("HUDPaint", "MemoNetwork_VersionWatermark", function()
    local cfg = MemoNetwork.Config
    local theme = MemoNetwork.Theme

    if not cfg or not cfg.Version then return end

    local text1 = cfg.ServerName or "MemoNetwork"
    local text2 = cfg.Version

    local x = ScrW() - 18
    local y = ScrH() - 38

    draw.SimpleText(text1, "MN_Small", x, y, Color(255, 255, 255, 90), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(text2, "MN_Small", x, y + 16, Color(255, 145, 0, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
