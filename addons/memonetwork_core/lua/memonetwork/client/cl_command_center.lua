-- MemoNetwork Alpha 23 Industrial Command Center
-- Integrated dashboard: players, builds, alerts and quick admin actions in one window.

MemoNetwork = MemoNetwork or {}
MemoNetwork.CommandCenter = MemoNetwork.CommandCenter or {}

local frame
local activeTab = "Dashboard"
local selectedPlayer
local selectedSteamID
local searchText = ""
local cachedIntel = {totals = {}, owners = {}, events = {}}

local function Theme()
    local t = MemoNetwork.Theme or {}
    return {
        orange = t.Orange or Color(255, 145, 0), text = t.Text or Color(245, 245, 245), muted = t.Muted or Color(155, 165, 180),
        bg = t.Background or Color(10, 14, 22, 238), panel = t.Panel or Color(14, 20, 28, 238), panel2 = t.PanelLight or Color(20, 28, 38, 238),
        success = t.Success or Color(90, 220, 120), warning = Color(255, 190, 80), danger = Color(255, 90, 90), blue = Color(80, 160, 255), purple = Color(180, 120, 255)
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
    if MemoNetwork.Notify then MemoNetwork.Notify(message, kind or "info", "Command Center", 3) else chat.AddText(Color(255,145,0), "[Command Center] ", color_white, tostring(message or "")) end
end

local function SendAction(action)
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
    net.SendToServer()
end

local function SendTargetAction(action, target)
    if not IsValid(target) then Notify("Selecteer eerst een online speler.", "error") return end
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        net.WriteEntity(target)
    net.SendToServer()
end

local function RequestIntel()
    if util.NetworkStringToID("MemoNetwork_RequestIntelligenceSnapshot") ~= 0 then
        net.Start("MemoNetwork_RequestIntelligenceSnapshot")
        net.SendToServer()
    end
end

net.Receive("MemoNetwork_IntelligenceSnapshot", function()
    local data = util.JSONToTable(net.ReadString() or "{}") or {}
    cachedIntel = data
end)

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

local function ScanLocal()
    local totals = {all=0, props=0, vehicles=0, wire=0, lights=0, npcs=0, owners=0, unknown=0}
    local owners = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() then
            local typ = EntityType(ent)
            if typ ~= "unknown" then
                totals.all = totals.all + 1
                totals[typ] = (totals[typ] or 0) + 1
                local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
                local name = ent:GetNWString("MemoNetworkOwnerName", "")
                if sid == "" then totals.unknown = totals.unknown + 1 else
                    owners[sid] = owners[sid] or {steamID=sid, name=name ~= "" and name or sid, count=0, props=0, vehicles=0, wire=0, lights=0, npcs=0}
                    local o = owners[sid]
                    if name ~= "" then o.name = name end
                    o.count = o.count + 1
                    o[typ] = (o[typ] or 0) + 1
                end
            end
        end
    end
    local list = {}
    for _, o in pairs(owners) do list[#list+1] = o end
    table.sort(list, function(a,b) return a.count > b.count end)
    totals.owners = #list
    return totals, list
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

local function Stat(parent, x, y, w, h, title, value, subtitle, accent)
    local th = Theme()
    Box(parent, x, y, w, h, accent or th.orange, function(_, pw, ph)
        draw.SimpleText(string.upper(tostring(title)), "MN_Small", 14, 15, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value or "-"), "MN_Subtitle", 14, 42, accent or th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(subtitle, "MN_Small", 14, 62, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end)
end

local function Button(parent, x, y, w, h, title, subtitle, fn, danger)
    local th = Theme()
    local b = vgui.Create("DButton", parent)
    b:SetPos(x,y); b:SetSize(w,h); b:SetText(""); b:SetCursor("hand"); b.HoverAmount = 0
    b.Paint = function(self,pw,ph)
        self.HoverAmount = Lerp(FrameTime()*10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(10,0,0,pw,ph,Color(18+self.HoverAmount*10,24+self.HoverAmount*10,32+self.HoverAmount*10,238))
        draw.RoundedBox(8,0,ph-5,pw,5,danger and th.danger or th.orange)
        draw.SimpleText(title,"MN_Text",14,subtitle and subtitle ~= "" and 17 or ph/2,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(subtitle,"MN_Small",14,38,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function() surface.PlaySound("buttons/button15.wav") if fn then fn() end end
    return b
end

local function BuildDashboard(parent)
    local th = Theme()
    local totals, owners = ScanLocal()
    local fps = MemoNetwork.Metrics and MemoNetwork.Metrics.Latest and MemoNetwork.Metrics.Latest("fps", math.floor(1/FrameTime())) or math.floor(1/FrameTime())
    local mem = math.floor(collectgarbage("count") / 1024)
    local health, color = "Good", th.success
    if totals.all > 1200 then health, color = "Critical", th.danger elseif totals.all > 800 then health, color = "Warning", th.warning end

    Stat(parent,0,0,132,68,"Health",health,"server",color)
    Stat(parent,144,0,132,68,"Players",#player.GetAll() .. "/" .. game.MaxPlayers(),"online",th.blue)
    Stat(parent,288,0,132,68,"Entities",totals.all,"world",th.orange)
    Stat(parent,432,0,132,68,"FPS",fps,"client",Color(255,210,90))
    Stat(parent,576,0,132,68,"Lua",mem .. " MB","memory",th.purple)

    Box(parent,0,88,708,132,th.orange,function(_,w,h)
        draw.SimpleText("Industrial Command Center", "MN_Title", 22, 28, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 23 bundelt spelers, builds, alerts en quick actions in één professioneel paneel.", "MN_Text", 22, 66, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Grootste build: " .. ((owners[1] and owners[1].name) or "none") .. " / " .. ((owners[1] and owners[1].count) or 0) .. " entities", "MN_Text", 22, 100, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    Button(parent,0,244,164,58,"World Manager","Live map",function() if MemoNetwork.WorldManager then MemoNetwork.WorldManager.Open() end end)
    Button(parent,180,244,164,58,"Intelligence","Timeline",function() if MemoNetwork.Intelligence then MemoNetwork.Intelligence.Open() end end)
    Button(parent,360,244,164,58,"Build Tools","Cleanup/freeze",function() if MemoNetwork.BuildTools then MemoNetwork.BuildTools.Open() end end)
    Button(parent,540,244,168,58,"Control Center","Server actions",function() if MemoNetwork.ControlCenter then MemoNetwork.ControlCenter.Open() end end)

    Box(parent,0,326,708,138,nil,function(_,w,h)
        draw.SimpleText("Alert Center", "MN_Subtitle", 18, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local y = 56
        if totals.all > 1200 then draw.SimpleText("⚠ Critical entity count: " .. totals.all, "MN_Text", 18, y, th.danger, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) y = y + 28 end
        if totals.unknown > 100 then draw.SimpleText("⚠ Many unknown owners: " .. totals.unknown, "MN_Text", 18, y, th.warning, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) y = y + 28 end
        if owners[1] and owners[1].count > 600 then draw.SimpleText("⚠ Large build: " .. owners[1].name .. " / " .. owners[1].count, "MN_Text", 18, y, th.warning, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) y = y + 28 end
        if y == 56 then draw.SimpleText("No major warnings right now.", "MN_Text", 18, y, th.success, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end)
end

local function BuildPlayers(parent)
    local th = Theme()
    local players = player.GetAll()
    if MemoNetwork.Player and MemoNetwork.Player.Sort then pcall(MemoNetwork.Player.Sort, players) end
    if not IsValid(selectedPlayer) then selectedPlayer = players[1] end

    local list = Box(parent,0,0,300,470,nil,function(_,w,h) draw.SimpleText("Players", "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end)
    local y = 56
    for _, ply in ipairs(players) do
        local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name="PLAYER", color=th.text}
        Button(list,14,y,272,52,ply:Nick(),(rank.name or "PLAYER") .. " | " .. ply:Ping() .. " ms",function() selectedPlayer = ply parent:Clear() BuildPlayers(parent) end, selectedPlayer == ply)
        y = y + 62
    end

    local detail = Box(parent,320,0,388,470,selectedPlayer and th.orange or th.warning,function(_,w,h)
        if not IsValid(selectedPlayer) then draw.SimpleText("Select a player", "MN_Title", 20, 32, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) return end
        local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(selectedPlayer) or {name="PLAYER", color=th.orange}
        draw.SimpleText(selectedPlayer:Nick(), "MN_Title", 20, 36, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Subtitle", 20, 76, rank.color or th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selectedPlayer:SteamID(), "MN_Text", 20, 112, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("HP " .. selectedPlayer:Health() .. "  AR " .. selectedPlayer:Armor() .. "  Ping " .. selectedPlayer:Ping(), "MN_Text", 20, 148, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    Button(detail,20,190,108,42,"Goto","",function() SendTargetAction("teleport", selectedPlayer) end)
    Button(detail,140,190,108,42,"Bring","",function() SendTargetAction("bring", selectedPlayer) end)
    Button(detail,260,190,108,42,"Heal","",function() SendTargetAction("heal_target", selectedPlayer) end)
    Button(detail,20,246,108,42,"Freeze","",function() SendTargetAction("freeze", selectedPlayer) end)
    Button(detail,140,246,108,42,"Spectate","",function() SendTargetAction("spectate", selectedPlayer) end)
    Button(detail,260,246,108,42,"Slay","",function() SendTargetAction("slay", selectedPlayer) end,true)
    Button(detail,20,302,108,42,"Respawn","",function() SendTargetAction("respawn", selectedPlayer) end)
    Button(detail,140,302,108,42,"Kick","",function() SendTargetAction("kick", selectedPlayer) end,true)
    Button(detail,260,302,108,42,"Copy SID","",function() if IsValid(selectedPlayer) then SetClipboardText(selectedPlayer:SteamID()) Notify("SteamID copied", "success") end end)
end

local function BuildBuilds(parent)
    local th = Theme()
    local totals, owners = ScanLocal()
    Stat(parent,0,0,132,68,"Owners",#owners,"tracked",th.success)
    Stat(parent,144,0,132,68,"Props",totals.props,"build",Color(90,220,120))
    Stat(parent,288,0,132,68,"Vehicles",totals.vehicles,"build",th.blue)
    Stat(parent,432,0,132,68,"Wire",totals.wire,"logic",Color(80,200,255))
    Stat(parent,576,0,132,68,"Unknown",totals.unknown,"owners",th.warning)

    local list = vgui.Create("DScrollPanel", parent)
    list:SetPos(0,88); list:SetSize(708,390)
    local y = 0
    for i,o in ipairs(owners) do
        Box(list,0,y,684,68,o.steamID == selectedSteamID and th.success or th.orange,function(_,w,h)
            draw.SimpleText("#" .. i .. " " .. (o.name or o.steamID), "MN_Subtitle", 16, 22, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText((o.count or 0) .. " entities | props " .. (o.props or 0) .. " | vehicles " .. (o.vehicles or 0) .. " | wire " .. (o.wire or 0), "MN_Small", 16, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(o.count > 700 and "HIGH" or (o.count > 300 and "MED" or "OK"), "MN_Subtitle", w-18, 34, o.count > 700 and th.danger or (o.count > 300 and th.warning or th.success), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end)
        y = y + 78
    end
end

local function BuildTimeline(parent)
    local th = Theme()
    RequestIntel()
    Button(parent,0,0,150,42,"Refresh","Intel",RequestIntel)
    Button(parent,166,0,150,42,"Open Intel","Full panel",function() if MemoNetwork.Intelligence then MemoNetwork.Intelligence.Open() end end)
    local list = vgui.Create("DScrollPanel", parent)
    list:SetPos(0,60); list:SetSize(708,410)
    local y = 0
    for _,ev in ipairs((cachedIntel and cachedIntel.events) or {}) do
        Box(list,0,y,684,54,ev.severity == "error" and th.danger or (ev.severity == "warning" and th.warning or th.orange),function(_,w,h)
            draw.SimpleText((ev.time or "--:--") .. " " .. string.upper(ev.kind or "INFO"), "MN_Small", 16, 15, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText((ev.actor or "Server") .. " - " .. (ev.message or ""), "MN_Text", 16, 37, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end)
        y = y + 62
    end
end

local function DrawPage(content)
    content:Clear()
    if activeTab == "Dashboard" then BuildDashboard(content)
    elseif activeTab == "Players" then BuildPlayers(content)
    elseif activeTab == "Builds" then BuildBuilds(content)
    elseif activeTab == "Timeline" then BuildTimeline(content)
    end
end

function MemoNetwork.CommandCenter.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end
    RequestIntel()
    local th = Theme()
    local w,h = math.min(1040,ScrW()-60), math.min(760,ScrH()-60)
    frame = vgui.Create("DFrame")
    frame:SetSize(w,h); frame:Center(); frame:SetTitle(""); frame:SetDraggable(false); frame:ShowCloseButton(false); frame:MakePopup()
    frame.Paint = function(_,pw,ph)
        draw.RoundedBox(14,0,0,pw,ph,th.bg)
        draw.RoundedBoxEx(14,0,0,pw,78,th.orange,true,true,false,false)
        draw.SimpleText("MemoNetwork Industrial Command Center", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 23 - integrated admin control room", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local close = vgui.Create("DButton", frame); close:SetPos(w-56,20); close:SetSize(36,36); close:SetText("X"); close.DoClick=function() frame:Remove() frame=nil end
    local sidebar = vgui.Create("DPanel", frame); sidebar:SetPos(20,100); sidebar:SetSize(250,h-124); sidebar.Paint=function(_,pw,ph) draw.RoundedBox(12,0,0,pw,ph,th.panel) end
    local content = vgui.Create("DPanel", frame); content:SetPos(292,100); content:SetSize(w-322,h-124); content.Paint=function() end
    local tabs = {{"Dashboard","Live overview"},{"Players","Player manager"},{"Builds","Build analytics"},{"Timeline","Events"}}
    local y=16
    for _,tab in ipairs(tabs) do Button(sidebar,14,y,222,50,tab[1],tab[2],function() activeTab=tab[1] DrawPage(content) end,activeTab==tab[1]) y=y+60 end
    Button(sidebar,14,y+20,222,50,"F6 Hub","Back to hub",function() if MemoNetwork.F6Hub then frame:Remove() frame=nil MemoNetwork.F6Hub.Open() end end)
    DrawPage(content)
end

concommand.Add("mn_command", MemoNetwork.CommandCenter.Open)
