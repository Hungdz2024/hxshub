--[[
    ArrowESP.lua
    Workflow Module 3: Crosshair Arrow ESP quanh tâm ngắm
    - Tầng 1: Object Pooling (N ImageLabel khởi tạo sẵn)
    - Tầng 2: Scanner Loop (Chạy mỗi 0.4s tìm mob gần nhất, lưu TargetCache)
    - Tầng 3: Render Loop (RenderStepped: PointToObjectSpace -> atan2 -> Vòng tròn R -> Lerp Color)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ArrowESP = {}

function ArrowESP.Init(State, Maid, ScreenGui)
    local config = State.Settings.ESP
    local arrowPool = {}

    -- Vùng chứa UI cho các mũi tên
    local arrowContainer = Instance.new("Folder")
    arrowContainer.Name = "ArrowESPContainer"
    arrowContainer.Parent = ScreenGui
    Maid:GiveTask(arrowContainer)

    -- 1. Chuẩn bị Hồ chứa UI (Object Pooling)
    -- Sử dụng asset mũi tên mặc định của Roblox hoặc asset id clean
    local ARROW_ASSET = "rbxassetid://6034818372" -- Mũi tên nhọn hướng lên trên (0 deg)

    for i = 1, config.PoolSize do
        local arrow = Instance.new("ImageLabel")
        arrow.Name = "Arrow_" .. i
        arrow.Size = UDim2.fromOffset(24, 24)
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.BackgroundTransparency = 1
        arrow.Image = ARROW_ASSET
        arrow.ImageColor3 = config.MinColor
        arrow.Visible = false
        arrow.Parent = arrowContainer

        arrowPool[i] = arrow
    end

    -- 2. Tầng Thu Thập Dữ Liệu (Scanner Loop - Chạy ngầm 0.4s)
    local lastScan = 0
    local function updateTargetCache()
        local character = LocalPlayer.Character
        if not character then
            State.TargetCache = {}
            return
        end

        local myRoot = character:FindFirstChild("HumanoidRootPart")
        if not myRoot then
            State.TargetCache = {}
            return
        end

        local myPos = myRoot.Position
        local rawTargets = {}

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
            if not model:IsA("Model") or model == character then return end
            -- BỎ QUA HOÀN TOÀN PLAYER: Chỉ nhắm vào Mob/Quái
            if Players:GetPlayerFromCharacter(model) then return end

            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = getMobRoot(model)

            if hum and root and hum.Health > 0 then
                local dist = (myPos - root.Position).Magnitude
                if dist <= config.MaxDistance then
                    table.insert(rawTargets, {
                        Root = root,
                        Distance = dist,
                        Name = model.Name
                    })
                end
            end
        end

        -- 1. Ưu tiên quét các folder chứa quái riêng biệt (nếu game có)
        local scannedFolders = false
        for _, folder in ipairs(commonMobFolders) do
            if folder then
                scannedFolders = true
                for _, obj in ipairs(folder:GetChildren()) do
                    checkAndAddMob(obj)
                end
            end
        end

        -- 2. Quét toàn bộ cấp 1 của Workspace
        for _, obj in ipairs(Workspace:GetChildren()) do
            checkAndAddMob(obj)
            -- Kiểm tra thêm nếu là Folder/Model lồng nhau một cấp (như Blox Fruits SpawnedEnemies)
            if obj:IsA("Folder") and obj.Name ~= "Terrain" and obj.Name ~= "Camera" then
                for _, sub in ipairs(obj:GetChildren()) do
                    checkAndAddMob(sub)
                end
            end
        end

        -- Sắp xếp tăng dần theo khoảng cách (ưu tiên mục tiêu gần nhất)
        table.sort(rawTargets, function(a, b)
            return a.Distance < b.Distance
        end)

        -- Chỉ giữ tối đa PoolSize mục tiêu vào cache
        local finalCache = {}
        for i = 1, math.min(#rawTargets, config.PoolSize) do
            table.insert(finalCache, rawTargets[i])
        end

        State.TargetCache = finalCache
    end

    -- 3. Tầng Hiển Thị Toán Học (Render Loop - Mỗi frame)
    local function onRenderStep(deltaTime)
        -- Kiểm tra chu kỳ quét Scanner Loop
        lastScan = lastScan + deltaTime
        if lastScan >= config.ScanInterval then
            lastScan = 0
            if State.Flags.ArrowESP then
                updateTargetCache()
            end
        end

        -- Nếu tắt tính năng thì ẩn hết pool
        if not State.Flags.ArrowESP then
            for i = 1, config.PoolSize do
                if arrowPool[i].Visible then
                    arrowPool[i].Visible = false
                end
            end
            return
        end

        -- Tâm màn hình (Viewport)
        local viewportSize = Camera.ViewportSize
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local radius = config.Radius

        local targets = State.TargetCache

        for i = 1, config.PoolSize do
            local arrow = arrowPool[i]
            local targetData = targets[i]

            if not targetData or not targetData.Root or not targetData.Root.Parent then
                arrow.Visible = false
            else
                local targetPos = targetData.Root.Position
                local dist = targetData.Distance

                -- [Bước A: Chuyển vị trí mục tiêu về Camera Object Space]
                local relativePos = Camera.CFrame:PointToObjectSpace(targetPos)
                -- relativePos.X: Trái (-) / Phải (+)
                -- relativePos.Y: Dưới (-) / Trên (+)
                -- relativePos.Z: Trước (-) / Sau (+) trong camera convention của Roblox

                -- [Bước B: Tính góc phương vị la bàn 2D]
                -- Màn hình: trục X sang phải (+X), trục Y hướng xuống (+Y)
                -- Khi nhìn vào relativePos: +X là lệch phải, -Z là phía trước camera (tương ứng -Y trên màn hình), +Z là phía sau (tương ứng +Y)
                local dirX = relativePos.X
                local dirY = relativePos.Z -- Lấy relativePos.Z làm trục dọc

                local angleRad = math.atan2(dirY, dirX)

                -- [Bước C: Tọa độ trên đường tròn tâm (centerX, centerY)]
                local arrowX = centerX + radius * math.cos(angleRad)
                local arrowY = centerY + radius * math.sin(angleRad)

                arrow.Position = UDim2.fromOffset(arrowX, arrowY)

                -- [Bước D: Xoay đầu mũi tên]
                -- atan2(dirY, dirX) trả về góc với 0 rad là hướng +X (sang phải)
                -- Mũi tên gốc rbxassetid://6034818372 hướng lên trên (-Y trong screen space)
                -- Chuyển Rad -> Deg và bù +90 độ để đầu nhọn hướng ra ngoài vòng tròn tâm ngắm
                local angleDeg = math.deg(angleRad) + 90
                arrow.Rotation = angleDeg

                -- [Bước E: Nội suy màu theo khoảng cách (Distance Lerp)]
                -- Gần = Đỏ (nguy hiểm), Xa = Xanh lá
                local alpha = math.clamp(dist / config.MaxDistance, 0, 1)
                local currentColor = config.MinColor:Lerp(config.MaxColor, alpha)
                arrow.ImageColor3 = currentColor

                arrow.Visible = true
            end
        end
    end

    local renderConnection = RunService.RenderStepped:Connect(onRenderStep)
    Maid:GiveTask(renderConnection)

    -- Cleanup
    Maid:GiveTask(function()
        for _, arrow in ipairs(arrowPool) do
            arrow:Destroy()
        end
    end)

    return ArrowESP
end

return ArrowESP
