-- MemoNetwork Alpha 21 Live World Manager
-- Large sprint preview: build map, player tracker, entity browser, world overlays and highlights.

MemoNetwork = MemoNetwork or {}
MemoNetwork.WorldManager = MemoNetwork.WorldManager or {}

local frame
local activeTab = "Map"
local selectedSteamID
local searchText = ""
local highlightSteamID
local highlightUntil = 0
local overlaysEnabled = true

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
    if MemoNetwork.Notify then MemoNetwork.Notify(message, kind or "info", "World Manager", 3) else chat.AddText(Color(255,145,0), "[World Manager] ", color_white, tostring(message or "")) end
end

local function OwnerInfo(ent)
    if not IsValid(ent) then return "Unknown", "unknown", nil end
    local owner = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(owner) and owner:IsPlayer() then return owner:Nick(), owner:SteamID(), owner end
    local name = ent:GetNWString("MemoNetworkOwnerName", "")
    local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
    if sid ~= "" then return name ~= "" and name or sid, sid, nil end
    return "Unknown", "unknown", nil
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
    if class == "env_sprite" or class == "env_smoketrail" or class == "env_fire" or class == "env_explosion" or class == "info_particle_system" then return "effects" end
    if string.StartWith(class, "gmod_") then return "other" end
    return "unknown"
end

