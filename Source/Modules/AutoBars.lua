-- ReputationBars: AutoBars
local appName = "ReputationBars"
local modName = "AutoBars"

local ReputationBars = LibStub("AceAddon-3.0"):GetAddon(appName)
ReputationBars_AutoBars = ReputationBars:NewModule(modName, "AceEvent-3.0")
local mod = ReputationBars_AutoBars

local L = LibStub("AceLocale-3.0"):GetLocale(appName)

local LSM = LibStub("LibSharedMedia-3.0")

local AutoBarsGroup

local db
local fadeTimer, cleanupTimer, sortTimer
local hidden
local hovering

local factionSlideDuration = 1

local factions = {}
local barlist = {}

-- Default settings
local defaults = {
	profile = {
		locked = false,
		showLosses = true,
		ignoreSplashRep = false,
		autoHide = true,
		autoHideSeconds = 30,
		removeInactiveFactions = true,
		removeFactionSeconds = 180,
		presentGainsForInactiveReputations = false,

		barFont = "Bazooka",
		barFontSize = 11,
		barFontOutline = "OUTLINE",

		barAlpha = 1,
		barTexture = "Fifths",
		barLength = 200,
		barThickness = 25,
		barScale = 1,

		growUp = false,
		showText = "always",
	}
}

function mod:GetDefaults()
	return defaults
end

function mod:OnInitialize()
end

-------------------------------------------------------------------------------
-- Show/hide
-------------------------------------------------------------------------------
local function FadeOutCompleted()
	if not db.locked then
		AutoBarsGroup:Lock()
		AutoBarsGroup:HideAnchor()
	end
end

local function FadeOut()
	local time = 5
	if hidden then return end
	UIFrameFadeOut(AutoBarsGroup, time, AutoBarsGroup:GetAlpha(), 0)
	hidden = true
	if fadeTimer then ReputationBars:CancelTimer(fadeTimer, true) end
	fadeTimer = ReputationBars:ScheduleTimer(FadeOutCompleted, time)
end

local function FadeIn(time)
	if db.autoHide then
		if fadeTimer then
			ReputationBars:CancelTimer(fadeTimer, true)
		end
		fadeTimer = ReputationBars:ScheduleTimer(FadeOut, db.autoHideSeconds)
	end

	if not db.locked then
		AutoBarsGroup:Unlock()
		AutoBarsGroup:ShowAnchor()
	end

	if not hidden then return end
	UIFrameFadeIn(AutoBarsGroup, time, AutoBarsGroup:GetAlpha(), db.barAlpha)
	hidden = false
end

-------------------------------------------------------------------------------
-- Enable/disable
-------------------------------------------------------------------------------
function mod:OnEnable()
	self.db = ReputationBars:GetModuleDB(modName)
	db = self.db.profile

	-- Initial load?
	if not AutoBarsGroup then
		hidden = true
		self:InitializeBar()
		AutoBarsGroup:SetAlpha(0)
		FadeIn(5)
	else
		self:UpdateBar(true)
		AutoBarsGroup:Show()
	end

	self:RegisterEvent("PET_BATTLE_OPENING_START")
	self:RegisterEvent("PET_BATTLE_CLOSE")
	
	cleanupTimer = ReputationBars:ScheduleRepeatingTimer(mod.Cleanup, 1)
end

function mod:OnDisable()
	if AutoBarsGroup then
		AutoBarsGroup:Hide()
	end
	if cleanupTimer then
		ReputationBars:CancelTimer(cleanupTimer, true)
		cleanupTimer = nil
	end

	db = nil
	self.db = nil
end

-------------------------------------------------------------------------------
-- Bar update
-------------------------------------------------------------------------------
local function CompareBarSortOrder(a, b)
	if not a.sortOrder or type(a.sortOrder) ~= "number" then return true end
	if not b.sortOrder or type(b.sortOrder) ~= "number" then return false end
	return a.sortOrder < b.sortOrder
