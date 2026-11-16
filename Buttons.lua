local _, ns = ...
local UI = ns.UI
local C = UI.colors

local QUALITY = {
	[2] = { 0.12, 1, 0 },
	[3] = { 0, 0.44, 0.87 },
	[4] = { 0.64, 0.21, 0.93 },
	[5] = { 1, 0.5, 0 },
	[6] = { 0.9, 0.8, 0.5 },
	[7] = { 0, 0.8, 1 },
}
ns.QUALITY = QUALITY

local created = 0

local function edges(b)
	local list = {}
	for i = 1, 4 do
		local t = b:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(1, 1, 1, 1)
		list[i] = t
	end
	list[1]:SetPoint("TOPLEFT") list[1]:SetPoint("TOPRIGHT") list[1]:SetHeight(1)
	list[2]:SetPoint("BOTTOMLEFT") list[2]:SetPoint("BOTTOMRIGHT") list[2]:SetHeight(1)
	list[3]:SetPoint("TOPLEFT") list[3]:SetPoint("BOTTOMLEFT") list[3]:SetWidth(1)
	list[4]:SetPoint("TOPRIGHT") list[4]:SetPoint("BOTTOMRIGHT") list[4]:SetWidth(1)
	return list
end

local function decorate(b)
	b.fill = b:CreateTexture(nil, "BACKGROUND")
	b.fill:SetAllPoints(b)
	b.fill:SetColorTexture(0.03, 0.03, 0.04, 0.9)
	b.edges = edges(b)
	b.glow = b:CreateTexture(nil, "OVERLAY")
	b.glow:SetPoint("TOPLEFT", 1, -1)
	b.glow:SetPoint("BOTTOMRIGHT", -1, 1)
	b.glow:SetColorTexture(1, 0.82, 0, 0.18)
	b.glow:Hide()
	b.ilvl = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.ilvl:SetPoint("TOPLEFT", 2, -2)
	b.star = b:CreateTexture(nil, "OVERLAY")
	b.star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
	b.star:SetSize(12, 12)
	b.star:SetPoint("TOPRIGHT", -1, -1)
	b.star:Hide()
	b.coin = b:CreateTexture(nil, "OVERLAY")
	b.coin:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
	b.coin:SetSize(14, 14)
	b.coin:SetPoint("BOTTOMLEFT", 1, 1)
	b.coin:Hide()
end

local function edgeColor(b, r, g, bl, a)
	for i = 1, 4 do b.edges[i]:SetVertexColor(r, g, bl, a or 1) end
end

local function quiet(b, key)
	local t = b[key]
	if type(t) == "table" and t.Hide then
		t:Hide()
		if t.SetAlpha then t:SetAlpha(0) end
	end
end

function ns.NewItemButton(parent, bag, slot)
	created = created + 1
	local name = "ABagItem" .. created
	local ok, b = pcall(CreateFrame, "ItemButton", name, parent, "ContainerFrameItemButtonTemplate")
	if not ok or not b then
		ok, b = pcall(CreateFrame, "Button", name, parent, "ContainerFrameItemButtonTemplate")
	end
	if not ok or not b then return nil end
	b:SetID(slot)
	if b.SetBagID then pcall(b.SetBagID, b, bag) end
	b.bag, b.slot = bag, slot
	local function part(key, suffix)
		local v = b[key]
		if type(v) ~= "table" then v = _G[name .. suffix] end
		if type(v) == "table" then return v end
	end
	b.iconTex = part("icon", "IconTexture")
	if not b.iconTex then
		b.iconTex = b:CreateTexture(nil, "BORDER")
		b.iconTex:SetAllPoints(b)
	end
	if b.iconTex.SetTexCoord then b.iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
	b.countText = part("Count", "Count")
	if not b.countText then
		b.countText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		b.countText:SetPoint("BOTTOMRIGHT", -2, 2)
	end
	b.cd = part("Cooldown", "Cooldown")
	local normal = b.GetNormalTexture and b:GetNormalTexture()
	if normal and normal.SetAlpha then normal:SetAlpha(0) end
	quiet(b, "IconBorder")
	quiet(b, "NewItemTexture")
	quiet(b, "BattlepayItemTexture")
	quiet(b, "JunkIcon")
	quiet(b, "IconQuestTexture")
	decorate(b)
	b:HookScript("OnEnter", function(self)
		if self.item then
			ns.known[self.item.id] = true
			self.glow:Hide()
		end
		if self.bag == (BANK_CONTAINER or -1) and BankButtonIDToInvSlotID and self.item then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(self.slot))
			GameTooltip:Show()
		end
	end)
	return b
end

function ns.NewPlainButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(37, 37)
	b.iconTex = b:CreateTexture(nil, "BORDER")
	b.iconTex:SetAllPoints(b)
	b.iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.countText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.countText:SetPoint("BOTTOMRIGHT", -2, 2)
	b.hl = UI.Fill(b, C.hover, "HIGHLIGHT")
	decorate(b)
	return b
end

function ns.UpdateButton(b, e)
	local item = e.id and e or nil
	b.item = item
	b.hasItem = item and true or nil
	if item then
		b.iconTex:SetTexture(e.icon)
		b.iconTex:Show()
		if b.iconTex.SetDesaturated then b.iconTex:SetDesaturated(e.locked and true or false) end
	else
		b.iconTex:SetTexture(nil)
		b.iconTex:Hide()
	end
	local count = ""
	if e.freeCount then
		count = tostring(e.freeCount)
	elseif item and (e.count or 1) > 1 then
		count = tostring(e.count)
	end
	b.countText:SetText(count)
	b.countText:Show()
	local q = item and QUALITY[e.quality or 1]
	if q then
		edgeColor(b, q[1], q[2], q[3], 1)
	elseif item and e.classID == 12 then
		edgeColor(b, 1, 0.82, 0, 1)
	else
		edgeColor(b, C.line[1], C.line[2], C.line[3], 1)
	end
	if item and ns.db.ilvl and (e.classID == 2 or e.classID == 4) and e.ilvl and e.ilvl > 1 then
		b.ilvl:SetText(e.ilvl)
		if q then b.ilvl:SetTextColor(q[1], q[2], q[3]) else b.ilvl:SetTextColor(1, 1, 1) end
		b.ilvl:Show()
	else
		b.ilvl:Hide()
	end
	b.coin:SetShown(item and e.junk or false)
	b.star:SetShown(item and ns.Wished(e.id) or false)
	b.glow:SetShown(item and e.live and ns.db.glow and ns.knownReady and not ns.known[e.id] or false)
	if b.cd and e.live then
		local start, duration, enable = 0, 0, 0
		if item then start, duration, enable = ns.C.Cooldown(e.bag, e.slot) end
		if CooldownFrame_Set then
			pcall(CooldownFrame_Set, b.cd, start, duration, enable)
		elseif b.cd.SetCooldown then
			pcall(b.cd.SetCooldown, b.cd, start, duration)
		end
	end
	if ns.query ~= "" and not ns.Matches(e, ns.query) then
		b:SetAlpha(0.2)
	else
		b:SetAlpha(1)
	end
end
