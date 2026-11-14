-- QuestCompanion 2.7+ : ce que rapportent les hauts faits.
-- Titres (FeatsTitles.lua) : rendu (préfixe, suffixe, apposé en phrase, nu,
-- anglais), forme automatique et manuelle, choix (titres gagnés seulement,
-- compte et personnage, automatique, aucun), /qc titre. Fiche de dresseur
-- (TrainerCard.lua) : en-tête, sélecteurs, protocole (nouveau ↔ nouveau,
-- nouveau ↔ ancien, lecture stricte). Exploits de guilde (GuildFeats.lua) :
-- sorte h (envoi, lecture, refus des inconnus), paliers annoncés une fois,
-- grand effet des bandeaux. Cosmétiques (FeatsCosmetics.lua) : déblocage par
-- le haut fait seulement, condition lisible, rendu dans les deux styles,
-- replis quand une image ou un atlas manque. Catalogue : feats_catalogue.lua.
-- 3.1.0 : affirme l'ancien habillage (carnet en parchemin, scènes en bois, bandeaux
-- dorés, anneau) : le drapeau QNS.AZEROTH_LEGACY rallumé pour tout le module
-- (remis à la valeur du produit à sa fin, tests/run_tests.lua)
T.Legacy(true)
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- plusieurs étapes d'un même sujet : un contrôle, les étapes ratées nommées
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

