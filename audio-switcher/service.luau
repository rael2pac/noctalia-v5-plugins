-- service.luau -- Audio Switcher: per-app audio routing

local function parseSinkInputs(text)
    local list = {}
    if not text or text == "" then return list end
    local currentId, currentSink, currentName = nil, nil, nil
    for line in text:gmatch("[^\n]*") do
        local id = line:match("^Sink Input #(%d+)")
        if id then
            if currentId and currentName then
                table.insert(list, {
                    id = currentId,
                    name = currentName,
                    sink = currentSink or 0,
                })
            end
            currentId = tonumber(id)
            currentName = nil
            currentSink = nil
        end
        local snk = line:match("^%s+Sink: (%d+)")
        if snk and currentId then currentSink = tonumber(snk) end
        local app = line:match('application.name = "(.+)"')
        if app and currentId then currentName = app end
    end
    if currentId and currentName then
        table.insert(list, {
            id = currentId,
            name = currentName,
            sink = currentSink or 0,
        })
    end
    return list
end

local function parseSinksFiltered(text)
    local list = {}
    if not text or text == "" then return list end
    local currentId, currentName, currentDesc = nil, nil, nil
    for line in text:gmatch("[^\n]*") do
        local id = line:match("^Sink #(%d+)")
        if id then
            if currentId and currentName then
                table.insert(list, {
                    id = tonumber(currentId),
                    name = currentName,
                    description = currentDesc or currentName,
                })
            end
            currentId = id
            currentName = nil
            currentDesc = nil
        end
        local n = line:match("^%s+Name: (.+)")
        if n and currentId then currentName = n:gsub("%s+", "") end
        local d = line:match("^%s+Description: (.+)")
        if d and currentId then currentDesc = d end
    end
    if currentId and currentName then
        table.insert(list, {
            id = tonumber(currentId),
            name = currentName,
            description = currentDesc or currentName,
        })
    end
    return list
end

local function refresh()
    noctalia.runAsync("pactl list sink-inputs 2>/dev/null", function(inputResult)
        local streams = {}
        if inputResult.exitCode == 0 and inputResult.stdout and inputResult.stdout ~= "" then
            streams = parseSinkInputs(inputResult.stdout)
        end

        noctalia.runAsync("pactl list sinks 2>/dev/null | grep -E '^(Sink #[0-9]|\\tName:|\\tDescription:)'", function(sinkResult)
            local sinks = {}
            if sinkResult.exitCode == 0 and sinkResult.stdout and sinkResult.stdout ~= "" then
                sinks = parseSinksFiltered(sinkResult.stdout)
            end

            noctalia.runAsync("pactl get-default-sink 2>/dev/null", function(defaultResult)
                local defaultSink = ""
                if defaultResult.exitCode == 0 and defaultResult.stdout then
                    defaultSink = defaultResult.stdout:gsub("%s+", "")
                end

                local state = {
                    streams = streams,
                    sinks = sinks,
                    default = defaultSink,
                }
                noctalia.state.set("audio", noctalia.json.encode(state))
            end)
        end)
    end)
end

local interval = noctalia.getConfig("refreshInterval") or 3
noctalia.setUpdateInterval(interval * 1000)

function update()
    refresh()
end

refresh()
