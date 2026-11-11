-- QuestCompanion 3.0.0 : échanges de spécimens entre joueurs (CaptureTrades.lua).
-- Un seul client dans le harnais : l'autre joueur (« Deklatis ») est simulé
-- en lui faisant envoyer des messages d'addon (CHAT_MSG_ADDON rejoué) et en
-- lisant ce que notre client envoie (C_ChatInfo.SendAddonMessage capturé).
-- Poignée de main et versions, invitation (accepter, refuser, 60 s), offres
-- et remise à zéro des validations, règles d'éligibilité, place dans la
-- Réserve, engagement en deux phases (spécimens déplacés, origine, ids
-- neufs), abandons (joueur introuvable, combat, écran de chargement, données
-- différentes, délai), reprise après un /reload au milieu de l'engagement,
-- journal (50 lignes), temps de repos, hauts faits, commandes, menu, la vue
-- « Échanges » dans les deux styles et ses contrastes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local X = { saved = {}, sent = {} }
local GLOBALS = { "C_ChatInfo", "UnitName", "UnitFullName", "UnitIsPlayer", "UnitIsFriend", "UnitFactionGroup",
	"InCombatLockdown", "UnitAffectingCombat", "time", "GetNormalizedRealmName", "C_Timer", "UnitLevel",
	"ERR_CHAT_PLAYER_NOT_FOUND_S" }
for _, name in ipairs(GLOBALS) do X.saved[name] = rawget(_G, name) end
local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble" }
local ZONE = 1413
local PEER, PEER_KEY, ME_KEY = "Deklatis-Royaume", "deklatis-royaume", "testeur-royaume"
local INK = NS.AZEROTH_INK

local function Has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end

function X.Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:TrainerResetSession()
	NS:TradeResetSession()
	NS.uiStyleCache, NS.errors, NS.carnetInkMisses = {}, {}, nil
	NS.captureAppCache, NS.specimenCountCache, NS.codexReserveCache, NS.codexZoneCache = nil, nil, nil, nil
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab, NS:DB().trainerHolders = nil, nil, nil, nil
	X.sent, X.now, X.combat = {}, 1800000000, false
	X.units = { target = { name = "Deklatis", faction = "Alliance" } }
	_G.time = function() return X.now end
	_G.C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return 0 end,
		SendAddonMessage = function(prefix, text, channel, target)
			X.sent[#X.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
			return 0
		end,
		InChatMessagingLockdown = function() return false end,
	}
	_G.InCombatLockdown = function() return X.combat end
	_G.UnitAffectingCombat = function() return X.combat end
	_G.UnitName = function(unit)
		if unit == "player" then return "Testeur" end
		local u = X.units[unit]
		return u and u.name, u and u.realm
	end
	_G.UnitFullName = nil
	_G.UnitIsPlayer = function(unit) return unit == "player" or X.units[unit] ~= nil end
	_G.UnitIsFriend = function(_, unit) local u = X.units[unit]; return not (u and u.faction == "Horde") end
	_G.UnitFactionGroup = function(unit)
		if unit == "player" then return "Alliance" end
		local u = X.units[unit]
		return u and u.faction or "Alliance"
	end
	_G.GetNormalizedRealmName = function() return "Royaume" end
	_G.C_Timer = nil
	_G.UnitLevel = function() return 20 end
	_G.ERR_CHAT_PLAYER_NOT_FOUND_S = "Aucun joueur nommé « %s » n'est connecté."
	Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = ZONE, 20
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "azeroth" and "azeroth" or "sobre"
	NS:DB().companionCapture = true
	NS:CompanionData().tutoDone = true
	NS:CompanionData().appearance = nil
	-- le Codex : Raptor 3, Kodo 1, Grue 3 ; la Réserve : quatre spécimens (dont un meilleur que le Codex)
	local data = NS:CaptureData()
	data.creatures[900] = { name = "Raptor", normal = true, stars = 3, zoneID = ZONE, type = "Bête", class = "normal", at = 1793000000 }
	data.creatures[901] = { name = "Kodo", normal = true, stars = 1, zoneID = ZONE, type = "Bête", class = "normal", at = 1793000100 }
	data.creatures[903] = { name = "Grue", normal = true, stars = 3, zoneID = ZONE, type = "Bête", class = "normal", at = 1793000200 }
	data.count = 3
	NS:SpecimenMigrate()
	X.ids = {}
	local function Add(key, spec)
		spec.origin, spec.zone, spec.at, spec.by = spec.origin or "capture", ZONE, 1793001000, "Testeur"
		spec.trait, spec.size = spec.trait or "curious", spec.size or "normal"
		X.ids[key] = NS:SpecimenAdd(spec)
	end
	Add("raptor2", { npc = 900, stars = 2, name = "Raptor", size = "large" })
	Add("raptor1", { npc = 900, stars = 1, name = "Raptor" })
	Add("grue2", { npc = 903, stars = 2, name = "Grue", trait = "lazy" })
	Add("kodo1", { npc = 901, stars = 1, name = "Kodo" })
	Add("kodo3", { npc = 901, stars = 3, name = "Kodo", keepReserve = true })
	X.ids.raptorRef = NS:SpecimenReference(900, false).id
	-- hauts faits : notés ici (le moteur dort dans le harnais)
	X.feats = { count = {}, flag = {} }
	X.FeatCount, X.FeatFlag = NS.FeatCount, NS.FeatFlag
	NS.FeatCount = function(_, key, delta, scope) X.feats.count[key] = (X.feats.count[key] or 0) + (delta or 0); X.feats.countScope = scope; return 1 end
	NS.FeatFlag = function(_, key, scope) X.feats.flag[key] = scope; return 1 end
	Mock:Reset()
end

function X.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = X.saved[name] end
	if X.FeatCount then NS.FeatCount, NS.FeatFlag = X.FeatCount, X.FeatFlag end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:TrainerResetSession()
	NS:TradeResetSession()
	NS.uiStyleCache = {}
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab, NS:DB().trainerHolders = nil, nil, nil, nil
	ResetWorld()
end

