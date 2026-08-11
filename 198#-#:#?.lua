--==============================================================================
-- KILLER HUB UI - COMBINED MODULE (ROLE & DEAD DETECTION VIA PlayerDataChanged)
-- Creator: Killer Hub | By Paolo
--==============================================================================

local KillerHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/paoloskibidipro/noname/refs/heads/main/unknow.lua"))()

if getgenv().__KillerHub_Combined_Loaded then
    KillerHub:NotifyWarn("Already Loaded", "The script is already running.", 3)
    return
end
getgenv().__KillerHub_Combined_Loaded = true

-- Services Caching
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Fast Localizations
local os_clock = os.clock
local math_round = math.round
local math_clamp = math.clamp
local math_floor = math.floor
local string_format = string.format
local Vector3_zero = Vector3.zero

--------------------------------------------------------------------------------
-- 1. TAB CREATION
--------------------------------------------------------------------------------
local TabExtras = KillerHub:CreateTab("Extras", "Code")
local TabAutoFarm = KillerHub:CreateTab("Auto Farm", "Robot")

--------------------------------------------------------------------------------
-- EXTRAS MODULE STATE & LOGIC
--------------------------------------------------------------------------------
local function FormatTime(seconds)
    local mins = math_floor(seconds / 60)
    local secs = math_floor(seconds % 60)
    return string_format("%02d:%02d", math.max(0, mins), math.max(0, secs))
end

-- System Performance Overlay
local statsConnection = nil
local statsGui = nil
local statsFrame = nil
local statsBgTransparency = 0.25

local function CleanUpPerfOverlay()
    if statsConnection then
        statsConnection:Disconnect()
        statsConnection = nil
    end
    if statsGui then
        statsGui:Destroy()
        statsGui = nil
        statsFrame = nil
    end
end

-- Round Time UI
local RoundTimerGui = nil
local RoundTimerConnection = nil

local function CreateTimerUI()
    if RoundTimerGui then RoundTimerGui:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KillerHub_RoundTimer"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local TimeLabel = Instance.new("TextLabel")
    TimeLabel.Name = "TimeText"
    TimeLabel.Size = UDim2.new(0, 250, 0, 40)
    TimeLabel.Position = UDim2.new(0.5, -125, 0, -5)
    TimeLabel.BackgroundTransparency = 1
    TimeLabel.Font = Enum.Font.SciFi
    TimeLabel.TextSize = 38
    TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TimeLabel.TextStrokeTransparency = 0.3
    TimeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TimeLabel.Text = ""
    TimeLabel.Visible = false
    TimeLabel.Parent = ScreenGui

    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end

    RoundTimerGui = ScreenGui
    return TimeLabel
end

local function RemoveTimerUI()
    if RoundTimerGui then
        RoundTimerGui:Destroy()
        RoundTimerGui = nil
    end
end

-- Knife ESP Logic
local KnifeESP_Connection = nil
local KnifeWorkspaceConnection = nil
local ActiveKnifeAdornments = {}

local function ClearKnifeESP()
    for part, adornment in pairs(ActiveKnifeAdornments) do
        if adornment then adornment:Destroy() end
    end
    table.clear(ActiveKnifeAdornments)
end

local function CreateKnifeBox(targetPart)
    if not targetPart or ActiveKnifeAdornments[targetPart] then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "KillerHub_CleanKnifeBox"
    box.Color3 = Color3.fromRGB(0, 255, 100)
    box.Transparency = 0.3
    box.AlwaysOnTop = true
    box.ZIndex = 5

    if targetPart:IsA("BasePart") then
        box.Size = targetPart.Size + Vector3.new(0.3, 0.3, 0.3)
    else
        box.Size = Vector3.new(1.2, 2.5, 1.2)
    end

    box.Adornee = targetPart

    if syn and syn.protect_gui then
        syn.protect_gui(box)
        box.Parent = CoreGui
    elseif gethui then
        box.Parent = gethui()
    else
        box.Parent = CoreGui
    end

    ActiveKnifeAdornments[targetPart] = box
end

local function ProcessPartOrModel(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") or obj:IsA("Tool") then
        local handle = obj:FindFirstChild("Handle") or obj.PrimaryPart
        if handle and handle:IsA("BasePart") then
            return handle
        end
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("BasePart") then
                return child
            end
        end
    end
    return nil
end

local function IsPartEquippedOrInWorkspace(part)
    if not part or not part.Parent then return false end
    local tool = part:FindFirstAncestorOfClass("Tool")
    if tool then
        local character = tool.Parent
        if character and character:FindFirstChildOfClass("Humanoid") then
            return true
        end
        return false
    end
    return part:IsDescendantOf(Workspace)
end

-- Traps ESP Logic
local TrapsESP_Connection = nil
local TrapsWorkspaceConnection = nil
local ActiveTrapAdornments = {}

local function ClearTrapsESP()
    for part, adornment in pairs(ActiveTrapAdornments) do
        if adornment then adornment:Destroy() end
    end
    table.clear(ActiveTrapAdornments)
end

local function CreateTrapBox(targetPart)
    if not targetPart or ActiveTrapAdornments[targetPart] then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "KillerHub_TrapBox"
    box.Color3 = Color3.fromRGB(255, 30, 30)
    box.Transparency = 0.3
    box.AlwaysOnTop = true
    box.ZIndex = 5

    if targetPart:IsA("BasePart") then
        box.Size = targetPart.Size + Vector3.new(0.4, 0.4, 0.4)
    else
        box.Size = Vector3.new(2, 2, 2)
    end

    box.Adornee = targetPart

    if syn and syn.protect_gui then
        syn.protect_gui(box)
        box.Parent = CoreGui
    elseif gethui then
        box.Parent = gethui()
    else
        box.Parent = CoreGui
    end

    ActiveTrapAdornments[targetPart] = box
end

-- No Lights Logic
local NoLightsConnection = nil
local OriginalMaterials = {}
local OriginalLightProps = {}
local OriginalLightingProps = {}

local function RemoveBrightGlaring(inst)
    if inst:IsA("BasePart") and inst.Material == Enum.Material.Neon then
        if not OriginalMaterials[inst] then
            OriginalMaterials[inst] = inst.Material
        end
        inst.Material = Enum.Material.SmoothPlastic
    elseif inst:IsA("Light") then
        if not OriginalLightProps[inst] then
            OriginalLightProps[inst] = inst.Brightness
        end
        if inst.Brightness > 1.2 then
            inst.Brightness = 0.8
        end
    end
end

local function ApplyNoLightsSettings()
    OriginalLightingProps.OutdoorAmbient = Lighting.OutdoorAmbient
    OriginalLightingProps.Brightness = Lighting.Brightness

    local curOutdoor = Lighting.OutdoorAmbient
    Lighting.OutdoorAmbient = Color3.fromRGB(
        math_clamp(math_floor(curOutdoor.R * 255 * 0.55), 70, 255),
        math_clamp(math_floor(curOutdoor.G * 255 * 0.55), 70, 255),
        math_clamp(math_floor(curOutdoor.B * 255 * 0.55), 70, 255)
    )
    
    if Lighting.Brightness > 1.0 then
        Lighting.Brightness = 1.0
    end
end

local function RestoreOriginalLights()
    for part, mat in pairs(OriginalMaterials) do
        if part and part.Parent then
            part.Material = mat
        end
    end
    table.clear(OriginalMaterials)

    for light, brightness in pairs(OriginalLightProps) do
        if light and light.Parent then
            light.Brightness = brightness
        end
    end
    table.clear(OriginalLightProps)

    if OriginalLightingProps.OutdoorAmbient then
        Lighting.OutdoorAmbient = OriginalLightingProps.OutdoorAmbient
    end
    if OriginalLightingProps.Brightness then
        Lighting.Brightness = OriginalLightingProps.Brightness
    end
    table.clear(OriginalLightingProps)
end

--------------------------------------------------------------------------------
-- EXTRAS CONTROLS
--------------------------------------------------------------------------------
TabExtras:CreateSection("Performance")

TabExtras:CreateToggle("Extras_PerformanceStats", "Show Stats", function(estado)
    CleanUpPerfOverlay()
    
    if estado then
        statsGui = Instance.new("ScreenGui")
        statsGui.Name = "KillerHub_PerformanceOverlay"
        statsGui.ResetOnSpawn = false

        statsFrame = Instance.new("Frame")
        statsFrame.Size = UDim2.new(0, 155, 0, 72)
        statsFrame.Position = UDim2.new(1, -162, 0, 2)
        statsFrame.BackgroundColor3 = Color3.fromRGB(12, 4, 22)
        statsFrame.BackgroundTransparency = statsBgTransparency
        statsFrame.BorderSizePixel = 0

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = statsFrame

        local Stroke = Instance.new("UIStroke")
        Stroke.Thickness = 1.2
        Stroke.Color = Color3.fromRGB(40, 15, 65)
        Stroke.Parent = statsFrame

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -10, 1, -6)
        TextLabel.Position = UDim2.new(0, 8, 0, 3)
        TextLabel.BackgroundTransparency = 1
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Font = Enum.Font.GothamBold
        TextLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
        TextLabel.TextSize = 12
        TextLabel.LineHeight = 1.25
        TextLabel.RichText = true
        TextLabel.Text = "Loading..."
        TextLabel.Parent = statsFrame

        statsFrame.Parent = statsGui

        if syn and syn.protect_gui then
            syn.protect_gui(statsGui)
            statsGui.Parent = CoreGui
        elseif gethui then
            statsGui.Parent = gethui()
        else
            statsGui.Parent = CoreGui
        end

        local lastTime = os_clock()
        local frameCount = 0
        local currentFps = 60
        local pingObject = nil
        pcall(function() pingObject = StatsService.Network.ServerStatsItem["Data Ping"] end)

        statsConnection = RunService.Heartbeat:Connect(function()
            frameCount = frameCount + 1
            local currentTime = os_clock()
            
            if currentTime - lastTime >= 0.4 then
                currentFps = math_round(frameCount / (currentTime - lastTime))
                frameCount = 0
                lastTime = currentTime
                
                local ping = 0
                if pingObject then
                    pcall(function() ping = math_round(pingObject:GetValue()) end)
                elseif LocalPlayer then
                    pcall(function() ping = math_round(LocalPlayer:GetNetworkPing() * 1000) end)
                end
                
                local memoria = math_round(StatsService:GetTotalMemoryUsageMb())
                
                TextLabel.Text = string_format(
                    "FPS: <font color=\"rgb(160,60,255)\">%d</font>\nPING: <font color=\"rgb(0,255,120)\">%d ms</font>\nRAM: <font color=\"rgb(240,240,240)\">%d MB</font>",
                    currentFps,
                    ping,
                    memoria
                )
            end
        end)
    end
end)

