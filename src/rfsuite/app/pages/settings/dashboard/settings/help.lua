return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  local message = i18n and i18n.t and i18n.t("app.pages.settings_dashboard_settings.help_message")
    or "The settings of this theme. The first line says whose values they are.\nStandard values for all models: used by every model without settings of its own.\nOwn settings for this model: this model only; only a value that differs from the standard is stored."

  return { message = message }
end
