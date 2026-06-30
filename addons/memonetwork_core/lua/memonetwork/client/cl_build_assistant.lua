-- MemoNetwork Alpha 19 Build Assistant
-- Lightweight Sandbox helper showing info about the entity you are looking at.

MemoNetwork = MemoNetwork or {}
MemoNetwork.BuildAssistant = MemoNetwork.BuildAssistant or {}

local function IsEnabled()
    if MemoNetwork.Settings and MemoNetwork.Settings.Get then
        local value = MemoNetwork.Settings.Get("build_assistant")
        if value ~= nil then return value end
    end
    return true
end

local function IsAdminAllowed()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, "players.inspect") or MemoNetwork.Ranks.HasPermission(ply, "players.manage")
    end
    return ply:IsAdmin()
end

local function NiceModel(model)
    model = tostring(model or "")
    if model == "" then return "No model" end
    local parts = string.Explode("/", model)
    return parts[#parts] or model
end

local function SafeNWEntity(ent, key)
    if not IsValid(ent) or not ent.GetNWEntity then return nil end
    local ok, value = pcall(ent.GetNWEntity, ent, key)
    if ok and IsValid(value) and value:IsPlayer() then return value end
end

local function SafeNWString(ent, key)
    if not IsValid(ent) or not ent.GetNWString then return "" end
    local ok, value = pcall(ent.GetNWString, ent, key, "")
    if ok then return tostring(value or "") end
    return ""
end

local function EntityOwner(ent)
    if not IsValid(ent) then return "Unknown" end

    -- MemoNetwork server-side ownership registry is the most reliable source.
    local memoOwner = SafeNWEntity(ent, "MemoNetworkOwner")
    if IsValid(memoOwner) then return memoOwner:Nick() end

    local memoOwnerName = SafeNWString(ent, "MemoNetworkOwnerName")
    if memoOwnerName ~= "" then return memoOwnerName end

    -- Prop protection addons.
    if ent.CPPIGetOwner then
        local ok, owner = pcall(ent.CPPIGetOwner, ent)
        if ok and IsValid(owner) and owner:IsPlayer() then return owner:Nick() end
    end

    -- Common legacy/fallback owner NW values.
    local owner = SafeNWEntity(ent, "Owner") or SafeNWEntity(ent, "owner") or SafeNWEntity(ent, "Creator")
    if IsValid(owner) then return owner:Nick() end

    local ownerName = SafeNWString(ent, "OwnerName")
    if ownerName ~= "" then return ownerName end

    if ent.GetCreator then
        local ok, creator = pcall(ent.GetCreator, ent)
        if ok and IsValid(creator) and creator:IsPlayer() then return creator:Nick() end
    end

    if ent.GetOwner then
        local ok, own = pcall(ent.GetOwner, ent)
        if ok and IsValid(own) and own:IsPlayer() then return own:Nick() end
    end

    return "Unknown"
end

local function SpawnAge(ent)
    if not IsValid(ent) or not ent.GetNWFloat then return nil end
    local spawnedAt = ent:GetNWFloat("MemoNetworkSpawnedAt", 0)
    if spawnedAt <= 0 then return nil end
    local age = math.max(0, CurTime() - spawnedAt)
    if age < 60 then return math.floor(age) .. "s ago" end
    return math.floor(age / 60) .. "m ago"
end

local function FrozenState(ent)
    if not IsValid(ent) or not ent.GetPhysicsObject then return "Unknown" end
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return "No physics" end
    return phys:IsMotionEnabled() and "No" or "Yes"
end

local function Mass(ent)
    if not IsValid(ent) or not ent.GetPhysicsObject then return "-" end
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return "-" end
    return math.Round(phys:GetMass()) .. " kg"
end

local function ConstraintCount(ent)
    if not constraint or not constraint.GetTable then return "-" end
    local ok, tbl = pcall(constraint.GetTable, ent)
    if not ok or not istable(tbl) then return "0" end
    return tostring(#tbl)
end

hook.Add("HUDPaint", "MemoNetwork_BuildAssistant", function()
    if not IsEnabled() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 350000 then return end

    local theme = MemoNetwork.Theme or {}
    local sw, sh = ScrW(), ScrH()
    local w, h = 360, IsAdminAllowed() and 234 or 202
    local x, y = sw - w - 28, sh * 0.34
    local class = ent:GetClass() or "unknown"
    local model = NiceModel(ent:GetModel())
    local age = SpawnAge(ent)

    draw.RoundedBox(14, x, y, w, h, Color(10, 14, 22, 225))
    draw.RoundedBoxEx(14, x, y, w, 6, theme.Orange or Color(255, 145, 0), true, true, false, false)

    draw.SimpleText("BUILD ASSISTANT", "MN_Small", x + 18, y + 24, theme.Muted or Color(160, 165, 175), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(model, "MN_Subtitle", x + 18, y + 52, theme.Text or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local lines = {
        {"Class", class},
        {"Owner", EntityOwner(ent)},
        {"Frozen", FrozenState(ent)},
        {"Mass", Mass(ent)},
        {"Constraints", ConstraintCount(ent)}
    }

    if age then
        table.insert(lines, {"Spawned", age})
    end

    local ly = y + 84
    for _, row in ipairs(lines) do
        draw.SimpleText(row[1], "MN_Text", x + 18, ly, theme.Muted or Color(160,165,175), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(row[2], "MN_Text", x + w - 18, ly, theme.Text or color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        ly = ly + 24
    end

    if IsAdminAllowed() then
        draw.SimpleText("Admin: owner tracking ready for Alpha 19 Build Manager", "MN_Small", x + 18, y + h - 20, theme.Orange or Color(255,145,0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end)

concommand.Add("mn_buildassistant_toggle", function()
    if MemoNetwork.Settings and MemoNetwork.Settings.Toggle then
        MemoNetwork.Settings.Toggle("build_assistant")
    end
end)
