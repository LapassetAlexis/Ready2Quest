-- JournalWindow.lua -- fenêtre du Carnet de voyage (v1.25.0, refonte)
--
-- Retour joueur : « le carnet n'est pas clair ». Deux endroits, pas plus :
--   * Complétion : une zone (liste déroulante, la zone où tu es par défaut),
--     son pourcentage, son coffre, et un onglet par activité : Exploration,
--     Combat, Métiers, Quêtes. Chaque onglet montre ce qui est fait et ce qui
--     reste, à partir des parts de complétion (ns.ZONE_PARTS).
--   * Évolution : où en est le compagnon, comment il évolue, son prochain
--     objectif, ses envies, ses coffres, sa collection et ton parcours
--     (zones, capitales, donjons, rares, paliers).
-- Les anciens onglets par sorte de tampon disparaissent : leurs données sont
-- rangées dans la zone (villages, rares) ou dans le parcours (le reste).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local WIDTH, HEIGHT = 560, 470
local LINES, LINE_H = 11, 20
local ZONE_LIST_MAX = 12
local ACTIVITIES = { "explore", "combat", "craft", "quests" }
ns.JOURNAL_ACTIVITIES = ACTIVITIES
-- part de complétion -> onglet, quand la part ne le dit pas elle-même
local PART_TAB = { villages = "explore", bestiary = "combat", named = "combat", gathering = "craft", quests = "quests" }

