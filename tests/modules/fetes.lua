-- QuestCompanion 3.7.0 : fêtes à la taille de l'exploit, signature, cotes des
-- prises rares, mode discret, annonce de groupe, indice d'un secret (Quiet.lua).
-- Chaque taille (ce qui s'affiche, le son, la bulle), le regroupement mixte, le
-- rattrapage muet, la signature (où elle est, où elle n'est pas), les cotes
-- (quatre exemples, le seuil, jamais avant la prise, trois endroits), le mode
-- discret source par source (laisse passer, coupe, rien en file), l'indice
-- (cadence, repos, mode discret), les contrastes des textes nouveaux.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local FIELDS = { "captureToast", "journalToast", "guildFeatToast", "captureResult", "featPill" }
local GLOBALS = { "UnitName", "UnitLevel", "InCombatLockdown", "UnitAffectingCombat", "PlaySound", "IsResting",
	"IsInGroup", "IsInRaid", "IsInGuild", "SendChatMessage", "GetStatistic" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local savedSay, savedShiny, savedDormant = NS.CompanionSay, NS.SHINY_CHANCE, NS.featsDormant
local savedSouvenir = rawget(NS, "SouvenirShow")

local F = { sounds = {}, says = {}, sends = {} }

local function Fresh(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.errors = {}, {}
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.featPills, NS.featPillHideAt = {}, nil
	NS.captureResultHideAt, NS.captureResultPending = nil, nil
	if NS.bannerLane then NS.bannerLane.showing, NS.bannerLane.frame, NS.bannerLane.waiting = nil, nil, {} end
	F.sounds, F.says, F.sends, F.resting, F.party = {}, {}, {}, false, false
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.GetStatistic = function() return nil end
	_G.PlaySound = function(id) F.sounds[#F.sounds + 1] = id; return true end
	_G.IsResting = function() return F.resting end
	_G.IsInGroup = function(category) return F.party and category ~= 2 end
	_G.IsInRaid = function() return false end
	_G.IsInGuild = function() return false end
	_G.SendChatMessage = function(text, channel) F.sends[#F.sends + 1] = { text = text, channel = channel } end
	NS.CompanionSay = function(self, pool, opts, ...)
		F.says[#F.says + 1] = { pool = pool, opts = opts }
		return savedSay(self, pool, opts, ...)
	end
	NS.SouvenirShow = nil
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS.announceQueue, NS.announceLog = {}, {}
	NS:CompanionData().tutoDone = true
	NS:DB().companionStyle = style or "azeroth"
	NS:DB().winterVeil = "off"
	NS:ApplyUIStyle()
end

local function Done()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	NS.CompanionSay, NS.SHINY_CHANCE, NS.featsDormant = savedSay, savedShiny, savedDormant
	NS.SouvenirShow = savedSouvenir
	NS.featPills, NS.featPillHideAt = {}, nil
	ResetWorld()
	NS.uiStyleCache = {}
end

local function Said(pool)
	for _, said in ipairs(F.says) do if said.pool == pool then return true end end
	return false
end
local function Shown(frame) return frame ~= nil and frame.IsShown and frame:IsShown() and true or false end
local function Award(id)
	F.sounds, F.says = {}, {}
	NS:FeatAward(id)
	NS:FeatFlush(true)
end
local function Clear()
	if NS.journalToast then NS.journalToast:Hide() end
	NS.journalToastHideAt, NS.journalToasts = nil, {}
	if NS.BannerDone then NS:BannerDone("journal") end
	if NS.featPill then NS.featPill:Hide() end
	NS.featPills, NS.featPillHideAt = {}, nil
end

-- 1. Trois tailles de fête -----------------------------------------------------------------------
do
	Say("-- fêtes : trois tailles")
	Fresh("azeroth")
	local s = Steps()
	-- petite (5 points) : une pastille muette, hors du couloir des bandeaux
	Award("char_level_10")
	local pill, toast = NS.featPill, NS.journalToast
	s.ok("petite : une pastille « Haut fait : <nom> » / « 5 points »", Shown(pill)
		and pill.text:GetText() == NS:F("FEAT_PILL_ONE", NS:FeatName(NS:FeatDef("char_level_10")))
		and pill.right:GetText() == "5 points")
	s.ok("petite : aucun son, aucune bulle, aucun bouton", #F.sounds == 0 and not Said("UNLOCK") and pill.shareButton == nil)
	s.ok("petite : ni bandeau ni file, le couloir reste libre", not Shown(toast) and #NS.journalToasts == 0
		and NS:BannerShowing() == nil and (NS.bannerLane.waiting.journal == nil))
	-- un « Capturé ! » arrive pendant la pastille : il passe aussitôt
	NS:CaptureResultQueue({ name = "Raptor", stars = 1 })
	local shownResult = NS:CaptureResultTick(NS.Now())
	s.ok("petite : un « Capturé ! » n'est pas retardé", shownResult == true and Shown(NS.captureResult))
	NS:CaptureResultHide()
	NS:UpdateFeatPill(NS.Now() + NS.FEAT_PILL.life + 0.1)
	s.ok("petite : deux secondes, puis rien", not Shown(pill) and NS.featPillHideAt == nil)
	Clear()
	-- moyenne (10 points) : le bandeau, la ligne de récompense, Partager, un son court
	Award("char_level_30")
	toast = NS.journalToast
	local def30 = NS:FeatDef("char_level_30")
	s.ok("moyenne : le bandeau « Haut fait obtenu »", Shown(toast) and toast.text:GetText() == NS:FeatName(def30))
	s.ok("moyenne : ligne de récompense avec ses paillettes", toast.stars:GetText() == NS:FeatRewardLine(def30)
		and toast.stars:GetText():find(NS:F("FEAT_GLITTER_N", 5), 1, true) == 1, toast.stars:GetText())
	s.ok("moyenne : Partager, un son court, pas de bulle ni de signature", toast.shareButton and toast.shareButton:IsShown()
		and #F.sounds == 1 and F.sounds[1] == NS.FEAT_SOUND_FALLBACK and not Said("UNLOCK")
		and not Shown(toast.qcSignature))
	Clear()
	-- grande (titre) : grand bandeau, « Nouveau titre : … · 15 paillettes », signature, fanfare, bulle
	Award("char_level_60")
	toast = NS.journalToast
	local def60 = NS:FeatDef("char_level_60")
	s.ok("grande : « Nouveau titre : X · N paillettes »", Shown(toast) and toast.stars:GetText() == NS:F("FEAT_TOAST_NEW_TITLE",
		NS:FeatTitleText(def60.reward.title)) .. " · " .. NS:F("FEAT_GLITTER_N", NS:FeatGlitterOf(def60)), toast.stars:GetText())
	s.ok("grande : signature, fanfare, bulle du compagnon, grand effet", Shown(toast.qcSignature)
		and toast.qcSignature.text:GetText() == "QUEST COMPANION" and F.sounds[1] == NS.FEAT_SOUND and Said("UNLOCK")
		and toast.azReward ~= nil)
	s.ok("grande : sans « Carte souvenir » tant que l'étape 3 ne l'a pas livrée ; Partager à droite",
		not Shown(toast.souvenirButton) and toast.shareButton:IsShown())
	Clear()
	-- avec ns.SouvenirShow : le bouton, à gauche de Partager
	local opened
	NS.SouvenirShow = function(_, payload) opened = payload end
	Award("char_kills_10000")
	toast = NS.journalToast
	local sv = toast.souvenirButton
	s.ok("grande (25 points) : « Carte souvenir » à gauche de Partager quand la fonction existe", Shown(sv)
		and sv.lastPoint and sv.lastPoint.relTo == toast.shareButton and sv.label:GetText() == NS.L.SOUVENIR_BUTTON)
	if sv then sv:GetScript("OnClick")(sv) end
	s.ok("… et son clic l'appelle", type(opened) == "table" and opened.kind == "feat")
	NS.SouvenirShow = nil
	Clear()
	s.check("[FETE] petite en pastille muette (2 s, hors couloir), moyenne au son court et sa récompense, grande signée, à la fanfare et à la bulle ; « Carte souvenir » seulement si elle existe")
	Done()
end

-- 2. Regroupement et rattrapage ------------------------------------------------------------------
do
	Say("-- fêtes : regroupement, rattrapage")
	Fresh("azeroth")
	local s = Steps()
	F.sounds, F.says = {}, {}
	NS:FeatAward("char_level_10"); NS:FeatAward("char_level_20"); NS:FeatAward("char_level_60")
	NS:FeatFlush(true)
	local toast = NS.journalToast
	s.ok("mixte : un seul bandeau, de la taille du plus grand (signé, fanfare)", Shown(toast) and toast.entry and toast.entry.count == 3
		and toast.entry.size == "big" and Shown(toast.qcSignature) and F.sounds[1] == NS.FEAT_SOUND and #NS.featPills == 0)
	Clear()
	Fresh("azeroth")
	local small = NS.FeatAdd({ "test_fete_s", 991, "jeu", 5, "account", crit = { "flag", "fete_s" } })
	NS:FeatAward("char_level_10"); NS:FeatAward("char_level_20"); NS:FeatAward(small)
	NS:FeatFlush(true)
	for index = #NS.FEAT_DEFS, 1, -1 do if NS.FEAT_DEFS[index] == small then table.remove(NS.FEAT_DEFS, index) end end
	NS.featIndexDirty = true
	local pill = NS.featPill
	F.dbg = string.format("%s %s %s %s", tostring(pill and pill.text:GetText()), tostring(pill and pill.right:GetText()),
		tostring(Shown(NS.journalToast) and NS.journalToast.text:GetText()), #F.sounds)
	s.ok("trois petits : une seule pastille « 3 hauts faits · 15 points »", Shown(pill) and pill.text:GetText() == NS:F("FEAT_PILL_MANY", 3)
		and pill.right:GetText() == "15 points" and not Shown(NS.journalToast) and #F.sounds == 0, F.dbg)
	Clear()
	-- rattrapage de connexion : déjà acquis, un seul bandeau muet, sans bulle ni signature
	Fresh("azeroth")
	_G.UnitLevel = function() return 60 end
	F.sounds, F.says = {}, {}
	local found = NS:FeatLogin()
	NS:FeatFlush(true)
	toast = NS.journalToast
	if toast and toast.entry and toast.entry.onShow then toast.entry.onShow() end
	s.ok("rattrapage : un seul bandeau groupé, muet", #found >= 2 and Shown(toast) and toast.entry.retro == true
		and #NS.journalToasts == 0 and #F.sounds == 0, #found)
	s.ok("rattrapage : ni bulle, ni signature, ni grand effet", not Said("UNLOCK") and not Shown(toast.qcSignature)
		and not toast.entry.big)
	Clear()
	-- rattrapage d'un seul haut fait, grand : bandeau muet quand même
	Fresh("azeroth")
	F.sounds = {}
	NS:FeatQueue({ id = "char_level_60", name = "Aventurier", pts = 25, size = "big", retro = true })
	NS:FeatFlush(true)
	toast = NS.journalToast
	if toast and toast.entry and toast.entry.onShow then toast.entry.onShow() end
	s.ok("rattrapage d'un seul : muet, sans signature", Shown(toast) and #F.sounds == 0 and not Shown(toast.qcSignature))
	Clear()
	s.check("[FETE] regroupement à la taille du plus grand (tous petits : une pastille) ; rattrapage : un bandeau muet, sans bulle ni signature")
	Done()
end

-- 3. Cotes des prises rares ----------------------------------------------------------------------
do
	Say("-- fêtes : cotes des prises rares")
	Fresh("azeroth")
	NS.SHINY_CHANCE = 1 / 150
	local s = Steps()
	s.ok("brillante seule : 150", NS:SpecimenOdds({ shiny = true, stars = 1, size = "normal", trait = "curious" }) == 150)
	s.ok("brillante et Géante : 7 500", NS:SpecimenOdds({ shiny = true, stars = 1, size = "giant" }) == 7500)
	s.ok("3 étoiles et Géant : 714", NS:SpecimenOdds({ stars = 3, size = "giant" }) == 714)
	s.ok("les trois : 107 143", NS:SpecimenOdds({ shiny = true, stars = 3, size = "giant" }) == 107143)
	s.ok("caractère rare : Zen 1 sur 20, Minuscule pareil que Géant", NS:SpecimenOdds({ stars = 1, trait = "zen" }) == 20
		and NS:SpecimenOdds({ stars = 3, size = "tiny" }) == 714)
	s.ok("rien de rare : rien", NS:SpecimenOdds({ stars = 2, size = "large", trait = "curious" }) == nil)
	-- les tables du jeu font foi
	local odds = NS.CAPTURE_QUALITY_ODDS.normal[3]
	NS.CAPTURE_QUALITY_ODDS.normal[3] = 10
	s.ok("lue dans les tables : 3 étoiles à 10 % et Géant -> 500", NS:SpecimenOdds({ stars = 3, size = "giant" }) == 500)
	NS.CAPTURE_QUALITY_ODDS.normal[3] = odds
	s.ok("seuil : 3 étoiles seules, Géant seul : rien d'affiché ; 714 : affiché",
		NS:SpecimenOddsShown({ stars = 3 }) == nil and NS:SpecimenOddsShown({ size = "giant" }) == nil
		and NS:SpecimenOddsShown({ stars = 3, size = "giant" }) == 714)
	s.ok("libellé et milliers : français, anglais", NS:SpecimenOddsText({ shiny = true, stars = 3, size = "giant" })
		== "Rareté de base : 1 chance sur 107 143" and NS.OddsNumber(107143, "en") == "107,143" and NS.OddsNumber(7500, "es") == "7.500"
		and NS.QUIET_STRINGS.en.SPEC_ODDS_LINE:format(NS.OddsNumber(107143, "en")) == "Base rarity: 1 in 107,143")
	-- 1. le bandeau « Capturé ! » : la sous-ligne sous les étoiles, la signature
	local specId = NS:SpecimenAdd({ npc = 3398, stars = 3, name = "Raptor", origin = "capture", zone = 1413, size = "giant",
		shiny = true, trait = "curious" })
	local frame = NS:CaptureResultShow({ name = "Raptor", shiny = true, stars = 3, npcID = 3398, level = 38, type = "Beast",
		class = "rare", specimen = specId })
	s.ok("bandeau : « Rareté de base : 1 chance sur 107 143 » sous les étoiles", frame and frame.odds and frame.odds:IsShown()
		and frame.odds:GetText() == "Rareté de base : 1 chance sur 107 143", frame and frame.odds and frame.odds:GetText())
	local starsY = frame.stars.lastPoint and frame.stars.lastPoint.y or 0
	local oddsY = frame.odds.lastPoint and frame.odds.lastPoint.y or 0
	s.ok("bandeau : la cote sous la ligne des étoiles, rien ne déborde", oddsY < starsY and frame:GetHeight() >= NS.FORGE_RESULT.h,
		starsY .. " / " .. oddsY)
	s.ok("bandeau : brillante signée", Shown(frame.qcSignature))
	-- 2. la fiche du spécimen : la ligne, et 3. le texte partagé
	local item = NS:ShareItemFromSpecimen(NS:SpecimenGet(specId))
	local text = NS:ShareText(item, "fr")
	s.ok("partage : la cote entre parenthèses après le nom", item.odds == 107143
		and text:find("(version brillante, 3 étoiles, Géant, 1 chance sur 107 143)", 1, true) ~= nil, text)
	s.ok("partage en anglais : « 1 in 107,143 »", NS:ShareText(item, "en"):find("1 in 107,143", 1, true) ~= nil)
	s.ok("fiche : sa ligne de cote", NS:SpecimenOddsText(NS:SpecimenGet(specId)) == "Rareté de base : 1 chance sur 107 143")
	NS:CaptureResultHide()
	-- un « Capturé ! » ordinaire : ni cote ni signature
	frame = NS:CaptureResultShow({ name = "Sanglier", stars = 2, npcID = 3100, level = 12, type = "Beast", class = "normal",
		specimen = { stars = 2, size = "large", trait = "curious" } })
	s.ok("prise ordinaire : ni cote ni signature", not (frame.odds and frame.odds:IsShown()) and not Shown(frame.qcSignature))
	NS:CaptureResultHide()
	-- une prise rare sans brillance (3 étoiles et Géant) : cote et signature
	frame = NS:CaptureResultShow({ name = "Loup", stars = 3, npcID = 3101, level = 12, type = "Beast", class = "normal",
		specimen = { stars = 3, size = "giant", trait = "curious" } })
	s.ok("prise rare (714) : cote et signature", frame.odds:GetText() == "Rareté de base : 1 chance sur 714" and Shown(frame.qcSignature))
	NS:CaptureResultHide()
	-- jamais avant la prise : l'occasion de capture ne dit rien de la cote
	NS:CaptureOffer("Creature-0-1-1-1-3398-0001", { zoneID = 1413, npcID = 3398, shiny = true }, true)
	local before = {}
	for _, key in ipairs({ "title", "text", "stars", "sub", "info" }) do
		local fs = NS.captureToast and NS.captureToast[key]
		if fs and fs.GetText then before[#before + 1] = tostring(fs:GetText() or "") end
	end
	s.ok("jamais avant la prise", not table.concat(before, " "):find("chance sur", 1, true))
	if NS.CaptureToastHide then NS:CaptureToastHide() end
	s.check("[COTE] quatre exemples, tables du jeu, seuil 1 sur 100, libellé « de base » ; bandeau, fiche, partage ; jamais avant la prise")
	Done()
end

-- 4. Mode discret --------------------------------------------------------------------------------
do
	Say("-- fêtes : mode discret")
	Fresh("azeroth")
	local s = Steps()
	s.ok("éteint par défaut", NS:DB().quiet == false and NS:Quiet() == false)
	NS:DB().quiet = true
	s.ok("allumé : ns:Quiet()", NS:Quiet() == true)
	-- coupe : astuces, objectifs, blagues, histoire des lieux, annonces automatiques
	NS:CompanionData().tipsSeen = nil
	F.says = {}
	s.ok("astuces : coupées", NS:CompanionTryTip(true) == false and not Said("TIP"))
	s.ok("objectifs : coupés", NS:CompanionTryGoal() == false and not Said("GOAL") and not Said("GOAL_STAGE"))
	local share = NS.COMPANION_JOKE_SHARE
	NS.COMPANION_JOKE_SHARE = 1
	s.ok("blagues : coupées (le bavardage ordinaire reste)", NS:CompanionIdlePool() == "IDLE")
	s.ok("histoire des lieux : coupée", NS.LoreOn(NS) == false)
	F.party = true
	local sent = NS:AnnounceCaptures({ { kind = "capture", name = "Raptor", shiny = true, stars = 1, key = "cap:x" } })
	s.ok("annonce de groupe : rien d'envoyé, rien en file", sent == false and #F.sends == 0 and #NS.announceQueue == 0)
	NS.announceQueue = { { kind = "capture", name = "Raptor", shiny = true, stars = 1, key = "cap:y" } }
	s.ok("file d'avant le mode : vidée sans envoi", NS:AnnounceFlush() == 0 and #NS.announceQueue == 0 and #F.sends == 0)
	-- hauts faits : pastille muette, même grands, sans bulle
	Award("char_level_60")
	s.ok("grand haut fait : pastille muette, sans bulle ni bandeau", Shown(NS.featPill) and #F.sounds == 0 and not Said("UNLOCK")
		and not Shown(NS.journalToast))
	Clear()
	-- laisse passer : bandeaux de capture, brillante, bonjour, grands événements (bulles forcées)
	local frame = NS:CaptureResultShow({ name = "Raptor", shiny = true, stars = 1, npcID = 3398, level = 20, type = "Beast" })
	s.ok("bandeau de capture et de brillante : passe", Shown(frame))
	NS:CaptureResultHide()
	s.ok("sceau (bandeau du carnet) : passe", NS:JournalToastPush({ kind = "seal", title = "SCEAU", name = "Durotar" }) == true
		and Shown(NS.journalToast))
	Clear()
	-- guilde : un bandeau regroupé toutes les 10 minutes au plus, le reste ne s'accumule pas
	local queue = NS:GuildFeatsQueue()
	local function GuildItem(key, at) return { key = key, sender = key, score = 10, at = at or NS.Now(), feat = { kind = "h" },
		info = { kind = "h", line = key .. " a gagné un haut fait", points = 25 } } end
	NS:GuildFeatsEnqueue(GuildItem("Xan"))
	local first = NS:GuildFeatsToastTick(NS.Now())
	NS:GuildFeatsHideToast()
	NS:GuildFeatsEnqueue(GuildItem("Zul"))
	local second = NS:GuildFeatsToastTick(NS.Now() + 60)
	s.ok("guilde : le premier passe, le suivant (moins de 10 min) ne s'accumule pas", first == true and second == false
		and #NS:GuildFeatsQueue() == 0, tostring(first) .. "/" .. tostring(second))
	NS:GuildFeatsEnqueue(GuildItem("Bob", NS.Now() + NS.QUIET_GUILD_GAP + 1))
	s.ok("guilde : 10 minutes après, de nouveau", NS:GuildFeatsToastTick(NS.Now() + NS.QUIET_GUILD_GAP + 1) == true)
	NS:GuildFeatsHideToast()
	-- éteint : tout comme avant, rien ne sort en rafale
	NS:DB().quiet = false
	F.says, F.sends = {}, {}
	Clear()
	s.ok("éteint : rien en file qui sorte en rafale", #NS.announceQueue == 0 and #NS.featPills == 0 and #NS:GuildFeatsQueue() == 0)
	s.ok("éteint : blagues et histoire des lieux reviennent", NS:CompanionIdlePool() == "JOKE" and NS.LoreOn(NS) ~= nil)
	Award("char_kills_10000")
	s.ok("éteint : le grand bandeau, la fanfare et la bulle reviennent", Shown(NS.journalToast) and F.sounds[1] == NS.FEAT_SOUND
		and Said("UNLOCK"))
	Clear()
	NS:DB().quiet = true
	s.ok("les réglages de détail ne changent pas", NS:DB().companionJokes ~= false and NS:DB().announceGroup == true
		and NS:DB().companionDiscovery ~= false and NS:DB().companionLore ~= false)
	NS.COMPANION_JOKE_SHARE = share
	-- la page Discrétion : la section et la ligne en tête, le détail dessous
	local page
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionQuiet" then page = p end end
	local rows = page and page.rows or {}
	s.ok("page Discrétion : « Un seul réglage… », « Mode discret », puis « Le détail… » et les réglages d'avant",
		rows[1] and rows[1].header == "OPT_QUIET_SECTION_ALL" and rows[2] and rows[2].key == "quiet"
		and rows[3] and rows[3].header == "OPT_QUIET_SECTION_DETAIL" and rows[4] and rows[4].key == "companionCombatFade")
	s.check("[DISCRET] coupe astuces, objectifs, blagues, lieux, annonces ; hauts faits en pastille ; laisse passer capture, brillante, sceau ; guilde au plus toutes les 10 min ; éteint : comme avant")
	Done()
end

-- 5. Annonce de groupe : une brillante seulement --------------------------------------------------
do
	Say("-- fêtes : annonce de groupe")
	Fresh("azeroth")
	local s = Steps()
	F.party = true
	local savedSize = NS.SpecimenRollSize
	NS.SpecimenRollSize = function() return "large" end
	NS.captureStage = nil
	NS:CaptureResolve({ success = true, stars = 3, target = { npcID = 7801, name = "Loup", class = "normal", zoneID = 1413 } })
	s.ok("3 étoiles : plus d'annonce automatique", #F.sends == 0)
	NS:CaptureResolve({ success = true, stars = 1, target = { npcID = 7802, name = "Raptor", class = "normal", shiny = true, zoneID = 1413 } })
	s.ok("brillante : une ligne au groupe", #F.sends == 1 and F.sends[1].channel == "PARTY")
	NS.SpecimenRollSize = savedSize
	s.ok("réglage : même clé, même défaut", NS:DB().announceGroup == true)
	s.ok("aide : brillante seulement", NS.SHARE_STRINGS.fr.OPT_ANNOUNCE_GROUP_DESC:find("plus pour un 3 étoiles", 1, true) ~= nil
		and NS.SHARE_STRINGS.en.OPT_ANNOUNCE_GROUP_DESC:find("no longer for a 3-star", 1, true) ~= nil)
	s.check("[ANN37] annonce automatique au groupe : une brillante seulement ; réglage inchangé, aide à jour")
	Done()
end

-- 6. Indice d'un secret ---------------------------------------------------------------------------
do
	Say("-- fêtes : indice d'un secret")
	Fresh("azeroth")
	local s = Steps()
	NS.RegisterStrings({ FEAT_test_fete_h = "Secret", FEATH_test_fete_h = "Il paraît que Lardeur aime les promenades…" },
		{ FEAT_test_fete_h = "Secret", FEATH_test_fete_h = "Rumour has it Lardeur loves walks…" })
	-- (les dix secrets du catalogue sont mis de côté le temps du test : l'indice tiré est celui de la ligne d'essai)
	local realSecrets = {}
	for _, other in ipairs(NS:FeatDefs()) do
		if other.hidden then realSecrets[#realSecrets + 1] = other; other.hidden = nil end
	end
	local def = NS.FeatAdd({ "test_fete_h", 990, "jeu", 5, "account", crit = { "flag", "fete_h" }, hidden = true })
	local function Pick() local tip = NS:DiscoveryPick(); return tip and tip.hint and tip or nil end
	NS:DB().companionDiscovery = false
	s.ok("hors repos : rien", Pick() == nil)
	F.resting = true
	NS:DB().quiet = true
	s.ok("au repos, mode discret : rien", Pick() == nil)
	NS:DB().quiet = false
	local tip = Pick()
	s.ok("au repos : l'indice, dans le créneau des astuces", tip and tip.line == "FEATH_test_fete_h"
		and NS:F(tip.line) == "Il paraît que Lardeur aime les promenades…")
	NS:DiscoveryShown(tip)
	s.ok("une fois dite : notée au compte, pas comme une astuce vue", tonumber(NS:DB().quietHintAt) ~= nil
		and NS:DiscoveryData().seen[NS.QUIET_HINT_ID] == nil)
	NS:FeatHintKnown("test_fete_h")
	s.ok("la même semaine : rien de plus", Pick() == nil)
	NS:DB().quietHintAt = (time() or 0) - NS.QUIET_HINT_GAP - 1
	s.ok("plus aucun secret à révéler : rien", Pick() == nil)
	-- par le vrai créneau (CompanionTryTip), une seule bulle, celle de l'astuce
	NS:FeatStore("account").hints = {}
	NS:DB().quietHintAt = nil
	F.says = {}
	NS:CompanionTryTip(true)
	local tipSaid
	for _, said in ipairs(F.says) do if said.pool == "TIP" then tipSaid = said end end
	s.ok("dans le créneau des astuces : une bulle TIP, pas une de plus", tipSaid and tipSaid.opts.line == "FEATH_test_fete_h"
		and #F.says == 1, #F.says)
	for index = #NS.FEAT_DEFS, 1, -1 do if NS.FEAT_DEFS[index] == def then table.remove(NS.FEAT_DEFS, index) end end
	for _, other in ipairs(realSecrets) do other.hidden = true end
	NS.featIndexDirty = true
	NS:DB().companionDiscovery = true
	s.check("[INDICE] au repos, une fois par semaine au compte, hors mode discret, dans le créneau des astuces ; rien sans secret")
	Done()
end

-- 7. Contrastes des textes nouveaux ---------------------------------------------------------------
do
	Say("-- fêtes : contrastes")
	local s = Steps()
	local X, XF = NS.CAPTURE_EXPRESS, NS.CAPTURE_EXPRESS_FORGE
	local function Over(c, alpha) return Theme.Over(Theme.WHITE, c, alpha) end
	local P, FG = Theme.FORGE_PLATE, Theme.FORGE
	-- pastille : plaque d'encre (Sobre) ou carte forgée (claire, sombre), à 0,94 sur la neige
	local plates = { Over(Theme.INK, X.plate), Over(Theme.ForgeSurface(XF.card or P.card, FG.label.light), X.plate),
		Over(Theme.ForgeSurface(XF.card or P.card, FG.label.dark), X.plate) }
	local worst = math.huge
	for _, plate in ipairs(plates) do
		for _, ink in ipairs({ Theme.PARCHMENT, Theme.GOLD_LIGHT }) do worst = math.min(worst, Theme.Contrast(ink, plate)) end
	end
	s.ok("pastille : nom et points ≥ 4,5:1", worst >= 4.5, string.format("%.2f", worst))
	F.worstPill = worst
	-- bandeau : fond WINDOW à 0,94 sur un monde blanc (pire cas)
	local bg = Theme.Over(Theme.WHITE, Theme.WINDOW, 0.94)
	local sig = Theme.Contrast(Theme.MUTED_LIGHT, bg)
	local odds = Theme.Contrast(Theme.PARCHMENT, bg)
	local reward = Theme.Contrast(Theme.GOLD_LIGHT, bg)
	s.ok("signature ≥ 4,5:1", sig >= 4.5, string.format("%.2f", sig))
	s.ok("cote ≥ 4,5:1", odds >= 4.5, string.format("%.2f", odds))
	s.ok("ligne de récompense ≥ 4,5:1", reward >= 4.5, string.format("%.2f", reward))
	-- réglages : titres de section et description du mode discret, sur la carte
	local section = Theme.Contrast(Theme.IDENTITY_LIGHT, Theme.SURFACE)
	local desc = Theme.Contrast(Theme.MUTED_LIGHT, Theme.ROW)
	s.ok("réglages : titre de section ≥ 3:1, description ≥ 4,5:1", section >= 3 and desc >= 4.5,
		string.format("%.2f / %.2f", section, desc))
	Say(string.format("   contrastes : pastille %.2f, signature %.2f, cote %.2f, récompense %.2f, section %.2f, description %.2f",
		worst, sig, odds, reward, section, desc))
	s.check("[FETE] contrastes : pastille, signature, cote, ligne de récompense, réglages")
end
