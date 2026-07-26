-- panel.luau -- Audio Switcher: per-app audio routing

local audioData = nil
local panelOpen = false

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
end

local function getSinkLabel(sink)
    if not sink then return "?" end
    if sink.description then return sink.description end
    return getSinkLabel({name = sink.name})
end

local function getSinkIcon(sink)
    if not sink then return "speakerphone" end
    local n = sink.name or ""
    if n:match("bluez") then return "bluetooth" end
    if n:match("hdmi") then return "device-desktop" end
    if n:match("iec958") then return "cable" end
    return "speakerphone"
end

local function getStreamIcon(appName)
    if not appName then return "app-window" end
    if appName:match("Firefox") then return "brand-firefox" end
    if appName:match("Chromium") or appName:match("Chrome") then return "brand-chrome" end
    if appName:match("Telegram") then return "brand-telegram" end
    if appName:match("Spotify") then return "brand-spotify" end
    if appName:match("mpv") then return "player-play" end
    if appName:match("Discord") then return "brand-discord" end
    return "app-window"
end

local function findSinkById(sinkId)
    if not audioData or not audioData.sinks then return nil end
    for _, s in ipairs(audioData.sinks) do
        if s.id == sinkId then return s end
    end
    return nil
end

local function doMoveSinkInput(streamId, sinkId)
    noctalia.runAsync("pactl move-sink-input " .. tostring(streamId) .. " " .. tostring(sinkId), function()
        noctalia.runAsync("pactl list sink-inputs 2>/dev/null", function(result)
            if result.exitCode == 0 and result.stdout then
                local newStreams = {}
                local currentId, currentSink, currentName = nil, nil, nil
                for line in result.stdout:gmatch("[^\n]*") do
                    local id = line:match("^Sink Input #(%d+)")
                    if id then
                        if currentId and currentName then
                            table.insert(newStreams, { id = currentId, name = currentName, sink = currentSink or 0 })
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
                    table.insert(newStreams, { id = currentId, name = currentName, sink = currentSink or 0 })
                end
                if audioData then audioData.streams = newStreams end
            end
            render()
        end)
    end)
end

-- Explicit route callbacks: stream 1-8, sink 1-5
function onR_1_1() if audioData and audioData.streams[1] and audioData.sinks[1] then doMoveSinkInput(audioData.streams[1].id, audioData.sinks[1].id) end end
function onR_1_2() if audioData and audioData.streams[1] and audioData.sinks[2] then doMoveSinkInput(audioData.streams[1].id, audioData.sinks[2].id) end end
function onR_1_3() if audioData and audioData.streams[1] and audioData.sinks[3] then doMoveSinkInput(audioData.streams[1].id, audioData.sinks[3].id) end end
function onR_1_4() if audioData and audioData.streams[1] and audioData.sinks[4] then doMoveSinkInput(audioData.streams[1].id, audioData.sinks[4].id) end end
function onR_1_5() if audioData and audioData.streams[1] and audioData.sinks[5] then doMoveSinkInput(audioData.streams[1].id, audioData.sinks[5].id) end end

function onR_2_1() if audioData and audioData.streams[2] and audioData.sinks[1] then doMoveSinkInput(audioData.streams[2].id, audioData.sinks[1].id) end end
function onR_2_2() if audioData and audioData.streams[2] and audioData.sinks[2] then doMoveSinkInput(audioData.streams[2].id, audioData.sinks[2].id) end end
function onR_2_3() if audioData and audioData.streams[2] and audioData.sinks[3] then doMoveSinkInput(audioData.streams[2].id, audioData.sinks[3].id) end end
function onR_2_4() if audioData and audioData.streams[2] and audioData.sinks[4] then doMoveSinkInput(audioData.streams[2].id, audioData.sinks[4].id) end end
function onR_2_5() if audioData and audioData.streams[2] and audioData.sinks[5] then doMoveSinkInput(audioData.streams[2].id, audioData.sinks[5].id) end end

function onR_3_1() if audioData and audioData.streams[3] and audioData.sinks[1] then doMoveSinkInput(audioData.streams[3].id, audioData.sinks[1].id) end end
function onR_3_2() if audioData and audioData.streams[3] and audioData.sinks[2] then doMoveSinkInput(audioData.streams[3].id, audioData.sinks[2].id) end end
function onR_3_3() if audioData and audioData.streams[3] and audioData.sinks[3] then doMoveSinkInput(audioData.streams[3].id, audioData.sinks[3].id) end end
function onR_3_4() if audioData and audioData.streams[3] and audioData.sinks[4] then doMoveSinkInput(audioData.streams[3].id, audioData.sinks[4].id) end end
function onR_3_5() if audioData and audioData.streams[3] and audioData.sinks[5] then doMoveSinkInput(audioData.streams[3].id, audioData.sinks[5].id) end end

function onR_4_1() if audioData and audioData.streams[4] and audioData.sinks[1] then doMoveSinkInput(audioData.streams[4].id, audioData.sinks[1].id) end end
function onR_4_2() if audioData and audioData.streams[4] and audioData.sinks[2] then doMoveSinkInput(audioData.streams[4].id, audioData.sinks[2].id) end end
function onR_4_3() if audioData and audioData.streams[4] and audioData.sinks[3] then doMoveSinkInput(audioData.streams[4].id, audioData.sinks[3].id) end end
function onR_4_4() if audioData and audioData.streams[4] and audioData.sinks[4] then doMoveSinkInput(audioData.streams[4].id, audioData.sinks[4].id) end end
function onR_4_5() if audioData and audioData.streams[4] and audioData.sinks[5] then doMoveSinkInput(audioData.streams[4].id, audioData.sinks[5].id) end end