TabExtras:CreateSlider("Extras_StatsOpacity", "BG Opacity (%)", 0, 100, function(valor)
    statsBgTransparency = valor / 100
    if statsFrame then
        statsFrame.BackgroundTransparency = statsBgTransparency
    end
end)

TabExtras:CreateSection("Round Info")

TabExtras:CreateToggle("Extras_ShowRoundTime", "Round Time", function(enabled)
    if enabled then
        local label = CreateTimerUI()
        local zeroTime = nil
        local lastCheck = 0

        RoundTimerConnection = RunService.Heartbeat:Connect(function()
            if os_clock() - lastCheck < 0.25 then return end
            lastCheck = os_clock()

            local timerPart = Workspace:FindFirstChild("RoundTimerPart")
            if timerPart then
                local secondsRemaining = timerPart:GetAttribute("Time")
                if secondsRemaining and tonumber(secondsRemaining) and secondsRemaining > 0 then
                    zeroTime = nil
                    label.Visible = true
                    label.Text = FormatTime(secondsRemaining)
                    label.TextColor3 = Color3.fromRGB(255, 255, 255)
                    return
                end
            end

            if not zeroTime then
                zeroTime = tick()
            end

            if tick() - zeroTime <= 10 then
                label.Visible = true
                label.Text = "00:00"
                label.TextColor3 = Color3.fromRGB(255, 40, 40)
            else
                label.Visible = false
            end
        end)
    else
        if RoundTimerConnection then
            RoundTimerConnection:Disconnect()
            RoundTimerConnection = nil
        end
        RemoveTimerUI()
    end
end)

TabExtras:CreateSection("Visuals")

TabExtras:CreateToggle("Extras_NoLights", "No lights", function(enabled)
    if enabled then
        ApplyNoLightsSettings()
        
        task.spawn(function()
            local descendants = Workspace:GetDescendants()
            for i = 1, #descendants do
                RemoveBrightGlaring(descendants[i])
                if i % 400 == 0 then
                    task.wait()
                end
            end
        end)

        NoLightsConnection = Workspace.DescendantAdded:Connect(function(desc)
            task.spawn(function()
                RemoveBrightGlaring(desc)
            end)
        end)
    else
        if NoLightsConnection then
            NoLightsConnection:Disconnect()
            NoLightsConnection = nil
        end
        RestoreOriginalLights()
    end
end)

TabExtras:CreateToggle("Extras_SeeKnifeESP", "Knife ESP", function(enabled)
    if enabled then
        local lastScan = 0
        KnifeESP_Connection = RunService.Heartbeat:Connect(function()
            if os_clock() - lastScan < 0.2 then return end
            lastScan = os_clock()

            local currentTargets = {}

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if char then
                        local knifeTool = char:FindFirstChild("Knife")
                        if knifeTool then
                            local validPart = ProcessPartOrModel(knifeTool)
                            if validPart then
                                currentTargets[validPart] = true
                            end
                        end
                    end
                end
            end

            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj.Name == "Knife" or obj.Name == "FlyingKnife" or obj:GetAttribute("ThrowSpeed") or obj:FindFirstChild("KnifeClient") then
                    local validPart = ProcessPartOrModel(obj)
                    if validPart then
                        currentTargets[validPart] = true
                    end
                end
            end

            for part, adornment in pairs(ActiveKnifeAdornments) do
                if not currentTargets[part] or not IsPartEquippedOrInWorkspace(part) then
                    adornment:Destroy()
                    ActiveKnifeAdornments[part] = nil
                end
            end

            for part in pairs(currentTargets) do
                if not ActiveKnifeAdornments[part] and IsPartEquippedOrInWorkspace(part) then
                    CreateKnifeBox(part)
                end
            end
        end)

        KnifeWorkspaceConnection = Workspace.ChildAdded:Connect(function(child)
            task.spawn(function()
                if child.Name == "Knife" or child.Name == "FlyingKnife" or child:GetAttribute("ThrowSpeed") or child:FindFirstChild("KnifeClient") then
                    local validPart = ProcessPartOrModel(child)
                    local attempts = 0
                    while not validPart and attempts < 8 do
                        task.wait(0.05)
                        attempts = attempts + 1
                        validPart = ProcessPartOrModel(child)
                    end
                    if validPart and IsPartEquippedOrInWorkspace(validPart) then
                        CreateKnifeBox(validPart)
                    end
                end
            end)
        end)
    else
        if KnifeESP_Connection then
            KnifeESP_Connection:Disconnect()
            KnifeESP_Connection = nil
        end
        if KnifeWorkspaceConnection then
            KnifeWorkspaceConnection:Disconnect()
            KnifeWorkspaceConnection = nil
        end
        ClearKnifeESP()
    end
end)

TabExtras:CreateToggle("Extras_SeeTraps", "Traps ESP", function(enabled)
    if enabled then
        local lastScan = 0
        TrapsESP_Connection = RunService.Heartbeat:Connect(function()
            if os_clock() - lastScan < 0.5 then return end
            lastScan = os_clock()

            local currentTraps = {}
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj.Name == "Trap" and (obj:IsA("Model") or obj:IsA("BasePart")) then
                    local validPart = ProcessPartOrModel(obj)
                    if validPart then
                        currentTraps[validPart] = true
                    end
                end
            end

            for part, adornment in pairs(ActiveTrapAdornments) do
                if not currentTraps[part] or not part.Parent then
                    adornment:Destroy()
                    ActiveTrapAdornments[part] = nil
                end
            end

            for part in pairs(currentTraps) do
                if not ActiveTrapAdornments[part] then
                    CreateTrapBox(part)
                end
            end
        end)

        TrapsWorkspaceConnection = Workspace.ChildAdded:Connect(function(child)
            if child.Name == "Trap" then
                task.spawn(function()
                    local validPart = ProcessPartOrModel(child)
                    local attempts = 0
                    while not validPart and attempts < 8 do
                        task.wait(0.05)
                        attempts = attempts + 1
                        validPart = ProcessPartOrModel(child)
                    end
                    if validPart and validPart:IsDescendantOf(Workspace) then
                        CreateTrapBox(part)
                    end
                end)
            end
        end)
    else
        if TrapsESP_Connection then
            TrapsESP_Connection:Disconnect()
            TrapsESP_Connection = nil
        end
        if TrapsWorkspaceConnection then
            TrapsWorkspaceConnection:Disconnect()
            TrapsWorkspaceConnection = nil
        end
        ClearTrapsESP()
    end
end)

--------------------------------------------------------------------------------
-- AUTOFARM MODULE STATE & LOGIC (ACCURATE PLAYER DATA DETECTION)
--------------------------------------------------------------------------------
local autoFarmEnabled = false
local autoResetEnabled = false
local antiAfkEnabled = false
local farmSpeed = 28.05

local roundInService = false
local resetting = false
local isBagFullState = false
local farmThread = nil
local activeTween = nil

-- ESTADOS EXTRAÍDOS DE PlayerDataChanged
local myRole = nil
local myDeadState = false

local connections = {}
local idledConnection = nil
local noclipConnection = nil

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isPlayerAlive()
    local hum = getHumanoid()
    local hrp = getHRP()
    return hum and hum.Health > 0 and hrp and hrp.Parent ~= nil
end

-- VERIFICACIÓN ESTRICTA DE ROL Y ESTADO MUERTO
local function hasValidActiveRole()
    if myDeadState == true then return false end
    if not myRole or myRole == "" or myRole == "None" or myRole == "Spectator" then
        return false
    end
    -- Roles permitidos en partida
    return myRole == "Innocent" or myRole == "Sheriff" or myRole == "Hero" or myRole == "Murderer"
