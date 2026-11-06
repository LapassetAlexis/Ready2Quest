-- Résumé de changement d'équipement : événements regroupés, référence
-- d'avant la première pièce, nouvelles tentatives tant que les stats ne sont
-- pas recalculées, UNIT_STATS, ligne de /r2q diag.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local saved = { toast = NS.ShowGearToast, issecret = rawget(_G, "issecretvalue") }
local G = { toasts = 0 }
NS.ShowGearToast = function(self, ...)
	G.toasts = G.toasts + 1
	return saved.toast(self, ...)
end

function G.Reset()
	ResetWorld()
	G.toasts = 0
	NS.gearPending, NS.gearLast = nil, nil
	Mock.world.timers = {}
	Mock.world.equipped[5] = "item:500"
	Mock.world.links["item:500"] = { name = "Plastron", quality = 2, itemLevel = 20, equipLoc = "INVTYPE_CHEST" }
	NS:CaptureStatBaseline()
end
-- un objet change dans l'emplacement ; les stats, elles, suivent plus tard
function G.Equip(slot, link)
	Mock.world.equipped[slot] = link
	Mock.world.links[link] = { name = "Neuf " .. link, quality = 3, itemLevel = 24, equipLoc = "INVTYPE_CHEST" }
	Mock:Fire("PLAYER_EQUIPMENT_CHANGED", slot, true)
end
-- joue la tentative n (timers en attente, dans l'ordre)
function G.Timers() return Mock.world.timers or {} end
function G.Shown() return NS.toastFrame ~= nil and NS.toastFrame:IsShown() == true end
function G.Diag() return NS:GearDiagLine() end

do
	Say("-- stuff : stats recalculées en retard")
	G.Reset()
	Check("[GEAR] diag : aucun changement", G.Diag():find("aucun changement", 1, true) ~= nil, G.Diag())
	G.Equip(5, "item:501")
	local timers = G.Timers()
	Check("[GEAR] trois tentatives programmées", #timers == #NS.GEAR_RETRY, #timers)
	Check("[GEAR] diag : en attente", G.Diag():find("en attente", 1, true) ~= nil, G.Diag())
	Mock.world.timers = {}
	timers[1]()   -- 0,3 s : rien n'a encore bougé
	Check("[GEAR] pas d'écart à 0,3 s : rien affiché", not G.Shown() and G.toasts == 0)
	Check("[GEAR] la référence n'est pas écrasée", NS.statBefore.slots[5] == "item:500" and NS.statBefore.armor == 506,
		tostring(NS.statBefore.slots[5]))
	Mock.world.armor = 600   -- le client a recalculé
	timers[2]()
	Check("[GEAR] écart trouvé à la 2e tentative : résumé affiché", G.Shown() and G.toasts == 1)
	Check("[GEAR] référence avancée après l'écart", NS.statBefore.armor == 600 and NS.gearPending == nil)
	timers[3]()
	Check("[GEAR] la dernière tentative ne refait rien", G.toasts == 1)
	Check("[GEAR] diag : emplacement 5, écarts, affiché", G.Diag():find("emplacement 5", 1, true) ~= nil
		and G.Diag():find("1 écart", 1, true) ~= nil and G.Diag():find("résumé affiché", 1, true) ~= nil, G.Diag())
end

do
	Say("-- stuff : plusieurs pièces d'un coup")
	G.Reset()
	G.Equip(5, "item:502")
	Mock.world.armor = 560
	G.Equip(7, "item:702")      -- deuxième pièce avant la première tentative
	Mock.world.stats[3] = 40     -- Endurance
	Check("[GEAR] emplacements regroupés", NS.gearPending and #NS.gearPending.slots == 2)
	Mock:RunTimers()
	Check("[GEAR] un seul résumé pour la série", G.toasts == 1, G.toasts)
	Check("[GEAR] comparé à la référence d'avant la 1re pièce (armure + endurance)",
		NS.gearLast and NS.gearLast.rows == 2, NS.gearLast and NS.gearLast.rows)
	Check("[GEAR] l'icône vient de la 1re pièce de la série", NS.gearLast and NS.gearLast.slot == 5)
end

do
	Say("-- stuff : aucun écart au bout des tentatives")
	G.Reset()
	G.Equip(5, "item:503")
	Mock:RunTimers()
	Check("[GEAR] rien affiché sans écart", G.toasts == 0)
	Check("[GEAR] la référence suit l'objet porté", NS.statBefore.slots[5] == "item:503")
	Check("[GEAR] diag : aucun écart après 1,5 s", G.Diag():find("aucun écart après 1,5 s", 1, true) ~= nil, G.Diag())
end

do
	Say("-- stuff : UNIT_STATS déclenche une tentative")
	G.Reset()
	G.Equip(5, "item:504")
	Mock:Fire("UNIT_STATS", "target")
	Check("[GEAR] UNIT_STATS d'une autre unité : ignoré", G.toasts == 0 and NS.gearPending ~= nil)
	Mock:Fire("UNIT_STATS", "player")
	Check("[GEAR] UNIT_STATS sans écart : toujours en attente", G.toasts == 0 and NS.gearPending ~= nil)
	Mock.world.armor = 650
	Mock:Fire("UNIT_STATS", "player")
	Check("[GEAR] UNIT_STATS avec écart : résumé tout de suite", G.toasts == 1 and NS.gearPending == nil)
	Mock:RunTimers()
	Check("[GEAR] les tentatives restantes ne doublent pas le résumé", G.toasts == 1)
	-- hors série en cours : UNIT_STATS ne fait rien
	Mock.world.armor = 700
	Mock:Fire("UNIT_STATS", "player")
	Check("[GEAR] UNIT_STATS hors série : ignoré", G.toasts == 1)
end

do
	Say("-- stuff : module désactivé, valeurs secrètes, diag")
	G.Reset()
	NS:DB().showGearToast = false
	G.Equip(5, "item:505")
	Mock.world.armor = 610
	Mock:RunTimers()
	Check("[GEAR] module coupé : pas de résumé", G.toasts == 0 and NS.statBefore.armor == 610)
	Check("[GEAR] diag : module désactivé", G.Diag():find("module désactivé", 1, true) ~= nil, G.Diag())
	NS:DB().showGearToast = true

	-- valeurs secrètes : comptées comme absentes, sans erreur
	local SECRET = {}
	_G.issecretvalue = function(value) return value == SECRET end
	local savedArmor = _G.UnitArmor
	_G.UnitArmor = function() return SECRET, SECRET end
	local ok, snap = pcall(NS.StatSnapshot, NS)
	Check("[GEAR] armure secrète : relevé sans erreur, armure 0", ok and snap.armor == 0, ok and snap.armor or snap)
	_G.UnitArmor = savedArmor
	_G.issecretvalue = saved.issecret

	-- la ligne apparaît dans /r2q diag
	Mock:Reset()
	NS:HandleCommand("diag")
	Check("[GEAR] /r2q diag dit le dernier changement", Mock:Output():find("équipement :", 1, true) ~= nil)

	-- appel direct (sans série) : tentative unique, comportement historique
	G.Reset()
	Mock.world.equipped[5] = "item:506"
	Mock.world.armor = 620
	Check("[GEAR] appel direct : résumé immédiat", NS:OnEquipmentChanged() == "shown" and G.toasts == 1)
end

NS.ShowGearToast = saved.toast
NS.gearPending, NS.gearLast = nil, nil