end

local function UpdateBarVisual()
	local now = time()
	local allFactions = ReputationBars:GetAllFactions()
	for factionIndex = 1, #allFactions do
		local fi = allFactions[factionIndex]
		local name = fi.name
		local faction = factions[name]
		if faction and (now - faction.lastUpdate) < db.removeFactionSeconds then
			local bar = faction.bar
			if not bar then
				-- Create new bar
				bar = AutoBarsGroup:NewCounterBar(modName..factionIndex, nil, 0, 100)
				bar.label:ClearAllPoints()
				bar.label:SetPoint("CENTER", bar, "CENTER", 0, 0)

				-- Remember bar position
				tinsert(barlist, name)
				bar.sortOrder = #barlist

				UIFrameFadeIn(bar, 0.5, 0, 1)

				bar:EnableMouse(true)
				bar:SetScript("OnEnter", function(frame)
					hovering = frame
					mod:UpdateBar(true)
				end)
				bar:SetScript("OnLeave", function(frame)
					hovering = nil
					UpdateBarVisual()
				end)
				
				faction.bar = bar
				
				AutoBarsGroup:SortBars()
			end

			local colorIndex
			if fi.friendID ~= nil then colorIndex = 5 else colorIndex = fi.standingId end
			local colors = FACTION_BAR_COLORS[colorIndex]
			bar:UnsetAllColors()
			bar:SetColorAt(0, colors.r, colors.g, colors.b, 1)

			local recentGainText = ""
			--if (now - faction.lastUpdate) < 60 then                          --Karp removed this on Oct 24 2022 to prevent recent gains from disappearing on mouse hover
			recentGainText = string.format(" |cffedf55f(%+d)", faction.amount)
			--end                                                              --Karp removed this on Oct 24 2022 to prevent recent gains from disappearing on mouse hover

			local displayMax = fi.max - fi.min
			local displayVal = fi.value - fi.min
			bar:SetValue(displayVal, displayMax)

			local barLabel
			if db.showText == "never" or (db.showText == "mouseover" and hovering ~= bar) then
				barLabel = ""
			else
				if hovering == bar and db.showText ~= "mouseover" then
					if fi.isParagon then
						barLabel = string.format("%s",L["Paragon"])
					elseif fi.isMajorFaction then
						local majorFactionInfo = C_MajorFactions.GetMajorFactionData(fi.factionID);
						barLabel = string.format("%s%s |cffedf55f(%d to go)", RENOWN_LEVEL_LABEL, majorFactionInfo.renownLevel, displayMax-displayVal)
					elseif fi.friendID ~= nil then
						local FriendshipInfo = C_GossipInfo.GetFriendshipReputation(fi.factionID)
						friendTextLevel = FriendshipInfo.reaction
						barLabel = string.format("%s", friendTextLevel)
					else
						local gender = UnitSex("player")
						local standingText = GetText("FACTION_STANDING_LABEL"..fi.standingId, gender)
						if fi.standingId < 8 then
							local nextStandingText = GetText("FACTION_STANDING_LABEL"..fi.standingId+1, gender);
							barLabel = string.format("%s |cffedf55f(%d to %s)", standingText, displayMax-displayVal, nextStandingText)
						else
							barLabel = string.format("%s", standingText)
						end
					end
				else
					barLabel = string.format("%s (%d / %d)%s", name, displayVal, displayMax, recentGainText)
				end
			end
			
			bar:SetLabel(barLabel)
		end
	end

end

function mod:UpdateBar(ensureVisible)
	if ensureVisible then FadeIn(0.5) end
	UpdateBarVisual()
end

-------------------------------------------------------------------------------
-- Anchor
-------------------------------------------------------------------------------
function mod:AnchorClicked(cbk, group, button)
	if button == "RightButton" then
		ReputationBars:ShowConfig(modName)
	end
end

