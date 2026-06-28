-- MemoNetwork Alpha 10 Module Manager

MemoNetwork = MemoNetwork or {}
MemoNetwork.Modules = MemoNetwork.Modules or {}
MemoNetwork.Modules.Registered = MemoNetwork.Modules.Registered or {}

function MemoNetwork.Modules:Register(name, data)
    if not name or name == "" then return end

    data = data or {}
    data.name = name
    data.enabled = data.enabled ~= false
    data.version = data.version or "1.0"
    data.description = data.description or "MemoNetwork module"

    self.Registered[name] = data
end

function MemoNetwork.Modules:IsEnabled(name)
    local config = MemoNetwork.Config and MemoNetwork.Config.Modules

    if config and config[name] == false then
        return false
    end

    local module = self.Registered[name]
    if module and module.enabled == false then
        return false
    end

    return true
end

function MemoNetwork.Modules:Get(name)
    return self.Registered[name]
end

function MemoNetwork.Modules:GetAll()
    return self.Registered
end

MemoNetwork.Modules:Register("HUD", {description = "Player status HUD"})
MemoNetwork.Modules:Register("Scoreboard", {description = "Custom scoreboard"})
MemoNetwork.Modules:Register("VoiceHUD", {description = "Custom voice display"})
MemoNetwork.Modules:Register("Dashboard", {description = "F1 dashboard"})
MemoNetwork.Modules:Register("Notifications", {description = "Toast notification system"})
MemoNetwork.Modules:Register("Admin", {description = "F6 admin tools"})
MemoNetwork.Modules:Register("Events", {description = "Join/leave events"})
MemoNetwork.Modules:Register("Links", {description = "Clickable website and Discord links"})
