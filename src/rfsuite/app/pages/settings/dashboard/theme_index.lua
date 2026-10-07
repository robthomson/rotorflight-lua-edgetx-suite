return {
  { name = "Default", source = "system", folder = "default", configure = "configure.lua", standalone = false },
  { name = "RF Status", source = "system", folder = "rfstatus", configure = "configure.lua", standalone = false },
  { name = "@AERC", source = "system", folder = "@aerc", configure = "configure.lua", standalone = false },
  { name = "@AERC Nitro", source = "system", folder = "@aerc-n", configure = "configure.lua", standalone = false },
  { name = "@SRB-RC", source = "system", folder = "@srb-rc", configure = "configure.lua", standalone = false },
  { name = "@RT-RC", source = "system", folder = "@rt-rc", configure = "configure.lua", standalone = false },
  { name = "@RT-RC Nitro", source = "system", folder = "@rt-rc-n", configure = "configure.lua", standalone = false },
  { name = "Urban", source = "system", folder = "urban", configure = "configure.lua", standalone = false, pages = { { id = "look", title = "@i18n(app.pages.settings_dashboard_settings.urban_page_look)@", icon = "icons/look.png" }, { id = "rows", title = "@i18n(app.pages.settings_dashboard_settings.urban_page_rows)@", icon = "icons/rows.png" }, { id = "topbar", title = "@i18n(app.pages.settings_dashboard_settings.urban_page_topbar)@", icon = "icons/topbar.png" }, { id = "keys", title = "@i18n(app.pages.settings_dashboard_settings.urban_page_keys)@", icon = "icons/keys.png" } } },
}
