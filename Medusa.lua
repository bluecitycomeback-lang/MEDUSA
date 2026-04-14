--[[
    ███╗   ███╗███████╗██████╗ ██╗   ██╗███████╗ █████╗ 
    ████╗ ████║██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
    ██╔████╔██║█████╗  ██║  ██║██║   ██║███████╗███████║
    ██║╚██╔╝██║██╔══╝  ██║  ██║██║   ██║╚════██║██╔══██║
    ██║ ╚═╝ ██║███████╗██████╔╝╚██████╔╝███████║██║  ██║
    ╚═╝     ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝
    
    VERSION: V57 - MEGA EXTENDED EDITION
    PROPRIÉTÉ DE: JNKIE & CEBO EDIT
    LIGNES: 600+
]]--

-- ────────────────────────────────────────────────────────────────
-- [ 1. INITIALISATION DES SERVICES ]
-- ────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")
local Stats = game:GetService("Stats")

-- ────────────────────────────────────────────────────────────────
-- [ 2. VARIABLES DE CONFIGURATION ]
-- ────────────────────────────────────────────────────────────────
local lp = Players.LocalPlayer
local Player = lp
local Character = lp.Character or lp.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local cfg = {
    speed = false, 
    speedValue = 57,
    meleeAimbot = false, 
    antiRagdoll = false, 
    fastSteal = false, 
    esp = false, 
    xray = false,
    infJump = false, 
    optimizer = false,
    noFog = false,
    lowGraphics = false
}

local Config = { 
    AutoRight = false, 
    AutoLeft = false 
}

local ToggleFunctions = {}
local AutoWalkConnection = nil
local isAutoWalking = false
local isReturning = false
local isPaused = false
local currentWaypointIndex = 1
local returnWaypointIndex = 1
local HasBrainrotInHand = false
local OriginalTransparency = {}

-- ────────────────────────────────────────────────────────────────
-- [ 3. MODULE : OPTIMIZER FPS EXTRÊME ]
-- ────────────────────────────────────────────────────────────────
local function FullOptimizer(state)
    if state then
        print("[MEDUSA] Activation de l'optimisation maximale...")
        
        -- Désactivation des effets de lumière
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        
        -- Suppression des effets visuels lourds
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostProcessEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = false
            end
        end

        -- Modification des textures de la map
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
                v.CastShadow = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = false
            elseif v:IsA("MeshPart") then
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
            elseif v:IsA("Sky") then
                v.Parent = nil -- Enlève le ciel pour gagner des FPS
            end
        end
        
        -- Paramètres de rendu Roblox
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    else
        print("[MEDUSA] Restauration des graphismes...")
        Lighting.GlobalShadows = true
        -- Note: Une restauration complète nécessite souvent un changement de serveur
    end
end

-- ────────────────────────────────────────────────────────────────
-- [ 4. MODULE : MELEE AIMBOT (CEBO SYSTEM) ]
-- ────────────────────────────────────────────────────────────────
local Cebo = { Conn = nil, Circle = nil, Align = nil, Attach = nil }

local function startMeleeAimbot()
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    
    Cebo.Attach = Instance.new("Attachment", hrp)
    Cebo.Align = Instance.new("AlignOrientation", hrp)
    Cebo.Align.Attachment0 = Cebo.Attach
    Cebo.Align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    Cebo.Align.RigidityEnabled = true
    
    Cebo.Circle = Instance.new("Part")
    Cebo.Circle.Shape = Enum.PartType.Cylinder
    Cebo.Circle.Material = Enum.Material.Neon
    Cebo.Circle.Size = Vector3.new(0.05, 14.5, 14.5)
    Cebo.Circle.Color = Color3.fromRGB(255, 0, 0)
    Cebo.Circle.CanCollide = false
    Cebo.Circle.Massless = true
    Cebo.Circle.Parent = workspace
    
    local weld = Instance.new("Weld")
    weld.Part0 = hrp
    weld.Part1 = Cebo.Circle
    weld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90))
    weld.Parent = Cebo.Circle
    
    Cebo.Conn = RunService.RenderStepped:Connect(function()
        local target = nil
        local dmin = 7.25
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                if d <= dmin then target, dmin = p.Character.HumanoidRootPart, d end
            end
        end
        
        if target then
            char.Humanoid.AutoRotate = false
            Cebo.Align.Enabled = true
            Cebo.Align.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(target.Position.X, hrp.Position.Y, target.Position.Z))
            local tool = char:FindFirstChild("Bat") or char:FindFirstChild("Medusa")
            if tool then tool:Activate() end
        else
            Cebo.Align.Enabled = false
            char.Humanoid.AutoRotate = true
        end
    end)
