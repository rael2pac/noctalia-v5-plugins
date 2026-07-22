-- service.luau -- Arch Updater: background service that checks for system / AUR / Flatpak updates

local state = {
    updates = {},
    systemStr = "",
    aurStr = "",
    flatpakStr = "",
    noctaliaUpdate = false,
    count = 0,
    lastRefreshTime = "",
}

local noctaliaNames = { "noctalia-qs", "noctalia-shell" }
local pendingToast = false

local function publishState()
    noctalia.state.set("updates_raw", noctalia.json.encode(state.updates))
    noctalia.state.set("count", state.count)
    noctalia.state.set("systemStr", state.systemStr)
    noctalia.state.set("aurStr", state.aurStr)
    noctalia.state.set("flatpakStr", state.flatpakStr)
    noctalia.state.set("noctaliaUpdate", state.noctaliaUpdate)
    noctalia.state.set("lastRefreshTime", state.lastRefreshTime)
end

local function checkNoctalia(str)
    local detect = noctalia.getConfig("noctaliaDetection")
    if detect == nil then detect = true end
    if detect then
        for _, name in ipairs(noctaliaNames) do
            if string.find(str, name, 1, true) then
                state.noctaliaUpdate = true
                return
            end
        end
    end
    state.noctaliaUpdate = false
end

local function parseUpdates(output, source)
    local updates = {}
    if not output or output == "" then return updates end
    for line in string.gmatch(output, "[^\n]+") do
        local parts = {}
        for word in string.gmatch(line, "%S+") do
            table.insert(parts, word)
        end
        if #parts >= 4 then
            local id = parts[1]
            local name = id
            local repo = ""
            if source == "system" then
                local slash = string.find(id, "/", 1, true)
                if slash then
                    repo = string.sub(id, 1, slash - 1)
                    name = string.sub(id, slash + 1)
                end
            else
                repo = source
            end
            table.insert(updates, {
                id = id,
                name = name,
                repo = repo,
                oldVer = parts[2],
                newVer = parts[4],
                source = source,
            })
        end
    end
    return updates
end

local function joinNames(updates)
    local names = {}
    for _, u in ipairs(updates) do
        table.insert(names, u.name)
    end
    return table.concat(names, "\n")
end

local function checkFlatpak()
    local cmd = "flatpak update --no-deploy --noninteractive >/dev/null 2>&1; "
        .. "join -t'\\t' -j1 "
        .. "<(flatpak remote-ls --updates --columns=application,name,version 2>/dev/null | sort -t'\\t' -k1,1) "
        .. "<(flatpak list --columns=application,version 2>/dev/null | sort -t'\\t' -k1,1)"
    noctalia.runAsync(cmd, function(result)
        if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
            local flatpakUpdates = {}
            for line in string.gmatch(result.stdout, "[^\n]+") do
                local parts = {}
                for field in string.gmatch(line, "[^\t]+") do
                    table.insert(parts, field)
                end
                if #parts >= 4 then
                    table.insert(flatpakUpdates, {
                        id = parts[1],
                        name = parts[2],
                        repo = "flatpak",
                        oldVer = parts[4],
                        newVer = parts[3],
                        source = "flatpak",
                    })
                end
            end
            for _, u in ipairs(flatpakUpdates) do
                table.insert(state.updates, u)
            end
            state.flatpakStr = joinNames(flatpakUpdates)
        else
            state.flatpakStr = ""
        end
        state.count = #state.updates

        local now = os.date("*t")
        state.lastRefreshTime = string.format("%02d:%02d:%02d", now.hour, now.min, now.sec)
        publishState()

        if pendingToast then
            pendingToast = false
            local total = state.count
            noctalia.notify("Arch Updater", tostring(total) .. " " .. (noctalia.tr("toast.updatesAvailable") or "updates available"))
        end
    end)
end

local function checkAUR()
    local cmd = noctalia.getConfig("aurCmd") or "yay -Qua 2>/dev/null"
    noctalia.runAsync(cmd, function(result)
        if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
            local aurUpdates = parseUpdates(result.stdout, "aur")
            for _, u in ipairs(aurUpdates) do
                table.insert(state.updates, u)
            end
            state.aurStr = joinNames(aurUpdates)
        else
            state.aurStr = ""
        end
        checkNoctalia(state.systemStr .. "\n" .. state.aurStr)

        local flatpakEnabled = noctalia.getConfig("flatpakEnabled")
        if flatpakEnabled == nil then flatpakEnabled = true end
        if flatpakEnabled then
            checkFlatpak()
        else
            state.flatpakStr = ""
            state.count = #state.updates
            local now = os.date("*t")
            state.lastRefreshTime = string.format("%02d:%02d:%02d", now.hour, now.min, now.sec)
            publishState()

            if pendingToast then
                pendingToast = false
                local total = state.count
                noctalia.notify("Arch Updater", tostring(total) .. " " .. (noctalia.tr("toast.updatesAvailable") or "updates available"))
            end
        end
    end)
