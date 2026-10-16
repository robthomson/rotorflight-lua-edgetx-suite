local M = {}

local function loadModule(path)
  local fullPath = "/SCRIPTS/TOOLS/rfsuite-core/" .. path
  local chunk = assert(loadScript(fullPath, "t"))
  return chunk()
end

local Controls = nil
local Common = nil
-- The mode rules lib/audio.lua acts on (lib/audio_volume.lua), so the page shows what the suite
-- will do with the file rather than a second reading of it.
local Rules = nil

-- ─── Config schema ────────────────────────────────────────────────────────────

-- `volume_mode` and `connected_only` are resolved through Rules after the plain copy below,
-- because a file written before they existed carries neither. `level_connected_only` is carried
-- through as it was read: it is what such a file meant, and nothing on this page edits it.
local CONFIG_SCHEMA = {
  { key = "volume_mode",          type = "number", default = 0 },
  { key = "connected_only",       type = "bool",   default = false },
  { key = "level",                type = "number", default = 0 },
  { key = "level_connected_only", type = "bool",   default = false },
  { key = "master_gvar",          type = "number", default = 0 },
  { key = "master_normal",        type = "number", default = 80 },
  { key = "master_alert",         type = "number", default = 100 },
}

local MODE_OFF, MODE_LEVEL, MODE_MASTER = 0, 1, 2

-- The level a pilot starts from on picking Callout level with none stored: 3 plays a sound file
-- at a quarter of its amplitude, which is what the radio's own Wav volume 0 does (EdgeTX
-- radio/src/audio.cpp, WavContext::mixBuffer).
local LEVEL_START = 3

-- The global variables only. The picker has no empty entry: Mode's Off is what turns the master
-- volume off, so there is one place for it. Read from the lvgl table, which every firmware with
-- lvgl.source exports; the number is only a fallback, EdgeTX 2.12's SRC_GVAR 1 << 15
-- (radio/src/dataconstants.h).
local SRC_GVAR_FILTER = (lvgl ~= nil and lvgl.SRC_GVAR) or 0x8000

local function buildDefaultConfig()
  local cfg = {}
  for _, field in ipairs(CONFIG_SCHEMA) do cfg[field.key] = field.default end
  return cfg
end

-- ─── State ────────────────────────────────────────────────────────────────────

local ui = {
  loaded    = false,
  dirty     = false,
  config    = buildDefaultConfig(),
}

ui.runtime = nil

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local t = nil

local function ensureDeps()
  if not Common then
    Common = loadModule("app/pages/settings/common.lua")
  end
  if not Controls then
    Controls = loadModule("ui/controls.lua")
  end
  if not Rules then
    Rules = loadModule("lib/audio_volume.lua")
  end
  if not ui.runtime then
    ui.runtime = Common.createFormRuntime(ui)
  end
  if not t then
    t = Common.pageT("settings_audio_volume")
  end
end

local function copyFromPrefs(prefs)
  local audio = (prefs and prefs.audio) or {}

  for _, field in ipairs(CONFIG_SCHEMA) do
    if field.type == "string" then
      local v = tostring(audio[field.key] or "")
      ui.config[field.key] = v ~= "" and v or field.default
    elseif field.type == "bool" then
      if audio[field.key] ~= nil then
        ui.config[field.key] = audio[field.key]
      else
        ui.config[field.key] = field.default
      end
    else
      ui.config[field.key] = tonumber(audio[field.key]) or field.default
    end
  end

  local mode = Rules.mode(audio)
  ui.config.volume_mode = mode
  ui.config.connected_only = Rules.connectedOnly(audio, mode)
  -- Until the pilot sets Connected only, or a save has stored it, it follows the mode the way a
  -- file without it is read: on for Master volume, the level's own switch for Callout level.
  ui.connectedOnlySet = audio.connected_only ~= nil
end

local function ensureLoaded(prefs)
  if ui.loaded then return end
  copyFromPrefs(prefs)
  ui.loaded = true
