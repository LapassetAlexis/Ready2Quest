-- JournalAddons.lua -- page « Addons liés » du carnet (3.0.1)
--
-- La dernière entrée de la colonne, sous le Guide. Une carte pour
-- Ready2Quest : son icône, son nom, ce qu'il fait (cinq points tirés de ses
-- modules), et son état en direct (ns.AddonStatus, socle) :
--   * chargé : sa version et « Ouvrir Ready2Quest » (ses réglages) ;
--   * installé mais désactivé : comment l'activer, et un bouton qui l'active
--     pour ce personnage puis propose de recharger (hors combat) ;
--   * absent : les liens CurseForge et Wago dans des champs à copier.
-- Puis « Ensemble » : ce que les deux addons font l'un avec l'autre.
-- Page externe du carnet : ns.JOURNAL_PANES.addons (JournalWindow.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local R2Q = "Ready2Quest"
local R2Q_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_Bag_08"   -- icône du client (rien d'embarqué)
local URLS = {
	{ "CurseForge", "https://www.curseforge.com/wow/addons/ready2quest" },
	{ "Wago", "https://addons.wago.io/addons/ready-2-quest" },
}
ns.ADDONS_R2Q_URLS = URLS
local HIGHLIGHTS = 5
local FACTS = { "sharedSocle", "windows", "departure", "aggro" }
ns.ADDONS_FACTS = FACTS

local FR = {
	JRN_SEC_addons        = "Addons liés",
	JRN_SUB_addons        = "L'autre addon du projet, et ce qu'ils font ensemble.",
	ADDONS_R2Q_LINE       = "Prépare ta sortie : un check avant de quitter la ville, puis du confort tout au long de la route.",
	ADDONS_R2Q_1          = "Check avant le départ : sacs, gris à vendre, vivres, buffs, repos, durabilité, quêtes à rendre.",
	ADDONS_R2Q_2          = "Bilan d'expédition au retour, fiche de donjon, kit de camp au feu de camp.",
	ADDONS_R2Q_3          = "Sac plein et Place au butin : l'objet qui te coûte le moins à jeter.",
	ADDONS_R2Q_4          = "Favoris protégés de la vente ; gris vendus et réparation automatiques chez le marchand.",
	ADDONS_R2Q_5          = "Portée d'aggro sur les barres de nom, rangs de sorts à mettre à jour, conseil après la mort.",
	ADDONS_LOADED         = "Installé et actif · version %s",
	ADDONS_OPEN_R2Q       = "Ouvrir Ready2Quest",
	ADDONS_DISABLED       = "Installé mais désactivé. Active-le à l'écran de sélection du personnage (bouton AddOns), puis /reload.",
	ADDONS_ENABLE         = "Activer pour ce personnage",
	ADDONS_ENABLE_COMBAT  = "Pas en combat : réessaie après.",
	ADDONS_MISSING        = "Pas installé. Tu le trouves ici :",
	ADDONS_COPY_HINT      = "Clique un lien, puis Ctrl+C pour copier.",
	ADDONS_TOGETHER       = "ENSEMBLE",
	ADDONS_FACT_sharedSocle = "Un seul socle commun (réglages, thème, textes) chargé une fois pour les deux : moins de mémoire.",
	ADDONS_FACT_windows   = "Leurs fenêtres ne se chevauchent plus : Place au butin, Sac plein, Tout capturer et la carte de capture se rangent côte à côte.",
	ADDONS_FACT_departure = "Ton compagnon réagit quand tu quittes une ville ou un village et quand tu y reviens : Ready2Quest le lui dit.",
	ADDONS_FACT_aggro     = "Une seule alerte d'aggro : quand l'anneau rouge de Ready2Quest est posé, ton compagnon ne clignote pas en plus.",
}
local EN = {
	JRN_SEC_addons        = "Related addons",
	JRN_SUB_addons        = "The project's other addon, and what they do together.",
	ADDONS_R2Q_LINE       = "Get ready to quest: a check before you leave town, then comfort all along the road.",
	ADDONS_R2Q_1          = "Pre-departure check: bags, grays to sell, food, buffs, rest, durability, quests to turn in.",
	ADDONS_R2Q_2          = "Expedition report when you're back, dungeon sheet, camp kit at the campfire.",
	ADDONS_R2Q_3          = "Full bags and Loot room: the item that costs you the least to discard.",
	ADDONS_R2Q_4          = "Favorites protected from selling; automatic gray selling and repairs at merchants.",
	ADDONS_R2Q_5          = "Aggro range on nameplates, spell ranks to update, advice after death.",
	ADDONS_LOADED         = "Installed and enabled · version %s",
	ADDONS_OPEN_R2Q       = "Open Ready2Quest",
	ADDONS_DISABLED       = "Installed but disabled. Enable it on the character select screen (AddOns button), then /reload.",
	ADDONS_ENABLE         = "Enable for this character",
	ADDONS_ENABLE_COMBAT  = "Not in combat: try again after.",
	ADDONS_MISSING        = "Not installed. You can find it here:",
	ADDONS_COPY_HINT      = "Click a link, then Ctrl+C to copy.",
	ADDONS_TOGETHER       = "TOGETHER",
	ADDONS_FACT_sharedSocle = "A single shared core (settings, theme, texts) loaded once for both: less memory.",
	ADDONS_FACT_windows   = "Their windows no longer overlap: Loot room, Full bags, Capture all and the capture card sit side by side.",
	ADDONS_FACT_departure = "Your companion reacts when you leave a town or village and when you come back: Ready2Quest tells it.",
	ADDONS_FACT_aggro     = "A single aggro alert: while Ready2Quest's red ring is up, your companion doesn't flash on top of it.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_ADDONS_STRINGS = { fr = FR, en = EN } end

-- mise en page (y depuis ui.TOP) ; tout tient au-dessus de la pagination
local CARD_H, ICON = 196, 40
local LINK_Y, LINK_STEP, LINK_W = 208, 28, 430
local TOGETHER_Y, FACT_STEP = 300, 34
ns.JOURNAL_ADDONS_LAYOUT = { cardH = CARD_H, linkY = LINK_Y, linkStep = LINK_STEP, togetherY = TOGETHER_Y,
	factStep = FACT_STEP, facts = #FACTS }

-- ---------------------------------------------------------------------------
-- État de Ready2Quest
-- ---------------------------------------------------------------------------
function ns:AddonsR2QStatus()
	if not ns.AddonStatus then return "missing" end
	return ns.AddonStatus(R2Q, R2Q)
end

function ns:AddonsR2QIcon(status)
	if status ~= "missing" and ns.AddonStatus then
		local api = rawget(_G, "C_AddOns")
		local meta = (type(api) == "table" and api.GetAddOnMetadata) or rawget(_G, "GetAddOnMetadata")
		if type(meta) == "function" then
			local ok, icon = pcall(meta, R2Q, "IconTexture")
			if ok and type(icon) == "string" and icon ~= "" then return icon end
		end
	end
	return R2Q_ICON_FALLBACK
end

-- « Ouvrir Ready2Quest » : ses réglages, par son API publique (_G.Ready2Quest)
function ns:AddonsOpenR2Q()
	local other = rawget(_G, R2Q)
	if type(other) ~= "table" or other == ns then return false end
	-- le carnet se ferme d'abord : les réglages ne s'ouvrent pas dessous
	if self.journalFrame and self.journalFrame.Hide then self.journalFrame:Hide() end
	if type(other.ToggleOptions) == "function" then
		local frame = other.optionsFrame
		if frame and frame.IsShown and frame:IsShown() then return true end
		return (pcall(other.ToggleOptions, other)) and true or false
	end
	local slash = rawget(_G, "SlashCmdList")
	local handler = type(slash) == "table" and slash.SACETDEPART
	if type(handler) == "function" then return (pcall(handler, "")) and true or false end
	return false
end

-- « Activer pour ce personnage » : hors combat, puis rechargement proposé
function ns:AddonsEnableR2Q()
	if ns.AddonEnable and ns.AddonEnable(R2Q) then
		if self.AskReload then self:AskReload(R2Q) end
		return true
	end
	self:Print(L.ADDONS_ENABLE_COMBAT)
	return false
end

-- ---------------------------------------------------------------------------
-- Champ de lien : lecture seule, tout sélectionné au clic
-- ---------------------------------------------------------------------------
local function LinkBox(pane, width, url)
	local box = Theme.CreateSearchBox(pane, width, "", nil)
	if box.SetMaxLetters then box:SetMaxLetters(200) end
	ns.CopyBoxLock(box, url)
	box:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= self.copyURL then ns.CopyBoxLock(self, self.copyURL) end
		if self.Refresh then self:Refresh() end
	end)
	box:SetScript("OnEditFocusGained", function(self)
		if self.HighlightText then self:HighlightText() end
		if self.border then self.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end
	end)
	box:SetScript("OnMouseUp", function(self)
		if self.SetFocus then self:SetFocus() end
		if self.HighlightText then self:HighlightText() end
	end)
	return box
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
local function Build(self, frame, content, ui)
	local At, Text = ui.At, ui.Text
	local TOP, INNER = ui.TOP, ui.INNER
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.addons = pane
	-- 3.0.1 bêta 3 : un fond opaque propre à la page, sous tout le reste. Une
	-- autre fenêtre de même strate (les réglages de Ready2Quest) pouvait
	-- s'intercaler entre le fond du carnet et cette page : on la voyait au
	-- travers. Même couleur que le fond de la fenêtre : rien ne change à l'œil.
	pane.base = pane:CreateTexture(nil, "BACKGROUND", nil, -8)
	pane.base:SetColorTexture(Theme.WINDOW[1], Theme.WINDOW[2], Theme.WINDOW[3], 1)
	pane.base:SetAllPoints(pane)

	local card = Theme.CreateTile(pane, INNER, CARD_H)
	At(card, content, 0, TOP)
	pane.card = card
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(ICON, ICON)
	card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -12)
	local textX = 12 + ICON + 12
	local textW = INNER - textX - 12
	card.name = Text(card, Theme.F_TITLE, Theme.LABEL, 260)
	card.name:SetPoint("TOPLEFT", card, "TOPLEFT", textX, -12)
	card.name:SetText(R2Q)
	card.line = Text(card, Theme.F_BODY, Theme.TEXT, textW)
	card.line:SetPoint("TOPLEFT", card, "TOPLEFT", textX, -36)
	card.line:SetText(L.ADDONS_R2Q_LINE)
	card.status = Text(card, Theme.F_SMALL, Theme.GREEN, textW - 200)
	card.status:SetPoint("TOPLEFT", card, "TOPLEFT", textX, -58)
	card.button = Theme.CreateButton(card, "auto", "sm", L.ADDONS_OPEN_R2Q, function() ns:AddonsCardAction() end, "accent")
	card.button:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -12)
	card.points = {}
	for i = 1, HIGHLIGHTS do
		local point = Text(card, Theme.F_BODY, Theme.TEXT, INNER - 40)
		point:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -84 - (i - 1) * 21)
		if point.SetWordWrap then point:SetWordWrap(false) end
		point:SetText("• " .. L["ADDONS_R2Q_" .. i])
		card.points[i] = point
	end

	-- absent : les deux liens à copier
	pane.links = {}
	pane.linkHint = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER)
	At(pane.linkHint, content, 0, TOP - LINK_Y)
	for i, link in ipairs(URLS) do
		local label = Text(pane, Theme.F_LABEL, Theme.LABEL, 100)
		At(label, content, 0, TOP - LINK_Y - 18 - (i - 1) * LINK_STEP - 4)
		label:SetText(link[1])
		local box = LinkBox(pane, LINK_W, link[2])
		At(box, content, 110, TOP - LINK_Y - 18 - (i - 1) * LINK_STEP)
		pane.links[i] = { label = label, box = box }
	end

	-- Ensemble
	pane.together = Theme.CreateSection(pane, L.ADDONS_TOGETHER)
	At(pane.together, content, 0, TOP - TOGETHER_Y)
	if pane.together.SetWidth then pane.together:SetWidth(INNER) end
	pane.facts = {}
	for i, key in ipairs(FACTS) do
		local fact = Text(pane, Theme.F_BODY, Theme.TEXT, INNER - 16)
		At(fact, content, 8, TOP - TOGETHER_Y - 26 - (i - 1) * FACT_STEP)
		if fact.SetWordWrap then fact:SetWordWrap(true) end
		fact:SetText("• " .. L["ADDONS_FACT_" .. key])
		pane.facts[i] = fact
	end
	pane:Hide()
