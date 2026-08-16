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

local noctaliaNames = { "noctalia", "noctalia-git", "noctalia-qs", "noctalia-shell" }

local previousIds = {}
local baselineSet = false
local refreshInFlight = false
local refreshQueued = false
local updating = false
local updatingTicks = 0

local markerPath
do
    local dir = noctalia.pluginDataDir()
    if dir then
        markerPath = dir .. "/update-done"
    else
        markerPath = "/tmp/noctalia-arch-updater-done"
    end
end
if noctalia.fileExists(markerPath) then
    noctalia.removeFile(markerPath)
end

local refresh

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

local function snapshotIds(updates)
    local ids = {}
    for _, u in ipairs(updates) do
        ids[u.source .. ":" .. u.id] = true
    end
    return ids
end

local function buildPackageList(updates)
    local lines = {}
    for _, u in ipairs(updates) do
        local prefix = ""
        if u.repo and u.repo ~= "" then prefix = u.repo .. "/" end
        table.insert(lines, prefix .. u.name .. "  " .. u.oldVer .. " -> " .. u.newVer)
    end
    return table.concat(lines, "\n")
end

local function shellEscape(s)
    if not s then return "" end
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, '"', '\\"')
    return s
end

local function countLines(s)
    if not s or s == "" then return 0 end
    local n = 0
    for _ in string.gmatch(s, "[^\n]+") do n = n + 1 end
    return n
end

local function truncateLines(s, maxLines)
    if not s then return "" end
    local lines = {}
    for line in string.gmatch(s, "[^\n]+") do
        table.insert(lines, line)
        if #lines >= maxLines then break end
    end
    return table.concat(lines, "\n")
end

local function sendSystemNotify(summary, body)
    local useSystem = noctalia.getConfig("notifySystem")
    if useSystem == nil then useSystem = true end

    if not useSystem then
        noctalia.notify("Arch Updater", summary .. "\n" .. (body or ""))
        return
    end

    local icon = noctalia.getConfig("notifyIcon")
    if icon == nil or icon == "" then icon = "system-software-update" end

    local bodyText = truncateLines(body or "", 12)
    local total = countLines(body)
    if total > 12 then
        local more = noctalia.trp("toast.more", total - 12)
        if more == nil or more == "toast.more" then more = "+ " .. tostring(total - 12) .. " more" end
        bodyText = bodyText .. "\n" .. more
    end

    local cmd = 'notify-send -a "Arch Updater" -i "' .. shellEscape(icon) .. '" -u normal "'
        .. shellEscape(summary) .. '" "' .. shellEscape(bodyText) .. '"'
    noctalia.runAsync(cmd)
end

local function resetState()
    state.updates = {}
    state.systemStr = ""
    state.aurStr = ""
    state.flatpakStr = ""
    state.noctaliaUpdate = false
    state.count = 0
    publishState()
end

local function finalizeRefresh(prev, showToast)
    local newUpdates = {}
    for _, u in ipairs(state.updates) do
        if not prev[u.source .. ":" .. u.id] then
            table.insert(newUpdates, u)
        end
    end

    previousIds = snapshotIds(state.updates)
    state.count = #state.updates
    local now = os.date("*t")
    state.lastRefreshTime = string.format("%02d:%02d:%02d", now.hour, now.min, now.sec)
    publishState()

    local showToasts = noctalia.getConfig("showToasts")
    if showToasts == nil then showToasts = true end

    if not baselineSet then
        baselineSet = true
        if showToast and showToasts and state.count > 0 then
            sendSystemNotify(tostring(state.count) .. " " .. (noctalia.tr("toast.updatesAvailable") or "updates available"), buildPackageList(state.updates))
        end
    elseif #newUpdates > 0 then
        local soundEnabled = noctalia.getConfig("soundEnabled")
        if soundEnabled == nil then soundEnabled = true end
        if soundEnabled then
            local soundPath = noctalia.getConfig("soundPath")
            local cmd
            if soundPath and soundPath ~= "" then
                cmd = "paplay \"" .. soundPath .. "\""
            else
                cmd = "canberra-gtk-play -i complete-download"
            end
            noctalia.runAsync(cmd)
        end
        if showToasts then
            local summary = noctalia.trp("toast.newUpdates", #newUpdates)
            sendSystemNotify(summary, buildPackageList(newUpdates))
        end
    elseif showToast and showToasts then
        noctalia.notify("Arch Updater", noctalia.tr("toast.noNewUpdates"))
    end

    refreshInFlight = false
    if refreshQueued then
        refreshQueued = false
        refresh(true)
    end
end

local function checkFlatpak(prev, showToast)
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
        finalizeRefresh(prev, showToast)
    end)
