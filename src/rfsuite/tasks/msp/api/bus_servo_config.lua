-- EdgeTX MSP API: BUS_SERVO_CONFIG
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.
-- Ported to EdgeTX schema (Api table + parse)

local Api = {
  command = 152, -- MSP_BUS_SERVO_CONFIG
  writeCommand = 153, -- MSP_SET_BUS_SERVO_CONFIG
  simulatorResponse = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  },
}

function Api.parse(buf)
  if type(buf) ~= "table" or #buf < 18 then return nil end
  local sources = {}
  for i = 1, 18 do
    sources[i] = buf[i] or 0
  end
  return { source_types = sources }
end

function Api.buildWritePayload(data)
  local idx = tonumber(data.index) or 1
  local source_type = tonumber(data.source_type) or 0
  return { idx, source_type }
end

return Api
