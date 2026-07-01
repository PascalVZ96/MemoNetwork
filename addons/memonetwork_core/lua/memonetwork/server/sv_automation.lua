-- MemoNetwork Alpha 25 Automation Engine
-- Live monitoring, diagnostics, alerts and scheduled admin reminders.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Automation = MemoNetwork.Automation or {}

util.AddNetworkString("MemoNetwork_AutomationSnapshot")
util.AddNetworkString("MemoNetwork_RequestAutomationSnapshot")
util.AddNetworkString("MemoNetwork_AutomationCommand")

local history = {}
local alerts = {}
local tasks = {}
local playerActivity = {}
local nextTick = 0
local nextSnapshot = 0

local function HasPerm(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        local ok, allowed = pcall(MemoNetwork.Ranks.HasPermission, ply, "admin.open")
        if ok and allowed then return true end
    end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function Alert(kind, text, severity)
    local entry = {time = os.date("%H:%M:%S"), kind = kind or "alert", text = text or "", severity = severity or "info"}
    table.insert(alerts, 1, entry)
    while #alerts > 80 do table.remove(alerts) end
    if MemoNetwork.Timeline and MemoNetwork.Timeline.Push then
        MemoNetwork.Timeline.Push("automation", "Automation", text or "", severity or "info")
    end
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

local function OwnerInfo(ent)
    local owner = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(owner) and owner:IsPlayer() then return owner:Nick(), owner:SteamID() end
    local name = ent:GetNWString("MemoNetworkOwnerName", "")
    local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
    if sid ~= "" then return name ~= "" and name or sid, sid end
    return "Unknown", "unknown"
end

local function ConstraintCount(ent)
    if not constraint or not constraint.GetTable then return 0 end
    local ok, tbl = pcall(constraint.GetTable, ent)
    if not ok or not istable(tbl) then return 0 end
    return #tbl
end

local function BuildSnapshot()
    local totals = {all=0, props=0, vehicles=0, wire=0, lights=0, npcs=0, ragdolls=0, other=0, unknown=0, constraints=0}
    local owners = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() then
            local typ = EntityType(ent)
            if typ ~= "unknown" then
                local name, sid = OwnerInfo(ent)
                local cc = ConstraintCount(ent)
                totals.all = totals.all + 1
                totals[typ] = (totals[typ] or 0) + 1
                totals.constraints = totals.constraints + cc
                if sid == "unknown" then totals.unknown = totals.unknown + 1 end
                owners[sid] = owners[sid] or {name=name, steamID=sid, count=0, props=0, vehicles=0, wire=0, lights=0, npcs=0, constraints=0, score=100, risk="OK"}
                local o = owners[sid]
                if name ~= "Unknown" then o.name = name end
                o.count = o.count + 1
                o[typ] = (o[typ] or 0) + 1
                o.constraints = o.constraints + cc
            end
        end
    end
    local list = {}
    for _, o in pairs(owners) do
        local penalty = 0
        if o.count > 300 then penalty = penalty + 15 end
        if o.count > 700 then penalty = penalty + 30 end
        if o.constraints > 500 then penalty = penalty + 20 end
        if (o.wire or 0) > 100 then penalty = penalty + 15 end
        if (o.vehicles or 0) > 15 then penalty = penalty + 10 end
        o.score = math.Clamp(100 - penalty, 1, 100)
        o.risk = o.score > 75 and "OK" or (o.score > 45 and "WARN" or "HIGH")
        list[#list + 1] = o
    end
    table.sort(list, function(a,b) return a.count > b.count end)
    return {time=os.date("%H:%M:%S"), uptime=math.floor(CurTime()), map=game.GetMap(), players=#player.GetAll(), maxPlayers=game.MaxPlayers(), totals=totals, owners=list, alerts=alerts, tasks=tasks, activity=playerActivity}
end

local function SendSnapshot(ply)
    local snap = BuildSnapshot()
    snap.history = history
    net.Start("MemoNetwork_AutomationSnapshot")
        net.WriteString(util.TableToJSON(snap, false) or "{}")
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end

local function RecordHistory()
    local snap = BuildSnapshot()
    table.insert(history, 1, {time=snap.time, entities=snap.totals.all, props=snap.totals.props, vehicles=snap.totals.vehicles, wire=snap.totals.wire, constraints=snap.totals.constraints, players=snap.players})
    while #history > 60 do table.remove(history) end

    if snap.totals.all > 1400 then Alert("entities", "Critical entity count: " .. snap.totals.all, "error")
    elseif snap.totals.all > 900 then Alert("entities", "High entity count: " .. snap.totals.all, "warning") end
    if snap.totals.unknown > 150 then Alert("ownership", "Many entities without owner: " .. snap.totals.unknown, "warning") end
    if snap.owners[1] and snap.owners[1].count > 750 then Alert("build", "Very large build: " .. snap.owners[1].name .. " / " .. snap.owners[1].count .. " entities", "warning") end
end

hook.Add("PlayerSpawnedProp", "MemoNetwork_Automation_Prop", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    playerActivity[sid] = playerActivity[sid] or {name=ply:Nick(), props=0, vehicles=0, npcs=0, chat=0, joins=0}
    playerActivity[sid].name = ply:Nick()
    playerActivity[sid].props = (playerActivity[sid].props or 0) + 1
end)

hook.Add("PlayerSpawnedVehicle", "MemoNetwork_Automation_Vehicle", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    playerActivity[sid] = playerActivity[sid] or {name=ply:Nick(), props=0, vehicles=0, npcs=0, chat=0, joins=0}
    playerActivity[sid].vehicles = (playerActivity[sid].vehicles or 0) + 1
end)

hook.Add("PlayerSpawnedNPC", "MemoNetwork_Automation_NPC", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    playerActivity[sid] = playerActivity[sid] or {name=ply:Nick(), props=0, vehicles=0, npcs=0, chat=0, joins=0}
    playerActivity[sid].npcs = (playerActivity[sid].npcs or 0) + 1
end)

hook.Add("PlayerSay", "MemoNetwork_Automation_Chat", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    playerActivity[sid] = playerActivity[sid] or {name=ply:Nick(), props=0, vehicles=0, npcs=0, chat=0, joins=0}
    playerActivity[sid].chat = (playerActivity[sid].chat or 0) + 1
end)

hook.Add("PlayerInitialSpawn", "MemoNetwork_Automation_Join", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        local sid = ply:SteamID()
        playerActivity[sid] = playerActivity[sid] or {name=ply:Nick(), props=0, vehicles=0, npcs=0, chat=0, joins=0}
        playerActivity[sid].joins = (playerActivity[sid].joins or 0) + 1
    end)
end)

hook.Add("Think", "MemoNetwork_Automation_Think", function()
    if CurTime() >= nextTick then
        nextTick = CurTime() + 30
        RecordHistory()
    end
    if CurTime() >= nextSnapshot then
        nextSnapshot = CurTime() + 10
        SendSnapshot(nil)
    end
    for i = #tasks, 1, -1 do
        local task = tasks[i]
        if task.runAt and CurTime() >= task.runAt and not task.done then
            task.done = true
            Alert("task", "Scheduled task ready: " .. (task.title or "Task"), "success")
        end
    end
end)

net.Receive("MemoNetwork_RequestAutomationSnapshot", function(_, ply)
    if not HasPerm(ply) then return end
    SendSnapshot(ply)
end)

net.Receive("MemoNetwork_AutomationCommand", function(_, ply)
    if not HasPerm(ply) then return end
    local cmd = net.ReadString()
    local payload = net.ReadString()
    if cmd == "add_task" then
        table.insert(tasks, 1, {title=payload ~= "" and payload or "Admin reminder", created=os.date("%H:%M:%S"), runAt=CurTime()+600, done=false})
        Alert("task", "Scheduled reminder created: " .. payload, "success")
    elseif cmd == "clear_alerts" then
        alerts = {}
    elseif cmd == "diagnostics" then
        RecordHistory()
        Alert("diagnostics", "Manual diagnostics completed", "success")
    end
    SendSnapshot(ply)
end)
