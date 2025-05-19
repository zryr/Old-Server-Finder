--[[
    Grow a Garden - Old Server Finder/Joiner with Pastebin Backend & GUI
    Version: 1.2.4 (Fix for '...' error in global scope)
]]

-- ------------------------------------------------------------------------------------
-- CONFIGURATION - !!! VERIFY ALL VALUES !!!
-- ------------------------------------------------------------------------------------
local PASTEBIN_API_DEV_KEY = "U8CrZNTgDnfYoJ2mDC3Px1mVqhpMG5wz"
local ACQUIRED_API_USER_KEY = "8bd62df35cbba6ade9f28b23e560baf1"
local SCRIPT_RELOAD_URL = "https://raw.githubusercontent.com/zryr/Old-Server-Finder/refs/heads/main/Grow%20a%20Garden.lua"

local DEFAULT_TARGET_MAX_VERSION = 1226

local OLD_SERVERS_PASTE_FILENAME_PREFIX = "Old_Servers_Gag_"
local UPTODATE_SERVERS_PASTE_FILENAME_PREFIX = "UpToDate_Servers_Gag_"
local OLD_SERVERS_PASTE_KEY_FILE = "gag_old_servers_paste_key.txt"
local UPTODATE_SERVERS_PASTE_KEY_FILE = "gag_uptodate_servers_paste_key.txt"

local TARGET_PLACE_ID = 16109285695
local PASTE_EXPIRY_TIME = "1D"
local MAX_PASTE_SIZE_BYTES = 500 * 1024
-- ------------------------------------------------------------------------------------

local TARGET_MAX_VERSION = DEFAULT_TARGET_MAX_VERSION -- Will be updated by main() if param is passed

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mainGui = nil
local statusLabel = nil

local function quickNotify(message, duration)
    duration = duration or 5
    if not CoreGui then return end
    local existingNotif = CoreGui:FindFirstChild("QuickNotificationScript")
    if existingNotif then existingNotif:Destroy() end

    local notifGui = Instance.new("ScreenGui", CoreGui)
    notifGui.DisplayOrder = 999999; notifGui.Name = "QuickNotificationScript"
    local frame = Instance.new("Frame", notifGui)
    frame.Size = UDim2.new(0.35, 0, 0.1, 0); frame.Position = UDim2.new(0.5, 0, 0.05, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0); frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2; frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 8)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 1, -10); label.Position = UDim2.new(0.5, 0, 0.5, 0)
    label.AnchorPoint = Vector2.new(0.5, 0.5); label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1); label.TextWrapped = true; label.TextScaled = false
    label.Font = Enum.Font.SourceSansSemibold; label.TextSize = 16; label.Text = message
    Debris:AddItem(notifGui, duration)
end

local function createPillButton(parent, text, position, size)
    local button = Instance.new("TextButton", parent)
    button.Text = text; button.Size = size; button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(70, 130, 180); button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansBold; button.TextSize = 18
    button.AutoButtonColor = true
    Instance.new("UICorner", button).CornerRadius = UDim.new(0.5, 0);
    return button
end

local function createMainGui()
    if not player then player = Players.LocalPlayer end
    local parentGui = player and player.PlayerGui or CoreGui
    if not parentGui then print("Error: Cannot find suitable parent for Main GUI."); return end

    if mainGui and mainGui.Parent then mainGui:Destroy() end
    mainGui = Instance.new("ScreenGui", parentGui); mainGui.Name = "OldServerFinderGUI"
    mainGui.DisplayOrder = 1000; mainGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", mainGui)
    frame.Size = UDim2.new(0, 320, 0, 220); frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    frame.BorderSizePixel = 1; frame.BorderColor3 = Color3.fromRGB(20,20,20)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Text = "Grow A Garden - Server Tool"; titleLabel.Size = UDim2.new(1, 0, 0, 35)
    titleLabel.Position = UDim2.new(0, 0, 0, 10); titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230); titleLabel.Font = Enum.Font.SourceSansSemibold
    titleLabel.TextSize = 20

    statusLabel = Instance.new("TextLabel", frame)
    statusLabel.Text = "Target Version <= " .. TARGET_MAX_VERSION; statusLabel.Size = UDim2.new(1, -20, 0, 20)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 50); statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.Font = Enum.Font.SourceSansItalic; statusLabel.TextSize = 14; statusLabel.TextWrapped = true

    local searchButton = createPillButton(frame, "Search Old Server", UDim2.new(0.5, 0, 0.45, 0), UDim2.new(0.85, 0, 0, 45))
    searchButton.AnchorPoint = Vector2.new(0.5, 0.5)

    local joinButton = createPillButton(frame, "Join Old Server", UDim2.new(0.5, 0, 0.75, 0), UDim2.new(0.85, 0, 0, 45))
    joinButton.AnchorPoint = Vector2.new(0.5, 0.5)

    searchButton.MouseButton1Click:Connect(function()
        if mainGui and mainGui.Parent then mainGui:Destroy() end
        quickNotify("Starting search for servers <= V" .. TARGET_MAX_VERSION, 3)
        coroutine.wrap(runMainLogic)("search_master", "", 0, HttpService:GenerateGUID(false))
    end)

    joinButton.MouseButton1Click:Connect(function()
        if mainGui and mainGui.Parent then mainGui:Destroy() end
        quickNotify("Searching Pastebin for servers <= V" .. TARGET_MAX_VERSION, 3)
        coroutine.wrap(runMainLogic)("join_master")
    end)
end

local function getPasteKeyFromFile(filename)
    if isfile and isfile(filename) then
        local s, k = pcall(function() return readfile(filename) end)
        if s and k and #k > 0 then return k:match("^%s*(.-)%s*$") end
    end
    return nil
end

local function savePasteKeyToFile(filename, key)
    if key and writefile then pcall(function() writefile(filename, key) end)
    elseif not key and delfile and isfile and isfile(filename) then pcall(function() delfile(filename) end)
    end
end

local function getRawPasteContent(pasteKey)
    if not pasteKey then return nil, "No paste key provided" end
    local rawUrl = "https://pastebin.com/raw/" .. pasteKey
    local success, contentOrError = pcall(function() return game:HttpGet(rawUrl, true) end)
    if success then
        if type(contentOrError) == "string" and contentOrError:lower():match("pastebin.com has been blocked|error processing request|this paste has been removed|this is a private paste|paste does not exist|not a valid paste id") then
            print("Pastebin fetch error for key " .. pasteKey .. ": Paste issue (removed/private/blocked/not exist/invalid).")
            return nil, "Paste issue"
        end
        return contentOrError, nil
    else
        print("Failed to fetch from Pastebin (key: " .. pasteKey .. "). Network/HTTP Error: "..tostring(contentOrError))
        return nil, "Network/HTTP Error: " .. tostring(contentOrError)
    end
end

local HttpPostAsync = HttpService.PostAsync or (HttpService.RequestAsync and function(url, body, contentType, _)
    local response = HttpService:RequestAsync({Url = url, Method = "POST", Headers = {["Content-Type"] = contentType}, Body = body})
    if response and response.Success then return response.Body
    elseif response then return "Error: "..response.StatusCode.." "..response.StatusMessage.." Body: ".. (response.Body or "")
    else return "Error: RequestAsync failed without response" end
end)

