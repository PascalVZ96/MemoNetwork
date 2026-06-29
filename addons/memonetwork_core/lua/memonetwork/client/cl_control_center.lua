-- MemoNetwork Alpha 16.2 Control Center
-- A focused F8 server control dashboard for quick actions, live players, cleanup and performance.

MemoNetwork = MemoNetwork or {}
MemoNetwork.ControlCenter = MemoNetwork.ControlCenter or {}

local frame
local selectedPlayer

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
        chat.AddText(Color(255, 145, 0), "[Control Center] ", color_white, message)
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

local function EntityStats()
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
end

local function PlayerCard(parent, ply, x, y, w, h)
    local theme = MemoNetwork.Theme
    local widgets = MemoNetwork.Widgets
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
        draw.SimpleText((IsValid(ply) and ply:Ping() or 0) .. " ms", "MN_Text", pw - 18, 25, MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText((IsValid(ply) and ply:Health() or 0) .. " HP / " .. (IsValid(ply) and ply:Armor() or 0) .. " AR", "MN_Small", pw - 18, 50, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    card.DoClick = function()
        selectedPlayer = ply
        if IsValid(parent.Root) and parent.Root.Rebuild then parent.Root:Rebuild() end
    end

    widgets.ActionButton(card, 14, 74, 82, 34, "Goto", "", function() SendTargetAction("teleport", ply) end)
    widgets.ActionButton(card, 104, 74, 82, 34, "Bring", "", function() SendTargetAction("bring", ply) end)
    widgets.ActionButton(card, 194, 74, 82, 34, "Heal", "", function() SendTargetAction("heal_target", ply) end)
    widgets.ActionButton(card, 284, 74, 82, 34, "Spec", "", function() SendTargetAction("spectate", ply) end)

    return card
end

local function BroadcastPopup()
    Derma_StringRequest("Control Center Broadcast", "Message to all players:", "Server restart in 5 minutes", function(text)
        text = string.Trim(text or "")
        if text == "" then Notify("Broadcast is empty.", "error") return end
        SendAction("broadcast", text)
    end)
end

local function Build(parent)
    parent:Clear()
    local theme = MemoNetwork.Theme
    local widgets = MemoNetwork.Widgets
    local metrics = MemoNetwork.Metrics
    local stats = EntityStats()
    local players = player.GetAll()
    local loaded, total = 0, 0
    if MemoNetwork.Addons and MemoNetwork.Addons.CountLoaded then loaded, total = MemoNetwork.Addons.CountLoaded() end

    widgets.Header(parent, 0, 0, 1040, 78, "Server Control Center", "F8 quick control dashboard for live administration", theme.Orange)

    widgets.StatCard(parent, 0, 98, 160, 80, "Server", "Online", game.GetMap(), theme.Success or Color(90,220,120))
    widgets.StatCard(parent, 174, 98, 160, 80, "Players", #players .. " / " .. game.MaxPlayers(), "connected", theme.Orange)
    widgets.StatCard(parent, 348, 98, 160, 80, "FPS", tostring(MemoNetwork.Metrics and MemoNetwork.Metrics.Latest("fps", math.floor(1 / FrameTime())) or math.floor(1 / FrameTime())), "client sample", Color(255,210,90))
    widgets.StatCard(parent, 522, 98, 160, 80, "Memory", (MemoNetwork.Metrics and MemoNetwork.Metrics.Latest("memory", math.floor(collectgarbage("count") / 1024)) or math.floor(collectgarbage("count") / 1024)) .. " MB", "lua", Color(180,120,255))
    widgets.StatCard(parent, 696, 98, 160, 80, "Entities", tostring(#ents.GetAll()), "total", theme.Orange)
    widgets.StatCard(parent, 870, 98, 170, 80, "Addons", loaded .. " / " .. total, "detected", loaded == total and (theme.Success or Color(90,220,120)) or Color(255,190,80))

    local q = widgets.Panel(parent, 0, 198, 1040, 86, function(_, w, h)
        draw.SimpleText("Quick Actions", "MN_Subtitle", 18, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Use carefully on live servers", "MN_Text", 18, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    widgets.ActionButton(q, 210, 18, 112, 50, "Cleanup", "All", function() Confirm("Cleanup", "Run full map cleanup?", function() SendAction("cleanup") end) end, {danger = true})
    widgets.ActionButton(q, 334, 18, 112, 50, "Restart", "Map", function() Confirm("Restart Map", "Restart current map?", function() SendAction("restart_map") end) end, {danger = true})
    widgets.ActionButton(q, 458, 18, 112, 50, "Broadcast", "Message", BroadcastPopup)
    widgets.ActionButton(q, 582, 18, 112, 50, "God", "Toggle", function() SendAction("god") end)
    widgets.ActionButton(q, 706, 18, 112, 50, "Noclip", "Toggle", function() SendAction("noclip") end)
    widgets.ActionButton(q, 830, 18, 112, 50, "Refresh", "Now", function() Build(parent) end)

    widgets.StatCard(parent, 0, 304, 126, 72, "Props", tostring(stats.props), nil, Color(90,220,120))
    widgets.StatCard(parent, 138, 304, 126, 72, "Vehicles", tostring(stats.vehicles), nil, Color(80,160,255))
    widgets.StatCard(parent, 276, 304, 126, 72, "NPCs", tostring(stats.npcs), nil, Color(255,90,90))
    widgets.StatCard(parent, 414, 304, 126, 72, "Ragdolls", tostring(stats.ragdolls), nil, Color(255,190,80))
    widgets.StatCard(parent, 552, 304, 126, 72, "Effects", tostring(stats.effects), nil, Color(180,120,255))
    widgets.StatCard(parent, 690, 304, 126, 72, "Wire", tostring(stats.wire), nil, Color(80,200,255))
    widgets.StatCard(parent, 828, 304, 126, 72, "Lights", tostring(stats.lights), nil, Color(255,230,120))

    local cleanup = widgets.Panel(parent, 0, 396, 330, 170, function(_, w, h)
        draw.SimpleText("Smart Cleanup", "MN_Subtitle", 18, 24, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local cleanupActions = {
        {"Props", "cleanup_props"}, {"Vehicles", "cleanup_vehicles"}, {"NPCs", "cleanup_npcs"},
        {"Ragdolls", "cleanup_ragdolls"}, {"Effects", "cleanup_effects"}, {"Projectiles", "cleanup_projectiles"}
    }
    for i, item in ipairs(cleanupActions) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        widgets.ActionButton(cleanup, 18 + col * 148, 52 + row * 36, 136, 30, item[1], "", function()
            Confirm("Cleanup " .. item[1], "Remove " .. string.lower(item[1]) .. "?", function() SendAction(item[2]) end)
        end, {danger = true})
    end

    widgets.Graph(parent, 350, 396, 330, 170, "FPS", metrics and metrics.Get("fps") or {}, 160, Color(255,210,90))
    widgets.Graph(parent, 700, 396, 340, 170, "Entities", metrics and metrics.Get("entities") or {}, math.max(100, metrics and metrics.Max("entities", 100) or 100), theme.Orange)

    local playerPanel = widgets.Panel(parent, 0, 586, 1040, 230, function(_, w, h)
        draw.SimpleText("Live Player Cards", "MN_Subtitle", 18, 24, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Click a player to select. Buttons run immediately.", "MN_Text", 18, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    playerPanel.Root = parent

    local scroll = vgui.Create("DHorizontalScroller", playerPanel)
    scroll:SetPos(18, 72)
    scroll:SetSize(1004, 140)
    scroll:SetOverlap(-8)

    if MemoNetwork.Player and MemoNetwork.Player.Sort then MemoNetwork.Player.Sort(players) end
    for _, ply in ipairs(players) do
        local card = vgui.Create("DPanel")
        card:SetSize(380, 122)
        card.Paint = function() end
        card.Root = parent
        PlayerCard(card, ply, 0, 0, 380, 122)
        scroll:AddPanel(card)
    end
end

function MemoNetwork.ControlCenter.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end

    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()
    local w, h = 1100, 900
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
        draw.SimpleText("Alpha 16.2", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(frame, w - 56, 20, function() frame:Remove() frame = nil end)
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
