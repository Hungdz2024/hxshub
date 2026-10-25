--[[
    ============================================================================
    UNIVERSAL UI, NIGHT VISION & ARROW ESP - DELTA MOBILE STANDALONE BUNDLE
    Target: Roblox Mobile (Delta, Codex, Arceus X) & PC Executors
    Architecture: 3-Tier Pipeline, Object Pooling, Maid Memory Management
    ============================================================================
]]

-- Dọn dẹp session cũ nếu đã từng execute trước đó
if getgenv and getgenv()._DeltaProjectMaid then
    pcall(function()
        getgenv()._DeltaProjectMaid:Destroy()
    end)
    getgenv()._DeltaProjectMaid = nil
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =============================================================================
-- [CORE] MAID: DỌN DẸP BỘ NHỚ VÀ CONNECTIONS
-- =============================================================================
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:GiveTask(task)
    if not task then return end
    table.insert(self._tasks, task)
    return task
end

function Maid:DoCleaning()
    local tasks = self._tasks
    for index = #tasks, 1, -1 do
        local task = tasks[index]
        tasks[index] = nil

        if typeof(task) == "RBXScriptConnection" then
            if task.Connected then task:Disconnect() end
        elseif typeof(task) == "Instance" then
            task:Destroy()
        elseif type(task) == "function" then
            pcall(task)
        elseif type(task) == "table" and typeof(task.Destroy) == "function" then
            task:Destroy()
        end
    end
end

function Maid:Destroy()
    self:DoCleaning()
    setmetatable(self, nil)
end

local globalMaid = Maid.new()
if getgenv then
    getgenv()._DeltaProjectMaid = globalMaid
end

-- =============================================================================
-- [CORE] STATE & CONFIGURATION
-- =============================================================================
local State = {
    Flags = {
        NightVision = false,
        ArrowESP = false,
        MenuOpen = false,
    },
    Settings = {
        ESP = {
            MaxDistance = 500,
            ScanInterval = 0.4,
            PoolSize = 15,
            Radius = 90,
            MinColor = Color3.fromRGB(255, 45, 45),   -- Gần (Đỏ)
            MaxColor = Color3.fromRGB(50, 255, 120),  -- Xa (Xanh lá)
        },
        UI = {
            DragThreshold = 5,
        }
    },
    TargetCache = {},
    OriginalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }
}

-- =============================================================================
-- [CONTAINER] SCREENGUI SETUP
-- =============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaUniversalProject"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local attached = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not attached or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
globalMaid:GiveTask(ScreenGui)

-- =============================================================================
-- [MODULE 2] NIGHT VISION (FULLBRIGHT)
-- =============================================================================
local nightVisionConn = nil

local function applyFullbright()
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end

local function restoreLighting()
    Lighting.Brightness = State.OriginalLighting.Brightness
    Lighting.ClockTime = State.OriginalLighting.ClockTime
    Lighting.FogEnd = State.OriginalLighting.FogEnd
    Lighting.GlobalShadows = State.OriginalLighting.GlobalShadows
    Lighting.Ambient = State.OriginalLighting.Ambient
    Lighting.OutdoorAmbient = State.OriginalLighting.OutdoorAmbient
end

local function setNightVision(enabled)
    State.Flags.NightVision = enabled
    if enabled then
        applyFullbright()
        if not nightVisionConn then
            nightVisionConn = RunService.RenderStepped:Connect(applyFullbright)
            globalMaid:GiveTask(nightVisionConn)
        end
    else
        if nightVisionConn then
            nightVisionConn:Disconnect()
            nightVisionConn = nil
        end
        restoreLighting()
    end
end

globalMaid:GiveTask(function()
    if nightVisionConn then
        nightVisionConn:Disconnect()
        nightVisionConn = nil
    end
    restoreLighting()
end)

-- =============================================================================
-- [MODULE 3] CROSSHAIR ARROW ESP (OBJECT POOLING & 3-TIER ENGINE)
-- =============================================================================
local espConfig = State.Settings.ESP
local arrowPool = {}

local arrowFolder = Instance.new("Folder")
arrowFolder.Name = "ArrowPoolContainer"
arrowFolder.Parent = ScreenGui
globalMaid:GiveTask(arrowFolder)

-- Hồ chứa UI (Object Pooling)
local ARROW_ASSET = "rbxassetid://6034818372"
for i = 1, espConfig.PoolSize do
    local arrow = Instance.new("ImageLabel")
    arrow.Name = "Arrow_" .. i
    arrow.Size = UDim2.fromOffset(24, 24)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.BackgroundTransparency = 1
    arrow.Image = ARROW_ASSET
    arrow.ImageColor3 = espConfig.MinColor
    arrow.Visible = false
    arrow.Parent = arrowFolder

    arrowPool[i] = arrow
end

