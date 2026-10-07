-- EdgeTX MSP API: led_strip_config (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 48,
  writeCommand = 49,
  simulatorResponse = (function()
    local t = {}
    -- 32 * 8 bytes for led_config_1..32
    for i = 1, 32 * 8 do t[#t+1] = 0 end
    t[#t+1] = 1 -- advanced_profile_support
    t[#t+1] = 0 -- ledstrip_profile
    return t
  end)()
}

local function pack_u64_from_bytes(b)
  -- return a table of 8 bytes (expects table or number)
  if type(b) == "table" then
    local out = {}
    for i = 1, 8 do out[i] = tonumber(b[i]) or 0 end
    return out
  elseif type(b) == "number" then
    local n = math.floor(b)
    local out = {}
    for k = 0, 7 do out[k+1] = (n >> (k*8)) & 0xFF end
    return out
  else
    return {0,0,0,0,0,0,0,0}
  end
end

function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < (32 * 8 + 2) then return nil end
  local i = 1
  local out = {}
  for idx = 1, 32 do
    local bytes = {}
    for b = 1, 8 do bytes[b] = tonumber(buf[i]) or 0; i = i + 1 end
    out["led_config_"..idx] = bytes
  end
  out.advanced_profile_support = tonumber(buf[i]); i = i + 1
  out.ledstrip_profile = tonumber(buf[i]); i = i + 1
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  local function push(v) p[#p+1] = v end
  for idx = 1, 32 do
    local bytes = pack_u64_from_bytes(data["led_config_"..idx])
    for b = 1, 8 do push(bytes[b] or 0) end
  end
  push(data.advanced_profile_support or 0)
  push(data.ledstrip_profile or 0)
  return p
end

return Api