local function createPastebinPaste(name, content)
    if not HttpPostAsync then quickNotify("HttpPostAsync not available!", 5); return nil, "HTTP POST not available" end
    if PASTEBIN_API_DEV_KEY == "YOUR_PASTEBIN_DEV_KEY_HERE" then quickNotify("Pastebin Dev Key not set!", 5); return nil, "Dev key not set" end

    if #content > MAX_PASTE_SIZE_BYTES then
        quickNotify("Error: Content for paste '" .. name .. "' is too large (" .. #content .. " bytes). Max is ~"..math.floor(MAX_PASTE_SIZE_BYTES/1024) .."KB. Paste not created.", 10)
        warn("Content too large for Pastebin: " .. name .. ", size: " .. #content)
        return nil, "Content too large (proactive check)" 
    end
    if #content == 0 then content = "-- Empty Paste " .. os.date("!%Y-%m-%d %H:%M") .. " --" end

    local params = {
        api_dev_key = PASTEBIN_API_DEV_KEY, api_option = "paste", api_paste_code = content,
        api_paste_name = name .. " " .. os.date("!%Y-%m-%d_%H%M"), api_paste_private = "1",
        api_paste_expire_date = PASTE_EXPIRY_TIME, api_paste_format = "text"
    }
    if ACQUIRED_API_USER_KEY and ACQUIRED_API_USER_KEY ~= "YOUR_ACQUIRED_API_USER_KEY_HERE" and ACQUIRED_API_USER_KEY ~= "" then
        params.api_user_key = ACQUIRED_API_USER_KEY
    end

    local bodyParts = {}
    for key, value in pairs(params) do table.insert(bodyParts, HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(value)) end
    local requestBody = table.concat(bodyParts, "&")
    local pastebinApiUrl = "https://pastebin.com/api/api_post.php"

    print((params.api_user_key and "User " or "Guest ") .. "Creating Pastebin: " .. name .. " (Size: " .. #content .. " bytes)")
    local success, response = pcall(HttpPostAsync, HttpService, pastebinApiUrl, requestBody, Enum.HttpContentType.ApplicationUrlEncoded, false)

    if success and response and type(response) == "string" then
        if response:match("^https?://pastebin.com/") then
            local newKey = response:match("pastebin.com/([^/]+)$")
            print("Pastebin created: " .. response .. (newKey and (" (Key: " .. newKey .. ")") or ""))
            return newKey, response
        elseif response:lower():match("maximum paste file size exceeded") then
            quickNotify("Pastebin API: Max file size exceeded for '"..name.."'", 7)
            warn("Pastebin API Error (Create - Max Size): ", name, response)
            return nil, "Max file size exceeded (API)"
        elseif response:lower():match("api_paste_code was empty") then
            quickNotify("Pastebin API: Paste content was empty for '"..name.."'", 7)
            warn("Pastebin API Error (Create - Empty Content): ", name, response)
            return nil, "Empty content (API)"
        else
            quickNotify("Pastebin API Error (Create): " .. tostring(response):sub(1,100), 7)
            warn("Pastebin API Error (Create - Other): ", name, response)
            return nil, response
        end
    else
        quickNotify("Pastebin HTTP Error (Create): " .. tostring(response or "Unknown HTTP error"), 7)
        warn("Pastebin HTTP Error (Create): ", name, response)
        return nil, tostring(response or "Unknown HTTP error")
    end
end

local function deletePastebinPaste(pasteKeyToDelete)
    if not HttpPostAsync then quickNotify("HttpPostAsync not available for delete!", 5); return false end
    if PASTEBIN_API_DEV_KEY == "YOUR_PASTEBIN_DEV_KEY_HERE" then quickNotify("Pastebin Dev Key not set for delete!", 5); return false end
    if not ACQUIRED_API_USER_KEY or ACQUIRED_API_USER_KEY == "YOUR_ACQUIRED_API_USER_KEY_HERE" or ACQUIRED_API_USER_KEY == "" then
        print("Cannot delete paste " .. pasteKeyToDelete .. ": api_user_key not available.")
        return false
    end

    print("Attempting to delete Pastebin paste: " .. pasteKeyToDelete)
    local params = {
        api_dev_key = PASTEBIN_API_DEV_KEY, api_user_key = ACQUIRED_API_USER_KEY,
        api_paste_key = pasteKeyToDelete, api_option = "delete"
    }
    local bodyParts = {}
    for key, value in pairs(params) do table.insert(bodyParts, HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(value)) end
    local requestBody = table.concat(bodyParts, "&")
    local pastebinApiUrl = "https://pastebin.com/api/api_post.php"

    local success, response = pcall(HttpPostAsync, HttpService, pastebinApiUrl, requestBody, Enum.HttpContentType.ApplicationUrlEncoded, false)
    if success and response then
        if response == "Paste Removed" then
            print("Successfully deleted Pastebin paste: " .. pasteKeyToDelete)
            quickNotify("Deleted old Pastebin: " .. pasteKeyToDelete:sub(1,8), 3)
            return true
        else
            quickNotify("Failed to delete Pastebin " .. pasteKeyToDelete:sub(1,8) .. ". Resp: " .. tostring(response):sub(1,50), 5)
            warn("Failed to delete Pastebin. Key: " .. pasteKeyToDelete .. ". Response: ", response)
            return false
        end
    else
        quickNotify("Error during Pastebin delete req for " .. pasteKeyToDelete:sub(1,8) .. ". Err: " .. tostring(response):sub(1,50), 5)
        warn("Error during Pastebin delete request for " .. pasteKeyToDelete .. ". Error: ", response)
        return false
    end
end

local function updatePastebinList(listType, newDataToAdd)
    newDataToAdd = newDataToAdd or {}
    local pasteKeyFile = (listType == "old" and OLD_SERVERS_PASTE_KEY_FILE or UPTODATE_SERVERS_PASTE_KEY_FILE)
    local pasteNamePrefix = (listType == "old" and OLD_SERVERS_PASTE_FILENAME_PREFIX or UPTODATE_SERVERS_PASTE_FILENAME_PREFIX)
    local oldKey = getPasteKeyFromFile(pasteKeyFile)
    local existingContent = ""
    if oldKey then
        local fetchedContent, fetchError = getRawPasteContent(oldKey)
        if fetchedContent then existingContent = fetchedContent
        else
            print("Old paste key '" .. oldKey .. "' for " .. listType .. " invalid. Details: " .. (fetchError or "N/A"))
            savePasteKeyToFile(pasteKeyFile, nil); oldKey = nil 
        end
    end

    local combinedLines = {}
    if existingContent ~= "" then
        for line in existingContent:gmatch("[^\r\n]+") do table.insert(combinedLines, line) end
    end
    for _, newLine in ipairs(newDataToAdd) do table.insert(combinedLines, newLine) end
    
    local uniqueLines = {}; local seenJobIds = {}
    for i = #combinedLines, 1, -1 do 
        local line = combinedLines[i]
        local jobId = line:match("^([^|]+)%s*|") 
        if jobId then
            jobId = jobId:gsub("%s+", "") 
            if not seenJobIds[jobId] then 
                table.insert(uniqueLines, 1, line); 
                seenJobIds[jobId] = true 
            end
        else
            table.insert(uniqueLines, 1, line) 
        end
    end

    local newContentCombined = table.concat(uniqueLines, "\n")
    if newContentCombined == "" and #newDataToAdd == 0 then newContentCombined = "-- Empty " .. listType .. " List -- " .. os.date("!%Y-%m-%d %H:%M") end

    local originalLength = #newContentCombined
    while #newContentCombined > MAX_PASTE_SIZE_BYTES and #uniqueLines > 1 do 
        table.remove(uniqueLines, 1) 
        newContentCombined = table.concat(uniqueLines, "\n")
    end
    if originalLength > MAX_PASTE_SIZE_BYTES and #newContentCombined <= MAX_PASTE_SIZE_BYTES then
        print("Truncated " .. listType .. " list from " .. originalLength .. " to " .. #newContentCombined .. " bytes to fit Pastebin limit.")
        quickNotify("Truncated " .. listType .. " list due to size.", 4)
        if newContentCombined == "" then newContentCombined = "-- List Emptied by Truncation -- " .. os.date("!%Y-%m-%d %H:%M") end
    end
    
    local newKey, creationResponse = createPastebinPaste(pasteNamePrefix, newContentCombined)
    if newKey then
        savePasteKeyToFile(pasteKeyFile, newKey)
        print(listType .. " list updated. New key: " .. newKey .. ". URL: " .. (type(creationResponse) == "string" and creationResponse:match("^http") and creationResponse or "N/A"))
        quickNotify(listType .. " list updated. Key: " .. newKey:sub(1,8), 3)
        if oldKey and oldKey ~= newKey and ACQUIRED_API_USER_KEY and ACQUIRED_API_USER_KEY ~= "" and ACQUIRED_API_USER_KEY ~= "YOUR_ACQUIRED_API_USER_KEY_HERE" then
            deletePastebinPaste(oldKey)
        elseif oldKey and oldKey ~= newKey then print("Old " .. listType .. " paste (" .. oldKey .. ") not deleted (no user_key or other). Will expire.") end
    else
        print("Failed to update " .. listType .. " list. Error: " .. tostring(creationResponse))
        quickNotify("Failed to update " .. listType .. " list. Err: " .. tostring(creationResponse):sub(1,30), 5)
    end
end

local function ensurePastebinListExists(listType)
    local listName = listType == "old" and "Old Servers" or "UpToDate Servers"
    print("Ensuring Pastebin list exists for: " .. listName)
    local keyFile = (listType == "old" and OLD_SERVERS_PASTE_KEY_FILE or UPTODATE_SERVERS_PASTE_KEY_FILE)
    local currentKey = getPasteKeyFromFile(keyFile)
    local createNew = false
    if not currentKey then 
        print("Local key for '"..listName.."' not found.")
        createNew = true
    else
        local _, err = getRawPasteContent(currentKey) 
        if err then 
            print(listName .. " paste (key: " .. currentKey .. ") invalid/unfetchable. Error: " .. err .. ". Will create new.")
            savePasteKeyToFile(keyFile, nil); 
            createNew = true
        end
    end
    if createNew then
        quickNotify("Creating initial '" .. listName .. "' Pastebin list...", 3)
        updatePastebinList(listType, {"-- Initial " .. listName .. " List (" .. os.date("!%Y-%m-%d %H:%M") .. ") --"})
        return getPasteKeyFromFile(keyFile) ~= nil 
    end
    print(listName.." list (key: "..currentKey..") exists and seems accessible.")
    return true
end

local function loadServerListFromPastebin(pasteKey)
    local serversSet = {}; local serverDetails = {}
    if not pasteKey then return serversSet, serverDetails end
    local content, err = getRawPasteContent(pasteKey)
    if content then
        for line in string.gmatch(content, "[^\r\n]+") do
            local jobId = line:match("^([^|]+)%s*|")
            if jobId then jobId = jobId:gsub("%s+", ""); serversSet[jobId] = true; serverDetails[jobId] = line end
        end
    else print("Could not load server list from paste key:", pasteKey, "Error:", err) end
    return serversSet, serverDetails
end

function runMainLogic(mode, arg1, arg2, arg3, arg4, arg5) -- Added arg5 for targetMaxVersion in slave
    if not player then player = Players.LocalPlayer end
    if not player then quickNotify("LocalPlayer not found!", 5); return end

    if mode ~= "initial_gui" and mode ~= "join_master_fetch_list" then
        if game.PlaceId ~= TARGET_PLACE_ID then
            quickNotify("Script for Grow A Garden (ID " .. TARGET_PLACE_ID .. ") only. Current: " .. game.PlaceId, 7)
            if mode ~= "search_slave_check_version" then pcall(createMainGui) end
            return
        end
    end
    
    print("Running Mode:", mode, arg1, arg2, arg3, arg4, arg5)

    if mode == "initial_gui" then
        pcall(createMainGui)

    elseif mode == "search_master" then
        local oldListOK = ensurePastebinListExists("old")
        local upToDateListOK = ensurePastebinListExists("uptodate")
        if not (oldListOK and upToDateListOK) then
            quickNotify("Failed to initialize Pastebin lists. Cannot start search.", 7); pcall(createMainGui); return
        end
        
        local cursor = arg1 or ""; local processedIdx = arg2 or 0
        local searchSessionId = arg3 or HttpService:GenerateGUID(false)
        if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Loading known servers..." else quickNotify("Search: Loading known servers...",2) end

        local oldServersKey = getPasteKeyFromFile(OLD_SERVERS_PASTE_KEY_FILE)
        local upToDateServersKey = getPasteKeyFromFile(UPTODATE_SERVERS_PASTE_KEY_FILE)
        local knownOldSet, _ = loadServerListFromPastebin(oldServersKey)
        local knownUpToDateSet, _ = loadServerListFromPastebin(upToDateServersKey)
        
        if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Fetching Roblox servers..." else quickNotify("Search: Fetching Roblox servers...",2) end
        local serversUrl = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=50&cursor=%s", TARGET_PLACE_ID, cursor)
        local success, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(serversUrl, true)) end)

        if not success or not response or not response.data then
            quickNotify("Failed to fetch Roblox server list. " .. tostring(response or "Network error"), 7); pcall(createMainGui); return
        end

        local serversToProcess = response.data; local nextTargetServer = nil; local nextProcessedIdxOnPage = processedIdx
        for i = processedIdx + 1, #serversToProcess do
            local server = serversToProcess[i]
            if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 999) then
                if not knownOldSet[server.id] and not knownUpToDateSet[server.id] then
                    nextTargetServer = server; nextProcessedIdxOnPage = i; break
                end
            end
        end
        
        if nextTargetServer then
            if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Teleporting to " .. nextTargetServer.id:sub(1,8) else quickNotify("Search: Teleporting to "..nextTargetServer.id:sub(1,8),2) end
            local payload = string.format("'%s', '%s', '%s', %d, '%s', %s", -- arg5 (TARGET_MAX_VERSION) is now a number
                                          "search_slave_check_version", tostring(nextTargetServer.id), 
                                          cursor, nextProcessedIdxOnPage, searchSessionId, tostring(TARGET_MAX_VERSION))
            if queue_on_teleport and SCRIPT_RELOAD_URL ~= "" and SCRIPT_RELOAD_URL ~= "YOUR_RAW_URL_TO_THIS_SCRIPT_HERE" then
                local ts = string.format([[local u="%s";local s,c=pcall(game.HttpGet,game,u,true);if s and c then local entryPoint=loadstring(c)();if type(entryPoint)=='function' then entryPoint(%s)else print("TS Error: entryPoint not func")end else print("TS Error: HttpGet fail or script load error: "..tostring(c))end]], SCRIPT_RELOAD_URL, payload)
                queue_on_teleport(ts)
            elseif queue_on_teleport then
                 print("WARNING: SCRIPT_RELOAD_URL not set correctly. queue_on_teleport may not function as intended.")
            end
            pcall(TeleportService.TeleportToPlaceInstance, TeleportService, TARGET_PLACE_ID, nextTargetServer.id, player)
        else
            if response.nextPageCursor then
                if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Next page..." else quickNotify("Search: Next page...",2) end
                runMainLogic("search_master", response.nextPageCursor, 0, searchSessionId)
            else
                quickNotify("Search completed. All reachable servers known or processed.", 7); pcall(createMainGui)
            end
        end

    elseif mode == "search_slave_check_version" then
        local expectedJobId = arg1; local originalCursor = arg2
        local originalProcessedIdxOnPage = arg3; local searchSessionId = arg4
        local currentTargetMaxVersion = tonumber(arg5) or TARGET_MAX_VERSION -- Use passed or global default

        local currentJobId = game.JobId; local currentVersion = tonumber(game.PlaceVersion)
        local timestamp = os.date("!%Y-%m-%d %H:%M:%S [UTC]")
        quickNotify("Slave: Checking server " .. currentJobId:sub(1,8) .. " V:" .. tostring(currentVersion or "N/A"), 3)
        if currentJobId ~= expectedJobId then warn("Search Slave: JobID mismatch! Expected "..expectedJobId..", got "..currentJobId) end
        local newDataEntry = { string.format("%s | Version: %s | Timestamp: %s", currentJobId, tostring(currentVersion or "N/A"), timestamp) }
        
        if currentVersion and currentVersion <= currentTargetMaxVersion then
            updatePastebinList("old", newDataEntry) 
        else
            updatePastebinList("uptodate", newDataEntry)
        end
        local payload = string.format("'%s', '%s', %d, '%s'", 
                                      "search_master", originalCursor, originalProcessedIdxOnPage, searchSessionId)
        if queue_on_teleport and SCRIPT_RELOAD_URL ~= "" and SCRIPT_RELOAD_URL ~= "YOUR_RAW_URL_TO_THIS_SCRIPT_HERE" then
            local ts = string.format([[local u="%s";local s,c=pcall(game.HttpGet,game,u,true);if s and c then local entryPoint=loadstring(c)();if type(entryPoint)=='function' then entryPoint(%s)else print("TS Error: entryPoint not func")end else print("TS Error: HttpGet fail or script load error: "..tostring(c))end]], SCRIPT_RELOAD_URL, payload)
            queue_on_teleport(ts)
        elseif queue_on_teleport then
             print("WARNING: SCRIPT_RELOAD_URL not set for slave->master. queue_on_teleport may not function as intended.")
        end
        pcall(TeleportService.Teleport, TeleportService, TARGET_PLACE_ID, player)

    elseif mode == "join_master" then
        if not ensurePastebinListExists("old") then
            quickNotify("Failed to ensure 'Old Servers' list. Cannot join.", 7); pcall(createMainGui); return
        end
        quickNotify("Join: Fetching old servers (<= V" .. TARGET_MAX_VERSION .. ")..", 3)
        local oldServersKey = getPasteKeyFromFile(OLD_SERVERS_PASTE_KEY_FILE)
        local _, serverDetailsMap = loadServerListFromPastebin(oldServersKey)
        local serverEntries = {}
        if serverDetailsMap then for _, line in pairs(serverDetailsMap) do table.insert(serverEntries, line) end end
        if #serverEntries == 0 then quickNotify("Old server list is empty.", 5); pcall(createMainGui); return end
        table.sort(serverEntries, function(a,b) local tsA=a:match("Timestamp:%s*(.+)$")or"0";local tsB=b:match("Timestamp:%s*(.+)$")or"0";return tsA>tsB end)
        for i = 1, #serverEntries do
--[[
    Grow a Garden - Old Server Finder/Joiner with Pastebin Backend & GUI
    Version: 1.2.5 (Fix for 'readonly table' error by using local getTableKeys)
]]

-- ------------------------------------------------------------------------------------
-- CONFIGURATION - !!! VERIFY ALL VALUES !!!
-- ------------------------------------------------------------------------------------
local PASTEBIN_API_DEV_KEY = "U8CrZNTgDnfYoJ2mDC3Px1mVqhpMG5wz"
local ACQUIRED_API_USER_KEY = "8bd62df35cbba6ade9f28b23e560baf1"
local SCRIPT_RELOAD_URL = "https://raw.githubusercontent.com/zryr/Old-Server-Finder/refs/heads/main/Grow%20a%20Garden.lua"

local DEFAULT_TARGET_MAX_VERSION = 1226

local OLD_SERVERS_PASTE_FILENAME_PREFIX = "Old_Servers_Gag_"
local UPTODATE_SERVERS_PASTE_FILENAME_PREFIX = "UpToDate_Servers_Gag_"
local OLD_SERVERS_PASTE_KEY_FILE = "gag_old_servers_paste_key.txt"
local UPTODATE_SERVERS_PASTE_KEY_FILE = "gag_uptodate_servers_paste_key.txt"

local TARGET_PLACE_ID = 16109285695
local PASTE_EXPIRY_TIME = "1D"
local MAX_PASTE_SIZE_BYTES = 500 * 1024
-- ------------------------------------------------------------------------------------

local TARGET_MAX_VERSION = DEFAULT_TARGET_MAX_VERSION

-- Local utility to get table keys safely
local function getTableKeys(t)
    local keys = {}
    if type(t) == "table" then
        for k, _ in pairs(t) do
            table.insert(keys, k)
        end
    end
    return keys
end

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mainGui = nil
local statusLabel = nil

local function quickNotify(message, duration)
    duration = duration or 5
    if not CoreGui then return end
    local existingNotif = CoreGui:FindFirstChild("QuickNotificationScript")
    if existingNotif then existingNotif:Destroy() end

    local notifGui = Instance.new("ScreenGui", CoreGui)
    notifGui.DisplayOrder = 999999; notifGui.Name = "QuickNotificationScript"
    local frame = Instance.new("Frame", notifGui)
    frame.Size = UDim2.new(0.35, 0, 0.1, 0); frame.Position = UDim2.new(0.5, 0, 0.05, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0); frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2; frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 8)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 1, -10); label.Position = UDim2.new(0.5, 0, 0.5, 0)
    label.AnchorPoint = Vector2.new(0.5, 0.5); label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1); label.TextWrapped = true; label.TextScaled = false
    label.Font = Enum.Font.SourceSansSemibold; label.TextSize = 16; label.Text = message
    Debris:AddItem(notifGui, duration)
