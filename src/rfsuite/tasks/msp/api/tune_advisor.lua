-- EdgeTX MSP API: TUNE_ADVISOR (MSP2_GET_TUNE_ADVISOR 0x5F10, MSP2_CLEAR_TUNE_ADVISOR 0x5F11)
--
-- The flight controller's in-flight rate-loop statistics, one axis per request. The request
-- payload is U8 axis (0 roll, 1 pitch, 2 yaw); the clear command takes no payload. The reply is
-- 51 bytes: one CRSF frame, 12 S.Port frames. Layout, payload version 3, as serialised by the
-- firmware's MSP2_GET_TUNE_ADVISOR case in src/main/msp/msp.c:
--
--   U8 version, U8 flags (bits 0-1 axis, bit 2 collecting, bits 3-5 rates_type),
--   U16 seconds of usable flight, then
--   U32 P | F << 10 | B << 20, U8 iterm_relax_cutoff, U8 rc_rate, U8 s_rate
--   U16 ffCount, U8 ffGain x64, S8 ffCorr x100, U8 ffLagMs
--   3 x {U8 gain x64, U16 count}  by setpoint 40-100, 100-200, 200+ deg/s
--   3 x {U8 gain x64, U16 count}  by |collective| <25%, 25-50%, 50%+
--   U16 fullCount, U16 fullSatCount, U8 fullRatio x100, U8 fullMaxRate in 10 deg/s
--   U16 releases, U8 bigRebounds, U8 meanRebound x100, U8 meanOvershoot x64,
--   U8 meanCounter x100, S16 meanIterm x1000
--   U16 shakeCount, U8 shakeRms x4 (deg/s)
--
-- Scaled values are decoded to plain numbers here; the firmware saturates each at its byte's
-- range (bigRebounds too), and counts stop at 65535.
--
-- A flight controller without the command answers with an MSP error. Over telemetry that
-- reply carries a single byte, so a reply shorter than the record is the refusal, and parse
-- returns nil for it. The read is queued with completeOnErrorReplyAttempt = 1 so that the
-- error reply reaches processReply at all; without it the queue retries and reports the
-- refusal exactly like a lost link.
--
-- A reply whose payload version is not 3 is not read either, and parse returns nil for it too:
-- a firmware that reorders or re-widths the record would otherwise decode into plausible
-- wrong numbers, and the advice would be built from them. Versions 1 and 2 (67 and 71 bytes,
-- every ratio 16-bit) were never in a firmware release.

local Api = {
  command = 0x5F10,      -- MSP2_GET_TUNE_ADVISOR
  writeCommand = 0x5F11, -- MSP2_CLEAR_TUNE_ADVISOR
}

local PAYLOAD_VERSION = 3
local REPLY_BYTES = 51
local BAND_COUNT = 3
local RATES_TYPE_ACTUAL = 4

-- The one-byte values: value x scale
local GAIN_SCALE = 64        -- ffGain, band gains, meanOvershoot: U8, 0..3.98
local CORR_SCALE = 100       -- ffCorr: S8, -1.27..1.27
local FRACTION_SCALE = 100   -- fullRatio, meanRebound, meanCounter: U8, 0..2.55
local RATE_STEP = 10         -- fullMaxRate: U8 in steps of 10 deg/s
local SHAKE_SCALE = 4        -- shakeRms: U8, 0..63.75 deg/s

-- The longest reply parse reads (the only one, while version 3 is the only layout)
Api.MAX_REPLY_BYTES = REPLY_BYTES

local function u8(buf, i)
  return tonumber(buf[i]) or 0
end

local function s8(buf, i)
  local v = u8(buf, i)
  if v >= 0x80 then v = v - 0x100 end
  return v
end

local function u16(buf, i)
  return u8(buf, i) | (u8(buf, i + 1) << 8)
end

local function s16(buf, i)
  local v = u16(buf, i)
  if v >= 0x8000 then v = v - 0x10000 end
  return v
end

local function u32(buf, i)
  return u16(buf, i) | (u16(buf, i + 2) << 16)
end

