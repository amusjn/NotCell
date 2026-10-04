-- General and About option pages.
local Cell = _G.NotCell
if not Cell then return end
Cell.OptionPageBuilders = Cell.OptionPageBuilders or {}

Cell.OptionPageBuilders.general = function(context)
	local panel = context.panel
	local Cell = context.Cell
	local AddOptionsCheckbox = context.AddOptionsCheckbox
	local AddOptionsButton = context.AddOptionsButton
	local AddOptionsSlider = context.AddOptionsSlider
	local AddChoiceDropdown = context.AddChoiceDropdown
	local AddSectionTitle = context.AddSectionTitle
	local AddOptionsDivider = context.AddOptionsDivider
	local SaveSetting = context.SaveSetting
	local SetPageContentExtent = context.SetPageContentExtent
	local RegisterAccentRefresher = context.RegisterAccentRefresher
	local GetUIAccentColor = context.GetUIAccentColor
	local aboutTextBlocks = {}
	local generalPage = context.pages.generalSettings
	local aboutPage = context.pages.about

	local aboutHeader = aboutPage:CreateFontString(nil, "OVERLAY", "NotCellFontNormalLarge")
	aboutHeader:SetPoint("TOPLEFT", aboutPage, "TOPLEFT", 10, -14)
	aboutHeader:SetText("NotCell")
	aboutHeader:SetTextColor(GetUIAccentColor())
	RegisterAccentRefresher(function() aboutHeader:SetTextColor(GetUIAccentColor()) end)
	local aboutIntro = aboutPage:CreateFontString(nil, "OVERLAY", "NotCellFontHighlight")
	aboutIntro:SetPoint("TOPLEFT", aboutPage, "TOPLEFT", 10, -42)
	aboutIntro:SetWidth(390); aboutIntro:SetHeight(50); aboutIntro:SetJustifyH("LEFT"); aboutTextBlocks[#aboutTextBlocks+1]=aboutIntro
	aboutIntro:SetText("NotCell: Party and Raid Unit-frames\nModular party and raid unit-frames for World of Warcraft 1.12 / 1.18")
	local aboutGitHub = CreateFrame("Button", nil, aboutPage)
	aboutGitHub:SetPoint("TOPLEFT", aboutPage, "TOPLEFT", 10, -94)
	aboutGitHub:SetWidth(390); aboutGitHub:SetHeight(22)
	local githubIcon = aboutGitHub:CreateTexture(nil, "ARTWORK")
	githubIcon:SetTexture("Interface\\AddOns\\NotCell\\Media\\Links\\github.tga")
	githubIcon:SetWidth(16); githubIcon:SetHeight(16); githubIcon:SetPoint("LEFT", aboutGitHub, "LEFT", 0, 0)
	local githubLabel = aboutGitHub:CreateFontString(nil, "OVERLAY", "NotCellFontHighlight")
	githubLabel:SetPoint("LEFT", githubIcon, "RIGHT", 5, 0)
	githubLabel:SetText("GitHub: amusjn/NotCell  ·  Version 1.2.0")
	githubLabel:SetTextColor(.35, .68, 1)
	aboutGitHub:SetScript("OnClick", function()
		local url = "https://github.com/amusjn/NotCell"
		local dialog = _G.NotCellGitHubLinkDialog
		if not dialog then
			dialog = CreateFrame("Frame", "NotCellGitHubLinkDialog", UIParent)
			dialog:SetWidth(420); dialog:SetHeight(126); dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			dialog:SetFrameStrata("DIALOG"); dialog:SetFrameLevel(220); dialog:SetMovable(true); dialog:SetClampedToScreen(true)
			dialog:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
			dialog:SetBackdropColor(.035,.035,.035,.98)
			dialog.title = dialog:CreateFontString(nil, "OVERLAY", "NotCellFontNormal")
			dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -12); dialog.title:SetText("NotCell on GitHub")
			dialog.editBox = CreateFrame("EditBox", nil, dialog)
			dialog.editBox:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -42); dialog.editBox:SetWidth(392); dialog.editBox:SetHeight(26)
			dialog.editBox:SetAutoFocus(false); dialog.editBox:SetFontObject(NotCellFontNormalSmall); dialog.editBox:SetTextInsets(6,6,2,2)
			dialog.editBox:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
			dialog.editBox:SetBackdropColor(.02,.02,.02,1)
			dialog.okButton = AddOptionsButton(dialog, "OK", 14, -78, 392, function() dialog:Hide() end)
			dialog.editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
			if UISpecialFrames then table.insert(UISpecialFrames, "NotCellGitHubLinkDialog") end
		end
		dialog.editBox:SetText(url); dialog:Show(); dialog.editBox:SetFocus(); dialog.editBox:HighlightText()
	end)
	aboutTextBlocks[#aboutTextBlocks+1]=aboutGitHub
	AddSectionTitle(aboutPage, "Features", 10, -130)
	AddOptionsDivider(aboutPage, -152)
	local aboutFeatures = aboutPage:CreateFontString(nil, "OVERLAY", "NotCellFontNormal")
	aboutFeatures:SetPoint("TOPLEFT", aboutPage, "TOPLEFT", 14, -156)
	aboutFeatures:SetWidth(390); aboutFeatures:SetHeight(108); aboutFeatures:SetJustifyH("LEFT"); aboutTextBlocks[#aboutTextBlocks+1]=aboutFeatures
	aboutFeatures:SetText("- Solo, party, and raid frames with automatic layout switching\n- Click-casting for NotCell and Blizzard frames\n- Incoming-heal prediction through bundled HealComm\n- Configurable indicators and debuff styles\n- Live previews, group filters, and settings import/export\nBackported from Cell 3.3.5a; inspired by Cell by enderneko.")
	AddSectionTitle(aboutPage, "Getting started", 10, -286)
	AddOptionsDivider(aboutPage, -308)
	local aboutGettingStarted = aboutPage:CreateFontString(nil, "OVERLAY", "NotCellFontHighlight")
	aboutGettingStarted:SetPoint("TOPLEFT", aboutPage, "TOPLEFT", 14, -312)
	aboutGettingStarted:SetWidth(390); aboutGettingStarted:SetHeight(44); aboutGettingStarted:SetJustifyH("LEFT"); aboutTextBlocks[#aboutTextBlocks+1]=aboutGettingStarted
	aboutGettingStarted:SetText("Open options with /notcell opt and setup with /notcell setup. Drag the red frame handle to reposition unitframes.")
	AddSectionTitle(aboutPage, "Tip", 10, -376)
	AddOptionsDivider(aboutPage, -398)
	local aboutTip = aboutPage:CreateFontString(nil, "OVERLAY", "NotCellFontHighlight")
	aboutTip:SetPoint("TOPLEFT", aboutPage, "TOPLEFT", 14, -402)
	aboutTip:SetWidth(390); aboutTip:SetHeight(38); aboutTip:SetJustifyH("LEFT"); aboutTextBlocks[#aboutTextBlocks+1]=aboutTip
	local tips = {
		"Use separate layouts for solo, party, and raid groups.",
		"Right-click the red frame handle to refresh the unit frames.",
		"Use the layout preview to adjust a group without being in a raid.",
		"Click-casting profiles and binds are saved per character.",
	}
	function panel.RefreshAboutTip() aboutTip:SetText(tips[math.random(table.getn(tips))]) end
	panel.RefreshAboutTip()
	panel.UpdateAboutResponsive = function(_, width)
		for _, block in ipairs(aboutTextBlocks) do block:SetWidth(math.max(1,width-20)) end
	end
	panel.aboutText = aboutFeatures
	if SetPageContentExtent then SetPageContentExtent("about", 440) end

	local generalY = {visibility = -10, visibilityDivider = -32, visibilityControls = -46,
		tooltips = -84, tooltipsDivider = -106, tooltipControls = -120,
		misc = -154, miscDivider = -176, blizzard = -190, lock = -214, healerPrompt = -244,
		setup = -278, setupDivider = -300, setupButton = -314, accent = -352}
	AddSectionTitle(generalPage, "Visibility", 10, generalY.visibility)
	AddOptionsDivider(generalPage, generalY.visibilityDivider)
	local visibilityColumnWidth = 200
	local visibilityRightX = 217
	panel.showSoloCheckbox = AddOptionsCheckbox(generalPage, "Show Solo", 10, generalY.visibilityControls, visibilityColumnWidth, function()
		Cell.showSolo = not Cell.showSolo; SaveSetting("showSolo", Cell.showSolo)
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	panel.showPartyCheckbox = AddOptionsCheckbox(generalPage, "Show Party and Raid", visibilityRightX, generalY.visibilityControls, visibilityColumnWidth, function()
		Cell.showParty = not Cell.showParty; SaveSetting("showParty", Cell.showParty)
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	AddSectionTitle(generalPage, "Tooltips", 10, generalY.tooltips)
	AddOptionsDivider(generalPage, generalY.tooltipsDivider)
	panel.tooltipsEnabledCheckbox = AddOptionsCheckbox(generalPage, "Enabled", 10, generalY.tooltipControls, visibilityColumnWidth, function()
		Cell:SetTooltipsEnabled(not Cell.tooltipsEnabled)
	end)
	panel.tooltipsCombatCheckbox = AddOptionsCheckbox(generalPage, "Hide in Combat", visibilityRightX, generalY.tooltipControls, visibilityColumnWidth, function()
		Cell:SetTooltipsHideInCombat(not Cell.tooltipsHideInCombat)
	end)
	AddSectionTitle(generalPage, "Misc", 10, generalY.misc)
	AddOptionsDivider(generalPage, generalY.miscDivider)
	panel.generalBlizzardCheckbox = AddOptionsCheckbox(generalPage, "Hide Blizzard Raid / Party", 10, generalY.blizzard, generalPage:GetWidth()-20, function()
		Cell:SetBlizzardFramesHidden(not Cell.hideBlizzardFrames)
	end)
	panel.generalPositionCheckbox = AddOptionsCheckbox(generalPage, "Lock NotCell Frames", 10, generalY.lock, generalPage:GetWidth()-20, function()
		Cell:SetFramesLocked(not Cell.framesLocked)
	end)
	panel.healerPromptButton = AddOptionsButton(generalPage, "Create Healer Indicators...", 10, generalY.healerPrompt, 220, function()
		Cell:ShowHealerIndicatorPrompt(true)
	end)
	AddSectionTitle(generalPage, "First Run Setup", 10, generalY.setup)
	AddOptionsDivider(generalPage, generalY.setupDivider)
	panel.runSetupButton = AddOptionsButton(generalPage, "Run Setup Again...", 10, generalY.setupButton, 220, function()
		Cell:ShowSetupWizard()
	end)
	AddSectionTitle(generalPage, "UI Accent Color", 10, generalY.accent)
	local accentChoices={{name="Class Color",value="class"},{name="Custom Color",value="custom"}}
	local accentDropdownX=156
	local accentControlY=generalY.accent-2
	panel.uiAccentModeDropdown=AddChoiceDropdown(generalPage,178,accentDropdownX,accentControlY,function()
		return "Accent: " .. (Cell.uiAccentColorMode=="custom" and "Custom Color" or "Class Color")
	end,accentChoices,function(value)
		Cell.uiAccentColorMode=value; SaveSetting("uiAccentColorMode",value); Cell:RefreshOptionsMenu()
	end)
	panel.uiAccentColorButton=AddOptionsButton(generalPage,"",generalPage:GetWidth()-34,accentControlY,24,function() Cell:OpenHealthColorPicker("uiAccentCustomColor",Cell.uiAccentCustomColor,false) end)
	panel.uiAccentColorSwatch=panel.uiAccentColorButton:CreateTexture(nil,"ARTWORK"); panel.uiAccentColorSwatch:SetPoint("TOPLEFT",panel.uiAccentColorButton,"TOPLEFT",3,-3); panel.uiAccentColorSwatch:SetPoint("BOTTOMRIGHT",panel.uiAccentColorButton,"BOTTOMRIGHT",-3,3)
	panel.UpdateGeneralResponsiveWidth = function()
		local width=generalPage:GetWidth(); local columnWidth=math.max(160,math.floor((width-30)/2)); local rightX=20+columnWidth
		visibilityColumnWidth,visibilityRightX=columnWidth,rightX
		panel.showSoloCheckbox:SetWidth(columnWidth); panel.showPartyCheckbox:ClearAllPoints(); panel.showPartyCheckbox:SetPoint("TOPLEFT",generalPage,"TOPLEFT",rightX,generalY.visibilityControls); panel.showPartyCheckbox:SetWidth(columnWidth)
		panel.tooltipsEnabledCheckbox:SetWidth(columnWidth); panel.tooltipsEnabledCheckbox:ClearAllPoints(); panel.tooltipsEnabledCheckbox:SetPoint("TOPLEFT",generalPage,"TOPLEFT",10,generalY.tooltipControls); panel.tooltipsCombatCheckbox:ClearAllPoints(); panel.tooltipsCombatCheckbox:SetPoint("TOPLEFT",generalPage,"TOPLEFT",rightX,generalY.tooltipControls); panel.tooltipsCombatCheckbox:SetWidth(columnWidth)
		panel.generalBlizzardCheckbox:SetWidth(width-20); panel.generalPositionCheckbox:SetWidth(width-20)
		panel.healerPromptButton:SetWidth(math.min(width-20,260))
		panel.runSetupButton:SetWidth(math.min(width-20,260))
		local swatchX=width-34
		local responsiveAccentDropdownX=math.min(accentDropdownX,math.max(138,swatchX-128))
		panel.uiAccentModeDropdown:ClearAllPoints(); panel.uiAccentModeDropdown:SetPoint("TOPLEFT",generalPage,"TOPLEFT",responsiveAccentDropdownX,accentControlY)
		panel.uiAccentModeDropdown:SetWidth(math.max(96,swatchX-responsiveAccentDropdownX-6))
		panel.uiAccentColorButton:ClearAllPoints(); panel.uiAccentColorButton:SetPoint("TOPLEFT",generalPage,"TOPLEFT",swatchX,accentControlY)
		if SetPageContentExtent then SetPageContentExtent("generalSettings", math.abs(generalY.accent) + 34) end
	end
	generalPage:SetScript("OnSizeChanged",function() if panel.UpdateGeneralResponsiveWidth then panel.UpdateGeneralResponsiveWidth() end end)
	panel.UpdateGeneralResponsiveWidth()
end






