-- MemoNetwork Alpha 15.2 Addon Detector
-- Detects common Sandbox addons client-side and exposes status for F6/workshop tools.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Addons = MemoNetwork.Addons or {}

local checks = {
    {
        key = "wiremod",
        name = "Wiremod",
        hint = "Wire tools / Expression 2",
        test = function()
            return WireLib ~= nil or WireToolObj ~= nil or weapons.Get("gmod_tool") ~= nil and file.Exists("weapons/gmod_tool/stools/wire_expression2.lua", "LUA")
        end
    },
    {
        key = "advdupe2",
        name = "Advanced Duplicator 2",
        hint = "Build saving/loading",
        test = function()
            return AdvDupe2 ~= nil or file.Exists("weapons/gmod_tool/stools/advdupe2.lua", "LUA")
        end
    },
    {
        key = "precision",
        name = "Precision Tool",
        hint = "Precise building",
        test = function()
            return file.Exists("weapons/gmod_tool/stools/precision.lua", "LUA") or file.Exists("weapons/gmod_tool/stools/precision_align.lua", "LUA")
        end
    },
    {
        key = "smartsnap",
        name = "SmartSnap",
        hint = "Grid snapping overlay",
        test = function()
            return SmartSnap ~= nil or file.Exists("autorun/client/smartsnap.lua", "LUA")
        end
    },
    {
        key = "pac3",
        name = "PAC3",
        hint = "Player customization",
        test = function()
            return pac ~= nil or file.Exists("autorun/pac_init.lua", "LUA")
        end
    },
    {
        key = "acf",
        name = "ACF",
        hint = "Combat/build systems",
        test = function()
            return ACF ~= nil or file.Exists("acf/shared/init.lua", "LUA")
        end
    },
    {
        key = "lvs",
        name = "LVS",
        hint = "Vehicle framework",
        test = function()
            return LVS ~= nil or file.Exists("lvs_framework/lvs_framework.lua", "LUA")
        end
    },
    {
        key = "simfphys",
        name = "Simfphys",
        hint = "Vehicle base",
        test = function()
            return simfphys ~= nil or file.Exists("autorun/simfphys_base_functions.lua", "LUA")
        end
    }
}

local cached = {}
local lastScan = 0

local function SafeTest(fn)
    local ok, result = pcall(fn)
    return ok and result == true
end

function MemoNetwork.Addons.Scan(force)
    if not force and CurTime and CurTime() - lastScan < 5 and #cached > 0 then
        return cached
    end

    cached = {}
    for _, data in ipairs(checks) do
        cached[#cached + 1] = {
            key = data.key,
            name = data.name,
            hint = data.hint,
            loaded = SafeTest(data.test)
        }
    end

    lastScan = CurTime and CurTime() or 0
    return cached
end

function MemoNetwork.Addons.GetStatus()
    return MemoNetwork.Addons.Scan(false)
end

function MemoNetwork.Addons.CountLoaded()
    local loaded = 0
    local total = 0
    for _, addon in ipairs(MemoNetwork.Addons.GetStatus()) do
        total = total + 1
        if addon.loaded then loaded = loaded + 1 end
    end
    return loaded, total
end

concommand.Add("mn_addons", function()
    chat.AddText(Color(255,145,0), "[MemoNetwork] ", color_white, "Addon status:")
    for _, addon in ipairs(MemoNetwork.Addons.Scan(true)) do
        chat.AddText(addon.loaded and Color(90,220,120) or Color(255,90,90), addon.loaded and "✓ " or "✗ ", color_white, addon.name, Color(155,165,180), " - " .. addon.hint)
    end
end)
