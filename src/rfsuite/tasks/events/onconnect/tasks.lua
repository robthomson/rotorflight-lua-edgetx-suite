local mode = (_G.rfsuite and _G.rfsuite.loadMode) or "bt"
local Runner = assert(loadScript("/SCRIPTS/TOOLS/rfsuite-core/tasks/events/common/runner.lua", mode))()
return Runner.new("onconnect")
