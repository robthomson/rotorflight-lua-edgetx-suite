---
title: Blackbox Status
sidebar_label: Status
sidebar_position: 30
---

# Blackbox Status

What the flight controller's two blackbox storage media hold: the onboard dataflash and the SD
card, each with its state and how much of it is used. The page also erases the dataflash.

## Where to find it

*Configuration* → *Setup* → *Controls* → *Blackbox* → *Status*

Read-only while the model is armed.

## Settings

The page has no settings. It reads both media when it opens and again every two seconds.

| Row | What it shows |
| --- | --- |
| Dataflash | *Used x / y* of the onboard flash chip. *Not supported* when the flight controller reports no dataflash. *Erasing / busy...* while the flash is being erased or is otherwise not ready. |
| SD Card | *Used x / y* of the card. *Not supported* when the flight controller reports no SD card support, *No card*, *Initializing card...*, *Initializing filesystem...*, *Error (code n)* with the filesystem's last error, or *Unknown state (n)* for a state the page does not know. |

| Button | What it does |
| --- | --- |
| Reload | Reads both media again. Greyed out while an erase is running. |
| `*` | Erases the onboard dataflash, after asking. The page shows *Erasing dataflash...* until the flight controller has acknowledged the erase and then reports the flash ready again, and shows the usage after the erase; an erase the flight controller never acknowledges (the MSP queue gives up after its retries), or one that is dropped, ends the wait. Lit only when the flight controller reports a dataflash, and not while an erase is running. |

## Notes

- The erase is irreversible: every log on the dataflash is gone.
- The flight controller erases the flash only while the blackbox records to it (*Blackbox* →
  *Configuration*, device *Onboard Flash*). With another device it accepts the command and does
  nothing, and the page shows the same usage as before.
- Nothing is sent to the flight controller while the model is armed; an erase asked for then is
  dropped and the page returns to its rows.
- The quick menu of the dashboard widget has an *ERASE BLACKBOX* entry of its own; see
  [the quick menu](../../../../dashboard/quick-menu.md).

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite 0.1.7.*
