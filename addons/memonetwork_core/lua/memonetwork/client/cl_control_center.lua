-- MemoNetwork Alpha 16.2.2 Control Center
-- Standalone F8 panel. No widget/scroll dependencies, fixed visible layout.

MemoNetwork = MemoNetwork or {}
MemoNetwork.ControlCenter = MemoNetwork.ControlCenter or {}

local frame
local selectedPlayer

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
        warning = Color(255, 190, 80)
    }
end

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
        MemoNetwork.Notify(message, kind or "info", "Control Center", 3)
    else
        chat.AddText(Color(255,145,0), "[Control Center] ", color_white, tostring(message or ""))
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

local function Confirm(title, text, fn)
    Derma_Query(text, title, "Yes", fn, "No")
end

local function EntityStats()
    local stats = {props = 0, vehicles = 0, npcs = 0, ragdolls = 0, effects = 0, wire = 0, lights = 0}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) then
            local class = ent:GetClass() or ""
            if class == "prop_physics" or class == "prop_physics_multiplayer" then stats.props = stats.props + 1 end
            if string.StartWith(class, "prop_vehicle") or string.StartWith(class, "gmod_sent_vehicle") then stats.vehicles = stats.vehicles + 1 end
            if ent:IsNPC() then stats.npcs = stats.npcs + 1 end
            if class == "prop_ragdoll" then stats.ragdolls = stats.ragdolls + 1 end
            if class == "env_sprite" or class == "env_smoketrail" or class == "env_fire" or class == "env_explosion" or class == "info_particle_system" then stats.effects = stats.effects + 1 end
            if string.StartWith(class, "gmod_wire") or string.find(class, "wire", 1, true) then stats.wire = stats.wire + 1 end
            if class == "gmod_lamp" or class == "gmod_light" or class == "light_dynamic" then stats.lights = stats.lights + 1 end
        end
    end
    return stats
end

local function MetricLatest(key, fallback)
    if MemoNetwork.Metrics and MemoNetwork.Metrics.Latest then
        local ok, value = pcall(MemoNetwork.Metrics.Latest, key, fallback)
        if ok and value ~= nil then return value end
    end
    return fallback
end

local function MetricValues(key)
    if MemoNetwork.Metrics and MemoNetwork.Metrics.Get then
        local ok, value = pcall(MemoNetwork.Metrics.Get, key)
        if ok and istable(value) then return value end
    end
    return {}
end

local function AddonCount()
    if MemoNetwork.Addons and MemoNetwork.Addons.CountLoaded then
        local ok, loaded, total = pcall(MemoNetwork.Addons.CountLoaded)
        if ok then return loaded or 0, total or 0 end
    end
    return 0, 0
end

local function PingColor(ping)
    if MemoNetwork.Player and MemoNetwork.Player.GetPingColor then
        local ok, value = pcall(MemoNetwork.Player.GetPingColor, ping)
        if ok and value then return value end
    end
    if ping < 60 then return Color(90, 220, 120) end
    if ping < 120 then return Color(255, 190, 80) end
    return Color(255, 90, 90)
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

