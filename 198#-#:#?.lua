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

-- Notification
KillerHub:NotifySuccess("Killer Hub", "script working correctly", 3)

--==============================================================================
-- 🔪 MM2 ADVANCED UTILITIES & BOMB JUMP — KILLER HUB
--==============================================================================

-- Cargar librería con fallback seguro (Loadstring del archivo Player)


if not KillerHub then
    warn("[KillerHub Error]: No se pudo obtener la interfaz base.")
    return
end

-- Prevenir doble ejecución
if getgenv().__MM2CombinedScript_Loaded then
    KillerHub:NotifyWarn("Alerta", "El script ya se está ejecutando.", 3)
    return
end
getgenv().__MM2CombinedScript_Loaded = true

-- Servicios (Locales para acceso ultrarrápido)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Helper para consultar flags de forma segura
local function GetFlag(name, default)
    local f = KillerHub.Flags and KillerHub.Flags[name]
    if f == nil or f.CurrentValue == nil then return default end
    return f.CurrentValue
end

--==============================================================================
-- 📊 VARIABLES GLOBAL Y CONFIGURACIÓN BOMB JUMP
--==============================================================================
local POTENCIA_SALTO = 58
local UMBRAL_ARRASTRE = 8

-- Normal Bomb
local CooldownNormalTime = 22.0
local CooldownFinNormal = 0
local NormalActivo = false
local AutoEquipNormalActivo = false
local LockNormal = false
local BotonSizeNormalActual = 100
local ARCHIVO_POS_NORMAL = "KillerHub_NormalPosConfig.json"

-- Gold Bomb
local CooldownGoldTime = 3.0
local CooldownFinGold = 0
local GoldActivo = false
local AutoEquipGoldActivo = false
local LockGold = false
local BotonSizeGoldActual = 100
local ARCHIVO_POS_GOLD = "KillerHub_GoldPosConfig.json"

-- Diamond Bomb
local CooldownDiamondTime = 5.5
local CooldownFinDiamond = 0
local DiamondActivo = false
local AutoEquipDiamondActivo = false
local LockDiamond = false
local BotonSizeDiamondActual = 100
local ARCHIVO_POS_DIAMOND = "KillerHub_DiamondPosConfig.json"

-- UI Flotantes y Conexiones
local ScreenGuiNormal, BotonNormal
local ScreenGuiGold, BotonGold
local ScreenGuiDiamond, BotonDiamond
local ID_Generacion_Actual = 0

local DragConnections = { Normal = {}, Gold = {}, Diamond = {} }

-- Variables de Estado Player
local NoclipConnection = nil
local InvisConnection = nil
local AntiFlingConnection = nil
local invisParts = {}
local speedGlitchLooping = false

-- Constante reutilizable para evitar recolección de basura
local VECTOR3_ZERO = Vector3.zero

--==============================================================================
-- 💾 SISTEMA DE CONFIGURACIÓN BOMB JUMP
--==============================================================================
local function guardarPosicionBoton(archivo, xScale, xOffset, yScale, yOffset)
    if not writefile then return end
    pcall(writefile, archivo, HttpService:JSONEncode({
        X_Scale = xScale, X_Offset = xOffset, Y_Scale = yScale, Y_Offset = yOffset
    }))
end

local function cargarPosicionBoton(archivo, defX, defY)
    local pos = {ScaleX = defX, OffsetX = -50, ScaleY = defY, OffsetY = -50}
    if readfile and isfile and isfile(archivo) then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(archivo))
            if decoded then
                pos.ScaleX = decoded.X_Scale or pos.ScaleX
                pos.OffsetX = decoded.X_Offset or pos.OffsetX
                pos.ScaleY = decoded.Y_Scale or pos.ScaleY
                pos.OffsetY = decoded.Y_Offset or pos.OffsetY
            end
        end)
    end
    return pos
end

