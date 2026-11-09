-- CaptureBatch.lua -- « Tout capturer » : le filet sur toute la file d'un coup (QuestCompanion 2.4.0, scène refaite en 2.5.0)
--
-- Retour des joueurs : après un pack, cinq ou six créatures attendent dans
-- le filet, et il faut cliquer, regarder la scène, recliquer… Désormais,
-- dès que deux candidats attendent, « Tout capturer » les tente tous :
--   * le clic sur le filet (ou sur le bandeau « Capture possible ») propose
--     le choix, près du filet : « Capturer : <le meilleur> » ou « Tout
--     capturer (N) » (2.5.0 : avant, il fallait passer par la liste du clic
--     droit). Maj+clic : le meilleur tout de suite ; Ctrl+clic : tout de
--     suite. Aussi dans la liste, sur le bandeau, et /qc filet tout ;
--   * chaque essai suit les règles d'un lancer seul : même tirage
--     (ns:CaptureRoll, Capture.lua), même verdict par ns:CaptureResolve et
--     toutes ses enveloppes (étoiles, aides rendues, sceaux, missions,
--     tutoriel…). Rien n'est recopié ici ;
--   * les verdicts tombent TOUS d'abord et sont enregistrés tout de suite ;
--     la scène ne fait que les montrer : une grille de petites scènes de
--     capture jouées en même temps (2.5.0, à la place des cartes) : une volée
--     de filets tombe sur les créatures, chacun se secoue autant de fois que
--     son tirage (rolling.shakes), puis tient (étoiles) ou se déchire (la
--     créature file). Les brillantes se débattent plus longtemps et tombent
--     en dernier, avec leur fanfare et leur halo doré ;
--   * l'aide choisie sert à chaque essai, comme pour un lancer seul ; s'il
--     n'en reste pas assez pour tous, on tente ceux qu'elle couvre (dans
--     l'ordre de la file) et les autres restent dans le filet ;
--   * jamais en combat ;
--   * le compte à rebours de la file est en pause pendant le choix et la
--     scène (ns:CaptureQueueHold, CaptureQueue.lua).
-- Les messages du chat et les bulles du compagnon que les verdicts
-- produiraient sont retenus pendant le tirage : le chat ne gâche pas la
-- surprise, il reçoit tout à la fin de la scène (ou à « Arrêter », Échap).
-- La scène : une seule fenêtre, une horloge OnUpdate pour toutes les cases
-- (pas d'AnimationGroup), rien d'alloué à chaque image ; les cases sont
-- créées à la demande et resservent d'un lot à l'autre ; modèles 3D pour
-- les CAPTURE_BATCH_MODELS premières seulement (icône au-delà). Nos
-- textures (Textures/, celles de la scène d'un lancer seul) et les aplats
-- du thème ; en style Azeroth (2.5.1), le choix et la volée prennent le
-- cadre en bois, la plaque et les cadres d'icône des hauts faits (atlas du
-- client, désignés par leur nom, jamais embarqués).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_BATCH_MIN = 2            -- candidats à partir desquels « Tout capturer » se propose
ns.CAPTURE_BATCH_LEAD = 0.35        -- s avant la volée (la grille se pose)
ns.CAPTURE_BATCH_STAGGER = 0.1      -- s entre deux filets de la volée
ns.CAPTURE_BATCH_DRAPE = 0.3        -- s pour qu'un filet se pose (rebond)
ns.CAPTURE_BATCH_PAUSE = 0.5        -- s après la dernière ordinaire avant les brillantes
ns.CAPTURE_BATCH_SPECIAL_GAP = 0.85 -- s entre deux brillantes…
ns.CAPTURE_BATCH_SPECIAL_SPAN = 3   -- … resserré pour qu'elles tiennent toutes en 3 s environ
ns.CAPTURE_BATCH_SPECIAL_MIN = 0.35 -- (jamais moins de 0,35 s : chacune a son moment)
ns.CAPTURE_BATCH_SETTLE = 1.2       -- s d'animation d'un verdict (puis la case se fige)
ns.CAPTURE_FLED_ALPHA = 0.45       -- 2.11.0 : opacité du portrait d'une créature échappée (grisé)
ns.CAPTURE_FLED_NET_ALPHA = 0.85   -- … et du filet déchiré posé dessus
ns.CAPTURE_BATCH_SOUND_GAP = 0.06   -- s au moins entre deux bruits de filet (chute, secousse)
ns.CAPTURE_BATCH_OK_GAP = 0.4       -- s au moins entre deux musiques de réussite (groupées)
ns.CAPTURE_BATCH_COLS = 4
ns.CAPTURE_BATCH_MODELS = 8         -- cases avec un modèle 3D (au-delà : l'icône)
-- le bruit d'un filet qui tombe ou se secoue : IG_ABILITY_PAGE_TURN (kit du
-- client, un froissement bref)
if type(ns.CAPTURE_SOUNDS) == "table" and not ns.CAPTURE_SOUNDS.net then ns.CAPTURE_SOUNDS.net = 836 end

local TILE_W, TILE_H, TILE_GAP = 104, 136, 8
local SCENE_H, MODEL, NET = 88, 84, 92
local PAD, HEAD, FOOT, MIN_W = 16, 44, 48, 340
local ROPES, BURST = 3, 6
local CHOOSER_W = 248
-- style Azeroth (2.5.1, maquette validée) : fenêtre en bois, plaque de titre,
-- cases avec la créature dans le cadre d'icône doré des hauts faits
local AZB = { tileW = 132, tileH = 148, gapX = 14, gapY = 16, ring = 96, window = 72, model = 76, net = 104,
	pad = 30, head = 150, foot = 50, minW = 440, plateW = 330, plateH = 92, plateY = -22, rowY = -118,
	stopW = 104, stopH = 22, shieldW = 40, shieldH = 36 }
ns.CAPTURE_BATCH_AZEROTH = AZB
-- le choix au filet, en bois : le glyphe du filet dans son cadre, la légende,
-- deux boutons dorés (avec leur ligne de dessous), les raccourcis
local AZC = { w = 300, h = 252, ring = 44, glyph = 28, ringY = -22, captionY = -70, buttonH = 44,
	oneY = -90, allY = -142, hintY = -194, gap = 14 }
ns.CAPTURE_CHOOSER_AZEROTH = AZC
local RANK_ORDER = { trivial = 0, minus = 0, normal = 1, elite = 2, rare = 3, rareelite = 4, worldboss = 5 }

local FR = {
	CAPTURE_BATCH_ACTION   = "Tout capturer",
	CAPTURE_BATCH_TIP      = "Lance le filet sur toutes les créatures qui attendent, d'un coup. Chaque essai compte comme un lancer (et coûte l'aide choisie).",
	CAPTURE_BATCH_TITLE    = "Tout capturer",
	CAPTURE_BATCH_COUNT    = "Captures : %d",
	CAPTURE_BATCH_STOP     = "Arrêter",
	CAPTURE_BATCH_CLOSE    = "Fermer",
	CAPTURE_BATCH_FLED     = "échappée",
	CAPTURE_BATCH_NEW      = "Nouvelle",
	CAPTURE_BATCH_SHINY    = "Brillante",
	CAPTURE_BATCH_BETTER   = "Mieux",
	CAPTURE_BATCH_RUNNING  = "Résultats déjà enregistrés : Arrêter montre tout.",
	CAPTURE_BATCH_DONE     = "Résultats enregistrés · Échap pour fermer",
	CAPTURE_BATCH_SUMMARY  = "Tout capturer : %d capturées sur %d essais.",
	CAPTURE_BATCH_SUMMARY_SHINY = "Tout capturer : %d capturées sur %d essais, dont %d brillantes !",
	CAPTURE_BATCH_SHORT    = "Plus assez de %s : %d essais sur %d, les autres restent dans le filet.",
	CAPTURE_BATCH_BUSY     = "Un filet est déjà lancé : attends son verdict.",
	CAPTURE_CHOOSE_TITLE   = "Le filet",
	CAPTURE_CHOOSE_ONE     = "Capturer : %s",
	CAPTURE_CHOOSE_ALL     = "Tout capturer (%d)",
	CAPTURE_CHOOSE_PAUSED  = "Le temps est en pause pendant que tu choisis.",
	CAPTURE_Q_CLICK_CHOOSE = "Clic : choisir (%s, ou tout capturer)",
	CAPTURE_Q_SHIFT        = "Maj+clic : capturer %s tout de suite",
	CAPTURE_Q_CTRL         = "Ctrl+clic : tout capturer (%d) tout de suite",
	CAPTURE_TOAST_HINT_CHOOSE = "Clic : choisir · clic droit : la liste",
	CAPTURE_BATCH_AID      = "Aide : %s",
	CAPTURE_CHOOSE_COUNT   = "%d créatures dans le filet",
	CAPTURE_CHOOSE_SHINY   = "brillante",
	CAPTURE_CHOOSE_ALL_AID = "chaque essai coûte : %s",
	CAPTURE_CHOOSE_ALL_FREE = "un lancer pour chacune",
	CAPTURE_CHOOSE_KEYS    = "Maj+clic : la meilleure · Ctrl+clic : tout · Échap : fermer",
}
local EN = {
	CAPTURE_BATCH_ACTION   = "Capture all",
	CAPTURE_BATCH_TIP      = "Throws the net at every creature waiting, all at once. Each try counts as a throw (and uses the chosen aid).",
	CAPTURE_BATCH_TITLE    = "Capture all",
	CAPTURE_BATCH_COUNT    = "Captures: %d",
	CAPTURE_BATCH_STOP     = "Stop",
	CAPTURE_BATCH_CLOSE    = "Close",
	CAPTURE_BATCH_FLED     = "got away",
	CAPTURE_BATCH_NEW      = "New",
	CAPTURE_BATCH_SHINY    = "Shiny",
	CAPTURE_BATCH_BETTER   = "Better",
	CAPTURE_BATCH_RUNNING  = "Results already saved: Stop shows them all.",
	CAPTURE_BATCH_DONE     = "Results saved · Escape to close",
	CAPTURE_BATCH_SUMMARY  = "Capture all: %d captured out of %d tries.",
	CAPTURE_BATCH_SUMMARY_SHINY = "Capture all: %d captured out of %d tries, %d of them shiny!",
	CAPTURE_BATCH_SHORT    = "Out of %s: %d tries out of %d, the others stay in the net.",
	CAPTURE_BATCH_BUSY     = "A net is already out: wait for its verdict.",
	CAPTURE_CHOOSE_TITLE   = "The net",
	CAPTURE_CHOOSE_ONE     = "Capture: %s",
	CAPTURE_CHOOSE_ALL     = "Capture all (%d)",
	CAPTURE_CHOOSE_PAUSED  = "Time is paused while you choose.",
	CAPTURE_Q_CLICK_CHOOSE = "Click: choose (%s, or capture all)",
	CAPTURE_Q_SHIFT        = "Shift-click: capture %s right away",
	CAPTURE_Q_CTRL         = "Ctrl-click: capture all (%d) right away",
	CAPTURE_TOAST_HINT_CHOOSE = "Click: choose · right-click: the list",
	CAPTURE_BATCH_AID      = "Aid: %s",
	CAPTURE_CHOOSE_COUNT   = "%d creatures in the net",
	CAPTURE_CHOOSE_SHINY   = "shiny",
	CAPTURE_CHOOSE_ALL_AID = "each try uses: %s",
	CAPTURE_CHOOSE_ALL_FREE = "one throw for each",
	CAPTURE_CHOOSE_KEYS    = "Shift-click: the best · Ctrl-click: all · Escape: close",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_BATCH_STRINGS = { fr = FR, en = EN } end

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
local function Enabled()
	local on = ns.CompanionOn and ns.CompanionOn() or false
	return on and ns:DB().companionCapture ~= false
end
local function Tooltip() local t = G("GameTooltip"); if type(t) == "table" and t.SetOwner then return t end end
local function Tint(region, c, alpha) if region and c then region:SetVertexColor(c[1], c[2], c[3], alpha or 1) end end
local function Method(obj, name, ...)
	if obj and type(obj[name]) == "function" then return pcall(obj[name], obj, ...) end
	return false
end
local function Upper(text) return Theme.Upper and Theme.Upper(text) or text end
-- Style des fenêtres de capture (2.5.1) : Azeroth (bois) ou Sobre
local function SceneStyle(self)
	return (self.AzerothScenesOn and self:AzerothScenesOn()) and "azeroth" or "sobre"
end
-- Une fenêtre par style, gardée (cache[style]) : rend celle du style voulu
-- déjà construite, ou nil (à construire). Celle du style d'avant reste à
-- l'écran tant qu'elle y est (le nouveau style vient à la prochaine).
local function Reuse(self, field, cacheField, want)
	local current = self[field]
	if current and ((current.uiStyle or "sobre") == want or current:IsShown()) then return current end
	self[cacheField] = self[cacheField] or {}
	if current then self[cacheField][current.uiStyle or "sobre"] = current end
	local kept = self[cacheField][want]
	if kept then self[field] = kept end
	return kept
end

-- Pendant le tirage, les verdicts ne font pas de bruit : la scène joue les
-- sons quand chaque filet tient
do
	local base = ns.CapturePlaySound
	if base then
		function ns:CapturePlaySound(key, ...)
			if self.captureBatchResolving then return false end
			return base(self, key, ...)
		end
	end
end

-- Les prises de la pause du compte à rebours (CaptureQueue.lua) : la scène
-- tant qu'elle se joue, le choix tant qu'il est ouvert
if type(ns.CAPTURE_HOLD_CHECKS) == "table" then
	ns.CAPTURE_HOLD_CHECKS.batch = function(self)
		local batch = self.captureBatch
		return batch ~= nil and not batch.done
	end
	ns.CAPTURE_HOLD_CHECKS.chooser = function(self)
		local chooser = self.captureChooser
		return chooser ~= nil and chooser:IsShown() and true or false
	end
end
local function Hold(self, reason) if self.CaptureQueueHold then self:CaptureQueueHold(reason) end end
local function Release(self, reason) if self.CaptureQueueRelease then self:CaptureQueueRelease(reason) end end

-- ---------------------------------------------------------------------------
-- Le tirage : tous les verdicts, enregistrés d'un coup
-- ---------------------------------------------------------------------------
-- « Tout capturer » est-il proposé ? (au moins CAPTURE_BATCH_MIN candidats)
function ns:CaptureBatchOffered()
	if not Enabled() then return false end
	local queue = self.captureState and self.captureState.queue
	return queue ~= nil and #queue >= ns.CAPTURE_BATCH_MIN
end

-- Force d'un résultat : sert à garder le plus beau pour la fin
local function Strength(result)
	local target = result.target
	return (target.shiny and 1000 or 0) + (result.fresh and 100 or 0)
		+ (RANK_ORDER[target.class] or 1) * 10 + (tonumber(result.stars) or 0)
end
-- Une brillante (prise ou non) : son filet se débat plus longtemps et tombe
-- en dernier (les espèces nouvelles, la plupart du filet, tombent avec la
-- volée : elle garde son effet). Prise ou non, pour ne rien trahir avant.
local function Special(result)
	return result.target.shiny and true or false
end
ns.CaptureBatchStrength, ns.CaptureBatchSpecial = Strength, Special

-- Tente toute la file (dans son ordre de priorité). Renvoie le lot
-- { results, tried, total, short, aid } et ouvre la scène, ou nil et la
-- raison ("off", "combat", "busy", "empty").
function ns:CaptureBatch()
	if not Enabled() then return nil, "off" end
	if InCombat() then self:Print(L.CAPTURE_BATCH_COMBAT); return nil, "combat" end
	local state = self:CaptureState()
	self:CaptureHideQueueList()
	self:CaptureChooserHide()
	-- le verdict d'un lancer seul est encore à l'écran : on le referme
	if state.rolling and state.rolling.result then
		state.rolling.closeAt = Clock()
		self:CaptureTick(Clock())
	end
	if state.rolling then self:Print(L.CAPTURE_BATCH_BUSY); return nil, "busy" end
	-- un lot encore à l'écran : il se montre d'un coup avant le suivant
	if self.captureBatch and not self.captureBatch.done then self:CaptureBatchStop(true) end
	local queue = self:CaptureQueuePrune()
	if #queue == 0 then self:Print(L.CAPTURE_Q_NOTHING); return nil, "empty" end
	local picked = {}
	for index, candidate in ipairs(queue) do picked[index] = candidate end
	-- le compte à rebours de ceux qui resteront attend la fin de la scène
	Hold(self, "batch")
	local aid = state.aid
	if aid and self:CaptureAidCount(aid) <= 0 then aid, state.aid = nil, nil end
	-- le tutoriel de la ménagerie attendait le filet (avant que la file ne se vide)
	if self.CompanionSequenceAdvance then pcall(self.CompanionSequenceAdvance, self, "net") end
	self:CaptureToastHide()
	self:CapturePlaySound("throw")

	local batch = { results = {}, total = #picked, aid = aid, messages = {}, startedAt = Clock() }
	-- chat et bulles retenus jusqu'à la fin de la scène
	local print, say = self.Print, self.CompanionSay
	self.Print = function(_, ...) batch.messages[#batch.messages + 1] = { ... } end
	self.CompanionSay = function() return false, "batch" end
	self.captureBatchResolving = true
	local ok, err = pcall(function()
		for _, candidate in ipairs(picked) do
			-- une capture précédente du lot a pu lui ôter son intérêt (même
			-- espèce, déjà à 3 étoiles) : il sort du filet sans essai
			if not self:CaptureQueueReason(candidate) then
				self:CaptureQueueRemove(candidate)
			else
				-- l'aide manque : les suivants restent dans le filet
				if aid and self:CaptureAidCount(aid) <= 0 then batch.short = true; break end
				self:CaptureQueueRemove(candidate)
				local target = {}
				for key, value in pairs(candidate) do target[key] = value end
				target.expires = nil
				local shiny = target.shiny and true or false
				local fresh = not self:CaptureIsCaptured(target.npcID)
				local before = self:CaptureStars(target.npcID, shiny)
				local rolling = self:CaptureRoll(target, aid)
				rolling.batch = true
				rolling.result = rolling.success and "ok" or "fail"
				local done, why = pcall(self.CaptureResolve, self, rolling)
				if not done and self.RecordError then self:RecordError("capture:batch", why) end
				batch.results[#batch.results + 1] = {
					target = target, success = rolling.success and true or false, stars = rolling.stars, shakes = rolling.shakes,
					better = rolling.starsBetter, before = before, fresh = fresh, aid = rolling.aid,
				}
			end
		end
	end)
	self.captureBatchResolving = nil
	self.Print, self.CompanionSay = print, say
	if not ok and self.RecordError then self:RecordError("capture:batch", err) end
	batch.tried = #batch.results
	if batch.short then
		batch.messages[#batch.messages + 1] = { self:F("CAPTURE_BATCH_SHORT", self:CaptureAidLabel(aid), batch.tried, batch.total) }
	end
	self:CaptureQueueRefresh()
	self.captureBatch = batch
	if batch.tried == 0 then
		batch.done = true
		Release(self, "batch")
		self:CaptureBatchFlush(batch)
		return batch
	end
	self:CaptureBatchShow(batch)
	return batch
end

-- Ce qui a été retenu pendant le tirage : les messages, un bilan, une bulle
-- du compagnon (la plus belle prise), et la suite du tutoriel
function ns:CaptureBatchFlush(batch)
	if not batch or batch.flushed then return end
	batch.flushed = true
	for _, message in ipairs(batch.messages) do self:Print(unpack(message)) end
	local got, shinies, best = 0, 0, nil
	for _, result in ipairs(batch.results) do
		if result.success then
			got = got + 1
			if result.target.shiny then shinies = shinies + 1 end
			if not best or Strength(result) > Strength(best) then best = result end
		end
	end
	batch.got = got
	if batch.tried > 0 then
		self:Print(shinies > 0 and self:F("CAPTURE_BATCH_SUMMARY_SHINY", got, batch.tried, shinies)
			or self:F("CAPTURE_BATCH_SUMMARY", got, batch.tried))
		if best then
			self:CompanionSay(best.target.shiny and "CAPTURE_SHINY" or "CAPTURE_OK", { force = true, args = { best.target.name } })
		else
			local last = batch.results[#batch.results]
			self:CompanionSay("CAPTURE_FAIL", { force = true, args = { last and last.target.name or "" } })
		end
	end
	-- la scène est « refermée » pour le tutoriel de la ménagerie (Companion.lua)
	if self.CompanionSequenceAdvance then pcall(self.CompanionSequenceAdvance, self, "stage", { ok = got > 0 }) end
end


-- ---------------------------------------------------------------------------
-- La scène : une grille de petites scènes de capture, jouées en même temps
-- ---------------------------------------------------------------------------
-- Même langage que la scène d'un lancer seul (CaptureStage.lua), en petit :
-- le filet tombe sur la créature et rebondit, son ombre le rejoint ; il se
-- secoue (la créature se débat dessous, le halo de rareté pulse) ; puis il
-- tient (éclair, étincelles, il se referme et s'efface, la créature tourne
-- sur elle-même, ses étoiles) ou se déchire (il tombe, ses cordes volent, la
-- créature file sur le côté et s'efface).
local function Coords() return ns.CAPTURE_COORDS or {} end
local FXC = ns.CAPTURE_FX_COLORS   -- 2.11.2 : teintes de CaptureStage.lua (mêmes valeurs)
local WHITE, DUST_COLOR = FXC.white, FXC.dust
local function Clamp01(x) return math.max(0, math.min(1, x)) end
local function EaseOut(x) x = Clamp01(x); return 1 - (1 - x) * (1 - x) end
local function EaseBack(x)
	x = Clamp01(x)
	local k = 1.7
	return 1 + (k + 1) * (x - 1) ^ 3 + k * (x - 1) ^ 2
end
local function Place(region, anchor, x, y)
	region:ClearAllPoints()
	region:SetPoint("CENTER", anchor, "CENTER", x, y)
end
local function Rotate(tex, radians) if tex.SetRotation then pcall(tex.SetRotation, tex, radians) end end
-- une image du client (atlas, 2.11.0) garde sa découpe : seules les nôtres en ont une
local function Coord(tex, c) if c and not tex.clientArt then tex:SetTexCoord(c[1], c[2], c[3], c[4]) end end
-- opacité et visibilité d'un coup : à 0, la région est cachée
local function Fade(region, alpha)
	if alpha <= 0 then region:Hide(); return end
	region:SetAlpha(math.min(1, alpha))
	region:Show()
end
local function HideAll(list) for _, region in ipairs(list) do region:Hide() end end
local function Step() return ns.CAPTURE_SHAKE_STEP or 0.55 end
-- 2.11.0 : `role` de ns.CaptureArtPaint (2.12.1 : image du client, vide si absente)
local function Texture(parent, layer, sub, role, coords, w, h, blend)
	local tex = parent:CreateTexture(nil, layer, nil, sub)
	if ns.CaptureArtPaint then ns.CaptureArtPaint(tex, role, coords) end
	tex:SetSize(w, h or w)
	if blend and tex.SetBlendMode then pcall(tex.SetBlendMode, tex, blend) end
	tex:Hide()
	return tex
end

-- Azeroth : la créature dans le cadre d'icône doré (le cadre devant le
-- modèle), le bouclier du verdict au coin, le nom en Friz (or pour une
-- brillante), les étoiles ou « échappée », l'étiquette dessous
local AZ_IDLE, AZ_FLED_NAME = FXC.idle, FXC.fledName
local function CreateTileAzeroth(parent)
	local coords = Coords()
	local tile = CreateFrame("Frame", nil, parent)
	tile:SetSize(AZB.tileW, AZB.tileH)
	tile.az = true
	tile.netSize, tile.sceneH, tile.haloSize, tile.modelSize, tile.flee = AZB.net, AZB.window, AZB.ring + 12, AZB.model, 36
	local level = tile:GetFrameLevel() or 1
	-- la fenêtre du cadre d'icône : la scène, qui rogne
	tile.scene = CreateFrame("Frame", nil, tile)
	tile.scene:SetSize(AZB.window, AZB.window)
	tile.scene:SetPoint("TOP", tile, "TOP", 0, -2 - (AZB.ring - AZB.window) / 2)
	Method(tile.scene, "SetClipsChildren", true)
	tile.bg = Theme.Solid(tile, "BACKGROUND", FXC.tileBg, 1)
	tile.bg:SetAllPoints(tile.scene)
	tile.halo = Texture(tile, "ARTWORK", 2, "halo", nil, tile.haloSize, tile.haloSize, "ADD")
	tile.halo:SetPoint("CENTER", tile.scene, "CENTER", 0, 0)
	-- 2.9.1 : la créature est l'icône fixe de son type (ns.MENAGERIE_TYPE_ICONS),
	-- comme la scène de capture depuis 2.9.0 : le modèle 3D se cadrait mal (le
	-- zoom visait une tête absente, la case ne montrait que le corps ou les
	-- pattes). L'icône remplit le trou du cadre doré (ns.AZEROTH_ICON_HOLE), centrée.
	local hole = ns.AZEROTH_ICON_HOLE or { l = 17 / 74, r = 57 / 74 }
	tile.iconSize = math.floor(AZB.ring * (hole.r - hole.l) + 0.5)
	tile.fallback = tile.scene:CreateTexture(nil, "ARTWORK")
	tile.fallback:SetSize(tile.iconSize, tile.iconSize)
	tile.fallback:SetTexture(ns.AZEROTH_PORTRAIT_ICON or "Interface\\Icons\\Ability_Hunter_BeastTaming")
	tile.fallback:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tile.fallback:Hide()
	-- le cadre doré, devant le modèle (un cadre enfant passe devant le 3D)
	tile.ringFrame = CreateFrame("Frame", nil, tile)
	tile.ringFrame:SetAllPoints(tile)
	tile.ringFrame:SetFrameLevel(level + 4)
	tile.ring = tile.ringFrame:CreateTexture(nil, "ARTWORK")
	tile.ring:SetSize(AZB.ring, AZB.ring)
	tile.ring:SetPoint("TOP", tile, "TOP", 0, -2)
	if ns.AzerothAtlas then ns.AzerothAtlas(tile.ring, ns.AZEROTH_ATLAS and ns.AZEROTH_ATLAS.frame) end
	-- au-dessus : le filet, son ombre, ses cordes, les étincelles, l'éclair, le bouclier
	tile.fx = CreateFrame("Frame", nil, tile)
	tile.fx:SetAllPoints(tile.scene)
	tile.fx:SetFrameLevel(level + 6)
	tile.shadow = Texture(tile.fx, "ARTWORK", 0, "net", coords.netWhole, AZB.net)
	tile.net = Texture(tile.fx, "ARTWORK", 1, "net", coords.netWhole, AZB.net)
	tile.ropes = {}
	for index = 1, ROPES do
		local p = Texture(tile.fx, "ARTWORK", 2, "rope", nil, 22 + index * 5, 5)
		p.vx, p.vy, p.spin, p.rot0 = (index - 2) * 45, 50 + index * 18, (index - 2) * 2.2 + 0.8, index * 0.9
		tile.ropes[index] = p
	end
	tile.burst = {}
	for index = 1, BURST do
		local p = Texture(tile.fx, "ARTWORK", 3, "sparks", nil, 11, 11, "ADD")
		p.angle = (index / BURST) * math.pi * 2 + 0.3
		p.reach = 40 + (index % 3) * 6
		tile.burst[index] = p
	end
	tile.dust = Texture(tile.fx, "ARTWORK", 2, "dust", nil, 44, 13, "ADD")
	tile.flash = Texture(tile.fx, "ARTWORK", 4, "halo", nil, 120, 120, "ADD")
	tile.flash:SetPoint("CENTER", tile.scene, "CENTER", 0, 0)
	tile.shield = tile.fx:CreateTexture(nil, "OVERLAY")
	tile.shield:SetSize(AZB.shieldW, AZB.shieldH)
	tile.shield:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -4, 4)
	tile.shield:Hide()
	-- 2.9.1 : l'écu n'est plus vide : il porte le nombre d'étoiles obtenues,
	-- centré comme les points des hauts faits (ns.AzerothShieldCenter)
	tile.shieldText = tile.fx:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER or Theme.F_TITLE or Theme.F_SMALL)
	if ns.AzerothFont then ns.AzerothFont(tile.shieldText, 13, "OUTLINE") end
	tile.shieldText:SetTextColor(WHITE[1], WHITE[2], WHITE[3], 1)
	Theme.TextShadow(tile.shieldText)
	if ns.AzerothShieldCenter then ns.AzerothShieldCenter(tile.shieldText, tile.shield) end
	tile.shieldText:SetText("")
	tile.shieldText:Hide()
	-- sous le cadre : le nom, les étoiles (ou « échappée »), l'étiquette
	tile.name = tile:CreateFontString(nil, "OVERLAY", Theme.F_LABEL or Theme.F_SMALL)
	tile.name:SetPoint("TOP", tile, "TOP", 0, -AZB.ring - 4)
	tile.name:SetWidth(AZB.tileW - 6)
	tile.name:SetJustifyH("CENTER")
	if ns.AzerothFont then ns.AzerothFont(tile.name, 12) end
	Theme.TextShadow(tile.name)
	if tile.name.SetWordWrap then tile.name:SetWordWrap(false) end
	tile.stars = Theme.Text(tile, Theme.F_SMALL, Theme.PARCHMENT)
	tile.stars:SetPoint("TOP", tile.name, "BOTTOM", 0, -3)
	tile.stars:SetJustifyH("CENTER")
	tile.tag = Theme.Text(tile, Theme.F_CAPS or Theme.F_SMALL, Theme.GOLD)
	tile.tag:SetPoint("TOP", tile.stars, "BOTTOM", 0, -2)
	return tile
end

local function CreateTile(parent, az)
	if az then return CreateTileAzeroth(parent) end
	local coords = Coords()
	local tile = CreateFrame("Frame", nil, parent)
	tile:SetSize(TILE_W, TILE_H)
	tile.bg = Theme.Solid(tile, "BACKGROUND", Theme.NAV or Theme.WINDOW, 1)
	tile.bg:SetAllPoints()
	tile.edge = Theme.Border(tile, Theme.GOLD_SOFT or Theme.GOLD, 1)
	-- le filet haut, à la couleur de la rareté (au verdict)
	tile.bar = Theme.Solid(tile, "BORDER", WHITE, 1)
	tile.bar:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
	tile.bar:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -1, -1)
	tile.bar:SetHeight(3)
	-- la scène : un rectangle qui rogne (la créature qui s'enfuit n'en sort pas)
	tile.scene = CreateFrame("Frame", nil, tile)
	tile.scene:SetSize(TILE_W - 8, SCENE_H)
	tile.scene:SetPoint("TOP", tile, "TOP", 0, -6)
	Method(tile.scene, "SetClipsChildren", true)
	-- derrière le modèle (sur la case elle-même) : le halo de rareté
	tile.halo = Texture(tile, "ARTWORK", 2, "halo", nil, 104, 104, "ADD")
	tile.halo:SetPoint("CENTER", tile.scene, "CENTER", 0, 0)
	tile.fallback = tile.scene:CreateTexture(nil, "ARTWORK")
	tile.fallback:SetSize(44, 44)
	tile.fallback:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
	tile.fallback:Hide()
	-- au-dessus du modèle (un cadre enfant passe devant le 3D) : le filet, son
	-- ombre, ses cordes, les étincelles, l'éclair, l'étiquette
	tile.fx = CreateFrame("Frame", nil, tile)
	tile.fx:SetAllPoints(tile.scene)
	tile.fx:SetFrameLevel((tile:GetFrameLevel() or 1) + 6)
	tile.shadow = Texture(tile.fx, "ARTWORK", 0, "net", coords.netWhole, NET)
	tile.net = Texture(tile.fx, "ARTWORK", 1, "net", coords.netWhole, NET)
	tile.ropes = {}
	for index = 1, ROPES do
		local p = Texture(tile.fx, "ARTWORK", 2, "rope", nil, 20 + index * 5, 5)
		p.vx, p.vy, p.spin, p.rot0 = (index - 2) * 45, 50 + index * 18, (index - 2) * 2.2 + 0.8, index * 0.9
		tile.ropes[index] = p
	end
	tile.burst = {}
	for index = 1, BURST do
		local p = Texture(tile.fx, "ARTWORK", 3, "sparks", nil, 10, 10, "ADD")
		p.angle = (index / BURST) * math.pi * 2 + 0.3
		p.reach = 34 + (index % 3) * 6
		tile.burst[index] = p
	end
	tile.dust = Texture(tile.fx, "ARTWORK", 2, "dust", nil, 40, 12, "ADD")
	tile.flash = Texture(tile.fx, "ARTWORK", 4, "halo", nil, 110, 110, "ADD")
	tile.flash:SetPoint("CENTER", tile.scene, "CENTER", 0, 0)
	tile.tag = Theme.Text(tile.fx, Theme.F_CAPS or Theme.F_SMALL, Theme.GOLD)
	tile.tag:SetPoint("TOP", tile, "TOP", 0, -8)
	-- sous la scène : le nom, puis les étoiles (ou « échappée »)
	tile.name = Theme.Text(tile, Theme.F_LABEL or Theme.F_SMALL, Theme.PARCHMENT)
	tile.name:SetPoint("TOP", tile.scene, "BOTTOM", 0, -5)
	tile.name:SetWidth(TILE_W - 10)
	tile.name:SetJustifyH("CENTER")
	if tile.name.SetWordWrap then tile.name:SetWordWrap(false) end
	tile.stars = Theme.Text(tile, Theme.F_SMALL, Theme.PARCHMENT)
	tile.stars:SetPoint("BOTTOM", tile, "BOTTOM", 0, 10)
	tile.stars:SetJustifyH("CENTER")
	return tile
end

-- Le modèle 3D d'une case, créé à la demande (les premières seulement)
local function TileModel(tile)
	if tile.model then return tile.model end
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, tile.scene)
	if not (ok and model) then return nil end
	model:SetSize(tile.modelSize or MODEL, tile.modelSize or MODEL)
	model:SetPoint("CENTER", tile.scene, "CENTER", 0, 0)
	tile.model = model
	return model
end

-- La créature d'une case (le modèle, ou l'icône) : position, opacité, cap
local function Creature(tile, x, y, alpha, facing)
	if tile.hasModel and tile.model then
		Place(tile.model, tile.scene, x, y)
		Method(tile.model, "SetAlpha", alpha)
		if facing then Method(tile.model, "SetFacing", facing) end
	else
		Place(tile.fallback, tile.scene, x, y)
		Fade(tile.fallback, alpha)
	end
end

-- Effets éphémères au repos
local function Quiet(tile)
	HideAll(tile.ropes)
	HideAll(tile.burst)
	tile.dust:Hide()
	tile.flash:Hide()
end

-- Avant la volée : la créature seule, son nom ; rien n'est dit du verdict
local function ApplyIdle(self, tile, result)
	tile.verdict = nil
	-- 2.11.0 : une case échappée du lot d'avant reprend ses couleurs
	if tile.fallback.SetDesaturated then tile.fallback:SetDesaturated(false) end
	if tile.az then
		tile.shieldKind = ns.AzerothShield and ns.AzerothShield(tile.shield, nil) or nil
		tile.shield:Hide()
		tile.shieldText:SetText("")
		tile.shieldText:Hide()
	else
		Tint(tile.bg, Theme.NAV or Theme.WINDOW, 1)
		if tile.edge and tile.edge.SetColor then local c = Theme.GOLD_SOFT or Theme.GOLD; tile.edge:SetColor(c[1], c[2], c[3], 1) end
		tile.bar:Hide()
	end
	tile.halo:Hide()
	tile.net:Hide()
	tile.shadow:Hide()
	Coord(tile.net, Coords().netWhole)
	Coord(tile.shadow, Coords().netWhole)
	Rotate(tile.net, 0)
	Rotate(tile.shadow, 0)
	Quiet(tile)
	local target = result.target
	tile.name:SetText(target.shiny and self:F("CAPTURE_SHINY_TAG", target.name) or target.name)
	local m = tile.az and AZ_IDLE or Theme.MUTED_LIGHT or Theme.PARCHMENT
	tile.name:SetTextColor(m[1], m[2], m[3])
	if tile.az and ns.AzerothFit then ns.AzerothFit(tile.name, AZB.tileW - 6, 12, 9) end
	tile.stars:SetText("")
	tile.stars:Hide()
	tile.tag:SetText("")
	Creature(tile, 0, 0, 1, 0)
end

-- Le verdict de `result` dans les textes de la case (au moment où le filet
-- tient ou se déchire) ; les étoiles se montrent un peu après
local function ApplyVerdictAzeroth(self, tile, result)
	local target = result.target
	local colors = ns.AZEROTH_COLORS or {}
	tile.name:SetText(target.name)
	if result.success then
		tile.verdict = "ok"
		local c = target.shiny and (colors.shinyName or Theme.GOLD_LIGHT) or WHITE
		tile.name:SetTextColor(c[1], c[2], c[3])
		tile.stars:SetText(self:CaptureStarsText(result.stars or 1, 14))
		tile.stars:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
		local tag = target.shiny and L.CAPTURE_BATCH_SHINY or (result.fresh and L.CAPTURE_BATCH_NEW)
			or (result.before and result.better and L.CAPTURE_BATCH_BETTER) or ""
		tile.tag:SetText(Upper(tag))
		local tc = target.shiny and (colors.shinyName or Theme.GOLD_LIGHT) or Theme.GOLD
		tile.tag:SetTextColor(tc[1], tc[2], tc[3])
		tile.shieldKind = ns.AzerothShield and ns.AzerothShield(tile.shield, "gold") or nil
		if tile.shieldKind then
			if ns.AzerothShieldCenter then ns.AzerothShieldCenter(tile.shieldText, tile.shield) end
			tile.shieldText:SetText(tostring(math.max(1, math.floor(tonumber(result.stars) or 1))))
			tile.shieldText:Show()
		end
	else
		tile.verdict = "fail"
		tile.name:SetTextColor(AZ_FLED_NAME[1], AZ_FLED_NAME[2], AZ_FLED_NAME[3])
		tile.stars:SetText(L.CAPTURE_BATCH_FLED)
		local f = colors.fled or Theme.MUTED_LIGHT
		tile.stars:SetTextColor(f[1], f[2], f[3])
		tile.tag:SetText("")
		Coord(tile.net, Coords().netTorn)
		-- 2.9.0 : plus de bouclier gris sur une échappée (un bouclier sombre et vide,
		-- qui ne disait rien) ; l'or reste réservé aux prises
		tile.shieldKind = nil
		tile.shield:Hide()
		tile.shieldText:SetText("")
		tile.shieldText:Hide()
	end
	if ns.AzerothFit then ns.AzerothFit(tile.name, AZB.tileW - 6, 12, 9) end
end

local function ApplyVerdict(self, tile, result)
	if tile.az then return ApplyVerdictAzeroth(self, tile, result) end
	local target = result.target
	if result.success then
		tile.verdict = "ok"
		local rarity = self.CaptureRarity and self:CaptureRarity(target) or { color = Theme.PARCHMENT }
		local c = rarity.color
		Tint(tile.bg, Theme.ROW or Theme.WINDOW, 1)
		if tile.edge and tile.edge.SetColor then tile.edge:SetColor(c[1], c[2], c[3], 1) end
		tile.bar:Show()
		Tint(tile.bar, c, 1)
		tile.name:SetText(target.name)
		-- 2.11.0 : le nom prend la variante claire du rang (lisible en Sobre)
		local ink = rarity.text or c
		tile.name:SetTextColor(ink[1], ink[2], ink[3])
		tile.stars:SetText(self:CaptureStarsText(result.stars or 1, 14))
		tile.stars:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
		local tag = target.shiny and L.CAPTURE_BATCH_SHINY or (result.fresh and L.CAPTURE_BATCH_NEW)
			or (result.before and result.better and L.CAPTURE_BATCH_BETTER) or ""
		tile.tag:SetText(Theme.Upper and Theme.Upper(tag) or tag)
		local tc = target.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GOLD
		tile.tag:SetTextColor(tc[1], tc[2], tc[3])
	else
		tile.verdict = "fail"
		Tint(tile.bg, Theme.NAV or Theme.WINDOW, 1)
		local e = Theme.EDGE or Theme.MUTED
		if tile.edge and tile.edge.SetColor then tile.edge:SetColor(e[1], e[2], e[3], 1) end
		tile.bar:Hide()
		tile.name:SetText(target.name)
		tile.name:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
		tile.stars:SetText(L.CAPTURE_BATCH_FLED)
		tile.stars:SetTextColor(Theme.RED[1], Theme.RED[2], Theme.RED[3])
		tile.tag:SetText("")
		Coord(tile.net, Coords().netTorn)
	end
end

-- La case figée sur son verdict (fin de l'animation, Arrêter, réglage coupé)
local function ApplyFinal(self, card)
	local tile, result = card.tile, card.result
	if not tile.verdict then ApplyVerdict(self, tile, result) end
	card.settled = true
	tile.net:Hide()
	tile.shadow:Hide()
	Quiet(tile)
	tile.stars:Show()
	if result.success then
		Creature(tile, 0, 0, 1, 0)
		if result.target.shiny then
			Tint(tile.halo, Theme.GOLD_LIGHT or Theme.GOLD, 0.5)
			tile.halo:SetSize(tile.haloSize or 104, tile.haloSize or 104)
			tile.halo:Show()
		else
			tile.halo:Hide()
		end
	else
		-- elle a filé. 2.11.0 (fiche 10) : plus de case noire vide ; son
		-- portrait (ou son icône) reste, grisé et à 45 %, sous le filet déchiré
		if tile.model then tile.model:Hide() end
		tile.hasModel = nil
		Place(tile.fallback, tile.scene, 0, 0)
		if tile.fallback.SetDesaturated then tile.fallback:SetDesaturated(true) end
		Fade(tile.fallback, ns.CAPTURE_FLED_ALPHA)
		Coord(tile.net, Coords().netTorn)
		Place(tile.net, tile.scene, 0, 0)
		tile.net:SetSize(tile.netSize or NET, tile.netSize or NET)
		Rotate(tile.net, -0.12)
		Fade(tile.net, ns.CAPTURE_FLED_NET_ALPHA)
		tile.halo:Hide()
	end
end

-- Un bruit de filet (chute, secousse) : pas plus d'un toutes les 0,06 s
local function NetSound(self, batch, now)
	if batch.quick then return end
	if batch.soundAt and now - batch.soundAt < ns.CAPTURE_BATCH_SOUND_GAP then return end
	if self:CapturePlaySound("net") then batch.soundAt = now end
end

-- La chute puis les secousses (`since` : depuis le début de la chute)
local function DrawShake(self, batch, card, since, now)
	local tile = card.tile
	local drape = Clamp01(since / ns.CAPTURE_BATCH_DRAPE)
	if not card.dropped then
		card.dropped = true
		NetSound(self, batch, now)
	end
	local step = Step()
	local s = since - ns.CAPTURE_BATCH_DRAPE
	local wobble, squeeze = 0, 0
	if s >= 0 then
		local k = math.floor(s / step)
		-- une secousse de plus à chaque pas (pas plus que le tirage n'en prévoit)
		if k + 1 > card.shook and k < card.cap then
			card.shook = k + 1
			NetSound(self, batch, now)
		end
		local inStep = (s % step) / step
		if inStep < 0.5 then
			wobble = math.sin(inStep * math.pi * 6) * 6 * (1 - inStep * 2)
			squeeze = 0.05 * math.sin(inStep * math.pi * 2)
		end
	end
	local lift = 34 * (1 - EaseOut(drape))
	local size = (tile.netSize or NET) * math.max(0.05, 0.6 + 0.4 * EaseBack(drape) - squeeze)
	Place(tile.net, tile.scene, wobble * 0.4, lift)
	tile.net:SetSize(size, size)
	Rotate(tile.net, wobble * 0.015)
	Fade(tile.net, 1)
	Place(tile.shadow, tile.scene, wobble * 0.4 + 3, -6)
	tile.shadow:SetSize(size, size)
	Rotate(tile.shadow, wobble * 0.015)
	Theme.Shade(tile.shadow, 0.2 + 0.2 * drape)
	tile.shadow:Show()
	Creature(tile, wobble, 0, 0.85, wobble * 0.06)
	-- éclair bref et poussière à l'impact
	Tint(tile.flash, WHITE, 1)
	Fade(tile.flash, 0.5 - since * 2.5)
	local u = since / 0.5
	if u < 1 then
		local w = 40 + 50 * EaseOut(u)
		tile.dust:SetSize(w, w * 0.3)
		Place(tile.dust, tile.scene, 0, -(tile.sceneH or SCENE_H) / 2 + 12)
		Tint(tile.dust, DUST_COLOR, 1)
		Fade(tile.dust, 0.45 * (1 - u))
	else
		tile.dust:Hide()
	end
	-- le halo pulse, de plus en plus vite
	local c = card.color
	Tint(tile.halo, c, 0.25 + 0.15 * math.abs(math.sin(now * (3 + card.shook * 1.5))))
	local halo = (tile.haloSize or 104) - 8
	tile.halo:SetSize(halo, halo)
	tile.halo:Show()
end

-- Le verdict en mouvement (`r` : depuis le verdict, < CAPTURE_BATCH_SETTLE)
local function DrawVerdict(card, r)
	local tile, result = card.tile, card.result
	tile.dust:Hide()
	tile.shadow:Hide()
	if result.success then
		local col = card.color
		Tint(tile.flash, WHITE, 1)
		Fade(tile.flash, 0.9 - r / 0.35)
		-- le filet se referme sur elle et s'efface dans l'éclair
		local size = (tile.netSize or NET) * (1 - 0.45 * EaseOut(r / 0.5))
		Place(tile.net, tile.scene, 0, 0)
		tile.net:SetSize(size, size)
		Rotate(tile.net, 0)
		Fade(tile.net, 1 - Clamp01((r - 0.2) / 0.4))
		-- un tour sur elle-même, qui ralentit
		Creature(tile, 0, 0, 1, EaseOut(r / 1.0) * math.pi * 2)
		local burst = Clamp01(r / 0.7)
		for _, p in ipairs(tile.burst) do
			if burst < 1 then
				local d = p.reach * EaseOut(burst)
				Place(p, tile.scene, math.cos(p.angle) * d, math.sin(p.angle) * d - 16 * burst * burst)
				Rotate(p, p.angle + r * 3)
				Tint(p, col, 1)
				Fade(p, 1 - burst)
			else
				p:Hide()
			end
		end
		Tint(tile.halo, col, 0.3 + 0.5 * math.max(0, 1 - r / 1.0))
		tile.halo:SetSize(tile.haloSize or 104, tile.haloSize or 104)
		tile.halo:Show()
		if r >= 0.35 then tile.stars:Show() end
	else
		tile.flash:Hide()
		HideAll(tile.burst)
		-- un sursaut, puis la chute du filet déchiré
		Place(tile.net, tile.scene, -4 * Clamp01(r / 0.5), -120 * r * r)
		Rotate(tile.net, -0.12 * r)
		Fade(tile.net, 1 - Clamp01((r - 0.4) / 0.5))
		local ropeAlpha = 1 - Clamp01((r - 0.5) / 0.5)
		for _, p in ipairs(tile.ropes) do
			Place(p, tile.scene, p.vx * r, 8 + p.vy * r - 260 * r * r)
			Rotate(p, p.rot0 + p.spin * r)
			Fade(p, ropeAlpha)
		end
		-- la fuite, de profil, qui s'efface
		local run = EaseOut(r / 0.8)
		Creature(tile, run * (tile.flee or 50), 0, 1 - Clamp01(run * 1.3), -math.pi / 2)
		Tint(tile.halo, Theme.RED, 0.3 * (1 - Clamp01(r / 1.0)))
		tile.halo:Show()
		if r >= 0.35 then tile.stars:Show() end
	end
end

-- Une volée par style (2.5.1, comme la scène d'un lancer seul) : Sobre ou
-- Azeroth (bois, plaque « TOUT CAPTURER », cadres d'icône), gardées
-- (ns.captureBatchFrames[style]) ; leurs cases resservent d'un lot à l'autre
function ns:EnsureCaptureBatchFrame()
	local want = SceneStyle(self)
	local kept = Reuse(self, "captureBatchFrame", "captureBatchFrames", want)
	if kept then return kept end
	if not (Theme and Theme.CreateToast) then return nil end
	-- un nom global : Échap la referme (UISpecialFrames), comme la scène d'un lancer seul
	local frame = want == "azeroth" and self.AzerothCreateWindow
		and self:AzerothCreateWindow(AZB.minW, 300, { strata = "DIALOG", name = "QuestCompanionCaptureBatchAzeroth" }) or nil
	if not frame then
		frame = Theme.CreateToast(UIParent, MIN_W, 300, { strata = "DIALOG", name = "QuestCompanionCaptureBatch", accent = Theme.GOLD })
		if not frame then return nil end
		frame.uiStyle = "sobre"
	end
	local az = frame.azeroth and true or false
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	frame:EnableMouse(true)
	if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
	-- cachée (Échap, ×, Fermer) : tout ce qui restait se montre d'un coup
	-- (les verdicts sont déjà enregistrés), le chat reçoit ses messages ; les
	-- modèles 3D se vident (la mémoire revient)
	frame:SetScript("OnHide", function()
		local batch = ns.captureBatch
		if batch and not batch.done then ns:CaptureBatchStop(true) end
		for _, tile in ipairs(frame.tiles) do
			if tile.model then ns.ModelForget(tile.model) end
			tile.hasModel = nil
		end
	end)
	-- 2.10.0 : le combat commence, tous les verdicts se figent (comme
	-- « Arrêter ») et la fenêtre se ferme ; rien ne se rouvre après le combat
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", function(f, event)
		if event ~= "PLAYER_REGEN_DISABLED" or not f:IsShown() then return end
		local batch = ns.captureBatch
		if batch and not batch.done then ns:CaptureBatchStop(true) end
		f:Hide()
	end)
	frame.tiles = {}
	local stopClick = function()
		local batch = ns.captureBatch
		if batch and not batch.done then ns:CaptureBatchStop() else frame:Hide() end
	end
	if az then
		-- la plaque : « TOUT CAPTURER », « Captures : N » ; dessous, l'aide à
		-- gauche et Arrêter / Fermer à droite ; la grille ; le pied
		frame.plate = self:AzerothPlate(frame, AZB.plateW, AZB.plateH)
		frame.plate:SetPoint("TOP", frame, "TOP", 0, AZB.plateY)
		frame.title, frame.counter = frame.plate.title, frame.plate.text
		frame.title:SetText(Upper(L.CAPTURE_BATCH_TITLE))
		frame.aidIcon = frame:CreateTexture(nil, "OVERLAY")
		frame.aidIcon:SetSize(14, 14)
		frame.aidIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		frame.aidIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", AZB.pad, AZB.rowY - 4)
		local colors = ns.AZEROTH_COLORS or {}
		frame.aidText = Theme.Text(frame, Theme.F_SMALL, colors.flavour or Theme.PARCHMENT)
		frame.aidText:SetPoint("LEFT", frame.aidIcon, "RIGHT", 4, 0)
		frame.aidText:SetJustifyH("LEFT")
		if frame.aidText.SetWordWrap then frame.aidText:SetWordWrap(false) end
		frame.stop = self:AzerothButton(frame, AZB.stopW, AZB.stopH, L.CAPTURE_BATCH_STOP, stopClick, "dark")
		frame.stop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -AZB.pad, AZB.rowY)
		frame.grid = CreateFrame("Frame", nil, frame)
		frame.grid:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -AZB.head)
		frame.grid:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -AZB.head)
		frame.grid:SetHeight(AZB.tileH)
		frame.footer = Theme.Text(frame, Theme.F_SMALL, colors.hint or Theme.MUTED)
		frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", AZB.pad, 24)
		frame.footer:SetJustifyH("LEFT")
		if frame.footer.SetWordWrap then frame.footer:SetWordWrap(false) end
	else
		local left = frame.contentLeft or PAD
		frame.title = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.MUTED_LIGHT)
		frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -12)
		frame.title:SetText(Theme.Upper and Theme.Upper(L.CAPTURE_BATCH_TITLE) or L.CAPTURE_BATCH_TITLE)
		frame.counter = Theme.Text(frame, Theme.F_TITLE or Theme.F_LABEL, Theme.PARCHMENT)
		frame.counter:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -24)
		if Theme.CreateCloseButton then
			frame.close = Theme.CreateCloseButton(frame, 18)
			frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
		end
		-- l'aide utilisée, en badge sous le ×
		frame.aidIcon = frame:CreateTexture(nil, "OVERLAY")
		frame.aidIcon:SetSize(14, 14)
		frame.aidIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		frame.aidText = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD)
		frame.aidText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
		frame.aidText:SetJustifyH("RIGHT")
		frame.aidIcon:SetPoint("RIGHT", frame.aidText, "LEFT", -4, 0)
		frame.grid = CreateFrame("Frame", nil, frame)
		frame.grid:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEAD)
		frame.grid:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -HEAD)
		frame.grid:SetHeight(TILE_H)
		frame.stop = Theme.CreateButton(frame, "auto", Theme.DIALOG_BUTTON_HEIGHT or 28, L.CAPTURE_BATCH_STOP, stopClick)
		frame.stop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
		frame.footer = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
		frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 18)
		frame.footer:SetJustifyH("LEFT")
		if frame.footer.SetWordWrap then frame.footer:SetWordWrap(false) end
	end
	frame:SetScript("OnUpdate", function(f)
		if not f:IsShown() then return end
		local done, err = pcall(ns.CaptureBatchUpdate, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("capture:batch:scene", err) end
	end)
	frame:Hide()
	self.captureBatchFrames = self.captureBatchFrames or {}
	self.captureBatchFrames[frame.uiStyle or "sobre"] = frame
	self.captureBatchFrame = frame
	return frame
end

-- Taille de la grille pour `n` cases : colonnes, rangées. Azeroth (cases
-- plus grandes) : 5 ou 6 cases en deux rangées de 3
function ns:CaptureBatchGrid(n, az)
	local most = ns.CAPTURE_BATCH_COLS
	if az and (n == 5 or n == 6) then most = 3 end
	local cols = math.max(1, math.min(n, most))
	return cols, math.max(1, math.ceil(n / cols))
end

-- Le déroulé : la volée (un filet toutes les CAPTURE_BATCH_STAGGER s, dans
-- l'ordre de la grille), puis pour chaque case autant de secousses que son
-- tirage ; les brillantes se débattent jusqu'après la dernière ordinaire et
-- tombent une à une, de la plus modeste à la plus belle. Pose card.dropAt,
-- card.resultAt (relatifs au début de la scène) et card.cap (secousses
-- montrées) ; batch.order = l'ordre des verdicts.
function ns:CaptureBatchSchedule(batch)
	local step, drape = Step(), ns.CAPTURE_BATCH_DRAPE
	local ordinary, special = {}, {}
	local lastOrdinary, latestSpecial = nil, 0
	for index, card in ipairs(batch.cards) do
		card.dropAt = ns.CAPTURE_BATCH_LEAD + (index - 1) * ns.CAPTURE_BATCH_STAGGER
		local shakes = math.max(1, math.floor(tonumber(card.result.shakes) or (card.result.success and 3 or 1)))
		card.resultAt = card.dropAt + drape + shakes * step
		card.special = Special(card.result) or nil
		if card.special then
			special[#special + 1] = card
			latestSpecial = math.max(latestSpecial, card.resultAt)
		else
			ordinary[#ordinary + 1] = card
			lastOrdinary = math.max(lastOrdinary or 0, card.resultAt)
		end
	end
	table.sort(special, function(a, b)
		local sa, sb = Strength(a.result), Strength(b.result)
		if sa ~= sb then return sa < sb end
		return a.index < b.index
	end)
	local at = math.max(latestSpecial, lastOrdinary and (lastOrdinary + ns.CAPTURE_BATCH_PAUSE) or 0)
	-- (un pack de brillantes : l'écart se resserre, sans tomber sous le minimum)
	local gap = math.max(ns.CAPTURE_BATCH_SPECIAL_MIN,
		math.min(ns.CAPTURE_BATCH_SPECIAL_GAP, ns.CAPTURE_BATCH_SPECIAL_SPAN / math.max(1, #special)))
	for _, card in ipairs(special) do
		card.resultAt = at
		at = at + gap
	end
	-- secousses montrées : celles du tirage (une brillante : jusqu'à son verdict)
	for _, card in ipairs(batch.cards) do
		card.cap = math.max(1, math.ceil((card.resultAt - card.dropAt - drape) / step - 1e-6))
	end
	local order = {}
	for _, card in ipairs(batch.cards) do order[#order + 1] = card end
	table.sort(order, function(a, b)
		if a.resultAt ~= b.resultAt then return a.resultAt < b.resultAt end
		return a.index < b.index
	end)
	batch.order = order
	return order
end

function ns:CaptureBatchShow(batch)
	local frame = self:EnsureCaptureBatchFrame()
	if not (frame and batch) then return nil end
	local n = #batch.results
	local az = frame.azeroth and true or false
	local tileW, tileH = az and AZB.tileW or TILE_W, az and AZB.tileH or TILE_H
	local gapX, gapY = az and AZB.gapX or TILE_GAP, az and AZB.gapY or TILE_GAP
	local cols, rows = self:CaptureBatchGrid(n, az)
	local gridW = cols * tileW + (cols - 1) * gapX
	local gridH = rows * tileH + (rows - 1) * gapY
	if az then
		frame:SetSize(math.max(AZB.minW, gridW + 2 * AZB.pad), AZB.head + gridH + AZB.foot)
	else
		frame:SetSize(math.max(MIN_W, gridW + 2 * PAD), HEAD + gridH + FOOT)
	end
	frame.grid:SetHeight(gridH)
	batch.cards = {}
	for index = 1, math.max(n, #frame.tiles) do
		local tile = frame.tiles[index]
		if index <= n then
			-- créée à la demande, gardée pour les lots suivants
			if not tile then tile = CreateTile(frame.grid, az); frame.tiles[index] = tile end
			local col, row = (index - 1) % cols, math.floor((index - 1) / cols)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", frame.grid, "TOP", -gridW / 2 + col * (tileW + gapX), -row * (tileH + gapY))
			local result = batch.results[index]
			-- le modèle 3D pour les premières cases, l'icône au-delà ; 2.9.1 : en
			-- Azeroth, toujours l'icône du type (cadrage fixe, voir CreateTileAzeroth)
			-- 2.11.0 : le repli (et la case échappée) montre le portrait 2D de
			-- la créature si son displayID est connu, sinon l'icône de son type
			self:CreaturePortrait(tile.fallback, result.target)
			local model = not tile.az and index <= ns.CAPTURE_BATCH_MODELS and TileModel(tile) or nil
			if tile.model and not model then tile.model:Hide() end
			tile.hasModel = model and self:CaptureModelSetup(model, result.target) or nil
			if tile.hasModel then tile.fallback:Hide() end
			local card = { index = index, tile = tile, result = result, shook = 0 }
			card.color = (self.CaptureRarity and self:CaptureRarity(result.target) or { color = Theme.PARCHMENT }).color
			ApplyIdle(self, tile, result)
			tile:Show()
			batch.cards[index] = card
		elseif tile then
			if tile.model then ns.ModelForget(tile.model) end
			tile.hasModel = nil
			tile:Hide()
		end
	end
	self:CaptureBatchSchedule(batch)
	batch.shown, batch.resolved, batch.soundAt, batch.okAt = 0, 0, nil, nil
	batch.startedAt = Clock()
	frame.counter:SetText(self:F("CAPTURE_BATCH_COUNT", 0))
	local aid
	for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == batch.aid then aid = def end end
	if aid then
		frame.aidIcon:SetTexture(aid.icon)
		local label = tostring(self:CaptureAidLabel(aid.id))
		frame.aidText:SetText(az and self:F("CAPTURE_BATCH_AID", label) or label)
		frame.aidIcon:Show(); frame.aidText:Show()
	else
		frame.aidIcon:Hide(); frame.aidText:Hide()
	end
	frame.stop:SetText(L.CAPTURE_BATCH_STOP)
	frame.footer:SetText(L.CAPTURE_BATCH_RUNNING)
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	-- capture animée coupée (réglage) : tout se montre d'emblée
	if self.CaptureStageOn and not self:CaptureStageOn() then self:CaptureBatchStop(true) end
	return frame
end

-- Un filet vient de tenir ou de se déchirer : compteur, son (les réussites
-- ordinaires groupées, la fanfare pour chaque brillante prise)
local function Resolved(self, batch, card, now)
	card.resolved = true
	batch.resolved = batch.resolved + 1
	ApplyVerdict(self, card.tile, card.result)
	if card.result.success then
		batch.shown = batch.shown + 1
		local frame = self.captureBatchFrame
		if frame then frame.counter:SetText(self:F("CAPTURE_BATCH_COUNT", batch.shown)) end
		if not batch.quick then
			if card.result.target.shiny then
				self:CapturePlaySound("shiny")
			elseif not batch.okAt or now - batch.okAt >= ns.CAPTURE_BATCH_OK_GAP then
				if self:CapturePlaySound("ok") then batch.okAt = now end
			end
		end
	end
end

-- L'horloge de la scène (OnUpdate) : chaque case suit son déroulé, toutes en
-- même temps ; une case figée ne coûte plus rien
function ns:CaptureBatchUpdate(now)
	local batch = self.captureBatch
	if not (batch and batch.cards) then return nil end
	local t = now - (batch.startedAt or now)
	local settle = ns.CAPTURE_BATCH_SETTLE
	for _, card in ipairs(batch.order) do
		if not card.settled then
			if t < card.dropAt then
				-- (au repos jusqu'à son filet : ApplyIdle a tout posé)
			elseif t < card.resultAt then
				DrawShake(self, batch, card, t - card.dropAt, now)
			else
				if not card.resolved then Resolved(self, batch, card, now) end
				local r = t - card.resultAt
				if r >= settle then ApplyFinal(self, card) else DrawVerdict(card, r) end
			end
		end
	end
	-- les brillantes prises battent doucement une fois figées
	for _, card in ipairs(batch.cards) do
		if card.settled and card.special and card.result.success then
			card.tile.halo:SetAlpha(0.35 + 0.25 * math.abs(math.sin(now * 2.5)))
		end
	end
	if not batch.done and batch.resolved >= #batch.cards then self:CaptureBatchFinish() end
	return batch.resolved
end

-- Fin de la scène : tous les verdicts sont tombés ; le chat reçoit ses
-- messages, le compte à rebours de ceux qui restent reprend
function ns:CaptureBatchFinish()
	local batch = self.captureBatch
	if not batch or batch.done then return false end
	batch.done = true
	-- rien de pris dans le lot : le petit son d'échec, une fois
	local any = false
	for _, result in ipairs(batch.results) do if result.success then any = true end end
	if not any and not batch.silent then self:CapturePlaySound("fail") end
	local frame = self.captureBatchFrame
	if frame then
		frame.stop:SetText(L.CAPTURE_BATCH_CLOSE)
		frame.footer:SetText(L.CAPTURE_BATCH_DONE)
	end
	Release(self, "batch")
	self:CaptureBatchFlush(batch)
	return true
end

-- « Arrêter » : tous les verdicts encore en suspens tombent d'un coup, les
-- cases se figent (les verdicts sont déjà enregistrés). quiet : sans son
-- (Échap, nouveau lot, capture animée coupée)
function ns:CaptureBatchStop(quiet)
	local batch = self.captureBatch
	if not batch or batch.done then return false end
	batch.quick = true
	batch.silent = quiet and true or nil
	local now = Clock()
	local shiny, ok = false, false
	for _, card in ipairs(batch.cards or {}) do
		if not card.resolved then
			Resolved(self, batch, card, now)
			if card.result.success then
				if card.result.target.shiny then shiny = true else ok = true end
			end
		end
		if not card.settled then ApplyFinal(self, card) end
	end
	-- la plus belle de celles qui restaient : sa musique, une seule
	if not quiet and (shiny or ok) then self:CapturePlaySound(shiny and "shiny" or "ok") end
	self:CaptureBatchFinish()
	return true
end

function ns:CaptureBatchHide()
	if self.captureBatchFrame then self.captureBatchFrame:Hide() end
end

-- ---------------------------------------------------------------------------
-- Le choix (2.5.0) : clic sur le filet (ou le bandeau) à deux candidats ou
-- plus. Petit panneau ancré au-dessus du filet, au style du bandeau : fond
-- sombre, liseré doré. Deux boutons : le meilleur seul, ou tout. Il se
-- referme par Échap, un clic ailleurs, un second clic sur le filet, le
-- combat, ou quand la file retombe sous deux. Pendant qu'il est ouvert, le
-- compte à rebours de la file est en pause.
-- ---------------------------------------------------------------------------
local function Busy(self)
	local state = self.captureState
	return state ~= nil and state.rolling ~= nil and not state.rolling.result
end
local function Key(name) return Call(G(name)) and true or false end
local function Over(frame)
	if not (frame and frame.IsMouseOver) then return false end
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and over and true or false
end

-- Azeroth (2.5.1) : petit panneau en bois, le glyphe du filet dans son cadre
-- d'icône, « N CRÉATURES DANS LE FILET », deux boutons dorés (le meilleur,
-- avec brillante et chance dessous ; tout, plus sombre, avec ce que coûte
-- chaque essai), les raccourcis. Mêmes champs (.single, .all, .hint, .title).
local function BuildChooserAzeroth(self, frame)
	local bw = AZC.w - 2 * (ns.AZEROTH_WOOD_PAD or 26)
	local colors = ns.AZEROTH_COLORS or {}
	frame.ring = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	frame.ring:SetSize(AZC.ring, AZC.ring)
	frame.ring:SetPoint("TOP", frame, "TOP", 0, AZC.ringY)
	if ns.AzerothAtlas then ns.AzerothAtlas(frame.ring, ns.AZEROTH_ATLAS and ns.AZEROTH_ATLAS.frame) end
	frame.glyph = frame:CreateTexture(nil, "ARTWORK", nil, 0)
	frame.glyph:SetSize(AZC.glyph, AZC.glyph)
	frame.glyph:SetPoint("CENTER", frame.ring, "CENTER", 0, 0)
	-- 2.11.0 : l'icône du filet du jeu (INV_Misc_Net_01), sinon notre glyphe blanc teinté d'or
	if not (ns.CaptureArtPaint and ns.CaptureArtPaint(frame.glyph, "icon")) then frame.glyph:SetTexture(Theme.LOGO_SMALL) end
	if not frame.glyph.clientArt then
		local g = Theme.GOLD_LIGHT or Theme.GOLD
		frame.glyph:SetVertexColor(g[1], g[2], g[3], 1)
	end
	frame.title = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, colors.caption or Theme.GOLD)
	frame.title:SetPoint("TOP", frame, "TOP", 0, AZC.captionY)
	frame.title:SetWidth(bw)
	frame.title:SetJustifyH("CENTER")
	if ns.AzerothFont then ns.AzerothFont(frame.title, 11) end
	if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end
	frame.single = self:AzerothButton(frame, bw, AZC.buttonH, "", function()
		ns:CaptureChooserHide()
		ns:CaptureThrow()
	end, "gold")
	frame.single:SetPoint("TOP", frame, "TOP", 0, AZC.oneY)
	frame.all = self:AzerothButton(frame, bw, AZC.buttonH, "", function()
		ns:CaptureChooserHide()
		ns:CaptureBatch()
	end, "dark")
	frame.all:SetPoint("TOP", frame, "TOP", 0, AZC.allY)
	frame.hint = Theme.Text(frame, Theme.F_SMALL, colors.hint or Theme.MUTED)
	frame.hint:SetPoint("TOP", frame, "TOP", 0, AZC.hintY)
	frame.hint:SetWidth(bw)
	frame.hint:SetJustifyH("CENTER")
	frame.hint:SetText(L.CAPTURE_CHOOSE_KEYS)
end

function ns:EnsureCaptureChooser()
	local want = SceneStyle(self)
	local kept = Reuse(self, "captureChooser", "captureChoosers", want)
	if kept then return kept end
	if not (Theme and Theme.CreateToast) then return nil end
	local frame = want == "azeroth" and self.AzerothCreateWindow
		and self:AzerothCreateWindow(AZC.w, AZC.h, { strata = "DIALOG", name = "QuestCompanionCaptureChooserAzeroth" }) or nil
	if frame then
		frame:EnableMouse(true)
		if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
		BuildChooserAzeroth(self, frame)
	else
		frame = Theme.CreateToast(UIParent, CHOOSER_W, 112, { strata = "DIALOG", name = "QuestCompanionCaptureChooser", accent = Theme.GOLD })
		if not frame then return nil end
		frame.uiStyle = "sobre"
		frame:EnableMouse(true)
		if frame.border and frame.border.SetColor then local c = Theme.GOLD_SOFT or Theme.GOLD; frame.border:SetColor(c[1], c[2], c[3], 1) end
		if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
		local left = frame.contentLeft or 14
		local width = CHOOSER_W - left - 10
		frame.title = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.MUTED_LIGHT)
		frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -9)
		frame.title:SetText(Theme.Upper and Theme.Upper(L.CAPTURE_CHOOSE_TITLE) or L.CAPTURE_CHOOSE_TITLE)
		frame.single = Theme.CreateButton(frame, width, 26, "", function()
			ns:CaptureChooserHide()
			ns:CaptureThrow()
		end, "normal")
		frame.single:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -26)
		frame.all = Theme.CreateButton(frame, width, 26, "", function()
			ns:CaptureChooserHide()
			ns:CaptureBatch()
		end, "primary")
		frame.all:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -58)
		for _, button in ipairs({ frame.single, frame.all }) do
			button.text:SetWidth(width - 12)
			if button.text.SetWordWrap then button.text:SetWordWrap(false) end
		end
		frame.hint = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
		frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -92)
		frame.hint:SetWidth(width)
		frame.hint:SetJustifyH("LEFT")
		if frame.hint.SetWordWrap then frame.hint:SetWordWrap(false) end
		frame.hint:SetText(L.CAPTURE_CHOOSE_PAUSED)
	end
	frame.all:HookScript("OnEnter", function(b)
		local tooltip = Tooltip()
		if not tooltip then return end
		tooltip:SetOwner(b, "ANCHOR_TOP")
		Theme.TooltipLine(tooltip, L.CAPTURE_BATCH_ACTION, Theme.PARCHMENT)
		Theme.TooltipLine(tooltip, L.CAPTURE_BATCH_TIP, Theme.MUTED_LIGHT)
		tooltip:Show()
	end)
	frame.all:HookScript("OnLeave", function() local t = Tooltip(); if t and t.Hide then t:Hide() end end)
	-- refermé (par n'importe quel chemin) : le compte à rebours reprend,
	-- sauf si un lancer vient de prendre le relais
	frame:SetScript("OnHide", function() Release(ns, "chooser") end)
	-- un clic ailleurs (hors du choix et du filet), le combat : on referme
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
	frame:SetScript("OnEvent", function(f, event)
		if not f:IsShown() then return end
		if event == "GLOBAL_MOUSE_DOWN" and (Over(f) or Over(ns.captureNetButton)) then return end
		ns:CaptureChooserHide()
	end)
	-- de quoi se refermer seul, et les libellés à jour (dix fois par seconde)
	frame:SetScript("OnUpdate", function(f)
		if not f:IsShown() then return end
		local now = Clock()
		if f.checkedAt and now - f.checkedAt < 0.1 and now >= f.checkedAt then return end
		f.checkedAt = now
		-- protégé : dix fois par seconde, une erreur inonderait le journal
		local ok, err = pcall(ns.CaptureChooserRefresh, ns)
		if not ok and ns.RecordError then ns:RecordError("capture:chooser", err) end
	end)
	frame:Hide()
	self.captureChoosers = self.captureChoosers or {}
	self.captureChoosers[frame.uiStyle or "sobre"] = frame
	self.captureChooser = frame
	return frame
end

-- Libellés à jour ; refermé si le choix n'a plus lieu d'être. Rend true s'il reste ouvert.
function ns:CaptureChooserRefresh()
	local frame = self.captureChooser
	if not (frame and frame:IsShown()) then return false end
	local net = self.captureNetButton
	if InCombat() or Busy(self) or not self:CaptureBatchOffered() or not (net and net:IsShown()) then
		self:CaptureChooserHide()
		return false
	end
	local queue = self:CaptureQueueState()
	local best = queue[1]
	local name = best.shiny and self:F("CAPTURE_SHINY_TAG", best.name) or best.name
	frame.single:SetText(self:F("CAPTURE_CHOOSE_ONE", name))
	frame.all:SetText(self:F("CAPTURE_CHOOSE_ALL", #queue))
	if frame.azeroth then
		-- la légende, et sous chaque bouton : brillante et chance ; ce que coûte chaque essai
		local colors = ns.AZEROTH_COLORS or {}
		frame.title:SetText(Upper(self:F("CAPTURE_CHOOSE_COUNT", #queue)))
		local aid = self:CaptureState().aid
		local chance, sure = self:CaptureChance(best, aid)
		local odds = sure and L.CAPTURE_TOAST_SURE or self:F("CAPTURE_TOAST_CHANCE", math.floor((chance or 0) * 100 + 0.5 + 1e-9))
		frame.single:SetSub(best.shiny and (L.CAPTURE_CHOOSE_SHINY .. " · " .. odds) or odds)
		frame.all:SetSub(aid and self:F("CAPTURE_CHOOSE_ALL_AID", self:CaptureAidLabel(aid)) or L.CAPTURE_CHOOSE_ALL_FREE)
		local c = best.shiny and (colors.shinyName or Theme.GOLD_LIGHT) or ns.AZEROTH_BUTTONS.text
		frame.single.text:SetTextColor(c[1], c[2], c[3])
	else
		local c = best.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or (Theme.LABEL or Theme.PARCHMENT)
		frame.single.text:SetTextColor(c[1], c[2], c[3])
	end
	frame.best = best
	return true
end

-- Le côté du filet où poser le choix : "left" si le filet est dans la moitié
-- droite de l'écran, "right" sinon
local function ChooserSide(net)
	local ok, x = pcall(net.GetCenter, net)
	local okS, scale = pcall(net.GetEffectiveScale, net)
	local parent = G("UIParent")
	local okW, width, okP, pscale = false, nil, false, nil
	if parent and parent.GetWidth then okW, width = pcall(parent.GetWidth, parent) end
	if parent and parent.GetEffectiveScale then okP, pscale = pcall(parent.GetEffectiveScale, parent) end
	x, width = ok and tonumber(x), okW and tonumber(width)
	if not (x and width) then return "right" end
	x = x * ((okS and tonumber(scale)) or 1)
	width = width * ((okP and tonumber(pscale)) or 1)
	return x > width / 2 and "left" or "right"
end
ns.CaptureChooserSide = ChooserSide

function ns:CaptureChooserShow()
	if not self:CaptureBatchOffered() or InCombat() then return nil end
	local frame = self:EnsureCaptureChooser()
	if not frame then return nil end
	self:CaptureQueuePrune()
	self:CaptureHideQueueList()
	frame:ClearAllPoints()
	local net = self.captureNetButton
	if net and net:IsShown() and frame.azeroth then
		-- à côté du filet, du côté où il y a la place : à gauche s'il est dans
		-- la moitié droite de l'écran, à droite sinon (gardé à l'écran, bois compris)
		local side = ChooserSide(net)
		frame.side = side
		if side == "left" then
			frame:SetPoint("RIGHT", net, "LEFT", -AZC.gap, 0)
		else
			frame:SetPoint("LEFT", net, "RIGHT", AZC.gap, 0)
		end
	elseif net and net:IsShown() then
		frame:SetPoint("BOTTOM", net, "TOP", 0, 8)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
	end
	frame:Show()
	-- dès le clic, le temps de la file s'arrête
	Hold(self, "chooser")
	if not self:CaptureChooserRefresh() then return nil end
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.15) end
	return frame
end

function ns:CaptureChooserHide()
	local frame = self.captureChooser
	if frame and frame:IsShown() then frame:Hide() end
	-- (au cas où OnHide n'a pas été joué)
	Release(self, "chooser")
end

-- Le clic sur le filet : à deux candidats ou plus, le choix ; Maj+clic, le
-- meilleur tout de suite ; Ctrl+clic, tout tout de suite ; un second clic
-- (choix ouvert) le referme. Un seul candidat, un filet déjà en l'air : comme
-- avant (le meilleur). En combat (2.10.0) : refusé, plus de lancer seul.
do
	local base = ns.CaptureNetClick
	if base then
		function ns:CaptureNetClick(mouse, ...)
			local chooser = self.captureChooser
			local open = chooser and chooser:IsShown()
			if mouse == "RightButton" then
				if open then self:CaptureChooserHide() end
				return base(self, mouse, ...)
			end
			if open then self:CaptureChooserHide(); return nil end
			if InCombat() then return self:CaptureRefuseCombat() end
			if not self:CaptureBatchOffered() or Busy(self) then return base(self, mouse, ...) end
			if Key("IsControlKeyDown") then return self:CaptureBatch() end
			if Key("IsShiftKeyDown") then return base(self, mouse, ...) end
			return self:CaptureChooserShow()
		end
	end
end

-- L'infobulle du filet (CaptureQueue.lua) : le choix et ses raccourcis
function ns:CaptureNetClickLines(tooltip, queue, name)
	if not (Enabled() and #queue >= ns.CAPTURE_BATCH_MIN) then return false end
	Theme.TooltipLine(tooltip, self:F("CAPTURE_Q_CLICK_CHOOSE", name), Theme.MUTED_LIGHT)
	Theme.TooltipLine(tooltip, self:F("CAPTURE_Q_SHIFT", name), Theme.MUTED_LIGHT)
	Theme.TooltipLine(tooltip, self:F("CAPTURE_Q_CTRL", #queue), Theme.MUTED_LIGHT)
	return true
end

-- La file a bougé : le choix se referme s'il n'a plus lieu d'être
do
	local refresh = ns.CaptureQueueRefresh
	if refresh then
		function ns:CaptureQueueRefresh(...)
			local count = refresh(self, ...)
			if self.captureChooser and self.captureChooser:IsShown() then self:CaptureChooserRefresh() end
			return count
		end
	end
end


-- ---------------------------------------------------------------------------
-- Les autres entrées : la liste du filet, le bandeau, /qc filet tout
-- ---------------------------------------------------------------------------
local function ShowTip(button, text)
	local tooltip = Tooltip()
	if not tooltip then return end
	tooltip:SetOwner(button, "ANCHOR_TOP")
	Theme.TooltipLine(tooltip, L.CAPTURE_BATCH_ACTION, Theme.PARCHMENT)
	Theme.TooltipLine(tooltip, text, Theme.MUTED_LIGHT)
	tooltip:Show()
end
local function HideTip() local t = Tooltip(); if t and t.Hide then t:Hide() end end

-- Bouton compact : le libellé et un peu d'air
local function CompactWidth(parent, label)
	local w = Theme.TextWidth and Theme.TextWidth(parent, label, Theme.F_LABEL) or 60
	return math.max(36, math.ceil((tonumber(w) or 60) + 16))
end

-- La liste (clic droit sur le filet) : « Tout capturer » en haut, à gauche du ×
do
	local ensure = ns.EnsureCaptureQueueList
	if ensure then
		function ns:EnsureCaptureQueueList(...)
			local fresh = not self.captureQueueList
			local frame = ensure(self, ...)
			if frame and fresh and not frame.all then
				local button = Theme.CreateButton(frame, CompactWidth(frame, L.CAPTURE_BATCH_ACTION), 18, L.CAPTURE_BATCH_ACTION,
					function() ns:CaptureHideQueueList(); ns:CaptureBatch() end, "accent")
				if frame.close then
					button:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
				else
					button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
				end
				button:SetScript("OnEnter", function(b) ShowTip(b, L.CAPTURE_BATCH_TIP) end)
				button:SetScript("OnLeave", HideTip)
				button:Hide()
				frame.all = button
			end
			return frame
		end
	end
	local refresh = ns.CaptureRefreshQueueList
	if refresh then
		function ns:CaptureRefreshQueueList(...)
			local a, b = refresh(self, ...)
			local frame = self.captureQueueList
			if frame and frame.all then
				if self:CaptureBatchOffered() then frame.all:Show() else frame.all:Hide() end
			end
			return a, b
		end
	end
end

-- Le bandeau « Capture possible » : « Tout capturer » à gauche d'Ignorer,
-- dans la rangée du bas (l'aide garde sa ligne au-dessus)
do
	local ensure = ns.EnsureCaptureToast
	if ensure then
		function ns:EnsureCaptureToast(...)
			local fresh = not self.captureToast
			local frame = ensure(self, ...)
			if frame and fresh and not frame.all and frame.ignore then
				local button = Theme.CreateButton(frame, CompactWidth(frame, L.CAPTURE_BATCH_ACTION), 18, L.CAPTURE_BATCH_ACTION,
					function() ns:CaptureToastHide(); ns:CaptureBatch() end, "accent")
				button:SetPoint("RIGHT", frame.ignore, "LEFT", -6, 0)
				button:SetFrameLevel(frame.ignore:GetFrameLevel() or 1)
				button:SetScript("OnEnter", function(b) ShowTip(b, L.CAPTURE_BATCH_TIP) end)
				button:SetScript("OnLeave", HideTip)
				button:Hide()
				frame.all = button
			end
			return frame
		end
	end
	local show = ns.CaptureToastShow
	if show then
		function ns:CaptureToastShow(...)
			local frame = show(self, ...)
			if frame and frame.all then
				if self:CaptureBatchOffered() then
					frame.all:Show()
					-- le clic sur le bandeau propose le choix (comme sur le filet)
					local more = #self:CaptureQueueState() - 1
					frame.hint:SetText(self:F("CAPTURE_TOAST_MORE", more) .. "  ·  " .. L.CAPTURE_TOAST_HINT_CHOOSE)
				else
					frame.all:Hide()
				end
			end
			return frame
		end
	end
end

-- /qc filet tout (ou all) : tout capturer ; /qc filet seul : le meilleur,
-- sans le choix (comme avant)
if ns.EXTRA_COMMANDS and ns.EXTRA_COMMANDS["filet"] then
	local base = ns.EXTRA_COMMANDS["filet"]
	ns.EXTRA_COMMANDS["filet"] = function(self, rest, ...)
		local sub = tostring(rest or ""):match("^%s*(%S*)")
		sub = (sub or ""):lower()
		if sub == "tout" or sub == "all" then
			self:CaptureBatch()
			return
		end
		return base(self, rest, ...)
	end
	ns.EXTRA_COMMANDS["net"] = ns.EXTRA_COMMANDS["filet"]
end

if ns.Mark then ns.Mark("CaptureBatch") end
