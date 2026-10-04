-- Appearance and preview option pages.
local Cell = _G.NotCell
if not Cell then return end
Cell.OptionPageBuilders = Cell.OptionPageBuilders or {}

Cell.OptionPageBuilders.appearance = function(context)
	local Cell = context.Cell
	local panel = context.panel
	local page = context.pages.appearance
	local AddOptionsButton = context.AddOptionsButton
	local AddOptionsCheckbox = context.AddOptionsCheckbox
	local AddOptionsSlider = context.AddOptionsSlider
	local AddChoiceDropdown = context.AddChoiceDropdown
	local AddSectionTitle = context.AddSectionTitle
	local AddOptionsDivider = context.AddOptionsDivider
	local SaveSetting = context.SaveSetting
	local SetPageContentExtent = context.SetPageContentExtent
	local rightX, columnWidth = page:GetWidth() / 2 + 10, (page:GetWidth() - 40) / 2
	local grid = Cell:CreateOptionsGrid(page, 2, 20)
	local sliderPitch = Cell.OptionsSliderLayout and Cell.OptionsSliderLayout.rowPitch or 60
	-- Each color category uses one 60px slider block plus 18px for its color
	-- dropdown/title row. This keeps related controls together without excess gaps.
	local categoryPitch = sliderPitch + 18
	local styleTitleY, styleControlY = -20, -44
	local healthRowY = -82
	local healthLossRowY = healthRowY - categoryPitch
	local powerRowY = healthLossRowY - categoryPitch
	local alphaRowY = powerRowY - categoryPitch
	local highlightsY = alphaRowY - sliderPitch - 24
	local predictionY = highlightsY - 60
	local textureChoices = {
		{name = "Flat White", value = "Interface\\Buttons\\WHITE8X8", previewType = "texture"},
		{name = "Blizzard Status Bar", value = "Interface\\TargetingFrame\\UI-StatusBar", previewType = "texture"},
		{name = "Targeting Bar Fill", value = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", previewType = "texture"},
		{name = "Melli", value = "Interface\\AddOns\\NotCell\\Media\\Melli.tga", previewType = "texture"},
		{name = "Minimalist", value = "Interface\\AddOns\\NotCell\\Media\\Minimalist.tga", previewType = "texture"},
		{name = "pfUI-A", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-A.tga", previewType = "texture"},
		{name = "pfUI-B", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-B.tga", previewType = "texture"},
		{name = "pfUI-C", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-C.tga", previewType = "texture"},
		{name = "pfUI-D", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-D.tga", previewType = "texture"},
		{name = "pfUI-E", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-E.tga", previewType = "texture"},
		{name = "pfUI-F", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-F.tga", previewType = "texture"},
		{name = "pfUI-G", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-G.tga", previewType = "texture"},
		{name = "pfUI-H", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-H.tga", previewType = "texture"},
		{name = "pfUI-I", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-I.tga", previewType = "texture"},
		{name = "pfUI-J", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-J.tga", previewType = "texture"},
		{name = "pfUI-K", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-K.tga", previewType = "texture"},
		{name = "pfUI-L", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-L.tga", previewType = "texture"},
		{name = "pfUI-M", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-M.tga", previewType = "texture"},
		{name = "pfUI-N", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-N.tga", previewType = "texture"},
		{name = "pfUI-O", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-O.tga", previewType = "texture"},
		{name = "pfUI-P", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-P.tga", previewType = "texture"},
		{name = "pfUI-Q", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-Q.tga", previewType = "texture"},
		{name = "pfUI-R", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-R.tga", previewType = "texture"},
		{name = "pfUI-S", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-S.tga", previewType = "texture"},
		{name = "pfUI-T", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-T.tga", previewType = "texture"},
		{name = "pfUI-U", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-U.tga", previewType = "texture"},
		{name = "pfUI-V", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-V.tga", previewType = "texture"},
		{name = "pfUI-W", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-W.tga", previewType = "texture"},
		{name = "pfUI-X", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-X.tga", previewType = "texture"},
		{name = "pfUI-Y", value = "Interface\\AddOns\\NotCell\\Media\\pfUI-Y.tga", previewType = "texture"},
		{name = "Smooth", value = "Interface\\AddOns\\NotCell\\Media\\Smooth.tga", previewType = "texture"},
		{name = "NotCell Texture", value = "Interface\\AddOns\\NotCell\\Media\\statusbar.tga", previewType = "texture"},
	}
	-- SharedMedia is optional; the bundled 3.3.5-safe copy provides defaults,
	-- while any registered external statusbar textures are exposed automatically.
	local media = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibSharedMedia-3.0", true)
	if media then
		local ok, names = pcall(media.List, media, "statusbar")
		if ok and type(names) == "table" then
			for _, name in ipairs(names) do
				local path = media:Fetch("statusbar", name, true)
				if path then textureChoices[#textureChoices + 1] = {name = "Shared: " .. name, value = path, previewType = "texture"} end
			end
		end
	end
	local animationChoices = {
		{name = "None", value = "none"}, {name = "Smooth", value = "smooth"}, {name = "Flash", value = "flash"},
	}
	local healthModes = {{name = "Class Color", value = "class"}, {name = "Health by Value", value = "value"}, {name = "Custom Color", value = "custom"}}
	local lossModes = {{name = "Class Color (Light)", value = "classLight"}, {name = "Class Color (Dark)", value = "classDark"}, {name = "Custom Color", value = "custom"}}
	local powerModes = {{name = "Power Color", value = "power"}, {name = "Class Color", value = "class"}, {name = "Custom Color", value = "custom"}}
	local function AddSwatch(key, x, y, colorGetter, openPicker)
		local button = AddOptionsButton(page, "", x, y, 22, function() openPicker() end)
		button:SetHeight(22)
		local swatch = button:CreateTexture(nil, "ARTWORK")
		swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3); swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
		button.colorTexture = swatch
		panel[key] = button
		panel[key .. "Texture"] = swatch
		panel[key .. "GetColor"] = colorGetter
		return button
	end
	local function AddColorMode(title, swatchKey, y, choices, getter, setter, colorGetter, settingName)
		local heading = AddSectionTitle(page, title, 10, y)
		heading:SetWidth(columnWidth - 32); heading:SetJustifyH("CENTER")
		local button = AddChoiceDropdown(page, columnWidth - 32, 10, y - 24, function()
			for i = 1, table.getn(choices) do if choices[i].value == getter() then return choices[i].name end end
			return choices[1].name
		end, choices, function(value)
			setter(value); SaveSetting(settingName, value); Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
			if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
		end)
		panel[swatchKey .. "ModeButton"] = button
		local swatch = AddSwatch(swatchKey, 10 + columnWidth - 22, y - 24, colorGetter, function()
			local color = colorGetter()
			Cell:OpenHealthColorPicker(settingName == "healthColorMode" and "customHealthColor" or settingName == "healthLossColorMode" and "healthLossCustomColor" or "powerBarCustomColor", color, false, false, settingName == "powerColorMode" and "power" or nil)
		end)
		return heading, button, swatch
	end

	panel.unitButtonStyleTitle = AddSectionTitle(page, "Unit Button Style", 10, styleTitleY)
	panel.unitButtonStyleTitle:SetWidth(page:GetWidth()-20); panel.unitButtonStyleTitle:SetJustifyH("CENTER")
	local styleGroupWidth = math.min(page:GetWidth()-20, 360)
	local styleGroupLeft = (page:GetWidth()-styleGroupWidth)/2
	local styleOptionWidth = (styleGroupWidth-16)/2
	panel.unitTextureButton = AddChoiceDropdown(page, styleOptionWidth, styleGroupLeft, styleControlY, function()
		for i = 1, table.getn(textureChoices) do if textureChoices[i].value == Cell.unitTexture then return "Texture: " .. textureChoices[i].name end end
		return "Texture: NotCell Texture"
	end, textureChoices, function(value)
		Cell.unitTexture = value; SaveSetting("unitTexture", value); Cell:ApplyAppearanceSettings(); Cell:RefreshOptionsMenu()
	end)
	panel.barAnimationButton = AddChoiceDropdown(page, styleOptionWidth, styleGroupLeft+styleOptionWidth+16, styleControlY, function()
		for i = 1, table.getn(animationChoices) do if animationChoices[i].value == Cell.barAnimationMode then return "Animation: " .. animationChoices[i].name end end
		return "Animation: Flash"
	end, animationChoices, function(value)
		Cell.barAnimationMode = value; SaveSetting("barAnimationMode", value); Cell:RefreshOptionsMenu()
	end)

	panel.healthColorHeading, panel.healthBarColorModeButton, panel.healthBarColorSwatch = AddColorMode("Health Bar Color", "healthBarColorSwatch", healthRowY, healthModes, function() return Cell.healthColorMode end,
		function(value) Cell.healthColorMode = value end, function() return Cell.customHealthColor end, "healthColorMode")
	panel.healthAlphaHeading = AddSectionTitle(page, "Health Bar Alpha", rightX, healthRowY)
	panel.healthAlphaHeading:SetWidth(columnWidth); panel.healthAlphaHeading:SetJustifyH("CENTER")
	panel.healthAlphaSlider = AddOptionsSlider(page, "", rightX, healthRowY - 6, columnWidth, 0, 95, 5, Cell.healthColorAlpha, function(value)
		if Cell.syncingAppearanceControls then return end
		Cell.healthColorAlpha = value; SaveSetting("healthColorAlpha", value); Cell:ApplyAppearanceSettings()
	end)
	grid:Add(panel.healthColorHeading, healthRowY, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.healthBarColorModeButton, healthRowY - 24, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.healthBarColorSwatch, healthRowY - 24, 1, 1, 22, "right")
	grid:Add(panel.healthAlphaHeading, healthRowY, 2); grid:Add(panel.healthAlphaSlider, healthRowY - 6, 2, 1, nil, nil, true)

	panel.healthLossHeading, panel.healthLossColorModeButton, panel.healthLossColorSwatch = AddColorMode("Health Loss Color", "healthLossColorSwatch", healthLossRowY, lossModes, function() return Cell.healthLossColorMode end,
		function(value) Cell.healthLossColorMode = value end, function() return Cell.healthLossCustomColor end, "healthLossColorMode")
	panel.healthLossAlphaHeading = AddSectionTitle(page, "Health Loss Alpha", rightX, healthLossRowY)
	panel.healthLossAlphaHeading:SetWidth(columnWidth); panel.healthLossAlphaHeading:SetJustifyH("CENTER")
	panel.healthLossAlphaSlider = AddOptionsSlider(page, "", rightX, healthLossRowY - 6, columnWidth, 0, 95, 5, Cell.healthLossAlpha, function(value)
		if Cell.syncingAppearanceControls then return end
		Cell.healthLossAlpha = value; SaveSetting("healthLossAlpha", value); Cell:ApplyAppearanceSettings()
	end)
	grid:Add(panel.healthLossHeading, healthLossRowY, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.healthLossColorModeButton, healthLossRowY - 24, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.healthLossColorSwatch, healthLossRowY - 24, 1, 1, 22, "right")
	grid:Add(panel.healthLossAlphaHeading, healthLossRowY, 2); grid:Add(panel.healthLossAlphaSlider, healthLossRowY - 6, 2, 1, nil, nil, true)

	panel.powerColorHeading, panel.powerColorModeButton, panel.powerColorSwatch = AddColorMode("Power Color", "powerColorSwatch", powerRowY, powerModes, function() return Cell.powerColorMode end,
		function(value) Cell.powerColorMode = value end, function() return Cell.powerBarCustomColor end, "powerColorMode")
	panel.powerAlphaHeading = AddSectionTitle(page, "Power Color Alpha", rightX, powerRowY)
	panel.powerAlphaHeading:SetWidth(columnWidth); panel.powerAlphaHeading:SetJustifyH("CENTER")
	panel.powerAlphaSlider = AddOptionsSlider(page, "", rightX, powerRowY - 6, columnWidth, 0, 95, 5, Cell.powerColorAlpha, function(value)
		if Cell.syncingAppearanceControls then return end
		Cell.powerColorAlpha = value; SaveSetting("powerColorAlpha", value); Cell:ApplyAppearanceSettings()
	end)
	grid:Add(panel.powerColorHeading, powerRowY, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.powerColorModeButton, powerRowY - 24, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.powerColorSwatch, powerRowY - 24, 1, 1, 22, "right")
	grid:Add(panel.powerAlphaHeading, powerRowY, 2); grid:Add(panel.powerAlphaSlider, powerRowY - 6, 2, 1, nil, nil, true)

	panel.backgroundAlphaHeading = AddSectionTitle(page, "Background Alpha", 10, alphaRowY)
	panel.backgroundAlphaHeading:SetWidth(columnWidth); panel.backgroundAlphaHeading:SetJustifyH("CENTER")
	panel.outOfRangeAlphaHeading = AddSectionTitle(page, "Out of Range Alpha", rightX, alphaRowY)
	panel.outOfRangeAlphaHeading:SetWidth(columnWidth); panel.outOfRangeAlphaHeading:SetJustifyH("CENTER")
	panel.backgroundAlphaSlider = AddOptionsSlider(page, "", 10, alphaRowY - 6, columnWidth, 0, 95, 5, Cell.backgroundAlpha, function(value)
		if Cell.syncingAppearanceControls then return end
		Cell.backgroundAlpha = value; SaveSetting("backgroundAlpha", value); Cell:ApplyAppearanceSettings()
	end)
	panel.outOfRangeAlphaSlider = AddOptionsSlider(page, "", rightX, alphaRowY - 6, columnWidth, 0, 95, 5, Cell.outOfRangeAlpha, function(value)
		if Cell.syncingAppearanceControls then return end
		Cell.outOfRangeAlpha = value; Cell.rangeFadeEnabled = value < 100; SaveSetting("outOfRangeAlpha", value); Cell:UpdateFrames()
	end)
	grid:Add(panel.backgroundAlphaHeading, alphaRowY, 1); grid:Add(panel.backgroundAlphaSlider, alphaRowY - 6, 1, 1, nil, nil, true)
	grid:Add(panel.outOfRangeAlphaHeading, alphaRowY, 2); grid:Add(panel.outOfRangeAlphaSlider, alphaRowY - 6, 2, 1, nil, nil, true)

	AddSectionTitle(page, "Highlights & Heal Prediction", 10, highlightsY)
	panel.targetHighlightCheckbox = AddOptionsCheckbox(page, "Target Highlight", 10, highlightsY - 24, 196, function()
		Cell.targetHighlightEnabled = not Cell.targetHighlightEnabled; SaveSetting("targetHighlightEnabled", Cell.targetHighlightEnabled); Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end, 20, "NotCellFontNormal")
	panel.targetHighlightSwatch = AddSwatch("targetHighlightSwatch", 214, highlightsY - 25, function() return Cell.targetHighlightColor end,
		function() Cell:OpenHealthColorPicker("targetHighlightColor", Cell.targetHighlightColor, false) end)
	panel.mouseoverHighlightCheckbox = AddOptionsCheckbox(page, "Mouseover Highlight", rightX, highlightsY - 24, 196, function()
		Cell.mouseoverHighlightEnabled = not Cell.mouseoverHighlightEnabled; SaveSetting("mouseoverHighlightEnabled", Cell.mouseoverHighlightEnabled); Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end, 20, "NotCellFontNormal")
	panel.mouseoverHighlightSwatch = AddSwatch("mouseoverHighlightSwatch", 454, highlightsY - 25, function() return Cell.mouseoverHighlightColor end,
		function() Cell:OpenHealthColorPicker("mouseoverHighlightColor", Cell.mouseoverHighlightColor, false) end)
	grid:Add(panel.targetHighlightCheckbox, highlightsY - 24, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.targetHighlightSwatch, highlightsY - 25, 1, 1, 22, "right")
	grid:Add(panel.mouseoverHighlightCheckbox, highlightsY - 24, 2, 1, function(cw) return cw - 32 end); grid:Add(panel.mouseoverHighlightSwatch, highlightsY - 25, 2, 1, 22, "right")
	panel.healPredictionCheckbox = AddOptionsCheckbox(page, "Heal Prediction", 10, predictionY, 160, function()
		Cell.healPredictionEnabled = not Cell.healPredictionEnabled; SaveSetting("healPredictionEnabled", Cell.healPredictionEnabled); Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end, 20, "NotCellFontNormal")
	panel.healPredictionSwatch = AddSwatch("healPredictionSwatch", 214, predictionY - 1, function() return Cell.healPredictionColor end,
		function() Cell:OpenHealthColorPicker("healPredictionColor", Cell.healPredictionColor, false) end)
	grid:Add(panel.healPredictionCheckbox, predictionY, 1, 1, function(cw) return cw - 32 end); grid:Add(panel.healPredictionSwatch, predictionY - 1, 1, 1, 22, "right")
	panel.UpdateAppearanceResponsive = function()
		rightX = page:GetWidth() / 2 + 10
		columnWidth = (page:GetWidth() - 40) / 2
		styleGroupWidth = math.min(page:GetWidth()-20, 360); styleGroupLeft = (page:GetWidth()-styleGroupWidth)/2; styleOptionWidth = (styleGroupWidth-16)/2
		panel.unitButtonStyleTitle:SetWidth(page:GetWidth()-20)
		grid:Layout()
		panel.unitTextureButton:ClearAllPoints(); panel.unitTextureButton:SetPoint("TOPLEFT",page,"TOPLEFT",styleGroupLeft,styleControlY); panel.unitTextureButton:SetWidth(styleOptionWidth)
		panel.barAnimationButton:ClearAllPoints(); panel.barAnimationButton:SetPoint("TOPLEFT",page,"TOPLEFT",styleGroupLeft+styleOptionWidth+16,styleControlY); panel.barAnimationButton:SetWidth(styleOptionWidth)
	end
	-- Share the same deepest-control measurement and bottom padding as every page.
	if SetPageContentExtent then SetPageContentExtent("appearance", math.abs(predictionY) + 24) end
	page:SetScript("OnSizeChanged", function() if panel.UpdateAppearanceResponsive then panel.UpdateAppearanceResponsive() end end)
	panel.UpdateAppearanceResponsive()

end


