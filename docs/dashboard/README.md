---
title: Dashboard widget
sidebar_label: Dashboard
---

# Dashboard widget

The *RFSuite* widget renders a theme from live telemetry and switches between a preflight,
an inflight and a postflight layout as the flight progresses. What the README says about it
is the starting point; these files carry the detail.

| File | What it will say | Start from | Status |
| --- | --- | --- | --- |
| `widget-setup.md` | Adding the widget to a screen, sizing it, and what it shows in each of the three flight phases. | README, and the phase table in [developer/dashboard-themes.md](../developer/dashboard-themes.md) | to write |
| `themes.md` | The shipped themes (Default, RF Status, @AERC, @AERC Nitro, @RT-RC, @RT-RC Nitro, @SRB-RC, Urban) and choosing one under *System* → *Settings* → *Dashboard* → *Design*, per model and per flight phase. | in-app help of the Design page, and the resolution order in [developer/dashboard-themes.md](../developer/dashboard-themes.md) | to write |
| `theme-settings.md` | The per-theme settings page under *Dashboard* → *Settings*: the voltage range a theme's gauges span, stored for the radio, with per-model settings where they are switched on. | theme `configure.lua` sources | to write |
| [user-themes.md](user-themes.md) | Copying a shipped theme into `/SCRIPTS/TOOLS/rfsuite.user/dashboard/`, editing it, box styling, named colors, dynamic thresholds, and why a copy keeps its own settings. | nowhere yet | written |
| [developer/dashboard-themes.md](../developer/dashboard-themes.md) | For contributors: the same thing at source level — the manifest keys, what puts the widget into each phase, the grid and box vocabulary, the `configure.lua` factory, and what a theme shipped in this repository owes. | source | written |
| [urban-theme.md](urban-theme.md) | The Urban theme, a free-form theme shipped as a demonstration of a theme that takes fullscreen and declares the telemetry it reads: what it shows, the pages it opens in full screen, its five settings pages, and what it does not do yet. | theme sources | written |
| [quick-menu.md](quick-menu.md) | The fullscreen quick menu: how it is reached, its entries — erasing the blackbox, opening the in-flight tuning surface, the battery prompt, opening the suite's tool inside the widget, picking the battery profile — the close button, and the entry list it builds from. | source | written |
| [inflight-tuning.md](inflight-tuning.md) | The in-flight tuning overlay: what the interlock switch brings up on the ground, in the air and after landing, and how it drives the flight controller's adjustment functions through two global variables. | the two settings pages and the overlay sources | written |
| `model-image.md` | Where the model picture comes from, the per-cell-count variant and the accepted file types. | README | to write |
| `service-widget.md` | What *RFSuite Service* keeps alive when the tool is closed, and where to place it. | README | to write |