local function Stat(parent, x, y, w, h, title, value, subtitle, accent)
    local th = Theme()
    return Box(parent, x, y, w, h, accent or th.orange, function(_, pw, ph)
        draw.SimpleText(string.upper(tostring(title or "STAT")), "MN_Small", 16, 17, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value or "-"), "MN_Subtitle", 16, 44, accent or th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(tostring(subtitle), "MN_Small", 16, 64, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end)
end

local function Action(parent, x, y, w, h, title, subtitle, fn, danger)
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
        draw.SimpleText(tostring(title or "Action"), "MN_Text", 14, subtitle and subtitle ~= "" and 17 or ph / 2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(tostring(subtitle), "MN_Small", 14, 38, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if fn then fn() end
    end
    return b
end

local function MiniGraph(parent, x, y, w, h, title, values, maxValue, accent)
    local th = Theme()
    values = istable(values) and values or {}
    maxValue = math.max(1, tonumber(maxValue) or 100)
    return Box(parent, x, y, w, h, nil, function(_, pw, ph)
        draw.SimpleText(title, "MN_Text", 14, 18, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local gx, gy = 14, 38
        local gw, gh = pw - 28, ph - 52
        draw.RoundedBox(8, gx, gy, gw, gh, Color(7, 10, 16, 210))
        if #values < 2 then
            draw.SimpleText("Collecting data", "MN_Small", pw / 2, gy + gh / 2, th.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end
        surface.SetDrawColor(accent or th.orange)
        for i = 2, #values do
            local x1 = gx + ((i - 2) / math.max(1, #values - 1)) * gw
            local x2 = gx + ((i - 1) / math.max(1, #values - 1)) * gw
            local y1 = gy + gh - math.Clamp((tonumber(values[i - 1]) or 0) / maxValue, 0, 1) * gh
            local y2 = gy + gh - math.Clamp((tonumber(values[i]) or 0) / maxValue, 0, 1) * gh
            surface.DrawLine(x1, y1, x2, y2)
        end
    end)
end

local function BroadcastPopup()
    Derma_StringRequest("Control Center Broadcast", "Message to all players:", "Server restart in 5 minutes", function(text)
        text = string.Trim(text or "")
        if text == "" then Notify("Broadcast is empty.", "error") return end
        SendAction("broadcast", text)
    end)
end

local function PlayerRow(parent, ply, x, y, w, h)
    local th = Theme()
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = th.text}
    local row = vgui.Create("DButton", parent)
    row:SetPos(x, y)
    row:SetSize(w, h)
    row:SetText("")
    row:SetCursor("hand")
    row.HoverAmount = 0

    local avatar = vgui.Create("AvatarImage", row)
    avatar:SetSize(36, 36)
    avatar:SetPos(12, 10)
    avatar:SetPlayer(ply, 36)
    avatar:SetMouseInputEnabled(false)

    row.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local selected = selectedPlayer == ply
        draw.RoundedBox(10, 0, 0, pw, ph, selected and Color(34, 45, 55, 245) or Color(18 + self.HoverAmount * 8, 24 + self.HoverAmount * 8, 32 + self.HoverAmount * 8, 238))
        draw.RoundedBox(6, 0, 0, selected and 8 or 5, ph, rank.color or th.orange)
        draw.SimpleText(IsValid(ply) and ply:Nick() or "Unknown", "MN_Text", 58, 18, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Small", 58, 40, rank.color or th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText((IsValid(ply) and ply:Ping() or 0) .. " ms", "MN_Text", pw - 16, 18, PingColor(IsValid(ply) and ply:Ping() or 0), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText((IsValid(ply) and ply:Health() or 0) .. " HP / " .. (IsValid(ply) and ply:Armor() or 0) .. " AR", "MN_Small", pw - 16, 40, th.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    row.DoClick = function() selectedPlayer = ply end

    return row
end

local function Build(content)
    content:Clear()
    local th = Theme()
    local stats = EntityStats()
    local players = player.GetAll()
    local loaded, total = AddonCount()
    if MemoNetwork.Player and MemoNetwork.Player.Sort then pcall(MemoNetwork.Player.Sort, players) end
    if not IsValid(selectedPlayer) then selectedPlayer = players[1] end

    Box(content, 0, 0, 876, 72, th.orange, function(_, w, h)
        draw.SimpleText("Server Control Center", "MN_Title", 20, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Stable F8 panel - no external widget dependency", "MN_Text", 20, 52, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(os.date("%H:%M:%S"), "MN_Text", w - 20, 36, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    Stat(content, 0, 88, 136, 74, "Server", "Online", game.GetMap(), th.success)
    Stat(content, 148, 88, 136, 74, "Players", #players .. "/" .. game.MaxPlayers(), "connected", th.orange)
    Stat(content, 296, 88, 136, 74, "FPS", MetricLatest("fps", math.floor(1 / FrameTime())), "client", Color(255,210,90))
    Stat(content, 444, 88, 136, 74, "Memory", MetricLatest("memory", math.floor(collectgarbage("count") / 1024)) .. " MB", "lua", Color(180,120,255))
    Stat(content, 592, 88, 136, 74, "Entities", #ents.GetAll(), "total", th.orange)
    Stat(content, 740, 88, 136, 74, "Addons", loaded .. "/" .. total, "detected", total > 0 and loaded == total and th.success or th.warning)

    local quick = Box(content, 0, 178, 876, 76, nil, function(_, w, h)
        draw.SimpleText("Quick Actions", "MN_Subtitle", 16, 20, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Cleanup / restart / broadcast / refresh", "MN_Small", 16, 46, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Action(quick, 210, 14, 102, 48, "Cleanup", "All", function() Confirm("Cleanup", "Run full map cleanup?", function() SendAction("cleanup") end) end, true)
    Action(quick, 322, 14, 102, 48, "Restart", "Map", function() Confirm("Restart", "Restart current map?", function() SendAction("restart_map") end) end, true)
    Action(quick, 434, 14, 102, 48, "Broadcast", "Msg", BroadcastPopup)
    Action(quick, 546, 14, 102, 48, "God", "Toggle", function() SendAction("god") end)
    Action(quick, 658, 14, 102, 48, "Noclip", "Toggle", function() SendAction("noclip") end)
    Action(quick, 770, 14, 90, 48, "Refresh", "", function() Build(content) end)

    Stat(content, 0, 270, 116, 68, "Props", stats.props, nil, Color(90,220,120))
    Stat(content, 126, 270, 116, 68, "Vehicles", stats.vehicles, nil, Color(80,160,255))
    Stat(content, 252, 270, 116, 68, "NPCs", stats.npcs, nil, th.danger)
    Stat(content, 378, 270, 116, 68, "Ragdolls", stats.ragdolls, nil, th.warning)
    Stat(content, 504, 270, 116, 68, "Effects", stats.effects, nil, Color(180,120,255))
    Stat(content, 630, 270, 116, 68, "Wire", stats.wire, nil, Color(80,200,255))
    Stat(content, 756, 270, 116, 68, "Lights", stats.lights, nil, Color(255,230,120))

    local cleanup = Box(content, 0, 354, 276, 164, nil, function(_, w, h)
        draw.SimpleText("Smart Cleanup", "MN_Subtitle", 16, 22, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local acts = {{"Props","cleanup_props"},{"Vehicles","cleanup_vehicles"},{"NPCs","cleanup_npcs"},{"Ragdolls","cleanup_ragdolls"},{"Effects","cleanup_effects"},{"Projectiles","cleanup_projectiles"}}
    for i, a in ipairs(acts) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Action(cleanup, 16 + col * 124, 48 + row * 34, 112, 28, a[1], "", function()
            Confirm("Cleanup " .. a[1], "Remove " .. string.lower(a[1]) .. "?", function() SendAction(a[2]) end)
        end, true)
    end

    MiniGraph(content, 292, 354, 276, 164, "FPS", MetricValues("fps"), 160, Color(255,210,90))
    MiniGraph(content, 584, 354, 292, 164, "Entities", MetricValues("entities"), math.max(100, MetricLatest("entities", #ents.GetAll())), th.orange)

    local playerBox = Box(content, 0, 534, 876, 190, nil, function(_, w, h)
        draw.SimpleText("Players", "MN_Subtitle", 16, 22, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Select a player, then use actions on the right", "MN_Small", 16, 46, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local y = 66
    for i, ply in ipairs(players) do
        if i > 3 then break end
        PlayerRow(playerBox, ply, 16, y, 430, 56)
        y = y + 62
    end

    local detail = Box(playerBox, 470, 66, 390, 108, selectedPlayer and (MemoNetwork.Ranks and MemoNetwork.Ranks.Get(selectedPlayer) and MemoNetwork.Ranks.Get(selectedPlayer).color or th.orange) or th.orange, function(_, w, h)
        if not IsValid(selectedPlayer) then
            draw.SimpleText("No player selected", "MN_Subtitle", 18, 28, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return
        end
        local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(selectedPlayer) or {name="PLAYER", color=th.orange}
        draw.SimpleText(selectedPlayer:Nick(), "MN_Subtitle", 18, 26, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Small", 18, 50, rank.color or th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selectedPlayer:SteamID(), "MN_Small", 18, 72, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Action(detail, 18, 72, 78, 28, "Goto", "", function() SendTargetAction("teleport", selectedPlayer) end)
    Action(detail, 104, 72, 78, 28, "Bring", "", function() SendTargetAction("bring", selectedPlayer) end)
    Action(detail, 190, 72, 78, 28, "Heal", "", function() SendTargetAction("heal_target", selectedPlayer) end)
    Action(detail, 276, 72, 78, 28, "Spec", "", function() SendTargetAction("spectate", selectedPlayer) end)
end

function MemoNetwork.ControlCenter.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end

    local th = Theme()
    local w, h = 940, 820
    w = math.min(w, ScrW() - 60)
    h = math.min(h, ScrH() - 60)

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
        draw.SimpleText("MemoNetwork Control Center", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 16.2.2", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(w - 56, 20)
    close:SetSize(36, 36)
    close:SetText("")
    close.Paint = function(self, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, Color(95, 48, 18, self:IsHovered() and 255 or 230))
        draw.SimpleText("X", "MN_Title", pw / 2, ph / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() frame:Remove() frame = nil end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(32, 100)
    content:SetSize(876, 724)
    content.Paint = function() end
    content.Rebuild = function(self) Build(self) end
    local ok, err = pcall(Build, content)
    if not ok then
        MsgC(Color(255,145,0), "[MemoNetwork Control Center] ", Color(255,90,90), tostring(err) .. "\n")
        content.Paint = function(_, cw, ch)
            draw.RoundedBox(12, 0, 0, cw, 160, th.panel2)
            draw.RoundedBox(6, 0, 0, 7, 160, th.danger)
            draw.SimpleText("Control Center Error", "MN_Title", 22, 34, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(err), "MN_Text", 22, 76, th.danger, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

concommand.Add("mn_control", MemoNetwork.ControlCenter.Open)

hook.Add("PlayerButtonDown", "MemoNetwork_ControlCenter_F8", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F8 then
        MemoNetwork.ControlCenter.Open()
    end
end)
