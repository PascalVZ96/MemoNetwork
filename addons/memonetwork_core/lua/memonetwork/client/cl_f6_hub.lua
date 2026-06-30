-- MemoNetwork Alpha 20.1 F6 Hub
-- Central launcher for all MemoNetwork admin/tools so admins only need to remember F6.

MemoNetwork = MemoNetwork or {}
MemoNetwork.F6Hub = MemoNetwork.F6Hub or {}

local frame
local activePage = "Home"

local function Theme()
    local t = MemoNetwork.Theme or {}
    return {
        orange = t.Orange or Color(255, 145, 0),
        text = t.Text or Color(245, 245, 245),
        muted = t.Muted or Color(155, 165, 180),
        bg = t.Background or Color(10, 14, 22, 238),
        panel = t.Panel or Color(14, 20, 28, 238),
        panel2 = t.PanelLight or Color(20, 28, 38, 238),
        success = t.Success or Color(90, 220, 120),
        danger = Color(255, 90, 90),
        warning = Color(255, 190, 80),
        blue = Color(80, 160, 255),
        purple = Color(180, 120, 255)
    }
end

local function CanOpen()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, "admin.open") or MemoNetwork.Ranks.HasPermission(ply, "players.manage")
    end
    return ply:IsAdmin()
end

local function Notify(message, kind)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", "F6 Hub", 3)
    else
        chat.AddText(Color(255,145,0), "[F6 Hub] ", color_white, tostring(message or ""))
    end
end

local function CloseHub()
    if IsValid(frame) then frame:Remove() frame = nil end
end

local function OpenTool(name, fn)
    if fn then
        CloseHub()
        timer.Simple(0, fn)
    else
        Notify(name .. " is not loaded yet.", "warning")
    end
end

local function Box(parent, x, y, w, h, accent, paintExtra)
    local th = Theme()
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    p.Paint = function(self, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, th.panel2)
        if accent then draw.RoundedBox(6, 0, 0, 6, ph, accent) end
        if paintExtra then paintExtra(self, pw, ph, th) end
    end
    return p
end

