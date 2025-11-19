local games = {
    [121864768012064] = "https://raw.githubusercontent.com/Fxndy17/executor-roblox/refs/heads/main/notif_fishit.lua"
}

local currentID = game.PlaceId
local scriptURL = games[currentID]

if scriptURL then
    loadstring(game:HttpGet(scriptURL))();
end
