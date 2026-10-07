-- EdgeTX MSP API: SET_MODE_RANGE (write-only)
-- Reference module: no shipped page loads it. It is kept for the developer API tester, which
-- loads a module by its name, and as the starting point for a page that needs this message.

local Api = {
  writeCommand = 35
}

function Api.buildWritePayload(payloadData)
  local payload = payloadData and payloadData.payload
  if type(payload) ~= "table" then return nil end
  return payload
end

return Api
