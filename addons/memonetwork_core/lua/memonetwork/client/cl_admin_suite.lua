-- MemoNetwork Alpha 20 Admin Suite
-- Big-sprint hub that connects Control Center, Map Manager, Build Manager and Build Tools.

MemoNetwork = MemoNetwork or {}
MemoNetwork.AdminSuite = MemoNetwork.AdminSuite or {}

local frame
local highlightSteamID
local highlightUntil = 0

local function Theme()
    local t = MemoNetwork.Theme or {}
    return {
        orange = t.Orange or Color(255, 145, 0),
        text = t.Text or Color(245, 245, 245),
        muted = t.Muted or Color(155, 165, 180),
        bg = t.Background or Color(10, 14, 22, 238),
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
        MemoNetwork.Notify(message, kind or "info", "Admin Suite", 3)
    else
        chat.AddText(Color(255,145,0), "[Admin Suite] ", color_white, tostring(message or ""))
    end
end

local function OwnerInfo(ent)
    if not IsValid(ent) then return nil end
    local owner = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(owner) and owner:IsPlayer() then return owner:Nick(), owner:SteamID(), owner end
    local name = ent:GetNWString("MemoNetworkOwnerName", "")
    local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
    if sid ~= "" then return name ~= "" and name or sid, sid, nil end
end

local function EntityType(ent)
    if not IsValid(ent) then return "unknown" end
    local class = ent:GetClass() or ""
    if class == "prop_physics" or class == "prop_physics_multiplayer" then return "props" end
    if string.StartWith(class, "prop_vehicle") or string.StartWith(class, "gmod_sent_vehicle") then return "vehicles" end
    if ent:IsNPC() then return "npcs" end
    if class == "prop_ragdoll" then return "ragdolls" end
    if class == "gmod_lamp" or class == "gmod_light" or class == "light_dynamic" then return "lights" end
    if string.StartWith(class, "gmod_wire") or string.find(class, "wire", 1, true) then return "wire" end
    if string.StartWith(class, "gmod_") then return "other" end
    return "unknown"
end

local function Scan()
    local totals = {all = 0, props = 0, vehicles = 0, wire = 0, lights = 0, npcs = 0, owners = 0, unknown = 0}
    local owners = {}

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() then
            local typ = EntityType(ent)
            if typ ~= "unknown" then
                totals.all = totals.all + 1
                totals[typ] = (totals[typ] or 0) + 1
                local name, sid = OwnerInfo(ent)
                if sid and sid ~= "" then
                    owners[sid] = owners[sid] or {name = name or sid, steamID = sid, count = 0, props = 0, vehicles = 0, wire = 0}
                    owners[sid].name = name or owners[sid].name
                    owners[sid].count = owners[sid].count + 1
                    owners[sid][typ] = (owners[sid][typ] or 0) + 1
                else
                    totals.unknown = totals.unknown + 1
                end
            end
        end
    end

    local ownerList = {}
    for _, data in pairs(owners) do ownerList[#ownerList + 1] = data end
    table.sort(ownerList, function(a, b) return a.count > b.count end)
    totals.owners = #ownerList
    return totals, ownerList
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

local function Stat(parent, x, y, w, h, title, value, accent)
    local th = Theme()
    Box(parent, x, y, w, h, accent or th.orange, function(_, pw, ph)
        draw.SimpleText(string.upper(title), "MN_Small", 13, 16, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value), "MN_Subtitle", 13, 43, accent or th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
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
        draw.RoundedBox(10, 0, 0, pw, ph, Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 238))
        draw.RoundedBox(8, 0, ph - 5, pw, 5, danger and th.danger or th.orange)
        draw.SimpleText(title, "MN_Text", 14, subtitle and subtitle ~= "" and 17 or ph / 2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(subtitle, "MN_Small", 14, 39, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if fn then fn() end
    end
    return b
end

local function HighlightBuild(steamID)
    highlightSteamID = steamID
    highlightUntil = CurTime() + 8
    Notify("Highlighting build for 8 seconds.", "success")
end

hook.Add("PreDrawHalos", "MemoNetwork_AdminSuite_BuildHighlight", function()
    if not highlightSteamID or CurTime() > highlightUntil then return end
    local entsToHalo = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:GetNWString("MemoNetworkOwnerSteamID", "") == highlightSteamID then
            entsToHalo[#entsToHalo + 1] = ent
        end
    end
    if #entsToHalo > 0 then
        halo.Add(entsToHalo, Color(255, 145, 0), 3, 3, 2, true, true)
    end
end)

local function Build(parent)
    parent:Clear()
    local th = Theme()
    local totals, owners = Scan()
    local top = owners[1]

    Box(parent, 0, 0, 920, 72, th.orange, function(_, w, h)
        draw.SimpleText("Industrial Admin Suite", "MN_Title", 20, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 20 sprint hub: builds, maps, cleanup, highlights and server health", "MN_Text", 20, 52, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(game.GetMap(), "MN_Text", w - 20, 36, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    Stat(parent, 0, 88, 122, 66, "Entities", totals.all, th.orange)
    Stat(parent, 132, 88, 122, 66, "Owners", totals.owners, th.success)
    Stat(parent, 264, 88, 122, 66, "Props", totals.props, Color(90,220,120))
    Stat(parent, 396, 88, 122, 66, "Vehicles", totals.vehicles, th.blue)
    Stat(parent, 528, 88, 122, 66, "Wire", totals.wire, Color(80,200,255))
    Stat(parent, 660, 88, 122, 66, "Lights", totals.lights, Color(255,230,120))
    Stat(parent, 792, 88, 128, 66, "Unknown", totals.unknown, totals.unknown > 0 and th.warning or th.success)

    local launch = Box(parent, 0, 174, 440, 250, nil, function(_, w, h)
        draw.SimpleText("Quick Launch", "MN_Subtitle", 18, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Open the major MemoNetwork tools from one place", "MN_Small", 18, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Button(launch, 18, 76, 190, 48, "F8 Control Center", "Server actions", function() if MemoNetwork.ControlCenter then MemoNetwork.ControlCenter.Open() end end)
    Button(launch, 226, 76, 190, 48, "F9 Map Manager", "Map switching", function() if MemoNetwork.MapManager then MemoNetwork.MapManager.Open() end end)
    Button(launch, 18, 140, 190, 48, "F10 Build Manager", "Build overview", function() if MemoNetwork.BuildManager then MemoNetwork.BuildManager.Open() end end)
    Button(launch, 226, 140, 190, 48, "F11 Build Tools", "Cleanup/freeze", function() if MemoNetwork.BuildTools then MemoNetwork.BuildTools.Open() end end)

    local health = Box(parent, 460, 174, 460, 250, nil, function(_, w, h)
        draw.SimpleText("Server Health", "MN_Subtitle", 18, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Quick live indicators", "MN_Small", 18, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Stat(health, 18, 76, 130, 62, "Players", #player.GetAll() .. "/" .. game.MaxPlayers(), th.orange)
    Stat(health, 164, 76, 130, 62, "FPS", MemoNetwork.Metrics and MemoNetwork.Metrics.Latest("fps", math.floor(1 / FrameTime())) or math.floor(1 / FrameTime()), Color(255,210,90))
    Stat(health, 310, 76, 130, 62, "Memory", (MemoNetwork.Metrics and MemoNetwork.Metrics.Latest("memory", math.floor(collectgarbage("count") / 1024)) or math.floor(collectgarbage("count") / 1024)) .. " MB", th.purple)
    Stat(health, 18, 152, 130, 62, "NPCs", totals.npcs, th.danger)
    Stat(health, 164, 152, 130, 62, "Map", game.GetMap(), th.success)
    Stat(health, 310, 152, 130, 62, "Top Build", top and top.count or 0, th.warning)

    local builders = Box(parent, 0, 444, 920, 238, nil, function(_, w, h)
        draw.SimpleText("Top Builders", "MN_Subtitle", 18, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Highlight a build to find it in the world", "MN_Small", 18, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local x = 18
    for i = 1, math.min(4, #owners) do
        local owner = owners[i]
        local card = Box(builders, x, 76, 210, 136, owner.steamID == "unknown" and th.warning or th.orange, function(_, w, h)
            draw.SimpleText(owner.name or owner.steamID, "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(owner.count .. " entities", "MN_Text", 16, 54, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Props " .. (owner.props or 0) .. "  Vehicles " .. (owner.vehicles or 0), "MN_Small", 16, 80, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Wire " .. (owner.wire or 0), "MN_Small", 16, 100, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end)
        Button(card, 16, 96, 178, 30, "Highlight", "", function() HighlightBuild(owner.steamID) end)
        x = x + 224
    end
end

function MemoNetwork.AdminSuite.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end

    local th = Theme()
    local w, h = math.min(980, ScrW() - 60), math.min(820, ScrH() - 60)
    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, th.bg)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, th.orange, true, true, false, false)
        draw.SimpleText("MemoNetwork Industrial Admin Suite", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 20", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(w - 56, 20)
    close:SetSize(36, 36)
    close:SetText("X")
    close.DoClick = function() frame:Remove() frame = nil end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(30, 100)
    content:SetSize(920, h - 124)
    content.Paint = function() end
    Build(content)
end

concommand.Add("mn_suite", MemoNetwork.AdminSuite.Open)

hook.Add("PlayerButtonDown", "MemoNetwork_AdminSuite_F12", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F12 then MemoNetwork.AdminSuite.Open() end
end)
