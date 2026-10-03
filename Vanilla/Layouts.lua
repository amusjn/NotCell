-- Vanilla layout profiles are independent named profiles; auto-switch categories
-- only point to one of these profiles (or to "hide").
local Cell = _G.NotCell
if not Cell then return end

local function QuoteJSON(value)
	value = tostring(value or "")
	local output = {'"'}
	for index = 1, string.len(value) do
		local byte = string.byte(value, index)
		local char = string.sub(value, index, index)
		local nextIndex = table.getn(output) + 1
		if byte == 34 then output[nextIndex] = '\\"'
		elseif byte == 92 then output[nextIndex] = '\\\\'
		elseif byte == 8 then output[nextIndex] = '\\b'
		elseif byte == 9 then output[nextIndex] = '\\t'
		elseif byte == 10 then output[nextIndex] = '\\n'
		elseif byte == 12 then output[nextIndex] = '\\f'
		elseif byte == 13 then output[nextIndex] = '\\r'
		elseif byte < 32 then output[nextIndex] = string.format('\\u%04x', byte)
		else output[nextIndex] = char end
	end
	output[table.getn(output) + 1] = '"'
	return table.concat(output)
end

local function EncodeJSON(value)
	local valueType = type(value)
	if valueType == "nil" then return "null"
	elseif valueType == "boolean" then return value and "true" or "false"
	elseif valueType == "number" then return tostring(value)
	elseif valueType == "string" then return QuoteJSON(value)
	elseif valueType ~= "table" then error("Unsupported layout value") end
	local count, maxIndex, isArray = 0, 0, true
	for key in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then isArray = false
		elseif key > maxIndex then maxIndex = key end
	end
	if isArray and count == maxIndex then
		local parts = {}
		for index = 1, maxIndex do parts[index] = EncodeJSON(value[index]) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
		for key in pairs(value) do keys[table.getn(keys) + 1] = tostring(key) end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		local originalKey = key
		for candidate in pairs(value) do if tostring(candidate) == key then originalKey = candidate; break end end
		parts[table.getn(parts) + 1] = QuoteJSON(key) .. ":" .. EncodeJSON(value[originalKey])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function RestoreNumericKeys(value)
	if type(value) ~= "table" then return value end
	local move = {}
	for key, item in pairs(value) do
		RestoreNumericKeys(item)
		if type(key) == "string" and string.match(key, "^%d+$") then
			local numeric = tonumber(key)
		if numeric and tostring(numeric) == key then move[table.getn(move) + 1] = {key, numeric, item} end
		end
	end
	for _, item in ipairs(move) do value[item[1]] = nil; value[item[2]] = item[3] end
	return value
end

local function CopyTable(source)
	-- Saved layouts can contain scalar values in fields that are normally tables
	-- (for example, after manual edits or older broken exports). Preserve scalars
	-- instead of passing them to pairs().
	if type(source) ~= "table" then return source end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value
	end
	return copy
end

function Cell:RefreshLayoutProfiles(profiles)
	if type(profiles) == "table" then self.groupLayoutProfiles = profiles end
	self.groupLayoutProfiles = type(self.groupLayoutProfiles) == "table" and self.groupLayoutProfiles or {}
	if type(self.groupLayoutProfiles.Default) ~= "table" then self.groupLayoutProfiles.Default = {} end
	self.groupLayoutNames = {}
	self.groupLayoutLabels = {}
	for name, profile in pairs(self.groupLayoutProfiles) do
		if type(name) == "string" and type(profile) == "table" then
			profile.groupFilter = type(profile.groupFilter) == "table" and profile.groupFilter or {}
			for group = 1, 8 do if profile.groupFilter[group] == nil then profile.groupFilter[group] = true end end
			profile.direction = profile.direction or ((profile.growth == "right-down" or profile.growth == "left-down") and "right-down" or "down-right")
			profile.healthBarOrientation = profile.healthBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
			profile.powerBarOrientation = profile.powerBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
			profile.powerBarSide = profile.powerBarSide == "RIGHT" and "RIGHT" or "LEFT"
			self.groupLayoutNames[table.getn(self.groupLayoutNames) + 1] = name
			self.groupLayoutLabels[name] = name
		end
	end
	table.sort(self.groupLayoutNames, function(a, b)
		if a == b then return false end
		if a == "Default" then return true end
		if b == "Default" then return false end
		return string.lower(a) < string.lower(b)
	end)
	if not self.groupLayoutProfiles[self.selectedGroupLayout] then self.selectedGroupLayout = "Default" end
	return self.groupLayoutNames
