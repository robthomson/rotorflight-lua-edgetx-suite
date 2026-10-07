local Render = {}

local GOVERNOR_LABELS = {
  [0] = "OFF",
  [1] = "IDLE",
  [2] = "SPOOLUP",
  [3] = "RECOVERY",
  [4] = "ACTIVE",
  [5] = "THROFF",
  [6] = "LOSTHS",
  [7] = "AUTOROT",
  [8] = "BAILOUT",
  [100] = "DISABLED",
  [101] = "DISARMED"
}

-- The flight controller's governor MODES, in the order it numbers them (govMode_e: NONE,
-- LIMIT, DIRECT, ELECTRIC, NITRO). Only the first two are named here, and only because they are
-- the two in which the board never runs a governor state machine at all: it leaves the state
-- sensor this box otherwise shows standing at THROTTLE_OFF for the whole flight, so the box
-- would report "throttle off" over a hovering helicopter. In DIRECT and above the state sensor
-- is maintained and is what the box should show, exactly as it does today.
local GOV_MODE_NONE = 0
local GOV_MODE_LIMIT = 1

local ARMING_DISABLE_FLAG_LABELS = {
  [0] = "No Gyro",
  [1] = "Fail Safe",
  [2] = "RX Fail Safe",
  [3] = "Bad RX Recovery",
  [4] = "Box Fail Safe",
  [5] = "Governor",
  [6] = "RPM Signal",
  [7] = "Throttle",
  [8] = "Angle",
  [9] = "Boot Grace Time",
  [10] = "No Pre Arm",
  [11] = "Load",
  [12] = "CALIB",
  [13] = "CLI",
  [14] = "CMS Menu",
  [15] = "BST",
  [16] = "MSP",
  [17] = "Paralyze",
  [18] = "GPS",
  [19] = "Resc",
  [20] = "RPM Filter",
  [21] = "Reboot Required",
  [22] = "DSHOT Bitbang",
  [23] = "Acc Calibration",
  [24] = "Motor Protocol",
  [25] = "Arm Switch"
}

local function translate(state, key, fallback)
  local i18n = state and state.i18n
  local t = i18n and i18n.t
  if type(t) == "function" then
    local ok, value = pcall(t, key, fallback)
    if ok and type(value) == "string" and value ~= "" then
      return value
    end
  end
  return fallback
end

local function armingDisableFlagsToText(state)
  local rawFlags = state and state.armDisableFlags
  local flags = tonumber(rawFlags)
  if flags == nil and type(rawFlags) == "string" then
    flags = tonumber(rawFlags, 16)
  end
  if flags == nil then
    return nil
  end

  flags = math.floor(flags)
  if flags < 0 then
    flags = flags + 4294967296
  end
  if flags == 0 then
    return nil
  end

  local labels = {}
  for bitIndex = 0, 25 do
    local isSet = false
    if bit32 then
      isSet = bit32.band(flags, bit32.lshift(1, bitIndex)) ~= 0
    else
      isSet = (flags % (2 ^ (bitIndex + 1))) >= (2 ^ bitIndex)
    end
    if isSet then
      labels[#labels + 1] = translate(
        state,
        "app.modules.fblstatus.arming_disable_flag_" .. tostring(bitIndex),
        ARMING_DISABLE_FLAG_LABELS[bitIndex] or ("FLAG" .. tostring(bitIndex))
      )
    end
  end

  if #labels == 0 then
    return nil
  end

  return table.concat(labels, ",")
end

local function armFlagsToIsArmed(value)
  local numeric = tonumber(value)
  if numeric == nil then
    return nil
  end
  numeric = math.floor(numeric)
  if numeric == 1 or numeric == 3 then return true end
  if numeric == 0 or numeric == 2 then return false end
  return nil
end

local function resolveArmedState(state)
  local fromArmFlags = armFlagsToIsArmed(state and state.armFlags)
  if fromArmFlags ~= nil then
    return fromArmFlags
  end
  return state and state.armed == true
end

local function governorText(state)
  local disableReason = armingDisableFlagsToText(state)
  if disableReason then
    return disableReason
  end

  local armed = resolveArmedState(state)
  local raw = tonumber(state and state.governor)
  if armFlagsToIsArmed(state and state.armFlags) == false then
    raw = 101
  end
  if not armed then
    return translate(state, "widgets.governor.DISARMED", GOVERNOR_LABELS[101])
  end
  -- The mode decides before the state does, because in these two there is no state to read.
  -- The wording follows the configurator's own names for the modes, so that a pilot reads the
  -- same word here as on the page the mode was set on.
  local mode = tonumber(state and state.governorMode)
  if mode == GOV_MODE_NONE then
    return translate(state, "widgets.governor.MODE_OFF", "Gov. Off")
  end
  if mode == GOV_MODE_LIMIT then
    return translate(state, "widgets.governor.MODE_LIMIT", "Gov. Limit")
  end
  if raw == nil then
    return translate(state, "widgets.governor.UNKNOWN", "UNKNOWN")
  end
  local key = GOVERNOR_LABELS[raw]
  if not key then
    return translate(state, "widgets.governor.UNKNOWN", "UNKNOWN")
  end
  return translate(state, "widgets.governor." .. key, key)
