-- EdgeTX MSP API: ARMING_CONFIG
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.
-- Ported to EdgeTX schema (Api table + parse)

local Api = {
  command = 61, -- MSP_ARMING_CONFIG
  writeCommand = 62, -- MSP_SET_ARMING_CONFIG
  simulatorResponse = { 5 }, -- auto_disarm_delay
}

function Api.parse(buf)
  if type(buf) ~= "table" or #buf < 1 then return nil end
  return {
    auto_disarm_delay = buf[1] or 0
  }
end

function Api.buildWritePayload(data)
  local delay = tonumber(data.auto_disarm_delay) or 0
  return { delay }
end

return Api
