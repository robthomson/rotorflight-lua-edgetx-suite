---
title: Urban theme
sidebar_label: Urban theme
---

# Urban theme

*Urban* is a dashboard theme that draws its own screen from code instead of a grid of boxes, and
takes full screen for itself. It is shipped as a worked example of two things a theme can do —
[take fullscreen](../developer/dashboard-themes.md#a-theme-that-takes-fullscreen) and declare
the telemetry it reads — and **it is a demonstration, not a finished theme**: the gaps it has
are listed at the end of this page.

## Where to find it

*System* → *Settings* → *Dashboard* → *Design*: choose *Urban* for a flight phase, or for all
three. Its settings are under *System* → *Settings* → *Dashboard* → *Settings* → *Urban*, split
into five pages: *Look*, *Value Rows*, *Top Bar*, *Keys* and *Telemetry*. They are stored for the radio, and a model
can carry its own under [*Per-Model Settings*](../pages/settings/dashboard/overrides.md) where
per-model settings are switched on. On both pages its tile carries an icon of its own, a small
picture of its flight screen with the battery gauge in the middle. Its words come from the suite's
translations, like every other theme's, so it speaks the language of the package that was installed.

## What it shows

**On the ground and in flight** one screen, which does not change shape at spool-up:

- **Top bar** — in full screen two buttons at the left, the menu and the tool, then the clock; up to four stacked
  link bars in the middle (the receiver's link quality *RQ*, the transmitter's *TQ*, and the
  signal of each receiver antenna as headroom above the sensitivity floor of the air rate the
  link runs, the second antenna only once one has been seen); the radio's battery at the right.
- **Left panel** — the model picture, the flight count and total flight time, the governor state
  and the throttle, a status line, and the PID, rate and battery profile numbers.
- **Middle** — a vertical battery gauge with the cell count, the fuel percentage and the capacity
  used. Until the model has reported a fuel reading the gauge is empty and reads `--%` rather
  than an empty pack.
- **Right panel** — five value rows, each chosen on the *Value Rows* page.
- **Bottom bar** — the model name, the arm state, the transmitter power and the skipped-frame
  count. While the flight controller names reasons that block arming, the whole bar shows them
  one at a time instead.

The **status line** says, worst news first: the main pack lost while the flight controller still
answers, the arming-disable reasons while disarmed, the speed controller's live verdict where the
controller reports one, and otherwise *No telemetry*, *Ready* or *Armed - OK*.

**After a flight** a statistics screen: the clock and the radio battery across the top, the model
with its totals, and a table of the last flight — cell voltage, headspeed on PID profiles 1 to 3,
current, ESC temperature, BEC voltage and voltage sags — each with the latest reading, the
flight's minimum and its maximum. Beneath it the flight time and the capacity used, and a bar
with the transmitter power, the lowest link quality, the highest MCU temperature and the
skipped frames. The header of the table says *Disconnected* once the flight controller has
stopped answering.

## Full screen

With *Urban* selected, full screen shows the theme itself rather than the quick menu. The theme
draws no close button: a **long press on RTN** leaves full screen, which the radio always
allows. Four places on the screen open a page over it, and a fifth opens the suite's tool:

- **The menu button** at the left of the top bar opens the [quick menu](quick-menu.md); so do the
  page keys and TELE, left at their defaults.
- **The tool button** beside it opens the suite's tool inside the widget, as the quick menu's
  *MAIN MENU* does; so does SYS, left at its default. The tool opens only while the model is
  disarmed: while it is armed the button is drawn grey and a press does nothing.
- **The profile row** of the left panel (PID, rate and battery profile) opens *Profile & Tuning*:
  the in-flight tuning surface, or a note that it is not available now, and the model's battery
  profiles, the one in force in green. Pressing a profile makes it the one in force and the page
  stays open, showing whether the change is being sent, was done or failed.
- **The link bars** in the top bar open the *ELRS* link page: the link quality of receiver and
  transmitter and the signal of each antenna as bars with their figures, the transmitter power,
  the skipped frames, the air rate beside the title and the rate floor at the foot. The *Link view
  switch* on the *Top Bar* page opens the same page while the switch is in the chosen position, in
  full screen and in the widget's zone alike; in the zone it only shows.
- **The value rows** of the right panel open *Telemetry*: up to twelve readings as tiles, three to
  a row, chosen on the *Telemetry* page. Each tile shows the reading's name and figure and, under
  it, the least and the most the flight reached, `min .. max`. Those come from the flight record:
  the flight in progress where it has a value, the last flight otherwise, so the line is empty
  until the model has been armed once and covers the armed time only. Where the record keeps one
  side only it shows `-` for the other -- the MCU temperature and the power have a most and no
  least, the fuel a least and no most -- and a reading the record does not keep (ESC load, ESC
  status, air rate, rate floor) has no line at all.
- **The battery gauge** opens the *Battery* page. At the top, the cell voltage as a bar with the
  figure beside it, on a scale marked at the flight controller's own minimum, warning and full
  cell voltage, which are written out under it; the bar turns yellow at the warning voltage and red
  at the minimum. Below it the pack as a battery laid on its side, filling towards the terminal in
  the same steps and colours as the gauge on the flight screen, with the fuel figure in the middle,
  the cell count at the left end and the used capacity at the right. At the foot, the pack voltage,
  the lowest cell voltage of the flight and the reserve the fuel figure keeps back. The cell
  voltages are the pack voltage divided by the cell count, as on the flight screen: no telemetry
  carries each cell's own voltage. The limits and the reserve are read from the flight controller
  on connecting, and read *-* until they have been. Like every other place that takes a press, the
  gauge has the radio's frame around it while *Frames on tap areas* is on. A key can open the page
  as well: choose *Theme: Battery* for it on the *Keys* page.

Urban draws these pages, the quick menu and the battery picker in the look of the screen they
open over, in its colour scheme: a plain page, a title up to a size larger than the top bar's
lettering with a thin line under it, buttons drawn as an outline with the choice in force in green, and a large **X** at the
top right that closes the page. The battery picker shows the packs in two columns from two packs up, each
with its name and a line with its capacity, its cycle count and the battery profile a pick selects
(*1100 mAh - 7 cycles - P2*; no profile where none of the board's matches the pack), and *NO BATTERY*
as a one-line row of its own at the foot, outlined in green where no pack is picked. Where
there are more packs than three rows hold, the packs scroll -- swipe them, or turn the rotary
encoder, which moves from pack to pack -- while *NO BATTERY* stays at the foot, so every pack can
be picked. RTN closes a page as well.

What the page keys, MDL, SYS and TELE do in full screen is chosen on the *Keys* page. Left at
their defaults, the page keys and TELE open the quick menu, SYS opens the suite's tool and MDL does
nothing; outside full screen MDL, SYS and TELE open the radio's own menus as always. A key set to
open a page closes that page again when pressed while it is showing, so a second TELE closes the
quick menu. A key set to the tool does nothing while the model is armed. MDL, SYS and TELE do
nothing while another page is on top. A radio without one of these keys simply never uses its
setting.

## Settings

| Page | Setting | What it does |
| --- | --- | --- |
| Look | Colour scheme | *Light* (default) or *Dark*. |
| Look | Arm state colours | *Green and red* (default): armed green, disarmed red. *Amber and grey*: armed amber, disarmed in the label colour. |
| Look | Frames on tap areas | *On* (default) shows the radio's own frame, light blue in its default theme, around every place on the full screen that takes a press. *Off* covers it; the outlines Urban draws itself stay, the choice in force stays green, and a place reached with the rotary encoder still shows the radio's focus frame. |
| Value Rows | Row 1 … Row 5 | The value each row of the right panel shows: cell voltage, voltage, headspeed, current, ESC temperature, MCU temperature, BEC voltage, power, throttle, fuel, capacity used, altitude, link quality, ESC load, ESC status, air rate, rate floor, one of the telemetry sensors listed under [What it reads](#what-it-reads), or nothing. Defaults: cell voltage, headspeed, current, ESC temperature, BEC voltage. |
| Value Rows | Units beside the values | *Off* (default) gives the width to the figures. |
| Value Rows | Temperature colours | Colours the ESC and MCU temperature rows. *Off* (default); *Standard*: ESC amber from 90 °C and red from 110 °C, MCU from 75 °C and 90 °C; *Early*: each 10 °C lower. |
| Top Bar | Clock | *Time only* (default) or *Date and time*. |
| Top Bar | RQ bar, TQ bar, RSSI bars | Each link bar on or off. On by default. |
| Top Bar | Transmitter battery | The radio battery at the right end of the top bar. On by default. |
| Top Bar | Status bar: TPWR | The transmitter power in the bottom bar. On by default. |
| Top Bar | Colour the bars | *Always* (default) colours a good link green; *Only on warning* leaves it neutral until a bar drops to its warning step. |
| Top Bar | Link good above | Where the link-quality bars turn amber, 50 % to 90 %, default 80 %; they turn red thirty points lower. |
| Top Bar | Signal good above | Where the signal bars turn amber, 10 % to 25 % of the headroom, default 15 %; they turn red at half of it. |
| Top Bar | Link view switch | A switch position that shows the *ELRS* link page while it is held. None by default: the page then opens only by a tap on the link bars. |
| Keys | Key PAGE >, Key PAGE < | What each page key does in full screen: *Nothing*, *Suite: Quick menu* (default), *Theme: Tuning* (the *Profile & Tuning* page), *Theme: ELRS link* (the *ELRS* link page), *Theme: Telemetry* (the *Telemetry* page), *Theme: Battery* (the *Battery* page), *Suite: Main menu*, *Suite: Flight log* or *Suite: Exit full screen*. *Suite* marks what the dashboard does on every theme, *Theme* a page Urban draws itself. *Suite: Flight log* opens the suite's tool on its *Flight Log* page, as the quick menu's *FLIGHT LOG* does, and does nothing while that page's preview switch is off or the model is armed. |
| Keys | Key MDL, Key SYS, Key TELE | The same choice for these keys. Defaults: MDL *Nothing*, SYS *Suite: Main menu*, TELE *Suite: Quick menu*. |
| Telemetry | Tile 1 … Tile 12 | The reading each tile of the *Telemetry* page shows, from the same list as the value rows, or nothing; a tile set to nothing is left out and the others close up. Defaults: voltage, cell voltage, current, capacity used, fuel, headspeed, ESC temperature, MCU temperature, BEC voltage, and tiles 10 to 12 off. The *Units beside the values* and *Temperature colours* settings apply to the tiles as to the rows. |

The cell voltage row turns red below the minimum pack voltage the widget works out for the
model — the cell count times the flight controller's minimum cell voltage — and the gauge, the
voltage rows and the status line turn red while the main pack is lost.

The radio draws the frame around every button a script creates, and a script can neither switch
it off nor change its colour, so *Off* covers it: the button gets square corners and lines in the
colour of the area lie over the frame.

## What it reads

Besides the fields every theme gets, the flight screen declares the transmitter's link quality
and power (`TQly`, `TPWR`), the air rate's sensitivity floor, whether a second antenna has been
seen, the skipped-frame count (`*Skp`) and the speed controller's live status, and whatever a
chosen value row or *Telemetry* tile needs (ESC load, ESC status, air rate, rate floor). The
*Telemetry* page names what its tiles need itself, so the widget reads those only while the page
is open; the ranges under the record's readings are read from the flight record.

A row or a tile can also show a telemetry sensor the widget has no reading of its own for, by the
name the suite's decoder gives it: BEC temperature (`Tbec`), tail speed (`Tspd`), vario (`Var`),
the transmitter's link quality (`TQly`) and power (`TPWR`), the ESC's own BEC temperature
(`BecT`), BEC current (`Ibec`), the ESC's voltage, current, capacity, RPM, PWM and load
(`EscV`, `EscI`, `EscC`, `EscR`, `EscP`, `Esc%`), GPS satellites, speed, altitude and distance
(`Sats`, `GSpd`, `GAlt`, `GDis`), pitch, roll and yaw (`Ptch`, `Roll`, `Yaw`), the flight
controller's CPU, system and real-time load (`CPU%`, `SYS%`, `RT%`), bus and MCU voltage
(`Vbus`, `Vmcu`) and the link's signal-to-noise ratio (`RSNR`). Such a sensor costs a sensor read
per telemetry pass: in a row for as long as the flight screen shows, on a *Telemetry* tile only
while the page is open. On a tile its range is the radio's own least and most of the sensor since
the last telemetry reset -- the sensor's `-` and `+` forms, two reads more -- because the flight
record keeps none of them. The statistics screen
declares nothing and reads the flight record. A reading the model does not carry shows `-`.

The skipped-frame count is published by the suite itself under the name `*Skp`
(`tasks/events/telemetry_bg/drain.lua`, `setTelemetryValue(0xEE02, …, "*Skp")`), and `*Skp` is
the name the theme declares and reads. The `Skp` in `common.lua`'s label table is only the word
drawn beside the number; a bare `Skp` is declared nowhere on purpose, because nothing creates a
sensor of that name and a declared name that is absent is still searched for.

## What it does not do yet

- **Priced only with the accounting fix that settles a free-form theme.** `bin/accounting/budgets.lua`
  carries a `theme.urban` row, measured with that fix; without it `bin/accounting/measure.lua`
  never settles a dashboard drawing this theme.
- **No colour for a pack that was not full when it was plugged in.** The gauge is green above
  20 %, yellow at 20 % and below and red at nothing left. Telling a part-used pack apart needs a
  verdict taken at the connect, and a theme has no pass of its own to take it in.
- **The transmitter power on the statistics bar is the last reading, not the flight's maximum**:
  the flight record keeps no transmitter power.
- **The arming-disable names cover bits 0 to 25**, named the same whatever MSP API version the
  flight controller runs.
- **Only the menu and tool buttons, the profile row, the link bars and the value rows take a press.**
  The gauge and the status line open nothing.
- **The *Telemetry* page shows the flight record's extremes for the readings the record keeps**,
  covering the armed time only, and the radio's own since its last telemetry reset for a raw
  sensor -- two different spans on one page.
- **A copy in the user folder draws with the shipped files**: its settings are its own, but its
  phase modules load `layout.lua` and `common.lua` from the shipped folder.
- The *Transmitter power*, *TQ* and skipped-frame cells read `-` on a link that does not report
  those sensors.

## Related

- [Dashboard themes](../developer/dashboard-themes.md) — the manifest keys, `fullscreen`,
  `sources` and the settings pages this theme uses.
- [Quick menu](quick-menu.md) — what opens over the theme in full screen.
- [User themes](user-themes.md) — copying a theme to the card.

*Documented against RFSuite 0.1.7.*
