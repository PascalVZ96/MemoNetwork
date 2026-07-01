-- MemoNetwork Alpha 25 Live Monitoring & Automation
-- Performance monitor, automation alerts, player activity, diagnostics, heatmap and task scheduler.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Monitoring = MemoNetwork.Monitoring or {}

local frame
local activeTab = "Overview"
local snapshot = {totals={}, owners={}, alerts={}, history={}, tasks={}, activity={}}

local function Theme()
    local t = MemoNetwork.Theme or {}
    return {orange=t.Orange or Color(255,145,0), text=t.Text or Color(245,245,245), muted=t.Muted or Color(155,165,180), bg=t.Background or Color(10,14,22,238), panel=t.Panel or Color(14,20,28,238), panel2=t.PanelLight or Color(20,28,38,238), success=t.Success or Color(90,220,120), warning=Color(255,190,80), danger=Color(255,90,90), blue=Color(80,160,255), purple=Color(180,120,255)}
end

local function CanOpen()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, "admin.open") or MemoNetwork.Ranks.HasPermission(ply, "players.manage")
    end
    return ply:IsAdmin()
end

local function Notify(msg, kind)
    if MemoNetwork.Notify then MemoNetwork.Notify(msg, kind or "info", "Monitoring", 3) else chat.AddText(Color(255,145,0), "[Monitoring] ", color_white, tostring(msg or "")) end
end

local function RequestSnapshot()
    net.Start("MemoNetwork_RequestAutomationSnapshot")
    net.SendToServer()
end

local function SendCommand(cmd, payload)
    net.Start("MemoNetwork_AutomationCommand")
        net.WriteString(cmd or "")
        net.WriteString(payload or "")
    net.SendToServer()
end

net.Receive("MemoNetwork_AutomationSnapshot", function()
    snapshot = util.JSONToTable(net.ReadString() or "{}") or snapshot
end)

local function Box(parent,x,y,w,h,accent,paintExtra)
    local th=Theme(); local p=vgui.Create("DPanel",parent); p:SetPos(x,y); p:SetSize(w,h)
    p.Paint=function(self,pw,ph) draw.RoundedBox(12,0,0,pw,ph,th.panel2) if accent then draw.RoundedBox(6,0,0,6,ph,accent) end if paintExtra then paintExtra(self,pw,ph,th) end end
    return p
end

