-- MemoNetwork Alpha 16 Widget Framework
-- Shared client-side UI helpers for F1/F6/MOTD style panels.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Widgets = MemoNetwork.Widgets or {}

local function Theme()
    return MemoNetwork.Theme or {
        Orange = Color(255, 145, 0),
        Text = Color(245, 245, 245),
        Muted = Color(155, 165, 180),
        Panel = Color(14, 20, 28, 235),
        PanelLight = Color(20, 28, 38, 235),
        Success = Color(90, 220, 120)
    }
end

function MemoNetwork.Widgets.Panel(parent, x, y, w, h, paintExtra)
    local theme = Theme()
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(w, h)
    panel.Paint = function(self, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.PanelLight)
        if paintExtra then paintExtra(self, pw, ph, theme) end
    end
    return panel
end

function MemoNetwork.Widgets.StatCard(parent, x, y, w, h, title, value, subtitle, accent)
    local theme = Theme()
    return MemoNetwork.Widgets.Panel(parent, x, y, w, h, function(_, pw, ph)
        draw.RoundedBox(6, 0, 0, 6, ph, accent or theme.Orange)
        draw.SimpleText(string.upper(tostring(title or "STAT")), "MN_Small", 16, 18, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value or "-"), "MN_Subtitle", 16, 47, accent or theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(tostring(subtitle), "MN_Small", 16, 68, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end)
end

function MemoNetwork.Widgets.ActionButton(parent, x, y, w, h, title, subtitle, onClick, opts)
    local theme = Theme()
    opts = opts or {}
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn:SetCursor("hand")
    btn.HoverAmount = 0
    btn.Paint = function(self, pw, ph)
        self.HoverAmount = Lerp(FrameTime() * 10, self.HoverAmount or 0, self:IsHovered() and 1 or 0)
        local bg = Color(18 + self.HoverAmount * 10, 24 + self.HoverAmount * 10, 32 + self.HoverAmount * 10, 235)
        local accent = opts.danger and Color(255, 90, 90) or (opts.accent or theme.Orange)
        draw.RoundedBox(10, 0, 0, pw, ph, bg)
        draw.RoundedBox(8, 0, ph - 5, pw, 5, accent)
        draw.SimpleText(tostring(title or "Button"), "MN_Subtitle", 16, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(tostring(subtitle), "MN_Text", 16, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if onClick then onClick(btn) end
    end
    return btn
end

function MemoNetwork.Widgets.StatusPill(parent, x, y, w, h, text, active)
    local theme = Theme()
    local pill = vgui.Create("DPanel", parent)
    pill:SetPos(x, y)
    pill:SetSize(w, h)
    pill.Paint = function(_, pw, ph)
        local c = active and (theme.Success or Color(90, 220, 120)) or Color(255, 90, 90)
        draw.RoundedBox(ph / 2, 0, 0, pw, ph, Color(18, 24, 32, 230))
        draw.RoundedBox(ph / 2, 10, ph / 2 - 5, 10, 10, c)
        draw.SimpleText(tostring(text or "Status"), "MN_Small", 28, ph / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return pill
end

function MemoNetwork.Widgets.Header(parent, x, y, w, h, title, subtitle, accent)
    local theme = Theme()
    return MemoNetwork.Widgets.Panel(parent, x, y, w, h, function(_, pw, ph)
        draw.RoundedBox(6, 0, 0, 7, ph, accent or theme.Orange)
        draw.SimpleText(tostring(title or "MemoNetwork"), "MN_Title", 22, 28, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(tostring(subtitle), "MN_Text", 22, 58, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end)
end

function MemoNetwork.Widgets.Graph(parent, x, y, w, h, title, values, maxValue, accent)
    local theme = Theme()
    local panel = MemoNetwork.Widgets.Panel(parent, x, y, w, h, function(_, pw, ph)
        draw.SimpleText(tostring(title or "Graph"), "MN_Subtitle", 16, 20, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local graphX, graphY = 16, 46
        local graphW, graphH = pw - 32, ph - 62
        draw.RoundedBox(8, graphX, graphY, graphW, graphH, Color(8, 12, 18, 190))
        values = values or {}
        maxValue = math.max(1, maxValue or 100)
        local count = #values
        if count < 2 then return end
        for i = 2, count do
            local x1 = graphX + ((i - 2) / math.max(1, count - 1)) * graphW
            local x2 = graphX + ((i - 1) / math.max(1, count - 1)) * graphW
            local y1 = graphY + graphH - math.Clamp(values[i - 1] / maxValue, 0, 1) * graphH
            local y2 = graphY + graphH - math.Clamp(values[i] / maxValue, 0, 1) * graphH
            surface.SetDrawColor(accent or theme.Orange)
            surface.DrawLine(x1, y1, x2, y2)
        end
    end)
    return panel
end
