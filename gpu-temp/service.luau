-- service.luau -- GPU Temperature: reads amdgpu hwmon sensor periodically

local gpuTemp = nil
local sensorPath = nil
local detecting = false

local function publishState()
    noctalia.state.set("gpu_temp", gpuTemp)
    noctalia.state.set("gpu_temp_available", gpuTemp ~= nil)
end

local function readTemp()
    if not sensorPath then return end
    noctalia.runAsync("cat " .. sensorPath, function(result)
        if result.exitCode == 0 and result.stdout then
            local raw = tonumber(string.match(result.stdout, "%d+"))
            if raw and raw > 0 then
                gpuTemp = math.floor(raw / 1000 + 0.5)
            else
                gpuTemp = nil
            end
        else
            gpuTemp = nil
            sensorPath = nil
        end
        publishState()
    end)
end

local function detectSensor()
    if detecting then return end
    detecting = true

    local customPath = noctalia.getConfig("sensorPath")
    if customPath and customPath ~= "" then
        sensorPath = customPath
        detecting = false
        readTemp()
        return
    end

    local cmd = 'for h in /sys/class/hwmon/hwmon*; do '
        .. 'name="$(cat "$h/name" 2>/dev/null)"; '
        .. 'if [ "$name" = "amdgpu" ]; then '
        .. 'for f in "$h"/temp*_input; do '
        .. '[ -f "$f" ] && echo "$f" && exit 0; '
        .. 'done; fi; done'

    noctalia.runAsync(cmd, function(result)
        detecting = false
        if result.exitCode == 0 and result.stdout then
            local path = string.match(result.stdout, "[^\n]+")
            if path then
                sensorPath = path
                readTemp()
                return
            end
        end
        sensorPath = nil
        gpuTemp = nil
        publishState()
    end)
end

function update()
    if sensorPath then
        readTemp()
    else
        detectSensor()
    end
end

function onConfigChanged()
    sensorPath = nil
    gpuTemp = nil
    publishState()
    detectSensor()
end

noctalia.setUpdateInterval(5000)
detectSensor()
