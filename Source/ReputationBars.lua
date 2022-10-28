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
		local name, _, _, _, _, _, _, _, _, _, _, _, _ = GetFactionInfo(i); 
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
	for i = 1, GetNumFactions() do
		local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
			canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)

		if not name or name == lastName and name ~= GUILD then break end
		
		--Step 1) define and populate (with faction data) all our "insert variables" for our internal table
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

		ReputationBarsCommon:DebugLog("","RefreshAllFactions",5,"Loading/Updating '"..tostring(nsrt_name).."' into internal table")
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"Step1: nsrt_name      : "..tostring(nsrt_name))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_standingId: "..tostring(nsrt_standingId))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_min       : "..tostring(nsrt_min))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_max       : "..tostring(nsrt_max))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_value     : "..tostring(nsrt_value))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isHeader  : "..tostring(nsrt_isHeader))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isChild   : "..tostring(nsrt_isChild))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_hasRep    : "..tostring(nsrt_hasRep))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isParagon : "..tostring(nsrt_isParagon))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_isActive  : "..tostring(nsrt_isActive))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_factionID : "..tostring(nsrt_factionID))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_friendID  : "..tostring(nsrt_friendID))

        --Step 2) figure out if this is a friend (rather than a faction), and if so, override some of our base faction values.
		if nsrt_isHeader ~= true then
			--we need to do this different ways for Dragonflight vs Shadowlands
			if expansionLevel >= 9 then -- DragonFlight
				--***************************************--
				--*       D R A G O N F L I G H T       *--
				--***************************************--
                --wrap in pcall instead--local FriendshipInfo= C_GossipInfo.GetFriendshipReputation(factionID)
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
--			else 
--				--***************************************--
--				--*        S H A D O W L A N D S        *--
--				--***************************************--
--				local x_friendID, x_friendRep, x_friendMaxRep, x_friendName, x_friendText, x_friendTexture, x_friendTextLevel, x_friendThreshhold , x_nextFriendThreshold = GetFriendshipReputation(factionID)
--				if x_friendID then 
--					if x_nextFriendThreshold ~= nil then --handle a weird scenario where the faction is a friend, but has no thresholds...
--						nsrt_min = x_friendThreshold
--						nsrt_max = x_nextFriendThreshold
--						nsrt_value = x_friendRep
--						nsrt_friendID = x_fiendID
--					end
--				end
			end
		end

		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"Step2: nsrt_min     : "..tostring(nsrt_min))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_max     : "..tostring(nsrt_max))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_value   : "..tostring(nsrt_value))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_friendID: "..tostring(nsrt_friendID))

        --Step 3) figure out if this is a paragon faction (extra rep beyond exalted), and if so, override some of our base faction values
		if factionID and C_Reputation.IsFactionParagon(factionID) then
			nsrt_isParagon = true
			local currentValue, threshold, rewardQuestID, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
			nsrt_value = currentValue % threshold
			nsrt_min = 0
			nsrt_max = threshold
		end
		lastName = name

		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"Step3: nsrt_isParagon: "..tostring(nsrt_isParagon))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_value    : "..tostring(nsrt_value))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_min      : "..tostring(nsrt_min))
		ReputationBarsCommon:DebugLog("","RefreshAllFactions",6,"       nsrt_max      : "..tostring(nsrt_max))

		--Step 4) *phew* that was a lot of work, save it before it's too late...
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
		
		UpdateFactionAmount(name, nsrt_value)
		if isCollapsed then ExpandFactionHeader(i) end
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
					name = "Sep-27-2022: Pre-preparations for multiple/additional StaticBars\n",
					order = 121,
				},
				Attributions_019 = {
					type = 'description',
					name = "Sep-28-2022: Creation of StaticBars 3 thru 9\n",
					order = 122,
				},
				Attributions_021 = {
					type = 'description',
					name = "Sep-30-2022: Refactored StaticBars code\n",
					order = 124,
				},
				Attributions_022 = {
					type = 'description',
					name = "Oct-18-2022: Override option in Autobars to change default ignore behaviour\n",
					order = 125,
				},
				Attributions_023 = {
					type = 'description',
					name = "Oct-24-2022: Prevent recent gains from disappearing in Autobars after hovering mouse on bar\n",
					order = 126,
				},
				Attributions_024 = {
					type = 'description',
					name = "Oct-26-2022: Fix incorrect friend logic\n",
					order = 127,
				},
				Attributions_025 = {
					type = 'description',
					name = "Oct-26-2022: Update of ACE3 libs to r1294\n",
					order = 128,
				},
				Attributions_026 = {
					type = 'description',
					name = "Oct-26-2022: QOL updates for friend reputations\n",
					order = 129,
				},
				Attributions_027 = {
					type = 'description',
					name = "Oct-27-2022: More QOL updates for friend reputations\n",
					order = 130,
				},
				Attributions_028 = {
					type = 'description',
					name = "Oct-27-2022: Error Trapping/Handling for call to C_GossipInfo.GetFriendshipReputation\n",
					order = 131,
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