local FR = {
	JRN_SEC_completion     = "Complétion",
	JRN_SEC_evolution      = "Évolution",
	JRN_ZONE_PICK          = "Zone : %s",
	JRN_ZONE_HERE          = "%s (ici)",
	JRN_ZONE_NONE          = "Aucune zone pour l'instant : explore, ton carnet se remplit tout seul.",
	JRN_ACT_explore        = "Exploration",
	JRN_ACT_combat         = "Combat",
	JRN_ACT_craft          = "Métiers",
	JRN_ACT_quests         = "Quêtes",
	JRN_QUESTS_TIP         = "Les quêtes de la zone que ton personnage peut faire (race, classe), livrées avec l'addon. Elles comptent dans les 100 %.",
	JRN_WATCH              = "Suivre à l'écran",
	JRN_WATCH_TIP          = "Cochée : les objectifs de cette zone s'affichent dans le bloc « Carnet » en jeu. La zone où tu es est suivie d'office ; décoche-la pour la masquer.",
	JRN_ACT_EMPTY_explore  = "Aucun village connu dans cette zone.",
	JRN_ACT_EMPTY_combat   = "Aucune créature croisée ici : cible-les ou survole-les pour les noter.",
	JRN_ACT_EMPTY_craft    = "Pas de métier de récolte (herboristerie, minage ou dépeçage), ou rien de ta compétence ici.",
	JRN_ACT_EMPTY_quests   = "Aucune quête connue pour toi dans cette zone.",
	JRN_ACT_NO_QUESTS      = "Pas de liste de quêtes pour ce client.",
	JRN_ZONE_PERCENT       = "%d %%",
	JRN_ZONE_NOPCT         = "Pourcentage dès que deux activités sont suivies ici.",
	JRN_CHEST_TODO         = "À 100 %% : un coffre, un objet au choix (palier %d)",
	JRN_CHEST_READY        = "Coffre gagné : à ouvrir !",
	JRN_CHEST_OPENED       = "Coffre ouvert : %s",
	JRN_CHEST_GOLDEN       = "Zone dorée : tout le palier %d est déjà à toi",
	JRN_OPEN_CHEST         = "Ouvrir le coffre",
	JRN_PART_HEAD          = "%s : %d/%d",
	JRN_ITEM_KILLED        = "abattu (%d)",
	JRN_ITEM_TO_KILL       = "à abattre",
	JRN_ITEM_TO_FIND       = "à trouver",
	JRN_ITEM_LEVEL         = "%s (niv. %s)",
	JRN_ITEM_GATHERED      = "récolté",
	JRN_ITEM_TO_GATHER     = "à récolter (%d)",
	JRN_ITEM_NAMED         = "%s, %s",
	JRN_EVO_STAGE          = "%s — %s (étape %d/%d)",
	JRN_EVO_NEXT_LEVEL     = "Prochaine étape : %s au niveau %d (tu es niveau %d).",
	JRN_EVO_NEXT_READY     = "Prêt à devenir %s : rends-le heureux, il évoluera aussitôt.",
	JRN_EVO_MAX            = "Dernière étape atteinte. Bravo !",
	JRN_EVO_NEEDS          = "Ses envies (heureux = toutes à %d %%)",
	JRN_EVO_HOW            = "Comment ça marche",
	JRN_EVO_HOW_1          = "Ton niveau ouvre chaque étape : 10, 20, 40 et 60.",
	JRN_EVO_HOW_2          = "Pour la franchir, il doit être heureux : ses quatre envies à %d %% ou plus. Mange, repose-toi, rends des quêtes, explore.",
	JRN_EVO_HOW_3          = "Finis une zone à 100 %% (onglet Complétion) : un coffre s'ouvre, tu y choisis une apparence, un ornement, un cadre ou un fond.",
	JRN_EVO_CHESTS         = "Coffres à ouvrir : %d",
	JRN_EVO_COLLECTION     = "Collection : %d/%d  (palier 1 : %d/%d · palier 2 : %d/%d · palier 3 : %d/%d)",
	JRN_EVO_ROAD           = "Parcours : %d zones · %d/%d capitales · %d donjons · %d rares · %d/%d paliers",
}
local EN = {
	JRN_SEC_completion     = "Completion",
	JRN_SEC_evolution      = "Evolution",
	JRN_ZONE_PICK          = "Zone: %s",
	JRN_ZONE_HERE          = "%s (here)",
	JRN_ZONE_NONE          = "No zone yet: explore, your journal fills itself.",
	JRN_ACT_explore        = "Exploration",
	JRN_ACT_combat         = "Combat",
	JRN_ACT_craft          = "Professions",
	JRN_ACT_quests         = "Quests",
	JRN_QUESTS_TIP         = "The zone's quests your character can do (race, class), shipped with the addon. They count toward 100%.",
	JRN_WATCH              = "Track on screen",
	JRN_WATCH_TIP          = "Checked: this zone's goals show in the in-game \"Journal\" tracker. The zone you are in is tracked by default; uncheck it to hide it.",
	JRN_ACT_EMPTY_explore  = "No known village in this zone.",
	JRN_ACT_EMPTY_combat   = "No creature met here yet: target or hover them to log them.",
	JRN_ACT_EMPTY_craft    = "No gathering profession (herbalism, mining or skinning), or nothing of your skill here.",
	JRN_ACT_EMPTY_quests   = "No known quest for you in this zone.",
	JRN_ACT_NO_QUESTS      = "No quest list for this client.",
	JRN_ZONE_PERCENT       = "%d %%",
	JRN_ZONE_NOPCT         = "Percentage as soon as two activities are tracked here.",
	JRN_CHEST_TODO         = "At 100 %%: a chest, one item of your choice (tier %d)",
	JRN_CHEST_READY        = "Chest earned: open it!",
	JRN_CHEST_OPENED       = "Chest opened: %s",
	JRN_CHEST_GOLDEN       = "Golden zone: you already own all of tier %d",
	JRN_OPEN_CHEST         = "Open the chest",
	JRN_PART_HEAD          = "%s: %d/%d",
	JRN_ITEM_KILLED        = "defeated (%d)",
	JRN_ITEM_TO_KILL       = "to defeat",
	JRN_ITEM_TO_FIND       = "to find",
	JRN_ITEM_LEVEL         = "%s (lvl %s)",
	JRN_ITEM_GATHERED      = "gathered",
	JRN_ITEM_TO_GATHER     = "to gather (%d)",
	JRN_ITEM_NAMED         = "%s, %s",
	JRN_EVO_STAGE          = "%s — %s (stage %d/%d)",
	JRN_EVO_NEXT_LEVEL     = "Next stage: %s at level %d (you are level %d).",
	JRN_EVO_NEXT_READY     = "Ready to become %s: make it happy and it grows at once.",
	JRN_EVO_MAX            = "Final stage reached. Well done!",
	JRN_EVO_NEEDS          = "Its needs (happy = all at %d %%)",
	JRN_EVO_HOW            = "How it works",
	JRN_EVO_HOW_1          = "Your level opens each stage: 10, 20, 40 and 60.",
	JRN_EVO_HOW_2          = "To go through, it must be happy: all four needs at %d %% or more. Eat, rest, turn in quests, explore.",
	JRN_EVO_HOW_3          = "Complete a zone to 100 %% (Completion tab): a chest opens and you pick a look, an ornament, a frame or a background.",
	JRN_EVO_CHESTS         = "Chests to open: %d",
	JRN_EVO_COLLECTION     = "Collection: %d/%d  (tier 1: %d/%d · tier 2: %d/%d · tier 3: %d/%d)",
	JRN_EVO_ROAD           = "Road: %d zones · %d/%d capitals · %d dungeons · %d rares · %d/%d milestones",
}
ns.RegisterStrings(FR, EN)
ns.JOURNAL_WINDOW_STRINGS = { fr = FR, en = EN }

local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.companionEnabled ~= false
end

local function ZoneName(self, zoneID)
	local info = self.MapInfo and self:MapInfo(zoneID)
	if info and info.name and info.name ~= "" then return info.name end
	local stamp = self:JournalData().stamps["zone:" .. tostring(zoneID)]
	return (stamp and stamp.name) or tostring(zoneID)
end

