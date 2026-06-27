-- MemoNetwork Lite Welcome Message

hook.Add("PlayerInitialSpawn", "MemoNetwork_Welcome", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end

        ply:ChatPrint("==========================================")
        ply:ChatPrint(" Welcome to MemoNetwork")
        ply:ChatPrint(" Type !menu or bind F1 to mn_menu.")
        ply:ChatPrint(" Use !rules, !build, !discord, !website.")
        ply:ChatPrint("==========================================")
    end)
end)
