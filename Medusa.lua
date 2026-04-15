-- [[ MEDUSA HUB V57 - THE DEFINITIVE AUTO-SAVE EDITION ]] --

local lp = game:GetService("Players").LocalPlayer
local Player = lp
local LocalPlayer = lp
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    baseEsp = false,
    xray = false,
    infJump = false, 
    optimizer = false,
    savedPos = nil
}

local Config = { AutoRight = false, AutoLeft = false }
local autoAimEnabled = false -- Remplace lagActive
local range = 100
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

-- [[ LOGIQUE ESP BASE TIMER ]] --
local function createBaseESP(base)
    local claimData = base:FindFirstChild("ClaimData")
    local timerVal = claimData and claimData:FindFirstChild("Timer")
    if not timerVal then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MedusaBaseTimer"
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 10, 0)
    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    local adorn = base:FindFirstChild("Main") or base:FindFirstChild("Pad") or base.PrimaryPart
    if adorn then billboard.Adornee = adorn; billboard.Parent = adorn end
    task.spawn(function()
        while billboard.Parent and cfg.baseEsp do
            local t = math.max(0, math.floor(timerVal.Value))
            label.Text = base.Name .. "\n" .. t .. "s"
            label.TextColor3 = t < 15 and Color3.new(1,0,0) or Color3.new(0,1,0)
            task.wait(0.2)
        end
        billboard:Destroy()
    end)
end
local function toggleBaseESP(val)
    cfg.baseEsp = val
    if val then
        local p = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("Bases")
        if p then for _, b in pairs(p:GetChildren()) do createBaseESP(b) end end
    else
        for _, v in pairs(workspace:GetDescendants()) do if v.Name == "MedusaBaseTimer" then v:Destroy() end end
    end
end

-- [[ INFINITE JUMP ]] --
UserInputService.JumpRequest:Connect(function()
    if cfg.infJump then
        local hum = GetHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- [[ XRAY LOGIC ]] --
local function toggleXray(v)
    cfg.xray = v
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(lp.Character) then
            if v then
                if not obj:FindFirstChild("MedusaXray") then
                    local originalTrans = Instance.new("NumberValue", obj)
                    originalTrans.Name = "MedusaXray"
                    originalTrans.Value = obj.Transparency
                    obj.Transparency = 0.5
                end
            else
                if obj:FindFirstChild("MedusaXray") then
                    obj.Transparency = obj.MedusaXray.Value
                    obj.MedusaXray:Destroy()
                end
            end
        end
    end
end

-- [ 3. LOGIQUE DUAL AIM BOT ] --
local Event = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RE/UseItem")

local function getNearestPlayer(maxRange)
    maxRange = maxRange or math.huge
    local hrp_me = GetRootPart()
    if not hrp_me then return nil end
    local myPos = hrp_me.Position
    local nearest = nil
    local shortest = maxRange
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
            local hrp_target = pl.Character.HumanoidRootPart
            local dist = (hrp_target.Position - myPos).Magnitude
            if dist < shortest then
                shortest = dist
                nearest = pl
            end
        end
    end
    return nearest
end

local function useLaserCape(targetPart)
    if not targetPart then return end
    local args = {targetPart.Position, targetPart}
    pcall(function() Event:FireServer(unpack(args)) end)
end

local function useWebSlinger(targetPart)
    if not targetPart then return end
    local char = lp.Character
    local backpack = lp:WaitForChild("Backpack")
    local tool = backpack:FindFirstChild("Web Slinger") or (char and char:FindFirstChild("Web Slinger"))
    if tool and tool:FindFirstChild("Handle") then
        local handle = tool.Handle
        local args = { Vector3.new(targetPart.Position.X, targetPart.Position.Y, targetPart.Position.Z), targetPart, handle }
        pcall(function() Event:FireServer(unpack(args)) end)
    end
end

local laserConnection = nil
local webConnection = nil

local function setupLaserAim()
    local char = lp.Character
    local backpack = lp:WaitForChild("Backpack")
    local laserTool = backpack:FindFirstChild("Laser Cape") or (char and char:FindFirstChild("Laser Cape"))
    if not laserTool then return end
    if laserConnection then laserConnection:Disconnect() end
    laserConnection = laserTool.Activated:Connect(function()
        if not autoAimEnabled then return end
        local target = getNearestPlayer(range)
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild("HumanoidRootPart")
            if targetPart then useLaserCape(targetPart) end
        end
    end)
end

local function setupWebAim()
    local char = lp.Character
    local backpack = lp:WaitForChild("Backpack")
    local webTool = backpack:FindFirstChild("Web Slinger") or (char and char:FindFirstChild("Web Slinger"))
    if not webTool then
        pcall(function()
            ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RF/CoinsShopService/RequestBuy"):InvokeServer("Web Slinger")
        end)
        task.wait(0.5)
        webTool = backpack:FindFirstChild("Web Slinger") or (char and char:FindFirstChild("Web Slinger"))
    end
    if not webTool then return end
    if webConnection then webConnection:Disconnect() end
    webConnection = webTool.Activated:Connect(function()
        if not autoAimEnabled then return end
        local target = getNearestPlayer(range)
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild("HumanoidRootPart")
            if targetPart then useWebSlinger(targetPart) end
        end
    end)
end

-- [ 4. NETTOYAGE UI ] --
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

-- [ 5. INITIALISATION RAYFIELD ] --
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "MEDUSA HUB V57",
   LoadingTitle = "Medusa Hub v57",
   LoadingSubtitle = "Jnkie + Cebo + Auto-Farm + XRay",
   ConfigurationSaving = { Enabled = true, FolderName = "MedusaHubV57", FileName = "MainConfig" }
})

