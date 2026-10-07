-- EdgeTX MSP API: gps_rescue_pids (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 136,
  writeCommand = 226,
  simulatorResponse = {
    0,0, -- throttle_p
    0,0, -- throttle_i
    0,0, -- throttle_d
    0,0, -- vel_p
    0,0, -- vel_i
    0,0, -- vel_d
    0,0  -- yaw_p
  }
}

local function to_u16(lo, hi)
  lo = tonumber(lo) or 0
  hi = tonumber(hi) or 0
  return ((hi & 0xFF) << 8) | (lo & 0xFF)
end

local function from_u16(v)
  v = math.floor(tonumber(v) or 0) & 0xFFFF
  return v & 0xFF, (v >> 8) & 0xFF
end

function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < 14 then return nil end
  local i = 1
  local out = {}
  out.throttle_p = to_u16(buf[i], buf[i+1]); i = i + 2
  out.throttle_i = to_u16(buf[i], buf[i+1]); i = i + 2
  out.throttle_d = to_u16(buf[i], buf[i+1]); i = i + 2
  out.vel_p = to_u16(buf[i], buf[i+1]); i = i + 2
  out.vel_i = to_u16(buf[i], buf[i+1]); i = i + 2
  out.vel_d = to_u16(buf[i], buf[i+1]); i = i + 2
  out.yaw_p = to_u16(buf[i], buf[i+1]); i = i + 2
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  local function push(v) p[#p+1] = v end
  local lo, hi = from_u16(data.throttle_p or 0); push(lo); push(hi)
  lo, hi = from_u16(data.throttle_i or 0); push(lo); push(hi)
  lo, hi = from_u16(data.throttle_d or 0); push(lo); push(hi)
  lo, hi = from_u16(data.vel_p or 0); push(lo); push(hi)
  lo, hi = from_u16(data.vel_i or 0); push(lo); push(hi)
  lo, hi = from_u16(data.vel_d or 0); push(lo); push(hi)
  lo, hi = from_u16(data.yaw_p or 0); push(lo); push(hi)
  return p
end

return Api
