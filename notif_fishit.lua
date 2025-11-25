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
    "https://discord.com/api/webhooks/1442898386406739989/FweK2dBOkVYZT4rqqrORf8exi1ofVl30xU7Fhfh2C2NwbDu7enURhnz8f49WRv6r7_O0"
local API_BASE_URL = "https://fishitapi-production.up.railway.app/api" -- Ganti dengan URL API kamu

local ITEM_CACHE = {}

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
        -- cek USERNAME lowercase
        if plr.Name:lower() == query then
            return plr
        end
        
        -- cek DISPLAYNAME lowercase
        if plr.DisplayName:lower() == query then
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

local function getTierDataByName(tierName)
    for _, tierData in ipairs(Tiers) do
        if tierData.Name == tierName then
            return tierData
        end
    end
    return nil
end

------------------------------------------------------
-- API
------------------------------------------------------

local function getAllUsers()
    local success, result = pcall(function()
        local response = request({
            Url = API_BASE_URL .. "/users",
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json"
            }
        })
        
        if response and response.StatusCode == 200 then
            local decoded = HTTPService:JSONDecode(response.Body)
            return decoded
        else
            warn("[API] Request failed:", response.StatusCode, response.Body)
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
            warn("[API] Request failed for notifications:", response.StatusCode, response.Body)
            return nil
        end
    end)
    
    if not success then
        warn("[API] PCall failed for notifications:", result)
        return nil
    end
    
    return result
end

local function findUserByRoblox(username)
    local plr = getPlayer(username)

    if plr == nil then
        print("not found player")
        return
    end

    local allUsers = getAllUsers()
    if not allUsers or not allUsers.success then
        return nil
    end

    for _, user in ipairs(allUsers.data) do
        if user.id_roblox and tonumber(user.id_roblox) == tonumber(plr.userId)  then
            return user
        end
    end
    return nil
end

local function generateUserMentions(users)
    local mentions = {}
    for _, user in ipairs(users) do
        table.insert(mentions, "<@" .. user.id_discord .. ">")
    end
    return table.concat(mentions, " ")
end

------------------------------------------------------
-- SEND FISH CAUGHT TO DISCORD WEBHOOK
------------------------------------------------------
local function sendFishCaught(fisher, fishName, weight, chance, tierName, tierNumber, iconUrl)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    -- Cari user berdasarkan Roblox username
    local user = findUserByRoblox(fisher)

    -- JIKA USER TIDAK DITEMUKAN, GUNAKAN NAMA ASLI TANPA MENTION
    local playerDisplay = fisher -- Default: pakai nama asli dari game

    -- JIKA USER DITEMUKAN DAN NOTIF_CAUGHT = TRUE, BARU KASIH MENTION
    local shouldPingUser = user and user.settings.notif_caught
    if shouldPingUser then
        playerDisplay = "<@" .. user.id_discord .. ">"
    else
        return;
    end

    local color = 5814783
    local tierData = getTierData(tierNumber)
    if tierData and tierData.Color then
        color = tierData.Color
    end

    local embed = {
        ["title"] = "🎣 FISH CAUGHT!",
        ["description"] = string.format(
            "**Player:** %s\n**Fish:** %s\n**Weight:** %s kg\n**Chance:** 1 in %s\n**Tier:** %s (Tier %d)",
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

    -- Tentukan content berdasarkan kondisi
    local content = ""
    if shouldPingUser then
        content = "<@" .. user.id_discord .. "> 🎣 **FISH CAUGHT!**"
    end

    local data = {
        ["content"] = content,
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
        if user then
            print("   Player: " .. user.username_roblox .. " (Registered)")
            print("   Notif Caught: " .. tostring(user.settings.notif_caught))
        else
            print("   Player: " .. fisher .. " (Not Registered)")
        end
    end
end

------------------------------------------------------
-- SEND EVENT TO DISCORD WEBHOOK
------------------------------------------------------
local function sendEvent(message, eventType, pingEveryone)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    -- Hanya cari user yang punya notif_weather enabled JIKA pingEveryone = true
    local mentions = ""
    if pingEveryone then
        local weatherUsers = getUsersWithNotification("notif_weather", true)
        if weatherUsers and weatherUsers.success and #weatherUsers.data > 0 then
            local mentionList = {}
            for _, user in ipairs(weatherUsers.data) do
                table.insert(mentionList, "<@" .. user.id_discord .. ">")
            end
            mentions = table.concat(mentionList, ", ") -- Format: @user1, @user2, @user3
        end
    end

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

    local content = ""
    if pingEveryone then
        if mentions ~= "" then
            content = mentions .. " 🎮 **EVENT NOTIFICATION!**"
        else
            -- Jika tidak ada user dengan notif_weather, tetap kasih pesan tanpa mention
            content = "🎮 **EVENT NOTIFICATION!**"
        end
    else
        content = "" -- No ping untuk event non-aktif
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
-- SEND DEBUG DATA KE DISCORD WEBHOOK
------------------------------------------------------
local function sendDebug(label, rawText, cleanText, fisher, fishName, weight, chance)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    -- Format field values dengan batasan karakter
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
        ["color"] = 15158332, -- merah
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
            Url = WEBHOOK_URL,
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
-- REMOVE RICH TEXT FROM STRING (<b>, <font>, etc)
------------------------------------------------------
local function stripRichText(str)
    return (str:gsub("<[^>]->", ""))
end

------------------------------------------------------
-- CHAT PARSER (CLEAN CHAT)
------------------------------------------------------
game:GetService("TextChatService").OnIncomingMessage = function(msg)
    local rawText = msg.Text
    local clean = stripRichText(rawText)

    if clean:find("obtained a") and clean:find("kg") then
        local fisher = extractPlayer(clean)
        local fishName, weight = extractFishInfo(clean)
        local chance = extractChanceInfo(clean)

        if fisher and fishName and weight and chance then
            print("🎣 Fish detected: " .. fishName .. " (" .. weight .. " kg) - Chance: 1 in " .. chance)

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
            sendEvent("**🍀 SERVER LUCK ACTIVE!**\nServer Luck event is now active!", "event_active", true)
        else
            sendEvent("**🍀 SERVER LUCK ENDED!**\nServer Luck event has ended.", "event_inactive", false)
        end
    end
end)

------------------------------------------------------
-- WATCH LUCKCOUNTER TEXT CHANGE
------------------------------------------------------
luckCounter:GetPropertyChangedSignal("Text"):Connect(function()
    local luckValue = luckCounter.Text
    print("[LUCK COUNTER] Text:", luckValue)

    sendEvent(string.format("**🍀 SERVER LUCK UPDATE**\n**Current Luck:** %s", luckValue), "server_luck", false)
end)

-- Test API connection on startup
local function testAPIConnection()
    local users = getAllUsers()
    if users and users.success then
        print("✅ API Connection Successful! Found " .. #users.data .. " users")
        sendEvent("🚀 **Script Started**\nMonitoring system activated!\nConnected to API: " .. #users.data ..
                      " users registered", "script_start", false)
    else
        print("❌ API Connection Failed!")
        sendEvent("🚀 **Script Started**\nMonitoring system activated!\n⚠️ API Connection Failed", "script_start",
            false)
    end
end

testAPIConnection()