-- ============================================================================================
-- I. Titres, fiche de dresseur, exploits de guilde
-- ============================================================================================
do
	local TT = { saved = {}, fx = {} }
	local GLOBALS = { "UnitName", "UnitFullName", "UnitSex", "UnitLevel", "GetLocale", "C_ChatInfo", "InCombatLockdown",
		"UnitAffectingCombat", "IsInGuild", "IsInGroup", "IsInRaid", "time", "GetNormalizedRealmName", "PlaySound", "C_Texture" }
	for _, name in ipairs(GLOBALS) do TT.saved[name] = rawget(_G, name) end
	TT.savedDormant = NS.featsDormant
	TT.savedFX = NS.AzerothRewardFX

	function TT.Reset()
		ResetWorld()
		NS:TrainerResetSession()
		NS:GuildFeatsReset()
		if NS.trainerFrame then NS.trainerFrame:Hide() end
		TT.sent, TT.sex, TT.name, TT.locale, TT.guild = {}, nil, nil, "frFR", true
		_G.UnitName = function(unit) if unit == "player" then return TT.name or "Testeur" end return nil end
		_G.UnitFullName = nil
		_G.UnitSex = function(unit) if unit == "player" then return TT.sex end return nil end
		_G.UnitLevel = function() return 20 end
		_G.GetLocale = function() return TT.locale end
		_G.C_ChatInfo = {
			RegisterAddonMessagePrefix = function() return 0 end,
			SendAddonMessage = function(prefix, text, channel, target)
				TT.sent[#TT.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
				return 0
			end,
			InChatMessagingLockdown = function() return false end,
		}
		_G.InCombatLockdown = function() return false end
		_G.UnitAffectingCombat = function() return false end
		_G.IsInGuild = function() return TT.guild end
		_G.IsInGroup = function() return false end
		_G.IsInRaid = function() return false end
		_G.time = function() return 1800000000 end
		_G.GetNormalizedRealmName = function() return "Royaume" end
		_G.PlaySound = function() return true end
		-- moteur réveillé, sans rattrapage de connexion
		NS.featsDormant = false
		NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
		NS.featLoginDone = true
		NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
		if NS.journalToast then NS.journalToast:Hide() end
		local db = NS:DB()
		db.trainerShare, db.guildFeatsSend, db.guildFeatsShow, db.guildFeatsChat = true, nil, nil, nil
		db.captureMuteUntil = nil
		NS:CompanionData().tutoDone = true
		Mock:Reset()
	end
	-- n espèces capturées par ce personnage (palier d'espèces = titre automatique)
	function TT.Species(n)
		local creatures = NS:CaptureData().creatures
		for i = 1, n do creatures[8000 + i] = { name = "Bête " .. i, class = "normal", zoneID = 1413, at = 1700000000, normal = true } end
		NS:CaptureData().count = n
		NS.captureAppCache = nil
	end
	function TT.Take()
		local list = TT.sent
		TT.sent = {}
		return list
	end
	-- l'analyseur des exploits de guilde d'avant la 2.7 (GuildFeats.lua 2.4) :
	-- quatre sortes, champs 1 à 8, la suite ignorée
	function TT.OldGuildParse(text)
		local fields = {}
		for field in (text .. "~"):gmatch("([^~]*)~") do
			fields[#fields + 1] = field
			if #fields > 16 then break end
		end
		if fields[1] ~= "E" or not tonumber(fields[2]) then return nil end
		if not ({ s = true, n = true, z = true, r = true })[fields[3] or ""] then return nil end
		for i = 4, 8 do if i ~= 7 and not (fields[i] or ""):find("^%d+$") then return nil end end
		return { kind = fields[3], id = tonumber(fields[4]) }
	end

	-- 1. Rendu ------------------------------------------------------------------------------------------
	do
		Say("-- titres : rendu")
		TT.Reset()
		local R = function(...) return NS:FeatTitleText(...) end
		local s = Steps()
		s.ok("préfixe", R(2, "Dyokrion", "m") == "Dresseur Dyokrion" and R(2, "Dyokrion", "f") == "Dresseuse Dyokrion")
		s.ok("suffixe apposé", R(13, "Dyokrion", "m") == "Dyokrion, Maître des brillantes"
			and R(13, "Dyokrion", "f") == "Dyokrion, Maîtresse des brillantes")
		s.ok("en phrase : virgule fermante après un suffixe apposé seulement",
			R(13, "Dyokrion", "m", { inline = true }) == "Dyokrion, Maître des brillantes,"
			and R(19, "Dyokrion", "m", { inline = true }) == "Dyokrion le Traqueur"
			and R(2, "Dyokrion", "m", { inline = true }) == "Dresseur Dyokrion")
		s.ok("nu : article retiré, capitale", R(12, nil, "m") == "Chasseur de brillantes" and R(11, nil, "f") == "Esthète"
			and R(26, nil, "m") == "Aux mains d'or" and R(40, nil, "f") == "Bredouille" and R(16, nil, "f") == "Arpenteuse"
			and R(19, nil, "f") == "Traqueuse" and R(35, nil, "m") == "Seigneur des créatures" and R(21, nil, "f") == "Aventurière")
		s.ok("épicène", R(18, "Ana", "f") == "Ana l'Infatigable" and R(28, "Ana", "f") == "Chef Ana")
		s.check("[TIT] rendu : préfixe, suffixe apposé (virgule fermante en phrase), nu, formes féminines et épicènes")
		TT.locale = "enUS"
		local english = R(35, "Dyo", "f") == "Dyo, Lady of the Creatures" and R(35, "Dyo", "m") == "Dyo, Lord of the Creatures"
			and R(37, nil, "f") == "Heroine of Azeroth" and R(12, nil, "f") == "Shiny Hunter" and R(2, "Dyo", "f") == "Trainer Dyo"
		TT.locale = "frFR"
		Check("[TIT] anglais : Lady / Heroine selon la forme, sinon une seule forme ; code inconnu : le nom seul",
			english and R(999, "Dyo") == nil and R("x") == nil and NS:FeatTitleWho("Dyo", 999) == "Dyo"
			and NS:FeatTitleWho("Dyo", 13, "m", true) == "Dyo, Maître des brillantes,")
	end

	-- 2. Forme des titres -------------------------------------------------------------------------------
	do
		Say("-- titres : forme")
		TT.Reset()
		local s = Steps()
		s.ok("UnitSex illisible : masculin, auto", NS:FeatTitleGender() == "m" and NS:FeatTitleForm() == "auto")
		TT.sex = 2
		s.ok("UnitSex 2 : masculin", NS:FeatTitleGender() == "m")
		TT.sex = 3
		s.ok("UnitSex 3 : féminin", NS:FeatTitleGender() == "f" and NS:FeatTitleText(19) == "Traqueuse")
		s.check("[TIT] forme automatique : d'après UnitSex (illisible = masculin), rendu par défaut à la bonne forme")
		s = Steps()
		s.ok("réglage masculin l'emporte", NS:FeatSetTitleForm("m") == "m" and NS:FeatTitleGender() == "m"
			and NS:FeatStore("char").form == "m")
		TT.sex = 2
		s.ok("réglage féminin l'emporte", NS:FeatSetTitleForm("f") == "f" and NS:FeatTitleGender() == "f")
		s.ok("forme inconnue refusée", NS:FeatSetTitleForm("x") == nil and NS:FeatTitleForm() == "f")
		s.ok("automatique : rien de stocké", NS:FeatSetTitleForm("auto") == "auto" and NS:FeatStore("char").form == nil
			and NS:FeatTitleGender() == "m")
		local row
		for _, page in ipairs(NS.OPTION_PAGES) do
			if page.id == "journal" then for _, r in ipairs(page.rows) do if r.key == "featTitleForm" then row = r end end end
		end
		s.ok("réglage « Forme des titres » (3 choix)", row and #row.choices() == 3 and row.current() == "auto")
		if row then row.choose("f") end
		s.ok("le choisir change la forme", NS:FeatTitleForm() == "f")
		NS:FeatSetTitleForm("auto")
		s.check("[TIT] forme manuelle par personnage : l'emporte sur UnitSex, inconnue refusée, réglage dans la section Hauts faits")
	end

	-- 3. Choix du titre ---------------------------------------------------------------------------------
	do
		Say("-- titres : choix")
		TT.Reset()
		local s = Steps()
		s.ok("rien de gagné", #NS:FeatTitlesEarned() == 0 and NS:FeatTitleCode() == nil and NS:TrainerTitle() == nil
			and #NS:FeatTitleOptions("Testeur") == 2 and not NS:FeatSetTitle(1))
		TT.Species(10)
		s.ok("10 espèces : « Apprenti dresseur » automatique", NS:FeatTitleCode() == 1 and NS:TrainerTitle() == "Apprenti dresseur")
		NS:FeatAward("day_rare_50", { silent = true })     -- personnage : titre 19
		NS:FeatAward("meta_menagerie", { silent = true })  -- compte : titre 35
		local earned = NS:FeatTitlesEarned()
		s.ok("gagnés : palier, personnage, compte, triés", #earned == 3 and earned[1] == 1 and earned[2] == 19 and earned[3] == 35)
		s.check("[TIT] titres gagnés : rien au départ, palier d'espèces automatique, personnage et compte triés")
		s = Steps()
		s.ok("choisir un titre gagné", NS:FeatSetTitle(19) and NS:FeatTitleCode() == 19 and NS:TrainerTitle() == "Traqueur"
			and NS:FeatTitleOptionValue() == "19")
		s.ok("pas gagné : refusé", not NS:FeatSetTitle(13) and not NS:FeatSetTitle(999) and NS:FeatTitleCode() == 19)
		local options = NS:FeatTitleOptions("Testeur")
		s.ok("sélecteur : Automatique, Aucun, titres rendus avec le nom", #options == 5 and options[1].value == "auto"
			and options[1].label:find("Apprenti dresseur", 1, true) and options[2].value == "none"
			and options[4].label == "Testeur le Traqueur" and options[5].label == "Testeur, Seigneur des créatures")
		s.check("[TIT] choix : un titre gagné seulement ; sélecteur Automatique, Aucun, puis les titres rendus avec le nom")
		-- un autre personnage : les titres de compte le suivent, pas ceux du personnage
		s = Steps()
		TT.name = "Autre"
		earned = NS:FeatTitlesEarned()
		-- 2.9.0 : la collection est au compte, le titre de palier de dresseur (1) la suit
		s.ok("compte et palier, pas le personnage", #earned == 2 and earned[1] == 1 and earned[2] == 35 and NS:FeatTitleCode() == 1)
		s.ok("peut choisir celui du compte", NS:FeatSetTitle(35) and NS:FeatTitleCode() == 35)
		s.ok("pas celui de l'autre personnage", not NS:FeatSetTitle(19))
		TT.name = nil
		s.ok("retour : choix gardé", NS:FeatTitleCode() == 19)
		s.check("[TIT] autre personnage : titres de compte et du palier de la collection, pas ceux du personnage ; choix par personnage")
		s = Steps()
		s.ok("aucun", NS:FeatSetTitle(0) and NS:FeatTitleCode() == nil and NS:TrainerTitle() == nil
			and NS:FeatTitleOptionValue() == "none" and NS:FeatStore("char").title == 0)
		s.ok("automatique", NS:FeatSetTitle(nil) and NS:FeatTitleCode() == 1 and NS:FeatStore("char").title == nil
			and NS:FeatTitleOptionValue() == "auto")
		NS:FeatStore("char").title = 13
		s.ok("choix enregistré plus disponible : automatique", NS:FeatTitleCode() == 1 and NS:FeatTitleOptionValue() == "auto"
			and NS:TrainerTitle() == "Apprenti dresseur")
		NS:FeatStore("char").title = nil
		s.ok("choix par valeur", NS:FeatTitlePick("35") and NS:FeatTitleCode() == 35 and NS:FeatTitlePick("none")
			and NS:FeatTitleCode() == nil and NS:FeatTitlePick("auto") and NS:FeatTitleCode() == 1)
		s.check("[TIT] aucun titre, automatique, choix devenu indisponible (repli automatique), choix par valeur")
	end

	-- 4. /qc titre ---------------------------------------------------------------------------------------
	do
		Say("-- titres : /qc titre")
		TT.Reset()
		TT.Species(10)
		NS:FeatAward("day_rare_50", { silent = true })
		NS:FeatAward("meta_menagerie", { silent = true })
		Mock:Reset()
		NS:HandleCommand("titre")
		local out = Mock:Output()
		local s = Steps()
		s.ok("liste numérotée", out:find("Titre affiché : Apprenti dresseur", 1, true) and out:find("19 — Traqueur", 1, true)
			and out:find("35 — Seigneur des créatures", 1, true), out)
		for _, case in ipairs({ { "titre traqueur", 19 }, { "titre 35", 35 }, { "titre aucun", nil },
			{ "titre seigneur des creatures", 35 }, { "titre auto", 1 }, { "titre Dame des créatures", 35 },
			{ "title the tracker", 19 }, { "titre dresseur", 1 } }) do
			NS:HandleCommand(case[1])
			s.ok(case[1], NS:FeatTitleCode() == case[2], NS:FeatTitleCode())
			if case[1] == "titre aucun" then s.ok("aucun : choix 0", NS:FeatTitleChoice() == 0) end
			if case[1] == "titre auto" then s.ok("auto : pas de choix", NS:FeatTitleChoice() == nil) end
		end
		s.check("[TIT] /qc titre : liste, puis par nom (casse, accents, forme féminine, anglais, morceau), numéro, aucun, auto")
		Mock:Reset()
		NS:HandleCommand("titre Maîtresse des brillantes|cffff0000")
		out = Mock:Output()
		local ok = NS:FeatTitleCode() == 1 and out:find("pas encore gagné", 1, true) and out:find("brillantes||cffff0000", 1, true) ~= nil
		NS:HandleCommand("titre 999")
		Check("[TIT] /qc titre : titre pas gagné ou numéro inconnu, rien ne change (pas de code couleur repris)", ok
			and NS:FeatTitleCode() == 1, out)
	end

	-- 5. Fiche de dresseur : en-tête, points, sélecteurs ---------------------------------------------------
	do
		Say("-- titres : fiche de dresseur")
		TT.Reset()
		TT.Species(10)
		NS:FeatAward("day_rare_50", { silent = true })     -- 25 points, personnage
		NS:FeatAward("meta_menagerie", { silent = true })  -- 50 points, compte
		NS:FeatSetTitle(19)
		local card = NS:TrainerOwnCard()
		local f = NS:TrainerOpen(nil)
		Check("[TIT] ma fiche : code, forme, texte nu, points ; en-tête « Testeur le Traqueur », points en sous-titre, sélecteurs",
			card.titleCode == 19 and card.gender == "m" and card.title == "Traqueur" and card.feats and card.feats.account == 50
			and card.feats.char == 25 and card.feats.count == 2 and f.header.title.text == "Testeur le Traqueur"
			and f.header.subtitle.text == "Hauts faits : 2 · 75 points (compte 50, perso 25)" and f.titlePicker:IsShown()
			and f.formPicker:IsShown() and #f.titlePicker.options == 5 and f.titlePicker:GetValue() == "19"
			and f.formPicker:GetValue() == "auto", f.header.title.text .. " / " .. tostring(f.header.subtitle.text))
		local s = Steps()
		f.titlePicker:Choose("1")
		s.ok("préfixe", NS:FeatTitleCode() == 1 and f.header.title.text == "Apprenti dresseur Testeur")
		f.titlePicker:Choose("35")
		s.ok("suffixe apposé", f.header.title.text == "Testeur, Seigneur des créatures")
		f.formPicker:Choose("f")
		s.ok("forme féminine", NS:FeatTitleForm() == "f" and f.header.title.text == "Testeur, Dame des créatures")
		f.titlePicker:Choose("none")
		s.ok("aucun : le nom seul", f.header.title.text == "Testeur" and NS:FeatTitleCode() == nil)
		NS:TrainerOpen("Bob")
		s.ok("fiche d'un autre : pas de sélecteur", not f.titlePicker:IsShown() and not f.formPicker:IsShown())
		s.check("[TIT] sélecteurs de la fiche : titre et forme appliqués à l'en-tête, absents sur la fiche d'un autre")
		f:Hide()
		NS:FeatSetTitleForm("auto")
		NS:FeatSetTitle(nil)
		TT.sex = 3
		card = NS:TrainerOwnCard()
		Check("[TIT] automatique, personnage féminin : « Apprentie dresseuse Testeur » ; sous-titre des points vide sans points",
			card.titleCode == 1 and card.gender == "f" and card.title == "Apprentie dresseuse"
			and NS:TrainerCardHeading(card, "Testeur") == "Apprentie dresseuse Testeur"
			and NS:TrainerCardFeatsText({ feats = { account = 0, char = 0, count = 0 } }) == "" and NS:TrainerCardFeatsText({}) == ""
			and NS:TrainerCardFeatsText({ feats = { account = 40, char = 0, count = 3 } }) == "Hauts faits : 3 · 40 points")
		TT.sex = nil
	end

	-- 6. Protocole de la fiche -----------------------------------------------------------------------------
	do
		Say("-- titres : protocole de la fiche")
		TT.Reset()
		TT.Species(10)
		NS:FeatAward("day_rare_50", { silent = true })
		NS:FeatAward("meta_menagerie", { silent = true })
		NS:FeatSetTitle(35)
		NS:FeatSetTitleForm("f")
		local text = NS:TrainerSerializeCard(NS:TrainerOwnCard())
		local raw = NS.TrainerDecode(text)
		Check("[TIT] fiche envoyée : ti, tg, ap, aq, ac, et le texte t lisible par les versions d'avant (nu, langue de l'expéditeur)",
			raw.ti == "35" and raw.tg == "f" and raw.ap == "50" and raw.aq == "25" and raw.ac == "2"
			and NS.TrainerUnescape(raw.t) == "Dame des créatures" and raw.n ~= nil, text)
		local back = NS:TrainerParseCard(text)
		TT.locale = "enUS"
		local heading = NS:TrainerCardHeading(back, "Bob")
		TT.locale = "frFR"
		Check("[TIT] nouveau → nouveau : code, forme, points relus ; titre rendu dans la langue du destinataire",
			back.titleCode == 35 and back.gender == "f" and back.feats.account == 50 and back.feats.char == 25
			and back.feats.count == 2 and back.title == "Dame des créatures" and heading == "Bob, Lady of the Creatures", heading)
		local old = NS:TrainerParseCard("p=1;n=Bob-Royaume;t=Ma%C3%AEtre des b%C3%AAtes;sp=3")
		local oldHeading, oldSub = NS:TrainerCardHeading(old, "Bob")
		local future = NS:TrainerParseCard("n=Bob;t=Titre futur;ti=200;tg=f")
		local futHeading, futSub = NS:TrainerCardHeading(future, "Bob")
		Check("[TIT] ancien → nouveau et code inconnu ici : le nom seul, le texte t reçu en sous-titre",
			old.titleCode == nil and old.feats == nil and oldHeading == "Bob" and oldSub == old.title and old.title ~= nil
			and future.titleCode == nil and futHeading == "Bob" and futSub == "Titre futur", tostring(oldSub))
		local bad = {}
		for _, value in ipairs({ "12a", "-3", "0", "1e3", "9999", "256", "", " 13", "0x0D" }) do
			if NS:TrainerParseCard("ti=" .. value).titleCode ~= nil then bad[#bad + 1] = "ti=" .. value end
		end
		if not (NS:TrainerParseCard("ti=19;tg=x").gender == "m" and NS:TrainerParseCard("ti=19").gender == "m"
			and NS:TrainerParseCard("ti=19;tg=f").gender == "f") then bad[#bad + 1] = "tg" end
		if not (NS:TrainerParseCard("ap=5;aq=x;ac=1").feats == nil and NS:TrainerParseCard("ap=999999;aq=1;ac=1").feats == nil
			and NS:TrainerParseCard("ap=5;aq=0").feats == nil and NS:TrainerParseCard("ap=5;aq=0;ac=1").feats.account == 5) then
			bad[#bad + 1] = "points"
		end
		Check("[TIT] lecture stricte : ti illisible, nul ou hors bornes ignoré ; forme inconnue = masculin ; points tous lisibles ou rien",
			#bad == 0, table.concat(bad, ", "))
		-- deux joueurs : ma fiche rejouée chez moi comme venant de Bob
		NS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Bob-Royaume")
		for _ = 1, 20 do NS:TrainerPump(10) end
		for _, msg in ipairs(TT.Take()) do NS:TrainerOnAddonMessage(msg.prefix, msg.text, "WHISPER", "Bob-Royaume") end
		local card = NS:TrainerCard("Bob")
		local f = NS:TrainerOpen("Bob")
		Check("[TIT] échange complet : en-tête « Bob, Dame des créatures », points", card and card.titleCode == 35
			and f.header.title.text == "Bob, Dame des créatures" and f.header.subtitle.text:find("75 points", 1, true) ~= nil,
			f.header.title.text)
		f:Hide()
		NS:FeatSetTitleForm("auto")
	end

	-- 7. Exploits de guilde : sorte h, titre de l'expéditeur -------------------------------------------------
	do
		Say("-- titres : exploits de guilde")
		TT.Reset()
		TT.Species(10)
		local parts = NS:GuildFeatMessage({ kind = "h", id = 73, zone = 0, stars = 0 }, 0, 13, "f")
		local plain = NS:GuildFeatMessage({ kind = "s", id = 3098, zone = 1411, stars = 2, class = "normal" }, 1)
		NS:FeatSetTitle(nil)
		NS:FeatAward("day_rare_50")
		Mock.now = Mock.now + NS.GFEAT_GATHER + 1
		for _ = 1, 5 do NS:TrainerPump(10) end
		local sent = TT.Take()
		Check("[TIT] message : titre en champs 9 et 10, sans titre le message d'avant ; haut fait à titre envoyé en sorte h "
			.. "(E~1~h~73~0~0~-~0~1~m), rejeté par l'analyseur d'avant", table.concat(parts, "~") == "h~73~0~0~-~0~13~f"
			and table.concat(plain, "~") == "s~3098~1411~2~normal~1" and sent[1] and sent[1].text == "E~1~h~73~0~0~-~0~1~m"
			and sent[1].channel == "GUILD" and TT.OldGuildParse(sent[1].text) == nil
			and TT.OldGuildParse("E~1~r~25~0~0~-~0~13~f") ~= nil, sent[1] and sent[1].text)
		local s = Steps()
		NS:GuildFeatsReset()
		NS:FeatAward("dng_visit_20", { silent = true })
		NS:FeatAward("zone_visit_25")
		NS:FeatAward("men_species_10")
		s.ok("rattrapage, 10 points, palier d'espèces : rien en h", NS.guildFeatsState.out == nil)
		NS:FeatAward("dng_visit_all")
		s.ok("50 points et un titre : retenu (score 800)", NS.guildFeatsState.out and NS.guildFeatsState.out.feat.kind == "h"
			and NS.GuildFeatScore(NS.guildFeatsState.out.feat) == 800)
		NS:GuildFeatsReset()
		TT.guild = false
		NS:FeatAward("meta_points_1500")
		s.ok("hors guilde : rien", NS.guildFeatsState.out == nil)
		TT.guild = true
		NS:DB().guildFeatsSend = false
		NS:FeatStore("account").got.meta_points_1500 = nil
		NS:FeatAward("meta_points_1500")
		s.ok("annonces coupées : rien", NS.guildFeatsState.out == nil)
		NS:DB().guildFeatsSend = nil
		s.check("[TIT] annonce de guilde : seulement un vrai gros haut fait, en guilde, annonces permises")
		-- paliers d'espèces : annoncés une fois (sorte r), 500 espèces en h
		local notes = {}
		local base = NS.GuildFeatNote
		NS.GuildFeatNote = function(_, feat) notes[#notes + 1] = feat; return true end
		for _, id in ipairs({ "men_species_10", "men_species_25", "men_species_50", "men_species_100", "men_species_250",
			"men_species_500" }) do
			local def = NS:FeatDef(id)
			NS:GuildFeatsOnFeat({ id = id, n = def.n, pts = def.pts, announce = true, retro = false })
		end
		NS.GuildFeatNote = base
		Check("[TIT] paliers d'espèces : annoncés une fois (sorte r), pas en h ; 500 espèces en h",
			#notes == 1 and notes[1].kind == "h" and notes[1].id == 7)
		-- réception
		NS:GuildFeatsReset()
		s = Steps()
		local info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~h~73~0~0~-~0~13~f"), "Bob-Royaume")
		s.ok("titre gagné", info and info.line == "Bob, Maîtresse des brillantes, a gagné le titre « Traqueuse » !"
			and info.sub == "Haut fait « Le traqueur » (+25)" and info.points == 25 and info.big == true, info and info.line)
		info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~h~109~0~0~-~0"), "Bob-Royaume")
		s.ok("haut fait sans titre", info and info.line == "Bob a obtenu le haut fait « Rien ne m'arrête » (+25) !"
			and info.sub == "Haut fait · Donjons et raids" and info.icon ~= nil, info and info.line)
		info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~19~f"), "Bob-Royaume")
		s.ok("autres sortes : nom avec titre, palier à sa forme", info and info.line == "Bob la Traqueuse a capturé 25 espèces !"
			and info.sub == "Nouveau titre : Dresseuse", info and info.line)
		info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~200~f"), "Bob-Royaume")
		local info2 = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~1x~f"), "Bob-Royaume")
		s.ok("code inconnu ou illisible : le nom seul", info and info2 and info.line == "Bob a capturé 25 espèces !"
			and info2.line == info.line)
		s.ok("réception complète par la guilde", NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0~13~f", "GUILD", "Bob-Royaume")
			and NS:GuildFeatsQueue()[1] and NS:GuildFeatsQueue()[1].score == 775)
		s.check("[TIT] réception : titre gagné, haut fait sans titre, nom de l'expéditeur avec son titre, code inconnu ignoré")
		local rejected = {}
		for _, msg in ipairs({
			"E~1~h~998~0~0~-~0",          -- haut fait inconnu chez nous
			"E~1~h~105~0~0~-~0",          -- haut fait « à vérifier » (jamais attribué)
			"E~1~h~73~5~0~-~0",           -- zone glissée
			"E~1~h~73~0~2~-~0",           -- étoiles glissées
			"E~1~h~73~0~0~rare~0",        -- rang glissé
			"E~1~h~1000~0~0~-~0",         -- code hors catalogue
			"E~1~h~7a~0~0~-~0",           -- code illisible
			"E~1~h~73~0~0~-",             -- champ manquant
		}) do
			if NS:GuildFeatsOnMessage(msg, "GUILD", "Cal-Royaume") then rejected[#rejected + 1] = msg end
		end
		NS:DB().guildFeatsShow = "shiny"
		if NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0", "GUILD", "Dan-Royaume") then rejected[#rejected + 1] = "brillantes seulement" end
		NS:DB().guildFeatsShow = nil
		Check("[TIT] lecture stricte de la sorte h : inconnus et champs faux ignorés ; « brillantes seulement » : pas de haut fait",
			#rejected == 0, table.concat(rejected, " | "))
		NS:GuildFeatsReset()
		NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0~13~f", "GUILD", "Bob-Royaume")
		NS:GuildFeatsToastTick(Mock.now)
		local toast = NS.guildFeatToast
		local withPoints = toast and toast:IsShown()
			and toast.text.text == "Bob, Maîtresse des brillantes, a gagné le titre « Traqueuse » !"
			and toast.featPoints and toast.featPoints.text == "25" and toast.featPoints:IsShown()
		NS:GuildFeatsShowToast({ key = "y", sender = "Yan-Royaume", feat = { kind = "z" }, score = 700, at = Mock.now,
			info = { kind = "z", line = "Yan a scellé une zone !", sub = "Sceau de zone : Mulgore" } })
		Check("[TIT] bandeau de guilde : la ligne et les points d'un haut fait, plus de points pour un exploit ordinaire",
			withPoints and not toast.featPoints:IsShown())
		NS:GuildFeatsHideToast()
	end

	-- 8. Grand effet des bandeaux (Azeroth) -----------------------------------------------------------------
	do
		Say("-- titres : grand effet")
		TT.Reset()
		local entry = { kind = "feat", id = "day_rare_50", title = "Haut fait obtenu", name = "Le traqueur", points = 25 }
		local small = { kind = "feat", id = "zone_visit_10", title = "Haut fait obtenu", name = "Bourlingueur", points = 5 }
		NS:DB().featToast = false
		NS:JournalToastPush(entry)
		NS:JournalToastPush(small)
		NS:DB().featToast = nil
		TT.fx = {}
		NS.AzerothRewardFX = function(_, frame) TT.fx[#TT.fx + 1] = frame; return true end
		for _, field in ipairs({ "journalToast", "guildFeatToast" }) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.uiStyleCache = {}
		Mock.InstallAtlas(true)
		NS:AzerothAtlasOK(true)
		NS:DB().companionStyle = "azeroth"
		NS.journalToasts, NS.journalToastHideAt = {}, nil
		local s = Steps()
		s.ok("titre ou 25 points : « grand », pas les petits", entry.big == true and not small.big)
		NS:JournalToastPush({ kind = "feat", id = "day_rare_50", title = "Haut fait obtenu", name = "Le traqueur", points = 25 })
		s.ok("ailes et éclat sur un gros", #TT.fx == 1 and TT.fx[1] == NS.journalToast and NS.journalToast.azeroth)
		NS.journalToast:Hide()
		NS.journalToastHideAt = nil
		NS:JournalToastPush({ kind = "feat", id = "zone_visit_10", title = "Haut fait obtenu", name = "Bourlingueur", points = 5 })
		s.ok("rien pour un petit", #TT.fx == 1)
		-- 3.0.1 : une place pour les bandeaux du haut (Banners.lua) : le carnet la rend
		NS.journalToast:Hide()
		NS.journalToastHideAt = nil
		NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0~13~f", "GUILD", "Bob-Royaume")
		NS:GuildFeatsToastTick(Mock.now)
		s.ok("bandeau de guilde d'un titre : effet et bouclier", #TT.fx == 2 and TT.fx[2] == NS.guildFeatToast
			and NS.guildFeatToast.azeroth and NS.guildFeatToast.featPoints.text == "25")
		s.check("[TIT] Azeroth : grand effet (ailes, éclat) sur les bandeaux d'un gros haut fait, du carnet comme de la guilde")
		NS:GuildFeatsHideToast()
		NS.AzerothRewardFX = TT.savedFX
		if NS.AzerothFxStop then NS:AzerothFxStop() end
		Mock.InstallAtlas(nil)
		NS:AzerothAtlasOK(true)
		NS:ApplyUIStyle()
		for _, field in ipairs({ "journalToast", "guildFeatToast" }) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.uiStyleCache = {}
	end

	-- rangement
	for _, name in ipairs(GLOBALS) do _G[name] = TT.saved[name] end
	NS.featsDormant = TT.savedDormant
	NS.featLoginDone = nil
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS:TrainerResetSession()
	NS:GuildFeatsReset()
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	NS:DB().companionStyle = nil
	ResetWorld()
end

-- ============================================================================================
-- II. Cosmétiques gagnés par les hauts faits
-- ============================================================================================
do
	local EXPECTED = {
		{ "frame", "feat_eight", "men_types_master" }, { "frame", "feat_prism", "meta_shiny" },
		{ "bg", "feat_atlas", "zone_100_10" }, { "bg", "feat_campfire", "char_camp_25" },
		{ "orn", "feat_chain", "men_boss_1" }, { "orn", "feat_goldstars", "men_stars3_100" },
		{ "orn", "feat_prism_orn", "shiny_3stars" }, { "orn", "feat_compass", "day_travel_1000" },
		{ "orn", "feat_anniversary", "day_days_365" }, { "orn", "feat_eye", "dng_raid_aq40" },
		{ "orn", "feat_wildcrown", "dng_raid_hyjal" },
	}
	local LISTS = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS" }
	local function Def(kind, id)
		for _, def in ipairs(NS[LISTS[kind]] or {}) do if def.id == id then return def end end
		return nil
	end
	local FIELDS = { "companionFrame", "companionBubble", "companionHover" }
	local function Reset(style)
		ResetWorld()
		for _, field in ipairs(FIELDS) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		_G.GetFileIDFromPath = nil
		NS.FeatFileReset()
		Mock.InstallAtlas(true)
		NS:AzerothAtlasOK(true)
		NS:SetUIStyle(style or "sobre")
		NS:CompanionData().tutoDone = true
		NS:CompanionUpdateVisibility()
		return NS:EnsureCompanionFrame()
	end

	-- 1. Replis : icône ou fichier absent du client -----------------------------------------------------------
	do
		Say("-- hauts faits, cosmétiques : replis")
		_G.GetFileIDFromPath = function(path) if path:find("CThun", 1, true) then return nil end return 1 end
		NS.FeatFileReset()
		local eye = NS.FeatPickIcon({ "Achievement_Boss_CThun", "INV_Misc_Eye_01" })
		_G.GetFileIDFromPath = function() return nil end
		NS.FeatFileReset()
		local none = NS.FeatPickIcon({ "INV_Crown_14" })
		_G.GetFileIDFromPath = nil
		NS.FeatFileReset()
		Check("[HF-E] icône absente du client : la suivante (l'œil d'origine sans celui de C'Thun) ; aucune : rien",
			eye == "Interface\\Icons\\INV_Misc_Eye_01" and none == nil)
		local frame = Reset("sobre")
		NS:CompanionData().unlocked["bg:seal_snow"] = true
		NS:CompanionSetStyle("bg", "seal_snow")
		local worn = frame.bgTexture == 189051 and not frame.bgFallback
		local set = frame.bg.SetTexture
		frame.bg.SetTexture = function(region, path) if type(path) == "number" then return false end return set(region, path) end
		NS:CompanionApplyBackground()
		Check("[HF-E] fond de sceau porté : le sol du client ; fichier refusé : aplat sombre, sans erreur", worn
			and frame.bgFallback == true)
		frame.bg.SetTexture = set
		ResetWorld()
	end

	-- 2. Déblocage par le haut fait, condition lisible ------------------------------------------------------
	do
		Say("-- hauts faits, cosmétiques : déblocage")
		Reset("sobre")
		local function AnyUnlocked()
			for _, row in ipairs(EXPECTED) do
				if NS:CompanionIsUnlocked(row[1], Def(row[1], row[2])) then return true end
			end
			return false
		end
		local s = Steps()
		s.ok("rien d'office", not AnyUnlocked())
		NS:CompanionCheckUnlocks(60, true)
		s.ok("ni le niveau ni les tampons", not AnyUnlocked())
		local def = Def("frame", "feat_eight")
		s.ok("condition « Haut fait : … »", NS:CompanionLockText(def) == "Haut fait : " .. NS:FeatName("men_types_master")
			and NS:FeatName("men_types_master") == "Les huit familles", NS:CompanionLockText(def))
		s.ok("carnet : la source dit le haut fait", NS:JournalCosmeticSource({ def = Def("orn", "feat_eye"), tier = 0 })
			== "Haut fait : L'œil se ferme")
		local hint
		for _, c in ipairs(NS:CompanionChoices("bg")) do if c.value == "feat_atlas" then hint = c.disabled and c.hint end end
		s.ok("liste : grisé avec sa condition", hint == "Haut fait : Dix zones accomplies", hint)
		s.ok("choix refusé tant que non gagné", NS:CompanionSetStyle("bg", "feat_atlas") == nil)
		s.check("[HF-E] cosmétiques des hauts faits : rien d'office (ni niveau ni tampons), grisés avec « Haut fait : … », refusés")
		s = Steps()
		local given = NS:FeatGrant(NS:FeatDef("zone_100_10"))
		s.ok("le haut fait donne le fond", given[1] == "bg:feat_atlas" and NS:CompanionIsUnlocked("bg", Def("bg", "feat_atlas")))
		for _, row in ipairs(EXPECTED) do
			NS:FeatGrant(NS:FeatDef(row[3]))
			s.ok(row[2], NS:CompanionIsUnlocked(row[1], Def(row[1], row[2])))
		end
		s.ok("donné deux fois : rien de neuf", #NS:FeatGrant(NS:FeatDef("men_boss_1"), { cosmeticsOnly = true }) == 0)
		s.check("[HF-E] chaque haut fait débloque son cosmétique, une seule fois")
		ResetWorld()
	end

	-- 3. Choix et rendu, style Sobre ------------------------------------------------------------------------
	do
		Say("-- hauts faits, cosmétiques : rendu Sobre")
		local frame = Reset("sobre")
		for _, row in ipairs(EXPECTED) do NS:FeatGrant(NS:FeatDef(row[3])) end
		local s = Steps()
		s.ok("Atlas : la carte du monde recadrée", NS:CompanionSetStyle("bg", "feat_atlas") ~= nil
			and frame.bgTexture == "Interface\\WorldMap\\Azeroth\\Azeroth6" and frame.bgCoords and not frame.bgFallback)
		NS:CompanionSetStyle("bg", "feat_campfire")
		local fire = frame.featFire
		s.ok("Feu de camp : nuit étoilée, halo, flamme en ADD", frame.bgStyle == "feat_campfire" and frame.stars
			and frame.stars[1]:IsShown() and fire and fire.glow and fire.glow.atlasName == "BonusChest-CircleGlow"
			and fire.flame:IsShown() and fire.flame.blendMode == "ADD" and fire.flame.texture == "Interface\\Icons\\Spell_Fire_Fire")
		NS:CompanionSetStyle("bg", "feat_atlas")
		s.ok("autre fond : plus de feu", not fire.flame:IsShown() and not fire.glow:IsShown())
		s.check("[HF-E] fonds gagnés (Sobre) : l'Atlas (carte du client), le Feu de camp (étoiles, halo, flamme), retirés au changement")
		NS:CompanionSetStyle("frame", "feat_eight")
		local holder = frame.featDeco
		local shown, icons = 0, {}
		for _, d in ipairs(holder and holder.eight or {}) do
			if d:IsShown() then shown = shown + 1 end
			icons[tostring(d.texture)] = true
		end
		local distinct = 0
		for path in pairs(icons) do if path:find("^Interface\\Icons\\") then distinct = distinct + 1 end end
		local p, rel, rp = holder.eight[1]:GetPoint()
		Check("[HF-E] cadre des huit familles : bordure dorée, huit icônes de familles du client sur le cadre carré, "
			.. "au-dessus de l'habillage", frame.frameStyle == "feat_eight" and frame.frameBackdrop == true and shown == 8
			and distinct == 8 and p == "CENTER" and rel == frame and rp == "TOPLEFT" and holder.level == (frame.level or 0) + 6)
		s = Steps()
		NS:CompanionSetStyle("frame", "feat_prism")
		local eightHidden = true
		for _, d in ipairs(holder.eight) do if d:IsShown() then eightHidden = false end end
		local before = frame.top.vertex and { frame.top.vertex[1], frame.top.vertex[2], frame.top.vertex[3] }
		Mock:Advance(2.5)
		local after = frame.top.vertex
		s.ok("les icônes partent, le filet change de teinte", eightHidden and before and after
			and (before[1] ~= after[1] or before[2] ~= after[2] or before[3] ~= after[3]))
		local top, right = frame.top.vertex, frame.rightEdge.vertex
		s.ok("un côté par quart de teinte", top[1] ~= right[1] or top[2] ~= right[2] or top[3] ~= right[3])
		NS:CompanionSetStyle("frame", "slate")
		s.ok("autre cadre : filet d'origine, plus d'horloge", frame.frameStyle == "slate"
			and holder:GetScript("OnUpdate") == nil and math.abs(frame.top.vertex[1] - 0.73) < 1e-6)
		s.check("[HF-E] cadre prismatique : un filet arc-en-ciel qui tourne, rendu à l'origine au changement de cadre")
		local orn = frame.featOrn or {}
		s = Steps()
		for _, row in ipairs(EXPECTED) do
			if row[1] == "orn" then s.ok(row[2] .. " posé", orn[row[2]] and orn[row[2]]:IsShown()) end
		end
		local chain = orn.feat_chain
		s.ok("chaîne dans l'anneau de minicarte", chain and chain.icon.texture == "Interface\\Icons\\Spell_Frost_ChainsOfIce"
			and chain.border.texture == "Interface\\Minimap\\MiniMap-TrackingBorder"
			and chain.back.texture == "Interface\\Minimap\\UI-Minimap-Background" and chain:GetParent() == frame.featDeco)
		s.ok("œil, couronne, ruban", orn.feat_eye.icon.texture == "Interface\\Icons\\Achievement_Boss_CThun"
			and orn.feat_wildcrown.icon.texture == "Interface\\Icons\\INV_Crown_14"
			and orn.feat_anniversary.icon.texture == "Interface\\Icons\\INV_Misc_Ribbon_01")
		local stars = orn.feat_goldstars.stars
		s.ok("trois étoiles de raid", stars and #stars == 3 and stars[2].texture == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
		s.ok("boussole", orn.feat_compass.icon.texture == "Interface\\Minimap\\MinimapArrow"
			and orn.feat_compass.north.texture == "Interface\\Minimap\\CompassNorthTag")
		local prism = orn.feat_prism_orn
		local v1 = prism.glow and prism.glow.vertex and prism.glow.vertex[1]
		Mock:Advance(3)
		s.ok("sphère prismatique, halo qui tourne", prism.icon.texture == "Interface\\Icons\\INV_Enchant_PrismaticSphere"
			and prism.glow and prism.glow.vertex[1] ~= v1)
		s.check("[HF-E] sept ornements posés au-dessus de l'habillage, chacun fait d'icônes et de cadres du client")
		s = Steps()
		NS:DB().companionOrnFeatChain = false
		NS:CompanionApplyOrnaments()
		s.ok("coupé : caché", not chain:IsShown())
		NS:DB().companionOrnFeatChain = true
		NS:CompanionApplyOrnaments()
		s.ok("rallumé : revenu", chain:IsShown())
		local labels = {}
		for _, def in ipairs(NS.COMPANION_ORNAMENTS) do
			if NS:CompanionIsUnlocked("orn", def) then labels[#labels + 1] = NS.L[def.label] or def.id end
		end
		local raw = false
		for _, text in ipairs(labels) do if tostring(text):find("^feat_") or tostring(text):find("^COMP_") then raw = true end end
		s.ok("page Compagnon : libellés lisibles", not raw and #labels >= 7)
		s.check("[HF-E] ornements : interrupteur par ornement, libellés lisibles sur la page Compagnon")
		ResetWorld()
	end

	-- 4. Atlas absents, style Azeroth ---------------------------------------------------------------------
	do
		Say("-- hauts faits, cosmétiques : atlas absents, Azeroth")
		local frame = Reset("sobre")
		Mock.InstallAtlas({ ["BonusChest-CircleGlow"] = true, ["garrlanding-circleglow"] = true })
		for _, row in ipairs(EXPECTED) do NS:FeatGrant(NS:FeatDef(row[3])) end
		NS:CompanionSetStyle("bg", "feat_campfire")
		Check("[HF-E] sans halo du client : le feu (flamme) et la sphère prismatique restent, sans erreur",
			frame.featFire and frame.featFire.glow == nil and frame.featFire.flame:IsShown()
			and frame.featOrn.feat_prism_orn and frame.featOrn.feat_prism_orn:IsShown() and frame.featOrn.feat_prism_orn.glow == nil)
		Mock.InstallAtlas(true)
		ResetWorld()

		frame = Reset("azeroth")
		for _, row in ipairs(EXPECTED) do NS:FeatGrant(NS:FeatDef(row[3])) end
		-- le client a les masques (le banc d'essai non) : le style arrondit le fond gagné
		frame.azSkin.mask = frame.azSkin.mask or {}
		frame.bg.AddMaskTexture = function(region, mask) region.maskTex = mask end
		frame.bg.RemoveMaskTexture = function(region) region.maskTex = nil end
		NS:CompanionApplyUIStyle()
		local s = Steps()
		NS:CompanionSetStyle("bg", "feat_atlas")
		s.ok("fond en disque sous l'anneau", frame.uiStyle == "azeroth" and frame.bg.azMasked == true
			and frame.bgTexture == "Interface\\WorldMap\\Azeroth\\Azeroth6")
		NS:CompanionSetStyle("frame", "feat_eight")
		local d = frame.featDeco.eight[1]
		local p, rel, rp, x, y = d:GetPoint()
		local ring = NS.AZEROTH_RING
		local r = math.sqrt(x * x + (y - ring.y) * (y - ring.y))
		s.ok("huit icônes autour de l'anneau", d:IsShown() and p == "CENTER" and rel == frame and rp == "TOP"
			and math.abs(r - (ring.w / 2 - 3)) < 0.01, r)
		NS:CompanionSetStyle("frame", "feat_prism")
		local halo = frame.featDeco.halo
		s.ok("prismatique : halo du client autour de l'anneau", halo and halo:IsShown() and halo.blendMode == "ADD"
			and halo.atlasName == "BonusChest-CircleGlow")
		local v = halo.vertex and halo.vertex[1]
		Mock:Advance(3)
		s.ok("sa teinte tourne", halo.vertex and halo.vertex[1] ~= v)
		NS:SetUIStyle("sobre")
		if NS.CompanionApplyUIStyle then NS:CompanionApplyUIStyle() end
		s.ok("retour en Sobre : halo caché, filet arc-en-ciel", not halo:IsShown() and frame.uiStyle == "sobre"
			and frame.featDeco:GetScript("OnUpdate") ~= nil)
		NS:SetUIStyle("azeroth")
		if NS.CompanionApplyUIStyle then NS:CompanionApplyUIStyle() end
		s.ok("ornements toujours là", frame.featOrn.feat_compass:IsShown())
		s.check("[HF-E] Azeroth : fond en disque, huit icônes autour de l'anneau, halo prismatique qui tourne, ornements gardés")
		NS:SetUIStyle("sobre")
		ResetWorld()
	end
end
