-- QuestCompanion 2.7.0, lot D des hauts faits : titres (FeatsTitles.lua),
-- fiche de dresseur (TrainerCard.lua) et exploits de guilde (GuildFeats.lua).
-- Registre des 40 titres comparé au document, rendu (préfixe, suffixe,
-- apposé en phrase, nu, anglais), forme automatique et manuelle, choix du
-- titre (titres gagnés seulement, compte et personnage, automatique,
-- aucun), /qc titre, en-tête de la fiche, protocole de la fiche (nouveau ↔
-- nouveau, nouveau ↔ ancien, lecture stricte), sorte h des exploits de
-- guilde (envoi, lecture, refus des inconnus), grand effet des bandeaux.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local TT = { saved = {}, fx = {} }
local GLOBALS = { "UnitName", "UnitFullName", "UnitSex", "UnitLevel", "GetLocale", "C_ChatInfo", "InCombatLockdown",
	"UnitAffectingCombat", "IsInGuild", "IsInGroup", "IsInRaid", "time", "GetNormalizedRealmName", "PlaySound", "C_Texture" }
for _, name in ipairs(GLOBALS) do TT.saved[name] = rawget(_G, name) end
TT.savedDormant = NS.featsDormant
TT.savedFX = NS.AzerothRewardFX

function TT.Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

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

function TT.Has(list, code)
	for _, item in ipairs(list) do if item == code then return true end end
	return false
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

