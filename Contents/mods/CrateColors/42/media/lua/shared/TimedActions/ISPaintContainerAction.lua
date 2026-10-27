-- ============================================================================
-- Crate Colors - timed action
-- B42 pattern: complete() runs on the server in MP (and locally in SP), so all
-- state changes (tint, modData, paint consumption) happen there.
-- ============================================================================
require "TimedActions/ISBaseTimedAction"
require "CrateColors_Shared"

ISPaintContainerAction = ISBaseTimedAction:derive("ISPaintContainerAction")

function ISPaintContainerAction:isValid()
    if not self.object or not self.object:getSquare() then return false end
    if self.clear and CrateColors.Config.AllowFreeStrip then return true end
    local inv = self.character:getInventory()
    if CrateColors.Config.RequireBrush then
        if not self.brush or not inv:containsRecursive(self.brush) then return false end
    end
    return self.paint ~= nil and inv:containsRecursive(self.paint)
end

function ISPaintContainerAction:waitToStart()
    self.character:faceThisObject(self.object)
    return self.character:shouldBeTurning()
end

function ISPaintContainerAction:update()
    self.character:faceThisObject(self.object)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISPaintContainerAction:start()
    self:setActionAnim("Paint")
    if self.brush then
        self:setOverrideHandModels(self.brush, nil)
    end
    self.sound = self.character:playSound("Painting")
end

function ISPaintContainerAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function ISPaintContainerAction:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function ISPaintContainerAction:perform()
    self:stopSound()
    ISBaseTimedAction.perform(self)
end

function ISPaintContainerAction:complete()
    if self.clear then
        CrateColors.clearColor(self.object)
    else
        CrateColors.setColor(self.object, self.r, self.g, self.b)
        CrateColors.consumePaint(self.character, self.paint)
    end
    CrateColors.broadcast(self.object)
    return true
end

function ISPaintContainerAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return CrateColors.Config.ActionTicks
end

-- clear == true removes paint (r/g/b ignored)
function ISPaintContainerAction:new(character, object, brush, paint, r, g, b, clear)
    local o = ISBaseTimedAction.new(self, character)
    o.object  = object
    o.brush   = brush
    o.paint   = paint
    o.r, o.g, o.b = r, g, b
    o.clear   = clear and true or false
    o.maxTime = o:getDuration()
    return o
end
