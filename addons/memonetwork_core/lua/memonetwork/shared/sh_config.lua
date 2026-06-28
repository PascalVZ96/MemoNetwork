-- MemoNetwork Lite Config

MemoNetwork = MemoNetwork or {}
MemoNetwork.Config = MemoNetwork.Config or {}

MemoNetwork.Config.ServerName = "MemoNetwork"
MemoNetwork.Config.Subtitle = "Industrial Sandbox"
MemoNetwork.Config.Version = "Alpha 11.5-dev"

MemoNetwork.Config.Website = "https://memocraft.nl"
MemoNetwork.Config.Discord = "https://memocraft.nl/?c=Discord"
MemoNetwork.Config.Workshop = "Coming soon"

MemoNetwork.Config.Owners = {
    ["STEAM_0:1:69073790"] = true
}

MemoNetwork.Config.Ranks = {
    ["STEAM_0:1:69073790"] = {
        name = "OWNER",
        color = Color(255, 145, 0),
        sort = 1
    }
}

MemoNetwork.Config.DefaultRank = {
    name = "PLAYER",
    color = Color(230, 230, 230),
    sort = 99
}

MemoNetwork.Config.Modules = {
    HUD = true,
    Scoreboard = true,
    VoiceHUD = true,
    Dashboard = true,
    Notifications = true,
    Admin = true,
    Events = true,
    Links = true
}

-- Maps shown in the F6 Admin Panel.
-- Add/remove maps here when the server map pool changes.
MemoNetwork.Config.Maps = {
    {name = "Construct", map = "gm_construct", description = "Default Sandbox build map"},
    {name = "Flatgrass", map = "gm_flatgrass", description = "Simple open build map"},
    {name = "Big City", map = "gm_bigcity", description = "Large city sandbox map"},
    {name = "Fork", map = "gm_fork", description = "Large scenic sandbox map"},
    {name = "Mall Parking", map = "gm_mallparking", description = "Parking/build test map"}
}

MemoNetwork.Config.ShowFPS = true
MemoNetwork.Config.ShowPing = true
MemoNetwork.Config.ShowPlayers = true

MemoNetwork.Config.MenuCommand = "mn_menu"
MemoNetwork.Config.AdminCommand = "mn_admin"