end

local function getCoinContainer()
    local container = Workspace:FindFirstChild("CoinContainer")
    if container then return container end

    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name == "Coins" or obj:FindFirstChild("CoinContainer") then
            return obj.Name == "CoinContainer" and obj or (obj:FindFirstChild("CoinContainer") or obj)
        end
    end
    return nil
end

local function isPlayerInLobby()
    local hrp = getHRP()
    if not hrp then return true end

    local lobby = Workspace:FindFirstChild("Lobby") or Workspace:FindFirstChild("LobbyMap")
    if lobby then
        local lobbyPart = lobby:FindFirstChildOfClass("BasePart") or lobby.PrimaryPart
        if lobbyPart then
            return (hrp.Position - lobbyPart.Position).Magnitude < 180
        end
    end

    local container = getCoinContainer()
    return container == nil or #container:GetChildren() == 0
end

local function canFarmRightNow()
    return isPlayerAlive() and hasValidActiveRole() and not isPlayerInLobby()
end

local function toggleNoclip(state)
    if state then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                if autoFarmEnabled and canFarmRightNow() and not isBagFullState and not resetting then
                    local char = LocalPlayer.Character
                    if char then
                        for _, part in ipairs(char:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

local function getNearestCoin()
    local hrp = getHRP()
    if not hrp then return nil, math.huge end

    local container = getCoinContainer()
    if not container then return nil, math.huge end

    local closest, minDist = nil, math.huge
    local coins = container:GetChildren()
    for i = 1, #coins do
        local coin = coins[i]
        if coin:IsA("BasePart") and coin.Parent and coin:FindFirstChild("TouchInterest") then
            local dist = (hrp.Position - coin.Position).Magnitude
            if dist < minDist then
                closest = coin
                minDist = dist
            end
        end
    end
    return closest, minDist
end

local function doAutoReset()
    if resetting then return end
    resetting = true
    roundInService = false
    isBagFullState = false
    toggleNoclip(false)
    
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end

    task.wait(0.1)
    local char = LocalPlayer.Character
    if char then
        char:BreakJoints()
    end
    
    task.wait(1.2)
    resetting = false
end

-- ESCUCHA DE EVENTOS REMOTOS Y PlayerDataChanged
pcall(function()
    local gameplayRemotes = ReplicatedStorage:WaitForChild("Remotes", 3):WaitForChild("Gameplay", 3)
    local PlayerDataChanged = gameplayRemotes and gameplayRemotes:FindFirstChild("PlayerDataChanged")
    local RoundStart = gameplayRemotes and gameplayRemotes:FindFirstChild("RoundStart")
    local RoundEnd = gameplayRemotes and (gameplayRemotes:FindFirstChild("RoundEndFade") or gameplayRemotes:FindFirstChild("RoundEnd"))
    local CoinCollected = gameplayRemotes and gameplayRemotes:FindFirstChild("CoinCollected")

    -- ESCUCHA DE ROLES EN PlayerDataChanged
    if PlayerDataChanged then
        table.insert(connections, PlayerDataChanged.OnClientEvent:Connect(function(dataData)
            if typeof(dataData) == "table" and LocalPlayer then
                local myData = dataData[LocalPlayer.Name]
                if myData then
                    if myData["Role"] ~= nil then
                        myRole = myData["Role"]
                    end
                    if myData["Dead"] ~= nil then
                        myDeadState = myData["Dead"]
                    end

                    -- Si acabamos de morir según el servidor, congelar inmediatamente el farm
                    if myDeadState == true then
                        roundInService = false
                        toggleNoclip(false)
                        if activeTween then
                            activeTween:Cancel()
                            activeTween = nil
                        end
                    end
                end
            end
        end))
    end
    
    if RoundStart then
        table.insert(connections, RoundStart.OnClientEvent:Connect(function()
            task.wait(0.5)
            if canFarmRightNow() then
                roundInService = true
                resetting = false
                isBagFullState = false
                if autoFarmEnabled then
                    toggleNoclip(true)
                end
            else
                roundInService = false
            end
        end))
    end

    if RoundEnd then
        table.insert(connections, RoundEnd.OnClientEvent:Connect(function()
            roundInService = false
            isBagFullState = false
            myRole = nil
            myDeadState = true
            toggleNoclip(false)
            if activeTween then activeTween:Cancel() end
        end))
    end

    if CoinCollected then
        table.insert(connections, CoinCollected.OnClientEvent:Connect(function(_, currentCoins, maxCoins)
            if typeof(currentCoins) == "number" and typeof(maxCoins) == "number" then
                if currentCoins >= maxCoins and maxCoins > 0 then
                    isBagFullState = true
                    toggleNoclip(false)
                end
            end
        end))
    end
end)

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 3)
    if hum then
        hum.Died:Connect(function()
            myDeadState = true
            roundInService = false
            isBagFullState = false
            toggleNoclip(false)
            if activeTween then 
                activeTween:Cancel()
                activeTween = nil 
            end
        end)
    end
end

if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
table.insert(connections, LocalPlayer.CharacterAdded:Connect(setupCharacter))

