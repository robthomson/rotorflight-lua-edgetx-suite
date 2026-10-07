-- EdgeTX MSP API: motor (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 104,
  writeCommand = 214,
  simulatorResponse = {
    0, 0, -- motor_1
    0, 0, -- motor_2
    0, 0, -- motor_3
    0, 0, -- motor_4
    0, 0, -- motor_5
    0, 0, -- motor_6
    0, 0, -- motor_7
    0, 0  -- motor_8
  }
}

local function u16_from_bytes(lo, hi)
  lo = tonumber(lo) or 0
  hi = tonumber(hi) or 0
  return ((hi & 0xFF) << 8) | (lo & 0xFF)
end

local function bytes_from_u16(v)
  v = math.floor(tonumber(v) or 0) & 0xFFFF
  return v & 0xFF, (v >> 8) & 0xFF
end

function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < 16 then return nil end
  local i = 1
  local out = {}
  for idx = 1, 8 do
    out["motor_"..idx] = u16_from_bytes(buf[i], buf[i+1]); i = i + 2
  end
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  for idx = 1, 8 do
    local lo, hi = bytes_from_u16(data["motor_"..idx] or 0)
    p[#p+1] = lo; p[#p+1] = hi
  end
  return p
end

return Api
