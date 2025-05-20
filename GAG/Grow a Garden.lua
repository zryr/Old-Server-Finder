--[[
    Grow a Garden - Old Server Finder/Joiner with GitHub Backend & GUI
    Step 7: Integrate Search Master/Slave logic with GitHub backend
    Version: Krnl_GitHub_Full_v1.0
]]

local DEBUG_PREFIX = "GAG_GH_V1: "
print(DEBUG_PREFIX .. "Script execution started.")

-- ------------------------------------------------------------------------------------
-- CONFIGURATION - !!! REPLACE GITHUB_PAT & VERIFY SCRIPT_RELOAD_URL !!!
-- ------------------------------------------------------------------------------------
local GITHUB_USERNAME = "Zryr"
local GITHUB_REPONAME = "Old-Server-Finder"
local GITHUB_PAT = "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" -- !!! REPLACE WITH YOUR NEW, SECURE PAT !!!

local SCRIPT_RELOAD_URL = "https://raw.githubusercontent.com/zryr/Old-Server-Finder/refs/heads/main/GAG/Grow%20a%20Garden.lua" 

local DEFAULT_TARGET_MAX_VERSION = 1226
local TARGET_PLACE_ID = 16109285695 -- Grow a Garden!
-- ------------------------------------------------------------------------------------

local CURRENT_TARGET_MAX_VERSION = DEFAULT_TARGET_MAX_VERSION 

local HttpService = game:GetService("HttpService") 
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mainGui = nil
local statusLabel = nil
local versionInputBox = nil 
local notificationManager = nil -- For Xaxa's notifications

local runMainLogic -- Forward declare

-- UTILITY FUNCTIONS --
local function getTableKeys(t) local ks={};if type(t)=="table"then for k,_ in pairs(t)do table.insert(ks,k)end end;return ks end

local xaxaNotificationFuncSource = [[
return function(message, lifetime, position)
    local notificationLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/laagginq/ui-libraries/main/xaxas-notification/src.lua", true))()
    if not notificationLibrary then print("XAXA NOTIF LIB FAILED TO LOAD"); return end
    local notifications = notificationLibrary.new({
        NotificationLifetime = lifetime or 3,
        NotificationPosition = position or "Middle",
        TextFont = Enum.Font.Code, TextColor = Color3.fromRGB(255,255,255), TextSize = 15,
        TextStrokeTransparency = 0, TextStrokeColor = Color3.fromRGB(0,0,0)
    })
    notifications:BuildNotificationUI()
    notifications:Notify(message)
end
]]
local xaxaNotify -- Will be initialized later

local function notify(message, duration) -- Our script's notify function
    print("NOTIFY: " .. message)
    if xaxaNotify then
        pcall(xaxaNotify, message, duration or 3)
    else
        -- Fallback quick notify if xaxa isn't ready
        if not CoreGui then return end
        local existingNotif = CoreGui:FindFirstChild("FallbackNotification")
        if existingNotif then existingNotif:Destroy() end
        local ng=Instance.new("ScreenGui",CoreGui);ng.DisplayOrder=999999+1;ng.Name="FallbackNotification"
        local fr=Instance.new("Frame",ng);fr.Size=UDim2.new(0.35,0,0.1,0);fr.Position=UDim2.new(0.5,0,0.05,0);fr.AnchorPoint=Vector2.new(0.5,0);fr.BackgroundColor3=Color3.fromRGB(30,30,30);fr.BackgroundTransparency=0.2;Instance.new("UICorner",fr).CornerRadius=UDim.new(0,8)
        local lbl=Instance.new("TextLabel",fr);lbl.Size=UDim2.new(1,-20,1,-10);lbl.Position=UDim2.new(0.5,0,0.5,0);lbl.AnchorPoint=Vector2.new(0.5,0.5);lbl.BackgroundTransparency=1;lbl.TextColor3=Color3.new(1,1,1);lbl.TextWrapped=true;lbl.Font=Enum.Font.SourceSansSemibold;lbl.TextSize=16;lbl.Text=message
        Debris:AddItem(ng,duration or 5)
    end
end

