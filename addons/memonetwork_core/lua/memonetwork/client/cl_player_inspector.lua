-- MemoNetwork Alpha 10.1 Player Inspector
-- Opens from the scoreboard and prepares future admin player actions.

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

local function SendAdminAction(action, target)
    if not IsValid(target) then return end

    if not IsAdminAllowed() then
        if MemoNetwork.Notify then
            MemoNetwork.Notify("Admin actions are owner/admin only.", "error", "Player Inspector", 3)
        end
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
    if MemoNetwork.UI and MemoNetwork.UI.CreateButton then
        return MemoNetwork.UI.CreateButton(parent, x, y, w, h, title, subtitle, function()
            SendAdminAction(action, target)
        end)
    end

    local theme = MemoNetwork.Theme
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.HoverAmount = 0
    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, ph - 5, pw, 5, theme.Orange)
        draw.SimpleText(title, "MN_Subtitle", 16, 20, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "MN_Text", 16, 45, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        SendAdminAction(action, target)
    end

    return btn
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
    local w, h = 560, 430
    local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(target) or {name = "PLAYER", color = theme.Text}
    local aliveText = target:Alive() and "Alive" or "Dead"
    local aliveColor = target:Alive() and (theme.Success or Color(75, 200, 120)) or Color(255, 90, 90)

    inspector = vgui.Create("DFrame")
    inspector:SetSize(w, h)
    inspector:SetPos((sw - w) / 2, (sh - h) / 2)
    inspector:SetTitle("")
    inspector:SetDraggable(false)
    inspector:ShowCloseButton(false)
    inspector:MakePopup()
    inspector:SetAlpha(0)
    inspector:AlphaTo(255, 0.10, 0)

    inspector.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 74, theme.Orange, true, true, false, false)
        draw.SimpleText("Player Inspector", "MN_Title", 26, 26, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Version or "Alpha 10", "MN_Text", 26, 52, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(inspector, w - 56, 18, function()
            inspector:Remove()
            inspector = nil
        end)
    end

    local avatar = vgui.Create("AvatarImage", inspector)
    avatar:SetSize(84, 84)
    avatar:SetPos(24, 100)
    avatar:SetPlayer(target, 84)

    local card = vgui.Create("DPanel", inspector)
    card:SetPos(124, 100)
    card:SetSize(w - 148, 84)
    card.Paint = function(_, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText(IsValid(target) and target:Nick() or "Unknown", "MN_Title", 18, 25, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rank.name or "PLAYER", "MN_Text", 18, 57, rank.color or theme.Orange, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local details = vgui.Create("DPanel", inspector)
    details:SetPos(24, 204)
    details:SetSize(w - 48, 146)
    details.Paint = function(_, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, theme.PanelLight)
    end

    DetailLine(details, 16, "SteamID", IsValid(target) and target:SteamID() or "Unknown", theme.Text)
    DetailLine(details, 48, "Ping", IsValid(target) and (target:Ping() .. " ms") or "0 ms", MemoNetwork.Player and MemoNetwork.Player.GetPingColor(target:Ping()) or theme.Text)
    DetailLine(details, 80, "Status", aliveText, aliveColor)
    DetailLine(details, 112, "Team", IsValid(target) and team.GetName(target:Team()) or "Unknown", theme.Text)

    if IsAdminAllowed() then
        AdminButton(inspector, 24, 366, 120, 46, "Teleport", "Go to player", "teleport", target)
        AdminButton(inspector, 154, 366, 120, 46, "Bring", "Bring here", "bring", target)
        AdminButton(inspector, 284, 366, 120, 46, "Heal", "HP + armor", "heal_target", target)
        AdminButton(inspector, 414, 366, 120, 46, "Freeze", "Toggle freeze", "freeze", target)
    else
        local info = vgui.Create("DPanel", inspector)
        info:SetPos(24, 366)
        info:SetSize(w - 48, 46)
        info.Paint = function(_, pw, ph)
            draw.RoundedBox(10, 0, 0, pw, ph, theme.Panel)
            draw.SimpleText("Admin actions are hidden for normal players.", "MN_Text", 18, ph / 2, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end