-- [ 6. BAT AIMBOT ] --
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
            if bat and bat.Parent == c then bat:Activate() end
            local targetVel = torso.AssemblyLinearVelocity
            local dir = torso.Position - h.Position
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            local flatDist = flatDir.Magnitude
            local predictedPos = torso.Position + targetVel * (flatDist / 80)
            if flatDist > 1 then
                local moveDir = Vector3.new(predictedPos.X-h.Position.X, 0, predictedPos.Z-h.Position.Z).Unit
                local yDiff = torso.Position.Y - h.Position.Y
                local ySpeed = math.abs(yDiff) > 0.5 and math.clamp(yDiff*8, -100, 100) or targetVel.Y
                h.AssemblyLinearVelocity = Vector3.new(moveDir.X*58, ySpeed, moveDir.Z*58)
            else
                h.AssemblyLinearVelocity = Vector3.new(targetVel.X, targetVel.Y, targetVel.Z)
            end
        end
    end)
end

local function stopBatAimbot()
    if Connections.batAimbot then Connections.batAimbot:Disconnect(); Connections.batAimbot = nil end
end

-- [ 7. ANTI RAGDOLL V1 ] --
local antiRagdollMode    = nil
local ragdollConnections = {}
local cachedCharData     = {}
local isBoosting         = false

local function arCacheCharacterData()
    local char = Player.Character
    if not char then return false end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = { character = char, humanoid = hum, root = root }
    return true
end

local function arIsRagdolled()
    if not cachedCharData.humanoid then return false end
    local state = cachedCharData.humanoid:GetState()
    return (state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown)
end

local function arForceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function() Player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
    if not isBoosting then
        isBoosting = true
        cachedCharData.humanoid.WalkSpeed = 400
    end
    cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    cachedCharData.root.Anchored = false
end

local function arHeartbeatLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        if arIsRagdolled() then arForceExitRagdoll()
        elseif isBoosting then
            isBoosting = false
            if cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed = 16 end
        end
    end
end

local function startAntiRagdoll()
    if antiRagdollMode == "v1" then return end
    if not arCacheCharacterData() then return end
    antiRagdollMode = "v1"
    table.insert(ragdollConnections, Player.CharacterAdded:Connect(function() task.wait(0.5) arCacheCharacterData() end))
    task.spawn(arHeartbeatLoop)
end

local function stopAntiRagdoll()
    antiRagdollMode = nil
    isBoosting = false
    for _, v in pairs(ragdollConnections) do v:Disconnect() end
    ragdollConnections = {}
end

-- [ 8. AUTO WALK ] --
local FORWARD_SPEED, RETURN_SPEED = 59, 29
local RIGHT_PATH = {Vector3.new(-473.32, -7.67, 10.16), Vector3.new(-472.71, -8.14, 29.92), Vector3.new(-472.87, -8.14, 49.50), Vector3.new(-472.45, -8.14, 65.05), Vector3.new(-472.94, -8.14, 82.48), Vector3.new(-475.00, -8.14, 96.84), Vector3.new(-485.50, -6.43, 96.08)}
local LEFT_PATH = {Vector3.new(-473.31, -7.67, 111.75), Vector3.new(-473.51, -8.14, 87.30), Vector3.new(-473.74, -8.14, 60.58), Vector3.new(-474.04, -8.14, 41.38), Vector3.new(-474.35, -8.14, 25.77), Vector3.new(-485.30, -6.43, 22.36)}
local RIGHT_RET = {Vector3.new(-475.23, -8.14, 90.61), Vector3.new(-476.24, -8.14, 57.32), Vector3.new(-475.63, -8.14, 23.36)}
local LEFT_RET = {Vector3.new(-474.23, -8.14, 26.51), Vector3.new(-475.15, -8.14, 59.32), Vector3.new(-475.62, -8.06, 97.99)}

