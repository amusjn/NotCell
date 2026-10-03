-- Click-cast profile clipboard serialization, kept separate from the options UI.
local Cell = _G.NotCell
if not Cell then return end

local function JSONQuote(value)
	value = tostring(value or "")
	local output = {'"'}
	for i = 1, string.len(value) do
		local byte = string.byte(value, i)
		local nextIndex = table.getn(output) + 1
		if byte == 34 then output[nextIndex] = '\\"'
		elseif byte == 92 then output[nextIndex] = '\\\\'
		elseif byte == 8 then output[nextIndex] = '\\b'
		elseif byte == 9 then output[nextIndex] = '\\t'
		elseif byte == 10 then output[nextIndex] = '\\n'
		elseif byte == 12 then output[nextIndex] = '\\f'
		elseif byte == 13 then output[nextIndex] = '\\r'
		elseif byte < 32 then output[nextIndex] = string.format('\\u%04x', byte)
		else output[nextIndex] = string.char(byte) end
	end
	output[table.getn(output) + 1] = '"'
	return table.concat(output)
end

function Cell:ExportClickCastProfile(profileName, casts)
	local slots = {}
	for slot in pairs(casts or {}) do slots[table.getn(slots) + 1] = slot end
	table.sort(slots, function(a, b) return tostring(a) < tostring(b) end)
	local rows = {}
	for _, slot in ipairs(slots) do
		local stored = casts[slot]
		local kind, action
		if type(stored) == "table" then kind = stored.kind or "target"; action = stored.text or ""
		else kind = "spell"; action = stored or "" end
		rows[table.getn(rows) + 1] = '{"key":' .. JSONQuote(slot) .. ',"type":' .. JSONQuote(kind) .. ',"action":' .. JSONQuote(action) .. '}'
	end
	return '{\n  "format": "NotCellClickCast",\n  "version": 1,\n  "profile": ' .. JSONQuote(profileName) .. ',\n  "bindings": [' .. (table.getn(rows) > 0 and '\n    ' .. table.concat(rows, ',\n    ') .. '\n  ' or '') .. ']\n}'
end

local function UTF8(code)
	if code < 128 then return string.char(code)
	elseif code < 2048 then return string.char(192 + math.floor(code / 64), 128 + code % 64)
	elseif code < 65536 then return string.char(224 + math.floor(code / 4096), 128 + math.floor(code / 64) % 64, 128 + code % 64)
	else return string.char(240 + math.floor(code / 262144), 128 + math.floor(code / 4096) % 64, 128 + math.floor(code / 64) % 64, 128 + code % 64) end
end

local function ParseJSON(source)
	local position = 1
	local function SkipSpace()
		while string.match(string.sub(source, position, position), "%s") do position = position + 1 end
	end
	local function ParseString()
		if string.sub(source, position, position) ~= '"' then return nil end
		position = position + 1
		local output = {}
		while position <= string.len(source) do
			local char = string.sub(source, position, position)
			position = position + 1
			if char == '"' then return table.concat(output) end
			if char == "\\" then
				local escaped = string.sub(source, position, position); position = position + 1
				local replacements = {['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t'}
				if replacements[escaped] then output[table.getn(output) + 1] = replacements[escaped]
				elseif escaped == "u" then
					local hex = string.sub(source, position, position + 3)
					if string.len(hex) ~= 4 or not string.match(hex, "^%x%x%x%x$") then return nil end
					position = position + 4; output[table.getn(output) + 1] = UTF8(tonumber(hex, 16))
				else return nil end
			elseif string.byte(char) < 32 then return nil
			else output[table.getn(output) + 1] = char end
		end
		return nil
	end
	local ParseValue
	local function ParseArray()
		position = position + 1; SkipSpace()
		local result = {}
		if string.sub(source, position, position) == ']' then position = position + 1; return result end
		while true do
			local value = ParseValue(); if value == nil then return nil end
			result[table.getn(result) + 1] = value; SkipSpace()
			local char = string.sub(source, position, position); position = position + 1
			if char == ']' then return result elseif char ~= ',' then return nil end
			SkipSpace()
		end
	end
	local function ParseObject()
		position = position + 1; SkipSpace()
		local result = {}
		if string.sub(source, position, position) == '}' then position = position + 1; return result end
		while true do
			local key = ParseString(); if key == nil then return nil end
			SkipSpace(); if string.sub(source, position, position) ~= ':' then return nil end
			position = position + 1; SkipSpace()
			local value = ParseValue(); if value == nil then return nil end
			result[key] = value; SkipSpace()
			local char = string.sub(source, position, position); position = position + 1
			if char == '}' then return result elseif char ~= ',' then return nil end
			SkipSpace()
		end
	end
	ParseValue = function()
		SkipSpace()
		local char = string.sub(source, position, position)
		if char == '"' then return ParseString()
		elseif char == '{' then return ParseObject()
		elseif char == '[' then return ParseArray()
		elseif string.sub(source, position, position + 3) == "true" then position = position + 4; return true
		elseif string.sub(source, position, position + 4) == "false" then position = position + 5; return false
		elseif string.sub(source, position, position + 3) == "null" then position = position + 4; return false
		else
			local number = string.match(string.sub(source, position), "^-?%d+%.?%d*[eE]?[+-]?%d*")
			if number and number ~= "" then position = position + string.len(number); return tonumber(number) end
		end
		return nil
	end
	local result = ParseValue(); SkipSpace()
	if result == nil or position <= string.len(source) then return nil end
	return result
end

function Cell:DecodeVanillaJSON(source)
	return ParseJSON(source)
end

function Cell:ImportClickCastProfile(payload)
	payload = string.gsub(payload or "", "\r", "")
	payload = string.gsub(payload, "^\239\187\191", "")
	local first = string.match(payload, "^%s*(.-)%s*$")
	if string.sub(first or "", 1, 1) == "{" then
		local data = ParseJSON(payload)
		if not data or (data.format ~= "NotCellClickCast" and data.format ~= "CellClickCast") or type(data.version) ~= "number" or data.version ~= 1 or type(data.bindings) ~= "table" then return nil, nil, "Invalid JSON click-cast profile." end
		local imported = {}
		for _, row in ipairs(data.bindings) do
			if type(row) == "table" and type(row.key) == "string" and row.key ~= "" and type(row.type) == "string" and type(row.action) == "string" then
				if row.type == "spell" then imported[row.key] = row.action
				elseif row.type == "macro" or row.type == "target" or row.type == "menu" then imported[row.key] = {kind = row.type, text = row.action} end
			end
		end
		return imported, type(data.profile) == "string" and data.profile or "unnamed profile"
	end
	return nil, nil, "Invalid JSON click-cast profile. Paste the complete JSON export."
end
