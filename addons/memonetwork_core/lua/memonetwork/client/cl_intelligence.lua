-- MemoNetwork Alpha 22 Client Intelligence Dashboard
-- Live timeline, server health alerts and build scoring.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Intelligence = MemoNetwork.Intelligence or {}

local frame
local activeTab = "Timeline"
local events = {}
local snapshot = {totals = {}, owners = {}, events = {}}

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

local function SeverityColor(sev)
    local th = Theme()
    if sev == "success" then return th.success end
    if sev == "warning" then return th.warning end
    if sev == "error" then return th.danger end
    return th.orange
end

local function RequestSnapshot()
    net.Start("MemoNetwork_RequestIntelligenceSnapshot")
    net.SendToServer()
end

net.Receive("MemoNetwork_TimelineEvent", function()
    table.insert(events, 1, {time = net.ReadString(), kind = net.ReadString(), actor = net.ReadString(), message = net.ReadString(), severity = net.ReadString()})
    while #events > 100 do table.remove(events) end
end)

net.Receive("MemoNetwork_IntelligenceSnapshot", function()
    local data = util.JSONToTable(net.ReadString() or "{}") or {}
    snapshot = data
    if istable(data.events) then events = data.events end
end)

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
        self.HoverAmount = Lerp(FrameTime()*10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(10,0,0,pw,ph,Color(18+self.HoverAmount*10,24+self.HoverAmount*10,32+self.HoverAmount*10,238))
        draw.RoundedBox(8,0,ph-5,pw,5,danger and th.danger or th.orange)
        draw.SimpleText(title,"MN_Text",14,subtitle and subtitle ~= "" and 17 or ph/2,th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(subtitle,"MN_Small",14,38,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function() surface.PlaySound("buttons/button15.wav") if fn then fn() end end
    return b
end

local function Stat(parent, x, y, w, h, title, value, accent)
    local th = Theme()
    Box(parent,x,y,w,h,accent or th.orange,function(_,pw,ph)
        draw.SimpleText(string.upper(title),"MN_Small",12,16,th.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value or 0),"MN_Subtitle",12,42,accent or th.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)
end

local function BuildTimeline(parent)
    local th = Theme()
    Button(parent, 0, 0, 150, 42, "Refresh", "Snapshot", RequestSnapshot)
    Button(parent, 166, 0, 150, 42, "Test Event", "Console cmd", function() RunConsoleCommand("mn_timeline_test") end)
    local list = vgui.Create("DScrollPanel", parent)
    list:SetPos(0, 60); list:SetSize(920, 500)
    local y = 0
    for i, ev in ipairs(events or {}) do
        local row = Box(list, 0, y, 895, 54, SeverityColor(ev.severity), function(_,w,h)
            draw.SimpleText((ev.time or "--:--") .. "  " .. string.upper(ev.kind or "info"), "MN_Small", 16, 15, SeverityColor(ev.severity), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText((ev.actor or "Server") .. " - " .. (ev.message or ""), "MN_Text", 16, 37, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end)
        y = y + 62
    end
end

local function BuildHealth(parent)
    local th = Theme()
    local totals = snapshot.totals or {}
    Stat(parent,0,0,140,70,"Entities",totals.all or 0,th.orange)
    Stat(parent,154,0,140,70,"Owned",totals.owned or 0,th.success)
    Stat(parent,308,0,140,70,"Unknown",totals.unknown or 0,(totals.unknown or 0) > 0 and th.warning or th.success)
    Stat(parent,462,0,140,70,"Players",snapshot.players or #player.GetAll(),th.blue)
    Stat(parent,616,0,140,70,"Map",snapshot.map or game.GetMap(),th.purple)
    local health = "Good"
    local color = th.success
    if (totals.all or 0) > 1200 then health = "Critical" color = th.danger elseif (totals.all or 0) > 800 then health = "Warning" color = th.warning end
    Stat(parent,770,0,140,70,"Health",health,color)

    Box(parent,0,94,920,180,color,function(_,w,h)
        draw.SimpleText("Server Intelligence", "MN_Title", 22, 34, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Live server snapshot: " .. tostring(snapshot.time or "waiting..."), "MN_Text", 22, 78, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Entities are scored using entity count, vehicles and wire load.", "MN_Text", 22, 112, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alerts appear automatically in the timeline.", "MN_Text", 22, 146, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
end

local function BuildScores(parent)
    local th = Theme()
    local list = vgui.Create("DScrollPanel", parent)
    list:SetPos(0, 0); list:SetSize(920, 560)
    local y = 0
    for i, owner in ipairs(snapshot.owners or {}) do
        local score = owner.score or 100
        local color = score > 75 and th.success or (score > 45 and th.warning or th.danger)
        Box(list, 0, y, 895, 72, color, function(_,w,h)
            draw.SimpleText("#" .. i .. "  " .. (owner.name or owner.steamID or "Unknown"), "MN_Subtitle", 16, 22, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText((owner.count or 0) .. " entities | props " .. (owner.props or 0) .. " | wire " .. (owner.wire or 0) .. " | vehicles " .. (owner.vehicles or 0), "MN_Small", 16, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Score " .. score .. "/100", "MN_Subtitle", w - 18, 34, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end)
        y = y + 82
    end
end

local function DrawPage(content)
    content:Clear()
    if activeTab == "Timeline" then BuildTimeline(content)
    elseif activeTab == "Health" then BuildHealth(content)
    elseif activeTab == "Build Scores" then BuildScores(content)
    end
end

function MemoNetwork.Intelligence.Open()
    if not CanOpen() then return end
    if IsValid(frame) then frame:Remove() frame = nil return end
    RequestSnapshot()
    local th = Theme()
    local w,h = math.min(1040,ScrW()-60), math.min(760,ScrH()-60)
    frame = vgui.Create("DFrame")
    frame:SetSize(w,h); frame:Center(); frame:SetTitle(""); frame:SetDraggable(false); frame:ShowCloseButton(false); frame:MakePopup()
    frame.Paint = function(_,pw,ph)
        draw.RoundedBox(14,0,0,pw,ph,th.bg)
        draw.RoundedBoxEx(14,0,0,pw,78,th.orange,true,true,false,false)
        draw.SimpleText("MemoNetwork Intelligence", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 22 - timeline, alerts and build scores", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local close = vgui.Create("DButton", frame); close:SetPos(w-56,20); close:SetSize(36,36); close:SetText("X"); close.DoClick = function() frame:Remove() frame=nil end
    local sidebar = vgui.Create("DPanel", frame); sidebar:SetPos(20,100); sidebar:SetSize(250,h-124); sidebar.Paint = function(_,pw,ph) draw.RoundedBox(12,0,0,pw,ph,th.panel) end
    local content = vgui.Create("DPanel", frame); content:SetPos(292,100); content:SetSize(w-322,h-124); content.Paint = function() end
    local tabs = {{"Timeline","Live events"},{"Health","Server alerts"},{"Build Scores","Top builds"}}
    local y=16
    for _,tab in ipairs(tabs) do
        Button(sidebar,14,y,222,50,tab[1],tab[2],function() activeTab=tab[1] DrawPage(content) end, activeTab==tab[1])
        y=y+60
    end
    DrawPage(content)
end

concommand.Add("mn_intel", MemoNetwork.Intelligence.Open)
