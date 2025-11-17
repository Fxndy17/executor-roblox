local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Discord Webhook URL
local WEBHOOK_URL =
    "https://discord.com/api/webhooks/1439918334509322250/tLGCb_6iVxqoDT-RG1YLL4RG7Nulcvt-ydNDG-qsEb7U0Qy5DGwJhRdXVsLF8-3w6k7d"

local function sendToDiscord(message, player)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local embed = {{
        ["title"] = "🎮 Listening",
        ["color"] = 0x00FF00,
        ["fields"] = {{
            ["name"] = "🎨 Message",
            ["value"] = message,
            ["inline"] = true
        }, {
            ["name"] = "👤 Player",
            ["value"] = player.Name,
            ["inline"] = true
        }},
        ["footer"] = {
            ["text"] = "Detected at: " .. timestamp
        }
    }}

    local data = {
        ["embeds"] = embed,
        ["username"] = "Roblox"
    }

    local jsonData = HttpService:JSONEncode(data)

    -- Menggunakan request() function
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

local function logChat(message, player)
    local timestamp = os.date("%H:%M:%S")
    local logEntry = string.format("[%s] %s: %s", timestamp, player.Name, message)

    print(logEntry) -- Tampilkan di console lokal

    -- Kirim ke Discord
    sendToDiscord(message, player)
end

-- Setup chat listener
for _, player in pairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        logChat(message, player)
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        logChat(message, player)
    end)
end)

print("Chat logger started - Data akan dikirim ke Discord")
