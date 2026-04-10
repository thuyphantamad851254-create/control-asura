-- ============================================================
-- REMOTE COMMAND HANDLER
-- Token duoc truyen tu fullscript.lua qua getgenv()
-- Khong co token nao trong file nay
-- ============================================================

-- Doc config tu getgenv() - duoc set trong fullscript.lua
local GIST_ID    = getgenv().REMOTE_GIST_ID    or "YOUR_GIST_ID"
local GIST_TOKEN = getgenv().REMOTE_GIST_TOKEN or ""
local GIST_FILE  = "commands.json"

local WEBHOOK_URL = getgenv().REMOTE_WEBHOOK or "https://discord.com/api/webhooks/1486045489244930199/HCnT6m-t3jtr5cBc6AoI-mVi5chpxPslNPhEOHXHXfY3JmNj7p-d2qwSABDhtmpSwkV2"

local HttpS   = game:GetService("HttpService")
local TS      = game:GetService("TeleportService")
local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local lastCmdTimestamp = 0
local POLL_INTERVAL    = 3

local function webhook(msg)
    task.spawn(function()
        pcall(function()
            local fn = request or http_request
            if not fn then return end
            fn({
                Url     = WEBHOOK_URL,
                Method  = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body    = HttpS:JSONEncode({
                    username = "RemoteControl | " .. player.Name,
                    content  = msg
                })
            })
        end)
    end)
end

local function handleCommand(cmd, target, extra)
    if target ~= "" and target ~= player.Name then return end
    print("[REMOTE] cmd:", cmd, "target:", target)

    if cmd == "stop" then
        pcall(function()
            if getgenv().REMOTE_stopTraining then getgenv().REMOTE_stopTraining() end
        end)
        webhook("STOP - " .. player.Name)

    elseif cmd == "start" then
        local mode = (extra and extra.mode) or "Treadmill"
        pcall(function()
            if getgenv().REMOTE_startFarm then getgenv().REMOTE_startFarm(mode) end
        end)
        webhook("START [" .. mode .. "] - " .. player.Name)

    elseif cmd == "checkpeople" then
        pcall(function()
            if checkPeopleAtSelectedLocation then checkPeopleAtSelectedLocation() end
        end)

    elseif cmd == "equiparmor" then
        pcall(function()
            if equipArmorNow then equipArmorNow() end
        end)
        webhook("EQUIP ARMOR - " .. player.Name)

    elseif cmd == "hopserver" then
        webhook("HOP SERVER - " .. player.Name)
        task.wait(1)
        pcall(function() TS:Teleport(game.PlaceId) end)

    elseif cmd == "statscheck" then
        task.spawn(function()
            pcall(function()
                if equipAndUseStatCheckTool then
                    local ok = equipAndUseStatCheckTool()
                    if ok then
                        task.wait(2)
                        local stats = collectStatCheckValues and collectStatCheckValues()
                        if stats then
                            local msg = (formatStatCheckWebhook and formatStatCheckWebhook(stats))
                                or ("Stats checked - " .. player.Name)
                            webhook(msg)
                            if closeStatCheckUi then closeStatCheckUi(stats.root) end
                        end
                    end
                end
            end)
        end)

    elseif cmd == "saveon" then
        pcall(function()
            if STATE then STATE.saveConfig = true end
            if queueConfigForTeleport then queueConfigForTeleport() end
        end)
        webhook("SAVE ON - " .. player.Name)

    elseif cmd == "unsave" then
        pcall(function()
            if STATE then STATE.saveConfig = false end
        end)
        webhook("SAVE OFF - " .. player.Name)

    elseif cmd == "status" then
        pcall(function()
            local msg = string.format(
                "STATUS | %s | HP:%.0f Hunger:%.0f%% Protein:%.0f%% Cash:Y%d | Mode:%s Running:%s",
                player.Name,
                getHP and getHP() or 0,
                getHunger and getHunger() or 0,
                getProtein and getProtein() or 0,
                getCash and getCash() or 0,
                CFG and CFG.Mode or "?",
                tostring(STATE and STATE.running or false)
            )
            webhook(msg)
        end)
    end
end

task.spawn(function()
    task.wait(3)

    if GIST_TOKEN == "" then
        warn("[REMOTE] Chua set REMOTE_GIST_TOKEN trong fullscript.lua")
        return
    end

    webhook("ONLINE - " .. player.Name)

    local fn = request or http_request
    if not fn then
        warn("[REMOTE] Executor khong ho tro request")
        return
    end

    local GIST_API = "https://api.github.com/gists/" .. GIST_ID

    while true do
        task.wait(POLL_INTERVAL)
        pcall(function()
            local res = fn({
                Url    = GIST_API,
                Method = "GET",
                Headers = {
                    ["Authorization"] = "token " .. GIST_TOKEN,
                    ["Accept"]        = "application/vnd.github.v3+json",
                }
            })

            if not res or not res.Body then return end

            local ok, meta = pcall(function()
                return HttpS:JSONDecode(res.Body)
            end)
            if not ok or type(meta) ~= "table" then return end

            local fileContent = meta.files
                and meta.files[GIST_FILE]
                and meta.files[GIST_FILE].content
            if not fileContent then return end

            local ok2, data = pcall(function()
                return HttpS:JSONDecode(fileContent)
            end)
            if not ok2 or type(data) ~= "table" then return end

            local cmd       = data.cmd or ""
            local target    = data.target or ""
            local timestamp = tonumber(data.timestamp) or 0
            local extra     = data.extra or {}

            if cmd == "" or timestamp <= lastCmdTimestamp then return end
            lastCmdTimestamp = timestamp

            handleCommand(cmd, target, extra)
        end)
    end
end)
