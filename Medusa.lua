-- [[ MEDUSA HUB V57 - FINAL EDITION ]] --

local lp = game:GetService("Players").LocalPlayer
local Player = lp
local LocalPlayer = lp
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =============================================
-- [ SAUVEGARDE DES PARAMETRES ] --
-- =============================================
local CONFIG_FILE = "MedusaHubV57_Config.json"

local defaultConfig = {
    speed       = false,
    antiRagdoll = false,
    fastSteal   = false,
    instSteal   = false,
    esp         = false,
    xray        = false,
    infJump     = false,
    optimizer   = false,
    timerEsp    = false,
    antiTrap    = false,
    halfTP      = false,
    aspectRatio = false,
    darkMode    = false,
    batAimbot   = false,
    autoRight   = false,
    autoLeft    = false,
    giantPotion = false,
    walkSpeed   = false,
    stealSpeed  = false,
    spamSteal   = false,
    balloonBase = false,
    autoBlock   = true,
    blockDelay  = 0.7,
}

local function loadConfig()
    local ok, data = pcall(function()
        if not isfile(CONFIG_FILE) then return nil end
        return game:GetService("HttpService"):JSONDecode(readfile(CONFIG_FILE))
    end)
    if ok and data then
        for k, v in pairs(defaultConfig) do
            if data[k] == nil then data[k] = v end
        end
        return data
    end
    return defaultConfig
end

local function saveConfig(t)
    pcall(function()
        writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(t))
    end)
end

local savedCfg = loadConfig()

-- =============================================
-- [ VARIABLES GLOBALES ] --
-- =============================================
local cfg = {
    speed       = savedCfg.speed,
    antiRagdoll = savedCfg.antiRagdoll,
    fastSteal   = savedCfg.fastSteal,
    instSteal   = savedCfg.instSteal,
    esp         = savedCfg.esp,
    xray        = savedCfg.xray,
    infJump     = savedCfg.infJump,
    optimizer   = savedCfg.optimizer,
    timerEsp    = savedCfg.timerEsp,
    antiTrap    = savedCfg.antiTrap,
    halfTP      = savedCfg.halfTP,
    aspectRatio = savedCfg.aspectRatio,
    darkMode    = savedCfg.darkMode,
}

local function persistCfg()
    for k, v in pairs(cfg) do savedCfg[k] = v end
    saveConfig(savedCfg)
end

local Config = { AutoRight = savedCfg.autoRight, AutoLeft = savedCfg.autoLeft }
local ToggleFunctions = {}
local Connections = {}
local Enabled = { BatAimbot = savedCfg.batAimbot }
local AutoWalkConnection = nil
local isAutoWalking = false
local isReturning = false
local isPaused = false
local currentWaypointIndex = 1
local IsShuttingDown = false
local HasBrainrotInHand = false
local antiTrapConnection = nil
local halfTpConnection = nil
local aspectRatioConnection = nil
local stretchGui = nil
local stretchCam = nil

-- =============================================
-- [ CHIRON TP - VARIABLES ] --
-- =============================================
local backpack = lp:WaitForChild("Backpack")
local charTP = lp.Character or lp.CharacterAdded:Wait()
local humanoidTP = charTP:WaitForChild("Humanoid")
local hrpTP = charTP:WaitForChild("HumanoidRootPart")

lp.CharacterAdded:Connect(function(c)
    charTP = c
    humanoidTP = c:WaitForChild("Humanoid")
    hrpTP = c:WaitForChild("HumanoidRootPart")
end)

local blockDelay = savedCfg.blockDelay or 0.7
local minDelay, maxDelay = 0.1, 5.0
local autoBlockEnabled = savedCfg.autoBlock
local teleportKey = Enum.KeyCode.F
local waitingForKey = false
local REQUIRED_TOOL = "Flying Carpet"

local spots = {
    CFrame.new(-402.18, -6.34, 131.83) * CFrame.Angles(0, math.rad(-20.08), 0),
    CFrame.new(-416.66, -6.34, -2.05)  * CFrame.Angles(0, math.rad(-62.89), 0),
    CFrame.new(-329.37, -4.68, 18.12)  * CFrame.Angles(0, math.rad(-30.53), 0),
}

local function FastClick()
    task.wait(blockDelay)
    local cam = workspace.CurrentCamera.ViewportSize
    local x, y = cam.X/2, cam.Y/2+23
    for _ = 1, 8 do
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true,  game, 1)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        task.wait(0.008)
    end
end

local function blockPlayer(plr)
    if not plr or plr == lp then return end
    pcall(function() StarterGui:SetCore("PromptBlockPlayer", plr) end)
end

local function equipFlyingCarpet()
    local tool = backpack:FindFirstChild(REQUIRED_TOOL) or charTP:FindFirstChild(REQUIRED_TOOL)
    if not tool then return false end
    if tool.Parent ~= charTP then
        humanoidTP:EquipTool(tool)
        repeat task.wait() until tool.Parent == charTP
    end
    return true
end

local function checkForBrainrot()
    if not autoBlockEnabled then return false end
    local keywords = {"brainrot","animal","monkey","dog","cat","bird"}
    local function hasKW(name)
        local n = name:lower()
        for _, kw in ipairs(keywords) do if n:find(kw) then return true end end
        return false
    end
    local function checkTools(container)
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and hasKW(tool.Name) then
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= lp and other.Character then
                        local ob = other:FindFirstChild("Backpack")
                        if ob and not ob:FindFirstChild(tool.Name) then
                            blockPlayer(other); FastClick(); task.wait(0.25); return true
                        end
                    end
                end
            end
        end
        return false
    end
    return checkTools(backpack) or checkTools(charTP)
end

local function setupBrainrotDetection()
    checkForBrainrot()
    backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then task.wait(0.5); checkForBrainrot() end
    end)
    charTP.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then task.wait(0.5); checkForBrainrot() end
    end)
    lp.CharacterAdded:Connect(function(newChar)
        charTP = newChar
        newChar.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then task.wait(0.5); checkForBrainrot() end
        end)
        task.wait(1); checkForBrainrot()
    end)
end

local function teleportAll()
    if not equipFlyingCarpet() then return end
    local lastTarget = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then lastTarget = plr; break end
    end
    for _, spot in ipairs(spots) do
        equipFlyingCarpet(); hrpTP.CFrame = spot; task.wait(0.12)
    end
    if lastTarget and autoBlockEnabled then blockPlayer(lastTarget); FastClick() end
end

local function blockAllPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then blockPlayer(plr); FastClick(); task.wait(0.25) end
    end
end

-- =============================================
-- [ AP SPAMMER (THORIUM) ] --
-- =============================================
local spamming = {}

local function getStealRemote()
    local net = ReplicatedStorage:FindFirstChild("Packages")
        and ReplicatedStorage.Packages:FindFirstChild("Net")
    if not net then return nil end
    return net:FindFirstChild("StealService/Grab", true)
end

local function startSpam(player)
    if spamming[player.UserId] then return end
    spamming[player.UserId] = true
    task.spawn(function()
        while spamming[player.UserId] and player.Parent do
            local remote = getStealRemote()
            if remote then
                pcall(function() remote:FireServer(player.Character) end)
            end
            task.wait(0.1)
        end
        spamming[player.UserId] = nil
    end)