local function createPillButton(parent,text,pos,size) local b=Instance.new("TextButton",parent);b.Text=text;b.Size=size;b.Position=pos;b.BackgroundColor3=Color3.fromRGB(70,130,180);b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.SourceSansBold;b.TextSize=18;b.AutoButtonColor=true;Instance.new("UICorner",b).CornerRadius=UDim.new(0.5,0);return b end
local function getTimestampGMTMinus5() local gmtM5Ts=os.time()-(5*3600); return os.date("!%Y-%m-%d %H:%M:%S (GMT-5)",gmtM5Ts) end
local function crappyBase64Encode(str_in) local str=str_in or"";local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';local s=string.gsub(str,'[^\32-\126\n\r]','');local l=#s;local t={};if l==0 then return""end;for i=1,math.floor(l/3)do local c1,c2,c3=string.byte(s,i*3-2,i*3);table.insert(t,b:sub(math.floor(c1/4)+1,math.floor(c1/4)+1));table.insert(t,b:sub(math.floor((c1%4)*16+c2/16)+1,math.floor((c1%4)*16+c2/16)+1));table.insert(t,b:sub(math.floor((c2%16)*4+c3/64)+1,math.floor((c2%16)*4+c3/64)+1));table.insert(t,b:sub(c3%64+1,c3%64+1));end;local m=l%3;if m==1 then local c1=string.byte(s,l);table.insert(t,b:sub(math.floor(c1/4)+1,math.floor(c1/4)+1));table.insert(t,b:sub((c1%4)*16+1,(c1%4)*16+1));table.insert(t,'==');elseif m==2 then local c1,c2=string.byte(s,l-1,l);table.insert(t,b:sub(math.floor(c1/4)+1,math.floor(c1/4)+1));table.insert(t,b:sub(math.floor((c1%4)*16+c2/16)+1,math.floor((c1%4)*16+c2/16)+1));table.insert(t,b:sub((c2%16)*4+1,(c2%16)*4+1));table.insert(t,'=');end;return table.concat(t) end

-- HTTP Request Handler (Prioritizes global 'request', then 'syn.request', then HttpService)
local function customHttpRequest(requestTable)
    local success, responseData, httpMethodUsed
    if typeof(request) == "function" then 
        httpMethodUsed = "global 'request'"
        success, responseData = pcall(request, requestTable)
        if success then
            if type(responseData)=="table" and responseData.Body~=nil and responseData.StatusCode~=nil then if responseData.Success==nil then responseData.Success=(responseData.StatusCode>=200 and responseData.StatusCode<400)end
            elseif type(responseData)=="string"then responseData={Success=true,Body=responseData,StatusCode=200,StatusMessage="OK (inferred)"}
            else responseData={Success=false,Body=tostring(responseData),StatusCode=0,StatusMessage="Unrecognized response"}end
        else responseData={Success=false,Body=tostring(responseData),StatusCode=0,StatusMessage="Error calling global 'request'"}end
    elseif syn and syn.request then 
        httpMethodUsed = "syn.request"
        success, responseData = pcall(syn.request, requestTable)
        if not success then responseData={Success=false,Body=tostring(responseData),StatusCode=0,StatusMessage="Error calling syn.request"}end
    elseif HttpService.RequestAsync then 
        httpMethodUsed = "HttpService:RequestAsync"
        success, responseData = pcall(HttpService.RequestAsync, HttpService, requestTable)
        if not success then responseData={Success=false,Body=tostring(responseData),StatusCode=0,StatusMessage="Error calling Service:ReqAsync"}end
    else return nil,"No HTTP func"end
    print(DEBUG_PREFIX.."HTTP via "..httpMethodUsed.." to "..requestTable.Url..". Success: "..tostring(responseData and responseData.Success)..", Status: "..(responseData and responseData.StatusCode or "N/A"))
    if responseData and not responseData.Success then local eb=responseData.Body or"";local sm=responseData.StatusMessage or"";print(DEBUG_PREFIX.."Err Body: "..tostring(eb):sub(1,200));return responseData,"HTTP Err: "..(responseData.StatusCode or "N/A").." "..sm end
    return responseData,nil 
end

