--[[
    AutoLeftClick.lua
    Workflow Module 4: Auto Left Click (Trigger Bot theo tâm ngắm)
    - Tầng Detection: Mỗi frame bắn 1 tia Raycast từ tâm màn hình (crosshair).
      Nếu tia trúng nhân vật còn sống của Player khác -> gửi input Left Click.
    - Tuyệt đối không click xuyên tường: tia trúng vật cản trước -> dừng.
    - Tầng Injection: Ưu tiên mouse1click / mouse1press + mouse1release của executor,
      fallback VirtualInputManager:SendMouseButtonEvent (chạy tốt trên Delta Mobile).
    - Chu kỳ click mặc định 0.01s -> click đầu tiên phát ngay khi crosshair chạm
      mục tiêu, gần như không có delay.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

local AutoLeftClick = {}

-- Gửi 1 cú Left Click gần như tức thời (press + release)
local function sendLeftClick()
    if type(mouse1click) == "function" then
        pcall(mouse1click)
        return
    end

    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(mouse1press)
        pcall(mouse1release)
        return
    end

    local camera = Workspace.CurrentCamera
    if camera and VirtualInputManager then
        local center = camera.ViewportSize * 0.5
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        end)
    end
end

-- Kiểm tra crosshair (tâm màn hình) có đang trỏ vào Player khác còn sống không
local function getPlayerUnderCrosshair(range, ignoreList, raycastParams)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local viewport = camera.ViewportSize
    local ray = camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)

    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoreList
    raycastParams.IgnoreWater = true

    local result = Workspace:Raycast(ray.Origin, ray.Direction * range, raycastParams)
    if not result then
        return nil
    end

    -- Truy ngược Parent để tìm Model nhân vật tương ứng với Player
    local ancestor = result.Instance
    while ancestor and ancestor ~= Workspace do
        local player = Players:GetPlayerFromCharacter(ancestor)
        if player then
            if player == LocalPlayer then
                return nil
            end

            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health <= 0 then
                return nil
            end

            return player
        end

        ancestor = ancestor.Parent
    end

    return nil
end

function AutoLeftClick.Init(State, Maid)
    local config = State.Settings.AutoClick
    local renderConnection = nil

    local raycastParams = RaycastParams.new()
    raycastParams.IgnoreWater = true

    local cooldown = 0

    local function onRenderStep(deltaTime)
        if cooldown > 0 then
            cooldown = math.max(cooldown - deltaTime, 0)
        end

        if not State.Flags.AutoLeftClick then
            return
        end

        -- Không click khi menu đang mở (tránh bấm nhầm UI) hoặc đang gõ chat
        if State.Flags.MenuOpen or UserInputService:GetFocusedTextBox() then
            return
        end

        if cooldown > 0 then
            return
        end

        local character = LocalPlayer.Character
        if not character or not character.Parent then
            return
        end

        local ignoreList = { character }
        local camera = Workspace.CurrentCamera
        if camera then
            table.insert(ignoreList, camera)
        end

        local target = getPlayerUnderCrosshair(config.Range, ignoreList, raycastParams)
        if target then
            sendLeftClick()
            cooldown = config.ClickInterval
        end
    end

    function AutoLeftClick.SetEnabled(enabled)
        State.Flags.AutoLeftClick = enabled

        if enabled then
            cooldown = 0
            if not renderConnection then
                renderConnection = RunService.RenderStepped:Connect(onRenderStep)
                Maid:GiveTask(renderConnection)
            end
        elseif renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end
    end

    Maid:GiveTask(function()
        if renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end
    end)

    return AutoLeftClick
end

return AutoLeftClick
