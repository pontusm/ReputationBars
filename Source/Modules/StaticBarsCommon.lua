
StaticBarsCommon = {}
print ("StaticBarsCommon loading...")

function StaticBarsCommon:DebugLog (msg)
  if DLAPI then DLAPI.DebugLog("ReputationBars", msg) end
end

function StaticBarsCommon:generateModName (addon)
  local baseName = "StaticBars"
  local found = true
  local searchName 
  local searchIndx = 1

  while found do  --assume found on the first pass in...
    found = false

    if searchIndx == 1 then
      searchName = baseName
    else 
      searchName = baseName .. tostring(searchIndx)
    end

    for name, _ in pairs(addon.modules) do
      if (name == searchName) then
        found = true
      end
    end

    searchIndx = searchIndx + 1
  end

  return searchName

end



