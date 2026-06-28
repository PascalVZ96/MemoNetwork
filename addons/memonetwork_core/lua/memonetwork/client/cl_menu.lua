-- MemoNetwork Lite Dashboard V3
-- Cleaner header, aligned sidebar tiles and custom close button.

local menu
local activePage = "Home"

local function CloseMenu()
    if IsValid(menu) then
        menu:AlphaTo(0, 0.10, 0, function()
            if IsValid(menu) then
                menu:Remove()
                menu = nil
            end
        end)
    end
end

local function DrawCloseButton(btn, w, h)
    local hover = btn:IsHovered()
    local bg = hover and Color(255, 170, 40, 255) or Color(20, 26, 34, 230)

    draw.RoundedBox(8, 0, 0, w, h, bg)
    draw.SimpleText("X", "MN_Title", w / 2, h / 2, hover and Color(10, 10, 10) or Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function Tile(parent, x, y, w, h, title, subtitle, accent, onClick)
    local theme = MemoNetwork.Theme

    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.HoverAmount = 0

    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount, self:IsHovered() and 1 or 0)

        local base = 18 + self.HoverAmount * 10
        local bg = Color(base, base + 6, base + 14, 235)

        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, 0, 6 + self.HoverAmount * 4, ph, accent or theme.Orange)

        -- Fixed alignment for every button
        draw.SimpleText(title, "MN_Title", 20, 23, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "MN_Small", 20, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if onClick then onClick() end
    end

    return btn
end

local function DrawPageContent(panel, page)
    panel:Clear()

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config

    local content = vgui.Create("DPanel", panel)
    content:SetPos(0, 0)
    content:SetSize(panel:GetWide(), panel:GetTall())
    content.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, theme.PanelLight)

        local title = page
        local lines = {}

        if page == "Home" then
            title = "Welcome to " .. cfg.ServerName
            lines = {
                cfg.Subtitle .. " - build, experiment and have fun.",
                "",
                "Use the menu on the left to view rules, build tips and links."
            }
        elseif page == "Rules" then
            title = "Server Rules"
            lines = {
                "1. Be respectful to other players.",
                "2. Do not grief or delete other players' builds.",
                "3. Clean up unused props.",
                "4. Keep the server fun and relaxed."
            }
        elseif page == "Build" then
            title = "Build Guide"
            lines = {
                "Use Precision Tool for accurate placement.",
                "Use SmartSnap for clean alignment.",
                "Use Advanced Duplicator 2 to save your builds.",
                "Use Wiremod for logic and automation."
            }
        elseif page == "Workshop" then
            title = "Workshop"
            lines = {cfg.Workshop or "Coming soon."}
        elseif page == "Discord" then
            title = "Discord"
            lines = {cfg.Discord or "Coming soon."}
        elseif page == "Website" then
            title = "Website"
            lines = {cfg.Website or "Coming soon."}
        elseif page == "Settings" then
            title = "Settings"
            lines = {
                "Settings will be added later.",
                "For now, use console command mn_menu or chat command !menu."
            }
        end

        draw.SimpleText(title, "MN_Title", 24, 30, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local y = 78
        for _, line in ipairs(lines) do
            draw.SimpleText(line, "MN_Text", 24, y, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            y = y + 30
        end
    end
end

local function OpenMenu()
    if IsValid(menu) then
        CloseMenu()
        return
    end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config
    local sw, sh = ScrW(), ScrH()

    local w, h = 820, 520

    menu = vgui.Create("DFrame")
    menu:SetSize(w, h)
    menu:SetPos((sw - w) / 2, (sh - h) / 2)
    menu:SetTitle("")
    menu:SetDraggable(false)
    menu:ShowCloseButton(false)
    menu:MakePopup()
    menu:SetAlpha(0)
    menu:AlphaTo(255, 0.10, 0)

    menu.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 74, theme.Orange, true, true, false, false)

        -- Header text left only, so it never sits behind the close button
        draw.SimpleText(cfg.ServerName, "MN_Title", 28, 26, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Subtitle, "MN_Text", 28, 52, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", menu)
    close:SetSize(38, 38)
    close:SetPos(w - 56, 18)
    close:SetText("")
    close.Paint = DrawCloseButton
    close.DoClick = CloseMenu

    local sidebar = vgui.Create("DPanel", menu)
    sidebar:SetPos(18, 94)
    sidebar:SetSize(250, h - 112)
    sidebar.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.Panel)
    end

    local content = vgui.Create("DPanel", menu)
    content:SetPos(286, 94)
    content:SetSize(w - 304, h - 112)
    content.Paint = function() end

    local buttons = {
        {"Home", "Server overview"},
        {"Rules", "Read server rules"},
        {"Build", "Builder tips"},
        {"Workshop", "Required addons"},
        {"Discord", "Community link"},
        {"Website", "Server website"},
        {"Settings", "Client options"}
    }

    local by = 16
    for _, data in ipairs(buttons) do
        Tile(sidebar, 16, by, 218, 56, data[1], data[2], theme.Orange, function()
            activePage = data[1]
            DrawPageContent(content, activePage)
        end)
        by = by + 64
    end

    DrawPageContent(content, activePage)
end

concommand.Add("mn_menu", OpenMenu)

hook.Add("ShowHelp", "MemoNetwork_ShowHelp_DashboardV3", function()
    OpenMenu()
    return true
end)

hook.Add("OnPlayerChat", "MemoNetwork_MenuChat_DashboardV3", function(ply, text)
    if ply ~= LocalPlayer() then return end

    text = string.Trim(string.lower(text or ""))

    if text == "!menu" or text == "/menu" or text == "!f1" or text == "/f1" then
        OpenMenu()
        return true
    end
end)
