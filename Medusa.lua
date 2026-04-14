--[[
    ███╗   ███╗███████╗██████╗ ██╗   ██╗███████╗ █████╗     ██╗  ██╗██╗   ██╗██████╗ 
    ████╗ ████║██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗    ██║  ██║██║   ██║██╔══██╗
    ██╔████╔██║█████╗  ██║  ██║██║   ██║███████╗███████║    ███████║██║   ██║██████╔╝
    ██║╚██╔╝██║██╔══╝  ██║  ██║██║   ██║╚════██║██╔══██║    ██╔══██║██║   ██║██╔══██╗
    ██║ ╚═╝ ██║███████╗██████╔╝╚██████╔╝███████║██║  ██║    ██║  ██║╚██████╔╝██████╔╝
    ╚═╝     ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ 
    
    VERSION: V57 - EXTENDED
    MODULES: CEBO, ANTI-RAGDOLL, AUTO-WALK, XRAY, MOBILE PANELS
    DEVELOPER: JNKIE & CEBO EDIT
]]--

-- ─── [ 1. SERVICES SYSTEME ] ───
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- ─── [ 2. VARIABLES GLOBALES & CONFIG ] ───
local LocalPlayer = Players.LocalPlayer
local Player = LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local Config = {
    -- Combat
    MeleeAimbot = false,
    AntiRagdoll = false,
    InstantSteal = false,
    
    -- Mouvement
    SpeedBoost = false,
    SpeedValue = 57,
    InfJump = false,
    
    -- Farm
    AutoRight = false,
    AutoLeft = false,
    
    -- Visuels
    ESP_Enabled = false,
    XRay_Enabled = false,
    Optimizer = false,
    
    -- Mobile
    PanelsVisible = true
}

-- État interne de l'Auto-Walk
local AutoWalkData = {
    Connection = nil,
    IsWalking = false,
    IsReturning = false,
    IsPaused = false,
    CurrentIndex = 1,
    ReturnIndex = 1,
    HasBrainrot = false
}

local ToggleFunctions = {}
local OriginalTransparency = {}

-- ─── [ 3. SYSTEME DE PROTECTION ANTI-AFK ] ───
local VirtualUser = game:GetService("VirtualUser")
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ─── [ 4. FONCTIONS UTILITAIRES ] ───
local function GetHumanoid()
    return Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
end

local function GetRoot()
    return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
end

local function Notify(title, text)
    Rayfield:Notify({
        Title = title,
        Content = text,
        Duration = 3,
        Image = 4483362458
    })
end

-- ─── [ 5. MODULE: CEBO MELEE AIMBOT (ORIGINAL) ] ───
local CeboStore = {
    Conn = nil,
    Circle = nil,
    Align = nil,
    Attach = nil
}

local function StartMeleeAimbot()
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    
    CeboStore.Attach = Instance.new("Attachment", hrp)
    CeboStore.Align = Instance.new("AlignOrientation", hrp)
    CeboStore.Align.Attachment0 = CeboStore.Attach
    CeboStore.Align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    CeboStore.Align.RigidityEnabled = true
    
    CeboStore.Circle = Instance.new("Part")
    CeboStore.Circle.Name = "CeboCircle"
    CeboStore.Circle.Shape = Enum.PartType.Cylinder
    CeboStore.Circle.Material = Enum.Material.Neon
    CeboStore.Circle.Size = Vector3.new(0.05, 14.5, 14.5)
    CeboStore.Circle.Color = Color3.new(1, 0, 0)
    CeboStore.Circle.CanCollide = false
    CeboStore.Circle.Massless = true
    CeboStore.Circle.Parent = workspace
    
    local weld = Instance.new("Weld")
    weld.Part0 = hrp
    weld.Part1 = CeboStore.Circle
    weld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90))
    weld.Parent = CeboStore.Circle
    
    CeboStore.Conn = RunService.RenderStepped:Connect(function()
        local target = nil
        local dmin = 7.25
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                if d <= dmin then
                    target = p.Character.HumanoidRootPart
                    dmin = d
                end
            end
        end
        
        if target then
            char.Humanoid.AutoRotate = false
            CeboStore.Align.Enabled = true
            CeboStore.Align.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(target.Position.X, hrp.Position.Y, target.Position.Z))
            
            local tool = char:FindFirstChild("Bat") or char:FindFirstChild("Medusa")
            if tool then tool:Activate() end
        else
            CeboStore.Align.Enabled = false
            char.Humanoid.AutoRotate = true
        end
    end)
