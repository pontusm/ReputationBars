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
	if moduleName and #moduleName > 0 then
		InterfaceOptionsFrame_OpenToCategory(self.optionFrames.plugins[moduleName])
	else
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
end

function mod:GetFactionInfo(factionIndex)
	return allFactions[factionIndex]
end

function mod:GetAllFactions()
	return allFactions
end

-- Refresh the list of known factions
function mod:RefreshAllFactions()
	local i = 1
	local lastName
	local factions = {}
	repeat
		-- name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
		--  canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(factionIndex)
		local name, _, standingId, bottomValue, topValue, earnedValue, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(i)
		if not name or name == lastName and name ~= GUILD then break end
		local friendID, friendRep, friendMaxRep, _, _, _, friendTextLevel, friendThresh = GetFriendshipReputation(factionID)
		if (friendID ~= nil) then
			bottomValue = friendThresh
			if nextThresh then
				topValue = friendThresh + min( friendMaxRep - friendThresh, 8400 ) -- Magic number! Yay!
			end
			earnedValue = friendRep
		end
		lastName = name
		tinsert(factions, {
			name = name,
			standingId = standingId,
			min = bottomValue,
			max = topValue,
			value = earnedValue,
			isHeader = isHeader,
			hasRep = hasRep,
			isActive = not IsFactionInactive(i),
			factionID = factionID,
			friendID = friendID
		})
		i = i + 1
	until i > 100
	
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
		if not reputationChanges[name] then
			reputationChanges[name] = amount
		else
			reputationChanges[name] = reputationChanges[name] + amount
		end

		if timer then
			self:CancelTimer(timer, true)
		end
		timer = self:ScheduleTimer("UpdateReputation", 0.1)

		--self:Print("Gained "..amount.." with "..name)
	end
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
	for name, module in self:IterateModules() do
		local sectionName = mod.options.args[name].name
		self.optionFrames.plugins[name] = ACD:AddToBlizOptions(appName, sectionName, appName, name)
	end

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
					order = 99,
					name = "\n\n\n\n\n\n\n",
				},
				hdr2 = {
					type = 'header',
					name = "",
					order = 100,
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
