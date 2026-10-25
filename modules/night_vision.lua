--[[
    NightVision.lua
    Workflow Module 2: Quản lý Fullbright / Night Vision
    Snapshot thông số Lighting -> Khóa thông số mỗi frame -> Khôi phục khi tắt
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local NightVision = {}
local renderConnection = nil

function NightVision.Init(State, Maid)
    -- Bước 1: Lưu trữ thông số ban đầu (Snapshot)
    State.OriginalLighting.Brightness = Lighting.Brightness
    State.OriginalLighting.ClockTime = Lighting.ClockTime
    State.OriginalLighting.FogEnd = Lighting.FogEnd
    State.OriginalLighting.GlobalShadows = Lighting.GlobalShadows
    State.OriginalLighting.Ambient = Lighting.Ambient
    State.OriginalLighting.OutdoorAmbient = Lighting.OutdoorAmbient

    -- Hàm áp đặt ánh sáng Fullbright
    local function applyFullbright()
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    end

    -- Hàm khôi phục lại Lighting gốc
    local function restoreLighting()
        Lighting.Brightness = State.OriginalLighting.Brightness
        Lighting.ClockTime = State.OriginalLighting.ClockTime
        Lighting.FogEnd = State.OriginalLighting.FogEnd
        Lighting.GlobalShadows = State.OriginalLighting.GlobalShadows
        Lighting.Ambient = State.OriginalLighting.Ambient
        Lighting.OutdoorAmbient = State.OriginalLighting.OutdoorAmbient
    end

    -- Hàm Toggle bật/tắt
    function NightVision.SetEnabled(enabled)
        State.Flags.NightVision = enabled

        if enabled then
            applyFullbright()
            -- Khóa ánh sáng mỗi frame để ngăn script môi trường/thời tiết của game override
            if not renderConnection then
                renderConnection = RunService.RenderStepped:Connect(applyFullbright)
                Maid:GiveTask(renderConnection)
            end
        else
            if renderConnection then
                renderConnection:Disconnect()
                renderConnection = nil
            end
            restoreLighting()
        end
    end

    -- Đăng ký cleanup khi gỡ bỏ script
    Maid:GiveTask(function()
        if renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end
        restoreLighting()
    end)

    return NightVision
end

return NightVision