end

local function stopSpam(player)
    spamming[player.UserId] = nil
end

local function stopAllSpam()
    for uid, _ in pairs(spamming) do spamming[uid] = nil end
end

-- =============================================
-- [ NETTOYAGE UI ] --
-- =============================================
for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "MedusaHubUI" or v.Name == "MedusaNotif" or v.Name == "MedusaStretch"
    or v.Name == "ThoriumDashboard" or v.Name == "ThoriumPlayerList" then v:Destroy() end
end
for _, v in pairs(lp.PlayerGui:GetChildren()) do
    if v.Name == "Rayfield" or v.Name == "MedusaStatsUI" or v.Name == "MedusaPanels" or v.Name == "ChironTP" then v:Destroy() end
end

-- [ UTILITAIRES ] --
local function GetHumanoid() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end
local function GetRootPart() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end

RunService.Heartbeat:Connect(function()
    HasBrainrotInHand = lp.Character and lp.Character:FindFirstChild("Brainrot") ~= nil
end)

-- =============================================
-- [ SPEED BILLBOARD ] --
-- =============================================
local speedBillboard = Instance.new("BillboardGui")
speedBillboard.Name = "CH_SpeedDisplay"
speedBillboard.Size = UDim2.new(0,90,0,26)
speedBillboard.StudsOffset = Vector3.new(0,3.5,0)
speedBillboard.AlwaysOnTop = false
speedBillboard.ResetOnSpawn = false

local speedLabel = Instance.new("TextLabel", speedBillboard)
speedLabel.Size = UDim2.new(1,0,1,0); speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(255,255,255); speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextSize = 20; speedLabel.Text = "0 sp"
speedLabel.TextStrokeTransparency = 0.3; speedLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)

local function attachSpeedDisplay()
    local c = LocalPlayer.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    speedBillboard.Adornee = hrp; speedBillboard.Parent = CoreGui
end
LocalPlayer.CharacterAdded:Connect(function(c)
    c:WaitForChild("HumanoidRootPart"); task.wait(0.1); attachSpeedDisplay()
end)
attachSpeedDisplay()

-- =============================================
-- [ THEME ] --
-- =============================================
local C = {
    BG      = Color3.fromRGB(28, 25, 40),
    HEADER  = Color3.fromRGB(20, 17, 32),
    ACCENT  = Color3.fromRGB(120, 90, 200),
    TAB_ON  = Color3.fromRGB(120, 90, 200),
    TAB_OFF = Color3.fromRGB(48, 44, 65),
    TEXT    = Color3.fromRGB(230, 225, 255),
    SUB     = Color3.fromRGB(160, 150, 190),
    TOG_ON  = Color3.fromRGB(120, 90, 200),
    TOG_OFF = Color3.fromRGB(65, 60, 85),
    PANEL   = Color3.fromRGB(32, 28, 48),
    BTN     = Color3.fromRGB(55, 50, 80),
    BTN_RED = Color3.fromRGB(150, 35, 35),
    BTN_GRN = Color3.fromRGB(35, 120, 60),
    BTN_BLU = Color3.fromRGB(50, 120, 220),
    BTN_ORG = Color3.fromRGB(200, 100, 30),
    SEP     = Color3.fromRGB(60, 55, 80),
    WHITE   = Color3.new(1,1,1),
}

-- =============================================
-- [ HELPERS UI ] --
-- =============================================
local function Corner(p, r) local c = Instance.new("UICorner",p); c.CornerRadius = UDim.new(0,r or 7); return c end
local function Stroke(p, col, t) local s = Instance.new("UIStroke",p); s.Color = col or C.ACCENT; s.Thickness = t or 1.5; return s end

local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
end

local function TogRow(parent, yPos, label, initVal, callback)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,-16,0,30); row.Position = UDim2.new(0,8,0,yPos); row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-52,1,0); lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = C.TEXT; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0,44,0,22); track.Position = UDim2.new(1,-44,0.5,-11)
    track.BackgroundColor3 = initVal and C.TOG_ON or C.TOG_OFF; track.BorderSizePixel = 0; Corner(track,11)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,16,0,16)
    knob.Position = initVal and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3 = C.WHITE; knob.BorderSizePixel = 0; Corner(knob,8)
    local state = initVal
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15,Enum.EasingStyle.Quad), {BackgroundColor3=state and C.TOG_ON or C.TOG_OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15,Enum.EasingStyle.Quad), {Position=state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        if callback then callback(state) end
    end)
    return function(v)
        state=v; track.BackgroundColor3=v and C.TOG_ON or C.TOG_OFF
        knob.Position=v and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    end
end

local function Sep(parent, yPos, label)
    if label then
        local l = Instance.new("TextLabel", parent)
        l.Size = UDim2.new(1,-16,0,18); l.Position = UDim2.new(0,8,0,yPos)
        l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = C.SUB
        l.Font = Enum.Font.GothamBold; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    end
    local line = Instance.new("Frame", parent)
    line.Size = UDim2.new(1,-16,0,1); line.Position = UDim2.new(0,8,0,yPos+(label and 18 or 0))
    line.BackgroundColor3 = C.SEP; line.BorderSizePixel = 0
    return yPos + (label and 20 or 1)
end

local function Btn(parent, yPos, label, col, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1,-16,0,27); b.Position = UDim2.new(0,8,0,yPos)
    b.BackgroundColor3 = col or C.BTN; b.BorderSizePixel = 0; b.Text = label
    b.TextColor3 = C.WHITE; b.Font = Enum.Font.GothamBold; b.TextSize = 12; Corner(b,5)
    if cb then b.MouseButton1Click:Connect(cb) end; return b
end

-- =============================================
-- [ FENETRE PRINCIPALE ] --
-- =============================================
local HubGui = Instance.new("ScreenGui")
HubGui.Name = "MedusaHubUI"; HubGui.ResetOnSpawn = false
HubGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; HubGui.DisplayOrder = 999
HubGui.Parent = CoreGui

local MainWin = Instance.new("Frame", HubGui)
MainWin.Name = "MainWin"; MainWin.Size = UDim2.new(0,235,0,420)
MainWin.Position = UDim2.new(0.5,-117,0.5,-210)
MainWin.BackgroundColor3 = C.BG; MainWin.BorderSizePixel = 0; MainWin.Active = true
Corner(MainWin,8); Stroke(MainWin,C.ACCENT,1.5)

local Hdr = Instance.new("Frame", MainWin)
Hdr.Size = UDim2.new(1,0,0,38); Hdr.BackgroundColor3 = C.HEADER; Hdr.BorderSizePixel = 0; Corner(Hdr,8)
local hMask = Instance.new("Frame", Hdr)
hMask.Size = UDim2.new(1,0,0,8); hMask.Position = UDim2.new(0,0,1,-8); hMask.BackgroundColor3 = C.HEADER; hMask.BorderSizePixel = 0

