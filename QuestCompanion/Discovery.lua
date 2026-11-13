-- Discovery.lua -- astuces de découverte du compagnon (QuestCompanion 3.1.0)
--
-- Le compagnon apprend l'addon en jouant : de temps en temps, une astuce sur
-- une fonction que le joueur n'utilise pas encore (changer d'allure, le
-- garde-manger, le mode chasse, la Réserve, le juke-box…).
--   * Même canal que les astuces d'avant (Companion.lua, CompanionTryTip :
--     catégorie TIP, son écart TIP_GAP + hasard) : ns:DiscoveryPick propose
--     une astuce de découverte quand c'est le moment, sinon l'astuce
--     ordinaire passe. Pas de second système de bavardage.
--   * Rythme : au plus une toutes les 20 min de jeu ; jamais en combat, en
--     instance (donjon, raid, champ de bataille), carte de capture, volée de
--     « Tout capturer » ou visite guidée ; la première pas avant 10 min après
--     la première connexion du jour.
--   * Chaque astuce : une fois par compte (QuestCompanionDB.discovery.seen),
--     jamais si la fonction est déjà connue (`learned` : données existantes,
--     ou un petit drapeau posé à son usage : discovery.used.<clé>, au
--     compte), seulement si elle a du sens (`eligible`). Toutes vues : plus
--     rien. /qc astuces reset les rejoue.
--   * Clic sur la bulle d'une astuce qui a une page : la page (sélecteur
--     d'allure, juke-box, Échoppe, Guide…). Les autres bulles ne changent pas
--     (toujours transparentes à la souris).
--   * Réglage « Astuces du compagnon sur l'addon » (page Compagnon de route,
--     actif) et /qc astuces on|off|reset.
-- La voix reste neutre (une phrase par langue, pas une par caractère).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.DISCOVERY_GAP = 1200       -- s de jeu entre deux astuces de découverte
ns.DISCOVERY_FIRST = 600      -- s après la première connexion du jour
ns.DISCOVERY_MAX_BYTES = 200  -- une bulle (texte, aide au clic comprise)

