-- CaptureQueue.lua -- Lot 1 : bouton filet, file d'attente des captures, étoiles des spécimens (QuestCompanion 2.0)
--
-- Retour des joueurs : la fenêtre « Capturer ? » qui s'ouvrait à chaque coup
-- fatal gênait (en plein pack, elle se remplaçait sans cesse). Désormais :
--   * chaque monstre abattu qui VAUT LE COUP rejoint une file d'attente :
--     espèce (ou version) pas encore capturée, brillante, ou spécimen qui
--     pourrait battre le tien (moins de 3 étoiles) ;
--   * chacun y reste CAPTURE_QUEUE_TIME secondes, comptées à partir de la FIN
--     du combat (en plein pack, rien ne s'efface) ;
--   * un petit bouton filet sur le cadre du compagnon, visible seulement si la
--     file n'est pas vide, avec un compteur ; doré et scintillant si une
--     brillante attend ;
--   * clic : capture du meilleur candidat (brillante > espèce nouvelle > plus
--     rare > amélioration d'étoiles), la scène de capture se joue
--     (CaptureStage.lua) ; clic droit : la liste (choisir, aides, tout ignorer).
--     Deux candidats ou plus : le clic propose le choix (CaptureBatch.lua) ;
--   * le compte à rebours s'arrête dès le clic (filet, bandeau) : rien ne
--     s'efface pendant qu'on choisit ni pendant la scène (ns:CaptureQueueHold).
-- Étoiles : 2.15.0, la qualité (1 à 3 étoiles) est tirée AU COUP FATAL selon
-- le rang (CaptureSpecimens.lua, CAPTURE_QUALITY_ODDS) et portée par le
-- candidat (candidate.stars) ; chaque capture devient un spécimen (Codex ou
-- Réserve). Le filet ne vient plus que si ça vaut le coup (CaptureQueueReason).
-- Le déroulé d'un essai reste celui de Capture.lua (CaptureThrow, CaptureTick,
-- CaptureResolve) : ce fichier choisit la cible et habille le reste.
-- Réglage : page « Au jour le jour » (« Capturer les monstres abattus »).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_QUEUE_TIME = 30        -- s par candidat, à partir de la fin du combat
ns.CAPTURE_QUEUE_MAX = 12         -- au-delà, les moins intéressants sortent
ns.CAPTURE_STAR_MAX = 3
-- (2.15.0 : les chances de qualité sont dans CaptureSpecimens.lua,
-- CAPTURE_QUALITY_ODDS ; ns.CAPTURE_STAR_ODDS y reste, celles d'un monstre ordinaire)
-- 2.12.1 : les étoiles et le glyphe du filet viennent du client. Étoiles :
-- l'atlas « auctionhouse-icon-favorite » (pleine) et sa variante « -off »
-- (vide) ; en texture simple, l'étoile des marqueurs de raid en repli.
ns.CAPTURE_STAR_ATLAS = { full = "auctionhouse-icon-favorite", empty = "auctionhouse-icon-favorite-off" }
ns.CAPTURE_STAR_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local NET_ICON = "Interface\\Icons\\Spell_Nature_Web"
-- 2.11.0 (fiche 12) : le glyphe du filet est l'icône du jeu INV_Misc_Net_01
-- (ns.CaptureArtPaint, rôle « icon »), en couleurs. Rend toujours false
-- (2.12.1 : plus de glyphe à nous à teinter).
local function PaintNetIcon(tex)
	if not tex then return false end
	local source = ns.CaptureArtPaint and ns.CaptureArtPaint(tex, "icon")
	if not source then tex:SetTexture(NET_ICON) end
	return false
end
ns.CapturePaintNetIcon = PaintNetIcon
local ICON_GAME_SHINY, ICON_GAME_REST = { 1, 0.85, 0.4 }, Theme.WHITE   -- 2.11.2 : le blanc du socle
-- Le filet (2.1.0) : un vrai bouton de 44 px, à côté du compagnon (pas sur
-- son portrait, où il passait inaperçu), qui suit sa taille et bat en doré
-- quand un candidat arrive ; et un bandeau « Capture possible ».
local NET_SIZE = 44
ns.CAPTURE_NET_SIZE = NET_SIZE
ns.CAPTURE_NET_GAP = 8            -- px entre le cadre du compagnon et le filet
ns.CAPTURE_NET_PULSE = 4          -- s de battement doré à l'arrivée d'un candidat
-- 2.15.0 : pastille de qualité (étoiles) au bas du filet : taille, centre (y depuis le bas)
ns.CAPTURE_NET_BADGE = { w = 40, h = 13, y = -2, star = 10 }
ns.CAPTURE_TOAST_SECONDS = 3      -- s d'affichage du bandeau « Capture possible » (2.9.0 : 5 -> 3)
local TOAST_W, TOAST_H, TOAST_ICON = 384, 102, 34
ns.CAPTURE_MUTE_CHOICES = { 5, 15, 30, 60 }   -- minutes de sourdine proposées par le bandeau
-- Sons (2.2.0) : des kits du client, par numéro (SoundKitConstants.lua de
-- l'interface de Blizzard ; les numéros sont les mêmes sur tous les clients) :
--   ready : UI_PET_BATTLES_TRAP_READY (le piège des mascottes est prêt)
--   throw : UI_PET_BATTLE_CAMERA_MOVE_IN
--   ok    : LFG_REWARDS (la petite musique de récompense)
--   shiny : UI_LEGENDARY_LOOT_TOAST (fanfare)
--   fail  : UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL
ns.CAPTURE_SOUNDS = { ready = 28814, throw = 32047, ok = 17316, shiny = 63971, fail = 43501 }
local LIST_W, LIST_ROW_H, LIST_ROWS = 300, 24, 6

local RANK_ORDER = { trivial = 0, minus = 0, normal = 1, elite = 2, rare = 3, rareelite = 4, worldboss = 5 }

local FR = {
	CAPTURE_Q_TITLE        = "À capturer",
	CAPTURE_Q_COUNT        = "Filet : %d à capturer",
	CAPTURE_Q_REASON_shiny = "Brillante !",
	CAPTURE_Q_REASON_new   = "Pas encore capturée",
	CAPTURE_Q_REASON_stars = "Peut battre ton spécimen %s",
	CAPTURE_Q_WAIT         = "après le combat",
	CAPTURE_Q_LEFT         = "%d s",
	CAPTURE_Q_CLICK        = "Clic : capturer %s",
	-- 2.10.0 : pas de capture en combat (déplacée de CaptureBatch.lua, chargé après)
	CAPTURE_BATCH_COMBAT   = "Pas de capture en combat : le filet attend la fin du combat.",
	CAPTURE_Q_COMBAT       = "Après le combat : le filet attend.",
	CAPTURE_STAGE_COMBAT   = "Combat : la capture continue, le résultat arrive dans le chat.",
	CAPTURE_Q_RIGHT        = "Clic droit : la liste (choisir, aides, tout ignorer)",
	CAPTURE_Q_NOTHING      = "Rien à capturer pour l'instant : abats un monstre qui manque à ta collection.",
	CAPTURE_Q_IGNORE       = "Tout ignorer",
	CAPTURE_Q_EMPTY        = "Rien à capturer pour l'instant.",
	CAPTURE_Q_LIST_HINT    = "Clic sur une ligne : la capturer. L'aide choisie sert au prochain essai.",
	CAPTURE_Q_AID          = "Aide : %s",
	CAPTURE_TOAST_TITLE    = "Capture possible",
	CAPTURE_TOAST_MORE     = "et %d de plus",
	CAPTURE_TOAST_HINT     = "Clic : préparer · Maj+clic : lancer · clic droit : la liste",
	CAPTURE_TOAST_NEW      = "Jamais capturée",
	CAPTURE_TOAST_OWNED    = "Déjà capturée %s",
	CAPTURE_TOAST_OWNED_SHINY = "brillante %s",
	CAPTURE_TOAST_BETTER   = "peut faire mieux",
	CAPTURE_TOAST_CHANCE   = "%d %% de chance",
	CAPTURE_TOAST_SURE     = "capture assurée",
	CAPTURE_TOAST_IGNORE   = "Ignorer",
	CAPTURE_TOAST_IGNORE_TIP = "Retire cette créature du filet (les autres restent).",
	CAPTURE_TOAST_MUTE     = "Sourdine",
	CAPTURE_TOAST_MUTE_TIP = "Plus de bandeau ni de son pendant un moment ; le filet reste.",
	CAPTURE_TOAST_MUTE_MIN = "%d min",
	CAPTURE_TOAST_MUTE_HOUR = "1 h",
	CAPTURE_TOAST_MUTE_CANCEL = "Annuler",
	CAPTURE_Q_MUTED        = "Sourdine : encore %s",
	CAPTURE_MSG_MUTED      = "Capture en sourdine pendant %s : plus de bandeau ni de son. Le filet reste (/qc filet sourdine off pour réactiver).",
	CAPTURE_MSG_UNMUTED    = "Fin de la sourdine : bandeau et sons de capture de retour.",
	OPT_DAILY_CAPTURE_SOUND = "Sons de capture",
	OPT_DAILY_CAPTURE_SOUND_DESC = "Un carillon quand une capture est possible, une petite musique quand elle réussit (fanfare pour une brillante).",
	OPT_DAILY_CAPTURE_TOAST = "Bandeau « Capture possible »",
	OPT_DAILY_CAPTURE_TOAST_DESC = "Un bandeau dès qu'un monstre abattu peut être capturé (après le combat). Clic dessus : le filet.",
	CAPTURE_STARS_LABEL    = "Qualité : %s",
	CAPTURE_MSG_STARS      = "%s : %s.",
	CAPTURE_MSG_STARS_BEST = "%s : %s, ton meilleur spécimen ! Il entre au Codex, l'ancien passe en Réserve.",
	CAPTURE_MSG_STARS_KEPT = "%s : %s, rangé dans ta Réserve. Ton spécimen à %d étoiles reste au Codex.",
	CAPTURE_STAGE_BEST     = "Meilleur spécimen !",
	CAPTURE_STAGE_KEPT     = "Le tien garde ses %d étoiles",
	-- 2.15.0 : pourquoi le filet le propose (infobulle, liste), en court
	CAPTURE_Q_TAG_new      = "nouvelle",
	CAPTURE_Q_TAG_shiny    = "brillante",
	CAPTURE_Q_TAG_stars    = "meilleure que la tienne %s",
	CAPTURE_Q_TAG_pinned   = "épinglée",
	CAPTURE_Q_TAG_hunt     = "chasse",
	CAPTURE_Q_CLICK_PREP   = "Clic : préparer la capture de %s (aides, Lancer, Passer)",
	CAPTURE_Q_SHIFT_DIRECT = "Maj+clic ou raccourci : lancer tout de suite",
	OPT_DAILY_CAPTURE_DIRECT = "Lancer directement au clic",
	OPT_DAILY_CAPTURE_DIRECT_DESC = "Le clic sur le filet lance tout de suite (l'aide choisie dans la liste sert), sans la carte de préparation. Maj+clic lance toujours tout de suite.",
}
local EN = {
	CAPTURE_Q_TITLE        = "To capture",
	CAPTURE_Q_COUNT        = "Net: %d to capture",
	CAPTURE_Q_REASON_shiny = "Shiny!",
	CAPTURE_Q_REASON_new   = "Not captured yet",
	CAPTURE_Q_REASON_stars = "Could beat your %s specimen",
	CAPTURE_Q_WAIT         = "after combat",
	CAPTURE_Q_LEFT         = "%ds",
	CAPTURE_Q_CLICK        = "Click: capture %s",
	CAPTURE_BATCH_COMBAT   = "No capturing in combat: the net waits for the fight to end.",
	CAPTURE_Q_COMBAT       = "After the fight: the net is waiting.",
	CAPTURE_STAGE_COMBAT   = "Combat: the capture goes on, the result will show in chat.",
	CAPTURE_Q_RIGHT        = "Right-click: the list (pick, aids, ignore all)",
	CAPTURE_Q_NOTHING      = "Nothing to capture right now: defeat a monster your collection is missing.",
	CAPTURE_Q_IGNORE       = "Ignore all",
	CAPTURE_Q_EMPTY        = "Nothing to capture right now.",
	CAPTURE_Q_LIST_HINT    = "Click a line to capture it. The chosen aid is used on the next try.",
	CAPTURE_Q_AID          = "Aid: %s",
	CAPTURE_TOAST_TITLE    = "Capture possible",
	CAPTURE_TOAST_MORE     = "and %d more",
	CAPTURE_TOAST_HINT     = "Click: prepare · Shift-click: throw · right-click: the list",
	CAPTURE_TOAST_NEW      = "Never captured",
	CAPTURE_TOAST_OWNED    = "Already captured %s",
	CAPTURE_TOAST_OWNED_SHINY = "shiny %s",
	CAPTURE_TOAST_BETTER   = "could do better",
	CAPTURE_TOAST_CHANCE   = "%d%% chance",
	CAPTURE_TOAST_SURE     = "guaranteed capture",
	CAPTURE_TOAST_IGNORE   = "Ignore",
	CAPTURE_TOAST_IGNORE_TIP = "Removes this creature from the net (the others stay).",
	CAPTURE_TOAST_MUTE     = "Mute",
	CAPTURE_TOAST_MUTE_TIP = "No banner and no sound for a while; the net stays.",
	CAPTURE_TOAST_MUTE_MIN = "%d min",
	CAPTURE_TOAST_MUTE_HOUR = "1 h",
	CAPTURE_TOAST_MUTE_CANCEL = "Cancel",
	CAPTURE_Q_MUTED        = "Muted: %s left",
	CAPTURE_MSG_MUTED      = "Capture muted for %s: no banner and no sound. The net stays (/qc filet sourdine off to turn it back on).",
	CAPTURE_MSG_UNMUTED    = "Mute over: capture banner and sounds are back.",
	OPT_DAILY_CAPTURE_SOUND = "Capture sounds",
	OPT_DAILY_CAPTURE_SOUND_DESC = "A chime when a capture is possible, a little tune when it succeeds (a fanfare for a shiny).",
	OPT_DAILY_CAPTURE_TOAST = "\"Capture possible\" banner",
	OPT_DAILY_CAPTURE_TOAST_DESC = "A banner as soon as a defeated monster can be captured (after combat). Click it: the net.",
	CAPTURE_STARS_LABEL    = "Quality: %s",
	CAPTURE_MSG_STARS      = "%s: %s.",
	CAPTURE_MSG_STARS_BEST = "%s: %s, your best specimen! It enters the Codex, the old one goes to the Reserve.",
	CAPTURE_MSG_STARS_KEPT = "%s: %s, stored in your Reserve. Your %d-star specimen stays in the Codex.",
	CAPTURE_STAGE_BEST     = "Best specimen yet!",
	CAPTURE_STAGE_KEPT     = "Yours keeps its %d stars",
	CAPTURE_Q_TAG_new      = "new",
	CAPTURE_Q_TAG_shiny    = "shiny",
	CAPTURE_Q_TAG_stars    = "better than yours %s",
	CAPTURE_Q_TAG_pinned   = "pinned",
	CAPTURE_Q_TAG_hunt     = "hunt",
	CAPTURE_Q_CLICK_PREP   = "Click: prepare to capture %s (aids, Throw, Skip)",
	CAPTURE_Q_SHIFT_DIRECT = "Shift-click or key: throw right away",
	OPT_DAILY_CAPTURE_DIRECT = "Throw right away on click",
	OPT_DAILY_CAPTURE_DIRECT_DESC = "Clicking the net throws right away (with the aid chosen in the list), without the preparation card. Shift-click always throws right away.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_QUEUE_STRINGS = { fr = FR, en = EN } end

-- 2.15.0 : plus de réglages « Recaptures » (communes, élites, rares) : le
-- filet ne revient que pour mieux (CaptureQueueReason). Les valeurs gardées
-- (companionRetry*) restent dans la sauvegarde, ignorées.
-- 2.15.0 : « Lancer directement au clic » (coupé : le clic ouvre la carte de préparation)
ns.RegisterDefaults({ companionCaptureToast = true, companionCaptureSound = true, companionCaptureDirect = false })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local present, presentSound, presentDirect, at = false, false, false, 1
	for index, row in ipairs(ns.DAILY_OPTION_ROWS) do
		if row.key == "companionCaptureToast" then present = true end
		if row.key == "companionCaptureSound" then presentSound = true end
		if row.key == "companionCaptureDirect" then presentDirect = true end
		if row.key == "companionCapture" or row.key == "companionCaptureAnim" then at = index + 1 end
	end
	if not presentDirect then
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = "companionCaptureDirect", label = "OPT_DAILY_CAPTURE_DIRECT", kind = "bool",
			describe = function() return L.OPT_DAILY_CAPTURE_DIRECT_DESC end })
		at = at + 1
	end
	if not present then
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = "companionCaptureToast", label = "OPT_DAILY_CAPTURE_TOAST", kind = "bool",
			describe = function() return L.OPT_DAILY_CAPTURE_TOAST_DESC end })
		at = at + 1
	end
	if not presentSound then
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = "companionCaptureSound", label = "OPT_DAILY_CAPTURE_SOUND", kind = "bool",
			describe = function() return L.OPT_DAILY_CAPTURE_SOUND_DESC end })
	end
