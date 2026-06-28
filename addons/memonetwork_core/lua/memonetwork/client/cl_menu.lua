-- MemoNetwork Alpha 13 Community Dashboard
-- Rebuilds F1 into a player home, profile, news, gallery, events and settings hub.

local menu
local activePage = "Home"
local newsData = {
    title = "Alpha 13 Community Update",
    items = {
        "New F1 Community Dashboard",
        "Profile page foundation",
        "Dynamic news support",
        "Gallery and events pages",
        "Settings hub polish"
    }
}
local newsLoaded = false
local galleryIndex = 1

local gallery = {
    {title = "Construct", subtitle = "Default Sandbox build area", map = "gm_construct"},
    {title = "Flatgrass", subtitle = "Open space for testing builds", map = "gm_flatgrass"},
    {title = "Big City", subtitle = "Large city map for vehicles and events", map = "gm_bigcity"},
    {title = "Fork", subtitle = "Scenic exploration and roleplay map", map = "gm_fork"}
}

local function ModuleEnabled(name)
    return not MemoNetwork.Modules or MemoNetwork.Modules:IsEnabled(name)
end

local function Setting(key, fallback)
    if MemoNetwork.Settings and MemoNetwork.Settings.Get then
        local value = MemoNetwork.Settings.Get(key)
        if value ~= nil then return value end
    end
    return fallback
end

local function IsURL(value)
    value = tostring(value or "")
    return string.StartWith(value, "http://") or string.StartWith(value, "https://")
end

local function Notify(message, kind, title)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", title or "MemoNetwork", 3)
    end
end

local function OpenURL(name, url)
    if IsURL(url) then
        gui.OpenURL(url)
        Notify(name .. " opened", "success", "Link")
    else
        Notify(name .. " is not configured yet", "warning", "Link")
    end
end

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

local function FitText(text, font, maxWidth)
    text = tostring(text or "")
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then return text end
    local suffix = "..."
    local suffixW = surface.GetTextSize(suffix)
    for i = #text, 1, -1 do
        local part = string.sub(text, 1, i)
        if surface.GetTextSize(part) + suffixW <= maxWidth then return part .. suffix end
    end
    return suffix
end

local function LoadNews()
    if newsLoaded then return end
    newsLoaded = true

    local cfg = MemoNetwork.Config or {}
    local url = cfg.NewsURL
    if not IsURL(url) or not http or not http.Fetch then return end

    http.Fetch(url, function(body)
        local data = util.JSONToTable(body or "")
        if not istable(data) then return end
        newsData.title = data.title or data.version or newsData.title
        newsData.items = istable(data.items) and data.items or (istable(data.news) and data.news or newsData.items)
    end, function()
        -- Keep bundled fallback news.
    end)
end

