--[[
		-+*+- Reputation Bars -+*+-
]]
local appName = "ReputationBars"

ReputationBars = LibStub("AceAddon-3.0"):NewAddon(appName,
						"AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0",
						"LibBars-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale(appName, true)

local mod = ReputationBars

-- Default settings
local defaults = {
	profile = {
		modules = {
			["*"] = true
		},
	},
}

local timer
local reputationChanges = {}
local allFactions = {}
local factionAmounts = {}

------------------------------------------------------------------------------
-- Initialize
------------------------------------------------------------------------------
function mod:OnInitialize()
	-- Initialize database
	self.db = LibStub("AceDB-3.0"):New("ReputationBarsDB", defaults, "Default")
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	
	-- Enable/disable submodules
	for name, module in self:IterateModules() do
		module:SetEnabledState(self.db.profile.modules[name] or false)
	end

	-- Initialize options
	self:SetupOptions()
	
	-- Register slash command
	--self:RegisterChatCommand("rptb", "ShowConfig")
end

function mod:OnProfileChanged(event, database, newProfileKey)
	for name, module in self:IterateModules() do 
		if self.db.profile.modules[name] then
			module:Enable()
			if module.OnProfileChanged then
				module:OnProfileChanged( self:GetModuleDB(name) )
			end
		else
			module:Disable()
		end
	end
end

-------------------------------------------------------------------------------
-- Enable/disable
-------------------------------------------------------------------------------
function mod:OnEnable()
	self:ScheduleTimer("EnsureFactionsLoaded", 0.5)	
	self:RegisterEvent("COMBAT_TEXT_UPDATE")
	self:RegisterEvent("UPDATE_FACTION")
end

function mod:OnDisable()
end

------------------------------------------------------------------------------
-- Get module db
------------------------------------------------------------------------------
function mod:GetModuleDB(moduleName)
	return mod.db:GetNamespace(moduleName)
end

------------------------------------------------------------------------------
-- Show config
------------------------------------------------------------------------------
function mod:ShowConfig(moduleName)
	-- We call Blizzard api multiple times to workaround bug
	if moduleName and #moduleName > 0 then
		InterfaceOptionsFrame_OpenToCategory(self.optionFrames.plugins[moduleName])
		InterfaceOptionsFrame_OpenToCategory(self.optionFrames.plugins[moduleName])
	else
		InterfaceOptionsFrame_OpenToCategory(self.optionFrames.general)
		InterfaceOptionsFrame_OpenToCategory(self.optionFrames.general)
	end
end

------------------------------------------------------------------------------
-- Faction methods
------------------------------------------------------------------------------
function mod:GetFactionIndex(factionName)
	local expansionLevel = GetClientDisplayExpansionLevel()
	for i = 1, #allFactions do
		local name = ""
		
		if expansionLevel < 10 then
			name, _, _, _, _, _, _, _, _, _, _, _, _ = GetFactionInfo(i); 
		else
			local factionData=C_Reputation.GetFactionDataByIndex(i);
			name = factionData.name
		end
		if name == factionName then return i end
	end
	return 0
end

function mod:GetFactionInfo(factionIndex)
	return allFactions[factionIndex]
end

function mod:GetAllFactions()
	return allFactions
end

local function UpdateFactionAmount(name, amount)
	ReputationBarsCommon:DebugLog("OK","UpdateFactionAmount",4,"Function Call Started...")	
	ReputationBarsCommon:DebugLog("","UpdateFaction",5,"Name  : "..tostring(name))
	ReputationBarsCommon:DebugLog("","UpdateFaction",6,"Amount: "..tostring(amount))

	local oldAmount = factionAmounts[name]
	if oldAmount ~= nil and oldAmount ~= amount then
		-- Collect all gained reputation before notifying modules
		
		ReputationBarsCommon:DebugLog("WARN","UpdateFaction",6,"Name     : "..tostring(name))
		ReputationBarsCommon:DebugLog("WARN","UpdateFaction",6,"Amount   : "..tostring(amount))
		ReputationBarsCommon:DebugLog("WARN","UpdateFaction",6,"oldAmount: "..tostring(oldAmount))

		reputationChanges[name] = amount - oldAmount
	end
	factionAmounts[name] = amount
	ReputationBarsCommon:DebugLog("OK","UpdateFactionAmount",4,"Function Call Finished")	
end

-- Refresh the list of known factions
function mod:RefreshAllFactions()
	ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",4,"Function Call Started...")
	local expansionLevel = GetClientDisplayExpansionLevel()

	local i
	local lastName
	local factions = {}
	--ExpandAllFactionHeaders()
	
	local factionCount = 0
	if expansionLevel < 10 then
		factionCount = GetNumFactions()
	else
		factionCount = C_Reputation.GetNumFactions()
	end

	
	--Standard Load Pattern (from Blizzard's API-based list of factions I know)
	for i = 1, factionCount do
		local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus

		if expansionLevel < 10 then 
			name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
		else
			local factionData=C_Reputation.GetFactionDataByIndex(i);
			if factionData then
				name           = factionData.name
				description	 = factionData.description
				standingId	 = factionData.reaction
				bottomValue 	 = factionData.currentReactionThreshold
				topValue	 = factionData.nextReactionThreshold
				earnedValue    = factionData.currentStanding
				atWarWith	 = factionData.atWarWith
				canToggleAtWar = factionData.canToggleAtWar
				isHeader	 = factionData.isHeader
				isCollapsed    = factionData.isCollapsed
				hasRep         = factionData.isHeaderWithRep
				isWatched      = factionData.isWatched
				isChild	 = factionData.isChild
				factionID	 = factionData.factionID
				canBeLFGBonus  = factionData.hasBonusRepGain
				canSetInactive = factionData.canSetInactive
				isAccountWide  = nil
			end
		end


		if expansionLevel < 10 then
			local isActive         = not IsFactionInactive(i)
		else
			local isActive         = C_Reputation.IsFactionActive(i)
		end

		if not name or name == lastName and name ~= GUILD then break end
		mod:ProcessFaction(factions, name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, canBeLFGBonus, canSetInactive, isAccountWide, isActive);

		if isCollapsed then
			if expansionLevel < 10 then
				ExpandFactionHeader(i)
			else
				C_Reputation.ExpandFactionHeader(i)
			end
		end
	end


	--'Special' Load Pattern (for factions that blizzard seems to "lose" regularly)
	local twitchyFactions = {2570,2590,2594}
	factionCount = #twitchyFactions
	ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",4,"Number of factions to handle in a special way: " .. tostring(factionCount));

	for i = 1, factionCount do
		missingFactionID = twitchyFactions[i];

	    ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",4,"Looking for problematic faction:" .. tostring(missingFactionID));
		local isFactionMissing=true

		for f = 1, #factions do
			local faction = factions[f]
			local factionID = faction.factionID

			if (factionID == missingFactionID) then
				isFactionMissing = false
				break
			end
		end

		if isFactionMissing then
			ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",4,"Preparing to special handle Faction: " .. tostring(missingFactionID));

			local factionData=C_Reputation.GetFactionDataByID(missingFactionID);
			if factionData then
				name           = factionData.name
				description	   = factionData.description
				standingId	   = factionData.reaction
				bottomValue    = factionData.currentReactionThreshold
				topValue	   = factionData.nextReactionThreshold
				earnedValue    = factionData.currentStanding
				atWarWith	   = factionData.atWarWith
				canToggleAtWar = factionData.canToggleAtWar
				isHeader	   = factionData.isHeader
				isCollapsed    = factionData.isCollapsed
				hasRep         = factionData.isHeaderWithRep
				isWatched      = factionData.isWatched
				isChild	       = factionData.isChild
				factionID	   = factionData.factionID
				canBeLFGBonus  = factionData.hasBonusRepGain
				canSetInactive = factionData.canSetInactive
				isAccountWide  = nil
				isActive       = false

				mod:ProcessFaction(factions, name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, canBeLFGBonus, canSetInactive, isAccountWide, isActive);
			end
			
		else
			ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",4,"Faction is loaded; no action: " .. tostring(missingFactionID));
		end
    end





	allFactions = factions
	ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",4,"Function Call Finished...")
end


function mod:ProcessFaction(factions, name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, canBeLFGBonus, canSetInactive, isAccountWide, isActive)
	ReputationBarsCommon:DebugLog("OK","ProcessFaction",5,"Function Call Started...")
	local isParagon = factionID and C_Reputation.IsFactionParagon(factionID);
	local isMajorFaction = factionID and C_Reputation.IsMajorFaction(factionID);
	local expansionLevel = GetClientDisplayExpansionLevel()

	
	if factionID == 169 then --hack for Steamwheedle Cartel (classic faction #169 which has no rep)
		return
	end
	
	--Step 1) define and populate (with faction data) all our "insert variables" for our internal table
	local nsrt_name             = name
	local nsrt_standingId       = standingId
	local nsrt_min              = bottomValue
	local nsrt_max              = topValue
	local nsrt_value            = earnedValue
	local nsrt_isHeader         = isHeader
	local nsrt_isChild          = isChild
	local nsrt_hasRep           = hasRep
	local nsrt_isParagon        = isParagon
	local nsrt_isActive         = isActive
	local nsrt_factionID        = factionID
	local nsrt_friendID
	local nsrt_isMajorFaction   = isMajorFaction
	local nsrt_hasRewardPending    = false
	local nsrt_RewardsCollected = 0

	ReputationBarsCommon:DebugLog("","ProcessFaction",5,"Loading/Updating '"..tostring(nsrt_name).."' into internal table")
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"Step1: nsrt_name            : "..tostring(nsrt_name))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_standingId      : "..tostring(nsrt_standingId))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_min             : "..tostring(nsrt_min))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_max             : "..tostring(nsrt_max))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_value           : "..tostring(nsrt_value))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_isHeader        : "..tostring(nsrt_isHeader))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_isChild         : "..tostring(nsrt_isChild))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_hasRep          : "..tostring(nsrt_hasRep))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_isParagon       : "..tostring(nsrt_isParagon))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_isActive        : "..tostring(nsrt_isActive))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_factionID       : "..tostring(nsrt_factionID))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_friendID        : "..tostring(nsrt_friendID))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_isMajorFaction  : "..tostring(nsrt_isMajorFaction))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_hasRewardPending: "..tostring(nsrt_hasRewardPending))

	--Step 2) figure out if this is a friend (rather than a faction), and if so, override some of our base faction values.
	if nsrt_isHeader ~= true then
		--we need to do this different ways for Dragonflight vs Shadowlands
		if expansionLevel >= 9 then -- DragonFlight, The War Within, and beyond
			local retOK, FriendshipInfo = pcall(C_GossipInfo.GetFriendshipReputation, factionID)

			if retOK then --make sure pcall worked
				ReputationBarsCommon:DebugLog("WARN","ProcessFaction",6,"       ***C_GossipInfo.GetFriendshipReputation call successful")
				ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       FriendshipInfo: " .. tostring(FriendshipInfo))

				if FriendshipInfo ~= nil then --make sure that we actually got a value from the API call
				ReputationBarsCommon:DebugLog("WARN","ProcessFaction",6,"       FriendshipInfo.friendshipFactionID: " .. tostring(FriendshipInfo.friendshipFactionID))					
				if FriendshipInfo.friendshipFactionID ~= 0 then --this is a friend .. handle them differently
						nsrt_value = FriendshipInfo.standing
						nsrt_friendID = FriendshipInfo.friendshipFactionID
				
						if FriendshipInfo.nextThreshold ~= nil then --this friend still has progress
							nsrt_min = FriendshipInfo.reactionThreshold
							nsrt_max = FriendshipInfo.nextThreshold
						end
					end
				end
			else
				ReputationBarsCommon:DebugLog("ERR","ProcessFaction",6,"       ***C_GossipInfo.GetFriendshipReputation call FAILED")
			end
		end
	end

	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"Step2: nsrt_min          : "..tostring(nsrt_min))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_max          : "..tostring(nsrt_max))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_value        : "..tostring(nsrt_value))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_friendID     : "..tostring(nsrt_friendID))

	--Step 3) figure out if this is a major faction (new for Shadowlands)
	if isMajorFaction then
		local majorFactionInfo = C_MajorFactions.GetMajorFactionData(factionID);
		nsrt_value = majorFactionInfo.renownReputationEarned
		nsrt_min = 0
		nsrt_max = majorFactionInfo.renownLevelThreshold
	end

	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"Step3: nsrt_isMajorFaction: "..tostring(nsrt_isMajorFaction))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_value         : "..tostring(nsrt_value))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_min           : "..tostring(nsrt_min))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_max           : "..tostring(nsrt_max))

	--Step 4) figure out if this is a paragon faction (extra rep beyond exalted), and if so, override some of our base faction values
	if isParagon then
		local currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevelForParagon = C_Reputation.GetFactionParagonInfo(factionID)
		nsrt_value = currentValue % threshold
		nsrt_min = 0
		nsrt_max = threshold
		nsrt_hasRewardPending = hasRewardPending
	end
	lastName = name

	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"Step4: nsrt_isParagon        : "..tostring(nsrt_isParagon))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_value            : "..tostring(nsrt_value))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_min              : "..tostring(nsrt_min))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_max              : "..tostring(nsrt_max))
	ReputationBarsCommon:DebugLog("","ProcessFaction",6,"       nsrt_hasRewardPending : "..tostring(nsrt_RewardPending))

	lastName = name

	--Step 5) *phew* that was a lot of work, save it before it's too late...
	tinsert(factions, {
		name             = nsrt_name,
		standingId       = nsrt_standingId,
		min              = nsrt_min,
		max              = nsrt_max,
		value            = nsrt_value,
		isHeader         = nsrt_isHeader,
		isChild          = nsrt_isChild,
		hasRep           = nsrt_hasRep,
		isParagon        = nsrt_isParagon,
		isActive         = nsrt_isActive,
		factionID        = nsrt_factionID,
		friendID         = nsrt_friendID,
		isMajorFaction   = nsrt_isMajorFaction,
		hasRewardPending = nsrt_hasRewardPending,
	})	
	
	UpdateFactionAmount(name, nsrt_value)
	ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",5,"Function Call Finished...")
