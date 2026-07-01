-- MemoNetwork Alpha 24 Live Build Editor
-- Build inspector, build tree, replay preview, graphs and smart analyzer foundation.

MemoNetwork = MemoNetwork or {}
MemoNetwork.BuildEditor = MemoNetwork.BuildEditor or {}

local frame
local activeTab = "Inspector"
local selectedSteamID
local searchText = ""
local highlightSteamID
local highlightUntil = 0
local replayEvents = {}

local function Theme()
    local t = MemoNetwork.Theme or {}
    return {
        orange = t.Orange or Color(255,145,0), text = t.Text or Color(245,245,245), muted = t.Muted or Color(155,165,180),
        bg = t.Background or Color(10,14,22,238), panel = t.Panel or Color(14,20,28,238), panel2 = t.PanelLight or Color(20,28,38,238),
        success = t.Success or Color(90,220,120), warning = Color(255,190,80), danger = Color(255,90,90), blue = Color(80,160,255), purple = Color(180,120,255)
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
    if MemoNetwork.Notify then MemoNetwork.Notify(message, kind or "info", "Build Editor", 3) else chat.AddText(Color(255,145,0), "[Build Editor] ", color_white, tostring(message or "")) end
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

local function ConstraintCount(ent)
    if not constraint or not constraint.GetTable then return 0 end
    local ok, tbl = pcall(constraint.GetTable, ent)
    if not ok or not istable(tbl) then return 0 end
    return #tbl
end

local function ScanBuilds()
    local owners = {}
    local allEntities = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() then
            local typ = EntityType(ent)
            if typ ~= "unknown" then
                local name, sid, ply = OwnerInfo(ent)
                owners[sid] = owners[sid] or {
                    steamID = sid, name = name, owner = ply, count = 0, entities = {}, center = Vector(0,0,0),
                    props = 0, vehicles = 0, wire = 0, lights = 0, npcs = 0, ragdolls = 0, effects = 0, other = 0, constraints = 0
                }
                local o = owners[sid]
                if name ~= "Unknown" then o.name = name end
                if IsValid(ply) then o.owner = ply end
                o.count = o.count + 1
                o[typ] = (o[typ] or 0) + 1
                o.constraints = o.constraints + ConstraintCount(ent)
                o.center = o.center + ent:GetPos()
                o.entities[#o.entities + 1] = ent
                allEntities[#allEntities + 1] = ent
            end
        end
    end
    local list = {}
    for _, o in pairs(owners) do
        if o.count > 0 then o.center = o.center / o.count end
        local penalty = 0
        if o.count > 300 then penalty = penalty + 15 end
        if o.count > 700 then penalty = penalty + 30 end
        if o.constraints > 500 then penalty = penalty + 20 end
        if o.wire > 100 then penalty = penalty + 15 end
        if o.vehicles > 15 then penalty = penalty + 10 end
        o.score = math.Clamp(100 - penalty, 5, 100)
        list[#list + 1] = o
    end
    table.sort(list, function(a,b) return a.count > b.count end)
    return list, allEntities
end

local function SelectedBuild(list)
    for _, o in ipairs(list) do if o.steamID == selectedSteamID then return o end end
    selectedSteamID = list[1] and list[1].steamID or nil
    return list[1]
end

local function Box(parent, x, y, w, h, accent, paintExtra)
    local th = Theme()
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x,y); p:SetSize(w,h)
    p.Paint = function(self,pw,ph)
        draw.RoundedBox(12,0,0,pw,ph,th.panel2)
        if accent then draw.RoundedBox(6,0,0,6,ph,accent) end
        if paintExtra then paintExtra(self,pw,ph,th) end
    end
    return p
end

local function Button(parent,x,y,w,h,title,subtitle,fn,danger)
    local th = Theme()
    local b = vgui.Create("DButton", parent)
    b:SetPos(x,y); b:SetSize(w,h); b:SetText(""); b:SetCursor("hand"); b.HoverAmount = 0
    b.Paint = function(self,pw,ph)
        self.HoverAmount = Lerp(FrameTime()*10,self.HoverAmount or 0,self:IsHovered() and 1 or 0)
        draw.RoundedBox(10,0,0,pw,ph,Color(18+self.HoverAmount*10,24+self.HoverAmount*10,32+self.HoverAmount*10,238))
        draw.RoundedBox(8,0,ph-5,pw,5,danger and th.danger or th.orange)
        draw.SimpleText(title,"MN_Text",14,subtitle and subtitle ~= "" and 17 or ph/2,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(subtitle,"MN_Small",14,38,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function() surface.PlaySound("buttons/button15.wav") if fn then fn() end end
    return b
end

local function Stat(parent,x,y,w,h,title,value,accent)
    local th = Theme()
    Box(parent,x,y,w,h,accent or th.orange,function(_,pw,ph)
        draw.SimpleText(string.upper(title),"MN_Small",12,16,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value),"MN_Subtitle",12,42,accent or th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)
end

local function BuildSelector(parent, builds, selected, rebuild)
    local th = Theme()
    local panel = Box(parent, 0, 0, 270, 540, nil, function(_,w,h)
        draw.SimpleText("Builds", "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#builds .. " detected", "MN_Small", 16, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:SetPos(14, 70); scroll:SetSize(242, 454)
    local y = 0
    for _, o in ipairs(builds) do
        Button(scroll, 0, y, 224, 56, o.name or o.steamID, o.count .. " entities | score " .. o.score, function()
            selectedSteamID = o.steamID
            if rebuild then rebuild() end
        end, selected and selected.steamID == o.steamID)
        y = y + 64
    end
end

local function BuildInspector(parent)
    local th = Theme()
    local builds = ScanBuilds()
    local selected = SelectedBuild(builds)
    local function Rebuild() parent:Clear() BuildInspector(parent) end
    BuildSelector(parent, builds, selected, Rebuild)

    local detail = Box(parent, 290, 0, 630, 170, selected and th.orange or th.warning, function(_,w,h)
        if not selected then draw.SimpleText("No build selected", "MN_Title", 20, 35, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) return end
        draw.SimpleText(selected.name or "Unknown", "MN_Title", 20, 34, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selected.steamID or "unknown", "MN_Text", 20, 70, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Smart score: " .. selected.score .. "/100", "MN_Subtitle", w - 20, 34, selected.score > 75 and th.success or (selected.score > 45 and th.warning or th.danger), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Center: " .. math.floor(selected.center.x) .. ", " .. math.floor(selected.center.y) .. ", " .. math.floor(selected.center.z), "MN_Small", 20, 104, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    if selected then
        Stat(parent,290,190,100,60,"Props",selected.props,Color(90,220,120))
        Stat(parent,402,190,100,60,"Vehicles",selected.vehicles,th.blue)
        Stat(parent,514,190,100,60,"Wire",selected.wire,Color(80,200,255))
        Stat(parent,626,190,100,60,"Lights",selected.lights,Color(255,230,120))
        Stat(parent,738,190,100,60,"NPCs",selected.npcs,th.danger)
        Stat(parent,850,190,70,60,"Con",selected.constraints,th.purple)
        Button(parent,290,270,140,48,"Highlight","10 sec",function() highlightSteamID = selected.steamID highlightUntil = CurTime() + 10 Notify("Build highlighted.", "success") end)
        Button(parent,446,270,140,48,"Goto Center","look direction",function() LocalPlayer():SetEyeAngles((selected.center - LocalPlayer():EyePos()):Angle()) Notify("Looking at build center.", "info") end)
        Button(parent,602,270,140,48,"Open Tools","cleanup/freeze",function() if MemoNetwork.BuildTools then MemoNetwork.BuildTools.Open() end end)
        Button(parent,758,270,162,48,"Copy Export JSON","stats only",function() SetClipboardText(util.TableToJSON(selected, true) or "{}") Notify("Build stats copied as JSON.", "success") end)
    end

    local browser = Box(parent, 290, 340, 630, 200, nil, function(_,w,h) draw.SimpleText("Entity Preview", "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end)
    if selected then
        local scroll = vgui.Create("DScrollPanel", browser)
        scroll:SetPos(14, 54); scroll:SetSize(602, 132)
        local y = 0
        for i = 1, math.min(30, #selected.entities) do
            local ent = selected.entities[i]
            Box(scroll, 0, y, 582, 38, th.orange, function(_,w,h)
                draw.SimpleText(EntityType(ent) .. " | " .. ModelName(ent), "MN_Small", 14, h/2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText((IsValid(ent) and ent:GetClass() or "invalid"), "MN_Small", w - 14, h/2, th.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end)
            y = y + 44
        end
    end
end

local function BuildTree(parent)
    local th = Theme()
    local builds = ScanBuilds()
    local selected = SelectedBuild(builds)
    local function Rebuild() parent:Clear() BuildTree(parent) end
    BuildSelector(parent, builds, selected, Rebuild)
    local tree = Box(parent, 290, 0, 630, 540, selected and th.orange or th.warning, function(_,w,h)
        draw.SimpleText("Build Tree", "MN_Title", 20, 34, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if selected then draw.SimpleText(selected.name .. " - structured entity overview", "MN_Text", 20, 70, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end)
    if selected then
        local rows = {
            {"Props", selected.props, Color(90,220,120)}, {"Vehicles", selected.vehicles, th.blue}, {"Wire", selected.wire, Color(80,200,255)},
            {"Lights", selected.lights, Color(255,230,120)}, {"NPCs", selected.npcs, th.danger}, {"Ragdolls", selected.ragdolls, th.warning},
            {"Effects", selected.effects, th.purple}, {"Constraints", selected.constraints, th.orange}
        }
        local y = 112
        for _, r in ipairs(rows) do
            Box(tree, 24, y, 582, 44, r[3], function(_,w,h)
                draw.SimpleText("├── " .. r[1], "MN_Text", 16, h/2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(r[2]), "MN_Subtitle", w-18, h/2, r[3], TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end)
            y = y + 54
        end
    end
end

local function BuildReplay(parent)
    local th = Theme()
    Box(parent,0,0,920,92,th.orange,function(_,w,h)
        draw.SimpleText("Live Replay Preview", "MN_Title", 22, 28, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Client-side preview. Server-side replay storage can be added in the next sprint.", "MN_Text", 22, 62, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Button(parent,0,112,150,46,"Mark Event","manual",function() table.insert(replayEvents,1,{time=os.date("%H:%M:%S"), text="Manual checkpoint", kind="checkpoint"}) end)
    Button(parent,166,112,150,46,"Clear","local",function() replayEvents = {} end,true)
    local list = vgui.Create("DScrollPanel", parent)
    list:SetPos(0,180); list:SetSize(920,360)
    local y = 0
    for i, ev in ipairs(replayEvents) do
        Box(list,0,y,895,52,th.orange,function(_,w,h)
            draw.SimpleText(ev.time .. "  " .. ev.kind, "MN_Small", 16, 15, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(ev.text, "MN_Text", 16, 37, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end)
        y = y + 60
    end
end

local function BuildGraphs(parent)
    local th = Theme()
    local builds = ScanBuilds()
    Box(parent,0,0,920,540,nil,function(_,w,h)
        draw.SimpleText("Live Build Graphs", "MN_Title", 22, 34, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Top 8 builds by entity count", "MN_Text", 22, 68, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local gx, gy, gw, gh = 40, 120, w - 80, 350
        draw.RoundedBox(10, gx, gy, gw, gh, Color(7,10,16,220))
        local maxCount = 1
        for i=1,math.min(8,#builds) do maxCount = math.max(maxCount, builds[i].count) end
        for i=1,math.min(8,#builds) do
            local o = builds[i]
            local bw = (gw - 40) / 8
            local bh = math.Clamp((o.count / maxCount) * (gh - 60), 8, gh - 60)
            local bx = gx + 20 + (i-1)*bw
            local by = gy + gh - 30 - bh
            draw.RoundedBox(8, bx, by, bw - 12, bh, o.score > 75 and th.success or (o.score > 45 and th.warning or th.danger))
            draw.SimpleText(tostring(o.count), "MN_Small", bx + (bw-12)/2, by - 12, th.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.sub(o.name or "?", 1, 10), "MN_Small", bx + (bw-12)/2, gy + gh - 14, th.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)
end

local function BuildAnalyzer(parent)
    local th = Theme()
    local builds = ScanBuilds()
    local list = vgui.Create("DScrollPanel", parent)
    list:SetPos(0,0); list:SetSize(920,540)
    local y = 0
    for _, o in ipairs(builds) do
        local issues = {}
        if o.count > 700 then issues[#issues+1] = "very high entity count" elseif o.count > 300 then issues[#issues+1] = "large build" end
        if o.constraints > 500 then issues[#issues+1] = "many constraints" end
        if o.wire > 100 then issues[#issues+1] = "heavy wire usage" end
        if o.vehicles > 15 then issues[#issues+1] = "many vehicles" end
        if #issues == 0 then issues[#issues+1] = "optimized" end
        local color = o.score > 75 and th.success or (o.score > 45 and th.warning or th.danger)
        Box(list,0,y,895,72,color,function(_,w,h)
            draw.SimpleText(o.name or o.steamID, "MN_Subtitle", 16, 22, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(table.concat(issues, ", "), "MN_Small", 16, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(o.score .. "/100", "MN_Subtitle", w-18, 34, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end)
        y = y + 82
    end
end

local function DrawPage(content)
    content:Clear()
    if activeTab == "Inspector" then BuildInspector(content)
    elseif activeTab == "Tree" then BuildTree(content)
    elseif activeTab == "Replay" then BuildReplay(content)
    elseif activeTab == "Graphs" then BuildGraphs(content)
    elseif activeTab == "Analyzer" then BuildAnalyzer(content)
    end
end

hook.Add("PreDrawHalos", "MemoNetwork_BuildEditor_Highlight", function()
    if not highlightSteamID or CurTime() > highlightUntil then return end
    local list = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:GetNWString("MemoNetworkOwnerSteamID", "") == highlightSteamID then list[#list+1] = ent end
    end
    if #list > 0 then halo.Add(list, Color(255,145,0), 3, 3, 2, true, true) end
end)

function MemoNetwork.BuildEditor.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame=nil return end
    local th = Theme()
    local w,h = math.min(1040,ScrW()-60), math.min(760,ScrH()-60)
    frame = vgui.Create("DFrame")
    frame:SetSize(w,h); frame:Center(); frame:SetTitle(""); frame:SetDraggable(false); frame:ShowCloseButton(false); frame:MakePopup()
    frame.Paint = function(_,pw,ph)
        draw.RoundedBox(14,0,0,pw,ph,th.bg)
        draw.RoundedBoxEx(14,0,0,pw,78,th.orange,true,true,false,false)
        draw.SimpleText("MemoNetwork Live Build Editor", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 24 - inspector, tree, replay preview and smart analyzer", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local close = vgui.Create("DButton", frame); close:SetPos(w-56,20); close:SetSize(36,36); close:SetText("X"); close.DoClick=function() frame:Remove() frame=nil end
    local sidebar = vgui.Create("DPanel", frame); sidebar:SetPos(20,100); sidebar:SetSize(250,h-124); sidebar.Paint=function(_,pw,ph) draw.RoundedBox(12,0,0,pw,ph,th.panel) end
    local content = vgui.Create("DPanel", frame); content:SetPos(292,100); content:SetSize(w-322,h-124); content.Paint=function() end
    local tabs = {{"Inspector","Build details"},{"Tree","Build tree"},{"Replay","Replay preview"},{"Graphs","Live graphs"},{"Analyzer","Smart analyzer"}}
    local y=16
    for _,tab in ipairs(tabs) do Button(sidebar,14,y,222,50,tab[1],tab[2],function() activeTab=tab[1] DrawPage(content) end,activeTab==tab[1]) y=y+60 end
    Button(sidebar,14,y+20,222,50,"Command Center","Back",function() if MemoNetwork.CommandCenter then frame:Remove() frame=nil MemoNetwork.CommandCenter.Open() end end)
    DrawPage(content)
end

concommand.Add("mn_buildeditor", MemoNetwork.BuildEditor.Open)