end

local function governorColor(state, box, utils, compiled)
  local armed = resolveArmedState(state)
  local value = tonumber(state and state.governor)
  if armFlagsToIsArmed(state and state.armFlags) == false then
    value = 101
  end

  if type(box and box.thresholds) == "table" and #box.thresholds > 0 and utils and type(utils.resolveThresholdColor) == "function" then
    local govText = governorText(state)
    -- The untranslated key tried when the text matches no threshold. While armed in the two
    -- modes that keep no state it is the mode's, MODE_OFF or MODE_LIMIT, which is also the name
    -- a user theme matches the mode label by. The state sensor's constant 0 would otherwise
    -- match a threshold on the OFF state in a bundle whose translation of OFF is "OFF" and in
    -- no other.
    local govKey = GOVERNOR_LABELS[value]
    if armed then
      local mode = tonumber(state and state.governorMode)
      if mode == GOV_MODE_NONE then
        govKey = "MODE_OFF"
      elseif mode == GOV_MODE_LIMIT then
        govKey = "MODE_LIMIT"
      end
    end
    local threshColor = utils.resolveThresholdColor(govText, box.thresholds, nil, false, box, state, nil, compiled)
    if threshColor == nil and govKey ~= nil then
      threshColor = utils.resolveThresholdColor(govKey, box.thresholds, nil, false, box, state, nil, compiled)
    end
    if threshColor ~= nil then
      return threshColor
    end
  end

  local defaultText = (utils and utils.resolveTextColor
    and utils.resolveTextColor(box, state, WHITE, nil, nil, compiled)) or (box and box.textcolor) or WHITE
  local warningColor = box and box.warningcolor or COLOR_THEME_WARNING or RED or defaultText
  local activeColor = box and box.activecolor or COLOR_THEME_PRIMARY1 or GREEN or defaultText
  if utils and utils.normalizeColor then
    warningColor = utils.normalizeColor(warningColor, defaultText)
    activeColor = utils.normalizeColor(activeColor, defaultText)
  end

  if box and box.bgcolor ~= nil and warningColor == box.bgcolor then
    warningColor = defaultText
  end
  if box and box.bgcolor ~= nil and activeColor == box.bgcolor then
    activeColor = defaultText
  end

  if not armed then
    return warningColor
  end

  if value and value >= 4 and value <= 8 then
    return activeColor
  end

  if value == 3 then
    return warningColor
  end

  return defaultText
end

function Render.render(nodes, rect, box, state, _, utils)
  local lastFlags = nil
  local lastArmFlags = nil
  local lastArmed = nil
  local lastGov = nil
  local lastMode = nil
  local cachedText = nil

  local textGetter = function()
    local flags = state and state.armDisableFlags
    local armFlags = state and state.armFlags
    local armed = state and state.armed
    local gov = state and state.governor
    local mode = state and state.governorMode

    if flags == lastFlags and armFlags == lastArmFlags and armed == lastArmed and gov == lastGov
        and mode == lastMode and cachedText ~= nil then
      return cachedText
    end

    lastFlags = flags
    lastArmFlags = armFlags
    lastArmed = armed
    lastGov = gov
    lastMode = mode

    local valueText = governorText(state)
    valueText = utils.applyLowResMaxChars(valueText, box, state, "max_chars_lowres")
    cachedText = valueText or "--"
    return cachedText
  end

  -- Compiled once, here where the box is rendered, rather than on every value change in the
  -- reactive sweep -- the argument for why that is the same answer is on Utils.renderThresholds.
  local compiledThresholds = utils.renderThresholds(box, state, false, WHITE)

  local lastColorArmFlags = nil
  local lastColorArmed = nil
  local lastColorGov = nil
  -- The mode belongs in this key as well as in the text one: where a box carries thresholds,
  -- governorColor matches them against the text, and the text now depends on the mode.
  local lastColorMode = nil
  local cachedColor = nil

  local colorGetter = function()
    local armFlags = state and state.armFlags
    local armed = state and state.armed
    local gov = state and state.governor
    local mode = state and state.governorMode

    if armFlags == lastColorArmFlags and armed == lastColorArmed and gov == lastColorGov
        and mode == lastColorMode and cachedColor ~= nil then
      return cachedColor
    end

    lastColorArmFlags = armFlags
    lastColorArmed = armed
    lastColorGov = gov
    lastColorMode = mode

    cachedColor = governorColor(state, box, utils, compiledThresholds)
    return cachedColor
  end

  local fontRef = utils.staticFont(box, state, 0, "font", "font_lowres")
  if fontRef == nil then
    fontRef = function()
      return utils.resolveFont(box, state, 0, "font", "font_lowres")
    end
  end

  utils.pushLabel(
    nodes,
    rect.x + 4,
    utils.defaultValueY(rect, box),
    rect.w - 8,
    textGetter,
    colorGetter,
    box.valuealign or box.titlealign or CENTER,
    fontRef
  )
end

return Render
