-- EdgeTX MSP API: CRSF_SENSORS_STATUS (MSP2_GET_CRSF_SENSORS_STATUS, 0x5F0B, read-only)
--
-- The flight controller's view of a CRSF sensor accessory wired to a serial port with the CRSF
-- Sensors function: the port's receive counters, and the latest value decoded from each CRSF frame
-- type the firmware understands. The layout is the reply as the firmware's msp.c writes it, all
-- little-endian:
--
--   U8 payload version, U8 enabled (a port has the function and was opened at boot)
--   U32 rx bytes, U32 rx sync bytes, U32 CRC-ok frames, U32 CRC-fail frames
--   U8 last frame type, U8 last frame length                                     -> 20 bytes
--   GPS      U8 has, S32 lat (1e-7 deg), S32 lon, U16 speed (cm/s), U16 heading (0.1 deg),
--            S32 altitude (cm), U8 satellites                                    -> 18 bytes
--   battery  U8 has, U32 voltage (mV), U32 current (mA), U32 used (mAh), U8 remaining (%)
--                                                                                -> 14 bytes
--   baro     U8 has, S32 altitude (cm), S16 vertical speed (cm/s)                -> 7 bytes
--   cells    U8 has, U8 count, count x U16 (mV), U32 total (mV)                  -> 6 + 2n bytes
--   RPM      U8 has, U8 count, count x S32                                       -> 2 + 4n bytes
--
-- Every group is on the wire whether or not it has data -- zeros when it has none -- except the
-- two lists, whose length is their count, and the count is written as 0 when the group has none.
-- So the reply is 67 bytes plus two per cell plus four per RPM value. A group the firmware has not
-- heard from within its sensor timeout is reported as absent.

local Api = {
  command = 0x5F0B
}

-- The reply with no cell and no RPM value: 20 + 18 + 14 + 7 + 6 + 2.
local FIXED_LENGTH = 67

-- The layout above is payload version 1, the reply's first byte.
local PAYLOAD_VERSION = 1

-- Version 1, port enabled, every group present: six cells and one RPM value, 83 bytes.
local SIM_RESPONSE = {
  1, 1,
  85, 188, 0, 0, 81, 7, 0, 0, 59, 7, 0, 0, 3, 0, 0, 0,  -- 48213 bytes, 1873 syncs, 1851 ok, 3 failed
  8, 12,                                                -- last frame: battery (0x08), 12 bytes
  1, 40, 36, 61, 28, 40, 92, 23, 5, 94, 1, 8, 7, 240, 160, 0, 0, 9,
  1, 16, 89, 0, 0, 220, 5, 0, 0, 120, 0, 0, 0, 96,
  1, 150, 0, 0, 0, 244, 255,
  1, 6, 216, 14, 217, 14, 215, 14, 216, 14, 218, 14, 214, 14, 16, 89, 0, 0,
  1, 1, 102, 8, 0, 0
}

Api.simulatorResponse = SIM_RESPONSE
Api.fixedLength = FIXED_LENGTH
Api.payloadVersion = PAYLOAD_VERSION

local function readUnsigned(buf, pos, width)
  local value = 0
  local scale = 1
  for i = 0, width - 1 do
    value = value + (tonumber(buf[pos + i]) or 0) * scale
    scale = scale * 256
  end
  return value
end

local function readS16(buf, pos)
  local value = readUnsigned(buf, pos, 2)
  if value >= 32768 then value = value - 65536 end
  return value
end

local function readS32(buf, pos)
  local value = readUnsigned(buf, pos, 4)
  if value >= 2147483648 then value = value - 4294967296 end
  return value
end

-- Returns nil for a reply shorter than its own counts say it is, and for one whose walk does not
-- end where the layout above says it must -- a wrong field width in this file shows up there
-- rather than as a plausible wrong value. Bytes past the end are kept as a count and otherwise
-- ignored, so a field appended by a later firmware does not blank the page. A payload version
-- other than 1 also returns nil: a firmware that reorders or re-widths the record would
-- otherwise decode into plausible wrong numbers.
function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  local length = #buf
  if length < FIXED_LENGTH then return nil end

  local out = {}
  local pos = 1

  out.version = readUnsigned(buf, pos, 1); pos = pos + 1
  if out.version ~= PAYLOAD_VERSION then return nil end
  out.enabled = readUnsigned(buf, pos, 1) ~= 0; pos = pos + 1
  out.rx_bytes = readUnsigned(buf, pos, 4); pos = pos + 4
  out.rx_sync = readUnsigned(buf, pos, 4); pos = pos + 4
  out.crc_ok = readUnsigned(buf, pos, 4); pos = pos + 4
  out.crc_fail = readUnsigned(buf, pos, 4); pos = pos + 4
  out.last_frame_type = readUnsigned(buf, pos, 1); pos = pos + 1
  out.last_frame_length = readUnsigned(buf, pos, 1); pos = pos + 1

  local hasGps = readUnsigned(buf, pos, 1) ~= 0; pos = pos + 1
  local gps = {}
  gps.latitude = readS32(buf, pos); pos = pos + 4
  gps.longitude = readS32(buf, pos); pos = pos + 4
  gps.groundspeed_cms = readUnsigned(buf, pos, 2); pos = pos + 2
  gps.heading_deg10 = readUnsigned(buf, pos, 2); pos = pos + 2
  gps.altitude_cm = readS32(buf, pos); pos = pos + 4
  gps.satellites = readUnsigned(buf, pos, 1); pos = pos + 1
  if hasGps then out.gps = gps end

  local hasBattery = readUnsigned(buf, pos, 1) ~= 0; pos = pos + 1
  local battery = {}
  battery.voltage_mv = readUnsigned(buf, pos, 4); pos = pos + 4
  battery.current_ma = readUnsigned(buf, pos, 4); pos = pos + 4
  battery.capacity_mah = readUnsigned(buf, pos, 4); pos = pos + 4
  battery.remaining_pct = readUnsigned(buf, pos, 1); pos = pos + 1
  if hasBattery then out.battery = battery end

  local hasBaro = readUnsigned(buf, pos, 1) ~= 0; pos = pos + 1
  local baro = {}
  baro.altitude_cm = readS32(buf, pos); pos = pos + 4
  baro.vertical_speed_cms = readS16(buf, pos); pos = pos + 2
  if hasBaro then out.baro = baro end

  local hasCells = readUnsigned(buf, pos, 1) ~= 0; pos = pos + 1
  local cellCount = readUnsigned(buf, pos, 1); pos = pos + 1
  if length < FIXED_LENGTH + cellCount * 2 then return nil end
  local cells = { count = cellCount, voltages_mv = {} }
  for i = 1, cellCount do
    cells.voltages_mv[i] = readUnsigned(buf, pos, 2); pos = pos + 2
  end
  cells.total_mv = readUnsigned(buf, pos, 4); pos = pos + 4
  if hasCells then out.cells = cells end

  local hasRpm = readUnsigned(buf, pos, 1) ~= 0; pos = pos + 1
  local rpmCount = readUnsigned(buf, pos, 1); pos = pos + 1
  local expected = FIXED_LENGTH + cellCount * 2 + rpmCount * 4
  if length < expected then return nil end
  local rpm = { count = rpmCount, values = {} }
  for i = 1, rpmCount do
    rpm.values[i] = readS32(buf, pos); pos = pos + 4
  end
  if hasRpm then out.rpm = rpm end

  if pos - 1 ~= expected then return nil end
  out.trailing_bytes = length - expected
  return out
end

return Api