local function Button(parent,x,y,w,h,title,subtitle,fn,danger)
    local th=Theme(); local b=vgui.Create("DButton",parent); b:SetPos(x,y); b:SetSize(w,h); b:SetText(""); b:SetCursor("hand"); b.HoverAmount=0
    b.Paint=function(self,pw,ph) self.HoverAmount=Lerp(FrameTime()*10,self.HoverAmount or 0,self:IsHovered() and 1 or 0) draw.RoundedBox(10,0,0,pw,ph,Color(18+self.HoverAmount*10,24+self.HoverAmount*10,32+self.HoverAmount*10,238)) draw.RoundedBox(8,0,ph-5,pw,5,danger and th.danger or th.orange) draw.SimpleText(title,"MN_Text",14,subtitle and subtitle~="" and 17 or ph/2,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) if subtitle and subtitle~="" then draw.SimpleText(subtitle,"MN_Small",14,38,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end end
    b.DoClick=function() surface.PlaySound("buttons/button15.wav") if fn then fn() end end
    return b
end

local function Stat(parent,x,y,w,h,title,value,accent)
    local th=Theme(); Box(parent,x,y,w,h,accent or th.orange,function(_,pw,ph) draw.SimpleText(string.upper(title),"MN_Small",12,16,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) draw.SimpleText(tostring(value or 0),"MN_Subtitle",12,42,accent or th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end)
end

local function DrawGraph(parent,x,y,w,h,data,key,color)
    local th=Theme(); Box(parent,x,y,w,h,nil,function(_,pw,ph)
        draw.SimpleText(key,"MN_Small",14,16,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        local values={}; local maxv=1
        for i=#data,1,-1 do local v=tonumber(data[i][key] or 0) or 0; values[#values+1]=v; maxv=math.max(maxv,v) end
        local gx,gy,gw,gh=16,34,pw-32,ph-48
        surface.SetDrawColor(255,255,255,25); surface.DrawRect(gx,gy,gw,gh)
        surface.SetDrawColor(color or th.orange)
        for i=2,#values do
            local x1=gx+(i-2)/math.max(1,#values-1)*gw; local x2=gx+(i-1)/math.max(1,#values-1)*gw
            local y1=gy+gh-(values[i-1]/maxv)*gh; local y2=gy+gh-(values[i]/maxv)*gh
            surface.DrawLine(x1,y1,x2,y2)
        end
    end)
end

local function BuildOverview(parent)
    local th=Theme(); local totals=snapshot.totals or {}; local owners=snapshot.owners or {}
    local health="Good"; local color=th.success
    if (totals.all or 0)>1400 then health="Critical" color=th.danger elseif (totals.all or 0)>900 then health="Warning" color=th.warning end
    Stat(parent,0,0,128,64,"Health",health,color); Stat(parent,140,0,128,64,"Entities",totals.all or 0,th.orange); Stat(parent,280,0,128,64,"Props",totals.props or 0,th.success); Stat(parent,420,0,128,64,"Wire",totals.wire or 0,th.blue); Stat(parent,560,0,128,64,"Con",totals.constraints or 0,th.purple)
    DrawGraph(parent,0,84,330,160,snapshot.history or {},"entities",th.orange)
    DrawGraph(parent,350,84,330,160,snapshot.history or {},"constraints",th.purple)
    Box(parent,0,270,680,210,th.orange,function(_,w,h)
        draw.SimpleText("Automation Engine", "MN_Title",22,30,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText("Map: "..tostring(snapshot.map or game.GetMap()).." | Uptime: "..tostring(snapshot.uptime or 0).."s", "MN_Text",22,70,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText("Largest build: "..((owners[1] and owners[1].name) or "none").." / "..((owners[1] and owners[1].count) or 0).." entities", "MN_Text",22,104,th.orange,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText("Ready for Alpha 26 web dashboard data export.", "MN_Text",22,138,th.success,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)
end

local function BuildAlerts(parent)
    Button(parent,0,0,150,42,"Refresh","",RequestSnapshot); Button(parent,166,0,150,42,"Diagnostics","manual",function() SendCommand("diagnostics","") end); Button(parent,332,0,150,42,"Clear Alerts","",function() SendCommand("clear_alerts","") end,true)
    local th=Theme(); local list=vgui.Create("DScrollPanel",parent); list:SetPos(0,62); list:SetSize(900,480); local y=0
    for _,a in ipairs(snapshot.alerts or {}) do
        local c=a.severity=="error" and th.danger or (a.severity=="warning" and th.warning or th.success)
        Box(list,0,y,875,54,c,function(_,w,h) draw.SimpleText((a.time or "--:--").." "..string.upper(a.kind or "alert"),"MN_Small",16,15,c,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) draw.SimpleText(a.text or "","MN_Text",16,37,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end)
        y=y+62
    end
end

local function BuildPlayers(parent)
    local th=Theme(); local list=vgui.Create("DScrollPanel",parent); list:SetPos(0,0); list:SetSize(900,540); local y=0
    for sid,a in pairs(snapshot.activity or {}) do
        Box(list,0,y,875,64,th.orange,function(_,w,h) draw.SimpleText(a.name or sid,"MN_Subtitle",16,20,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) draw.SimpleText("props "..(a.props or 0).." | vehicles "..(a.vehicles or 0).." | npcs "..(a.npcs or 0).." | chat "..(a.chat or 0).." | joins "..(a.joins or 0),"MN_Small",16,46,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end)
        y=y+74
    end
end

local function BuildHeatmap(parent)
    local th=Theme(); local owners=snapshot.owners or {}
    Box(parent,0,0,900,540,nil,function(_,w,h)
        draw.SimpleText("Build Heatmap / Risk Map", "MN_Title",22,34,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 25 risk overview: green = clean, yellow = warning, red = heavy build", "MN_Text",22,70,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        local x,y=30,120; local cw,ch=200,78
        for i,o in ipairs(owners) do if i>12 then break end
            local col=o.risk=="HIGH" and th.danger or (o.risk=="WARN" and th.warning or th.success)
            draw.RoundedBox(10,x,y,cw,ch,Color(18,24,32,235)); draw.RoundedBox(6,x,y,6,ch,col)
            draw.SimpleText(o.name or o.steamID,"MN_Text",x+16,y+22,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText((o.count or 0).." ent | score "..(o.score or 0),"MN_Small",x+16,y+50,col,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            x=x+220; if x+cw>w then x=30; y=y+96 end
        end
    end)
end

local function BuildTasks(parent)
    Button(parent,0,0,180,42,"Add Reminder","10 minutes",function() SendCommand("add_task","Check server/builds") end)
    Button(parent,196,0,180,42,"Refresh","",RequestSnapshot)
    local th=Theme(); local list=vgui.Create("DScrollPanel",parent); list:SetPos(0,62); list:SetSize(900,480); local y=0
    for _,t in ipairs(snapshot.tasks or {}) do
        Box(list,0,y,875,54,t.done and th.success or th.orange,function(_,w,h) draw.SimpleText(t.title or "Task","MN_Text",16,18,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) draw.SimpleText((t.done and "READY" or "Scheduled").." | created "..(t.created or ""),"MN_Small",16,40,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end)
        y=y+62
    end
end

local function DrawPage(content)
    content:Clear()
    if activeTab=="Overview" then BuildOverview(content) elseif activeTab=="Alerts" then BuildAlerts(content) elseif activeTab=="Players" then BuildPlayers(content) elseif activeTab=="Heatmap" then BuildHeatmap(content) elseif activeTab=="Tasks" then BuildTasks(content) end
end

function MemoNetwork.Monitoring.Open()
    if not CanOpen() then return end
    if IsValid(frame) then frame:Remove(); frame=nil; return end
    RequestSnapshot()
    local th=Theme(); local w,h=math.min(1040,ScrW()-60),math.min(760,ScrH()-60)
    frame=vgui.Create("DFrame"); frame:SetSize(w,h); frame:Center(); frame:SetTitle(""); frame:SetDraggable(false); frame:ShowCloseButton(false); frame:MakePopup()
    frame.Paint=function(_,pw,ph) draw.RoundedBox(14,0,0,pw,ph,th.bg); draw.RoundedBoxEx(14,0,0,pw,78,th.orange,true,true,false,false); draw.SimpleText("MemoNetwork Live Monitoring & Automation","MN_Title",26,27,Color(10,10,10),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER); draw.SimpleText("Alpha 25 - performance, tasks, diagnostics, heatmap and automation","MN_Text",26,55,Color(25,25,25),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
    local close=vgui.Create("DButton",frame); close:SetPos(w-56,20); close:SetSize(36,36); close:SetText("X"); close.DoClick=function() frame:Remove(); frame=nil end
    local sidebar=vgui.Create("DPanel",frame); sidebar:SetPos(20,100); sidebar:SetSize(250,h-124); sidebar.Paint=function(_,pw,ph) draw.RoundedBox(12,0,0,pw,ph,th.panel) end
    local content=vgui.Create("DPanel",frame); content:SetPos(292,100); content:SetSize(w-322,h-124); content.Paint=function() end
    local tabs={{"Overview","Graphs"},{"Alerts","Automation"},{"Players","Activity"},{"Heatmap","Risk map"},{"Tasks","Scheduler"}}
    local y=16; for _,tab in ipairs(tabs) do Button(sidebar,14,y,222,50,tab[1],tab[2],function() activeTab=tab[1]; DrawPage(content) end,activeTab==tab[1]); y=y+60 end
    DrawPage(content)
end

concommand.Add("mn_monitor", MemoNetwork.Monitoring.Open)