function mod:AnchorMoved(cbk, group, x, y)
	self:SavePosition()
end

local function OnEnterAnchor(frame)
	GameTooltip:SetOwner(frame)
	GameTooltip:AddLine(appName .. " : "..modName)
	GameTooltip:AddLine(L["|cffeda55fDrag|r to move the frame"])
	GameTooltip:AddLine(L["|cffeda55fRight Click|r to open the configuration window"])
	GameTooltip:Show()
end

local function OnLeaveAnchor(frame)
	GameTooltip:Hide()
end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------
function mod:InitializeBar()
	if not AutoBarsGroup then
		AutoBarsGroup = ReputationBars:NewBarGroup("Reputation : " .. modName, nil, 200, 12, appName .. "_"..modName)

		AutoBarsGroup.RegisterCallback(self, "AnchorClicked")
		AutoBarsGroup.RegisterCallback(self, "AnchorMoved")
		AutoBarsGroup:HideIcon()
		AutoBarsGroup.button:SetScript("OnEnter", OnEnterAnchor)
		AutoBarsGroup.button:SetScript("OnLeave", OnLeaveAnchor)

		AutoBarsGroup:SetSortFunction(CompareBarSortOrder)
	end

	self:ApplySettings()
	self:LoadPosition()
end

-------------------------------------------------------------------------------
-- Profile/settings
-------------------------------------------------------------------------------
function mod:OnProfileChanged(newdb)
	self.db = newdb
	db = self.db.profile
	self:ApplySettings()
	self:LoadPosition()
	self:UpdateBar(true)
end

function mod:ApplySettings()
	if db.locked then
		AutoBarsGroup:Lock()
		AutoBarsGroup:HideAnchor()
	else
		AutoBarsGroup:Unlock()
		AutoBarsGroup:ShowAnchor()
	end

	local font = LSM:Fetch("font", db.barFont)
	AutoBarsGroup:SetFont(font, db.barFontSize, db.barFontOutline)

	local texture = LSM:Fetch("statusbar", db.barTexture)
	AutoBarsGroup:SetTexture(texture)

	AutoBarsGroup:ReverseGrowth(db.growUp)
	AutoBarsGroup:SetAlpha(db.barAlpha)
	AutoBarsGroup:SetScale(db.barScale)
	AutoBarsGroup:SetLength(db.barLength)
	AutoBarsGroup:SetThickness(db.barThickness)
end



-------------------------------------------------------------------------------
-- Update reputation
-------------------------------------------------------------------------------
function mod:UpdateReputation(changes)
	for i, faction in ipairs(changes) do
		-- Only show largest gain?
		if db.ignoreSplashRep and i > 1 then break end

		local name = faction.name
		if not factions[name] then
			factions[name] = {}
			factions[name].amount = faction.amount
		else
			factions[name].amount = factions[name].amount + faction.amount
		end
		factions[name].lastUpdate = time()
	end

	self:UpdateBar(true)
end

function ReputationBars_AutoBars:overrideInactiveReputations()
	ReputationBarsCommon:DebugLog("","ReputationBars_AutoBars:overrideInactiveReputations",6,"===> Function Started")

	local retVal = false

	if db ~= nil then
		ReputationBarsCommon:DebugLog("OK","ReputationBars_AutoBars:overrideInactiveReputations",6,"db is not nil")
		if db.presentGainsForInactiveReputations ~= nil then
			ReputationBarsCommon:DebugLog("OK","ReputationBars_AutoBars:overrideInactiveReputations",6,"db.presentGainsForInactiveReputations is not nil")
			retVal = db.presentGainsForInactiveReputations
		else
			ReputationBarsCommon:DebugLog("ERR","ReputationBars_AutoBars:overrideInactiveReputations",6,"db.presentGainsForInactiveReputations is nil")
		end
	else
		ReputationBarsCommon:DebugLog("ERR","ReputationBars_AutoBars:overrideInactiveReputations",6,"db is nil")
	end
	
	ReputationBarsCommon:DebugLog("","ReputationBars_AutoBars:overrideInactiveReputations",6,"<=== Function Complete.  RetVal = " .. tostring(retVal))
	return retVal
