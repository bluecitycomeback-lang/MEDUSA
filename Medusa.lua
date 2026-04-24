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
local ProximityPromptService = game:GetService("ProximityPromptService")

-- =============================================
-- [ SAUVEGARDE ] --
-- =============================================
local CONFIG_FILE = "MedusaHubV57_Config.json"

local defaultConfig = {
    speed=false, antiRagdoll=false, fastSteal=false, instSteal=false,
    esp=false, xray=false, infJump=false, optimizer=false, timerEsp=false,
    antiTrap=false, halfTP=false, aspectRatio=false, darkMode=false,
    batAimbot=false, autoRight=false, autoLeft=false, giantPotion=false,
    walkSpeed=false, stealSpeed=false, spamSteal=false, balloonBase=false,
    autoBlock=true, blockDelay=0.7,
}

local function loadConfig()
    local ok, data = pcall(function()
        if not isfile(CONFIG_FILE) then return nil end
        return game:GetService("HttpService"):JSONDecode(readfile(CONFIG_FILE))
    end)
    if ok and data then
        for k,v in pairs(defaultConfig) do if data[k]==nil then data[k]=v end end
        return data
    end
    return defaultConfig
end

local function saveConfig(t)
    pcall(function() writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(t)) end)
end

local savedCfg = loadConfig()

-- =============================================
-- [ VARIABLES ] --
-- =============================================
local cfg = {
    speed=savedCfg.speed, antiRagdoll=savedCfg.antiRagdoll,
    fastSteal=savedCfg.fastSteal, instSteal=savedCfg.instSteal,
    esp=savedCfg.esp, xray=savedCfg.xray, infJump=savedCfg.infJump,
    optimizer=savedCfg.optimizer, timerEsp=savedCfg.timerEsp,
    antiTrap=savedCfg.antiTrap, halfTP=savedCfg.halfTP,
    aspectRatio=savedCfg.aspectRatio, darkMode=savedCfg.darkMode,
    giantPotion=savedCfg.giantPotion,
}

local function persistCfg()
    for k,v in pairs(cfg) do savedCfg[k]=v end
    saveConfig(savedCfg)
end

local Config = {AutoRight=savedCfg.autoRight, AutoLeft=savedCfg.autoLeft}
local ToggleFunctions = {}
local Connections = {}
local Enabled = {BatAimbot=savedCfg.batAimbot}
local AutoWalkConnection = nil
local isAutoWalking, isReturning, isPaused = false, false, false
local currentWaypointIndex = 1
local IsShuttingDown = false
local HasBrainrotInHand = false
local antiTrapConnection = nil
local halfTpConnection = nil
local aspectRatioConnection = nil
local stretchGui = nil
local stretchCam = nil

-- =============================================
-- [ SLOT STEAL SYSTEM (KACOW) ] --
-- =============================================
local pos1 = Vector3.new(-352.98, -7, 74.30)
local pos2 = Vector3.new(-352.98, -6.49, 45.76)

local spot1_sequence = {
    CFrame.new(-370.810913,-7.00000334,41.2687263,0.99984771,1.22364419e-09,0.0174523517,-6.54859778e-10,1,-3.2596418e-08,-0.0174523517,3.25800258e-08,0.99984771),
    CFrame.new(-336.355286,-5.10107088,17.2327671,-0.999883354,-2.76150569e-08,0.0152716246,-2.88224964e-08,1,-7.88441525e-08,-0.0152716246,-7.9275118e-08,-0.999883354)
}

local spot2_sequence = {
    CFrame.new(-354.782867,-7.00000334,92.8209305,-0.999997616,-1.11891862e-09,-0.00218066527,-1.11958298e-09,1,3.03415071e-10,0.00218066527,3.05855785e-10,-0.999997616),
    CFrame.new(-336.942902,-5.10106993,99.3276443,0.999914348,-3.63984611e-08,0.0130875716,3.67094941e-08,1,-2.35254749e-08,-0.0130875716,2.40038975e-08,0.999914348)
}

local allAnimalsCache = {}
local PromptMemoryCache = {}
local InternalStealCache = {}
local IsStealing = false
local StealProgress = 0
local CurrentStealTarget = nil
local selectedSlot = nil -- slot sélectionné manuellement
local AUTO_STEAL_PROX_RADIUS = 200

local function getHRP()
    local char = lp.Character; if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function isMyBase(plotName)
    local plot = workspace.Plots:FindFirstChild(plotName); if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    return sign and sign:FindFirstChild("YourBase") and sign.YourBase.Enabled
end

local function scanSinglePlot(plot)
    if not plot or not plot:IsA("Model") or isMyBase(plot.Name) then return end
    local podiums = plot:FindFirstChild("AnimalPodiums"); if not podiums then return end
    for _, podium in ipairs(podiums:GetChildren()) do
        if podium:IsA("Model") and podium:FindFirstChild("Base") then
            table.insert(allAnimalsCache, {
                plot = plot.Name,
                slot = podium.Name,
                worldPosition = podium:GetPivot().Position,
                uid = plot.Name.."_"..podium.Name,
                displayName = plot.Name.." / Slot "..podium.Name,
            })
        end
    end
end

local function initializeScanner()
    task.wait(2)
    local plots = workspace:WaitForChild("Plots", 10)
    for _, plot in ipairs(plots:GetChildren()) do scanSinglePlot(plot) end
    plots.ChildAdded:Connect(scanSinglePlot)
    task.spawn(function()
        while task.wait(5) do
            table.clear(allAnimalsCache)
            for _, plot in ipairs(plots:GetChildren()) do scanSinglePlot(plot) end
        end
    end)
end

local function findPrompt(animal)
    local cached = PromptMemoryCache[animal.uid]
    if cached and cached.Parent then return cached end
    local plot = workspace.Plots:FindFirstChild(animal.plot)
    local podium = plot and plot.AnimalPodiums:FindFirstChild(animal.slot)
    local prompt = podium and podium.Base.Spawn.PromptAttachment:FindFirstChildOfClass("ProximityPrompt")
    if prompt then PromptMemoryCache[animal.uid] = prompt end
    return prompt
end

local function buildStealCallbacks(prompt)
    if InternalStealCache[prompt] then return end
    local data = {holdCallbacks={}, triggerCallbacks={}, ready=true}
    local ok1, conns1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
    if ok1 then for _, c in ipairs(conns1) do table.insert(data.holdCallbacks, c.Function) end end
    local ok2, conns2 = pcall(getconnections, prompt.Triggered)
    if ok2 then for _, c in ipairs(conns2) do table.insert(data.triggerCallbacks, c.Function) end end
    InternalStealCache[prompt] = data
end

local function useGiantPotion()
    if not cfg.giantPotion then return end
    local bp = lp:FindFirstChild("Backpack"); if not bp then return end
    local potion = bp:FindFirstChild("Giant Potion")
    local char = lp.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum or not potion then return end
    hum:EquipTool(potion)
    task.wait(0.1)
    pcall(function() potion:Activate() end)
end

local function executeSlotSteal(animal, useSpot2)
    local prompt = findPrompt(animal); if not prompt then return end
    buildStealCallbacks(prompt)
    local data = InternalStealCache[prompt]
    if not data or not data.ready or IsStealing then return end

    data.ready = false; IsStealing = true; StealProgress = 0; CurrentStealTarget = animal
    local tpDone = false
    local seq = useSpot2 and spot2_sequence or spot1_sequence

    task.spawn(function()
        for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
        local startTime = tick()
        while tick()-startTime < 1.3 do
            StealProgress = (tick()-startTime)/1.3
            if StealProgress >= 0.73 and not tpDone then
                tpDone = true
                local hrp = getHRP()
                if hrp then
                    hrp.CFrame = seq[1]; task.wait(0.1)
                    hrp.CFrame = seq[2]; task.wait(0.2)
                    local d1 = (hrp.Position-pos1).Magnitude
                    local d2 = (hrp.Position-pos2).Magnitude
                    hrp.CFrame = CFrame.new(d1<d2 and pos1 or pos2)
                    useGiantPotion()
                end
            end
            task.wait()
        end
        StealProgress = 1
        for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
        task.wait(0.2)
        data.ready = true; IsStealing = false; StealProgress = 0; CurrentStealTarget = nil
    end)
end

local function getNearestAnimal()
    local hrp = getHRP(); if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, animal in ipairs(allAnimalsCache) do
        local d = (hrp.Position-animal.worldPosition).Magnitude
        if d < dist and d <= AUTO_STEAL_PROX_RADIUS then dist=d; nearest=animal end
    end
    return nearest
end

-- =============================================
-- [ CHIRON TP ] --
-- =============================================
local backpack = lp:WaitForChild("Backpack")
local charTP = lp.Character or lp.CharacterAdded:Wait()
local humanoidTP = charTP:WaitForChild("Humanoid")
local hrpTP = charTP:WaitForChild("HumanoidRootPart")

lp.CharacterAdded:Connect(function(c)
    charTP=c; humanoidTP=c:WaitForChild("Humanoid"); hrpTP=c:WaitForChild("HumanoidRootPart")
end)

