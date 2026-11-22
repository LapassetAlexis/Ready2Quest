-- DiscordCopy.lua -- « Copier pour Discord » (QuestCompanion 3.7.0)
--
-- Rien ne sort du jeu tout seul : l'addon ne peut ni écrire dans le
-- presse-papiers ni ouvrir un lien. Il compose un texte (ns:DiscordText) et le
-- pose, tout sélectionné, dans une petite fenêtre (ns.DiscordCopyShow) : le
-- joueur fait Ctrl+C et colle où il veut. Aucun de ces textes ne part dans le
-- chat du jeu.
--   * ns.DiscordCopyShow(texte, titre) : la fenêtre (zone sur plusieurs
--     lignes, verrouillée par la brique de copie du socle, ns.CopyBoxLock ;
--     consigne ; « Fermer »). Échap ferme, le combat aussi ; jamais ouverte
--     en combat.
--   * ns:DiscordText(sorte, sujet[, langue]) : le texte, dans la langue du
--     joueur (langue : "fr", "en" ou "es", pour les tests). Sortes :
--       "capture" (ou "specimen") : sujet = spécimen (table ou identifiant),
--         { kind = "capture", result = … } (bandeau de prise), ou
--         { kind = "specimen", id = … } ;
--       "trainer" : sa fiche de dresseur (sujet ignoré) ;
--       "stats"   : les six blocs de l'onglet Statistiques, une ligne par
--         bloc (seulement si ns:FeatStatsBlocks existe) ;
--       "feat"    : un haut fait OBTENU (identifiant, définition, ou
--         { kind = "feat", id | entry | def }) ; un haut fait non obtenu, un
--         secret non découvert ou une ligne en attente : aucun texte.
--     La première ligne porte le gras Discord ; les deux dernières sont la
--     signature, l'adresse CurseForge en tout dernier. Moins de
--     ns.DISCORD_MAX octets (donc de caractères). Rend nil si rien à dire.
-- Le genre d'une espèce n'est pas connu : aucune tournure ne l'accorde
-- (« **Raptor** · brillante · 3 étoiles · Géant », « Prise de … »).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.DISCORD_MAX = 1900                 -- strictement moins (octets, donc caractères)
ns.DISCORD_URL = "https://www.curseforge.com/wow/addons/quest-companion"
ns.DISCORD_LINE_MAX = 400             -- une ligne trop longue est coupée (octets)
ns.DISCORD_COPY = { w = 460, h = 232, pad = 20, areaY = 50, areaH = 128, maxLetters = 2000 }
-- caractères échappés dans ce qui vient du joueur ou du jeu (surnom, nom,
-- zone) : la mise en forme de Discord et les mentions (« \@everyone »)
ns.DISCORD_ESCAPE = "([\\%*_~`@])"

