---
title: Tune Advisor
sidebar_label: Tune Advisor
sidebar_position: 30
---

# Tune Advisor

While you fly in acro mode, the flight controller measures how the heli answers the sticks. This page reads
those measurements and suggests one change at a time for each axis. *Save* in the header lists the writable
changes for the shown axis and asks you to confirm. Fly again after applying them and come back.

The flight controller counts only acro flight while spooled up and airborne, with the heli moving on some axis.
Time in Angle, Horizon, Trainer, Altitude hold, Rescue, GPS rescue or failsafe is left out. The data builds up
over several flights. Clear it with *\** after confirming, or it clears at the next arming when the PIDs, the
I-term relax cut-off, the PID mode, the rates (type, RC rate, expo, S-rate), the PID profile or the rate profile
differ from the last arming. Nothing is cleared while you fly. A useful set is about ten seconds of rolls,
flips and pirouettes with the stick centred after each one. The measurements live in the flight controller's
memory and are lost at power-off.

## Where to find it

*Configuration* → *Flight Tuning* → *Tune Advisor*

Needs MSP API 12.10; greyed out on an older flight controller. Read-only while the model is armed.

The page refreshes every 2 seconds. A flight controller that does not know the Tune Advisor command -- a 12.10
firmware from before it, or a board built without it -- shows "Needs newer firmware", and the page stops asking;
Reload asks again. When the link drops for a moment, the last measurements stay on screen until the next answer.

## Settings

| Line | What it shows |
| --- | --- |
| #n (heading at the top) | The rate profile the advice is for. A profile switch with the page open is followed shortly after the radio sees the new profile. |
| Axis | Roll, Pitch or Yaw. Everything below is for the chosen axis. |
| Flight data | Minutes and seconds of acro flight measured, and whether measuring is happening now (collecting) or not (paused). |
| Response | How fast the heli turns compared with the rate the stick asks for, for example "53% faster than asked". "Needs more flying" shows how much data is still needed; "Too uneven to judge" means the response varies too much. |
| Stops | How much the heli bounces back after you centre the stick, as a share of the turn rate. Needs 10 stops. |
| Suggested changes | Up to three changes, each named by the page, row and column to change, in the units that page shows, for example *PIDs > Roll > FF: 100 -> 80* and *Rates > Roll > Max Rate: 720 -> 900*. |
| Why | The reason for each change, and a fact worth knowing when there is room (for example how much faster the heli turns at high collective). |
| * (header) | Clears the measurements on the flight controller after asking to confirm. |
| Save (header) | After confirmation, writes the suggested changes for the shown axis, saves to EEPROM and reads back the result. Available while connected and disarmed, with a known board ID and at least one writable change, and no apply already running. |

The suggestions follow these rules:

- **Turns faster or slower than asked** (more than 15% off): change FF and the rates by the same amount in
  opposite directions, so the stick feel stays the same but the heli flies the rate you ask for. One step
  changes FF by at most 20%. With Actual, Quick and Rotorflight rates the page gives the exact rate values,
  never beyond what the *Rates* page takes for that column; with the other rate types it gives a percentage. An axis with FF set to 0 (often the tail) gets no FF advice.
- **Full stick asks for more rate than the heli reaches** (roll and pitch), with the cyclic at its limit: lower
  the rates to what the heli reaches.
- **Stops bounce back 12% or more**: if the I-term pushes back, lower *Advanced > PID Controller > Cut-off point*
  by 20%. If FF does not match yet, fix FF first. Otherwise the controller is barely braking the stop: raise P
  by 20% (or add B).

The radio's own confirmation dialog lists the changes, with the No button first. After you confirm,
the page reads the current PID gains, PID profile settings and rates afresh. It refuses
without writing if a read fails, the model is armed, either profile or the tune differs from the advice,
the polar cyclic setting no longer matches, or a suggested value is outside its range. It also reads the
flight controller's own active PID and rate profile and checks both against the advice. Only fields that
actually change are replaced in copies of those replies: every other byte is written back exactly as read,
including any extra bytes at the end, and only messages carrying a change are sent. The shared save process
then commits to EEPROM without a reboot. The page reads the settings again and reports how many changes
were written and read back, or names the first field that differs.
If the settings cannot be read back, it reports that the save is unverified; if a profile changed during
the save, it asks you to check both profiles.