end
-------------------------------------------------------------------------------
-- Cleanup
-------------------------------------------------------------------------------
local function CleanupSort()
	AutoBarsGroup:SortBars()
	sortTimer = nil
end

local function RemoveBar(bar)
	bar:StopAnimating()
	AutoBarsGroup:RemoveBar(bar)
	
	-- Need to do a clean up sort after all running animations are done (to avoid popping)
	if sortTimer then ReputationBars:CancelTimer(sortTimer, true) end
	sortTimer = ReputationBars:ScheduleTimer(CleanupSort, 0.1)
end

local function RemoveBarSmoothly(bar, duration)
	local animGroup = bar:CreateAnimationGroup()
	animGroup:SetLooping("BOUNCE")	-- Bounce avoids popping here

	local anim = animGroup:CreateAnimation("Scale")
	anim:SetOrder(1)
	anim:SetDuration(duration)
	anim:SetScale(1, 0)
	anim:SetSmoothing("OUT")

	local offset = bar:GetHeight()
	if db.growUp then offset = -offset end
	
	anim = animGroup:CreateAnimation("Translation")
	anim:SetOrder(1)
	anim:SetDuration(duration)
	anim:SetOffset(0, offset)
	anim:SetSmoothing("OUT")

	anim = animGroup:CreateAnimation("Alpha")
	anim:SetOrder(1)
	anim:SetDuration(duration)
	anim:SetFromAlpha(1)
	anim:SetToAlpha(0)
	anim:SetSmoothing("OUT")
	
	animGroup:Play()
	
	ReputationBars:ScheduleTimer(RemoveBar, duration, bar)
end

local function CleanupExpiredBars()
	local now = time()
	local needCollapse = false
	for i = #barlist, 1, -1 do
		local name = barlist[i]
		local faction = factions[name]
		
		-- Time to remove it?
		if (now - faction.lastUpdate) >= db.removeFactionSeconds then
			if faction.bar then
				RemoveBarSmoothly(faction.bar, factionSlideDuration)

				-- Remove bar and update sort orders
				faction.bar = nil
				tremove(barlist, i)
				
				needCollapse = true
			end
		end
	end
	return needCollapse
end

local function MoveBarSmoothly(bar, offset, duration)
	bar.animGroup = bar.animGroup or bar:CreateAnimationGroup()
	bar.animGroup:SetLooping("NONE")
	
	if db.growUp then offset = -offset end

	local anim = bar.animGroup:CreateAnimation("Translation")
	anim:SetOrder(1)
	anim:SetDuration(duration)
	anim:SetOffset(0, offset)
	anim:SetSmoothing("OUT")
	
	bar.animGroup:Play()
end

local function CollapseBars()
	for i = 1, #barlist do
		local faction = factions[barlist[i]]
		local bar = faction.bar
		if bar and i ~= bar.sortOrder then
			-- Collapse bar and update sort order
			local offset = bar:GetThickness() * bar:GetEffectiveScale()
			MoveBarSmoothly(bar, offset * (bar.sortOrder - i), factionSlideDuration)
			bar.sortOrder = i
		end
	end
end

function mod:Cleanup()
	if not db.removeInactiveFactions then return end

	-- Cleanup, then collapse if needed
	if CleanupExpiredBars() then
		-- Collapse remaining bars, and then sort them
		CollapseBars()
	end
end

function mod:HideAllBars()
	for i = #barlist, 1, -1 do
		local name = barlist[i]
		local faction = factions[name]
		
		if faction.bar then
			RemoveBar(faction.bar)
			faction.bar = nil
			tremove(barlist, i)
		end
	end
end

