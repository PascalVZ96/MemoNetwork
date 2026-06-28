-- MemoNetwork Alpha 10.3 Player Inspector
-- Cleaner Sandbox layout: removed unused Team row and added Steam helpers.

MemoNetwork = MemoNetwork or {}
MemoNetwork.PlayerInspector = MemoNetwork.PlayerInspector or {}

local inspector

local function IsAdminAllowed()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    if MemoNetwork.Ranks and MemoNetwork.Ranks.CanAdmin then
        return MemoNetwork.Ranks.CanAdmin(ply)
    end

    return ply:IsAdmin()
end

local function Notify(message, kind, title)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", title or "Player Inspector", 3)
    end
end

local function SendAdminAction(action, target)
    if not IsValid(target) then return end

    if not IsAdminAllowed() then
        Notify("Admin actions are owner/admin only.", "error")
        return
    end

    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
        net.WriteEntity(target)
    net.SendToServer()
end

local function DetailLine(parent, y, label, value, valueColor)
    local theme = MemoNetwork.Theme

    local row = vgui.Create("DPanel", parent)
    row:SetPos(24, y)
    row:SetSize(parent:GetWide() - 48, 30)
    row.Paint = function(_, w, h)
        draw.SimpleText(label, "MN_Text", 0, h / 2, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "MN_Text", w, h / 2, valueColor or theme.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    return row
end

local function AdminButton(parent, x, y, w, h, title, subtitle, action, target)
    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn:SetCursor("hand")
    btn.HoverAmount = 0

    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
        local barH = 4 + self.HoverAmount * 2

        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBoxEx(8, 0, ph - barH, pw, barH, theme.Orange, false, false, true, true)
        draw.SimpleText(title, "MN_Subtitle", 14, 19, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "MN_Small", 14, 43, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        SendAdminAction(action, target)
    end

    return btn
end

local function SmallButton(parent, x, y, w, h, title, onClick)
    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn:SetCursor("hand")
    btn.HoverAmount = 0

    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(20 + self.HoverAmount * 10, 26 + self.HoverAmount * 10, 34 + self.HoverAmount * 10, 235)
        draw.RoundedBox(8, 0, 0, pw, ph, bg)
        draw.SimpleText(title, "MN_Text", pw / 2, ph / 2, theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if onClick then onClick() end
    end

    return btn
end

local function AddAdminActions(parent, y, target)
    local actions = {
        {"Teleport", "Go to player", "teleport"},
        {"Bring", "Bring here", "bring"},
        {"Heal", "HP + armor", "heal_target"},
        {"Freeze", "Toggle freeze", "freeze"},
        {"Slay", "Kill player", "slay"},
        {"Spectate", "Watch player", "spectate"}
    }

    local margin = 24
    local gap = 10
    local cols = 3
    local btnW = math.floor((parent:GetWide() - (margin * 2) - (gap * (cols - 1))) / cols)
    local btnH = 58

    for i, data in ipairs(actions) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = margin + col * (btnW + gap)
        local by = y + row * (btnH + gap)

        AdminButton(parent, x, by, btnW, btnH, data[1], data[2], data[3], target)
    end
end

function MemoNetwork.PlayerInspector.Open(target)
    if not IsValid(target) or not target:IsPlayer() then return end

    if IsValid(inspector) then
        inspector:Remove()
        inspector = nil
    end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config or {}
    local sw, sh = ScrW(), ScrH()
    local w, h = 620, 505
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(target) or {name = "PLAYER", color = theme.Text}
    local aliveText = target:Alive() and "Alive" or "Dead"
    local aliveColor = target:Alive() and (theme.Success or Color(75, 200, 120)) or Color(255, 90, 90)
    local steamid = IsValid(target) and target:SteamID() or "Unknown"

    inspector = vgui.Create("DFrame")
    inspector:SetSize(w, h)
    inspector:SetPos((sw - w) / 2, (sh - h) / 2)
    inspector:SetTitle("")
    inspector:SetDraggable(false)
    inspector:ShowCloseButton(false)
    inspector:MakePopup()
    inspector:SetAlpha(0)
    inspector:AlphaTo(255, 0.12, 0)

    inspector.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, theme.Orange, true, true, false, false)
        draw.SimpleText("Player Inspector", "MN_Title", 26, 27, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Version or "Alpha 10", "MN_Text", 26, 55, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(inspector, w - 56, 20, function()
            inspector:Remove()
            inspector = nil
        end)
    end

    local avatar = vgui.Create("AvatarImage", inspector)
    avatar:SetSize(96, 96)
    avatar:SetPos(24, 102)
    avatar:SetPlayer(target, 96)

    local card = vgui.Create("DPanel", inspector)
    card:SetPos(136, 102)
    card:SetSize(w - 160, 96)
    card.Paint = function(_, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText(IsValid(target) and target:Nick() or "Unknown", "MN_Title", 18, 30, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Text", 18, 66, rank.color or theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(steamid, "MN_Small", pw - 18, 66, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    SmallButton(card, card:GetWide() - 224, 16, 98, 30, "Copy ID", function()
        SetClipboardText(steamid)
        Notify("SteamID copied.", "success")
    end)

    SmallButton(card, card:GetWide() - 116, 16, 98, 30, "Steam", function()
        if IsValid(target) then
            gui.OpenURL("https://steamcommunity.com/profiles/" .. target:SteamID64())
            Notify("Steam profile opened.", "success")
        end
    end)

    local details = vgui.Create("DPanel", inspector)
    details:SetPos(24, 218)
    details:SetSize(w - 48, 114)
    details.Paint = function(_, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, theme.PanelLight)
    end

    local ping = IsValid(target) and target:Ping() or 0
    DetailLine(details, 16, "SteamID", steamid, theme.Text)
    DetailLine(details, 48, "Ping", ping .. " ms", MemoNetwork.Player and MemoNetwork.Player.GetPingColor(ping) or theme.Text)
    DetailLine(details, 80, "Status", aliveText, aliveColor)

    if IsAdminAllowed() then
        AddAdminActions(inspector, 352, target)
    else
        local info = vgui.Create("DPanel", inspector)
        info:SetPos(24, 352)
        info:SetSize(w - 48, 58)
        info.Paint = function(_, pw, ph)
            draw.RoundedBox(10, 0, 0, pw, ph, theme.Panel)
            draw.SimpleText("Admin actions are hidden for normal players.", "MN_Text", 18, ph / 2, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end
