---
title: CRSF Sensors
sidebar_label: CRSF Sensors
sidebar_position: 55
---

# CRSF Sensors

What the flight controller hears from a CRSF sensor accessory — a GPS, a battery or voltage
sensor, a barometer or an RPM sensor that speaks the CRSF protocol and is wired to one of its
serial ports. The page to open when the accessory's values do not show up: it tells a port that
is not set up from a wire that carries nothing, and both from frames that arrive damaged.

## Where to find it

*System* → *Tools* → *Diagnostics* → *CRSF Sensors*

Greyed out until the flight controller answers. Needs MSP API 12.10; greyed out on an older
flight controller, which does not have this message. Read-only while the model is armed.

## What it shows

The page has no settings. It reads the flight controller's CRSF sensor status about once a
second while it is open, and the values change in place.

| Row | What it shows |
| --- | --- |
| Link | *Port enabled* when a serial port has the CRSF Sensors function and the flight controller opened it at boot, *Port disabled* otherwise. |
| RX bytes | Every byte the port has received since the flight controller started. Rising means something is on the wire. |
| RX sync bytes | Bytes taken as the possible start of a frame. Rising much faster than *CRC OK frames* means the bytes do not form frames — a wrong device or a wrong signal on the port. |
| CRC OK frames | Complete frames whose checksum was correct. |
| CRC fail | Complete frames whose checksum was wrong: damaged on the way. A count that keeps rising points at the wiring, a long or unshielded lead, or a wrong signal level. |
| Last frame type/len | The CRSF frame type of the last good frame, in hexadecimal, and its length in bytes. |
| GPS | *Receiving*, then latitude and longitude in degrees, ground speed, heading, altitude and the number of satellites. |
| Battery | *Receiving*, then voltage, current, the capacity used and the remaining charge in percent, as the accessory reports them. |
| Barometer | *Receiving*, then altitude and vertical speed. |
| Cell Voltages | *Receiving*, then the number of cells, the total of their voltages and one row per cell. |
| RPM | *Receiving*, then one row per value the accessory sends. |

A group the accessory has not sent reads *No data*. A group it stops sending turns back to
*No data* after the flight controller's sensor timeout, 2 seconds unless the CLI setting
`crsf_sensors_timeout_ms` says otherwise.

## Notes

- **The counters belong to the flight controller, not to the page.** They count from the
  flight controller's start and keep counting while the page is closed; what tells the story is
  whether they move while you watch.
- **A dash or *Waiting for the flight controller* means nothing has been read yet.** *No reply
  from the flight controller* replaces the values as soon as a read goes unanswered, rather than
  leaving numbers on screen that are no longer being refreshed; the page keeps asking.
- ***This firmware does not support the CRSF Sensors diagnostic.*** means the flight controller
  answered that it does not know the message: a firmware that reports MSP API 12.10 but was built
  before the CRSF sensor input was added. It also appears when the flight controller sends the
  record in a layout this suite does not know (a payload version other than 1), rather than
  showing numbers decoded from the wrong layout. The page asks once per visit; Reload asks again.
- **The function is assigned to a serial port of the flight controller.** Where this suite's
  [Ports](../../setup/ports.md) page (*Configuration* → *Setup* → *Ports*) offers *CRSF Sensors* in
  a port's function list -- it needs MSP API 12.10 -- set it there; otherwise the Rotorflight
  Configurator's Ports tab sets it. The port is opened when the flight controller starts.
- **What the readings are used for is set on the flight controller, not here.** The GPS values
  appear only on this page. With the voltage meter source set to CRSF, the battery voltage comes
  from the battery values, or from the total of the cell voltages when no battery values arrive
  (`crsf_sensors_battery_source` chooses); with the current meter source set to CRSF, current and
  capacity used come from the battery values. The barometer feeds the altitude with
  `crsf_sensors_use_baro` on, and the RPM values feed the motor RPM with `crsf_sensors_use_rpm`
  on. All three are CLI settings.
- **RPM arrives at telemetry rate, not at motor rate.** It is fine to look at; for the RPM filter
  or a governor mode that follows the head speed, bidirectional DShot or a dedicated RPM sensor
  tracks the motor far more closely.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite 0.1.7.*
