-- MemoNetwork Alpha 11.3 Persistent Rank Manager

MemoNetwork = MemoNetwork or {}
MemoNetwork.StoredRanks = MemoNetwork.StoredRanks or {}

util.AddNetworkString("MemoNetwork_SetRank")
util.AddNetworkString("MemoNetwork_RankResult")

local DATA_DIR = "memonetwork"
local DATA_FILE = DATA_DIR .. "/ranks.json"

local function HasPerm(ply, permission)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, permission)
    end
    return ply:IsAdmin()
end

local function SendResult(ply, message, kind)
    net.Start("MemoNetwork_RankResult")
        net.WriteString(message or "")
        net.WriteString(kind or "info")
    net.Send(ply)
end

local function SaveRanks()
    if not file.Exists(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    file.Write(DATA_FILE, util.TableToJSON(MemoNetwork.StoredRanks, true))
end

local function ApplyRank(ply)
    if not IsValid(ply) then return end

    local steamid = ply:SteamID()
    local storedRank = MemoNetwork.StoredRanks[steamid]

    if storedRank and MemoNetwork.Ranks and MemoNetwork.Ranks.IsValidRank(storedRank) then
        ply:SetNWString("MemoNetwork_Rank", storedRank)
    else
        ply:SetNWString("MemoNetwork_Rank", "")
    end
end

local function LoadRanks()
    if not file.Exists(DATA_FILE, "DATA") then
        MemoNetwork.StoredRanks = {}
        return
    end

    local raw = file.Read(DATA_FILE, "DATA") or "{}"
    local data = util.JSONToTable(raw) or {}

    MemoNetwork.StoredRanks = data

    for _, ply in ipairs(player.GetAll()) do
        ApplyRank(ply)
    end
end

hook.Add("Initialize", "MemoNetwork_LoadRanks", LoadRanks)

hook.Add("PlayerInitialSpawn", "MemoNetwork_ApplyRank", function(ply)
    timer.Simple(1, function()
        ApplyRank(ply)
    end)
end)

net.Receive("MemoNetwork_SetRank", function(_, admin)
    if not HasPerm(admin, "ranks.manage") then
        SendResult(admin, "Missing permission: ranks.manage", "error")
        return
    end

    local target = net.ReadEntity()
    local rankName = string.upper(net.ReadString() or "")

    if not IsValid(target) or not target:IsPlayer() then
        SendResult(admin, "Invalid target player.", "error")
        return
    end

    if not MemoNetwork.Ranks or not MemoNetwork.Ranks.IsValidRank(rankName) then
        SendResult(admin, "Invalid rank: " .. rankName, "error")
        return
    end

    local adminRank = MemoNetwork.Ranks.GetName(admin)
    if adminRank ~= "OWNER" and rankName == "OWNER" then
        SendResult(admin, "Only OWNER can assign OWNER rank.", "error")
        return
    end

    MemoNetwork.StoredRanks[target:SteamID()] = rankName
    SaveRanks()
    ApplyRank(target)

    SendResult(admin, "Set " .. target:Nick() .. " to " .. rankName .. ".", "success")

    if net.Start then
        net.Start("MemoNetwork_AdminLog")
            net.WriteString(os.date("%H:%M:%S"))
            net.WriteString(admin:Nick())
            net.WriteString("set " .. target:Nick() .. " rank to " .. rankName)
            net.WriteString("success")
        net.Broadcast()
    end
end)
