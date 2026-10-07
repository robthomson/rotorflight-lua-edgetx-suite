return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  local fallback = "Select which sources the flight controller uses for battery voltage and current measurements.\n"
    .. "Voltage Source: where the pack voltage is read from; CRSF needs a serial port set to CRSF Sensors on the Ports page.\n"
    .. "Current Source: where the pack current is read from; CRSF reads it from the same sensor."
  local message = i18n and i18n.t and i18n.t("app.pages.setup_power_sources.help_message")
    or fallback

  return {
    message = message
  }
end
