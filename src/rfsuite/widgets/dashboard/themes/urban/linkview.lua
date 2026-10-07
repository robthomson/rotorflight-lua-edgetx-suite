-- The link detail view (init.lua registers it as `urban_link`, in full screen and in the widget
-- zone): the ELRS link in detail, in the readings this theme already has.
--
-- Opened in full screen by a tap on the top bar's link bars, and -- in full screen and in the
-- zone alike -- by the switch the pilot names on the settings page (`link_switch`), held: it shows
-- while the switch is in that position. In the zone it is display only: the host builds it
-- without a `ctx`, and it then binds nothing, not even its close box.
--
-- The rows are the readings the top and bottom bars already draw, and nothing the theme would
-- have to ask the host for anew: the receiver's link quality (RQ, `state.lq`), the transmitter's
-- (TQ, the TQly reading), the signal of each receiver antenna in dBm with its bar as headroom over
-- the air rate's floor, the second only where the host has seen one, the transmitter power and the
-- skipped-packet count. The bars take the warning steps the top bar takes from the settings. The
-- transmitter's received signal (TRSS) and the signal-to-noise ratio are not shown: this theme
-- reads neither.

local function requireModule(path)
  if _G.rfsuite and type(_G.rfsuite.require) == "function" then
    local mod = _G.rfsuite.require(path)
    if type(mod) == "table" then return mod end
  end
  local mode = (_G.rfsuite and _G.rfsuite.loadMode) or "bt"
  local chunk = loadScript("/SCRIPTS/TOOLS/rfsuite-core/" .. path, mode)
  if chunk then
    local ok, mod = pcall(chunk)
    if ok and type(mod) == "table" then return mod end
  end
  return nil
end

local K = requireModule("widgets/dashboard/themes/urban/viewkit.lua") or {}
local L = requireModule("widgets/dashboard/themes/urban/layout.lua") or {}

local M = {}

-- What a memo holds before its first reading: no reading equals it.
local UNSET = {}

-- Readers of one number, nil for anything else, with the test written out: the sweep calls them
-- every frame.
local function stateField(state, name)
  return function()
    local v = state[name]
    if type(v) ~= "number" then return nil end
    return v
  end
end

local function derivedField(state, name)
  return function()
    local d = state.derived
    local v = d and d[name]
    if type(v) ~= "number" then return nil end
    return v
  end
end

