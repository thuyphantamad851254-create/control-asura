-- ============================================================
-- REMOTE COMMAND HANDLER - GitHub Repo (NO TOKEN NEEDED)
-- Đọc lệnh từ commands.json (public repo)
-- Kết quả gửi về Discord webhook
-- ============================================================

local GITHUB_USER = "thuyphantamad851254-create"   -- vd: thuyphantamad851254-create
local GITHUB_REPO = "control-asura"  -- vd: control-asura

local CMD_RAW_URL = string.format(
    "https://raw.githubusercontent.com/%s/%s/main/commands.json",
    GITHUB_USER, GITHUB_REPO
)

local HttpS   = game:GetService("HttpService")
local TS      = game:GetService("TeleportService")
local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local lastCmdTimestamp = 0
local POLL_INTERVAL    = 5

-- ============================================================
-- Xử lý lệnh
-- ============================================================
local function handleCommand(cmd, target, extra)
    if target ~= "" and target ~= player.Name then return end

    print("[CMD] Nhan lenh:", cmd, "| target:", target)

    if cmd == "stop" then
        if STATE then
            STATE.running = false
            STATE.busy    = false
        end
        -- Gọi đúng hàm stop như nút GUI
        pcall(function()
            if getgenv().REMOTE_stopTraining then
                getgenv().REMOTE_stopTraining()
            elseif stopTrainingByUser then
                stopTrainingByUser()
            end
        end)
        log("STOP boi Remote Control")
        sendWebhook("STOP - " .. player.Name, true)

    elseif cmd == "start" then
        local mode = (extra and extra.mode) or "Treadmill"
        pcall(function()
            if getgenv().REMOTE_startFarm then
                getgenv().REMOTE_startFarm(mode)
            end
        end)
        log("Start [" .. mode .. "] boi Remote Control")
        sendWebhook("START [" .. mode .. "] - " .. player.Name, true)

    elseif cmd == "checkpeople" then
        if checkPeopleAtSelectedLocation then checkPeopleAtSelectedLocation() end

    elseif cmd == "equiparmor" then
        if equipArmorNow then equipArmorNow() end
        sendWebhook("EQUIP ARMOR - " .. player.Name, true)

    elseif cmd == "hopserver" then
        sendWebhook("HOP SERVER - " .. player.Name, true)
        task.wait(1)
        pcall(function() TS:Teleport(game.PlaceId) end)

    elseif cmd == "statscheck" then
        task.spawn(function()
            if equipAndUseStatCheckTool then
                local ok = equipAndUseStatCheckTool()
                if ok then
                    task.wait(2)
                    local stats = collectStatCheckValues and collectStatCheckValues()
                    if stats then
                        local msg = (formatStatCheckWebhook and formatStatCheckWebhook(stats))
                            or ("Stats checked - " .. player.Name)
                        sendWebhook(msg, true)
                        if closeStatCheckUi then closeStatCheckUi(stats.root) end
                    end
                end
            end
        end)

    elseif cmd == "screenshot" then
        task.spawn(function()
            pcall(function()
                -- Thử các API chụp màn hình của executor
                local imgData = nil

                -- Synapse / KRNL / Fluxus
                if screenshot then
                    imgData = screenshot()
                elseif saveinstance then
                    -- fallback: không hỗ trợ
                end

                if imgData then
                    -- Gửi raw image lên Discord webhook
                    local fn = request or http_request
                    if fn then
                        fn({
                            Url = WEBHOOK_URL,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "multipart/form-data" },
                            Body = imgData,
                            -- Một số executor hỗ trợ MultipartFormdata
                            MultipartData = {
                                {
                                    Name = "file",
                                    Value = imgData,
                                    FileName = "screenshot_" .. player.Name .. ".png",
                                    ContentType = "image/png"
                                },
                                {
                                    Name = "content",
                                    Value = "Screenshot - " .. player.Name .. " - " .. os.date("%H:%M:%S")
                                }
                            }
                        })
                    end
                else
                    -- Executor không hỗ trợ screenshot API
                    -- Fallback: chụp bằng writefile nếu có
                    if writefile and isfile then
                        local path = "screenshot_temp.png"
                        -- Một số executor: rconsoleprint thay thế
                        sendWebhook("Screenshot: executor nay khong ho tro chup man hinh tu dong - " .. player.Name, true)
                    else
                        sendWebhook("Screenshot: khong ho tro - " .. player.Name, true)
                    end
                end
            end)
        end)
        if STATE then STATE.saveConfig = true end
        if queueConfigForTeleport then queueConfigForTeleport() end
        sendWebhook("SAVE ON - " .. player.Name, true)

    elseif cmd == "unsave" then
        if STATE then STATE.saveConfig = false end
        sendWebhook("SAVE OFF - " .. player.Name, true)

    elseif cmd == "status" then
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
        sendWebhook(msg, true)
    end
end

-- ============================================================
-- POLL LOOP - đọc commands.json mỗi 5s
-- ============================================================
task.spawn(function()
    task.wait(3)
    -- Báo online khi load xong
    if sendWebhook then
        sendWebhook("ONLINE - " .. player.Name .. " da load remote control", true)
    end

    while true do
        task.wait(POLL_INTERVAL)
        pcall(function()
            local fn = request or http_request
            if not fn then return end

            -- cache-buster
            local url = CMD_RAW_URL .. "?t=" .. tostring(math.floor(tick()))
            local res = fn({ Url = url, Method = "GET" })
            if not res or not res.Body then return end

            local ok, data = pcall(function()
                return HttpS:JSONDecode(res.Body)
            end)
            if not ok or type(data) ~= "table" then return end

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
