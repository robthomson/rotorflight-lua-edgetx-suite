---
title: Ports
sidebar_label: Ports
sidebar_position: 60
---

# Ports

Sets what each serial port of the flight controller is used for, and at what baud rate. A pilot
opens it to move a receiver, a GPS, an ESC telemetry line or a blackbox logger to another port.

## Where to find it

*Configuration* → *Setup* → *Ports*

Read-only while the model is armed.

## Settings

The page has one row per serial port the flight controller reports, up to twelve. The USB port is
not listed. Where the board layout is known, a row is named as the board prints it, with the UART
name in brackets (`Port A [UART4]` on an F7A1 board); otherwise it carries the UART name alone.
Each list a row opens is titled with that row's name.

| Setting | What it does |
| --- | --- |
| Function | What the port is used for: *Disabled*, *MSP*, *GPS*, *RX Serial*, *ESC Sensor*, *Blackbox*, *SBus Out*, *FBus Out*, *S.PORT Master*, *SRXL2 ESC*, *CRSF Sensors*, or one of the telemetry protocols (*FrSky*, *SmartPort*, *iBus*, *HoTT*, *MAVLink*, *LTM*). A function another port already uses is not offered, and only one port can carry telemetry. *SBus Out* needs MSP API 12.07, *FBus Out* and *S.PORT Master* need 12.09, *SRXL2 ESC* and *CRSF Sensors* need 12.10; on an older flight controller they are not offered. *CRSF Sensors* reads an external CRSF sensor, which [Power → Sources](power/sources.md) can then use for the pack voltage and current. A function this page does not know is shown as *Custom* with its number. |
| Baud rate | The speed of the port, offered as a list only where the function has more than one: *MSP* offers fixed rates from 9600 to 1000000, *GPS* and *MAVLink* offer *AUTO* and rates up to 460800, *Blackbox* offers *AUTO* and rates up to 2470000. Every other function is fixed at *AUTO*, which is shown as text, and a disabled port shows no rate. A rate already stored that is not in that list is still offered. When a new function does not allow the current rate, the rate moves to the first one it allows. |

The port that carries the receiver is marked *[RX]* and cannot be changed here: its function list
is greyed out, and a save keeps that port as it was.

## Notes

- **Save writes the ports you changed, stores the configuration and restarts the flight
  controller.** Once the flight controller answers again, the page reads the ports from it, so the
  rows show what the board holds -- including a configuration the flight controller rejected and
  reset to its defaults when it stored it. See [Saving configuration](../../reference/saving.md).
- *Reload* reads the ports from the flight controller again and discards unsaved changes.
- **A port set to *SRXL2 ESC* changes two other pages when it is saved.** The flight controller
  then drives the motor over that port and reads the ESC telemetry from it, so it sets the
  protocol on *ESC & Motors* → *Throttle* to *SRXL2*, and on *ESC & Motors* → *Telemetry* the
  protocol to *SRXL2* with *Half Duplex* on; *Pin Swap* there applies to this port. The port's
  speed is agreed with the ESC, so its baud rate stays at *AUTO*. Rotorflight 4.7 is needed.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite 0.1.7.*