end

local function getModeOptions(i18n)
  return {
    { value = MODE_OFF, label = t(i18n, "mode_off", "Off (radio default)") },
    { value = MODE_LEVEL, label = t(i18n, "mode_level", "Callout level") },
    { value = MODE_MASTER, label = t(i18n, "mode_master", "Master volume") },
  }
end

local function getLevelOptions()
  return {
    { value = 1, label = "1" },
    { value = 2, label = "2" },
    { value = 3, label = "3" },
    { value = 4, label = "4" },
    { value = 5, label = "5" },
  }
end

local function onModeSelected(value)
  ui.config.volume_mode = value
  if value == MODE_LEVEL and (tonumber(ui.config.level) or 0) <= 0 then
    ui.config.level = LEVEL_START
  end
  if not ui.connectedOnlySet then
    ui.config.connected_only = Rules.connectedOnly(
      { level_connected_only = ui.config.level_connected_only }, value)
  end
  -- The rows below depend on the mode, so this asks for a rebuild.
  ui.runtime.markDirty()
end

local function onConnectedOnlySet(value)
  ui.connectedOnlySet = true
  ui.runtime.getBoolSetter("connected_only")(value)
end

-- The source index of GV1. The global variables are one block of mix sources, so GV n is that
-- index + n - 1; "gvar1" is the firmware's own field name and does not move when a variable is
-- renamed (radio/src/lua/api_general.cpp, luaMultipleFields).
local function gvarSourceBase()
  if type(getFieldInfo) ~= "function" then return nil end
  local ok, info = pcall(getFieldInfo, "gvar1")
  if ok and type(info) == "table" then return tonumber(info.id) end
  return nil
end

-- A row's `?` opens the page's help sheet with the row's label as its title (the pattern of
-- app/pages/settings/audio/events/category_page.lua). Cached on ui.runtime, so onClose drops it.
local function getInlineHelpHandler()
  if ui.runtime.inlineHelpHandler then return ui.runtime.inlineHelpHandler end
  ui.runtime.inlineHelpHandler = function(helpText, helpTitle)
    local openHelp = ui.runtime.openHelp
    if type(openHelp) == "function" and type(helpText) == "string" and helpText ~= "" then
      openHelp(helpText, helpTitle)
    end
  end
  return ui.runtime.inlineHelpHandler
end

-- The options table a row control takes for its `?` button; empty when the row has no text,
-- which leaves the control as it is drawn without one.
local function helpOpts(text, title)
  if type(text) ~= "string" or text == "" then return {} end
  return { helpText = text, helpTitle = title, onHelp = getInlineHelpHandler() }
end

-- The global variable row. The picker is EdgeTX's own source picker, filtered to the global
-- variables this radio has, with their names. Controls has no wrapper for it, so the row draws
-- its label, the picker and its `?` where appendComboSelect places them.
local HELP_BTN_W, HELP_BTN_H, HELP_BTN_GAP, PICKER_W = 30, 30, 6, 172

