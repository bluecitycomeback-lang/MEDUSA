-- [[ MEDUSA HUB V57 - OMAGAD UI EDITION ]] --

local lp = game:GetService("Players").LocalPlayer
local Player = lp
local LocalPlayer = lp
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

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
    timerEsp = false,
    antiTrap = false,
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
local antiTrapConnection = nil

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
end)
attachSpeedDisplay()

-- [ 2. FONCTIONS UTILITAIRES ] --
local function GetHumanoid() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end
local function GetRootPart() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end

RunService.Heartbeat:Connect(function()
    if lp.Character and lp.Character:FindFirstChild("Brainrot") then
        HasBrainrotInHand = true
    else
        HasBrainrotInHand = false
    end
end)

-- [ 3. NETTOYAGE UI ] --
for _, v in pairs(lp.PlayerGui:GetChildren()) do
    if v.Name == "MedusaHubUI" or v.Name == "MedusaStatsUI" then v:Destroy() end
end

-- =============================================
-- [ 4. NOUVELLE INTERFACE STYLE OMAGAD HUB ] --
-- =============================================

local MedusaGui = Instance.new("ScreenGui")
MedusaGui.Name = "MedusaHubUI"
MedusaGui.ResetOnSpawn = false
MedusaGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MedusaGui.DisplayOrder = 999
MedusaGui.Parent = CoreGui

-- Couleurs thème
local COL_BG        = Color3.fromRGB(28, 25, 40)
local COL_BG2       = Color3.fromRGB(38, 34, 55)
local COL_ACCENT    = Color3.fromRGB(120, 90, 200)
local COL_ACCENT2   = Color3.fromRGB(150, 110, 230)
local COL_TAB_ACT   = Color3.fromRGB(120, 90, 200)
local COL_TAB_INACT = Color3.fromRGB(48, 44, 65)
local COL_TEXT      = Color3.fromRGB(230, 225, 255)
local COL_SUBTEXT   = Color3.fromRGB(160, 150, 190)
local COL_TOGGLE_ON = Color3.fromRGB(120, 90, 200)
local COL_TOGGLE_OFF= Color3.fromRGB(65, 60, 85)
local COL_PANEL     = Color3.fromRGB(32, 28, 48)
local COL_PANEL_HDR = Color3.fromRGB(22, 18, 35)
local COL_BTN       = Color3.fromRGB(55, 50, 80)
local COL_BTN_RED   = Color3.fromRGB(160, 40, 40)

-- [ DRAG FUNCTION ] --
local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- [ TOGGLE COMPONENT ] --
local function CreateToggle(parent, yPos, label, initVal, callback)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -16, 0, 30)
    row.Position = UDim2.new(0, 8, 0, yPos)
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -52, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COL_TEXT
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0, 44, 0, 22)
    track.Position = UDim2.new(1, -44, 0.5, -11)
    track.BackgroundColor3 = initVal and COL_TOGGLE_ON or COL_TOGGLE_OFF
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = initVal
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        state = not state
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
        TweenService:Create(track, tweenInfo, {BackgroundColor3 = state and COL_TOGGLE_ON or COL_TOGGLE_OFF}):Play()
        TweenService:Create(knob, tweenInfo, {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
        if callback then callback(state) end
    end)

    return function(val)
        state = val
        track.BackgroundColor3 = val and COL_TOGGLE_ON or COL_TOGGLE_OFF
        knob.Position = val and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    end
end

-- [ SEPARATOR ] --
local function CreateSeparator(parent, yPos, label)
    if label then
        local lbl = Instance.new("TextLabel", parent)
        lbl.Size = UDim2.new(1, -16, 0, 20)
        lbl.Position = UDim2.new(0, 8, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = COL_SUBTEXT
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
    end
    local line = Instance.new("Frame", parent)
    line.Size = UDim2.new(1, -16, 0, 1)
    line.Position = UDim2.new(0, 8, 0, yPos + (label and 18 or 0))
    line.BackgroundColor3 = Color3.fromRGB(60, 55, 80)
    line.BorderSizePixel = 0
    return label and yPos + 19 or yPos + 1
end

-- ─────────────────────────────────────────
-- FENÊTRE PRINCIPALE (style omagad)
-- ─────────────────────────────────────────
local MainWindow = Instance.new("Frame", MedusaGui)
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 230, 0, 370)
MainWindow.Position = UDim2.new(0.5, -115, 0.5, -185)
MainWindow.BackgroundColor3 = COL_BG
MainWindow.BorderSizePixel = 0
MainWindow.Active = true
Instance.new("UICorner", MainWindow).CornerRadius = UDim.new(0, 8)
local mwStroke = Instance.new("UIStroke", MainWindow)
mwStroke.Color = COL_ACCENT
mwStroke.Thickness = 1.5

-- Header
local Header = Instance.new("Frame", MainWindow)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = COL_PANEL_HDR
Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)
-- Masque bas header
local HeaderMask = Instance.new("Frame", Header)
HeaderMask.Size = UDim2.new(1, 0, 0, 8)
HeaderMask.Position = UDim2.new(0, 0, 1, -8)
HeaderMask.BackgroundColor3 = COL_PANEL_HDR
HeaderMask.BorderSizePixel = 0

