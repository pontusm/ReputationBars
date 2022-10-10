ReputationBarsCommon = {}

local isFormatComplete = false
local isLoggingEnabled = true -- this should be false whenever possible

function ReputationBarsCommon:DebugLog (type,category,level,message)
  if isLoggingEnabled then
    local debugmsg = ""
    if type ~= nil and type ~= "" then
      debugmsg = debugmsg .. type .. "~"
    end
    
    if category ~= nil and category ~= "" then
      debugmsg = debugmsg .. category .. "~"
    end

    if level ~= nil and level ~= "" then
      debugmsg = debugmsg .. level .. "~"
    end

    debugmsg = debugmsg .. message
    
    if DLAPI then DLAPI.DebugLog("ReputationBars", debugmsg) end

    if isFormatComplete == false then
      ReputationBarsCommon:FormatDebugLog()
    end
  end
end

function ReputationBarsCommon:FormatDebugLog()
  if DLAPI and DLAPI.GetFormat and DLAPI.IsFormatRegistered then
    local fmt = DLAPI.IsFormatRegistered(DLAPI.GetFormat(addonName))
    if fmt and fmt.colWidth then
      fmt.colWidth = { 0.05, 0.12, 0.11, 0.03, 1 - 0.05 - 0.12 - 0.11 - 0.03, }
    end
  end
  isFormatComplete = true
end  