If saving fails, the page says what may still be active in RAM until a restart:

- "Saving failed. The changes are active until the flight controller restarts, then undone." means the
  EEPROM commit failed or timed out: the new values are active but were not stored. Restart the flight
  controller to undo them.
- "Writing failed. Nothing was saved: restart the flight controller to undo any part already sent."
  means a write failed or timed out before the EEPROM commit. Some values may already be active in RAM;
  restart the flight controller to restore the stored settings.

Betaflight, Raceflight and KISS rate suggestions are percentages, not exact values: Save writes neither
those rates nor the FF change paired with them. P and I-term relax cut-off suggestions remain writable.
FF and its paired rate changes are written together or not at all; if a rate stays unchanged at a limit,
none of them is written.

Once Save starts writing, the axis shows "Applied. Fly again to check the new settings." and offers no further
change on the same flight data, including after a failed write or EEPROM commit. Values may be active in RAM
until a restart, so a further step would build on them; the mark survives leaving the page and clears when
flight data changes at the next flight or is cleared with *\**. A different flight controller starts with its
own measurements.

## Getting a clean measurement

- A rate profile switch in flight clears nothing: the set then mixes both profiles, and the advice is worked
  out against the profile active when you look. Fly one profile per measurement.
- Switching polar cyclic on or off clears nothing either: it is not part of what the flight controller checks
  at arming. Clear once with *\** after toggling it.
- Fly, land, open the page, make one change, then fly again. The next arming starts a fresh set by itself when
  the tune changed.
- The advice and the check use the settings the flight controller holds now, and statistics clear only at
  the next arming, so a value changed by hand after landing is not detected; make changes by hand only
  after flying again.

## Notes

- The names in a suggestion are the ones the target page shows. Which rate columns are named depends on the
  rate type: *Center Sens* and *Max Rate* for Actual, *RC Rate* and *Max Rate* for Quick, *Rate* for Rotorflight.
- With polar cyclic rates (*Advanced* → *Rates (Advanced)* → *Cyclic Behaviour*), the *Rates* page shows one
  *Cyclic* row, which edits the Pitch rates. While polar is on, the flight controller applies that one curve
  to the whole cyclic stick, roll included, and a rate change on that row changes both axes in flight. The
  Roll rates are not changed by the row; they are kept as they were and apply again once polar is switched
  off. With polar on, Roll and Pitch rate suggestions name the *Cyclic* row and work from the Pitch rates;
  Save writes the Pitch rates for either axis.
  A Cyclic rate write marks both Roll and Pitch as applied until the flight data changes or is cleared.
  The page reads the polar setting after the first advisor answer, again when the active rate profile changes,
  and on Reload. Until the first read answers, or if it fails, suggestions name the per-axis rows as before;
  a later read that fails keeps the previous answer. The profile switch is seen through the radio's rate
  profile telemetry sensor, otherwise the profile known at connect is used. Without that sensor, a switch
  made on the transmitter is not seen: Reload reads the rates again, but the #n in the heading keeps the profile
  known at connect. Feed-forward and P/cut-off suggestions stay per axis.
  Roll and Pitch are still judged separately, so their cards can ask for different changes to the one *Cyclic*
  row: change it once, fly, and check both again.
- Each value committed by this page is appended to the flight controller's
  [change journal](../../reference/change-journal.md), at
  `/SCRIPTS/TOOLS/rfsuite.user/journal/<mcu id>.lua`, one line per value. Its time comes from the radio's
  clock and is only as right as that clock; the append order holds anyway. The file is append-only.
  A journal failure is reported with the save result; the changes already stored on the board stay stored.

## Related

- [Rates](rates.md)
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite 0.1.7.*
