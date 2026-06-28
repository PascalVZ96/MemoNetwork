-- MemoNetwork Lite Admin Panel
-- Opens with F6 or mn_admin for owners/admins.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Admin = MemoNetwork.Admin or {}

local panel

local function IsAllowed()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    if MemoNetwork.Ranks and MemoNetwork.Ranks.IsOwner and MemoNetwork.Ranks.IsOwner(ply) then
        return true
    end

    return ply:IsAdmin()
end

local function SendAction(action)
    net.Start("MemoNetwork_AdminAction")
        net.WriteString(action)
    net.SendToServer()
end

net.Receive("MemoNetwork_AdminResult", function()
    local message = net.ReadString()
    local kind = net.ReadString()

    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind, "Admin", 3)
    else
        chat.AddText(Color(255, 145, 0), "[MemoNetwork Admin] ", color_white, message)
    end
end)

local function ActionButton(parent, x, y, w, h, title, subtitle, action)
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
        draw.SimpleText(title, "MN_Subtitle", 16, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "MN_Text", 16, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        SendAction(action)
    end
end

function MemoNetwork.Admin.Open()
    if not IsAllowed() then
        if MemoNetwork.Notify then
            MemoNetwork.Notify("Admin panel is owner/admin only.", "error", "Admin", 3)
        end
        return
    end

    if IsValid(panel) then
        panel:Remove()
        panel = nil
        return
    end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config
    local sw, sh = ScrW(), ScrH()

    local w, h = 620, 390

    panel = vgui.Create("DFrame")
    panel:SetSize(w, h)
    panel:SetPos((sw - w) / 2, (sh - h) / 2)
    panel:SetTitle("")
    panel:SetDraggable(false)
    panel:ShowCloseButton(false)
    panel:MakePopup()
    panel:SetAlpha(0)
    panel:AlphaTo(255, 0.10, 0)

    panel.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 72, theme.Orange, true, true, false, false)

        draw.SimpleText("MemoNetwork Admin", "MN_Title", 26, 26, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Version or "Alpha", "MN_Text", 26, 52, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", panel)
    close:SetSize(38, 38)
    close:SetPos(w - 56, 17)
    close:SetText("")
    close.Paint = function(btn, bw, bh)
        local hover = btn:IsHovered()
        local bg = hover and Color(255, 170, 40, 255) or Color(20, 26, 34, 230)

        draw.RoundedBox(8, 0, 0, bw, bh, bg)
        draw.SimpleText("X", "MN_Title", bw / 2, bh / 2 - 1, hover and Color(10, 10, 10) or Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function()
        panel:Remove()
        panel = nil
    end

    ActionButton(panel, 24, 96, 176, 76, "Cleanup", "Clean unused map props", "cleanup")
    ActionButton(panel, 222, 96, 176, 76, "God Mode", "Toggle god mode", "god")
    ActionButton(panel, 420, 96, 176, 76, "Noclip", "Toggle noclip", "noclip")
    ActionButton(panel, 24, 194, 176, 76, "Heal", "100 HP + 100 armor", "health")

    local info = vgui.Create("DPanel", panel)
    info:SetPos(222, 194)
    info:SetSize(374, 146)
    info.Paint = function(_, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, theme.PanelLight)
        draw.SimpleText("Private Server Tools", "MN_Subtitle", 18, 28, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Small admin panel for quick testing.", "MN_Text", 18, 62, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Open with F6 or command mn_admin.", "MN_Text", 18, 92, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

concommand.Add("mn_admin", function()
    MemoNetwork.Admin.Open()
end)

hook.Add("PlayerButtonDown", "MemoNetwork_Admin_F6", function(ply, button)
    if ply ~= LocalPlayer() then return end

    if button == KEY_F6 then
        MemoNetwork.Admin.Open()
    end
end)