local TitleLabel = Instance.new("TextLabel", Header)
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "medusa hub"
TitleLabel.TextColor3 = COL_TEXT
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

-- FPS/PING display in header
local StatsLabel = Instance.new("TextLabel", Header)
StatsLabel.Size = UDim2.new(0, 120, 1, 0)
StatsLabel.Position = UDim2.new(1, -125, 0, 0)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = "FPS: -- PING: --ms"
StatsLabel.TextColor3 = COL_SUBTEXT
StatsLabel.Font = Enum.Font.Gotham
StatsLabel.TextSize = 10
StatsLabel.TextXAlignment = Enum.TextXAlignment.Right

MakeDraggable(MainWindow, Header)

-- Close button
local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0.5, -12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)
CloseBtn.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
end)

-- TAB BAR
local TabBar = Instance.new("Frame", MainWindow)
TabBar.Size = UDim2.new(1, -16, 0, 28)
TabBar.Position = UDim2.new(0, 8, 0, 46)
TabBar.BackgroundTransparency = 1

local tabNames = {"Main", "Visual"}
local tabPages = {}
local tabBtns = {}
local currentTab = "Main"

local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 4)

-- Content area
local ContentArea = Instance.new("Frame", MainWindow)
ContentArea.Size = UDim2.new(1, 0, 1, -82)
ContentArea.Position = UDim2.new(0, 0, 0, 82)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true

local function CreatePage(name)
    local page = Instance.new("ScrollingFrame", ContentArea)
    page.Name = name.."Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = COL_ACCENT
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    tabPages[name] = page
    return page
end

local function SwitchTab(name)
    currentTab = name
    for n, page in pairs(tabPages) do
        page.Visible = (n == name)
    end
    for n, btn in pairs(tabBtns) do
        btn.BackgroundColor3 = (n == name) and COL_TAB_ACT or COL_TAB_INACT
        btn.TextColor3 = (n == name) and Color3.new(1,1,1) or COL_SUBTEXT
    end
end

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(0, 100, 1, 0)
    btn.BackgroundColor3 = (i == 1) and COL_TAB_ACT or COL_TAB_INACT
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = (i == 1) and Color3.new(1,1,1) or COL_SUBTEXT
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.LayoutOrder = i
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabBtns[name] = btn
    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
end

-- ─────────────────────────────────────────
-- PAGE MAIN
-- ─────────────────────────────────────────
local MainPage = CreatePage("Main")
MainPage.Visible = true
local mainY = 6

-- Section: Stealing
mainY = CreateSeparator(MainPage, mainY, "Stealing")
mainY = mainY + 4

local setFastSteal = CreateToggle(MainPage, mainY, "Auto Steal (New)", false, function(v)
    cfg.fastSteal = v
end)
mainY = mainY + 34

local setIS = CreateToggle(MainPage, mainY, "Instant Steal", false, function(v)
    cfg.fastSteal = v
    if v then
        for _, vv in pairs(workspace:GetDescendants()) do
            if vv:IsA("ProximityPrompt") then vv.HoldDuration = 0 end
        end
    end
end)
mainY = mainY + 34