-- Estilo Liquid Glass
local function AplicarEstiloLiquidGlass(boton, colorBordeText)
    boton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    boton.BackgroundTransparency = 0.35
    boton.Font = Enum.Font.GothamBlack
    boton.TextSize = 12
    boton.TextColor3 = Color3.fromRGB(255, 255, 255)
    boton.TextStrokeTransparency = 1
    boton.BorderSizePixel = 0
    boton.Active = true

    local corner = boton:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = boton

    local stroke = boton:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = colorBordeText
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = boton
end

-- Limpieza estricta de eventos para prevenir memory leaks / lag de FPS
local function LimpiarConexionesDrag(tipo)
    if DragConnections[tipo] then
        for i = 1, #DragConnections[tipo] do
            local conn = DragConnections[tipo][i]
            if conn and conn.Connected then conn:Disconnect() end
        end
        table.clear(DragConnections[tipo])
    end
end

local function ConfigurarArrastreYClick(boton, archivoConfig, getLockState, accionClick, tipoKey)
    LimpiarConexionesDrag(tipoKey)

    local dragging = false
    local wasDragged = false
    local dragInputObject = nil
    local dragStart = VECTOR3_ZERO
    local startPos = UDim2.new()

    local connBegan = boton.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            wasDragged = false
            dragInputObject = input
            dragStart = input.Position
            startPos = boton.Position
        end
    end)

    local connChanged = UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInputObject then
            local delta = input.Position - dragStart
            if delta.Magnitude > UMBRAL_ARRASTRE then
                wasDragged = true
                if not (getLockState and getLockState()) then
                    boton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end
        end
    end)

    local connEnded = UserInputService.InputEnded:Connect(function(input)
        if input == dragInputObject and dragging then
            dragging = false
            dragInputObject = nil

            if wasDragged then
                if not (getLockState and getLockState()) then
                    guardarPosicionBoton(archivoConfig, boton.Position.X.Scale, boton.Position.X.Offset, boton.Position.Y.Scale, boton.Position.Y.Offset)
                end
            else
                if accionClick then accionClick() end
            end
        end
    end)

    table.insert(DragConnections[tipoKey], connBegan)
    table.insert(DragConnections[tipoKey], connChanged)
    table.insert(DragConnections[tipoKey], connEnded)
end

