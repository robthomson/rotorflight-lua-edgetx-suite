-- lib/audio_volume.lua
-- What Settings > Audio > Volume asks for, read out of the radio-wide `audio` settings.
--
-- One place for the rules, because two places read them: the page shows what the suite will do
-- with a settings file, and lib/audio.lua does it -- in the dashboard widget, in the tool, and in
-- the Lua states that only run the adjustment teller. A second copy of the migration below would
-- be a page that says one thing while the announcements do another.
--
-- The page offers ONE mode at a time. The callout level is handed to playFile and playNumber and
-- scales the sound files only; the master volume scales everything the radio plays, after the
-- level. With both on, the level can only make the announcements quieter than the master volume
-- says, which is not a setting anybody asks for.

local M = {}

M.OFF = 0     -- the radio's own volumes, nothing written
M.LEVEL = 1   -- `level` (1..5) on every announcement
M.MASTER = 2  -- the master volume through the global variable `master_gvar`

-- The most global variables a radio has: 15 on the STM32H7, H7RS and H5 boards, 9 on the others
-- (radio/src/gvars.h, MAX_GVARS).
M.MAX_GVARS = 15

--- The mode a settings file asks for.
---
--- `volume_mode` is written by the page from the first save on. A file written before the page
--- offered a mode carries `level` and `master_gvar` only, and is read the way the suite used it
--- then: a global variable set means the master volume, a level set means the callout level.
--- A file that has BOTH lands in the master volume and its level is ignored; it stays in the file
--- and is offered again when the pilot picks Callout level.
function M.mode(audio)
  if type(audio) ~= "table" then return M.OFF end
  local mode = tonumber(audio.volume_mode)
  if mode == M.OFF or mode == M.LEVEL or mode == M.MASTER then return mode end
  if (tonumber(audio.master_gvar) or 0) > 0 then return M.MASTER end
  if (tonumber(audio.level) or 0) > 0 then return M.LEVEL end
  return M.OFF
end

--- Whether the mode acts only while the radio's link to the model is up.
---
--- One setting for both modes, `connected_only`, written by the page once it is set or saved in a mode. A
--- file without it keeps what each layer did before it existed: the callout level followed
--- `level_connected_only`, and the master volume let go of the pot only while connected -- so a
--- master-volume file reads as on, whatever `level_connected_only` says.
function M.connectedOnly(audio, mode)
  if type(audio) ~= "table" then return false end
  if audio.connected_only ~= nil then return audio.connected_only == true end
  if (mode or M.mode(audio)) == M.MASTER then return true end
  return audio.level_connected_only == true
end

--- Whether this radio has global variable `n` (1-based). A settings file can name one it lacks
--- -- copied from a radio with 15 -- and the suite then leaves the master volume alone rather
--- than write to a variable that is not there. getGlobalVariableDetails answers nil past the
--- board's last one (radio/src/lua/api_model.cpp); without it, the 9 every board has.
function M.gvarOnBoard(n)
  n = tonumber(n)
  if n == nil or n < 1 or n > M.MAX_GVARS or n ~= math.floor(n) then return false end
  local api = type(model) == "table" and model.getGlobalVariableDetails
  if type(api) ~= "function" then return n <= 9 end
  local ok, details = pcall(api, n - 1)
  return ok and details ~= nil
end

return M
