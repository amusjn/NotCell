-- Layout-specific indicator editor for the Vanilla options panel.
local Cell = _G.NotCell
if not Cell then return end
Cell.OptionPageBuilders = Cell.OptionPageBuilders or {}

Cell.OptionPageBuilders.indicators = function(context)
	local Cell, panel, page = context.Cell, context.panel, context.pages.indicators
	local AddButton, AddCheckbox, AddSlider, AddDropdown, AddTitle = context.AddOptionsButton, context.AddOptionsCheckbox, context.AddOptionsSlider, context.AddChoiceDropdown, context.AddSectionTitle
	local sliderPitch = Cell.OptionsSliderLayout and Cell.OptionsSliderLayout.rowPitch or 60
	local AddOptionsDivider = context.AddOptionsDivider
	local SetPageContentExtent = context.SetPageContentExtent
	local RegisterAccentRefresher, GetUIAccentColor = context.RegisterAccentRefresher, context.GetUIAccentColor
	local StyleDropdownButton, StyleDropdownMenu = context.StyleOptionsDropdownButton, context.StyleOptionsDropdownMenu
	local indicators = {
		{name="Name text", key="nameText", kind="text"}, {name="Health text", key="healthText", kind="text"},
		{name="Power text", key="powerText", kind="text"}, {name="Status text", key="statusText", kind="text"},
		{name="Status icon", key="statusIcon", kind="icon"}, {name="Role icon", key="roleIcon", kind="icon"},
		{name="Leader icon", key="leaderIcon", kind="icon"}, {name="Ready Check icon", key="readyCheckIcon", kind="icon"},
		{name="Raid Icon", key="raidIcon", kind="icon"}, {name="Buffs", key="buffs", kind="aura"}, {name="Debuffs", key="debuffs", kind="aura"}, {name="Missing buffs", key="missingBuffs", kind="aura"}, {name="Healers", key="healerBuffs", kind="aura"},
	}
	local anchors = {{name="TOPLEFT",value="TOPLEFT"},{name="TOP",value="TOP"},{name="TOPRIGHT",value="TOPRIGHT"},{name="LEFT",value="LEFT"},{name="CENTER",value="CENTER"},{name="RIGHT",value="RIGHT"},{name="BOTTOMLEFT",value="BOTTOMLEFT"},{name="BOTTOM",value="BOTTOM"},{name="BOTTOMRIGHT",value="BOTTOMRIGHT"}}
	local iconGrowthChoices = {{name="Right",value="right"},{name="Left",value="left"},{name="Up",value="up"},{name="Down",value="down"}}
	local debuffDirections = {{name="Right",value="left-to-right"},{name="Left",value="right-to-left"},{name="Up",value="down-to-up"},{name="Down",value="up-to-down"}}
	local debuffDisplayModes = {{name="None",value="none"},{name="Border Glow",value="border"},{name="Solid Tint",value="solid"},{name="Gradient",value="gradient"}}
	local iconGrowthLabels = {right="Right",left="Left",up="Up",down="Down",["right-to-left"]="Left"}
	local fonts = {}
	for i, entry in ipairs(Cell.indicatorFonts or {{name="Friz Quadrata"},{name="Arial Narrow"},{name="Morpheus"},{name="Skurri"}}) do fonts[i]={name=entry.name,value=i,path=entry.path,previewType="font"} end
	local outlines = {{name="None",value=1},{name="Outline",value=2},{name="Thick outline",value=3}}
	local layoutNames = Cell.groupLayoutNames or {"Default"}
	local layoutLabels = Cell.groupLayoutLabels or {}
	local selectedKey, selectedItem = Cell.selectedIndicatorKey or "nameText", 1
	local defaultAnchors = {nameText="TOPLEFT", healthText="RIGHT", powerText="BOTTOM", statusText="CENTER", statusIcon="CENTER", roleIcon="TOPLEFT", leaderIcon="TOPRIGHT", readyCheckIcon="CENTER", raidIcon="TOPRIGHT", buffs="CENTER", debuffs="CENTER", missingBuffs="CENTER", healerBuffs="TOPRIGHT"}
	-- Starter whitelist for the Buffs indicator. These are aura spell IDs, tagged
	-- by provider class so the current-class option can filter them safely.
	local defaultBuffSpellIDs = {
		{class="MAGE",ids={1459,23028,604}}, {class="PRIEST",ids={1243,21562,14752,27681,976,27683,6346}},
		{class="DRUID",ids={1126,21849,467}}, {class="PALADIN",ids={19740,25782,20217,25898,19742,25894,1038,25895,19977,25890,20911,25899,465,7294,19746,8185}},
		{class="SHAMAN",ids={8076,8072,8836,5677,5672,25909,10596,8185,8182,8177,16191,2825}},
		{class="WARRIOR",ids={6673}}, {class="WARLOCK",ids={20707,5697,132}}, {class="HUNTER",ids={19506,13165,13163,20043,5118,13159,13161}},
	}
	local function MakeDefaultBuffList()
		local spells={}
		for _,group in ipairs(defaultBuffSpellIDs) do
			for _,id in ipairs(group.ids) do
				if GetSpellInfo then local name,_,icon=GetSpellInfo(id); if name and icon then spells[table.getn(spells)+1]={id=id,name=name,icon=icon,class=group.class} end end
			end
		end
		return spells
	end
	local function InitializeIndicatorSettings(v, key, kind)
		if not v.anchorInitialized then
			-- Migrate the old raid-mark default once. User-selected TOP must remain
			-- a valid anchor after settings have been initialized.
			if key=="raidIcon" and v.anchor=="TOP" and (tonumber(v.x) or 0)==0 and (tonumber(v.y) or 0)==0 then v.anchor="TOPRIGHT" end
			if not v.anchor or (v.anchor == "CENTER" and (tonumber(v.x) or 0) == 0 and (tonumber(v.y) or 0) == 0) then v.anchor=defaultAnchors[key] or "CENTER" end
			v.anchorInitialized=true
		end
		v.x=tonumber(v.x) or 0; v.y=tonumber(v.y) or 0
		v.font=tonumber(v.font) or Cell.defaultFontIndex or 1; v.outline=tonumber(v.outline) or 2
		v.size=tonumber(v.size) or (kind=="text" and (key=="nameText" and 14 or 10) or 16)
		v.iconSize=tonumber(v.iconSize) or 16; v.maxIcons=tonumber(v.maxIcons) or (key=="missingBuffs" and 3 or (key=="healerBuffs" and 5 or 4)); v.rows=tonumber(v.rows) or 1
		-- Keep the saved `orientation` key for existing layout profiles; the UI
		-- presents this setting as Icon Growth.
		if v.orientation=="right-to-left" then v.orientation="left" end
		if v.orientation~="right" and v.orientation~="left" and v.orientation~="up" and v.orientation~="down" then v.orientation="right" end
		if key=="healerBuffs" and v.enabled==nil then v.enabled=false end
		v.enabled=v.enabled ~= false; v.spells=type(v.spells)=="table" and v.spells or {}
		if key=="buffs" and not v.defaultBuffListInitialized and table.getn(v.spells)==0 and (not v.filterModeInitialized or v.filterMode~="whitelist") then
			local defaults=MakeDefaultBuffList()
			if table.getn(defaults)>0 then v.spells=defaults; v.filterMode="whitelist"; v.filterModeInitialized=true; v.defaultBuffListInitialized=true end
		end
		if v.onlyKnown==nil then v.onlyKnown=true end
		if v.onlyCurrentClass==nil then v.onlyCurrentClass=true end
		if v.onlyDispellable==nil then v.onlyDispellable=false end
		if key=="healerBuffs" and not v.filterModeInitialized then v.filterMode="whitelist"; v.filterModeInitialized=true end
		if not v.filterModeInitialized then
			if not v.filterMode or (v.filterMode=="whitelist" and table.getn(v.spells)==0) then v.filterMode="blacklist" end
			v.filterModeInitialized=true
		end
		v.filterMode=v.filterMode or "blacklist"
		if v.colorMode==nil then v.colorMode=key=="powerText" and "power" or "class" end
		if v.colorMode=="inherit" then v.colorMode="class" end
	end
	for _,layoutKey in ipairs(layoutNames) do
		local p=Cell.groupLayoutProfiles[layoutKey]
		if p then
			p.indicators=type(p.indicators)=="table" and p.indicators or {}
			for _,item in ipairs(indicators) do
				local v=p.indicators[item.key]
				if type(v)~="table" then v={}; p.indicators[item.key]=v end
				InitializeIndicatorSettings(v,item.key,item.kind)
			end
		end
	end
	local function profile()
		local p = Cell.groupLayoutProfiles[panel.indicatorLayoutKey or Cell.selectedGroupLayout]
		if not p then p={}; Cell.groupLayoutProfiles[panel.indicatorLayoutKey or Cell.selectedGroupLayout]=p end
		p.indicators = type(p.indicators)=="table" and p.indicators or {}
		return p
	end
	local function values()
		local p=profile(); local v=p.indicators[selectedKey]
		if type(v)~="table" then
			local kind=indicators[selectedItem].kind
			v={color={1,1,1}}
			p.indicators[selectedKey]=v
		end
		InitializeIndicatorSettings(v,selectedKey,indicators[selectedItem].kind)
		return v
	end
	local leftWidth, leftTotalWidth = 152, 167
	local settingsX = leftTotalWidth + 28
	local settingsWidth = math.max(228, page:GetWidth() - settingsX - 44)
	local settingsControlWidth = settingsWidth - 24
	local sectionHeight = 442
	local listViewportHeight = 352
	local title=page:CreateFontString(nil,"OVERLAY","NotCellFontNormal")
	title:SetPoint("TOPLEFT",page,"TOPLEFT",settingsX,-30); title:SetText("Indicator Settings"); title:SetTextColor(GetUIAccentColor())
	RegisterAccentRefresher(function() title:SetTextColor(GetUIAccentColor()) end)
	AddTitle(page,"Layout",10,-30)
	panel.indicatorLayoutKey=Cell.selectedGroupLayout or layoutNames[1]
	local layoutMenu=CreateFrame("Frame",nil,page); layoutMenu:SetWidth(leftTotalWidth); layoutMenu:SetFrameStrata("TOOLTIP"); layoutMenu:SetFrameLevel(page:GetFrameLevel()+20); layoutMenu:Hide()
	if StyleDropdownMenu then StyleDropdownMenu(layoutMenu) end
	local function selectLayout(key)
		panel.indicatorLayoutKey=key; Cell.selectedGroupLayout=key; Cell.selectedIndicatorKey=selectedKey
		panel.indicatorLayoutDropdown:SetText(layoutLabels[key] or key)
		local db=NotCellDB or {}; NotCellDB=db; NotCellVanillaDB=NotCellVanillaDB or {}; NotCellVanillaDB.layouts=Cell.groupLayoutProfiles; NotCellVanillaDB.groupLayoutProfiles=Cell.groupLayoutProfiles; NotCellVanillaDB.selectedLayout=key; NotCellVanillaDB.selectedGroupLayout=key; db.CellVanillaPreview=NotCellVanillaDB
		Cell:ApplyTextSettings(); Cell:RefreshOptionsMenu(); panel.RefreshIndicatorSettings(); if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
	end
	panel.indicatorLayoutDropdown=AddButton(page,"",10,-54,leftWidth,function(self)
		if layoutMenu:IsShown() then layoutMenu:Hide(); return end
		local keys=Cell.groupLayoutNames or layoutNames
		layoutMenu:SetWidth(leftWidth); layoutMenu:SetHeight(table.getn(keys)*22+4); layoutMenu:ClearAllPoints(); layoutMenu:SetPoint("TOPLEFT",self,"BOTTOMLEFT",0,-1)
		for i,key in ipairs(keys) do
			local layoutKey=key
			local row=layoutMenu.rows and layoutMenu.rows[i]
			if not row then
				layoutMenu.rows=layoutMenu.rows or {}; row=AddButton(layoutMenu,"",2,-2-(i-1)*22,leftWidth-4,function() end); row:SetHeight(21); layoutMenu.rows[i]=row
			end
			row:SetPoint("TOPLEFT",layoutMenu,"TOPLEFT",2,-2-(i-1)*22); row:SetText(layoutLabels[layoutKey] or layoutKey); row:SetScript("OnClick",function() layoutMenu:Hide(); selectLayout(layoutKey) end); row:Show()
		end
		for i=table.getn(keys)+1,table.getn(layoutMenu.rows or {}) do layoutMenu.rows[i]:Hide() end
		Cell:ShowOptionsDropdown(layoutMenu); layoutMenu:Show()
	end)
	if StyleDropdownButton then StyleDropdownButton(panel.indicatorLayoutDropdown) end
	panel.indicatorLayoutDropdown:SetText(layoutLabels[panel.indicatorLayoutKey] or panel.indicatorLayoutKey)
	AddTitle(page,"Indicators",10,-108)
	local left=CreateFrame("ScrollFrame",nil,page)
	left:SetPoint("TOPLEFT",page,"TOPLEFT",10,-132); left:SetWidth(leftWidth); left:SetHeight(listViewportHeight)
	local leftChild=CreateFrame("Frame",nil,left); leftChild:SetWidth(leftWidth-4); leftChild:SetHeight(table.getn(indicators)*32); left:SetScrollChild(leftChild)
	local scroll=CreateFrame("Slider",nil,page)
	scroll:SetPoint("TOPLEFT",left,"TOPRIGHT",2,0); scroll:SetWidth(10); scroll:SetHeight(listViewportHeight); scroll:SetOrientation("VERTICAL"); scroll:SetMinMaxValues(0,math.max(0,table.getn(indicators)*32-listViewportHeight)); scroll:SetValueStep(16); scroll:SetValue(0)
	local function StyleScrollBar(bar, contentHeight, viewportHeight)
		if not bar.cellTrack then
			local track=bar:CreateTexture(nil,"BACKGROUND"); track:SetTexture("Interface\\Buttons\\WHITE8X8"); track:SetVertexColor(.18,.18,.18,.9); track:SetPoint("TOPLEFT",bar,"TOPLEFT",3,-2); track:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",-3,2); bar.cellTrack=track
			bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8"); bar.cellThumb=bar:GetThumbTexture()
			RegisterAccentRefresher(function() if bar.cellThumb then local r,g,b=GetUIAccentColor(); bar.cellThumb:SetVertexColor(r,g,b,1) end end)
		end
		local thumb=bar.cellThumb; if thumb then thumb:SetWidth(10); thumb:SetHeight(10); local r,g,b=GetUIAccentColor(); thumb:SetVertexColor(r,g,b,1) end
		bar:SetMinMaxValues(0,math.max(0,contentHeight-viewportHeight)); bar:SetValueStep(16)
	end
	StyleScrollBar(scroll,table.getn(indicators)*32,listViewportHeight); scroll:SetValue(0)
	left:EnableMouseWheel(true)
	left:SetScript("OnMouseWheel",function(_,delta) scroll:SetValue(math.max(0,math.min(math.max(0,table.getn(indicators)*32-listViewportHeight),scroll:GetValue()-delta*32))) end)
	scroll:SetScript("OnValueChanged",function(self,v) left:SetVerticalScroll(v) end)
	panel.indicatorRows={}
	local right=CreateFrame("ScrollFrame",nil,page); right:SetPoint("TOPLEFT",page,"TOPLEFT",settingsX,-54); right:SetWidth(settingsWidth-18); right:SetHeight(sectionHeight)
	local contentHeight=1250
	local content=CreateFrame("Frame",nil,right); content:SetWidth(settingsWidth-19); content:SetHeight(contentHeight); right:SetScrollChild(content)
	local auraControls=CreateFrame("Frame",nil,content); auraControls:SetPoint("TOPLEFT",content,"TOPLEFT",0,0); auraControls:SetWidth(settingsControlWidth); auraControls:SetHeight(contentHeight)
	local rightScroll=CreateFrame("Slider",nil,page); rightScroll:SetPoint("TOPLEFT",right,"TOPRIGHT",2,0); rightScroll:SetWidth(10); rightScroll:SetHeight(sectionHeight); rightScroll:SetOrientation("VERTICAL")
	StyleScrollBar(rightScroll,contentHeight,sectionHeight); rightScroll:SetValue(0)
	right:EnableMouseWheel(true)
	right:SetScript("OnMouseWheel",function(_,delta) rightScroll:SetValue(math.max(0,math.min(math.max(0,contentHeight-sectionHeight),rightScroll:GetValue()-delta*32))) end)
	rightScroll:SetScript("OnValueChanged",function(self,v) right:SetVerticalScroll(v) end)
	for i,item in ipairs(indicators) do
		local rowIndex, rowKey = i, item.key
		local row=CreateFrame("Button",nil,leftChild); row:SetWidth(146); row:SetHeight(26); row:SetPoint("TOPLEFT",leftChild,"TOPLEFT",0,-(i-1)*32); row:EnableMouse(true)
		row.background=row:CreateTexture(nil,"BACKGROUND"); row.background:SetAllPoints(row); row.background:SetTexture("Interface\\Buttons\\WHITE8X8")
		row.label=row:CreateFontString(nil,"OVERLAY","NotCellFontNormalSmall"); row.label:SetPoint("LEFT",row,"LEFT",5,0); row.label:SetJustifyH("LEFT"); row.label:SetText(item.name)
		row:SetScript("OnClick",function()
			selectedItem=rowIndex; selectedKey=rowKey; Cell.selectedIndicatorKey=rowKey
			if panel.RefreshIndicatorSettings then panel.RefreshIndicatorSettings() end
		end)
		panel.indicatorRows[i]=row
	end
	local function save()
		local db=NotCellDB or {}; NotCellDB=db; NotCellVanillaDB=NotCellVanillaDB or {}; NotCellVanillaDB.layouts=Cell.groupLayoutProfiles; NotCellVanillaDB.groupLayoutProfiles=Cell.groupLayoutProfiles; db.CellVanillaPreview=NotCellVanillaDB
		Cell:ApplyTextSettings(); Cell:UpdateFrames(); if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
	end
	local y=-8
	panel.indicatorEnabled=AddCheckbox(content,"Enabled",0,y,settingsControlWidth,function() local v=values(); v.enabled=not v.enabled; save(); panel.RefreshIndicatorSettings() end); y=y-34
	local positionDropdownY=y
	panel.indicatorAnchor=AddDropdown(content,settingsControlWidth,0,y,function() return "Position: "..(values().anchor or "CENTER") end,anchors,function(v) values().anchor=v; values().anchorInitialized=true; save(); panel.RefreshIndicatorSettings() end); y=y-38
	panel.indicatorX,panel.indicatorXValue=AddSlider(content,"X offset",0,y,settingsControlWidth,-100,100,1,0,function(v) values().x=v; values().anchorInitialized=true; save() end); y=y-sliderPitch
	panel.indicatorY,panel.indicatorYValue=AddSlider(content,"Y offset",0,y,settingsControlWidth,-100,100,1,0,function(v) values().y=v; values().anchorInitialized=true; save() end); y=y-sliderPitch
	panel.indicatorXBaseY=panel.indicatorX.optionY; panel.indicatorYBaseY=panel.indicatorY.optionY
	panel.textAppearanceTitle=AddTitle(content,"Text appearance",0,y); y=y-24
	panel.indicatorFont=AddDropdown(content,settingsControlWidth,0,y,function() local f=fonts[values().font or Cell.defaultFontIndex or 1] or fonts[1]; return "Font: "..(f and f.name or "Friz Quadrata") end,fonts,function(v) values().font=v; save(); panel.RefreshIndicatorSettings() end); y=y-36
	panel.indicatorSize,panel.indicatorSizeValue=AddSlider(content,"Font size",0,y,settingsControlWidth,6,48,1,12,function(v) values().size=v; values().iconSize=v; save() end); panel.indicatorTextSizeY=y; y=y-sliderPitch
	panel.indicatorOutline=AddDropdown(content,settingsControlWidth,0,y,function() local o=outlines[values().outline or 2] or outlines[2]; return "Outline: "..o.name end,outlines,function(v) values().outline=v; save(); panel.RefreshIndicatorSettings() end); y=y-36
	local colorLabels={nameText="Name color",healthText="Health color",powerText="Power color",statusText="Status color"}
	local textColorChoices={{name="Class Color",value="class"},{name="Power Color",value="power"},{name="Custom Color",value="custom"}}
	panel.indicatorColorMode=AddDropdown(content,settingsControlWidth-30,0,y,function() local mode=values().colorMode; local label=mode=="power" and "Power Color" or (mode=="custom" and "Custom Color" or "Class Color"); return (colorLabels[selectedKey] or "Text color")..": "..label end,textColorChoices,function(mode) values().colorMode=mode; save(); panel.RefreshIndicatorSettings() end)
	panel.indicatorColorY=y
	panel.indicatorColor=CreateFrame("Button",nil,content); panel.indicatorColor:SetWidth(22); panel.indicatorColor:SetHeight(22); panel.indicatorColor:SetPoint("TOPLEFT",content,"TOPLEFT",settingsControlWidth-24,y+2)
	panel.indicatorColor:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
	panel.indicatorColor.swatch=panel.indicatorColor:CreateTexture(nil,"ARTWORK"); panel.indicatorColor.swatch:SetPoint("TOPLEFT",panel.indicatorColor,"TOPLEFT",4,-4); panel.indicatorColor.swatch:SetPoint("BOTTOMRIGHT",panel.indicatorColor,"BOTTOMRIGHT",-4,4)
	panel.indicatorColor:SetScript("OnClick",function()
		local v=values(); local color=v.color or {1,1,1}; local original={color[1],color[2],color[3]}
		if not ColorPickerFrame then return end
		local function apply(r,g,b) v.color={r,g,b}; panel.indicatorColor.swatch:SetVertexColor(r,g,b); save() end
		ColorPickerFrame.func=function() local r,g,b=ColorPickerFrame:GetColorRGB(); apply(r,g,b) end
		ColorPickerFrame.opacityFunc=nil
		ColorPickerFrame.cancelFunc=function() apply(original[1],original[2],original[3]) end
		if Cell.RaiseColorPicker then Cell:RaiseColorPicker() end
		ColorPickerFrame:SetColorRGB(color[1],color[2],color[3]); ColorPickerFrame:Show()
		if ColorPickerFrame._cellRaisePickerButtons then ColorPickerFrame._cellRaisePickerButtons(ColorPickerFrame) end
	end); y=y-38
	panel.indicatorValueFormat=AddDropdown(content,settingsControlWidth,0,y,function() return "Format: "..(values().format=="absolute" and "Current / max" or "Percent") end,{{name="Percent",value="percent"},{name="Current / max",value="absolute"}},function(v) values().format=v; save(); panel.RefreshIndicatorSettings() end); y=y-38
	panel.indicatorPercentSign=AddCheckbox(content,"Show % sign",0,y,settingsControlWidth,function()
		local v=values(); v.showPercentSign=(v.showPercentSign==false); save(); panel.RefreshIndicatorSettings()
	end)
	y=y-34
	panel.iconLayoutTitle=AddTitle(auraControls,"Aura layout",0,y); y=y-24
	panel.indicatorMax,panel.indicatorMaxValue=AddSlider(auraControls,"Maximum shown",0,y,settingsControlWidth,1,20,1,4,function(v) values().maxIcons=v; save() end); y=y-sliderPitch
	panel.indicatorRowsSlider,panel.indicatorRowsValue=AddSlider(auraControls,"Lines",0,y,settingsControlWidth,1,8,1,1,function(v) values().rows=v; save() end); y=y-sliderPitch
	panel.indicatorIconGrowth=AddDropdown(auraControls,settingsControlWidth,0,positionDropdownY-34,function() return "Icon Growth: "..(iconGrowthLabels[values().orientation] or "Right") end,iconGrowthChoices,function(v) values().orientation=v; save(); panel.RefreshIndicatorSettings() end); y=y-38
	panel.auraFilterTitle=AddTitle(auraControls,"Aura spell filter",0,y); y=y-24
	panel.auraFilter=AddDropdown(auraControls,settingsControlWidth,0,y,function() return "Filter: "..(values().filterMode or "blacklist") end,{{name="Whitelist",value="whitelist"},{name="Blacklist",value="blacklist"}},function(v) local s=values(); s.filterMode=v; s.filterModeInitialized=true; save(); panel.auraFilter:RefreshChoiceLabel() end); y=y-38
	panel.dispellableOnly=AddCheckbox(auraControls,"Only show debuffs I can dispel",0,y,settingsControlWidth,function() local v=values(); v.onlyDispellable=not v.onlyDispellable; save(); panel.RefreshIndicatorSettings() end); y=y-30
	local function saveDebuffVisual(key, value)
		if panel.syncingDebuffControls then return end
		local settings=NotCellVanillaDB or {}; NotCellVanillaDB=settings
		if settings[key]==value then return end
		settings[key]=value
		settings.layouts=Cell.groupLayoutProfiles; settings.groupLayoutProfiles=Cell.groupLayoutProfiles
		NotCellDB=NotCellDB or {}; NotCellDB.CellVanillaPreview=settings
		Cell:UpdateFrames(); Cell:RefreshOptionsMenu()
		if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
	end
	panel.debuffDisplayTitle=AddTitle(auraControls,"Debuff display",0,0)
	panel.debuffDisplayMode=AddDropdown(auraControls,settingsControlWidth,0,0,function()
		local mode=Cell.debuffFillMode or "none"
		if mode=="none" and Cell.debuffBorderEnabled then mode="border" end
		return "Display: "..(mode=="solid" and "Solid Tint" or (mode=="gradient" and "Gradient" or (mode=="border" and "Border Glow" or "None")))
	end,debuffDisplayModes,function(mode)
		Cell.debuffBorderEnabled=(mode=="border")
		Cell.debuffFillMode=(mode=="solid" or mode=="gradient") and mode or "none"
		saveDebuffVisual("debuffBorderEnabled",Cell.debuffBorderEnabled); saveDebuffVisual("debuffFillMode",Cell.debuffFillMode)
		panel.RefreshIndicatorSettings()
	end)
	panel.debuffIconsCheckbox=AddCheckbox(auraControls,"Show debuff icons",0,0,settingsControlWidth,function()
		Cell.showDebuffIcons=not Cell.showDebuffIcons
		saveDebuffVisual("showDebuffIcons",Cell.showDebuffIcons)
		panel.RefreshIndicatorSettings()
	end)
	panel.debuffAlpha,panel.debuffAlphaValue=AddSlider(auraControls,"Effect alpha",0,0,settingsControlWidth,0,100,5,65,function(v) Cell.debuffFillAlpha=v; saveDebuffVisual("debuffFillAlpha",v) end)
	panel.debuffCoverage,panel.debuffCoverageValue=AddSlider(auraControls,"Gradient coverage",0,0,settingsControlWidth,10,100,5,100,function(v) Cell.debuffFillAmount=v; saveDebuffVisual("debuffFillAmount",v) end)
	panel.debuffDirection=AddDropdown(auraControls,settingsControlWidth,0,0,function()
		local labels={ ["left-to-right"]="Right",["right-to-left"]="Left",["down-to-up"]="Up",["up-to-down"]="Down" }
		return "Gradient growth: "..(labels[Cell.debuffFillDirection] or "Right")
	end,debuffDirections,function(direction) Cell.debuffFillDirection=direction; saveDebuffVisual("debuffFillDirection",direction) end)
	panel.missingKnown=AddCheckbox(auraControls,"Only show buffs I have learned",0,y,settingsControlWidth,function() local v=values(); v.onlyKnown=not v.onlyKnown; save(); panel.RefreshIndicatorSettings() end); y=y-30
	panel.missingClass=AddCheckbox(auraControls,"Only show buffs for my class",0,y,settingsControlWidth,function() local v=values(); v.onlyCurrentClass=not v.onlyCurrentClass; save(); panel.RefreshIndicatorSettings() end); y=y-34
	local spellInputY=y
	local spellEdit=CreateFrame("EditBox",nil,auraControls); spellEdit:SetWidth(settingsControlWidth-70); spellEdit:SetHeight(22); spellEdit:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,y); spellEdit:SetAutoFocus(false); spellEdit:SetFontObject(NotCellFontNormalSmall); spellEdit:SetTextInsets(4,4,2,2); spellEdit:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); spellEdit:SetBackdropColor(.05,.05,.05,1); spellEdit:SetText("Spell name or ID"); spellEdit:SetTextColor(.65,.65,.65); panel.indicatorSpellEdit=spellEdit
	spellEdit:SetScript("OnEditFocusGained",function(self) if self:GetText()=="Spell name or ID" then self:SetText(""); self:SetTextColor(1,1,1) end end)
	spellEdit:SetScript("OnEditFocusLost",function(self) if self:GetText()=="" then self:SetText("Spell name or ID"); self:SetTextColor(.65,.65,.65) end end)
	panel.indicatorSpellAdd=AddButton(auraControls,"Add spell",settingsControlWidth-63,y,63,function()
		local raw=spellEdit:GetText() or ""; if raw=="Spell name or ID" then raw="" end; local id=tonumber(raw); local name,icon
		if id and GetSpellInfo then local spellName,rank,spellIcon=GetSpellInfo(id); name,icon=spellName,spellIcon
		else name=raw; if GetSpellInfo then local spellName,rank,spellIcon=GetSpellInfo(raw); if spellName then name,icon=spellName,spellIcon end end end
		if name and name~="" then local v=values(); v.spells=v.spells or {}; v.spells[#v.spells+1]={id=id,name=name,icon=icon}; spellEdit:SetText(""); spellEdit:ClearFocus(); panel.RefreshIndicatorSettings() end
		save()
	end); y=y-30
	panel.indicatorSpellRows={}
	local function CreateSpellRow(i)
		local row=CreateFrame("Button",nil,auraControls); row:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,y-(i-1)*18); row:SetWidth(settingsControlWidth-28); row:SetHeight(17)
		row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetWidth(18); row.icon:SetHeight(18); row.icon:SetPoint("LEFT",row,"LEFT",0,0)
		row.label=row:CreateFontString(nil,"OVERLAY","NotCellFontNormalSmall"); row.label:SetPoint("LEFT",row.icon,"RIGHT",4,0); row.label:SetWidth(settingsControlWidth-54); row.label:SetJustifyH("LEFT")
		panel.indicatorSpellRows[i]=row
		local remove=AddButton(auraControls,"X",settingsControlWidth-24,y-(i-1)*18,24,function() local v=values(); if row.spellIndex then table.remove(v.spells,row.spellIndex); panel.RefreshIndicatorSettings(); save() end end)
		remove:SetHeight(17); row.removeButton=remove
	end
	for i=1,20 do CreateSpellRow(i) end
	local preview=CreateFrame("Frame",nil,panel)
	preview:SetFrameStrata("DIALOG"); preview:SetWidth(160); preview:SetHeight(60); preview:SetClampedToScreen(true); preview:Hide()
	preview.title=preview:CreateFontString(nil,"OVERLAY","NotCellFontNormal"); preview.title:SetPoint("BOTTOMLEFT",preview,"TOPLEFT",0,4); preview.title:SetText("Preview"); preview.title:SetFont(NotCellFontNormal:GetFont(),18,"THICKOUTLINE"); preview.title:SetTextColor(GetUIAccentColor()); RegisterAccentRefresher(function() preview.title:SetTextColor(GetUIAccentColor()) end)
	preview.background=preview:CreateTexture(nil,"BACKGROUND"); preview.background:SetAllPoints(preview); preview.background:SetTexture(.08,.08,.08,.95)
	preview.health=CreateFrame("StatusBar",nil,preview); preview.health:SetPoint("TOPLEFT",preview,"TOPLEFT",2,-2); preview.health:SetPoint("BOTTOMRIGHT",preview,"BOTTOMRIGHT",-2,(Cell.powerBarHeight or 4)+4); preview.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8"); preview.health:SetStatusBarColor(.25,.55,.25,1); preview.health:SetMinMaxValues(0,1); preview.health:SetValue(.72)
	-- Keep the loss region on the same status bar and draw layer as live frames;
	-- a sibling behind the bar is covered by the status bar's unfilled area.
	preview.healthLoss=preview.health:CreateTexture(nil,"BACKGROUND"); preview.healthLoss:SetAllPoints(preview.health); preview.healthLoss:SetTexture(.62,.08,.08,.95)
	preview.power=CreateFrame("StatusBar",nil,preview); preview.power:SetPoint("BOTTOMLEFT",preview,"BOTTOMLEFT",2,2); preview.power:SetPoint("BOTTOMRIGHT",preview,"BOTTOMRIGHT",-2,2); preview.power:SetHeight(Cell.powerBarHeight or 4); preview.power:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8"); preview.power:SetStatusBarColor(.2,.35,.85,1); preview.power:SetMinMaxValues(0,1); preview.power:SetValue(.6)
	preview.indicatorOverlay=CreateFrame("Frame",nil,preview); preview.indicatorOverlay:SetAllPoints(preview); preview.indicatorOverlay:SetFrameLevel(math.max(preview.health:GetFrameLevel(),preview.power:GetFrameLevel())+10)
	preview.debuffSegments={}
	for i=1,24 do
		preview.debuffSegments[i]=preview.indicatorOverlay:CreateTexture(nil,"OVERLAY")
		preview.debuffSegments[i]:SetTexture("Interface\\Buttons\\WHITE8X8")
		preview.debuffSegments[i]:Hide()
	end
	preview.debuffBorder=CreateFrame("Frame",nil,preview)
	preview.debuffBorder:SetAllPoints(preview)
	preview.debuffBorder:SetFrameLevel(preview.indicatorOverlay:GetFrameLevel()+1)
	preview.debuffBorder:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,edgeSize=3})
	preview.debuffBorder:SetBackdropColor(0,0,0,0)
	preview.debuffBorder:Hide()
	preview.damageFlash=preview.indicatorOverlay:CreateTexture(nil,"OVERLAY"); preview.damageFlash:SetTexture("Interface\\Buttons\\WHITE8X8"); preview.damageFlash:SetVertexColor(1,1,1,1); preview.damageFlash:SetAlpha(0); preview.damageFlash:Hide()
	preview.name=preview.indicatorOverlay:CreateFontString(nil,"OVERLAY","NotCellFontNormalSmall"); preview.name:SetText("Sample Player"); preview.name:SetTextColor(.25,.65,1)
	preview.healthText=preview.indicatorOverlay:CreateFontString(nil,"OVERLAY","NotCellFontNormalSmall"); preview.healthText:SetText("72%")
	preview.status=preview.indicatorOverlay:CreateFontString(nil,"OVERLAY","NotCellFontNormalSmall"); preview.status:SetText(""); preview.status:Hide()
	preview.powerText=preview.indicatorOverlay:CreateFontString(nil,"OVERLAY","NotCellFontNormalSmall"); preview.powerText:SetText("60%")
	preview.auraIcons={buffs={},debuffs={},missingBuffs={},healerBuffs={}}
	preview.missingBuffGlow={}
	local previewClass
	if UnitClass then local _, classToken = UnitClass("player"); previewClass = classToken end
	local previewAuraSpellIDs = {
		buffs={MAGE={1459,23028,604},PRIEST={6346,1243,14752,976},DRUID={467,1126,770,774,8936},PALADIN={19740,20217,19742,1038,465,7294},SHAMAN={8076,8072,8836,5677,2825},WARRIOR={6673},WARLOCK={20707,5697,132},HUNTER={19506,13165}},
		debuffs={MAGE={116,118,122},PRIEST={589,605,8092},DRUID={5176,8921,339},PALADIN={853,879},SHAMAN={8042,8050},WARRIOR={772,12294},WARLOCK={172,980,686},HUNTER={1978,3044}},
		missingBuffs={MAGE={1459},PRIEST={1243,6346},DRUID={1126,467},PALADIN={19740,465},SHAMAN={8076,8072},WARRIOR={6673},WARLOCK={5697,132},HUNTER={19506}},
		healerBuffs={PRIEST={139,17,14892,"Enlighten","Apotheosis"},PALADIN={20236,1022,"Daybreak"},SHAMAN={16177,29203},DRUID={774,8936,740}},
	}
	for auraType,offset in pairs({buffs=0,debuffs=110,missingBuffs=55,healerBuffs=165}) do
		for i=1,(auraType=="missingBuffs" and 3 or 8) do
			if auraType=="healerBuffs" and i>5 then break end
			-- Parent aura preview icons to the elevated overlay; textures created on
			-- the preview itself render behind its health StatusBar on Classic clients.
			local icon=preview.indicatorOverlay:CreateTexture(nil,"OVERLAY"); icon:SetWidth(18); icon:SetHeight(18); icon:SetPoint("TOPLEFT",preview,"TOPLEFT",8+offset+((i-1)%5)*21,-88-math.floor((i-1)/5)*21); icon:Hide(); preview.auraIcons[auraType][i]=icon
			if auraType=="missingBuffs" then
				local glow=CreateFrame("Frame",nil,preview.indicatorOverlay)
				glow:SetPoint("TOPLEFT",icon,"TOPLEFT",-1,1); glow:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",1,-1)
				glow:SetFrameLevel(preview.indicatorOverlay:GetFrameLevel()+20)
				glow:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
				glow:SetBackdropBorderColor(.58,.88,1,.85); glow:Hide()
				preview.missingBuffGlow[i]=glow
			end
		end
	end
	preview.indicatorIcons={}
	local previewIconTextures={statusIcon="Interface\\TargetingFrame\\UI-TargetingFrame-Skull",roleIcon="Interface\\AddOns\\NotCell\\Media\\Roles\\Blizzard3_TANK.tga",leaderIcon="Interface\\GroupFrame\\UI-Group-LeaderIcon",readyCheckIcon="Interface\\AddOns\\NotCell\\Media\\Icons\\readycheck-ready.tga",raidIcon="Interface\\TargetingFrame\\UI-RaidTargetingIcons"}
	for key,texture in pairs(previewIconTextures) do
		local icon=preview.indicatorOverlay:CreateTexture(nil,"OVERLAY"); icon:SetWidth(16); icon:SetHeight(16); icon:SetTexture(texture); icon:Hide(); preview.indicatorIcons[key]=icon
		if key=="raidIcon" then
			if SetRaidTargetIconTexture then SetRaidTargetIconTexture(icon,4) else icon:SetTexCoord(.25,.5,0,.5) end
		end
	end
	local testButton
	local debuffTestButton
	local previewSettings = type(NotCellVanillaDB) == "table" and NotCellVanillaDB
		or (type(NotCellDB) == "table" and type(NotCellDB.CellVanillaPreview) == "table" and NotCellDB.CellVanillaPreview)
	local previewOnlySelected = previewSettings and previewSettings.previewOnlySelectedIndicator == true or false
	local debuffTestTypes = {
		{name="Disease", color={0.60,0.40,0.00}, icon="Interface\\Icons\\Spell_Shadow_CurseOfMannoroth"}, {name="Poison", color={0.00,0.60,0.00}, icon="Interface\\Icons\\Ability_Poisons"},
		{name="Magic", color={0.20,0.60,1.00}, icon="Interface\\Icons\\Spell_Frost_FrostNova"}, {name="Curse", color={0.60,0.00,1.00}, icon="Interface\\Icons\\Spell_Shadow_CurseOfSargeras"},
	}
	local debuffTestIndex=0
	local function ApplyPreviewDebuffTest()
		if not preview.debuffTesting then return end
		local layoutKey=panel.indicatorLayoutKey or Cell.selectedGroupLayout
		local profile=Cell.groupLayoutProfiles and Cell.groupLayoutProfiles[layoutKey] or {}
		local debuffSettings=profile.indicators and profile.indicators.debuffs or {}
		local sample=debuffTestTypes[debuffTestIndex]
		if not sample then return end
		preview.debuffBorder:Hide()
		for i=1,table.getn(preview.debuffSegments) do preview.debuffSegments[i]:Hide() end

		-- The visual test follows the indicator's master Enabled switch just like
		-- live frames; Show debuff icons only controls icons, not these effects.
		if debuffSettings.enabled == false then return end
		if Cell.showDebuffIcons then
			local testIcon=preview.auraIcons.debuffs[1]
			if testIcon and sample.icon then testIcon:SetTexture(sample.icon); testIcon:SetAlpha(1); testIcon:Show() end
		end
		local mode=Cell.debuffFillMode or "none"
		if mode=="none" and Cell.debuffBorderEnabled then mode="border" end
		if mode=="border" then
			preview.debuffBorder:SetBackdropBorderColor(sample.color[1],sample.color[2],sample.color[3],.95)
			preview.debuffBorder:Show()
		elseif mode=="solid" then
			preview.health:SetStatusBarColor(sample.color[1],sample.color[2],sample.color[3],1)
		elseif mode=="gradient" then
			local width,height=preview.health:GetWidth(),preview.health:GetHeight()
			local fraction=math.max(.10,math.min(1,(tonumber(Cell.debuffFillAmount) or 100)/100))
			local vertical=Cell.debuffFillDirection=="down-to-up" or Cell.debuffFillDirection=="up-to-down"
			local extent=vertical and height*fraction or width*fraction
			local segmentExtent=extent/table.getn(preview.debuffSegments)
			local alpha=math.max(0,math.min(1,(tonumber(Cell.debuffFillAlpha) or 65)/100))
			for i,segment in ipairs(preview.debuffSegments) do
				local x,y,segmentWidth,segmentHeight
				if vertical then
					x,segmentWidth,segmentHeight=0,width,segmentExtent
					y=Cell.debuffFillDirection=="down-to-up" and (height-i*segmentExtent) or ((i-1)*segmentExtent)
				else
					y,segmentHeight,segmentWidth=0,height,segmentExtent
					x=Cell.debuffFillDirection=="right-to-left" and (width-i*segmentExtent) or ((i-1)*segmentExtent)
				end
				segment:ClearAllPoints(); segment:SetPoint("TOPLEFT",preview.health,"TOPLEFT",x,-y)
				segment:SetPoint("BOTTOMRIGHT",preview.health,"TOPLEFT",x+segmentWidth,-(y+segmentHeight))
				segment:SetVertexColor(sample.color[1],sample.color[2],sample.color[3])
				segment:SetAlpha(alpha*(.08+.62*(i-1)/math.max(1,table.getn(preview.debuffSegments)-1)))
				if extent>0 and width>0 and height>0 then segment:Show() end
			end
		end
	end
	local function StopPreviewDebuffTest(refreshPreview)
		preview.debuffTesting=nil
		preview.debuffBorder:Hide()
		for i=1,table.getn(preview.debuffSegments) do preview.debuffSegments[i]:Hide() end
		if debuffTestButton then debuffTestButton:SetText("Test Debuffs") end
		if refreshPreview and panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview()
		elseif Cell.ApplyPreviewAppearance then Cell:ApplyPreviewAppearance(preview); ApplyPreviewDebuffTest() end
	end
	local function UpdatePreviewHealthText()
		local p=Cell.groupLayoutProfiles[panel.indicatorLayoutKey or Cell.selectedGroupLayout] or {}; local settings=((p.indicators or {}).healthText or {})
		local percent=math.floor((preview.health:GetValue() or .72)*100)
		local percentText=tostring(percent)..(settings.showPercentSign==false and "" or "%")
		preview.healthText:SetText(settings.format=="absolute" and (tostring(percent*10).." / 1000") or percentText)
	end
	local function GetAuraPreviewTextures(key, settings)
		local result, entries = {}, settings.spells or {}
		local useConfigured = settings.filterMode == "whitelist" and table.getn(entries) > 0 and key ~= "missingBuffs"
		if useConfigured then
			local function addEntry(entry)
					local texture = entry.icon
					if not texture and GetSpellInfo then local _,_,spellTexture=GetSpellInfo(entry.id or entry.name); texture=spellTexture end
					if texture then result[table.getn(result)+1]=texture end
			end
			if settings.onlyCurrentClass then
				for _,entry in ipairs(entries) do if not entry.class or entry.class==previewClass then addEntry(entry) end end
			else
				-- Show the current class first, then other providers when the filter is off.
				for _,entry in ipairs(entries) do if entry.class==previewClass then addEntry(entry) end end
				for _,entry in ipairs(entries) do if entry.class~=previewClass then addEntry(entry) end end
			end
		end
		if table.getn(result)==0 then
			local defaults=(previewAuraSpellIDs[key] or {})[previewClass] or {}
			for _,spell in ipairs(defaults) do
				local texture
				if GetSpellInfo then local _,_,spellTexture=GetSpellInfo(spell); texture=spellTexture end
				if texture then result[table.getn(result)+1]=texture end
			end
		end
		return result
	end
	local function GetPreviewAuraOffset(settings,index,maxIcons,lines,size)
		local orientation=settings.orientation or "right"
		if orientation=="right-to-left" then orientation="left" end
		if orientation=="left-to-right" then orientation="right" end
		local iconsPerLine=math.max(1,math.ceil(maxIcons/math.max(1,lines)))
		local step=(index-1)%iconsPerLine; local line=math.floor((index-1)/iconsPerLine)
		local anchor=settings.anchor or "CENTER"; local gap=size+2
		local inwardX=string.find(anchor,"RIGHT",1,true) and -1 or 1
		local inwardY=string.find(anchor,"TOP",1,true) and -1 or (string.find(anchor,"BOTTOM",1,true) and 1 or -1)
		if orientation=="left" or orientation=="right" then
			return (tonumber(settings.x) or 0)+(orientation=="left" and -1 or 1)*step*gap,(tonumber(settings.y) or 0)+inwardY*line*gap
		else
			return (tonumber(settings.x) or 0)+inwardX*line*gap,(tonumber(settings.y) or 0)+(orientation=="up" and 1 or -1)*step*gap
		end
	end
	local function ShowPreviewDamage(fromValue,toValue)
		if toValue>=fromValue then preview.damageFlash:Hide(); preview.damageFlashRemaining=nil; return end
		preview.damageFlash:ClearAllPoints()
		if preview.healthOrientation == "VERTICAL" then
			local height=preview.health:GetHeight() or 0
			preview.damageFlash:SetPoint("TOPLEFT",preview.health,"TOPLEFT",0,-height*(1-fromValue))
			preview.damageFlash:SetPoint("BOTTOMRIGHT",preview.health,"BOTTOMRIGHT",0,height*toValue)
		else
			local width=preview.health:GetWidth() or 0; local lost=fromValue-toValue
			preview.damageFlash:SetPoint("TOPLEFT",preview.health,"TOPLEFT",width*toValue,0)
			preview.damageFlash:SetPoint("BOTTOMLEFT",preview.health,"BOTTOMLEFT",width*toValue,0)
			preview.damageFlash:SetWidth(math.max(1,width*lost))
		end
		preview.damageFlash:SetAlpha(.70); preview.damageFlash:Show(); preview.damageFlashRemaining=.30
	end
	local function StopPreviewTest(resetHealth)
		preview.testing=nil; preview:SetScript("OnUpdate",nil)
		if testButton then testButton:SetText("Test") end
		preview.damageFlash:Hide(); preview.damageFlashRemaining=nil
		if resetHealth then preview.health:SetValue(.72); if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end; if Cell.ApplyPreviewAppearance then Cell:ApplyPreviewAppearance(preview) end; ApplyPreviewDebuffTest() end
	end
	testButton=AddButton(preview,"Test",0,-68,82,function()
		if preview.testing then StopPreviewTest(false); return end
		preview.testing=true; preview.testHealing=false; preview.testTarget=nil; preview.testWait=.75; preview.testElapsed=0
		testButton:SetText("Stop test")
		preview:SetScript("OnUpdate",function(self,elapsed)
			if self.damageFlashRemaining then
				self.damageFlashRemaining=self.damageFlashRemaining-elapsed
				if self.damageFlashRemaining<=0 then self.damageFlashRemaining=nil; self.damageFlash:Hide()
				else self.damageFlash:SetAlpha(.70*self.damageFlashRemaining/.30) end
			end
			if not self.testTarget then
				self.testWait=self.testWait-elapsed
				if self.testWait<=0 then
					local current=self.health:GetValue() or .72
					local target
					if self.testHealing or current<=.12 then target=math.min(1,current+math.random(12,40)/100); self.testHealing=false
					else target=math.max(.08,current-math.random(12,42)/100); self.testHealing=true end
					local mode=Cell.barAnimationMode or "smooth"
					if mode=="smooth" then
						self.testTarget=target; self.testFrom=current; self.testElapsed=0; self.testDuration=.20
					else
						if mode=="flash" then ShowPreviewDamage(current,target) else ShowPreviewDamage(target,target) end
						self.health:SetValue(target); self.testWait=math.random(8,20)/10
						UpdatePreviewHealthText(); if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end; if Cell.ApplyPreviewAppearance then Cell:ApplyPreviewAppearance(self) end; ApplyPreviewDebuffTest()
					end
				end
			else
				self.testElapsed=self.testElapsed+elapsed
				local progress=math.min(1,self.testElapsed/self.testDuration)
				local current=self.testFrom+(self.testTarget-self.testFrom)*progress
				self.health:SetValue(current)
				UpdatePreviewHealthText(); if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
				if Cell.ApplyPreviewAppearance then Cell:ApplyPreviewAppearance(self) end
				ApplyPreviewDebuffTest()
				if progress>=1 then self.health:SetValue(self.testTarget); UpdatePreviewHealthText(); self.testTarget=nil; self.testWait=math.random(8,20)/10 end
			end
		end)
	end)
	debuffTestButton=AddButton(preview,"Test Debuffs",0,-68,105,function()
		if preview.debuffTesting then
			StopPreviewDebuffTest(true)
			return
		end
		debuffTestIndex=debuffTestIndex%table.getn(debuffTestTypes)+1
		preview.debuffTesting=true
		debuffTestButton:SetText("Stop debuff test")
		if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() else ApplyPreviewDebuffTest() end
	end)
	testButton:ClearAllPoints(); testButton:SetPoint("TOPLEFT",preview,"BOTTOMLEFT",0,-8)
	debuffTestButton:ClearAllPoints(); debuffTestButton:SetPoint("LEFT",testButton,"RIGHT",6,0)
	local previewOnlyCheckbox
	previewOnlyCheckbox = AddCheckbox(preview, "Show selected indicator only", 0, -68, 210, function()
		previewOnlySelected = not previewOnlySelected
		previewOnlyCheckbox:SetChecked(previewOnlySelected)
		NotCellVanillaDB = type(NotCellVanillaDB) == "table" and NotCellVanillaDB
			or (type(NotCellDB) == "table" and type(NotCellDB.CellVanillaPreview) == "table" and NotCellDB.CellVanillaPreview) or {}
		NotCellVanillaDB.previewOnlySelectedIndicator = previewOnlySelected
		NotCellDB = type(NotCellDB) == "table" and NotCellDB or {}
		NotCellDB.CellVanillaPreview = NotCellVanillaDB
		if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
	end)
	previewOnlyCheckbox:ClearAllPoints(); previewOnlyCheckbox:SetPoint("TOPLEFT",testButton,"BOTTOMLEFT",0,-4)
	previewOnlyCheckbox:SetChecked(previewOnlySelected)
	local previewToggleFont,previewToggleFontSize=previewOnlyCheckbox.label:GetFont()
	previewOnlyCheckbox.label:SetFont(previewToggleFont,previewToggleFontSize,"OUTLINE")
	panel.previewOnlySelectedIndicatorCheckbox = previewOnlyCheckbox
	panel.indicatorPreviewFrame=preview
	panel:HookScript("OnHide",function() preview:Hide() end)
	panel:HookScript("OnShow",function() preview:Show() end)
	preview:SetScript("OnHide",function()
		StopPreviewTest(true)
		if preview.debuffTesting then
			StopPreviewDebuffTest(false)
			if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
		end
	end)
	function panel.UpdateIndicatorPreview()
		local p=Cell.groupLayoutProfiles[panel.indicatorLayoutKey or Cell.selectedGroupLayout] or {}
		local w=math.max(40,math.min(300,tonumber(p.width) or Cell.buttonWidth or 130)); local h=math.max(32,math.min(120,tonumber(p.height) or Cell.buttonHeight or 50))
		-- Rebuild the normal preview first so turning isolation off restores bars
		-- that a previous filtered pass hid.
		preview.background:Show(); preview.health:Show(); preview.healthLoss:Show(); preview.power:Show()
		local powerHeight=math.max(2,math.min(12,tonumber(p.powerBarHeight) or Cell.powerBarHeight or 4))
		local healthOrientation=p.healthBarOrientation=="VERTICAL" and "VERTICAL" or "HORIZONTAL"
		preview.healthOrientation=healthOrientation
		local powerVertical=p.powerBarOrientation=="VERTICAL"
		local powerSide=p.powerBarSide=="RIGHT" and "RIGHT" or "LEFT"
		preview:SetWidth(w); preview:SetHeight(h); preview.health:ClearAllPoints(); preview.health:SetOrientation(healthOrientation); preview.power:ClearAllPoints(); preview.power:SetOrientation(powerVertical and "VERTICAL" or "HORIZONTAL")
		if powerVertical then
			preview.power:SetWidth(powerHeight)
			preview.power:SetHeight(math.max(1,h-4))
			if powerSide=="LEFT" then preview.power:SetPoint("TOPLEFT",preview,"TOPLEFT",2,-2); preview.power:SetPoint("BOTTOMLEFT",preview,"BOTTOMLEFT",2,2); preview.health:SetPoint("TOPLEFT",preview,"TOPLEFT",powerHeight+4,-2); preview.health:SetPoint("BOTTOMRIGHT",preview,"BOTTOMRIGHT",-2,2)
			else preview.power:SetPoint("TOPRIGHT",preview,"TOPRIGHT",-2,-2); preview.power:SetPoint("BOTTOMRIGHT",preview,"BOTTOMRIGHT",-2,2); preview.health:SetPoint("TOPLEFT",preview,"TOPLEFT",2,-2); preview.health:SetPoint("BOTTOMRIGHT",preview,"BOTTOMRIGHT",-(powerHeight+4),2) end
		else
			preview.power:SetWidth(math.max(1,w-4)); preview.power:SetHeight(powerHeight); preview.power:SetPoint("BOTTOMLEFT",preview,"BOTTOMLEFT",2,2); preview.power:SetPoint("BOTTOMRIGHT",preview,"BOTTOMRIGHT",-2,2); preview.health:SetPoint("TOPLEFT",preview,"TOPLEFT",2,-2); preview.health:SetPoint("BOTTOMRIGHT",preview,"BOTTOMRIGHT",-2,powerHeight+4)
		end
		testButton:ClearAllPoints(); testButton:SetPoint("TOPLEFT",preview,"BOTTOMLEFT",0,-8)
		debuffTestButton:ClearAllPoints(); debuffTestButton:SetPoint("LEFT",testButton,"RIGHT",6,0)
		local ind=p.indicators or {}; local n=ind.nameText or {}; local ht=ind.healthText or {}; local pt=ind.powerText or {}; local st=ind.statusText or {}
		local function place(fontString,settings,relative,defaultAnchor,forcedAnchor)
			fontString:ClearAllPoints(); local anchor=forcedAnchor or settings.anchor or defaultAnchor; fontString:SetPoint(anchor,relative,anchor,tonumber(settings.x) or 0,tonumber(settings.y) or 0)
			local outline=tonumber(settings.outline) or 2; local flags=outline==1 and "" or (outline==3 and "THICKOUTLINE" or "OUTLINE")
			local font=(Cell.indicatorFonts or {})[tonumber(settings.font) or Cell.defaultFontIndex or 1]
			fontString:SetFont((font and font.path) or NotCellFontNormalSmall:GetFont(),tonumber(settings.size) or 12,flags); if settings.enabled==false then fontString:Hide() else fontString:Show() end
		end
		place(preview.name,n,preview.health,"TOPLEFT"); place(preview.healthText,ht,preview,"RIGHT"); place(preview.powerText,pt,preview.power,"CENTER","CENTER"); place(preview.status,st,preview,"CENTER")
		local function applyTextColor(fontString,settings,defaultColor,powerColor)
			local mode=settings.colorMode or "class"; local c=settings.color or {1,1,1}
			if mode=="custom" then fontString:SetTextColor(c[1],c[2],c[3])
			elseif mode=="power" then fontString:SetTextColor(powerColor[1],powerColor[2],powerColor[3])
			else fontString:SetTextColor(defaultColor[1],defaultColor[2],defaultColor[3]) end
		end
		applyTextColor(preview.name,n,{.25,.65,1},{.25,.65,1})
		applyTextColor(preview.healthText,ht,{.25,.65,1},{.25,.65,1})
		applyTextColor(preview.powerText,pt,{.25,.65,1},{.2,.35,.95})
		applyTextColor(preview.status,st,{.25,.65,1},{.25,.65,1})
		UpdatePreviewHealthText()
		preview.powerText:SetText(pt.format=="absolute" and "60 / 100" or ("60"..(pt.showPercentSign==false and "" or "%")))
		local function iconSettings(key, icons, single)
			local settings=ind[key] or {}; local shown=settings.enabled~=false; if key=="debuffs" then shown=shown and Cell.showDebuffIcons end; local size=tonumber(settings.iconSize or settings.size) or 16; local fallbackMax=key=="missingBuffs" and 3 or (key=="healerBuffs" and 5 or ((key=="buffs" or key=="debuffs") and 4 or 1)); local max=single and 1 or math.min(key=="missingBuffs" and 3 or (key=="healerBuffs" and 5 or 8),tonumber(settings.maxIcons) or fallbackMax); local rows=math.max(1,tonumber(settings.rows) or 1); local anchor=settings.anchor or "CENTER"
			local auraTextures=not single and GetAuraPreviewTextures(key,settings) or nil
			for i,icon in ipairs(icons) do
				icon:SetWidth(size); icon:SetHeight(size); icon:ClearAllPoints()
				local offsetX,offsetY=GetPreviewAuraOffset(settings,i,max,rows,size)
				icon:SetPoint(anchor,preview,anchor,offsetX,offsetY)
				if auraTextures and auraTextures[i] then icon:SetTexture(auraTextures[i]) end
				if shown and i<=max and (not auraTextures or auraTextures[i]) then icon:Show() else icon:Hide() end
				if key=="missingBuffs" and preview.missingBuffGlow[i] then
					if icon:IsShown() and (not previewOnlySelected or selectedKey==key) then preview.missingBuffGlow[i]:Show() else preview.missingBuffGlow[i]:Hide() end
				end
			end
		end
		for key,icon in pairs(preview.indicatorIcons) do
			iconSettings(key,{icon},true)
		end
		iconSettings("buffs",preview.auraIcons.buffs); iconSettings("debuffs",preview.auraIcons.debuffs); iconSettings("missingBuffs",preview.auraIcons.missingBuffs); iconSettings("healerBuffs",preview.auraIcons.healerBuffs)
		if Cell.ApplyPreviewAppearance then Cell:ApplyPreviewAppearance(preview) end
		ApplyPreviewDebuffTest()
		if previewOnlySelected then
			local selected = selectedKey
			local function setVisible(region, visible)
				if visible then region:Show() else region:Hide() end
			end
			-- This filter applies to indicators only. Keep the preview's health,
			-- health-loss, and power bars visible in both modes.
			setVisible(preview.name, selected == "nameText")
			setVisible(preview.healthText, selected == "healthText")
			setVisible(preview.powerText, selected == "powerText")
			setVisible(preview.status, selected == "statusText")
			for key,icon in pairs(preview.indicatorIcons) do setVisible(icon, key == selected) end
			for auraType,icons in pairs(preview.auraIcons) do
				for i,icon in ipairs(icons) do
					local visible=(auraType == selected or (preview.debuffTesting and auraType=="debuffs" and Cell.showDebuffIcons)) and icon:IsShown()
					setVisible(icon,visible)
					if auraType=="missingBuffs" and preview.missingBuffGlow[i] then setVisible(preview.missingBuffGlow[i],visible) end
				end
			end
			setVisible(preview.debuffBorder, (selected == "debuffs" or preview.debuffTesting) and preview.debuffBorder:IsShown())
			for _,segment in ipairs(preview.debuffSegments) do setVisible(segment, (selected == "debuffs" or preview.debuffTesting) and segment:IsShown()) end

			-- The damage flash is part of the health-bar animation, not an indicator.
			-- Keep it visible while filtering indicators so Flash mode remains testable.
		end
	end
	function panel.OnIndicatorsOpened()
		local statuses={"DEAD","GHOST","OFFLINE"}; preview.status:SetText(statuses[math.random(table.getn(statuses))])
		local roleTextures={"Interface\\AddOns\\NotCell\\Media\\Roles\\Blizzard3_TANK.tga","Interface\\AddOns\\NotCell\\Media\\Roles\\Blizzard3_HEALER.tga","Interface\\AddOns\\NotCell\\Media\\Roles\\Blizzard3_DAMAGER.tga"}; preview.indicatorIcons.roleIcon:SetTexture(roleTextures[math.random(3)])
		local readyTextures={"Interface\\AddOns\\NotCell\\Media\\Icons\\readycheck-waiting.tga","Interface\\AddOns\\NotCell\\Media\\Icons\\readycheck-ready.tga","Interface\\AddOns\\NotCell\\Media\\Icons\\readycheck-notready.tga"}; preview.indicatorIcons.readyCheckIcon:SetTexture(readyTextures[math.random(3)])
		panel.UpdateIndicatorPreview()
	end
	-- Keep the preview attached to the movable Options frame so it cannot drift
	-- as a detached UIParent child when the window is dragged.
	preview:SetPoint("TOPLEFT",panel,"TOPRIGHT",14,-142)
	function panel.RefreshIndicatorSettings()
		local v=values(); local item=indicators[selectedItem]
		for i,row in ipairs(panel.indicatorRows) do
			local selected=i==selectedItem
			local r,g,b=GetUIAccentColor()
			row.background:SetVertexColor(selected and r*.46 or .055,selected and g*.22 or .055,selected and b*.08 or .055,selected and 1 or 0)
			row.label:SetTextColor(selected and r or .88,selected and g or .88,selected and b or .88)
		end
		panel.indicatorEnabled:SetChecked(v.enabled); panel.missingKnown:SetChecked(v.onlyKnown~=false); panel.missingClass:SetChecked(v.onlyCurrentClass~=false)
		panel.indicatorX:SetValue(tonumber(v.x) or 0); panel.indicatorY:SetValue(tonumber(v.y) or 0)
		panel.indicatorSize:SetValue(tonumber(v.size or v.iconSize) or 12); panel.indicatorRowsSlider:SetValue(tonumber(v.rows) or 1)
		panel.indicatorAnchor:RefreshChoiceLabel(); panel.indicatorFont:RefreshChoiceLabel(); panel.indicatorOutline:RefreshChoiceLabel(); panel.indicatorValueFormat:RefreshChoiceLabel(); panel.auraFilter:RefreshChoiceLabel(); panel.indicatorIconGrowth:RefreshChoiceLabel()
		local isText=item.kind=="text"; local isAura=item.kind=="aura"; local isIcon=item.kind=="icon"
		local isMissing=selectedKey=="missingBuffs"; local isHealers=selectedKey=="healerBuffs"
		local hasAuraSettings=isAura and not isMissing
		local maxShown=isMissing and 3 or (isHealers and 5 or 20)
		panel.indicatorMax:SetMinMaxValues(1,maxShown)
		panel.indicatorMax:SetValue(math.min(maxShown,tonumber(v.maxIcons) or 4))
		-- Health/Power Text include the percent-sign toggle below Format; leave
		-- enough scroll-child height for its checkbox instead of clipping it.
		local savedSpellCount=table.getn(v.spells or {})
		local gradientDebuffSettings=selectedKey=="debuffs" and Cell.debuffFillMode=="gradient"
		local minAuraContentHeight=selectedKey=="debuffs" and (gradientDebuffSettings and 1250 or 1080) or 620
		contentHeight=isAura and (isMissing and 520 or math.max(minAuraContentHeight,602+savedSpellCount*18)) or (isText and 480 or 240)
		content:SetHeight(contentHeight); auraControls:SetHeight(contentHeight); auraControls:SetWidth(settingsControlWidth)
		local previousScroll=tonumber(rightScroll:GetValue()) or tonumber(right:GetVerticalScroll()) or 0
		local maxScroll=math.max(0,contentHeight-sectionHeight)
		local restoredScroll=math.max(0,math.min(previousScroll,maxScroll))
		rightScroll:SetMinMaxValues(0,maxScroll); rightScroll:SetValue(restoredScroll); right:SetVerticalScroll(restoredScroll)
		local isValueText=selectedKey=="healthText" or selectedKey=="powerText"
		local function shown(widget, enabled) if enabled then widget:Show() else widget:Hide() end end
		local function shownSlider(slider, enabled)
			shown(slider,enabled); shown(slider.label,enabled); shown(slider.valueBox,enabled)
			shown(slider.minimumLabel,enabled); shown(slider.maximumLabel,enabled); shown(slider.valueBackground,enabled)
			for _,edge in pairs(slider.valueBorder or {}) do shown(edge,enabled) end
		end
		Cell:PlaceOptionsSlider(panel.indicatorX,content,0,panel.indicatorXBaseY,settingsControlWidth)
		Cell:PlaceOptionsSlider(panel.indicatorY,content,0,panel.indicatorYBaseY,settingsControlWidth)
		local sizeY=(isIcon or isAura) and (panel.indicatorY.optionY-68) or panel.indicatorTextSizeY
		Cell:PlaceOptionsSlider(panel.indicatorSize,content,0,sizeY,settingsControlWidth)
		local iconGrowthY=sizeY-sliderPitch
		panel.indicatorIconGrowth:ClearAllPoints(); panel.indicatorIconGrowth:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,iconGrowthY)
		-- Aura-specific sections follow icon positioning. Debuffs get a display
		-- block between Icon Growth and Aura Layout; other auras keep a compact gap.
		local auraY
		if selectedKey=="debuffs" then auraY=iconGrowthY-(gradientDebuffSettings and 286 or 148)
		elseif isMissing then auraY=sizeY-72
		else auraY=iconGrowthY-44 end
		panel.iconLayoutTitle:ClearAllPoints(); panel.iconLayoutTitle:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,auraY)
		Cell:PlaceOptionsSlider(panel.indicatorMax,auraControls,0,auraY-24,settingsControlWidth)
		Cell:PlaceOptionsSlider(panel.indicatorRowsSlider,auraControls,0,auraY-76,settingsControlWidth)
		panel.auraFilterTitle:ClearAllPoints(); panel.auraFilterTitle:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,auraY-134)
		panel.auraFilter:ClearAllPoints(); panel.auraFilter:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,auraY-158)
		panel.dispellableOnly:ClearAllPoints(); panel.dispellableOnly:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,auraY-200)
		local debuffControlsY=iconGrowthY-38
		panel.debuffVisualBaseY=debuffControlsY
		panel.debuffDisplayTitle:ClearAllPoints(); panel.debuffDisplayTitle:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,debuffControlsY)
		panel.debuffDisplayMode:ClearAllPoints(); panel.debuffDisplayMode:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,debuffControlsY-24)
		panel.debuffIconsCheckbox:ClearAllPoints(); panel.debuffIconsCheckbox:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,debuffControlsY-56)
		Cell:PlaceOptionsSlider(panel.debuffAlpha,auraControls,0,debuffControlsY-90,settingsControlWidth)
		Cell:PlaceOptionsSlider(panel.debuffCoverage,auraControls,0,debuffControlsY-150,settingsControlWidth)
		panel.debuffDirection:ClearAllPoints(); panel.debuffDirection:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,debuffControlsY-210)
		panel.missingKnown:ClearAllPoints(); panel.missingKnown:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,auraY-134)
		panel.missingClass:ClearAllPoints(); panel.missingClass:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,isMissing and auraY-164 or auraY-200)
		if selectedKey=="healerBuffs" then spellInputY=auraY-200 elseif selectedKey=="debuffs" then spellInputY=auraY-244 else spellInputY=auraY-232 end
		spellEdit:ClearAllPoints(); spellEdit:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,spellInputY)
		panel.indicatorSpellAdd:ClearAllPoints(); panel.indicatorSpellAdd:SetPoint("TOPLEFT",auraControls,"TOPLEFT",settingsControlWidth-63,spellInputY)
		while table.getn(panel.indicatorSpellRows) < savedSpellCount do CreateSpellRow(table.getn(panel.indicatorSpellRows)+1) end
		for i,row in ipairs(panel.indicatorSpellRows) do
			row:ClearAllPoints(); row:SetPoint("TOPLEFT",auraControls,"TOPLEFT",0,spellInputY-30-(i-1)*18)
			row.removeButton:ClearAllPoints(); row.removeButton:SetPoint("TOPLEFT",auraControls,"TOPLEFT",settingsControlWidth-24,spellInputY-30-(i-1)*18)
		end
		shown(panel.textAppearanceTitle,isText); shown(panel.indicatorFont,isText); shown(panel.indicatorOutline,isText); shown(panel.indicatorColorMode,isText); shown(panel.indicatorColor,isText and v.colorMode=="custom")
		shown(panel.indicatorValueFormat,isValueText)
		shown(panel.indicatorPercentSign,isValueText and v.format~="absolute")
		panel.indicatorPercentSign:SetChecked(v.showPercentSign~=false)
		shown(panel.indicatorSize,isText or isIcon or isAura); shown(panel.indicatorSizeValue,isText or isIcon or isAura)
		panel.indicatorSize.label:SetText(isText and "Font size" or "Icon size")
		if not hasAuraSettings then
			if panel.auraFilter.CloseDropdown then panel.auraFilter:CloseDropdown() end
			if panel.indicatorIconGrowth.CloseDropdown then panel.indicatorIconGrowth:CloseDropdown() end
		end
		shown(auraControls,isAura)
		shown(panel.iconLayoutTitle,isAura); shown(panel.indicatorMax,isAura); shown(panel.indicatorMax.label,isAura); shown(panel.indicatorMaxValue,isAura); shown(panel.indicatorRowsSlider,isAura); shown(panel.indicatorRowsSlider.label,isAura); shown(panel.indicatorRowsValue,isAura)
		shown(panel.indicatorIconGrowth,hasAuraSettings); shown(panel.auraFilterTitle,hasAuraSettings); shown(panel.auraFilter,hasAuraSettings); shown(panel.dispellableOnly,selectedKey=="debuffs"); panel.dispellableOnly:SetChecked(v.onlyDispellable); shown(spellEdit,hasAuraSettings); shown(panel.indicatorSpellAdd,hasAuraSettings)
		shown(panel.missingKnown,isMissing); shown(panel.missingClass,isMissing or selectedKey=="buffs")
		local isDebuffs=selectedKey=="debuffs"
		shown(panel.debuffDisplayTitle,isDebuffs); shown(panel.debuffDisplayMode,isDebuffs)
		shown(panel.debuffIconsCheckbox,isDebuffs); panel.debuffIconsCheckbox:SetChecked(Cell.showDebuffIcons)
		local isGradient=isDebuffs and Cell.debuffFillMode=="gradient"
		shownSlider(panel.debuffAlpha,isGradient)
		shownSlider(panel.debuffCoverage,isGradient)
		shown(panel.debuffDirection,isGradient)
		panel.syncingDebuffControls=true
		panel.debuffAlpha:SetValue(tonumber(Cell.debuffFillAlpha) or 65); panel.debuffCoverage:SetValue(tonumber(Cell.debuffFillAmount) or 100)
		panel.syncingDebuffControls=nil
		panel.debuffDisplayMode:RefreshChoiceLabel(); panel.debuffDirection:RefreshChoiceLabel()
		shown(panel.indicatorXValue,true); shown(panel.indicatorYValue,true)
		panel.indicatorColorMode:RefreshChoiceLabel()
		local color=v.color or {1,1,1}; panel.indicatorColor.swatch:SetVertexColor(color[1],color[2],color[3])
		for i,row in ipairs(panel.indicatorSpellRows) do
			local spell=(v.spells or {})[i]
			if isAura and not isMissing and spell then
				row.spellIndex=i; local texture=spell.icon or (spell.id and GetSpellTexture and GetSpellTexture(spell.id))
				row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark"); row.label:SetText((spell.id and ("["..spell.id.."] ") or "")..spell.name); row:Show(); row.removeButton:Show()
			else row:Hide(); row.removeButton:Hide() end
		end
		if panel.UpdateIndicatorPreview then panel.UpdateIndicatorPreview() end
	end
	RegisterAccentRefresher(function() if panel.RefreshIndicatorSettings then panel.RefreshIndicatorSettings() end end)
	function panel.UpdateIndicatorResponsiveWidth()
		sectionHeight=math.max(300,page:GetHeight()-62); listViewportHeight=math.max(230,page:GetHeight()-148)
		settingsWidth=math.max(228,page:GetWidth()-settingsX-44); settingsControlWidth=settingsWidth-24
		left:SetHeight(listViewportHeight); scroll:SetHeight(listViewportHeight); right:SetHeight(sectionHeight); rightScroll:SetHeight(sectionHeight)
		StyleScrollBar(scroll,table.getn(indicators)*32,listViewportHeight); StyleScrollBar(rightScroll,contentHeight,sectionHeight)
		right:SetWidth(settingsWidth-18); content:SetWidth(settingsWidth-22)
		for _,widget in ipairs({panel.indicatorEnabled,panel.indicatorAnchor,panel.indicatorFont,panel.indicatorOutline,panel.indicatorColorMode,panel.indicatorValueFormat,panel.auraFilter,panel.indicatorIconGrowth,panel.dispellableOnly,panel.debuffDisplayMode,panel.debuffIconsCheckbox,panel.debuffDirection}) do widget:SetWidth(settingsControlWidth) end
		panel.indicatorColorMode:SetWidth(settingsControlWidth-30); panel.indicatorColor:ClearAllPoints(); panel.indicatorColor:SetPoint("TOPLEFT",content,"TOPLEFT",settingsControlWidth-24,panel.indicatorColorY+2)
		spellEdit:SetWidth(settingsControlWidth-70); panel.indicatorSpellAdd:ClearAllPoints(); panel.indicatorSpellAdd:SetPoint("TOPLEFT",auraControls,"TOPLEFT",settingsControlWidth-63,spellInputY)
		auraControls:SetWidth(settingsControlWidth)
		for _,entry in ipairs({{panel.indicatorX,panel.indicatorXValue},{panel.indicatorY,panel.indicatorYValue},{panel.indicatorSize,panel.indicatorSizeValue}}) do
			Cell:PlaceOptionsSlider(entry[1],content,0,entry[1].optionY,settingsControlWidth)
		end
		for _,entry in ipairs({{panel.indicatorMax,panel.indicatorMaxValue},{panel.indicatorRowsSlider,panel.indicatorRowsValue}}) do
			Cell:PlaceOptionsSlider(entry[1],auraControls,0,entry[1].optionY,settingsControlWidth)
		end
		if panel.debuffVisualBaseY then
			Cell:PlaceOptionsSlider(panel.debuffAlpha,auraControls,0,panel.debuffVisualBaseY-90,settingsControlWidth)
			Cell:PlaceOptionsSlider(panel.debuffCoverage,auraControls,0,panel.debuffVisualBaseY-150,settingsControlWidth)
		end
		for _,row in ipairs(panel.indicatorSpellRows) do row:SetWidth(settingsControlWidth-28); row.label:SetWidth(settingsControlWidth-54) end
		panel.indicatorLayoutDropdown:SetWidth(leftWidth)
		if SetPageContentExtent then SetPageContentExtent("indicators", 448) end
	end
	page:SetScript("OnSizeChanged",function() if panel.UpdateIndicatorResponsiveWidth then panel.UpdateIndicatorResponsiveWidth() end end)
	panel.UpdateIndicatorResponsiveWidth()
	panel.RefreshIndicatorSettings()
end



