-- MemoNetwork Lite Client Settings
-- Local player settings saved with cookies.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Settings = MemoNetwork.Settings or {}

local defaults = {
    hud = true,
    voice = true,
    notifications = true,
    fps = true,
    ping = true,
    players = true
}

local values = {}

local function CookieName(key)
    return "memonetwork_setting_" .. key
end

function MemoNetwork.Settings.Get(key)
    if values[key] == nil then
        return defaults[key]
    end

    return values[key]
end

function MemoNetwork.Settings.Set(key, value)
    if defaults[key] == nil then return end

    values[key] = value and true or false
    cookie.Set(CookieName(key), values[key] and "1" or "0")

    if MemoNetwork.Notify then
        MemoNetwork.Notify("Setting saved: " .. key, "success", "Settings", 2.5)
    end
end

function MemoNetwork.Settings.Toggle(key)
    MemoNetwork.Settings.Set(key, not MemoNetwork.Settings.Get(key))
end

function MemoNetwork.Settings.Load()
    for key, default in pairs(defaults) do
        local stored = cookie.GetString(CookieName(key), nil)

        if stored == nil then
            values[key] = default
        else
            values[key] = stored == "1"
        end
    end
end

MemoNetwork.Settings.Load()