end

-- Le bouton de la carte : ouvrir (chargé) ou activer (désactivé)
function ns:AddonsCardAction()
	local status = self:AddonsR2QStatus()
	if status == "loaded" then return self:AddonsOpenR2Q() end
	if status == "disabled" then return self:AddonsEnableR2Q() end
	return false
end

local function Refresh(self, frame)
	local pane = frame.addons
	if not pane then return end
	local status, version = self:AddonsR2QStatus()
	local card = pane.card
	pane.status = status
	card.icon:SetTexture(self:AddonsR2QIcon(status))
	if status == "loaded" then
		card.status:SetText(self:F("ADDONS_LOADED", tostring(version or "?")))
		card.status:SetTextColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3], 1)
		card.status.addonsRole = "addons.ok"
		card.button:SetText(L.ADDONS_OPEN_R2Q)
		card.button:Show()
	elseif status == "disabled" then
		card.status:SetText(L.ADDONS_DISABLED)
		card.status:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
		card.status.addonsRole = "addons.muted"
		card.button:SetText(L.ADDONS_ENABLE)
		if ns.AddonEnable then card.button:Show() else card.button:Hide() end
	else
		card.status:SetText(L.ADDONS_MISSING)
		card.status:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
		card.status.addonsRole = "addons.muted"
		card.button:Hide()
	end
	local missing = status == "missing"
	pane.linkHint:SetText(missing and L.ADDONS_COPY_HINT or "")
	for _, link in ipairs(pane.links) do
		if missing then link.label:Show(); link.box:Show() else link.label:Hide(); link.box:Hide() end
	end
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.addons = {
	field = "addons", title = "JRN_SEC_addons", subtitle = "JRN_SUB_addons",
	build = Build, refresh = Refresh,
}

if ns.Mark then ns.Mark("JournalAddons") end
