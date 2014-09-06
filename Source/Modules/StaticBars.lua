-- ReputationBars: StaticBars
local appName = "ReputationBars"
local modName = "StaticBars"

local ReputationBars = LibStub("AceAddon-3.0"):GetAddon(appName)
ReputationBars_StaticBars = ReputationBars:NewModule(modName, "AceEvent-3.0")
local mod = ReputationBars_StaticBars

local L = LibStub("AceLocale-3.0"):GetLocale(appName)

local LSM = LibStub("LibSharedMedia-3.0")

local StaticBarsGroup

local db
local fadeTimer
local hidden
local hovering

local factionSlideDuration = 1

local factions = {}
--local barlist = {}

-- Default settings
local defaults = {
	profile = {
		locked = false,
		autoHide = false,
		autoHideSeconds = 30,

		barFont = "Bazooka",
		barFontSize = 10,
		barFontOutline = "OUTLINE",

		barAlpha = 1,
		barTexture = "Fifths",
		barLength = 200,
		barThickness = 15,
		barScale = 1,

		growUp = false,
		showText = "always",
	},

	char = {
		watchedFactions = {
			["*"] = false
		},
	},
}

function mod:GetDefaults()
	return defaults
end

function mod:OnInitialize()
end

-------------------------------------------------------------------------------
-- Show/hide
-------------------------------------------------------------------------------
local function FadeOut()
	if hidden then return end
	UIFrameFadeOut(StaticBarsGroup, 5, StaticBarsGroup:GetAlpha(), 0)
	hidden = true
end

local function FadeIn(time)
	if db.autoHide then
		if fadeTimer then
			ReputationBars:CancelTimer(fadeTimer, true)
		end
		fadeTimer = ReputationBars:ScheduleTimer(FadeOut, db.autoHideSeconds)
	end

	if not hidden then return end
	UIFrameFadeIn(StaticBarsGroup, time, StaticBarsGroup:GetAlpha(), db.barAlpha)
	hidden = false
end

-------------------------------------------------------------------------------
-- Enable/disable
-------------------------------------------------------------------------------
function mod:OnEnable()
	self.db = ReputationBars:GetModuleDB(modName)
	db = self.db.profile

	-- Initial load?
	if not StaticBarsGroup then
		hidden = true
		self:InitializeBar()
		self:UpdateBar(false)
		StaticBarsGroup:SetAlpha(0)
		FadeIn(5)
	else
		self:UpdateBar(true)
		StaticBarsGroup:Show()
	end

	self:RegisterEvent("UPDATE_FACTION")
end

function mod:OnDisable()
	if StaticBarsGroup then
		StaticBarsGroup:Hide()
	end
	if cleanupTimer then
		ReputationBars:CancelTimer(cleanupTimer, true)
		cleanupTimer = nil
	end
end

-------------------------------------------------------------------------------
-- Bar update
-------------------------------------------------------------------------------
local function CompareBarSortOrder(a, b)
	local bar1 = tostring(a.sortOrder)
	local bar2 = tostring(b.sortOrder)
	if not bar1 then return true end
	if not bar2 then return false end
	return bar1 < bar2
end

local function UpdateBarVisual()
	local now = time()
	local allFactions = ReputationBars:GetAllFactions()
	for factionIndex = 1, #allFactions do
		local fi = allFactions[factionIndex]
		local name = fi.name
		if mod.db.char.watchedFactions[name] then
			if not factions[name] then factions[name] = {} end
			local faction = factions[name]

			local bar = faction.bar
			if not bar then
				-- Create new bar
				bar = StaticBarsGroup:NewCounterBar(modName..factionIndex, nil, 0, 100)
				bar.label:ClearAllPoints()
				bar.label:SetPoint("CENTER", bar, "CENTER", 0, 0)

				-- Remember bar position
				--tinsert(barlist, name)
				bar.sortOrder = name

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
				
				StaticBarsGroup:SortBars()
			end

			local colorIndex
			if fi.friendID ~= nil then colorIndex = 5 else colorIndex = fi.standingId end
			local colors = FACTION_BAR_COLORS[colorIndex]
			bar:UnsetAllColors()
			bar:SetColorAt(0, colors.r, colors.g, colors.b, 1)

			local recentGainText = ""
			if faction.lastUpdate and (now - faction.lastUpdate) < 60 then
				recentGainText = string.format(" |cffedf55f(%+d)", faction.amount)
			end

			local displayMax = fi.max - fi.min
			local displayVal = fi.value - fi.min
			bar:SetValue(displayVal, displayMax)
			local barLabel
			if db.showText == "never" or (db.showText == "mouseover" and hovering ~= bar) then
				barLabel = ""
			else
				if hovering == bar and db.showText ~= "mouseover" then
					if fi.friendID ~= nil then
						local _, _, _, _, _, _, friendTextLevel, _, _ = GetFriendshipReputation(fi.factionID)
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
		else
			-- Ensure faction is not shown
			if factions[name] and factions[name].bar then
				StaticBarsGroup:RemoveBar(factions[name].bar)
				factions[name] = nil
			end
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
	if not StaticBarsGroup then
		StaticBarsGroup = ReputationBars:NewBarGroup("Reputation : " .. modName, nil, 200, 12, appName .. "_"..modName)

		StaticBarsGroup.RegisterCallback(self, "AnchorClicked")
		StaticBarsGroup.RegisterCallback(self, "AnchorMoved")
		StaticBarsGroup:HideIcon()
		StaticBarsGroup.button:SetScript("OnEnter", OnEnterAnchor)
		StaticBarsGroup.button:SetScript("OnLeave", OnLeaveAnchor)

		StaticBarsGroup:SetSortFunction(CompareBarSortOrder)
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
		StaticBarsGroup:Lock()
		StaticBarsGroup:HideAnchor()
	else
		StaticBarsGroup:Unlock()
		StaticBarsGroup:ShowAnchor()
	end

	local font = LSM:Fetch("font", db.barFont)
	StaticBarsGroup:SetFont(font, db.barFontSize, db.barFontOutline)

	local texture = LSM:Fetch("statusbar", db.barTexture)
	StaticBarsGroup:SetTexture(texture)

	StaticBarsGroup:ReverseGrowth(db.growUp)
	StaticBarsGroup:SetAlpha(db.barAlpha)
	StaticBarsGroup:SetScale(db.barScale)
	StaticBarsGroup:SetLength(db.barLength)
	StaticBarsGroup:SetThickness(db.barThickness)
