--[[
    ███╗   ███╗███████╗██████╗ ██╗   ██╗███████╗ █████╗ 
    ████╗ ████║██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
    ██╔████╔██║█████╗  ██║  ██║██║   ██║███████╗███████║
    ██║╚██╔╝██║██╔══╝  ██║  ██║██║   ██║╚════██║██╔══██║
    ██║ ╚═╝ ██║███████╗██████╔╝╚██████╔╝███████║██║  ██║
    ╚═╝     ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝
    
    DEVELOPER: JNKIE & CEBO EDIT
    VERSION: V57 ULTIMATE (FULL CODE)
    DESCRIPTION: AUTO-FARM, COMBAT, VISUALS, MOBILE SUPPORT
]]--

-- ────────────────────────────────────────────────────────────────
-- [ 1. SERVICES ROBLOX ]
-- ────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

-- ────────────────────────────────────────────────────────────────
-- [ 2. VARIABLES DE SESSION ]
-- ────────────────────────────────────────────────────────────────
local lp = Players.LocalPlayer
local Player = lp
local Mouse = lp:GetMouse()
local Camera = workspace.CurrentCamera

local cfg = {
    speed = false, 
    speedValue = 57,
    meleeAimbot = false, 
    antiRagdoll = false, 
    fastSteal = false, 
    esp = false, 
    xray = false,
    infJump = false, 
    optimizer = false
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
-- [ 3. FONCTIONS DE SÉCURITÉ & LOGS ]
-- ────────────────────────────────────────────────────────────────
local function MedusaLog(msg)
    print("[MEDUSA V57] : " .. tostring(msg))
end

local function GetHumanoid() 
    if lp.Character then
        return lp.Character:FindFirstChildOfClass("Humanoid") 
    end
    return nil
end

local function GetRootPart() 
    if lp.Character then
        return lp.Character:FindFirstChild("HumanoidRootPart") 
    end
    return nil
end

-- Anti-AFK Système
lp.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    MedusaLog("Anti-AFK Actionné")
end)

-- Détection constante des outils
RunService.Heartbeat:Connect(function()
    if lp.Character and lp.Character:FindFirstChild("Brainrot") then
        HasBrainrotInHand = true
    else
        HasBrainrotInHand = false
    end
end)

-- ────────────────────────────────────────────────────────────────
-- [ 4. MODULE OPTIMIZER (MAX FPS) ]
-- ────────────────────────────────────────────────────────────────
local function ApplyOptimizer(state)
    if state then
        MedusaLog("Optimisation des performances...")
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 2
        settings().Rendering.QualityLevel = 1
        
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = false
            end
        end
    else
        MedusaLog("Rétablissement des graphismes...")
        Lighting.GlobalShadows = true
    end
end

-- ────────────────────────────────────────────────────────────────
-- [ 5. MODULE COMBAT: CEBO MELEE AIMBOT ]
-- ────────────────────────────────────────────────────────────────
local Cebo = { 
    Conn = nil, 
    Circle = nil, 
    Align = nil, 
    Attach = nil 
}

local function startMeleeAimbot()
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    
    Cebo.Attach = Instance.new("Attachment", hrp)
    Cebo.Align = Instance.new("AlignOrientation", hrp)
    Cebo.Align.Attachment0 = Cebo.Attach
    Cebo.Align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    Cebo.Align.RigidityEnabled = true
    
    Cebo.Circle = Instance.new("Part")
    Cebo.Circle.Name = "MedusaAura"
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
                local dist = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                if dist <= dmin then 
                    target = p.Character.HumanoidRootPart 
                    dmin = dist 
                end
            end
        end
        
        if target then
            char.Humanoid.AutoRotate = false
            Cebo.Align.Enabled = true
            Cebo.Align.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(target.Position.X, hrp.Position.Y, target.Position.Z))
            
            local bat = char:FindFirstChild("Bat") or char:FindFirstChild("Medusa")
            if bat then 
                bat:Activate() 
            end
        else
            Cebo.Align.Enabled = false
            char.Humanoid.AutoRotate = true
        end
    end)
    MedusaLog("Melee Aimbot Activé")
