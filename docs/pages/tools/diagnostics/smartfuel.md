---
title: SmartFuel
sidebar_label: SmartFuel
sidebar_position: 50
---

# SmartFuel

One read-only screen that says which fuel estimate this model is using — the flight
controller's or the suite's own — what it is fed from, and what it reports. Open it when the
fuel reading on the dashboard does not match what you expect.

## Where to find it

*System* → *Tools* → *Diagnostics* → *SmartFuel*

Greyed out until the flight controller answers. Read-only while the model is armed. Needs MSP
API 12.09; hidden on an older flight controller.

## Settings

The page has no settings. It reads the flight controller's SmartFuel and battery configuration
over MSP when it opens, and the rest from this model's preferences and from telemetry.

| Row | What it shows |
| --- | --- |
| Protocol | The telemetry the page reads its sensors from: *CRSF / ELRS*, *FBus / S.Port* or *Simulator / MSP*. |
| Active mode | *Firmware* and the flight controller's source when it computes the estimate, otherwise *Local* and the source set in this model's preferences. |
| FBL / local | Both sources side by side; `n/a` for the flight controller's where it was not read. |
| Tuning source | *Firmware MSP* when the flight controller computes the estimate, *Local prefs* otherwise. |
| Fuel input | The fuel sensor the flight controller's estimate arrives on, or the local source. |
| Source mAh | The consumption sensor of that telemetry. |
| Smart Fuel | The suite's `SmFt` sensor. |
| Smart mAh | The suite's `SmCp` sensor. |
| Voltage slew, Charge slew, Sag gain | The voltage-mode tuning, from the flight controller when it computes the estimate, otherwise from the model's preferences. |
| Pack capacity | The capacity of the active battery profile. |
| Reserve alert | The reserve the fuel reading is measured against. |
| Reserve target | The fuel reading rescaled so that the reserve reads 0 %. |

A sensor that has no current value reads `-`.

## Notes

- **The values do not refresh by themselves.** The page draws what it had when it was opened, so
  that it can be scrolled; *Reload* in the header reads the configuration again and redraws.
- **The page logs what it reads.** A read that fails reaches the *Session Logs* page at any
  *Debug Level*; the start and end of each load and each read it queues and receives, from *DEBUG*
  up, so opening the page leaves nothing in the log while logging is off.

## Related

- [SmartFuel](../../setup/power/smartfuel.md) — where the flight controller's estimate is set.
- [Custom telemetry sensors](../../../reference/telemetry-sensors.md) — what `SmFt` and `SmCp` are
- [Rotorflight documentation: SmartFuel](https://doc.rotorflight.org/setup/smartfuel/)

*Documented against RFSuite 0.1.7.*