-- ---------------------------------------------------------------------------
-- Détail des parts : ce que chaque onglet liste
-- ---------------------------------------------------------------------------
-- Bestiaire : chaque espèce croisée, à abattre d'abord ; les nommés portent
-- leur rang (élite, rare…). La part « nommés » n'a pas de liste à elle : ses
-- espèces sont déjà là, on ne les montre pas deux fois.
local CLASS_LABEL = { elite = "BST_CLASS_elite", rare = "BST_CLASS_rare", rareelite = "BST_CLASS_rareelite", worldboss = "BST_CLASS_worldboss" }
FR.BST_CLASS_elite, FR.BST_CLASS_rare, FR.BST_CLASS_rareelite, FR.BST_CLASS_worldboss = "élite", "rare", "rare élite", "boss"
EN.BST_CLASS_elite, EN.BST_CLASS_rare, EN.BST_CLASS_rareelite, EN.BST_CLASS_worldboss = "elite", "rare", "rare elite", "boss"
ns.RegisterStrings({ BST_CLASS_elite = FR.BST_CLASS_elite, BST_CLASS_rare = FR.BST_CLASS_rare,
	BST_CLASS_rareelite = FR.BST_CLASS_rareelite, BST_CLASS_worldboss = FR.BST_CLASS_worldboss },
	{ BST_CLASS_elite = EN.BST_CLASS_elite, BST_CLASS_rare = EN.BST_CLASS_rare,
	BST_CLASS_rareelite = EN.BST_CLASS_rareelite, BST_CLASS_worldboss = EN.BST_CLASS_worldboss })

-- Zone préremplie (ZoneCreatures_<client>.lua) : aussi les espèces jamais croisées,
-- « à trouver », avec leur niveau ; vues : « à abattre » ; puis « abattu (n) ».
local function BestiaryItems(self, zoneID)
	local items = {}
	if not self.BestiarySpecies then return items end
	for _, species in pairs(self:BestiarySpecies(zoneID)) do
		local name = tostring(species.name or "?")
		local tag = CLASS_LABEL[species.class or ""]
		if tag then name = self:F("JRN_ITEM_NAMED", name, L[tag]) elseif species.type then name = self:F("JRN_ITEM_NAMED", name, species.type) end
		local level = self.BestiaryLevelText and self:BestiaryLevelText(species)
		if level then name = self:F("JRN_ITEM_LEVEL", name, level) end
		local killed = tonumber(species.killed) or 0
		local detail = L.JRN_ITEM_TO_FIND
		if killed > 0 then detail = self:F("JRN_ITEM_KILLED", killed) elseif species.seen then detail = L.JRN_ITEM_TO_KILL end
		local lvl = type(species.lvl) == "table" and tonumber(species.lvl[1]) or tonumber(species.level) or 0
		items[#items + 1] = { name = name, done = killed > 0, named = tag ~= nil, seen = species.seen == true,
			level = lvl, detail = detail }
	end
	table.sort(items, function(a, b)
		if a.done ~= b.done then return not a.done end
		if a.named ~= b.named then return a.named end
		if a.level ~= b.level then return a.level < b.level end
		return a.name < b.name
	end)
	return items
end

-- Récolte : les ressources de ta tranche, récoltées ou non dans cette zone
local function GatheringItems(self, zoneID)
	local items = {}
	if not (self.GatheringZoneBand and self.GatheringData) then return items end
	local data = self:GatheringData()
	-- zone préremplie (ZoneGathering_<client>.lua) : seulement ce qui y pousse
	for _, entry in ipairs((self:GatheringZoneBand(zoneID))) do
		local record = data[entry.itemID]
		local done = record and type(record.zones) == "table" and (tonumber(record.zones[zoneID]) or 0) > 0
		items[#items + 1] = { name = entry.name, done = done == true, req = entry.req,
			detail = done and L.JRN_ITEM_GATHERED or self:F("JRN_ITEM_TO_GATHER", entry.req) }
	end
	table.sort(items, function(a, b)
		if a.done ~= b.done then return not a.done end
		if a.req ~= b.req then return a.req < b.req end
		return a.name < b.name
	end)
	return items
end

local ITEMS = { bestiary = BestiaryItems, gathering = GatheringItems }

local function PartTab(def) return def.tab or PART_TAB[def.id] end

local function PartItems(self, def, zoneID)
	local fn = def.Items or ITEMS[def.id]
	if type(fn) ~= "function" then return {} end
	local ok, items = pcall(fn, self, zoneID)
	if ok and type(items) == "table" then return items end
	return {}
end

