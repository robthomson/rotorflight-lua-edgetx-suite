-- EdgeTX MSP API: osd_config (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 84,
  writeCommand = 85,
  simulatorResponse = {
    0,    -- osd_flags
    0,    -- video_system
    0,    -- units
    0,    -- rssi_alarm
    0, 0, -- cap_alarm
    0,    -- legacy_timer_lo
    0,    -- legacy_timer_hi
    0, 0  -- alt_alarm
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
  local i = 1
  local out = {}
  out.osd_flags = tonumber(buf[i]); i = i + 1
  out.video_system = tonumber(buf[i]); i = i + 1
  out.units = tonumber(buf[i]); i = i + 1
  out.rssi_alarm = tonumber(buf[i]); i = i + 1
  out.cap_alarm = u16_from_bytes(buf[i], buf[i+1]); i = i + 2
  out.legacy_timer_lo = tonumber(buf[i]); i = i + 1
  out.legacy_timer_hi = tonumber(buf[i]); i = i + 1
  out.alt_alarm = u16_from_bytes(buf[i], buf[i+1]); i = i + 2
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  local function push(v) p[#p+1] = v end
  push(data.addr or 0)
  push(data.video_system or 0)
  push(data.units or 0)
  push(data.rssi_alarm or 0)
  local lo, hi = bytes_from_u16(data.cap_alarm or 0); push(lo); push(hi)
  local legacy = tonumber(data.legacy_timer) or 0
  push(legacy & 0xFF); push((legacy >> 8) & 0xFF)
  lo, hi = bytes_from_u16(data.alt_alarm or 0); push(lo); push(hi)
  push(data.enabled_warnings_16 or 0)
  push(data.enabled_warnings_32 or 0)
  push(data.osd_profile_index or 0)
  push(data.overlay_radio_mode or 0)
  push(data.camera_frame_width or 0)
  push(data.camera_frame_height or 0)
  return p
end

return Api