-- GitHub API Interaction Functions
local function getGithubFileSha(filePath) 
    if GITHUB_PAT==""or GITHUB_PAT:find("YOUR_")then notify("GitHub PAT not configured for getSHA!",5);return nil end
    local apiUrl=string.format("https://api.github.com/repos/%s/%s/contents/%s",GITHUB_USERNAME,GITHUB_REPONAME,filePath);
    local reqT={Url=apiUrl,Method="GET",Headers={["Authorization"]="token "..GITHUB_PAT,["Accept"]="application/vnd.github.v3+json"}};
    local respD,err=customHttpRequest(reqT);if err then if type(err)=="string"and err:match("404")or(type(respD)=="table"and respD.StatusCode==404)then print(DEBUG_PREFIX.."File "..filePath.." not found (404).")else print(DEBUG_PREFIX.."Failed to get SHA for "..filePath..". Err: "..err)end;return nil end
    if respD and respD.Body then local decS,decB=pcall(HttpService.JSONDecode,HttpService,respD.Body);if decS and decB and decB.sha then return decB.sha elseif decS and decB and decB.message and decB.message:lower():match("not found")then return nil end end;return nil 
end
local function getGithubRawContent(filePath) -- New function to get raw content
    if GITHUB_PAT==""or GITHUB_PAT:find("YOUR_")then notify("GitHub PAT not configured for getRawContent!",5);return nil end
    local apiUrl=string.format("https://api.github.com/repos/%s/%s/contents/%s",GITHUB_USERNAME,GITHUB_REPONAME,filePath);
    local reqT={Url=apiUrl,Method="GET",Headers={["Authorization"]="token "..GITHUB_PAT,["Accept"]="application/vnd.github.v3.raw"}} -- Crucial: .raw
    local respD,err=customHttpRequest(reqT)
    if err then print(DEBUG_PREFIX.."Failed to get raw content for "..filePath..". Err: "..err); return nil, err end
    if respD and respD.Body then return respD.Body, nil else return nil, "No body in raw content response" end
end
local function createOrUpdateGithubFile(filePath, rawContent, commitMessage) 
    if GITHUB_PAT==""or GITHUB_PAT:find("YOUR_")then notify("GitHub PAT not configured!",5);return false end
    local currentSha=getGithubFileSha(filePath);local apiUrl=string.format("https://api.github.com/repos/%s/%s/contents/%s",GITHUB_USERNAME,GITHUB_REPONAME,filePath)
    local encodedContent=crappyBase64Encode(rawContent);if encodedContent==""and rawContent~=""then notify("Base64 encoding failed.",5);return false end
    local payloadT={message=commitMessage,content=encodedContent};if currentSha then payloadT.sha=currentSha end
    local jsonData=HttpService:JSONEncode(payloadT)
    local reqT={Url=apiUrl,Method="PUT",Headers={["Authorization"]="token "..GITHUB_PAT,["Accept"]="application/vnd.github.v3+json",["Content-Type"]="application/json"},Body=jsonData}
    local respD,err=customHttpRequest(reqT)
    if err then notify("GitHub update fail: "..filePath:sub(1,15).."..."..err:sub(1,30),7);return false end
    if respD and respD.Body then notify("GitHub file "..filePath:sub(1,15).."... updated!",3);return true 
    else notify("GitHub update fail: "..filePath:sub(1,15).."... Invalid response.",7);return false end 
end

