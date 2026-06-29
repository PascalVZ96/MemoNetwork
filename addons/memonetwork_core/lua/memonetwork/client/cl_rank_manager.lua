-- MemoNetwork Alpha 11.3 Rank Manager UI

MemoNetwork = MemoNetwork or {}
MemoNetwork.RankManager = MemoNetwork.RankManager or {}

local frame

local function CanOpen()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.HasPermission then
        return MemoNetwork.Ranks.HasPermission(ply, "ranks.manage")
    end
    return ply:IsSuperAdmin()
end

local function Notify(message, kind)
    if MemoNetwork.Notify then
        MemoNetwork.Notify(message, kind or "info", "Rank Manager", 3)
    else
        chat.AddText(Color(255, 145, 0), "[Rank Manager] ", color_white, message)
    end
end

net.Receive("MemoNetwork_RankResult", function()
    Notify(net.ReadString(), net.ReadString())
end)

local function SendSetRank(target, rankName)
    if not IsValid(target) then return end

    net.Start("MemoNetwork_SetRank")
        net.WriteEntity(target)
        net.WriteString(rankName)
    net.SendToServer()
end

local function RankCombo(parent, x, y, w, h, selected)
    local combo = vgui.Create("DComboBox", parent)
    combo:SetPos(x, y)
    combo:SetSize(w, h)
    combo:SetFont("MN_Text")
    combo:SetValue(selected or "PLAYER")

    local ranks = MemoNetwork.Ranks and MemoNetwork.Ranks.Order or {"OWNER", "SUPERADMIN", "ADMIN", "MODERATOR", "DEVELOPER", "BUILDER", "VIP", "PLAYER"}
    for _, rankName in ipairs(ranks) do
        combo:AddChoice(rankName)
    end

    return combo
end

function MemoNetwork.RankManager.Open()
    if not CanOpen() then
        Notify("Only users with ranks.manage can open this.", "error")
        return
    end

    if IsValid(frame) then
        frame:Remove()
        frame = nil
        return
    end

    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()
    local w, h = 760, 540

    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:SetPos((sw - w) / 2, (sh - h) / 2)
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.12, 0)

    frame.Paint = function(_, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(14, 0, 0, pw, 78, theme.Orange, true, true, false, false)
        draw.SimpleText("MemoNetwork Rank Manager", "MN_Title", 26, 27, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Set ranks without editing Lua files", "MN_Text", 26, 55, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if MemoNetwork.UI and MemoNetwork.UI.CreateCloseButton then
        MemoNetwork.UI.CreateCloseButton(frame, w - 56, 20, function()
            frame:Remove()
            frame = nil
        end)
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(24, 100)
    scroll:SetSize(w - 48, h - 124)

    local players = player.GetAll()
    if MemoNetwork.Player and MemoNetwork.Player.Sort then
        MemoNetwork.Player.Sort(players)
    end

    local y = 0
    for _, ply in ipairs(players) do
        local currentRank = MemoNetwork.Ranks and MemoNetwork.Ranks.GetName(ply) or "PLAYER"
        local rankColor = MemoNetwork.Ranks and MemoNetwork.Ranks.GetColor(ply) or theme.Text

        local row = vgui.Create("DPanel", scroll)
        row:SetPos(0, y)
        row:SetSize(w - 68, 74)
        row.Paint = function(_, rw, rh)
            draw.RoundedBox(10, 0, 0, rw, rh, theme.PanelLight)
            draw.RoundedBox(6, 0, 0, 6, rh, rankColor)
            draw.SimpleText(IsValid(ply) and ply:Nick() or "Unknown", "MN_Subtitle", 62, 22, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(IsValid(ply) and ply:SteamID() or "Unknown", "MN_Small", 62, 50, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local avatar = vgui.Create("AvatarImage", row)
        avatar:SetSize(38, 38)
        avatar:SetPos(14, 18)
        avatar:SetPlayer(ply, 38)

        local combo = RankCombo(row, row:GetWide() - 244, 18, 140, 34, currentRank)

        local save = vgui.Create("DButton", row)
        save:SetPos(row:GetWide() - 94, 18)
        save:SetSize(78, 34)
        save:SetText("")
        save:SetCursor("hand")
        save.Paint = function(self, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, self:IsHovered() and Color(255, 170, 40) or theme.Orange)
            draw.SimpleText("Save", "MN_Text", pw / 2, ph / 2, Color(10, 10, 10), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        save.DoClick = function()
            local selected = combo:GetValue()
            SendSetRank(ply, selected)
        end

        y = y + 84
    end
end

concommand.Add("mn_rankmanager", MemoNetwork.RankManager.Open)