-- 1. Registre ----------------------------------------------------------------------------------------
do
	Say("-- qc27 titres : registre")
	local T_ = NS.FEAT_TITLES
	local doc = TT.Read("docs/QC-HAUTS-FAITS.md") or ""
	local section = doc:sub(doc:find("### 4.1 Titres", 1, true) or 1, doc:find("### 4.2", 1, true) or #doc)
	local rows, bad = 0, {}
	for line in section:gmatch("[^\n]+") do
		local code, _, m, f, en, ps = line:match("^| T(%d+) | (.-) | (.-) | (.-) | (.-) | ([PS]) |$")
		if code then
			rows = rows + 1
			code = tonumber(code)
			local t = T_[code]
			local enm, enf = en:match("^(.-) / (.+)$")
			if not enm then enm = en end
			if not t then bad[#bad + 1] = "T" .. code .. " absent"
			else
				if t.m ~= m then bad[#bad + 1] = "T" .. code .. " m" end
				if (f == "—" and t.f ~= nil) or (f ~= "—" and t.f ~= f) then bad[#bad + 1] = "T" .. code .. " f" end
				if t.en ~= enm or t.enf ~= enf then bad[#bad + 1] = "T" .. code .. " en" end
				if (ps == "P") ~= (t.pos == "pre") then bad[#bad + 1] = "T" .. code .. " P/S" end
			end
		end
	end
	Check("[TIT] 40 titres, formes FR m/f et EN conformes au document (§4.1)", rows == 40 and #bad == 0,
		rows .. " lignes ; " .. table.concat(bad, ", "))
	local count, shape = 0, {}
	for code, t in pairs(T_) do
		count = count + 1
		if type(code) ~= "number" or code < 1 or code > NS.FEAT_TITLE_MAX then shape[#shape + 1] = tostring(code) .. " code" end
		for _, key in ipairs({ "m", "f", "en", "enf" }) do
			local fmt = t[key]
			if fmt ~= nil then
				local _, n = fmt:gsub("%%s", "")
				if n ~= 1 then shape[#shape + 1] = code .. " " .. key .. " %s" end
				if (t.pos == "pre") == (fmt:find("^%%s") ~= nil) then shape[#shape + 1] = code .. " " .. key .. " place" end
			end
		end
		if not (t.m and t.en and (t.pos == "pre" or t.pos == "suf")) then shape[#shape + 1] = code .. " incomplet" end
		if not (type(t.src) == "string" and doc:find("`" .. t.src .. "`", 1, true)) then shape[#shape + 1] = code .. " source" end
	end
	Check("[TIT] codes 1 à 40 uniques, un seul %s par forme, place cohérente, source citée par le document",
		count == 40 and #shape == 0, table.concat(shape, ", "))
	Check("[TIT] anglais genré seulement pour Seigneur / Dame et Héros / Héroïne", (function()
		for code, t in pairs(T_) do if t.enf and code ~= 35 and code ~= 37 then return false end end
		return T_[35].enf and T_[37].enf
	end)())
	local mismatch = {}
	for _, def in ipairs(NS:FeatDefs()) do
		local code = type(def.reward) == "table" and def.reward.title
		if code and not (T_[code] and T_[code].src == def.id) then mismatch[#mismatch + 1] = def.id end
	end
	Check("[TIT] chaque reward.title du catalogue pointe vers le titre de sa source", #mismatch == 0, table.concat(mismatch, ", "))
	local parity = {}
	for _, set in ipairs({ NS.FEAT_TITLE_STRINGS, NS.TRAINER_STRINGS, NS.GFEAT_STRINGS }) do
		for key in pairs(set.fr) do if set.en[key] == nil then parity[#parity + 1] = key end end
		for key in pairs(set.en) do if set.fr[key] == nil then parity[#parity + 1] = key end end
	end
	Check("[TIT] chaînes : mêmes clés en français et en anglais", #parity == 0, table.concat(parity, ", "))
	Check("[TIT] .toc : FeatsTitles.lua après Feats.lua et JournalFeats.lua", (function()
		local toc = TT.Read("QuestCompanion/QuestCompanion.toc") or ""
		local a, b, c = toc:find("\nFeats.lua", 1, true), toc:find("JournalFeats.lua", 1, true), toc:find("FeatsTitles.lua", 1, true)
		return a and b and c and a < c and b < c
	end)())
end

-- 2. Rendu ------------------------------------------------------------------------------------------
do
	Say("-- qc27 titres : rendu")
	TT.Reset()
	local R = function(...) return NS:FeatTitleText(...) end
	Check("[TIT] préfixe : « Dresseur Dyokrion », « Dresseuse Dyokrion »", R(2, "Dyokrion", "m") == "Dresseur Dyokrion"
		and R(2, "Dyokrion", "f") == "Dresseuse Dyokrion")
	Check("[TIT] suffixe apposé : « Dyokrion, Maître des brillantes »", R(13, "Dyokrion", "m") == "Dyokrion, Maître des brillantes"
		and R(13, "Dyokrion", "f") == "Dyokrion, Maîtresse des brillantes")
	Check("[TIT] en phrase : virgule fermante après un suffixe apposé, seulement",
		R(13, "Dyokrion", "m", { inline = true }) == "Dyokrion, Maître des brillantes,"
		and R(19, "Dyokrion", "m", { inline = true }) == "Dyokrion le Traqueur"
		and R(2, "Dyokrion", "m", { inline = true }) == "Dresseur Dyokrion")
	Check("[TIT] nu : article retiré, capitale", R(12, nil, "m") == "Chasseur de brillantes" and R(11, nil, "f") == "Esthète"
		and R(26, nil, "m") == "Aux mains d'or" and R(40, nil, "f") == "Bredouille" and R(16, nil, "f") == "Arpenteuse",
		tostring(R(26, nil, "m")))
	Check("[TIT] forme épicène : la même pour les deux", R(18, "Ana", "f") == "Ana l'Infatigable" and R(28, "Ana", "f") == "Chef Ana")
	TT.locale = "enUS"
	Check("[TIT] anglais : Lady / Heroine selon la forme, sinon une seule forme", R(35, "Dyo", "f") == "Dyo, Lady of the Menagerie"
		and R(35, "Dyo", "m") == "Dyo, Lord of the Menagerie" and R(37, nil, "f") == "Heroine of Azeroth"
		and R(12, nil, "f") == "Shiny Hunter" and R(2, "Dyo", "f") == "Trainer Dyo")
	TT.locale = "frFR"
	Check("[TIT] code inconnu : nil, le nom seul", R(999, "Dyo") == nil and R("x") == nil and NS:FeatTitleWho("Dyo", 999) == "Dyo"
		and NS:FeatTitleWho("Dyo", 13, "m", true) == "Dyo, Maître des brillantes,")
end

-- 3. Forme des titres -------------------------------------------------------------------------------
do
	Say("-- qc27 titres : forme")
	TT.Reset()
	Check("[TIT] UnitSex illisible : masculin", NS:FeatTitleGender() == "m" and NS:FeatTitleForm() == "auto")
	TT.sex = 2
	Check("[TIT] UnitSex 2 : masculin", NS:FeatTitleGender() == "m")
	TT.sex = 3
	Check("[TIT] UnitSex 3 : féminin, rendu par défaut à la bonne forme", NS:FeatTitleGender() == "f"
		and NS:FeatTitleText(19) == "Traqueuse")
	Check("[TIT] réglage masculin : l'emporte sur UnitSex", NS:FeatSetTitleForm("m") == "m" and NS:FeatTitleGender() == "m"
		and NS:FeatStore("char").form == "m")
	TT.sex = 2
	Check("[TIT] réglage féminin : l'emporte aussi", NS:FeatSetTitleForm("f") == "f" and NS:FeatTitleGender() == "f")
	Check("[TIT] forme inconnue refusée", NS:FeatSetTitleForm("x") == nil and NS:FeatTitleForm() == "f")
	Check("[TIT] automatique : retour à UnitSex, rien de stocké", NS:FeatSetTitleForm("auto") == "auto"
		and NS:FeatStore("char").form == nil and NS:FeatTitleGender() == "m")
	local row
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "journal" then for _, r in ipairs(page.rows) do if r.key == "featTitleForm" then row = r end end end
	end
	Check("[TIT] réglage « Forme des titres » dans la section Hauts faits", row and #row.choices() == 3 and row.current() == "auto")
	if row then row.choose("f") end
	Check("[TIT] … le choisir change la forme de ce personnage", NS:FeatTitleForm() == "f")
	NS:FeatSetTitleForm("auto")
end

-- 4. Choix du titre ---------------------------------------------------------------------------------
do
	Say("-- qc27 titres : choix")
	TT.Reset()
	Check("[TIT] rien de gagné : aucun titre, aucun choix possible", #NS:FeatTitlesEarned() == 0 and NS:FeatTitleCode() == nil
		and NS:TrainerTitle() == nil and #NS:FeatTitleOptions("Testeur") == 2 and not NS:FeatSetTitle(1))
	TT.Species(10)
	Check("[TIT] 10 espèces : « Apprenti dresseur » automatique, TrainerTitle inchangé", NS:FeatTitleCode() == 1
		and NS:TrainerTitle() == "Apprenti dresseur" and TT.Has(NS:FeatTitlesEarned(), 1))
	NS:FeatAward("day_rare_50", { silent = true })     -- personnage : titre 19
	NS:FeatAward("meta_menagerie", { silent = true })  -- compte : titre 35
	local earned = NS:FeatTitlesEarned()
	Check("[TIT] titres gagnés : palier, personnage et compte, triés", #earned == 3 and earned[1] == 1 and earned[2] == 19
		and earned[3] == 35)
	Check("[TIT] choisir un titre gagné", NS:FeatSetTitle(19) and NS:FeatTitleCode() == 19 and NS:TrainerTitle() == "Traqueur"
		and NS:FeatTitleOptionValue() == "19")
	Check("[TIT] un titre pas gagné : refusé, le choix reste", not NS:FeatSetTitle(13) and not NS:FeatSetTitle(999)
		and NS:FeatTitleCode() == 19)
	local options = NS:FeatTitleOptions("Testeur")
	Check("[TIT] sélecteur : Automatique, Aucun, puis les titres rendus avec le nom", #options == 5 and options[1].value == "auto"
		and options[1].label:find("Apprenti dresseur", 1, true) and options[2].value == "none"
		and options[4].label == "Testeur le Traqueur" and options[5].label == "Testeur, Seigneur de la ménagerie",
		options[4] and options[4].label)
	-- un autre personnage : les titres de compte le suivent, pas ceux du personnage
	TT.name = "Autre"
	earned = NS:FeatTitlesEarned()
	Check("[TIT] autre personnage : le titre de compte seulement", #earned == 1 and earned[1] == 35 and NS:FeatTitleCode() == nil)
	Check("[TIT] … qui peut le choisir", NS:FeatSetTitle(35) and NS:FeatTitleCode() == 35)
	Check("[TIT] … mais pas le titre de personnage d'un autre", not NS:FeatSetTitle(19))
	TT.name = nil
	Check("[TIT] retour : le choix de ce personnage est gardé", NS:FeatTitleCode() == 19)
	Check("[TIT] aucun titre", NS:FeatSetTitle(0) and NS:FeatTitleCode() == nil and NS:TrainerTitle() == nil
		and NS:FeatTitleOptionValue() == "none" and NS:FeatStore("char").title == 0)
	Check("[TIT] automatique : le palier d'espèces", NS:FeatSetTitle(nil) and NS:FeatTitleCode() == 1
		and NS:FeatStore("char").title == nil and NS:FeatTitleOptionValue() == "auto")
	NS:FeatStore("char").title = 13
	Check("[TIT] choix enregistré qui n'est plus disponible : automatique", NS:FeatTitleCode() == 1
		and NS:FeatTitleOptionValue() == "auto" and NS:TrainerTitle() == "Apprenti dresseur")
	NS:FeatStore("char").title = nil
	Check("[TIT] sélecteur : choix par valeur", NS:FeatTitlePick("35") and NS:FeatTitleCode() == 35 and NS:FeatTitlePick("none")
		and NS:FeatTitleCode() == nil and NS:FeatTitlePick("auto") and NS:FeatTitleCode() == 1)
end

-- 5. /qc titre ---------------------------------------------------------------------------------------
do
	Say("-- qc27 titres : /qc titre")
	TT.Reset()
	TT.Species(10)
	NS:FeatAward("day_rare_50", { silent = true })
	NS:FeatAward("meta_menagerie", { silent = true })
	Mock:Reset()
	NS:HandleCommand("titre")
	local out = Mock:Output()
	Check("[TIT] /qc titre : le titre affiché et la liste numérotée", out:find("Titre affiché : Apprenti dresseur", 1, true)
		and out:find("19 — Traqueur", 1, true) and out:find("35 — Seigneur de la ménagerie", 1, true), out)
	NS:HandleCommand("titre traqueur")
	Check("[TIT] /qc titre traqueur (casse libre)", NS:FeatTitleCode() == 19)
	NS:HandleCommand("titre 35")
	Check("[TIT] /qc titre 35", NS:FeatTitleCode() == 35)
	NS:HandleCommand("titre aucun")
	Check("[TIT] /qc titre aucun", NS:FeatTitleCode() == nil and NS:FeatTitleChoice() == 0)
	NS:HandleCommand("titre seigneur de la menagerie")
	Check("[TIT] sans les accents", NS:FeatTitleCode() == 35)
	NS:HandleCommand("titre auto")
	Check("[TIT] /qc titre auto", NS:FeatTitleChoice() == nil and NS:FeatTitleCode() == 1)
	NS:HandleCommand("titre Dame de la ménagerie")
	Check("[TIT] la forme féminine est reconnue aussi", NS:FeatTitleCode() == 35)
	NS:HandleCommand("title the tracker")
	Check("[TIT] /qc title, nom anglais", NS:FeatTitleCode() == 19)
	NS:HandleCommand("titre dresseur")
	Check("[TIT] un morceau de nom, un seul titre gagné qui le contient", NS:FeatTitleCode() == 1)
	Mock:Reset()
	NS:HandleCommand("titre Maîtresse des brillantes|cffff0000")
	out = Mock:Output()
	Check("[TIT] titre pas gagné : message, rien ne change, pas de code couleur", NS:FeatTitleCode() == 1
		and out:find("pas encore gagné", 1, true) and out:find("brillantes||cffff0000", 1, true) ~= nil, out)
	NS:HandleCommand("titre 999")
	Check("[TIT] numéro inconnu : rien ne change", NS:FeatTitleCode() == 1)
end

-- 6. Fiche de dresseur : en-tête, points, sélecteurs ---------------------------------------------------
do
	Say("-- qc27 titres : fiche de dresseur")
	TT.Reset()
	TT.Species(10)
	NS:FeatAward("day_rare_50", { silent = true })     -- 25 points, personnage
	NS:FeatAward("meta_menagerie", { silent = true })  -- 50 points, compte
	NS:FeatSetTitle(19)
	local card = NS:TrainerOwnCard()
	Check("[TIT] ma fiche : code, forme, texte nu, points", card.titleCode == 19 and card.gender == "m" and card.title == "Traqueur"
		and card.feats and card.feats.account == 50 and card.feats.char == 25 and card.feats.count == 2)
	local f = NS:TrainerOpen(nil)
	Check("[TIT] suffixe : « Testeur le Traqueur » en en-tête, points en sous-titre", f.header.title.text == "Testeur le Traqueur"
		and f.header.subtitle.text == "Hauts faits : 2 · 75 points (compte 50, perso 25)", f.header.title.text .. " / "
		.. tostring(f.header.subtitle.text))
	Check("[TIT] ma fiche : sélecteur de titre et forme visibles", f.titlePicker:IsShown() and f.formPicker:IsShown()
		and #f.titlePicker.options == 5 and f.titlePicker:GetValue() == "19" and f.formPicker:GetValue() == "auto")
	f.titlePicker:Choose("1")
	Check("[TIT] préfixe : « Apprenti dresseur Testeur »", NS:FeatTitleCode() == 1 and f.header.title.text == "Apprenti dresseur Testeur")
	f.titlePicker:Choose("35")
	Check("[TIT] suffixe apposé : « Testeur, Seigneur de la ménagerie »", f.header.title.text == "Testeur, Seigneur de la ménagerie")
	f.formPicker:Choose("f")
	Check("[TIT] forme féminine choisie sur la fiche", NS:FeatTitleForm() == "f" and f.header.title.text == "Testeur, Dame de la ménagerie")
	f.titlePicker:Choose("none")
	Check("[TIT] aucun titre : le nom seul", f.header.title.text == "Testeur" and NS:FeatTitleCode() == nil)
	-- une autre fiche : pas de sélecteur
	NS:TrainerOpen("Bob")
	Check("[TIT] fiche d'un autre : pas de sélecteur", not f.titlePicker:IsShown() and not f.formPicker:IsShown())
	f:Hide()
	NS:FeatSetTitleForm("auto")
	-- automatique, personnage féminin : le palier rendu au féminin sur la fiche
	NS:FeatSetTitle(nil)
	TT.sex = 3
	card = NS:TrainerOwnCard()
	Check("[TIT] automatique, personnage féminin : « Apprentie dresseuse »", card.titleCode == 1 and card.gender == "f"
		and card.title == "Apprentie dresseuse" and NS:TrainerCardHeading(card, "Testeur") == "Apprentie dresseuse Testeur")
	TT.sex = nil
	Check("[TIT] sans points : rien en sous-titre", NS:TrainerCardFeatsText({ feats = { account = 0, char = 0, count = 0 } }) == ""
		and NS:TrainerCardFeatsText({}) == "" and NS:TrainerCardFeatsText({ feats = { account = 40, char = 0, count = 3 } })
		== "Hauts faits : 3 · 40 points")
end

-- 7. Protocole de la fiche -----------------------------------------------------------------------------
do
	Say("-- qc27 titres : protocole de la fiche")
	TT.Reset()
	TT.Species(10)
	NS:FeatAward("day_rare_50", { silent = true })
	NS:FeatAward("meta_menagerie", { silent = true })
	NS:FeatSetTitle(35)
	NS:FeatSetTitleForm("f")
	local text = NS:TrainerSerializeCard(NS:TrainerOwnCard())
	local raw = NS.TrainerDecode(text)
	Check("[TIT] fiche envoyée : ti, tg, ap, aq, ac, et le texte t pour les versions d'avant", raw.ti == "35" and raw.tg == "f"
		and raw.ap == "50" and raw.aq == "25" and raw.ac == "2" and NS.TrainerUnescape(raw.t) == "Dame de la ménagerie", text)
	local back = NS:TrainerParseCard(text)
	Check("[TIT] nouveau → nouveau : code, forme, points relus", back.titleCode == 35 and back.gender == "f"
		and back.feats.account == 50 and back.feats.char == 25 and back.feats.count == 2 and back.title == "Dame de la ménagerie")
	TT.locale = "enUS"
	Check("[TIT] le destinataire rend le titre dans SA langue, à la forme reçue", NS:TrainerCardHeading(back, "Bob")
		== "Bob, Lady of the Menagerie")
	TT.locale = "frFR"
	-- nouveau → ancien : une version d'avant ne lit que ce qu'elle connaît (t)
	Check("[TIT] nouveau → ancien : t reste lisible, nu, dans la langue de l'expéditeur",
		NS.TrainerUnescape(raw.t) == "Dame de la ménagerie" and raw.n ~= nil)
	-- ancien → nouveau : pas de ti, le texte t en sous-titre
	local old = NS:TrainerParseCard("p=1;n=Bob-Royaume;t=Ma%C3%AEtre des b%C3%AAtes;sp=3")
	local heading, subtitle = NS:TrainerCardHeading(old, "Bob")
	Check("[TIT] ancien → nouveau : le nom seul, le texte reçu en sous-titre", old.titleCode == nil and old.feats == nil
		and heading == "Bob" and subtitle == old.title and old.title ~= nil, tostring(subtitle))
	-- code inconnu ici (version plus récente) : repli sur t
	local future = NS:TrainerParseCard("n=Bob;t=Titre futur;ti=200;tg=f")
	heading, subtitle = NS:TrainerCardHeading(future, "Bob")
	Check("[TIT] code inconnu ici : repli sur le texte t", future.titleCode == nil and heading == "Bob" and subtitle == "Titre futur")
	-- lecture stricte
	local bad = {}
	for _, value in ipairs({ "12a", "-3", "0", "1e3", "9999", "256", "", " 13", "0x0D" }) do
		if NS:TrainerParseCard("ti=" .. value).titleCode ~= nil then bad[#bad + 1] = value end
	end
	Check("[TIT] ti illisible, nul, hors bornes : ignoré", #bad == 0, table.concat(bad, ", "))
	Check("[TIT] forme inconnue ou absente : masculin", NS:TrainerParseCard("ti=19;tg=x").gender == "m"
		and NS:TrainerParseCard("ti=19").gender == "m" and NS:TrainerParseCard("ti=19;tg=f").gender == "f")
	Check("[TIT] points : les trois champs, tous lisibles, ou rien", NS:TrainerParseCard("ap=5;aq=x;ac=1").feats == nil
		and NS:TrainerParseCard("ap=999999;aq=1;ac=1").feats == nil and NS:TrainerParseCard("ap=5;aq=0").feats == nil
		and NS:TrainerParseCard("ap=5;aq=0;ac=1").feats.account == 5)
	-- deux joueurs : ma fiche rejouée chez moi comme venant de Bob
	NS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Bob-Royaume")
	for _ = 1, 20 do NS:TrainerPump(10) end
	local answer = TT.Take()
	for _, msg in ipairs(answer) do NS:TrainerOnAddonMessage(msg.prefix, msg.text, "WHISPER", "Bob-Royaume") end
	local card = NS:TrainerCard("Bob")
	local f = NS:TrainerOpen("Bob")
	Check("[TIT] échange complet : en-tête « Bob, Dame de la ménagerie », points", card and card.titleCode == 35
		and f.header.title.text == "Bob, Dame de la ménagerie" and f.header.subtitle.text:find("75 points", 1, true) ~= nil,
		f.header.title.text)
	f:Hide()
	NS:FeatSetTitleForm("auto")
end

-- 8. Exploits de guilde : sorte h, titre de l'expéditeur -------------------------------------------------
do
	Say("-- qc27 titres : exploits de guilde")
	TT.Reset()
	TT.Species(10)
	local parts = NS:GuildFeatMessage({ kind = "h", id = 73, zone = 0, stars = 0 }, 0, 13, "f")
	Check("[TIT] message avec titre : champs 9 et 10", table.concat(parts, "~") == "h~73~0~0~-~0~13~f")
	parts = NS:GuildFeatMessage({ kind = "s", id = 3098, zone = 1411, stars = 2, class = "normal" }, 1)
	Check("[TIT] sans titre : le message d'avant, inchangé", table.concat(parts, "~") == "s~3098~1411~2~normal~1")
	-- envoi : un haut fait à titre (25 points) part en sorte h, avec mon titre
	NS:FeatSetTitle(nil)
	NS:FeatAward("day_rare_50")
	Mock.now = Mock.now + NS.GFEAT_GATHER + 1
	for _ = 1, 5 do NS:TrainerPump(10) end
	local sent = TT.Take()
	Check("[TIT] haut fait annoncé : E~1~h~73~0~0~-~0~1~m", sent[1] and sent[1].text == "E~1~h~73~0~0~-~0~1~m"
		and sent[1].channel == "GUILD", sent[1] and sent[1].text)
	Check("[TIT] l'analyseur d'avant rejette la sorte h", TT.OldGuildParse(sent[1] and sent[1].text or "") == nil
		and TT.OldGuildParse("E~1~r~25~0~0~-~0~13~f") ~= nil)
	-- rattrapage, petit haut fait, palier d'espèces : rien en h
	NS:GuildFeatsReset()
	NS:FeatAward("dng_visit_20", { silent = true })
	NS:FeatAward("zone_visit_25")
	NS:FeatAward("men_species_10")
	Check("[TIT] rattrapage, 10 points, palier d'espèces (sorte r) : pas de sorte h", NS.guildFeatsState.out == nil)
	NS:FeatAward("dng_visit_all")
	Check("[TIT] 50 points et un titre : retenu (score entre sceau et palier)", NS.guildFeatsState.out
		and NS.guildFeatsState.out.feat.kind == "h" and NS.GuildFeatScore(NS.guildFeatsState.out.feat) == 800)
	NS:GuildFeatsReset()
	TT.guild = false
	NS:FeatAward("meta_points_1500")
	Check("[TIT] hors guilde : rien", NS.guildFeatsState.out == nil)
	TT.guild = true
	NS:DB().guildFeatsSend = false
	NS:FeatStore("account").got.meta_points_1500 = nil
	NS:FeatAward("meta_points_1500")
	Check("[TIT] annonces coupées : rien", NS.guildFeatsState.out == nil)
	NS:DB().guildFeatsSend = nil

	-- réception
	NS:GuildFeatsReset()
	local info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~h~73~0~0~-~0~13~f"), "Bob-Royaume")
	Check("[TIT] titre gagné : « Bob, Maîtresse des brillantes, a gagné le titre « Traqueuse » ! »", info
		and info.line == "Bob, Maîtresse des brillantes, a gagné le titre « Traqueuse » !"
		and info.sub == "Haut fait « Le traqueur » (+25)" and info.points == 25 and info.big == true, info and info.line)
	info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~h~109~0~0~-~0"), "Bob-Royaume")
	Check("[TIT] haut fait sans titre : « Bob a obtenu le haut fait « Rien ne m'arrête » (+25) ! »", info
		and info.line == "Bob a obtenu le haut fait « Rien ne m'arrête » (+25) !" and info.sub == "Haut fait · Donjons et raids"
		and info.icon ~= nil, info and info.line)
	info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~19~f"), "Bob-Royaume")
	Check("[TIT] autres sortes : le nom avec son titre, palier rendu à sa forme", info
		and info.line == "Bob la Traqueuse a capturé 25 espèces !" and info.sub == "Nouveau titre : Dresseuse", info and info.line)
	info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~200~f"), "Bob-Royaume")
	local info2 = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~1x~f"), "Bob-Royaume")
	Check("[TIT] code de titre inconnu ou illisible : le nom seul, le message gardé", info and info2
		and info.line == "Bob a capturé 25 espèces !" and info2.line == info.line)
	Check("[TIT] réception complète par la guilde", NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0~13~f", "GUILD", "Bob-Royaume")
		and NS:GuildFeatsQueue()[1] and NS:GuildFeatsQueue()[1].score == 775)
	local rejected = {}
	for _, msg in ipairs({
		"E~1~h~998~0~0~-~0",          -- haut fait inconnu chez nous
		"E~1~h~98~0~0~-~0",           -- haut fait « à vérifier » (jamais attribué)
		"E~1~h~73~5~0~-~0",           -- zone glissée
		"E~1~h~73~0~2~-~0",           -- étoiles glissées
		"E~1~h~73~0~0~rare~0",        -- rang glissé
		"E~1~h~1000~0~0~-~0",         -- code hors catalogue
		"E~1~h~7a~0~0~-~0",           -- code illisible
		"E~1~h~73~0~0~-",             -- champ manquant
	}) do
		if NS:GuildFeatsOnMessage(msg, "GUILD", "Cal-Royaume") then rejected[#rejected + 1] = msg end
	end
	Check("[TIT] lecture stricte de la sorte h : inconnus et champs faux ignorés", #rejected == 0, table.concat(rejected, " | "))
	NS:DB().guildFeatsShow = "shiny"
	Check("[TIT] « brillantes seulement » : pas de haut fait", not NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0", "GUILD", "Dan-Royaume"))
	NS:DB().guildFeatsShow = nil
	-- bandeau (Sobre) : icône de la catégorie et points
	NS:GuildFeatsReset()
	NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0~13~f", "GUILD", "Bob-Royaume")
	NS:GuildFeatsToastTick(Mock.now)
	local toast = NS.guildFeatToast
	Check("[TIT] bandeau de guilde : la ligne, la sous-ligne, les points", toast and toast:IsShown()
		and toast.text.text == "Bob, Maîtresse des brillantes, a gagné le titre « Traqueuse » !"
		and toast.featPoints and toast.featPoints.text == "25" and toast.featPoints:IsShown())
	NS:GuildFeatsShowToast({ key = "y", sender = "Yan-Royaume", feat = { kind = "z" }, score = 700, at = Mock.now,
		info = { kind = "z", line = "Yan a scellé une zone !", sub = "Sceau de zone : Mulgore" } })
	Check("[TIT] exploit ordinaire ensuite : plus de points", not toast.featPoints:IsShown())
	NS:GuildFeatsHideToast()
end

-- 9. Grand effet des bandeaux (Azeroth) -----------------------------------------------------------------
do
	Say("-- qc27 titres : grand effet")
	TT.Reset()
	local entry = { kind = "feat", id = "day_rare_50", title = "Haut fait obtenu", name = "Le traqueur", points = 25 }
	local small = { kind = "feat", id = "zone_visit_10", title = "Haut fait obtenu", name = "Bourlingueur", points = 5 }
	NS:DB().featToast = false
	NS:JournalToastPush(entry)
	NS:JournalToastPush(small)
	NS:DB().featToast = nil
	Check("[TIT] titre ou 25 points : bandeau marqué « grand », pas les petits", entry.big == true and not small.big)
	-- style Azeroth : l'effet part sur le bandeau du carnet et sur celui de la guilde
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
	NS:JournalToastPush({ kind = "feat", id = "day_rare_50", title = "Haut fait obtenu", name = "Le traqueur", points = 25 })
	Check("[TIT] Azeroth : ailes et éclat sur le bandeau d'un gros haut fait", #TT.fx == 1 and TT.fx[1] == NS.journalToast
		and NS.journalToast.azeroth)
	NS.journalToast:Hide()
	NS.journalToastHideAt = nil
	NS:JournalToastPush({ kind = "feat", id = "zone_visit_10", title = "Haut fait obtenu", name = "Bourlingueur", points = 5 })
	Check("[TIT] Azeroth : rien pour un petit", #TT.fx == 1)
	NS:GuildFeatsOnMessage("E~1~h~73~0~0~-~0~13~f", "GUILD", "Bob-Royaume")
	NS:GuildFeatsToastTick(Mock.now)
	Check("[TIT] Azeroth : bandeau de guilde d'un titre, avec l'effet et le bouclier", #TT.fx == 2 and TT.fx[2] == NS.guildFeatToast
		and NS.guildFeatToast.azeroth and NS.guildFeatToast.featPoints.text == "25")
	NS:GuildFeatsHideToast()
	-- rangement : les autres modules testent le style Sobre
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

-- Rangement
do
	for _, name in ipairs(GLOBALS) do _G[name] = TT.saved[name] end
	NS.featsDormant = TT.savedDormant
	NS.featLoginDone = nil
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS:TrainerResetSession()
	NS:GuildFeatsReset()
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	ResetWorld()
end
