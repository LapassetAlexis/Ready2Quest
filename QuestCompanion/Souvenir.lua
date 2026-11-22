-- Souvenir.lua -- la carte souvenir (QuestCompanion 3.7.0)
--
-- Une carte à photographier, centrée sur un voile sombre qui couvre l'écran
-- (rien d'autre de l'interface n'est masqué) : ns.SouvenirShow(sujet).
-- Elle ne s'ouvre jamais seule (seulement sur un clic : bandeau d'un grand
-- haut fait, bandeau d'une prise rare, ligne dépliée d'un haut fait obtenu,
-- pied de la fiche de dresseur, fiche d'un spécimen de la Réserve), se ferme
-- à Échap et au combat, et ne s'ouvre pas en combat.
-- Sujets (appel par point ou par deux-points) :
--   { kind = "capture", result = … }   le bandeau d'une prise (Quiet.lua)
--   { kind = "specimen", id = … }      un spécimen (ou spec = table, ou la table elle-même)
--   { kind = "feat", id | entry | def } un haut fait OBTENU (jamais un secret
--                                      non découvert, jamais une ligne en attente)
--   nil, "trainer", { kind = "trainer" } sa fiche de dresseur
-- La carte : à gauche le modèle 3D (ns.ShowModel, profil « card » ; repli :
-- portrait du client) ou l'icône du haut fait ; à droite le petit titre, le
-- nom, la ligne d'espèce, les lignes (étoiles en textures du client), la
-- cote si elle existe ; en pied le nom et le titre du dresseur, « <rang> ·
-- <points> points · <espèces> espèces », la signature.
-- Sous la carte : « Capture d'écran » (les boutons s'effacent, Screenshot()
-- part ns.SOUVENIR.shotDelay s plus tard, puis ils reviennent avec une
-- phrase qui dit où le jeu range ses captures ; même si Screenshot échoue),
-- « Copier pour Discord » (ns.DiscordCopyShow, ns:DiscordText du sujet),
-- « Fermer ». Sans Screenshot sur ce client : pas de bouton, une phrase
-- invite à la touche de capture du jeu.
-- Première carte ouverte : ns:TallyAdd("souvenir") (haut fait « Souriez ! »).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- géométrie de la maquette (autres-c1) : carte 580 x 298, panneau du modèle
-- 214, colonne de droite à 232, grille de lignes 76 + 8, boutons 138/150/80
ns.SOUVENIR = {
	w = 580, h = 298, y = 34, left = 214, x = 233, rightPad = 16,
	kickY = 17, nameY = 31, nameSize = 22, subY = 63, rowsY = 89, rowStep = 20, labelW = 84,
	oddsGap = 15, oddsH = 20, oddsPad = 8,
	ruleY = 243, ruleW = 330, whoY = 253, footY = 269, sigY = 253, sigRight = -4,
	model = 206, icon = 72, glow = 360, glowY = -10,
	buttonsGap = 24, buttonGap = 8, shotW = 138, copyW = 150, closeW = 80, hintGap = 12,
	shotDelay = 0.5, starSize = 12, starGap = 2, starText = 4,
}
-- les étoiles de la ligne « Qualité » : l'étoile dorée du client (pleine,
-- vide), celle des étoiles de capture (CaptureQueue.lua) ; repli : l'étoile
-- des marqueurs de raid
ns.SOUVENIR_STAR_FULL = { atlases = { ns.CAPTURE_STAR_ATLAS and ns.CAPTURE_STAR_ATLAS.full or "auctionhouse-icon-favorite" },
	fallback = ns.CAPTURE_STAR_ICON or "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" }
ns.SOUVENIR_STAR_EMPTY = { atlases = { ns.CAPTURE_STAR_ATLAS and ns.CAPTURE_STAR_ATLAS.empty or "auctionhouse-icon-favorite-off" },
	fallback = ns.CAPTURE_STAR_ICON or "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" }