-------------------------------------------------------------------------------
-- Load/save position
-------------------------------------------------------------------------------
function mod:LoadPosition()
	local x, y = db.posx, db.posy
	if not x or not y then
		x = 100
		y = -200
	end

	local f = AutoBarsGroup
	local s = f:GetEffectiveScale()
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", x/s, y/s)
end

function mod:SavePosition()
	local x, y
	local f = AutoBarsGroup
	local s = f:GetEffectiveScale()
	local shown = f:IsShown()
	local l = f:GetLeft()
	if not shown then f:Show() end
	if l then
		x = l * s
		y = f:GetTop() * s - UIParent:GetHeight()*UIParent:GetEffectiveScale()
	end
	if not shown then f:Hide() end

	db.posx = x
	db.posy = y

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function mod:PET_BATTLE_OPENING_START()
	if AutoBarsGroup then
		AutoBarsGroup:Hide()
	end
end

function mod:PET_BATTLE_CLOSE()
	if AutoBarsGroup then
		AutoBarsGroup:Show()
	end
end

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
function mod:GetOptions()
	return mod.options
end

local function GenerateTestData()
        local allFactions = ReputationBars:GetAllFactions()
  
	return {
		[1] = {
			name = allFactions[1].name,
			amount = 100,
			factionIndex = ReputationBars:GetFactionIndex(allFactions[1].name)
		},
		[2] = {
			name = allFactions[2].name,
			amount = 200,
			factionIndex = ReputationBars:GetFactionIndex(allFactions[2].name)
		},
		[3] = {
			name = allFactions[3].name,
			amount = 300,
			factionIndex = ReputationBars:GetFactionIndex(allFactions[3].name)
		},
		[4] = {
			name = allFactions[4].name,
			amount = 400,
			factionIndex = ReputationBars:GetFactionIndex(allFactions[4].name)
		},
		[5] = {
			name = allFactions[5].name,
			amount = 500,
			factionIndex = ReputationBars:GetFactionIndex(allFactions[5].name)
		},		
	}
end

