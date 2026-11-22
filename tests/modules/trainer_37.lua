-- QuestCompanion 3.7.0, chantier D : fiche de dresseur et comparaison.
-- Rang sous le nom (bornes, fiche d'un autre), signature (texte et patte en
-- texture), marque « Pionnier » (tour de force fos_pioneer, ligne fabriquée
-- par le test si le catalogue ne l'a pas), pied (boutons de l'étape 3
-- seulement si leurs fonctions existent), champ de comparaison fb (aller et
-- retour, compatibilité avec une 3.6 dans les deux sens, taille d'une fiche
-- pleine), rang dans les bandeaux de guilde (champ 11), fenêtre de
-- comparaison (contenu, ordre, secrets, pied, bouton grisé, molette, Échap,
-- combat, compteur), neuf habillages (déclarés, nommés, textures, résolus
-- par le catalogue, cadres hors de la zone des textes, contrastes).
local Check, Say, ResetWorld, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local NS = QNS
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local function Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

local saved = { InCombatLockdown = rawget(_G, "InCombatLockdown"), UnitAffectingCombat = rawget(_G, "UnitAffectingCombat"),
	time = rawget(_G, "time"), TrainerCodeShow = rawget(NS, "TrainerCodeShow"), SouvenirShow = rawget(NS, "SouvenirShow") }
local combat = false

local function Reset()
	ResetWorld()
	NS:TrainerResetSession()
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	if NS.trainerCompareFrame then NS.trainerCompareFrame:Hide() end
	NS.trainerFrame = nil
	combat = false
	_G.InCombatLockdown = function() return combat end
	_G.UnitAffectingCombat = function() return combat end
	_G.time = function() return 1800000000 end
	NS.TrainerCodeShow, NS.SouvenirShow = nil, nil
end

