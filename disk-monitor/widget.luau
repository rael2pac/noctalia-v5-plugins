local diskData = {}
local loaded = false
local currentIndex = 1

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
    if disk.removable then
        local name = (disk.devName or ""):lower()
        if name:match("sd") and not name:match("nvme") then
            return "device-sd-card"
        end
        return "device-usb"
    end
    if disk.ssd then return "database" end
    return "hard-drive"
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
    if pct >= 85 then return "#ef4444"
    elseif pct >= 60 then return "#facc15"
    else return "#22c55e" end
end

local function render()
    if not loaded then
        barWidget.setVisible(false)
        return
    end

    local hideOnEmpty = noctalia.state.get("hideOnEmpty")
    if hideOnEmpty == nil then hideOnEmpty = noctalia.getConfig("hideOnEmpty") end
    if hideOnEmpty == nil then hideOnEmpty = false end

    local showAll = noctalia.state.get("showAllDisks")
    if showAll == nil then showAll = noctalia.getConfig("showAllDisks") end
    if showAll == nil then showAll = false end

    local colorMode = noctalia.state.get("barColorMode") or noctalia.getConfig("barColorMode") or "none"

    local displayDisk = nil

    if showAll and #diskData > 0 then
        if currentIndex > #diskData then currentIndex = 1 end
        displayDisk = diskData[currentIndex]
    else
        local selected = noctalia.state.get("selectedDisk") or noctalia.getConfig("selectedDisk") or "/"
        displayDisk = findDisk(selected)
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
    local textColor = "on_surface"
    if colorMode == "by_usage" then
        textColor = getPercentColor(pct)
    end

    local function stripSlash(mp)
        if not mp then return "?" end
        if mp == "/" then return "/" end
        return mp:gsub("^/", "")
    end

    local mountLabel = stripSlash(displayDisk.mountpoint)
    local availTxt = displayDisk.avail or "?"

    local displayFormat = noctalia.state.get("displayFormat") or noctalia.getConfig("displayFormat") or "name_free"

    local text = ""
    if displayFormat == "name_free" then
        text = mountLabel .. " " .. availTxt
    elseif displayFormat == "free_only" then
        text = availTxt
    elseif displayFormat == "percent" then
        text = mountLabel .. " " .. tostring(pct) .. "%"
    elseif displayFormat == "name_percent" then
        text = mountLabel .. " " .. tostring(pct) .. "%"
    else
        text = mountLabel .. " " .. availTxt
    end

    local label = text
    if showAll then
        label = "[" .. tostring(currentIndex) .. "/" .. tostring(#diskData) .. "] " .. availTxt
    end

    barWidget.render(ui.row({ gap = 5, align = "center" }, {
        ui.glyph({ name = icon, size = 16, color = textColor }),
        ui.label({ text = label, fontSize = 13, fontWeight = "bold", color = textColor }),
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

noctalia.state.watch("displayFormat", function(_value)
    render()
end)

noctalia.state.watch("hideOnEmpty", function(_value)
    render()
end)

noctalia.state.watch("showAllDisks", function(_value)
    render()
end)

noctalia.state.watch("barColorMode", function(_value)
    render()
end)

noctalia.state.watch("showTemperature", function(_value)
    render()
end)

function onClick()
    local showAll = noctalia.state.get("showAllDisks")
    if showAll == nil then showAll = noctalia.getConfig("showAllDisks") end
    if showAll and #diskData > 0 then
        currentIndex = currentIndex + 1
        if currentIndex > #diskData then currentIndex = 1 end
        render()
    else
        noctalia.togglePanel("rael2pac/disk-monitor:panel")
    end
end

render()
