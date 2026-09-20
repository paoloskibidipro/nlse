-- ============================================================================
-- 👻 KILLER HUB | MURDER SUITE V10.0
-- Wall-Aware Prediction • Anti-Jukes • Ballistic Fall • No Sheriff Interference
-- ============================================================================

if getgenv().__KillerHub_MurderSuite_Loaded then
    if getgenv().KillerHub and getgenv().KillerHub.NotifyWarn then
        getgenv().KillerHub:NotifyWarn("Ya cargado", "Murder Suite ya se está ejecutando.", 3)
    end
    return
end
getgenv().__KillerHub_MurderSuite_Loaded = true

local KillerHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/paoloskibidipro/s-eee-ri/refs/heads/main/Slayer.lua"))()

-- Servicios
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local Stats            = game:GetService("Stats")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Camera           = workspace.CurrentCamera

-- Alias locales (más rápido que lookup global cada frame)
local vec3New    = Vector3.new
local vec2New    = Vector2.new
local udim2New   = UDim2.new
local cframeNew  = CFrame.new
local color3RGB  = Color3.fromRGB
local math_clamp = math.clamp
local math_abs   = math.abs
local math_min   = math.min
local math_max   = math.max
local math_sqrt  = math.sqrt
local math_acos  = math.acos
local math_rad   = math.rad
local os_clock   = os.clock
local VECTOR_ZERO= vec3New(0, 0, 0)

-- Archivo de Persistencia de Posición
local POS_FILE = "MurderSuite_ButtonPos.json"

local function saveButtonPosition(pos)
    if writefile then
        pcall(function()
            writefile(POS_FILE, HttpService:JSONEncode({
                XScale = pos.X.Scale, XOffset = pos.X.Offset,
                YScale = pos.Y.Scale, YOffset = pos.Y.Offset
            }))
        end)
    end
end

local function loadButtonPosition()
    if isfile and readfile and isfile(POS_FILE) then
        local ok, result = pcall(function()
            local d = HttpService:JSONDecode(readfile(POS_FILE))
            return udim2New(d.XScale, d.XOffset, d.YScale, d.YOffset)
        end)
        if ok and result then return result end
    end
    return udim2New(0.82, 0, 0.60, 0)
end

-- Constants & Memory Caches
local MAX_DISTANCE_SQ   = 1822500
local GRAVITY           = workspace.Gravity > 0 and workspace.Gravity or 196.2
local wallFilterTable   = {}
local partsToCheck      = {nil, nil}
local playerFysics      = setmetatable({}, { __mode = "k" })  -- weak keys
local originalPartData  = setmetatable({}, { __mode = "k" })  -- weak keys
local lastVisualPosition= VECTOR_ZERO
local lastActualPosition= VECTOR_ZERO
local lastTracerPosition= VECTOR_ZERO
local cachedHasKnife    = false
local lastKnifeCheck    = 0
local cachedTarget      = nil
local wasHitboxActive   = false

-- Lista de partes del cuerpo para el hitbox (SIN HumanoidRootPart)
local HITBOX_PART_NAMES = {
    "Head", "UpperTorso", "LowerTorso", "Torso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Cache de viewport y DPI
local cachedViewportSize  = Camera.ViewportSize
local cachedScreenCenter  = vec2New(cachedViewportSize.X / 2, cachedViewportSize.Y / 2)
local cachedDpiScale      = 1

local function updateViewportCache()
    cachedViewportSize = Camera.ViewportSize
    cachedScreenCenter = vec2New(cachedViewportSize.X / 2, cachedViewportSize.Y / 2)
    local vy = cachedViewportSize.Y
    cachedDpiScale = vy > 0 and math_max(1, 1080 / vy) or 1
end
updateViewportCache()
KillerHub:AddTask(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewportCache))

-- Visual Drawing API
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 0.8; FOVCircle.NumSides = 36; FOVCircle.Filled = false; FOVCircle.Visible = false; FOVCircle.Transparency = 0.8
KillerHub:AddTask(FOVCircle)

local PredRingOuter = Drawing.new("Circle")
PredRingOuter.Radius = 6.0; PredRingOuter.Thickness = 1.2; PredRingOuter.Filled = false
PredRingOuter.Color = color3RGB(255, 35, 35); PredRingOuter.Visible = false
KillerHub:AddTask(PredRingOuter)

local PredDotCenter = Drawing.new("Circle")
PredDotCenter.Radius = 2.5; PredDotCenter.Thickness = 1; PredDotCenter.Filled = true
PredDotCenter.Color = color3RGB(255, 255, 255); PredDotCenter.Visible = false
KillerHub:AddTask(PredDotCenter)

local PredLine = Drawing.new("Line")
PredLine.Thickness = 1.0; PredLine.Color = color3RGB(185, 0, 255); PredLine.Transparency = 0.65; PredLine.Visible = false
KillerHub:AddTask(PredLine)

local TracerLine = Drawing.new("Line")
TracerLine.Thickness = 1.0; TracerLine.Color = color3RGB(140, 0, 255); TracerLine.Transparency = 0.9; TracerLine.Visible = false
KillerHub:AddTask(TracerLine)

-- Helper para leer Flags
local function GetFlag(flagName, default)
    local f = KillerHub.Flags[flagName]
    if f == nil or f.CurrentValue == nil then return default end
    return f.CurrentValue
end

-- Caché de materiales
local materialCache = {}
local function getMaterialEnum(matString)
    if materialCache[matString] then return materialCache[matString] end
    local ok, mat = pcall(function() return Enum.Material[matString] end)
    local result = ok and mat or Enum.Material.Plastic
    materialCache[matString] = result
    return result
end

-- Auxiliares del juego
local function hasKnifeInInventory()
    local now = os_clock()
    if now - lastKnifeCheck > 0.15 then
        lastKnifeCheck = now
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        cachedHasKnife = (char and char:FindFirstChild("Knife")) or (backpack and backpack:FindFirstChild("Knife"))
    end
    return cachedHasKnife
end

local function getKnifeTool()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Knife") then return char.Knife end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack and backpack:FindFirstChild("Knife") then return backpack.Knife end
    return nil
end

local function checkPlayerHasGun(player)
    local char = player.Character
    if char and char:FindFirstChild("Gun") then return true end
    local backpack = player:FindFirstChild("Backpack")
    return backpack and backpack:FindFirstChild("Gun") ~= nil
end

-- Wall Check optimizado (para selección de objetivo)
local function isVisibleThroughWalls(targetChar)
    if not targetChar then return false end
    local localChar = LocalPlayer.Character
    if not localChar then return false end

    local head = targetChar:FindFirstChild("Head")
    local torso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
    if not head and not torso then return false end

    local origin = Camera.CFrame.Position
    partsToCheck[1] = head
    partsToCheck[2] = torso

    for i = 1, 2 do
        local part = partsToCheck[i]
        if part then
            local direction = part.Position - origin
            if direction:Dot(direction) > 0 then
                table.clear(wallFilterTable)
                wallFilterTable[1] = localChar
                wallFilterTable[2] = targetChar
                wallFilterTable[3] = Camera

                local visible = true
                for _ = 1, 3 do
                    raycastParams.FilterDescendantsInstances = wallFilterTable
                    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
                    if not raycastResult then
                        visible = true; break
                    end
                    local hitInst = raycastResult.Instance
                    if hitInst then
                        if not hitInst.CanCollide or hitInst.Transparency >= 0.75 then
                            table.insert(wallFilterTable, hitInst)
                        else
                            visible = false; break
                        end
                    else
                        visible = true; break
                    end
                end
                if visible then return true end
            end
        end
    end
    return false
end

-- Detección de Sheriff
local CurrentSheriff = nil
local lastSheriffScan = 0

local function updateSheriffTarget()
    if CurrentSheriff and CurrentSheriff.Parent == Players then
        local char = CurrentSheriff.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and checkPlayerHasGun(CurrentSheriff) then return end
    end
    local now = os_clock()
    if now - lastSheriffScan > 0.6 then
        lastSheriffScan = now
        CurrentSheriff = nil
        local allPlayers = Players:GetPlayers()
        for i = 1, #allPlayers do
            local player = allPlayers[i]
            if player ~= LocalPlayer and checkPlayerHasGun(player) then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    CurrentSheriff = player
                    break
                end
            end
        end
    end