end



------------------------------------------------------------------------------
-- Ensure factions and guild info are loaded
------------------------------------------------------------------------------
function mod:EnsureFactionsLoaded()
	-- Sometimes it takes a while for faction and guild info
	-- to load when the game boots up so we need to periodically
	-- check whether its loaded before we can display it

	local expansionLevel = GetClientDisplayExpansionLevel()
	if expansionLevel < 10 then
	   factionData = GetFactionInfo(1)
	else 
	   factionData = C_Reputation.GetFactionDataByID(1)
	end
	
	if factionData == nil or (IsInGuild() and GetGuildInfo("player") == nil) then
		self:ScheduleTimer("EnsureFactionsLoaded", 0.5)	
	else
		-- Refresh all factions and notify modules
		self:RefreshAllFactions()
		for _, module in self:IterateModules() do 
			if module.RefreshReputation and module:IsEnabled() then
				module:RefreshReputation()
			end
		end
	end
end

------------------------------------------------------------------------------
-- Update reputation
------------------------------------------------------------------------------
function mod:UpdateReputation()
	self:RefreshAllFactions()

	local presentGainsForInactiveReputations = ReputationBars_AutoBars:overrideInactiveReputations()
	ReputationBarsCommon:DebugLog("ERR","UpdateReputation",6,"presentGainsForInactiveReputations: "..tostring(presentGainsForInactiveReputations))

	-- Build sorted change table
	local changes = {}
	for name, amount in pairs(reputationChanges) do
		-- Skip inactive factions
		local factionIndex = self:GetFactionIndex(name)

		local expansionLevel = GetClientDisplayExpansionLevel()

		if expansionLevel < 10 then
                        ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"Expansion<10")
			local isFactionActive         = not IsFactionInactive(factionIndex)
		else
                        ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"Expansion>=10")
			local isFactionActive         = C_Reputation.IsFactionActive(factionIndex)
		end
		
		-- Override/Hack for when isFactionActive is invalid
		if isFactionActive == nil then
		    ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"isFactionActive is still nil; need to fix it.")
		    isFactionActive = true
		else
		    ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"isFactionActive has a value.")
		end
		

		ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"  => factionIndex:                       "..tostring(factionIndex))
		ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"  => isFactionActive:                    "..tostring(isFactionActive))
		ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"  => presentGainsForInactiveReputations: "..tostring(presentGainsForInactiveReputations))
		ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"  => name:                               "..tostring(name))
		ReputationBarsCommon:DebugLog("WARN","UpdateReputation",6,"  => amount:                             "..tostring(amount))

		if factionIndex and (isFactionActive or presentGainsForInactiveReputations) then   --this is the line that modnarwave is suggesting changing.
			tinsert(changes, {
				name = name,
				amount = amount,
				factionIndex = factionIndex
			})
		end
	end

	if #changes > 1 then
		table.sort(changes, function(a, b) return a.amount > b.amount end)
	end

	if #changes > 0 then
		-- Notify modules
		for _, module in self:IterateModules() do 
			if module.UpdateReputation and module:IsEnabled() then
				module:UpdateReputation(changes)
			end
		end
	end

	timer = nil
	reputationChanges = {}
