-- MemoNetwork Client URL opener

net.Receive("MemoNetwork_OpenURL", function()
    local url = net.ReadString()

    if not url or url == "" or url == "Coming soon" then return end

    gui.OpenURL(url)
end)
