local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Chat = game:GetService("Chat")

-- Discord Webhook URL
local WEBHOOK_URL = "https://discord.com/api/webhooks/1439918334509322250/tLGCb_6iVxqoDT-RG1YLL4RG7Nulcvt-ydNDG-qsEb7U0Qy5DGwJhRdXVsLF8-3w6k7d"

local function sendToDiscord(message, playerName, isSystemMessage)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    local embedTitle = isSystemMessage and "🔔 System Message" or "🎮 Player Chat"
    local fieldName = isSystemMessage and "📢 System Message" or "🎨 Player Message"
    local playerField = isSystemMessage and "🤖 System" or "👤 " .. playerName

    local embed = {{
        ["title"] = embedTitle,
        ["color"] = isSystemMessage and 0xFFA500 or 0x00FF00, -- Orange untuk system, Green untuk player
        ["fields"] = {{
            ["name"] = fieldName,
            ["value"] = message,
            ["inline"] = true
        }, {
            ["name"] = "👤 Sender",
            ["value"] = playerField,
            ["inline"] = true
        }},
        ["footer"] = {
            ["text"] = "Detected at: " .. timestamp
        }
    }}

    local data = {
        ["embeds"] = embed,
        ["username"] = "Roblox Chat Logger"
    }

    local jsonData = HttpService:JSONEncode(data)

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

    if success then
        print("✅ Webhook berhasil dikirim!")
    else
        print("❌ Gagal mengirim webhook: " .. tostring(result))
    end
end

local function logChat(message, player, isSystemMessage)
    local timestamp = os.date("%H:%M:%S")
    local sender = isSystemMessage and "[SYSTEM]" or player.Name
    local logEntry = string.format("[%s] %s: %s", timestamp, sender, message)

    print(logEntry)

    -- Kirim ke Discord
    sendToDiscord(message, player and player.Name or "System", isSystemMessage)
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

-- Listener untuk system messages/notifications
Chat.MessagePosted:Connect(function(message, channelName)
    -- Cek jika ini system message (bukan dari player)
    if string.find(channelName, "System") or string.find(message, "^%[.*%].*:") then
        logChat(message, nil, true)
    end
end)

-- Alternative: Listen untuk semua chat channel termasuk system
local function onMessagePosted(messageData, channelName)
    local speaker = messageData.FromSpeaker
    local message = messageData.Message
    local isSystem = speaker == "System" or channelName == "System"
    
    if isSystem then
        logChat(message, nil, true)
    else
        -- Untuk player messages, sudah ditangani oleh Player.Chatted
        -- Tapi bisa juga ditangani di sini jika diperlukan
    end
end

-- Connect ke signal MessagePosted
Chat.MessagePosted:Connect(onMessagePosted)

print("Advanced chat logger started - Player chat dan system messages akan dikirim ke Discord")