local setUnlockBase = CreateToggle(MainPage, mainY, "Unlock Base", true, function(v) end)
mainY = mainY + 38

-- Section: Combat
mainY = CreateSeparator(MainPage, mainY, "Combat")
mainY = mainY + 4

local setBatAim; setBatAim = CreateToggle(MainPage, mainY, "Bat Aimbot", false, function(v)
    Enabled.BatAimbot = v
    if v then startBatAimbot() else stopBatAimbot() end
end)
mainY = mainY + 34

local setAntiRag = CreateToggle(MainPage, mainY, "Anti-Ragdoll v1", false, function(v)
    cfg.antiRagdoll = v
    if v then startAntiRagdoll() else stopAntiRagdoll() end
end)
mainY = mainY + 34

local setAntiTrap = CreateToggle(MainPage, mainY, "Anti-Trap", false, function(v)
    cfg.antiTrap = v
    if v then
        antiTrapConnection = RunService.Heartbeat:Connect(function()
            local trap = Workspace:FindFirstChild("Trap")
            if trap and trap:IsA("Model") then trap:Destroy() end
        end)
    else
        if antiTrapConnection then antiTrapConnection:Disconnect(); antiTrapConnection = nil end
    end
end)
mainY = mainY + 38

-- Section: Movement
mainY = CreateSeparator(MainPage, mainY, "Movement")
mainY = mainY + 4

local setSpeed = CreateToggle(MainPage, mainY, "Speed Boost (57)", false, function(v) cfg.speed = v end)
mainY = mainY + 34

local setInfJump = CreateToggle(MainPage, mainY, "Infinite Jump", false, function(v) cfg.infJump = v end)
mainY = mainY + 34

-- Section: Server
mainY = CreateSeparator(MainPage, mainY, "Server")
mainY = mainY + 10

local function CreateButton(parent, yPos, label, col, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -16, 0, 28)
    btn.Position = UDim2.new(0, 8, 0, yPos)
    btn.BackgroundColor3 = col or COL_BTN
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    if callback then btn.MouseButton1Click:Connect(callback) end
    return btn
end

CreateButton(MainPage, mainY, "Rejoin Server", COL_BTN, function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)
mainY = mainY + 33

CreateButton(MainPage, mainY, "Kick Self", COL_BTN, function()
    LocalPlayer:Kick("Kicked via Medusa Hub")
end)
mainY = mainY + 33

CreateButton(MainPage, mainY, "Force Reset", COL_BTN_RED, function()
    local h = GetHumanoid()
    if h then h.Health = 0 end
end)
mainY = mainY + 10

MainPage.CanvasSize = UDim2.new(0, 0, 0, mainY + 10)

-- ─────────────────────────────────────────
-- PAGE VISUAL
-- ─────────────────────────────────────────
local VisualPage = CreatePage("Visual")
local visY = 6

visY = CreateSeparator(VisualPage, visY, "ESP")
visY = visY + 4

local setESP = CreateToggle(VisualPage, visY, "Friend Allow ESP", false, function(v) cfg.esp = v end)
visY = visY + 34

local setXray = CreateToggle(VisualPage, visY, "Xray", false, function(v)
    cfg.xray = v
    if v then enableXRay() else disableXRay() end
end)
visY = visY + 34

local setTimerESP = CreateToggle(VisualPage, visY, "Timer ESP (Purchase)", false, function(v) cfg.timerEsp = v end)
visY = visY + 38

visY = CreateSeparator(VisualPage, visY, "Effects")
visY = visY + 4

local setDarkMode = CreateToggle(VisualPage, visY, "Dark Mode", false, function(v)
    Lighting.Brightness = v and 0.1 or 2
    Lighting.ClockTime = v and 0 or 14
end)
visY = visY + 34

local setDeleteAnim = CreateToggle(VisualPage, visY, "Delete Animations", false, function(v)
    if v and lp.Character then
        local anim = lp.Character:FindFirstChildOfClass("Humanoid")
        if anim then
            for _, a in pairs(anim:GetPlayingAnimationTracks()) do a:Stop() end
        end
    end
end)
visY = visY + 34

