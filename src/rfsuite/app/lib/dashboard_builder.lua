-- Dynamic dashboard settings menu builder
-- Reuses the dashboard settings library so menus and pages discover
-- the exact same theme set at runtime.

local function loadModule(path)
  local chunk = assert(loadScript("/SCRIPTS/TOOLS/rfsuite-core/" .. path, "t"))
  return chunk()
end

local DashboardLib = loadModule("app/pages/settings/dashboard/lib.lua")
local Log = loadModule("lib/log.lua")
local FALLBACK_ICON = "@pages/settings/dashboard/settings/icon.png"
local OVERRIDES_ICON = "@pages/settings/dashboard/overrides/icon.png"
local DEBUG_PREFIX = "[dashboard.builder] "

local function debugLog(message)
  if Log and type(Log.emit) == "function" then
    Log.emit("dashboard.builder", DEBUG_PREFIX .. tostring(message), "debug")
  end
end

local function hexEncode(input)
  if type(input) ~= "string" then return "" end
  local result = ""
  for i = 1, string.len(input) do
    local byte = string.byte(input, i)
    result = result .. string.format("%02x", byte)
  end
  return result
end

-- Every theme is reachable in two scopes, and the menu id says which: the grid of the Settings
-- tile edits the radio's standard values, the model overrides page edits the connected model's.
-- The settings page reads the scope off the id's prefix, so the two never share a cached module.
local STANDARD_SCOPE = { menuPrefix = "settings_dashboard_settings_", idPrefix = "dashboard_settings_" }
local MODEL_SCOPE = { menuPrefix = "settings_dashboard_model_", idPrefix = "dashboard_model_" }
local OVERRIDES_MENU_ID = "settings_dashboard_overrides_page"
local OVERRIDES_TITLE = "@i18n(app.modules.dashboard_overrides.name)@"

-- The grid a theme's own tile opens when the theme declares pages: one tile per page, laid out
-- like the theme grid above it. Each tile opens the same settings page under a menu id that
-- carries the page id, which is how the page knows which half of the theme it is showing.
local function buildThemePageMenu(t, token, themeIcon, menus, scope)
  local menuId = scope.menuPrefix .. token .. "_menu"
  local pages = {}

  for i = 1, #t.pages do
    local page = t.pages[i]
    local pageMenuId = scope.menuPrefix .. token .. "_" .. page.id .. "_page"
    debugLog("page entry theme=" .. tostring(t.path) .. " page=" .. tostring(page.id) .. " menuId=" .. tostring(pageMenuId))
    pages[#pages + 1] = {
      id = scope.idPrefix .. token .. "_" .. page.id,
      title = page.title,
      menuId = pageMenuId,
      icon = page.iconPath or themeIcon,
      row = math.floor((i - 1) / 6) + 1,
      col = ((i - 1) % 6) + 1,
      themePath = t.path
    }
    menus[pageMenuId] = {
      title = page.title,
      pages = {},
      themePath = t.path
    }
  end

  menus[menuId] = {
    title = t.name,
    pages = pages,
    themePath = t.path
  }

  return menuId
end

-- One theme's entry in a scope's list, with the menus it opens registered beside it.
local function buildThemeEntry(t, index, menus, scope)
  local token = hexEncode(t.path)
  local themeIcon = t.iconPath or FALLBACK_ICON
  local menuId
  if type(t.pages) == "table" then
    menuId = buildThemePageMenu(t, token, themeIcon, menus, scope)
  else
    menuId = scope.menuPrefix .. token .. "_page"
    menus[menuId] = {
      title = t.name,
      pages = {},
      themePath = t.path
    }
  end
  debugLog("menu entry name=" .. tostring(t.name) .. " path=" .. tostring(t.path) .. " menuId=" .. tostring(menuId))
  return {
    id = scope.idPrefix .. token,
    title = t.name,
    menuId = menuId,
    icon = themeIcon,
    row = math.floor((index - 1) / 6) + 1,
    col = ((index - 1) % 6) + 1,
    themePath = t.path
  }
end

-- The model overrides tile exists only while it has something to edit: a flight controller is
-- connected, so the model's store can be addressed, and overrides are on for that model and
-- allowed on this radio. Asked whenever the grid is drawn or entered, so turning overrides on
-- under Design shows the tile the next time the grid is opened.
local function modelOverridesVisible()
  local root = type(_G) == "table" and _G.rfsuite or nil
  local session = root and root.session
  if type(session) ~= "table" or session.mcu_id == nil then return false end
  local modelPrefs = session.modelPreferences
  if type(modelPrefs) ~= "table" then return false end
  local prefs = root.preferences
  local dashboard = type(prefs) == "table" and prefs.dashboard or nil
  return DashboardLib.modelOverridesActive(dashboard, modelPrefs.dashboard) == true
end

local function buildDashboardSettingsThemeMenus()
  local themes = DashboardLib.getConfigurableThemes(DashboardLib.listThemes())
  debugLog("buildDashboardSettingsThemeMenus configurable count=" .. tostring(#themes))

  local entries = {}
  local modelEntries = {}
  local menus = {}

  -- The overview is a page, and its theme entries are what its buttons open: the menu registry
  -- opens an entry of the current menu id's list, and that id is the page's own. Its tile comes
  -- first, ahead of the themes: it is the one tile that is about the connected model, and the
  -- grid lays out only the tiles it shows, so while it is hidden the themes start the grid.
  if #themes > 0 then
    menus[OVERRIDES_MENU_ID] = {
      title = OVERRIDES_TITLE,
      pages = modelEntries
    }
    entries[1] = {
      id = "dashboard_overrides",
      title = OVERRIDES_TITLE,
      menuId = OVERRIDES_MENU_ID,
      icon = OVERRIDES_ICON,
      row = 1,
      col = 1,
      visibleWhen = modelOverridesVisible
    }
  end

  for i = 1, #themes do
    local t = themes[i]
    entries[#entries + 1] = buildThemeEntry(t, #entries + 1, menus, STANDARD_SCOPE)
    modelEntries[#modelEntries + 1] = buildThemeEntry(t, i, menus, MODEL_SCOPE)
  end

  debugLog("buildDashboardSettingsThemeMenus entries=" .. tostring(#entries))

  return entries, menus
end

return {
  buildDashboardSettingsThemeMenus = buildDashboardSettingsThemeMenus
}
