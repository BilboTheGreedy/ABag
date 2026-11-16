local _, ns = ...
local UI = ns.UI
local C = UI.colors

local PAD = 10
local containers = {}

local function options(anchor)
	local db = ns.db
	local function relayout() ns:Fire("LAYOUT") end
	local entries = {
		{ text = "Options", title = true },
		UI.Check(db, "categories", "Group items by category", relayout),
		UI.Check(db, "bagbar", "Show the bag slots", relayout),
		UI.Check(db, "keyring", "Show the keyring", relayout),
		UI.Check(db, "ilvl", "Item level on equipment", relayout),
		UI.Check(db, "glow", "Highlight new items", relayout),
		UI.Check(db, "autoOpen", "Open at vendors, bank, mail and auctions"),
		UI.Check(db, "autoSell", "Sell junk automatically"),
		UI.Check(db, "autoRepair", "Repair automatically"),
		{ text = "Columns", title = true },
	}
	for _, n in ipairs({ 8, 10, 12, 14, 16 }) do
		entries[#entries + 1] = {
			text = tostring(n), checked = db.columns == n,
			func = function()
				db.columns = n
				relayout()
			end,
		}
	end
	entries[#entries + 1] = { text = "Button size", title = true }
	for _, n in ipairs({ 30, 34, 37, 42 }) do
		entries[#entries + 1] = {
			text = tostring(n), checked = db.size == n,
			func = function()
				db.size = n
				relayout()
			end,
		}
	end
	for _, e in ipairs(UI.ScaleEntries(db.bags, function(s)
		db.bank.scale = s
		for _, c in pairs(containers) do c.frame:SetScale(s) end
	end)) do
		entries[#entries + 1] = e
	end
	UI.Menu(anchor, entries)
end

local function moneyTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	GameTooltip:AddLine("Gold", 1, 0.82, 0)
	local total = 0
	local keys = {}
	for key in pairs(ns.db.chars) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local c = ns.db.chars[key]
		local money = c.money or 0
		total = total + money
		GameTooltip:AddDoubleLine(c.name or key, ACore.Money(money), 0.9, 0.9, 0.92, 1, 1, 1)
	end
	if #keys > 1 then GameTooltip:AddDoubleLine("Total", ACore.Money(total), 0.58, 0.6, 0.65, 1, 1, 1) end
	if AAuction and AAuction.GetPrice then
		local value = 0
		for _, e in ipairs(ns.Scan("bags")) do
			if e.id then
				local ok, market = pcall(AAuction.GetPrice, e.id)
				if ok and type(market) == "number" then value = value + market * (e.count or 1) end
			end
		end
		if value > 0 then GameTooltip:AddDoubleLine("Auction value of bags", ACore.Money(value), 0.58, 0.6, 0.65, 1, 1, 1) end
	end
	GameTooltip:Show()
end

local function bagButton(c, bag)
	local b = CreateFrame("Button", nil, c.content)
	b:SetSize(30, 30)
	UI.Fill(b, { 0.03, 0.03, 0.04, 0.9 })
	UI.Border(b)
	b.iconTex = b:CreateTexture(nil, "ARTWORK")
	b.iconTex:SetPoint("TOPLEFT", 1, -1)
	b.iconTex:SetPoint("BOTTOMRIGHT", -1, 1)
	b.iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.text = UI.Text(b, "GameFontHighlightSmall", "RIGHT")
	b.text:SetPoint("BOTTOMRIGHT", -1, 1)
	b.bag = bag
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	local function inv() return ns.C.InventoryID(bag) end
	b:SetScript("OnClick", function()
		local id = inv()
		if not id then return end
		if CursorHasItem and CursorHasItem() and PutItemInBag then
			PutItemInBag(id)
		elseif PickupInventoryItem then
			PickupInventoryItem(id)
		end
	end)
	b:SetScript("OnDragStart", function()
		local id = inv()
		if id and PickupInventoryItem then PickupInventoryItem(id) end
	end)
	b:SetScript("OnReceiveDrag", function()
		local id = inv()
		if id and PutItemInBag then PutItemInBag(id) end
	end)
	b:SetScript("OnEnter", function(self)
		local id = inv()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if not id or not GameTooltip:SetInventoryItem("player", id) then
			GameTooltip:AddLine("Empty bag slot", 0.9, 0.9, 0.92)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local function Container(kind, name, title, db)
	local c = { kind = kind, buttons = {}, bagFrames = {}, headers = {}, bagButtons = {}, slotCount = -1 }
	local frame = UI.Window(name, title, 420, 300, db)
	frame:SetFrameStrata("MEDIUM")
	c.frame = frame
	c.content = CreateFrame("Frame", nil, frame.body)
	c.content:SetAllPoints(frame.body)

	local optionsButton = UI.Button(frame.bar, "Options", function(self) options(self) end)
	optionsButton:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
	local sortButton = UI.Button(frame.bar, "Sort", function() ns.Sort(kind) end)
	sortButton:SetPoint("RIGHT", optionsButton, "LEFT", -6, 0)
	c.sortButton = sortButton
	local last = sortButton
	if kind == "bags" then
		local view = UI.Button(frame.bar, "Categories", function()
			ns.db.categories = not ns.db.categories
			ns:Fire("LAYOUT")
		end)
		view:SetPoint("RIGHT", last, "LEFT", -6, 0)
		c.viewButton = view
		local chars = UI.Button(frame.bar, "Characters", function(self) ns.View.Menu(self) end)
		chars:SetPoint("RIGHT", view, "LEFT", -6, 0)
		c.charsButton = chars
		last = chars
		local search = UI.EditBox(frame.bar, "Search", function(text)
			ns.query = text:gsub("^%s+", ""):gsub("%s+$", "")
			ns:Fire("SEARCH")
		end)
		search:SetPoint("LEFT", frame.title, "RIGHT", 10, 0)
		search:SetPoint("RIGHT", last, "LEFT", -8, 0)
		c.search = search
	else
		local buy = UI.Button(frame.bar, "Buy slot", function()
			if not PurchaseSlot then return end
			local cost = GetBankSlotCost and GetBankSlotCost() or 0
			UI.Confirm("Buy a bank bag slot for " .. ACore.Money(cost) .. "?", function() PurchaseSlot() end)
		end)
		buy:SetPoint("RIGHT", last, "LEFT", -6, 0)
		c.buyButton = buy
	end

	local foot = CreateFrame("Frame", nil, frame)
	foot:SetPoint("BOTTOMLEFT")
	foot:SetPoint("BOTTOMRIGHT")
	foot:SetHeight(24)
	UI.Fill(foot, C.bar)
	local free = UI.Text(foot, "GameFontDisableSmall", "RIGHT", C.dim)
	free:SetPoint("RIGHT", -10, 0)
	c.free = free
	if kind == "bags" then
		local money = CreateFrame("Button", nil, foot)
		money:SetPoint("LEFT", 10, 0)
		money:SetSize(150, 20)
		money.text = UI.Text(money, "GameFontHighlightSmall")
		money.text:SetPoint("LEFT")
		money:SetScript("OnEnter", moneyTooltip)
		money:SetScript("OnLeave", function() GameTooltip:Hide() end)
		c.money = money
		local sell = UI.Button(foot, "Sell junk", function() ns.SellJunk() end)
		sell:SetPoint("LEFT", money, "RIGHT", 6, 0)
		sell:Hide()
		c.sellButton = sell
	end

	local function button(bag, slot)
		local list = c.buttons[bag]
		if not list then
			list = {}
			c.buttons[bag] = list
		end
		local b = list[slot]
		if b then return b end
		local parent = c.bagFrames[bag]
		if not parent then
			parent = CreateFrame("Frame", nil, c.content)
			parent:SetID(bag)
			parent:SetAllPoints(c.content)
			c.bagFrames[bag] = parent
		end
		b = ns.NewItemButton(parent, bag, slot)
		list[slot] = b
		return b
	end

	local function header(i)
		local h = c.headers[i]
		if not h then
			h = UI.Text(c.content, "GameFontNormalSmall", "LEFT", C.dim)
			c.headers[i] = h
		end
		return h
	end

	function c:Footer()
		local text = ns.FreeText(kind)
		self.free:SetText(text)
		if self.money then
			local money = GetMoney and GetMoney() or 0
			if type(money) ~= "number" or ns.IsSecret(money) then money = 0 end
			self.money.text:SetText(ACore.Money(money))
			local atMerchant = MerchantFrame and MerchantFrame:IsShown() and true or false
			self.sellButton:SetShown(atMerchant or ns.atMerchant or false)
		end
		if self.viewButton then self.viewButton:SetActive(ns.db.categories) end
		if self.buyButton then
			local show = false
			if GetNumBankSlots then
				local _, full = GetNumBankSlots()
				show = not full
			end
			self.buyButton:SetShown(show)
		end
	end

	function c:Visuals(entries)
		for _, e in ipairs(entries) do
			local list = self.buttons[e.bag]
			local b = list and list[e.slot]
			if b then
				e.live = true
				if b.shownFree and not e.id then e.freeCount = b.shownFree end
				ns.UpdateButton(b, e)
			end
		end
		self:Footer()
	end

	function c:Layout()
		if ns.InCombat() then
			ns.AfterCombat(kind .. "layout", function()
				if frame:IsShown() then c:Layout() end
			end)
			self:Visuals(ns.Scan(kind))
			return
		end
		local entries = ns.Scan(kind)
		local size = ns.db.size
		local s = size / 37
		local cell = size + 4
		local cols = ns.db.columns
		local width = math.max(cols * cell - 4 + PAD * 2, kind == "bags" and 440 or 300)
		cols = math.floor((width - PAD * 2 + 4) / cell)
		local y = PAD
		local used = {}

		local bar = ns.db.bagbar and ns.BagBarList(kind) or {}
		for i, bag in ipairs(bar) do
			local b = self.bagButtons[i]
			if not b then
				b = bagButton(self, bag)
				self.bagButtons[i] = b
			end
			local inv = ns.C.InventoryID(bag)
			local tex = inv and GetInventoryItemTexture and GetInventoryItemTexture("player", inv)
			b.iconTex:SetTexture(tex)
			b.iconTex:SetShown(tex and true or false)
			local slots = ns.C.Slots(bag)
			b.text:SetText(slots > 0 and (ns.C.Free(bag)) or "")
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD + (i - 1) * 34, -y)
			b:Show()
		end
		for i = #bar + 1, #self.bagButtons do self.bagButtons[i]:Hide() end
		if #bar > 0 then y = y + 38 end

		local col = 0
		local headers = 0
		local function place(e)
			local b = button(e.bag, e.slot)
			if not b then return end
			used[b] = true
			b.shownFree = e.freeCount
			b:SetScale(s)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", self.content, "TOPLEFT", (PAD + col * cell) / s, -y / s)
			b:Show()
			e.live = true
			ns.UpdateButton(b, e)
			col = col + 1
			if col >= cols then
				col = 0
				y = y + cell
			end
		end
		local function section(text)
			if col > 0 then
				col = 0
				y = y + cell
			end
			headers = headers + 1
			local h = header(headers)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, -y - 2)
			h:SetText(text)
			h:Show()
			y = y + 18
		end

		if ns.db.categories and kind == "bags" then
			local groups, empty, emptyOrder = {}, {}, {}
			for _, e in ipairs(entries) do
				if e.id then
					groups[e.category] = groups[e.category] or {}
					table.insert(groups[e.category], e)
				else
					local f = e.bag == KEYRING_CONTAINER and -1 or e.family
					if not empty[f] then
						empty[f] = { first = e, n = 0 }
						emptyOrder[#emptyOrder + 1] = f
					end
					empty[f].n = empty[f].n + 1
				end
			end
			for _, cat in ipairs(ns.CATEGORIES) do
				local list = groups[cat]
				if list then
					table.sort(list, ns.Before)
					section(cat .. "  (" .. #list .. ")")
					for _, e in ipairs(list) do place(e) end
				end
			end
			if #emptyOrder > 0 then
				section("Empty")
				for _, f in ipairs(emptyOrder) do
					local e = empty[f].first
					e.freeCount = empty[f].n
					place(e)
				end
			end
		else
			for _, e in ipairs(entries) do place(e) end
		end
		if col > 0 then y = y + cell end
		for i = headers + 1, #self.headers do self.headers[i]:Hide() end
		for _, list in pairs(self.buttons) do
			for _, b in pairs(list) do
				if not used[b] then
					b:Hide()
					b.item = nil
				end
			end
		end
		self.slotCount = #entries
		frame:SetSize(width, 34 + y + PAD - 4 + 24)
		self:Footer()
	end

	function c:Refresh()
		if not frame:IsShown() then return end
		if ns.InCombat() then
			local entries = ns.Scan(kind)
			self:Visuals(entries)
			if #entries ~= self.slotCount or ns.db.categories then
				ns.AfterCombat(kind .. "layout", function()
					if frame:IsShown() then c:Layout() end
				end)
			end
		else
			self:Layout()
		end
	end

	function c:Show()
		if frame:IsShown() then return end
		if ns.InCombat() and frame.IsProtected and frame:IsProtected() then
			ns.AfterCombat(kind .. "show", function() c:Show() end)
			return
		end
		frame:Show()
	end

	function c:Hide()
		if not frame:IsShown() then return end
		if ns.InCombat() and frame.IsProtected and frame:IsProtected() then
			ns.AfterCombat(kind .. "show", function() c:Hide() end)
			return
		end
		frame:Hide()
	end

	frame:SetScript("OnShow", function()
		c:Layout()
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
	end)
	frame:SetScript("OnHide", function()
		if kind == "bags" then
			for _, e in ipairs(ns.Scan("bags")) do
				if e.id then ns.known[e.id] = true end
			end
			ns.knownReady = true
		end
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end
		ns:Fire("CLOSED", kind)
	end)

	containers[kind] = c
	return c
end

local function get(kind)
	local c = containers[kind]
	if c then return c end
	if kind == "bank" then
		return Container("bank", "ABagBankFrame", "Bank", ns.db.bank)
	end
	return Container("bags", "ABagFrame", "Bags", ns.db.bags)
end

local function api(kind)
	local t = {}
	function t.Show() get(kind):Show() end
	function t.Hide()
		local c = containers[kind]
		if c then c:Hide() end
	end
	function t.IsShown()
		local c = containers[kind]
		return c and c.frame:IsShown() or false
	end
	function t.Toggle()
		if t.IsShown() then t.Hide() else t.Show() end
	end
	function t.Refresh()
		local c = containers[kind]
		if c then c:Refresh() end
	end
	function t.Container() return containers[kind] end
	return t
end

ns.Bags = api("bags")
ns.Bank = api("bank")

function ns.Bags.SetSearch(text)
	local c = get("bags")
	c.search.box:SetText(text or "")
end

local function refreshAll()
	ns.Bags.Refresh()
	ns.Bank.Refresh()
end

local function visuals()
	for kind, c in pairs(containers) do
		if c.frame:IsShown() then c:Visuals(ns.Scan(kind)) end
	end
end

ns.RefreshAll = refreshAll

ns:Listen("LAYOUT", refreshAll)
ns:Listen("SEARCH", visuals)
ns:Listen("SORT_DONE", refreshAll)
ns:Listen("LAYOUT_RESET", function()
	for _, c in pairs(containers) do c.frame:Restore() end
end)

local function changed()
	ns.Debounce("bags", 0.1, function()
		refreshAll()
		ns:Fire("BAGS_CHANGED")
	end)
end

ns:On("BAG_UPDATE", changed)
ns:On("BAG_UPDATE_DELAYED", changed)
ns:On("PLAYERBANKSLOTS_CHANGED", changed)
ns:On("PLAYERBANKBAGSLOTS_CHANGED", changed)
ns:On("BAG_NEW_ITEMS_UPDATED", changed)
ns:On("GET_ITEM_INFO_RECEIVED", function()
	ns.Debounce("info", 0.3, refreshAll)
end)
ns:On("ITEM_LOCK_CHANGED", function() ns.Debounce("lock", 0.05, visuals) end)
ns:On("BAG_UPDATE_COOLDOWN", function() ns.Debounce("cd", 0.1, visuals) end)
ns:On("PLAYER_MONEY", function()
	for _, c in pairs(containers) do c:Footer() end
	ns:Fire("BAGS_CHANGED")
end)

ns:Listen("LOGIN", function()
	for _, e in ipairs(ns.Scan("bags")) do
		if e.id then ns.known[e.id] = true end
	end
	ns.knownReady = true

	local function external(arg)
		return type(arg) == "table" and not ns.db.autoOpen
	end
	ToggleAllBags = function() ns.Bags.Toggle() end
	OpenAllBags = function(arg)
		if external(arg) then return end
		ns.Bags.Show()
	end
	CloseAllBags = function()
		local was = ns.Bags.IsShown()
		ns.Bags.Hide()
		return was
	end
	ToggleBackpack = ToggleAllBags
	OpenBackpack = OpenAllBags
	CloseBackpack = CloseAllBags
	ToggleBag = function() ns.Bags.Toggle() end
	OpenBag = function() ns.Bags.Show() end

	if ns.db.replaceBank and BankFrame and not ns.InCombat() then
		local hidden = CreateFrame("Frame")
		hidden:Hide()
		pcall(BankFrame.UnregisterAllEvents, BankFrame)
		pcall(BankFrame.SetParent, BankFrame, hidden)
	end
end)
