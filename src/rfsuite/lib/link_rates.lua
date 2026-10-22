-- What the CRSF link-statistics frame says about the radio link itself.
--
-- Two things live here, and both are the frame's own semantics rather than presentation: the
-- packet rate the `RFMD` field names, and the test that decides whether the `2RSS` and `ANT`
-- fields prove a receiver has a second antenna. Neither needs a radio to evaluate, which is
-- why they are data and a pair of pure functions rather than part of the widget. Beside them
-- sit the two things both the dashboard and the audio announcements build on that: the query
-- that learns which ExpressLRS generation the module runs (its frame functions are passed in,
-- so it too runs without a radio), the headroom a signal reading has above its rate's floor, and
-- where a signal-to-noise reading sits between the rate's dynamic-power thresholds.
--
-- THE RATE TABLES ARE EXPRESSLRS'S, ONE PER GENERATION, AND THE BYTE DOES NOT SAY WHICH.
--
-- `RFMD` is byte 8 of the link-statistics frame (0x14), and the frame a radio parses is the one
-- the TRANSMITTER module builds for it -- not the one the receiver sends the flight controller,
-- which never reaches the radio. The transmitter writes its current air rate into that byte
-- verbatim: `linkStats.rf_Mode = ModParams->enum_rate` (ExpressLRS 4.1.0 src/src/tx_main.cpp:503,
-- 3.6.4 :441, 3.0.0 :346). So the byte is a value of `expresslrs_RFrates_e`. EdgeTX stores it
-- unchanged: its CRSF driver remaps only the transmit-power index of that frame
-- (edgetx radio/src/telemetry/crossfire.cpp:300-309) and declares `RFMD` as UNIT_RAW
-- (crossfire.cpp:49).
--
-- ExpressLRS renumbered that enumeration between 3.x and 4.x, and it is not a shift. Through
-- the whole of 3.x (3.0.0 to 3.6.4, appended to and never reordered) the values run 0..19 with
-- the band left out of the name; from 4.0.0 (unchanged through 4.1.0) they run 0..11 for
-- 900 MHz, 20..36 for 2.4 GHz and 100..101 for both bands (4.1.0 src/include/common.h:83-116,
-- 3.6.4 :80-102). Most of 0..11 is used by both with different meanings -- byte 10 is
-- `RATE_DVDA_250HZ` (FLRC, 2.4 GHz) on 3.x and `RATE_LORA_900_50HZ_DVDA` on 4.x -- and those
-- are the common rates, so the generation cannot be inferred from the byte either.
--
-- What says which it is: the device-information frame (0x29) the transmitter module answers a
-- device ping (0x28) with. ExpressLRS fills its serial with 'ELRS' and its software version
-- with the release number, major first (4.1.0 src/lib/CrsfProtocol/CRSFEndpoint.cpp:426-428,
-- 3.6.4 src/lib/Handset/CRSF.cpp:72-74). A build whose version string is not a release number
-- reports its over-the-air protocol generation as the major instead (`OTA_VERSION_ID << 16`,
-- CRSFEndpoint.cpp:412 and CRSF.cpp:59), which is 3 throughout 3.x and 4 throughout 4.x -- so a
-- development build still names its generation. `generationFromDeviceInfo` below reads that
-- frame; until it has, the rate is not resolved at all, because a guessed generation is a
-- wrong rate on half of the links.
--
-- And the byte is protocol-specific, not ExpressLRS's alone: the field is defined as an
-- enumeration by whichever module fills it ("RF Mode ( enum 4fps = 0, 50fps, 150hz )" in the
-- CRSF specification). A transmitter module that does not identify as ExpressLRS 3.x or 4.x is
-- therefore never resolved against these tables.
--
-- The sensitivity floor is `expresslrs_rf_pref_params_s.RXsensitivity`, "expected min RF
-- sensitivity" in dBm, out of the three `ExpressLRS_AirRateRFperf` tables in src/src/common.cpp
-- -- SX127x (900 MHz), LR1121 (both bands) and SX128x (2.4 GHz); at 4.1.0 :17-23, :53-73 and
-- :93-103, at 3.6.4 :17-23, :49-65 and :85-95 -- matched to the rate by the `enum_rate` column
-- of the `ExpressLRS_AirRateConfig` table beside each of them. Where every table that
-- configures a byte gives it the same figure, the floor is a function of the byte and is stated.
-- On 4.x that holds for every configured byte, because the value carries the band. On 3.x it
-- fails for two: `RATE_LORA_50HZ` is -120 dBm on 900 MHz and -115 on 2.4 GHz, and
-- `RATE_LORA_250HZ` -- configured on 900 MHz as well from 3.4.0 -- is -111 against -108. The
-- band is not in the frame, so those two carry a rate and no floor.
--
-- It is kept in ExpressLRS's sign, negative, which is also the sign the radio's own RSSI sensors
-- carry: the transmitter negates the magnitude the receiver sent it on the way to the handset
-- (4.1.0 src/src/tx_main.cpp:145-146, 3.6.4 :177-178, *"OpenTX's value is signed and will
-- display +dBm and -dBm properly"*), and EdgeTX sign-extends the byte. So a floor and an RSSI
-- reading are directly comparable and their difference is the headroom in dB.
--
-- The spellings are ExpressLRS's own, taken from the option list its handset script shows
-- (`STR_LUA_PACKETRATES`: 4.1.0 src/lib/tx-crsf/TXModuleParameters.cpp:24-36, 3.6.4
-- src/lib/LUA/tx_devLUA.cpp:19-29, which list the rates in reverse index order and carry the
-- same sensitivity figures). A tile therefore reads the same words the module's own screen
-- does. Those strings do not name the band -- "50Hz" is both the 900 MHz and the 2.4 GHz rate
-- -- and that is kept rather than corrected, for the same reason. The one exception is 3.x on
-- the LR1121, whose list spells the band out ("50 2.4G", "250 Low Band"); the byte does not
-- carry the band there either, so the 3.x table uses the SX127x and SX128x spellings, which are
-- the same words 4.x uses.

local LinkRates = {}

-- rf_Mode -> { rate = the air rate as ExpressLRS spells it,
--              floor = expected minimum RF sensitivity in dBm, absent where no radio target
--                      configures the rate, or where the targets that do disagree,
--              noSnr = true where the modulation reports no usable signal-to-noise ratio,
--              modulation = "FLRC" or "FSK" where the rate is not LoRa, absent where it is,
--              snrUp, snrDn = the rate's dynamic-power SNR thresholds in dB, absent where
--                      the rate has none (noSnr) or the targets that configure it disagree }
--
-- `snrUp` and `snrDn` are `DynpowerSnrThreshUp` and `DynpowerSnrThreshDn` of the same
-- `ExpressLRS_AirRateRFperf` rows the floor comes from (fields: 4.1.0 src/include/common.h:147
-- and :149, 3.6.4 :145 and :147, 3.0.0 :119 and :121), written in dB as the tables write them,
-- `SNR_SCALE(x)`; every radio driver scales by 4, so the half-dB figures are exact. ExpressLRS's
-- dynamic power asks for more power while the reported average SNR is at or below `snrUp` and
-- for less at or above `snrDn` (3.6.4 src/src/dynpower.cpp:175-181); 4.x starts from the same
-- pair and, once its statistics window is full, moves both to fit the link's own SNR spread
-- (4.1.0 dynpower.cpp:192-221), so on 4.x these are the rate's configured figures. The rule is
-- the floor's: a figure only where every table that configures the byte gives the same pair. On
-- 4.x that holds for every LoRa byte; on 3.x it fails for three,
-- because the band is not in the byte: 2 (`RATE_LORA_50HZ`, -1 / 1.5 dB on 900 MHz, -1 / 6.5 on
-- 2.4 GHz), 4 (`RATE_LORA_100HZ_8CH`, 1 / 3 against 0 / 8.5 -- its floor agrees, its SNR does not)
-- and 7 (`RATE_LORA_250HZ`, 1 / 3 against 3 / 9.5). Checked against every release tag from 3.0.0
-- to 4.1.0: no pair of a configured byte changed within either generation.
--
-- `noSnr` is ExpressLRS's own distinction rather than a judgement: the FLRC and GFSK rates are
-- exactly the ones whose `DynpowerSnrThreshUp` is `DYNPOWER_SNR_THRESH_NONE`, the marker its
-- dynamic-power control uses for "this rate's SNR cannot be compared" (4.1.0 common.h:131,
-- 3.6.4 :130, and the rows in common.cpp). The `RSNR` and `TSNR` sensors read 0 on them.
--
-- `modulation` is the radio type the rate runs on, from the second column of the
-- `ExpressLRS_AirRateConfig` tables beside the floors: `RADIO_TYPE_SX128x_FLRC` /
-- `RadioBandMod::Combined::FLRC_2G4` for the FLRC rates, the DVDA 250 Hz and 500 Hz ones among
-- them, and `RADIO_TYPE_LR1121_GFSK_*` / `GFSK_*` for the FSK ones (3.6.4 common.cpp:46-47 and
-- :74-77, 4.1.0 :32, :41-43 and :82-85). Every other configured rate is LoRa, `RATE_DVDA_50HZ`
-- included, and carries no field. Each rate NAME has one modulation in both generations, which is
-- what lets LinkRates.modulationOf answer from the name alone.
--
-- A rate the enumeration declares and no radio target configures still has a name, because the
-- enumeration constant says what it is; it is named and its floor is left out rather than
-- guessed. It can never be on the air, so the name is there for completeness, not for a tile.

-- ExpressLRS 4.x (4.0.0 to 4.1.0). Seven configured by no target: 4, 8, 9, 20, 22, 25, 26.
LinkRates.byMode4 = {
  -- 900 MHz (RATE_LORA_900_* / RATE_FSK_900_*, enum values 0..11)
  [0]   = { rate = "25Hz",       floor = -123, snrUp = -3, snrDn = 0.5 },
  [1]   = { rate = "50Hz",       floor = -120, snrUp = -1, snrDn = 1.5 },
  [2]   = { rate = "100Hz",      floor = -117, snrUp = 1, snrDn = 2.5 },
  [3]   = { rate = "100Hz Full", floor = -112, snrUp = 1, snrDn = 3 },
  [4]   = { rate = "150Hz" },
  [5]   = { rate = "200Hz",      floor = -112, snrUp = 1, snrDn = 3 },
  [6]   = { rate = "200Hz Full", floor = -111, snrUp = 1, snrDn = 3 },
  [7]   = { rate = "250Hz",      floor = -111, snrUp = 1, snrDn = 3 },
  [8]   = { rate = "333Hz Full" },
  [9]   = { rate = "500Hz" },
  [10]  = { rate = "D50Hz",      floor = -112, snrUp = 1, snrDn = 3 },
  [11]  = { rate = "K1000 Full", floor = -101, noSnr = true, modulation = "FSK" },

  -- 2.4 GHz (RATE_LORA_2G4_* / RATE_FLRC_2G4_* / RATE_FSK_2G4_*, enum values 20..36)
  [20]  = { rate = "25Hz" },
  [21]  = { rate = "50Hz",       floor = -115, snrUp = -1, snrDn = 6.5 },
  [22]  = { rate = "100Hz" },
  [23]  = { rate = "100Hz Full", floor = -112, snrUp = 0, snrDn = 8.5 },
  [24]  = { rate = "150Hz",      floor = -112, snrUp = 0, snrDn = 8.5 },
  [25]  = { rate = "200Hz" },
  [26]  = { rate = "200Hz Full" },
  [27]  = { rate = "250Hz",      floor = -108, snrUp = 3, snrDn = 9.5 },
  [28]  = { rate = "333Hz Full", floor = -105, snrUp = 5, snrDn = 9.5 },
  [29]  = { rate = "500Hz",      floor = -105, snrUp = 5, snrDn = 9.5 },
  [30]  = { rate = "D250",       floor = -104, noSnr = true, modulation = "FLRC" },
  [31]  = { rate = "D500",       floor = -104, noSnr = true, modulation = "FLRC" },
  [32]  = { rate = "F500",       floor = -104, noSnr = true, modulation = "FLRC" },
  [33]  = { rate = "F1000",      floor = -104, noSnr = true, modulation = "FLRC" },
  [34]  = { rate = "DK250",      floor = -103, noSnr = true, modulation = "FSK" },
  [35]  = { rate = "DK500",      floor = -103, noSnr = true, modulation = "FSK" },
  [36]  = { rate = "K1000",      floor = -103, noSnr = true, modulation = "FSK" },

  -- Both bands at once (RATE_LORA_DUAL_*, enum values 100..101)
  [100] = { rate = "100Hz Full", floor = -112, snrUp = 0, snrDn = 8.5 },
  [101] = { rate = "150Hz",      floor = -112, snrUp = 0, snrDn = 8.5 },
}

-- ExpressLRS 3.x (3.0.0 to 3.6.4; 14 was added in 3.3.0, 15 in 3.4.0, 16..19 in 3.5.0, and no
-- figure of an existing value changed on the way). Configured by no target: 0, 17, 18.
-- 2 and 7 have no floor because their figure depends on the band (see the header); 2, 4 and 7
-- carry no SNR thresholds for the same reason (see the rows' description above).
LinkRates.byMode3 = {
  [0]   = { rate = "4Hz" },                                     -- RATE_LORA_4HZ
  [1]   = { rate = "25Hz",       floor = -123, snrUp = -3, snrDn = 0.5 },            -- RATE_LORA_25HZ
  [2]   = { rate = "50Hz" },                                                         -- RATE_LORA_50HZ: -120 / -115, SNR -1/1.5 / -1/6.5
  [3]   = { rate = "100Hz",      floor = -117, snrUp = 1, snrDn = 2.5 },             -- RATE_LORA_100HZ
  [4]   = { rate = "100Hz Full", floor = -112 },                                     -- RATE_LORA_100HZ_8CH: SNR 1/3 / 0/8.5
  [5]   = { rate = "150Hz",      floor = -112, snrUp = 0, snrDn = 8.5 },             -- RATE_LORA_150HZ
  [6]   = { rate = "200Hz",      floor = -112, snrUp = 1, snrDn = 3 },               -- RATE_LORA_200HZ
  [7]   = { rate = "250Hz" },                                                        -- RATE_LORA_250HZ: -111 / -108, SNR 1/3 / 3/9.5
  [8]   = { rate = "333Hz Full", floor = -105, snrUp = 5, snrDn = 9.5 },             -- RATE_LORA_333HZ_8CH
  [9]   = { rate = "500Hz",      floor = -105, snrUp = 5, snrDn = 9.5 },             -- RATE_LORA_500HZ
  [10]  = { rate = "D250",       floor = -104, noSnr = true, modulation = "FLRC" },  -- RATE_DVDA_250HZ
  [11]  = { rate = "D500",       floor = -104, noSnr = true, modulation = "FLRC" },  -- RATE_DVDA_500HZ
  [12]  = { rate = "F500",       floor = -104, noSnr = true, modulation = "FLRC" },  -- RATE_FLRC_500HZ
  [13]  = { rate = "F1000",      floor = -104, noSnr = true, modulation = "FLRC" },  -- RATE_FLRC_1000HZ
  [14]  = { rate = "D50Hz",      floor = -112, snrUp = 1, snrDn = 3 },               -- RATE_DVDA_50HZ
  [15]  = { rate = "200Hz Full", floor = -111, snrUp = 1, snrDn = 3 },               -- RATE_LORA_200HZ_8CH
  [16]  = { rate = "DK500",      floor = -103, noSnr = true, modulation = "FSK" },   -- RATE_FSK_2G4_DVDA_500HZ
  [17]  = { rate = "K1000", modulation = "FSK" },                -- RATE_FSK_2G4_1000HZ
  [18]  = { rate = "K1000", modulation = "FSK" },                -- RATE_FSK_900_1000HZ
  [19]  = { rate = "K1000 Full", floor = -101, noSnr = true, modulation = "FSK" },   -- RATE_FSK_900_1000HZ_8CH
}

LinkRates.byGeneration = { [3] = LinkRates.byMode3, [4] = LinkRates.byMode4 }

--- What the `RFMD` reading `mode` says the link is running, or nil.
--
-- `generation` is the ExpressLRS major version the transmitter module reported, as
-- `generationFromDeviceInfo` returns it. Nil covers the generation not being known yet, the
-- module not being ExpressLRS 3.x or 4.x, the reading being absent or not a whole number, and
-- the byte carrying a value that generation leaves unused.
function LinkRates.forMode(mode, generation)
  local rows = LinkRates.byGeneration[generation]
  if not rows then return nil end
  if type(mode) ~= "number" then return nil end
  -- The sensor is declared UNIT_RAW with no decimals, so anything fractional arriving here is
  -- not an air rate and rounding it would name one.
  if mode % 1 ~= 0 then return nil end
  return rows[mode]
end

--- The modulation of the air rate ExpressLRS names `rate` -- "LoRa", "FLRC" or "FSK" -- or nil
--- where no row of either generation carries that name. Read off the rows rather than the name's
--- spelling, so a rate added to a table answers without a second list to keep in step. A scan of
--- both tables, for a caller that keeps the answer until the rate changes.
function LinkRates.modulationOf(rate)
  if type(rate) ~= "string" then return nil end
  for _, rows in pairs(LinkRates.byGeneration) do
    for _, row in pairs(rows) do
      if row.rate == rate then return row.modulation or "LoRa" end
    end
  end
  return nil
end

-- The device ping and its answer. The ping is addressed to the transmitter module (0xEE) from
-- the radio (0xEA), which both generations answer (4.1.0 CRSFEndpoint.cpp:342-344, 3.6.4
-- src/lib/Handset/CRSFHandset.cpp:335-337 and src/lib/LUA/lua.cpp:392-397) and which, unlike a
-- broadcast, is not forwarded to the receiver.
LinkRates.FRAME_DEVICE_PING = 0x28
LinkRates.FRAME_DEVICE_INFO = 0x29
LinkRates.PING_PAYLOAD = { 0xEE, 0xEA }

local ADDRESS_TRANSMITTER = 0xEE
local SERIAL_ELRS = { 0x45, 0x4C, 0x52, 0x53 }  -- 'E' 'L' 'R' 'S'

--- The generation a device-information payload names: 3 or 4 for ExpressLRS 3.x or 4.x, 0 for
--- a transmitter module that is anything else, nil where this payload is not the transmitter
--- module's answer at all.
---
--- `data` is the table crossfireTelemetryPop returns for frame 0x29: destination, origin, the
--- device name and its terminating nought, then serial, hardware version and software version,
--- four bytes each and big-endian, then the parameter count -- the layout the ELRS Link page
--- already reads. The software version is (0, major, minor, revision).
function LinkRates.generationFromDeviceInfo(data)
  if type(data) ~= "table" or data[2] ~= ADDRESS_TRANSMITTER then return nil end
  local i = 3
  while data[i] ~= nil and data[i] ~= 0 do i = i + 1 end
  if data[i] == nil then return nil end
  local offset = i + 1
  -- serial (4) + hardware (4) + software (4): anything shorter is not a whole answer.
  local major = data[offset + 9]
  if type(data[offset + 11]) ~= "number" or type(major) ~= "number" then return nil end
  for k = 1, 4 do
    if data[offset + k - 1] ~= SERIAL_ELRS[k] then return 0 end
  end
  if LinkRates.byGeneration[major] then return major end
  return 0
end

--- The ExpressLRS generation of the transmitter module -- 3, 4, or 0 for anything else -- or
--- nil while it is not known, asked for once and remembered on `state`.
---
--- The `RFMD` byte means different rates on ExpressLRS 3.x and 4.x and does not say which, so
--- the module is asked: one device ping, and the device-information frame it answers with names
--- the release (`generationFromDeviceInfo` above). The answer is kept in `state.linkGeneration`
--- and the fact that the ping went out in `state.linkPingSent`; a caller clears both where the
--- next connection may be a different module.
---
--- `crsf` is lib/crsf.lua, the one frame multiplexer of the caller's Lua state: asking it for
--- 0x29 before the ping is what makes it keep the answer when another consumer drains the queue
--- first, and it keeps every other consumer's frames while this one drains. `push` is
--- crossfireTelemetryPush. Both are arguments so that the rule can be run without a radio.
--- Nothing calls this unless it needs a rate: a dashboard theme that declares one of the rate
--- sources, or an announcement that measures the link against its rate.
function LinkRates.resolveGeneration(state, crsf, push)
  if type(state) ~= "table" then return nil end
  if state.linkGeneration ~= nil then return state.linkGeneration end
  if not (crsf and type(crsf.popFrame) == "function") then return nil end
  while true do
    local data = crsf.popFrame(LinkRates.FRAME_DEVICE_INFO)
    if data == nil then break end
    local generation = LinkRates.generationFromDeviceInfo(data)
    if generation ~= nil then
      state.linkGeneration = generation
      return generation
    end
  end
  if state.linkPingSent or type(push) ~= "function" then return nil end
  local ok, queued = pcall(push, LinkRates.FRAME_DEVICE_PING, LinkRates.PING_PAYLOAD)
  if not ok then return nil end
  -- Nil is EdgeTX saying no module runs the CRSF protocol, so nothing will answer and nothing
  -- ExpressLRS is there. False is a full output buffer, which the next call tries again.
  if queued == nil then
    state.linkGeneration = 0
    return 0
  end
  if queued == true then state.linkPingSent = true end
  return nil
end

--- The top of the headroom scale below, in dBm: a reading this strong or stronger counts as
--- the whole window. It is a convention of the scale rather than a figure of ExpressLRS's, and it
--- is the one the Urban theme's link bars already draw with (themes/urban/layout.lua, RSSI_TOP).
LinkRates.HEADROOM_TOP = -40

--- How much of the window between the air rate's sensitivity floor and HEADROOM_TOP a signal
--- reading still has above the floor, in whole percent, 0 to 100: 0 at the floor, where
--- ExpressLRS expects the receiver to stop decoding, 100 at HEADROOM_TOP and above.
---
--- `rssi` is a reading in dBm as EdgeTX carries it (negative), `floor` the `floor` of a row of
--- the tables above. Nil without a reading -- 0 is what the sensors read once their value has
--- aged out -- and without a floor, because a headroom against a guessed floor is a wrong number
--- with a percent sign. Rounded down, as the Urban bars round it, so a spoken figure and a drawn
--- one agree.
function LinkRates.headroom(rssi, floor)
  if type(rssi) ~= "number" or rssi == 0 then return nil end
  local top = LinkRates.HEADROOM_TOP
  if type(floor) ~= "number" or floor >= top then return nil end
  local reading = rssi
  if reading > top then reading = top end
  local pct = 100 * (reading - floor) / (top - floor)
  if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
  return math.floor(pct)
end

--- Where a signal-to-noise reading sits between the rate's two dynamic-power thresholds, in
--- whole percent, 0 to 100: 0 at or below `snrUp`, where ExpressLRS asks for more power, 100 at
--- or above `snrDn`, where it asks for less.
---
--- `snr` is an `RSNR` or `TSNR` reading in dB, `row` a row of the tables above. Nil without a
--- reading and on a row that carries no thresholds (FLRC and FSK rates, which report no SNR, and
--- the 3.x rates whose thresholds depend on the band). Unlike an RSSI reading, 0 is a reading
--- here: it is a real signal-to-noise ratio, and on some rates it is the threshold itself.
--- Rounded down, as LinkRates.headroom is.
function LinkRates.snrPercent(snr, row)
  if type(snr) ~= "number" or type(row) ~= "table" then return nil end
  local up, dn = row.snrUp, row.snrDn
  if type(up) ~= "number" or type(dn) ~= "number" or dn <= up then return nil end
  local pct = 100 * (snr - up) / (dn - up)
  if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
  return math.floor(pct)
end

--- One decibel in points of LinkRates.snrPercent's scale on `row`, rounded up, or nil where the
--- row has no thresholds. ExpressLRS reports the SNR in whole dB, so this is the smallest step a
--- reading can take on that rate's scale.
function LinkRates.snrPointsPerDb(row)
  if type(row) ~= "table" then return nil end
  local up, dn = row.snrUp, row.snrDn
  if type(up) ~= "number" or type(dn) ~= "number" or dn <= up then return nil end
  return math.ceil(100 / (dn - up))
end

--- Do these two readings prove the receiver has a second antenna?
--
-- `secondRssi` is the `2RSS` sensor and `antenna` is `ANT`, both straight off the frame.
--
-- The `ANT` field is present in every link-statistics frame and a receiver with one antenna
-- reports a constant 0 in it, so the field existing proves nothing at all. What proves a
-- second antenna is a reading only a second one can produce: an uplink RSSI for antenna 2,
-- or `ANT` naming antenna 2 as the one in use.
--
-- Both follow from how the two fields are filled. At the receiver: two radios write both RSSI
-- fields on every packet; one radio with a switch writes whichever field belongs to the antenna
-- it is on and moves the antenna field with it; one antenna writes the first field only and
-- leaves the second at nought (ExpressLRS 4.1.0, src/src/rx_main.cpp:243-278,
-- `getRFlinkInfo`). The transmitter then passes both on to the radio unchanged but for the sign
-- -- `linkStats.uplink_RSSI_2 = -(ls->uplink_RSSI_2)` and
-- `linkStats.active_antenna = ls->antenna` (src/src/tx_main.cpp:146 and :154, in
-- `LinkStatsFromOta`) -- and negating nought leaves nought. So a non-zero `2RSS` and a non-zero
-- `ANT` are each sufficient, and neither is necessary on its own.
--
-- The `ANT` half rests on the field being counted from nought -- the specification spells it
-- "Diversity active antenna ( enum ant. 1 = 0, ant. 2 )" -- and `2RSS` is the half that does not.
-- A link that numbered the antennas from one would make a receiver with a single antenna look
-- like a receiver with two, which is why the test is `~= 0` and never `== 1`: whatever the
-- numbering, nought is the value that means nothing has been proved.
function LinkRates.provesDiversity(secondRssi, antenna)
  if type(secondRssi) == "number" and secondRssi ~= 0 then return true end
  if type(antenna) == "number" and antenna ~= 0 then return true end
  return false
end

--- The diversity flag after one more pair of readings: 1 proved, 0 not proved, nil not yet
--- reported.
---
--- `latched` is what the last pass concluded. The flag only ever rises, because a receiver with
--- one radio and a switch spends most of its packets on one antenna and a pass that sees only
--- the first is not evidence against the second. What clears it is a new receiver, and that is
--- the caller's business rather than this rule's.
---
--- Nil is kept until one of the two fields has answered. `ANT` is in every link-statistics
--- frame, so a receiver reporting nothing at all is a different state from a receiver reporting
--- one antenna, and reporting the second as the first would be a claim about hardware nobody
--- has heard from.
function LinkRates.latchDiversity(latched, secondRssi, antenna)
  if latched == 1 then return 1 end
  if LinkRates.provesDiversity(secondRssi, antenna) then return 1 end
  if type(secondRssi) == "number" or type(antenna) == "number" then return 0 end
  return latched
end

return LinkRates
