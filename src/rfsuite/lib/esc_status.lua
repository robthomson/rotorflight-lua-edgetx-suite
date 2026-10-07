-- The speed controller's health, in words, out of the two bytes the flight controller publishes
-- for it: ESC1 Status and ESC1 Model.
--
-- The flight controller keeps one status word and one signature byte per speed controller
-- (`escSensorData_t.status` and `.id` in `src/main/sensors/esc_sensor.c` of the firmware) and
-- sends them as telemetry slots 27 and 28, which the suite decodes into the sensors `EscF` and
-- `Esc#` (`lib/rf2tlm_sensors.lua`). The signature says which protocol answered and therefore
-- how the status word is laid out; there is no common layout, so the word cannot be read at all
-- without it.
--
-- This module is the layout, and nothing else: no sensor read, no file, no global but `bit32`.
-- It is the one place the per-protocol bit meanings are written down, so a caller never has to
-- know which manufacturer it is looking at.
--
-- The text is carried as a complete build marker rather than as a key looked up at run time.
-- Translation happens when the install is packaged -- the packager rewrites each marker in the
-- staged tree into the translated string -- and a key assembled from a table lookup is the one
-- shape that step cannot follow, so it would reach the screen untranslated.
local M = {}

-- What a verdict is worth. A caller colours the line from this and keeps the worst it has seen;
-- the numbers rise with severity so that "worst" is a comparison. There is no zero: nothing to
-- report at all is a nil verdict, not a level, because a caller has to tell "the controller says
-- it is fine" apart from "no controller answered" and a number cannot carry both.
M.LEVEL_OK = 1
M.LEVEL_WARNING = 2
M.LEVEL_ERROR = 3

-- Signatures, from the firmware's own list (`esc_sensor.c`, the `ESC_SIG_*` defines). 0x00 is no
-- speed controller at all; 0xFF is not a manufacturer but a request, see RESTART below.
local SIG_NONE = 0x00
local SIG_RESTART = 0xFF

-- One entry per condition a status word can report, and the text a pilot reads for it. Several
-- protocols report the same physical condition, so the table is keyed by the condition rather
-- than by manufacturer and bit -- which is also what keeps the number of strings to translate
-- down to the number of distinct things that can be wrong.
local TEXT = {
  ok = "@i18n(widgets.escstatus.ok)@",
  restart = "@i18n(widgets.escstatus.restart)@",
  no_status = "@i18n(widgets.escstatus.no_status)@",
  unknown = "@i18n(widgets.escstatus.unknown)@",
  fault = "@i18n(widgets.escstatus.fault)@",
  undervoltage = "@i18n(widgets.escstatus.undervoltage)@",
  overvoltage = "@i18n(widgets.escstatus.overvoltage)@",
  overcurrent = "@i18n(widgets.escstatus.overcurrent)@",
  current_warning = "@i18n(widgets.escstatus.current_warning)@",
  overheat = "@i18n(widgets.escstatus.overheat)@",
  temp_warning = "@i18n(widgets.escstatus.temp_warning)@",
  bec_undervoltage = "@i18n(widgets.escstatus.bec_undervoltage)@",
  bec_overvoltage = "@i18n(widgets.escstatus.bec_overvoltage)@",
  bec_overcurrent = "@i18n(widgets.escstatus.bec_overcurrent)@",
  bec_overheat = "@i18n(widgets.escstatus.bec_overheat)@",
  bec_voltage = "@i18n(widgets.escstatus.bec_voltage)@",
  motor_hot = "@i18n(widgets.escstatus.motor_hot)@",
  input_voltage = "@i18n(widgets.escstatus.input_voltage)@",
  motor_locked = "@i18n(widgets.escstatus.motor_locked)@",
  throttle_at_start = "@i18n(widgets.escstatus.throttle_at_start)@",
  throttle_lost = "@i18n(widgets.escstatus.throttle_lost)@",
  throttle = "@i18n(widgets.escstatus.throttle)@",
  motor_wiring = "@i18n(widgets.escstatus.motor_wiring)@",
  startup = "@i18n(widgets.escstatus.startup)@",
  motor_saturated = "@i18n(widgets.escstatus.motor_saturated)@",
  consumption = "@i18n(widgets.escstatus.consumption)@",
  capacity_limit = "@i18n(widgets.escstatus.capacity_limit)@",
  current_limit = "@i18n(widgets.escstatus.current_limit)@",
  battery_limit = "@i18n(widgets.escstatus.battery_limit)@",
  esc_temp_limit = "@i18n(widgets.escstatus.esc_temp_limit)@",
  bec_temp_limit = "@i18n(widgets.escstatus.bec_temp_limit)@",
  rudder_cutoff = "@i18n(widgets.escstatus.rudder_cutoff)@",
  operation = "@i18n(widgets.escstatus.operation)@",
  operation_warning = "@i18n(widgets.escstatus.operation_warning)@",
  self_test = "@i18n(widgets.escstatus.self_test)@",
  eeprom = "@i18n(widgets.escstatus.eeprom)@",
  watchdog = "@i18n(widgets.escstatus.watchdog)@",
  programming_open = "@i18n(widgets.escstatus.programming_open)@",
  rpm_low = "@i18n(widgets.escstatus.rpm_low)@",
  setpoint_noise = "@i18n(widgets.escstatus.setpoint_noise)@"
}

