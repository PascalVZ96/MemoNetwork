-- MemoNetwork Alpha 14 Server Admin Tools
-- Permission-aware actions, map control, broadcasts, live logs and player management.

util.AddNetworkString("MemoNetwork_AdminAction")
util.AddNetworkString("MemoNetwork_AdminResult")
util.AddNetworkString("MemoNetwork_AdminLog")
util.AddNetworkString("MemoNetwork_Broadcast")

local function HasPerm(ply, permission)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if MemoNetwork and MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, permission)
    end
    return ply:IsAdmin()
end

local function RequirePerm(ply, permission)
    if HasPerm(ply, permission) then return true end
    net.Start("MemoNetwork_AdminResult")
        net.WriteString("Missing permission: " .. permission)
        net.WriteString("error")
    net.Send(ply)
    return false
end

local function SendResult(ply, message, kind)
    net.Start("MemoNetwork_AdminResult")
        net.WriteString(message or "")
        net.WriteString(kind or "info")
    net.Send(ply)
end

local function LogAdmin(actor, message, kind)
    net.Start("MemoNetwork_AdminLog")
        net.WriteString(os.date("%H:%M:%S"))
        net.WriteString(IsValid(actor) and actor:Nick() or "Console")
        net.WriteString(message or "")
        net.WriteString(kind or "info")
    net.Broadcast()
end

local function IsKnownMap(mapName)
    mapName = tostring(mapName or "")
    if mapName == "" then return false end

    for _, data in ipairs((MemoNetwork.Config and MemoNetwork.Config.Maps) or {}) do
        if data.map == mapName then return true end
    end

    return file.Exists("maps/" .. mapName .. ".bsp", "GAME")
end

local function ReadTarget()
    local ok, target = pcall(net.ReadEntity)
    if ok and IsValid(target) and target:IsPlayer() then return target end
end

local function RemoveMatching(predicate)
    local removed = 0
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and predicate(ent) then
            ent:Remove()
            removed = removed + 1
        end
    end
    return removed
end

local function IsProp(ent)
    local class = ent:GetClass()
    return class == "prop_physics" or class == "prop_physics_multiplayer" or class == "prop_dynamic" or class == "prop_dynamic_override"
end

local function IsVehicle(ent)
    local class = ent:GetClass()
    return class == "prop_vehicle_jeep" or class == "prop_vehicle_airboat" or class == "prop_vehicle_prisoner_pod" or string.StartWith(class, "gmod_sent_vehicle")
end

local function IsProjectile(ent)
    local class = ent:GetClass()
    return string.find(class, "grenade", 1, true) or string.find(class, "rocket", 1, true) or string.find(class, "missile", 1, true) or class == "crossbow_bolt"
end

hook.Add("PlayerInitialSpawn", "MemoNetwork_AdminLog_PlayerJoin", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then LogAdmin(nil, ply:Nick() .. " joined the server", "success") end
    end)
end)

hook.Add("PlayerDisconnected", "MemoNetwork_AdminLog_PlayerLeave", function(ply)
    LogAdmin(nil, ply:Nick() .. " left the server", "warning")
end)