local blockDelay = savedCfg.blockDelay or 0.7
local minDelay, maxDelay = 0.1, 5.0
local autoBlockEnabled = savedCfg.autoBlock
local teleportKey = Enum.KeyCode.F
local waitingForKey = false
local REQUIRED_TOOL = "Flying Carpet"

local spots = {
    CFrame.new(-402.18,-6.34,131.83)*CFrame.Angles(0,math.rad(-20.08),0),
    CFrame.new(-416.66,-6.34,-2.05)*CFrame.Angles(0,math.rad(-62.89),0),
    CFrame.new(-329.37,-4.68,18.12)*CFrame.Angles(0,math.rad(-30.53),0),
}

local function FastClick()
    task.wait(blockDelay)
    local cam = workspace.CurrentCamera.ViewportSize
    local x,y = cam.X/2, cam.Y/2+23
    for _=1,8 do
        VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,1)
        VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,1)
        task.wait(0.008)
    end
end

local function blockPlayer(plr)
    if not plr or plr==lp then return end
    pcall(function() StarterGui:SetCore("PromptBlockPlayer",plr) end)
end

local function equipFlyingCarpet()
    local tool = backpack:FindFirstChild(REQUIRED_TOOL) or charTP:FindFirstChild(REQUIRED_TOOL)
    if not tool then return false end
    if tool.Parent ~= charTP then
        humanoidTP:EquipTool(tool)
        repeat task.wait() until tool.Parent==charTP
    end
    return true
end

local function checkForBrainrot()
    if not autoBlockEnabled then return false end
    local keywords = {"brainrot","animal","monkey","dog","cat","bird"}
    local function hasKW(name)
        local n=name:lower()
        for _,kw in ipairs(keywords) do if n:find(kw) then return true end end
        return false
    end
    local function checkTools(container)
        for _,tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and hasKW(tool.Name) then
                for _,other in ipairs(Players:GetPlayers()) do
                    if other~=lp and other.Character then
                        local ob=other:FindFirstChild("Backpack")
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
        charTP=newChar
        newChar.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then task.wait(0.5); checkForBrainrot() end
        end)
        task.wait(1); checkForBrainrot()
    end)
end

local function teleportAll()
    if not equipFlyingCarpet() then return end
    local lastTarget=nil
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=lp then lastTarget=plr; break end
    end
    for _,spot in ipairs(spots) do equipFlyingCarpet(); hrpTP.CFrame=spot; task.wait(0.12) end
    if lastTarget and autoBlockEnabled then blockPlayer(lastTarget); FastClick() end
end

local function blockAllPlayers()
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=lp then blockPlayer(plr); FastClick(); task.wait(0.25) end
    end
end

-- =============================================
-- [ BASE PROTECT - BALLOON + ROCKET ] --
-- =============================================
local baseProtActive = false
local baseProtConnection = nil

local function useTool(toolName)
    local char = lp.Character; if not char then return end
    local bp = lp:FindFirstChild("Backpack"); if not bp then return end
    local tool = bp:FindFirstChild(toolName) or char:FindFirstChild(toolName)
    if not tool then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if tool.Parent ~= char then hum:EquipTool(tool); task.wait(0.15) end
    pcall(function() tool:Activate() end)
end

local function useToolOnTarget(toolName, targetChar)
    -- Équipe l'outil et l'utilise en direction du voleur
    local char = lp.Character; if not char then return end
    local bp = lp:FindFirstChild("Backpack"); if not bp then return end
    local tool = bp:FindFirstChild(toolName) or char:FindFirstChild(toolName)
    if not tool then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    -- Oriente vers la cible
    if targetChar then
        local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z))
        end
    end
    if tool.Parent ~= char then hum:EquipTool(tool); task.wait(0.15) end
    pcall(function() tool:Activate() end)
    task.wait(0.1)
end

local function startBaseProt()
    if baseProtConnection then return end
    -- Détecte quand quelqu'un vole le brainrot (il disparait de notre char/backpack)
    baseProtConnection = RunService.Heartbeat:Connect(function()
        if not baseProtActive then return end
        -- Cherche le voleur le plus proche
        local hrp = GetRootPart(); if not hrp then return end
        local nearest, nearestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local eh = p.Character:FindFirstChild("HumanoidRootPart")
                if eh then
                    local d = (eh.Position-hrp.Position).Magnitude
                    if d < nearestDist and d < 60 then nearestDist=d; nearest=p end
                end
            end
        end
        if nearest and nearest.Character then
            task.spawn(function()
                useToolOnTarget("Balloon", nearest.Character)
                task.wait(0.2)
                useToolOnTarget("Rocket", nearest.Character)
            end)
        end
    end)
end

local function stopBaseProt()
    if baseProtConnection then baseProtConnection:Disconnect(); baseProtConnection=nil end
end

-- Détection du vol de brainrot pour déclencher auto base prot
RunService.Heartbeat:Connect(function()
    if not baseProtActive then return end
    local char = lp.Character; if not char then return end
    -- Si quelqu'un est dans notre base avec un brainrot
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local pChar = p.Character
            -- Vérifie si le joueur a un brainrot (il vient de voler)
            if pChar:FindFirstChild("Brainrot") then
                local hrp = GetRootPart()
                local pHRP = pChar:FindFirstChild("HumanoidRootPart")
                if hrp and pHRP and (pHRP.Position-hrp.Position).Magnitude < 80 then
                    task.spawn(function()
                        useToolOnTarget("Balloon", pChar)
                        task.wait(0.3)
                        useToolOnTarget("Rocket", pChar)
                    end)
                end
            end
        end
    end
end)

-- =============================================
-- [ AP SPAMMER ] --
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
            if remote then pcall(function() remote:FireServer(player.Character) end) end
            task.wait(0.1)
        end
        spamming[player.UserId] = nil
    end)
end

local function stopSpam(player) spamming[player.UserId] = nil end
local function stopAllSpam() for uid,_ in pairs(spamming) do spamming[uid]=nil end end

-- =============================================
-- [ NETTOYAGE UI ] --
-- =============================================
for _,v in pairs(CoreGui:GetChildren()) do
    if v.Name=="MedusaHubUI" or v.Name=="MedusaNotif" or v.Name=="MedusaStretch"
    or v.Name=="ThoriumDashboard" or v.Name=="ThoriumPlayerList" or v.Name=="CoolHubGui" then v:Destroy() end
end
for _,v in pairs(lp.PlayerGui:GetChildren()) do
    if v.Name=="Rayfield" or v.Name=="MedusaStatsUI" or v.Name=="MedusaPanels" or v.Name=="ChironTP" then v:Destroy() end
end

local function GetHumanoid() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end
local function GetRootPart() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end

RunService.Heartbeat:Connect(function()
    HasBrainrotInHand = lp.Character and lp.Character:FindFirstChild("Brainrot") ~= nil
end)

-- SPEED BILLBOARD
local speedBillboard = Instance.new("BillboardGui")
speedBillboard.Name="CH_SpeedDisplay"; speedBillboard.Size=UDim2.new(0,90,0,26)
speedBillboard.StudsOffset=Vector3.new(0,3.5,0); speedBillboard.AlwaysOnTop=false; speedBillboard.ResetOnSpawn=false
local speedLabel = Instance.new("TextLabel", speedBillboard)
speedLabel.Size=UDim2.new(1,0,1,0); speedLabel.BackgroundTransparency=1
speedLabel.TextColor3=Color3.fromRGB(255,255,255); speedLabel.Font=Enum.Font.GothamBold
speedLabel.TextSize=20; speedLabel.Text="0 sp"; speedLabel.TextStrokeTransparency=0.3
speedLabel.TextStrokeColor3=Color3.fromRGB(0,0,0)
local function attachSpeedDisplay()
    local c=LocalPlayer.Character; if not c then return end
    local hrp=c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    speedBillboard.Adornee=hrp; speedBillboard.Parent=CoreGui
end
LocalPlayer.CharacterAdded:Connect(function(c) c:WaitForChild("HumanoidRootPart"); task.wait(0.1); attachSpeedDisplay() end)
attachSpeedDisplay()

-- =============================================
-- [ THEME ] --
-- =============================================
local C = {
    BG=Color3.fromRGB(28,25,40), HEADER=Color3.fromRGB(20,17,32),
    ACCENT=Color3.fromRGB(120,90,200), TAB_ON=Color3.fromRGB(120,90,200),
    TAB_OFF=Color3.fromRGB(48,44,65), TEXT=Color3.fromRGB(230,225,255),
    SUB=Color3.fromRGB(160,150,190), TOG_ON=Color3.fromRGB(120,90,200),
    TOG_OFF=Color3.fromRGB(65,60,85), PANEL=Color3.fromRGB(32,28,48),
    BTN=Color3.fromRGB(55,50,80), BTN_RED=Color3.fromRGB(150,35,35),
    BTN_GRN=Color3.fromRGB(35,120,60), BTN_BLU=Color3.fromRGB(50,120,220),
    SEP=Color3.fromRGB(60,55,80), WHITE=Color3.new(1,1,1),
    ROW_A=Color3.fromRGB(38,34,55), ROW_B=Color3.fromRGB(42,38,60),
}

local function Corner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 7); return c end
local function Stroke(p,col,t) local s=Instance.new("UIStroke",p); s.Color=col or C.ACCENT; s.Thickness=t or 1.5; return s end