end

local function createPillButton(parent, text, position, size)
    local button = Instance.new("TextButton", parent)
    button.Text = text; button.Size = size; button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(70, 130, 180); button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansBold; button.TextSize = 18
    button.AutoButtonColor = true
    Instance.new("UICorner", button).CornerRadius = UDim.new(0.5, 0);
    return button
end

local function createMainGui()
    if not player then player = Players.LocalPlayer end
    local parentGui = player and player.PlayerGui or CoreGui
    if not parentGui then print("Error: Cannot find suitable parent for Main GUI."); return end

    if mainGui and mainGui.Parent then mainGui:Destroy() end
    mainGui = Instance.new("ScreenGui", parentGui); mainGui.Name = "OldServerFinderGUI"
    mainGui.DisplayOrder = 1000; mainGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", mainGui)
    frame.Size = UDim2.new(0, 320, 0, 220); frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    frame.BorderSizePixel = 1; frame.BorderColor3 = Color3.fromRGB(20,20,20)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Text = "Grow A Garden - Server Tool"; titleLabel.Size = UDim2.new(1, 0, 0, 35)
    titleLabel.Position = UDim2.new(0, 0, 0, 10); titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230); titleLabel.Font = Enum.Font.SourceSansSemibold
    titleLabel.TextSize = 20

    statusLabel = Instance.new("TextLabel", frame)
    statusLabel.Text = "Target Version <= " .. TARGET_MAX_VERSION; statusLabel.Size = UDim2.new(1, -20, 0, 20)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 50); statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.Font = Enum.Font.SourceSansItalic; statusLabel.TextSize = 14; statusLabel.TextWrapped = true

    local searchButton = createPillButton(frame, "Search Old Server", UDim2.new(0.5, 0, 0.45, 0), UDim2.new(0.85, 0, 0, 45))
    searchButton.AnchorPoint = Vector2.new(0.5, 0.5)

    local joinButton = createPillButton(frame, "Join Old Server", UDim2.new(0.5, 0, 0.75, 0), UDim2.new(0.85, 0, 0, 45))
    joinButton.AnchorPoint = Vector2.new(0.5, 0.5)

    searchButton.MouseButton1Click:Connect(function()
        if mainGui and mainGui.Parent then mainGui:Destroy() end
        quickNotify("Starting search for servers <= V" .. TARGET_MAX_VERSION, 3)
        coroutine.wrap(runMainLogic)("search_master", "", 0, HttpService:GenerateGUID(false))
    end)

    joinButton.MouseButton1Click:Connect(function()
        if mainGui and mainGui.Parent then mainGui:Destroy() end
        quickNotify("Searching Pastebin for servers <= V" .. TARGET_MAX_VERSION, 3)
        coroutine.wrap(runMainLogic)("join_master")
    end)