--- The decoded record, or nil when the reply is not one (the refusal of an older firmware, or
--- a payload version this file does not know). axis is 1-based (1 roll, 2 pitch, 3 yaw).
function Api.parse(buf)
  if type(buf) ~= "table" or #buf < REPLY_BYTES then return nil end
  if u8(buf, 1) ~= PAYLOAD_VERSION then return nil end

  local bands = function(first)
    local out = {}
    for i = 1, BAND_COUNT do
      local at = first + (i - 1) * 3
      out[i] = { gain = u8(buf, at) / GAIN_SCALE, count = u16(buf, at + 1) }
    end
    return out
  end

  local flags = u8(buf, 2)
  local gains = u32(buf, 5)
  return {
    version = PAYLOAD_VERSION,
    collecting = (flags & 0x04) ~= 0,
    seconds = u16(buf, 3),
    axis = (flags & 0x03) + 1,
    a = {
      P = gains & 0x3FF,
      F = (gains >> 10) & 0x3FF,
      B = (gains >> 20) & 0x3FF,
      relaxCutoff = u8(buf, 9),
      ratesType = (flags >> 3) & 0x07,
      rcRate = u8(buf, 10),
      sRate = u8(buf, 11),
      ffCount = u16(buf, 12),
      ffGain = u8(buf, 14) / GAIN_SCALE,
      ffCorr = s8(buf, 15) / CORR_SCALE,
      ffLagMs = u8(buf, 16),
      spBands = bands(17),
      collBands = bands(26),
      fullCount = u16(buf, 35),
      fullSatCount = u16(buf, 37),
      fullRatio = u8(buf, 39) / FRACTION_SCALE,
      fullMaxRate = u8(buf, 40) * RATE_STEP,
      releases = u16(buf, 41),
      bigRebounds = u8(buf, 43),
      meanRebound = u8(buf, 44) / FRACTION_SCALE,
      meanOvershoot = u8(buf, 45) / GAIN_SCALE,
      meanCounter = u8(buf, 46) / FRACTION_SCALE,
      meanIterm = s16(buf, 47) / 1000,
      shakeCount = u16(buf, 49),
      shakeRms = u8(buf, 51) / SHAKE_SCALE,
    }
  }
end

-- Simulator fixture, one reply per axis (Actual rates, centre 360, max 720): cyclic turning
-- faster than asked with the usual stop bounce, pitch too irregular to judge, tail with
-- little data. None of them shaking.
local SIM_AXES = {
  { p = 50, f = 100, cutoff = 10, rcRate = 36, sRate = 72, ffCount = 1491, ff = 1.53, corr = 0.97, lag = 90,
    sp = { { 1.52, 1341 }, { 1.54, 163 }, { 1.03, 50 } }, coll = { { 1.24, 385 }, { 1.54, 763 }, { 1.73, 356 } },
    full = { 87, 25, 0.38, 395 }, rel = { 35, 18, 0.15, 1.47, 0.020, 0.003 }, shake = { 2410, 3.1 } },
  { p = 50, f = 100, cutoff = 10, rcRate = 36, sRate = 72, ffCount = 1172, ff = 0.79, corr = 0.78, lag = 70,
    sp = { { 1.06, 999 }, { 0.45, 194 }, { 0, 54 } }, coll = { { 0.28, 446 }, { 1.27, 629 }, { 1.59, 118 } },
    full = { 105, 72, 0, 23 }, rel = { 10, 2, 0.09, 1.33, 0.019, 0.011 }, shake = { 1980, 2.4 } },
  { p = 80, f = 0, cutoff = 10, rcRate = 36, sRate = 72, ffCount = 404, ff = 0.27, corr = 0.84, lag = 250,
    sp = { { 0.26, 300 }, { 0.30, 109 }, { 0, 0 } }, coll = { { 0.29, 409 }, { 0, 0 }, { 0, 0 } },
    full = { 29, 29, 0.09, 42 }, rel = { 0, 0, 0, 0, 0, 0 }, shake = { 3120, 1.2 } },
}

local simulatorResponses = {}

--- The simulator's reply for one axis (1-3), built once and kept.
function Api.simulatorResponseFor(axis)
  local cached = simulatorResponses[axis]
  if cached then return cached end
  local a = SIM_AXES[axis]
  if not a then return nil end

  local buf = {}
  local function w8(v) buf[#buf + 1] = v & 0xFF end
  local function w16(v) w8(v); w8(v >> 8) end
  local function w32(v) w16(v & 0xFFFF); w16(v >> 16) end
  local function scaled(v, scale, lo, hi)
    local n = math.floor(v * scale + 0.5)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
  end
  local function wU8(v, scale) w8(scaled(v, scale, 0, 255)) end

  w8(PAYLOAD_VERSION); w8((axis - 1) | (RATES_TYPE_ACTUAL << 3)); w16(147)
  w32(a.p | (a.f << 10) | (((a.b or 0) & 0x3FF) << 20)); w8(a.cutoff); w8(a.rcRate); w8(a.sRate)
  w16(a.ffCount); wU8(a.ff, GAIN_SCALE); w8(scaled(a.corr, CORR_SCALE, -128, 127)); w8(a.lag)
  for i = 1, BAND_COUNT do wU8(a.sp[i][1], GAIN_SCALE); w16(a.sp[i][2]) end
  for i = 1, BAND_COUNT do wU8(a.coll[i][1], GAIN_SCALE); w16(a.coll[i][2]) end
  w16(a.full[1]); w16(a.full[2]); wU8(a.full[3], FRACTION_SCALE); wU8(a.full[4], 1 / RATE_STEP)
  w16(a.rel[1]); w8(math.min(a.rel[2], 255))
  wU8(a.rel[3], FRACTION_SCALE); wU8(a.rel[4], GAIN_SCALE); wU8(a.rel[5], FRACTION_SCALE)
  w16(scaled(a.rel[6], 1000, -32768, 32767) & 0xFFFF)
  w16(a.shake[1]); wU8(a.shake[2], SHAKE_SCALE)

  simulatorResponses[axis] = buf
  return buf
end

-- The reply to a request for roll, as a plain byte table like every other api module's.
Api.simulatorResponse = Api.simulatorResponseFor(1)

return Api