-- le bouton de la fiche d'un spécimen (Réserve) : une icône du client
ns.SOUVENIR_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local FR = {
	SOUVENIR_KICK_SHINY  = "PRISE BRILLANTE",
	SOUVENIR_KICK_SPEC   = "SPÉCIMEN",
	SOUVENIR_KICK_FEAT   = "HAUT FAIT OBTENU",
	SOUVENIR_KICK_CARD   = "FICHE DE DRESSEUR",
	SOUVENIR_LEVEL       = "niveau %d",
	SOUVENIR_L_QUALITY   = "Qualité",
	SOUVENIR_L_SIZE      = "Taille",
	SOUVENIR_L_TRAIT     = "Caractère",
	SOUVENIR_L_BOND      = "Lien",
	SOUVENIR_L_CAUGHT    = "Capture",
	SOUVENIR_L_POINTS    = "Points",
	SOUVENIR_L_EARNED    = "Obtenu",
	SOUVENIR_L_CATEGORY  = "Catégorie",
	SOUVENIR_L_RANK      = "Rang",
	SOUVENIR_L_SPECIES   = "Espèces",
	SOUVENIR_L_SHINIES   = "Brillantes",
	SOUVENIR_L_SEALS     = "Sceaux",
	SOUVENIR_L_FEATS     = "Hauts faits",
	SOUVENIR_SIZE_VALUE  = "%s (indice %d)",
	SOUVENIR_PLACE_DATE  = "%s, le %s",
	SOUVENIR_SPECIES_OF  = "%s / %s",
	SOUVENIR_CARD_SUB    = "avec %s",
	SOUVENIR_FOOT        = "%s · %s · %s",
	SOUVENIR_SHOT        = "Capture d'écran",
	SOUVENIR_COPY        = "Copier pour Discord",
	SOUVENIR_CLOSE       = "Fermer",
	SOUVENIR_SHOT_DONE   = "Le jeu range ses captures dans le dossier Screenshots de World of Warcraft.",
	SOUVENIR_SHOT_FAIL   = "La capture n'est pas partie : appuie sur la touche de capture d'écran du jeu (Impr. écran).",
	SOUVENIR_SHOT_NONE   = "Pour la photo, appuie sur la touche de capture d'écran du jeu (Impr. écran).",
}
local EN = {
	SOUVENIR_KICK_SHINY  = "SHINY CATCH",
	SOUVENIR_KICK_SPEC   = "SPECIMEN",
	SOUVENIR_KICK_FEAT   = "ACHIEVEMENT EARNED",
	SOUVENIR_KICK_CARD   = "TRAINER CARD",
	SOUVENIR_LEVEL       = "level %d",
	SOUVENIR_L_QUALITY   = "Quality",
	SOUVENIR_L_SIZE      = "Size",
	SOUVENIR_L_TRAIT     = "Character",
	SOUVENIR_L_BOND      = "Bond",
	SOUVENIR_L_CAUGHT    = "Caught",
	SOUVENIR_L_POINTS    = "Points",
	SOUVENIR_L_EARNED    = "Earned",
	SOUVENIR_L_CATEGORY  = "Category",
	SOUVENIR_L_RANK      = "Rank",
	SOUVENIR_L_SPECIES   = "Species",
	SOUVENIR_L_SHINIES   = "Shinies",
	SOUVENIR_L_SEALS     = "Seals",
	SOUVENIR_L_FEATS     = "Achievements",
	SOUVENIR_SIZE_VALUE  = "%s (index %d)",
	SOUVENIR_PLACE_DATE  = "%s, %s",
	SOUVENIR_SPECIES_OF  = "%s / %s",
	SOUVENIR_CARD_SUB    = "with %s",
	SOUVENIR_FOOT        = "%s · %s · %s",
	SOUVENIR_SHOT        = "Screenshot",
	SOUVENIR_COPY        = "Copy for Discord",
	SOUVENIR_CLOSE       = "Close",
	SOUVENIR_SHOT_DONE   = "The game keeps its screenshots in the World of Warcraft Screenshots folder.",
	SOUVENIR_SHOT_FAIL   = "The screenshot did not go through: press the game's screenshot key (Print Screen).",
	SOUVENIR_SHOT_NONE   = "For the photo, press the game's screenshot key (Print Screen).",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SOUVENIR_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function InCombat()
	local fn = G("InCombatLockdown")
	return type(fn) == "function" and (ns.Plain and ns.Plain(fn()) or fn()) == true
end
local function Count(n, stem) return ns.DiscordCount(n, stem) end
local function Number(n) return ns.OddsNumber and ns.OddsNumber(n) or tostring(n) end

-- Le jeu a-t-il Screenshot (appelable par un addon : à vérifier en jeu) ?
function ns:SouvenirCanShoot() return type(G("Screenshot")) == "function" end

-- ---------------------------------------------------------------------------
-- Ce que dit la carte : une vue par sujet
-- ---------------------------------------------------------------------------
-- { kind, discord (sorte du texte), subject, kicker, kickColor, name, sub,
--   rows = { { label, value, stars } }, odds, model = { npc, display, shiny }, icon }
local function SubjectKind(subject)
	if subject == nil or subject == "trainer" then return "trainer" end
	if type(subject) ~= "table" then return "specimen" end
	local kind = subject.kind
	if kind == "trainer" or kind == "card" then return "trainer" end
	if kind == "feat" then return "feat" end
	if kind == "capture" or kind == "specimen" then return kind end
	if subject.npc or subject.name then return "specimen" end
	return nil
end

local function Footer(self, view)
	local fig = self:DiscordFigures()
	view.who = fig.who
	local points = Count(fig.points, "DISCORD_POINTS")
	local species = Count(fig.species, "DISCORD_SPECIES")
	view.foot = fig.rank and self:F("SOUVENIR_FOOT", fig.rank, points, species) or (points .. L.DISCORD_SEP .. species)
	return fig
end

local VIEWS = {}

function VIEWS.specimen(self, subject)
	local spec, level = self:DiscordSpecimen(subject)
	if not spec then return nil end
	local view = { discord = "capture", subject = subject, kind = "specimen" }
	view.kicker = spec.shiny and L.SOUVENIR_KICK_SHINY or L.SOUVENIR_KICK_SPEC
	local species = self:DiscordSpecies(spec)
	local nick = spec.nick and spec.nick ~= "" and spec.nick or nil
	view.name = nick or species
	-- sous le nom : l'espèce (s'il a un surnom), le niveau (s'il est connu),
	-- sinon le type de la créature (jamais le nom répété)
	local sub = {}
	if nick then sub[#sub + 1] = species end
	if level then sub[#sub + 1] = self:F("SOUVENIR_LEVEL", level) end
	if #sub == 0 then
		local typeKey = self.SpecimenTypeKey and Call(self.SpecimenTypeKey, self, spec)
		local label = typeKey and self.CreatureTypeLabel and Call(self.CreatureTypeLabel, self, typeKey)
		if label and label ~= "" then sub[1] = label end
	end
	view.sub = table.concat(sub, L.DISCORD_SEP)
	local rows = {}
	local stars = tonumber(spec.stars)
	if stars then rows[#rows + 1] = { L.SOUVENIR_L_QUALITY, ns.DiscordCount(stars, "DISCORD_STARS", nil, true), stars = stars } end
	if spec.size or spec.npc then
		local label = self.SpecimenSizeLabel and self:SpecimenSizeLabel(spec.size) or tostring(spec.size or "")
		local index = self.SpecimenSizeIndex and Call(self.SpecimenSizeIndex, self, spec)
		rows[#rows + 1] = { L.SOUVENIR_L_SIZE, index and self:F("SOUVENIR_SIZE_VALUE", label, index) or label }
	end
	local trait = spec.trait and self.PersonaLabel and Call(self.PersonaLabel, self, spec.trait)
	if trait and trait ~= "" then rows[#rows + 1] = { L.SOUVENIR_L_TRAIT, trait } end
	if spec.id and self.SpecimenBondLevel and self.SpecimenBondName then
		local bond = Call(self.SpecimenBondName, self, Call(self.SpecimenBondLevel, self, spec) or 0)
		if bond and bond ~= "" then rows[#rows + 1] = { L.SOUVENIR_L_BOND, bond } end
	end
	local info = spec.zone and self.MapInfo and self:MapInfo(spec.zone)
	local zone = type(info) == "table" and info.name or nil
	local day = ns.DiscordDate(spec.at)
	local caught = (zone and day and self:F("SOUVENIR_PLACE_DATE", zone, day)) or zone or day
	if caught then rows[#rows + 1] = { L.SOUVENIR_L_CAUGHT, caught } end
	view.rows = rows
	local odds = self.SpecimenOddsShown and self:SpecimenOddsShown(spec)
	if odds then view.odds = ns:F("DISCORD_ODDS", Number(odds)) end
	view.model = { npc = tonumber(spec.npc), display = tonumber(spec.display), shiny = spec.shiny and true or false,
		type = spec.type }
	Footer(self, view)
	return view
end
VIEWS.capture = VIEWS.specimen

function VIEWS.feat(self, subject)
	local def, at = self:DiscordFeat(subject)
	if not def then return nil end
	local view = { discord = "feat", subject = def.id, kind = "feat", kicker = L.SOUVENIR_KICK_FEAT }
	view.name = self:FeatName(def)
	view.sub = self.FeatDescription and self:FeatDescription(def) or ""
	local rows = { { L.SOUVENIR_L_POINTS, tostring(tonumber(def.pts) or 0) } }
	local cat = def.cat and L["FEATC_" .. tostring(def.cat)]
	if cat and cat ~= "FEATC_" .. tostring(def.cat) then rows[#rows + 1] = { L.SOUVENIR_L_CATEGORY, cat } end
	local day = ns.DiscordDate(at)
	if day then rows[#rows + 1] = { L.SOUVENIR_L_EARNED, day } end
	view.rows = rows
	view.icon = self:FeatIcon(def)
	Footer(self, view)
	return view
end

function VIEWS.trainer(self)
	local view = { discord = "trainer", kind = "trainer", kicker = L.SOUVENIR_KICK_CARD }
	local fig = Footer(self, view)
	view.name = fig.name
	local comp = fig.companion
	view.sub = (comp and comp.name) and self:F("SOUVENIR_CARD_SUB", comp.name) or ""
	local points = Count(fig.points, "DISCORD_POINTS")
	local rows = { fig.rank and { L.SOUVENIR_L_RANK, fig.rank .. L.DISCORD_SEP .. points } or { L.SOUVENIR_L_POINTS, points } }
	local species = Number(fig.species or 0)
	if fig.total and fig.total > 0 then species = self:F("SOUVENIR_SPECIES_OF", species, Number(fig.total)) end
	rows[#rows + 1] = { L.SOUVENIR_L_SPECIES, species }
	rows[#rows + 1] = { L.SOUVENIR_L_SHINIES, Number(fig.shinies or 0) }
	rows[#rows + 1] = { L.SOUVENIR_L_SEALS, Number(fig.seals or 0) }
	rows[#rows + 1] = { L.SOUVENIR_L_FEATS, Number(fig.feats or 0) }
	view.rows = rows
	if comp then view.model = { npc = tonumber(comp.npc), display = tonumber(comp.display), shiny = comp.shiny, mascot = comp.mascot } end
	return view
end

-- La vue d'un sujet, ou nil (sujet inconnu, haut fait non obtenu, secret)
function ns:SouvenirView(subject)
	local kind = SubjectKind(subject)
	local fn = kind and VIEWS[kind]
	if not fn then return nil end
	local ok, view = pcall(fn, self, subject)
	if not ok then
		if self.RecordError then self:RecordError("souvenir:view", view) end
		return nil
	end
	return view
end

-- ---------------------------------------------------------------------------
-- La carte
-- ---------------------------------------------------------------------------
local function Paint(region, color)
	if region and region.SetTextColor then region:SetTextColor(color[1], color[2], color[3], 1) end
end

local function Line(parent, font, color, width)
	local fs = Theme.Text(parent, font, color)
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	return fs
end

local function At(region, parent, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	return region
end

local function BuildCard(veil)
	local S = ns.SOUVENIR
	local card = Theme.CreateWindow(veil, S.w, S.h, { strata = "FULLSCREEN" })
	if not card then return nil end
	card:SetPoint("CENTER", veil, "CENTER", 0, S.y)
	if card.close then card.close:Hide() end
	if card.SetMovable then card:SetMovable(false) end
	if card.RegisterForDrag then card:RegisterForDrag() end
	card:SetScript("OnDragStart", nil)
	card:SetScript("OnDragStop", nil)
	-- panneau du modèle : encre, une lueur chaude au centre, un filet à droite
	local panel = CreateFrame("Frame", nil, card)
	panel:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
	panel:SetSize(S.left, S.h - 2)
	panel.bg = Theme.Solid(panel, "BACKGROUND", Theme.INK, 1)
	panel.bg:SetAllPoints()
	panel.glow = panel:CreateTexture(nil, "BORDER")
	if Theme.ART and Theme.ART.dot then panel.glow:SetTexture(Theme.ART.dot.file) else panel.glow:SetTexture(Theme.SOLID) end
	panel.glow:SetSize(S.glow, S.glow)
	panel.glow:SetPoint("CENTER", panel, "CENTER", 0, S.glowY)
	if panel.glow.SetBlendMode then pcall(panel.glow.SetBlendMode, panel.glow, "ADD") end
	panel.glow:SetVertexColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3], Theme.SHADE.veil)
	if panel.SetClipsChildren then panel:SetClipsChildren(true) end
	panel.edge = Theme.Solid(card, "ARTWORK", Theme.GOLD_SOFT, Theme.SHADE.mid)
	panel.edge:SetPoint("TOPLEFT", panel, "TOPRIGHT", 0, 0)
	panel.edge:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 0, 0)
	panel.edge:SetWidth(1)
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, panel)
	if ok and model then
		model:SetSize(S.model, S.model)
		model:SetPoint("CENTER", panel, "CENTER", 0, 0)
		model:Hide()
		panel.model = model
	end
	panel.portrait = panel:CreateTexture(nil, "ARTWORK")
	panel.portrait:SetSize(S.icon, S.icon)
	panel.portrait:SetPoint("CENTER", panel, "CENTER", 0, 0)
	panel.portrait:Hide()
	card.panel = panel
	-- colonne de droite
	local width = S.w - S.x - S.rightPad
	card.kicker = At(Line(card, Theme.F_CAPS, Theme.ARCANE_LIGHT, width), card, S.x, S.kickY)
	card.name = Theme.CreateTitle(card, S.nameSize)
	card.name:SetJustifyH("LEFT")
	card.name:SetWidth(width)
	if card.name.SetWordWrap then card.name:SetWordWrap(false) end
	Paint(card.name, Theme.GOLD_LIGHT)
	Theme.TextShadow(card.name, Theme.SHADE.veil)
	At(card.name, card, S.x, S.nameY)
	card.sub = At(Line(card, Theme.F_SMALL, Theme.MUTED_LIGHT, width), card, S.x, S.subY)
	card.rows = {}
	for index = 1, 5 do
		local y = S.rowsY + (index - 1) * S.rowStep
		local row = {}
		row.label = At(Line(card, Theme.F_SMALL, Theme.MUTED_LIGHT, S.labelW - 8), card, S.x, y + 1)
		row.value = At(Line(card, Theme.F_BODY, Theme.TEXT, width - S.labelW), card, S.x + S.labelW, y)
		-- les étoiles : des textures du client (jamais un glyphe)
		row.stars = {}
		for star = 1, (ns.CAPTURE_STAR_MAX or 3) do
			local tex = card:CreateTexture(nil, "OVERLAY")
			tex:SetSize(S.starSize, S.starSize)
			tex:SetPoint("TOPLEFT", card, "TOPLEFT", S.x + S.labelW + (star - 1) * (S.starSize + S.starGap), -(y + 1))
			tex:Hide()
			row.stars[star] = tex
		end
		card.rows[index] = row
	end
	-- la cote : une étiquette dorée
	local odds = CreateFrame("Frame", nil, card)
	odds:SetHeight(S.oddsH)
	odds.bg = Theme.Solid(odds, "BACKGROUND", Theme.GOLD, Theme.SHADE.soft / 2)
	odds.bg:SetAllPoints()
	odds.border = Theme.Border(odds, Theme.GOLD_LIGHT, Theme.SHADE.mid)
	odds.text = Theme.Text(odds, Theme.F_LABEL, Theme.GOLD_LIGHT)
	odds.text:SetPoint("LEFT", odds, "LEFT", S.oddsPad, 0)
	odds:Hide()
	card.odds = odds
	-- pied : filet, dresseur, rang, signature
	card.rule = Theme.Solid(card, "ARTWORK", Theme.GOLD_SOFT, Theme.SHADE.mid)
	card.rule:SetSize(S.ruleW, 1)
	At(card.rule, card, S.x, S.ruleY)
	card.who = At(Line(card, Theme.F_LABEL, Theme.PARCHMENT, S.ruleW - 110), card, S.x, S.whoY)
	card.foot = At(Line(card, Theme.F_SMALL, Theme.MUTED_LIGHT, S.ruleW - 110), card, S.x, S.footY)
	local sigHolder = CreateFrame("Frame", nil, card)
	sigHolder:SetSize(200, 30)
	sigHolder:SetPoint("TOPRIGHT", card, "TOPRIGHT", S.sigRight, -S.sigY)
	if ns.SignatureSet then ns:SignatureSet(sigHolder, true) end
	card.sigHolder = sigHolder
	return card
end

local function BuildButtons(veil, card)
	local S = ns.SOUVENIR
	local bar = CreateFrame("Frame", nil, veil)
	bar:SetSize(S.shotW + S.copyW + S.closeW + 2 * S.buttonGap, Theme.ButtonHeight("md"))
	bar:SetPoint("TOP", card, "BOTTOM", 0, -S.buttonsGap)
	bar.shot = Theme.CreateButton(bar, S.shotW, "md", L.SOUVENIR_SHOT, function() ns:SouvenirShoot() end, "primary")
	bar.copy = Theme.CreateButton(bar, S.copyW, "md", L.SOUVENIR_COPY, function() ns:SouvenirCopy() end, "outline")
	bar.close = Theme.CreateButton(bar, S.closeW, "md", L.SOUVENIR_CLOSE, function() ns:SouvenirHide() end, "accent")
	veil.hint = Theme.Text(veil, Theme.F_SMALL, Theme.LABEL)
	veil.hint:SetPoint("TOP", bar, "BOTTOM", 0, -S.hintGap)
	veil.hint:SetJustifyH("CENTER")
	veil.hint:SetWidth(S.w)
	return bar
end

-- les boutons, en rang centré (« Capture d'écran » seulement si le jeu l'a)
local function LayoutButtons(bar, canShoot)
	local S = ns.SOUVENIR
	local list = canShoot and { bar.shot, bar.copy, bar.close } or { bar.copy, bar.close }
	if canShoot then bar.shot:Show() else bar.shot:Hide() end
	local total = 0
	for index, button in ipairs(list) do total = total + (tonumber(button:GetWidth()) or 0) + (index > 1 and S.buttonGap or 0) end
	bar:SetWidth(total)
	local x = 0
	for _, button in ipairs(list) do
		button:ClearAllPoints()
		button:SetPoint("LEFT", bar, "LEFT", x, 0)
		button:Show()
		x = x + (tonumber(button:GetWidth()) or 0) + S.buttonGap
	end
end

local function BuildVeil()
	local ok, veil = pcall(CreateFrame, "Frame", "QuestCompanionSouvenir", UIParent)
	if not (ok and veil) then return nil end
	veil:SetAllPoints(UIParent)
	veil:SetFrameStrata("FULLSCREEN")
	veil:EnableMouse(true)
	veil.shade = Theme.Solid(veil, "BACKGROUND", Theme.INK, Theme.SHADE.strong)
	veil.shade:SetAllPoints()
	veil.card = BuildCard(veil)
	if not veil.card then return nil end
	veil.bar = BuildButtons(veil, veil.card)
	if Theme.RegisterEscapeClose then Theme.RegisterEscapeClose(veil) end
	-- le combat ferme la carte (et la fenêtre de copie, DiscordCopy.lua)
	if veil.RegisterEvent then pcall(veil.RegisterEvent, veil, "PLAYER_REGEN_DISABLED") end
	veil:SetScript("OnEvent", function(f, event)
		if event == "PLAYER_REGEN_DISABLED" and f:IsShown() then ns:SouvenirHide() end
	end)
	veil:SetScript("OnHide", function()
		local model = veil.card and veil.card.panel and veil.card.panel.model
		if model and ns.ModelForget then ns.ModelForget(model) end
	end)
	veil:Hide()
	return veil
end

function ns:EnsureSouvenir()
	if not self.souvenirFrame then self.souvenirFrame = BuildVeil() end
	return self.souvenirFrame
end

-- Pose une vue sur la carte
function ns:SouvenirPaint(view)
	local veil = self:EnsureSouvenir()
	if not (veil and view) then return nil end
	local S, card = ns.SOUVENIR, veil.card
	card.kicker:SetText(view.kicker or "")
	card.name:SetText(view.name or "")
	card.sub:SetText(view.sub or "")
	local rows = view.rows or {}
	for index, row in ipairs(card.rows) do
		local item = rows[index]
		if item then
			row.label:SetText(item[1] or "")
			row.value:SetText(tostring(item[2] or ""))
			local shift = 0
			for star, tex in ipairs(row.stars) do
				if item.stars then
					local full = star <= item.stars
					Theme.PaintClient(tex, full and ns.SOUVENIR_STAR_FULL or ns.SOUVENIR_STAR_EMPTY)
					if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, not full) end
					tex:Show()
					shift = star * (S.starSize + S.starGap) + S.starText
				else
					tex:Hide()
				end
			end
			At(row.value, card, S.x + S.labelW + shift, S.rowsY + (index - 1) * S.rowStep)
			row.label:Show(); row.value:Show()
		else
			row.label:SetText(""); row.value:SetText("")
			row.label:Hide(); row.value:Hide()
			for _, tex in ipairs(row.stars) do tex:Hide() end
		end
	end
	if view.odds then
		card.odds.text:SetText(view.odds)
		local measure = card.odds.text.GetUnboundedStringWidth or card.odds.text.GetStringWidth
		local w = math.ceil(tonumber(measure and measure(card.odds.text)) or (#view.odds * 6))
		card.odds:SetWidth(w + 2 * S.oddsPad)
		At(card.odds, card, S.x, S.rowsY + math.max(1, #rows) * S.rowStep + S.oddsGap)
		card.odds:Show()
	else
		card.odds:Hide()
	end
	card.who:SetText(view.who or "")
	card.foot:SetText(view.foot or "")
	-- à gauche : le modèle 3D (repli : portrait du client), ou l'icône du haut fait
	local panel = card.panel
	local model, portrait = panel.model, panel.portrait
	panel.modelShown = false
	portrait:Hide()
	if view.model and (view.model.npc or view.model.display) and model and ns.ShowModel then
		ns.souvenirEpoch = (ns.souvenirEpoch or 0) + 1
		local m = view.model
		panel.modelShown = ns.ShowModel(model, { npc = m.npc, display = m.display, shiny = m.shiny, epoch = ns.souvenirEpoch,
			cam = m.mascot and ns.MODEL_PROFILES and ns.MODEL_PROFILES.portrait and ns.MODEL_PROFILES.portrait.cam or nil }, "card")
		if not panel.modelShown then
			portrait:SetSize(S.icon, S.icon)
			if self.CreaturePortrait then self:CreaturePortrait(portrait, { npcID = m.npc, display = m.display, type = m.type }) end
			portrait:Show()
		end
	else
		if model and ns.ModelForget then ns.ModelForget(model) end
		if view.icon then
			portrait:SetSize(S.icon, S.icon)
			pcall(portrait.SetTexture, portrait, view.icon)
			if portrait.SetTexCoord then portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
			portrait:Show()
		end
	end
	veil.view = view
	return veil
end

-- ns.SouvenirShow(sujet) : par point ou par deux-points (ns:SouvenirShow)
function ns.SouvenirShow(a, b)
	local subject = a
	if a == ns then subject = b end
	if InCombat() then
		ns:Print(L.DISCORD_COMBAT)
		return nil
	end
	local view = ns:SouvenirView(subject)
	if not view then return nil end
	local veil = ns:SouvenirPaint(view)
	if not veil then return nil end
	-- boutons : jamais restés effacés d'une capture précédente
	veil.shooting = nil
	ns.Cancel("souvenir:shot")
	local canShoot = ns:SouvenirCanShoot()
	LayoutButtons(veil.bar, canShoot)
	veil.bar:Show()
	veil.hint:SetText(canShoot and "" or L.SOUVENIR_SHOT_NONE)
	if canShoot then veil.hint:Hide() else veil.hint:Show() end
	veil:Show()
	if veil.Raise then veil:Raise() end
	-- première carte ouverte : le compteur du haut fait « Souriez ! »
	if ns.TallyAdd and ns.TallyGet and (tonumber(ns:TallyGet("souvenir")) or 0) < 1 then ns:TallyAdd("souvenir") end
	return veil
end

function ns:SouvenirHide()
	local veil = self.souvenirFrame
	if veil and veil:IsShown() then veil:Hide() end
	if self.discordCopy and self.discordCopy:IsShown() then self.discordCopy:Hide() end
end

function ns:SouvenirCopy()
	local veil = self.souvenirFrame
	local view = veil and veil.view
	if not view then return nil end
	local text = self:DiscordText(view.discord, view.subject)
	if not text then return nil end
	return ns.DiscordCopyShow(text, L.DISCORD_COPY_TITLE)
end

-- les boutons reviennent, avec la phrase qui dit où va la capture
local function ShotDone(ok)
	local veil = ns.souvenirFrame
	if not veil then return false end
	veil.shooting = nil
	veil.bar:Show()
	if veil:IsShown() then
		veil.hint:SetText(ok and L.SOUVENIR_SHOT_DONE or L.SOUVENIR_SHOT_FAIL)
		veil.hint:Show()
	end
	return false
end

-- « Capture d'écran » : les boutons s'effacent, la photo part un instant plus
-- tard, puis ils reviennent (même si Screenshot échoue ou si la carte a été
-- fermée entre-temps)
function ns:SouvenirShoot()
	local veil = self.souvenirFrame
	if not (veil and veil:IsShown()) or veil.shooting then return false end
	if not self:SouvenirCanShoot() then return false end
	veil.shooting = true
	veil.bar:Hide()
	veil.hint:Hide()
	ns.Soon("souvenir:shot", ns.SOUVENIR.shotDelay, function()
		local ok = false
		if veil:IsShown() and not InCombat() then
			local shoot = G("Screenshot")
			if type(shoot) == "function" then ok = pcall(shoot) end
		end
		ShotDone(ok)
		return false
	end)
	return true
end

if ns.Mark then ns.Mark("Souvenir") end
