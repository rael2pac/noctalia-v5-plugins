-- widget.luau -- Audio Switcher: bar widget

local audioState = nil
local loaded = false

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

local function getVolumeIcon(muted, volume)
    if muted then return "volume-3" end
    if volume >= 66 then return "volume"
    elseif volume >= 33 then return "volume-2"
    else return "volume-1" end
end

local function render()
    if not loaded or not audioState then
        barWidget.setVisible(false)
        return
    end

    barWidget.setVisible(true)

    local showPercent = noctalia.getConfig("showPercent")
    if showPercent == nil then showPercent = true end

    local icon = getVolumeIcon(audioState.muted, audioState.volume)
    local label = ""
    if showPercent then
        label = tostring(audioState.volume) .. "%"
    end

    barWidget.render(ui.row({ gap = 5, align = "center" }, {
        ui.glyph({ name = icon, size = 16, color = "on_surface" }),
        ui.label({ text = label, fontSize = 13, fontWeight = "bold", color = "on_surface" }),
    }))

    local displayName = getDisplayName(audioState.default)
    barWidget.setTooltip(tr("widget.tooltip", "Saida: ") .. displayName .. " (" .. tostring(audioState.volume) .. "%)")
end

noctalia.state.watch("audio", function(value)
    if value and value ~= "" then
        local d = noctalia.json.decode(value)
        if d then audioState = d else audioState = nil end
    else
        audioState = nil
    end
    loaded = true
    render()
end)

function onClick()
    noctalia.togglePanel("rael2pac/audio-switcher:panel")
end

function onScrollUp()
    noctalia.runAsync("pactl set-sink-volume @DEFAULT_SINK@ +5%", function() refresh() end)
end

function onScrollDown()
    noctalia.runAsync("pactl set-sink-volume @DEFAULT_SINK@ -5%", function() refresh() end)
end

function refresh()
    noctalia.runAsync("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null", function(result)
        if result.exitCode == 0 and result.stdout then
            local volume = tonumber(result.stdout:match("(%d+)%%")) or 0
            if audioState then
                audioState.volume = volume
                render()
            end
        end
    end)
end

render()
