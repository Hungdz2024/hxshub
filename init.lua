--[[
    init.lua
    [Entry Point] Modular architecture for Roblox Mobile / Delta Executor
    - Khởi tạo Maid & State
    - Khởi tạo ScreenGui (ResetOnSpawn = false)
    - Nạp UI Floating Bubble & Modules (Night Vision, Arrow ESP)
    - Cung cấp cơ chế Unload an toàn để không rò rỉ RAM khi execute lại
]]

-- Dọn dẹp instance cũ nếu người dùng nạp lại script (Prevent Duplicate UI)
if getgenv and getgenv()._DeltaProjectMaid then
    pcall(function()
        getgenv()._DeltaProjectMaid:Destroy()
    end)
    getgenv()._DeltaProjectMaid = nil
end

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Nạp các Module cục bộ (Khi dev dùng loader hoặc Darklua bundle)
local MaidClass = loadfile and loadfile("core/maid.lua")() or require(script.core.maid)
local State = loadfile and loadfile("core/state.lua")() or require(script.core.state)
local FloatingBubble = loadfile and loadfile("ui/floating_bubble.lua")() or require(script.ui.floating_bubble)
local NightVision = loadfile and loadfile("modules/night_vision.lua")() or require(script.modules.night_vision)
local ArrowESP = loadfile and loadfile("modules/arrow_esp.lua")() or require(script.modules.arrow_esp)

-- Khởi tạo Maid toàn cục
local Maid = MaidClass.new()
if getgenv then
    getgenv()._DeltaProjectMaid = Maid
end

-- Khởi tạo ScreenGui với ResetOnSpawn = false
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaUniversalProject"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Ưu tiên chèn vào CoreGui (nếu executor cấp quyền), fallback về PlayerGui
local success, _ = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not success or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
Maid:GiveTask(ScreenGui)

-- Khởi tạo các Module hệ thống
local nightVisionModule = NightVision.Init(State, Maid)
local arrowESPModule = ArrowESP.Init(State, Maid, ScreenGui)

-- Khởi tạo UI Bong bóng nổi & Menu điều khiển
FloatingBubble.Init(
    State,
    Maid,
    ScreenGui,
    function(enabled)
        nightVisionModule.SetEnabled(enabled)
    end,
    function(enabled)
        State.Flags.ArrowESP = enabled
    end
)

print("[Delta Project]: Universal UI, Night Vision & Arrow ESP đã nạp thành công!")

return {
    Maid = Maid,
    State = State,
    Unload = function()
        Maid:Destroy()
        if getgenv then
            getgenv()._DeltaProjectMaid = nil
        end
        print("[Delta Project]: Đã dọn dẹp và unload hoàn tất.")
    end
}