local TitleL = Instance.new("TextLabel", Hdr)
TitleL.Size = UDim2.new(1,-40,1,0); TitleL.Position = UDim2.new(0,10,0,0); TitleL.BackgroundTransparency = 1
TitleL.Text = "medusa hub"; TitleL.TextColor3 = C.TEXT; TitleL.Font = Enum.Font.GothamBold
TitleL.TextSize = 14; TitleL.TextXAlignment = Enum.TextXAlignment.Left

local XBtn = Instance.new("TextButton", Hdr)
XBtn.Size = UDim2.new(0,22,0,22); XBtn.Position = UDim2.new(1,-28,0.5,-11)
XBtn.BackgroundColor3 = C.BTN_RED; XBtn.BorderSizePixel = 0; XBtn.Text = "×"
XBtn.TextColor3 = C.WHITE; XBtn.Font = Enum.Font.GothamBold; XBtn.TextSize = 15; Corner(XBtn,11)
XBtn.MouseButton1Click:Connect(function() MainWin.Visible = not MainWin.Visible end)
MakeDraggable(MainWin, Hdr)

local TabBar = Instance.new("Frame", MainWin)
TabBar.Size = UDim2.new(1,-16,0,26); TabBar.Position = UDim2.new(0,8,0,44); TabBar.BackgroundTransparency = 1
local tLayout = Instance.new("UIListLayout", TabBar)
tLayout.FillDirection = Enum.FillDirection.Horizontal; tLayout.SortOrder = Enum.SortOrder.LayoutOrder; tLayout.Padding = UDim.new(0,4)

local ContentArea = Instance.new("Frame", MainWin)
ContentArea.Size = UDim2.new(1,0,1,-78); ContentArea.Position = UDim2.new(0,0,0,78)
ContentArea.BackgroundTransparency = 1; ContentArea.ClipsDescendants = true

local tabPages, tabBtns = {}, {}

local function CreatePage(name)
    local p = Instance.new("ScrollingFrame", ContentArea)
    p.Name = name.."Page"; p.Size = UDim2.new(1,0,1,0); p.BackgroundTransparency = 1
    p.BorderSizePixel = 0; p.ScrollBarThickness = 2; p.ScrollBarImageColor3 = C.ACCENT
    p.CanvasSize = UDim2.new(0,0,0,0); p.Visible = false; tabPages[name] = p; return p
end

local function SwitchTab(name)
    for n,p in pairs(tabPages) do p.Visible = (n==name) end
    for n,b in pairs(tabBtns) do
        b.BackgroundColor3 = (n==name) and C.TAB_ON or C.TAB_OFF
        b.TextColor3 = (n==name) and C.WHITE or C.SUB
    end
end

for i, name in ipairs({"Main","Visual"}) do
    local b = Instance.new("TextButton", TabBar)
    b.Size = UDim2.new(0,104,1,0); b.BackgroundColor3 = (i==1) and C.TAB_ON or C.TAB_OFF
    b.BorderSizePixel = 0; b.Text = name
    b.TextColor3 = (i==1) and C.WHITE or C.SUB
    b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.LayoutOrder = i; Corner(b,5)
    tabBtns[name] = b; b.MouseButton1Click:Connect(function() SwitchTab(name) end)
end

-- =============================================
-- [ PAGE MAIN ] --
-- =============================================
local MainPage = CreatePage("Main"); MainPage.Visible = true
local mY = 6

-- CHIRON TP
mY = Sep(MainPage, mY, "Chiron TP"); mY = mY + 4

Btn(MainPage, mY, "🚀  FUCK EM  [F]", C.BTN_BLU, function()
    task.spawn(function()
        teleportAll()
        if autoBlockEnabled then task.wait(1); checkForBrainrot() end
    end)
end); mY = mY + 32

local keybindBtn = Btn(MainPage, mY, "Keybind: [F]", C.BTN, nil)
keybindBtn.MouseButton1Click:Connect(function()
    keybindBtn.Text = "Press a key..."
    waitingForKey = true
end); mY = mY + 32

TogRow(MainPage, mY, "Auto Block", autoBlockEnabled, function(v)
    autoBlockEnabled=v; savedCfg.autoBlock=v; saveConfig(savedCfg)
end); mY = mY + 32

-- Delay row
local delayRow = Instance.new("Frame", MainPage)
delayRow.Size = UDim2.new(1,-16,0,28); delayRow.Position = UDim2.new(0,8,0,mY); delayRow.BackgroundTransparency = 1
local delayLbl = Instance.new("TextLabel", delayRow)
delayLbl.Size = UDim2.new(0,55,1,0); delayLbl.BackgroundTransparency = 1
delayLbl.Text = "Delay:"; delayLbl.TextColor3 = C.TEXT; delayLbl.Font = Enum.Font.Gotham; delayLbl.TextSize = 11; delayLbl.TextXAlignment = Enum.TextXAlignment.Left
local delayBox = Instance.new("TextBox", delayRow)
delayBox.Size = UDim2.new(0,70,0,22); delayBox.Position = UDim2.new(0,55,0.5,-11)
delayBox.Text = tostring(blockDelay); delayBox.TextColor3 = C.TEXT
delayBox.Font = Enum.Font.Gotham; delayBox.TextSize = 11
delayBox.BackgroundColor3 = Color3.fromRGB(40,35,60); delayBox.BorderSizePixel = 0
delayBox.PlaceholderText = "0.1-5.0"; Corner(delayBox,4); Stroke(delayBox,C.ACCENT,1)
local setDelayBtn2 = Instance.new("TextButton", delayRow)
setDelayBtn2.Size = UDim2.new(0,38,0,22); setDelayBtn2.Position = UDim2.new(0,130,0.5,-11)
setDelayBtn2.BackgroundColor3 = C.ACCENT; setDelayBtn2.BorderSizePixel = 0
setDelayBtn2.Text = "SET"; setDelayBtn2.TextColor3 = C.WHITE; setDelayBtn2.Font = Enum.Font.GothamBold; setDelayBtn2.TextSize = 10; Corner(setDelayBtn2,4)
local function applyDelay()
    local num = tonumber(delayBox.Text)
    if num then
        blockDelay = math.clamp(math.floor(num*100+0.5)/100, minDelay, maxDelay)
        delayBox.Text = tostring(blockDelay); savedCfg.blockDelay=blockDelay; saveConfig(savedCfg)
    else delayBox.Text = tostring(blockDelay) end
end
setDelayBtn2.MouseButton1Click:Connect(applyDelay); delayBox.FocusLost:Connect(applyDelay)
mY = mY + 34

Btn(MainPage, mY, "🚫  Block All Players", C.BTN, function() task.spawn(blockAllPlayers) end); mY = mY + 36

-- Combat
mY = Sep(MainPage, mY, "Combat"); mY = mY + 4

local setBatAim = TogRow(MainPage, mY, "Bat Aimbot", savedCfg.batAimbot, function(v)
    Enabled.BatAimbot=v; savedCfg.batAimbot=v; saveConfig(savedCfg)
    if v then startBatAimbot() else stopBatAimbot() end
end); mY = mY + 32

TogRow(MainPage, mY, "Half TP V2", cfg.halfTP, function(v)
    cfg.halfTP=v; persistCfg(); if v then startHalfTP() else stopHalfTP() end
end); mY = mY + 32