local function MakeDraggable(frame,handle)
    handle=handle or frame
    local dragging,dragStart,startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=frame.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
end

local function TogRow(parent,yPos,label,initVal,callback)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-16,0,30); row.Position=UDim2.new(0,8,0,yPos); row.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-52,1,0); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.TEXT; lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local track=Instance.new("Frame",row)
    track.Size=UDim2.new(0,44,0,22); track.Position=UDim2.new(1,-44,0.5,-11)
    track.BackgroundColor3=initVal and C.TOG_ON or C.TOG_OFF; track.BorderSizePixel=0; Corner(track,11)
    local knob=Instance.new("Frame",track)
    knob.Size=UDim2.new(0,16,0,16)
    knob.Position=initVal and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3=C.WHITE; knob.BorderSizePixel=0; Corner(knob,8)
    local state=initVal
    local btn=Instance.new("TextButton",row)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
    btn.MouseButton1Click:Connect(function()
        state=not state
        TweenService:Create(track,TweenInfo.new(0.15,Enum.EasingStyle.Quad),{BackgroundColor3=state and C.TOG_ON or C.TOG_OFF}):Play()
        TweenService:Create(knob,TweenInfo.new(0.15,Enum.EasingStyle.Quad),{Position=state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        if callback then callback(state) end
    end)
    return function(v)
        state=v; track.BackgroundColor3=v and C.TOG_ON or C.TOG_OFF
        knob.Position=v and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    end
end

local function Sep(parent,yPos,label)
    if label then
        local l=Instance.new("TextLabel",parent)
        l.Size=UDim2.new(1,-16,0,18); l.Position=UDim2.new(0,8,0,yPos)
        l.BackgroundTransparency=1; l.Text=label; l.TextColor3=C.SUB
        l.Font=Enum.Font.GothamBold; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left
    end
    local line=Instance.new("Frame",parent)
    line.Size=UDim2.new(1,-16,0,1); line.Position=UDim2.new(0,8,0,yPos+(label and 18 or 0))
    line.BackgroundColor3=C.SEP; line.BorderSizePixel=0
    return yPos+(label and 20 or 1)
end

local function Btn(parent,yPos,label,col,cb)
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(1,-16,0,27); b.Position=UDim2.new(0,8,0,yPos)
    b.BackgroundColor3=col or C.BTN; b.BorderSizePixel=0; b.Text=label
    b.TextColor3=C.WHITE; b.Font=Enum.Font.GothamBold; b.TextSize=12; Corner(b,5)
    if cb then b.MouseButton1Click:Connect(cb) end; return b
end

-- =============================================
-- [ FENETRE PRINCIPALE ] --
-- =============================================
local HubGui=Instance.new("ScreenGui")
HubGui.Name="MedusaHubUI"; HubGui.ResetOnSpawn=false
HubGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; HubGui.DisplayOrder=999; HubGui.Parent=CoreGui

local MainWin=Instance.new("Frame",HubGui)
MainWin.Name="MainWin"; MainWin.Size=UDim2.new(0,235,0,420)
MainWin.Position=UDim2.new(0.5,-117,0.5,-210)
MainWin.BackgroundColor3=C.BG; MainWin.BorderSizePixel=0; MainWin.Active=true
Corner(MainWin,8); Stroke(MainWin,C.ACCENT,1.5)

local Hdr=Instance.new("Frame",MainWin)
Hdr.Size=UDim2.new(1,0,0,38); Hdr.BackgroundColor3=C.HEADER; Hdr.BorderSizePixel=0; Corner(Hdr,8)
local hMask=Instance.new("Frame",Hdr)
hMask.Size=UDim2.new(1,0,0,8); hMask.Position=UDim2.new(0,0,1,-8); hMask.BackgroundColor3=C.HEADER; hMask.BorderSizePixel=0
local TitleL=Instance.new("TextLabel",Hdr)
TitleL.Size=UDim2.new(1,-40,1,0); TitleL.Position=UDim2.new(0,10,0,0); TitleL.BackgroundTransparency=1
TitleL.Text="medusa hub"; TitleL.TextColor3=C.TEXT; TitleL.Font=Enum.Font.GothamBold; TitleL.TextSize=14; TitleL.TextXAlignment=Enum.TextXAlignment.Left
local XBtn=Instance.new("TextButton",Hdr)
XBtn.Size=UDim2.new(0,22,0,22); XBtn.Position=UDim2.new(1,-28,0.5,-11)
XBtn.BackgroundColor3=C.BTN_RED; XBtn.BorderSizePixel=0; XBtn.Text="×"
XBtn.TextColor3=C.WHITE; XBtn.Font=Enum.Font.GothamBold; XBtn.TextSize=15; Corner(XBtn,11)
XBtn.MouseButton1Click:Connect(function() MainWin.Visible=not MainWin.Visible end)
MakeDraggable(MainWin,Hdr)

local TabBar=Instance.new("Frame",MainWin)
TabBar.Size=UDim2.new(1,-16,0,26); TabBar.Position=UDim2.new(0,8,0,44); TabBar.BackgroundTransparency=1
local tLayout=Instance.new("UIListLayout",TabBar)
tLayout.FillDirection=Enum.FillDirection.Horizontal; tLayout.SortOrder=Enum.SortOrder.LayoutOrder; tLayout.Padding=UDim.new(0,4)

local ContentArea=Instance.new("Frame",MainWin)
ContentArea.Size=UDim2.new(1,0,1,-78); ContentArea.Position=UDim2.new(0,0,0,78)
ContentArea.BackgroundTransparency=1; ContentArea.ClipsDescendants=true

local tabPages,tabBtns={},{}
local function CreatePage(name)
    local p=Instance.new("ScrollingFrame",ContentArea)
    p.Name=name.."Page"; p.Size=UDim2.new(1,0,1,0); p.BackgroundTransparency=1
    p.BorderSizePixel=0; p.ScrollBarThickness=2; p.ScrollBarImageColor3=C.ACCENT
    p.CanvasSize=UDim2.new(0,0,0,0); p.Visible=false; tabPages[name]=p; return p
end

local function SwitchTab(name)
    for n,p in pairs(tabPages) do p.Visible=(n==name) end
    for n,b in pairs(tabBtns) do
        b.BackgroundColor3=(n==name) and C.TAB_ON or C.TAB_OFF
        b.TextColor3=(n==name) and C.WHITE or C.SUB
    end
end

for i,name in ipairs({"Main","Farm","Visual"}) do
    local b=Instance.new("TextButton",TabBar)
    b.Size=UDim2.new(0,68,1,0); b.BackgroundColor3=(i==1) and C.TAB_ON or C.TAB_OFF
    b.BorderSizePixel=0; b.Text=name; b.TextColor3=(i==1) and C.WHITE or C.SUB
    b.Font=Enum.Font.GothamBold; b.TextSize=12; b.LayoutOrder=i; Corner(b,5)
    tabBtns[name]=b; b.MouseButton1Click:Connect(function() SwitchTab(name) end)
end

-- =============================================
-- [ PAGE MAIN ] --
-- =============================================
local MainPage=CreatePage("Main"); MainPage.Visible=true
local mY=6

-- CHIRON TP
mY=Sep(MainPage,mY,"Chiron TP"); mY=mY+4

Btn(MainPage,mY,"🚀  FUCK EM  [F]",C.BTN_BLU,function()
    task.spawn(function() teleportAll(); if autoBlockEnabled then task.wait(1); checkForBrainrot() end end)
end); mY=mY+32

local keybindBtn=Btn(MainPage,mY,"Keybind: [F]",C.BTN,nil)
keybindBtn.MouseButton1Click:Connect(function() keybindBtn.Text="Press a key..."; waitingForKey=true end); mY=mY+32

TogRow(MainPage,mY,"Auto Block",autoBlockEnabled,function(v) autoBlockEnabled=v; savedCfg.autoBlock=v; saveConfig(savedCfg) end); mY=mY+32

local delayRow=Instance.new("Frame",MainPage)
delayRow.Size=UDim2.new(1,-16,0,28); delayRow.Position=UDim2.new(0,8,0,mY); delayRow.BackgroundTransparency=1
local delayLbl=Instance.new("TextLabel",delayRow)
delayLbl.Size=UDim2.new(0,55,1,0); delayLbl.BackgroundTransparency=1; delayLbl.Text="Delay:"
delayLbl.TextColor3=C.TEXT; delayLbl.Font=Enum.Font.Gotham; delayLbl.TextSize=11; delayLbl.TextXAlignment=Enum.TextXAlignment.Left
local delayBox=Instance.new("TextBox",delayRow)
delayBox.Size=UDim2.new(0,70,0,22); delayBox.Position=UDim2.new(0,55,0.5,-11)
delayBox.Text=tostring(blockDelay); delayBox.TextColor3=C.TEXT; delayBox.Font=Enum.Font.Gotham; delayBox.TextSize=11
delayBox.BackgroundColor3=Color3.fromRGB(40,35,60); delayBox.BorderSizePixel=0
delayBox.PlaceholderText="0.1-5.0"; Corner(delayBox,4); Stroke(delayBox,C.ACCENT,1)
local setDelayBtn=Instance.new("TextButton",delayRow)
setDelayBtn.Size=UDim2.new(0,38,0,22); setDelayBtn.Position=UDim2.new(0,130,0.5,-11)
setDelayBtn.BackgroundColor3=C.ACCENT; setDelayBtn.BorderSizePixel=0
setDelayBtn.Text="SET"; setDelayBtn.TextColor3=C.WHITE; setDelayBtn.Font=Enum.Font.GothamBold; setDelayBtn.TextSize=10; Corner(setDelayBtn,4)
local function applyDelay()
    local num=tonumber(delayBox.Text)
    if num then blockDelay=math.clamp(math.floor(num*100+0.5)/100,minDelay,maxDelay); delayBox.Text=tostring(blockDelay); savedCfg.blockDelay=blockDelay; saveConfig(savedCfg)
    else delayBox.Text=tostring(blockDelay) end
end
setDelayBtn.MouseButton1Click:Connect(applyDelay); delayBox.FocusLost:Connect(applyDelay)
mY=mY+34

Btn(MainPage,mY,"🚫  Block All Players",C.BTN,function() task.spawn(blockAllPlayers) end); mY=mY+36

-- Combat
mY=Sep(MainPage,mY,"Combat"); mY=mY+4
local setBatAim=TogRow(MainPage,mY,"Bat Aimbot",savedCfg.batAimbot,function(v)
    Enabled.BatAimbot=v; savedCfg.batAimbot=v; saveConfig(savedCfg)
    if v then startBatAimbot() else stopBatAimbot() end
end); mY=mY+32
TogRow(MainPage,mY,"Half TP V2",cfg.halfTP,function(v) cfg.halfTP=v; persistCfg(); if v then startHalfTP() else stopHalfTP() end end); mY=mY+32
TogRow(MainPage,mY,"Anti-Ragdoll v1",cfg.antiRagdoll,function(v) cfg.antiRagdoll=v; persistCfg(); if v then startAntiRagdoll() else stopAntiRagdoll() end end); mY=mY+32
TogRow(MainPage,mY,"Anti-Trap",cfg.antiTrap,function(v)
    cfg.antiTrap=v; persistCfg()
    if v then antiTrapConnection=RunService.Heartbeat:Connect(function()
        local trap=Workspace:FindFirstChild("Trap"); if trap and trap:IsA("Model") then trap:Destroy() end end)
    else if antiTrapConnection then antiTrapConnection:Disconnect(); antiTrapConnection=nil end end
end); mY=mY+36

-- Stealing
mY=Sep(MainPage,mY,"Stealing"); mY=mY+4
TogRow(MainPage,mY,"Auto Steal (New)",cfg.fastSteal,function(v) cfg.fastSteal=v; persistCfg() end); mY=mY+32
TogRow(MainPage,mY,"Instant Steal",cfg.instSteal,function(v) cfg.instSteal=v; persistCfg() end); mY=mY+36

-- Movement
mY=Sep(MainPage,mY,"Movement"); mY=mY+4
TogRow(MainPage,mY,"Speed Boost (57)",cfg.speed,function(v) cfg.speed=v; persistCfg() end); mY=mY+32
TogRow(MainPage,mY,"Infinite Jump",cfg.infJump,function(v) cfg.infJump=v; persistCfg() end); mY=mY+36

-- Server
mY=Sep(MainPage,mY,"Server"); mY=mY+8
Btn(MainPage,mY,"Rejoin Server",C.BTN,function() game:GetService("TeleportService"):Teleport(game.PlaceId,LocalPlayer) end); mY=mY+32
Btn(MainPage,mY,"Kick Self",C.BTN,function() LocalPlayer:Kick("Medusa Hub") end); mY=mY+32
Btn(MainPage,mY,"Force Reset",C.BTN_RED,function() local h=GetHumanoid(); if h then h:TakeDamage(math.huge) end end); mY=mY+10
MainPage.CanvasSize=UDim2.new(0,0,0,mY)

-- =============================================
-- [ PAGE FARM (SLOT STEAL) ] --
-- =============================================
local FarmPage=CreatePage("Farm")
local fY=6

fY=Sep(FarmPage,fY,"Slot Steal"); fY=fY+4

-- Progress bar
local pbBg=Instance.new("Frame",FarmPage)
pbBg.Size=UDim2.new(1,-16,0,14); pbBg.Position=UDim2.new(0,8,0,fY)
pbBg.BackgroundColor3=Color3.fromRGB(25,25,35); pbBg.BorderSizePixel=0; Corner(pbBg,5)
local pbFill=Instance.new("Frame",pbBg)
pbFill.Size=UDim2.new(0,0,1,0); pbFill.BackgroundColor3=C.ACCENT; pbFill.BorderSizePixel=0; Corner(pbFill,5)
local pbLbl=Instance.new("TextLabel",pbBg)
pbLbl.Size=UDim2.new(1,0,1,0); pbLbl.BackgroundTransparency=1; pbLbl.Text="0%"
pbLbl.TextColor3=C.WHITE; pbLbl.Font=Enum.Font.GothamBold; pbLbl.TextSize=9; pbLbl.TextXAlignment=Enum.TextXAlignment.Right
task.spawn(function()
    while true do
        pbFill.Size=UDim2.new(math.clamp(StealProgress,0,1),0,1,0)
        pbLbl.Text=(math.floor(StealProgress*100+0.5)).."%"
        task.wait(0.02)
    end
end)
fY=fY+20

-- Label slot sélectionné
local slotLabel=Instance.new("TextLabel",FarmPage)
slotLabel.Size=UDim2.new(1,-16,0,16); slotLabel.Position=UDim2.new(0,8,0,fY)
slotLabel.BackgroundTransparency=1; slotLabel.Text="Slot: Nearest (auto)"
slotLabel.TextColor3=C.SUB; slotLabel.Font=Enum.Font.Gotham; slotLabel.TextSize=10
slotLabel.TextXAlignment=Enum.TextXAlignment.Left
fY=fY+20

-- Giant Potion toggle
TogRow(FarmPage,fY,"Giant Potion",cfg.giantPotion,function(v) cfg.giantPotion=v; persistCfg() end); fY=fY+36

-- Boutons steal
Btn(FarmPage,fY,"⚡ Steal Left (Spot 1)",C.ACCENT,function()
    if IsStealing then return end
    local animal = selectedSlot or getNearestAnimal()
    if animal then executeSlotSteal(animal, false) end
end); fY=fY+32

Btn(FarmPage,fY,"⚡ Steal Right (Spot 2)",C.BTN_BLU,function()
    if IsStealing then return end
    local animal = selectedSlot or getNearestAnimal()
    if animal then executeSlotSteal(animal, true) end
end); fY=fY+36

-- Liste des slots disponibles
fY=Sep(FarmPage,fY,"Choisir un slot"); fY=fY+4

local slotInfo=Instance.new("TextLabel",FarmPage)
slotInfo.Size=UDim2.new(1,-16,0,14); slotInfo.Position=UDim2.new(0,8,0,fY)
slotInfo.BackgroundTransparency=1; slotInfo.Text="Chargement des slots..."
slotInfo.TextColor3=C.SUB; slotInfo.Font=Enum.Font.Gotham; slotInfo.TextSize=9
slotInfo.TextXAlignment=Enum.TextXAlignment.Left
fY=fY+18

-- Scroll des slots
local slotScroll=Instance.new("ScrollingFrame",FarmPage)
slotScroll.Size=UDim2.new(1,-16,0,200); slotScroll.Position=UDim2.new(0,8,0,fY)
slotScroll.BackgroundColor3=Color3.fromRGB(22,18,35); slotScroll.BorderSizePixel=0
slotScroll.ScrollBarThickness=3; slotScroll.ScrollBarImageColor3=C.ACCENT
slotScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; Corner(slotScroll,5)
local slotLayout=Instance.new("UIListLayout",slotScroll)
slotLayout.FillDirection=Enum.FillDirection.Vertical; slotLayout.Padding=UDim.new(0,3)
slotLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
fY=fY+210

Btn(FarmPage,fY,"🔄 Rafraîchir la liste",C.BTN,function() refreshSlotList() end); fY=fY+32
Btn(FarmPage,fY,"❌ Reset sélection",C.BTN_RED,function()
    selectedSlot=nil; slotLabel.Text="Slot: Nearest (auto)"
end); fY=fY+10
FarmPage.CanvasSize=UDim2.new(0,0,0,fY)

-- Fonction refresh liste de slots
local activeSlotBtn=nil
function refreshSlotList()
    for _,c in ipairs(slotScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local count=0
    for _,animal in ipairs(allAnimalsCache) do
        count=count+1
        local row=Instance.new("Frame",slotScroll)
        row.Size=UDim2.new(1,-6,0,30); row.BackgroundColor3=C.ROW_A; row.BorderSizePixel=0; Corner(row,5)

        local nameLbl=Instance.new("TextLabel",row)
        nameLbl.Size=UDim2.new(1,-70,1,0); nameLbl.Position=UDim2.new(0,6,0,0)
        nameLbl.BackgroundTransparency=1; nameLbl.Text=animal.displayName
        nameLbl.TextColor3=C.TEXT; nameLbl.Font=Enum.Font.Gotham; nameLbl.TextSize=9
        nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.TextTruncate=Enum.TextTruncate.AtEnd

        local selBtn=Instance.new("TextButton",row)
        selBtn.Size=UDim2.new(0,60,0,22); selBtn.Position=UDim2.new(1,-64,0.5,-11)
        selBtn.BackgroundColor3=C.BTN; selBtn.BorderSizePixel=0
        selBtn.Text="Sélect."; selBtn.TextColor3=C.WHITE; selBtn.Font=Enum.Font.GothamBold; selBtn.TextSize=9; Corner(selBtn,4)

        local animalRef=animal
        selBtn.MouseButton1Click:Connect(function()
            if activeSlotBtn then activeSlotBtn.BackgroundColor3=C.BTN end
            selectedSlot=animalRef
            slotLabel.Text="Slot: "..animalRef.displayName
            selBtn.BackgroundColor3=C.ACCENT
            activeSlotBtn=selBtn
        end)
    end
    slotInfo.Text=count>0 and (count.." slots trouvés") or "Aucun slot trouvé"
end

-- =============================================
-- [ PAGE VISUAL ] --
-- =============================================
local VisualPage=CreatePage("Visual")
local vY=6

vY=Sep(VisualPage,vY,"ESP"); vY=vY+4
TogRow(VisualPage,vY,"ESP Anti-Invis",cfg.esp,function(v) cfg.esp=v; persistCfg() end); vY=vY+32
TogRow(VisualPage,vY,"Base X-Ray",cfg.xray,function(v) cfg.xray=v; persistCfg(); if v then enableXRay() else disableXRay() end end); vY=vY+32
TogRow(VisualPage,vY,"Timer ESP",cfg.timerEsp,function(v) cfg.timerEsp=v; persistCfg() end); vY=vY+36

vY=Sep(VisualPage,vY,"Effects"); vY=vY+4
TogRow(VisualPage,vY,"Aspect Ratio (Stretch)",cfg.aspectRatio,function(v) cfg.aspectRatio=v; persistCfg(); if v then enableAspectRatio() else disableAspectRatio() end end); vY=vY+32
TogRow(VisualPage,vY,"Dark Mode",cfg.darkMode,function(v) cfg.darkMode=v; persistCfg(); Lighting.Brightness=v and 0.1 or 2; Lighting.ClockTime=v and 0 or 14 end); vY=vY+32
TogRow(VisualPage,vY,"FPS Booster",cfg.optimizer,function(v) cfg.optimizer=v; persistCfg(); applyOptimizer(v) end); vY=vY+10
VisualPage.CanvasSize=UDim2.new(0,0,0,vY)

-- =============================================
-- [ FPS PANEL ] --
-- =============================================
local FPSPanel=Instance.new("Frame",HubGui)
FPSPanel.Size=UDim2.new(0,180,0,46); FPSPanel.Position=UDim2.new(0.5,-90,0,8)
FPSPanel.BackgroundColor3=C.HEADER; FPSPanel.BorderSizePixel=0; FPSPanel.Active=true
Corner(FPSPanel,8); Stroke(FPSPanel,C.ACCENT,1.2); MakeDraggable(FPSPanel)
local HubNameL=Instance.new("TextLabel",FPSPanel)
HubNameL.Size=UDim2.new(1,0,0,20); HubNameL.Position=UDim2.new(0,0,0,3)
HubNameL.BackgroundTransparency=1; HubNameL.Text="medusa hub  •  gg/medusa"
HubNameL.TextColor3=C.SUB; HubNameL.Font=Enum.Font.GothamBold; HubNameL.TextSize=10
local FPSStats=Instance.new("TextLabel",FPSPanel)
FPSStats.Size=UDim2.new(1,0,0,20); FPSStats.Position=UDim2.new(0,0,0,24)
FPSStats.BackgroundTransparency=1; FPSStats.Text="FPS: --  PING: --ms"
FPSStats.TextColor3=C.TEXT; FPSStats.Font=Enum.Font.GothamBold; FPSStats.TextSize=11
local MenuBtn=Instance.new("TextButton",HubGui)
MenuBtn.Size=UDim2.new(0,80,0,22); MenuBtn.Position=UDim2.new(0.5,-40,0,58)
MenuBtn.BackgroundColor3=C.ACCENT; MenuBtn.BorderSizePixel=0; MenuBtn.Text="Menu  [K]"
MenuBtn.TextColor3=C.WHITE; MenuBtn.Font=Enum.Font.GothamBold; MenuBtn.TextSize=11; Corner(MenuBtn,5)
MenuBtn.MouseButton1Click:Connect(function() MainWin.Visible=not MainWin.Visible end)

-- =============================================
-- [ PANELS FLOTTANTS ] --
-- =============================================
local function MakePanel(title,xOff,yOff,w,h)
    local panel=Instance.new("Frame",HubGui)
    panel.Size=UDim2.new(0,w,0,h); panel.Position=UDim2.new(1,xOff,0,yOff)
    panel.BackgroundColor3=C.PANEL; panel.BorderSizePixel=0; panel.Active=true; Corner(panel,7); Stroke(panel,C.ACCENT,1)
    local hdr=Instance.new("Frame",panel)
    hdr.Size=UDim2.new(1,0,0,26); hdr.BackgroundColor3=C.HEADER; hdr.BorderSizePixel=0; Corner(hdr,7)
    local hMask2=Instance.new("Frame",hdr)
    hMask2.Size=UDim2.new(1,0,0,7); hMask2.Position=UDim2.new(0,0,1,-7); hMask2.BackgroundColor3=C.HEADER; hMask2.BorderSizePixel=0
    local hT=Instance.new("TextLabel",hdr)
    hT.Size=UDim2.new(1,-8,1,0); hT.Position=UDim2.new(0,8,0,0); hT.BackgroundTransparency=1
    hT.Text=title; hT.TextColor3=C.TEXT; hT.Font=Enum.Font.GothamBold; hT.TextSize=11; hT.TextXAlignment=Enum.TextXAlignment.Left
    local content=Instance.new("Frame",panel)
    content.Size=UDim2.new(1,0,1,-26); content.Position=UDim2.new(0,0,0,26); content.BackgroundTransparency=1
    MakeDraggable(panel,hdr); return panel,content
end

local function PanelTog(parent,yPos,label,initVal,callback)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-12,0,26); row.Position=UDim2.new(0,6,0,yPos); row.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-46,1,0); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.TEXT; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local track=Instance.new("Frame",row)
    track.Size=UDim2.new(0,38,0,19); track.Position=UDim2.new(1,-38,0.5,-9.5)
    track.BackgroundColor3=initVal and C.TOG_ON or C.TOG_OFF; track.BorderSizePixel=0; Corner(track,9)
    local knob=Instance.new("Frame",track)
    knob.Size=UDim2.new(0,13,0,13)
    knob.Position=initVal and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)
    knob.BackgroundColor3=C.WHITE; knob.BorderSizePixel=0; Corner(knob,6)
    local state=initVal
    local btn=Instance.new("TextButton",row)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
    btn.MouseButton1Click:Connect(function()
        state=not state
        TweenService:Create(track,TweenInfo.new(0.15),{BackgroundColor3=state and C.TOG_ON or C.TOG_OFF}):Play()
        TweenService:Create(knob,TweenInfo.new(0.15),{Position=state and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)}):Play()
        if callback then callback(state) end
    end)
    return function(v)
        state=v; track.BackgroundColor3=v and C.TOG_ON or C.TOG_OFF
        knob.Position=v and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)
    end