local setOpt = CreateToggle(VisualPage, visY, "FPS Booster (Optimizer)", false, function(v)
    cfg.optimizer = v
    ApplyOptimizer(v)
end)
visY = visY + 10

VisualPage.CanvasSize = UDim2.new(0, 0, 0, visY + 10)

-- =============================================
-- PANELS FLOTTANTS STYLE OMAGAD (DROITE)
-- =============================================

local function CreateFloatingPanel(title, xOffset, yOffset, width, height)
    local panel = Instance.new("Frame", MedusaGui)
    panel.Size = UDim2.new(0, width, 0, height)
    panel.Position = UDim2.new(1, xOffset, 0, yOffset)
    panel.BackgroundColor3 = COL_PANEL
    panel.BorderSizePixel = 0
    panel.Active = true
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 7)
    local stroke = Instance.new("UIStroke", panel)
    stroke.Color = COL_ACCENT
    stroke.Thickness = 1

    local hdr = Instance.new("Frame", panel)
    hdr.Size = UDim2.new(1, 0, 0, 28)
    hdr.BackgroundColor3 = COL_PANEL_HDR
    hdr.BorderSizePixel = 0
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 7)
    local hdrMask = Instance.new("Frame", hdr)
    hdrMask.Size = UDim2.new(1, 0, 0, 7)
    hdrMask.Position = UDim2.new(0, 0, 1, -7)
    hdrMask.BackgroundColor3 = COL_PANEL_HDR
    hdrMask.BorderSizePixel = 0

    local titleLbl = Instance.new("TextLabel", hdr)
    titleLbl.Size = UDim2.new(1, -10, 1, 0)
    titleLbl.Position = UDim2.new(0, 8, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = COL_TEXT
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local content = Instance.new("Frame", panel)
    content.Size = UDim2.new(1, 0, 1, -28)
    content.Position = UDim2.new(0, 0, 0, 28)
    content.BackgroundTransparency = 1

    MakeDraggable(panel, hdr)
    return panel, content
end

-- Panel: Auto Farm
local farmPanel, farmContent = CreateFloatingPanel("Auto Farm", -155, 50, 145, 110)

local function PanelToggle(parent, yPos, label, initVal, callback)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -12, 0, 28)
    row.Position = UDim2.new(0, 6, 0, yPos)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -46, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COL_TEXT
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0, 38, 0, 20)
    track.Position = UDim2.new(1, -38, 0.5, -10)
    track.BackgroundColor3 = initVal and COL_TOGGLE_ON or COL_TOGGLE_OFF
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = initVal and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local state = initVal
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = state and COL_TOGGLE_ON or COL_TOGGLE_OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}):Play()
        if callback then callback(state) end
    end)
    return function(v)
        state = v
        track.BackgroundColor3 = v and COL_TOGGLE_ON or COL_TOGGLE_OFF
        knob.Position = v and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    end
end

local updateRightPanel = PanelToggle(farmContent, 4, "Auto Right", false, function(v) ToggleAutoRight(v) end)
local updateLeftPanel  = PanelToggle(farmContent, 34, "Auto Left", false, function(v) ToggleAutoLeft(v) end)

-- Panel: Booster (right side)
local boosterPanel, boosterContent = CreateFloatingPanel("Booster", -155, 175, 145, 120)

local walkSpeedLabel = Instance.new("TextLabel", boosterContent)
walkSpeedLabel.Size = UDim2.new(1, -12, 0, 18)
walkSpeedLabel.Position = UDim2.new(0, 6, 0, 4)
walkSpeedLabel.BackgroundTransparency = 1
walkSpeedLabel.Text = "Walk Speed  59"
walkSpeedLabel.TextColor3 = COL_TEXT
walkSpeedLabel.Font = Enum.Font.Gotham
walkSpeedLabel.TextSize = 11
walkSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left

local setSpeedPanel = PanelToggle(boosterContent, 24, "Walk Speed", false, function(v) cfg.speed = v end)
local setStealPanel = PanelToggle(boosterContent, 54, "Steal Speed", false, function(v) cfg.fastSteal = v end)

-- Panel: Instant Steal V2
local stealPanel, stealContent = CreateFloatingPanel("Instant Steal V2", -155, 310, 145, 120)

