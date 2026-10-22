-- Flight Tuning -> Tune Advisor.
--
-- Reads the flight controller's in-flight rate-loop statistics (tasks/msp/api/tune_advisor.lua,
-- firmware src/main/flight/tune_advisor.c) and turns them into concrete changes, one axis at a
-- time: what was measured, which setting to change (named by the page it lives on, in the units
-- that page shows), and why. The firmware only measures; the rules below are the advice, kept
-- here so they can change without a flash. The rules and their wording are the Ethos suite's
-- Tune Advisor page (rotorflight-lua-ethos-suite, app/pages/tune_advisor.lua).
--
-- Rules, per axis:
-- - Feed-forward match (gyro / setpoint at the best delay), judged only when the ratio is
--   consistent. Above FF_HOT the heli outruns the stick: lower F and scale the rate curve up by
--   the same factor, which keeps the stick feel. Below FF_LOW, the reverse. One step is capped
--   at FF_STEP_MAX so the pilot flies and re-checks rather than jumping. The curve can only be
--   scaled exactly for Actual, Quick and Rotorflight rates; for the others the page gives a
--   percentage. An axis with F = 0 (often the tail) gets no F advice: its PID gains set the
--   response.
-- - Full stick (roll and pitch): cyclic saturated and the rate reached well below the rate
--   asked, so the rate is suggested at what the heli reaches.
-- - |Collective| spread is shown as a fact, last, when there is room.
-- - Stick releases: the rebound after a stop. I-term pushing back points at a lower I-term
--   relax cut-off; with F still off, F comes first; otherwise the controller is barely braking,
--   so more P (or B).
--
-- Clear (the header's star button) resets the statistics on the flight controller; they also
-- reset on their own when the tune changes.

local M = {}

local function loadModule(path)
  local fullPath = "/SCRIPTS/TOOLS/rfsuite-core/" .. path
  local chunk = loadScript(fullPath, "t")
  if type(chunk) ~= "function" then return nil end
  local ok, mod = pcall(chunk)
  if not ok then return nil end
  return mod
end

local Common = nil
local Controls = nil
local MspRuntime = nil
local TuneAdvisorApi = nil
local ConfirmDialog = nil
local t = nil

local AXIS_ROLL, AXIS_PITCH, AXIS_YAW = 1, 2, 3

local REFRESH_INTERVAL_SECONDS = 2

-- Feed-forward match
local FF_MIN_COUNT = 1000       -- 10 s of usable 40-200 deg/s stick
local FF_MIN_CORR = 0.85
local FF_HOT = 1.15
local FF_LOW = 0.85
local FF_STEP_MAX = 0.2         -- change F by at most 20% per step
local GAIN_MAX = 1000           -- firmware PID_GAIN_MAX, the limit for P and F alike

-- rates_type values, as the Rates page numbers its tables
local RATE_TYPE_ACTUAL = 4
local RATE_TYPE_QUICK = 5
local RATE_TYPE_ROTORFLIGHT = 6

-- Which rate columns scale the whole curve linearly, per rates_type. The others (Betaflight,
-- Raceflight, KISS) get a percentage instead.
local LINEAR_ROLES = {
  [RATE_TYPE_ACTUAL] = { "rcRate", "srate" },       -- center sensitivity, max rate
  [RATE_TYPE_QUICK] = { "rcRate", "srate" },        -- rc rate, max rate
  [RATE_TYPE_ROTORFLIGHT] = { "rcRate" },           -- rate (srate is the shape)
}

-- How the Rates page shows a raw roll, pitch or yaw byte for these three types: raw * mult /
-- scale, in the decimals its formatValue gives that scale, and the raw range its cell takes
-- (RATE_TABLES in app/pages/flight_tuning/rates/page.lua). A suggestion stays inside that range.
local RATE_DISPLAY = {
  [RATE_TYPE_ACTUAL] = { rcRate = { mult = 10, scale = 1, min = 1, max = 100 }, srate = { mult = 10, scale = 1, min = 0, max = 100 } },
  [RATE_TYPE_QUICK] = { rcRate = { mult = 1, scale = 100, min = 1, max = 255 }, srate = { mult = 10, scale = 1, min = 0, max = 100 } },
  [RATE_TYPE_ROTORFLIGHT] = { rcRate = { mult = 5, scale = 1, min = 2, max = 200 } },
}

-- Max rate asked at full stick (deg/s) from the raw bytes, where the type makes it direct: the
-- firmware's rate curves (fc/rc_rates.c) at full stick. Actual and Quick reach the larger of
-- their two terms.
local function maxRateAsked(a)
  if a.ratesType == RATE_TYPE_ACTUAL then return math.max(a.rcRate, a.sRate) * 10 end
  if a.ratesType == RATE_TYPE_QUICK then return math.max(a.sRate * 10, a.rcRate * 2) end
  if a.ratesType == RATE_TYPE_ROTORFLIGHT then return a.rcRate * 5 end
  return nil
end

-- Collective fact
local BAND_MIN_COUNT = 300
local COLL_SPREAD = 1.25

-- Full stick
local FULL_MIN_COUNT = 100
local FULL_SAT_SHARE = 0.5
local FULL_REACH = 0.8

-- Stick releases
local STOPS_MIN = 10
local REBOUND_BAD = 0.12
local ITERM_PUSH = 0.03         -- I at release, output units
local P_STEP = 1.2
local CUTOFF_STEP = 0.8         -- lower cut-off = more relax, less bounce-back
local CUTOFF_MIN = 1

local MAX_ACTIONS = 3
local MAX_WHYS = 3

-- A change is written as the path a pilot follows to it: page > row > column, or with the
-- menu in front for a page under Advanced. The names are the ones those pages show.
local PATH_FMT = "%s > %s > %s:  %s -> %s"
local ADVANCED_PATH_FMT = "%s > %s > %s > %s:  %s -> %s"

local ui = {
  loaded = false,
  generation = 0,
  selected = AXIS_ROLL,
  pending = false,
  unsupported = false,      -- the flight controller refused the command: no polling until Reload
  lastPoll = 0,
  lastData = nil,
  lastSignature = nil,
  text = nil,
  view = nil,
  runtime = {
    requestRebuild = nil,
    builtThisPass = false,
    deferredLastPass = false
  }
}

local function nowSeconds()
  if getTime then
    local ok, value = pcall(getTime)
    if ok and type(value) == "number" then
      return value / 100
    end
  end
  return 0
end

local function ensureDeps()
  if not Common then Common = loadModule("app/pages/settings/common.lua") end
  if not Controls then Controls = loadModule("ui/controls.lua") end
  if not MspRuntime then MspRuntime = loadModule("tasks/msp/runtime.lua") end
  if not TuneAdvisorApi then TuneAdvisorApi = loadModule("tasks/msp/api/tune_advisor.lua") end
  if not ConfirmDialog then ConfirmDialog = loadModule("ui/confirm_dialog.lua") end
  if not t then t = Common and Common.pageT("flight_tuning_tune_advisor") or nil end
end

local function pageText(i18n, key, fallback)
  if t then
    local translated = t(i18n, key, fallback)
    if translated ~= nil and translated ~= "" and translated ~= key then
      return translated
    end
  end
  return fallback
end

local function requestRebuild()
  if type(ui.runtime.requestRebuild) == "function" then
    ui.runtime.requestRebuild()
  end
end

-- Every string the page shows, resolved once per opening. The names of the settings the advice
-- points at are borrowed from the pages that show them, so the advice reads exactly like the
-- row and column it sends the pilot to, in every language those pages are translated into.
local function loadTexts(i18n)
  local pidsAxis = {
    "@i18n(app.pages.flight_tuning_pids.roll)@",
    "@i18n(app.pages.flight_tuning_pids.pitch)@",
    "@i18n(app.pages.flight_tuning_pids.yaw)@"
  }
  local ratesAxis = {
    "@i18n(app.pages.flight_tuning_rates.roll)@",
    "@i18n(app.pages.flight_tuning_rates.pitch)@",
    "@i18n(app.pages.flight_tuning_rates.yaw)@"
  }
  local controllerAxis = {
    "@i18n(app.pages.flight_tuning_advanced_pid_controller.roll)@",
    "@i18n(app.pages.flight_tuning_advanced_pid_controller.pitch)@",
    "@i18n(app.pages.flight_tuning_advanced_pid_controller.yaw)@"
  }
  local centerSens = "@i18n(app.pages.flight_tuning_rates.center_sensitivity)@"
  local maxRate = "@i18n(app.pages.flight_tuning_rates.max_rate)@"
  local rcRate = "@i18n(app.pages.flight_tuning_rates.rc_rate)@"
  local rate = "@i18n(app.pages.flight_tuning_rates.rate)@"

  return {
    pageTitle = "@i18n(app.modules.tune_advisor.name)@",
    axis = pageText(i18n, "axis", "Axis"),
    axisNames = {
      pageText(i18n, "roll", "Roll"),
      pageText(i18n, "pitch", "Pitch"),
      pageText(i18n, "yaw", "Yaw")
    },
    data = pageText(i18n, "data", "Flight data"),
    dataFmt = pageText(i18n, "data_fmt", "%dm %02ds, %s"),
    collecting = pageText(i18n, "collecting", "collecting"),
    paused = pageText(i18n, "paused", "paused"),
    unsupported = pageText(i18n, "unsupported", "Needs newer firmware"),
    clearPrompt = pageText(i18n, "clear_prompt", "Clear the collected flight data?"),
    response = pageText(i18n, "response", "Response"),
    stops = pageText(i18n, "stops", "Stops"),
    changes = pageText(i18n, "changes", "Suggested changes"),
    why = pageText(i18n, "why", "Why"),

    respMoreFmt = pageText(i18n, "resp_more_fmt", "Needs more flying (%d%%)"),
    respUneven = pageText(i18n, "resp_uneven", "Too uneven to judge"),
    respFastFmt = pageText(i18n, "resp_fast_fmt", "%d%% faster than asked"),
    respSlowFmt = pageText(i18n, "resp_slow_fmt", "%d%% slower than asked"),
    respOk = pageText(i18n, "resp_ok", "Matches the stick"),
    stopsMoreFmt = pageText(i18n, "stops_more_fmt", "Needs more stops (%d/%d)"),
    stopsValueFmt = pageText(i18n, "stops_value_fmt", "%d%% bounce-back"),

    actFlyRoll = pageText(i18n, "act_fly_roll", "Fly rolls in rate mode, centre the stick after each"),
    actFlyPitch = pageText(i18n, "act_fly_pitch", "Fly flips in rate mode, centre the stick after each"),
    actFlyYaw = pageText(i18n, "act_fly_yaw", "Fly pirouettes in rate mode, centre the stick after each"),
    actRatePctUpFmt = pageText(i18n, "act_rate_pct_up_fmt", "%s > %s: all rates about %d%% higher"),
    actRatePctDownFmt = pageText(i18n, "act_rate_pct_down_fmt", "%s > %s: all rates about %d%% lower"),
    actNone = pageText(i18n, "act_none", "No change suggested"),

    whyMore = pageText(i18n, "why_more", "Data builds up while you fly in rate mode."),
    whyUneven = pageText(i18n, "why_uneven", "The response varies too much to judge. Common in 3D."),
    whyFast = pageText(i18n, "why_fast", "The heli turns faster than the stick asks for."),
    whySlow = pageText(i18n, "why_slow", "The heli turns slower than the stick asks for."),
    whyKeepFeel = pageText(i18n, "why_keep_feel", "Changing FF and the rates together keeps the stick feel."),
    whyNoF = pageText(i18n, "why_no_f", "This axis has no FF, so its PID gains set the response."),
    whyFullFmt = pageText(i18n, "why_full_fmt", "Full stick asks %d deg/s but the heli tops out at %d."),
    whyCollHighFmt = pageText(i18n, "why_coll_high_fmt", "It turns %d%% faster at high collective than at low."),
    whyCollLowFmt = pageText(i18n, "why_coll_low_fmt", "It turns %d%% faster at low collective than at high."),
    whyRelax = pageText(i18n, "why_relax", "After a stop, the I-term pushes the heli back."),
    whyFixFFmt = pageText(i18n, "why_fix_f_fmt", "Stops bounce back %d%%. Fix FF first, then check again."),
    whyBrakeFmt = pageText(i18n, "why_brake_fmt", "Stops bounce back %d%%. More P brakes them (or add B)."),
    whyOk = pageText(i18n, "why_ok", "The heli answers the stick as asked."),

    -- Where each change is made
    pidsPage = "@i18n(app.modules.pids.name)@",
    ratesPage = "@i18n(app.modules.rates.name)@",
    advancedMenu = "@i18n(app.modules.advanced.name)@",
    controllerPage = "@i18n(app.modules.pid_controller.name)@",
    pidsAxis = pidsAxis,
    ratesAxis = ratesAxis,
    controllerAxis = controllerAxis,
    pidsP = "@i18n(app.pages.flight_tuning_pids.p)@",
    pidsF = "@i18n(app.pages.flight_tuning_pids.f)@",
    cutoff = "@i18n(app.pages.flight_tuning_advanced_pid_controller.cutoff_point)@",
    rateColumns = {
      [RATE_TYPE_ACTUAL] = { rcRate = centerSens, srate = maxRate },
      [RATE_TYPE_QUICK] = { rcRate = rcRate, srate = maxRate },
      [RATE_TYPE_ROTORFLIGHT] = { rcRate = rate }
    }
  }
end

local function round(v)
  return math.floor(v + 0.5)
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function ffJudged(a)
  return a.ffCount >= FF_MIN_COUNT and a.ffCorr >= FF_MIN_CORR
end

local function ffOff(a)
  return ffJudged(a) and (a.ffGain > FF_HOT or a.ffGain < FF_LOW)
end

-- A raw rate byte as the Rates page shows it for this rates_type
local function rateText(raw, rateType, role)
  local spec = RATE_DISPLAY[rateType] and RATE_DISPLAY[rateType][role]
  if not spec then return tostring(raw) end
  local value = raw * spec.mult / spec.scale
  if spec.scale == 100 then
    return string.format("%.2f", value)
  end
  return string.format("%.0f", value)
end

-- Suggests scaling the rate curve by k (e.g. 1.25 = 25% faster everywhere)
local function rateActions(T, a, axis, k, act)
  local roles = LINEAR_ROLES[a.ratesType]
  if not roles then
    local pct = round(math.abs(k - 1) * 100)
    act(string.format(k > 1 and T.actRatePctUpFmt or T.actRatePctDownFmt, T.ratesPage, T.ratesAxis[axis], pct))
    return
  end
  for _, role in ipairs(roles) do
    local raw = (role == "rcRate") and a.rcRate or a.sRate
    local range = RATE_DISPLAY[a.ratesType][role]
    local newRaw = clamp(round(raw * k), range.min, range.max)
    act(string.format(PATH_FMT, T.ratesPage, T.ratesAxis[axis], T.rateColumns[a.ratesType][role],
      rateText(raw, a.ratesType, role), rateText(newRaw, a.ratesType, role)))
  end
end

-- How many lines rateActions() adds for this rates_type
local function rateActionCount(a)
  local roles = LINEAR_ROLES[a.ratesType]
  return roles and #roles or 1
end

-- Fills actions/whys (cleared by the caller) for one axis; returns the Response and Stops
-- values.
--
-- A change and its reason go in together or not at all, so a reason never shows for a change
-- that was left out: a later change first checks room(). The first change (fly more, F with its
-- rates, or full-stick rates) always fits. The reasons for changes stay within MAX_WHYS; only
-- the closing |collective| fact can be cut.
local function advise(T, a, axis, actions, whys)
  local function room(n) return #actions + n <= MAX_ACTIONS end
  local function act(s) if #actions < MAX_ACTIONS then actions[#actions + 1] = s end end
  local function why(s) if #whys < MAX_WHYS then whys[#whys + 1] = s end end

  -- Response: feed-forward match
  local response
  if a.ffCount < FF_MIN_COUNT then
    response = string.format(T.respMoreFmt, math.floor(100 * a.ffCount / FF_MIN_COUNT))
    act(axis == AXIS_ROLL and T.actFlyRoll or axis == AXIS_PITCH and T.actFlyPitch or T.actFlyYaw)
    why(T.whyMore)
  elseif a.ffCorr < FF_MIN_CORR then
    response = T.respUneven
    why(T.whyUneven)
  elseif ffOff(a) then
    local g = a.ffGain
    local hot = g > FF_HOT
    response = string.format(hot and T.respFastFmt or T.respSlowFmt, round(math.abs(g - 1) * 100))
    if a.F > 0 then
      local newF = clamp(round(a.F * clamp(1 / g, 1 - FF_STEP_MAX, 1 + FF_STEP_MAX)), 1, GAIN_MAX)
      act(string.format(PATH_FMT, T.pidsPage, T.pidsAxis[axis], T.pidsF, a.F, newF))
      -- Keep the stick feel: F x rate is what the pilot feels
      rateActions(T, a, axis, a.F / newF, act)
      why(hot and T.whyFast or T.whySlow)
      why(T.whyKeepFeel)
    else
      why(T.whyNoF)
    end
  else
    response = T.respOk
    local asked = maxRateAsked(a)
    if axis ~= AXIS_YAW and asked and a.fullCount >= FULL_MIN_COUNT
        and a.fullSatCount >= FULL_SAT_SHARE * a.fullCount
        and a.fullMaxRate < FULL_REACH * asked and room(rateActionCount(a)) then
      rateActions(T, a, axis, a.fullMaxRate / asked, act)
      why(string.format(T.whyFullFmt, asked, a.fullMaxRate))
    end
  end

  -- Stops: rebound after a release
  local stops
  if a.releases < STOPS_MIN then
    stops = string.format(T.stopsMoreFmt, a.releases, STOPS_MIN)
  else
    local rebound = round(a.meanRebound * 100)
    stops = string.format(T.stopsValueFmt, rebound)
    if a.meanRebound >= REBOUND_BAD then
      -- No room for the cutoff only after F and two rate lines; F is off then, so the next
      -- branch says to fix F first.
      if a.meanIterm >= ITERM_PUSH and a.relaxCutoff > CUTOFF_MIN and room(1) then
        act(string.format(ADVANCED_PATH_FMT, T.advancedMenu, T.controllerPage, T.cutoff,
          T.controllerAxis[axis], a.relaxCutoff,
          clamp(round(a.relaxCutoff * CUTOFF_STEP), CUTOFF_MIN, a.relaxCutoff - 1)))
        why(T.whyRelax)
      elseif ffOff(a) and a.F > 0 then
        why(string.format(T.whyFixFFmt, rebound))
      elseif room(1) then
        act(string.format(PATH_FMT, T.pidsPage, T.pidsAxis[axis], T.pidsP, a.P,
          clamp(round(a.P * P_STEP), a.P + 1, GAIN_MAX)))
        why(string.format(T.whyBrakeFmt, rebound))
      end
    end
  end

  -- Least important last: a fact, no action
  if ffJudged(a) then
    local lo, hi = a.collBands[1], a.collBands[3]
    if lo.count >= BAND_MIN_COUNT and hi.count >= BAND_MIN_COUNT and lo.gain > 0 and hi.gain > 0 then
      local spread = math.max(lo.gain, hi.gain) / math.min(lo.gain, hi.gain)
      if spread >= COLL_SPREAD then
        why(string.format(hi.gain > lo.gain and T.whyCollHighFmt or T.whyCollLowFmt, round((spread - 1) * 100)))
      end
    end
  end

  if #actions == 0 then
    act(T.actNone)
    if #whys == 0 then why(T.whyOk) end
  end

  return response, stops
end

local function newView()
  return { data = "-", response = "-", stops = "-", actions = {}, whys = {} }
end

local function showUnsupported()
  local view = newView()
  view.data = ui.text and ui.text.unsupported or "-"
  ui.view = view
  requestRebuild()
end

local function render()
  local data = ui.lastData
  local T = ui.text
  if not data or not T or data.axis ~= ui.selected then return end

  local view = newView()
  view.data = string.format(T.dataFmt, math.floor(data.seconds / 60), data.seconds % 60,
    data.collecting and T.collecting or T.paused)
  view.response, view.stops = advise(T, data.a, ui.selected, view.actions, view.whys)
  ui.view = view
  requestRebuild()
end

local function apply(data)
  -- Skip the rebuild when nothing new was collected
  local a = data.a
  local signature = ((data.seconds * 2 + (data.collecting and 1 or 0)) * 4 + data.axis) * 31
    + a.ffCount + a.releases + a.fullCount + a.F + a.P + a.rcRate + a.sRate + a.ratesType + a.relaxCutoff
  if signature == ui.lastSignature then return end
  ui.lastSignature = signature
  ui.lastData = data
  render()
end

local function getQueue()
  if not MspRuntime or type(MspRuntime.getState) ~= "function" then return nil end
  local mspState = MspRuntime.getState()
  local queue = mspState and mspState.queue
  if not queue or type(queue.add) ~= "function" then return nil end
  return queue
end

local poll

poll = function()
  if not ui.loaded or ui.pending or ui.unsupported then return end
  local api = TuneAdvisorApi
  local queue = getQueue()
  if not api or not queue then return end

  local generation = ui.generation
  local axis = ui.selected
  ui.pending = true
  queue:add({
    command = api.command,
    payload = { axis - 1 },
    isWrite = false,
    -- The flight controller's error reply is the only answer that says the firmware lacks the
    -- command, and only this field lets it reach processReply instead of being retried.
    completeOnErrorReplyAttempt = 1,
    simulatorResponse = api.simulatorResponseFor(axis),
    processReply = function(_, buf)
      if generation ~= ui.generation then return end
      ui.pending = false
      local data = api.parse(buf)
      if not data then
        -- A refusal: say so once and stop asking until Reload.
        ui.unsupported = true
        ui.lastSignature = nil
        ui.lastData = nil
        showUnsupported()
        return
      end
      if data.axis ~= ui.selected then
        poll()      -- the axis changed while this request was out
        return
      end
      apply(data)
    end,
    -- No answer at all is the link, not the firmware: keep what is on screen and let the next
    -- poll try again.
    errorHandler = function()
      if generation ~= ui.generation then return end
      ui.pending = false
    end
  })
end

local function onCleared()
  ui.lastSignature = nil
  poll()
end

local function clear()
  local api = TuneAdvisorApi
  local queue = getQueue()
  if not api or not queue then return end
  local generation = ui.generation
  queue:add({
    command = api.writeCommand,
    payload = {},
    isWrite = true,
    completeOnErrorReplyAttempt = 1,
    simulatorResponse = {},
    processReply = function(_, buf)
      if generation ~= ui.generation then return end
      -- The acknowledgement carries no bytes; the error reply of a firmware without the
      -- command carries one.
      if type(buf) == "table" and #buf > 0 then
        ui.unsupported = true
        ui.lastSignature = nil
        ui.lastData = nil
        showUnsupported()
        return
      end
      onCleared()
    end
  })
end

local function ensureLoaded(i18n)
  if ui.loaded then return end
  ui.generation = ui.generation + 1
  ui.loaded = true
  ui.selected = AXIS_ROLL
  ui.pending = false
  ui.unsupported = false
  ui.lastPoll = 0
  ui.lastData = nil
  ui.lastSignature = nil
  ui.text = loadTexts(i18n)
  ui.view = newView()
end

local function onAxis(value)
  ui.selected = tonumber(value) or AXIS_ROLL
  -- Each axis is its own request: fetch the new one now
  ui.lastSignature = nil
  ui.lastPoll = nowSeconds()
  poll()
end

function M.getHeaderActions()
  return { reload = true, save = false, help = true, star = true }
end

-- Polling lives here and never on the pass that built the page: a build this pass defers the
-- poll to the next one, at most once in a row.
function M.wakeup(ctx)
  if not ui.loaded then return end
  ui.runtime.requestRebuild = ctx and ctx.requestRebuild or ui.runtime.requestRebuild

  if ui.runtime.builtThisPass and not ui.runtime.deferredLastPass then
    ui.runtime.builtThisPass = false
    ui.runtime.deferredLastPass = true
    return
  end
  ui.runtime.builtThisPass = false
  ui.runtime.deferredLastPass = false

  local now = nowSeconds()
  if not ui.pending and not ui.unsupported
      and (ui.lastPoll == 0 or now - ui.lastPoll >= REFRESH_INTERVAL_SECONDS) then
    ui.lastPoll = now
    poll()
  end
end

-- One line of text that may wrap, and the height it takes
local function appendText(children, x, y, w, text, color)
  children[#children + 1] = {
    type = "label", x = x, y = y, w = w, text = text, color = color or COLOR_THEME_PRIMARY1, font = SMLSIZE
  }
  local lineH = Controls.LABEL_H or 21
  if type(Controls.estimateWrappedTextHeight) == "function" then
    local total = Controls.estimateWrappedTextHeight(text, w, SMLSIZE)
    local one = Controls.estimateWrappedTextHeight("Ag", w, SMLSIZE)
    if type(total) == "number" and type(one) == "number" and one > 0 then
      return math.max(1, math.floor(total / one + 0.5)) * (one + 4)
    end
  end
  return lineH + 4
end

local function appendValueRow(children, x, y, w, label, value)
  local rowH = Controls.ROW_H or 40
  local labelY = Controls.labelY(y, rowH)
  local labelW = math.floor(w * 0.42)
  children[#children + 1] = {
    type = "label", x = x + 10, y = labelY, w = labelW - 10,
    text = label, color = COLOR_THEME_PRIMARY1, font = SMLSIZE
  }
  children[#children + 1] = {
    type = "label", x = x + labelW, y = labelY, w = w - labelW - 10,
    text = value, color = COLOR_THEME_PRIMARY1, align = RIGHT, font = SMLSIZE
  }
  children[#children + 1] = {
    type = "rectangle", x = x, y = y + rowH, w = w, h = 1, color = COLOR_THEME_SECONDARY2, filled = true
  }
  return rowH + 1
end

local function appendSection(children, x, y, w, title, items)
  if #items == 0 then return 0 end
  local cursorY = y
  Controls.appendStaticSectionHeader(children, x, cursorY, w, title)
  cursorY = cursorY + (Controls.STATIC_SECTION_H or 38) + 4
  for i = 1, #items do
    cursorY = cursorY + appendText(children, x + 10, cursorY, w - 20, items[i])
  end
  return cursorY - y + 6
end

function M.build(ctx)
  ensureDeps()
  if not Common or not Controls then return end
  local i18n = ctx and ctx.i18n
  ensureLoaded(i18n)
  ui.runtime.requestRebuild = ctx and ctx.requestRebuild or nil
  ui.runtime.builtThisPass = true

  local T = ui.text
  local view = ui.view or newView()
  local children = ctx.children
  local x, y, w = ctx.x, ctx.y, ctx.w
  local cursorY = y

  local axisOptions = {
    { label = T.axisNames[AXIS_ROLL], value = AXIS_ROLL },
    { label = T.axisNames[AXIS_PITCH], value = AXIS_PITCH },
    { label = T.axisNames[AXIS_YAW], value = AXIS_YAW }
  }
  cursorY = cursorY + Controls.appendComboSelect(children, x, cursorY, w, T.axis, axisOptions,
    ui.selected, onAxis)

  cursorY = cursorY + appendValueRow(children, x, cursorY, w, T.data, view.data)
  cursorY = cursorY + appendValueRow(children, x, cursorY, w, T.response, view.response)
  cursorY = cursorY + appendValueRow(children, x, cursorY, w, T.stops, view.stops)
  cursorY = cursorY + 6

  cursorY = cursorY + appendSection(children, x, cursorY, w, T.changes, view.actions)
  appendSection(children, x, cursorY, w, T.why, view.whys)
end

function M.onReload()
  -- Ask again, e.g. after a firmware update
  ui.unsupported = false
  ui.lastSignature = nil
  ui.lastPoll = nowSeconds()
  poll()
  return false
end

function M.onStar(ctx)
  ensureDeps()
  if not ConfirmDialog or not ui.text then return false end
  ConfirmDialog.show({
    title = ui.text.pageTitle,
    message = ui.text.clearPrompt,
    onConfirm = function()
      clear()
    end
  })
  return true
end

function M.onClose()
  ui.loaded = false
  ui.generation = ui.generation + 1
  ui.pending = false
  ui.unsupported = false
  ui.lastData = nil
  ui.lastSignature = nil
  ui.text = nil
  ui.view = nil
  ui.runtime.requestRebuild = nil
  ui.runtime.builtThisPass = false
  ui.runtime.deferredLastPass = false
  Common = nil
  Controls = nil
  MspRuntime = nil
  TuneAdvisorApi = nil
  ConfirmDialog = nil
  t = nil
end

return M