end

local function PanelBtn(parent,yPos,label,col,cb)
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(1,-12,0,25); b.Position=UDim2.new(0,6,0,yPos)
    b.BackgroundColor3=col or C.BTN; b.BorderSizePixel=0; b.Text=label
    b.TextColor3=C.WHITE; b.Font=Enum.Font.GothamBold; b.TextSize=11; Corner(b,5)
    if cb then b.MouseButton1Click:Connect(cb) end; return b
end

-- Panel Chiron TP
local _,ctpC=MakePanel("Chiron TP",-152,88,142,120)
PanelBtn(ctpC,4,"🚀 FUCK EM [F]",C.BTN_BLU,function()
    task.spawn(function() teleportAll(); if autoBlockEnabled then task.wait(1); checkForBrainrot() end end)
end)
PanelBtn(ctpC,32,"🚫 Block All",C.BTN,function() task.spawn(blockAllPlayers) end)
PanelTog(ctpC,62,"Auto Block",autoBlockEnabled,function(v) autoBlockEnabled=v; savedCfg.autoBlock=v; saveConfig(savedCfg) end)
PanelBtn(ctpC,90,"Rebind [F]",C.BTN,function() keybindBtn.Text="Press a key..."; waitingForKey=true; MainWin.Visible=true; SwitchTab("Main") end)

