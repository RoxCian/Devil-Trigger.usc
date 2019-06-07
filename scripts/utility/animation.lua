Animation = {
    progress = 0,
    previousProgress = 0,
    veolocity = 0,
    isFreeze = false,
    isRepeat = false,
    fulfilledCallback = nil,
    returnedCallback = nil,
}

function Animation:new(v, p, rep, fulfilledCb, returnedCb)
    local object = {}
    setmetatable(object, self)
    self.__index = self
    p = p or 0
    self:setProgress(p)
    self:setVeolocity(v)
    self.isRepeat = rep or false
    local emptyFunction = function() end
    self.fulfilledCallback = fulfilledCb or function() end
    self.returnedCallback = returnedCb or function() end
    return object
end
function Animation:getProgress()
    return self.progress
end
function Animation:setProgress(value)
    self.previousProgress = self.progress
    if value > 1 then
        local cf = self.veolocity > 0
        if self.isRepeat then
            local i
            i, self.progress = math.modf(value)
        else
            self.progress = 1
            cf = cf and self.progress > self.previousProgress
        end
        if cf then
            self.fulfilledCallback()
        end
    else
        if value < 0 then
            local cf = self.veolocity < 0
            if self.isRepeat then
                local i
                i, self.progress = math.modf(value)
            else
                self.progress = 0
                cf = cf and self.progress < self.previousProgress
            end
            if cf then
                self.returnedCallback()
            end
        else
            self.progress = value
        end
    end
end
function Animation:getVeolocity()
    return self.veolocity
end
function Animation:setVeolocity(value)
    self.veolocity = value
end
function Animation:reset()
    self:setProgress(0)
end
function Animation:reverse()
    self.veolocity = -self.veolocity
end
function Animation:update(deltaTime)
    if not self.isFreeze then
        self:setProgress(self.progress + deltaTime * self.veolocity)
    end
end
function Animation:freeze()
    self.isFreeze = true
end
function Animation:continue()
    self.isFreeze = false
end
function Animation:isFulfilled()
    return self.progress == 1
end
function Animation:isReturned()
    return self.progress == 0
end
function Animation:getIsRepeat()
    return self.isRepeat
end
function Animation:setIsRepeat(value)
    self.isRepeat = value or false
end