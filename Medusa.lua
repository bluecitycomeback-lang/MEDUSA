-- [[ MEDUSA HUB V57 - THE DEFINITIVE AUTO-SAVE EDITION ]] --

local lp = game:GetService("Players").LocalPlayer
local Player = lp
local LocalPlayer = lp
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- [ 1. CONFIGURATION & VARIABLES GLOBALES ] --
local cfg = {
    speed = false, 
    meleeAimbot = false, 
    antiRagdoll = false, 
    fastSteal = false, 
    esp = false, 
    xray = false,
    infJump = false, 
    optimizer = false,
    savedPos = nil
}

local Config = { AutoRight = false, AutoLeft = false }
local lagActive = false 
local ToggleFunctions = {}
local Connections = {} 
local Enabled = { BatAimbot = false } 
local AutoWalkConnection = nil
local isAutoWalking = false
local isReturning = false
local isPaused = false
local currentWaypointIndex = 1
local OriginalCameraZoom = nil
local OriginalCameraMaxZoom = nil
local IsShuttingDown = false
local HasBrainrotInHand = false

-- [[ SPEED INDICATOR ]] --
local speedBillboard = Instance.new("BillboardGui")
speedBillboard.Name = "CH_SpeedDisplay"
speedBillboard.Size = UDim2.new(0, 90, 0, 26)
speedBillboard.StudsOffset = Vector3.new(0, 3.5, 0)
speedBillboard.AlwaysOnTop = false
speedBillboard.ResetOnSpawn = false

local speedLabel = Instance.new("TextLabel", speedBillboard)
speedLabel.Size = UDim2.new(1, 0, 1, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextSize = 20
speedLabel.Text = "0 sp"
speedLabel.TextStrokeTransparency = 0.3
speedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local function attachSpeedDisplay()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    speedBillboard.Adornee = hrp
    speedBillboard.Parent = CoreGui
end

LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
    task.wait(0.1)
    attachSpeedDisplay()
    if not LocalPlayer:FindFirstChild("CHERRY_USER") then
        local t2 = Instance.new("StringValue")
        t2.Name = "CHERRY_USER"
        t2.Value = "using cherry hub"
        t2.Parent = LocalPlayer
    end
end)
attachSpeedDisplay()

-- [ 2. FONCTIONS UTILITAIRES ] --
local function GetHumanoid() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end
local function GetRootPart() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end

-- Détection du Brainrot
RunService.Heartbeat:Connect(function()
    if lp.Character and lp.Character:FindFirstChild("Brainrot") then
        HasBrainrotInHand = true
    else
        HasBrainrotInHand = false
    end
end)

-- [ 3. NETTOYAGE UI ] --
for _, v in pairs(lp.PlayerGui:GetChildren()) do
    if v.Name == "Rayfield" or v.Name == "MedusaStatsUI" or v.Name == "MedusaPanels" then v:Destroy() end
end

-- [ FONCTION DE DRAG PERSONNALISÉE ] --
local function MakeDraggable(gui)
    local dragging, dragInput, dragStart, startPos
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- [ 4. INITIALISATION RAYFIELD ] --
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "MEDUSA HUB V57",
   LoadingTitle = "Medusa Hub v57",
   LoadingSubtitle = "Jnkie + Cebo + Auto-Farm + XRay",
   ConfigurationSaving = { Enabled = true, FolderName = "MedusaHubV57", FileName = "MainConfig" }
})

-- [ 5. BAT AIMBOT (ANCIENNE LOGIQUE + AUTO HIT) ] --

local function getBat()
    local char = LocalPlayer.Character; if not char then return nil end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool and tool.Name == "Bat" then return tool end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then local bt = bp:FindFirstChild("Bat"); if bt then return bt end end
    return nil
end

local function findNearestEnemy(myHRP)
    local nearest, nearestDist, nearestTorso = nil, math.huge, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local eh    = p.Character:FindFirstChild("HumanoidRootPart")
            local torso = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum   = p.Character:FindFirstChildOfClass("Humanoid")
            if eh and hum and hum.Health > 0 then
                local d = (eh.Position - myHRP.Position).Magnitude
                if d < nearestDist then nearestDist=d; nearest=eh; nearestTorso=torso or eh end
            end
        end
    end
    return nearest, nearestDist, nearestTorso
