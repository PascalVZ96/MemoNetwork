-- MemoNetwork Alpha 16.2.1 Control Center
-- Stable F8 server control dashboard with safe fallbacks.

MemoNetwork = MemoNetwork or {}
MemoNetwork.ControlCenter = MemoNetwork.ControlCenter or {}

local frame
local selectedPlayer

local fallbackTheme = {
    Orange = Color(255, 145, 0),
    Text = Color(245, 245, 245),
    Muted = Color(155, 165, 180),
    Background = Color(10, 14, 22, 235),
    Panel = Color(14, 20, 28, 235),
    PanelLight = Color(20, 28, 38, 235),
    Success = Color(90, 220, 120)
}

local function T()
    local t = MemoNetwork.Theme or {}
    return {
        Orange = t.Orange or fallbackTheme.Orange,
        Text = t.Text or fallbackTheme.Text,
        Muted = t.Muted or fallbackTheme.Muted,
        Background = t.Background or fallbackTheme.Background,
        Panel = t.Panel or fallbackTheme.Panel,
        PanelLight = t.PanelLight or fallbackTheme.PanelLight,
        Success = t.Success or fallbackTheme.Success
    }
end

local function SafeCall(name, fn, fallback)
    local ok, result = pcall(fn)
    if not ok then
        MsgC(Color(255, 145, 0), "[MemoNetwork Control Center] ", Color(255, 90, 90), tostring(name) .. " failed: " .. tostring(result) .. "\n")
        return fallback
    end
    if result == nil then return fallback end
    return result
end

local function HasPerm(permission)
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, permission)
    end
    return ply:IsAdmin()
end

local function CanOpen()
    return HasPerm("admin.open")
end

local function Notify(message, kind)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", "Control Center", 3)
    else
        chat.AddText(Color(255, 145, 0), "[Control Center] ", color_white, tostring(message or ""))
    end
end

local function SendAction(action, payload)
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        if payload then net.WriteString(payload) end
    net.SendToServer()
end

local function SendTargetAction(action, target)
    if not IsValid(target) then Notify("Select a player first.", "error") return end
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        net.WriteEntity(target)
    net.SendToServer()
end

local function Confirm(title, text, action)
    Derma_Query(text, title, "Yes", action, "No")
end

local function Panel(parent, x, y, w, h, paintExtra)
    local theme = T()
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    p.Paint = function(self, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.PanelLight)
        if paintExtra then paintExtra(self, pw, ph, theme) end
    end
    return p
end

