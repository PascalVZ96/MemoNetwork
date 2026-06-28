-- MemoNetwork Alpha 10 Player Helper

MemoNetwork = MemoNetwork or {}
MemoNetwork.Player = MemoNetwork.Player or {}

function MemoNetwork.Player.GetName(ply)
    if not IsValid(ply) then return "Unknown" end
    return ply:Nick()
end

function MemoNetwork.Player.GetSteamID(ply)
    if not IsValid(ply) then return "UNKNOWN" end
    return ply:SteamID()
end

function MemoNetwork.Player.GetRank(ply)
    return MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = Color(230, 230, 230), sort = 99}
end

function MemoNetwork.Player.GetPingColor(ping)
    ping = tonumber(ping) or 0

    if ping <= 50 then return Color(90, 220, 120) end
    if ping <= 100 then return Color(255, 190, 80) end
    return Color(255, 90, 90)
end

function MemoNetwork.Player.Sort(list)
    table.sort(list, function(a, b)
        local ra = MemoNetwork.Ranks and MemoNetwork.Ranks.GetSort(a) or 99
        local rb = MemoNetwork.Ranks and MemoNetwork.Ranks.GetSort(b) or 99

        if ra == rb then
            return string.lower(MemoNetwork.Player.GetName(a)) < string.lower(MemoNetwork.Player.GetName(b))
        end

        return ra < rb
    end)

    return list
end
