ReputationBarsCommon = {}
local appName = "ReputationBars"

local isFormatComplete = false
local isLoggingEnabled = true -- this should be false whenever possible

function ReputationBarsCommon:DebugLog (type,category,level,message)
  if isLoggingEnabled then
    local debugMsg = ""
    if type ~= nil and type ~= "" then
      --Supported Values for type are:  <blank>, "OK", "WARN", "ERR"
      debugMsg = debugMsg .. type .. "~"
    end
    
    if category ~= nil and category ~= "" then
      debugMsg = debugMsg .. category .. "~"
    end

    if level ~= nil and level ~= "" then
      debugMsg = debugMsg .. level .. "~"
    end

    debugMsg = debugMsg .. message
    
    if DLAPI then DLAPI.DebugLog(appName, debugMsg) end

    if isFormatComplete == false then
      ReputationBarsCommon:FormatDebugLog()
    end
  end
end

function ReputationBarsCommon:FormatDebugLog()
  if DLAPI and DLAPI.GetFormat and DLAPI.IsFormatRegistered then
    local fmt = DLAPI.IsFormatRegistered(DLAPI.GetFormat(appName))
    if fmt and fmt.colWidth then
      fmt.colWidth = { 0.05, 0.12, 0.20, 0.03, 1 - 0.05 - 0.12 - 0.20 - 0.03, }
    end
  end
  isFormatComplete = true
end  
