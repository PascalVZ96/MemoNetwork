-- MemoNetwork Alpha 19 Ownership Registry
-- Registers prop/entity ownership so Build Assistant and Build Manager can reliably show owners.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Ownership = MemoNetwork.Ownership or {}

local ownerKeys = {
    "MemoNetworkOwnerName",
    "MemoNetworkOwnerSteamID",
    "MemoNetworkOwner64",
    "MemoNetworkSpawnedAt"
}

local function IsBuildEntity(ent)
    if not IsValid(ent) then return false end
    local class = ent:GetClass() or ""

    if class == "prop_physics" or class == "prop_physics_multiplayer" then return true end
    if class == "prop_ragdoll" then return true end
    if string.StartWith(class, "prop_vehicle") or string.StartWith(class, "gmod_sent_vehicle") then return true end
    if string.StartWith(class, "gmod_wire") or string.find(class, "wire", 1, true) then return true end
    if class == "gmod_lamp" or class == "gmod_light" or class == "gmod_button" or class == "gmod_camera" then return true end
    if ent:IsNPC() then return true end

    return false
end

function MemoNetwork.Ownership.Set(ent, ply)
    if not IsValid(ent) or not IsValid(ply) or not ply:IsPlayer() then return end

    ent.MemoNetworkOwner = ply
    ent.MemoNetworkOwnerName = ply:Nick()
    ent.MemoNetworkOwnerSteamID = ply:SteamID()
    ent.MemoNetworkOwner64 = ply:SteamID64() or ""
    ent.MemoNetworkSpawnedAt = CurTime()

    ent:SetNWEntity("MemoNetworkOwner", ply)
    ent:SetNWString("MemoNetworkOwnerName", ply:Nick())
    ent:SetNWString("MemoNetworkOwnerSteamID", ply:SteamID())
    ent:SetNWString("MemoNetworkOwner64", ply:SteamID64() or "")
    ent:SetNWFloat("MemoNetworkSpawnedAt", CurTime())

    -- CPPI-compatible prop protection addons often listen to this style of owner data.
    if ent.CPPISetOwner then
        pcall(ent.CPPISetOwner, ent, ply)
    end
end

function MemoNetwork.Ownership.Get(ent)
    if not IsValid(ent) then return nil end

    if IsValid(ent.MemoNetworkOwner) then return ent.MemoNetworkOwner end

    local nw = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(nw) and nw:IsPlayer() then return nw end

    if ent.CPPIGetOwner then
        local ok, owner = pcall(ent.CPPIGetOwner, ent)
        if ok and IsValid(owner) and owner:IsPlayer() then return owner end
    end

    if ent.GetCreator then
        local ok, creator = pcall(ent.GetCreator, ent)
        if ok and IsValid(creator) and creator:IsPlayer() then return creator end
    end
end

local function MarkNextEntity(ply, ent)
    timer.Simple(0, function()
        if IsValid(ent) and IsValid(ply) then MemoNetwork.Ownership.Set(ent, ply) end
    end)
end

hook.Add("PlayerSpawnedProp", "MemoNetwork_Ownership_Prop", function(ply, model, ent)
    MarkNextEntity(ply, ent)
end)

hook.Add("PlayerSpawnedSENT", "MemoNetwork_Ownership_SENT", function(ply, ent)
    MarkNextEntity(ply, ent)
end)

hook.Add("PlayerSpawnedVehicle", "MemoNetwork_Ownership_Vehicle", function(ply, ent)
    MarkNextEntity(ply, ent)
end)

hook.Add("PlayerSpawnedNPC", "MemoNetwork_Ownership_NPC", function(ply, ent)
    MarkNextEntity(ply, ent)
end)

hook.Add("PlayerSpawnedRagdoll", "MemoNetwork_Ownership_Ragdoll", function(ply, model, ent)
    MarkNextEntity(ply, ent)
end)

hook.Add("PlayerSpawnedEffect", "MemoNetwork_Ownership_Effect", function(ply, model, ent)
    MarkNextEntity(ply, ent)
end)

hook.Add("PlayerSpawnedSWEP", "MemoNetwork_Ownership_SWEP", function(ply, ent)
    MarkNextEntity(ply, ent)
end)

hook.Add("PlayerSpawnedScriptedEntity", "MemoNetwork_Ownership_Scripted", function(ply, ent)
    MarkNextEntity(ply, ent)
end)

-- Fallback for tools/duplicators that set creator but do not run PlayerSpawned* hooks cleanly.
hook.Add("OnEntityCreated", "MemoNetwork_Ownership_Fallback", function(ent)
    timer.Simple(0.15, function()
        if not IsValid(ent) or not IsBuildEntity(ent) then return end
        if ent:GetNWString("MemoNetworkOwnerSteamID", "") ~= "" then return end

        if ent.GetCreator then
            local ok, creator = pcall(ent.GetCreator, ent)
            if ok and IsValid(creator) and creator:IsPlayer() then
                MemoNetwork.Ownership.Set(ent, creator)
            end
        end
    end)
end)

concommand.Add("mn_owner_debug", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local total = 0
    local owned = 0
    for _, ent in ipairs(ents.GetAll()) do
        if IsBuildEntity(ent) then
            total = total + 1
            if ent:GetNWString("MemoNetworkOwnerSteamID", "") ~= "" then owned = owned + 1 end
        end
    end
    print("[MemoNetwork] Ownership: " .. owned .. " / " .. total .. " build entities registered")
end)
