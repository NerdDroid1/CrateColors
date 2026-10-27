-- ============================================================================
-- Crate Colors - color selection dialog
-- A small window with a live preview swatch, a hex field, and a button that
-- opens the vanilla full-spectrum HSB picker. Nothing is committed until the
-- player presses "Paint", which queues the timed action.
-- ============================================================================
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "CrateColors_Shared"

CrateColorsDialog = ISPanel:derive("CrateColorsDialog")

local FONT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local PAD = 10

-- --- color helpers ----------------------------------------------------------
local function toHex(r, g, b)
    return string.format("%02X%02X%02X",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function fromHex(s)
    s = s or ""
    if string.sub(s, 1, 1) == "#" then s = string.sub(s, 2) end
    if string.len(s) ~= 6 then return nil end
    local r = tonumber(string.sub(s, 1, 2), 16)
    local g = tonumber(string.sub(s, 3, 4), 16)
    local b = tonumber(string.sub(s, 5, 6), 16)
    if not (r and g and b) then return nil end
    return r / 255, g / 255, b / 255
end

-- The vanilla picker has passed a Lua table, a Color, or a ColorInfo across
-- versions; read whichever we get.
local function readColor(c)
    if not c then return nil end
    if type(c) == "table" then return c.r, c.g, c.b end
    if c.getR then return c:getR(), c:getG(), c:getB() end
    if c.r then return c.r, c.g, c.b end
    return nil
end

-- --- panel ------------------------------------------------------------------
function CrateColorsDialog:createChildren()
    ISPanel.createChildren(self)
    local y = PAD + FONT_SMALL + PAD

    -- swatch occupies left side, controls right
    self.swatch = { x = PAD, y = y, w = 64, h = 64 }

    local cx = PAD + 64 + PAD
    local cw = self.width - cx - PAD

    self.pickBtn = ISButton:new(cx, y, cw, 24, "Choose color...", self, CrateColorsDialog.onPick)
    self.pickBtn:initialise(); self:addChild(self.pickBtn)

    self.hexEntry = ISTextEntryBox:new(toHex(self.r, self.g, self.b), cx, y + 24 + 6, cw, 24)
    self.hexEntry:initialise(); self.hexEntry:instantiate()
    self.hexEntry.onTextChange = function() self:onHexChanged() end
    self:addChild(self.hexEntry)

    y = y + 64 + PAD
    self.statusY = y
    y = y + FONT_SMALL + PAD

    local bw = math.floor((self.width - PAD * 3) / 2)
    self.okBtn = ISButton:new(PAD, y, bw, 25, "Paint", self, CrateColorsDialog.onOK)
    self.okBtn:initialise(); self:addChild(self.okBtn)

    self.cancelBtn = ISButton:new(PAD * 2 + bw, y, bw, 25, "Cancel", self, CrateColorsDialog.onCancel)
    self.cancelBtn:initialise(); self:addChild(self.cancelBtn)

    self:setHeight(y + 25 + PAD)
end

function CrateColorsDialog:prerender()
    ISPanel.prerender(self)
    self:drawText("Paint container", PAD, PAD, 1, 1, 1, 1, UIFont.Small)
    local s = self.swatch
    self:drawRect(s.x, s.y, s.w, s.h, 1, self.r, self.g, self.b)
    self:drawRectBorder(s.x, s.y, s.w, s.h, 1, 0.6, 0.6, 0.6)

    local ok, msg = self:checkTools()
    self.okBtn:setEnable(ok)
    self:drawText(msg, PAD, self.statusY, ok and 0.6 or 1, ok and 1 or 0.4, ok and 0.6 or 0.4, 1, UIFont.Small)
end

function CrateColorsDialog:checkTools()
    local brush = CrateColors.findBrush(self.character)
    local paint = CrateColors.findPaint(self.character)
    if CrateColors.Config.RequireBrush and not brush then return false, "Needs a paintbrush" end
    if not paint then return false, "Needs a can of paint" end
    return true, "Uses: " .. paint:getDisplayName()
end

function CrateColorsDialog:setColor(r, g, b, updateHex)
    self.r, self.g, self.b = r, g, b
    if updateHex then self.hexEntry:setText(toHex(r, g, b)) end
    -- live preview on the actual container (client-side only, reverted on cancel)
    CrateColors.renderTint(self.object, r, g, b)
end

function CrateColorsDialog:onHexChanged()
    local r, g, b = fromHex(self.hexEntry:getText())
    if r then self:setColor(r, g, b, false) end
end

function CrateColorsDialog:onPick()
    if self.picker then self.picker:removeFromUIManager() end
    local initial = ColorInfo.new(self.r, self.g, self.b, 1)
    self.picker = ISColorPickerHSB:new(self:getAbsoluteX() + self.width + 4, self:getAbsoluteY(), initial)
    self.picker:initialise()
    self.picker:setPickedFunc(CrateColorsDialog.onPicked, self)
    self.picker:addToUIManager()
    self.picker:bringToTop()
end

-- (target, color, hideOrMouseUp, ...)
function CrateColorsDialog.onPicked(self, color)
    local r, g, b = readColor(color)
    if r then self:setColor(r, g, b, true) end
end

function CrateColorsDialog:restorePreview()
    local c = CrateColors.getStoredColor(self.object)
    if c then CrateColors.renderTint(self.object, c.r, c.g, c.b)
    else CrateColors.renderTint(self.object, nil) end
end

function CrateColorsDialog:close()
    if self.picker then self.picker:removeFromUIManager(); self.picker = nil end
    self:setVisible(false)
    self:removeFromUIManager()
    CrateColorsDialog.instance = nil
end

function CrateColorsDialog:onOK()
    local ok = self:checkTools()
    if not ok then return end
    self:restorePreview()  -- the timed action applies the real color
    CrateColors.queuePaint(self.character, self.object, self.r, self.g, self.b, false)
    self:close()
end

function CrateColorsDialog:onCancel()
    self:restorePreview()
    self:close()
end

function CrateColorsDialog:new(x, y, character, object)
    local o = ISPanel.new(self, x, y, 260, 200)
    o.character = character
    o.object = object
    o.moveWithMouse = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    local c = CrateColors.getStoredColor(object)
    o.r, o.g, o.b = c and c.r or 0.55, c and c.g or 0.35, c and c.b or 0.2
    return o
end

function CrateColorsDialog.open(character, object)
    if CrateColorsDialog.instance then CrateColorsDialog.instance:onCancel() end
    local x = getCore():getScreenWidth() / 2 - 130
    local y = getCore():getScreenHeight() / 2 - 100
    local d = CrateColorsDialog:new(x, y, character, object)
    d:initialise()
    d:addToUIManager()
    CrateColorsDialog.instance = d
end
