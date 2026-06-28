-- MemoNetwork Alpha 15.2 Spectate HUD
-- Shows useful player information while spectating/admin-watching a player.

MemoNetwork = MemoNetwork or {}
MemoNetwork.SpectateHUD = MemoNetwork.SpectateHUD or {}

local function IsEnabled()
    if MemoNetwork.Settings and MemoNetwork.Settings.Get then
        local value = MemoNetwork.Settings.Get("spectate_hud")
        if value ~= nil then return value end
    end
    return true
end

local function WatchedPlayer()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local target = ply:GetObserverTarget()
    if IsValid(target) and target:IsPlayer() then return target end

    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) and tr.Entity:IsPlayer() then return tr.Entity end
end

local function CurrentWeaponName(ply)
    if not IsValid(ply) then return "-" end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return "None" end
    if wep.GetPrintName then
        local ok, name = pcall(wep.GetPrintName, wep)
        if ok and name and name ~= "" then return name end
    end
    return wep:GetClass() or "Unknown"
end

local function VehicleName(ply)
    if not IsValid(ply) or not ply:InVehicle() then return "No" end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then return "Yes" end
    return veh:GetClass() or "Vehicle"
end

hook.Add("HUDPaint", "MemoNetwork_SpectateHUD", function()
    if not IsEnabled() then return end

    local target = WatchedPlayer()
    if not IsValid(target) then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if target == lp and lp:GetObserverMode() == OBS_MODE_NONE then return end

    local theme = MemoNetwork.Theme or {}
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(target) or {name = "PLAYER", color = Color(255,145,0)}
    local sw, sh = ScrW(), ScrH()
    local w, h = 420, 194
    local x, y = (sw - w) / 2, sh - h - 36
    local speed = math.Round(target:GetVelocity():Length())

    draw.RoundedBox(16, x, y, w, h, Color(10, 14, 22, 225))
    draw.RoundedBoxEx(16, x, y, w, 7, rank.color or theme.Orange or Color(255,145,0), true, true, false, false)

    draw.SimpleText("SPECTATE HUD", "MN_Small", x + 20, y + 24, theme.Muted or Color(155,165,180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(target:Nick(), "MN_Title", x + 20, y + 58, theme.Text or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(rank.name or "PLAYER", "MN_Subtitle", x + w - 20, y + 58, rank.color or Color(255,145,0), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local lines = {
        {"Health", target:Health() .. " HP"},
        {"Armor", target:Armor()},
        {"Ping", target:Ping() .. " ms"},
        {"Weapon", CurrentWeaponName(target)},
        {"Speed", speed},
        {"Vehicle", VehicleName(target)}
    }

    local lx = x + 20
    local rx = x + w - 20
    local ly = y + 94
    for i, row in ipairs(lines) do
        local col = (i - 1) % 2
        local line = math.floor((i - 1) / 2)
        local px = col == 0 and lx or x + 225
        local vx = col == 0 and x + 190 or rx
        local py = ly + line * 26
        draw.SimpleText(row[1], "MN_Text", px, py, theme.Muted or Color(155,165,180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(row[2]), "MN_Text", vx, py, theme.Text or color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end)

concommand.Add("mn_spectatehud_toggle", function()
    if MemoNetwork.Settings and MemoNetwork.Settings.Toggle then
        MemoNetwork.Settings.Toggle("spectate_hud")
    end
end)