local setGiantPotion = PanelToggle(stealContent, 4, "Giant Potion", false, function(v) end)

local actBtn = Instance.new("TextButton", stealContent)
actBtn.Size = UDim2.new(1, -12, 0, 26)
actBtn.Position = UDim2.new(0, 6, 0, 34)
actBtn.BackgroundColor3 = COL_BTN
actBtn.BorderSizePixel = 0
actBtn.Text = "Activate (Reset)"
actBtn.TextColor3 = Color3.new(1,1,1)
actBtn.Font = Enum.Font.GothamBold
actBtn.TextSize = 11
Instance.new("UICorner", actBtn).CornerRadius = UDim.new(0, 5)

local execBtn = Instance.new("TextButton", stealContent)
execBtn.Size = UDim2.new(1, -12, 0, 26)
execBtn.Position = UDim2.new(0, 6, 0, 64)
execBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 160)
execBtn.BorderSizePixel = 0
execBtn.Text = "Execute (F)"
execBtn.TextColor3 = Color3.new(1,1,1)
execBtn.Font = Enum.Font.GothamBold
execBtn.TextSize = 11
Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0, 5)
execBtn.MouseButton1Click:Connect(function()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then v.HoldDuration = 0 end
    end
end)

-- Panel: Base Prot
local baseProtPanel, baseProtContent = CreateFloatingPanel("Base Prot", -155, 445, 145, 110)

local apSpam = Instance.new("TextButton", baseProtContent)
apSpam.Size = UDim2.new(1, -12, 0, 26)
apSpam.Position = UDim2.new(0, 6, 0, 4)
apSpam.BackgroundColor3 = COL_BTN
apSpam.BorderSizePixel = 0
apSpam.Text = "AP Spam Nearest [Q]"
apSpam.TextColor3 = Color3.new(1,1,1)
apSpam.Font = Enum.Font.Gotham
apSpam.TextSize = 10
Instance.new("UICorner", apSpam).CornerRadius = UDim.new(0, 5)

local instaReset = Instance.new("TextButton", baseProtContent)
instaReset.Size = UDim2.new(1, -12, 0, 26)
instaReset.Position = UDim2.new(0, 6, 0, 34)
instaReset.BackgroundColor3 = COL_BTN_RED
instaReset.BorderSizePixel = 0
instaReset.Text = "Insta Reset [R]"
instaReset.TextColor3 = Color3.new(1,1,1)
instaReset.Font = Enum.Font.Gotham
instaReset.TextSize = 10
Instance.new("UICorner", instaReset).CornerRadius = UDim.new(0, 5)
instaReset.MouseButton1Click:Connect(function()
    local h = GetHumanoid(); if h then h.Health = 0 end
end)

local setSpamSteal = PanelToggle(baseProtContent, 64, "Spam If Stealing", false, function(v) end)

-- =============================================
-- TOGGLE HUB (KeyBind K)
-- =============================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.K then
        MainWindow.Visible = not MainWindow.Visible
    end
end)

-- =============================================
-- [ FONCTIONS CORE (inchangées) ] --
-- =============================================

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

function startBatAimbot()
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

function stopBatAimbot()
    if Connections.batAimbot then Connections.batAimbot:Disconnect(); Connections.batAimbot = nil end
end

-- ANTI RAGDOLL
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
    for _, conn in ipairs(ragdollConnections) do pcall(function() conn:Disconnect() end) end
    ragdollConnections = {}
end

local function arIsRagdolled()
    if not cachedCharData.humanoid then return false end
    local state = cachedCharData.humanoid:GetState()
    local ragdollStates = {[Enum.HumanoidStateType.Physics]=true,[Enum.HumanoidStateType.Ragdoll]=true,[Enum.HumanoidStateType.FallingDown]=true}
    if ragdollStates[state] then return true end
    local endTime = Player:GetAttribute("RagdollEndTime")
    if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then return true end
    return false
end

local function arForceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function() Player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
    for _, descendant in ipairs(cachedCharData.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            descendant:Destroy()
        end
    end
    if not isBoosting then isBoosting = true; cachedCharData.humanoid.WalkSpeed = BOOST_SPEED end
    if cachedCharData.humanoid.Health > 0 then cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running) end
    cachedCharData.root.Anchored = false
