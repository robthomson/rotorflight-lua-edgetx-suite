-- Opens a flight record on the arm edge.
--
-- Nothing is written here and nothing is read off the card. The record is a handful of values in
-- the session that the disarm task turns into a line, and the arm edge is the wrong moment to be
-- touching the card at all -- the pilot is taking off.
--
-- The record is opened whether or not the flight log is switched on, because the setting is read
-- where the line would be written. Turning the log on between arming and disarming then records
-- the whole flight rather than half of it.
--
-- The start time is taken here rather than at disarm on purpose: a flight is filed under when it
-- began, which is also what lets a row be matched against a radio log of the same flight.

local M = {}

local recorded = false

-- The pack the model's store held when the craft armed, out of the copy already in memory -- no
-- card read. Only the disarm task's last resort: the MSP runtime drops the board's identity, and
-- the store with it, the moment the link goes, and reads it again only once the craft has
-- disarmed, so after a dropout in flight the disarm finds no store to ask. The same conversion
-- as lib/flight_log.lua's storedBatteryId, which this task does not load.
local function storedPick(modelPreferences)
  local section = type(modelPreferences) == "table" and modelPreferences.flightlog or nil
  local value = type(section) == "table" and section.battery or nil
  if type(value) == "number" then value = string.format("%s", value) end
  if type(value) ~= "string" then return nil end
  value = string.match(value, "^%s*(.-)%s*$")
  if value == "" then return nil end
  return value
end

function M.wakeup()
  if recorded then return end
  recorded = true

  local root = _G and _G.rfsuite
  local session = type(root) == "table" and root.session or nil
  if type(session) ~= "table" then return end

  local startTicks = nil
  if type(getTime) == "function" then
    local ok, ticks = pcall(getTime)
    if ok and type(ticks) == "number" then startTicks = ticks end
  end

  local startDate = nil
  if type(getDateTime) == "function" then
    local ok, dt = pcall(getDateTime)
    if ok and type(dt) == "table" then startDate = dt end
  end

  -- The pack chosen for the connection, and the pack a use has already been counted against,
  -- both outlive one flight. They are carried over from the record the previous flight left.
  local previous = type(session.flightlog) == "table" and session.flightlog or nil
  local batteryId = previous and previous.batteryId or nil

  session.flightlog = {
    open = true,
    startTicks = startTicks,
    startDate = startDate,
    model = session.modelName,
    batteryId = batteryId,
    countedFor = previous and previous.countedFor or nil,
    batteryAtArm = batteryId or storedPick(session.modelPreferences)
  }
end

function M.isComplete()
  return recorded
end

function M.reset()
  recorded = false
end

return M
