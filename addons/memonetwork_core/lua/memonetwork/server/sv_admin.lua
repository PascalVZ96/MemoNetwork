-- MemoNetwork Lite Admin Tools
-- Alpha 10.3: supports self actions, target actions and map changing.

util.AddNetworkString("MemoNetwork_AdminAction")
util.AddNetworkString("MemoNetwork_AdminResult")

local function IsAllowed(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if MemoNetwork and MemoNetwork.Ranks and MemoNetwork.Ranks.CanAdmin then
        return MemoNetwork.Ranks.CanAdmin(ply)
    end
    return ply:IsAdmin()
end

local function SendResult(ply, message, kind)
    net.Start("MemoNetwork_AdminResult")
        net.WriteString(message or "")
        net.WriteString(kind or "info")
    net.Send(ply)
end

local function IsKnownMap(mapName)
    mapName = tostring(mapName or "")
    if mapName == "" then return false end

    local maps = MemoNetwork.Config and MemoNetwork.Config.Maps or {}
    for _, data in ipairs(maps) do
        if data.map == mapName then return true end
    end

    return file.Exists("maps/" .. mapName .. ".bsp", "GAME")
end

local function ReadOptionalTarget()
    local ok, target = pcall(net.ReadEntity)
    if ok and IsValid(target) and target:IsPlayer() then
        return target
    end
end

net.Receive("MemoNetwork_AdminAction", function(_, ply)
    if not IsAllowed(ply) then
        SendResult(ply, "You do not have permission.", "error")
        return
    end

    local action = net.ReadString()

    if action == "change_map" then
        local mapName = net.ReadString()

        if not IsKnownMap(mapName) then
            SendResult(ply, "Map is not available: " .. mapName, "error")
            return
        end

        SendResult(ply, "Changing map to " .. mapName .. "...", "warning")
        timer.Simple(1, function()
            RunConsoleCommand("changelevel", mapName)
        end)
        return
    end

    if action == "restart_map" then
        local current = game.GetMap()
        SendResult(ply, "Restarting " .. current .. "...", "warning")
        timer.Simple(1, function()
            RunConsoleCommand("changelevel", current)
        end)
        return
    end

    local target = ReadOptionalTarget()

    if action == "cleanup" then
        game.CleanUpMap(false)
        SendResult(ply, "Map cleanup completed.", "success")
    elseif action == "god" then
        if ply:HasGodMode() then
            ply:GodDisable()
            SendResult(ply, "God mode disabled.", "warning")
        else
            ply:GodEnable()
            SendResult(ply, "God mode enabled.", "success")
        end
    elseif action == "noclip" then
        if ply:GetMoveType() == MOVETYPE_NOCLIP then
            ply:SetMoveType(MOVETYPE_WALK)
            SendResult(ply, "Noclip disabled.", "warning")
        else
            ply:SetMoveType(MOVETYPE_NOCLIP)
            SendResult(ply, "Noclip enabled.", "success")
        end
    elseif action == "health" then
        ply:SetHealth(100)
        ply:SetArmor(100)
        SendResult(ply, "Health and armor restored.", "success")
    elseif action == "teleport" and IsValid(target) then
        ply:SetPos(target:GetPos() + Vector(45, 0, 0))
        SendResult(ply, "Teleported to " .. target:Nick() .. ".", "success")
    elseif action == "bring" and IsValid(target) then
        target:SetPos(ply:GetPos() + ply:GetForward() * 80)
        SendResult(ply, "Brought " .. target:Nick() .. ".", "success")
    elseif action == "heal_target" and IsValid(target) then
        target:SetHealth(100)
        target:SetArmor(100)
        SendResult(ply, "Healed " .. target:Nick() .. ".", "success")
    elseif action == "freeze" and IsValid(target) then
        target:SetMoveType(target:GetMoveType() == MOVETYPE_NONE and MOVETYPE_WALK or MOVETYPE_NONE)
        SendResult(ply, "Toggled freeze for " .. target:Nick() .. ".", "success")
    elseif action == "slay" and IsValid(target) then
        target:Kill()
        SendResult(ply, "Slayed " .. target:Nick() .. ".", "warning")
    elseif action == "spectate" and IsValid(target) then
        if ply == target then
            SendResult(ply, "You cannot spectate yourself.", "warning")
            return
        end

        ply:Spectate(OBS_MODE_IN_EYE)
        ply:SpectateEntity(target)
        SendResult(ply, "Spectating " .. target:Nick() .. ". Use noclip/spawn to return.", "success")
    else
        SendResult(ply, "Unknown admin action.", "error")
    end
end)
