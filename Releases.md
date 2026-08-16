# 0.1.0

### Features
- **Telemetry Flight Logs & Dashboard (`diagnostics/flight_logs`)**:
  - Implemented flight log browser and analytical dashboard to inspect EdgeTX CSV log files directly on the radio.
  - Added statistics calculations including min/max/average cell voltages, battery capacity consumption, RPM, temperatures, and flight durations.
  - Added interactive `LoadingOverlay` with non-blocking incremental parsing and proactive memory cleanup to keep the UI responsive on large CSV files.
- **RFSuite EdgeTX Updater Tool & CI**:
  - Added standalone and integrated EdgeTX Updater tool for automatic online and local updating of RFSuite packages.
  - Automated detection of available languages from repository branches and release tags.
  - Added multi-language CI build workflows and packaging scripts.
- **Governor Setup Pages**:
  - Ported Governor General setup page (`governor/general`).
  - Ported Governor Ramp Time configuration (`governor/ramps`).
  - Ported Governor Filters setup page (`governor/filters`).
  - Ported Governor Bypass Curve configuration (`governor/bypass`).
- **Dynamic ESC Sensor Detection**:
  - Added background `esc_sensor_config` task triggered on connection to query and identify active ESC telemetry protocol.
- **Manufacturer ESC Tools Integration**:
  - Ported and integrated full ESC configuration suites for Bluejay, BLHeli_S, Flyrotor, Hobbywing V5, OMP, Scorpion, XD-Fly, YGE, and ZTW.

### Localization (i18n)
- Localized flight tuning pages (PIDs, Rates, Governor, Rates Advanced) in German and English with fallback cleanup.

### Bug Fixes & Performance
- **Telemetry CSV Parsing Accuracy**: Improved header validation, outlier filtering (e.g. 0 RPM spikes), and memory efficiency during log analysis.
- **Reconnect Performance**: Resolved telemetry reconnect slowdowns and memory buildup using proactive garbage collection and cached LQ checks.

# 0.0.2

### Features
- **Compile-time Translation Inlining**: Introduced static translation inlining at compile time, simplified settings, and bumped version to 0.0.2.
- **Fuel Announcements**: Added initial fuel announcement and implemented differentiation between electric and gas/glow models in fuel callouts.
- **Developer Logging**: Made exit shutdown logging conditional on the developer `debug_level`.
- **Dynamic ESC Tools Lockout**: Automatically enable/disable manufacturer-specific ESC Tool menu tiles based on the active telemetry protocol queried via `esc_sensor_config`.
- **YGE ESC 12V BEC Support**: Dynamically adjust BEC voltage range up to 12.0V for supported models (205 HVT, 205 HVT BEC, 165 HVT, Aureus 105v2, Aureus 135v2, Saphir 155v2), capping older/standard models at 8.4V and synchronizing the `flags_bec12v` bit automatically.

### Security & Armed State (Model Armed)
- **Model Armed Blocking**:
  - Implemented `isModelArmed()` check in `home.lua` using the passive ARM telemetry sensor.
  - Blocked `MspRuntime.tick()` and active page wakeup from executing when model is armed to avoid serial connection hangs.
  - Added a full-screen armed warning screen at boot and during runtime if the model is armed.
  - Blocked subpage navigation, reloading, and saving actions with a warning dialog when armed.
  - Added German & English localizations for the armed title and warning messages.
- **Armed Warning Screen & Telemetry Check Optimization**:
  - Kept `MspRuntime.tick()` running when armed to drain the serial RX buffer and prevent telemetry loss.
  - Wrapped the armed warning screen in a standard page with a Close button and back-navigation support.
  - Checked `getRSSI()` to detect telemetry loss, skipping the check in the simulator to allow simulation of the armed state.

### Performance
- **Lag Reduction**: Cached compiled Lua chunks and optimized the exit cleanup sequence to resolve lags.

### Bug Fixes
- **Audio Callouts & Alarms**:
  - Corrected empty battery warning path for electric models to `"stat/alerts/lowbat.wav"` ("Flugakku leer") instead of the radio's native low battery warning.
  - Optimized fuel threshold countdown logic to jump directly to the lowest crossed threshold without stepped intermediate announcements.
- **Focus Preservation & Page Rebuilds**:
  - Redesigned `buildSessionSignature()` across all ESC pages (AM32, BLHeli_S, Bluejay, Flycolor, Hobbywing V5, OMP, Scorpion, XD-Fly, YGE, ZTW) to prevent background wakeup loops from stealing focus while editing fields.
  - Added value-change guards in `controls.lua` for number fields and combo selectors to ignore layout-time init events and prevent unintended dirty states.
- **Telemetry Freezes & Hangs**:
  - Unconditionally run `Events.wakeup()` in `home.lua` to keep the background `telemetry_bg` task running.
  - Skip onconnect tasks when armed in `tasks/events/runtime.lua` to prevent FBL configuration requests.
  - Run the `telemetry_bg` task even when armed to parse custom CRSF frames and update radio sensors.
  - Skip startup version and UID reads when armed in `tasks/msp/runtime.lua`.
- **Audio Processing**: Enabled `Audio.process` in the configuration tool for live voice feedback (profiles, rates, telemetry).
- **ESC Configuration (AM32)**:
  - Restored ESC target to 100 on `am32/page.lua` close and performed a post-save reset cycle to apply and save settings.
  - Fixed MotorConfigApi command reference in `am32/page.lua` (using `.command` instead of `.readCommand`).
  - Implemented retry logic for motor config reads when the FBL returns empty buffers.
  - Added German & English localizations for ESC config loading and saving messages.
- **Alignment Page**:
  - Added guards for `ui.runtime` checks in `alignment/page.lua` async callbacks to prevent nil errors after page close.

### UI & Miscellaneous
- **Layout Redesign**: Redesigned alignment layout to two rows, widened Roll/Nick/Yaw fields and Magnetometer combobox to 160px.
- **Git Config**: Updated `.gitignore`.