end

local function arHeartbeatLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        local currentlyRagdolled = arIsRagdolled()
        if currentlyRagdolled then arForceExitRagdoll()
        elseif isBoosting and not currentlyRagdolled then
            isBoosting = false
            if cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED end
        end
    end
end

function startAntiRagdoll()
    if antiRagdollMode == "v1" then return end
    if not arCacheCharacterData() then return end
    antiRagdollMode = "v1"
    local camConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then cam.CameraSubject = cachedCharData.humanoid end
    end)
    table.insert(ragdollConnections, camConn)
    local respawnConn = Player.CharacterAdded:Connect(function()
        isBoosting = false; task.wait(0.5); arCacheCharacterData()
    end)
    table.insert(ragdollConnections, respawnConn)
    task.spawn(arHeartbeatLoop)
end

function stopAntiRagdoll()
    antiRagdollMode = nil
    if isBoosting and cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED end
    isBoosting = false; arDisconnectAll(); cachedCharData = {}
end

-- AUTO WALK
local FORWARD_SPEED = 59
local RETURN_SPEED = 29

local RIGHT_PATH = {
    Vector3.new(-473.32, -7.67, 10.16), Vector3.new(-472.71, -8.14, 29.92),
    Vector3.new(-472.87, -8.14, 49.50), Vector3.new(-472.45, -8.14, 65.05),
    Vector3.new(-472.94, -8.14, 82.48), Vector3.new(-475.00, -8.14, 96.84),
    Vector3.new(-485.50, -6.43, 96.08),
}
local LEFT_PATH = {
    Vector3.new(-473.31, -7.67, 111.75), Vector3.new(-473.51, -8.14, 87.30),
    Vector3.new(-473.74, -8.14, 60.58),  Vector3.new(-474.04, -8.14, 41.38),
    Vector3.new(-474.35, -8.14, 25.77),  Vector3.new(-485.30, -6.43, 22.36),
}
local RIGHT_RETURN_PATH_FAST = {
    Vector3.new(-475.23, -8.14, 90.61), Vector3.new(-476.24, -8.14, 57.32), Vector3.new(-475.63, -8.14, 23.36),
}
local LEFT_RETURN_PATH_FAST = {
    Vector3.new(-474.23, -8.14, 26.51), Vector3.new(-475.15, -8.14, 59.32), Vector3.new(-475.62, -8.06, 97.99),
}

local waypoints = {}
local returnWaypoints = {}
local returnWaypointIndex = 1

local function StopAutoWalk()
    if AutoWalkConnection then AutoWalkConnection:Disconnect(); AutoWalkConnection = nil end
    waypoints = {}; returnWaypoints = {}
    currentWaypointIndex = 1; returnWaypointIndex = 1
    isAutoWalking = false; isReturning = false; isPaused = false
    local humanoid = GetHumanoid()
    if humanoid then humanoid:Move(Vector3.new(0,0,0)) end
    local rootPart = GetRootPart()
    if rootPart then rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0) end
end

local function FindClosestWaypoint(position, waypointList)
    local closestIndex, closestDistance = 1, math.huge
    for i, waypoint in ipairs(waypointList) do
        local dist = (Vector3.new(waypoint.X, position.Y, waypoint.Z) - position).Magnitude
        if dist < closestDistance then closestDistance = dist; closestIndex = i end
    end
    return closestIndex
end