local FR = {
	DISCORD_COPY_TITLE   = "Copier pour Discord",
	DISCORD_COPY_HINT    = "Ctrl+C, puis colle où tu veux",
	DISCORD_COPY_CLOSE   = "Fermer",
	DISCORD_COMBAT       = "Pas pendant un combat.",
	DISCORD_SIGN         = "Quest Companion, addon WoW Forever",
	DISCORD_SEP          = " · ",
	DISCORD_SHINY        = "brillante",
	DISCORD_STARS_ONE    = "%d étoile",
	DISCORD_STARS_MANY   = "%d étoiles",
	DISCORD_ODDS         = "1 chance sur %s",
	DISCORD_CAUGHT_BY    = "Prise de %s",
	DISCORD_SPECIES_ONE  = "%s espèce",
	DISCORD_SPECIES_MANY = "%s espèces",
	DISCORD_SHINIES_ONE  = "%s brillante",
	DISCORD_SHINIES_MANY = "%s brillantes",
	DISCORD_FEATPTS_ONE  = "%s point de hauts faits",
	DISCORD_FEATPTS_MANY = "%s points de hauts faits",
	DISCORD_POINTS_ONE   = "%s point",
	DISCORD_POINTS_MANY  = "%s points",
	DISCORD_SEALS_ONE    = "%s sceau",
	DISCORD_SEALS_MANY   = "%s sceaux",
	DISCORD_FEATS_ONE    = "%s haut fait",
	DISCORD_FEATS_MANY   = "%s hauts faits",
	DISCORD_STATS_HEAD   = "Statistiques de %s",
	DISCORD_STAT_BLOCK   = "%s — %s",
	DISCORD_STAT_ROW     = "%s : %s",
	DISCORD_FEAT_EARNED  = "obtenu le %s",
}
local EN = {
	DISCORD_COPY_TITLE   = "Copy for Discord",
	DISCORD_COPY_HINT    = "Ctrl+C, then paste wherever you like",
	DISCORD_COPY_CLOSE   = "Close",
	DISCORD_COMBAT       = "Not during combat.",
	DISCORD_SIGN         = "Quest Companion, a WoW Forever addon",
	DISCORD_SEP          = " · ",
	DISCORD_SHINY        = "shiny",
	DISCORD_STARS_ONE    = "%d star",
	DISCORD_STARS_MANY   = "%d stars",
	DISCORD_ODDS         = "1 in %s",
	DISCORD_CAUGHT_BY    = "Caught by %s",
	DISCORD_SPECIES_ONE  = "%s species",
	DISCORD_SPECIES_MANY = "%s species",
	DISCORD_SHINIES_ONE  = "%s shiny",
	DISCORD_SHINIES_MANY = "%s shinies",
	DISCORD_FEATPTS_ONE  = "%s achievement point",
	DISCORD_FEATPTS_MANY = "%s achievement points",
	DISCORD_POINTS_ONE   = "%s point",
	DISCORD_POINTS_MANY  = "%s points",
	DISCORD_SEALS_ONE    = "%s seal",
	DISCORD_SEALS_MANY   = "%s seals",
	DISCORD_FEATS_ONE    = "%s achievement",
	DISCORD_FEATS_MANY   = "%s achievements",
	DISCORD_STATS_HEAD   = "Stats for %s",
	DISCORD_STAT_BLOCK   = "%s — %s",
	DISCORD_STAT_ROW     = "%s: %s",
	DISCORD_FEAT_EARNED  = "earned on %s",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.DISCORD_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then return a, b, c, d, e end
	return nil
end
local function Plain(v) if ns.Plain then return ns.Plain(v) end return v end

-- ---------------------------------------------------------------------------
-- Langue : le texte du joueur (ns.L), ou une langue demandée (tests)
-- ---------------------------------------------------------------------------
local function S(key, lang)
	local tables = lang and ns.STRINGS_TABLES
	if tables and tables[lang] then
		local value = (tables[lang] and tables[lang][key]) or (lang ~= "fr" and tables.en and tables.en[key]) or (tables.fr and tables.fr[key])
		if value then return value end
	end
	return L[key]
end
local function F(key, lang, ...)
	local fmt = S(key, lang)
	local ok, text = pcall(string.format, tostring(fmt), ...)
	return ok and text or tostring(fmt)
end
ns.DiscordString = S

local function Number(n, lang)
	if ns.OddsNumber then return ns.OddsNumber(n, lang or ns.STRINGS_LANG) end
	return tostring(math.floor(tonumber(n) or 0))
end
-- « 1 étoile » / « 3 étoiles » (une clé _ONE et une _MANY ; le nombre déjà mis en forme si `formatted`)
local function Count(n, stem, lang, raw)
	n = tonumber(n) or 0
	local value = raw and n or Number(n, lang)
	return F(stem .. (n == 1 and "_ONE" or "_MANY"), lang, value)
end
ns.DiscordCount = Count

-- échappe la mise en forme de Discord dans un texte venu du joueur ou du jeu
function ns.DiscordEscape(text)
	return (tostring(text or ""):gsub(ns.DISCORD_ESCAPE, "\\%1"))
end
local Esc = ns.DiscordEscape

-- date du jour d'un horodatage, à la façon de la langue
function ns.DiscordDate(at, lang)
	at = tonumber(at)
	local date = G("date") or (os and os.date)
	if not at or at <= 0 or type(date) ~= "function" then return nil end
	lang = lang or ns.STRINGS_LANG
	local ok, text = pcall(date, lang == "en" and "%Y-%m-%d" or "%d/%m/%Y", at)
	return ok and text or nil
end

-- coupe à `max` octets sans casser un caractère UTF-8 (points de suspension)
local function Cut(text, max)
	if #text <= max then return text end
	local cut = max - 3
	while cut > 0 do
		local byte = text:byte(cut + 1)
		if not byte or byte < 128 or byte >= 192 then break end
		cut = cut - 1
	end
	return text:sub(1, cut) .. "…"
end

-- ---------------------------------------------------------------------------
-- Ce que l'on sait du joueur : nom et titre, rang, chiffres
-- ---------------------------------------------------------------------------
function ns:DiscordWho()
	local name = Call(self.TrainerMe, self) or Plain(Call(G("UnitName"), "player")) or "?"
	name = tostring(name):match("^([^%-]+)") or tostring(name)
	local code = Call(self.FeatTitleCode, self)
	if code and self.FeatTitleWho then
		local gender = Call(self.FeatTitleGender, self)
		local who = Call(self.FeatTitleWho, self, name, code, gender)
		if type(who) == "string" and who ~= "" then return who, name end
	end
	return name, name
end

-- { who, name, points, feats, rank, species, total, shinies, seals, companion }
function ns:DiscordFigures()
	local fig = {}
	fig.who, fig.name = self:DiscordWho()
	local card = Call(self.TrainerOwnCard, self)
	if type(card) == "table" then
		fig.species, fig.total = tonumber(card.species), tonumber(card.total)
		fig.shinies, fig.seals = tonumber(card.shinies), tonumber(card.seals)
		fig.feats = type(card.feats) == "table" and tonumber(card.feats.count) or nil
		fig.companion = type(card.companion) == "table" and card.companion or nil
	end
	local points, count = Call(self.FeatPoints, self, nil)
	fig.points = tonumber(points) or 0
	fig.feats = fig.feats or tonumber(count)
	local _, rank = Call(self.FeatRank, self, fig.points)
	fig.rank = rank
	if not fig.species then
		local data = Call(self.CaptureData, self)
		fig.species = type(data) == "table" and tonumber(data.count) or 0
	end
	fig.shinies = fig.shinies or tonumber(Call(self.CaptureShinyCount, self)) or 0
	return fig
end

-- ---------------------------------------------------------------------------
-- Sujets : un spécimen, un haut fait obtenu
-- ---------------------------------------------------------------------------
-- Le spécimen d'un sujet (table, identifiant, bandeau de prise), sa
-- version brillante quand le bandeau le dit, et le niveau s'il est connu.
function ns:DiscordSpecimen(subject)
	local level
	if type(subject) == "table" and subject.kind == "capture" then
		local result = type(subject.result) == "table" and subject.result or {}
		level = tonumber(result.level)
		local spec = result.specimen
		if type(spec) ~= "table" and spec ~= nil and self.SpecimenGet then spec = self:SpecimenGet(spec) end
		if type(spec) ~= "table" then
			-- un bandeau sans spécimen (version d'avant) : ce qu'il dit lui-même
			if not result.npcID and not result.name then return nil end
			spec = { npc = tonumber(result.npcID), name = result.name, stars = tonumber(result.stars) or 1,
				shiny = result.shiny and true or nil, size = result.size, trait = result.trait }
		end
		if result.shiny and not spec.shiny then
			local copy = {}
			for k, v in pairs(spec) do copy[k] = v end
			copy.shiny = true
			spec = copy
		end
		return spec, level
	end
	if type(subject) == "table" and subject.kind == "specimen" then subject = subject.spec or subject.id end
	if type(subject) ~= "table" and subject ~= nil and self.SpecimenGet then subject = self:SpecimenGet(subject) end
	if type(subject) ~= "table" or not (subject.npc or subject.name) then return nil end
	return subject, level
end

-- La définition d'un haut fait OBTENU (secret découvert compris), et la date ;
-- nil pour une ligne inconnue, en attente, pas encore obtenue
function ns:DiscordFeat(subject)
	local id = subject
	if type(subject) == "table" then
		if subject.kind == "feat" then id = subject.def or subject.id or (type(subject.entry) == "table" and subject.entry.id) end
		if type(id) == "table" and id.def then id = id.def end
	end
	local def = type(id) == "table" and id or (self.FeatDef and self:FeatDef(id))
	if type(def) ~= "table" or not def.id or def.pending then return nil end
	local got = self.FeatGot and self:FeatGot(def)
	if not got then return nil end
	return def, type(got) == "table" and tonumber(got.at) or nil
end

-- l'espèce d'un spécimen, sans « (brillant) »
function ns:DiscordSpecies(spec)
	if type(spec) ~= "table" then return "?" end
	if self.CreatureName and spec.npc then return self:CreatureName(spec.npc, { name = spec.name }) end
	return tostring(spec.name or spec.npc or "?")
end

-- ---------------------------------------------------------------------------
-- Les textes
-- ---------------------------------------------------------------------------
local function Signed(lines, lang)
	lines[#lines + 1] = S("DISCORD_SIGN", lang)
	lines[#lines + 1] = ns.DISCORD_URL
	for index, line in ipairs(lines) do lines[index] = Cut(line, ns.DISCORD_LINE_MAX) end
	-- trop long : les lignes du corps partent par la fin (titre et signature restent)
	while #table.concat(lines, "\n") >= ns.DISCORD_MAX and #lines > 3 do table.remove(lines, #lines - 2) end
	return table.concat(lines, "\n")
end

local function FiguresLine(fig, lang)
	local sep = S("DISCORD_SEP", lang)
	return Count(fig.species, "DISCORD_SPECIES", lang) .. sep .. Count(fig.shinies, "DISCORD_SHINIES", lang)
		.. sep .. Count(fig.points, "DISCORD_FEATPTS", lang)
end

local TEXTS = {}

-- « **Croc** · Raptor de Strangleronce · brillante · 3 étoiles · Géant (1 chance sur 107 143) »
-- « Prise de Dyokrion, Maître des brillantes · Vallée de Strangleronce »
-- « 312 espèces · 14 brillantes · 1 240 points de hauts faits »
function TEXTS.capture(self, subject, lang)
	local spec = self:DiscordSpecimen(subject)
	if not spec then return nil end
	local sep = S("DISCORD_SEP", lang)
	local species = Esc(self:DiscordSpecies(spec))
	local parts = {}
	if spec.nick and spec.nick ~= "" then
		parts[1] = "**" .. Esc(spec.nick) .. "**"
		parts[2] = species
	else
		parts[1] = "**" .. species .. "**"
	end
	if spec.shiny then parts[#parts + 1] = S("DISCORD_SHINY", lang) end
	local stars = tonumber(spec.stars)
	if stars then parts[#parts + 1] = Count(stars, "DISCORD_STARS", lang, true) end
	if spec.size and spec.size ~= "normal" and ns.SPECIMEN_SIZE_BY_ID and ns.SPECIMEN_SIZE_BY_ID[spec.size] then
		parts[#parts + 1] = S("SPEC_SIZE_" .. spec.size, lang)
	end
	local first = table.concat(parts, sep)
	local odds = self.SpecimenOddsShown and self:SpecimenOddsShown(spec)
	if odds then first = first .. " (" .. F("DISCORD_ODDS", lang, Number(odds, lang)) .. ")" end
	local fig = self:DiscordFigures()
	local caught = F("DISCORD_CAUGHT_BY", lang, Esc(fig.who))
	local info = spec.zone and self.MapInfo and self:MapInfo(spec.zone)
	if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then caught = caught .. sep .. Esc(info.name) end
	return Signed({ first, caught, FiguresLine(fig, lang) }, lang)
end
TEXTS.specimen = TEXTS.capture

-- « **Dyokrion, Maître des brillantes** » / « Réputé · 1 240 points » /
-- « 312 espèces · 14 brillantes · 3 sceaux · 142 hauts faits »
function TEXTS.trainer(self, _, lang)
	local fig = self:DiscordFigures()
	local sep = S("DISCORD_SEP", lang)
	local points = Count(fig.points, "DISCORD_POINTS", lang)
	local second = fig.rank and (fig.rank .. sep .. points) or points
	local third = Count(fig.species, "DISCORD_SPECIES", lang) .. sep .. Count(fig.shinies, "DISCORD_SHINIES", lang)
		.. sep .. Count(fig.seals or 0, "DISCORD_SEALS", lang) .. sep .. Count(fig.feats or 0, "DISCORD_FEATS", lang)
	return Signed({ "**" .. Esc(fig.who) .. "**", second, third }, lang)
end

-- « **Statistiques de Dyokrion** », puis un bloc par ligne :
-- « Captures — Prises : 1 240 · Brillantes : 14 » (valeurs inconnues omises)
function TEXTS.stats(self, _, lang)
	if type(self.FeatStatsBlocks) ~= "function" then return nil end
	local ok, blocks = pcall(self.FeatStatsBlocks, self)
	if not ok or type(blocks) ~= "table" or #blocks == 0 then return nil end
	local fig = { who = (self:DiscordWho()) }
	local lines = { "**" .. Esc(F("DISCORD_STATS_HEAD", lang, fig.who)) .. "**" }
	local sep = S("DISCORD_SEP", lang)
	for _, block in ipairs(blocks) do
		if type(block) == "table" then
			local rows = {}
			for _, row in ipairs(type(block.rows) == "table" and block.rows or {}) do
				local value = type(row) == "table" and row.value ~= nil and tostring(row.value) or nil
				if value and value ~= "" and value ~= "—" and row.label then
					rows[#rows + 1] = F("DISCORD_STAT_ROW", lang, tostring(row.label), value)
				end
			end
			if #rows > 0 then lines[#lines + 1] = F("DISCORD_STAT_BLOCK", lang, tostring(block.title or block.key or ""), table.concat(rows, sep)) end
		end
	end
	if #lines == 1 then return nil end
	return Signed(lines, lang)
end

-- « **Cinq cents prises** » / « Capturer 500 créatures » / « 25 points · obtenu le 22/11/2026 »
function TEXTS.feat(self, subject, lang)
	local def, at = self:DiscordFeat(subject)
	if not def then return nil end
	local name = self:FeatName(def)
	local condition = self.FeatDescription and self:FeatDescription(def) or ""
	local third = Count(tonumber(def.pts) or 0, "DISCORD_POINTS", lang)
	local day = ns.DiscordDate(at, lang)
	if day then third = third .. S("DISCORD_SEP", lang) .. F("DISCORD_FEAT_EARNED", lang, day) end
	local lines = { "**" .. Esc(name) .. "**" }
	if condition ~= "" then lines[#lines + 1] = condition end
	lines[#lines + 1] = third
	return Signed(lines, lang)
end

function ns:DiscordText(kind, subject, lang)
	local fn = TEXTS[kind]
	if not fn then return nil end
	local ok, text = pcall(fn, self, subject, lang)
	if not ok then
		if self.RecordError then self:RecordError("discord:" .. tostring(kind), text) end
		return nil
	end
	return text
end

-- ---------------------------------------------------------------------------
-- La fenêtre de copie
-- ---------------------------------------------------------------------------
local function InCombat()
	local fn = G("InCombatLockdown")
	return type(fn) == "function" and Plain(fn()) == true
end
ns.SouvenirInCombat = InCombat

local function BuildCopy()
	local D = ns.DISCORD_COPY
	local frame = Theme.CreateWindow(UIParent, D.w, D.h, { name = "QuestCompanionDiscordCopy", strata = "FULLSCREEN_DIALOG" })
	if not frame then return nil end
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame.title = Theme.CreateTitle(frame, 16)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", D.pad, -D.pad)
	frame.title:SetJustifyH("LEFT")
	-- la zone : le creux du thème, une EditBox sur plusieurs lignes, verrouillée
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetSize(D.w - 2 * D.pad, D.areaH)
	holder:SetPoint("TOPLEFT", frame, "TOPLEFT", D.pad, -D.areaY)
	holder.bg = Theme.Solid(holder, "BACKGROUND", Theme.FIELD, 1)
	holder.bg:SetAllPoints()
	holder.border = Theme.Border(holder, Theme.EDGE, 1)
	if Theme.Forged() and Theme.ForgeSlice then
		holder.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 0)
		holder.inset = Theme.ForgeSlice(holder, "inset", Theme.EDGE)
	end
	local scroll = CreateFrame("ScrollFrame", nil, holder)
	scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 9, -7)
	scroll:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -9, 7)
	if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
	local edit = CreateFrame("EditBox", nil, scroll)
	if edit.SetMultiLine then edit:SetMultiLine(true) end
	if edit.SetAutoFocus then edit:SetAutoFocus(false) end
	edit:SetFontObject(Theme.F_SMALL)
	edit:SetWidth(D.w - 2 * D.pad - 18)
	edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
	if edit.SetMaxLetters then edit:SetMaxLetters(D.maxLetters) end
	if edit.SetTextColor then edit:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3], 1) end
	if scroll.SetScrollChild then scroll:SetScrollChild(edit) end
	-- chaque frappe remet le texte, tout sélectionné (ns.CopyBoxLock, socle)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self.copyURL and self:GetText() ~= self.copyURL then ns.CopyBoxLock(self, self.copyURL) end
	end)
	edit:SetScript("OnEditFocusGained", function(self) if self.HighlightText then self:HighlightText() end end)
	edit:SetScript("OnEscapePressed", function() frame:Hide() end)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		if not (scroll.SetVerticalScroll and scroll.GetVerticalScroll) then return end
		local max = math.max(0, (tonumber(edit:GetHeight()) or 0) - (tonumber(scroll:GetHeight()) or 0))
		local value = (tonumber(scroll:GetVerticalScroll()) or 0) - (tonumber(delta) or 0) * 30
		scroll:SetVerticalScroll(math.min(math.max(value, 0), max))
	end)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function() frame:Select() end)
	frame.area, frame.scroll, frame.edit = holder, scroll, edit
	frame.closeButton = Theme.CreateButton(frame, "auto", "md", L.DISCORD_COPY_CLOSE, function() frame:Hide() end, "accent")
	frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -D.pad, 16)
	frame.hint = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.hint:SetPoint("LEFT", frame, "BOTTOMLEFT", D.pad, 16 + Theme.ButtonHeight("md") / 2)
	frame.hint:SetJustifyH("LEFT")
	frame.hint:SetText(L.DISCORD_COPY_HINT)
	function frame:Select()
		if edit.SetFocus then edit:SetFocus() end
		if edit.HighlightText then edit:HighlightText() end
	end
	frame:SetScript("OnHide", function()
		if edit.ClearFocus then edit:ClearFocus() end
	end)
	-- le combat ferme la fenêtre
	if frame.RegisterEvent then pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED") end
	frame:SetScript("OnEvent", function(f, event)
		if event == "PLAYER_REGEN_DISABLED" and f:IsShown() then f:Hide() end
	end)
	frame:Hide()
	return frame
end

function ns:EnsureDiscordCopy()
	if not self.discordCopy then self.discordCopy = BuildCopy() end
	return self.discordCopy
end

-- ns.DiscordCopyShow(texte, titre) (appel par point ; ns:DiscordCopyShow aussi)
function ns.DiscordCopyShow(text, title, extra)
	if text == ns then text, title = title, extra end
	if type(text) ~= "string" or text == "" then return nil end
	if InCombat() then
		ns:Print(L.DISCORD_COMBAT)
		return nil
	end
	local frame = ns:EnsureDiscordCopy()
	if not frame then return nil end
	frame.title:SetText(type(title) == "string" and title ~= "" and title or L.DISCORD_COPY_TITLE)
	frame.value = text
	ns.CopyBoxLock(frame.edit, text)
	if frame.edit.SetCursorPosition then frame.edit:SetCursorPosition(0) end
	if frame.scroll.SetVerticalScroll then frame.scroll:SetVerticalScroll(0) end
	frame:Show()
	if frame.Raise then frame:Raise() end
	frame:Select()
	return frame
end

if ns.Mark then ns.Mark("DiscordCopy") end
