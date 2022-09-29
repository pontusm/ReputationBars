
StaticBarsCommon = {}
print ("StaticBarsCommon loading...")

function StaticBarsCommon:DebugLog (msg)
  if DLAPI then DLAPI.DebugLog("ReputationBars", msg) end
end