-- LOOP PRINCIPAL DE AUTO FARM (PERFECTAMENTE CONTROLADO POR ROL)
local function startFarmLoop()
    if farmThread then return end
    
    farmThread = task.spawn(function()
        while autoFarmEnabled do
            if not resetting then
                if autoResetEnabled and isBagFullState then
                    doAutoReset()
                elseif canFarmRightNow() and not isBagFullState then
                    roundInService = true
                    toggleNoclip(true)

                    local coin, dist = getNearestCoin()
                    local hrp = getHRP()

                    if coin and canFarmRightNow() and hrp then
                        local timeToReach = math_clamp(dist / math_clamp(farmSpeed, 15, 35), 0.05, 2.5)
                        local tweenInfo = TweenInfo.new(timeToReach, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                        local targetCFrame = coin.CFrame * CFrame.new(0, 1.2, 0)
                        
                        activeTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
                        activeTween:Play()

                        local startTime = os_clock()
                        local coinTimeout = math.min(timeToReach + 0.3, 1.5)

                        repeat
                            local touch = coin:FindFirstChild("TouchInterest")
                            if touch and (hrp.Position - coin.Position).Magnitude < 4.5 then
                                if firetouchinterest then
                                    pcall(function()
                                        firetouchinterest(hrp, coin, 0)
                                        task.wait(0.01)
                                        firetouchinterest(hrp, coin, 1)
                                    end)
                                end
                            end

                            task.wait(0.03)
                        until not coin 
                           or not coin.Parent 
                           or not coin:FindFirstChild("TouchInterest") 
                           or not autoFarmEnabled 
                           or not canFarmRightNow()
                           or resetting 
                           or isBagFullState
                           or (os_clock() - startTime) >= coinTimeout
                        
                        if activeTween then
                            activeTween:Cancel()
                            activeTween = nil
                        end

                        if hrp then
                            hrp.AssemblyLinearVelocity = Vector3_zero
                            hrp.AssemblyAngularVelocity = Vector3_zero
                        end
                    else
                        task.wait(0.2)
                    end
                else
                    roundInService = false
                    toggleNoclip(false)
                    if activeTween then
                        activeTween:Cancel()
                        activeTween = nil
                    end
                end
            else
                if activeTween then
                    activeTween:Cancel()
                    activeTween = nil
                end
            end
            
            task.wait(0.05)
        end
        
        roundInService = false
        toggleNoclip(false)
        if activeTween then activeTween:Cancel() end
        farmThread = nil
    end)
end

--------------------------------------------------------------------------------
-- AUTOFARM CONTROLS
--------------------------------------------------------------------------------
TabAutoFarm:CreateSection("Coin Farming")

TabAutoFarm:CreateToggle("Farm_Coins", "Auto Farm", function(state)
    autoFarmEnabled = state
    if state then
        startFarmLoop()
    else
        roundInService = false
        isBagFullState = false
        toggleNoclip(false)
        if activeTween then 
            activeTween:Cancel()
            activeTween = nil
        end
    end
end)

TabAutoFarm:CreateToggle("Farm_ResetFull", "Auto Reset", function(state)
    autoResetEnabled = state
end)

TabAutoFarm:CreateSlider("Farm_Speed", "Farm Speed", 15, 35, function(value)
    farmSpeed = value
end)

TabAutoFarm:CreateSection("Utilities")

TabAutoFarm:CreateToggle("Farm_AntiAFK", "Anti-AFK", function(state)
    antiAfkEnabled = state
    if state then
        if not idledConnection then
            idledConnection = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    else
        if idledConnection then
            idledConnection:Disconnect()
            idledConnection = nil
        end
    end
end)

--------------------------------------------------------------------------------
-- CLEANUP TASK
--------------------------------------------------------------------------------
KillerHub:AddTask(function()
    CleanUpPerfOverlay()
    if RoundTimerConnection then RoundTimerConnection:Disconnect() RoundTimerConnection = nil end
    if KnifeESP_Connection then KnifeESP_Connection:Disconnect() KnifeESP_Connection = nil end
    if KnifeWorkspaceConnection then KnifeWorkspaceConnection:Disconnect() KnifeWorkspaceConnection = nil end
    if TrapsESP_Connection then TrapsESP_Connection:Disconnect() TrapsESP_Connection = nil end
    if TrapsWorkspaceConnection then TrapsWorkspaceConnection:Disconnect() TrapsWorkspaceConnection = nil end
    if NoLightsConnection then NoLightsConnection:Disconnect() NoLightsConnection = nil end
    RestoreOriginalLights()
    RemoveTimerUI()
    ClearKnifeESP()
    ClearTrapsESP()

    autoFarmEnabled = false
    roundInService = false
    isBagFullState = false
    myRole = nil
    myDeadState = true
    if activeTween then activeTween:Cancel() end
    toggleNoclip(false)
    if idledConnection then
        idledConnection:Disconnect()
        idledConnection = nil
    end
    for _, conn in ipairs(connections) do
        if conn then conn:Disconnect() end
    end
    table.clear(connections)

    getgenv().__KillerHub_Combined_Loaded = nil
end)


--==============================================================================
-- 🔪 MM2 ADVANCED PLAYER UTILITIES — KILLER HUB
--==============================================================================


if not KillerHub then
    warn("[KillerHub Error]: No se pudo obtener la interfaz base.")
    return
end

-- Prevenir doble ejecución
if getgenv().__MM2AdvancedScript_Loaded then
    KillerHub:NotifyWarn("Alerta", "El script ya se está ejecutando.", 3)
    return
end
getgenv().__MM2AdvancedScript_Loaded = true

-- Helper para consultar flags de forma segura
local function GetFlag(name, default)
    local f = KillerHub.Flags and KillerHub.Flags[name]
    if f == nil or f.CurrentValue == nil then return default end
    return f.CurrentValue
end

-- Servicios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Variables de Estado
local NoclipConnection = nil
local InvisConnection = nil
local AntiFlingConnection = nil
local invisParts = {}
local speedGlitchLooping = false

--==============================================================================
-- CORE UTILITY FUNCTIONS
--==============================================================================

-- Speed Glitch Optimizado por Raycast
local function startSpeedGlitchLoop()
    if speedGlitchLooping then return end
    speedGlitchLooping = true
    
    task.spawn(function()
        local wallCheckParams = RaycastParams.new()
        wallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
        wallCheckParams.IgnoreWater = true
        
        while GetFlag("Speed_Glitch", false) do
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            
            if hum and root and hum.Health > 0 then
                local currentHandState = hum:GetState()
                local isClimbing = (currentHandState == Enum.HumanoidStateType.Climbing)
                local isSwimming = (currentHandState == Enum.HumanoidStateType.Swimming)
                
                if hum.FloorMaterial == Enum.Material.Air and root.AssemblyLinearVelocity.Y > 0 and not isClimbing and not isSwimming then
                    local moveDir = hum.MoveDirection
                    if moveDir.Magnitude > 0 then
                        wallCheckParams.FilterDescendantsInstances = {char, workspace.CurrentCamera}
                        local raycastResult = workspace:Raycast(root.Position, moveDir * 2.2, wallCheckParams)
                        
                        if not raycastResult then
                            local power = GetFlag("Speed_Glitch_Intensity", 50)
                            root.AssemblyLinearVelocity = Vector3.new(
                                moveDir.X * power,
                                root.AssemblyLinearVelocity.Y,
                                moveDir.Z * power
                            )
                        end
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
        speedGlitchLooping = false
    end)
end

-- Método FE Invisibility con Transparencia 0.5 y desincronización
local function ToggleInvisibilityFE(state)
    if InvisConnection then
        InvisConnection:Disconnect()
        InvisConnection = nil
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if not state then
        for part, origTrans in pairs(invisParts) do
            if part and part.Parent then
                part.Transparency = origTrans
            end
        end
        table.clear(invisParts)

        if hum then
            hum.CameraOffset = Vector3.zero
        end
        return
    end

    if not char or not hum then return end

    table.clear(invisParts)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
            invisParts[obj] = obj.Transparency
            obj.Transparency = 0.5
        end
    end

    InvisConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and rootPart and humanoid.Health > 0 and GetFlag("Invisible_FE", false) then
            local cf = rootPart.CFrame
            local camOffset = humanoid.CameraOffset
            local hidden = cf * CFrame.new(0, -200000, 0)

            rootPart.CFrame = hidden
            humanoid.CameraOffset = hidden:ToObjectSpace(CFrame.new(cf.Position)).Position

            RunService.RenderStepped:Wait()

            if rootPart and rootPart.Parent then
                rootPart.CFrame = cf
            end
            if humanoid and humanoid.Parent then
                humanoid.CameraOffset = camOffset
            end
        end
    end)
end

-- Módulo Anti Fling
local function ToggleAntiFling(state)
    if AntiFlingConnection then
        AntiFlingConnection:Disconnect()
        AntiFlingConnection = nil
    end

    if not state then return end

    AntiFlingConnection = RunService.Stepped:Connect(function()
        if not GetFlag("Anti_Fling", false) then return end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if part.CanCollide then
                            part.CanCollide = false
                        end
                        if part.AssemblyLinearVelocity.Magnitude > 50 or part.AssemblyAngularVelocity.Magnitude > 50 then
                            part.AssemblyLinearVelocity = Vector3.zero
                            part.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                end
            end
        end

        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Accessory") then
                local handle = obj:FindFirstChildWhichIsA("BasePart")
                if handle then
                    if handle.CanCollide then
                        handle.CanCollide = false
                    end
                    if handle.AssemblyLinearVelocity.Magnitude > 50 then
                        handle.AssemblyLinearVelocity = Vector3.zero
                        handle.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end
    end)
end

--==============================================================================
-- CHARACTER INITIALIZATION & PERSISTENCE
--==============================================================================

local function SetupCharacter(char)
    task.wait(0.3)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    if GetFlag("Invisible_FE", false) then
        ToggleInvisibilityFE(true)
    end

    if GetFlag("Anti_Fling", false) then
        ToggleAntiFling(true)
    end
    
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if GetFlag("WalkSpeed_Toggle", false) then
            local targetSpeed = GetFlag("WalkSpeed_Value", 16)
            if humanoid.WalkSpeed ~= targetSpeed then
                humanoid.WalkSpeed = targetSpeed
            end
        end
    end)
    
    humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if GetFlag("JumpPower_Toggle", false) then
            humanoid.UseJumpPower = true
            local targetJump = GetFlag("JumpPower_Value", 50)
            if humanoid.JumpPower ~= targetJump then
                humanoid.JumpPower = targetJump
            end
        end
    end)
    
    if GetFlag("WalkSpeed_Toggle", false) then humanoid.WalkSpeed = GetFlag("WalkSpeed_Value", 16) end
    if GetFlag("JumpPower_Toggle", false) then 
        humanoid.UseJumpPower = true 
        humanoid.JumpPower = GetFlag("JumpPower_Value", 50) 
    end
end

LocalPlayer.CharacterAdded:Connect(SetupCharacter)
if LocalPlayer.Character then task.spawn(SetupCharacter, LocalPlayer.Character) end

--==============================================================================
-- INTERFACE SETUP (TAB: PLAYER)
--==============================================================================

local TabPlayer = KillerHub:CreateTab("Player", "Movement")

-- Sección 1: Speed Glitch
TabPlayer:CreateSection("Speed Glitch")

TabPlayer:CreateToggle("Speed_Glitch", "Speed Glitch", function(state)
    if state then startSpeedGlitchLoop() end
end)

TabPlayer:CreateSlider("Speed_Glitch_Intensity", "Speed Glitch Intensity", 1, 200, function(value) end)

-- Sección 2: Modificadores de Movimiento
TabPlayer:CreateSection("Movement Modifiers")

TabPlayer:CreateToggleSlider("WalkSpeed_Toggle", "WalkSpeed_Value", "WalkSpeed", 16, 120, 
    function(state)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = state and GetFlag("WalkSpeed_Value", 16) or 16 end
    end,
    function(value)
        if not GetFlag("WalkSpeed_Toggle", false) then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = value end
    end
)

TabPlayer:CreateToggleSlider("JumpPower_Toggle", "JumpPower_Value", "JumpPower", 50, 150, 
    function(state)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then 
            hum.UseJumpPower = true
            hum.JumpPower = state and GetFlag("JumpPower_Value", 50) or 50 
        end
    end,
    function(value)
        if not GetFlag("JumpPower_Toggle", false) then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then 
            hum.UseJumpPower = true
            hum.JumpPower = value 
        end
    end
)

-- Sección 3: Utilidades
TabPlayer:CreateSection("Utilities")

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if GetFlag("Infinite_Jump", false) and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then 
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping) 
        end
    end
end)

TabPlayer:CreateToggle("Infinite_Jump", "Infinite Jump", function(state) end)

