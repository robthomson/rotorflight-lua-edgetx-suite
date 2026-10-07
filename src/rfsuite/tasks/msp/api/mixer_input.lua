-- Ported MIXER_INPUT -> mixer_input.lua
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.
local Api = {
    command = 170,
    writeCommand = 171
}

local INPUT_GROUPS = {
    {"aileron", 1024, 820, 1220},
    {"elevator", 1024, 820, 1220},
    {"throttle", 1024, 820, 1220},
    {"tail", 1024, 820, 1220},
    {"aux1", 1024, 820, 1220},
    {"aux2", 1024, 820, 1220},
    {"aux3", 1024, 820, 1220},
    {"aux4", 1024, 820, 1220}
}

local function to_u16(lo, hi)
    lo = tonumber(lo) or 0
    hi = tonumber(hi) or 0
    return ((hi & 0xFF) << 8) | (lo & 0xFF)
end

local function from_u16(v)
    v = tonumber(v) or 0
    v = v & 0xFFFF
    return v & 0xFF, (v >> 8) & 0xFF
end

-- build simulator response using INPUT_GROUPS defaults
local function build_sim_response()
    local t = {}
    for _, g in ipairs(INPUT_GROUPS) do
        local lo, hi = from_u16(g[2] or 0)
        t[#t+1] = lo; t[#t+1] = hi
        lo, hi = from_u16(g[3] or 0)
        t[#t+1] = lo; t[#t+1] = hi
        lo, hi = from_u16(g[4] or 0)
        t[#t+1] = lo; t[#t+1] = hi
    end
    return t
end

Api.simulatorResponse = build_sim_response()

function Api.parse(buf)
    if type(buf) ~= "table" then return nil end
    local expected = #INPUT_GROUPS * 6
    if #buf < expected then return nil end
    local out = {}
    local i = 1
    for _, g in ipairs(INPUT_GROUPS) do
        out["rate_" .. g[1]] = to_u16(buf[i], buf[i+1]); i = i + 2
        out["min_" .. g[1]] = to_u16(buf[i], buf[i+1]); i = i + 2
        out["max_" .. g[1]] = to_u16(buf[i], buf[i+1]); i = i + 2
    end
    return out
end

function Api.buildWritePayload(data)
    data = data or {}
    local idx = tonumber(data.index) or 0
    local payload = {}
    payload[#payload+1] = idx & 0xFF
    local function add_u16(v)
        local lo, hi = from_u16(v or 0)
        payload[#payload+1] = lo; payload[#payload+1] = hi
    end
    add_u16(data.rate or 0)
    add_u16(data.min or 0)
    add_u16(data.max or 0)
    return payload
end

return Api