-- Panel Slot Steal
local _,ssC=MakePanel("Slot Steal",-152,221,142,110)
local panelSlotLbl=Instance.new("TextLabel",ssC)
panelSlotLbl.Size=UDim2.new(1,-12,0,14); panelSlotLbl.Position=UDim2.new(0,6,0,3)
panelSlotLbl.BackgroundTransparency=1; panelSlotLbl.Text="Slot: Nearest"
panelSlotLbl.TextColor3=C.SUB; panelSlotLbl.Font=Enum.Font.Gotham; panelSlotLbl.TextSize=9; panelSlotLbl.TextXAlignment=Enum.TextXAlignment.Left
PanelBtn(ssC,20,"⚡ Steal Left",C.ACCENT,function()
    if IsStealing then return end
    local animal=selectedSlot or getNearestAnimal()
    if animal then executeSlotSteal(animal,false) end
end)
PanelBtn(ssC,48,"⚡ Steal Right",C.BTN_BLU,function()
    if IsStealing then return end
    local animal=selectedSlot or getNearestAnimal()
    if animal then executeSlotSteal(animal,true) end
end)
PanelTog(ssC,78,"Giant Potion",cfg.giantPotion,function(v) cfg.giantPotion=v; persistCfg() end)

-- Panel AP Spammer
local apPanel,apContent=MakePanel("AP Spammer",-152,344,142,0)
local apScroll=Instance.new("ScrollingFrame",apContent)
apScroll.Size=UDim2.new(1,0,1,-32); apScroll.Position=UDim2.new(0,0,0,0)
apScroll.BackgroundTransparency=1; apScroll.BorderSizePixel=0
apScroll.ScrollBarThickness=3; apScroll.ScrollBarImageColor3=C.ACCENT
apScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
local apLayout=Instance.new("UIListLayout",apScroll)
apLayout.FillDirection=Enum.FillDirection.Vertical; apLayout.Padding=UDim.new(0,4); apLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
local stopAllBtn=Instance.new("TextButton",apContent)
stopAllBtn.Size=UDim2.new(1,-12,0,24); stopAllBtn.Position=UDim2.new(0,6,1,-28)
stopAllBtn.BackgroundColor3=C.BTN_RED; stopAllBtn.BorderSizePixel=0
stopAllBtn.Text="⛔ Stop All"; stopAllBtn.TextColor3=C.WHITE; stopAllBtn.Font=Enum.Font.GothamBold; stopAllBtn.TextSize=10; Corner(stopAllBtn,5)
stopAllBtn.MouseButton1Click:Connect(stopAllSpam)