-- Ce que notre client a envoyé sous le préfixe des échanges (la file vidée), découpé
function X.Take(prefix)
	for _ = 1, 30 do NS:TrainerPump(10) end
	local out, rest = {}, {}
	for _, msg in ipairs(X.sent) do
		if msg.prefix == (prefix or "QCTrade") then
			local f = {}
			for field in (msg.text .. "~"):gmatch("([^~]*)~") do f[#f + 1] = field end
			f.text, f.target, f.channel = msg.text, msg.target, msg.channel
			out[#out + 1] = f
		else
			rest[#rest + 1] = msg
		end
	end
	X.sent = rest
	return out
end
function X.Kinds(list)
	local kinds = {}
	for index, f in ipairs(list) do kinds[index] = f[1] end
	return table.concat(kinds, ",")
end
function X.Find(list, kind)
	for _, f in ipairs(list) do if f[1] == kind then return f end end
	return nil
end

-- L'autre joueur parle
function X.From(text, sender)
	return NS:TrainerOnAddonMessage("QCTrade", text, "WHISPER", sender or PEER)
end
function X.Say(kind, tid, ...)
	local parts = { kind, "1", tid }
	for index = 1, select("#", ...) do parts[#parts + 1] = tostring((select(index, ...))) end
	return X.From(table.concat(parts, "~"))
end

-- Un spécimen de Deklatis, tel que son client l'enverrait
function X.PeerSpec(fields)
	local f = { i = fields.i or 501, n = fields.n or 900, s = fields.s or 3, h = fields.h, z = fields.z or "normal",
		t = fields.t or "daring", zo = fields.zo or ZONE, at = fields.at or 1793500000, by = fields.by or "Thrall",
		o = fields.o or "capture", nm = fields.nm or "Raptor", cl = fields.cl or "normal", ty = fields.ty or "Bête",
		hp = fields.hp or 0 }
	return NS.TrainerEncode(f)
end
-- Son offre entière (révision rev), morceau par morceau
function X.PeerOffer(tid, rev, raws)
	if #raws == 0 then return X.Say("O", tid, rev, 0, 0, "") end
	for index, raw in ipairs(raws) do X.Say("O", tid, rev, index, #raws, raw) end
end
function X.PeerLock(tid, raws)
	if #raws == 0 then return X.Say("L", tid, 0, 0, "") end
	for index, raw in ipairs(raws) do X.Say("L", tid, index, #raws, raw) end
end

-- Un échange ouvert à notre initiative : rend le tid
function X.Open()
	NS:TradeInvite("Deklatis")
	local tid = X.Find(X.Take(), "I")[3]
	X.Say("R", tid, "3.0.0")
	X.Say("A", tid)
	X.Take()
	return tid
end

local function Session() return NS:TradeSession() end

-- 1. Poignée de main et versions ---------------------------------------------------------------------------
do
	Say("-- qc30 échanges : invitation, versions, refus")
	X.Reset()
	local ok = NS:TradeInvite("Deklatis")
	local sent = X.Take()
	local inv = X.Find(sent, "I")
	Check("[ECH] invitation : préfixe « QCTrade » (16 caractères au plus), I~1~tid~version~clé, en chuchotement",
		NS.TRADE_PREFIX == "QCTrade" and #NS.TRADE_PREFIX <= 16 and ok and inv and inv[2] == "1" and inv[3] ~= ""
		and NS.TrainerUnescape(inv[4]) == tostring(NS.version) and NS.TrainerUnescape(inv[5]) == PEER_KEY
		and inv.channel == "WHISPER" and inv.target == PEER, inv and inv.text)
	local probe = false
	for _, msg in ipairs(X.sent) do if msg.prefix == "QCTrainer" and msg.text:find("^P~") then probe = true end end
	Check("[ECH] … et une sonde de la fiche (une version d'avant la 3.0 y répond)", probe)
	Check("[ECH] … session « inviting », message dans le chat", Session().phase == "inviting"
		and Has(Mock:Output(), "Invitation à l'échange envoyée à Deklatis"))
	local tid = inv[3]
	X.Say("R", tid, "3.0.0")
	Check("[ECH] accusé R : l'invitation est affichée chez lui", Session().rung == true and Session().peerVersion == "3.0.0")
	Mock:Advance(12); NS:TradeTick()
	Check("[ECH] accusé reçu : pas de « pas de réponse » au bout de 10 s", Session() and Session().phase == "inviting")
	X.Say("A", tid)
	Check("[ECH] accepté : la fenêtre s'ouvre (phase open)", Session().phase == "open"
		and Has(Mock:Output(), "Échange ouvert avec Deklatis"))
	NS:TradeCancel()
	local x = X.Find(X.Take(), "X")
	Check("[ECH] Annuler : X~cancel, fin, temps de repos", x and x[4] == "cancel" and Session() == nil)
	Check("[ECH] temps de repos : 10 s avant une nouvelle invitation", select(2, NS:TradeInvite("Deklatis")) == "cooldown"
		and Has(Mock:Output(), "Patiente encore"))
	Mock:Advance(11)
	-- un autre protocole : refus « version »
	NS:TradeInvite("Deklatis")
	tid = X.Find(X.Take(), "I")[3]
	X.From("R~2~" .. tid .. "~4.0.0")
	Check("[ECH] accusé d'une autre génération du protocole : fin « version »", Session() == nil
		and Has(Mock:Output(), "vos versions de QuestCompanion ne se comprennent pas"))
	Mock:Advance(11)
	X.Take()
	X.From("I~2~abcd~4.0.0~" .. ME_KEY)
	local d = X.Find(X.Take(), "D")
	Check("[ECH] invitation d'une autre génération : refus D~version", d and d[3] == "abcd" and d[4] == "version" and Session() == nil)
	-- pas de réponse du tout
	NS:TradeInvite("Deklatis")
	X.Take()
	Mock:Reset()
	Mock:Advance(11); NS:TradeTick()
	Check("[ECH] 10 s sans accusé : « pas de QuestCompanion 3.0 » (ou hors ligne, autre faction)", Session() == nil
		and Has(Mock:Output(), "sans QuestCompanion 3.0"), Mock:Output())
	Mock:Advance(11)
	-- une version d'avant la 3.0 : elle répond à la sonde de la fiche, pas à l'invitation
	NS:TradeInvite("Deklatis")
	X.Take()
	NS:TrainerOnAddonMessage("QCTrainer", "A~1", "WHISPER", PEER)
	Mock:Reset()
	Mock:Advance(11); NS:TradeTick()
	Check("[ECH] détenteur d'une version d'avant la 3.0 : le dire", Session() == nil
		and Has(Mock:Output(), "une version d'avant la 3.0"), Mock:Output())
	Mock:Advance(11)
	Mock:Reset()
	Check("[ECH] pas d'échange avec soi-même (le dire), ni sans nom", select(2, NS:TradeInvite("Testeur")) == "self"
		and Has(Mock:Output(), "toi-même") and select(2, NS:TradeInvite("")) == "name")
	X.units.target = { name = "Garrosh", faction = "Horde" }
	Mock:Reset()
	local faction = select(2, NS:TradeWithTarget()) == "faction" and Has(Mock:Output(), "l'autre faction") and Session() == nil
	X.units.target = nil
	Check("[ECH] cible de l'autre faction : refusée d'avance, la raison dite ; sans cible : le dire", faction
		and select(2, NS:TradeWithTarget()) == "target")
	X.units.target = { name = "Deklatis", faction = "Alliance" }
	Check("[ECH] cible de ta faction : invitation", NS:TradeWithTarget() == true and Session().peer == PEER)
	NS:TradeCancel()
	X.Done()
end

-- 2. Invitation reçue : accepter, refuser, 60 s, occupé ---------------------------------------------------
do
	Say("-- qc30 échanges : invitation reçue")
	X.Reset()
	X.Say("I", "t1", "3.0.0", ME_KEY)
	local r = X.Find(X.Take(), "R")
	Check("[ECH] invitation reçue : accusé R, session « invited », ligne dans le chat",
		r and r[3] == "t1" and Session().phase == "invited" and Session().role == "invitee"
		and Has(Mock:Output(), "Deklatis te propose un échange de spécimens"))
	X.From("I~1~t9~3.0.0~" .. ME_KEY, "Oscar-Royaume")
	local busy = X.Find(X.Take(), "D")
	Check("[ECH] une autre invitation pendant ce temps : D~busy", busy and busy[3] == "t9" and busy[4] == "busy"
		and busy.target == "Oscar-Royaume" and Session().tid == "t1")
	NS:TradeAccept()
	Check("[ECH] Accepter : A, phase open", X.Find(X.Take(), "A") and Session().phase == "open")
	NS:TradeCancel()
	X.Take()
	Mock:Advance(11)
	X.Say("I", "t2", "3.0.0", ME_KEY)
	X.Take()
	NS:TradeDecline()
	local d = X.Find(X.Take(), "D")
	Check("[ECH] Refuser : D~no", d and d[3] == "t2" and d[4] == "no" and Session() == nil)
	Mock:Advance(11)
	X.Say("I", "t3", "3.0.0", "oscar-royaume")
	Check("[ECH] invitation pour un autre (clé) : ignorée", Session() == nil and #X.Take() == 0)
	X.Say("I", "t4", "3.0.0", ME_KEY)
	X.Take()
	Mock:Advance(61); NS:TradeTick()
	d = X.Find(X.Take(), "D")
	Check("[ECH] 60 s sans réponse : D~timeout, fin", d and d[4] == "timeout" and Session() == nil)
	-- côté de celui qui invite : refus reçu
	Mock:Advance(11)
	NS:TradeInvite("Deklatis")
	local tid = X.Find(X.Take(), "I")[3]
	Mock:Reset()
	X.Say("D", tid, "no")
	Check("[ECH] refus reçu : « Deklatis a refusé l'échange. »", Session() == nil and Has(Mock:Output(), "Deklatis a refusé l'échange."))
	Mock:Advance(11)
	NS:TradeInvite("Deklatis")
	X.Take()
	Mock:Advance(61); NS:TradeTick()
	Check("[ECH] accusé mais pas de réponse en 60 s : fin", Session() == nil)
	-- capture coupée : refus « off »
	Mock:Advance(11)
	NS:DB().companionCapture = false
	X.Say("I", "t5", "3.0.0", ME_KEY)
	d = X.Find(X.Take(), "D")
	Check("[ECH] capture coupée : D~off", d and d[4] == "off" and Session() == nil)
	NS:DB().companionCapture = true
	-- en combat : refus
	X.combat = true
	X.Say("I", "t6", "3.0.0", ME_KEY)
	X.combat = false   -- (la file attend la fin du combat pour envoyer)
	d = X.Find(X.Take(), "D")
	Check("[ECH] en combat : D~combat (parti après le combat)", d and d[4] == "combat" and Session() == nil)
	X.Done()
end

-- 3. Éligibilité et verrou --------------------------------------------------------------------------------
do
	Say("-- qc30 échanges : éligibilité")
	X.Reset()
	local ids = X.ids
	Check("[ECH] spécimen de Réserve : échangeable ; référence du Codex, meilleur que le Codex, inexistant : non",
		NS:SpecimenCanTrade(ids.raptor2) == true and select(2, NS:SpecimenCanTrade(ids.raptorRef)) == "reference"
		and select(2, NS:SpecimenCanTrade(ids.kodo3)) == "better" and select(2, NS:SpecimenCanTrade(99999)) == "missing")
	NS:CompanionData().appearance = "cap:900"
	Check("[ECH] apparence portée : non (« worn »)", select(2, NS:SpecimenCanTrade(ids.raptorRef)) == "worn")
	NS:CompanionData().appearance = nil
	X.Open()
	Check("[ECH] proposé : true", NS:TradeToggleOffer(ids.raptor2) == true)
	Check("[ECH] engagé : plus échangeable ailleurs, ni relâché, ni mis au Codex",
		select(2, NS:SpecimenCanTrade(ids.raptor2)) == "locked" and select(2, NS:SpecimenCanRelease(ids.raptor2)) == "locked"
		and select(2, NS:SpecimenSetReference(ids.raptor2)) == "locked" and not NS:SpecimenIsReference(ids.raptor2))
	Check("[ECH] la référence ne se propose pas", select(2, NS:TradeToggleOffer(ids.raptorRef)) == "reference"
		and #Session().mine == 1)
	NS:TradeToggleOffer(ids.raptor1); NS:TradeToggleOffer(ids.grue2)
	Mock:Reset()
	Check("[ECH] 3 au plus", select(2, NS:TradeToggleOffer(ids.kodo1)) == "max" and #Session().mine == 3
		and Has(Mock:Output(), "3 spécimens au plus"))
	Check("[ECH] retirer : false, il redevient libre", NS:TradeToggleOffer(ids.grue2) == false
		and NS:SpecimenCanTrade(ids.grue2) == true)
	NS:TradeCancel()
	Check("[ECH] échange fini : plus rien d'engagé", NS:SpecimenCanTrade(ids.raptor2) == true
		and NS:SpecimenCanRelease(ids.raptor2) == true)
	X.Done()
end

-- 4. Offres, validations, place --------------------------------------------------------------------------------
do
	Say("-- qc30 échanges : offres et validations")
	X.Reset()
	local ids = X.ids
	local tid = X.Open()
	NS:TradeToggleOffer(ids.raptor2)
	local o = X.Find(X.Take(), "O")
	local mine = NS:TradeDecodeSpec(o[7])
	Check("[ECH] offre : O~1~tid~rév~1~1~spécimen complet", o[3] == tid and o[4] == "1" and o[5] == "1" and o[6] == "1"
		and mine and mine.i == ids.raptor2 and mine.npc == 900 and mine.stars == 2 and mine.size == "large"
		and mine.trait == "curious" and mine.by == "Testeur" and mine.zone == ZONE and mine.name == "Raptor"
		and mine.origin == "capture" and mine.hops == 0, o and o.text)
	Check("[ECH] … sous 255 octets", #o.text <= 255, #o.text)
	NS:TradeToggleOffer(ids.raptor2)
	o = X.Find(X.Take(), "O")
	Check("[ECH] offre vidée : O~…~2~0~0~", o[4] == "2" and o[5] == "0" and o[6] == "0")
	NS:TradeToggleOffer(ids.raptor2)
	X.Take()
	local peerRaw = X.PeerSpec({ i = 77, n = 950, s = 2, h = true, nm = "Ours givré", z = "giant", t = "zen" })
	X.PeerOffer(tid, 1, { peerRaw })
	local s = Session()
	Check("[ECH] son offre reçue et lue", s.theirRev == 1 and #s.theirs == 1 and s.theirs[1].spec.npc == 950
		and s.theirs[1].spec.shiny and s.theirs[1].spec.size == "giant" and s.theirs[1].spec.name == "Ours givré")
	local validated = NS:TradeValidate() == true and s.myValid
	local v = X.Find(X.Take(), "V")
	Check("[ECH] Valider : V~1~tid~ma révision~la sienne", validated and v and v[4] == "3" and v[5] == "1")
	X.PeerOffer(tid, 2, { peerRaw, X.PeerSpec({ i = 78, n = 901, s = 1, nm = "Kodo" }) })
	Check("[ECH] il change son offre : les deux validations à zéro", not s.myValid and not s.theirValid and #s.theirs == 2)
	X.Say("V", tid, 1, 3)
	Check("[ECH] sa validation d'une vieille révision : ignorée", not s.theirValid)
	X.Say("V", tid, 2, 3)
	Check("[ECH] sa validation des bonnes révisions : notée", s.theirValid and s.phase == "open")
	NS:TradeToggleOffer(ids.raptor1)
	Check("[ECH] je change mon offre : les deux validations à zéro", not s.myValid and not s.theirValid and s.myRev == 4)
	-- place : la Réserve pleine
	local capture = NS:CaptureData()
	X.Take()
	X.PeerOffer(tid, 3, { X.PeerSpec({ i = 80, n = 901, s = 1, nm = "Kodo" }), X.PeerSpec({ i = 81, n = 901, s = 1, nm = "Kodo" }),
		X.PeerSpec({ i = 82, n = 903, s = 1, nm = "Grue" }) })
	NS:TradeToggleOffer(ids.raptor1)
	local capacity = NS.ReserveCapacity
	NS.ReserveCapacity = function(self) return self:SpecimenReserveCount() end
	Check("[ECH] place : 3 reçus en Réserve, 1 donné, 0 libre : il en manque 2", NS:TradeRoom() == 2)
	Mock:Reset()
	Check("[ECH] Valider refusé, la raison dite", select(2, NS:TradeValidate()) == "full" and not s.myValid
		and Has(Mock:Output(), "il manque 2 place"))
	X.PeerOffer(tid, 4, { X.PeerSpec({ i = 83, n = 960, s = 1, nm = "Loup" }), X.PeerSpec({ i = 84, n = 960, s = 2, nm = "Loup" }) })
	Check("[ECH] une espèce nouvelle : la première va au Codex (ne compte pas), la seconde en Réserve", NS:TradeRoom() == 0)
	NS.ReserveCapacity = capacity
	Check("[ECH] rien à échanger des deux côtés : Valider refusé", (function()
		NS:TradeToggleOffer(ids.raptor2)
		X.PeerOffer(tid, 5, {})
		return select(2, NS:TradeValidate()) == "empty"
	end)())
	NS:TradeCancel()
	X.Done()
end

-- 5. Engagement en deux phases : réussi ---------------------------------------------------------------------
do
	Say("-- qc30 échanges : engagement réussi")
	X.Reset()
	local ids = X.ids
	local capture = NS:CaptureData()
	local countBefore, reserveBefore = capture.count, NS:SpecimenReserveCount()
	local tid = X.Open()
	NS:TradeToggleOffer(ids.raptor2)
	NS:TradeToggleOffer(ids.grue2)
	X.Take()
	-- il donne : un Ours givré brillant (espèce nouvelle) et un Raptor 3 étoiles (égal au Codex : Réserve)
	-- et un Kodo 2 étoiles (meilleur que le Codex : reste en Réserve, marqué)
	local raws = { X.PeerSpec({ i = 77, n = 950, s = 2, h = true, nm = "Ours givré", z = "giant", t = "zen", by = "Thrall",
		o = "migration", hp = 1 }), X.PeerSpec({ i = 78, n = 900, s = 3, nm = "Raptor", by = "Jaina" }),
		X.PeerSpec({ i = 79, n = 901, s = 2, nm = "Kodo", by = "Thrall" }) }
	X.PeerOffer(tid, 1, raws)
	NS:TradeValidate()
	X.Take()
	X.Say("V", tid, 1, 2)
	local s = Session()
	local lock = X.Take()
	Check("[ECH] les deux validés : phase 1, mes données complètes (L)", s.phase == "locking" and X.Kinds(lock) == "L,L"
		and NS:TradeDecodeSpec(lock[1][6]).i == ids.raptor2 and lock[1][4] == "1" and lock[1][5] == "2")
	X.PeerLock(tid, raws)
	local pending = capture.tradePending
	local k = X.Find(X.Take(), "K")
	Check("[ECH] ses données = celles affichées : préparé, journalisé dans la sauvegarde, K", s.phase == "prepared"
		and k and pending and pending.tid == tid and pending.peer == PEER and #pending.give == 2 and #pending.get == 3
		and NS:SpecimenGet(ids.raptor2) ~= nil)
	Check("[ECH] préparé : Annuler n'est plus possible", select(2, NS:TradeCancel()) == "prepared")
	Mock:Reset()
	X.Say("K", tid)
	local f = X.Find(X.Take(), "F")
	Check("[ECH] son K : engagé, F envoyé, fin de session", f and f[3] == tid and Session() == nil and capture.tradePending == nil)
	Check("[ECH] donnés : partis de la Réserve", NS:SpecimenGet(ids.raptor2) == nil and NS:SpecimenGet(ids.grue2) == nil)
	local got = {}
	for _, spec in pairs(capture.specimens) do if spec.origin == "trade" then got[spec.npc] = spec end end
	local ours, raptor, kodo = got[950], got[900], got[901]
	Check("[ECH] reçus : trois spécimens, ids neufs", ours and raptor and kodo and ours.id ~= 77 and raptor.id ~= 78
		and ours.id ~= ids.raptor2 and kodo.id ~= ids.grue2)
	Check("[ECH] … caractère, taille, étoiles, brillant gardés", ours.trait == "zen" and ours.size == "giant" and ours.stars == 2
		and ours.shiny == true and raptor.stars == 3)
	Check("[ECH] … dresseur d'origine gardé, « Échange avec Deklatis », date, origine première, échanges subis",
		ours.by == "Thrall" and ours.tradedFrom == "Deklatis" and ours.tradedAt == X.now and ours.firstOrigin == "migration"
		and ours.hops == 2 and raptor.by == "Jaina" and raptor.hops == 1)
	Check("[ECH] espèce nouvelle : au Codex, fiche de l'espèce créée, une espèce de plus",
		NS:SpecimenIsReference(ours.id) and NS:CaptureHas(950, true) and not NS:CaptureHas(950, false)
		and capture.creatures[950].name == "Ours givré" and capture.count == countBefore + 1)
	Check("[ECH] Raptor égal au Codex : en Réserve", not NS:SpecimenIsReference(raptor.id))
	Check("[ECH] Kodo meilleur que le Codex : reste en Réserve, marqué « meilleur »", not NS:SpecimenIsReference(kodo.id)
		and NS:SpecimenBetterThanCodex(kodo.id))
	Check("[ECH] Réserve : −2 + 2", NS:SpecimenReserveCount() == reserveBefore)
	local origin = NS:SpecimenOriginText(ours)
	Check("[ECH] origine affichée : « Échange avec Deklatis · Avant la 3.0 · Les Tarides · date », « … · Capturé par Jaina »",
		Has(origin, "Échange avec Deklatis") and Has(origin, "Avant la 3.0") and Has(origin, "Les Tarides")
		and Has(NS:SpecimenOriginText(raptor), "Échange avec Deklatis · Capturé par Jaina"), origin)
	local out = Mock:Output()
	Check("[ECH] chat : « Échange conclu avec Deklatis », l'espèce nouvelle, le meilleur que le Codex, sans ★ ni ☆",
		Has(out, "Échange conclu avec Deklatis") and Has(out, "rejoint ton Codex") and Has(out, "meilleur que ton spécimen du Codex")
		and not Has(out, "★") and not Has(out, "☆"), out)
	local log = NS:TradeLog()
	Check("[ECH] journal : une ligne (tid, joueur, donnés, reçus)", #log == 1 and log[1].tid == tid and log[1].peer == "Deklatis"
		and #log[1].gave == 2 and #log[1].got == 3 and log[1].result == "done" and capture.tradeCount == 1)
	Check("[ECH] hauts faits : un échange de plus (compte), une espèce jamais capturée reçue",
		X.feats.count.trades == 1 and X.feats.countScope == "account" and X.feats.flag.tradeNew == "account")
	-- idempotent : un F ou un K rejoué ne refait rien
	local n = 0
	for _ in pairs(capture.specimens) do n = n + 1 end
	X.Say("F", tid)
	X.Say("K", tid)
	local again = X.Take()
	local n2 = 0
	for _ in pairs(capture.specimens) do n2 = n2 + 1 end
	Check("[ECH] K rejoué après coup : F renvoyé (le journal répond), rien d'appliqué deux fois",
		n2 == n and X.Kinds(again) == "F" and #NS:TradeLog() == 1)
	X.Say("K", "inconnu")
	Check("[ECH] K d'un échange inconnu : N", X.Kinds(X.Take()) == "N")
	-- second échange sans espèce nouvelle : pas de drapeau
	Mock:Advance(11)
	X.feats.flag = {}
	tid = X.Open()
	local raw = X.PeerSpec({ i = 90, n = 903, s = 1, nm = "Grue" })
	X.PeerOffer(tid, 1, { raw })
	NS:TradeValidate()
	X.Say("V", tid, 1, 0)
	X.PeerLock(tid, { raw })
	X.Say("K", tid)
	Check("[ECH] un cadeau (rien de mon côté) : conclu, journal en tête, pas d'espèce nouvelle",
		Session() == nil and #NS:TradeLog() == 2 and NS:TradeLog()[1].tid == tid and #NS:TradeLog()[1].gave == 0
		and X.feats.flag.tradeNew == nil and X.feats.count.trades == 2)
	X.Done()
end

-- 6. Abandons ---------------------------------------------------------------------------------------------
do
	Say("-- qc30 échanges : abandons")
	X.Reset()
	local ids = X.ids
	local capture = NS:CaptureData()
	local function Ready(raws)
		local tid = X.Open()
		NS:TradeToggleOffer(ids.raptor2)
		X.PeerOffer(tid, 1, raws)
		NS:TradeValidate()
		X.Say("V", tid, 1, 1)
		X.Take()
		return tid
	end
	local raw = X.PeerSpec({ i = 77, n = 950, s = 2, nm = "Ours" })
	-- données différentes de l'offre affichée
	local tid = Ready({ raw })
	Mock:Reset()
	X.PeerLock(tid, { X.PeerSpec({ i = 77, n = 950, s = 3, nm = "Ours" }) })
	local x = X.Find(X.Take(), "X")
	Check("[ECH] données différentes de l'affiché : X~mismatch, rien de préparé ni de bougé", x and x[4] == "mismatch"
		and Session() == nil and capture.tradePending == nil and NS:SpecimenGet(ids.raptor2) ~= nil
		and Has(Mock:Output(), "ne correspondaient pas"))
	-- 30 s sans ses données
	Mock:Advance(11)
	tid = Ready({ raw })
	Mock:Advance(31); NS:TradeTick()
	x = X.Find(X.Take(), "X")
	Check("[ECH] 30 s sans ses données : X~timeout", x and x[4] == "timeout" and Session() == nil and capture.tradePending == nil)
	-- joueur introuvable (déconnecté)
	Mock:Advance(11)
	X.Open()
	Mock:Reset()
	NS:TradeOnEvent("CHAT_MSG_SYSTEM", "Aucun joueur nommé « Deklatis » n'est connecté.")
	Check("[ECH] « joueur introuvable » du client (motif tiré de son texte) : fin, le dire", Session() == nil
		and Has(Mock:Output(), "joueur introuvable")
		and NS.TradeNotFoundName("Aucun joueur nommé « Bob-Hyjal » n'est connecté.") == "Bob-Hyjal"
		and NS.TradeNotFoundName("autre chose") == nil)
	-- combat
	Mock:Advance(11)
	X.Open()
	NS:TradeOnEvent("PLAYER_REGEN_DISABLED")
	x = X.Find(X.Take(), "X")
	Check("[ECH] combat : X~combat, fin", x and x[4] == "combat" and Session() == nil)
	-- écran de chargement : envoyé tout de suite (hors file)
	Mock:Advance(11)
	X.Open()
	local before = #X.sent
	NS:TradeOnEvent("PLAYER_LEAVING_WORLD")
	Check("[ECH] écran de chargement : X~zoning envoyé sur-le-champ", #X.sent == before + 1 and X.sent[#X.sent].text:find("^X~1~.-~zoning$")
		and Session() == nil)
	X.Take()
	-- il abandonne
	Mock:Advance(11)
	tid = X.Open()
	Mock:Reset()
	X.Say("X", tid, "cancel")
	Check("[ECH] son abandon : fin, le dire", Session() == nil and Has(Mock:Output(), "Échange avec Deklatis annulé."))
	-- un de mes spécimens n'est plus échangeable au moment de verrouiller
	Mock:Advance(11)
	tid = X.Open()
	NS:TradeToggleOffer(ids.raptor2)
	X.PeerOffer(tid, 1, { raw })
	NS:TradeValidate()
	NS:SpecimenTake(ids.raptor2)
	X.Say("V", tid, 1, 1)
	x = X.Find(X.Take(), "X")
	Check("[ECH] mon spécimen a disparu entre-temps : X~missing", x and x[4] == "missing" and Session() == nil)
	-- 5 min sans rien
	Mock:Advance(11)
	X.Open()
	Mock:Advance(301); NS:TradeTick()
	Check("[ECH] 5 min sans rien dans la fenêtre : fin", Session() == nil)
	X.Done()
end

-- 7. /reload au milieu de l'engagement ---------------------------------------------------------------------
do
	Say("-- qc30 échanges : reprise après un /reload")
	X.Reset()
	local ids = X.ids
	local capture = NS:CaptureData()
	local raw = X.PeerSpec({ i = 77, n = 950, s = 2, nm = "Ours" })
	local function Prepared()
		local tid = X.Open()
		NS:TradeToggleOffer(ids.raptor2)
		X.PeerOffer(tid, 1, { raw })
		NS:TradeValidate()
		X.Say("V", tid, 1, 1)
		X.PeerLock(tid, { raw })
		X.Take()
		return tid
	end
	local tid = Prepared()
	Check("[ECH] préparé (journalisé), son K pas encore reçu", capture.tradePending and capture.tradePending.tid == tid)
	-- /reload : la session s'efface, la sauvegarde reste
	NS:TradeResetSession(); NS:TrainerResetSession()
	Check("[ECH] après le /reload : spécimen toujours réservé", select(2, NS:SpecimenCanRelease(ids.raptor2)) == "locked")
	NS:TradeOnEvent("PLAYER_ENTERING_WORLD")
	local s = Session()
	Check("[ECH] reprise : session « en suspens » retrouvée", s and s.recovered and s.phase == "prepared" and s.tid == tid)
	NS:TradeTick()
	local k = X.Find(X.Take(), "K")
	Check("[ECH] K renvoyé (question à l'autre)", k and k[3] == tid and k.target == PEER)
	Mock:Advance(2); NS:TradeTick()
	local early = #X.Take() == 0
	Mock:Advance(4); NS:TradeTick()
	Check("[ECH] … pas avant 5 s, puis toutes les 5 s", early and X.Kinds(X.Take()) == "K")
	Check("[ECH] « joueur introuvable » masqué pendant la reprise", NS:TradeChatFilter("Aucun joueur nommé « Deklatis » n'est connecté.") == true
		and NS:TradeChatFilter("Aucun joueur nommé « Oscar » n'est connecté.") == false)
	Mock:Reset()
	X.Say("F", tid)
	Check("[ECH] il avait conclu (F) : on conclut, une seule fois", capture.tradePending == nil and NS:SpecimenGet(ids.raptor2) == nil
		and #NS:TradeLog() == 1 and Session() == nil and Has(Mock:Output(), "L'échange en suspens avec Deklatis est conclu."))
	X.Say("F", tid)
	local n = 0
	for _, spec in pairs(capture.specimens) do if spec.npc == 950 then n = n + 1 end end
	Check("[ECH] F rejoué : rien de doublé", n == 1 and #NS:TradeLog() == 1)
	-- il n'en a aucune trace (il n'a pas conclu) : abandon, rien ne bouge
	Mock:Advance(11)
	X.Reset()
	ids = X.ids
	capture = NS:CaptureData()
	tid = Prepared()
	NS:TradeResetSession(); NS:TrainerResetSession()
	NS:TradeOnEvent("PLAYER_ENTERING_WORLD")
	NS:TradeTick()
	X.Take()
	Mock:Reset()
	X.Say("N", tid)
	Check("[ECH] réponse N (aucune trace) : en suspens annulé, mes spécimens restent", capture.tradePending == nil
		and NS:SpecimenGet(ids.raptor2) ~= nil and NS:SpecimenCanTrade(ids.raptor2) == true and Session() == nil
		and NS:TradeLog()[1].result == "aborted" and Has(Mock:Output(), "rien n'a bougé"))
	X.Say("K", tid)
	Check("[ECH] … et un K de lui ensuite : X (le journal dit « abandonné »)", X.Kinds(X.Take()) == "X")
	-- il est prêt aussi (K) : on conclut
	Mock:Advance(11)
	tid = Prepared()
	NS:TradeResetSession(); NS:TrainerResetSession()
	NS:TradeOnEvent("PLAYER_ENTERING_WORLD")
	X.Say("K", tid)
	Check("[ECH] reprise, son K : conclu, F", capture.tradePending == nil and NS:SpecimenGet(ids.raptor2) == nil
		and X.Find(X.Take(), "F") ~= nil)
	-- son K arrive avant même la reprise (session pas encore refaite) : conclu, F quand même
	Mock:Advance(11)
	local savedRaptor = ids.raptor2
	ids.raptor2 = NS:SpecimenAdd({ npc = 900, stars = 2, name = "Raptor", trait = "curious", size = "normal", origin = "capture" })
	local tid2 = Prepared()
	NS:TradeResetSession(); NS:TrainerResetSession()
	X.Say("K", tid2)
	Check("[ECH] son K avant la reprise : conclu, F envoyé", capture.tradePending == nil and NS:SpecimenGet(ids.raptor2) == nil
		and X.Find(X.Take(), "F") ~= nil)
	ids.raptor2 = savedRaptor
	-- /reload après la conclusion : rien à reprendre ; son K : F
	NS:TradeResetSession(); NS:TrainerResetSession()
	NS:TradeOnEvent("PLAYER_ENTERING_WORLD")
	Check("[ECH] /reload après coup : rien en suspens", Session() == nil)
	X.Say("K", tid)
	Check("[ECH] … son K (il n'a pas reçu notre F) : F renvoyé", X.Kinds(X.Take()) == "F")
	-- en suspens qui ne revient jamais : abandon après 7 jours seulement
	Mock:Advance(11)
	X.Reset()
	ids = X.ids
	capture = NS:CaptureData()
	tid = Prepared()
	NS:TradeResetSession(); NS:TrainerResetSession()
	NS:TradeOnEvent("PLAYER_ENTERING_WORLD")
	Check("[ECH] en suspens : pas de nouvel échange", select(2, NS:TradeInvite("Oscar")) == "pending"
		or select(2, NS:TradeInvite("Oscar")) == "busy")
	Check("[ECH] Abandonner avant 7 jours : refusé", select(2, NS:TradeAbandon()) == "doubt" and capture.tradePending ~= nil)
	X.now = X.now + 8 * 86400
	Check("[ECH] après 7 jours : abandonné, mes spécimens restent", NS:TradeAbandon() == true and capture.tradePending == nil
		and NS:SpecimenGet(ids.raptor2) ~= nil and NS:TradeLog()[1].result == "aborted")
	X.Done()
end

-- 8. Journal (50 au plus), commandes, menu -----------------------------------------------------------------
do
	Say("-- qc30 échanges : journal, commandes, menu")
	X.Reset()
	local capture = NS:CaptureData()
	capture.tradeLog = {}
	for index = 1, 50 do capture.tradeLog[index] = { tid = "old" .. index, at = X.now, peer = "Bob", gave = {}, got = {}, result = "done" } end
	local tid = X.Open()
	local raw = X.PeerSpec({ i = 77, n = 903, s = 1, nm = "Grue" })
	X.PeerOffer(tid, 1, { raw })
	NS:TradeValidate()
	X.Say("V", tid, 1, 0)
	X.PeerLock(tid, { raw })
	X.Say("K", tid)
	Check("[ECH] journal : 50 lignes au plus, la plus récente en tête", #NS:TradeLog() == 50 and NS:TradeLog()[1].tid == tid
		and NS:TradeLog()[50].tid == "old49")
	Mock:Advance(11)
	NS:HandleCommand("echange Deklatis")
	local invited = Session() and Session().phase == "inviting" and Session().peer == PEER
	NS:HandleCommand("echange annuler")
	Check("[ECH] /qc echange <nom> : invitation ; /qc echange annuler", invited and Session() == nil)
	Mock:Advance(11)
	X.Say("I", "c1", "3.0.0", ME_KEY)
	NS:HandleCommand("trade yes")
	local accepted = Session() and Session().phase == "open"
	NS:HandleCommand("trade cancel")
	Mock:Advance(11)
	X.Say("I", "c2", "3.0.0", ME_KEY)
	NS:HandleCommand("echange non")
	Check("[ECH] /qc trade yes : accepté ; /qc echange non : refusé", accepted and Session() == nil
		and X.Find(X.Take(), "D")[4] == "no")
	local help = false
	for _, section in ipairs(NS.HELP) do for _, key in ipairs(section[2]) do if key == "HELP_TRADE" then help = true end end end
	Check("[ECH] aide et visite guidée (étape Réserve) : /qc echange <nom>", help and Has(NS.L.HELP_TRADE, "/qc echange <nom>")
		and Has(NS.L.TOUR_B_reserve, "/qc echange <nom>"))
	-- menu du clic droit : après la fiche de dresseur, détenteurs connus
	local root = { buttons = {} }
	function root:CreateDivider() end
	function root:CreateButton(text, fn) self.buttons[#self.buttons + 1] = { text = text, fn = fn } end
	NS:TrainerMarkHolder(PEER)
	NS:TrainerMenuAdd(root, { name = "Deklatis" })
	local entry = #root.buttons == 2 and root.buttons[2].text == "Proposer un échange"
	Mock:Advance(11)
	root.buttons[2].fn()
	Check("[ECH] menu : « Proposer un échange » sous la fiche ; clic : invitation", entry and Session() and Session().peer == PEER)
	NS:TradeCancel()
	-- textes et hauts faits
	local fr, en = NS.TRADE_STRINGS.fr, NS.TRADE_STRINGS.en
	local missing = {}
	for key in pairs(fr) do if en[key] == nil then missing[#missing + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	for key, text in pairs(fr) do if Has(text, "★") or Has(text, "☆") then missing[#missing + 1] = "★:" .. key end end
	for key, text in pairs(en) do if Has(text, "★") or Has(text, "☆") then missing[#missing + 1] = "★:" .. key end end
	Check("[ECH] textes FR/EN au complet, aucun ★/☆", #missing == 0, table.concat(missing, ", "))
	local one, ten, new = NS:FeatDef("soc_trade_1"), NS:FeatDef("soc_trade_10"), NS:FeatDef("soc_trade_new")
	Check("[ECH] hauts faits : Guilde et entraide, compte, codes 178 à 180, critères, noms et descriptions",
		one and ten and new and one.cat == "soc" and one.scope == "account" and one.n == 178 and ten.n == 179 and new.n == 180
		and one.pts == 5 and ten.pts == 10 and new.pts == 10 and one.crit[1] == "streak" and one.crit[2] == "trades"
		and one.crit[3] == 1 and ten.crit[3] == 10 and new.crit[1] == "flag" and new.crit[2] == "tradeNew"
		and NS.L.FEAT_soc_trade_1 == "Premier échange" and NS.L.FEAT_soc_trade_10 == "Marchand de créatures"
		and NS.L.FEAT_soc_trade_new == "Venu d'ailleurs" and NS:FeatDescription(ten) == "Conclure 10 échanges de spécimens avec d'autres joueurs"
		and NS:FeatDescription(one) == "Conclure un échange de spécimens avec un autre joueur")
	local root2 = rawget(_G, "ADDON_ROOT") or "."
	local h = io.open(root2 .. "/docs/QC-HAUTS-FAITS.md", "rb")
	local doc = h and h:read("*a") or ""
	if h then h:close() end
	Check("[ECH] documentés (docs/QC-HAUTS-FAITS.md)", Has(doc, "`soc_trade_1` (code 178)") and Has(doc, "`soc_trade_10` (code 179)")
		and Has(doc, "`soc_trade_new` (code 180)") and Has(doc, "**180 lignes**"))
	X.Done()
end

-- 9. La vue « Échanges », dans les deux styles ------------------------------------------------------------------
do
	Say("-- qc30 échanges : la vue Échanges")
	for _, style in ipairs({ "sobre", "azeroth" }) do
		X.Reset(style)
		local ids = X.ids
		NS:OpenReserve("trade")
		local f = NS.journalFrame
		local pane = f and f.res
		local tv = pane and pane.trade
		Check("[ECH] " .. style .. " : puce « Échanges », vue montrée", tv and tv:IsShown() and f.resView == "trade"
			and not pane.reserve:IsShown() and pane.views.byId and pane.views.byId.trade ~= nil)
		-- la page Réserve a son bouton « Échanger avec ma cible »
		Check("[ECH] " .. style .. " : sans échange : intro, bouton cible (ici et dans la vue Réserve), historique vide",
			tv.status:GetText() == "Aucun échange en cours." and Has(tv.note:GetText(), "/qc echange <nom>") and tv.target:IsShown()
			and tv.histEmpty:IsShown() and not tv.validate:IsShown() and not tv.cols.mine.head:IsShown()
			and pane.reserve.tradeButton and pane.reserve.tradeButton:GetText() == "Échanger avec ma cible")
		-- invitation reçue : Accepter / Refuser dans la page
		X.Say("I", "u1", "3.0.0", ME_KEY)
		Check("[ECH] " .. style .. " : invitation : Accepter / Refuser dans la page", tv.accept:IsShown() and tv.decline:IsShown()
			and Has(tv.status:GetText(), "Deklatis te propose un échange"))
		tv.accept:GetScript("OnClick")(tv.accept)
		X.Take()
		local s = Session()
		Check("[ECH] " .. style .. " : accepté : la fenêtre d'échange", s.phase == "open" and tv.validate:IsShown()
			and tv.cols.mine.head:GetText() == "Toi (Testeur)" and tv.cols.theirs.head:GetText() == "Deklatis"
			and not tv.histEmpty:IsShown())
		-- la grille : la Réserve, l'inéligible grisé
		local pick, better
		for _, tile in ipairs(tv.picks) do
			if tile:IsShown() and tile.tradeSpec and tile.tradeSpec.id == ids.raptor2 then pick = tile end
			if tile:IsShown() and tile.tradeSpec and tile.tradeSpec.id == ids.kodo3 then better = tile end
		end
		Check("[ECH] " .. style .. " : grille de la Réserve, le meilleur que le Codex grisé avec sa raison", pick and better
			and better.why == "better" and better.pickable == false and pick.pickable == true)
		pick:GetScript("OnClick")(pick)
		Check("[ECH] " .. style .. " : clic : proposé, dans ma colonne", #s.mine == 1 and tv.cols.mine.tiles[1]:IsShown()
			and tv.cols.mine.tiles[1].tradeSpec.id == ids.raptor2 and not tv.cols.mine.slots[1].plus:IsShown()
			and tv.cols.mine.slots[2].plus:IsShown() and pick.offered)
		X.PeerOffer(s.tid, 1, { X.PeerSpec({ i = 77, n = 950, s = 2, h = true, nm = "Ours givré", z = "giant" }) })
		local theirTile = tv.cols.theirs.tiles[1]
		Check("[ECH] " .. style .. " : son offre affichée : nom, étoiles, perle, taille", theirTile:IsShown()
			and theirTile.label:GetText() == "Ours givré" and theirTile.stars[2].full and not theirTile.stars[3].full
			and theirTile.gem:IsShown() and theirTile.sizeTag:IsShown())
		local pending = tv.cols.mine.state:GetText() == "Pas encore validé" and tv.validate.qcEnabled ~= false
		tv.validate:GetScript("OnClick")(tv.validate)
		Check("[ECH] " .. style .. " : « Pas encore validé », puis Valider : « Validé », bouton grisé", pending and s.myValid
			and tv.cols.mine.state:GetText() == "Validé"
			and tv.validate.qcEnabled == false and Has(tv.status:GetText(), "en attente de sa validation"))
		-- infobulle de sa vignette : origine et « nouvelle espèce »
		local tipped
		local ui = NS.JournalUI
		local tip = ui.Tip
		ui.Tip = function(_, title, lines) tipped = { title = title, lines = lines } end
		theirTile.onEnter(theirTile)
		ui.Tip = tip
		local tipText = tipped and table.concat(tipped.lines, "\n") or ""
		Check("[ECH] " .. style .. " : infobulle : capturé par, zone, nouvelle espèce", Has(tipText, "Capturé par Thrall")
			and Has(tipText, "Les Tarides") and Has(tipText, "Nouvelle espèce pour toi"), tipText)
		if style == "azeroth" then
			NS:RefreshJournal()
			Check("[ECH] azeroth : encres trade.* et reserve.*, aucun rôle manquant", tv.status.azRole == "trade.status"
				and tv.cols.mine.head.azRole == "trade.head" and tv.cols.mine.state.azRole == "trade.ok"
				and tv.cols.theirs.state.azRole == "trade.state" and theirTile.label.azRole == "reserve.shiny"
				and tv.cols.mine.slots[2].plus.azRole == "trade.slot" and pick.label.azRole == "reserve.name"
				and NS.carnetInkMisses == nil, table.concat(NS.carnetInkMisses or {}, ", "))
		end
		local before = #Mock.frames
		NS:RefreshJournal(); NS:RefreshJournal()
		Check("[ECH] " .. style .. " : rafraîchi sans rien créer", #Mock.frames == before, #Mock.frames .. "/" .. before)
		NS:TradeCancel()
		X.Take()
		Check("[ECH] " .. style .. " : annulé : retour à l'historique", not tv.validate:IsShown() and tv.target:IsShown())
		-- historique
		NS:CaptureData().tradeLog = { { tid = "h1", at = X.now, peer = "Jaina", result = "done",
			gave = { { npc = 900, stars = 2, name = "Raptor" } }, got = { { npc = 950, stars = 3, shiny = true, name = "Ours givré" } } } }
		NS:RefreshJournal()
		local row = tv.hist[1]
		Check("[ECH] " .. style .. " : historique : date, joueur, donné, reçu", row.line:IsShown() and Has(row.line:GetText(), "avec Jaina")
			and Has(row.sub:GetText(), "Donné : Raptor") and Has(row.sub:GetText(), "Reçu : Ours givré") and not tv.histEmpty:IsShown())
		local inked = style ~= "azeroth" or (row.line.azRole == "trade.histName" and row.sub.azRole == "trade.histText"
			and tv.histHead.label.azRole == "section.label" and NS.carnetInkMisses == nil)
		Check("[ECH] " .. style .. " : aucune erreur (azeroth : historique encré, aucun rôle manquant)", next(NS.errors or {}) == nil
			and inked, table.concat(NS.carnetInkMisses or {}, ", "))
		X.Done()
	end
	-- contraste : rôles mesurés (Azeroth), jetons du socle sur la fenêtre (Sobre)
	local bad = {}
	for _, role in ipairs({ "trade.status", "trade.head", "trade.state", "trade.ok", "trade.histName", "trade.histText", "trade.slot" }) do
		local r = NS.AZEROTH_CONTRAST[role]
		local ratio = r and NS.AzerothContrast(INK[r[1]], r[2]) or 0
		if not r or ratio < r[3] then bad[#bad + 1] = role .. string.format(" %.2f", ratio) end
	end
	Check("[ECH] azeroth : rôles trade.* au-dessus du seuil, sur les fonds repris des surfaces mesurées", #bad == 0
		and NS.AZEROTH_CONTRAST["trade.status"][2] == NS.AZEROTH_CONTRAST["reserve.text"][2]
		and NS.AZEROTH_CONTRAST["trade.slot"][2] == NS.AZEROTH_CONTRAST["reserve.name"][2], table.concat(bad, ", "))
	local Th = NS.Theme
	local bg = NS.AzerothLuminance(Th.WINDOW)
	local low, lowName = 99, ""
	for _, key in ipairs({ "LABEL", "MUTED_LIGHT", "GOLD", "GREEN", "TEXT" }) do
		local ratio = NS.AzerothContrast(Th[key], bg)
		if ratio < low then low, lowName = ratio, key end
	end
	Check("[ECH] sobre : textes de la vue ≥ 4,5:1 sur Theme.WINDOW", low >= 4.5, lowName .. string.format("=%.2f", low))
end
