local _, ns = ...

local opened = {}

local function open(reason)
	if not ns.db.autoOpen then return end
	if not ns.Bags.IsShown() then
		opened[reason] = true
		ns.Bags.Show()
	end
end

local function close(reason)
	if opened[reason] then
		opened[reason] = nil
		if not next(opened) then ns.Bags.Hide() end
	end
end

local function ownerKey(owner)
	local name = type(owner) == "table" and owner.GetName and owner:GetName()
	return "frame:" .. tostring(name or owner)
end

function ns.OwnerOpen(owner)
	open(ownerKey(owner))
end

function ns.OwnerClose(owner)
	close(ownerKey(owner))
end

ns:Listen("CLOSED", function(kind)
	if kind == "bags" then
		opened = {}
	elseif kind == "bank" and ns.atBank then
		ns.atBank = false
		if C_Bank and C_Bank.CloseBankFrame then
			pcall(C_Bank.CloseBankFrame)
		elseif CloseBankFrame then
			pcall(CloseBankFrame)
		end
	end
end)

local selling

function ns.JunkList()
	local out = {}
	for _, e in ipairs(ns.Scan("bags")) do
		if e.junk and not e.locked then
			local keep = false
			if AVendor and AVendor.IsProtected then
				local ok, v = pcall(AVendor.IsProtected, e.id, e.link, e.quality)
				keep = ok and v and true or false
			end
			if not keep then out[#out + 1] = e end
		end
	end
	return out
end

local function sellStep(total, count)
	if not ns.atMerchant then
		selling = nil
		if count > 0 then ns.Print("Sold " .. count .. " junk items for " .. ACore.Money(total)) end
		return
	end
	local list = ns.JunkList()
	if #list == 0 or count >= 200 then
		selling = nil
		if count > 0 then
			ns.Print("Sold " .. count .. " junk items for " .. ACore.Money(total))
		else
			ns.Print("No junk to sell")
		end
		return
	end
	local n = 0
	for _, e in ipairs(list) do
		ns.C.Use(e.bag, e.slot)
		total = total + e.price * (e.count or 1)
		count = count + 1
		n = n + 1
		if n >= 8 then break end
	end
	ns.After(0.3, function() sellStep(total, count) end)
end

function ns.SellJunk()
	if not ns.atMerchant then
		ns.Print("Open a vendor first")
		return
	end
	if selling then return end
	selling = true
	sellStep(0, 0)
end

local function repair()
	if not ns.db.autoRepair or not CanMerchantRepair or not CanMerchantRepair() then return end
	if not GetRepairAllCost or not RepairAllItems then return end
	local cost, can = GetRepairAllCost()
	if ns.IsSecret(cost) or not can or type(cost) ~= "number" or cost <= 0 then return end
	local money = GetMoney and GetMoney() or 0
	if type(money) ~= "number" or ns.IsSecret(money) or money < cost then
		ns.Print("Not enough gold to repair (" .. ACore.Money(cost) .. ")")
		return
	end
	RepairAllItems()
	ns.Print("Repaired for " .. ACore.Money(cost))
end

ns:On("MERCHANT_SHOW", function()
	ns.atMerchant = true
	open("merchant")
	ns.Bags.Refresh()
	repair()
	if ns.db.autoSell and #ns.JunkList() > 0 then ns.SellJunk() end
end)
ns:On("MERCHANT_CLOSED", function()
	ns.atMerchant = false
	close("merchant")
	ns.Bags.Refresh()
end)

ns:On("BANKFRAME_OPENED", function()
	open("bank")
	if not ns.db.replaceBank or not ns.bankStashed then return end
	ns.atBank = true
	ns.Bank.Show()
	ns.Bank.Refresh()
	ns.SaveBank()
end)
ns:On("BANK_TABS_CHANGED", function()
	if ns.atBank then ns.Bank.Refresh() end
end)
ns:On("BANKFRAME_CLOSED", function()
	ns.atBank = false
	ns.Bank.Hide()
	close("bank")
	if ns.StashBank then ns.After(0.5, ns.StashBank) end
end)

ns:On("MAIL_SHOW", function() open("mail") end)
ns:On("MAIL_CLOSED", function() close("mail") end)
ns:On("AUCTION_HOUSE_SHOW", function() open("auction") end)
ns:On("AUCTION_HOUSE_CLOSED", function() close("auction") end)
ns:On("TRADE_SHOW", function() open("trade") end)
ns:On("TRADE_CLOSED", function() close("trade") end)
