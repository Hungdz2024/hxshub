--[[
    State.lua
    Quản lý các biến cờ trạng thái (Flags), cấu hình (Config) và Cache chia sẻ giữa các tầng.
]]

local State = {
    -- Cờ tính năng
    Flags = {
        NightVision = false,
        ArrowESP = false,
        MenuOpen = false,
    },

    -- Cấu hình Arrow ESP
    Settings = {
        ESP = {
            MaxDistance = 500,     -- Khoảng cách tối đa quét mục tiêu (studs)
            ScanInterval = 0.4,    -- Chu kỳ quét Workspace (giây)
            PoolSize = 15,         -- Số lượng mũi tên tối đa trong Object Pool
            Radius = 90,           -- Bán kính hiển thị mũi tên quanh tâm ngắm (pixels)
            MinColor = Color3.fromRGB(255, 45, 45),   -- Màu khi mục tiêu ở gần (nguy hiểm)
            MaxColor = Color3.fromRGB(50, 255, 120),  -- Màu khi mục tiêu ở xa (an toàn)
        },
        UI = {
            BubbleRadius = 24, -- Bán kính bong bóng (Size 48x48)
            DragThreshold = 5, -- Ngưỡng pixel để phân biệt tap vs drag
        }
    },

    -- Cache chia sẻ giữa Scanner Loop (Tầng 2) và Render Loop (Tầng 3)
    TargetCache = {},

    -- Snapshot thuộc tính gốc của game.Lighting
    OriginalLighting = {
        Brightness = 2,
        ClockTime = 14,
        FogEnd = 100000,
        GlobalShadows = true,
        Ambient = Color3.fromRGB(127, 127, 127),
        OutdoorAmbient = Color3.fromRGB(127, 127, 127),
    }
}

return State
