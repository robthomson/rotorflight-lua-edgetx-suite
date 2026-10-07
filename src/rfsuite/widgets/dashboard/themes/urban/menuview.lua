-- The quick menu's look, for a host with theme views (init.lua registers it under the host's own
-- id, `menu`).
--
-- The look only. The rows are the host's quick menu -- `ctx.list("quick")`, in its order, each
-- drawn where `ctx.visible` offers it -- and every press is `ctx.run` of the host's record or
-- option, so what a row does and what follows it (leaving the menu, opening the picker, raising
-- the tuning surface) is the host's. No row is added and none is left out that the host offers.
-- The close box does what the host menu's own does: `done`.
--
-- A row is a button; a choice without a view of its own -- the battery profiles -- is its title
-- over a grid of its options, the one in force in the ok colour. What the theme shows beside a row
-- is state the host hands out: how full the blackbox is (`ctx.info`).

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

local M = {}

-- The blackbox's fill as the host last read it, or nil where it has not.
local function blackboxLine(info)
  if type(info) ~= "table" then return nil end
  local used, total = K.UD.num(info.used), K.UD.num(info.total)
  if used == nil or total == nil or total <= 0 then return nil end
  return string.format("%s %d%%", K.T.blackbox, math.floor(used * 100 / total + 0.5))
end

-- How many columns a choice's options take in `w`.
local function gridCols(count, w)
  if w < 200 then return 1 end
  return (count > 4 and w >= 400) and 3 or 2
end

-- A choice's options as a grid under its title, the rows `btnH` tall; answers the y below it.
local function optionGrid(nodes, g, f, x, y, w, bottom, item, btnH, run)
  local UD, C = K.UD, K.C
  local entry, options, cols = item.entry, item.options, item.cols
  UD.label(nodes, x, y, w, f.nameH, UD.fit(f.name, entry.title or "", w), f.name, C.label, LEFT)
  y = y + f.nameH + g.gap
  local btnW = math.floor((w - (cols - 1) * g.gap) / cols)
  for i = 1, #options do
    local option = options[i]
    local by = y + math.floor((i - 1) / cols) * (btnH + g.gap)
    if by + btnH > bottom then break end
    local bx = x + ((i - 1) % cols) * (btnW + g.gap)
    K.button(nodes, g, f, bx, by, btnW, btnH, option.label, nil, option.current == true,
      function() run(entry, option) end)
  end
  return y + math.ceil(#options / cols) * (btnH + g.gap)
end

function M.build(children, zone, state, ctx)
  if type(K.begin) ~= "function" then return children end
  local g = K.begin(zone, state or {})
  if g == nil then return children end
  local T = K.T

  local contentY = K.header(children, g, T.view_menu, function() ctx.action("done") end)
  if type(ctx) ~= "table" or type(ctx.list) ~= "function" then return children end

  local run, visible = ctx.run, ctx.visible
  local x, w = g.x + g.pad, g.w - 2 * g.pad
  local bottom = g.y + g.h - g.pad
  local f = K.rowFonts(g)

  -- What is drawn first, so the rows can share the room there is (K.stretch); then the drawing.
  -- A grid's rows are rows of the stack as well, and its title is room the rows cannot have.
  local items, naturals, fixed = {}, {}, 0
  local list = ctx.list("quick")
  for i = 1, #list do
    local entry = list[i]
    if visible(entry) then
      local item = { entry = entry, first = #naturals + 1 }
      if entry.kind == "choice" and entry.view == nil then
        item.options = type(entry.options) == "function" and entry.options() or {}
        item.cols = gridCols(#item.options, w)
        fixed = fixed + f.nameH + g.gap
        for _ = 1, math.ceil(#item.options / item.cols) do naturals[#naturals + 1] = f.lineH end
      else
        if entry.id == "erase_blackbox" and type(ctx.info) == "function" then item.sub = blackboxLine(ctx.info(entry)) end
        naturals[#naturals + 1] = item.sub and f.rowH or f.lineH
      end
      items[#items + 1] = item
    end
  end
  fixed = fixed + math.max(0, #naturals - 1) * g.gap
  local heights = K.stretch(g, bottom - contentY, fixed, naturals)

  for i = 1, #items do
    local item = items[i]
    local entry = item.entry
    local rowH = heights[item.first] or f.lineH
    if item.options then
      if contentY + f.nameH > bottom then break end
      contentY = optionGrid(children, g, f, x, contentY, w, bottom, item, rowH, run)
    else
      if contentY + rowH > bottom then break end
      K.button(children, g, f, x, contentY, w, rowH, entry.title or "", item.sub, false,
        function() run(entry) end)
      contentY = contentY + rowH + g.gap
    end
  end
  return children
end

-- Rebuilt when the profile in force moves, which the grid marks. The blackbox fill is read on the
-- build only: the host re-reads it after an erase, and an erase from this menu closes it.
function M.renderKey(_, state)
  return tostring(state and state.batteryProfile or "")
end

return M