TogRow(MainPage, mY, "Anti-Ragdoll v1", cfg.antiRagdoll, function(v)
    cfg.antiRagdoll=v; persistCfg(); if v then startAntiRagdoll() else stopAntiRagdoll() end
end); mY = mY + 32

TogRow(MainPage, mY, "Anti-Trap", cfg.antiTrap, function(v)
    cfg.antiTrap=v; persistCfg()
    if v then
        antiTrapConnection = RunService.Heartbeat:Connect(function()
            local trap = Workspace:FindFirstChild("Trap")
            if trap and trap:IsA("Model") then trap:Destroy() end
        end)
    else if antiTrapConnection then antiTrapConnection:Disconnect(); antiTrapConnection = nil end end
end); mY = mY + 36

-- Stealing
mY = Sep(MainPage, mY, "Stealing"); mY = mY + 4
TogRow(MainPage, mY, "Auto Steal (New)", cfg.fastSteal, function(v) cfg.fastSteal=v; persistCfg() end); mY = mY + 32
TogRow(MainPage, mY, "Instant Steal",    cfg.instSteal, function(v) cfg.instSteal=v; persistCfg() end); mY = mY + 36

-- Movement
mY = Sep(MainPage, mY, "Movement"); mY = mY + 4
TogRow(MainPage, mY, "Speed Boost (57)", cfg.speed,    function(v) cfg.speed=v; persistCfg() end); mY = mY + 32
TogRow(MainPage, mY, "Infinite Jump",    cfg.infJump,  function(v) cfg.infJump=v; persistCfg() end); mY = mY + 36

-- Server
mY = Sep(MainPage, mY, "Server"); mY = mY + 8
Btn(MainPage, mY, "Rejoin Server", C.BTN, function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end); mY = mY + 32
Btn(MainPage, mY, "Kick Self",    C.BTN,     function() LocalPlayer:Kick("Medusa Hub") end); mY = mY + 32
Btn(MainPage, mY, "Force Reset",  C.BTN_RED, function() local h=GetHumanoid(); if h then h.Health=0 end end); mY = mY + 10
MainPage.CanvasSize = UDim2.new(0,0,0,mY)

-- =============================================
-- [ PAGE VISUAL ] --
-- =============================================
local VisualPage = CreatePage("Visual")
local vY = 6

vY = Sep(VisualPage, vY, "ESP"); vY = vY + 4
TogRow(VisualPage, vY, "ESP Anti-Invis", cfg.esp,     function(v) cfg.esp=v; persistCfg() end); vY = vY + 32
TogRow(VisualPage, vY, "Base X-Ray",     cfg.xray,    function(v) cfg.xray=v; persistCfg(); if v then enableXRay() else disableXRay() end end); vY = vY + 32
TogRow(VisualPage, vY, "Timer ESP",      cfg.timerEsp,function(v) cfg.timerEsp=v; persistCfg() end); vY = vY + 36

vY = Sep(VisualPage, vY, "Effects"); vY = vY + 4
TogRow(VisualPage, vY, "Aspect Ratio (Stretch)", cfg.aspectRatio, function(v)
    cfg.aspectRatio=v; persistCfg(); if v then enableAspectRatio() else disableAspectRatio() end
end); vY = vY + 32
TogRow(VisualPage, vY, "Dark Mode", cfg.darkMode, function(v)
    cfg.darkMode=v; persistCfg(); Lighting.Brightness=v and 0.1 or 2; Lighting.ClockTime=v and 0 or 14
end); vY = vY + 32
TogRow(VisualPage, vY, "FPS Booster", cfg.optimizer, function(v)
    cfg.optimizer=v; persistCfg(); applyOptimizer(v)
end); vY = vY + 10
VisualPage.CanvasSize = UDim2.new(0,0,0,vY)

-- =============================================
-- [ PANEL FPS/PING ] --
-- =============================================
local FPSPanel = Instance.new("Frame", HubGui)
FPSPanel.Size = UDim2.new(0,180,0,46); FPSPanel.Position = UDim2.new(0.5,-90,0,8)
FPSPanel.BackgroundColor3 = C.HEADER; FPSPanel.BorderSizePixel = 0; FPSPanel.Active = true
Corner(FPSPanel,8); Stroke(FPSPanel,C.ACCENT,1.2); MakeDraggable(FPSPanel)

local HubNameL = Instance.new("TextLabel", FPSPanel)
HubNameL.Size = UDim2.new(1,0,0,20); HubNameL.Position = UDim2.new(0,0,0,3)
HubNameL.BackgroundTransparency = 1; HubNameL.Text = "medusa hub  •  gg/medusa"
HubNameL.TextColor3 = C.SUB; HubNameL.Font = Enum.Font.GothamBold; HubNameL.TextSize = 10

local FPSStats = Instance.new("TextLabel", FPSPanel)
FPSStats.Size = UDim2.new(1,0,0,20); FPSStats.Position = UDim2.new(0,0,0,24)
FPSStats.BackgroundTransparency = 1; FPSStats.Text = "FPS: --  PING: --ms"
FPSStats.TextColor3 = C.TEXT; FPSStats.Font = Enum.Font.GothamBold; FPSStats.TextSize = 11

local MenuBtn = Instance.new("TextButton", HubGui)
MenuBtn.Size = UDim2.new(0,80,0,22); MenuBtn.Position = UDim2.new(0.5,-40,0,58)
MenuBtn.BackgroundColor3 = C.ACCENT; MenuBtn.BorderSizePixel = 0
MenuBtn.Text = "Menu  [K]"; MenuBtn.TextColor3 = C.WHITE
MenuBtn.Font = Enum.Font.GothamBold; MenuBtn.TextSize = 11; Corner(MenuBtn,5)
MenuBtn.MouseButton1Click:Connect(function() MainWin.Visible = not MainWin.Visible end)

-- =============================================
-- [ PANELS FLOTTANTS DROITE ] --
-- =============================================
local function MakePanel(title, xOff, yOff, w, h)
    local panel = Instance.new("Frame", HubGui)
    panel.Size = UDim2.new(0,w,0,h); panel.Position = UDim2.new(1,xOff,0,yOff)
    panel.BackgroundColor3 = C.PANEL; panel.BorderSizePixel = 0; panel.Active = true
    Corner(panel,7); Stroke(panel,C.ACCENT,1)
    local hdr = Instance.new("Frame", panel)
    hdr.Size = UDim2.new(1,0,0,26); hdr.BackgroundColor3 = C.HEADER; hdr.BorderSizePixel = 0; Corner(hdr,7)
    local hMask2 = Instance.new("Frame", hdr)
    hMask2.Size = UDim2.new(1,0,0,7); hMask2.Position = UDim2.new(0,0,1,-7); hMask2.BackgroundColor3 = C.HEADER; hMask2.BorderSizePixel = 0
    local hT = Instance.new("TextLabel", hdr)
    hT.Size = UDim2.new(1,-8,1,0); hT.Position = UDim2.new(0,8,0,0); hT.BackgroundTransparency = 1
    hT.Text = title; hT.TextColor3 = C.TEXT; hT.Font = Enum.Font.GothamBold; hT.TextSize = 11; hT.TextXAlignment = Enum.TextXAlignment.Left
    local content = Instance.new("Frame", panel)
    content.Size = UDim2.new(1,0,1,-26); content.Position = UDim2.new(0,0,0,26); content.BackgroundTransparency = 1
    MakeDraggable(panel, hdr)
    return panel, content
