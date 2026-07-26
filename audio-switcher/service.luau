-- service.luau -- Audio Switcher: poll pactl for sink info

local function parseSinks(text)
    local list = {}
    if not text or text == "" then return list end
    for line in text:gmatch("[^\n]+") do
        local id, name, driver, format = line:match("^(%d+)%s+(%S+)%s+(%S+)%s+(%S+)")
        if id and name then
            table.insert(list, {
                id = tonumber(id),
                name = name,
                driver = driver or "",
            })
        end
    end
    return list
end

local function refresh()
    noctalia.runAsync("pactl list sinks short 2>/dev/null", function(result)
        local sinks = {}
        if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
            sinks = parseSinks(result.stdout)
        end

        noctalia.runAsync("pactl get-default-sink 2>/dev/null", function(defaultResult)
            local defaultSink = ""
            if defaultResult.exitCode == 0 and defaultResult.stdout then
                defaultSink = defaultResult.stdout:gsub("%s+", "")
            end

            noctalia.runAsync("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null", function(volResult)
                local volume = 0
                local muted = false
                if volResult.exitCode == 0 and volResult.stdout then
                    volume = tonumber(volResult.stdout:match("(%d+)%%")) or 0
                end

                noctalia.runAsync("pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null", function(muteResult)
                    if muteResult.exitCode == 0 and muteResult.stdout then
                        muted = muteResult.stdout:match("Mute: yes") ~= nil
                    end

                    local state = {
                        sinks = sinks,
                        default = defaultSink,
                        volume = volume,
                        muted = muted,
                    }
                    noctalia.state.set("audio", noctalia.json.encode(state))
                end)
            end)
        end)
    end)
end

local interval = noctalia.getConfig("refreshInterval") or 5
noctalia.setUpdateInterval(interval * 1000)

function update()
    refresh()
end

refresh()
