-- MemoNetwork Alpha 16 Server Metrics
-- Client-side metric history for widgets/graphs in F6 and future panels.

MemoNetwork = MemoNetwork or {}
MemoNetwork.Metrics = MemoNetwork.Metrics or {}

local history = {
    fps = {},
    entities = {},
    memory = {},
    players = {}
}

local maxSamples = 42
local nextSample = 0

local function Push(key, value)
    history[key] = history[key] or {}
    table.insert(history[key], value)
    while #history[key] > maxSamples do
        table.remove(history[key], 1)
    end
end

hook.Add("Think", "MemoNetwork_MetricsSampler", function()
    if CurTime() < nextSample then return end
    nextSample = CurTime() + 1

    Push("fps", math.Clamp(math.floor(1 / FrameTime()), 0, 300))
    Push("entities", #ents.GetAll())
    Push("memory", math.floor(collectgarbage("count") / 1024))
    Push("players", #player.GetAll())
end)

function MemoNetwork.Metrics.Get(key)
    return history[key] or {}
end

function MemoNetwork.Metrics.Latest(key, fallback)
    local values = history[key] or {}
    return values[#values] or fallback or 0
end

function MemoNetwork.Metrics.Max(key, fallback)
    local values = history[key] or {}
    local max = fallback or 1
    for _, value in ipairs(values) do
        if value > max then max = value end
    end
    return max
end
