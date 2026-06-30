-- MemoNetwork Alpha 19.2 Build Tools Server
-- Per-owner cleanup and freeze/unfreeze actions for the Build Manager tools.

MemoNetwork = MemoNetwork or {}
MemoNetwork.BuildTools = MemoNetwork.BuildTools or {}

util.AddNetworkString("MemoNetwork_BuildAction")
util.AddNetworkString("MemoNetwork_BuildActionResult")

local function HasPerm(ply, permission)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if MemoNetwork and MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        local ok, allowed = pcall(MemoNetwork.Ranks.HasPermission, ply, permission)
        if ok and allowed then return true end
    end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function SendResult(ply, message, kind)
    net.Start("MemoNetwork_BuildActionResult")
        net.WriteString(message or "")
        net.WriteString(kind or "info")
    net.Send(ply)
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

local function OwnerSteamID(ent)
    if not IsValid(ent) then return "" end

    local owner = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(owner) and owner:IsPlayer() then return owner:SteamID() end

    local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
    if sid ~= "" then return sid end

    if ent.CPPIGetOwner then
        local ok, cppiOwner = pcall(ent.CPPIGetOwner, ent)
        if ok and IsValid(cppiOwner) and cppiOwner:IsPlayer() then return cppiOwner:SteamID() end
    end

    if ent.GetCreator then
        local ok, creator = pcall(ent.GetCreator, ent)
        if ok and IsValid(creator) and creator:IsPlayer() then return creator:SteamID() end
    end

    return ""
end

local function MatchesOwnerAndType(ent, steamID, category)
    if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() then return false end
    if OwnerSteamID(ent) ~= steamID then return false end

    local typ = EntityType(ent)
    if typ == "unknown" then return false end
    if category == "all" or category == "" then return true end
    return typ == category
end

local function FreezeEntity(ent, frozen)
    if not IsValid(ent) or not ent.GetPhysicsObject then return false end
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return false end
    phys:EnableMotion(not frozen)
    phys:Wake()
    return true
end

local function CleanupOwner(steamID, category)
    local count = 0
    for _, ent in ipairs(ents.GetAll()) do
        if MatchesOwnerAndType(ent, steamID, category) then
            ent:Remove()
            count = count + 1
        end
    end
    return count
end

local function FreezeOwner(steamID, category, frozen)
    local count = 0
    for _, ent in ipairs(ents.GetAll()) do
        if MatchesOwnerAndType(ent, steamID, category) and FreezeEntity(ent, frozen) then
            count = count + 1
        end
    end
    return count
end

net.Receive("MemoNetwork_BuildAction", function(_, ply)
    if not HasPerm(ply, "cleanup") and not HasPerm(ply, "players.manage") then
        SendResult(ply, "Missing permission: cleanup or players.manage", "error")
        return
    end

    local action = net.ReadString()
    local steamID = net.ReadString()
    local category = net.ReadString()

    steamID = tostring(steamID or "")
    category = tostring(category or "all")

    if steamID == "" or steamID == "unknown" then
        SendResult(ply, "Select a known online/registered owner first.", "error")
        return
    end

    if action == "cleanup" then
        local count = CleanupOwner(steamID, category)
        SendResult(ply, "Removed " .. count .. " " .. category .. " entities for " .. steamID .. ".", "success")
        return
    end

    if action == "freeze" then
        local count = FreezeOwner(steamID, category, true)
        SendResult(ply, "Frozen " .. count .. " " .. category .. " entities for " .. steamID .. ".", "success")
        return
    end

    if action == "unfreeze" then
        local count = FreezeOwner(steamID, category, false)
        SendResult(ply, "Unfrozen " .. count .. " " .. category .. " entities for " .. steamID .. ".", "success")
        return
    end

    SendResult(ply, "Unknown build action: " .. action, "error")
end)
