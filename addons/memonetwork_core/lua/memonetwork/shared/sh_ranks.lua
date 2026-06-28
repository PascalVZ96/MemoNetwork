-- MemoNetwork Alpha 11.2 Rank + Permission Manager

MemoNetwork = MemoNetwork or {}
MemoNetwork.Ranks = MemoNetwork.Ranks or {}

MemoNetwork.Ranks.Definitions = {
    OWNER = {
        name = "OWNER",
        color = Color(255, 145, 0),
        sort = 1,
        permissions = {"*"}
    },
    SUPERADMIN = {
        name = "SUPERADMIN",
        color = Color(255, 105, 105),
        sort = 2,
        permissions = {"admin.open", "players.manage", "cleanup", "broadcast", "map.change", "map.restart", "logs.view"}
    },
    ADMIN = {
        name = "ADMIN",
        color = Color(80, 160, 255),
        sort = 3,
        permissions = {"admin.open", "players.manage", "cleanup", "broadcast", "logs.view"}
    },
    MODERATOR = {
        name = "MODERATOR",
        color = Color(120, 210, 255),
        sort = 4,
        permissions = {"admin.open", "players.inspect", "broadcast", "logs.view"}
    },
    DEVELOPER = {
        name = "DEVELOPER",
        color = Color(180, 120, 255),
        sort = 5,
        permissions = {"admin.open", "players.inspect", "logs.view"}
    },
    BUILDER = {
        name = "BUILDER",
        color = Color(90, 220, 120),
        sort = 6,
        permissions = {"players.inspect"}
    },
    VIP = {
        name = "VIP",
        color = Color(255, 210, 90),
        sort = 7,
        permissions = {"players.inspect"}
    },
    PLAYER = {
        name = "PLAYER",
        color = Color(230, 230, 230),
        sort = 99,
        permissions = {}
    }
}

local groupMap = {
    owner = "OWNER",
    superadmin = "SUPERADMIN",
    admin = "ADMIN",
    moderator = "MODERATOR",
    mod = "MODERATOR",
    developer = "DEVELOPER",
    dev = "DEVELOPER",
    builder = "BUILDER",
    vip = "VIP"
}

local function CopyRank(rank)
    return {
        name = rank.name,
        color = rank.color,
        sort = rank.sort,
        permissions = rank.permissions or {}
    }
end

function MemoNetwork.Ranks.GetByName(name)
    name = string.upper(tostring(name or "PLAYER"))
    return CopyRank(MemoNetwork.Ranks.Definitions[name] or MemoNetwork.Ranks.Definitions.PLAYER)
end

function MemoNetwork.Ranks.Get(ply)
    local cfg = MemoNetwork.Config or {}
    local default = cfg.DefaultRank or MemoNetwork.Ranks.Definitions.PLAYER

    if not IsValid(ply) or not ply:IsPlayer() then
        return CopyRank(default)
    end

    local steamid = ply:SteamID()

    if cfg.Ranks and cfg.Ranks[steamid] then
        local custom = cfg.Ranks[steamid]
        local base = MemoNetwork.Ranks.GetByName(custom.name or "PLAYER")
        base.name = custom.name or base.name
        base.color = custom.color or base.color
        base.sort = custom.sort or base.sort
        base.permissions = custom.permissions or base.permissions
        return base
    end

    if ply.GetUserGroup then
        local group = string.lower(ply:GetUserGroup() or "")
        if groupMap[group] then
            return MemoNetwork.Ranks.GetByName(groupMap[group])
        end
    end

    return CopyRank(default)
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

function MemoNetwork.Ranks.HasPermission(ply, permission)
    if not IsValid(ply) then return false end
    permission = tostring(permission or "")

    local rank = MemoNetwork.Ranks.Get(ply)
    for _, perm in ipairs(rank.permissions or {}) do
        if perm == "*" or perm == permission then
            return true
        end
    end

    return false
end

function MemoNetwork.Ranks.CanAdmin(ply)
    return MemoNetwork.Ranks.HasPermission(ply, "admin.open")
end
