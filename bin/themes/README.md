# Theme checks

`validate.lua` checks a dashboard theme that takes fullscreen (`fullscreen = "theme"` in its
`init.lua`) for the duties [dashboard themes](../../docs/developer/dashboard-themes.md#a-theme-that-takes-fullscreen)
gives it, and the [views a theme registers](../../docs/developer/dashboard-themes.md#views-of-a-themes-own).
It runs offline, with desktop Lua 5.3, from the repository root:

```sh
lua5.3 bin/themes/validate.lua <theme folder>
lua5.3 bin/themes/validate.lua <theme folder> --size 480x272
```

The folder is a theme folder anywhere on disk — a shipped one under
`src/rfsuite/widgets/dashboard/themes/`, or a user theme copied off the card. The size is the
fullscreen size the theme is built at, `800x480` when omitted.

## What it does

Each phase module the theme declares is resolved the way the widget resolves it (`armed` falls
back to `preflight`, `offline` to `postflight`, a phase with no module to `widget.lua`), and each
distinct module is built once at the fullscreen size with a `ctx` that records what it is asked
to do. Every `press` in the tree the build returns is then fired, and `ctx.keys` is read once
the build and the presses have run.

A theme is **red** where:

| Finding | Why it matters |
| --- | --- |
| no press opens the quick menu (`openView:menu`, or a menu built through `ctx.menu`) | the menu is where ERASE BLACKBOX, BATTERY and the battery profiles are, and a touch radio has no other way to it |
| nothing leaves fullscreen | a way out is a press with `exitFullscreen`, or `ctx.keys.exit = "exitFullscreen"` — a short press on RTN, which every radio has — or `fullscreenExit = "longRtn"` declared in `init.lua`: the author relies on a long press on RTN, which always leaves fullscreen |
| a `rectangle` is drawn over a node that has a press | built in fullscreen, a rectangle takes the press and hands it to its parent, so it swallows every press that lands on it. A rectangle among the press node's own `children` is not over it: its parent IS the button, which the press then reaches |
| a press or a `ctx.keys` entry names an unknown action or view | the widget ignores it, so the control or the key does nothing |
| a `ctx.keys` entry is not `exit`, `pageDown`, `pageUp`, `mdl`, `sys` or `tele` | the widget answers no other key, so the binding does nothing |
| a build raises or does not return a node list | |

A tree that binds no press at all is green, because the widget then draws its own menu control
and X over it, and so is a declarative theme, which cannot bind one. A theme without the
`fullscreen` key is not checked for these.

## A theme's views

The `views` of a theme's `init.lua` are checked whether the theme takes fullscreen or not. Each
module is built once: a fullscreen view (`where` `"fullscreen"` or `"both"`) at the fullscreen
size with the recording `ctx`, its presses fired and held to the rules above, and a zone view
(`"zone"` or `"both"`) without a `ctx`, as the widget builds it. The records a view reaches
through `ctx.entry` and `ctx.list` are the widget's own, from `fullscreen_menu.lua`; `ctx.run`
looks the entry and the option up again by id among them, as the widget does, and records the
action that would follow rather than doing the work. A view is **red** where:

| Finding | Why it matters |
| --- | --- |
| an entry has no `id` or `module`, or a `where` that is not `"fullscreen"`, `"zone"` or `"both"` | the widget leaves it out |
| the module does not load, has no `build()`, or a build raises | the widget does not ask for it again, and the view never shows |
| a press runs, through `ctx.run`, an entry or an option the menu does not have | the widget refuses it, so the control does nothing |
| a zone view binds a press | a zone view is display only; a widget zone receives no touch |
| a zone view has no `openWhen` | nothing ever shows it |
| `openWhen` names a condition the widget does not have | it is false, so the view never opens |
| `openWhen` names a switch that is none of `SA` to `SR`, `SW1` to `SW6`, `FL1` to `FL4`, `L01` to `L64`, or a physical switch without `pos` (`"up"`, `"mid"`, `"down"`), or names switch `0` itself | the radio finds no such position, so the view never opens |
| `openWhen` reads a setting (`switch = { pref = "<key>" }`) that the theme's settings page does not name, or declares no `default` | the setting is never there to read |
| `openWhen` is a function that raises on the fixture state of any phase | on the radio it counts as false |
| `openWhen` is a function that costs more than **35 instructions** per call on the fixture state of any phase | it runs on every pass its view can be shown on |

**The 35** is what asking the costliest of the widget's own conditions costs, counted the same way
as the check counts (`debug.sethook`, one count per VM instruction, the counter's own empty call
taken back out) on the same fixture states: `batteryPickHasPacks` 35, `previewInflightTuning` 28,
and `batteryPickPending` — the one the widget asks on every fullscreen pass — 25. A theme's
condition is held to the widget's own. A simple test of the state, `state.armed == true and
(state.rss1 or 0) < -90`, costs 6.

**A number is a switch position**, as the widget reads it: what the radio's own switch picker
stores in a setting, taken as it is whatever `pos` says. So a numeric `switch`, or a numeric
`default` for a setting, passes, and a `default` of `0` passes too: it is the picker's "nothing
chosen yet", and the view then does not open on a switch until the pilot has picked one. Only a
`switch` that is `0` itself is red, since that view could never open on it.

**Where a setting must be named.** A setting is found by reading, for the key assigned as a table
key or a field (`key =`, `values.key =`; a read such as `cfg.key` or `cfg.key ==` does not count)
or as a quoted string, the source of the theme's settings page: the `configure` module
of `init.lua`, and every file of the theme's folder that it names as a `.lua` path, and those
files' in turn. Not the whole folder: `init.lua` names the key in the very `openWhen` being
checked, and a view that reads `themeConfig.<key>` names it too, so searching every file would find
every key and prove nothing; the page that stores a setting is what proves it exists.

What the check cannot see: a switch the pilot has renamed on the radio (the radio finds it, the
check does not know the name), and a setting the settings page names only as a key built from
parts, or in a file it reaches by a path built from parts.

Exit status: `0` green, `1` red — one line per finding, beginning `RED:` — and `2` when the theme
cannot be read.

## What it does not do

It does not look at the picture, and apart from a view condition's it does not measure cost: that
is `bin/accounting/measure.lua`. The firmware and the widget are stubbed in the file itself; the
state a build receives is a fixture of typical readings, so a theme that reads anything else sees
`nil`, as it may on a radio before the first telemetry arrives. It is not part of the CI
workflow.

## What a save reports

`verify_save_scope.lua` checks a theme's settings page for what it tells the pilot when it
saves. It runs offline, with desktop Lua 5.3, from the repository root:

```sh
lua5.3 bin/themes/verify_save_scope.lua              # the checks
lua5.3 bin/themes/verify_save_scope.lua --verbose    # and one line per case
lua5.3 bin/themes/verify_save_scope.lua --self-test  # proves the checks can go red
```

A theme's values are saved into the store of the scope its settings page was opened in
([dashboard themes](../../docs/developer/dashboard-themes.md), `configure.lua`): a theme tile
edits the radio's standard values, *Per-Model Settings* the connected model's own. The save may
say *Saved* only when that store was written, and a failure has to reach the pilot as a
translated sentence.

The `configure.lua` of every shipped theme with a settings page is loaded with the real
`app/pages/settings/dashboard/lib.lua`, the scope is set as the settings page sets it, and the
module is driven as the page drives it -- the factory, `onReload`, `build`, `onSave`. Stubbed are
the controls, the model's store (its write succeeds, its module does not load, or the write is
refused) and the radio's write (succeeds or is refused), with and without a flight controller.
A refused write answers what the real stores answer, one case each: `lib/config_store.lua`'s
`io`, `write`, `delete` and `rename`, and the error text `io.open` gives on the radio, the file's
path followed by `file error`; for the model's store also `unavailable` and `missing_mcu_id`, and
for the radio's `unavailable`, the sentence `ui/preferences.lua` answers for a missing module, and
the text of a Lua error -- 20 cases, 640 in all. Every case runs in both scopes and with the real
bundle of both shipped locales, and is red where the page is told anything but the expected title
and message, where the model's or the radio's file is written a different number of times, where
the values stand in the wrong store, where a message names a module file, shows an untranslated
key, or contains what a store answered in that case, a path separator or `file error`, and where a
bundle lacks a key the message needs: a key missing from a locale is answered with the key, not
with the English text.

`--self-test` breaks every theme's module four times, in memory -- the model scope answering
*Saved* after its file was refused, a model store that will not load answering a file name, and
the model's and the radio's answer each reaching the screen as it came -- and fails unless each
breakage turns every theme red in the case it breaks, the last two through the check on what a
store answered, or if a module's source no longer has the line the breakage rewrites.

Exit status: `0` green, `1` red, `2` when the tree cannot be read. It is not part of the CI
workflow.
