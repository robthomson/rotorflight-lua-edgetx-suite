-- EdgeTX MSP API: FAILSAFE_CONFIG (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.
-- Self-contained, no core/Ethos dependencies

local Api = {
  command = 75, -- MSP_API_CMD_READ
  writeCommand = 76, -- MSP_API_CMD_WRITE
  simulatorResponse = {
    10,      -- failsafe_delay
    10,      -- failsafe_off_delay
    232, 3,  -- failsafe_throttle (U16)
    0,       -- failsafe_switch_mode
    100, 0,  -- failsafe_throttle_low_delay (U16)
    0        -- failsafe_procedure
  }
}

local function parseU16(lo, hi)
  return (tonumber(hi) or 0) << 8 | (tonumber(lo) or 0)
end

function Api.parse(buf)
  if type(buf) ~= "table" or #buf < 8 then return nil end
  return {
    failsafe_delay = buf[1] or 0,
    failsafe_off_delay = buf[2] or 0,
    failsafe_throttle = parseU16(buf[3], buf[4]),
    failsafe_switch_mode = buf[5] or 0,
    failsafe_throttle_low_delay = parseU16(buf[6], buf[7]),
    failsafe_procedure = buf[8] or 0
  }
end

function Api.buildWritePayload(data)
  local function toU16(val)
    val = math.floor(tonumber(val) or 0)
    return val & 0xFF, (val >> 8) & 0xFF
  end
  local payload = {}
  payload[#payload+1] = tonumber(data.failsafe_delay) or 0
  payload[#payload+1] = tonumber(data.failsafe_off_delay) or 0
  local lo, hi = toU16(data.failsafe_throttle)
  payload[#payload+1] = lo
  payload[#payload+1] = hi
  payload[#payload+1] = tonumber(data.failsafe_switch_mode) or 0
  lo, hi = toU16(data.failsafe_throttle_low_delay)
  payload[#payload+1] = lo
  payload[#payload+1] = hi
  payload[#payload+1] = tonumber(data.failsafe_procedure) or 0
  return payload
end

return Api
