---
title: Logs
sidebar_label: Logs
sidebar_position: 20
---

# Logs

Lists the telemetry logs EdgeTX has written to the SD card and shows, for the one you pick, a
summary of the flight and a graph of up to four of its columns.

## Where to find it

*System* → *Logs*

Always available. The page reads the SD card only and does not talk to the flight controller.

EdgeTX writes a telemetry log only when logging is switched on for the model, with a Special
Function *SD Logs*. Without it there is nothing for this page to list.

## The list

The page searches `/LOGS/`, `/LOGS/rfsuite/` and `/LOGS/rfsuite/telemetry/`, each at its top
level and one folder down, and lists every `.csv` file it finds there that is a telemetry log,
newest first. *View* opens the summary of that log.

While it searches, the page shows how many folder entries it has read and how many logs it has
found so far. It shows no bar: how many entries a folder holds is not known before they have
been read, and reading them is most of the search.

The list shows 25 logs at a time. Scroll it by touch, or turn the rotary encoder to step from
one log's *View* to the next. Where there are more logs, *Previous* above the list and *Next*
below it show the 25 before or after, with which logs are shown out of how many beside them.
Coming back from a log's summary finds the list on the same 25.

The list is kept when you leave the page, so coming back shows it at once, on the 25 you left
it on. *Reload* in the header searches the card again and starts at the newest log; a log written
since the list was read appears only then. The tool holds on to only the last few pages you
opened, so after several other pages, or after leaving the tool, the page searches again.

A file whose name carries a date and a time, as EdgeTX names its logs
(`<model>-YYYY-MM-DD-HHMMSS.csv`), is listed without being opened. Any other `.csv` file is
opened, and is listed only if its first line begins with the `Date,Time` header EdgeTX writes;
a spreadsheet or another program's CSV file in the same folder is left out.

## The summary

| Row | What it shows |
| --- | --- |
| Flight Time | The time from the first to the last row of the log, and the number of rows. |
| Voltage | The battery voltage at the start, the lowest with the sag from the start, and at the end. |
| Current | The peak and average current, and the consumption: the last capacity reading, or the average current over the flight time where the log has no capacity reading. |
| Headspeed | The highest headspeed, and the lowest above 1000 rpm, both only while the motor is driving the head (armed, and throttle at 25 % or more or current at 1.5 A or more). |
| ESC Temp | The highest and the starting ESC temperature, and the highest throttle. |

Each figure is read from the column whose header names it -- `Vbat(V)`, `Curr(A)`, `Capa(mAh)`,
`Hspd(rpm)`, `EscT(°C)`, `Thr(%)`, `ARM` and their usual variants. A plain `Thr` column is the
throttle stick channel, not the throttle the flight controller reports, and is not used. **A figure whose column the log does not have is
shown as `--`.** That is what a log from a model without Rotorflight telemetry usually shows for
most rows: its first columns are link statistics, and none of them is taken for a flight value.

A log without an `ARM` column gives the headspeed rows nothing to tell armed from disarmed by, so
they then rest on throttle and current alone.

## The graph

*Graph* opens a plot of the log over time. Choose up to four columns, or one of the offered sets
(*Power*, *Battery*, *Link*, *Governor*, whichever this log can serve), and press *Show*. Zoom,
page and a cursor readout work on the plotted flight; where the log holds more than one flight,
the chooser also offers which one.

The graph needs the `Date` and `Time` columns and at least one row whose time it can read, written
the way EdgeTX writes it (`HH:MM:SS.mmm`). A file that lacks either says so instead of offering
columns: *Not an EdgeTX telemetry log* without the two columns, *No row carries a time the graph
can read* where no row's time has that form. The summary also reads a time without the
milliseconds, so such a file can have a summary and still no graph. A log without any data rows
has no summary, and its *Graph* button is not offered.

## Related

- [EdgeTX manual](https://manual.edgetx.org/) -- the *SD Logs* Special Function, which writes these files.

*Documented against RFSuite 0.1.7.*
