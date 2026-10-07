-- EdgeTX MSP API: TUNE_ADVISOR (MSP2_GET_TUNE_ADVISOR 0x5F10, MSP2_CLEAR_TUNE_ADVISOR 0x5F11)
--
-- The flight controller's in-flight rate-loop statistics, one axis per request so the reply
-- (67 bytes) fits MSP over telemetry. The request payload is U8 axis (0 roll, 1 pitch, 2 yaw).
-- The clear command takes no payload. Layout, payload version 1, as serialised by the
-- firmware's MSP2_GET_TUNE_ADVISOR case in src/main/msp/msp.c:
--
--   U8 version, U8 collecting, U16 seconds of usable flight, U8 axis, then
--   U16 P, U16 F, U16 B, U8 iterm_relax_cutoff, U8 rates_type, U8 rc_rate, U8 s_rate
--   U16 ffCount, S16 ffGain, S16 ffCorr, U16 ffLagMs
--   3 x {S16 gain, U16 count}  by setpoint 40-100, 100-200, 200+ deg/s
--   3 x {S16 gain, U16 count}  by |collective| <25%, 25-50%, 50%+
--   U16 fullCount, U16 fullSatCount, S16 fullRatio, U16 fullMaxRate
--   U16 releases, U16 bigRebounds, S16 meanRebound, S16 meanOvershoot, S16 meanCounter,
--   S16 meanIterm
--
-- Ratios are x1000 on the wire and are decoded to plain numbers here; counts stop at 65535.
--
-- A flight controller without the command answers with an MSP error. Over telemetry that
-- reply carries a single byte, so a reply shorter than the record is the refusal, and parse
-- returns nil for it. The read is queued with completeOnErrorReplyAttempt = 1 so that the
-- error reply reaches processReply at all; without it the queue retries and reports the
-- refusal exactly like a lost link.
--
-- A reply whose payload version is not 1 is not read either, and parse returns nil for it too:
-- a later firmware that reorders or re-widths the record would otherwise decode into plausible
-- wrong numbers, and the advice would be built from them.

local Api = {
  command = 0x5F10,      -- MSP2_GET_TUNE_ADVISOR
  writeCommand = 0x5F11, -- MSP2_CLEAR_TUNE_ADVISOR
}

local REPLY_BYTES = 67
local BAND_COUNT = 3
local RATES_TYPE_ACTUAL = 4

Api.REPLY_BYTES = REPLY_BYTES

local function u8(buf, i)
  return tonumber(buf[i]) or 0
end

local function u16(buf, i)
  return u8(buf, i) | (u8(buf, i + 1) << 8)
end

local function s16(buf, i)
  local v = u16(buf, i)
  if v >= 0x8000 then v = v - 0x10000 end
  return v
end

local function ratio(buf, i)
  return s16(buf, i) / 1000
end

--- The decoded record, or nil when the reply is not one (the refusal of an older firmware, or
--- a payload version this file does not know). axis is 1-based (1 roll, 2 pitch, 3 yaw).
function Api.parse(buf)
  if type(buf) ~= "table" or #buf < REPLY_BYTES then return nil end

  local bands = function(first)
    local out = {}
    for i = 1, BAND_COUNT do
      local at = first + (i - 1) * 4
      out[i] = { gain = ratio(buf, at), count = u16(buf, at + 2) }
    end
    return out
  end

  local out = {
    version = u8(buf, 1),
    collecting = u8(buf, 2) ~= 0,
    seconds = u16(buf, 3),
    axis = u8(buf, 5) + 1,
    a = {
      P = u16(buf, 6),
      F = u16(buf, 8),
      B = u16(buf, 10),
      relaxCutoff = u8(buf, 12),
      ratesType = u8(buf, 13),
      rcRate = u8(buf, 14),
      sRate = u8(buf, 15),
      ffCount = u16(buf, 16),
      ffGain = ratio(buf, 18),
      ffCorr = ratio(buf, 20),
      ffLagMs = u16(buf, 22),
      spBands = bands(24),
      collBands = bands(36),
      fullCount = u16(buf, 48),
      fullSatCount = u16(buf, 50),
      fullRatio = ratio(buf, 52),
      fullMaxRate = u16(buf, 54),
      releases = u16(buf, 56),
      bigRebounds = u16(buf, 58),
      meanRebound = ratio(buf, 60),
      meanOvershoot = ratio(buf, 62),
      meanCounter = ratio(buf, 64),
      meanIterm = ratio(buf, 66),
    }
  }
  if out.version ~= 1 then return nil end
  return out
end

-- Simulator fixture, one reply per axis (Actual rates, centre 360, max 720): cyclic turning
-- faster than asked with the usual stop bounce, pitch too irregular to judge, tail with
-- little data.
local SIM_AXES = {
  { p = 50, f = 100, cutoff = 10, rcRate = 36, sRate = 72, ffCount = 1491, ff = 1.53, corr = 0.97, lag = 90,
    sp = { { 1.52, 1341 }, { 1.54, 163 }, { 1.03, 50 } }, coll = { { 1.24, 385 }, { 1.54, 763 }, { 1.73, 356 } },
    full = { 87, 25, 0.38, 395 }, rel = { 35, 18, 0.15, 1.47, 0.020, 0.003 } },
  { p = 50, f = 100, cutoff = 10, rcRate = 36, sRate = 72, ffCount = 1172, ff = 0.79, corr = 0.78, lag = 70,
    sp = { { 1.06, 999 }, { 0.45, 194 }, { 0, 54 } }, coll = { { 0.28, 446 }, { 1.27, 629 }, { 1.59, 118 } },
    full = { 105, 72, 0, 23 }, rel = { 10, 2, 0.09, 1.33, 0.019, 0.011 } },
  { p = 80, f = 0, cutoff = 10, rcRate = 36, sRate = 72, ffCount = 404, ff = 0.27, corr = 0.84, lag = 250,
    sp = { { 0.26, 300 }, { 0.30, 109 }, { 0, 0 } }, coll = { { 0.29, 409 }, { 0, 0 }, { 0, 0 } },
    full = { 29, 29, 0.09, 42 }, rel = { 0, 0, 0, 0, 0, 0 } },
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
  local function wRatio(v) w16(math.floor(v * 1000 + 0.5) & 0xFFFF) end

  w8(1); w8(0); w16(147); w8(axis - 1)
  w16(a.p); w16(a.f); w16(0); w8(a.cutoff); w8(RATES_TYPE_ACTUAL); w8(a.rcRate); w8(a.sRate)
  w16(a.ffCount); wRatio(a.ff); wRatio(a.corr); w16(a.lag)
  for i = 1, BAND_COUNT do wRatio(a.sp[i][1]); w16(a.sp[i][2]) end
  for i = 1, BAND_COUNT do wRatio(a.coll[i][1]); w16(a.coll[i][2]) end
  w16(a.full[1]); w16(a.full[2]); wRatio(a.full[3]); w16(a.full[4])
  w16(a.rel[1]); w16(a.rel[2])
  for i = 3, 6 do wRatio(a.rel[i]) end

  simulatorResponses[axis] = buf
  return buf
end

-- The reply to a request for roll, as a plain byte table like every other api module's.
Api.simulatorResponse = Api.simulatorResponseFor(1)

return Api