end


-------------------------------------------------------------------------------
-- Update reputation
-------------------------------------------------------------------------------
function mod:RefreshReputation()
	self:UpdateBar(false)
end

function mod:UpdateReputation(changes)
	local needUpdate = false
	for i, faction in ipairs(changes) do
		local name = faction.name
		if mod.db.char.watchedFactions[name] then
			if not factions[name] then factions[name] = {} end
			factions[name].amount = faction.amount
			factions[name].lastUpdate = time()
			needUpdate = true
		end
	end

	if needUpdate then self:UpdateBar(true) end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function mod:UPDATE_FACTION()
	self:UpdateBar(false)
end

-------------------------------------------------------------------------------
-- Load/save position
-------------------------------------------------------------------------------
function mod:LoadPosition()
	local x, y = db.posx, db.posy
	if not x or not y then
		x = 100
		y = -300
	end

	local f = StaticBarsGroup
	local s = f:GetEffectiveScale()
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", x/s, y/s)
end

function mod:SavePosition()
	local x, y
	local f = StaticBarsGroup
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
-- Options
-------------------------------------------------------------------------------
function mod:GetOptions()
	return mod.options
end

local function GenerateTestData()
	return {
		[1] = {
			name = "Booty Bay",
			amount = 200,
			factionIndex = ReputationBars:GetFactionIndex("Darnassus")
		},
		[2] = {
			name = "Everlook",
			amount = 100,
			factionIndex = ReputationBars:GetFactionIndex("Ironforge")
		},
		[3] = {
			name = "Stormwind",
			amount = 50,
			factionIndex = ReputationBars:GetFactionIndex("Stormwind")
		},
		[4] = {
			name = "Orgrimmar",
			amount = 50,
			factionIndex = ReputationBars:GetFactionIndex("Orgrimmar")
		},
	}
end

mod.options = {
	name = L["StaticBars settings"],
	type = "group",
	childGroups = "tab",
	get = function(info) return mod.db.profile[info[#info]] end,
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
			name = L["The StaticBars module shows the reputation for the factions that you specify."]
		},

		--testbtn = {
			--type = "execute",
			--order = 10,
			--name = L["Show test bars"],
			--func = function(info)
				--mod:UpdateReputation( GenerateTestData() )
			--end,
		--},

		barBehavior = {
			type = "group",
			name = L["Behavior"],
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
						StaticBarsGroup:Show()
						mod:ApplySettings()
						mod:LoadPosition()
						mod:UpdateBar(true)
					end,
				},

				hdr2 = {
					type = "header",
					order = 49,
					name = ""
				},

				autoHide = {
					type = "toggle",
					order = 50,
					name = L["Auto hide"],
					desc = L["Automatically hide if no reputation has been gained recently."],
				},

				autoHideSeconds = {
					type = "range",
					order = 51,
					name = L["Auto hide (seconds)"],
					desc = L["Automatically hide after this many seconds."],
					disabled = function(info) return not mod.db.profile.autoHide end,
					min = 1,
					max = 600,
					step = 1,
				},

				growUp = {
					type = "toggle",
					order = 60,
					name = L["Grow upwards"],
					desc = L["Bars are added above the anchor instead of below it."],
				},
			},
		},

		barFactions = {
			type = "group",
			name = L["Factions"],
			order = 25,
			args = {

				selectFactions = {
					type = "multiselect",
					order = 10,
					name = "Factions",
					desc = "Select the factions that you wish to monitor.",
					width = "full",
					values = function(info)
								local allFactions = {}
								for factionIndex = 1, #ReputationBars:GetAllFactions() do
									local fi = ReputationBars:GetFactionInfo(factionIndex)
									if not fi.isHeader or fi.hasRep then allFactions[fi.name] = fi.name end
								end
								return allFactions
							end,
					get =	function(info, key)
								return mod.db.char.watchedFactions[key]
							end,
					set =	function(info, key, val)
								mod.db.char.watchedFactions[key] = val
								mod:UpdateBar(true)
								StaticBarsGroup:SortBars()
							end,
				},
				
			},
		},
		
		barText = {
			type = "group",
			name = L["Text"],
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
