-- MemoNetwork Alpha 10.3 Admin Panel
-- F6 admin dashboard with tools, map control and server overview.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Admin = MemoNetwork.Admin or {}

local panel
local activeTab = "Dashboard"

local function IsAllowed()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    if MemoNetwork.Ranks and MemoNetwork.Ranks.CanAdmin then
        return MemoNetwork.Ranks.CanAdmin(ply)
    end

    return ply:IsAdmin()
end

local function SendAction(action, payload)
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        if payload then
            net.WriteString(payload)
        end
    net.SendToServer()
end

net.Receive("MemoNetwork_AdminResult", function()
    local message = net.ReadString()
    local kind = net.ReadString()

    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind, "Admin", 3)
    else
        chat.AddText(Color(255, 145, 0), "[MemoNetwork Admin] ", color_white, message)
    end
end)

local function ActionButton(parent, x, y, w, h, title, subtitle, action, payload)
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
        draw.RoundedBox(8, 0, ph - 5, pw, 5, theme.Orange)
        draw.SimpleText(title, "MN_Subtitle", 16, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "MN_Text", 16, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        SendAction(action, payload)
    end

    return btn
end

local function TabButton(parent, x, y, w, h, label, content)
    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn:SetCursor("hand")
    btn.HoverAmount = 0

    btn.Paint = function(self, pw, ph)
        local selected = activeTab == label
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = selected and Color(30, 38, 48, 245) or Color(15 + self.HoverAmount * 8, 20 + self.HoverAmount * 8, 28 + self.HoverAmount * 8, 230)
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(6, 0, 0, selected and 7 or 4, ph, selected and theme.Orange or Color(255, 145, 0, 120))
        draw.SimpleText(label, "MN_Subtitle", 18, ph / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        activeTab = label
        if IsValid(content) and content.Rebuild then
            content:Rebuild()
        end
    end

    return btn
end

local function InfoCard(parent, x, y, w, h, title, value, color)
    local theme = MemoNetwork.Theme
    local card = vgui.Create("DPanel", parent)
    card:SetPos(x, y)
    card:SetSize(w, h)
    card.Paint = function(_, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText(string.upper(title), "MN_Small", 16, 18, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "MN_Subtitle", 16, 47, color or theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return card
end

local function BuildDashboard(content)
    local ply = LocalPlayer()
    local theme = MemoNetwork.Theme

    InfoCard(content, 0, 0, 160, 78, "Map", game.GetMap())
    InfoCard(content, 176, 0, 160, 78, "Players", #player.GetAll() .. " / " .. game.MaxPlayers())
    InfoCard(content, 352, 0, 160, 78, "Ping", IsValid(ply) and (ply:Ping() .. " ms") or "0 ms", MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Text)

    local box = vgui.Create("DPanel", content)
    box:SetPos(0, 100)
    box:SetSize(512, 214)
    box.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight)
        draw.SimpleText("MemoNetwork Admin", "MN_Title", 24, 32, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Use this panel for quick Sandbox server control.", "MN_Text", 24, 70, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Maps are configured in sh_config.lua so the server map pool stays easy to edit.", "MN_Text", 24, 102, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Current version: " .. (MemoNetwork.Config.Version or "Alpha"), "MN_Text", 24, 134, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function BuildTools(content)
    ActionButton(content, 0, 0, 160, 76, "Cleanup", "Clean map props", "cleanup")
    ActionButton(content, 176, 0, 160, 76, "God Mode", "Toggle god mode", "god")
    ActionButton(content, 352, 0, 160, 76, "Noclip", "Toggle noclip", "noclip")
    ActionButton(content, 0, 94, 160, 76, "Heal", "100 HP + armor", "health")
    ActionButton(content, 176, 94, 160, 76, "Restart Map", "Reload current map", "restart_map")
end

local function BuildMaps(content)
    local theme = MemoNetwork.Theme
    local maps = MemoNetwork.Config.Maps or {}

    local info = vgui.Create("DPanel", content)
    info:SetPos(0, 0)
    info:SetSize(512, 64)
    info.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight)
        draw.SimpleText("Map Control", "MN_Subtitle", 18, 20, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Click a map to changelevel. Current: " .. game.GetMap(), "MN_Text", 18, 45, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local y = 82
    local rowH = 58
    for _, data in ipairs(maps) do
        local mapName = data.map or ""
        local title = data.name or mapName
        local subtitle = mapName .. " - " .. (data.description or "Sandbox map")

        local row = vgui.Create("DButton", content)
        row:SetPos(0, y)
        row:SetSize(512, rowH)
        row:SetText("")
        row:SetCursor("hand")
        row.HoverAmount = 0
        row.Paint = function(self, w, h)
            self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
            local selected = game.GetMap() == mapName
            local bg = selected and Color(34, 45, 55, 245) or Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
            draw.RoundedBox(10, 0, 0, w, h, bg)
            draw.RoundedBox(6, 0, 0, selected and 8 or 5, h, selected and theme.Success or theme.Orange)
            draw.SimpleText(title, "MN_Subtitle", 18, 19, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(subtitle, "MN_Small", 18, 42, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(selected and "CURRENT" or "CHANGE", "MN_Small", w - 18, h / 2, selected and theme.Success or theme.Orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            surface.PlaySound("buttons/button15.wav")
            SendAction("change_map", mapName)
        end

        y = y + rowH + 10
    end
end

local function BuildPlayers(content)
    local theme = MemoNetwork.Theme
    local players = player.GetAll()

    if MemoNetwork.Player and MemoNetwork.Player.Sort then
        MemoNetwork.Player.Sort(players)
    end

    local y = 0
    for _, ply in ipairs(players) do
        local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = theme.Text}
        local row = vgui.Create("DButton", content)
        row:SetPos(0, y)
        row:SetSize(512, 58)
        row:SetText("")
        row:SetCursor("hand")
        row.HoverAmount = 0

        local avatar = vgui.Create("AvatarImage", row)
        avatar:SetSize(38, 38)
        avatar:SetPos(12, 10)
        avatar:SetPlayer(ply, 38)
        avatar:SetMouseInputEnabled(false)

        row.Paint = function(self, w, h)
            self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
            draw.RoundedBox(10, 0, 0, w, h, Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235))
            draw.RoundedBox(6, 0, 0, 5, h, rank.color or theme.Orange)
            draw.SimpleText(IsValid(ply) and ply:Nick() or "Unknown", "MN_Text", 62, 21, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(rank.name or "PLAYER", "MN_Small", 62, 42, rank.color or theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(IsValid(ply) and (ply:Ping() .. " ms") or "0 ms", "MN_Text", w - 18, h / 2, MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            if MemoNetwork.PlayerInspector and MemoNetwork.PlayerInspector.Open then
                MemoNetwork.PlayerInspector.Open(ply)
            end
        end

        y = y + 68
    end
end

local function BuildContent(content)
    content:Clear()
    if activeTab == "Dashboard" then
        BuildDashboard(content)
    elseif activeTab == "Players" then
        BuildPlayers(content)
    elseif activeTab == "Tools" then
        BuildTools(content)
    elseif activeTab == "Maps" then
        BuildMaps(content)
    end
end

function MemoNetwork.Admin.Open()
    if not IsAllowed() then
        if MemoNetwork.Notify then
            MemoNetwork.Notify("Admin panel is owner/admin only.", "error", "Admin", 3)
        end
        return
    end

    if IsValid(panel) then
        panel:Remove()
        panel = nil
        return
    end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config
    local sw, sh = ScrW(), ScrH()
    local w, h = 820, 540

    panel = vgui.Create("DFrame")
    panel:SetSize(w, h)
    panel:SetPos((sw - w) / 2, (sh - h) / 2)
    panel:SetTitle("")
    panel:SetDraggable(false)
    panel:ShowCloseButton(false)
    panel:MakePopup()
    panel:SetAlpha(0)
    panel:AlphaTo(255, 0.12, 0)

    panel.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, theme.Orange, true, true, false, false)
        draw.SimpleText("MemoNetwork Admin", "MN_Title", 26, 27, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Version or "Alpha", "MN_Text", 26, 55, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(panel, w - 56, 20, function()
            panel:Remove()
            panel = nil
        end)
    end

    local sidebar = vgui.Create("DPanel", panel)
    sidebar:SetPos(18, 98)
    sidebar:SetSize(240, h - 116)
    sidebar.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.Panel)
    end

    local content = vgui.Create("DPanel", panel)
    content:SetPos(278, 98)
    content:SetSize(w - 296, h - 116)
    content.Paint = function() end
    content.Rebuild = function(self) BuildContent(self) end

    local tabs = {"Dashboard", "Players", "Tools", "Maps"}
    local y = 14
    for _, tab in ipairs(tabs) do
        TabButton(sidebar, 16, y, 208, 54, tab, content)
        y = y + 64
    end

    BuildContent(content)
end

concommand.Add("mn_admin", function()
    MemoNetwork.Admin.Open()
end)

hook.Add("PlayerButtonDown", "MemoNetwork_Admin_F6", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_F6 then
        MemoNetwork.Admin.Open()
    end
end)
