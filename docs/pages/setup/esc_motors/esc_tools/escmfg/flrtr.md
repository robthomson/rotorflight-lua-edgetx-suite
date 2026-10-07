---
title: Flyrotor Configurator
sidebar_label: Flyrotor
sidebar_position: 40
---

# Flyrotor Configurator

Reads the parameter block out of a Flyrotor ESC and writes it back, so the ESC can be set up
from the radio instead of from a computer. A pilot opens it to check or change the cell
count, the protections, the startup behaviour and the ESC's own governor without unplugging
anything.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Tools* → *Flyrotor*

Lit only while the flight controller reports this ESC telemetry protocol. Read-only while
the model is armed.

## Settings

The page opens on a safety notice, and behind it on a summary of the ESC's model, firmware
and version. *Section* switches between three groups of settings; every setting of the
chosen group is always shown.

| Setting | What it does |
| --- | --- |
| Section | *Basic*, *Advanced* or *Governor*. Switching it rebuilds the list below; nothing is read from the ESC again. |

### Basic

| Setting | What it does |
| --- | --- |
| Cell Count | The battery's cell count as the ESC assumes it, 4 to 14. |
| Low Voltage Protection | The voltage the low-voltage protection acts on, 2.8V to 3.8V in 0.1 V steps. |
| Temperature Protection | The temperature the protection acts on, 50 C to 135 C in five-degree steps. |
| BEC Voltage | The BEC output: *Disabled*, *7.5V*, *8.0V*, *8.5V* or *12.0V*. |
| Electrical Angle | *Auto*, or a fixed 1 deg to 10 deg in one-degree steps. |
| Motor Direction | *CW* or *CCW*. |
| Starting Torque | 1 to 15. |
| Response Speed | 1 to 15. |
| Buzzer Volume | 1 to 5. |
| Current Gain | A correction applied to the ESC's current figure, -20 to 20 in steps of 1. |
| Fan Control | *Automatic*, *Always On* or *Always Off*. |

### Advanced

| Setting | What it does |
| --- | --- |
| Auto Restart Time | 0 s to 100 s in one-second steps. |
| Restart Acc | 1 to 10. |

### Governor

| Setting | What it does |
| --- | --- |
| ESC Mode | Which governor runs the head speed: *ESC Gov*, *Linear Throttle* or *RF Gov*. |
| Soft Start | 5 s to 55 s in one-second steps. |
| Governor P | The ESC governor's P gain, 0 to 100. |
| Governor I | The ESC governor's I gain, 0 to 100. |

## Notes

- The page opens behind a safety notice asking for the main and tail blades to be removed
  before the ESC is configured. Nothing else is drawn until the notice is dismissed.
- Saving writes the whole parameter block to the ESC, not only the settings that were
  changed. A setting the page does not offer is written back as it was read, so a Save with
  nothing edited changes nothing in the ESC.
- The ESC is read when the page opens, and again on *Reload*, which also drops any unsaved
  edit. Switching *Section* does not read it again.
- An unsaved edit is marked below the list, and is lost if the page is left without saving.
- If the ESC does not answer the write, the page says so and the edits stay marked as
  unsaved.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/) -- what each of these
  settings does inside the ESC, and how the ESC's own governor relates to the flight
  controller's.

*Documented against RFSuite 0.1.7.*
