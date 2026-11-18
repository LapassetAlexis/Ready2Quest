-- QC 3.6.0 (docs/audit-pokemon-like-3.5, lot 1B « Des buts longs ») : rangs
-- de dresseur au-delà de 250 et « tout Azeroth », fonds et cadres de la fiche
-- de dresseur (catalogue, déblocage, choix, partage, contraste mesuré sur nos
-- textures), médailles de type (paliers 4 et 5, sans force en plus),
-- récompenses de l'étude et du lien, liseré d'or d'une espèce maîtrisée,
-- marque « Inséparable » sur la vignette.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

local function Fresh()
	ResetWorld()
	local capture = NS:CaptureData()
	capture.creatures, capture.count = {}, 0
	capture.serial = (tonumber(capture.serial) or 0) + 1
	NS.menagerieStatic = nil
	if NS.FeatMenagerieScanReset then NS:FeatMenagerieScanReset() end
	return capture
end

local function Caught(npc, typeText)
	local capture = NS:CaptureData()
	if capture.creatures[npc] == nil then capture.count = capture.count + 1 end
	capture.creatures[npc] = { name = "Créature " .. npc, class = "normal", type = typeText or "Bête", normal = true, stars = 2, at = 1 }
	capture.serial = (tonumber(capture.serial) or 0) + 1
end

