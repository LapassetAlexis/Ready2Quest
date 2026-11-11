-- Ready2Quest : résumé de changement d'équipement (événements regroupés,
-- référence d'avant la 1re pièce, nouvelles tentatives tant que les stats ne
-- sont pas recalculées, UNIT_STATS, ligne de /r2q diag) et stats du portrait
-- au survol quel que soit le cadre du joueur (accroches EllesmereUI/ElvUI,
-- cadres nés tard, repli par sondage, pas de double affichage, ancrage).
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
	local idle = G.Diag():find("aucun changement", 1, true) ~= nil
	G.Equip(5, "item:501")
	local timers = G.Timers()
	Check("[GEAR] trois tentatives programmées ; diag : « aucun changement » puis « en attente »", idle
		and #timers == #NS.GEAR_RETRY and G.Diag():find("en attente", 1, true) ~= nil, G.Diag())
	Mock.world.timers = {}
	timers[1]()   -- 0,3 s : rien n'a encore bougé
	Check("[GEAR] pas d'écart à 0,3 s : rien affiché, la référence n'est pas écrasée", not G.Shown() and G.toasts == 0
		and NS.statBefore.slots[5] == "item:500" and NS.statBefore.armor == 506, tostring(NS.statBefore.slots[5]))
	Mock.world.armor = 600   -- le client a recalculé
	timers[2]()
	Check("[GEAR] écart trouvé à la 2e tentative : résumé affiché, référence avancée", G.Shown() and G.toasts == 1
		and NS.statBefore.armor == 600 and NS.gearPending == nil)
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
	Check("[GEAR] un seul résumé pour la série, comparé à la référence d'avant la 1re pièce (armure + endurance), son icône",
		G.toasts == 1 and NS.gearLast and NS.gearLast.rows == 2 and NS.gearLast.slot == 5, NS.gearLast and NS.gearLast.rows)
end

do
	Say("-- stuff : aucun écart au bout des tentatives")
	G.Reset()
	G.Equip(5, "item:503")
	Mock:RunTimers()
	Check("[GEAR] sans écart : rien affiché, la référence suit l'objet porté, diag « aucun écart après 1,5 s »", G.toasts == 0
		and NS.statBefore.slots[5] == "item:503" and G.Diag():find("aucun écart après 1,5 s", 1, true) ~= nil, G.Diag())
end

do
	Say("-- stuff : UNIT_STATS déclenche une tentative")
	G.Reset()
	G.Equip(5, "item:504")
	Mock:Fire("UNIT_STATS", "target")
	Mock:Fire("UNIT_STATS", "player")
	Check("[GEAR] UNIT_STATS d'une autre unité, ou sans écart : toujours en attente", G.toasts == 0 and NS.gearPending ~= nil)
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
	Check("[GEAR] module coupé : pas de résumé, référence suivie, diag « module désactivé »", G.toasts == 0
		and NS.statBefore.armor == 610 and G.Diag():find("module désactivé", 1, true) ~= nil, G.Diag())
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
_G.issecretvalue = saved.issecret

local savedP = {
	GetMouseFoci = rawget(_G, "GetMouseFoci"),
	GetMouseFocus = rawget(_G, "GetMouseFocus"),
	Ellesmere = rawget(_G, "EllesmereUIUnitFrames_Player"),
	ElvUF = rawget(_G, "ElvUF_Player"),
	show = NS.ShowPortraitStats,
}
local H = { focus = nil, shows = 0 }
_G.GetMouseFoci = function() return { H.focus } end
-- le panneau compte ses affichages (double affichage = scintillement)
NS.ShowPortraitStats = function(self, ...)
	H.shows = H.shows + 1
	return savedP.show(self, ...)
end

function H.Reset()
	ResetWorld()
	H.focus, H.shows = nil, 0
	NS.portraitHover, NS.portraitHoverSource, NS.portraitAnchor = nil, nil, nil
	if NS.portraitFrame then NS.portraitFrame:Hide() end
end
function H.Shown() return NS.portraitFrame ~= nil and NS.portraitFrame:IsShown() == true end
function H.AnchoredTo(frame)
	local point = NS.portraitFrame and NS.portraitFrame.lastPoint
	return point ~= nil and point.relTo == frame
end
-- cadre d'unité façon oUF : attribut sécurisé « unit »
function H.UnitFrame(name, unit, parent)
	local frame = CreateFrame("Button", name, parent)
	frame.attributes = { unit = unit }
	function frame:GetAttribute(key) return self.attributes[key] end
	frame:Show()   -- un cadre d'unité est à l'écran
	return frame
end

do
	Say("-- portrait : cadres d'interface connus")
	H.Reset()
	local found = {}
	for _, name in ipairs(NS.PORTRAIT_FRAMES) do found[name] = true end
	local ellesmere = H.UnitFrame("EllesmereUIUnitFrames_Player", "player")
	_G.EllesmereUIUnitFrames_Player = ellesmere
	Check("[PORT] cadres connus (Blizzard, EllesmereUI, ElvUI, SUF) ; EllesmereUI accroché, pas en double",
		found.PlayerFrame and found.EllesmereUIUnitFrames_Player and found.ElvUF_Player and found.SUFUnitplayer
		and NS:HookPortraitFrames() >= 1 and ellesmere.hooks and type(ellesmere.hooks.OnEnter) == "function"
		and type(ellesmere.hooks.OnLeave) == "function" and NS:HookPortraitFrames() == 0)
	ellesmere.hooks.OnEnter(ellesmere)
	Check("[PORT] survol EllesmereUI : panneau affiché au-dessus du cadre survolé", H.Shown() and H.AnchoredTo(ellesmere))
	ellesmere.hooks.OnLeave(ellesmere)
	Check("[PORT] sortie : panneau masqué", not H.Shown())

	-- position choisie par le joueur : elle prime sur le cadre survolé
	NS:DB().portraitManual = true
	NS:DB().portraitPoint = { point = "CENTER", x = 10, y = 20 }
	ellesmere.hooks.OnEnter(ellesmere)
	Check("[PORT] position manuelle respectée", H.AnchoredTo(UIParent))
	ellesmere.hooks.OnLeave(ellesmere)
	NS:DB().portraitManual = false
end

do
	Say("-- portrait : cadre créé après l'entrée en jeu")
	H.Reset()
	_G.ElvUF_Player = nil
	NS.portraitRetried = nil
	Mock.world.timers = {}
	NS:InitPlayerFrameHooks()
	Check("[PORT] trois nouvelles tentatives programmées", #(Mock.world.timers or {}) == #NS.PORTRAIT_RETRY,
		#(Mock.world.timers or {}))
	local elv = H.UnitFrame("ElvUF_Player", "player")
	_G.ElvUF_Player = elv
	Mock:RunTimers()
	Check("[PORT] ElvUI accroché à retardement", elv.hooks and type(elv.hooks.OnEnter) == "function")
	Check("[PORT] sondeur créé une seule fois", NS.portraitPoller ~= nil and (function()
		local poller = NS.portraitPoller
		NS:InitPlayerFrameHooks()
		return NS.portraitPoller == poller
	end)())
end

do
	Say("-- portrait : repli générique (cadre sous la souris)")
	H.Reset()
	-- un cadre d'addon inconnu : l'unité est sur le parent du bouton survolé
	local custom = H.UnitFrame("MonAddonCadreJoueur", "player")
	local portrait = CreateFrame("Button", nil, custom)
	H.focus = portrait
	local viaParent = NS:PortraitHoveredFrame() == custom
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] sondage : cadre du joueur trouvé via le parent, panneau posé au-dessus", viaParent and H.Shown()
		and NS.portraitHoverSource == "poll" and H.AnchoredTo(custom))
	local shows = H.shows
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] sondage : pas de réaffichage à chaque passe", H.shows == shows, H.shows - shows)
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] sondage : masqué en partant", not H.Shown() and NS.portraitHover == nil)

	-- une cible n'est pas le joueur
	H.focus = H.UnitFrame("MonAddonCadreCible", "target")
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] cadre de la cible : rien", not H.Shown())

	-- champ .unit (cadres sans attribut sécurisé)
	local plain = CreateFrame("Frame", "CadreSimple")
	plain.unit = "player"
	H.focus = plain
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] champ .unit reconnu", H.Shown())
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)

	-- trop loin dans la hiérarchie (plus de trois parents) : ignoré
	local deep = CreateFrame("Frame", nil, CreateFrame("Frame", nil, CreateFrame("Frame", nil,
		CreateFrame("Frame", nil, H.UnitFrame("Profond", "player")))))
	H.focus = deep
	Check("[PORT] au-delà de trois parents : ignoré", NS:PortraitHoveredFrame() == nil)

	-- GetMouseFocus (ancien client) en repli
	_G.GetMouseFoci = nil
	_G.GetMouseFocus = function() return custom end
	Check("[PORT] GetMouseFocus en repli", NS:PortraitHoveredFrame() == custom)
	_G.GetMouseFocus = savedP.GetMouseFocus
	_G.GetMouseFoci = function() return { H.focus } end
