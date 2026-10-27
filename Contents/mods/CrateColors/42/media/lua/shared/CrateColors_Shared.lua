-- ============================================================================
-- Crate Colors (Build 42) - shared logic
-- Loaded on client AND server. Holds config, paint detection, and the code
-- that actually tints a world object and persists the tint in its modData.
-- ============================================================================

CrateColors = CrateColors or {}

-- ---------------------------------------------------------------------------
-- CONFIG  (edit these to tune the mod; v1 keeps them here rather than in
-- sandbox options so nothing depends on translation-file formats)
-- ---------------------------------------------------------------------------
CrateColors.Config = {
    RequireBrush        = true,   -- need a paintbrush in inventory
    PaintUsesPerCoat    = 1,      -- drainable "uses" consumed per repaint
    ActionTicks         = 150,    -- timed-action length (≈ 3 s at normal speed)
    AllowFreeStrip      = true,   -- "Remove paint" needs no paint/brush
    Alpha               = 1.0,    -- tint alpha passed to setCustomColor
}

CrateColors.MODDATA_KEY = "CrateColors_RGB"   -- {r=,g=,b=} stored on the object
CrateColors.NET_MODULE  = "CrateColors"

-- Vanilla brushes (B42 adds a crafted one). Anything tagged base:paintbrush
-- is also accepted, so modded brushes work.
CrateColors.BRUSH_TYPES = {
    ["Base.Paintbrush"]        = true,
    ["Base.PaintbrushCrafted"] = true,
}

-- ---------------------------------------------------------------------------
-- Small compatibility helpers (B42 renamed a few drainable methods mid-cycle)
-- ---------------------------------------------------------------------------
local function hasTag(item, tag)
    if item.hasTag then
        local ok, res = pcall(function() return item:hasTag(tag) end)
        if ok and res then return true end
    end
    return false
end

local function usesLeft(item)
    if item.getCurrentUsesFloat then return item:getCurrentUsesFloat() end
    if item.getUsedDelta      then return item:getUsedDelta()        end
    return 1
end

function CrateColors.isBrush(item)
    if not item then return false end
    if CrateColors.BRUSH_TYPES[item:getFullType()] then return true end
    return hasTag(item, "base:paintbrush") or hasTag(item, "Paintbrush")
end

function CrateColors.isPaint(item)
    if not item then return false end
    if CrateColors.isBrush(item) then return false end
    if hasTag(item, "base:paint") or hasTag(item, "Paint") then
        return usesLeft(item) > 0
    end
    -- Fallback for older/modded paint: Base.PaintXxx drainables
    local t = item:getType() or ""
    if string.sub(t, 1, 5) == "Paint" and t ~= "PaintbucketEmpty" then
        return usesLeft(item) > 0
    end
    return false
end

-- Searches main inventory + equipped bags.
local function findFirst(character, predicate)
    local inv = character:getInventory()
    local found = inv:getFirstEvalRecurse(predicate)
    return found
end

function CrateColors.findBrush(character)
    return findFirst(character, CrateColors.isBrush)
end

function CrateColors.findPaint(character)
    return findFirst(character, CrateColors.isPaint)
end

function CrateColors.consumePaint(character, paint)
    if not paint then return end
    for _ = 1, CrateColors.Config.PaintUsesPerCoat do
        if paint.UseAndSync then paint:UseAndSync() else paint:Use() end
        if usesLeft(paint) <= 0 then break end
    end
end

-- ---------------------------------------------------------------------------
-- Which world objects count as a "crate"? Per the design: every container.
-- ---------------------------------------------------------------------------
function CrateColors.isColorable(obj)
    if not obj then return false end
    if instanceof(obj, "IsoDeadBody") then return false end
    if instanceof(obj, "IsoMovingObject") then return false end
    return obj:getContainer() ~= nil
end

-- ---------------------------------------------------------------------------
-- Applying / clearing the tint
-- ---------------------------------------------------------------------------
local function clamp01(v)
    v = tonumber(v) or 1
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- Visual only. Safe to call anywhere (used when chunks load, too).
function CrateColors.renderTint(obj, r, g, b)
    if r == nil then
        obj:setCustomColor(1, 1, 1, 1)   -- white tint == original sprite
    else
        obj:setCustomColor(clamp01(r), clamp01(g), clamp01(b), CrateColors.Config.Alpha)
    end
end

-- Authoritative change: tint + persist in modData.
function CrateColors.setColor(obj, r, g, b)
    local md = obj:getModData()
    md[CrateColors.MODDATA_KEY] = { r = clamp01(r), g = clamp01(g), b = clamp01(b) }
    CrateColors.renderTint(obj, r, g, b)
end

function CrateColors.clearColor(obj)
    if obj:hasModData() then
        obj:getModData()[CrateColors.MODDATA_KEY] = nil
    end
    CrateColors.renderTint(obj, nil)
end

function CrateColors.getStoredColor(obj)
    if not obj:hasModData() then return nil end
    return obj:getModData()[CrateColors.MODDATA_KEY]
end

-- Re-apply stored tints whenever a square streams in (client and server).
local function onLoadGridsquare(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj:hasModData() then
            local c = obj:getModData()[CrateColors.MODDATA_KEY]
            if c then CrateColors.renderTint(obj, c.r, c.g, c.b) end
        end
    end
end
Events.LoadGridsquare.Add(onLoadGridsquare)

-- ---------------------------------------------------------------------------
-- Network helpers: identify an object by square + index + sprite name
-- ---------------------------------------------------------------------------
function CrateColors.objectRef(obj)
    local sq = obj:getSquare()
    local sprite = obj:getSprite() and obj:getSprite():getName() or ""
    return { x = sq:getX(), y = sq:getY(), z = sq:getZ(),
             idx = obj:getObjectIndex(), sprite = sprite }
end

function CrateColors.resolveRef(ref)
    local sq = getCell():getGridSquare(ref.x, ref.y, ref.z)
    if not sq then return nil end
    local objects = sq:getObjects()
    -- Fast path: index still matches
    if ref.idx >= 0 and ref.idx < objects:size() then
        local o = objects:get(ref.idx)
        local s = o:getSprite() and o:getSprite():getName() or ""
        if s == ref.sprite then return o end
    end
    -- Slow path: first container with the same sprite
    for i = 0, objects:size() - 1 do
        local o = objects:get(i)
        local s = o:getSprite() and o:getSprite():getName() or ""
        if s == ref.sprite and CrateColors.isColorable(o) then return o end
    end
    return nil
end

-- Called at the end of the timed action. In SP this just tints locally; on a
-- dedicated server it also syncs modData and tells every client to re-tint.
function CrateColors.broadcast(obj)
    if not isServer() then return end
    obj:transmitModData()
    local args = CrateColors.objectRef(obj)
    local c = CrateColors.getStoredColor(obj)
    if c then args.r, args.g, args.b = c.r, c.g, c.b else args.clear = true end
    sendServerCommand(CrateColors.NET_MODULE, "applyTint", args)
end