end

-- Selección de objetivo
local function getClosestTargetToFOV()
    local localChar = LocalPlayer.Character
    local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not localHrp then return nil end

    local aimType           = GetFlag("KnifeAimType", "Target FOV")
    local wallCheck         = GetFlag("KnifeWallCheckActive", false)
    local prioritizeSheriff = GetFlag("PrioritizeSheriffActive", false)
    local fovRadius         = GetFlag("FovRadiusMurder", 150)
    local allPlayers        = Players:GetPlayers()

    if aimType == "Nearest Player" then
        local nearestPlayer, shortestDistSq = nil, MAX_DISTANCE_SQ
        for i = 1, #allPlayers do
            local player = allPlayers[i]
            if player ~= LocalPlayer and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then
                    local diff = hrp.Position - localHrp.Position
                    local distSq = diff:Dot(diff)
                    if distSq <= shortestDistSq then
                        if wallCheck and not isVisibleThroughWalls(player.Character) then continue end
                        shortestDistSq = distSq
                        nearestPlayer = player
                    end
                end
            end
        end
        cachedTarget = nearestPlayer
        return nearestPlayer
    end

    if prioritizeSheriff then updateSheriffTarget() else CurrentSheriff = nil end

    if CurrentSheriff and CurrentSheriff.Character then
        local hrp = CurrentSheriff.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local diff = hrp.Position - localHrp.Position
            if diff:Dot(diff) <= MAX_DISTANCE_SQ then
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local distToCenter = (vec2New(screenPos.X, screenPos.Y) - cachedScreenCenter).Magnitude
                    if distToCenter < fovRadius then
                        if not wallCheck or isVisibleThroughWalls(CurrentSheriff.Character) then
                            cachedTarget = CurrentSheriff
                            return CurrentSheriff
                        end
                    end
                end
            end
        end
    end

    local closestInnocent, shortestDistance = nil, fovRadius
    for i = 1, #allPlayers do
        local player = allPlayers[i]
        if player ~= LocalPlayer and player ~= CurrentSheriff and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                local diff = hrp.Position - localHrp.Position
                if diff:Dot(diff) > MAX_DISTANCE_SQ then continue end
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local distToCenter = (vec2New(screenPos.X, screenPos.Y) - cachedScreenCenter).Magnitude
                    if distToCenter < shortestDistance then
                        if wallCheck and not isVisibleThroughWalls(player.Character) then continue end
                        shortestDistance = distToCenter
                        closestInnocent = player
                    end
                end
            end
        end
    end
    cachedTarget = closestInnocent
    return closestInnocent
end

-- ============================================================================
-- ANTI-JUKES (doble detección: dirección + multi-muestra)
-- ============================================================================
local function computeJukeFactor(physicsData, currentVelocity)
    local factor = 1.0

    -- Método 1: cambio de dirección de velocidad (rápido)
    if physicsData and physicsData.LastVelocity then
        local lastH = vec3New(physicsData.LastVelocity.X, 0, physicsData.LastVelocity.Z)
        local curH  = vec3New(currentVelocity.X, 0, currentVelocity.Z)
        if lastH.Magnitude > 1 and curH.Magnitude > 1 then
            local dot = math_clamp(lastH.Unit:Dot(curH.Unit), -1, 1)
            if dot < 0.94 then
                factor = factor * math_clamp((dot + 1) / 1.94, 0.25, 1.0)
            end
        end
    end

    -- Método 2: análisis multi-muestra (más robusto para jukes reales)
    if physicsData and physicsData.Samples and #physicsData.Samples >= 3 then
        local samples = physicsData.Samples
        local n = #samples
        local s1, s2, s3 = samples[n - 2], samples[n - 1], samples[n]
        local v1 = (s2.pos - s1.pos) / math_max(s2.t - s1.t, 0.01)
        local v2 = (s3.pos - s2.pos) / math_max(s3.t - s2.t, 0.01)
        if v1.Magnitude > 2 and v2.Magnitude > 2 then
            local dot = math_clamp(v1.Unit:Dot(v2.Unit), -1, 1)
            local angle = math_acos(dot)
            if angle > math_rad(30) then
                local turnRatio = math_clamp((angle - math_rad(30)) / math_rad(90), 0, 1)
                factor = factor * (1.0 - turnRatio * 0.60)
            end
        end
    end

    return math_clamp(factor, 0.15, 1.0)
end

-- ============================================================================
-- WALL-AWARE CLAMP (evita que el cuchillo se incruste en paredes al doblar esquinas)
-- ============================================================================
local function getKnifeOriginWorld()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if hand then return hand.Position end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function clampPredictionForWalls(originPos, targetPos, predictedPos, targetChar)
    if not originPos or not targetChar then return predictedPos end

    -- 1) Rayo desde origen hacia la posición predicha
    table.clear(wallFilterTable)
    wallFilterTable[1] = LocalPlayer.Character
    wallFilterTable[2] = targetChar
    wallFilterTable[3] = Camera
    raycastParams.FilterDescendantsInstances = wallFilterTable

    local dirToPred = predictedPos - originPos
    if dirToPred.Magnitude < 0.1 then return predictedPos end

    local rayToPred = workspace:Raycast(originPos, dirToPred, raycastParams)
    if rayToPred and rayToPred.Instance and rayToPred.Instance.CanCollide
       and rayToPred.Instance.Transparency < 0.75 then

        -- Pared bloquea el trayecto hacia el predicho. ¿Podemos llegar al objetivo actual?
        local dirToTarget = targetPos - originPos
        local rayToTarget = workspace:Raycast(originPos, dirToTarget, raycastParams)

        if rayToTarget and rayToTarget.Instance and rayToTarget.Instance.CanCollide
           and rayToTarget.Instance.Transparency < 0.75 then
            -- El objetivo actual TAMBIÉN está bloqueado. Devolvemos la posición actual
            -- (no ganamos nada prediciendo, solo se incrustaría el cuchillo).
            return targetPos
        end

        -- El objetivo actual SÍ se alcanza, pero el predicho no. Recortamos la
        -- predicción al punto seguro justo antes de la pared.
        local hitDist = (rayToPred.Position - originPos).Magnitude
        local safeDist = math_max(0, hitDist - 1.0)
        local distToTarget = dirToTarget.Magnitude

        if safeDist >= distToTarget then
            -- La pared está más allá del objetivo: usamos la posición actual.
            return targetPos
        end

        -- Cortamos la predicción al punto seguro sobre la recta origen→predicho
        return originPos + dirToPred.Unit * safeDist
    end

    -- 2) Chequeo clásico desde el objetivo hacia el predicho (por si hay pared
    --    justo detrás del jugador).
    table.clear(wallFilterTable)
    wallFilterTable[1] = targetChar
    wallFilterTable[2] = LocalPlayer.Character
    wallFilterTable[3] = Camera
    raycastParams.FilterDescendantsInstances = wallFilterTable

    local wallRay = workspace:Raycast(targetPos, predictedPos - targetPos, raycastParams)
    if wallRay and wallRay.Instance and wallRay.Instance.CanCollide then
        local hitDistance = (wallRay.Position - targetPos).Magnitude
        if hitDistance > 0.5 then
            return targetPos + (predictedPos - targetPos).Unit * (hitDistance - 0.4)
        else
            return targetPos
        end
    end

    return predictedPos
end