end

do
	Say("-- portrait : accroche et sondage ensemble")
	H.Reset()
	local ellesmere = _G.EllesmereUIUnitFrames_Player
	ellesmere.hooks.OnEnter(ellesmere)
	H.focus = ellesmere
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] un seul affichage quand les deux voies le voient", H.shows == 1, H.shows)
	-- la souris est partie, l'OnLeave n'est pas encore arrivé : le sondage
	-- ne masque pas ce que l'accroche a montré
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] le sondage ne masque pas l'affichage de l'accroche", H.Shown())
	ellesmere.hooks.OnLeave(ellesmere)
	Check("[PORT] … l'accroche le masque", not H.Shown())
	-- après un masquage par commande, un nouveau survol réaffiche
	ellesmere.hooks.OnEnter(ellesmere)
	NS:HidePortraitStats()
	ellesmere.hooks.OnEnter(ellesmere)
	Check("[PORT] réaffiché après un masquage externe", H.Shown())
	ellesmere.hooks.OnLeave(ellesmere)

	-- module coupé : le sondage ne fait rien
	NS:DB().showPortraitStats = false
	H.focus = ellesmere
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] module coupé : pas de sondage", not H.Shown() and NS.portraitHover == nil)
	NS:DB().showPortraitStats = true
	H.focus = nil
