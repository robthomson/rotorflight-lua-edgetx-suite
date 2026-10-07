return function(ctx)
  local i18n = ctx and ctx.i18n or nil
  -- The fallback is joined in a local of its own: the precompiler replaces the call together with
  -- the first literal after `or`, so a `..` chain written there would be appended to the
  -- translated text in the package.
  local fallback = "Configure safety prompts, preview features and developer visibility in general settings. "
    .. "A preview feature is already in the suite but not finished: it stays hidden until it is "
    .. "switched on here."
  local message = i18n and i18n.t and i18n.t("app.pages.settings_general.help_message") or fallback

  return { message = message }
end
