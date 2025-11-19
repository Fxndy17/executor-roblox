local Players = game:GetService("Players")
local HTTPService = game:GetService("HttpService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiers = require(game:GetService("ReplicatedStorage").Tiers)

local eventsFrame = gui:WaitForChild("Events"):WaitForChild("Frame")
local eventsFolder = eventsFrame:WaitForChild("Events")
local serverLuck = eventsFrame:WaitForChild("Server Luck")
local serverGui = serverLuck:WaitForChild("Server")
local luckCounter = serverGui:WaitForChild("LuckCounter")

local WEBHOOK_URL =
    "https://discord.com/api/webhooks/1439918334509322250/tLGCb_6iVxqoDT-RG1YLL4RG7Nulcvt-ydNDG-qsEb7U0Qy5DGwJhRdXVsLF8-3w6k7d"
-- Cache untuk item data
local ITEM_CACHE = {}

local function getItemData(itemName)
    -- Cek cache dulu
    if ITEM_CACHE[itemName] then
        return ITEM_CACHE[itemName]
    end

    -- Cari item di ReplicatedStorage.Items
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then
        return nil
    end

    local itemModule = itemsFolder:FindFirstChild(itemName)
    if itemModule and itemModule:IsA("ModuleScript") then
        local success, itemData = pcall(function()
            return require(itemModule)
        end)

        if success and itemData then
            ITEM_CACHE[itemName] = itemData
            return itemData
        end
    end

    return nil
end

local function extractFishInfo(message)
    -- Pattern untuk format dengan tag font dan bold
    -- Contoh: <b><font size="18">[Server]:</font></b> Fxndy obtained a <b><font color="rgb(174, 80, 255)">Skeleton Angler Fish (2.11kg)</font></b> with a 1 in 3K chance!
    local pattern1 = 'obtained a.-<font color="rgb%(%d+,%s*%d+,%s*%d+%)">(.-)%s*%(([%d%.]+[Kk]?) kg%)</font>'
    
    -- Pattern alternative untuk format dengan tag bold di dalam font
    local pattern2 = 'obtained a.-<font[^>]+>.-<b>(.-)</b>%s*%(([%d%.]+[Kk]?) kg%)</font>'
    
    -- Pattern untuk format sederhana
    local pattern3 = 'obtained a.-<font[^>]+>(.-)%s*%(([%d%.]+[Kk]?) kg%)</font>'
    
    -- Pattern untuk format tanpa tag (clean text)
    local pattern4 = 'obtained a (.-) %(([%d%.]+[Kk]?) kg%) with a'

    local fishName, weight

    -- Coba pattern pertama
    fishName, weight = string.match(message, pattern1)
    if fishName then
        fishName = string.gsub(fishName, "<[^>]+>", "")
        fishName = string.gsub(fishName, "^%s*(.-)%s*$", "%1")
        return fishName, weight
    end

    -- Coba pattern kedua
    fishName, weight = string.match(message, pattern2)
    if fishName then
        fishName = string.gsub(fishName, "<[^>]+>", "")
        fishName = string.gsub(fishName, "^%s*(.-)%s*$", "%1")
        return fishName, weight
    end

    -- Coba pattern ketiga
    fishName, weight = string.match(message, pattern3)
    if fishName then
        fishName = string.gsub(fishName, "<[^>]+>", "")
        fishName = string.gsub(fishName, "^%s*(.-)%s*$", "%1")
        return fishName, weight
    end

    -- Coba pattern keempat (clean text)
    fishName, weight = string.match(message, pattern4)
    if fishName then
        fishName = string.gsub(fishName, "<[^>]+>", "")
        fishName = string.gsub(fishName, "^%s*(.-)%s*$", "%1")
        return fishName, weight
    end

    return nil, nil
end

local function extractChanceInfo(message)
    -- Pattern untuk chance info dari raw HTML
    local pattern1 = "with a 1 in (%d+[Kk]?) chance!"
    
    -- Pattern alternative untuk clean text
    local pattern2 = "with a 1 in (%d+[Kk]?) chance!"
    
    -- Pattern untuk format yang mungkin berbeda
    local pattern3 = "1 in (%d+[Kk]?) chance!"

    local chance = string.match(message, pattern1)
    if not chance then
        chance = string.match(message, pattern2)
    end
    if not chance then
        chance = string.match(message, pattern3)
    end
    
    return chance
end

local function getTierName(tierNumber)
    for _, tierData in ipairs(Tiers) do
        if tierData.Tier == tierNumber then
            return tierData.Name
        end
    end
    return nil -- Return nil if tier number not found
end

-- Function to get tier data by tier number
local function getTierData(tierNumber)
    for _, tierData in ipairs(Tiers) do
        if tierData.Tier == tierNumber then
            return tierData
        end
    end
    return nil
end

-- Function to get tier data by tier name
local function getTierDataByName(tierName)
    for _, tierData in ipairs(Tiers) do
        if tierData.Name == tierName then
            return tierData
        end
    end
    return nil
end

------------------------------------------------------
-- SEND EVENT TO DISCORD WEBHOOK
------------------------------------------------------
local function sendEvent(message, eventType, pingEveryone)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local content = pingEveryone and "@everyone" or ""
    
    -- Tentukan warna berdasarkan jenis event
    local color = 5814783 -- Default color (biru)
    if eventType == "event_active" then
        color = 3066993 -- Hijau untuk event aktif
    elseif eventType == "event_inactive" then
        color = 15158332 -- Merah untuk event non-aktif
    elseif eventType == "server_luck" then
        color = 15844367 -- Emas untuk server luck
    elseif eventType == "script_start" then
        color = 3447003 -- Biru untuk script start
    end

    local data = {
        ["content"] = content,
        ["embeds"] = {{
            ["title"] = "🎮 Game Event Notification",
            ["description"] = message,
            ["color"] = color,
            ["footer"] = {
                ["text"] = "Timestamp: " .. timestamp
            },
            ["thumbnail"] = {
                ["url"] = "https://cdn.discordapp.com/emojis/1117363660576395324.webp"
            }
        }}
    }

    local jsonData = HTTPService:JSONEncode(data)

    local success, result = pcall(function()
        return request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    if not success then
        warn("[WEBHOOK ERROR] Failed to send event:", result)
    end
end

------------------------------------------------------
-- SEND FISH CAUGHT TO DISCORD WEBHOOK
------------------------------------------------------
local function sendFishCaught(fishName, weight, chance, tierName, tierNumber, iconUrl)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Tentukan warna berdasarkan tier
    local color = 5814783 -- Default color
    local tierData = getTierData(tierNumber)
    if tierData and tierData.Color then
        color = tierData.Color
    end

    local embed = {
        ["title"] = "🎣 FISH CAUGHT!",
        ["description"] = string.format(
            "**Player:** %s\n**Fish:** %s\n**Weight:** %s kg\n**Chance:** 1 in %s\n**Tier:** %s (Tier %d)",
            player.Name, fishName, weight, chance, tierName, tierNumber
        ),
        ["color"] = color,
        ["footer"] = {
            ["text"] = "Timestamp: " .. timestamp
        }
    }

    -- Tambahkan thumbnail jika ada icon
    if iconUrl then
        embed["thumbnail"] = {
            ["url"] = iconUrl
        }
    end

    local data = {
        ["content"] = "@everyone 🎣 **FISH CAUGHT!**",
        ["embeds"] = {embed}
    }

    local jsonData = HTTPService:JSONEncode(data)

    local success, result = pcall(function()
        return request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    if not success then
        warn("[WEBHOOK ERROR] Failed to send fish caught:", result)
    else
        print("✅ Fish caught notification sent to Discord!")
    end
end

------------------------------------------------------
-- REMOVE RICH TEXT FROM STRING (<b>, <font>, etc)
------------------------------------------------------
local function stripRichText(str)
    return (str:gsub("<[^>]->", "")) -- remove tags <...>
end

------------------------------------------------------
-- CHAT PARSER (CLEAN CHAT)
------------------------------------------------------
game:GetService("TextChatService").OnIncomingMessage = function(msg)
    local rawText = msg.Text
    local clean = stripRichText(rawText)

    if string.find(clean, "obtained a") and string.find(clean, "kg") then
        local fishName, weight = extractFishInfo(rawText)
        local chance = extractChanceInfo(rawText)

        if fishName and weight and chance then
            print("🎣 Fish detected: " .. fishName .. " (" .. weight .. " kg) - Chance: 1 in " .. chance)

            -- Dapatkan data item dari ReplicatedStorage
            local itemData = getItemData(fishName)

            -- Konversi icon URL
            local iconUrl = nil
            if itemData and itemData.Data and itemData.Data.Icon then
                local iconId = string.match(itemData.Data.Icon, "rbxassetid://(%d+)")
                if iconId then
                    iconUrl = "https://assetdelivery.roblox.com/v1/asset/?id=" .. iconId
                end
            end

            -- Dapatkan tier info
            local tierName = "Unknown"
            local tierNumber = 0
            if itemData and itemData.Data and itemData.Data.Tier then
                tierNumber = itemData.Data.Tier
                tierName = getTierName(tierNumber) or "Unknown"
            end

            -- Kirim notifikasi fish caught
            sendFishCaught(fishName, weight, chance, tierName, tierNumber, iconUrl)
        else
            print("❌ Failed to extract fish info from message")
        end
    end
end

------------------------------------------------------
-- WATCH IMAGEBUTTON / IMAGELABEL VISIBLE CHANGES
------------------------------------------------------
local function watchEvent(obj)
    if obj:IsA("ImageButton") or obj:IsA("ImageLabel") then
        obj.Changed:Connect(function(prop)
            if prop == "Visible" then
                local status = obj.Visible and "🟢 VISIBLE" or "🔴 HIDDEN"
                local eventName = obj.Name
                
                if obj.Visible then
                    sendEvent(
                        string.format("**Event Active!**\n**Event Name:** %s\n**Status:** 🟢 ACTIVE", eventName),
                        "event_active",
                        true
                    )
                else
                    sendEvent(
                        string.format("**Event Ended!**\n**Event Name:** %s\n**Status:** 🔴 INACTIVE", eventName),
                        "event_inactive",
                        false
                    )
                end
            end
        end)
    end
end

-- Pantau semua yang sudah ada
for _, obj in ipairs(eventsFolder:GetDescendants()) do
    watchEvent(obj)
end

-- Pantau yang baru masuk
eventsFolder.DescendantAdded:Connect(function(obj)
    watchEvent(obj)
end)

------------------------------------------------------
-- WATCH SERVER LUCK VISIBLE
------------------------------------------------------
serverGui.Changed:Connect(function(prop)
    if prop == "Visible" then
        if serverGui.Visible then
            sendEvent(
                "**🍀 SERVER LUCK ACTIVE!**\nServer Luck event is now active!",
                "event_active",
                true
            )
        else
            sendEvent(
                "**🍀 SERVER LUCK ENDED!**\nServer Luck event has ended.",
                "event_inactive",
                false
            )
        end
    end
end)

------------------------------------------------------
-- WATCH LUCKCOUNTER TEXT CHANGE
------------------------------------------------------
luckCounter:GetPropertyChangedSignal("Text"):Connect(function()
    local luckValue = luckCounter.Text
    print("[LUCK COUNTER] Text:", luckValue)

    sendEvent(
        string.format("**🍀 SERVER LUCK UPDATE**\n**Current Luck:** %s", luckValue),
        "server_luck",
        false
    )
end)

-- Initial message when script starts
sendEvent("🚀 **Script Started**\nMonitoring system activated!", "script_start", false)
