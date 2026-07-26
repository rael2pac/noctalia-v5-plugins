-- widget.luau -- Monitor de Discos: bar widget

local diskData = {}
local loaded = false

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
end

local function findDisk(mountpoint)
    for _, d in ipairs(diskData) do
        if d.mountpoint == mountpoint then
            return d
        end
    end
    return nil
end

local function formatSize(str)
    if not str or str == "?" then return "?" end
    return str
end

local function parseBytes(str)
    if not str or str == "?" then return 0 end
    local num, unit = str:match("^([%d%.]+)(.+)$")
    if not num then return 0 end
    num = tonumber(num)
    if not num then return 0 end
    unit = unit:upper()
    if unit == "T" or unit == "TB" then return num * 1024 * 1024 * 1024 * 1024
    elseif unit == "G" or unit == "GB" then return num * 1024 * 1024 * 1024
    elseif unit == "M" or unit == "MB" then return num * 1024 * 1024
    elseif unit == "K" or unit == "KB" then return num * 1024
    else return num end
end

local function getPercentUsed(disk)
    if disk.percent then
        return tonumber(disk.percent:match("(%d+)")) or 0
    end
    local totalBytes = parseBytes(disk.size)
    local usedBytes = parseBytes(disk.used)
    if totalBytes == 0 then return 0 end
    return math.floor((usedBytes / totalBytes) * 100)
end

local function getPercentColor(pct)
    if pct >= 80 then return "#ef4444"
    elseif pct >= 60 then return "#facc15"
    else return "#22c55e" end
end

local function render()
    if not loaded then
        barWidget.setVisible(false)
        return
    end

    local hideOnEmpty = noctalia.getConfig("hideOnEmpty")
    if hideOnEmpty == nil then hideOnEmpty = false end

    local displayDisk = noctalia.getConfig("displayDisk") or "/"
    local displayFormat = noctalia.getConfig("displayFormat") or "name_free"

    local disk = findDisk(displayDisk)

    if not disk then
        if hideOnEmpty then
            barWidget.setVisible(false)
        else
            barWidget.setVisible(true)
            barWidget.render(ui.row({ gap = 5, align = "center" }, {
                ui.glyph({ name = "hard-drive", size = 16, color = "on_surface_variant" }),
                ui.label({ text = tr("widget.noDisk", "Sem dados"), fontSize = 13, color = "on_surface/0.6" }),
            }))
        end
        return
    end

    barWidget.setVisible(true)

    local pct = getPercentUsed(disk)
    local color = getPercentColor(pct)

    local text = ""
    if displayFormat == "name_free" then
        text = disk.mountpoint .. " " .. formatSize(disk.avail) .. " livres"
    elseif displayFormat == "free_only" then
        text = formatSize(disk.avail)
    elseif displayFormat == "percent" then
        text = tostring(pct) .. "%"
    elseif displayFormat == "name_percent" then
        text = disk.mountpoint .. " " .. tostring(pct) .. "%"
    else
        text = disk.mountpoint .. " " .. formatSize(disk.avail) .. " livres"
    end

    barWidget.render(ui.row({ gap = 5, align = "center" }, {
        ui.glyph({ name = "hard-drive", size = 16, color = color }),
        ui.label({ text = text, fontSize = 13, fontWeight = "bold", color = "on_surface" }),
    }))

    barWidget.setTooltip(disk.devName .. " (" .. disk.fstype .. ") - " .. formatSize(disk.used) .. " / " .. formatSize(disk.size))
end

noctalia.state.watch("disks", function(value)
    if value and value ~= "" then
        local d = noctalia.json.decode(value)
        if d then diskData = d else diskData = {} end
    else
        diskData = {}
    end
    loaded = true
    render()
end)

function onClick()
    noctalia.togglePanel("rael2pac/disk-monitor:panel")
end

render()
