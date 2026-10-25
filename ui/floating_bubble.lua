--[[
    FloatingBubble.lua
    Workflow Module 1: Bong bóng nổi (Draggable Floating Bubble) & Menu Window
    - Thuật toán phân biệt Tap (mở menu) vs Drag (kéo vị trí) bằng ngưỡng delta.Magnitude > 5px
    - Thiết kế Touch-friendly cho Delta Mobile, mượt mà trên Touch & Mouse
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local FloatingBubble = {}

function FloatingBubble.Init(State, Maid, ScreenGui, onToggleNightVision, onToggleArrowESP)
    -- =========================================================================
    -- 1. BONG BÓNG NỔI (FLOATING BUBBLE)
    -- =========================================================================
    local bubble = Instance.new("TextButton")
    bubble.Name = "FloatingBubble"
    bubble.Size = UDim2.fromOffset(48, 48)
    bubble.Position = UDim2.new(0.08, 0, 0.4, 0)
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
    bubbleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bubbleStroke.Parent = bubble

    -- =========================================================================
    -- 2. BẢNG MENU CHÍNH (MAIN MENU WINDOW)
    -- =========================================================================
    local menuFrame = Instance.new("Frame")
    menuFrame.Name = "MainHubFrame"
    menuFrame.Size = UDim2.fromOffset(260, 230)
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

    -- Header Menu
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = menuFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar

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

    -- Container chứa nút Toggle
    local contentList = Instance.new("Frame")
    contentList.Name = "ContentList"
    contentList.Size = UDim2.new(1, -20, 1, -50)
    contentList.Position = UDim2.fromOffset(10, 44)
    contentList.BackgroundTransparency = 1
    contentList.Parent = menuFrame

    local uiLayout = Instance.new("UIListLayout")
    uiLayout.Padding = UDim.new(0, 8)
    uiLayout.FillDirection = Enum.FillDirection.Vertical
    uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiLayout.Parent = contentList

    -- Hàm helper tạo Button Toggle chuẩn phong cách mobile
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

    -- Khởi tạo 2 toggle theo tài liệu
    createToggle("ToggleNightVision", "🌙 Night Vision (Fullbright)", State.Flags.NightVision, function(val)
        onToggleNightVision(val)
    end)

    createToggle("ToggleArrowESP", "🎯 Mob Arrow ESP (Chỉ Quái)", State.Flags.ArrowESP, function(val)
        onToggleArrowESP(val)
    end)

    -- Status footer text
    local footerText = Instance.new("TextLabel")
    footerText.Size = UDim2.new(1, 0, 0, 20)
    footerText.BackgroundTransparency = 1
    footerText.Text = "Optimized for Delta / Mobile 60 FPS"
    footerText.TextColor3 = Color3.fromRGB(90, 95, 110)
    footerText.Font = Enum.Font.Gotham
    footerText.TextSize = 10
    footerText.Parent = contentList

    -- =========================================================================
    -- 3. THUẬT TOÁN PHÂN BIỆT TAP & DRAG (DELTA THRESHOLD > 5 PIXELS)
    -- =========================================================================
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    local hasMoved = false

    local inputBeganConn = bubble.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            hasMoved = false
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos = bubble.Position
        end
    end)
    Maid:GiveTask(inputBeganConn)

    local inputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local currentPos = Vector2.new(input.Position.X, input.Position.Y)
            local delta = currentPos - dragStart

            -- Nếu độ lệch vượt quá 5 pixels -> Coi là thao tác kéo
            if delta.Magnitude > State.Settings.UI.DragThreshold then
                hasMoved = true
                local newX = UDim.new(startPos.X.Scale, startPos.X.Offset + delta.X)
                local newY = UDim.new(startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                bubble.Position = UDim2.new(newX, newY)
            end
        end
    end)
    Maid:GiveTask(inputChangedConn)

    local inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                -- Nếu không vượt quá threshold -> Coi là cú chạm nhẹ (Tap) -> Đảo trạng thái mở/đóng Menu
                if not hasMoved then
                    State.Flags.MenuOpen = not State.Flags.MenuOpen
                    menuFrame.Visible = State.Flags.MenuOpen
                end
            end
        end
    end)
    Maid:GiveTask(inputEndedConn)

    -- Nút đóng góc phải Menu
    closeBtn.Activated:Connect(function()
        State.Flags.MenuOpen = false
        menuFrame.Visible = false
    end)

    return FloatingBubble
end

return FloatingBubble