end

local function checkAUR(prev, showToast)
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
            checkFlatpak(prev, showToast)
        else
            state.flatpakStr = ""
            finalizeRefresh(prev, showToast)
        end
    end)
end

local function checkSystem(prev, showToast)
    local cmd = noctalia.getConfig("systemCmd") or "checkupdates 2>/dev/null"
    noctalia.runAsync(cmd, function(result)
        if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
            state.updates = parseUpdates(result.stdout, "system")
            state.systemStr = joinNames(state.updates)
        else
            state.updates = {}
            state.systemStr = ""
        end
        checkAUR(prev, showToast)
    end)
end

function refresh(showToast)
    if updating then
        return
    end
    if refreshInFlight then
        if showToast then refreshQueued = true end
        return
    end
    refreshInFlight = true
    refreshQueued = false

    local prev = previousIds
    state.updates = {}
    state.systemStr = ""
    state.aurStr = ""
    state.flatpakStr = ""
    state.noctaliaUpdate = false

    publishState()

    if showToast then
        local showToasts = noctalia.getConfig("showToasts")
        if showToasts == nil then showToasts = true end
        if showToasts then
            noctalia.notify("Arch Updater", noctalia.tr("toast.refreshing"))
        end
    end

    checkSystem(prev, showToast)
end