end

function Cell:SaveLayoutProfiles()
	NotCellDB = type(NotCellDB) == "table" and NotCellDB or {}
	NotCellVanillaDB = type(NotCellVanillaDB) == "table" and NotCellVanillaDB or NotCellDB.CellVanillaPreview or {}
	NotCellVanillaDB.layouts = self.groupLayoutProfiles
	-- Kept as an alias for the previous Vanilla build and the Indicators editor.
	NotCellVanillaDB.groupLayoutProfiles = self.groupLayoutProfiles
	NotCellVanillaDB.selectedLayout = self.selectedGroupLayout
	NotCellVanillaDB.selectedGroupLayout = self.selectedGroupLayout
	NotCellVanillaDB.layoutAutoSwitch = self.layoutAutoSwitch
	NotCellVanillaDB.autoGroupLayouts = self.autoGroupLayouts
	NotCellDB.CellVanillaPreview = NotCellVanillaDB
end

function Cell:CreateLayoutProfile(name, sourceName)
	name = string.gsub(tostring(name or ""), "^%s*(.-)%s*$", "%1")
	if name == "" or name == "Default" or self.groupLayoutProfiles[name] then return nil, "Choose a unique layout name." end
	local source = self.groupLayoutProfiles[sourceName or self.selectedGroupLayout] or {}
	self.groupLayoutProfiles[name] = CopyTable(source)
	self.groupLayoutNames[table.getn(self.groupLayoutNames) + 1] = name
	self.groupLayoutLabels[name] = name
	self.selectedGroupLayout = name
	self:SaveLayoutProfiles()
	self:RefreshLayoutProfiles()
	return name
end

function Cell:RenameLayoutProfile(oldName, newName)
	newName = string.gsub(tostring(newName or ""), "^%s*(.-)%s*$", "%1")
	if oldName == "Default" then return nil, "The Default layout cannot be renamed." end
	if not self.groupLayoutProfiles[oldName] or newName == "" or newName == "Default" or self.groupLayoutProfiles[newName] then return nil, "Choose a unique layout name." end
	self.groupLayoutProfiles[newName] = self.groupLayoutProfiles[oldName]
	self.groupLayoutProfiles[oldName] = nil
	for groupType, name in pairs(self.layoutAutoSwitch or {}) do if name == oldName then self.layoutAutoSwitch[groupType] = newName end end
	if self.selectedGroupLayout == oldName then self.selectedGroupLayout = newName end
	self:RefreshLayoutProfiles()
	self:SaveLayoutProfiles()
	return newName
end

function Cell:DeleteLayoutProfile(name)
	if name == "Default" then return nil, "The Default layout cannot be deleted." end
	if not self.groupLayoutProfiles[name] then return nil, "Layout not found." end
	self.groupLayoutProfiles[name] = nil
	for groupType, mappedName in pairs(self.layoutAutoSwitch or {}) do if mappedName == name then self.layoutAutoSwitch[groupType] = "Default" end end
	if self.selectedGroupLayout == name then self.selectedGroupLayout = "Default" end
	self:RefreshLayoutProfiles()
	self:SaveLayoutProfiles()
	return true
end

function Cell:ExportLayoutProfile(name)
	local profile = self.groupLayoutProfiles[name]
	if not profile then return nil, "Layout not found." end
	-- Layout exports deliberately whitelist layout geometry and placement. Indicator
	-- configuration is stored beside layout data in saved variables, but is not part
	-- of a layout and may contain hundreds of spell IDs.
	local fields = {"width", "height", "powerBarHeight", "nameFontSize", "healthTextFontSize", "powerTextFontSize", "groupsPerLine", "direction", "growth", "healthBarOrientation", "powerBarOrientation", "powerBarSide", "groupFilter", "spacingX", "spacingY", "position"}
	local layout = {}
	for _, key in ipairs(fields) do if profile[key] ~= nil then layout[key] = CopyTable(profile[key]) end end
	local ok, serialized = pcall(EncodeJSON, {format = "NotCellLayout", version = 1, name = name, profile = layout})
	if not ok or not serialized then return nil, "Could not serialize this layout." end
	return serialized
end