-- une ligne du catalogue, fabriquée si absente (le catalogue complet arrive d'ailleurs)
local function Row(id, cat, pts, extra)
	local def = NS:FeatDef(id)
	if def then return def end
	local n = 980
	while NS:FeatDefByCode(n) do n = n + 1 end
	local row = { id, n, cat, pts, "account", crit = { "flag", "t37_" .. id } }
	for k, v in pairs(extra or {}) do row[k] = v end
	return NS.FeatAdd(row)
end

-- la fiche `text` reçue de `sender` (morceaux rejoués comme des messages d'addon)
local function Receive(text, sender)
	for _, chunk in ipairs(NS:TrainerChunks(text, 7)) do NS:TrainerOnAddonMessage("QCTrainer", chunk, "WHISPER", sender) end
	return NS:TrainerCard(sender)
end

local function Without(text, key)
	local parts = {}
	for pair in text:gmatch("[^;]+") do
		if not pair:find("^" .. key .. "=") then parts[#parts + 1] = pair end
	end
	return table.concat(parts, ";")
end

-- 1. Rang sous le nom ---------------------------------------------------------------------------
do
	Say("-- 3.7 D : rang sous le nom")
	Reset()
	local s = Steps()
	local function Text(account, char, count) return NS:TrainerCardFeatsText({ feats = { account = account, char = char, count = count } }) end
	s.ok("99 points : pas de rang", Text(99, 0, 4) == "99 points · 4 hauts faits", Text(99, 0, 4))
	s.ok("100 points : premier rang", Text(60, 40, 5) == NS.L.FEAT_RANK_1 .. " · 100 points · 5 hauts faits", Text(60, 40, 5))
	s.ok("1 240 points : Réputé, milliers séparés", Text(1000, 240, 142) == "Réputé · 1 240 points · 142 hauts faits", Text(1000, 240, 142))
	s.ok("4 000 points : dernier rang", Text(4000, 0, 300):find(NS.L.FEAT_RANK_8, 1, true) == 1, Text(4000, 0, 300))
	s.ok("aucun point : rien", Text(0, 0, 0) == "" and NS:TrainerCardFeatsText({}) == "")
	-- la fiche d'un autre : son rang se calcule de ses points
	local other = Receive("p=1;n=Xan;ap=1500;aq=10;ac=120;fb=", "Xan-Royaume")
	local heading, subtitle = NS:TrainerCardHeading(other, "Xan")
	s.ok("fiche reçue : rang de ses points", heading == "Xan" and subtitle == NS.L.FEAT_RANK_5 .. " · 1 510 points · 120 hauts faits", subtitle)
	-- ma fiche ouverte : sous le nom
	NS:FeatAward("men_first", { silent = true })
	local f = NS:TrainerOpen(nil)
	s.ok("ma fiche : points sans rang sous le nom", (f.header.subtitle.text or ""):find("points · 1 hauts faits", 1, true) ~= nil,
		f.header.subtitle.text)
	s.ok("en-tête des hauts faits : « (1 obtenus · N points) » (maquette)",
		(f.featsSection.detail.text or ""):find("^%(1 obtenus · %d+ points%)$") ~= nil, f.featsSection.detail.text)
	s.check("[T37] rang : « <rang> · <points> points · <n> hauts faits », sans rang sous 100, calculé des points reçus")
	f:Hide()
end

-- 2. Signature, Pionnier, pied ------------------------------------------------------------------
do
	Say("-- 3.7 D : signature, Pionnier, pied")
	Reset()
	local f = NS:TrainerOpen(nil)
	local glyph = f.signaturePaw:GetTexture()
	Check("[T37] signature : « QUEST COMPANION » atténué en haut à droite, la patte du logo en texture",
		f.signature.mockHidden ~= true and f.signature.text == "QUEST COMPANION" and glyph == (Theme.LOGO_GLYPH or Theme.LOGO_SMALL)
		and select(1, f.signature:GetPoint()) == "TOPRIGHT" and f.signaturePaw.mockHidden ~= true
		and not f.signature.text:find("[\226]"), tostring(glyph))
	local sig = {}
	for _, ground in ipairs({ "WINDOW", "NAV" }) do sig[#sig + 1] = Theme.Contrast(Theme.MUTED, Theme[ground]) end
	Check("[T37] signature : contraste ≥ 4,5 sur la fenêtre et la plaque de titre", sig[1] >= 4.5 and sig[2] >= 4.5,
		string.format("%.2f / %.2f", sig[1], sig[2]))
	f:Hide()

	-- Pionnier
	Reset()
	local pioneer = Row("fos_pioneer", "fos", 0)
	NS:CaptureData().creatures[7001] = { name = "Kodo", class = "normal", normal = true, at = 1790000000, firstAt = 1790000000 }
	f = NS:TrainerOpen(nil)
	local before = f.lines[1].text or ""
	NS:FeatAward(pioneer, { silent = true })
	NS:TrainerRefreshWindow()
	local after = f.lines[1].text or ""
	local s = Steps()
	s.ok("sans le tour de force : « Dresseur depuis le … » seul", before:find("^Dresseur depuis le ") and not before:find("Pionnier"), before)
	s.ok("avec : « · Pionnier »", after:find("^Dresseur depuis le .+ · Pionnier$") ~= nil, after)
	NS:FeatSetTitleForm("f")
	NS:TrainerRefreshWindow()
	s.ok("forme féminine : « Pionnière »", (f.lines[1].text or ""):find("Pionnière", 1, true) ~= nil, f.lines[1].text)
	NS:FeatSetTitleForm("auto")
	f:Hide()
	-- un autre dresseur : lu dans ses bits
	local bits = NS:FeatBits({ [tonumber(pioneer.n)] = true })
	local card = Receive("p=1;n=Xan;f=1790000000;fb=" .. bits, "Xan-Royaume")
	local old = Receive("p=1;n=Bob;f=1790000000", "Bob-Royaume")
	s.ok("autre dresseur : marque lue dans ses bits ; fiche de 3.6 : on ne sait pas", NS:TrainerCardHasFeat(card, "fos_pioneer") == true
		and NS:TrainerCardHasFeat(old, "fos_pioneer") == nil)
	NS:TrainerOpen("Xan")
	s.ok("fiche de Xan : « · Pionnier »", (NS.trainerFrame.lines[1].text or ""):find("Pionnier", 1, true) ~= nil, NS.trainerFrame.lines[1].text)
	NS:TrainerOpen("Bob")
	s.ok("fiche de Bob (3.6) : pas de marque", not (NS.trainerFrame.lines[1].text or ""):find("Pionnier", 1, true))
	s.check("[T37] Pionnier : marque après « Dresseur depuis le <date> », la mienne et celle lue dans les bits d'un autre")
	NS.trainerFrame:Hide()

	-- pied
	Reset()
	f = NS:TrainerOpen(nil)
	s = Steps()
	local _, closeAnchor = f.closeButton:GetPoint()
	s.ok("sans l'étape 3 : ni « Code de dresseur » ni « Carte souvenir »", not f.codeButton:IsShown() and not f.souvenirButton:IsShown()
		and f.formPicker:IsShown() and f.shareToggle:IsShown())
	local calls = {}
	NS.TrainerCodeShow = function() calls[#calls + 1] = "code" end
	NS.SouvenirShow = function() calls[#calls + 1] = "souvenir" end
	NS:TrainerRefreshWindow()
	local _, rel1 = f.souvenirButton:GetPoint()
	local _, rel2 = f.codeButton:GetPoint()
	f.codeButton:Click(); f.souvenirButton:Click()
	s.ok("avec : les deux boutons, à gauche de Fermer, dans cet ordre", f.codeButton:IsShown() and f.souvenirButton:IsShown()
		and rel1 == f.closeButton and rel2 == f.souvenirButton and f.codeButton.text.text == "Code de dresseur"
		and f.souvenirButton.text.text == "Carte souvenir" and table.concat(calls, ",") == "code,souvenir")
	Receive("p=1;n=Xan;fb=", "Xan-Royaume")
	NS:TrainerOpen("Xan")
	s.ok("fiche d'un autre : pas ces boutons", not f.codeButton:IsShown() and not f.souvenirButton:IsShown() and f.compareButton:IsShown())
	s.check("[T37] pied : les boutons de l'étape 3 n'apparaissent que si leurs fonctions existent, sur ma fiche")
	f:Hide()
end

-- 3. Champ de comparaison : aller-retour, 3.6 dans les deux sens, taille ----------------------------
do
	Say("-- 3.7 D : champ de comparaison")
	Reset()
	NS:FeatAward("men_first", { silent = true })
	local card = NS:TrainerOwnCard()
	local text = NS:TrainerSerializeCard(card)
	local fields = NS.TrainerDecode(text)
	local back = NS:TrainerParseCard(text)
	local first = NS:FeatDef("men_first")
	local s = Steps()
	s.ok("ma fiche porte fb = ns:FeatBits()", fields.fb == NS:FeatBits() and card.featBits == NS:FeatBits() and fields.fb ~= "")
	s.ok("relue : mêmes bits, men_first dedans", back.featBits == fields.fb and NS:FeatBitsDecode(back.featBits)[tonumber(first.n)])
	-- rien d'obtenu : « fb= » (une fiche de 3.7 quand même)
	local empty = NS:TrainerSerializeCard({ name = "Z", showcase = {}, badges = {}, featBits = "" })
	s.ok("rien d'obtenu : « fb= », relu vide (pas absent)", empty:find("fb=", 1, true) ~= nil and NS:TrainerParseCard(empty).featBits == "")
	-- piégé : caractères hors alphabet, trop long
	s.ok("bits piégés ou trop longs : écartés", NS:TrainerParseCard("p=1;n=E;fb=AB%3Bc").featBits == nil
		and NS:TrainerParseCard("p=1;n=E;fb=" .. string.rep("A", NS.TRAINER_BITS_MAX + 1)).featBits == nil
		and NS:TrainerParseCard("p=1;n=E;fb=" .. string.rep("_", NS.TRAINER_BITS_MAX)).featBits ~= nil)
	s.check("[T37] champ fb : aller-retour, vide permis, contenu piégé écarté")

	-- une 3.6 lit ma fiche : décodeur sans liste de clés (les clés inconnues restent à part),
	-- l'alphabet des bits n'a aucun caractère réservé ; tout le reste se relit à l'identique
	s = Steps()
	local stripped = Without(text, "fb")
	local a, b = NS:TrainerParseCard(stripped), NS:TrainerParseCard(text)
	local same = true
	for key, value in pairs(a) do
		if key ~= "featBits" and type(value) ~= "table" and b[key] ~= value then same = false end
	end
	local decoded, keys = NS.TrainerDecode(text), 0
	for key in pairs(decoded) do if key ~= "fb" then keys = keys + 1 end end
	local strippedKeys = 0
	for _ in pairs(NS.TrainerDecode(stripped)) do strippedKeys = strippedKeys + 1 end
	s.ok("mêmes champs sans fb", same and keys == strippedKeys)
	s.ok("alphabet des bits sans caractère réservé (; = , ~ | : %)", not NS.FEAT_BITS_ALPHABET:find("[;=,~|:%%]"))
	-- une fiche de 3.6 (sans fb) reste lisible ici : pas de bits, le reste lu
	local old = NS:TrainerParseCard("p=1;n=Bob;sp=10;st=3128;ap=50;aq=0;ac=3")
	s.ok("fiche de 3.6 : lue, sans bits", old.featBits == nil and old.species == 10 and old.feats.account == 50)
	s.check("[T37] compatibilité 3.6 : ma fiche se lit à l'identique sans fb, la sienne se lit ici sans bits")

	-- taille d'une fiche pleine, découpage et débit inchangés
	local codes = {}
	for n = 1, 450 do codes[n] = true end
	local full = { proto = 1, name = "Abcdefghijkl-Royaumeimmense", title = string.rep("é", 30),
		titleCode = 200, gender = "f", first = 1790000000, species = 3128, total = 3128, shinies = 999, shinySeen = 999, seals = 120,
		feats = { account = 99999, char = 99999, count = 450 }, showcase = {}, badges = { ek = 60, ka = 55, other = 5 },
		companion = { name = string.rep("n", 48), npc = 123456, display = 123456, class = "rareelite", shiny = true, stars = 3,
			typeKey = "elemental", strength = 0.125, huntId = "capture_all", huntValue = 0.06, comfortId = "decay_slow", comfortValue = 0.12 },
		featShowcase = {}, featCats = { men = 999, shiny = 999, zone = 999, char = 999 }, styleBg = "card_directory",
		styleFrame = "card_rank_glow", mastered = 99999, medals = {}, featBits = NS:FeatBits(codes) }
	for slot = 1, 3 do
		full.showcase[slot] = { npc = 123450 + slot, shiny = true, stars = 3, class = "rareelite", typeKey = "elemental",
			name = string.rep("m", 48) }
		full.featShowcase[slot] = { n = 440 + slot, at = 1799999999 }
	end
	for _, key in ipairs(NS.CREATURE_TYPES) do full.medals[key] = 5 end
	local fullText = NS:TrainerSerializeCard(full)
	local chunks = NS:TrainerChunks(fullText, 999)
	local before = NS:TrainerChunks(Without(fullText, "fb"), 999)
	local longest = 0
	for _, chunk in ipairs(chunks) do longest = math.max(longest, #chunk) end
	local bits = #NS:FeatBits(codes)
	-- une fiche courante : la mienne, un haut fait, une capture
	local usual = NS:TrainerSerializeCard(card)
	Say(string.format("   fiche pleine (tous les champs au maximum) : %d octets (dont « fb=… » %d), %d messages (%d sans fb), le plus long %d octets ; "
		.. "fiche courante : %d octets, %d message(s)", #fullText, bits + 4, #chunks, #before, longest, #usual, #NS:TrainerChunks(usual, 1)))
	Check("[T37] taille : fiche pleine avec fb (75 caractères) : un message de plus au plus, partie d'une seule rafale "
		.. "(≤ 6 messages de 255 octets au plus), débit inchangé (morceaux de 200, seau 6, 1/s)",
		bits == 75 and #chunks <= #before + 1 and #chunks <= NS.TRAINER_BURST and longest <= NS.TRAINER_MAX_MSG
		and NS.TRAINER_CHUNK == 200 and NS.TRAINER_BURST == 6 and NS.TRAINER_RATE == 1,
		#fullText .. " octets, " .. #chunks .. " messages")
end

-- 4. Rang dans les bandeaux de guilde ------------------------------------------------------------
do
	Say("-- 3.7 D : rang dans les bandeaux de guilde")
	Reset()
	local s = Steps()
	local feat = { kind = "s", id = 3098, zone = 1411, stars = 2, class = "normal" }
	local low = NS:GuildFeatMessage(feat, 1, nil, nil, 99)
	local plain = NS:GuildFeatMessage(feat, 1, nil, nil, 1240)
	local titled = NS:GuildFeatMessage(feat, 1, 13, "f", 1240)
	s.ok("sous 100 points : message d'avant", table.concat(low, "~") == "s~3098~1411~2~normal~1")
	s.ok("sans titre : champs 9 et 10 vides, puis les points", table.concat(plain, "~") == "s~3098~1411~2~normal~1~~~1240",
		table.concat(plain, "~"))
	s.ok("avec titre : titre puis points", table.concat(titled, "~") == "s~3098~1411~2~normal~1~13~f~1240")
	local parsed = NS:GuildFeatParse("E~1~" .. table.concat(plain, "~"))
	local parsedT = NS:GuildFeatParse("E~1~" .. table.concat(titled, "~"))
	local before = NS:GuildFeatParse("E~1~s~3098~1411~2~normal~1")
	s.ok("relu : points en fp, pas de titre fantôme", parsed and parsed.fp == 1240 and parsed.ti == nil and parsedT.fp == 1240
		and parsedT.ti == 13 and before.fp == nil)
	-- une 3.6 : même lecture des dix premiers champs (le champ 11 lui est inconnu)
	s.ok("une 3.6 lit les dix premiers champs comme avant", parsed.kind == before.kind and parsed.id == before.id
		and parsed.more == before.more and parsed.stars == before.stars)
	local first = NS:FeatDef("men_first")
	local info = NS:GuildFeatDescribe({ kind = "h", id = tonumber(first.n), zone = 0, stars = 0, more = 0, fp = 1240 }, "Xan-Royaume")
	local none = NS:GuildFeatDescribe({ kind = "h", id = tonumber(first.n), zone = 0, stars = 0, more = 0 }, "Xan-Royaume")
	s.ok("bandeau : le rang après le nom", info and info.line:find("^Xan %(Réputé%) a obtenu") ~= nil, info and info.line)
	s.ok("sans points : le nom seul", none and none.line:find("^Xan a obtenu") ~= nil, none and none.line)
	s.check("[T37] guilde : points en champ 11 (rang ≥ 100), tolérés d'une 3.6, rang dit après le nom")
end

-- 5. Comparaison --------------------------------------------------------------------------------
do
	Say("-- 3.7 D : comparaison")
	Reset()
	-- lignes fabriquées : une que j'ai, une qu'il a, un secret qu'il a, un secret que j'ai,
	-- une en attente qu'il a, un tour de force qu'il a
	local mine = Row("t37_mine", "fun", 10)
	local theirs = Row("t37_theirs", "fun", 10)
	local secret = Row("t37_secret", "fun", 10, { hidden = true })
	local mySecret = Row("t37_mysecret", "fun", 10, { hidden = true })
	local pending = Row("t37_pending", "fun", 10, { pending = true })
	local fos = Row("t37_fos", "fos", 0)
	NS:FeatAward(mine, { silent = true })
	NS:FeatAward(mySecret, { silent = true })
	local set = { [tonumber(theirs.n)] = true, [tonumber(secret.n)] = true, [tonumber(pending.n)] = true, [tonumber(fos.n)] = true }
	Receive("p=1;n=Xan;ti=;fb=" .. NS:FeatBits(set), "Xan-Royaume")
	local f = NS:TrainerOpen("Xan")
	local s = Steps()
	s.ok("bouton « Comparer les hauts faits » actif", f.compareButton:IsShown() and not f.compareButton.inactive
		and f.compareButton.text.text == "Comparer les hauts faits")
	local tally = NS.TallyGet and NS:TallyGet("compare") or 0
	f.compareButton:Click()
	local w = NS.trainerCompareFrame
	s.ok("ouverte par le bouton", w and w:IsShown() and w.viewing == "Xan-Royaume")
	s.ok("compteur « compare » +1", not NS.TallyGet or NS:TallyGet("compare") == tally + 1)
	local data = w.data
	local rows = {}
	for _, family in ipairs(data.families) do
		for _, row in ipairs(family.rows) do rows[#rows + 1] = row.def.id end
	end
	local list = table.concat(rows, ",")
	s.ok("lignes : ce qui me manque d'abord (dont le secret), puis le mien ; ni en attente ni tour de force",
		list:find("t37_theirs", 1, true) and list:find("t37_secret", 1, true) and list:find("t37_mine", 1, true)
		and list:find("t37_mysecret", 1, true) and not list:find("t37_pending", 1, true) and not list:find("t37_fos", 1, true)
		and list:find("t37_secret", 1, true) < list:find("t37_mine", 1, true), list)
	-- l'écran : titre, sous-titre, sections, cellules
	s.ok("titre et sous-titre", w.header.title.text == "Comparer les hauts faits"
		and (w.header.subtitle.text or ""):find("^Toi et Xan · fiche reçue le ") ~= nil, w.header.subtitle.text)
	local header, secretSlot, mineSlot, theirsSlot
	for _, slot in ipairs(w.slots) do
		local item = slot.item
		if slot:IsShown() and item then
			if item.header and not header then header = slot end
			if not item.header and item.def == secret then secretSlot = slot end
			if not item.header and item.def == mine then mineSlot = slot end
			if not item.header and item.def == theirs then theirsSlot = slot end
		end
	end
	s.ok("section « DRESSEUR · <n> HAUTS FAITS COMPARÉS », colonnes TOI et XAN", header
		and header.section.label.text:find("^DRESSEUR · %d+ HAUTS FAITS COMPARÉS$") ~= nil
		and header.meTag.label.text == "TOI" and header.themTag.label.text == "XAN", header and header.section.label.text)
	s.ok("ma ligne : case cochée chez moi, tiret chez lui", mineSlot and mineSlot.mine.value == "check"
		and mineSlot.mine.check:IsShown() and mineSlot.theirs.value == "—")
	s.ok("la sienne : ma progression « 0 / 1 », case cochée chez lui", theirsSlot and theirsSlot.mine.value == "0 / 1"
		and theirsSlot.theirs.value == "check" and theirsSlot.theirs.check:IsShown())
	local leak = false
	for _, slot in ipairs(w.slots) do
		for _, fs in ipairs({ slot.name, slot.desc }) do
			if (fs.text or ""):find(NS.L["FEAT_t37_secret"] or "\0", 1, true) then leak = true end
		end
	end
	s.ok("secret non découvert : « Un secret du compagnon », sans condition ni progression", secretSlot
		and secretSlot.name.text == "Un secret du compagnon" and secretSlot.desc.text == "" and secretSlot.mine.value == "—" and not leak)
	-- la case cochée est une texture, jamais un glyphe
	s.ok("case cochée : texture du client", mineSlot and mineSlot.mine.check.mark:GetTexture() == Theme.CHECK_FILE)
	s.ok("pied : tournure neutre", w.summary.text == string.format("Toi %d · Xan %d · %d chez Xan seulement · %d chez toi seulement",
		data.mine, data.theirs, data.onlyTheirs, data.onlyMine) and data.onlyTheirs >= 2 and data.onlyMine >= 2, w.summary.text)
	s.ok("boutons « Voir sa fiche » et « Fermer »", w.cardButton.text.text == "Voir sa fiche" and w.closeButton.mockHidden ~= true
		and w.closeButton.text.text == NS.L.OPT_CLOSE)
	s.check("[T37] comparaison : lignes, ordre, colonnes, secret sans fuite, pied neutre, compteur")

	-- molette, Échap, Voir sa fiche, combat
	s = Steps()
	for index = 1, 12 do NS:FeatAward(Row("t37_more" .. index, "fun", 5), { silent = true }) end
	NS:TrainerCompareOpen("Xan-Royaume")
	local firstItem = w.slots[1].item
	local moved = NS:TrainerCompareScroll(1)
	s.ok("molette : la liste descend d'un cran, bornée", moved and w.slots[1].item ~= firstItem and w.offset == 1
		and not NS:TrainerCompareScroll(-5) == false and w.offset == 0)
	for _ = 1, 50 do NS:TrainerCompareScroll(1) end
	s.ok("molette : jamais au-delà de la dernière ligne", w.offset == w.maxOffset and w.slots[#w.slots]:IsShown())
	local escape = false
	for _, name in ipairs(UISpecialFrames or {}) do if name == "QuestCompanionTrainerCompare" then escape = true end end
	s.ok("Échap ferme (nom global dans UISpecialFrames)", escape and w:GetName() == "QuestCompanionTrainerCompare")
	w.cardButton:Click()
	s.ok("« Voir sa fiche » : la comparaison se ferme, la fiche s'ouvre", not w:IsShown() and NS.trainerFrame:IsShown()
		and NS.trainerFrame.viewing == "Xan-Royaume")
	NS:TrainerCompareOpen("Xan-Royaume")
	combat = true
	w:GetScript("OnEvent")(w, "PLAYER_REGEN_DISABLED")
	s.ok("combat : fermée", not w:IsShown())
	s.ok("combat : ne s'ouvre pas", NS:TrainerCompareOpen("Xan-Royaume") == nil and not w:IsShown())
	combat = false
	s.check("[T37] comparaison : molette, Échap, « Voir sa fiche », fermée et refusée en combat")

	-- fiche de 3.6 : bouton grisé, son infobulle dit pourquoi
	s = Steps()
	Receive("p=1;n=Bob;ap=10;aq=0;ac=1", "Bob-Royaume")
	f = NS:TrainerOpen("Bob")
	f.compareButton:Click()
	s.ok("grisé, avec la raison", f.compareButton:IsShown() and f.compareButton.inactive
		and f.compareButton.disabledTip == "Sa version de Quest Companion ne permet pas encore de comparer les hauts faits.")
	s.ok("clic sans effet", not w:IsShown() and NS:TrainerCompareOpen("Bob-Royaume") == nil)
	s.check("[T37] fiche de 3.6 : « Comparer » grisé, infobulle « sa version ne le permet pas »")
	f:Hide()

	-- contrastes de la fenêtre (encre sur son fond réel)
	local bad, worst = {}, 99
	for _, skin in ipairs({ "sobre", "azeroth" }) do
		Theme.ApplySkin(skin)
		for _, pair in ipairs({ { "LABEL", "ROW", 4.5 }, { "LABEL", "ROW_ALT", 4.5 }, { "MUTED_LIGHT", "ROW", 4.5 },
			{ "MUTED_LIGHT", "ROW_ALT", 4.5 }, { "MUTED_LIGHT", "WINDOW", 4.5 }, { "GREEN", "ROW", 3 }, { "BLUE", "WINDOW", 3 },
			{ "TITLE", "NAV", 3 }, { "MUTED_LIGHT", "NAV", 4.5 } }) do
			local c = Theme.Contrast(Theme[pair[1]], Theme[pair[2]])
			worst = math.min(worst, c)
			if c < pair[3] then bad[#bad + 1] = string.format("%s %s/%s %.2f", skin, pair[1], pair[2], c) end
		end
	end
	Theme.ApplySkin(NS:UISkinChoice())
	Check("[T37] comparaison : contrastes ≥ 4,5 (texte), ≥ 3 (titres, case, étiquettes), deux styles", #bad == 0,
		table.concat(bad, ", ") .. string.format(" (pire %.2f)", worst))
end

-- 6. Neuf habillages -----------------------------------------------------------------------------
do
	Say("-- 3.7 D : neuf habillages de fiche")
	Reset()
	local NEW = { cardframe = { "card_rank_bronze", "card_rank_silver", "card_rank_gold", "card_rank_glow", "card_eight", "card_prism" },
		cardbg = { "card_zoology", "card_gold_zones", "card_directory" } }
	local strings = NS.TRAINER_STYLE_STRINGS or {}
	local src = Read("tools/gen_ui_assets.py") or ""
	local s = Steps()
	for kind, ids in pairs(NEW) do
		for _, id in ipairs(ids) do
			local def = NS.TrainerCardStyleDef(kind, id)
			if not def then s.ok(id .. " déclaré", false) else
				s.ok(id .. " nommé FR/EN", strings.fr and strings.fr[def.label] and strings.en and strings.en[def.label]
					and strings.fr[def.name] and strings.en[def.name] and strings.fr[def.name] ~= strings.en[def.name] or id == "card_prism")
				for _, addon in ipairs({ "Ready2Quest", "QuestCompanion" }) do
					s.ok(id .. " texture " .. addon, Read(addon .. "/Libs/Socle/Media/" .. def.tex .. ".tga") ~= nil)
				end
				s.ok(id .. " générée par le script", src:find('("' .. def.tex .. '"', 1, true) ~= nil)
				s.ok(id .. " haut fait", type(def.unlock) == "table" and type(def.unlock.feat) == "string")
			end
		end
	end
	s.ok("aucune image du jeu dans le script", src:find("Interface", 1, true) == nil)
	s.check("[T37] habillages : neuf déclarés (6 cadres, 3 fonds), nommés FR/EN, textures générées dans les deux socles")

	-- résolus par le catalogue : une récompense promise (reward.soon) devient réelle ; le haut fait débloque
	s = Steps()
	for kind, ids in pairs(NEW) do
		for _, id in ipairs(ids) do
			local def = NS.TrainerCardStyleDef(kind, id)
			local fd = NS:FeatDef(def.unlock.feat)
			if fd and fd.reward and (fd.reward.soon or fd.reward.cosmetic) then
				local c = fd.reward.cosmetic
				s.ok(id .. " : récompense du catalogue réelle", not fd.reward.soon and c and c[1] == kind and c[2] == id)
			end
		end
	end
	local promised = Row("t37_promise", "fun", 10, { reward = { soon = { "cardframe", "card_rank_bronze" } } })
	NS.FeatResolveSoon()
	s.ok("reward.soon → reward.cosmetic", promised.reward.soon == nil and promised.reward.cosmetic
		and promised.reward.cosmetic[2] == "card_rank_bronze")
	s.ok("libellé de récompense : le nom, pas « à venir »", (NS:FeatRewardText(promised) or ""):find("Rang de bronze", 1, true) ~= nil,
		NS:FeatRewardText(promised))
	s.ok("pas gagné : refusé", NS:TrainerCardStyleSet("cardframe", "card_rank_bronze") == false)
	NS:FeatGrant(promised)
	s.ok("gagné : choisi, porté par ma fiche, partagé et relu", NS:TrainerCardStyleSet("cardframe", "card_rank_bronze")
		and NS:TrainerOwnCard().styleFrame == "card_rank_bronze"
		and NS:TrainerParseCard(NS:TrainerSerializeCard(NS:TrainerOwnCard())).styleFrame == "card_rank_bronze")
	s.check("[T37] habillages : résolus par le catalogue (reward.soon), débloqués par le haut fait, partagés")

	-- cadres : rien de peint là où se pose le texte de la fiche (au-delà de 12 px du bord, hors carré de coin de 19 px)
	local function Pixels(path)
		local data = Read(path)
		if not data or #data < 18 then return nil end
		local w, h = data:byte(13) + 256 * data:byte(14), data:byte(15) + 256 * data:byte(16)
		return data, w, h
	end
	local bad = {}
	for _, id in ipairs(NEW.cardframe) do
		local def = NS.TrainerCardStyleDef("cardframe", id)
		local data, w, h = Pixels("QuestCompanion/Libs/Socle/Media/" .. def.tex .. ".tga")
		if not data then bad[#bad + 1] = id .. " illisible" else
			local over = 0
			for i = 0, w * h - 1 do
				local x, y = i % w, math.floor(i / w)
				local ex, ey = math.min(x + 0.5, w - x - 0.5), math.min(y + 0.5, h - y - 0.5)
				local alpha = data:byte(19 + i * 4 + 3)
				if alpha > 8 and math.min(ex, ey) >= 12 and not (ex < 19 and ey < 19) then over = over + 1 end
			end
			if over > 0 then bad[#bad + 1] = id .. " " .. over .. " px" end
		end
	end
	Check("[T37] cadres : aucun pixel peint dans la zone des textes de la fiche (≥ 12 px du bord, hors coins) : le texte reste sur le fond",
		#bad == 0, table.concat(bad, ", "))

	-- fonds : texte de la fiche au pixel le plus clair, deux styles
	local function Brightest(path)
		local data, w, h = Pixels(path)
		if not data then return nil end
		local best, bestL = nil, -1
		for i = 0, w * h - 1 do
			local o = 19 + i * 4
			local c = { data:byte(o + 2) / 255, data:byte(o + 1) / 255, data:byte(o) / 255 }
			local l = Theme.Luminance(c)
			if l > bestL then best, bestL = c, l end
		end
		return best
	end
	bad = {}
	local worst = {}
	for _, skin in ipairs({ "sobre", "azeroth" }) do
		Theme.ApplySkin(skin)
		for _, id in ipairs(NEW.cardbg) do
			local def = NS.TrainerCardStyleDef("cardbg", id)
			local light = Brightest("QuestCompanion/Libs/Socle/Media/" .. def.tex .. ".tga")
			worst[id] = worst[id] or { 99, "" }
			for _, ink in ipairs({ "TEXT", "MUTED_LIGHT", "MUTED", "LABEL", "PARCHMENT", "GOLD", "GOLD_LIGHT", "TITLE", "IDENTITY", "GOLD_SOFT" }) do
				if Theme[ink] and light then
					local c = Theme.Contrast(Theme[ink], light)
					local need = (ink == "TITLE" or ink == "IDENTITY" or ink == "GOLD_SOFT") and 3 or 4.5
					if c < worst[id][1] and need == 4.5 then worst[id] = { c, ink } end
					if c < need then bad[#bad + 1] = string.format("%s %s %s %.2f", skin, id, ink, c) end
				end
			end
		end
	end
	Theme.ApplySkin(NS:UISkinChoice())
	local report = {}
	for _, id in ipairs(NEW.cardbg) do report[#report + 1] = string.format("%s %.2f (%s)", id, worst[id][1], worst[id][2]) end
	Say("   contrastes les plus faibles : " .. table.concat(report, ", "))
	Check("[T37] fonds neufs : texte de la fiche ≥ 4,5 (titres ≥ 3) au pixel le plus clair, deux styles", #bad == 0,
		table.concat(bad, ", "))
end

_G.InCombatLockdown, _G.UnitAffectingCombat, _G.time = saved.InCombatLockdown, saved.UnitAffectingCombat, saved.time
NS.TrainerCodeShow, NS.SouvenirShow = saved.TrainerCodeShow, saved.SouvenirShow
