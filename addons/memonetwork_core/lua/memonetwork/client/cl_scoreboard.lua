-- MemoNetwork Lite Scoreboard

local board

local function CloseScoreboard()
    if IsValid(board) then
        board:Remove()
        board = nil
    end
end

local function OpenScoreboard()
    if IsValid(board) then return end

    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()
    local w, h = 560, 360

    board = vgui.Create("DFrame")
    board:SetSize(w, h)
    board:SetPos((sw - w) / 2, (sh - h) / 2)
    board:SetTitle("")
    board:SetDraggable(false)
    board:ShowCloseButton(false)

    board.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(12, 0, 0, pw, 52, theme.Orange, true, true, false, false)
        draw.SimpleText("MemoNetwork", "MN_Title", 22, 26, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#player.GetAll() .. "/" .. game.MaxPlayers(), "MN_Text", pw - 22, 26, Color(10, 10, 10), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local y = 68
    for _, ply in ipairs(player.GetAll()) do
        local row = vgui.Create("DPanel", board)
        row:SetSize(w - 40, 38)
        row:SetPos(20, y)
        row.Paint = function(_, rw, rh)
            draw.RoundedBox(8, 0, 0, rw, rh, theme.PanelLight)
            draw.SimpleText(ply:Nick(), "MN_Text", 14, rh / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(ply:IsAdmin() and "Admin" or "Player", "MN_Small", rw - 115, rh / 2, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText(ply:Ping() .. " ms", "MN_Small", rw - 14, rh / 2, theme.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        y = y + 46
    end
end

hook.Add("ScoreboardShow", "MemoNetwork_ScoreboardShow", function()
    OpenScoreboard()
    return false
end)

hook.Add("ScoreboardHide", "MemoNetwork_ScoreboardHide", function()
    CloseScoreboard()
    return false
end)