-- LIST MANAGEMENT (Using GitHub now)
local function loadListFromGithub(listType) -- Renamed conceptually
    print(DEBUG_PREFIX .. "loadListFromGithub called for type: " .. listType)
    local fileName = (listType == "old" and "Old_Servers_" or "Visited_Servers_") .. os.date("!%Y-%m-%d") .. ".txt"
    local filePath = "GAG/" .. fileName
    
    local content, err = getGithubRawContent(filePath)
    local serverSet = {}
    if content then
        for line in content:gmatch("[^\r\n]+") do
            -- Assuming each JobID is on its own line or easily extractable
            -- For the new multi-line format, we need to parse smarter
            -- For now, let's assume one JobID per "JobID: <id>" line for the set
            local jobId = line:match("^JobID:%s*([%w%-]+)")
            if jobId then serverSet[jobId] = true end
        end
        print(DEBUG_PREFIX .. "Loaded " .. #getTableKeys(serverSet) .. " JobIDs from GitHub file: " .. filePath)
    else
        print(DEBUG_PREFIX .. "Could not load GitHub file " .. filePath .. ". Error: " .. tostring(err) .. ". Treating as empty list.")
    end
    return serverSet
end

local function appendToListOnGithub(listType, serverDataString) -- serverDataString is the multi-line entry
    print(DEBUG_PREFIX .. "appendToListOnGithub called for type: " .. listType)
    local fileName = (listType == "old" and "Old_Servers_" or "Visited_Servers_") .. os.date("!%Y-%m-%d") .. ".txt"
    local filePath = "GAG/" .. fileName
    local commitMsg = "Append " .. listType .. " list: " .. os.date("!%H:%M:%S")

    local existingContent = ""; local sha = getGithubFileSha(filePath) -- getGithubFileSha will get SHA if exists
    if sha then -- File exists, get its content
        local fetchedContent, fetchErr = getGithubRawContent(filePath)
        if fetchedContent then existingContent = fetchedContent
        else print(DEBUG_PREFIX .. "Could not fetch existing GitHub file "..filePath.." to append. Error: "..tostring(fetchErr).." Will create/overwrite."); sha=nil end -- Force create if read fails
    end

    local newContent
    if existingContent == "" or existingContent:match("^-- Initial") or existingContent:match("^-- Empty") then
        newContent = serverDataString -- Start fresh if list was placeholder/empty
    else
        newContent = existingContent .. "\n\n" .. serverDataString -- Append with a blank line
    end
    
    -- Simple size check - if new content is huge, maybe just overwrite with new entry
    if #newContent > (MAX_PASTE_SIZE_BYTES * 0.9) and #serverDataString < (MAX_PASTE_SIZE_BYTES * 0.9) then -- Crude check
        print(DEBUG_PREFIX .. "Combined content for " .. filePath .. " might be too large. Overwriting with new entry only.")
        newContent = serverDataString
        sha = nil -- Force creation if overwriting due to size
    end

    return createOrUpdateGithubFile(filePath, newContent, commitMsg)
end


-- GUI Creation
local function createMainGui()
    print(DEBUG_PREFIX .. "createMainGui() called.")
    if not player then player = Players.LocalPlayer; if not player then print(DEBUG_PREFIX.."Player nil in createMainGui"); return end end
    local parentGui = player.PlayerGui or CoreGui; if not parentGui then print(DEBUG_PREFIX.."parentGui nil in createMainGui"); return end
    if mainGui and mainGui.Parent then mainGui:Destroy() end
    mainGui = Instance.new("ScreenGui", parentGui); mainGui.Name = "GAG_ServerFinderGUI_GH"; mainGui.DisplayOrder = 1000; mainGui.ResetOnSpawn = false

    local frame = Instance.new("Frame",mainGui);frame.Size=UDim2.new(0,320,0,270);frame.Position=UDim2.new(0.5,0,0.5,0);frame.AnchorPoint=Vector2.new(0.5,0.5);frame.BackgroundColor3=Color3.fromRGB(45,45,45);Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)
    local titleLabel=Instance.new("TextLabel",frame);titleLabel.Text="Grow A Garden - Finder";titleLabel.Size=UDim2.new(1,0,0,35);titleLabel.Position=UDim2.new(0,0,0,10);titleLabel.BackgroundTransparency=1;titleLabel.TextColor3=Color3.fromRGB(230,230,230);titleLabel.Font=Enum.Font.SourceSansSemibold;titleLabel.TextSize=20
    local versionLabel=Instance.new("TextLabel",frame);versionLabel.Text="Target Max Version:";versionLabel.Size=UDim2.new(0.9,0,0,20);versionLabel.Position=UDim2.new(0.5,0,0,45);versionLabel.AnchorPoint=Vector2.new(0.5,0);versionLabel.BackgroundTransparency=1;versionLabel.TextColor3=Color3.fromRGB(180,180,180);versionLabel.TextXAlignment=Enum.TextXAlignment.Left;versionLabel.Font=Enum.Font.SourceSans;versionLabel.TextSize=14
    versionInputBox=Instance.new("TextBox",frame);versionInputBox.Size=UDim2.new(0.85,0,0,35);versionInputBox.Position=UDim2.new(0.5,0,0,65);versionInputBox.AnchorPoint=Vector2.new(0.5,0);versionInputBox.BackgroundColor3=Color3.fromRGB(30,30,30);versionInputBox.TextColor3=Color3.fromRGB(220,220,220);versionInputBox.PlaceholderText="e.g. "..DEFAULT_TARGET_MAX_VERSION;versionInputBox.Text=tostring(CURRENT_TARGET_MAX_VERSION);versionInputBox.Font=Enum.Font.SourceSans;versionInputBox.TextSize=16;versionInputBox.ClearTextOnFocus=false;Instance.new("UICorner",versionInputBox).CornerRadius=UDim.new(0,8);local pad=Instance.new("UIPadding",versionInputBox);pad.PaddingLeft=UDim.new(0,10);pad.PaddingRight=UDim.new(0,10)
    statusLabel=Instance.new("TextLabel",frame);statusLabel.Text="Idle. Set target & select action.";statusLabel.Size=UDim2.new(1,-20,0,20);statusLabel.Position=UDim2.new(0.5,0,0,105);statusLabel.AnchorPoint=Vector2.new(0.5,0);statusLabel.BackgroundTransparency=1;statusLabel.TextColor3=Color3.fromRGB(180,180,180);statusLabel.Font=Enum.Font.SourceSansItalic;statusLabel.TextSize=14;statusLabel.TextWrapped=true
    local searchButton=createPillButton(frame,"Search Old Server",UDim2.new(0.5,0,0.65,0),UDim2.new(0.85,0,0,45));searchButton.AnchorPoint=Vector2.new(0.5,0.5)
    local joinButton=createPillButton(frame,"Join Old Server",UDim2.new(0.5,0,0.85,0),UDim2.new(0.85,0,0,45));joinButton.AnchorPoint=Vector2.new(0.5,0.5)
    local function updateTargetVersionFromInput() if not versionInputBox then return end;local num=tonumber(versionInputBox.Text);if num and num>0 then CURRENT_TARGET_MAX_VERSION=math.floor(num);notify("Target version <= V"..CURRENT_TARGET_MAX_VERSION,3);if statusLabel and statusLabel.Parent then statusLabel.Text="Target <= V"..CURRENT_TARGET_MAX_VERSION..". Select."end else notify("Invalid target. Using V"..CURRENT_TARGET_MAX_VERSION,3);versionInputBox.Text=tostring(CURRENT_TARGET_MAX_VERSION)end end
    if versionInputBox then versionInputBox.FocusLost:Connect(function(ep)if ep then updateTargetVersionFromInput()end end)end
    searchButton.MouseButton1Click:Connect(function()updateTargetVersionFromInput();if mainGui and mainGui.Parent then mainGui:Destroy()end;notify("Starting server search...",3);if runMainLogic then coroutine.wrap(runMainLogic)("search_master","",0,HttpService:GenerateGUID(false))end end)
    joinButton.MouseButton1Click:Connect(function()updateTargetVersionFromInput();if mainGui and mainGui.Parent then mainGui:Destroy()end;notify("Preparing to join server...",3);if runMainLogic then coroutine.wrap(runMainLogic)("join_master")end end)
    print(DEBUG_PREFIX.."Main GUI created.")
