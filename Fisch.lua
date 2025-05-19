local function main(desiredUptime)
    -- Check for the existence of queue_on_teleport support
    local hasQueueSupport = queue_on_teleport ~= nil

    -- Notify the user about the requirement for auto-execute setup if needed
    if not hasQueueSupport then
        notify('Please place the script in your auto-execute folder.')
    end

    -- Define the function to check uptime
    function checkUptime(desiredUptime)
        local function notify(message)
            local notificationLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/laagginq/ui-libraries/main/xaxas-notification/src.lua"))()
            local notifications = notificationLibrary.new({
                NotificationLifetime = 3,
                NotificationPosition = "Middle",
                TextFont = Enum.Font.Code,
                TextColor = Color3.fromRGB(255, 255, 255),
                TextSize = 15,
                TextStrokeTransparency = 0,
                TextStrokeColor = Color3.fromRGB(0, 0, 0)
            })

            notifications:BuildNotificationUI()
            notifications:Notify(message)
        end

        local TeleportService = game:GetService("TeleportService")
        local HttpService = game:GetService("HttpService")
        local Players = game:GetService("Players")

        -- Attempt to get the LocalPlayer safely
        local player = Players.LocalPlayer
        if not player then
            notify("LocalPlayer is not yet available.")
            return
        end

        local visitedServersFile = "visited_servers.txt"
        local visitedServers = {}

        -- Initial wait before starting the script logic
        wait(2)

        -- Check if the script is executed on the correct PlaceId
        local expectedPlaceId = 16732694052
        if game.PlaceId ~= expectedPlaceId then
            notify("Wrong place! This script is for Fisch only!")
            return
        end

        local function loadVisitedServers()
            if pcall(function() return readfile(visitedServersFile) end) then
                local data = readfile(visitedServersFile)
                for line in string.gmatch(data, "[^\n]+") do
                    local serverId, info = line:match("([^|]+)%s*|%s*(.*)")
                    if serverId and info then
                        visitedServers[serverId] = info
                    end
                end
            else
                writefile(visitedServersFile, "")
            end
        end

        local function saveVisitedServers()
            local data = ""
            for serverId, info in pairs(visitedServers) do
                data = data .. serverId .. " | " .. info .. "\n"
            end
            writefile(visitedServersFile, data)
        end

        loadVisitedServers()

        local function getServerUptimeFromGUI()
            local uptimeLabel = player.PlayerGui:WaitForChild("serverInfo"):WaitForChild("serverInfo"):WaitForChild("uptime")
            local uptimeText = uptimeLabel.Text
            local timeStr = uptimeText:match("(%d+:%d+:%d+)")
            return timeStr
        end

        local function getUpdateVersionFromGUI()
            local versionLabel = player.PlayerGui:WaitForChild("serverInfo"):WaitForChild("serverInfo"):WaitForChild("version")
            local versionText = versionLabel.Text
            local versionStr = versionText:match("Update Version: (%d+%.%d+)")
            return versionStr
        end

        local function toClipboard(text)
            setclipboard(text)
        end

        local function flashScreenUntilInteraction(callback)
            local screenGui = Instance.new("ScreenGui")
            screenGui.DisplayOrder = 1000
            screenGui.Parent = player.PlayerGui
            screenGui.IgnoreGuiInset = true

            local flashButton = Instance.new("TextButton")
            flashButton.Size = UDim2.new(1, 0, 1, 0)
            flashButton.BackgroundColor3 = Color3.new(1, 1, 1)
            flashButton.BorderSizePixel = 0
            flashButton.Text = ""
            flashButton.Parent = screenGui

            local flashing = true

            local function removeFlash()
                flashing = false
                screenGui:Destroy()
                if callback then
                    callback() -- Trigger the notification after the flash screen is closed
                end
            end

            flashButton.MouseButton1Click:Connect(removeFlash)

            while flashing do
                flashButton.Visible = not flashButton.Visible
                wait(0.5)
            end
        end

        local function convertTimeToSeconds(timeStr)
            local hours, minutes, seconds = timeStr:match("(%d+):(%d+):(%d+)")
            hours = tonumber(hours) or 0
            minutes = tonumber(minutes) or 0
            seconds = tonumber(seconds) or 0
            return (hours * 3600) + (minutes * 60) + seconds
        end

        local function serverHop()
            local gameId = game.PlaceId
            local cursor = ""
            local serversUrlPattern = "https://games.roblox.com/v1/games/" .. gameId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=%s"

            local function fetchServers()
                local serversUrl = serversUrlPattern:format(cursor)
                local success, result = pcall(function()
                    return HttpService:JSONDecode(game:HttpGet(serversUrl))
                end)

                if success and result.data then
                    return result.data, result.nextPageCursor
                else
                    notify("Failed to retrieve server list. Retrying in 10 seconds...")
                    wait(10)  -- Wait for 10 seconds before retrying to get the server list
                    return nil, nil
                end
            end

            local function tryJoinServer(server)
                local successJoin, errorMessage

                successJoin, errorMessage = pcall(function()
                    TeleportService:TeleportToPlaceInstance(gameId, server.id, player)
                end)

                if not successJoin then
                    if errorMessage:match("GameFull") or errorMessage:match("Unauthorized") then
                        visitedServers[server.id] = "Full or Unauthorized"
                        saveVisitedServers()
                        notify("Server is full or unauthorized, skipping.")
                        return false
                    else
                        notify("Error joining server: " .. errorMessage)
                        wait(5) -- Wait before retrying for network issues or other transient errors
                    end
                end

                return successJoin
            end

            while true do
                local servers, nextCursor = fetchServers()
                if servers then
                    for _, server in ipairs(servers) do
                        if server.id ~= game.JobId and not server.private and not visitedServers[server.id] and server.playing < server.maxPlayers then
                            if tryJoinServer(server) then
                                return
                            end
                        end
                    end

                    cursor = nextCursor or ""
                end

                if cursor == "" then
                    notify("No suitable servers found, refreshing list in 10 seconds...")
                    wait(10) -- Wait before starting a new server search cycle
                end
            end
        end

        local function checkCurrentServer()
            local serverUptime = getServerUptimeFromGUI()
            local serverVersion = getUpdateVersionFromGUI()

            print("Initial Server Uptime: " .. (serverUptime or "(failed to get server info)"))
            print("Server Version: " .. (serverVersion or "(failed to get server info)"))

            if serverUptime == "00:00:00" then
                warn("Server uptime not loaded. Current uptime is 00:00:00.")
                wait(10)  -- Wait for 10 seconds to re-check
                serverUptime = getServerUptimeFromGUI()
                serverVersion = getUpdateVersionFromGUI()
                print("Checked Server Uptime: " .. (serverUptime or "(failed to get server info)"))
                print("Checked Server Version: " .. (serverVersion or "(failed to get server info)"))

                if serverUptime == "00:00:00" then
                    warn("Server uptime still not loaded. Current uptime is 00:00:00.")
                    visitedServers[game.JobId] = "(failed to get server info)"
                    saveVisitedServers()
                    print("Server didn't meet the criteria, blacklisting it.")
                    serverHop()
                    return
                end
            end

            local currentServerId = game.JobId
            local currentTimeUTC = os.date("!%I:%M:%S %p [UTC]")

            local serverUptimeSeconds = convertTimeToSeconds(serverUptime)
            local desiredUptimeSeconds = convertTimeToSeconds(desiredUptime)

            if serverUptimeSeconds >= desiredUptimeSeconds then
                toClipboard(currentServerId)
                flashScreenUntilInteraction(function()
                    notify("Old Server Found! JobID is in your Clipboard")
                    wait(3)
                    notify("Make sure to delete the visited_servers.txt file from the executor's workspace.")
                end)
            else
                visitedServers[currentServerId] = serverUptime .. " | " .. (serverVersion or "Unknown Version") .. " | " .. currentTimeUTC
                saveVisitedServers()
                print("Server didn't meet the criteria, blacklisting it.")
                serverHop()
            end
        end

        checkCurrentServer()

        -- Queue the script for execution after teleport
        local teleportScript = [[
            loadstring(game:HttpGet("https://raw.githubusercontent.com/zryr/Fisch-Old-Server-Finder/refs/heads/main/Source-Khalid-Beta"))()("]] .. desiredUptime .. [[")
        ]]

        if hasQueueSupport then
            queue_on_teleport(teleportScript)
        else
            -- The notification is already handled at the start if queue_on_teleport is not supported
        end

        -- Anti-AFK script integration
        local GC = getconnections or get_signal_cons
        if GC then
            for i, v in pairs(GC(Players.LocalPlayer.Idled)) do
                if v["Disable"] then
                    v["Disable"](v)
                elseif v["Disconnect"] then
                    v["Disconnect"](v)
                end
            end
        else
            local VirtualUser = cloneref(game:GetService("VirtualUser"))
            Players.LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end

    -- Call the function with the desired uptime
    checkUptime(desiredUptime)
end

-- Provide the script as a loadstring
return main
