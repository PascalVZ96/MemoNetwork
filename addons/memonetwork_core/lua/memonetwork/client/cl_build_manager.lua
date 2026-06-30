-- MemoNetwork Alpha 19 Build Manager
-- Standalone build/entity overview for Sandbox administration.

MemoNetwork = MemoNetwork or {}
MemoNetwork.BuildManager = MemoNetwork.BuildManager or {}

local frame
local selectedSteamID
local searchText = ""

local function Theme()
    local t = MemoNetwork.Theme or {}
    return {
        orange = t.Orange or Color(255, 145, 0),
        text = t.Text or Color(245, 245, 245),
        muted = t.Muted or Color(155, 165, 180),
        bg = t.Background or Color(10, 14, 22, 238),
        panel = t.Panel or Color(14, 20, 28, 238),
        panel2 = t.PanelLight or Color(20, 28, 38, 238),
        success = t.Success or Color(90, 220, 120),
        danger = Color(255, 90, 90),
        warning = Color(255, 190, 80),
        blue = Color(80, 160, 255),
        purple = Color(180, 120, 255)
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

local function Notify(message, kind)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", "Build Manager", 3)
    else
        chat.AddText(Color(255,145,0), "[Build Manager] ", color_white, tostring(message or ""))
    end
end

local function SendAction(action, payload)
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        if payload then net.WriteString(payload) end
    net.SendToServer()
end

local function SendTargetAction(action, target)
    if not IsValid(target) then Notify("No player selected.", "error") return end
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        net.WriteEntity(target)
    net.SendToServer()
end

local function Confirm(title, text, fn)
    Derma_Query(text, title, "Yes", fn, "No")
end

local function OwnerInfo(ent)
    if not IsValid(ent) then return "Unknown", "unknown", nil end

    local owner = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(owner) and owner:IsPlayer() then
        return owner:Nick(), owner:SteamID(), owner
    end

    local name = ent:GetNWString("MemoNetworkOwnerName", "")
    local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
    if name ~= "" or sid ~= "" then return name ~= "" and name or sid, sid ~= "" and sid or "unknown", nil end

    if ent.CPPIGetOwner then
        local ok, cppiOwner = pcall(ent.CPPIGetOwner, ent)
        if ok and IsValid(cppiOwner) and cppiOwner:IsPlayer() then
            return cppiOwner:Nick(), cppiOwner:SteamID(), cppiOwner
        end
    end

    if ent.GetCreator then
        local ok, creator = pcall(ent.GetCreator, ent)
        if ok and IsValid(creator) and creator:IsPlayer() then
            return creator:Nick(), creator:SteamID(), creator
        end
    end

    return "Unknown", "unknown", nil
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
    return "other"
end

local function IsBuildEntity(ent)
    local t = EntityType(ent)
    return t ~= "unknown" and t ~= "other" or (IsValid(ent) and string.StartWith(ent:GetClass() or "", "gmod_"))
end

local function ModelName(ent)
    local model = IsValid(ent) and ent:GetModel() or ""
    model = tostring(model or "")
    if model == "" then return "no model" end
    local parts = string.Explode("/", model)
    return parts[#parts] or model
end

local function SpawnAge(ent)
    if not IsValid(ent) then return "-" end
    local spawnedAt = ent:GetNWFloat("MemoNetworkSpawnedAt", 0)
    if spawnedAt <= 0 then return "-" end
    local age = math.max(0, CurTime() - spawnedAt)
    if age < 60 then return math.floor(age) .. "s" end
    if age < 3600 then return math.floor(age / 60) .. "m" end
    return math.floor(age / 3600) .. "h"
end

local function ConstraintCount(ent)
    if not constraint or not constraint.GetTable then return 0 end
    local ok, tbl = pcall(constraint.GetTable, ent)
    if not ok or not istable(tbl) then return 0 end
    return #tbl
end

local function ScanBuilds()
    local groups = {}
    local totals = {props=0, vehicles=0, npcs=0, ragdolls=0, effects=0, wire=0, lights=0, other=0, all=0, owned=0, unknown=0}

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() and IsBuildEntity(ent) then
            local ownerName, steamID, ownerPly = OwnerInfo(ent)
            steamID = steamID or "unknown"
            if steamID == "" then steamID = "unknown" end
            if not groups[steamID] then
                groups[steamID] = {
                    steamID = steamID,
                    ownerName = ownerName or "Unknown",
                    owner = ownerPly,
                    entities = {},
                    counts = {props=0, vehicles=0, npcs=0, ragdolls=0, effects=0, wire=0, lights=0, other=0, all=0}
                }
            end

            local g = groups[steamID]
            if ownerName and ownerName ~= "Unknown" then g.ownerName = ownerName end
            if IsValid(ownerPly) then g.owner = ownerPly end

            local typ = EntityType(ent)
            g.entities[#g.entities + 1] = ent
            g.counts[typ] = (g.counts[typ] or 0) + 1
            g.counts.all = g.counts.all + 1
            totals[typ] = (totals[typ] or 0) + 1
            totals.all = totals.all + 1
            if steamID == "unknown" then totals.unknown = totals.unknown + 1 else totals.owned = totals.owned + 1 end
        end
    end

    local list = {}
    for _, group in pairs(groups) do
        list[#list + 1] = group
    end
    table.sort(list, function(a, b)
        if a.steamID == "unknown" then return false end
        if b.steamID == "unknown" then return true end
        return a.counts.all > b.counts.all
    end)
    return list, totals
end

local function MatchesGroup(group)
    local q = string.Trim(string.lower(searchText or ""))
    if q == "" then return true end
    return string.find(string.lower(group.ownerName or ""), q, 1, true)
        or string.find(string.lower(group.steamID or ""), q, 1, true)
end

local function Box(parent, x, y, w, h, accent, paintExtra)
    local th = Theme()
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    p.Paint = function(self, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, th.panel2)
        if accent then draw.RoundedBox(6, 0, 0, 6, ph, accent) end
        if paintExtra then paintExtra(self, pw, ph, th) end
    end
    return p
end

local function Stat(parent, x, y, w, h, title, value, accent)
    local th = Theme()
    return Box(parent, x, y, w, h, accent or th.orange, function(_, pw, ph)
        draw.SimpleText(string.upper(tostring(title or "STAT")), "MN_Small", 14, 17, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value or "0"), "MN_Subtitle", 14, 44, accent or th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
end

local function Button(parent, x, y, w, h, title, subtitle, fn, danger)
    local th = Theme()
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(w, h)
    b:SetText("")
    b:SetCursor("hand")
    b.HoverAmount = 0
    b.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 238)
        local accent = danger and th.danger or th.orange
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, ph - 5, pw, 5, accent)
        draw.SimpleText(tostring(title or "Button"), "MN_Text", 12, subtitle and subtitle ~= "" and 17 or ph / 2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(tostring(subtitle), "MN_Small", 12, 38, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if fn then fn() end
    end
    return b
end

local function SelectedGroup(groups)
    for _, group in ipairs(groups) do
        if group.steamID == selectedSteamID then return group end
    end
    selectedSteamID = groups[1] and groups[1].steamID or nil
    return groups[1]
end

local function Build(parent)
    parent:Clear()
    local th = Theme()
    local groups, totals = ScanBuilds()
    local visible = {}
    for _, group in ipairs(groups) do
        if MatchesGroup(group) then visible[#visible + 1] = group end
    end
    local selected = SelectedGroup(visible)

    Box(parent, 0, 0, 876, 72, th.orange, function(_, w, h)
        draw.SimpleText("Build Manager", "MN_Title", 20, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 19 ownership, build statistics and player cleanup tools", "MN_Text", 20, 52, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Entities: " .. totals.all, "MN_Text", w - 20, 36, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    Stat(parent, 0, 88, 116, 68, "Total", totals.all, th.orange)
    Stat(parent, 126, 88, 116, 68, "Owned", totals.owned, th.success)
    Stat(parent, 252, 88, 116, 68, "Unknown", totals.unknown, totals.unknown > 0 and th.warning or th.success)
    Stat(parent, 378, 88, 116, 68, "Props", totals.props, Color(90,220,120))
    Stat(parent, 504, 88, 116, 68, "Vehicles", totals.vehicles, th.blue)
    Stat(parent, 630, 88, 116, 68, "Wire", totals.wire, Color(80,200,255))
    Stat(parent, 756, 88, 116, 68, "Lights", totals.lights, Color(255,230,120))

    local searchPanel = Box(parent, 0, 172, 876, 56, nil, function(_, w, h)
        draw.SimpleText("Search", "MN_Text", 16, h / 2, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local search = vgui.Create("DTextEntry", searchPanel)
    search:SetPos(86, 11)
    search:SetSize(500, 34)
    search:SetFont("MN_Text")
    search:SetText(searchText)
    search:SetPlaceholderText("Player name or SteamID...")
    search:SetUpdateOnType(true)
    search.OnValueChange = function(_, value)
        searchText = value or ""
        timer.Create("MemoNetwork_BuildManager_Search", 0.15, 1, function()
            if IsValid(parent) then Build(parent) end
        end)
    end
    Button(searchPanel, 606, 11, 120, 34, "Clear", "", function() searchText = "" Build(parent) end)
    Button(searchPanel, 740, 11, 120, 34, "Refresh", "", function() Build(parent) end)

    local playersBox = Box(parent, 0, 244, 360, 430, nil, function(_, w, h)
        draw.SimpleText("Builders", "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#visible .. " shown / " .. #groups .. " owners", "MN_Small", 16, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local scroll = vgui.Create("DScrollPanel", playersBox)
    scroll:SetPos(14, 72)
    scroll:SetSize(332, 342)

    local y = 0
    for _, group in ipairs(visible) do
        local row = vgui.Create("DButton", scroll)
        row:SetPos(0, y)
        row:SetSize(314, 68)
        row:SetText("")
        row:SetCursor("hand")
        row.HoverAmount = 0
        row.Paint = function(self, w, h)
            self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
            local selectedRow = selectedSteamID == group.steamID
            draw.RoundedBox(10, 0, 0, w, h, selectedRow and Color(34,45,55,245) or Color(18 + self.HoverAmount * 8, 24 + self.HoverAmount * 8, 32 + self.HoverAmount * 8, 238))
            draw.RoundedBox(6, 0, 0, selectedRow and 8 or 5, h, group.steamID == "unknown" and th.warning or th.orange)
            draw.SimpleText(group.ownerName or "Unknown", "MN_Text", 18, 20, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(group.steamID or "unknown", "MN_Small", 18, 43, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(group.counts.all .. " ent", "MN_Subtitle", w - 16, 24, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            selectedSteamID = group.steamID
            Build(parent)
        end
        y = y + 76
    end

    local detail = Box(parent, 380, 244, 496, 430, selected and (selected.steamID == "unknown" and th.warning or th.orange) or th.orange, function(_, w, h)
        draw.SimpleText("Build Details", "MN_Subtitle", 20, 26, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if not selected then
            draw.SimpleText("No build owner selected", "MN_Text", 20, 70, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return
        end
        draw.SimpleText(selected.ownerName or "Unknown", "MN_Title", 20, 76, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selected.steamID or "unknown", "MN_Text", 20, 112, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Total entities: " .. selected.counts.all, "MN_Subtitle", 20, 154, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    if selected then
        Stat(detail, 20, 186, 96, 58, "Props", selected.counts.props, Color(90,220,120))
        Stat(detail, 126, 186, 96, 58, "Vehicles", selected.counts.vehicles, th.blue)
        Stat(detail, 232, 186, 96, 58, "Wire", selected.counts.wire, Color(80,200,255))
        Stat(detail, 338, 186, 96, 58, "Lights", selected.counts.lights, Color(255,230,120))
        Stat(detail, 20, 256, 96, 58, "NPCs", selected.counts.npcs, th.danger)
        Stat(detail, 126, 256, 96, 58, "Ragdolls", selected.counts.ragdolls, th.warning)
        Stat(detail, 232, 256, 96, 58, "Effects", selected.counts.effects, th.purple)
        Stat(detail, 338, 256, 96, 58, "Other", selected.counts.other, th.muted)

        Button(detail, 20, 336, 104, 42, "Goto", "Player", function() SendTargetAction("teleport", selected.owner) end)
        Button(detail, 134, 336, 104, 42, "Bring", "Player", function() SendTargetAction("bring", selected.owner) end)
        Button(detail, 248, 336, 104, 42, "Heal", "Player", function() SendTargetAction("heal_target", selected.owner) end)
        Button(detail, 362, 336, 104, 42, "Refresh", "", function() Build(parent) end)
        Button(detail, 20, 386, 218, 34, "Cleanup Player", "Coming next", function() Notify("Per-player cleanup server action comes in the next Alpha 19 step.", "warning") end, true)
        Button(detail, 248, 386, 218, 34, "Freeze/Unfreeze", "Coming next", function() Notify("Freeze tools come in the next Alpha 19 step.", "warning") end)
    end

    local entBox = Box(parent, 0, 692, 876, 150, nil, function(_, w, h)
        draw.SimpleText("Selected Build Entities", "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("First 6 entities for quick inspection", "MN_Small", 16, 48, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    if selected then
        local ex = 16
        for i = 1, math.min(6, #selected.entities) do
            local ent = selected.entities[i]
            Box(entBox, ex, 70, 132, 60, nil, function(_, w, h)
                draw.SimpleText(EntityType(ent), "MN_Small", 10, 15, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(ModelName(ent), "MN_Small", 10, 35, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("age " .. SpawnAge(ent), "MN_Small", 10, 51, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end)
            ex = ex + 142
        end
    end
end

function MemoNetwork.BuildManager.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end

    local th = Theme()
    local w, h = 940, 920
    w = math.min(w, ScrW() - 60)
    h = math.min(h, ScrH() - 60)

    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.12, 0)
    frame.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, th.bg)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, th.orange, true, true, false, false)
        draw.SimpleText("MemoNetwork Build Manager", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 19.0", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(w - 56, 20)
    close:SetSize(36, 36)
    close:SetText("")
    close.Paint = function(self, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, Color(95, 48, 18, self:IsHovered() and 255 or 230))
        draw.SimpleText("X", "MN_Title", pw / 2, ph / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() frame:Remove() frame = nil end

    local content = vgui.Create("DScrollPanel", frame)
    content:SetPos(32, 100)
    content:SetSize(w - 64, h - 124)
    content.Rebuild = function(self) Build(self) end
    Build(content)
end

concommand.Add("mn_builds", MemoNetwork.BuildManager.Open)

hook.Add("PlayerButtonDown", "MemoNetwork_BuildManager_F10", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F10 then
        MemoNetwork.BuildManager.Open()
    end
end)