end

-- Joue un son de capture (clé de ns.CAPTURE_SOUNDS), sauf réglage coupé ou
-- sourdine ; rend true si le client a accepté de le jouer
function ns:CapturePlaySound(key)
	local id = ns.CAPTURE_SOUNDS[key]
	if not id or self:DB().companionCaptureSound == false or self:CaptureMuted() then return false end
	local play = rawget(_G, "PlaySound")   -- (défini avant les aides du fichier)
	if type(play) ~= "function" then return false end
	local ok, willPlay = pcall(play, id)
	return ok and willPlay ~= false
end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function InCombat()
	if Call(G("InCombatLockdown")) then return true end
	return Call(G("UnitAffectingCombat"), "player") and true or false
end
-- 2.10.0 : en combat, le filet ne se lance pas (rien ne s'ouvre au milieu de
-- l'écran) : un message court, au plus toutes les 5 s, et le son d'échec
ns.CAPTURE_COMBAT_MSG_GAP = 5
function ns:CaptureRefuseCombat()
	local now = Clock()
	local state = self:CaptureState()
	if not state.combatMsgAt or now - state.combatMsgAt >= ns.CAPTURE_COMBAT_MSG_GAP or now < state.combatMsgAt then
		state.combatMsgAt = now
		self:Print(L.CAPTURE_BATCH_COMBAT)
		self:CapturePlaySound("fail")
	end
	return false
end
local function Enabled()
	local on = ns.CompanionOn and ns.CompanionOn() or false
	return on and ns:DB().companionCapture ~= false
end

-- 2.15.0 : un candidat bloqué (Réserve pleine, ns:CaptureBlockedReason) :
-- un message (au plus toutes les 5 s) et le son d'échec. Rend true si refusé.
function ns:CaptureRefuseBlocked(candidate)
	local why = self.CaptureBlockedReason and self:CaptureBlockedReason(candidate)
	if not why then return false end
	local now = Clock()
	local state = self:CaptureState()
	if not state.blockedMsgAt or now - state.blockedMsgAt >= ns.CAPTURE_COMBAT_MSG_GAP or now < state.blockedMsgAt then
		state.blockedMsgAt = now
		if why == "reserveFull" then
			self:Print(self:F("CAPTURE_MSG_RESERVE_FULL", self:SpecimenReserveCount(), self:ReserveCapacity(),
				candidate.name or tostring(candidate.npcID)))
		end
		self:CapturePlaySound("fail")
	end
	return true
end
local function Tooltip() local t = G("GameTooltip"); if type(t) == "table" and t.SetOwner then return t end end

-- ---------------------------------------------------------------------------
-- Étoiles
-- ---------------------------------------------------------------------------
-- Les fiches d'avant les étoiles valent 1 étoile (une fois, à la lecture)
do
	local base = ns.CaptureData
	if base then
		function ns:CaptureData(...)
			local capture = base(self, ...)
			if not capture.starsV then
				for _, entry in pairs(capture.creatures) do
					if type(entry) == "table" then
						if entry.normal ~= false and entry.stars == nil then entry.stars = 1 end
						if entry.shiny and entry.shinyStars == nil then entry.shinyStars = 1 end
					end
				end
				capture.starsV = 1
			end
			return capture
		end
	end
end

local EarliestAt

-- Étoiles d'une fiche (sans relire les données) : 1 à 3, ou nil
local function EntryStars(entry, shiny)
	if type(entry) ~= "table" then return nil end
	local stars
	if shiny then
		if not entry.shiny then return nil end
		stars = entry.shinyStars
	else
		if entry.normal == false then return nil end
		stars = entry.stars
	end
	return math.max(1, math.min(ns.CAPTURE_STAR_MAX, math.floor(tonumber(stars) or 1)))
end

-- 1 à 3, ou nil si cette version n'est pas capturée
function ns:CaptureStars(npcID, shiny)
	return EntryStars(self:CaptureData().creatures[tonumber(npcID) or npcID], shiny)
end

-- (2.15.0 : plus de tirage après la capture ; la qualité est celle du
-- candidat, tirée au coup fatal par ns:CaptureRollQuality)

-- Texte des étoiles, pour le chat et les fiches. 2.12.1 : balises d'atlas
-- du client (|A), l'étoile dorée pleine, sa variante grise « -off » vide
local function StarIcon(full, size)
	local atlas = full and ns.CAPTURE_STAR_ATLAS.full or ns.CAPTURE_STAR_ATLAS.empty
	return string.format("|A:%s:%d:%d|a", atlas, size, size)
end
function ns:CaptureStarsText(stars, size)
	stars = tonumber(stars)
	if not stars then return "" end
	local parts = {}
	for index = 1, ns.CAPTURE_STAR_MAX do parts[index] = StarIcon(index <= stars, size or 12) end
	return table.concat(parts)
end

-- La Ménagerie : chaque espèce porte ses étoiles (normale, brillante)
do
	local base = ns.MenagerieList
	if base then
		function ns:MenagerieList(...)
			local list, stats = base(self, ...)
			local creatures = self:CaptureData().creatures
			-- la fiche lue directement : pas de CaptureData par espèce
			for _, item in ipairs(list or {}) do
				local entry = item.captured and creatures[item.npc]
				if type(entry) == "table" then
					item.stars = EntryStars(entry, false)
					item.shinyStars = EntryStars(entry, true)
				end
			end
			return list, stats
		end
	end
end

-- ---------------------------------------------------------------------------
-- La file d'attente
-- ---------------------------------------------------------------------------
function ns:CaptureQueueState()
	local state = self:CaptureState()
	state.queue = state.queue or {}
	return state.queue
end

-- Pourquoi ce monstre vaut le coup (2.15.0) : "shiny" (toujours), "new"
-- (version pas encore au Codex), "stars" (sa qualité, tirée au coup fatal,
-- bat ta meilleure de cette version), "pinned" (espèce épinglée), "hunt"
-- (abattu en mode chasse, ou chasse en cours) ; nil : le filet se tait.
function ns:CaptureQueueReason(candidate)
	if candidate.shiny then return "shiny" end
	local stars = self:CaptureStars(candidate.npcID, false)
	if not stars then return "new" end
	if (tonumber(candidate.stars) or 0) > stars then return "stars" end
	if self.HuntPinned and self:HuntPinned(candidate.npcID) then return "pinned" end
	if candidate.hunt or (self.HuntActive and self:HuntActive()) then return "hunt" end
	return nil
end

-- rang des raisons, pour le tri (la brillante passe avant tout)
local REASON_RANK = { new = 3, stars = 2, pinned = 1, hunt = 0 }
ns.CAPTURE_REASON_RANK = REASON_RANK

-- brillante > espèce nouvelle > meilleur spécimen > épinglée > chasse ;
-- puis la plus belle qualité, le plus rare ; puis celui dont le temps file
-- le plus vite
local function Better(a, b)
	local sa, sb = a.shiny and 1 or 0, b.shiny and 1 or 0
	if sa ~= sb then return sa > sb end
	local na, nb = REASON_RANK[a.reason] or 0, REASON_RANK[b.reason] or 0
	if na ~= nb then return na > nb end
	local qa, qb = tonumber(a.stars) or 1, tonumber(b.stars) or 1
	if qa ~= qb then return qa > qb end
	local ra, rb = RANK_ORDER[a.class] or 1, RANK_ORDER[b.class] or 1
	if ra ~= rb then return ra > rb end
	local ca, cb = a.have or 0, b.have or 0
	if ca ~= cb then return ca < cb end
	local ea, eb = a.expires or math.huge, b.expires or math.huge
	if ea ~= eb then return ea < eb end
	return (a.serial or 0) < (b.serial or 0)
end

-- Remet la file à jour : raisons recalculées (une capture a pu changer la
-- donne), expirés et sans intérêt retirés, tri. Sur place, sans table
-- nouvelle. Renvoie la file.
function ns:CaptureQueuePrune(now)
	local queue = self:CaptureQueueState()
	now = now or Clock()
	-- (l'heure de la file : figée pendant une pause du compte à rebours)
	local clock = self:CaptureQueueClock(now)
	local kept = 0
	for index = 1, #queue do
		local candidate = queue[index]
		candidate.reason = self:CaptureQueueReason(candidate)
		candidate.have = self:CaptureStars(candidate.npcID, candidate.shiny and true or false)
		if candidate.reason and not (candidate.expires and clock > candidate.expires) then
			kept = kept + 1
			queue[kept] = candidate
		end
	end
	for index = #queue, kept + 1, -1 do queue[index] = nil end
	table.sort(queue, Better)
	for index = #queue, ns.CAPTURE_QUEUE_MAX + 1, -1 do queue[index] = nil end
	local state = self:CaptureState()
	state.queuePrunedAt, state.queuePrunedSerial = now, self:CaptureData().serial
	return queue
end

-- ---------------------------------------------------------------------------
-- Le compte à rebours en pause (2.5.0). Retour des joueurs : le temps filait
-- pendant qu'on choisissait, pendant la scène d'un lancer seul ou celle de
-- « Tout capturer », et les suivants s'effaçaient sous leurs yeux. Désormais,
-- dès le clic (filet, bandeau), l'heure de la file se fige : chaque raison de
-- pause (« chooser », « throw », « batch ») est une prise ; quand la dernière
-- est lâchée, chaque candidat reprend avec le temps qui lui restait (expires
-- décalé de la durée de la pause, jamais remis à 30 s). Chaque prise a son
-- contrôle (CAPTURE_HOLD_CHECKS) : l'horloge lâche d'elle-même une prise
-- dont la raison a disparu (scène fermée par Échap, etc.).
-- ---------------------------------------------------------------------------
ns.CAPTURE_HOLD_CHECKS = ns.CAPTURE_HOLD_CHECKS or {}
-- un lancer seul : tant que le filet est en l'air (ou son verdict à l'écran)
ns.CAPTURE_HOLD_CHECKS.throw = function(self)
	local state = self.captureState
	return state ~= nil and (state.rolling ~= nil or state.pending ~= nil)
end

-- L'heure de la file : `now`, ou l'instant de la pause tant qu'elle dure
function ns:CaptureQueueClock(now)
	local state = self.captureState
	return (state and state.queuePausedAt) or now or Clock()
end

function ns:CaptureQueuePaused()
	local state = self.captureState
	return state ~= nil and state.queuePausedAt ~= nil
end

-- Pose une prise (`reason`) : la première fige l'heure de la file
function ns:CaptureQueueHold(reason)
	local state = self:CaptureState()
	state.queueHolds = state.queueHolds or {}
	if not next(state.queueHolds) then state.queuePausedAt = Clock() end
	state.queueHolds[reason] = true
	return true
end

-- Lâche une prise ; la dernière relance le compte : chacun reprend avec le
-- temps qui lui restait. Rend true si la prise était posée.
function ns:CaptureQueueRelease(reason)
	local state = self.captureState
	local holds = state and state.queueHolds
	if not (holds and holds[reason]) then return false end
	holds[reason] = nil
	if next(holds) then return true end
	local pausedAt = state.queuePausedAt
	state.queuePausedAt = nil
	if pausedAt then
		local shift = math.max(0, Clock() - pausedAt)
		for _, candidate in ipairs(self:CaptureQueueState()) do
			if candidate.expires then candidate.expires = candidate.expires + shift end
		end
	end
	return true
end

-- Les prises dont la raison a disparu sont lâchées (horloge de la file).
-- Rend true si le compte a pu reprendre.
function ns:CaptureQueueCheckHolds()
	local state = self.captureState
	local holds = state and state.queueHolds
	if not (holds and next(holds)) then return false end
	local stale
	for reason in pairs(holds) do
		local check = ns.CAPTURE_HOLD_CHECKS[reason]
		if not (check and check(self)) then stale = reason; break end
	end
	if not stale then return false end
	-- (lâchée hors du parcours, puis un nouveau tour pour les autres)
	self:CaptureQueueRelease(stale)
	self:CaptureQueueCheckHolds()
	return true
end

-- La file triée : { guid, npcID, name, class, type, shiny, reason, expires }
-- (expires = nil : le combat n'est pas fini, le compte n'a pas commencé)
function ns:CaptureQueue()
	local list = {}
	for index, candidate in ipairs(self:CaptureQueuePrune()) do list[index] = candidate end
	return list
end

function ns:CaptureQueueBest()
	return self:CaptureQueuePrune()[1]
end

function ns:CaptureQueueHasShiny()
	for _, candidate in ipairs(self:CaptureQueueState()) do
		if candidate.shiny then return true end
	end
	return false
end

-- Le coup fatal (Capture.lua, BestiaryOnKill) : plus de fenêtre, la file.
-- `entry` : { zoneID, npcID } ; `shiny` : brillante abattue
function ns:CaptureOffer(guid, entry, shiny)
	if not Enabled() or type(entry) ~= "table" or not entry.npcID then return nil end
	local queue = self:CaptureQueueState()
	if guid then
		for _, candidate in ipairs(queue) do if candidate.guid == guid then return nil end end
	end
	-- l'aide choisie reste choisie… tant qu'il en reste
	local chosen = self:CaptureState().aid
	if chosen and self:CaptureAidCount(chosen) <= 0 then self:CaptureState().aid = nil end
	local npcID = tonumber(entry.npcID) or entry.npcID
	local book = self.BestiaryData and self:BestiaryData()
	local species = book and book[entry.zoneID] and book[entry.zoneID][entry.npcID] or {}
	local state = self:CaptureState()
	state.queueSerial = (state.queueSerial or 0) + 1
	-- 2.14.0 (bêta 4) : sans nom lu, celui du carnet, de la table livrée ou du client
	local name = species.name
	if not ns.CreatureNameGood(name, npcID) and type(shiny) == "table" then name = shiny.name end
	local candidate = {
		guid = guid, npcID = npcID, zoneID = entry.zoneID,
		name = self:CreatureName(npcID, { name = name }),
		class = species.class or "normal", level = species.level, type = species.type,
		family = species.family, shiny = shiny and true or nil, serial = state.queueSerial,
	}
	-- 2.15.0 : la qualité se tire ici, au coup fatal (selon le rang) ; abattu
	-- en mode chasse, il reste proposé jusqu'au bout de son temps
	candidate.stars = self.CaptureRollQuality and self:CaptureRollQuality(candidate.class) or 1
	if self.HuntActive and self:HuntActive() then candidate.hunt = true end
	candidate.reason = self:CaptureQueueReason(candidate)
	if not candidate.reason then return nil end
	-- en plein combat, le compte attend la fin du combat
	-- (pendant une pause, il garde ses 30 s pour la reprise)
	if not InCombat() then candidate.expires = self:CaptureQueueClock() + ns.CAPTURE_QUEUE_TIME end
	queue[#queue + 1] = candidate
	self:CaptureQueuePrune()
	local still = false
	for _, c in ipairs(queue) do if c == candidate then still = true end end
	if not still then return nil end
	-- le compagnon remarque un 3 étoiles ou une brillante (2.15.0) ; sinon il
	-- signale une nouveauté (pas chaque amélioration, ni chaque proie en chasse)
	if not (self.CaptureGreatLine and self:CaptureGreatLine(candidate)) and candidate.reason == "new"
		and not (candidate.shiny or tonumber(candidate.stars) == 3) then
		self:CompanionSay("CAPTURE_PROMPT", { args = { candidate.name } })
	end
	self:CaptureQueueRefresh()
	-- et le bandeau « Capture possible » ; en combat, il attend la fin du combat
	if not InCombat() then
		self:CaptureToastShow()
		-- 3.0.0 : occasion de capture : la visite des premières captures (GuidedTour.lua)
		if self.TourCaptureOpportunity then pcall(self.TourCaptureOpportunity, self) end
	end
	return candidate
end

-- Retire un candidat (par son guid, ou la table elle-même)
function ns:CaptureQueueRemove(which)
	local queue = self:CaptureQueueState()
	for index = #queue, 1, -1 do
		local candidate = queue[index]
		if candidate == which or (which ~= nil and candidate.guid == which) then table.remove(queue, index) end
	end
	self:CaptureQueueRefresh()
end

function ns:CaptureQueueClear()
	local queue = self:CaptureQueueState()
	for index = #queue, 1, -1 do queue[index] = nil end
	self:CaptureHideQueueList()
	self:CaptureQueueRefresh()
end

-- Fin du combat : le compte à rebours démarre pour ceux qui attendaient
function ns:CaptureQueueStartTimers(now)
	now = self:CaptureQueueClock(now or Clock())
	local started = false
	for _, candidate in ipairs(self:CaptureQueueState()) do
		if not candidate.expires then
			candidate.expires = now + ns.CAPTURE_QUEUE_TIME
			started = true
		end
	end
	return started
end

-- ---------------------------------------------------------------------------
-- Un essai : le meilleur candidat (ou celui choisi), joué par Capture.lua
-- ---------------------------------------------------------------------------
-- ns:CaptureThrow(guid) : sans fenêtre ouverte, prend le candidat de la file
-- (celui de ce guid, sinon le meilleur). Renvoie true si le filet est lancé.
do
	local base = ns.CaptureThrow
	function ns:CaptureThrow(guid)
		-- 2.10.0 : la liste, le bandeau, le raccourci passent tous par ici
		if InCombat() then return self:CaptureRefuseCombat() end
		local state = self:CaptureState()
		-- la liste se referme dès qu'on lance (ou qu'on essaie de lancer)
		self:CaptureHideQueueList()
		-- le verdict du lancer précédent est encore à l'écran : on le referme
		-- et on enchaîne, sans attendre la fin de ses 3,5 s
		if state.rolling and state.rolling.result then
			state.rolling.closeAt = Clock()
			self:CaptureTick(Clock())
		end
		if state.rolling then return false end
		local picked
		if not state.pending or guid then
			local queue = self:CaptureQueuePrune()
			if guid then
				for _, candidate in ipairs(queue) do
					if candidate.guid == guid or candidate == guid then picked = candidate end
				end
			else
				picked = queue[1]
			end
			if not picked then return false end
			-- 2.15.0 : Réserve pleine et il irait en Réserve : refusé, il reste au filet
			if self.CaptureRefuseBlocked and self:CaptureRefuseBlocked(picked) then return false end
			-- 3.0.0 : le filet part (visite guidée, GuidedTour.lua ; avant que
			-- la file ne se vide : ce n'est pas un candidat perdu)
			if self.TourSignal then pcall(self.TourSignal, self, "throw") end
			self:CaptureQueueRemove(picked)
			self:CaptureToastHide()
			self:CapturePlaySound("throw")
			local pending = {}
			for key, value in pairs(picked) do pending[key] = value end
			pending.expires = Clock() + (ns.CAPTURE_WINDOW or 12)
			state.pending = pending
			-- l'aide choisie la dernière fois reste choisie s'il en reste
			if state.aid and self:CaptureAidCount(state.aid) <= 0 then state.aid = nil end
		end
		-- sans la scène animée : la petite fenêtre montre les secousses
		local staged = self.CaptureStageOn and self:CaptureStageOn() or false
		if not staged and self.CaptureShowPrompt then self:CaptureShowPrompt() end
		self:CaptureHideQueueList()
		local thrown = base(self)
		-- le compte à rebours des autres attend la fin de la scène (reprise :
		-- CAPTURE_HOLD_CHECKS.throw, quand le lancer se termine)
		if thrown then self:CaptureQueueHold("throw") end
		-- (lancer depuis la petite fenêtre déjà ouverte : le geste compte aussi)
		if thrown and self.TourSignal then pcall(self.TourSignal, self, "throw") end
		self:CaptureQueueRefresh()
		return thrown
	end
end

-- Première date d'une fiche (firstAt, sinon la plus ancienne de at / shinyAt)
function EarliestAt(entry)
	if type(entry) ~= "table" then return nil end
	local first = tonumber(entry.firstAt)
	if first and first > 0 then return first end
	for _, at in ipairs({ tonumber(entry.at) or false, tonumber(entry.shinyAt) or false }) do
		if at and at > 0 and (not first or at < first) then first = at end
	end
	return first
end

-- Date de la toute première capture : capture.firstAt (posée à la capture
-- suivante, puis figée), sinon la plus ancienne des fiches
function ns:CaptureEarliestAt()
	local capture = self:CaptureData()
	local first = tonumber(capture.firstAt)
	if first and first > 0 then return first end
	first = nil
	for _, entry in pairs(capture.creatures) do
		local at = EarliestAt(entry)
		if at and (not first or at < first) then first = at end
	end
	return first
end

-- Le verdict : étoiles tirées, meilleur spécimen gardé
do
	local base = ns.CaptureResolve
	function ns:CaptureResolve(rolling)
		local target = rolling and rolling.target
		if target then self:CapturePlaySound(rolling.success and (target.shiny and "shiny" or "ok") or "fail") end
		if not (target and rolling.success) then
			local result = base(self, rolling)
			self:CaptureQueueRefresh()
			return result
		end
		local shiny = target.shiny and true or false
		local before = self:CaptureStars(target.npcID, shiny)
		local capture = self:CaptureData()
		local old = capture.creatures[target.npcID]
		local oldAt = old and (shiny and old.shinyAt or old.at)
		-- dates de première capture (de l'espèce, de la ménagerie) : une
		-- recapture meilleure remplace `at`, elles ne bougent plus
		local oldFirst = EarliestAt(old)
		if not tonumber(capture.firstAt) then capture.firstAt = ns:CaptureEarliestAt() end
		-- 2.15.0 : la qualité du candidat (tirée au coup fatal), plus de tirage ici
		rolling.stars = math.max(1, math.min(ns.CAPTURE_STAR_MAX, math.floor(tonumber(rolling.stars or target.stars) or 1)))
		rolling.starsBefore = before
		-- la fiche d'avant a sa référence au Codex avant que le spécimen n'arrive
		if self.SpecimenReconcile then self:SpecimenReconcile(target.npcID) end
		local result = base(self, rolling)
		local entry = self:CaptureData().creatures[target.npcID]
		if entry then
			entry.firstAt = oldFirst or EarliestAt(entry)
			if not tonumber(capture.firstAt) then capture.firstAt = entry.firstAt end
			local better = before == nil or rolling.stars > before
			local best = math.max(before or 0, rolling.stars)
			if shiny then entry.shinyStars = best else entry.stars = best end
			-- 2.15.0 : le spécimen (Codex s'il est le meilleur, sinon Réserve),
			-- et une capture de plus de l'espèce aujourd'hui (méfiance)
			if self.SpecimenAdd then
				local id, place = self:SpecimenAdd({ npc = target.npcID, stars = rolling.stars, shiny = shiny,
					zone = target.zoneID, at = Call(G("time")), by = ns.Plain and ns.Plain(Call(G("UnitName"), "player")) or nil,
					origin = "capture", name = target.name })
				rolling.specimen, rolling.place = id, place
			end
			if self.CaptureWaryNote then self:CaptureWaryNote(target.npcID) end
			-- pas mieux : la date reste celle du spécimen gardé
			if not better and oldAt then
				if shiny then entry.shinyAt = oldAt else entry.at = oldAt end
			end
			rolling.starsBest, rolling.starsBetter = best, better
			-- les étoiles ont pu changer : les effets du compagnon (lot 2) se recalculent
			local capture = self:CaptureData()
			capture.serial = (tonumber(capture.serial) or 0) + 1
			self.captureAppCache = nil
			local text = self:CaptureStarsText(rolling.stars)
			-- 3.1.0 : « Raptor : <étoiles> · Grand · Curieux. » (taille et caractère du spécimen)
			if rolling.specimen and self.SpecimenTagsShort then
				local tags = self:SpecimenTagsShort(rolling.specimen)
				if tags ~= "" then text = text .. L.SPEC_TAGS_SEP .. tags end
			end
			if before == nil then
				self:Print(self:F("CAPTURE_MSG_STARS", target.name, text))
			elseif better then
				self:Print(self:F("CAPTURE_MSG_STARS_BEST", target.name, text))
			else
				self:Print(self:F("CAPTURE_MSG_STARS_KEPT", target.name, text, before))
			end
		end
		self:CaptureQueueRefresh()
		return result
	end
end

-- Horloge (Capture.lua, 10 fois par seconde) : la file aussi (fin du
-- combat, temps écoulé). Le tri ne se refait que si quelque chose a bougé
-- (compte lancé, captures, un candidat arrivé au bout de son temps), et au
-- plus tard une fois par seconde ; rien n'est alloué à chaque passage.
ns.CAPTURE_QUEUE_PRUNE_GAP = 1
do
	local base = ns.CaptureTick
	function ns:CaptureTick(now)
		local before = self.captureState and self.captureState.rolling
		-- 2.15.0 : la fin du mode chasse (minuté) est annoncée ici
		if self.HuntCheck then self:HuntCheck() end
		base(self, now)
		local state = self.captureState
		-- la scène (ou la petite fenêtre) vient de se refermer sur son verdict :
		-- la visite guidée passe au verdict (GuidedTour.lua, 3.0.0)
		if before and before.result and not (state and state.rolling) and self.TourSignal then
			pcall(self.TourSignal, self, "result", before.success and true or false)
		end
		-- la scène refermée, le choix abandonné… : le compte à rebours reprend
		local resumed = self:CaptureQueueCheckHolds()
		local queue = state and state.queue
		if not (queue and #queue > 0) then return end
		now = now or Clock()
		local changed = false
		if self.captureToastHideAt and now >= self.captureToastHideAt then
			-- souris dessus : il attend qu'on la retire
			local toast = self.captureToast
			local over = toast and toast.IsMouseOver and Call(toast.IsMouseOver, toast)
			if over then self.captureToastHideAt = now + 1 else self:CaptureToastHide() end
		end
		if not InCombat() and self:CaptureQueueStartTimers(now) then
			changed = true
			-- fin du combat : ceux qui attendaient sont annoncés, et c'est
			-- aussi une occasion pour la visite des premières captures
			self:CaptureToastShow()
			if self.TourCaptureOpportunity then pcall(self.TourCaptureOpportunity, self) end
		end
		local due = changed or resumed or state.queuePrunedSerial ~= self:CaptureData().serial or not state.queuePrunedAt
			or now - state.queuePrunedAt >= ns.CAPTURE_QUEUE_PRUNE_GAP or now < state.queuePrunedAt
		if not due then
			local clock = self:CaptureQueueClock(now)
			for index = 1, #queue do
				local expires = queue[index].expires
				if expires and clock > expires then due = true; break end
			end
		end
		if due then
			local before = #queue
			self:CaptureQueuePrune(now)
			if #queue ~= before then changed = true end
		end
		if changed then self:CaptureQueueRefresh() end
		if self.captureQueueList and self.captureQueueList:IsShown() then self:CaptureRefreshQueueList(now) end
	end
end

-- La scène : le pied dit si le spécimen bat celui qu'on avait (les étoiles
-- elles-mêmes sont dessinées par CaptureStage.lua, depuis rolling.stars)
do
	local base = ns.CaptureStageUpdate
	if base then
		function ns:CaptureStageUpdate(now)
			local phase = base(self, now)
			local frame = self.captureStage
			local rolling = frame and frame.rolling
			if phase == "ok" and rolling and rolling.starsBefore then
				local r = now - (rolling.resultAt or now)
				if r <= 1.2 then
					frame.footer:SetText(rolling.starsBetter and L.CAPTURE_STAGE_BEST
						or self:F("CAPTURE_STAGE_KEPT", rolling.starsBefore))
				end
			end
			return phase
		end
	end
end

-- ---------------------------------------------------------------------------
-- Le bouton filet, sur le cadre du compagnon
-- ---------------------------------------------------------------------------
local function ShowNetTooltip(button)
	local tooltip = Tooltip()
	if not tooltip then return end
	tooltip:SetOwner(button, "ANCHOR_TOP")
	local queue = ns:CaptureQueuePrune()
	Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_COUNT", #queue), Theme.GOLD)
	local best = queue[1]
	if best then
		local name = best.shiny and ns:F("CAPTURE_SHINY_TAG", best.name) or best.name
		Theme.TooltipLine(tooltip, ns:CaptureQueueLine(best), Theme.PARCHMENT)
		-- 2.10.0 : en combat, le clic ne lance rien : l'infobulle le dit
		if InCombat() then
			Theme.TooltipLine(tooltip, L.CAPTURE_Q_COMBAT, Theme.MUTED_LIGHT)
		-- deux candidats ou plus : le choix et ses raccourcis (CaptureBatch.lua)
		elseif not (ns.CaptureNetClickLines and ns:CaptureNetClickLines(tooltip, queue, name)) then
			if ns:DB().companionCaptureDirect == true then
				Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_CLICK", name), Theme.MUTED_LIGHT)
			else
				Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_CLICK_PREP", name), Theme.MUTED_LIGHT)
				Theme.TooltipLine(tooltip, L.CAPTURE_Q_SHIFT_DIRECT, Theme.MUTED_LIGHT)
			end
		end
	end
	local aid = ns:CaptureState().aid
	if aid and ns:CaptureAidCount(aid) > 0 then
		Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_AID", ns:CaptureAidLabel(aid)), Theme.MUTED_LIGHT)
	end
	Theme.TooltipLine(tooltip, L.CAPTURE_Q_RIGHT, Theme.MUTED_LIGHT)
	local left = ns:CaptureMuted()
	if left then Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_MUTED", ns:CaptureMuteText(left)), Theme.MUTED) end
	tooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Sourdine (2.2.0) : plus de bandeau ni de son de capture pendant N minutes
-- (temps réel, gardé dans les réglages) ; le filet et la liste restent.
-- ---------------------------------------------------------------------------
local function RealTime()
	local fn = G("time")
	return type(fn) == "function" and tonumber(fn()) or Clock()
end

-- secondes de sourdine restantes, ou nil
function ns:CaptureMuted()
	local untilAt = tonumber(self:DB().captureMuteUntil)
	if not untilAt then return nil end
	local left = untilAt - RealTime()
	if left <= 0 then self:DB().captureMuteUntil = nil; return nil end
	return left
end

-- « 12 min », « 1 h 05 », « 40 s »
function ns:CaptureMuteText(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds >= 3600 then
		local h, m = math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)
		return m > 0 and string.format("%d h %02d", h, m) or string.format("%d h", h)
	elseif seconds >= 60 then
		return self:F("CAPTURE_TOAST_MUTE_MIN", math.ceil(seconds / 60))
	end
	return seconds .. " s"
end

function ns:CaptureMute(minutes)
	minutes = tonumber(minutes) or 15
	if minutes <= 0 then return self:CaptureUnmute() end
	self:DB().captureMuteUntil = RealTime() + minutes * 60
	self:CaptureToastHide()
	self:Print(self:F("CAPTURE_MSG_MUTED", self:CaptureMuteText(minutes * 60)))
	return self:DB().captureMuteUntil
end

function ns:CaptureUnmute()
	if not self:DB().captureMuteUntil then return false end
	self:DB().captureMuteUntil = nil
	self:Print(L.CAPTURE_MSG_UNMUTED)
	return true
end

-- Le filet vit sur l'écran, pas dans le cadre du compagnon (QC 2.0) : à
-- côté du compagnon quand il est affiché (à sa droite, ou à sa gauche s'il
-- touche le bord de l'écran), à sa taille ; seul sous le personnage quand le
-- compagnon est masqué (réglage) — on peut toujours capturer.
ns.CAPTURE_NET_ALONE = { point = "CENTER", x = 0, y = -170 }

-- Le compagnon touche-t-il le bord droit de l'écran, filet compris ?
local function NetCrowdsRight(frame, scale)
	if not (frame.GetRight and UIParent and UIParent.GetWidth) then return false end
	local ok, right = pcall(frame.GetRight, frame)
	right = ok and tonumber(ns.Plain and ns.Plain(right) or right) or nil
	if not right then return false end
	local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
	local screen = (UIParent:GetWidth() or 0) * ((UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1)
	if screen <= 0 then return false end
	local needed = (ns.CAPTURE_NET_GAP + NET_SIZE + 4) * (scale or 1) * frameScale
	return right * frameScale + needed > screen
end

function ns:CapturePlaceNet()
	local button = self.captureNetButton
	if not button then return nil end
	local frame = self.companionFrame
	local onCompanion = frame and frame.IsShown and frame:IsShown() and true or false
	button:ClearAllPoints()
	if onCompanion then
		local scale = (frame.GetScale and frame:GetScale()) or 1
		if button.SetScale then button:SetScale(scale) end
		local gap = ns.CAPTURE_NET_GAP
		if NetCrowdsRight(frame, 1) then
			button:SetPoint("RIGHT", frame, "LEFT", -gap, 0)
			button.side = "left"
		else
			button:SetPoint("LEFT", frame, "RIGHT", gap, 0)
			button.side = "right"
		end
		if button.SetFrameStrata and frame.GetFrameStrata then pcall(button.SetFrameStrata, button, frame:GetFrameStrata()) end
		button:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
		frame.captureNet = button
	else
		if button.SetScale then button:SetScale(1) end
		local spot = ns.CAPTURE_NET_ALONE
		button:SetPoint(spot.point, UIParent, spot.point, spot.x, spot.y)
		if button.SetFrameStrata then pcall(button.SetFrameStrata, button, "MEDIUM") end
		button.side = nil
	end
	button.alone = not onCompanion
	return onCompanion and "companion" or "alone"
end

function ns:EnsureCaptureNet()
	if self.captureNetButton then self:CapturePlaceNet(); return self.captureNetButton end
	local button = Theme.CreateIconButton(UIParent, NET_SIZE, NET_ICON)
	self.captureNetButton = button
	if button.icon then button.ownGlyph = PaintNetIcon(button.icon) end
	if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	-- 2.3.1 : lisible sur n'importe quel sol (sable, neige, pierre claire). Une
	-- ombre portée sombre autour, une plaque d'encre opaque derrière le glyphe,
	-- un double liseré (sombre dehors, doré dedans).
	button.shadow = Theme.Solid(button, "BACKGROUND", Theme.SHADOW, 0.55)
	button.shadow:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
	button.shadow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
	if button.shadow.SetDrawLayer then button.shadow:SetDrawLayer("BACKGROUND", -8) end
	-- le halo doré d'une brillante (et du battement), entre l'ombre et la plaque
	button.glow = Theme.Solid(button, "BACKGROUND", Theme.GOLD_LIGHT, 0)
	button.glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
	button.glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
	if button.glow.SetDrawLayer then button.glow:SetDrawLayer("BACKGROUND", 0) end
	button.plate = Theme.Solid(button, "BACKGROUND", Theme.INK, 0.94)
	button.plate:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	button.plate:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	if button.plate.SetDrawLayer then button.plate:SetDrawLayer("BACKGROUND", 4) end
	button.ring = Theme.Border(button, Theme.GOLD, 1, "BORDER", button.plate)
	if button.border and button.border.SetColor then button.border:SetColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], 1) end
	-- le compteur : pastille dorée sur le coin, texte sombre (se voit partout)
	button.countBack = Theme.Solid(button, "ARTWORK", Theme.GOLD, 1)
	button.countBack:SetSize(18, 16)
	button.countBack:SetPoint("CENTER", button, "TOPRIGHT", -2, -2)
	if button.countBack.SetDrawLayer then button.countBack:SetDrawLayer("OVERLAY", 6) end
	button.countEdge = Theme.Border(button, Theme.SHADOW, 1, "OVERLAY", button.countBack)
	button.count = Theme.Text(button, Theme.F_LABEL, Theme.INK)
	if button.count.SetDrawLayer then button.count:SetDrawLayer("OVERLAY", 7) end
	button.count:SetPoint("CENTER", button.countBack, "CENTER", 0, 0)
	button.count:SetJustifyH("CENTER")
	-- 2.15.0 : la qualité du meilleur candidat (étoiles du client), sur une
	-- pastille d'encre au bas du filet ; une brillante garde son halo doré
	button.badgeBack = Theme.Solid(button, "ARTWORK", Theme.INK, 0.92)
	button.badgeBack:SetSize(ns.CAPTURE_NET_BADGE.w, ns.CAPTURE_NET_BADGE.h)
	button.badgeBack:SetPoint("CENTER", button, "BOTTOM", 0, ns.CAPTURE_NET_BADGE.y)
	if button.badgeBack.SetDrawLayer then button.badgeBack:SetDrawLayer("OVERLAY", 5) end
	button.badgeEdge = Theme.Border(button, Theme.GOLD, 1, "OVERLAY", button.badgeBack)
	button.badge = Theme.Text(button, Theme.F_SMALL, Theme.WHITE)
	if button.badge.SetDrawLayer then button.badge:SetDrawLayer("OVERLAY", 7) end
	button.badge:SetPoint("CENTER", button.badgeBack, "CENTER", 0, 0)
	button.badgeBack:Hide(); button.badge:Hide()
	if button.badgeEdge and button.badgeEdge.Hide then button.badgeEdge:Hide() end
	button:SetScript("OnClick", function(_, mouse) ns:CaptureNetClick(mouse) end)
	button:SetScript("OnEnter", function(b) b.hover = true; ns:CaptureStyleNet(); ShowNetTooltip(b) end)
	button:SetScript("OnLeave", function(b)
		b.hover = nil
		ns:CaptureStyleNet()
		local tooltip = Tooltip()
		if tooltip and tooltip.Hide then tooltip:Hide() end
	end)
	-- scintillement : tant qu'une brillante attend, et quelques secondes à
	-- l'arrivée d'un candidat (le battement attire l'œil, sans clignoter)
	button:SetScript("OnUpdate", function(b)
		local now = Clock()
		-- 3.0.0 : la visite guidée montre le filet : il bat tant que l'étape attend
		if ns.tourNetPulse then b.pulseUntil = now + ns.CAPTURE_NET_PULSE end
		if b.shiny then
			b.glow:SetAlpha(0.20 + 0.35 * math.abs(math.sin(now * 3)))
		elseif b.pulseUntil and now < b.pulseUntil then
			b.glow:SetAlpha(0.15 + 0.35 * math.abs(math.sin(now * 2.5)))
		elseif b.pulseUntil then
			b.pulseUntil = nil
			b.glow:SetAlpha(0)
		end
	end)
	button:Hide()
	self:CapturePlaceNet()
	return button
end

-- Le clic sur le filet (et sur le bandeau) : clic droit, la liste ; clic, le
-- meilleur candidat (en combat, refusé : 2.10.0). CaptureBatch.lua y ajoute
-- le choix à deux candidats.
-- 2.15.0 : le clic ouvre la carte de préparation (CaptureStage.lua) ;
-- Maj+clic, ou le réglage « Lancer directement au clic » : le filet part tout
-- de suite (avec l'aide déjà choisie). Carte déjà ouverte : un clic la ferme.
function ns:CaptureDirectOn()
	if self:DB().companionCaptureDirect == true then return true end
	return Call(G("IsShiftKeyDown")) and true or false
end

function ns:CaptureNetClick(mouse)
	if mouse == "RightButton" then
		if self.CapturePrepClose then self:CapturePrepClose() end
		return self:CaptureToggleQueueList()
	end
	if self.CapturePrepShown and self:CapturePrepShown() then self:CapturePrepClose(); return nil end
	if InCombat() then return self:CaptureRefuseCombat() end
	if self:CaptureDirectOn() or not self.CapturePrepOpen then return self:CaptureThrow() end
	local frame = self:CapturePrepOpen()
	if frame then return frame end
	-- pas de carte possible (thème absent) : comme avant
	return self:CaptureThrow()
end

-- Couleurs : ambre au repos, or plein (et halo) pour une brillante
function ns:CaptureStyleNet()
	local button = self.captureNetButton
	if not button then return end
	if button.icon.SetDesaturated then button.icon:SetDesaturated(false) end
	button.icon:SetAlpha(1)
	-- liseré doré au repos (un filet qui attend doit se voir), or clair au
	-- survol ou pour une brillante
	local c = (button.shiny or button.hover) and Theme.GOLD_LIGHT or Theme.GOLD
	-- liseré doré dedans, noir dehors : contraste sur sol clair comme sombre
	if button.ring and button.ring.SetColor then button.ring:SetColor(c[1], c[2], c[3], 1) end
	if button.border and button.border.SetColor then button.border:SetColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], 1) end
	if button.countBack and button.countBack.SetVertexColor then
		local cc = button.shiny and Theme.GOLD_LIGHT or Theme.GOLD
		button.countBack:SetVertexColor(cc[1], cc[2], cc[3], 1)
	end
	local g = button.shiny and Theme.GOLD_LIGHT or Theme.GOLD
	if button.glow.SetVertexColor then button.glow:SetVertexColor(g[1], g[2], g[3], 1) end
	-- notre glyphe blanc prend sa couleur : ambre au repos, or si brillante
	-- ou au survol (l'icône du jeu, en repli, reste en couleurs)
	local ours = button.ownGlyph
	local tint = button.shiny and (ours and Theme.GOLD_LIGHT or ICON_GAME_SHINY)
		or (ours and (button.hover and Theme.GOLD_LIGHT or Theme.GOLD) or ICON_GAME_REST)
	button.icon:SetVertexColor(tint[1], tint[2], tint[3], 1)
	if not button.shiny and not (button.pulseUntil and Clock() < button.pulseUntil) then button.glow:SetAlpha(0) end
end

-- Bouton et liste à jour (après chaque changement de la file)
function ns:CaptureQueueRefresh()
	local queue = self:CaptureQueueState()
	local count = (Enabled() and #queue) or 0
	do
		local button = self.captureNetButton or (count > 0 and self:EnsureCaptureNet())
		if button then
			self:CapturePlaceNet()
			-- 2.10.0 : réglage « Afficher le filet », indépendant du compagnon ;
			-- masqué, les candidats attendent dans la file (raccourci, /qc filet)
			if count > 0 and self:DB().companionNetShow ~= false then
				button.count:SetText(tostring(count))
				button.shiny = self:CaptureQueueHasShiny()
				self:CaptureNetBadge(button, queue[1])
				-- un candidat de plus : le filet bat quelques secondes
				if count > (button.lastCount or 0) then button.pulseUntil = Clock() + ns.CAPTURE_NET_PULSE end
				button.lastCount = count
				self:CaptureStyleNet()
				button:Show()
			else
				button.shiny, button.lastCount, button.pulseUntil = nil, 0, nil
				button:Hide()
			end
		end
	end
	if count == 0 then self:CaptureToastHide() end
	if count == 0 then self:CaptureHideQueueList()
	elseif self.captureQueueList and self.captureQueueList:IsShown() then self:CaptureRefreshQueueList() end
	-- 2.15.0 : la carte de préparation suit la file (CaptureStage.lua)
	if self.CapturePrepCheck then self:CapturePrepCheck() end
	return count
end

-- 2.15.0 : la pastille de qualité du filet (étoiles du meilleur candidat) ;
-- le texte n'est refait que si les étoiles changent
function ns:CaptureNetBadge(button, best)
	button = button or self.captureNetButton
	if not (button and button.badge) then return nil end
	local stars = best and tonumber(best.stars)
	if not stars then
		button.badgeStars = nil
		button.badge:Hide(); button.badgeBack:Hide()
		if button.badgeEdge and button.badgeEdge.Hide then button.badgeEdge:Hide() end
		return nil
	end
	if button.badgeStars ~= stars then
		button.badgeStars = stars
		button.badge:SetText(self:CaptureStarsText(stars, ns.CAPTURE_NET_BADGE.star))
	end
	local edge = (best.shiny or stars >= 3) and Theme.GOLD_LIGHT or Theme.GOLD
	if button.badgeEdge and button.badgeEdge.SetColor then button.badgeEdge:SetColor(edge[1], edge[2], edge[3], 1) end
	button.badge:Show(); button.badgeBack:Show()
	if button.badgeEdge and button.badgeEdge.Show then button.badgeEdge:Show() end
	return stars
end

-- ---------------------------------------------------------------------------
-- Le bandeau « Capture possible » (2.1.0) : dès qu'un monstre abattu peut
-- être capturé, hors combat (en combat, il attend la fin du combat, comme le
-- compte à rebours de la file). Même bandeau que les tampons du carnet :
-- liseré doré, icône du filet, titre en capitales, le nom de la créature.
-- Clic : le filet (le meilleur candidat) ; clic droit : la liste. Il se
-- déplace comme les autres bandeaux et garde sa place (captureToastPoint).
-- ---------------------------------------------------------------------------
-- Bouton compact (la rangée de sourdine) : le libellé et un peu d'air
local function CompactWidth(parent, label)
	local w = Theme.TextWidth and Theme.TextWidth(parent, label, Theme.F_LABEL) or 30
	return math.max(36, math.ceil((tonumber(w) or 30) + 16))
end

function ns:EnsureCaptureToast()
	if self.captureToast then return self.captureToast end
	-- style de l'interface (2.5.0, AzerothStyle.lua) : un bandeau déjà fait
	-- pour le style courant resservit ; Azeroth = bandeau doré + bande sombre
	local cached = self.StyleCached and self:StyleCached("captureToast")
	if cached then self.captureToast = cached; return cached end
	local frame = self.AzerothOn and self:AzerothOn() and self:AzerothCreateBanner({ strata = "HIGH", strip = true })
	if frame then
		frame.ownGlyph = PaintNetIcon(frame.icon)
		if frame.ownGlyph then frame.icon:SetVertexColor(Theme.GOLD_LIGHT[1], Theme.GOLD_LIGHT[2], Theme.GOLD_LIGHT[3], 1)
		else frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	elseif not (Theme and Theme.CreateToast) then
		return nil
	else
		frame = self:CaptureToastSobre()
	end
	if not frame then return nil end
	self:CaptureToastControls(frame)
	if self.RestorePoint then self:RestorePoint(frame, "captureToastPoint", { point = "TOP", x = 0, y = -240 }) end
	frame:Hide()
	self.captureToast = frame
	return frame
end

-- Le bandeau Sobre (le style d'avant 2.5.0) : liseré doré, glyphe, textes
function ns:CaptureToastSobre()
	local frame = Theme.CreateToast(UIParent, TOAST_W, TOAST_H, { strata = "HIGH", accent = Theme.GOLD })
	if not frame then return nil end
	frame.uiStyle = "sobre"
	local left = frame.contentLeft or 14
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.ownGlyph = PaintNetIcon(frame.icon)
	if frame.ownGlyph then
		frame.icon:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	else
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	frame.icon:SetSize(TOAST_ICON, TOAST_ICON)
	frame.icon:SetPoint("LEFT", frame, "LEFT", left, 0)
	local textLeft = left + TOAST_ICON + 10
	local textW = TOAST_W - textLeft - 12
	frame.title = Theme.Text(frame, Theme.F_CAPS, Theme.MUTED_LIGHT)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, -9)
	frame.title:SetWidth(textW)
	frame.title:SetJustifyH("LEFT")
	if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end
	frame.text = Theme.Text(frame, Theme.F_TITLE, Theme.PARCHMENT)
	frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, -23)
	frame.text:SetWidth(textW)
	frame.text:SetJustifyH("LEFT")
	if frame.text.SetWordWrap then frame.text:SetWordWrap(false) end
	-- ce qu'on a déjà de cette espèce (étoiles), et la chance
	frame.info = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.info:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, -42)
	frame.info:SetWidth(textW)
	frame.info:SetJustifyH("LEFT")
	if frame.info.SetWordWrap then frame.info:SetWordWrap(false) end
	-- l'aide sur sa propre ligne, sous les infos : les boutons ont la rangée du bas
	frame.hint = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
	frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, -57)
	frame.hint:SetWidth(textW)
	frame.hint:SetJustifyH("LEFT")
	if frame.hint.SetWordWrap then frame.hint:SetWordWrap(false) end
	return frame
end

-- Clic, Ignorer, Sourdine et la rangée des durées : communs aux deux styles.
-- Les boutons vont en bas de la zone d'infos (frame.strip en Azeroth, le
-- bandeau entier en Sobre).
function ns:CaptureToastControls(frame)
	local zone = frame.strip or frame
	-- un bouton invisible par-dessus : clic, clic droit, et le glisser du bandeau
	local ok, button = pcall(CreateFrame, "Button", nil, frame)
	if ok and button then
		button:SetAllPoints(frame)
		if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
		if button.RegisterForDrag then button:RegisterForDrag("LeftButton") end
		-- même geste que sur le filet (à deux candidats : le choix, près du filet)
		button:SetScript("OnClick", function(_, mouse)
			ns:CaptureToastHide()
			ns:CaptureNetClick(mouse)
		end)
		button:SetScript("OnDragStart", function() if frame.StartMoving then pcall(frame.StartMoving, frame) end end)
		button:SetScript("OnDragStop", function()
			local stop = frame.GetScript and frame:GetScript("OnDragStop")
			if type(stop) == "function" then pcall(stop, frame) elseif frame.StopMovingOrSizing then pcall(frame.StopMovingOrSizing, frame) end
		end)
		frame.button = button
	end
	-- Ignorer et Sourdine, en bas à droite, par-dessus le bouton invisible
	local above = (frame.button and frame.button.GetFrameLevel and frame.button:GetFrameLevel() or frame:GetFrameLevel() or 1) + 2
	frame.mute = Theme.CreateButton(frame, "auto", 18, L.CAPTURE_TOAST_MUTE, function() ns:CaptureToastToggleMuteRow() end)
	frame.mute:SetPoint("BOTTOMRIGHT", zone, "BOTTOMRIGHT", -8, 7)
	frame.mute:SetFrameLevel(above)
	frame.ignore = Theme.CreateButton(frame, "auto", 18, L.CAPTURE_TOAST_IGNORE, function() ns:CaptureToastIgnore() end)
	frame.ignore:SetPoint("RIGHT", frame.mute, "LEFT", -6, 0)
	frame.ignore:SetFrameLevel(above)
	frame.mute:Show(); frame.ignore:Show()
	for _, b in ipairs({ frame.mute, frame.ignore }) do
		b.tip = b == frame.mute and L.CAPTURE_TOAST_MUTE_TIP or L.CAPTURE_TOAST_IGNORE_TIP
		b:HookScript("OnEnter", function(self)
			local tooltip = Tooltip()
			if not tooltip then return end
			tooltip:SetOwner(self, "ANCHOR_TOP")
			Theme.TooltipLine(tooltip, self.tip, Theme.PARCHMENT)
			tooltip:Show()
		end)
		b:HookScript("OnLeave", function() local t = Tooltip(); if t and t.Hide then t:Hide() end end)
	end
	-- la rangée des durées de sourdine : remplace la ligne du bas tant qu'on choisit
	-- (toute la largeur du bandeau, boutons compacts : 4 durées + Annuler tiennent)
	local row = CreateFrame("Frame", nil, frame)
	row:SetPoint("BOTTOMLEFT", zone, "BOTTOMLEFT", 6, 5)
	row:SetPoint("BOTTOMRIGHT", zone, "BOTTOMRIGHT", -6, 5)
	row:SetHeight(22)
	row:SetFrameLevel(above + 1)
	row.bg = Theme.Solid(row, "BACKGROUND", Theme.NAV or Theme.WINDOW, 1)
	row.bg:SetAllPoints()
	row.choices = {}
	local anchor
	for index, minutes in ipairs(ns.CAPTURE_MUTE_CHOICES) do
		local label = minutes >= 60 and L.CAPTURE_TOAST_MUTE_HOUR or ns:F("CAPTURE_TOAST_MUTE_MIN", minutes)
		local choice = Theme.CreateButton(row, CompactWidth(row, label), 18, label, function() ns:CaptureMute(minutes) end, "accent")
		if anchor then choice:SetPoint("LEFT", anchor, "RIGHT", 4, 0) else choice:SetPoint("LEFT", row, "LEFT", 4, 0) end
		choice.minutes = minutes
		row.choices[index] = choice
		anchor = choice
	end
	row.cancel = Theme.CreateButton(row, CompactWidth(row, L.CAPTURE_TOAST_MUTE_CANCEL), 18, L.CAPTURE_TOAST_MUTE_CANCEL, function() ns:CaptureToastToggleMuteRow(false) end)
	row.cancel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row:Hide()
	frame.muteRow = row
	return frame
end

-- Ignorer : le candidat du bandeau sort du filet ; le suivant prend sa place
function ns:CaptureToastIgnore()
	local frame = self.captureToast
	local candidate = frame and frame.candidate
	if not candidate then return false end
	self:CaptureQueueRemove(candidate)
	if #self:CaptureQueuePrune() > 0 then self:CaptureToastShow() else self:CaptureToastHide() end
	return true
end

function ns:CaptureToastToggleMuteRow(show)
	local frame = self.captureToast
	if not (frame and frame.muteRow) then return false end
	if show == nil then show = not frame.muteRow:IsShown() end
	if show then frame.muteRow:Show() else frame.muteRow:Hide() end
	-- tant qu'on choisit, le bandeau ne s'efface pas tout seul
	if show then self.captureToastHideAt = Clock() + 60 else self.captureToastHideAt = Clock() + ns.CAPTURE_TOAST_SECONDS end
	return show
end

-- La ligne d'infos du bandeau : ce qu'on a déjà de cette espèce, et la chance
function ns:CaptureToastInfo(candidate)
	local parts = {}
	local normal = self.CaptureStars and self:CaptureStars(candidate.npcID, false)
	local shiny = self.CaptureStars and self:CaptureStars(candidate.npcID, true)
	if normal or shiny then
		local owned = normal and self:CaptureStarsText(normal, 10) or ""
		if shiny then
			local tag = self:F("CAPTURE_TOAST_OWNED_SHINY", self:CaptureStarsText(shiny, 10))
			owned = owned ~= "" and (owned .. " · " .. tag) or tag
		end
		parts[#parts + 1] = self:F("CAPTURE_TOAST_OWNED", owned)
		if candidate.reason == "stars" then parts[#parts + 1] = L.CAPTURE_TOAST_BETTER
		elseif candidate.reason == "pinned" or candidate.reason == "hunt" then parts[#parts + 1] = L["CAPTURE_Q_REASON_" .. candidate.reason] end
	else
		parts[#parts + 1] = L.CAPTURE_TOAST_NEW
	end
	local chance, sure = self:CaptureChance(candidate, self:CaptureState().aid)
	parts[#parts + 1] = sure and L.CAPTURE_TOAST_SURE or self:F("CAPTURE_TOAST_CHANCE", math.floor((chance or 0) * 100 + 0.5 + 1e-9))
	return table.concat(parts, " · "), (normal or shiny) and true or false
end

-- Montre (ou remet à jour) le bandeau pour le meilleur candidat de la file
function ns:CaptureToastShow()
	if not Enabled() or self:DB().companionCaptureToast == false or InCombat() or self:CaptureMuted() then return nil end
	local queue = self:CaptureQueuePrune()
	local best = queue[1]
	if not best then self:CaptureToastHide(); return nil end
	local frame = self:EnsureCaptureToast()
	if not frame then return nil end
	local name = best.shiny and self:F("CAPTURE_SHINY_TAG", best.name) or best.name
	frame.title:SetText(Theme.Upper and Theme.Upper(L.CAPTURE_TOAST_TITLE) or L.CAPTURE_TOAST_TITLE)
	frame.text:SetText(name)
	local info, owned = self:CaptureToastInfo(best)
	frame.info:SetText(info)
	local ic = owned and Theme.MUTED_LIGHT or Theme.GOLD
	frame.info:SetTextColor(ic[1], ic[2], ic[3])
	if #queue > 1 then
		frame.hint:SetText(self:F("CAPTURE_TOAST_MORE", #queue - 1) .. "  ·  " .. L.CAPTURE_TOAST_HINT)
	else
		frame.hint:SetText(L.CAPTURE_TOAST_HINT)
	end
	if frame.muteRow then frame.muteRow:Hide() end
	local accent = best.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GOLD
	if frame.SetAccent then frame:SetAccent(accent) end
	if frame.ownGlyph then frame.icon:SetVertexColor(accent[1], accent[2], accent[3], 1) end
	frame.candidate = best
	local fresh = not frame:IsShown()
	if fresh then
		frame:Show()
		if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.2) end
	end
	-- Azeroth : nom ajusté à la largeur, bouclier gris (pas encore à toi), apparition
	if self.StyleShown then self:StyleShown(frame, { shiny = best.shiny, shield = "grey", play = fresh }) end
	if frame.chimedFor ~= best.serial then
		frame.chimedFor = best.serial
		self:CapturePlaySound("ready")
	end
	-- un nouveau monstre abattu ne le prolonge plus (2.9.0) : en pleine mêlée
	-- il restait affiché sans fin ; seule une nouvelle apparition relance le délai
	if fresh or not self.captureToastHideAt then self.captureToastHideAt = Clock() + ns.CAPTURE_TOAST_SECONDS end
	return frame
end

function ns:CaptureToastHide()
	self.captureToastHideAt = nil
	local frame = self.captureToast
	if frame then
		frame.candidate = nil
		frame:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- La liste (clic droit sur le filet)
-- ---------------------------------------------------------------------------
-- 2.15.0 : « nouvelle », « brillante », « meilleure que la tienne ★☆☆ »,
-- « épinglée », « chasse »
function ns:CaptureQueueTag(candidate)
	local reason = candidate.reason or "new"
	if reason == "stars" then return self:F("CAPTURE_Q_TAG_stars", self:CaptureStarsText(candidate.have, 10)) end
	return L["CAPTURE_Q_TAG_" .. reason] or tostring(reason)
end

-- « ★★★ · nouvelle · Normal · 30 % · 24 s »
function ns:CaptureQueueLine(candidate, now)
	local parts = {}
	-- 2.15.0 : la qualité du spécimen (tirée au coup fatal), puis pourquoi
	-- le filet le propose, en court (« nouvelle », « meilleure que la tienne ★ »…)
	if candidate.stars then parts[1] = self:CaptureStarsText(candidate.stars, 10) end
	parts[#parts + 1] = self:CaptureQueueTag(candidate)
	local state = self:CaptureState()
	local chance, sure = self:CaptureChance(candidate, state.aid)
	parts[#parts + 1] = sure and self:F("CAPTURE_SURE", L["CAPTURE_RANK_" .. tostring(candidate.class)])
		or self:F("CAPTURE_CHANCE", L["CAPTURE_RANK_" .. tostring(candidate.class)], math.floor(chance * 100 + 0.5 + 1e-9))
	if candidate.expires then
		-- (en pause, le temps restant ne bouge pas)
		parts[#parts + 1] = self:F("CAPTURE_Q_LEFT", math.max(0, math.ceil(candidate.expires - self:CaptureQueueClock(now or Clock()))))
	else
		parts[#parts + 1] = L.CAPTURE_Q_WAIT
	end
	return table.concat(parts, " · ")
end

function ns:EnsureCaptureQueueList()
	if self.captureQueueList then return self.captureQueueList end
	if not (Theme and Theme.CreateToast) then return nil end
	local height = 34 + LIST_ROWS * LIST_ROW_H + 70
	-- un nom global : Échap la referme (UISpecialFrames), comme les fenêtres du thème (2.3.0)
	local frame = Theme.CreateToast(UIParent, LIST_W, height, { strata = "HIGH", name = "QuestCompanionCaptureList" })
	if not frame then return nil end
	frame:EnableMouse(true)
	if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
	self:RestorePoint(frame, "captureListPoint", { point = "BOTTOM", x = 0, y = 260 })
	-- clic droit sur le fond : on referme
	frame:SetScript("OnMouseUp", function(_, mouse) if mouse == "RightButton" then ns:CaptureHideQueueList() end end)
	local pad = 12
	frame.title = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
	frame.title:SetText(L.CAPTURE_Q_TITLE)
	-- « × » en haut à droite (brique du thème), comme les autres fenêtres
	if Theme.CreateCloseButton then
		frame.close = Theme.CreateCloseButton(frame, 18)
		frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	end
	frame.rows = {}
	for index = 1, LIST_ROWS do
		local row = Theme.CreateListRow(frame, LIST_W - 2 * pad, LIST_ROW_H - 2,
			{ kind = "Button", detail = true, detailFont = Theme.F_SMALL, font = Theme.F_SMALL })
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -30 - (index - 1) * LIST_ROW_H)
		row:SetIndex(index)
		row.text:SetWidth(110)
		row.detail:SetWidth(LIST_W - 2 * pad - 130)
		-- clic sur une ligne : le filet part sur ce candidat, la liste se referme
		row:SetScript("OnClick", function(r)
			ns:CaptureHideQueueList()
			if r.candidate then ns:CaptureThrow(r.candidate) end
		end)
		row:Hide()
		frame.rows[index] = row
	end
	frame.empty = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -34)
	frame.empty:SetText(L.CAPTURE_Q_EMPTY)
	-- les aides, comme dans l'ancienne fenêtre : choisies pour le prochain essai
	frame.aids = {}
	local aidY = pad + 30
	for index, aid in ipairs(ns.CAPTURE_AIDS or {}) do
		local button = Theme.CreateIconButton(frame, 24, aid.icon, function() ns:CaptureToggleAid(aid.id); ns:CaptureRefreshQueueList() end)
		button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad + (index - 1) * 30, aidY)
		button.count = Theme.Text(button, Theme.F_SMALL, Theme.PARCHMENT)
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
		button.aid = aid.id
		button:SetScript("OnEnter", function(b)
			local tooltip = Tooltip()
			if not tooltip then return end
			tooltip:SetOwner(b, "ANCHOR_TOP")
			local count = ns:CaptureAidCount(aid.id)
			Theme.TooltipLine(tooltip, ns:CaptureAidLabel(aid.id), Theme.PARCHMENT)
			Theme.TooltipLine(tooltip, L["CAPTURE_AID_DESC_" .. aid.id], Theme.TEXT)
			Theme.TooltipLine(tooltip, count > 0 and ns:F("CAPTURE_AID_HINT", count) or L.CAPTURE_AID_NONE, Theme.MUTED_LIGHT)
			tooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			local tooltip = Tooltip()
			if tooltip and tooltip.Hide then tooltip:Hide() end
			ns:CaptureRefreshQueueList()
		end)
		frame.aids[index] = button
	end
	frame.ignore = Theme.CreateButton(frame, 100, Theme.DIALOG_BUTTON_HEIGHT or 28, L.CAPTURE_Q_IGNORE,
		function() ns:CaptureQueueClear() end)
	frame.ignore:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, aidY - 2)
	frame.hint = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
	frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, pad - 2)
	frame.hint:SetWidth(LIST_W - 2 * pad)
	frame.hint:SetJustifyH("LEFT")
	frame.hint:SetText(L.CAPTURE_Q_LIST_HINT)
	frame:Hide()
	self.captureQueueList = frame
	return frame
end

function ns:CaptureRefreshQueueList(now)
	local frame = self.captureQueueList
	if not frame then return end
	local queue = self:CaptureQueueState()
	frame.title:SetText(self:F("CAPTURE_Q_COUNT", #queue))
	for index, row in ipairs(frame.rows) do
		local candidate = queue[index]
		row.candidate = candidate
		if candidate then
			local rarity = self.CaptureRarity and self:CaptureRarity(candidate)
			row.text:SetText(candidate.shiny and self:F("CAPTURE_SHINY_TAG", candidate.name) or candidate.name)
			local c = rarity and rarity.color or Theme.TEXT
			row.text:SetTextColor(c[1], c[2], c[3])
			row.detail:SetText(self:CaptureQueueLine(candidate, now))
			row:Show()
		else
			row:Hide()
		end
	end
	if #queue == 0 then frame.empty:Show() else frame.empty:Hide() end
	local state = self:CaptureState()
	for _, button in ipairs(frame.aids) do
		local count = self:CaptureAidCount(button.aid)
		button.count:SetText(count > 0 and tostring(count) or "")
		local chosen = state.aid == button.aid
		if button.icon.SetDesaturated then button.icon:SetDesaturated(not chosen) end
		button.icon:SetAlpha(chosen and 1 or (count > 0 and 0.6 or 0.25))
		local c = chosen and Theme.GOLD or Theme.EDGE
		if button.border and button.border.SetColor then button.border:SetColor(c[1], c[2], c[3], 1) end
	end
end

function ns:CaptureShowQueueList()
	local frame = self:EnsureCaptureQueueList()
	if not frame then return nil end
	self:CaptureQueuePrune()
	self:CaptureRefreshQueueList()
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	return frame
end

function ns:CaptureHideQueueList()
	if self.captureQueueList then self.captureQueueList:Hide() end
end

function ns:CaptureToggleQueueList()
	local frame = self.captureQueueList
	if frame and frame:IsShown() then self:CaptureHideQueueList(); return nil end
	return self:CaptureShowQueueList()
end

-- Le cadre du compagnon (re)créé : le filet s'y pose s'il y a de quoi
do
	local base = ns.EnsureCompanionFrame
	if base then
		function ns:EnsureCompanionFrame(...)
			local frame = base(self, ...)
			if self.captureNetButton then pcall(self.CapturePlaceNet, self)
			elseif frame and self.captureState and self.captureState.queue and #self.captureState.queue > 0 then
				pcall(self.CaptureQueueRefresh, self)
			end
			return frame
		end
	end
end

-- compagnon montré ou masqué : le filet suit (sur lui, ou seul à l'écran) ;
-- sa taille changée (réglage) : le filet aussi
do
	local base = ns.CompanionUpdateVisibility
	if base then
		function ns:CompanionUpdateVisibility(...)
			local a, b = base(self, ...)
			if self.captureNetButton then pcall(self.CapturePlaceNet, self) end
			return a, b
		end
	end
	local size = ns.CompanionApplySize
	if size then
		function ns:CompanionApplySize(...)
			local scale = size(self, ...)
			if self.captureNetButton then pcall(self.CapturePlaceNet, self) end
			return scale
		end
	end
end

-- /qc filet : capture le meilleur candidat (même compagnon masqué)
if ns.EXTRA_COMMANDS then
	ns.EXTRA_COMMANDS["filet"] = function(self, rest)
		local sub, arg = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
		sub = (sub or ""):lower()
		if sub == "sourdine" or sub == "mute" then
			if arg == "off" or arg == "non" or arg == "0" then
				if not self:CaptureUnmute() then self:Print(L.CAPTURE_MSG_UNMUTED) end
			else
				self:CaptureMute(tonumber(arg) or 15)
			end
			return
		end
		if not self:CaptureThrow() then self:Print(L.CAPTURE_Q_NOTHING) end
	end
	ns.EXTRA_COMMANDS["net"] = ns.EXTRA_COMMANDS["filet"]
end

if ns.Mark then ns.Mark("CaptureQueue") end
