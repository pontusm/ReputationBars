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

	for i = 1, factionCount do
		local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus

		if expansionLevel < 10 then 
			name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
		else
			local factionData=C_Reputation.GetFactionDataByIndex(i);
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
		
		local isParagon = factionID and C_Reputation.IsFactionParagon(factionID);
		local isMajorFaction = factionID and C_Reputation.IsMajorFaction(factionID);
		
		if not name or name == lastName and name ~= GUILD then break end
	
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
		if expansionLevel < 10 then
			local nsrt_isActive         = not IsFactionInactive(i)
		else
			local nsrt_isActive         = C_Reputation.IsFactionActive(i)
		end
		local nsrt_factionID        = factionID
		local nsrt_friendID
		local nsrt_isMajorFaction   = isMajorFaction
		local nsrt_hasRewardPending    = false
		local nsrt_RewardsCollected = 0

		ReputationBarsCommon:DebugLog("","RefreshAllFactions",5,"Loading/Updating '"..tostring(nsrt_name).."' into internal table")
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"Step1: nsrt_name            : "..tostring(nsrt_name))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_standingId      : "..tostring(nsrt_standingId))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_min             : "..tostring(nsrt_min))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_max             : "..tostring(nsrt_max))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_value           : "..tostring(nsrt_value))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isHeader        : "..tostring(nsrt_isHeader))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isChild         : "..tostring(nsrt_isChild))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_hasRep          : "..tostring(nsrt_hasRep))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isParagon       : "..tostring(nsrt_isParagon))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isActive        : "..tostring(nsrt_isActive))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_factionID       : "..tostring(nsrt_factionID))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_friendID        : "..tostring(nsrt_friendID))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isMajorFaction  : "..tostring(nsrt_isMajorFaction))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_hasRewardPending : "..tostring(nsrt_hasRewardPending))

		--Step 2) figure out if this is a friend (rather than a faction), and if so, override some of our base faction values.
		if nsrt_isHeader ~= true then
			--we need to do this different ways for Dragonflight vs Shadowlands
			if expansionLevel >= 9 then -- DragonFlight, The War Within, and beyond
				local retOK, FriendshipInfo = pcall(C_GossipInfo.GetFriendshipReputation, factionID)

				if retOK then --make sure pcall worked
					ReputationBarsCommon:DebugLog("WARN","RefreshAllFactions",6,"       ***C_GossipInfo.GetFriendshipReputation call successful")
					ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       FriendshipInfo: " .. tostring(FriendshipInfo))

					if FriendshipInfo ~= nil then --make sure that we actually got a value from the API call
					ReputationBarsCommon:DebugLog("WARN","RefreshAllFactions",6,"       FriendshipInfo.friendshipFactionID: " .. tostring(FriendshipInfo.friendshipFactionID))					
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
					ReputationBarsCommon:DebugLog("ERR","RefreshAllFactions",6,"       ***C_GossipInfo.GetFriendshipReputation call FAILED")
				end
			end
		end

		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"Step2: nsrt_min          : "..tostring(nsrt_min))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_max          : "..tostring(nsrt_max))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_value        : "..tostring(nsrt_value))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_friendID     : "..tostring(nsrt_friendID))

		--Step 3) figure out if this is a major faction (new for Shadowlands)
		if isMajorFaction then
			local majorFactionInfo = C_MajorFactions.GetMajorFactionData(factionID);
			nsrt_value = majorFactionInfo.renownReputationEarned
			nsrt_min = 0
			nsrt_max = majorFactionInfo.renownLevelThreshold
		end

		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"Step3: nsrt_isMajorFaction: "..tostring(nsrt_isMajorFaction))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_value         : "..tostring(nsrt_value))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_min           : "..tostring(nsrt_min))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_max           : "..tostring(nsrt_max))

		--Step 4) figure out if this is a paragon faction (extra rep beyond exalted), and if so, override some of our base faction values
		if isParagon then
			local currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevelForParagon = C_Reputation.GetFactionParagonInfo(factionID)
			nsrt_value = currentValue % threshold
			nsrt_min = 0
			nsrt_max = threshold
			nsrt_hasRewardPending = hasRewardPending
		end
		lastName = name

		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"Step4: nsrt_isParagon        : "..tostring(nsrt_isParagon))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_value            : "..tostring(nsrt_value))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_min              : "..tostring(nsrt_min))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_max              : "..tostring(nsrt_max))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_hasRewardPending : "..tostring(nsrt_RewardPending))

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

		if isCollapsed then
			if expansionLevel < 10 then
				ExpandFactionHeader(i)
			else
				C_Reputation.ExpandFactionHeader(i)
			end
		end
	end

	allFactions = factions
	ReputationBarsCommon:DebugLog("OK","RefreshAllFactions",4,"Function Call Finished...")
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
		if factionIndex and (not IsFactionInactive(factionIndex) or presentGainsForInactiveReputations) then
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
	if (type == "FACTION") then
		if IsInGuild() then
			-- Check name for guild reputation
			if name == GUILD then
				name = (GetGuildInfo("player"))
				if not name or name == "" then return end
			end
		end
	
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
				Attributions_115 = {
					type = 'description',
					name = "\n****** DRAGONFLIGHT ******\n",
					order = 115,
				},
				Attributions_116 = {
					type = 'description',
					name = "Sep-25-2022: Dragonflight API updates\n",
					order = 116,
				},
				Attributions_117 = {
					type = 'description',
					name = "Sep-25-2022: Proper and Final (hopefully?) fix for non-standard reputations (friends, NatPagle, Venari, Achivists, etc...)\n",
					order = 117,
				},
				Attributions_118 = {
					type = 'description',
					name = "Sep-26-2022: Quality of Life Updates to show 'Paragon' instead of exalted for those factions that have a paragon mode\n",
					order = 118,
				},
				Attributions_119 = {
					type = 'description',
					name = "Sep-26-2022: Addition of Scrollbars for faction checkboxes\n",
					order = 119,
				},
				Attributions_120 = {
					type = 'description',
					name = "Sep-26-2022: Update of ACE3 libs to r1281\n",
					order = 120,
				},
				Attributions_121 = {
					type = 'description',
					name = "Sep-27-2022: Pre-preparations for multiple/additional StaticBars\n",
					order = 121,
				},
				Attributions_0122 = {
					type = 'description',
					name = "Sep-28-2022: Creation of StaticBars 3 thru 9\n",
					order = 122,
				},
				Attributions_124 = {
					type = 'description',
					name = "Sep-30-2022: Refactored StaticBars code\n",
					order = 124,
				},
				Attributions_125 = {
					type = 'description',
					name = "Oct-18-2022: Override option in Autobars to change default ignore behaviour\n",
					order = 125,
				},
				Attributions_126 = {
					type = 'description',
					name = "Oct-24-2022: Prevent recent gains from disappearing in Autobars after hovering mouse on bar\n",
					order = 126,
				},
				Attributions_127 = {
					type = 'description',
					name = "Oct-26-2022: Fix incorrect friend logic\n",
					order = 127,
				},
				Attributions_128 = {
					type = 'description',
					name = "Oct-26-2022: Update of ACE3 libs to r1294\n",
					order = 128,
				},
				Attributions_129 = {
					type = 'description',
					name = "Oct-26-2022: QOL updates for friend reputations\n",
					order = 129,
				},
				Attributions_130 = {
					type = 'description',
					name = "Oct-27-2022: More QOL updates for friend reputations\n",
					order = 130,
				},
				Attributions_0131 = {
					type = 'description',
					name = "Oct-27-2022: Error Trapping/Handling for call to C_GossipInfo.GetFriendshipReputation\n",
					order = 131,
				},
				Attributions_132 = {
					type = 'description',
					name = "===> 10.0.2-0007 released\n",
					order = 132,
				},
				Attributions_133 = {
					type = 'description',
					name = "Nov-06-2022: TOC update for 10.0.2\n",
					order = 133,
				},
				Attributions_134 = {
					type = 'description',
					name = "===> 10.0.2-0008 released\n",
					order = 134,
				},
				Attributions_135 = {
					type = 'description',
					name = "Nov-27-2022: Attempt to fix/address 'upvalue bug'\n",
					order = 135,
				},
				Attributions_136 = {
					type = 'description',
					name = "===> 10.0.2-0009 released\n",
					order = 136,
				},
				Attributions_137 = {
					type = 'description',
					name = "Nov-27-2022: Enhancements for 'Major Factions' (factions with renown) introduced in Dragonflight\n",
					order = 137,
				},
				Attributions_138 = {
					type = 'description',
					name = "Nov-27-2022: Cleanup of Friendship Code\n",
					order = 138,
				},
				Attributions_139 = {
					type = 'description',
					name = "Nov-27-2022: Removal of deprecated Shadowlands code\n",
					order = 139,
				},
				Attributions_140 = {
					type = 'description',
					name = "===> 10.0.2-0010 released\n",
					order = 140,
				},
				Attributions_141 = {
					type = 'description',
					name = "Jan-18-2023: Reprioritized processing sequence for faction attributes to fix Major Factions as Paragons\n",
					order = 141,
				},
				Attributions_142 = {
					type = 'description',
					name = "===> 10.0.2-0011 released\n",
					order = 142,
				},
				Attributions_143 = {
					type = 'description',
					name = "Jan-24-2023: ToC Updates for 10.0.5\n",
					order = 143,
				},
				Attributions_144 = {
					type = 'description',
					name = "===> 10.0.5-0012 released\n",
					order = 144,
				},
				Attributions_145 = {
					type = 'description',
					name = "Jan-28-2023: minor QoL for Paragon Rewards\n",
					order = 145,
				},
				Attributions_146 = {
					type = 'description',
					name = "Mar-21-2023: ToC Updates for 10.0.7\n",
					order = 146,
				},
				Attributions_147 = {
					type = 'description',
					name = "===> 10.0.7-0013 released\n",
					order = 147,
				},
				Attributions_148 = {
					type = 'description',
					name = "May-03-2023: ToC Updates for 10.1.0\n",
					order = 148,
				},
				Attributions_149 = {
					type = 'description',
					name = "===> 10.1.0-0014 released\n",
					order = 149,
				},
				Attributions_150 = {
					type = 'description',
					name = "May-05-2023: Icon for Reputation Bars\n",
					order = 150,
				},
				Attributions_151 = {
					type = 'description',
					name = "Jul-11-2023: ToC Updates for 10.1.5\n",
					order = 151,
				},
				Attributions_152 = {
					type = 'description',
					name = "===> 10.1.5-0015 released\n",
					order = 152,
				},
				Attributions_153 = {
					type = 'description',
					name = "Jun-01-2024: ToC Updates for 10.2.7\n",
					order = 153,
				},
				Attributions_154 = {
					type = 'description',
					name = "Jun-01-2024: Undo code refactoring from Oct-2022 due to a blizz chnage with 10.2.7 that causes errors and warning on ui load duet duplicate file load\n",
					order = 154,
				},
				Attributions_155 = {
					type = 'description',
					name = "===> 10.2.7-0016 released\n",
					order = 155,
				},
				Attributions_156 = {
					type = 'description',
					name = "Jun-05-2024: Formal retirement of WatchBars\n",
					order = 156,
				},
				Attributions_157 = {
					type = 'description',
					name = "Jun-05-2024: Update of ACE3 libs to r1341\n",
					order = 157,
				},
				Attributions_158 = {
					type = 'description',
					name = "Jun-06-2024: Update of AceGui-3.0-SharedMediaWidgets libs to r65\n",
					order = 158,
				},
				Attributions_159 = {
					type = 'description',
					name = "===> 10.2.7-0019 released\n",
					order = 159
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