end

local function PanelTog(parent, yPos, label, initVal, callback)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,-12,0,26); row.Position = UDim2.new(0,6,0,yPos); row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-46,1,0); lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = C.TEXT; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0,38,0,19); track.Position = UDim2.new(1,-38,0.5,-9.5)
    track.BackgroundColor3 = initVal and C.TOG_ON or C.TOG_OFF; track.BorderSizePixel = 0; Corner(track,9)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,13,0,13)
    knob.Position = initVal and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)
    knob.BackgroundColor3 = C.WHITE; knob.BorderSizePixel = 0; Corner(knob,6)
    local state = initVal
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3=state and C.TOG_ON or C.TOG_OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position=state and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)}):Play()
        if callback then callback(state) end
    end)
    return function(v)
        state=v; track.BackgroundColor3=v and C.TOG_ON or C.TOG_OFF
        knob.Position=v and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)
    end
end

local function PanelBtn(parent, yPos, label, col, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1,-12,0,25); b.Position = UDim2.new(0,6,0,yPos)
    b.BackgroundColor3 = col or C.BTN; b.BorderSizePixel = 0; b.Text = label
    b.TextColor3 = C.WHITE; b.Font = Enum.Font.GothamBold; b.TextSize = 11; Corner(b,5)
    if cb then b.MouseButton1Click:Connect(cb) end; return b
end

-- Panel Chiron TP
local _, ctpC = MakePanel("Chiron TP", -152, 88, 142, 120)
PanelBtn(ctpC, 4,  "🚀 FUCK EM [F]", C.BTN_BLU, function()
    task.spawn(function() teleportAll(); if autoBlockEnabled then task.wait(1); checkForBrainrot() end end)
end)
PanelBtn(ctpC, 32, "🚫 Block All", C.BTN, function() task.spawn(blockAllPlayers) end)
PanelTog(ctpC, 62, "Auto Block", autoBlockEnabled, function(v)
    autoBlockEnabled=v; savedCfg.autoBlock=v; saveConfig(savedCfg)
end)
PanelBtn(ctpC, 90, "Rebind [F]", C.BTN, function()
    keybindBtn.Text = "Press a key..."; waitingForKey = true; MainWin.Visible = true; SwitchTab("Main")
end)

-- =============================================
-- [ PANEL AP SPAMMER (THORIUM) ] --
-- =============================================
local apPanel, apContent = MakePanel("AP Spammer", -152, 221, 142, 0)

-- Liste scrollable des joueurs dans le panel
local apScroll = Instance.new("ScrollingFrame", apContent)
apScroll.Size = UDim2.new(1,0,1,-32); apScroll.Position = UDim2.new(0,0,0,0)
apScroll.BackgroundTransparency = 1; apScroll.BorderSizePixel = 0
apScroll.ScrollBarThickness = 3; apScroll.ScrollBarImageColor3 = C.ACCENT
apScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local apLayout = Instance.new("UIListLayout", apScroll)
apLayout.FillDirection = Enum.FillDirection.Vertical
apLayout.Padding = UDim.new(0,4)
apLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Bouton Stop All en bas du panel
local stopAllBtn = Instance.new("TextButton", apContent)
stopAllBtn.Size = UDim2.new(1,-12,0,24); stopAllBtn.Position = UDim2.new(0,6,1,-28)
stopAllBtn.BackgroundColor3 = C.BTN_RED; stopAllBtn.BorderSizePixel = 0
stopAllBtn.Text = "⛔ Stop All Spam"; stopAllBtn.TextColor3 = C.WHITE
stopAllBtn.Font = Enum.Font.GothamBold; stopAllBtn.TextSize = 10; Corner(stopAllBtn,5)
stopAllBtn.MouseButton1Click:Connect(stopAllSpam)

local function createAPRow(player)
    if player == lp then return end

    local row = Instance.new("Frame", apScroll)
    row.Name = "APRow_"..player.UserId
    row.Size = UDim2.new(1,-8,0,34); row.BackgroundColor3 = Color3.fromRGB(38,34,55)
    row.BorderSizePixel = 0; Corner(row,6)

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1,-68,1,0); nameLbl.Position = UDim2.new(0,6,0,0)
    nameLbl.BackgroundTransparency = 1; nameLbl.Text = player.Name
    nameLbl.TextColor3 = C.TEXT; nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 10; nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local spamBtn = Instance.new("TextButton", row)
    spamBtn.Size = UDim2.new(0,58,0,22); spamBtn.Position = UDim2.new(1,-62,0.5,-11)
    spamBtn.BackgroundColor3 = C.BTN_RED; spamBtn.BorderSizePixel = 0
    spamBtn.Text = "⚡SPAM"; spamBtn.TextColor3 = C.WHITE
    spamBtn.Font = Enum.Font.GothamBold; spamBtn.TextSize = 10; Corner(spamBtn,5)

    local active = false
    spamBtn.MouseButton1Click:Connect(function()
        active = not active
        if active then
            spamBtn.BackgroundColor3 = C.BTN_GRN; spamBtn.Text = "STOP"
            startSpam(player)
        else
            spamBtn.BackgroundColor3 = C.BTN_RED; spamBtn.Text = "⚡SPAM"
            stopSpam(player)
        end
    end)

    player.AncestryChanged:Connect(function()
        if not player.Parent then
            spamming[player.UserId] = nil
            row:Destroy()
            -- Redimensionner le panel
        end
    end)

    return row
end