end

local function StopMeleeAimbot()
    if CeboStore.Conn then CeboStore.Conn:Disconnect() CeboStore.Conn = nil end
    if CeboStore.Circle then CeboStore.Circle:Destroy() CeboStore.Circle = nil end
    if CeboStore.Align then CeboStore.Align:Destroy() CeboStore.Align = nil end
    if CeboStore.Attach then CeboStore.Attach:Destroy() CeboStore.Attach = nil end
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.AutoRotate = true
    end
end

-- ─── [ 6. MODULE: ANTI-RAGDOLL V1 (ORIGINAL) ] ───
local AntiRagData = {
    Mode = nil,
    Conns = {},
    Cache = {},
    IsBoosting = false,
    BoostSpeed = 400,
    NormalSpeed = 16
}

local function CacheChar()
    local char = Player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    AntiRagData.Cache = {character = char, humanoid = hum, root = root}
    return true
end

local function ForceExitRagdoll()
    if not AntiRagData.Cache.humanoid then return end
    pcall(function()
        Player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    for _, v in ipairs(AntiRagData.Cache.character:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or (v:IsA("Attachment") and v.Name:find("RagdollAttachment")) then
            v:Destroy()
        end
    end
    if not AntiRagData.IsBoosting then
        AntiRagData.IsBoosting = true
        AntiRagData.Cache.humanoid.WalkSpeed = AntiRagData.BoostSpeed
    end
    if AntiRagData.Cache.humanoid.Health > 0 then
        AntiRagData.Cache.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    AntiRagData.Cache.root.Anchored = false
end

local function StartAntiRagdoll()
    if AntiRagData.Mode == "v1" then return end
    if not CacheChar() then return end
    AntiRagData.Mode = "v1"
    
    local c1 = RunService.RenderStepped:Connect(function()
        if workspace.CurrentCamera and AntiRagData.Cache.humanoid then
            workspace.CurrentCamera.CameraSubject = AntiRagData.Cache.humanoid
        end
    end)
    table.insert(AntiRagData.Conns, c1)
    
    task.spawn(function()
        while AntiRagData.Mode == "v1" do
            task.wait()
            if CacheChar() then
                local isRag = false
                local st = AntiRagData.Cache.humanoid:GetState()
                if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then isRag = true end
                if Player:GetAttribute("RagdollEndTime") and (Player:GetAttribute("RagdollEndTime") - workspace:GetServerTimeNow()) > 0 then isRag = true end
                
                if isRag then
                    ForceExitRagdoll()
                elseif AntiRagData.IsBoosting then
                    AntiRagData.IsBoosting = false
                    AntiRagData.Cache.humanoid.WalkSpeed = AntiRagData.NormalSpeed
                end
            end
        end
    end)
end

local function StopAntiRagdoll()
    AntiRagData.Mode = nil
    for _, c in ipairs(AntiRagData.Conns) do c:Disconnect() end
    AntiRagData.Conns = {}
    if AntiRagData.IsBoosting and AntiRagData.Cache.humanoid then
        AntiRagData.Cache.humanoid.WalkSpeed = AntiRagData.NormalSpeed
    end
end

-- ─── [ 7. MODULE: AUTO-WALK (COORDONNÉES MOT POUR MOT) ] ───
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

local function StopAutoWalk()
    if AutoWalkData.Connection then AutoWalkData.Connection:Disconnect() end
    AutoWalkData.IsWalking = false
    AutoWalkData.IsReturning = false
    AutoWalkData.IsPaused = false
    local h = GetHumanoid()
    if h then h:Move(Vector3.new(0,0,0)) end
end

local function StartAutoWalk(dir)
    StopAutoWalk()
    local mainPath = (dir == "right") and PATHS.RIGHT or PATHS.LEFT
    local retPath = (dir == "right") and PATHS.RIGHT_RET or PATHS.LEFT_RET
    
    AutoWalkData.CurrentIndex = 1
    AutoWalkData.ReturnIndex = 1
    AutoWalkData.IsWalking = true
    
    AutoWalkData.Connection = RunService.Heartbeat:Connect(function()
        if not Config.AutoRight and not Config.AutoLeft then StopAutoWalk() return end
        if AutoWalkData.IsPaused then return end
        
        -- Détection Brainrot
        if Player.Character and Player.Character:FindFirstChild("Brainrot") then
            AutoWalkData.IsReturning = true
        end
        
        local h = GetHumanoid()
        local r = GetRoot()
        if not h or not r then return end
        
        local target = AutoWalkData.IsReturning and retPath[AutoWalkData.ReturnIndex] or mainPath[AutoWalkData.CurrentIndex]
        if not target then return end
        
        local moveVec = (target - r.Position) * Vector3.new(1,0,1)
        h:Move(moveVec.Unit)
        
        local spd = AutoWalkData.IsReturning and PATHS.RETURN_SPEED or PATHS.FORWARD_SPEED
        r.AssemblyLinearVelocity = Vector3.new(moveVec.Unit.X * spd, r.AssemblyLinearVelocity.Y, moveVec.Unit.Z * spd)
        
        if moveVec.Magnitude < 3.5 then
            if not AutoWalkData.IsReturning then
                AutoWalkData.CurrentIndex = AutoWalkData.CurrentIndex + 1
                if AutoWalkData.CurrentIndex > #mainPath then
                    AutoWalkData.IsPaused = true
                    task.wait(0.5)
                    AutoWalkData.IsReturning = true
                    AutoWalkData.IsPaused = false
                end
            else
                AutoWalkData.ReturnIndex = AutoWalkData.ReturnIndex + 1
                if AutoWalkData.ReturnIndex > #retPath then
                    Config.AutoRight = false
                    Config.AutoLeft = false
                    ToggleFunctions.AutoRight(false)
                    ToggleFunctions.AutoLeft(false)
                    StopAutoWalk()
                end
            end
        end
    end)
end

-- ─── [ 8. MODULE: VISUELS (XRAY & ESP) ] ───
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

local function CreateESP(p)
    if not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = p.Character.HumanoidRootPart
    if hrp:FindFirstChild("MedusaESP") then return end
    
    local gui = Instance.new("BillboardGui", hrp)
    gui.Name = "MedusaESP"
    gui.AlwaysOnTop = true
    gui.Size = UDim2.new(4,0,5,0)
    
    local f = Instance.new("Frame", gui)
    f.Size = UDim2.new(1,0,1,0)
    f.BackgroundTransparency = 0.8
    f.BackgroundColor3 = Color3.fromRGB(255, 0, 150)
    
    local s = Instance.new("UIStroke", f)
    s.Color = Color3.new(1,1,1)
    s.Thickness = 1.5
    
    local t = Instance.new("TextLabel", gui)
    t.Size = UDim2.new(1,0,0.2,0)
    t.Position = UDim2.new(0,0,-0.3,0)
    t.BackgroundTransparency = 1
    t.Text = p.Name
    t.TextColor3 = Color3.new(1,1,1)
    t.Font = "GothamBold"
    t.TextSize = 11
end

-- ─── [ 9. INTERFACE RAYFIELD ] ───
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "MEDUSA HUB V57 - ULTIMATE",
    LoadingTitle = "Initialisation Medusa...",
    LoadingSubtitle = "Jnkie x Cebo x Extended",
    ConfigurationSaving = { Enabled = true, FolderName = "MedusaConfig" }
})

