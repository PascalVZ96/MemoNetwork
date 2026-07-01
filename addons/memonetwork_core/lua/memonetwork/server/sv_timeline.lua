-- MemoNetwork Alpha 22 Server Intelligence
-- Timeline, alerts and lightweight build intelligence for admin dashboards.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Timeline = MemoNetwork.Timeline or {}

util.AddNetworkString("MemoNetwork_TimelineEvent")
util.AddNetworkString("MemoNetwork_IntelligenceSnapshot")
util.AddNetworkString("MemoNetwork_RequestIntelligenceSnapshot")

local events = {}
local maxEvents = 120
local nextSnapshot = 0

local function HasPerm(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        local ok, allowed = pcall(MemoNetwork.Ranks.HasPermission, ply, "admin.open")
        if ok and allowed then return true end
    end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function PushEvent(kind, actor, message, severity)
    local ev = {
        time = os.date("%H:%M:%S"),
        kind = kind or "info",
        actor = actor or "Server",
        message = message or "",
        severity = severity or "info"
    }

    table.insert(events, 1, ev)
    while #events > maxEvents do table.remove(events) end

    net.Start("MemoNetwork_TimelineEvent")
        net.WriteString(ev.time)
        net.WriteString(ev.kind)
        net.WriteString(ev.actor)
        net.WriteString(ev.message)
        net.WriteString(ev.severity)
    net.Broadcast()
end

MemoNetwork.Timeline.Push = PushEvent

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
    if not IsValid(ent) then return "Unknown", "unknown" end
    local owner = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(owner) and owner:IsPlayer() then return owner:Nick(), owner:SteamID() end
    local name = ent:GetNWString("MemoNetworkOwnerName", "")
    local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
    if sid ~= "" then return name ~= "" and name or sid, sid end
    return "Unknown", "unknown"
end

local function BuildSnapshot()
    local totals = {all = 0, owned = 0, unknown = 0, props = 0, vehicles = 0, wire = 0, lights = 0, npcs = 0, ragdolls = 0, other = 0}
    local owners = {}

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() then
            local typ = EntityType(ent)
            if typ ~= "unknown" then
                local name, sid = OwnerInfo(ent)
                totals.all = totals.all + 1
                totals[typ] = (totals[typ] or 0) + 1
                if sid == "unknown" then totals.unknown = totals.unknown + 1 else totals.owned = totals.owned + 1 end
                owners[sid] = owners[sid] or {name = name, steamID = sid, count = 0, props = 0, vehicles = 0, wire = 0, lights = 0, npcs = 0, score = 100}
                local o = owners[sid]
                if name ~= "Unknown" then o.name = name end
                o.count = o.count + 1
                o[typ] = (o[typ] or 0) + 1
            end
        end
    end

    local list = {}
    for _, o in pairs(owners) do
        local penalty = 0
        if o.count > 300 then penalty = penalty + 20 end
        if o.count > 700 then penalty = penalty + 30 end
        if (o.wire or 0) > 100 then penalty = penalty + 15 end
        if (o.vehicles or 0) > 12 then penalty = penalty + 10 end
        o.score = math.Clamp(100 - penalty, 5, 100)
        list[#list + 1] = o
    end
    table.sort(list, function(a, b) return a.count > b.count end)

    return {totals = totals, owners = list, events = events, time = os.date("%H:%M:%S"), map = game.GetMap(), players = #player.GetAll(), maxPlayers = game.MaxPlayers()}
end

local function SendSnapshot(ply)
    local snap = BuildSnapshot()
    local json = util.TableToJSON(snap, false) or "{}"
    net.Start("MemoNetwork_IntelligenceSnapshot")
        net.WriteString(json)
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end

net.Receive("MemoNetwork_RequestIntelligenceSnapshot", function(_, ply)
    if not HasPerm(ply) then return end
    SendSnapshot(ply)
end)

hook.Add("PlayerInitialSpawn", "MemoNetwork_Timeline_Join", function(ply)
    timer.Simple(1, function() if IsValid(ply) then PushEvent("join", ply:Nick(), "joined the server", "success") end end)
end)

hook.Add("PlayerDisconnected", "MemoNetwork_Timeline_Leave", function(ply)
    PushEvent("leave", ply:Nick(), "left the server", "warning")
end)

hook.Add("PlayerSpawnedProp", "MemoNetwork_Timeline_PropSpawn", function(ply, model, ent)
    if not IsValid(ply) then return end
    PushEvent("spawn", ply:Nick(), "spawned prop " .. tostring(model or "prop"), "info")
end)

hook.Add("PlayerSpawnedVehicle", "MemoNetwork_Timeline_VehicleSpawn", function(ply, ent)
    if not IsValid(ply) then return end
    PushEvent("vehicle", ply:Nick(), "spawned a vehicle", "warning")
end)

hook.Add("PlayerSpawnedNPC", "MemoNetwork_Timeline_NPCSpawn", function(ply, ent)
    if not IsValid(ply) then return end
    PushEvent("npc", ply:Nick(), "spawned an NPC", "warning")
end)

hook.Add("Think", "MemoNetwork_Intelligence_AutoSnapshot", function()
    if CurTime() < nextSnapshot then return end
    nextSnapshot = CurTime() + 20
    SendSnapshot(nil)

    local snap = BuildSnapshot()
    if snap.totals.all > 1200 then
        PushEvent("alert", "Server", "High entity count: " .. snap.totals.all, "error")
    elseif snap.owners[1] and snap.owners[1].count > 600 then
        PushEvent("alert", "Server", "Large build detected: " .. snap.owners[1].name .. " / " .. snap.owners[1].count .. " entities", "warning")
    end
end)

concommand.Add("mn_timeline_test", function(ply)
    if IsValid(ply) and not HasPerm(ply) then return end
    PushEvent("test", IsValid(ply) and ply:Nick() or "Console", "created a test timeline event", "success")
end)