end

-- Main Logic Router (runMainLogic) --
runMainLogic = function(mode, arg1, arg2, arg3, arg4, arg5) -- arg5 is targetMaxVersion for slaves
    print(DEBUG_PREFIX .. "runMainLogic called with Mode:", mode)
    if not player then player = Players.LocalPlayer; if not player then notify("LocalPlayer not found!", 5); return end end
    
    local effectiveTargetMaxVersion = CURRENT_TARGET_MAX_VERSION -- From GUI
    if mode == "search_slave_check_version" or mode == "join_slave_confirm" then
        effectiveTargetMaxVersion = tonumber(arg5) or CURRENT_TARGET_MAX_VERSION -- Use version passed to slave
    end

    if mode == "initial_gui" then
        pcall(createMainGui)
    elseif mode == "search_master" then
        print(DEBUG_PREFIX .. "Search Master started. Target V <= " .. effectiveTargetMaxVersion)
        notify("Search started. Hopping servers...", 2)
        local cursor = arg1 or ""
        local processedJobIdsOnPage = arg2 or 0 -- This should be an index or count

        -- Load known servers from GitHub files
        local knownOldSet = loadListFromGithub("old")
        local knownVisitedSet = loadListFromGithub("uptodate") -- Changed from "UpToDate Servers" to "Visited_Servers" filename base
        
        local serversUrl = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=25&cursor=%s", TARGET_PLACE_ID, cursor) -- Limit 25 to be less aggressive
        local successHttp, responseData = pcall(HttpService.JSONDecode, HttpService, game:HttpGet(serversUrl, true))

        if not successHttp or not responseData or not responseData.data then
            notify("Failed to fetch Roblox server list: " .. tostring(responseData or "Network error"), 5)
            wait(10)
            runMainLogic("search_master", cursor, processedJobIdsOnPage, arg3, arg4, effectiveTargetMaxVersion) -- Retry same page
            return
        end

        local serversToProcess = responseData.data
        local teleported = false
        for i = 1, #serversToProcess do -- Iterate through current page
            local server = serversToProcess[i]
            if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 999) then
                if not knownOldSet[server.id] and not knownVisitedSet[server.id] then
                    notify("Found new server: " .. server.id:sub(1,8) .. ". Teleporting...", 2)
                    local payload = string.format("'%s', '%s', '%s', %d, '%s', %s", 
                                                  "search_slave_check_version", tostring(server.id), 
                                                  cursor, i, -- Pass current cursor and index on THIS page
                                                  arg3, -- searchSessionId
                                                  tostring(effectiveTargetMaxVersion))
                    if queue_on_teleport and SCRIPT_RELOAD_URL ~= "" and not SCRIPT_RELOAD_URL:find("YOUR_RAW_URL") then
                        local ts = string.format([[local u="%s";local s,c=pcall(game.HttpGet,game,u,true);if s and c then local entryPoint=loadstring(c)();if type(entryPoint)=='function' then entryPoint(%s)end else print("TS Error")end]], SCRIPT_RELOAD_URL, payload)
                        queue_on_teleport(ts)
                    end
                    pcall(TeleportService.TeleportToPlaceInstance, TeleportService, TARGET_PLACE_ID, server.id, player)
                    teleported = true
                    break -- Exit loop after teleporting
                end
            end
        end

        if not teleported then -- Finished page or no suitable servers on page
            if responseData.nextPageCursor then
                notify("Page processed. Getting next page of servers...", 2)
                runMainLogic("search_master", responseData.nextPageCursor, 0, arg3, arg4, effectiveTargetMaxVersion) -- Reset processed index for new page
            else
                notify("Search cycle complete. All known servers processed.", 5)
                pcall(createMainGui) -- Show GUI again
            end
        end

    elseif mode == "search_slave_check_version" then
        -- arg1=expectedJobId, arg2=originalCursor, arg3=originalProcessedIdx, arg4=searchSessionId, arg5=slaveTargetMaxVersion
        local currentJobId = game.JobId
        local currentVersion = tonumber(game.PlaceVersion)
        local timestamp = getTimestampGMTMinus5()
        notify("In server: " .. currentJobId:sub(1,8) .. " V: " .. tostring(currentVersion or "N/A"), 3)

        local entryString = string.format("JobID: %s\nVersion: %s\nTime: %s", currentJobId, tostring(currentVersion or "N/A"), timestamp)
        local listTypeToUpdate
        
        if currentVersion and currentVersion <= effectiveTargetMaxVersion then
            listTypeToUpdate = "old"
            notify("Server is OLD (V" .. currentVersion .. "). Logging to GitHub.", 3)
        else
            listTypeToUpdate = "uptodate" -- conceptually "visited_and_not_old"
            notify("Server is current (V" .. currentVersion .. "). Logging to GitHub.", 3)
        end
        appendToListOnGithub(listTypeToUpdate, entryString)
        
        wait(3) -- Give GitHub write a moment, and user to see notification
        -- Continue search from where master left off (it will skip the one we just processed because it's now "known")
        local payload = string.format("'%s', '%s', %d, '%s'", "search_master", arg2, arg3 + 1, arg4) -- originalCursor, originalProcessedIdx + 1, searchSessionId
        if queue_on_teleport and SCRIPT_RELOAD_URL ~= "" and not SCRIPT_RELOAD_URL:find("YOUR_RAW_URL") then
            local ts = string.format([[local u="%s";local s,c=pcall(game.HttpGet,game,u,true);if s and c then local entryPoint=loadstring(c)();if type(entryPoint)=='function' then entryPoint(%s)end else print("TS Error")end]], SCRIPT_RELOAD_URL, payload)
            queue_on_teleport(ts)
        end
        pcall(TeleportService.Teleport, TeleportService, TARGET_PLACE_ID, player) -- Hop to a random server to re-trigger master

    elseif mode == "join_master" then
        notify("Join Master: Fetching 'Old Servers' list from GitHub...", 3)
        -- This part will need to be fully fleshed out similar to the original Pastebin version
        -- For now, it's a placeholder.
        local oldServerJobIds = getTableKeys(loadListFromGithub("old"))
        if #oldServerJobIds == 0 then
            notify("No old servers found in GitHub list.", 5)
            pcall(createMainGui)
            return
        end
        notify("Join Master: Found " .. #oldServerJobIds .. " potential old servers. (Join logic not fully implemented)", 5)
        -- TODO: Iterate and try to join, handling full/invalid servers and using effectiveTargetMaxVersion.
        pcall(createMainGui)

    elseif mode == "join_slave_confirm" then
        local expectedJobId = arg1
        local slaveConfirmTargetMaxVersion = tonumber(arg2) or CURRENT_TARGET_MAX_VERSION
        local currentJobId=game.JobId; local currentVersion=tonumber(game.PlaceVersion)
        if currentJobId==expectedJobId then
            if currentVersion and currentVersion<=slaveConfirmTargetMaxVersion then notify("Joined OLD server: "..currentJobId:sub(1,8).." V"..currentVersion,10)
            else notify("Joined server "..currentJobId:sub(1,8).." (V"..tostring(currentVersion)..", not old by target V"..slaveConfirmTargetMaxVersion..").",10)end
        else notify("Joined different server. Expected: "..expectedJobId:sub(1,8)..", Is: "..currentJobId:sub(1,8),10)end
        wait(10);pcall(createMainGui)
    else
        print(DEBUG_PREFIX.."runMainLogic: Unknown mode:", mode); if not(mainGui and mainGui.Parent)then pcall(createMainGui)end 
    end
end

-- Anti-AFK & Main Entry Point --
local function antiAfk()print(DEBUG_PREFIX.."antiAfk() setup.");if player and player.Idled then player.Idled:Connect(function()print(DEBUG_PREFIX.."Anti-AFK triggered.");local vu=game:GetService("VirtualUser");vu:CaptureController();vu:ClickButton2(Vector2.new())end);print(DEBUG_PREFIX.."Anti-AFK connected.")else print(DEBUG_PREFIX.."Anti-AFK could not connect.")end end
local function mainEntryPoint() 
    print(DEBUG_PREFIX .. "mainEntryPoint() called.")
    CURRENT_TARGET_MAX_VERSION = DEFAULT_TARGET_MAX_VERSION 
    
    local s, xaxaLoaded = pcall(loadstring(xaxaNotificationFuncSource))
    if s and type(xaxaLoaded) == "function" then xaxaNotify = xaxaLoaded 
    else print(DEBUG_PREFIX .. "Failed to load Xaxa's notification library. Error: " .. tostring(xaxaLoaded)) end

    notify("Target Version initially <= " .. CURRENT_TARGET_MAX_VERSION, 4)

    local configError=false;local configErrorMsg="CONFIG ISSUE: "
    if GITHUB_PAT==""or GITHUB_PAT:find("YOUR_")then configError=true;configErrorMsg=configErrorMsg.."Set GITHUB_PAT. "end
    if SCRIPT_RELOAD_URL==""or SCRIPT_RELOAD_URL:find("YOUR_RAW_URL")then print("INFO: SCRIPT_RELOAD_URL placeholder.")end
    if configError then notify(configErrorMsg,30);return function()print("Aborted: config error.")end end

    if not player then print(DEBUG_PREFIX .. "Player nil, waiting.");local pc;pc=Players.PlayerAdded:Connect(function(p)if p==Players.LocalPlayer then player=p;if pc then pc:Disconnect();pc=nil;end;antiAfk();runMainLogic("initial_gui")end end)
    else antiAfk();if not(mainGui and mainGui.Parent)then runMainLogic("initial_gui")end end
    return runMainLogic 
end

print(DEBUG_PREFIX .. "Script top-level definitions complete.")
return mainEntryPoint() -- Return the result of mainEntryPoint, which is runMainLogic
