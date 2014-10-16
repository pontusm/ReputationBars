local Type, Version = "ReputationTreeView", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local function FirstFrameUpdate(frame)
	print("FirstFrameUpdate")
	local self = frame.obj
	frame:SetScript("OnUpdate", nil)
	self:RefreshTree()
end

--[[ Methods ]]--
local methods = {
	["OnAcquire"] = function(self)
		print("OnAcquire")

		--self:SetDisabled(false)
	end,

	["OnRelease"] = function(self)
		print("OnRelease")
		--self.frame:Hide()
		--self:SetDisabled(false)
	end,

	["RefreshTree"] = function(self)
		local numFactions = GetNumFactions()
		local maxRows = 5

		local num = AceGUI:GetNextWidgetNum("ReputationTreeViewRow")
		local frame = CreateFrame("Frame", ("ReputationTreeViewRow%d"):format(num), self.treeFrame)
		frame:SetPoint("TOPLEFT")
		frame:SetPoint("TOPRIGHT")
		frame.obj = self


		for i = 1, maxRows do
--			local name, description, standingID, barMin, barMax, barValue, atWarWith, 
--				canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(factionIndex)

		end
	end,

	["SetDisabled"] = function(self, disabled)
		print("SetDisabled:", disabled)
		self.disabled = disabled
	end,

	["SetLabel"] = function(self, label)
		print("SetLabel:", label)
	end,

	["SetList"] = function(self, values)
		print("SetList", values)
	end,

	["SetMultiselect"] = function(self, multiselect)
		print("SetMultiselect:", multiselect)
	end,
}

--[[ Constructor ]]
local PaneBackdrop  = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 5, bottom = 3 }
}

local DraggerBackdrop  = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = nil,
	tile = true, tileSize = 16, edgeSize = 0,
	insets = { left = 3, right = 3, top = 7, bottom = 7 }
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	local num = AceGUI:GetNextWidgetNum(Type)

	local treeFrame = CreateFrame("Frame", nil, frame)
	treeFrame:SetPoint("TOPLEFT")
	--treeFrame:SetPoint("TOPRIGHT")
	treeFrame:SetPoint("BOTTOMLEFT")
	--treeFrame:SetWidth(175)
	--treeFrame:SetHeight(200)
	treeFrame:EnableMouseWheel(true)
	treeFrame:SetBackdrop(PaneBackdrop)
	treeFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	treeFrame:SetBackdropBorderColor(0.4, 0.4, 0.4)
	treeFrame:SetResizable(true)
	treeFrame:SetMinResize(100, 1)
	treeFrame:SetMaxResize(400, 1600)
	treeFrame:SetScript("OnUpdate", FirstFrameUpdate)
	--treeFrame:SetScript("OnSizeChanged", Tree_OnSizeChanged)
	--treeFrame:SetScript("OnMouseWheel", Tree_OnMouseWheel)

	local dragger = CreateFrame("Frame", nil, treeFrame)
	dragger:SetWidth(8)
	dragger:SetPoint("TOP", treeFrame, "TOPRIGHT")
	dragger:SetPoint("BOTTOM", treeFrame, "BOTTOMRIGHT")
	dragger:SetBackdrop(DraggerBackdrop)
	dragger:SetBackdropColor(1, 1, 1, 0)

	local scrollbar = CreateFrame("Slider", ("AceGUIWidgetReputationTreeView%dScrollBar"):format(num), treeFrame, "UIPanelScrollBarTemplate")
	scrollbar:SetScript("OnValueChanged", nil)
	scrollbar:SetPoint("TOPRIGHT", -10, -26)
	scrollbar:SetPoint("BOTTOMRIGHT", -10, 26)
	scrollbar:SetMinMaxValues(0, 0)
	scrollbar:SetValueStep(1)
	scrollbar:SetValue(0)
	scrollbar:SetWidth(16)

	local scrollbg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbg:SetAllPoints(scrollbar)
	scrollbg:SetTexture(0, 0, 0, 0.4)

	local border = CreateFrame("Frame", nil, frame)
	border:SetPoint("TOPLEFT", treeFrame, "TOPRIGHT")
	border:SetPoint("BOTTOMRIGHT")
	border:SetBackdrop(PaneBackdrop)
	border:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	border:SetBackdropBorderColor(0.4, 0.4, 0.4)

	local content = CreateFrame("Frame", nil, border)
	content:SetPoint("TOPLEFT", 10, -10)
	content:SetPoint("BOTTOMRIGHT", -10, 10)

	--frame:SetWidth(200)
	frame:SetHeight(300)

	local widget = {
		frame = frame,
		type = Type,
		treeFrame = treeFrame,
		dragger = dragger,
		scrollbar = scrollbar,
		-- border = border,
		-- content = content
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	treeFrame.obj, dragger.obj, scrollbar.obj = widget, widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
