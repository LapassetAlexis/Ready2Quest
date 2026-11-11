-- CompanionAllure.lua -- choisir l'allure du compagnon (QuestCompanion 2.14.0)
--
-- Avant : « Son allure » (page Compagnon du carnet) faisait défiler cinq
-- vignettes 3D avec deux chevrons ; à 76 apparences, introuvable. Désormais :
--   * la page montre l'allure portée (petit modèle, nom, ce qu'elle est) et
--     un bouton « Choisir… » (AllureBuildCard / AllureRefreshCard, appelés par
--     JournalWindow.lua) ;
--   * le bouton ouvre un panneau posé sur le carnet (Échap le ferme, il se
--     ferme avec le carnet) : recherche (minuscules, sans accents, à la fin
--     de la frappe), puces (Toutes, un type par type présent, Brillantes,
--     Favoris), la section « Voile d'hiver » en tête en saison
--     (WinterCompanions.lua, trois petits modèles 3D), puis la grille des
--     apparences, 8 par rangée, à la molette : mascottes gagnées, créatures
--     capturées (par type puis par nom), mascottes pas encore gagnées
--     (grisées, leur condition en infobulle, pas choisissables) ;
--   * clic : la choisir (le même chemin que l'ancien carrousel :
--     CompanionAskAppearance, sa confirmation qui compare les effets et le
--     délai des effets) ; Maj+clic : favori (CompanionData().allureFav) ;
--   * une espèce capturée en brillante a deux vignettes côte à côte : la
--     normale (« cap:<pnj> ») et la brillante (« cap:<pnj>:s », portrait
--     teinté d'or, perle en coin, liseré doré). La version choisie est
--     l'apparence elle-même : le compagnon prend la lumière dorée (Companion.lua,
--     ModelShinyLight), comme partout ailleurs.
-- Vignettes : portraits 2D (SetPortraitTextureFromCreatureDisplayID par
-- ns:CreaturePortrait) quand le displayID de l'espèce est connu ; la grille
-- garde 8 × ALLURE_ROWS_MAX tuiles construites une fois et repeintes au
-- défilement (aucune création par rafraîchissement).
-- 2.14.0 (bêta 3) : presque toutes les créatures capturées n'avaient pas de
-- displayID appris : la même icône de type (le loup des bêtes) partout. Une
-- vignette sans displayID montre désormais la créature elle-même dans un
-- petit modèle 3D (SetCreature) : un modèle par tuile, créé à son premier
-- besoin et réutilisé au défilement (au plus 8 × ALLURE_ROWS_MAX), cadré
-- comme dans le cadre du compagnon (CompanionModelCam, cadrage « pied »).
-- En fond, les displayID manquants s'apprennent (ns:ModelLearnCreatures,
-- Companion.lua : les vignettes visibles d'abord, ≈ 3 par seconde, jamais en
-- combat) : la fois suivante, le portrait 2D. L'icône du type ne reste que
-- si le client ne sait montrer ni l'un ni l'autre.
-- Deux habits : Sobre (socle) et Azeroth (parchemin des confirmations,
-- JournalAzeroth.lua : ns.CarnetSkinDialog, encres mesurées « allure.* »).
-- Un panneau par style, construit à la première ouverture ; changer de style
-- panneau ouvert le rouvre dans le nouveau style (CarnetRestyle).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	ALLURE_CHOOSE     = "Choisir…",
	ALLURE_TITLE      = "Choisir son allure",
	ALLURE_SUB        = "Clic : l'emmener sous cette allure. Maj+clic : favori.",
	ALLURE_SEARCH     = "Chercher un nom",
	ALLURE_ALL        = "Toutes",
	ALLURE_SHINY      = "Brillantes",
	ALLURE_FAV        = "Favoris",
	ALLURE_SEASON     = "Voile d'hiver",
	ALLURE_MINE       = "Ses apparences",
	ALLURE_COUNT      = "%d sur %d",
	ALLURE_EMPTY      = "Aucune apparence ne correspond.",
	ALLURE_EMPTY_FAV  = "Pas encore de favori : Maj+clic sur une vignette.",
	ALLURE_MASCOT     = "Mascotte",
	ALLURE_SEASONAL   = "Compagnon de saison",
	ALLURE_SHINY_OF   = "%s, version brillante",
	ALLURE_CARD_COUNT = "%d apparences à choisir",
	ALLURE_TIP_CLICK  = "Clic : l'emmener sous cette allure.",
	ALLURE_TIP_WORN   = "C'est son allure du moment.",
	ALLURE_TIP_FAV    = "Maj+clic : l'ajouter aux favoris.",
	ALLURE_TIP_UNFAV  = "Maj+clic : la retirer des favoris.",
	ALLURE_TIP_SHINY  = "Version brillante : il brille d'une lumière dorée.",
	ALLURE_TIP_NORMAL = "Tu as aussi sa version brillante, juste à côté.",
	ALLURE_TIP_LOCKED = "Pas encore gagnée : %s",
	ALLURE_TIP_SEASON = "Le temps des fêtes : son allure habituelle revient d'elle-même ensuite.",
}
local EN = {
	ALLURE_CHOOSE     = "Choose…",
	ALLURE_TITLE      = "Choose its look",
	ALLURE_SUB        = "Click: take this look. Shift+click: favourite.",
	ALLURE_SEARCH     = "Search a name",
	ALLURE_ALL        = "All",
	ALLURE_SHINY      = "Shiny",
	ALLURE_FAV        = "Favourites",
	ALLURE_SEASON     = "Winter Veil",
	ALLURE_MINE       = "Its looks",
	ALLURE_COUNT      = "%d of %d",
	ALLURE_EMPTY      = "No look matches.",
	ALLURE_EMPTY_FAV  = "No favourite yet: Shift+click a tile.",
	ALLURE_MASCOT     = "Mascot",
	ALLURE_SEASONAL   = "Seasonal companion",
	ALLURE_SHINY_OF   = "%s, shiny version",
	ALLURE_CARD_COUNT = "%d looks to choose from",
	ALLURE_TIP_CLICK  = "Click: take this look.",
	ALLURE_TIP_WORN   = "This is its current look.",
	ALLURE_TIP_FAV    = "Shift+click: add to favourites.",
	ALLURE_TIP_UNFAV  = "Shift+click: remove from favourites.",
	ALLURE_TIP_SHINY  = "Shiny version: it glows with a golden light.",
	ALLURE_TIP_NORMAL = "You also have its shiny version, right next to it.",
	ALLURE_TIP_LOCKED = "Not earned yet: %s",
	ALLURE_TIP_SEASON = "Holiday time: its usual look comes back on its own afterwards.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.ALLURE_STRINGS = { fr = FR, en = EN } end

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------
ns.ALLURE_W, ns.ALLURE_H = 560, 580
ns.ALLURE_COLS, ns.ALLURE_ROWS_MAX = 8, 5
ns.ALLURE_TILE_W, ns.ALLURE_TILE_H, ns.ALLURE_GAP = 58, 74, 7
ns.ALLURE_PORTRAIT = 46
ns.ALLURE_STRATA = "FULLSCREEN"          -- au-dessus du carnet (DIALOG), sous la confirmation (FULLSCREEN_DIALOG)
ns.ALLURE_LEVEL_UP = 30
-- la perle des brillantes (icône du haut fait « Brillantes », FeatsData.lua)
ns.ALLURE_SHINY_ICON = "Interface\\Icons\\INV_Misc_Gem_Pearl_04"
-- l'étoile du jeu (vérifiée en jeu, ns.MEN_STAR)
ns.ALLURE_FAV_ATLAS = "auctionhouse-icon-favorite"

local function G(name) return rawget(_G, name) end
local function InCombat()
	local fn = G("InCombatLockdown")
	return type(fn) == "function" and fn() and true or false
end
local function ShiftDown()
	local fn = G("IsShiftKeyDown")
	return type(fn) == "function" and fn() and true or false
end
local function Fold(text)
	if ns.OptionFold then return ns.OptionFold(text) end
	return ns.AsciiLower and ns.AsciiLower(tostring(text or "")) or tostring(text or "")
end
local function UI() return ns.JournalUI or {} end
local function Tip(owner, title, lines)
	local fn = UI().Tip
	if fn then fn(owner, title, lines) end
end
local function HideTip()
	local fn = UI().HideTip
	if fn then fn() end
end
local function Az(frame) return frame and frame.uiStyle == "azeroth" end
-- encre d'un rôle mesuré (Azeroth) ou jeton du socle (Sobre)
local function Ink(fs, frame, role, token, shadow)
	if not fs then return end
	if Az(frame) and ns.CarnetRolePaint then
		ns.CarnetRolePaint(fs, role, shadow)
	else
		fs:SetTextColor(token[1], token[2], token[3], 1)
	end
end

-- ---------------------------------------------------------------------------
-- Ce qu'on sait d'une apparence (gardé par déf : la liste des captures est
-- refaite quand la ménagerie change, Capture.lua)
-- ---------------------------------------------------------------------------
local META = setmetatable({}, { __mode = "k" })
local MASCOT_ORDER = {}
for index, def in ipairs(ns.COMPANION_APPEARANCES or {}) do MASCOT_ORDER[def] = index end
local TYPE_ORDER = {}
for index, key in ipairs(ns.CREATURE_TYPES or {}) do TYPE_ORDER[key] = index end

local function Meta(self, def)
	local m = META[def]
	if m then return m end
	m = {}
	local name = tostring(L[def.label] or def.label or def.id)
	m.name = name
	if def.seasonal then
		m.kind = "season"
	elseif def.captured then
		m.kind = "capture"
		local data = self.CaptureData and self:CaptureData()
		local entry = data and data.creatures and data.creatures[def.npc]
		-- 2.14.0 (bêta 4) : le nom, pas le numéro (CreatureName, Bestiary.lua)
		m.base = tostring(entry and self.CreatureName and self:CreatureName(def.npc, entry) or entry and entry.name or name)
		m.typeText = entry and entry.type or nil
		m.typeKey = (entry and self.CreatureTypeKey and self:CreatureTypeKey(entry.type)) or nil
		m.baseFold = Fold(m.base)
	else
		m.kind = "mascot"
		m.order = MASCOT_ORDER[def] or 999
	end
	m.fold = Fold(name)
	META[def] = m
	return m
end
function ns:AllureMeta(def) return def and Meta(self, def) or nil end

-- Favoris : par personnage, avec son allure (CompanionData)
function ns:AllureFavs()
	local data = self:CompanionData()
	if type(data.allureFav) ~= "table" then data.allureFav = {} end
	return data.allureFav
end
function ns:AllureIsFav(id) return self:AllureFavs()[id or ""] == true end
function ns:AllureToggleFav(id)
	if not id then return nil end
	local favs = self:AllureFavs()
	favs[id] = not favs[id] or nil
	self:AllureRefresh()
	return favs[id] == true
end

-- ---------------------------------------------------------------------------
-- Les listes du panneau : la saison, puis la grille. filter = "all",
-- "t:<type>", "shiny", "fav" ; search : texte tapé. Les deux tables sont
-- réutilisées d'un appel à l'autre.
-- ---------------------------------------------------------------------------
local seasonList, gridList, typesSeen, learnList = {}, {}, {}, {}
local function Wipe(t) for key in pairs(t) do t[key] = nil end end
local function Rank(self, def, m)
	if m.kind == "mascot" then return self:CompanionIsUnlocked("app", def) and 1 or 3 end
	return 2
end
local function Before(a, b)
	local ma, mb = META[a], META[b]
	if ma.rank ~= mb.rank then return ma.rank < mb.rank end
	if ma.kind == "mascot" then return ma.order < mb.order end
	local ta, tb = TYPE_ORDER[ma.typeKey or ""] or 99, TYPE_ORDER[mb.typeKey or ""] or 99
	if ta ~= tb then return ta < tb end
	if ma.baseFold ~= mb.baseFold then return ma.baseFold < mb.baseFold end
	local sa, sb = a.shiny and 1 or 0, b.shiny and 1 or 0
	if sa ~= sb then return sa < sb end
	return a.id < b.id
end
local function Keep(self, def, m, filter, needle)
	if needle and not m.fold:find(needle, 1, true) then return false end
	if filter == "all" or filter == nil then return true end
	if filter == "fav" then return self:AllureIsFav(def.id) end
	if filter == "shiny" then return def.shiny == true end
	local key = filter:match("^t:(.+)$")
	return key ~= nil and m.typeKey == key
end
function ns:AllureList(filter, search)
	Wipe(seasonList); Wipe(gridList); Wipe(typesSeen)
	local needle = search and search ~= "" and Fold(search) or nil
	if needle == "" then needle = nil end
	local total = 0
	for _, def in ipairs(self:CompanionAllAppearances()) do
		local m = Meta(self, def)
		m.rank = Rank(self, def, m)
		total = total + 1
		if m.typeKey then typesSeen[m.typeKey] = true end
		if Keep(self, def, m, filter, needle) then
			if m.kind == "season" then seasonList[#seasonList + 1] = def else gridList[#gridList + 1] = def end
		end
	end
	table.sort(gridList, Before)
	return seasonList, gridList, total, typesSeen
end

-- Le chemin de l'ancien carrousel : confirmation qui compare les effets
-- (CompanionEffects.lua), sinon le choix direct. Rend comme
-- CompanionAskAppearance (déf, "ask" ou nil si verrouillée).
function ns:AllureChoose(id)
	local def = id and self:CompanionAppearanceDef(id)
	if not (def and self:CompanionIsUnlocked("app", def)) then return nil end
	local function Done()
		if ns.CompanionApplyModel then pcall(ns.CompanionApplyModel, ns) end
		ns:RefreshJournal()
		ns:AllureRefresh()
	end
	if self.CompanionAskAppearance then return self:CompanionAskAppearance(def.id, Done) end
	local done = self:CompanionSetAppearance(def.id)
	if done then Done() end
	return done
end

-- ---------------------------------------------------------------------------
-- Une vignette : portrait 2D rond (ou petit modèle 3D pour la saison), nom,
-- étoile de favori, perle de brillante, liseré de l'allure portée
-- ---------------------------------------------------------------------------
local function Badge(tile, layer, size)
	local tex = tile:CreateTexture(nil, layer, nil, 3)
	tex:SetSize(size, size)
	tex:Hide()
	return tex
end

-- Le petit modèle d'une tuile : créé à son premier besoin, gardé ensuite
local function TileModel(tile)
	if tile.model then return tile.model end
	if tile.noModel then return nil end
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, tile)
	if not (ok and model) then tile.noModel = true; return nil end
	model:SetPoint("TOP", tile, "TOP", 0, -5)
	model:SetSize((tile.tileW or ns.ALLURE_TILE_W) - 6, tile.portraitSize or ns.ALLURE_PORTRAIT)
	if model.EnableMouse then model:EnableMouse(false) end
	tile.model = model
	return model
end

-- 2.15.0 : opts = { w, h, portrait } (la Réserve du carnet reprend ces
-- vignettes, un peu plus hautes pour ses étoiles : JournalReserve.lua)
local function NewTile(frame, parent, seasonal, opts)
	opts = opts or {}
	local TW, TH, P = opts.w or ns.ALLURE_TILE_W, opts.h or ns.ALLURE_TILE_H, opts.portrait or ns.ALLURE_PORTRAIT
	local tile = Theme.CreateTile(parent, TW, TH, { accent = "top" })
	tile.tileW, tile.portraitSize = TW, P
	if tile.RegisterForClicks then tile:RegisterForClicks("LeftButtonUp") end
	tile.seasonal = seasonal and true or false
	if seasonal then TileModel(tile) end
	tile.portrait = tile:CreateTexture(nil, "ARTWORK", nil, 1)
	tile.portrait:SetSize(P, P)
	tile.portrait:SetPoint("TOP", tile, "TOP", 0, -6)
	tile.label = Theme.Text(tile, Theme.F_SMALL, Theme.LABEL)
	tile.label:SetPoint("BOTTOM", tile, "BOTTOM", 0, 5)
	tile.label:SetWidth(TW - 6)
	tile.label:SetJustifyH("CENTER")
	if tile.label.SetWordWrap then tile.label:SetWordWrap(false) end
	tile.fav = Badge(tile, "OVERLAY", 13)
	tile.fav:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -4)
	local okAtlas = ns.AzerothAtlas and ns.AzerothAtlas(tile.fav, ns.ALLURE_FAV_ATLAS)
	if not okAtlas then pcall(tile.fav.SetAtlas, tile.fav, ns.ALLURE_FAV_ATLAS) end
	tile.gem = Badge(tile, "OVERLAY", 14)
	tile.gem:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -3, -4)
	tile.gem:SetTexture(ns.ALLURE_SHINY_ICON)
	tile.gem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- le liseré de l'allure portée : deux filets dorés (le cadre et 1 px dedans)
	tile.inset = tile:CreateTexture(nil, "BACKGROUND", nil, 0)
	tile.inset:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
	tile.inset:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
	tile.ring = Theme.Border(tile, Theme.GOLD, 1, "OVERLAY")
	tile.ringIn = Theme.Border(tile, Theme.GOLD, 1, "OVERLAY", tile.inset)
	tile.onEnter = function(t) ns:AllureTileTip(t) end
	tile.onLeave = HideTip
	tile:SetScript("OnClick", function(t) ns:AllureTileClick(t) end)
	tile.frame = frame
	return tile
