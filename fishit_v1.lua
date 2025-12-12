local Players = game:GetService("Players")
local HTTPService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

-- Configuration
local PLACE_ID = game.PlaceId
local PLACE_NAME = MarketplaceService:GetProductInfo(PLACE_ID).Name
local Tiers = require(ReplicatedStorage.Tiers)

-- UI References
local eventsFrame = gui:WaitForChild("Events"):WaitForChild("Frame")
local eventsFolder = eventsFrame:WaitForChild("Events")
local serverLuck = eventsFrame:WaitForChild("Server Luck")
local serverGui = serverLuck:WaitForChild("Server")
local luckCounter = serverGui:WaitForChild("LuckCounter")
local hudScrollingFrame = gui.HUD.Frame.Frame.Inside.ScrollingFrame

-- Webhooks
local WEBHOOK_PLAYER = "https://discord.com/api/webhooks/1448855276588499074/2SOhJPAJ3opHZiNrnhqybVkBucd9466nRVPNtIWkOQZXZp1icJv0n3L2dDJr8aJw5g-m"
local WEBHOOK_CAUGHT = "https://discord.com/api/webhooks/1448855116751835282/AQrdU0AnZQkHsBqPV1Xioe7n7vceCjOnEuG-_2e_rg1_Y9Ztvxf4eTVHGDgCCFRKmH16"
local WEBHOOK_EVENT = "https://discord.com/api/webhooks/1448855209928560672/b3ctW9dJYcvNYCj15L6o484N_-WMi8agyjW27PtV6_8-rHH3zkch_5JOcmLeVE31xtS7"
local API_BASE_URL = "https://fishitapi-production.up.railway.app/api"

-- Caches
local itemCache = {}
local eventCache = {}
local playerJoinTime = {}
local adminEventCache = {}

-- Utility Functions
function CleanRichText(str)
    return str:gsub("<[^>]->", "")
end

function FormatPlayDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, secs)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    end
    return string.format("%ds", secs)
end

function IsNameSimilar(baseName, inputName)
    baseName = baseName:lower()
    inputName = inputName:lower()
    if inputName:find(baseName, 1, true) then return true end
    
    for word in baseName:gmatch("%S+") do
        if not inputName:find(word, 1, true) then return false end
    end
    return true
end

function FindSimilarItem(folder, inputName)
    for _, child in ipairs(folder:GetChildren()) do
        if IsNameSimilar(child.Name, inputName) then return child end
    end
    return nil
end

function LoadModule(folder, cache, moduleName)
    if cache[moduleName] then return cache[moduleName] end
    if not folder then return nil end
    
    local module = folder:FindFirstChild(moduleName) or FindSimilarItem(folder, moduleName)
    if module and module:IsA("ModuleScript") then
        local success, data = pcall(require, module)
        if success then
            cache[moduleName] = data
            return data
        end
    end
    return nil
end

function GetFishData(fishName)
    return LoadModule(ReplicatedStorage:WaitForChild("Items"), itemCache, fishName)
end

function GetGameEventData(eventName)
    return LoadModule(ReplicatedStorage:WaitForChild("Events"), eventCache, eventName)
end

function FindPlayerByName(playerName)
    playerName = playerName:lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower() == playerName or plr.DisplayName:lower() == playerName then
            return plr
        end
    end
    return nil
end

function GetTierData(tierNumber)
    for _, tierData in ipairs(Tiers) do
        if tierData.Tier == tierNumber then return tierData end
    end
    return nil
end

-- API Functions
function CallAPI(endpoint, method, body)
    local url = API_BASE_URL .. endpoint
    local options = {
        Url = url,
        Method = method or "GET",
        Headers = {["Content-Type"] = "application/json"}
    }
    
    if body then options.Body = HTTPService:JSONEncode(body) end
    
    local success, response = pcall(request, options)
    if success and response.Success then
        return HTTPService:JSONDecode(response.Body)
    end
    warn("[API] Request failed:", response and response.StatusCode or "No response")
    return nil