-- Lignes d'un onglet : pour chaque part de cet onglet, un titre « Villages :
-- 1/3 », puis ses éléments
function ns:JournalActivityRows(zoneID, activity)
	local rows = {}
	if not zoneID then return rows end
	for _, def in ipairs(ns.ZONE_PARTS or {}) do
		if PartTab(def) == activity then
			local ok, part = pcall(def.Compute, self, zoneID)
			if ok and type(part) == "table" and tonumber(part.need) and part.need > 0 then
				rows[#rows + 1] = { header = true, name = self:F("JRN_PART_HEAD", L[def.label] or def.label or def.id,
					math.min(tonumber(part.have) or 0, part.need), part.need), ratio = (tonumber(part.have) or 0) / part.need }
				for _, item in ipairs(PartItems(self, def, zoneID)) do rows[#rows + 1] = item end
			end
		end
	end
	return rows
end

-- Zones connues : celle où tu es, puis toutes celles du carnet (tampon,
-- bestiaire, récolte, coffre), par nom
function ns:JournalKnownZones()
	local seen, list = {}, {}
	local here = self.JournalZone and self:JournalZone()
	local function Add(zoneID)
		zoneID = tonumber(zoneID)
		if not zoneID or seen[zoneID] then return end
		seen[zoneID] = true
		list[#list + 1] = { id = zoneID, name = ZoneName(self, zoneID), here = zoneID == here }
	end
	if here then Add(here) end
	for id, stamp in pairs(self:JournalData().stamps) do
		if stamp.kind == "zone" then Add(id:match("^zone:(%d+)$")) end
	end
	if self.BestiaryData then for zoneID in pairs(self:BestiaryData()) do Add(zoneID) end end
	if self.GatheringData then
		for _, record in pairs(self:GatheringData()) do
			if type(record) == "table" and type(record.zones) == "table" then
				for zoneID in pairs(record.zones) do Add(zoneID) end
			end
		end
	end
	if self.ChestData then for zoneID in pairs(self:ChestData()) do Add(zoneID) end end
	table.sort(list, function(a, b)
		if a.here ~= b.here then return a.here end
		return a.name < b.name
	end)
	return list
end

-- ---------------------------------------------------------------------------
-- Fenêtre
-- ---------------------------------------------------------------------------
local function TabColor(button, selected)
	if button.text and button.text.SetTextColor then
		local c = selected and Theme.GOLD or { 0.81, 0.78, 0.72 }
		button.text:SetTextColor(c[1], c[2], c[3])
	end
	button.selected = selected
end

local function Text(parent, font, x, y, width)
	local text = parent:CreateFontString(nil, "OVERLAY", font or Theme.F_BODY)
	text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if width then text:SetWidth(width) end
	text:SetJustifyH("LEFT")
	return text
end

local function BuildCompletion(self, frame, top)
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetAllPoints()
	frame.comp = pane

	-- liste déroulante : un bouton, et la liste qui s'ouvre dessous
	pane.zoneButton = Theme.CreateButton(pane, 300, 22, "", function() ns:ToggleJournalZoneList() end)
	pane.zoneButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 34)
	-- suivre la zone dans le bloc « Carnet » en jeu
	pane.watch = Theme.CreateToggle(pane, 30, 14, "Button")
	pane.watch:SetPoint("TOPLEFT", frame, "TOPLEFT", 326, top - 38)
	pane.watch:SetScript("OnClick", function()
		if frame.zoneID then ns:JournalSetWatched(frame.zoneID, not ns:JournalIsWatched(frame.zoneID)) end
	end)
	pane.watchLabel = Text(pane, Theme.F_BODY, 362, top - 38)
	pane.watchLabel:SetText(L.JRN_WATCH)
	local function WatchTip(owner)
		local tip = rawget(_G, "GameTooltip")
		if type(tip) ~= "table" then return end
		pcall(tip.SetOwner, tip, owner, "ANCHOR_BOTTOM")
		if tip.ClearLines then tip:ClearLines() end
		tip:AddLine(L.JRN_WATCH, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
		tip:AddLine(L.JRN_WATCH_TIP, 1, 1, 1, true)
		tip:Show()
	end
	pane.watch:SetScript("OnEnter", WatchTip)
	pane.watch:SetScript("OnLeave", function() local tip = rawget(_G, "GameTooltip"); if tip then tip:Hide() end end)
	pane.percent = Theme.CreateTitle(pane, 17)
	pane.percent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, top - 34)
	pane.percent:SetJustifyH("RIGHT")
	pane.bar = Theme.CreateBar(pane, WIDTH - 28, 4)
	pane.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 62)
	pane.chest = Text(pane, Theme.F_BODY, 14, top - 72, WIDTH - 180)
	pane.openChest = Theme.CreateButton(pane, 130, 20, L.JRN_OPEN_CHEST, function()
		if frame.zoneID then ns:OpenChest(frame.zoneID) end
	end, "primary")
	pane.openChest:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, top - 68)

	pane.tabs = {}
	local tabW = math.floor((WIDTH - 28 - (#ACTIVITIES - 1) * 4) / #ACTIVITIES)
	for index, activity in ipairs(ACTIVITIES) do
		local tab = Theme.CreateButton(pane, tabW, 20, L["JRN_ACT_" .. activity], function() ns:SelectJournalActivity(activity) end)
		tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (index - 1) * (tabW + 4), top - 96)
		tab.activity = activity
		pane.tabs[activity] = tab
		if activity == "quests" and tab.HookScript then
			-- l'onglet dit ce qu'il compte, ou qu'il n'a pas de liste pour ce client
			tab:HookScript("OnEnter", function(owner)
				local tip = rawget(_G, "GameTooltip")
				if type(tip) ~= "table" then return end
				pcall(tip.SetOwner, tip, owner, "ANCHOR_BOTTOM")
				if tip.ClearLines then tip:ClearLines() end
				tip:AddLine(L.JRN_ACT_quests, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
				local available = ns.ZoneQuestsAvailable and ns:ZoneQuestsAvailable()
				tip:AddLine(available and L.JRN_QUESTS_TIP or L.JRN_ACT_NO_QUESTS, 1, 1, 1, true)
				tip:Show()
			end)
			tab:HookScript("OnLeave", function() local tip = rawget(_G, "GameTooltip"); if tip then tip:Hide() end end)
		end
	end
	pane.divider = Theme.CreateDivider(pane, WIDTH - 28, top - 122)

	pane.lines = {}
	local listTop = top - 130
	for index = 1, LINES do
		local row = CreateFrame("Frame", nil, pane)
		row:SetSize(WIDTH - 28, LINE_H - 2)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, listTop - (index - 1) * LINE_H)
		row.stamp = Theme.CreateDiamond(row, 10, false)
		row.stamp:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.name = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.name:SetPoint("LEFT", row, "LEFT", 22, 0)
		row.name:SetWidth(340)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.detail = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.detail:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.detail:SetWidth(150)
		row.detail:SetJustifyH("RIGHT")
		row.detail:SetWordWrap(false)
		row:Hide()
		pane.lines[index] = row
	end
	local bottom = listTop - LINES * LINE_H
	pane.empty = Text(pane, Theme.F_BODY, 16, listTop - 4, WIDTH - 32)
	pane.empty:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	pane.position = Text(pane, Theme.F_SMALL, 16, bottom - 6)
	pane.position:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	pane.up = Theme.CreateButton(pane, 22, 17, "^", function() ns:ScrollJournal(1) end)
	pane.up:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, bottom - 4)
	pane.down = Theme.CreateButton(pane, 22, 17, "v", function() ns:ScrollJournal(-1) end)
	pane.down:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, bottom - 4)

	-- la liste des zones, par-dessus le reste
	local list = CreateFrame("Frame", nil, frame)
	list:SetSize(300, 4 + ZONE_LIST_MAX * 20)
	list:SetPoint("TOPLEFT", pane.zoneButton, "BOTTOMLEFT", 0, -2)
	if list.SetFrameLevel and frame.GetFrameLevel then list:SetFrameLevel((frame:GetFrameLevel() or 1) + 20) end
	list.bg = list:CreateTexture(nil, "BACKGROUND")
	list.bg:SetTexture(Theme.SOLID)
	list.bg:SetVertexColor(0.06, 0.07, 0.085, 0.98)
	list.bg:SetAllPoints()
	list.buttons = {}
	for index = 1, ZONE_LIST_MAX do
		local button = Theme.CreateButton(list, 296, 19, "", function(b) ns:SelectJournalZone(b.zoneID) end)
		button:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -2 - (index - 1) * 20)
		button:Hide()
		list.buttons[index] = button
	end
	if list.EnableMouseWheel then list:EnableMouseWheel(true) end
	list:SetScript("OnMouseWheel", function(_, delta)
		list.offset = (list.offset or 0) - delta
		ns:RefreshJournalZoneList()
	end)
	list:Hide()
	pane.zoneList = list