-- ============================================================================
-- MOTOR DE PREDICCIÓN BALÍSTICA DEL CUCHILLO (V10 - Mejorado)
-- ============================================================================
local function getAdvancedKnifePrediction(targetChar)
    if not targetChar then return nil, nil end
    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
    local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
    local localChar = LocalPlayer.Character
    local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")

    if not hrp or not humanoid or not localHrp then return nil, nil end

    local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
    local targetPosition = hrp.Position
    local distance = (targetPosition - localHrp.Position).Magnitude
    local physicsData = targetPlayer and playerFysics[targetPlayer]

    if physicsData and physicsData.IsLaggingOut then
        return targetPosition, targetPosition
    end

    -- Ajuste para personajes pequeños (bebés)
    local extentsY = targetChar:GetExtentsSize().Y
    local scaleFactor = 1.0
    if humanoid:FindFirstChild("BodyHeightScale") then scaleFactor = humanoid.BodyHeightScale.Value end
    if extentsY < 4.8 or scaleFactor < 0.85 then
        local deficit = math_clamp((5.1 - extentsY) * 0.52, 0.4, 2.3)
        targetPosition = targetPosition - vec3New(0, deficit, 0)
    end

    local smoothVelocity = physicsData and physicsData.SmoothedVelocity or VECTOR_ZERO
    if smoothVelocity:Dot(smoothVelocity) < 0.0225 then
        -- Jugador quieto: devolvemos posición actual (sin predicción)
        return targetPosition, targetPosition
    end

    -- Ping y tiempo de viaje
    local rawPing = 0.06
    if Stats and Stats:FindFirstChild("Network") and Stats.Network:FindFirstChild("ServerToClientPing") then
        rawPing = Stats.Network.ServerToClientPing:GetValue() / 1000
    end
    local ping = math_clamp(rawPing, 0.01, 0.25)
    local travelTime = (distance / 85) + ping

    local horizontalVelocity = vec3New(smoothVelocity.X, 0, smoothVelocity.Z)
    local exactSpeed = horizontalVelocity.Magnitude

    local MAX_WALKSPEED = 16.715
    if exactSpeed > MAX_WALKSPEED then
        horizontalVelocity = horizontalVelocity.Unit * MAX_WALKSPEED
        exactSpeed = MAX_WALKSPEED
    end

    -- ─────── ANTI-JUKES ───────
    local jukeFactor = computeJukeFactor(physicsData, smoothVelocity)

    -- Decaimiento por pérdida de velocidad
    if physicsData and physicsData.LastVelocity then
        local lastSpeed = vec3New(physicsData.LastVelocity.X, 0, physicsData.LastVelocity.Z).Magnitude
        if exactSpeed < lastSpeed * 0.85 and lastSpeed > 1 then
            jukeFactor = jukeFactor * math_clamp(exactSpeed / lastSpeed, 0.25, 1.0)
        end
    end

    local velocityScale = math_clamp(exactSpeed / MAX_WALKSPEED, 0, 1)
    if exactSpeed < 12 then velocityScale = velocityScale ^ 1.4 end

    -- Configs del usuario
    local hPredConfig = GetFlag("KnifeHorizSlider", 145) / 1000
    local vPredConfig = GetFlag("KnifeVertSlider", 40) / 1000

    -- ─────── HORIZONTAL ───────
    local shortRangeBoost = distance < 20 and 1.15 or 1.0
    local dynamicScale = (1.0 + (distance * 0.004)) * shortRangeBoost
    local maxElasticCap = math_clamp(distance * 0.38, 3.5, 13.5)

    local horizontalOffset = horizontalVelocity * (hPredConfig * 6.8) * travelTime
        * dynamicScale * jukeFactor * velocityScale
    if horizontalOffset:Dot(horizontalOffset) > (maxElasticCap * maxElasticCap) then
        horizontalOffset = horizontalOffset.Unit * maxElasticCap
    end

    -- ─────── VERTICAL ───────
    local verticalOffset = VECTOR_ZERO
    local isAir = (humanoid.FloorMaterial == Enum.Material.Air)
    local absYVelocity = math_abs(smoothVelocity.Y)

    if isAir and absYVelocity > 0.5 then
        local verticalVelocity = math_clamp(smoothVelocity.Y, -25, 30)
        local verticalDistanceScale = 1 / (1 + (distance * 0.005))

        if verticalVelocity < -0.5 then
            -- ═══ CAYENDO: balística pura con clamp a tiempo de aterrizaje ═══
            table.clear(wallFilterTable)
            wallFilterTable[1] = targetChar
            wallFilterTable[2] = LocalPlayer.Character
            wallFilterTable[3] = Camera
            raycastParams.FilterDescendantsInstances = wallFilterTable

            local floorRay = workspace:Raycast(targetPosition, vec3New(0, -50, 0), raycastParams)
            local v0 = math_abs(verticalVelocity)

            if floorRay then
                local h = targetPosition.Y - floorRay.Position.Y  -- altura sobre el piso
                if h > 0.1 then
                    -- Tiempo hasta tocar el piso: tFall = (v0 + √(v0² + 2·g·h)) / g
                    local tFall = (v0 + math_sqrt(v0 * v0 + 2 * GRAVITY * h)) / GRAVITY

                    -- Tiempo deseado por el usuario (escalado por el slider vertical)
                    local desiredT = (vPredConfig * 5.8) * travelTime * verticalDistanceScale

                    -- Clamp: nunca predecimos más allá del aterrizaje
                    local t = math_min(desiredT, tFall * 0.92)

                    -- Fórmula balística: y = -v0·t - ½·g·t²
                    local yOffset = -(v0 * t + 0.5 * GRAVITY * t * t)

                    -- Segundo clamp: nunca por debajo del piso (margen 1 stud)
                    local maxDrop = h - 1.0
                    if maxDrop < 0 then maxDrop = 0 end
                    if yOffset < -maxDrop then yOffset = -maxDrop end

                    verticalOffset = vec3New(0, yOffset, 0)
                end
            else
                -- Sin piso detectado: predicción limitada
                local calculatedYOffset = verticalVelocity * 0.32
                    * (vPredConfig * 5.8) * travelTime * verticalDistanceScale
                verticalOffset = vec3New(0, math_max(calculatedYOffset, -20), 0)
            end
        else
            -- ═══ SUBIENDO: mantener comportamiento original ═══
            local calculatedYOffset = verticalVelocity * 0.70
                * (vPredConfig * 5.8) * travelTime * verticalDistanceScale
            verticalOffset = vec3New(0, calculatedYOffset, 0)
        end
    elseif absYVelocity > 0.02 then
        -- Escaleras / rampas
        local rampCompensation = 1.20
        local sliderScale = (vPredConfig / 0.040)
        verticalOffset = vec3New(0, smoothVelocity.Y * travelTime * sliderScale * rampCompensation, 0)
    end

    -- ─────── APLICAR WALL-AWARE CLAMP ───────
    local originPos = getKnifeOriginWorld()
    local rawFinalPred = targetPosition + horizontalOffset + verticalOffset
    local finalPredictedPos = clampPredictionForWalls(originPos, targetPosition, rawFinalPred, targetChar)

    return targetPosition, finalPredictedPos
end

-- ============================================================================
-- LANZAMIENTO INSTANTÁNEO + FAST THROW
-- ============================================================================
local function executeInstantThrow()
    local knife = getKnifeTool()
    if not knife then return end

    local events = knife:FindFirstChild("Events")
    local knifeThrownRemote = events and events:FindFirstChild("KnifeThrown")
    local handle = knife:FindFirstChild("Handle")
        or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("RightHand"))

    if not knifeThrownRemote or not handle then return end

    local originCF = handle.CFrame
    local targetCF = nil
    local targetPlayer = cachedTarget or getClosestTargetToFOV()

    if targetPlayer and targetPlayer.Character then
        local _, predictedPos = getAdvancedKnifePrediction(targetPlayer.Character)
        if predictedPos then targetCF = cframeNew(predictedPos) end
    end

    if not targetCF then
        local mouse = LocalPlayer:GetMouse()
        targetCF = mouse and mouse.Hit or cframeNew(Camera.CFrame.Position + (Camera.CFrame.LookVector * 100))
    end

    -- Modo FAST: avanzar el origen del cuchillo
    local throwType = GetFlag("KnifeThrowType", "Normal")
    local throwDistConfig = GetFlag("KnifeThrowDistance", 14)

    if throwType == "Fast" and throwDistConfig > 0 then
        local direction = targetCF.Position - originCF.Position
        local dist = direction.Magnitude
        if dist > 0 then
            local advanceDistance = math_min(throwDistConfig, dist * 0.75)
            originCF = originCF + (direction.Unit * advanceDistance)
        end
    end

    knifeThrownRemote:FireServer(originCF, targetCF)