-- Severity, where the protocol's own wording decides it: a condition the firmware's comment
-- calls an *error*, a *protection* or a *loss* is ERROR, one it calls a *warning* or a *limit
-- reached* is WARNING, and a condition named without either word is ERROR where it names a
-- voltage, current or temperature fault and WARNING where it only reports a state. Where a
-- protocol calls its whole field "warning flags", every bit in it is a WARNING however it reads.
local ERR = M.LEVEL_ERROR
local WRN = M.LEVEL_WARNING
local INF = M.LEVEL_OK

-- Kontronik Telemetry V4, "Error flags", 24 bits. Bits 11 and 23 are the same condition in the
-- protocol's own list and share one text here.
local KONTRONIK = {
  [0] = { TEXT.undervoltage, ERR },
  [1] = { TEXT.overvoltage, ERR },
  [2] = { TEXT.overcurrent, ERR },
  [3] = { TEXT.current_warning, WRN },
  [4] = { TEXT.temp_warning, WRN },
  [5] = { TEXT.overheat, ERR },
  [6] = { TEXT.bec_undervoltage, ERR },
  [7] = { TEXT.bec_overvoltage, ERR },
  [8] = { TEXT.bec_overcurrent, ERR },
  [9] = { TEXT.bec_overheat, ERR },
  [10] = { TEXT.rudder_cutoff, WRN },
  [11] = { TEXT.capacity_limit, WRN },
  [12] = { TEXT.operation, ERR },
  [13] = { TEXT.operation_warning, WRN },
  [14] = { TEXT.self_test, ERR },
  [15] = { TEXT.eeprom, ERR },
  [16] = { TEXT.watchdog, ERR },
  -- "Programming is still permitted" reports what the controller will accept, not a fault.
  [17] = { TEXT.programming_open, INF },
  [18] = { TEXT.battery_limit, WRN },
  [19] = { TEXT.current_limit, WRN },
  [20] = { TEXT.esc_temp_limit, WRN },
  [21] = { TEXT.bec_temp_limit, WRN },
  [22] = { TEXT.current_limit, WRN },
  [23] = { TEXT.capacity_limit, WRN }
}

-- Advanced Power Drives, "Status Flags", 6 bits used. Bit 0 is *motor started* -- a running
-- motor, not a fault -- so it is masked out below rather than given a text: left in, every
-- healthy controller in flight would report it instead of reporting nothing wrong.
local APD = {
  [1] = { TEXT.motor_saturated, WRN },
  [2] = { TEXT.overheat, ERR },
  [3] = { TEXT.overvoltage, ERR },
  [4] = { TEXT.undervoltage, ERR },
  [5] = { TEXT.startup, ERR }
}

-- Scorpion, "Error Code bits", 8 bits of which bits 0 and 6 are unassigned.
local SCORPION = {
  [1] = { TEXT.bec_voltage, ERR },
  [2] = { TEXT.overheat, ERR },
  [3] = { TEXT.consumption, ERR },
  [4] = { TEXT.input_voltage, ERR },
  [5] = { TEXT.overcurrent, ERR },
  [7] = { TEXT.throttle, ERR }
}

-- Hobbywing V5, "Fault code bits", 8 bits. Every one of them is a fault the controller has
-- acted on, so every one of them is an error.
local HOBBYWING_V5 = {
  [0] = { TEXT.motor_locked, ERR },
  [1] = { TEXT.overheat, ERR },
  [2] = { TEXT.throttle_at_start, ERR },
  [3] = { TEXT.throttle_lost, ERR },
  [4] = { TEXT.overcurrent, ERR },
  [5] = { TEXT.undervoltage, ERR },
  [6] = { TEXT.input_voltage, ERR },
  [7] = { TEXT.motor_wiring, ERR }
}