-- Noclip Limpio
TabPlayer:CreateToggle("Noclip", "Noclip", function(state)
    if state then
        NoclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char and char:IsDescendantOf(workspace) then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if NoclipConnection then 
            NoclipConnection:Disconnect() 
            NoclipConnection = nil 
        end
    end
end)

-- Invisible FE
TabPlayer:CreateToggle("Invisible_FE", "Invisible FE", function(state)
    ToggleInvisibilityFE(state)
end)

-- Anti Fling
TabPlayer:CreateToggle("Anti_Fling", "Anti Fling", function(state)
    ToggleAntiFling(state)
end)

-- Notificación de Carga
KillerHub:NotifySuccess("KillerHub Script", "Script Loaded successfully.", 4)

-- ============================================================================
-- 🚀 KILLER HUB - PORTABLE TROLL & MODIFY MODULE (MAX OPTIMIZED V3.4)
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- Control Global de Ejecución
getgenv().KH_ScriptActive = true


if not KillerHub and getgenv().KillerHub then
    KillerHub = getgenv().KillerHub
end

if not KillerHub then
    warn("[KillerHub Error]: UI Library failed to load.")
    return
end

-- Global Optimizations & Fallen Height Cache
getgenv().KH_PlayerRoles = getgenv().KH_PlayerRoles or {}
getgenv().KH_PlayerDeadStatus = getgenv().KH_PlayerDeadStatus or {}
getgenv().FPDH = Workspace.FallenPartsDestroyHeight

-- Cached References & Variables
local GunAuraActivo = false
local MostrarBoxVisual = true 
local GunAuraRadio = 15
local GunAuraConnection = nil
local VisualAuraPart = nil
local CachedGunDrop = nil
local LastGunScan = 0

-- Coin Aura & ESP Variables
local CoinAuraActivo = false
local MostrarCoinESPVisual = true
local CoinAuraRadio = 9
local CoinAuraConnection = nil
local CachedCoins = {}
local ActiveCoinAdornments = {}

-- Real-Time VFX Variables
local ModificarDisparosActivo = false
local ArcoirisActivo = false
local ColorDisparoActual = Color3.fromRGB(185, 0, 0)
local GrosorDisparo = 0.8
local OpacidadDisparo = 0.0
local TransparenciaSequence = NumberSequence.new(0)
local TrackedBeams = {}
local BeamAddedConnection = nil

-- Visual Cleaners
local function LimpiarAuraVisual()
    if VisualAuraPart then
        pcall(function() VisualAuraPart:Destroy() end)
        VisualAuraPart = nil
    end
end

local function LimpiarTodosLosAdornments()
    for coin, adorn in pairs(ActiveCoinAdornments) do
        pcall(function() adorn:Destroy() end)
    end
    table.clear(ActiveCoinAdornments)
end

-- Helper: Buscar GunDrop optimizado
local function ObtenerGunDrop()
    local now = tick()
    if now - LastGunScan > 0.15 or not CachedGunDrop or not CachedGunDrop.Parent then
        LastGunScan = now
        CachedGunDrop = Workspace:FindFirstChild("GunDrop", true)
    end
    return CachedGunDrop
end

-- ============================================================================
-- 🛡️ ENVIRONMENT FILTER
-- ============================================================================
local function EsUnDisparoValido(descendant)
    if not descendant:IsA("Beam") then return false end
    
    local current = descendant
    while current and current ~= Workspace do
        local name = current.Name:lower()
        if name:find("map") or name:find("geom") or name:find("lobby") 
           or name:find("building") or name:find("sign") or name:find("neon") or name:find("glass") then
            return false
        end
        current = current.Parent
    end
    
    return (descendant.Name == "Beam" or descendant.Name == "CustomBeam")
end

-- ============================================================================
-- ⚡ HIGH-PERFORMANCE VFX MOTOR
-- ============================================================================
local function InicializarCacheBeams()
    table.clear(TrackedBeams)
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if EsUnDisparoValido(desc) then
            TrackedBeams[desc] = true
        end
    end
end

local function ModificarVigaIndividual(desc)
    if not desc or not desc.Parent then return end
    pcall(function()
        desc.Texture = "" 
        desc.TextureSpeed = 0
        desc.Width0 = GrosorDisparo
        desc.Width1 = GrosorDisparo
        desc.Transparency = TransparenciaSequence
        desc.LightEmission = 0.55
        desc.LightInfluence = 0.0
        
        if not ArcoirisActivo then 
            desc.Color = ColorSequence.new(ColorDisparoActual)
        end
    end)
end

local function ActualizarTodosLosBeams()
    if not ModificarDisparosActivo then return end
    
    for desc in pairs(TrackedBeams) do
        if desc and desc.Parent then
            ModificarVigaIndividual(desc)
        else
            TrackedBeams[desc] = nil
        end
    end
end

BeamAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
    if EsUnDisparoValido(descendant) then
        TrackedBeams[descendant] = true
        if ModificarDisparosActivo then
            ModificarVigaIndividual(descendant) 
        end
    end
end)

InicializarCacheBeams()

-- ============================================================================
-- 📡 NETWORK SYNC
-- ============================================================================
local function parsePlayerData(tabla)
    if type(tabla) == "table" then
        for name, data in pairs(tabla) do
            if type(data) == "table" then
                if data.Role then getgenv().KH_PlayerRoles[name] = data.Role end
                if data.Dead ~= nil then getgenv().KH_PlayerDeadStatus[name] = data.Dead end
            end
        end
    end
end

local PlayerDataChanged = ReplicatedStorage:FindFirstChild("PlayerDataChanged", true)
local RoundStart = ReplicatedStorage:FindFirstChild("RoundStart", true)

if PlayerDataChanged and PlayerDataChanged:IsA("RemoteEvent") then 
    PlayerDataChanged.OnClientEvent:Connect(parsePlayerData) 
end

if RoundStart and RoundStart:IsA("RemoteEvent") then
    RoundStart.OnClientEvent:Connect(function(arg1, arg2)
        table.clear(getgenv().KH_PlayerRoles)
        table.clear(getgenv().KH_PlayerDeadStatus)
        parsePlayerData(arg2)
        parsePlayerData(arg1)
    end)
end

local function EscanearMochilasYEquipamiento()
    local sheriffActual = nil
    for name, role in pairs(getgenv().KH_PlayerRoles) do
        if role == "Sheriff" and not getgenv().KH_PlayerDeadStatus[name] then
            sheriffActual = name
            break
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local character = p.Character
            local backpack = p:FindFirstChild("Backpack")
            local tieneKnife = false
            local tieneGun = false
            
            if backpack then
                if backpack:FindFirstChild("Knife") then tieneKnife = true end
                if backpack:FindFirstChild("Gun") then tieneGun = true end
            end
            
            if character then
                if character:FindFirstChild("Knife") then tieneKnife = true end
                if character:FindFirstChild("Gun") then tieneGun = true end
            end
            
            if tieneKnife then
                getgenv().KH_PlayerRoles[p.Name] = "Murderer"
            elseif tieneGun then
                if sheriffActual and sheriffActual ~= p.Name then
                    getgenv().KH_PlayerRoles[p.Name] = "Hero"
                else
                    getgenv().KH_PlayerRoles[p.Name] = "Sheriff"
                end
            end
        end
    end
end

task.spawn(function()
    while getgenv().KH_ScriptActive and task.wait(0.5) do
        EscanearMochilasYEquipamiento()
        for _, p in ipairs(Players:GetPlayers()) do
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                getgenv().KH_PlayerRoles[p.Name] = nil
                getgenv().KH_PlayerDeadStatus[p.Name] = true
            end
        end
    end
end)

-- ============================================================================
-- 🪙 COIN CACHE & ESP
-- ============================================================================
task.spawn(function()
    while getgenv().KH_ScriptActive do
        if CoinAuraActivo then
            local coinContainer = Workspace:FindFirstChild("CoinContainer", true)
            local tempCoins = {}
            
            if coinContainer then
                for _, coin in ipairs(coinContainer:GetChildren()) do
                    if coin.Name == "Coin_Server" and coin:IsA("BasePart") then
                        table.insert(tempCoins, coin)
                        
                        if MostrarCoinESPVisual then
                            if not ActiveCoinAdornments[coin] or ActiveCoinAdornments[coin].Parent == nil then
                                local adorn = Instance.new("BoxHandleAdornment")
                                adorn.Name = "KH_CoinESP_Box"
                                adorn.Size = Vector3.new(1.6, 1.6, 1.6)
                                adorn.Color3 = Color3.fromRGB(255, 215, 0)
                                adorn.Transparency = 0.45
                                adorn.AlwaysOnTop = true 
                                adorn.ZIndex = 6
                                adorn.Adornee = coin
                                adorn.Parent = coin 
                                ActiveCoinAdornments[coin] = adorn
                            end
                        end
                    end
                end
            end
            
            if not MostrarCoinESPVisual then
                LimpiarTodosLosAdornments()
            else
                for coin, adorn in pairs(ActiveCoinAdornments) do
                    if not coin or not coin.Parent or not table.find(tempCoins, coin) then
                        pcall(function() adorn:Destroy() end)
                        ActiveCoinAdornments[coin] = nil
                    end
                end
            end
            
            CachedCoins = tempCoins
        else
            LimpiarTodosLosAdornments()
            table.clear(CachedCoins)
        end
        task.wait(0.5)
    end
end)

