require("utility\\animation")
AnimationList = {
    entity = {}
}
function AnimationList:new()
    local object = {}
    setmetatable(object, self)
    self.__index = self
    self.__newIndex = function (index)
        return self:item(index)
    end
    return object
end
function AnimationList:toTable()
    return self.entity
end
function AnimationList:item(index)
    return self.entity[index]
end
function AnimationList:insert(arg1, arg2)
    if arg2 == nil then
        table.insert(self.entity, arg1)
    else
        table.insert(self.entity, arg1, arg2)
    end
end
function AnimationList:remove(index)
    table.remove(self.entity, index)
end
function AnimationList:removeItem(item)
    for k, v in pairs(self.entity) do
        if table.equals(item, v) then
            table.remove(self.entity, k)
            return
        end
    end
end
function AnimationList:concat(animationList)
    table.concat(this.entity, animationList.entity)
end
function AnimationList:sort()
    table.sort(this.entity)
end
function AnimationList:count()
    return #self.entity
end
function AnimationList:first()
    if #self.entity > 0 then
        return self.entity(1)
    else
        return nil
    end
end
function AnimationList:last()
    return self.entity[#self.entity]
end
function AnimationList:create(veolocity, defaultProgress, isRepeat, fulfilledCallback, returnedCallback)
    self:insert(Animation:new(veolocity, defaultProgress, isRepeat, fulfilledCallback, returnedCallback))
    return self:last()
end
function AnimationList:update(deltaTime)
    for k = 1, #self.entity do
        self.entity[k]:update(deltaTime)
    end
end