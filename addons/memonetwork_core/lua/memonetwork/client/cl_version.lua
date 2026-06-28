-- MemoNetwork Lite Version Watermark

hook.Add("HUDPaint", "MemoNetwork_VersionWatermark", function()
    local cfg = MemoNetwork.Config

    if not cfg or not cfg.Version then return end

    local x = ScrW() - 18
    local y = ScrH() - 38

    draw.SimpleText(cfg.ServerName or "MemoNetwork", "MN_Small", x, y, Color(255, 255, 255, 90), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(cfg.Version, "MN_Small", x, y + 16, Color(255, 145, 0, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