mod.options = {
	name = L["AutoBars settings"],
	type = "group",
	childGroups = "tab",
	get = function(info)
		if not mod.db then return nil end
		return mod.db.profile[info[#info]]
	end,
	set = function(info, val)
		mod.db.profile[info[#info]] = val
		mod:ApplySettings()
		mod:UpdateBar(true)
	end,
	disabled = function(info) return not mod.db end,
	args = {
		about1 = {
			type = "description",
			order = 1,
			name = L["The AutoBars module shows the reputation you have gained recently for various factions."]
		},

		testbtn = {
			type = "execute",
			order = 10,
			name = L["Show test bars"],
			func = function(info)
				mod:UpdateReputation( GenerateTestData() )
			end,
		},
		
		clearbarsbtn = {
			type = "execute",
			order = 11,
			name = L["Hide all bars"],
			func = function(info)
				mod:HideAllBars()
			end,
		},

		barBehavior = {
			type = "group",
			name = L["Behavior"],
			--guiInline = true,
			order = 20,
			args = {

				locked = {
					type = "toggle",
					order = 10,
					name = L["Lock frame and hide drag handle"],
					desc = L["Lock the frame to prevent moving it and to hide the drag bar."],
					width = "full",
				},

				resetbtn = {
					type = "execute",
					order = 12,
					name = L["Reset position"],
					func = function(info)
						mod.db.profile.posx = nil
						mod.db.profile.posy = nil
						AutoBarsGroup:Show()
						mod:ApplySettings()
						mod:LoadPosition()
						mod:UpdateBar(true)
					end,
				},

				showLosses = {
					type = "toggle",
					order = 20,
					name = L["Show lost reputation"],
					desc = L["This will display a bar when you lose reputation with a faction."],
					width = "full",
				},

				ignoreSplashRep = {
					type = "toggle",
					order = 30,
					name = L["Ignore splash reputation"],
					desc = L["If you gain reputation with many factions at the same time this will only show the one you gain the most with."],
					width = "full",
				},

				--hdr1 = {
					--type = "header",
					--order = 39,
					--name = ""
				--},

				removeInactiveFactions = {
					type = "toggle",
					order = 40,
					name = L["Remove inactive"],
					desc = L["A faction will be removed from the list of bars after this many seconds of inactivity."],
				},
				
				removeFactionSeconds = {
					type = "range",
					order = 41,
					name = L["Time (seconds)"],
					desc = L["How many seconds before a faction is considered inactive and is removed from the list."],
					min = 5,
					max = 600,
					step = 1,
				},

				presentGainsForInactiveReputations = {
					type = "toggle",
					order = 42,
					name = L["Show reputation changes for inactive factions"],
					desc = L["Override the default behaviour whereby factions marked as inactive will not show in AutoBars"],
					width = "full",
				},

				hdr2 = {
					type = "header",
					order = 49,
					name = ""
				},

				growUp = {
					type = "toggle",
					order = 50,
					name = L["Grow upwards"],
					desc = L["Bars are added above the anchor instead of below it."],
					width = "full",
				},

				autoHide = {
					type = "toggle",
					order = 60,
					name = L["Auto hide"],
					desc = L["Automatically hide if no reputation has been gained recently."],
				},

				autoHideSeconds = {
					type = "range",
					order = 61,
					name = L["Auto hide (seconds)"],
					desc = L["Automatically hide after this many seconds."],
					disabled = function(info) return not mod.db.profile.autoHide end,
					min = 1,
					max = 600,
					step = 1,
				},

			},
		},

		barText = {
			type = "group",
			name = L["Text"],
			--guiInline = true,
			order = 30,
			args = {

				showText = {
					type = "select",
					order = 1,
					name = L["Show text on bar"],
					desc = L["Determines when to show text on the bar."],
					values = {
						always = "Always",
						mouseover = "On mouse over",
						never = "Never",
					},
				},

				barFont = {
					type = "select",
					dialogControl = "LSM30_Font",
					order = 20,
					name = L["Font"],
					desc = L["Set the font for the bar text."],
					values = AceGUIWidgetLSMlists.font,
				},

				barFontOutline = {
					type = "select",
					order = 21,
					name = L["Font outline"],
					desc = L["Set the outline style for the text."],
					values = {
						[""] = L["None"],
						["OUTLINE"] = L["Normal"],
						["THICKOUTLINE"] = L["Thick"],
					},
				},

				barFontSize = {
					type = "range",
					order = 22,
					name = L["Font size"],
					desc = L["Set the font size of the bar text."],
					min = 5,
					max = 30,
					step = 1,
				},

			},
		},

		barAppearance = {
			type = "group",
			name = L["Appearance"],
			--guiInline = true,
			order = 40,
			args = {

				barLength = {
					type = "range",
					order = 0,
					name = L["Length"],
					desc = L["Set the length of the bar."],
					min = 20,
					max = 2000,
					step = 0.1,
				},

				barThickness = {
					type = "range",
					order = 1,
					name = L["Thickness"],
					desc = L["Set the thickness of the bar."],
					min = 2,
					max = 50,
					step = 1,
				},

				barAlpha = {
					type = "range",
					order = 10,
					name = L["Alpha"],
					desc = L["Determines the amount of transparency of the bar."],
					min = 0,
					max = 1,
					step = 0.01,
					isPercent = true,
				},

				barTexture = {
					type = "select",
					dialogControl = "LSM30_Statusbar",
					order = 20,
					name = L["Bar texture"],
					desc = L["Set the texture for the bar."],
					values = AceGUIWidgetLSMlists.statusbar,
				},

				barScale = {
					type = "range",
					order = 30,
					width = "full",
					name = L["Scale"],
					desc = L["Set the overall scale of the bar."],
					min = 0.1,
					max = 3
				},
			},
		},

	}
}
