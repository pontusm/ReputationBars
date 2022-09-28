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
	for i = 1, #allFactions do
		local name, _, _, _, _, _, _, _, _, _, _, _, _ = GetFactionInfo(i); --added 2 or 3 _, to the end
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
	local oldAmount = factionAmounts[name]
	if oldAmount ~= nil and oldAmount ~= amount then
		-- Collect all gained reputation before notifying modules
		reputationChanges[name] = amount - oldAmount
--		print("Faction "..name.." changed from "..oldAmount.." to "..amount)
	end
	factionAmounts[name] = amount
end

-- Refresh the list of known factions
function mod:RefreshAllFactions()

	local expansionLevel = GetClientDisplayExpansionLevel()
	--if DLAPI then DLAPI.DebugLog("ReputationBars", "expansionLevel: %s", tostring(expansionLevel)) end

	local i = 1
	local lastName
	local factions = {}
	--ExpandAllFactionHeaders()
	for i = 1, GetNumFactions() do
		local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
			canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)

		if not name or name == lastName and name ~= GUILD then break end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "ReputationBars.lua @ 139") end
	    --if DLAPI then DLAPI.DebugLog("ReputationBars", "          factionIndex: %s",tostring(i)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          name: %s", tostring(name)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          description: %s", tostring(description)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          standingID: %s", tostring(standingId)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          bottomValue: %s", tostring(bottomValue)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          topValue: %s", tostring(topValue)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          earnedValue: %s", tostring(earnedValue)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          atWarWith: %s", tostring(atWarWith)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          canToggleAtWar: %s", tostring(canToggleAtWar)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          isHeader: %s", tostring(isHeader)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          isCollapsed: %s", tostring(isCollapsed)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          hasRep: %s", tostring(hasRep)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          isWatched: %s", tostring(isWatched)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          isChild: %s", tostring(isChild)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          factionID: %s", tostring(factionID)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          hasBonusRepGain: %s", tostring(hasBonusRepGain)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          canBeLFGBonus: %s", tostring(canBeLFGBonus)) end

			
		--define and populate (with faction data) all our "insert variables" for our internal table
        local nsrt_name       = name
		local nsrt_standingId = standingId
		local nsrt_min        = bottomValue
		local nsrt_max        = topValue
		local nsrt_value      = earnedValue
		local nsrt_isHeader   = isHeader
		local nsrt_isChild    = isChild
		local nsrt_hasRep     = hasRep
		local nsrt_isParagon = false
		local nsrt_isActive   = not IsFactionInactive(i)
		local nsrt_factionID  = factionID
		local nsrt_friendID
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          isActive (dervied): %s", tostring(nsrt_isActive)) end

        if nsrt_isheader == true then
			--figure out if this is a friend (rather than a faction), and if so, override some of our base faction values.
			if expansionLevel >= 9 then -- DragonFlight
				--***************************************--
				--*       D R A G O N F L I G H T       *--
				--***************************************--
				local FriendshipInfo= C_GossipInfo.GetFriendshipReputation(factionID)

				if FriendshipInfo.friendshipFactionID ~= 0 then
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> friendshipFactionID: %s", tostring(FriendshipInfo.friendshipFactionID)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> standing: %s", tostring(FriendshipInfo.standing)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> maxRep: %s", tostring(FriendshipInfo.maxRep)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> name: %s", tostring(FriendshipInfo.name)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> text: %s", tostring(FriendshipInfo.text)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> texture: %s", tostring(FriendshipInfo.texture)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> reaction: %s", tostring(FriendshipInfo.reaction)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> reactionThreshold: %s", tostring(FriendshipInfo.reactionThreshold)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nextThreshold: %s", tostring(FriendshipInfo.nextThreshold)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> reversedColor: %s", tostring(FriendshipInfo.reversedColor)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> overrideColor: %s", tostring(FriendshipInfo.overrideColor)) end
					if FriendshipInfo.nextThreshold ~= nil then --handle a weird scenario where the faction is a friend, but has no thresholds...
						nsrt_min = FriendshipInfo.reactionThreshold
						nsrt_max = FriendshipInfo.nextThreshold
						nsrt_value = FriendshipInfo.standing
						nsrt_friendID = FriendshipInfo.friendshipFactionID
					end
				end
			else --Shadowlands
				--***************************************--
				--*        S H A D O W L A N D S        *--
				--***************************************--
				local x_friendID, x_friendRep, x_friendMaxRep, x_friendName, x_friendText, x_friendTexture, x_friendTextLevel, x_friendThreshhold , x_nextFriendThreshold = GetFriendshipReputation(factionID)
				if x_friendID then 
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> friendshipFactionID: %s", tostring(FriendshipInfo.friendshipFactionID)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> standing: %s", tostring(FriendshipInfo.standing)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> maxRep: %s", tostring(FriendshipInfo.maxRep)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> name: %s", tostring(FriendshipInfo.name)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> text: %s", tostring(FriendshipInfo.text)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> texture: %s", tostring(FriendshipInfo.texture)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> reaction: %s", tostring(FriendshipInfo.reaction)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> reactionThreshold: %s", tostring(FriendshipInfo.reactionThreshold)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nextThreshold: %s", tostring(FriendshipInfo.nextThreshold)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> reversedColor: %s", tostring(FriendshipInfo.reversedColor)) end
					--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> overrideColor: %s", tostring(FriendshipInfo.overrideColor)) end
					if x_nextFriendThreshold ~= nil then --handle a weird scenario where the faction is a friend, but has no thresholds...
						nsrt_min = x_friendThreshold
						nsrt_max = x_nextFriendThreshold-- ????FriendshipInfo.nextThreshold
						nsrt_value = x_friendRep
						nsrt_friendID = x_fiendID
					end
				end
			end
		end


        --figure out if this is a paragon faction (extra rep beyond exalted), and if so, override some of our base faction values
		if factionID and C_Reputation.IsFactionParagon(factionID) then
			nsrt_isParagon = true
			local currentValue, threshold, rewardQuestID, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
			--if DLAPI then DLAPI.DebugLog("ReputationBars", "          ==> currentValue: %s", tostring(currentValue)) end
			--if DLAPI then DLAPI.DebugLog("ReputationBars", "          ==> threshold: %s", tostring(threshold)) end
			--if DLAPI then DLAPI.DebugLog("ReputationBars", "          ==> rewardQuestID: %s", tostring(rewardQuestID)) end
			--if DLAPI then DLAPI.DebugLog("ReputationBars", "          ==> hasRewardPending: %s", tostring(hasRewardPending)) end
			nsrt_value = currentValue % threshold
			nsrt_min = 0
			nsrt_max = threshold
		end
		lastName = name

		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> -----------------------------") end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_name: %s", tostring(nsrt_name)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_standingId: %s", tostring(nsrt_standingId)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_min: %s", tostring(nsrt_min)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_max: %s", tostring(nsrt_max)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_value: %s", tostring(nsrt_value)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_isHeader: %s", tostring(nsrt_isHeader)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_isChild: %s", tostring(nsrt_isChild)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_hasRep: %s", tostring(nsrt_hasRep)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_isParagon: %s", tostring(nsrt_isParagon)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_isActive: %s", tostring(nsrt_isActive)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_factionID: %s", tostring(nsrt_factionID)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> nsrt_friendID: %s", tostring(nsrt_friendID)) end
		--if DLAPI then DLAPI.DebugLog("ReputationBars", "          --> -----------------------------") end


		tinsert(factions, {
			name       = nsrt_name,
			standingId = nsrt_standingId,
			min        = nsrt_min,
			max        = nsrt_max,
			value      = nsrt_value,
			isHeader   = nsrt_isHeader,
			isChild    = nsrt_isChild,
			hasRep     = nsrt_hasRep,
			isParagon  = nsrt_isParagon,
			isActive   = nsrt_isActive,
			factionID  = nsrt_factionID,
			friendID   = nsrt_friendID
		})	

		
		UpdateFactionAmount(name, earnedValue)
		if isCollapsed then ExpandFactionHeader(i) end
	end

	allFactions = factions