local function createAPRow(player)
    if player==lp then return end
    local row=Instance.new("Frame",apScroll)
    row.Name="APRow_"..player.UserId
    row.Size=UDim2.new(1,-8,0,32); row.BackgroundColor3=C.ROW_A; row.BorderSizePixel=0; Corner(row,5)
    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(1,-66,1,0); nameLbl.Position=UDim2.new(0,5,0,0)
    nameLbl.BackgroundTransparency=1; nameLbl.Text=player.Name
    nameLbl.TextColor3=C.TEXT; nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=10; nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.TextTruncate=Enum.TextTruncate.AtEnd
    local spamBtn=Instance.new("TextButton",row)
    spamBtn.Size=UDim2.new(0,58,0,22); spamBtn.Position=UDim2.new(1,-62,0.5,-11)
    spamBtn.BackgroundColor3=C.BTN_RED; spamBtn.BorderSizePixel=0
    spamBtn.Text="⚡SPAM"; spamBtn.TextColor3=C.WHITE; spamBtn.Font=Enum.Font.GothamBold; spamBtn.TextSize=10; Corner(spamBtn,5)
    local active=false
    spamBtn.MouseButton1Click:Connect(function()
        active=not active
        if active then spamBtn.BackgroundColor3=C.BTN_GRN; spamBtn.Text="STOP"; startSpam(player)
        else spamBtn.BackgroundColor3=C.BTN_RED; spamBtn.Text="⚡SPAM"; stopSpam(player) end
    end)
    player.AncestryChanged:Connect(function()
        if not player.Parent then spamming[player.UserId]=nil; row:Destroy(); refreshAPList() end
    end)
end

local function refreshAPList()
    for _,c in ipairs(apScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local count=0
    for _,p in ipairs(Players:GetPlayers()) do if p~=lp then createAPRow(p); count=count+1 end end
    local h=math.max(62, 26+math.min(count,4)*36+32)
    apPanel.Size=UDim2.new(0,142,0,h)
end

Players.PlayerAdded:Connect(function(p) task.wait(1); createAPRow(p); refreshAPList() end)
Players.PlayerRemoving:Connect(function(p) spamming[p.UserId]=nil; refreshAPList() end)

-- Panel Auto Farm
local _,farmC=MakePanel("Auto Farm",-152,488+142,142,92)
local updateRightPanel=PanelTog(farmC,4,"Auto Right",savedCfg.autoRight,function(v) savedCfg.autoRight=v; saveConfig(savedCfg); ToggleAutoRight(v) end)
local updateLeftPanel=PanelTog(farmC,32,"Auto Left",savedCfg.autoLeft,function(v) savedCfg.autoLeft=v; saveConfig(savedCfg); ToggleAutoLeft(v) end)
local updateBatPanel=PanelTog(farmC,60,"Bat Aimbot",savedCfg.batAimbot,function(v)
    Enabled.BatAimbot=v; savedCfg.batAimbot=v; saveConfig(savedCfg)
    if v then startBatAimbot() else stopBatAimbot() end; setBatAim(v)
end)

-- Panel Base Prot
local _,bpC=MakePanel("Base Prot",-152,640,142,112)
PanelBtn(bpC,4,"AP Spam Nearest [Q]",C.BTN,function()
    local hrp=GetRootPart(); if not hrp then return end
    local nearest,nearestDist=nil,math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=lp and p.Character then
            local eh=p.Character:FindFirstChild("HumanoidRootPart")
            if eh then local d=(eh.Position-hrp.Position).Magnitude; if d<nearestDist then nearestDist=d; nearest=p end end
        end
    end
    if nearest then if spamming[nearest.UserId] then stopSpam(nearest) else startSpam(nearest) end end
end)
PanelBtn(bpC,32,"Insta Reset [R]",C.BTN_RED,function() local h=GetHumanoid(); if h then h:TakeDamage(math.huge) end end)
PanelTog(bpC,62,"Base Protect (Balloon+Rocket)",false,function(v)
    baseProtActive=v
    if v then startBaseProt() else stopBaseProt() end
end)

-- Panel Booster
local _,boostC=MakePanel("Booster",-152,765,142,100)
local walkLbl=Instance.new("TextLabel",boostC)
walkLbl.Size=UDim2.new(1,-12,0,16); walkLbl.Position=UDim2.new(0,6,0,3)
walkLbl.BackgroundTransparency=1; walkLbl.Text="Walk Speed  0"
walkLbl.TextColor3=C.SUB; walkLbl.Font=Enum.Font.Gotham; walkLbl.TextSize=10; walkLbl.TextXAlignment=Enum.TextXAlignment.Left
PanelTog(boostC,22,"Walk Speed",savedCfg.walkSpeed,function(v) cfg.speed=v; savedCfg.walkSpeed=v; saveConfig(savedCfg) end)
PanelTog(boostC,50,"Steal Speed",savedCfg.stealSpeed,function(v) cfg.fastSteal=v; savedCfg.stealSpeed=v; saveConfig(savedCfg) end)

-- Panel Server
local _,srvC=MakePanel("Server",-152,878,142,100)
PanelBtn(srvC,4,"Rejoin Server",C.BTN,function() game:GetService("TeleportService"):Teleport(game.PlaceId,LocalPlayer) end)
PanelBtn(srvC,32,"Kick Self",C.BTN,function() LocalPlayer:Kick("Medusa Hub") end)
PanelBtn(srvC,60,"Force Reset",C.BTN_RED,function() local h=GetHumanoid(); if h then h:TakeDamage(math.huge) end end)

-- =============================================
-- [ KEYBINDS ] --
-- =============================================
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if waitingForKey and input.UserInputType==Enum.UserInputType.Keyboard then
        teleportKey=input.KeyCode; keybindBtn.Text="Keybind: ["..teleportKey.Name.."]"; waitingForKey=false; return
    end
    if input.KeyCode==Enum.KeyCode.K then MainWin.Visible=not MainWin.Visible
    elseif input.KeyCode==teleportKey then
        task.spawn(function() teleportAll(); if autoBlockEnabled then task.wait(1); checkForBrainrot() end end)
    elseif input.KeyCode==Enum.KeyCode.Q then
        local hrp=GetRootPart(); if not hrp then return end
        local nearest,nearestDist=nil,math.huge
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=lp and p.Character then
                local eh=p.Character:FindFirstChild("HumanoidRootPart")
                if eh then local d=(eh.Position-hrp.Position).Magnitude; if d<nearestDist then nearestDist=d; nearest=p end end
            end
        end
        if nearest then if spamming[nearest.UserId] then stopSpam(nearest) else startSpam(nearest) end end
    elseif input.KeyCode==Enum.KeyCode.R then
        local h=GetHumanoid(); if h then h:TakeDamage(math.huge) end
    end
end)

-- =============================================
-- [ FONCTIONS CORE ] --
-- =============================================
local function getBat()
    local c=LocalPlayer.Character; if not c then return nil end
    local tool=c:FindFirstChildWhichIsA("Tool")
    if tool and tool.Name=="Bat" then return tool end
    local bp=LocalPlayer:FindFirstChild("Backpack")
    if bp then local bt=bp:FindFirstChild("Bat"); if bt then return bt end end
    return nil
