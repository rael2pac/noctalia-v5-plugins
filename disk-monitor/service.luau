local disks = {}
local notifiedDisks = {}

local function getNvmeTemp(devName)
    if not devName then return nil end
    local nvmeMatch = devName:match("(nvme%d+)")
    if not nvmeMatch then return nil end
    local path = "/sys/class/nvme/" .. nvmeMatch .. "/device/temp1_input"
    local f = io.open(path, "r")
    if f then
        local raw = f:read("*line")
        f:close()
        if raw then
            local millideg = tonumber(raw)
            if millideg then
                return string.format("%.0f°C", millideg / 1000)
            end
        end
    end
    return nil
end

local function enrichWithTemp(diskList)
    if not diskList then return end
    for _, d in ipairs(diskList) do
        if d.devName and (d.ssd or d.devName:match("nvme")) then
            local temp = getNvmeTemp(d.devName)
            if temp then
                d.temp = temp
            else
                d.temp = nil
            end
        end
    end
end

local function getDiskLabel(d)
    return d.mountpoint or d.devName or "?"
end

local function checkNotifications(diskList)
    local threshold = noctalia.state.get("notificationThreshold") or noctalia.getConfig("notificationThreshold") or 90
    local now = os.time()
    for _, d in ipairs(diskList) do
        local pct = 0
        if d.percent then
            pct = tonumber(d.percent:match("(%d+)")) or 0
        end
        if pct >= threshold then
            local label = getDiskLabel(d)
            local lastNotified = notifiedDisks[label]
            if not lastNotified or (now - lastNotified) > 3600 then
                local msg = d.mountpoint .. " com " .. tostring(pct) .. "% de uso!"
                if d.devName then
                    msg = d.devName .. " (" .. d.mountpoint .. ") - " .. tostring(pct) .. "% de uso!"
                end
                noctalia.log("disk-monitor: " .. msg)
                notifiedDisks[label] = now
            end
        end
    end
end

local function parseLsblk(text)
    local list = {}
    if not text or text == "" then return list end
    local ok, data = pcall(noctalia.json.decode, text)
    if not ok or not data or not data.blockdevices then return list end

    local function addDisk(dev, parentName, parentModel, parentRm)
        if dev.mountpoint and dev.mountpoint ~= "" then
            local diskType = dev.type or "part"
            if diskType ~= "loop" and diskType ~= "ram" and diskType ~= "rom" then
                local isRemovable = dev.rm or parentRm or false
                local model = dev.model or parentModel or ""
                local isSSD = (dev.rota == false) or (dev.rota == 0)
                local isNVMe = (dev.name or ""):match("nvme") ~= nil
                table.insert(list, {
                    name = dev.name,
                    devName = dev.name,
                    size = dev.size or "?",
                    used = dev.fsused or "?",
                    avail = dev.fsavail or "?",
                    fstype = dev.fstype or "?",
                    mountpoint = dev.mountpoint,
                    type = diskType,
                    parent = parentName or dev.name,
                    percent = dev["fsuse%"] or "?",
                    removable = isRemovable,
                    model = model,
                    ssd = isSSD,
                    nvme = isNVMe,
                })
            end
        end
        if dev.children then
            local cModel = dev.model or parentModel or ""
            local cRm = dev.rm or parentRm or false
            for _, child in ipairs(dev.children) do
                addDisk(child, dev.name, cModel, cRm)
            end
        end
    end

    for _, dev in ipairs(data.blockdevices) do
        addDisk(dev, nil, nil, nil)
    end
    return list
end

local function ensureDefaultDisk()
    local current = noctalia.state.get("selectedDisk") or noctalia.getConfig("selectedDisk")
    if not current or current == "" then
        noctalia.state.set("selectedDisk", "/")
    end
end

local function refresh()
    noctalia.runAsync("lsblk -J -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE,FSSIZE,FSUSED,FSAVAIL,FSUSE%,RM,MODEL,ROTA 2>/dev/null", function(result)
        if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
            disks = parseLsblk(result.stdout)
            local showTemp = noctalia.state.get("showTemperature") or noctalia.getConfig("showTemperature")
            if showTemp then
                enrichWithTemp(disks)
            end
            checkNotifications(disks)
        else
            disks = {}
        end

        if #disks == 0 then
            noctalia.runAsync("df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null", function(dfResult)
                if dfResult.exitCode == 0 and dfResult.stdout and dfResult.stdout ~= "" then
                    for line in dfResult.stdout:gmatch("[^\n]+") do
                        if not line:match("^Filesystem") then
                            local dev, size, used, avail, pct, mount = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
                            if dev and mount then
                                table.insert(disks, {
                                    name = dev,
                                    devName = dev,
                                    size = size,
                                    used = used,
                                    avail = avail,
                                    percent = pct,
                                    mountpoint = mount,
                                    fstype = "?",
                                    type = "disk",
                                    parent = dev,
                                    removable = false,
                                    model = "",
                                    ssd = false,
                                    nvme = false,
                                })
                            end
                        end
                    end
                    checkNotifications(disks)
                end
                noctalia.state.set("disks", noctalia.json.encode(disks))
                ensureDefaultDisk()
            end)
        else
            noctalia.state.set("disks", noctalia.json.encode(disks))
            ensureDefaultDisk()
        end
    end)
end

local interval = noctalia.getConfig("refreshInterval") or 30
noctalia.setUpdateInterval(interval * 1000)

function update()
    refresh()
end

refresh()
