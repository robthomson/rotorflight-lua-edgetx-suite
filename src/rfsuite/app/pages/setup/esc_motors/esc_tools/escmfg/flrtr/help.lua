-- One sheet per Section. The page shows one section at a time, and a sheet listing all seventeen
-- rows would not fit a 480x320 screen, so `M.onHelp` in page.lua passes the section on screen and
-- the sheet names that section's rows only. Opened without it, the sheet is the first section's.
--
-- Each fallback is joined in a local of its own: the precompiler replaces the call together with
-- the first literal after `or`, so a `..` chain written there would be appended to the translated
-- text in the package.
return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  local section = ctx and tonumber(ctx.section) or 1

  if section == 2 then
    local fallback = "Auto Restart Time: how long after a throttle cut the ESC still restarts the motor quickly (bailout).\n"
      .. "Restart Acc: how fast the motor spools back up on such a restart."
    local message = i18n and i18n.t and i18n.t("app.pages.setup_esc_motors.help_flrtr_advanced") or fallback
    return { message = message }
  end

  if section == 3 then
    local fallback = "ESC Mode: RF Gov when Rotorflight's governor holds the head speed, ESC Gov for the ESC's own governor.\n"
      .. "Soft Start: the time the ESC takes to spool the motor up.\n"
      .. "Governor P: the P gain of the ESC's own governor; it acts in ESC Gov only.\n"
      .. "Governor I: the I gain of the ESC's own governor; it acts in ESC Gov only."
    local message = i18n and i18n.t and i18n.t("app.pages.setup_esc_motors.help_flrtr_governor") or fallback
    return { message = message }
  end

  local fallback = "Cell Count: cells in the flight pack.\n"
    .. "Low Voltage Protection: the cell voltage it acts at.\n"
    .. "Temperature Protection: the ESC temperature it acts at.\n"
    .. "BEC Voltage: the ESC's BEC output, or off.\n"
    .. "Electrical Angle: Auto is recommended; fixed can run smoother, raise it if the motor runs hot.\n"
    .. "Motor Direction: which way the motor turns.\n"
    .. "Starting Torque: lower it if the tail kicks on spool-up.\n"
    .. "Response Speed: how directly the ESC follows the throttle.\n"
    .. "Buzzer Volume: how loud the ESC beeps.\n"
    .. "Current Gain: a correction to the ESC's current reading.\n"
    .. "Fan Control: by temperature, or always on or off."
  local message = i18n and i18n.t and i18n.t("app.pages.setup_esc_motors.help_flrtr_basic") or fallback
  return { message = message }
end