end

local function getPasteKeyFromFile(filename)
    if isfile and isfile(filename) then
        local s, k = pcall(function() return readfile(filename) end)
        if s and k and #k > 0 then return k:match("^%s*(.-)%s*$") end
    end
    return nil
end

local function savePasteKeyToFile(filename, key)
    if key and writefile then pcall(function() writefile(filename, key) end)
    elseif not key and delfile and isfile and isfile(filename) then pcall(function() delfile(filename) end)
    end
end

local function getRawPasteContent(pasteKey)
    if not pasteKey then return nil, "No paste key provided" end
    local rawUrl = "https://pastebin.com/raw/" .. pasteKey
    local success, contentOrError = pcall(function() return game:HttpGet(rawUrl, true) end)
    if success then
        if type(contentOrError) == "string" and contentOrError:lower():match("pastebin.com has been blocked|error processing request|this paste has been removed|this is a private paste|paste does not exist|not a valid paste id") then
            print("Pastebin fetch error for key " .. pasteKey .. ": Paste issue (removed/private/blocked/not exist/invalid).")
            return nil, "Paste issue"
        end
        return contentOrError, nil
    else
        print("Failed to fetch from Pastebin (key: " .. pasteKey .. "). Network/HTTP Error: "..tostring(contentOrError))
        return nil, "Network/HTTP Error: " .. tostring(contentOrError)
    end