local function G(name) return rawget(_G, name) end
local function Call(name, ...)
	local fn = G(name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Wall() return tonumber(Call("time")) or 0 end
local function Day() return math.floor(Wall() / 86400) end

-- Le carnet sur une page
local function Page(self, kind)
	if not self.ToggleJournal then return nil end
	local frame = self:ToggleJournal(true)
	if frame and self.SelectJournalKind then self:SelectJournalKind(kind) end
	return frame
end

-- ---------------------------------------------------------------------------
-- Le magasin (au compte)
-- ---------------------------------------------------------------------------
function ns:DiscoveryData()
	local db = self:DB()
	local data = db.discovery
	if type(data) ~= "table" then
		data = {}
		db.discovery = data
	end
	if type(data.seen) ~= "table" then data.seen = {} end
	if type(data.used) ~= "table" then data.used = {} end
	return data
end

-- Une fonction utilisée : l'astuce qui l'apprend ne sera plus dite
function ns:DiscoveryUse(key)
	if key then self:DiscoveryData().used[key] = true end
end
local function Used(self, key) return self:DiscoveryData().used[key] == true end
local function Captures(self) return self.CaptureCaughtCount and tonumber(self:CaptureCaughtCount()) or 0 end
local function Reserve(self) return self.SpecimenReserveCount and tonumber(self:SpecimenReserveCount()) or 0 end
local function Level() return tonumber(Call("UnitLevel", "player")) or 1 end

-- ---------------------------------------------------------------------------
-- Le catalogue : id, FR, EN, learned, eligible, open (tout facultatif sauf
-- le texte ; learned/eligible/open reçoivent ns)
-- ---------------------------------------------------------------------------
ns.DISCOVERY_TIPS = {
	-- le compagnon
	{ id = "look",
		fr = "Tu sais que je peux changer d'allure ? Carnet, page Compagnon, bouton « Choisir… ».",
		en = "Did you know I can change my look? Journal, Companion page, \"Choose…\" button.",
		learned = function(self)
			if Used(self, "look") then return true end
			local data = self:CompanionData()
			local first = ns.COMPANION_APPEARANCES and ns.COMPANION_APPEARANCES[1]
			return data.appearance ~= nil and first ~= nil and data.appearance ~= first.id
		end,
		eligible = function(self)
			local list = self.CompanionUnlockedAppearances and self:CompanionUnlockedAppearances()
			return type(list) == "table" and #list > 1
		end,
		open = function(self) Page(self, "evolution"); if self.AllureOpen then self:AllureOpen() end end },
	{ id = "frame",
		fr = "Mon cadre et mon fond se changent aussi : page Compagnon du carnet, ou les réglages.",
		en = "My frame and background can change too: Companion page of the journal, or the settings.",
		learned = function(self) return Used(self, "frame") end,
		eligible = function(self) return Level() >= 10 end,
		open = function(self) Page(self, "evolution") end },
	{ id = "pet",
		fr = "Un clic sur moi, c'est une caresse. Mon moral adore ça.",
		en = "A click on me is a pat. My mood loves it.",
		learned = function(self) return Used(self, "pet") end },
	{ id = "pantry",
		fr = "Maj + clic sur moi : mon garde-manger. Une friandise, et l'envie la plus basse remonte.",
		en = "Shift + click on me: my pantry. One treat and my lowest need goes back up.",
		learned = function(self) return Used(self, "pantry") end,
		open = function(self) if self.TreatMenuToggle then self:TreatMenuToggle() end end },
	{ id = "journal",
		fr = "Clic droit sur moi : le carnet, d'un geste.",
		en = "Right-click on me: the journal, in one move.",
		learned = function(self) return Used(self, "rightClick") end,
		open = function(self) if self.CompanionOpenJournal then self:CompanionOpenJournal() end end },
	{ id = "menu",
		fr = "Maj + clic droit sur moi : un petit menu, avec le mode chasse.",
		en = "Shift + right-click on me: a small menu, with hunt mode.",
		learned = function(self) return Used(self, "menu") or Used(self, "hunt") end,
		eligible = function(self) return Captures(self) >= 1 end,
		open = function(self) if self.CompanionMenuShow then self:CompanionMenuShow() end end },
	{ id = "needs",
		fr = "Survole-moi : ma faim, mon énergie, mon moral et ma curiosité. Heureux, j'évolue.",
		en = "Hover me: my hunger, energy, mood and curiosity. Happy, I evolve.",
		learned = function(self) return Used(self, "hover") end },
	{ id = "personality",
		fr = "J'ai mon caractère : il me donne une mission chaque jour. Il est écrit page Compagnon.",
		en = "I have my own character: it gives me a mission every day. It's on the Companion page.",
		learned = function(self) return Used(self, "page_evolution") end,
		open = function(self) Page(self, "evolution") end },
	{ id = "size",
		fr = "Trop petit ? Trop grand ? Ma taille se règle dans les options, page Compagnon de route.",
		en = "Too small? Too big? My size is in the settings, Road companion page.",
		learned = function(self)
			local size = self:DB().companionSize
			return Used(self, "size") or (size ~= nil and tonumber(size) ~= tonumber(ns.COMPANION_SIZE_DEFAULT))
		end,
		eligible = function(self) return Level() >= 5 end,
		open = function(self) if self.ToggleOptions then self:ToggleOptions() end end },
	-- la capture
	{ id = "aids",
		fr = "Sur la carte de capture, choisis une aide : appât, lasso ou sifflet. Puis Lancer, ou Passer.",
		en = "On the capture card, pick an aid: bait, lasso or whistle. Then Throw, or Skip.",
		learned = function(self) return Used(self, "aid") end,
		eligible = function(self) return Captures(self) >= 1 end },
	{ id = "direct",
		fr = "Pressé ? Maj + clic sur le filet : il part tout de suite, sans la carte.",
		en = "In a hurry? Shift + click the net: it goes at once, without the card.",
		learned = function(self) return Used(self, "direct") or self:DB().companionCaptureDirect == true end,
		eligible = function(self) return Captures(self) >= 3 end },
	{ id = "batch",
		fr = "Plusieurs créatures au filet ? Ctrl + clic sur le filet, ou /qc filet tout : tout capturer.",
		en = "Several creatures in the net? Ctrl + click the net, or /qc filet tout: capture them all.",
		learned = function(self) return Used(self, "batch") end,
		eligible = function(self) return Captures(self) >= 3 end },
	{ id = "pins",
		fr = "Page Créatures, « À compléter » : épingle une espèce, le filet la guettera pour toi.",
		en = "Creatures page, \"To complete\": pin a species, the net will watch for it.",
		learned = function(self)
			local pins = self.CaptureData and self:CaptureData().pins
			return Used(self, "pin") or (type(pins) == "table" and next(pins) ~= nil)
		end,
		eligible = function(self) return Captures(self) >= 5 end,
		open = function(self) if self.OpenMenagerieTodo then self:OpenMenagerieTodo() end end },
	{ id = "locate",
		fr = "Il te manque une espèce ? « Localiser » pose un repère sur ta carte, là où elle vit.",
		en = "Missing a species? \"Locate\" puts a pin on your map, where it lives.",
		learned = function(self) return Used(self, "locate") end,
		eligible = function(self) return Captures(self) >= 5 end,
		open = function(self) if self.OpenMenagerieTodo then self:OpenMenagerieTodo() end end },
	{ id = "hunt",
		fr = "Le mode chasse met chaque monstre abattu au filet : 5, 15, 30 min, 1 h ou jusqu'à l'arrêt. Maj + clic droit sur moi.",
		en = "Hunt mode puts every monster you kill in the net: 5, 15, 30 min, 1 h or until you stop. Shift + right-click on me.",
		learned = function(self) return Used(self, "hunt") end,
		eligible = function(self) return Captures(self) >= 5 end },
	{ id = "wary",
		fr = "En chasse, une espèce capturée trop souvent dans la journée devient méfiante. Varie les proies !",
		en = "In hunt mode, a species captured too often in a day gets wary. Vary your prey!",
		learned = function(self)
			local wary = self.CaptureData and self:CaptureData().wary
			if type(wary) ~= "table" or type(wary.n) ~= "table" then return false end
			for _, count in pairs(wary.n) do if (tonumber(count) or 0) >= 3 then return true end end
			return false
		end,
		eligible = function(self) return Used(self, "hunt") end },
	-- la Réserve
	{ id = "release",
		fr = "Un spécimen en trop dans la Réserve ? Relâche-le : il te rend des paillettes.",
		en = "A spare specimen in the Reserve? Release it: it gives you glitter.",
		learned = function(self) return Used(self, "release") end,
		eligible = function(self) return Reserve(self) >= 1 end,
		open = function(self) if self.OpenReserve then self:OpenReserve("reserve") end end },
	{ id = "codex",
		fr = "Dans la Réserve, « Mettre au Codex » fait d'un spécimen ta référence (et une allure possible).",
		en = "In the Reserve, \"Put in the Codex\" makes a specimen your reference (and a possible look).",
		learned = function(self) return Used(self, "codex") end,
		eligible = function(self) return Reserve(self) >= 1 end,
		open = function(self) if self.OpenReserve then self:OpenReserve("reserve") end end },
	{ id = "shop",
		fr = "Tes paillettes se dépensent à l'Échoppe du dresseur : aides, places de Réserve, allure.",
		en = "Your glitter is spent at the Trainer's Stall: aids, Reserve slots, looks.",
		learned = function(self) return Used(self, "shop") end,
		eligible = function(self) return (self.Paillettes and tonumber(self:Paillettes()) or 0) >= 5 end,
		open = function(self) if self.OpenShop then self:OpenShop() end end },
	{ id = "trade",
		fr = "Un ami a l'addon ? Cible-le et tape /qc echange, ou clic droit sur son portrait : échangez des spécimens.",
		en = "A friend has the addon? Target them and type /qc echange, or right-click their portrait: trade specimens.",
		learned = function(self)
			local log = self.TradeLog and self:TradeLog()
			return Used(self, "trade") or (type(log) == "table" and #log > 0)
		end,
		eligible = function(self) return Reserve(self) >= 1 end },
	-- le carnet
	{ id = "keys",
		fr = "Le carnet s'ouvre aussi avec la touche Y (si elle était libre) ou le bouton de la minicarte.",
		en = "The journal also opens with the Y key (if it was free) or the minimap button.",
		learned = function(self) return (tonumber(self:DiscoveryData().used.journalOpens) or 0) >= 5 end },
	{ id = "chests",
		fr = "Page Exploration : chaque zone a ses paliers, et un coffre pour moi à 100 %%.",
		en = "Exploration page: every zone has milestones, and a chest for me at 100%%.",
		learned = function(self) return Used(self, "chest") or Used(self, "page_progress") end,
		open = function(self) Page(self, "progress") end },
	{ id = "missions",
		fr = "Page Missions : trois missions par jour, trois par semaine, et des paillettes à la clé.",
		en = "Missions page: three missions a day, three a week, and glitter as a reward.",
		learned = function(self) return Used(self, "page_day") end,
		eligible = function(self) return Captures(self) >= 1 end,
		open = function(self) Page(self, "day") end },
	{ id = "titles",
		fr = "Tes hauts faits t'ont donné un titre : /qc titre pour le porter.",
		en = "Your achievements gave you a title: /qc title to wear it.",
		learned = function(self) return Used(self, "title") end,
		eligible = function(self)
			local earned = self.FeatTitlesEarned and self:FeatTitlesEarned()
			return type(earned) == "table" and #earned > 0
		end,
		open = function(self) if self.OpenJournalFeats then self:OpenJournalFeats("all") end end },
	{ id = "trainer",
		fr = "/qc fiche : ta fiche de dresseur. Les joueurs qui ont l'addon la voient d'un clic droit sur toi.",
		en = "/qc fiche: your trainer card. Players with the addon see it with a right-click on you.",
		learned = function(self) return Used(self, "trainer") end,
		eligible = function(self) return Captures(self) >= 3 end,
		open = function(self) if self.TrainerOpen then self:TrainerOpen() end end },
	{ id = "guild",
		fr = "En guilde, tes beaux exploits s'affichent chez les guildeux qui ont l'addon.",
		en = "In a guild, your big feats show up for guildmates who have the addon.",
		learned = function(self) return Used(self, "guildFeat") end,
		eligible = function() return Call("IsInGuild") and true or false end },
	{ id = "juke",
		fr = "/qc juke : le juke-box, toutes les musiques des zones. Je fredonne avec toi.",
		en = "/qc juke: the jukebox, every zone's music. I'll hum along.",
		learned = function(self) return Used(self, "juke") end,
		open = function(self) if self.OpenJournalJuke then self:OpenJournalJuke() end end },
	{ id = "guide",
		fr = "Une question ? La page Guide explique tout, et /qc tuto rejoue les visites guidées.",
		en = "A question? The Guide page explains everything, and /qc tuto replays the guided tours.",
		learned = function(self) return Used(self, "page_guide") or Used(self, "tuto") end,
		open = function(self) Page(self, "guide") end },
	{ id = "style",
		fr = "/qc style azeroth ou sobre : deux habits pour toute l'interface, bandeaux compris.",
		en = "/qc style azeroth or sobre: two outfits for the whole interface, banners included.",
		learned = function(self) return Used(self, "style") end,
		eligible = function() return Level() >= 5 end },
	{ id = "noel",
		fr = "C'est le Voile d'hiver ! /qc noel pour décorer le carnet et me déguiser.",
		en = "It's Winter Veil! /qc noel to decorate the journal and dress me up.",
		learned = function(self) return Used(self, "noel") end,
		eligible = function(self) return self.WinterVeilSeason and self:WinterVeilSeason() and true or false end },
	-- partager
	{ id = "share",
		fr = "Un beau bandeau ? L'icône de chat dessus le partage en guilde ou en groupe.",
		en = "A nice banner? The chat icon on it shares it with your guild or group.",
		learned = function(self) return Used(self, "share") end,
		eligible = function(self) return Captures(self) >= 1 end },
	{ id = "announce",
		fr = "En groupe, j'annonce tes brillantes et tes 3 étoiles. Réglable page Carnet de voyage.",
		en = "In a group, I announce your shinies and 3-star catches. Set it on the Travel journal page.",
		learned = function(self) return Used(self, "announce") or self:DB().announceGroup == false end,
		eligible = function()
			return (Call("IsInGroup") or Call("IsInRaid")) and true or false
		end },
	-- l'autre addon : une fois, seulement s'il n'est pas là
	{ id = "r2q",
		fr = "Psst : Ready2Quest, l'autre addon du projet, prépare tes départs. Page « Addons liés ».",
		en = "Psst: Ready2Quest, the project's other addon, gets you ready to head out. \"Related addons\" page.",
		learned = function(self) return Used(self, "page_addons") end,
		eligible = function(self)
			local status = self.AddonsR2QStatus and self:AddonsR2QStatus()
			return status ~= "loaded" and not (type(G("Ready2Quest")) == "table")
		end,
		open = function(self) Page(self, "addons") end },
}
local BY_ID = {}
for _, tip in ipairs(ns.DISCOVERY_TIPS) do BY_ID[tip.id] = tip; tip.line = "DISC_" .. tip.id end
ns.DISCOVERY_BY_ID = BY_ID

local CLICK_FR, CLICK_EN = " Clique sur la bulle pour voir.", " Click the bubble to see."
local FR = {
	OPT_COMP_DISCOVERY      = "Astuces du compagnon sur l'addon",
	OPT_COMP_DISCOVERY_DESC = "De temps en temps (au plus une toutes les 20 min, jamais en combat ni en instance), il te fait découvrir une fonction que tu n'utilises pas encore. /qc astuces on|off|reset.",
	DISC_CMD_ON     = "Astuces sur l'addon : actives.",
	DISC_CMD_OFF    = "Astuces sur l'addon : coupées.",
	DISC_CMD_RESET  = "Astuces sur l'addon : elles seront toutes redites.",
	DISC_CMD_USAGE  = "/qc astuces on|off|reset (actuellement : %s, %d / %d vues)",
	HELP_DISCOVERY  = "/qc astuces on|off|reset -- les astuces du compagnon sur l'addon",
}
local EN = {
	OPT_COMP_DISCOVERY      = "Companion tips about the addon",
	OPT_COMP_DISCOVERY_DESC = "Now and then (at most one every 20 min, never in combat or instances), it shows you a feature you don't use yet. /qc astuces on|off|reset.",
	DISC_CMD_ON     = "Tips about the addon: on.",
	DISC_CMD_OFF    = "Tips about the addon: off.",
	DISC_CMD_RESET  = "Tips about the addon: they will all be told again.",
	DISC_CMD_USAGE  = "/qc astuces on|off|reset (now: %s, %d / %d seen)",
	HELP_DISCOVERY  = "/qc astuces on|off|reset -- the companion's tips about the addon",
}
for _, tip in ipairs(ns.DISCOVERY_TIPS) do
	FR[tip.line] = tip.fr .. (tip.open and CLICK_FR or "")
	EN[tip.line] = tip.en .. (tip.open and CLICK_EN or "")
end
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.DISCOVERY_STRINGS = { fr = FR, en = EN } end
-- le texte des astuces n'a plus besoin d'être gardé dans le catalogue
for _, tip in ipairs(ns.DISCOVERY_TIPS) do
	if not ns.KEEP_STRINGS then tip.fr, tip.en = nil, nil end
end

ns.RegisterDefaults({ companionDiscovery = true })

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then table.insert(section[2], "HELP_DISCOVERY") end
	end
end

-- ---------------------------------------------------------------------------
-- Le moment, et l'astuce
-- ---------------------------------------------------------------------------
-- Première connexion du jour : notée une fois par jour
function ns:DiscoveryDayMark()
	local data, day = self:DiscoveryData(), Day()
	if data.day ~= day then data.day, data.dayFirst = day, Wall() end
	return data.dayFirst
end

local function Shown(frame) return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false end

-- Le joueur est-il occupé ? (instance, carte de capture, volée, visite)
function ns:DiscoveryBusy()
	if Call("IsInInstance") then return "instance" end
	if self.TourActive and self:TourActive() then return "tour" end
	if self.CapturePrepShown and self:CapturePrepShown() then return "capture" end
	if Shown(self.captureStage) or Shown(self.captureBatchFrame) or Shown(self.captureChooser) then return "capture" end
	return nil
end

-- L'astuce à dire maintenant, ou nil (le moment n'y est pas, rien à dire).
-- Appelée par CompanionTryTip, quand le créneau des astuces est ouvert.
function ns:DiscoveryPick()
	local db = self:DB()
	if db.companionDiscovery == false then return nil end
	local data = self:DiscoveryData()
	local first = self:DiscoveryDayMark()
	if Wall() - (tonumber(first) or 0) < ns.DISCOVERY_FIRST then return nil end
	if self.discoveryLastAt and Clock() - self.discoveryLastAt < ns.DISCOVERY_GAP then return nil end
	if self:DiscoveryBusy() then return nil end
	for _, tip in ipairs(ns.DISCOVERY_TIPS) do
		if not data.seen[tip.id] then
			local ok, learned = pcall(tip.learned or function() return false end, self)
			local fine, eligible = true, true
			if tip.eligible then fine, eligible = pcall(tip.eligible, self) end
			if ok and not learned and fine and eligible then return tip end
		end
	end
	return nil
end

-- Dite : vue pour de bon (au compte), plus rien avant DISCOVERY_GAP
function ns:DiscoveryShown(tip)
	if not tip then return end
	self:DiscoveryData().seen[tip.id] = true
	self.discoveryLastAt = Clock()
	self.discoveryBubble = tip.id
end

-- Clic sur la bulle d'une astuce : sa page
function ns:DiscoveryClick()
	local id = self.discoveryBubble
	local tip = id and BY_ID[id]
	if not (tip and tip.open) then return false end
	if self.companionBubbleLine ~= tip.line then return false end
	self.discoveryBubble = nil
	if self.CompanionHideBubble then self:CompanionHideBubble() end
	local ok, err = pcall(tip.open, self)
	if not ok and self.RecordError then self:RecordError("discovery:open", err) end
	return ok
end

-- La bulle : cliquable seulement pour une astuce qui a une page
do
	local base = ns.CompanionSay
	if base then
		function ns:CompanionSay(pool, opts, ...)
			local done, why = base(self, pool, opts, ...)
			if done then
				local bubble = self.companionBubble
				local tip = self.discoveryBubble and BY_ID[self.discoveryBubble]
				local clickable = tip ~= nil and tip.open ~= nil and self.companionBubbleLine == tip.line
				if not clickable then self.discoveryBubble = nil end
				if bubble and bubble.EnableMouse then
					if clickable and not bubble.discoveryHooked then
						bubble.discoveryHooked = true
						bubble:SetScript("OnMouseUp", function() ns:DiscoveryClick() end)
					end
					bubble:EnableMouse(clickable)
				end
			end
			return done, why
		end
	end
end

-- ---------------------------------------------------------------------------
-- /qc astuces on|off|reset
-- ---------------------------------------------------------------------------
function ns:DiscoveryCommand(rest)
	local word = (tostring(rest or ""):match("^%s*(%S*)") or ""):lower()
	local db = self:DB()
	if word == "on" then
		db.companionDiscovery = true
		return self:Print(L.DISC_CMD_ON)
	elseif word == "off" then
		db.companionDiscovery = false
		return self:Print(L.DISC_CMD_OFF)
	elseif word == "reset" then
		self:DiscoveryData().seen = {}
		self.discoveryLastAt = nil
		return self:Print(L.DISC_CMD_RESET)
	end
	local seen = 0
	for _ in pairs(self:DiscoveryData().seen) do seen = seen + 1 end
	return self:Print(self:F("DISC_CMD_USAGE", db.companionDiscovery == false and L.MODULE_OFF or L.MODULE_ON, seen, #ns.DISCOVERY_TIPS))
end
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["astuces"] = function(self, rest) self:DiscoveryCommand(rest) end
ns.EXTRA_COMMANDS["tips"] = ns.EXTRA_COMMANDS["astuces"]

-- ---------------------------------------------------------------------------
-- « Appris » : un drapeau posé quand la fonction sert (rien de suivi avant)
-- ---------------------------------------------------------------------------
local Unpack = unpack or table.unpack
local function Pack(...) return { n = select("#", ...), ... } end
local function Mark(name, key, test)
	local base = ns[name]
	if type(base) ~= "function" then return end
	ns[name] = function(self, ...)
		-- tous les retours gardés (« false, raison »)
		local out = Pack(base(self, ...))
		local result = out[1]
		local k = key
		if type(key) == "function" then
			local ok, picked = pcall(key, self, result, ...)
			k = ok and picked or nil
		end
		if k and (not test or test(result)) then pcall(ns.DiscoveryUse, ns, k) end
		return Unpack(out, 1, out.n)
	end
end
local function Truthy(result) return result ~= nil and result ~= false end
local function NoShift() return not Call("IsShiftKeyDown") end

Mark("CompanionSetAppearance", "look", Truthy)
Mark("CompanionSetStyle", "frame", Truthy)
Mark("CompanionPet", function() return NoShift() and "pet" or "pantry" end)
Mark("TreatMenuToggle", "pantry")
Mark("TreatGive", "pantry")
Mark("CompanionOpenJournal", "rightClick")
Mark("CompanionMenuShow", "menu")
Mark("CompanionShowHover", "hover")
Mark("CaptureToggleAid", "aid")
Mark("CaptureThrow", function() return Call("IsShiftKeyDown") and "direct" or nil end)
Mark("CaptureBatch", "batch")
Mark("CodexTogglePin", "pin")
Mark("HuntPin", "pin")
Mark("LocateSpecies", "locate")
Mark("ReserveLocate", "locate")
Mark("HuntStart", "hunt")
Mark("SpecimenRelease", "release", Truthy)
Mark("SpecimenSetReference", "codex", Truthy)
Mark("ShopBuy", "shop", Truthy)
Mark("TradeInvite", "trade")
Mark("TradeWithTarget", "trade")
Mark("ChestPick", "chest")
Mark("OpenChest", "chest")
Mark("FeatSetTitle", "title")
Mark("TrainerOpen", "trainer")
Mark("GuildFeatsEnqueue", "guildFeat")
Mark("JukePlay", "juke")
Mark("OpenJournalJuke", "juke")
Mark("TourReplay", "tuto")
Mark("SetUIStyle", "style", Truthy)
Mark("SetWinterVeil", "noel")
Mark("WinterVeilCommand", "noel")
Mark("ShareOpen", "share")
Mark("AnnounceFlush", "announce", function(sent) return (tonumber(sent) or 0) > 0 end)
Mark("SelectJournalKind", function(_, _, kind) return kind and ("page_" .. tostring(kind)) or nil end)
do
	local base = ns.ToggleJournal
	if base then
		function ns:ToggleJournal(...)
			local frame = base(self, ...)
			if frame and frame.IsShown and frame:IsShown() then
				local used = self:DiscoveryData().used
				used.journalOpens = (tonumber(used.journalOpens) or 0) + 1
			end
			return frame
		end
	end
end
-- la taille du compagnon changée dans les réglages
Mark("CompanionApplySize", function(self)
	local size = self:DB().companionSize
	return (size ~= nil and tonumber(size) ~= tonumber(ns.COMPANION_SIZE_DEFAULT)) and "size" or nil
end)

-- Connexion : la première du jour est notée
do
	local ok, events = pcall(CreateFrame, "Frame")
	if ok and events then
		pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
		events:SetScript("OnEvent", function() pcall(ns.DiscoveryDayMark, ns) end)
		ns.discoveryEvents = events
	end
end

if ns.Mark then ns.Mark("Discovery") end