local function StopAutoWalk()
    if AutoWalkConnection then AutoWalkConnection:Disconnect(); AutoWalkConnection = nil end
    isAutoWalking, isReturning, isPaused = false, false, false
    local hum = GetHumanoid()
    if hum then hum:Move(Vector3.new(0, 0, 0)) end
end

local function StartAutoWalk(direction)
    StopAutoWalk()
    local waypoints = direction == "right" and RIGHT_PATH or LEFT_PATH
    local retPoints = direction == "right" and RIGHT_RET or LEFT_RET
    currentWaypointIndex, isAutoWalking = 1, true
    AutoWalkConnection = RunService.Heartbeat:Connect(function()
        if isPaused or not (Config.AutoRight or Config.AutoLeft) then return end
        if HasBrainrotInHand and not isReturning then isReturning, currentWaypointIndex = true, 1 end
        local targetList = isReturning and retPoints or waypoints
        local target = targetList[currentWaypointIndex]
        if not target then return end
        local moveDir = (target - GetRootPart().Position) * Vector3.new(1,0,1)
        GetHumanoid():Move(moveDir.Unit)
        GetRootPart().AssemblyLinearVelocity = Vector3.new(moveDir.Unit.X * (isReturning and RETURN_SPEED or FORWARD_SPEED), GetRootPart().AssemblyLinearVelocity.Y, moveDir.Unit.Z * (isReturning and RETURN_SPEED or FORWARD_SPEED))
        if moveDir.Magnitude < 3 then
            currentWaypointIndex = currentWaypointIndex + 1
            if currentWaypointIndex > #targetList then
                if not isReturning then isPaused = true; task.wait(0.3); isReturning, currentWaypointIndex, isPaused = true, 1, false
                else Config.AutoRight, Config.AutoLeft = false, false; StopAutoWalk() end
            end
        end
    end)
end

-- [ 9. VISUELS & PANELS ] --
local function CreateBoxESP(p)
    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = p.Character.HumanoidRootPart
        if not hrp:FindFirstChild("MedusaBox") then
            local b = Instance.new("BillboardGui", hrp); b.Name = "MedusaBox"; b.AlwaysOnTop = true; b.Size = UDim2.new(4.5,0,6,0); b.Adornee = hrp
            local f = Instance.new("Frame", b); f.Size = UDim2.new(1,0,1,0); f.BackgroundTransparency = 0.7; f.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
            Instance.new("UIStroke", f).Color = Color3.new(1,1,1)
        end
    end
end

local function CreateMiniPanel(name, pos, toggleFunc, initialValue)
    local f = Instance.new("Frame", lp.PlayerGui.MedusaPanels); f.Size = UDim2.new(0, 130, 0, 45); f.Position = pos; f.BackgroundColor3 = Color3.fromRGB(10, 10, 10); MakeDraggable(f)
    local corner = Instance.new("UICorner", f); corner.CornerRadius = UDim.new(0, 6); local stroke = Instance.new("UIStroke", f); stroke.Color = Color3.fromRGB(255, 105, 180); stroke.Thickness = 1.8
    local btn = Instance.new("TextButton", f); btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Font = "GothamBold"; btn.TextSize = 11; btn.TextColor3 = Color3.new(1,1,1)
    local function update(val)
        if name == "DUAL-AIM" then
            btn.Text = "DUAL-AIM\n"..(val and "[ ON ]" or "[ OFF ]")
            f.BackgroundColor3 = val and Color3.fromRGB(30, 30, 60) or Color3.fromRGB(10, 10, 10)
        else
            btn.Text = name.."\n"..(val and "[ ACTIVE ]" or "[ INACTIVE ]")
        end
        btn.TextColor3 = val and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(255, 105, 180)
    end
    btn.MouseButton1Click:Connect(function() initialValue = not initialValue; toggleFunc(initialValue); update(initialValue) end)
    update(initialValue); return update
end

local PanelGui = Instance.new("ScreenGui", lp.PlayerGui); PanelGui.Name = "MedusaPanels"; PanelGui.ResetOnSpawn = false
local updateBatPanel = CreateMiniPanel("BAT-AIM", UDim2.new(0, 20, 0, 250), function(v) Enabled.BatAimbot = v; if v then startBatAimbot() else stopBatAimbot() end end, Enabled.BatAimbot)
local updateAimPanel = CreateMiniPanel("DUAL-AIM", UDim2.new(0, 20, 0, 310), function(v) 
    autoAimEnabled = v 
    if v then setupLaserAim() setupWebAim() end
end, autoAimEnabled)
local updateRightPanel = CreateMiniPanel("AUTO-RIGHT", UDim2.new(1, -150, 0, 50), function(v) Config.AutoRight = v; if v then StartAutoWalk("right") else StopAutoWalk() end updateRightPanel(v) end, Config.AutoRight)
local updateLeftPanel = CreateMiniPanel("AUTO-LEFT", UDim2.new(1, -150, 0, 110), function(v) Config.AutoLeft = v; if v then StartAutoWalk("left") else StopAutoWalk() end updateLeftPanel(v) end, Config.AutoLeft)