function M.build(children, zone, state, ctx)
  if type(K.begin) ~= "function" or type(L.setting) ~= "function" then return children end
  state = state or {}
  local g = K.begin(zone, state)
  if g == nil then return children end
  local UD, C, T = K.UD, K.C, K.T

  -- The close box only where there is a ctx, i.e. in full screen: the zone binds no press.
  local closePress = nil
  if type(ctx) == "table" and type(ctx.action) == "function" then
    closePress = function() ctx.action("closeView") end
  end
  local d = state.derived
  local rate = d and d.link_packet_rate
  if type(rate) ~= "string" or rate == "" then rate = nil end
  local top = K.header(children, g, T.view_link, closePress, rate)

  local lqWarn = tonumber(L.setting(state, "lq_warn")) or 80
  local lqCrit = math.max(0, lqWarn - 30)
  local rsWarn = tonumber(L.setting(state, "rssi_warn")) or 15
  local rsCrit = math.floor(rsWarn / 2 + 0.5)
  -- Kept per pair of raw readings: the bar's colour and its length both ask every frame.
  -- rssiPercent tests both for a number itself.
  local function rss(field)
    local lastDbm, lastFloor, lastP = UNSET, UNSET, nil
    return function()
      -- The host replaces the snapshot rather than filling it, so it is read per call.
      local snap = state.derived
      local dbm, floor = state[field], snap and snap.link_floor
      if dbm == lastDbm and floor == lastFloor then return lastP end
      lastDbm, lastFloor = dbm, floor
      lastP = L.rssiPercent(dbm, floor)
      return lastP
    end
  end
  local function dbm(field)
    return UD.getter(stateField(state, field), function(v)
      if v == nil or v == 0 then return "-" end
      return string.format("%ddBm", math.floor(v))
    end)
  end
  local function percent(read)
    return UD.getter(read, function(v)
      if v == nil then return "-" end
      return string.format("%d%%", math.floor(v))
    end)
  end

  local rows = {
    { label = T.link_rq, value = percent(stateField(state, "lq")),
      bar = stateField(state, "lq"), warn = lqWarn, crit = lqCrit },
    { label = T.link_tq, value = percent(derivedField(state, "TQly")),
      bar = derivedField(state, "TQly"), warn = lqWarn, crit = lqCrit },
    { label = T.link_rss1, value = dbm("rss1"), bar = rss("rss1"), warn = rsWarn, crit = rsCrit },
  }
  if type(L.diversity) == "function" and L.diversity(state) then
    rows[#rows + 1] = { label = T.link_rss2, value = dbm("rss2"), bar = rss("rss2"), warn = rsWarn, crit = rsCrit }
  end
  rows[#rows + 1] = { label = T.tpwr, value = UD.getter(derivedField(state, "TPWR"), function(v)
    if v == nil then return "-" end
    return string.format("%dmW", math.floor(v))
  end) }
  rows[#rows + 1] = { label = T.skp, value = UD.getter(derivedField(state, "*Skp"), function(v)
    if v == nil then return "-" end
    return string.format("%d", math.floor(v))
  end) }

  -- The foot line, in the flight view's face: the floor the signal bars measure their headroom
  -- against.
  local x, w = g.x + g.pad, g.w - 2 * g.pad
  local footY = g.y + g.h - g.pad - g.fontH
  UD.label(children, x, footY, w, g.fontH, UD.getter(derivedField(state, "link_floor"), function(v)
    if v == nil then return T.link_floor .. ": -" end
    return string.format("%s: %ddBm", T.link_floor, math.floor(v))
  end), g.font, C.label, LEFT)
  UD.hline(children, x, footY - g.gap, w)

  -- The rows, each a name, a bar where the reading has one, and the figure -- the flight view's
  -- value rows in one line: the name in its face and the label colour, the figure as large as the
  -- row takes, picked by the rule its value panel uses (layout.lua, L.valuePanel: the row height
  -- less 2 px). The name column is as wide as the widest name drawn.
  local rowsH = footY - g.gap - top - g.gap
  local rowH = math.floor(rowsH / #rows)
  local font = UD.selectFont(math.max(8, rowH - 2), math.floor(w / 2), "-108dBm")
  local fontH = UD.measure(font, "-108dBm")
  local labelW = 0
  for i = 1, #rows do labelW = math.max(labelW, UD.textWidth(g.font, rows[i].label)) end
  labelW = labelW + g.pad
  local valueW = UD.textWidth(font, "-108dBm") + g.pad
  local barX = x + labelW
  local barW = math.max(20, w - labelW - valueW - g.pad)
  local barH = math.max(4, math.min(rowH - 6, fontH))
  for i = 1, #rows do
    local row = rows[i]
    local ry = top + (i - 1) * rowH
    local ty = ry + math.floor((rowH - fontH) / 2)
    UD.label(children, x, ry + math.floor((rowH - g.fontH) / 2), labelW, g.fontH, row.label, g.font, C.label, LEFT)
    if row.bar ~= nil then
      local read, warn, crit = row.bar, row.warn, row.crit
      local by = ry + math.floor((rowH - barH) / 2)
      local lastSV, lastW = UNSET, 0
      local lastV, lastColor = UNSET, nil
      UD.rect(children, barX, by, barW, barH, C.track, true, 2)
      children[#children + 1] = {
        type = "rectangle", x = barX, y = by, w = 1, h = barH, filled = true, rounded = 2,
        color = function()
          local v = read()
          if v == lastV then return lastColor end
          lastV = v
          if v == nil then lastColor = C.track
          elseif v <= crit then lastColor = C.crit
          elseif v <= warn then lastColor = C.warn
          else lastColor = C.ok end
          return lastColor
        end,
        size = function()
          local v = read()
          if v ~= lastSV then
            lastSV = v
            local p = v or 0
            if p < 0 then p = 0 elseif p > 100 then p = 100 end
            lastW = math.floor(barW * p / 100)
          end
          return lastW, barH
        end
      }
      UD.rect(children, barX + math.floor(barW * crit / 100), by, 2, barH, C.tick, true, 0)
      UD.rect(children, barX + math.floor(barW * warn / 100), by, 2, barH, C.tick, true, 0)
      UD.rect(children, barX, by, barW, barH, C.frame, false, 2, 1)
    end
    UD.label(children, x + w - valueW, ty, valueW, fontH, row.value, font, C.text, RIGHT)
  end
  return children
end

-- The second antenna adds a row, once the host has seen it.
function M.renderKey(_, state)
  if type(L.diversity) == "function" and L.diversity(state) then return "div" end
  return ""
end

return M
