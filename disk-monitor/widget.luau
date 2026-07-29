local diskData = {}
local loaded = false
local function findDisk(mountpoint)
    for _, d in ipairs(diskData) do
        if d.mountpoint == mountpoint then
            return d
        end
    end
    return nil
end

local function getDiskIcon(disk)
    if disk.nvme then return "chip" end
    return "database"
end

local function parseBytes(str)
    if not str or str == "?" then return 0 end
    local normalized = str:gsub(",", ".")
    local num, unit = normalized:match("^([%d%.]+)(.+)$")
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

local function render()
    if not loaded then
        barWidget.setVisible(false)
        return
    end

    local hideOnEmpty = noctalia.state.get("hideOnEmpty")
    if hideOnEmpty == nil then hideOnEmpty = noctalia.getConfig("hideOnEmpty") end
    if hideOnEmpty == nil then hideOnEmpty = false end

    local displayDisk = nil

    local selected = noctalia.state.get("selectedDisk") or noctalia.getConfig("selectedDisk") or "/"
    displayDisk = findDisk(selected)
    if not displayDisk and #diskData > 0 then
        displayDisk = diskData[1]
    end

    if not displayDisk then
        if hideOnEmpty then
            barWidget.setVisible(false)
        else
            barWidget.setVisible(true)
            barWidget.render(ui.row({ gap = 5, align = "center" }, {
                ui.glyph({ name = "database", size = 16, color = "on_surface_variant" }),
                ui.label({ text = "Sem dados", fontSize = 13, color = "on_surface/0.6" }),
            }))
        end
        return
    end

    barWidget.setVisible(true)

    local pct = getPercentUsed(displayDisk)
    local icon = getDiskIcon(displayDisk)

    local function stripSlash(mp)
        if not mp then return "?" end
        if mp == "/" then return "/" end
        return mp:gsub("^/", "")
    end

    local mountLabel = stripSlash(displayDisk.mountpoint)

    local availBytes = parseBytes(displayDisk.avail)
    local availGB = availBytes / (1024 * 1024 * 1024)
    local availTxt = ""
    if availGB >= 1 then
        availTxt = string.format("%.1f", availGB):gsub("%.", ",")
    else
        availTxt = (displayDisk.avail or "0"):gsub("[,]?[GTMKMk]?[Bb]?$", "")
    end

    local barLen = 6
    local filled = math.floor(pct / (100 / barLen))
    if filled > barLen then filled = barLen end
    if filled < 0 then filled = 0 end
    local empty = barLen - filled
    local bar = string.rep("█", filled) .. string.rep("░", empty)

    local color = "#22c55e"
    if pct >= 85 then
        color = "#ef4444"
    elseif pct >= 60 then
        color = "#facc15"
    end

    barWidget.render(ui.row({ gap = 3, align = "center" }, {
        ui.glyph({ name = icon, size = 12, color = "on_surface" }),
        ui.label({ text = mountLabel, fontSize = 11, fontWeight = "bold", color = "on_surface" }),
        ui.label({ text = bar, fontFamily = "monospace", fontSize = 10, color = color }),
        ui.label({ text = availTxt, fontSize = 11, fontWeight = "bold", color = color }),
    }))

    local tooltip = displayDisk.devName .. " (" .. (displayDisk.fstype or "?") .. ") - " .. (displayDisk.used or "?") .. " / " .. (displayDisk.size or "?") .. " (" .. tostring(pct) .. "%)"
    if displayDisk.model and displayDisk.model ~= "" then
        tooltip = displayDisk.model .. " | " .. tooltip
    end
    local showTemp = noctalia.state.get("showTemperature") or noctalia.getConfig("showTemperature")
    if showTemp and displayDisk.temp then
        tooltip = tooltip .. " | Temp: " .. displayDisk.temp
    end
    barWidget.setTooltip(tooltip)
end

local function loadExistingState()
    local raw = noctalia.state.get("disks")
    if raw and raw ~= "" then
        local d = noctalia.json.decode(raw)
        if d and #d > 0 then
            diskData = d
            loaded = true
        end
    end
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

loadExistingState()

noctalia.state.watch("selectedDisk", function(_value)
    render()
end)

noctalia.state.watch("hideOnEmpty", function(_value)
    render()
end)

noctalia.state.watch("showTemperature", function(_value)
    render()
end)

function onClick()
    noctalia.togglePanel("rael2pac/disk-monitor:panel")
end

render()