local function doUpdate()
    local preserveList = noctalia.getConfig("cachePreserveList") or ""
    local excludes = ""
    if preserveList ~= "" then
        local parts = {}
        for name in string.gmatch(preserveList, "%S+") do
            table.insert(parts, '! -name ' .. name)
        end
        excludes = table.concat(parts, " ")
    end
    excludes = excludes .. ' ! -name ksycoca6_*'

    local script = 'R="\\033[0;31m" G="\\033[0;32m" Y="\\033[1;33m" C="\\033[0;36m" B="\\033[1;34m" N="\\033[0m"\n'
        .. 're_pkg="^([^ ]+)[[:space:]]([^ ]+)[[:space:]]->[[:space:]]([^ ]+)$"\n'
        .. '\n'
        .. 'echo -e "${B}📦 ATUALIZANDO O SISTEMA${N}"\n'
        .. 'echo "=========================================="\n'
        .. '\n'
        .. 'PACMAN_PRE=$(checkupdates 2>/dev/null || true)\n'
        .. 'AUR_PRE=$(yay -Qua 2>/dev/null || true)\n'
        .. '\n'
        .. 'echo -e "${Y}-> INICIANDO AS ATUALIZAÇÕES${N}"\n'
        .. 'yay -Syu --noconfirm 2>&1\n'
        .. 'echo\n'
        .. '\n'
        .. 'echo -e "${C}-> Flatpaks${N}"\n'
        .. 'flatpak update -y 2>&1 || echo "Flatpak nao encontrado, pulando..."\n'
        .. 'echo\n'

    script = script
        .. 'echo -e "${Y}🧹 LIMPEZA DO SISTEMA${N}"\n'
        .. 'echo "=========================================="\n'
        .. '\n'
        .. 'echo -e "${Y}• Cache pacman (paccache -k 3)...${N}"\n'
        .. 'PAC_LOG=$(sudo paccache -r -k 3 2>&1)\n'
        .. 'echo "$PAC_LOG"\n'
        .. 'echo\n'
        .. '\n'
        .. 'echo -e "${Y}• Cache AUR (yay -Sc)...${N}"\n'
        .. 'AUR_LOG=$(yes | yay -Sc 2>&1)\n'
        .. 'echo "$AUR_LOG" | grep -v "^$" | tail -20\n'
        .. 'echo\n'
        .. '\n'
        .. 'echo -e "${Y}• Builds AUR nao usados (yay -Yc)...${N}"\n'
        .. 'BUILD_LOG=$(yes | yay -Yc 2>&1)\n'
        .. 'echo "$BUILD_LOG" | grep -v "^$" | tail -20\n'
        .. 'echo\n'
        .. '\n'
        .. 'echo -e "${Y}• Orfaos...${N}"\n'
        .. 'ORPHAN_LIST=$(pacman -Qdtq 2>/dev/null)\n'
        .. 'if [ -n "$ORPHAN_LIST" ]; then\n'
        .. '    echo "$ORPHAN_LIST"\n'
        .. '    ORPHAN_LOG=$(sudo pacman -Rns $ORPHAN_LIST --noconfirm 2>&1)\n'
        .. '    echo "$ORPHAN_LOG"\n'
        .. 'else\n'
        .. '    ORPHAN_LOG="Nenhum pacote orfao encontrado"\n'
        .. '    echo "$ORPHAN_LOG"\n'
        .. 'fi\n'
        .. 'echo\n'
        .. '\n'
        .. 'echo -e "${Y}• Flatpaks nao usados...${N}"\n'
        .. 'FLATPAK_LOG=$(flatpak uninstall --unused --delete-data -y 2>&1 || echo "Flatpak nao encontrado, pulando...")\n'
        .. 'echo "$FLATPAK_LOG"\n'
        .. 'echo\n'
        .. '\n'
        .. 'echo -e "${Y}• Logs (journalctl 7d)...${N}"\n'
        .. 'JOURNAL_LOG=$(sudo journalctl --vacuum-time=7d 2>&1)\n'
        .. 'echo "$JOURNAL_LOG"\n'
        .. 'echo\n'
        .. '\n'
        .. 'echo -e "${Y}• Cache do usuario...${N}"\n'
        .. 'EXCLUDE_DIRS="' .. excludes .. '"\n'
        .. 'CACHE_ITEMS=$(find ~/.cache -mindepth 1 -maxdepth 1 $EXCLUDE_DIRS -exec du -sh {} + 2>/dev/null | sort -rh)\n'
        .. 'USER_CACHE_BEFORE=$(du -sh ~/.cache 2>/dev/null | cut -f1)\n'
        .. 'if [ -n "$CACHE_ITEMS" ]; then\n'
        .. '    echo "Itens removidos:"\n'
        .. '    echo "$CACHE_ITEMS"\n'
        .. '    echo ""\n'
        .. 'fi\n'
        .. 'find ~/.cache -mindepth 1 -maxdepth 1 $EXCLUDE_DIRS -exec rm -rf {} + 2>/dev/null || true\n'
        .. 'USER_CACHE_AFTER=$(du -sh ~/.cache 2>/dev/null | cut -f1)\n'
        .. 'echo "Tamanho: $USER_CACHE_BEFORE → $USER_CACHE_AFTER"\n'
        .. 'echo\n'

    script = script
        .. 'echo "=========================================="\n'
        .. 'echo -e "${G}✅ Sistema atualizado com sucesso!${N}"\n'
        .. 'echo "=========================================="\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo "========================================="\n'
        .. 'echo -e "${C}📋 LOG DE PACOTES ATUALIZADOS${N}"\n'
        .. 'echo "========================================="\n'
        .. 'if [ -n "$PACMAN_PRE" ]; then\n'
        .. '    echo -e "${Y}--- Pacman ---${N}"\n'
        .. '    echo "$PACMAN_PRE" | while IFS= read -r line; do\n'
        .. '        if [[ "$line" =~ $re_pkg ]]; then\n'
        .. '            echo -e "${C}${BASH_REMATCH[1]}${N} ${R}${BASH_REMATCH[2]}${N} ${Y}->${N} ${G}${BASH_REMATCH[3]}${N}"\n'
        .. '        else\n'
        .. '            echo "$line"\n'
        .. '        fi\n'
        .. '    done\n'
        .. 'else\n'
        .. '    echo -e "${Y}Nenhuma atualizacao pendente${N} (Pacman)"\n'
        .. 'fi\n'
        .. 'if [ -n "$AUR_PRE" ]; then\n'
        .. '    echo ""\n'
        .. '    echo -e "${M}--- AUR ---${N}"\n'
        .. '    echo "$AUR_PRE" | while IFS= read -r line; do\n'
        .. '        if [[ "$line" =~ $re_pkg ]]; then\n'
        .. '            echo -e "${C}${BASH_REMATCH[1]}${N} ${R}${BASH_REMATCH[2]}${N} ${Y}->${N} ${G}${BASH_REMATCH[3]}${N}"\n'
        .. '        else\n'
        .. '            echo "$line"\n'
        .. '        fi\n'
        .. '    done\n'
        .. 'else\n'
        .. '    echo -e "${Y}Nenhuma atualizacao pendente${N} (AUR)"\n'
        .. 'fi\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo "========================================="\n'
        .. 'echo -e "${C}📋 LOG DE LIMPEZA${N}"\n'
        .. 'echo "========================================="\n'
        .. '\n'
        .. 'echo -e "${Y}• Cache pacman:${N}"\n'
        .. 'PAC_CLEANED=$(echo "$PAC_LOG" | grep -iE "(remov|liberado|freed|total|pruned)" | head -5)\n'
        .. 'if [ -n "$PAC_CLEANED" ]; then\n'
        .. '    echo "$PAC_CLEANED" | while IFS= read -r line; do echo -e "${G}$line${N}"; done\n'
        .. 'else\n'
        .. '    echo -e "${Y}$(echo "$PAC_LOG" | tail -3)${N}"\n'
        .. 'fi\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo -e "${Y}• Cache AUR:${N}"\n'
        .. 'echo "$AUR_LOG" | grep -ivE "(^$|Deseja|Diretório|Pacotes a|Todos os)" | tail -15 | while IFS= read -r line; do\n'
        .. '    if [[ "$line" =~ ^Removing ]]; then\n'
        .. '        echo -e "${Y}$line${N}"\n'
        .. '    else\n'
        .. '        echo "$line"\n'
        .. '    fi\n'
        .. 'done\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo -e "${Y}• Builds AUR removidos:${N}"\n'
        .. 'BUILD_REMOVED=$(echo "$BUILD_LOG" | grep -E "(removendo|Pacotes|Tamanho|Nada)" | head -10)\n'
        .. 'if [ -n "$BUILD_REMOVED" ]; then\n'
        .. '    echo "$BUILD_REMOVED" | while IFS= read -r line; do\n'
        .. '        if [[ "$line" =~ Tamanho ]]; then\n'
        .. '            echo -e "${G}$line${N}"\n'
        .. '        elif [[ "$line" =~ ^Pacotes ]]; then\n'
        .. '            echo -e "${M}$line${N}"\n'
        .. '        elif [[ "$line" =~ ^removendo ]]; then\n'
        .. '            echo -e "${Y}$line${N}"\n'
        .. '        else\n'
        .. '            echo "$line"\n'
        .. '        fi\n'
        .. '    done\n'
        .. 'else\n'
        .. '    echo -e "${Y}Nada removido${N}"\n'
        .. 'fi\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo -e "${Y}• Orfaos:${N}"\n'
        .. 'if [ -n "$ORPHAN_LIST" ]; then\n'
        .. '    echo "$ORPHAN_LIST" | while IFS= read -r line; do echo -e "${C}$line${N}"; done\n'
        .. '    echo "$ORPHAN_LOG" | grep -iE "(removendo|total)" | head -5 | while IFS= read -r line; do\n'
        .. '        if [[ "$line" =~ Tamanho ]]; then\n'
        .. '            echo -e "${G}$line${N}"\n'
        .. '        else\n'
        .. '            echo -e "${Y}$line${N}"\n'
        .. '        fi\n'
        .. '    done\n'
        .. 'else\n'
        .. '    echo -e "${Y}$ORPHAN_LOG${N}"\n'
        .. 'fi\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo -e "${Y}• Flatpaks:${N}"\n'
        .. 'echo "$FLATPAK_LOG" | grep -v "^$" | while IFS= read -r line; do\n'
        .. '    if [[ "$line" =~ nao\\ encontrado ]]; then\n'
        .. '        echo -e "${Y}$line${N}"\n'
        .. '    else\n'
        .. '        echo "$line"\n'
        .. '    fi\n'
        .. 'done\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo -e "${Y}• Logs:${N}"\n'
        .. 'echo "$JOURNAL_LOG" | while IFS= read -r line; do\n'
        .. '    if [[ "$line" =~ freed ]]; then\n'
        .. '        echo -e "${G}$line${N}"\n'
        .. '    elif [[ "$line" =~ Vacuuming ]]; then\n'
        .. '        echo -e "${Y}$line${N}"\n'
        .. '    else\n'
        .. '        echo "$line"\n'
        .. '    fi\n'
        .. 'done\n'
        .. 'echo ""\n'
        .. '\n'
        .. 'echo -e "${Y}• Cache do usuario:${N}"\n'
        .. 'echo -e "${C}$USER_CACHE_BEFORE${N} ${Y}→${N} ${C}$USER_CACHE_AFTER${N}"\n'
        .. 'if [ -n "$CACHE_ITEMS" ]; then\n'
        .. '    echo ""\n'
        .. '    echo -e "${M}Itens removidos:${N}"\n'
        .. '    echo "$CACHE_ITEMS" | while IFS= read -r line; do\n'
        .. '        size="${line%%[[:space:]]*}"\n'
        .. '        rest="${line#*[[:space:]]}"\n'
        .. '        echo -e "${Y}$size${N}$rest"\n'
        .. '    done\n'
        .. 'fi\n'
        .. 'echo ""\n'

    script = script
        .. 'echo "========================================="\n'
        .. ': > "' .. markerPath .. '"\n'
        .. 'noctalia msg plugin rael2pac/arch-updater:updater all update-done >/dev/null 2>&1 || true\n'
        .. 'read -p "Pressione Enter para fechar..."\n'

    noctalia.runInTerminal(script)

    updating = true
    updatingTicks = 0
    resetState()
end

local function applyRefreshInterval()
    local intervalMin = noctalia.getConfig("refreshInterval")
    if type(intervalMin) ~= "number" or intervalMin < 1 then intervalMin = 120 end
    noctalia.setUpdateInterval(intervalMin * 60000)
end

applyRefreshInterval()
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
    if updating then
        updatingTicks = updatingTicks + 1
        if noctalia.fileExists(markerPath) then
            noctalia.removeFile(markerPath)
            updating = false
            refresh(false)
        elseif updatingTicks >= 10 then
            if noctalia.fileExists(markerPath) then
                noctalia.removeFile(markerPath)
            end
            updating = false
            refresh(false)
        end
        return
    end
    refresh(false)
end

function onConfigChanged()
    applyRefreshInterval()
    refresh(false)
end

function onIpc(event, payload)
    if event == "refresh" then
        refresh(true)
    elseif event == "update" then
        doUpdate()
    elseif event == "update-done" then
        updating = false
        updatingTicks = 0
        if noctalia.fileExists(markerPath) then
            noctalia.removeFile(markerPath)
        end
        refresh(false)
    else
        noctalia.log("noctaliav5: unknown IPC event: " .. event)
    end
end
