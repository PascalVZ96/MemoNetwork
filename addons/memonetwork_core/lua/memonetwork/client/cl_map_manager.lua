-- MemoNetwork Alpha 17.0 Map Manager
-- Standalone map browser with search and safe changelevel action.

MemoNetwork = MemoNetwork or {}
MemoNetwork.MapManager = MemoNetwork.MapManager or {}

local frame
local selectedMap
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
        warning = Color(255, 190, 80)
    }
end

local function CanOpen()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, "admin.open") or MemoNetwork.Ranks.HasPermission(ply, "map.change")
    end
    return ply:IsAdmin()
end

local function Notify(message, kind)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", "Map Manager", 3)
    else
        chat.AddText(Color(255,145,0), "[Map Manager] ", color_white, tostring(message or ""))
    end
end

local function SendChangeMap(mapName)
    if not mapName or mapName == "" then return end
    net.Start("MemoNetwork_AdminAction")
        net.WriteString("change_map")
        net.WriteString(mapName)
    net.SendToServer()
end

local function KnownMaps()
    local maps = {}
    for _, data in ipairs((MemoNetwork.Config and MemoNetwork.Config.Maps) or {}) do
        maps[#maps + 1] = {
            name = data.name or data.map or "Unknown",
            map = data.map or "",
            description = data.description or "Sandbox map"
        }
    end

    if #maps == 0 then
        maps[#maps + 1] = {name = "Construct", map = "gm_construct", description = "Default Sandbox build map"}
        maps[#maps + 1] = {name = "Flatgrass", map = "gm_flatgrass", description = "Simple open build map"}
    end

    table.sort(maps, function(a, b)
        if a.map == game.GetMap() then return true end
        if b.map == game.GetMap() then return false end
        return string.lower(a.name) < string.lower(b.name)
    end)

    return maps
end

local function Matches(mapData)
    local q = string.Trim(string.lower(searchText or ""))
    if q == "" then return true end
    return string.find(string.lower(mapData.name or ""), q, 1, true)
        or string.find(string.lower(mapData.map or ""), q, 1, true)
        or string.find(string.lower(mapData.description or ""), q, 1, true)
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
        draw.SimpleText(tostring(title or "Button"), "MN_Text", 14, subtitle and subtitle ~= "" and 17 or ph / 2, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then draw.SimpleText(tostring(subtitle), "MN_Small", 14, 38, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if fn then fn() end
    end
    return b
end

local function ConfirmMapChange(mapData)
    if not mapData or not mapData.map or mapData.map == "" then return end
    if mapData.map == game.GetMap() then
        Notify("This map is already active.", "warning")
        return
    end

    Derma_Query(
        "Change server map to " .. mapData.map .. "?\n\nPlayers will reconnect/load the new map.",
        "Change Map",
        "Change Map",
        function() SendChangeMap(mapData.map) end,
        "Cancel"
    )
end

local function Build(parent)
    parent:Clear()
    local th = Theme()
    local maps = KnownMaps()
    local visible = {}
    for _, data in ipairs(maps) do
        if Matches(data) then visible[#visible + 1] = data end
    end
    if not selectedMap or not selectedMap.map then selectedMap = visible[1] or maps[1] end

    Box(parent, 0, 0, 876, 72, th.orange, function(_, w, h)
        draw.SimpleText("Map Manager", "MN_Title", 20, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Search, inspect and change server maps", "MN_Text", 20, 52, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Current: " .. game.GetMap(), "MN_Text", w - 20, 36, th.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    local searchPanel = Box(parent, 0, 88, 876, 58, nil, function(_, w, h)
        draw.SimpleText("Search", "MN_Text", 18, h / 2, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    local search = vgui.Create("DTextEntry", searchPanel)
    search:SetPos(90, 12)
    search:SetSize(520, 34)
    search:SetFont("MN_Text")
    search:SetText(searchText)
    search:SetPlaceholderText("gm_construct, city, flatgrass...")
    search:SetUpdateOnType(true)
    search.OnValueChange = function(_, value)
        searchText = value or ""
        timer.Create("MemoNetwork_MapManager_Search", 0.15, 1, function()
            if IsValid(parent) then Build(parent) end
        end)
    end
    Button(searchPanel, 630, 12, 110, 34, "Clear", "", function()
        searchText = ""
        Build(parent)
    end)
    Button(searchPanel, 752, 12, 106, 34, "Refresh", "", function() Build(parent) end)

    local list = Box(parent, 0, 162, 420, 500, nil, function(_, w, h)
        draw.SimpleText("Available Maps", "MN_Subtitle", 18, 24, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#visible .. " shown / " .. #maps .. " configured", "MN_Small", 18, 50, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local scroll = vgui.Create("DScrollPanel", list)
    scroll:SetPos(14, 72)
    scroll:SetSize(392, 412)

    local y = 0
    for _, data in ipairs(visible) do
        local isCurrent = data.map == game.GetMap()
        local row = vgui.Create("DButton", scroll)
        row:SetPos(0, y)
        row:SetSize(374, 62)
        row:SetText("")
        row:SetCursor("hand")
        row.HoverAmount = 0
        row.Paint = function(self, w, h)
            self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
            local selected = selectedMap and selectedMap.map == data.map
            draw.RoundedBox(10, 0, 0, w, h, selected and Color(34,45,55,245) or Color(18 + self.HoverAmount * 8, 24 + self.HoverAmount * 8, 32 + self.HoverAmount * 8, 238))
            draw.RoundedBox(6, 0, 0, isCurrent and 8 or 5, h, isCurrent and th.success or th.orange)
            draw.SimpleText(data.name or data.map, "MN_Text", 18, 20, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(data.map .. " - " .. (data.description or ""), "MN_Small", 18, 43, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if isCurrent then draw.SimpleText("CURRENT", "MN_Small", w - 16, 20, th.success, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
        end
        row.DoClick = function()
            selectedMap = data
            Build(parent)
        end
        y = y + 70
    end

    local detail = Box(parent, 440, 162, 436, 500, selectedMap and (selectedMap.map == game.GetMap() and th.success or th.orange) or th.orange, function(_, w, h)
        draw.SimpleText("Map Details", "MN_Subtitle", 20, 28, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if not selectedMap then
            draw.SimpleText("No map selected", "MN_Text", 20, 70, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return
        end
        local isCurrent = selectedMap.map == game.GetMap()
        draw.SimpleText(selectedMap.name or selectedMap.map, "MN_Title", 20, 82, th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selectedMap.map or "", "MN_Subtitle", 20, 124, isCurrent and th.success or th.orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(selectedMap.description or "Sandbox map", "MN_Text", 20, 168, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(isCurrent and "This is the active map." or "Ready to change map.", "MN_Text", 20, 210, isCurrent and th.success or th.warning, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Tip: add more maps in MemoNetwork.Config.Maps.", "MN_Small", 20, h - 28, th.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    Button(detail, 20, 250, 180, 52, "Change Map", selectedMap and selectedMap.map or "", function() ConfirmMapChange(selectedMap) end, selectedMap and selectedMap.map ~= game.GetMap())
    Button(detail, 216, 250, 180, 52, "Restart Current", game.GetMap(), function()
        Derma_Query("Restart current map " .. game.GetMap() .. "?", "Restart Map", "Restart", function()
            net.Start("MemoNetwork_AdminAction")
                net.WriteString("restart_map")
            net.SendToServer()
        end, "Cancel")
    end, true)
    Button(detail, 20, 320, 180, 52, "Open F8", "Control Center", function()
        if MemoNetwork.ControlCenter and MemoNetwork.ControlCenter.Open then MemoNetwork.ControlCenter.Open() end
    end)
    Button(detail, 216, 320, 180, 52, "Copy Name", selectedMap and selectedMap.map or "", function()
        if selectedMap and selectedMap.map then SetClipboardText(selectedMap.map) Notify("Map name copied.", "success") end
    end)
end

function MemoNetwork.MapManager.Open()
    if not CanOpen() then Notify("Admin only.", "error") return end
    if IsValid(frame) then frame:Remove() frame = nil return end

    local th = Theme()
    local w, h = 940, 760
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
        draw.SimpleText("MemoNetwork Map Manager", "MN_Title", 26, 27, Color(10,10,10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Alpha 17.0", "MN_Text", 26, 55, Color(25,25,25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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

    local content = vgui.Create("DPanel", frame)
    content:SetPos(32, 100)
    content:SetSize(876, h - 124)
    content.Paint = function() end
    Build(content)
end

concommand.Add("mn_maps", MemoNetwork.MapManager.Open)

hook.Add("PlayerButtonDown", "MemoNetwork_MapManager_F9", function(ply, button)
    if ply == LocalPlayer() and button == KEY_F9 then
        MemoNetwork.MapManager.Open()
    end
end)
