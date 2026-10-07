-- EdgeTX MSP API: gps_rescue (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 135,
  writeCommand = 225,
  simulatorResponse = {
    0,0,    -- angle
    100,0,  -- initial_altitude_m
    100,0,  -- descent_distance_m
    200,0,  -- rescue_groundspeed
    0,0,    -- throttle_min
    0,0,    -- throttle_max
    0,0,    -- throttle_hover
    0,      -- sanity_checks
    6,      -- min_sats
    0,0,    -- ascend_rate
    0,0,    -- descend_rate
    0,      -- allow_arming_without_fix
    0,      -- altitude_mode
    0,0     -- min_rescue_dth
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
  if #buf < 16 then return nil end
  local i = 1
  local out = {}
  out.angle = to_u16(buf[i], buf[i+1]); i = i + 2
  out.initial_altitude_m = to_u16(buf[i], buf[i+1]); i = i + 2
  out.descent_distance_m = to_u16(buf[i], buf[i+1]); i = i + 2
  out.rescue_groundspeed = to_u16(buf[i], buf[i+1]); i = i + 2
  out.throttle_min = to_u16(buf[i], buf[i+1]); i = i + 2
  out.throttle_max = to_u16(buf[i], buf[i+1]); i = i + 2
  out.throttle_hover = to_u16(buf[i], buf[i+1]); i = i + 2
  out.sanity_checks = tonumber(buf[i]); i = i + 1
  out.min_sats = tonumber(buf[i]); i = i + 1
  if buf[i] and buf[i+1] then out.ascend_rate = to_u16(buf[i], buf[i+1]); i = i + 2 end
  if buf[i] and buf[i+1] then out.descend_rate = to_u16(buf[i], buf[i+1]); i = i + 2 end
  if buf[i] then out.allow_arming_without_fix = tonumber(buf[i]); i = i + 1 end
  if buf[i] then out.altitude_mode = tonumber(buf[i]); i = i + 1 end
  if buf[i] and buf[i+1] then out.min_rescue_dth = to_u16(buf[i], buf[i+1]); i = i + 2 end
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  local function push(v) p[#p+1] = v end
  local lo, hi = from_u16(data.angle or 0); push(lo); push(hi)
  lo, hi = from_u16(data.initial_altitude_m or 100); push(lo); push(hi)
  lo, hi = from_u16(data.descent_distance_m or 100); push(lo); push(hi)
  lo, hi = from_u16(data.rescue_groundspeed or 200); push(lo); push(hi)
  lo, hi = from_u16(data.throttle_min or 0); push(lo); push(hi)
  lo, hi = from_u16(data.throttle_max or 0); push(lo); push(hi)
  lo, hi = from_u16(data.throttle_hover or 0); push(lo); push(hi)
  push(data.sanity_checks or 0)
  push(data.min_sats or 6)
  lo, hi = from_u16(data.ascend_rate or 0); push(lo); push(hi)
  lo, hi = from_u16(data.descend_rate or 0); push(lo); push(hi)
  push(data.allow_arming_without_fix or 0)
  push(data.altitude_mode or 0)
  lo, hi = from_u16(data.min_rescue_dth or 0); push(lo); push(hi)
  return p
end

return Api