local function ModelName(ent)
    local model = IsValid(ent) and ent:GetModel() or ""
    model = tostring(model or "")
    if model == "" then return "no model" end
    local parts = string.Explode("/", model)
    return parts[#parts] or model
end

local function BoundsFromEntities(list)
    local minX, minY, maxX, maxY
    for _, ent in ipairs(list) do
        if IsValid(ent) then
            local p = ent:GetPos()
            minX = minX and math.min(minX, p.x) or p.x
            minY = minY and math.min(minY, p.y) or p.y
            maxX = maxX and math.max(maxX, p.x) or p.x
            maxY = maxY and math.max(maxY, p.y) or p.y
        end
    end
    minX = minX or -4096; minY = minY or -4096; maxX = maxX or 4096; maxY = maxY or 4096
    local pad = 700
    return minX - pad, minY - pad, maxX + pad, maxY + pad
end

local function ScanWorld()
    local entities = {}
    local owners = {}
    local totals = {all = 0, owned = 0, unknown = 0, props = 0, vehicles = 0, wire = 0, lights = 0, npcs = 0, ragdolls = 0, effects = 0, other = 0}

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() then
            local typ = EntityType(ent)
            if typ ~= "unknown" then
                local name, sid, ply = OwnerInfo(ent)
                local item = {ent = ent, type = typ, ownerName = name, steamID = sid, owner = ply, pos = ent:GetPos(), class = ent:GetClass() or "", model = ModelName(ent)}
                entities[#entities + 1] = item
                totals.all = totals.all + 1
                totals[typ] = (totals[typ] or 0) + 1
                if sid == "unknown" then totals.unknown = totals.unknown + 1 else totals.owned = totals.owned + 1 end
                owners[sid] = owners[sid] or {name = name, steamID = sid, owner = ply, count = 0, props = 0, vehicles = 0, wire = 0, lights = 0, npcs = 0, entities = {}, center = Vector(0,0,0)}
                local o = owners[sid]
                if name ~= "Unknown" then o.name = name end
                if IsValid(ply) then o.owner = ply end
                o.count = o.count + 1
                o[typ] = (o[typ] or 0) + 1
                o.entities[#o.entities + 1] = ent
                o.center = o.center + ent:GetPos()
            end
        end
    end

    local ownerList = {}
    for _, o in pairs(owners) do
        if o.count > 0 then o.center = o.center / o.count end
        ownerList[#ownerList + 1] = o
    end
    table.sort(ownerList, function(a,b) return a.count > b.count end)
    return entities, ownerList, totals
end

local function Box(parent, x, y, w, h, accent, paintExtra)
    local th = Theme()
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y); p:SetSize(w, h)
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
    b:SetPos(x, y); b:SetSize(w, h); b:SetText(""); b:SetCursor("hand"); b.HoverAmount = 0
    b.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(10, 0, 0, pw, ph, Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 238))
        draw.RoundedBox(8, 0, ph - 5, pw, 5, danger and th.danger or th.orange)
        draw.SimpleText(title, "MN_Text", 14, subtitle and subtitle ~= "" and 17 or ph / 2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(subtitle, "MN_Small", 14, 38, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function() surface.PlaySound("buttons/button15.wav") if fn then fn() end end
    return b
end

local function Stat(parent, x, y, w, h, title, value, accent)
    local th = Theme()
    Box(parent, x, y, w, h, accent or th.orange, function(_, pw, ph)
        draw.SimpleText(string.upper(title), "MN_Small", 12, 16, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value), "MN_Subtitle", 12, 42, accent or th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
end

local function WorldToMini(pos, minX, minY, maxX, maxY, x, y, w, h)
    local px = x + math.Clamp((pos.x - minX) / math.max(1, maxX - minX), 0, 1) * w
    local py = y + h - math.Clamp((pos.y - minY) / math.max(1, maxY - minY), 0, 1) * h
    return px, py
end

local function BuildMap(parent)
    local th = Theme()
    local entities, owners, totals = ScanWorld()
    local minX, minY, maxX, maxY = BoundsFromEntities(ents.GetAll())

    Stat(parent, 0, 0, 120, 62, "Entities", totals.all, th.orange)
    Stat(parent, 132, 0, 120, 62, "Owners", #owners, th.success)
    Stat(parent, 264, 0, 120, 62, "Props", totals.props, Color(90,220,120))
    Stat(parent, 396, 0, 120, 62, "Vehicles", totals.vehicles, th.blue)
    Stat(parent, 528, 0, 120, 62, "Wire", totals.wire, Color(80,200,255))

    local map = Box(parent, 0, 82, 650, 420, nil, function(_, w, h)
        draw.SimpleText("Live Build Map", "MN_Subtitle", 18, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Orange dots = builds, blue dots = players", "MN_Small", 18, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local mx, my, mw, mh = 20, 76, w - 40, h - 96
        draw.RoundedBox(10, mx, my, mw, mh, Color(7, 10, 16, 220))
        surface.SetDrawColor(255,255,255,20)
        for i = 1, 8 do
            surface.DrawLine(mx + i * mw / 8, my, mx + i * mw / 8, my + mh)
            surface.DrawLine(mx, my + i * mh / 8, mx + mw, my + i * mh / 8)
        end
        for _, o in ipairs(owners) do
            local px, py = WorldToMini(o.center, minX, minY, maxX, maxY, mx, my, mw, mh)
            local r = math.Clamp(5 + o.count / 25, 6, 20)
            draw.RoundedBox(r, px - r, py - r, r * 2, r * 2, o.steamID == selectedSteamID and th.success or Color(255,145,0,210))
            draw.SimpleText(o.name or "Unknown", "MN_Small", px + r + 4, py, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local px, py = WorldToMini(ply:GetPos(), minX, minY, maxX, maxY, mx, my, mw, mh)
                draw.RoundedBox(6, px - 6, py - 6, 12, 12, th.blue)
            end
        end
    end)

    local side = Box(parent, 670, 82, 250, 420, nil, function(_, w, h)
        draw.SimpleText("Top Builds", "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local y = 58
    for i = 1, math.min(5, #owners) do
        local o = owners[i]
        Button(side, 14, y, 222, 54, o.name or o.steamID, o.count .. " entities", function()
            selectedSteamID = o.steamID
            highlightSteamID = o.steamID
            highlightUntil = CurTime() + 10
            Notify("Build highlighted for 10 seconds.", "success")
        end, selectedSteamID == o.steamID)
        y = y + 64
    end
end

local function BuildEntities(parent)
    local th = Theme()
    local entities = ScanWorld()
    local q = string.lower(string.Trim(searchText or ""))
    local filtered = {}
    for _, item in ipairs(entities) do
        if q == "" or string.find(string.lower(item.ownerName or ""), q, 1, true) or string.find(string.lower(item.model or ""), q, 1, true) or string.find(string.lower(item.class or ""), q, 1, true) then
            filtered[#filtered + 1] = item
        end
    end

    local search = Box(parent, 0, 0, 920, 56, nil, function(_, w, h) draw.SimpleText("Search", "MN_Text", 16, h/2, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end)
    local entry = vgui.Create("DTextEntry", search)
    entry:SetPos(86, 11); entry:SetSize(540, 34); entry:SetFont("MN_Text"); entry:SetText(searchText); entry:SetPlaceholderText("owner, model or classname..."); entry:SetUpdateOnType(true)
    entry.OnValueChange = function(_, v) searchText = v or "" timer.Create("MN_WorldManager_Search", 0.15, 1, function() if IsValid(parent) then parent:Clear() BuildEntities(parent) end end) end
    Button(search, 648, 11, 120, 34, "Clear", "", function() searchText = "" parent:Clear() BuildEntities(parent) end)
    Button(search, 786, 11, 120, 34, "Refresh", "", function() parent:Clear() BuildEntities(parent) end)

    local list = vgui.Create("DScrollPanel", parent)
    list:SetPos(0, 76); list:SetSize(920, 470)
    local y = 0
    for i = 1, math.min(80, #filtered) do
        local item = filtered[i]
        local row = vgui.Create("DButton", list)
        row:SetPos(0, y); row:SetSize(895, 54); row:SetText(""); row.HoverAmount = 0
        row.Paint = function(self, w, h)
            self.HoverAmount = Lerp(FrameTime()*10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
            draw.RoundedBox(10,0,0,w,h,Color(18+self.HoverAmount*8,24+self.HoverAmount*8,32+self.HoverAmount*8,238))
            draw.RoundedBox(6,0,0,5,h,th.orange)
            draw.SimpleText(item.type .. "  |  " .. item.model, "MN_Text", 16, 18, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(item.ownerName .. "  -  " .. item.class, "MN_Small", 16, 40, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(math.floor(LocalPlayer():GetPos():Distance(item.pos)) .. "u", "MN_Text", w - 18, h/2, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoDoubleClick = function()
            if IsValid(item.ent) then LocalPlayer():SetEyeAngles((item.ent:GetPos() - LocalPlayer():EyePos()):Angle()) end
            Notify("Looked at entity. Server teleport action comes next sprint.", "info")
        end
        y = y + 62
    end
end

local function BuildPerformance(parent)
    local th = Theme()
    local _, owners, totals = ScanWorld()
    local fps = MemoNetwork.Metrics and MemoNetwork.Metrics.Latest and MemoNetwork.Metrics.Latest("fps", math.floor(1/FrameTime())) or math.floor(1/FrameTime())
    local mem = math.floor(collectgarbage("count") / 1024)
    Stat(parent, 0, 0, 140, 70, "FPS", fps, Color(255,210,90))
    Stat(parent, 154, 0, 140, 70, "Lua MB", mem, th.purple)
    Stat(parent, 308, 0, 140, 70, "Entities", totals.all, th.orange)
    Stat(parent, 462, 0, 140, 70, "Owners", #owners, th.success)
    Stat(parent, 616, 0, 140, 70, "Players", #player.GetAll(), th.blue)
    Box(parent, 0, 94, 920, 200, nil, function(_, w, h)
        draw.SimpleText("Performance Notes", "MN_Title", 22, 34, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("This Alpha 21 sprint adds the visual dashboard foundation.", "MN_Text", 22, 78, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Next sprint can add server-side physics samples, constraint counts and history logging.", "MN_Text", 22, 112, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Current largest build: " .. ((owners[1] and owners[1].name) or "none") .. " / " .. ((owners[1] and owners[1].count) or 0) .. " entities", "MN_Text", 22, 146, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
end

local function DrawPage(content)
    content:Clear()
    if activeTab == "Map" then BuildMap(content)
    elseif activeTab == "Entities" then BuildEntities(content)
    elseif activeTab == "Performance" then BuildPerformance(content)
    end
end

hook.Add("PreDrawHalos", "MemoNetwork_WorldManager_Highlight", function()
    if not highlightSteamID or CurTime() > highlightUntil then return end
    local list = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:GetNWString("MemoNetworkOwnerSteamID", "") == highlightSteamID then list[#list + 1] = ent end
    end
    if #list > 0 then halo.Add(list, Color(255,145,0), 3, 3, 2, true, true) end
end)

hook.Add("PostDrawTranslucentRenderables", "MemoNetwork_WorldManager_Overlays", function()
    if not overlaysEnabled then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local _, owners = ScanWorld()
    local count = 0
    for _, o in ipairs(owners) do
        if o.steamID ~= "unknown" and o.center:DistToSqr(ply:GetPos()) < 3500000 then
            count = count + 1
            if count > 8 then break end
            local ang = Angle(0, EyeAngles().y - 90, 90)
            cam.Start3D2D(o.center + Vector(0,0,85), ang, 0.12)
                draw.RoundedBox(8, -120, -34, 240, 68, Color(10,14,22,220))
                draw.SimpleText(o.name or "Unknown", "MN_Subtitle", 0, -12, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(o.count .. " entities", "MN_Text", 0, 15, Color(255,145,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    end
end)

function MemoNetwork.WorldManager.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end
    local th = Theme()
    local w, h = math.min(1040, ScrW()-60), math.min(760, ScrH()-60)
    frame = vgui.Create("DFrame")
    frame:SetSize(w,h); frame:Center(); frame:SetTitle(""); frame:SetDraggable(false); frame:ShowCloseButton(false); frame:MakePopup()
    frame.Paint = function(_, pw, ph)
        draw.RoundedBox(14,0,0,pw,ph,th.bg)
        draw.RoundedBoxEx(14,0,0,pw,78,th.orange,true,true,false,false)
        draw.SimpleText("MemoNetwork Live World Manager", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 21 - Build map, trackers, overlays and entity browser", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local close = vgui.Create("DButton", frame); close:SetPos(w-56,20); close:SetSize(36,36); close:SetText("X"); close.DoClick = function() frame:Remove() frame=nil end
    local sidebar = vgui.Create("DPanel", frame); sidebar:SetPos(20,100); sidebar:SetSize(250,h-124); sidebar.Paint = function(_,pw,ph) draw.RoundedBox(12,0,0,pw,ph,th.panel) end
    local content = vgui.Create("DPanel", frame); content:SetPos(292,100); content:SetSize(w-322,h-124); content.Paint = function() end
    local tabs = {{"Map","Live build map"},{"Entities","Entity browser"},{"Performance","Server health"}}
    local y = 16
    for _, tab in ipairs(tabs) do
        Button(sidebar, 14, y, 222, 50, tab[1], tab[2], function() activeTab = tab[1] DrawPage(content) end, activeTab == tab[1])
        y = y + 60
    end
    Button(sidebar, 14, y + 20, 222, 50, overlaysEnabled and "Overlays ON" or "Overlays OFF", "World labels", function() overlaysEnabled = not overlaysEnabled Notify("World overlays " .. (overlaysEnabled and "enabled" or "disabled"), "info") end)
    DrawPage(content)
end

concommand.Add("mn_world", MemoNetwork.WorldManager.Open)
