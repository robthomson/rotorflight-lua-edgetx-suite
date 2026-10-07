return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  local message = i18n and i18n.t and i18n.t("app.pages.settings_dashboard_overrides.help_message")
    or "The theme settings the connected model uses instead of the standard values.\nEdit for this model: each theme the model draws; its button opens that theme's settings for this model alone.\nDifferent from standard: each value the model changes, beside the standard value it replaces.\nReset: the model uses the standard value again. Saved at once.\nReset all: the same for every value, after asking."

  return { message = message }
end