end

local function ShowRing(tile, on, frame)
	local c = Az(frame) and ns.AZEROTH_INK.catGold or Theme.GOLD
	for _, ring in ipairs({ tile.ring, tile.ringIn }) do
		ring:SetColor(c[1], c[2], c[3], on and 1 or 0)
	end
end

-- Ce que montre une tuile : le portrait 2D (displayID connu, client qui
-- sait le peindre), sinon le petit modèle de la créature, sinon l'icône du
-- type. Rechargé seulement quand l'apparence ou sa façon de la montrer
-- changent (lookKey). Rend "portrait", "model" ou "icon".
local function CanPortrait() return type(G("SetPortraitTextureFromCreatureDisplayID")) == "function" end
-- 2.14.0 (bêta 6) : les vignettes de saison prennent aussi le portrait 2D
-- (ns:WinterPortraitDisplay, WinterCompanions.lua : Metzen par l'affichage du
-- Renne de l'Hiver, les deux autres par leur displayID appris) ; portrait
-- refusé par le client : le petit modèle 3D d'avant.
local function SeasonDisplay(self, def)
	return self.WinterPortraitDisplay and self:WinterPortraitDisplay(def.npc) or nil
end
local function PaintLook(self, tile, def, m)
	local display = def.display
	if tile.seasonal then
		display = SeasonDisplay(self, def)
	elseif not display and def.npc and self.ModelKnownDisplay then
		display = self:ModelKnownDisplay(def.npc)
	end
	local want3d = def.npc ~= nil and not (display and CanPortrait())
	local key = def.id .. (want3d and ":m" or ":p") .. tostring(tile.seasonal and display or "")
	if tile.lookKey ~= key then
		tile.lookKey, tile.look = key, nil
		if not want3d and tile.seasonal then
			if tile.model and ns.ModelForget then ns.ModelForget(tile.model) end
			local look = self.CreaturePortrait and self:CreaturePortrait(tile.portrait, { display = display, npc = def.npc, type = m.typeText })
			if look == "portrait" then tile.look = "portrait" else want3d = true end
		end
		if want3d then
			local model = TileModel(tile)
			local cam, y, facing
			if self.CompanionModelCam then
				cam, y, facing = self:CompanionModelCam({ npc = def.npc, type = m.typeText }, "pied")
			end
			if model and ns.ShowModel and ns.ShowModel(model, { npc = def.npc, shiny = def.shiny,
				cam = cam, y = y, facing = facing }, "tile") then
				tile.look = "model"
			end
		end
		if tile.look ~= "model" and tile.look ~= "portrait" then
			if tile.model and ns.ModelForget then ns.ModelForget(tile.model) end
			tile.look = self.CreaturePortrait and self:CreaturePortrait(tile.portrait,
				{ display = display, npc = def.npc, type = m.typeText }) or "icon"
		end
	end
	return tile.look
end

-- Le portrait, le modèle ou l'icône d'une vignette, montré (et l'autre
-- caché) ; 2.15.0 : repris par la Réserve (ns:AllureTileLook)
local function ShowLook(self, tile, def, m, locked)
	if PaintLook(self, tile, def, m) == "model" then
		tile.portrait:Hide()
		tile.model:Show()
		return "model"
	end
	if tile.model then tile.model:Hide() end
	local tint = def.shiny and Theme.SHINY or Theme.WHITE
	tile.portrait:SetVertexColor(tint[1], tint[2], tint[3], 1)
	if tile.portrait.SetDesaturated then tile.portrait:SetDesaturated(locked and true or false) end
	tile.portrait:SetAlpha(locked and Theme.DIM_ALPHA or 1)
	tile.portrait:Show()
	return tile.look
end

local function PaintTile(self, tile, def, current)
	local frame = tile.frame
	tile.def = def
	if not def then
		tile:Hide()
		return
	end
	local m = Meta(self, def)
	local locked = not self:CompanionIsUnlocked("app", def)
	tile.locked = locked
	tile.label:SetText(m.kind == "capture" and m.base or m.name)
	-- portrait, modèle ou icône (rechargé seulement s'il change)
	ShowLook(self, tile, def, m, locked)
	-- encres : nom, grisé, brillante
	if locked then
		Ink(tile.label, frame, "allure.locked", Theme.MUTED)
	elseif def.shiny then
		Ink(tile.label, frame, "allure.shiny", Theme.GOLD_LIGHT)
	else
		Ink(tile.label, frame, "allure.name", Theme.LABEL)
	end
	if self:AllureIsFav(def.id) then tile.fav:Show() else tile.fav:Hide() end
	if def.shiny then tile.gem:Show() else tile.gem:Hide() end
	local worn = current and current.id == def.id or false
	tile.worn = worn
	local rarity = def.captured and ns.CAPTURE_RARITY and ns.CAPTURE_RARITY[def.class or "normal"]
	tile:SetAccent(worn and Theme.GOLD or (def.shiny and Theme.GOLD_LIGHT) or (rarity and rarity.color) or nil)
	tile:SetSelected(worn)
	ShowRing(tile, worn, frame)
	tile:Show()
end

-- ---------------------------------------------------------------------------
-- 2.15.0 : les vignettes prêtées à la Réserve du carnet (JournalReserve.lua)
-- ---------------------------------------------------------------------------
-- Une vignette neuve (construite une fois, réutilisée) ; le module pose ses
-- propres OnClick, onEnter, onLeave par-dessus
function ns.AllureNewTile(frame, parent, opts) return NewTile(frame, parent, false, opts) end
-- Montre une espèce (npc, brillante) : portrait 2D, sinon petit modèle 3D,
-- sinon l'icône du type. look = { id, npc, shiny, display, typeText } (id :
-- clé de rechargement, « cap:<npc>[:s] »). Rend "portrait", "model" ou "icon".
function ns:AllureTileLook(tile, look)
	if not (tile and look) then return nil end
	return ShowLook(self, tile, look, { typeText = look.typeText }, false)
end
function ns.AllureShowRing(tile, on, frame) ShowRing(tile, on, frame) end

function ns:AllureTileTip(tile)
	local def = tile and tile.def
	if not def then return end
	local m = Meta(self, def)
	local lines = {}
	if m.kind == "season" then
		lines[#lines + 1] = L.ALLURE_SEASONAL
		lines[#lines + 1] = L.ALLURE_TIP_SEASON
	elseif m.kind == "mascot" then
		lines[#lines + 1] = L.ALLURE_MASCOT
	else
		local typeLabel = m.typeKey and self.CreatureTypeLabel and self:CreatureTypeLabel(m.typeKey) or m.typeText
		if typeLabel then lines[#lines + 1] = tostring(typeLabel) end
		-- 3.1.0 : la taille et le caractère du spécimen du Codex (celui qu'il portera)
		local ref = def.npc and self.SpecimenReference and self:SpecimenReference(def.npc, def.shiny and true or false)
		if ref and self.SpecimenTagsShort then lines[#lines + 1] = self:SpecimenTagsShort(ref) end
		if def.shiny then
			lines[#lines + 1] = L.ALLURE_TIP_SHINY
		else
			local entry = self.CaptureData and self:CaptureData().creatures[def.npc]
			if entry and entry.shiny then lines[#lines + 1] = L.ALLURE_TIP_NORMAL end
		end
	end
	if tile.locked then
		lines[#lines + 1] = self:F("ALLURE_TIP_LOCKED", self:CompanionLockText(def))
	else
		lines[#lines + 1] = tile.worn and L.ALLURE_TIP_WORN or L.ALLURE_TIP_CLICK
		lines[#lines + 1] = self:AllureIsFav(def.id) and L.ALLURE_TIP_UNFAV or L.ALLURE_TIP_FAV
	end
	Tip(tile, def.shiny and self:F("ALLURE_SHINY_OF", m.base or m.name) or m.name, lines)
end

-- Clic : choisir ; Maj+clic : favori. Une mascotte pas encore gagnée ne se
-- choisit pas (ni ne se met en favori).
function ns:AllureTileClick(tile)
	local def = tile and tile.def
	if not def or tile.locked then return nil end
	if ShiftDown() then return self:AllureToggleFav(def.id) end
	return self:AllureChoose(def.id)
end

-- ---------------------------------------------------------------------------
-- Le panneau
-- ---------------------------------------------------------------------------
local FILTERS = { "all" }
for _, key in ipairs(ns.CREATURE_TYPES or {}) do FILTERS[#FILTERS + 1] = "t:" .. key end
FILTERS[#FILTERS + 1] = "shiny"
FILTERS[#FILTERS + 1] = "fav"
ns.ALLURE_FILTERS = FILTERS

local function FilterLabel(id)
	if id == "all" then return L.ALLURE_ALL end
	if id == "shiny" then return L.ALLURE_SHINY end
	if id == "fav" then return L.ALLURE_FAV end
	local key = id:match("^t:(.+)$")
	return key and ns.CreatureTypeLabel and ns:CreatureTypeLabel(key) or id
end

local function Build(self)
	if not (Theme and Theme.CreateDialog) then return nil end
	local W, H = ns.ALLURE_W, ns.ALLURE_H
	local frame = Theme.CreateDialog(UIParent, W, H, { title = L.ALLURE_TITLE, subtitle = L.ALLURE_SUB, footer = false })
	if not frame then return nil end
	frame:SetFrameStrata(ns.ALLURE_STRATA)
	if frame.SetToplevel then pcall(frame.SetToplevel, frame, true) end
	if frame.close then frame.close:SetScript("OnClick", function() ns:AllureClose() end) end
	frame:SetScript("OnKeyDown", function(f, key)
		local esc = key == "ESCAPE"
		if f.SetPropagateKeyboardInput and not InCombat() then pcall(f.SetPropagateKeyboardInput, f, not esc) end
		if esc then ns:AllureClose() end
	end)
	frame.filter, frame.search, frame.offset = "all", "", 0
	local x0, top = frame.pad, frame.contentTop
	-- recherche, à la fin de la frappe (comme les Créatures du carnet)
	frame.searchBox = Theme.CreateSearchBox(frame, 220, L.ALLURE_SEARCH, function(text)
		frame.search = text or ""
		frame.offset = 0
		if frame.search == "" then ns:AllureRefresh() else ns:AllureSoon() end
	end)
	frame.searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, top - 10)
	if frame.searchBox.HookScript then
		frame.searchBox:HookScript("OnEnterPressed", function() ns:AllureRefresh() end)
	end
	-- puces : toutes construites, celles des types absents cachées
	local defs = {}
	for _, id in ipairs(FILTERS) do defs[#defs + 1] = { id = id, label = FilterLabel(id) } end
	frame.chips = Theme.CreateChips(frame, defs, function(id)
		frame.filter = id
		frame.offset = 0
		ns:AllureRefresh()
	end)
	frame.chips:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, top - 44)
	-- la saison : trois petits modèles
	frame.seasonTitle = Theme.CreateSection(frame, L.ALLURE_SEASON)
	frame.seasonTitle:SetWidth(frame.innerWidth)
	frame.seasonTiles = {}
	for index = 1, #(ns.WINTER_COMPANIONS or {}) do frame.seasonTiles[index] = NewTile(frame, frame, true) end
	-- la grille
	frame.mineTitle = Theme.CreateSection(frame, L.ALLURE_MINE)
	frame.mineTitle:SetWidth(frame.innerWidth - 140)
	frame.pager = Theme.CreatePager(frame, function(step) ns:AllureScroll(-step) end)
	frame.grid = CreateFrame("Frame", nil, frame)
	frame.grid:SetSize(frame.innerWidth, 10)
	if frame.grid.EnableMouseWheel then frame.grid:EnableMouseWheel(true) end
	frame.grid:SetScript("OnMouseWheel", function(_, delta) ns:AllureScroll(-(tonumber(delta) or 0)) end)
	if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
	frame:SetScript("OnMouseWheel", function(_, delta) ns:AllureScroll(-(tonumber(delta) or 0)) end)
	frame.tiles = {}
	for index = 1, ns.ALLURE_COLS * ns.ALLURE_ROWS_MAX do frame.tiles[index] = NewTile(frame, frame.grid, false) end
	frame.empty = Theme.Text(frame.grid, Theme.F_BODY, Theme.MUTED_LIGHT)
	frame.empty:SetPoint("TOP", frame.grid, "TOP", 0, -24)
	frame.empty:SetWidth(frame.innerWidth - 40)
	frame.empty:SetJustifyH("CENTER")
	-- le texte de la fenêtre (l'habit Azeroth des confirmations lui donne son encre)
	frame.text = frame.empty
	frame:Hide()
	return frame
end

-- Le panneau du style en cours, construit une fois par style
function ns:EnsureAllure()
	local style = (self.JournalStyle and self:JournalStyle()) or "sobre"
	self.allureByStyle = self.allureByStyle or {}
	local frame = self.allureByStyle[style]
	if frame then self.allurePanel = frame; return frame end
	if style == "azeroth" and ns.CarnetCaptureRun and ns.CarnetSkinDialog then
		local reg = { new = {}, texts = {} }
		local ok, made = pcall(ns.CarnetCaptureRun, reg, Build, self)
		frame = ok and made or nil
		if frame then
			frame.uiStyle, frame.azReg = "azeroth", reg
			local skinned, err = pcall(ns.CarnetSkinDialog, self, frame, reg)
			if not skinned and self.RecordError then self:RecordError("allure:skin", err) end
		elseif not ok and self.RecordError then
			self:RecordError("allure:build", made)
		end
	end
	if not frame then
		frame = Build(self)
		if frame then frame.uiStyle = "sobre" end
		style = "sobre"
	end
	if not frame then return nil end
	self.allureByStyle[frame.uiStyle] = frame
	self.allurePanel = frame
	return frame
end

-- Posé sur le carnet ouvert, un cran au-dessus ; fermé avec lui
local function Place(self, frame)
	local journal = self.journalFrame
	frame:ClearAllPoints()
	frame:SetFrameStrata(ns.ALLURE_STRATA)
	if journal and journal.IsShown and journal:IsShown() then
		frame:SetPoint("CENTER", journal, "CENTER", 0, 0)
		local level = (journal.GetFrameLevel and tonumber(journal:GetFrameLevel()) or 1) + ns.ALLURE_LEVEL_UP
		if frame.SetFrameLevel then frame:SetFrameLevel(level) end
		if not journal.qcAllureHooked and journal.HookScript then
			journal.qcAllureHooked = true
			journal:HookScript("OnHide", function() ns:AllureOnJournalHide() end)
		end
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	if frame.Raise then frame:Raise() end
	local keys = not InCombat()
	if frame.EnableKeyboard then pcall(frame.EnableKeyboard, frame, keys) end
	if keys and frame.SetPropagateKeyboardInput then pcall(frame.SetPropagateKeyboardInput, frame, true) end
end

function ns:AllureOnJournalHide() self:AllureClose() end

function ns:AllureOpen()
	local frame = self:EnsureAllure()
	if not frame then return nil end
	-- l'autre style a pu rester ouvert (changement de style) : fermé
	for _, other in pairs(self.allureByStyle or {}) do
		if other ~= frame and other:IsShown() then other:Hide() end
	end
	Place(self, frame)
	frame.offset = 0
	frame:Show()
	self:AllureRefresh()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.15) end
	return frame
end

function ns:AllureClose()
	local frame = self.allurePanel
	HideTip()
	-- l'apprentissage des displayID s'arrête avec le panneau
	if self.ModelLearnStop then self:ModelLearnStop() end
	if frame and frame:IsShown() then
		if frame.searchBox and frame.searchBox.ClearFocus then frame.searchBox:ClearFocus() end
		frame:Hide()
		return true
	end
	return false
end

function ns:AllureShown()
	local frame = self.allurePanel
	return frame and frame:IsShown() and true or false
end

-- Défilement par rangées (molette, chevrons)
function ns:AllureScroll(delta)
	local frame = self.allurePanel
	if not (frame and frame:IsShown()) then return end
	frame.offset = math.max(0, math.min((frame.offset or 0) + (tonumber(delta) or 0), frame.maxOffset or 0))
	self:AllureRefresh()
end

-- Recherche : un seul rafraîchissement à la fin de la frappe (sans C_Timer :
-- tout de suite)
local soon = 0
function ns:AllureSoon()
	local timer = G("C_Timer")
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return self:AllureRefresh() end
	soon = soon + 1
	local mine = soon
	timer.After(ns.JOURNAL_SEARCH_DELAY or 0.25, function()
		if soon == mine then ns:AllureRefresh() end
	end)
end

-- Puces des types présents, à la ligne quand la place manque ; rend le
-- nombre de rangées de puces
local function LayoutChips(frame, types)
	local row, width = frame.chips, frame.innerWidth
	local x, y, rows, gap = 0, 0, 1, 6
	for _, chip in ipairs(row.chips) do
		local key = chip.id:match("^t:(.+)$")
		local visible = not key or types[key] == true
		if visible then
			local w = chip:GetWidth() or 60
			if x > 0 and x + w > width then x, y, rows = 0, y + Theme.CHIP_HEIGHT + 6, rows + 1 end
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", row, "TOPLEFT", x, -y)
			x = x + w + gap
			chip:Show()
		else
			chip:Hide()
		end
	end
	row:SetSize(width, rows * Theme.CHIP_HEIGHT + (rows - 1) * 6)
	return rows
end

-- Pose les sections et compte les rangées visibles de la grille
local function Layout(frame, chipRows, seasonOn)
	local x0 = frame.pad
	local y = frame.contentTop - 44 - chipRows * Theme.CHIP_HEIGHT - (chipRows - 1) * 6 - 12
	local TW, TH, GAP = ns.ALLURE_TILE_W, ns.ALLURE_TILE_H, ns.ALLURE_GAP
	if seasonOn then
		frame.seasonTitle:ClearAllPoints()
		frame.seasonTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, y)
		frame.seasonTitle:Show()
		y = y - 22
		for index, tile in ipairs(frame.seasonTiles) do
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", frame, "TOPLEFT", x0 + (index - 1) * (TW + GAP), y)
		end
		y = y - TH - 12
	else
		frame.seasonTitle:Hide()
		for _, tile in ipairs(frame.seasonTiles) do tile:Hide() end
	end
	frame.mineTitle:ClearAllPoints()
	frame.mineTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, y)
	frame.pager:ClearAllPoints()
	frame.pager:SetPoint("TOPRIGHT", frame, "TOPLEFT", x0 + frame.innerWidth, y + 1)
	y = y - 24
	frame.grid:ClearAllPoints()
	frame.grid:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, y)
	local room = ns.ALLURE_H + y - 16
	local rows = math.max(1, math.min(ns.ALLURE_ROWS_MAX, math.floor((room + GAP) / (TH + GAP))))
	frame.grid:SetSize(frame.innerWidth, rows * (TH + GAP) - GAP)
	frame.rows = rows
	return rows
end

function ns:AllureRefresh()
	local frame = self.allurePanel
	if not (frame and frame:IsShown()) then return nil end
	local season, grid, total, types = self:AllureList(frame.filter, frame.search)
	-- un filtre de type dont plus rien n'existe : retour à « Toutes »
	local key = frame.filter and frame.filter:match("^t:(.+)$")
	if key and not types[key] then
		frame.filter = "all"
		season, grid, total, types = self:AllureList(frame.filter, frame.search)
	end
	if frame.chips.selected ~= frame.filter then frame.chips:Select(frame.filter, true) end
	local chipRows = LayoutChips(frame, types)
	local current = self:CompanionCurrentAppearance()
	local seasonOn = #season > 0
	local rows = Layout(frame, chipRows, seasonOn)
	if seasonOn then
		for index, tile in ipairs(frame.seasonTiles) do PaintTile(self, tile, season[index], current) end
	end
	local cols = ns.ALLURE_COLS
	local totalRows = math.ceil(#grid / cols)
	frame.maxOffset = math.max(0, totalRows - rows)
	frame.offset = math.max(0, math.min(frame.offset or 0, frame.maxOffset))
	local first = frame.offset * cols
	local TW, TH, GAP = ns.ALLURE_TILE_W, ns.ALLURE_TILE_H, ns.ALLURE_GAP
	for index, tile in ipairs(frame.tiles) do
		local slot = index - 1
		local r = math.floor(slot / cols)
		if r < rows then
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", frame.grid, "TOPLEFT", (slot % cols) * (TW + GAP), -r * (TH + GAP))
			PaintTile(self, tile, grid[first + index], current)
		else
			tile.def = nil
			tile:Hide()
		end
	end
	frame.pager:Update(frame.offset, rows, totalRows, frame.maxOffset)
	-- les displayID manquants, appris en fond : les vignettes visibles d'abord
	if self.ModelLearnCreatures then
		Wipe(learnList)
		local last = first + rows * cols
		for pass = 1, 2 do
			for index, def in ipairs(grid) do
				local seen = index > first and index <= last
				if def.npc and not def.display and seen == (pass == 1) then learnList[#learnList + 1] = def.npc end
			end
		end
		-- 2.14.0 (bêta 6) : les compagnons de saison en dernier (leur portrait 2D)
		if seasonOn and self.WinterPortraitToLearn then
			for _, npc in ipairs(self:WinterPortraitToLearn()) do learnList[#learnList + 1] = npc end
		end
		self:ModelLearnCreatures(learnList)
	end
	frame.mineTitle:SetText(L.ALLURE_MINE, self:F("ALLURE_COUNT", #grid + #season, total))
	if #grid == 0 then
		frame.empty:SetText(frame.filter == "fav" and (frame.search or "") == "" and L.ALLURE_EMPTY_FAV or L.ALLURE_EMPTY)
		frame.empty:Show()
	else
		frame.empty:SetText("")
		frame.empty:Hide()
	end
	-- encres des textes du panneau (les vignettes ont les leurs)
	for _, section in ipairs({ frame.seasonTitle, frame.mineTitle }) do
		Ink(section.label, frame, "allure.section", Theme.MUTED_LIGHT)
		Ink(section.detail, frame, "allure.hint", Theme.MUTED)
	end
	Ink(frame.empty, frame, "allure.text", Theme.MUTED_LIGHT)
	Ink(frame.pager.position, frame, "allure.hint", Theme.MUTED_LIGHT)
	return #grid, #season
end

-- Changer de style panneau ouvert : rouvert dans le nouveau (le carnet,
-- lui, est remplacé par CarnetRestyle)
do
	local restyle = ns.CarnetRestyle
	if restyle then
		function ns:CarnetRestyle(...)
			local open = self:AllureShown()
			local before = open and self.allurePanel
			local a, b = restyle(self, ...)
			local want = self.JournalStyle and self:JournalStyle() or "sobre"
			if before and before.uiStyle ~= want then
				before:Hide()
				local journal = self.journalFrame
				if journal and journal:IsShown() then self:AllureOpen() end
			end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Page Compagnon du carnet : l'allure portée et « Choisir… »
-- (JournalWindow.lua appelle ces deux fonctions)
-- ---------------------------------------------------------------------------
function ns:AllureBuildCard(pane, content, x, y, width, height)
	local ui = UI()
	if not (ui.At and ui.Text and Theme.CreateTile) then return end
	local card = Theme.CreateTile(pane, width, height, { kind = "Frame", accent = "top" })
	ui.At(card, content, x, y)
	pane.lookCard = card
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, card)
	if ok and model then
		model:SetPoint("LEFT", card, "LEFT", 6, 0)
		model:SetSize(56, height - 8)
		card.model = model
	end
	-- 2.14.0 (bêta 6) : le portrait 2D rond d'un compagnon de saison
	local side = math.min(56, height - 8)
	card.portrait = card:CreateTexture(nil, "ARTWORK", nil, 1)
	card.portrait:SetSize(side, side)
	card.portrait:SetPoint("CENTER", card, "LEFT", 6 + 28, 0)
	card.portrait:Hide()
	pane.lookChoose = Theme.CreateButton(card, "auto", "sm", L.ALLURE_CHOOSE, function() ns:AllureOpen() end, "primary")
	pane.lookChoose:SetPoint("RIGHT", card, "RIGHT", -10, 0)
	local textX = 70
	local textW = width - textX - (pane.lookChoose:GetWidth() or 90) - 20
	pane.lookName = ui.Text(card, Theme.F_LABEL, Theme.PARCHMENT, textW)
	pane.lookName:SetPoint("TOPLEFT", card, "TOPLEFT", textX, -16)
	if pane.lookName.SetWordWrap then pane.lookName:SetWordWrap(false) end
	pane.lookDetail = ui.Text(card, Theme.F_SMALL, Theme.MUTED_LIGHT, textW)
	pane.lookDetail:SetPoint("TOPLEFT", card, "TOPLEFT", textX, -36)
	if pane.lookDetail.SetWordWrap then pane.lookDetail:SetWordWrap(false) end
end

-- Ce qu'est une apparence, en quelques mots (type, brillante, mascotte, saison)
function ns:AllureKindText(def)
	local m = Meta(self, def)
	if m.kind == "season" then return L.ALLURE_SEASONAL end
	if m.kind == "mascot" then return L.ALLURE_MASCOT end
	local typeLabel = m.typeKey and self.CreatureTypeLabel and self:CreatureTypeLabel(m.typeKey) or m.typeText
	typeLabel = typeLabel and tostring(typeLabel) or nil
	if def.shiny then return typeLabel and (typeLabel .. " · " .. L.ALLURE_SHINY) or L.ALLURE_SHINY end
	return typeLabel or ""
end

function ns:AllureRefreshCard(pane)
	local card = pane and pane.lookCard
	if not card then return end
	local def = self:CompanionCurrentAppearance()
	local m = Meta(self, def)
	pane.lookName:SetText(def.shiny and self:F("ALLURE_SHINY_OF", m.base or m.name) or (m.base or m.name))
	local count = self.CompanionUnlockedAppearances and #self:CompanionUnlockedAppearances() or 0
	pane.lookDetail:SetText(self:AllureKindText(def) .. "  ·  " .. self:F("ALLURE_CARD_COUNT", count))
	local rarity = def.captured and ns.CAPTURE_RARITY and ns.CAPTURE_RARITY[def.class or "normal"]
	card:SetAccent(def.shiny and Theme.GOLD_LIGHT or (rarity and rarity.color) or Theme.GOLD)
	-- 2.14.0 (bêta 6) : compagnon de saison au displayID connu : le portrait 2D
	local display = def.seasonal and CanPortrait() and SeasonDisplay(self, def) or nil
	if display and card.portrait and self.CreaturePortrait
		and self:CreaturePortrait(card.portrait, { display = display, npc = def.npc }) == "portrait" then
		card.portrait:Show()
		card.look = "portrait"
		if card.model then
			if ns.ModelForget then ns.ModelForget(card.model) end
			card.model:Hide()
		end
		return
	end
	if card.portrait then card.portrait:Hide() end
	card.look = "model"
	if card.model then card.model:Show() end
	if card.model and ns.ShowModel then
		-- 2.14.0 (bêta 3) : une créature (capturée, de saison) cadrée comme
		-- dans le cadre du compagnon (Metzen : de loin)
		local cam, y, facing
		if (def.captured or def.seasonal) and self.CompanionModelCam then
			cam, y, facing = self:CompanionModelCam({ npc = def.npc, type = m.typeText }, "pied")
		end
		ns.ShowModel(card.model, { display = def.display, npc = def.npc, shiny = def.shiny,
			cam = cam, y = y, facing = facing }, "cell")
	end
end

if ns.Mark then ns.Mark("CompanionAllure") end
