-- EdgeTX MSP API: rssi_config (ported from Ethos)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  command = 50,
  writeCommand = 51,
  simulatorResponse = {0, 100, 0, 0}
}

function Api.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < 4 then return nil end
  return {
    rssi_channel = tonumber(buf[1]),
    rssi_scale = tonumber(buf[2]),
    rssi_invert = tonumber(buf[3]),
    rssi_offset = tonumber(buf[4])
  }
end

function Api.buildWritePayload(data)
  data = data or {}
  return {
    tonumber(data.rssi_channel) or 0,
    tonumber(data.rssi_scale) or 100,
    tonumber(data.rssi_invert) or 0,
    tonumber(data.rssi_offset) or 0
  }
end

return Api
