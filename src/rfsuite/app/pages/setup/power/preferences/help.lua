return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  -- Joined in a local of its own, for the reason given in settings/general/help.lua.
  local fallback = "Power settings kept on the radio per flight controller; nothing here is written to it.\n"
    .. "Model Type: what the fuel estimate and the announcements treat the model as.\n"
    .. "Local SmartFuel Source: the estimate the radio computes when the flight controller computes none.\n"
    .. "Publish SmFt / SmCp: publish the remaining fuel and the consumption as two telemetry sensors.\n"
    .. "ESC Current Limit: the limit the ESC load is a percentage of; the label says where it came from."
  local message = i18n and i18n.t and i18n.t("app.pages.setup_power_preferences.help_message") or fallback

  return {
    message = message
  }
end