local function refreshAPList()
    for _, child in ipairs(apScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp then
            createAPRow(player)
            count = count + 1
        end
    end
    -- Ajuste la hauteur du panel dynamiquement
    local panelH = math.max(90, 26 + math.min(count, 4) * 38 + 36)
    apPanel.Size = UDim2.new(0,142,0,panelH)
    apContent.Size = UDim2.new(1,0,1,-26)
    apScroll.Size = UDim2.new(1,0,1,-32)
end

Players.PlayerAdded:Connect(function(player)
    task.wait(1); createAPRow(player); refreshAPList()
end)
Players.PlayerRemoving:Connect(function(player)
    spamming[player.UserId] = nil
    local row = apScroll:FindFirstChild("APRow_"..player.UserId)
    if row then row:Destroy() end
    refreshAPList()
end)

-- Panel Auto Farm
local _, farmC = MakePanel("Auto Farm", -152, 360, 142, 92)
local updateRightPanel = PanelTog(farmC, 4,  "Auto Right", savedCfg.autoRight, function(v)
    savedCfg.autoRight=v; saveConfig(savedCfg); ToggleAutoRight(v)
end)
local updateLeftPanel  = PanelTog(farmC, 32, "Auto Left",  savedCfg.autoLeft, function(v)
    savedCfg.autoLeft=v; saveConfig(savedCfg); ToggleAutoLeft(v)
end)
local updateBatPanel   = PanelTog(farmC, 60, "Bat Aimbot", savedCfg.batAimbot, function(v)
    Enabled.BatAimbot=v; savedCfg.batAimbot=v; saveConfig(savedCfg)
    if v then startBatAimbot() else stopBatAimbot() end; setBatAim(v)
end)

-- Panel Instant Steal V2
local _, stealC = MakePanel("Instant Steal V2", -152, 465, 142, 102)
PanelTog(stealC, 4,  "Giant Potion", savedCfg.giantPotion, function(v) savedCfg.giantPotion=v; saveConfig(savedCfg) end)
PanelBtn(stealC, 32, "Activate (Reset)", C.BTN, function() end)
PanelBtn(stealC, 60, "Execute (F)", C.ACCENT, function()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then v.HoldDuration=0 end
    end
end)

-- Panel Booster
local _, boostC = MakePanel("Booster", -152, 580, 142, 100)
local walkLbl = Instance.new("TextLabel", boostC)
walkLbl.Size = UDim2.new(1,-12,0,16); walkLbl.Position = UDim2.new(0,6,0,3)
walkLbl.BackgroundTransparency = 1; walkLbl.Text = "Walk Speed  0"
walkLbl.TextColor3 = C.SUB; walkLbl.Font = Enum.Font.Gotham; walkLbl.TextSize = 10; walkLbl.TextXAlignment = Enum.TextXAlignment.Left
PanelTog(boostC, 22, "Walk Speed",  savedCfg.walkSpeed,  function(v) cfg.speed=v; savedCfg.walkSpeed=v; saveConfig(savedCfg) end)
PanelTog(boostC, 50, "Steal Speed", savedCfg.stealSpeed, function(v) cfg.fastSteal=v; savedCfg.stealSpeed=v; saveConfig(savedCfg) end)

-- Panel Base Prot
local _, bpC = MakePanel("Base Prot", -152, 693, 142, 112)
PanelBtn(bpC, 4,  "AP Spam Nearest [Q]", C.BTN, function()
    -- Spam le joueur le plus proche
    local hrp = GetRootPart(); if not hrp then return end
    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local eh = p.Character:FindFirstChild("HumanoidRootPart")
            if eh then
                local d = (eh.Position - hrp.Position).Magnitude
                if d < nearestDist then nearestDist=d; nearest=p end
            end
        end
    end
    if nearest then startSpam(nearest) end
end)
PanelBtn(bpC, 32, "Insta Reset [R]", C.BTN_RED, function()
    local h=GetHumanoid(); if h then h.Health=0 end
end)
PanelTog(bpC, 62, "Spam If Stealing", savedCfg.spamSteal,   function(v) savedCfg.spamSteal=v; saveConfig(savedCfg) end)
PanelTog(bpC, 88, "Balloon In Base",  savedCfg.balloonBase, function(v) savedCfg.balloonBase=v; saveConfig(savedCfg) end)

-- Panel Server
local _, srvC = MakePanel("Server", -152, 818, 142, 100)
PanelBtn(srvC, 4,  "Rejoin Server", C.BTN, function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)
PanelBtn(srvC, 32, "Kick Self",   C.BTN,     function() LocalPlayer:Kick("Medusa Hub") end)
PanelBtn(srvC, 60, "Force Reset", C.BTN_RED, function() local h=GetHumanoid(); if h then h.Health=0 end end)

-- =============================================
-- [ KEYBINDS ] --
-- =============================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if waitingForKey and input.UserInputType == Enum.UserInputType.Keyboard then
        teleportKey = input.KeyCode
        keybindBtn.Text = "Keybind: ["..teleportKey.Name.."]"
        waitingForKey = false
        return
    end

    if input.KeyCode == Enum.KeyCode.K then
        MainWin.Visible = not MainWin.Visible

    elseif input.KeyCode == teleportKey then
        task.spawn(function()
            teleportAll()
            if autoBlockEnabled then task.wait(1); checkForBrainrot() end
        end)

    elseif input.KeyCode == Enum.KeyCode.Q then
        -- Q = AP Spam nearest
        local hrp = GetRootPart(); if not hrp then return end
        local nearest, nearestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local eh = p.Character:FindFirstChild("HumanoidRootPart")
                if eh then
                    local d = (eh.Position - hrp.Position).Magnitude
                    if d < nearestDist then nearestDist=d; nearest=p end
                end
            end
        end
        if nearest then
            if spamming[nearest.UserId] then stopSpam(nearest)
            else startSpam(nearest) end
        end

    elseif input.KeyCode == Enum.KeyCode.R then
        local h = GetHumanoid(); if h then h.Health=0 end
    end
end)

-- =============================================
-- [ FONCTIONS CORE ] --
-- =============================================

local function getBat()
    local c = LocalPlayer.Character; if not c then return nil end
    local tool = c:FindFirstChildWhichIsA("Tool")
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
            local tv = torso.AssemblyLinearVelocity
            local dir = torso.Position - h.Position
            local flatDist = Vector3.new(dir.X,0,dir.Z).Magnitude
            local pred = torso.Position + tv*(flatDist/80)
            local spd = 58
            if flatDist > 1 then
                local md = Vector3.new(pred.X-h.Position.X,0,pred.Z-h.Position.Z).Unit
                local yDiff = torso.Position.Y - h.Position.Y
                local ys = math.abs(yDiff)>0.5 and math.clamp(yDiff*8,-100,100) or tv.Y
                h.AssemblyLinearVelocity = Vector3.new(md.X*spd,ys,md.Z*spd)
            else h.AssemblyLinearVelocity = tv end
        end
    end)
end

function stopBatAimbot()
    if Connections.batAimbot then Connections.batAimbot:Disconnect(); Connections.batAimbot=nil end
end

function startHalfTP()
    if halfTpConnection then return end
    halfTpConnection = RunService.Heartbeat:Connect(function()
        if not cfg.halfTP then return end
        local c = LocalPlayer.Character; if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local nearest, nearestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local eh = p.Character:FindFirstChild("HumanoidRootPart")
                if eh then
                    local d = (eh.Position - hrp.Position).Magnitude
                    if d < nearestDist then nearestDist=d; nearest=eh end
                end
            end
        end
        if nearest and nearestDist > 6 then
            local mid = (hrp.Position + nearest.Position) / 2
            hrp.CFrame = CFrame.new(mid) * (nearest.CFrame - nearest.CFrame.Position)
        end
    end)
end

function stopHalfTP()
    if halfTpConnection then halfTpConnection:Disconnect(); halfTpConnection=nil end
end

-- ANTI RAGDOLL
local antiRagdollMode = nil
local ragdollConnections = {}
local cachedCharData = {}
local isBoosting = false
local BOOST_SPEED = 400
local AR_DEFAULT_SPEED = 16

local function arCache()
    local c = Player.Character; if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    local root = c:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = {character=c,humanoid=hum,root=root}; return true
end

local function arDisconnect()
    for _, c in ipairs(ragdollConnections) do pcall(function() c:Disconnect() end) end
    ragdollConnections = {}
end

