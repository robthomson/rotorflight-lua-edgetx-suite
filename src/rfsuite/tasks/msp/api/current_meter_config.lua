-- EdgeTX MSP API: CURRENT_METER_CONFIG
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.
-- Ported to EdgeTX schema (Api table + parse)

local Api = {
  command = 40, -- MSP_CURRENT_METER_CONFIG
  writeCommand = 41, -- MSP_SET_CURRENT_METER_CONFIG
  simulatorResponse = {
    1,    -- meter_count
    6,    -- frame_length
    0,    -- meter_id
    1,    -- meter_type
    0, 0, -- scale
    0, 0  -- offset
  },
}

local function parseU16(lo, hi)
  return (tonumber(hi) or 0) << 8 | (tonumber(lo) or 0)
end

function Api.parse(buf)
  if type(buf) ~= "table" or #buf < 8 then return nil end
  return {
    meter_count = buf[1] or 0,
    frame_length = buf[2] or 0,
    meter_id = buf[3] or 0,
    meter_type = buf[4] or 0,
    scale = parseU16(buf[5], buf[6]),
    offset = parseU16(buf[7], buf[8])
  }
end

function Api.buildWritePayload(data)
  local function toU16(val)
    val = tonumber(val) or 0
    return val & 0xFF, (val >> 8) & 0xFF
  end
  local payload = {}
  payload[#payload+1] = tonumber(data.meter_id) or 0
  local sLo, sHi = toU16(data.scale)
  payload[#payload+1] = sLo
  payload[#payload+1] = sHi
  local oLo, oHi = toU16(data.offset)
  payload[#payload+1] = oLo
  payload[#payload+1] = oHi
  return payload
end

return Api