-- [ 10. ONGLETS RAYFIELD ] --
local TabCombat = Window:CreateTab("COMBAT")
local TabFarm = Window:CreateTab("AUTO-FARM")
local TabMove = Window:CreateTab("MOUVEMENT")
local TabSettings = Window:CreateTab("PARAMÈTRES")

TabCombat:CreateToggle({Name = "Dual Aim (Laser/Web)", CurrentValue = false, Callback = function(v) autoAimEnabled = v if v then setupLaserAim() setupWebAim() end updateAimPanel(v) end})
TabCombat:CreateToggle({Name = "Bat Aimbot", CurrentValue = false, Callback = function(v) Enabled.BatAimbot = v if v then startBatAimbot() else stopBatAimbot() end updateBatPanel(v) end})
TabFarm:CreateToggle({Name = "Auto Right", CurrentValue = false, Callback = function(v) Config.AutoRight = v; if v then StartAutoWalk("right") else StopAutoWalk() end updateRightPanel(v) end})
TabFarm:CreateToggle({Name = "Auto Left", CurrentValue = false, Callback = function(v) Config.AutoLeft = v; if v then StartAutoWalk("left") else StopAutoWalk() end updateLeftPanel(v) end})

TabMove:CreateToggle({Name = "Speed Boost", CurrentValue = false, Callback = function(v) cfg.speed = v end})
TabMove:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Callback = function(v) cfg.infJump = v end})

TabSettings:CreateToggle({Name = "Player ESP", CurrentValue = false, Callback = function(v) cfg.esp = v end})
TabSettings:CreateToggle({Name = "Base Timer ESP", CurrentValue = false, Callback = function(v) toggleBaseESP(v) end})
TabSettings:CreateToggle({Name = "X-Ray", CurrentValue = false, Callback = function(v) toggleXray(v) end})
TabSettings:CreateToggle({Name = "Instant Steal", CurrentValue = false, Callback = function(v) cfg.fastSteal = v end})
TabSettings:CreateButton({Name = "Optimizer (Boost FPS)", Callback = function()
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(lp.Character) then
            v.Material = Enum.Material.SmoothPlastic
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v:Destroy()
        end
    end
end})

-- [ 11. STATS UI & BOUCLE FINALE ] --
local sg = Instance.new("ScreenGui", lp.PlayerGui); sg.Name = "MedusaStatsUI"; sg.ResetOnSpawn = false
local f_stats = Instance.new("Frame", sg); f_stats.Size = UDim2.new(0, 180, 0, 55); f_stats.Position = UDim2.new(0.5, -90, 0, 10); f_stats.BackgroundColor3 = Color3.new(0,0,0); MakeDraggable(f_stats)
Instance.new("UICorner", f_stats); local st = Instance.new("UIStroke", f_stats); st.Color = Color3.fromRGB(255, 105, 180); st.Thickness = 2
local t_stats = Instance.new("TextLabel", f_stats); t_stats.Size = UDim2.new(1,0,1,0); t_stats.BackgroundTransparency = 1; t_stats.TextColor3 = Color3.fromRGB(255,105,180); t_stats.Font = "GothamBold"; t_stats.TextSize = 12

RunService.RenderStepped:Connect(function()
    local fps = math.floor(1/RunService.RenderStepped:Wait())
    local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")
    t_stats.Text = "  MEDUSA V57\n  FPS: "..fps.." | PING: "..ping.."ms"
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local vel = lp.Character.HumanoidRootPart.Velocity
        speedLabel.Text = math.floor(Vector3.new(vel.X, 0, vel.Z).Magnitude) .. " sp"
        if cfg.speed and lp.Character:FindFirstChildOfClass("Humanoid").MoveDirection.Magnitude > 0 then
            lp.Character.HumanoidRootPart.Velocity = Vector3.new(lp.Character:FindFirstChildOfClass("Humanoid").MoveDirection.X * 57, lp.Character.HumanoidRootPart.Velocity.Y, lp.Character:FindFirstChildOfClass("Humanoid").MoveDirection.Z * 57)
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if cfg.esp then for _, p in pairs(Players:GetPlayers()) do if p ~= lp then CreateBoxESP(p) end end end
        if cfg.fastSteal then
            for _, v in pairs(workspace:GetDescendants()) do 
                if v:IsA("ProximityPrompt") then 
                    v.HoldDuration = 0 
                    if fireproximityprompt and (v.Parent.Position - GetRootPart().Position).Magnitude < v.MaxActivationDistance then fireproximityprompt(v) end
                end 
            end
        end
    end
end)