-- ============================================================================
-- 🌀 CHAOTIC MULTI-DIRECTIONAL FLING ENGINE (INSTAKILL 360)
-- ============================================================================
local function ObtenerJugadorPorRol(rolBuscado)
    local espRoles = getgenv().KH_PlayerRoles
    local espDead = getgenv().KH_PlayerDeadStatus
    
    for _, p in ipairs(Players:GetPlayers()) do
        if espRoles[p.Name] == rolBuscado then
            local char = p.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local estaMuerto = espDead[p.Name] == true
                local hum = char:FindFirstChildOfClass("Humanoid")
                local sinVida = hum and hum.Health <= 0
                if not (estaMuerto or sinVida) then 
                    return p 
                end
            end
        end
    end
    return nil
end

local isFlinging = false
local function EjecutarSkidFling(TargetPlayer)
    if not TargetPlayer or TargetPlayer == LocalPlayer or isFlinging then return end
    isFlinging = true
    
    pcall(function()
        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Humanoid and Humanoid.RootPart
        
        local TCharacter = TargetPlayer.Character
        local THumanoid = TCharacter and TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart
        local THead = TCharacter and TCharacter:FindFirstChild("Head")
        local Accessory = TCharacter and TCharacter:FindFirstChildOfClass("Accessory")
        local Handle = Accessory and Accessory:FindFirstChild("Handle")
        
        if Character and Humanoid and RootPart and TCharacter and THumanoid then
            if RootPart.Velocity.Magnitude < 50 then
                getgenv().OldPos = RootPart.CFrame
            end
            
            if THead then 
                Workspace.CurrentCamera.CameraSubject = THead 
            elseif TRootPart then 
                Workspace.CurrentCamera.CameraSubject = TRootPart 
            elseif Handle then
                Workspace.CurrentCamera.CameraSubject = Handle
            end
            
            local FPos = function(BasePart, Pos, Ang)
                if not (RootPart and BasePart and BasePart.Parent) then return end
                local targetCF = CFrame.new(BasePart.Position) * Pos * Ang
                RootPart.CFrame = targetCF
                Character:SetPrimaryPartCFrame(targetCF)
                RootPart.Velocity = Vector3.new(9e7, -9e7 * 10, 9e7) 
                RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
            end
            
            local SFBasePart = function(BasePart)
                local TimeToWait = 2.0
                local Time = tick()
                local Angle = 0
                
                repeat
                    if RootPart and Character and THumanoid and BasePart and BasePart.Parent then
                        Angle = Angle + 120
                        local moveDir = THumanoid.MoveDirection
                        local spd = math.max(THumanoid.WalkSpeed, BasePart.Velocity.Magnitude) / 1.1
                        
                        FPos(BasePart, CFrame.new(0, 1.8, 0) + moveDir * spd, CFrame.Angles(math.rad(Angle), math.rad(Angle), 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.8, 0) - moveDir * spd, CFrame.Angles(math.rad(Angle), 0, math.rad(Angle)))
                        task.wait()
                        FPos(BasePart, CFrame.new(2.5, 1.5, -2.5) + moveDir, CFrame.Angles(0, math.rad(Angle), math.rad(Angle)))
                        task.wait()
                        FPos(BasePart, CFrame.new(-2.5, -1.5, 2.5) - moveDir, CFrame.Angles(math.rad(Angle), math.rad(Angle), math.rad(Angle)))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, 3.2, 0), CFrame.Angles(math.rad(Angle * 2), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -3.2, 0), CFrame.Angles(0, math.rad(Angle * 2), 0))
                        task.wait()
                    else
                        break
                    end
                until BasePart.Velocity.Magnitude > 500 
                   or BasePart.Parent ~= TargetPlayer.Character 
                   or TargetPlayer.Parent ~= Players 
                   or THumanoid.Sit 
                   or Humanoid.Health <= 0 
                   or tick() > Time + TimeToWait
            end
            
            pcall(function() Workspace.FallenPartsDestroyHeight = 0/0 end)
            
            local BV = Instance.new("BodyVelocity")
            BV.Name = "EpixVel"
            BV.Parent = RootPart
            BV.Velocity = Vector3.new(9e8, -9e8 * 10, 9e8) 
            BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)
            
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
            
            if TRootPart and THead then
                if (TRootPart.Position - THead.Position).Magnitude > 5 then 
                    SFBasePart(THead) 
                else 
                    SFBasePart(TRootPart) 
                end
            elseif TRootPart then 
                SFBasePart(TRootPart) 
            elseif THead then 
                SFBasePart(THead) 
            elseif Handle then 
                SFBasePart(Handle) 
            end
            
            BV:Destroy()
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            Workspace.CurrentCamera.CameraSubject = Humanoid
            
            if getgenv().OldPos then
                repeat
                    RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                    Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
                    Humanoid:ChangeState("GettingUp")
                    for _, x in ipairs(Character:GetChildren()) do
                        if x:IsA("BasePart") then 
                            x.Velocity = Vector3.new()
                            x.RotVelocity = Vector3.new() 
                        end
                    end
                    task.wait()
                until (RootPart.Position - getgenv().OldPos.Position).Magnitude < 25
            end
        end
    end)
    
    Workspace.FallenPartsDestroyHeight = getgenv().FPDH
    isFlinging = false
end

-- ============================================================================
-- 🎯 CUSTOM CROSSHAIR ENGINE (CORREGIDO Y PERSISTENTE)
-- ============================================================================
local OriginalCrosshairImage = nil
local OriginalCrosshairSize = nil
local CachedCrosshairGui = nil

local CrosshairSpinActive = false
local CrosshairSpinSpeed = 100
local CrosshairRotation = 0
local SpinConnection = nil

local UltimoCustomID = ""
local OptionCrosshairSeleccionada = "Default"

-- Estado persisente personalizado
local CustomCrosshairSizeX = nil
local CustomCrosshairSizeY = nil
local CurrentCrosshairAsset = nil

local CrosshairOptions = {
    ["Default"] = "DEFAULT_GAME_CROSSHAIR",
    ["Crosshair 1"] = "rbxassetid://5998624778",
    ["Crosshair 2"] = "rbxassetid://4941755392",
    ["Crosshair 3"] = "rbxassetid://11719595104",
    ["Crosshair 4"] = "rbxassetid://119672509101087",
    ["Crosshair 5"] = "rbxassetid://11759192985",
    ["Crosshair 6"] = "rbxassetid://5124214183",
    ["Crosshair 7"] = "rbxassetid://13380318482",
    ["Crosshair 8"] = "rbxassetid://8138092208",
    ["Crosshair 9"] = "rbxassetid://17123709960",
    ["Crosshair 10"] = "rbxassetid://12554863225",
    ["Crosshair 11"] = "rbxassetid://78920076068446",
    ["Crosshair 12"] = "rbxassetid://13070257771",
    ["Crosshair 13"] = "rbxassetid://4618023421",
    ["Crosshair 14"] = "rbxassetid://2149935582",
    ["Crosshair 15"] = "rbxassetid://5456882455",
    ["Crosshair 16"] = "rbxassetid://86534793846898",
    ["Crosshair 17"] = "rbxassetid://71895353135208",
    ["Crosshair 18"] = "rbxassetid://10644137227",
    ["Crosshair 19"] = "rbxassetid://11767037107",
    ["Crosshair 20"] = "rbxassetid://5995357646",
    ["Crosshair 21"] = "rbxassetid://8680062686",
    ["Crosshair 22"] = "rbxassetid://11826465934",
    ["Crosshair 23"] = "rbxassetid://9871562353"
}

local function GuardarEstadoOriginalCrosshair(crossGui)
    if crossGui then
        if not OriginalCrosshairImage then
            OriginalCrosshairImage = crossGui.Image
        end
        if not OriginalCrosshairSize then
            OriginalCrosshairSize = crossGui.Size
        end
    end
end

local function ActualizarCrosshairGui()
    if not CachedCrosshairGui or not CachedCrosshairGui.Parent then return end

    -- Re-aplicar imagen si hay una elegida
    if CurrentCrosshairAsset then
        if CurrentCrosshairAsset == "DEFAULT_GAME_CROSSHAIR" then
            if OriginalCrosshairImage then CachedCrosshairGui.Image = OriginalCrosshairImage end
        else
            CachedCrosshairGui.Image = CurrentCrosshairAsset
        end
    end

    -- Re-aplicar tamaño si hay uno configurado
    if CustomCrosshairSizeX or CustomCrosshairSizeY then
        local currentX = CustomCrosshairSizeX or (OriginalCrosshairSize and OriginalCrosshairSize.X.Offset) or CachedCrosshairGui.Size.X.Offset
        local currentY = CustomCrosshairSizeY or (OriginalCrosshairSize and OriginalCrosshairSize.Y.Offset) or CachedCrosshairGui.Size.Y.Offset
        CachedCrosshairGui.Size = UDim2.new(CachedCrosshairGui.Size.X.Scale, currentX, CachedCrosshairGui.Size.Y.Scale, currentY)
    end