local function StartAutoWalk(direction)
    StopAutoWalk()
    local rootPart = GetRootPart(); if not rootPart then return end
    if direction == "right" then waypoints = RIGHT_PATH; returnWaypoints = RIGHT_RETURN_PATH_FAST
    elseif direction == "left" then waypoints = LEFT_PATH; returnWaypoints = LEFT_RETURN_PATH_FAST end
    currentWaypointIndex = FindClosestWaypoint(rootPart.Position, waypoints)
    returnWaypointIndex = 1; isAutoWalking = true; isReturning = false; isPaused = false

    AutoWalkConnection = RunService.Heartbeat:Connect(function()
        if IsShuttingDown then return end
        if not Config.AutoRight and not Config.AutoLeft then StopAutoWalk(); return end
        if isPaused then return end
        if HasBrainrotInHand and not isReturning then isReturning = true; returnWaypointIndex = 1 end
        local humanoid = GetHumanoid(); local rootPart = GetRootPart()
        if not humanoid or not rootPart or not isAutoWalking then return end
        local targetPos = isReturning and returnWaypoints[returnWaypointIndex] or waypoints[currentWaypointIndex]
        if not targetPos then return end
        local directionVector = (targetPos - rootPart.Position) * Vector3.new(1, 0, 1)
        local distance = directionVector.Magnitude
        local moveDirection = directionVector.Unit
        humanoid:Move(moveDirection)
        local speedValue = isReturning and RETURN_SPEED or FORWARD_SPEED
        rootPart.AssemblyLinearVelocity = Vector3.new(moveDirection.X * speedValue, rootPart.AssemblyLinearVelocity.Y, moveDirection.Z * speedValue)
        if distance < 3.0 then
            if not isReturning then
                currentWaypointIndex = currentWaypointIndex + 1
                if currentWaypointIndex > #waypoints then
                    isPaused = true
                    humanoid:Move(Vector3.new(0,0,0))
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
                    task.spawn(function() task.wait(0.3); isReturning = true; returnWaypointIndex = 1; isPaused = false end)
                end
            else
                returnWaypointIndex = returnWaypointIndex + 1
                if returnWaypointIndex > #returnWaypoints then
                    isPaused = true
                    humanoid:Move(Vector3.new(0,0,0))
                    if Config.AutoRight then Config.AutoRight = false; if ToggleFunctions["AutoRight"] then ToggleFunctions["AutoRight"](false) end
                    elseif Config.AutoLeft then Config.AutoLeft = false; if ToggleFunctions["AutoLeft"] then ToggleFunctions["AutoLeft"](false) end end
                    StopAutoWalk()
                end
            end
        end
    end)
end

function ToggleAutoRight(enabled)
    Config.AutoRight = enabled
    if enabled then Config.AutoLeft = false; if ToggleFunctions["AutoLeft"] then ToggleFunctions["AutoLeft"](false) end; StartAutoWalk("right")
    else if not Config.AutoLeft then StopAutoWalk() end end
end

function ToggleAutoLeft(enabled)
    Config.AutoLeft = enabled
    if enabled then Config.AutoRight = false; if ToggleFunctions["AutoRight"] then ToggleFunctions["AutoRight"](false) end; StartAutoWalk("left")
    else if not Config.AutoRight then StopAutoWalk() end end
end

ToggleFunctions["AutoRight"] = function(v) updateRightPanel(v) end
ToggleFunctions["AutoLeft"]  = function(v) updateLeftPanel(v) end

-- XRAY
local originalTransparency = {}
function enableXRay()
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

function disableXRay()
    for part, value in pairs(originalTransparency) do
        if part then part.LocalTransparencyModifier = value end
    end
    originalTransparency = {}
end

-- ESP
local function CreateBoxESP(p)
    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = p.Character.HumanoidRootPart
        if not hrp:FindFirstChild("MedusaBox") then
            local b = Instance.new("BillboardGui", hrp)
            b.Name = "MedusaBox"; b.AlwaysOnTop = true; b.Size = UDim2.new(4.5,0,6,0); b.Adornee = hrp
            local f = Instance.new("Frame", b); f.Size = UDim2.new(1,0,1,0); f.BackgroundTransparency = 0.7; f.BackgroundColor3 = Color3.fromRGB(120, 90, 200)
            Instance.new("UIStroke", f).Color = Color3.new(1,1,1)
            local tl = Instance.new("TextLabel", b); tl.Size = UDim2.new(1,0,0.2,0); tl.Position = UDim2.new(0,0,-0.25,0); tl.BackgroundTransparency = 1
            tl.Text = p.Name; tl.TextColor3 = Color3.new(1,1,1); tl.Font = "GothamBold"; tl.TextSize = 10
        end
    end
end