end

local function BuildEvolution(self, frame, top)
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetAllPoints()
	frame.evo = pane
	local width = WIDTH - 28
	pane.stage = Theme.CreateTitle(pane, 17)
	pane.stage:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 36)
	pane.next = Text(pane, Theme.F_NORMAL, 14, top - 62, width)
	pane.next:SetWordWrap(true)
	pane.needsTitle = Text(pane, Theme.F_SMALL, 14, top - 88, width)
	pane.needsTitle:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	pane.needs = {}
	for index, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		local y = top - 106 - (index - 1) * 18
		local row = { key = key }
		row.label = Text(pane, Theme.F_BODY, 14, y, 110)
		row.bar = Theme.CreateBar(pane, 300, 5)
		row.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 130, y - 5)
		row.value = Text(pane, Theme.F_BODY, 440, y, 80)
		pane.needs[index] = row
	end
	pane.howTitle = Text(pane, Theme.F_SMALL, 14, top - 186, width)
	pane.howTitle:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	pane.how = {}
	for index = 1, 3 do
		local line = Text(pane, Theme.F_BODY, 14, top - 204 - (index - 1) * 30, width)
		line:SetWordWrap(true)
		pane.how[index] = line
	end
	pane.divider = Theme.CreateDivider(pane, width, top - 296)
	pane.chests = Text(pane, Theme.F_NORMAL, 14, top - 306, width - 150)
	pane.openChest = Theme.CreateButton(pane, 130, 20, L.JRN_OPEN_CHEST, function() ns:OpenChest() end, "primary")
	pane.openChest:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, top - 302)
	pane.collection = Text(pane, Theme.F_BODY, 14, top - 332, width)
	pane.road = Text(pane, Theme.F_BODY, 14, top - 354, width)
	pane.road:SetWordWrap(true)