end

-- ============================================================================
-- BOTÓN FLOTANTE ESTILO SHERIFF SUITE
-- ============================================================================
local cachedScreenGui, cachedShootButton, checkWeaponVisibility

local function setupThrownButtonGUI()
    local parentGui = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

    local oldGui = parentGui:FindFirstChild("KillerHub_MurderThrownGui")
    if oldGui then oldGui:Destroy() end

    cachedScreenGui = Instance.new("ScreenGui")
    cachedScreenGui.Name = "KillerHub_MurderThrownGui"
    cachedScreenGui.ResetOnSpawn = false
    cachedScreenGui.Enabled = false
    cachedScreenGui.Parent = parentGui

    local buttonSize = GetFlag("Murder_BtnSize", 95)
    local savedPos = loadButtonPosition()

    cachedShootButton = Instance.new("ImageButton")
    cachedShootButton.Name = "ThrownButton"
    cachedShootButton.Size = udim2New(0, buttonSize, 0, buttonSize)
    cachedShootButton.Position = savedPos
    cachedShootButton.BackgroundColor3 = color3RGB(15, 6, 26)
    cachedShootButton.BackgroundTransparency = 0.05
    cachedShootButton.BorderSizePixel = 0
    cachedShootButton.AutoButtonColor = false
    cachedShootButton.ClipsDescendants = true
    cachedShootButton.Parent = cachedScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.28, 0)
    corner.Parent = cachedShootButton

    local glowOverlay = Instance.new("Frame")
    glowOverlay.Size = udim2New(1, 0, 1, 0)
    glowOverlay.BackgroundTransparency = 1
    glowOverlay.ZIndex = cachedShootButton.ZIndex + 1
    glowOverlay.Parent = cachedShootButton

    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0.28, 0)
    glowCorner.Parent = glowOverlay

    local uiGradient = Instance.new("UIGradient")
    uiGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color3RGB(24, 8, 43)),
        ColorSequenceKeypoint.new(0.5, color3RGB(131, 46, 222)),
        ColorSequenceKeypoint.new(1, color3RGB(24, 8, 43))
    })
    uiGradient.Parent = glowOverlay

    local tweenRot = TweenService:Create(uiGradient,
        TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
        {Rotation = 360})
    tweenRot:Play()
    KillerHub:AddTask(tweenRot)

    local decalTexture = Instance.new("ImageLabel")
    decalTexture.Name = "CrosshairDecal"
    decalTexture.Size = udim2New(0.38, 0, 0.38, 0)
    decalTexture.AnchorPoint = vec2New(0.5, 0.5)
    decalTexture.Position = udim2New(0.5, 0, 0.44, 0)
    decalTexture.BackgroundTransparency = 1
    decalTexture.Image = "rbxassetid://125754446555599"
    decalTexture.ZIndex = cachedShootButton.ZIndex + 2
    decalTexture.Parent = cachedShootButton

    local tiLoop = TweenInfo.new(0.80, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local rotAnim = TweenService:Create(decalTexture, tiLoop, {Rotation = 360})
    rotAnim:Play()
    KillerHub:AddTask(rotAnim)

    local label = Instance.new("TextLabel")
    label.Name = "MainLabel"
    label.Size = udim2New(1, 0, 0.2, 0)
    label.Position = udim2New(0, 0, 0.75, 0)
    label.BackgroundTransparency = 1
    label.Text = "THROWN"
    label.TextColor3 = color3RGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.ZIndex = cachedShootButton.ZIndex + 2
    label.Parent = cachedShootButton

    local labelConstraint = Instance.new("UITextSizeConstraint")
    labelConstraint.MaxTextSize = 15
    labelConstraint.MinTextSize = 8
    labelConstraint.Parent = label

    -- Drag + autoguardado
    local dragging = false
    local dragInput, dragStart, startPos

    cachedShootButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(glowOverlay,
                TweenInfo.new(0.01, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundTransparency = 0.02}):Play()
            executeInstantThrow()

            if not GetFlag("Murder_LockBtnPos", false) then
                dragging = true
                dragStart = input.Position
                startPos = cachedShootButton.Position
                local cChanged
                cChanged = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        if cChanged then cChanged:Disconnect() end
                        saveButtonPosition(cachedShootButton.Position)
                    end
                end)
            end
        end
    end)

    cachedShootButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(glowOverlay,
                TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundTransparency = 1}):Play()
            if dragging then
                dragging = false
                saveButtonPosition(cachedShootButton.Position)
            end
        end
    end)

    cachedShootButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and not GetFlag("Murder_LockBtnPos", false) then
            local delta = input.Position - dragStart
            cachedShootButton.Position = udim2New(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

setupThrownButtonGUI()

checkWeaponVisibility = function()
    if not cachedScreenGui then return end
    local showBtn   = GetFlag("Murder_ShowButton", false)
    local smartVis  = GetFlag("SmartHandVisibility", false)
    local hasKnife  = hasKnifeInInventory()

    if not showBtn then cachedScreenGui.Enabled = false; return end
    if smartVis then cachedScreenGui.Enabled = hasKnife else cachedScreenGui.Enabled = true end
end

-- ============================================================================
-- UI SETUP
-- ============================================================================
local MurderTab = KillerHub:CreateTab("Murder", "rbxassetid://104386785713574")

MurderTab:CreateSection("Knife Combats")
MurderTab:CreateToggle("KnifeAimActive", "Knife Thrown aim", function() end)
MurderTab:CreateDropdown("KnifeAimType", "Type of throw aim", {"Target FOV", "Nearest Player"}, function() end)
MurderTab:CreateToggle("PrioritizeSheriffActive", "Prioritize Sheriff", function() end)
MurderTab:CreateToggle("KnifeWallCheckActive", "Wall Check", function() end)

MurderTab:CreateDropdown("KnifeThrowType", "Knife throwing type", {"Normal", "Fast"}, function() end)
MurderTab:CreateSlider("KnifeThrowDistance", "Throw Advance Distance", 0, 100, function() end)

MurderTab:CreateSlider("KnifeHorizSlider", "Horizontal prediction", 0, 300, function() end)
MurderTab:CreateSlider("KnifeVertSlider", "Vertical prediction", 0, 120, function() end)

MurderTab:CreateSection("Interface & Thrown Button")
MurderTab:CreateToggle("Murder_ShowButton", "Show Thrown Button (Blatant)", function() checkWeaponVisibility() end)
MurderTab:CreateToggle("Murder_LockBtnPos", "Lock Button Position", function() end)
MurderTab:CreateSlider("Murder_BtnSize", "Button Size", 50, 200, function(val)
    if cachedShootButton then cachedShootButton.Size = udim2New(0, val, 0, val) end
end, 95)
MurderTab:CreateKeybind("Murder_ThrownKey", "Thrown Keybind (Blatant)", Enum.KeyCode.F, function()
    executeInstantThrow()
end)

MurderTab:CreateSection("Stab Hitbox Modifier")
MurderTab:CreateToggle("StabHitboxMaster", "Stab Hitbox", function() end)
MurderTab:CreateToggle("SeeHitboxActive", "See hitbox", function() end)
MurderTab:CreateSlider("HitboxSizeSlider", "Stab Hitbox Size", 2, 30, function() end)
MurderTab:CreateSlider("HitboxTransparencySlider", "Hitbox transparency", 0, 100, function() end)

MurderTab:CreateDropdown("HitboxMaterialDropdown", "Hitbox Material",
    {"Plastic", "SmoothPlastic", "Metal", "DiamondPlate", "Glass", "Neon", "ForceField", "Wood"},
    function() end)
MurderTab:CreateHint("El hitbox ya NO modifica el HumanoidRootPart para no romper el Sheriff Suite.")

MurderTab:CreateSection("Visuals & Environment")
MurderTab:CreateToggle("ShowKnifePredictionVisual", "See prediction", function() end)
MurderTab:CreateToggle("ShowKnifeTracerVisual", "See prediction tracer", function() end)
MurderTab:CreateToggle("SmartHandVisibility", "Smart Visibility", function() checkWeaponVisibility() end)

MurderTab:CreateSection("Modify FOV")
MurderTab:CreateToggleColorPicker("FovVisibleMurder", "FovColorMurder", "Show FOV Circle",
    color3RGB(0, 255, 185), function() end, function() end)
MurderTab:CreateSlider("FovRadiusMurder", "FOV Radius", 30, 600, function() end)

-- ============================================================================
-- LOOP DE VISIBILIDAD DEL BOTÓN
-- ============================================================================
local visCheckTask = task.spawn(function()
    while task.wait(0.2) do pcall(checkWeaponVisibility) end
end)
KillerHub:AddTask(visCheckTask)

-- ============================================================================
-- HELPERS DE HITBOX (SIN TOCAR HumanoidRootPart)
-- ============================================================================
local function applyHitboxToCharacter(targetChar, targetSize, targetTransparency, matEnum, seeHitbox)
    if not originalPartData[targetChar] then originalPartData[targetChar] = {} end
    local saved = originalPartData[targetChar]

    for i = 1, #HITBOX_PART_NAMES do
        local partName = HITBOX_PART_NAMES[i]
        local part = targetChar:FindFirstChild(partName)
        if part then
            -- Guardamos el tamaño/material original la primera vez
            if not saved[partName] then
                saved[partName] = { size = part.Size, material = part.Material }
            end
            if part.Size ~= targetSize then part.Size = targetSize end
            if part.CanCollide then part.CanCollide = false end

            if seeHitbox then
                if part.Transparency ~= targetTransparency then part.Transparency = targetTransparency end
                if part.Material ~= matEnum then part.Material = matEnum end
            else
                if part.Transparency ~= 1 then part.Transparency = 1 end
            end
        end
    end
end

local function restoreHitboxOnCharacter(targetChar)
    local saved = originalPartData[targetChar]
    if not saved then return end

    for i = 1, #HITBOX_PART_NAMES do
        local partName = HITBOX_PART_NAMES[i]
        local part = targetChar:FindFirstChild(partName)
        local orig = saved[partName]
        if part and orig then
            part.Size = orig.size
            part.Material = orig.material
            part.Transparency = 1
        end
    end
    originalPartData[targetChar] = nil
end

-- ============================================================================
-- HEARTBEAT: física + hitbox + selección de objetivo
-- ============================================================================
local hbConn = RunService.Heartbeat:Connect(function()
    local silentAimActive = GetFlag("KnifeAimActive", false)
    local hitboxActive    = GetFlag("StabHitboxMaster", false)
    local smartVis        = GetFlag("SmartHandVisibility", false)
    local hasKnife        = hasKnifeInInventory()

    local shouldRunAimLogic = silentAimActive and (not smartVis or hasKnife)

    if shouldRunAimLogic then
        getClosestTargetToFOV()
    else
        cachedTarget = nil
    end

    -- Restaurar hitbox si se apagó
    if not hitboxActive and wasHitboxActive then
        wasHitboxActive = false
        local allPlayers = Players:GetPlayers()
        for i = 1, #allPlayers do
            local player = allPlayers[i]
            if player ~= LocalPlayer and player.Character then
                restoreHitboxOnCharacter(player.Character)
            end
        end
    end

    if not shouldRunAimLogic and not hitboxActive then return end
    if hitboxActive then wasHitboxActive = true end

    local currentTime = os_clock()
    local seeHitbox = GetFlag("SeeHitboxActive", false)
    local hitboxSize = GetFlag("HitboxSizeSlider", 2)
    local transSlider = GetFlag("HitboxTransparencySlider", 0)
    local targetTransparency = math_clamp(transSlider, 0, 100) / 100
    local matEnum = getMaterialEnum(GetFlag("HitboxMaterialDropdown", "Plastic"))
    local targetSize = vec3New(hitboxSize, hitboxSize, hitboxSize)
    local allPlayers = Players:GetPlayers()

    for i = 1, #allPlayers do
        local player = allPlayers[i]
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")

            if hrp then
                -- Aplicar hitbox (excluye HRP)
                if hitboxActive then
                    applyHitboxToCharacter(player.Character, targetSize, targetTransparency, matEnum, seeHitbox)
                end

                -- Física para predicción
                if shouldRunAimLogic then
                    local currentPos = hrp.Position
                    local physicsVelocity = hrp.AssemblyLinearVelocity

                    if not playerFysics[player] then
                        playerFysics[player] = {
                            LastPos = currentPos,
                            LastTime = currentTime,
                            SmoothedVelocity = physicsVelocity,
                            LastVelocity = physicsVelocity,
                            LastRawVelocity = physicsVelocity,
                            ConsecutiveSameVelocity = 0,
                            IsLaggingOut = false,
                            Samples = {}
                        }
                    end

                    local data = playerFysics[player]
                    local deltaTime = currentTime - data.LastTime

                    if deltaTime > 0 then
                        local positionalVelocity = (currentPos - data.LastPos) / deltaTime
                        local realVelocity = vec3New(physicsVelocity.X, positionalVelocity.Y, physicsVelocity.Z)

                        -- Detección de lag (velocidad repetida)
                        local diffVel = realVelocity - data.LastRawVelocity
                        if diffVel:Dot(diffVel) < 0.000001 then
                            data.ConsecutiveSameVelocity = data.ConsecutiveSameVelocity + 1
                        else
                            data.ConsecutiveSameVelocity = 0
                        end
                        data.LastRawVelocity = realVelocity

                        if data.ConsecutiveSameVelocity > 20 and realVelocity:Dot(realVelocity) > 1 then
                            data.IsLaggingOut = true
                            realVelocity = VECTOR_ZERO
                        else
                            data.IsLaggingOut = false
                        end

                        -- Teleport detection
                        if positionalVelocity:Dot(positionalVelocity) > 3025 then
                            realVelocity = VECTOR_ZERO
                        end

                        data.LastVelocity = data.SmoothedVelocity
                        data.SmoothedVelocity = data.SmoothedVelocity:Lerp(realVelocity, 0.20)
                    end

                    -- Multi-sample para anti-jukes
                    local samples = data.Samples
                    samples[#samples + 1] = { pos = currentPos, t = currentTime }
                    if #samples > 4 then table.remove(samples, 1) end

                    data.LastPos = currentPos
                    data.LastTime = currentTime
                end
            end
        end
    end
end)
KillerHub:AddTask(hbConn)

-- ============================================================================
-- RENDER STEPPED: visuales
-- ============================================================================
local rsConn = RunService.RenderStepped:Connect(function()
    local silentAimActive = GetFlag("KnifeAimActive", false)

    if not silentAimActive then
        FOVCircle.Visible = false
        PredDotCenter.Visible = false
        PredRingOuter.Visible = false
        PredLine.Visible = false
        TracerLine.Visible = false
        return
    end

    local hasKnife = hasKnifeInInventory()
    local smartVis = GetFlag("SmartHandVisibility", false)

    if smartVis and not hasKnife then
        FOVCircle.Visible = false
        PredDotCenter.Visible = false
        PredRingOuter.Visible = false
        PredLine.Visible = false
        TracerLine.Visible = false
        return
    end

    local showFOV = GetFlag("FovVisibleMurder", false)
    if showFOV then
        FOVCircle.Position = cachedScreenCenter
        FOVCircle.Radius = GetFlag("FovRadiusMurder", 150) * cachedDpiScale
        FOVCircle.Thickness = 0.8 * cachedDpiScale
        FOVCircle.Color = GetFlag("FovColorMurder", color3RGB(0, 255, 185))
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    local activeTarget = cachedTarget

    local showPred = GetFlag("ShowKnifePredictionVisual", false)
    if showPred and activeTarget and activeTarget.Character then
        local basePos, rawPredictedPos = getAdvancedKnifePrediction(activeTarget.Character)
        if basePos and rawPredictedPos then
            lastActualPosition = lastActualPosition:Lerp(basePos, 0.28)
            lastVisualPosition = lastVisualPosition:Lerp(rawPredictedPos, 0.28)

            local screenPosBase, onScreenBase = Camera:WorldToViewportPoint(lastActualPosition)
            local screenPosPred, onScreenPred = Camera:WorldToViewportPoint(lastVisualPosition)

            if onScreenBase and onScreenPred then
                local drawBase = vec2New(screenPosBase.X, screenPosBase.Y)
                local drawPred = vec2New(screenPosPred.X, screenPosPred.Y)

                PredDotCenter.Radius = 2.5 * cachedDpiScale
                PredDotCenter.Thickness = 1 * cachedDpiScale
                PredRingOuter.Radius = 6.0 * cachedDpiScale
                PredRingOuter.Thickness = 1.2 * cachedDpiScale
                PredLine.Thickness = 1.0 * cachedDpiScale

                PredDotCenter.Position = drawBase
                PredRingOuter.Position = drawPred
                PredLine.From = drawBase
                PredLine.To = drawPred

                local lineDiff = drawBase - drawPred
                PredLine.Visible = lineDiff:Dot(lineDiff) >= (2.25 * cachedDpiScale * cachedDpiScale)
                PredDotCenter.Visible = true
                PredRingOuter.Visible = true
            else
                PredDotCenter.Visible = false; PredRingOuter.Visible = false; PredLine.Visible = false
            end
        else
            PredDotCenter.Visible = false; PredRingOuter.Visible = false; PredLine.Visible = false
        end
    else
        PredDotCenter.Visible = false; PredRingOuter.Visible = false; PredLine.Visible = false
        if activeTarget and activeTarget.Character then
            local hrp = activeTarget.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                lastActualPosition = hrp.Position
                lastVisualPosition = hrp.Position
            end
        end
    end

    local showTracer = GetFlag("ShowKnifeTracerVisual", false)
    if showTracer and activeTarget and activeTarget.Character then
        local _, rawPredictedPos = getAdvancedKnifePrediction(activeTarget.Character)
        if rawPredictedPos then
            lastTracerPosition = lastTracerPosition:Lerp(rawPredictedPos, 0.80)

            local char = LocalPlayer.Character
            local rightHand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
            local originWorld = rightHand and rightHand.Position
                or (char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position)

            if originWorld then
                local screenHand, onScreenHand = Camera:WorldToViewportPoint(originWorld)
                local screenPred, onScreenPred = Camera:WorldToViewportPoint(lastTracerPosition)

                if onScreenHand or onScreenPred then
                    TracerLine.From = vec2New(screenHand.X, screenHand.Y)
                    TracerLine.To = vec2New(screenPred.X, screenPred.Y)
                    TracerLine.Thickness = 1.0 * cachedDpiScale
                    TracerLine.Visible = true
                else
                    TracerLine.Visible = false
                end
            else
                TracerLine.Visible = false
            end
        else
            TracerLine.Visible = false
        end
    else
        TracerLine.Visible = false
        if activeTarget and activeTarget.Character then
            local hrp = activeTarget.Character:FindFirstChild("HumanoidRootPart")
            if hrp then lastTracerPosition = hrp.Position end
        end
    end
end)
KillerHub:AddTask(rsConn)

-- ============================================================================
-- HOOKS DE SILENT AIM
-- ============================================================================
local ClientServices = ReplicatedStorage:WaitForChild("ClientServices", 5)
if ClientServices then
    local ok, WeaponService = pcall(function()
        return require(ClientServices:WaitForChild("WeaponService"))
    end)
    if ok and WeaponService then
        local oldGetTargetPosition = WeaponService.GetTargetPosition
        local oldGetMouseTargetCFrame = WeaponService.GetMouseTargetCFrame

        WeaponService.GetTargetPosition = function(self, ...)
            if GetFlag("KnifeAimActive", false) and hasKnifeInInventory() then
                local targetPlayer = cachedTarget or getClosestTargetToFOV()
                if targetPlayer and targetPlayer.Character then
                    local _, predictedPos = getAdvancedKnifePrediction(targetPlayer.Character)
                    if predictedPos then return cframeNew(predictedPos) end
                end
            end
            return oldGetTargetPosition(self, ...)
        end

        WeaponService.GetMouseTargetCFrame = function(self, ...)
            if GetFlag("KnifeAimActive", false) and hasKnifeInInventory() then
                local targetPlayer = cachedTarget or getClosestTargetToFOV()
                if targetPlayer and targetPlayer.Character then
                    local _, predictedPos = getAdvancedKnifePrediction(targetPlayer.Character)
                    if predictedPos then return cframeNew(predictedPos) end
                end
            end
            return oldGetMouseTargetCFrame(self, ...)
        end
    end
end

-- Namecall hook para Fast Throw
local rawNamecall
rawNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not checkcaller() and method == "FireServer" and self.Name == "KnifeThrown" then
        local throwType = GetFlag("KnifeThrowType", "Normal")
        local throwDistConfig = GetFlag("KnifeThrowDistance", 14)

        if throwType == "Fast" and throwDistConfig > 0 and #args >= 2
           and typeof(args[1]) == "CFrame" and typeof(args[2]) == "CFrame" then
            local originCF = args[1]
            local targetCF = args[2]
            local direction = targetCF.Position - originCF.Position
            local dist = direction.Magnitude

            if dist > 0 then
                local advanceDistance = math_min(throwDistConfig, dist * 0.75)
                args[1] = originCF + (direction.Unit * advanceDistance)
            end

            return rawNamecall(self, unpack(args))
        end
    end

    return rawNamecall(self, ...)
end))

