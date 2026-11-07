-- QuestCompanion 2.7.x, lot E des hauts faits : cosmétiques gagnés par les
-- hauts faits (FeatsCosmetics.lua), faits UNIQUEMENT d'images du client
-- (icônes, carte du monde, minicarte, atlas ; rien de livré). Catalogue,
-- chemins relevés dans le listfile de Forever, replis quand une image manque,
-- déblocage par le haut fait (et seulement lui), choix et rendu dans les deux
-- styles, texte de condition « Haut fait : … », récompenses de la fiche de
-- dresseur reportées (jamais un id brut). Fonds des sceaux : sols du client.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

-- images du client relevées (wago.tools : listfile global et tables
-- UiTextureAtlas* de Forever, novembre 2026) : chemin -> FileDataID
local LISTFILE = {
	["interface/icons/spell_frost_chainsofice"] = 135834, ["interface/icons/spell_nature_stranglevines"] = 136100,
	["interface/icons/inv_enchant_prismaticsphere"] = 132872, ["interface/icons/inv_misc_gem_diamond_02"] = 134095,
	["interface/icons/inv_misc_ribbon_01"] = 134411, ["interface/icons/inv_misc_gift_01"] = 134140,
	["interface/icons/achievement_boss_cthun"] = 236407, ["interface/icons/inv_misc_eye_01"] = 133884,
	["interface/icons/inv_crown_14"] = 132770, ["interface/icons/inv_crown_02"] = 132768,
	["interface/icons/spell_fire_fire"] = 135805, ["interface/icons/ability_hunter_pet_wolf"] = 132203,
	["interface/icons/inv_misc_head_dragon_01"] = 134153,
	["interface/worldmap/azeroth/azeroth6"] = 270458, ["interface/minimap/minimap-trackingborder"] = 136430,
	["interface/minimap/ui-minimap-background"] = 136467, ["interface/minimap/minimaparrow"] = 136431,
	["interface/minimap/compassnorthtag"] = 136427,
}
local ATLASES = { ["BonusChest-CircleGlow"] = 99, ["garrlanding-circleglow"] = 46 }   -- largeur dans la table
-- sols des sceaux : FileDataID -> chemin du listfile
local GROUNDS = {
	forest = { 187124, "tileset/elwynn/elwynnflowerbase" }, nightforest = { 188474, "tileset/felwood/felwoodmoss" },
	canyon = { 186915, "tileset/barrens/barrensbaserock" }, savanna = { 186908, "tileset/barrens/barrensbasegrassgold" },
	snow = { 189051, "tileset/winterspring grove/winterspringsnowripple" },
	swamp = { 188851, "tileset/swamp of sorrows/swampsorrowsroot01" }, desert = { 188872, "tileset/tanaris/tanarissandbase02" },
	blight = { 188688, "tileset/plaguelands/plaguedearthcreep01" }, jungle = { 188829, "tileset/stranglethorn/stranglethornplants01" },
	volcanic = { 186959, "tileset/burningstepps/burningsteppsrocklava" },
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
local function Known(path) return LISTFILE[tostring(path):gsub("\\", "/"):lower()] ~= nil end

local function ReadFile(path)
	local h = io.open(ROOT .. "/" .. path, "rb")
	if not h then return nil end
	local data = h:read("*a")
	h:close()
	return data
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

-- 1. Catalogue, chaînes et images du client --------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot E : catalogue et images du client")
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
			if kind == "orn" and not (def.key and NS:DB()[def.key] ~= nil and def.at and (def.icons or def.look)) then Bad("ornement") end
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

	-- chaque image appelée existe dans le client (relevé du listfile), aucune n'est livrée
	local unknown = {}
	local function Want(path) if not Known(path) then unknown[#unknown + 1] = tostring(path) end end
	for _, def in ipairs(NS.FEAT_COSMETICS.orn) do
		for _, name in ipairs(def.icons or {}) do Want("Interface\\Icons\\" .. name) end
	end
	for _, name in pairs(NS.FEAT_FAMILY_ICONS) do
		if name == "Ability_Hunter_Pet_Wolf" or name == "INV_Misc_Head_Dragon_01" then Want("Interface\\Icons\\" .. name) end
	end
	Want(Def("bg", "feat_atlas").texture)
	for _, path in ipairs(NS.FEAT_COSMETIC_CLIENT_FILES) do
		local p = tostring(path):lower()
		if not (p:find("tooltip") or p:find("dialogbox") or p:find("raidtargeting") or p:find("tempportrait")) then Want(path) end
	end
	Check("[HF-E] images : toutes relevées dans le listfile du client", #unknown == 0, table.concat(unknown, ", "))
	local atl = true
	for _, name in ipairs(NS.FEAT_COSMETIC_ATLASES) do if not ATLASES[name] then atl = false end end
	Check("[HF-E] atlas : relevés dans les tables du client", atl and #NS.FEAT_COSMETIC_ATLASES == 2)
	local src = (ReadFile("QuestCompanion/FeatsCosmetics.lua") or "")
	Check("[HF-E] aucune texture livrée par l'addon", not src:find("AddOns\\", 1, true) and not src:find("%.tga")
		and ReadFile("QuestCompanion/Textures/feat_ornaments.tga") == nil and ReadFile("tools/gen_feat_cosmetics.py") == nil)
	local toc = ReadFile("QuestCompanion/QuestCompanion.toc") or ""
	Check("[HF-E] .toc : chargé juste après Feats.lua", toc:find("\nFeats.lua\r?\nFeatsCosmetics.lua\r?\n") ~= nil)

	-- repli : une icône absente du client -> la suivante ; aucune -> ornement caché
	_G.GetFileIDFromPath = function(path) if path:find("CThun", 1, true) then return nil end return 1 end
	NS.FeatFileReset()
	Check("[HF-E] repli : sans l'œil de C'Thun, l'œil d'origine", NS.FeatPickIcon({ "Achievement_Boss_CThun", "INV_Misc_Eye_01" })
		== "Interface\\Icons\\INV_Misc_Eye_01")
	_G.GetFileIDFromPath = function() return nil end
	NS.FeatFileReset()
	Check("[HF-E] repli : aucune icône, rien", NS.FeatPickIcon({ "INV_Crown_14" }) == nil)
	_G.GetFileIDFromPath = nil
	NS.FeatFileReset()
end

-- 1 bis. Fonds des sceaux : sols du client ---------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot E : fonds des sceaux")
	local bad = {}
	for _, biome in ipairs(NS.MENAGERIE_BIOMES) do
		local def
		for _, d in ipairs(NS.COMPANION_BACKGROUNDS) do if d.id == "seal_" .. biome then def = d end end
		local want = GROUNDS[biome]
		if not (def and want and def.texture == want[1] and def.unlock and def.unlock.seal == biome and def.unlock.count == 2
			and def.color and def.color[1] < 0.9) then bad[#bad + 1] = biome end
	end
	Check("[HF-E] 10 fonds de sceau : un sol du client (FileDataID relevé), assombri, même condition", #bad == 0,
		table.concat(bad, ", "))
	local left = {}
	for _, biome in ipairs(NS.MENAGERIE_BIOMES) do
		if ReadFile("QuestCompanion/Textures/scene_" .. biome .. ".tga") then left[#left + 1] = biome end
	end
	Check("[HF-E] paysages peints et leur outil retirés", #left == 0 and ReadFile("tools/gen_seal_scenes.py") == nil
		and NS.MENAGERIE_SCENE_TEXTURE == nil, table.concat(left, ", "))
	local frame = Reset("sobre")
	NS:CompanionData().unlocked["bg:seal_snow"] = true
	NS:CompanionSetStyle("bg", "seal_snow")
	Check("[HF-E] fond de sceau porté : la texture du client", frame.bgTexture == 189051 and not frame.bgFallback)
	-- client qui refuse le fichier : aplat sombre (repli de Companion.lua)
	local set = frame.bg.SetTexture
	frame.bg.SetTexture = function(region, path) if type(path) == "number" then return false end return set(region, path) end
	NS:CompanionApplyBackground()
	Check("[HF-E] fichier refusé : aplat, pas d'erreur", frame.bgFallback == true)
	frame.bg.SetTexture = set
	ResetWorld()
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
	Check("[HF-E] fond Atlas porté : la carte du monde du client, recadrée",
		NS:CompanionSetStyle("bg", "feat_atlas") ~= nil and frame.bgTexture == "Interface\\WorldMap\\Azeroth\\Azeroth6"
		and frame.bgCoords and frame.bgCoords[1] == 0.06 and not frame.bgFallback)
	NS:CompanionSetStyle("bg", "feat_campfire")
	local fire = frame.featFire
	Check("[HF-E] fond Feu de camp : nuit étoilée, halo du client et flamme (icône en ADD)", frame.bgStyle == "feat_campfire"
		and frame.stars and frame.stars[1]:IsShown() and fire and fire.glow and fire.glow.atlasName == "BonusChest-CircleGlow"
		and fire.flame:IsShown() and fire.flame.blendMode == "ADD" and fire.flame.texture == "Interface\\Icons\\Spell_Fire_Fire")
	NS:CompanionSetStyle("bg", "feat_atlas")
	Check("[HF-E] autre fond : plus de feu", not fire.flame:IsShown() and not fire.glow:IsShown())
	NS:CompanionSetStyle("frame", "feat_eight")
	local holder = frame.featDeco
	local shown, icons = 0, {}
	for _, d in ipairs(holder and holder.eight or {}) do
		if d:IsShown() then shown = shown + 1 end
		icons[tostring(d.texture)] = true
	end
	local distinct = 0
	for path in pairs(icons) do if path:find("^Interface\\Icons\\") then distinct = distinct + 1 end end
	Check("[HF-E] cadre des huit familles : bordure dorée et les huit icônes de familles du client",
		frame.frameStyle == "feat_eight" and frame.frameBackdrop == true and shown == 8 and distinct == 8)
	local p, rel, rp = holder.eight[1]:GetPoint()
	Check("[HF-E] Sobre : les icônes sur le cadre carré (coins et milieux)", p == "CENTER" and rel == frame and rp == "TOPLEFT")
	Check("[HF-E] décor au-dessus de l'habillage (niveau + 6)", holder.level == (frame.level or 0) + 6, tostring(holder.level))

	NS:CompanionSetStyle("frame", "feat_prism")
	local eightHidden = true
	for _, d in ipairs(holder.eight) do if d:IsShown() then eightHidden = false end end
	local before = frame.top.vertex and { frame.top.vertex[1], frame.top.vertex[2], frame.top.vertex[3] }
	Mock:Advance(2.5)
	local after = frame.top.vertex
	Check("[HF-E] cadre prismatique : les icônes partent, le filet change de teinte avec le temps",
		eightHidden and before and after and (before[1] ~= after[1] or before[2] ~= after[2] or before[3] ~= after[3]))
	local top, right = frame.top.vertex, frame.rightEdge.vertex
	Check("[HF-E] prisme : un côté par quart de teinte", top[1] ~= right[1] or top[2] ~= right[2] or top[3] ~= right[3])
	NS:CompanionSetStyle("frame", "slate")
	Check("[HF-E] autre cadre : filet d'origine, plus d'horloge", frame.frameStyle == "slate"
		and holder:GetScript("OnUpdate") == nil and math.abs(frame.top.vertex[1] - 0.73) < 1e-6)

	-- ornements : bouton rond de minicarte (anneau du client) et icône du client
	local orn = frame.featOrn or {}
	local okOrn, missing = true, {}
	for _, row in ipairs(EXPECTED) do
		if row[1] == "orn" then
			local o = orn[row[2]]
			if not (o and o:IsShown()) then okOrn = false; missing[#missing + 1] = row[2] end
		end
	end
	Check("[HF-E] sept ornements posés", okOrn, table.concat(missing, ", "))
	local chain = orn.feat_chain
	Check("[HF-E] chaîne : icône du client dans l'anneau d'un bouton de minicarte", chain and chain.icon.texture
		== "Interface\\Icons\\Spell_Frost_ChainsOfIce" and chain.border.texture == "Interface\\Minimap\\MiniMap-TrackingBorder"
		and chain.back.texture == "Interface\\Minimap\\UI-Minimap-Background")
	Check("[HF-E] œil clos : l'œil de C'Thun ; couronne sauvage : la couronne de lierre",
		orn.feat_eye.icon.texture == "Interface\\Icons\\Achievement_Boss_CThun"
		and orn.feat_wildcrown.icon.texture == "Interface\\Icons\\INV_Crown_14"
		and orn.feat_anniversary.icon.texture == "Interface\\Icons\\INV_Misc_Ribbon_01")
	local stars = orn.feat_goldstars.stars
	Check("[HF-E] trois étoiles d'or : l'étoile des marqueurs de raid, trois fois", stars and #stars == 3
		and stars[2].texture == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
	local compass = orn.feat_compass
	Check("[HF-E] boussole : disque, flèche et nord de la minicarte", compass.icon.texture == "Interface\\Minimap\\MinimapArrow"
		and compass.north.texture == "Interface\\Minimap\\CompassNorthTag")
	Check("[HF-E] ornements au-dessus de l'habillage", chain:GetParent() == frame.featDeco)
	NS:DB().companionOrnFeatChain = false
	NS:CompanionApplyOrnaments()
	Check("[HF-E] interrupteur coupé : ornement caché", not chain:IsShown())
	NS:DB().companionOrnFeatChain = true
	NS:CompanionApplyOrnaments()
	Check("[HF-E] interrupteur rallumé : ornement revenu", chain:IsShown())
	local prism = orn.feat_prism_orn
	local v1 = prism.glow and prism.glow.vertex and prism.glow.vertex[1]
	Mock:Advance(3)
	Check("[HF-E] ornement prisme : la sphère prismatique, son halo change de teinte", prism.icon.texture
		== "Interface\\Icons\\INV_Enchant_PrismaticSphere" and prism.glow and prism.glow.vertex[1] ~= v1)
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

-- 3 bis. Atlas absents : les pièces qui en dépendent sautent sans erreur ------------------------------------
do
	Say("-- qc27 hauts faits, lot E : atlas absents")
	local frame = Reset("sobre")
	Mock.InstallAtlas({ ["BonusChest-CircleGlow"] = true, ["garrlanding-circleglow"] = true })
	for _, row in ipairs(EXPECTED) do NS:FeatGrant(NS:FeatDef(row[3])) end
	NS:CompanionSetStyle("bg", "feat_campfire")
	Check("[HF-E] sans halo du client : le feu reste (flamme), pas d'erreur", frame.featFire and frame.featFire.glow == nil
		and frame.featFire.flame:IsShown())
	Check("[HF-E] sans halo : la sphère prismatique reste", frame.featOrn.feat_prism_orn and frame.featOrn.feat_prism_orn:IsShown()
		and frame.featOrn.feat_prism_orn.glow == nil)
	Mock.InstallAtlas(true)
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
		and frame.bgTexture == "Interface\\WorldMap\\Azeroth\\Azeroth6")
	NS:CompanionSetStyle("frame", "feat_eight")
	local d = frame.featDeco.eight[1]
	local p, rel, rp, x, y = d:GetPoint()
	local ring = NS.AZEROTH_RING
	local r = math.sqrt(x * x + (y - ring.y) * (y - ring.y))
	Check("[HF-E] Azeroth : les huit icônes autour de l'anneau", d:IsShown() and p == "CENTER" and rel == frame and rp == "TOP"
		and math.abs(r - (ring.w / 2 - 3)) < 0.01, tostring(r))
	NS:CompanionSetStyle("frame", "feat_prism")
	local halo = frame.featDeco.halo
	Check("[HF-E] Azeroth : cadre prismatique = halo du client (atlas) autour de l'anneau", halo and halo:IsShown()
		and halo.blendMode == "ADD" and halo.atlasName == "BonusChest-CircleGlow")
	local v = halo.vertex and halo.vertex[1]
	Mock:Advance(3)
	Check("[HF-E] Azeroth : sa teinte tourne", halo.vertex and halo.vertex[1] ~= v)
	NS:SetUIStyle("sobre")
	if NS.CompanionApplyUIStyle then NS:CompanionApplyUIStyle() end
	Check("[HF-E] retour en Sobre : halo caché, filet arc-en-ciel", not halo:IsShown() and frame.uiStyle == "sobre"
		and frame.featDeco:GetScript("OnUpdate") ~= nil)
	NS:SetUIStyle("azeroth")
	if NS.CompanionApplyUIStyle then NS:CompanionApplyUIStyle() end
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
