-- MemoNetwork Alpha 10 Loader

MemoNetwork = MemoNetwork or {}

local function AddClient(path)
    if SERVER then
        AddCSLuaFile(path)
    else
        include(path)
    end
end

local function AddShared(path)
    if SERVER then
        AddCSLuaFile(path)
    end
    include(path)
end

local function AddServer(path)
    if SERVER then
        include(path)
    end
end

AddShared("memonetwork/shared/sh_config.lua")
AddShared("memonetwork/shared/sh_theme.lua")
AddShared("memonetwork/shared/sh_modules.lua")
AddShared("memonetwork/shared/sh_ranks.lua")
AddShared("memonetwork/shared/sh_player.lua")

AddClient("memonetwork/client/cl_fonts.lua")
AddClient("memonetwork/client/cl_settings.lua")
AddClient("memonetwork/client/cl_ui.lua")
AddClient("memonetwork/client/cl_hud.lua")
AddClient("memonetwork/client/cl_voice.lua")
AddClient("memonetwork/client/cl_scoreboard.lua")
AddClient("memonetwork/client/cl_player_inspector.lua")
AddClient("memonetwork/client/cl_menu.lua")
AddClient("memonetwork/client/cl_notifications.lua")
AddClient("memonetwork/client/cl_links.lua")
AddClient("memonetwork/client/cl_version.lua")
AddClient("memonetwork/client/cl_events.lua")
AddClient("memonetwork/client/cl_admin.lua")

AddServer("memonetwork/server/sv_commands.lua")
AddServer("memonetwork/server/sv_welcome.lua")
AddServer("memonetwork/server/sv_events.lua")
AddServer("memonetwork/server/sv_admin.lua")
