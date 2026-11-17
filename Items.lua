local _, ns = ...

local CC = C_Container or {}
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

local C = {}
ns.C = C

local function num(v, default)
	if type(v) == "number" and not ns.IsSecret(v) then return v end
	return default
end

function C.Slots(bag)
	if bag == nil then return 0 end
	if bag == KEYRING_CONTAINER and GetKeyRingSize then
		local ok, n = pcall(GetKeyRingSize)
		return ok and num(n, 0) or 0
	end
	local f = CC.GetContainerNumSlots or GetContainerNumSlots
	if not f then return 0 end
	local ok, n = pcall(f, bag)
	return ok and num(n, 0) or 0
end

function C.Free(bag)
	local f = CC.GetContainerNumFreeSlots or GetContainerNumFreeSlots
	if not f then return 0, 0 end
	local ok, n, family = pcall(f, bag)
	if not ok then return 0, 0 end
	return num(n, 0), num(family, 0)
end

function C.Info(bag, slot)
	if CC.GetContainerItemInfo then
		local ok, t = pcall(CC.GetContainerItemInfo, bag, slot)
		if not ok or type(t) ~= "table" or ns.IsSecret(t.itemID) or not t.itemID then return nil end
		return {
			icon = t.iconFileID, count = num(t.stackCount, 1), locked = t.isLocked and true or false,
			quality = num(t.quality), link = t.hyperlink, noValue = t.hasNoValue and true or false,
			id = t.itemID, bound = t.isBound and true or false,
		}
	elseif GetContainerItemInfo then
		local icon, count, locked, quality, _, _, link, _, noValue, id = GetContainerItemInfo(bag, slot)
		if not icon then return nil end
		if not id and link then id = tonumber(link:match("item:(%d+)")) end
		if not id then return nil end
		return {
			icon = icon, count = num(count, 1), locked = locked and true or false, quality = num(quality),
			link = link, noValue = noValue and true or false, id = id, bound = false,
		}
	end
	return nil
end

function C.Cooldown(bag, slot)
	local f = CC.GetContainerItemCooldown or GetContainerItemCooldown
	if not f then return 0, 0, 0 end
	local ok, start, duration, enable = pcall(f, bag, slot)
	if not ok then return 0, 0, 0 end
	if ns.IsSecret(start) or ns.IsSecret(duration) then return start, duration, 1, true end
	if ns.IsSecret(enable) then enable = 1 end
	return start or 0, duration or 0, enable or 0
end

function C.Quest(bag, slot)
	if not CC.GetContainerItemQuestInfo then return false, false end
	local ok, t = pcall(CC.GetContainerItemQuestInfo, bag, slot)
	if not ok or type(t) ~= "table" then return false, false end
	local starts = t.questID and not t.isActive
	return (t.isQuestItem or t.questID) and true or false, starts and true or false
end

function C.Use(bag, slot)
	local f = CC.UseContainerItem or UseContainerItem
	if f then pcall(f, bag, slot) end
end

function C.Pickup(bag, slot)
	local f = CC.PickupContainerItem or PickupContainerItem
	if f then pcall(f, bag, slot) end
end

function C.InventoryID(bag)
	local f = CC.ContainerIDToInventoryID or ContainerIDToInventoryID
	if not f then return nil end
	local ok, id = pcall(f, bag)
	return ok and num(id) or nil
end

local BACKPACK = BACKPACK_CONTAINER or 0
local NUM_BAGS = NUM_BAG_SLOTS or 4
local NUM_HELD = math.max(NUM_BAGS, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0)
local NUM_BANK = NUM_BANKBAGSLOTS or 6
local BANK = BANK_CONTAINER or -1

function ns.BankType()
	return Enum and Enum.BankType and Enum.BankType.Character
end

function ns.TabbedBank()
	return C_Bank and C_Bank.FetchPurchasedBankTabIDs and ns.BankType() ~= nil and true or false
end

