-- MemoNetwork Alpha 11.2 Permission Viewer
-- Temporary standalone viewer while the F6 permission tab is expanded.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Permissions = MemoNetwork.Permissions or {}

local frame

local function CanOpen()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if MemoNetwork.Ranks and MemoNetwork.Ranks.CanAdmin then
        return MemoNetwork.Ranks.CanAdmin(ply)
    end
    return ply:IsAdmin()
end

local function OpenPermissions()
    if not CanOpen() then
        if MemoNetwork.Notify then
            MemoNetwork.Notify("Permission viewer is owner/admin only.", "error", "Permissions", 3)
        end
        return
    end

    if IsValid(frame) then
        frame:Remove()
        frame = nil
        return
    end

    local theme = MemoNetwork.Theme
    local sw, sh = ScrW(), ScrH()
    local w, h = 720, 520

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
        draw.SimpleText("MemoNetwork Permissions", "MN_Title", 26, 27, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(MemoNetwork.Config.Version or "Alpha", "MN_Text", 26, 55, Color(25, 25, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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

    local ranks = MemoNetwork.Ranks and MemoNetwork.Ranks.Definitions or {}
    local ordered = {}
    for key, data in pairs(ranks) do
        ordered[#ordered + 1] = {key = key, data = data}
    end
    table.sort(ordered, function(a, b)
        return (a.data.sort or 99) < (b.data.sort or 99)
    end)

    local y = 0
    for _, item in ipairs(ordered) do
        local rank = item.data
        local perms = table.concat(rank.permissions or {}, ", ")
        if perms == "" then perms = "No admin permissions" end

        local row = vgui.Create("DPanel", scroll)
        row:SetPos(0, y)
        row:SetSize(w - 68, 72)
        row.Paint = function(_, rw, rh)
            draw.RoundedBox(10, 0, 0, rw, rh, theme.PanelLight)
            draw.RoundedBox(6, 0, 0, 6, rh, rank.color or theme.Orange)
            draw.SimpleText(rank.name or item.key, "MN_Subtitle", 18, 22, rank.color or theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(perms, "MN_Small", 18, 52, theme.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        y = y + 82
    end
end

MemoNetwork.Permissions.Open = OpenPermissions
concommand.Add("mn_permissions", OpenPermissions)
