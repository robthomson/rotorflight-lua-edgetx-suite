-- EdgeTX MSP API: raw_gps (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 106,
  writeCommand = 201,
  simulatorResponse = {
    0,    -- fix
    0,    -- num_sat
    0,0,0,0, -- lat (U32 little-endian)
    0,0,0,0, -- lon (U32)
    0,0, -- alt (U16)
    0,0, -- ground_speed (U16)
    0,0, -- ground_course (U16)
    0,0  -- hdop (U16, optional)
  }
}

local function u16_from_bytes(lo, hi)
  lo = tonumber(lo) or 0
  hi = tonumber(hi) or 0
  return ((hi & 0xFF) << 8) | (lo & 0xFF)
end

local function u32_from_bytes(b0, b1, b2, b3)
  b0 = tonumber(b0) or 0
  b1 = tonumber(b1) or 0
  b2 = tonumber(b2) or 0
  b3 = tonumber(b3) or 0
  return ((b3 & 0xFF) << 24) | ((b2 & 0xFF) << 16) | ((b1 & 0xFF) << 8) | (b0 & 0xFF)
end

local function bytes_from_u32(v)
  v = math.floor(tonumber(v) or 0) & 0xFFFFFFFF
  return v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF
end

local function bytes_from_u16(v)
  v = math.floor(tonumber(v) or 0) & 0xFFFF
  return v & 0xFF, (v >> 8) & 0xFF
end

function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < 18 then return nil end
  local i = 1
  local out = {}
  out.fix = tonumber(buf[i]); i = i + 1
  out.num_sat = tonumber(buf[i]); i = i + 1
  out.lat = u32_from_bytes(buf[i], buf[i+1], buf[i+2], buf[i+3]); i = i + 4
  out.lon = u32_from_bytes(buf[i], buf[i+1], buf[i+2], buf[i+3]); i = i + 4
  out.alt = u16_from_bytes(buf[i], buf[i+1]); i = i + 2
  out.ground_speed = u16_from_bytes(buf[i], buf[i+1]); i = i + 2
  out.ground_course = u16_from_bytes(buf[i], buf[i+1]); i = i + 2
  if buf[i] and buf[i+1] then out.hdop = u16_from_bytes(buf[i], buf[i+1]); i = i + 2 end
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  local function push(v) p[#p+1] = v end
  push(data.fix or 0)
  push(data.num_sat or 0)
  local b0,b1,b2,b3 = bytes_from_u32(data.lat or 0); push(b0); push(b1); push(b2); push(b3)
  b0,b1,b2,b3 = bytes_from_u32(data.lon or 0); push(b0); push(b1); push(b2); push(b3)
  local lo,hi = bytes_from_u16(data.alt or 0); push(lo); push(hi)
  lo,hi = bytes_from_u16(data.ground_speed or 0); push(lo); push(hi)
  lo,hi = bytes_from_u16(data.ground_course or 0); push(lo); push(hi)
  lo,hi = bytes_from_u16(data.hdop or 0); push(lo); push(hi)
  return p
end

return Api
