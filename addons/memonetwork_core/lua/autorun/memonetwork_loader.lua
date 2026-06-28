-- MemoNetwork Lite Loader

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

AddShared("memonetwork/shared/sh_config.lua")
AddShared("memonetwork/shared/sh_theme.lua")
AddShared("memonetwork/shared/sh_ranks.lua")

AddClient("memonetwork/client/cl_fonts.lua")
AddClient("memonetwork/client/cl_settings.lua")
AddClient("memonetwork/client/cl_hud.lua")
AddClient("memonetwork/client/cl_voice.lua")
AddClient("memonetwork/client/cl_scoreboard.lua")
AddClient("memonetwork/client/cl_menu.lua")
AddClient("memonetwork/client/cl_notifications.lua")
AddClient("memonetwork/client/cl_links.lua")
AddClient("memonetwork/client/cl_version.lua")
AddClient("memonetwork/client/cl_events.lua")
AddClient("memonetwork/client/cl_admin.lua")

if SERVER then
    include("memonetwork/server/sv_commands.lua")
    include("memonetwork/server/sv_welcome.lua")
    include("memonetwork/server/sv_events.lua")
    include("memonetwork/server/sv_admin.lua")
end