-- 1. Rangs de dresseur au-delà de 250, « tout Azeroth » --------------------------------------
do
	Say("-- 3.6 B : rangs de dresseur")
	Fresh()
	local R = NS.TRAINER_RANKS
	local counts = {}
	for index = 6, 12 do counts[#counts + 1] = R[index].count end
	Check("[L36B] rangs : 500, 750, 1000, 1500, 2000, 2500, 3000 puis « tout Azeroth », un titre chacun",
		#R == 13 and table.concat(counts, ",") == "500,750,1000,1500,2000,2500,3000" and R[13].all and R[13].count > 3000
		and NS.FEAT_RANK_TITLES.wildtracker == 41 and NS.FEAT_RANK_TITLES.azeroth == 47 and NS.FEAT_RANK_TITLES.beastwalker == 6
		and NS.L.TRAINER_azeroth == "Dresseur de tout Azeroth", table.concat(counts, ","))
	for index = 1, 760 do Caught(100000 + index) end
	local rank, _, nextRank = NS:TrainerRank()
	Check("[L36B] 760 espèces : rang « Pisteur des terres sauvages » (titre automatique T41), le suivant à 1000",
		rank and rank.key == "wildtracker" and nextRank and nextRank.count == 1000 and NS:FeatTitleAuto() == 41,
		rank and rank.key)
	local gained = NS:MenagerieRankCheck({ quiet = true })
	local coll = NS:MenagerieCollectionData()
	Check("[L36B] palier noté une fois (750 compris), « tout Azeroth » pas encore", coll.ranks[750] ~= nil and coll.ranks[500] ~= nil
		and coll.ranks.azeroth == nil and #NS:MenagerieRankCheck({ quiet = true }) == 0 and #gained >= 7)
	-- « tout Azeroth » : toutes les espèces de la table de ta faction (hors boss du monde, 9999)
	local catalog = NS:MenagerieCatalog()
	local have, need = NS:MenagerieAzeroth()
	local wanted = 0
	for _, item in ipairs(catalog.list) do
		if item.class ~= "worldboss" and (tonumber(item.lo) or 0) < 9999 then wanted = wanted + 1 end
	end
	Check("[L36B] tout Azeroth : la table de la faction, hors boss du monde et lignes 9999", need == wanted and need > 0
		and have == 0, have .. "/" .. need)
	for _, item in ipairs(catalog.list) do
		if item.class ~= "worldboss" and (tonumber(item.lo) or 0) < 9999 then Caught(item.npc) end
	end
	have, need = NS:MenagerieAzeroth()
	local source = NS.FEAT_SOURCES.azeroth.get(NS)
	local azerothGained = false
	for _, r in ipairs(NS:MenagerieRankCheck({ quiet = true })) do if r.key == "azeroth" then azerothGained = true end end
	Check("[L36B] tout Azeroth : atteint quand il n'en manque aucune ; haut fait à 100 %, rang noté sous sa clé",
		have == need and NS:TrainerRankReached(R[13]) and source == 100 and NS:FeatDef("men_species_all").crit[2] == "azeroth"
		and azerothGained and coll.ranks.azeroth ~= nil,
		have .. "/" .. need .. " " .. tostring(source))
	local codes, titles = {}, {}
	for n, id in ipairs({ "men_species_750", "men_species_1000", "men_species_1500", "men_species_2000", "men_species_2500",
		"men_species_3000", "men_species_all" }) do
		local def = NS:FeatDef(id)
		codes[#codes + 1] = def and def.n or 0
		titles[#titles + 1] = def and def.reward.title or 0
		if not (def and def.pts == 50 and def.scope == "account" and NS.FEAT_TITLES[40 + n].src == id) then codes[#codes + 1] = "x" end
	end
	Check("[L36B] hauts faits 188 à 194, 50 points, au compte, titres 41 à 47 (libres pour le chantier B)",
		table.concat(codes, ",") == "188,189,190,191,192,193,194" and table.concat(titles, ",") == "41,42,43,44,45,46,47",
		table.concat(codes, ","))
	local gift = NS:TrainerRankGift(R[6])
	Check("[L36B] ce que rapporte un rang long : le titre et le fond de fiche de son haut fait (500)",
		gift:find("Arpenteur des bêtes", 1, true) ~= nil and gift:find("Registre des espèces", 1, true) ~= nil, gift)
end

-- 2. Médailles de type : paliers 4 et 5, cosmétiques seulement ------------------------------
do
	Say("-- 3.6 B : médailles de type")
	Fresh()
	NS:MenagerieCollectionData().medals = {}
	for index = 1, 85 do Caught(200000 + index, "Bête") end
	for index = 1, 40 do Caught(210000 + index, "Démon") end
	local beast, beastCount, beastNext = NS:MenagerieMedal("beast")
	local demon, _, demonNext = NS:MenagerieMedal("demon")
	Check("[L36B] médaille : bêtes 85 → palier 4 (prochain à 160) ; démons 40 → palier 4 (rare : 40, 80)",
		beast == 4 and beastCount == 85 and beastNext == 160 and demon == 4 and demonNext == 80,
		beast .. "/" .. demon .. "/" .. tostring(beastNext))
	Check("[L36B] médaille : aucune force en plus au-delà du palier 3 (compagnon)",
		NS:MenagerieTypeBonus("beast") == 3 * NS.MENAGERIE_TYPE_STEP and NS:MenagerieTypeTier("beast") == 3)
	local said = {}
	local print = NS.Print
	NS.Print = function(_, text) said[#said + 1] = text end
	local first = NS:MenagerieMedalCheck()
	local again = NS:MenagerieMedalCheck()
	NS.Print = print
	Check("[L36B] médailles 4 et 5 annoncées une fois", #first == 2 and #again == 0 and #said == 2
		and said[1]:find("médaille de palier 4", 1, true) ~= nil, table.concat(said, " | "))
	for index = 86, 160 do Caught(200000 + index, "Bête") end
	Check("[L36B] bêtes 160 → palier 5 (le dernier)", (NS:MenagerieMedal("beast")) == 5 and NS:TrainerOwnMedals().beast == 5
		and NS:TrainerOwnMedals().demon == 4 and NS:TrainerOwnMedals().giant == nil)
end

-- 3. Fonds et cadres de la fiche : catalogue, textures, déblocage, choix ---------------------
do
	Say("-- 3.6 B : fonds et cadres de fiche")
	Fresh()
	local BG, FR = NS.TRAINER_CARD_BACKGROUNDS, NS.TRAINER_CARD_FRAMES
	local bad = {}
	for kind, list in pairs({ cardbg = BG, cardframe = FR }) do
		for _, def in ipairs(list) do
			local fd = NS:FeatDef(def.unlock.feat)
			local c = fd and fd.reward and fd.reward.cosmetic
			if not (c and c[1] == kind and c[2] == def.id) then bad[#bad + 1] = def.id .. " haut fait" end
			if not (NS.L[def.label] ~= def.label and NS.L[def.name] ~= def.name) then bad[#bad + 1] = def.id .. " libellé" end
			for _, addon in ipairs({ "Ready2Quest", "QuestCompanion" }) do
				if not Read(addon .. "/Libs/Socle/Media/" .. def.tex .. ".tga") then bad[#bad + 1] = def.id .. " " .. addon end
			end
			if not def.file:find("Libs\\Socle\\Media\\" .. def.tex, 1, true) then bad[#bad + 1] = def.id .. " chemin" end
		end
	end
	local soon = 0
	for _, def in ipairs(NS:FeatDefs()) do if def.reward and def.reward.soon then soon = soon + 1 end end
	Check("[L36B] 4 fonds et 3 cadres de fiche : donnés par les 7 hauts faits promis, nommés FR/EN, textures dans le socle des deux addons",
		#BG == 4 and #FR == 3 and #bad == 0 and soon == 0, table.concat(bad, ", "))
	local src = (Read("tools/gen_ui_assets.py") or "")
	Check("[L36B] textures générées par tools/gen_ui_assets.py (aucune image du jeu)", src:find("def fiche_registre", 1, true) ~= nil
		and src:find("def fiche_lauriers", 1, true) ~= nil and src:find("Interface", 1, true) == nil)
	-- liste : grisée tant que pas gagné ; choix refusé
	local options = NS:TrainerCardStyleOptions("cardbg")
	local refused = NS:TrainerCardStyleSet("cardbg", "card_census") == false
	Check("[L36B] fond pas gagné : grisé avec sa condition, refusé", #options == 5 and options[1].value == "none"
		and options[2].disabled and (options[2].hint or ""):find("Le grand recensement", 1, true) ~= nil and refused
		and options[1].label == "Fond : aucun", tostring(options[2].hint))
	-- gagné par le haut fait : débloqué, choisi, sur ma fiche
	NS:FeatGrant(NS:FeatDef("men_species_500"))
	NS:FeatGrant(NS:FeatDef("meta_hero"))
	local set = NS:TrainerCardStyleSet("cardbg", "card_census") and NS:TrainerCardStyleSet("cardframe", "card_laurels")
	local bg, frame = NS:TrainerCardStyle()
	local card = NS:TrainerOwnCard()
	Check("[L36B] gagné : débloqué au compagnon, choisi, porté par ma fiche", set and bg == "card_census" and frame == "card_laurels"
		and NS:CompanionData().unlocked["cardbg:card_census"] and card.styleBg == "card_census" and card.styleFrame == "card_laurels")
	-- partage : champs facultatifs, liste blanche
	card.mastered, card.medals = 12, { beast = 5, demon = 4 }
	local text = NS:TrainerSerializeCard(card)
	local fields = NS.TrainerDecode(text)
	local back = NS:TrainerParseCard(text)
	Check("[L36B] partage : cb, cf, sm, md ; aller-retour", fields.cb == "card_census" and fields.cf == "card_laurels"
		and fields.sm == "12" and back.styleBg == "card_census" and back.styleFrame == "card_laurels" and back.mastered == 12
		and back.medals.beast == 5 and back.medals.demon == 4 and fields.p == "1", tostring(fields.md))
	local evil = NS:TrainerParseCard("p=1;n=Bob;cb=../../x;cf=card_inconnu;sm=12a;md=beast:9,dragon:3,giant:2")
	local old = NS:TrainerParseCard("p=1;n=Bob;sp=10")
	Check("[L36B] partage : id inconnu, palier faux, type inconnu écartés ; fiche d'avant : rien", evil.styleBg == nil
		and evil.styleFrame == nil and evil.mastered == nil and evil.medals and evil.medals.giant == 2 and evil.medals.beast == nil
		and evil.medals.dragon == nil and old.styleBg == nil and old.medals == nil and old.mastered == nil)
	-- « aucun » rend la fiche d'avant
	NS:TrainerCardStyleSet("cardbg", "none")
	Check("[L36B] « aucun » : plus de fond", (NS:TrainerCardStyle()) == nil)
end

-- 4. Contraste du texte de la fiche sur chaque fond (point le plus clair), deux styles ----------
do
	Say("-- 3.6 B : contrastes sur les fonds de fiche")
	local function Brightest(path)
		local data = Read(path)
		if not data or #data < 18 then return nil end
		local w, h = data:byte(13) + 256 * data:byte(14), data:byte(15) + 256 * data:byte(16)
		local best, bestL = nil, -1
		for i = 0, w * h - 1 do
			local o = 19 + i * 4
			local b, g, r = data:byte(o), data:byte(o + 1), data:byte(o + 2)
			local c = { r / 255, g / 255, b / 255 }
			local l = Theme.Luminance(c)
			if l > bestL then best, bestL = c, l end
		end
		return best, bestL
	end
	local bad, worst = {}, 99
	for _, skin in ipairs({ "sobre", "azeroth" }) do
		Theme.ApplySkin(skin)
		for _, def in ipairs(NS.TRAINER_CARD_BACKGROUNDS) do
			local light = Brightest("QuestCompanion/Libs/Socle/Media/" .. def.tex .. ".tga")
			if not light then bad[#bad + 1] = def.id .. " illisible" else
				for _, ink in ipairs({ "TEXT", "MUTED_LIGHT", "MUTED", "LABEL", "PARCHMENT", "GOLD", "GOLD_LIGHT" }) do
					local c = Theme.Contrast(Theme[ink], light)
					worst = math.min(worst, c)
					if c < 4.5 then bad[#bad + 1] = string.format("%s %s %s %.2f", skin, def.id, ink, c) end
				end
				for _, ink in ipairs({ "TITLE", "IDENTITY", "GOLD_SOFT" }) do
					if Theme[ink] then
						local c = Theme.Contrast(Theme[ink], light)
						if c < 3 then bad[#bad + 1] = string.format("%s %s %s %.2f (titre)", skin, def.id, ink, c) end
					end
				end
			end
		end
	end
	Theme.ApplySkin(NS:UISkinChoice())
	Check("[L36B] texte de la fiche sur chaque fond : ≥ 4,5 (titres ≥ 3), au pixel le plus clair, deux styles",
		#bad == 0, table.concat(bad, ", ") .. string.format(" (pire %.2f)", worst))
end

-- 5. Récompenses de l'étude et du lien ---------------------------------------------------------
do
	Say("-- 3.6 B : récompenses de l'étude et du lien")
	local function Rw(id) return NS:FeatDef(id).reward or {} end
	local text = NS:FeatRewardText(NS:FeatDef("men_bond_inseparable"))
	Check("[L36B] étude 10/50/100 : aide, titre, ornement ; Inséparable : titre « l'Inséparable » ; 8 caractères : cadre ; 5 tailles : fond",
		(Rw("men_study_10").aids or {}).sifflet == 1 and Rw("men_study_50").title == 48 and Rw("men_study_100").cosmetic[2] == "feat_scholar"
		and Rw("men_bond_inseparable").title == 49 and Rw("men_traits_all").cosmetic[1] == "frame"
		and Rw("men_sizes_all").cosmetic[1] == "bg" and NS:FeatTitleText(49, "Dyokrion") == "Dyokrion l'Inséparable"
		and text:find("Inséparable", 1, true) ~= nil, text)
end

-- 6. Écrans : liseré d'or d'une espèce maîtrisée, marque « Inséparable », fiche -----------------
do
	Say("-- 3.6 B : liseré, marque, fiche")
	Fresh()
	Caught(3098, "Bête"); Caught(3099, "Bête")
	local study = NS.SpecimenStudy
	NS.SpecimenStudy = function(self, npc)
		local st = study(self, npc)
		if tonumber(npc) == 3098 then st.mastered = true end
		return st
	end
	NS:ToggleJournal(true)
	NS:SelectJournalKind("menagerie")
	local f = NS.journalFrame
	f.menZone, f.menState = "all", "captured"
	NS:RefreshJournal()
	local rows = {}
	for _, row in ipairs(f.men.items) do if row.entry and row:IsShown() then rows[row.entry.npc] = row end end
	NS.SpecimenStudy = study
	local a, b = rows[3098], rows[3099]
	local ar, ag, br, bg
	if a then ar, ag = a.caught:GetVertexColor() end
	if b then br, bg = b.caught:GetVertexColor() end
	Check("[L36B] Créatures : liseré d'or pour l'espèce maîtrisée, vert sinon", a and b and a.caught:IsShown() and a.mastered
		and ar == Theme.GOLD[1] and ag == Theme.GOLD[2] and br == Theme.GREEN[1] and bg == Theme.GREEN[2] and not b.mastered)
	f:Hide()
	-- marque « Inséparable » : client, par référence ; lien 5 seulement
	local tile = CreateFrame("Frame", nil, UIParent)
	tile:SetSize(58, 84)
	NS.ReserveTileExtras(tile)
	local level = NS.SpecimenBondLevel
	local spec = NS:SpecimenAdd({ npc = 3098, stars = 3, name = "Créature", origin = "capture" })
	if type(spec) ~= "table" then spec = NS:SpecimenGet(spec) end
	NS.SpecimenBondLevel = function() return 5 end
	NS:ReserveTilePaintExtras(tile, spec)
	local shown = tile.inseparable:IsShown()
	NS.SpecimenBondLevel = function() return 4 end
	NS:ReserveTilePaintExtras(tile, spec)
	NS.SpecimenBondLevel = level
	Check("[L36B] vignette : marque « Inséparable » au lien 5 seulement (texture du client)", shown and not tile.inseparable:IsShown()
		and NS.RESERVE_ICONS.inseparable:find("^Interface\\Icons\\") ~= nil)
	-- fiche : maîtrisées, médailles, listes de fond et de cadre
	for index = 1, 45 do Caught(220000 + index, "Démon") end
	NS.trainerFrame = nil
	local frame = NS:TrainerOpen(nil)
	local species = frame.lines[2]:GetText() or ""
	local demon
	for _, medal in ipairs(frame.medals) do if medal.key == "demon" then demon = medal end end
	Check("[L36B] fiche : espèces maîtrisées sur la ligne des espèces, une médaille par type, listes Fond et Cadre",
		species:find("maîtrisées", 1, true) ~= nil and #frame.medals == #NS.CREATURE_TYPES and demon and demon.tier == 4
		and frame.bgStylePicker:IsShown() and frame.frameStylePicker:IsShown(), species)
	frame:Hide()
	NS.trainerFrame = nil
end
