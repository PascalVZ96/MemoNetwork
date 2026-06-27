-- MemoNetwork Lite F1 Menu

local menu

local function CloseMenu()
    if IsValid(menu) then
        menu:Remove()
        menu = nil
    end
end

local function OpenMenu()
    if IsValid(menu) then
        CloseMenu()
        return
    end

    local theme = MemoNetwork.Theme
    local cfg = MemoNetwork.Config
    local sw, sh = ScrW(), ScrH()
    local w, h = 540, 390

    menu = vgui.Create("DFrame")
    menu:SetSize(w, h)
    menu:SetPos((sw - w) / 2, (sh - h) / 2)
    menu:SetTitle("")
    menu:SetDraggable(false)
    menu:ShowCloseButton(false)
    menu:MakePopup()

    menu.Paint = function(_, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, theme.Background)
        draw.RoundedBoxEx(12, 0, 0, pw, 58, theme.Orange, true, true, false, false)
        draw.SimpleText(cfg.ServerName, "MN_Title", 24, 29, Color(10, 10, 10), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.Subtitle, "MN_Text", 24, 84, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", menu)
    close:SetSize(84, 30)
    close:SetPos(w - 104, 14)
    close:SetText("Close")
    close:SetFont("MN_Text")
    close.DoClick = CloseMenu

    local items = {
        {"Rules", "Be respectful. No griefing. Clean up your builds."},
        {"Build Guide", "Use Precision Tool, SmartSnap and Advanced Duplicator 2 for better builds."},
        {"Workshop", cfg.Workshop},
        {"Discord", cfg.Discord},
        {"Website", cfg.Website}
    }

    for i, item in ipairs(items) do
        local btn = vgui.Create("DButton", menu)
        btn:SetSize(w - 48, 40)
        btn:SetPos(24, 120 + ((i - 1) * 47))
        btn:SetText(item[1])
        btn:SetFont("MN_Text")
        btn.DoClick = function()
            chat.AddText(theme.Orange, "[MemoNetwork] ", Color(255, 255, 255), item[2])
        end
    end
end

concommand.Add("mn_menu", OpenMenu)

hook.Add("ShowHelp", "MemoNetwork_ShowHelp", function()
    OpenMenu()
    return true
end)

hook.Add("OnPlayerChat", "MemoNetwork_MenuChat", function(ply, text)
    if ply ~= LocalPlayer() then return end

    text = string.Trim(string.lower(text or ""))

    if text == "!menu" or text == "/menu" or text == "!f1" or text == "/f1" then
        OpenMenu()
        return true
    end
end)