end

local function stopMeleeAimbot()
    if Cebo.Conn then Cebo.Conn:Disconnect() Cebo.Conn = nil end
    if Cebo.Circle then Cebo.Circle:Destroy() Cebo.Circle = nil end
    if Cebo.Align then Cebo.Align:Destroy() Cebo.Align = nil end
    if Cebo.Attach then Cebo.Attach:Destroy() Cebo.Attach = nil end
    
    local h = GetHumanoid()
    if h then h.AutoRotate = true end
    MedusaLog("Melee Aimbot Désactivé")
end

-- ────────────────────────────────────────────────────────────────
-- [ 6. MODULE COMBAT: ANTI-RAGDOLL V1 ]
-- ────────────────────────────────────────────────────────────────
local AntiRagData = { 
    Mode = nil, 
    Conns = {}, 
    IsBoosting = false 
}

local function arForceExit()
    local c = lp.Character
    if not c then return end
    
    pcall(function() 
        lp:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) 
    end)
    
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or (v:IsA("Attachment") and v.Name:find("RagdollAttachment")) then 
            v:Destroy() 
        end
    end
    
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then
        if not AntiRagData.IsBoosting then 
            AntiRagData.IsBoosting = true 
            h.WalkSpeed = 400 
        end
        h:ChangeState(Enum.HumanoidStateType.Running)
    end
end