-- Loop de cooldowns
local function IniciarLoopCooldown(boton, tiempoFin, textoBase, colorBase, idGen)
    task.spawn(function()
        while os.clock() < tiempoFin and idGen == ID_Generacion_Actual do
            if boton and boton.Parent then
                local restante = tiempoFin - os.clock()
                boton.Text = string.format("%.1fs", math.max(0, restante))
                boton.TextColor3 = Color3.fromRGB(160, 160, 160)
            else
                break
            end
            task.wait(0.1)
        end
        if boton and boton.Parent and idGen == ID_Generacion_Actual then
            boton.Text = textoBase
            boton.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
end

--==============================================================================
-- 📦 LÓGICA BOMB JUMP (INVENTARIO Y EJECUCIÓN)
--==============================================================================
local function ObtenerOVerificarBombaEnInventario(nombreBomba)
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return nil end

    local bomba = char:FindFirstChild(nombreBomba) or backpack:FindFirstChild(nombreBomba)
    if bomba then return bomba end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local extras = remotes and remotes:FindFirstChild("Extras")
    local remoteToy = extras and extras:FindFirstChild("ReplicateToy")

    if remoteToy then
        pcall(function() remoteToy:InvokeServer(nombreBomba) end)
    end

    return nil
end

-- Bucle pasivo optimizado para AutoEquip
task.spawn(function()
    while true do
        task.wait(0.5)
        if AutoEquipNormalActivo or AutoEquipGoldActivo or AutoEquipDiamondActivo then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if hum and hum.Health > 0 then
                if AutoEquipNormalActivo and NormalActivo then ObtenerOVerificarBombaEnInventario("FakeBomb") end
                if AutoEquipGoldActivo and GoldActivo then ObtenerOVerificarBombaEnInventario("GoldBomb") end
                if AutoEquipDiamondActivo and DiamondActivo then ObtenerOVerificarBombaEnInventario("DiamondBomb") end
            end
        end
    end
end)

local function PrepararBombaParaSalto(nombreBomba, autoEquip)
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return nil end

    local bomba = char:FindFirstChild(nombreBomba)
    if bomba then return bomba end

    bomba = backpack:FindFirstChild(nombreBomba)
    if not bomba and autoEquip then
        bomba = ObtenerOVerificarBombaEnInventario(nombreBomba)
    end

    if bomba and bomba.Parent == backpack then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(bomba) end
    end

    return bomba
end

local function EjecutarBombJumpGenerico(bombaNombre, cooldownTime, refCooldownFin, refActivo, autoEquip, boton, textoBase, colorBase)
    if os.clock() < refCooldownFin or not refActivo then return refCooldownFin end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root and hum.Health > 0) then return refCooldownFin end

    local bomba = PrepararBombaParaSalto(bombaNombre, autoEquip)
    if not bomba then return refCooldownFin end

    local remote = bomba:FindFirstChild("Remote") or bomba:FindFirstChildWhichIsA("RemoteEvent", true)
    if remote then
        local nuevoCooldown = os.clock() + cooldownTime
        IniciarLoopCooldown(boton, nuevoCooldown, textoBase, colorBase, ID_Generacion_Actual)

        task.spawn(function()
            -- 1. PRIMERO: Tirar / Soltar Bomba
            pcall(function()
                if bomba:FindFirstChild("Activate") then bomba:Activate() end
                remote:FireServer(CFrame.new(root.Position - Vector3.new(0, 3, 0)), 50)
            end)
            
            -- 2. MICRO-PAUSA DE SINCRONIZACIÓN (0.09s)
            task.wait(0.09)
            
            -- 3. SEGUNDO: Aplicar Salto
            if char and root and root.Parent and hum.Health > 0 then
                local velActual = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(velActual.X, POTENCIA_SALTO, velActual.Z)
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        return nuevoCooldown
    end
    return refCooldownFin
end

local function EjecutarNormalBombJump()
    CooldownFinNormal = EjecutarBombJumpGenerico("FakeBomb", CooldownNormalTime, CooldownFinNormal, NormalActivo, AutoEquipNormalActivo, BotonNormal, "BOMB JUMP", Color3.fromRGB(255, 255, 255))
end

local function EjecutarGoldBombJump()
    CooldownFinGold = EjecutarBombJumpGenerico("GoldBomb", CooldownGoldTime, CooldownFinGold, GoldActivo, AutoEquipGoldActivo, BotonGold, "GOLD JUMP", Color3.fromRGB(255, 215, 0))
end

local function EjecutarDiamondBombJump()
    CooldownFinDiamond = EjecutarBombJumpGenerico("DiamondBomb", CooldownDiamondTime, CooldownFinDiamond, DiamondActivo, AutoEquipDiamondActivo, BotonDiamond, "DIAMOND JUMP", Color3.fromRGB(0, 191, 255))
end

--==============================================================================
-- 🔳 CREACIÓN DE BOTONES FLOTANTES
--==============================================================================
local function CrearBotonNormal()
    if CoreGui:FindFirstChild("KillerHub_NormalJump") then CoreGui.KillerHub_NormalJump:Destroy() end
    ScreenGuiNormal = Instance.new("ScreenGui", CoreGui)
    ScreenGuiNormal.Name = "KillerHub_NormalJump"
    ScreenGuiNormal.ResetOnSpawn = false
    
    local pos = cargarPosicionBoton(ARCHIVO_POS_NORMAL, 0.6, 0.7)
    BotonNormal = Instance.new("TextButton", ScreenGuiNormal)
    BotonNormal.Name = "NormalJumpButton"
    BotonNormal.Size = UDim2.new(0, BotonSizeNormalActual, 0, BotonSizeNormalActual)
    BotonNormal.Position = UDim2.new(pos.ScaleX, pos.OffsetX, pos.ScaleY, pos.OffsetY)
    
    AplicarEstiloLiquidGlass(BotonNormal, Color3.fromRGB(255, 255, 255))
    
    if os.clock() < CooldownFinNormal then
        IniciarLoopCooldown(BotonNormal, CooldownFinNormal, "BOMB JUMP", Color3.fromRGB(255, 255, 255), ID_Generacion_Actual)
    else
        BotonNormal.Text = "BOMB JUMP"
    end
    
    ConfigurarArrastreYClick(BotonNormal, ARCHIVO_POS_NORMAL, function() return LockNormal end, EjecutarNormalBombJump, "Normal")
end

local function CrearBotonGold()
    if CoreGui:FindFirstChild("KillerHub_GoldJump") then CoreGui.KillerHub_GoldJump:Destroy() end
    ScreenGuiGold = Instance.new("ScreenGui", CoreGui)
    ScreenGuiGold.Name = "KillerHub_GoldJump"
    ScreenGuiGold.ResetOnSpawn = false
    
    local pos = cargarPosicionBoton(ARCHIVO_POS_GOLD, 0.4, 0.7)
    BotonGold = Instance.new("TextButton", ScreenGuiGold)
    BotonGold.Name = "GoldJumpButton"
    BotonGold.Size = UDim2.new(0, BotonSizeGoldActual, 0, BotonSizeGoldActual)
    BotonGold.Position = UDim2.new(pos.ScaleX, pos.OffsetX, pos.ScaleY, pos.OffsetY)
    
    AplicarEstiloLiquidGlass(BotonGold, Color3.fromRGB(255, 215, 0))
    
    if os.clock() < CooldownFinGold then
        IniciarLoopCooldown(BotonGold, CooldownFinGold, "GOLD JUMP", Color3.fromRGB(255, 215, 0), ID_Generacion_Actual)
    else
        BotonGold.Text = "GOLD JUMP"
    end
    
    ConfigurarArrastreYClick(BotonGold, ARCHIVO_POS_GOLD, function() return LockGold end, EjecutarGoldBombJump, "Gold")
end

local function CrearBotonDiamond()
    if CoreGui:FindFirstChild("KillerHub_DiamondJump") then CoreGui.KillerHub_DiamondJump:Destroy() end
    ScreenGuiDiamond = Instance.new("ScreenGui", CoreGui)
    ScreenGuiDiamond.Name = "KillerHub_DiamondJump"
    ScreenGuiDiamond.ResetOnSpawn = false
    
    local pos = cargarPosicionBoton(ARCHIVO_POS_DIAMOND, 0.5, 0.7)
    BotonDiamond = Instance.new("TextButton", ScreenGuiDiamond)
    BotonDiamond.Name = "DiamondJumpButton"
    BotonDiamond.Size = UDim2.new(0, BotonSizeDiamondActual, 0, BotonSizeDiamondActual)
    BotonDiamond.Position = UDim2.new(pos.ScaleX, pos.OffsetX, pos.ScaleY, pos.OffsetY)
    
    AplicarEstiloLiquidGlass(BotonDiamond, Color3.fromRGB(0, 191, 255))
    
    if os.clock() < CooldownFinDiamond then
        IniciarLoopCooldown(BotonDiamond, CooldownFinDiamond, "DIAMOND JUMP", Color3.fromRGB(0, 191, 255), ID_Generacion_Actual)
    else
        BotonDiamond.Text = "DIAMOND JUMP"
    end
    
    ConfigurarArrastreYClick(BotonDiamond, ARCHIVO_POS_DIAMOND, function() return LockDiamond end, EjecutarDiamondBombJump, "Diamond")
end

local function DestruirBotonNormal() 
    LimpiarConexionesDrag("Normal")
    if ScreenGuiNormal then ScreenGuiNormal:Destroy() ScreenGuiNormal = nil BotonNormal = nil end 
end
local function DestruirBotonGold() 
    LimpiarConexionesDrag("Gold")
    if ScreenGuiGold then ScreenGuiGold:Destroy() ScreenGuiGold = nil BotonGold = nil end 
end
local function DestruirBotonDiamond() 
    LimpiarConexionesDrag("Diamond")
    if ScreenGuiDiamond then ScreenGuiDiamond:Destroy() ScreenGuiDiamond = nil BotonDiamond = nil end 
end

--==============================================================================
-- ⚡ CORE UTILITY FUNCTIONS (PLAYER)
--==============================================================================

-- Speed Glitch Optimizado
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

        if hum then hum.CameraOffset = VECTOR3_ZERO end
        return
    end

    if not char or not hum then return end

    table.clear(invisParts)
    local descendants = char:GetDescendants()
    for i = 1, #descendants do
        local obj = descendants[i]
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

            if rootPart and rootPart.Parent then rootPart.CFrame = cf end
            if humanoid and humanoid.Parent then humanoid.CameraOffset = camOffset end
        end
    end)