end

function mod:ScheduleUpdate()
	if timer then
		self:CancelTimer(timer, true)
	end
	timer = self:ScheduleTimer("UpdateReputation", 0.1)
end

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------
function mod:COMBAT_TEXT_UPDATE(event, type, name, amount)
	ReputationBarsCommon:DebugLog("OK","mod:COMBAT_TEXT_UPDATE",4,"Event Trapped...")	
	--ReputationBarsCommon:DebugLog("OK","mod:COMBAT_TEXT_UPDATE",5,"  => event  : "..tostring(event))	
	--ReputationBarsCommon:DebugLog("OK","mod:COMBAT_TEXT_UPDATE",5,"  => type   : "..tostring(type))
	--ReputationBarsCommon:DebugLog("OK","mod:COMBAT_TEXT_UPDATE",5,"  => name   : "..tostring(name))	
	--ReputationBarsCommon:DebugLog("OK","mod:COMBAT_TEXT_UPDATE",5,"  => amount : "..tostring(amount))	
	
	if (type == "FACTION") then
		if IsInGuild() then
			-- Check name for guild reputation
			if name == GUILD then
				name = (GetGuildInfo("player"))
				if not name or name == "" then return end
			end
		end
		
		name, amount=GetCurrentCombatTextEventInfo()
		ReputationBarsCommon:DebugLog("OK","mod:COMBAT_TEXT_UPDATE",5,"  => name   (override): "..tostring(name))
		ReputationBarsCommon:DebugLog("OK","mod:COMBAT_TEXT_UPDATE",5,"  => amount (override): "..tostring(amount))
		
		-- Collect all gained reputation before notifying modules
		if name then
			if not reputationChanges[name] then
				reputationChanges[name] = amount
			else
				reputationChanges[name] = reputationChanges[name] + amount
			end
		end

		self:ScheduleUpdate()

		--self:Print("Gained "..amount.." with "..name)
	end