end

function GetAllRegisteredAccounts()
    return CallAPI("/accounts")
end

function GetUsersWithNotification(notificationType, enabled)
    return CallAPI(string.format("/notifications/%s?enabled=%s", notificationType, tostring(enabled)))
end

function FindUserAccount(username)
    local plr = FindPlayerByName(username)
    if not plr then return nil end
    
    local accounts = GetAllRegisteredAccounts()
    if not accounts or not accounts.success then return nil end
    
    for _, account in ipairs(accounts.data) do
        if account.id_roblox and tonumber(account.id_roblox) == plr.UserId then
            return account
        end
    end
    return nil
end

function GetOnlineNotifiedUsers(notificationType, enabled)
    local notificationUsers = GetUsersWithNotification(notificationType, enabled)
    if not notificationUsers or not notificationUsers.success then return {} end
    
    local onlinePlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        onlinePlayers[player.Name:lower()] = true
    end
    
    local result = {}
    for _, user in ipairs(notificationUsers.data) do
        for _, account in ipairs(user.roblox_accounts or {}) do
            if account.username_roblox and onlinePlayers[account.username_roblox:lower()] then
                table.insert(result, user)
                break
            end
        end
    end
    
    return result
end

-- Discord Functions
function SendToDiscord(webhookUrl, data)
    local jsonData = HTTPService:JSONEncode(data)
    
    local success, response = pcall(function()
        return request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
    end)
    
    if success then
        print("✅ Webhook sent to:", webhookUrl)
        return response
    end
    warn("[WEBHOOK] Failed to send to:", webhookUrl, response)
    return nil
end

function GetImageFromRoblox(assetId, maxRetries)
    local thumbnailUrl = string.format(
        "https://thumbnails.roblox.com/v1/assets?assetIds=%d&returnPolicy=PlaceHolder&size=420x420&format=webp",
        assetId
    )
    
    for attempt = 1, maxRetries do
        local success, response = pcall(request, {Url = thumbnailUrl, Method = "GET"})
        
        if success and response.Success then
            local data = HTTPService:JSONDecode(response.Body)
            if data and data.data and #data.data > 0 then
                return data.data[1].imageUrl
            end
        end
        
        if attempt < maxRetries then wait(1) end
    end
    
    return nil
end

-- Admin Event Functions
function SendAdminEventNotification(eventData, eventStatus)
    local statusColors = {
        new = 65280,        -- Hijau
        update = 16776960,  -- Kuning
        ended = 16711680    -- Merah
    }
    
    local embed = {
        title = "ADMIN EVENT",
        color = statusColors[eventStatus] or 5814783,
        fields = {},
        footer = {text = os.date("🕒 %Y-%m-%d %H:%M:%S")}
    }
    
    -- Tambahkan field yang ada
    if eventData.eventName and eventData.eventName ~= "" then
        table.insert(embed.fields, {
            name = "📝 Event Name",
            value = eventData.eventName,
            inline = true
        })
    end
    
    if eventData.description and eventData.description ~= "" then
        table.insert(embed.fields, {
            name = "📄 Description",
            value = eventData.description,
            inline = false
        })
    end
    
    if eventData.reqLevel and eventData.reqLevel ~= "" then
        table.insert(embed.fields, {
            name = "🎯 Required Level",
            value = eventData.reqLevel,
            inline = true
        })
    end
    
    if eventData.time and eventData.time ~= "" then
        table.insert(embed.fields, {
            name = "⏰ Time",
            value = eventData.time,
            inline = true
        })
    end
    
    local webhookData = {
        content = eventStatus == "new" and "@everyone **ADMIN EVENT!**" or "",
        embeds = {embed}
    }
    
    SendToDiscord(WEBHOOK_EVENT, webhookData)
end

function TrackAdminEventField(obj, eventId, fieldName)
    if not obj or not obj:IsA("TextLabel") then return end
    
    adminEventCache[eventId][fieldName] = obj.Text
    
    obj.Changed:Connect(function(prop)
        if prop == "Text" then
            adminEventCache[eventId][fieldName] = obj.Text
            SendAdminEventNotification(adminEventCache[eventId], "update")
        end
    end)
