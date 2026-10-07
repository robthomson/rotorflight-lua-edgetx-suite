-- EdgeTX MSP API: led_strip_modecolor (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 127,
  writeCommand = 221,
  simulatorResponse = {
    -- mode slots 1..24 and special slots 25..35, each: mode, fun, color
  }
}

-- build simulatorResponse table matching Ethos defaults
do
  local t = {}
  -- the values mirror the Ethos default pattern used in source
  local defaults = {
    -- first 24 slot triples (mode, fun, color)
    0,0,0, 0,1,0, 0,2,0, 0,3,0, 0,4,0, 0,5,0,
    1,0,0, 1,1,0, 1,2,0, 1,3,0, 1,4,0, 1,5,0,
    2,0,0, 2,1,0, 2,2,0, 2,3,0, 2,4,0, 2,5,0,
    3,0,0, 3,1,0, 3,2,0, 3,3,0, 3,4,0, 3,5,0,
    -- special slots 25..35 (mode=4)
    4,0,0, 4,1,0, 4,2,0, 4,3,0, 4,4,0, 4,5,0, 4,6,0, 4,7,0, 4,8,0, 4,9,0, 4,10,0,
    255, 0, 0 -- aux_mode, aux_fun, aux_color
  }
  for i = 1, #defaults do t[#t+1] = defaults[i] end
  Api.simulatorResponse = t
end

function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < 108 then return nil end
  local i = 1
  local out = {}
  for idx = 1, 35 do
    out["mode_"..idx] = tonumber(buf[i]); i = i + 1
    out["fun_"..idx] = tonumber(buf[i]); i = i + 1
    out["color_"..idx] = tonumber(buf[i]); i = i + 1
  end
  out.aux_mode = tonumber(buf[i]); i = i + 1
  out.aux_fun = tonumber(buf[i]); i = i + 1
  out.aux_color = tonumber(buf[i]); i = i + 1
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  local function push(v) p[#p+1] = v end
  for idx = 1, 35 do
    push(data["mode_"..idx] or 0)
    push(data["fun_"..idx] or 0)
    push(data["color_"..idx] or 0)
  end
  push(data.aux_mode or 255)
  push(data.aux_fun or 0)
  push(data.aux_color or 0)
  return p
end

return Api
