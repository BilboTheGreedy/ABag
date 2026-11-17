local ADDON, ns = ...

local defaults = {
	columns = 10,
	size = 37,
	categories = false,
	keyring = false,
	bagbar = false,
	ilvl = true,
	glow = true,
	autoSell = false,
	autoRepair = false,
	autoOpen = true,
	replaceBank = true,
	bags = { scale = 1, default = { "BOTTOMRIGHT", "BOTTOMRIGHT", -90, 130 } },
	bank = { scale = 1, default = { "TOPLEFT", "TOPLEFT", 90, -130 } },
	view = { scale = 1, default = { "CENTER", "CENTER", 0, 60 } },
	chars = {},
}

ACore.New(ADDON, ns, { db = "ABagDB", defaults = defaults, profile = true, shared = { "chars" } })

ns.query = ""
ns.known = {}

function ns.InCombat()
	return InCombatLockdown and InCombatLockdown() and true or false
end

local afterCombat = {}
function ns.AfterCombat(key, fn)
	afterCombat[key] = fn
end

ns:On("PLAYER_REGEN_ENABLED", function()
	local run = afterCombat
	afterCombat = {}
	for _, fn in pairs(run) do fn() end
end)

ACore.Register({
	name = "ABag",
	title = "ABag",
	slash = "/abag",
	desc = "bags and bank",
	toggle = function() ns.Bags.Toggle() end,
	options = function() return ns.Options() end,
})

SLASH_ABAG1 = "/abag"
SLASH_ABAG2 = "/ab"
SlashCmdList["ABAG"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd = msg:lower()
	if cmd == "" then
		ns.Bags.Toggle()
	elseif cmd == "sort" then
		ns.Sort("bags")
	elseif cmd == "junk" then
		ns.SellJunk()
	elseif cmd == "bank" then
		ns.View.Show(ns.CharKey(), "bank")
	elseif cmd == "reset" then
		ns.db.bags.pos, ns.db.bank.pos, ns.db.view.pos = nil, nil, nil
		ns.db.bags.scale, ns.db.bank.scale = 1, 1
		ns:Fire("LAYOUT_RESET")
	else
		ns.Bags.Show()
		ns.Bags.SetSearch(msg)
	end
end

BINDING_HEADER_ABAG = "ABag"
BINDING_NAME_ABAG_TOGGLE = "Toggle bags"
function ABag_ToggleBinding()
	ns.Bags.Toggle()
end
