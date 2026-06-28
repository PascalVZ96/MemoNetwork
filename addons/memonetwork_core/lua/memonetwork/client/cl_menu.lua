-- MemoNetwork Lite Dashboard V2
-- Replaces the simple F1 menu with a tiled dashboard.

local menu
local activePage = "Home"

local function CloseMenu()
    if IsValid(menu) then
        menu:Remove()
        menu = nil
    end
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

        local bg = Color(20 + self.HoverAmount * 8, 26 + self.HoverAmount * 8, 34 + self.HoverAmount * 8, 235)

        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(10, 0, 0, 6, ph, accent or theme.Orange)

        draw.SimpleText(title, "MN_Title", 20, 23, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "MN_Text", 20, 52, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        if onClick then onClick() end
    end

    return btn
end

local function DrawPageContent(panel, page)
    panel:Clear()

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config

    if page == "Home" then
        local info = vgui.Create("DPanel", panel)
        info:SetPos(24, 24)
        info:SetSize(panel:GetWide() - 48, 96)
        info.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight)
            draw.SimpleText("Welcome to " .. cfg.ServerName, "MN_Title", 20, 24, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(cfg.Subtitle .. " - build, experiment and have fun.", "MN_Text", 20, 58, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return
    end

    local text = {
        Rules = {
            "Server Rules",
            "1. Be respectful to other players.",
            "2. Do not grief or delete other players' builds.",
            "3. Clean up unused props.",
            "4. Keep the server fun and relaxed."
        },
        Build = {
            "Build Guide",
            "Use Precision Tool for accurate placement.",
            "Use SmartSnap for clean alignment.",
            "Use Advanced Duplicator 2 to save your builds.",
            "Use Wiremod for logic and automation."
        },
        Workshop = {
            "Workshop",
            cfg.Workshop or "Coming soon."
        },
        Discord = {
            "Discord",
            cfg.Discord or "Coming soon."
        },
        Website = {
            "Website",
            cfg.Website or "Coming soon."
        },
        Settings = {
            "Settings",
            "Settings will be added later.",
            "For now you can use chat commands and console commands."
        }
    }

    local lines = text[page] or {"MemoNetwork", "No content yet."}

    local content = vgui.Create("DPanel", panel)
    content:SetPos(24, 24)
    content:SetSize(panel:GetWide() - 48, panel:GetTall() - 48)
    content.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight)
        draw.SimpleText(lines[1], "MN_Title", 22, 28, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local y = 68
        for i = 2, #lines do
            draw.SimpleText(lines[i], "MN_Text", 22, y, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            y = y + 28
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

    menu.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 64, theme.Orange, true, true, false, false)

        draw.SimpleText(cfg.ServerName, "MN_Title", 26, 32, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Subtitle, "MN_Text", pw - 26, 32, Color(10, 10, 10), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", menu)
    close:SetSize(90, 34)
    close:SetPos(w - 112, 15)
    close:SetText("Close")
    close:SetFont("MN_Text")
    close.DoClick = CloseMenu

    local sidebar = vgui.Create("DPanel", menu)
    sidebar:SetPos(18, 82)
    sidebar:SetSize(250, h - 100)
    sidebar.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.Panel)
    end

    local content = vgui.Create("DPanel", menu)
    content:SetPos(286, 82)
    content:SetSize(w - 304, h - 100)
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
        Tile(sidebar, 16, by, 218, 58, data[1], data[2], theme.Orange, function()
            activePage = data[1]
            DrawPageContent(content, activePage)
        end)
        by = by + 68
    end

    DrawPageContent(content, activePage)
end

concommand.Add("mn_menu", OpenMenu)

hook.Add("ShowHelp", "MemoNetwork_ShowHelp_DashboardV2", function()
    OpenMenu()
    return true
end)

hook.Add("OnPlayerChat", "MemoNetwork_MenuChat_DashboardV2", function(ply, text)
    if ply ~= LocalPlayer() then return end

    text = string.Trim(string.lower(text or ""))

    if text == "!menu" or text == "/menu" or text == "!f1" or text == "/f1" then
        OpenMenu()
        return true
    end
end)