end

-- Módulo Anti Fling Altamente Optimizado
local function ToggleAntiFling(state)
    if AntiFlingConnection then
        AntiFlingConnection:Disconnect()
        AntiFlingConnection = nil
    end

    if not state then return end

    AntiFlingConnection = RunService.Stepped:Connect(function()
        if not GetFlag("Anti_Fling", false) then return end

        local allPlayers = Players:GetPlayers()
        for i = 1, #allPlayers do
            local player = allPlayers[i]
            if player ~= LocalPlayer and player.Character then
                local parts = player.Character:GetDescendants()
                for j = 1, #parts do
                    local part = parts[j]
                    if part:IsA("BasePart") then
                        if part.CanCollide then part.CanCollide = false end
                        if part.AssemblyLinearVelocity.Magnitude > 50 or part.AssemblyAngularVelocity.Magnitude > 50 then
                            part.AssemblyLinearVelocity = VECTOR3_ZERO
                            part.AssemblyAngularVelocity = VECTOR3_ZERO
                        end
                    end
                end
            end
        end

        local wsObjects = workspace:GetChildren()
        for i = 1, #wsObjects do
            local obj = wsObjects[i]
            if obj:IsA("Accessory") then
                local handle = obj:FindFirstChildWhichIsA("BasePart")
                if handle then
                    if handle.CanCollide then handle.CanCollide = false end
                    if handle.AssemblyLinearVelocity.Magnitude > 50 then
                        handle.AssemblyLinearVelocity = VECTOR3_ZERO
                        handle.AssemblyAngularVelocity = VECTOR3_ZERO
                    end
                end
            end
        end
    end)
