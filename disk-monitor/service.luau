-- service.luau -- Monitor de Discos: poll lsblk for disk info

local disks = {}

local function parseLsblk(text)
    local list = {}
    if not text or text == "" then return list end
    local ok, data = pcall(noctalia.json.decode, text)
    if not ok or not data or not data.blockdevices then return list end

    local function addDisk(dev, parentName)
        if dev.mountpoint and dev.mountpoint ~= "" then
            local diskType = dev.type or "part"
            if diskType ~= "loop" and diskType ~= "ram" and diskType ~= "rom" then
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
                })
            end
        end
        if dev.children then
            for _, child in ipairs(dev.children) do
                addDisk(child, dev.name)
            end
        end
    end

    for _, dev in ipairs(data.blockdevices) do
        addDisk(dev, nil)
    end
    return list
end

local function refresh()
    noctalia.runAsync("lsblk -J -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE,FSSIZE,FSUSED,FSAVAIL,FSUSE% 2>/dev/null", function(result)
        if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
            disks = parseLsblk(result.stdout)
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
                                })
                            end
                        end
                    end
                end
                noctalia.state.set("disks", noctalia.json.encode(disks))
            end)
        else
            noctalia.state.set("disks", noctalia.json.encode(disks))
        end
    end)
end

local interval = noctalia.getConfig("refreshInterval") or 30
noctalia.setUpdateInterval(interval * 1000)

function update()
    refresh()
end

refresh()