--==============================================================================
-- KILLER HUB UI - COMBINED MODULE (FIXED POS PERSISTENCE & OPTIMIZED)
-- Creator: Killer Hub | By Paolo
--==============================================================================


if getgenv().__KillerHub_Combined_Loaded then
    KillerHub:NotifyWarn("Already Loaded", "The script is already running.", 3)
    return
end
getgenv().__KillerHub_Combined_Loaded = true

-- Services Caching
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Fast Localizations
local os_clock = os.clock
local math_round = math.round
local math_clamp = math.clamp
local math_floor = math.floor
local string_format = string.format
local Vector3_zero = Vector3.zero

--------------------------------------------------------------------------------
-- PERSISTENCE FOR POSITIONS (FIXED)
--------------------------------------------------------------------------------
local CONFIG_FILE = "KillerHub_Positions.json"

-- Default positions
local timerPos = UDim2.new(0.5, 0, 0.01, 0)
getgenv().KillerHub_PerfPos = getgenv().KillerHub_PerfPos or UDim2.new(0.85, 0, 0.01, 0)

local function LoadCustomPositions()
    local success, result = pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if success and type(result) == "table" then
        if result.timerPos then
            timerPos = UDim2.new(result.timerPos.XS, result.timerPos.XO, result.timerPos.YS, result.timerPos.YO)
        end
        if result.perfPos then
            getgenv().KillerHub_PerfPos = UDim2.new(result.perfPos.XS, result.perfPos.XO, result.perfPos.YS, result.perfPos.YO)
        end
    end
