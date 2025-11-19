local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Chat = game:GetService("Chat")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Discord Webhook URL
local WEBHOOK_URL = "https://discord.com/api/webhooks/1439918334509322250/tLGCb_6iVxqoDT-RG1YLL4RG7Nulcvt-ydNDG-qsEb7U0Qy5DGwJhRdXVsLF8-3w6k7d"

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
    -- Pattern untuk mengekstrak nama ikan dan berat dari format chat
    -- Contoh: "Fxndy obtained a Crocodile (5.36K kg) with a 1 in 50K chance!"
    local pattern = 'obtained a.-<font color="rgb%(%d+,%s*%d+,%s*%d+%)">(.-)%s*%(([%d%.]+[Kk]?) kg%)</font>'
    
    local fishName, weight = string.match(message, pattern)
    
    if fishName then
        -- Bersihkan nama ikan dari tag HTML jika ada
        fishName = string.gsub(fishName, "<[^>]+>", "")
        fishName = string.gsub(fishName, "^%s*(.-)%s*$", "%1")
        
        return fishName, weight
    end
    
    -- Alternative pattern untuk format berbeda
    local altPattern = 'obtained a.-<font[^>]+>(.-)%s*%(([%d%.]+[Kk]?) kg%)</font>'
    fishName, weight = string.match(message, altPattern)
    
    if fishName then
        fishName = string.gsub(fishName, "<[^>]+>", "")
        fishName = string.gsub(fishName, "^%s*(.-)%s*$", "%1")
        return fishName, weight
    end
    
    return nil, nil
end

local function extractChanceInfo(message)
    -- Pattern untuk mengekstrak chance info
    -- Contoh: "with a 1 in 50K chance!"
    local pattern = "with a 1 in (%d+[Kk]?) chance!"
    local chance = string.match(message, pattern)
    return chance
end

local function getTierName(tierNumber)
    local tierMap = {
        [1] = "Common",
        [2] = "Uncommon", 
        [3] = "Rare",
        [4] = "Epic",
        [5] = "Legendary",
        [6] = "Mythic",
        [7] = "SECRET"
    }
    return tierMap[tierNumber] or "Unknown"
end

local function sendToDiscord(message, playerName, fishName, weight, chance, itemData)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
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
        tierName = getTierName(tierNumber)
    end
    
    -- Warna embed berdasarkan tier
    local tierColors = {
        [1] = 0xFFFFFF, -- Common: White
        [2] = 0x00FF00, -- Uncommon: Green
        [3] = 0x0064FF, -- Rare: Blue
        [4] = 0x800080, -- Epic: Purple
        [5] = 0xFFB92B, -- Legendary: Gold
        [6] = 0xFF0000, -- Mythic: Red
        [7] = 0x00FFFF  -- SECRET: Cyan
    }
    
    local embedColor = tierColors[tierNumber] or 0x808080
    
    -- Format fields
    local fields = {
        {
            ["name"] = "🎣 Fish Caught",
            ["value"] = "**" .. fishName .. "**",
            ["inline"] = true
        },
        {
            ["name"] = "⚖️ Weight", 
            ["value"] = weight .. " kg",
            ["inline"] = true
        },
        {
            ["name"] = "⭐ Tier",
            ["value"] = tierName .. " (Tier " .. tierNumber .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "🎯 Chance",
            ["value"] = "1 in " .. chance,
            ["inline"] = true
        },
        {
            ["name"] = "👤 Player", 
            ["value"] = playerName,
            ["inline"] = true
        },
        {
            ["name"] = "💰 Sell Price",
            ["value"] = itemData and itemData.SellPrice and tostring(itemData.SellPrice) or "Unknown",
            ["inline"] = true
        }
    }

    local embed = {
        {
            ["title"] = "🎣 FISH CATCH ALERT!",
            ["color"] = embedColor,
            ["fields"] = fields,
            ["thumbnail"] = iconUrl and {["url"] = iconUrl} or nil,
            ["footer"] = {
                ["text"] = "Caught at: " .. timestamp
            },
            ["author"] = {
                ["name"] = "Fishing Logger",
                ["icon_url"] = "https://cdn.discordapp.com/attachments/1439918334509322250/1439918334509322250/tLGCb_6iVxqoDT-RG1YLL4RG7Nulcvt-ydNDG-qsEb7U0Qy5DGwJhRdXVsLF8-3w6k7d?ex=66d5f3e6&is=66d4a266&hm=8a7f5a5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c&"
            }
        }
    }

    local data = {
        ["embeds"] = embed,
        ["username"] = "Fishing Notifier",
        ["avatar_url"] = "https://cdn.discordapp.com/attachments/1439918334509322250/1439918334509322250/tLGCb_6iVxqoDT-RG1YLL4RG7Nulcvt-ydNDG-qsEb7U0Qy5DGwJhRdXVsLF8-3w6k7d?ex=66d5f3e6&is=66d4a266&hm=8a7f5a5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c&"
    }

    local jsonData = HttpService:JSONEncode(data)

    local success, result = pcall(function()
        return HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
    end)

    if success then
        print("✅ Webhook berhasil dikirim! Fish: " .. fishName)
    else
        print("❌ Gagal mengirim webhook: " .. tostring(result))
    end
end

local function logChat(message, player, isSystemMessage)
    local timestamp = os.date("%H:%M:%S")
    local sender = isSystemMessage and "[SYSTEM]" or player.Name
    
    print("[" .. timestamp .. "] " .. sender .. ": " .. message)

    -- Cek jika ini message tentang mendapatkan ikan
    if string.find(message, "obtained a") and string.find(message, "kg") then
        local fishName, weight = extractFishInfo(message)
        local chance = extractChanceInfo(message)
        
        if fishName and weight and chance then
            print("🎣 Fish detected: " .. fishName .. " (" .. weight .. " kg) - Chance: 1 in " .. chance)
            
            -- Dapatkan data item dari ReplicatedStorage
            local itemData = getItemData(fishName)
            
            if itemData then
                print("📦 Item data found: Tier " .. (itemData.Data.Tier or "Unknown"))
            else
                print("⚠️ Item data not found for: " .. fishName)
            end
            
            -- Kirim ke Discord
            sendToDiscord(message, player.Name, fishName, weight, chance, itemData)
        else
            print("❌ Failed to extract fish info from message")
        end
    end
end

-- Listener untuk chat player
for _, player in pairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        logChat(message, player, false)
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        logChat(message, player, false)
    end)
end)

-- Listener untuk system messages
Chat.MessagePosted:Connect(function(message, channelName)
    if string.find(channelName, "System") or string.find(message, "^%[.*%].*:") then
        -- Untuk system messages, kita gunakan nil player
        logChat(message, {Name = "System"}, true)
    end
end)

print("🎣 Fishing Logger Started!")
print("Akan mendeteksi dan log semua fish catches ke Discord")