local TabCombat = Window:CreateTab("COMBAT", 4483362458)
local TabFarm = Window:CreateTab("AUTO-FARM", 4483362458)
local TabMove = Window:CreateTab("MOUVEMENT", 4483362458)
local TabVisuals = Window:CreateTab("VISUELS", 4483362458)
local TabSettings = Window:CreateTab("SETTINGS", 4483362458)

-- Section Combat
TabCombat:CreateSection("Melee Systems")
local TogAimbot = TabCombat:CreateToggle({
    Name = "Cebo Melee Aimbot",
    CurrentValue = false,
    Callback = function(v)
        Config.MeleeAimbot = v
        if v then StartMeleeAimbot() else StopMeleeAimbot() end
    end
})
TabCombat:CreateKeybind({
    Name = "Bind Melee",
    CurrentKeybind = "F",
    Callback = function() TogAimbot:Set(not Config.MeleeAimbot) end
})

local TogRag = TabCombat:CreateToggle({
    Name = "Anti-Ragdoll v1",
    CurrentValue = false,
    Callback = function(v)
        Config.AntiRagdoll = v
        if v then StartAntiRagdoll() else StopAntiRagdoll() end
    end
})
TabCombat:CreateKeybind({
    Name = "Bind Anti-Ragdoll",
    CurrentKeybind = "G",
    Callback = function() TogRag:Set(not Config.AntiRagdoll) end
})