local function Card(parent, x, y, w, h, title, value, subtitle, accent)
    local theme = MemoNetwork.Theme
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(w, h)
    panel.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.PanelLight)
        draw.RoundedBox(6, 0, 0, 6, ph, accent or theme.Orange)
        draw.SimpleText(string.upper(title or "CARD"), "MN_Small", 18, 18, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(FitText(value or "-", "MN_Subtitle", pw - 36), "MN_Subtitle", 18, 45, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(FitText(subtitle, "MN_Small", pw - 36), "MN_Small", 18, 68, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    return panel
end

local function Button(parent, x, y, w, h, title, subtitle, onClick, accent)
    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn:SetCursor("hand")
    btn.HoverAmount = 0
    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, ph - 5, pw, 5, accent or theme.Orange)
        draw.SimpleText(title, "MN_Subtitle", 16, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(subtitle, "MN_Text", 16, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if onClick then onClick() end
    end
    return btn
end

local function AddToggle(parent, x, y, label, key)
    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(parent:GetWide() - 48, 42)
    btn:SetText("")
    btn:SetCursor("hand")
    btn.Paint = function(_, w, h)
        local enabled = Setting(key, true)
        local accent = enabled and (theme.Success or Color(90, 220, 120)) or Color(255, 90, 90)
        draw.RoundedBox(8, 0, 0, w, h, theme.Panel)
        draw.RoundedBox(6, 12, 11, 20, 20, accent)
        draw.SimpleText(label, "MN_Text", 46, h / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(enabled and "ON" or "OFF", "MN_Text", w - 18, h / 2, accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        if MemoNetwork.Settings and MemoNetwork.Settings.Toggle then
            MemoNetwork.Settings.Toggle(key)
        end
    end
end

local function DrawNewsList(parent, x, y, w, h)
    local theme = MemoNetwork.Theme
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(w, h)
    panel.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText(newsData.title or "Latest News", "MN_Title", 22, 30, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local lineY = 70
        for i, item in ipairs(newsData.items or {}) do
            if i > 6 then break end
            draw.SimpleText("✓", "MN_Text", 24, lineY, theme.Success or Color(90, 220, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(item), "MN_Text", 50, lineY, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            lineY = lineY + 28
        end
    end
    return panel
end

local function BuildHome(parent)
    LoadNews()
    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config or {}
    local ply = LocalPlayer()
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = theme.Text}
    local w = parent:GetWide()

    local hero = vgui.Create("DPanel", parent)
    hero:SetPos(0, 0)
    hero:SetSize(w, 126)
    hero.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.PanelLight)
        draw.RoundedBox(8, 0, 0, 8, ph, rank.color or theme.Orange)
        draw.SimpleText("WELCOME BACK", "MN_Small", 24, 24, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(IsValid(ply) and ply:Nick() or "Player", "MN_Title", 24, 58, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Subtitle", 24, 92, rank.color or theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Subtitle or "Industrial Sandbox", "MN_Text", pw - 24, 58, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(os.date("%H:%M"), "MN_Title", pw - 24, 92, theme.Orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    Card(parent, 0, 146, 160, 84, "Players", #player.GetAll() .. " / " .. game.MaxPlayers(), "Online now", theme.Orange)
    Card(parent, 176, 146, 160, 84, "Map", game.GetMap(), "Current map", Color(90, 220, 120))
    Card(parent, 352, 146, 160, 84, "Ping", (IsValid(ply) and ply:Ping() or 0) .. " ms", "Your latency", MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Orange)

    DrawNewsList(parent, 0, 250, 512, 168)
end

local function BuildProfile(parent)
    local theme = MemoNetwork.Theme
    local ply = LocalPlayer()
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = theme.Text}
    local w = parent:GetWide()

    local avatar = vgui.Create("AvatarImage", parent)
    avatar:SetSize(96, 96)
    avatar:SetPos(24, 26)
    if IsValid(ply) then avatar:SetPlayer(ply, 96) end

    local top = vgui.Create("DPanel", parent)
    top:SetPos(0, 0)
    top:SetSize(w, 146)
    top.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText(IsValid(ply) and ply:Nick() or "Player", "MN_Title", 142, 42, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Subtitle", 142, 78, rank.color or theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(IsValid(ply) and ply:SteamID() or "Unknown", "MN_Text", 142, 108, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    Card(parent, 0, 166, 160, 84, "Health", tostring(IsValid(ply) and ply:Health() or 0), "Current HP", Color(255, 90, 90))
    Card(parent, 176, 166, 160, 84, "Armor", tostring(IsValid(ply) and ply:Armor() or 0), "Current armor", Color(80, 160, 255))
    Card(parent, 352, 166, 160, 84, "FPS", tostring(math.floor(1 / FrameTime())), "Client FPS", theme.Orange)
    Card(parent, 0, 270, 160, 84, "Ping", (IsValid(ply) and ply:Ping() or 0) .. " ms", "Network", MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Orange)
    Card(parent, 176, 270, 160, 84, "Level", "Coming", "XP framework ready", Color(255, 210, 90))
    Card(parent, 352, 270, 160, 84, "Joins", "Soon", "Stats foundation", Color(180, 120, 255))
end

local function BuildGallery(parent)
    local theme = MemoNetwork.Theme
    local w = parent:GetWide()
    local current = gallery[galleryIndex] or gallery[1]

    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(0, 0)
    panel:SetSize(w, 260)
    panel.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.PanelLight)
        draw.RoundedBox(10, 18, 18, pw - 36, ph - 36, Color(18, 26, 38, 240))
        draw.SimpleText("SERVER GALLERY", "MN_Small", 38, 52, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(current.title, "MN_Title", 38, 96, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(current.subtitle, "MN_Text", 38, 132, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(current.map, "MN_Subtitle", 38, 180, theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    Button(parent, 0, 284, 160, 76, "Previous", "Gallery image", function()
        galleryIndex = galleryIndex - 1
        if galleryIndex < 1 then galleryIndex = #gallery end
        parent:Clear()
        BuildGallery(parent)
    end)
    Button(parent, 176, 284, 160, 76, "Next", "Gallery image", function()
        galleryIndex = galleryIndex + 1
        if galleryIndex > #gallery then galleryIndex = 1 end
        parent:Clear()
        BuildGallery(parent)
    end)
    Button(parent, 352, 284, 160, 76, "Workshop", "Open addons", function()
        OpenURL("Workshop", MemoNetwork.Config.Workshop)
    end)
end

local function BuildEvents(parent)
    local theme = MemoNetwork.Theme
    local w = parent:GetWide()

    local event = vgui.Create("DPanel", parent)
    event:SetPos(0, 0)
    event:SetSize(w, 150)
    event.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText("UPCOMING EVENT", "MN_Small", 24, 28, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Build Contest", "MN_Title", 24, 68, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Saturday 20:00 - reward: VIP / Showcase", "MN_Text", 24, 108, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    Card(parent, 0, 174, 160, 84, "Daily", "Spawn 50", "Props challenge", theme.Orange)
    Card(parent, 176, 174, 160, 84, "Reward", "Soon", "XP framework", Color(255, 210, 90))
    Card(parent, 352, 174, 160, 84, "Status", "Planned", "Alpha 14+", Color(90, 220, 120))

    local info = vgui.Create("DPanel", parent)
    info:SetPos(0, 278)
    info:SetSize(w, 118)
    info.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText("Event Framework", "MN_Title", 24, 34, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("This page prepares MemoNetwork for contests, votes, daily rewards and challenges.", "MN_Text", 24, 74, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function BuildLinks(parent)
    local cfg = MemoNetwork.Config or {}
    Button(parent, 0, 0, 160, 76, "Website", "Open memocraft.nl", function() OpenURL("Website", cfg.Website) end)
    Button(parent, 176, 0, 160, 76, "Discord", "Join community", function() OpenURL("Discord", cfg.Discord) end)
    Button(parent, 352, 0, 160, 76, "Workshop", "Required addons", function() OpenURL("Workshop", cfg.Workshop) end)
    Button(parent, 0, 100, 160, 76, "Rules", "Server rules", function() activePage = "Rules" end)
    Button(parent, 176, 100, 160, 76, "Admin", "Open F6", function() RunConsoleCommand("mn_admin") end)
end

local function BuildSettings(parent)
    local theme = MemoNetwork.Theme
    local info = vgui.Create("DPanel", parent)
    info:SetPos(0, 0)
    info:SetSize(parent:GetWide(), 70)
    info.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, theme.PanelLight)
        draw.SimpleText("Settings", "MN_Title", 24, 28, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Saved locally on your client.", "MN_Text", 24, 52, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    AddToggle(parent, 24, 96, "Show HUD", "hud")
    AddToggle(parent, 24, 146, "Show Voice HUD", "voice")
    AddToggle(parent, 24, 196, "Show Notifications", "notifications")
    AddToggle(parent, 24, 246, "Show FPS", "fps")
    AddToggle(parent, 24, 296, "Show Ping", "ping")
    AddToggle(parent, 24, 346, "Show Player Count", "players")
end

local function BuildTextPage(parent, title, lines)
    local theme = MemoNetwork.Theme
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(0, 0)
    panel:SetSize(parent:GetWide(), parent:GetTall())
    panel.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, theme.PanelLight)
        draw.SimpleText(title, "MN_Title", 24, 32, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local y = 80
        for _, line in ipairs(lines) do
            draw.SimpleText(line, "MN_Text", 24, y, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            y = y + 30
        end
    end
end

local function DrawPageContent(panel, page)
    panel:Clear()

    if page == "Home" then BuildHome(panel)
    elseif page == "Profile" then BuildProfile(panel)
    elseif page == "News" then LoadNews() DrawNewsList(panel, 0, 0, panel:GetWide(), panel:GetTall())
    elseif page == "Gallery" then BuildGallery(panel)
    elseif page == "Events" then BuildEvents(panel)
    elseif page == "Links" then BuildLinks(panel)
    elseif page == "Settings" then BuildSettings(panel)
    elseif page == "Rules" then BuildTextPage(panel, "Server Rules", {"1. Be respectful to other players.", "2. Do not grief or delete other players' builds.", "3. Clean up unused props.", "4. Keep the server fun and relaxed."})
    elseif page == "Build" then BuildTextPage(panel, "Build Guide", {"Use Precision Tool for accurate placement.", "Use SmartSnap for clean alignment.", "Use Advanced Duplicator 2 to save your builds.", "Use Wiremod for logic and automation."})
    end
end

local function OpenMenu()
    if not ModuleEnabled("Dashboard") then return end
    if IsValid(menu) then CloseMenu() return end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config or {}
    local sw, sh = ScrW(), ScrH()
    local w, h = 880, 590

    menu = vgui.Create("DFrame")
    menu:SetSize(w, h)
    menu:SetPos((sw - w) / 2, (sh - h) / 2)
    menu:SetTitle("")
    menu:SetDraggable(false)
    menu:ShowCloseButton(false)
    menu:MakePopup()
    menu:SetAlpha(0)
    menu:AlphaTo(255, 0.12, 0)

    menu.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, theme.Orange, true, true, false, false)
        draw.SimpleText(cfg.ServerName or "MemoNetwork", "MN_Title", 28, 27, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText((cfg.Subtitle or "") .. "  -  " .. (cfg.Version or ""), "MN_Text", 28, 55, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(menu, w - 56, 20, CloseMenu)
    end

    local sidebar = vgui.Create("DPanel", menu)
    sidebar:SetPos(18, 98)
    sidebar:SetSize(250, h - 116)
    sidebar.Paint = function(_, pw, ph) draw.RoundedBox(12, 0, 0, pw, ph, theme.Panel) end

    local content = vgui.Create("DPanel", menu)
    content:SetPos(286, 98)
    content:SetSize(w - 304, h - 116)
    content.Paint = function() end

    local buttons = {
        {"Home", "Community dashboard"},
        {"Profile", "Your player profile"},
        {"News", "Latest updates"},
        {"Gallery", "Server showcase"},
        {"Events", "Challenges and events"},
        {"Links", "Website and Discord"},
        {"Rules", "Read server rules"},
        {"Build", "Builder tips"},
        {"Settings", "Client options"}
    }

    local by = 12
    for _, data in ipairs(buttons) do
        Button(sidebar, 16, by, 218, 42, data[1], data[2], function()
            activePage = data[1]
            DrawPageContent(content, activePage)
        end, theme.Orange)
        by = by + 48
    end

    DrawPageContent(content, activePage)
end

concommand.Add("mn_menu", OpenMenu)

hook.Add("ShowHelp", "MemoNetwork_ShowHelp_Alpha13", function()
    OpenMenu()
    return true
end)

hook.Add("OnPlayerChat", "MemoNetwork_MenuChat_Alpha13", function(ply, text)
    if ply ~= LocalPlayer() then return end
    text = string.Trim(string.lower(text or ""))
    if text == "!menu" or text == "/menu" or text == "!f1" or text == "/f1" then
        OpenMenu()
        return true
    end
end)
