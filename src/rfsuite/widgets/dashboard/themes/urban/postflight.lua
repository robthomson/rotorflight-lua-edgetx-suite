-- Free-form phase module for the view after a flight: what the last one reached, kept by
-- the runtime after the link drops.

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

local Layout = requireModule("widgets/dashboard/themes/urban/layout.lua") or {}

local Theme = {}

-- `ctx`: see flight.lua.
function Theme.build(zone, state, ctx)
  if type(Layout.buildStats) ~= "function" then return {} end
  return Layout.buildStats(zone, state or {}, ctx)
end

function Theme.renderKey(zone, state)
  if type(Layout.renderKey) ~= "function" then return "urban" end
  return Layout.renderKey(zone, state)
end

return Theme
