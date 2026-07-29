local disks = {}
local panelOpen = false

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
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

local function getPercentColor(pct)
    if pct >= 85 then return "#ef4444"
    elseif pct >= 60 then return "#facc15"
    else return "#22c55e" end
end

local function getBarWidth(pct)
    local filled = math.floor(pct / 5)
    if filled > 20 then filled = 20 end
    if filled < 0 then filled = 0 end
    local empty = 20 - filled
    return string.rep("█", filled) .. string.rep("░", empty)
end

local function getDiskIcon(disk)
    if disk.nvme then return "chip" end
    return "database"
end

local function stripSlash(mp)
    if not mp then return "?" end
    if mp == "/" then return "/" end
    return mp:gsub("^/", "")
end

local function formatSize(disk)
    local used = parseBytes(disk.used)
    local total = parseBytes(disk.size)
    if total == 0 then return (disk.used or "?") .. " / " .. (disk.size or "?") end
    local usedGB = used / (1024 * 1024 * 1024)
    local totalGB = total / (1024 * 1024 * 1024)
    if totalGB >= 1 then
        return string.format("%.1f / %.1f GB", usedGB, totalGB)
    else
        return (disk.used or "?") .. " / " .. (disk.size or "?")
    end
end

local formats = { "free_total", "free_only", "name_free", "percent", "name_percent" }
local formatLabels = { free_total = "Nome + Livre/Total", free_only = "So Livre", name_free = "Nome + Livre", percent = "Percentual", name_percent = "Nome + %" }

function onSelect1() setDisk(1) end
function onSelect2() setDisk(2) end
function onSelect3() setDisk(3) end
function onSelect4() setDisk(4) end
function onSelect5() setDisk(5) end
function onSelect6() setDisk(6) end
function onSelect7() setDisk(7) end
function onSelect8() setDisk(8) end

function setDisk(idx)
    local d = disks[idx]
    if not d then return end
    noctalia.state.set("selectedDisk", d.mountpoint)
    render()
end

