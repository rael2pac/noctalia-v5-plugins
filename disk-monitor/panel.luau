-- panel.luau -- Monitor de Discos: painel detalhado

local disks = {}
local panelOpen = false

local function tr(key, fallback)
    local v = noctalia.tr(key)
    if v == nil or v == key then return fallback or key end
    return v
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

local function getBarWidth(pct)
    local filled = math.floor(pct / 5)
    if filled > 20 then filled = 20 end
    if filled < 0 then filled = 0 end
    local empty = 20 - filled
    return string.rep("█", filled) .. string.rep("░", empty)
end

local function getTypeIcon(dtype)
    if dtype == "disk" then return "hard-drive"
    elseif dtype == "part" then return "square"
    elseif dtype == "lvm" then return "layers"
    else return "circle" end
end

local function formatSize(str)
    if not str or str == "?" then return "?" end
    return str
end

function render()
    local body = {}

    if #disks == 0 then
        table.insert(body, ui.column({ align = "center", justify = "center", flexGrow = 1, padding = 30 }, {
            ui.glyph({ name = "hard-drive", size = 28, color = "secondary" }),
            ui.label({ text = tr("panel.noDisks", "Nenhum disco detectado"), fontSize = 14, color = "on_surface/0.6" }),
        }))
    else
        table.insert(body, ui.row({ gap = 10, align = "center", paddingH = 8, paddingV = 4 }, {
            ui.label({ text = tr("panel.device", "Dispositivo"), fontSize = 12, fontWeight = "bold", color = "on_surface_variant", flexGrow = 1 }),
            ui.label({ text = tr("panel.total", "Total"), fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
            ui.label({ text = tr("panel.used", "Usado"), fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
            ui.label({ text = tr("panel.free", "Livre"), fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
            ui.label({ text = tr("panel.usage", "Uso"), fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
        }))

        for _, d in ipairs(disks) do
            local pct = getPercentUsed(d)
            local color = getPercentColor(pct)
            local bar = getBarWidth(pct)
            local icon = getTypeIcon(d.type)

            local sizeText = d.size or "?"
            local usedText = d.used or "?"
            local freeText = d.avail or "?"

            table.insert(body, ui.column({ gap = 2, paddingH = 8, paddingV = 4 }, {
                ui.row({ gap = 10, align = "center" }, {
                    ui.glyph({ name = icon, size = 14, color = color }),
                    ui.label({ text = d.mountpoint, fontSize = 13, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
                    ui.label({ text = sizeText, fontSize = 12, color = "on_surface_variant" }),
                    ui.label({ text = usedText, fontSize = 12, color = "#ef4444" }),
                    ui.label({ text = freeText, fontSize = 12, color = "#22c55e" }),
                    ui.label({ text = tostring(pct) .. "%", fontSize = 12, fontWeight = "bold", color = color }),
                }),
                ui.row({ gap = 4, align = "center" }, {
                    ui.label({ text = "  " .. bar, fontFamily = "monospace", fontSize = 11, color = color }),
                    ui.label({ text = "  " .. d.devName .. " (" .. (d.fstype or "?") .. ") - " .. (d.type or "?"), fontSize = 10, color = "on_surface/0.5" }),
                }),
            }))
        end
    end

    panel.render(ui.column({ flexGrow = 1, gap = 4, padding = 12, fill = "surface", radius = 12 }, {
        ui.row({ gap = 10, align = "center" }, {
            ui.glyph({ name = "hard-drive", size = 18, color = "primary" }),
            ui.label({ text = tr("panel.title", "Monitor de Discos"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
            ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }),
        }),

        ui.scroll({ flexGrow = 1, gap = 4 }, body),
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
