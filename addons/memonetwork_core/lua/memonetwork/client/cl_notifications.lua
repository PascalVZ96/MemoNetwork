-- MemoNetwork Lite Notifications V2
-- Reusable notification/toast system for MemoNetwork.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Notifications = MemoNetwork.Notifications or {}

local notes = {}

local TYPES = {
    info = {
        color = Color(80, 160, 255),
        title = "Info"
    },
    success = {
        color = Color(90, 220, 120),
        title = "Success"
    },
    warning = {
        color = Color(255, 190, 80),
        title = "Warning"
    },
    error = {
        color = Color(255, 90, 90),
        title = "Error"
    }
}

function MemoNetwork.Notifications.Add(message, kind, title, duration)
    kind = string.lower(kind or "info")

    local data = TYPES[kind] or TYPES.info

    table.insert(notes, 1, {
        message = tostring(message or ""),
        title = tostring(title or data.title),
        kind = kind,
        color = data.color,
        start = CurTime(),
        duration = duration or 4,
        xOffset = 320,
        alpha = 0
    })
end

-- Short helper aliases
function MemoNetwork.Notify(message, kind, title, duration)
    MemoNetwork.Notifications.Add(message, kind, title, duration)
end

local function DrawNotification(n, index)
    local theme = MemoNetwork.Theme
    local sw = ScrW()

    local w = 330
    local h = 72
    local targetX = sw - w - 24
    local targetY = 24 + ((index - 1) * (h + 10))

    n.xOffset = Lerp(FrameTime() * 10, n.xOffset, 0)
    n.alpha = Lerp(FrameTime() * 10, n.alpha, 255)

    local x = targetX + n.xOffset
    local y = targetY

    local alpha = math.Clamp(n.alpha, 0, 255)

    draw.RoundedBox(10, x, y, w, h, Color(12, 16, 22, math.min(alpha, 230)))
    draw.RoundedBoxEx(10, x, y, 7, h, Color(n.color.r, n.color.g, n.color.b, alpha), true, false, true, false)

    draw.SimpleText(n.title, "MN_Subtitle", x + 20, y + 22, Color(240, 240, 240, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(n.message, "MN_Text", x + 20, y + 49, Color(175, 180, 190, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "MemoNetwork_NotificationsV2", function()
    for i = #notes, 1, -1 do
        local n = notes[i]
        local age = CurTime() - n.start

        if age > n.duration then
            n.xOffset = Lerp(FrameTime() * 12, n.xOffset, 360)
            n.alpha = Lerp(FrameTime() * 12, n.alpha, 0)

            if n.alpha < 5 then
                table.remove(notes, i)
            end
        end
    end

    for i, n in ipairs(notes) do
        if i <= 5 then
            DrawNotification(n, i)
        end
    end
end)

hook.Add("InitPostEntity", "MemoNetwork_WelcomeNotificationV2", function()
    timer.Simple(2, function()
        local ply = LocalPlayer()
        local name = IsValid(ply) and ply:Nick() or "Builder"

        MemoNetwork.Notify("Welcome " .. name, "success", "MemoNetwork", 5)
    end)
end)