end

------------------------------------------------------------------------------
-- Ensure factions and guild info are loaded
------------------------------------------------------------------------------
function mod:EnsureFactionsLoaded()
	-- Sometimes it takes a while for faction and guild info
	-- to load when the game boots up so we need to periodically
	-- check whether its loaded before we can display it
	if GetFactionInfo(1) == nil or (IsInGuild() and GetGuildInfo("player") == nil) then
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

	-- Build sorted change table
	local changes = {}
	for name, amount in pairs(reputationChanges) do
		-- Skip inactive factions
		local factionIndex = self:GetFactionIndex(name)
		if factionIndex and not IsFactionInactive(factionIndex) then
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
				Attributions_000 = {
					type = 'description',
					name = "Continued support in Shadowlands and beyond by Karpana of Arygos (US)\n",
					order = 103,
				},

				Attributions_001 = {
					type = 'description',
					name = "\n\n****** SHADOWLANDS ******\n",
					order = 104,
				},
				Attributions_002 = {
					type = 'description',
					name = "Oct-18-2020: Shadowlands stabilization fixes\n",
					order = 105,
				},
				Attributions_003 = {
					type = 'description',
					name = "Feb-01-2021: Inclusion of secondary StaticBars\n",
					order = 106,
				},
				Attributions_004 = {
					type = 'description',
					name = "Mar-07-2021: Updated for 9.0.5\n",
					order = 107,
				},
				Attributions_005 = {
					type = 'description',
					name = "Jun-29-2021: Updated for 9.1.0\n",
					order = 108,
				},
				Attributions_006 = {
					type = 'description',
					name = "Jul-25-2021: Ve'nari Paragon Reputation updates\n",
					order = 109,
				},
				Attributions_007 = {
					type = 'description',
					name = "Jul-25-2021: Archivist's Codex Paragaon Reputation updates.   Many Thanks to Mithrasangel!!!\n",
					order = 110,
				},
				Attributions_008 = {
					type = 'description',
					name = "Oct-22-2021: Second fix for Archivist's Codex Paragon Reputation\n",
					order = 111,
				},
				Attributions_009 = {
					type = 'description',
					name = "Oct-22-2021: Updated for 9.1.5\n",
					order = 112,
				},
				Attributions_010 = {
					type = 'description',
					name = "Feb-01-2022: Updated for 9.2.0\n",
					order = 113,
				},
				Attributions_011 = {
					type = 'description',
					name = "Sep-25-2022: Updated for 9.2.7\n",
					order = 114,
				},
				Attributions_012 = {
					type = 'description',
					name = "\n****** DRAGONFLIGHT ******\n",
					order = 115,
				},
				Attributions_013 = {
					type = 'description',
					name = "Sep-25-2022: Dragonflight API updates\n",
					order = 116,
				},
				Attributions_014 = {
					type = 'description',
					name = "Sep-25-2022: Proper and Final (hopefully?) fix for non-standard reputations (friends, NatPagle, Venari, Achivists, etc...)\n",
					order = 117,
				},
				Attributions_015 = {
					type = 'description',
					name = "Sep-26-2022: Quality of Life Updates to show 'Paragon' instead of exalted for those factions that have a paragon mode\n",
					order = 118,
				},
				Attributions_016 = {
					type = 'description',
					name = "Sep-26-2022: Addition of Scrollbars for faction checkboxes\n",
					order = 119,
				},
				Attributions_017 = {
					type = 'description',
					name = "Sep-26-2022: Update of ACE3 libs to r1281\n",
					order = 120,
				},
				Attributions_018 = {
					type = 'description',
					name = "Sep-28-2022: Pre-preparations for multiple/additional StaticBars\n",
					order = 121,
				},

				

				Attributions_998 = {
					type = 'description',
					name = "\n****** KNOWN ISSUES ******\n",
					order = 998,
				},
				Attributions_999 = {
					type = 'description',
					name = "Watch Bars throw LUA errors and fail to properly function\n",
					order = 999,
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
