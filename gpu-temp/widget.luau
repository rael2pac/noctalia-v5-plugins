-- widget.luau -- GPU Temperature: bar widget showing GPU temp with icon

local gpuTemp = nil
local available = false

local function render()
    if not available or gpuTemp == nil then
        barWidget.setVisible(false)
        return
    end

    barWidget.setVisible(true)

    local warnTemp = noctalia.getConfig("warnTemp") or 80
    local critTemp = noctalia.getConfig("critTemp") or 90

    local color = "on_surface"
    if gpuTemp >= critTemp then
        color = "error"
    elseif gpuTemp >= warnTemp then
        color = "warning"
    end

    barWidget.render(ui.row({ gap = 4, align = "center" }, {
        ui.glyph({ name = "thermometer", size = 16, color = color }),
        ui.label({ text = gpuTemp .. "°C", fontSize = 12, color = "on_surface" }),
    }))
end

noctalia.state.watch("gpu_temp", function(value)
    gpuTemp = value
    render()
end)

noctalia.state.watch("gpu_temp_available", function(value)
    available = value == true
    render()
end)
