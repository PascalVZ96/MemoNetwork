-- MemoNetwork Lite Ranks
-- Shared helper functions for HUD, scoreboard and voice HUD.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Ranks = MemoNetwork.Ranks or {}

function MemoNetwork.Ranks.Get(ply)
    local cfg = MemoNetwork.Config or {}
    local default = cfg.DefaultRank or {
        name = "PLAYER",
        color = Color(230, 230, 230),
        sort = 99
    }

    if not IsValid(ply) or not ply:IsPlayer() then
        return default
    end

    local steamid = ply:SteamID()

    if cfg.Ranks and cfg.Ranks[steamid] then
        return cfg.Ranks[steamid]
    end

    if ply.GetUserGroup then
        local group = string.lower(ply:GetUserGroup() or "")

        if group == "superadmin" or group == "owner" then
            return {
                name = "OWNER",
                color = Color(255, 145, 0),
                sort = 1
            }
        end

        if group == "admin" then
            return {
                name = "ADMIN",
                color = Color(80, 160, 255),
                sort = 2
            }
        end
    end

    return default
end

function MemoNetwork.Ranks.GetName(ply)
    return MemoNetwork.Ranks.Get(ply).name or "PLAYER"
end

function MemoNetwork.Ranks.GetColor(ply)
    return MemoNetwork.Ranks.Get(ply).color or Color(230, 230, 230)
end

function MemoNetwork.Ranks.GetSort(ply)
    return MemoNetwork.Ranks.Get(ply).sort or 99
end

function MemoNetwork.Ranks.IsOwner(ply)
    return MemoNetwork.Ranks.GetName(ply) == "OWNER"
end