end

function FindObjectInHierarchy(parent, path)
    local current = parent
    for _, name in ipairs(path) do
        current = current and current:FindFirstChild(name)
    end
    return current
end

function SetupAdminEventMonitor(eventFrame)
    local eventId = tostring(eventFrame:GetDebugId())
    
    adminEventCache[eventId] = {
        title = "",
        eventName = "",
        description = "",
        reqLevel = "",
        time = ""
    }
    
    -- Track semua field di event frame
    local fieldTracking = {
        {path = {"Inside", "Content", "Top", "TextLabel"}, field = "title"},
        {path = {"Inside", "Content", "Bottom", "Display", "Header"}, field = "eventName"},
        {path = {"Inside", "Content", "Bottom", "Description"}, field = "description"},
        {path = {"Inside", "Content", "Bottom", "Info", "ReqLevel"}, field = "reqLevel"},
        {path = {"Inside", "Content", "Bottom", "Info", "Timer"}, field = "time"}
    }
    
    for _, trackingInfo in ipairs(fieldTracking) do
        local obj = FindObjectInHierarchy(eventFrame, trackingInfo.path)
        TrackAdminEventField(obj, eventId, trackingInfo.field)
    end
    
    -- Kirim notifikasi event baru
    wait(0.5)
    SendAdminEventNotification(adminEventCache[eventId], "new")
    
    -- Cleanup saat event selesai
    eventFrame.AncestryChanged:Connect(function()
        if not eventFrame.Parent then
            SendAdminEventNotification(adminEventCache[eventId], "ended")
            adminEventCache[eventId] = nil
        end
    end)
end

function InitAdminEventTracking()
    -- Monitor event yang sudah ada
    for _, eventFrame in ipairs(hudScrollingFrame:GetChildren()) do
        if eventFrame.Name == "Template" then
            SetupAdminEventMonitor(eventFrame)
        end
    end
    
    -- Monitor event baru
    hudScrollingFrame.ChildAdded:Connect(function(child)
        if child.Name == "Template" then
            wait(0.1)
            SetupAdminEventMonitor(child)
        end
    end)
end

-- Fish Notification
function NotifyFishCaught(fisherName, fishName, weight, chance, tierNumber)
    if tierNumber <= 4 then return end
    
    local player = FindPlayerByName(fisherName)
    if not player then return end
    
    local userAccount = FindUserAccount(fisherName)
    if not userAccount or not userAccount.settings.notif_caught then
        print("ℹ️ Skipping notification for", fisherName)
        return
    end
    
    local fishData = GetFishData(fishName)
    local tierData = GetTierData(tierNumber)
    local leaderstats = player.leaderstats
    
    local embed = {
        title = "🎣 FISH CAUGHT!",
        color = tierData and tierData.Color or 5814783,
        fields = {
            {name = "👤 Player", value = fisherName, inline = true},
            {name = "🐟 Fish", value = fishName, inline = true},
            {name = "⚖️ Weight", value = tostring(weight), inline = true},
            {name = "🎲 Chance", value = "1 in " .. chance, inline = true},
            {name = "⭐ Tier", value = string.format("%s (Tier %d)", tierData and tierData.Name or "Unknown", tierNumber), inline = true},
            {name = "👑 Rarest Fish", value = tostring(leaderstats["Rarest Fish"].Value), inline = true},
            {name = "📦 Total Caught", value = tostring(leaderstats["Caught"].Value), inline = true}
        },
        footer = {text = "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S")}
    }
    
    if fishData and fishData.Data and fishData.Data.Icon then
        local assetId = fishData.Data.Icon:match("rbxassetid://(%d+)")
        if assetId then
            local imageUrl = GetImageFromRoblox(tonumber(assetId), 3) or 
                "https://i.pinimg.com/736x/bb/a6/8e/bba68ed1c87ee67b4ee324e243603c8a.jpg"
            embed.thumbnail = {url = imageUrl}
        end
    end
    
    local data = {
        content = "<@" .. userAccount.id_discord .. "> 🎣 **FISH CAUGHT!**",
        embeds = {embed}
    }
    
    SendToDiscord(WEBHOOK_CAUGHT, data)
    print("✅ Fish caught notification sent for:", fisherName)