end

function ns:EnsureJournalWindow()
	if self.journalFrame then return self.journalFrame end
	if not Theme or not Theme.CreatePanel then return nil end
	local frame = Theme.CreatePanel(UIParent, WIDTH, HEIGHT, L.JRN_TITLE, { name = "Ready2QuestJournalFrame" })
	if not frame then return nil end
	if self.RestorePoint then self:RestorePoint(frame, "journalPoint", { point = "CENTER", x = 0, y = 40 }) end
	frame.kind, frame.activity, frame.offset = "completion", "explore", 0
	local top = frame.contentTop - 8

	frame.sections = {}
	for index, section in ipairs({ "completion", "evolution" }) do
		local button = Theme.CreateButton(frame, 130, 22, L["JRN_SEC_" .. section], function() ns:SelectJournalKind(section) end)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (index - 1) * 136, top)
		frame.sections[section] = button
	end

	BuildCompletion(self, frame, top)
	BuildEvolution(self, frame, top)

	if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
	frame:SetScript("OnMouseWheel", function(_, delta) ns:ScrollJournal(delta) end)
	frame.closeButton = Theme.CreateButton(frame, 90, 20, L.OPT_CLOSE, function() frame:Hide() end, "primary")
	frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 10)
	frame:Hide()
	self.journalFrame = frame
	return frame
end

