local _, ns = ...
local UI = ns.UI
local C = UI.colors

local View = {}
ns.View = View

local function pack(kind)
	local out = {}
	for _, e in ipairs(ns.Scan(kind)) do
		if e.id then out[#out + 1] = e.id .. ":" .. (e.count or 1) end
	end
	return out
end

local function char()
	local key = ns.CharKey()
	local c = ns.db.chars[key]
	if not c then
		c = {}
		ns.db.chars[key] = c
	end
	c.name = UnitName and UnitName("player") or key
	c.class = ns.playerClass
	return c
end

function ns.SaveBags()
	local c = char()
	c.bags = pack("bags")
	local money = GetMoney and GetMoney() or 0
	if type(money) == "number" and not ns.IsSecret(money) then c.money = money end
	c.seen = time and time() or 0
end

function ns.SaveBank()
	local c = char()
	c.bank = pack("bank")
	c.bankSeen = time and time() or 0
end

ns:Listen("LOGIN", function() ns.SaveBags() end)
ns:Listen("BAGS_CHANGED", function()
	ns.SaveBags()
	if ns.atBank then ns.SaveBank() end
end)

local frame
local buttons = {}

local function build()
	frame = UI.Window("ABagViewFrame", "Stored items", 440, 300, ns.db.view)
	frame:SetFrameStrata("MEDIUM")
	frame.note = UI.Text(frame.body, "GameFontDisableSmall", "LEFT", C.dim)
	frame.note:SetPoint("BOTTOMLEFT", 10, 8)
end

local function unpackItems(list)
	local merged, order = {}, {}
	for _, s in ipairs(list or {}) do
		local id, count = s:match("^(%d+):(%d+)$")
		id, count = tonumber(id), tonumber(count)
		if id then
			if not merged[id] then
				local d = ns.Detail(id)
				merged[id] = {
					id = id, count = 0, name = d.name or ("Item " .. id), quality = d.quality or 1,
					classID = d.classID, ilvl = d.ilvl, price = d.price or 0, lower = d.lower or "",
				}
				order[#order + 1] = merged[id]
			end
			merged[id].count = merged[id].count + count
		end
	end
	for _, e in ipairs(order) do
		e.junk = e.quality == 0 and e.price > 0
		e.category = ns.Category(e)
		local icon
		if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(e.id) elseif GetItemIcon then icon = GetItemIcon(e.id) end
		e.icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	table.sort(order, ns.Before)
	return order
end

function View.Show(key, which)
	local c = ns.db.chars[key]
	if not c then
		ns.Print("Nothing stored for " .. tostring(key))
		return
	end
	if not frame then build() end
	local items = unpackItems(which == "bank" and c.bank or c.bags)
	local cols, cell = 10, 41
	for i, e in ipairs(items) do
		local b = buttons[i]
		if not b then
			b = ns.NewPlainButton(frame.body)
			b:SetScript("OnEnter", function(self)
				if not self.item then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetHyperlink("item:" .. self.item.id)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			buttons[i] = b
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 10 + ((i - 1) % cols) * cell, -10 - math.floor((i - 1) / cols) * cell)
		ns.UpdateButton(b, e)
		b:SetAlpha(1)
		b:Show()
	end
	for i = #items + 1, #buttons do buttons[i]:Hide() end
	local rows = math.max(1, math.ceil(#items / cols))
	frame:SetSize(cols * cell - 4 + 20, 34 + 10 + rows * cell + 26)
	frame.title:SetText((c.name or key) .. " - " .. (which == "bank" and "Bank" or "Bags"))
	if which == "bank" and not c.bank then
		frame.note:SetText("Visit a banker once to store the bank contents")
	else
		frame.note:SetText(#items .. " different items, read only")
	end
	frame:Show()
end

function View.Menu(anchor)
	local entries = { { text = "Stored items", title = true } }
	local keys = {}
	for key in pairs(ns.db.chars) do keys[#keys + 1] = key end
	table.sort(keys)
	local me = ns.CharKey()
	for _, key in ipairs(keys) do
		local c = ns.db.chars[key]
		local name = c.name or key
		local color
		if c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class] then
			local cc = RAID_CLASS_COLORS[c.class]
			color = { cc.r, cc.g, cc.b }
		end
		if key ~= me then
			entries[#entries + 1] = { text = name .. ": bags", color = color, func = function() View.Show(key, "bags") end }
		end
		entries[#entries + 1] = { text = name .. ": bank", color = color, func = function() View.Show(key, "bank") end }
	end
	UI.Menu(anchor, entries)
end
