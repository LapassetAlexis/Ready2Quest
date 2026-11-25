-- QuestCompanion 3.7.0, chantier X : les dix cosmétiques du compagnon que le
-- catalogue 3.7 réclame (reward.soon) : sept ornements, un cadre étoilé, deux
-- fonds (FeatsCosmetics.lua). Déclarés comme les autres, faits d'images du
-- client seulement (relevées dans le listfile, la dernière de chaque liste
-- déjà employée ailleurs par l'addon), repli quand le client n'a pas le
-- fichier, résolution des reward.soon, rendu dans les deux styles.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

-- le contrat (CONTRAT-ETAPE-2-FICHE, chantier X ; lignes du catalogue : CONTRAT-ETAPE-1-B2)
local WANTED = {
	{ "orn", "feat_rarities", "men_rare_50" }, { "orn", "feat_contest", "spec_contest" },
	{ "orn", "feat_rare_size", "shiny_rare_size" }, { "orn", "feat_glitter", "shop_glitter_100000" },
	{ "orn", "feat_volunteer", "day_mission_500" }, { "orn", "feat_worlds", "soc_discord" },
	{ "orn", "feat_unfindable", "fos_unfindable" }, { "frame", "feat_starry", "spec_stars3_250" },
	{ "bg", "feat_sparkle", "shiny_found_100" }, { "bg", "feat_perfect", "day_perfect_100" },
}
local LISTS = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS" }
local function Def(kind, id)
	for _, def in ipairs(NS[LISTS[kind]] or {}) do if def.id == id then return def end end
	return nil
end
-- images du client appelées (wowdev/wow-listfile, community-listfile.csv) : chemin -> FileDataID
local LISTFILE = {
	["interface/icons/inv_misc_gem_sapphire_02"] = 134132, ["interface/icons/inv_misc_gem_sapphire_01"] = 134131,
	["interface/icons/inv_misc_gem_amethyst_02"] = 134075, ["interface/icons/inv_jewelry_talisman_01"] = 133434,
	["interface/icons/inv_misc_ribbon_01"] = 134411, ["interface/icons/inv_misc_spyglass_03"] = 134442,
	["interface/icons/inv_misc_spyglass_02"] = 134441, ["interface/icons/ability_hunter_snipershot"] = 132212,
	["interface/icons/inv_misc_bag_10"] = 133639, ["interface/icons/inv_misc_coin_02"] = 133785,
	["interface/icons/inv_misc_coin_01"] = 133784, ["interface/icons/inv_misc_token_argentdawn"] = 134499,
	["interface/icons/inv_misc_token_argentdawn2"] = 134500, ["interface/icons/spell_holy_devotionaura"] = 135893,
	["interface/icons/inv_misc_orb_01"] = 134333, ["interface/icons/inv_misc_map_01"] = 134269,
	["interface/icons/inv_misc_gem_opal_01"] = 134116, ["interface/icons/inv_misc_gem_topaz_02"] = 134136,
	["interface/icons/inv_misc_gem_pearl_04"] = 134123, ["interface/targetingframe/ui-raidtargetingicon_1"] = 137001,
}

local FIELDS = { "companionFrame", "companionBubble", "companionHover" }
local function Reset(style, atlas)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	_G.GetFileIDFromPath = nil
	NS.FeatFileReset()
	if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:SetUIStyle(style or "sobre")
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
	return NS:EnsureCompanionFrame()
end
local function Done()
	_G.GetFileIDFromPath = nil
	NS.FeatFileReset()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	ResetWorld()
end
local function GrantAll()
	local data = NS:CompanionData()
	for _, row in ipairs(WANTED) do data.unlocked[row[1] .. ":" .. row[2]] = true end
end

-- 1. Catalogue ------------------------------------------------------------------------------------------
do
	Say("-- 3.7 : dix cosmétiques du compagnon, déclarés")
	local fr, en = NS.FEAT_COSMETIC_STRINGS.fr, NS.FEAT_COSMETIC_STRINGS.en
	local chest = {}
	for _, reward in ipairs(NS.COMPANION_REWARDS or {}) do chest[reward.kind .. ":" .. reward.id] = true end
	local rows = {}
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionOrnaments" then for _, r in ipairs(page.rows) do rows[r.key] = true end end
	end
	local own = { frame = NS.FEAT_COSMETICS.frame, bg = NS.FEAT_COSMETICS.bg, orn = NS.FEAT_COSMETICS.orn }
	local s = Steps()
	for _, row in ipairs(WANTED) do
		local kind, id, feat = row[1], row[2], row[3]
		local def = Def(kind, id)
		local mine = false
		for _, d in ipairs(own[kind]) do if d == def then mine = true end end
		s.ok(id .. " déclaré dans FEAT_COSMETICS." .. kind, def and mine)
		if def then
			s.ok(id .. " : palier 0, haut fait " .. feat, def.tier == 0 and def.unlock and def.unlock.feat == feat)
			s.ok(id .. " : nom FR et EN", fr[def.label] and en[def.label] and fr[def.label] ~= en[def.label] == (id ~= "x")
				and NS.COMPANION_STRINGS.fr[def.label] == fr[def.label] and NS.COMPANION_STRINGS.en[def.label] == en[def.label])
			s.ok(id .. " : jamais au coffre", not chest[kind .. ":" .. id])
			if kind == "orn" then
				s.ok(id .. " : interrupteur et ligne de réglage", def.key and NS:DB()[def.key] == true and rows[def.key])
				s.ok(id .. " : place au carré et sur l'anneau forgé", def.at and def.size and NS.FEAT_ORN_FORGE[id])
			end
		end
	end
	-- aucun glyphe interdit dans les noms
	for _, row in ipairs(WANTED) do
		local def = Def(row[1], row[2])
		for _, text in ipairs({ def and fr[def.label] or "", def and en[def.label] or "" }) do
			for _, glyph in ipairs({ "★", "☆", "✓", "✗" }) do
				if text:find(glyph, 1, true) then s.ok(row[2] .. " sans glyphe", false) end
			end
		end
	end
	s.check("[X37] dix cosmétiques : catalogue, palier 0, haut fait du contrat, noms FR/EN, hors coffre, un réglage par ornement")
end

-- 2. Images du client seulement --------------------------------------------------------------------------
do
	Say("-- 3.7 : cosmétiques neufs, images du client")
	local unknown, reused = {}, {}
	local function Want(path)
		if LISTFILE[tostring(path):gsub("\\", "/"):lower()] == nil then unknown[#unknown + 1] = tostring(path) end
	end
	-- les autres fichiers de l'addon (pour le repli « déjà employé »)
	local others = {}
	for _, file in ipairs({ "JournalReserve.lua", "JournalWindow.lua", "FeatsData.lua", "CompanionAllure.lua",
		"ReserveBrowse.lua", "Treats.lua", "Shiny.lua", "CompanionEffects.lua" }) do
		others[#others + 1] = Read("QuestCompanion/" .. file) or ""
	end
	local function UsedElsewhere(name)
		for _, text in ipairs(others) do if text:find(name, 1, true) then return true end end
		return false
	end
	for _, row in ipairs(WANTED) do
		local def = Def(row[1], row[2])
		if def and def.icons then
			for _, name in ipairs(def.icons) do Want("Interface\\Icons\\" .. name) end
			local last = def.icons[#def.icons]
			if not UsedElsewhere(last) and last ~= "INV_Misc_Ribbon_01" then reused[#reused + 1] = row[2] .. " (" .. last .. ")" end
		end
	end
	for _, name in ipairs(NS.FEAT_SUN_ICONS) do Want("Interface\\Icons\\" .. name) end
	Want("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
	local src = Read("QuestCompanion/FeatsCosmetics.lua") or ""
	Check("[X37] images : toutes relevées dans le listfile, aucune texture livrée", #unknown == 0
		and not src:find("AddOns\\", 1, true) and not src:find("%.tga") and not src:find("%.blp"), table.concat(unknown, ", "))
	Check("[X37] repli sûr : la dernière icône de chaque ornement neuf est déjà employée ailleurs par l'addon (ou par un ornement existant)",
		#reused == 0 and UsedElsewhere(NS.FEAT_SUN_ICONS[1]), table.concat(reused, ", "))
end

-- 3. Le catalogue les réclame : reward.soon résolu ----------------------------------------------------------
do
	Say("-- 3.7 : reward.soon du catalogue résolu")
	local s = Steps()
	local added = {}
	for _, row in ipairs(WANTED) do
		local fd = NS:FeatDef(row[3])
		if fd then
			-- la ligne du catalogue est là : son cosmétique est donné
			local c = fd.reward and fd.reward.cosmetic
			s.ok(row[3] .. " donne " .. row[2], c and c[1] == row[1] and c[2] == row[2] and not fd.reward.soon)
		else
			-- pas encore là (autre chantier) : une ligne d'essai qui attend ce cosmétique
			added[#added + 1] = { id = "x37_probe_" .. row[2], cat = "men", reward = { soon = { row[1], row[2] } } }
		end
	end
	for _, probe in ipairs(added) do NS.FEAT_DEFS[#NS.FEAT_DEFS + 1] = probe end
	NS.FeatResolveSoon()
	for _, probe in ipairs(added) do
		local c = probe.reward.cosmetic
		s.ok(probe.id .. " résolu", c and c[2] == probe.id:sub(#"x37_probe_" + 1) and probe.reward.soon == nil)
		local text = NS:FeatRewardText(probe)
		s.ok(probe.id .. " : plus « à venir »", not text:find(NS.L.FEAT_SOON_any, 1, true), text)
	end
	for _ = 1, #added do table.remove(NS.FEAT_DEFS) end
	NS.featIndexDirty = true
	s.check("[X37] chaque reward.soon des dix devient un cosmétique (ligne du catalogue, ou ligne d'essai si elle n'est pas encore là)")
end

-- 4. Rendu Sobre -----------------------------------------------------------------------------------------
do
	Say("-- 3.7 : cosmétiques neufs, rendu Sobre")
	local frame = Reset("sobre")
	GrantAll()
	NS:CompanionApplyOrnaments()
	local orn = frame.featOrn or {}
	local s = Steps()
	local ICON = { feat_rarities = "INV_Misc_Gem_Sapphire_02", feat_contest = "INV_Jewelry_Talisman_01",
		feat_rare_size = "INV_Misc_Spyglass_03", feat_glitter = "INV_Misc_Bag_10", feat_volunteer = "INV_Misc_Token_ArgentDawn",
		feat_worlds = "INV_Misc_Orb_01", feat_unfindable = "INV_Misc_Gem_Opal_01" }
	for id, icon in pairs(ICON) do
		local o = orn[id]
		s.ok(id .. " posé, dans l'anneau de minicarte", o and o:IsShown() and o.icon.texture == "Interface\\Icons\\" .. icon
			and o.border.texture == "Interface\\Minimap\\MiniMap-TrackingBorder" and o:GetParent() == frame.featDeco)
	end
	s.ok("halo fixe : bourse et joyau, teintés, sans horloge", orn.feat_glitter.glow and orn.feat_unfindable.glow
		and orn.feat_unfindable.glow.vertex[1] == 1 and orn.feat_glitter:GetScript("OnUpdate") == nil
		and orn.feat_unfindable:GetScript("OnUpdate") == nil and orn.feat_rarities.glow == nil)
	-- deux ornements des hauts faits ne partagent jamais la même place
	local seen, clash = {}, {}
	for _, def in ipairs(NS.FEAT_COSMETICS.orn) do
		local key = table.concat({ def.at[1], def.at[2], def.at[3], def.at[4] }, ",")
		if seen[key] then clash[#clash + 1] = def.id .. "=" .. seen[key] end
		seen[key] = def.id
	end
	s.ok("places distinctes", #clash == 0, table.concat(clash, ", "))
	s.check("[X37] sept ornements neufs posés au Sobre (icône du client dans l'anneau de minicarte, halo fixe pour deux)")

	s = Steps()
	NS:CompanionSetStyle("frame", "feat_starry")
	local holder = frame.featDeco
	local shown = 0
	for _, star in ipairs(holder.starry or {}) do
		if star:IsShown() and star.texture == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" then shown = shown + 1 end
	end
	s.ok("cadre étoilé : bordure du client et huit étoiles", frame.frameStyle == "feat_starry" and frame.frameBackdrop == true
		and shown == #NS.FEAT_STARRY_SOBRE and shown == 8)
	local p, rel, rp = holder.starry[1]:GetPoint()
	s.ok("étoiles sur le cadre carré", p == "CENTER" and rel == frame and rp == "TOPLEFT")
	NS:CompanionSetStyle("frame", "slate")
	local gone = true
	for _, star in ipairs(holder.starry) do if star:IsShown() then gone = false end end
	s.ok("autre cadre : étoiles parties", gone and frame.frameStyle == "slate")
	s.check("[X37] cadre étoilé : étoiles des marqueurs de raid sur le cadre, retirées au changement de cadre")

	s = Steps()
	NS:CompanionSetStyle("bg", "feat_sparkle")
	local deco = frame.featBgDeco or {}
	s.ok("nuit scintillante : étoiles et halo argenté", frame.bgStyle == "feat_sparkle" and frame.starsOn
		and deco.sparkle and deco.sparkle.glow and deco.sparkle.glow:IsShown())
	NS:CompanionSetStyle("bg", "feat_perfect")
	local sun = deco.sunrise and deco.sunrise.sun
	s.ok("soleil levant : disque coupé à l'horizon, en ADD, halo", sun and sun:IsShown() and sun.blendMode == "ADD"
		and sun.texture == "Interface\\Icons\\INV_Misc_Gem_Pearl_04" and deco.sunrise.glow:IsShown()
		and not deco.sparkle.glow:IsShown() and not frame.starsOn)
	local sp, _, _, _, sy = sun:GetPoint()
	s.ok("au carré : l'horizon au-dessus de la bande du nom", sp == "BOTTOM" and sy == NS.FEAT_BG_DECO.sunrise.sun[3])
	NS:CompanionSetStyle("bg", NS.COMPANION_BACKGROUNDS[1].id)
	s.ok("autre fond : décor parti", frame.bgStyle == NS.COMPANION_BACKGROUNDS[1].id and not sun:IsShown()
		and not deco.sunrise.glow:IsShown())
	s.check("[X37] fonds neufs (Sobre) : nuit scintillante (étoiles, halo), soleil levant (disque, halo), retirés au changement")
	Done()
end

-- 5. Thème forgé ------------------------------------------------------------------------------------------
do
	Say("-- 3.7 : cosmétiques neufs, médaillon forgé")
	local frame = Reset("azeroth")
	GrantAll()
	NS:CompanionApplyOrnaments()
	local s = Steps()
	local top = NS.ForgeCompanionPlateTop and NS.ForgeCompanionPlateTop()
	local centers = {}
	for _, row in ipairs(WANTED) do
		if row[1] == "orn" then
			local o = frame.featOrn and frame.featOrn[row[2]]
			local spec = NS.FEAT_ORN_FORGE[row[2]]
			s.ok(row[2] .. " recalé sur le médaillon", o and o.forgePlaced and o:IsShown())
			if o and spec.angle then
				local lp = o.lastPoint
				s.ok(row[2] .. " au-dessus de la plaque", lp.y - o.height / 2 > top, lp.y)
				centers[#centers + 1] = { row[2], lp.x, lp.y }
			end
		end
	end
	-- les ornements de l'anneau ne se chevauchent pas (centres à plus d'une icône)
	for id, spec in pairs(NS.FEAT_ORN_FORGE) do
		local o = frame.featOrn[id]
		if spec.angle and o and o.lastPoint then
			for _, c in ipairs(centers) do
				if c[1] ~= id then
					local dx, dy = o.lastPoint.x - c[2], o.lastPoint.y - c[3]
					s.ok(c[1] .. " / " .. id .. " à distance", math.sqrt(dx * dx + dy * dy) >= 22)
				end
			end
		end
	end
	s.check("[X37] médaillon forgé : les sept ornements neufs recalés (second rang de l'anneau, sous la plaque), sans chevauchement")

	s = Steps()
	NS:CompanionSetStyle("frame", "feat_starry")
	local low = 99
	for _, star in ipairs(frame.featDeco.starry or {}) do
		local b = star.lastPoint.y - star.height / 2
		if b < low then low = b end
	end
	s.ok("étoiles sur l'arc du haut, aucune sur la plaque", frame.featDeco.starry and low > top, low)
	NS:CompanionSetStyle("bg", "feat_perfect")
	local parts = frame.featBgDeco and frame.featBgDeco.sunrise
	local skin = NS.CompanionRingSkin and NS.CompanionRingSkin(frame)
	s.ok("soleil levant à sa hauteur sur l'anneau, arrondi par son masque", parts and parts.sun
		and (not (skin and skin.mask) or parts.sun.azMasked) and parts.sun.lastPoint.y == NS.FEAT_BG_DECO.sunrise.sun[2])
	NS:SetUIStyle("sobre")
	s.ok("retour au Sobre : soleil démasqué, à sa hauteur du carré", not parts.sun.azMasked
		and parts.sun.lastPoint.y == NS.FEAT_BG_DECO.sunrise.sun[3])
	s.check("[X37] médaillon forgé : étoiles hors de la plaque, soleil masqué par l'anneau, rendu au carré au retour")
	Done()
end

-- 6. Replis : fichier ou atlas absent du client ---------------------------------------------------------
do
	Say("-- 3.7 : cosmétiques neufs, replis")
	local s = Steps()
	-- premières icônes absentes : la dernière (déjà employée par l'addon)
	_G.GetFileIDFromPath = function(path)
		for _, name in ipairs({ "Sapphire", "Talisman", "Spyglass", "Bag_10", "Coin_02", "ArgentDawn", "Orb_01", "Opal", "Topaz" }) do
			if path:find(name, 1, true) then return nil end
		end
		return 1
	end
	NS.FeatFileReset()
	for _, row in ipairs(WANTED) do
		local def = Def(row[1], row[2])
		if def and def.icons then
			local got = NS.FeatPickIcon(def.icons)
			s.ok(row[2] .. " : repli sur " .. def.icons[#def.icons], got == "Interface\\Icons\\" .. def.icons[#def.icons], got)
		end
	end
	-- rien du tout (ni icône, ni étoile, ni atlas) : rien de cassé
	local frame = Reset("sobre", false)
	_G.GetFileIDFromPath = function() return nil end
	NS.FeatFileReset()
	GrantAll()
	NS:CompanionApplyOrnaments()
	local hidden = true
	for _, row in ipairs(WANTED) do
		if row[1] == "orn" and frame.featOrn[row[2]] then hidden = false end
	end
	s.ok("aucune icône : ornement caché (jamais un carré vert)", hidden)
	NS:CompanionSetStyle("frame", "feat_starry")
	s.ok("sans étoile : le cadre garde filets et bordure", frame.frameStyle == "feat_starry" and frame.frameBackdrop == true
		and frame.featDeco and frame.featDeco.starry == false)
	NS:CompanionSetStyle("bg", "feat_perfect")
	local parts = frame.featBgDeco and frame.featBgDeco.sunrise
	s.ok("sans soleil ni halo : le dégradé d'aurore reste", frame.bgStyle == "feat_perfect" and not frame.bgFallback
		and parts and parts.sun == nil and parts.glow == nil)
	NS:CompanionSetStyle("bg", "feat_sparkle")
	s.ok("sans halo : la nuit étoilée reste", frame.starsOn and frame.featBgDeco.sparkle.glow == nil)
	s.ok("sans erreur", #(NS.errors or {}) == 0)
	s.check("[X37] replis : première icône absente -> la suivante ; aucune -> ornement caché, cadre et fonds gardent filets et dégradés")
	Done()
end