end

local function ObtenerCrosshairGui()
    if CachedCrosshairGui and CachedCrosshairGui.Parent then
        return CachedCrosshairGui
    end
    
    -- Si el GUI fue destruido (respawn), reseteamos los estados originales cacheados
    OriginalCrosshairImage = nil
    OriginalCrosshairSize = nil
    CachedCrosshairGui = nil

    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        local topbar = pGui:FindFirstChild("GameTopbar")
        if topbar then
            local cross = topbar:FindFirstChild("Crosshair")
            if cross and (cross:IsA("ImageLabel") or cross:IsA("ImageButton")) then
                CachedCrosshairGui = cross
                GuardarEstadoOriginalCrosshair(cross)
                -- Re-aplicar personalizaciones en automático al detectar nuevo Gui
                ActualizarCrosshairGui()
                return cross
            end
        end
    end
    return nil
end

local function AplicarCrosshairImage(assetUri)
    CurrentCrosshairAsset = assetUri
    local crossGui = ObtenerCrosshairGui()
    if crossGui then
        ActualizarCrosshairGui()
    else
        KillerHub:NotifyWarn("Crosshair", "Game Crosshair GUI not found.", 3)
    end
end

-- Monitor constante para mantener sincronizado el Crosshair tras reaparecer
RunService.RenderStepped:Connect(function(dt)
    if not getgenv().KH_ScriptActive then return end
    
    local crossGui = ObtenerCrosshairGui()
    if crossGui and CrosshairSpinActive then
        CrosshairRotation = (CrosshairRotation + (CrosshairSpinSpeed * 10 * dt)) % 360
        crossGui.Rotation = CrosshairRotation
    end
end)

-- ============================================================================
-- 🛠️ UI BUILD
-- ============================================================================
local TrollTab = KillerHub:CreateTab("Troll", "rbxassetid://94245473778571")
local ModifyTab = KillerHub:CreateTab("Modify", "rbxassetid://140013014943385")

local SoundConnection, GrabGunConnection, GunAuraConnection, CoinAuraConnection

TrollTab:CreateSection("Combat Attacks")

TrollTab:CreateButton("Fling Murderer", function()
    local target = ObtenerJugadorPorRol("Murderer")
    if target then task.spawn(function() EjecutarSkidFling(target) end)
    else StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[KillerHub]: Murderer not found in cache yet.", Color = Color3.fromRGB(255, 100, 100)}) end
end)

TrollTab:CreateButton("Fling Sheriff / Hero", function()
    local target = ObtenerJugadorPorRol("Sheriff") or ObtenerJugadorPorRol("Hero")
    if target then task.spawn(function() EjecutarSkidFling(target) end)
    else StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[KillerHub]: Sheriff or Hero not found in cache yet.", Color = Color3.fromRGB(255, 100, 100)}) end
end)

TrollTab:CreateSection("Gun Aura")

TrollTab:CreateToggle("GunAuraToggle", "Gun Aura", function(estado)
    GunAuraActivo = estado
    if estado then
        GunAuraConnection = RunService.Heartbeat:Connect(function()
            local myCharacter = LocalPlayer.Character
            local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
            if myRoot and myCharacter:FindFirstChildOfClass("Humanoid") and myCharacter:FindFirstChildOfClass("Humanoid").Health > 0 then
                
                local gunDrop = ObtenerGunDrop()
                
                if gunDrop then
                    local distancia = (myRoot.Position - gunDrop.Position).Magnitude
                    
                    if MostrarBoxVisual then
                        if not VisualAuraPart or VisualAuraPart.Parent == nil then
                            VisualAuraPart = Instance.new("Part")
                            VisualAuraPart.Name = "GunAuraHitbox3D"
                            VisualAuraPart.Shape = Enum.PartType.Block
                            VisualAuraPart.Material = Enum.Material.Neon
                            VisualAuraPart.Color = Color3.fromRGB(0, 255, 100)
                            VisualAuraPart.Transparency = 0.85
                            VisualAuraPart.Anchored = true
                            VisualAuraPart.CanCollide = false
                            VisualAuraPart.CastShadow = false
                            VisualAuraPart.Parent = Workspace
                        end
                        
                        local tamanoCaja = GunAuraRadio * 2
                        VisualAuraPart.Size = Vector3.new(tamanoCaja, tamanoCaja, tamanoCaja)
                        VisualAuraPart.CFrame = CFrame.new(gunDrop.Position)
                    else
                        LimpiarAuraVisual()
                    end
                    
                    if distancia <= GunAuraRadio then
                        pcall(function()
                            firetouchinterest(myRoot, gunDrop, 0)
                            firetouchinterest(myRoot, gunDrop, 1)
                        end)
                    end
                else
                    LimpiarAuraVisual()
                end
            end
        end)
    else
        if GunAuraConnection then GunAuraConnection:Disconnect() GunAuraConnection = nil end
        LimpiarAuraVisual()
    end
end)

TrollTab:CreateToggle("ShowGunBoxToggle", "Show Gun Box", function(estado)
    MostrarBoxVisual = estado
    if not estado then LimpiarAuraVisual() end
end)

TrollTab:CreateSlider("GunAuraRadius", "Gun Aura Radius", 1, 50, function(valor)
    GunAuraRadio = valor
end)

TrollTab:CreateSection("Coin Aura")

TrollTab:CreateToggle("CoinAuraToggle", "Coin Aura", function(estado)
    CoinAuraActivo = estado
    if estado then
        CoinAuraConnection = RunService.Heartbeat:Connect(function()
            local myCharacter = LocalPlayer.Character
            local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
            if myRoot and myCharacter:FindFirstChildOfClass("Humanoid") and myCharacter:FindFirstChildOfClass("Humanoid").Health > 0 then
                
                for _, coin in ipairs(CachedCoins) do
                    if coin and coin.Parent then
                        local dist = (myRoot.Position - coin.Position).Magnitude
                        
                        if dist <= CoinAuraRadio then
                            pcall(function()
                                firetouchinterest(myRoot, coin, 0)
                                firetouchinterest(myRoot, coin, 1)
                            end)
                        end
                    end
                end
            end
        end)
    else
        if CoinAuraConnection then CoinAuraConnection:Disconnect() CoinAuraConnection = nil end
        LimpiarTodosLosAdornments()
    end
end)

TrollTab:CreateToggle("ShowCoinBoxToggle", "See Coins", function(estado)
    MostrarCoinESPVisual = estado
    if not estado then LimpiarTodosLosAdornments() end
end)

TrollTab:CreateSlider("CoinAuraRadius", "Coin Aura Radius", 1, 9, function(valor)
    CoinAuraRadio = valor
end)

TrollTab:CreateSection("Grab Gun")

TrollTab:CreateToggle("AutoGrabGun", "Grab Gun", function(estado)
    if estado then
        GrabGunConnection = RunService.Heartbeat:Connect(function()
            local myCharacter = LocalPlayer.Character
            local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
            if myRoot and myCharacter:FindFirstChildOfClass("Humanoid") and myCharacter:FindFirstChildOfClass("Humanoid").Health > 0 then
                local gunDrop = ObtenerGunDrop()
                if gunDrop then
                    local distancia = (myRoot.Position - gunDrop.Position).Magnitude
                    if distancia < 500 then
                        pcall(function()
                            firetouchinterest(myRoot, gunDrop, 0)
                            firetouchinterest(myRoot, gunDrop, 1)
                        end)
                    end
                end
            end
        end)
    else
        if GrabGunConnection then GrabGunConnection:Disconnect() GrabGunConnection = nil end
    end
end)

-- ============================================================================
-- PESTAÑA MODIFY
-- ============================================================================
ModifyTab:CreateSection("Custom Crosshair")

local DropdownOptionsCrosshair = {
    "Default", "Custom ID", "Crosshair 1", "Crosshair 2", "Crosshair 3", "Crosshair 4", "Crosshair 5",
    "Crosshair 6", "Crosshair 7", "Crosshair 8", "Crosshair 9", "Crosshair 10",
    "Crosshair 11", "Crosshair 12", "Crosshair 13", "Crosshair 14", "Crosshair 15",
    "Crosshair 16", "Crosshair 17", "Crosshair 18", "Crosshair 19", "Crosshair 20",
    "Crosshair 21", "Crosshair 22", "Crosshair 23"
}

ModifyTab:CreateDropdown("SelectCrosshair", "Select Crosshair", DropdownOptionsCrosshair, function(seleccion)
    OptionCrosshairSeleccionada = seleccion
    if seleccion == "Custom ID" then
        if #UltimoCustomID > 0 then
            AplicarCrosshairImage("rbxassetid://" .. UltimoCustomID)
        else
            KillerHub:NotifyWarn("Crosshair", "Ingresa un ID numérico abajo", 3)
        end
    else
        local asset = CrosshairOptions[seleccion]
        if asset then
            AplicarCrosshairImage(asset)
        end
    end
end)

