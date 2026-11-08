-- QuestCompanion 2.9.0 : lisibilité et mise en page (retours en jeu sur le
-- style Azeroth). Textes centrés verticalement (Exploration, plaque), boucliers
-- des points (taille, gris de même gabarit, nombre au centre de l'écu),
-- bloc « Ses effets » de la page Compagnon et intertitres de la fiche de
-- dresseur à l'encre mesurée, portrait fixe dans le cadre de la scène de
-- capture et bouclier à la taille de l'atlas.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local LS = { saved = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitLevel", "InCombatLockdown",
	"UnitAffectingCombat", "C_Texture", "time", "C_ChatInfo", "GetNormalizedRealmName", "GetRealmName" }
for _, name in ipairs(GLOBALS) do LS.saved[name] = rawget(_G, name) end
local INK = NS.AZEROTH_INK
local CONTRAST = NS.AZEROTH_CONTRAST
local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "captureResult" }
LS.feat = { dormant = NS.featsDormant, login = NS.featLoginDone }

function LS.Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.errors = {}
	NS.carnetMissing = {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	_G.UnitName = function(unit) if unit == "player" then return "Dyokrion" end end
	_G.UnitFullName = function(unit) if unit == "player" then return "Dyokrion", "Aeternalis" end end
	_G.UnitExists = function(unit) return unit == "player" end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.time = function() return 1800000000 end
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:CompanionData().tutoDone = true
end
function LS.Done()
	NS:DB().feats = nil
	NS:CharData().feats = nil
	NS:CompanionData().trainer = nil
	NS.featsDormant, NS.featLoginDone = LS.feat.dormant, LS.feat.login
	if NS.TrainerResetSession then NS:TrainerResetSession() end
	for _, name in ipairs(GLOBALS) do _G[name] = LS.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	ResetWorld()
end
local function NoErrors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return #list == 0, table.concat(list, " | ")
end
local function Point(region, name)
	for _, p in ipairs(region and region.points or {}) do if p.point == name then return p end end
	return nil
end
local function Same(c, ref)
	if not (c and ref) then return false end
	for i = 1, 3 do if math.abs((c[i] or -1) - ref[i]) > 0.001 then return false end end
	return true
end
local function Lin(c) if c <= 0.03928 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
local function Lum(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
local function Ratio(c, bg)
	local a, b = Lum(c), bg
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end
-- l'encre d'un rôle, et son contraste sur le pire fond mesuré
local function RoleOK(key)
	local role = CONTRAST[key]
	if not role then return false, "rôle absent : " .. key end
	local ratio = Ratio(INK[role[1]], role[2])
	return ratio >= role[3], string.format("%s %.2f:1 (seuil %.1f)", key, ratio, role[3])
end
local function Painted(fs, key)
	return fs and CONTRAST[key] and Same(fs.textColor, INK[CONTRAST[key][1]])
end

-- 1. La table des contrastes : les rôles de 2.9.0 tiennent leur seuil -------------------------------
do
	Say("-- 2.9.0 : contraste mesuré des nouveaux rôles")
	for _, key in ipairs({ "section.label", "section.detail", "effects.line", "effects.linePending", "effects.state",
		"effects.statePending" }) do
		local ok, detail = RoleOK(key)
		Check("[LIS] contraste " .. key, ok, detail)
	end
end

-- 2. Exploration : textes centrés verticalement sur leur zone --------------------------------------
do
	Say("-- 2.9.0 : Exploration, textes centrés")
	LS.Reset()
	local f = NS:ToggleJournal(true)
	NS:SelectJournalKind("progress")
	local pane = f.prog
	Check("[LIS] page Exploration présente", pane and pane.zones and pane.zones[1] and pane.parts and pane.parts[1])
	local G = NS.CARNET_PROGRESS_LAYOUT
	local row = pane.zones[1]
	row.bar:Show()
	NS.CarnetZoneRowText(row)
	local top, bottom = Point(row.name, "TOPLEFT"), Point(row.name, "BOTTOMLEFT")
	local barY = select(5, row.bar:GetPoint())
	Check("[LIS] zone avec barre : nom posé du haut de la rangée au haut de la barre, centré", top and bottom
		and top.relTo == row and top.y == -G.rowPad and bottom.relTo == row and bottom.relPoint == "TOPLEFT"
		and bottom.y == barY and row.name.justifyV == "MIDDLE", bottom and tostring(bottom.y))
	local pt, pb = Point(row.percent, "TOPRIGHT"), Point(row.percent, "BOTTOMRIGHT")
	Check("[LIS] zone avec barre : pourcentage et « ici » aussi", pt and pb and pb.y == barY and row.percent.justifyV == "MIDDLE"
		and Point(row.here, "BOTTOMRIGHT") and row.here.justifyV == "MIDDLE")
	row.bar:Hide()
	NS.CarnetZoneRowText(row)
	bottom = Point(row.name, "BOTTOMLEFT")
	Check("[LIS] zone sans barre : nom centré sur toute la rangée", bottom and bottom.relPoint == "BOTTOMLEFT"
		and bottom.y == G.rowPad and #row.name.points == 2)
	local tile = pane.parts[1]
	local lt, lb = Point(tile.label, "TOPLEFT"), Point(tile.label, "BOTTOMLEFT")
	local tileBar = select(5, tile.bar:GetPoint())
	Check("[LIS] carte de part : libellé centré entre le haut et le liseré de la barre", lt and lb and lt.y == -G.partTop
		and lb.relPoint == "TOPLEFT" and lb.y == tileBar + G.barEdge and tile.label.justifyV == "MIDDLE")
	Check("[LIS] carte de part : compte aligné sur le libellé", Point(tile.count, "BOTTOMRIGHT")
		and Point(tile.count, "BOTTOMRIGHT").y == lb.y and tile.count.justifyV == "MIDDLE")
	-- plaque : titre et case des points
	local plate = f.azPlate
	local cp = Point(plate.count, "CENTER")
	Check("[LIS] plaque : nombre centré dans la case (bouclier compris), sur son creux", cp and cp.relTo == plate.box
		and cp.x == NS.CARNET_PLATE_COUNT.x and cp.y == NS.CARNET_PLATE_COUNT.y and plate.count.justifyH == "CENTER"
		and plate.count.justifyV == "MIDDLE")
	Check("[LIS] plaque : titre centré verticalement", plate.title.justifyV == "MIDDLE" and plate.title.justifyH == "CENTER")
	local ok, errs = NoErrors()
	Check("[LIS] Exploration : sans erreur", ok, errs)
	LS.Done()
end

-- 3. Boucliers des points : taille, gris du même gabarit, nombre centré ----------------------------
do
	Say("-- 2.9.0 : boucliers des points")
	LS.Reset()
	Check("[LIS] bouclier gris : celui du même gabarit que le doré (62×56)",
		NS.AZEROTH_ATLAS.shieldGrey == "ui-achievement-shield-1-desaturated")
	local f = NS:ToggleJournal(true)
	NS:SelectJournalKind("feats")
	local hf = f.feats
	local row = hf.rows[1]
	row.entry.got = nil
	NS:RefreshJournal()
	local size = NS.AZEROTH_SHIELD_SIZE.row
	Check("[LIS] ligne : bouclier agrandi, au rapport de l'atlas", row.shield:GetWidth() == size[1] and row.shield:GetHeight() == size[2]
		and math.abs(size[1] / size[2] - 63 / 56) < 0.02)
	Check("[LIS] ligne pas encore obtenue : bouclier gris de même gabarit", row.shield:IsShown()
		and row.shield.atlas == "ui-achievement-shield-1-desaturated")
	local pp = Point(row.pts, "CENTER")
	local face = NS.AZEROTH_SHIELD_FACE
	Check("[LIS] ligne : nombre au centre visuel de l'écu, centré H et V", pp and pp.relTo == row.shield
		and pp.x == math.floor(size[1] * face.x + 0.5) and pp.y == math.floor(size[2] * face.y + 0.5) + face.digits
		and row.pts.justifyH == "CENTER" and row.pts.justifyV == "MIDDLE", pp and (pp.x .. "," .. pp.y))
	-- grand bouclier de l'en-tête
	local big, B = hf.azShield, NS.CARNET_SHIELD_BIG
	local tc = big.texCoord
	Check("[LIS] en-tête : grand bouclier recadré sur son dessin (70×51 sur 128)", tc and math.abs(tc[1] - 29 / 128) < 1e-6
		and math.abs(tc[2] - 99 / 128) < 1e-6 and math.abs(tc[3] - 39 / 128) < 1e-6 and math.abs(tc[4] - 90 / 128) < 1e-6)
	Check("[LIS] en-tête : à la taille voulue, sans déformer (±5 %)", big:GetWidth() == B.w and big:GetHeight() == B.h
		and math.abs((B.w / B.h) / (70 / 51) - 1) < 0.05)
	local sp = Point(hf.azShieldText, "CENTER")
	Check("[LIS] en-tête : nombre au centre de l'écu, centré", sp and sp.relTo == big and sp.x == 0 and sp.y == B.y
		and hf.azShieldText.justifyH == "CENTER" and hf.azShieldText.justifyV == "MIDDLE")
	local feats = NS.FeatPoints
	NS.FeatPoints = function() return 1250 end
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	Check("[LIS] en-tête : 4 chiffres, police réduite", hf.azShieldText.font and hf.azShieldText.font.size == B.font[4]
		and hf.azShieldText.font.flags == "OUTLINE")
	NS.FeatPoints = function() return 95 end
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	Check("[LIS] en-tête : 2 chiffres, pleine taille", hf.azShieldText.font.size == B.font[2] and hf.azShieldText:GetText() == "95")
	NS.FeatPoints = feats
	-- petit bouclier (plaque) : recadré, à sa taille
	local icon = f.azPlate.icon
	tc = icon.texCoord
	Check("[LIS] petit bouclier : recadré sur son dessin (20×18 sur 32)", tc and math.abs(tc[2] - 20 / 32) < 1e-6
		and math.abs(tc[4] - 18 / 32) < 1e-6 and icon:GetWidth() == 20 and icon:GetHeight() == 18)
	local ok, errs = NoErrors()
	Check("[LIS] boucliers : sans erreur", ok, errs)
	LS.Done()
end

-- 4. Page Compagnon : bloc « Ses effets » et intertitres à l'encre --------------------------------
do
	Say("-- 2.9.0 : page Compagnon, « Ses effets »")
	LS.Reset()
	local f = NS:ToggleJournal(true)
	NS:SelectJournalKind("evolution")
	local evo = f.evo
	Check("[LIS] intertitre « Ses effets » à l'encre des intertitres", Painted(evo.effTitle.label, "section.label"))
	local pending = not (NS:CompanionEffects() or {}).active
	local line, state = pending and "effects.linePending" or "effects.line", pending and "effects.statePending" or "effects.state"
	Check("[LIS] lignes des effets à l'encre mesurée", Painted(evo.effHunt, line) and Painted(evo.effComfort, line)
		and Painted(evo.effState, state))
	-- l'horloge des effets repeint hors du carnet : l'encre tient
	NS:CompanionEffectsRefreshPane(evo)
	Check("[LIS] après l'horloge des effets : toujours l'encre", Painted(evo.effHunt, line) and Painted(evo.effState, state))
	local real = NS.CompanionEffects
	NS.CompanionEffects = function(self)
		local e = real(self)
		local copy = {}
		for k, v in pairs(e or {}) do copy[k] = v end
		copy.active, copy.remaining = true, 0
		return copy
	end
	NS:CompanionEffectsRefreshPane(evo)
	Check("[LIS] effets actifs : l'encre pleine", Painted(evo.effHunt, "effects.line") and Painted(evo.effState, "effects.state"))
	NS.CompanionEffects = real
	local ok, errs = NoErrors()
	Check("[LIS] page Compagnon : sans erreur", ok, errs)
	LS.Done()
end

-- 5. Fiche de dresseur : intertitres lisibles, petits boucliers ------------------------------------
do
	Say("-- 2.9.0 : fiche de dresseur, intertitres")
	LS.Reset()
	NS:TrainerResetSession()
	_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() return 0 end, SendAddonMessage = function() return 0 end,
		InChatMessagingLockdown = function() return false end }
	_G.GetNormalizedRealmName, _G.GetRealmName = nil, nil
	local t = NS:TrainerOpen(nil)
	Check("[LIS] fiche Azeroth ouverte", t and t.azeroth)
	local all = true
	for _, key in ipairs({ "compSection", "infoSection", "badgeSection", "featsSection", "showSection" }) do
		if not Painted(t[key].label, "section.label") then all = false; Say("  pas à l'encre : " .. key) end
	end
	Check("[LIS] intertitres (Compagnon, Fiche, Sceaux, Hauts faits, Vitrine) à l'encre mesurée", all)
	Check("[LIS] détail des hauts faits à l'encre mesurée", Painted(t.featsSection.detail, "section.detail"))
	local mark = t.featCards[1].mark
	Check("[LIS] vitrine : petit bouclier recadré, à sa taille", mark.texCoord and math.abs(mark.texCoord[2] - 20 / 32) < 1e-6
		and mark:GetWidth() == 20 and mark:GetHeight() == 18)
	local ok, errs = NoErrors()
	Check("[LIS] fiche : sans erreur", ok, errs)
	LS.Done()
end

-- 6. Scène de capture : portrait fixe, bouclier à la taille de l'atlas -----------------------------
do
	Say("-- 2.9.0 : scène de capture, portrait et bouclier")
	LS.Reset()
	local banner = NS:AzerothVerdict(UIParent, 330, 107)
	local size = NS.AZEROTH_SHIELD_SIZE.verdict
	Check("[LIS] verdict : bouclier à la taille de l'atlas (63×56)", banner.shield:GetWidth() == size[1]
		and banner.shield:GetHeight() == size[2] and size[1] == 63 and size[2] == 56)
	banner:SetShield("grey")
	Check("[LIS] verdict « Échappé… » : bouclier gris de même gabarit", banner.shield.atlas == "ui-achievement-shield-1-desaturated")
	Check("[LIS] verdict : pas de modèle 3D (la patte au lieu de la tête)", banner.portrait == nil)
	banner:SetCreature({ npcID = 7001, type = "Humanoïde" })
	Check("[LIS] verdict : portrait fixe, l'icône du type", banner.portraitIcon:IsShown()
		and banner.portraitIcon.texture == NS.MENAGERIE_TYPE_ICONS["Humanoïde"] and banner.portraitNpc == 7001)
	banner:SetLevel(14)
	local lp = Point(banner.levelText, "CENTER")
	Check("[LIS] verdict : niveau au centre de l'écu, centré", lp and lp.relTo == banner.shield and banner.levelText:GetText() == "14"
		and banner.levelText.justifyH == "CENTER" and banner.levelText.justifyV == "MIDDLE")
	LS.Done()
end
