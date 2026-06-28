-- MemoNetwork Lite Scoreboard V2
-- Compact scoreboard with avatars, rank display, ping colors and sorted players.

local board
local playerList

local function GetRank(ply)
    if not IsValid(ply) then return "Player", Color(220, 220, 220) end

    local group = "player"

    if ply.GetUserGroup then
        group = string.lower(ply:GetUserGroup() or "player")
    elseif ply:IsSuperAdmin() then
        group = "superadmin"
    elseif ply:IsAdmin() then
        group = "admin"
    end

    if group == "superadmin" or group == "owner" then
        return "Owner", Color(255, 145, 0)
    end

    if group == "admin" then
        return "Admin", Color(80, 160, 255)
    end

    return "Player", Color(230, 230, 230)
end

local function GetSortWeight(ply)
    local rank = select(1, GetRank(ply))

    if rank == "Owner" then return 1 end
    if rank == "Admin" then return 2 end

    return 3
end

local function PingColor(ping)
    if ping <= 50 then
        return Color(90, 220, 120)
    elseif ping <= 100 then
        return Color(255, 190, 80)
    end

    return Color(255, 90, 90)
end

local function SortedPlayers()
    local players = player.GetAll()

    table.sort(players, function(a, b)
        local wa, wb = GetSortWeight(a), GetSortWeight(b)

        if wa == wb then
            return string.lower(a:Nick()) < string.lower(b:Nick())
        end

        return wa < wb
    end)

    return players
end

local function BuildPlayerList(parent)
    if not IsValid(parent) then return end
    if IsValid(playerList) then playerList:Remove() end

    local theme = MemoNetwork.Theme
    local w = parent:GetWide()

    playerList = vgui.Create("DScrollPanel", parent)
    playerList:SetPos(18, 72)
    playerList:SetSize(w - 36, parent:GetTall() - 90)

    local y = 0

    for _, ply in ipairs(SortedPlayers()) do
        local row = vgui.Create("DPanel", playerList)
        row:SetPos(0, y)
        row:SetSize(w - 44, 54)

        local avatar = vgui.Create("AvatarImage", row)
        avatar:SetSize(36, 36)
        avatar:SetPos(10, 9)
        avatar:SetPlayer(ply, 36)

        row.Paint = function(_, rw, rh)
            local rankText, rankColor = GetRank(ply)
            local ping = IsValid(ply) and ply:Ping() or 0

            draw.RoundedBox(8, 0, 0, rw, rh, theme.PanelLight or Color(30, 38, 48, 220))

            draw.SimpleText(IsValid(ply) and ply:Nick() or "Unknown", "MN_Text", 58, 17, theme.Text or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(rankText, "MN_Small", 58, 36, rankColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            draw.SimpleText(ping .. " ms", "MN_Text", rw - 16, rh / 2, PingColor(ping), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        y = y + 62
    end
end

local function CloseScoreboard()
    if IsValid(board) then
        board:AlphaTo(0, 0.10, 0, function()
            if IsValid(board) then
                board:Remove()
                board = nil
                playerList = nil
            end
        end)
    end
end

local function OpenScoreboard()
    if IsValid(board) then return end

    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()

    local w = 620
    local h = math.min(460, sh - 160)

    board = vgui.Create("DFrame")
    board:SetSize(w, h)
    board:SetPos((sw - w) / 2, (sh - h) / 2)
    board:SetTitle("")
    board:SetDraggable(false)
    board:ShowCloseButton(false)
    board:SetAlpha(0)
    board:AlphaTo(255, 0.10, 0)

    board.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.Background or Color(12, 16, 22, 225))
        draw.RoundedBoxEx(12, 0, 0, pw, 56, theme.Orange or Color(255, 145, 0), true, true, false, false)

        draw.SimpleText(MemoNetwork.Config.ServerName or "MemoNetwork", "MN_Title", 22, 28, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#player.GetAll() .. "/" .. game.MaxPlayers(), "MN_Text", pw - 22, 28, Color(10, 10, 10), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    BuildPlayerList(board)
end

hook.Add("ScoreboardShow", "MemoNetwork_ScoreboardShow_V2", function()
    OpenScoreboard()
    return false
end)

hook.Add("ScoreboardHide", "MemoNetwork_ScoreboardHide_V2", function()
    CloseScoreboard()
    return false
end)

hook.Add("PlayerConnect", "MemoNetwork_ScoreboardRefreshConnect", function()
    timer.Simple(1, function()
        if IsValid(board) then
            BuildPlayerList(board)
        end
    end)
end)

hook.Add("PlayerDisconnected", "MemoNetwork_ScoreboardRefreshDisconnect", function()
    timer.Simple(0.2, function()
        if IsValid(board) then
            BuildPlayerList(board)
        end
    end)
end)