-- Tầng 2: Scanner Loop (Chạy mỗi 0.4s)
local function updateTargetCache()
    local char = LocalPlayer.Character
    if not char then
        State.TargetCache = {}
        return
    end

    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        State.TargetCache = {}
        return
    end

    -- Helper tìm RootPart của Mob linh hoạt (HumanoidRootPart, PrimaryPart, Torso, UpperTorso)
    local function getMobRoot(model)
        return model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
            or model:FindFirstChild("Torso")
            or model:FindFirstChild("UpperTorso")
    end

    -- Danh sách folder quái phổ biến trong các game Roblox (Blox Fruits, King Legacy, Dungeon...)
    local commonMobFolders = {
        Workspace:FindFirstChild("Enemies"),
        Workspace:FindFirstChild("NPCs"),
        Workspace:FindFirstChild("Mobs"),
        Workspace:FindFirstChild("Monsters"),
        Workspace:FindFirstChild("Entities"),
        Workspace:FindFirstChild("Living")
    }

    local function checkAndAddMob(model)
        if not model:IsA("Model") or model == char then return end
        -- BỎ QUA HOÀN TOÀN PLAYER: Chỉ nhắm vào Mob/Quái
        if Players:GetPlayerFromCharacter(model) then return end

        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = getMobRoot(model)

        if hum and root and hum.Health > 0 then
            local dist = (myPos - root.Position).Magnitude
            if dist <= espConfig.MaxDistance then
                table.insert(rawList, { Root = root, Distance = dist })
            end
        end
    end

    -- 1. Quét các folder chứa quái riêng biệt (nếu game có)
    for _, folder in ipairs(commonMobFolders) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                checkAndAddMob(obj)
            end
        end
    end

    -- 2. Quét Workspace (và các subfolder lồng 1 cấp)
    for _, obj in ipairs(Workspace:GetChildren()) do
        checkAndAddMob(obj)
        if obj:IsA("Folder") and obj.Name ~= "Terrain" and obj.Name ~= "Camera" then
            for _, sub in ipairs(obj:GetChildren()) do
                checkAndAddMob(sub)
            end
        end
    end

    -- Sắp xếp tăng dần theo khoảng cách
    table.sort(rawList, function(a, b) return a.Distance < b.Distance end)

    local finalCache = {}
    for i = 1, math.min(#rawList, espConfig.PoolSize) do
        table.insert(finalCache, rawList[i])
    end
    State.TargetCache = finalCache
end

-- Tầng 3: Render Loop (RenderStepped)
local scanTimer = 0
local espRenderConn = RunService.RenderStepped:Connect(function(dt)
    scanTimer = scanTimer + dt
    if scanTimer >= espConfig.ScanInterval then
        scanTimer = 0
        if State.Flags.ArrowESP then
            updateTargetCache()
        end
    end

    if not State.Flags.ArrowESP then
        for i = 1, espConfig.PoolSize do
            if arrowPool[i].Visible then arrowPool[i].Visible = false end
        end
        return
    end

    local vSize = Camera.ViewportSize
    local centerX = vSize.X * 0.5
    local centerY = vSize.Y * 0.5
    local radius = espConfig.Radius
    local targets = State.TargetCache

    for i = 1, espConfig.PoolSize do
        local arrow = arrowPool[i]
        local data = targets[i]

        if not data or not data.Root or not data.Root.Parent then
            arrow.Visible = false
        else
            -- Bước A: PointToObjectSpace của Camera
            local rel = Camera.CFrame:PointToObjectSpace(data.Root.Position)
            -- Bước B: atan2 góc phương vị
            local angleRad = math.atan2(rel.Z, rel.X)

            -- Bước C: Tọa độ vòng tròn quanh tâm ngắm
            local posX = centerX + radius * math.cos(angleRad)
            local posY = centerY + radius * math.sin(angleRad)
            arrow.Position = UDim2.fromOffset(posX, posY)

            -- Bước D: Xoay đầu mũi tên hướng về mục tiêu
            arrow.Rotation = math.deg(angleRad) + 90

            -- Bước E: Distance Lerp RGB
            local alpha = math.clamp(data.Distance / espConfig.MaxDistance, 0, 1)
            arrow.ImageColor3 = espConfig.MinColor:Lerp(espConfig.MaxColor, alpha)
            arrow.Visible = true
        end
    end
end)
globalMaid:GiveTask(espRenderConn)

-- =============================================================================
-- [MODULE 1] BONG BÓNG NỔI & GIAO DIỆN MENU (FLOATING BUBBLE UI)
-- =============================================================================
local bubble = Instance.new("TextButton")
bubble.Name = "FloatingBubble"
bubble.Size = UDim2.fromOffset(48, 48)
bubble.Position = UDim2.new(0.08, 0, 0.45, 0)
bubble.AnchorPoint = Vector2.new(0.5, 0.5)
bubble.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
bubble.Text = "⚡"
bubble.TextSize = 22
bubble.TextColor3 = Color3.fromRGB(0, 220, 255)
bubble.Font = Enum.Font.GothamBold
bubble.AutoButtonColor = false
bubble.Parent = ScreenGui

local bubbleCorner = Instance.new("UICorner")
bubbleCorner.CornerRadius = UDim.new(1, 0)
bubbleCorner.Parent = bubble

local bubbleStroke = Instance.new("UIStroke")
bubbleStroke.Thickness = 2
bubbleStroke.Color = Color3.fromRGB(0, 180, 255)
bubbleStroke.Parent = bubble

-- Bảng Menu Window
local menuFrame = Instance.new("Frame")
menuFrame.Name = "DeltaHubMenu"
menuFrame.Size = UDim2.fromOffset(260, 215)
menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
menuFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
menuFrame.BorderSizePixel = 0
menuFrame.Visible = false
menuFrame.ClipsDescendants = true
menuFrame.Parent = ScreenGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 12)
menuCorner.Parent = menuFrame

