-- widget.luau -- Audio Switcher: bar widget - just an icon to open panel

local streamCount = 0
local loaded = false

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
end

local function render()
    if not loaded then
        barWidget.setVisible(false)
        return
    end

    barWidget.setVisible(true)

    local label = ""
    if streamCount > 0 then
        label = tostring(streamCount)
    end

    barWidget.render(ui.row({ gap = 5, align = "center" }, {
        ui.glyph({ name = "peaker", size = 16, color = "on_surface" }),
        ui.label({ text = label, fontSize = 13, fontWeight = "bold", color = "on_surface" }),
    }))

    barWidget.setTooltip(tr("widget.tooltip", "Roteamento de audio"))
end

noctalia.state.watch("audio", function(value)
    if value and value ~= "" then
        local d = noctalia.json.decode(value)
        if d and d.streams then
            streamCount = #d.streams
        else
            streamCount = 0
        end
    else
        streamCount = 0
    end
    loaded = true
    render()
end)

function onClick()
    noctalia.togglePanel("rael2pac/audio-switcher:panel")
end

render()
