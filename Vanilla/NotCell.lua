local addonName, namespace = ...
namespace = namespace or {}

local Cell = {}
namespace.NotCell = Cell
_G.NotCell = Cell

Cell.frames = {}
Cell.buttons = {}
Cell.elapsed = 0
Cell.updateInterval = 0.25
Cell.columns = 8
Cell.rows = 5
Cell.buttonWidth = 130
Cell.buttonHeight = 50
Cell.powerBarHeight = 4
Cell.horizontalGap = 5
Cell.verticalGap = 4
Cell.preview = false
Cell.previewMode = nil
Cell.previewLimit = nil

local partyPreviewUnits = {
	{name = "Empi (You)", class = "PRIEST", health = 1.00, power = 0.82},
	{name = "Thornkeeper", class = "WARRIOR", health = 0.74, power = 0.34},
	{name = "Mosswhisper", class = "DRUID", health = 0.46, power = 0.63},
	{name = "Brightspark", class = "MAGE", health = 0.91, power = 0.91},
	{name = "Quickshadow", class = "ROGUE", health = 0.28, power = 0.76},
}
local statusPreviewUnits = {
	{name = "Ready", class = "PRIEST", health = 0.86, power = 0.75, debuff = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth", debuffCount = 2, debuffType = "Poison", spellID = 12345},
	{name = "Dead", class = "WARRIOR", health = 0.00, power = 0.00, status = "dead"},
	{name = "Ghost", class = "DRUID", health = 0.00, power = 0.00, status = "ghost"},
	{name = "Offline", class = "MAGE", health = 0.58, power = 0.40, status = "offline"},
	{name = "Far away", class = "HUNTER", health = 0.68, power = 0.55, inRange = false},
}
local raidPreviewUnits = {}
local previewClasses = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
local previewPowerTypes = {WARRIOR = 1, ROGUE = 3}
for i = 1, 40 do
	local subgroup = math.floor((i - 1) / 5) + 1
	local member = (i - 1) % 5 + 1
	local health = 0.25 + ((i * 17) % 76) / 100
	raidPreviewUnits[i] = {
		name = "G" .. subgroup .. "-Member" .. member,
		class = previewClasses[(i - 1) % table.getn(previewClasses) + 1],
		health = health,
		power = 0.09 + ((i * 13) % 91) / 100,
	}
	raidPreviewUnits[i].powerType = previewPowerTypes[raidPreviewUnits[i].class] or 0
end

local powerColors = {
	[0] = {0.10, 0.45, 1.00}, -- mana
	[1] = {1.00, 0.12, 0.12}, -- rage
	[2] = {1.00, 0.85, 0.10}, -- focus
	[3] = {1.00, 0.85, 0.10}, -- energy
	[4] = {0.70, 0.50, 0.30}, -- happiness
}

-- Capture first-run state before the helpers below manufacture empty SavedVariables.
-- A renamed addon has a new SavedVariables filename. If an existing Cell user
-- copies the old Cell.lua files to the corresponding NotCell.lua locations,
-- migrate their tables once and save them under NotCell's new names.
if type(NotCellDB) ~= "table" or next(NotCellDB) == nil then
	if type(CellDB) == "table" then NotCellDB = CellDB else NotCellDB = {} end
end
if type(NotCellVanillaDB) ~= "table" or next(NotCellVanillaDB) == nil then
	if type(CellVanillaDB) == "table" and next(CellVanillaDB) ~= nil then
		NotCellVanillaDB = CellVanillaDB
	elseif type(NotCellDB.CellVanillaPreview) == "table" then
		NotCellVanillaDB = NotCellDB.CellVanillaPreview
	else
		NotCellVanillaDB = {}
	end
end
if type(NotCellCharacterDB) ~= "table" or next(NotCellCharacterDB) == nil then
	if type(CellCharacterDB) == "table" then NotCellCharacterDB = CellCharacterDB else NotCellCharacterDB = {} end
end
local function MigrateCellAssetPaths(value)
	if type(value) ~= "table" then return end
	for key, item in pairs(value) do
		if type(item) == "table" then
			MigrateCellAssetPaths(item)
		elseif type(item) == "string" then
			value[key] = string.gsub(item, "Interface\\AddOns\\Cell\\", "Interface\\AddOns\\NotCell\\")
		end
	end
end
MigrateCellAssetPaths(NotCellVanillaDB)
-- Drop the legacy globals after copying so NotCell writes only its own tables.
CellDB = nil
CellVanillaDB = nil
CellCharacterDB = nil
local hasSavedCellProfile = (type(NotCellVanillaDB)=="table" and next(NotCellVanillaDB)~=nil)
	or (type(NotCellDB)=="table" and type(NotCellDB.CellVanillaPreview)=="table" and next(NotCellDB.CellVanillaPreview)~=nil)
local offerHealerIndicator = not hasSavedCellProfile
NotCellVanillaDB = NotCellVanillaDB or {}
local function GetCellSettingsDB()
	NotCellDB = type(NotCellDB) == "table" and NotCellDB or {}
	local settings = type(NotCellVanillaDB) == "table" and NotCellVanillaDB or nil
	local backup = NotCellDB.CellVanillaPreview
	if (not settings or next(settings) == nil) and type(backup) == "table" then
		settings = backup
	end
	if not settings then settings = {} end
	NotCellVanillaDB = settings
	NotCellDB.CellVanillaPreview = settings
	return settings
end

local function SaveCellSettingsDB()
	local settings = GetCellSettingsDB()
	NotCellDB.CellVanillaPreview = settings
	return settings
end

local function GetCharacterClickCastDB()
	NotCellCharacterDB = type(NotCellCharacterDB) == "table" and NotCellCharacterDB or {}
	return NotCellCharacterDB
end

local function SaveClickCastSettings()
	Cell.clickCastProfiles = Cell.clickCastProfiles or {}
	Cell.clickCastProfiles[Cell.activeClickCastProfile] = Cell.clickCasts or {}
	local characterSettings = GetCharacterClickCastDB()
	characterSettings.vanillaClickCastProfiles = Cell.clickCastProfiles
	characterSettings.vanillaClickCastProfileNames = Cell.clickCastProfileNames or {}
	characterSettings.vanillaActiveClickCastProfile = Cell.activeClickCastProfile
	-- One-time migration from releases that kept these fields beside the
	-- account-wide layout and appearance settings.
	local settings = GetCellSettingsDB()
	settings.clickCastProfiles = nil
	settings.clickCastProfileNames = nil
	settings.activeClickCastProfile = nil
	settings.clickCasts = nil
	SaveCellSettingsDB()
end

local function GetMinimapButtonDB()
	local settings = GetCellSettingsDB()
	if type(settings.minimapButton) ~= "table" then
		settings.minimapButton = {shown = true, angle = 220}
	end
	-- The minimap icon is always available; the visibility toggle has been removed.
	settings.minimapButton.shown = true
	return settings.minimapButton
end

local cellSettings = GetCellSettingsDB()
local function LoadDebuffSettings(settings)
	Cell.debuffStyle = settings.debuffStyle or "icon"
	if settings.showDebuffIcons ~= nil then
		Cell.showDebuffIcons = settings.showDebuffIcons
	else
		Cell.showDebuffIcons = settings.showDebuffs ~= false
	end
	Cell.debuffFillMode = settings.debuffFillMode
	if Cell.debuffFillMode ~= "none" and Cell.debuffFillMode ~= "solid" and Cell.debuffFillMode ~= "gradient" then
		if settings.debuffGradientEnabled or Cell.debuffStyle == "half-bar" then Cell.debuffFillMode = "gradient"
		elseif settings.debuffSolidEnabled or Cell.debuffStyle == "tint" then Cell.debuffFillMode = "solid"
		else Cell.debuffFillMode = "none" end
	end
	Cell.debuffBorderSize = math.max(1, math.min(8, tonumber(settings.debuffBorderSize) or 2))
	if settings.debuffBorderEnabled ~= nil then
		Cell.debuffBorderEnabled = settings.debuffBorderEnabled
	else
		Cell.debuffBorderEnabled = Cell.debuffStyle == "border"
	end
	Cell.debuffFillAmount = math.max(10, math.min(100, tonumber(settings.debuffFillAmount) or 50))
	Cell.debuffFillAlpha = math.max(0, math.min(100, tonumber(settings.debuffFillAlpha) or 65))
	local directions = {"left-to-right", "right-to-left", "down-to-up", "up-to-down"}
	Cell.debuffFillDirection = settings.debuffFillDirection or directions[1]
	local directionValid = false
	for i = 1, table.getn(directions) do if directions[i] == Cell.debuffFillDirection then directionValid = true end end
	if not directionValid then Cell.debuffFillDirection = directions[1] end
	Cell.debuffFilterMode = settings.debuffFilterMode or "off"
	if Cell.debuffFilterMode ~= "whitelist" and Cell.debuffFilterMode ~= "blacklist" then Cell.debuffFilterMode = "off" end
	Cell.debuffFilterIDs = type(settings.debuffFilterIDs) == "table" and settings.debuffFilterIDs or {}
end

Cell.healthColorMode = cellSettings.healthColorMode or "custom"
Cell.customHealthColor = cellSettings.customHealthColor or {0.20, 0.72, 0.30}
Cell.deadBackdropEnabled = cellSettings.deadBackdropEnabled and true or false
Cell.customDeadBackdrop = cellSettings.customDeadBackdrop or {0.42, 0.42, 0.42}
Cell.tappedColor = cellSettings.tappedColor or {0.08, 0.08, 0.08}
Cell.healthLossColorMode = cellSettings.healthLossColorMode or "classLight"
Cell.healthLossCustomColor = cellSettings.healthLossCustomColor or Cell.tappedColor
Cell.healthColorAlpha = tonumber(cellSettings.healthColorAlpha) or 95
Cell.healthLossAlpha = tonumber(cellSettings.healthLossAlpha) or 95
Cell.powerColorMode = cellSettings.powerColorMode or "power"
Cell.powerBarCustomColor = cellSettings.powerBarCustomColor or {0.1, 0.35, 0.95}
Cell.powerColorAlpha = tonumber(cellSettings.powerColorAlpha) or 95
Cell.backgroundAlpha = tonumber(cellSettings.backgroundAlpha) or 95
Cell.outOfRangeAlpha = tonumber(cellSettings.outOfRangeAlpha) or 45
Cell.unitTexture = cellSettings.unitTexture or "Interface\\AddOns\\NotCell\\Media\\statusbar.tga"
local function NormalizeBarAnimationMode(mode, legacyDuration)
	if mode == "none" or mode == "instant" then return "none"
	elseif mode == "smooth" then return "smooth"
	elseif mode == "flash" or mode == "shock" then return "flash" end
	return tonumber(legacyDuration) == 0 and "none" or "smooth"
end
Cell.barAnimationMode = NormalizeBarAnimationMode(cellSettings.barAnimationMode, cellSettings.barAnimationDuration)
Cell.targetHighlightColor = cellSettings.targetHighlightColor or {1, 0.68, 0.12}
Cell.mouseoverHighlightColor = cellSettings.mouseoverHighlightColor or {0.15, 0.55, 1}
Cell.targetHighlightEnabled = cellSettings.targetHighlightEnabled ~= false
Cell.mouseoverHighlightEnabled = cellSettings.mouseoverHighlightEnabled ~= false
Cell.healPredictionColor = cellSettings.healPredictionColor or {0.20, 1.00, 0.35}
Cell.healPredictionEnabled = cellSettings.healPredictionEnabled ~= false
local function NormalizeOptionsScale(value)
	value = tonumber(value) or 100
	-- Earlier builds stored scale as a fraction (1.0) while the current slider
	-- stores percentages (100). Convert the legacy form before slider clamping.
	if value > 0 and value <= 2 then value = value * 100 end
	return math.max(60, math.min(140, value))
end
Cell.optionsScale = NormalizeOptionsScale(cellSettings.optionsScale)
Cell.uiAccentColorMode = cellSettings.uiAccentColorMode == "custom" and "custom" or "class"
Cell.uiAccentCustomColor = cellSettings.uiAccentCustomColor or {1, .52, .12}
Cell.rangeFadeEnabled = cellSettings.rangeFadeEnabled ~= false
Cell.showSolo = cellSettings.showSolo ~= false
Cell.showParty = cellSettings.showParty ~= false
Cell.tooltipsEnabled = cellSettings.tooltipsEnabled ~= false
Cell.tooltipsHideInCombat = cellSettings.tooltipsHideInCombat and true or false
LoadDebuffSettings(cellSettings)
Cell.nameColorMode = cellSettings.nameColorMode or "class"
Cell.nameCustomColor = cellSettings.nameCustomColor or {1, 1, 1}
Cell.nameFontIndex = cellSettings.nameFontIndex or 1
Cell.nameFontSize = cellSettings.nameFontSize or 14
Cell.nameFontOutline = cellSettings.nameFontOutline or 2
Cell.showHealthValues = cellSettings.showHealthValues ~= false
Cell.healthValueFormat = cellSettings.healthValueFormat or "percent"
Cell.healthTextFontIndex = cellSettings.healthTextFontIndex or 1
Cell.healthTextFontSize = cellSettings.healthTextFontSize or 10
Cell.healthTextFontOutline = cellSettings.healthTextFontOutline or 2
Cell.healthTextColorMode = cellSettings.healthTextColorMode or "custom"
Cell.healthTextCustomColor = cellSettings.healthTextCustomColor or {1, 1, 1}
Cell.healthTextAnchor = cellSettings.healthTextAnchor or "BOTTOMRIGHT"
Cell.showPowerValues = cellSettings.showPowerValues ~= false
Cell.powerValueFormat = cellSettings.powerValueFormat or "percent"
Cell.powerTextFontIndex = cellSettings.powerTextFontIndex or 1
Cell.powerTextFontSize = cellSettings.powerTextFontSize or 10
Cell.powerTextFontOutline = cellSettings.powerTextFontOutline or 2
Cell.powerTextColorMode = cellSettings.powerTextColorMode or "custom"
Cell.powerTextCustomColor = cellSettings.powerTextCustomColor or {1, 1, 1}
Cell.powerTextAnchor = cellSettings.powerTextAnchor or "BOTTOM"
Cell.nameAnchor = cellSettings.nameAnchor or "TOPLEFT"
Cell.powerBarHeight = math.max(2, math.min(12, tonumber(cellSettings.powerBarHeight) or 4))
local characterClickSettings = GetCharacterClickCastDB()
Cell.clickCastProfiles = type(characterClickSettings.vanillaClickCastProfiles) == "table" and characterClickSettings.vanillaClickCastProfiles
	 or (type(cellSettings.clickCastProfiles) == "table" and cellSettings.clickCastProfiles) or {}
Cell.clickCastCharacterKey = (GetRealmName and GetRealmName() or "Realm") .. "-" .. (UnitName and UnitName("player") or "Character")
Cell.clickCastProfiles.common = Cell.clickCastProfiles.common or (type(characterClickSettings.vanillaClickCasts) == "table" and characterClickSettings.vanillaClickCasts or (type(cellSettings.clickCasts) == "table" and cellSettings.clickCasts or {}))
Cell.clickCastProfiles[Cell.clickCastCharacterKey] = Cell.clickCastProfiles[Cell.clickCastCharacterKey] or {}
Cell.clickCastProfileNames = type(characterClickSettings.vanillaClickCastProfileNames) == "table" and characterClickSettings.vanillaClickCastProfileNames
	 or (type(cellSettings.clickCastProfileNames) == "table" and cellSettings.clickCastProfileNames) or {}
Cell.clickCastProfileNames.common = "Common"
Cell.clickCastProfileNames[Cell.clickCastCharacterKey] = Cell.clickCastProfileNames[Cell.clickCastCharacterKey] or (UnitName and UnitName("player") or "This character")
Cell.activeClickCastProfile = characterClickSettings.vanillaActiveClickCastProfile or cellSettings.activeClickCastProfile or "common"
if not Cell.clickCastProfiles[Cell.activeClickCastProfile] then Cell.activeClickCastProfile = "common" end
Cell.clickCasts = Cell.clickCastProfiles[Cell.activeClickCastProfile]
Cell.autoGroupLayouts = cellSettings.autoGroupLayouts and true or false
local legacyLayoutProfiles = type(cellSettings.groupLayoutProfiles) == "table" and cellSettings.groupLayoutProfiles or {}
Cell.groupLayoutProfiles = type(cellSettings.layouts) == "table" and cellSettings.layouts or {}
local builtInLayouts = {Default=true}
if not Cell.groupLayoutProfiles.Default then
	-- Migrate the former per-group layout model. Keep Party as the starting profile,
	-- then make former user-created layouts available as independent profiles.
	local startingProfile = legacyLayoutProfiles.party or legacyLayoutProfiles[cellSettings.selectedGroupLayout] or {}
	Cell.groupLayoutProfiles.Default = startingProfile
	for key, profile in pairs(legacyLayoutProfiles) do
		if type(key) == "string" and type(profile) == "table" and key ~= "solo" and key ~= "party" and key ~= "raidOutdoor" and key ~= "raid10" and key ~= "raid25" and key ~= "raid40" then
			Cell.groupLayoutProfiles[key] = profile
		end
	end
end
Cell.groupLayoutNames = {}
Cell.groupLayoutLabels = {}
for key, profile in pairs(Cell.groupLayoutProfiles) do
	if type(key) == "string" and type(profile) == "table" then
		Cell.groupLayoutNames[#Cell.groupLayoutNames + 1] = key
		Cell.groupLayoutLabels[key] = key == "Default" and "Default" or (profile.displayName or key)
	end
end
if not Cell.groupLayoutProfiles.Default then Cell.groupLayoutProfiles.Default = {}; table.insert(Cell.groupLayoutNames, 1, "Default"); Cell.groupLayoutLabels.Default = "Default" end
table.sort(Cell.groupLayoutNames, function(a, b) if a == "Default" then return true elseif b == "Default" then return false else return a < b end end)
Cell.layoutAutoSwitch = type(cellSettings.layoutAutoSwitch) == "table" and cellSettings.layoutAutoSwitch or {}
local groupLayoutDefaults = {solo="Default", party="Default", raid_outdoor="Default", raid10="Default", raid25="Default", raid40="Default"}
for groupType, defaultLayout in pairs(groupLayoutDefaults) do
	local selected = Cell.layoutAutoSwitch[groupType]
	if selected == "hide" then
		Cell.layoutAutoSwitch[groupType] = "hide"
	elseif Cell.groupLayoutProfiles[selected] then
		Cell.layoutAutoSwitch[groupType] = selected
	elseif legacyLayoutProfiles[selected] then
		local builtIn = selected == "solo" or selected == "party" or selected == "raidOutdoor" or selected == "raid10" or selected == "raid25" or selected == "raid40"
		Cell.layoutAutoSwitch[groupType] = builtIn and "Default" or selected
	else
		Cell.layoutAutoSwitch[groupType] = defaultLayout
	end
end
local SaveContainerPosition
local SaveContainerPositionAfterMove
local initialContainerPosition = type(cellSettings.containerPosition) == "table" and cellSettings.containerPosition or nil
for _, key in ipairs(Cell.groupLayoutNames) do
	local profile = Cell.groupLayoutProfiles[key]
	if type(profile) ~= "table" then profile = {}; Cell.groupLayoutProfiles[key] = profile end
	profile.width = math.max(40, math.min(300, tonumber(profile.width) or Cell.buttonWidth))
	profile.height = math.max(32, math.min(120, tonumber(profile.height) or Cell.buttonHeight))
	profile.powerBarHeight = math.max(2, math.min(12, tonumber(profile.powerBarHeight) or Cell.powerBarHeight))
	profile.healthBarOrientation = profile.healthBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
	profile.powerBarOrientation = profile.powerBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
	profile.powerBarSide = profile.powerBarSide == "RIGHT" and "RIGHT" or "LEFT"
	profile.nameFontSize = math.max(10, math.min(20, tonumber(profile.nameFontSize) or Cell.nameFontSize))
	profile.healthTextFontSize = math.max(8, math.min(20, tonumber(profile.healthTextFontSize) or Cell.healthTextFontSize))
	profile.powerTextFontSize = math.max(8, math.min(20, tonumber(profile.powerTextFontSize) or Cell.powerTextFontSize))
	profile.groupsPerLine = math.max(1, math.min(8, tonumber(profile.groupsPerLine) or 4))
	profile.groupFilter = type(profile.groupFilter) == "table" and profile.groupFilter or {}
	for group = 1, 8 do if profile.groupFilter[group] == nil then profile.groupFilter[group] = true end end
	profile.direction = profile.direction or ((profile.growth == "right-down" or profile.growth == "left-down") and "right-down" or "down-right")
	profile.spacingX = math.max(0, math.min(100, tonumber(profile.spacingX) or Cell.horizontalGap or 5))
	profile.spacingY = math.max(0, math.min(100, tonumber(profile.spacingY) or Cell.verticalGap or 4))
	if type(profile.position) ~= "table" and initialContainerPosition and initialContainerPosition.x and initialContainerPosition.y then
		profile.position = {x = initialContainerPosition.x, y = initialContainerPosition.y}
	end
end
	Cell.selectedGroupLayout = (cellSettings.selectedLayout and Cell.groupLayoutProfiles[cellSettings.selectedLayout] and cellSettings.selectedLayout) or (cellSettings.selectedGroupLayout and Cell.groupLayoutProfiles[cellSettings.selectedGroupLayout] and cellSettings.selectedGroupLayout) or "Default"
local selectedInitialProfile = Cell.groupLayoutProfiles[Cell.selectedGroupLayout] or {}
Cell.healthBarOrientation = selectedInitialProfile.healthBarOrientation or "HORIZONTAL"
Cell.powerBarOrientation = selectedInitialProfile.powerBarOrientation or "HORIZONTAL"
Cell.powerBarSide = selectedInitialProfile.powerBarSide or "LEFT"
local function GetDisplayedLayoutProfile()
	local key = Cell.preview and Cell.previewGroupLayout or (Cell.autoGroupLayouts and Cell.activeGroupLayout) or Cell.selectedGroupLayout
	if key and string.sub(key, 1, 8) == "preview-" then key = string.sub(key, 9) end
	return key and Cell.groupLayoutProfiles[key] or nil
end
local function GetDisplayedSpacing()
	local profile = GetDisplayedLayoutProfile() or {}
	return tonumber(profile.spacingX) or Cell.horizontalGap, tonumber(profile.spacingY) or Cell.verticalGap
end
local function GetDisplayedFontSize(field, fallback)
	local profile = GetDisplayedLayoutProfile()
	return profile and profile[field] or fallback
end
local function GetDisplayedIndicatorSettings(key)
	local profile = GetDisplayedLayoutProfile()
	return profile and type(profile.indicators) == "table" and profile.indicators[key] or nil
end
local function GetSelectedFontSize(field, fallback)
	local profile = Cell.groupLayoutProfiles[Cell.selectedGroupLayout]
	return profile and profile[field] or fallback
end
local directionModes = {"down-right", "right-down"}
local directionLabels = { ["down-right"] = "Down then right", ["right-down"] = "Right then down" }
local function GetGroupGridPosition(index)
	local profile = GetDisplayedLayoutProfile() or {}
	local groupsPerLine = math.max(1, math.min(8, tonumber(profile.groupsPerLine) or 4))
	local direction = profile.direction or "down-right"
	local groupIndex = math.floor((index - 1) / 5)
	local memberIndex = (index - 1) % 5
	if direction == "right-down" then
		local groupColumn = math.floor(groupIndex / groupsPerLine)
		local groupRow = groupIndex % groupsPerLine
		return groupColumn * 5 + memberIndex, groupRow
	end
	local groupRow = math.floor(groupIndex / groupsPerLine)
	local groupColumn = groupIndex % groupsPerLine
	return groupColumn, groupRow * 5 + memberIndex
end
local function GetGroupGridSize(count)
	local profile = GetDisplayedLayoutProfile() or {}
	local groupsPerLine = math.max(1, math.min(8, tonumber(profile.groupsPerLine) or 4))
	local groupCount = math.max(1, math.ceil(math.min(count or 1, 40) / 5))
	local direction = profile.direction or "down-right"
	if direction == "right-down" then
		return math.ceil(groupCount / groupsPerLine) * 5, math.min(groupCount, groupsPerLine)
	end
	return math.min(groupCount, groupsPerLine), math.ceil(groupCount / groupsPerLine) * 5
end
local function GetEnabledGroupNumbers(profile)
	local result = {}
	local filter = profile and profile.groupFilter
	for group = 1, 8 do if not filter or filter[group] ~= false then result[#result + 1] = group end end
	return result
end
local function GetGroupDisplayRank(group, enabledGroups)
	for rank = 1, table.getn(enabledGroups) do if enabledGroups[rank] == group then return rank end end
	return nil
end
local nameFonts = {
	{name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF"},
	{name = "Arial Narrow", path = "Fonts\\ARIALN.TTF"},
	{name = "Morpheus", path = "Fonts\\MORPHEUS.TTF"},
	{name = "Skurri", path = "Fonts\\SKURRI.TTF"},
	{name = "Accidental Presidency", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\Accidental_Presidency.ttf"},
	{name = "Big Noodle Titling Oblique", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\big_noodle_titling_oblique.ttf"},
	{name = "Big Noodle Titling", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\big_noodle_titling.ttf"},
	{name = "Continuum Medium", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\ContinuumMedium.ttf"},
	{name = "Die Die Die", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\DieDieDie.ttf"},
	{name = "Expressway", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\Expressway.ttf"},
	{name = "Homespun", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\Homespun.ttf"},
	{name = "PT Sans Narrow", path = "Interface\\AddOns\\NotCell\\Media\\Fonts\\PTSansNarrow.ttf"},
}
Cell.indicatorFonts = nameFonts
local sharedMedia = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibSharedMedia-3.0", true)
if sharedMedia then
	local ok, mediaNames = pcall(sharedMedia.List, sharedMedia, "font")
	if ok and type(mediaNames) == "table" then
		for _, mediaName in ipairs(mediaNames) do
			local path = sharedMedia:Fetch("font", mediaName, true)
			if path then nameFonts[table.getn(nameFonts)+1] = {name="Shared: " .. mediaName, path=path} end
		end
	end
end
local nameOutlines = {{name = "None", flag = ""}, {name = "Outline", flag = "OUTLINE"}, {name = "Thick", flag = "THICKOUTLINE"}}
local fontSizes = {8, 9, 10, 11, 12, 13, 14, 16, 18, 20}
local textAnchors = {
	{name = "Top left", value = "TOPLEFT"}, {name = "Top", value = "TOP"}, {name = "Top right", value = "TOPRIGHT"},
	{name = "Left", value = "LEFT"}, {name = "Center", value = "CENTER"}, {name = "Right", value = "RIGHT"},
	{name = "Bottom left", value = "BOTTOMLEFT"}, {name = "Bottom", value = "BOTTOM"}, {name = "Bottom right", value = "BOTTOMRIGHT"},
}
Cell.hideBlizzardFrames = cellSettings.hideBlizzardFrames ~= false
-- Movers are always locked after a reload; users can unlock them temporarily.
Cell.framesLocked = cellSettings.framesLocked and true or false
GetMinimapButtonDB()

local blizzardUnitFrameNames = {"PlayerFrame", "TargetFrame", "TargetFrameToT", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4", "ShaguTweaksRaidCluster", "ShaguTweaksRaidFrame"}
-- Hiding is deliberately narrower than click-casting: Blizzard's player and
-- target frames remain visible when users hide only raid/party group frames.
local blizzardGroupFrameNames = {"PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4", "ShaguTweaksRaidCluster", "ShaguTweaksRaidFrame"}
for group = 1, 8 do
	blizzardUnitFrameNames[table.getn(blizzardUnitFrameNames) + 1] = "RaidGroup" .. group
	blizzardUnitFrameNames[table.getn(blizzardUnitFrameNames) + 1] = "RaidPullout" .. group
	blizzardGroupFrameNames[table.getn(blizzardGroupFrameNames) + 1] = "RaidGroup" .. group
	blizzardGroupFrameNames[table.getn(blizzardGroupFrameNames) + 1] = "RaidPullout" .. group
	for member = 1, 5 do
		blizzardUnitFrameNames[table.getn(blizzardUnitFrameNames) + 1] = "RaidGroup" .. group .. "Button" .. member
		blizzardGroupFrameNames[table.getn(blizzardGroupFrameNames) + 1] = "RaidGroup" .. group .. "Button" .. member
	end
end

local function HideFrame(frame)
	if type(frame) == "table" and type(frame.Hide) == "function" then
		if not Cell.blizzardFrameWasShown then Cell.blizzardFrameWasShown = {} end
		if Cell.blizzardFrameWasShown[frame] == nil then
			if type(frame.IsShown) == "function" then
				Cell.blizzardFrameWasShown[frame] = frame:IsShown()
			else
				Cell.blizzardFrameWasShown[frame] = true
			end
		end
		frame:Hide()
		return true
	end
	return false
end

function Cell:UpdateBlizzardFrames()
	local found = 0
	for i = 1, table.getn(blizzardGroupFrameNames) do
		local frame = getglobal(blizzardGroupFrameNames[i])
		if frame then
			found = found + 1
			if self.hideBlizzardFrames then HideFrame(frame) end
		end
	end
	return found
end

function Cell:SetBlizzardFramesHidden(hidden)
	self.hideBlizzardFrames = hidden and true or false
	NotCellVanillaDB = GetCellSettingsDB()
	NotCellVanillaDB.hideBlizzardFrames = self.hideBlizzardFrames
	SaveCellSettingsDB()
	if not self.hideBlizzardFrames then
		for frame, wasShown in pairs(self.blizzardFrameWasShown or {}) do
			if wasShown then frame:Show() else frame:Hide() end
		end
		self.blizzardFrameWasShown = nil
	end
	self:UpdateBlizzardFrames()
	self:RefreshOptionsMenu()
end

local function GetUIAccentColor()
	if Cell.uiAccentColorMode == "custom" then
		local color = Cell.uiAccentCustomColor or {1,.52,.12}
		return color[1] or 1, color[2] or .52, color[3] or .12
	end
	local classToken
	if UnitClass then local _, token = UnitClass("player"); classToken = token end
	local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
	if color then return color.r, color.g, color.b end
	return 1, .52, .12
end

local function RegisterAccentRefresher(callback)
	Cell.uiAccentRefreshers = Cell.uiAccentRefreshers or {}
	Cell.uiAccentRefreshers[table.getn(Cell.uiAccentRefreshers) + 1] = callback
end

function Cell:RefreshUIAccent()
	for _, callback in ipairs(self.uiAccentRefreshers or {}) do callback() end
end

local function AddOptionsButton(parent, text, x, y, width, callback)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width)
	button:SetHeight(24)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(button)
	background:SetTexture("Interface\\Buttons\\WHITE8X8")
	button.cellBackground = background
	button.cellBorder = {}
	for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
		local line = button:CreateTexture(nil, "BORDER")
		line:SetTexture("Interface\\Buttons\\WHITE8X8")
		local r,g,b=GetUIAccentColor(); line:SetVertexColor(r*.62,g*.42,b*.20,1)
		if edge == "TOP" or edge == "BOTTOM" then
			line:SetPoint(edge, button, edge, 0, 0); line:SetPoint("LEFT",button,"LEFT",0,0); line:SetPoint("RIGHT",button,"RIGHT",0,0); line:SetHeight(1)
		else
			line:SetPoint(edge, button, edge, 0, 0); line:SetPoint("TOP",button,"TOP",0,0); line:SetPoint("BOTTOM",button,"BOTTOM",0,0); line:SetWidth(1)
		end
		button.cellBorder[edge] = line
	end
	local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.cellLabel = label
	function button:SetText(value) self.cellLabel:SetText(value or "") end
	function button:GetText() return self.cellLabel:GetText() end
	button:SetText(text)
	button:SetScript("OnEnter", function(self)
		self.cellBackground:SetVertexColor(0.20, 0.20, 0.20, 1)
		self.cellLabel:SetTextColor(GetUIAccentColor())
	end)
	button:SetScript("OnLeave", function(self)
		self.cellBackground:SetVertexColor(0.08, 0.08, 0.08, 1)
		self.cellLabel:SetTextColor(0.90, 0.90, 0.90)
	end)
	background:SetVertexColor(0.08, 0.08, 0.08, 1)
	label:SetTextColor(0.90, 0.90, 0.90)
	button:SetScript("OnClick", callback)
	RegisterAccentRefresher(function()
		local r,g,b=GetUIAccentColor()
		local red, green, blue = r*.62, g*.42, b*.20
		if button.cellDropdownListItem then red, green, blue = .16, .22, .25 end
		for _,line in pairs(button.cellBorder) do line:SetVertexColor(red, green, blue, 1) end
	end)
	return button
end

local function AddOptionsCheckbox(parent, text, x, y, width, callback, boxSize, fontObject)
	boxSize = boxSize or 14
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width); button:SetHeight(boxSize + 4); button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local box = button:CreateTexture(nil, "BACKGROUND")
	box:SetTexture("Interface\\Buttons\\WHITE8X8"); box:SetVertexColor(0.035, 0.035, 0.035, 1)
	box:SetWidth(boxSize); box:SetHeight(boxSize); box:SetPoint("LEFT", button, "LEFT", 0, 0)
	local border = {}
	for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
		local line = button:CreateTexture(nil, "BORDER")
		line:SetTexture("Interface\\Buttons\\WHITE8X8"); local r,g,b=GetUIAccentColor(); line:SetVertexColor(r*.62,g*.42,b*.20,1)
		if edge == "TOP" or edge == "BOTTOM" then line:SetPoint(edge, box, edge, 0, 0); line:SetWidth(boxSize); line:SetHeight(1)
		else line:SetPoint(edge, box, edge, 0, 0); line:SetWidth(1); line:SetHeight(boxSize) end
		border[edge] = line
	end
	local check = button:CreateTexture(nil, "ARTWORK")
	-- A tick-shaped mark stays distinct from the square color swatches, including
	-- when the user's accent color is white or another very light color.
	check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); check:SetVertexColor(GetUIAccentColor())
	local inset = boxSize > 14 and 2 or 1
	check:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset); check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset); check:Hide()
	local label = button:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormalSmall")
	label:SetPoint("LEFT", box, "RIGHT", 6, 0); label:SetPoint("RIGHT", button, "RIGHT", 0, 0); label:SetJustifyH("LEFT"); label:SetText(text)
	button.checkMark = check; button.label = label
	function button:SetChecked(checked) self.checked = checked and true or false; if self.checked then self.checkMark:Show() else self.checkMark:Hide() end end
	button:SetScript("OnEnter", function(self) self.label:SetTextColor(GetUIAccentColor()) end)
	button:SetScript("OnLeave", function(self) self.label:SetTextColor(0.90, 0.90, 0.90) end)
	button:SetScript("OnClick", callback)
	button:SetChecked(false)
	RegisterAccentRefresher(function()
		local r,g,b=GetUIAccentColor(); check:SetVertexColor(r,g,b,1)
		for _,line in pairs(border) do line:SetVertexColor(r*.62,g*.42,b*.20,1) end
	end)
	return button
end

local function AddCategoryButton(parent, text, x, y, width, callback, categoryStyle)
	local button = CreateFrame("Button", nil, parent)
	button.categoryStyle = categoryStyle or "main"
	button:SetWidth(width); button:SetHeight(24)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(button)
	background:SetTexture("Interface\\Buttons\\WHITE8X8")
	button.categoryBackground = background
	local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText(text)
	button.categoryLabel = label
	local accent = button:CreateTexture(nil, "OVERLAY")
	accent:SetTexture("Interface\\Buttons\\WHITE8X8")
	accent:SetHeight(2); accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0); accent:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	button.categoryAccent = accent
	function button:SetSelected(selected)
		self.categorySelected = selected and true or false
		if self.categorySelected then
			if self.categoryStyle == "sub" then
				local r,g,b=GetUIAccentColor()
				self.categoryBackground:SetVertexColor(r*.26,g*.16,b*.08,1)
				self.categoryLabel:SetTextColor(r,g,b)
				self.categoryAccent:SetVertexColor(r,g,b,1); self.categoryAccent:Show()
			else
				local r,g,b=GetUIAccentColor()
				self.categoryBackground:SetVertexColor(r*.46,g*.22,b*.05,1)
				self.categoryLabel:SetTextColor(r,g,b)
				self.categoryAccent:Hide()
			end
		else
			self.categoryBackground:SetVertexColor(0.08, 0.08, 0.08, 1)
			self.categoryLabel:SetTextColor(0.88, 0.88, 0.88)
			self.categoryAccent:Hide()
		end
	end
	button:SetScript("OnEnter", function(self)
		if not self.categorySelected then self.categoryBackground:SetVertexColor(0.20, 0.20, 0.20, 1); self.categoryLabel:SetTextColor(GetUIAccentColor()) end
	end)
	button:SetScript("OnLeave", function(self)
		if not self.categorySelected then self.categoryBackground:SetVertexColor(0.08, 0.08, 0.08, 1); self.categoryLabel:SetTextColor(0.88, 0.88, 0.88) end
	end)
	button:SetScript("OnClick", callback)
	button:SetSelected(false)
	RegisterAccentRefresher(function() button:SetSelected(button.categorySelected) end)
	return button
end

-- Shared value-box styling for every options slider. Keep dimensions and colors
-- here so sliders added by any option page inherit the same Vanilla-safe look.
local SLIDER_VALUE_BOX_STYLE = {
	width = 40,
	height = 14,
	background = {.025, .025, .025, 1},
	border = {.30, .20, .10, 1},
}
-- Shared vertical/horizontal rhythm for every slider built through
-- AddOptionsSlider: label at y, track at y-22, range labels at y-29,
-- compact value field at y-42; reserve at least 60px before the next row.
local SLIDER_LAYOUT = {
	trackOffset = 22,
	rangeLabelOffset = 29,
	valueOffset = 42,
	trackInset = 22,
	rangeLabelInset = 17,
	rowPitch = 60,
	valueBackgroundX = 3,
	valueBackgroundY = 2,
}
Cell.OptionsSliderLayout = SLIDER_LAYOUT

local function AddOptionsSlider(parent, label, x, y, width, minValue, maxValue, step, value, callback)
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	title:SetText(label)
	local valueBox = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	valueBox:SetPoint("TOP", parent, "TOPLEFT", x + width / 2, y - SLIDER_LAYOUT.valueOffset)
	valueBox:SetWidth(SLIDER_VALUE_BOX_STYLE.width); valueBox:SetHeight(SLIDER_VALUE_BOX_STYLE.height); valueBox:SetJustifyH("CENTER")
	local valueBackground = parent:CreateTexture(nil, "BACKGROUND")
	valueBackground:SetTexture("Interface\\Buttons\\WHITE8X8"); valueBackground:SetPoint("TOPLEFT", valueBox, "TOPLEFT", -SLIDER_LAYOUT.valueBackgroundX, SLIDER_LAYOUT.valueBackgroundY); valueBackground:SetPoint("BOTTOMRIGHT", valueBox, "BOTTOMRIGHT", SLIDER_LAYOUT.valueBackgroundX, -SLIDER_LAYOUT.valueBackgroundY); valueBackground:SetVertexColor(unpack(SLIDER_VALUE_BOX_STYLE.background))
	local valueBorder = {}
	for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
		local line=parent:CreateTexture(nil,"BORDER"); line:SetTexture("Interface\\Buttons\\WHITE8X8"); line:SetVertexColor(unpack(SLIDER_VALUE_BOX_STYLE.border))
		if edge=="TOP" or edge=="BOTTOM" then line:SetPoint(edge,valueBackground,edge,0,0); line:SetWidth(SLIDER_VALUE_BOX_STYLE.width+SLIDER_LAYOUT.valueBackgroundX*2); line:SetHeight(1)
		else line:SetPoint(edge,valueBackground,edge,0,0); line:SetWidth(1); line:SetHeight(SLIDER_VALUE_BOX_STYLE.height+SLIDER_LAYOUT.valueBackgroundY*2) end
		valueBorder[edge]=line
	end
	valueBox:SetTextColor(GetUIAccentColor())
	local minimum = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	minimum:SetPoint("RIGHT", parent, "TOPLEFT", x + SLIDER_LAYOUT.rangeLabelInset, y - SLIDER_LAYOUT.rangeLabelOffset); minimum:SetText(tostring(minValue)); minimum:SetTextColor(.82,.82,.82)
	local maximum = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	maximum:SetPoint("LEFT", parent, "TOPLEFT", x + width - SLIDER_LAYOUT.rangeLabelInset, y - SLIDER_LAYOUT.rangeLabelOffset); maximum:SetText(tostring(maxValue)); maximum:SetTextColor(.82,.82,.82)
	local slider = CreateFrame("Slider", nil, parent)
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + SLIDER_LAYOUT.trackInset, y - SLIDER_LAYOUT.trackOffset)
	slider:SetWidth(width - SLIDER_LAYOUT.trackInset * 2)
	slider:SetHeight(14)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider:SetOrientation("HORIZONTAL")
	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetTexture("Interface\\Buttons\\WHITE8X8")
	track:SetPoint("LEFT", slider, "LEFT", 0, 0)
	track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
	track:SetHeight(12)
	track:SetVertexColor(.035,.035,.035,1)
	local trackBorder={}
	for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
		local line=slider:CreateTexture(nil,"BORDER"); line:SetTexture("Interface\\Buttons\\WHITE8X8"); line:SetVertexColor(.34,.34,.34,1)
		if edge=="TOP" or edge=="BOTTOM" then line:SetPoint(edge,track,edge,0,0); line:SetWidth(width-SLIDER_LAYOUT.trackInset*2); line:SetHeight(1)
		else line:SetPoint(edge,track,edge,0,0); line:SetWidth(1); line:SetHeight(12) end
		trackBorder[edge]=line
	end
	slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	local thumb = slider:GetThumbTexture()
	if thumb then thumb:SetWidth(14); thumb:SetHeight(14); thumb:SetVertexColor(GetUIAccentColor()) end
	slider:SetValue(value)
	local function NormalizeValue(v)
		v = math.max(minValue, math.min(maxValue, tonumber(v) or minValue))
		return math.floor((v - minValue) / step + 0.5) * step + minValue
	end
	local function UpdateValue(v, apply)
		local rounded = NormalizeValue(v)
		valueBox:SetText(tostring(rounded))
		if apply then callback(rounded) end
		return rounded
	end
	UpdateValue(value, false)
	slider.valueBox = valueBox
	slider.valueBackground = valueBackground
	slider.label = title
	slider.optionX, slider.optionY, slider.optionWidth = x, y, width
	slider:SetScript("OnValueChanged", function(self, newValue)
		UpdateValue(newValue, true)
	end)
	slider.minimumLabel, slider.maximumLabel = minimum, maximum
	slider.trackBorder = trackBorder
	slider.valueBorder = valueBorder
	RegisterAccentRefresher(function()
		local r,g,b=GetUIAccentColor()
		if thumb then thumb:SetVertexColor(r,g,b,1) end
		valueBox:SetTextColor(r,g,b)
		for _,line in pairs(valueBorder) do line:SetVertexColor(r*.62,g*.42,b*.20,1) end
		for _,line in pairs(trackBorder) do line:SetVertexColor(r*.45,g*.36,b*.24,1) end
	end)
	return slider, valueBox
end

function Cell:PlaceOptionsSlider(slider, parent, x, y, width)
	if not slider then return end
	slider.optionX, slider.optionY, slider.optionWidth = x, y, width
	slider.label:ClearAllPoints(); slider.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	slider:ClearAllPoints(); slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + SLIDER_LAYOUT.trackInset, y - SLIDER_LAYOUT.trackOffset); slider:SetWidth(width - SLIDER_LAYOUT.trackInset * 2)
	slider.valueBox:ClearAllPoints(); slider.valueBox:SetPoint("TOP", parent, "TOPLEFT", x + width / 2, y - SLIDER_LAYOUT.valueOffset)
	slider.minimumLabel:ClearAllPoints(); slider.minimumLabel:SetPoint("RIGHT", parent, "TOPLEFT", x + SLIDER_LAYOUT.rangeLabelInset, y - SLIDER_LAYOUT.rangeLabelOffset)
	slider.maximumLabel:ClearAllPoints(); slider.maximumLabel:SetPoint("LEFT", parent, "TOPLEFT", x + width - SLIDER_LAYOUT.rangeLabelInset, y - SLIDER_LAYOUT.rangeLabelOffset)
	for _, line in pairs(slider.trackBorder or {}) do if line:GetHeight() == 1 then line:SetWidth(width - SLIDER_LAYOUT.trackInset * 2) end end
end

-- Responsive two-dimensional page layout for future option sections.
-- Each item can occupy a grid column or span several columns; fixed-width
-- controls may be right-aligned within their cell (for example color swatches).
function Cell:CreateOptionsGrid(parent, columns, gap)
	local grid = {parent = parent, columns = columns or 2, gap = gap or 16, items = {}}
	function grid:Add(widget, y, column, span, fixedWidth, align, slider)
		self.items[#self.items + 1] = {widget = widget, y = y, column = column or 1, span = span or 1, fixedWidth = fixedWidth, align = align, slider = slider}
	end
	function grid:Layout()
		local width = math.max(1, self.parent:GetWidth() - 20)
		local cellWidth = (width - (self.columns - 1) * self.gap) / self.columns
		for _, item in ipairs(self.items) do
			local x = 10 + (item.column - 1) * (cellWidth + self.gap)
			local cellSpanWidth = cellWidth * item.span + self.gap * (item.span - 1)
			local itemWidth = type(item.fixedWidth) == "function" and item.fixedWidth(cellWidth, cellSpanWidth) or item.fixedWidth or cellSpanWidth
			if item.align == "right" then x = x + cellSpanWidth - itemWidth end
			if item.slider then
				Cell:PlaceOptionsSlider(item.widget, self.parent, x, item.y, itemWidth)
			else
				item.widget:ClearAllPoints(); item.widget:SetPoint("TOPLEFT", self.parent, "TOPLEFT", x, item.y); item.widget:SetWidth(itemWidth)
			end
		end
	end
	return grid
end

function Cell:RefreshOptionsMenu()
	if not self.optionsFrame then return end
	NotCellVanillaDB = GetCellSettingsDB()
	self:RefreshUIAccent()
	if self.optionsFrame.healthFillModeButton then
		local modeName = self.healthColorMode == "value" and "health-by-value" or self.healthColorMode
		self.optionsFrame.healthFillModeButton:SetText("Health color: " .. modeName)
	end
	if self.optionsFrame.blizzardButton then
		self.optionsFrame.blizzardButton:SetText(self.hideBlizzardFrames and "Show Blizzard unitframes" or "Hide Blizzard unitframes")
	end
	if self.optionsFrame.positionButton then
		self.optionsFrame.positionButton:SetText(self.framesLocked and "Unlock frame position" or "Lock frame position")
	end
	if self.optionsFrame.showSoloCheckbox then self.optionsFrame.showSoloCheckbox:SetChecked(self.showSolo) end
	if self.optionsFrame.showPartyCheckbox then self.optionsFrame.showPartyCheckbox:SetChecked(self.showParty) end
	if self.optionsFrame.tooltipsEnabledCheckbox then self.optionsFrame.tooltipsEnabledCheckbox:SetChecked(self.tooltipsEnabled) end
	if self.optionsFrame.tooltipsCombatCheckbox then
		self.optionsFrame.tooltipsCombatCheckbox:SetChecked(self.tooltipsHideInCombat)
		if self.tooltipsEnabled then self.optionsFrame.tooltipsCombatCheckbox:Enable() else self.optionsFrame.tooltipsCombatCheckbox:Disable() end
	end
	if self.optionsFrame.generalBlizzardCheckbox then self.optionsFrame.generalBlizzardCheckbox:SetChecked(self.hideBlizzardFrames) end
	if self.optionsFrame.generalPositionCheckbox then self.optionsFrame.generalPositionCheckbox:SetChecked(self.framesLocked) end
	if self.optionsFrame.healPredictionCheckbox then self.optionsFrame.healPredictionCheckbox:SetChecked(self.healPredictionEnabled) end
	local setupWizard = self.setupWizardFrame
	if setupWizard and setupWizard.healPredictionCheckbox then
		setupWizard.healPredictionCheckbox:SetChecked(self.healPredictionEnabled)
		if setupWizard.UpdateGuidePreview then setupWizard.UpdateGuidePreview() end
	end
	if self.optionsFrame.targetHighlightCheckbox then self.optionsFrame.targetHighlightCheckbox:SetChecked(self.targetHighlightEnabled) end
	if self.optionsFrame.mouseoverHighlightCheckbox then self.optionsFrame.mouseoverHighlightCheckbox:SetChecked(self.mouseoverHighlightEnabled) end
	if self.optionsFrame.debuffCheckbox then self.optionsFrame.debuffCheckbox:SetChecked(self.showDebuffIcons) end
	if self.optionsFrame.debuffBorderCheckbox then self.optionsFrame.debuffBorderCheckbox:SetChecked(self.debuffBorderEnabled) end
	if self.optionsFrame.debuffFillButton then
		self.optionsFrame.debuffFillButton:SetText("Debuff fill: " .. self.debuffFillMode)
		self.optionsFrame.debuffBorderSizeButton:SetText("Debuff border size: " .. self.debuffBorderSize .. " px")
		self.optionsFrame.debuffFillAmountButton:SetText("Debuff fill amount: " .. self.debuffFillAmount .. "%")
		self.optionsFrame.debuffDirectionButton:SetText("Fill direction: " .. self.debuffFillDirection)
	end
	if self.optionsFrame.deadBackdropCheckbox then self.optionsFrame.deadBackdropCheckbox:SetChecked(self.deadBackdropEnabled) end
	local selectedLayout = self.groupLayoutProfiles and self.groupLayoutProfiles[self.selectedGroupLayout]
	self.syncingLayoutControls = true
	if self.optionsFrame.widthSlider then self.optionsFrame.widthSlider:SetValue(selectedLayout and selectedLayout.width or self.buttonWidth) end
	if self.optionsFrame.heightSlider then self.optionsFrame.heightSlider:SetValue(selectedLayout and selectedLayout.height or self.buttonHeight) end
	if self.optionsFrame.powerHeightSlider then self.optionsFrame.powerHeightSlider:SetValue(selectedLayout and selectedLayout.powerBarHeight or self.powerBarHeight) end
	if selectedLayout then
		if self.optionsFrame.spacingXSlider then self.optionsFrame.spacingXSlider:SetValue(selectedLayout.spacingX or self.horizontalGap) end
		if self.optionsFrame.spacingYSlider then self.optionsFrame.spacingYSlider:SetValue(selectedLayout.spacingY or self.verticalGap) end
	end
	self.syncingLayoutControls = nil
	if self.optionsFrame.UpdateResponsiveLayout then self.optionsFrame:UpdateResponsiveLayout() end
	if self.optionsFrame.presetButton then self.optionsFrame.presetButton:SetText("Appearance preset: " .. (self.appearancePreset or "Custom")) end
	if self.optionsFrame.autoGroupLayoutsCheckbox then self.optionsFrame.autoGroupLayoutsCheckbox:SetChecked(self.autoGroupLayouts) end
	if self.optionsFrame.groupLayoutButton then
		if self.optionsFrame.groupLayoutButton.RefreshChoiceLabel then self.optionsFrame.groupLayoutButton:RefreshChoiceLabel()
		else self.optionsFrame.groupLayoutButton:SetText("Layout: " .. (self.groupLayoutLabels[self.selectedGroupLayout] or "Default")) end
	end
	for _,dropdown in ipairs(self.optionsFrame.autoLayoutDropdowns or {}) do dropdown:RefreshChoiceLabel() end
	if self.optionsFrame.layoutAutoSwitchFrame and self.optionsFrame.layoutAutoSwitchFrame.currentProfile then
		local active=self.activeGroupLayout or self.selectedGroupLayout
		self.optionsFrame.layoutAutoSwitchFrame.currentProfile:SetText("Current profile: "..(active=="hide" and "Hidden" or (self.groupLayoutLabels[active] or active or "Default")))
	end
	local selectedProfile = self.groupLayoutProfiles[self.selectedGroupLayout]
	if self.optionsFrame.renameLayoutButton then if self.selectedGroupLayout == "Default" then self.optionsFrame.renameLayoutButton:Disable() else self.optionsFrame.renameLayoutButton:Enable() end end
	if self.optionsFrame.deleteLayoutButton then if self.selectedGroupLayout == "Default" then self.optionsFrame.deleteLayoutButton:Disable() else self.optionsFrame.deleteLayoutButton:Enable() end end
	if self.optionsFrame.groupsPerLineButton and selectedProfile then
		self.optionsFrame.groupsPerLineButton:SetText("Groups per row / column: " .. selectedProfile.groupsPerLine)
	end
	if self.optionsFrame.directionButton and selectedProfile then self.optionsFrame.directionButton:SetText("Direction: " .. (directionLabels[selectedProfile.direction] or directionLabels["down-right"])) end
	if self.optionsFrame.groupFilterChecks and selectedProfile then
		for group = 1, 8 do self.optionsFrame.groupFilterChecks[group]:SetChecked(selectedProfile.groupFilter[group] ~= false) end
	end
	if self.optionsFrame.layoutPreviewButton then self.optionsFrame.layoutPreviewButton:SetText("Preview: " .. (self.layoutPreviewMode == "party" and "Party" or self.layoutPreviewMode == "raid" and "Raid" or "Off")) end
	if selectedProfile then
		if self.optionsFrame.healthBarDirectionDropdown then self.optionsFrame.healthBarDirectionDropdown:RefreshChoiceLabel() end
		if self.optionsFrame.powerBarDirectionDropdown then self.optionsFrame.powerBarDirectionDropdown:RefreshChoiceLabel() end
		if self.optionsFrame.powerBarSideDropdown then self.optionsFrame.powerBarSideDropdown:RefreshChoiceLabel(); if selectedProfile.powerBarOrientation == "VERTICAL" then self.optionsFrame.powerBarSideDropdown:Show() else self.optionsFrame.powerBarSideDropdown:Hide() end end
	end
	local function RefreshSwatch(button, color)
		if button and button.colorTexture and color then button.colorTexture:SetTexture(color[1], color[2], color[3], 1) end
	end
	RefreshSwatch(self.optionsFrame.healthBarColorSwatch, self.customHealthColor)
	RefreshSwatch(self.optionsFrame.healthLossColorSwatch, self.healthLossCustomColor)
	RefreshSwatch(self.optionsFrame.powerColorSwatch, self.powerBarCustomColor)
	RefreshSwatch(self.optionsFrame.targetHighlightSwatch, self.targetHighlightColor)
	RefreshSwatch(self.optionsFrame.mouseoverHighlightSwatch, self.mouseoverHighlightColor)
	RefreshSwatch(self.optionsFrame.healPredictionSwatch, self.healPredictionColor)
	for _, key in ipairs({"healthBarColorSwatchModeButton", "healthLossColorSwatchModeButton", "powerColorSwatchModeButton"}) do
		if self.optionsFrame[key] then self.optionsFrame[key]:RefreshChoiceLabel() end
	end
	if self.optionsFrame.deadBackdropSwatch then
		self.optionsFrame.deadBackdropSwatch:SetTexture(self.customDeadBackdrop[1], self.customDeadBackdrop[2], self.customDeadBackdrop[3])
	end
	if self.optionsFrame.healthCustomColorSwatch then
		self.optionsFrame.healthCustomColorSwatch:SetTexture(self.healthTextCustomColor[1], self.healthTextCustomColor[2], self.healthTextCustomColor[3])
	end
	if self.optionsFrame.powerCustomColorSwatch then
		self.optionsFrame.powerCustomColorSwatch:SetTexture(self.powerTextCustomColor[1], self.powerTextCustomColor[2], self.powerTextCustomColor[3])
	end
	local function SetOptionShown(widget, shown)
		if not widget then return end
		if shown then widget:Show() else widget:Hide() end
	end
	SetOptionShown(self.optionsFrame.healthBarColorSwatch, self.healthColorMode == "custom")
	SetOptionShown(self.optionsFrame.healthLossColorSwatch, self.healthLossColorMode == "custom")
	SetOptionShown(self.optionsFrame.powerColorSwatch, self.powerColorMode == "custom")
	SetOptionShown(self.optionsFrame.healthBarColorSwatchTexture, self.healthColorMode == "custom")
	SetOptionShown(self.optionsFrame.healthLossColorSwatchTexture, self.healthLossColorMode == "custom")
	SetOptionShown(self.optionsFrame.powerColorSwatchTexture, self.powerColorMode == "custom")
	SetOptionShown(self.optionsFrame.nameCustomColorButton, self.nameColorMode == "custom")
	SetOptionShown(self.optionsFrame.nameColorSwatch, self.nameColorMode == "custom")
	SetOptionShown(self.optionsFrame.healthCustomColorButton, self.healthTextColorMode == "custom")
	SetOptionShown(self.optionsFrame.healthCustomColorSwatch, self.healthTextColorMode == "custom")
	SetOptionShown(self.optionsFrame.powerCustomColorButton, self.powerTextColorMode == "custom")
	SetOptionShown(self.optionsFrame.powerCustomColorSwatch, self.powerTextColorMode == "custom")
	if self.optionsFrame.unitTextureButton then self.optionsFrame.unitTextureButton:RefreshChoiceLabel() end
	if self.optionsFrame.barAnimationButton then self.optionsFrame.barAnimationButton:RefreshChoiceLabel() end
	if self.optionsFrame.uiAccentModeDropdown then
		self.optionsFrame.uiAccentModeDropdown:RefreshChoiceLabel()
		local swatch=self.optionsFrame.uiAccentColorSwatch
		if swatch then swatch:SetTexture(self.uiAccentCustomColor[1],self.uiAccentCustomColor[2],self.uiAccentCustomColor[3]) end
		if self.uiAccentColorMode=="custom" then self.optionsFrame.uiAccentColorButton:Show() else self.optionsFrame.uiAccentColorButton:Hide() end
	end
	self.syncingAppearanceControls = true
	for _, key in ipairs({"optionsScaleSlider", "healthAlphaSlider", "healthLossAlphaSlider", "powerAlphaSlider", "backgroundAlphaSlider", "outOfRangeAlphaSlider"}) do
		local slider = self.optionsFrame[key]
		if slider then
			local valueKey = ({optionsScaleSlider = "optionsScale", healthAlphaSlider = "healthColorAlpha", healthLossAlphaSlider = "healthLossAlpha", powerAlphaSlider = "powerColorAlpha", backgroundAlphaSlider = "backgroundAlpha", outOfRangeAlphaSlider = "outOfRangeAlpha"})[key]
			slider:SetValue(self[valueKey])
		end
	end
	self.syncingAppearanceControls = nil
	SetOptionShown(self.optionsFrame.debuffBorderSizeButton, self.debuffBorderEnabled)
	SetOptionShown(self.optionsFrame.debuffFillAmountButton, self.debuffFillMode == "gradient")
	SetOptionShown(self.optionsFrame.debuffDirectionButton, self.debuffFillMode == "gradient")
	if self.optionsFrame.nameFontButton then
		self.optionsFrame.nameFontButton:RefreshChoiceLabel()
		self.optionsFrame.nameSizeButton:RefreshChoiceLabel()
		self.optionsFrame.nameOutlineButton:SetText("Outline: " .. nameOutlines[self.nameFontOutline].name)
		self.optionsFrame.nameColorButton:SetText("Name color: " .. self.nameColorMode)
		self.optionsFrame.nameColorSwatch:SetTexture(self.nameCustomColor[1], self.nameCustomColor[2], self.nameCustomColor[3])
		self.optionsFrame.healthValuesCheckbox:SetChecked(self.showHealthValues)
		self.optionsFrame.healthFormatButton:SetText("Health: " .. (self.healthValueFormat == "percent" and "percent" or "current/max"))
		self.optionsFrame.healthFontButton:RefreshChoiceLabel()
		self.optionsFrame.healthSizeButton:RefreshChoiceLabel()
		self.optionsFrame.healthOutlineButton:SetText("Outline: " .. nameOutlines[self.healthTextFontOutline].name)
		local healthTextColorName = self.healthTextColorMode == "value" and "health-by-value" or self.healthTextColorMode
		self.optionsFrame.healthValueColorButton:SetText("Color: " .. healthTextColorName)
		self.optionsFrame.healthAnchorButton:RefreshChoiceLabel()
		self.optionsFrame.powerValuesCheckbox:SetChecked(self.showPowerValues)
		self.optionsFrame.powerFormatButton:SetText("Power: " .. (self.powerValueFormat == "percent" and "percent" or "current/max"))
		self.optionsFrame.powerFontButton:RefreshChoiceLabel()
		self.optionsFrame.powerSizeButton:RefreshChoiceLabel()
		self.optionsFrame.powerOutlineButton:SetText("Outline: " .. nameOutlines[self.powerTextFontOutline].name)
		local powerColorName = self.powerTextColorMode == "power" and "Power color" or (self.powerTextColorMode == "class" and "Class color" or "Custom color")
		self.optionsFrame.powerColorButton:SetText("Power text: " .. powerColorName)
		self.optionsFrame.powerAnchorButton:RefreshChoiceLabel()
	end
end

local function GetTextFontAndOutline(fontIndex, outlineIndex, fallbackFontIndex, fallbackOutlineIndex)
	fontIndex = tonumber(fontIndex) or tonumber(fallbackFontIndex) or 1
	outlineIndex = tonumber(outlineIndex) or tonumber(fallbackOutlineIndex) or 2
	local font = nameFonts[fontIndex] or nameFonts[1]
	local outline = nameOutlines[outlineIndex] or nameOutlines[2]
	return font, outline
end

function Cell:ApplyTextSettings()
	local nameSettings, healthSettings, powerSettings = GetDisplayedIndicatorSettings("nameText"), GetDisplayedIndicatorSettings("healthText"), GetDisplayedIndicatorSettings("powerText")
	local statusSettings = GetDisplayedIndicatorSettings("statusText")
	local nameFontSize = nameSettings and nameSettings.size or GetDisplayedFontSize("nameFontSize", self.nameFontSize)
	local healthTextFontSize = healthSettings and healthSettings.size or GetDisplayedFontSize("healthTextFontSize", self.healthTextFontSize)
	local powerTextFontSize = powerSettings and powerSettings.size or GetDisplayedFontSize("powerTextFontSize", self.powerTextFontSize)
	for i = 1, table.getn(self.buttons) do
		local button = self.buttons[i]
		if button.name then
			local font, outline = GetTextFontAndOutline(nameSettings and nameSettings.font, nameSettings and nameSettings.outline, self.nameFontIndex, self.nameFontOutline)
			button.name:SetFont(font.path, nameFontSize, outline.flag)
			button.name:ClearAllPoints()
			local anchor = nameSettings and nameSettings.anchor or self.nameAnchor
			button.name:SetPoint(anchor, button.health, anchor, nameSettings and nameSettings.x or 2, nameSettings and nameSettings.y or -1)
			if nameSettings and nameSettings.enabled == false then button.name:Hide() else button.name:Show() end
		end
		if button.healthText then
			local font, outline = GetTextFontAndOutline(healthSettings and healthSettings.font, healthSettings and healthSettings.outline, self.healthTextFontIndex, self.healthTextFontOutline)
			button.healthText:SetFont(font.path, healthTextFontSize, outline.flag)
			button.healthText:ClearAllPoints()
			local anchor = healthSettings and healthSettings.anchor or self.healthTextAnchor
			button.healthText:SetPoint(anchor, button, anchor, healthSettings and healthSettings.x or 0, healthSettings and healthSettings.y or 0)
			if healthSettings and healthSettings.enabled == false then button.healthText:Hide() else button.healthText:Show() end
			button.healthText:SetJustifyH(string.find(anchor, "LEFT", 1, true) and "LEFT" or (string.find(anchor, "RIGHT", 1, true) and "RIGHT" or "CENTER"))
		end
		if button.powerText then
			local font, outline = GetTextFontAndOutline(powerSettings and powerSettings.font, powerSettings and powerSettings.outline, self.powerTextFontIndex, self.powerTextFontOutline)
			button.powerText:SetFont(font.path, powerTextFontSize, outline.flag)
			button.powerText:ClearAllPoints()
			local anchor = powerSettings and powerSettings.anchor or self.powerTextAnchor
			button.powerText:SetPoint(anchor, button, anchor, powerSettings and powerSettings.x or 0, powerSettings and powerSettings.y or 0)
			if powerSettings and powerSettings.enabled == false then button.powerText:Hide() else button.powerText:Show() end
			button.powerText:SetJustifyH(string.find(anchor, "LEFT", 1, true) and "LEFT" or (string.find(anchor, "RIGHT", 1, true) and "RIGHT" or "CENTER"))
		end
		if button.statusText then
			if statusSettings then
				local font, outline = GetTextFontAndOutline(statusSettings.font, statusSettings.outline, self.nameFontIndex, 2)
				button.statusText:SetFont(font.path, statusSettings.size or 12, outline.flag)
				button.statusText:ClearAllPoints()
				local anchor = statusSettings.anchor or "CENTER"
				button.statusText:SetPoint(anchor, button, anchor, statusSettings.x or 0, statusSettings.y or 0)
				if statusSettings.enabled == false then button.statusText:Hide() else button.statusText:Show() end
			end
		end
	end
	self:UpdateFrames()
end

function Cell:UpdateMoverControls()
	local hovered = self.isMovingFrames and true or false
	local container = self.container
	if not hovered and container and GetCursorPosition then
		local left, top = container:GetLeft(), container:GetTop()
		local cursorX, cursorY = GetCursorPosition()
		local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
		if left and top and scale and scale > 0 then
			cursorX, cursorY = cursorX / scale, cursorY / scale
			-- The handles sit above the upper-left edge; include that strip and
			-- the top edge of the first frame so moving onto a handle stays stable.
			hovered = cursorX >= left - 3 and cursorX <= left + 44
				and cursorY >= top - 22 and cursorY <= top + 18
		end
	end
	if self.optionsHandle then
		if hovered then self.optionsHandle:Show() else self.optionsHandle:Hide() end
	end
	if self.moveHandle then if hovered then self.moveHandle:Show() else self.moveHandle:Hide() end end
end

function Cell:SetFramesLocked(locked)
	self.framesLocked = locked and true or false
	NotCellVanillaDB = GetCellSettingsDB()
	NotCellVanillaDB.framesLocked = self.framesLocked
	NotCellVanillaDB.framesLockPreferenceVersion = 1
	SaveCellSettingsDB()
	self:UpdateMoverControls()
	self:RefreshOptionsMenu()
end

function Cell:CanShowUnitTooltips()
	if not self.tooltipsEnabled then return false end
	if self.tooltipsHideInCombat and ((InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))) then return false end
	return true
end

function Cell:HideUnitFrameTooltip()
	if self.activeUnitTooltipOwner and GameTooltip then GameTooltip:Hide() end
	self.activeUnitTooltipOwner = nil
end

function Cell:SetTooltipsEnabled(enabled)
	self.tooltipsEnabled = enabled and true or false
	local settings = GetCellSettingsDB(); settings.tooltipsEnabled = self.tooltipsEnabled; SaveCellSettingsDB()
	if not self:CanShowUnitTooltips() then self:HideUnitFrameTooltip() end
	self:RefreshOptionsMenu()
end

function Cell:SetTooltipsHideInCombat(enabled)
	self.tooltipsHideInCombat = enabled and true or false
	local settings = GetCellSettingsDB(); settings.tooltipsHideInCombat = self.tooltipsHideInCombat; SaveCellSettingsDB()
	if not self:CanShowUnitTooltips() then self:HideUnitFrameTooltip() end
	self:RefreshOptionsMenu()
end

local function AddSectionTitle(parent, text, x, y)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	RegisterAccentRefresher(function() label:SetTextColor(GetUIAccentColor()) end)
	return label
end

-- Shared accent divider for separating option sections across all main tabs.
-- Supplying width keeps a divider inside a column; otherwise it follows the
-- parent's right edge as responsive pages change width.
local function AddOptionsDivider(parent, y, x, width)
	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetTexture("Interface\\Buttons\\WHITE8X8")
	local r,g,b=GetUIAccentColor(); divider:SetVertexColor(r*.45,g*.36,b*.24,1)
	divider:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 10, y)
	if width then divider:SetWidth(width) else divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y) end
	divider:SetHeight(2)
	RegisterAccentRefresher(function() local r,g,b=GetUIAccentColor(); divider:SetVertexColor(r*.45,g*.36,b*.24,1) end)
	return divider
end

-- Shared styling for selection controls: dropdowns use a cool dark fill and a
-- right-side chevron so they are visually distinct from action buttons.
local function StyleOptionsDropdownButton(button)
	button.isCellDropdown = true
	button.cellBackground:SetVertexColor(.035, .055, .065, 1)
	button.cellLabel:ClearAllPoints()
	button.cellLabel:SetPoint("LEFT", button, "LEFT", 8, 0)
	button.cellLabel:SetPoint("RIGHT", button, "RIGHT", -22, 0)
	button.cellLabel:SetJustifyH("CENTER")
	button.cellLabel:SetTextColor(.82, .90, .92)
	local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	arrow:SetPoint("RIGHT", button, "RIGHT", -7, 0)
	arrow:SetText("v")
	arrow:SetTextColor(.45, .82, .90)
	button.dropdownArrow = arrow
	button:SetScript("OnEnter", function(self)
		self.cellBackground:SetVertexColor(.07, .12, .14, 1)
		self.cellLabel:SetTextColor(GetUIAccentColor())
		self.dropdownArrow:SetTextColor(GetUIAccentColor())
	end)
	button:SetScript("OnLeave", function(self)
		self.cellBackground:SetVertexColor(.035, .055, .065, 1)
		self.cellLabel:SetTextColor(.82, .90, .92)
		self.dropdownArrow:SetTextColor(.45, .82, .90)
	end)
	RegisterAccentRefresher(function()
		local r,g,b=GetUIAccentColor()
		for _,line in pairs(button.cellBorder) do line:SetVertexColor(r*.48,g*.78,b*.88,1) end
	end)
	return button
end

local function StyleOptionsDropdownMenu(menu)
	if menu.cellDropdownBorder then return menu end
	menu.cellDropdownBorder = {}
	for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
		local line=menu:CreateTexture(nil,"BORDER")
		line:SetTexture("Interface\\Buttons\\WHITE8X8")
		line:SetVertexColor(.18,.38,.43,1)
		if edge=="TOP" or edge=="BOTTOM" then line:SetPoint(edge,menu,edge,0,0); line:SetPoint("LEFT",menu,"LEFT",0,0); line:SetPoint("RIGHT",menu,"RIGHT",0,0); line:SetHeight(1)
		else line:SetPoint(edge,menu,edge,0,0); line:SetPoint("TOP",menu,"TOP",0,0); line:SetPoint("BOTTOM",menu,"BOTTOM",0,0); line:SetWidth(1) end
		menu.cellDropdownBorder[edge]=line
	end
	RegisterAccentRefresher(function()
		local r,g,b=GetUIAccentColor()
		for _,line in pairs(menu.cellDropdownBorder) do line:SetVertexColor(r*.48,g*.78,b*.88,1) end
	end)
	return menu
end

-- Popup rows use a flatter slate background so the list reads separately from
-- both the bordered dropdown control and the gold-accented action buttons.
local function StyleOptionsDropdownItem(button)
	button.cellDropdownListItem = true
	button.cellBackground:SetVertexColor(.065, .075, .085, 1)
	button.cellLabel:SetJustifyH("LEFT")
	button.cellLabel:ClearAllPoints()
	button.cellLabel:SetPoint("LEFT", button, "LEFT", 9, 0)
	button.cellLabel:SetPoint("RIGHT", button, "RIGHT", -5, 0)
	button:SetScript("OnEnter", function(self) self.cellBackground:SetVertexColor(.12, .17, .20, 1); self.cellLabel:SetTextColor(.85, .94, .97) end)
	button:SetScript("OnLeave", function(self) self.cellBackground:SetVertexColor(.065, .075, .085, 1); self.cellLabel:SetTextColor(.76, .82, .84) end)
	button.cellLabel:SetTextColor(.76, .82, .84)
	for _, line in pairs(button.cellBorder or {}) do line:SetVertexColor(.16, .22, .25, 1) end
	return button
end

local function AddChoiceDropdown(parent, width, x, y, getLabel, choices, onSelect)
	local button = StyleOptionsDropdownButton(AddOptionsButton(parent, "", x, y, width, nil))
	button.choiceOptions = {}
	-- Dropdowns can be opened from controls inside scroll children. Keep the
	-- popup outside that hierarchy so it is not clipped or covered by siblings.
	local menu = CreateFrame("Frame", nil, UIParent)
	menu:SetWidth(width)
	local menuContentHeight = table.getn(choices) * 22
	menu:SetHeight(math.min(menuContentHeight + 4, 320))
	menu:SetFrameStrata("TOOLTIP")
	menu:SetFrameLevel(math.max(parent:GetFrameLevel() + 100, 1000))
	menu:SetToplevel(true)
	StyleOptionsDropdownMenu(menu)
	local bg = menu:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(menu)
	bg:SetTexture(0.04, 0.04, 0.04, 0.98)
	local menuScroll = CreateFrame("ScrollFrame", nil, menu)
	menuScroll:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
	menuScroll:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)
	menuScroll:EnableMouseWheel(true)
	local menuContent = CreateFrame("Frame", nil, menuScroll)
	menuContent:SetWidth(math.max(1, width - 4)); menuContent:SetHeight(math.max(1, menuContentHeight))
	menuScroll:SetScrollChild(menuContent)
	local function ScrollOptionsMenu(self, delta)
		local maximum = math.max(0, menuContent:GetHeight() - self:GetHeight())
		menuScroll:SetVerticalScroll(math.max(0, math.min(maximum, (menuScroll:GetVerticalScroll() or 0) - delta * 44)))
	end
	menuScroll:SetScript("OnMouseWheel", ScrollOptionsMenu)
	menuContent:EnableMouseWheel(true); menuContent:SetScript("OnMouseWheel", ScrollOptionsMenu)
	menu:Hide()
	local function Dismiss()
		if Cell.activeOptionsDropdown == menu then
			Cell.activeOptionsDropdown = nil
			if Cell.optionsDropdownDismiss then Cell.optionsDropdownDismiss:Hide() end
		end
		menu:Hide()
	end
	for i = 1, table.getn(choices) do
		local choice = choices[i]
		local choiceValue = choice.value
		local option = StyleOptionsDropdownItem(AddOptionsButton(menuContent, choice.name, 0, -(i - 1) * 22, width - 4, nil))
		button.choiceOptions[#button.choiceOptions + 1] = option
		option:SetHeight(21)
		option:EnableMouseWheel(true); option:SetScript("OnMouseWheel", ScrollOptionsMenu)
		local previewType = choice.previewType
		local previewValue = choice.previewValue or choice.path or choice.value
		if not previewType then
			if choice.path then previewType = "font"
			elseif type(previewValue) == "string" and (string.match(string.lower(previewValue), "%.tga$") or string.match(string.lower(previewValue), "%.blp$")) then previewType = "texture" end
		end
		if previewType == "texture" then
			option.previewTexture = option:CreateTexture(nil, "ARTWORK")
			option.previewTexture:SetWidth(48); option.previewTexture:SetHeight(14); option.previewTexture:SetPoint("LEFT", option, "LEFT", 5, 0)
			option.previewTexture:SetTexture(previewValue)
			option.cellLabel:ClearAllPoints(); option.cellLabel:SetPoint("LEFT", option.previewTexture, "RIGHT", 6, 0); option.cellLabel:SetPoint("RIGHT", option, "RIGHT", -4, 0); option.cellLabel:SetJustifyH("LEFT")
		elseif previewType == "font" and choice.path then
			option.cellLabel:SetFont(choice.path, 14, "")
		end
		option:SetScript("OnClick", function()
			Dismiss()
			onSelect(choiceValue)
		end)
	end
	button:SetScript("OnClick", function()
		if menu:IsShown() then
			Dismiss()
		else
			Cell:ShowOptionsDropdown(menu)
			menuScroll:SetVerticalScroll(0)
			menu:ClearAllPoints()
			if button:GetBottom() and button:GetBottom() < menu:GetHeight() + 20 then
				menu:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 1)
			else
				menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -1)
			end
			menu:Show()
		end
	end)
	button.CloseDropdown = Dismiss
	menu:SetScript("OnHide", Dismiss)
	button.RefreshChoiceLabel = function() button:SetText(getLabel()) end
	button:RefreshChoiceLabel()
	return button
end

function Cell:ShowOptionsDropdown(menu)
	if self.activeOptionsDropdown and self.activeOptionsDropdown ~= menu then self.activeOptionsDropdown:Hide() end
	if menu and menu.SetScale then menu:SetScale((self.optionsFrame and self.optionsFrame.appliedOptionsScale) or (tonumber(self.optionsScale) or 100) / 100) end
	if not self.optionsDropdownDismiss then
		local catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("DIALOG")
		catcher:SetFrameLevel(500)
		catcher:EnableMouse(true)
		catcher:RegisterForClicks("AnyUp")
		catcher:SetScript("OnClick", function()
			local active = Cell.activeOptionsDropdown
			Cell.activeOptionsDropdown = nil
			catcher:Hide()
			if active then active:Hide() end
		end)
		catcher:Hide()
		self.optionsDropdownDismiss = catcher
	end
	menu:SetScript("OnHide", function()
		if Cell.activeOptionsDropdown == menu then
			Cell.activeOptionsDropdown = nil
			if Cell.optionsDropdownDismiss then Cell.optionsDropdownDismiss:Hide() end
		end
	end)
	self.activeOptionsDropdown = menu
	self.optionsDropdownDismiss:Show()
end

function Cell:ApplyAppearancePreset(preset, persist)
	local tapped
	if preset == "Dark Mode" then
		self.healthColorMode = "custom"
		self.customHealthColor = {0.12, 0.13, 0.14}
		tapped = {0.72, 0.72, 0.72}
		self.healthLossColorMode = "custom"
		self.healthLossCustomColor = {0.88, 0.88, 0.88}
		self.healthTextColorMode = "custom"
		self.healthTextCustomColor = {1, 1, 1}
	else
		preset = "Light Mode"
		self.healthColorMode = "class"
		tapped = {0.10, 0.10, 0.10}
		self.healthLossColorMode = "custom"
		self.healthLossCustomColor = {0.24, 0.055, 0.055}
		self.healthTextColorMode = "custom"
		self.healthTextCustomColor = {1, 1, 1}
	end
	self.appearancePreset = preset
	self.tappedColor = tapped
	self.nameColorMode = "class"
	self.powerTextColorMode = "power"
	self.nameFontOutline = 3
	self.healthTextFontOutline = 2
	self.powerTextFontOutline = 2
	if persist ~= false then
		NotCellVanillaDB = GetCellSettingsDB()
		NotCellVanillaDB.appearancePreset = preset
		NotCellVanillaDB.healthColorMode = self.healthColorMode
		NotCellVanillaDB.customHealthColor = self.customHealthColor
		NotCellVanillaDB.healthLossColorMode = self.healthLossColorMode
		NotCellVanillaDB.healthLossCustomColor = self.healthLossCustomColor
		NotCellVanillaDB.tappedColor = tapped
		NotCellVanillaDB.healthTextColorMode = self.healthTextColorMode
		NotCellVanillaDB.healthTextCustomColor = self.healthTextCustomColor
		NotCellVanillaDB.nameColorMode = self.nameColorMode
		NotCellVanillaDB.powerTextColorMode = self.powerTextColorMode
		NotCellVanillaDB.nameFontOutline = self.nameFontOutline
		NotCellVanillaDB.healthTextFontOutline = self.healthTextFontOutline
		NotCellVanillaDB.powerTextFontOutline = self.powerTextFontOutline
		SaveCellSettingsDB()
	end
	for i = 1, table.getn(self.buttons) do
		local button = self.buttons[i]
		if button.healthBackground then button.healthBackground:SetTexture(tapped[1], tapped[2], tapped[3], 1) end
	end
	self:ApplyTextSettings()
	self:ApplyAppearanceSettings()
	self:RefreshOptionsMenu()
end

function Cell:CreateOptionsMenu()
	if self.optionsFrame then return self.optionsFrame end
	local panel = CreateFrame("Frame", "NotCellOptionsFrame", UIParent)
	NotCellVanillaDB = GetCellSettingsDB()
	-- Match Cell's 3.3.5 options width (432px); tab height grows only as needed.
	local panelWidth = 432
	local panelHeight = 600
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	panelWidth = math.min(panelWidth, screenWidth)
	panelHeight = math.min(panelHeight, screenHeight)
	panel:SetWidth(panelWidth)
	panel:SetHeight(panelHeight)
	panel:SetClampedToScreen(true)
	if UISpecialFrames then
		local registered = false
		for i = 1, table.getn(UISpecialFrames) do
			if UISpecialFrames[i] == "NotCellOptionsFrame" then registered = true end
		end
		if not registered then table.insert(UISpecialFrames, "NotCellOptionsFrame") end
	end
	local autoSwitchFrame
	local function ApplyOptionsScale(requestedScale)
		local requested = math.max(0.60, math.min(1.40, tonumber(requestedScale) or 1))
		-- Respect the full slider range; the previous 88% screen-fit cap made
		-- values above 100% map to the same effective size on common resolutions.
		local appliedScale = requested
		panel:SetScale(appliedScale)
		if autoSwitchFrame then autoSwitchFrame:SetScale(appliedScale) end
		-- The indicator preview is a child of the Options frame and inherits its scale.
		panel.appliedOptionsScale = appliedScale
	end
	panel._cellApplyOptionsScale = ApplyOptionsScale
	ApplyOptionsScale((tonumber(self.optionsScale) or 100) / 100)
	local visualWidth, visualHeight = panelWidth * panel:GetScale(), panelHeight * panel:GetScale()
	local savedPosition = NotCellVanillaDB.optionsPosition
	if savedPosition and savedPosition.x and savedPosition.y then
		local left = math.max(0, math.min(savedPosition.x, screenWidth - visualWidth))
		local bottom = math.max(0, math.min(savedPosition.y, screenHeight - visualHeight))
		panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	panel:SetMovable(true)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(100)
	local function SavePanelGeometry()
		local left, bottom = panel:GetLeft(), panel:GetBottom()
		if left and bottom then
			local visualW = (panel:GetRight() or left + panelWidth * panel:GetScale()) - left
			local visualH = (panel:GetTop() or bottom + panelHeight * panel:GetScale()) - bottom
			left = math.max(0, math.min(left, UIParent:GetWidth() - visualW))
			bottom = math.max(0, math.min(bottom, UIParent:GetHeight() - visualH))
			NotCellVanillaDB = GetCellSettingsDB()
			NotCellVanillaDB.optionsPosition = {x = left, y = bottom}
			SaveCellSettingsDB()
		end
	end
	local panelMoveSave = CreateFrame("Frame")
	panelMoveSave:Hide()
	panelMoveSave:SetScript("OnUpdate",function(frame,elapsed)
		frame.remaining=(frame.remaining or 0)-elapsed
		if frame.remaining<=0 then frame:Hide(); frame.remaining=nil; SavePanelGeometry() end
	end)
	local function FinishPanelMove()
		panel:StopMovingOrSizing()
		SavePanelGeometry()
		panelMoveSave.remaining=0.05; panelMoveSave:Show()
	end
	-- Also allow dragging from empty window space. Use the actual mouse focus to
	-- leave buttons, sliders, edit boxes, and tab controls to their own handlers.
	panel:EnableMouse(true)
	panel:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local focus = GetMouseFocus and GetMouseFocus()
		local objectType = focus and focus.GetObjectType and focus:GetObjectType()
		if not focus or focus == self or objectType == "Frame" or objectType == "ScrollFrame" then
			self._cellBackgroundDragging = true
			self:StartMoving()
		end
	end)
	panel:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self._cellBackgroundDragging then
			self._cellBackgroundDragging = nil
			FinishPanelMove()
		end
	end)
	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(panel)
	background:SetTexture("Interface\\Buttons\\WHITE8X8")
	background:SetVertexColor(0.035, 0.035, 0.035, 0.96)
	for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
		local line = panel:CreateTexture(nil, "BORDER")
		line:SetTexture("Interface\\Buttons\\WHITE8X8")
		local r,g,b=GetUIAccentColor(); line:SetVertexColor(r*.45,g*.36,b*.24,1)
		if edge == "TOP" or edge == "BOTTOM" then
			line:SetPoint(edge, panel, edge, 0, 0); line:SetWidth(panelWidth); line:SetHeight(1)
		else
			-- Anchor both ends so legacy clients do not position a single-point
			-- vertical texture around the screen center and extend it past the panel.
			local inset = edge == "LEFT" and "LEFT" or "RIGHT"
			line:SetPoint("TOP" .. inset, panel, "TOP" .. inset, 0, 0)
			line:SetPoint("BOTTOM" .. inset, panel, "BOTTOM" .. inset, 0, 0)
			line:SetWidth(1)
		end
		panel.accentBorderLines = panel.accentBorderLines or {}
		panel.accentBorderLines[#panel.accentBorderLines + 1] = line
	end
	RegisterAccentRefresher(function() local r,g,b=GetUIAccentColor(); for _,line in ipairs(panel.accentBorderLines or {}) do line:SetVertexColor(r*.45,g*.36,b*.24,1) end end)
	-- Limit dragging to the full-width title bar. A full-window drag region
	-- covers the page tabs on this client and steals their clicks.
	local dragHandle = CreateFrame("Button", nil, panel)
	dragHandle:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	dragHandle:SetWidth(panelWidth)
	dragHandle:SetHeight(32)
	dragHandle:EnableMouse(true)
	dragHandle:RegisterForDrag("LeftButton")
	dragHandle:SetScript("OnDragStart", function() panel:StartMoving() end)
	dragHandle:SetScript("OnDragStop", FinishPanelMove)
	local title = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", dragHandle, "LEFT", 14, 0)
	title:SetText("NotCell")
	title:SetTextColor(GetUIAccentColor())
	RegisterAccentRefresher(function() title:SetTextColor(GetUIAccentColor()) end)
	-- Compact options scale control in the title bar; deliberately has no caption.
	local scaleSlider = CreateFrame("Slider", nil, panel)
	scaleSlider:SetFrameLevel(dragHandle:GetFrameLevel() + 2)
	scaleSlider:EnableMouse(true)
	scaleSlider:SetPoint("LEFT", title, "RIGHT", 12, 0)
	scaleSlider:SetWidth(112); scaleSlider:SetHeight(12)
	scaleSlider:SetMinMaxValues(60, 140); scaleSlider:SetValueStep(5); scaleSlider:SetOrientation("HORIZONTAL")
	local scaleTrack = scaleSlider:CreateTexture(nil, "BACKGROUND")
	scaleTrack:SetTexture("Interface\\Buttons\\WHITE8X8"); scaleTrack:SetPoint("LEFT", scaleSlider, "LEFT", 0, 0); scaleTrack:SetPoint("RIGHT", scaleSlider, "RIGHT", 0, 0); scaleTrack:SetHeight(8); scaleTrack:SetVertexColor(.10,.10,.10,1)
	scaleSlider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	local scaleThumb = scaleSlider:GetThumbTexture(); if scaleThumb then scaleThumb:SetWidth(12); scaleThumb:SetHeight(12); scaleThumb:SetVertexColor(GetUIAccentColor()) end
	local scaleValue = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	scaleValue:SetPoint("LEFT", scaleSlider, "RIGHT", 6, 0); scaleValue:SetWidth(46); scaleValue:SetJustifyH("LEFT"); scaleValue:SetTextColor(GetUIAccentColor())
	local function SaveOptionsScale(value, apply)
		value = math.floor((NormalizeOptionsScale(value) + 2.5) / 5) * 5
		Cell.optionsScale = value; scaleValue:SetText(tostring(value) .. "%")
		local settings = GetCellSettingsDB(); settings.optionsScale = value; SaveCellSettingsDB()
		if apply then ApplyOptionsScale(value / 100) end
	end
	scaleSlider:SetValue(Cell.optionsScale or 100); SaveOptionsScale(Cell.optionsScale or 100, false)
	scaleSlider:SetScript("OnValueChanged", function(_, value)
		if Cell.syncingAppearanceControls then scaleValue:SetText(tostring(math.floor(value + 0.5)) .. "%"); return end
		-- Do not rescale the slider's parent while the pointer is dragging it:
		-- moving the control under the cursor makes old clients snap to min/max.
		SaveOptionsScale(value, false)
	end)
	scaleSlider:SetScript("OnMouseDown", function() Cell.optionsScaleDragging = true end)
	scaleSlider:SetScript("OnMouseUp", function(self)
		Cell.optionsScaleDragging = nil
		SaveOptionsScale(self:GetValue(), true)
	end)
	panel.optionsScaleSlider = scaleSlider
	RegisterAccentRefresher(function() local r,g,b=GetUIAccentColor(); if scaleThumb then scaleThumb:SetVertexColor(r,g,b,1) end; scaleValue:SetTextColor(r,g,b) end)
	local close = AddOptionsButton(panel, "X", 0, -12, 20, function() panel:Hide() end)
	close:SetFrameLevel(dragHandle:GetFrameLevel() + 2)
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -8)

	panel.tabs = {}
	panel.pages = {}
	local function CreatePage(id)
		local page = CreateFrame("Frame", nil, panel)
		page:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -140)
		page:SetWidth(431)
		page:SetHeight(570)
		page:Hide()
		panel.pages[id] = page
		return page
	end
	local generalSettingsPage = CreatePage("generalSettings")
	local appearancePage = CreatePage("appearance")
	local indicatorsPage = CreatePage("indicators")
	local sizePage = CreatePage("size")
	local clicksPage = CreatePage("clicks")
	local statusPage = CreatePage("status")
	local aboutPage = CreatePage("about")
	panel.closeButton = close
	panel.tabs = {}
	panel.subTabs = {}
	local mainTabOrder = {"general", "appearance", "layouts", "about", "clickCastings", "indicators"}
	local mainTabLabels = {
		general = "General", appearance = "Appearance", layouts = "Layouts", about = "About",
		clickCastings = "Click-Castings", indicators = "Indicators",
	}
	local mainTabPages = {
		general = "generalSettings", appearance = "appearance", layouts = "size", about = "about",
		clickCastings = "clicks", indicators = "indicators",
	}
	-- One sizing contract for every tab: page builders report the deepest visible
	-- control's bottom from the page top. The window adds the fixed 112px title/tab
	-- chrome and the same 16px content inset for every current and future page.
	local optionsChromeHeight, optionsContentPadding = 112, 16
	local optionsMinimumHeight = 420
	panel.pageContentExtents = {}
	local function SelectMainTab(id, subPage)
		panel.activeMainTab = id
		if id == "about" and panel.RefreshAboutTip then panel.RefreshAboutTip() end
		local activePage = subPage or panel.activeSubPages[id] or mainTabPages[id]
		local extent = panel.pageContentExtents[activePage]
		local requestedHeight = extent and math.max(optionsMinimumHeight, optionsChromeHeight + extent + optionsContentPadding) or optionsMinimumHeight
		panelHeight = math.min(requestedHeight, screenHeight)
		panel:SetHeight(panelHeight)
		ApplyOptionsScale((tonumber(Cell.optionsScale) or 100) / 100)
		if subPage then panel.activeSubPages[id] = subPage end
		for pageID, page in pairs(panel.pages) do
			if pageID == activePage then page:Show() else page:Hide() end
		end
		for tabID, tab in pairs(panel.tabs) do
			tab:SetSelected(tabID == id)
		end
		for groupID, tabGroup in pairs(panel.subTabs) do
			for tabID, tab in pairs(tabGroup) do
				if id == groupID then tab:Show() else tab:Hide() end
				tab:SetSelected(tabID == activePage)
			end
		end
		if panel.indicatorPreviewFrame then
			-- Keep the preview visible on every Options tab. It is parented to
			-- the Options panel, so hiding the panel still hides the preview.
			panel.indicatorPreviewFrame:Show()
			if id == "indicators" and panel.OnIndicatorsOpened then
				panel.OnIndicatorsOpened()
			end
		end
		if panel.layoutAutoSwitchFrame then
			if id=="layouts" and panel:IsShown() then panel.layoutAutoSwitchFrame:Show() else panel.layoutAutoSwitchFrame:Hide() end
		end
	end
	panel.SelectMainTab = SelectMainTab
	panel.activeSubPages = {}
	function panel:SetPageContentExtent(pageID, bottomExtent)
		bottomExtent = math.max(0, tonumber(bottomExtent) or 0)
		if self.pageContentExtents[pageID] == bottomExtent then return end
		self.pageContentExtents[pageID] = bottomExtent
		local activePage = self.activeSubPages[self.activeMainTab] or mainTabPages[self.activeMainTab]
		if self.activeMainTab and activePage == pageID then
			local targetHeight = math.min(math.max(optionsMinimumHeight, optionsChromeHeight + bottomExtent + optionsContentPadding), screenHeight)
			if math.abs(panelHeight - targetHeight) > 0.5 then
				panelHeight = targetHeight
				self:SetHeight(panelHeight)
				ApplyOptionsScale((tonumber(Cell.optionsScale) or 100) / 100)
			end
		end
	end
	local setPageContentExtent = function(pageID, bottomExtent) panel:SetPageContentExtent(pageID, bottomExtent) end
	for _, id in ipairs(mainTabOrder) do
		local tabID = id
		panel.tabs[tabID] = AddCategoryButton(panel, mainTabLabels[tabID], 0, 0, 100, function() SelectMainTab(tabID) end)
	end
	local categoryDivider = panel:CreateTexture(nil, "ARTWORK")
	categoryDivider:SetTexture("Interface\\Buttons\\WHITE8X8")
	local dividerR,dividerG,dividerB=GetUIAccentColor(); categoryDivider:SetVertexColor(dividerR*.45,dividerG*.36,dividerB*.24,1)
	RegisterAccentRefresher(function() local r,g,b=GetUIAccentColor(); categoryDivider:SetVertexColor(r*.45,g*.36,b*.24,1) end)
	categoryDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -92)
	categoryDivider:SetWidth(panelWidth - 24); categoryDivider:SetHeight(2)
	local orderedTabs = {}
	for _, id in ipairs(mainTabOrder) do orderedTabs[#orderedTabs + 1] = panel.tabs[id] end
	function panel:UpdateResponsiveLayout()
		local availableWidth = math.max(1, self:GetWidth() - 24)
		local tabGap = 2
		for i = 1, table.getn(orderedTabs) do
			local tab = orderedTabs[i]
			local row = math.floor((i - 1) / 3)
			local columns = 3
			local column = (i - 1) % 3
			local tabWidth = (availableWidth - (columns - 1) * tabGap) / columns
			tab:ClearAllPoints()
			tab:SetWidth(tabWidth)
			tab:SetPoint("TOPLEFT", self, "TOPLEFT", 12 + column * (tabWidth + tabGap), -38 - row * 26)
		end
		local pageTop = -100
		local availableHeight = math.max(1, self:GetHeight() + pageTop - 12)
		for pageID, page in pairs(self.pages) do
			page:ClearAllPoints()
			page:SetPoint("TOPLEFT", self, "TOPLEFT", 12, pageTop)
			page:SetWidth(availableWidth); page:SetHeight(availableHeight); page:SetScale(1)
			if pageID == "generalSettings" and self.UpdateGeneralResponsiveWidth then self:UpdateGeneralResponsiveWidth() end
			if pageID == "appearance" and self.UpdateAppearanceResponsive then self:UpdateAppearanceResponsive() end
			if pageID == "indicators" and self.UpdateIndicatorResponsiveWidth then self:UpdateIndicatorResponsiveWidth() end
			if pageID == "size" and self.UpdateLayoutsResponsive then self:UpdateLayoutsResponsive() end
			if pageID == "clicks" and self.UpdateClickResponsive then self:UpdateClickResponsive() end
			if pageID == "status" and self.UpdateStatusResponsive then self:UpdateStatusResponsive() end
			if pageID == "about" and self.UpdateAboutResponsive then self:UpdateAboutResponsive(availableWidth) end
		end
	end
	panel:SetScript("OnSizeChanged", function(self) self:UpdateResponsiveLayout() end)
	panel:UpdateResponsiveLayout()
	panel:HookScript("OnShow", function()
		local activeTab = panel.activeMainTab or "general"
		SelectMainTab(activeTab, panel.activeSubPages[activeTab])
		Cell:RefreshOptionsMenu()
	end)

	local clickSlots = {
		{name = "Left click", value = "1"}, {name = "Right click", value = "2"}, {name = "Middle click", value = "3"},
		{name = "Mouse 4", value = "4"}, {name = "Mouse 5", value = "5"},
		{name = "Shift + left", value = "shift-1"}, {name = "Ctrl + left", value = "ctrl-1"}, {name = "Alt + left", value = "alt-1"},
		{name = "Shift + right", value = "shift-2"}, {name = "Ctrl + right", value = "ctrl-2"}, {name = "Alt + right", value = "alt-2"},
		{name = "Shift + middle", value = "shift-3"}, {name = "Ctrl + middle", value = "ctrl-3"}, {name = "Alt + middle", value = "alt-3"},
		{name = "Shift + Mouse 4", value = "shift-4"}, {name = "Ctrl + Mouse 4", value = "ctrl-4"}, {name = "Alt + Mouse 4", value = "alt-4"},
		{name = "Shift + Mouse 5", value = "shift-5"}, {name = "Ctrl + Mouse 5", value = "ctrl-5"}, {name = "Alt + Mouse 5", value = "alt-5"},
	}
	local selectedClickSlot = "shift-1"
	local selectedClickSlotName = "Shift + left"
	local selectedSpellRank
	local selectedActionType = "spell"
	local bindingMode = false
	local bindingModeButton
	local bookGlow
	local InstallSpellbookBindingHooks
	local RefreshClickCastList
	local GetStoredCast
	local CaptureClickBinding
	local CaptureClickMouse
	local captureNextBind = false
	local captureCreatesBinding = false
	local capturingClickSlot
	local SaveClickCast
	local GetCurrentModifierPrefix
	local clickRows = {}
	local clickProfileButton = AddOptionsButton(clicksPage, "", 10, -10, 190, nil)
	local function GetClickProfileLabel()
		return "Profile: " .. (Cell.clickCastProfileNames[Cell.activeClickCastProfile] or Cell.activeClickCastProfile)
	end
	local clickProfileName = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clickProfileName:SetPoint("LEFT", clicksPage, "TOPLEFT", 210, -22)
	clickProfileName:SetWidth(197); clickProfileName:SetHeight(20)
	clickProfileName:SetJustifyH("LEFT")
	local clickNewProfileButton = AddOptionsButton(clicksPage, "New profile", 10, -40, 96, nil)
	local clickRenameProfileButton = AddOptionsButton(clicksPage, "Rename", 112, -40, 92, nil)
	local clickExportButton = AddOptionsButton(clicksPage, "Export", 210, -40, 90, nil)
	local clickImportButton = AddOptionsButton(clicksPage, "Import", 306, -40, 101, nil)
	local function UpdateClickProfileLabel()
		clickProfileButton:SetText(GetClickProfileLabel())
		clickProfileName:SetText("Current profile: " .. (Cell.clickCastProfileNames[Cell.activeClickCastProfile] or Cell.activeClickCastProfile))
	end
	clickProfileButton:SetScript("OnClick", function()
		if InCombatLockdown and InCombatLockdown() then DEFAULT_CHAT_FRAME:AddMessage("NotCell: click-cast profiles can only be changed out of combat"); return end
		local profiles = {}
		for profileID in pairs(Cell.clickCastProfiles) do profiles[#profiles + 1] = profileID end
		table.sort(profiles)
		local nextIndex = 1
		for i = 1, table.getn(profiles) do if profiles[i] == Cell.activeClickCastProfile then nextIndex = i % table.getn(profiles) + 1 end end
		Cell.activeClickCastProfile = profiles[nextIndex] or "common"
		Cell.clickCasts = Cell.clickCastProfiles[Cell.activeClickCastProfile] or {}
		Cell.clickCastProfiles[Cell.activeClickCastProfile] = Cell.clickCasts
		SaveClickCastSettings()
		UpdateClickProfileLabel()
		Cell:ApplyAllClickCastSettings()
		if RefreshClickCastList then RefreshClickCastList() end
	end)
	local transferFrame
	local transferEdit
	local function BuildClickProfileExport()
		local profileName = Cell.clickCastProfileNames[Cell.activeClickCastProfile] or Cell.activeClickCastProfile
		return Cell:ExportClickCastProfile(profileName, Cell.clickCasts)
	end
	local function ImportClickProfile()
		if InCombatLockdown and InCombatLockdown() then DEFAULT_CHAT_FRAME:AddMessage("NotCell: click-cast profiles can only be changed out of combat"); return end
		local imported, sourceName, importError = Cell:ImportClickCastProfile(transferEdit:GetText() or "")
		if not imported then DEFAULT_CHAT_FRAME:AddMessage("NotCell: " .. (importError or "Could not read click-cast profile JSON.")); return end
		local rowCount = 0; for _ in pairs(imported) do rowCount = rowCount + 1 end
		Cell.clickCasts = imported; Cell.clickCastProfiles[Cell.activeClickCastProfile] = imported
		SaveClickCastSettings(); Cell:ApplyAllClickCastSettings(); RefreshClickCastList(); transferFrame:Hide()
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: imported " .. rowCount .. " bindings from " .. sourceName .. " into " .. (Cell.clickCastProfileNames[Cell.activeClickCastProfile] or Cell.activeClickCastProfile) .. ".")
	end
	local function OpenTransferWindow(mode)
		if not transferFrame then
			transferFrame = CreateFrame("Frame", "NotCellClickCastTransferFrame", UIParent)
			transferFrame:SetWidth(600); transferFrame:SetHeight(460); transferFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			transferFrame:SetFrameStrata("DIALOG"); transferFrame:SetFrameLevel(200); transferFrame:SetMovable(true); transferFrame:SetClampedToScreen(true)
			transferFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 12, insets = {left = 4, right = 4, top = 4, bottom = 4}})
			transferFrame:SetBackdropColor(0.035, 0.035, 0.035, 0.98)
			local titleBar = CreateFrame("Button", nil, transferFrame)
			titleBar:SetPoint("TOPLEFT", transferFrame, "TOPLEFT", 8, -6); titleBar:SetWidth(540); titleBar:SetHeight(32); titleBar:RegisterForDrag("LeftButton")
			titleBar:SetScript("OnDragStart", function() transferFrame:StartMoving() end)
			titleBar:SetScript("OnDragStop", function() transferFrame:StopMovingOrSizing() end)
			transferFrame.title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			transferFrame.title:SetPoint("LEFT", titleBar, "LEFT", 8, 0); transferFrame.title:SetTextColor(GetUIAccentColor()); RegisterAccentRefresher(function() transferFrame.title:SetTextColor(GetUIAccentColor()) end)
			transferEdit = CreateFrame("EditBox", nil, transferFrame)
			transferEdit:SetPoint("TOPLEFT", transferFrame, "TOPLEFT", 16, -48); transferEdit:SetWidth(568); transferEdit:SetHeight(350)
			transferEdit:SetAutoFocus(false); transferEdit:SetMultiLine(true); transferEdit:SetFontObject(GameFontNormalSmall); transferEdit:SetTextInsets(8, 8, 8, 8)
			transferEdit:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
			transferEdit:SetBackdropColor(0.02, 0.02, 0.02, 1)
			transferFrame.closeButton = AddOptionsButton(transferFrame, "Close", 492, -414, 90, function() transferFrame:Hide() end)
			transferFrame.importButton = AddOptionsButton(transferFrame, "Import profile", 390, -414, 95, ImportClickProfile)
			if UISpecialFrames then table.insert(UISpecialFrames, "NotCellClickCastTransferFrame") end
		end
		transferFrame.title:SetText(mode == "export" and "Export click-casting profile" or "Import click-casting profile")
		if mode == "export" then
			transferEdit:SetText(BuildClickProfileExport()); transferEdit:SetFocus(); transferEdit:HighlightText()
			transferFrame.importButton:Hide()
		else
			transferEdit:SetText(""); transferEdit:SetFocus()
			transferFrame.importButton:Show()
		end
		transferFrame:Show()
	end
	clickExportButton:SetScript("OnClick", function() OpenTransferWindow("export") end)
	clickImportButton:SetScript("OnClick", function() OpenTransferWindow("import") end)
	local profileDialog
	local profileNameEdit
	local function OpenProfileDialog(mode)
		if not profileDialog then
			profileDialog = CreateFrame("Frame", "NotCellClickCastProfileDialog", UIParent)
			profileDialog:SetWidth(340); profileDialog:SetHeight(132); profileDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			profileDialog:SetFrameStrata("DIALOG"); profileDialog:SetFrameLevel(210); profileDialog:SetMovable(true); profileDialog:SetClampedToScreen(true)
			profileDialog:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 12, insets = {left = 4, right = 4, top = 4, bottom = 4}})
			profileDialog:SetBackdropColor(0.035, 0.035, 0.035, 0.98)
			profileDialog.title = profileDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			profileDialog.title:SetPoint("TOPLEFT", profileDialog, "TOPLEFT", 14, -14); profileDialog.title:SetTextColor(GetUIAccentColor()); RegisterAccentRefresher(function() profileDialog.title:SetTextColor(GetUIAccentColor()) end)
			profileNameEdit = CreateFrame("EditBox", nil, profileDialog)
			profileNameEdit:SetPoint("TOPLEFT", profileDialog, "TOPLEFT", 14, -42); profileNameEdit:SetWidth(312); profileNameEdit:SetHeight(24)
			profileNameEdit:SetAutoFocus(false); profileNameEdit:SetFontObject(GameFontNormalSmall); profileNameEdit:SetTextInsets(5, 5, 2, 2)
			profileNameEdit:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
			profileNameEdit:SetBackdropColor(0.02, 0.02, 0.02, 1)
			profileDialog.okButton = AddOptionsButton(profileDialog, "Save", 126, -86, 90, nil)
			profileDialog.cancelButton = AddOptionsButton(profileDialog, "Cancel", 222, -86, 90, function() profileDialog:Hide() end)
			if UISpecialFrames then table.insert(UISpecialFrames, "NotCellClickCastProfileDialog") end
		end
		profileDialog.title:SetText(mode == "new" and "Create click-casting profile" or "Rename click-casting profile")
		profileNameEdit:SetText(mode == "rename" and (Cell.clickCastProfileNames[Cell.activeClickCastProfile] or "") or "")
		profileDialog.okButton:SetScript("OnClick", function()
			local name = string.gsub(profileNameEdit:GetText() or "", "^%s*(.-)%s*$", "%1")
			if name == "" then return end
			if mode == "new" then
				local baseID = "custom-" .. string.gsub(string.lower(name), "[^%w]+", "-")
				local profileID, suffix = baseID, 2
				while Cell.clickCastProfiles[profileID] do profileID = baseID .. "-" .. suffix; suffix = suffix + 1 end
				Cell.clickCastProfiles[profileID] = {}; Cell.clickCastProfileNames[profileID] = name
				Cell.activeClickCastProfile = profileID; Cell.clickCasts = Cell.clickCastProfiles[profileID]
			else
				Cell.clickCastProfileNames[Cell.activeClickCastProfile] = name
			end
			SaveClickCastSettings(); UpdateClickProfileLabel(); Cell:ApplyAllClickCastSettings(); RefreshClickCastList(); profileDialog:Hide()
		end)
		profileDialog:Show(); profileNameEdit:SetFocus(); profileNameEdit:HighlightText()
	end
	clickNewProfileButton:SetScript("OnClick", function() OpenProfileDialog("new") end)
	clickRenameProfileButton:SetScript("OnClick", function() OpenProfileDialog("rename") end)
	UpdateClickProfileLabel()
	local clickKeyHeader = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clickKeyHeader:SetText("Keybind")
	local clickTypeHeader = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clickTypeHeader:SetText("Type")
	local clickActionHeader = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clickActionHeader:SetText("Action")
	local clickCastInstruction = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clickCastInstruction:SetPoint("TOP", clicksPage, "TOP", 0, -62)
	clickCastInstruction:SetWidth(407); clickCastInstruction:SetHeight(30); clickCastInstruction:SetJustifyH("CENTER")
	clickCastInstruction:SetText("Right Click on a bind to delete it.")
	local clickSpellEdit
	local selectedBindLabel
	local function DisplayBindName(slot)
		for i = 1, table.getn(clickSlots) do if clickSlots[i].value == slot then return clickSlots[i].name end end
		local key = string.match(slot or "", "^key%-(.+)$")
		if key then return "Key: " .. string.gsub(key, "%-", "+") end
		return slot or "Unassigned"
	end
	GetStoredCast = function(slot)
		local entry = (Cell.clickCasts or {})[slot]
		if type(entry) == "table" then return entry.text or "", entry.kind or "spell" end
		return entry or "", "spell"
	end
	local function LoadSelectedSpell()
		local stored, kind = GetStoredCast(selectedClickSlot)
		selectedActionType = kind
		local spell, rank
		if kind == "spell" then spell, rank = string.match(stored, "^(.-)%s*%(%s*Rank%s+(%d+)%s*%)$") end
		if spell then clickSpellEdit:SetText(spell); selectedSpellRank = "Rank " .. rank
		else clickSpellEdit:SetText(stored); selectedSpellRank = nil end
		clickSpellEdit:Hide()
		if selectedBindLabel then selectedBindLabel:SetText("Binding: " .. selectedClickSlotName) end
	end
	local clickList = CreateFrame("ScrollFrame", nil, clicksPage)
	clickList:SetPoint("TOP", clicksPage, "TOP", 0, -110)
	clickList:SetWidth(393); clickList:SetHeight(192)
	clickKeyHeader:SetPoint("BOTTOMLEFT", clickList, "TOPLEFT", 0, 7); clickKeyHeader:SetWidth(105); clickKeyHeader:SetJustifyH("CENTER")
	clickTypeHeader:SetPoint("BOTTOMLEFT", clickList, "TOPLEFT", 108, 7); clickTypeHeader:SetWidth(72); clickTypeHeader:SetJustifyH("CENTER")
	clickActionHeader:SetPoint("BOTTOMLEFT", clickList, "TOPLEFT", 183, 7); clickActionHeader:SetWidth(164); clickActionHeader:SetJustifyH("CENTER")
	local clickRankHeader = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clickRankHeader:SetPoint("BOTTOMLEFT", clickList, "TOPLEFT", 350, 7); clickRankHeader:SetWidth(55); clickRankHeader:SetJustifyH("CENTER"); clickRankHeader:SetText("Rank")
	local clickListChild = CreateFrame("Frame", nil, clickList)
	clickListChild:SetWidth(393); clickListChild:SetHeight(192)
	clickList:SetScrollChild(clickListChild)
	clickListChild:EnableMouseWheel(true)
	local clickListScroll = CreateFrame("Slider", nil, clicksPage)
	clickListScroll:SetOrientation("VERTICAL")
	clickListScroll:SetWidth(10); clickListScroll:SetHeight(192)
	clickListScroll:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	local clickScrollTrack = clickListScroll:CreateTexture(nil, "BACKGROUND")
	clickScrollTrack:SetTexture("Interface\\Buttons\\WHITE8X8")
	clickScrollTrack:SetAllPoints(clickListScroll); clickScrollTrack:SetVertexColor(0.08, 0.08, 0.08, 0.95)
	local clickScrollThumb = clickListScroll:GetThumbTexture()
	if clickScrollThumb then clickScrollThumb:SetWidth(8); clickScrollThumb:SetHeight(24); clickScrollThumb:SetVertexColor(0.62, 0.43, 0.24, 1) end
	local syncingClickScroll = false
	clickListScroll:SetScript("OnValueChanged", function(_, value)
		if not syncingClickScroll then clickList:SetVerticalScroll(value) end
	end)
	local function ScrollClickList(delta)
		local current = clickList:GetVerticalScroll() or 0
		local maximum = math.max(0, clickListChild:GetHeight() - clickList:GetHeight())
		local value = math.max(0, math.min(maximum, current - delta * 24))
		clickList:SetVerticalScroll(value)
		syncingClickScroll = true; clickListScroll:SetValue(value); syncingClickScroll = false
	end
	clickListChild:SetScript("OnMouseWheel", function(_, delta) ScrollClickList(delta) end)
	local clickPlusButton = AddOptionsButton(clicksPage, "+", 153, 0, 100, nil)
	clickPlusButton:SetHeight(28)
	bindingModeButton = CreateFrame("Button", nil, clicksPage)
	bindingModeButton:SetWidth(44); bindingModeButton:SetHeight(44)
	local bookIcon = bindingModeButton:CreateTexture(nil, "ARTWORK")
	bookIcon:SetAllPoints(bindingModeButton); bookIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	bookGlow = bindingModeButton:CreateTexture(nil, "OVERLAY")
	bookGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); bookGlow:SetBlendMode("ADD")
	bookGlow:SetWidth(68); bookGlow:SetHeight(68); bookGlow:SetPoint("CENTER", bindingModeButton, "CENTER", 0, 0); bookGlow:Hide()
	bindingModeButton:SetScript("OnUpdate", function(self)
		if bookGlow and bookGlow:IsShown() then bookGlow:SetAlpha(0.55 + 0.35 * math.sin((GetTime() or 0) * 5)) end
	end)
	bindingModeButton:SetScript("OnEnter", function()
		if not GameTooltip then return end
		GameTooltip:SetOwner(bindingModeButton, "ANCHOR_RIGHT")
		GameTooltip:SetText("Spellbook capture", 1, 0.82, 0)
		GameTooltip:AddLine("Click to open or close your spellbook. Hover over a spell and press a key to add a bind.", 1, 1, 1, true); GameTooltip:Show()
	end)
	bindingModeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	bindingModeButton:SetScript("OnClick", function()
		bindingMode = not bindingMode
		if bookGlow then if bindingMode then bookGlow:Show() else bookGlow:Hide() end end
		if InstallSpellbookBindingHooks then InstallSpellbookBindingHooks() end
		if bindingMode then
			if not (SpellBookFrame and SpellBookFrame.IsShown and SpellBookFrame:IsShown()) then
				if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL)
				elseif SpellBookFrame and ShowUIPanel then ShowUIPanel(SpellBookFrame) end
			end
		elseif SpellBookFrame and SpellBookFrame.IsShown and SpellBookFrame:IsShown() then
			if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL)
			elseif HideUIPanel then HideUIPanel(SpellBookFrame) else SpellBookFrame:Hide() end
		end
	end)
	local bindingModeHelp = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bindingModeHelp:SetPoint("TOP", bindingModeButton, "BOTTOM", 0, -6)
	bindingModeHelp:SetWidth(360); bindingModeHelp:SetHeight(36); bindingModeHelp:SetJustifyH("CENTER")
	bindingModeHelp:SetTextColor(GetUIAccentColor())
	RegisterAccentRefresher(function() bindingModeHelp:SetTextColor(GetUIAccentColor()) end)
	bindingModeHelp:SetText("Click to open or close your spellbook. Hover over a spell and press a key to add a bind.")
	clickList:EnableMouseWheel(true)
	clickList:SetScript("OnMouseWheel", function(self, delta)
		ScrollClickList(delta)
	end)
	local clickMenu = CreateFrame("Frame", nil, clicksPage)
	clickMenu:SetWidth(224); clickMenu:SetHeight(200); clickMenu:SetFrameStrata("TOOLTIP"); clickMenu:SetFrameLevel(clicksPage:GetFrameLevel() + 100); clickMenu:SetToplevel(true); clickMenu:Hide()
	clickMenu:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
	clickMenu:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
	local clickMenuScroll = CreateFrame("ScrollFrame", nil, clickMenu)
	clickMenuScroll:SetPoint("TOPLEFT", clickMenu, "TOPLEFT", 4, -4); clickMenuScroll:SetPoint("BOTTOMRIGHT", clickMenu, "BOTTOMRIGHT", -4, 4)
	local clickMenuChild = CreateFrame("Frame", nil, clickMenuScroll); clickMenuChild:SetWidth(212); clickMenuChild:SetHeight(1); clickMenuScroll:SetScrollChild(clickMenuChild)
	clickMenuScroll:EnableMouseWheel(true)
	clickMenuScroll:SetScript("OnMouseWheel", function(self, delta)
		local maximum = math.max(0, clickMenuChild:GetHeight() - clickMenu:GetHeight() + 8)
		self:SetVerticalScroll(math.max(0, math.min(maximum, (self:GetVerticalScroll() or 0) - delta * 22)))
	end)
	local clickMenuButtons = {}
	local function ShowClickMenu(anchor, options, onSelect)
		if not options or table.getn(options) == 0 then return end
		clickMenu:ClearAllPoints(); clickMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
		clickMenu:SetFrameLevel(math.max(clicksPage:GetFrameLevel() + 100, anchor:GetFrameLevel() + 40))
		clickMenu:SetHeight(math.min(200, table.getn(options) * 22 + 8)); clickMenuChild:SetHeight(table.getn(options) * 22)
		for i = 1, table.getn(options) do
			local button = clickMenuButtons[i]
			if not button then
				button = CreateFrame("Button", nil, clickMenuChild); button:SetWidth(212); button:SetHeight(22)
				button.icon = button:CreateTexture(nil, "ARTWORK")
				button.icon:SetWidth(16); button.icon:SetHeight(16); button.icon:SetPoint("LEFT", button, "LEFT", 4, 0); button.icon:Hide()
				button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				button.text:SetPoint("LEFT", button, "LEFT", 5, 0); button.text:SetPoint("RIGHT", button, "RIGHT", -5, 0); button.text:SetJustifyH("LEFT")
				button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")
				clickMenuButtons[i] = button
			end
			local item = options[i]
			button:ClearAllPoints(); button:SetPoint("TOPLEFT", clickMenuChild, "TOPLEFT", 0, -((i - 1) * 22))
			button.text:SetText(item.label)
			if item.icon then button.icon:SetTexture(item.icon); button.icon:Show(); button.text:ClearAllPoints(); button.text:SetPoint("LEFT", button.icon, "RIGHT", 5, 0); button.text:SetPoint("RIGHT", button, "RIGHT", -5, 0)
			else button.icon:Hide(); button.text:ClearAllPoints(); button.text:SetPoint("LEFT", button, "LEFT", 5, 0); button.text:SetPoint("RIGHT", button, "RIGHT", -5, 0) end
			button:SetScript("OnClick", function() clickMenu:Hide(); onSelect(item) end)
			button:Show()
		end
		for i = table.getn(options) + 1, table.getn(clickMenuButtons) do clickMenuButtons[i]:Hide() end
		clickMenuScroll:SetVerticalScroll(0); Cell:ShowOptionsDropdown(clickMenu); clickMenu:Show()
	end
	local function DeleteClickBinding(slot)
		if InCombatLockdown and InCombatLockdown() then DEFAULT_CHAT_FRAME:AddMessage("NotCell: click-cast bindings can only be changed out of combat"); return end
		clickMenu:Hide()
		if capturingClickSlot == slot then
			captureNextBind = false; captureCreatesBinding = false; capturingClickSlot = nil
			for _, existingRow in ipairs(clickRows) do if existingRow and existingRow.button then existingRow.button:EnableKeyboard(false) end end
		end
		Cell.clickCasts[slot] = nil
		if selectedClickSlot == slot then selectedClickSlot = "shift-1"; selectedClickSlotName = DisplayBindName(selectedClickSlot) end
		SaveClickCastSettings(); Cell:ApplyAllClickCastSettings(); RefreshClickCastList()
	end
	RefreshClickCastList = function()
		local slots = {}
		for slot in pairs(Cell.clickCasts or {}) do slots[table.getn(slots) + 1] = slot end
		table.sort(slots, function(a, b) return DisplayBindName(a) < DisplayBindName(b) end)
		for i = 1, math.max(table.getn(slots), table.getn(clickRows)) do
			local row = clickRows[i]
			if not row then
				row = CreateFrame("Frame", nil, clickListChild)
				row:SetWidth(407); row:SetHeight(22)
				row:EnableMouse(true)
				-- Right-click deletion belongs to the individual controls below. A row-level
				-- mouse-up handler also fires after a captured RightButton and would delete
				-- the bind that was just created.
				row.button = AddOptionsButton(row, "", 0, 0, 105, nil)
				row.button:SetHeight(22)
				row.button:RegisterForClicks("AnyUp", "Button4Up", "Button5Up")
				row.button:EnableMouseWheel(true)
				row.button:SetScript("OnMouseWheel", function(_, delta) ScrollClickList(delta) end)
				row.typeButton = AddOptionsButton(row, "", 108, 0, 72, nil)
				row.typeButton:SetHeight(22)
				row.typeButton:RegisterForClicks("AnyUp", "Button4Up", "Button5Up")
				row.typeButton:EnableMouseWheel(true)
				row.typeButton:SetScript("OnMouseWheel", function(_, delta) ScrollClickList(delta) end)
				row.valueButton = AddOptionsButton(row, "", 183, 0, 164, nil)
				row.valueButton:SetHeight(22)
				row.valueButton:RegisterForClicks("AnyUp", "Button4Up", "Button5Up")
				row.valueButton:EnableMouseWheel(true)
				row.valueButton:SetScript("OnMouseWheel", function(_, delta) ScrollClickList(delta) end)
				row.rankButton = AddOptionsButton(row, "-Rank", 350, 0, 55, nil)
				row.rankButton:SetHeight(22)
				row.rankButton:RegisterForClicks("AnyUp", "Button4Up", "Button5Up")
				row.valueIcon = row.valueButton:CreateTexture(nil, "OVERLAY")
				row.valueIcon:SetWidth(16); row.valueIcon:SetHeight(16)
				row.valueIcon:SetPoint("LEFT", row.valueButton, "LEFT", 4, 0)
				clickRows[i] = row
			end
			local slot = slots[i]
			if slot then
				row.clickSlot = slot
				local text, kind = GetStoredCast(slot)
				row:ClearAllPoints(); row:SetPoint("TOPLEFT", clickListChild, "TOPLEFT", 0, -(i - 1) * 24)
				local label = kind == "target" and "Target" or kind == "menu" and "Menu" or kind == "macro" and text or text
				local isDraft = string.match(slot, "^draft%-") ~= nil
				row.button:SetText(isDraft and "Set key" or DisplayBindName(slot))
				row.typeButton:SetText((kind == "target" or kind == "menu") and "General" or (kind == "macro" and "Macro" or "Spell"))
				row.valueButton:SetText(label ~= "" and label or "Choose action")
				row.button:SetScript("OnClick", function(self, mouseButton)
					if captureNextBind and capturingClickSlot == slot then
						selectedClickSlot = slot; selectedClickSlotName = DisplayBindName(slot)
						CaptureClickMouse(mouseButton)
					elseif mouseButton == "RightButton" then
						DeleteClickBinding(slot)
					else
						selectedClickSlot = slot; selectedClickSlotName = DisplayBindName(slot)
						LoadSelectedSpell()
						for j = 1, table.getn(clickRows) do
							if clickRows[j] then clickRows[j].button:EnableKeyboard(false) end
						end
						capturingClickSlot = slot; captureNextBind = true; captureCreatesBinding = false
						self:SetText("Press key")
						self:EnableKeyboard(true)
					end
				end)
				row.button:SetScript("OnKeyDown", function(self, key)
					if captureNextBind and capturingClickSlot == slot then
						if key == "ESCAPE" then
							captureNextBind = false; captureCreatesBinding = false; capturingClickSlot = nil
							for j = 1, table.getn(clickRows) do if clickRows[j] then clickRows[j].button:EnableKeyboard(false) end end
							panel:Hide()
						elseif CaptureClickBinding(key) then
							self:EnableKeyboard(false); RefreshClickCastList()
						end
					end
				end)
				row.typeButton:SetScript("OnClick", function(self, mouseButton)
					if mouseButton == "RightButton" then DeleteClickBinding(slot); return end
					local types = {{label = "Spell", value = "spell"}, {label = "Macro", value = "macro"}, {label = "General: Target", value = "target"}, {label = "General: Menu", value = "menu"}}
					ShowClickMenu(row.typeButton, types, function(choice)
						if InCombatLockdown and InCombatLockdown() then DEFAULT_CHAT_FRAME:AddMessage("NotCell: click-cast bindings can only be changed out of combat"); return end
						selectedClickSlot = slot; selectedClickSlotName = DisplayBindName(slot)
						local oldText, oldKind = GetStoredCast(slot)
						selectedActionType = choice.value
						if choice.value == "spell" then Cell.clickCasts[slot] = oldKind == "spell" and oldText or ""
						else Cell.clickCasts[slot] = {kind = choice.value, text = (choice.value == "macro" and oldKind == "macro") and oldText or ""} end
						SaveClickCastSettings(); Cell:ApplyAllClickCastSettings(); LoadSelectedSpell(); RefreshClickCastList()
					end)
				end)
				row.valueButton:SetScript("OnClick", function(self, mouseButton)
					if mouseButton == "RightButton" then DeleteClickBinding(slot); return end
					selectedClickSlot = slot; selectedClickSlotName = DisplayBindName(slot)
					local storedText, storedKind = GetStoredCast(slot)
					if storedKind == "target" or storedKind == "menu" then
						ShowClickMenu(row.valueButton, {{label = "Target", value = "target"}, {label = "Menu", value = "menu"}}, function(choice)
							Cell.clickCasts[slot] = {kind = choice.value, text = ""}; SaveClickCastSettings(); Cell:ApplyAllClickCastSettings(); RefreshClickCastList()
						end)
					elseif storedKind == "spell" then
						local learned = {}
						if GetNumSpellTabs and GetSpellTabInfo then
							for tab = 1, GetNumSpellTabs() do
								local _, _, offset, count = GetSpellTabInfo(tab)
								for spellSlot = (offset or 0) + 1, (offset or 0) + (count or 0) do
									local name, rank
									if GetSpellBookItemName then name, rank = GetSpellBookItemName(spellSlot, BOOKTYPE_SPELL)
									elseif GetSpellName then name, rank = GetSpellName(spellSlot, BOOKTYPE_SPELL) end
									local itemType
									if GetSpellBookItemInfo then itemType = GetSpellBookItemInfo(spellSlot, BOOKTYPE_SPELL) end
								local passive = IsPassiveSpell and IsPassiveSpell(spellSlot, BOOKTYPE_SPELL)
								local harmful = IsHarmfulSpell and IsHarmfulSpell(spellSlot, BOOKTYPE_SPELL)
								local normalized = string.lower(name or "")
									local excludedName = normalized == "attack" or normalized == "shoot" or normalized == "dodge" or normalized == "cultivation" or normalized == "nature resistance" or normalized == "endurance" or normalized == "war stomp" or normalized == "slow & steady" or normalized == "exhaustion"
									local utilityName = string.find(normalized, "dispel") or string.find(normalized, "decurse") or string.find(normalized, "purge") or string.find(normalized, "cleanse") or string.find(normalized, "cure") or string.find(normalized, "remove curse") or string.find(normalized, "remove lesser curse") or string.find(normalized, "abolish") or string.find(normalized, "detoxify")
									if name and name ~= "" and itemType ~= "FUTURESPELL" and not passive and (not harmful or utilityName) and not excludedName then
										local full = rank and rank ~= "" and (name .. "(" .. rank .. ")") or name
										local icon = GetSpellTexture and GetSpellTexture(spellSlot, BOOKTYPE_SPELL)
										learned[table.getn(learned) + 1] = {label = full, value = full, icon = icon}
									end
								end
							end
						end
						learned[table.getn(learned) + 1] = {label = "Enter spell name or ID...", value = "__manual__"}
						ShowClickMenu(row.valueButton, learned, function(choice)
							if choice.value == "__manual__" then
								LoadSelectedSpell(); clickSpellEdit:ClearAllPoints(); clickSpellEdit:SetPoint("TOPLEFT", row.valueButton, "TOPLEFT", 0, 0)
								clickSpellEdit:SetWidth(164); clickSpellEdit:SetHeight(22); clickSpellEdit:Show(); clickSpellEdit:SetFocus(); clickSpellEdit:HighlightText()
							else
								Cell.clickCasts[slot] = choice.value; SaveClickCastSettings(); Cell:ApplyAllClickCastSettings(); RefreshClickCastList()
							end
						end)
					else
						LoadSelectedSpell()
						clickSpellEdit:ClearAllPoints(); clickSpellEdit:SetPoint("TOPLEFT", row.valueButton, "TOPLEFT", 0, 0)
						clickSpellEdit:SetWidth(164); clickSpellEdit:SetHeight(22); clickSpellEdit:Show()
						clickSpellEdit:SetFocus(); clickSpellEdit:HighlightText()
					end
				end)
				local unrankedSpell = kind == "spell" and string.match(text, "^(.-)%s*%(%s*Rank%s+%d+%s*%)$")
				if unrankedSpell then
					row.rankButton:SetScript("OnClick", function(_, mouseButton)
						if mouseButton == "RightButton" then DeleteClickBinding(slot); return end
						Cell.clickCasts[slot] = unrankedSpell
						SaveClickCastSettings(); Cell:ApplyAllClickCastSettings(); RefreshClickCastList()
					end)
					row.rankButton:Show()
				else
					row.rankButton:Hide()
				end
				local spellName = kind == "spell" and string.match(text, "^(.-)%s*%(%s*Rank%s+%d+%s*%)$") or text
				if kind == "spell" and not spellName then spellName = text end
				local spellIcon
				if kind == "spell" and GetSpellInfo then local _, _, icon = GetSpellInfo(tonumber(spellName) or spellName); spellIcon = icon end
				if spellIcon then
					row.valueIcon:SetTexture(spellIcon); row.valueIcon:Show()
					row.valueButton.cellLabel:ClearAllPoints(); row.valueButton.cellLabel:SetPoint("LEFT", row.valueButton, "LEFT", 22, 0)
				else
					row.valueIcon:Hide()
					row.valueButton.cellLabel:ClearAllPoints(); row.valueButton.cellLabel:SetPoint("CENTER", row.valueButton, "CENTER", 0, 0)
				end
				local actionLabel = label ~= "" and label or "Choose action"
				local labelFont = row.valueButton.cellLabel
				labelFont:SetText(actionLabel)
				local availableWidth = spellIcon and 132 or 150
				local function TrimActionEnd(value)
					local index = string.len(value)
					while index > 0 do
						local byte = string.byte(value, index)
						if byte < 128 or byte >= 192 then return string.sub(value, 1, index - 1) end
						index = index - 1
					end
					return ""
				end
				while labelFont:GetStringWidth() > availableWidth and string.len(actionLabel) > 3 do
					actionLabel = TrimActionEnd(string.sub(actionLabel, 1, string.len(actionLabel) - 3)) .. "..."
					labelFont:SetText(actionLabel)
				end
				row:Show(); row.button:Show(); row.typeButton:Show(); row.valueButton:Show()
			else row:Hide() end
		end
		clickPlusButton:ClearAllPoints(); clickPlusButton:SetPoint("TOP", clickList, "BOTTOM", 0, -8)
		clickPlusButton:SetText("+")
		clickPlusButton:SetScript("OnClick", function(self, mouseButton)
			if InCombatLockdown and InCombatLockdown() then DEFAULT_CHAT_FRAME:AddMessage("NotCell: click-cast bindings can only be changed out of combat"); return end
			local index = 1; local draft = "draft-" .. index
			while Cell.clickCasts[draft] do index = index + 1; draft = "draft-" .. index end
			Cell.clickCasts[draft] = {kind = "spell", text = ""}
			selectedClickSlot = draft; selectedClickSlotName = "New binding"
			SaveClickCastSettings(); RefreshClickCastList()
			local scrollValue = math.max(0, clickListChild:GetHeight() - clickList:GetHeight())
			clickList:SetVerticalScroll(scrollValue)
			syncingClickScroll = true; clickListScroll:SetValue(scrollValue); syncingClickScroll = false
		end)
		clickPlusButton:SetScript("OnKeyDown", nil)
		bindingModeButton:ClearAllPoints(); bindingModeButton:SetPoint("TOP", clickPlusButton, "BOTTOM", 0, -12)
		clickListChild:SetHeight(math.max(190, table.getn(slots) * 24))
		if clickList.UpdateScrollChildRect then clickList:UpdateScrollChildRect() end
		local maxScroll = math.max(0, clickListChild:GetHeight() - clickList:GetHeight())
		if (clickList:GetVerticalScroll() or 0) > maxScroll then clickList:SetVerticalScroll(maxScroll) end
		-- Rows created after the initial responsive pass otherwise keep the
		-- 407px fallback widths until the options panel is rebuilt on /reload.
		if panel.UpdateClickResponsive then panel.UpdateClickResponsive() end
	end
	clickSpellEdit = CreateFrame("EditBox", nil, clicksPage)
	clickSpellEdit:SetWidth(390); clickSpellEdit:SetHeight(22)
	clickSpellEdit:SetAutoFocus(false); clickSpellEdit:SetFontObject(GameFontNormalSmall); clickSpellEdit:SetTextInsets(5, 5, 2, 2)
	clickSpellEdit:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
	clickSpellEdit:SetBackdropColor(0.05, 0.05, 0.05, 1)
	clickSpellEdit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and selectedSpellRank then selectedSpellRank = nil end
	end)
	LoadSelectedSpell()
	clickSpellEdit:Hide()
	GetCurrentModifierPrefix = function(uppercase)
		local prefix = ""
		if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. (uppercase and "ALT-" or "alt-") end
		if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. (uppercase and "CTRL-" or "ctrl-") end
		if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. (uppercase and "SHIFT-" or "shift-") end
		return prefix
	end
	CaptureClickBinding = function(key, preserveOld)
		if not key or key == "UNKNOWN" then return false end
		local modifiers = GetCurrentModifierPrefix(true)
		local normalized = string.upper(key)
		if normalized == "LSHIFT" or normalized == "RSHIFT" or normalized == "LCTRL" or normalized == "RCTRL" or normalized == "LALT" or normalized == "RALT" or normalized == "ESCAPE" then return false end
		if normalized == "-" then normalized = "DASH"
		elseif normalized == "\\" then normalized = "BACKSLASH"
		elseif normalized == '"' then normalized = "DOUBLEQUOTE" end
		local oldSlot = selectedClickSlot
		local newSlot = "key-" .. modifiers .. normalized
		if preserveOld then
			if string.match(oldSlot or "", "^draft%-") then Cell.clickCasts[oldSlot] = nil end
			Cell.clickCasts[newSlot] = Cell.clickCasts[newSlot] or {kind = "spell", text = ""}
			SaveClickCastSettings(); Cell:ApplyAllClickCastSettings()
		elseif captureCreatesBinding then
			Cell.clickCasts[newSlot] = Cell.clickCasts[newSlot] or {kind = "target", text = ""}
			captureCreatesBinding = false
			SaveClickCastSettings(); Cell:ApplyAllClickCastSettings()
		elseif Cell.clickCasts[oldSlot] and oldSlot ~= newSlot then
			Cell.clickCasts[newSlot] = Cell.clickCasts[oldSlot]
			Cell.clickCasts[oldSlot] = nil
			SaveClickCastSettings(); Cell:ApplyAllClickCastSettings()
		end
		selectedClickSlot = newSlot
		selectedClickSlotName = DisplayBindName(selectedClickSlot)
		captureNextBind = false
		capturingClickSlot = nil
		for i = 1, table.getn(clickRows) do if clickRows[i] then clickRows[i].button:EnableKeyboard(false) end end
		if RefreshClickCastList then RefreshClickCastList() end
		return true
	end
	local mouseButtonNumbers = {LeftButton = "1", RightButton = "2", MiddleButton = "3", Button4 = "4", Button5 = "5", MouseButton4 = "4", MouseButton5 = "5"}
	local function GetMouseButtonNumber(mouseButton)
		return mouseButtonNumbers[mouseButton]
	end
	CaptureClickMouse = function(mouseButton)
		if not captureNextBind or (InCombatLockdown and InCombatLockdown()) then return false end
		local mouse = GetMouseButtonNumber(mouseButton)
		if not mouse then return false end
		local newSlot = GetCurrentModifierPrefix(false) .. mouse
		local oldSlot = selectedClickSlot
		if captureCreatesBinding then
			Cell.clickCasts[newSlot] = Cell.clickCasts[newSlot] or {kind = "target", text = ""}
			captureCreatesBinding = false
		elseif Cell.clickCasts[oldSlot] and oldSlot ~= newSlot then
			Cell.clickCasts[newSlot] = Cell.clickCasts[oldSlot]; Cell.clickCasts[oldSlot] = nil
		end
		selectedClickSlot = newSlot; selectedClickSlotName = DisplayBindName(newSlot); captureNextBind = false
		capturingClickSlot = nil
		for i = 1, table.getn(clickRows) do if clickRows[i] then clickRows[i].button:EnableKeyboard(false) end end
		SaveClickCastSettings(); Cell:ApplyAllClickCastSettings()
		if RefreshClickCastList then RefreshClickCastList() end
		return true
	end
	selectedBindLabel = clicksPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	selectedBindLabel:SetPoint("TOPLEFT", clicksPage, "TOPLEFT", 10, -300)
	selectedBindLabel:SetWidth(407); selectedBindLabel:SetHeight(20); selectedBindLabel:Hide()
	SaveClickCast = function(clear)
		if InCombatLockdown and InCombatLockdown() then
			DEFAULT_CHAT_FRAME:AddMessage("NotCell: click-cast bindings can only be changed out of combat")
			return
		end
		if selectedActionType == "target" or selectedActionType == "menu" then clickSpellEdit:SetText("") end
		Cell.clickCasts = Cell.clickCasts or {}
		local spell = clear and "" or string.gsub(clickSpellEdit:GetText() or "", "^%s*(.-)%s*$", "%1")
		if clear then selectedSpellRank = nil end
		local baseSpell = spell
		if selectedActionType == "spell" and spell ~= "" and tonumber(spell) and GetSpellInfo then spell = GetSpellInfo(tonumber(spell)) or spell end
		if selectedActionType == "spell" and spell ~= "" and selectedSpellRank then spell = spell .. "(" .. selectedSpellRank .. ")" end
		if clear or ((selectedActionType == "spell" or selectedActionType == "macro") and spell == "") then Cell.clickCasts[selectedClickSlot] = nil
		elseif selectedActionType == "spell" then Cell.clickCasts[selectedClickSlot] = spell
		elseif selectedActionType == "macro" then Cell.clickCasts[selectedClickSlot] = {kind = "macro", text = spell}
		else Cell.clickCasts[selectedClickSlot] = {kind = selectedActionType, text = ""} end
		SaveClickCastSettings()
		Cell:ApplyAllClickCastSettings()
		clickSpellEdit:SetText(baseSpell)
		RefreshClickCastList()
	end
	clickSpellEdit:SetScript("OnEnterPressed", function() SaveClickCast(false); clickSpellEdit:ClearFocus(); clickSpellEdit:Hide() end)
	clickSpellEdit:SetScript("OnEscapePressed", function() LoadSelectedSpell(); clickSpellEdit:ClearFocus(); clickSpellEdit:Hide() end)
	selectedBindLabel:SetText("Binding: " .. selectedClickSlotName)
	RefreshClickCastList()
	panel.UpdateClickResponsive = function()
		local width=math.max(1,clicksPage:GetWidth()-20)
		local profileWidth=math.min(245,width*.32)
		clickProfileButton:ClearAllPoints(); clickProfileButton:SetPoint("TOPLEFT",clicksPage,"TOPLEFT",10,-10); clickProfileButton:SetWidth(profileWidth)
		clickProfileName:ClearAllPoints(); clickProfileName:SetPoint("LEFT",clickProfileButton,"RIGHT",10,0); clickProfileName:SetWidth(width-profileWidth-10)
		local buttonGap=6; local profileButtonWidth=(width-buttonGap*3)/4
		for i,button in ipairs({clickNewProfileButton,clickRenameProfileButton,clickExportButton,clickImportButton}) do
			button:ClearAllPoints(); button:SetPoint("TOPLEFT",clicksPage,"TOPLEFT",10+(i-1)*(profileButtonWidth+buttonGap),-40); button:SetWidth(profileButtonWidth)
		end
		clickCastInstruction:ClearAllPoints(); clickCastInstruction:SetPoint("TOP",clicksPage,"TOP",0,-62); clickCastInstruction:SetWidth(width); clickCastInstruction:SetHeight(30)
		local listHeight=192
		local listWidth=math.max(1,width-14)
		clickList:ClearAllPoints(); clickList:SetPoint("TOP",clicksPage,"TOP",-7,-110); clickList:SetWidth(listWidth); clickList:SetHeight(listHeight)
		clickListChild:SetWidth(listWidth)
		clickListScroll:ClearAllPoints(); clickListScroll:SetPoint("TOPLEFT",clickList,"TOPRIGHT",2,0); clickListScroll:SetHeight(listHeight)
		local keyWidth=math.max(90,math.floor(listWidth*.22)); local typeWidth=math.max(68,math.floor(listWidth*.18)); local rankWidth=54; local gap=3
		local keyX=0; local typeX=keyWidth+gap; local actionX=typeX+typeWidth+gap; local actionWidth=math.max(90,listWidth-actionX-rankWidth-gap); local rankX=actionX+actionWidth+gap
		clickKeyHeader:ClearAllPoints(); clickKeyHeader:SetPoint("BOTTOMLEFT",clickList,"TOPLEFT",keyX,7); clickKeyHeader:SetWidth(keyWidth)
		clickTypeHeader:ClearAllPoints(); clickTypeHeader:SetPoint("BOTTOMLEFT",clickList,"TOPLEFT",typeX,7); clickTypeHeader:SetWidth(typeWidth)
		clickActionHeader:ClearAllPoints(); clickActionHeader:SetPoint("BOTTOMLEFT",clickList,"TOPLEFT",actionX,7); clickActionHeader:SetWidth(actionWidth)
		clickRankHeader:ClearAllPoints(); clickRankHeader:SetPoint("BOTTOMLEFT",clickList,"TOPLEFT",rankX,7); clickRankHeader:SetWidth(rankWidth)
		for _,row in ipairs(clickRows) do
			row:SetWidth(listWidth)
			if row.button then row.button:ClearAllPoints(); row.button:SetPoint("TOPLEFT",row,"TOPLEFT",keyX,0); row.button:SetWidth(keyWidth) end
			if row.typeButton then row.typeButton:ClearAllPoints(); row.typeButton:SetPoint("TOPLEFT",row,"TOPLEFT",typeX,0); row.typeButton:SetWidth(typeWidth) end
			if row.valueButton then row.valueButton:ClearAllPoints(); row.valueButton:SetPoint("TOPLEFT",row,"TOPLEFT",actionX,0); row.valueButton:SetWidth(actionWidth) end
			if row.rankButton then row.rankButton:ClearAllPoints(); row.rankButton:SetPoint("TOPLEFT",row,"TOPLEFT",rankX,0); row.rankButton:SetWidth(rankWidth) end
		end
		local visibleRows=0; for _,row in ipairs(clickRows) do if row:IsShown() then visibleRows=visibleRows+1 end end
		local childHeight=math.max(listHeight,visibleRows*24)
		clickListChild:SetHeight(childHeight); if clickList.UpdateScrollChildRect then clickList:UpdateScrollChildRect() end
		local maximum=math.max(0,childHeight-listHeight)
		clickListScroll:SetMinMaxValues(0,maximum); clickListScroll:SetValueStep(24)
		local scrollValue=math.min(clickList:GetVerticalScroll() or 0,maximum)
		clickList:SetVerticalScroll(scrollValue)
		syncingClickScroll=true; clickListScroll:SetValue(scrollValue); syncingClickScroll=false
		if maximum>0 then clickListScroll:Show() else clickListScroll:Hide() end
		clickPlusButton:SetWidth(math.min(130,width))
		if clickSpellEdit and clickSpellEdit:IsShown() then clickSpellEdit:SetWidth(actionWidth) end
		panel:SetPageContentExtent("clicks", 436)
	end
	clicksPage:SetScript("OnSizeChanged",function() if panel.UpdateClickResponsive then panel.UpdateClickResponsive() end end)
	panel.UpdateClickResponsive()
	local function GetHoveredSpell(button)
		local slot = button and button.GetID and button:GetID()
		if slot and SpellBook_GetSpellID then slot = SpellBook_GetSpellID(slot) end
		if not slot or slot < 1 then return end
		local name, rank
		local bookType = SpellBookFrame and SpellBookFrame.bookType or BOOKTYPE_SPELL
		if GetSpellName then name, rank = GetSpellName(slot, bookType)
		elseif GetSpellBookItemName then name, rank = GetSpellBookItemName(slot, bookType) end
		if not name or name == "" then return end
		return rank and rank ~= "" and (name .. "(" .. rank .. ")") or name, name, rank
	end
	local function DisableSpellbookCapture()
		bindingMode = false
		captureNextBind = false; captureCreatesBinding = false; capturingClickSlot = nil
		if bookGlow then bookGlow:Hide() end
		for i = 1, table.getn(clickRows) do if clickRows[i] then clickRows[i].button:EnableKeyboard(false) end end
		if InstallSpellbookBindingHooks then InstallSpellbookBindingHooks() end
	end
	panel:SetScript("OnHide", function()
		captureNextBind = false; captureCreatesBinding = false; capturingClickSlot = nil
		for i = 1, table.getn(clickRows) do if clickRows[i] then clickRows[i].button:EnableKeyboard(false) end end
		if bindingMode then DisableSpellbookCapture() end
	end)
	local function SaveSpellbookBinding(button, key)
		if key == "ESCAPE" and bindingMode then DisableSpellbookCapture(); return end
		if not bindingMode or not GetHoveredSpell then return end
		if key == "MOUSE2" then return end
		if InCombatLockdown and InCombatLockdown() then DEFAULT_CHAT_FRAME:AddMessage("NotCell: click-cast bindings can only be changed out of combat"); return end
		local fullSpell, spellName, rank = GetHoveredSpell(button)
		if not fullSpell then return end
		local mouseNumber = string.match(key or "", "^MOUSE(%d)$")
		if mouseNumber then
			local mods = GetCurrentModifierPrefix(false)
			selectedClickSlot = mods .. mouseNumber; selectedClickSlotName = DisplayBindName(selectedClickSlot)
		else
			if not CaptureClickBinding(key, true) then return end
		end
		local slot = selectedClickSlot
		Cell.clickCasts = Cell.clickCasts or {}
		Cell.clickCasts[slot] = fullSpell
					SaveClickCastSettings()
		Cell:ApplyAllClickCastSettings()
		clickSpellEdit:SetText(spellName)
		selectedSpellRank = rank
		selectedActionType = "spell"
		selectedClickSlotName = mouseNumber and DisplayBindName(slot) or ("Key: " .. string.gsub(string.match(slot, "^key%-(.+)$") or "", "%-", "+"))
		selectedBindLabel:SetText("Binding: " .. selectedClickSlotName)
		RefreshClickCastList()
	end
	InstallSpellbookBindingHooks = function()
		if SpellBookFrame and SpellBookFrame.EnableKeyboard then SpellBookFrame:EnableKeyboard(bindingMode) end
		for index = 1, 12 do
			local spellButton = _G["SpellButton" .. index]
			if spellButton and not spellButton._cellVanillaBindingHooked and spellButton.HookScript then
				spellButton._cellVanillaBindingHooked = true
				local capture = CreateFrame("Button", nil, spellButton)
				capture:SetAllPoints(spellButton); capture:RegisterForClicks("AnyUp", "Button4Up", "Button5Up"); capture:Hide()
				capture:SetScript("OnClick", function(self, mouseButton)
					local mouseNumber = GetMouseButtonNumber(mouseButton)
					if mouseNumber == "4" or mouseNumber == "5" then SaveSpellbookBinding(self:GetParent(), "MOUSE" .. mouseNumber) end
				end)
				capture:SetScript("OnKeyDown", nil)
				capture:SetScript("OnEnter", function(self)
					self:EnableKeyboard(false)
					local parent = self:GetParent()
					local slot = parent:GetID()
					if slot and SpellBook_GetSpellID then slot = SpellBook_GetSpellID(slot) end
					if slot and GameTooltip and GameTooltip.SetSpellBookItem then
						GameTooltip:SetOwner(parent, "ANCHOR_RIGHT")
						GameTooltip:SetSpellBookItem(slot, SpellBookFrame and SpellBookFrame.bookType or BOOKTYPE_SPELL)
					end
				end)
				capture:SetScript("OnLeave", function(self)
					if GameTooltip then GameTooltip:Hide() end
					self:EnableKeyboard(false)
					self:Hide()
				end)
				spellButton._cellVanillaCapture = capture
				spellButton:HookScript("OnEnter", function(self)
					if self._cellVanillaCapture then if bindingMode then self._cellVanillaCapture:Show() else self._cellVanillaCapture:Hide() end; self._cellVanillaCapture:EnableKeyboard(false) end
					self:EnableKeyboard(bindingMode)
				end)
				spellButton:HookScript("OnKeyDown", function(self, key)
					if not bindingMode or not (self.IsMouseOver and self:IsMouseOver()) then return end
					if key == "ESCAPE" then DisableSpellbookCapture() else SaveSpellbookBinding(self, key) end
				end)
			end
			if spellButton and spellButton._cellVanillaCapture then
				local overSpell = bindingMode and spellButton.IsMouseOver and spellButton:IsMouseOver()
				if overSpell then spellButton._cellVanillaCapture:Show() else spellButton._cellVanillaCapture:Hide() end
				spellButton._cellVanillaCapture:EnableKeyboard(false)
				spellButton:EnableKeyboard(overSpell and true or false)
			end
		end
	end
	InstallSpellbookBindingHooks()
	if SpellBookFrame and SpellBookFrame.HookScript and not SpellBookFrame._cellVanillaBindingHooked then
		SpellBookFrame._cellVanillaBindingHooked = true
		SpellBookFrame:HookScript("OnShow", InstallSpellbookBindingHooks)
		SpellBookFrame:HookScript("OnHide", function() if bindingMode then DisableSpellbookCapture() end end)
		SpellBookFrame:HookScript("OnKeyDown", function(_, key) if bindingMode and key == "ESCAPE" then DisableSpellbookCapture() end end)
	end

	local optionBuilder = Cell.OptionPageBuilders and Cell.OptionPageBuilders.general
	if optionBuilder then
		optionBuilder({Cell = Cell, panel = panel, pages = panel.pages, AddOptionsButton = AddOptionsButton, AddOptionsCheckbox = AddOptionsCheckbox, AddOptionsSlider = AddOptionsSlider, AddChoiceDropdown = AddChoiceDropdown, StyleOptionsDropdownButton = StyleOptionsDropdownButton, StyleOptionsDropdownMenu = StyleOptionsDropdownMenu, AddSectionTitle = AddSectionTitle, AddOptionsDivider = AddOptionsDivider, RegisterAccentRefresher = RegisterAccentRefresher, GetUIAccentColor = GetUIAccentColor, SetPageContentExtent = setPageContentExtent,
			SaveSetting = function(key, value) local settings = GetCellSettingsDB(); settings[key] = value; SaveCellSettingsDB() end})
	end

	local appearanceBuilder = Cell.OptionPageBuilders and Cell.OptionPageBuilders.appearance
	if appearanceBuilder then appearanceBuilder({Cell = Cell, panel = panel, pages = panel.pages, AddOptionsButton = AddOptionsButton, AddOptionsCheckbox = AddOptionsCheckbox, AddOptionsSlider = AddOptionsSlider, AddChoiceDropdown = AddChoiceDropdown, StyleOptionsDropdownButton = StyleOptionsDropdownButton, StyleOptionsDropdownMenu = StyleOptionsDropdownMenu, AddSectionTitle = AddSectionTitle, AddOptionsDivider = AddOptionsDivider, RegisterAccentRefresher = RegisterAccentRefresher, GetUIAccentColor = GetUIAccentColor, SetPageContentExtent = setPageContentExtent,
		SaveSetting = function(key, value) local settings = GetCellSettingsDB(); settings[key] = value; SaveCellSettingsDB() end}) end
	local indicatorsBuilder = Cell.OptionPageBuilders and Cell.OptionPageBuilders.indicators
	if indicatorsBuilder then indicatorsBuilder({Cell = Cell, panel = panel, pages = panel.pages, AddOptionsButton = AddOptionsButton, AddOptionsCheckbox = AddOptionsCheckbox, AddOptionsSlider = AddOptionsSlider, AddChoiceDropdown = AddChoiceDropdown, StyleOptionsDropdownButton = StyleOptionsDropdownButton, StyleOptionsDropdownMenu = StyleOptionsDropdownMenu, AddSectionTitle = AddSectionTitle, AddOptionsDivider = AddOptionsDivider, RegisterAccentRefresher = RegisterAccentRefresher, GetUIAccentColor = GetUIAccentColor, SetPageContentExtent = setPageContentExtent}) end
	if panel.layoutAutoSwitchFrame and panel.indicatorPreviewFrame then
		panel.layoutAutoSwitchFrame:ClearAllPoints(); panel.layoutAutoSwitchFrame:SetPoint("TOPLEFT",panel.indicatorPreviewFrame,"BOTTOMLEFT",0,-78)
	end
	AddSectionTitle(statusPage, "Debuff display", 10, -12)
	panel.debuffCheckbox = AddOptionsCheckbox(statusPage, "Show Debuff Icons", 10, -40, 407, function()
		Cell.showDebuffIcons = not Cell.showDebuffIcons
		NotCellVanillaDB = GetCellSettingsDB()
		NotCellVanillaDB.showDebuffIcons = Cell.showDebuffIcons
		SaveCellSettingsDB()
		Cell:UpdateFrames()
		Cell:RefreshOptionsMenu()
	end)
	panel.debuffFillButton = AddOptionsButton(statusPage, "", 10, -72, 407, function()
		local modes = {"none", "solid", "gradient"}
		local nextIndex = 1
		for i = 1, table.getn(modes) do if modes[i] == Cell.debuffFillMode then nextIndex = i + 1 end end
		if nextIndex > table.getn(modes) then nextIndex = 1 end
		Cell.debuffFillMode = modes[nextIndex]
		NotCellVanillaDB = GetCellSettingsDB(); NotCellVanillaDB.debuffFillMode = Cell.debuffFillMode; SaveCellSettingsDB()
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	panel.debuffBorderCheckbox = AddOptionsCheckbox(statusPage, "Debuff Border", 10, -104, 200, function()
		Cell.debuffBorderEnabled = not Cell.debuffBorderEnabled
		NotCellVanillaDB = GetCellSettingsDB(); NotCellVanillaDB.debuffBorderEnabled = Cell.debuffBorderEnabled; SaveCellSettingsDB()
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	panel.debuffBorderSizeButton = AddOptionsButton(statusPage, "", 217, -104, 200, function()
		Cell.debuffBorderSize = Cell.debuffBorderSize % 8 + 1
		NotCellVanillaDB = GetCellSettingsDB(); NotCellVanillaDB.debuffBorderSize = Cell.debuffBorderSize; SaveCellSettingsDB()
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	panel.debuffFillAmountButton = AddOptionsButton(statusPage, "", 10, -136, 407, function()
		local amounts = {10, 25, 50, 75, 100}
		local nextIndex = 1
		for i = 1, table.getn(amounts) do if amounts[i] == Cell.debuffFillAmount then nextIndex = i + 1 end end
		if nextIndex > table.getn(amounts) then nextIndex = 1 end
		Cell.debuffFillAmount = amounts[nextIndex]
		NotCellVanillaDB = GetCellSettingsDB(); NotCellVanillaDB.debuffFillAmount = Cell.debuffFillAmount; SaveCellSettingsDB()
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	panel.debuffDirectionButton = AddOptionsButton(statusPage, "", 10, -168, 407, function()
		local directions = {"left-to-right", "right-to-left", "down-to-up", "up-to-down"}
		local nextIndex = 1
		for i = 1, table.getn(directions) do if directions[i] == Cell.debuffFillDirection then nextIndex = i + 1 end end
		if nextIndex > table.getn(directions) then nextIndex = 1 end
		Cell.debuffFillDirection = directions[nextIndex]
		NotCellVanillaDB = GetCellSettingsDB(); NotCellVanillaDB.debuffFillDirection = Cell.debuffFillDirection; SaveCellSettingsDB()
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	local widthSlider,heightSlider,powerHeightSlider
	local function SaveLayoutSettings()
		NotCellVanillaDB=GetCellSettingsDB(); NotCellVanillaDB.layouts=Cell.groupLayoutProfiles; NotCellVanillaDB.groupLayoutProfiles=Cell.groupLayoutProfiles; NotCellVanillaDB.layoutAutoSwitch=Cell.layoutAutoSwitch; NotCellVanillaDB.selectedLayout=Cell.selectedGroupLayout; NotCellVanillaDB.selectedGroupLayout=Cell.selectedGroupLayout; NotCellVanillaDB.autoGroupLayouts=Cell.autoGroupLayouts; SaveCellSettingsDB()
	end
	local function AddLayoutPicker(parent,x,y,width,getValue,onSelect,labelPrefix,includeHide)
		local button=StyleOptionsDropdownButton(AddOptionsButton(parent,"",x,y,width,nil))
		local menu=CreateFrame("Frame",nil,UIParent); menu:SetFrameStrata("TOOLTIP"); menu:SetFrameLevel(1400); menu:SetWidth(width); menu:SetHeight(24); menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); menu:SetBackdropColor(.04,.04,.04,.98); menu:Hide()
		StyleOptionsDropdownMenu(menu)
		local rows={}
		-- This is called both with dot and colon syntax throughout the options code.
		function button.RefreshChoiceLabel()
			local value=getValue()
			button:SetText((labelPrefix or "Layout")..": "..(value=="hide" and "Hide" or (Cell.groupLayoutLabels[value] or value or "Default")))
		end
		button:SetScript("OnClick",function()
			if menu:IsShown() then menu:Hide(); return end
			local keys={}
			if includeHide then keys[#keys+1]="hide" end
			for _,key in ipairs(Cell.groupLayoutNames or {}) do keys[#keys+1]=key end
			menu:SetHeight(math.max(24,table.getn(keys)*24+4)); menu:ClearAllPoints()
			if button:GetBottom() and button:GetBottom()<menu:GetHeight()+20 then menu:SetPoint("BOTTOMLEFT",button,"TOPLEFT",0,1) else menu:SetPoint("TOPLEFT",button,"BOTTOMLEFT",0,-1) end
			for i,key in ipairs(keys) do
				local layoutKey=key; local row=rows[i]
				if not row then row=StyleOptionsDropdownItem(AddOptionsButton(menu,"",3,-3-(i-1)*24,width-6,nil)); row:SetHeight(23); rows[i]=row end
				row:SetPoint("TOPLEFT",menu,"TOPLEFT",3,-3-(i-1)*24); row:SetText(layoutKey=="hide" and "Hide" or (Cell.groupLayoutLabels[layoutKey] or layoutKey)); row:SetScript("OnClick",function() menu:Hide(); onSelect(layoutKey) end); row:Show()
			end
			for i=table.getn(keys)+1,table.getn(rows) do rows[i]:Hide() end
			Cell:ShowOptionsDropdown(menu); menu:Show()
		end)
		button.RefreshChoiceLabel(); return button
	end
	local function ApplySelectedLayout(key)
		if not Cell.groupLayoutProfiles[key] then return end
		Cell.selectedGroupLayout=key; SaveLayoutSettings()
		local profile=Cell.groupLayoutProfiles[key]
		Cell.syncingLayoutControls=true
		if widthSlider then widthSlider:SetValue(profile.width) end
		if heightSlider then heightSlider:SetValue(profile.height) end
		if powerHeightSlider then powerHeightSlider:SetValue(profile.powerBarHeight or Cell.powerBarHeight) end
		Cell.syncingLayoutControls=nil
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout==key then Cell.buttonWidth=profile.width; Cell.buttonHeight=profile.height; Cell.powerBarHeight=profile.powerBarHeight or Cell.powerBarHeight; Cell.healthBarOrientation=profile.healthBarOrientation; Cell.powerBarOrientation=profile.powerBarOrientation; Cell.powerBarSide=profile.powerBarSide; Cell:ApplyButtonSize() end
		Cell:ApplyTextSettings(); if Cell.optionsFrame and Cell.optionsFrame.UpdateIndicatorPreview then Cell.optionsFrame.UpdateIndicatorPreview() end
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end
	panel.layoutsHeading = AddSectionTitle(sizePage, "Layouts", 10, -12)
	panel.groupLayoutButton=AddLayoutPicker(sizePage,10,-40,407,function() return Cell.selectedGroupLayout end,ApplySelectedLayout,"Layout")
	local layoutNameEdit=CreateFrame("EditBox",nil,sizePage); layoutNameEdit:SetWidth(160); layoutNameEdit:SetHeight(26); layoutNameEdit:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-74); layoutNameEdit:SetAutoFocus(false); layoutNameEdit:SetFontObject(GameFontNormalSmall); layoutNameEdit:SetTextInsets(5,5,2,2); layoutNameEdit:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); layoutNameEdit:SetBackdropColor(.05,.05,.05,1); layoutNameEdit:SetText("New layout name"); panel.layoutNameEdit=layoutNameEdit
	layoutNameEdit:SetScript("OnEditFocusGained",function(self) if self:GetText()=="New layout name" then self:SetText("") end end)
	layoutNameEdit:SetScript("OnEditFocusLost",function(self) if self:GetText()=="" then self:SetText("New layout name") end end)
	layoutNameEdit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
	panel.createLayoutButton=AddOptionsButton(sizePage,"Create new",180,-74,105,function()
		local name=layoutNameEdit:GetText(); if name=="New layout name" then name="" end; name=string.gsub(name or "","^%s*(.-)%s*$","%1")
		local created,err=Cell:CreateLayoutProfile(name,Cell.selectedGroupLayout)
		if not created then DEFAULT_CHAT_FRAME:AddMessage("NotCell: "..(err or "Could not create layout.")); return end
		SaveLayoutSettings(); layoutNameEdit:SetText(""); ApplySelectedLayout(created); for _,dropdown in ipairs(panel.autoLayoutDropdowns or {}) do dropdown:RefreshChoiceLabel() end
	end)
	panel.renameLayoutButton=AddOptionsButton(sizePage,"Rename",290,-74,65,function()
		local key=Cell.selectedGroupLayout; if builtInLayouts[key] then return end
		local name=layoutNameEdit:GetText(); if name=="New layout name" then name="" end; name=string.gsub(name or "","^%s*(.-)%s*$","%1")
		if name=="" or Cell.groupLayoutProfiles[name] then return end
		Cell.groupLayoutProfiles[name]=Cell.groupLayoutProfiles[key]; Cell.groupLayoutProfiles[name].displayName=name; Cell.groupLayoutProfiles[key]=nil; Cell.groupLayoutLabels[key]=nil; Cell.groupLayoutLabels[name]=name
		for i,entry in ipairs(Cell.groupLayoutNames) do if entry==key then Cell.groupLayoutNames[i]=name end end
		for groupType,entry in pairs(Cell.layoutAutoSwitch) do if entry==key then Cell.layoutAutoSwitch[groupType]=name end end
		if Cell.selectedGroupLayout==key then Cell.selectedGroupLayout=name end; SaveLayoutSettings(); layoutNameEdit:SetText(""); ApplySelectedLayout(name); for _,dropdown in ipairs(panel.autoLayoutDropdowns or {}) do dropdown:RefreshChoiceLabel() end
	end)
	panel.deleteLayoutButton=AddOptionsButton(sizePage,"Delete",360,-74,57,function()
		local key=Cell.selectedGroupLayout; if builtInLayouts[key] then return end
		Cell.groupLayoutProfiles[key]=nil; Cell.groupLayoutLabels[key]=nil; for i,entry in ipairs(Cell.groupLayoutNames) do if entry==key then table.remove(Cell.groupLayoutNames,i); break end end
		local fallback="Default"
		for groupType,entry in pairs(Cell.layoutAutoSwitch) do if entry==key then Cell.layoutAutoSwitch[groupType]=fallback end end
		Cell.selectedGroupLayout=fallback; SaveLayoutSettings(); ApplySelectedLayout(fallback); for _,dropdown in ipairs(panel.autoLayoutDropdowns or {}) do dropdown:RefreshChoiceLabel() end
	end)
	local layoutTransferFrame,layoutTransferEdit,layoutTransferScroll
	local function PrettyLayoutJSON(source)
		local output, quoted, escaped = {}, false, false
		for index = 1, string.len(source or "") do
			local char = string.sub(source, index, index)
			output[table.getn(output) + 1] = char
			if quoted then
				if escaped then escaped = false elseif char == "\\" then escaped = true elseif char == '"' then quoted = false end
			elseif char == '"' then quoted = true
			elseif char == "," then output[table.getn(output) + 1] = "\n" end
		end
		return table.concat(output)
	end
	local function OpenLayoutTransfer(mode)
		if not layoutTransferFrame then
			layoutTransferFrame=CreateFrame("Frame","NotCellLayoutTransferFrame",UIParent)
			layoutTransferFrame:SetWidth(600); layoutTransferFrame:SetHeight(460); layoutTransferFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
			layoutTransferFrame:SetFrameStrata("DIALOG"); layoutTransferFrame:SetFrameLevel(220); layoutTransferFrame:SetMovable(true); layoutTransferFrame:SetClampedToScreen(true)
			layoutTransferFrame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}}); layoutTransferFrame:SetBackdropColor(.035,.035,.035,.98)
		layoutTransferFrame.title=layoutTransferFrame:CreateFontString(nil,"OVERLAY","GameFontNormal"); layoutTransferFrame.title:SetPoint("TOPLEFT",layoutTransferFrame,"TOPLEFT",16,-14); layoutTransferFrame.title:SetTextColor(GetUIAccentColor()); RegisterAccentRefresher(function() layoutTransferFrame.title:SetTextColor(GetUIAccentColor()) end)
			layoutTransferScroll=CreateFrame("ScrollFrame",nil,layoutTransferFrame); layoutTransferScroll:SetPoint("TOPLEFT",layoutTransferFrame,"TOPLEFT",16,-48); layoutTransferScroll:SetWidth(568); layoutTransferScroll:SetHeight(350); layoutTransferScroll:EnableMouseWheel(true)
			layoutTransferEdit=CreateFrame("EditBox",nil,layoutTransferScroll); layoutTransferEdit:SetPoint("TOPLEFT",layoutTransferScroll,"TOPLEFT",0,0); layoutTransferEdit:SetWidth(552); layoutTransferEdit:SetHeight(350); layoutTransferEdit:SetAutoFocus(false); layoutTransferEdit:SetMultiLine(true); layoutTransferEdit:SetFontObject(GameFontNormalSmall); layoutTransferEdit:SetTextInsets(8,8,8,8); layoutTransferScroll:SetScrollChild(layoutTransferEdit)
			layoutTransferScroll:SetScript("OnMouseWheel",function(self,delta) self:SetVerticalScroll(math.max(0,math.min(math.max(0,layoutTransferEdit:GetHeight()-self:GetHeight()),(self:GetVerticalScroll() or 0)-delta*24))) end)
			layoutTransferEdit:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); layoutTransferEdit:SetBackdropColor(.02,.02,.02,1)
			layoutTransferFrame.close=AddOptionsButton(layoutTransferFrame,"Close",492,-414,90,function() layoutTransferFrame:Hide() end)
			layoutTransferFrame.encode=AddOptionsButton(layoutTransferFrame,"Encode",202,-414,88,function()
				local data,err=Cell:EncodeLayoutProfile(layoutTransferEdit:GetText() or "")
				if not data then DEFAULT_CHAT_FRAME:AddMessage("NotCell: "..(err or "Could not encode layout.")); return end
				layoutTransferEdit:SetText(data); layoutTransferEdit:SetHeight(350); layoutTransferScroll:SetVerticalScroll(0)
			end)
			layoutTransferFrame.decode=AddOptionsButton(layoutTransferFrame,"Decode",296,-414,88,function()
				local data,err=Cell:DecodeLayoutProfile(layoutTransferEdit:GetText() or "")
				if not data then DEFAULT_CHAT_FRAME:AddMessage("NotCell: "..(err or "Could not decode layout.")); return end
				data=PrettyLayoutJSON(data); layoutTransferEdit:SetText(data)
				local lines=select(2,string.gsub(data,"\n",""))+1; layoutTransferEdit:SetHeight(math.max(350,lines*16+16)); layoutTransferScroll:SetVerticalScroll(0)
			end)
			layoutTransferFrame.import=AddOptionsButton(layoutTransferFrame,"Import layout",390,-414,95,function()
				local name,err=Cell:ImportLayoutProfile(layoutTransferEdit:GetText() or "")
			if not name then DEFAULT_CHAT_FRAME:AddMessage("NotCell: "..(err or "Could not import layout.")); return end
				SaveLayoutSettings(); ApplySelectedLayout(name); layoutNameEdit:SetText(""); layoutTransferFrame:Hide()
				for _,dropdown in ipairs(panel.autoLayoutDropdowns or {}) do dropdown:RefreshChoiceLabel() end
			end)
			if UISpecialFrames then table.insert(UISpecialFrames,"NotCellLayoutTransferFrame") end
		end
		layoutTransferFrame.title:SetText(mode=="export" and ("Export layout: "..Cell.selectedGroupLayout) or "Import layout")
		if mode=="export" then
			local data,err=Cell:ExportLayoutProfile(Cell.selectedGroupLayout)
			local encoded,encodeError=data and Cell:EncodeLayoutProfile(data)
			layoutTransferEdit:SetText(encoded or data or err or encodeError or "Export failed."); layoutTransferEdit:SetHeight(350); layoutTransferScroll:SetVerticalScroll(0)
			layoutTransferEdit:SetFocus(); layoutTransferEdit:HighlightText(); layoutTransferFrame.import:Hide(); layoutTransferFrame.encode:Show(); layoutTransferFrame.decode:Show()
		else
			layoutTransferEdit:SetText(""); layoutTransferEdit:SetHeight(350); layoutTransferScroll:SetVerticalScroll(0); layoutTransferEdit:SetFocus(); layoutTransferFrame.import:Show(); layoutTransferFrame.encode:Hide(); layoutTransferFrame.decode:Hide()
		end
		layoutTransferFrame:Show()
	end
	panel.exportLayoutButton=AddOptionsButton(sizePage,"Export",10,-104,80,function() OpenLayoutTransfer("export") end)
	panel.importLayoutButton=AddOptionsButton(sizePage,"Import",96,-104,80,function() OpenLayoutTransfer("import") end)
	panel.selectedLayoutHeading = AddSectionTitle(sizePage, "Selected layout settings", 10, -142)
	widthSlider = AddOptionsSlider(sizePage, "Width", 10, -172, 195, 40, 300, 1, self.buttonWidth, function(value)
		if Cell.syncingLayoutControls then return end
		Cell.groupLayoutProfiles[Cell.selectedGroupLayout].width = value
		SaveLayoutSettings()
		if (Cell.preview and Cell.previewGroupLayout == Cell.selectedGroupLayout) or (not Cell.preview and (not Cell.autoGroupLayouts or Cell.activeGroupLayout == Cell.selectedGroupLayout)) then
			Cell.buttonWidth = value
			Cell:ApplyButtonSize()
		elseif not Cell.preview and not Cell.activeGroupLayout then
			Cell:UpdateFrames()
		end
		if Cell.optionsFrame and Cell.optionsFrame.UpdateIndicatorPreview then Cell.optionsFrame.UpdateIndicatorPreview() end
	end)
	heightSlider = AddOptionsSlider(sizePage, "Height", 220, -172, 195, 32, 120, 1, self.buttonHeight, function(value)
		if Cell.syncingLayoutControls then return end
		Cell.groupLayoutProfiles[Cell.selectedGroupLayout].height = value
		SaveLayoutSettings()
		if (Cell.preview and Cell.previewGroupLayout == Cell.selectedGroupLayout) or (not Cell.preview and (not Cell.autoGroupLayouts or Cell.activeGroupLayout == Cell.selectedGroupLayout)) then
			Cell.buttonHeight = value
			Cell:ApplyButtonSize()
		elseif not Cell.preview and not Cell.activeGroupLayout then
			Cell:UpdateFrames()
		end
		if Cell.optionsFrame and Cell.optionsFrame.UpdateIndicatorPreview then Cell.optionsFrame.UpdateIndicatorPreview() end
	end)
	powerHeightSlider = AddOptionsSlider(sizePage, "Power bar height", 10, -222, 195, 2, 12, 1, self.powerBarHeight, function(value)
		if Cell.syncingLayoutControls then return end
		Cell.groupLayoutProfiles[Cell.selectedGroupLayout].powerBarHeight = value
		SaveLayoutSettings()
		if (Cell.preview and Cell.previewGroupLayout == Cell.selectedGroupLayout) or (not Cell.preview and (not Cell.autoGroupLayouts or Cell.activeGroupLayout == Cell.selectedGroupLayout)) then
			Cell.powerBarHeight = value
			Cell:ApplyButtonSize()
		end
		if Cell.optionsFrame and Cell.optionsFrame.UpdateIndicatorPreview then Cell.optionsFrame.UpdateIndicatorPreview() end
	end)
	panel.widthSlider = widthSlider
	panel.heightSlider = heightSlider
	panel.powerHeightSlider = powerHeightSlider
	local barOrientationChoices = {{name="Horizontal",value="HORIZONTAL"},{name="Vertical",value="VERTICAL"}}
	local powerSideChoices = {{name="Left",value="LEFT"},{name="Right",value="RIGHT"}}
	panel.healthBarDirectionDropdown = AddChoiceDropdown(sizePage,195,220,-222,function()
		return "Health fill: " .. (Cell.groupLayoutProfiles[Cell.selectedGroupLayout].healthBarOrientation == "VERTICAL" and "Vertical" or "Horizontal")
	end,barOrientationChoices,function(value)
		local profile=Cell.groupLayoutProfiles[Cell.selectedGroupLayout]; profile.healthBarOrientation=value; SaveLayoutSettings()
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout==Cell.selectedGroupLayout then Cell.healthBarOrientation=value; Cell:ApplyButtonSize() end
		Cell:RefreshOptionsMenu()
	end)
	panel.powerBarDirectionDropdown = AddChoiceDropdown(sizePage,195,220,-252,function()
		return "Power bar: " .. (Cell.groupLayoutProfiles[Cell.selectedGroupLayout].powerBarOrientation == "VERTICAL" and "Vertical" or "Horizontal")
	end,barOrientationChoices,function(value)
		local profile=Cell.groupLayoutProfiles[Cell.selectedGroupLayout]; profile.powerBarOrientation=value; SaveLayoutSettings()
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout==Cell.selectedGroupLayout then Cell.powerBarOrientation=value; Cell:ApplyButtonSize() end
		Cell:RefreshOptionsMenu()
	end)
	panel.powerBarSideDropdown = AddChoiceDropdown(sizePage,195,220,-282,function()
		return "Power bar side: " .. (Cell.groupLayoutProfiles[Cell.selectedGroupLayout].powerBarSide == "RIGHT" and "Right" or "Left")
	end,powerSideChoices,function(value)
		local profile=Cell.groupLayoutProfiles[Cell.selectedGroupLayout]; profile.powerBarSide=value; SaveLayoutSettings()
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout==Cell.selectedGroupLayout then Cell.powerBarSide=value; Cell:ApplyButtonSize() end
		Cell:RefreshOptionsMenu()
	end)
	panel.groupArrangementHeading = AddSectionTitle(sizePage, "Group arrangement", 10, -282)
	panel.groupsPerLineButton = AddOptionsButton(sizePage, "", 10, -312, 195, function()
		local profile = Cell.groupLayoutProfiles[Cell.selectedGroupLayout]
		profile.groupsPerLine = profile.groupsPerLine % 8 + 1
		SaveLayoutSettings()
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout == Cell.selectedGroupLayout then Cell:ApplyButtonSize() end
		Cell:RefreshOptionsMenu()
	end)
	panel.directionButton = AddOptionsButton(sizePage, "", 220, -312, 195, function()
		local profile = Cell.groupLayoutProfiles[Cell.selectedGroupLayout]
		local current = 1
		for i = 1, table.getn(directionModes) do if directionModes[i] == profile.direction then current = i end end
		profile.direction = directionModes[current % table.getn(directionModes) + 1]
		SaveLayoutSettings()
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout == Cell.selectedGroupLayout then Cell:ApplyButtonSize() end
		Cell:RefreshOptionsMenu()
	end)
	panel.groupFilterChecks = {}
	panel.groupFilterHeading = AddSectionTitle(sizePage, "Group filter", 10, -352)
	for group = 1, 8 do
		local groupID = group -- Lua 5.0 closures otherwise all capture the final loop value.
		local check = CreateFrame("Button", nil, sizePage)
		check:SetWidth(40); check:SetHeight(30); check:SetPoint("TOPLEFT", sizePage, "TOPLEFT", 10 + (groupID - 1) * 50, -376)
		local background = check:CreateTexture(nil, "BACKGROUND"); background:SetAllPoints(check); background:SetTexture("Interface\\Buttons\\WHITE8X8"); check.background = background
		local border = {}
		for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
			local line = check:CreateTexture(nil, "BORDER"); line:SetTexture("Interface\\Buttons\\WHITE8X8"); local r,g,b=GetUIAccentColor(); line:SetVertexColor(r*.62,g*.42,b*.20,1)
			if edge == "TOP" or edge == "BOTTOM" then line:SetPoint(edge,check,edge,0,0); line:SetWidth(40); line:SetHeight(1) else line:SetPoint(edge,check,edge,0,0); line:SetWidth(1); line:SetHeight(30) end
			border[edge] = line
		end
		local number = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); number:SetPoint("CENTER",check,"CENTER",0,0); number:SetText(tostring(groupID)); check.number = number
		function check:SetChecked(checked)
			self.checked = checked and true or false
			local r,g,b=GetUIAccentColor()
			if self.checked then self.background:SetVertexColor(r*.46,g*.22,b*.08,1); self.number:SetTextColor(r,g,b)
			else self.background:SetVertexColor(.055,.055,.055,1); self.number:SetTextColor(.78,.78,.78) end
		end
		check:SetScript("OnClick", function()
			local profile = Cell.groupLayoutProfiles[Cell.selectedGroupLayout]
			profile.groupFilter[groupID] = not profile.groupFilter[groupID]
			SaveLayoutSettings(); Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
		end)
		check:SetChecked(true)
		RegisterAccentRefresher(function()
			local r,g,b=GetUIAccentColor(); for _,line in pairs(border) do line:SetVertexColor(r*.62,g*.42,b*.20,1) end; check:SetChecked(check.checked)
		end)
		panel.groupFilterChecks[group] = check
	end
	panel.layoutPreviewButton = AddOptionsButton(sizePage, "Preview: Off", 10, -414, 407, function()
		local nextMode = Cell.layoutPreviewMode == nil and "party" or Cell.layoutPreviewMode == "party" and "raid" or nil
		Cell.layoutPreviewMode = nextMode
		Cell.preview = nextMode ~= nil
		Cell.previewMode = nextMode
		Cell.previewLimit = nil
		Cell.previewGroupLayout = Cell.selectedGroupLayout
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	panel.spacingXSlider = AddOptionsSlider(sizePage, "Unit Spacing Horizontal", 10, -448, 195, 0, 100, 1, 5, function(value)
		if Cell.syncingLayoutControls then return end
		Cell.groupLayoutProfiles[Cell.selectedGroupLayout].spacingX = value; SaveLayoutSettings()
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout == Cell.selectedGroupLayout then Cell:ApplyButtonSize() end
	end)
	panel.spacingYSlider = AddOptionsSlider(sizePage, "Unit Spacing Vertical", 220, -448, 195, 0, 100, 1, 4, function(value)
		if Cell.syncingLayoutControls then return end
		Cell.groupLayoutProfiles[Cell.selectedGroupLayout].spacingY = value; SaveLayoutSettings()
		if Cell.preview or not Cell.autoGroupLayouts or Cell.activeGroupLayout == Cell.selectedGroupLayout then Cell:ApplyButtonSize() end
	end)
	panel.UpdateLayoutsResponsive = function()
		local width=math.max(1,sizePage:GetWidth()-20); local gap=20; local column=(width-gap)/2; local right=10+column+gap
		panel.layoutsHeading:ClearAllPoints(); panel.layoutsHeading:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-12)
		panel.groupLayoutButton:ClearAllPoints(); panel.groupLayoutButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-40); panel.groupLayoutButton:SetWidth(width)
		local nameWidth=math.min(160,math.max(130,width*.40)); local start=10+nameWidth+8; local gapSmall=4; local buttonW=math.max(54,(width-nameWidth-16)/3)
		layoutNameEdit:ClearAllPoints(); layoutNameEdit:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-74); layoutNameEdit:SetWidth(nameWidth)
		local createW,renameW,deleteW=buttonW,buttonW,buttonW
		panel.createLayoutButton:ClearAllPoints(); panel.createLayoutButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",start,-74); panel.createLayoutButton:SetWidth(createW)
		panel.renameLayoutButton:ClearAllPoints(); panel.renameLayoutButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",start+createW+gapSmall,-74); panel.renameLayoutButton:SetWidth(renameW)
		panel.deleteLayoutButton:ClearAllPoints(); panel.deleteLayoutButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",start+createW+renameW+gapSmall*2,-74); panel.deleteLayoutButton:SetWidth(deleteW)
		panel.exportLayoutButton:ClearAllPoints(); panel.exportLayoutButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-104); panel.exportLayoutButton:SetWidth((width-gapSmall)/2)
		panel.importLayoutButton:ClearAllPoints(); panel.importLayoutButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10+(width+gapSmall)/2,-104); panel.importLayoutButton:SetWidth((width-gapSmall)/2)
		panel.selectedLayoutHeading:ClearAllPoints(); panel.selectedLayoutHeading:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-142)
		Cell:PlaceOptionsSlider(widthSlider,sizePage,10,-162,column); Cell:PlaceOptionsSlider(heightSlider,sizePage,right,-162,column); Cell:PlaceOptionsSlider(powerHeightSlider,sizePage,10,-222,column)
		panel.healthBarDirectionDropdown:ClearAllPoints(); panel.healthBarDirectionDropdown:SetPoint("TOPLEFT",sizePage,"TOPLEFT",right,-222); panel.healthBarDirectionDropdown:SetWidth(column)
		panel.powerBarDirectionDropdown:ClearAllPoints(); panel.powerBarDirectionDropdown:SetPoint("TOPLEFT",sizePage,"TOPLEFT",right,-252); panel.powerBarDirectionDropdown:SetWidth(column)
		panel.powerBarSideDropdown:ClearAllPoints(); panel.powerBarSideDropdown:SetPoint("TOPLEFT",sizePage,"TOPLEFT",right,-282); panel.powerBarSideDropdown:SetWidth(column)
		panel.groupArrangementHeading:ClearAllPoints(); panel.groupArrangementHeading:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-282)
		panel.groupsPerLineButton:ClearAllPoints(); panel.groupsPerLineButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-312); panel.groupsPerLineButton:SetWidth(column)
		panel.directionButton:ClearAllPoints(); panel.directionButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",right,-312); panel.directionButton:SetWidth(column)
		panel.groupFilterHeading:ClearAllPoints(); panel.groupFilterHeading:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-352)
		for group=1,8 do local check=panel.groupFilterChecks[group]; local square=40; local cell=width/8; check:ClearAllPoints(); check:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10+(group-1)*cell+(cell-square)/2,-376); check:SetWidth(square) end
		panel.layoutPreviewButton:ClearAllPoints(); panel.layoutPreviewButton:SetPoint("TOPLEFT",sizePage,"TOPLEFT",10,-414); panel.layoutPreviewButton:SetWidth(width)
		-- Keep the spacing pair as the final compact row; mover dragging saves
		-- positions directly, so the old manual-save button is no longer needed.
		Cell:PlaceOptionsSlider(panel.spacingXSlider,sizePage,10,-448,column); Cell:PlaceOptionsSlider(panel.spacingYSlider,sizePage,right,-448,column)
		panel:SetPageContentExtent("size", 506)
	end
	sizePage:SetScript("OnSizeChanged",function() if panel.UpdateLayoutsResponsive then panel.UpdateLayoutsResponsive() end end)
	panel.UpdateLayoutsResponsive()
	autoSwitchFrame=CreateFrame("Frame",nil,UIParent)
	autoSwitchFrame:SetWidth(245); autoSwitchFrame:SetHeight(362); autoSwitchFrame:SetFrameStrata("DIALOG"); autoSwitchFrame:SetFrameLevel(panel:GetFrameLevel()+40); autoSwitchFrame:SetClampedToScreen(true)
	autoSwitchFrame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}}); autoSwitchFrame:SetBackdropColor(.035,.035,.035,.98)
	autoSwitchFrame.title=autoSwitchFrame:CreateFontString(nil,"OVERLAY","GameFontNormal"); autoSwitchFrame.title:SetPoint("TOPLEFT",autoSwitchFrame,"TOPLEFT",12,-10); autoSwitchFrame.title:SetText("Layout Auto Switch"); autoSwitchFrame.title:SetTextColor(GetUIAccentColor()); RegisterAccentRefresher(function() autoSwitchFrame.title:SetTextColor(GetUIAccentColor()) end)
	panel.autoGroupLayoutsCheckbox=AddOptionsCheckbox(autoSwitchFrame,"Automatically use selected layouts",12,-35,218,function()
		Cell.autoGroupLayouts=not Cell.autoGroupLayouts; SaveLayoutSettings(); Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	autoSwitchFrame.currentProfile=autoSwitchFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); autoSwitchFrame.currentProfile:SetPoint("TOPLEFT",autoSwitchFrame,"TOPLEFT",12,-67); autoSwitchFrame.currentProfile:SetWidth(220); autoSwitchFrame.currentProfile:SetJustifyH("LEFT")
	panel.autoLayoutDropdowns={}
	local autoLayoutRows={{"Solo","solo",-98},{"Party","party",-140},{"Raid (Outdoor)","raid_outdoor",-182},{"Raid 10","raid10",-224},{"Raid 25","raid25",-266},{"Raid 40","raid40",-308}}
	for _,row in ipairs(autoLayoutRows) do
		local groupLabel,groupType,rowY=row[1],row[2],row[3]
		local label=autoSwitchFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); label:SetPoint("TOPLEFT",autoSwitchFrame,"TOPLEFT",12,rowY+13); label:SetText(groupLabel)
		local dropdown=AddLayoutPicker(autoSwitchFrame,12,rowY,218,function() return Cell.layoutAutoSwitch[groupType] end,function(layoutKey)
			Cell.layoutAutoSwitch[groupType]=layoutKey; SaveLayoutSettings(); Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
		end,groupLabel,true)
		panel.autoLayoutDropdowns[#panel.autoLayoutDropdowns+1]=dropdown
	end
	panel.layoutAutoSwitchFrame=autoSwitchFrame
	autoSwitchFrame:SetPoint("TOPLEFT",panel.indicatorPreviewFrame or panel,"BOTTOMLEFT",0,-78)
	panel:HookScript("OnHide",function() autoSwitchFrame:Hide() end)
	panel:HookScript("OnShow",function() if panel.activeMainTab=="layouts" then autoSwitchFrame:Show() end end)
	AddSectionTitle(statusPage, "Dead unit backdrop", 10, -292)
	panel.deadBackdropCheckbox = AddOptionsCheckbox(statusPage, "Custom Dead Backdrop", 10, -320, 200, function()
		Cell.deadBackdropEnabled = not Cell.deadBackdropEnabled
		NotCellVanillaDB = GetCellSettingsDB(); NotCellVanillaDB.deadBackdropEnabled = Cell.deadBackdropEnabled; SaveCellSettingsDB()
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
	end)
	panel.deadBackdropColorButton = AddOptionsButton(statusPage, "Custom Dead Backdrop", 217, -320, 200, function()
		Cell:OpenDeadBackdropColorPicker()
	end)
	panel.deadBackdropSwatch = panel.deadBackdropColorButton:CreateTexture(nil, "OVERLAY")
	panel.deadBackdropSwatch:SetWidth(16); panel.deadBackdropSwatch:SetHeight(16)
	panel.deadBackdropSwatch:SetPoint("RIGHT", panel.deadBackdropColorButton, "RIGHT", -8, 0)
	panel.UpdateStatusResponsive = function()
		local width=math.max(1,statusPage:GetWidth()-20); local column=(width-20)/2; local right=10+column+20
		panel.debuffFillButton:SetWidth(width); panel.debuffFillAmountButton:SetWidth(width); panel.debuffDirectionButton:SetWidth(width)
		panel.debuffBorderCheckbox:ClearAllPoints(); panel.debuffBorderCheckbox:SetPoint("TOPLEFT",statusPage,"TOPLEFT",10,-104); panel.debuffBorderCheckbox:SetWidth(column)
		panel.debuffBorderSizeButton:ClearAllPoints(); panel.debuffBorderSizeButton:SetPoint("TOPLEFT",statusPage,"TOPLEFT",right,-104); panel.debuffBorderSizeButton:SetWidth(column)
		panel.deadBackdropCheckbox:SetWidth(column); panel.deadBackdropColorButton:ClearAllPoints(); panel.deadBackdropColorButton:SetPoint("TOPLEFT",statusPage,"TOPLEFT",right,-320); panel.deadBackdropColorButton:SetWidth(column)
		panel:SetPageContentExtent("status", 344)
	end
	panel:UpdateResponsiveLayout()
	self.optionsFrame = panel
	function Cell:SelectOptionsPage(id)
		local pageOwners = {appearance = "appearance", size = "layouts", clicks = "clickCastings", status = "indicators", indicators = "indicators", about = "about"}
	SelectMainTab(pageOwners[id] or "general", id)
	end
	SelectMainTab("general")
	self.optionsFrame = panel
	ApplyOptionsScale((tonumber(self.optionsScale) or 100) / 100)
	function self:ApplyOptionsUIScale(value)
		if self.optionsFrame and self.optionsFrame._cellApplyOptionsScale then self.optionsFrame._cellApplyOptionsScale((tonumber(value) or 100) / 100) end
	end
	self:RefreshOptionsMenu()
	return panel
end

function Cell:OpenCustomColorPicker()
	self:OpenHealthColorPicker("customHealthColor", self.customHealthColor, false)
end

function Cell:OpenTappedColorPicker()
	self:OpenHealthColorPicker("tappedColor", self.tappedColor, true)
end

function Cell:OpenDeadBackdropColorPicker()
	self:OpenHealthColorPicker("customDeadBackdrop", self.customDeadBackdrop, false, false, nil, true)
end

function Cell:OpenNameColorPicker()
	self:OpenHealthColorPicker("nameCustomColor", self.nameCustomColor, false, true)
end

function Cell:OpenValueColorPicker(which)
	if which == "health" then
		self:OpenHealthColorPicker("healthTextCustomColor", self.healthTextCustomColor, false, false, "health")
	else
		self:OpenHealthColorPicker("powerTextCustomColor", self.powerTextCustomColor, false, false, "power")
	end
end

function Cell:RaiseColorPicker()
	if not ColorPickerFrame then return false end
	-- Keep the stock 1.12 picker in the dialog layer. Extremely high levels
	-- (1200+) can put its controls into a non-interactive layer on this client.
	if ColorPickerFrame.SetFrameStrata then ColorPickerFrame:SetFrameStrata("DIALOG") end
	if ColorPickerFrame.SetFrameLevel then ColorPickerFrame:SetFrameLevel((self.optionsFrame and self.optionsFrame:GetFrameLevel() or 100) + 20) end
	local function RaisePickerButtons(frame)
		local function RaiseButton(pickerButton)
			if not pickerButton then return end
			if pickerButton.SetFrameStrata then pickerButton:SetFrameStrata("DIALOG") end
			if pickerButton.SetFrameLevel and frame.GetFrameLevel then pickerButton:SetFrameLevel(frame:GetFrameLevel() + 2) end
			if pickerButton.Enable then pickerButton:Enable() end
		end
		RaiseButton(ColorPickerOkayButton)
		RaiseButton(ColorPickerCancelButton)
	end
	if not ColorPickerFrame._cellLayerHooked and ColorPickerFrame.HookScript then
		ColorPickerFrame._cellLayerHooked = true
		ColorPickerFrame:HookScript("OnShow", function(frame)
			if frame.SetFrameStrata then frame:SetFrameStrata("DIALOG") end
			if frame.SetFrameLevel then frame:SetFrameLevel((Cell.optionsFrame and Cell.optionsFrame:GetFrameLevel() or 100) + 20) end
			RaisePickerButtons(frame)
		end)
	end
	ColorPickerFrame._cellRaisePickerButtons = RaisePickerButtons
	return true
end

function Cell:OpenHealthColorPicker(settingName, originalColor, isTapped, isName, valueKind, isDeadBackdrop)
	if not ColorPickerFrame then
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: the client color picker is unavailable")
		return
	end
	local oldColor = {originalColor[1], originalColor[2], originalColor[3]}
	local function ApplyColor(r, g, b)
		local color = {r, g, b}
		if isTapped then
			self.tappedColor = color
		elseif settingName == "healthLossCustomColor" then
			self.healthLossCustomColor = color; self.healthLossColorMode = "custom"
		elseif settingName == "powerBarCustomColor" then
			self.powerBarCustomColor = color; self.powerColorMode = "custom"
		elseif settingName == "targetHighlightColor" then
			self.targetHighlightColor = color
		elseif settingName == "mouseoverHighlightColor" then
			self.mouseoverHighlightColor = color
		elseif settingName == "healPredictionColor" then
			self.healPredictionColor = color
		elseif isDeadBackdrop then
			self.customDeadBackdrop = color
		elseif settingName == "uiAccentCustomColor" then
			self.uiAccentCustomColor = color
		elseif isName then
			self.nameCustomColor = color
		elseif valueKind == "health" then
			self.healthTextCustomColor = color
			self.healthTextColorMode = "custom"
		elseif valueKind == "power" then
			self.powerTextCustomColor = color
			self.powerTextColorMode = "custom"
		else
			self.customHealthColor = color
			self.healthColorMode = "custom"
		end
		NotCellVanillaDB = GetCellSettingsDB()
		NotCellVanillaDB[settingName] = color
		if settingName == "healthLossCustomColor" then NotCellVanillaDB.healthLossColorMode = "custom"
		elseif settingName == "powerBarCustomColor" then NotCellVanillaDB.powerColorMode = "custom"
		elseif isName then
			NotCellVanillaDB.nameColorMode = "custom"
			self.nameColorMode = "custom"
		elseif valueKind == "health" then
			NotCellVanillaDB.healthTextColorMode = "custom"
		elseif valueKind == "power" then
			NotCellVanillaDB.powerTextColorMode = "custom"
		elseif settingName == "customHealthColor" then NotCellVanillaDB.healthColorMode = "custom" end
		SaveCellSettingsDB()
		if isTapped then
			for i = 1, table.getn(self.buttons) do
				local button = self.buttons[i]
				if button.healthBackground then button.healthBackground:SetTexture(color[1], color[2], color[3], 1) end
			end
		end
		self:UpdateFrames()
		self:RefreshOptionsMenu()
		if self.optionsFrame and self.optionsFrame.UpdateIndicatorPreview then self.optionsFrame.UpdateIndicatorPreview() end
	end
	self:RaiseColorPicker()
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.func = function()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		ApplyColor(r, g, b)
	end
	ColorPickerFrame.opacityFunc = ColorPickerFrame.func
	ColorPickerFrame.cancelFunc = function()
		ApplyColor(oldColor[1], oldColor[2], oldColor[3])
	end
	if ColorPickerOkayButton then ColorPickerOkayButton:Enable() end
	if ColorPickerCancelButton then ColorPickerCancelButton:Enable() end
	ColorPickerFrame:SetColorRGB(oldColor[1], oldColor[2], oldColor[3])
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
	if ColorPickerFrame._cellRaisePickerButtons then ColorPickerFrame._cellRaisePickerButtons(ColorPickerFrame) end
end

function Cell:SetMinimapButtonShown(shown)
	NotCellVanillaDB = GetCellSettingsDB()
	local minimapDB = GetMinimapButtonDB()
	minimapDB.shown = shown and true or false
	SaveCellSettingsDB()
	if not self.minimapButton and minimapDB.shown then self:CreateMinimapButton() end
	if self.minimapButton then
		if minimapDB.shown then self.minimapButton:Show() else self.minimapButton:Hide() end
	end
	self:RefreshOptionsMenu()
end

function Cell:CreateMinimapButton()
	if self.minimapButton or not Minimap then return end
	local minimapDB = GetMinimapButtonDB()
	-- Minimap-button collectors scan Minimap's children, so parent it there.
	local button = CreateFrame("Button", "NotCellMinimapButton", Minimap)
	button:SetWidth(31)
	button:SetHeight(31)
	button:EnableMouse(true)
	button:SetToplevel(true)
	button:SetFrameStrata("HIGH")
	button:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0) + 20)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetTexture("Interface\\AddOns\\NotCell\\Media\\icon")
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
	local function UpdatePosition()
		local buttonDB = GetMinimapButtonDB()
		local angle = math.rad(buttonDB.angle or 220)
		button:ClearAllPoints()
		button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
	end
	button.UpdateCellPosition = UpdatePosition
	button:SetScript("OnDragStart", function()
		button:SetScript("OnUpdate", function()
			local centerX, centerY = Minimap:GetCenter()
			local scale = Minimap:GetEffectiveScale()
			local cursorX, cursorY = GetCursorPosition()
			cursorX, cursorY = cursorX / scale, cursorY / scale
			GetMinimapButtonDB().angle = math.floor(math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) + 0.5)
			UpdatePosition()
		end)
	end)
	button:SetScript("OnDragStop", function()
		button:SetScript("OnUpdate", nil)
		SaveCellSettingsDB()
	end)
	local function HandleMinimapClick(self, mouseButton)
		if mouseButton == "LeftButton" or mouseButton == "RightButton" then
			local now=GetTime and GetTime() or 0
			if self._lastCellOptionsToggle and now-self._lastCellOptionsToggle<0.15 then return end
			self._lastCellOptionsToggle=now
			local options=Cell:CreateOptionsMenu()
			if options:IsShown() then options:Hide() else options:Show() end
		end
	end
	button:SetScript("OnClick", HandleMinimapClick)
	button:SetScript("OnMouseUp", HandleMinimapClick)
	local tooltip = CreateFrame("GameTooltip", "NotCellMinimapTooltip", UIParent, "GameTooltipTemplate")
	local function ShowCellTooltip(self)
		tooltip:ClearLines()
		tooltip:SetOwner(self, "ANCHOR_LEFT")
		tooltip:AddLine("NotCell")
		tooltip:AddLine("Left- or right-click to open options", 1, 1, 1)
		tooltip:Show()
	end
	local function HideCellTooltip() tooltip:Hide() end
	Cell.minimapTooltip = tooltip
	if button.HookScript then
		button:HookScript("OnEnter", ShowCellTooltip)
		button:HookScript("OnLeave", HideCellTooltip)
	else
		button:SetScript("OnEnter", ShowCellTooltip)
		button:SetScript("OnLeave", HideCellTooltip)
	end
	self.minimapButton = button
	UpdatePosition()
	if minimapDB.shown then button:Show() else button:Hide() end
end

local function SetHealthColor(button, unit, classToken, healthFraction)
	local alpha = math.max(0, math.min(0.95, (tonumber(Cell.healthColorAlpha) or 95) / 100))
	if Cell.healthColorMode == "value" then
		local fraction = math.max(0, math.min(1, tonumber(healthFraction) or 1))
		local red, green
		if fraction < 0.5 then red, green = 1, fraction * 2 else red, green = (1 - fraction) * 2, 1 end
		button.health:SetStatusBarColor(red, green, 0, alpha)
		return
	end
	if Cell.healthColorMode == "class" then
		if not classToken and unit and UnitClass then
			local _, token = UnitClass(unit)
			classToken = token
		end
		local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
		if color then
			button.health:SetStatusBarColor(color.r, color.g, color.b, alpha)
			return
		end
	end
	local color = Cell.customHealthColor
	button.health:SetStatusBarColor(color[1], color[2], color[3], alpha)
end

local function SetPowerColor(button, unit, powerType)
	local color
	if Cell.powerColorMode == "custom" then color = Cell.powerBarCustomColor
	elseif Cell.powerColorMode == "class" then
		local classToken = button.classToken
		if not classToken and unit and UnitClass then local _, token = UnitClass(unit); classToken = token end
		local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
		if classColor then color = {classColor.r, classColor.g, classColor.b} end
	end
	color = color or powerColors[powerType] or powerColors[0]
	button.power:SetStatusBarColor(color[1], color[2], color[3], math.max(0, math.min(0.95, (tonumber(Cell.powerColorAlpha) or 95) / 100)))
end

local function GetHealthLossColor(classToken)
	if Cell.healthLossColorMode == "custom" then return Cell.healthLossCustomColor end
	if Cell.healthLossColorMode == "classDark" then return {0.88, 0.28, 0.28} end
	return {0.62, 0.08, 0.08}
end

local function SetHealthLossColor(button, classToken)
	local color = GetHealthLossColor(classToken)
	button.healthBackground:SetTexture(color[1], color[2], color[3], math.max(0, math.min(0.95, (tonumber(Cell.healthLossAlpha) or 95) / 100)))
end

local function SetBarTexture(bar, texturePath)
	if not bar then return end
	if bar.SetStatusBarTexture then bar:SetStatusBarTexture(texturePath) end
	-- Some Vanilla-derived clients keep a separate fill texture region after the
	-- statusbar texture is initialized. Update that region as well so runtime
	-- appearance changes take effect without recreating the frame.
	if bar.GetStatusBarTexture then
		local fill = bar:GetStatusBarTexture()
		if (type(fill) == "table" or type(fill) == "userdata") and fill.SetTexture then fill:SetTexture(texturePath) end
	end
end

function Cell:ApplyPreviewAppearance(preview)
	if not preview or not preview.health then return end
	local classToken
	if UnitClass then local _, token=UnitClass("player"); classToken=token end
	local texture = self.unitTexture or "Interface\\Buttons\\WHITE8X8"
	SetBarTexture(preview.health, texture)
	SetBarTexture(preview.power, texture)
	SetHealthColor({health=preview.health},"player",classToken,preview.health:GetValue() or 1)
	if preview.power then SetPowerColor({classToken=classToken,power=preview.power},"player",UnitPowerType and UnitPowerType("player") or 0) end
	local lossColor=GetHealthLossColor(classToken)
	if preview.healthLoss then preview.healthLoss:SetTexture(lossColor[1],lossColor[2],lossColor[3],math.max(0,math.min(.95,(tonumber(self.healthLossAlpha) or 95)/100))) end
	if preview.background then preview.background:SetTexture(.08,.08,.08,math.max(0,math.min(.95,(tonumber(self.backgroundAlpha) or 95)/100))) end
end

local function ApplyBorder(edges, color, shown)
	for i = 1, table.getn(edges or {}) do
		local edge = edges[i]
		if shown then edge:SetVertexColor(color[1], color[2], color[3], 0.95); edge:Show() else edge:Hide() end
	end
end

local function UpdateFrameHighlights(button, unit, mouseover)
	local targeted = unit and UnitIsUnit and UnitIsUnit(unit, "target")
	ApplyBorder(button.targetHighlightEdges, Cell.targetHighlightColor, Cell.targetHighlightEnabled and targeted)
	local tint = button.mouseoverHighlightTint
	if tint then
		if Cell.mouseoverHighlightEnabled and mouseover then
			local color = Cell.mouseoverHighlightColor or {0.15, 0.55, 1}
			tint:SetVertexColor(color[1], color[2], color[3], 0.08)
			tint:Show()
		else
			tint:Hide()
		end
	end
end

-- HealComm 1.0 compatibility adapter. Heal prediction below prefers the
-- client API, then calls this small name-based shim; removing this adapter and
-- its TOC libraries cleanly disables HealComm without touching frame bars.
local LegacyHealComm
local function RefreshLegacyHealComm()
	if LegacyHealComm or not AceLibrary or type(AceLibrary.HasInstance) ~= "function" or not AceLibrary:HasInstance("HealComm-1.0") then return end
	local ok, library = pcall(AceLibrary, "HealComm-1.0")
	if ok and type(library) == "table" and type(library.getHeal) == "function" then LegacyHealComm = library end
end
RefreshLegacyHealComm()
local function UpdateHealPrediction(button, unit, current, maximum)
	local bar = button.healPrediction
	if not bar then return end
	if not Cell.healPredictionEnabled or not unit or not maximum or maximum <= 0 or (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) then bar:Hide(); return end
	local healthWidth, healthHeight = button.health:GetWidth(), button.health:GetHeight()
	local healthFraction = math.max(0, math.min(1, current / maximum))
	if healthWidth <= 0 or healthHeight <= 0 then bar:Hide(); return end
	local incoming = 0
	local apiIncoming = UnitGetIncomingHeals and tonumber(UnitGetIncomingHeals(unit))
	if apiIncoming ~= nil then
		incoming = math.max(0, apiIncoming)
	end
	if incoming <= 0 and LegacyHealComm and UnitName then
		local name = UnitName(unit)
		if name then
			local ok, legacyIncoming = pcall(LegacyHealComm.getHeal, LegacyHealComm, name)
			if ok then incoming = math.max(incoming, tonumber(legacyIncoming) or 0) end
		end
	end
	local healFraction = math.max(0, math.min(1 - healthFraction, incoming / maximum))
	if healFraction > 0 then
		local color = Cell.healPredictionColor or {0.20, 1.00, 0.35}
		bar:SetStatusBarColor(color[1], color[2], color[3], 0.75)
		bar:ClearAllPoints()
		if button.healthOrientation == "VERTICAL" then
			bar:SetOrientation("VERTICAL")
			bar:SetPoint("TOPLEFT", button.health, "TOPLEFT", 0, -healthHeight * (1 - healthFraction - healFraction))
			bar:SetPoint("BOTTOMRIGHT", button.health, "BOTTOMRIGHT", 0, healthHeight * healthFraction)
		else
			bar:SetOrientation("HORIZONTAL")
			bar:SetPoint("TOPLEFT", button.health, "TOPLEFT", healthWidth * healthFraction, 0)
			bar:SetPoint("BOTTOMRIGHT", button.health, "BOTTOMRIGHT", -healthWidth * (1 - healthFraction - healFraction), 0)
		end
		bar:SetMinMaxValues(0, 1); bar:SetValue(1); bar:Show()
	else bar:Hide() end
end

function Cell:ApplyAppearanceSettings()
	local texture = self.unitTexture or "Interface\\Buttons\\WHITE8X8"
	local backgroundAlpha = math.max(0, math.min(0.95, (tonumber(self.backgroundAlpha) or 95) / 100))
	for i = 1, table.getn(self.buttons or {}) do
		local button = self.buttons[i]
		if button then
			-- The backdrop texture is already tinted by SetTexture at creation.
			-- SetVertexColor multiplies that tint a second time and darkens it to
			-- near black as the alpha approaches its maximum.
			if button.backdrop then button.backdrop:SetTexture(0.08, 0.08, 0.08, backgroundAlpha) end
			if button.powerBackground then button.powerBackground:SetTexture(0.18, 0.18, 0.18, backgroundAlpha) end
			SetHealthLossColor(button, button.classToken)
		end
	end
	self:UpdateFrames()
	-- Reapply after UpdateFrames, which may refresh/recreate unit buttons while
	-- processing the selected layout.
	for i = 1, table.getn(self.buttons or {}) do
		local button = self.buttons[i]
		if button then
			SetBarTexture(button.health, texture)
			SetBarTexture(button.power, texture)
			SetBarTexture(button.healPrediction, texture)
		end
	end
	if self.optionsFrame and self.optionsFrame.UpdateIndicatorPreview then self.optionsFrame.UpdateIndicatorPreview() end
end

local function SetAnimatedHealthValue(button, value, forceInstant)
	local bar = button.health
	local mode = Cell.barAnimationMode or "smooth"
	local previousHealth = button._cellLastHealthValue
	button._cellLastHealthValue = value
	if button.damageFlash and button.damageFlashDriver then
		if not forceInstant and mode == "flash" and not button.preview and previousHealth and value < previousHealth then
			local lost=previousHealth-value
			button.damageFlash:ClearAllPoints()
			if button.healthOrientation == "VERTICAL" then
				local height=bar:GetHeight() or 0
				button.damageFlash:SetPoint("TOPLEFT",bar,"TOPLEFT",0,-height*(1-previousHealth))
				button.damageFlash:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",0,height*value)
			else
				local width=bar:GetWidth() or 0
				button.damageFlash:SetPoint("TOPLEFT",bar,"TOPLEFT",width*value,0)
				button.damageFlash:SetPoint("BOTTOMLEFT",bar,"BOTTOMLEFT",width*value,0)
				button.damageFlash:SetWidth(math.max(1,width*lost))
			end
			button.damageFlash:SetAlpha(0.70); button.damageFlash:Show()
			button.damageFlashRemaining=0.30; button.damageFlashDriver:Show()
		else
			button.damageFlash:SetAlpha(0); button.damageFlash:Hide(); button.damageFlashDriver:Hide()
		end
	end
	local duration = (mode ~= "smooth" or forceInstant) and 0 or 0.20
	if duration <= 0 or not bar:GetValue() then
		bar:SetScript("OnUpdate", nil); bar._cellAnimation = nil; bar:SetValue(value); return
	end
	local activeAnimation = bar._cellAnimation
	if activeAnimation and activeAnimation.to == value then return end
	local from = bar:GetValue()
	if math.abs(from - value) < 0.001 then return end
	bar._cellAnimation = {from = from, to = value, elapsed = 0, duration = duration}
	bar:SetScript("OnUpdate", function(self, elapsed)
		local animation = self._cellAnimation
		if not animation then self:SetScript("OnUpdate", nil); return end
		animation.elapsed = animation.elapsed + elapsed
		local progress = math.min(1, animation.elapsed / animation.duration)
		self:SetValue(animation.from + (animation.to - animation.from) * progress)
		if progress >= 1 then self:SetValue(animation.to); self._cellAnimation = nil; self:SetScript("OnUpdate", nil) end
	end)
end

local function UpdatePower(button, unit)
	local current = UnitPower and UnitPower(unit) or UnitMana and UnitMana(unit) or 0
	local maximum = UnitPowerMax and UnitPowerMax(unit) or UnitManaMax and UnitManaMax(unit) or 0
	local powerType = UnitPowerType and UnitPowerType(unit) or 0
	SetPowerColor(button, unit, powerType)
	if maximum > 0 then
		button.power:SetValue(current / maximum)
	else
		button.power:SetValue(0)
	end
	return current, maximum, powerType
end

local function GetUnitList()
	local units = {}
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then
		if not Cell.showParty then return units end
		for i = 1, 40 do
			units[i] = "raid" .. i
		end
	elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
		if Cell.showParty then
			units[1] = "player"
			for i = 1, 4 do units[i + 1] = "party" .. i end
		elseif Cell.showSolo then
			units[1] = "player"
		end
	elseif Cell.showSolo then
		units[1] = "player"
	end
	return units
end

local function SetNameColor(button, unit, classToken)
	local layoutSettings = GetDisplayedIndicatorSettings and GetDisplayedIndicatorSettings("nameText")
	if layoutSettings and layoutSettings.colorMode == "custom" and layoutSettings.color then
		local color = layoutSettings.color
		button.name:SetTextColor(color[1], color[2], color[3])
		return
	end
	if layoutSettings and layoutSettings.colorMode == "class" then
		if not classToken and unit and UnitClass then local _, token = UnitClass(unit); classToken = token end
		local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
		if classColor then button.name:SetTextColor(classColor.r,classColor.g,classColor.b) else button.name:SetTextColor(1,1,1) end
		return
	end
	if Cell.nameColorMode == "custom" then
		local color = Cell.nameCustomColor
		button.name:SetTextColor(color[1], color[2], color[3])
		return
	end
	if not classToken and unit then
		local _, token = UnitClass(unit)
		classToken = token
	end
	local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
	if color then
		button.name:SetTextColor(color.r, color.g, color.b)
	else
		button.name:SetTextColor(1, 1, 1)
	end
end

local function SetStyledTextColor(fontString, colorMode, customColor, classToken, powerType, healthFraction)
	if colorMode == "power" then
		local color = powerColors[powerType] or powerColors[0]
		fontString:SetTextColor(color[1], color[2], color[3])
		return
	end
	if colorMode == "value" then
		local fraction = math.max(0, math.min(1, tonumber(healthFraction) or 1))
		local red, green
		if fraction < 0.5 then red, green = 1, fraction * 2 else red, green = (1 - fraction) * 2, 1 end
		fontString:SetTextColor(red, green, 0)
		return
	end
	if colorMode == "class" then
		local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
		if color then
			fontString:SetTextColor(color.r, color.g, color.b)
			return
		end
	end
	fontString:SetTextColor(customColor[1], customColor[2], customColor[3])
end

local function SetHealthValueText(button, current, maximum)
	local settings = GetDisplayedIndicatorSettings("healthText")
	local visible = true
	local format = settings and settings.format or Cell.healthValueFormat
	if not visible or not maximum or maximum <= 0 then
		button.healthText:SetText("")
	elseif format == "absolute" then
		button.healthText:SetText(math.floor(current) .. "/" .. math.floor(maximum))
	else
		button.healthText:SetText(math.floor(current * 100 / maximum) .. (settings and settings.showPercentSign == false and "" or "%"))
	end
end

local function SetPowerValueText(button, current, maximum)
	local settings = GetDisplayedIndicatorSettings("powerText")
	local visible = true
	local format = settings and settings.format or Cell.powerValueFormat
	if not visible or not maximum or maximum <= 0 then
		button.powerText:SetText("")
	elseif format == "absolute" then
		button.powerText:SetText(math.floor(current) .. "/" .. math.floor(maximum))
	else
		button.powerText:SetText(math.floor(current * 100 / maximum) .. (settings and settings.showPercentSign == false and "" or "%"))
	end
end

local function SetFrameStatus(button, status)
	local alpha = math.max(0, math.min(0.95, (tonumber(Cell.healthColorAlpha) or 95) / 100))
	if status == "offline" then
		button.statusText:SetText("OFFLINE")
		button.statusText:SetTextColor(1.00, 0.45, 0.20)
		button.health:SetStatusBarColor(0.38, 0.38, 0.38, alpha)
	elseif status == "ghost" then
		button.statusText:SetText("GHOST")
		button.statusText:SetTextColor(0.75, 0.62, 1.00)
		button.health:SetStatusBarColor(0.46, 0.40, 0.55, alpha)
	elseif status == "dead" then
		button.statusText:SetText("DEAD")
		button.statusText:SetTextColor(1.00, 0.78, 0.30)
		if Cell.deadBackdropEnabled then
			button.health:SetStatusBarColor(Cell.customDeadBackdrop[1], Cell.customDeadBackdrop[2], Cell.customDeadBackdrop[3], alpha)
		else
			button.health:SetStatusBarColor(0.42, 0.42, 0.42, alpha)
		end
	else
		button.statusText:SetText("")
		button.statusText:Hide()
		return
	end
	local statusSettings = GetDisplayedIndicatorSettings("statusText")
	if statusSettings and statusSettings.colorMode == "custom" and statusSettings.color then
		button.statusText:SetTextColor(statusSettings.color[1],statusSettings.color[2],statusSettings.color[3])
	elseif statusSettings and statusSettings.colorMode == "class" then
		local color=button.classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[button.classToken]
		if color then button.statusText:SetTextColor(color.r,color.g,color.b) end
	end
	if statusSettings and statusSettings.enabled == false then button.statusText:Hide() else button.statusText:Show() end
	button.healthText:SetText("")
	button.powerText:SetText("")
end

local debuffTypeColors = {
	Magic = {0.20, 0.60, 1.00},
	Curse = {0.60, 0.00, 1.00},
	Disease = {0.60, 0.40, 0.00},
	Poison = {0.00, 0.60, 0.00},
}

local function IsDebuffAllowed(spellID)
	if Cell.debuffFilterMode == "whitelist" then
		return spellID and Cell.debuffFilterIDs[tonumber(spellID)] or false
	elseif Cell.debuffFilterMode == "blacklist" and spellID then
		return not Cell.debuffFilterIDs[tonumber(spellID)]
	end
	return true
end

local function SetDebuffIcon(button, texture, count, dispelName, spellID)
	local segments = button.debuffFillSegments
	for i = 1, table.getn(segments) do segments[i]:Hide() end
	local settings = GetDisplayedIndicatorSettings("debuffs") or {}
	if settings.enabled == false then
		button.debuffIcon:Hide()
		button.debuffCount:SetText("")
		button.debuffBorderFrame:Hide()
		return
	end
	if not texture or not IsDebuffAllowed(spellID) then
		button.debuffIcon:Hide()
		button.debuffCount:SetText("")
		button.debuffBorderFrame:Hide()
		return
	end
	button.debuffIcon:SetTexture(texture)
	if Cell.showDebuffIcons then
		button.debuffIcon:Show()
		button.debuffCount:SetText(count and count > 1 and tostring(count) or "")
	else
		button.debuffIcon:Hide()
		button.debuffCount:SetText("")
	end
	local tint = debuffTypeColors[dispelName]
	local gradientAlpha = math.max(0, math.min(1, (tonumber(Cell.debuffFillAlpha) or 65) / 100))
	local borderSize = math.max(1, math.min(8, tonumber(Cell.debuffBorderSize) or 2))
	local borderAlpha = borderSize <= 3 and 0.95 or math.max(0.80, 0.95 - (borderSize - 3) * 0.0375)
	if Cell.debuffBorderEnabled and tint then
		if button.debuffBorderFrame.borderSize ~= borderSize then
			button.debuffBorderFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = borderSize})
			button.debuffBorderFrame:SetBackdropColor(0, 0, 0, 0)
			button.debuffBorderFrame.borderSize = borderSize
		end
		button.debuffBorderFrame:SetBackdropBorderColor(tint[1], tint[2], tint[3], borderAlpha)
		button.debuffBorderFrame:Show()
	else
		button.debuffBorderFrame:Hide()
	end
	if Cell.debuffFillMode == "solid" and tint then
		button.health:SetStatusBarColor(tint[1], tint[2], tint[3], 1)
	end
	if Cell.debuffFillMode == "gradient" and tint then
		local width, height = button.health:GetWidth(), button.health:GetHeight()
		local fraction = math.max(0.10, math.min(1, (tonumber(Cell.debuffFillAmount) or 50) / 100))
		local vertical = Cell.debuffFillDirection == "down-to-up" or Cell.debuffFillDirection == "up-to-down"
		-- Cover a portion of the frame, not a portion of the current HP fill.
		local extent = vertical and height * fraction or width * fraction
		local segmentExtent = extent / table.getn(segments)
		for i = 1, table.getn(segments) do
			local segment = segments[i]
			local x, y, segmentWidth, segmentHeight
			if vertical then
				x, segmentWidth, segmentHeight = 0, width, segmentExtent
				if Cell.debuffFillDirection == "down-to-up" then
					y = height - i * segmentExtent
				else
					y = (i - 1) * segmentExtent
				end
			else
				y, segmentHeight, segmentWidth = 0, height, segmentExtent
				if Cell.debuffFillDirection == "right-to-left" then
					x = width - i * segmentExtent
				else
					x = (i - 1) * segmentExtent
				end
			end
			segment:ClearAllPoints()
			segment:SetPoint("TOPLEFT", button.health, "TOPLEFT", x, -y)
			segment:SetPoint("BOTTOMRIGHT", button.health, "TOPLEFT", x + segmentWidth, -(y + segmentHeight))
			segment:SetTexture("Interface\\Buttons\\WHITE8X8")
			segment:SetVertexColor(tint[1], tint[2], tint[3])
			segment:SetAlpha(gradientAlpha * (0.08 + 0.62 * (i - 1) / math.max(1, table.getn(segments) - 1)))
			if extent > 0 and width > 0 and height > 0 then segment:Show() end
		end
	end
end

local CanDispelType
local function GetFirstDebuff(unit)
	local debuffSettings = GetDisplayedIndicatorSettings("debuffs")
	local onlyDispellable = debuffSettings and debuffSettings.onlyDispellable
	if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
		for index = 1, 16 do
			local aura = C_UnitAuras.GetDebuffDataByIndex(unit, index)
			if not aura then break end
			if IsDebuffAllowed(aura.spellId) and (not onlyDispellable or (CanDispelType and CanDispelType(aura.dispelName))) then
				return aura.icon, aura.applications, aura.dispelName, aura.spellId
			end
		end
		return nil
	end
	if not UnitDebuff then return nil end
	for index = 1, 16 do
		local texture, count, dispelName, duration, expirationTime, caster, isStealable, shouldConsolidate, spellID = UnitDebuff(unit, index)
		if not texture then break end
		if IsDebuffAllowed(spellID) and (not onlyDispellable or (CanDispelType and CanDispelType(dispelName))) then return texture, count, dispelName, spellID end
	end
end

local auraPlayerClass
local function GetAuraPlayerClass()
	if not auraPlayerClass and UnitClass then local _, token=UnitClass("player"); auraPlayerClass=token end
	return auraPlayerClass
end
local function IsAuraConfigured(settings, auraName, spellID, icon)
	local matches = false
	local playerClass=GetAuraPlayerClass()
	for _, entry in ipairs(settings.spells or {}) do
		local relevant = settings.onlyCurrentClass == false or not entry.class or entry.class == playerClass
		if relevant then
			if entry.id and spellID and tonumber(entry.id) == tonumber(spellID) then matches = true end
			if entry.name and auraName and string.lower(entry.name) == string.lower(auraName) then matches = true end
			if entry.icon and icon and entry.icon == icon then matches = true end
		end
	end
	if settings.filterMode == "whitelist" then return matches end
	return not matches
end

local dispelSpellIDs = {
	PRIEST={magic={527},disease={528,552}}, MAGE={curse={475}},
	DRUID={poison={8946,2893},curse={2782}}, PALADIN={magic={4987},poison={1152,4987},disease={1152,4987}},
	SHAMAN={disease={2870},poison={526}},
}
local function PlayerKnowsSpell(id)
	if IsSpellKnown and IsSpellKnown(id) then return true end
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	if not (GetSpellInfo and GetSpellName and GetNumSpellTabs and GetSpellTabInfo) then return false end
	local expected=GetSpellInfo(id)
	if not expected then return false end
	for tab=1,GetNumSpellTabs() do
		local _,_,offset,count=GetSpellTabInfo(tab)
		for slot=(offset or 0)+1,(offset or 0)+(count or 0) do
			if GetSpellName(slot,BOOKTYPE_SPELL)==expected then return true end
		end
	end
	return false
end
CanDispelType = function(dispelType)
	if not dispelType then return false end
	local classToken=GetAuraPlayerClass()
	local classSpells=dispelSpellIDs[classToken]
	local candidates=classSpells and classSpells[string.lower(dispelType)]
	if not candidates then return false end
	for _,id in ipairs(candidates) do if PlayerKnowsSpell(id) then return true end end
	return false
end

local function GetConfiguredAuras(unit, auraType, settings)
	local found = {}
	local isBuff = auraType == "buffs" or auraType == "healerBuffs"
	local healerSettings = auraType == "buffs" and GetDisplayedIndicatorSettings("healerBuffs") or nil
	local api = C_UnitAuras and (isBuff and C_UnitAuras.GetBuffDataByIndex or C_UnitAuras.GetDebuffDataByIndex)
	for index = 1, 40 do
		local icon, count, dispelName, spellID, name, caster
		if api then
			local aura = api(unit, index)
			if not aura then break end
			icon, count, dispelName, spellID, name = aura.icon, aura.applications, aura.dispelName, aura.spellId, aura.name
			caster = aura.sourceUnit or aura.casterUnit
		else
			local getter = isBuff and UnitBuff or UnitDebuff
			if not getter then break end
			local duration, expirationTime, isStealable, shouldConsolidate
			icon, count, dispelName, duration, expirationTime, caster, isStealable, shouldConsolidate, spellID = getter(unit, index)
			if not icon then break end
		end
		if not name and spellID and GetSpellInfo then name = GetSpellInfo(spellID) end
		local casterMatches = not settings.castByPlayer or caster=="player" or (caster and UnitIsUnit and UnitIsUnit(caster,"player"))
		local shownByHealers = healerSettings and healerSettings.enabled ~= false and healerSettings.filterMode == "whitelist"
			and IsAuraConfigured(healerSettings, name, spellID, icon)
		local dispelMatches = auraType ~= "debuffs" or not settings.onlyDispellable or CanDispelType(dispelName)
		if icon and casterMatches and dispelMatches and not shownByHealers and IsAuraConfigured(settings, name, spellID, icon) then
			found[table.getn(found)+1] = {icon=icon,count=count,dispelName=dispelName,spellID=spellID,name=name}
			if table.getn(found) >= (tonumber(settings.maxIcons) or 4) then break end
		end
	end
	return found
end

-- Vanilla missing-buff indicators are separate from the normal Buffs indicator.
-- For totems, auraIDs are the effect a party member receives; learned contains the
-- summon spell IDs the shaman actually learns (the two IDs are not interchangeable).
local missingBuffCatalog = {
	{class="MAGE", ids={1459,23028}},
	{class="PRIEST", ids={1243,21562}}, {class="PRIEST", ids={14752,27681}},
	{class="PRIEST", ids={976,27683}}, {class="PRIEST", ids={6346}}, {class="PRIEST", ids={10060}},
	{class="DRUID", ids={1126,21849}}, {class="DRUID", ids={467}},
	{class="PALADIN", ids={20217,25898}, blessing=true}, {class="PALADIN", ids={19740,25782}, blessing=true},
	{class="PALADIN", ids={19742,25894}, blessing=true}, {class="PALADIN", ids={1038,25895}, blessing=true},
	{class="PALADIN", ids={19977,25890}, blessing=true}, {class="PALADIN", ids={20911,25899}, blessing=true},
	{class="PALADIN", ids={465}}, {class="PALADIN", ids={7294}}, {class="PALADIN", ids={19746}},
	{class="PALADIN", ids={8185}}, {class="PALADIN", ids={19891}}, {class="PALADIN", ids={19888}}, {class="PALADIN", ids={19898}},
	{class="SHAMAN", ids={8076}, learned={8075}}, {class="SHAMAN", ids={8072}, learned={8071}},
	{class="SHAMAN", ids={8836}, learned={8835}}, {class="SHAMAN", ids={5677}, learned={5675}},
	{class="SHAMAN", ids={5672}, learned={5394}}, {class="SHAMAN", ids={25909}, learned={25908}},
	{class="SHAMAN", ids={10596}, learned={10595}}, {class="SHAMAN", ids={8185}, learned={8184}},
	{class="SHAMAN", ids={8182}, learned={8181}}, {class="SHAMAN", ids={8177}},
	{class="SHAMAN", ids={16191}, learned={16190}},
	{class="HUNTER", ids={19506}}, {class="HUNTER", ids={13165}}, {class="HUNTER", ids={13163}},
	{class="HUNTER", ids={20043}}, {class="HUNTER", ids={5118}}, {class="HUNTER", ids={13159}}, {class="HUNTER", ids={13161}},
}
local missingBuffClasses={}
for _,entry in ipairs(missingBuffCatalog) do missingBuffClasses[entry.class]=true end
local missingBuffPlayerClass
if UnitClass then local _, class = UnitClass("player"); missingBuffPlayerClass = class end
local knownMissingBuffSpells = {}
local missingAuraCache={}
local missingBuffBlesserCount
local function RefreshMissingBuffSpells()
	for id in pairs(knownMissingBuffSpells) do knownMissingBuffSpells[id]=nil end
	for unit in pairs(missingAuraCache) do missingAuraCache[unit]=nil end
	for _,entry in ipairs(missingBuffCatalog) do
		for _,id in ipairs(entry.learned or entry.ids) do
			local known=IsSpellKnown and IsSpellKnown(id) or (IsPlayerSpell and IsPlayerSpell(id))
			if not known and GetSpellName and GetSpellInfo and GetNumSpellTabs and GetSpellTabInfo then
				local expected=GetSpellInfo(id)
				if expected then
					for tab=1,GetNumSpellTabs() do
						local _,_,offset,numSpells=GetSpellTabInfo(tab)
						for slot=(offset or 0)+1,(offset or 0)+(numSpells or 0) do
							local name=GetSpellName(slot,BOOKTYPE_SPELL)
						if name==expected then known=true; break end
						end
						if known then break end
					end
				end
			end
			if known then knownMissingBuffSpells[id]=true end
		end
	end
end
local missingBuffSpellEvents=CreateFrame("Frame")
missingBuffSpellEvents:RegisterEvent("PLAYER_LOGIN")
missingBuffSpellEvents:RegisterEvent("SPELLS_CHANGED")
missingBuffSpellEvents:SetScript("OnEvent",function()
	RefreshMissingBuffSpells()
	if Cell and Cell.container then Cell:UpdateFrames() end
end)
local function IsMissingBuffKnown(id)
	return knownMissingBuffSpells[id]
end
local function GetMissingBuffBlesserCount()
	if missingBuffBlesserCount~=nil then return missingBuffBlesserCount end
	local count=0
	local function countUnit(unit)
		if UnitExists and UnitExists(unit) and UnitClass then local _,class=UnitClass(unit); if class=="PALADIN" then count=count+1 end end
	end
	if GetNumRaidMembers and GetNumRaidMembers()>0 then
		for i=1,GetNumRaidMembers() do countUnit("raid"..i) end
	elseif GetNumPartyMembers and GetNumPartyMembers()>0 then
		countUnit("player")
		for i=1,GetNumPartyMembers() do countUnit("party"..i) end
	else
		countUnit("player")
	end
	missingBuffBlesserCount=count
	return count
end
local function GetMissingBuffAuras(unit, settings)
	local onlyKnown=settings.onlyKnown~=false
	-- Match upstream's class-only option: classes with supported provider spells
	-- get their own list; classes without one retain the group-wide view.
	local onlyClass=settings.onlyCurrentClass~=false and missingBuffClasses[missingBuffPlayerClass]
	local cacheKey=(onlyClass and "class" or "all")..(onlyKnown and "known" or "any")
	missingAuraCache[unit]=missingAuraCache[unit] or {}
	if missingAuraCache[unit][cacheKey] then return missingAuraCache[unit][cacheKey] end
	local missing, blessingMissing, present, presentIcons = {}, {}, {}, {}
	local activeBlessings=0
	if not UnitBuff then return missing end
	for index=1,40 do
		local texture,_,_,_,_,_,_,_,spellID=UnitBuff(unit,index)
		if not texture then break end
		if spellID then present[tonumber(spellID)]=true end
		presentIcons[texture]=true
	end
	for _,entry in ipairs(missingBuffCatalog) do
		if (not onlyClass or entry.class==missingBuffPlayerClass) then
			local icon, active, learned
			for _,id in ipairs(entry.ids) do
				local name,_,spellIcon
				if GetSpellInfo then name,_,spellIcon=GetSpellInfo(id) end
				if name then
					icon=icon or spellIcon
					if present[id] or (spellIcon and presentIcons[spellIcon]) then active=true end
				end
			end
			for _,id in ipairs(entry.learned or entry.ids) do
				if IsMissingBuffKnown(id) then learned=true end
			end
			if entry.blessing then
				if active then activeBlessings=activeBlessings+1
				elseif icon and (not onlyKnown or learned) then blessingMissing[#blessingMissing+1]={icon=icon} end
			elseif icon and not active and (not onlyKnown or learned) then missing[#missing+1]={icon=icon} end
		end
	end
	local blessingSlots=math.max(0,GetMissingBuffBlesserCount()-activeBlessings)
	for i=1,math.min(blessingSlots,table.getn(blessingMissing)) do missing[#missing+1]=blessingMissing[i] end
	missingAuraCache[unit][cacheKey]=missing
	return missing
end

local function GetAuraIconOffset(settings, index, maxIcons, lines, size)
	local orientation=settings.orientation or "right"
	if orientation=="right-to-left" then orientation="left" end -- saved-setting migration safety
	if orientation=="left-to-right" then orientation="right" end
	if orientation~="right" and orientation~="left" and orientation~="up" and orientation~="down" then orientation="right" end
	local anchor=settings.anchor or "CENTER"
	local iconsPerLine=math.max(1,math.ceil(maxIcons/math.max(1,lines)))
	local step=(index-1)%iconsPerLine
	local line=math.floor((index-1)/iconsPerLine)
	local x=(tonumber(settings.x) or 0)
	local y=(tonumber(settings.y) or 0)
	local gap=size+2
	local inwardX=string.find(anchor,"RIGHT",1,true) and -1 or 1
	local inwardY=string.find(anchor,"TOP",1,true) and -1 or (string.find(anchor,"BOTTOM",1,true) and 1 or -1)
	if orientation=="left" or orientation=="right" then
		local direction=orientation=="left" and -1 or 1
		return x+direction*step*gap, y+inwardY*line*gap
	else
		local direction=orientation=="up" and 1 or -1
		return x+inwardX*line*gap, y+direction*step*gap
	end
end

local function UpdateAuraIcons(button, unit, auraType, status)
	local settings = GetDisplayedIndicatorSettings(auraType)
	local icons = button.auraIcons and button.auraIcons[auraType]
	if not icons then return end
	if not settings or settings.enabled == false or (auraType == "debuffs" and not Cell.showDebuffIcons) or (auraType == "missingBuffs" and status == "offline") then
		for _, icon in ipairs(icons) do
			icon:Hide()
			if icon.missingBuffGlow then icon.missingBuffGlow:Hide() end
		end
		return
	end
	local iconLimit=auraType=="missingBuffs" and 3 or (auraType=="healerBuffs" and 5 or 20)
	local maxIcons = math.max(1,math.min(iconLimit,tonumber(settings.maxIcons) or 4))
	local rows = math.max(1,math.min(8,tonumber(settings.rows) or 1))
	local size = math.max(8,math.min(48,tonumber(settings.iconSize or settings.size) or 16))
	local anchor = settings.anchor or "CENTER"
	local auras = auraType=="missingBuffs" and GetMissingBuffAuras(unit,settings) or GetConfiguredAuras(unit,auraType,settings)
	for i, icon in ipairs(icons) do
		local aura = auras[i]
		if aura and i <= maxIcons then
			local offsetX,offsetY=GetAuraIconOffset(settings,i,maxIcons,rows,size)
			icon:SetWidth(size); icon:SetHeight(size); icon:ClearAllPoints()
			icon:SetPoint(anchor,button,anchor,offsetX,offsetY)
			icon.texture:SetTexture(aura.icon); icon.count:SetText(aura.count and aura.count>1 and tostring(aura.count) or ""); icon:Show()
			if icon.missingBuffGlow then icon.missingBuffGlow:Show() end
		else
			icon:Hide()
			if icon.missingBuffGlow then icon.missingBuffGlow:Hide() end
		end
	end
end

local function GetLiveUnitStatus(unit)
	if UnitIsConnected and not UnitIsConnected(unit) then
		return "offline"
	elseif UnitIsGhost and UnitIsGhost(unit) then
		return "ghost"
	elseif UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
		return "dead"
	elseif UnitIsDead and UnitIsDead(unit) then
		return "dead"
	end
end

local function UpdateSimpleIndicators(button, unit, status)
	local icons=button.indicatorIcons or {}
	local role=UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	for key,icon in pairs(icons) do
		local settings=GetDisplayedIndicatorSettings(key) or {}
		local size=math.max(8,math.min(48,tonumber(settings.iconSize or settings.size) or 16))
		local anchor=settings.anchor or "CENTER"
		icon:SetWidth(size); icon:SetHeight(size); icon:ClearAllPoints(); icon:SetPoint(anchor,button,anchor,tonumber(settings.x) or 0,tonumber(settings.y) or 0)
		local visible=settings.enabled~=false
		if key=="statusIcon" then
			visible=visible and status~=nil
			if status=="offline" then icon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
			elseif status=="ghost" then icon:SetTexture("Interface\\Icons\\Spell_Shadow_GhostKey")
			else icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull") end
		elseif key=="roleIcon" then
			visible=visible and role and role~="NONE"
			local roleTextures={TANK="Interface\\AddOns\\NotCell\\Media\\Roles\\Blizzard3_TANK.tga",HEALER="Interface\\AddOns\\NotCell\\Media\\Roles\\Blizzard3_HEALER.tga",DAMAGER="Interface\\AddOns\\NotCell\\Media\\Roles\\Blizzard3_DAMAGER.tga"}
			icon:SetTexture(roleTextures[role] or roleTextures.DAMAGER); icon:SetTexCoord(0,1,0,1)
		elseif key=="leaderIcon" then
			visible=visible and ((UnitIsGroupLeader and UnitIsGroupLeader(unit)) or (UnitIsGroupAssistant and UnitIsGroupAssistant(unit)))
			icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon"); icon:SetTexCoord(0,1,0,1)
		elseif key=="readyCheckIcon" then
			local ready=GetReadyCheckStatus and GetReadyCheckStatus(unit)
			visible=visible and ready~=nil
			local readyTextures={ready="Interface\\AddOns\\NotCell\\Media\\Icons\\readycheck-ready.tga",notready="Interface\\AddOns\\NotCell\\Media\\Icons\\readycheck-notready.tga",waiting="Interface\\AddOns\\NotCell\\Media\\Icons\\readycheck-waiting.tga"}
			icon:SetTexture(readyTextures[ready] or readyTextures.waiting)
		elseif key=="raidIcon" then
			local index=GetRaidTargetIndex and GetRaidTargetIndex(unit)
			visible=visible and index~=nil
			if visible and SetRaidTargetIconTexture then SetRaidTargetIconTexture(icon,index)
			else icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons") end
		end
		if visible then icon:Show() else icon:Hide() end
	end
end

local vanillaUnitMenuDropdown
local function EnsureVanillaUnitMenu()
		if vanillaUnitMenuDropdown or not UIDropDownMenu_Initialize then return end
		vanillaUnitMenuDropdown = CreateFrame("Frame", "NotCellUnitMenuDropDown", UIParent, "UIDropDownMenuTemplate")
		local ok = pcall(UIDropDownMenu_Initialize, vanillaUnitMenuDropdown, function()
			local self = vanillaUnitMenuDropdown
			local menuUnit = self.unit
			if not menuUnit or not UnitExists(menuUnit) then return end
			local menu, name, id
			if UnitIsUnit(menuUnit, "player") then menu = "SELF"
			elseif UnitIsUnit(menuUnit, "pet") then menu = "PET"
			elseif UnitIsPlayer(menuUnit) then
				local raidIndex = UnitInRaid(menuUnit)
				if raidIndex then menu = "RAID_PLAYER"; id = raidIndex + 1; name = GetRaidRosterInfo(id)
				elseif UnitInParty(menuUnit) then menu = "PARTY"
				else menu = "PLAYER" end
			else menu = "TARGET"; name = RAID_TARGET_ICON end
			if menu and UnitPopup_ShowMenu then UnitPopup_ShowMenu(self, menu, menuUnit, name, id) end
		end, "MENU")
		if not ok then vanillaUnitMenuDropdown = nil end
end
local function ShowVanillaUnitMenu(button)
	local unit = button and button:GetAttribute("unit")
	if not unit or not UnitExists or not UnitExists(unit) then return end
	EnsureVanillaUnitMenu()
	if not vanillaUnitMenuDropdown then return end
	HideDropDownMenu(1)
	vanillaUnitMenuDropdown.unit = unit
	ToggleDropDownMenu(1, nil, vanillaUnitMenuDropdown, "cursor", 0, 0)
end

-- Click-cast implementation shared by Cell's secure buttons and Blizzard's
-- compatible unit buttons. Keep the Blizzard adapter below separate so it can
-- be disabled/reverted without changing Cell's own bindings.
local function ClearCellClickCastOverrides(button)
	if not button then return end
	local owner = button._cellKeyOverrideOwner or button
	-- Override bindings belong to their owner. A dedicated owner keeps cleanup
	-- from removing bindings another addon may have attached to Blizzard frames.
	-- Clear the complete set so removed profile keys cannot remain active.
	if ClearOverrideBindings then
		ClearOverrideBindings(owner)
	elseif SetOverrideBinding then
		for i = 1, table.getn(button._cellKeyOverrides or {}) do
			SetOverrideBinding(owner, true, button._cellKeyOverrides[i][1], nil)
		end
	end
end

local function ApplyCellClickCastOverrides(button)
	if not button or not SetOverrideBindingClick then return end
	local owner = button._cellKeyOverrideOwner or button
	for i = 1, table.getn(button._cellKeyOverrides or {}) do
		local binding = button._cellKeyOverrides[i]
		SetOverrideBindingClick(owner, true, binding[1], binding[2])
	end
end

function Cell:ApplyClickCastSettings(button)
	if not button or (InCombatLockdown and InCombatLockdown()) then return false end
	if button.RegisterForClicks then button:RegisterForClicks("AnyUp", "Button4Up", "Button5Up") end
	ClearCellClickCastOverrides(button)
	EnsureVanillaUnitMenu()
	button.menu = ShowVanillaUnitMenu
	Cell.keyboardBindButtons = Cell.keyboardBindButtons or {}
	if button._cellVanillaMouseAttributes then
		for i = 1, table.getn(button._cellVanillaMouseAttributes) do button:SetAttribute(button._cellVanillaMouseAttributes[i], nil) end
	end
	button._cellVanillaMouseAttributes = {}
	button:SetAttribute("type1", "target")
	button:SetAttribute("type2", "menu")
	for buttonNumber = 3, 5 do button:SetAttribute("type" .. buttonNumber, nil) end
	for buttonNumber = 1, 5 do
		button:SetAttribute("spell" .. buttonNumber, nil)
		button:SetAttribute("macrotext" .. buttonNumber, nil)
	end
	local modifierCombos = {"shift", "ctrl", "alt", "ctrl-shift", "alt-shift", "alt-ctrl", "alt-ctrl-shift"}
	for _, modifier in ipairs(modifierCombos) do
		for buttonNumber = 1, 5 do
			-- Reserve unbound modifier combos with an empty macro so modified
			-- attribute lookup cannot inherit a plain-click cast.
			button:SetAttribute(modifier .. "-type" .. buttonNumber, "macro")
			button:SetAttribute(modifier .. "-spell" .. buttonNumber, nil)
			button:SetAttribute(modifier .. "-macrotext" .. buttonNumber, "")
		end
	end
	local keyboardSlots = {}
	for slot, entry in pairs(self.clickCasts or {}) do
		local key = string.match(slot, "^key%-(.+)$")
		local kind, action
		if type(entry) == "table" then kind, action = entry.kind or "spell", entry.text else kind, action = "spell", entry end
		if key and ((kind == "target" or kind == "menu") or (type(action) == "string" and action ~= "")) then
			keyboardSlots[table.getn(keyboardSlots) + 1] = {key = string.upper(key), kind = kind, action = action}
		end
	end
	table.sort(keyboardSlots, function(a, b) return a.key < b.key end)
	local overrideBindings = {}
	if not button._cellKeyOverrideOwner then
		local ok, owner = pcall(CreateFrame, "Frame", nil, UIParent)
		if ok then button._cellKeyOverrideOwner = owner end
	end
	for i = 1, table.getn(keyboardSlots) do
		local tokens = {}
		for token in string.gmatch(keyboardSlots[i].key, "[^%-]+") do tokens[table.getn(tokens) + 1] = token end
		local modifierTokens, key = {}, tokens[table.getn(tokens)]
		for tokenIndex = 1, table.getn(tokens) - 1 do modifierTokens[table.getn(modifierTokens) + 1] = string.lower(tokens[tokenIndex]) end
		local modifiers = table.concat(modifierTokens, "-")
		if modifiers ~= "" then modifiers = modifiers .. "-" end
		local kind, action = keyboardSlots[i].kind, keyboardSlots[i].action
		local bindingButton = Cell.keyboardBindButtons[keyboardSlots[i].key]
		if not bindingButton then
			Cell.keyboardBindButtonCount = (Cell.keyboardBindButtonCount or 0) + 1
			local buttonName = "NotCellKeyboardBind" .. Cell.keyboardBindButtonCount
			local ok, created = pcall(CreateFrame, "Button", buttonName, UIParent, "SecureUnitButtonTemplate")
			if ok then
				bindingButton = created
				bindingButton:SetWidth(1); bindingButton:SetHeight(1)
				bindingButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10, -10)
				bindingButton:SetAlpha(0)
				bindingButton:RegisterForClicks("AnyUp")
				bindingButton:SetAttribute("unit", "mouseover")
				bindingButton:Show()
				Cell.keyboardBindButtons[keyboardSlots[i].key] = bindingButton
			end
		end
		if bindingButton then
			local typeValue = "macro"
			if kind == "target" or kind == "menu" then typeValue = kind end
			bindingButton:SetAttribute("type1", typeValue)
			bindingButton.menu = ShowVanillaUnitMenu
			if kind == "spell" then bindingButton:SetAttribute("macrotext1", "/cast [@mouseover] " .. action)
			elseif kind == "macro" then bindingButton:SetAttribute("macrotext1", action)
			else bindingButton:SetAttribute("macrotext1", nil) end
			-- Saved slots have an internal `key-` prefix; the binding API expects
			-- the actual key chord (for example SHIFT-F1).
			overrideBindings[table.getn(overrideBindings) + 1] = {key, bindingButton:GetName()}
		end
	end
	if not button._cellKeyOverrideHooks then
		button._cellKeyOverrideHooks = true
		button:HookScript("OnEnter", function(self)
			self._cellClickCastPointerActive = true
			ApplyCellClickCastOverrides(self)
		end)
		local function ClearKeyOverrides(self)
			self._cellClickCastPointerActive = false
			ClearCellClickCastOverrides(self)
		end
		button:HookScript("OnLeave", ClearKeyOverrides)
		button:HookScript("OnHide", ClearKeyOverrides)
	end
	button._cellKeyOverrides = overrideBindings
	-- IsMouseOver() is only a geometric check: it can be true for a frame
	-- underneath the options panel or another window. Only OnEnter establishes
	-- that this frame actually received pointer focus.
	if button._cellClickCastPointerActive then ApplyCellClickCastOverrides(button) end
	for slot, entry in pairs(self.clickCasts or {}) do
		local modifier, buttonNumber = string.match(slot, "^(.-)(%d+)$")
		buttonNumber = tonumber(buttonNumber)
		local kind, action
		if type(entry) == "table" then kind, action = entry.kind or "spell", entry.text else kind, action = "spell", entry end
		if buttonNumber and buttonNumber >= 1 and buttonNumber <= 5 and ((kind == "target" or kind == "menu") or (type(action) == "string" and action ~= "")) then
			local typeAttribute = (modifier or "") .. "type" .. buttonNumber
			local typeValue = kind
			local actionAttribute
			if kind == "macro" then actionAttribute = (modifier or "") .. "macrotext" .. buttonNumber
			elseif kind == "spell" then typeValue = "macro"; actionAttribute = (modifier or "") .. "macrotext" .. buttonNumber end
			button:SetAttribute(typeAttribute, typeValue)
			if actionAttribute then
				local macro = action
				if kind == "spell" then macro = "/cast [@mouseover] " .. action end
				button:SetAttribute(actionAttribute, macro)
			end
			if modifier and modifier ~= "" then
				button._cellVanillaMouseAttributes[table.getn(button._cellVanillaMouseAttributes) + 1] = typeAttribute
				if actionAttribute then button._cellVanillaMouseAttributes[table.getn(button._cellVanillaMouseAttributes) + 1] = actionAttribute end
			end
		end
	end
	return true
end

-- Optional Blizzard-frame adapter for the shared secure click-cast settings.
function Cell:ApplyBlizzardClickCasts(force)
	if InCombatLockdown and InCombatLockdown() then return end
	for i = 1, table.getn(blizzardUnitFrameNames) do
		local frame = _G[blizzardUnitFrameNames[i]]
		if frame and frame.SetAttribute and (force or not frame._cellVanillaClickCastsInstalled) then
			local ok = pcall(self.ApplyClickCastSettings, self, frame)
			if ok then frame._cellVanillaClickCastsInstalled = true end
		end
	end
end

function Cell:ApplyAllClickCastSettings()
	for i = 1, table.getn(self.buttons or {}) do
		if self.buttons[i] then self:ApplyClickCastSettings(self.buttons[i]) end
	end
	self:ApplyBlizzardClickCasts(true)
end

function Cell:ApplyPowerBarLayout(button)
	if not button or not button.health or not button.power then return end
	local thickness = self.powerBarHeight or 4
	local verticalPower = self.powerBarOrientation == "VERTICAL"
	local side = self.powerBarSide == "RIGHT" and "RIGHT" or "LEFT"
	button.health:SetOrientation(self.healthBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
	button.healthOrientation = self.healthBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
	button.power:SetOrientation(verticalPower and "VERTICAL" or "HORIZONTAL")
	button.power:ClearAllPoints()
	if verticalPower then
		button.power:SetWidth(thickness)
		button.power:SetHeight(math.max(1, self.buttonHeight - 4))
		if side == "LEFT" then button.power:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2); button.power:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
		else button.power:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2); button.power:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2) end
	else
		button.power:SetWidth(math.max(1, self.buttonWidth - 4))
		button.power:SetHeight(thickness)
		button.power:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
		button.power:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	end
	button.health:ClearAllPoints()
	if verticalPower then
		if side == "LEFT" then button.health:SetPoint("TOPLEFT", button, "TOPLEFT", thickness + 4, -2); button.health:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		else button.health:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2); button.health:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -(thickness + 4), 2) end
	else
		button.health:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
		button.health:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, thickness + 4)
	end
end

function Cell:CreateButton(index)
	local button = CreateFrame("Button", "NotCellUnit" .. index, self.container, "SecureUnitButtonTemplate")
	button:SetWidth(self.buttonWidth)
	button:SetHeight(self.buttonHeight)
	button:RegisterForClicks("AnyUp", "Button4Up", "Button5Up")
	button:SetAttribute("type1", "target")
	button:SetAttribute("type2", "menu")
	local dragOverlay = CreateFrame("Button", nil, button)
	dragOverlay:SetAllPoints(button)
	dragOverlay:SetFrameLevel(button:GetFrameLevel() + 25)
	dragOverlay:RegisterForDrag("LeftButton")
	dragOverlay:EnableMouse(false)
	dragOverlay:Hide()
	dragOverlay:SetScript("OnDragStart", function()
		if Cell.preview and Cell.layoutPreviewMode and Cell.container then
			Cell.previewDragPositionLayout = Cell.previewGroupLayout or Cell.selectedGroupLayout or "Default"
			Cell.isMovingFrames = true
			Cell.container:StartMoving()
		end
	end)
	local function StopPreviewDrag()
		if not Cell.isMovingFrames or not Cell.layoutPreviewMode or not Cell.container then return end
		Cell.container:StopMovingOrSizing()
		Cell.isMovingFrames = nil
		local layoutKey = Cell.previewDragPositionLayout or Cell.selectedGroupLayout or "Default"
		Cell.previewDragPositionLayout = nil
		SaveContainerPosition(layoutKey)
		if SaveContainerPositionAfterMove then SaveContainerPositionAfterMove(layoutKey) end
		Cell:UpdateMoverControls()
	end
	dragOverlay:SetScript("OnDragStop", StopPreviewDrag)
	dragOverlay:SetScript("OnMouseUp", StopPreviewDrag)
	button.previewDragOverlay = dragOverlay

	local backdrop = button:CreateTexture(nil, "BACKGROUND")
	backdrop:SetAllPoints(button)
	backdrop:SetTexture(0.08, 0.08, 0.08, 0.95)
	button.backdrop = backdrop

	local health = CreateFrame("StatusBar", nil, button)
	health:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	health:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, (self.powerBarHeight or 4) + 4)
	health:SetStatusBarTexture(Cell.unitTexture or "Interface\\Buttons\\WHITE8X8")
	health:SetMinMaxValues(0, 1)
	local damageFlash = health:CreateTexture(nil, "OVERLAY")
	damageFlash:SetTexture("Interface\\Buttons\\WHITE8X8")
	damageFlash:SetAllPoints(health)
	damageFlash:SetVertexColor(1, 1, 1, 1)
	damageFlash:SetAlpha(0)
	damageFlash:Hide()
	button.damageFlash = damageFlash
	local damageFlashDriver = CreateFrame("Frame", nil, button)
	damageFlashDriver:SetAllPoints(button)
	damageFlashDriver:SetFrameLevel(button:GetFrameLevel() + 3)
	damageFlashDriver:SetScript("OnUpdate", function(driver, elapsed)
		button.damageFlashRemaining = (button.damageFlashRemaining or 0) - elapsed
		if button.damageFlashRemaining <= 0 then
			damageFlash:SetAlpha(0); damageFlash:Hide(); driver:Hide()
		else
			damageFlash:SetAlpha(0.70 * button.damageFlashRemaining / 0.30)
		end
	end)
	damageFlashDriver:Hide()
	button.damageFlashDriver = damageFlashDriver
	local healthBackground = health:CreateTexture(nil, "BACKGROUND")
	healthBackground:SetAllPoints(health)
	local lossColor = GetHealthLossColor(nil)
	healthBackground:SetTexture(lossColor[1], lossColor[2], lossColor[3], (Cell.healthLossAlpha or 95) / 100)
	button.healthBackground = healthBackground
	button.health = health
	local healPrediction = CreateFrame("StatusBar", nil, button)
	healPrediction:SetStatusBarTexture(Cell.unitTexture or "Interface\\Buttons\\WHITE8X8")
	local healColor = Cell.healPredictionColor or {0.20, 1.00, 0.35}
	healPrediction:SetStatusBarColor(healColor[1], healColor[2], healColor[3], 0.75); healPrediction:SetAlpha(0.65); healPrediction:Hide()
	button.healPrediction = healPrediction

	local power = CreateFrame("StatusBar", nil, button)
	power:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	power:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	power:SetHeight(self.powerBarHeight or 4)
	power:SetStatusBarTexture(Cell.unitTexture or "Interface\\Buttons\\WHITE8X8")
	power:SetMinMaxValues(0, 1)
	local powerBackground = power:CreateTexture(nil, "BACKGROUND")
	powerBackground:SetAllPoints(power)
	powerBackground:SetTexture(0.18, 0.18, 0.18, 1)
	button.power = power
	button.powerBackground = powerBackground
	local mouseoverHighlightLayer = CreateFrame("Frame", nil, button)
	mouseoverHighlightLayer:SetAllPoints(button)
	mouseoverHighlightLayer:SetFrameLevel(button:GetFrameLevel() + 1)
	local mouseoverTint = mouseoverHighlightLayer:CreateTexture(nil, "OVERLAY")
	mouseoverTint:SetTexture("Interface\\Buttons\\WHITE8X8")
	mouseoverTint:SetAllPoints(button)
	mouseoverTint:Hide()
	button.mouseoverHighlightTint = mouseoverTint
	local function CreateHighlightEdges(inset, edgeParent)
		local edges = {}
		for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
			local edge = edgeParent:CreateTexture(nil, "OVERLAY")
			edge:SetTexture("Interface\\Buttons\\WHITE8X8")
			if side == "TOP" or side == "BOTTOM" then
				edge:SetHeight(2); edge:SetPoint(side, button, side, 0, side == "TOP" and -inset or inset)
				edge:SetPoint("LEFT", button, "LEFT", inset, 0); edge:SetPoint("RIGHT", button, "RIGHT", -inset, 0)
			else
				edge:SetWidth(2); edge:SetPoint(side, button, side, side == "LEFT" and inset or -inset, 0)
				edge:SetPoint("TOP", button, "TOP", 0, -inset); edge:SetPoint("BOTTOM", button, "BOTTOM", 0, inset)
			end
			edge:Hide(); edges[table.getn(edges) + 1] = edge
		end
		return edges
	end
	button.targetHighlightEdges = CreateHighlightEdges(0, button)
	local textOverlay = CreateFrame("Frame", nil, button)
	textOverlay:SetAllPoints(button)
	textOverlay:SetFrameLevel(button:GetFrameLevel() + 2)
	button.textOverlay = textOverlay

	local name = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	name:SetPoint("TOPLEFT", health, "TOPLEFT", 2, -1)
	name:SetPoint("TOPRIGHT", health, "TOPRIGHT", -2, -1)
	name:SetJustifyH("LEFT")
	local font = nameFonts[Cell.nameFontIndex] or nameFonts[1]
	local outline = nameOutlines[Cell.nameFontOutline] or nameOutlines[2]
	name:SetFont(font.path, Cell.nameFontSize, outline.flag)
	button.name = name

	local healthText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	healthText:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -2, 0)
	button.healthText = healthText
	local powerText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	powerText:SetPoint("BOTTOM", button, "BOTTOM", 0, 4)
	button.powerText = powerText
	local statusText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusText:SetPoint("CENTER", button, "CENTER")
	statusText:SetFont(nameFonts[1].path, 12, "THICKOUTLINE")
	statusText:SetJustifyH("CENTER")
	statusText:Hide()
	button.statusText = statusText
	local debuffIcon = textOverlay:CreateTexture(nil, "OVERLAY")
	debuffIcon:SetWidth(16); debuffIcon:SetHeight(16)
	debuffIcon:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 2, 2)
	debuffIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	debuffIcon:Hide()
	button.debuffIcon = debuffIcon
	local debuffCount = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	debuffCount:SetPoint("BOTTOMRIGHT", debuffIcon, "BOTTOMRIGHT", 2, -2)
	debuffCount:SetFont(nameFonts[1].path, 10, "THICKOUTLINE")
	debuffCount:SetJustifyH("RIGHT")
	button.debuffCount = debuffCount
	button.auraIcons = {buffs={},debuffs={},missingBuffs={},healerBuffs={}}
	button.indicatorIcons={}
	for _, key in ipairs({"statusIcon","roleIcon","leaderIcon","readyCheckIcon","raidIcon"}) do
		local icon=textOverlay:CreateTexture(nil,"OVERLAY"); icon:SetWidth(16); icon:SetHeight(16); icon:Hide(); button.indicatorIcons[key]=icon
	end
	for _, auraType in ipairs({"buffs","debuffs","missingBuffs","healerBuffs"}) do
		local iconCount=auraType=="missingBuffs" and 3 or (auraType=="healerBuffs" and 5 or 20)
		for auraIndex=1,iconCount do
			local icon=CreateFrame("Frame",nil,textOverlay)
			-- Keep aura icons above the health StatusBar and any health-color layer.
			icon:SetFrameLevel(textOverlay:GetFrameLevel()+5)
			icon:SetWidth(16); icon:SetHeight(16); icon:Hide()
			if auraType=="missingBuffs" then
				local glow=CreateFrame("Frame",nil,icon)
				glow:SetPoint("TOPLEFT",icon,"TOPLEFT",-1,1); glow:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",1,-1)
				glow:SetFrameLevel(icon:GetFrameLevel()+2)
				glow:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
				glow:SetBackdropBorderColor(.58,.88,1,.85)
				glow:Show()
				icon.missingBuffGlow=glow
			end
			icon.texture=icon:CreateTexture(nil,"ARTWORK"); icon.texture:SetAllPoints(icon); icon.texture:SetTexCoord(0.08,0.92,0.08,0.92)
			icon.count=icon:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); icon.count:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",2,-2); icon.count:SetFont(nameFonts[1].path,9,"THICKOUTLINE"); icon.count:SetJustifyH("RIGHT")
			button.auraIcons[auraType][auraIndex]=icon
		end
	end
	local debuffFillSegments = {}
	for i = 1, 24 do
		debuffFillSegments[i] = textOverlay:CreateTexture(nil, "BACKGROUND")
		debuffFillSegments[i]:SetTexture("Interface\\Buttons\\WHITE8X8")
		debuffFillSegments[i]:Hide()
	end
	button.debuffFillSegments = debuffFillSegments
	local debuffBorderFrame = CreateFrame("Frame", nil, button)
	debuffBorderFrame:SetAllPoints(button)
	debuffBorderFrame:SetFrameLevel(button:GetFrameLevel() + 1)
	debuffBorderFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = 1})
	debuffBorderFrame:SetBackdropColor(0, 0, 0, 0)
	debuffBorderFrame.borderSize = 1
	debuffBorderFrame:Hide()
	button.debuffBorderFrame = debuffBorderFrame
	self:ApplyClickCastSettings(button)
	button:HookScript("OnEnter", function(self)
		UpdateFrameHighlights(self, self:GetAttribute("unit"), true)
		if not Cell:CanShowUnitTooltips() or not GameTooltip then return end
		local unit = self:GetAttribute("unit")
		if unit and UnitExists and UnitExists(unit) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetUnit(unit)
			GameTooltip:Show()
			Cell.activeUnitTooltipOwner = self
		end
	end)
	button:HookScript("OnLeave", function(self)
		UpdateFrameHighlights(self, self:GetAttribute("unit"), false)
		if Cell.activeUnitTooltipOwner == self then Cell:HideUnitFrameTooltip() end
	end)
	button.classToken = nil

	local col, row = GetGroupGridPosition(index)
	local spacingX, spacingY = GetDisplayedSpacing()
	button:SetPoint("TOPLEFT", self.container, "TOPLEFT",
		col * (self.buttonWidth + spacingX),
		-row * (self.buttonHeight + spacingY))
	button:Hide()
	self.buttons[index] = button
	return button
end

function Cell:ResizeContainer(unitCount)
	if not self.container then return end
	local count = math.max(1, math.min(unitCount or 1, 40))
	local columns, rows = GetGroupGridSize(count)
	local spacingX, spacingY = GetDisplayedSpacing()
	local width = columns * self.buttonWidth + (columns - 1) * spacingX
	local height = rows * self.buttonHeight + (rows - 1) * spacingY
	if self.container:GetWidth() ~= width then self.container:SetWidth(width) end
	if self.container:GetHeight() ~= height then self.container:SetHeight(height) end
end

function Cell:ApplyButtonSize(skipRefresh)
	for i = 1, table.getn(self.buttons) do
		local button = self.buttons[i]
		if not button then break end
		button:SetWidth(self.buttonWidth)
		button:SetHeight(self.buttonHeight)
		self:ApplyPowerBarLayout(button)
		local col, row = GetGroupGridPosition(i)
		local spacingX, spacingY = GetDisplayedSpacing()
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", self.container, "TOPLEFT",
			col * (self.buttonWidth + spacingX),
			-row * (self.buttonHeight + spacingY))
	end
	if not skipRefresh then self:UpdateFrames() end
end

local function GetActiveGroupLayout()
	local groupType
	if UnitInRaid and UnitInRaid("player") then
		local count = GetNumRaidMembers and GetNumRaidMembers() or 0
		local instanceType
		if GetInstanceInfo then local _,kind=GetInstanceInfo(); instanceType=kind end
		if IsInInstance then local inInstance,kind=IsInInstance(); if inInstance and kind then instanceType=kind end end
		if not instanceType or instanceType=="none" then groupType="raid_outdoor"
		elseif instanceType~="raid" then groupType="raid_outdoor"
		elseif count<=10 then groupType="raid10"
		elseif count<=25 then groupType="raid25"
		else groupType="raid40" end
	elseif (GetNumPartyMembers and GetNumPartyMembers() or 0)>0 then
		groupType="party"
	else
		groupType="solo"
	end
	return Cell.layoutAutoSwitch[groupType] or "Default"
end

local function GetPositionLayoutKey()
	if Cell.preview then return Cell.previewGroupLayout or Cell.selectedGroupLayout or "Default" end
	if Cell.autoGroupLayouts then return GetActiveGroupLayout() end
	return Cell.selectedGroupLayout or "Default"
end

local positionSaveDriver = CreateFrame("Frame")
positionSaveDriver:Hide()
positionSaveDriver:SetScript("OnUpdate", function(self, elapsed)
	self.remaining = (self.remaining or 0) - elapsed
	if self.remaining <= 0 then
		self:Hide()
		self.remaining = nil
		if Cell.container then SaveContainerPosition(self.layoutKey) end
		self.layoutKey = nil
	end
end)
SaveContainerPositionAfterMove = function(layoutKey)
	-- Let the client finish applying the drag before reading the final frame rect.
	positionSaveDriver.layoutKey = layoutKey
	positionSaveDriver.remaining = 0.20
	positionSaveDriver:Show()
end

SaveContainerPosition = function(layoutKey, preserveAnchor)
	if not Cell.container then return end
	local left, bottom = Cell.container:GetLeft(), Cell.container:GetBottom()
	if not left or not bottom then return end
	left = math.max(0, math.min(left, UIParent:GetWidth() - Cell.container:GetWidth()))
	bottom = math.max(0, math.min(bottom, UIParent:GetHeight() - Cell.container:GetHeight()))
	if not preserveAnchor then
		Cell.container:ClearAllPoints()
		Cell.container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	end
	initialContainerPosition = {x = left, y = bottom}
	local key = layoutKey or GetPositionLayoutKey()
	local profile = Cell.groupLayoutProfiles[key]
	if profile then profile.position = {x = left, y = bottom} end
	NotCellVanillaDB = GetCellSettingsDB()
	NotCellVanillaDB.containerPosition = {x = left, y = bottom}
	NotCellVanillaDB.positionLayoutKey = key
	NotCellVanillaDB.layouts = Cell.groupLayoutProfiles
	NotCellVanillaDB.groupLayoutProfiles = Cell.groupLayoutProfiles
	SaveCellSettingsDB()
end

function Cell:UpdateFrames()
	if not self.container then return end
	local enablePreviewDragging = self.preview and self.layoutPreviewMode ~= nil
	for _, button in ipairs(self.buttons or {}) do
		if button.previewDragOverlay then
			if enablePreviewDragging then button.previewDragOverlay:EnableMouse(true); button.previewDragOverlay:Show()
			else button.previewDragOverlay:EnableMouse(false); button.previewDragOverlay:Hide() end
		end
	end
	local layoutKey
	if self.preview then
		layoutKey = self.selectedGroupLayout or "Default"
		self.previewGroupLayout = layoutKey
	elseif self.autoGroupLayouts then
		layoutKey = GetActiveGroupLayout()
	else
		layoutKey = self.selectedGroupLayout or "Default"
	end
	if not self.preview and self.autoGroupLayouts and layoutKey == "hide" then
		self.activeGroupLayout = "hide"
		self.container:Hide()
		for i = 1, table.getn(self.buttons) do if self.buttons[i] then self.buttons[i]:Hide() end end
		return
	end
	self.container:Show()
	local positionKey = GetPositionLayoutKey()
	local positionProfile = self.groupLayoutProfiles[positionKey]
	local positionToApply
	if positionProfile and self.activePositionLayout ~= positionKey then
		local firstPositionApply = self.activePositionLayout == nil
		self.activePositionLayout = positionKey
		local savedPositionKey = NotCellVanillaDB and NotCellVanillaDB.positionLayoutKey
		local position
		if firstPositionApply and initialContainerPosition then
			-- The global value is the last position the player dragged to. Use it
			-- on startup even if auto-switch selected a different layout key.
			position = initialContainerPosition
		elseif savedPositionKey == positionKey then
			position = initialContainerPosition or (positionProfile and positionProfile.position)
		elseif savedPositionKey then
			position = positionProfile.position or initialContainerPosition
		else
			-- Older saved data had only the global position. Prefer it over the
			-- per-layout copies that were initialized from an earlier position.
			position = initialContainerPosition or positionProfile.position
		end
		positionToApply = position or true
	end
	local function ApplyPendingPosition()
		if not positionToApply then return end
		-- POSITION PERSISTENCE: keep this after ResizeContainer in both the
		-- preview and live branches. Initialize starts with an 8-column placeholder
		-- frame; clamping against that temporary width pushed valid saved positions
		-- to the far left edge on login/reload.
		local requestedLeft = type(positionToApply) == "table" and tonumber(positionToApply.x) or nil
		local requestedBottom = type(positionToApply) == "table" and tonumber(positionToApply.y) or nil
		local left = math.max(0, math.min(requestedLeft or (UIParent:GetWidth() - self.container:GetWidth()) / 2, UIParent:GetWidth() - self.container:GetWidth()))
		local bottom = math.max(0, math.min(requestedBottom or (UIParent:GetHeight() - self.container:GetHeight()) / 2, UIParent:GetHeight() - self.container:GetHeight()))
		self.container:ClearAllPoints()
		self.container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
		positionToApply = nil
	end
	if layoutKey then
		local profile = self.groupLayoutProfiles[layoutKey]
		local activeKey = (self.preview and "preview-" or "") .. layoutKey
		if profile and (self.activeGroupLayout ~= activeKey or self.buttonWidth ~= profile.width or self.buttonHeight ~= profile.height or self.powerBarHeight ~= profile.powerBarHeight or self.healthBarOrientation ~= profile.healthBarOrientation or self.powerBarOrientation ~= profile.powerBarOrientation or self.powerBarSide ~= profile.powerBarSide) then
			self.activeGroupLayout = activeKey
			self.buttonWidth, self.buttonHeight = profile.width, profile.height
			self.powerBarHeight = profile.powerBarHeight or self.powerBarHeight
			self.healthBarOrientation = profile.healthBarOrientation or "HORIZONTAL"
			self.powerBarOrientation = profile.powerBarOrientation or "HORIZONTAL"
			self.powerBarSide = profile.powerBarSide or "LEFT"
			self:ApplyButtonSize(true)
			self:ApplyTextSettings()
			if self.optionsFrame and self.optionsFrame.groupLayoutButton then
				self.syncingLayoutControls = true
				if self.selectedGroupLayout == layoutKey then
					self.optionsFrame.widthSlider:SetValue(profile.width)
					self.optionsFrame.heightSlider:SetValue(profile.height)
					if self.optionsFrame.powerHeightSlider then self.optionsFrame.powerHeightSlider:SetValue(profile.powerBarHeight or self.powerBarHeight) end
					if self.optionsFrame.spacingXSlider then self.optionsFrame.spacingXSlider:SetValue(profile.spacingX or self.horizontalGap) end
					if self.optionsFrame.spacingYSlider then self.optionsFrame.spacingYSlider:SetValue(profile.spacingY or self.verticalGap) end
				end
				self.syncingLayoutControls = nil
				self:RefreshOptionsMenu()
			end
		end
	end
	if self.preview then
		local displayedProfile = GetDisplayedLayoutProfile() or {}
		local enabledGroups = GetEnabledGroupNumbers(displayedProfile)
		local previewCount = self.previewMode == "raid" and math.min(self.previewLimit or 40, table.getn(enabledGroups) * 5)
			or ((self.previewMode == "status" or self.previewMode == "range") and table.getn(statusPreviewUnits) or table.getn(partyPreviewUnits))
		self:ResizeContainer(previewCount)
		ApplyPendingPosition()
		for i = 1, 40 do
			local button = self.buttons[i]
			if not button then break end
			local sample
			if self.previewMode == "raid" then
				if not self.previewLimit or i <= self.previewLimit then
					local shownGroup = math.floor((i - 1) / 5) + 1
					local member = (i - 1) % 5 + 1
					local sourceIndex = enabledGroups[shownGroup] and (enabledGroups[shownGroup] - 1) * 5 + member
					sample = sourceIndex and raidPreviewUnits[sourceIndex]
				end
			elseif self.previewMode == "status" or self.previewMode == "range" then
				sample = statusPreviewUnits[i]
			elseif i <= table.getn(partyPreviewUnits) then
				sample = partyPreviewUnits[i]
			end
			if not button.preview then
				button.preview = true
				button.unit = nil
				button:EnableMouse(true)
				button:SetAttribute("type1", "")
				button:SetAttribute("type2", "")
				button:SetAttribute("unit", nil)
			end
			if sample then
				local samplePowerType = sample.powerType or previewPowerTypes[sample.class] or 0
				button.name:SetText(sample.name)
				button.classToken = sample.class
				SetNameColor(button, nil, sample.class)
				SetHealthLossColor(button, sample.class)
				local healthSettings, powerSettings = GetDisplayedIndicatorSettings("healthText"), GetDisplayedIndicatorSettings("powerText")
				SetStyledTextColor(button.healthText, healthSettings and healthSettings.colorMode or Cell.healthTextColorMode, healthSettings and healthSettings.color or Cell.healthTextCustomColor, sample.class, nil, sample.health)
				SetStyledTextColor(button.powerText, powerSettings and powerSettings.colorMode or Cell.powerTextColorMode, powerSettings and powerSettings.color or Cell.powerTextCustomColor, sample.class, samplePowerType)
				local previewHealth = sample.status == "dead" and Cell.deadBackdropEnabled and 1 or sample.health
				SetAnimatedHealthValue(button, previewHealth, sample.status == "dead")
				SetHealthColor(button, nil, sample.class, sample.health)
				local sampleMax = 1000
				SetHealthValueText(button, sample.health * sampleMax, sampleMax)
				SetPowerValueText(button, (sample.power or 0) * sampleMax, sampleMax)
				SetPowerColor(button, nil, samplePowerType)
				button.power:SetValue(sample.power or 0)
				SetDebuffIcon(button, sample.debuff, sample.debuffCount, sample.debuffType, sample.spellID)
				SetFrameStatus(button, sample.status)
				button:SetAlpha(sample.inRange == false and (self.outOfRangeAlpha or 45) / 100 or 1)
				UpdateFrameHighlights(button, nil, button.IsMouseOver and button:IsMouseOver())
				button:Show()
			else
				button:Hide()
			end
		end
		self:ApplyBlizzardClickCasts()
		return
	end

	local units = GetUnitList()
	local visibleCount = 0
	local liveProfile = GetDisplayedLayoutProfile() or {}
	local enabledGroups = GetEnabledGroupNumbers(liveProfile)
	for i = 1, 40 do
		local raidIndex = units[i] and tonumber(string.match(units[i], "^raid(%d+)$"))
		local displayIndex = i
		if raidIndex then
			local rank = GetGroupDisplayRank(math.ceil(raidIndex / 5), enabledGroups)
			displayIndex = rank and (rank - 1) * 5 + (raidIndex - 1) % 5 + 1 or nil
		end
		if displayIndex and units[i] and UnitExists(units[i]) then visibleCount = math.max(visibleCount, displayIndex) end
	end
	self:ResizeContainer(visibleCount)
	ApplyPendingPosition()
	for i = 1, 40 do
		local button = self.buttons[i]
		if not button then break end
		local unit = units[i]
		local raidGroup = unit and tonumber(string.match(unit, "^raid(%d+)$"))
		local groupRank = raidGroup and GetGroupDisplayRank(math.ceil(raidGroup / 5), enabledGroups)
		local groupEnabled = not raidGroup or groupRank ~= nil
		if raidGroup and groupRank then
			local logicalIndex = (groupRank - 1) * 5 + (raidGroup - 1) % 5 + 1
			local column, row = GetGroupGridPosition(logicalIndex)
			local spacingX, spacingY = GetDisplayedSpacing()
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self.container, "TOPLEFT", column * (self.buttonWidth + spacingX), -row * (self.buttonHeight + spacingY))
		end
		if unit and groupEnabled and UnitExists(unit) then
			if button.preview then
				button.preview = nil
				button.unit = nil
				button._cellLastHealthValue = nil
				button:SetAttribute("type1", "target")
				button:SetAttribute("type2", "menu")
				Cell:ApplyClickCastSettings(button)
			end
			button:EnableMouse(true)
			if button.unit ~= unit then
				button.unit = unit
				button._cellLastHealthValue = nil
				button:SetAttribute("unit", unit)
			end
			button.name:SetText(UnitName(unit) or unit)
			local _, classToken = UnitClass(unit)
			button.classToken = classToken
			SetNameColor(button, unit, classToken)
			SetHealthLossColor(button, classToken)
			local power, powerMax, powerType = UpdatePower(button, unit)
			SetStyledTextColor(button.powerText, Cell.powerTextColorMode, Cell.powerTextCustomColor, classToken, powerType)
			local powerSettings = GetDisplayedIndicatorSettings("powerText")
			if powerSettings and powerSettings.colorMode then SetStyledTextColor(button.powerText,powerSettings.colorMode,powerSettings.color or Cell.powerTextCustomColor,classToken,powerType) end
			SetPowerValueText(button, power, powerMax)

			local status = GetLiveUnitStatus(unit)
			UpdateSimpleIndicators(button,unit,status)
			local health = UnitHealth(unit) or 0
			local healthMax = UnitHealthMax(unit) or 0
			SetStyledTextColor(button.healthText, Cell.healthTextColorMode, Cell.healthTextCustomColor, classToken, nil, healthMax > 0 and health / healthMax or 0)
			local healthSettings = GetDisplayedIndicatorSettings("healthText")
			if healthSettings and healthSettings.colorMode == "custom" and healthSettings.color then button.healthText:SetTextColor(healthSettings.color[1], healthSettings.color[2], healthSettings.color[3])
			elseif healthSettings and healthSettings.colorMode == "class" then local color=classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]; if color then button.healthText:SetTextColor(color.r,color.g,color.b) end end
			if healthMax > 0 then
				local healthFraction = health / healthMax
				if status == "dead" and Cell.deadBackdropEnabled then healthFraction = 1 end
				SetAnimatedHealthValue(button, healthFraction, status == "dead")
				SetHealthColor(button, unit, classToken, health / healthMax)
				SetHealthValueText(button, health, healthMax)
			else
				SetAnimatedHealthValue(button, 0, status == "dead")
				SetHealthColor(button, unit, classToken, 0)
				SetHealthValueText(button, 0, 0)
			end
			local debuffTexture, debuffCount, debuffType, debuffSpellID = GetFirstDebuff(unit)
			SetDebuffIcon(button, debuffTexture, debuffCount, debuffType, debuffSpellID)
			UpdateAuraIcons(button,unit,"buffs",status); UpdateAuraIcons(button,unit,"debuffs",status); UpdateAuraIcons(button,unit,"missingBuffs",status); UpdateAuraIcons(button,unit,"healerBuffs",status)
			SetFrameStatus(button, status)
			UpdateHealPrediction(button, unit, health, healthMax)
			UpdateFrameHighlights(button, unit, button.IsMouseOver and button:IsMouseOver())
			local inRange, rangeChecked
			if self.rangeFadeEnabled and UnitInRange then
				inRange, rangeChecked = UnitInRange(unit)
			end
			button:SetAlpha(rangeChecked and not inRange and (self.outOfRangeAlpha or 45) / 100 or 1)
			button:Show()
		else
			button.unit = nil
			button:EnableMouse(false)
			button:Hide()
		end
	end
	self:ApplyBlizzardClickCasts()
end

-- Class-tagged list for the first-run prompt. Include every healer class so
-- every client can track teammates' effects, not only spells from its own class.
local healerAuraSpellIDs={
	PRIEST={139,17,15357,15359,15361,"Enlighten","Apotheosis"},
	PALADIN={20236,1022,"Daybreak"},
	SHAMAN={16176,16177,16178,29203,29204,29205},
	DRUID={774,8936,740},
}
local function BuildHealerIndicatorSpells()
	local spells, iconMarkup = {}, ""
	for _,classToken in ipairs({"PRIEST","PALADIN","SHAMAN","DRUID"}) do
		for _,id in ipairs(healerAuraSpellIDs[classToken] or {}) do
			if GetSpellInfo then
				local name,_,icon=GetSpellInfo(id)
				if name and icon then
					spells[table.getn(spells)+1]={id=type(id)=="number" and id or nil,name=name,icon=icon,class=classToken}
					iconMarkup=iconMarkup.."|T"..icon..":22:22|t "
				end
			end
		end
	end
	return spells, iconMarkup
end

function Cell:CreateHealerIndicators()
	local spells=BuildHealerIndicatorSpells()
	if table.getn(spells)==0 then return false end
	local layoutKey=Cell.selectedGroupLayout or "Default"
	local profile=Cell.groupLayoutProfiles[layoutKey] or Cell.groupLayoutProfiles.Default
	profile.indicators=type(profile.indicators)=="table" and profile.indicators or {}
	profile.indicators.healerBuffs={enabled=true,anchor="TOPRIGHT",x=0,y=0,iconSize=16,size=16,maxIcons=5,rows=1,orientation="left",filterMode="whitelist",filterModeInitialized=true,spells=spells,onlyCurrentClass=false,castByPlayer=false}
	NotCellVanillaDB=GetCellSettingsDB()
	NotCellVanillaDB.layouts=Cell.groupLayoutProfiles
	NotCellVanillaDB.groupLayoutProfiles=Cell.groupLayoutProfiles
	NotCellVanillaDB.selectedLayout=layoutKey
	NotCellDB.CellVanillaPreview=NotCellVanillaDB
	SaveCellSettingsDB()
	Cell:UpdateFrames()
	Cell:RefreshOptionsMenu()
	return true
end

function Cell:ShowHealerIndicatorPrompt(force)
	if not force and not offerHealerIndicator then return end
	if not force then offerHealerIndicator=false end
	local settings=GetCellSettingsDB()
	if not force and settings.healerIndicatorPromptSeen then return end
	if not force then settings.healerIndicatorPromptSeen=true; SaveCellSettingsDB() end
	local _, iconMarkup=BuildHealerIndicatorSpells()
	local prompt=Cell.healerIndicatorPromptFrame
	if not prompt then
		prompt=CreateFrame("Frame","NotCellHealerPrompt",UIParent)
		prompt:SetWidth(310); prompt:SetHeight(168); prompt:SetPoint("CENTER",UIParent,"CENTER",0,0)
		prompt:SetFrameStrata("DIALOG"); prompt:SetFrameLevel(500); prompt:SetMovable(true); prompt:EnableMouse(true)
		prompt:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
		prompt.title=prompt:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
		prompt.title:SetPoint("TOP",prompt,"TOP",0,-15); prompt.title:SetText("Healer Indicators")
		prompt.message=prompt:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
		prompt.message:SetPoint("TOPLEFT",prompt,"TOPLEFT",18,-43); prompt.message:SetPoint("TOPRIGHT",prompt,"TOPRIGHT",-18,-43); prompt.message:SetJustifyH("CENTER")
		prompt.noButton=AddOptionsButton(prompt,"No",38,-126,100,function() prompt:Hide() end)
		prompt.yesButton=AddOptionsButton(prompt,"Create",172,-126,100,function() end)
		prompt:SetScript("OnMouseDown",function(self,button) if button=="LeftButton" then self:StartMoving() end end)
		prompt:SetScript("OnMouseUp",function(self,button) if button=="LeftButton" then self:StopMovingOrSizing() end end)
		if UISpecialFrames then table.insert(UISpecialFrames,"NotCellHealerPrompt") end
		Cell.healerIndicatorPromptFrame=prompt
	end
	prompt.message:SetText("Create a Healers indicator for healing-over-time spells and shields?\n"..iconMarkup)
	prompt.noButton:SetScript("OnClick",function() prompt:Hide() end)
	prompt.yesButton:SetScript("OnClick",function()
		Cell:CreateHealerIndicators()
		prompt:Hide()
	end)
	prompt:Show()
end

function Cell:ShowSetupWizard()
	self:Initialize()
	-- Setup is modal. Hide Options whether setup was opened from its button or
	-- from /notcell setup.
	if self.optionsFrame and self.optionsFrame:IsShown() then self.optionsFrame:Hide() end
	NotCellDB=type(NotCellDB)=="table" and NotCellDB or {}
	local state=NotCellDB
	local setupFrame=self.setupWizardFrame
	if not setupFrame then
		setupFrame=CreateFrame("Frame","NotCellSetupWizard",UIParent)
		setupFrame:SetWidth(438); setupFrame:SetHeight(520); setupFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
		setupFrame:SetFrameStrata("DIALOG"); setupFrame:SetFrameLevel(600); setupFrame:SetMovable(true); setupFrame:EnableMouse(true)
		setupFrame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
		setupFrame.title=setupFrame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
	setupFrame.title:SetPoint("TOP",setupFrame,"TOP",0,-12); setupFrame.title:SetText("Welcome to NotCell")
		setupFrame.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",20,"OUTLINE")
		setupFrame.intro=setupFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
		setupFrame.intro:SetPoint("TOPLEFT",setupFrame,"TOPLEFT",22,-37); setupFrame.intro:SetWidth(394); setupFrame.intro:SetHeight(22); setupFrame.intro:SetJustifyH("LEFT")
		setupFrame.intro:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"OUTLINE")
		setupFrame.intro:SetText("Choose an appearance and how your unitframes are arranged.")
		local function AddWizardLabel(text,y)
			local label=setupFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
			label:SetPoint("TOPLEFT",setupFrame,"TOPLEFT",22,y); label:SetWidth(194); label:SetHeight(22); label:SetText(text)
			label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"OUTLINE")
			return label
		end
		AddWizardLabel("Select Mode",-71)
		setupFrame.profileDropdown=AddChoiceDropdown(setupFrame,198,220,-65,function() return setupFrame.profileValue or "Light Mode" end,{{name="Light Mode",value="Light Mode"},{name="Dark Mode",value="Dark Mode"}},function(value)
			setupFrame.profileValue=value
			setupFrame.profileDropdown:RefreshChoiceLabel()
			self:ApplyAppearancePreset(value,false)
			if setupFrame.UpdateGuidePreview then setupFrame.UpdateGuidePreview() end
		end)
		setupFrame.growthLabel=AddWizardLabel("How frames grow on screen",-107)
		setupFrame.growthDropdown=AddChoiceDropdown(setupFrame,198,220,-101,function() return "Growth: "..((setupFrame.growthValue=="right-down") and "Right then Down" or "Down then Right") end,{{name="Down then Right (row first)",value="down-right"},{name="Right then Down (column first)",value="right-down"}},function(value)
			setupFrame.growthValue=value; setupFrame.growthDropdown:RefreshChoiceLabel(); self:ApplySetupLayoutChoices()
		end)
		setupFrame.healthOrientationLabel=AddWizardLabel("Health Fill Direction",-143)
		setupFrame.healthOrientationDropdown=AddChoiceDropdown(setupFrame,198,220,-137,function() return "Health: "..(setupFrame.healthOrientationValue=="VERTICAL" and "Vertical" or "Horizontal") end,{{name="Horizontal (left to right)",value="HORIZONTAL"},{name="Vertical (bottom to top)",value="VERTICAL"}},function(value)
			setupFrame.healthOrientationValue=value; setupFrame.healthOrientationDropdown:RefreshChoiceLabel(); self:ApplySetupLayoutChoices()
		end)
		setupFrame.powerOrientationLabel=AddWizardLabel("Power Bar Direction",-179)
		setupFrame.powerOrientationDropdown=AddChoiceDropdown(setupFrame,198,220,-173,function() return "Power: "..(setupFrame.powerOrientationValue=="VERTICAL" and "Vertical" or "Horizontal") end,{{name="Horizontal (along bottom)",value="HORIZONTAL"},{name="Vertical (left or right edge)",value="VERTICAL"}},function(value)
			setupFrame.powerOrientationValue=value; setupFrame.powerOrientationDropdown:RefreshChoiceLabel(); self:UpdateSetupPowerSideVisibility(); self:ApplySetupLayoutChoices()
		end)
		setupFrame.powerSideLabel=AddWizardLabel("Choose Power Bar Position",-215)
		setupFrame.powerSideDropdown=AddChoiceDropdown(setupFrame,198,220,-209,function() return "Position: "..(setupFrame.powerSideValue=="RIGHT" and "Right" or "Left") end,{{name="Left edge",value="LEFT"},{name="Right edge",value="RIGHT"}},function(value)
			setupFrame.powerSideValue=value; setupFrame.powerSideDropdown:RefreshChoiceLabel(); self:ApplySetupLayoutChoices()
		end)
		setupFrame.healPredictionCheckbox=AddOptionsCheckbox(setupFrame,"Heal Prediction",22,-251,396,function()
			Cell.healPredictionEnabled=not Cell.healPredictionEnabled
			setupFrame.healPredictionCheckbox:SetChecked(Cell.healPredictionEnabled)
			local db=GetCellSettingsDB(); db.healPredictionEnabled=Cell.healPredictionEnabled; SaveCellSettingsDB()
			Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
			if setupFrame.UpdateGuidePreview then setupFrame.UpdateGuidePreview() end
		end,14)
		setupFrame.healPredictionCheckbox.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"OUTLINE")
		setupFrame.healPredictionNote=setupFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
		setupFrame.healPredictionNote:SetPoint("TOPLEFT",setupFrame,"TOPLEFT",43,-269); setupFrame.healPredictionNote:SetWidth(370); setupFrame.healPredictionNote:SetHeight(18); setupFrame.healPredictionNote:SetJustifyH("LEFT")
		setupFrame.healPredictionNote:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE")
		setupFrame.healPredictionNote:SetText("Shows estimated incoming heals on unit health bars.")
		setupFrame.healerCheck=AddOptionsCheckbox(setupFrame,"Create Healer Indicators",22,-293,396,function() setupFrame.createHealerIndicators=not setupFrame.createHealerIndicators; setupFrame.healerCheck:SetChecked(setupFrame.createHealerIndicators) end,14)
		setupFrame.healerCheck.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"OUTLINE")
		setupFrame.healerNote=setupFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
		setupFrame.healerNote:SetPoint("TOPLEFT",setupFrame,"TOPLEFT",43,-311); setupFrame.healerNote:SetWidth(370); setupFrame.healerNote:SetHeight(18); setupFrame.healerNote:SetJustifyH("LEFT")
		setupFrame.healerNote:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE")
		setupFrame.healerNote:SetText("Tracks healing-over-time effects and shields on group frames.")
		setupFrame.blizzardCheck=AddOptionsCheckbox(setupFrame,"Hide Blizzard group frames",22,-335,396,function() setupFrame.hideBlizzardFrames=not setupFrame.hideBlizzardFrames; setupFrame.blizzardCheck:SetChecked(setupFrame.hideBlizzardFrames) end,14)
		setupFrame.blizzardCheck.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"OUTLINE")
		setupFrame.blizzardNote=setupFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
		setupFrame.blizzardNote:SetPoint("TOPLEFT",setupFrame,"TOPLEFT",43,-353); setupFrame.blizzardNote:SetWidth(380); setupFrame.blizzardNote:SetHeight(18); setupFrame.blizzardNote:SetJustifyH("LEFT")
		setupFrame.blizzardNote:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE")
		setupFrame.blizzardNote:SetText("Party/Raid only; Player, Target, and Target of Target stay visible.")
		setupFrame.finishButton=AddOptionsButton(setupFrame,"Finish Setup",64,-480,150,function() end)
		setupFrame.skipButton=AddOptionsButton(setupFrame,"Skip",234,-480,150,function() end)
		-- One private guide unitframe, drawn like a live Cell frame: bars are
		-- child StatusBars and text sits on a higher-level overlay frame.
		setupFrame.guideUnit=CreateFrame("Frame",nil,setupFrame)
	setupFrame.guideUnit:SetWidth(180); setupFrame.guideUnit:SetHeight(72)
		setupFrame.guideUnit:SetPoint("TOP",setupFrame,"TOP",0,-378)
		local unit=setupFrame.guideUnit
		unit.frameBackground=unit:CreateTexture(nil,"BACKGROUND")
		unit.frameBackground:SetAllPoints(unit); unit.frameBackground:SetTexture("Interface\\Buttons\\WHITE8X8"); unit.frameBackground:SetVertexColor(.035,.035,.035,1)
		unit.health=CreateFrame("StatusBar",nil,unit); unit.health:SetAllPoints(unit); unit.health:SetMinMaxValues(0,1); unit.health:SetValue(.72); unit.health:SetStatusBarTexture(Cell.unitTexture or "Interface\\Buttons\\WHITE8X8")
		unit.healthBackground=unit.health:CreateTexture(nil,"BACKGROUND"); unit.healthBackground:SetAllPoints(unit.health); unit.healthBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
		unit.heal=CreateFrame("StatusBar",nil,unit); unit.heal:SetMinMaxValues(0,1); unit.heal:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8"); unit.heal:SetStatusBarColor(.20,1,.35,.45)
		unit.power=CreateFrame("StatusBar",nil,unit); unit.power:SetMinMaxValues(0,1); unit.power:SetValue(.62); unit.power:SetStatusBarTexture(Cell.unitTexture or "Interface\\Buttons\\WHITE8X8"); unit.power:SetStatusBarColor(.15,.42,1,1)
		unit.powerBackground=unit.power:CreateTexture(nil,"BACKGROUND"); unit.powerBackground:SetAllPoints(unit.power); unit.powerBackground:SetTexture("Interface\\Buttons\\WHITE8X8"); unit.powerBackground:SetVertexColor(.18,.18,.18,1)
		unit.textOverlay=CreateFrame("Frame",nil,unit); unit.textOverlay:SetAllPoints(unit); unit.textOverlay:SetFrameLevel(unit:GetFrameLevel()+2)
		unit.name=unit.textOverlay:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		unit.healthText=unit.textOverlay:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		unit.powerText=unit.textOverlay:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		unit.healthText:SetText("72%"); unit.powerText:SetText("62%")
		local guideFont=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		unit.name:SetFont(guideFont,14,"OUTLINE"); unit.healthText:SetFont(guideFont,12,"OUTLINE"); unit.powerText:SetFont(guideFont,10,"OUTLINE")
		setupFrame.guideElapsed=0
		setupFrame.UpdateGuidePreview=function()
			local verticalHealth=setupFrame.healthOrientationValue=="VERTICAL"
			local verticalPower=setupFrame.powerOrientationValue=="VERTICAL"
			local playerClass
			if UnitClass then local _,classToken=UnitClass("player"); playerClass=classToken end
			local layout=Cell.groupLayoutProfiles[Cell.selectedGroupLayout] or Cell.groupLayoutProfiles.Default or {}
			local indicators=layout.indicators or {}
			local nameSettings=indicators.nameText or {}
			local healthSettings=indicators.healthText or {}
			local powerSettings=indicators.powerText or {}
			local nameFont,nameOutline=GetTextFontAndOutline(nameSettings.font,nameSettings.outline,Cell.nameFontIndex,Cell.nameFontOutline)
			local healthFont,healthOutline=GetTextFontAndOutline(healthSettings.font,healthSettings.outline,Cell.healthTextFontIndex,Cell.healthTextFontOutline)
			local powerFont,powerOutline=GetTextFontAndOutline(powerSettings.font,powerSettings.outline,Cell.powerTextFontIndex,Cell.powerTextFontOutline)
			local nameAnchor=nameSettings.anchor or "TOPLEFT"
			local healthAnchor=healthSettings.anchor or "BOTTOMRIGHT"
			local powerAnchor=powerSettings.anchor or "BOTTOM"
			unit.name:SetFont(nameFont.path,nameSettings.size or layout.nameFontSize or Cell.nameFontSize or 14,nameOutline.flag)
			unit.healthText:SetFont(healthFont.path,healthSettings.size or layout.healthTextFontSize or Cell.healthTextFontSize or 10,healthOutline.flag)
			unit.powerText:SetFont(powerFont.path,powerSettings.size or layout.powerTextFontSize or Cell.powerTextFontSize or 10,powerOutline.flag)
			unit.name:ClearAllPoints(); unit.name:SetPoint(nameAnchor,unit.health,nameAnchor,tonumber(nameSettings.x) or 2,tonumber(nameSettings.y) or -1)
			unit.name:SetText(UnitName and UnitName("player") or "Sample Player")
			unit.healthText:ClearAllPoints(); unit.healthText:SetPoint(healthAnchor,unit,healthAnchor,tonumber(healthSettings.x) or 0,tonumber(healthSettings.y) or 0)
			unit.powerText:ClearAllPoints(); unit.powerText:SetPoint(powerAnchor,unit,powerAnchor,tonumber(powerSettings.x) or 0,tonumber(powerSettings.y) or 0)
			unit.healthText:SetJustifyH(string.find(healthAnchor,"LEFT",1,true) and "LEFT" or (string.find(healthAnchor,"RIGHT",1,true) and "RIGHT" or "CENTER"))
			unit.powerText:SetJustifyH(string.find(powerAnchor,"LEFT",1,true) and "LEFT" or (string.find(powerAnchor,"RIGHT",1,true) and "RIGHT" or "CENTER"))
			if nameSettings.enabled==false then unit.name:Hide() else unit.name:Show() end
			if healthSettings.enabled==false then unit.healthText:Hide() else unit.healthText:Show() end
			if powerSettings.enabled==false then unit.powerText:Hide() else unit.powerText:Show() end
			unit.health:SetOrientation(verticalHealth and "VERTICAL" or "HORIZONTAL")
			unit.heal:SetOrientation(verticalHealth and "VERTICAL" or "HORIZONTAL")
			unit.health:ClearAllPoints(); unit.heal:ClearAllPoints(); unit.power:ClearAllPoints()
			-- Settings were anchored above using the same per-indicator profile as
			-- live frames; changing bar orientation must not reset text placement.
			if verticalPower then
				local side=setupFrame.powerSideValue=="RIGHT" and "RIGHT" or "LEFT"
				unit.power:SetWidth(4)
				unit.power:SetPoint("TOP"..side,unit,"TOP"..side,side=="RIGHT" and -2 or 2,-2)
				unit.power:SetPoint("BOTTOM"..side,unit,"BOTTOM"..side,side=="RIGHT" and -2 or 2,2)
				unit.health:SetPoint("TOPLEFT",unit,"TOPLEFT",side=="LEFT" and 8 or 2,-2)
				unit.health:SetPoint("BOTTOMRIGHT",unit,"BOTTOMRIGHT",side=="RIGHT" and -8 or -2,2)
				unit.powerText:SetPoint("BOTTOM",unit,"BOTTOM",0,3)
			else
				unit.health:SetPoint("TOPLEFT",unit,"TOPLEFT",0,0)
				unit.health:SetPoint("BOTTOMRIGHT",unit,"BOTTOMRIGHT",0,(Cell.powerBarHeight or 4)+2)
				unit.power:SetHeight(Cell.powerBarHeight or 4)
				unit.power:SetPoint("BOTTOMLEFT",unit,"BOTTOMLEFT",2,1); unit.power:SetPoint("BOTTOMRIGHT",unit,"BOTTOMRIGHT",-2,1)
				unit.powerText:SetPoint("BOTTOMRIGHT",unit,"BOTTOMRIGHT",-5,(Cell.powerBarHeight or 4)+2)
			end
			unit.heal:SetAllPoints(unit.health)
			local healthColor=Cell.customHealthColor or {.2,.72,.3}
			if Cell.healthColorMode=="class" and playerClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[playerClass] then
				local color=RAID_CLASS_COLORS[playerClass]; healthColor={color.r,color.g,color.b}
			end
			unit.health:SetStatusBarColor(healthColor[1],healthColor[2],healthColor[3],math.max(0,math.min(.95,(tonumber(Cell.healthColorAlpha) or 95)/100)))
			local loss=Cell.healthLossColorMode=="custom" and Cell.healthLossCustomColor or (Cell.healthLossColorMode=="classDark" and {.88,.28,.28} or {.62,.08,.08})
			unit.healthBackground:SetVertexColor(loss[1],loss[2],loss[3],math.max(0,math.min(.95,(tonumber(Cell.healthLossAlpha) or 95)/100)))
			if Cell.healPredictionEnabled then unit.heal:Show() else unit.heal:Hide() end
		end
		setupFrame:SetScript("OnUpdate",function(frame,elapsed)
			frame.guideElapsed=frame.guideElapsed+elapsed
			if frame.guideElapsed>=1.2 then
				frame.guideElapsed=0
				local unit=frame.guideUnit
				unit.guideHealth=unit.guideHealth or .72
				unit.guideHealth=unit.guideHealth<=.48 and .78 or unit.guideHealth-.08
				unit.health:SetValue(unit.guideHealth); unit.heal:SetValue(math.min(1,unit.guideHealth+.12)); unit.healthText:SetText(math.floor(unit.guideHealth*100).."%")
			end
		end)
		for _,dropdown in ipairs({setupFrame.profileDropdown,setupFrame.growthDropdown,setupFrame.healthOrientationDropdown,setupFrame.powerOrientationDropdown,setupFrame.powerSideDropdown}) do
			dropdown.cellLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"OUTLINE")
			for _,option in ipairs(dropdown.choiceOptions or {}) do option.cellLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE") end
		end
		setupFrame.finishButton.cellLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",14,"OUTLINE")
		setupFrame.skipButton.cellLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",14,"OUTLINE")
		setupFrame.skipButton.cellBackground:SetVertexColor(.40,.06,.06,1)
		setupFrame.skipButton:SetScript("OnEnter",function(button) button.cellBackground:SetVertexColor(.58,.10,.10,1); button.cellLabel:SetTextColor(1,.9,.9) end)
		setupFrame.skipButton:SetScript("OnLeave",function(button) button.cellBackground:SetVertexColor(.40,.06,.06,1); button.cellLabel:SetTextColor(.95,.86,.86) end)
		setupFrame:SetScript("OnMouseDown",function(frame,button) if button=="LeftButton" then frame:StartMoving() end end)
		setupFrame:SetScript("OnMouseUp",function(frame,button) if button=="LeftButton" then frame:StopMovingOrSizing() end end)
		setupFrame:SetScript("OnHide",function(frame)
			if frame._cellApplying then frame._cellApplying=nil; return end
			if frame._cellSnapshot then
				local s=frame._cellSnapshot
				for key,value in pairs(s.appearance) do Cell[key]=value end
				local p=Cell.groupLayoutProfiles[s.layoutKey]
				if p then p.direction=s.direction; p.healthBarOrientation=s.healthBarOrientation; p.powerBarOrientation=s.powerBarOrientation; p.powerBarSide=s.powerBarSide end
				Cell.healthBarOrientation=s.healthBarOrientation; Cell.powerBarOrientation=s.powerBarOrientation; Cell.powerBarSide=s.powerBarSide
				Cell:ApplyTextSettings(); Cell:ApplyAppearanceSettings(); Cell:ApplyButtonSize(); Cell:RefreshOptionsMenu()
				if Cell.optionsFrame and Cell.optionsFrame.UpdateIndicatorPreview then Cell.optionsFrame.UpdateIndicatorPreview() end
			end
		end)
		if UISpecialFrames then table.insert(UISpecialFrames,"NotCellSetupWizard") end
		self.setupWizardFrame=setupFrame
	end
	setupFrame.profileValue=state.setupProfile or self.appearancePreset or "Light Mode"
	local currentProfile=self.groupLayoutProfiles[self.selectedGroupLayout] or self.groupLayoutProfiles.Default
	setupFrame.growthValue=currentProfile.direction or "down-right"
	setupFrame.healthOrientationValue=currentProfile.healthBarOrientation or "HORIZONTAL"
	setupFrame.powerOrientationValue=currentProfile.powerBarOrientation or "HORIZONTAL"
	setupFrame.powerSideValue=currentProfile.powerBarSide or "LEFT"
	setupFrame.createHealerIndicators=state.setupCreateHealerIndicators and true or false
	setupFrame.hideBlizzardFrames=self.hideBlizzardFrames
	setupFrame.healPredictionCheckbox:SetChecked(self.healPredictionEnabled)
	setupFrame.profileDropdown:RefreshChoiceLabel(); setupFrame.growthDropdown:RefreshChoiceLabel(); setupFrame.healthOrientationDropdown:RefreshChoiceLabel(); setupFrame.powerOrientationDropdown:RefreshChoiceLabel(); setupFrame.powerSideDropdown:RefreshChoiceLabel()
	setupFrame.healerCheck:SetChecked(setupFrame.createHealerIndicators)
	setupFrame.blizzardCheck:SetChecked(setupFrame.hideBlizzardFrames)
	setupFrame:UpdateGuidePreview()
	self:UpdateSetupPowerSideVisibility()
	setupFrame.finishButton:SetScript("OnClick",function(frame)
		local db=GetCellSettingsDB()
		local profileName=setupFrame.profileValue or "Light Mode"
		self:ApplyAppearancePreset(profileName,true)
		local selectedProfile=self.groupLayoutProfiles[self.selectedGroupLayout] or self.groupLayoutProfiles.Default
		selectedProfile.direction=setupFrame.growthValue or "down-right"
		selectedProfile.healthBarOrientation=setupFrame.healthOrientationValue or "HORIZONTAL"
		selectedProfile.powerBarOrientation=setupFrame.powerOrientationValue or "HORIZONTAL"
		selectedProfile.powerBarSide=setupFrame.powerSideValue or "LEFT"
		if setupFrame.createHealerIndicators then self:CreateHealerIndicators() end
		self.hideBlizzardFrames=setupFrame.hideBlizzardFrames and true or false
		self:SetBlizzardFramesHidden(self.hideBlizzardFrames)
		local selectedLayout=self.selectedGroupLayout or "Default"
		db.hideBlizzardFrames=self.hideBlizzardFrames
		db.layoutAutoSwitch=self.layoutAutoSwitch
		db.layouts=self.groupLayoutProfiles; db.groupLayoutProfiles=self.groupLayoutProfiles
		db.selectedLayout=selectedLayout; db.selectedGroupLayout=selectedLayout
		state.setupProfile=profileName
		state.setupCreateHealerIndicators=setupFrame.createHealerIndicators and true or false
		state.setupGrowthDirection=nil; state.setupHealthFillOrientation=nil; state.setupPowerBarOrientation=nil; state.setupPowerBarSide=nil
		state.setupHideBlizzardFrames=nil; state.setupRole=nil; state.setupLayout=nil
		state.setupCompleted=true; state.setupSkipped=nil
		self.healthBarOrientation=selectedProfile.healthBarOrientation; self.powerBarOrientation=selectedProfile.powerBarOrientation; self.powerBarSide=selectedProfile.powerBarSide
		self.activeGroupLayout=nil
		self:ApplyButtonSize()
		SaveCellSettingsDB()
		self:UpdateFrames(); self:RefreshOptionsMenu()
		if self.optionsFrame and self.optionsFrame.UpdateIndicatorPreview then self.optionsFrame.UpdateIndicatorPreview() end
		setupFrame._cellSnapshot=nil
		setupFrame._cellApplying=true; setupFrame:Hide()
	end)
	setupFrame.skipButton:SetScript("OnClick",function()
		NotCellDB=type(NotCellDB)=="table" and NotCellDB or {}
		NotCellDB.setupCompleted=true
		NotCellDB.setupSkipped=true
		SaveCellSettingsDB()
		setupFrame:Hide()
	end)
	if self.activeOptionsDropdown then self.activeOptionsDropdown:Hide() end
	setupFrame._cellSnapshot=nil
	local snapshotProfile=self.groupLayoutProfiles[self.selectedGroupLayout] or self.groupLayoutProfiles.Default
	setupFrame._cellSnapshot={layoutKey=self.selectedGroupLayout,direction=snapshotProfile.direction,healthBarOrientation=snapshotProfile.healthBarOrientation,powerBarOrientation=snapshotProfile.powerBarOrientation,powerBarSide=snapshotProfile.powerBarSide,appearance={
		appearancePreset=self.appearancePreset,healthColorMode=self.healthColorMode,customHealthColor={self.customHealthColor[1],self.customHealthColor[2],self.customHealthColor[3]},healthLossColorMode=self.healthLossColorMode,healthLossCustomColor={self.healthLossCustomColor[1],self.healthLossCustomColor[2],self.healthLossCustomColor[3]},tappedColor={self.tappedColor[1],self.tappedColor[2],self.tappedColor[3]},healthTextColorMode=self.healthTextColorMode,healthTextCustomColor={self.healthTextCustomColor[1],self.healthTextCustomColor[2],self.healthTextCustomColor[3]},nameColorMode=self.nameColorMode,powerTextColorMode=self.powerTextColorMode,nameFontOutline=self.nameFontOutline,healthTextFontOutline=self.healthTextFontOutline,powerTextFontOutline=self.powerTextFontOutline,
	}}
	setupFrame:Show()
end

function Cell:ApplySetupLayoutChoices()
	local frame=self.setupWizardFrame
	local profile=self.groupLayoutProfiles[self.selectedGroupLayout] or self.groupLayoutProfiles.Default
	if not frame or not profile then return end
	profile.direction=frame.growthValue or "down-right"
	profile.healthBarOrientation=frame.healthOrientationValue or "HORIZONTAL"
	profile.powerBarOrientation=frame.powerOrientationValue or "HORIZONTAL"
	profile.powerBarSide=frame.powerSideValue or "LEFT"
	self.healthBarOrientation=profile.healthBarOrientation
	self.powerBarOrientation=profile.powerBarOrientation
	self.powerBarSide=profile.powerBarSide
	self.activeGroupLayout=nil
	self:ApplyButtonSize()
	self:UpdateFrames()
	self:RefreshOptionsMenu()
	if self.optionsFrame and self.optionsFrame.UpdateIndicatorPreview then self.optionsFrame.UpdateIndicatorPreview() end
	if frame.UpdateGuidePreview then frame.UpdateGuidePreview() end
end

function Cell:UpdateSetupPowerSideVisibility()
	local frame=self.setupWizardFrame
	if not frame then return end
	local visible=frame.powerOrientationValue=="VERTICAL"
	if visible then frame.powerSideLabel:Show(); frame.powerSideDropdown:Show()
	else frame.powerSideLabel:Hide(); frame.powerSideDropdown:Hide() end
end

function Cell:Initialize()
	if self.container then return end
	local container = CreateFrame("Frame", "NotCellContainer", UIParent)
	local spacingX, spacingY = GetDisplayedSpacing()
	container:SetWidth(self.columns * self.buttonWidth + (self.columns - 1) * spacingX)
	container:SetHeight(self.rows * self.buttonHeight + (self.rows - 1) * spacingY)
	NotCellVanillaDB = GetCellSettingsDB()
	local position = NotCellVanillaDB.containerPosition
	if position and position.x and position.y then
		container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", position.x, position.y)
	else
		container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	self.container = container
	container:SetMovable(true)
	container:EnableMouse(true)
	container:SetClampedToScreen(true)
	local handleWidth, handleHeight = 20, 13
	local function CreateHoverControl(name, label, color, offset)
		local control = CreateFrame("Button", name, container)
		control:SetWidth(handleWidth); control:SetHeight(handleHeight)
		control:SetPoint("BOTTOMLEFT", container, "TOPLEFT", offset * handleWidth, 2)
		control:SetFrameLevel(container:GetFrameLevel() + 20)
		local background = control:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints(control)
		background:SetTexture("Interface\\Buttons\\WHITE8X8")
		background:SetVertexColor(color[1], color[2], color[3], 0.95)
		local text = control:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("CENTER", control, "CENTER", 0, 0)
		text:SetText(label)
		control:Hide()
		return control
	end
	local moveHandle = CreateHoverControl("NotCellMoveHandle", "", {0.72, 0.10, 0.10}, 0)
	moveHandle:EnableMouse(true)
	moveHandle:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Drag to reposition. Left Click to open settings. Right Click to refresh unitframes.")
		GameTooltip:Show()
	end)
	moveHandle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	local movePositionLayout
	local function StopFrameMove()
		local wasDragging = Cell.isMovingFrames or moveHandle._cellWasDragged
		Cell.isMovingFrames = nil
		moveHandle._cellWasDragged = nil
		if Cell.container then
			Cell.container:StopMovingOrSizing()
			-- Save even if this arrived through OnMouseUp instead of OnDragStop;
			-- old clients differ in which drag callback they deliver to child buttons.
			if wasDragging or not Cell.framesLocked then SaveContainerPosition(wasDragging and movePositionLayout or nil) end
			if wasDragging then SaveContainerPositionAfterMove(movePositionLayout) end
		end
		movePositionLayout = nil
		Cell:UpdateMoverControls()
	end
	moveHandle:RegisterForDrag("LeftButton")
	moveHandle:RegisterForClicks("AnyUp")
	moveHandle:SetScript("OnMouseDown", function(self) self._cellWasDragged=nil end)
	moveHandle:SetScript("OnDragStart", function()
		if not Cell.framesLocked and Cell.container then
			movePositionLayout = GetPositionLayoutKey()
			moveHandle._cellWasDragged=true
			Cell.isMovingFrames = true
			Cell.container:StartMoving()
			Cell:UpdateMoverControls()
		end
	end)
	moveHandle:SetScript("OnDragStop", StopFrameMove)
	moveHandle:SetScript("OnMouseUp", StopFrameMove)
	moveHandle:SetScript("OnClick", function(self, mouseButton)
		if self._cellWasDragged then self._cellWasDragged=nil; return end
		if mouseButton == "RightButton" then
			Cell:UpdateFrames()
		elseif mouseButton == "LeftButton" then
			local options=Cell:CreateOptionsMenu()
			if options:IsShown() then options:Hide() else options:Show() end
		end
	end)
	self.moveHandle = moveHandle
	self.optionsHandle = nil
	self:UpdateMoverControls()

	for i = 1, 40 do
		self:CreateButton(i)
	end
	self:ApplyButtonSize(true)
	self:ApplyTextSettings()
	self:CreateMinimapButton()

	local updater = CreateFrame("Frame")
	updater:SetScript("OnUpdate", function(frame, elapsed)
		Cell.elapsed = Cell.elapsed + elapsed
		if Cell.isMovingFrames then SaveContainerPosition(nil, true) end
		if Cell.elapsed >= Cell.updateInterval then
			Cell.elapsed = 0
			Cell:UpdateBlizzardFrames()
			Cell:UpdateFrames()
			Cell:UpdateMoverControls()
		end
	end)
	self.updater = updater
	self:UpdateFrames()
end

local function MaybeShowFirstRunSetup()
	if Cell.initialSetupAutoShown or not Cell.firstRunSavedVariablesReady or not Cell.firstRunWorldReady then return end
	NotCellDB=type(NotCellDB)=="table" and NotCellDB or {}
	-- Saved profiles created before setup existed belong to returning users. A
	-- genuinely fresh SavedVariables file has no profile and must get the wizard.
	if NotCellDB.setupCompleted == nil and hasSavedCellProfile then
		NotCellDB.setupCompleted=true
		SaveCellSettingsDB()
	end
	if NotCellDB.setupCompleted == true then Cell.initialSetupAutoShown=true; return true end
	-- Initialize the fresh-install defaults at the same point as the first
	-- automatic setup prompt. The independent marker is written immediately, so
	-- cancelling/reloading the wizard cannot cause defaults to be reapplied.
	if not NotCellDB.initialDefaultsApplied then
		local settings=GetCellSettingsDB()
		if hasSavedCellProfile then
			NotCellDB.initialDefaultsApplied=true
			SaveCellSettingsDB()
		else
			Cell.backgroundAlpha=50
			Cell.healthColorMode="class"
			Cell.healthLossColorMode="classDark"
			Cell.targetHighlightEnabled=false
			Cell.mouseoverHighlightEnabled=true
			Cell.mouseoverHighlightColor={1,1,1}
			settings.backgroundAlpha=50
			settings.healthColorMode="class"
			settings.healthLossColorMode="classDark"
			settings.targetHighlightEnabled=false
			settings.mouseoverHighlightEnabled=true
			settings.mouseoverHighlightColor={1,1,1}
			settings.previewOnlySelectedIndicator=true
			-- Indicator settings live on each layout profile. Seed every layout
			-- once so opening or switching layouts cannot reveal a different set
			-- of first-run defaults later.
			for _,layoutKey in ipairs(Cell.groupLayoutNames or {"Default"}) do
				local profile=Cell.groupLayoutProfiles[layoutKey]
				if profile then
					profile.indicators=type(profile.indicators)=="table" and profile.indicators or {}
					local function setIndicator(key, defaults)
						local value=profile.indicators[key]
						if type(value)~="table" then value={}; profile.indicators[key]=value end
						for field,setting in pairs(defaults) do value[field]=setting end
						value.anchorInitialized=true
					end
					setIndicator("nameText",{anchor="TOPLEFT"})
					setIndicator("healthText",{anchor="RIGHT",x=-4})
					setIndicator("statusText",{anchor="CENTER",size=12})
					setIndicator("leaderIcon",{anchor="TOPRIGHT",size=15,iconSize=15,x=-15,y=5})
					setIndicator("roleIcon",{anchor="TOPRIGHT",size=15,iconSize=15,y=5})
					setIndicator("raidIcon",{anchor="LEFT",size=20,iconSize=20,x=-5})
					setIndicator("buffs",{enabled=false})
					setIndicator("debuffs",{enabled=true,anchor="BOTTOMRIGHT",y=5,orientation="left"})
					setIndicator("healerBuffs",{enabled=false,anchor="BOTTOMRIGHT",y=5,size=14,iconSize=14,orientation="right"})
				end
			end
			Cell.debuffFillMode="solid"
			Cell.debuffBorderEnabled=false
			settings.debuffFillMode="solid"
			settings.debuffBorderEnabled=false
			Cell.activeClickCastProfile="common"
			Cell.clickCasts=Cell.clickCastProfiles.common or {}
			Cell.clickCasts["1"]={kind="target",text=""}
			Cell.clickCasts["2"]={kind="menu",text=""}
			Cell.clickCastProfiles.common=Cell.clickCasts
			NotCellDB.initialDefaultsApplied=true
			SaveClickCastSettings()
			SaveCellSettingsDB()
			Cell:ApplyAppearanceSettings()
			Cell:ApplyTextSettings()
			Cell:UpdateFrames()
			Cell:ApplyAllClickCastSettings()
			Cell:RefreshOptionsMenu()
			if Cell.optionsFrame and Cell.optionsFrame.UpdateIndicatorPreview then Cell.optionsFrame.UpdateIndicatorPreview() end
		end
	end
	local wizard=Cell.setupWizardFrame
	if wizard and wizard:IsShown() then
		if wizard:IsVisible() then Cell.initialSetupAutoShown=true; return true end
		return false
	end
	Cell:ShowSetupWizard()
	-- IsShown() alone is insufficient during the loading transition: the dialog
	-- may be flagged shown while UIParent is still hidden. Wait for visibility.
	if Cell.setupWizardFrame and Cell.setupWizardFrame:IsVisible() then
		Cell.initialSetupAutoShown=true
		return true
	end
	return false
end

local eventFrame = CreateFrame("Frame")
local function QueueFirstRunSetupCheck()
	if Cell.firstRunSetupCheckQueued or Cell.initialSetupAutoShown
		or not Cell.firstRunSavedVariablesReady or not Cell.firstRunWorldReady then return end
	Cell.firstRunSetupCheckQueued=true
	local wait=0
	eventFrame:SetScript("OnUpdate",function(frame,elapsed)
		wait=wait+elapsed
		if wait>=0.20 then
			wait=0
			if MaybeShowFirstRunSetup() then
				frame:SetScript("OnUpdate",nil)
				Cell.firstRunSetupCheckQueued=nil
			end
		end
	end)
end
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
eventFrame:RegisterEvent("UNIT_MANA")
eventFrame:RegisterEvent("UNIT_RAGE")
eventFrame:RegisterEvent("UNIT_FOCUS")
eventFrame:RegisterEvent("UNIT_ENERGY")
eventFrame:RegisterEvent("UNIT_HAPPINESS")
eventFrame:RegisterEvent("UNIT_MAXMANA")
eventFrame:RegisterEvent("UNIT_MAXRAGE")
eventFrame:RegisterEvent("UNIT_MAXFOCUS")
eventFrame:RegisterEvent("UNIT_MAXENERGY")
eventFrame:RegisterEvent("UNIT_MAXHAPPINESS")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:SetScript("OnEvent", function(frame, event, arg1)
	if event=="UNIT_AURA" then
		if arg1 then missingAuraCache[arg1]=nil else for unit in pairs(missingAuraCache) do missingAuraCache[unit]=nil end end
	elseif event=="PLAYER_ENTERING_WORLD" or event=="PARTY_MEMBERS_CHANGED" or event=="RAID_ROSTER_UPDATE" then
		for unit in pairs(missingAuraCache) do missingAuraCache[unit]=nil end
		missingBuffBlesserCount=nil
	end
	if event == "ADDON_LOADED" then
		RefreshLegacyHealComm()
		if arg1 == addonName or arg1 == "NotCell" then
			Cell.firstRunSavedVariablesReady=true
			QueueFirstRunSetupCheck()
		end
		return
	end
	if event == "PLAYER_LOGOUT" then
		if Cell.container then SaveContainerPosition(Cell.activePositionLayout or GetPositionLayoutKey()) end
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		if Cell.tooltipsHideInCombat then Cell:HideUnitFrameTooltip() end
		return
	end
	if event == "VARIABLES_LOADED" then
		Cell.firstRunSavedVariablesReady=true
		local settings = GetCellSettingsDB()
		local characterSettings = GetCharacterClickCastDB()
		Cell.clickCastCharacterKey = (GetRealmName and GetRealmName() or "Realm") .. "-" .. (UnitName and UnitName("player") or "Character")
		local legacyClickCastProfiles = type(settings.clickCastProfiles) == "table" and settings.clickCastProfiles or nil
		local legacyClickCastData = legacyClickCastProfiles ~= nil or type(settings.clickCasts) == "table"
		Cell.clickCastProfiles = type(characterSettings.vanillaClickCastProfiles) == "table" and characterSettings.vanillaClickCastProfiles
			or legacyClickCastProfiles or Cell.clickCastProfiles or {}
		Cell.clickCastProfiles.common = Cell.clickCastProfiles.common or (type(characterSettings.vanillaClickCasts) == "table" and characterSettings.vanillaClickCasts
			or (type(settings.clickCasts) == "table" and settings.clickCasts or {}))
		Cell.clickCastProfiles[Cell.clickCastCharacterKey] = Cell.clickCastProfiles[Cell.clickCastCharacterKey] or {}
		Cell.clickCastProfileNames = type(characterSettings.vanillaClickCastProfileNames) == "table" and characterSettings.vanillaClickCastProfileNames
			or (type(settings.clickCastProfileNames) == "table" and settings.clickCastProfileNames) or Cell.clickCastProfileNames or {}
		Cell.clickCastProfileNames.common = "Common"
		Cell.clickCastProfileNames[Cell.clickCastCharacterKey] = Cell.clickCastProfileNames[Cell.clickCastCharacterKey] or (UnitName and UnitName("player") or "This character")
		Cell.activeClickCastProfile = characterSettings.vanillaActiveClickCastProfile or settings.activeClickCastProfile or Cell.activeClickCastProfile or "common"
		if not Cell.clickCastProfiles[Cell.activeClickCastProfile] then Cell.activeClickCastProfile = "common" end
		Cell.clickCasts = Cell.clickCastProfiles[Cell.activeClickCastProfile]
		-- Move legacy shared click-casting data into this character's database.
		-- New edits are saved only to NotCellCharacterDB.
		if type(characterSettings.vanillaClickCastProfiles) ~= "table" and legacyClickCastData then
			SaveClickCastSettings()
		end
		Cell.appearancePreset = settings.appearancePreset
		Cell.healthColorMode = settings.healthColorMode or "custom"
		if Cell.healthColorMode ~= "custom" and Cell.healthColorMode ~= "class" and Cell.healthColorMode ~= "value" then Cell.healthColorMode = "custom" end
		Cell.customHealthColor = settings.customHealthColor or {0.20, 0.72, 0.30}
		Cell.healthLossColorMode = settings.healthLossColorMode or "classLight"
		if Cell.healthLossColorMode ~= "classLight" and Cell.healthLossColorMode ~= "classDark" and Cell.healthLossColorMode ~= "custom" then Cell.healthLossColorMode = "classLight" end
		Cell.healthLossCustomColor = settings.healthLossCustomColor or {0.62, 0.08, 0.08}
		Cell.healthColorAlpha = math.max(0, math.min(95, tonumber(settings.healthColorAlpha) or 95))
		Cell.healthLossAlpha = math.max(0, math.min(95, tonumber(settings.healthLossAlpha) or 95))
		Cell.powerColorMode = settings.powerColorMode or "power"
		if Cell.powerColorMode ~= "power" and Cell.powerColorMode ~= "class" and Cell.powerColorMode ~= "custom" then Cell.powerColorMode = "power" end
		Cell.powerBarCustomColor = settings.powerBarCustomColor or {0.1, 0.35, 0.95}
		Cell.powerColorAlpha = math.max(0, math.min(95, tonumber(settings.powerColorAlpha) or 95))
		Cell.backgroundAlpha = math.max(0, math.min(95, tonumber(settings.backgroundAlpha) or 95))
		Cell.outOfRangeAlpha = math.max(0, math.min(95, tonumber(settings.outOfRangeAlpha) or 45))
		Cell.unitTexture = settings.unitTexture or "Interface\\Buttons\\WHITE8X8"
		Cell.barAnimationMode = NormalizeBarAnimationMode(settings.barAnimationMode, settings.barAnimationDuration)
		Cell.targetHighlightColor = settings.targetHighlightColor or {1, 0.68, 0.12}
		Cell.mouseoverHighlightColor = settings.mouseoverHighlightColor or {0.15, 0.55, 1}
		Cell.targetHighlightEnabled = settings.targetHighlightEnabled ~= false
		Cell.mouseoverHighlightEnabled = settings.mouseoverHighlightEnabled ~= false
		Cell.healPredictionColor = settings.healPredictionColor or {0.20, 1.00, 0.35}
		Cell.healPredictionEnabled = settings.healPredictionEnabled ~= false
		Cell.optionsScale = NormalizeOptionsScale(settings.optionsScale)
		if Cell.optionsFrame and Cell.optionsFrame._cellApplyOptionsScale then Cell.optionsFrame._cellApplyOptionsScale(Cell.optionsScale / 100)
		elseif Cell.optionsFrame then Cell.optionsFrame:SetScale(Cell.optionsScale / 100) end
		Cell.deadBackdropEnabled = settings.deadBackdropEnabled and true or false
		Cell.customDeadBackdrop = settings.customDeadBackdrop or {0.42, 0.42, 0.42}
		Cell.hideBlizzardFrames = settings.hideBlizzardFrames ~= false
		Cell.buttonWidth = math.max(40, math.min(300, tonumber(settings.buttonWidth) or 130))
		Cell.buttonHeight = math.max(32, math.min(120, tonumber(settings.buttonHeight) or 50))
		Cell.powerBarHeight = math.max(2, math.min(12, tonumber(settings.powerBarHeight) or Cell.powerBarHeight or 4))
		Cell.autoGroupLayouts = settings.autoGroupLayouts and true or false
		local oldProfiles = type(settings.groupLayoutProfiles) == "table" and settings.groupLayoutProfiles or Cell.groupLayoutProfiles or {}
		Cell.groupLayoutProfiles = type(settings.layouts) == "table" and settings.layouts or oldProfiles
		if not Cell.groupLayoutProfiles.Default then
			local start = oldProfiles.party or oldProfiles[settings.selectedGroupLayout] or {}
			Cell.groupLayoutProfiles.Default = start
			for key, profile in pairs(oldProfiles) do
				if type(key) == "string" and type(profile) == "table" and key ~= "solo" and key ~= "party" and key ~= "raidOutdoor" and key ~= "raid10" and key ~= "raid25" and key ~= "raid40" then Cell.groupLayoutProfiles[key] = profile end
			end
		end
		Cell.selectedGroupLayout = settings.selectedLayout or settings.selectedGroupLayout or "Default"
		Cell:RefreshLayoutProfiles(Cell.groupLayoutProfiles)
		Cell.layoutAutoSwitch = type(settings.layoutAutoSwitch) == "table" and settings.layoutAutoSwitch or Cell.layoutAutoSwitch or {}
		for groupType, defaultLayout in pairs({solo="Default", party="Default", raid_outdoor="Default", raid10="Default", raid25="Default", raid40="Default"}) do
			local mapped = Cell.layoutAutoSwitch[groupType]
			if mapped ~= "hide" and not Cell.groupLayoutProfiles[mapped] then
				local isOldBuiltIn = mapped == "solo" or mapped == "party" or mapped == "raidOutdoor" or mapped == "raid10" or mapped == "raid25" or mapped == "raid40"
				Cell.layoutAutoSwitch[groupType] = isOldBuiltIn and "Default" or defaultLayout
			end
		end
		for _, key in ipairs(Cell.groupLayoutNames) do
			local profile = Cell.groupLayoutProfiles[key]
			if type(profile) ~= "table" then profile = {}; Cell.groupLayoutProfiles[key] = profile end
			profile.width = math.max(40, math.min(300, tonumber(profile.width) or Cell.buttonWidth))
			profile.height = math.max(32, math.min(120, tonumber(profile.height) or Cell.buttonHeight))
			profile.powerBarHeight = math.max(2, math.min(12, tonumber(profile.powerBarHeight) or Cell.powerBarHeight))
			profile.healthBarOrientation = profile.healthBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
			profile.powerBarOrientation = profile.powerBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
			profile.powerBarSide = profile.powerBarSide == "RIGHT" and "RIGHT" or "LEFT"
			profile.nameFontSize = math.max(10, math.min(20, tonumber(profile.nameFontSize) or Cell.nameFontSize))
			profile.healthTextFontSize = math.max(8, math.min(20, tonumber(profile.healthTextFontSize) or Cell.healthTextFontSize))
			profile.powerTextFontSize = math.max(8, math.min(20, tonumber(profile.powerTextFontSize) or Cell.powerTextFontSize))
			profile.groupsPerLine = math.max(1, math.min(8, tonumber(profile.groupsPerLine) or 4))
			profile.groupFilter = type(profile.groupFilter) == "table" and profile.groupFilter or {}
			for group = 1, 8 do if profile.groupFilter[group] == nil then profile.groupFilter[group] = true end end
			profile.direction = profile.direction or ((profile.growth == "right-down" or profile.growth == "left-down") and "right-down" or "down-right")
			profile.spacingX = math.max(0, math.min(100, tonumber(profile.spacingX) or Cell.horizontalGap or 5))
			profile.spacingY = math.max(0, math.min(100, tonumber(profile.spacingY) or Cell.verticalGap or 4))
			local savedPosition = settings.containerPosition
			if settings.positionLayoutKey == key and type(savedPosition) == "table"
				and tonumber(savedPosition.x) and tonumber(savedPosition.y) then
				-- The global position is authoritative for its recorded layout;
				-- older per-profile coordinates must not overwrite a newer drag.
				profile.position = {x = tonumber(savedPosition.x), y = tonumber(savedPosition.y)}
			elseif type(profile.position) ~= "table" and type(savedPosition) == "table"
				and tonumber(savedPosition.x) and tonumber(savedPosition.y) then
				profile.position = {x = tonumber(savedPosition.x), y = tonumber(savedPosition.y)}
			end
		end
		Cell.selectedGroupLayout = settings.selectedLayout or settings.selectedGroupLayout or "Default"
		if not Cell.groupLayoutProfiles[Cell.selectedGroupLayout] then Cell.selectedGroupLayout = "Default" end
		local selectedProfile = Cell.groupLayoutProfiles[Cell.selectedGroupLayout]
		if selectedProfile then
			Cell.buttonWidth, Cell.buttonHeight = selectedProfile.width, selectedProfile.height
			Cell.powerBarHeight = selectedProfile.powerBarHeight
			Cell.healthBarOrientation = selectedProfile.healthBarOrientation or "HORIZONTAL"
			Cell.powerBarOrientation = selectedProfile.powerBarOrientation or "HORIZONTAL"
			Cell.powerBarSide = selectedProfile.powerBarSide or "LEFT"
		end
		Cell.rangeFadeEnabled = true
		LoadDebuffSettings(settings)
		Cell.nameColorMode = settings.nameColorMode == "custom" and "custom" or "class"
		Cell.nameCustomColor = settings.nameCustomColor or {1, 1, 1}
		Cell.nameFontIndex = math.max(1, math.min(table.getn(nameFonts), tonumber(settings.nameFontIndex) or 1))
		Cell.nameFontSize = math.max(10, math.min(20, tonumber(settings.nameFontSize) or 14))
		Cell.nameFontOutline = math.max(1, math.min(table.getn(nameOutlines), tonumber(settings.nameFontOutline) or 2))
		Cell.showHealthValues = settings.showHealthValues ~= false
		Cell.healthValueFormat = settings.healthValueFormat == "absolute" and "absolute" or "percent"
		Cell.healthTextFontIndex = math.max(1, math.min(table.getn(nameFonts), tonumber(settings.healthTextFontIndex) or 1))
		Cell.healthTextFontSize = math.max(8, math.min(20, tonumber(settings.healthTextFontSize) or 10))
		Cell.healthTextFontOutline = math.max(1, math.min(table.getn(nameOutlines), tonumber(settings.healthTextFontOutline) or 2))
		Cell.healthTextColorMode = settings.healthTextColorMode or "custom"
		if Cell.healthTextColorMode ~= "custom" and Cell.healthTextColorMode ~= "class" and Cell.healthTextColorMode ~= "value" then Cell.healthTextColorMode = "custom" end
		Cell.healthTextCustomColor = settings.healthTextCustomColor or {1, 1, 1}
		Cell.healthTextAnchor = settings.healthTextAnchor or "BOTTOMRIGHT"
		Cell.showPowerValues = settings.showPowerValues ~= false
		Cell.powerValueFormat = settings.powerValueFormat == "absolute" and "absolute" or "percent"
		Cell.powerTextFontIndex = math.max(1, math.min(table.getn(nameFonts), tonumber(settings.powerTextFontIndex) or 1))
		Cell.powerTextFontSize = math.max(8, math.min(20, tonumber(settings.powerTextFontSize) or 10))
		Cell.powerTextFontOutline = math.max(1, math.min(table.getn(nameOutlines), tonumber(settings.powerTextFontOutline) or 2))
		Cell.powerTextColorMode = settings.powerTextColorMode or "custom"
		if Cell.powerTextColorMode ~= "power" and Cell.powerTextColorMode ~= "class" and Cell.powerTextColorMode ~= "custom" then Cell.powerTextColorMode = "custom" end
		Cell.powerTextCustomColor = settings.powerTextCustomColor or {1, 1, 1}
		Cell.powerTextAnchor = settings.powerTextAnchor or "BOTTOM"
		Cell.showSolo = settings.showSolo ~= false
		Cell.showParty = settings.showParty ~= false
		Cell.tooltipsEnabled = settings.tooltipsEnabled ~= false
		Cell.tooltipsHideInCombat = settings.tooltipsHideInCombat and true or false
		if not settings.framesLockPreferenceVersion then
			settings.framesLocked = false
			settings.framesLockPreferenceVersion = 1
		end
		Cell.framesLocked = settings.framesLocked and true or false
		settings.framesLocked = Cell.framesLocked
		settings.layouts = Cell.groupLayoutProfiles
		settings.groupLayoutProfiles = Cell.groupLayoutProfiles
		settings.selectedLayout = Cell.selectedGroupLayout
			settings.layoutAutoSwitch = Cell.layoutAutoSwitch
			settings.hideBlizzardFrames = Cell.hideBlizzardFrames
		SaveCellSettingsDB()
		Cell.tappedColor = settings.tappedColor or {0.08, 0.08, 0.08}
		local savedPosition = settings.containerPosition
		if type(savedPosition) == "table" and tonumber(savedPosition.x) and tonumber(savedPosition.y) then
			-- Refresh the in-memory position even if Initialize has not created
			-- the container yet; its later first layout pass reads this cache.
			initialContainerPosition = {x = tonumber(savedPosition.x), y = tonumber(savedPosition.y)}
		end
		if Cell.container then
			if initialContainerPosition then
				Cell.container:ClearAllPoints()
				Cell.container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", initialContainerPosition.x, initialContainerPosition.y)
			end
			Cell:SetFramesLocked(Cell.framesLocked)
			Cell:SetBlizzardFramesHidden(Cell.hideBlizzardFrames)
			for i = 1, table.getn(Cell.buttons) do
				local button = Cell.buttons[i]
				if button.healthBackground then button.healthBackground:SetTexture(Cell.tappedColor[1], Cell.tappedColor[2], Cell.tappedColor[3], 1) end
			end
			Cell.activePositionLayout = nil
			Cell:ApplyButtonSize()
			Cell:ApplyTextSettings()
			Cell:ApplyAppearanceSettings()
			Cell:UpdateFrames()
		end
		if Cell.optionsFrame and settings.optionsPosition then
			local frame = Cell.optionsFrame
			local visualWidth = frame:GetWidth() * frame:GetScale()
			local visualHeight = frame:GetHeight() * frame:GetScale()
			local left = math.max(0, math.min(settings.optionsPosition.x, UIParent:GetWidth() - visualWidth))
			local bottom = math.max(0, math.min(settings.optionsPosition.y, UIParent:GetHeight() - visualHeight))
			Cell.optionsFrame:ClearAllPoints()
			Cell.optionsFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
		end
		if Cell.minimapButton then
			Cell.minimapButton.UpdateCellPosition()
			if GetMinimapButtonDB().shown then Cell.minimapButton:Show() else Cell.minimapButton:Hide() end
		end
		Cell:RefreshOptionsMenu()
		-- PLAYER_LOGIN can precede VARIABLES_LOADED in this client's loader.
		-- Once the saved profile is resolved, refresh all protected click attributes.
		if Cell.container then Cell:ApplyAllClickCastSettings() end
		QueueFirstRunSetupCheck()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
		Cell:ApplyBlizzardClickCasts(true)
	end
	if not Cell.container then
		Cell:Initialize()
	else
		Cell:UpdateFrames()
	end
	if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then Cell:ApplyAllClickCastSettings() end
	if event == "PLAYER_ENTERING_WORLD" then
		Cell.firstRunWorldReady=true
		QueueFirstRunSetupCheck()
	end
end)

SLASH_NOTCELL1 = "/notcell"
SlashCmdList["NOTCELL"] = function(message)
	message = string.lower(message or "")
	-- SavedVariables can be absent on some Vanilla/Enhanced Client loader paths.
	-- Recreate the table before writing settings so color commands never error.
	NotCellVanillaDB = GetCellSettingsDB()
	local colorMode, hexColor = string.match(message, "^healthcolor%s+(%a+)%s*(%S*)$")
	if message == "options" or message == "config" or message == "opt" then
		Cell:Initialize()
		Cell:CreateOptionsMenu():Show()
	elseif message == "setup" then
		Cell:ShowSetupWizard()
	elseif message == "minimap" then
		Cell:SetMinimapButtonShown(true)
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: minimap button is shown")
	elseif message == "minimap show" then
		Cell:SetMinimapButtonShown(true)
	elseif message == "blizz hide" then
		Cell:SetBlizzardFramesHidden(true)
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: group-frame hiding active for " .. Cell:UpdateBlizzardFrames() .. " matches (player frame excluded). Use /notcell blizz show to restore.")
	elseif message == "blizz show" then
		Cell:SetBlizzardFramesHidden(false)
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: Blizzard player and party frames restored")
	elseif colorMode == "class" then
		Cell.healthColorMode = "class"
		NotCellVanillaDB = GetCellSettingsDB()
		NotCellVanillaDB.healthColorMode = "class"
		SaveCellSettingsDB()
		Cell:UpdateFrames()
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: health bars use class colors")
	elseif colorMode == "custom" then
		hexColor = string.gsub(hexColor or "", "^#", "")
		if string.len(hexColor) == 6 then
			local red = tonumber(string.sub(hexColor, 1, 2), 16)
			local green = tonumber(string.sub(hexColor, 3, 4), 16)
			local blue = tonumber(string.sub(hexColor, 5, 6), 16)
			if red and green and blue then
				Cell.customHealthColor = {red / 255, green / 255, blue / 255}
				NotCellVanillaDB = GetCellSettingsDB()
				NotCellVanillaDB.customHealthColor = Cell.customHealthColor
			end
		end
		Cell.healthColorMode = "custom"
		NotCellVanillaDB = GetCellSettingsDB()
		NotCellVanillaDB.healthColorMode = "custom"
		SaveCellSettingsDB()
		Cell:UpdateFrames()
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: health bars use custom color; optional format: /notcell healthcolor custom RRGGBB")
	elseif message == "hide" then
		if Cell.container then Cell.container:Hide() end
	elseif message == "show" then
		if Cell.container then Cell.container:Show() end
		Cell:UpdateFrames()
	elseif message == "position" then
		local frame = Cell.container or getglobal("NotCellContainer")
		local left, bottom = frame and frame:GetLeft(), frame and frame:GetBottom()
		local saved = NotCellVanillaDB.containerPosition or {}
		DEFAULT_CHAT_FRAME:AddMessage(string.format("NotCell position: live=(%s,%s) size=(%s,%s) screen=(%s,%s) saved=(%s,%s) key=%s active=%s moving=%s locked=%s", tostring(left), tostring(bottom), tostring(frame and frame:GetWidth()), tostring(frame and frame:GetHeight()), tostring(UIParent:GetWidth()), tostring(UIParent:GetHeight()), tostring(saved.x), tostring(saved.y), tostring(NotCellVanillaDB.positionLayoutKey), tostring(Cell.activePositionLayout), tostring(Cell.isMovingFrames), tostring(Cell.framesLocked)))
	elseif message == "preview" then
		Cell.preview = not Cell.preview
		Cell.previewMode = Cell.preview and "party" or nil
		Cell:UpdateFrames()
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: " .. (Cell.preview and "party preview shown" or "real units shown"))
	elseif message == "preview status" then
		Cell.preview = true
		Cell.previewMode = "status"
		Cell.previewLimit = 4
		Cell:UpdateFrames()
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: dead, ghost, offline, and out-of-range samples shown")
	elseif message == "preview party" or message == "preview raid" or message == "preview raid10" or message == "preview raid20" or message == "preview raid25" then
		Cell.preview = true
		Cell.previewMode = "party"
		Cell.previewLimit = 5
		if message == "preview raid10" then
			Cell.previewMode = "raid"
			Cell.previewLimit = 10
		elseif message == "preview raid20" then
			Cell.previewMode = "raid"
			Cell.previewLimit = 20
		elseif message == "preview raid25" then
			Cell.previewMode = "raid"
			Cell.previewLimit = 25
		elseif message == "preview raid" then
			Cell.previewMode = "raid"
			Cell.previewLimit = 40
		end
		Cell:UpdateFrames()
		DEFAULT_CHAT_FRAME:AddMessage("NotCell: sample " .. Cell.previewMode .. " (" .. Cell.previewLimit .. " frames) shown")
	else
		DEFAULT_CHAT_FRAME:AddMessage("NotCell commands: /notcell opt, /notcell setup, /notcell minimap show, /notcell blizz hide|show, /notcell healthcolor class|custom RRGGBB, /notcell show|hide, /notcell preview [party|status|raid10|raid20|raid25|raid]")
	end
end