end

local function findNearestEnemy(myHRP)
    local nearest,nearestDist,nearestTorso=nil,math.huge,nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local eh=p.Character:FindFirstChild("HumanoidRootPart")
            local torso=p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum=p.Character:FindFirstChildOfClass("Humanoid")
            if eh and hum and hum.Health>0 then
                local d=(eh.Position-myHRP.Position).Magnitude
                if d<nearestDist then nearestDist=d; nearest=eh; nearestTorso=torso or eh end
            end
        end
    end
    return nearest,nearestDist,nearestTorso
end

function startBatAimbot()
    if Connections.batAimbot then return end
    Connections.batAimbot=RunService.Heartbeat:Connect(function()
        if not Enabled.BatAimbot then return end
        local c=LocalPlayer.Character; if not c then return end
        local h=c:FindFirstChild("HumanoidRootPart"); local hum=c:FindFirstChildOfClass("Humanoid"); if not h or not hum then return end
        local bat=getBat(); local target,dist,torso=findNearestEnemy(h)
        if target and torso then
            if bat and bat.Parent==c then bat:Activate() end
            local tv=torso.AssemblyLinearVelocity
            local dir=torso.Position-h.Position; local flatDist=Vector3.new(dir.X,0,dir.Z).Magnitude
            local pred=torso.Position+tv*(flatDist/80); local spd=58
            if flatDist>1 then
                local md=Vector3.new(pred.X-h.Position.X,0,pred.Z-h.Position.Z).Unit
                local yDiff=torso.Position.Y-h.Position.Y
                local ys=math.abs(yDiff)>0.5 and math.clamp(yDiff*8,-100,100) or tv.Y
                h.AssemblyLinearVelocity=Vector3.new(md.X*spd,ys,md.Z*spd)
            else h.AssemblyLinearVelocity=tv end
        end
    end)
end

function stopBatAimbot()
    if Connections.batAimbot then Connections.batAimbot:Disconnect(); Connections.batAimbot=nil end
end

function startHalfTP()
    if halfTpConnection then return end
    halfTpConnection=RunService.Heartbeat:Connect(function()
        if not cfg.halfTP then return end
        local c=LocalPlayer.Character; if not c then return end
        local hrp=c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local nearest,nearestDist=nil,math.huge
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local eh=p.Character:FindFirstChild("HumanoidRootPart")
                if eh then local d=(eh.Position-hrp.Position).Magnitude; if d<nearestDist then nearestDist=d; nearest=eh end end
            end
        end
        if nearest and nearestDist>6 then
            local mid=(hrp.Position+nearest.Position)/2
            hrp.CFrame=CFrame.new(mid)*(nearest.CFrame-nearest.CFrame.Position)
        end
    end)
end

function stopHalfTP() if halfTpConnection then halfTpConnection:Disconnect(); halfTpConnection=nil end end

local antiRagdollMode=nil; local ragdollConnections={}; local cachedCharData={}
local isBoosting=false; local BOOST_SPEED=400; local AR_DEFAULT_SPEED=16

local function arCache()
    local c=Player.Character; if not c then return false end
    local hum=c:FindFirstChildOfClass("Humanoid"); local root=c:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData={character=c,humanoid=hum,root=root}; return true
end
local function arDisconnect() for _,c in ipairs(ragdollConnections) do pcall(function() c:Disconnect() end) end; ragdollConnections={} end
local function arIsRag()
    if not cachedCharData.humanoid then return false end
    local s=cachedCharData.humanoid:GetState()
    local rs={[Enum.HumanoidStateType.Physics]=true,[Enum.HumanoidStateType.Ragdoll]=true,[Enum.HumanoidStateType.FallingDown]=true}
    if rs[s] then return true end
    local et=Player:GetAttribute("RagdollEndTime"); return et and (et-workspace:GetServerTimeNow())>0
end
local function arForceExit()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function() Player:SetAttribute("RagdollEndTime",workspace:GetServerTimeNow()) end)
    for _,d in ipairs(cachedCharData.character:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then d:Destroy() end
    end
    if not isBoosting then isBoosting=true; cachedCharData.humanoid.WalkSpeed=BOOST_SPEED end
    if cachedCharData.humanoid.Health>0 then cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running) end
    cachedCharData.root.Anchored=false
end
local function arLoop()
    while antiRagdollMode=="v1" do
        task.wait(); local rag=arIsRag()
        if rag then arForceExit()
        elseif isBoosting then isBoosting=false; if cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed=AR_DEFAULT_SPEED end end
    end
end
function startAntiRagdoll()
    if antiRagdollMode=="v1" then return end; if not arCache() then return end; antiRagdollMode="v1"
    table.insert(ragdollConnections,RunService.RenderStepped:Connect(function()
        local cam=workspace.CurrentCamera; if cam and cachedCharData.humanoid then cam.CameraSubject=cachedCharData.humanoid end
    end))
    table.insert(ragdollConnections,Player.CharacterAdded:Connect(function() isBoosting=false; task.wait(0.5); arCache() end))
    task.spawn(arLoop)
end
function stopAntiRagdoll()
    antiRagdollMode=nil; if isBoosting and cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed=AR_DEFAULT_SPEED end
    isBoosting=false; arDisconnect(); cachedCharData={}
end

local FORWARD_SPEED=59; local RETURN_SPEED=29
local RIGHT_PATH={Vector3.new(-473.32,-7.67,10.16),Vector3.new(-472.71,-8.14,29.92),Vector3.new(-472.87,-8.14,49.50),Vector3.new(-472.45,-8.14,65.05),Vector3.new(-472.94,-8.14,82.48),Vector3.new(-475.00,-8.14,96.84),Vector3.new(-485.50,-6.43,96.08)}
local LEFT_PATH={Vector3.new(-473.31,-7.67,111.75),Vector3.new(-473.51,-8.14,87.30),Vector3.new(-473.74,-8.14,60.58),Vector3.new(-474.04,-8.14,41.38),Vector3.new(-474.35,-8.14,25.77),Vector3.new(-485.30,-6.43,22.36)}
local RIGHT_RETURN={Vector3.new(-475.23,-8.14,90.61),Vector3.new(-476.24,-8.14,57.32),Vector3.new(-475.63,-8.14,23.36)}
local LEFT_RETURN={Vector3.new(-474.23,-8.14,26.51),Vector3.new(-475.15,-8.14,59.32),Vector3.new(-475.62,-8.06,97.99)}
local waypoints,returnWaypoints={},{}; local returnWaypointIndex=1

local function StopAutoWalk()
    if AutoWalkConnection then AutoWalkConnection:Disconnect(); AutoWalkConnection=nil end
    waypoints={}; returnWaypoints={}; currentWaypointIndex=1; returnWaypointIndex=1
    isAutoWalking=false; isReturning=false; isPaused=false
    local h=GetHumanoid(); if h then h:Move(Vector3.new(0,0,0)) end
    local r=GetRootPart(); if r then r.AssemblyLinearVelocity=Vector3.new(0,0,0) end
end
local function FindClosest(pos,list)
    local ci,cd=1,math.huge
    for i,wp in ipairs(list) do local d=(Vector3.new(wp.X,pos.Y,wp.Z)-pos).Magnitude; if d<cd then cd=d; ci=i end end
    return ci
