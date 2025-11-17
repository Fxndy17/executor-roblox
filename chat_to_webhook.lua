-- Local Chat Logger with Discord Webhook
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Discord Webhook URL
local WEBHOOK_URL =
    "https://discord.com/api/webhooks/1439918334509322250/tLGCb_6iVxqoDT-RG1YLL4RG7Nulcvt-ydNDG-qsEb7U0Qy5DGwJhRdXVsLF8-3w6k7d"

local function sendToDiscord(message, player)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = "Chat Log",
            ["description"] = message,
            ["color"] = 5814783,
            ["fields"] = {{
                ["name"] = "Player",
                ["value"] = player.Name .. " (@" .. player.DisplayName .. ")",
                ["inline"] = true
            }, {
                ["name"] = "User ID",
                ["value"] = tostring(player.UserId),
                ["inline"] = true
            }, {
                ["name"] = "Timestamp",
                ["value"] = timestamp,
                ["inline"] = true
            }},
            ["footer"] = {
                ["text"] = "Chat Logger"
            }
        }}
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

    -- Simpan ke file lokal (opsional)
    -- writefile("chat_log.txt", logEntry .. "\n", true)
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