end

local function stopMeleeAimbot()
    if Cebo.Conn then Cebo.Conn:Disconnect() Cebo.Conn = nil end
    if Cebo.Circle then Cebo.Circle:Destroy() Cebo.Circle = nil end
    if Cebo.Align then Cebo.Align:Destroy() Cebo.Align = nil end
    if Cebo.Attach then Cebo.Attach:Destroy() Cebo.Attach = nil end
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.AutoRotate = true
    end
end

-- ────────────────────────────────────────────────────────────────
-- [ 5. MODULE : ANTI-RAGDOLL V1 ]
-- ────────────────────────────────────────────────────────────────
local AntiRagData = { Mode = nil, Conns = {}, IsBoosting = false }

local function arForceExit()
    local c = lp.Character
    if not c then return end
    pcall(function() lp:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or (v:IsA("Attachment") and v.Name:find("RagdollAttachment")) then v:Destroy() end
    end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then
        if not AntiRagData.IsBoosting then AntiRagData.IsBoosting = true h.WalkSpeed = 400 end
        h:ChangeState(Enum.HumanoidStateType.Running)
    end
end

function startAntiRagdoll()
    AntiRagData.Mode = "v1"
    task.spawn(function()
        while AntiRagData.Mode == "v1" do
            task.wait()
            local h = (lp.Character and lp.Character:FindFirstChildOfClass("Humanoid"))
            if h then
                local isRag = (h:GetState() == Enum.HumanoidStateType.Physics)
                if lp:GetAttribute("RagdollEndTime") and (lp:GetAttribute("RagdollEndTime") - workspace:GetServerTimeNow()) > 0 then isRag = true end
                if isRag then arForceExit() elseif AntiRagData.IsBoosting then AntiRagData.IsBoosting = false h.WalkSpeed = 16 end
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────────
-- [ 6. MODULE : AUTO-WALK (COORDONNÉES COMPLÈTES) ]
-- ────────────────────────────────────────────────────────────────
local PATHS = {
    FORWARD_SPEED = 59,
    RETURN_SPEED = 29,
    
    RIGHT = {
        Vector3.new(-473.32, -7.67, 10.16),
        Vector3.new(-472.71, -8.14, 29.92),
        Vector3.new(-472.87, -8.14, 49.50),
        Vector3.new(-472.45, -8.14, 65.05),
        Vector3.new(-472.94, -8.14, 82.48),
        Vector3.new(-475.00, -8.14, 96.84),
        Vector3.new(-485.50, -6.43, 96.08)
    },
    
    LEFT = {
        Vector3.new(-473.31, -7.67, 111.75),
        Vector3.new(-473.51, -8.14, 87.30),
        Vector3.new(-473.74, -8.14, 60.58),
        Vector3.new(-474.04, -8.14, 41.38),
        Vector3.new(-474.35, -8.14, 25.77),
        Vector3.new(-485.30, -6.43, 22.36)
    },
    
    RIGHT_RET = {
        Vector3.new(-475.23, -8.14, 90.61),
        Vector3.new(-476.24, -8.14, 57.32),
        Vector3.new(-475.63, -8.14, 23.36)
    },
    
    LEFT_RET = {
        Vector3.new(-474.23, -8.14, 26.51),
        Vector3.new(-475.15, -8.14, 59.32),
        Vector3.new(-475.62, -8.06, 97.99)
    }
}

local function StartAutoWalk(dir)
    if AutoWalkConnection then AutoWalkConnection:Disconnect() end
    local mainPath = (dir == "right") and PATHS.RIGHT or PATHS.LEFT
    local retPath = (dir == "right") and PATHS.RIGHT_RET or PATHS.LEFT_RET
    
    currentWaypointIndex = 1
    returnWaypointIndex = 1
    isAutoWalking = true
    isReturning = false
    isPaused = false
    
    AutoWalkConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoRight and not Config.AutoLeft then if AutoWalkConnection then AutoWalkConnection:Disconnect() end return end
        if isPaused then return end
        
        -- Détection outils en main
        if lp.Character and lp.Character:FindFirstChild("Brainrot") then
            isReturning = true
        end
        
        local h = (lp.Character and lp.Character:FindFirstChildOfClass("Humanoid"))
        local r = (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"))
        if not h or not r then return end
        
        local target = isReturning and retPath[returnWaypointIndex] or mainPath[currentWaypointIndex]
        if not target then return end
        
        local dirVec = (target - r.Position) * Vector3.new(1,0,1)
        h:Move(dirVec.Unit)
        
        local spd = isReturning and PATHS.RETURN_SPEED or PATHS.FORWARD_SPEED
        r.AssemblyLinearVelocity = Vector3.new(dirVec.Unit.X * spd, r.AssemblyLinearVelocity.Y, dirVec.Unit.Z * spd)
        
        if dirVec.Magnitude < 3.5 then
            if not isReturning then
                currentWaypointIndex = currentWaypointIndex + 1
                if currentWaypointIndex > #mainPath then
                    isPaused = true
                    task.wait(0.5)
                    isReturning = true
                    isPaused = false
                end
            else
                returnWaypointIndex = returnWaypointIndex + 1
                if returnWaypointIndex > #retPath then
                    Config.AutoRight = false
                    Config.AutoLeft = false
                    ToggleFunctions.AutoRight(false)
                    ToggleFunctions.AutoLeft(false)
                    isAutoWalking = false
                    AutoWalkConnection:Disconnect()
                end
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────────
-- [ 7. MODULE : INFINITE JUMP (VERSION ORIGINALE) ]
-- ────────────────────────────────────────────────────────────────
local function EnableInfJump()
    UserInputService.JumpRequest:Connect(function()
        if cfg.infJump then
            local r = (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"))
            if r then
                r.Velocity = Vector3.new(r.Velocity.X, 50, r.Velocity.Z)
            end
        end
    end)
end
EnableInfJump()

-- ────────────────────────────────────────────────────────────────
-- [ 8. MODULE : VISUELS (XRAY & ESP) ]
-- ────────────────────────────────────────────────────────────────
local function DoXray(state)
    if state then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                OriginalTransparency[obj] = obj.LocalTransparencyModifier
                obj.LocalTransparencyModifier = 0.85
            end
        end
    else
        for obj, val in pairs(OriginalTransparency) do
            if obj then obj.LocalTransparencyModifier = val end
        end
        OriginalTransparency = {}
    end
end

-- ────────────────────────────────────────────────────────────────
-- [ 9. INTERFACE RAYFIELD ]
-- ────────────────────────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "MEDUSA HUB V57 - ULTIMATE EDITION",
    LoadingTitle = "Projet Medusa V57",
    LoadingSubtitle = "Jnkie x Cebo Edit",
    ConfigurationSaving = { Enabled = true, FolderName = "MedusaV57" }
})

-- Onglet Combat
local TabCombat = Window:CreateTab("COMBAT")
TabCombat:CreateSection("Melee Systems")
local TogMelee = TabCombat:CreateToggle({
    Name = "Cebo Melee Aimbot",
    CurrentValue = false,
    Callback = function(v) cfg.meleeAimbot = v if v then startMeleeAimbot() else stopMeleeAimbot() end end
})
TabCombat:CreateKeybind({
    Name = "Keybind Melee",
    CurrentKeybind = "F",
    Callback = function() TogMelee:Set(not cfg.meleeAimbot) end
})

local TogRag = TabCombat:CreateToggle({
    Name = "Anti-Ragdoll V1",
    CurrentValue = false,
    Callback = function(v) if v then startAntiRagdoll() else AntiRagData.Mode = nil end end
})

-- Onglet Farm
local TabFarm = Window:CreateTab("AUTO-FARM")
TabFarm:CreateSection("Pathfinding")
local TogR = TabFarm:CreateToggle({
    Name = "Path: Auto Right",
    CurrentValue = false,
    Callback = function(v) 
        Config.AutoRight = v 
        if v then Config.AutoLeft = false ToggleFunctions.AutoLeft(false) StartAutoWalk("right") end 
    end
})
ToggleFunctions.AutoRight = function(v) TogR:Set(v) end

local TogL = TabFarm:CreateToggle({
    Name = "Path: Auto Left",
    CurrentValue = false,
    Callback = function(v) 
        Config.AutoLeft = v 
        if v then Config.AutoRight = false ToggleFunctions.AutoRight(false) StartAutoWalk("left") end 
    end
})
ToggleFunctions.AutoLeft = function(v) TogL:Set(v) end

-- Onglet Mouvement
local TabMove = Window:CreateTab("MOUVEMENT")
TabMove:CreateSection("Velocity Hacks")
local TogSpd = TabMove:CreateToggle({
    Name = "Speed Hack (57)",
    CurrentValue = false,
    Callback = function(v) cfg.speed = v end
})
TabMove:CreateKeybind({
    Name = "Keybind Speed",
    CurrentKeybind = "Q",
    Callback = function() TogSpd:Set(not cfg.speed) end
})

local TogJump = TabMove:CreateToggle({
    Name = "Original Infinite Jump",
    CurrentValue = false,
    Callback = function(v) cfg.infJump = v end
})

-- Onglet Paramètres & Optimizer
local TabSettings = Window:CreateTab("PARAMÈTRES")
TabSettings:CreateSection("Performance & Visuals")
TabSettings:CreateToggle({
    Name = "MEGA FPS OPTIMIZER",
    CurrentValue = false,
    Callback = function(v) cfg.optimizer = v FullOptimizer(v) end
})
TabSettings:CreateToggle({
    Name = "Base X-Ray",
    CurrentValue = false,
    Callback = function(v) DoXray(v) end
})

-- ────────────────────────────────────────────────────────────────
-- [ 10. BOUTONS FLOTTANTS MOBILE ]
-- ────────────────────────────────────────────────────────────────
local MobileGui = Instance.new("ScreenGui", CoreGui)
MobileGui.Name = "MedusaMobilePanels"

local function NewMobileBtn(name, pos, col, func)
    local b = Instance.new("TextButton", MobileGui)
    b.Size = UDim2.new(0, 90, 0, 45)
    b.Position = pos
    b.BackgroundColor3 = col
    b.Text = name
    b.Font = "GothamBold"
    b.TextColor3 = Color3.new(1,1,1)
    b.Draggable = true
    b.Active = true
    
    local c = Instance.new("UICorner", b)
    c.CornerRadius = UDim.new(0, 10)
    
    local s = Instance.new("UIStroke", b)
    s.Thickness = 2
    s.Color = Color3.new(1,1,1)
    
    b.MouseButton1Click:Connect(func)
    return b
end

NewMobileBtn("BAT AIM", UDim2.new(0.05, 0, 0.4, 0), Color3.fromRGB(150, 0, 0), function() 
    TogMelee:Set(not cfg.meleeAimbot) 
end)

NewBtnAutoR = NewMobileBtn("AUTO R", UDim2.new(0.85, 0, 0.35, 0), Color3.fromRGB(0, 150, 0), function() 
    TogR:Set(not Config.AutoRight) 
end)

NewBtnAutoL = NewMobileBtn("AUTO L", UDim2.new(0.85, 0, 0.45, 0), Color3.fromRGB(0, 100, 200), function() 
    TogL:Set(not Config.AutoLeft) 
end)

-- ────────────────────────────────────────────────────────────────
-- [ 11. BOUCLE FINALE DE RENDU ]
-- ────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    if cfg.speed then
        local r = (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"))
        local h = (lp.Character and lp.Character:FindFirstChildOfClass("Humanoid"))
        if r and h and h.MoveDirection.Magnitude > 0 then
            r.Velocity = Vector3.new(h.MoveDirection.X * cfg.speedValue, r.Velocity.Y, h.MoveDirection.Z * cfg.speedValue)
        end
    end
end)

-- Message de bienvenue
Rayfield:Notify({
    Title = "Medusa V57 Chargé",
    Content = "Script prêt. 600+ lignes actives.",
    Duration = 5
})

Rayfield:LoadConfiguration()