local function bankTabs()
	local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, ns.BankType())
	local out = {}
	if ok and type(ids) == "table" then
		for _, id in ipairs(ids) do
			if type(id) == "number" then out[#out + 1] = id end
		end
	end
	return out
end

function ns.BagList(kind)
	local out = {}
	if kind == "bank" then
		if ns.TabbedBank() then return bankTabs() end
		out[1] = BANK
		for i = 1, NUM_BANK do out[#out + 1] = NUM_HELD + i end
	else
		for i = BACKPACK, NUM_HELD do out[#out + 1] = i end
		if ns.db.keyring and KEYRING_CONTAINER and C.Slots(KEYRING_CONTAINER) > 0 then
			out[#out + 1] = KEYRING_CONTAINER
		end
	end
	return out
end

function ns.BagBarList(kind)
	local out = {}
	if kind == "bank" then
		if ns.TabbedBank() then
			local index = Enum.BagIndex or {}
			local holder, first = index.Characterbanktab, index.CharacterBankTab_1
			if not holder or not first or not C_Bank.FetchMaxNumBankTabs then return out end
			local ok, max = pcall(C_Bank.FetchMaxNumBankTabs, ns.BankType())
			if not ok or type(max) ~= "number" then return out end
			for n = 2, max do out[#out + 1] = { bag = first + n - 1, holder = holder, index = n } end
			return out
		end
		for i = 1, NUM_BANK do out[#out + 1] = { bag = NUM_HELD + i } end
	else
		for i = 1, NUM_HELD do out[#out + 1] = { bag = i } end
	end
	return out
end

ns.CATEGORIES = { "Equipment", "Consumables", "Trade goods", "Quest", "Other", "Junk" }
local CATORDER = {}
for i, c in ipairs(ns.CATEGORIES) do CATORDER[c] = i end

local QUALITY = { [0] = "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact", "heirloom" }

local details = {}

local function detail(id, link)
	local d = details[id]
	if d and d.full then return d end
	d = d or { id = id }
	if GetInfo then
		local ok, name, _, quality, ilvl, _, itemType, subType, _, equipLoc, _, price, classID, subclassID, bindType = pcall(GetInfo, link or id)
		if ok and name then
			d.name, d.quality, d.ilvl, d.type, d.subType, d.equipLoc = name, quality, ilvl, itemType, subType, equipLoc
			d.price, d.classID, d.subclassID, d.bindType = price or 0, classID, subclassID, bindType
			d.lower = (name .. " " .. (itemType or "") .. " " .. (subType or "")):lower()
			d.full = true
		end
	end
	if not d.classID and GetInstant then
		local ok, _, itemType, subType, equipLoc, _, classID, subclassID = pcall(GetInstant, id)
		if ok then
			d.type, d.subType, d.equipLoc, d.classID, d.subclassID = itemType, subType, equipLoc, classID, subclassID
		end
	end
	details[id] = d
	return d
end

ns.Detail = detail

function ns.Category(item)
	if item.junk then return "Junk" end
	local c = item.classID
	if c == 2 or c == 4 then return "Equipment" end
	if c == 0 then return "Consumables" end
	if c == 7 or c == 5 or c == 9 or c == 3 then return "Trade goods" end
	if c == 12 then return "Quest" end
	return "Other"
end

function ns.Scan(kind)
	local out = {}
	for _, bag in ipairs(ns.BagList(kind)) do
		local _, family = C.Free(bag)
		for slot = 1, C.Slots(bag) do
			local e = { bag = bag, slot = slot, family = family }
			local info = C.Info(bag, slot)
			if info then
				local d = detail(info.id, info.link)
				e.id, e.link, e.icon, e.count, e.locked, e.bound = info.id, info.link, info.icon, info.count, info.locked, info.bound
				e.quality = info.quality or d.quality or 1
				e.name = d.name or ("Item " .. info.id)
				e.lower = d.lower or e.name:lower()
				e.classID, e.subclassID, e.equipLoc, e.bindType = d.classID, d.subclassID, d.equipLoc, d.bindType
				e.price = d.price or 0
				e.ilvl = d.ilvl
				if (e.classID == 2 or e.classID == 4) and GetLevel and info.link then
					local ok, level = pcall(GetLevel, info.link)
					if ok and num(level) then e.ilvl = level end
				end
				e.junk = e.quality == 0 and e.price > 0 and not info.noValue
				e.quest, e.starts = C.Quest(bag, slot)
				e.category = ns.Category(e)
			end
			out[#out + 1] = e
		end
	end
	return out
end

function ns.Matches(item, query)
	if not query or query == "" then return true end
	if not item.id then return false end
	for word in query:lower():gmatch("%S+") do
		local ok
		if word == "junk" then
			ok = item.junk
		elseif word == "boe" then
			ok = item.bindType == 2 and not item.bound
		elseif word == "quest" then
			ok = item.classID == 12 or item.lower:find(word, 1, true)
		elseif QUALITY[item.quality or 1] == word then
			ok = true
		else
			ok = item.lower:find(word, 1, true) or item.category:lower():find(word, 1, true)
		end
		if not ok then return false end
	end
	return true
end

function ns.Before(a, b)
	local ca, cb = CATORDER[a.category] or 9, CATORDER[b.category] or 9
	if ca ~= cb then return ca < cb end
	if a.quality ~= b.quality then return a.quality > b.quality end
	if (a.classID or 99) ~= (b.classID or 99) then return (a.classID or 99) < (b.classID or 99) end
	if a.name ~= b.name then return a.name < b.name end
	if a.id ~= b.id then return a.id < b.id end
	return a.count > b.count
end

function ns.FreeText(kind)
	local free, total = 0, 0
	local special = {}
	for _, bag in ipairs(ns.BagList(kind)) do
		local size = C.Slots(bag)
		if size > 0 and bag ~= KEYRING_CONTAINER then
			local f, family = C.Free(bag)
			if family == 0 then
				free, total = free + f, total + size
			else
				special[family] = (special[family] or 0) + f
			end
		end
	end
	local text = free .. " / " .. total .. " free"
	local names = { [1] = "Quiver", [2] = "Ammo", [4] = "Soul", [8] = "Leather", [32] = "Herb", [64] = "Enchant", [128] = "Engineer", [1024] = "Mining" }
	local keys = {}
	for family in pairs(special) do keys[#keys + 1] = family end
	table.sort(keys)
	for _, family in ipairs(keys) do
		text = text .. "   " .. (names[family] or "Special") .. " " .. special[family]
	end
	return text, free, total
end

local sorting
local function sortStep(kind, steps)
	if ns.InCombat() or steps > 400 then
		sorting = nil
		ns:Fire("SORT_DONE")
		return
	end
	local slots, items = {}, {}
	for _, e in ipairs(ns.Scan(kind)) do
		if e.family == 0 and e.bag ~= KEYRING_CONTAINER then
			slots[#slots + 1] = e
			if e.id then items[#items + 1] = e end
		end
	end
	table.sort(items, ns.Before)
	for i, want in ipairs(items) do
		local at = slots[i]
		if at.id ~= want.id or at.count ~= want.count then
			if not at.locked and not want.locked then
				if ClearCursor then ClearCursor() end
				C.Pickup(want.bag, want.slot)
				C.Pickup(at.bag, at.slot)
				if ClearCursor then ClearCursor() end
			end
			ns.After(0.15, function() sortStep(kind, steps + 1) end)
			return
		end
	end
	sorting = nil
	ns:Fire("SORT_DONE")
end

function ns.Sort(kind)
	if ns.InCombat() then
		ns.Print("Cannot sort in combat")
		return
	end
	if kind == "bank" then
		if CC.SortBank and ns.BankType() ~= nil then
			pcall(CC.SortBank, ns.BankType())
			return
		end
		local f = CC.SortBankBags or SortBankBags
		if f then
			pcall(f)
			return
		end
	else
		local f = CC.SortBags or SortBags
		if f then
			pcall(f)
			return
		end
	end
	if sorting then return end
	sorting = true
	sortStep(kind, 0)
end

function ns.Wished(id)
	local db = ALootDB
	if type(db) ~= "table" or type(db.lists) ~= "table" then return false end
	for _, list in ipairs(db.lists) do
		if type(list.items) == "table" and list.items[id] then return true end
	end
	return false
end

function ns.CharKey()
	local name = UnitName and UnitName("player") or "Player"
	local realm = GetRealmName and GetRealmName() or "Realm"
	return tostring(name) .. " - " .. tostring(realm)
end
