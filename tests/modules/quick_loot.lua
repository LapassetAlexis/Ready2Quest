-- Ready2Quest : butin rapide (QuickLoot.lua, 1.35.0). Coupé par défaut ; suit
-- le butin automatique du jeu et sa touche ; toutes les cases libres d'un
-- coup, les verrouillées laissées ; un passage par intervalle ; la main
-- laissée à un autre addon de butin rapide ; écoute seulement réglage actif.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local GLOBALS = { "GetNumLootItems", "GetLootSlotInfo", "LootSlot", "GetCVarBool", "C_CVar", "IsModifiedClick",
	"IsAddOnLoaded", "C_AddOns", "LeaPlusDB" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local W
_G.C_CVar, _G.C_AddOns = nil, nil
_G.GetNumLootItems = function() return #W.slots end
_G.GetLootSlotInfo = function(i) local s = W.slots[i]; return "icon", s.name, 1, nil, 1, s.locked end
_G.LootSlot = function(i) W.taken[#W.taken + 1] = i end
_G.GetCVarBool = function(name) return name == "autoLootDefault" and W.auto end
_G.IsModifiedClick = function(action) return action == "AUTOLOOTTOGGLE" and W.key == true end
_G.IsAddOnLoaded = function(name) return W.addons[name] == true end
local function Reset()
	ResetWorld()
	W = { auto = true, taken = {}, addons = {}, slots = { { name = "Peau" }, { name = "Lié", locked = true }, { name = "Croc" } } }
	_G.LeaPlusDB = nil
	NS.quickLootAt, NS.quickLootRivalSaid = nil, nil
	NS:QuickLootEvents()
end

do
	Say("-- butin rapide")
	Reset()
	Check("[QLT] coupé par défaut : pas d'écoute, le butin prêt ne ramasse rien", NS:DB().quickLootEnabled == false
		and not NS:QuickLootListening() and not NS.Listening("LOOT_READY", "quickLoot") and NS:QuickLootRun() == 0 and #W.taken == 0)
	NS:DB().quickLootEnabled = true
	NS:RefreshOptions()
	Check("[QLT] réglage actif : le butin prêt est écouté", NS:QuickLootListening()
		and (NS.Listening("LOOT_READY", "quickLoot") or NS.Listening("LOOT_OPENED", "quickLoot")))
	Mock:Fire(NS.Listening("LOOT_READY", "quickLoot") and "LOOT_READY" or "LOOT_OPENED", true)
	Check("[QLT] butin prêt : toutes les cases libres, de la dernière à la première ; la verrouillée laissée",
		#W.taken == 2 and W.taken[1] == 3 and W.taken[2] == 1, table.concat(W.taken, ","))
	Check("[QLT] deux butins coup sur coup : un seul passage par intervalle", NS:QuickLootRun() == 0 and #W.taken == 2)
	Mock.now = Mock.now + NS.QUICKLOOT_GAP + 0.1
	W.auto = false
	Check("[QLT] butin automatique du jeu coupé : rien", NS:QuickLootRun() == 0 and #W.taken == 2)
	W.key = true
	Check("[QLT] … mais forcé par la touche de butin automatique : ramassé", NS:QuickLootRun() == 2 and #W.taken == 4)
	Mock.now = Mock.now + NS.QUICKLOOT_GAP + 0.1
	W.auto = true
	Check("[QLT] butin automatique actif et touche tenue : rien (comme le jeu)", NS:QuickLootRun() == 0)
	W.key = false
	W.addons.SpeedyAutoLoot = true
	local printed, old = {}, NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end
	local a, b = NS:QuickLootRun(), NS:QuickLootRun()
	Check("[QLT] un autre addon de butin rapide : la main lui est laissée, dit une fois", a == 0 and b == 0 and #W.taken == 4
		and #printed == 1 and printed[1] == NS:F("QUICKLOOT_RIVAL", "SpeedyAutoLoot"))
	W.addons.SpeedyAutoLoot = nil
	W.addons.Leatrix_Plus = true
	_G.LeaPlusDB = { FasterLooting = "Off" }
	Check("[QLT] Leatrix Plus présent mais son butin rapide coupé : Ready2Quest ramasse", NS:QuickLootRun() == 2)
	NS.Print = old
	W.slots = {}
	Mock.now = Mock.now + NS.QUICKLOOT_GAP + 0.1
	Check("[QLT] butin vide : rien, sans erreur", NS:QuickLootRun() == 0)
	NS:DB().quickLootEnabled = false
	NS:RefreshOptions()
	local row
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "lootroom" then for _, r in ipairs(page.rows) do if r.key == "quickLootEnabled" then row = r end end end
	end
	Check("[QLT] réglage coupé : l'écoute est rendue ; le réglage est sur la page Place au butin",
		not NS:QuickLootListening() and not NS.Listening("LOOT_READY", "quickLoot") and row ~= nil)
end

for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
NS.quickLootAt, NS.quickLootRivalSaid = nil, nil
NS:QuickLootEvents()
