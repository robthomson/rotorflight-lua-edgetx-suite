return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  local fallback = "Counters and readings of a CRSF sensor accessory on the CRSF Sensors serial port, read about once a second.\n"
    .. "Link: Port enabled once a serial port has the CRSF Sensors function.\n"
    .. "RX bytes: rises while bytes arrive; standing still means nothing reaches the port.\n"
    .. "CRC fail: frames that arrived damaged; rising means a wiring or signal problem.\n"
    .. "GPS, Battery, Barometer, Cell Voltages, RPM: No data until that frame type arrives."
  local message = i18n and i18n.t and i18n.t("app.pages.diagnostics_crsf_sensors.help_message")
    or fallback

  return { message = message }
end