-- Graupner, "Warning flags", 7 bits. The protocol calls the whole field warnings and pairs it
-- with a warning tone, so none of them is raised to an error here.
local GRAUPNER = {
  [0] = { TEXT.undervoltage, WRN },
  [1] = { TEXT.temp_warning, WRN },
  [2] = { TEXT.motor_hot, WRN },
  [3] = { TEXT.current_limit, WRN },
  [4] = { TEXT.rpm_low, WRN },
  [5] = { TEXT.capacity_limit, WRN },
  [6] = { TEXT.current_limit, WRN }
}

-- OpenYGE packs two fields into one byte instead of using bits: the low nibble is the motor
-- state and the high nibble is a warning code with a device bit, so it is not a flag word and
-- has a reader of its own below.
local OYGE_STATE_POWER_CUT = 0x01
local OYGE_STATE_STARTING = 0x08
local OYGE_WARN_OK = 0x00
local OYGE_WARN_UNDERVOLTAGE = 0x10
local OYGE_WARN_OVERTEMP = 0x20
local OYGE_WARN_OVERAMP = 0x40
local OYGE_WARN_DEVICE_BEC = 0x80
local OYGE_WARN_SETPOINT_NOISE = 0xC0

local function isBitSet(word, bitIndex)
  if bit32 and type(bit32.band) == "function" and type(bit32.lshift) == "function" then
    return bit32.band(word, bit32.lshift(1, bitIndex)) ~= 0
  end
  return (word % (2 ^ (bitIndex + 1))) >= (2 ^ bitIndex)
end

-- The worst condition the word reports, and nothing else. Reported rather than counted: a tile
-- has room for one line, and a second fault behind the first one changes nothing a pilot does.
-- Ties go to the lower bit, which is the order the protocol lists them in.
local function worstBit(word, bits, highestBit)
  local bestText, bestLevel = nil, nil
  for bitIndex = 0, highestBit do
    local entry = bits[bitIndex]
    if entry ~= nil and isBitSet(word, bitIndex) then
      if bestLevel == nil or entry[2] > bestLevel then
        bestText, bestLevel = entry[1], entry[2]
        -- Nothing further down can beat an error, and under the tie rule above nothing further
        -- down would replace one either. The widest layout here is 24 bits, so stopping at the
        -- first error is most of the walk on the reading that matters.
        if bestLevel >= M.LEVEL_ERROR then break end
      end
    end
  end
  return bestText, bestLevel
end

-- OpenYGE's own comments make three of the four warning codes conditional on the motor state --
-- a warning is a failure only while the motor is cut or has not started -- and they make warning
-- code zero mean overvoltage in the one state where the controller cuts power. Both are kept:
-- the same code otherwise reads as a warning during a flight it did not interrupt.
local function decodeOpenYGE(word)
  local byte = word % 256
  local state = byte % 16
  local warn = byte - state

  if warn == OYGE_WARN_SETPOINT_NOISE then
    return TEXT.setpoint_noise, WRN
  end

  local isBec = (warn >= OYGE_WARN_DEVICE_BEC)
  local code = isBec and (warn - OYGE_WARN_DEVICE_BEC) or warn

  if code == OYGE_WARN_OK then
    if state == OYGE_STATE_POWER_CUT then
      return (isBec and TEXT.bec_overvoltage or TEXT.overvoltage), ERR
    end
    return TEXT.ok, INF
  end
  if code == OYGE_WARN_UNDERVOLTAGE then
    local level = (state < OYGE_STATE_STARTING) and ERR or WRN
    return (isBec and TEXT.bec_undervoltage or TEXT.undervoltage), level
  end
  if code == OYGE_WARN_OVERTEMP then
    local level = (state == OYGE_STATE_POWER_CUT) and ERR or WRN
    return (isBec and TEXT.bec_overheat or TEXT.overheat), level
  end
  if code == OYGE_WARN_OVERAMP then
    local level = (state == OYGE_STATE_POWER_CUT) and ERR or WRN
    return (isBec and TEXT.bec_overcurrent or TEXT.overcurrent), level
  end

  -- A code the protocol does not assign. Reported rather than swallowed, because a controller
  -- saying something unexpected about itself is worth a look.
  return TEXT.fault, WRN
end

