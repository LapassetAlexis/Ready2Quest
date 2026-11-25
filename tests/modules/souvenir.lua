-- QuestCompanion 3.7.0, étape 3 « Ça se montre » : carte souvenir et « Copier
-- pour Discord » (Souvenir.lua, DiscordCopy.lua). Chaque texte composé
-- (contenu, longueur, aucun accord de genre, cote présente ou absente,
-- adresse en dernière ligne, trois langues, échappement), la fenêtre de
-- copie, la carte pour chaque sujet, le bouton de capture avec et sans
-- Screenshot (et quand il échoue), la fermeture en combat et à Échap, le
-- compteur du haut fait « Souriez ! », les boutons apparus, aucun envoi dans
-- le chat, les contrastes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme
local L = NS.L

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local GLOBALS = { "UnitName", "UnitLevel", "InCombatLockdown", "UnitAffectingCombat", "PlaySound", "Screenshot", "date",
	"SendChatMessage", "ChatFrame_OpenChat", "ChatEdit_InsertLink", "ChatEdit_GetActiveWindow", "GetStatistic", "IsShiftKeyDown" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local savedShiny, savedDormant, savedStats = NS.SHINY_CHANCE, NS.featsDormant, rawget(NS, "FeatStatsBlocks")
local FIELDS = { "captureToast", "journalToast", "guildFeatToast", "captureResult", "featPill" }
local URL = "https://www.curseforge.com/wow/addons/quest-companion"

local F = { shots = 0, sends = 0, combat = false }

local function Fresh()
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	if NS.souvenirFrame then NS.souvenirFrame:Hide() end
	if NS.discordCopy then NS.discordCopy:Hide() end
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.uiStyleCache, NS.errors = {}, {}
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.featPills, NS.featPillHideAt = {}, nil
	NS.captureResultHideAt, NS.captureResultPending = nil, nil
	if NS.bannerLane then NS.bannerLane.showing, NS.bannerLane.frame, NS.bannerLane.waiting = nil, nil, {} end
	F.shots, F.sends, F.combat = 0, 0, false
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return F.combat end
	_G.UnitAffectingCombat = function() return F.combat end
	_G.PlaySound = function() return true end
	_G.GetStatistic = function() return nil end
	_G.IsShiftKeyDown = function() return false end
	_G.date = os.date
	_G.Screenshot = function() F.shots = F.shots + 1 end
	-- tout ce qui pourrait écrire dans le chat : compté
	_G.SendChatMessage = function() F.sends = F.sends + 1 end
	_G.ChatFrame_OpenChat = function() F.sends = F.sends + 1 end
	_G.ChatEdit_InsertLink = function() F.sends = F.sends + 1; return true end
	_G.ChatEdit_GetActiveWindow = function() return nil end
	NS.SHINY_CHANCE = 1 / 150
	NS.FeatStatsBlocks = nil
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS:CompanionData().tutoDone = true
	NS:DB().winterVeil = "off"
	NS:DB().featsFilter = "all"
	Mock:Reset()
end

local function Done()
	if NS.souvenirFrame then NS.souvenirFrame:Hide() end
	if NS.discordCopy then NS.discordCopy:Hide() end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	if NS.journalFrame then NS.journalFrame:Hide() end
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	NS.SHINY_CHANCE, NS.featsDormant, NS.FeatStatsBlocks = savedShiny, savedDormant, savedStats
	ResetWorld()
end

local function Shown(frame) return frame ~= nil and frame.IsShown and frame:IsShown() and true or false end
local function Lines(text)
	local out = {}
	for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = line end
	return out
end
local function Has(text, piece) return type(text) == "string" and text:find(piece, 1, true) ~= nil end
-- un accord au masculin ou au féminin de l'espèce (« capturé », « brillant, »)
local function Agrees(text)
	return Has(text, "capturé") or Has(text, "capturée") or text:find("brillant[^e]") ~= nil or text:find("brillant$") ~= nil
end

-- le raptor de la maquette : brillant, 3 étoiles, Géant, Curieux (1 chance sur 107 143)
local function Raptor(extra)
	local spec = { npc = 3398, stars = 3, name = "Raptor de Strangleronce", origin = "capture", zone = 1413, by = "Testeur",
		size = "giant", shiny = true, trait = "curious", at = os.time({ year = 2026, month = 11, day = 22, hour = 12 }) }
	for k, v in pairs(extra or {}) do spec[k] = v end
	return NS:SpecimenAdd(spec)
end
local function Plain1()
	return NS:SpecimenAdd({ npc = 3236, stars = 1, name = "Kodo des Tarides", origin = "capture", zone = 1413, by = "Testeur",
		size = "normal", trait = "lazy", at = os.time({ year = 2026, month = 11, day = 20, hour = 12 }) })
end

-- 1. Les textes ----------------------------------------------------------------------------------
do
	Say("-- souvenir : les textes pour Discord")
	Fresh()
	local s = Steps()
	local id = Raptor()
	local text = NS:DiscordText("capture", { kind = "capture", result = { specimen = id, shiny = true, level = 38 } })
	local lines = Lines(text)
	s.ok("prise : cinq lignes", #lines == 5, #lines)
	s.ok("prise : « **Raptor de Strangleronce** · brillante · 3 étoiles · Géant (1 chance sur 107 143) »",
		lines[1] == "**Raptor de Strangleronce** · brillante · 3 étoiles · Géant (1 chance sur 107 143)", lines[1])
	s.ok("prise : « Prise de Testeur » et le lieu", lines[2] and lines[2]:find("^Prise de Testeur") ~= nil, lines[2])
	s.ok("prise : espèces · brillantes · points de hauts faits", lines[3] and Has(lines[3], "espèce") and Has(lines[3], "brillante")
		and Has(lines[3], "points de hauts faits"), lines[3])
	s.ok("prise : signature puis l'adresse CurseForge en dernière ligne", lines[4] == "Quest Companion, addon WoW Forever" and lines[5] == URL)
	s.ok("prise : aucun accord de genre", not Agrees(text), text)
	-- la cote seulement quand elle existe
	local plain = NS:DiscordText("capture", (Plain1()))
	s.ok("prise ordinaire : pas de cote, pas de « brillante », pas de taille Normal", plain and not Has(plain, "1 chance sur")
		and not Has(plain, "brillante ·") and not Has(plain, "Normal") and Lines(plain)[1] == "**Kodo des Tarides** · 1 étoile", plain)
	-- surnom : en tête, échappé (gras, mentions)
	local nick = NS:SpecimenGet(Raptor({ shiny = false }))
	nick.nick = "*Croc_@everyone"
	local nickText = NS:DiscordText("specimen", { kind = "specimen", id = nick.id })
	s.ok("surnom : en tête et échappé, l'espèce ensuite", Lines(nickText)[1]:find("^%*%*\\%*Croc\\_\\@everyone%*%* · Raptor de Strangleronce · 3 étoiles · Géant") ~= nil,
		Lines(nickText)[1])
	-- trois langues : la langue du joueur (ici demandée)
	local en = NS:DiscordText("capture", id, "en")
	local es = NS:DiscordText("capture", id, "es")
	s.ok("anglais : « **Raptor de Strangleronce** · shiny · 3 stars · Giant (1 in 107,143) »",
		Lines(en)[1] == "**Raptor de Strangleronce** · shiny · 3 stars · Giant (1 in 107,143)" and Lines(en)[2]:find("^Caught by Testeur") ~= nil
		and Lines(en)[4] == "Quest Companion, a WoW Forever addon" and Lines(en)[5] == URL, en)
	s.ok("espagnol : texte espagnol, nombre à la mode espagnole, adresse en dernière ligne", es and es ~= en and Has(Lines(es)[1], "107.143")
		and Lines(es)[#Lines(es)] == URL and Lines(es)[4] ~= Lines(en)[4], es)
	-- fiche de dresseur
	local card = NS:DiscordText("trainer")
	local cl = Lines(card)
	s.ok("fiche : nom en gras, points, espèces · brillantes · sceaux · hauts faits, signature", #cl == 5 and cl[1] == "**Testeur**"
		and Has(cl[2], "points") and Has(cl[3], "sceau") and Has(cl[3], "haut") and cl[5] == URL, card)
	-- haut fait obtenu ; pas obtenu, secret, en attente : rien
	NS:FeatAward("char_level_30", { silent = true, at = os.time({ year = 2026, month = 11, day = 21, hour = 12 }) })
	local feat = NS:DiscordText("feat", "char_level_30")
	local fl = Lines(feat)
	local def = NS:FeatDef("char_level_30")
	s.ok("haut fait : nom en gras, condition, points et date, signature", fl[1] == "**" .. NS:FeatName(def) .. "**"
		and fl[2] == NS:FeatDescription(def) and fl[3] == "10 points · obtenu le 21/11/2026" and fl[#fl] == URL, feat)
	s.ok("haut fait : par la ligne dépliée ou le bandeau, même texte", NS:DiscordText("feat", { kind = "feat", id = "char_level_30" }) == feat
		and NS:DiscordText("feat", { kind = "feat", entry = { id = "char_level_30" } }) == feat)
	s.ok("haut fait pas obtenu : aucun texte", NS:DiscordText("feat", "char_level_60") == nil)
	s.ok("secret non découvert : aucun texte", NS:FeatDef("fun_wake").hidden and NS:DiscordText("feat", "fun_wake") == nil)
	-- (une ligne encore en attente : n'importe laquelle du catalogue, s'il en reste)
	local waiting
	for _, def in ipairs(NS:FeatDefs()) do if def.pending then waiting = def; break end end
	s.ok("ligne en attente : aucun texte", waiting ~= nil and NS:DiscordText("feat", waiting.id) == nil, waiting and waiting.id)
	-- statistiques : seulement si l'onglet les donne
	s.ok("statistiques : rien sans ns:FeatStatsBlocks", NS:DiscordText("stats") == nil)
	NS.FeatStatsBlocks = function()
		local blocks = {}
		for b = 1, 6 do
			local rows = {}
			for r = 1, 4 do rows[r] = { key = "r" .. r, label = "Ligne " .. r, value = r == 4 and "—" or tostring(b * 100 + r), fresh = r == 1 } end
			blocks[b] = { key = "b" .. b, title = "Bloc " .. b, rows = rows }
		end
		return blocks
	end
	local stats = NS:DiscordText("stats")
	local sl = Lines(stats)
	s.ok("statistiques : titre en gras, une ligne par bloc (inconnues omises), signature", #sl == 9 and sl[1] == "**Statistiques de Testeur**"
		and sl[2] == "Bloc 1 — Ligne 1 : 101 · Ligne 2 : 102 · Ligne 3 : 103" and not Has(stats, "—Ligne 4") and not Has(stats, "Ligne 4")
		and sl[9] == URL, stats)
	-- trop long : le corps raccourcit, la signature reste
	NS.FeatStatsBlocks = function()
		local blocks = {}
		for b = 1, 6 do
			local rows = {}
			for r = 1, 40 do rows[r] = { key = "r" .. r, label = "Une très longue étiquette " .. r, value = "123 456 789" } end
			blocks[b] = { key = "b" .. b, title = "Bloc " .. b, rows = rows }
		end
		return blocks
	end
	local long = NS:DiscordText("stats")
	s.ok("statistiques trop longues : sous 1 900, adresse en dernière ligne", long and #long < 1900 and Lines(long)[#Lines(long)] == URL, long and #long)
	-- tous : sous 1 900 caractères, adresse en dernière ligne
	local all = { text, plain, nickText, en, es, card, feat, stats, long }
	local bad = {}
	for index, t in ipairs(all) do
		if not (type(t) == "string" and #t < 1900 and Lines(t)[#Lines(t)] == URL) then bad[#bad + 1] = tostring(index) end
	end
	s.ok("chaque texte : moins de 1 900 caractères, l'adresse en dernière ligne", #bad == 0, table.concat(bad, ","))
	s.ok("aucun envoi dans le chat", F.sends == 0, F.sends)
	s.check("[SOUV] textes : prise (cote si elle existe, sans accord, trois langues, surnom échappé), fiche, statistiques (si l'onglet existe, raccourcies), haut fait obtenu seulement ; < 1 900, adresse en dernier")
	Done()
end

-- 2. La fenêtre de copie -------------------------------------------------------------------------
do
	Say("-- souvenir : la fenêtre de copie")
	Fresh()
	local s = Steps()
	local frame = NS.DiscordCopyShow("**Bonjour**\nligne 2", "Mon titre")
	s.ok("ouverte, titre, texte posé et mis au premier plan", Shown(frame) and frame.title:GetText() == "Mon titre"
		and frame.edit:GetText() == "**Bonjour**\nligne 2" and frame.edit:HasFocus())
	s.ok("plusieurs lignes, consigne, « Fermer »", frame.edit.multiLine ~= false and frame.hint:GetText() == L.DISCORD_COPY_HINT
		and frame.closeButton.text:GetText() == L.DISCORD_COPY_CLOSE)
	-- verrouillée : une frappe remet le texte (brique du socle)
	frame.edit:SetText("abîmé")
	frame.edit:GetScript("OnTextChanged")(frame.edit, true)
	s.ok("verrouillée : une frappe remet le texte", frame.edit:GetText() == "**Bonjour**\nligne 2" and frame.edit.copyURL == "**Bonjour**\nligne 2")
	local named = false
	for _, name in ipairs(UISpecialFrames) do if name == frame:GetName() then named = true end end
	s.ok("Échap ferme (fenêtre nommée, UISpecialFrames)", named and frame:GetName() == "QuestCompanionDiscordCopy")
	frame.edit:GetScript("OnEscapePressed")(frame.edit)
	s.ok("Échap dans la zone ferme aussi", not Shown(frame))
	-- par deux-points, titre par défaut
	frame = NS:DiscordCopyShow("x")
	s.ok("appel par deux-points, titre par défaut", Shown(frame) and frame.title:GetText() == L.DISCORD_COPY_TITLE and frame.edit:GetText() == "x")
	frame.closeButton:Click()
	s.ok("« Fermer » ferme", not Shown(frame))
	-- combat : fermée, et jamais ouverte
	NS.DiscordCopyShow("y")
	Mock:Fire("PLAYER_REGEN_DISABLED")
	s.ok("le combat la ferme", not Shown(frame))
	F.combat = true
	s.ok("en combat : pas d'ouverture", NS.DiscordCopyShow("z") == nil and not Shown(frame))
	F.combat = false
	s.ok("texte vide : rien", NS.DiscordCopyShow("") == nil and NS.DiscordCopyShow(nil) == nil)
	s.ok("aucun envoi dans le chat", F.sends == 0, F.sends)
	s.check("[SOUV] copie : zone sur plusieurs lignes verrouillée et sélectionnée, consigne, Fermer, Échap, combat")
	Done()
end

-- 3. La carte, pour chaque sujet -----------------------------------------------------------------
do
	Say("-- souvenir : la carte")
	Fresh()
	local s = Steps()
	local id = Raptor()
	s.ok("jamais ouverte seule : rien à l'ouverture d'une prise", NS.souvenirFrame == nil or not Shown(NS.souvenirFrame))
	local veil = NS:SouvenirShow({ kind = "capture", result = { specimen = id, shiny = true, level = 38 } })
	local card = veil and veil.card
	s.ok("prise : voile sur tout l'écran, carte au-dessus", Shown(veil) and veil.allPoints == UIParent and veil.strata == "FULLSCREEN"
		and card and card:GetParent() == veil and Shown(UIParent ~= nil and veil))
	s.ok("prise : petit titre, nom, espèce et niveau", card.kicker:GetText() == L.SOUVENIR_KICK_SHINY
		and card.name:GetText() == "Raptor de Strangleronce" and card.sub:GetText() == "niveau 38", card.sub:GetText())
	local labels, values = {}, {}
	for index, row in ipairs(card.rows) do
		if Shown(row.label) then labels[#labels + 1] = row.label:GetText(); values[#values + 1] = row.value:GetText() end
	end
	s.ok("prise : qualité, taille, caractère, lien, capture", table.concat(labels, "|") == "Qualité|Taille|Caractère|Lien|Capture",
		table.concat(labels, "|"))
	local starRow = card.rows[1]
	local textures = 0
	for _, tex in ipairs(starRow.stars) do if Shown(tex) and (tex.atlas or tex.texture) then textures = textures + 1 end end
	s.ok("prise : trois étoiles en textures du client, jamais en glyphe", textures == 3 and values[1] == "3 étoiles"
		and not values[1]:find("★", 1, true) and not Shown(card.rows[2].stars[1]))
	s.ok("prise : taille et indice", values[2] and values[2]:find("^Géant %(indice %d+%)$") ~= nil, values[2])
	s.ok("prise : lieu et date", values[5] and Has(values[5], "22/11/2026"), values[5])
	s.ok("prise : la cote", Shown(card.odds) and card.odds.text:GetText() == "1 chance sur 107 143")
	s.ok("prise : le modèle 3D de la créature (ou son portrait)", card.panel.modelShown or Shown(card.panel.portrait))
	s.ok("pied : dresseur, « rang · points · espèces », signature", card.who:GetText() == "Testeur" and Has(card.foot:GetText(), "points")
		and Has(card.foot:GetText(), "espèce") and card.sigHolder.qcSignature and Shown(card.sigHolder.qcSignature)
		and card.sigHolder.qcSignature.text:GetText() == "QUEST COMPANION")
	s.ok("sous la carte : Capture d'écran, Copier pour Discord, Fermer", Shown(veil.bar.shot) and Shown(veil.bar.copy) and Shown(veil.bar.close)
		and veil.bar.shot.text:GetText() == L.SOUVENIR_SHOT and veil.bar.copy.text:GetText() == L.SOUVENIR_COPY)
	-- Copier pour Discord : le texte du sujet
	veil.bar.copy:Click()
	s.ok("Copier pour Discord : la fenêtre de copie, avec le texte de la prise", Shown(NS.discordCopy)
		and NS.discordCopy.edit:GetText() == NS:DiscordText("capture", { kind = "capture", result = { specimen = id, shiny = true, level = 38 } }))
	veil.bar.close:Click()
	s.ok("Fermer : la carte et la fenêtre de copie se ferment", not Shown(veil) and not Shown(NS.discordCopy))
	-- sans cote : pas d'étiquette
	veil = NS:SouvenirShow({ kind = "specimen", id = (Plain1()) })
	s.ok("spécimen ordinaire : pas de cote, « SPÉCIMEN »", Shown(veil) and not Shown(veil.card.odds) and veil.card.kicker:GetText() == L.SOUVENIR_KICK_SPEC)
	-- haut fait obtenu
	NS:FeatAward("char_level_30", { silent = true, at = os.time({ year = 2026, month = 11, day = 21, hour = 12 }) })
	veil = NS:SouvenirShow({ kind = "feat", id = "char_level_30" })
	card = veil and veil.card
	s.ok("haut fait : icône, nom, condition, points, date", card and card.kicker:GetText() == L.SOUVENIR_KICK_FEAT
		and card.name:GetText() == NS:FeatName("char_level_30") and card.sub:GetText() == NS:FeatDescription("char_level_30")
		and Shown(card.panel.portrait) and card.panel.portrait.texture == NS:FeatIcon(NS:FeatDef("char_level_30"))
		and card.rows[1].value:GetText() == "10" and not Shown(card.odds))
	veil:Hide()
	s.ok("haut fait pas obtenu, secret non découvert : pas de carte", NS:SouvenirShow({ kind = "feat", id = "char_level_60" }) == nil
		and NS:SouvenirShow({ kind = "feat", id = "fun_wake" }) == nil and not Shown(NS.souvenirFrame))
	-- fiche de dresseur (sans sujet, ou { kind = "trainer" })
	veil = NS:SouvenirShow()
	card = veil and veil.card
	s.ok("fiche : rang, espèces, brillantes, sceaux, hauts faits", card and card.kicker:GetText() == L.SOUVENIR_KICK_CARD
		and card.name:GetText() == "Testeur" and (card.rows[1].label:GetText() == L.SOUVENIR_L_RANK or card.rows[1].label:GetText() == L.SOUVENIR_L_POINTS)
		and card.rows[5].label:GetText() == L.SOUVENIR_L_FEATS)
	veil:Hide()
	s.ok("fiche : aussi par { kind = \"trainer\" } et par point", NS.SouvenirShow({ kind = "trainer" }) == NS.souvenirFrame)
	NS:SouvenirHide()
	-- Échap : le voile est nommé
	local named = false
	for _, name in ipairs(UISpecialFrames) do if name == "QuestCompanionSouvenir" then named = true end end
	s.ok("Échap ferme (voile nommé, UISpecialFrames)", named and NS.souvenirFrame:GetName() == "QuestCompanionSouvenir")
	s.ok("l'interface n'est jamais cachée (seul le voile la couvre)", UIParent.mockHidden ~= true)
	s.ok("sujet inconnu : rien", NS:SouvenirShow({ kind = "autre" }) == nil and NS:SouvenirShow({ kind = "specimen", id = 99999 }) == nil)
	s.ok("aucun envoi dans le chat", F.sends == 0, F.sends)
	s.check("[SOUV] carte : prise (modèle, étoiles en textures, taille et indice, caractère, lien, lieu et date, cote), spécimen, haut fait obtenu, fiche ; pied signé ; jamais seule")
	Done()
end

-- 4. Capture d'écran -----------------------------------------------------------------------------
do
	Say("-- souvenir : capture d'écran")
	Fresh()
	local s = Steps()
	local veil = NS:SouvenirShow({ kind = "specimen", id = Raptor() })
	s.ok("avec Screenshot : le bouton, pas de phrase", Shown(veil.bar.shot) and not Shown(veil.hint))
	veil.bar.shot:Click()
	s.ok("clic : les trois boutons s'effacent", not Shown(veil.bar) and F.shots == 0)
	Mock:Advance(0.3)
	s.ok("… la photo ne part pas tout de suite", F.shots == 0 and not Shown(veil.bar))
	Mock:Advance(0.3)
	s.ok("une demi-seconde plus tard : la photo, puis les boutons et la phrase du dossier", F.shots == 1 and Shown(veil.bar)
		and Shown(veil.hint) and veil.hint:GetText() == L.SOUVENIR_SHOT_DONE)
	-- Screenshot échoue : les boutons reviennent quand même
	_G.Screenshot = function() error("bloqué") end
	veil.bar.shot:Click()
	Mock:Advance(0.6)
	s.ok("Screenshot échoue : les boutons reviennent, une phrase le dit", Shown(veil.bar) and veil.hint:GetText() == L.SOUVENIR_SHOT_FAIL)
	-- fermée pendant l'attente : rien ne part, les boutons reviennent pour la prochaine fois
	_G.Screenshot = function() F.shots = F.shots + 1 end
	veil.bar.shot:Click()
	veil:Hide()
	Mock:Advance(0.6)
	s.ok("fermée pendant l'attente : pas de photo, boutons rendus", F.shots == 1 and Shown(veil.bar))
	-- sans Screenshot : pas de bouton, une phrase invite à la touche du jeu
	_G.Screenshot = nil
	veil = NS:SouvenirShow({ kind = "specimen", id = (Plain1()) })
	s.ok("sans Screenshot : pas de bouton, la phrase de la touche de capture", not Shown(veil.bar.shot) and Shown(veil.bar.copy)
		and Shown(veil.hint) and veil.hint:GetText() == L.SOUVENIR_SHOT_NONE and NS:SouvenirShoot() == false)
	s.ok("sans Screenshot : les deux boutons restent centrés", veil.bar:GetWidth() == veil.bar.copy:GetWidth() + veil.bar.close:GetWidth() + NS.SOUVENIR.buttonGap)
	s.ok("aucun envoi dans le chat", F.sends == 0, F.sends)
	s.check("[SOUV] capture d'écran : boutons effacés, photo une demi-seconde après, retour avec la phrase (même en échec ou fermée) ; sans Screenshot, pas de bouton et une phrase")
	Done()
end

-- 5. Combat et compteur --------------------------------------------------------------------------
do
	Say("-- souvenir : combat, compteur")
	Fresh()
	local s = Steps()
	local id = Raptor()
	s.ok("compteur à zéro avant", NS:TallyGet("souvenir") == 0)
	local veil = NS:SouvenirShow({ kind = "specimen", id = id })
	s.ok("première carte : le compteur « souvenir »", NS:TallyGet("souvenir") == 1)
	NS.DiscordCopyShow("texte")
	Mock:Fire("PLAYER_REGEN_DISABLED")
	s.ok("le combat ferme la carte et la fenêtre de copie", not Shown(veil) and not Shown(NS.discordCopy))
	F.combat = true
	s.ok("en combat : pas de carte", NS:SouvenirShow({ kind = "specimen", id = id }) == nil and not Shown(veil))
	F.combat = false
	NS:SouvenirShow({ kind = "specimen", id = id })
	s.ok("cartes suivantes : le compteur ne bouge plus", NS:TallyGet("souvenir") == 1)
	local def = NS:FeatDef("soc_photo_1")
	local cur, max, state = NS:FeatProgress(def)
	s.ok("« Souriez ! » n'est plus en attente et se remplit", def and not def.pending and NS:FeatCountable(def) and cur == 1 and max == 1
		and state ~= "pending", tostring(cur) .. "/" .. tostring(max) .. " " .. tostring(state))
	s.check("[SOUV] combat : carte et copie fermées, jamais ouvertes ; première carte : compteur souvenir, « Souriez ! » comptable")
	Done()
end

-- 6. Les boutons apparus -------------------------------------------------------------------------
do
	Say("-- souvenir : les boutons « Carte souvenir »")
	Fresh()
	local s = Steps()
	NS:DB().companionStyle = "azeroth"
	NS:ApplyUIStyle()
	-- grand bandeau de haut fait
	NS:FeatAward("char_kills_10000")
	NS:FeatFlush(true)
	local toast = NS.journalToast
	local sv = toast and toast.souvenirButton
	s.ok("grand bandeau : « Carte souvenir »", Shown(sv))
	if sv then sv:GetScript("OnClick")(sv) end
	s.ok("… son clic ouvre la carte du haut fait", Shown(NS.souvenirFrame) and NS.souvenirFrame.view.kind == "feat"
		and NS.souvenirFrame.view.name == NS:FeatName("char_kills_10000"))
	NS:SouvenirHide()
	-- bandeau d'une prise rare
	local id = Raptor()
	local frame = NS:CaptureResultShow({ name = "Raptor de Strangleronce", shiny = true, stars = 3, npcID = 3398, level = 38,
		type = "Beast", class = "normal", specimen = id })
	sv = frame and frame.souvenirButton
	s.ok("prise rare : « Carte souvenir »", Shown(sv))
	if sv then sv:GetScript("OnClick")(sv) end
	s.ok("… son clic ouvre la carte de la prise", Shown(NS.souvenirFrame) and NS.souvenirFrame.view.kind == "specimen"
		and NS.souvenirFrame.card.odds.text:GetText() == "1 chance sur 107 143")
	NS:SouvenirHide()
	if NS.CaptureResultHide then NS:CaptureResultHide() end
	-- ligne dépliée d'un haut fait obtenu
	NS:FeatAward("char_hearth_50", { silent = true })
	NS:OpenJournalFeatsAt("char_hearth_50")
	local f = NS.journalFrame
	local open
	for _, row in ipairs(f and f.feats and f.feats.list and f.feats.list.rows or {}) do
		if row:IsShown() and row.item and row.selected then open = row end
	end
	s.ok("ligne dépliée : « Carte souvenir »", open and Shown(open.souvenir))
	if open then open.souvenir:Click() end
	s.ok("… son clic ouvre la carte du haut fait", Shown(NS.souvenirFrame) and NS.souvenirFrame.view.name == NS:FeatName("char_hearth_50"))
	NS:SouvenirHide()
	if f then f:Hide() end
	-- fiche d'un spécimen de la Réserve
	NS.journalFrame = nil
	Plain1()
	local pick = Plain1()   -- le second va en Réserve
	NS:ToggleJournal(true)
	NS:SelectJournalKind("reserve")
	NS:ReservePick(pick)
	local rv = NS.journalFrame and NS.journalFrame.res and NS.journalFrame.res.reserve
	s.ok("fiche d'un spécimen : l'icône « Carte souvenir »", rv and Shown(rv.souvenir) and rv.souvenir.tipTitle == L.SOUVENIR_BUTTON)
	if rv and rv.souvenir then rv.souvenir:Click() end
	s.ok("… son clic ouvre la carte du spécimen", Shown(NS.souvenirFrame) and NS.souvenirFrame.view.kind == "specimen"
		and NS.souvenirFrame.view.name == "Kodo des Tarides")
	NS:SouvenirHide()
	s.ok("aucun envoi dans le chat", F.sends == 0, F.sends)
	s.check("[SOUV] boutons : grand bandeau, prise rare, ligne dépliée d'un haut fait obtenu, fiche d'un spécimen ; chacun ouvre sa carte")
	Done()
end

-- 7. Rien ne part dans le chat -------------------------------------------------------------------
do
	Say("-- souvenir : rien dans le chat")
	Fresh()
	local s = Steps()
	local veil = NS:SouvenirShow({ kind = "specimen", id = Raptor() })
	veil.bar.copy:Click()
	veil.bar.shot:Click()
	Mock:Advance(0.6)
	NS:SouvenirShow()
	veil.bar.copy:Click()
	local out = Mock:Output()
	s.ok("aucune fonction du chat appelée", F.sends == 0, F.sends)
	s.ok("aucun texte composé dans la fenêtre de chat", not Has(out, URL) and not Has(out, "**"), out)
	s.check("[SOUV] rien ne sort du jeu : ni envoi, ni zone de saisie du chat, ni ligne de chat avec le texte")
	Done()
end

-- 8. Contrastes et textes ------------------------------------------------------------------------
do
	Say("-- souvenir : contrastes, textes")
	Fresh()
	local s = Steps()
	local veil = NS:SouvenirShow({ kind = "capture", result = { specimen = Raptor(), shiny = true, level = 38 } })
	local card = veil.card
	local copy = NS.DiscordCopyShow("a", "b")
	local function Ink(region)
		local c = region.textColor or {}
		return { c[1] or 1, c[2] or 1, c[3] or 1 }
	end
	local window = Theme.WINDOW
	-- pire voile : le jeu blanc derrière le voile
	local worstVeil = Theme.Over(Theme.WHITE, Theme.INK, Theme.SHADE.strong)
	local oddsGround = Theme.Over(window, Theme.GOLD, Theme.SHADE.soft / 2)
	local rows = {
		{ "petit titre", card.kicker, window, 4.5 },
		{ "nom (titre)", card.name, window, 3 },
		{ "espèce et niveau", card.sub, window, 4.5 },
		{ "étiquette", card.rows[1].label, window, 4.5 },
		{ "valeur", card.rows[1].value, window, 4.5 },
		{ "cote", card.odds.text, oddsGround, 4.5 },
		{ "dresseur", card.who, window, 4.5 },
		{ "rang et chiffres", card.foot, window, 4.5 },
		{ "signature", card.sigHolder.qcSignature.text, window, 4.5 },
		{ "phrase sous la carte", veil.hint, worstVeil, 4.5 },
		{ "copie : titre", copy.title, window, 3 },
		{ "copie : texte", copy.edit, Theme.FIELD, 4.5 },
		{ "copie : consigne", copy.hint, window, 4.5 },
	}
	local measured, weakest = {}, math.huge
	for _, row in ipairs(rows) do
		local ratio = Theme.Contrast(Ink(row[2]), row[3])
		measured[#measured + 1] = string.format("%s %.2f", row[1], ratio)
		if ratio < weakest then weakest = ratio end
		s.ok(row[1] .. string.format(" %.2f ≥ %.1f", ratio, row[4]), ratio >= row[4])
	end
	Say("   contrastes : " .. table.concat(measured, ", "))
	-- textes : français et anglais, mêmes clés, aucun glyphe ★ ☆ ✓ ✗
	local bad, glyph = {}, {}
	for _, set in ipairs({ NS.SOUVENIR_STRINGS, NS.DISCORD_STRINGS }) do
		for key in pairs(set.fr) do if set.en[key] == nil then bad[#bad + 1] = key end end
		for key in pairs(set.en) do if set.fr[key] == nil then bad[#bad + 1] = key end end
		for _, lang in ipairs({ "fr", "en" }) do
			for key, text in pairs(set[lang]) do
				for _, g in ipairs({ "★", "☆", "✓", "✗" }) do if text:find(g, 1, true) then glyph[#glyph + 1] = key end end
			end
		end
	end
	s.ok("mêmes clés en français et en anglais", #bad == 0, table.concat(bad, ", "))
	s.ok("aucun glyphe ★ ☆ ✓ ✗", #glyph == 0, table.concat(glyph, ", "))
	s.check("[SOUV] contrastes mesurés (texte ≥ 4,5, titres ≥ 3 ; la phrase sous la carte sur le pire voile) ; textes FR/EN, sans glyphe")
	Done()
end