end

function mod:UPDATE_FACTION()
	ReputationBarsCommon:DebugLog("OK","mod:UPDATE_FACTION",4,"Event Trapped...")	
	self:ScheduleUpdate()
end

------------------------------------------------------------------------------
-- Setup options
------------------------------------------------------------------------------
function mod:SetupOptions()
	-- Get submodule defaults and options
	for name, module in self:IterateModules() do
		local moddefaults = module:GetDefaults()
		mod.db:RegisterNamespace(name, moddefaults)
		mod.options.args[name] = module:GetOptions()
	end
	
	-- Generate profile selector
	mod.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	mod.options.args.profiles.order = -1
	
	-- Register all options
	LibStub("AceConfig-3.0"):RegisterOptionsTable(appName, mod.options, "rptb")
	
	-- Add to Blizzard options
	self.optionFrames = {}
	local ACD = LibStub("AceConfigDialog-3.0")
	self.optionFrames.general = ACD:AddToBlizOptions(appName, nil, nil, "general")
	self.optionFrames.plugins = {}
	
	-- Pull all the paenels into an array/collection, because we want them listed in Alphabetical Sequence
	local panels = {}	
	for name, module in self:IterateModules() do
		tinsert(panels,name)
	end

	-- Sort the Array, using the built in Sorting Algorithm
	sort(panels)

	--Cycle through the array and push them into the BlizOptions
	for i = 1, #panels do
		local name = panels[i]
		local sectionName = mod.options.args[name].name
		self.optionFrames.plugins[name] = ACD:AddToBlizOptions(appName, sectionName, appName, name)
	end

	--Add profiles last
	self.optionFrames.profiles = ACD:AddToBlizOptions(appName, "Profiles", appName, "profiles")
