-- MemoNetwork Lite Notifications

MemoNetwork = MemoNetwork or {}
MemoNetwork.Notifications = MemoNetwork.Notifications or {}

local notes = {}

function MemoNetwork.Notifications.Add(text)
    notes[#notes + 1] = {
        text = tostring(text or ""),
        time = CurTime()
    }
end

hook.Add("HUDPaint", "MemoNetwork_Notifications", function()
    local theme = MemoNetwork.Theme
    local sw = ScrW()

    for i = #notes, 1, -1 do
        local n = notes[i]
        local age = CurTime() - n.time

        if age > 4 then
            table.remove(notes, i)
        else
            local alpha = 255
            if age > 3 then
                alpha = 255 * (1 - (age - 3))
            end

            local w, h = 260, 38
            local x = sw - w - 24
            local y = 24 + ((i - 1) * 44)

            draw.RoundedBox(8, x, y, w, h, Color(12, 16, 22, math.Clamp(alpha, 0, 225)))
            draw.RoundedBox(8, x, y, 5, h, Color(255, 145, 0, math.Clamp(alpha, 0, 255)))
            draw.SimpleText(n.text, "MN_Text", x + 16, y + h / 2, Color(240, 240, 240, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end)

hook.Add("InitPostEntity", "MemoNetwork_WelcomeNotification", function()
    timer.Simple(2, function()
        if MemoNetwork and MemoNetwork.Notifications then
            MemoNetwork.Notifications.Add("Welcome to MemoNetwork")
        end
    end)
end)
