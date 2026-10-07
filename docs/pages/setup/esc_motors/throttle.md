---
title: Throttle
sidebar_label: Throttle
sidebar_position: 10
---

# Throttle

Which signal the flight controller sends to the speed controller, and the pulse limits that
signal uses. Saving reboots the flight controller.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *Throttle*

Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Throttle Protocol | The output protocol. *PWM*, *ONESHOT125*, *ONESHOT42*, *MULTISHOT*, *BRUSHED*, *DSHOT150*, *DSHOT300*, *DSHOT600*, *PROSHOT*, and *DISABLED* to stop driving the motor output at all. *CASTLE* is offered on MSP API 12.08 and later, *SRXL2* on 12.10 and later; a flight controller older than that does not have them. |
| Update frequency | Output rate for the unsynchronised PWM protocols. 50 to 8000 Hz, default 250. Greyed out for the DSHOT and PROSHOT protocols and for *DISABLED*. |
| Motor Stop PWM Value | Pulse width sent while the motor is stopped. 50 to 2250 us, default 1000. Same condition as above. |
| 0% Throttle PWM Value | Pulse width at zero throttle. 50 to 2250 us, default 1070. Same condition as above. |
| 100% Throttle PWM Value | Pulse width at full throttle. 50 to 2250 us, default 2000. Same condition as above. |
| Unsynced ESC Update | Sends the output at a fixed rate instead of synchronised to the control loop. Available for the ONESHOT, MULTISHOT and BRUSHED protocols. |

## Notes

- **The protocol list is the flight controller's own, and which entries it has depends on the
  MSP API version the board reports.** The value written is the position in that list, so an
  entry the board does not have would not merely be unusable — it would shift every protocol
  behind it, and the page would write one protocol's number while showing another's name.
  *CASTLE* and *SRXL2* were each added to the firmware in front of *DISABLED*, which is why
  *DISABLED* does not always have the same number and why the list is built per board rather
  than written down once.
- A protocol the board reports that this build has no name for is shown as an unknown value
  and cannot be selected; that is a flight controller newer than the suite.
- Saving sends the settings and then reboots the flight controller, so the link drops and
  comes back. Once the settings are stored the notice can be closed and the page left; the
  outcome is then shown the next time the page is opened. The page also reads again if a
  different flight controller answers while it is open. Both are described in
  [Saving configuration](../../../reference/saving.md).

## Related

- [Saving configuration](../../../reference/saving.md) — the save that restarts the flight
  controller, and what a different flight controller does to an open page.
- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite 0.1.7.*