end

local function startBatAimbot()
    if Connections.batAimbot then return end
    Connections.batAimbot = RunService.Heartbeat:Connect(function()
        if not Enabled.BatAimbot then return end
        local c = LocalPlayer.Character; if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        
        local bat = getBat()
        local target, dist, torso = findNearestEnemy(h)
        
        if target and torso then
            -- AUTO HIT (TAPE TOUT SEUL)
            if bat and bat.Parent == c then
                bat:Activate()
            end

            -- ANCIENNE LOGIQUE DE MOUVEMENT FLUIDE
            local targetVel = torso.AssemblyLinearVelocity
            local dir = torso.Position - h.Position
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            local flatDist = flatDir.Magnitude
            local timeToReach = flatDist / 80
            local predictedPos = torso.Position + targetVel * timeToReach
            local spd = 58
            
            if flatDist > 1 then
                local moveDir = Vector3.new(predictedPos.X-h.Position.X, 0, predictedPos.Z-h.Position.Z).Unit
                local yDiff = torso.Position.Y - h.Position.Y
                local ySpeed = math.abs(yDiff) > 0.5 and math.clamp(yDiff*8, -100, 100) or targetVel.Y
                h.AssemblyLinearVelocity = Vector3.new(moveDir.X*spd, ySpeed, moveDir.Z*spd)
            else
                h.AssemblyLinearVelocity = Vector3.new(targetVel.X, targetVel.Y, targetVel.Z)
            end
        end
    end)
end

local function stopBatAimbot()
    if Connections.batAimbot then Connections.batAimbot:Disconnect(); Connections.batAimbot = nil end
end

-- ─── ANTI RAGDOLL V1 ───
local antiRagdollMode    = nil
local ragdollConnections = {}
local cachedCharData     = {}
local isBoosting         = false
local BOOST_SPEED        = 400
local AR_DEFAULT_SPEED   = 16

local function arCacheCharacterData()
    local char = Player.Character
    if not char then return false end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = { character = char, humanoid = hum, root = root }
    return true
end

local function arDisconnectAll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
end

local function arIsRagdolled()
    if not cachedCharData.humanoid then return false end
    local state = cachedCharData.humanoid:GetState()
    local ragdollStates = {
        [Enum.HumanoidStateType.Physics]     = true,
        [Enum.HumanoidStateType.Ragdoll]     = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }
    if ragdollStates[state] then return true end
    local endTime = Player:GetAttribute("RagdollEndTime")
    if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then return true end
    return false
end

