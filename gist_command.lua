-- ============================================================
-- REMOTE COMMAND HANDLER
-- Dung GitHub Contents API (khong cache, realtime)
-- Poll moi 2 giay
-- ============================================================

local GITHUB_USER = "thuyphantamad851254-create"
local GITHUB_REPO = "control-asura"

-- GitHub Contents API tra ve realtime, khong bi cache nhu raw URL
local CMD_API_URL = string.format(
    "https://api.github.com/repos/%s/%s/contents/commands.json",
    GITHUB_USER, GITHUB_REPO
)

local WEBHOOK_URL = "https://discord.com/api/webhooks/1486045489244930199/HCnT6m-t3jtr5cBc6AoI-mVi5chpxPslNPhEOHXHXfY3JmNj7p-d2qwSABDhtmpSwkV2"

local HttpS   = game:GetService("HttpService")
local TS      = game:GetService("TeleportService")
local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local lastCmdTimestamp = 0
local POLL_INTERVAL    = 2  -- giam xuong 2 giay

-- ============================================================
-- Base64 decode (de doc noi dung tu GitHub API)
-- ============================================================
local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64Decode(data)
    data = data:gsub("[^"..b64.."=]", "")
    return (data:gsub(".", function(x)
        if x == "=" then return "" end
        local r, f = "", (b64:find(x) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2^i - f % 2^(i-1) > 0 and "1" or "0")
        end
        return r
    end):gsub("%d%d%d%d%d%d%d%d", function(x)
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == "1" and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- ============================================================
-- Webhook helper
-- ============================================================
local function webhook(msg)
    task.spawn(function()
        pcall(function()
            local fn = request or http_request
            if not fn then return end
            fn({
                Url    = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body   = HttpS:JSONEncode({
                    username = "RemoteControl | " .. player.Name,
                    content  = msg
                })
            })
        end)
    end)
end

-- ============================================================
-- Xu ly lenh
-- ============================================================
local function handleCommand(cmd, target, extra)
    if target ~= "" and target ~= player.Name then return end

    print("[REMOTE] cmd:", cmd, "target:", target)

    if cmd == "stop" then
        pcall(function()
            if getgenv().REMOTE_stopTraining then
                getgenv().REMOTE_stopTraining()
            end
        end)
        webhook("STOP - " .. player.Name)

    elseif cmd == "start" then
        local mode = (extra and extra.mode) or "Treadmill"
        pcall(function()
            if getgenv().REMOTE_startFarm then
                getgenv().REMOTE_startFarm(mode)
            end
        end)
        webhook("START [" .. mode .. "] - " .. player.Name)

    elseif cmd == "checkpeople" then
        pcall(function()
            if checkPeopleAtSelectedLocation then
                checkPeopleAtSelectedLocation()
            end
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

    elseif cmd == "screenshot" then
        task.spawn(function()
            pcall(function()
                if screenshot then
                    local data = screenshot()
                    if data then
                        local fn = request or http_request
                        if fn then
                            fn({
                                Url    = WEBHOOK_URL,
                                Method = "POST",
                                MultipartData = {
                                    { Name = "content", Value = "Screenshot - " .. player.Name },
                                    { Name = "file", Value = data, FileName = "screen.png", ContentType = "image/png" }
                                }
                            })
                        end
                    end
                else
                    webhook("Screenshot: executor nay khong ho tro - " .. player.Name)
                end
            end)
        end)
    end
end

-- ============================================================
-- POLL LOOP - dung GitHub Contents API, khong cache
-- ============================================================
task.spawn(function()
    task.wait(3)
    webhook("ONLINE - " .. player.Name .. " da load remote control")

    local fn = request or http_request
    if not fn then
        warn("[REMOTE] Executor khong ho tro request/http_request")
        return
    end

    while true do
        task.wait(POLL_INTERVAL)
        pcall(function()
            -- GitHub Contents API: tra ve JSON co truong "content" la base64
            -- Them header de tranh rate limit
            local res = fn({
                Url    = CMD_API_URL,
                Method = "GET",
                Headers = {
                    ["Accept"]     = "application/vnd.github.v3+json",
                    ["User-Agent"] = "RobloxScript",
                    -- Them If-None-Match de giam bandwidth neu khong co thay doi
                }
            })

            if not res or not res.Body then return end

            local ok, meta = pcall(function()
                return HttpS:JSONDecode(res.Body)
            end)
            if not ok or type(meta) ~= "table" or not meta.content then return end

            -- Decode base64 content
            local raw = base64Decode(meta.content:gsub("\n",""))
            local ok2, data = pcall(function()
                return HttpS:JSONDecode(raw)
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
