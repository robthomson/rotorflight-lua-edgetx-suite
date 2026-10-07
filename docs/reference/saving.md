---
title: Saving configuration
sidebar_label: Saving configuration
---

# Saving configuration

The **Save** action on a configuration page writes the values that page has read and edited.
A page can display initial values before the flight controller has answered; those values are
not a configuration that is ready to save.

On the pages listed below, Save requires a successful read of every record in the page load.
If loading is still running, failed, or returned data the parser rejected, Save reports **Not
saved** and explains that the complete configuration must be read first. It queues neither the
page writes nor the host EEPROM commit. Wait for loading to finish, or use **Reload** to try
again. A reload invalidates the previous completion until its own reads succeed.

The check also runs after a save confirmation, immediately before the deferred save executes.
A page change cancels that pending save and reports **Not saved**, asking you to return to the
page and save again. Arming continues to prevent FC writes. Both checks of the arming state use
the configured warning style: the notice, or the transient banner when the armed warning is
disabled. Local radio settings do not need an FC read and keep their existing save behaviour.

## Confirming a save

*Confirm on Save*, under *System* > *Settings* > *General*, puts a question in front of every Save.
It is on by default and can be switched off. Two things override it, and both ask whatever the
preference says.

The first is an arming state that cannot be read: the question is asked anyway, because the
alternative is writing to a flight controller that may be armed without anybody having been told
the check did not run.

The second is a page whose Save destroys something that cannot be read back afterwards. Such a page
supplies the words of the question itself, so that it names what is about to be lost instead of
only asking whether to save, and it requires the question rather than leaving it to the preference.
**Tools > Copy Profiles** is the one page that does this today: it asks which profile is about to be
overwritten and which one it is copied from, because the destination profile's tune is replaced and
nothing anywhere holds what was there before. Answering *No* writes nothing.

The re-checks described above are unaffected either way: the page, its read state and the arming
state are all checked again after the answer and immediately before anything is written.

## A save that restarts the flight controller

A save on Configuration, Alignment, GPS, Ports, Radio Config, and ESC/Motors RPM, Telemetry and
Throttle restarts the flight controller after writing; on Swash and Tail it does so when the swash
type or the tail mode was changed. While the settings are being written the page cannot be left.
Once the flight controller has confirmed they are stored, the notice can be closed and the page
left, and the save finishes on its own. Its outcome is shown the next time that page is opened, in
the same box a save reports in when it is watched to the end.

## When a different flight controller answers

Adjustments, Beepers, Blackbox, Failsafe and Stats under Setup > Controls, the four Governor pages,
both Servos pages, and ESC/Motors Motor Override, RPM, Telemetry and Throttle keep what they have
read while they are open. If the link drops and comes back from a different flight controller --
another board, or one reporting a different MSP API version -- such a page reads again. A link that drops and comes back to the same
board does not make it read again, so values edited and not yet saved stay on the page.

## Pages covered

- Flight Tuning: PIDs, Rates and Governor.
- Flight Tuning > Advanced: Autolevel, Filters, Main Rotor, PID Bandwidth, PID Controller,
  Rescue, Tail Rotor, and all three Rates Advanced pages.
- Setup > Alignment.
- Setup > Governor: General, Time, Filters and Curves.
- Setup > ESC/Motors: RPM, Throttle and Telemetry.
- Setup > Controls: Modes, Failsafe, Stats, both Beepers pages, and Blackbox Configuration
  and Logging.
- Setup > Power: Battery and Sources.
- Setup > Mixer: Swash, Swash Geometry, Tail and Trims.

A chained load must finish successfully even if an earlier error allowed the page to continue
reading other records. Previously read session values alone do not grant permission to save.
The page's existing parameter help and save/reboot sequence are otherwise unchanged.

The four Mixer pages show the values of their previous visit while they read again, and each
writes whole records -- the mixer configuration, and on Swash, Swash Geometry and Tail the mixer
inputs -- with the page's own fields laid over them. A save from a visit whose read did not
succeed would send an earlier visit's records, including settings another Mixer page has changed
since. The live write that Trims sends while the swash override is on, and Swash Geometry while
setup mode is on, waits for the same read: until it has succeeded, a changed value is shown and
not sent. Switching the override or setup mode on with the * button waits for it too -- the button
is disabled until the read has succeeded -- while switching either off is available at any time.

## ESC Configurator pages

*Setup* > *ESC & Motors* > *ESC Tools* opens one page per ESC firmware. These pages do not use
the shared Save action above; each writes the ESC's whole parameter block over MSP, not the
settings that were changed. Two rules follow from that.

A page reads the block only if it is that ESC's. The flight controller names the ESC family it
detected in the first byte of the block, and the *AM32*, *BLHeli_S*, *Bluejay*, *Flyrotor*,
*Hobbywing V5*, *OMP*, *Scorpion*, *XDFly*, *YGE* and *ZTW* pages -- all ten -- refuse a reply
from another family rather than decoding it with their own field list. BLHeli_S and Bluejay
report the same family, so those two decide on the ESC's main revision instead. A refused
read leaves the page on its own initial values; use *Reload* after selecting the page for
the ESC that is actually fitted.

On every ESC Configurator page, Save is refused until the read of the current visit has
succeeded, and reports the reason. A block that was never read cannot be written back: every
setting the page does not itself show would go to the ESC as zero. The page is kept between
visits, so a block read on an earlier one does not authorise a save on a later one: a read that
fails -- a different ESC, another *ESC Target*, an ESC that did not answer -- cannot be saved
from what the previous one sent. The settings on screen, the ESC's name and its firmware go back
to the page's own initial ones when the page is left as well, so a visit whose read fails does not
show the previous ESC's either.

The ESC Tools grid lights AM32, BLHeli_S and Bluejay together, because what lights them is the
ESC telemetry protocol, which all three share. Which of the three pages fits is still the
pilot's choice; on the BLHeli_S and Bluejay pages these checks make a wrong choice visible
instead of writing it to the ESC.

## Scope

The shared check protects the Save action from absent page data. It does not change wire
encodings, validate every field inside an accepted parser result, or alter the transport policy
for writes already queued. ESC encoding and telemetry-catalog issues have separate fixes.

Checked against RFSuite 0.1.7. Related: [issue 273](https://github.com/rotorflight/rotorflight-lua-edgetx-suite/issues/273).
