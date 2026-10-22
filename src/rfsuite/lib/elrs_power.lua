-- lib/elrs_power.lua
--
-- The transmitter module's power settings, read over the CRSF parameter protocol: the maximum
-- power the pilot set in the module, and whether dynamic power is on. The TX power alert in
-- lib/audio.lua needs both -- the power as a share of the maximum, and only where the module
-- regulates its power at all -- and neither is on any telemetry frame.
--
-- ExpressLRS registers both inside its "TX Power" folder, by name, in 3.x and 4.x alike
-- (4.1.0 src/lib/tx-crsf/TXModuleParameters.cpp:101-118, 3.6.4 src/lib/LUA/tx_devLUA.cpp:76-90):
--
--   "Max Power"  a text selection of power levels in mW, cut to what the hardware can do
--                (CRSFEndpoint.cpp filterOptions), so the value is an index into the cut list and
--                only the LABEL says the power;
--   "Dynamic"    "Off;Dyn;AUX9;AUX10;AUX11;AUX12". Every choice but Off is dynamic power: an AUX
--                choice adds a switch that boosts to the maximum (4.1.0 src/src/dynpower.cpp:106-113).
--
-- Parameter ids are given out in registration order, and what is registered depends on the
-- hardware and the build (an RF Band field on dual-band modules, Antenna Mode on dual-radio ones),
-- so the same firmware numbers the fields differently on two modules. The first read of a module
-- therefore walks the list by name until both fields are found; the ids it found are kept for that
-- module, and every later read asks for the two fields directly. A field that does not belong to
-- the two is left after its first chunk, which carries its name.
--
-- One conversation is driven by `PowerRead.step`, a pass at a time, on a table the caller keeps
-- (the state of one connection). The frame multiplexer (lib/crsf.lua) and the push function are
-- passed in, so the whole conversation can be checked without a radio.

local PowerRead = {}

local FRAME_DEVICE_PING = 0x28
local FRAME_DEVICE_INFO = 0x29
local FRAME_PARAMETER_ENTRY = 0x2B
local FRAME_PARAMETER_READ = 0x2C

-- The ping goes to the transmitter module from the radio, as lib/link_rates.lua's does; a parameter
-- read names the ExpressLRS Lua script as its origin, as the ELRS Link page's does.
local ADDRESS_MODULE = 0xEE
local ADDRESS_RADIO = 0xEA
local ADDRESS_ELRS_LUA = 0xEF
local PING_PAYLOAD = { ADDRESS_MODULE, ADDRESS_RADIO }
local SERIAL_ELRS = { 0x45, 0x4C, 0x52, 0x53 }  -- 'E' 'L' 'R' 'S'

local TYPE_TEXT_SELECTION = 9

-- How long an unanswered request waits before it is sent again.
local PING_RETRY_SECONDS = 1.0
local REQUEST_RETRY_SECONDS = 0.5

-- How many tries one conversation may make to send a frame, in all, before the values are left
-- unknown. Every try counts -- a repeat, and one the full output buffer refused -- so that the
-- conversation ends on any radio. A budget in tries rather than seconds, because a radio running
-- its passes slowly sends one frame per pass and would run out of seconds while the module is
-- still answering. The longest first read measured is 12 frames, the ping included (a dual-band
-- module with RF Band and Antenna Mode ahead of the power fields, Max Power in two chunks); 36 is
-- three tries per frame of that read on average, so a slow or lossy module still finishes, and a
-- module that never answers is left after 36 pings. An attempt an arming cuts short starts again
-- after the disarm on a fresh table, with a fresh count.
local FRAME_BUDGET = 36

-- Field ids per module, for the life of this Lua state. The key is the module's name, versions and
-- field count off its device information: the same key is the same numbering.
local idsByModule = {}

PowerRead.FRAME_BUDGET = FRAME_BUDGET