-- Section Farm
TabFarm:CreateSection("Auto-Walk Paths")
local TogRight = TabFarm:CreateToggle({
    Name = "Path: Right Side",
    CurrentValue = false,
    Callback = function(v)
        Config.AutoRight = v
        if v then 
            Config.AutoLeft = false
            ToggleFunctions.AutoLeft(false)
            StartAutoWalk("right") 
        else 
            StopAutoWalk() 
        end
    end
})
ToggleFunctions.AutoRight = function(v) TogRight:Set(v) end

local TogLeft = TabFarm:CreateToggle({
    Name = "Path: Left Side",
    CurrentValue = false,
    Callback = function(v)
        Config.AutoLeft = v
        if v then 
            Config.AutoRight = false
            ToggleFunctions.AutoRight(false)
            StartAutoWalk("left") 
        else 
            StopAutoWalk() 
        end
    end
})
ToggleFunctions.AutoLeft = function(v) TogLeft:Set(v) end

-- Section Mouvement
TabMove:CreateSection("Physics Modification")
local TogSpeed = TabMove:CreateToggle({
    Name = "Speed Boost (57)",
    CurrentValue = false,
    Callback = function(v) Config.SpeedBoost = v end
})
TabMove:CreateKeybind({
    Name = "Bind Speed",
    CurrentKeybind = "Q",
    Callback = function() TogSpeed:Set(not Config.SpeedBoost) end
})

TabMove:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Callback = function(v) Config.InfJump = v end
})

-- Section Visuels
TabVisuals:CreateSection("Rendering")
TabVisuals:CreateToggle({
    Name = "Base X-Ray",
    CurrentValue = false,
    Callback = function(v) DoXray(v) end
})
TabVisuals:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Callback = function(v) Config.ESP_Enabled = v end
})

-- ─── [ 10. MOBILE FLOATING PANELS ] ───
local MobileGui = Instance.new("ScreenGui", CoreGui)
MobileGui.Name = "MedusaMobile"

local function NewMobileBtn(txt, pos, color, func)
    local b = Instance.new("TextButton", MobileGui)
    b.Size = UDim2.new(0, 90, 0, 45)
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = txt
    b.Font = "GothamBold"
    b.TextColor3 = Color3.new(1,1,1)
    b.TextSize = 12
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
    TogAimbot:Set(not Config.MeleeAimbot)
end)

NewMobileBtn("AUTO R", UDim2.new(0.85, 0, 0.35, 0), Color3.fromRGB(0, 150, 0), function()
    TogRight:Set(not Config.AutoRight)
end)

NewMobileBtn("AUTO L", UDim2.new(0.85, 0, 0.45, 0), Color3.fromRGB(0, 100, 200), function()
    TogLeft:Set(not Config.AutoLeft)
end)

-- ─── [ 11. BOUCLE PRINCIPALE (OPTIMISÉE) ] ───
RunService.Heartbeat:Connect(function()
    -- Speed Logic
    if Config.SpeedBoost then
        local r = GetRoot()
        local h = GetHumanoid()
        if r and h and h.MoveDirection.Magnitude > 0 then
            r.Velocity = Vector3.new(h.MoveDirection.X * Config.SpeedValue, r.Velocity.Y, h.MoveDirection.Z * Config.SpeedValue)
        end
    end
end)

-- ESP & Fast Steal Loop
task.spawn(function()
    while task.wait(0.5) do
        if Config.ESP_Enabled then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= Player then CreateESP(p) end
            end
        else
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local e = p.Character.HumanoidRootPart:FindFirstChild("MedusaESP")
                    if e then e:Destroy() end
                end
            end
        end
        
        if Config.InstantSteal then
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") then v.HoldDuration = 0 end
            end
        end
    end
end)

-- Inf Jump Logic
UserInputService.JumpRequest:Connect(function()
    if Config.InfJump then
        local h = GetHumanoid()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Message de bienvenue
Notify("Medusa V57 Load", "Script activé avec succès ! Bon jeu.")
Rayfield:LoadConfiguration()
