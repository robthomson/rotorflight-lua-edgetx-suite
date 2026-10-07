-- The controls the widget draws over a theme that draws its own fullscreen and binds no control
-- of its own: a way into the quick menu, a way out of fullscreen, and a way into the suite's tool.
--
-- A theme that has taken fullscreen decides which controls it shows and what they do; it binds
-- them through the `ctx` its build receives. This file is what such a screen gets when its tree
-- carries no press at all, which is always the case for a declarative theme -- the engine has
-- no way to bind a tap -- so that no fullscreen the widget puts up is without the menu and a
-- way out. Loaded only then, by the runtime's fullscreen build.
--
-- The geometry is the quick menu's: the X lands exactly where the menu's close box lands, at
-- both layout profiles (`dH > 350` is the split fullscreen_menu.lua uses), the menu control
-- sits one box to its left and the tool control one box to the left of that.
--
-- The tool control is also drawn on its own, on the connect splash at full screen
-- (`M.appendTool`), so the tool can be reached before the dashboard has anything to show.

local M = {}

local requireModule = (_G.rfsuite and _G.rfsuite.require) or function(path)
  local fullPath = string.sub(path, 1, 1) == "/" and path or ("/SCRIPTS/TOOLS/rfsuite-core/" .. path)
  local chunk = loadScript(fullPath, "t")
  if chunk then
    local ok, mod = pcall(chunk)
    if ok and type(mod) == "table" then return mod end
  end
  return nil
end

local Views = requireModule("widgets/dashboard/views.lua")

-- The glyph opens the menu over the theme. The X is drawn on the theme, which is the whole of
-- fullscreen, so it leaves fullscreen -- where the menu's own X, drawn on a view over the
-- theme, closes that view and puts the theme back.
local AFTER_MENU = "openView:menu"
local AFTER_CLOSE = "exitFullscreen"
-- The tool runs in place of the dashboard until it is closed; see widgets/dashboard/tool_host.lua.
local AFTER_TOOL = "openTool"

local function navigate(widget, after)
  if Views and type(Views.navigate) == "function" then Views.navigate(widget, after) end
end

local function geometry(widget)
  local zone = widget.zone
  local dW = (zone and zone.w) or LCD_W or 0
  local dH = (zone and zone.h) or LCD_H or 0

  local isLarge = dH > 350
  local size = isLarge and 44 or 20
  -- The quick menu's own inset for its close box, so the X is not a pixel off the menu's.
  local margin = isLarge and 8 or 1
  return {
    isLarge = isLarge,
    size = size,
    margin = margin,
    cx = dW - size - margin,
    cy = isLarge and 8 or 1,
  }
end

-- The tool control: a button with three slider lines on it. Lines for the same reason as the
-- menu control's bars below -- a line object is not clickable, so a press on the glyph reaches
-- the button. Not drawn while the model is armed: the tool is not opened then (tool_host.lua).
local function appendToolControl(children, widget, x, y, size)
  if widget.state and widget.state.armed == true then return end
  children[#children+1] = {
    type = "button", x = x, y = y, w = size, h = size, color = COLOR_THEME_PRIMARY1 or BLACK,
    press = function() navigate(widget, AFTER_TOOL) end
  }
  local lineW = math.floor(size * 0.56)
  local thin = math.max(1, math.floor(size * 0.05))
  local knobW = math.max(2, math.floor(size * 0.12))
  local knobH = math.max(4, math.floor(size * 0.2))
  local lineX = x + math.floor((size - lineW) / 2)
  local step = math.max(knobH + 1, math.floor(size * 0.25))
  local firstY = y + math.floor(size / 2) - step
  local knobAt = { 0.7, 0.3, 0.55 }
  for i = 0, 2 do
    local lineY = firstY + i * step
    children[#children+1] = {
      type = "line", x = 0, y = 0, w = 0, h = 0,
      pts = { { lineX, lineY }, { lineX + lineW, lineY } },
      color = WHITE, thickness = thin
    }
    local knobX = lineX + math.floor(lineW * knobAt[i + 1])
    local half = math.floor(knobH / 2)
    children[#children+1] = {
      type = "line", x = 0, y = 0, w = 0, h = 0,
      pts = { { knobX, lineY - half }, { knobX, lineY + half } },
      color = WHITE, thickness = knobW
    }
  end
end

--- Append the tool control alone, in the place of the close control, for a fullscreen surface
--- that carries no other control -- the connect splash.
function M.appendTool(children, widget)
  local g = geometry(widget)
  appendToolControl(children, widget, g.cx, g.cy, g.size)
  return children
end

--- Append the tool control, the menu control and the close control to `children`, after
--- whatever is there, so they lie above it.
function M.append(children, widget)
  local g = geometry(widget)
  local isLarge, size, margin = g.isLarge, g.size, g.margin
  local fontH = isLarge and 24 or 12
  local font = isLarge and MIDSIZE or SMLSIZE
  local textOffY = isLarge and -8 or -4

  local cx = g.cx
  local gx = cx - size - margin
  local cy = g.cy

  appendToolControl(children, widget, gx - size - margin, cy, size)

  children[#children+1] = {
    type = "button", x = gx, y = cy, w = size, h = size, color = COLOR_THEME_PRIMARY1 or BLACK,
    press = function() navigate(widget, AFTER_MENU) end
  }

  -- The three bars are LINES, and that is not a drawing preference. A `rectangle` built while
  -- the widget is fullscreen is a clickable object that passes its press to its parent
  -- (lua_lvgl_widget.cpp, LvglWidgetBox::build clears the clickable flag only for a widget that
  -- is not fullscreen), so bars drawn as boxes would lie on top of the button and swallow every
  -- press that lands on them: the control would answer around its bars and not at its centre.
  -- LVGL's line object is created not clickable, so a press on a bar reaches the button -- the
  -- same reason the quick menu's X label over its own button has always worked. The points are
  -- a plain table, not a function, so nothing here is resolved per frame.
  local barW = math.floor(size * 0.5)
  local barH = math.max(2, math.floor(size * 0.08))
  local barX = gx + math.floor((size - barW) / 2)
  local step = math.max(barH + 2, math.floor(size * 0.2))
  local barY = cy + math.floor((size - (barH + step * 2)) / 2) + math.floor(barH / 2)
  for i = 0, 2 do
    local lineY = barY + i * step
    children[#children+1] = {
      type = "line", x = 0, y = 0, w = 0, h = 0,
      pts = { { barX, lineY }, { barX + barW, lineY } },
      color = WHITE, thickness = barH
    }
  end

  children[#children+1] = {
    type = "button", x = cx, y = cy, w = size, h = size, color = COLOR_THEME_SECONDARY1 or RED,
    press = function() navigate(widget, AFTER_CLOSE) end
  }
  children[#children+1] = {
    type = "label", x = cx, y = cy + math.floor((size - fontH) / 2) + textOffY, w = size,
    text = "X", color = WHITE, align = CENTER, font = font
  }
  return children
end

return M