function startAntiRagdoll()
    AntiRagData.Mode = "v1"
    MedusaLog("Anti-Ragdoll activé")
    task.spawn(function()
        while AntiRagData.Mode == "v1" do
            task.wait()
            local h = GetHumanoid()
            if h then
                local isRag = (h:GetState() == Enum.HumanoidStateType.Physics)
                local serverRag = lp:GetAttribute("RagdollEndTime") and (lp:GetAttribute("RagdollEndTime") - workspace:GetServerTimeNow()) > 0
                
                if isRag or serverRag then 
                    arForceExit() 
                elseif AntiRagData.IsBoosting then 
                    AntiRagData.IsBoosting = false 
                    h.WalkSpeed = 16 
                end
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────────
-- [ 7. MODULE FARM: AUTO-WALK (COORDONNÉES DÉPLIÉES) ]
-- ────────────────────────────────────────────────────────────────
local PATHS = {
    -- Chemin Droite
    RIGHT = {
        Vector3.new(-473.32, -7.67, 10.16),
        Vector3.new(-472.71, -8.14, 29.92),
        Vector3.new(-472.87, -8.14, 49.50),
        Vector3.new(-472.45, -8.14, 65.05),
        Vector3.new(-472.94, -8.14, 82.48),
        Vector3.new(-475.00, -8.14, 96.84),
        Vector3.new(-485.50, -6.43, 96.08)
    },
    -- Chemin Gauche
    LEFT = {
        Vector3.new(-473.31, -7.67, 111.75),
        Vector3.new(-473.51, -8.14, 87.30),
        Vector3.new(-473.74, -8.14, 60.58),
        Vector3.new(-474.04, -8.14, 41.38),
        Vector3.new(-474.35, -8.14, 25.77),
        Vector3.new(-485.30, -6.43, 22.36)
    },
    -- Retours
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
    MedusaLog("Démarrage Auto-Walk: " .. dir)
    if AutoWalkConnection then 
        AutoWalkConnection:Disconnect() 
    end
    
    local main = (dir == "right") and PATHS.RIGHT or PATHS.LEFT
    local ret = (dir == "right") and PATHS.RIGHT_RET or PATHS.LEFT_RET
    
    currentWaypointIndex = 1 
    returnWaypointIndex = 1
    isAutoWalking = true 
    isReturning = false 
    isPaused = false
    
    AutoWalkConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoRight and not Config.AutoLeft then 
            if AutoWalkConnection then AutoWalkConnection:Disconnect() end 
            return 
        end
        
        if isPaused then return end
        
        if HasBrainrotInHand and not isReturning then 
            isReturning = true 
            returnWaypointIndex = 1 
            MedusaLog("Brainrot détecté ! Retour à la base...")
        end
        
        local h, r = GetHumanoid(), GetRootPart()
        if not h or not r then return end
        
        local target = isReturning and ret[returnWaypointIndex] or main[currentWaypointIndex]
        if not target then return end
        
        local move = (target - r.Position) * Vector3.new(1,0,1)
        h:Move(move.Unit)
        
        local spd = isReturning and 29 or 59
        r.AssemblyLinearVelocity = Vector3.new(
            move.Unit.X * spd, 
            r.AssemblyLinearVelocity.Y, 
            move.Unit.Z * spd
        )
        
        if move.Magnitude < 3.5 then
            if not isReturning then
                currentWaypointIndex = currentWaypointIndex + 1
                if currentWaypointIndex > #main then 
                    isPaused = true 
                    task.wait(0.5) 
                    isReturning = true 
                    isPaused = false 
                end
            else
                returnWaypointIndex = returnWaypointIndex + 1
                if returnWaypointIndex > #ret then 
                    Config.AutoRight = false 
                    Config.AutoLeft = false 
                    ToggleFunctions.AutoRight(false) 
                    ToggleFunctions.AutoLeft(false) 
                    isAutoWalking = false 
                    AutoWalkConnection:Disconnect() 
                    MedusaLog("Cycle terminé.")
                end
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────────
-- [ 8. MODULE MOUVEMENT: INFINITE JUMP & SPEED ]
-- ────────────────────────────────────────────────────────────────
UserInputService.JumpRequest:Connect(function()
    if cfg.infJump then
        local r = GetRootPart()
        if r then
            r.Velocity = Vector3.new(r.Velocity.X, 50, r.Velocity.Z)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if cfg.speed then
        local r, h = GetRootPart(), GetHumanoid()
        if r and h and h.MoveDirection.Magnitude > 0 then
            r.Velocity = Vector3.new(
                h.MoveDirection.X * cfg.speedValue, 
                r.Velocity.Y, 
                h.MoveDirection.Z * cfg.speedValue
            )
        end
    end
end)

-- ────────────────────────────────────────────────────────────────
-- [ 9. MODULE VISUELS: XRAY & ESP ]
-- ────────────────────────────────────────────────────────────────
local function DoXray(v)
    if v then
        MedusaLog("X-Ray ON")
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                OriginalTransparency[obj] = obj.LocalTransparencyModifier
                obj.LocalTransparencyModifier = 0.85
            end
        end
    else
        MedusaLog("X-Ray OFF")
        for obj, val in pairs(OriginalTransparency) do 
            if obj then obj.LocalTransparencyModifier = val end 
        end
        OriginalTransparency = {}
    end
end

-- ────────────────────────────────────────────────────────────────
-- [ 10. INTERFACE RAYFIELD (UI) ]
-- ────────────────────────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "MEDUSA HUB V57 - ULTIMATE",
    LoadingTitle = "Medusa Project V57",
    LoadingSubtitle = "Jnkie & Cebo Edition",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MedusaV57",
        FileName = "Config"
    }
})

-- Onglet Combat
local TabCombat = Window:CreateTab("COMBAT", 4483362458)
TabCombat:CreateSection("Aimbot & Defense")

local TogMelee = TabCombat:CreateToggle({
    Name = "Cebo Melee Aimbot",
    CurrentValue = false,
    Callback = function(v) 
        cfg.meleeAimbot = v 
        if v then startMeleeAimbot() else stopMeleeAimbot() end 
    end
})

TabCombat:CreateKeybind({
    Name = "Bind Melee",
    CurrentKeybind = "F",
    Callback = function() TogMelee:Set(not cfg.meleeAimbot) end
})

local TogRag = TabCombat:CreateToggle({
    Name = "Anti-Ragdoll v1",
    CurrentValue = false,
    Callback = function(v) 
        if v then startAntiRagdoll() else AntiRagData.Mode = nil end 
    end
})