ModifyTab:CreateInput("CustomCrosshairID", "Custom Asset ID", "Enter ID...", function(texto)
    local idLimpia = texto:gsub("%D", "")
    if #idLimpia > 0 then
        UltimoCustomID = idLimpia
        if OptionCrosshairSeleccionada == "Custom ID" then
            AplicarCrosshairImage("rbxassetid://" .. UltimoCustomID)
            KillerHub:NotifySuccess("Crosshair", "Custom Crosshair Applied", 3)
        else
            KillerHub:NotifySuccess("Crosshair", "ID Guardado. Selecciona 'Custom ID' arriba", 3)
        end
    else
        KillerHub:NotifyWarn("Crosshair", "Enter a valid numeric ID", 3)
    end
end)

ModifyTab:CreateSlider("CrosshairSizeX", "Size X", 5, 200, function(val)
    CustomCrosshairSizeX = val
    ActualizarCrosshairGui()
end)

ModifyTab:CreateSlider("CrosshairSizeY", "Size Y", 5, 200, function(val)
    CustomCrosshairSizeY = val
    ActualizarCrosshairGui()
end)

ModifyTab:CreateToggleSlider(
    "SpinCrosshair_Enabled", "SpinCrosshair_Speed", "Spin Crosshair Speed", 10, 250,
    function(estado)
        CrosshairSpinActive = estado
        if not estado then
            local crossGui = ObtenerCrosshairGui()
            if crossGui then crossGui.Rotation = 0 end
        end
    end,
    function(valor)
        CrosshairSpinSpeed = valor
    end
)

ModifyTab:CreateSection("Weapon Sounds")

local GunSounds = {
    ["Default"] = {Disparo = nil, Recarga = nil},
    ["Gingerscope"] = {Disparo = "rbxassetid://98245448501031", Recarga = nil},
    ["Laser"] = {Disparo = "rbxassetid://8561500387", Recarga = "rbxassetid://8561502124"}
}

local KnifeSounds = {
    ["Default"] = nil,
    ["Minecraft"] = "rbxassetid://133823475766637",
    ["Minecraft 2"] = "rbxassetid://133248563542879",
    ["Minecraft 3"] = "rbxassetid://107868586874799",
    ["Minecraft 4"] = "rbxassetid://90520156786055",
    ["Fart"] = "rbxassetid://17043360893"
}

local SonidoPistolaActual = "Default"
local SonidoCuchilloActual = "Default"
local VolumenPistola = 2 
local VolumenCuchillo = 2
local OriginalIds = {}

local function ModificarAudio(descendant)
    if not descendant:IsA("Sound") then return end
    
    if not OriginalIds[descendant] then
        OriginalIds[descendant] = descendant.SoundId
    end

    local name = descendant.Name:lower()
    local esDePistola = descendant:FindFirstAncestor("Gun") or descendant:FindFirstAncestor("Pistola") or name:find("gun") or name:find("shoot") or name:find("reload")
    local esDeCuchillo = descendant:FindFirstAncestor("Knife") or descendant:FindFirstAncestor("Cuchillo") or name:find("slash") or name:find("stab") or name:find("knife")

    local configPistola = GunSounds[SonidoPistolaActual]
    if SonidoPistolaActual ~= "Default" and configPistola and esDePistola and not esDeCuchillo then
        descendant.Volume = VolumenPistola
        if (name:find("shoot") or name:find("shot") or name:find("fire")) and configPistola.Disparo then
            descendant.SoundId = configPistola.Disparo
        elseif name:find("reload") and configPistola.Recarga then
            descendant.SoundId = configPistola.Recarga
        end
    elseif SonidoPistolaActual == "Default" and esDePistola then
        if OriginalIds[descendant] then descendant.SoundId = OriginalIds[descendant] end
    end
    
    local audioCuchillo = KnifeSounds[SonidoCuchilloActual]
    if SonidoCuchilloActual ~= "Default" and audioCuchillo and esDeCuchillo then
        descendant.Volume = VolumenCuchillo
        if (name:find("slash") or name:find("stab") or name:find("kill") or name:find("hit")) then
            descendant.SoundId = audioCuchillo
        end
    elseif SonidoCuchilloActual == "Default" and esDeCuchillo then
        if OriginalIds[descendant] then descendant.SoundId = OriginalIds[descendant] end
    end
end

local function GestionarEscuchadorSonidos()
    if SoundConnection then SoundConnection:Disconnect() SoundConnection = nil end
    
    local contenedores = {Workspace, ReplicatedStorage}
    for _, cont in ipairs(contenedores) do
        for _, descendant in ipairs(cont:GetDescendants()) do
            if descendant:IsA("Sound") then ModificarAudio(descendant) end
        end
    end

    SoundConnection = Workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Sound") then
            ModificarAudio(descendant)
        end
    end)
end

ModifyTab:CreateDropdown("CustomGunSound", "Select Gun Sound", {"Default", "Gingerscope", "Laser"}, function(seleccionado)
    SonidoPistolaActual = seleccionado
    GestionarEscuchadorSonidos()
end)

local actualizandoVolPistola = 0
ModifyTab:CreateSlider("GunVolume", "Gun Volume", 0, 10, function(valor)
    VolumenPistola = valor
    local idActual = tick()
    actualizandoVolPistola = idActual
    task.wait(0.08)
    if actualizandoVolPistola == idActual then
        GestionarEscuchadorSonidos()
    end
end)

ModifyTab:CreateDropdown("CustomKnifeSound", "Select Knife Sound", {"Default", "Minecraft", "Minecraft 2", "Minecraft 3", "Minecraft 4", "Fart"}, function(seleccionado)
    SonidoCuchilloActual = seleccionado
    GestionarEscuchadorSonidos()
end)

local actualizandoVolCuchillo = 0
ModifyTab:CreateSlider("KnifeVolume", "Knife Volume", 0, 10, function(valor)
    VolumenCuchillo = valor
    local idActual = tick()
    actualizandoVolCuchillo = idActual
    task.wait(0.08)
    if actualizandoVolCuchillo == idActual then
        GestionarEscuchadorSonidos()
    end
end)

-- ============================================================================
-- 💎 CUSTOM BEAM VFX
-- ============================================================================
ModifyTab:CreateSection("Gun Shot Effects")

ModifyTab:CreateToggle("ModifyVfxActive", "Modify Gun Shots Trail", function(val) 
    ModificarDisparosActivo = val 
    if val then
        ActualizarTodosLosBeams()
    end
end)

ModifyTab:CreateToggle("RainbowVfxActive", "Rainbow Effect (RGB)", function(val) 
    ArcoirisActivo = val 
    ActualizarTodosLosBeams()
end)

RunService.Heartbeat:Connect(function()
    if not ModificarDisparosActivo or not ArcoirisActivo then return end
    
    local t = tick() * 1.2
    local premiumSequence = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV((t) % 1, 1.0, 0.85)),
        ColorSequenceKeypoint.new(0.25, Color3.fromHSV((t + 0.25) % 1, 1.0, 0.85)),
        ColorSequenceKeypoint.new(0.50, Color3.fromHSV((t + 0.50) % 1, 1.0, 0.85)),
        ColorSequenceKeypoint.new(0.75, Color3.fromHSV((t + 0.75) % 1, 1.0, 0.85)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV((t + 1.00) % 1, 1.0, 0.85))
    })
    
    for b in pairs(TrackedBeams) do 
        if b and b.Parent then 
            b.Color = premiumSequence 
            b.Transparency = TransparenciaSequence
        else 
            TrackedBeams[b] = nil 
        end 
    end
end)

ModifyTab:CreateColorPicker("BeamCustomColor", "Shot Color", Color3.fromRGB(185, 0, 0), function(c) 
    ColorDisparoActual = c 
    ActualizarTodosLosBeams()
end)

ModifyTab:CreateSlider("BeamTransparency", "Shot Trail Opacity", 1, 10, function(v) 
    OpacidadDisparo = (v - 1) / 9
    TransparenciaSequence = NumberSequence.new(OpacidadDisparo)
    ActualizarTodosLosBeams()
end)

ModifyTab:CreateSlider("BeamWidth", "Shot Width", 1, 15, function(v) 
    GrosorDisparo = v / 10
    ActualizarTodosLosBeams()
end)

-- Clean Up cuando el Hub se cierra/descarga
CoreGui.ChildRemoved:Connect(function(child)
    if child.Name == "KillerHub" then 
        getgenv().KH_ScriptActive = false
        
        if SoundConnection then SoundConnection:Disconnect() end
        if GrabGunConnection then GrabGunConnection:Disconnect() end
        if GunAuraConnection then GunAuraConnection:Disconnect() end
        if CoinAuraConnection then CoinAuraConnection:Disconnect() end
        if SpinConnection then SpinConnection:Disconnect() end
        if BeamAddedConnection then BeamAddedConnection:Disconnect() end
        
        local crossGui = ObtenerCrosshairGui()
        if crossGui then
            if OriginalCrosshairImage then crossGui.Image = OriginalCrosshairImage end
            if OriginalCrosshairSize then crossGui.Size = OriginalCrosshairSize end
            crossGui.Rotation = 0
        end

        LimpiarAuraVisual()
        LimpiarTodosLosAdornments()
        table.clear(TrackedBeams)
    end
end)

return KillerHub
