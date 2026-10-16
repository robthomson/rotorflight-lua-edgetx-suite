---
title: Rescue
sidebar_label: Rescue
sidebar_position: 100
---

# Rescue

Announces the start and the end of the flight controller's rescue, once each and without
vibration. Both announcements are off until switched on here.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *Rescue*

Always available.

## Settings

| Setting | What it does |
| --- | --- |
| Rescue Active | Speaks "Rescue -- Active" once when a rescue starts, whichever phase it starts in. Off by default. |
| Rescue Off | Speaks "Rescue -- Off" once when the rescue is over and the flight controller is back to normal control. Off by default. |

Both are radio-wide: one setting for every model. The two are independent, so either
announcement can be had without the other.

## Notes

- The state is read from the *Rescue State* sensor (92), or from *System Status* (120) where the
  flight controller does not send the first; select either under *Configuration* → *Setup* →
  *Telemetry* (*System Status* is offered there on MSP API 12.10 and later). With neither,
  nothing is spoken.
- Only a change of state is spoken. A model that connects during a rescue, or a switch turned on
  during one, does not announce it as just begun; its end is announced.
- The phases of a rescue (pull-up, flip, climb, hover, exit) are not spoken one by one; the
  current phase is shown under *System* → *Tools* → *Diagnostics* → *System Status*, which
  decodes it from the *System Status* sensor only.
- The announcements do not wait for the model to be armed. A flight controller with rescue
  enabled enters it whenever the switch assigned to it is on, so flicking that switch with the model
  disarmed on the bench speaks both announcements, which checks the switch.
- When the announcements are made, and the files they play, are on
  [Audio Events](../../../../audio/events.md).

## Related

- The rescue itself is configured under *Configuration* → *Flight Tuning* → *Advanced* →
  *Rescue*.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite 0.1.7.*
