---
title: Settings
sidebar_label: Settings
sidebar_position: 40
---

# Settings

The suite's logging and diagnostics switches: how much it logs, where the log goes, and whether
the configuration tool shows and logs its own memory use. These are the settings a report is
usually asked for with; [Collecting logs for a report](../../troubleshooting/collecting-logs.md)
says what to set and which files to attach.

## Where to find it

*System* → *Developer* → *Settings*

Not listed at all until *Developer Tools* is switched on under *System* → *Settings* →
*General*.

## Settings

| Setting | What it does |
| --- | --- |
| Debug Level | How much is logged: *OFF*, *ERROR*, *WARN*, *INFO*, *DEBUG* or *TRACE*, default *OFF*. Errors, warnings and most info lines are logged at every level, *OFF* included: they go to the in-memory list under *Session Logs* and, with *Log Session To Card* on, to the card. The level decides what is added on top: *DEBUG* adds the steps in between, *TRACE* also the raw bytes of every request to and reply from the flight controller. A few info lines, and the log lines printed to the radio's debug output or sent to the serial port, appear only once the level is raised to them. |
| Continuous Memory Log | The configuration tool logs its Lua memory once a second as an info line: what it holds, the peak, and what is left where the radio reports it. Off by default. |
| Show Header Memory | Shows the configuration tool's Lua memory, `LUA: <n>KB`, in the page header. Off by default. |
| Enable Serial Debug | Also sends every log line the debug level lets through to the radio's serial port. At *OFF* that is none. Off by default. |
| Log Session To Card | Writes the log to `/SCRIPTS/TOOLS/rfsuite.user/logs/` on the card. Off by default. On its own it already writes the configuration tool's `tool_*` and the widgets' `widget_*` files with errors, warnings and info; the background decoder's `function_*` files also need the debug level at *DEBUG* or above. |

Nothing changes until *Save* in the header is pressed.

## Related

- [Collecting logs for a report](../../troubleshooting/collecting-logs.md) — the files on the card
  and which of them to attach.
- [Session Logs](../tools/diagnostics/session_logs.md) — the in-memory list.

*Documented against RFSuite 0.1.7.*
