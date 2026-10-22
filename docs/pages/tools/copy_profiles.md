---
title: Copy Profiles
sidebar_label: Copy Profiles
sidebar_position: 10
---

# Copy Profiles

Copies one PID profile or one rate profile of the flight controller over another, so a tune that
works can be taken as the starting point for the next one. The copy happens on the board and is
written to its EEPROM straight away.

## Where to find it

*Tools* → *Copy Profiles*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Type | Which kind of profile is copied: *PID* or *Rate*. The board counts the two kinds separately, so changing this may change how many profiles the two lists below offer. |
| Source | The profile that is read. Its settings are not changed. |
| Destination | The profile that is written. Everything it held is replaced by the source. |

Both lists offer the profiles the flight controller reports it has, and the two kinds are counted
separately: a board built with 256 kB of flash has three PID profiles and six rate profiles, and a
smaller one has two and three. A profile the board does not have is not offered, because the board
ignores a copy onto it and still answers as if it had been made. Until the flight controller's
status has been read, both lists offer six and SAVE is held: pressed before that, the save notice
asks for the read to finish, and RELOAD asks the board again. A choice beyond the board's profiles
-- made before its status arrived, or carried over from the other type -- is not moved to another
profile and is not sent: the list shows it as *Unknown (n)*, and the save notice asks to check the
choice and save again.

## Notes

**The copy cannot be undone.** The destination profile keeps nothing of its own settings, and there
is no copy of them anywhere: the suite does not read the destination before overwriting it, so
there is nothing to put back. SAVE therefore asks first, naming the profile that is about to be
overwritten and the one it is taken from, and it asks whether or not *Confirm on Save* is on under
*System* → *Settings* → *General*.

**A copy is not a profile change.** The flight controller keeps flying the profile it was already
on; to fly the one that has just been written, switch to it under *Tools* → *Select Profile*. The
exception is copying **onto the PID profile that is currently active** while the model is
disarmed, which the board applies straight away.

**Source and destination must differ.** SAVE is greyed out while both lists name the same profile,
which is how the page opens; pick a different destination and it comes back. A copy of a profile
onto itself that is asked for anyway is refused and says so.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite 0.1.7.*