end

local function SaveCustomPositions()
    pcall(function()
        if writefile then
            local data = {
                timerPos = {XS = timerPos.X.Scale, XO = timerPos.X.Offset, YS = timerPos.Y.Scale, YO = timerPos.Y.Offset},
                perfPos = {XS = getgenv().KillerHub_PerfPos.X.Scale, XO = getgenv().KillerHub_PerfPos.X.Offset, YS = getgenv().KillerHub_PerfPos.Y.Scale, YO = getgenv().KillerHub_PerfPos.Y.Offset}
            }
            writefile(CONFIG_FILE, HttpService:JSONEncode(data))
        end
    end)
end

LoadCustomPositions()

local knifeESPColor = Color3.fromRGB(0, 255, 100)
local timerSize = 38
local timerFontEnum = Enum.Font.SciFi
local timerPreviewActive = false

local perfThemeColor = Color3.fromRGB(160, 60, 255)
local perfStyle = "Horizontal Bar"
local perfScale = 1.0
local perfPreviewActive = false
local statsBgTransparency = 0.25

local FontMap = {
    SciFi = Enum.Font.SciFi,
    GothamBold = Enum.Font.GothamBold,
    Arcade = Enum.Font.Arcade,
    FredokaOne = Enum.Font.FredokaOne,
    SourceSansBold = Enum.Font.SourceSansBold,
    Fantasy = Enum.Font.Fantasy,
    Creepster = Enum.Font.Creepster,
    LuckiestGuy = Enum.Font.LuckiestGuy,
    Bangers = Enum.Font.Bangers,
    PermanentMarker = Enum.Font.PermanentMarker
}