local function appendGvarPicker(children, x, y, w, labelText, help)
  local rowH = Controls.ROW_H
  local pickerW = PICKER_W
  if pickerW > w then pickerW = w end
  local pickerX = x + w - pickerW - 10 - HELP_BTN_W - HELP_BTN_GAP
  -- Asked once per build rather than on every refresh of the picker: both answers are tables
  -- the firmware allocates, and neither changes while the page is open. A pick rebuilds the page.
  local base = gvarSourceBase()
  local storedGv = tonumber(ui.config.master_gvar) or 0
  local shown = 0
  if storedGv > 0 and base ~= nil and Rules.gvarOnBoard(storedGv) then shown = base + storedGv - 1 end

  children[#children + 1] = {
    type = "label",
    x = x, y = Controls.labelY(y, rowH), w = pickerX - x - 8,
    text = labelText, color = COLOR_THEME_PRIMARY1, font = SMLSIZE
  }
  children[#children + 1] = {
    type = "source",
    x = pickerX, y = Controls.controlY(y, rowH), w = pickerW, h = Controls.CTRL_H,
    -- NO `title`: the source picker does not take one (see app/pages/setup_wizard/proc_radio.lua).
    filter = SRC_GVAR_FILTER,
    -- None picked yet, or a variable this radio lacks, is 0, which EdgeTX draws as its empty
    -- source: past the last variable come the radio's own sources (TX voltage, time, GPS), and
    -- the picker would name one of those.
    get = function() return shown end,
    set = function(value)
      value = tonumber(value) or 0
      local gv = base and (value - base + 1) or 0
      if gv < 1 or gv > Rules.MAX_GVARS then return end
      shown = value
      if gv == (tonumber(ui.config.master_gvar) or 0) then return end
      ui.config.master_gvar = gv
      -- Normal and Alert are drawn only with a variable picked.
      ui.runtime.markDirty()
    end
  }
  if help.helpText then
    children[#children + 1] = {
      type = "button",
      x = pickerX + pickerW + HELP_BTN_GAP, y = y + math.floor((rowH - HELP_BTN_H) / 2),
      w = HELP_BTN_W, h = HELP_BTN_H,
      text = "?",
      press = function() help.onHelp(help.helpText, help.helpTitle) end
    }
  end
  children[#children + 1] = {
    type = "rectangle",
    x = x, y = y + rowH, w = w, h = 1,
    color = COLOR_THEME_SECONDARY2, filled = true
  }
  return rowH + 1
end

local function appendNote(children, x, y, w, text)
  children[#children + 1] = {
    type = "label",
    x = x, y = y, w = w,
    text = text,
    color = COLOR_THEME_PRIMARY1,
    font = SMLSIZE
  }
  return Controls.LABEL_H + 4
end

local function appendPercentField(children, x, y, w, labelText, key, help)
  return Controls.appendNumberField(
    children, x, y, w,
    labelText,
    {
      min = 0,
      max = 100,
      step = 5,
      suffix = "%",
      get = function() return ui.config[key] end,
      set = ui.runtime.getValueSetter(key),
      helpText = help.helpText,
      helpTitle = help.helpTitle,
      onHelp = help.onHelp
    }
  )
end

-- ─── Module API ──────────────────────────────────────────────────────────────

function M.getHeaderActions()
  ensureDeps()
  return { save = true, help = true }
end

function M.onReload(ctx)
  ensureDeps()
  copyFromPrefs(ctx.preferences)
  ui.dirty = false
end

function M.onSave(ctx)
  ensureDeps()
  if type(ctx.preferences.audio) ~= "table" then ctx.preferences.audio = {} end

  -- Every key, the other mode's included: picking a mode leaves the other one's settings in the
  -- file, so switching back finds them as they were.
  for _, field in ipairs(CONFIG_SCHEMA) do
    ctx.preferences.audio[field.key] = ui.config[field.key]
  end
  -- Saved in Off with Connected only never set, it stays out of the file, so a mode picked later
  -- still starts from that mode's own reading of it.
  if not ui.connectedOnlySet and ui.config.volume_mode == MODE_OFF then
    ctx.preferences.audio.connected_only = nil
  end
  local ok, err = ctx.savePreferences()
  if ok then
    ui.dirty = false
    ui.connectedOnlySet = ctx.preferences.audio.connected_only ~= nil
    if ctx and type(ctx.reportSave) == "function" then
      ctx.reportSave({ ok = true, title = t(ctx.i18n, "saved_title", "Saved"), message = t(ctx.i18n, "saved_message", "Settings saved") })
    end
  else
    if ctx and type(ctx.reportSave) == "function" then
      ctx.reportSave({ title = t(ctx.i18n, "save_error_title", "Error"), message = t(ctx.i18n, "save_error_message", "Save failed") .. ": " .. Common.saveFailureReason(ctx.i18n, err) })
    end
  end
end

