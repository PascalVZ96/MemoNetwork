-- MemoNetwork Lite Scoreboard V3
-- Restored polished scoreboard: avatars, ranks, ping colors and sorting.

local board
local playerList

local function ModuleEnabled(name)
    return not MemoNetwork.Modules or MemoNetwork.Modules:IsEnabled(name)
end

local function PingColor(ping)
    if MemoNetwork.Player and MemoNetwork.Player.GetPingColor then
        return MemoNetwork.Player.GetPingColor(ping)
    end

    if ping <= 50 then return Color(90, 220, 120) end
    if ping <= 100 then return Color(255, 190, 80) end
    return Color(255, 90, 90)
end

local function SortedPlayers()
    local players = player.GetAll()

    if MemoNetwork.Player and MemoNetwork.Player.Sort then
        return MemoNetwork.Player.Sort(players)
    end

    table.sort(players, function(a, b)
        return string.lower(a:Nick()) < string.lower(b:Nick())
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
            local rank = MemoNetwork.Ranks and MemoNetwork.Ranks.Get(ply) or {name = "PLAYER", color = theme.Text}
            local ping = IsValid(ply) and ply:Ping() or 0

            draw.RoundedBox(8, 0, 0, rw, rh, theme.PanelLight or Color(30, 38, 48, 220))
            draw.RoundedBox(6, 0, 0, 5, rh, rank.color or theme.Orange)

            draw.SimpleText(IsValid(ply) and ply:Nick() or "Unknown", "MN_Text", 58, rh / 2, theme.Text or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(rank.name or "PLAYER", "MN_Text", rw - 170, rh / 2, rank.color or theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
    if not ModuleEnabled("Scoreboard") then return end
    if IsValid(board) then return end

    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()

    local w = 640
    local h = math.min(420, sh - 160)

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

hook.Add("ScoreboardShow", "MemoNetwork_ScoreboardShow_V3", function()
    OpenScoreboard()
    return false
end)

hook.Add("ScoreboardHide", "MemoNetwork_ScoreboardHide_V3", function()
    CloseScoreboard()
    return false
end)
