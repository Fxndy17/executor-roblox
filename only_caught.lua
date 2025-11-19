local Players = game:GetService("Players")
local HTTPService = game:GetService("HttpService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiers = require(game:GetService("ReplicatedStorage").Tiers)

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
    -- Pattern untuk raw HTML dengan font color
    local pattern1 = 'obtained a.-<font color="rgb%(%d+,%s*%d+,%s*%d+%)">(.-)%s*%(([%d%.]+[Kk]?) kg%)</font>'
    
    -- Pattern untuk raw HTML dengan bold di dalam font
    local pattern2 = 'obtained a.-<font[^>]+><b>(.-)</b>%s*%(([%d%.]+[Kk]?) kg%)</font>'
    
    -- Pattern untuk raw HTML tanpa bold
    local pattern3 = 'obtained a.-<font[^>]+>(.-)%s*%(([%d%.]+[Kk]?) kg%)</font>'

    local fishName, weight

    -- Coba pattern pertama
    fishName, weight = string.match(message, pattern1)
    if fishName then
        -- Hapus tag HTML dari fishName jika ada
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

    return nil, nil
end

local function extractChanceInfo(message)
    -- Pattern untuk chance info dari raw HTML
    local pattern = "with a 1 in (%d+[%.]?%d*[Kk]?) chance!"
    
    local chance = string.match(message, pattern)
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
            "**Player:** %s\n**Fish:** %s\n**Weight:** %s kg\n**Chance:** 1 in %s\n**Tier:** %s (Tier %d)", player.Name,
            fishName, weight, chance, tierName, tierNumber),
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

    if string.find(rawText, "obtained a") and string.find(rawText, "kg") then
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