end

--==============================================================================
-- 🔄 CHARACTER INITIALIZATION & PERSISTENCE
--==============================================================================
local function SetupCharacter(char)
    task.wait(0.3)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    if GetFlag("Invisible_FE", false) then ToggleInvisibilityFE(true) end
    if GetFlag("Anti_Fling", false) then ToggleAntiFling(true) end
    
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if GetFlag("WalkSpeed_Toggle", false) then
            local targetSpeed = GetFlag("WalkSpeed_Value", 16)
            if humanoid.WalkSpeed ~= targetSpeed then humanoid.WalkSpeed = targetSpeed end
        end
    end)
    
    humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if GetFlag("JumpPower_Toggle", false) then
            humanoid.UseJumpPower = true
            local targetJump = GetFlag("JumpPower_Value", 50)
            if humanoid.JumpPower ~= targetJump then humanoid.JumpPower = targetJump end
        end
    end)
    
    if GetFlag("WalkSpeed_Toggle", false) then humanoid.WalkSpeed = GetFlag("WalkSpeed_Value", 16) end
    if GetFlag("JumpPower_Toggle", false) then 
        humanoid.UseJumpPower = true 
        humanoid.JumpPower = GetFlag("JumpPower_Value", 50) 
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    -- Reset Detector de Bomb Jump
    ID_Generacion_Actual = ID_Generacion_Actual + 1
    CooldownFinNormal = 0
    CooldownFinGold = 0
    CooldownFinDiamond = 0
    
    if BotonNormal and NormalActivo then BotonNormal.Text = "BOMB JUMP" BotonNormal.TextColor3 = Color3.fromRGB(255, 255, 255) end
    if BotonGold and GoldActivo then BotonGold.Text = "GOLD JUMP" BotonGold.TextColor3 = Color3.fromRGB(255, 255, 255) end
    if BotonDiamond and DiamondActivo then BotonDiamond.Text = "DIAMOND JUMP" BotonDiamond.TextColor3 = Color3.fromRGB(255, 255, 255) end

    -- Setup Character de Player
    SetupCharacter(char)
