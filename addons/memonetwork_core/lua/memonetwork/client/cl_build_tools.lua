-- MemoNetwork Alpha 19.2 Build Tools Client
-- Quick per-player cleanup/freeze tools for testing Alpha 19.2.

MemoNetwork = MemoNetwork or {}
MemoNetwork.BuildTools = MemoNetwork.BuildTools or {}

local frame
local selectedSteamID
local selectedName
local selectedCategory = "all"

local categories = {
    {key = "all", name = "All"},
    {key = "props", name = "Props"},
    {key = "vehicles", name = "Vehicles"},
    {key = "wire", name = "Wire"},
    {key = "lights", name = "Lights"},
    {key = "npcs", name = "NPCs"},
    {key = "ragdolls", name = "Ragdolls"},
    {key = "effects", name = "Effects"}
}

local function Theme()
    local t = MemoNetwork.Theme or {}
    return {
        orange = t.Orange or Color(255, 145, 0),
        text = t.Text or Color(245, 245, 245),
        muted = t.Muted or Color(155, 165, 180),
        bg = t.Background or Color(10, 14, 22, 238),
        panel2 = t.PanelLight or Color(20, 28, 38, 238),
        success = t.Success or Color(90, 220, 120),
        danger = Color(255, 90, 90),
        warning = Color(255, 190, 80)
    }
end

local function Notify(message, kind)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", "Build Tools", 3)
    else
        chat.AddText(Color(255,145,0), "[Build Tools] ", color_white, tostring(message or ""))
    end
end

net.Receive("MemoNetwork_BuildActionResult", function()
    Notify(net.ReadString(), net.ReadString())
end)

local function OwnerInfo(ent)
    if not IsValid(ent) then return nil end
    local owner = ent:GetNWEntity("MemoNetworkOwner")
    if IsValid(owner) and owner:IsPlayer() then return owner:Nick(), owner:SteamID() end
    local name = ent:GetNWString("MemoNetworkOwnerName", "")
    local sid = ent:GetNWString("MemoNetworkOwnerSteamID", "")
    if sid ~= "" then return name ~= "" and name or sid, sid end
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

local function ScanOwners()
    local owners = {}
    for _, ent in ipairs(ents.GetAll()) do
        local typ = EntityType(ent)
        if typ ~= "unknown" then
            local name, sid = OwnerInfo(ent)
            if sid and sid ~= "" then
                owners[sid] = owners[sid] or {name = name, steamID = sid, count = 0, counts = {}}
                owners[sid].name = name or owners[sid].name
                owners[sid].count = owners[sid].count + 1
                owners[sid].counts[typ] = (owners[sid].counts[typ] or 0) + 1
            end
        end
    end

    local list = {}
    for _, data in pairs(owners) do list[#list + 1] = data end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end

local function SendBuildAction(action)
    if not selectedSteamID then Notify("Select a builder first.", "error") return end
    net.Start("MemoNetwork_BuildAction")
        net.WriteString(action)
        net.WriteString(selectedSteamID)
        net.WriteString(selectedCategory or "all")
    net.SendToServer()
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

local function Button(parent, x, y, w, h, title, fn, danger)
    local th = Theme()
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(w, h)
    b:SetText("")
    b.HoverAmount = 0
    b.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(10, 0, 0, pw, ph, Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 238))
        draw.RoundedBox(8, 0, ph - 5, pw, 5, danger and th.danger or th.orange)
        draw.SimpleText(title, "MN_Text", pw / 2, ph / 2, th.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if fn then fn() end
    end
    return b
end

local function Build(parent)
    parent:Clear()
    local th = Theme()
    local owners = ScanOwners()
    if not selectedSteamID and owners[1] then selectedSteamID = owners[1].steamID selectedName = owners[1].name end

    Box(parent, 0, 0, 760, 70, th.orange, function(_, w, h)
        draw.SimpleText("Build Tools", "MN_Title", 20, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 19.2 cleanup and freeze tools", "MN_Text", 20, 52, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local list = Box(parent, 0, 88, 330, 430, nil, function(_, w, h)
        draw.SimpleText("Builders", "MN_Subtitle", 16, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#owners .. " detected owners", "MN_Small", 16, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local scroll = vgui.Create("DScrollPanel", list)
    scroll:SetPos(14, 72)
    scroll:SetSize(302, 342)

    local y = 0
    for _, owner in ipairs(owners) do
        local row = vgui.Create("DButton", scroll)
        row:SetPos(0, y)
        row:SetSize(284, 60)
        row:SetText("")
        row.HoverAmount = 0
        row.Paint = function(self, w, h)
            self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
            local selected = selectedSteamID == owner.steamID
            draw.RoundedBox(10, 0, 0, w, h, selected and Color(34,45,55,245) or Color(18 + self.HoverAmount * 8, 24 + self.HoverAmount * 8, 32 + self.HoverAmount * 8, 238))
            draw.RoundedBox(6, 0, 0, selected and 8 or 5, h, th.orange)
            draw.SimpleText(owner.name or owner.steamID, "MN_Text", 16, 18, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(owner.steamID, "MN_Small", 16, 40, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(owner.count .. " ent", "MN_Subtitle", w - 14, 24, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            selectedSteamID = owner.steamID
            selectedName = owner.name
            Build(parent)
        end
        y = y + 68
    end

    local detail = Box(parent, 350, 88, 410, 430, selectedSteamID and th.orange or th.warning, function(_, w, h)
        draw.SimpleText("Selected Build", "MN_Subtitle", 18, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selectedName or "No builder selected", "MN_Title", 18, 72, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selectedSteamID or "-", "MN_Text", 18, 108, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Category: " .. selectedCategory, "MN_Subtitle", 18, 150, th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local cx, cy = 18, 184
    for i, cat in ipairs(categories) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        Button(detail, cx + col * 94, cy + row * 42, 84, 34, cat.name, function()
            selectedCategory = cat.key
            Build(parent)
        end, selectedCategory == cat.key)
    end

    Button(detail, 18, 292, 120, 46, "Cleanup", function()
        Derma_Query("Remove " .. selectedCategory .. " entities for " .. tostring(selectedName or selectedSteamID) .. "?", "Build Cleanup", "Cleanup", function() SendBuildAction("cleanup") end, "Cancel")
    end, true)
    Button(detail, 148, 292, 120, 46, "Freeze", function() SendBuildAction("freeze") end)
    Button(detail, 278, 292, 114, 46, "Unfreeze", function() SendBuildAction("unfreeze") end)
    Button(detail, 18, 352, 374, 42, "Refresh", function() Build(parent) end)
end

function MemoNetwork.BuildTools.Open()
    if IsValid(frame) then frame:Remove() frame = nil return end
    local th = Theme()
    frame = vgui.Create("DFrame")
    frame:SetSize(820, 660)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(14, 0, 0, w, h, th.bg)
        draw.RoundedBoxEx(14, 0, 0, w, 78, th.orange, true, true, false, false)
        draw.SimpleText("MemoNetwork Build Tools", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 19.2", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(764, 20)
    close:SetSize(36, 36)
    close:SetText("X")
    close.DoClick = function() frame:Remove() frame = nil end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(30, 100)
    content:SetSize(760, 530)
    content.Paint = function() end
    Build(content)
end

concommand.Add("mn_buildtools", MemoNetwork.BuildTools.Open)

hook.Add("PlayerButtonDown", "MemoNetwork_BuildTools_F11", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F11 then MemoNetwork.BuildTools.Open() end
end)
