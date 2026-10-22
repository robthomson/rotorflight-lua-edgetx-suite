local function loadModule(path)
  local fullPath = "/SCRIPTS/TOOLS/rfsuite-core/" .. path
  local chunk = loadScript(fullPath, "t")
  if type(chunk) ~= "function" then return nil end
  local ok, mod = pcall(chunk)
  if not ok then return nil end
  return mod
end

return function(ctx)
  local Common = loadModule("app/pages/settings/common.lua")
  local t = Common and Common.pageT("flight_tuning_advanced_rescue") or function(_, _, fb) return fb end
  local i18n = ctx.i18n

  local help_p1 = t(i18n, "help_p1", "Rescue Mode Enable: Enables the rescue autopilot on the flight controller.")
  local help_alt_hold = t(i18n, "help_alt_hold",
    "Altitude hold: shown only for a profile that already holds altitude; off makes rescue climb instead.")
  local help_p2 = t(i18n, "help_p2", "Flip to upright: Chooses whether the helicopter flips to an upright orientation when rescue is triggered.")
  local help_p3 = t(i18n, "help_p3", "Pull-up: Defines collective pitch percent and duration to stop the helicopter's descent.")
  local help_p4 = t(i18n, "help_p4", "Climb: Defines collective pitch percent and climb duration for the climbing stage.")
  local help_p5 = t(i18n, "help_p5", "Hover: Defines collective pitch percent to maintain a steady hover at the end of the climb.")
  local help_p6 = t(i18n, "help_p6", "Flip Limits: Fail time specifies how long to attempt a flip before aborting. Exit time is the flip exit phase duration.")
  local help_p7 = t(i18n, "help_p7", "Gains and Limits: Level sets the self-leveling gain, and Flip sets the flip rotation rate gain. Rate and Accel limit the max rotation rate and acceleration during leveling.")

  local parts = { help_p1, help_alt_hold, help_p2, help_p3, help_p4, help_p5, help_p6, help_p7 }

  return {
    title = t(i18n, "help_title", "Rescue Help"),
    message = table.concat(parts, "\n\n")
  }
end