local menuStroke = Instance.new("UIStroke")
menuStroke.Thickness = 1.5
menuStroke.Color = Color3.fromRGB(45, 50, 65)
menuStroke.Parent = menuFrame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
titleBar.BorderSizePixel = 0
titleBar.Parent = menuFrame

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -40, 1, 0)
titleText.Position = UDim2.fromOffset(12, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "DELTA HUB • MOBILE"
titleText.TextColor3 = Color3.fromRGB(240, 240, 245)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 13
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar

local contentList = Instance.new("Frame")
contentList.Size = UDim2.new(1, -20, 1, -46)
contentList.Position = UDim2.fromOffset(10, 42)
contentList.BackgroundTransparency = 1
contentList.Parent = menuFrame

local uiLayout = Instance.new("UIListLayout")
uiLayout.Padding = UDim.new(0, 8)
uiLayout.FillDirection = Enum.FillDirection.Vertical
uiLayout.Parent = contentList

local function createToggle(name, text, defaultVal, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = defaultVal and Color3.fromRGB(25, 55, 75) or Color3.fromRGB(26, 30, 40)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = contentList

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = defaultVal and Color3.fromRGB(0, 190, 255) or Color3.fromRGB(45, 50, 65)
    stroke.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(230, 230, 240)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    local statusTag = Instance.new("TextLabel")
    statusTag.Size = UDim2.fromOffset(48, 22)
    statusTag.Position = UDim2.new(1, -56, 0.5, -11)
    statusTag.BackgroundColor3 = defaultVal and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 45, 58)
    statusTag.Text = defaultVal and "ON" or "OFF"
    statusTag.TextColor3 = defaultVal and Color3.fromRGB(15, 20, 30) or Color3.fromRGB(160, 165, 180)
    statusTag.Font = Enum.Font.GothamBold
    statusTag.TextSize = 11
    statusTag.Parent = btn

    local tagCorner = Instance.new("UICorner")
    tagCorner.CornerRadius = UDim.new(0, 6)
    tagCorner.Parent = statusTag

    local isEnabled = defaultVal
    btn.Activated:Connect(function()
        isEnabled = not isEnabled
        statusTag.Text = isEnabled and "ON" or "OFF"
        statusTag.BackgroundColor3 = isEnabled and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 45, 58)
        statusTag.TextColor3 = isEnabled and Color3.fromRGB(15, 20, 30) or Color3.fromRGB(160, 165, 180)
        btn.BackgroundColor3 = isEnabled and Color3.fromRGB(25, 55, 75) or Color3.fromRGB(26, 30, 40)
        stroke.Color = isEnabled and Color3.fromRGB(0, 190, 255) or Color3.fromRGB(45, 50, 65)
        callback(isEnabled)
    end)
    return btn
end

createToggle("ToggleNightVision", "🌙 Night Vision (Fullbright)", State.Flags.NightVision, function(val)
    setNightVision(val)
end)

createToggle("ToggleArrowESP", "🎯 Mob Arrow ESP (Chỉ Quái)", State.Flags.ArrowESP, function(val)
    State.Flags.ArrowESP = val
end)

local footerText = Instance.new("TextLabel")
footerText.Size = UDim2.new(1, 0, 0, 20)
footerText.BackgroundTransparency = 1
footerText.Text = "Optimized for Delta Mobile • 60 FPS"
footerText.TextColor3 = Color3.fromRGB(90, 95, 110)
footerText.Font = Enum.Font.Gotham
footerText.TextSize = 10
footerText.Parent = contentList

-- Thuật toán phân biệt Tap vs Drag (Delta Magnitude > 5px)
local dragging = false
local dragStart = Vector2.new()
local startPos = UDim2.new()
local hasMoved = false

local bubbleBegan = bubble.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        hasMoved = false
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        startPos = bubble.Position
    end
end)
globalMaid:GiveTask(bubbleBegan)

local bubbleChanged = UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
        if delta.Magnitude > State.Settings.UI.DragThreshold then
            hasMoved = true
            bubble.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)
globalMaid:GiveTask(bubbleChanged)

local bubbleEnded = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            dragging = false
            if not hasMoved then
                State.Flags.MenuOpen = not State.Flags.MenuOpen
                menuFrame.Visible = State.Flags.MenuOpen
            end
        end
    end
end)
globalMaid:GiveTask(bubbleEnded)

closeBtn.Activated:Connect(function()
    State.Flags.MenuOpen = false
    menuFrame.Visible = false
end)

print("[Delta Project]: Bundled single-file script nạp thành công trên thiết bị!")