end)

if LocalPlayer.Character then task.spawn(SetupCharacter, LocalPlayer.Character) end

--==============================================================================
-- 📌 1. INTERFACE SETUP (PESTAÑAS DE PLAYER PRIMERO)
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
                local parts = char:GetDescendants()
                for i = 1, #parts do
                    local part = parts[i]
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

--==============================================================================
-- 📌 2. INTERFACE SETUP (PESTAÑA DE BOMB JUMP DESPUÉS)
--==============================================================================

local MMVTab = KillerHub:CreateTab("Bomb Jump", "rbxassetid://14321074389")

-- 1️⃣ NORMAL BOMB JUMP
MMVTab:CreateSection("Bomb Jump")

MMVTab:CreateToggle("NormalBomb_Enable", "Bomb Jump", function(estado)
    NormalActivo = estado
    if estado then CrearBotonNormal() else DestruirBotonNormal() end
end)

MMVTab:CreateSlider("NormalBomb_Size", "Button Size", 60, 200, function(valor)
    BotonSizeNormalActual = math.floor(valor)
    if BotonNormal and NormalActivo then
        BotonNormal.Size = UDim2.new(0, BotonSizeNormalActual, 0, BotonSizeNormalActual)
    end
end)

MMVTab:CreateToggle("NormalBomb_Lock", "Lock Position", function(estado)
    LockNormal = estado
end)

MMVTab:CreateToggle("NormalBomb_AutoEquip", "Auto Equip", function(estado)
    AutoEquipNormalActivo = estado
end)

-- 2️⃣ GOLD BOMB JUMP
MMVTab:CreateSection("Gold Bomb Jump")

MMVTab:CreateToggle("GoldBomb_Enable", "Gold Bomb Jump", function(estado)
    GoldActivo = estado
    if estado then CrearBotonGold() else DestruirBotonGold() end
end)

MMVTab:CreateSlider("GoldBomb_Size", "Button Size", 60, 200, function(valor)
    BotonSizeGoldActual = math.floor(valor)
    if BotonGold and GoldActivo then
        BotonGold.Size = UDim2.new(0, BotonSizeGoldActual, 0, BotonSizeGoldActual)
    end
end)

MMVTab:CreateToggle("GoldBomb_Lock", "Lock Position", function(estado)
    LockGold = estado
end)

MMVTab:CreateToggle("GoldBomb_AutoEquip", "Auto Equip", function(estado)
    AutoEquipGoldActivo = estado
end)

-- 3️⃣ DIAMOND BOMB JUMP
MMVTab:CreateSection("Diamond Bomb Jump")

MMVTab:CreateToggle("DiamondBomb_Enable", "Diamond Bomb Jump", function(estado)
    DiamondActivo = estado
    if estado then CrearBotonDiamond() else DestruirBotonDiamond() end
end)

MMVTab:CreateSlider("DiamondBomb_Size", "Button Size", 60, 200, function(valor)
    BotonSizeDiamondActual = math.floor(valor)
    if BotonDiamond and DiamondActivo then
        BotonDiamond.Size = UDim2.new(0, BotonSizeDiamondActual, 0, BotonSizeDiamondActual)
    end
end)

MMVTab:CreateToggle("DiamondBomb_Lock", "Lock Position", function(estado)
    LockDiamond = estado
end)

MMVTab:CreateToggle("DiamondBomb_AutoEquip", "Auto Equip", function(estado)
    AutoEquipDiamondActivo = estado
end)

-- Notificación Final de Carga Exitosa
KillerHub:NotifySuccess("MM2 Script", "Script unificado y cargado con éxito.", 4)

return KillerHub