--------------------------------------------------------------------------------
-- DRAG SYSTEM HELPER
--------------------------------------------------------------------------------
local function MakeDraggable(guiObject, getPreviewState, onPosUpdate)
    local dragging = false
    local dragInput, dragStart, startPos

    guiObject.InputBegan:Connect(function(input)
        if not getPreviewState() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position

            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                    SaveCustomPositions() -- Save when dragging ends
                end
            end)
        end
    end)

    guiObject.InputChanged:Connect(function(input)
        if not getPreviewState() then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and getPreviewState() then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            guiObject.Position = newPos
            if onPosUpdate then onPosUpdate(newPos) end
        end
    end)
end

--------------------------------------------------------------------------------
-- TAB & SUB-PAGE CREATION
--------------------------------------------------------------------------------
local TabExtras = KillerHub:CreateTab("Extras", "Code")
local PageExtrasGeneral = TabExtras:CreatePage("General", "Code")
local PageExtrasEdit = TabExtras:CreatePage("Edit", "Gear")

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
local statsStroke = nil
local statsTextLabel = nil

local function SavePerfPosition(pos)
    getgenv().KillerHub_PerfPos = pos
end

local function UpdatePerfStyle()
    if not statsFrame then return end
    
    statsFrame.Position = getgenv().KillerHub_PerfPos
    statsFrame.AnchorPoint = Vector2.new(0.5, 0)
    statsFrame.Active = perfPreviewActive

    local baseW, baseH = 260, 32

    if perfStyle == "Horizontal Bar" then
        baseW, baseH = 260, 32
        statsFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
        statsFrame.BackgroundTransparency = statsBgTransparency
        if statsStroke then
            statsStroke.Enabled = true
            statsStroke.Color = Color3.fromRGB(40, 40, 50)
            statsStroke.Thickness = 1
        end
    elseif perfStyle == "Minimalist" then
        baseW, baseH = 135, 62
        statsFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
        statsFrame.BackgroundTransparency = statsBgTransparency
        if statsStroke then statsStroke.Enabled = false end
    elseif perfStyle == "Glassmorphism" then
        baseW, baseH = 250, 34
        statsFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        statsFrame.BackgroundTransparency = math.min(statsBgTransparency + 0.45, 0.85)
        if statsStroke then
            statsStroke.Enabled = true
            statsStroke.Color = Color3.fromRGB(255, 255, 255)
            statsStroke.Thickness = 1
        end
    elseif perfStyle == "Premium Card" then
        baseW, baseH = 150, 68
        statsFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
        statsFrame.BackgroundTransparency = statsBgTransparency
        if statsStroke then
            statsStroke.Enabled = true
            statsStroke.Color = perfThemeColor
            statsStroke.Thickness = 1
        end
    elseif perfStyle == "Line OLED" then
        baseW, baseH = 240, 28
        statsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        statsFrame.BackgroundTransparency = 0.4
        if statsStroke then statsStroke.Enabled = false end
    end

    statsFrame.Size = UDim2.new(0, math_floor(baseW * perfScale), 0, math_floor(baseH * perfScale))
    if statsTextLabel then
        statsTextLabel.TextSize = math_floor(12 * perfScale)
    end
end

local function CleanUpPerfOverlay()
    if statsConnection then
        statsConnection:Disconnect()
        statsConnection = nil
    end
    if statsGui then
        statsGui:Destroy()
        statsGui = nil
        statsFrame = nil
        statsStroke = nil
        statsTextLabel = nil
    end
end

local function CreatePerfOverlay()
    CleanUpPerfOverlay()
    
    statsGui = Instance.new("ScreenGui")
    statsGui.Name = "KillerHub_PerformanceOverlay"
    statsGui.ResetOnSpawn = false

    statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(0, 260, 0, 32)
    statsFrame.Position = getgenv().KillerHub_PerfPos
    statsFrame.AnchorPoint = Vector2.new(0.5, 0)
    statsFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    statsFrame.BackgroundTransparency = statsBgTransparency
    statsFrame.BorderSizePixel = 0
    statsFrame.Active = perfPreviewActive

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 16)
    Corner.Parent = statsFrame

    statsStroke = Instance.new("UIStroke")
    statsStroke.Thickness = 1
    statsStroke.Color = Color3.fromRGB(40, 40, 50)
    statsStroke.Parent = statsFrame

    statsTextLabel = Instance.new("TextLabel")
    statsTextLabel.Size = UDim2.new(1, -12, 1, 0)
    statsTextLabel.Position = UDim2.new(0, 6, 0, 0)
    statsTextLabel.BackgroundTransparency = 1
    statsTextLabel.TextXAlignment = Enum.TextXAlignment.Center
    statsTextLabel.TextYAlignment = Enum.TextYAlignment.Center
    statsTextLabel.Font = Enum.Font.GothamBold
    statsTextLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    statsTextLabel.TextSize = math_floor(12 * perfScale)
    statsTextLabel.RichText = true
    statsTextLabel.Text = "Cargando..."
    statsTextLabel.Active = false
    statsTextLabel.Parent = statsFrame

    MakeDraggable(statsFrame, function() return perfPreviewActive end, function(newPos)
        SavePerfPosition(newPos)
    end)

    statsFrame.Parent = statsGui
    UpdatePerfStyle()

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

    -- OPTIMIZED: Increased update interval from 0.5s to 1.0s to reduce RAM/CPU polling overhead
    statsConnection = RunService.Heartbeat:Connect(function()
        frameCount = frameCount + 1
        local currentTime = os_clock()
        
        if currentTime - lastTime >= 1.0 then
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
            local colorHex = string_format("%d,%d,%d", math_floor(perfThemeColor.R*255), math_floor(perfThemeColor.G*255), math_floor(perfThemeColor.B*255))

            if perfStyle == "Horizontal Bar" or perfStyle == "Glassmorphism" or perfStyle == "Line OLED" then
                statsTextLabel.TextXAlignment = Enum.TextXAlignment.Center
                statsTextLabel.Text = string_format(
                    "FPS: <font color=\"rgb(%s)\">%d</font>    |    PING: <font color=\"rgb(0,230,140)\">%d ms</font>    |    RAM: <font color=\"rgb(220,220,220)\">%d MB</font>",
                    colorHex, currentFps, ping, memoria
                )
            else
                statsTextLabel.TextXAlignment = Enum.TextXAlignment.Left
                statsTextLabel.Text = string_format(
                    "FPS: <font color=\"rgb(%s)\">%d</font>\nPING: <font color=\"rgb(0,230,140)\">%d ms</font>\nRAM: <font color=\"rgb(220,220,220)\">%d MB</font>",
                    colorHex, currentFps, ping, memoria
                )
            end
        end
    end)
end

-- Round Time UI
local RoundTimerGui = nil
local RoundTimerConnection = nil
local TimeLabelRef = nil

local function UpdateTimerStyle()
    if TimeLabelRef then
        TimeLabelRef.Position = timerPos
        TimeLabelRef.AnchorPoint = Vector2.new(0.5, 0)
        TimeLabelRef.TextSize = timerSize
        TimeLabelRef.Font = timerFontEnum
        TimeLabelRef.Active = timerPreviewActive
    end
end

local function CreateTimerUI()
    if RoundTimerGui then RoundTimerGui:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KillerHub_RoundTimer"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local TimeLabel = Instance.new("TextLabel")
    TimeLabel.Name = "TimeText"
    TimeLabel.Size = UDim2.new(0, 300, 0, 50)
    TimeLabel.Position = timerPos
    TimeLabel.AnchorPoint = Vector2.new(0.5, 0)
    TimeLabel.BackgroundTransparency = 1
    TimeLabel.Font = timerFontEnum
    TimeLabel.TextSize = timerSize
    TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TimeLabel.TextStrokeTransparency = 0.3
    TimeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TimeLabel.Text = ""
    TimeLabel.Visible = false
    TimeLabel.Active = timerPreviewActive
    TimeLabel.Parent = ScreenGui

    MakeDraggable(TimeLabel, function() return timerPreviewActive end, function(newPos)
        timerPos = newPos
    end)

    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end

    RoundTimerGui = ScreenGui
    TimeLabelRef = TimeLabel
    return TimeLabel
