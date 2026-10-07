-- The ESC's own current limit, kept for the model so that the dashboard can show the current
-- as a share of it.
--
-- The value is not asked for anywhere it can be read. Three of the ten ESC families report a
-- limit in their parameter block, and a manufacturer page that has just read one hands it here;
-- the remaining seven have no such field and are the reason the same key can also be set by
-- hand, under Setup > Power > Preferences. The store is the per-model one, so the figure follows
-- the flight controller rather than the transmitter model.
--
-- Amps, always. The three families spell the limit in three different units -- AM32 in amps,
-- Scorpion and YGE in hundredths of an amp -- so each caller converts on the way in and only
-- one unit is ever written.
--
-- Nothing is read from the flight controller for this and nothing is added to the connect
-- chain: the value is a by-product of a page the pilot opened anyway.
local M = {}

local function loadModule(path)
  local fullPath = "/SCRIPTS/TOOLS/rfsuite-core/" .. path
  local chunk = loadScript(fullPath, "t")
  if type(chunk) ~= "function" then return nil end
  local ok, mod = pcall(chunk)
  if not ok then return nil end
  return mod
end

local PowerModelPreferences = nil
local Log = nil

local function ensureDeps()
  if not PowerModelPreferences then
    PowerModelPreferences = loadModule("app/pages/setup/power/model_preferences.lua")
  end
  if not Log then Log = loadModule("lib/log.lua") end
end

local function logD(msg)
  if Log and type(Log.emit) == "function" then
    pcall(Log.emit, "rfsuite.esc.currentlimit", tostring(msg), "debug")
  end
end

--- The key one physical fact is stored under, named here so that no reader has to spell it.
M.KEY = "esc_current_limit"

--- Whole amps, or nil where the argument is not a limit at all. A limit of zero is how every
--- one of the three families spells "no limit set", so it is not a figure to remember: it would
--- read back as a limit of nought and turn every reading into an overload.
function M.normalize(amps)
  local limit = tonumber(amps)
  if limit == nil then return nil end
  limit = math.floor(limit + 0.5)
  if limit <= 0 then return nil end
  return limit
end

--- Stores the limit for the flight controller that is connected, and writes the file only where
--- the figure is new. A page reads its block on every visit, so writing unconditionally would be
--- a card write per page open for a value that changes when the ESC is reconfigured and never
--- otherwise.
---
--- The per-model store is not created here. A save writes the whole table, so saving one that
--- the connect chain has not filled yet would put a nearly empty file on the card in place of
--- the model's settings. Where there is nothing to write into, the limit is simply not kept.
function M.remember(session, amps)
  local limit = M.normalize(amps)
  if limit == nil then return false, "no_limit" end
  if type(session) ~= "table" then return false, "no_session" end
  if type(session.modelPreferences) ~= "table" then return false, "no_model_preferences" end

  local battery = session.modelPreferences.battery
  if type(battery) ~= "table" then
    battery = {}
    session.modelPreferences.battery = battery
  end

  if tonumber(battery[M.KEY]) == limit then return true, "unchanged" end

  battery[M.KEY] = limit

  ensureDeps()
  if not PowerModelPreferences or type(PowerModelPreferences.save) ~= "function" then
    return false, "model_preferences_unavailable"
  end

  local ok, err = PowerModelPreferences.save(session)
  logD("remember " .. tostring(limit) .. " A: " .. (ok and "saved" or ("failed: " .. tostring(err or "io"))))
  return ok, err
end

return M
