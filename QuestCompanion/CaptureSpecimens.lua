-- CaptureSpecimens.lua -- spécimens, Codex, Réserve, paillettes, mode chasse (QuestCompanion 2.15.0)
--
-- 2.15.0 : refonte de la capture (retour des joueurs : 3 étoiles trop
-- faciles avec les recaptures sans fin, filet qui revenait sans cesse).
--   * chaque capture réussie crée un SPÉCIMEN unique (espèce, qualité 1 à 3
--     étoiles, brillant ou non, zone, date, dresseur) ;
--   * la qualité est tirée AU COUP FATAL, selon le rang du monstre
--     (CAPTURE_QUALITY_ODDS), et rend la capture plus dure (CAPTURE_QUALITY_FACTOR) ;
--   * le CODEX garde, par espèce et par version (normale, brillante), le
--     spécimen de référence ; les autres vont dans la RÉSERVE (20 places au
--     départ, + places achetées plus tard) ; relâcher un spécimen de la
--     Réserve rend des PAILLETTES (1 / 3 / 8 / 20) ;
--   * le filet ne vient plus que si ça vaut le coup (CaptureQueue.lua,
--     CaptureQueueReason) : espèce nouvelle, brillante, spécimen meilleur que
--     le tien, espèce épinglée (liste de chasse), ou MODE CHASSE ;
--   * mode chasse : chaque monstre abattu est proposé, pendant 5/15/30/60 min
--     ou jusqu'à l'arrêt ; MÉFIANCE (en chasse seulement) : −15 % de chance par
--     capture de la même espèce dans la journée (jamais sous ×0,4).
-- La vue par espèce d'avant (capture.creatures[npc] : normal, shiny, stars,
-- shinyStars, at, shinyAt…) reste la source de tous les lecteurs actuels
-- (Ménagerie, hauts faits, apparences « cap:<npc>[:s] », fiche de dresseur,
-- infobulles) : elle est tenue à jour ici comme un RÉSUMÉ des spécimens
-- (stars = meilleure qualité possédée de cette version).
--
-- ===========================================================================
-- API (2.15.0) — pour les pages Codex / Réserve / boutique / carte de capture
-- ===========================================================================
-- Données (au compte, QuestCompanionDB.capture, voir ns:CaptureData) :
--   capture.specimens[id] = { id, npc, stars (1..3), shiny (true|nil), zone
--       (uiMapID|nil), at (time()|nil), by (nom du personnage|nil),
--       origin ("capture"|"migration"|"gift3"|"trade"), name (texte|nil),
--       3.0.0 échanges : tradedFrom (dernier donneur), tradedAt, firstOrigin
--       (origine d'avant le premier échange), hops (échanges subis),
--       trait (caractère, ns.PERSONALITY_TRAITS), size ("tiny"|"small"|
--       "normal"|"large"|"giant") } -- 3.1.0 : SpecimenTraits.lua
--   capture.codex[npc]    = { best = id (normale), bestShiny = id (brillante) }
--   capture.specNext      = prochain numéro de spécimen
--   capture.specV         = version du schéma (ns.SPECIMEN_SCHEMA)
--   capture.traitV        = 3.1.0 : caractères et tailles posés (ns.SPECIMEN_TRAIT_SCHEMA)
--   capture.paillettes    = solde ; capture.paillettesEarned = total gagné
--   capture.reserveBonus  = places de Réserve en plus (boutique, plus tard)
--   capture.pins[npc]     = true (liste de chasse, au compte)
--   capture.caught        = captures réussies (spécimens, migration comprise)
--   capture.wary          = { day = clé du jour, n = { [npc] = captures du jour } }
--   réglages (ns:DB()) : captureHuntOn (bool), captureHuntUntil (time()|nil)
--
-- Spécimens
--   ns:SpecimenAdd(spec) -> id, place ("codex"|"reserve"), oldRefId|nil
--       spec = { npc, stars, shiny, zone, at, by, origin, name, trait, size } ;
--       3.1.0 : caractère et taille tirés s'ils manquent (taille normale
--       hors capture) ; un
--       spécimen meilleur que tout ce que tu as de cette version devient la
--       référence du Codex (l'ancienne passe en Réserve). Ne vérifie PAS la
--       place : ns:CaptureBlockedReason le fait avant le lancer.
--       3.0.0 : spec.keepReserve (échanges, CaptureTrades.lua) : jamais promu
--       au Codex s'il y a déjà une référence de cette version.
--   ns:SpecimenGet(id) -> spec|nil
--   ns:CaptureCaughtCount() -> captures réussies (spécimens ; capture.count = espèces)
--   ns:SpecimenList(filter) -> { spec, … } (table neuve, triée)
--       filter = { where = "all"|"reserve"|"codex", npc = n, shiny = bool,
--       stars = n (au moins), sort = "stars"|"date"|"name"|"id" } (tout optionnel)
--   ns:SpecimenReserve() -> la Réserve (SpecimenList{ where = "reserve" })
--   ns:SpecimenReserveCount() -> n (sans table neuve)
--   ns:SpecimenIsReference(id) -> bool
--   ns:SpecimenReference(npc, shiny) -> spec|nil (référence du Codex)
--   ns:SpecimenBetterThanCodex(id) -> bool (spécimen de Réserve meilleur que la référence)
--   ns:SpecimenSetReference(id) -> true | false, raison ("missing"|"already")
--       « Mettre au Codex » : il devient la référence, l'ancienne va en Réserve
--   ns:SpecimenWorn(id) -> bool (référence portée comme apparence par un personnage)
--   ns:SpecimenReleaseValue(id|spec) -> paillettes rendues (1/3/8, brillant 20)
--   ns:SpecimenCanRelease(id) -> true | false, raison ("missing"|"reference"|"worn"|"better")
--       2.15.0 : "better" = meilleur que la référence du Codex (relâcher ne
--       fait jamais baisser tes étoiles : « Mets-le au Codex avant »)
--   ns:SpecimenRelease(id) -> gain | false, raison (mêmes raisons)
--   ns:SpecimenTake(id) -> spec | nil (3.0.0 : part sans paillettes, échange)
--   ns:SpecimenLabel(spec) -> nom (avec « (brillant) »)
-- Réserve
--   ns:ReserveCapacity() -> CAPTURE_RESERVE_BASE + bonus
--   ns:ReserveFull() -> bool
--   ns:ReserveAddSlots(n) -> nouvelle capacité
-- Paillettes
--   ns:Paillettes() -> solde
--   ns:PaillettesAdd(n, reason) -> solde
--   ns:PaillettesSpend(n, reason) -> true, solde | false, "short"
-- Qualité et chance
--   ns.CAPTURE_QUALITY_ODDS[group] = { %1★, %2★, %3★ } ; group par
--       ns.CAPTURE_QUALITY_GROUP[class] ("normal"|"elite"|"rare")
--   ns:CaptureRollQuality(class) -> 1..3 (tiré au coup fatal : candidate.stars)
--   ns.CAPTURE_QUALITY_FACTOR[stars] : facteur de chance (1 / 0,8 / 0,6) ;
--       ns:CaptureChance(info) lit info.stars (et info.npcID pour la méfiance)
--   ns:CaptureBlockedReason(candidate) -> nil | "reserveFull"
-- Liste de chasse et mode chasse
--   ns:HuntPin(npc, on) -> bool (épinglée ?) ; ns:HuntPinned(npc) -> bool
--   ns:HuntPins() -> { npc, … } (table neuve, triée)
--   ns:HuntStart(minutes|nil) (nil ou 0 : jusqu'à l'arrêt) -> true
--   ns:HuntStop() -> true si elle tournait ; ns:HuntToggle()
--   ns:HuntActive() -> bool
--   ns:HuntRemaining() -> secondes (chasse minutée), -1 (jusqu'à l'arrêt), nil (inactive)
--   ns:HuntText() -> « 12 min », « jusqu'à l'arrêt », ou nil
--   ns.HUNT_CHOICES = { 5, 15, 30, 60 } (+ « jusqu'à ce que je l'arrête » : nil)
--   ns:CaptureWariness(npc) -> facteur (1 hors chasse), captures du jour
-- 3.0.0 : migration et cadeau de bienvenue
--   ns:SpecimenMigratedCounts() -> espèces, spécimens, brillants (origin "migration")
--   ns.GIFT30 = { max = 3, minSpecies = 4, origin = "gift3" }
--   ns:Gift30Available() -> bool (plus de 3 espèces migrées, pas encore utilisé)
--   ns:Gift30Candidates() -> { { npc, stars, name, zone, shinyOnly }, … } (Codex)
--   ns:Gift30Grant(npcs) -> { ids } | false, "used"|"count"|"missing"|"full"
--       copies normales en Réserve, étoiles de la référence ; capture.gift30Used
-- Événements (ns:RegisterCallback) : "SPECIMENS" (quoi, id), "PAILLETTES"
-- (solde, delta, raison), "HUNT" (actif).
-- Commande : /qc chasse [5|15|30|60|on|stop] (alias /qc hunt) ; raccourci
-- « Mode chasse » (Bindings.lua).
-- ===========================================================================
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.SPECIMEN_SCHEMA = 1
ns.CAPTURE_RESERVE_BASE = 20
-- qualité tirée au coup fatal (en %), selon le rang du monstre
ns.CAPTURE_QUALITY_ODDS = {
	normal = { 65, 28, 7 },
	elite  = { 50, 35, 15 },
	rare   = { 30, 45, 25 },
}
ns.CAPTURE_QUALITY_GROUP = { trivial = "normal", minus = "normal", normal = "normal", elite = "elite",
	rare = "rare", rareelite = "rare", worldboss = "rare" }
-- chance de capture : un beau spécimen se débat plus
ns.CAPTURE_QUALITY_FACTOR = { 1, 0.8, 0.6 }
-- (guide, tutoriel : les chances d'un monstre ordinaire, comme avant 2.15)
ns.CAPTURE_STAR_ODDS = ns.CAPTURE_QUALITY_ODDS.normal
-- relâcher : paillettes par étoiles (un brillant vaut toujours `shiny`)
ns.PAILLETTES_RELEASE = { 1, 3, 8, shiny = 20 }
-- mode chasse : durées proposées (minutes), comme la sourdine
ns.HUNT_CHOICES = { 5, 15, 30, 60 }
-- méfiance : −15 % par capture de la même espèce dans la journée, plancher ×0,4
ns.CAPTURE_WARINESS = { step = 0.15, floor = 0.4 }

local FR = {
	HUNT_MSG_START_FOR   = "Mode chasse pendant %s : chaque monstre abattu est proposé au filet. Méfiance : chaque capture d'une même espèce aujourd'hui rend la suivante plus dure.",
	HUNT_MSG_START_ON    = "Mode chasse jusqu'à ce que tu l'arrêtes (/qc chasse stop) : chaque monstre abattu est proposé au filet. Méfiance : chaque capture d'une même espèce aujourd'hui rend la suivante plus dure.",
	HUNT_MSG_STOP        = "Mode chasse arrêté : le filet ne propose plus que ce qui vaut le coup.",
	HUNT_MSG_END         = "Fin du mode chasse : le filet ne propose plus que ce qui vaut le coup.",
	HUNT_MSG_STATUS      = "Mode chasse : encore %s.",
	HUNT_MSG_STATUS_ON   = "Mode chasse : actif jusqu'à ce que tu l'arrêtes.",
	HUNT_UNTIL_STOP      = "Jusqu'à ce que je l'arrête",
	HUNT_TEXT_ON         = "jusqu'à l'arrêt",
	HUNT_TITLE           = "Mode chasse",
	HUNT_PINNED          = "%s est épinglée : toujours proposée au filet.",
	HUNT_UNPINNED        = "%s n'est plus épinglée.",
	HELP_HUNT            = "/qc chasse [5|15|30|60|on|stop] -- mode chasse : chaque monstre abattu au filet",
	CAPTURE_Q_REASON_pinned = "Espèce épinglée",
	CAPTURE_Q_REASON_hunt   = "Mode chasse",
	CAPTURE_WARY         = "Méfiant · %d capture(s) aujourd'hui (−%d %%)",
	CAPTURE_MSG_RESERVE_FULL = "Réserve pleine (%d/%d) : relâche un spécimen ou agrandis-la avant de capturer %s.",
	CAPTURE_MSG_TO_RESERVE   = "%s rejoint ta Réserve (%d/%d).",
	SPECIMEN_RELEASED    = "%s relâché : +%d paillettes (%d en tout).",
	SPECIMEN_TO_CODEX    = "%s entre au Codex ; l'ancien passe en Réserve.",
	SPECIMEN_ERR_missing   = "Ce spécimen n'existe plus.",
	SPECIMEN_ERR_reference = "C'est ton spécimen du Codex : mets-en un autre au Codex avant de le relâcher.",
	SPECIMEN_ERR_worn      = "Ton compagnon porte cette apparence : change d'apparence avant de le relâcher.",
	SPECIMEN_ERR_already   = "Il est déjà au Codex.",
	SPECIMEN_ERR_better    = "Il est meilleur que ton spécimen du Codex : mets-le au Codex avant de le relâcher.",
	PAILLETTES_NAME      = "paillettes",
}
local EN = {
	HUNT_MSG_START_FOR   = "Hunt mode for %s: every monster you defeat is offered in the net. Wariness: each capture of the same species today makes the next one harder.",
	HUNT_MSG_START_ON    = "Hunt mode until you stop it (/qc hunt stop): every monster you defeat is offered in the net. Wariness: each capture of the same species today makes the next one harder.",
	HUNT_MSG_STOP        = "Hunt mode stopped: the net only offers what's worth it again.",
	HUNT_MSG_END         = "Hunt mode is over: the net only offers what's worth it again.",
	HUNT_MSG_STATUS      = "Hunt mode: %s left.",
	HUNT_MSG_STATUS_ON   = "Hunt mode: on until you stop it.",
	HUNT_UNTIL_STOP      = "Until I stop it",
	HUNT_TEXT_ON         = "until stopped",
	HUNT_TITLE           = "Hunt mode",
	HUNT_PINNED          = "%s is pinned: always offered in the net.",
	HUNT_UNPINNED        = "%s is no longer pinned.",
	HELP_HUNT            = "/qc hunt [5|15|30|60|on|stop] -- hunt mode: every defeated monster in the net",
	CAPTURE_Q_REASON_pinned = "Pinned species",
	CAPTURE_Q_REASON_hunt   = "Hunt mode",
	CAPTURE_WARY         = "Wary · %d capture(s) today (−%d%%)",
	CAPTURE_MSG_RESERVE_FULL = "Reserve full (%d/%d): release a specimen or expand it before capturing %s.",
	CAPTURE_MSG_TO_RESERVE   = "%s joins your Reserve (%d/%d).",
	SPECIMEN_RELEASED    = "%s released: +%d glitter (%d in total).",
	SPECIMEN_TO_CODEX    = "%s enters the Codex; the old one goes to the Reserve.",
	SPECIMEN_ERR_missing   = "This specimen no longer exists.",
	SPECIMEN_ERR_reference = "This is your Codex specimen: put another one in the Codex before releasing it.",
	SPECIMEN_ERR_worn      = "Your companion wears this look: change looks before releasing it.",
	SPECIMEN_ERR_already   = "It's already in the Codex.",
	SPECIMEN_ERR_better    = "It beats your Codex specimen: put it in the Codex before releasing it.",
	PAILLETTES_NAME      = "glitter",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_SPECIMEN_STRINGS = { fr = FR, en = EN } end

-- Répliques au coup fatal : un 3 étoiles ou un brillant ne passe pas inaperçu
local P = {
	CAPTURE_GREAT = {   -- %s = la créature
		{ "Oh, celui-là est magnifique ! Trois étoiles !", "Oh, that one's magnificent! Three stars!" },
		{ "Regarde-moi ce %s : trois étoiles, une merveille !", "Look at that %s: three stars, a marvel!" },
		{ "Un %s parfait ! Celui-là, on ne le laisse pas filer.", "A perfect %s! We're not letting that one go." },
		{ "Trois étoiles… %s ferait des jaloux au campement.", "Three stars… %s would make the whole camp jealous." },
	},
	CAPTURE_GREAT_SHINY = {   -- %s = la créature
		{ "Il BRILLE ! %s, vite, le filet !", "It's SHINING! %s, quick, the net!" },
		{ "%s… je n'en crois pas mes yeux. Ne le rate pas !", "%s… I can't believe my eyes. Don't miss it!" },
		{ "Ça scintille ! %s, c'est pour nous.", "It sparkles! %s is ours." },
	},
}
local POOLS = ns.RegisterCompanionLines(P)
ns.CAPTURE_SPECIMEN_POOLS = POOLS

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end
-- temps réel (gardé d'une session à l'autre : chasse, dates des spécimens)
local function RealTime()
	local fn = G("time")
	return type(fn) == "function" and tonumber(fn()) or Clock()
end
local function Key(npc) return tonumber(npc) or npc end
local function Clamp(stars)
	stars = math.floor(tonumber(stars) or 1)
	if stars < 1 then return 1 end
	if stars > 3 then return 3 end
	return stars
end
local function Fire(event, ...)
	if ns.FireCallback then ns:FireCallback(event, ...) end
end

-- ---------------------------------------------------------------------------
-- Données et migration
-- ---------------------------------------------------------------------------
-- Le meilleur spécimen de cette version (sauf `except`), ou nil
local function BestOf(capture, npc, shiny, except)
	local best
	for id, spec in pairs(capture.specimens) do
		if id ~= except and spec.npc == npc and (spec.shiny == true) == shiny then
			if not best or spec.stars > best.stars or (spec.stars == best.stars and spec.id < best.id) then best = spec end
		end
	end
	return best
end

local function NewId(capture)
	local id = math.max(1, math.floor(tonumber(capture.specNext) or 1))
	while capture.specimens[id] do id = id + 1 end
	capture.specNext = id + 1
	return id
end

local function Touch(capture)
	capture.specSerial = (tonumber(capture.specSerial) or 0) + 1
end

-- Chaque version possédée d'après la vue par espèce a sa référence au Codex :
-- un spécimen de Réserve s'il y en a (le meilleur), sinon un spécimen
-- « migration » fait de la fiche (étoiles, date). Rend le nombre créé.
local function Reconcile(capture, npc, entry)
	if type(entry) ~= "table" then return 0 end
	local made = 0
	for pass = 1, 2 do
		local shiny = pass == 2
		local owned
		if shiny then owned = entry.shiny == true else owned = entry.normal ~= false end
		if owned then
			local codex = capture.codex[npc]
			local field = shiny and "bestShiny" or "best"
			local ref = codex and codex[field] and capture.specimens[codex[field]]
			if not (ref and ref.npc == npc and (ref.shiny == true) == shiny) then
				local best = BestOf(capture, npc, shiny)
				if not best then
					local id = NewId(capture)
					best = { id = id, npc = npc, stars = Clamp(shiny and entry.shinyStars or entry.stars), shiny = shiny or nil,
						zone = tonumber(entry.zoneID), at = tonumber(shiny and (entry.shinyAt or entry.at) or entry.at),
						origin = "migration", name = entry.name }
					capture.specimens[id] = best
					made = made + 1
				end
				codex = codex or {}
				capture.codex[npc] = codex
				codex[field] = best.id
				-- 3.1.0 : son caractère (celui du compagnon s'il est porté) au prochain Store
				capture.traitDirty = true
			end
		end
	end
	return made
end

-- Tout le Codex d'après la vue par espèce (migration, ou collection d'un
-- personnage versée au compte). Idempotent.
local function ReconcileAll(capture)
	local made = 0
	for npcID, entry in pairs(capture.creatures) do
		made = made + Reconcile(capture, Key(npcID), entry)
	end
	capture.caught = math.max(0, math.floor(tonumber(capture.caught) or 0)) + made
	capture.specV = ns.SPECIMEN_SCHEMA
	capture.specDirty = nil
	if made > 0 then Touch(capture) end
	return made
end

-- La table de capture du compte, prête pour les spécimens (migration faite)
local function Store(self)
	local capture = self:CaptureData()
	if type(capture.specimens) ~= "table" then capture.specimens = {} end
	if type(capture.codex) ~= "table" then capture.codex = {} end
	if type(capture.pins) ~= "table" then capture.pins = {} end
	if capture.specV ~= ns.SPECIMEN_SCHEMA or capture.specDirty then ReconcileAll(capture) end
	-- 3.1.0 : caractère et taille de chaque spécimen (SpecimenTraits.lua)
	if (capture.traitV ~= ns.SPECIMEN_TRAIT_SCHEMA or capture.traitDirty) and ns.SpecimenTraitsFill then
		ns.SpecimenTraitsFill(self, capture)
	end
	return capture
end
ns.SpecimenStore = Store

-- Migration explicite (tests, diagnostic) : rend le nombre de spécimens créés
function ns:SpecimenMigrate()
	local capture = self:CaptureData()
	capture.specimens = type(capture.specimens) == "table" and capture.specimens or {}
	capture.codex = type(capture.codex) == "table" and capture.codex or {}
	return ReconcileAll(capture)
end

-- Une espèce seulement (avant d'ajouter un spécimen : la fiche d'avant a sa référence)
function ns:SpecimenReconcile(npc)
	local capture = Store(self)
	npc = Key(npc)
	local made = Reconcile(capture, npc, capture.creatures[npc])
	if made > 0 then
		capture.caught = (tonumber(capture.caught) or 0) + made
		Touch(capture)
	end
	return made
end

-- Une collection de personnage versée au compte (Capture.lua) : le Codex se
-- refait à la prochaine lecture
do
	local merge = ns.CaptureMergeInto
	if merge then
		function ns.CaptureMergeInto(account, ...)
			local added = merge(account, ...)
			if type(account) == "table" then account.specDirty = true end
			return added
		end
	end
end

-- La vue par espèce suit les spécimens : étoiles = la meilleure qualité possédée
local function Sync(self, capture, npc)
	local entry = capture.creatures[npc]
	if type(entry) ~= "table" then return end
	local normal, shiny = BestOf(capture, npc, false), BestOf(capture, npc, true)
	if normal then entry.normal = true; entry.stars = normal.stars end
	if shiny then entry.shiny = true; entry.shinyStars = shiny.stars end
	capture.serial = (tonumber(capture.serial) or 0) + 1
	self.captureAppCache = nil
end

-- ---------------------------------------------------------------------------
-- Spécimens
-- ---------------------------------------------------------------------------
function ns:SpecimenAdd(spec)
	if type(spec) ~= "table" or spec.npc == nil then return nil end
	local capture = Store(self)
	local npc = Key(spec.npc)
	local shiny = spec.shiny and true or false
	local id = NewId(capture)
	local new = { id = id, npc = npc, stars = Clamp(spec.stars), shiny = shiny or nil, zone = tonumber(spec.zone),
		at = tonumber(spec.at), by = spec.by, origin = spec.origin or "capture", name = spec.name }
	-- 3.1.0 : caractère tiré, taille tirée à la capture (normale sinon)
	local traits = ns.PERSONALITY_TRAITS or {}
	new.trait = traits[spec.trait or ""] and spec.trait or (self.SpecimenRollTrait and self:SpecimenRollTrait()) or nil
	local sizes = ns.SPECIMEN_SIZE_BY_ID or {}
	if sizes[spec.size or ""] then new.size = spec.size
	elseif new.origin == "capture" and self.SpecimenRollSize then new.size = self:SpecimenRollSize()
	else new.size = "normal" end
	local best = BestOf(capture, npc, shiny)
	capture.specimens[id] = new
	local codex = capture.codex[npc] or {}
	capture.codex[npc] = codex
	local field = shiny and "bestShiny" or "best"
	local old = codex[field] and capture.specimens[codex[field]] and codex[field] or nil
	local place, previous = "reserve", nil
	if not old then
		codex[field], place = id, "codex"
	elseif (not best or new.stars > best.stars) and not spec.keepReserve then
		-- 3.0.0 : un spécimen reçu par échange (keepReserve) reste en Réserve,
		-- marqué « Meilleur que ton spécimen du Codex » : le joueur choisit
		codex[field], place, previous = id, "codex", old
	end
	if new.origin == "capture" then capture.caught = (tonumber(capture.caught) or 0) + 1 end
	Touch(capture)
	Sync(self, capture, npc)
	if new.origin == "capture" and self.SpecimenSizeFeat then pcall(self.SpecimenSizeFeat, self, new) end
	Fire("SPECIMENS", "add", id)
	return id, place, previous
end

-- Captures réussies (spécimens, ceux de la migration compris) ; le nombre
-- d'ESPÈCES reste capture.count (hauts faits, sceaux)
function ns:CaptureCaughtCount()
	return math.max(0, math.floor(tonumber(Store(self).caught) or 0))
end

function ns:SpecimenGet(id)
	return Store(self).specimens[tonumber(id) or id]
end

function ns:SpecimenIsReference(id)
	local capture = Store(self)
	local spec = capture.specimens[tonumber(id) or id]
	if not spec then return false end
	local codex = capture.codex[spec.npc]
	return codex ~= nil and codex[spec.shiny and "bestShiny" or "best"] == spec.id
end

function ns:SpecimenReference(npc, shiny)
	local capture = Store(self)
	local codex = capture.codex[Key(npc)]
	local id = codex and codex[shiny and "bestShiny" or "best"]
	return id and capture.specimens[id] or nil
end

function ns:SpecimenBetterThanCodex(id)
	local spec = self:SpecimenGet(id)
	if not spec or self:SpecimenIsReference(id) then return false end
	local ref = self:SpecimenReference(spec.npc, spec.shiny)
	return ref ~= nil and spec.stars > ref.stars
end

local SORTS = {
	stars = function(a, b)
		if a.stars ~= b.stars then return a.stars > b.stars end
		if (a.shiny == true) ~= (b.shiny == true) then return a.shiny == true end
		return a.id > b.id
	end,
	date = function(a, b)
		if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
		return a.id > b.id
	end,
	name = function(a, b)
		local x, y = tostring(a.name or a.npc), tostring(b.name or b.npc)
		if x ~= y then return x < y end
		return a.id < b.id
	end,
	id = function(a, b) return a.id < b.id end,
}

function ns:SpecimenList(filter)
	filter = filter or {}
	local capture = Store(self)
	local where, npc = filter.where or "all", filter.npc and Key(filter.npc)
	local list = {}
	for _, spec in pairs(capture.specimens) do
		local keep = (npc == nil or spec.npc == npc)
			and (filter.shiny == nil or (spec.shiny == true) == (filter.shiny == true))
			and (filter.stars == nil or spec.stars >= filter.stars)
		if keep and where ~= "all" then
			local codex = capture.codex[spec.npc]
			local ref = codex ~= nil and codex[spec.shiny and "bestShiny" or "best"] == spec.id
			keep = (where == "codex") == ref
		end
		if keep then list[#list + 1] = spec end
	end
	table.sort(list, SORTS[filter.sort or "stars"] or SORTS.stars)
	return list
end

function ns:SpecimenReserve(sort) return self:SpecimenList({ where = "reserve", sort = sort }) end

-- Taille de la Réserve, gardée tant que rien ne bouge (pas de table neuve)
function ns:SpecimenReserveCount()
	local capture = Store(self)
	local cache = self.specimenCountCache
	if cache and cache.serial == capture.specSerial and cache.specimens == capture.specimens then return cache.n end
	local n = 0
	for _, spec in pairs(capture.specimens) do
		local codex = capture.codex[spec.npc]
		if not (codex and codex[spec.shiny and "bestShiny" or "best"] == spec.id) then n = n + 1 end
	end
	self.specimenCountCache = { serial = capture.specSerial, specimens = capture.specimens, n = n }
	return n
end

function ns:SpecimenLabel(spec)
	if type(spec) ~= "table" then return "" end
	local name = self.CreatureName and self:CreatureName(spec.npc, { name = spec.name }) or tostring(spec.name or spec.npc)
	return spec.shiny and self:F("CAPTURE_SHINY_TAG", name) or name
end

-- « Mettre au Codex » : la référence change, l'ancienne passe en Réserve
function ns:SpecimenSetReference(id)
	local capture = Store(self)
	local spec = capture.specimens[tonumber(id) or id]
	if not spec then return false, "missing" end
	local codex = capture.codex[spec.npc] or {}
	capture.codex[spec.npc] = codex
	local field = spec.shiny and "bestShiny" or "best"
	if codex[field] == spec.id then return false, "already" end
	codex[field] = spec.id
	Touch(capture)
	Sync(self, capture, spec.npc)
	self:Print(self:F("SPECIMEN_TO_CODEX", self:SpecimenLabel(spec)))
	Fire("SPECIMENS", "reference", spec.id)
	return true
end

-- Une référence portée comme apparence (« cap:<npc> » ou « cap:<npc>:s »)
-- par l'un des personnages du compte
function ns:SpecimenWorn(id)
	local spec = self:SpecimenGet(id)
	if not spec or not self:SpecimenIsReference(id) then return false end
	local look = "cap:" .. tostring(spec.npc) .. (spec.shiny and ":s" or "")
	local db = self:DB()
	for _, char in pairs(type(db.chars) == "table" and db.chars or {}) do
		local companion = type(char) == "table" and char.companion
		if type(companion) == "table" and companion.appearance == look then return true end
	end
	return false
end

function ns:SpecimenReleaseValue(spec)
	if type(spec) ~= "table" then spec = self:SpecimenGet(spec) end
	if not spec then return 0 end
	local values = ns.PAILLETTES_RELEASE
	if spec.shiny then return values.shiny end
	return values[Clamp(spec.stars)] or 0
end

function ns:SpecimenCanRelease(id)
	local spec = self:SpecimenGet(id)
	if not spec then return false, "missing" end
	if self:SpecimenWorn(id) then return false, "worn" end
	if self:SpecimenIsReference(id) then return false, "reference" end
	-- 2.15.0 : relâcher ne fait jamais baisser tes étoiles. Un spécimen de
	-- Réserve meilleur que la référence de sa version passe d'abord au Codex.
	if self:SpecimenBetterThanCodex(id) then return false, "better" end
	return true
end

function ns:SpecimenRelease(id)
	local ok, why = self:SpecimenCanRelease(id)
	if not ok then return false, why end
	local capture = Store(self)
	local spec = capture.specimens[tonumber(id) or id]
	local gain = self:SpecimenReleaseValue(spec)
	capture.specimens[spec.id] = nil
	Touch(capture)
	Sync(self, capture, spec.npc)
	local total = self:PaillettesAdd(gain, "release")
	self:Print(self:F("SPECIMEN_RELEASED", self:SpecimenLabel(spec), gain, total))
	Fire("SPECIMENS", "release", spec.id)
	return gain
end

-- 3.0.0 : un spécimen de Réserve qui s'en va sans paillettes (échange conclu,
-- CaptureTrades.lua). Jamais une référence du Codex. Rend le spécimen ou nil.
function ns:SpecimenTake(id)
	local capture = Store(self)
	local spec = capture.specimens[tonumber(id) or id]
	if not spec or self:SpecimenIsReference(spec.id) then return nil end
	capture.specimens[spec.id] = nil
	Touch(capture)
	Sync(self, capture, spec.npc)
	Fire("SPECIMENS", "take", spec.id)
	return spec
end

-- ---------------------------------------------------------------------------
-- Réserve et paillettes
-- ---------------------------------------------------------------------------
function ns:ReserveCapacity()
	local capture = self:CaptureData()
	return ns.CAPTURE_RESERVE_BASE + math.max(0, math.floor(tonumber(capture.reserveBonus) or 0))
end

function ns:ReserveFull()
	return self:SpecimenReserveCount() >= self:ReserveCapacity()
end

function ns:ReserveAddSlots(n)
	local capture = self:CaptureData()
	capture.reserveBonus = math.max(0, math.floor(tonumber(capture.reserveBonus) or 0) + math.floor(tonumber(n) or 0))
	Fire("SPECIMENS", "slots", nil)
	return self:ReserveCapacity()
end

function ns:Paillettes()
	return math.max(0, math.floor(tonumber(self:CaptureData().paillettes) or 0))
end

function ns:PaillettesAdd(n, reason)
	n = math.max(0, math.floor(tonumber(n) or 0))
	local capture = self:CaptureData()
	capture.paillettes = self:Paillettes() + n
	capture.paillettesEarned = math.max(0, math.floor(tonumber(capture.paillettesEarned) or 0)) + n
	Fire("PAILLETTES", capture.paillettes, n, reason)
	return capture.paillettes
end

function ns:PaillettesSpend(n, reason)
	n = math.max(0, math.floor(tonumber(n) or 0))
	local have = self:Paillettes()
	if have < n then return false, "short" end
	local capture = self:CaptureData()
	capture.paillettes = have - n
	Fire("PAILLETTES", capture.paillettes, -n, reason)
	return true, capture.paillettes
end

-- ---------------------------------------------------------------------------
-- Qualité au coup fatal
-- ---------------------------------------------------------------------------
function ns:CaptureRollQuality(class)
	local odds = ns.CAPTURE_QUALITY_ODDS[ns.CAPTURE_QUALITY_GROUP[class or "normal"] or "normal"] or ns.CAPTURE_QUALITY_ODDS.normal
	local total = 0
	for _, weight in ipairs(odds) do total = total + weight end
	local roll = math.random() * total
	for stars, weight in ipairs(odds) do
		roll = roll - weight
		if roll < 0 then return stars end
	end
	return #odds
end

-- Un candidat qu'on ne peut pas capturer maintenant : la Réserve est pleine
-- et il y irait (version déjà au Codex). nil : rien ne bloque.
function ns:CaptureBlockedReason(candidate)
	if type(candidate) ~= "table" or candidate.npcID == nil then return nil end
	if not self:CaptureHas(candidate.npcID, candidate.shiny and true or false) then return nil end
	if self:ReserveFull() then return "reserveFull" end
	return nil
end

-- ---------------------------------------------------------------------------
-- Liste de chasse (épingles)
-- ---------------------------------------------------------------------------
function ns:HuntPinned(npc)
	if npc == nil then return false end
	local capture = self:CaptureData()
	return type(capture.pins) == "table" and capture.pins[Key(npc)] == true
end

function ns:HuntPin(npc, on)
	if npc == nil then return false end
	local capture = self:CaptureData()
	if type(capture.pins) ~= "table" then capture.pins = {} end
	npc = Key(npc)
	if on == nil then on = capture.pins[npc] ~= true end
	capture.pins[npc] = on and true or nil
	-- épingler, c'est vouloir la voir : « Ne plus proposer » est levé
	if on and type(capture.skip) == "table" then capture.skip[npc] = nil end
	Fire("SPECIMENS", "pin", npc)
	return on and true or false
end

function ns:HuntPins()
	local list = {}
	for npc, on in pairs(self:CaptureData().pins or {}) do
		if on == true then list[#list + 1] = npc end
	end
	table.sort(list, function(a, b) return tostring(a) < tostring(b) end)
	return list
end

-- ---------------------------------------------------------------------------
-- Mode chasse (réglages : captureHuntOn, captureHuntUntil en temps réel)
-- ---------------------------------------------------------------------------
function ns:HuntActive()
	local db = self:DB()
	if db.captureHuntOn ~= true then return false end
	local untilAt = tonumber(db.captureHuntUntil)
	return untilAt == nil or RealTime() < untilAt
end

function ns:HuntRemaining()
	if not self:HuntActive() then return nil end
	local untilAt = tonumber(self:DB().captureHuntUntil)
	if not untilAt then return -1 end
	return math.max(0, untilAt - RealTime())
end

function ns:HuntText()
	local left = self:HuntRemaining()
	if not left then return nil end
	if left < 0 then return L.HUNT_TEXT_ON end
	return self.CaptureMuteText and self:CaptureMuteText(left) or (math.ceil(left / 60) .. " min")
end

function ns:HuntStart(minutes)
	minutes = tonumber(minutes)
	local db = self:DB()
	db.captureHuntOn = true
	if minutes and minutes > 0 then
		db.captureHuntUntil = RealTime() + minutes * 60
		self:Print(self:F("HUNT_MSG_START_FOR", self:HuntText()))
	else
		db.captureHuntUntil = nil
		self:Print(L.HUNT_MSG_START_ON)
	end
	Fire("HUNT", true)
	return true
end

-- `expired` : fin naturelle (message de fin plutôt que d'arrêt)
function ns:HuntStop(expired)
	local db = self:DB()
	if db.captureHuntOn ~= true then return false end
	db.captureHuntOn, db.captureHuntUntil = nil, nil
	self:Print(expired and L.HUNT_MSG_END or L.HUNT_MSG_STOP)
	Fire("HUNT", false)
	return true
end

function ns:HuntToggle()
	if self:HuntActive() then return not self:HuntStop() end
	return self:HuntStart(nil)
end

-- Horloge de la capture (CaptureQueue.lua) : la chasse arrivée à son terme
-- est annoncée, même après un /reload ou une absence. Rien n'est alloué.
function ns:HuntCheck()
	local db = self:DB()
	if db.captureHuntOn ~= true then return false end
	local untilAt = tonumber(db.captureHuntUntil)
	if untilAt and RealTime() >= untilAt then return self:HuntStop(true) end
	return false
end

-- ---------------------------------------------------------------------------
-- Méfiance (mode chasse seulement) : captures de l'espèce dans la journée
-- ---------------------------------------------------------------------------
-- clé du jour (date locale), refaite au plus une fois par seconde : la
-- chance est lue à chaque rafraîchissement de la liste du filet
local dayAt, dayKey
local function DayKey()
	local now = RealTime()
	if dayKey and now == dayAt then return dayKey end
	local key
	local date = G("date")
	if type(date) == "function" then
		local ok, text = pcall(date, "%Y-%m-%d", now)
		if ok and type(text) == "string" then key = text end
	end
	dayAt, dayKey = now, key or tostring(math.floor(now / 86400))
	return dayKey
end

local function Wary(capture)
	local wary = capture.wary
	local day = DayKey()
	if type(wary) ~= "table" or wary.day ~= day or type(wary.n) ~= "table" then
		wary = { day = day, n = {} }
		capture.wary = wary
	end
	return wary
end

-- Une capture réussie de plus aujourd'hui pour cette espèce
function ns:CaptureWaryNote(npc)
	if npc == nil then return 0 end
	local wary = Wary(self:CaptureData())
	npc = Key(npc)
	wary.n[npc] = (wary.n[npc] or 0) + 1
	return wary.n[npc]
end

-- Facteur de chance (1 hors chasse), et captures du jour de l'espèce
function ns:CaptureWariness(npc)
	if npc == nil then return 1, 0 end
	local capture = self:CaptureData()
	local wary = capture.wary
	local count = 0
	if type(wary) == "table" and type(wary.n) == "table" and wary.day == DayKey() then count = wary.n[Key(npc)] or 0 end
	if count <= 0 or not self:HuntActive() then return 1, count end
	local w = ns.CAPTURE_WARINESS
	return math.max(w.floor, 1 - w.step * count), count
end

-- ---------------------------------------------------------------------------
-- Réplique au coup fatal (CaptureQueue.lua, CaptureOffer) : un 3 étoiles ou
-- un brillant. En combat, un 3 étoiles passe en « event » : il attend la fin
-- du combat (résumé du compagnon) au lieu d'être perdu.
-- ---------------------------------------------------------------------------
function ns:CaptureGreatLine(candidate)
	if type(candidate) ~= "table" then return false end
	local pool
	if candidate.shiny then pool = "CAPTURE_GREAT_SHINY"
	elseif tonumber(candidate.stars) == 3 then pool = "CAPTURE_GREAT" end
	if not pool then return false end
	-- hors combat, une réaction comme « On l'embarque ? » ; en combat, un 3 étoiles est gardé pour après ;
	-- une brillante a déjà sa grande bulle (Shiny.lua) : la nôtre ne la recouvre pas
	local fight = Call(G("InCombatLockdown")) or Call(G("UnitAffectingCombat"), "player")
	return self:CompanionSay(pool, { category = (fight and not candidate.shiny) and "event" or nil,
		args = { candidate.name } })
end

-- ---------------------------------------------------------------------------
-- 3.0.0 : ta collection d'avant la 3.0, et le cadeau de bienvenue
-- ---------------------------------------------------------------------------
-- Les spécimens venus de la migration (origin "migration") : espèces,
-- spécimens, brillants. Lu par la visite guidée (GuidedTour.lua).
function ns:SpecimenMigratedCounts()
	local capture = Store(self)
	local species, total, shiny, seen = 0, 0, 0, {}
	for _, spec in pairs(capture.specimens) do
		if type(spec) == "table" and spec.origin == "migration" then
			total = total + 1
			if spec.shiny then shiny = shiny + 1 end
			if spec.npc ~= nil and not seen[spec.npc] then seen[spec.npc] = true; species = species + 1 end
		end
	end
	return species, total, shiny
end

-- Cadeau de la 3.0 : qui avait PLUS de GIFT30.minSpecies - 1 espèces avant
-- la 3.0 choisit jusqu'à GIFT30.max créatures de son Codex ; une copie de
-- chacune entre dans la Réserve (version normale, étoiles de la référence ;
-- une espèce possédée seulement brillante est copiée en normale, avec ses
-- étoiles). Une fois par compte (capture.gift30Used). Les copies vont
-- toujours en Réserve (jamais au Codex) et y prennent une place.
ns.GIFT30 = { max = 3, minSpecies = 4, origin = "gift3" }

function ns:Gift30Available()
	local capture = Store(self)
	if capture.gift30Used then return false end
	local species = self:SpecimenMigratedCounts()
	return species >= ns.GIFT30.minSpecies
end

-- Ce qui peut être copié : une ligne par espèce du Codex (table neuve,
-- triée par nom) { npc, stars, name, shinyOnly }
function ns:Gift30Candidates()
	local capture = Store(self)
	local list = {}
	for npc, codex in pairs(capture.codex) do
		local ref = codex.best and capture.specimens[codex.best]
		local shinyOnly = false
		if not ref and codex.bestShiny then ref, shinyOnly = capture.specimens[codex.bestShiny], true end
		if ref then
			local name = self.CreatureName and self:CreatureName(npc, { name = ref.name }) or tostring(ref.name or npc)
			list[#list + 1] = { npc = npc, stars = ref.stars, name = name, zone = ref.zone, shinyOnly = shinyOnly or nil }
		end
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
		return tostring(a.npc) < tostring(b.npc)
	end)
	return list
end

-- Verse les copies : `npcs` = liste de 1 à GIFT30.max espèces du Codex.
-- Rend la liste des ids créés, ou false, raison ("used", "count", "missing",
-- "full").
function ns:Gift30Grant(npcs)
	if not self:Gift30Available() then return false, "used" end
	local capture = Store(self)
	local picks, seen = {}, {}
	for _, npc in ipairs(type(npcs) == "table" and npcs or {}) do
		npc = Key(npc)
		if not seen[npc] then seen[npc] = true; picks[#picks + 1] = npc end
	end
	if #picks == 0 or #picks > ns.GIFT30.max then return false, "count" end
	local refs = {}
	for index, npc in ipairs(picks) do
		local codex = capture.codex[npc]
		local ref = codex and ((codex.best and capture.specimens[codex.best]) or (codex.bestShiny and capture.specimens[codex.bestShiny]))
		if not ref then return false, "missing" end
		refs[index] = ref
	end
	if self:SpecimenReserveCount() + #picks > self:ReserveCapacity() then return false, "full" end
	local ids, at = {}, RealTime()
	for index, ref in ipairs(refs) do
		local id = NewId(capture)
		-- 3.1.0 : un caractère tiré, taille normale
		capture.specimens[id] = { id = id, npc = ref.npc, stars = Clamp(ref.stars), zone = ref.zone, at = at,
			origin = ns.GIFT30.origin, name = ref.name, trait = self.SpecimenRollTrait and self:SpecimenRollTrait() or nil,
			size = "normal" }
		ids[index] = id
	end
	capture.gift30Used = true
	Touch(capture)
	Fire("SPECIMENS", "gift", ids[1])
	return ids
end

-- ---------------------------------------------------------------------------
-- /qc chasse [5|15|30|60|on|stop]
-- ---------------------------------------------------------------------------
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_HUNT")
		end
	end
end
if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["chasse"] = function(self, rest)
		local arg = tostring(rest or ""):match("^%s*(%S*)") or ""
		arg = arg:lower()
		if arg == "" then return self:HuntToggle() end
		if arg == "stop" or arg == "off" or arg == "arret" or arg == "arrêt" or arg == "non" then
			if not self:HuntStop() then self:Print(L.HUNT_MSG_STOP) end
			return false
		end
		if arg == "on" or arg == "oui" then return self:HuntStart(nil) end
		if arg == "statut" or arg == "status" or arg == "?" then
			local left = self:HuntRemaining()
			if not left then self:Print(L.HELP_HUNT)
			elseif left < 0 then self:Print(L.HUNT_MSG_STATUS_ON)
			else self:Print(self:F("HUNT_MSG_STATUS", self:HuntText())) end
			return self:HuntActive()
		end
		local minutes = tonumber(arg)
		if minutes and minutes > 0 then return self:HuntStart(minutes) end
		self:Print(L.HELP_HUNT)
		return false
	end
	ns.EXTRA_COMMANDS["hunt"] = ns.EXTRA_COMMANDS["chasse"]
end

if ns.Mark then ns.Mark("CaptureSpecimens") end
