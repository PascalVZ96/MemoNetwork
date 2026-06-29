-- MemoNetwork Alpha 10 UI Helpers

MemoNetwork = MemoNetwork or {}
MemoNetwork.UI = MemoNetwork.UI or {}

function MemoNetwork.UI.DrawPanel(x, y, w, h, color, radius)
    draw.RoundedBox(radius or 12, x, y, w, h, color or MemoNetwork.Theme.Background)
end

function MemoNetwork.UI.DrawHeader(x, y, w, h, title, subtitle)
    local theme = MemoNetwork.Theme

    draw.RoundedBoxEx(12, x, y, w, h, theme.Orange, true, true, false, false)
    draw.SimpleText(title or "MemoNetwork", "MN_Title", x + 24, y + 23, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if subtitle and subtitle ~= "" then
        draw.SimpleText(subtitle, "MN_Text", x + 24, y + 51, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

function MemoNetwork.UI.DrawButton(self, w, h, title, subtitle, accent)
    local theme = MemoNetwork.Theme

    self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)

    local base = 18 + self.HoverAmount * 10
    local bg = Color(base, base + 6, base + 14, 235)

    draw.RoundedBox(10, 0, 0, w, h, bg)
    draw.RoundedBox(8, 0, 0, 6 + self.HoverAmount * 4, h, accent or theme.Orange)

    draw.SimpleText(title or "Button", "MN_Subtitle", 20, 20, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if subtitle and subtitle ~= "" then
        draw.SimpleText(subtitle, "MN_Text", 20, 43, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

function MemoNetwork.UI.CreateButton(parent, x, y, w, h, title, subtitle, onClick, accent)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.HoverAmount = 0
    btn.Paint = function(self, pw, ph)
        MemoNetwork.UI.DrawButton(self, pw, ph, title, subtitle, accent)
    end
    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if onClick then onClick(btn) end
    end
    return btn
end

function MemoNetwork.UI.CreateCloseButton(parent, x, y, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(38, 38)
    btn:SetText("")
    btn.Paint = function(self, w, h)
        local hover = self:IsHovered()
        local bg = hover and Color(255, 170, 40, 255) or Color(20, 26, 34, 230)
        draw.RoundedBox(8, 0, 0, w, h, bg)
        draw.SimpleText("X", "MN_Title", w / 2, h / 2 - 1, hover and Color(10, 10, 10) or Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = onClick
    return btn
end
