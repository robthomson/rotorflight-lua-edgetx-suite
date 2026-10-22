---
title: MSP Speed
sidebar_label: MSP Speed
sidebar_position: 10
---

# MSP Speed

Measures how the MSP link to the flight controller performs: it sends a steady series of short
reads for a set time and counts how many were answered, how many timed out or had to be retried,
and how long an answer took.

## Where to find it

*System* → *Developer* → *MSP Speed*

Not listed at all until *Developer Tools* is switched on under *System* → *Settings* →
*General*. Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Duration | How long a test runs: 30, 120, 300 or 600 seconds, default 120. Taken when *Start* is pressed. |
| Start / Stop | *Start* runs the test; while it runs the button reads *Stop* and ends it early. |

## What it shows

| Row | What it shows |
| --- | --- |
| RF Protocol | The transport MSP runs over, for example `CRSF`. |
| Test Length | The duration of the current or last test. |
| Status | *Not running*, *Running* with the seconds done out of the total, or *Completed*. |
| Total Queries | Reads finished, answered or not. |
| Successful Queries | Reads the flight controller answered. |
| Timeouts | Reads given up because no attempt was answered (`max_retries`). A read the flight controller answered with an error reply is given up as `refused` and counts in *Total Queries* and *Last Error* only. |
| Retries | Repeated sends, summed over all reads. |
| Checksum Errors | Not counted in this version; it stays at 0. |
| Min / Max / Avg Query Time | Time from queuing a read to its answer, over the answered reads. |
| Last Error | The reason the most recent read failed, or `-`: `max_retries` (no answer), `refused` (an error reply), `cleared` (the read was dropped unanswered: the link went, or the test ended while a read was still out, which also counts it in *Total Queries*). |

While a test runs, a bar under the rows shows how much of it is done, and the rows are redrawn
once a second.

## Notes

- **The test reads, it never writes.** It cycles through three reads — the MSP API version, the
  flight controller version and its unique id — one at a time, a new one every 0.25 s over CRSF
  and every 0.35 s otherwise, and only once the previous one has finished. A read waits up to
  2.2 s for its answer over CRSF (2.4 s otherwise) before it is sent again.
- **Leaving the page stops the test**, and so does *Reload* in the header, which also clears the
  rows.

*Documented against RFSuite 0.1.7.*
