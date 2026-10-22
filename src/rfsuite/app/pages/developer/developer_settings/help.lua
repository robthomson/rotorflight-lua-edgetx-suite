return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  local message = i18n and i18n.t and i18n.t("app.pages.settings_developer_settings.help_message")
    or "Debug Level: how much is logged. Errors, warnings and most info lines are logged even at OFF; DEBUG and TRACE add more.\nContinuous Memory Log: the tool logs its Lua memory once a second.\nShow Header Memory: shows the tool's Lua memory in the page header.\nEnable Serial Debug: also sends the lines the debug level lets through to the radio's serial port; at OFF that is none.\nLog Session To Card: writes the log to the SD card. On its own it already writes errors, warnings and info; the background decoder writes only from DEBUG up."

  return { message = message }
end
