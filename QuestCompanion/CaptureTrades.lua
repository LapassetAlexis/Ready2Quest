-- CaptureTrades.lua -- échanges de spécimens entre joueurs (QuestCompanion 3.0.0)
--
-- 3.0.0 : deux joueurs en ligne qui ont QuestCompanion 3.0 (ou plus) échangent
-- jusqu'à TRADE_MAX spécimens de leur Réserve chacun (CaptureSpecimens.lua).
-- Lancer : /qc echange <nom> (EN /qc trade <name>), « Proposer un échange »
-- dans le menu du clic droit sur un joueur (mêmes menus que la fiche de
-- dresseur, Menu.ModifyMenu : l'API prévue par le client, sans souillure ;
-- rien sur un client sans Menu, l'ancien UnitPopup souillerait), ou le bouton
-- « Échanger avec ma cible » de la page Réserve. La fenêtre d'échange est la
-- vue « Échanges » de la page Réserve du carnet (JournalReserve.lua) : deux
-- colonnes « Toi » / « <nom> » de 3 places, la Réserve en dessous (clic :
-- proposer ou retirer), Valider / Annuler ; sans échange en cours :
-- l'invitation reçue (Accepter / Refuser) et l'historique des échanges.
--
-- Spécimens échangeables (ns:SpecimenCanTrade) : ceux de la RÉSERVE seulement.
-- Jamais une référence du Codex (donc jamais l'apparence portée, ni le
-- dernier exemplaire d'une version), jamais un spécimen meilleur que sa
-- référence (comme relâcher : « Mets-le au Codex avant »), jamais un
-- spécimen déjà engagé dans un échange (verrou : ni relâché, ni mis au Codex).
-- Place : (reçus qui iront en Réserve) − (donnés) ≤ places libres. Un reçu
-- d'une version que tu n'as pas encore devient sa référence au Codex ; sinon
-- il va en Réserve, même meilleur que ton Codex (marqué « Meilleur que ton
-- spécimen du Codex » : à toi de choisir « Mettre au Codex »).
--
-- Canal : chuchotement d'addon (WHISPER), préfixe « QCTrade », par la file
-- et le débit de la fiche de dresseur (TrainerCard.lua, ns:ChatQueue).
-- Faction : un client de type Classic ne chuchote pas à l'autre faction
-- (pas même un message d'addon) et n'y fait pas de groupe ; un échange entre
-- Horde et Alliance est donc impossible, la cible d'en face est refusée
-- d'avance, et un nom inconnu tombe sur « joueur introuvable ». Pas de repli
-- sur le canal de groupe : un groupe est toujours de la même faction (le
-- chuchotement y marche) et le canal diffuserait l'échange à tout le groupe.
--
-- ===========================================================================
-- PROTOCOLE (TRADE_PROTO = 1). Message : « type~proto~tid~… », champs échappés
-- (ns.TrainerEscape) ; tid = numéro d'échange tiré par celui qui invite. Un
-- type inconnu est ignoré ; un proto d'une autre génération : refus "version".
--   I~1~tid~version~clé   invitation (clé du destinataire : un message égaré
--                         chez un autre est ignoré)
--   R~1~tid~version       invitation reçue et affichée (le destinataire a la 3.0)
--   A~1~tid               acceptée            D~1~tid~raison   refusée
--   O~1~tid~rév~i~n~spéc  offre : morceau i sur n de la révision « rév » de
--                         l'offre de l'expéditeur (n = 0 : offre vide)
--   V~1~tid~sienne~mienne validation : révisions vues des deux offres ; toute
--                         nouvelle offre remet les deux validations à zéro
--   L~1~tid~i~n~spéc      phase 1 : les données complètes de ce qu'on donne
--   K~1~tid               « prêt » (vote oui, journalisé) ; sert aussi de
--                         question après un /reload : réponse K, F, X ou N
--   F~1~tid               échange conclu chez l'expéditeur
--   X~1~tid~raison        abandon (jamais après un K)
--   N~1~tid               inconnu (aucune trace de ce tid)
-- spéc = ns.TrainerEncode{ i (id chez l'expéditeur), n, s, h, z, t, zo, at,
-- by, o (origine première), nm, cl, ty, fa, hp (échanges déjà subis) }.
--
-- Phases : inviting / invited -> open -> locking -> prepared -> fini.
--   * open : chacun compose son offre (O) et valide (V) ; Valider vérifie la
--     place. Les deux validés sur les mêmes révisions : locking.
--   * locking : chacun revérifie ses spécimens et sa place, envoie L. À la
--     réception des L de l'autre : comparaison EXACTE avec l'offre affichée
--     (sinon X "mismatch"), puis PRÉPARÉ : l'échange est écrit dans la
--     sauvegarde (capture.tradePending : donnés, reçus) et K part.
--   * prepared : à la réception d'un K (ou d'un F) de l'autre : ENGAGEMENT,
--     d'un seul bloc Lua (rien ne s'intercale, pas même une sauvegarde) :
--     les donnés quittent la Réserve, les reçus arrivent (ids neufs, origine
--     « Échange avec X », `by` d'origine gardé, tradedFrom, tradedAt), une
--     ligne au journal (capture.tradeLog, 50 au plus, avec le tid),
--     tradePending effacé ; puis F part.
-- Règles de sûreté : on ne vote K qu'une fois l'échange journalisé ; on
-- n'envoie jamais X après K ; on n'engage qu'après le K (ou F) de l'autre.
-- Donc : abandon avant K des deux côtés = rien ne bouge ; X ou N reçu en
-- préparé = l'autre n'a pas engagé, on abandonne aussi.
-- Reprise (/reload, déconnexion) : tradePending survit ; à la connexion, K
-- repart (toutes les 5 s, 6 fois, puis toutes les 2 min). Réponses : F (il a
-- engagé : on engage), K (il est prêt aussi : on engage), X ou N (il n'a pas
-- engagé : on abandonne). Un K reçu d'un échange déjà conclu : F renvoyé ;
-- abandonné : X ; inconnu : N. Le journal (tid) rend tout cela idempotent :
-- un échange n'est jamais appliqué deux fois.
-- Reste un cas sans issue sûre : l'autre ne revient jamais. Au bout de
-- TRADE_DOUBT_ABANDON (7 jours), « Abandonner » garde tes spécimens chez toi.
-- (Un client qui plante après l'engagement perd sa session, échange compris,
-- comme toute autre partie non sauvegardée : le jeu n'écrit la sauvegarde
-- qu'à la déconnexion ou au /reload.)
-- Abandon (X) avant K : Annuler, combat, écran de chargement, 60 s sans
-- réponse à l'invitation, 5 min sans rien dans la fenêtre, 30 s en locking,
-- joueur introuvable (message système du client), données différentes.
-- Anti-abus (léger) : un échange à la fois, TRADE_COOLDOWN s entre deux, pas
-- avec soi-même (même nom ; les personnages d'un compte partagent déjà la
-- collection), plafond de messages reçus par joueur.
-- ===========================================================================
-- API
--   ns:SpecimenCanTrade(id) -> true | false, raison ("missing"|"reference"|
--       "worn"|"better"|"locked")
--   ns:TradeInvite(nom) / ns:TradeWithTarget() / ns:TradeAccept() /
--   ns:TradeDecline() / ns:TradeCancel() / ns:TradeAbandon()
--   ns:TradeToggleOffer(id) -> true (ajouté) | false (retiré) | nil, raison
--   ns:TradeValidate() -> true | nil, raison
--   ns:TradeSession() -> la session (lecture), nil sans échange
--   ns:TradeLog() -> journal (le plus récent d'abord)
--   ns:TradeRoom() -> places manquantes (0 : ça tient)
--   ns:TradeOnAddonMessage(prefix, texte, canal, expéditeur)
--   ns:TradeTick(now) (horloge, 1 s), ns:TradeOnEvent(event, …)
-- Hauts faits : soc_trade_1, soc_trade_10 (compteur "trades"), soc_trade_new
-- (drapeau "tradeNew" : une espèce jamais capturée reçue). FeatsCatMenagerie.lua.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.TRADE_PREFIX = "QCTrade"          -- 16 caractères au plus
ns.TRADE_PROTO = 1
ns.TRADE_MAX = 3                     -- spécimens de chaque côté
ns.TRADE_INVITE_TTL = 60             -- s pour accepter
ns.TRADE_RING_WAIT = 10              -- s sans accusé : pas de QuestCompanion 3.0 en face
ns.TRADE_IDLE_TTL = 300              -- s sans rien dans la fenêtre : abandon
ns.TRADE_LOCK_TTL = 30               -- s pour recevoir les données de l'autre
ns.TRADE_COOLDOWN = 10               -- s entre deux échanges
ns.TRADE_RESEND = { 5, 6, 120 }      -- K préparé : toutes les 5 s, 6 fois, puis toutes les 2 min
ns.TRADE_DOUBT_ABANDON = 7 * 86400   -- s avant de pouvoir abandonner un échange en suspens
ns.TRADE_LOG_MAX = 50
ns.TRADE_IN_WINDOW, ns.TRADE_IN_MAX = 10, 60   -- messages reçus d'un joueur par fenêtre
ns.TRADE_TEXT_MAX = { nm = 48, by = 36, ty = 24, fa = 24 }   -- octets gardés d'un texte reçu
ns.TRADE_CLASSES = { trivial = true, minus = true, normal = true, elite = true, rare = true, rareelite = true,
	worldboss = true }
ns.TRADE_ORIGINS = { capture = true, migration = true, gift3 = true }
-- vue « Échanges » : places, grille de la Réserve, historique
ns.TRADE_LAYOUT = { histRow = 36, histGap = 2, slotGap = 7, stateX = 6 }

local FR = {
	TRADE_MENU            = "Proposer un échange",
	TRADE_TITLE           = "Échanges",
	TRADE_SUB             = "Échange jusqu'à 3 spécimens de ta Réserve avec un autre dresseur qui a QuestCompanion 3.0.",
	TRADE_INTRO           = "Avec un joueur en ligne de ta faction : /qc echange <nom>, clic droit sur son portrait (« Proposer un échange »), ou cible-le et clique ci-dessous. Jusqu'à 3 spécimens de ta Réserve de chaque côté ; les deux valident.",
	TRADE_YOU             = "Toi (%s)",
	TRADE_STATE_VALID     = "Validé",
	TRADE_STATE_WAIT      = "Pas encore validé",
	TRADE_STATE_LOCK      = "Vérification…",
	TRADE_STATE_DONE      = "Prêt",
	TRADE_VALIDATE        = "Valider",
	TRADE_VALIDATED       = "Validé",
	TRADE_CANCEL          = "Annuler l'échange",
	TRADE_ACCEPT          = "Accepter",
	TRADE_DECLINE         = "Refuser",
	TRADE_ABANDON         = "Abandonner",
	TRADE_PICK_HEAD       = "Ta Réserve : clic pour proposer ou retirer un spécimen (%d / %d)",
	TRADE_PICK_HINT       = "Le compagnon porté, le Codex et un spécimen meilleur que ton Codex ne s'échangent pas.",
	TRADE_PICK_EMPTY      = "Ta Réserve est vide : rien à proposer pour l'instant (tu peux quand même recevoir).",
	TRADE_SLOT            = "+",
	TRADE_HIST_HEAD       = "Historique des échanges",
	TRADE_HIST_EMPTY      = "Aucun échange pour l'instant.",
	TRADE_HIST_LINE       = "%s · avec %s",
	TRADE_HIST_ABORT      = "%s · avec %s · abandonné",
	TRADE_HIST_GAVE       = "Donné : %s",
	TRADE_HIST_GOT        = "Reçu : %s",
	TRADE_HIST_NONE       = "rien",
	TRADE_HIST_SEP        = " · ",
	TRADE_LIST_SEP        = ", ",
	TRADE_ST_INVITING     = "Invitation envoyée à %s…",
	TRADE_ST_RUNG         = "%s a reçu ton invitation : en attente de sa réponse (%d s).",
	TRADE_ST_INVITED      = "%s te propose un échange de spécimens (%d s).",
	TRADE_ST_OPEN         = "Échange avec %s : compose ton offre, puis valide.",
	TRADE_ST_WAIT_THEM    = "Échange avec %s : tu as validé, en attente de sa validation.",
	TRADE_ST_WAIT_YOU     = "Échange avec %s : il a validé, à toi.",
	TRADE_ST_LOCK         = "Échange avec %s : vérification des deux offres…",
	TRADE_ST_PREPARED     = "Échange avec %s : tout est prêt, conclusion en cours…",
	TRADE_ST_DOUBT        = "Échange avec %s en suspens : il se conclut dès que vous êtes tous deux en ligne. Tes spécimens proposés restent réservés.",
	TRADE_ST_DOUBT_OLD    = "Échange avec %s en suspens depuis plus de 7 jours : « Abandonner » garde tes spécimens chez toi.",
	TRADE_ST_IDLE         = "Aucun échange en cours.",
	TRADE_MSG_INVITE      = "Invitation à l'échange envoyée à %s.",
	TRADE_MSG_INVITED     = "%s te propose un échange de spécimens : /qc echange oui ou /qc echange non (60 s), ou carnet › Réserve › Échanges.",
	TRADE_MSG_OPEN        = "Échange ouvert avec %s : carnet › Réserve › Échanges.",
	TRADE_MSG_DONE        = "Échange conclu avec %s. Donné : %s. Reçu : %s.",
	TRADE_MSG_BETTER      = "%s est meilleur que ton spécimen du Codex : il t'attend dans la Réserve (« Mettre au Codex »).",
	TRADE_MSG_NEW         = "%s rejoint ton Codex : une espèce de plus !",
	TRADE_MSG_RECOVERED   = "L'échange en suspens avec %s est conclu.",
	TRADE_MSG_DOUBT_END   = "L'échange en suspens avec %s est annulé : rien n'a bougé.",
	TRADE_MSG_ABANDONED   = "Échange avec %s abandonné : tes spécimens restent chez toi.",
	TRADE_MSG_TARGET      = "Cible d'abord le joueur avec qui échanger.",
	TRADE_ERR_self        = "Tu ne peux pas échanger avec toi-même (tes personnages partagent déjà la collection).",
	TRADE_ERR_busy        = "Un échange est déjà en cours : termine-le ou annule-le d'abord.",
	TRADE_ERR_pending     = "Un échange avec %s est en suspens : il doit d'abord se conclure.",
	TRADE_ERR_cooldown    = "Patiente encore %d s avant un nouvel échange.",
	TRADE_ERR_combat      = "Pas d'échange en combat.",
	TRADE_ERR_off         = "La capture est coupée dans les réglages : pas d'échange.",
	TRADE_ERR_name        = "Donne le nom d'un joueur : /qc echange <nom>.",
	TRADE_ERR_faction     = "Échange impossible avec l'autre faction : le client ne laisse pas les messages passer entre Horde et Alliance.",
	TRADE_ERR_full        = "Ta Réserve n'aura pas la place : il manque %d place(s). Relâche des spécimens ou ajoute des places à l'Échoppe.",
	TRADE_ERR_max         = "3 spécimens au plus de chaque côté.",
	TRADE_ERR_empty       = "Propose ou attends au moins un spécimen avant de valider.",
	TRADE_ERR_doubt       = "L'échange n'est pas encore vieux de 7 jours : patiente, il se conclura dès que vous serez tous deux en ligne.",
	TRADE_END_no          = "%s a refusé l'échange.",
	TRADE_END_busy        = "%s est déjà occupé (un autre échange, ou il vient d'en finir un) : réessaie dans un moment.",
	TRADE_END_off         = "%s a coupé la capture : pas d'échange possible.",
	TRADE_END_combat      = "Échange avec %s annulé : combat.",
	TRADE_END_zoning      = "Échange avec %s annulé : écran de chargement.",
	TRADE_END_timeout     = "Échange avec %s annulé : pas de réponse à temps.",
	TRADE_END_invite_timeout = "%s n'a pas répondu à ton invitation (60 s).",
	TRADE_END_cancel      = "Échange avec %s annulé.",
	TRADE_END_mismatch    = "Échange avec %s annulé : les données reçues ne correspondaient pas à ce qui était affiché. Rien n'a bougé.",
	TRADE_END_missing     = "Échange avec %s annulé : un spécimen proposé n'est plus échangeable.",
	TRADE_END_full        = "Échange avec %s annulé : une Réserve n'avait plus la place.",
	TRADE_END_version     = "Échange avec %s impossible : vos versions de QuestCompanion ne se comprennent pas (mettez-vous à jour tous les deux).",
	TRADE_END_offline     = "Échange avec %s annulé : joueur introuvable (hors ligne, autre faction ou autre royaume).",
	TRADE_END_unknown     = "Échange avec %s annulé : il n'en a aucune trace.",
	TRADE_END_noanswer    = "Pas de réponse de %s : hors ligne, de l'autre faction, ou sans QuestCompanion 3.0 (les échanges demandent la 3.0 des deux côtés).",
	TRADE_END_oldaddon    = "%s a QuestCompanion, mais une version d'avant la 3.0 : les échanges demandent la 3.0 des deux côtés.",
	TRADE_END_self        = "Échange refusé : c'est ton propre nom.",
	TRADE_TIP_NEW         = "Nouvelle espèce pour toi !",
	TRADE_TIP_NEW_VERSION = "Version que tu n'as pas encore : elle ira au Codex.",
	TRADE_TIP_BETTER      = "Meilleur que ton spécimen du Codex : il ira dans ta Réserve.",
	TRADE_TIP_REMOVE      = "Clic : le retirer de l'offre.",
	TRADE_TIP_ADD         = "Clic : le proposer.",
	HELP_TRADE            = "/qc echange <nom> | oui | non | annuler -- échanger des spécimens avec un joueur",
}
local EN = {
	TRADE_MENU            = "Offer a trade",
	TRADE_TITLE           = "Trades",
	TRADE_SUB             = "Trade up to 3 specimens from your Reserve with another trainer who has QuestCompanion 3.0.",
	TRADE_INTRO           = "With an online player of your faction: /qc trade <name>, right-click their portrait (\"Offer a trade\"), or target them and click below. Up to 3 specimens from your Reserve on each side; both of you confirm.",
	TRADE_YOU             = "You (%s)",
	TRADE_STATE_VALID     = "Confirmed",
	TRADE_STATE_WAIT      = "Not confirmed yet",
	TRADE_STATE_LOCK      = "Checking…",
	TRADE_STATE_DONE      = "Ready",
	TRADE_VALIDATE        = "Confirm",
	TRADE_VALIDATED       = "Confirmed",
	TRADE_CANCEL          = "Cancel the trade",
	TRADE_ACCEPT          = "Accept",
	TRADE_DECLINE         = "Decline",
	TRADE_ABANDON         = "Give up",
	TRADE_PICK_HEAD       = "Your Reserve: click to offer or take back a specimen (%d / %d)",
	TRADE_PICK_HINT       = "Your worn companion, the Codex and a specimen better than your Codex can't be traded.",
	TRADE_PICK_EMPTY      = "Your Reserve is empty: nothing to offer for now (you can still receive).",
	TRADE_SLOT            = "+",
	TRADE_HIST_HEAD       = "Trade history",
	TRADE_HIST_EMPTY      = "No trades yet.",
	TRADE_HIST_LINE       = "%s · with %s",
	TRADE_HIST_ABORT      = "%s · with %s · given up",
	TRADE_HIST_GAVE       = "Gave: %s",
	TRADE_HIST_GOT        = "Got: %s",
	TRADE_HIST_NONE       = "nothing",
	TRADE_HIST_SEP        = " · ",
	TRADE_LIST_SEP        = ", ",
	TRADE_ST_INVITING     = "Invitation sent to %s…",
	TRADE_ST_RUNG         = "%s got your invitation: waiting for an answer (%d s).",
	TRADE_ST_INVITED      = "%s offers you a specimen trade (%d s).",
	TRADE_ST_OPEN         = "Trade with %s: set up your offer, then confirm.",
	TRADE_ST_WAIT_THEM    = "Trade with %s: you confirmed, waiting for them.",
	TRADE_ST_WAIT_YOU     = "Trade with %s: they confirmed, your turn.",
	TRADE_ST_LOCK         = "Trade with %s: checking both offers…",
	TRADE_ST_PREPARED     = "Trade with %s: all set, finishing…",
	TRADE_ST_DOUBT        = "Trade with %s on hold: it completes as soon as you're both online. Your offered specimens stay reserved.",
	TRADE_ST_DOUBT_OLD    = "Trade with %s on hold for over 7 days: \"Give up\" keeps your specimens with you.",
	TRADE_ST_IDLE         = "No trade in progress.",
	TRADE_MSG_INVITE      = "Trade invitation sent to %s.",
	TRADE_MSG_INVITED     = "%s offers you a specimen trade: /qc trade yes or /qc trade no (60 s), or journal › Reserve › Trades.",
	TRADE_MSG_OPEN        = "Trade open with %s: journal › Reserve › Trades.",
	TRADE_MSG_DONE        = "Trade done with %s. Gave: %s. Got: %s.",
	TRADE_MSG_BETTER      = "%s beats your Codex specimen: it's waiting in your Reserve (\"Set in Codex\").",
	TRADE_MSG_NEW         = "%s joins your Codex: one more species!",
	TRADE_MSG_RECOVERED   = "The trade on hold with %s is done.",
	TRADE_MSG_DOUBT_END   = "The trade on hold with %s is cancelled: nothing moved.",
	TRADE_MSG_ABANDONED   = "Trade with %s given up: your specimens stay with you.",
	TRADE_MSG_TARGET      = "Target the player you want to trade with first.",
	TRADE_ERR_self        = "You can't trade with yourself (your characters already share the collection).",
	TRADE_ERR_busy        = "A trade is already in progress: finish or cancel it first.",
	TRADE_ERR_pending     = "A trade with %s is on hold: it must complete first.",
	TRADE_ERR_cooldown    = "Wait %d more s before another trade.",
	TRADE_ERR_combat      = "No trading in combat.",
	TRADE_ERR_off         = "Capture is turned off in the settings: no trading.",
	TRADE_ERR_name        = "Give a player's name: /qc trade <name>.",
	TRADE_ERR_faction     = "No trading with the other faction: the client doesn't let messages through between Horde and Alliance.",
	TRADE_ERR_full        = "Your Reserve won't have room: %d slot(s) short. Release specimens or add slots at the Stall.",
	TRADE_ERR_max         = "3 specimens at most on each side.",
	TRADE_ERR_empty       = "Offer or wait for at least one specimen before confirming.",
	TRADE_ERR_doubt       = "The trade isn't 7 days old yet: be patient, it completes as soon as you're both online.",
	TRADE_END_no          = "%s declined the trade.",
	TRADE_END_busy        = "%s is busy (another trade, or one just ended): try again in a moment.",
	TRADE_END_off         = "%s turned capture off: no trading possible.",
	TRADE_END_combat      = "Trade with %s cancelled: combat.",
	TRADE_END_zoning      = "Trade with %s cancelled: loading screen.",
	TRADE_END_timeout     = "Trade with %s cancelled: no answer in time.",
	TRADE_END_invite_timeout = "%s didn't answer your invitation (60 s).",
	TRADE_END_cancel      = "Trade with %s cancelled.",
	TRADE_END_mismatch    = "Trade with %s cancelled: the data received didn't match what was shown. Nothing moved.",
	TRADE_END_missing     = "Trade with %s cancelled: an offered specimen can no longer be traded.",
	TRADE_END_full        = "Trade with %s cancelled: a Reserve ran out of room.",
	TRADE_END_version     = "Trade with %s impossible: your QuestCompanion versions don't understand each other (both of you, update).",
	TRADE_END_offline     = "Trade with %s cancelled: player not found (offline, other faction or other realm).",
	TRADE_END_unknown     = "Trade with %s cancelled: they have no trace of it.",
	TRADE_END_noanswer    = "No answer from %s: offline, other faction, or no QuestCompanion 3.0 (trades need 3.0 on both sides).",
	TRADE_END_oldaddon    = "%s has QuestCompanion, but a version before 3.0: trades need 3.0 on both sides.",
	TRADE_END_self        = "Trade refused: that's your own name.",
	TRADE_TIP_NEW         = "A new species for you!",
	TRADE_TIP_NEW_VERSION = "A version you don't have yet: it'll go to the Codex.",
	TRADE_TIP_BETTER      = "Better than your Codex specimen: it'll go to your Reserve.",
	TRADE_TIP_REMOVE      = "Click: take it back.",
	TRADE_TIP_ADD         = "Click: offer it.",
	HELP_TRADE            = "/qc trade <name> | yes | no | cancel -- trade specimens with a player",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRADE_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Epoch() return tonumber(Call(G("time"))) or 0 end
local function Plain(v)
	if ns.Plain then return ns.Plain(v) end
	return v
end
local function Refresh(self)
	local frame = self.journalFrame
	if frame and frame:IsShown() and frame.kind == "reserve" and self.RefreshJournal then pcall(self.RefreshJournal, self) end
end

-- État de la session (rien n'est sauvegardé ici ; l'échange préparé l'est :
-- capture.tradePending). ns.tradeState pour les tests.
local S = { session = nil, cooldownUntil = nil, incoming = {}, filterUntil = nil }
ns.tradeState = S

function ns:TradeResetSession()
	S.session, S.cooldownUntil, S.incoming, S.filterUntil, S.recovered = nil, nil, {}, nil, nil
end

-- ---------------------------------------------------------------------------
-- Données (au compte) : capture.tradeLog, capture.tradePending, capture.tradeCount
-- ---------------------------------------------------------------------------
local function Data(self)
	local capture = self.SpecimenStore and ns.SpecimenStore(self) or self:CaptureData()
	if type(capture.tradeLog) ~= "table" then capture.tradeLog = {} end
	return capture
end

function ns:TradeLog() return Data(self).tradeLog end

local function LogFind(self, tid)
	for _, entry in ipairs(Data(self).tradeLog) do
		if entry.tid == tid then return entry end
	end
	return nil
end

local function Pending(self)
	local pending = Data(self).tradePending
	return type(pending) == "table" and pending or nil
end

-- Un spécimen engagé dans l'échange en cours (offre) ou en suspens (préparé)
local function Locked(self, id)
	local pending = Pending(self)
	if pending then
		for _, given in ipairs(pending.give or {}) do if given == id then return true end end
	end
	local s = S.session
	if s and s.mine then
		for _, mine in ipairs(s.mine) do if mine == id then return true end end
	end
	return false
end
ns.TradeLocked = Locked

-- ---------------------------------------------------------------------------
-- Éligibilité
-- ---------------------------------------------------------------------------
function ns:SpecimenCanTrade(id, ignoreLock)
	local spec = self:SpecimenGet(id)
	if not spec then return false, "missing" end
	if self:SpecimenWorn(spec.id) then return false, "worn" end
	if self:SpecimenIsReference(spec.id) then return false, "reference" end
	if self:SpecimenBetterThanCodex(spec.id) then return false, "better" end
	if not ignoreLock and Locked(self, spec.id) then return false, "locked" end
	return true
end

-- Un spécimen engagé ne se relâche pas et ne passe pas au Codex
do
	local canRelease = ns.SpecimenCanRelease
	function ns:SpecimenCanRelease(id, ...)
		local ok, why = canRelease(self, id, ...)
		if ok and Locked(self, tonumber(id) or id) then return false, "locked" end
		return ok, why
	end
	local setRef = ns.SpecimenSetReference
	function ns:SpecimenSetReference(id, ...)
		if Locked(self, tonumber(id) or id) then return false, "locked" end
		return setRef(self, id, ...)
	end
end

-- ---------------------------------------------------------------------------
-- Données d'un spécimen en message
-- ---------------------------------------------------------------------------
local function Cut(text, max)
	if type(text) ~= "string" then return nil end
	text = text:gsub("[|%c]", "")
	if #text > max then
		text = text:sub(1, max)
		-- pas de caractère UTF-8 coupé en deux
		text = text:gsub("[\192-\255][\128-\191]*$", "")
	end
	if text == "" then return nil end
	return text
end

-- Les champs d'un spécimen à envoyer (table neuve)
local function Fields(self, spec)
	local capture = self:CaptureData()
	local entry = capture.creatures[spec.npc]
	entry = type(entry) == "table" and entry or {}
	local origin = spec.origin == "trade" and spec.firstOrigin or spec.origin
	local M = ns.TRADE_TEXT_MAX
	return {
		i = spec.id, n = spec.npc, s = spec.stars, h = spec.shiny and true or nil, z = spec.size or "normal",
		t = spec.trait, zo = tonumber(spec.zone), at = tonumber(spec.at), by = Cut(spec.by, M.by),
		o = ns.TRADE_ORIGINS[origin or ""] and origin or "capture",
		nm = Cut(spec.name or entry.name, M.nm), cl = ns.TRADE_CLASSES[entry.class or ""] and entry.class or nil,
		ty = Cut(entry.type, M.ty), fa = Cut(entry.family, M.fa), hp = tonumber(spec.hops) or 0,
	}
end

function ns:TradeEncodeSpec(spec)
	if type(spec) ~= "table" then spec = self:SpecimenGet(spec) end
	if not spec then return nil end
	return ns.TrainerEncode(Fields(self, spec))
end

local function Int(raw, lo, hi)
	local n = tonumber(raw)
	if not n or n ~= math.floor(n) or n < lo or n > hi then return nil end
	return n
end

-- Texte reçu -> spécimen (table neuve, valeurs bornées), ou nil s'il est illisible
function ns:TradeDecodeSpec(text)
	if type(text) ~= "string" or text == "" or #text > 250 then return nil end
	local raw = ns.TrainerDecode(text)
	local U = ns.TrainerUnescape
	local function Str(key) return raw[key] and Cut(U(raw[key]), ns.TRADE_TEXT_MAX[key] or 48) or nil end
	local npc, stars, id = Int(raw.n, 1, 9999999), Int(raw.s, 1, 3), Int(raw.i, 1, 99999999)
	if not (npc and stars and id) then return nil end
	local size = raw.z and U(raw.z) or "normal"
	if not (ns.SPECIMEN_SIZE_BY_ID and ns.SPECIMEN_SIZE_BY_ID[size]) then size = "normal" end
	local trait = raw.t and U(raw.t) or nil
	if not (trait and ns.PERSONALITY_TRAITS and ns.PERSONALITY_TRAITS[trait]) then trait = nil end
	local origin = raw.o and U(raw.o) or "capture"
	local class = raw.cl and U(raw.cl) or nil
	return {
		i = id, npc = npc, stars = stars, shiny = raw.h == "1" or nil, size = size, trait = trait,
		zone = Int(raw.zo, 1, 999999), at = Int(raw.at, 0, 4294967295), by = Str("by"),
		origin = ns.TRADE_ORIGINS[origin] and origin or "capture", name = Str("nm"),
		class = ns.TRADE_CLASSES[class or ""] and class or nil, type = Str("ty"), family = Str("fa"),
		hops = Int(raw.hp, 0, 999) or 0,
	}
end

-- ---------------------------------------------------------------------------
-- Envoi
-- ---------------------------------------------------------------------------
local function Send(self, s, kind, ...)
	local parts = { kind, tostring(ns.TRADE_PROTO), s.tid }
	for index = 1, select("#", ...) do parts[#parts + 1] = tostring((select(index, ...))) end
	s.sentAt = Clock()
	S.filterUntil = Clock() + 10
	return self:ChatQueue(ns.TRADE_PREFIX, table.concat(parts, "~"), "WHISPER", s.peer)
end

local function NewTid()
	local now = Epoch()
	return string.format("%x%04x", now % 16777216, math.random(0, 65535))
end

local function Short(self, name)
	return self.TrainerShortName and self:TrainerShortName(name) or tostring(name or "?")
end

-- Fin d'une session (pas d'un échange préparé) : message, temps de repos
local function End(self, reason, notify, sendNow)
	local s = S.session
	if not s then return false end
	if notify and s.tid then
		if sendNow and self.ChatSendNow then
			local text = table.concat({ "X", tostring(ns.TRADE_PROTO), s.tid, notify }, "~")
			if not self:ChatSendNow(ns.TRADE_PREFIX, text, "WHISPER", s.peer) then Send(self, s, "X", notify) end
		else
			Send(self, s, "X", notify)
		end
	end
	S.session = nil
	S.cooldownUntil = Clock() + ns.TRADE_COOLDOWN
	if reason then self:Print(self:F("TRADE_END_" .. reason, Short(self, s.peer))) end
	local frame = self.journalFrame
	if frame then frame.tradeOffset = 0 end
	Refresh(self)
	return true
end

-- ---------------------------------------------------------------------------
-- Place dans la Réserve : reçus qui iront en Réserve − donnés ≤ places libres
-- ---------------------------------------------------------------------------
function ns:TradeRoom(theirs, mine)
	local s = S.session
	theirs = theirs or (s and s.theirs) or {}
	mine = mine or (s and s.mine) or {}
	local incoming, seen = 0, {}
	for _, item in ipairs(theirs) do
		local spec = item.spec or item
		local key = tostring(spec.npc) .. (spec.shiny and ":s" or "")
		-- une version que tu n'as pas : la première va au Codex
		if self:CaptureHas(spec.npc, spec.shiny and true or false) or seen[key] then
			incoming = incoming + 1
		end
		seen[key] = true
	end
	local free = self:ReserveCapacity() - self:SpecimenReserveCount()
	return math.max(0, incoming - #mine - free)
end

-- ---------------------------------------------------------------------------
-- Démarrer, accepter, refuser, annuler
-- ---------------------------------------------------------------------------
local function CaptureOn(self) return self:DB().companionCapture ~= false end
local function InCombat()
	return Plain(Call(G("InCombatLockdown"))) == true or Plain(Call(G("UnitAffectingCombat"), "player")) == true
end
local function IsMe(self, key) return key ~= nil and key == self:TrainerKey(self:TrainerMe()) end

-- Pourquoi on ne peut pas commencer un échange (nil : rien ne bloque)
local function Blocked(self)
	if not CaptureOn(self) then return "off" end
	local pending = Pending(self)
	if pending then return "pending", Short(self, pending.peer) end
	if S.session then return "busy" end
	local now = Clock()
	if S.cooldownUntil and now < S.cooldownUntil then return "cooldown", math.ceil(S.cooldownUntil - now) end
	if InCombat() then return "combat" end
	return nil
end

local function Fail(self, why, arg)
	if arg ~= nil then self:Print(self:F("TRADE_ERR_" .. why, arg)) else self:Print(L["TRADE_ERR_" .. why]) end
	return nil, why
end

local function NewSession(tid, peer, key, role, phase)
	local now = Clock()
	return { tid = tid, peer = peer, key = key, role = role, phase = phase, at = now, started = now,
		expires = now + ns.TRADE_INVITE_TTL, mine = {}, myRev = 0, theirs = {}, theirRev = 0 }
end

function ns:TradeInvite(name)
	name = name and self:TrainerFullName(name)
	local key = name and self:TrainerKey(name)
	if not key then return Fail(self, "name") end
	if IsMe(self, key) then return Fail(self, "self") end
	local why, arg = Blocked(self)
	if why then return Fail(self, why, arg) end
	local s = NewSession(NewTid(), name, key, "inviter", "inviting")
	s.ringBy = s.at + ns.TRADE_RING_WAIT
	S.session = s
	Send(self, s, "I", ns.TrainerEscape(tostring(ns.version or "?")), ns.TrainerEscape(key))
	-- une version d'avant la 3.0 répond à la sonde de la fiche (pas aux échanges) :
	-- de quoi dire « mets-toi à jour » plutôt que « pas de réponse » (s.trainerSeen)
	if self.TrainerSharing and self:TrainerSharing() and self.TrainerSend then self:TrainerSend("P", "WHISPER", name) end
	self:Print(self:F("TRADE_MSG_INVITE", Short(self, name)))
	if self.OpenReserve then self:OpenReserve("trade") end
	Refresh(self)
	return true
end

-- La cible : un joueur de ta faction
function ns:TradeWithTarget()
	local name = self.TrainerUnitName and self:TrainerUnitName("target")
	if not name then
		self:Print(L.TRADE_MSG_TARGET)
		return nil, "target"
	end
	local mine, theirs = Plain(Call(G("UnitFactionGroup"), "player")), Plain(Call(G("UnitFactionGroup"), "target"))
	if (mine and theirs and mine ~= theirs) or Plain(Call(G("UnitIsFriend"), "player", "target")) == false then
		return Fail(self, "faction")
	end
	return self:TradeInvite(name)
end

function ns:TradeAccept()
	local s = S.session
	if not (s and s.phase == "invited") then return nil, "none" end
	if InCombat() then return Fail(self, "combat") end
	s.phase, s.at = "open", Clock()
	Send(self, s, "A")
	self:Print(self:F("TRADE_MSG_OPEN", Short(self, s.peer)))
	if self.OpenReserve then self:OpenReserve("trade") end
	Refresh(self)
	return true
end

function ns:TradeDecline()
	local s = S.session
	if not (s and s.phase == "invited") then return nil, "none" end
	Send(self, s, "D", "no")
	S.session = nil
	S.cooldownUntil = Clock() + ns.TRADE_COOLDOWN
	Refresh(self)
	return true
end

-- Annuler : toute session avant le vote (préparé : impossible, voir Abandonner)
function ns:TradeCancel()
	local s = S.session
	if not s or s.prepared then return nil, s and "prepared" or "none" end
	if s.phase == "invited" then return self:TradeDecline() end
	return End(self, "cancel", "cancel")
end

-- ---------------------------------------------------------------------------
-- Offre et validation
-- ---------------------------------------------------------------------------
local function SendOffer(self, s)
	local count = #s.mine
	if count == 0 then return Send(self, s, "O", s.myRev, 0, 0, "") end
	for index, id in ipairs(s.mine) do
		Send(self, s, "O", s.myRev, index, count, self:TradeEncodeSpec(id) or "")
	end
	return true
end

local function ResetValid(s)
	s.myValid, s.theirValid = false, false
end

function ns:TradeToggleOffer(id)
	local s = S.session
	if not (s and s.phase == "open") then return nil, "none" end
	id = tonumber(id) or id
	for index, mine in ipairs(s.mine) do
		if mine == id then
			table.remove(s.mine, index)
			s.myRev, s.at = s.myRev + 1, Clock()
			ResetValid(s)
			SendOffer(self, s)
			Refresh(self)
			return false
		end
	end
	local ok, why = self:SpecimenCanTrade(id)
	if not ok then return nil, why end
	if #s.mine >= ns.TRADE_MAX then return Fail(self, "max") end
	s.mine[#s.mine + 1] = id
	s.myRev, s.at = s.myRev + 1, Clock()
	ResetValid(s)
	SendOffer(self, s)
	Refresh(self)
	return true
end

-- Tous mes spécimens proposés sont-ils encore échangeables ? (verrou ignoré : ce sont les miens)
local function MineOk(self, s)
	for _, id in ipairs(s.mine) do
		if not self:SpecimenCanTrade(id, true) then return false end
	end
	return true
end

local MaybeLock, TryPrepare
function ns:TradeValidate()
	local s = S.session
	if not (s and s.phase == "open") then return nil, "none" end
	if #s.mine + #s.theirs == 0 then return Fail(self, "empty") end
	if not MineOk(self, s) then
		End(self, "missing", "missing")
		return nil, "missing"
	end
	local short = self:TradeRoom()
	if short > 0 then return Fail(self, "full", short) end
	s.myValid, s.at = true, Clock()
	Send(self, s, "V", s.myRev, s.theirRev)
	MaybeLock(self, s)
	Refresh(self)
	return true
end

-- ---------------------------------------------------------------------------
-- Engagement
-- ---------------------------------------------------------------------------
-- Une ligne de résumé d'un spécimen (journal : sans id ; table neuve)
local function Brief(spec)
	return { npc = spec.npc, stars = spec.stars, shiny = spec.shiny and true or nil, name = spec.name, size = spec.size }
end

local function LogAdd(self, entry)
	local log = Data(self).tradeLog
	table.insert(log, 1, entry)
	for index = #log, ns.TRADE_LOG_MAX + 1, -1 do log[index] = nil end
end

local function Label(self, brief)
	local name = self.CreatureName and self:CreatureName(brief.npc, { name = brief.name }) or tostring(brief.name or brief.npc)
	if brief.shiny then name = self:F("CAPTURE_SHINY_TAG", name) end
	return name .. " " .. (self.CaptureStarsText and self:CaptureStarsText(brief.stars, 10) or "")
end

function ns:TradeListText(list)
	if type(list) ~= "table" or #list == 0 then return L.TRADE_HIST_NONE end
	local parts = {}
	for index, brief in ipairs(list) do parts[index] = Label(self, brief) end
	return table.concat(parts, L.TRADE_LIST_SEP)
end

-- La fiche de l'espèce d'un spécimen reçu : créée si l'espèce est nouvelle
-- (comme une capture : nom, rang, type, zone), sans rien posséder encore (le
-- spécimen ajouté ensuite pose normal / shiny et les étoiles)
local function EnsureEntry(self, capture, spec, now)
	local entry = capture.creatures[spec.npc]
	local fresh = entry == nil
	if fresh then
		entry = { normal = false, name = spec.name, class = spec.class or "normal", type = spec.type, family = spec.family,
			zoneID = spec.zone }
		capture.creatures[spec.npc] = entry
		capture.count = (tonumber(capture.count) or 0) + 1
	end
	if spec.shiny then
		if entry.shiny ~= true then entry.shinyAt = spec.at or now; entry.at = entry.at or entry.shinyAt end
	elseif entry.normal == false or entry.normal == nil then
		entry.at = spec.at or now
	end
	entry.firstAt = entry.firstAt or entry.at
	return fresh
end

-- L'échange préparé est appliqué, d'un seul bloc. Rend true.
local function Commit(self, pending)
	local capture = Data(self)
	local peer = pending.peer
	if LogFind(self, pending.tid) then
		capture.tradePending = nil
		return false
	end
	local now = Epoch()
	local gave, got = {}, {}
	for _, id in ipairs(pending.give or {}) do
		local spec = capture.specimens[id]
		if spec then
			gave[#gave + 1] = Brief(spec)
			self:SpecimenTake(id)
		end
	end
	local newSpecies, notes = false, {}
	for _, raw in ipairs(pending.get or {}) do
		local spec = self:TradeDecodeSpec(raw)
		if spec then
			local had = capture.creatures[spec.npc] ~= nil
			EnsureEntry(self, capture, spec, now)
			if not had then newSpecies = true end
			local id, place = self:SpecimenAdd({ npc = spec.npc, stars = spec.stars, shiny = spec.shiny, zone = spec.zone,
				at = spec.at, by = spec.by, origin = "trade", name = spec.name, trait = spec.trait, size = spec.size,
				keepReserve = true })
			local added = id and capture.specimens[id]
			if added then
				added.tradedFrom, added.tradedAt = Short(self, peer), now
				added.firstOrigin, added.hops = spec.origin, (spec.hops or 0) + 1
				got[#got + 1] = Brief(added)
				if not had then notes[#notes + 1] = { "TRADE_MSG_NEW", added }
				elseif place == "reserve" and self:SpecimenBetterThanCodex(id) then notes[#notes + 1] = { "TRADE_MSG_BETTER", added } end
			end
		end
	end
	capture.serial = (tonumber(capture.serial) or 0) + 1
	self.captureAppCache = nil
	LogAdd(self, { tid = pending.tid, at = now, peer = Short(self, peer), gave = gave, got = got, result = "done" })
	capture.tradePending = nil
	capture.tradeCount = (tonumber(capture.tradeCount) or 0) + 1
	-- hauts faits (FeatsCatMenagerie.lua) : soc_trade_1, soc_trade_10, soc_trade_new
	if self.FeatCount then pcall(self.FeatCount, self, "trades", 1, "account") end
	if newSpecies and self.FeatFlag then pcall(self.FeatFlag, self, "tradeNew", "account") end
	self:Print(self:F("TRADE_MSG_DONE", Short(self, peer), self:TradeListText(gave), self:TradeListText(got)))
	for _, note in ipairs(notes) do self:Print(self:F(note[1], self:SpecimenLabel(note[2]))) end
	if self.FireCallback then self:FireCallback("SPECIMENS", "trade", pending.tid) end
	return true
end

-- Un échange préparé que l'autre n'a pas engagé : on l'oublie (rien n'a bougé)
local function DropPending(self, pending, why)
	local capture = Data(self)
	LogAdd(self, { tid = pending.tid, at = Epoch(), peer = Short(self, pending.peer), gave = {}, got = {},
		result = "aborted", reason = why })
	capture.tradePending = nil
end

local function TryCommit(self)
	local pending = Pending(self)
	if not (pending and pending.gotK) then return false end
	local s = S.session
	local recovered = s and s.recovered
	local done = Commit(self, pending)
	-- F à l'autre dans tous les cas (il attend peut-être, préparé)
	Send(self, s and s.tid == pending.tid and s or { tid = pending.tid, peer = pending.peer }, "F")
	if s and s.tid == pending.tid then
		S.session = nil
		S.cooldownUntil = Clock() + ns.TRADE_COOLDOWN
	end
	if done and recovered then self:Print(self:F("TRADE_MSG_RECOVERED", Short(self, pending.peer))) end
	if self.journalFrame then self.journalFrame.tradeOffset = 0 end
	Refresh(self)
	return done
end

-- Phase 1 : mes données complètes ; la place et mes spécimens revérifiés
function MaybeLock(self, s)
	if not (s.phase == "open" and s.myValid and s.theirValid) then return false end
	if not MineOk(self, s) then return End(self, "missing", "missing") end
	if self:TradeRoom() > 0 then return End(self, "full", "full") end
	s.phase, s.lockAt, s.at = "locking", Clock(), Clock()
	s.lockRaw = {}
	local count = #s.mine
	for index, id in ipairs(s.mine) do
		local raw = self:TradeEncodeSpec(id) or ""
		s.lockRaw[index] = raw
		Send(self, s, "L", index, count, raw)
	end
	if count == 0 then Send(self, s, "L", 0, 0, "") end
	-- ses données sont peut-être déjà là
	TryPrepare(self, s)
	return true
end

-- Les données de l'autre reçues : comparées à ce qui était affiché, puis préparé (journalisé) et K
function TryPrepare(self, s)
	if not (s.phase == "locking" and s.theirLock) or s.prepared then return false end
	if #s.theirLock ~= #s.theirs then return End(self, "mismatch", "mismatch") end
	for index, item in ipairs(s.theirs) do
		if s.theirLock[index] ~= item.raw then return End(self, "mismatch", "mismatch") end
	end
	if self:TradeRoom() > 0 then return End(self, "full", "full") end
	local give, get = {}, {}
	for index, id in ipairs(s.mine) do give[index] = id end
	for index, raw in ipairs(s.theirLock) do get[index] = raw end
	Data(self).tradePending = { tid = s.tid, peer = s.peer, at = Epoch(), give = give, get = get, gotK = s.gotK or nil }
	s.prepared, s.phase, s.at = true, "prepared", Clock()
	s.resent, s.nextK = 0, Clock() + ns.TRADE_RESEND[1]
	Send(self, s, "K")
	TryCommit(self)
	Refresh(self)
	return true
end

-- ---------------------------------------------------------------------------
-- Réception
-- ---------------------------------------------------------------------------
local function Split(text)
	local fields = {}
	for field in (text .. "~"):gmatch("([^~]*)~") do fields[#fields + 1] = field end
	return fields
end

local function Flooded(key, now)
	local box = S.incoming[key]
	if not box or now < box.at or now - box.at >= ns.TRADE_IN_WINDOW then
		box = { at = now, n = 0 }
		S.incoming[key] = box
	end
	box.n = box.n + 1
	return box.n > ns.TRADE_IN_MAX
end

-- Morceaux d'une offre (O) ou de données (L) : boîte { rev, n, parts, got }
local function Collect(box, rev, index, count, raw)
	if not (index and count) or count < 0 or count > ns.TRADE_MAX then return nil end
	if count == 0 then return {} end
	if index < 1 or index > count then return nil end
	if box.rev ~= rev or box.n ~= count then box.rev, box.n, box.parts, box.got = rev, count, {}, 0 end
	if box.parts[index] == nil then box.parts[index] = raw; box.got = box.got + 1 end
	if box.got < count then return nil end
	local list = {}
	for i = 1, count do list[i] = box.parts[i] end
	box.rev, box.n, box.parts, box.got = nil, nil, {}, 0
	return list
end

local function OnOffer(self, s, f)
	local rev, index, count = tonumber(f[4]), tonumber(f[5]), tonumber(f[6])
	if not rev or rev < s.theirRev or not (s.phase == "open" or s.phase == "locking") then return end
	s.offerBox = s.offerBox or { parts = {}, got = 0 }
	local list = Collect(s.offerBox, rev, index, count, table.concat(f, "~", 7))
	if not list then return end
	local theirs = {}
	for i, raw in ipairs(list) do
		local spec = self:TradeDecodeSpec(raw)
		if not spec then return end
		theirs[i] = { raw = raw, spec = spec }
	end
	s.theirs, s.theirRev, s.at = theirs, rev, Clock()
	-- une nouvelle offre après les validations (croisement) : retour à la
	-- composition, ses anciennes données oubliées
	s.phase, s.lockRaw, s.theirLock, s.lockBox = "open", nil, nil, nil
	ResetValid(s)
	Refresh(self)
end

local function OnLock(self, s, f)
	if not (s.phase == "open" or s.phase == "locking") then return end
	local index, count = tonumber(f[4]), tonumber(f[5])
	s.lockBox = s.lockBox or { parts = {}, got = 0 }
	local list = Collect(s.lockBox, "L", index, count, table.concat(f, "~", 6))
	if not list then return end
	s.theirLock = list
	TryPrepare(self, s)
end

-- Un message pour l'échange préparé (en suspens) : K, F, X, N
local function OnPending(self, pending, kind)
	if kind == "K" or kind == "F" then
		pending.gotK = true
		return TryCommit(self)
	end
	if kind == "X" or kind == "N" then
		DropPending(self, pending, kind == "N" and "unknown" or "abort")
		local s = S.session
		if s and s.tid == pending.tid then
			S.session = nil
			S.cooldownUntil = Clock() + ns.TRADE_COOLDOWN
		end
		self:Print(self:F("TRADE_MSG_DOUBT_END", Short(self, pending.peer)))
		Refresh(self)
		return true
	end
	return false
end

local DECLINES = { no = "no", busy = "busy", off = "off", combat = "combat", version = "version", timeout = "timeout",
	self = "self", cooldown = "busy" }
local ABORTS = { cancel = "cancel", combat = "combat", zoning = "zoning", timeout = "timeout", mismatch = "mismatch",
	missing = "missing", full = "full", version = "version" }

local function OnInvite(self, sender, key, f)
	local tid, to = f[3], f[5] and ns.TrainerUnescape(f[5]) or nil
	if not tid or tid == "" or #tid > 16 then return end
	if to and to ~= "" and not IsMe(self, to) then return end
	local reply = { tid = tid, peer = sender }
	local why = Blocked(self)
	if why == "pending" or why == "cooldown" then why = "busy" end
	if why then return Send(self, reply, "D", why) end
	local s = NewSession(tid, sender, key, "invitee", "invited")
	s.peerVersion = f[4] and ns.TrainerUnescape(f[4]) or nil
	S.session = s
	Send(self, s, "R", ns.TrainerEscape(tostring(ns.version or "?")))
	self:Print(self:F("TRADE_MSG_INVITED", Short(self, sender)))
	if self.CapturePlaySound then pcall(self.CapturePlaySound, self, "toast") end
	Refresh(self)
end

function ns:TradeOnAddonMessage(prefix, text, channel, sender)
	if Plain(prefix) ~= ns.TRADE_PREFIX then return false end
	text, sender = Plain(text), Plain(sender)
	if type(text) ~= "string" or type(sender) ~= "string" or #text > 255 then return false end
	sender = self:TrainerFullName(sender)
	local key = sender and self:TrainerKey(sender)
	if not key or IsMe(self, key) then return false end
	if Flooded(key, Clock()) then return false end
	local f = Split(text)
	local kind, proto, tid = f[1], tonumber(f[2]), f[3]
	if not proto or not tid or tid == "" then return false end
	if self.TrainerMarkHolder then self:TrainerMarkHolder(sender) end
	-- une autre génération du protocole : pas d'échange possible
	if math.floor(proto) ~= ns.TRADE_PROTO then
		if kind == "I" then Send(self, { tid = tid, peer = sender }, "D", "version") end
		local s = S.session
		if s and s.key == key and s.tid == tid and not s.prepared then End(self, "version") end
		return true
	end
	if kind == "I" then OnInvite(self, sender, key, f); return true end
	-- l'échange préparé (en suspens, ou repris après un /reload)
	local pending = Pending(self)
	if pending and pending.tid == tid and self:TrainerKey(pending.peer) == key then
		OnPending(self, pending, kind)
		return true
	end
	local s = S.session
	if not (s and s.tid == tid and s.key == key) then
		-- une question sur un échange fini : la réponse du journal
		if kind == "K" then
			local entry = LogFind(self, tid)
			local reply = { tid = tid, peer = sender }
			if entry and entry.result == "done" then Send(self, reply, "F")
			elseif entry then Send(self, reply, "X", "abort")
			else Send(self, reply, "N") end
		end
		return true
	end
	s.at = Clock()
	if kind == "R" then
		if s.phase == "inviting" then s.rung, s.peerVersion = true, f[4] and ns.TrainerUnescape(f[4]) or nil end
	elseif kind == "A" then
		if s.phase == "inviting" then
			s.phase, s.rung = "open", true
			self:Print(self:F("TRADE_MSG_OPEN", Short(self, s.peer)))
			if self.OpenReserve then self:OpenReserve("trade") end
		end
	elseif kind == "D" then
		if s.phase == "inviting" then End(self, DECLINES[f[4] or ""] or "no") end
	elseif kind == "O" then
		OnOffer(self, s, f)
	elseif kind == "V" then
		local theirRev, myRev = tonumber(f[4]), tonumber(f[5])
		if s.phase == "open" and theirRev == s.theirRev and myRev == s.myRev then
			s.theirValid = true
			MaybeLock(self, s)
		end
	elseif kind == "L" then
		OnLock(self, s, f)
	elseif kind == "K" then
		-- K avant d'avoir fini de préparer : retenu
		s.gotK = true
		TryPrepare(self, s)
	elseif kind == "X" then
		End(self, ABORTS[f[4] or ""] or "cancel")
	elseif kind == "N" then
		End(self, "unknown")
	end
	Refresh(self)
	return true
end

-- La fiche de dresseur reçoit tous les messages d'addon (TrainerCard.lua) :
-- ceux des échanges viennent ici
do
	local base = ns.TrainerOnAddonMessage
	if base then
		function ns:TrainerOnAddonMessage(prefix, text, channel, sender, ...)
			prefix = Plain(prefix)
			if prefix == ns.TRADE_PREFIX then return self:TradeOnAddonMessage(prefix, text, channel, sender, ...) end
			-- l'invité répond à la fiche mais pas à l'invitation : une version d'avant la 3.0
			local s = S.session
			if s and s.phase == "inviting" and prefix == ns.TRAINER_PREFIX and type(Plain(sender)) == "string"
				and self:TrainerKey(Plain(sender)) == s.key then
				s.trainerSeen = true
			end
			return base(self, prefix, text, channel, sender, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Horloge (1 s, rien d'alloué) : délais, K renvoyé tant que c'est en suspens
-- ---------------------------------------------------------------------------
function ns:TradeTick(now)
	now = now or Clock()
	local s = S.session
	if not s then
		-- échange en suspens retrouvé à la connexion : la reprise
		if S.loggedIn and Pending(self) then self:TradeRecover() end
		return false
	end
	local phase = s.phase
	-- le compte à rebours de l'invitation, si la vue Échanges est ouverte
	if phase == "inviting" or phase == "invited" then
		local frame = self.journalFrame
		if frame and frame.resView == "trade" then Refresh(self) end
	end
	if phase == "inviting" then
		if not s.rung and now >= s.ringBy then
			return End(self, s.trainerSeen and "oldaddon" or "noanswer", "timeout")
		end
		if now >= s.expires then return End(self, "invite_timeout", "timeout") end
	elseif phase == "invited" then
		if now >= s.expires then
			Send(self, s, "D", "timeout")
			S.session = nil
			Refresh(self)
			return true
		end
	elseif phase == "open" then
		if now - s.at >= ns.TRADE_IDLE_TTL then return End(self, "timeout", "timeout") end
	elseif phase == "locking" then
		if now - (s.lockAt or now) >= ns.TRADE_LOCK_TTL then return End(self, "timeout", "timeout") end
	elseif phase == "prepared" then
		if now >= (s.nextK or 0) then
			local R = ns.TRADE_RESEND
			s.resent = (s.resent or 0) + 1
			s.nextK = now + (s.resent < R[2] and R[1] or R[3])
			Send(self, s, "K")
		end
	end
	return false
end

-- L'échange en suspens retrouvé (connexion, /reload) : une session « préparé »
-- qui renvoie K à l'autre jusqu'à sa réponse
function ns:TradeRecover()
	local pending = Pending(self)
	if not pending or (S.session and S.session.tid == pending.tid) then return false end
	local key = self:TrainerKey(pending.peer)
	local s = NewSession(pending.tid, pending.peer, key, "recover", "prepared")
	s.prepared, s.recovered, s.resent, s.nextK = true, true, 0, Clock()
	s.mine = {}
	for index, id in ipairs(pending.give or {}) do s.mine[index] = id end
	S.session = s
	return true
end

function ns:TradeAbandon()
	local pending = Pending(self)
	if not pending then return nil, "none" end
	if Epoch() - (tonumber(pending.at) or 0) < ns.TRADE_DOUBT_ABANDON then return Fail(self, "doubt") end
	local s = S.session
	if s and s.tid == pending.tid then Send(self, s, "X", "abandon") end
	DropPending(self, pending, "abandon")
	S.session = nil
	self:Print(self:F("TRADE_MSG_ABANDONED", Short(self, pending.peer)))
	Refresh(self)
	return true
end

function ns:TradeSession() return S.session end

-- ---------------------------------------------------------------------------
-- Événements : combat, écran de chargement, joueur introuvable, connexion
-- ---------------------------------------------------------------------------
local ACTIVE = { inviting = true, invited = true, open = true, locking = true }

-- « Aucun joueur nommé « X » n'est connecté » (ERR_CHAT_PLAYER_NOT_FOUND_S) -> X
local notFound, notFoundFmt
local function NotFoundName(text)
	local fmt = G("ERR_CHAT_PLAYER_NOT_FOUND_S")
	if fmt ~= notFoundFmt then
		notFoundFmt, notFound = fmt, nil
		if type(fmt) == "string" and fmt:find("%s", 1, true) then
			local pattern = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
			notFound = "^" .. pattern .. "$"
		end
	end
	if not notFound or type(text) ~= "string" then return nil end
	return text:match(notFound)
end
ns.TradeNotFoundName = NotFoundName

local function PeerNamed(self, s, name)
	if not (s and name) then return false end
	return self:TrainerKey(name) == s.key or self:TrainerKey(self:TrainerFullName(name)) == s.key
end

function ns:TradeOnEvent(event, ...)
	local s = S.session
	if event == "PLAYER_REGEN_DISABLED" then
		if s and ACTIVE[s.phase] then
			if s.phase == "invited" then
				Send(self, s, "D", "combat")
				S.session = nil
				self:Print(self:F("TRADE_END_combat", Short(self, s.peer)))
				Refresh(self)
				return true
			end
			return End(self, "combat", "combat")
		end
	elseif event == "PLAYER_LEAVING_WORLD" then
		if s and ACTIVE[s.phase] then return End(self, "zoning", "zoning", true) end
	elseif event == "CHAT_MSG_SYSTEM" then
		local name = NotFoundName(Plain((...)))
		if s and ACTIVE[s.phase] and PeerNamed(self, s, name) then return End(self, "offline") end
	elseif event == "PLAYER_ENTERING_WORLD" then
		S.loggedIn = true
		if Pending(self) then return self:TradeRecover() end
	end
	return false
end

-- Le « joueur introuvable » du client, tant qu'on relance un échange en
-- suspens (l'autre est peut-être hors ligne) : masqué, notre message suffit
function ns:TradeChatFilter(text)
	local s = S.session
	if not (s and S.filterUntil and Clock() <= S.filterUntil) then return false end
	return PeerNamed(self, s, NotFoundName(Plain(text)))
end

do
	-- 3.1.0 : cadre d'événements commun de l'addon (ns.On, Libs/Socle/Compat.lua) ;
	-- une fonction par événement, faite une fois (TradeOnEvent reçoit son nom)
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "CHAT_MSG_SYSTEM" }) do
		ns.On(event, "trade", function(...) return ns:TradeOnEvent(event, ...) end)
	end
	ns.ChatRegisterPrefix(ns.TRADE_PREFIX)
	if ns.Every then
		ns.Every("trade", 1, function()
			local done, err = pcall(ns.TradeTick, ns)
			if not done and ns.RecordError then ns:RecordError("trade:tick", err) end
		end)
	end
	-- (moteur récent : ChatFrameUtil.AddMessageEventFilter ; ancien : la fonction globale)
	local util = G("ChatFrameUtil")
	local addFilter = (type(util) == "table" and util.AddMessageEventFilter) or G("ChatFrame_AddMessageEventFilter")
	if type(addFilter) == "function" then
		pcall(addFilter, "CHAT_MSG_SYSTEM", function(_, _, text)
			local done, hide = pcall(ns.TradeChatFilter, ns, text)
			return done and hide or false
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Menu du clic droit (mêmes menus que la fiche de dresseur, détenteurs connus)
-- ---------------------------------------------------------------------------
function ns:TradeMenuAdd(rootDescription, contextData)
	local name = self:TrainerMenuTarget(contextData)
	if not name or type(rootDescription) ~= "table" or type(rootDescription.CreateButton) ~= "function" then return false end
	local unit = type(contextData) == "table" and Plain(contextData.unit) or nil
	if unit and Plain(Call(G("UnitIsFriend"), "player", unit)) == false then return false end
	pcall(rootDescription.CreateButton, rootDescription, L.TRADE_MENU, function() ns:TradeInvite(name) end)
	return true
end
do
	local base = ns.TrainerMenuAdd
	if base then
		function ns:TrainerMenuAdd(rootDescription, contextData)
			local added = base(self, rootDescription, contextData)
			if added then pcall(self.TradeMenuAdd, self, rootDescription, contextData) end
			return added
		end
	end
end

-- ---------------------------------------------------------------------------
-- /qc echange <nom> | oui | non | annuler | abandonner (EN /qc trade)
-- ---------------------------------------------------------------------------
local WORDS = { oui = "accept", accepter = "accept", accept = "accept", yes = "accept",
	non = "decline", refuser = "decline", decline = "decline", no = "decline",
	annuler = "cancel", cancel = "cancel", stop = "cancel",
	abandonner = "abandon", abandon = "abandon" }
function ns:TradeCommand(rest)
	local arg = tostring(rest or ""):match("^%s*(.-)%s*$") or ""
	if arg == "" then
		if self.OpenReserve then self:OpenReserve("trade") end
		return true
	end
	local word = WORDS[arg:lower()]
	if word == "accept" then return self:TradeAccept()
	elseif word == "decline" then return self:TradeDecline()
	elseif word == "cancel" then return self:TradeCancel()
	elseif word == "abandon" then return self:TradeAbandon() end
	return self:TradeInvite(arg:match("^(%S+)"))
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_TRADE")
		end
	end
end
if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["echange"] = function(self, rest) return self:TradeCommand(rest) end
	ns.EXTRA_COMMANDS["échange"] = ns.EXTRA_COMMANDS["echange"]
	ns.EXTRA_COMMANDS["trade"] = ns.EXTRA_COMMANDS["echange"]
end

-- ---------------------------------------------------------------------------
-- La vue « Échanges » de la page Réserve (JournalReserve.lua)
-- ---------------------------------------------------------------------------
local LAY = ns.TRADE_LAYOUT
local RLAY = ns.RESERVE_LAYOUT
local function UI() return ns.JournalUI or {} end

local function Enable(button, on, why)
	on = on and true or false
	if button.SetEnabled then button:SetEnabled(on) end
	button.qcEnabled = on
	button.disabledTip = (not on) and why or nil
end

local function SpecTip(self, tile)
	local spec, tip = tile.tradeSpec, UI().Tip
	if not (spec and tip) then return end
	local lines = { self.CaptureStarsText and self:CaptureStarsText(spec.stars, 12) or "" }
	if tile.theirs then
		lines[#lines + 1] = self:SpecimenOriginText({ origin = spec.origin, by = spec.by, zone = spec.zone, at = spec.at })
		if self.SpecimenTagsShort then lines[#lines + 1] = self:SpecimenTagsShort(spec) end
		if self:CaptureData().creatures[spec.npc] == nil then
			lines[#lines + 1] = L.TRADE_TIP_NEW
		elseif not self:CaptureHas(spec.npc, spec.shiny and true or false) then
			lines[#lines + 1] = L.TRADE_TIP_NEW_VERSION
		else
			local ref = self:SpecimenReference(spec.npc, spec.shiny)
			if ref and spec.stars > ref.stars then lines[#lines + 1] = L.TRADE_TIP_BETTER end
		end
	else
		lines[#lines + 1] = self:SpecimenOriginText(spec)
		if self.SpecimenTagsShort then lines[#lines + 1] = self:SpecimenTagsShort(spec) end
		if tile.why then lines[#lines + 1] = L["RES_WHY_" .. tile.why] or ""
		elseif tile.offered then lines[#lines + 1] = L.TRADE_TIP_REMOVE
		elseif tile.pickable then lines[#lines + 1] = L.TRADE_TIP_ADD end
	end
	tip(tile, self:SpecimenLabel(spec), lines)
end

function ns.TradeBuildView(self, frame, pane, content, ui)
	local At, Text, HideTip = ui.At, ui.Text, ui.HideTip
	local TOP, INNER, HALF, GAP = ui.TOP, ui.INNER, ui.HALF, ui.COL_GAP
	local tv = CreateFrame("Frame", nil, pane)
	tv:SetAllPoints()
	pane.trade = tv
	local y0 = TOP - Theme.CHIP_HEIGHT - 10
	tv.status = Text(tv, Theme.F_LABEL, Theme.LABEL, INNER)
	At(tv.status, content, 0, y0)
	if tv.status.SetWordWrap then tv.status:SetWordWrap(true) end
	tv.note = Text(tv, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER)
	At(tv.note, content, 0, y0 - 34)
	if tv.note.SetWordWrap then tv.note:SetWordWrap(true) end
	-- boutons sans échange : cible, invitation reçue, en suspens
	local rowY = y0 - 76
	tv.target = Theme.CreateButton(tv, "auto", "sm", L.RES_TRADE_TARGET, function(b)
		if b.qcEnabled == false then return end
		if tv.targetMode == "cancel" then ns:TradeCancel() else ns:TradeWithTarget() end
	end, "primary")
	At(tv.target, content, 0, rowY)
	tv.accept = Theme.CreateButton(tv, 120, "sm", L.TRADE_ACCEPT, function() ns:TradeAccept() end, "primary")
	At(tv.accept, content, 0, rowY)
	tv.decline = Theme.CreateButton(tv, 120, "sm", L.TRADE_DECLINE, function() ns:TradeDecline() end, "outline")
	tv.decline:SetPoint("LEFT", tv.accept, "RIGHT", 8, 0)
	tv.abandon = Theme.CreateButton(tv, "auto", "sm", L.TRADE_ABANDON, function(b)
		if b.qcEnabled ~= false then ns:TradeAbandon() end
	end, "outline")
	At(tv.abandon, content, 0, rowY)
	-- l'historique
	local histY = rowY - RLAY.actionH - 16
	-- 3.0.0 : intertitre canonique (Theme.CreateSection, comme les autres pages)
	tv.histHead = Theme.CreateSection(tv, L.TRADE_HIST_HEAD)
	tv.histHead:SetWidth(INNER)
	At(tv.histHead, content, 0, histY)
	local listTop = histY - 22
	local step = LAY.histRow + LAY.histGap
	local rows = math.max(1, math.floor((listTop - ui.PAGER_Y - 8) / step))
	tv.hist = {}
	for index = 1, rows do
		local y = listTop - (index - 1) * step
		local line = Text(tv, Theme.F_LABEL, Theme.LABEL, INNER)
		At(line, content, 0, y)
		if line.SetWordWrap then line:SetWordWrap(false) end
		local sub = Text(tv, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER)
		At(sub, content, 0, y - 16)
		if sub.SetWordWrap then sub:SetWordWrap(false) end
		tv.hist[index] = { line = line, sub = sub }
	end
	tv.histEmpty = Text(tv, Theme.F_BODY, Theme.MUTED_LIGHT, INNER)
	At(tv.histEmpty, content, 0, listTop)

	-- la fenêtre d'échange : deux colonnes de 3 places
	local colY = y0 - 30
	local tileY = colY - 20
	local slotStep = RLAY.tileW + LAY.slotGap
	tv.cols = {}
	for side, x in pairs({ mine = 0, theirs = HALF + GAP }) do
		local col = { slots = {}, tiles = {} }
		col.head = Text(tv, Theme.F_LABEL, Theme.GOLD, HALF)
		At(col.head, content, x, colY)
		if col.head.SetWordWrap then col.head:SetWordWrap(false) end
		for index = 1, ns.TRADE_MAX do
			local slot = Theme.CreateTile(tv, RLAY.tileW, RLAY.tileH, { kind = "Frame" })
			At(slot, content, x + (index - 1) * slotStep, tileY)
			slot.plus = Text(slot, Theme.F_TITLE or Theme.F_LABEL, Theme.MUTED, RLAY.tileW)
			slot.plus:SetPoint("CENTER", slot, "CENTER", 0, 0)
			slot.plus:SetJustifyH("CENTER")
			slot.plus:SetText(L.TRADE_SLOT)
			col.slots[index] = slot
			local tile = ns.ReserveNewTile(frame, tv)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
			tile.theirs = side == "theirs"
			if side == "mine" then
				tile:SetScript("OnClick", function(t) if t.tradeSpec then ns:TradeToggleOffer(t.tradeSpec.id) end end)
			end
			tile.onEnter = function(t) SpecTip(ns, t) end
			tile.onLeave = HideTip
			tile:Hide()
			col.tiles[index] = tile
		end
		local stateX = x + ns.TRADE_MAX * slotStep + LAY.stateX
		col.state = Text(tv, Theme.F_SMALL, Theme.MUTED_LIGHT, HALF - (stateX - x))
		At(col.state, content, stateX, tileY - 4)
		if col.state.SetWordWrap then col.state:SetWordWrap(true) end
		tv.cols[side] = col
	end
	local buttonY = tileY - RLAY.tileH - 10
	tv.validate = Theme.CreateButton(tv, 140, "sm", L.TRADE_VALIDATE, function(b)
		if b.qcEnabled ~= false then ns:TradeValidate() end
	end, "primary")
	At(tv.validate, content, 0, buttonY)
	tv.cancel = Theme.CreateButton(tv, "auto", "sm", L.TRADE_CANCEL, function() ns:TradeCancel() end, "outline")
	tv.cancel:SetPoint("LEFT", tv.validate, "RIGHT", 8, 0)
	tv.warn = Text(tv, Theme.F_SMALL, Theme.RED, INNER - 340)
	At(tv.warn, content, 340, buttonY - 4)
	if tv.warn.SetWordWrap then tv.warn:SetWordWrap(true) end
	-- la Réserve : clic pour proposer ou retirer
	local pickY = buttonY - RLAY.actionH - 12
	tv.pickHead = Text(tv, Theme.F_LABEL, Theme.LABEL, INNER)
	At(tv.pickHead, content, 0, pickY)
	if tv.pickHead.SetWordWrap then tv.pickHead:SetWordWrap(false) end
	local gridTop = pickY - 20
	local cols = math.floor((INNER + RLAY.gap) / (RLAY.tileW + RLAY.gap))
	local gridRows = math.max(1, math.floor((gridTop - ui.PAGER_Y - 8 + RLAY.gap) / (RLAY.tileH + RLAY.gap)))
	tv.pickCols, tv.pickRows = cols, gridRows
	tv.grid = CreateFrame("Frame", nil, tv)
	At(tv.grid, content, 0, gridTop)
	tv.grid:SetSize(INNER, gridRows * (RLAY.tileH + RLAY.gap))
	tv.picks = {}
	for index = 1, cols * gridRows do
		local tile = ns.ReserveNewTile(frame, tv.grid)
		local slot = index - 1
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", tv.grid, "TOPLEFT", (slot % cols) * (RLAY.tileW + RLAY.gap),
			-math.floor(slot / cols) * (RLAY.tileH + RLAY.gap))
		tile:SetScript("OnClick", function(t)
			if t.tradeSpec and t.pickable ~= false then ns:TradeToggleOffer(t.tradeSpec.id) end
		end)
		tile.onEnter = function(t) SpecTip(ns, t) end
		tile.onLeave = HideTip
		tile:Hide()
		tv.picks[index] = tile
	end
	tv.pickEmpty = Text(tv, Theme.F_BODY, Theme.MUTED_LIGHT, INNER - 20)
	At(tv.pickEmpty, content, 10, gridTop - 20)
	ui.Pager(tv, content)
	tv:Hide()
end

local ALL_ACTIVE = { "validate", "cancel", "warn", "pickHead", "grid", "pickEmpty" }
local ALL_IDLE = { "target", "accept", "decline", "abandon", "histHead", "histEmpty" }
local function ShowList(tv, keys, on)
	for _, key in ipairs(keys) do if on then tv[key]:Show() else tv[key]:Hide() end end
end

local function PaintColumn(self, tv, col, list, theirs, state, stateRole)
	for index, tile in ipairs(col.tiles) do
		local item = list[index]
		local spec = item and (theirs and item.spec or self:SpecimenGet(item)) or nil
		tile.tradeSpec = spec
		if spec and self:ReserveTilePaint(tile, spec) then
			tile:SetSelected(false)
			tile:SetAccent(spec.shiny and Theme.GOLD_LIGHT or nil)
			tile:Show()
			col.slots[index].plus:Hide()
		else
			tile:Hide()
			col.slots[index].plus:Show()
		end
	end
	col.state:SetText(state)
	col.stateRole = stateRole
	local c = stateRole == "trade.ok" and Theme.GREEN or Theme.MUTED_LIGHT
	col.state:SetTextColor(c[1], c[2], c[3], 1)
	col.state.azKeep = nil
end

local function RefreshHistory(self, frame, tv)
	local log = self:TradeLog()
	local rows = #tv.hist
	local maxOffset = math.max(0, #log - rows)
	frame.tradeOffset = math.max(0, math.min(frame.tradeOffset or 0, maxOffset))
	for index, row in ipairs(tv.hist) do
		local entry = log[frame.tradeOffset + index]
		if entry then
			local day = entry.at and Call(G("date"), "%d/%m/%Y", entry.at) or "?"
			row.line:SetText(self:F(entry.result == "done" and "TRADE_HIST_LINE" or "TRADE_HIST_ABORT", day, tostring(entry.peer)))
			row.sub:SetText(self:F("TRADE_HIST_GAVE", self:TradeListText(entry.gave)) .. L.TRADE_HIST_SEP
				.. self:F("TRADE_HIST_GOT", self:TradeListText(entry.got)))
			row.line:Show(); row.sub:Show()
		else
			row.line:SetText(""); row.sub:SetText("")
			row.line:Hide(); row.sub:Hide()
		end
	end
	if #log == 0 then tv.histEmpty:SetText(L.TRADE_HIST_EMPTY); tv.histEmpty:Show() else tv.histEmpty:Hide() end
	tv.pager:Update(frame.tradeOffset, rows, #log, maxOffset)
	tv.hint:SetText("")
end

local function RefreshPicker(self, frame, tv, s)
	local all = self:ReserveView("stars")
	local cols, rows = tv.pickCols, tv.pickRows
	local totalRows = math.ceil(#all / cols)
	local maxOffset = math.max(0, totalRows - rows)
	frame.tradeOffset = math.max(0, math.min(frame.tradeOffset or 0, maxOffset))
	local first = frame.tradeOffset * cols
	local open = s.phase == "open"
	for index, tile in ipairs(tv.picks) do
		local spec = all[first + index]
		tile.tradeSpec = spec
		if spec then
			self:ReserveTilePaint(tile, spec)
			local offered = false
			for _, id in ipairs(s.mine) do if id == spec.id then offered = true end end
			local ok, why = self:SpecimenCanTrade(spec.id, true)
			tile.offered, tile.why = offered, (not ok) and why or nil
			tile.pickable = open and (offered or (ok and #s.mine < ns.TRADE_MAX))
			tile:SetSelected(offered)
			if ns.AllureShowRing then ns.AllureShowRing(tile, offered, frame) end
			tile:SetAccent((offered and Theme.GOLD) or (spec.shiny and Theme.GOLD_LIGHT) or nil)
			tile:SetAlpha((ok or offered) and 1 or Theme.DIM_ALPHA or 0.45)
			tile:Show()
		else
			tile:Hide()
		end
	end
	tv.pickHead:SetText(self:F("TRADE_PICK_HEAD", #s.mine, ns.TRADE_MAX))
	if #all == 0 then tv.pickEmpty:SetText(L.TRADE_PICK_EMPTY); tv.pickEmpty:Show() else tv.pickEmpty:SetText(""); tv.pickEmpty:Hide() end
	tv.pager:Update(frame.tradeOffset, rows, totalRows, maxOffset)
	tv.hint:SetText(L.TRADE_PICK_HINT)
end

local function StatusText(self, s, now)
	local peer = Short(self, s.peer)
	if s.recovered then
		local pending = Pending(self)
		local old = pending and Epoch() - (tonumber(pending.at) or 0) >= ns.TRADE_DOUBT_ABANDON
		return self:F(old and "TRADE_ST_DOUBT_OLD" or "TRADE_ST_DOUBT", peer)
	end
	local left = math.max(0, math.ceil((s.expires or now) - now))
	if s.phase == "inviting" then
		return s.rung and self:F("TRADE_ST_RUNG", peer, left) or self:F("TRADE_ST_INVITING", peer)
	elseif s.phase == "invited" then return self:F("TRADE_ST_INVITED", peer, left)
	elseif s.phase == "locking" then return self:F("TRADE_ST_LOCK", peer)
	elseif s.phase == "prepared" then return self:F("TRADE_ST_PREPARED", peer) end
	if s.myValid and not s.theirValid then return self:F("TRADE_ST_WAIT_THEM", peer) end
	if s.theirValid and not s.myValid then return self:F("TRADE_ST_WAIT_YOU", peer) end
	return self:F("TRADE_ST_OPEN", peer)
end

local function SideState(s, valid)
	if s.phase == "locking" then return L.TRADE_STATE_LOCK, "trade.state" end
	if s.phase == "prepared" then return L.TRADE_STATE_DONE, "trade.ok" end
	if valid then return L.TRADE_STATE_VALID, "trade.ok" end
	return L.TRADE_STATE_WAIT, "trade.state"
end

function ns:TradeRefreshView(frame, pane)
	local tv = pane and pane.trade
	if not tv then return end
	frame.header:SetTitle(L.TRADE_TITLE)
	frame.header:SetSubtitle(L.TRADE_SUB)
	local s = S.session
	if not s and Pending(self) then
		self:TradeRecover()
		s = S.session
	end
	local now = Clock()
	local window = s and (s.phase == "open" or s.phase == "locking" or (s.phase == "prepared" and not s.recovered))
	tv.window = window and true or false
	for _, col in pairs(tv.cols) do
		col.head:Show(); col.state:Show()
		for _, slot in ipairs(col.slots) do slot:Show() end
		if not window then
			col.head:Hide(); col.state:Hide()
			for _, slot in ipairs(col.slots) do slot:Hide() end
			for _, tile in ipairs(col.tiles) do tile:Hide(); tile.tradeSpec = nil end
		end
	end
	for _, row in ipairs(tv.hist) do if window then row.line:Hide(); row.sub:Hide() end end
	ShowList(tv, ALL_ACTIVE, window)
	ShowList(tv, ALL_IDLE, not window)
	if window then
		tv.status:SetText(StatusText(self, s, now))
		tv.note:SetText("")
		local me = Short(self, self:TrainerMe())
		tv.cols.mine.head:SetText(self:F("TRADE_YOU", me))
		tv.cols.theirs.head:SetText(Short(self, s.peer))
		local mineState, mineRole = SideState(s, s.myValid)
		local theirState, theirRole = SideState(s, s.theirValid)
		PaintColumn(self, tv, tv.cols.mine, s.mine, false, mineState, mineRole)
		PaintColumn(self, tv, tv.cols.theirs, s.theirs, true, theirState, theirRole)
		local open = s.phase == "open"
		local short = open and self:TradeRoom() or 0
		local why
		if short > 0 then why = self:F("TRADE_ERR_full", short)
		elseif open and #s.mine + #s.theirs == 0 then why = L.TRADE_ERR_empty end
		tv.warn:SetText(short > 0 and why or "")
		tv.validate:SetText(s.myValid and L.TRADE_VALIDATED or L.TRADE_VALIDATE)
		Enable(tv.validate, open and not s.myValid and why == nil, why)
		Enable(tv.cancel, not s.prepared)
		RefreshPicker(self, frame, tv, s)
		return
	end
	-- sans fenêtre : invitation, attente, échange en suspens, historique
	tv.target:Hide(); tv.accept:Hide(); tv.decline:Hide(); tv.abandon:Hide()
	if s then
		tv.status:SetText(StatusText(self, s, now))
		tv.note:SetText("")
		if s.phase == "invited" then
			tv.accept:Show(); tv.decline:Show()
		elseif s.recovered then
			local pending = Pending(self)
			local old = pending and Epoch() - (tonumber(pending.at) or 0) >= ns.TRADE_DOUBT_ABANDON
			Enable(tv.abandon, old, L.TRADE_ERR_doubt)
			tv.abandon:Show()
		else
			tv.decline:Hide()
			tv.target:SetText(L.TRADE_CANCEL)
			tv.targetMode = "cancel"
			Enable(tv.target, true)
			tv.target:Show()
		end
	else
		tv.status:SetText(L.TRADE_ST_IDLE)
		tv.note:SetText(L.TRADE_INTRO)
		tv.target:SetText(L.RES_TRADE_TARGET)
		tv.targetMode = "target"
		local why, arg = Blocked(self)
		Enable(tv.target, why == nil or why == "combat",
			why and (arg ~= nil and self:F("TRADE_ERR_" .. why, arg) or L["TRADE_ERR_" .. why]) or nil)
		tv.target:Show()
	end
	RefreshHistory(self, frame, tv)
end

-- Style Azeroth : encres mesurées (AzerothStyle.lua, rôles trade.*)
do
	local posts = ns.CARNET_PAGE_POSTS
	local skins = ns.CARNET_PAGE_SKINS
	local paint = ns.CarnetRolePaint
	if type(posts) == "table" and paint then
		local base = posts.reserve
		posts.reserve = function(self, frame)
			if base then base(self, frame) end
			local tv = frame.res and frame.res.trade
			if not (tv and tv:IsShown()) then return end
			paint(tv.status, "trade.status")
			paint(tv.note, "reserve.text")
			paint(tv.histHead.label, "section.label")
			paint(tv.histEmpty, "reserve.text")
			paint(tv.pickHead, "trade.status")
			paint(tv.pickEmpty, "reserve.text")
			paint(tv.warn, "reserve.full")
			paint(tv.hint, "reserve.hint")
			for _, row in ipairs(tv.hist) do paint(row.line, "trade.histName"); paint(row.sub, "trade.histText") end
			for _, col in pairs(tv.cols) do
				paint(col.head, "trade.head")
				paint(col.state, col.stateRole or "trade.state")
				for _, slot in ipairs(col.slots) do paint(slot.plus, "trade.slot") end
				for _, tile in ipairs(col.tiles) do
					if tile.tradeSpec and tile.label then paint(tile.label, tile.tradeSpec.shiny and "reserve.shiny" or "reserve.name") end
				end
			end
			for _, tile in ipairs(tv.picks) do
				if tile.tradeSpec and tile.label then paint(tile.label, tile.tradeSpec.shiny and "reserve.shiny" or "reserve.name") end
			end
		end
	end
	if type(skins) == "table" and ns.CarnetInkPager then
		skins.trade = function(self, frame)
			local tv = frame.res and frame.res.trade
			if tv then ns.CarnetInkPager(tv.pager) end
		end
	end
end

if ns.Mark then ns.Mark("CaptureTrades") end