end

local function RemoveTimerUI()
    if RoundTimerGui then
        RoundTimerGui:Destroy()
        RoundTimerGui = nil
        TimeLabelRef = nil
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
    box.Color3 = knifeESPColor
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

-- No Lights Logic (OPTIMIZED TO PREVENT FREEZES)
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
-- PAGE GENERAL (EXTRAS)
--------------------------------------------------------------------------------
PageExtrasGeneral:CreateSection("Performance")

PageExtrasGeneral:CreateToggle("Extras_PerformanceStats", "Show Stats", function(estado)
    if estado then
        CreatePerfOverlay()
    else
        if not perfPreviewActive then
            CleanUpPerfOverlay()
        end
    end
end)

PageExtrasGeneral:CreateSlider("Extras_StatsOpacity", "BG Opacity (%)", 0, 100, function(valor)
    statsBgTransparency = valor / 100
    UpdatePerfStyle()
end)

PageExtrasGeneral:CreateSection("Round Info")

PageExtrasGeneral:CreateToggle("Extras_ShowRoundTime", "Round Time", function(enabled)
    if enabled or timerPreviewActive then
        local label = TimeLabelRef or CreateTimerUI()
        local zeroTime = nil
        local lastCheck = 0

        if RoundTimerConnection then RoundTimerConnection:Disconnect() end

        RoundTimerConnection = RunService.Heartbeat:Connect(function()
            if os_clock() - lastCheck < 0.25 then return end
            lastCheck = os_clock()

            if timerPreviewActive then
                label.Visible = true
                label.Text = "06:67"
                label.TextColor3 = Color3.fromRGB(0, 255, 150)
                return
            end

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

PageExtrasGeneral:CreateSection("Visuals")

PageExtrasGeneral:CreateToggle("Extras_NoLights", "No lights", function(enabled)
    if enabled then
        ApplyNoLightsSettings()
        
        -- OPTIMIZED: Asynchronous batched iteration to prevent lag spikes on mobile
        task.spawn(function()
            local descendants = Workspace:GetDescendants()
            for i = 1, #descendants do
                RemoveBrightGlaring(descendants[i])
                if i % 200 == 0 then
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

PageExtrasGeneral:CreateToggle("Extras_SeeKnifeESP", "Knife ESP", function(enabled)
    if enabled then
        local lastScan = 0
        KnifeESP_Connection = RunService.Heartbeat:Connect(function()
            if os_clock() - lastScan < 0.3 then return end -- Slightly increased interval for better performance
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

PageExtrasGeneral:CreateToggle("Extras_SeeTraps", "Traps ESP", function(enabled)
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
                        CreateTrapBox(validPart)
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
-- PAGE EDIT (CUSTOMIZATIONS)
--------------------------------------------------------------------------------
PageExtrasEdit:CreateSection("Round Time Customization")

PageExtrasEdit:CreateToggle("Edit_Timer_Preview", "Preview & Drag Mode", function(enabled)
    timerPreviewActive = enabled
    if TimeLabelRef then
        TimeLabelRef.Active = enabled
    end
    if enabled then
        if not TimeLabelRef then
            CreateTimerUI()
        end
        TimeLabelRef.Visible = true
        TimeLabelRef.Active = true
        TimeLabelRef.Text = "06:67"
        TimeLabelRef.TextColor3 = Color3.fromRGB(0, 255, 150)
    else
        if not KillerHub.Flags["Extras_ShowRoundTime"] or not KillerHub.Flags["Extras_ShowRoundTime"].CurrentValue then
            RemoveTimerUI()
        end
    end
end)

PageExtrasEdit:CreateSlider("Edit_Timer_Size", "Text Size", 16, 72, function(val)
    timerSize = val
    UpdateTimerStyle()
end, 38)

PageExtrasEdit:CreateDropdown("Edit_Timer_Font", "Font Style", {
    "SciFi", "GothamBold", "Arcade", "FredokaOne", "SourceSansBold", "Fantasy",
    "Creepster", "LuckiestGuy", "Bangers", "PermanentMarker"
}, function(sel)
    if FontMap[sel] then
        timerFontEnum = FontMap[sel]
        UpdateTimerStyle()
    end
end, "SciFi")

PageExtrasEdit:CreateSection("Knife ESP Customization")

PageExtrasEdit:CreateColorPicker("Edit_KnifeESP_Color", "Knife Box Color", Color3.fromRGB(0, 255, 100), function(color)
    knifeESPColor = color
    for _, adornment in pairs(ActiveKnifeAdornments) do
        if adornment then
            adornment.Color3 = knifeESPColor
        end
    end
end)

PageExtrasEdit:CreateSection("Performance Statistics Customization")

PageExtrasEdit:CreateToggle("Edit_Perf_Preview", "Preview Overlay & Drag", function(enabled)
    perfPreviewActive = enabled
    if statsFrame then
        statsFrame.Active = enabled
    end
    if enabled then
        if not statsGui then
            CreatePerfOverlay()
        end
        if statsFrame then
            statsFrame.Active = true
        end
    else
        if not KillerHub.Flags["Extras_PerformanceStats"] or not KillerHub.Flags["Extras_PerformanceStats"].CurrentValue then
            CleanUpPerfOverlay()
        end
    end
end)

PageExtrasEdit:CreateSlider("Edit_Perf_Scale", "Card Scale (%)", 70, 160, function(val)
    perfScale = val / 100
    UpdatePerfStyle()
end, 100)

PageExtrasEdit:CreateDropdown("Edit_Perf_Style", "Card Design", {
    "Horizontal Bar", "Minimalist", "Glassmorphism", "Premium Card", "Line OLED"
}, function(sel)
    perfStyle = sel
    UpdatePerfStyle()
end, "Horizontal Bar")

PageExtrasEdit:CreateColorPicker("Edit_Perf_Color", "Accent Color", Color3.fromRGB(160, 60, 255), function(color)
    perfThemeColor = color
    UpdatePerfStyle()
end)

--------------------------------------------------------------------------------
-- AUTOFARM MODULE STATE & LOGIC
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

local function hasValidActiveRole()
    if myDeadState == true then return false end
    if not myRole or myRole == "" or myRole == "None" or myRole == "Spectator" then
        return false
    end
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

-- REMOTE EVENT LISTENING
pcall(function()
    local gameplayRemotes = ReplicatedStorage:WaitForChild("Remotes", 3):WaitForChild("Gameplay", 3)
    local PlayerDataChanged = gameplayRemotes and gameplayRemotes:FindFirstChild("PlayerDataChanged")
    local RoundStart = gameplayRemotes and gameplayRemotes:FindFirstChild("RoundStart")
    local RoundEnd = gameplayRemotes and (gameplayRemotes:FindFirstChild("RoundEndFade") or gameplayRemotes:FindFirstChild("RoundEnd"))
    local CoinCollected = gameplayRemotes and gameplayRemotes:FindFirstChild("CoinCollected")

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

-- MAIN AUTOFARM LOOP
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

TabAutoFarm:CreateParagraph("⚠️ WARNING", "It is recommended to have a low auto farm speed value as it can kick you out of the game for invalid position.")

TabAutoFarm:CreateSlider("Farm_Speed", "Farm Speed", 15, 30, function(value)
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
-- CLEANUP TASK (INTEGRATED TO UNLOAD)
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
if KillerHub.NotifySuccess then
    KillerHub:NotifySuccess("Killer Hub", "Positions Persistence Solved & Fully Optimized!", 3)
elseif KillerHub.Notify then
    KillerHub:Notify("Killer Hub", "Positions Persistence Solved & Fully Optimized!", 3)
elseif KillerHub.NotifyWarn then
    KillerHub:NotifyWarn("Killer Hub", "Positions Persistence Solved & Fully Optimized!", 3)
end

return KillerHub
