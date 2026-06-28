-- MemoNetwork Alpha 14 Admin Panel
-- F6 server management suite: status, players, maps, performance, workshop, cleanup, ranks, broadcast and logs.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Admin = MemoNetwork.Admin or {}

local panel
local activeTab = "Dashboard"
local selectedPlayer
local adminLogs = adminLogs or {}

local function HasPerm(permission)
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then return MemoNetwork.Ranks.HasPermission(ply, permission) end
    return ply:IsAdmin()
end

local function IsAllowed() return HasPerm("admin.open") end

local function Notify(message, kind, title)
    if MemoNetwork.Notify then MemoNetwork.Notify(message, kind or "info", title or "Admin", 3) else chat.AddText(Color(255,145,0), "[MemoNetwork] ", color_white, message) end
end

local function AddLocalLog(actor, message, kind)
    table.insert(adminLogs, 1, {time = os.date("%H:%M:%S"), actor = actor or "Client", message = message or "", kind = kind or "info"})
    while #adminLogs > 80 do table.remove(adminLogs) end
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

local function SendRank(target, rankName)
    if not IsValid(target) then return end
    net.Start("MemoNetwork_SetRank")
        net.WriteEntity(target)
        net.WriteString(rankName)
    net.SendToServer()
end

local function Confirm(title, text, confirmText, onConfirm)
    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()
    local w, h = 430, 210
    local frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:SetPos((sw - w) / 2, (sh - h) / 2)
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.10, 0)
    frame.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 62, theme.Orange, true, true, false, false)
        draw.SimpleText(title, "MN_Title", 22, 31, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, "MN_Text", 22, 94, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Players online: " .. #player.GetAll(), "MN_Text", 22, 124, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local cancel = vgui.Create("DButton", frame)
    cancel:SetPos(22, 154) cancel:SetSize(180, 38) cancel:SetText("")
    cancel.Paint = function(self, pw, ph) draw.RoundedBox(8, 0, 0, pw, ph, self:IsHovered() and Color(42,48,58) or theme.Panel) draw.SimpleText("Cancel", "MN_Text", pw / 2, ph / 2, theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
    cancel.DoClick = function() frame:Remove() end
    local ok = vgui.Create("DButton", frame)
    ok:SetPos(228, 154) ok:SetSize(180, 38) ok:SetText("")
    ok.Paint = function(self, pw, ph) draw.RoundedBox(8, 0, 0, pw, ph, self:IsHovered() and Color(255,170,40) or theme.Orange) draw.SimpleText(confirmText or "Confirm", "MN_Text", pw / 2, ph / 2, Color(10,10,10), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
    ok.DoClick = function() frame:Remove() if onConfirm then onConfirm() end end
end

net.Receive("MemoNetwork_AdminResult", function()
    local message = net.ReadString()
    local kind = net.ReadString()
    AddLocalLog("Server", message, kind)
    Notify(message, kind, "Admin")
end)

net.Receive("MemoNetwork_AdminLog", function()
    table.insert(adminLogs, 1, {time = net.ReadString(), actor = net.ReadString(), message = net.ReadString(), kind = net.ReadString()})
    while #adminLogs > 80 do table.remove(adminLogs) end
end)

net.Receive("MemoNetwork_Broadcast", function()
    local actor = net.ReadString()
    local message = net.ReadString()
    Notify(message, "info", "Broadcast - " .. actor)
    chat.AddText(Color(255,145,0), "[Broadcast] ", Color(240,240,240), message)
end)

local function KindColor(kind)
    local theme = MemoNetwork.Theme
    if kind == "success" then return theme.Success or Color(90,220,120) end
    if kind == "warning" then return Color(255,190,80) end
    if kind == "error" then return Color(255,90,90) end
    return theme.Orange or Color(255,145,0)
end

local function Card(parent, x, y, w, h, title, value, subtitle, color)
    local theme = MemoNetwork.Theme
    local card = vgui.Create("DPanel", parent)
    card:SetPos(x, y) card:SetSize(w, h)
    card.Paint = function(_, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, theme.PanelLight)
        draw.RoundedBox(6, 0, 0, 6, ph, color or theme.Orange)
        draw.SimpleText(string.upper(title), "MN_Small", 16, 18, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "MN_Subtitle", 16, 47, color or theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle then draw.SimpleText(subtitle, "MN_Small", 16, 68, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    return card
end

local function Button(parent, x, y, w, h, title, subtitle, onClick, dangerous)
    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y) btn:SetSize(w, h) btn:SetText("") btn:SetCursor("hand") btn.HoverAmount = 0
    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
        local accent = dangerous and Color(255,90,90) or theme.Orange
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, ph - 5, pw, 5, accent)
        draw.SimpleText(title, "MN_Subtitle", 16, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle or "", "MN_Text", 16, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function() surface.PlaySound("buttons/button15.wav") if onClick then onClick() end end
    return btn
end

local function TabButton(parent, x, y, w, h, label, content)
    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y) btn:SetSize(w, h) btn:SetText("") btn:SetCursor("hand") btn.HoverAmount = 0
    btn.Paint = function(self, pw, ph)
        local selected = activeTab == label
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = selected and Color(30,38,48,245) or Color(15 + self.HoverAmount * 8, 20 + self.HoverAmount * 8, 28 + self.HoverAmount * 8, 230)
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(6, 0, 0, selected and 7 or 4, ph, selected and theme.Orange or Color(255,145,0,120))
        draw.SimpleText(label, "MN_Subtitle", 18, ph / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function() activeTab = label surface.PlaySound("buttons/button15.wav") if IsValid(content) and content.Rebuild then content:Rebuild() end end
    return btn
end

local function BuildDashboard(content)
    local ply = LocalPlayer()
    local theme = MemoNetwork.Theme
    Card(content, 0, 0, 160, 84, "Status", "Online", game.GetMap(), theme.Success or Color(90,220,120))
    Card(content, 176, 0, 160, 84, "Players", #player.GetAll() .. " / " .. game.MaxPlayers(), "connected", theme.Orange)
    Card(content, 352, 0, 160, 84, "Ping", (IsValid(ply) and ply:Ping() or 0) .. " ms", "your latency", MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Orange)
    Card(content, 0, 104, 160, 84, "Entities", tostring(#ents.GetAll()), "world total", Color(180,120,255))
    Card(content, 176, 104, 160, 84, "FPS", tostring(math.floor(1 / FrameTime())), "client fps", Color(255,210,90))
    Card(content, 352, 104, 160, 84, "Version", MemoNetwork.Config.Version or "Alpha", "MemoNetwork", theme.Orange)

    local box = vgui.Create("DPanel", content)
    box:SetPos(0, 212) box:SetSize(512, 192)
    box.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight)
        draw.SimpleText("Alpha 14 Server Management", "MN_Title", 24, 34, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("F6 now acts as a real server control panel.", "MN_Text", 24, 76, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("New: Performance, Workshop, Server tools and stronger player actions.", "MN_Text", 24, 108, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Next: XP, achievements, daily rewards and leaderboards.", "MN_Text", 24, 140, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function PlayerRow(parent, ply, x, y, w, selected)
    local theme = MemoNetwork.Theme
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = theme.Text}
    local row = vgui.Create("DButton", parent)
    row:SetPos(x, y) row:SetSize(w, 58) row:SetText("") row:SetCursor("hand") row.HoverAmount = 0
    local avatar = vgui.Create("AvatarImage", row)
    avatar:SetSize(38, 38) avatar:SetPos(12, 10) avatar:SetPlayer(ply, 38) avatar:SetMouseInputEnabled(false)
    row.Paint = function(self, rw, rh)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = selectedPlayer == ply and Color(34,45,55,245) or Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
        draw.RoundedBox(10, 0, 0, rw, rh, bg)
        draw.RoundedBox(6, 0, 0, selectedPlayer == ply and 8 or 5, rh, rank.color or theme.Orange)
        draw.SimpleText(IsValid(ply) and ply:Nick() or "Unknown", "MN_Text", 62, 21, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Small", 62, 42, rank.color or theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(IsValid(ply) and (ply:Ping() .. " ms") or "0 ms", "MN_Text", rw - 18, rh / 2, MemoNetwork.Player and MemoNetwork.Player.GetPingColor(IsValid(ply) and ply:Ping() or 0) or theme.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    row.DoClick = function() selectedPlayer = ply if IsValid(parent.RootContent) and parent.RootContent.Rebuild then parent.RootContent:Rebuild() end end
    return row
end

local function BuildPlayers(content)
    local theme = MemoNetwork.Theme
    local list = vgui.Create("DPanel", content)
    list:SetPos(0, 0) list:SetSize(250, 410) list.Paint = function() end list.RootContent = content
    local players = player.GetAll()
    if MemoNetwork.Player and MemoNetwork.Player.Sort then MemoNetwork.Player.Sort(players) end
    if not IsValid(selectedPlayer) then selectedPlayer = players[1] end
    local y = 0
    for _, ply in ipairs(players) do PlayerRow(list, ply, 0, y, 250) y = y + 68 end

    local details = vgui.Create("DPanel", content)
    details:SetPos(268, 0) details:SetSize(244, 410)
    details.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight)
        if not IsValid(selectedPlayer) then draw.SimpleText("Select a player", "MN_Subtitle", 18, 28, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) return end
        local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(selectedPlayer) or {name="PLAYER", color=theme.Text}
        draw.SimpleText(selectedPlayer:Nick(), "MN_Subtitle", 18, 28, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Text", 18, 56, rank.color or theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selectedPlayer:SteamID(), "MN_Small", 18, 82, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("HP " .. selectedPlayer:Health() .. "  Armor " .. selectedPlayer:Armor(), "MN_Text", 18, 112, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local actions = {
        {"Teleport", "Go to player", "teleport"}, {"Bring", "Bring here", "bring"},
        {"Heal", "HP + armor", "heal_target"}, {"Freeze", "Toggle freeze", "freeze"},
        {"Slay", "Kill player", "slay"}, {"Respawn", "Force spawn", "respawn"},
        {"Spectate", "Watch player", "spectate"}, {"Kick", "Remove player", "kick", true}
    }
    local ax, ay = 18, 138
    for i, a in ipairs(actions) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Button(details, ax + col * 104, ay + row * 58, 96, 48, a[1], a[2], function()
            if a[4] then Confirm(a[1], a[2] .. "?", a[1], function() SendTargetAction(a[3], selectedPlayer) end) else SendTargetAction(a[3], selectedPlayer) end
        end, a[4])
    end
end

local function BuildMaps(content)
    local theme = MemoNetwork.Theme
    local info = vgui.Create("DPanel", content)
    info:SetPos(0, 0) info:SetSize(512, 62)
    info.Paint = function(_, w, h) draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight) draw.SimpleText("Map Manager", "MN_Subtitle", 18, 20, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) draw.SimpleText("Current: " .. game.GetMap(), "MN_Text", 18, 45, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    Button(content, 352, 0, 160, 62, "Restart", "Current map", function() Confirm("Restart Map", "Reload " .. game.GetMap() .. "?", "Restart", function() SendAction("restart_map") end) end, true)
    local y = 82
    for _, data in ipairs(MemoNetwork.Config.Maps or {}) do
        local mapName = data.map or ""
        local row = vgui.Create("DButton", content)
        row:SetPos(0, y) row:SetSize(512, 58) row:SetText("") row:SetCursor("hand") row.HoverAmount = 0
        row.Paint = function(self, w, h)
            self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
            local current = game.GetMap() == mapName
            draw.RoundedBox(10, 0, 0, w, h, current and Color(34,45,55,245) or Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235))
            draw.RoundedBox(6, 0, 0, current and 8 or 5, h, current and (theme.Success or Color(90,220,120)) or theme.Orange)
            draw.SimpleText(data.name or mapName, "MN_Subtitle", 18, 19, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(mapName .. " - " .. (data.description or "Sandbox map"), "MN_Small", 18, 42, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(current and "CURRENT" or "CHANGE", "MN_Small", w - 18, h / 2, current and (theme.Success or Color(90,220,120)) or theme.Orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function() Confirm("Change Map", "Change server to " .. mapName .. "?", "Change", function() SendAction("change_map", mapName) end) end
        y = y + 68
    end
end

local function BuildPerformance(content)
    local props = 0 local vehicles = 0 local npcs = 0
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) then
            local class = ent:GetClass()
            if class == "prop_physics" or class == "prop_physics_multiplayer" then props = props + 1 end
            if string.StartWith(class, "prop_vehicle") then vehicles = vehicles + 1 end
            if ent:IsNPC() then npcs = npcs + 1 end
        end
    end
    Card(content, 0, 0, 160, 84, "FPS", tostring(math.floor(1 / FrameTime())), "client", Color(255,210,90))
    Card(content, 176, 0, 160, 84, "Lua Memory", math.floor(collectgarbage("count") / 1024) .. " MB", "client", Color(180,120,255))
    Card(content, 352, 0, 160, 84, "Entities", tostring(#ents.GetAll()), "total", MemoNetwork.Theme.Orange)
    Card(content, 0, 104, 160, 84, "Props", tostring(props), "physics", Color(90,220,120))
    Card(content, 176, 104, 160, 84, "Vehicles", tostring(vehicles), "spawned", Color(80,160,255))
    Card(content, 352, 104, 160, 84, "NPCs", tostring(npcs), "active", Color(255,90,90))
end

local function BuildTools(content)
    Button(content, 0, 0, 160, 76, "God Mode", "Toggle god mode", function() SendAction("god") end)
    Button(content, 176, 0, 160, 76, "Noclip", "Toggle noclip", function() SendAction("noclip") end)
    Button(content, 352, 0, 160, 76, "Heal", "100 HP + armor", function() SendAction("health") end)
    Button(content, 0, 100, 160, 76, "Cleanup All", "Full cleanup", function() Confirm("Cleanup All", "Clean the map?", "Cleanup", function() SendAction("cleanup") end) end, true)
    Button(content, 176, 100, 160, 76, "Restart Map", "Reload current", function() Confirm("Restart Map", "Reload current map?", "Restart", function() SendAction("restart_map") end) end, true)
end

local function BuildCleanup(content)
    local actions = {{"Props","Remove props","cleanup_props"},{"Vehicles","Remove vehicles","cleanup_vehicles"},{"NPCs","Remove NPCs","cleanup_npcs"},{"Ragdolls","Remove ragdolls","cleanup_ragdolls"},{"Effects","Remove effects","cleanup_effects"},{"Projectiles","Remove projectiles","cleanup_projectiles"}}
    for i, a in ipairs(actions) do
        local col = (i - 1) % 3 local row = math.floor((i - 1) / 3)
        Button(content, col * 176, row * 94, 160, 76, a[1], a[2], function() Confirm(a[1], a[2] .. "?", "Remove", function() SendAction(a[3]) end) end, true)
    end
    Button(content, 0, 212, 512, 76, "Cleanup Everything", "Full map cleanup", function() Confirm("Cleanup Everything", "Full map cleanup?", "Cleanup", function() SendAction("cleanup") end) end, true)
end

local function BuildWorkshop(content)
    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config or {}
    local box = vgui.Create("DPanel", content)
    box:SetPos(0, 0) box:SetSize(512, 168)
    box.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight)
        draw.SimpleText("Workshop Manager", "MN_Title", 24, 34, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Collection link: " .. tostring(cfg.Workshop or "Coming soon"), "MN_Text", 24, 78, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Next step: collection ID checks and missing addon detection.", "MN_Text", 24, 112, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    Button(content, 0, 194, 160, 76, "Open Workshop", "Required addons", function() if string.StartWith(tostring(cfg.Workshop), "http") then gui.OpenURL(cfg.Workshop) else Notify("Workshop is not configured yet.", "warning") end end)
    Button(content, 176, 194, 160, 76, "Help", "Workshop setup", function() Notify("Set MemoNetwork.Config.Workshop or host_workshop_collection.", "info", "Workshop") end)
end

local function BuildBroadcast(content)
    local theme = MemoNetwork.Theme
    local box = vgui.Create("DPanel", content)
    box:SetPos(0, 0) box:SetSize(512, 190)
    box.Paint = function(_, w, h) draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight) draw.SimpleText("Broadcast", "MN_Title", 18, 30, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) draw.SimpleText("Send a MemoNetwork popup to all players.", "MN_Text", 18, 64, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    local entry = vgui.Create("DTextEntry", box)
    entry:SetPos(18, 92) entry:SetSize(476, 36) entry:SetFont("MN_Text") entry:SetPlaceholderText("Example: Server restart in 5 minutes") entry:SetTextColor(theme.Text) entry:SetPlaceholderColor(theme.Muted) entry:SetDrawBackground(false)
    entry.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, theme.Panel) self:DrawTextEntryText(theme.Text, theme.Orange, theme.Text) end
    Button(content, 0, 212, 160, 76, "Send", "Broadcast message", function() local msg = string.Trim(entry:GetText() or "") if msg == "" then Notify("Broadcast is empty.", "error") return end SendAction("broadcast", msg) entry:SetText("") end)
end

local function BuildLogs(content)
    local theme = MemoNetwork.Theme
    local header = vgui.Create("DPanel", content)
    header:SetPos(0, 0) header:SetSize(512, 54)
    header.Paint = function(_, w, h) draw.RoundedBox(10, 0, 0, w, h, theme.PanelLight) draw.SimpleText("Live Server Logs", "MN_Subtitle", 18, h / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) draw.SimpleText(#adminLogs .. " entries", "MN_Small", w - 18, h / 2, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
    local scroll = vgui.Create("DScrollPanel", content)
    scroll:SetPos(0, 70) scroll:SetSize(512, 340)
    local y = 0
    for _, log in ipairs(adminLogs) do
        local row = vgui.Create("DPanel", scroll)
        row:SetPos(0, y) row:SetSize(500, 48)
        row.Paint = function(_, w, h) local c = KindColor(log.kind) draw.RoundedBox(8, 0, 0, w, h, theme.PanelLight) draw.RoundedBox(6, 0, 0, 5, h, c) draw.SimpleText("[" .. (log.time or "--:--:--") .. "] " .. (log.actor or "Server"), "MN_Small", 16, 14, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) draw.SimpleText(log.message or "", "MN_Text", 16, 34, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        y = y + 56
    end
end

local function BuildRanks(content)
    local theme = MemoNetwork.Theme
    if not HasPerm("ranks.manage") then Card(content,0,0,512,84,"Ranks","Locked","Missing ranks.manage",Color(255,90,90)) return end
    local y = 0
    for _, ply in ipairs(player.GetAll()) do
        local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.GetName(ply) or "PLAYER"
        local row = vgui.Create("DPanel", content)
        row:SetPos(0,y) row:SetSize(512,62)
        row.Paint = function(_,w,h) draw.RoundedBox(10,0,0,w,h,theme.PanelLight) draw.SimpleText(ply:Nick(),"MN_Text",18,20,theme.Text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) draw.SimpleText(ply:SteamID(),"MN_Small",18,44,theme.Muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
        local combo = vgui.Create("DComboBox", row)
        combo:SetPos(300,14) combo:SetSize(120,34) combo:SetFont("MN_Text") combo:SetValue(rank)
        for _, r in ipairs(MemoNetwork.Ranks.Order or {}) do combo:AddChoice(r) end
        Button(row, 430, 14, 66, 34, "Save", "", function() SendRank(ply, combo:GetValue()) end)
        y = y + 72
    end
end

local function BuildPermissions(content)
    local theme = MemoNetwork.Theme
    local y = 0
    local ordered = {}
    for key, data in pairs((MemoNetwork.Ranks and MemoNetwork.Ranks.Definitions) or {}) do ordered[#ordered + 1] = {key=key,data=data} end
    table.sort(ordered, function(a,b) return (a.data.sort or 99) < (b.data.sort or 99) end)
    for _, item in ipairs(ordered) do
        local perms = table.concat(item.data.permissions or {}, ", ") if perms == "" then perms = "No admin permissions" end
        local row = vgui.Create("DPanel", content)
        row:SetPos(0,y) row:SetSize(512,72)
        row.Paint = function(_,w,h) draw.RoundedBox(10,0,0,w,h,theme.PanelLight) draw.RoundedBox(6,0,0,6,h,item.data.color or theme.Orange) draw.SimpleText(item.data.name or item.key,"MN_Subtitle",18,22,item.data.color or theme.Text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) draw.SimpleText(perms,"MN_Small",18,52,theme.Muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
        y = y + 82
    end
end

local function BuildContent(content)
    content:Clear()
    if activeTab == "Dashboard" then BuildDashboard(content)
    elseif activeTab == "Players" then BuildPlayers(content)
    elseif activeTab == "Maps" then BuildMaps(content)
    elseif activeTab == "Performance" then BuildPerformance(content)
    elseif activeTab == "Tools" then BuildTools(content)
    elseif activeTab == "Cleanup" then BuildCleanup(content)
    elseif activeTab == "Workshop" then BuildWorkshop(content)
    elseif activeTab == "Ranks" then BuildRanks(content)
    elseif activeTab == "Permissions" then BuildPermissions(content)
    elseif activeTab == "Broadcast" then BuildBroadcast(content)
    elseif activeTab == "Logs" then BuildLogs(content)
    end
end

function MemoNetwork.Admin.Open()
    if not IsAllowed() then Notify("Admin panel is owner/admin only.", "error") return end
    if IsValid(panel) then panel:Remove() panel = nil return end
    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config or {}
    local sw, sh = ScrW(), ScrH()
    local w, h = 940, 620
    panel = vgui.Create("DFrame")
    panel:SetSize(w,h) panel:SetPos((sw-w)/2,(sh-h)/2) panel:SetTitle("") panel:SetDraggable(false) panel:ShowCloseButton(false) panel:MakePopup() panel:SetAlpha(0) panel:AlphaTo(255,0.12,0)
    panel.Paint = function(_,pw,ph) draw.RoundedBox(14,0,0,pw,ph,theme.Background) draw.RoundedBoxEx(14,0,0,pw,78,theme.Orange,true,true,false,false) draw.SimpleText("MemoNetwork Admin", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) draw.SimpleText((cfg.Version or "Alpha") .. "  -  Server Management", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then MemoNetwork.UI.CreateCloseButton(panel, w - 56, 20, function() panel:Remove() panel = nil end) end
    local sidebar = vgui.Create("DPanel", panel)
    sidebar:SetPos(18,98) sidebar:SetSize(260,h-116) sidebar.Paint = function(_,pw,ph) draw.RoundedBox(12,0,0,pw,ph,theme.Panel) end
    local content = vgui.Create("DPanel", panel)
    content:SetPos(296,98) content:SetSize(w-314,h-116) content.Paint = function() end content.Rebuild = function(self) BuildContent(self) end
    local tabs = {"Dashboard","Players","Maps","Performance","Tools","Cleanup","Workshop","Ranks","Permissions","Broadcast","Logs"}
    local y = 10
    for _, tab in ipairs(tabs) do TabButton(sidebar,16,y,228,38,tab,content) y = y + 43 end
    BuildContent(content)
end

concommand.Add("mn_admin", function() MemoNetwork.Admin.Open() end)
hook.Add("PlayerButtonDown", "MemoNetwork_Admin_F6", function(ply, button) if ply == LocalPlayer() and button == KEY_F6 then MemoNetwork.Admin.Open() end end)