-- One mode at a time: the selector, Connected only under it, then the chosen mode's rows. A row a
-- mode gains later goes after that mode's last row, so the rows above it stay where they are.
function M.build(ctx)
  ensureDeps()
  ensureLoaded(ctx.preferences)

  local children = ctx.children
  local x, w = ctx.x, ctx.w
  local i18n = ctx.i18n
  local cursorY = ctx.y
  local mode = ui.config.volume_mode

  ui.runtime.setRequestRebuild(ctx.requestRebuild)
  ui.runtime.openHelp = ctx.openHelp

  local modeLabel = t(i18n, "mode", "Mode")
  cursorY = cursorY + Controls.appendComboSelect(
    children, x, cursorY, w,
    modeLabel,
    getModeOptions(i18n),
    mode,
    onModeSelected,
    helpOpts(t(i18n, "help_mode"), modeLabel)
  )

  if mode ~= MODE_LEVEL and mode ~= MODE_MASTER then return end

  local connectedLabel = t(i18n, "connected_only", "Connected only")
  cursorY = cursorY + Controls.appendRadioSwitch(
    children, x, cursorY, w,
    connectedLabel,
    ui.config.connected_only,
    onConnectedOnlySet,
    nil,
    helpOpts(t(i18n, "help_connected_only"), connectedLabel)
  )

  if mode == MODE_LEVEL then
    local levelLabel = t(i18n, "level", "Level")
    Controls.appendComboSelect(
      children, x, cursorY, w,
      levelLabel,
      getLevelOptions(),
      ui.config.level,
      ui.runtime.getValueSetter("level"),
      helpOpts(t(i18n, "help_level"), levelLabel)
    )
    return
  end

  local gvarLabel = t(i18n, "master_gvar", "Global Variable")
  cursorY = cursorY + appendGvarPicker(children, x, cursorY, w,
    gvarLabel, helpOpts(t(i18n, "help_master_gvar"), gvarLabel))

  local gv = tonumber(ui.config.master_gvar) or 0
  if gv <= 0 then
    -- Master volume with no variable picked writes nothing (lib/audio.lua); said here, so the
    -- mode is not taken for one that acts.
    local none = t(i18n, "gvar_none", "No global variable picked, so the master volume does nothing yet. Pick one above.")
    appendNote(children, x, cursorY + 2, w, none)
    return
  end
  if not Rules.gvarOnBoard(gv) then
    -- Kept in the file and not acted on (lib/audio.lua); said here, so the picker showing none is
    -- not taken for a setting that was never made.
    local missing = t(i18n, "gvar_missing", "GV%d is not on this radio, so the master volume is off. Pick one it has.")
    appendNote(children, x, cursorY + 2, w, string.format(missing, math.tointeger(math.floor(math.min(gv, 99999))) or 0))
    return
  end

  local normalLabel = t(i18n, "master_normal", "Normal")
  cursorY = cursorY + appendPercentField(children, x, cursorY, w, normalLabel, "master_normal",
    helpOpts(t(i18n, "help_master_normal"), normalLabel))

  local alertLabel = t(i18n, "master_alert", "Alert")
  cursorY = cursorY + appendPercentField(children, x, cursorY, w, alertLabel, "master_alert",
    helpOpts(t(i18n, "help_master_alert"), alertLabel))

  if type(model) == "table" and type(model.getGlobalVariableDetails) == "function" then
    local ok, details = pcall(model.getGlobalVariableDetails, gv - 1)
    if ok and type(details) == "table" then
      if details.popup and details.popup ~= 0 and details.popup ~= false then
        appendNote(children, x, cursorY, w, t(i18n, "gvar_popup_warning", "Warning: GVAR popup is enabled"))
      end
    end
  end
end

function M.onClose()
  Common.resetPageState(ui)
  Controls = nil
  Common = nil
  Rules = nil
  t = nil
end

-- Asked before the page is left (ui/home.lua): true while an edit here is not saved.
function M.hasUnsavedChanges()
  return ui.dirty == true
end

return M