end

-- Game Event Notification
function NotifyGameEvent(eventName, isActive)
    local eventData = GetGameEventData(eventName)
    if not eventData then return end
    
    local onlineUsers = GetOnlineNotifiedUsers("notif_weather", true)
    local mentions = ""
    
    if #onlineUsers > 0 then
        local mentionList = {}
        for _, user in ipairs(onlineUsers) do
            table.insert(mentionList, "<@" .. user.id_discord .. ">")
        end
        mentions = table.concat(mentionList, ", ")
    end
    
    local duration = eventData.Duration and math.floor(eventData.Duration / 60) or 0
    local modifiersText = ""
    
    if eventData.Modifiers then
        for key, value in pairs(eventData.Modifiers) do
            modifiersText = modifiersText .. string.format("**%s:** +%s\n", key, tostring(value))
        end
    end
    
    local fields = {
        {name = "🕒 Duration", value = string.format("%s minutes", duration), inline = true}
    }
    
    if modifiersText ~= "" then
        table.insert(fields, {name = "📊 Modifiers", value = modifiersText, inline = false})
    end
    
    local embed = {
        title = isActive and "🎮 Event Started" or "🎮 Event Ended",
        description = string.format("**%s**\n%s", eventData.Name or eventName, eventData.Description or ""),
        color = isActive and 3066993 or 15158332,
        fields = fields,
        footer = {text = "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S")}
    }
    
    if eventData.Icon then
        local assetId = eventData.Icon:match("rbxassetid://(%d+)")
        if assetId then
            local imageUrl = GetImageFromRoblox(tonumber(assetId), 3) or 
                "https://i.pinimg.com/736x/bb/a6/8e/bba68ed1c87ee67b4ee324e243603c8a.jpg"
            embed.thumbnail = {url = imageUrl}
        end
    end
    
    local data = {
        content = #onlineUsers > 0 and mentions .. " 🎮 **EVENT NOTIFICATION!**" or "🎮 **EVENT NOTIFICATION!**",
        embeds = {embed}
    }
    
    SendToDiscord(WEBHOOK_EVENT, data)
    print("✅ Game event notification sent:", eventName)
end