-- « goals » / « evolution » : Évolution ; tout le reste : Complétion
-- (« completion », ou un ancien nom d'onglet)
function ns:SelectJournalKind(kind)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.kind = (kind == "evolution" or kind == "goals") and "evolution" or "completion"
	frame.offset = 0
	self:RefreshJournal()
end

function ns:SelectJournalZone(zoneID)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.zoneID, frame.offset, frame.zonePicked = tonumber(zoneID), 0, true
	frame.comp.zoneList:Hide()
	self:RefreshJournal()
end

function ns:SelectJournalActivity(activity)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.activity, frame.offset = activity, 0
	self:RefreshJournal()
end

function ns:ScrollJournal(delta)
	local frame = self.journalFrame
	if not frame then return end
	frame.offset = (frame.offset or 0) - (tonumber(delta) or 0)
	self:RefreshJournal()
end

function ns:ToggleJournalZoneList()
	local frame = self.journalFrame
	if not frame then return end
	local list = frame.comp.zoneList
	if list:IsShown() then list:Hide(); return end
	list.offset = 0
	self:RefreshJournalZoneList()
	list:Show()
end

function ns:RefreshJournalZoneList()
	local frame = self.journalFrame
	if not frame then return end
	local list = frame.comp.zoneList
	local zones = self:JournalKnownZones()
	list.offset = math.max(0, math.min(list.offset or 0, #zones - ZONE_LIST_MAX))
	local shown = 0
	for index, button in ipairs(list.buttons) do
		local zone = zones[index + list.offset]
		if zone then
			local done = self.ZoneCompletion and self:ZoneCompletion(zone.id)
			local label = zone.here and self:F("JRN_ZONE_HERE", zone.name) or zone.name
			if done and #done.parts >= 2 then label = label .. "  " .. self:F("JRN_ZONE_PERCENT", done.percent) end
			button.zoneID = zone.id
			button:SetText(label)
			button:Show()
			shown = shown + 1
		else
			button.zoneID = nil
			button:Hide()
		end
	end
	list:SetHeight(4 + math.max(1, shown) * 20)
	list.zones = zones
end

local function RefreshCompletion(self, frame)
	local pane = frame.comp
	-- par défaut la zone où tu es ; un choix dans la liste tient jusqu'à fermeture
	if not frame.zonePicked or not frame.zoneID then
		frame.zoneID = self.JournalZone and self:JournalZone() or nil
		if not frame.zoneID then
			local first = self:JournalKnownZones()[1]
			frame.zoneID = first and first.id or nil
		end
	end
	local zoneID = frame.zoneID
	local here = self.JournalZone and self:JournalZone()
	if not zoneID then
		pane.zoneButton:SetText(self:F("JRN_ZONE_PICK", "-"))
		pane.watch:Hide(); pane.watchLabel:Hide()
		pane.percent:SetText("")
		pane.bar:Hide()
		pane.chest:SetText("")
		pane.openChest:Hide()
		for _, row in ipairs(pane.lines) do row:Hide() end
		pane.empty:SetText(L.JRN_ZONE_NONE)
		pane.position:SetText("")
		pane.up:Hide(); pane.down:Hide()
		frame.rows = {}
		return
	end
	local name = ZoneName(self, zoneID)
	pane.zoneButton:SetText(self:F("JRN_ZONE_PICK", zoneID == here and self:F("JRN_ZONE_HERE", name) or name) .. "  v")

	local done = self.ZoneCompletion and self:ZoneCompletion(zoneID)
	if done and #done.parts >= 2 then
		pane.percent:SetText(self:F("JRN_ZONE_PERCENT", done.percent))
		pane.bar:SetValue(done.ratio)
		pane.bar:Show()
	else
		pane.percent:SetText("")
		pane.bar:Hide()
	end
	local chest = self.ChestData and self:ChestData()[zoneID]
	pane.openChest:Hide()
	if chest and chest.golden then
		pane.chest:SetText(self:F("JRN_CHEST_GOLDEN", chest.tier or 1))
	elseif chest and chest.opened then
		local reward = chest.reward and chest.reward:match("^%w+:(.+)$")
		local label = reward
		for _, entry in ipairs(self.ChestRewards and self:ChestRewards() or {}) do
			if chest.reward == entry.kind .. ":" .. entry.id then label = self:ChestRewardLabel(entry) end
		end
		pane.chest:SetText(self:F("JRN_CHEST_OPENED", tostring(label or "?")))
	elseif chest then
		pane.chest:SetText(L.JRN_CHEST_READY)
		pane.openChest:Show()
	elseif done and #done.parts >= 2 then
		pane.chest:SetText(self:F("JRN_CHEST_TODO", self.ZoneTier and self:ZoneTier(zoneID) or 1))
	else
		pane.chest:SetText(L.JRN_ZONE_NOPCT)
	end

	pane.watch:SetChecked(self:JournalIsWatched(zoneID))
	pane.watch:Show(); pane.watchLabel:Show()
	local activity = frame.activity or "explore"
	for key, tab in pairs(pane.tabs) do TabColor(tab, key == activity) end
	-- Quêtes : grisé si ce client n'a pas de liste de quêtes
	local quests = self.ZoneQuestsAvailable and self:ZoneQuestsAvailable()
	local questsTab = pane.tabs.quests
	questsTab:SetText(L.JRN_ACT_quests)
	if not quests and activity ~= "quests" and questsTab.text.SetTextColor then
		questsTab.text:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	end
	local rows = self:JournalActivityRows(zoneID, activity)
	frame.rows = rows
	local maxOffset = math.max(0, #rows - LINES)
	frame.offset = math.max(0, math.min(frame.offset or 0, maxOffset))
	for index, row in ipairs(pane.lines) do
		local item = rows[index + frame.offset]
		row.item = item
		if item and item.header then
			row.stamp:Hide()
			row.name:SetText(item.name)
			row.name:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
			row.detail:SetText("")
			row:Show()
		elseif item then
			row.stamp:Show()
			row.stamp:SetTexture(item.done and Theme.DIAMOND or Theme.DIAMOND_LINE)
			local c = item.done and Theme.GOLD or Theme.MUTED
			row.stamp:SetVertexColor(c[1], c[2], c[3], 1)
			local t = item.done and Theme.PARCHMENT or Theme.TEXT
			row.name:SetTextColor(t[1], t[2], t[3])
			row.name:SetText(item.name)
			row.detail:SetText(Theme.T_GREY .. tostring(item.detail or "") .. "|r")
			row:Show()
		else
			row:Hide()
		end
	end
	local empty = ""
	if #rows == 0 then
		if activity == "quests" and not (self.ZoneQuestsAvailable and self:ZoneQuestsAvailable()) then
			empty = L.JRN_ACT_NO_QUESTS
		else
			empty = L["JRN_ACT_EMPTY_" .. activity] or ""
		end
	end
	pane.empty:SetText(empty)
	pane.position:SetText(#rows > LINES
		and string.format("%d-%d / %d", frame.offset + 1, math.min(#rows, frame.offset + LINES), #rows) or "")
	if frame.offset > 0 then pane.up:Show() else pane.up:Hide() end
	if frame.offset < maxOffset then pane.down:Show() else pane.down:Hide() end
end

local function CollectionCounts(self)
	local total, owned, byTier = 0, 0, { { 0, 0 }, { 0, 0 }, { 0, 0 } }
	local unlocked = self.CompanionData and self:CompanionData().unlocked or {}
	for _, reward in ipairs(self.ChestRewards and self:ChestRewards() or {}) do
		local tier = byTier[tonumber(reward.tier) or 0]
		if tier then
			local has = unlocked[reward.kind .. ":" .. reward.id] == true
			total, tier[2] = total + 1, tier[2] + 1
			if has then owned, tier[1] = owned + 1, tier[1] + 1 end
		end
	end
	return owned, total, byTier
end

local function RefreshEvolution(self, frame)
	local pane = frame.evo
	local stages = ns.COMPANION_STAGES or {}
	local data = self.CompanionData and self:CompanionData() or { needs = {} }
	local stage = self.CompanionStage and self:CompanionStage() or 1
	local name = self.CompanionName and self:CompanionName() or "?"
	pane.stage:SetText(self:F("JRN_EVO_STAGE", name, self.CompanionStageLabel and self:CompanionStageLabel(stage) or "",
		stage, #stages))
	local unitLevel = rawget(_G, "UnitLevel")
	local ok, rawLevel = pcall(unitLevel or function() return 1 end, "player")
	local level = tonumber(ok and rawLevel) or 1
	local nextStage = stages[stage + 1]
	if data.stageReady and stages[data.stageReady] then
		pane.next:SetText(self:F("JRN_EVO_NEXT_READY", L[stages[data.stageReady].label]))
		pane.next:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	elseif nextStage then
		pane.next:SetText(self:F("JRN_EVO_NEXT_LEVEL", L[nextStage.label], nextStage.level, level))
		pane.next:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
	else
		pane.next:SetText(L.JRN_EVO_MAX)
		pane.next:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	end
	local happyMin = ns.COMPANION_HAPPY_MIN or 70
	pane.needsTitle:SetText(self:F("JRN_EVO_NEEDS", happyMin))
	for _, row in ipairs(pane.needs) do
		local value = math.floor(tonumber(data.needs and data.needs[row.key]) or 0)
		row.label:SetText(L["COMP_NEED_" .. row.key] or row.key)
		row.bar:SetValue(value / 100)
		local c = value >= happyMin and Theme.GOLD or Theme.MUTED
		row.bar:SetColor(c[1], c[2], c[3], 1)
		row.value:SetText(value .. " %")
	end
	pane.howTitle:SetText(L.JRN_EVO_HOW)
	pane.how[1]:SetText(L.JRN_EVO_HOW_1)
	pane.how[2]:SetText(self:F("JRN_EVO_HOW_2", happyMin))
	pane.how[3]:SetText(self:F("JRN_EVO_HOW_3"))

	local pending = self.ChestPending and #self:ChestPending() or 0
	pane.chests:SetText(self:F("JRN_EVO_CHESTS", pending))
	if pending > 0 then pane.openChest:Show() else pane.openChest:Hide() end
	local owned, total, byTier = CollectionCounts(self)
	pane.collection:SetText(self:F("JRN_EVO_COLLECTION", owned, total, byTier[1][1], byTier[1][2],
		byTier[2][1], byTier[2][2], byTier[3][1], byTier[3][2]))
	local counts = self:JournalCounts()
	local capitals = self.JournalTotal and self:JournalTotal("capital") or counts.capital
	local milestones = #(ns.JOURNAL_MILESTONES or { 10, 20, 30, 40, 50, 60 })
	pane.road:SetText(self:F("JRN_EVO_ROAD", counts.zone or 0, counts.capital or 0, capitals or 0,
		counts.dungeon or 0, counts.rare or 0, counts.level or 0, milestones))
end

function ns:RefreshJournal()
	local frame = self.journalFrame
	if not frame then return end
	local section = frame.kind == "evolution" and "evolution" or "completion"
	frame.kind = section
	for key, button in pairs(frame.sections) do TabColor(button, key == section) end
	local counts = self:JournalCounts()
	if frame.subtitle then
		frame.subtitle:SetText(self:F("JRN_TOTAL", counts.total)
			.. (ModuleOn() and "" or ("  " .. Theme.T_GREY .. L.MODULE_OFF .. "|r")))
	end
	if section == "evolution" then
		frame.comp:Hide()
		frame.comp.zoneList:Hide()
		frame.evo:Show()
		RefreshEvolution(self, frame)
	else
		frame.evo:Hide()
		frame.comp:Show()
		RefreshCompletion(self, frame)
	end
end

-- à la fermeture, la zone revient à « ici » à la prochaine ouverture
do
	local previous = ns.ToggleJournal
	function ns:ToggleJournal(forceShow)
		local frame = self.journalFrame
		local opening = not (frame and frame:IsShown()) or forceShow
		if opening and frame then frame.zonePicked = nil; frame.offset = 0 end
		return previous(self, forceShow)
	end
end

-- une seule grande fenêtre à la fois (socle commun, ns:CloseOtherWindows)
if type(ns.EXCLUSIVE_WINDOWS) == "table" then table.insert(ns.EXCLUSIVE_WINDOWS, "journalFrame") end

if ns.Mark then ns.Mark("JournalWindow") end