end

local HttpPostAsync = HttpService.PostAsync or (HttpService.RequestAsync and function(url, body, contentType, _)
    local response = HttpService:RequestAsync({Url = url, Method = "POST", Headers = {["Content-Type"] = contentType}, Body = body})
    if response and response.Success then return response.Body
    elseif response then return "Error: "..response.StatusCode.." "..response.StatusMessage.." Body: ".. (response.Body or "")
    else return "Error: RequestAsync failed without response" end
end)

local function createPastebinPaste(name, content)
    if not HttpPostAsync then quickNotify("HttpPostAsync not available!", 5); return nil, "HTTP POST not available" end
    if PASTEBIN_API_DEV_KEY == "YOUR_PASTEBIN_DEV_KEY_HERE" then quickNotify("Pastebin Dev Key not set!", 5); return nil, "Dev key not set" end

    if #content > MAX_PASTE_SIZE_BYTES then
        quickNotify("Error: Content for paste '" .. name .. "' is too large (" .. #content .. " bytes). Max is ~"..math.floor(MAX_PASTE_SIZE_BYTES/1024) .."KB. Paste not created.", 10)
        warn("Content too large for Pastebin: " .. name .. ", size: " .. #content)
        return nil, "Content too large (proactive check)" 
    end
    if #content == 0 then content = "-- Empty Paste " .. os.date("!%Y-%m-%d %H:%M") .. " --" end

    local params = {
        api_dev_key = PASTEBIN_API_DEV_KEY, api_option = "paste", api_paste_code = content,
        api_paste_name = name .. " " .. os.date("!%Y-%m-%d_%H%M"), api_paste_private = "1",
        api_paste_expire_date = PASTE_EXPIRY_TIME, api_paste_format = "text"
    }
    if ACQUIRED_API_USER_KEY and ACQUIRED_API_USER_KEY ~= "YOUR_ACQUIRED_API_USER_KEY_HERE" and ACQUIRED_API_USER_KEY ~= "" then
        params.api_user_key = ACQUIRED_API_USER_KEY
    end

    local bodyParts = {}
    for key, value in pairs(params) do table.insert(bodyParts, HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(value)) end
    local requestBody = table.concat(bodyParts, "&")
    local pastebinApiUrl = "https://pastebin.com/api/api_post.php"

    print((params.api_user_key and "User " or "Guest ") .. "Creating Pastebin: " .. name .. " (Size: " .. #content .. " bytes)")
    local success, response = pcall(HttpPostAsync, HttpService, pastebinApiUrl, requestBody, Enum.HttpContentType.ApplicationUrlEncoded, false)

    if success and response and type(response) == "string" then
        if response:match("^https?://pastebin.com/") then
            local newKey = response:match("pastebin.com/([^/]+)$")
            print("Pastebin created: " .. response .. (newKey and (" (Key: " .. newKey .. ")") or ""))
            return newKey, response
        elseif response:lower():match("maximum paste file size exceeded") then
            quickNotify("Pastebin API: Max file size exceeded for '"..name.."'", 7)
            warn("Pastebin API Error (Create - Max Size): ", name, response)
            return nil, "Max file size exceeded (API)"
        elseif response:lower():match("api_paste_code was empty") then
            quickNotify("Pastebin API: Paste content was empty for '"..name.."'", 7)
            warn("Pastebin API Error (Create - Empty Content): ", name, response)
            return nil, "Empty content (API)"
        else
            quickNotify("Pastebin API Error (Create): " .. tostring(response):sub(1,100), 7)
            warn("Pastebin API Error (Create - Other): ", name, response)
            return nil, response
        end
    else
        quickNotify("Pastebin HTTP Error (Create): " .. tostring(response or "Unknown HTTP error"), 7)
        warn("Pastebin HTTP Error (Create): ", name, response)
        return nil, tostring(response or "Unknown HTTP error")
    end
end

local function deletePastebinPaste(pasteKeyToDelete)
    if not HttpPostAsync then quickNotify("HttpPostAsync not available for delete!", 5); return false end
    if PASTEBIN_API_DEV_KEY == "YOUR_PASTEBIN_DEV_KEY_HERE" then quickNotify("Pastebin Dev Key not set for delete!", 5); return false end
    if not ACQUIRED_API_USER_KEY or ACQUIRED_API_USER_KEY == "YOUR_ACQUIRED_API_USER_KEY_HERE" or ACQUIRED_API_USER_KEY == "" then
        print("Cannot delete paste " .. pasteKeyToDelete .. ": api_user_key not available.")
        return false
    end

    print("Attempting to delete Pastebin paste: " .. pasteKeyToDelete)
    local params = {
        api_dev_key = PASTEBIN_API_DEV_KEY, api_user_key = ACQUIRED_API_USER_KEY,
        api_paste_key = pasteKeyToDelete, api_option = "delete"
    }
    local bodyParts = {}
    for key, value in pairs(params) do table.insert(bodyParts, HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(value)) end
    local requestBody = table.concat(bodyParts, "&")
    local pastebinApiUrl = "https://pastebin.com/api/api_post.php"

    local success, response = pcall(HttpPostAsync, HttpService, pastebinApiUrl, requestBody, Enum.HttpContentType.ApplicationUrlEncoded, false)
    if success and response then
        if response == "Paste Removed" then
            print("Successfully deleted Pastebin paste: " .. pasteKeyToDelete)
            quickNotify("Deleted old Pastebin: " .. pasteKeyToDelete:sub(1,8), 3)
            return true
        else
            quickNotify("Failed to delete Pastebin " .. pasteKeyToDelete:sub(1,8) .. ". Resp: " .. tostring(response):sub(1,50), 5)
            warn("Failed to delete Pastebin. Key: " .. pasteKeyToDelete .. ". Response: ", response)
            return false
        end
    else
        quickNotify("Error during Pastebin delete req for " .. pasteKeyToDelete:sub(1,8) .. ". Err: " .. tostring(response):sub(1,50), 5)
        warn("Error during Pastebin delete request for " .. pasteKeyToDelete .. ". Error: ", response)
        return false
    end
end

local function updatePastebinList(listType, newDataToAdd)
    newDataToAdd = newDataToAdd or {}
    local pasteKeyFile = (listType == "old" and OLD_SERVERS_PASTE_KEY_FILE or UPTODATE_SERVERS_PASTE_KEY_FILE)
    local pasteNamePrefix = (listType == "old" and OLD_SERVERS_PASTE_FILENAME_PREFIX or UPTODATE_SERVERS_PASTE_FILENAME_PREFIX)
    local oldKey = getPasteKeyFromFile(pasteKeyFile)
    local existingContent = ""
    if oldKey then
        local fetchedContent, fetchError = getRawPasteContent(oldKey)
        if fetchedContent then existingContent = fetchedContent
        else
            print("Old paste key '" .. oldKey .. "' for " .. listType .. " invalid. Details: " .. (fetchError or "N/A"))
            savePasteKeyToFile(pasteKeyFile, nil); oldKey = nil 
        end
    end

    local combinedLines = {}
    if existingContent ~= "" then
        for line in existingContent:gmatch("[^\r\n]+") do table.insert(combinedLines, line) end
    end
    for _, newLine in ipairs(newDataToAdd) do table.insert(combinedLines, newLine) end
    
    local uniqueLines = {}; local seenJobIds = {}
    for i = #combinedLines, 1, -1 do 
        local line = combinedLines[i]
        local jobId = line:match("^([^|]+)%s*|") 
        if jobId then
            jobId = jobId:gsub("%s+", "") 
            if not seenJobIds[jobId] then 
                table.insert(uniqueLines, 1, line); 
                seenJobIds[jobId] = true 
            end
        else
            table.insert(uniqueLines, 1, line) 
        end
    end

    local newContentCombined = table.concat(uniqueLines, "\n")
    if newContentCombined == "" and #newDataToAdd == 0 then newContentCombined = "-- Empty " .. listType .. " List -- " .. os.date("!%Y-%m-%d %H:%M") end

    local originalLength = #newContentCombined
    while #newContentCombined > MAX_PASTE_SIZE_BYTES and #uniqueLines > 1 do 
        table.remove(uniqueLines, 1) 
        newContentCombined = table.concat(uniqueLines, "\n")
    end
    if originalLength > MAX_PASTE_SIZE_BYTES and #newContentCombined <= MAX_PASTE_SIZE_BYTES then
        print("Truncated " .. listType .. " list from " .. originalLength .. " to " .. #newContentCombined .. " bytes to fit Pastebin limit.")
        quickNotify("Truncated " .. listType .. " list due to size.", 4)
        if newContentCombined == "" then newContentCombined = "-- List Emptied by Truncation -- " .. os.date("!%Y-%m-%d %H:%M") end
    end
    
    local newKey, creationResponse = createPastebinPaste(pasteNamePrefix, newContentCombined)
    if newKey then
        savePasteKeyToFile(pasteKeyFile, newKey)
        print(listType .. " list updated. New key: " .. newKey .. ". URL: " .. (type(creationResponse) == "string" and creationResponse:match("^http") and creationResponse or "N/A"))
        quickNotify(listType .. " list updated. Key: " .. newKey:sub(1,8), 3)
        if oldKey and oldKey ~= newKey and ACQUIRED_API_USER_KEY and ACQUIRED_API_USER_KEY ~= "" and ACQUIRED_API_USER_KEY ~= "YOUR_ACQUIRED_API_USER_KEY_HERE" then
            deletePastebinPaste(oldKey)
        elseif oldKey and oldKey ~= newKey then print("Old " .. listType .. " paste (" .. oldKey .. ") not deleted (no user_key or other). Will expire.") end
    else
        print("Failed to update " .. listType .. " list. Error: " .. tostring(creationResponse))
        quickNotify("Failed to update " .. listType .. " list. Err: " .. tostring(creationResponse):sub(1,30), 5)
    end
end

local function ensurePastebinListExists(listType)
    local listName = listType == "old" and "Old Servers" or "UpToDate Servers"
    print("Ensuring Pastebin list exists for: " .. listName)
    local keyFile = (listType == "old" and OLD_SERVERS_PASTE_KEY_FILE or UPTODATE_SERVERS_PASTE_KEY_FILE)
    local currentKey = getPasteKeyFromFile(keyFile)
    local createNew = false
    if not currentKey then 
        print("Local key for '"..listName.."' not found.")
        createNew = true
    else
        local _, err = getRawPasteContent(currentKey) 
        if err then 
            print(listName .. " paste (key: " .. currentKey .. ") invalid/unfetchable. Error: " .. err .. ". Will create new.")
            savePasteKeyToFile(keyFile, nil); 
            createNew = true
        end
    end
    if createNew then
        quickNotify("Creating initial '" .. listName .. "' Pastebin list...", 3)
        updatePastebinList(listType, {"-- Initial " .. listName .. " List (" .. os.date("!%Y-%m-%d %H:%M") .. ") --"})
        return getPasteKeyFromFile(keyFile) ~= nil 
    end
    print(listName.." list (key: "..currentKey..") exists and seems accessible.")
    return true
end

local function loadServerListFromPastebin(pasteKey)
    local serversSet = {}; local serverDetails = {}
    if not pasteKey then return serversSet, serverDetails end
    local content, err = getRawPasteContent(pasteKey)
    if content then
        for line in string.gmatch(content, "[^\r\n]+") do
            local jobId = line:match("^([^|]+)%s*|")
            if jobId then jobId = jobId:gsub("%s+", ""); serversSet[jobId] = true; serverDetails[jobId] = line end
        end
    else print("Could not load server list from paste key:", pasteKey, "Error:", err) end
    return serversSet, serverDetails
end

function runMainLogic(mode, arg1, arg2, arg3, arg4, arg5) 
    if not player then player = Players.LocalPlayer end
    if not player then quickNotify("LocalPlayer not found!", 5); return end

    if mode ~= "initial_gui" and mode ~= "join_master_fetch_list" then
        if game.PlaceId ~= TARGET_PLACE_ID then
            quickNotify("Script for Grow A Garden (ID " .. TARGET_PLACE_ID .. ") only. Current: " .. game.PlaceId, 7)
            if mode ~= "search_slave_check_version" then pcall(createMainGui) end
            return
        end
    end
    
    print("Running Mode:", mode, arg1, arg2, arg3, arg4, arg5)

    if mode == "initial_gui" then
        pcall(createMainGui)

    elseif mode == "search_master" then
        local oldListOK = ensurePastebinListExists("old")
        local upToDateListOK = ensurePastebinListExists("uptodate")
        if not (oldListOK and upToDateListOK) then
            quickNotify("Failed to initialize Pastebin lists. Cannot start search.", 7); pcall(createMainGui); return
        end
        
        local cursor = arg1 or ""; local processedIdx = arg2 or 0
        local searchSessionId = arg3 or HttpService:GenerateGUID(false)
        if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Loading known servers..." else quickNotify("Search: Loading known servers...",2) end

        local oldServersKey = getPasteKeyFromFile(OLD_SERVERS_PASTE_KEY_FILE)
        local upToDateServersKey = getPasteKeyFromFile(UPTODATE_SERVERS_PASTE_KEY_FILE)
        local knownOldSet, _ = loadServerListFromPastebin(oldServersKey)
        local knownUpToDateSet, _ = loadServerListFromPastebin(upToDateServersKey)
        
        -- Use getTableKeys instead of table.keys
        print("Known old servers count: " .. #getTableKeys(knownOldSet))
        print("Known up-to-date servers count: " .. #getTableKeys(knownUpToDateSet))
        
        if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Fetching Roblox servers..." else quickNotify("Search: Fetching Roblox servers...",2) end
        local serversUrl = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=50&cursor=%s", TARGET_PLACE_ID, cursor)
        local success, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(serversUrl, true)) end)

        if not success or not response or not response.data then
            quickNotify("Failed to fetch Roblox server list. " .. tostring(response or "Network error"), 7); pcall(createMainGui); return
        end

        local serversToProcess = response.data; local nextTargetServer = nil; local nextProcessedIdxOnPage = processedIdx
        for i = processedIdx + 1, #serversToProcess do
            local server = serversToProcess[i]
            if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 999) then
                if not knownOldSet[server.id] and not knownUpToDateSet[server.id] then
                    nextTargetServer = server; nextProcessedIdxOnPage = i; break
                end
            end
        end
        
        if nextTargetServer then
            if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Teleporting to " .. nextTargetServer.id:sub(1,8) else quickNotify("Search: Teleporting to "..nextTargetServer.id:sub(1,8),2) end
            local payload = string.format("'%s', '%s', '%s', %d, '%s', %s", 
                                          "search_slave_check_version", tostring(nextTargetServer.id), 
                                          cursor, nextProcessedIdxOnPage, searchSessionId, tostring(TARGET_MAX_VERSION))
            if queue_on_teleport and SCRIPT_RELOAD_URL ~= "" and SCRIPT_RELOAD_URL ~= "YOUR_RAW_URL_TO_THIS_SCRIPT_HERE" then
                local ts = string.format([[local u="%s";local s,c=pcall(game.HttpGet,game,u,true);if s and c then local entryPoint=loadstring(c)();if type(entryPoint)=='function' then entryPoint(%s)else print("TS Error: entryPoint not func")end else print("TS Error: HttpGet fail or script load error: "..tostring(c))end]], SCRIPT_RELOAD_URL, payload)
                queue_on_teleport(ts)
            elseif queue_on_teleport then
                 print("WARNING: SCRIPT_RELOAD_URL not set correctly. queue_on_teleport may not function as intended.")
            end
            pcall(TeleportService.TeleportToPlaceInstance, TeleportService, TARGET_PLACE_ID, nextTargetServer.id, player)
        else
            if response.nextPageCursor then
                if statusLabel and statusLabel.Parent then statusLabel.Text = "Search: Next page..." else quickNotify("Search: Next page...",2) end
                runMainLogic("search_master", response.nextPageCursor, 0, searchSessionId)
            else
                quickNotify("Search completed. All reachable servers known or processed.", 7); pcall(createMainGui)
            end
        end

    elseif mode == "search_slave_check_version" then
        local expectedJobId = arg1; local originalCursor = arg2
        local originalProcessedIdxOnPage = arg3; local searchSessionId = arg4
        local currentTargetMaxVersion = tonumber(arg5) or TARGET_MAX_VERSION

        local currentJobId = game.JobId; local currentVersion = tonumber(game.PlaceVersion)
        local timestamp = os.date("!%Y-%m-%d %H:%M:%S [UTC]")
        quickNotify("Slave: Checking server " .. currentJobId:sub(1,8) .. " V:" .. tostring(currentVersion or "N/A"), 3)
        if currentJobId ~= expectedJobId then warn("Search Slave: JobID mismatch! Expected "..expectedJobId..", got "..currentJobId) end
        local newDataEntry = { string.format("%s | Version: %s | Timestamp: %s", currentJobId, tostring(currentVersion or "N/A"), timestamp) }
        
        if currentVersion and currentVersion <= currentTargetMaxVersion then
            updatePastebinList("old", newDataEntry) 
        else
            updatePastebinList("uptodate", newDataEntry)
        end
        local payload = string.format("'%s', '%s', %d, '%s'", 
                                      "search_master", originalCursor, originalProcessedIdxOnPage, searchSessionId)
        if queue_on_teleport and SCRIPT_RELOAD_URL ~= "" and SCRIPT_RELOAD_URL ~= "YOUR_RAW_URL_TO_THIS_SCRIPT_HERE" then
            local ts = string.format([[local u="%s";local s,c=pcall(game.HttpGet,game,u,true);if s and c then local entryPoint=loadstring(c)();if type(entryPoint)=='function' then entryPoint(%s)else print("TS Error: entryPoint not func")end else print("TS Error: HttpGet fail or script load error: "..tostring(c))end]], SCRIPT_RELOAD_URL, payload)
            queue_on_teleport(ts)
        elseif queue_on_teleport then
             print("WARNING: SCRIPT_RELOAD_URL not set for slave->master. queue_on_teleport may not function as intended.")
        end
        pcall(TeleportService.Teleport, TeleportService, TARGET_PLACE_ID, player)

    elseif mode == "join_master" then
        if not ensurePastebinListExists("old") then
            quickNotify("Failed to ensure 'Old Servers' list. Cannot join.", 7); pcall(createMainGui); return
        end
        quickNotify("Join: Fetching old servers (<= V" .. TARGET_MAX_VERSION .. ")..", 3)
        local oldServersKey = getPasteKeyFromFile(OLD_SERVERS_PASTE_KEY_FILE)
        local _, serverDetailsMap = loadServerListFromPastebin(oldServersKey)
        local serverEntries = {}
        if serverDetailsMap then for _, line in pairs(serverDetailsMap) do table.insert(serverEntries, line) end end
        if #serverEntries == 0 then quickNotify("Old server list is empty.", 5); pcall(createMainGui); return end
        table.sort(serverEntries, function(a,b) local tsA=a:match("Timestamp:%s*(.+)$")or"0";local tsB=b:match("Timestamp:%s*(.+)$")or"0";return tsA>tsB end)
        for i = 1, #serverEntries do
            local line = serverEntries[i]; local jobId = line:match("^([^|]+)%s*|")
            local versionInList = tonumber(line:match("Version:%s*([^|]+)")) 
            if jobId then
                if versionInList and versionInList <= TARGET_MAX_VERSION then 
                    jobId = jobId:gsub("%s+", "")
                    quickNotify("Join: Attempting " .. jobId:sub(1,8) .. " (V" .. versionInList .. ")", 3)
                    local success, err = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, TARGET_PLACE_ID, jobId, player)
                    if success then
                        local checkPayload = string.format("'%s', '%s', %s", "join_slave_confirm", jobId, tostring(TARGET_MAX_VERSION))
                        if queue_on_teleport and SCRIPT_RELOAD_URL ~= "" and SCRIPT_RELOAD_URL ~= "YOUR_RAW_URL_TO_THIS_SCRIPT_HERE" then
                             local ts = string.format([[wait(7);local u="%s";local s,c=pcall(game.HttpGet,game,u,true);if s and c then local entryPoint=loadstring(c)();if type(entryPoint)=='function' then entryPoint(%s)else print("TS Error: entryPoint not func")end else print("TS Error: HttpGet fail or script load error: "..tostring(c))end]], SCRIPT_RELOAD_URL, checkPayload)
                             queue_on_teleport(ts)
                        elseif queue_on_teleport then
                            print("WARNING: SCRIPT_RELOAD_URL not set for join_slave. queue_on_teleport may not function as intended.")
                        end
                        return
                    else quickNotify("Join Fail " .. jobId:sub(1,8) .. ": " .. tostring(err):sub(1,30), 4) end
                else
                    print("Skipping server from 'Old List' as its listed version (" .. tostring(versionInList) .. ") > target (" .. TARGET_MAX_VERSION .. "): " .. jobId)
                end
            end
        end
        quickNotify("Tried all suitable old servers. None joinable or list exhausted.", 7); pcall(createMainGui)
    
    elseif mode == "join_slave_confirm" then
        local expectedJobId = arg1
        local currentTargetMaxVersion = tonumber(arg2) or TARGET_MAX_VERSION
        local currentJobId = game.JobId; local currentVersion = tonumber(game.PlaceVersion)
        if currentJobId == expectedJobId then
            if currentVersion and currentVersion <= currentTargetMaxVersion then quickNotify("Joined OLD server: " .. currentJobId:sub(1,8) .. " V" .. currentVersion, 10)
            else quickNotify("Joined server " .. currentJobId:sub(1,8) .. " (V" .. tostring(currentVersion) .. ", not old by target V" .. currentTargetMaxVersion .. ").", 10) end
        else quickNotify("Joined different server. Expected: "..expectedJobId:sub(1,8)..", Is: "..currentJobId:sub(1,8), 10) end
        wait(10); pcall(createMainGui)
    end
end

local function antiAfk()
    if player and player.Idled then
        player.Idled:Connect(function() local vu=game:GetService("VirtualUser");vu:CaptureController();vu:ClickButton2(Vector2.new()) end)
    end
end

local function main(targetMaxVersionParam) 
    if targetMaxVersionParam ~= nil then 
        local numParam = tonumber(targetMaxVersionParam)
        if numParam then
            TARGET_MAX_VERSION = numParam
            print("Target Max Version set from parameter: " .. TARGET_MAX_VERSION)
        else
            print("Warning: Invalid targetMaxVersionParam provided ('"..tostring(targetMaxVersionParam).."'), using default: " .. DEFAULT_TARGET_MAX_VERSION)
            TARGET_MAX_VERSION = DEFAULT_TARGET_MAX_VERSION
        end
    else
        print("No targetMaxVersionParam for this call, using current/default: " .. TARGET_MAX_VERSION)
    end
    quickNotify("Target Version <= " .. TARGET_MAX_VERSION, 4)

    local configError = false
    local configErrorMsg = "SCRIPT CONFIGURATION ISSUE: "
    if PASTEBIN_API_DEV_KEY == "YOUR_PASTEBIN_DEV_KEY_HERE" then configError = true; configErrorMsg = configErrorMsg .. "Set PASTEBIN_API_DEV_KEY. " end
    if ACQUIRED_API_USER_KEY == "YOUR_ACQUIRED_API_USER_KEY_HERE" then 
        configError = true; configErrorMsg = configErrorMsg .. "Set ACQUIRED_API_USER_KEY. "
    end
    if SCRIPT_RELOAD_URL == "YOUR_RAW_URL_TO_THIS_SCRIPT_HERE" then 
        print("INFO: SCRIPT_RELOAD_URL is using a placeholder. For queue_on_teleport to reload THIS script from a URL, update this value. Otherwise, it relies on auto-execute.")
    end

    if configError then
        quickNotify(configErrorMsg .. "\nPlease edit the script file.", 30)
        return function() print("Script aborted due to configuration error.") end 
    end

    if not player then
        local playerAddedConn
        playerAddedConn = Players.PlayerAdded:Connect(function(p)
            if p == Players.LocalPlayer then 
                player = p; 
                if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil; end
                antiAfk(); 
                runMainLogic("initial_gui") 
            end
        end)
    else
        antiAfk()
        if not (mainGui and mainGui.Parent) then
             runMainLogic("initial_gui")
        end
    end
    
    return runMainLogic 
end

-- No longer attempting to modify global 'table'
return main