-- Player Notification
function NotifyPlayerStatus(player, action)
    local playDuration = os.time() - (playerJoinTime[player.UserId] or os.time())
    local userAccount = FindUserAccount(player.Name)
    
    local embed = {
        title = action == "join" and "🟢 Player Joined" or "🔴 Player Left",
        color = action == "join" and 3066993 or 15158332,
        thumbnail = {
            url = string.format(
                "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png",
                player.UserId
            )
        },
        fields = {
            {name = "👤 Player Info", value = string.format("**Username:** %s\n**Display Name:** %s\n**User ID:** %d", 
                player.Name, player.DisplayName, player.UserId), inline = true},
            {name = "📊 Account Info", value = string.format("**Account Age:** %d days\n**Play Time:** %s", 
                player.AccountAge, FormatPlayDuration(playDuration)), inline = true},
            {name = "🎮 Server Info", value = string.format("**Server:** %s\n**Players:** %d/%d", 
                PLACE_NAME, #Players:GetPlayers(), Players.MaxPlayers), inline = false}
        },
        footer = {text = string.format("Server ID: %s | %s", game.JobId, os.date("%Y-%m-%d %H:%M:%S"))}
    }
    
    local content = userAccount and action == "leave" and "<@" .. userAccount.id_discord .. "> " or ""
    content = content .. (action == "join" and "**🟢 JOINED THE GAME!**" or "**🔴 LEFT THE GAME!**")
    
    local data = {
        content = content,
        embeds = {embed}
    }
    
    SendToDiscord(WEBHOOK_PLAYER, data)
    print(string.format("✅ Player %s notification sent for: %s", action:upper(), player.Name))
end

-- Chat Processing
function ProcessChatMessage(text)
    local cleanText = CleanRichText(text)
    
    if not (cleanText:find("obtained a") and cleanText:find("kg")) then
        return
    end
    
    local playerName = cleanText:match("%]:%s*(%w+)")
    local fishName = cleanText:match("obtained an?%s+([%w%s%-]+)%s*%(") or cleanText:match("obtained an?%s+(.-)%s*%(")
    local weight = cleanText:match("%(([%d%.]+%s*[KM]?%s*kg?)%)") or cleanText:match("%(([%d%.]+%s*[KM]?)%)")
    local chance = cleanText:match("1 in%s+([%w]+)")
    
    if playerName and fishName and weight and chance then
        local fishData = GetFishData(fishName)
        local tierNumber = fishData and fishData.Data and fishData.Data.Tier or 0
        
        NotifyFishCaught(playerName, fishName, weight, chance, tierNumber)
    end
end

-- UI Element Monitoring
function MonitorUIElement(obj)
    if obj:IsA("ImageButton") or obj:IsA("ImageLabel") then
        obj.Changed:Connect(function(prop)
            if prop == "Visible" then
                NotifyGameEvent(obj.Name, obj.Visible)
            end
        end)
    end
end

-- Server Luck Tracking
serverGui.Changed:Connect(function(prop)
    if prop == "Visible" then
        local embed = {
            title = "🍀 Server Luck",
            description = serverGui.Visible and "**SERVER LUCK EVENT ACTIVE!**" or "**SERVER LUCK EVENT ENDED!**",
            color = serverGui.Visible and 3066993 or 15158332,
            footer = {text = "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S")}
        }
        
        SendToDiscord(WEBHOOK_EVENT, {embeds = {embed}})
    end
end)

luckCounter:GetPropertyChangedSignal("Text"):Connect(function()
    local embed = {
        title = "🍀 Server Luck Update",
        description = string.format("**Current Luck:** %s", luckCounter.Text),
        color = 5814783,
        footer = {text = "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S")}
    }
    
    SendToDiscord(WEBHOOK_EVENT, {embeds = {embed}})
end)

-- Player Management
Players.PlayerAdded:Connect(function(player)
    playerJoinTime[player.UserId] = os.time()
    wait(2)
    NotifyPlayerStatus(player, "join")
    
    player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            NotifyPlayerStatus(player, "leave")
            playerJoinTime[player.UserId] = nil
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    NotifyPlayerStatus(player, "leave")
    playerJoinTime[player.UserId] = nil
end)

-- Initialize Monitoring
for _, obj in ipairs(eventsFolder:GetDescendants()) do
    MonitorUIElement(obj)
end

eventsFolder.DescendantAdded:Connect(MonitorUIElement)

for _, player in ipairs(Players:GetPlayers()) do
    playerJoinTime[player.UserId] = os.time()
end

InitAdminEventTracking()

game:GetService("TextChatService").OnIncomingMessage = function(msg)
    ProcessChatMessage(msg.Text)
end

-- Server Startup Notification
function SendServerStartupNotification()
    local embed = {
        title = "🚀 Server Started",
        description = "Game server is now online",
        color = 3447003,
        fields = {
            {name = "🎮 Game", value = PLACE_NAME, inline = true},
            {name = "👥 Players", value = string.format("%d/%d", #Players:GetPlayers(), Players.MaxPlayers), inline = true}
        },
        footer = {text = string.format("Server ID: %s | %s", game.JobId, os.date("%Y-%m-%d %H:%M:%S"))}
    }
    
    SendToDiscord(WEBHOOK_PLAYER, {embeds = {embed}})
    print("✅ Server startup notification sent")
end

SendServerStartupNotification()

print("✅ Monitoring system initialized successfully!")