-- OPTIMIZER
function ApplyOptimizer(state)
    if state then
        Lighting.GlobalShadows = false
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then v.Material = Enum.Material.Plastic; v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
        end
    else Lighting.GlobalShadows = true end
end

-- TIMER ESP
local function UpdateTimerESP()
    local plots = Workspace:FindFirstChild("Plots"); if not plots then return end
    for _, plot in pairs(plots:GetChildren()) do
        local purchases = plot:FindFirstChild("Purchases"); if not purchases then continue end
        for _, purchase in pairs(purchases:GetChildren()) do
            local main = purchase:FindFirstChild("Main")
            local billboard = main and main:FindFirstChild("BillboardGui")
            local remTime = billboard and billboard:FindFirstChild("RemainingTime")
            if remTime and remTime:IsA("TextLabel") and remTime.Visible then
                local existing = main:FindFirstChild("TimerESP_Gui")
                if cfg.timerEsp then
                    if not existing then
                        local gui = Instance.new("BillboardGui", main); gui.Name = "TimerESP_Gui"
                        gui.Size = UDim2.new(0, 100, 0, 40); gui.StudsOffset = Vector3.new(0, 3, 0); gui.AlwaysOnTop = true
                        local txt = Instance.new("TextLabel", gui); txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1
                        txt.TextColor3 = Color3.fromRGB(120, 90, 200); txt.Font = "GothamBold"; txt.TextSize = 14; txt.TextStrokeTransparency = 0; txt.Text = remTime.Text
                    else existing.TextLabel.Text = remTime.Text end
                elseif existing then existing:Destroy() end
            end
        end
    end
end

-- MAIN LOOP
RunService.RenderStepped:Connect(function()
    local fps = math.floor(1/RunService.RenderStepped:Wait())
    local ok, ping = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+") end)
    StatsLabel.Text = "FPS: "..fps.." PING: "..(ok and ping or "--").."ms"

    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local velocity = lp.Character.HumanoidRootPart.Velocity
        local speed = math.floor(Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
        speedLabel.Text = speed .. " sp"
        walkSpeedLabel.Text = "Walk Speed  " .. speed
    end

    if cfg.speed and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            hrp.Velocity = Vector3.new(hum.MoveDirection.X * 57, hrp.Velocity.Y, hum.MoveDirection.Z * 57)
        end
    end

    UpdateTimerESP()
end)

UserInputService.JumpRequest:Connect(function()
    if cfg.infJump and GetRootPart() then
        GetRootPart().Velocity = Vector3.new(GetRootPart().Velocity.X, 50, GetRootPart().Velocity.Z)
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        if cfg.esp then
            for _, p in pairs(Players:GetPlayers()) do if p ~= lp then CreateBoxESP(p) end end
        else
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart:FindFirstChild("MedusaBox") then
                    p.Character.HumanoidRootPart.MedusaBox:Destroy()
                end
            end
        end
        if cfg.fastSteal then
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") then v.HoldDuration = 0 end
            end
        end
    end
end)

-- Notification de lancement
task.spawn(function()
    task.wait(1)
    local notifGui = Instance.new("ScreenGui", lp.PlayerGui)
    notifGui.Name = "MedusaNotif"; notifGui.ResetOnSpawn = false
    local notif = Instance.new("Frame", notifGui)
    notif.Size = UDim2.new(0, 220, 0, 50)
    notif.Position = UDim2.new(0.5, -110, 1, 0)
    notif.BackgroundColor3 = COL_BG
    notif.BorderSizePixel = 0
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 8)
    local ns = Instance.new("UIStroke", notif); ns.Color = COL_ACCENT; ns.Thickness = 1.5
    local nl = Instance.new("TextLabel", notif)
    nl.Size = UDim2.new(1,0,1,0); nl.BackgroundTransparency = 1
    nl.Text = "✓  MEDUSA HUB V57 chargé\n[K] pour ouvrir/fermer"
    nl.TextColor3 = COL_TEXT; nl.Font = Enum.Font.GothamBold; nl.TextSize = 11
    TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, -110, 1, -60)}):Play()
    task.wait(3)
    TweenService:Create(notif, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -110, 1, 10)}):Play()
    task.wait(0.4); notifGui:Destroy()
end)