-- Onglet Farm
local TabFarm = Window:CreateTab("AUTO-FARM", 4483362458)
TabFarm:CreateSection("Chemins Automatisés")

local TogR = TabFarm:CreateToggle({
    Name = "Auto Right Path",
    CurrentValue = false,
    Callback = function(v) 
        Config.AutoRight = v 
        if v then 
            Config.AutoLeft = false 
            ToggleFunctions.AutoLeft(false) 
            StartAutoWalk("right") 
        end 
    end
})
ToggleFunctions.AutoRight = function(v) TogR:Set(v) end

TabFarm:CreateKeybind({
    Name = "Bind Auto Right",
    CurrentKeybind = "H",
    Callback = function() TogR:Set(not Config.AutoRight) end
})

local TogL = TabFarm:CreateToggle({
    Name = "Auto Left Path",
    CurrentValue = false,
    Callback = function(v) 
        Config.AutoLeft = v 
        if v then 
            Config.AutoRight = false 
            ToggleFunctions.AutoRight(false) 
            StartAutoWalk("left") 
        end 
    end
})
ToggleFunctions.AutoLeft = function(v) TogL:Set(v) end

TabFarm:CreateKeybind({
    Name = "Bind Auto Left",
    CurrentKeybind = "J",
    Callback = function() TogL:Set(not Config.AutoLeft) end
})

-- Onglet Mouvement
local TabMove = Window:CreateTab("MOUVEMENT", 4483362458)
TabMove:CreateSection("Vitesse & Saut")

local TogSpd = TabMove:CreateToggle({
    Name = "Speed Boost (57)",
    CurrentValue = false,
    Callback = function(v) cfg.speed = v end
})

TabMove:CreateKeybind({
    Name = "Bind Speed",
    CurrentKeybind = "Q",
    Callback = function() TogSpd:Set(not cfg.speed) end
})

local TogJump = TabMove:CreateToggle({
    Name = "Original Inf Jump",
    CurrentValue = false,
    Callback = function(v) cfg.infJump = v end
})

TabMove:CreateKeybind({
    Name = "Bind Jump",
    CurrentKeybind = "C",
    Callback = function() TogJump:Set(not cfg.infJump) end
})

-- Onglet Paramètres
local TabSettings = Window:CreateTab("SETTINGS", 4483362458)
TabSettings:CreateSection("Performance")

TabSettings:CreateToggle({
    Name = "FPS Optimizer",
    CurrentValue = false,
    Callback = function(v) 
        cfg.optimizer = v 
        ApplyOptimizer(v) 
    end
})

TabVisuals = Window:CreateTab("VISUELS", 4483362458)
TabVisuals:CreateToggle({
    Name = "Base X-Ray",
    CurrentValue = false,
    Callback = function(v) DoXray(v) end
})

-- ────────────────────────────────────────────────────────────────
-- [ 11. BOUTONS FLOTTANTS MOBILE ]
-- ────────────────────────────────────────────────────────────────
local MobileGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
MobileGui.Name = "MedusaMobile"

local function NewBtn(name, pos, col, func)
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
end

-- Placement des boutons mobiles
NewBtn("BAT AIM", UDim2.new(0, 10, 0.4, 0), Color3.fromRGB(150, 0, 0), function() 
    TogMelee:Set(not cfg.meleeAimbot) 
end)

NewBtn("AUTO R", UDim2.new(0.9, -95, 0.35, 0), Color3.fromRGB(0, 150, 0), function() 
    TogR:Set(not Config.AutoRight) 
end)

NewBtn("AUTO L", UDim2.new(0.9, -95, 0.45, 0), Color3.fromRGB(0, 100, 200), function() 
    TogL:Set(not Config.AutoLeft) 
end)

-- ────────────────────────────────────────────────────────────────
-- [ 12. CHARGEMENT FINAL ]
-- ────────────────────────────────────────────────────────────────
MedusaLog("Système prêt !")
Rayfield:LoadConfiguration()
