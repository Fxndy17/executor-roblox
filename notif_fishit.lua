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

-- Configuration
local WEBHOOK_CAUGHT = "https://discord.com/api/webhooks/1443775157381365903/aQmPT3LS58OrBQxiuHH5ChntyR0XhaEFxNDxkNHCZxEGzyaeMyCcjq2e_RwzUXmaldUJ"
local WEBHOOK_EVENT = "https://discord.com/api/webhooks/1443775782596903044/M8DKjQZ5aizPBzQtT8FHrxRyAqXnO-e_lJq2_vLsAtFPRLLVDoqF5bpQ8k5LIc1iX42o"
local API_BASE_URL = "https://fishitapi-production.up.railway.app/api"

local ITEM_CACHE = {}

------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------

local function isSimilar(baseName, inputName)
    baseName = baseName:lower()
    inputName = inputName:lower()

    if inputName:find(baseName, 1, true) then
        return true
    end

    local allWordsMatch = true
    for word in baseName:gmatch("%S+") do
        if not inputName:find(word, 1, true) then
            allWordsMatch = false
            break
        end
    end

    return allWordsMatch
end

local function findSimilarChild(folder, inputName)
    for _, child in ipairs(folder:GetChildren()) do
        if isSimilar(child.Name:lower(), inputName:lower()) then
            return child
        end
    end
    return nil
end

local function getItemData(itemName)
    if ITEM_CACHE[itemName] then
        return ITEM_CACHE[itemName]
    end

    local itemsFolder = ReplicatedStorage:WaitForChild("Items")
    if not itemsFolder then
        return nil
    end

    local itemModule = itemsFolder:FindFirstChild(itemName)

    if not itemModule then
        itemModule = findSimilarChild(itemsFolder, itemName)
    end

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

local function getPlayer(query)
    query = query:lower()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower() == query or plr.DisplayName:lower() == query then
            return plr
        end
    end

    return nil
end

local function extractPlayer(clean)
    return clean:match("%]:%s*(%w+)")
end

local function extractFishInfo(clean)
    local fish = clean:match("obtained an?%s+([%w%s%-]+)%s*%(")
    local weight = clean:match("%(([%d%.]+%s*[KM]?%s*kg)%)")

    if not weight then
        weight = clean:match("%(([%d%.]+%s*[KM]?)%)")
    end

    if not fish then
        fish = clean:match("obtained an?%s+(.-)%s*%(")
    end

    return fish, weight
end

local function extractChanceInfo(clean)
    return clean:match("1 in%s+([%w]+)")
end

local function getTierName(tierNumber)
    for _, tierData in ipairs(Tiers) do
        if tierData.Tier == tierNumber then
            return tierData.Name
        end
    end
    return nil
end

local function getTierData(tierNumber)
    for _, tierData in ipairs(Tiers) do
        if tierData.Tier == tierNumber then
            return tierData
        end
    end
    return nil
end

local function stripRichText(str)
    return (str:gsub("<[^>]->", ""))
end

------------------------------------------------------
-- API FUNCTIONS
------------------------------------------------------

local function getAllAccounts()
    local success, result = pcall(function()
        local response = request({
            Url = API_BASE_URL .. "/accounts",
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json"
            }
        })
        
        if response and response.StatusCode == 200 then
            local decoded = HTTPService:JSONDecode(response.Body)
            return decoded
        else
            warn("[API] Request failed:", response.StatusCode)
            return nil
        end
    end)
    
    if not success then
        warn("[API] PCall failed:", result)
        return nil
    end
    
    return result
end

local function getUsersWithNotification(notificationType, enabled)
    local success, result = pcall(function()
        local response = request({
            Url = API_BASE_URL .. "/notifications/" .. notificationType .. "?enabled=" .. tostring(enabled),
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json"
            }
        })
        
        if response and response.StatusCode == 200 then
            local decoded = HTTPService:JSONDecode(response.Body)
            return decoded
        else
            warn("[API] Request failed for notifications:", response.StatusCode)
            return nil
        end
    end)
    
    if not success then
        warn("[API] PCall failed for notifications:", result)
        return nil
    end
    
    return result
end

local function findUserByRobloxUsername(username)
    local plr = getPlayer(username)

    if plr == nil then
        print("❌ Player not found:", username)
        return nil
    end

    local allAccounts = getAllAccounts()
    if not allAccounts or not allAccounts.success then
        return nil
    end

    for _, account in ipairs(allAccounts.data) do
        if account.id_roblox and tonumber(account.id_roblox) == tonumber(plr.UserId) then
            return account
        end
    end
    return nil
end

local function generateUserMentions(users)
    local mentions = {}
    for _, user in ipairs(users) do
        table.insert(mentions, "<@" .. user.id_discord .. ">")
    end
    return table.concat(mentions, ", ")