local compactProfileKeys = {
	width="w", height="h", powerBarHeight="p", nameFontSize="n", healthTextFontSize="u", powerTextFontSize="v", groupsPerLine="g", direction="d", growth="r",
	healthBarOrientation="o", powerBarOrientation="q", powerBarSide="s", groupFilter="f",
	spacingX="x", spacingY="y", position="t",
}
local expandedProfileKeys = {}
for key, shortKey in pairs(compactProfileKeys) do expandedProfileKeys[shortKey] = key end

function Cell:EncodeLayoutProfile(payload)
	local ok, data = pcall(self.DecodeVanillaJSON, self, payload or "")
	if not ok or type(data) ~= "table" or (data.format ~= "NotCellLayout" and data.format ~= "CellVanillaLayout") or type(data.profile) ~= "table" or type(data.name) ~= "string" then
		return nil, "Invalid layout JSON."
	end
	local compact = {f="NotCellLayout", v=1, n=data.name, p={}}
	for key, shortKey in pairs(compactProfileKeys) do
		if data.profile[key] ~= nil then compact.p[shortKey] = data.profile[key] end
	end
	local encoded, result = pcall(EncodeJSON, compact)
	if not encoded or not result then return nil, "Could not encode this layout." end
	return "CELL1:" .. result
end

function Cell:DecodeLayoutProfile(payload)
	if string.sub(payload or "", 1, 6) ~= "CELL1:" then return payload end
	local ok, compact = pcall(self.DecodeVanillaJSON, self, string.sub(payload, 7))
	if not ok or type(compact) ~= "table" or (compact.f ~= "NotCellLayout" and compact.f ~= "CellVanillaLayout") or tonumber(compact.v) ~= 1 or type(compact.p) ~= "table" then
		return nil, "Invalid encoded layout."
	end
	local data = {format="NotCellLayout", version=1, name=compact.n, profile={}}
	for shortKey, value in pairs(compact.p) do
		local key = expandedProfileKeys[shortKey]
		if key then data.profile[key] = value end
	end
	local encoded, result = pcall(EncodeJSON, data)
	if not encoded or not result then return nil, "Could not decode this layout." end
	return result
end

function Cell:ImportLayoutProfile(payload)
	local decodeError
	payload, decodeError = self:DecodeLayoutProfile(payload or "")
	if not payload then return nil, decodeError or "Invalid encoded layout." end
	local success, data = pcall(self.DecodeVanillaJSON, self, payload or "")
	if not success or type(data) ~= "table" or type(data.profile) ~= "table" or type(data.name) ~= "string" then return nil, "Invalid layout contents." end
	if (data.format ~= "NotCellLayout" and data.format ~= "CellVanillaLayout") or tonumber(data.version) ~= 1 then return nil, "This is not a supported NotCell layout export." end
	local name = string.gsub(data.name, "^%s*(.-)%s*$", "%1")
	if name == "" or name == "Default" then name = "Imported layout" end
	local baseName, suffix = name, 2
	while self.groupLayoutProfiles[name] do name = baseName .. " " .. suffix; suffix = suffix + 1 end
	local profile = RestoreNumericKeys(CopyTable(data.profile))
	profile.width = math.max(40, math.min(300, tonumber(profile.width) or self.buttonWidth or 130))
	profile.height = math.max(32, math.min(120, tonumber(profile.height) or self.buttonHeight or 50))
	profile.powerBarHeight = math.max(2, math.min(12, tonumber(profile.powerBarHeight) or self.powerBarHeight or 4))
	profile.groupsPerLine = math.max(1, math.min(8, tonumber(profile.groupsPerLine) or 4))
	profile.direction = profile.direction or "down-right"
	profile.healthBarOrientation = profile.healthBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
	profile.powerBarOrientation = profile.powerBarOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
	profile.powerBarSide = profile.powerBarSide == "RIGHT" and "RIGHT" or "LEFT"
	profile.groupFilter = type(profile.groupFilter) == "table" and profile.groupFilter or {}
	for group = 1, 8 do if profile.groupFilter[group] == nil then profile.groupFilter[group] = true end end
	profile.spacingX = math.max(0, math.min(100, tonumber(profile.spacingX) or self.horizontalGap or 5))
	profile.spacingY = math.max(0, math.min(100, tonumber(profile.spacingY) or self.verticalGap or 4))
	if type(profile.position) ~= "table" then profile.position = nil end
	if type(profile.indicators) ~= "table" then profile.indicators = {} end
	self.groupLayoutProfiles[name] = profile
	self:RefreshLayoutProfiles()
	self.selectedGroupLayout = name
	self:SaveLayoutProfiles()
	return name
end