end

local function checkSystem()
    local cmd = noctalia.getConfig("systemCmd") or "checkupdates 2>/dev/null"
    noctalia.runAsync(cmd, function(result)
        if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
            state.updates = parseUpdates(result.stdout, "system")
            state.systemStr = joinNames(state.updates)
        else
            state.updates = {}
            state.systemStr = ""
        end
        checkAUR()
    end)
end

local function refresh(showToast)
    state.updates = {}
    state.systemStr = ""
    state.aurStr = ""
    state.flatpakStr = ""
    state.noctaliaUpdate = false

    pendingToast = (showToast == true)
    if pendingToast then
        noctalia.notify("Arch Updater", noctalia.tr("toast.refreshing"))
    end
    checkSystem()
end

local function doUpdate()
    noctalia.runInTerminal(
        'R="\\033[0;31m" G="\\033[0;32m" Y="\\033[1;33m" C="\\033[0;36m" B="\\033[1;34m" N="\\033[0m"\n'
        .. 'echo -e "${B}📦 ATUALIZANDO O SISTEMA${N}"\n'
        .. 'echo "=========================================="\n'
        .. 'yay -Syu --noconfirm 2>&1\n'
        .. 'echo\n'
        .. 'echo -e "${C}-> Flatpaks${N}"\n'
        .. 'flatpak update -y 2>&1 || echo "Flatpak nao encontrado"\n'
        .. 'echo\n'
        .. 'echo -e "${Y}🏁 CONCLUIDO${N}"\n'
        .. 'echo "=========================================="\n'
        .. 'sleep 3\n'
    )

    local cleanupEnabled = noctalia.getConfig("cleanupAfterUpdate")
    if cleanupEnabled then
        local preserveList = noctalia.getConfig("cachePreserveList") or ""
        local excludes = ""
        if preserveList ~= "" then
            local parts = {}
            for name in string.gmatch(preserveList, "%S+") do
                table.insert(parts, '! -name "' .. name .. '"')
            end
            excludes = table.concat(parts, " ")
        end

        local cleanupCmd = 'paccache -r -k 3 2>/dev/null\n'
            .. 'yay -Sc --noconfirm 2>/dev/null\n'
            .. 'yay -Yc --noconfirm 2>/dev/null\n'
            .. 'orphans=$(pacman -Qdtq 2>/dev/null)\n'
            .. '[ -n "$orphans" ] && sudo pacman -Rns $orphans --noconfirm 2>/dev/null || true\n'
            .. 'flatpak uninstall --unused --delete-data -y 2>/dev/null || true\n'
            .. 'journalctl --vacuum-time=7d 2>/dev/null\n'
        if excludes ~= "" then
            cleanupCmd = cleanupCmd
                .. 'set -f; find "$HOME/.cache" -mindepth 1 -maxdepth 1 '
                .. excludes .. ' -exec rm -rf {} + 2>/dev/null || true\n'
        end

        noctalia.runInTerminal(
            'echo -e "\\033[1;33m🧹 LIMPEZA DO SISTEMA\\033[0m"\n'
            .. 'echo "=========================================="\n'
            .. cleanupCmd .. '\n'
            .. 'echo "\\033[0;32m✔ Limpeza concluida\\033[0m"\n'
            .. 'sleep 3\n'
        )
    end

    refresh(false)
end

noctalia.setUpdateInterval(60000)
refresh(false)

noctalia.state.watch("refresh_request", function(value)
    if value and value > 0 then
        refresh(true)
    end
end)

noctalia.state.watch("update_request", function(value)
    if value and value > 0 then
        doUpdate()
    end
end)

function update()
    refresh(false)
end

function onConfigChanged()
    refresh(false)
end

function onIpc(event, payload)
    if event == "refresh" then
        refresh(true)
    elseif event == "update" then
        doUpdate()
    else
        noctalia.log("noctaliav5: unknown IPC event: " .. event)
    end
end