local function Button(parent, x, y, w, h, title, subtitle, fn, danger)
    local th = Theme()
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(w, h)
    b:SetText("")
    b:SetCursor("hand")
    b.HoverAmount = 0
    b.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 238)
        local accent = danger and th.danger or th.orange
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, ph - 5, pw, 5, accent)
        draw.SimpleText(tostring(title or "Button"), "MN_Subtitle", 16, subtitle and subtitle ~= "" and 22 or ph / 2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(tostring(subtitle), "MN_Text", 16, 52, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if fn then fn() end
    end
    return b
end

local function Stat(parent, x, y, w, h, title, value, subtitle, accent)
    local th = Theme()
    Box(parent, x, y, w, h, accent or th.orange, function(_, pw, ph)
        draw.SimpleText(string.upper(tostring(title or "STAT")), "MN_Small", 16, 17, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value or "-"), "MN_Subtitle", 16, 45, accent or th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(tostring(subtitle), "MN_Small", 16, 66, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end)
end

local function SendAction(action)
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
    net.SendToServer()
end

local function BuildHome(parent)
    local th = Theme()
    local ply = LocalPlayer()

    Box(parent, 0, 0, 640, 100, th.orange, function(_, w, h)
        draw.SimpleText("MemoNetwork Central Hub", "MN_Title", 22, 28, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alles zit nu onder F6. De oude hotkeys blijven alleen als backup.", "MN_Text", 22, 62, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(MemoNetwork.Config and MemoNetwork.Config.Version or "Alpha", "MN_Subtitle", w - 22, 42, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    Stat(parent, 0, 120, 150, 78, "Players", #player.GetAll() .. "/" .. game.MaxPlayers(), "online", th.orange)
    Stat(parent, 164, 120, 150, 78, "Map", game.GetMap(), "current", th.success)
    Stat(parent, 328, 120, 150, 78, "Ping", IsValid(ply) and (ply:Ping() .. " ms") or "0 ms", "your latency", th.blue)
    Stat(parent, 492, 120, 148, 78, "Entities", #ents.GetAll(), "world", th.purple)

    Button(parent, 0, 222, 200, 74, "Control Center", "Server actions / broadcast", function() OpenTool("Control Center", MemoNetwork.ControlCenter and MemoNetwork.ControlCenter.Open) end)
    Button(parent, 220, 222, 200, 74, "Build Manager", "Owners and build stats", function() OpenTool("Build Manager", MemoNetwork.BuildManager and MemoNetwork.BuildManager.Open) end)
    Button(parent, 440, 222, 200, 74, "Industrial Suite", "Alpha 20 overview", function() OpenTool("Admin Suite", MemoNetwork.AdminSuite and MemoNetwork.AdminSuite.Open) end)

    Button(parent, 0, 316, 200, 74, "Map Manager", "Change / restart map", function() OpenTool("Map Manager", MemoNetwork.MapManager and MemoNetwork.MapManager.Open) end)
    Button(parent, 220, 316, 200, 74, "Build Tools", "Cleanup / freeze builds", function() OpenTool("Build Tools", MemoNetwork.BuildTools and MemoNetwork.BuildTools.Open) end)
    Button(parent, 440, 316, 200, 74, "Rank Manager", "Ranks and staff", function() OpenTool("Rank Manager", MemoNetwork.RankManager and MemoNetwork.RankManager.Open) end)
end

local function BuildAdmin(parent)
    Button(parent, 0, 0, 200, 74, "Control Center", "F8 moved here", function() OpenTool("Control Center", MemoNetwork.ControlCenter and MemoNetwork.ControlCenter.Open) end)
    Button(parent, 220, 0, 200, 74, "Classic Admin", "Old F6 panel", function()
        CloseHub()
        if MemoNetwork.Admin and MemoNetwork.Admin.OpenClassic then
            MemoNetwork.Admin.OpenClassic()
        else
            Notify("Classic admin is kept as backup in older builds.", "warning")
        end
    end)
    Button(parent, 440, 0, 200, 74, "Broadcast", "Open Control Center", function() OpenTool("Control Center", MemoNetwork.ControlCenter and MemoNetwork.ControlCenter.Open) end)

    Button(parent, 0, 94, 200, 74, "Godmode", "Toggle yourself", function() SendAction("god") end)
    Button(parent, 220, 94, 200, 74, "Noclip", "Toggle yourself", function() SendAction("noclip") end)
    Button(parent, 440, 94, 200, 74, "Cleanup Map", "Careful", function()
        Derma_Query("Run full map cleanup?", "Cleanup", "Cleanup", function() SendAction("cleanup") end, "Cancel")
    end, true)
end

local function BuildBuilds(parent)
    Button(parent, 0, 0, 200, 74, "Build Manager", "F10 moved here", function() OpenTool("Build Manager", MemoNetwork.BuildManager and MemoNetwork.BuildManager.Open) end)
    Button(parent, 220, 0, 200, 74, "Build Tools", "F11 moved here", function() OpenTool("Build Tools", MemoNetwork.BuildTools and MemoNetwork.BuildTools.Open) end)
    Button(parent, 440, 0, 200, 74, "Build Assistant", "Toggle HUD helper", function() RunConsoleCommand("mn_buildassistant_toggle") end)

    local ownerCount = 0
    local entCount = 0
    local owners = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsPlayer() and not ent:IsWorld() then
            local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
            if sid ~= "" then owners[sid] = true entCount = entCount + 1 end
        end
    end
    for _ in pairs(owners) do ownerCount = ownerCount + 1 end

    Stat(parent, 0, 110, 150, 78, "Owners", ownerCount, "tracked", Theme().success)
    Stat(parent, 164, 110, 150, 78, "Owned Ents", entCount, "registered", Theme().orange)
    Stat(parent, 328, 110, 150, 78, "All Ents", #ents.GetAll(), "world", Theme().purple)
end

local function BuildMaps(parent)
    Button(parent, 0, 0, 200, 74, "Map Manager", "F9 moved here", function() OpenTool("Map Manager", MemoNetwork.MapManager and MemoNetwork.MapManager.Open) end)
    Button(parent, 220, 0, 200, 74, "Restart Current", game.GetMap(), function()
        Derma_Query("Restart current map " .. game.GetMap() .. "?", "Restart Map", "Restart", function() SendAction("restart_map") end, "Cancel")
    end, true)

    local y = 110
    for i, data in ipairs((MemoNetwork.Config and MemoNetwork.Config.Maps) or {}) do
        if i > 5 then break end
        Box(parent, 0, y, 640, 42, data.map == game.GetMap() and Theme().success or Theme().orange, function(_, w, h, th)
            draw.SimpleText(data.name or data.map, "MN_Text", 16, h / 2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(data.map or "", "MN_Text", w - 16, h / 2, data.map == game.GetMap() and th.success or th.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end)
        y = y + 50
    end
end

local function BuildSettings(parent)
    Box(parent, 0, 0, 640, 120, Theme().orange, function(_, w, h, th)
        draw.SimpleText("Hotkeys cleaned up", "MN_Title", 22, 30, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Gebruik voortaan F6 als hoofdmenu. F8/F9/F10/F11/F12 blijven tijdelijk als backup.", "MN_Text", 22, 66, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Button(parent, 0, 150, 200, 74, "Notifications", "Toggle", function() if MemoNetwork.Settings and MemoNetwork.Settings.Toggle then MemoNetwork.Settings.Toggle("notifications") end end)
    Button(parent, 220, 150, 200, 74, "HUD", "Toggle", function() if MemoNetwork.Settings and MemoNetwork.Settings.Toggle then MemoNetwork.Settings.Toggle("hud") end end)
    Button(parent, 440, 150, 200, 74, "Voice HUD", "Toggle", function() if MemoNetwork.Settings and MemoNetwork.Settings.Toggle then MemoNetwork.Settings.Toggle("voice") end end)
end

local function DrawPage(content)
    content:Clear()
    if activePage == "Home" then BuildHome(content)
    elseif activePage == "Administration" then BuildAdmin(content)
    elseif activePage == "Builds" then BuildBuilds(content)
    elseif activePage == "Maps" then BuildMaps(content)
    elseif activePage == "Settings" then BuildSettings(content)
    end
end

function MemoNetwork.F6Hub.Open()
    if not CanOpen() then Notify("F6 Hub is admin only.", "error") return end
    if IsValid(frame) then CloseHub() return end

    local th = Theme()
    local w, h = math.min(980, ScrW() - 60), math.min(720, ScrH() - 60)
    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.12, 0)
    frame.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, th.bg)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, th.orange, true, true, false, false)
        draw.SimpleText("MemoNetwork F6 Hub", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("One place for all admin tools", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(w - 56, 20)
    close:SetSize(36, 36)
    close:SetText("X")
    close.DoClick = CloseHub

    local sidebar = vgui.Create("DPanel", frame)
    sidebar:SetPos(20, 100)
    sidebar:SetSize(250, h - 124)
    sidebar.Paint = function(_, pw, ph) draw.RoundedBox(12, 0, 0, pw, ph, th.panel) end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(292, 100)
    content:SetSize(w - 322, h - 124)
    content.Paint = function() end

    local tabs = {
        {"Home", "Overview"},
        {"Administration", "Server tools"},
        {"Builds", "Build systems"},
        {"Maps", "Map tools"},
        {"Settings", "Client options"}
    }

    local y = 14
    for _, tab in ipairs(tabs) do
        Button(sidebar, 14, y, 222, 48, tab[1], tab[2], function()
            activePage = tab[1]
            DrawPage(content)
        end, activePage == tab[1])
        y = y + 58
    end

    DrawPage(content)
end

-- Keep old admin panel available for recovery if needed.
if MemoNetwork.Admin and MemoNetwork.Admin.Open and not MemoNetwork.Admin.OpenClassic then
    MemoNetwork.Admin.OpenClassic = MemoNetwork.Admin.Open
end

MemoNetwork.Admin = MemoNetwork.Admin or {}
MemoNetwork.Admin.Open = MemoNetwork.F6Hub.Open

pcall(concommand.Remove, "mn_admin")
concommand.Add("mn_admin", function() MemoNetwork.F6Hub.Open() end)

hook.Add("PlayerButtonDown", "MemoNetwork_Admin_F6", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F6 then MemoNetwork.F6Hub.Open() end
end)