-- One row per signature the firmware can publish. `bits` is the flag layout and `highest` the
-- top bit it assigns; `ignore` masks a bit that is a state rather than a fault; `reader` is a
-- protocol whose byte is not a flag word at all; `opaque` is a protocol that fills the status
-- word with a layout the firmware does not document, where all that can honestly be said is
-- whether it is reporting something; and a row with none of those is a protocol that fills no
-- status word, where the word is always zero and means nothing.
local FAMILIES = {
  [0xC8] = { name = "BLHeli32" },
  [0x9B] = { name = "Hobbywing V4" },
  [0x4B] = { name = "Kontronik", bits = KONTRONIK, highest = 23 },
  [0xD0] = { name = "OMP Hobby", opaque = true },
  [0xDD] = { name = "ZTW", opaque = true },
  [0xA0] = { name = "APD", bits = APD, highest = 5, ignore = { [0] = true } },
  [0xFD] = { name = "Hobbywing V5", bits = HOBBYWING_V5, highest = 7 },
  [0x53] = { name = "Scorpion", bits = SCORPION, highest = 7 },
  [0xA5] = { name = "OpenYGE", reader = decodeOpenYGE },
  [0xA6] = { name = "XDFly", opaque = true },
  [0x73] = { name = "FlyRotor", opaque = true },
  [0xC0] = { name = "Graupner", bits = GRAUPNER, highest = 6 },
  [0xC1] = { name = "BLHeli_S" },
  [0xC2] = { name = "AM32" },
  [0xCC] = { name = "Castle" }
}

-- The status word arrives as a signed integer, because the value the flight controller puts on
-- the wire for it is one; a 32-bit word with its top bit set therefore comes back negative.
local function toWord(value)
  local number = tonumber(value)
  if number == nil then return nil end
  number = math.floor(number)
  if number < 0 then number = number + 4294967296 end
  return number
end

local function toSignature(value)
  local number = tonumber(value)
  if number == nil then return nil end
  number = math.floor(number)
  if number < 0 or number > 255 then return nil end
  return number
end

--- Read the two bytes into one verdict.
--
-- @param signature the ESC1 Model byte, the protocol that answered
-- @param word      the ESC1 Status word
-- @return nil where no speed controller answered, otherwise a table:
--         `text`      what to show, carried as a build marker until the install is packaged
--         `level`     one of the `M.LEVEL_*` values
--         `word`      the status word as read, normalised, or nil where there is none
--         `family`    the protocol's name, or nil where the signature is not one we know
--         `transient` true where the verdict is withdrawn by the next telemetry frame and a
--                     caller must therefore not remember it
function M.decode(signature, word)
  local sig = toSignature(signature)
  if sig == nil or sig == SIG_NONE then return nil end

  -- Not a manufacturer: the firmware writes this signature when the controller has to be
  -- restarted before parameters just written to it take effect, and the next telemetry frame
  -- writes the real signature back over it. It is a request to the pilot, and a passing one.
  if sig == SIG_RESTART then
    return { text = TEXT.restart, level = WRN, word = nil, family = nil, transient = true }
  end

  local family = FAMILIES[sig]
  if family == nil then
    return { text = TEXT.unknown, level = INF, word = nil, family = nil, transient = false }
  end

  local raw = toWord(word)
  local hasLayout = (family.bits ~= nil) or (family.reader ~= nil) or (family.opaque == true)
  if raw == nil or not hasLayout then
    return { text = TEXT.no_status, level = INF, word = raw, family = family.name, transient = false }
  end

  if family.reader then
    local text, level = family.reader(raw)
    return { text = text, level = level, word = raw, family = family.name, transient = false }
  end

  if family.opaque then
    local text = (raw == 0) and TEXT.ok or TEXT.fault
    local level = (raw == 0) and INF or WRN
    return { text = text, level = level, word = raw, family = family.name, transient = false }
  end

  local masked = raw
  if family.ignore then
    for bitIndex in pairs(family.ignore) do
      if isBitSet(masked, bitIndex) then
        masked = masked - math.floor(2 ^ bitIndex + 0.5)
      end
    end
  end

  -- Nothing set is the answer on almost every reading, and it needs no walk at all.
  local text, level = nil, nil
  if masked ~= 0 then
    text, level = worstBit(masked, family.bits, family.highest)
  end
  if text == nil then
    text, level = TEXT.ok, INF
  end
  return { text = text, level = level, word = raw, family = family.name, transient = false }
end

--- The protocol name for a signature byte, where it is one we know. Exposed for a caller that
--- wants to name the controller rather than its health.
function M.familyName(signature)
  local sig = toSignature(signature)
  local family = sig and FAMILIES[sig] or nil
  return family and family.name or nil
end

return M
