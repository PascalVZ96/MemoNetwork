-- MemoNetwork Lite Config

MemoNetwork = MemoNetwork or {}
MemoNetwork.Config = MemoNetwork.Config or {}

MemoNetwork.Config.ServerName = "MemoNetwork"
MemoNetwork.Config.Subtitle = "Industrial Sandbox"
MemoNetwork.Config.Version = "Alpha 9.0"

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

MemoNetwork.Config.ShowFPS = true
MemoNetwork.Config.ShowPing = true
MemoNetwork.Config.ShowPlayers = true

MemoNetwork.Config.MenuCommand = "mn_menu"