end

mod.options = {
	type = "group",
	get = function(info) return mod.db.profile[info[#info]] end, 
	set = function(info, val) mod.db.profile[info[#info]] = val end, 
	args = {

		general = {
			name = L["General settings"],
			type = "group",
			order = 1,
			args = {
				about1 = {
					type = "description",
					order = 1,
					name = "This addon allows you to view reputation bars in various ways as you grind your way to exalted."
				},
				
				hdr1 = {
					type = "header",
					order = 19,
					name = ""
				},
				
				modules = {
					type = "multiselect",
					order = 20,
					name = "Modules",
					desc = "Enable/disable the modules you would like to use.",
					cmdHidden = true,
					width = "full",
					values = function(info)
								local modules = {}
								for name, module in mod:IterateModules() do
									modules[name] = name
								end
								return modules;
							end,
					get =	function(info, key)
								return mod.db.profile.modules[key]
							end,
					set =	function(info, key, val)
								if val == nil then val = false end
								mod.db.profile.modules[key] = val
								
								if val then
									mod:EnableModule(key)
									local module = mod:GetModule(key)
									if module and module.OnProfileChanged then module:OnProfileChanged( mod:GetModuleDB(key) ) end
								else
									mod:DisableModule(key)
								end
							end,
				},

				spacer = {
					type = 'description',
					order = 100,
					name = "\n",
				},
				author = {
					type = 'description',
					name = "Addon developed by Pontus Munck aka Garderobert of Moonglade (EU)\n",
					order = 101,
				},
				thanks = {
					type = 'description',
					name = "Credits go to the Ace3 team for an excellent framework.\n",
					order = 102,
				},
				Attributions_103 = {
					type = 'description',
					name = "Continued support in Shadowlands and beyond by Karpana of Ysera (US)\n",
					order = 103,
				},
				Attributions_201 = {
					type = 'description',
					name = "\n****** THE WAR WITHIN ******\n",
					order = 201,
				},
				Attributions_202 = {
					type = 'description',
					name = "Jun-05-2024: The War Within API updates with reverse compatibility for 10.2.7\n",
					order = 202,
				},
				Attributions_203 = {
					type = 'description',
					name = "===> 10.2.7-0019 released\n",
					order = 203
				},
				Attributions_204 = {
					type = 'description',
					name = "Jun-26-2024: Update ToC for 11.0.0\n",
					order = 204,
				},
				Attributions_205 = {
					type = 'description',
					name = "Jun-26-2024: update internal version for 11.0.0\n",
					order = 205,
				},
				Attributions_206 = {
					type = 'description',
					name = "===> 11.0.0-0001 released\n",
					order = 206
				},
				Attributions_207 = {
					type = 'description',
					name = "Jul-21-2024: Update ToC for 11.0.2\n",
					order = 207,
				},
				Attributions_208 = {
					type = 'description',
					name = "===> 11.0.2-0002 released\n",
					order = 208
				},
				Attributions_209 = {
					type = 'description',
					name = "Jul-28-2024: Update api call for inactive reputations (resulting from TWW api warband changes\n",
					order = 209,
				},
				Attributions_210 = {
					type = 'description',
					name = "===> 11.0.2-0003 released\n",
					order = 210
				},
				Attributions_211 = {
					type = 'description',
					name = "Jul-28-2024: Updated ACE3 to r1349\n",
					order = 211,
				},
				Attributions_212 = {
					type = 'description',
					name = "===> 11.0.2-0004 released\n",
					order = 212
				},
				Attributions_213 = {
					type = 'description',
					name = "Nov-01-2024: Update the way Test bars are loaded (to handle language differences)\n",
					order = 213,
				},
				Attributions_214 = {
					type = 'description',
					name = "Nov-01-2024: Update COMBAT_TEXT_UPDATE event handler to properly capture faction name and recent earnings (thank you to modnarwave)\n",
					order = 214
				},
				Attributions_215 = {
					type = 'description',
					name = "Nov-01-2024: Update ToC for 11.0.5\n",
					order = 215,
				},
				Attributions_216 = {
					type = 'description',
					name = "===> 11.0.5-0005 released\n",
					order = 216
				},
				Attributions_217 = {
					type = 'description',
					name = "Nov-02-2024: Adjusted the way TestBars work so they don't error out on fresh characters\n",
					order = 217,
				},
				Attributions_218 = {
					type = 'description',
					name = "===> 11.0.5-0006 released\n",
					order = 218
				},
				Attributions_219 = {
					type = 'description',
					name = "Nov-02-2024: Fixed compile/load errorn",
					order = 219,
				},
				Attributions_220 = {
					type = 'description',
					name = "===> 11.0.5-0007 released\n",
					order = 220
				},
				Attributions_221 = {
					type = 'description',
					name = "Feb-04-2025: Update TOC for 11.1.0\n",
					order = 221,
				},
				Attributions_222 = {
					type = 'description',
					name = "===> 11.1.0-0008 released\n",
					order = 222
				},
				Attributions_223 = {
					type = 'description',
					name = "Feb-28-2025: Pre-emptively refactored faction processing\n",
					order = 223,
				},
				Attributions_224 = {
					type = 'description',
					name = "Mar-01-2025: Built forcible, and far from pretty, override for the disappearing faction problem affecting Hallowfall, Council of Dornogal, and Assembly.\n",
					order = 224,
				},
				Attributions_225 = {
					type = 'description',
					name = "Mar-02-2025: Fixed issue with Steamwheedle Cartel showing incorrect reputation gains in Staticbars.\n",
					order = 225,
				},
				Attributions_226 = {
					type = 'description',
					name = "Mar-02-2025: Fixed issue with Steamwheedle Cartel showing incorrect reputation gains in Autobars.\n",
					order = 226,
				},
				Attributions_227 = {
					type = 'description',
					name = "===> 11.1.0-0009 released\n",
					order = 227
				},
			},
		},
		
		config = {
			name = L["Show configuration"],
			type = "execute",
			func = function(info)
				mod:ShowConfig()
			end,
		},
	},
}

