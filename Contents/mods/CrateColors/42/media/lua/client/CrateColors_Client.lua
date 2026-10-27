-- ============================================================================
-- Crate Colors - client: right-click menu + receiving tints from the server
-- ============================================================================
require "CrateColors_Shared"
require "CrateColors_UI"
require "TimedActions/ISPaintContainerAction"
require "TimedActions/ISTimedActionQueue"

-- Walk to the container, then queue the paint action.
function CrateColors.queuePaint(character, obj, r, g, b, clear)
    local brush = CrateColors.findBrush(character)
    local paint = CrateColors.findPaint(character)

    if not clear then
        if brush then ISInventoryPaneContextMenu.transferIfNeeded(character, brush) end
        if paint then ISInventoryPaneContextMenu.transferIfNeeded(character, paint) end
    end

    if luautils.walkAdj(character, obj:getSquare(), true) then
        ISTimedActionQueue.add(ISPaintContainerAction:new(character, obj, brush, paint, r, g, b, clear))
    end
end

-- ---------------------------------------------------------------------------
-- Context menu
-- ---------------------------------------------------------------------------
local function collectContainers(worldobjects)
    local seen, list = {}, {}
    for _, wo in ipairs(worldobjects) do
        local sq = wo:getSquare()
        if sq then
            local objs = sq:getObjects()
            for i = 0, objs:size() - 1 do
                local o = objs:get(i)
                if not seen[o] and CrateColors.isColorable(o) then
                    seen[o] = true
                    table.insert(list, o)
                end
            end
        end
    end
    return list
end

local function containerName(obj)
    local c = obj:getContainer()
    local name = obj:getName() or (c and c:getType()) or "Container"
    if obj.getTileName and obj:getTileName() then name = obj:getTileName() end
    local key = "IGUI_ContainerTitle_" .. tostring(c and c:getType() or "")
    local t = getText(key)
    if t and t ~= key then name = t end
    return name
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end

    local containers = collectContainers(worldobjects)
    if #containers == 0 then return end
    if test then return true end

    local parent = context:addOption("Paint Container", nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, obj in ipairs(containers) do
        local label = (#containers > 1) and containerName(obj) or "Choose color..."
        local opt = sub:addOption(label, character, CrateColorsDialog.open, obj)

        local hasBrush = CrateColors.findBrush(character) ~= nil
        local hasPaint = CrateColors.findPaint(character) ~= nil
        if (CrateColors.Config.RequireBrush and not hasBrush) or not hasPaint then
            opt.notAvailable = true
            local tip = ISToolTip:new(); tip:initialise(); tip:setVisible(false)
            tip:setName("Paint Container")
            tip.description = "Requires: "
                .. (CrateColors.Config.RequireBrush and "Paintbrush + " or "")
                .. "any can of paint"
            opt.toolTip = tip
        end

        if CrateColors.getStoredColor(obj) then
            local stripLabel = (#containers > 1) and ("Remove paint: " .. containerName(obj)) or "Remove paint"
            local strip = sub:addOption(stripLabel, character, function(chr, o)
                CrateColors.queuePaint(chr, o, nil, nil, nil, true)
            end, obj)
            if not CrateColors.Config.AllowFreeStrip and ((CrateColors.Config.RequireBrush and not hasBrush) or not hasPaint) then
                strip.notAvailable = true
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- ---------------------------------------------------------------------------
-- Server -> client sync (dedicated / hosted MP)
-- ---------------------------------------------------------------------------
local function onServerCommand(module, command, args)
    if module ~= CrateColors.NET_MODULE or command ~= "applyTint" then return end
    local obj = CrateColors.resolveRef(args)
    if not obj then return end  -- square not loaded here; LoadGridsquare will catch it
    if args.clear then
        CrateColors.clearColor(obj)
    else
        CrateColors.setColor(obj, args.r, args.g, args.b)
    end
end
Events.OnServerCommand.Add(onServerCommand)
