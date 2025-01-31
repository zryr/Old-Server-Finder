local Speed_Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/AhmadV99/Main/refs/heads/main/Library/Optimitzed_V5.lua"))()

local window = Speed_Library:CreateWindow({
    Title = "Old Server Finder",
    Description = "Find servers with desired uptime",
    TabWidth = 150,
    SizeUi = UDim2.new(0, 600, 0, 300)
})

local mainTab = window:CreateTab({
    Name = "Main",
    Icon = ""
})

local mainSection = mainTab:AddSection("Server Finder", true)

mainSection:AddButton({
    Title = "Unblacklist Visited Servers",
    Content = "Click here before using the old server finder",
    Callback = function()
        if pcall(function() return readfile("visited_servers.txt") end) then
            delfile("visited_servers.txt")
            Speed_Library:SetNotification({
                Title = "Servers",
                Description = "Unblacklisted Successfully",
                Content = "You've successfully unblacklisted your previously visited servers.",
                Time = 0.5,
                Delay = 5
            })
        end
    end
})

mainSection:AddLine()

local uptimeInput = mainSection:AddInput({
    Title = "Minimum Uptime",
    Content = "A white screen will flash once the old server is found, tap on it to remove it.",
    Default = "30 or 30:10:01",
    Callback = function(value)
    end
})

mainSection:AddButton({
    Title = "Begin to search",
    Content = "Start searching for old servers",
    Callback = function()
        local desiredUptime = uptimeInput.Value

        if desiredUptime:match("^%d+$") then
            desiredUptime = desiredUptime .. ":00:00"
        end

        local hours, minutes, seconds = desiredUptime:match("^(%d+):(%d+):(%d+)$")

        if not (hours and minutes and seconds) then
            Speed_Library:SetNotification({
                Title = "Invalid Format",
                Description = "",
                Content = "Please try entering time in HH:MM:SS format.",
                Time = 0.5,
                Delay = 5
            })
            return
        end
        
        desiredUptime = string.format("%02d:%02d:%02d", tonumber(hours), tonumber(minutes), tonumber(seconds))
        
        -- Check if queue_on_teleport is supported
        if not syn or not syn.queue_on_teleport then
            Speed_Library:SetNotification({
                Title = "Executor doesn't support",
                Description = "Queue_On_Teleport",
                Content = "Place the script in your clipboard into your executor's auto execute folder.",
                Time = 0.5,
                Delay = 10  -- Notification duration increased to 10 seconds
            })
            
            local scriptToClipboard = string.format([[
-- Configuration (Minimum Uptime)
local desiredUptime = "%s" -- %s Hours, %s Minutes, %s Seconds

-- Loadstring
loadstring(game:HttpGet("https://raw.githubusercontent.com/zryr/Fisch-Old-Server-Finder/refs/heads/main/Old-Server-Finder-Speed-Hub-X"))()(desiredUptime)
]], desiredUptime, hours, minutes, seconds)
            
            setclipboard(scriptToClipboard)
        else
            local scriptUrl = "https://raw.githubusercontent.com/zryr/Fisch-Old-Server-Finder/refs/heads/main/Old-Server-Finder-Speed-Hub-X"
            loadstring(game:HttpGet(scriptUrl))()(desiredUptime)
        end
    end
})

mainSection:AddParagraph({
    Title = "❗️• Information",
    Content = "If you keep serverhopping without clicking the 'Begin to Search' button, switch to a different game and then rejoin Fisch."
})

mainSection:AddLine()

mainSection:AddInput({
    Title = "Server Joiner (JobID)",
    Content = "Place a server's JobID here to join it",
    Callback = function(value)
        if value and value ~= "" then
            local TeleportService = game:GetService("TeleportService")
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, value, game.Players.LocalPlayer)
            end)
        end
    end
})
