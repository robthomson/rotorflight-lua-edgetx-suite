-- EdgeTX MSP API: led_colors (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 46,
  writeCommand = 47,
  simulatorResponse = {
    -- 16 colors: each -> U16(h), U8(s), U8(v) encoded as lo,hi,s,v
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  }
}

local function to_u16(lo, hi)
  lo = tonumber(lo) or 0
  hi = tonumber(hi) or 0
  return ((hi & 0xFF) << 8) | (lo & 0xFF)
end

local function from_u16(v)
  v = math.floor(tonumber(v) or 0) & 0xFFFF
  return v & 0xFF, (v >> 8) & 0xFF
end

function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < 64 then return nil end
  local i = 1
  local out = {}
  for idx = 1, 16 do
    local h = to_u16(buf[i], buf[i+1]); i = i + 2
    local s = tonumber(buf[i]); i = i + 1
    local v = tonumber(buf[i]); i = i + 1
    out["color_"..idx.."_h"] = h
    out["color_"..idx.."_s"] = s
    out["color_"..idx.."_v"] = v
  end
  return out
end

function Api.buildWritePayload(data)
  data = data or {}
  local p = {}
  local function push(v) p[#p+1] = v end
  for idx = 1, 16 do
    local h = data["color_"..idx.."_h"] or 0
    local s = data["color_"..idx.."_s"] or 0
    local v = data["color_"..idx.."_v"] or 0
    local lo, hi = from_u16(h)
    push(lo); push(hi); push(s); push(v)
  end
  return p
end

return Api