end
local function StartAutoWalk(direction)
    StopAutoWalk(); local rp=GetRootPart(); if not rp then return end
    if direction=="right" then waypoints=RIGHT_PATH; returnWaypoints=RIGHT_RETURN
    elseif direction=="left" then waypoints=LEFT_PATH; returnWaypoints=LEFT_RETURN end
    currentWaypointIndex=FindClosest(rp.Position,waypoints); returnWaypointIndex=1; isAutoWalking=true; isReturning=false; isPaused=false
    AutoWalkConnection=RunService.Heartbeat:Connect(function()
        if IsShuttingDown then return end
        if not Config.AutoRight and not Config.AutoLeft then StopAutoWalk(); return end
        if isPaused then return end
        if HasBrainrotInHand and not isReturning then isReturning=true; returnWaypointIndex=1 end
        local hum=GetHumanoid(); local rp2=GetRootPart(); if not hum or not rp2 or not isAutoWalking then return end
        local tp=isReturning and returnWaypoints[returnWaypointIndex] or waypoints[currentWaypointIndex]; if not tp then return end
        local dv=(tp-rp2.Position)*Vector3.new(1,0,1); local dist=dv.Magnitude; local md=dv.Unit
        hum:Move(md); local spd=isReturning and RETURN_SPEED or FORWARD_SPEED
        rp2.AssemblyLinearVelocity=Vector3.new(md.X*spd,rp2.AssemblyLinearVelocity.Y,md.Z*spd)
        if dist<3 then
            if not isReturning then
                currentWaypointIndex=currentWaypointIndex+1
                if currentWaypointIndex>#waypoints then
                    isPaused=true; hum:Move(Vector3.new(0,0,0)); rp2.AssemblyLinearVelocity=Vector3.new(0,rp2.AssemblyLinearVelocity.Y,0)
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
function ToggleAutoRight(e) Config.AutoRight=e; if e then Config.AutoLeft=false; if ToggleFunctions["AutoLeft"] then ToggleFunctions["AutoLeft"](false) end; StartAutoWalk("right") else if not Config.AutoLeft then StopAutoWalk() end end end
function ToggleAutoLeft(e) Config.AutoLeft=e; if e then Config.AutoRight=false; if ToggleFunctions["AutoRight"] then ToggleFunctions["AutoRight"](false) end; StartAutoWalk("left") else if not Config.AutoRight then StopAutoWalk() end end end
ToggleFunctions["AutoRight"]=function(v) updateRightPanel(v) end
ToggleFunctions["AutoLeft"]=function(v) updateLeftPanel(v) end

local origTransparency={}
function enableXRay()
    pcall(function()
        for _,obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                origTransparency[obj]=obj.LocalTransparencyModifier; obj.LocalTransparencyModifier=0.85
            end
        end
    end)
end
function disableXRay() for p,v in pairs(origTransparency) do if p then p.LocalTransparencyModifier=v end end; origTransparency={} end

function enableAspectRatio()
    if stretchGui then stretchGui:Destroy() end
    stretchGui=Instance.new("ScreenGui",CoreGui); stretchGui.Name="MedusaStretch"; stretchGui.ResetOnSpawn=false; stretchGui.DisplayOrder=-999; stretchGui.IgnoreGuiInset=true
    local vp=Instance.new("ViewportFrame",stretchGui); vp.Size=UDim2.new(1,0,1,0); vp.BackgroundTransparency=1; vp.BorderSizePixel=0
    stretchCam=Instance.new("Camera"); stretchCam.Parent=vp; vp.CurrentCamera=stretchCam
    aspectRatioConnection=RunService.RenderStepped:Connect(function()
        if not cfg.aspectRatio then return end
        local rc=workspace.CurrentCamera; if not rc or not stretchCam then return end
        stretchCam.CFrame=rc.CFrame
        local vs=rc.ViewportSize; local hfov=2*math.atan(math.tan(math.rad(rc.FieldOfView)/2)*(vs.X/vs.Y))
        stretchCam.FieldOfView=math.deg(2*math.atan(math.tan(hfov/2)/(4/3)))
    end)
end
function disableAspectRatio()
    if aspectRatioConnection then aspectRatioConnection:Disconnect(); aspectRatioConnection=nil end
    if stretchGui then stretchGui:Destroy(); stretchGui=nil end; stretchCam=nil
end

function applyOptimizer(s)
    if s then
        Lighting.GlobalShadows=false
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then v.Material=Enum.Material.Plastic; v.Reflectance=0
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1 end
        end
    else Lighting.GlobalShadows=true end
end

local function CreateBoxESP(p)
    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
        local hrp=p.Character.HumanoidRootPart
        if not hrp:FindFirstChild("MedusaBox") then
            local b=Instance.new("BillboardGui",hrp); b.Name="MedusaBox"; b.AlwaysOnTop=true; b.Size=UDim2.new(4.5,0,6,0); b.Adornee=hrp
            local fr=Instance.new("Frame",b); fr.Size=UDim2.new(1,0,1,0); fr.BackgroundTransparency=0.7; fr.BackgroundColor3=C.ACCENT
            Instance.new("UIStroke",fr).Color=C.WHITE
            local tl=Instance.new("TextLabel",b); tl.Size=UDim2.new(1,0,0.2,0); tl.Position=UDim2.new(0,0,-0.25,0); tl.BackgroundTransparency=1
            tl.Text=p.Name; tl.TextColor3=C.WHITE; tl.Font="GothamBold"; tl.TextSize=10
        end
    end
end

local function UpdateTimerESP()
    local plots=Workspace:FindFirstChild("Plots"); if not plots then return end
    for _,plot in pairs(plots:GetChildren()) do
        local purchases=plot:FindFirstChild("Purchases"); if not purchases then continue end
        for _,purchase in pairs(purchases:GetChildren()) do
            local main=purchase:FindFirstChild("Main")
            local billboard=main and main:FindFirstChild("BillboardGui")
            local remTime=billboard and billboard:FindFirstChild("RemainingTime")
            if remTime and remTime:IsA("TextLabel") and remTime.Visible then
                local existing=main:FindFirstChild("TimerESP_Gui")
                if cfg.timerEsp then
                    if not existing then
                        local gui=Instance.new("BillboardGui",main); gui.Name="TimerESP_Gui"; gui.Size=UDim2.new(0,100,0,40); gui.StudsOffset=Vector3.new(0,3,0); gui.AlwaysOnTop=true
                        local txt=Instance.new("TextLabel",gui); txt.Size=UDim2.new(1,0,1,0); txt.BackgroundTransparency=1
                        txt.TextColor3=C.ACCENT; txt.Font="GothamBold"; txt.TextSize=14; txt.TextStrokeTransparency=0; txt.Text=remTime.Text
                    else local tl=existing:FindFirstChildOfClass("TextLabel"); if tl then tl.Text=remTime.Text end end
                elseif existing then existing:Destroy() end
            end
        end
    end
end

-- =============================================
-- [ BOUCLE PRINCIPALE ] --
-- =============================================
RunService.RenderStepped:Connect(function()
    local fps=math.floor(1/math.max(RunService.RenderStepped:Wait(),0.001))
    local pingOk,ping=pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+") end)
    FPSStats.Text="FPS: "..fps.."  PING: "..(pingOk and ping or "--").."ms"
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local vel=lp.Character.HumanoidRootPart.Velocity; local spd=math.floor(Vector3.new(vel.X,0,vel.Z).Magnitude)
        speedLabel.Text=spd.." sp"; walkLbl.Text="Walk Speed  "..spd
    end
    if cfg.speed and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp=lp.Character.HumanoidRootPart; local hum=lp.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude>0 then hrp.Velocity=Vector3.new(hum.MoveDirection.X*57,hrp.Velocity.Y,hum.MoveDirection.Z*57) end
    end
    UpdateTimerESP()
end)

UserInputService.JumpRequest:Connect(function()
    if cfg.infJump and GetRootPart() then GetRootPart().Velocity=Vector3.new(GetRootPart().Velocity.X,50,GetRootPart().Velocity.Z) end
end)

task.spawn(function()
    while task.wait(0.2) do
        if cfg.esp then for _,p in pairs(Players:GetPlayers()) do if p~=lp then CreateBoxESP(p) end end
        else for _,p in pairs(Players:GetPlayers()) do if p.Character then local hrp=p.Character:FindFirstChild("HumanoidRootPart"); if hrp and hrp:FindFirstChild("MedusaBox") then hrp.MedusaBox:Destroy() end end end end
        if cfg.fastSteal or cfg.instSteal then for _,v in pairs(workspace:GetDescendants()) do if v:IsA("ProximityPrompt") then v.HoldDuration=0 end end end
    end
end)

-- =============================================
-- [ INIT ] --
-- =============================================
task.spawn(function()
    task.wait(1)
    if cfg.antiRagdoll then startAntiRagdoll() end
    if cfg.halfTP then startHalfTP() end
    if cfg.xray then enableXRay() end
    if cfg.optimizer then applyOptimizer(true) end
    if cfg.darkMode then Lighting.Brightness=0.1; Lighting.ClockTime=0 end
    if cfg.aspectRatio then enableAspectRatio() end
    if cfg.antiTrap then antiTrapConnection=RunService.Heartbeat:Connect(function() local trap=Workspace:FindFirstChild("Trap"); if trap and trap:IsA("Model") then trap:Destroy() end end) end
    if Enabled.BatAimbot then startBatAimbot() end
    if Config.AutoRight then ToggleAutoRight(true) end
    if Config.AutoLeft then ToggleAutoLeft(true) end
    setupBrainrotDetection()
    initializeScanner()
    task.wait(3)
    refreshAPList()
    refreshSlotList()
end)

-- NOTIFICATION
task.spawn(function()
    task.wait(0.5)
    local ng=Instance.new("ScreenGui",CoreGui); ng.Name="MedusaNotif"; ng.ResetOnSpawn=false; ng.DisplayOrder=9999
    local nf=Instance.new("Frame",ng)
    nf.Size=UDim2.new(0,310,0,48); nf.Position=UDim2.new(0.5,-155,1,10)
    nf.BackgroundColor3=C.HEADER; nf.BorderSizePixel=0; Corner(nf,8); Stroke(nf,C.ACCENT,1.5)
    local nl=Instance.new("TextLabel",nf)
    nl.Size=UDim2.new(1,0,1,0); nl.BackgroundTransparency=1
    nl.Text="✓  MEDUSA HUB V57  •  Paramètres chargés\n[K] menu  •  [F] TP  •  [Q] AP Spam  •  [R] reset"
    nl.TextColor3=C.TEXT; nl.Font=Enum.Font.GothamBold; nl.TextSize=11
    TweenService:Create(nf,TweenInfo.new(0.4,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-155,1,-60)}):Play()
    task.wait(4); TweenService:Create(nf,TweenInfo.new(0.3),{Position=UDim2.new(0.5,-155,1,10)}):Play()
    task.wait(0.4); ng:Destroy()
end)