local function arIsRag()
    if not cachedCharData.humanoid then return false end
    local s = cachedCharData.humanoid:GetState()
    local rs = {[Enum.HumanoidStateType.Physics]=true,[Enum.HumanoidStateType.Ragdoll]=true,[Enum.HumanoidStateType.FallingDown]=true}
    if rs[s] then return true end
    local et = Player:GetAttribute("RagdollEndTime")
    return et and (et - workspace:GetServerTimeNow()) > 0
end

local function arForceExit()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function() Player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
    for _, d in ipairs(cachedCharData.character:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then d:Destroy() end
    end
    if not isBoosting then isBoosting=true; cachedCharData.humanoid.WalkSpeed=BOOST_SPEED end
    if cachedCharData.humanoid.Health > 0 then cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running) end
    cachedCharData.root.Anchored = false
end

local function arLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        local rag = arIsRag()
        if rag then arForceExit()
        elseif isBoosting then
            isBoosting=false
            if cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed=AR_DEFAULT_SPEED end
        end
    end
end

function startAntiRagdoll()
    if antiRagdollMode == "v1" then return end
    if not arCache() then return end
    antiRagdollMode = "v1"
    table.insert(ragdollConnections, RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then cam.CameraSubject=cachedCharData.humanoid end
    end))
    table.insert(ragdollConnections, Player.CharacterAdded:Connect(function()
        isBoosting=false; task.wait(0.5); arCache()
    end))
    task.spawn(arLoop)
end

function stopAntiRagdoll()
    antiRagdollMode=nil
    if isBoosting and cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed=AR_DEFAULT_SPEED end
    isBoosting=false; arDisconnect(); cachedCharData={}
end

-- AUTO WALK
local FORWARD_SPEED = 59
local RETURN_SPEED  = 29
local RIGHT_PATH = {
    Vector3.new(-473.32,-7.67,10.16), Vector3.new(-472.71,-8.14,29.92),
    Vector3.new(-472.87,-8.14,49.50), Vector3.new(-472.45,-8.14,65.05),
    Vector3.new(-472.94,-8.14,82.48), Vector3.new(-475.00,-8.14,96.84), Vector3.new(-485.50,-6.43,96.08),
}
local LEFT_PATH = {
    Vector3.new(-473.31,-7.67,111.75), Vector3.new(-473.51,-8.14,87.30),
    Vector3.new(-473.74,-8.14,60.58),  Vector3.new(-474.04,-8.14,41.38),
    Vector3.new(-474.35,-8.14,25.77),  Vector3.new(-485.30,-6.43,22.36),
}
local RIGHT_RETURN = {Vector3.new(-475.23,-8.14,90.61),Vector3.new(-476.24,-8.14,57.32),Vector3.new(-475.63,-8.14,23.36)}
local LEFT_RETURN  = {Vector3.new(-474.23,-8.14,26.51),Vector3.new(-475.15,-8.14,59.32),Vector3.new(-475.62,-8.06,97.99)}
local waypoints, returnWaypoints = {}, {}
local returnWaypointIndex = 1

local function StopAutoWalk()
    if AutoWalkConnection then AutoWalkConnection:Disconnect(); AutoWalkConnection=nil end
    waypoints={}; returnWaypoints={}; currentWaypointIndex=1; returnWaypointIndex=1
    isAutoWalking=false; isReturning=false; isPaused=false
    local h=GetHumanoid(); if h then h:Move(Vector3.new(0,0,0)) end
    local r=GetRootPart(); if r then r.AssemblyLinearVelocity=Vector3.new(0,0,0) end
end

local function FindClosest(pos, list)
    local ci, cd = 1, math.huge
    for i, wp in ipairs(list) do
        local d=(Vector3.new(wp.X,pos.Y,wp.Z)-pos).Magnitude
        if d<cd then cd=d; ci=i end
    end
    return ci
end

local function StartAutoWalk(direction)
    StopAutoWalk()
    local rp = GetRootPart(); if not rp then return end
    if direction=="right" then waypoints=RIGHT_PATH; returnWaypoints=RIGHT_RETURN
    elseif direction=="left" then waypoints=LEFT_PATH; returnWaypoints=LEFT_RETURN end
    currentWaypointIndex=FindClosest(rp.Position,waypoints)
    returnWaypointIndex=1; isAutoWalking=true; isReturning=false; isPaused=false
    AutoWalkConnection = RunService.Heartbeat:Connect(function()
        if IsShuttingDown then return end
        if not Config.AutoRight and not Config.AutoLeft then StopAutoWalk(); return end
        if isPaused then return end
        if HasBrainrotInHand and not isReturning then isReturning=true; returnWaypointIndex=1 end
        local hum=GetHumanoid(); local rp2=GetRootPart()
        if not hum or not rp2 or not isAutoWalking then return end
        local tp = isReturning and returnWaypoints[returnWaypointIndex] or waypoints[currentWaypointIndex]
        if not tp then return end
        local dv=(tp-rp2.Position)*Vector3.new(1,0,1); local dist=dv.Magnitude; local md=dv.Unit
        hum:Move(md)
        local spd = isReturning and RETURN_SPEED or FORWARD_SPEED
        rp2.AssemblyLinearVelocity = Vector3.new(md.X*spd, rp2.AssemblyLinearVelocity.Y, md.Z*spd)
        if dist < 3 then
            if not isReturning then
                currentWaypointIndex=currentWaypointIndex+1
                if currentWaypointIndex>#waypoints then
                    isPaused=true; hum:Move(Vector3.new(0,0,0))
                    rp2.AssemblyLinearVelocity=Vector3.new(0,rp2.AssemblyLinearVelocity.Y,0)
                    task.spawn(function() task.wait(0.3); isReturning=true; returnWaypointIndex=1; isPaused=false end)
                end
            else
                returnWaypointIndex=returnWaypointIndex+1
                if returnWaypointIndex>#returnWaypoints then
                    isPaused=true; hum:Move(Vector3.new(0,0,0))
                    if Config.AutoRight then Config.AutoRight=false; if ToggleFunctions["AutoRight"] then ToggleFunctions["AutoRight"](false) end
                    elseif Config.AutoLeft then Config.AutoLeft=false; if ToggleFunctions["AutoLeft"] then ToggleFunctions["AutoLeft"](false) end end
                    StopAutoWalk()
                end
            end
        end
    end)
end

function ToggleAutoRight(enabled)
    Config.AutoRight=enabled
    if enabled then
        Config.AutoLeft=false; if ToggleFunctions["AutoLeft"] then ToggleFunctions["AutoLeft"](false) end
        StartAutoWalk("right")
    else if not Config.AutoLeft then StopAutoWalk() end end
end

function ToggleAutoLeft(enabled)
    Config.AutoLeft=enabled
    if enabled then
        Config.AutoRight=false; if ToggleFunctions["AutoRight"] then ToggleFunctions["AutoRight"](false) end
        StartAutoWalk("left")
    else if not Config.AutoRight then StopAutoWalk() end end
end

ToggleFunctions["AutoRight"] = function(v) updateRightPanel(v) end
ToggleFunctions["AutoLeft"]  = function(v) updateLeftPanel(v) end

-- XRAY
local origTransparency = {}
function enableXRay()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and
               (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                origTransparency[obj]=obj.LocalTransparencyModifier; obj.LocalTransparencyModifier=0.85
            end
        end
    end)