end

local function getOnlineUsersWithNotification(notificationType, enabled)
    local notificationUsers = getUsersWithNotification(notificationType, enabled)
    if not notificationUsers or not notificationUsers.success then
        return {}
    end
    
    local onlineUsers = {}
    local onlinePlayerNames = {}
    
    -- Get list of online player usernames
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(onlinePlayerNames, player.Name:lower())
    end
    
    -- Filter users yang sedang online dan punya notifikasi enabled
    for _, user in ipairs(notificationUsers.data) do
        for _, account in ipairs(user.roblox_accounts or {}) do
            if account.username_roblox then
                local usernameLower = account.username_roblox:lower()
                for _, onlineName in ipairs(onlinePlayerNames) do
                    if onlineName == usernameLower then
                        table.insert(onlineUsers, user)
                        break
                    end
                end
            end
        end
    end
    
    return onlineUsers
end

------------------------------------------------------
-- WEBHOOK FUNCTIONS
------------------------------------------------------

local function sendFishCaught(fisher, fishName, weight, chance, tierName, tierNumber, iconUrl)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    -- Cari user berdasarkan Roblox username
    local userAccount = findUserByRobloxUsername(fisher)

    -- Jika user tidak ditemukan atau notif_caught = false, skip
    if not userAccount or not userAccount.settings.notif_caught then
        print("ℹ️ Skipping notification for", fisher, "- User not registered or notifications disabled")
        return
    end

    -- GUNAKAN NAMA IN-GAME (fisher) BUKAN USER ID MENTION
    local playerDisplay = fisher

    local color = 5814783
    local tierData = getTierData(tierNumber)
    if tierData and tierData.Color then
        color = tierData.Color
    end

    local embed = {
        ["title"] = "🎣 FISH CAUGHT!",
        ["description"] = string.format(
            "**Player:** %s\n**Fish:** %s\n**Weight:** %s\n**Chance:** 1 in %s\n**Tier:** %s (Tier %d)",
            playerDisplay, fishName, weight, chance, tierName, tierNumber),
        ["color"] = color,
        ["footer"] = {
            ["text"] = "Timestamp: " .. timestamp
        }
    }

    if iconUrl then
        embed["thumbnail"] = {
            ["url"] = iconUrl
        }
    end

    -- CONTENT: Tag user ID tapi di embed show nama in-game
    local data = {
        ["content"] = "<@" .. userAccount.id_discord .. "> 🎣 **FISH CAUGHT!**",
        ["embeds"] = {embed}
    }

    local jsonData = HTTPService:JSONEncode(data)

    local success, result = pcall(function()
        return request({
            Url = WEBHOOK_CAUGHT,
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
        print("✅ Fish caught notification sent for:", userAccount.username_roblox)
    end
end

local function sendEvent(message, eventType, pingEveryone)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local mentions = ""
    if pingEveryone then
        local onlineUsers = getOnlineUsersWithNotification("notif_weather", true)
        if #onlineUsers > 0 then
            mentions = generateUserMentions(onlineUsers)
            print("🔔 Tagging " .. #onlineUsers .. " online users with weather notifications")
        else
            print("ℹ️ No online users with weather notifications found")
        end
    end

    local color = 5814783 -- Default color
    if eventType == "event_active" then
        color = 3066993 -- Hijau
    elseif eventType == "event_inactive" then
        color = 15158332 -- Merah
    elseif eventType == "server_luck" then
        color = 15844367 -- Emas
    elseif eventType == "script_start" then
        color = 3447003 -- Biru
    end

    local content = ""
    if pingEveryone and mentions ~= "" then
        content = mentions .. " 🎮 **EVENT NOTIFICATION!**"
    elseif pingEveryone then
        content = "🎮 **EVENT NOTIFICATION!**"
    end

    local data = {
        ["content"] = content,
        ["embeds"] = {{
            ["title"] = "🎮 Event Notification",
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
            Url = WEBHOOK_EVENT,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    if not success then
        warn("[WEBHOOK ERROR] Failed to send event:", result)
    else
        print("✅ Event notification sent to Discord")
    end
end

local function sendDebug(label, rawText, cleanText, fisher, fishName, weight, chance)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local function formatField(value, maxLength)
        if not value then return "nil" end
        local str = tostring(value)
        if #str > maxLength then
            return str:sub(1, maxLength - 3) .. "..."
        end
        return str
    end

    local embed = {
        ["title"] = "🐞 DEBUG: " .. (label or "Unknown"),
        ["color"] = 15158332,
        ["fields"] = {
            {
                ["name"] = "📝 Raw Text",
                ["value"] = "```" .. formatField(rawText, 100) .. "```",
                ["inline"] = false
            },
            {
                ["name"] = "🧹 Clean Text",
                ["value"] = "```" .. formatField(cleanText, 100) .. "```",
                ["inline"] = false
            },
            {
                ["name"] = "👤 Player",
                ["value"] = formatField(fisher, 50),
                ["inline"] = true
            },
            {
                ["name"] = "🎣 Fish Name",
                ["value"] = formatField(fishName, 50),
                ["inline"] = true
            },
            {
                ["name"] = "⚖️ Weight",
                ["value"] = formatField(weight, 30),
                ["inline"] = true
            },
            {
                ["name"] = "🎲 Chance",
                ["value"] = formatField(chance, 30),
                ["inline"] = true
            }
        },
        ["footer"] = {
            ["text"] = "Timestamp: " .. timestamp
        }
    }

    local data = {
        ["content"] = "🐞 **DEBUG DATA RECEIVED**",
        ["embeds"] = {embed}
    }

    local jsonData = HTTPService:JSONEncode(data)

    local success, result = pcall(function()
        return request({
            Url = WEBHOOK_CAUGHT,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    if not success then
        warn("[DEBUG ERROR] Failed to send debug:", result)
    else
        print("🐞 DEBUG SENT!")
    end
end

------------------------------------------------------
-- EVENT HANDLERS
------------------------------------------------------

local function watchEvent(obj)
    if obj:IsA("ImageButton") or obj:IsA("ImageLabel") then
        obj.Changed:Connect(function(prop)
            if prop == "Visible" then
                local eventName = obj.Name
                if obj.Visible then
                    sendEvent(
                        string.format("**Event Active!**\n**Event Name:** %s\n**Status:** 🟢 ACTIVE", eventName),
                        "event_active", true)
                else
                    sendEvent(
                        string.format("**Event Ended!**\n**Event Name:** %s\n**Status:** 🔴 INACTIVE", eventName),
                        "event_inactive", false)
                end
            end
        end)
    end
end

game:GetService("TextChatService").OnIncomingMessage = function(msg)
    local rawText = msg.Text
    local clean = stripRichText(rawText)

    if clean:find("obtained a") and clean:find("kg") then
        local fisher = extractPlayer(clean)
        local fishName, weight = extractFishInfo(clean)
        local chance = extractChanceInfo(clean)

        if fisher and fishName and weight and chance then
            print("🎣 Fish detected: " .. fishName .. " (" .. weight .. ") - Chance: 1 in " .. chance)

            local itemData = getItemData(fishName)

            local iconUrl = nil
            if itemData and itemData.Data and itemData.Data.Icon then
                local iconId = string.match(itemData.Data.Icon, "rbxassetid://(%d+)")
                if iconId then
                    iconUrl = "https://assetdelivery.roblox.com/v1/asset/?id=" .. iconId
                end
            end

            local tierName = "Unknown"
            local tierNumber = 0
            if itemData and itemData.Data and itemData.Data.Tier then
                tierNumber = itemData.Data.Tier
                tierName = getTierName(tierNumber) or "Unknown"
            end

            sendFishCaught(fisher, fishName, weight, chance, tierName, tierNumber, iconUrl)
        else
            print("❌ Failed to extract fish info from message")
            sendDebug("Parsing Failed", rawText, clean, fisher, fishName, weight, chance)
        end
    end
end

------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------

-- Initialize event watchers
for _, obj in ipairs(eventsFolder:GetDescendants()) do
    watchEvent(obj)
end

eventsFolder.DescendantAdded:Connect(watchEvent)

serverGui.Changed:Connect(function(prop)
    if prop == "Visible" then
        if serverGui.Visible then
            sendEvent("**🍀 SERVER LUCK ACTIVE!**\nServer Luck event is now active!", "event_active", true)
        else
            sendEvent("**🍀 SERVER LUCK ENDED!**\nServer Luck event has ended.", "event_inactive", false)
        end
    end
end)

luckCounter:GetPropertyChangedSignal("Text"):Connect(function()
    local luckValue = luckCounter.Text
    print("[LUCK COUNTER] Text:", luckValue)
    sendEvent(string.format("**🍀 SERVER LUCK UPDATE**\n**Current Luck:** %s", luckValue), "server_luck", false)
end)

-- Test API connection on startup
local function testAPIConnection()
    local accounts = getAllAccounts()
    if accounts and accounts.success then
        print("✅ API Connection Successful! Found " .. #accounts.data .. " accounts")
        sendEvent("🚀 **Script Started**\nMonitoring system activated!\nConnected to API: " .. #accounts.data .. " accounts registered", "script_start", false)
    else
        print("❌ API Connection Failed!")
        sendEvent("🚀 **Script Started**\nMonitoring system activated!\n⚠️ API Connection Failed", "script_start", false)
    end
end

testAPIConnection()
