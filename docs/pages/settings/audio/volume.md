---
nav_order: 2
parent: Audio
grand_parent: Settings
---

# Volume

The Volume page sets how loud the suite's announcements are, in one of two ways: a level for the announcements themselves, or the radio's whole master volume through a global variable. A save the card refuses shows *Save failed: the settings file could not be written to the SD card*.

## Mode

* **Mode:** one of three, and only one at a time.
  * **Off (radio default)** (the default): the radio's own Wav volume and master volume rule; the suite writes nothing.
  * **Callout level:** every announcement plays at the *Level* set below; the master volume stays with the pot.
  * **Master volume:** the suite sets the radio's whole volume through a global variable; see [Master volume](#master-volume).

The two cannot be combined because they multiply: the level scales the sound files, and the master volume scales everything the radio plays after that. Under a master volume the suite sets, a level could only make the announcements quieter than that master volume says.

**A settings file written before the page offered a mode** is read the way the suite used it then: a global variable set means *Master volume*, a level set means *Callout level*, neither means *Off*. A file that had both a level and a global variable set opens in *Master volume*, and the level is ignored from then on -- the announcements then play at the radio's own Wav volume under the master volume, rather than at that level. The level stays in the file and is offered again when *Callout level* is picked. The mode is written to the file on the page's first save.

* **Connected only:** shown in both modes, under *Mode*.
  * **On:** the mode acts only while the radio's link to the model is up, so bench and menu work stays at the radio's own volume. In *Master volume* the pot rules until the link comes up, the *Normal Level* is written then, and `-1024` is written when the link goes down (unless a critical alert is still active, see below).
  * **Off:** the mode acts from the moment the dashboard or the tool starts, and the link changes nothing. In *Master volume* the pot therefore stays overridden for as long as the mode is on.
  * Until it is set, it follows the mode: in *Callout level* the earlier *Connected only* of the level, in *Master volume* on, which is how the master volume always behaved. A file written before this setting existed reads the same way, and so does a mode picked on the page before *Connected only* is touched or saved in one of the two modes; a save in *Off* does not store it.
  * For adjustment announcements made where neither the dashboard nor the tool runs (by the [background decoder](../../../reference/background-decoder.md), or by the service widget on its own), *on* means that the radio's RF link is up.

## Callout level

* **Level:** 1 to 5 (5 the loudest). It applies to the sound file of an announcement, to the number and unit the radio speaks after it, and to the adjustment announcements the background decoder or the service widget makes. Level 3 plays a sound file at a quarter of its amplitude, which is what the radio's own *Wav volume* does at its middle setting 0; 5 plays it at full amplitude, 1 at a sixteenth. Picking *Callout level* with no level stored starts at 3.

## Master volume

The suite changes the entire radio's volume during flight. While no critical alert is active it writes the *Normal Level*; while any critical alert is active it writes the *Alert Level* instead. The critical alerts are low voltage, an empty tank, telemetry lost in flight, and the ESC or MCU temperature at its critical level -- the tank and the temperatures only while their own alert is switched on. With *Connected only* on, the *Normal Level* is written only while the link is up, the *Alert Level* whenever a critical alert is active.

* **Global Variable:** picked with the radio's own source picker, which lists only the global variables this radio has, with their names -- GV1 to GV9 on most radios, GV1 to GV15 on radios that have fifteen. It has no entry for off: *Mode* *Off* is what turns the master volume off. Until a global variable is picked, the picker shows EdgeTX's empty source `---`, the suite writes nothing, and the page says under the picker that one is to be picked. EdgeTX lists no global variable while global variables are switched off for the model (in its model setup, or for every model in the radio setup); a global variable picked before stays shown and is still written. A settings file that names a global variable this radio does not have (copied from a radio with more) leaves the master volume off, and the page says so under the picker; the setting stays in the file.
* **Normal Level (%):** the master volume while no critical alert is active.
* **Alert Level (%):** the master volume while any critical alert is active.

The setting is radio-wide: every model memory that carries the chain below uses the same global variable.

**Radio Setup (once per model):**
1. **Settings > Audio > Volume:** set *Mode* to *Master volume* and *Global Variable* to a free global variable (e.g. **GV9**). Set your desired *Normal* and *Alert* volume levels.
2. **Inputs:** Add one input, e.g. `I15 "Vol"`, **Source = GV9**, weight 100. (Give it its own slot and leave it out of the mixer).
3. **Logical Switch:** Create a logical switch `L10: a > x` with **a = GV9**, **x = -1024**. This is true while the suite is driving the volume.
4. **Special Function:** Create a special function `SF: L10 -> Volume = I15 (Vol)`. (Use the **input**, not the GVAR).

When the suite stops driving the volume while the dashboard or the tool runs (the link goes down with *Connected only* on, another mode is picked, or another global variable is picked -- then the one it held), it writes `-1024` to the GVAR. This makes the logical switch false, the special function releases, and your regular volume pot regains control. Each changed value is a write into the model, which EdgeTX saves with the model.

> [!NOTE]
> Retiring the feature does not automatically release the GVAR. The last written value stays in the model file, so the pot will remain overridden until something writes `-1024` again. The same holds when the radio is switched off while the suite holds the volume and the mode is changed before the next start: only a running dashboard or tool that wrote the global variable releases it, so write `-1024` by hand (or pick the mode again, start the dashboard, then change it) before relying on the pot.
