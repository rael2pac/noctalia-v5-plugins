-- panel.luau -- Audio Switcher: per-app audio routing

local audioData = nil
local panelOpen = false
local routeCallbacks = {}

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
end

local function getSinkDisplayName(sinkName)
    if not sinkName then return "?" end
    if sinkName:match("bluez") then
        return "Bluetooth"
    end
    if sinkName:match("hdmi") then
        return "HDMI"
    end
    if sinkName:match("iec958") then
        return "Digital"
    end
    if sinkName:match("Corsair") or sinkName:match("corsair") or sinkName:match("USB") then
        return "Corsair HS55"
    end
    local name = sinkName
    name = name:gsub("alsa_output%.", "")
    name = name:gsub("bluez_output%.", "")
    name = name:gsub("%.analog%-stereo$", "")
    name = name:gsub("%.hdmi%-stereo.*$", "")
    name = name:gsub("%.iec958%-stereo$", "")
    name = name:gsub("%-00$", "")
    name = name:gsub("_", " ")
    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")
    if name == "" then return "Audio" end
    return name
end

local function getSinkIcon(sinkName)
    if not sinkName then return "speakerphone" end
    if sinkName:match("bluez") then return "bluetooth" end
    if sinkName:match("hdmi") then return "device-desktop" end
    if sinkName:match("iec958") then return "cable" end
    return "speakerphone"
end

local function getStreamIcon(appName)
    if not appName then return "app-window" end
    if appName:match("Firefox") then return "brand-firefox" end
    if appName:match("Chromium") or appName:match("Chrome") then return "brand-chrome" end
    if appName:match("Telegram") then return "brand-telegram" end
    if appName:match("Spotify") then return "brand-spotify" end
    return "app-window"
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

local function routeStream(streamIdx, sinkIdx)
    if not audioData or not audioData.streams or not audioData.sinks then return end
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
    routeCallbacks = {}

    if not audioData or not audioData.streams or #audioData.streams == 0 then
        table.insert(body, ui.column({ align = "center", justify = "center", flexGrow = 1, padding = 30 }, {
            ui.glyph({ name = "speaker-off", size = 28, color = "secondary" }),
            ui.label({ text = tr("panel.noStreams", "Nenhum audio tocando"), fontSize = 14, color = "on_surface/0.6" }),
        }))
    else
        for i, stream in ipairs(audioData.streams) do
            local sinkName = findSinkName(stream.sink)
            local sinkIcon = findSinkIcon(stream.sink)
            local appIcon = getStreamIcon(stream.name)

            table.insert(body, ui.column({ gap = 3, paddingH = 8, paddingV = 6, fill = "surface_variant", radius = 8 }, {
                ui.row({ gap = 8, align = "center" }, {
                    ui.glyph({ name = appIcon, size = 16, color = "primary" }),
                    ui.label({ text = stream.name, fontSize = 14, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
                    ui.glyph({ name = "arrow-right", size = 12, color = "on_surface/0.4" }),
                    ui.glyph({ name = sinkIcon, size = 14, color = "on_surface" }),
                    ui.label({ text = sinkName, fontSize = 12, color = "on_surface/0.7" }),
                }),
            }))

            if audioData.sinks then
                local sinkButtons = {}
                for j, sink in ipairs(audioData.sinks) do
                    local isSelected = (stream.sink == sink.id)
                    local variant = isSelected and "default" or "outline"
                    local icon = getSinkIcon(sink.name)
                    local label = getSinkDisplayName(sink.name)
                    local cbKey = "route_" .. i .. "_" .. j
                    routeCallbacks[cbKey] = { streamIdx = i, sinkIdx = j }
                    table.insert(sinkButtons, ui.button({
                        text = label,
                        glyph = icon,
                        variant = variant,
                        controlSize = "sm",
                        onClick = cbKey,
                    }))
                end
                table.insert(body, ui.row({ gap = 4, wrap = true, paddingH = 8, paddingV = 2 }, sinkButtons))
            end
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

function onRouteClick(key)
    local cb = routeCallbacks[key]
    if cb then
        routeStream(cb.streamIdx, cb.sinkIdx)
    end
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
    routeCallbacks = {}
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
