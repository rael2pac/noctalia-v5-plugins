-- widget.luau -- Arch Updater: bar widget showing update count

local count = noctalia.state.get("count") or 0
local noctaliaUpdate = noctalia.state.get("noctaliaUpdate") == true
local loaded = true

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

    local hideOnEmpty = noctalia.getConfig("hideOnEmpty")
    if hideOnEmpty == nil then hideOnEmpty = false end

    local boldText = noctalia.getConfig("boldText")
    if boldText == nil then boldText = true end

    local noctaliaHighlight = noctalia.getConfig("noctaliaHighlight")
    if noctaliaHighlight == nil then noctaliaHighlight = true end

    if hideOnEmpty and count == 0 then
        barWidget.setVisible(false)
        return
    end
    barWidget.setVisible(true)

    local glyphColor = "on_surface_variant"
    if count and count > 0 then
        glyphColor = "primary"
    end
    if noctaliaHighlight and noctaliaUpdate then
        glyphColor = "secondary"
    end

    barWidget.render(ui.row({ gap = 5, align = "center" }, {
        ui.glyph({ name = "arrow-big-down-lines", size = 16, color = glyphColor }),
        ui.label({ text = tostring(count or 0), fontSize = 13, fontWeight = boldText and "bold" or "normal", color = "on_surface" }),
    }))

    local tooltip
    if noctaliaUpdate then
        tooltip = tr("tooltip.noctaliaUpdates", "Noctalia Updates available")
    elseif count and count > 0 then
        tooltip = tr("tooltip.availableUpdates", "Available Updates") .. ": " .. tostring(count)
    else
        tooltip = tr("tooltip.noUpdates", "No updates")
    end
    barWidget.setTooltip(tooltip)
end

render()

noctalia.state.watch("count", function(value)
    count = value or 0
    loaded = true
    render()
end)

noctalia.state.watch("noctaliaUpdate", function(value)
    noctaliaUpdate = value == true
    loaded = true
    render()
end)

function onClick()
    noctalia.togglePanel("rael2pac/arch-updater:panel")
end

function onMiddleClick()
    noctalia.state.set("refresh_request", (noctalia.state.get("refresh_request") or 0) + 1)
end