end

do
	Say("-- portrait : ElvUI")
	H.Reset()
	local elv = H.UnitFrame("ElvUF_Player", "player")
	_G.ElvUF_Player = elv
	NS:HookPortraitFrames()
	-- ElvUI remet ses scripts en reconfigurant ses cadres (SetScript efface
	-- les accroches) : le sondage prend le relais
	elv.hooks = nil
	local health = CreateFrame("StatusBar", nil, elv)
	H.focus = health
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] ElvUI, accroche perdue : le sondage affiche, au-dessus de son cadre", H.Shown() and NS.portraitHover == elv
		and H.AnchoredTo(elv))
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] ElvUI : masqué en partant", not H.Shown())
	-- ElvUI masque le PlayerFrame de Blizzard : on ne s'y ancre pas
	local blizzard = rawget(_G, "PlayerFrame")
	local wasShown = blizzard and blizzard:IsShown()
	if blizzard then blizzard:Hide() end
	-- un seul jeu de cadres à l'écran : celui d'ElvUI
	local ellesmere = rawget(_G, "EllesmereUIUnitFrames_Player")
	local ellesmereShown = ellesmere and ellesmere:IsShown()
	if ellesmere then ellesmere:Hide() end
	NS.portraitAnchor = nil
	Check("[PORT] ElvUI : ancre par défaut = son cadre, pas le PlayerFrame masqué", NS:PortraitAnchorFrame() == elv,
		tostring(NS:PortraitAnchorFrame() and NS:PortraitAnchorFrame():GetName()))
	if blizzard and wasShown then blizzard:Show() end
	if ellesmere and ellesmereShown then ellesmere:Show() end
	_G.ElvUF_Player = savedP.ElvUF
end

_G.GetMouseFoci = savedP.GetMouseFoci
_G.GetMouseFocus = savedP.GetMouseFocus
_G.EllesmereUIUnitFrames_Player = savedP.Ellesmere
_G.ElvUF_Player = savedP.ElvUF
NS.ShowPortraitStats = savedP.show
NS.portraitHover, NS.portraitHoverSource, NS.portraitAnchor = nil, nil, nil
