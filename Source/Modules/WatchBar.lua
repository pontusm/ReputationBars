-- ReputationBars: WatchBar
local appName = "ReputationBars"
local modName = "WatchBar"

local ReputationBars = LibStub("AceAddon-3.0"):GetAddon(appName)
ReputationBars_WatchBar = ReputationBars:NewModule(modName, "AceEvent-3.0")
local mod = ReputationBars_WatchBar

local L = LibStub("AceLocale-3.0"):GetLocale(appName)

local LSM = LibStub("LibSharedMedia-3.0")

local WatchBarGroup
local WatchBar

local db
local currentFaction
local fadeTimer, gainTimer
local hidden
local hovering
local recentGain

-- Default settings
local defaults = {
	profile = {
		locked = false,
		replaceBlizzard = true,
		
		autoTrack = true,
		autoHide = false,
		autoHideSeconds = 60,

		barFont = "Arial Narrow",
		barFontSize = 10,
		barFontOutline = "",

		barAlpha = 1,
		barTexture = "Blizzard",
		barLength = 1024,
		barThickness = 10,
		barScale = 1,

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
local function FadeOut()
	if hidden then return end
	UIFrameFadeOut(WatchBarGroup, 5, WatchBarGroup:GetAlpha(), 0)
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
	UIFrameFadeIn(WatchBarGroup, time, WatchBarGroup:GetAlpha(), db.barAlpha)
	hidden = false
end

-------------------------------------------------------------------------------
-- Enable/disable
-------------------------------------------------------------------------------
function mod:OnEnable()
	self.db = ReputationBars:GetModuleDB(modName)
	db = self.db.profile

	-- Initial load?
	if not WatchBarGroup then
		hidden = true
		self:InitializeBar()
		WatchBarGroup:SetAlpha(0)
		FadeIn(5)
	else
		self:UpdateBar(true)
		WatchBarGroup:Show()
	end

	self:RegisterEvent("UPDATE_FACTION")
	self:RegisterEvent("PET_BATTLE_OPENING_START")
	self:RegisterEvent("PET_BATTLE_CLOSE")
end

function mod:OnDisable()
	if WatchBarGroup then
		WatchBarGroup:Hide()
	end

	db = nil
	self.db = nil
end

-------------------------------------------------------------------------------
-- Bar update
-------------------------------------------------------------------------------
local lastFactionName -- not the same as currentFaction - this one is (and should be) only used and updated in this function
local lastFactionIndex
local function UpdateBarVisual()
	local name, standingID, min, max, value = GetWatchedFactionInfo()
	if name then
		-- Try and figure out which faction it is we're dealing with
		local factionIndex
		if name == lastFactionName then
			factionIndex = lastFactionIndex
		else
			factionIndex = ReputationBars:GetFactionIndex( name )
			if not factionIndex then
				ReputationBars:RefreshAllFactions()
				ReputationBars:GetFactionIndex( name )
			end
			lastFactionName = name
			lastFactionIndex = factionIndex
		end
		local factionInfo = nil
		if factionIndex then
			factionInfo = ReputationBars:GetFactionInfo( factionIndex )
		end

		currentFaction = name
		local colorIndex
		if factionInfo and factionInfo.friendID ~= nil then colorIndex = 5 else colorIndex = standingID end
		local colors = FACTION_BAR_COLORS[colorIndex]
		WatchBar:UnsetAllColors()
		WatchBar:SetColorAt(0, colors.r, colors.g, colors.b, 1)

		local displayMax = max - min
		local displayVal = value - min
		WatchBar:SetValue(displayVal, displayMax)
		local recentGainText = ""
		if recentGain then
			recentGainText = string.format(" |cffedf55f(%+d)", recentGain)
		end

		local barLabel
		if db.showText == "never" or (db.showText == "mouseover" and not hovering) then
			barLabel = ""
		else
			if hovering and db.showText ~= "mouseover" then
				if factionInfo and factionInfo.friendID ~= nil then
					local _, _, _, _, _, _, friendTextLevel, _ = GetFriendshipReputation(factionInfo.factionID)
					barLabel = string.format("%s", friendTextLevel)
				else
					local gender = UnitSex("player")
					local standingText = GetText("FACTION_STANDING_LABEL"..standingID, gender)
					if standingID < 8 then
						local nextStandingText = GetText("FACTION_STANDING_LABEL"..standingID+1, gender);
						barLabel = string.format("%s |cffedf55f(%d to %s)", standingText, displayMax-displayVal, nextStandingText)
					else
						barLabel = string.format("%s", standingText)
					end
				end
			else
				barLabel = string.format("%s (%d / %d)%s", name, displayVal, displayMax, recentGainText)
			end
		end
		
		WatchBar:SetLabel(barLabel)

		--WatchBar:Show()
	--else
		--WatchBar:Hide()
	end
end

function mod:UpdateBar(ensureVisible)
	if ensureVisible then FadeIn(1) end
	UpdateBarVisual()
end

local function OnEnterBar(frame)
	hovering = true
	UpdateBarVisual()
end

local function OnLeaveBar(frame)
	hovering = false
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
	if not WatchBarGroup then
		WatchBarGroup = ReputationBars:NewBarGroup("Reputation : " .. modName, nil, 200, 12, appName .. "_"..modName)

		WatchBarGroup.RegisterCallback(self, "AnchorClicked")
		WatchBarGroup.RegisterCallback(self, "AnchorMoved")
		WatchBarGroup:HideIcon()
		WatchBarGroup.button:SetScript("OnEnter", OnEnterAnchor)
		WatchBarGroup.button:SetScript("OnLeave", OnLeaveAnchor)
	end

	if not WatchBar then
		WatchBar = WatchBarGroup:NewCounterBar(modName, nil, 0, 100)
		WatchBar.label:ClearAllPoints()
		WatchBar.label:SetPoint("CENTER", WatchBar, "CENTER", 0, 2)
		WatchBar:EnableMouse(true)
		WatchBar:SetScript("OnEnter", OnEnterBar)
		WatchBar:SetScript("OnLeave", OnLeaveBar)

		-- Reputation gain display
		--WatchBar.repFrame = WatchBar.repFrame or CreateFrame("Frame", nil, WatchBar)
		--WatchBar.repFrame:ClearAllPoints()
		--WatchBar.repFrame:SetPoint("LEFT", WatchBar, "RIGHT", 0, 0)
		--WatchBar.repFrame:SetBackdrop( {
			--bgFile = [[Interface\Tooltips\UI-Tooltip-Background]]
		--})

		--WatchBar.repLabel = WatchBar.repLabel or WatchBar.repFrame:CreateFontString(nil, "OVERLAY")
		--WatchBar.repLabel:ClearAllPoints()
		--WatchBar.repLabel:SetPoint("CENTER")
		--WatchBar.repLabel:SetFont(font, db.barFontSize, db.barFontOutline)
		--WatchBar.repLabel:SetText("+200")
		--
		--WatchBar.repFrame:SetScale(2)
		--WatchBar.repFrame:SetWidth( WatchBar.repLabel:GetStringWidth() )
		--WatchBar.repFrame:SetHeight( WatchBar.repLabel:GetStringHeight() )
		--WatchBar.repFrame:Show()
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
	if db.locked or db.replaceBlizzard then
		WatchBarGroup:Lock()
		WatchBarGroup:HideAnchor()
	else
		WatchBarGroup:Unlock()
		WatchBarGroup:ShowAnchor()
	end

	local font = LSM:Fetch("font", db.barFont)
	WatchBarGroup:SetFont(font, db.barFontSize, db.barFontOutline)

	local texture = LSM:Fetch("statusbar", db.barTexture)
	WatchBarGroup:SetTexture(texture)

	WatchBarGroup:SetAlpha(db.barAlpha)
	if db.replaceBlizzard then
		WatchBarGroup:SetParent(ReputationWatchBar)
		WatchBarGroup:ClearAllPoints()
		WatchBarGroup:SetPoint("CENTER")
		WatchBarGroup:SetScale(1)
		WatchBarGroup:SetLength(ReputationWatchBar:GetWidth())
		WatchBarGroup:SetThickness(ReputationWatchBar:GetHeight())
		WatchBarGroup:SetFrameStrata(ReputationWatchBar.StatusBar:GetFrameStrata())
		WatchBarGroup:SetFrameLevel(ReputationWatchBar.StatusBar:GetFrameLevel())
		
		-- Hide Blizzard frames
		ReputationWatchBar.StatusBar:Hide()
		ReputationWatchBar.OverlayFrame:Hide()
	else
		WatchBarGroup:SetParent(UIParent)
		WatchBarGroup:SetScale(db.barScale)
		WatchBarGroup:SetLength(db.barLength)
		WatchBarGroup:SetThickness(db.barThickness)
		
		ReputationWatchBar.StatusBar:Show()
		ReputationWatchBar.OverlayFrame:Show()
	end
	
end



-------------------------------------------------------------------------------
-- Update reputation
-------------------------------------------------------------------------------
function mod:RefreshReputation()
	self:UpdateBar(false)
end

local function ClearRecentGain()
	recentGain = nil
	gainTimer = nil
	mod:UpdateBar(false)
end

function mod:UpdateReputation(changes)
	if db.autoTrack then
		-- Largest gain is at first element
		local newFaction = changes[1].name
		if newFaction ~= currentFaction then
			SetWatchedFactionIndex( changes[1].factionIndex )
			currentFaction = newFaction
		end
	end

	-- Find watched faction
	local idx = 0
	for i, faction in ipairs(changes) do
		if faction.name == currentFaction then
			idx = i
			break
		end
	end
	
	if idx == 0 then return end

	recentGain = changes[idx].amount
	if gainTimer then
		ReputationBars:CancelTimer(gainTimer, true)
	end
	gainTimer = ReputationBars:ScheduleTimer(ClearRecentGain, 30)

	self:UpdateBar(true)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

--function mod:COMBAT_TEXT_UPDATE(event, arg1, arg2, arg3)
	--if (arg1 == "FACTION") then
		--self:UpdateBar()
		--ReputationBars:Print("Gained "..arg3.." with "..arg2)
	--end
--end

function mod:UPDATE_FACTION()
	self:UpdateBar(false)
end

function mod:PET_BATTLE_OPENING_START()
	if WatchBarGroup then
		WatchBarGroup:Hide()
	end
end

function mod:PET_BATTLE_CLOSE()
	if WatchBarGroup then
		WatchBarGroup:Show()
	end
end

-------------------------------------------------------------------------------
-- Load/save position
-------------------------------------------------------------------------------
function mod:LoadPosition()
	if db.replaceBlizzard then return end

	local x, y = db.posx, db.posy
	if not x or not y then
		x = 100
		y = -100
	end

	local f = WatchBarGroup
	local s = f:GetEffectiveScale()
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", x/s, y/s)
end

function mod:SavePosition()
	if db.replaceBlizzard then return end

	local x, y
	local f = WatchBarGroup
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

mod.options = {
	name = L["WatchBar settings"],
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
			name = L["The WatchBar works as a replacement for the built in reputation bar. By default it is shown at the bottom of your screen just above the action buttons."]
		},

		barBehavior = {
			type = "group",
			name = L["Behavior"],
			order = 20,
			args = {

				replaceBlizzard = {
					type = "toggle",
					order = 1,
					name = L["Replace Blizzard reputation bar"],
					desc = L["Replaces the default Blizzard reputation watch bar that is shown next to the experience bar in the standard UI."],
					width = "full",
				},
				
				locked = {
					type = "toggle",
					order = 10,
					name = L["Lock frame and hide drag handle"],
					desc = L["Lock the frame to prevent moving it and to hide the drag bar."],
					disabled = function(info) return mod.db.profile.replaceBlizzard end,
					width = "full",
				},

				resetbtn = {
					type = "execute",
					order = 11,
					name = L["Reset position"],
					func = function(info)
						mod.db.profile.posx = nil
						mod.db.profile.posy = nil
						WatchBarGroup:Show()
						mod:ApplySettings()
						mod:LoadPosition()
						mod:UpdateBar(true)
					end,
					disabled = function(info) return mod.db.profile.replaceBlizzard end,
				},

				hdr1 = {
					type = "header",
					order = 29,
					name = ""
				},

				autoTrack = {
					type = "toggle",
					order = 30,
					name = L["Auto track reputation"],
					desc = L["Automatically switches to the most recently gained reputation."],
					width = "full",
				},

				about2 = {
					type = "description",
					order = 31,
					name = L["This option will automatically switch to the most recent faction you gain reputation with. To change factions manually go to the Blizzard reputation window, select a faction and then mark 'Show as Experience bar'."]
				},

				hdr2 = {
					type = "header",
					order = 39,
					name = ""
				},

				autoHide = {
					type = "toggle",
					order = 40,
					name = L["Auto hide"],
					desc = L["Automatically hide if no reputation has been gained recently."],
				},

				autoHideSeconds = {
					type = "range",
					order = 41,
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
					name = L["Scale"],
					desc = L["Set the overall scale of the bar."],
					min = 0.1,
					max = 3
				},
			},
		},
	}
}
