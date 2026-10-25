--[[
    Maid.lua
    Quản lý dọn dẹp task, RBXScriptConnection, instances để triệt tiêu memory leak.
]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
    local self = setmetatable({
        _tasks = {}
    }, Maid)
    return self
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
            if task.Connected then
                task:Disconnect()
            end
        elseif typeof(task) == "Instance" then
            task:Destroy()
        elseif type(task) == "function" then
            local success, err = pcall(task)
            if not success then
                warn("[Maid Error]:", err)
            end
        elseif type(task) == "table" and typeof(task.Destroy) == "function" then
            task:Destroy()
        end
    end
end

function Maid:Destroy()
    self:DoCleaning()
    setmetatable(self, nil)
end

return Maid
