-- MemoNetwork Alpha 16.1 Admin Dashboard 2.0
-- Widget-based server monitor and quick actions preview.

MemoNetwork = MemoNetwork or {}
MemoNetwork.AdminDashboard2 = MemoNetwork.AdminDashboard2 or {}

local frame
local quickBroadcastText = ""

local function CanOpen()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, "admin.open")
    end
    return ply:IsAdmin()
end

local function Notify(message, kind)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", "Dashboard 2.0", 3)
    else
        chat.AddText(Color(255, 145, 0), "[Dashboard 2.0] ", color_white, message)
    end
end

local function SendAction(action, payload)
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        if payload then net.WriteString(payload) end
    net.SendToServer()
end

local function CountEntities()
    local stats = {props = 0, vehicles = 0, npcs = 0, wire = 0, lights = 0}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) then
            local class = ent:GetClass() or ""
            if class == "prop_physics" or class == "prop_physics_multiplayer" then stats.props = stats.props + 1 end
            if string.StartWith(class, "prop_vehicle") or string.StartWith(class, "gmod_sent_vehicle") then stats.vehicles = stats.vehicles + 1 end
            if ent:IsNPC() then stats.npcs = stats.npcs + 1 end
            if string.StartWith(class, "gmod_wire") or string.find(class, "wire", 1, true) then stats.wire = stats.wire + 1 end
            if class == "gmod_lamp" or class == "gmod_light" or class == "light_dynamic" then stats.lights = stats.lights + 1 end
        end
    end
    return stats
end

local function OpenBroadcastPopup()
    local theme = MemoNetwork.Theme
    local w, h = 430, 190
    local popup = vgui.Create("DFrame")
    popup:SetSize(w, h)
    popup:Center()
    popup:SetTitle("")
    popup:SetDraggable(false)
    popup:ShowCloseButton(false)
    popup:MakePopup()
    popup.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 62, theme.Orange, true, true, false, false)
        draw.SimpleText("Quick Broadcast", "MN_Title", 22, 31, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local entry = vgui.Create("DTextEntry", popup)
    entry:SetPos(22, 82)
    entry:SetSize(w - 44, 36)
    entry:SetFont("MN_Text")
    entry:SetText(quickBroadcastText)
    entry:SetPlaceholderText("Server restart in 5 minutes")

    MemoNetwork.Widgets.ActionButton(popup, 22, 136, 180, 36, "Cancel", "", function() popup:Remove() end)
    MemoNetwork.Widgets.ActionButton(popup, 228, 136, 180, 36, "Send", "", function()
        quickBroadcastText = string.Trim(entry:GetText() or "")
        if quickBroadcastText == "" then Notify("Broadcast is empty.", "error") return end
        SendAction("broadcast", quickBroadcastText)
        popup:Remove()
    end)
end

local function BuildContent(parent)
    parent:Clear()
    local theme = MemoNetwork.Theme
    local widgets = MemoNetwork.Widgets
    local metrics = MemoNetwork.Metrics
    local ply = LocalPlayer()
    local stats = CountEntities()
    local loaded, total = 0, 0
    if MemoNetwork.Addons and MemoNetwork.Addons.CountLoaded then
        loaded, total = MemoNetwork.Addons.CountLoaded()
    end

    widgets.Header(parent, 0, 0, 740, 82, "Dashboard 2.0", "Live server overview with widgets, graphs and quick actions", theme.Orange)

    widgets.StatCard(parent, 0, 102, 170, 84, "Players", #player.GetAll() .. " / " .. game.MaxPlayers(), "online", theme.Orange)
    widgets.StatCard(parent, 190, 102, 170, 84, "Map", game.GetMap(), "current", theme.Success or Color(90,220,120))
    widgets.StatCard(parent, 380, 102, 170, 84, "Ping", (IsValid(ply) and ply:Ping() or 0) .. " ms", "your latency", MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Orange)
    widgets.StatCard(parent, 570, 102, 170, 84, "Addons", loaded .. " / " .. total, "detected", loaded == total and (theme.Success or Color(90,220,120)) or Color(255,190,80))

    widgets.Graph(parent, 0, 210, 360, 150, "FPS History", metrics and metrics.Get("fps") or {}, 160, Color(255,210,90))
    widgets.Graph(parent, 380, 210, 360, 150, "Entity History", metrics and metrics.Get("entities") or {}, math.max(100, metrics and metrics.Max("entities", 100) or 100), theme.Orange)
    widgets.Graph(parent, 0, 380, 360, 150, "Lua Memory", metrics and metrics.Get("memory") or {}, math.max(128, metrics and metrics.Max("memory", 128) or 128), Color(180,120,255))
    widgets.Graph(parent, 380, 380, 360, 150, "Players", metrics and metrics.Get("players") or {}, math.max(8, game.MaxPlayers()), Color(90,220,120))

    local quick = widgets.Panel(parent, 760, 0, 240, 530, function(_, w, h)
        draw.SimpleText("Quick Actions", "MN_Title", 18, 30, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Fast owner/admin tools", "MN_Text", 18, 60, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    widgets.ActionButton(quick, 18, 86, 204, 54, "Cleanup", "Full map cleanup", function() SendAction("cleanup") end, {danger = true})
    widgets.ActionButton(quick, 18, 150, 204, 54, "Restart Map", "Reload current map", function() SendAction("restart_map") end, {danger = true})
    widgets.ActionButton(quick, 18, 214, 204, 54, "Broadcast", "Send message", OpenBroadcastPopup)
    widgets.ActionButton(quick, 18, 278, 204, 54, "F6 Admin", "Open classic panel", function() RunConsoleCommand("mn_admin") end)
    widgets.ActionButton(quick, 18, 342, 204, 54, "Refresh", "Rebuild widgets", function() BuildContent(parent) end)

    widgets.StatCard(quick, 18, 420, 96, 70, "Props", tostring(stats.props), nil, Color(90,220,120))
    widgets.StatCard(quick, 126, 420, 96, 70, "Wire", tostring(stats.wire), nil, Color(80,160,255))
end

function MemoNetwork.AdminDashboard2.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end

    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()
    local w, h = 1050, 660
    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:SetPos((sw - w) / 2, (sh - h) / 2)
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.12, 0)
    frame.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, theme.Orange, true, true, false, false)
        draw.SimpleText("MemoNetwork Admin", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 16.1 Dashboard 2.0", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(frame, w - 56, 20, function() frame:Remove() frame = nil end)
    end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(24, 100)
    content:SetSize(w - 48, h - 124)
    content.Paint = function() end
    BuildContent(content)
end

concommand.Add("mn_admin2", MemoNetwork.AdminDashboard2.Open)

hook.Add("PlayerButtonDown", "MemoNetwork_AdminDashboard2_F7", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F7 then
        MemoNetwork.AdminDashboard2.Open()
    end
end)