function onR_5_1() if audioData and audioData.streams[5] and audioData.sinks[1] then doMoveSinkInput(audioData.streams[5].id, audioData.sinks[1].id) end end
function onR_5_2() if audioData and audioData.streams[5] and audioData.sinks[2] then doMoveSinkInput(audioData.streams[5].id, audioData.sinks[2].id) end end
function onR_5_3() if audioData and audioData.streams[5] and audioData.sinks[3] then doMoveSinkInput(audioData.streams[5].id, audioData.sinks[3].id) end end
function onR_5_4() if audioData and audioData.streams[5] and audioData.sinks[4] then doMoveSinkInput(audioData.streams[5].id, audioData.sinks[4].id) end end
function onR_5_5() if audioData and audioData.streams[5] and audioData.sinks[5] then doMoveSinkInput(audioData.streams[5].id, audioData.sinks[5].id) end end

function onR_6_1() if audioData and audioData.streams[6] and audioData.sinks[1] then doMoveSinkInput(audioData.streams[6].id, audioData.sinks[1].id) end end
function onR_6_2() if audioData and audioData.streams[6] and audioData.sinks[2] then doMoveSinkInput(audioData.streams[6].id, audioData.sinks[2].id) end end
function onR_6_3() if audioData and audioData.streams[6] and audioData.sinks[3] then doMoveSinkInput(audioData.streams[6].id, audioData.sinks[3].id) end end
function onR_6_4() if audioData and audioData.streams[6] and audioData.sinks[4] then doMoveSinkInput(audioData.streams[6].id, audioData.sinks[4].id) end end
function onR_6_5() if audioData and audioData.streams[6] and audioData.sinks[5] then doMoveSinkInput(audioData.streams[6].id, audioData.sinks[5].id) end end

function render()
    local body = {}

    if not audioData or not audioData.streams or #audioData.streams == 0 then
        table.insert(body, ui.column({ align = "center", justify = "center", flexGrow = 1, padding = 30 }, {
            ui.glyph({ name = "speaker-off", size = 28, color = "secondary" }),
            ui.label({ text = tr("panel.noStreams", "Nenhum audio tocando"), fontSize = 14, color = "on_surface/0.6" }),
        }))
    else
        for i, stream in ipairs(audioData.streams) do
            local currentSink = findSinkById(stream.sink)
            local sinkLabel = currentSink and currentSink.description or "?"
            local sinkIcon = currentSink and getSinkIcon(currentSink) or "speakerphone"
            local appIcon = getStreamIcon(stream.name)

            table.insert(body, ui.column({ gap = 4, paddingH = 8, paddingV = 8, fill = "surface_variant", radius = 8 }, {
                ui.row({ gap = 8, align = "center" }, {
                    ui.glyph({ name = appIcon, size = 18, color = "primary" }),
                    ui.column({ gap = 1, flexGrow = 1 }, {
                        ui.label({ text = stream.name, fontSize = 14, fontWeight = "bold", color = "on_surface" }),
                        ui.row({ gap = 4, align = "center" }, {
                            ui.glyph({ name = sinkIcon, size = 12, color = "on_surface/0.5" }),
                            ui.label({ text = sinkLabel, fontSize = 11, color = "on_surface/0.5" }),
                        }),
                    }),
                }),
            }))

            if audioData.sinks then
                local sinkButtons = {}
                for j, sink in ipairs(audioData.sinks) do
                    if j <= 5 then
                        local isSelected = (stream.sink == sink.id)
                        local variant = isSelected and "default" or "outline"
                        local icon = getSinkIcon(sink)
                        local label = getSinkLabel(sink)
                        local cb = "onR_" .. i .. "_" .. j
                        table.insert(sinkButtons, ui.button({
                            text = label,
                            glyph = icon,
                            variant = variant,
                            controlSize = "sm",
                            onClick = cb,
                        }))
                    end
                end
                table.insert(body, ui.column({ gap = 4, paddingH = 8, paddingV = 2 }, {
                    ui.row({ gap = 4, wrap = true }, sinkButtons),
                }))
            end
        end
    end

    panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 12, fill = "surface", radius = 12 }, {
        ui.row({ gap = 10, align = "center" }, {
            ui.glyph({ name = "speakerphone", size = 18, color = "primary" }),
            ui.label({ text = tr("panel.title", "Audio Switcher"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
            ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }),
        }),

        ui.scroll({ flexGrow = 1, gap = 8 }, body),
    }))
end

function onOpen(_context)
    panelOpen = true
    local raw = noctalia.state.get("audio")
    if raw and raw ~= "" then
        local ok, d = pcall(noctalia.json.decode, raw)
        if ok and d then audioData = d else audioData = nil end
    else
        audioData = nil
    end
    render()
end

function onClose()
    panelOpen = false
    audioData = nil
end

function onCloseClicked()
    panel.close()
end

noctalia.state.watch("audio", function(value)
    if value and value ~= "" then
        local ok, d = pcall(noctalia.json.decode, value)
        if ok and d then audioData = d else audioData = nil end
    else
        audioData = nil
    end
    if panelOpen then render() end
end)
