-- panel.luau -- Audio Switcher: per-app audio routing panel

local audioData = nil
local panelOpen = false

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
end

local function getSinkDisplayName(sinkName)
    if not sinkName then return "?" end
    local name = sinkName
    name = name:gsub("alsa_output%.", "")
    name = name:gsub("bluez_output%.", "")
    name = name:gsub("%.analog%-stereo$", "")
    name = name:gsub("%.hdmi%-stereo.*$", " HDMI")
    name = name:gsub("%.iec958%-stereo$", " Digital")
    name = name:gsub("%-00$", "")
    name = name:gsub("_", " ")
    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")
    return name
end

local function getSinkIcon(sinkName)
    if not sinkName then return "speakerphone" end
    if sinkName:match("bluez") then return "bluetooth" end
    if sinkName:match("hdmi") then return "device-desktop" end
    return "speakerphone"
end

local function findSinkName(sinkId)
    if not audioData or not audioData.sinks then return "?" end
    for _, s in ipairs(audioData.sinks) do
        if s.id == sinkId then
            return getSinkDisplayName(s.name)
        end
    end
    return "?"
end

local function findSinkIcon(sinkId)
    if not audioData or not audioData.sinks then return "speakerphone" end
    for _, s in ipairs(audioData.sinks) do
        if s.id == sinkId then
            return getSinkIcon(s.name)
        end
    end
    return "speakerphone"
end

-- Stream routing callbacks
function route1_1() routeStream(1, 1) end
function route1_2() routeStream(1, 2) end
function route1_3() routeStream(1, 3) end
function route1_4() routeStream(1, 4) end
function route1_5() routeStream(1, 5) end

function route2_1() routeStream(2, 1) end
function route2_2() routeStream(2, 2) end
function route2_3() routeStream(2, 3) end
function route2_4() routeStream(2, 4) end
function route2_5() routeStream(2, 5) end

function route3_1() routeStream(3, 1) end
function route3_2() routeStream(3, 2) end
function route3_3() routeStream(3, 3) end
function route3_4() routeStream(3, 4) end
function route3_5() routeStream(3, 5) end

function route4_1() routeStream(4, 1) end
function route4_2() routeStream(4, 2) end
function route4_3() routeStream(4, 3) end
function route4_4() routeStream(4, 4) end
function route4_5() routeStream(4, 5) end

function route5_1() routeStream(5, 1) end
function route5_2() routeStream(5, 2) end
function route5_3() routeStream(5, 3) end
function route5_4() routeStream(5, 4) end
function route5_5() routeStream(5, 5) end

function routeStream(streamIdx, sinkIdx)
    if not audioData then return end
    local stream = audioData.streams[streamIdx]
    local sink = audioData.sinks[sinkIdx]
    if not stream or not sink then return end
    noctalia.runAsync("pactl move-sink-input " .. tostring(stream.id) .. " " .. tostring(sink.id) .. " 2>/dev/null", function()
        stream.sink = sink.id
        render()
    end)
end

function render()
    local body = {}

    if not audioData or not audioData.streams or #audioData.streams == 0 then
        table.insert(body, ui.column({ align = "center", justify = "center", flexGrow = 1, padding = 30 }, {
            ui.glyph({ name = "speaker-off", size = 28, color = "secondary" }),
            ui.label({ text = tr("panel.noStreams", "Nenhum audio tocando"), fontSize = 14, color = "on_surface/0.6" }),
        }))
    else
        for i, stream in ipairs(audioData.streams) do
            local sinkName = findSinkName(stream.sink)
            local sinkIcon = findSinkIcon(stream.sink)

            table.insert(body, ui.column({ gap = 3, paddingH = 8, paddingV = 4, fill = "surface_variant", radius = 8 }, {
                ui.row({ gap = 8, align = "center" }, {
                    ui.glyph({ name = "app-window", size = 14, color = "primary" }),
                    ui.label({ text = stream.name, fontSize = 14, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
                    ui.glyph({ name = "arrow-right", size = 12, color = "on_surface/0.4" }),
                    ui.glyph({ name = sinkIcon, size = 14, color = "on_surface" }),
                    ui.label({ text = sinkName, fontSize = 12, color = "on_surface/0.7" }),
                }),
            }))

            local sinkButtons = {}
            for j, sink in ipairs(audioData.sinks) do
                local isSelected = (stream.sink == sink.id)
                local variant = isSelected and "default" or "outline"
                local icon = getSinkIcon(sink.name)
                local label = getSinkDisplayName(sink.name)
                local cb = "route" .. i .. "_" .. j
                table.insert(sinkButtons, ui.button({
                    text = label,
                    glyph = icon,
                    variant = variant,
                    controlSize = "sm",
                    onClick = cb,
                }))
            end
            table.insert(body, ui.row({ gap = 4, wrap = true, paddingH = 8, paddingV = 2 }, sinkButtons))
        end
    end

    panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 12, fill = "surface", radius = 12 }, {
        ui.row({ gap = 10, align = "center" }, {
            ui.glyph({ name = "peaker", size = 18, color = "primary" }),
            ui.label({ text = tr("panel.title", "Audio Switcher"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
            ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }),
        }),

        ui.scroll({ flexGrow = 1, gap = 6 }, body),
    }))
end

function onOpen(_context)
    panelOpen = true
    local raw = noctalia.state.get("audio")
    if raw and raw ~= "" then
        local d = noctalia.json.decode(raw)
        if d then audioData = d else audioData = nil end
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
        local d = noctalia.json.decode(value)
        if d then audioData = d else audioData = nil end
    else
        audioData = nil
    end
    if panelOpen then render() end
end)