end

function disableXRay()
    for part,val in pairs(origTransparency) do if part then part.LocalTransparencyModifier=val end end
    origTransparency={}
end

-- ASPECT RATIO STRETCH
function enableAspectRatio()
    if stretchGui then stretchGui:Destroy() end
    stretchGui = Instance.new("ScreenGui", CoreGui)
    stretchGui.Name = "MedusaStretch"; stretchGui.ResetOnSpawn=false
    stretchGui.DisplayOrder=-999; stretchGui.IgnoreGuiInset=true
    local vp = Instance.new("ViewportFrame", stretchGui)
    vp.Size = UDim2.new(1,0,1,0); vp.BackgroundTransparency=1; vp.BorderSizePixel=0
    stretchCam = Instance.new("Camera"); stretchCam.Parent=vp; vp.CurrentCamera=stretchCam
    aspectRatioConnection = RunService.RenderStepped:Connect(function()
        if not cfg.aspectRatio then return end
        local realCam = workspace.CurrentCamera
        if not realCam or not stretchCam then return end
        stretchCam.CFrame = realCam.CFrame
        local vp_size = realCam.ViewportSize
        local hfov = 2 * math.atan(math.tan(math.rad(realCam.FieldOfView)/2) * (vp_size.X/vp_size.Y))
        local vfov = 2 * math.atan(math.tan(hfov/2) / (4/3))
        stretchCam.FieldOfView = math.deg(vfov)
    end)
end

function disableAspectRatio()
    if aspectRatioConnection then aspectRatioConnection:Disconnect(); aspectRatioConnection=nil end
    if stretchGui then stretchGui:Destroy(); stretchGui=nil end
    stretchCam=nil
end

-- OPTIMIZER
function applyOptimizer(state)
    if state then
        Lighting.GlobalShadows=false
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then v.Material=Enum.Material.Plastic; v.Reflectance=0
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1 end
        end
    else Lighting.GlobalShadows=true end
end

-- ESP
local function CreateBoxESP(p)
    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = p.Character.HumanoidRootPart
        if not hrp:FindFirstChild("MedusaBox") then
            local b=Instance.new("BillboardGui",hrp); b.Name="MedusaBox"; b.AlwaysOnTop=true; b.Size=UDim2.new(4.5,0,6,0); b.Adornee=hrp
            local fr=Instance.new("Frame",b); fr.Size=UDim2.new(1,0,1,0); fr.BackgroundTransparency=0.7; fr.BackgroundColor3=C.ACCENT
            Instance.new("UIStroke",fr).Color=C.WHITE
            local tl=Instance.new("TextLabel",b); tl.Size=UDim2.new(1,0,0.2,0); tl.Position=UDim2.new(0,0,-0.25,0); tl.BackgroundTransparency=1
            tl.Text=p.Name; tl.TextColor3=C.WHITE; tl.Font="GothamBold"; tl.TextSize=10
        end
    end
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
                        local gui=Instance.new("BillboardGui",main); gui.Name="TimerESP_Gui"
                        gui.Size=UDim2.new(0,100,0,40); gui.StudsOffset=Vector3.new(0,3,0); gui.AlwaysOnTop=true
                        local txt=Instance.new("TextLabel",gui); txt.Size=UDim2.new(1,0,1,0); txt.BackgroundTransparency=1
                        txt.TextColor3=C.ACCENT; txt.Font="GothamBold"; txt.TextSize=14; txt.TextStrokeTransparency=0; txt.Text=remTime.Text
                    else
                        local tl=existing:FindFirstChildOfClass("TextLabel")
                        if tl then tl.Text=remTime.Text end
                    end
                elseif existing then existing:Destroy() end
            end
        end
    end
end

-- =============================================
-- [ BOUCLE PRINCIPALE ] --
-- =============================================
RunService.RenderStepped:Connect(function()
    local fps = math.floor(1/math.max(RunService.RenderStepped:Wait(), 0.001))
    local pingOk, ping = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")
    end)
    FPSStats.Text = "FPS: "..fps.."  PING: "..(pingOk and ping or "--").."ms"

    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local vel = lp.Character.HumanoidRootPart.Velocity
        local spd = math.floor(Vector3.new(vel.X,0,vel.Z).Magnitude)
        speedLabel.Text = spd.." sp"
        walkLbl.Text = "Walk Speed  "..spd
    end

    if cfg.speed and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            hrp.Velocity = Vector3.new(hum.MoveDirection.X*57, hrp.Velocity.Y, hum.MoveDirection.Z*57)
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
                if p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and hrp:FindFirstChild("MedusaBox") then hrp.MedusaBox:Destroy() end
                end
            end
        end
        if cfg.fastSteal or cfg.instSteal then
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") then v.HoldDuration=0 end
            end
        end
    end
end)

-- =============================================
-- [ INIT ] --
-- =============================================
task.spawn(function()
    task.wait(1)
    if cfg.antiRagdoll then startAntiRagdoll() end
    if cfg.halfTP       then startHalfTP() end
    if cfg.xray         then enableXRay() end
    if cfg.optimizer    then applyOptimizer(true) end
    if cfg.darkMode     then Lighting.Brightness=0.1; Lighting.ClockTime=0 end
    if cfg.aspectRatio  then enableAspectRatio() end
    if cfg.antiTrap then
        antiTrapConnection = RunService.Heartbeat:Connect(function()
            local trap = Workspace:FindFirstChild("Trap")
            if trap and trap:IsA("Model") then trap:Destroy() end
        end)
    end
    if Enabled.BatAimbot   then startBatAimbot() end
    if Config.AutoRight     then ToggleAutoRight(true) end
    if Config.AutoLeft      then ToggleAutoLeft(true) end
    setupBrainrotDetection()
    refreshAPList()
end)

-- =============================================
-- [ NOTIFICATION ] --
-- =============================================
task.spawn(function()
    task.wait(0.5)
    local ng = Instance.new("ScreenGui", CoreGui)
    ng.Name="MedusaNotif"; ng.ResetOnSpawn=false; ng.DisplayOrder=9999
    local nf = Instance.new("Frame", ng)
    nf.Size=UDim2.new(0,300,0,48); nf.Position=UDim2.new(0.5,-150,1,10)
    nf.BackgroundColor3=C.HEADER; nf.BorderSizePixel=0; Corner(nf,8); Stroke(nf,C.ACCENT,1.5)
    local nl = Instance.new("TextLabel", nf)
    nl.Size=UDim2.new(1,0,1,0); nl.BackgroundTransparency=1
    nl.Text="✓  MEDUSA HUB V57  •  Paramètres chargés\n[K] menu  •  [F] TP  •  [Q] AP Spam  •  [R] reset"
    nl.TextColor3=C.TEXT; nl.Font=Enum.Font.GothamBold; nl.TextSize=11
    TweenService:Create(nf, TweenInfo.new(0.4,Enum.EasingStyle.Back), {Position=UDim2.new(0.5,-150,1,-60)}):Play()
    task.wait(4)
    TweenService:Create(nf, TweenInfo.new(0.3), {Position=UDim2.new(0.5,-150,1,10)}):Play()
    task.wait(0.4); ng:Destroy()
end)
