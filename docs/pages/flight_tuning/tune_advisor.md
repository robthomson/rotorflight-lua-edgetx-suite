---
title: Tune Advisor
sidebar_label: Tune Advisor
sidebar_position: 30
---

# Tune Advisor

While you fly in rate mode, the flight controller measures how the heli answers the sticks. This page reads
those measurements and suggests one change at a time for each axis. It changes nothing by itself: make the
change on *PIDs*, *Rates* or *PID Controller*, fly again and come back.

The flight controller counts only rate flight while spooled up and airborne, with the heli moving on some axis.
Time in Angle, Horizon, Trainer, Altitude hold, Rescue, GPS rescue or failsafe is left out. The data builds up
over several flights and clears on its own when you change the PIDs, the I-term relax cut-off, the PID mode, the
rates or the active profile. A useful set is about ten seconds of rolls, flips and pirouettes with the stick
centred after each one. The measurements live in the flight controller's memory and are lost at power-off.

## Where to find it

*Configuration* → *Flight Tuning* → *Tune Advisor*

Needs MSP API 12.10; greyed out on an older flight controller. Read-only while the model is armed.

The page refreshes every 2 seconds. A flight controller that does not know the Tune Advisor command -- a 12.10
firmware from before it, or a board built without it -- shows "Needs newer firmware", and the page stops asking;
Reload asks again. When the link drops for a moment, the last measurements stay on screen until the next answer.

## Settings

| Line | What it shows |
| --- | --- |
| Axis | Roll, Pitch or Yaw. Everything below is for the chosen axis. |
| Flight data | Minutes and seconds of rate flight measured, and whether measuring is happening now (collecting) or not (paused). |
| Response | How fast the heli turns compared with the rate the stick asks for, for example "53% faster than asked". "Needs more flying" shows how much data is still needed; "Too uneven to judge" means the response varies too much. |
| Stops | How much the heli bounces back after you centre the stick, as a share of the turn rate. Needs 10 stops. |
| Suggested changes | Up to three changes, each named by the page, row and column to change, in the units that page shows, for example *PIDs > Roll > FF: 100 -> 80* and *Rates > Roll > Max Rate: 720 -> 900*. |
| Why | The reason for each change, and a fact worth knowing when there is room (for example how much faster the heli turns at high collective). |
| * (header) | Clears the measurements on the flight controller after asking to confirm. |

The suggestions follow these rules:

- **Turns faster or slower than asked** (more than 15% off): change FF and the rates by the same amount in
  opposite directions, so the stick feel stays the same but the heli flies the rate you ask for. One step
  changes FF by at most 20%. With Actual, Quick and Rotorflight rates the page gives the exact rate values;
  with the other rate types it gives a percentage. An axis with FF set to 0 (often the tail) gets no FF advice.
- **Full stick asks for more rate than the heli reaches** (roll and pitch), with the cyclic at its limit: lower
  the rates to what the heli reaches.
- **Stops bounce back 12% or more**: if the I-term pushes back, lower *Advanced > PID Controller > Cut-off point*
  by 20%. If FF does not match yet, fix FF first. Otherwise the controller is barely braking the stop: raise P
  by 20% (or add B).

## Notes

- The names in a suggestion are the ones the target page shows. Which rate columns are named depends on the
  rate type: *Center Sens* and *Max Rate* for Actual, *RC Rate* and *Max Rate* for Quick, *Rate* for Rotorflight.
- With polar cyclic rates (*Advanced* → *Rates (Advanced)* → *Cyclic Behaviour*), the *Rates* page shows one
  *Cyclic* row that sets Roll and Pitch together, so a suggestion naming Roll or Pitch is made on that row and
  changes both axes.

## Related

- [Rates](rates.md)
- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite 0.1.7.*
