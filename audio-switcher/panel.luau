-- panel.luau -- Audio Switcher: painel para trocar saida de audio

local audioState = nil
local panelOpen = false

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
end

local function getDisplayName(sinkName)
    if not sinkName then return "?" end
    local name = sinkName
    name = name:gsub("alsa_output%.", "")
    name = name:gsub("bluez_output%.", "BT: ")
    name = name:gsub("%.analog%-stereo$", "")
    name = name:gsub("%.hdmi%-stereo.*$", " (HDMI)")
    name = name:gsub("%.iec958%-stereo$", " (Digital)")
    name = name:gsub("%-00$", "")
    name = name:gsub("_", " ")
    return name
end

local function getSinkIcon(sinkName)
    if not sinkName then return "speakerphone" end
    if sinkName:match("bluez") then return "bluetooth" end
    if sinkName:match("hdmi") then return "device-desktop" end
    if sinkName:match("iec958") then return "cable" end
    return "speakerphone"
end

local function getVolumeIcon(muted, volume)
    if muted then return "volume-3" end
    if volume >= 66 then return "volume"
    elseif volume >= 33 then return "volume-2"
    else return "volume-1" end
end

function onSelect1() switchSink(1) end
function onSelect2() switchSink(2) end
function onSelect3() switchSink(3) end
function onSelect4() switchSink(4) end
function onSelect5() switchSink(5) end

function switchSink(idx)
    if not audioState or not audioState.sinks then return end
    local sink = audioState.sinks[idx]
    if not sink then return end
    noctalia.runAsync("pactl set-default-sink " .. tostring(sink.id) .. " 2>/dev/null", function()
        noctalia.runAsync("pactl set-default-sink " .. tostring(sink.id), function() end)
    end)
    if audioState then
        audioState.default = sink.name
    end
    render()
end

function onToggleMute()
    noctalia.runAsync("pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null", function(result)
        if audioState then
            audioState.muted = not audioState.muted
        end
        render()
    end)
end

function onVolumeUp10()
    noctalia.runAsync("pactl set-sink-volume @DEFAULT_SINK@ +10% 2>/dev/null", function()
        updateVolume()
    end)
end

function onVolumeDown10()
    noctalia.runAsync("pactl set-sink-volume @DEFAULT_SINK@ -10% 2>/dev/null", function()
        updateVolume()
    end)
end

function updateVolume()
    noctalia.runAsync("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null", function(result)
        if result.exitCode == 0 and result.stdout then
            local volume = tonumber(result.stdout:match("(%d+)%%")) or 0
            if audioState then
                audioState.volume = volume
            end
            render()
        end
    end)
end

function render()
    local body = {}

    if not audioState or not audioState.sinks or #audioState.sinks == 0 then
        table.insert(body, ui.column({ align = "center", justify = "center", flexGrow = 1, padding = 30 }, {
            ui.glyph({ name = "volume-3", size = 28, color = "secondary" }),
            ui.label({ text = tr("panel.noSinks", "Nenhuma saida de audio encontrada"), fontSize = 14, color = "on_surface/0.6" }),
        }))
    else
        table.insert(body, ui.label({ text = tr("panel.selectSink", "Saida de audio:"), fontSize = 12, fontWeight = "bold", color = "primary", paddingH = 8 }))

        for i, sink in ipairs(audioState.sinks) do
            local isSelected = (sink.name == audioState.default)
            local variant = isSelected and "default" or "outline"
            local icon = getSinkIcon(sink.name)
            local label = getDisplayName(sink.name)
            local cb = "onSelect" .. i

            table.insert(body, ui.column({ gap = 2, paddingH = 8, paddingV = 4, fill = "surface_variant", radius = 8 }, {
                ui.row({ gap = 8, align = "center" }, {
                    ui.button({ glyph = icon, variant = variant, controlSize = "sm", onClick = cb }),
                    ui.label({ text = label, fontSize = 13, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
                    ui.label({ text = sink.driver, fontSize = 10, color = "on_surface/0.4" }),
                }),
            }))
        end
    end

    local volIcon = getVolumeIcon(audioState and audioState.muted, audioState and audioState.volume or 0)
    local volText = tostring(audioState and audioState.volume or 0) .. "%"

    table.insert(body, ui.column({ gap = 4, paddingH = 8, paddingV = 6, fill = "surface_variant", radius = 8 }, {
        ui.label({ text = tr("panel.volume", "Volume"), fontSize = 12, fontWeight = "bold", color = "primary" }),
        ui.row({ gap = 8, align = "center" }, {
            ui.button({ glyph = "minus", variant = "outline", controlSize = "sm", onClick = "onVolumeDown10" }),
            ui.glyph({ name = volIcon, size = 18, color = "on_surface" }),
            ui.label({ text = volText, fontSize = 14, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
            ui.button({ glyph = "plus", variant = "outline", controlSize = "sm", onClick = "onVolumeUp10" }),
            ui.button({ glyph = audioState and audioState.muted and "volume-3" or "volume", variant = audioState and audioState.muted and "default" or "outline", controlSize = "sm", onClick = "onToggleMute" }),
        }),
    }))

    panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 12, fill = "surface", radius = 12 }, {
        ui.row({ gap = 10, align = "center" }, {
            ui.glyph({ name = "volume", size = 18, color = "primary" }),
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
        if d then audioState = d else audioState = nil end
    else
        audioState = nil
    end
    render()
end

function onClose()
    panelOpen = false
    audioState = nil
end

function onCloseClicked()
    panel.close()
end

noctalia.state.watch("audio", function(value)
    if value and value ~= "" then
        local d = noctalia.json.decode(value)
        if d then audioState = d else audioState = nil end
    else
        audioState = nil
    end
    if panelOpen then render() end
end)