--- The module's identity and field count from a device-information payload; nil where the payload
--- is not the transmitter module's answer, false where the module is not ExpressLRS.
---
--- The layout is the one lib/link_rates.lua reads (generationFromDeviceInfo): destination, origin,
--- the name and its terminating nought, then serial, hardware and software version, four bytes
--- each, then the parameter count.
function PowerRead.identity(data)
  if type(data) ~= "table" or data[2] ~= ADDRESS_MODULE then return nil end
  local i = 3
  while data[i] ~= nil and data[i] ~= 0 do i = i + 1 end
  if data[i] == nil then return nil end
  local offset = i + 1
  local count = data[offset + 12]
  if type(count) ~= "number" then return nil end
  for k = 1, 4 do
    if data[offset + k - 1] ~= SERIAL_ELRS[k] then return false end
  end
  local name = {}
  for k = 3, i - 1 do name[#name + 1] = string.char(data[k]) end
  local key = table.concat(name) .. "|" .. table.concat(data, ".", offset + 4, offset + 11) .. "|" .. count
  return key, count
end

-- A nought-terminated string out of `bytes` from `from`; the string and the index after its nought,
-- or nil where the nought is not there.
local function cString(bytes, from)
  local i = from
  while bytes[i] ~= nil and bytes[i] ~= 0 do i = i + 1 end
  if bytes[i] == nil then return nil end
  local chars = {}
  for k = from, i - 1 do chars[#chars + 1] = string.char(bytes[k]) end
  return table.concat(chars), i + 1
end

--- Which of the two fields a parameter name is: "max", "dynamic", or nil.
function PowerRead.classify(name)
  if type(name) ~= "string" then return nil end
  local lower = string.lower(name)
  if lower == "max power" then return "max" end
  if lower == "dynamic" then return "dynamic" end
  return nil
end

--- A whole parameter entry, its chunks joined: parent, type, name, and for a text selection the
--- options, the selected index and the unit. `bytes` starts at the parent byte (the payload after
--- destination, origin, field id and chunks remaining). Nil where it is not a whole text selection.
function PowerRead.parseSelection(bytes)
  local fieldType = bytes[2]
  if type(fieldType) ~= "number" or fieldType % 128 ~= TYPE_TEXT_SELECTION then return nil end
  local name, after = cString(bytes, 3)
  if not name then return nil end
  local optionText, valueAt = cString(bytes, after)
  if not optionText then return nil end
  local value = bytes[valueAt]
  if type(value) ~= "number" then return nil end
  -- value, min, max, default, then the unit.
  local unit = cString(bytes, valueAt + 4) or ""
  local options = {}
  for option in string.gmatch(optionText .. ";", "([^;]*);") do options[#options + 1] = option end
  return { name = name, options = options, value = value, unit = unit }
end

--- The maximum power in mW a parsed "Max Power" field selects, or nil.
---
--- Nil where the label is not a plain number: on a dual-band module built for the CE domain the
--- labels are pairs ("25/250", the limit of each band), and which one applies depends on the band
--- the link runs on, which this field does not say.
function PowerRead.maxPowerMilliwatts(field)
  if type(field) ~= "table" or string.lower(field.unit or "") ~= "mw" then return nil end
  local label = field.options[field.value + 1]
  local mw = tonumber(label)
  if mw == nil or mw <= 0 then return nil end
  return mw
end

--- Whether a parsed "Dynamic" field says dynamic power is on, or nil where its options are not
--- the ones this reads.
function PowerRead.dynamicOn(field)
  if type(field) ~= "table" or string.lower(field.options[1] or "") ~= "off" then return nil end
  return field.value > 0
end

local function clearBuffer(st)
  local buf = st.buf
  for i = #buf, 1, -1 do buf[i] = nil end
  st.chunk = 0
  st.expectRemain = nil
  st.requestAt = nil
end

local function finish(st)
  st.done = true
  st.phase = nil
end

-- The next field to ask for, or the end of the conversation.
local function nextField(st)
  clearBuffer(st)
  if st.phase == "read" then
    if st.field == st.maxId then
      st.field = st.dynamicId
      return
    end
    finish(st)
    return
  end
  if st.maxId and st.dynamicId then
    idsByModule[st.key] = { max = st.maxId, dynamic = st.dynamicId }
    finish(st)
    return
  end
  st.field = st.field + 1
  if st.field > (st.fieldCount or 0) then finish(st) end
end

-- One whole field has arrived.
local function takeField(st, bytes)
  local field = PowerRead.parseSelection(bytes)
  local kind = field and PowerRead.classify(field.name) or nil
  if st.phase == "read" then
    local expected = (st.field == st.maxId) and "max" or "dynamic"
    if kind ~= expected then
      -- The module numbers its fields differently from when the ids were kept (a new build with
      -- the same name and version is the case this covers): forget them and walk again.
      idsByModule[st.key] = nil
      st.phase = "walk"
      st.maxId, st.dynamicId = nil, nil
      st.maxMilliwatts, st.dynamic = nil, nil
      st.field = 0
      nextField(st)
      return
    end
  end
  if kind == "max" then
    st.maxId = st.field
    st.maxMilliwatts = PowerRead.maxPowerMilliwatts(field)
  elseif kind == "dynamic" then
    st.dynamicId = st.field
    st.dynamic = PowerRead.dynamicOn(field)
  end
  nextField(st)
end

-- One parameter-entry frame for the field asked for.
local function takeEntry(st, data)
  local remain = data[4]
  if type(remain) ~= "number" then return end
  -- The reply carries how many chunks remain, not which one this is; a chunk that is not the one
  -- asked for is a late answer to an earlier request and is dropped.
  if st.expectRemain ~= nil and remain ~= st.expectRemain then return end
  if st.chunk == 0 and st.phase == "walk" then
    -- The name is in the first chunk. A field that is neither of the two is left here.
    local name = cString(data, 7)
    if PowerRead.classify(name) == nil then
      nextField(st)
      return
    end
  end
  local buf = st.buf
  for i = 5, #data do buf[#buf + 1] = data[i] end
  if remain > 0 then
    st.chunk = st.chunk + 1
    st.expectRemain = remain - 1
    st.requestAt = nil
    return
  end
  takeField(st, buf)
end

--- Drive one conversation one step. `st` is the caller's table for one connection; `crsf` is the
--- frame multiplexer (lib/crsf.lua) and `push` is crossfireTelemetryPush. When `st.done` is set the
--- results stand on it: `maxMilliwatts` (number or nil) and `dynamic` (true, false or nil), nil
--- meaning not known. Every frame this sends goes out in place of one RC channels frame, so it
--- sends at most one per call, and a caller calls it only while the model is disarmed.
function PowerRead.step(st, crsf, push, now)
  if st.done then return end
  if type(push) ~= "function" or type(crsf) ~= "table" or type(crsf.popFrame) ~= "function" then
    finish(st)
    return
  end
  if st.sent == nil then
    st.sent = 0
    st.buf = st.buf or {}
    -- Parameter entries that are still waiting are another conversation's: a late answer to an
    -- earlier connection's read, or the ELRS Link page's walk, which reaches every Lua state's
    -- queue. lib/crsf.lua keeps them for this reader once it has asked for the type, and one for a
    -- field of the same id would pass for this conversation's answer with the value of before.
    -- Device information is left alone, because another reader may be waiting for its answer.
    while crsf.popFrame(FRAME_PARAMETER_ENTRY) ~= nil do end
  end
  if st.phase == nil then
    -- Device information is taken only once this conversation has pinged: an answer that was
    -- already waiting is another reader's (the dashboard pings once for the link's generation).
    while st.pingAt ~= nil do
      local data = crsf.popFrame(FRAME_DEVICE_INFO)
      if data == nil then break end
      local key, count = PowerRead.identity(data)
      if key == false then
        -- The module answered and is not ExpressLRS: nothing to read.
        finish(st)
        return
      end
      if key then
        st.key = key
        st.fieldCount = count
        local ids = idsByModule[key]
        if ids then
          st.phase = "read"
          st.maxId, st.dynamicId = ids.max, ids.dynamic
          st.field = ids.max
        else
          st.phase = "walk"
          st.field = 1
          if count <= 0 then
            finish(st)
            return
          end
        end
        clearBuffer(st)
        break
      end
    end
    if st.phase == nil then
      if st.pingAt == nil or (now - st.pingAt) >= PING_RETRY_SECONDS then
        if st.sent >= FRAME_BUDGET then
          finish(st)
          return
        end
        st.sent = st.sent + 1
        local ok, queued = pcall(push, FRAME_DEVICE_PING, PING_PAYLOAD)
        -- Nil is EdgeTX saying no module runs the CRSF protocol; false is a full output buffer,
        -- which the next call tries again.
        if ok and queued == nil then
          finish(st)
          return
        end
        if ok and queued then st.pingAt = now end
      end
      return
    end
  end

  -- An entry counts only while a request of this conversation is out; one that arrives between the
  -- answer and the next request is a repeat of an answer already taken.
  while not st.done do
    local data = crsf.popFrame(FRAME_PARAMETER_ENTRY)
    if data == nil then break end
    if st.requestAt ~= nil and data[2] == ADDRESS_MODULE and data[3] == st.field then takeEntry(st, data) end
  end
  if st.done then return end

  if st.requestAt == nil or (now - st.requestAt) >= REQUEST_RETRY_SECONDS then
    -- The budget is spent: the answer to the last frame had its chance until now.
    if st.sent >= FRAME_BUDGET then
      finish(st)
      return
    end
    st.sent = st.sent + 1
    local ok, queued = pcall(push, FRAME_PARAMETER_READ, { ADDRESS_MODULE, ADDRESS_ELRS_LUA, st.field, st.chunk })
    if ok and queued then st.requestAt = now end
  end
end

--- Forget the ids kept for every module. For a caller that knows the module was replaced or
--- reflashed; nothing in the suite calls it on its own.
function PowerRead.forget()
  for k in pairs(idsByModule) do idsByModule[k] = nil end
end

return PowerRead