local function arForceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function()
        Player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    for _, descendant in ipairs(cachedCharData.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or
           (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            descendant:Destroy()
        end
    end
    if not isBoosting then
        isBoosting = true
        cachedCharData.humanoid.WalkSpeed = BOOST_SPEED
    end
    if cachedCharData.humanoid.Health > 0 then
        cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    cachedCharData.root.Anchored = false
end

local function arHeartbeatLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        local currentlyRagdolled = arIsRagdolled()
        if currentlyRagdolled then
            arForceExitRagdoll()
        elseif isBoosting and not currentlyRagdolled then
            isBoosting = false
            if cachedCharData.humanoid then
                cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED
            end
        end
    end
end

local function startAntiRagdoll()
    if antiRagdollMode == "v1" then return end
    if not arCacheCharacterData() then return end
    antiRagdollMode = "v1"
    local camConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then
            cam.CameraSubject = cachedCharData.humanoid
        end
    end)
    table.insert(ragdollConnections, camConn)
    local respawnConn = Player.CharacterAdded:Connect(function()
        isBoosting = false
        task.wait(0.5)
        arCacheCharacterData()
    end)
    table.insert(ragdollConnections, respawnConn)
    task.spawn(arHeartbeatLoop)
end

local function stopAntiRagdoll()
    antiRagdollMode = nil
    if isBoosting and cachedCharData.humanoid then
        cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED
    end
    isBoosting = false
    arDisconnectAll()
    cachedCharData = {}
end

-- [ 6. AUTO WALK ] --

local FORWARD_SPEED = 59
local RETURN_SPEED = 29

local RIGHT_PATH = {
    Vector3.new(-473.32, -7.67, 10.16),
    Vector3.new(-472.71, -8.14, 29.92),
    Vector3.new(-472.87, -8.14, 49.50),
    Vector3.new(-472.45, -8.14, 65.05),
    Vector3.new(-472.94, -8.14, 82.48),
    Vector3.new(-475.00, -8.14, 96.84),  
    Vector3.new(-485.50, -6.43, 96.08),
}

local LEFT_PATH = {
    Vector3.new(-473.31, -7.67, 111.75),
    Vector3.new(-473.51, -8.14, 87.30),
    Vector3.new(-473.74, -8.14, 60.58),
    Vector3.new(-474.04, -8.14, 41.38),
    Vector3.new(-474.35, -8.14, 25.77),
    Vector3.new(-485.30, -6.43, 22.36),
}

local RIGHT_RETURN_PATH_FAST = {
    Vector3.new(-475.23, -8.14, 90.61),
    Vector3.new(-476.24, -8.14, 57.32),
    Vector3.new(-475.63, -8.14, 23.36),
}

local LEFT_RETURN_PATH_FAST = {
    Vector3.new(-474.23, -8.14, 26.51),
    Vector3.new(-475.15, -8.14, 59.32),
    Vector3.new(-475.62, -8.06, 97.99),
}

local waypoints = {}
local returnWaypoints = {}
local returnWaypointIndex = 1

local function StopAutoWalk()
    if AutoWalkConnection then
        AutoWalkConnection:Disconnect()
        AutoWalkConnection = nil
    end
    waypoints = {}
    returnWaypoints = {}
    currentWaypointIndex = 1
    returnWaypointIndex = 1
    isAutoWalking = false
    isReturning = false
    isPaused = false
    
    if OriginalCameraZoom then
        LocalPlayer.CameraMinZoomDistance = OriginalCameraZoom
        OriginalCameraZoom = nil
    end
    if OriginalCameraMaxZoom then
        LocalPlayer.CameraMaxZoomDistance = OriginalCameraMaxZoom
        OriginalCameraMaxZoom = nil
    end
    
    local humanoid = GetHumanoid()
    if humanoid then humanoid:Move(Vector3.new(0, 0, 0)) end
    
    local rootPart = GetRootPart()
    if rootPart then rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
end

local function FindClosestWaypoint(position, waypointList)
    local closestIndex = 1
    local closestDistance = math.huge
    for i, waypoint in ipairs(waypointList) do
        local dist = (Vector3.new(waypoint.X, position.Y, waypoint.Z) - position).Magnitude
        if dist < closestDistance then
            closestDistance = dist
            closestIndex = i
        end
    end
    return closestIndex
end

local function StartAutoWalk(direction)
    StopAutoWalk()
    if OriginalCameraZoom == nil then
        OriginalCameraZoom = LocalPlayer.CameraMinZoomDistance
    end
    if OriginalCameraMaxZoom == nil then
        OriginalCameraMaxZoom = LocalPlayer.CameraMaxZoomDistance
    end
    
    local rootPart = GetRootPart()
    if not rootPart then return end
    
    local currentPos = rootPart.Position
    if direction == "right" then
        waypoints = RIGHT_PATH
        returnWaypoints = RIGHT_RETURN_PATH_FAST
    elseif direction == "left" then
        waypoints = LEFT_PATH
        returnWaypoints = LEFT_RETURN_PATH_FAST
    end
    
    currentWaypointIndex = FindClosestWaypoint(currentPos, waypoints)
    returnWaypointIndex = 1
    isAutoWalking = true
    isReturning = false
    isPaused = false
    
    AutoWalkConnection = RunService.Heartbeat:Connect(function()
        if IsShuttingDown then return end
        if not Config.AutoRight and not Config.AutoLeft then 
            StopAutoWalk()
            return 
        end
        if isPaused then return end
        
        if HasBrainrotInHand and not isReturning then
            isReturning = true
            returnWaypointIndex = 1
        end
        
        local humanoid = GetHumanoid()
        local rootPart = GetRootPart()
        if not humanoid or not rootPart or not isAutoWalking then return end
        
        local targetPos = isReturning and returnWaypoints[returnWaypointIndex] or waypoints[currentWaypointIndex]
        if not targetPos then return end
        
        local directionVector = (targetPos - rootPart.Position) * Vector3.new(1, 0, 1)
        local distance = directionVector.Magnitude
        local moveDirection = directionVector.Unit
        
        humanoid:Move(moveDirection)
        
        local speedValue = isReturning and RETURN_SPEED or FORWARD_SPEED
        rootPart.AssemblyLinearVelocity = Vector3.new(
            moveDirection.X * speedValue,
            rootPart.AssemblyLinearVelocity.Y,
            moveDirection.Z * speedValue
        )
        
        if distance < 3.0 then
            if not isReturning then
                currentWaypointIndex = currentWaypointIndex + 1
                if currentWaypointIndex > #waypoints then
                    isPaused = true
                    humanoid:Move(Vector3.new(0, 0, 0))
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
                    task.spawn(function()
                        task.wait(0.3)
                        isReturning = true
                        returnWaypointIndex = 1
                        isPaused = false
                    end)
                end
            else
                returnWaypointIndex = returnWaypointIndex + 1
                if returnWaypointIndex > #returnWaypoints then
                    isPaused = true
                    humanoid:Move(Vector3.new(0, 0, 0))
                    if Config.AutoRight then
                        Config.AutoRight = false
                        if ToggleFunctions["AutoRight"] then ToggleFunctions["AutoRight"](false) end
                    elseif Config.AutoLeft then
                        Config.AutoLeft = false
                        if ToggleFunctions["AutoLeft"] then ToggleFunctions["AutoLeft"](false) end
                    end
                    StopAutoWalk()
                end
            end
        end
    end)
end

function ToggleAutoRight(enabled)
    Config.AutoRight = enabled
    if enabled then
        Config.AutoLeft = false
        if ToggleFunctions["AutoLeft"] then ToggleFunctions["AutoLeft"](false) end
        StartAutoWalk("right")
    else
        if not Config.AutoLeft then StopAutoWalk() end
    end
end

function ToggleAutoLeft(enabled)
    Config.AutoLeft = enabled
    if enabled then
        Config.AutoRight = false
        if ToggleFunctions["AutoRight"] then ToggleFunctions["AutoRight"](false) end
        StartAutoWalk("left")
    else
        if not Config.AutoRight then StopAutoWalk() end
    end
end

-- [ 7. SCRIPTS VISUELS ] --

local originalTransparency = {}
local function enableXRay()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and
               (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                originalTransparency[obj] = obj.LocalTransparencyModifier
                obj.LocalTransparencyModifier = 0.85
            end
        end
    end)
end

local function disableXRay()
    for part, value in pairs(originalTransparency) do
        if part then part.LocalTransparencyModifier = value end
    end
    originalTransparency = {}
end

local function CreateBoxESP(p)
    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = p.Character.HumanoidRootPart
        if not hrp:FindFirstChild("MedusaBox") then
            local b = Instance.new("BillboardGui", hrp)
            b.Name = "MedusaBox"; b.AlwaysOnTop = true; b.Size = UDim2.new(4.5,0,6,0); b.Adornee = hrp
            local f = Instance.new("Frame", b); f.Size = UDim2.new(1,0,1,0); f.BackgroundTransparency = 0.7; f.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
            Instance.new("UIStroke", f).Color = Color3.new(1,1,1)
            local tl = Instance.new("TextLabel", b); tl.Size = UDim2.new(1,0,0.2,0); tl.Position = UDim2.new(0,0,-0.25,0); tl.BackgroundTransparency = 1
            tl.Text = p.Name; tl.TextColor3 = Color3.new(1,1,1); tl.Font = "GothamBold"; tl.TextSize = 10
        end
    end
end

local function ApplyOptimizer(state)
    if state then
        Lighting.GlobalShadows = false
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then v.Material = Enum.Material.Plastic v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
        end
    else Lighting.GlobalShadows = true end
end

-- [ 8. PANELS AMOVIBLES ] --
local PanelGui = Instance.new("ScreenGui", lp.PlayerGui)
PanelGui.Name = "MedusaPanels"
PanelGui.ResetOnSpawn = false -- CORRECTIF : Reste affiché après la mort

local function CreateMiniPanel(name, pos, toggleFunc, initialValue)
    local f = Instance.new("Frame", PanelGui)
    f.Name = name.."Panel"
    f.Size = UDim2.new(0, 130, 0, 45)
    f.Position = pos
    f.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    f.BorderSizePixel = 0
    f.Active = false 
    
    MakeDraggable(f)

    local corner = Instance.new("UICorner", f); corner.CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", f); stroke.Color = Color3.fromRGB(255, 105, 180); stroke.Thickness = 1.8

    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Font = "GothamBold"; btn.TextSize = 11; btn.TextColor3 = Color3.new(1,1,1)
    
    local function updateVisual(val)
        if name == "FREEZE" then
            btn.Text = "FREEZE\n"..(val and "ON" or "OFF")
            btn.TextColor3 = val and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
            f.BackgroundColor3 = val and Color3.fromRGB(120, 20, 20) or Color3.fromRGB(50, 10, 10)
        else
            btn.Text = name.."\n"..(val and "[ ACTIVE ]" or "[ INACTIVE ]")
            btn.TextColor3 = val and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(255, 105, 180)
        end
    end
    
    btn.MouseButton1Click:Connect(function()
        local currentVal
        if name == "BAT-AIM" then currentVal = Enabled.BatAimbot
        elseif name == "AUTO-RIGHT" then currentVal = Config.AutoRight
        elseif name == "AUTO-LEFT" then currentVal = Config.AutoLeft
        elseif name == "FREEZE" then currentVal = lagActive end
        
        local newState = not currentVal
        toggleFunc(newState)
        updateVisual(newState)
    end)

    updateVisual(initialValue)
    return function(val) updateVisual(val) end
end

local updateBatPanel = CreateMiniPanel("BAT-AIM", UDim2.new(0, 20, 0, 250), function(v) 
    Enabled.BatAimbot = v 
    if v then startBatAimbot() else stopBatAimbot() end 
end, Enabled.BatAimbot)

local updateLagPanel = CreateMiniPanel("FREEZE", UDim2.new(0, 20, 0, 310), function(v) 
    lagActive = v 
    workspace:SetAttribute("CH_FREEZE", v) 
end, lagActive)

local updateRightPanel = CreateMiniPanel("AUTO-RIGHT", UDim2.new(1, -150, 0, 50), function(v) ToggleAutoRight(v) end, Config.AutoRight)
local updateLeftPanel = CreateMiniPanel("AUTO-LEFT", UDim2.new(1, -150, 0, 110), function(v) ToggleAutoLeft(v) end, Config.AutoLeft)

-- [ 9. ONGLETS ET LOGIQUE INTERFACE ] --

local TabCombat = Window:CreateTab("COMBAT")
local TabFarm = Window:CreateTab("AUTO-FARM")
local TabMove = Window:CreateTab("MOUVEMENT")
local TabVisuals = Window:CreateTab("VISUELS")
local TabSettings = Window:CreateTab("PARAMÈTRES")

local MeleeToggle = TabCombat:CreateToggle({
    Name = "New Bat Aimbot", 
    CurrentValue = false, 
    Flag = "MeleeAimbot", 
    Callback = function(v) 
        Enabled.BatAimbot = v 
        if v then startBatAimbot() else stopBatAimbot() end 
        updateBatPanel(v)
    end
})

TabCombat:CreateToggle({
    Name = "Anti-Ragdoll v1", 
    CurrentValue = false, 
    Flag = "AntiRagdoll", 
    Callback = function(v) cfg.antiRagdoll = v if v then startAntiRagdoll() else stopAntiRagdoll() end end
})

local RightToggle = TabFarm:CreateToggle({
    Name = "Auto Right Path", CurrentValue = false, Flag = "AR", 
    Callback = function(v) ToggleAutoRight(v) updateRightPanel(v) end
})
ToggleFunctions["AutoRight"] = function(v) RightToggle:Set(v) updateRightPanel(v) end

local LeftToggle = TabFarm:CreateToggle({
    Name = "Auto Left Path", CurrentValue = false, Flag = "AL", 
    Callback = function(v) ToggleAutoLeft(v) updateLeftPanel(v) end
})
ToggleFunctions["AutoLeft"] = function(v) LeftToggle:Set(v) updateLeftPanel(v) end

TabMove:CreateToggle({
    Name = "Speed Boost (57)", CurrentValue = false, Flag = "Spd", 
    Callback = function(v) cfg.speed = v end
})

TabMove:CreateToggle({
    Name = "Infinite Jump", CurrentValue = false, Flag = "IJ", 
    Callback = function(v) cfg.infJump = v end
})

TabVisuals:CreateToggle({
    Name = "ESP Anti-Invis", CurrentValue = false, Flag = "ESP", 
    Callback = function(v) cfg.esp = v end
})

TabVisuals:CreateToggle({
    Name = "Base X-Ray", CurrentValue = false, Flag = "XR", 
    Callback = function(v) cfg.xray = v if v then enableXRay() else disableXRay() end end
})

TabSettings:CreateToggle({
    Name = "FPS Booster (Optimizer)", CurrentValue = false, Flag = "Opt", 
    Callback = function(v) cfg.optimizer = v ApplyOptimizer(v) end
})

TabSettings:CreateToggle({
    Name = "Instant Steal", CurrentValue = false, Flag = "IS", 
    Callback = function(v) cfg.fastSteal = v end
})

-- [ 10. STATS UI ET BOUCLE FINALE ] --
local sg = Instance.new("ScreenGui", lp.PlayerGui); sg.Name = "MedusaStatsUI"
sg.ResetOnSpawn = false -- CORRECTIF : Reste affiché après la mort
local f = Instance.new("Frame", sg); f.Size = UDim2.new(0, 180, 0, 55); f.Position = UDim2.new(0.5, -90, 0, 10); f.BackgroundColor3 = Color3.new(0,0,0); f.Active = false
MakeDraggable(f)

Instance.new("UICorner", f); local st = Instance.new("UIStroke", f); st.Color = Color3.fromRGB(255, 105, 180); st.Thickness = 2
local t = Instance.new("TextLabel", f); t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1; t.TextColor3 = Color3.fromRGB(255,105,180); t.Font = "GothamBold"; t.TextSize = 12

RunService.RenderStepped:Connect(function()
    local fps = math.floor(1/RunService.RenderStepped:Wait())
    local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")
    t.Text = "  MEDUSA V57\n  FPS: "..fps.." | PING: "..ping.."ms"
    
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local velocity = lp.Character.HumanoidRootPart.Velocity
        local speed = math.floor(Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
        speedLabel.Text = speed .. " sp"
    end

    if cfg.speed and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            hrp.Velocity = Vector3.new(hum.MoveDirection.X * 57, hrp.Velocity.Y, hum.MoveDirection.Z * 57)
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if cfg.infJump and GetRootPart() then
        GetRootPart().Velocity = Vector3.new(GetRootPart().Velocity.X, 50, GetRootPart().Velocity.Z)
    end
end)

-- LOGIQUE OPTIMISÉE FAST STEAL + ESP + INTERVALLES
task.spawn(function()
    while task.wait(0.1) do -- Boucle plus rapide (0.1s au lieu de 0.3s)
        if cfg.esp then
            for _, p in pairs(Players:GetPlayers()) do if p ~= lp then CreateBoxESP(p) end end
        else
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart:FindFirstChild("MedusaBox") then
                    p.Character.HumanoidRootPart.MedusaBox:Destroy()
                end
            end
        end
        
        -- FAST STEAL ULTIME
        if cfg.fastSteal then
            for _, v in pairs(workspace:GetDescendants()) do 
                if v:IsA("ProximityPrompt") then 
                    v.HoldDuration = 0 -- Pas de temps d'attente
                    v.ClickablePrompt = true -- Toujours cliquable
                end 
            end
        end
    end
end)

Rayfield:LoadConfiguration()