local function Card(parent, x, y, w, h, title, value, subtitle, accent)
    local theme = T()
    return Panel(parent, x, y, w, h, function(_, pw, ph)
        draw.RoundedBox(6, 0, 0, 6, ph, accent or theme.Orange)
        draw.SimpleText(string.upper(tostring(title or "STAT")), "MN_Small", 16, 18, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value or "-"), "MN_Subtitle", 16, 47, accent or theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(tostring(subtitle), "MN_Small", 16, 68, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end)
end

local function Button(parent, x, y, w, h, title, subtitle, onClick, danger)
    local theme = T()
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn:SetCursor("hand")
    btn.HoverAmount = 0
    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
        local accent = danger and Color(255, 90, 90) or theme.Orange
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, ph - 5, pw, 5, accent)
        draw.SimpleText(tostring(title or "Button"), "MN_Subtitle", 14, 18, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(tostring(subtitle), "MN_Small", 14, 40, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if onClick then onClick(btn) end
    end
    return btn
end

local function Graph(parent, x, y, w, h, title, values, maxValue, accent)
    local theme = T()
    values = istable(values) and values or {}
    maxValue = math.max(1, tonumber(maxValue) or 100)
    return Panel(parent, x, y, w, h, function(_, pw, ph)
        draw.SimpleText(tostring(title or "Graph"), "MN_Subtitle", 16, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local gx, gy = 16, 48
        local gw, gh = pw - 32, ph - 64
        draw.RoundedBox(8, gx, gy, gw, gh, Color(8, 12, 18, 190))
        if #values < 2 then
            draw.SimpleText("Collecting data...", "MN_Text", pw / 2, gy + gh / 2, theme.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end
        surface.SetDrawColor(accent or theme.Orange)
        for i = 2, #values do
            local x1 = gx + ((i - 2) / math.max(1, #values - 1)) * gw
            local x2 = gx + ((i - 1) / math.max(1, #values - 1)) * gw
            local y1 = gy + gh - math.Clamp((tonumber(values[i - 1]) or 0) / maxValue, 0, 1) * gh
            local y2 = gy + gh - math.Clamp((tonumber(values[i]) or 0) / maxValue, 0, 1) * gh
            surface.DrawLine(x1, y1, x2, y2)
        end
    end)
end

local function EntityStats()
    return SafeCall("EntityStats", function()
        local stats = {props = 0, vehicles = 0, npcs = 0, ragdolls = 0, effects = 0, projectiles = 0, wire = 0, lights = 0}
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) then
                local class = ent:GetClass() or ""
                if class == "prop_physics" or class == "prop_physics_multiplayer" then stats.props = stats.props + 1 end
                if string.StartWith(class, "prop_vehicle") or string.StartWith(class, "gmod_sent_vehicle") then stats.vehicles = stats.vehicles + 1 end
                if ent:IsNPC() then stats.npcs = stats.npcs + 1 end
                if class == "prop_ragdoll" then stats.ragdolls = stats.ragdolls + 1 end
                if class == "env_sprite" or class == "env_smoketrail" or class == "env_fire" or class == "env_explosion" or class == "info_particle_system" then stats.effects = stats.effects + 1 end
                if string.find(class, "grenade", 1, true) or string.find(class, "rocket", 1, true) or string.find(class, "missile", 1, true) or class == "crossbow_bolt" then stats.projectiles = stats.projectiles + 1 end
                if string.StartWith(class, "gmod_wire") or string.find(class, "wire", 1, true) then stats.wire = stats.wire + 1 end
                if class == "gmod_lamp" or class == "gmod_light" or class == "light_dynamic" then stats.lights = stats.lights + 1 end
            end
        end
        return stats
    end, {props = 0, vehicles = 0, npcs = 0, ragdolls = 0, effects = 0, projectiles = 0, wire = 0, lights = 0})
end

local function MetricLatest(key, fallback)
    if MemoNetwork.Metrics and MemoNetwork.Metrics.Latest then
        return MemoNetwork.Metrics.Latest(key, fallback)
    end
    return fallback
end

local function MetricValues(key)
    if MemoNetwork.Metrics and MemoNetwork.Metrics.Get then
        return MemoNetwork.Metrics.Get(key)
    end
    return {}
end

local function MetricMax(key, fallback)
    if MemoNetwork.Metrics and MemoNetwork.Metrics.Max then
        return MemoNetwork.Metrics.Max(key, fallback)
    end
    return fallback
end

local function PingColor(ping)
    if MemoNetwork.Player and MemoNetwork.Player.GetPingColor then
        return MemoNetwork.Player.GetPingColor(ping)
    end
    if ping < 60 then return Color(90, 220, 120) end
    if ping < 120 then return Color(255, 190, 80) end
    return Color(255, 90, 90)
end

local function AddonCount()
    if MemoNetwork.Addons and MemoNetwork.Addons.CountLoaded then
        local ok, loaded, total = pcall(MemoNetwork.Addons.CountLoaded)
        if ok then return loaded or 0, total or 0 end
    end
    return 0, 0
end

local function BroadcastPopup()
    Derma_StringRequest("Control Center Broadcast", "Message to all players:", "Server restart in 5 minutes", function(text)
        text = string.Trim(text or "")
        if text == "" then Notify("Broadcast is empty.", "error") return end
        SendAction("broadcast", text)
    end)
end

local function PlayerCard(parent, ply, x, y, w, h, root)
    local theme = T()
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = theme.Text}
    local card = vgui.Create("DButton", parent)
    card:SetPos(x, y)
    card:SetSize(w, h)
    card:SetText("")
    card:SetCursor("hand")
    card.HoverAmount = 0

    local avatar = vgui.Create("AvatarImage", card)
    avatar:SetSize(44, 44)
    avatar:SetPos(14, 16)
    avatar:SetPlayer(ply, 44)
    avatar:SetMouseInputEnabled(false)

    card.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local selected = selectedPlayer == ply
        draw.RoundedBox(12, 0, 0, pw, ph, selected and Color(34, 45, 55, 245) or Color(18 + self.HoverAmount * 8, 24 + self.HoverAmount * 8, 32 + self.HoverAmount * 8, 235))
        draw.RoundedBox(6, 0, 0, selected and 8 or 5, ph, rank.color or theme.Orange)
        draw.SimpleText(IsValid(ply) and ply:Nick() or "Unknown", "MN_Subtitle", 70, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Small", 70, 48, rank.color or theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText((IsValid(ply) and ply:Ping() or 0) .. " ms", "MN_Text", pw - 18, 25, PingColor(IsValid(ply) and ply:Ping() or 0), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText((IsValid(ply) and ply:Health() or 0) .. " HP / " .. (IsValid(ply) and ply:Armor() or 0) .. " AR", "MN_Small", pw - 18, 50, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    card.DoClick = function()
        selectedPlayer = ply
        if IsValid(root) and root.Rebuild then root:Rebuild() end
    end

    Button(card, 14, 74, 82, 34, "Goto", "", function() SendTargetAction("teleport", ply) end)
    Button(card, 104, 74, 82, 34, "Bring", "", function() SendTargetAction("bring", ply) end)
    Button(card, 194, 74, 82, 34, "Heal", "", function() SendTargetAction("heal_target", ply) end)
    Button(card, 284, 74, 82, 34, "Spec", "", function() SendTargetAction("spectate", ply) end)

    return card
end

local function DrawError(parent, err)
    local theme = T()
    parent:Clear()
    Panel(parent, 0, 0, 1040, 180, function(_, w, h)
        draw.RoundedBox(6, 0, 0, 7, h, Color(255, 90, 90))
        draw.SimpleText("Control Center Error", "MN_Title", 22, 34, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("The panel failed to build, but the UI stayed alive.", "MN_Text", 22, 74, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(err), "MN_Small", 22, 116, Color(255, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
end

local function BuildUnsafe(parent)
    parent:Clear()
    local theme = T()
    local stats = EntityStats()
    local players = player.GetAll()
    local loaded, total = AddonCount()

    Panel(parent, 0, 0, 1040, 78, function(_, w, h)
        draw.RoundedBox(6, 0, 0, 7, h, theme.Orange)
        draw.SimpleText("Server Control Center", "MN_Title", 22, 27, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("F8 quick control dashboard - stable build", "MN_Text", 22, 55, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    Card(parent, 0, 98, 160, 80, "Server", "Online", game.GetMap(), theme.Success)
    Card(parent, 174, 98, 160, 80, "Players", #players .. " / " .. game.MaxPlayers(), "connected", theme.Orange)
    Card(parent, 348, 98, 160, 80, "FPS", tostring(MetricLatest("fps", math.floor(1 / FrameTime()))), "client sample", Color(255,210,90))
    Card(parent, 522, 98, 160, 80, "Memory", MetricLatest("memory", math.floor(collectgarbage("count") / 1024)) .. " MB", "lua", Color(180,120,255))
    Card(parent, 696, 98, 160, 80, "Entities", tostring(#ents.GetAll()), "total", theme.Orange)
    Card(parent, 870, 98, 170, 80, "Addons", loaded .. " / " .. total, "detected", total > 0 and loaded == total and theme.Success or Color(255,190,80))

    local q = Panel(parent, 0, 198, 1040, 86, function(_, w, h)
        draw.SimpleText("Quick Actions", "MN_Subtitle", 18, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Use carefully on live servers", "MN_Text", 18, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Button(q, 210, 18, 112, 50, "Cleanup", "All", function() Confirm("Cleanup", "Run full map cleanup?", function() SendAction("cleanup") end) end, true)
    Button(q, 334, 18, 112, 50, "Restart", "Map", function() Confirm("Restart Map", "Restart current map?", function() SendAction("restart_map") end) end, true)
    Button(q, 458, 18, 112, 50, "Broadcast", "Message", BroadcastPopup)
    Button(q, 582, 18, 112, 50, "God", "Toggle", function() SendAction("god") end)
    Button(q, 706, 18, 112, 50, "Noclip", "Toggle", function() SendAction("noclip") end)
    Button(q, 830, 18, 112, 50, "Refresh", "Now", function() parent:Rebuild() end)

    Card(parent, 0, 304, 126, 72, "Props", tostring(stats.props), nil, Color(90,220,120))
    Card(parent, 138, 304, 126, 72, "Vehicles", tostring(stats.vehicles), nil, Color(80,160,255))
    Card(parent, 276, 304, 126, 72, "NPCs", tostring(stats.npcs), nil, Color(255,90,90))
    Card(parent, 414, 304, 126, 72, "Ragdolls", tostring(stats.ragdolls), nil, Color(255,190,80))
    Card(parent, 552, 304, 126, 72, "Effects", tostring(stats.effects), nil, Color(180,120,255))
    Card(parent, 690, 304, 126, 72, "Wire", tostring(stats.wire), nil, Color(80,200,255))
    Card(parent, 828, 304, 126, 72, "Lights", tostring(stats.lights), nil, Color(255,230,120))

    local cleanup = Panel(parent, 0, 396, 330, 170, function(_, w, h)
        draw.SimpleText("Smart Cleanup", "MN_Subtitle", 18, 24, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local cleanupActions = {
        {"Props", "cleanup_props"}, {"Vehicles", "cleanup_vehicles"}, {"NPCs", "cleanup_npcs"},
        {"Ragdolls", "cleanup_ragdolls"}, {"Effects", "cleanup_effects"}, {"Projectiles", "cleanup_projectiles"}
    }
    for i, item in ipairs(cleanupActions) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Button(cleanup, 18 + col * 148, 52 + row * 36, 136, 30, item[1], "", function()
            Confirm("Cleanup " .. item[1], "Remove " .. string.lower(item[1]) .. "?", function() SendAction(item[2]) end)
        end, true)
    end

    Graph(parent, 350, 396, 330, 170, "FPS", MetricValues("fps"), 160, Color(255,210,90))
    Graph(parent, 700, 396, 340, 170, "Entities", MetricValues("entities"), math.max(100, MetricMax("entities", 100)), theme.Orange)

    local playerPanel = Panel(parent, 0, 586, 1040, 230, function(_, w, h)
        draw.SimpleText("Live Player Cards", "MN_Subtitle", 18, 24, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Click a player to select. Buttons run immediately.", "MN_Text", 18, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local scroll = vgui.Create("DHorizontalScroller", playerPanel)
    scroll:SetPos(18, 72)
    scroll:SetSize(1004, 140)
    scroll:SetOverlap(-8)

    if MemoNetwork.Player and MemoNetwork.Player.Sort then
        SafeCall("Player.Sort", function() MemoNetwork.Player.Sort(players) end)
    end
    for _, ply in ipairs(players) do
        local holder = vgui.Create("DPanel")
        holder:SetSize(380, 122)
        holder.Paint = function() end
        PlayerCard(holder, ply, 0, 0, 380, 122, parent)
        scroll:AddPanel(holder)
    end
end

local function Build(parent)
    local ok, err = pcall(BuildUnsafe, parent)
    if not ok then
        MsgC(Color(255, 145, 0), "[MemoNetwork Control Center] ", Color(255, 90, 90), tostring(err) .. "\n")
        DrawError(parent, err)
    end
end

function MemoNetwork.ControlCenter.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end

    local theme = T()
    local sw, sh = ScrW(), ScrH()
    local w, h = math.min(1100, sw - 60), math.min(900, sh - 60)
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
        draw.SimpleText("MemoNetwork Control Center", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 16.2.1", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(frame, w - 56, 20, function() frame:Remove() frame = nil end)
    else
        local close = vgui.Create("DButton", frame)
        close:SetPos(w - 56, 20)
        close:SetSize(36, 36)
        close:SetText("X")
        close.DoClick = function() frame:Remove() frame = nil end
    end

    local content = vgui.Create("DScrollPanel", frame)
    content:SetPos(30, 100)
    content:SetSize(w - 60, h - 124)
    content.Rebuild = function(self) Build(self) end
    Build(content)
end

concommand.Add("mn_control", MemoNetwork.ControlCenter.Open)

hook.Add("PlayerButtonDown", "MemoNetwork_ControlCenter_F8", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F8 then
        MemoNetwork.ControlCenter.Open()
    end
end)
