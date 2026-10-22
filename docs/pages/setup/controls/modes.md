---
title: Modes
sidebar_label: Modes
sidebar_position: 10
---

# Modes

The flight controller's mode ranges: each one switches a flight mode -- Arm, or any other the
flight controller reports -- on while an AUX channel of the radio is inside a window. The page
shows the ranges of one mode at a time and writes every range that was changed with a single
Save.

## Where to find it

*Configuration* → *Setup* → *Controls* → *Modes*

Read-only while the model is armed.

## Settings

The line below the mode shows how many ranges the selected mode has out of the flight
controller's slots (*Active ranges*), and whether there are unsaved changes.

| Setting | What it does |
| --- | --- |
| Mode | The flight mode whose ranges are shown, from the list the flight controller reports. |
| + Add | Adds a range to the selected mode in the first free slot: AUX 1, 1300 to 1700 µs. |
| Range | One row per range. The channel's live position is shown beside it, with a `*` while it is inside the window. *Set* takes the channel's current position, 50 µs either side, as the window, after asking. |
| AUX channel | The AUX channel the range watches, AUX 1 to AUX 13, or *AUTO*: move the switch you want and the page takes the AUX channel that moved. |
| Logic | *OR* or *AND*: how this range combines with the mode's other ranges. |
| Start / End | The window, 875 to 2125 µs in steps of 5 µs. |
| X | Deletes the range and frees its slot. |

## Notes

- Save writes each range that was changed, then one EEPROM write. A Save with nothing changed
  writes nothing.
- While the save runs the page is covered by its progress, so a range cannot be changed half-way
  through it; Save and Reload pressed in the header meanwhile do nothing.
- Reload reads every range from the flight controller again and discards every unsaved change.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite 0.1.7.*