net.Receive("MemoNetwork_AdminAction", function(_, ply)
    if not RequirePerm(ply, "admin.open") then return end
    local action = net.ReadString()

    if action == "broadcast" then
        if not RequirePerm(ply, "broadcast") then return end
        local message = string.Trim(net.ReadString() or "")
        if message == "" then SendResult(ply, "Broadcast message is empty.", "error") return end
        net.Start("MemoNetwork_Broadcast")
            net.WriteString(ply:Nick())
            net.WriteString(message)
        net.Broadcast()
        SendResult(ply, "Broadcast sent.", "success")
        LogAdmin(ply, "broadcasted: " .. message, "info")
        return
    end

    if action == "change_map" then
        if not RequirePerm(ply, "map.change") then return end
        local mapName = net.ReadString()
        if not IsKnownMap(mapName) then SendResult(ply, "Map is not available: " .. mapName, "error") return end
        SendResult(ply, "Changing map to " .. mapName .. "...", "warning")
        LogAdmin(ply, "changed map to " .. mapName, "warning")
        timer.Simple(1, function() RunConsoleCommand("changelevel", mapName) end)
        return
    end

    if action == "restart_map" then
        if not RequirePerm(ply, "map.restart") then return end
        local current = game.GetMap()
        SendResult(ply, "Restarting " .. current .. "...", "warning")
        LogAdmin(ply, "restarted map " .. current, "warning")
        timer.Simple(1, function() RunConsoleCommand("changelevel", current) end)
        return
    end

    if action == "cleanup" then
        if not RequirePerm(ply, "cleanup") then return end
        game.CleanUpMap(false)
        SendResult(ply, "Map cleanup completed.", "success")
        LogAdmin(ply, "cleaned up the map", "success")
        return
    elseif action == "cleanup_props" then
        if not RequirePerm(ply, "cleanup") then return end
        local count = RemoveMatching(IsProp)
        SendResult(ply, "Removed " .. count .. " props.", "success")
        LogAdmin(ply, "removed " .. count .. " props", "success")
        return
    elseif action == "cleanup_vehicles" then
        if not RequirePerm(ply, "cleanup") then return end
        local count = RemoveMatching(IsVehicle)
        SendResult(ply, "Removed " .. count .. " vehicles.", "success")
        LogAdmin(ply, "removed " .. count .. " vehicles", "success")
        return
    elseif action == "cleanup_npcs" then
        if not RequirePerm(ply, "cleanup") then return end
        local count = RemoveMatching(function(ent) return ent:IsNPC() end)
        SendResult(ply, "Removed " .. count .. " NPCs.", "success")
        LogAdmin(ply, "removed " .. count .. " NPCs", "success")
        return
    elseif action == "cleanup_ragdolls" then
        if not RequirePerm(ply, "cleanup") then return end
        local count = RemoveMatching(function(ent) return ent:GetClass() == "prop_ragdoll" end)
        SendResult(ply, "Removed " .. count .. " ragdolls.", "success")
        LogAdmin(ply, "removed " .. count .. " ragdolls", "success")
        return
    elseif action == "cleanup_effects" then
        if not RequirePerm(ply, "cleanup") then return end
        local count = RemoveMatching(function(ent)
            local class = ent:GetClass()
            return class == "env_sprite" or class == "env_smoketrail" or class == "env_fire" or class == "env_explosion" or class == "info_particle_system"
        end)
        SendResult(ply, "Removed " .. count .. " effects.", "success")
        LogAdmin(ply, "removed " .. count .. " effects", "success")
        return
    elseif action == "cleanup_projectiles" then
        if not RequirePerm(ply, "cleanup") then return end
        local count = RemoveMatching(IsProjectile)
        SendResult(ply, "Removed " .. count .. " projectiles.", "success")
        LogAdmin(ply, "removed " .. count .. " projectiles", "success")
        return
    end

    local target = ReadTarget()

    if action == "god" then
        if ply:HasGodMode() then ply:GodDisable() SendResult(ply, "God mode disabled.", "warning") LogAdmin(ply, "disabled god mode", "warning") else ply:GodEnable() SendResult(ply, "God mode enabled.", "success") LogAdmin(ply, "enabled god mode", "success") end
    elseif action == "noclip" then
        if ply:GetMoveType() == MOVETYPE_NOCLIP then ply:SetMoveType(MOVETYPE_WALK) SendResult(ply, "Noclip disabled.", "warning") LogAdmin(ply, "disabled noclip", "warning") else ply:SetMoveType(MOVETYPE_NOCLIP) SendResult(ply, "Noclip enabled.", "success") LogAdmin(ply, "enabled noclip", "success") end
    elseif action == "health" then
        ply:SetHealth(100) ply:SetArmor(100) SendResult(ply, "Health and armor restored.", "success") LogAdmin(ply, "restored health and armor", "success")
    elseif action == "teleport" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        ply:SetPos(target:GetPos() + Vector(45, 0, 0)) SendResult(ply, "Teleported to " .. target:Nick() .. ".", "success") LogAdmin(ply, "teleported to " .. target:Nick(), "info")
    elseif action == "bring" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        target:SetPos(ply:GetPos() + ply:GetForward() * 80) SendResult(ply, "Brought " .. target:Nick() .. ".", "success") LogAdmin(ply, "brought " .. target:Nick(), "info")
    elseif action == "heal_target" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        target:SetHealth(100) target:SetArmor(100) SendResult(ply, "Healed " .. target:Nick() .. ".", "success") LogAdmin(ply, "healed " .. target:Nick(), "success")
    elseif action == "freeze" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        target:SetMoveType(target:GetMoveType() == MOVETYPE_NONE and MOVETYPE_WALK or MOVETYPE_NONE) SendResult(ply, "Toggled freeze for " .. target:Nick() .. ".", "success") LogAdmin(ply, "toggled freeze for " .. target:Nick(), "warning")
    elseif action == "slay" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        target:Kill() SendResult(ply, "Slayed " .. target:Nick() .. ".", "warning") LogAdmin(ply, "slayed " .. target:Nick(), "warning")
    elseif action == "respawn" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        target:Spawn() SendResult(ply, "Respawned " .. target:Nick() .. ".", "success") LogAdmin(ply, "respawned " .. target:Nick(), "success")
    elseif action == "kick" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        target:Kick("Kicked by " .. ply:Nick()) SendResult(ply, "Kicked " .. target:Nick() .. ".", "warning") LogAdmin(ply, "kicked " .. target:Nick(), "warning")
    elseif action == "spectate" and IsValid(target) then
        if not RequirePerm(ply, "players.manage") then return end
        if ply == target then SendResult(ply, "You cannot spectate yourself.", "warning") return end
        ply:Spectate(OBS_MODE_IN_EYE) ply:SpectateEntity(target) SendResult(ply, "Spectating " .. target:Nick() .. ". Use noclip/spawn to return.", "success") LogAdmin(ply, "started spectating " .. target:Nick(), "info")
    else
        SendResult(ply, "Unknown admin action.", "error")
    end
end)
