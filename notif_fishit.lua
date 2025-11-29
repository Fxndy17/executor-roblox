local Players = game:GetService("Players")
local HTTPService = game:GetService("HttpService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local PLACE_ID = game.PlaceId
local PLACE_NAME = game:GetService("MarketplaceService"):GetProductInfo(PLACE_ID).Name

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiers = require(game:GetService("ReplicatedStorage").Tiers)

local eventsFrame = gui:WaitForChild("Events"):WaitForChild("Frame")
local eventsFolder = eventsFrame:WaitForChild("Events")
local serverLuck = eventsFrame:WaitForChild("Server Luck")
local serverGui = serverLuck:WaitForChild("Server")
local luckCounter = serverGui:WaitForChild("LuckCounter")

local WEBHOOK_PLAYER =
    "https://discord.com/api/webhooks/1444328790019936499/DKycW0JnIeXZoZqM1zu3g3TsweCYWtKu_DfIhB_zzEN6GkHswBYfK4vzCj-pfrHKH6fS"
local WEBHOOK_CAUGHT =
    "https://discord.com/api/webhooks/1443775157381365903/aQmPT3LS58OrBQxiuHH5ChntyR0XhaEFxNDxkNHCZxEGzyaeMyCcjq2e_RwzUXmaldUJ"
local WEBHOOK_EVENT =
    "https://discord.com/api/webhooks/1443775782596903044/M8DKjQZ5aizPBzQtT8FHrxRyAqXnO-e_lJq2_vLsAtFPRLLVDoqF5bpQ8k5LIc1iX42o"
local API_BASE_URL = "https://fishitapi-production.up.railway.app/api"

local ITEM_CACHE = {}
local EVENT_CACHE = {}
local PLAYER_JOIN_TIME = {}

local function getPlayerInfo(player)
    local joinTime = PLAYER_JOIN_TIME[player.UserId] or os.time()
    local playTime = os.time() - joinTime

    local hours = math.floor(playTime / 3600)
    local minutes = math.floor((playTime % 3600) / 60)
    local seconds = playTime % 60

    local playTimeFormatted = ""
    if hours > 0 then
        playTimeFormatted = string.format("%dh %dm %ds", hours, minutes, seconds)
    elseif minutes > 0 then
        playTimeFormatted = string.format("%dm %ds", minutes, seconds)
    else
        playTimeFormatted = string.format("%ds", seconds)
    end

    return {
        userId = player.UserId,
        username = player.Name,
        displayName = player.DisplayName,
        accountAge = player.AccountAge,
        joinTime = joinTime,
        playTime = playTimeFormatted
    }
end

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

local function getEventsData(eventName)
    if EVENT_CACHE[eventName] then
        return EVENT_CACHE[eventName]
    end

    local eventsFolder = ReplicatedStorage:WaitForChild("Events")
    if not eventsFolder then
        return nil
    end

    local eventModule = eventsFolder:FindFirstChild(eventName)

    if not eventModule then
        eventModule = findSimilarChild(eventsFolder, eventName)
    end

    if eventModule and eventModule:IsA("ModuleScript") then
        local success, eventData = pcall(function()
            return require(eventModule)
        end)

        if success and eventData then
            EVENT_CACHE[eventName] = eventData
            return eventData
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

    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(onlinePlayerNames, player.Name:lower())
    end

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

local function sendFishCaught(fisher, fishName, weight, chance, tierName, tierNumber, iconId)
    if tierNumber <= 4 then
        return
    end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local userAccount = findUserByRobloxUsername(fisher)
    local plr = getPlayer(fisher)

    if not userAccount or not userAccount.settings.notif_caught then
        print("ℹ️ Skipping notification for", fisher, "- User not registered or notifications disabled")
        return
    end

    local playerDisplay = fisher

    local color = 5814783
    local tierData = getTierData(tierNumber)
    if tierData and tierData.Color then
        color = tierData.Color
    end

    local function fetchIconWithRetry(iconId, maxRetries)
        local retries = 0

        while retries < maxRetries do
            local thumbnailUrl = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. iconId ..
                                     "&returnPolicy=PlaceHolder&size=420x420&format=webp"

            local success, response = pcall(function()
                return request({
                    Url = thumbnailUrl,
                    Method = "GET"
                })
            end)

            if success and response.Success then
                local thumbnailData = HTTPService:JSONDecode(response.Body)
                if thumbnailData and thumbnailData.data and #thumbnailData.data > 0 then
                    local fetchedUrl = thumbnailData.data[1].imageUrl
                    print("✅ Image loaded from Roblox API (Attempt " .. (retries + 1) .. "):", fetchedUrl)
                    return fetchedUrl
                else
                    print("⚠️ No image data found for iconId:", iconId, "- Attempt", (retries + 1))
                end
            else
                print("❌ Failed to fetch image for iconId:", iconId, "- Attempt", (retries + 1), "- Error:", response)
            end

            retries = retries + 1

            if retries < maxRetries then
                wait(1) 
            end
        end

        return nil 
    end

    local leaderstats = plr.leaderstats
    local rareFish = leaderstats["Rarest Fish"].Value
    local caught = leaderstats["Caught"].Value

    local embed = {
        ["title"] = "🎣 FISH CAUGHT!",
        ["color"] = color,

        ["fields"] = {{
            ["name"] = "👤 Player",
            ["value"] = playerDisplay,
            ["inline"] = true
        }, {
            ["name"] = "🐟 Fish",
            ["value"] = fishName,
            ["inline"] = true
        }, {
            ["name"] = "⚖️ Weight",
            ["value"] = tostring(weight),
            ["inline"] = true
        }, {
            ["name"] = "🎲 Chance",
            ["value"] = "1 in " .. tostring(chance),
            ["inline"] = true
        }, {
            ["name"] = "⭐ Tier",
            ["value"] = string.format("%s (Tier %d)", tierName, tierNumber),
            ["inline"] = true
        }, {
            ["name"] = "👑 Rarest Fish",
            ["value"] = tostring(rareFish),
            ["inline"] = true
        }, {
            ["name"] = "📦 Total Caught",
            ["value"] = tostring(caught),
            ["inline"] = true
        }},

        ["footer"] = {
            ["text"] = "Timestamp: " .. timestamp
        }
    }

    if iconId then
        local fetchedUrl = fetchIconWithRetry(iconId, 3) 

        local iconUrl = "https://i.pinimg.com/736x/bb/a6/8e/bba68ed1c87ee67b4ee324e243603c8a.jpg" 

        if fetchedUrl then
            iconUrl = fetchedUrl
        else
            print("🚨 All attempts failed to fetch image for iconId:", iconId, "- Using fallback image")
        end

        embed["thumbnail"] = {
            ["url"] = iconUrl
        }
    else
        print("ℹ️ No iconId provided, skipping image")
    end

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

local function sendScriptStatusEmbed(status, accountsCount)
    local color = status == "success" and 3066993 or 15158332
    local title = status == "success" and "🚀 Script Started Successfully" or "⚠️ Script Started with Issues"

    local description = status == "success" and
                            string.format("Monitoring system activated!\nConnected to API: **%d accounts** registered",
            accountsCount) and "Monitoring system activated!\n⚠️ API Connection Failed"

    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["thumbnail"] = {
            ["url"] = "https://i.pinimg.com/736x/bb/a6/8e/bba68ed1c87ee67b4ee324e243603c8a.jpg"
        },
        ["footer"] = {
            ["text"] = "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S")
        }
    }

    local data = {
        ["embeds"] = {embed}
    }

    local jsonData = HTTPService:JSONEncode(data)

    pcall(function()
        request({
            Url = WEBHOOK_EVENT,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    print("✅ Script status notification sent")
end

local function sendServerLuckEmbed(luckValue, eventType)
    local color = 5814783
    local title = "🍀 Server Luck"

    local description = ""
    if eventType == "active" then
        description = "**SERVER LUCK EVENT ACTIVE!**\nServer Luck event is now active!"
        color = 3066993
    elseif eventType == "ended" then
        description = "**SERVER LUCK EVENT ENDED!**\nServer Luck event has ended."
        color = 15158332
    else
        description = string.format("**SERVER LUCK UPDATE**\n**Current Luck:** %s", luckValue)
    end

    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["thumbnail"] = {
            ["url"] = "https://i.pinimg.com/736x/bb/a6/8e/bba68ed1c87ee67b4ee324e243603c8a.jpg"
        },
        ["footer"] = {
            ["text"] = "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S")
        }
    }

    local data = {
        ["embeds"] = {embed}
    }

    local jsonData = HTTPService:JSONEncode(data)

    pcall(function()
        request({
            Url = WEBHOOK_EVENT,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    print("✅ Server luck notification sent")
end

local function sendEvent(eventName, enabled, pingEveryone)
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
    if enabled then
        color = 3066993 -- Hijau
    else
        color = 15158332 -- Merah
    end

    local content = ""
    if pingEveryone and mentions ~= "" then
        content = mentions .. " 🎮 **EVENT NOTIFICATION!**"
    elseif pingEveryone then
        content = "🎮 **EVENT NOTIFICATION!**"
    end

    local eventData = getEventsData(eventName) 
    local durationMinutes = eventData and eventData.Duration and math.floor(eventData.Duration / 60) or 0

    local modifiersText = ""
    if eventData and eventData.Modifiers then
        for key, value in pairs(eventData.Modifiers) do
            modifiersText = modifiersText .. string.format("**%s:** +%s\n", key, tostring(value))
        end
    end

    local additionalInfo = ""

    if eventData and eventData.Variants and #eventData.Variants > 0 then
        additionalInfo = additionalInfo ..
                             string.format("**🎭 Variants:** %s\n", table.concat(eventData.Variants, ", "))
    end

    if eventData and eventData.GlobalFish and #eventData.GlobalFish > 0 then
        additionalInfo = additionalInfo ..
                             string.format("**🐟 Global Fish:** %s\n", table.concat(eventData.GlobalFish, ", "))
    end

    if eventData and eventData.LinkedEvents and eventData.LinkedEvents.Modifiers then
        for eventName, modifiers in pairs(eventData.LinkedEvents.Modifiers) do
            additionalInfo = additionalInfo .. string.format("**🔗 Linked Event - %s:**\n", eventName)
            for modKey, modValue in pairs(modifiers) do
                additionalInfo = additionalInfo .. string.format("  • **%s:** +%s\n", modKey, tostring(modValue))
            end
        end
    end

    if eventData and eventData.Coordinates and #eventData.Coordinates > 0 then
        local coordStrings = {}
        for i, coord in ipairs(eventData.Coordinates) do
            table.insert(coordStrings, string.format("(%.0f, %.0f, %.0f)", coord.X, coord.Y, coord.Z))
        end
        additionalInfo = additionalInfo .. string.format("**📍 Coordinates:** %s\n", table.concat(coordStrings, ", "))
    end

    if eventData and eventData.Tier then
        additionalInfo = additionalInfo .. string.format("**⭐ Tier:** %s\n", tostring(eventData.Tier))
    end

    local message = string.format("⭐ **EVENT ACTIVE: %s**\n%s\n\n**🕒 Duration:** %s minutes\n%s%s%s",
        eventData and eventData.Name or "Unknown Event", eventData and eventData.Description or "", durationMinutes,
        modifiersText ~= "" and "**📊 Modifiers:**\n" .. modifiersText .. "\n" or "", additionalInfo ~= "" and
            "**📋 Event Details:**\n" .. additionalInfo .. "\n" or "", eventData and eventData.GlobalDescription and
            "**🌍 Global Effect:** " .. eventData.GlobalDescription or "")

    local iconId = nil
    if eventData and eventData.Icon then
        iconId = string.match(eventData.Icon, "rbxassetid://(%d+)")
    end

    local iconUrl = "https://i.pinimg.com/736x/bb/a6/8e/bba68ed1c87ee67b4ee324e243603c8a.jpg"

    local function fetchIconWithRetry(iconId, maxRetries)
        local retries = 0

        while retries < maxRetries do
            local thumbnailUrl = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. iconId ..
                                     "&returnPolicy=PlaceHolder&size=420x420&format=webp"

            local success, response = pcall(function()
                return request({
                    Url = thumbnailUrl,
                    Method = "GET"
                })
            end)

            if success and response.Success then
                local thumbnailData = HTTPService:JSONDecode(response.Body)
                if thumbnailData and thumbnailData.data and #thumbnailData.data > 0 then
                    local fetchedUrl = thumbnailData.data[1].imageUrl
                    print("✅ Image loaded from Roblox API (Attempt " .. (retries + 1) .. "):", fetchedUrl)
                    return fetchedUrl
                else
                    print("⚠️ No image data found for iconId:", iconId, "- Attempt", (retries + 1))
                end
            else
                print("❌ Failed to fetch image for iconId:", iconId, "- Attempt", (retries + 1), "- Error:", response)
            end

            retries = retries + 1

            if retries < maxRetries then
                wait(1) 
            end
        end

        return nil
    end

    if iconId then
        local fetchedUrl = fetchIconWithRetry(iconId, 3) 

        if fetchedUrl then
            iconUrl = fetchedUrl
        else
            print("🚨 All attempts failed to fetch image for iconId:", iconId, "- Using fallback image")
        end
    else
        print("ℹ️ No iconId found, using fallback image")
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
                ["url"] = iconUrl
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
        if not value then
            return "nil"
        end
        local str = tostring(value)
        if #str > maxLength then
            return str:sub(1, maxLength - 3) .. "..."
        end
        return str
    end

    local embed = {
        ["title"] = "🐞 DEBUG: " .. (label or "Unknown"),
        ["color"] = 15158332,
        ["fields"] = {{
            ["name"] = "📝 Raw Text",
            ["value"] = "```" .. formatField(rawText, 100) .. "```",
            ["inline"] = false
        }, {
            ["name"] = "🧹 Clean Text",
            ["value"] = "```" .. formatField(cleanText, 100) .. "```",
            ["inline"] = false
        }, {
            ["name"] = "👤 Player",
            ["value"] = formatField(fisher, 50),
            ["inline"] = true
        }, {
            ["name"] = "🎣 Fish Name",
            ["value"] = formatField(fishName, 50),
            ["inline"] = true
        }, {
            ["name"] = "⚖️ Weight",
            ["value"] = formatField(weight, 30),
            ["inline"] = true
        }, {
            ["name"] = "🎲 Chance",
            ["value"] = formatField(chance, 30),
            ["inline"] = true
        }},
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

local function watchEvent(obj)
    if obj:IsA("ImageButton") or obj:IsA("ImageLabel") then
        obj.Changed:Connect(function(prop)
            if prop == "Visible" then
                local eventName = obj.Name
                sendEvent(eventName, obj.Visible, not obj.Visible)
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

            local iconId = nil
            if itemData and itemData.Data and itemData.Data.Icon then
                iconId = string.match(itemData.Data.Icon, "rbxassetid://(%d+)")
            end

            local tierName = "Unknown"
            local tierNumber = 0
            if itemData and itemData.Data and itemData.Data.Tier then
                tierNumber = itemData.Data.Tier
                tierName = getTierName(tierNumber) or "Unknown"
            end

            sendFishCaught(fisher, fishName, weight, chance, tierName, tierNumber, iconId)
        else
            print("❌ Failed to extract fish info from message")
            sendDebug("Parsing Failed", rawText, clean, fisher, fishName, weight, chance)
        end
    end
end

for _, obj in ipairs(eventsFolder:GetDescendants()) do
    watchEvent(obj)
end

eventsFolder.DescendantAdded:Connect(watchEvent)

serverGui.Changed:Connect(function(prop)
    if prop == "Visible" then
        if serverGui.Visible then
            sendServerLuckEmbed("", "active")
        else
            sendServerLuckEmbed("", "ended")
        end
    end
end)

luckCounter:GetPropertyChangedSignal("Text"):Connect(function()
    local luckValue = luckCounter.Text
    print("[LUCK COUNTER] Text:", luckValue)
    sendServerLuckEmbed(luckValue, "update")
end)

local function getServerInfo()
    local players = Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers

    return {
        placeName = PLACE_NAME,
        placeId = PLACE_ID,
        jobId = game.JobId,
        playerCount = #players,
        maxPlayers = maxPlayers,
        serverLoad = math.floor((#players / maxPlayers) * 100)
    }
end

local function sendPlayerWebhook(player, action)
    local playerInfo = getPlayerInfo(player)
    local serverInfo = getServerInfo()

    local userAccount = findUserByRobloxUsername(player.Name)

    local color = action == "join" and 3066993 or 15158332 -- Green for join, Red for leave
    local title = action == "join" and "🟢 Player Joined" or "🔴 Player Left"
    local description = action == "join" and "A player has joined the game" or "A player has left the game"

    local content = ""
    if userAccount then
        content = "<@" .. userAccount.id_discord .. "> "
    end
    content = content .. (action == "join" and "**🟢 JOINED THE GAME!**" or "**🔴 LEFT THE GAME!**")

    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["thumbnail"] = {
            ["url"] = string.format(
                "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png",
                playerInfo.userId)
        },
        ["fields"] = {{
            ["name"] = "👤 Player Info",
            ["value"] = string.format("**Username:** %s\n**Display Name:** %s\n**User ID:** %d", playerInfo.username,
                playerInfo.displayName, playerInfo.userId),
            ["inline"] = true
        }, {
            ["name"] = "📊 Account Info",
            ["value"] = string.format("**Account Age:** %d days\n**Play Time:** %s", playerInfo.accountAge,
                playerInfo.playTime),
            ["inline"] = true
        }, {
            ["name"] = "🎮 Server Info",
            ["value"] = string.format("**Server:** %s\n**Players:** %d/%d (%d%%)", serverInfo.placeName,
                serverInfo.playerCount, serverInfo.maxPlayers, serverInfo.serverLoad),
            ["inline"] = false
        }},
        ["footer"] = {
            ["text"] = string.format("Server ID: %s | %s", serverInfo.jobId, os.date("%Y-%m-%d %H:%M:%S"))
        }
    }

    local data = {
        ["content"] = content,
        ["embeds"] = {embed}
    }

    local jsonData = HTTPService:JSONEncode(data)

    local success, result = pcall(function()
        return request({
            Url = WEBHOOK_PLAYER,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    if success then
        print(string.format("✅ %s notification sent for: %s", action:upper(), player.Name))
    else
        warn(string.format("❌ Failed to send %s notification: %s", action, result))
    end
end

local function onPlayerAdded(player)
    PLAYER_JOIN_TIME[player.UserId] = os.time()

    wait(2)

    sendPlayerWebhook(player, "join")

    player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            sendPlayerWebhook(player, "leave")
            PLAYER_JOIN_TIME[player.UserId] = nil
        end
    end)
end

local function onPlayerRemoving(player)
    sendPlayerWebhook(player, "leave")
    PLAYER_JOIN_TIME[player.UserId] = nil
end

local function sendServerStartNotification()
    local serverInfo = getServerInfo()

    local embed = {
        ["title"] = "🚀 Server Started",
        ["description"] = "Game server is now online",
        ["color"] = 3447003, -- Blue
        ["fields"] = {{
            ["name"] = "🎮 Server Information",
            ["value"] = string.format("**Game:** %s\n**Place ID:** %d\n**Max Players:** %d", serverInfo.placeName,
                serverInfo.placeId, serverInfo.maxPlayers),
            ["inline"] = true
        }, {
            ["name"] = "📊 Current Status",
            ["value"] = string.format("**Players Online:** %d\n**Server Load:** %d%%", serverInfo.playerCount,
                serverInfo.serverLoad),
            ["inline"] = true
        }},
        ["footer"] = {
            ["text"] = string.format("Server ID: %s | %s", serverInfo.jobId, os.date("%Y-%m-%d %H:%M:%S"))
        }
    }

    local data = {
        ["embeds"] = {embed}
    }

    local jsonData = HTTPService:JSONEncode(data)

    pcall(function()
        request({
            Url = WEBHOOK_PLAYER,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    print("✅ Server start notification sent")
end

sendServerStartNotification()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
    PLAYER_JOIN_TIME[player.UserId] = os.time()
end

local function testAPIConnection()
    local accounts = getAllAccounts()
    if accounts and accounts.success then
        print("API Connection Successful! Found " .. #accounts.data .. " accounts")
        sendScriptStatusEmbed("success", #accounts.data)
    else
        print("API Connection Failed!")
        sendScriptStatusEmbed("failed", 0)
    end
end

testAPIConnection()
