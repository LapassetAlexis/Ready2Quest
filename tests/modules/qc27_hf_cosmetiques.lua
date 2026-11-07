-- QuestCompanion 2.7.x, lot E des hauts faits : cosmétiques gagnés par les
-- hauts faits (FeatsCosmetics.lua). Catalogue et textures sur le disque,
-- déblocage par le haut fait (et seulement lui), choix et rendu dans les deux
-- styles (Sobre : décor du cadre carré ; Azeroth : autour de l'anneau), texte
-- de condition « Haut fait : … », récompenses de la fiche de dresseur
-- reportées (jamais un id brut), sortie déterministe du générateur.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

-- empreintes des TGA écrits par tools/gen_feat_cosmetics.py (taille, Adler-32) :
-- python3 -I tools/gen_feat_cosmetics.py --empreintes ; relancer le générateur
-- doit redonner exactement ces octets
local PRINTS = {
	["feat_atlas.tga"]     = { 196626, 1326092886 },
	["feat_campfire.tga"]  = { 196626, 3187426133 },
	["feat_ornaments.tga"] = { 131090, 2816338184 },
}
local EXPECTED = {
	{ "frame", "feat_eight", "men_types_master" },
	{ "frame", "feat_prism", "meta_shiny" },
	{ "bg", "feat_atlas", "zone_100_10" },
	{ "bg", "feat_campfire", "char_camp_25" },
	{ "orn", "feat_chain", "men_boss_1" },
	{ "orn", "feat_goldstars", "men_stars3_100" },
	{ "orn", "feat_prism_orn", "shiny_3stars" },
	{ "orn", "feat_compass", "day_travel_1000" },
	{ "orn", "feat_anniversary", "day_days_365" },
	{ "orn", "feat_eye", "dng_raid_aq40" },
	{ "orn", "feat_wildcrown", "dng_raid_hyjal" },
}
local LISTS = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS" }
local function Def(kind, id)
	for _, def in ipairs(NS[LISTS[kind]] or {}) do if def.id == id then return def end end
	return nil
end

local function ReadFile(path)
	local h = io.open(ROOT .. "/" .. path, "rb")
	if not h then return nil end
	local data = h:read("*a")
	h:close()
	return data
end

local function Adler32(data)
	local a, b = 1, 0
	local MOD = 65521
	local len = #data
	local i = 1
	while i <= len do
		local j = math.min(i + 3999, len)
		local bytes = { data:byte(i, j) }
		for k = 1, #bytes do
			a = a + bytes[k]
			b = b + a
		end
		a, b = a % MOD, b % MOD
		i = j + 1
	end
	return b * 65536 + a
end

local function U16(data, pos) local lo, hi = data:byte(pos, pos + 1); return lo + hi * 256 end

local FIELDS = { "companionFrame", "companionBubble", "companionHover" }
local function Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:SetUIStyle(style or "sobre")
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
	return NS:EnsureCompanionFrame()
end

-- 1. Catalogue, chaînes et textures -------------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot E : catalogue et textures")
	local bad = {}
	local fr, en = NS.FEAT_COSMETIC_STRINGS.fr, NS.FEAT_COSMETIC_STRINGS.en
	for _, row in ipairs(EXPECTED) do
		local kind, id, feat = row[1], row[2], row[3]
		local def = Def(kind, id)
		local function Bad(why) bad[#bad + 1] = kind .. ":" .. id .. " " .. why end
		if not def then Bad("absent") else
			if def.tier ~= 0 then Bad("palier") end
			if not (def.unlock and def.unlock.feat == feat) then Bad("condition") end
			if not (fr[def.label] and en[def.label] and NS.COMPANION_STRINGS.fr[def.label]) then Bad("libellé") end
			local fd = NS:FeatDef(feat)
			local c = fd and fd.reward and fd.reward.cosmetic
			if not (c and c[1] == kind and c[2] == id) then Bad("haut fait " .. feat) end
			if fd and fd.reward.soon then Bad("encore en attente") end
			if kind == "orn" and not (def.key and NS:DB()[def.key] ~= nil and def.cell and def.at) then Bad("ornement") end
		end
	end
	Check("[HF-E] 11 cosmétiques : catalogue, palier 0, libellés FR/EN, donnés par leur haut fait", #bad == 0,
		table.concat(bad, ", "))
	local chest = {}
	for _, reward in ipairs(NS.COMPANION_REWARDS or {}) do chest[reward.kind .. ":" .. reward.id] = true end
	local inChest = false
	for _, row in ipairs(EXPECTED) do if chest[row[1] .. ":" .. row[2]] then inChest = true end end
	Check("[HF-E] jamais au coffre de zone", not inChest)
	Check("[HF-E] noms : « Cadre des huit familles », « Prismatic Frame », « Œil clos »",
		fr.COMP_FRAME_FEAT_EIGHT == "Cadre des huit familles" and en.COMP_FRAME_FEAT_PRISM == "Prismatic Frame"
		and fr.COMP_ORN_FEAT_EYE == "Œil clos")
	local parity = {}
	for key in pairs(fr) do if en[key] == nil then parity[#parity + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then parity[#parity + 1] = key end end
	Check("[HF-E] chaînes : mêmes clés en français et en anglais", #parity == 0, table.concat(parity, ", "))

	-- textures : sur le disque, TGA non compressés, puissances de deux, alpha pour la feuille
	local texBad, total = {}, 0
	for _, name in ipairs(NS.FEAT_COSMETIC_TEXTURES) do
		local data = ReadFile("QuestCompanion/Textures/" .. name .. ".tga")
		if not data then texBad[#texBad + 1] = name .. " absent" else
			total = total + #data
			local w, h, bpp = U16(data, 13), U16(data, 15), data:byte(17)
			local pow2 = function(n) local p = 1; while p < n do p = p * 2 end; return p == n end
			if data:byte(3) ~= 2 or not (pow2(w) and pow2(h)) then texBad[#texBad + 1] = name .. " format" end
			if #data ~= 18 + w * h * bpp / 8 then texBad[#texBad + 1] = name .. " taille" end
			if name == "feat_ornaments" and not (bpp == 32 and w == 512 and h == 64) then texBad[#texBad + 1] = name .. " alpha" end
			local print = PRINTS[name .. ".tga"]
			if not (print and print[1] == #data and print[2] == Adler32(data)) then
				texBad[#texBad + 1] = name .. " empreinte " .. Adler32(data)
			end
		end
	end
	Check("[HF-E] textures : sur le disque, TGA non compressés, puissances de deux, empreintes du générateur",
		#texBad == 0, table.concat(texBad, ", "))
	Check("[HF-E] budget : moins de 600 Ko de textures neuves", total > 0 and total < 600 * 1024, total)
	local bgPaths = true
	for _, id in ipairs({ "feat_atlas", "feat_campfire" }) do
		local def = Def("bg", id)
		if not (def and def.texture and def.texture:find("Textures\\" .. id, 1, true)) then bgPaths = false end
	end
	Check("[HF-E] fonds : nos textures (aucune image de Blizzard embarquée)", bgPaths)
	-- le générateur : ses sorties sont celles du dépôt (déterministe : graines fixes, pas d'aléa)
	local gen = ReadFile("tools/gen_feat_cosmetics.py") or ""
	Check("[HF-E] générateur : outil déterministe, mêmes fichiers", gen:find("RandomState", 1, true) ~= nil
		and not gen:find("random%.random%(") and gen:find("feat_ornaments.tga", 1, true) ~= nil)
	local toc = ReadFile("QuestCompanion/QuestCompanion.toc") or ""
	Check("[HF-E] .toc : chargé juste après Feats.lua", toc:find("\nFeats.lua\r?\nFeatsCosmetics.lua\r?\n") ~= nil)
end

-- 2. Déblocage par le haut fait, condition lisible ------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot E : déblocage")
	Reset("sobre")
	local locked = true
	for _, row in ipairs(EXPECTED) do
		if NS:CompanionIsUnlocked(row[1], Def(row[1], row[2])) then locked = false end
	end
	Check("[HF-E] rien de gagné d'office", locked)
	NS:CompanionCheckUnlocks(60, true)
	local still = true
	for _, row in ipairs(EXPECTED) do
		if NS:CompanionIsUnlocked(row[1], Def(row[1], row[2])) then still = false end
	end
	Check("[HF-E] ni le niveau ni les tampons ne les donnent", still)
	local def = Def("frame", "feat_eight")
	Check("[HF-E] condition : « Haut fait : Les huit familles »",
		NS:CompanionLockText(def) == "Haut fait : " .. NS:FeatName("men_types_master")
		and NS:FeatName("men_types_master") == "Les huit familles", NS:CompanionLockText(def))
	local entry = { def = Def("orn", "feat_eye"), tier = 0 }
	Check("[HF-E] carnet : la source dit le haut fait", NS:JournalCosmeticSource(entry) == "Haut fait : L'œil se ferme",
		NS:JournalCosmeticSource(entry))
	local choices = NS:CompanionChoices("bg")
	local hint
	for _, c in ipairs(choices) do if c.value == "feat_atlas" then hint = c.disabled and c.hint end end
	Check("[HF-E] liste des fonds : l'Atlas grisé, avec sa condition", hint == "Haut fait : Dix zones accomplies", tostring(hint))
	Check("[HF-E] choix refusé tant que non gagné", NS:CompanionSetStyle("bg", "feat_atlas") == nil)

	local given = NS:FeatGrant(NS:FeatDef("zone_100_10"))
	Check("[HF-E] le haut fait donne le fond", given[1] == "bg:feat_atlas" and NS:CompanionIsUnlocked("bg", Def("bg", "feat_atlas")))
	local all = true
	for _, row in ipairs(EXPECTED) do
		NS:FeatGrant(NS:FeatDef(row[3]))
		if not NS:CompanionIsUnlocked(row[1], Def(row[1], row[2])) then all = false end
	end
	Check("[HF-E] chaque haut fait débloque son cosmétique", all)
	Check("[HF-E] donné deux fois : rien de neuf", #NS:FeatGrant(NS:FeatDef("men_boss_1"), { cosmeticsOnly = true }) == 0)
	ResetWorld()
end

-- 3. Choix et rendu, style Sobre ------------------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot E : rendu Sobre")
	local frame = Reset("sobre")
	for _, row in ipairs(EXPECTED) do NS:FeatGrant(NS:FeatDef(row[3])) end
	Check("[HF-E] fond Atlas porté : notre texture, recadrée au format du cadre",
		NS:CompanionSetStyle("bg", "feat_atlas") ~= nil and frame.bgTexture:find("feat_atlas", 1, true)
		and frame.bgCoords and frame.bgCoords[1] == 0.06 and not frame.bgFallback)
	NS:CompanionSetStyle("bg", "feat_campfire")
	Check("[HF-E] fond Feu de camp porté", frame.bgStyle == "feat_campfire" and frame.bgTexture:find("feat_campfire", 1, true))
	NS:CompanionSetStyle("frame", "feat_eight")
	local holder = frame.featDeco
	local shown, colors = 0, {}
	for _, d in ipairs(holder and holder.eight or {}) do
		if d:IsShown() then shown = shown + 1 end
		colors[(d.vertex and d.vertex[1] or 0) .. ":" .. (d.vertex and d.vertex[3] or 0)] = true
	end
	local distinct = 0
	for _ in pairs(colors) do distinct = distinct + 1 end
	Check("[HF-E] cadre des huit familles : bordure dorée et huit losanges de couleurs différentes",
		frame.frameStyle == "feat_eight" and frame.frameBackdrop == true and shown == 8 and distinct == 8)
	local p, rel, rp = holder.eight[1]:GetPoint()
	Check("[HF-E] Sobre : les losanges sur le cadre carré (coins et milieux)", p == "CENTER" and rel == frame and rp == "TOPLEFT")
	Check("[HF-E] décor au-dessus de l'habillage (niveau + 6)", holder.level == (frame.level or 0) + 6, tostring(holder.level))

	NS:CompanionSetStyle("frame", "feat_prism")
	local eightHidden = true
	for _, d in ipairs(holder.eight) do if d:IsShown() then eightHidden = false end end
	local before = frame.top.vertex and { frame.top.vertex[1], frame.top.vertex[2], frame.top.vertex[3] }
	Mock:Advance(2.5)
	local after = frame.top.vertex
	Check("[HF-E] cadre prismatique : les losanges partent, le filet change de teinte avec le temps",
		eightHidden and before and after and (before[1] ~= after[1] or before[2] ~= after[2] or before[3] ~= after[3]))
	local top, right = frame.top.vertex, frame.rightEdge.vertex
	Check("[HF-E] prisme : un côté par quart de teinte", top[1] ~= right[1] or top[2] ~= right[2] or top[3] ~= right[3])
	NS:CompanionSetStyle("frame", "slate")
	Check("[HF-E] autre cadre : filet d'origine, plus d'horloge", frame.frameStyle == "slate"
		and holder:GetScript("OnUpdate") == nil and math.abs(frame.top.vertex[1] - 0.73) < 1e-6)

	-- ornements : une case de la feuille chacun, interrupteur respecté
	local orn = frame.featOrn or {}
	local okOrn = true
	for _, row in ipairs(EXPECTED) do
		if row[1] == "orn" then
			local o = orn[row[2]]
			local def = Def("orn", row[2])
			if not (o and o:IsShown() and o.tex.texture:find("feat_ornaments", 1, true)
				and math.abs(o.tex.texCoord[1] - def.cell / 8) < 1e-9) then okOrn = false end
		end
	end
	Check("[HF-E] sept ornements posés, chacun sa case de la feuille", okOrn)
	local o = orn.feat_chain
	Check("[HF-E] ornements au-dessus de l'habillage", o and o:GetParent() == frame.featDeco)
	NS:DB().companionOrnFeatChain = false
	NS:CompanionApplyOrnaments()
	Check("[HF-E] interrupteur coupé : ornement caché", not o:IsShown())
	NS:DB().companionOrnFeatChain = true
	NS:CompanionApplyOrnaments()
	Check("[HF-E] interrupteur rallumé : ornement revenu", o:IsShown())
	local prism = orn.feat_prism_orn
	local v1 = prism.tex.vertex and prism.tex.vertex[1]
	Mock:Advance(3)
	Check("[HF-E] ornement prisme : sa teinte tourne", prism.tex.vertex and prism.tex.vertex[1] ~= v1)
	-- page Compagnon : un bouton par ornement gagné, libellé lisible
	local labels = {}
	for _, def in ipairs(NS.COMPANION_ORNAMENTS) do
		if NS:CompanionIsUnlocked("orn", def) then labels[#labels + 1] = NS.L[def.label] or def.id end
	end
	local raw = false
	for _, text in ipairs(labels) do if tostring(text):find("^feat_") or tostring(text):find("^COMP_") then raw = true end end
	Check("[HF-E] page Compagnon : ornements gagnés lisibles (pas d'id brut)", not raw and #labels >= 7)
	ResetWorld()
end

-- 4. Rendu, style Azeroth -------------------------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot E : rendu Azeroth")
	local frame = Reset("azeroth")
	for _, row in ipairs(EXPECTED) do NS:FeatGrant(NS:FeatDef(row[3])) end
	-- le client a les masques (le banc d'essai non) : le style arrondit le fond gagné
	frame.azSkin.mask = frame.azSkin.mask or {}
	frame.bg.AddMaskTexture = function(region, mask) region.maskTex = mask end
	frame.bg.RemoveMaskTexture = function(region) region.maskTex = nil end
	NS:CompanionApplyUIStyle()
	NS:CompanionSetStyle("bg", "feat_atlas")
	Check("[HF-E] Azeroth : le fond en disque sous l'anneau (masque)", frame.uiStyle == "azeroth" and frame.bg.azMasked == true
		and frame.bgTexture:find("feat_atlas", 1, true))
	NS:CompanionSetStyle("frame", "feat_eight")
	local d = frame.featDeco.eight[1]
	local p, rel, rp, x, y = d:GetPoint()
	local ring = NS.AZEROTH_RING
	local r = math.sqrt(x * x + (y - ring.y) * (y - ring.y))
	Check("[HF-E] Azeroth : les huit losanges autour de l'anneau", d:IsShown() and p == "CENTER" and rel == frame and rp == "TOP"
		and math.abs(r - (ring.w / 2 - 3)) < 0.01, tostring(r))
	NS:CompanionSetStyle("frame", "feat_prism")
	local halo = frame.featDeco.halo
	Check("[HF-E] Azeroth : cadre prismatique = halo additif autour de l'anneau", halo and halo:IsShown()
		and halo.blendMode == "ADD" and halo.texture:find("feat_ornaments", 1, true) and math.abs(halo.texCoord[1] - 7 / 8) < 1e-9)
	local v = halo.vertex and halo.vertex[1]
	Mock:Advance(3)
	Check("[HF-E] Azeroth : sa teinte tourne", halo.vertex and halo.vertex[1] ~= v)
	NS:SetUIStyle("sobre")
	if NS.CompanionApplyUIStyle then NS:CompanionApplyUIStyle() end
	local p2, _, rp2 = frame.featDeco.eight[1]:GetPoint()
	Check("[HF-E] retour en Sobre : halo caché, filet arc-en-ciel", not halo:IsShown() and frame.uiStyle == "sobre"
		and frame.featDeco:GetScript("OnUpdate") ~= nil)
	NS:SetUIStyle("azeroth")
	if NS.CompanionApplyUIStyle then NS:CompanionApplyUIStyle() end
	NS:CompanionSetStyle("frame", "feat_eight")
	Check("[HF-E] ornements toujours là en Azeroth", frame.featOrn.feat_compass:IsShown())
	NS:SetUIStyle("sobre")
	ResetWorld()
end

-- 5. Récompenses : jamais d'identifiant brut ------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot E : textes de récompense")
	local raw = {}
	for _, def in ipairs(NS:FeatDefs()) do
		local text = NS:FeatRewardText(def)
		if text:find("feat_", 1, true) or text:find("card_", 1, true) or text:find("COMP_", 1, true)
			or text:find("FEAT_", 1, true) then raw[#raw + 1] = def.id .. "=" .. text end
	end
	Check("[HF-E] aucun texte de récompense ne montre un id brut", #raw == 0, table.concat(raw, " | "))
	Check("[HF-E] fiche de dresseur reportée : « fond de fiche (à venir) » après le titre",
		NS:FeatRewardText(NS:FeatDef("men_species_500")):find("fond de fiche (à venir)", 1, true) ~= nil
		and NS:FeatRewardText(NS:FeatDef("men_species_500")):find("titre", 1, true) ~= nil,
		NS:FeatRewardText(NS:FeatDef("men_species_500")))
	Check("[HF-E] cadre de fiche reporté : seul", NS:FeatRewardText(NS:FeatDef("zone_seal_ek")) == "cadre de fiche (à venir)",
		NS:FeatRewardText(NS:FeatDef("zone_seal_ek")))
	Check("[HF-E] cosmétique du compagnon : son nom", NS:FeatRewardText(NS:FeatDef("men_boss_1")) == "Chaîne du colosse"
		and NS:FeatRewardText(NS:FeatDef("meta_shiny")) == "Cadre prismatique")
	local pending = 0
	for _, def in ipairs(NS:FeatDefs()) do
		if def.reward and def.reward.soon then
			pending = pending + 1
			if def.reward.soon[1] ~= "cardbg" and def.reward.soon[1] ~= "cardframe" then pending = -99 end
		end
	end
	Check("[HF-E] seules les récompenses de fiche restent en attente (6)", pending == 6, pending)
	-- un id inconnu du catalogue (ligne future) : « récompense à venir », pas son id
	local text = NS:FeatRewardText({ id = "x", reward = { cosmetic = { "orn", "feat_inconnu" } } })
	Check("[HF-E] id inconnu : « récompense à venir »", text == "récompense à venir", text)
	Check("[HF-E] rien en attente : texte d'origine", NS:FeatRewardText({ id = "x", reward = { cosmetic = { "frame", "gilded" } } })
		== NS.L.COMP_FRAME_GILDED)
	-- sous-page « Ornements » : une ligne par ornement, verrouillée tant que non gagné
	local rows = {}
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionOrnaments" then for _, row in ipairs(page.rows) do rows[row.key] = true end end
	end
	local missing = 0
	for _, def in ipairs(NS.FEAT_COSMETICS.orn) do if not rows[def.key] then missing = missing + 1 end end
	Check("[HF-E] réglages : chaque ornement a sa ligne", missing == 0)
end
