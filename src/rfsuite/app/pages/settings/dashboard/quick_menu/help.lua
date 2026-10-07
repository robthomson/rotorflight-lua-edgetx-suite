return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  local message = i18n and i18n.t and i18n.t("app.pages.settings_dashboard_quick_menu.help_message")
    or "Which entries the dashboard's Quick Settings menu shows, from the top.\nPosition 1, 2, ...: the entry in that place; the dash leaves it empty. An entry chosen twice counts at its first place.\nA chosen entry still hides where it does not apply, as in the menu. Saved with the default order, the menu follows the default."

  return {
    message = message
  }
end