function onCycleFormat()
    local current = noctalia.state.get("displayFormat") or noctalia.getConfig("displayFormat") or "free_total"
    local nextIdx = 1
    for i, f in ipairs(formats) do
        if f == current then
            nextIdx = (i % #formats) + 1
            break
        end
    end
    noctalia.state.set("displayFormat", formats[nextIdx])
    render()
end

function onToggleHideEmpty()
    local current = noctalia.state.get("hideOnEmpty")
    if current == nil then
        current = noctalia.getConfig("hideOnEmpty")
    end
    if current == nil then current = false end
    noctalia.state.set("hideOnEmpty", not current)
    render()
end

function onToggleShowAll()
    local current = noctalia.state.get("showAllDisks")
    if current == nil then
        current = noctalia.getConfig("showAllDisks")
    end
    if current == nil then current = false end
    noctalia.state.set("showAllDisks", not current)
    render()
end

function onToggleTemp()
    local current = noctalia.state.get("showTemperature")
    if current == nil then
        current = noctalia.getConfig("showTemperature")
    end
    if current == nil then current = false end
    noctalia.state.set("showTemperature", not current)
    render()
end

function onToggleColorMode()
    local current = noctalia.state.get("barColorMode") or noctalia.getConfig("barColorMode") or "none"
    if current == "none" then
        noctalia.state.set("barColorMode", "by_usage")
    else
        noctalia.state.set("barColorMode", "none")
    end
    render()
end

function render()
    local body = {}
    local currentDisplay = noctalia.state.get("selectedDisk") or noctalia.getConfig("selectedDisk") or "/"

    if #disks == 0 then
        table.insert(body, ui.column({ align = "center", justify = "center", flexGrow = 1, padding = 30 }, {
            ui.glyph({ name = "database", size = 28, color = "secondary" }),
            ui.label({ text = tr("panel.noDisks", "Nenhum disco detectado"), fontSize = 14, color = "on_surface/0.6" }),
        }))
    else
        for i, d in ipairs(disks) do
            local pct = getPercentUsed(d)
            local color = getPercentColor(pct)
            local bar = getBarWidth(pct)
            local icon = getDiskIcon(d)
            local label = stripSlash(d.mountpoint)
            local isSelected = (d.mountpoint == currentDisplay)
            local variant = isSelected and "default" or "outline"

            local tagLabel = ""
            if d.nvme then tagLabel = "NVMe"
            elseif d.ssd then tagLabel = "SSD"
            end
            if d.removable then
                if tagLabel ~= "" then tagLabel = tagLabel .. " " end
                tagLabel = tagLabel .. "USB"
            end

            local modelStr = ""
            if d.model and d.model ~= "" then
                modelStr = d.model
            end

            local tempStr = ""
            local showTemp = noctalia.state.get("showTemperature") or noctalia.getConfig("showTemperature")
            if showTemp then
                tempStr = d.temp or tr("panel.na", "N/D")
            end

            local cb = "onSelect" .. i

            local infoRow = { ui.label({ text = label, fontSize = 14, fontWeight = "bold", color = "on_surface" }) }
            if tagLabel ~= "" then
                table.insert(infoRow, ui.label({ text = tagLabel, fontSize = 11, color = color }))
            end
            if tempStr ~= "" then
                table.insert(infoRow, ui.label({ text = " " .. tempStr, fontSize = 11, color = "tertiary" }))
            end

            table.insert(body, ui.column({ gap = 3, paddingH = 8, paddingV = 6, fill = "surface_variant", radius = 8 }, {
                ui.row({ gap = 8, align = "center" }, {
                    ui.button({ glyph = icon, variant = variant, controlSize = "sm", onClick = cb }),
                    ui.column({ gap = 1, flexGrow = 1 }, {
                        ui.row({ gap = 6, align = "center" }, infoRow),
                        ui.label({ text = modelStr, fontSize = 10, color = "on_surface/0.5" }),
                    }),
                    ui.label({ text = tostring(pct) .. "%", fontSize = 14, fontWeight = "bold", color = color }),
                }),
                ui.row({ gap = 6, align = "center" }, {
                    ui.label({ text = bar, fontFamily = "monospace", fontSize = 11, color = color }),
                    ui.label({ text = formatSize(d), fontSize = 11, color = "on_surface/0.7" }),
                }),
                ui.row({ gap = 4, align = "center" }, {
                    ui.label({ text = d.devName, fontSize = 10, color = "on_surface/0.4" }),
                    ui.label({ text = (d.fstype or "?"), fontSize = 10, color = "on_surface/0.4" }),
                }),
            }))
        end
    end

    local currentFormat = noctalia.state.get("displayFormat") or noctalia.getConfig("displayFormat") or "free_total"
    local hideEmpty = noctalia.state.get("hideOnEmpty")
    if hideEmpty == nil then hideEmpty = noctalia.getConfig("hideOnEmpty") end
    if hideEmpty == nil then hideEmpty = false end

    local showAll = noctalia.state.get("showAllDisks")
    if showAll == nil then showAll = noctalia.getConfig("showAllDisks") end
    if showAll == nil then showAll = false end

    local showTemp = noctalia.state.get("showTemperature")
    if showTemp == nil then showTemp = noctalia.getConfig("showTemperature") end
    if showTemp == nil then showTemp = false end

    local colorMode = noctalia.state.get("barColorMode") or noctalia.getConfig("barColorMode") or "none"

    table.insert(body, ui.column({ gap = 6, paddingH = 8, paddingV = 8, fill = "surface_variant", radius = 8 }, {
        ui.row({ gap = 6, align = "center" }, {
            ui.glyph({ name = "settings", size = 14, color = "primary" }),
            ui.label({ text = tr("panel.config", "Configuracoes"), fontSize = 13, fontWeight = "bold", color = "primary", flexGrow = 1 }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.label({ text = tr("panel.format", "Formato:"), fontSize = 11, color = "on_surface/0.7", flexGrow = 1 }),
            ui.button({ text = formatLabels[currentFormat] or currentFormat, variant = "outline", controlSize = "sm", onClick = "onCycleFormat" }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.label({ text = tr("panel.hideEmpty", "Ocultar vazio:"), fontSize = 11, color = "on_surface/0.7", flexGrow = 1 }),
            ui.button({ text = hideEmpty and "Sim" or "Nao", variant = hideEmpty and "default" or "outline", controlSize = "sm", onClick = "onToggleHideEmpty" }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.label({ text = "Cor por uso:", fontSize = 11, color = "on_surface/0.7", flexGrow = 1 }),
            ui.button({ text = colorMode == "by_usage" and "Sim" or "Nao", variant = colorMode == "by_usage" and "default" or "outline", controlSize = "sm", onClick = "onToggleColorMode" }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.label({ text = "Temp. NVMe:", fontSize = 11, color = "on_surface/0.7", flexGrow = 1 }),
            ui.button({ text = showTemp and "Sim" or "Nao", variant = showTemp and "default" or "outline", controlSize = "sm", onClick = "onToggleTemp" }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.label({ text = "Todos discos:", fontSize = 11, color = "on_surface/0.7", flexGrow = 1 }),
            ui.button({ text = showAll and "Sim" or "Nao", variant = showAll and "default" or "outline", controlSize = "sm", onClick = "onToggleShowAll" }),
        }),
    }))

    panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 12, fill = "surface", radius = 12 }, {
        ui.row({ gap = 10, align = "center" }, {
            ui.glyph({ name = "settings", size = 18, color = "primary" }),
            ui.label({ text = tr("panel.title", "Monitor de Discos"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
            ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }),
        }),
        ui.scroll({ flexGrow = 1, gap = 6 }, body),
    }))
end

function onOpen(_context)
    panelOpen = true
    local raw = noctalia.state.get("disks")
    if raw and raw ~= "" then
        local d = noctalia.json.decode(raw)
        if d then disks = d else disks = {} end
    else
        disks = {}
    end
    render()
end

function onClose()
    panelOpen = false
    disks = {}
end

function onCloseClicked()
    panel.close()
end

noctalia.state.watch("disks", function(value)
    if value and value ~= "" then
        local d = noctalia.json.decode(value)
        if d then disks = d else disks = {} end
    else
        disks = {}
    end
    if panelOpen then render() end
end)
