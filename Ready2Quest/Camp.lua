-- Camp.lua -- module « Kit de camp » (WoW Forever uniquement)
--
-- Forever ajoute le campement : la Cuisine fabrique un feu de camp (kits
-- Basique / Compagnon / Expert), chaque joueur autour y pose UN objet de son
-- métier (Meule à aiguiser du forgeron, Tente du travailleur du cuir…), avec
-- une recharge d'une heure partagée entre tous les objets de camp. Les buffs
-- (une heure) tombent après environ une minute assis ou à fabriquer au camp.
--
-- Le module :
--   1. ajoute deux contrôles au Check avant le départ (kit, objet de camp) ;
--   2. au camp, affiche un petit compte à rebours jusqu'aux buffs ;
--   3. en quittant le camp, écrit dans le chat le temps de buffs restant.
--
-- Tout le module vit dans ce fichier (API d'extension, voir Core.lua).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

-- ---------------------------------------------------------------------------
-- Données du client
-- Source : wago.tools, produit `wowf`, build 1.60.1.70753, tables ItemSparse
-- (RequiredSkill / RequiredSkillRank), ItemXItemEffect + ItemEffect (sort lancé,
-- SpellCategoryID, CategoryCoolDownMSec), SpellMisc + SpellDuration (durées),
-- SpellEffect (déclenchements). Relevé le 2026-11-03. Les noms anglais ne
-- servent que de repli si le client n'a pas encore l'objet en cache.
-- ---------------------------------------------------------------------------

-- Kits de feu de camp : Cuisine (185). Catégorie de sort 2511, recharge 5 min.
local CAMP_KITS = {
	{ item = 279981, skill = 185, rank = 1,   name = "Basic Campfire Kit" },        -- sort 1307227
	{ item = 279961, skill = 185, rank = 140, name = "Journeyman Campfire Kit" },   -- sort 1307252
	{ item = 279974, skill = 185, rank = 220, name = "Expert Campfire Kit" },       -- sort 1307237
}

-- Objets de camp : catégorie de sort 97, recharge de catégorie 3 600 000 ms,
-- c'est-à-dire UNE recharge d'une heure partagée par tous ces objets. Trois
-- paliers par métier (compétence 20 / 140 / 300).
local CAMP_OBJECTS = {
	{ item = 279944, skill = 164, rank = 20,  name = "Sharpening Wheel" },
	{ item = 279988, skill = 164, rank = 140, name = "Anvil" },
	{ item = 279955, skill = 164, rank = 300, name = "Master Forge" },
	{ item = 279978, skill = 165, rank = 20,  name = "Camp Tent" },
	{ item = 279941, skill = 165, rank = 140, name = "Tanning Rack" },
	{ item = 279945, skill = 165, rank = 300, name = "Sewing Machine" },
	{ item = 279972, skill = 197, rank = 20,  name = "Faction Banner" },   -- deux versions (une par faction)
	{ item = 279973, skill = 197, rank = 20,  name = "Faction Banner" },
	{ item = 279943, skill = 197, rank = 140, name = "Spinning Wheel" },
	{ item = 279959, skill = 197, rank = 300, name = "Loom" },
	{ item = 279962, skill = 182, rank = 20,  name = "Incense Candle" },
	{ item = 279964, skill = 182, rank = 140, name = "Greenhouse" },
	{ item = 279947, skill = 182, rank = 300, name = "Seed Hybridizer" },
	{ item = 279979, skill = 393, rank = 20,  name = "Camp Chair" },
	{ item = 279969, skill = 393, rank = 140, name = "Field Guide" },
	{ item = 279938, skill = 393, rank = 300, name = "Trapper's Workbench" },
	{ item = 279960, skill = 186, rank = 20,  name = "Lodestone" },
	{ item = 279948, skill = 186, rank = 140, name = "Rock Garden" },
	{ item = 279952, skill = 186, rank = 300, name = "Molten Foundry" },
	{ item = 279950, skill = 202, rank = 20,  name = "Reagent Bot" },
	{ item = 279949, skill = 202, rank = 140, name = "Repair Bot" },
	{ item = 279989, skill = 202, rank = 300, name = "Anarchist's Workbench" },
	{ item = 279956, skill = 171, rank = 20,  name = "Mana Well" },
	{ item = 279970, skill = 171, rank = 140, name = "Fermenter" },
	{ item = 279990, skill = 171, rank = 300, name = "Alchemy Laboratory" },
	{ item = 279976, skill = 333, rank = 20,  name = "Enchanted Lute" },
	{ item = 279985, skill = 333, rank = 140, name = "Arcane Salvager" },
	{ item = 279987, skill = 333, rank = 300, name = "Arcane Forge" },
	{ item = 279968, skill = 129, rank = 20,  name = "First Aid Kit" },
	{ item = 279940, skill = 129, rank = 140, name = "Toxin Study" },
	{ item = 279951, skill = 129, rank = 300, name = "Plague Doctor's Laboratory" },
	{ item = 279967, skill = 356, rank = 20,  name = "Fish Bowl" },
	{ item = 279965, skill = 356, rank = 140, name = "Fishing Rack" },
	{ item = 279966, skill = 356, rank = 300, name = "Fishing Hut" },
	{ item = 279957, skill = 185, rank = 140, name = "Cookie's Feast" },
	{ item = 279982, skill = 185, rank = 300, name = "Iron Oven" },
}

-- Le client Forever donne les métiers par leur NOM dans la fenêtre
-- de compétences, sans numéro : on reconnaît les deux langues de l'addon.
local SKILL_BY_NAME = {
	["cooking"] = 185, ["cuisine"] = 185,
	["blacksmithing"] = 164, ["forge"] = 164,
	["leatherworking"] = 165, ["travail du cuir"] = 165,
	["tailoring"] = 197, ["couture"] = 197,
	["herbalism"] = 182, ["herboristerie"] = 182,
	["skinning"] = 393, ["dépeçage"] = 393,
	["mining"] = 186, ["minage"] = 186,
	["engineering"] = 202, ["ingénierie"] = 202,
	["alchemy"] = 171, ["alchimie"] = 171,
	["enchanting"] = 333, ["enchantement"] = 333,
	["first aid"] = 129, ["secourisme"] = 129,
	["fishing"] = 356, ["pêche"] = 356,
}

-- Seuil d'une minute : « Welcoming Campfire » (1229739 / 1289723) dure 60 s et
-- déclenche « Camp Benefits » (1229741, 1 h) à son unique tic (SpellEffect :
-- aura 226, période 60 000 ms, EffectTriggerSpell 1229741).
local WELCOME_AURAS = { 1229739, 1289723 }
local THRESHOLD = 60

-- Buffs donnés par le camp (une heure chacun, SpellDuration 3 600 000 ms).
-- « Boosted … » sont les buffs des objets de métier (Boosted Attack Power =
-- Meule à aiguiser, Boosted Spirit = Bannière, Boosted Intellect = Bougie…).
-- Non vérifié en jeu : la correspondance objet -> buff exacte ; la liste
-- vient des sorts d'une heure nommés comme ceux du campement.
local CAMP_BUFFS = {
	1229741,   -- Camp Benefits
	1229451,   -- Boosted Rest (Tente : repos)
	1229513,   -- Boosted Intellect
	1229519,   -- Boosted Critical Chance (Chaise de camp)
	1229718,   -- Boosted Spirit
	1230098,   -- Boosted Stats
	1230124,   -- Boosted Stamina
	1230164,   -- Boosted Attack Power
	1230172,   -- Extra Strength
	1230552,   -- Boosted Spell Power
	1230587,   -- Boosted Mana Regeneration
	1230653,   -- Boosted Stats
	1308027,   -- Camping
	1325147,   -- Adventurer's Tent
	1325299,   -- [DNT] Boosted Rest
}

ns.CAMP_DATA = { kits = CAMP_KITS, objects = CAMP_OBJECTS, buffs = CAMP_BUFFS, welcome = WELCOME_AURAS }

-- Les buffs du camp durent une heure et disparaissent ensuite : sans ça,
-- l'apprentissage des buffs (Buffs.lua) les retiendrait et les réclamerait à
-- chaque départ. ns.IGNORED_BUFF_SPELLS est la table même que lit Buffs.lua.
if type(ns.IGNORED_BUFF_SPELLS) == "table" then
	for _, spellID in ipairs(CAMP_BUFFS) do ns.IGNORED_BUFF_SPELLS[spellID] = true end
	for _, spellID in ipairs(WELCOME_AURAS) do ns.IGNORED_BUFF_SPELLS[spellID] = true end
end

-- ---------------------------------------------------------------------------
-- Chaînes (tutoiement, courtes)
-- ---------------------------------------------------------------------------
local STRINGS_FR = {
	OPT_PAGE_CAMP = "Kit de camp",
	OPT_PAGE_CAMP_SUB = "Feu de camp et objets de métier (Forever) : avant le départ, au camp, en partant.",
	OPT_CAMP_COUNTDOWN = "Compte à rebours au camp",
	OPT_CAMP_DEPARTLINE = "Buffs restants en quittant le camp",
	CHK_CAMPKIT = "Kit de feu de camp",
	CHK_CAMPKIT_DETAIL = "%d dans tes sacs",
	CHK_CAMPKIT_NONE = "aucun dans tes sacs",
	ADV_CAMPKIT = "Prends un kit de feu de camp : une heure de buffs en route.",
	CHK_CAMPOBJ = "Objet de camp",
	CHK_CAMPOBJ_READY = "%s, prêt",
	CHK_CAMPOBJ_CD = "%s, encore %d min",
	CHK_CAMPOBJ_NONE = "aucun dans tes sacs",
	ADV_CAMPOBJ = "Ton objet de camp n'est pas prêt : à fabriquer, ou en recharge.",
	CAMP_TIMER = "Au camp : buffs dans %s",
	CAMP_TIMER_EST = "Au camp : buffs dans ~%s",
	CAMP_TIMER_HINT = "Buffs du feu de camp : assieds-toi ou fabrique ici",
	CAMP_TIMER_ACTIVE = "Buffs du camp actifs",
	CAMP_DEPART_BUFFS = "Buffs du camp : encore %d min.",
}
local STRINGS_EN = {
	OPT_PAGE_CAMP = "Camp kit",
	OPT_PAGE_CAMP_SUB = "Campfire and profession camp objects (Forever): before leaving, at camp, on the way out.",
	OPT_CAMP_COUNTDOWN = "Countdown at camp",
	OPT_CAMP_DEPARTLINE = "Buff time left when leaving camp",
	CHK_CAMPKIT = "Campfire kit",
	CHK_CAMPKIT_DETAIL = "%d in your bags",
	CHK_CAMPKIT_NONE = "none in your bags",
	ADV_CAMPKIT = "Pack a campfire kit: an hour of buffs on the road.",
	CHK_CAMPOBJ = "Camp object",
	CHK_CAMPOBJ_READY = "%s, ready",
	CHK_CAMPOBJ_CD = "%s, %d min left",
	CHK_CAMPOBJ_NONE = "none in your bags",
	ADV_CAMPOBJ = "Your camp object isn't ready: craft one, or wait for its cooldown.",
	CAMP_TIMER = "At camp: buffs in %s",
	CAMP_TIMER_EST = "At camp: buffs in ~%s",
	CAMP_TIMER_HINT = "Campfire buffs: sit down or craft here",
	CAMP_TIMER_ACTIVE = "Camp buffs active",
	CAMP_DEPART_BUFFS = "Camp buffs: %d min left.",
}
if ns.KEEP_STRINGS then ns.CAMP_STRINGS = { fr = STRINGS_FR, en = STRINGS_EN } end
if ns.RegisterStrings then ns.RegisterStrings(STRINGS_FR, STRINGS_EN) end

if ns.RegisterDefaults then
	ns.RegisterDefaults({
		campEnabled       = true,   -- module « Kit de camp »
		campCountdown     = true,   -- compte à rebours au camp
		campDepartureLine = true,   -- ligne de chat en quittant le camp
		campPoint         = { point = "TOP", x = 0, y = -150 },
	})
end

-- ---------------------------------------------------------------------------
-- Lecture du client
-- ---------------------------------------------------------------------------
local function Now() return (ns.Now and ns.Now()) or 0 end

function ns:CampEnabled()
	local db = self:DB()
	return db.enabled ~= false and db.campEnabled ~= false
end

-- [skillID] = rang, d'après la fenêtre de compétences. Second retour : false
-- si l'API manque (on se rabat alors sur le contenu des sacs).
function ns:CampSkillRanks()
	local ranks = {}
	local count, info = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
	if type(count) ~= "function" or type(info) ~= "function" then return ranks, false end
	local ok, total = pcall(count)
	if not ok or type(total) ~= "number" then return ranks, false end
	for index = 1, total do
		local okLine, name, isHeader, _, rank = pcall(info, index)
		if okLine and type(name) == "string" and not (isHeader == true or isHeader == 1) then
			local skill = SKILL_BY_NAME[ns.AsciiLower(name)]
			if skill then ranks[skill] = tonumber(rank) or 0 end
		end
	end
	return ranks, true
end

local function ItemCount(itemID)
	if ns.ItemCount then return ns.ItemCount(itemID) or 0 end
	return 0
end

local function ItemName(entry)
	local name = ns.ItemInfo(entry.item)
	if type(name) == "string" and name ~= "" then return name end
	return entry.name
end

-- Secondes de recharge restantes d'un objet (0 = prêt). Le GCD (1,5 s) ne
-- compte pas comme une recharge.
local function ItemCooldown(itemID)
	local fn = (C_Container and C_Container.GetItemCooldown) or rawget(_G, "GetItemCooldown")
	if type(fn) ~= "function" then return 0 end
	local ok, start, duration = pcall(fn, itemID)
	if not ok or type(start) ~= "number" or type(duration) ~= "number" then return 0 end
	if start <= 0 or duration <= 1.5 then return 0 end
	local remaining = start + duration - Now()
	return remaining > 0 and remaining or 0
end

-- Aura du joueur par numéro de sort (défensif : valeurs « secrètes » sur
-- certains clients, d'où le pcall)
local function PlayerAura(spellID)
	if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then return nil end
	local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
	if ok and type(aura) == "table" then return aura end
	return nil
end

local function AuraRemaining(aura)
	local expiration = aura and tonumber(aura.expirationTime)
	if not expiration or expiration <= 0 then return nil end
	local remaining = expiration - Now()
	return remaining > 0 and remaining or nil
end

-- Buffs du camp sur le joueur : secondes restantes (le plus long) et nombre.
function ns:CampBuffRemaining()
	local best, count = 0, 0
	for _, spellID in ipairs(CAMP_BUFFS) do
		local aura = PlayerAura(spellID)
		if aura then
			count = count + 1
			local remaining = AuraRemaining(aura)
			if remaining and remaining > best then best = remaining end
		end
	end
	return best, count
end

-- ---------------------------------------------------------------------------
-- Ce que le joueur porte et peut utiliser
-- ---------------------------------------------------------------------------
function ns:CampKitStatus()
	local ranks, known = self:CampSkillRanks()
	local count, best = 0, nil
	for _, kit in ipairs(CAMP_KITS) do
		local have = ItemCount(kit.item)
		if have > 0 then
			count = count + have
			best = kit
		end
	end
	local cooking = known and (ranks[185] or 0) > 0
	return { count = count, best = best, cooking = cooking }
end

-- Objets de camp portés, et ceux que ses métiers permettent de fabriquer
function ns:CampObjectStatus()
	local ranks = self:CampSkillRanks()
	local carried, craftable = {}, {}
	for _, object in ipairs(CAMP_OBJECTS) do
		local have = ItemCount(object.item)
		if have > 0 then carried[#carried + 1] = { entry = object, count = have } end
		if (ranks[object.skill] or 0) >= object.rank then craftable[#craftable + 1] = object end
	end
	-- recharge partagée : n'importe quel objet de la catégorie la donne. On
	-- prend le plus long relevé, au cas où un client ne la renverrait que pour
	-- un objet en sac.
	local cooldown = 0
	for _, object in ipairs(CAMP_OBJECTS) do
		local remaining = ItemCooldown(object.item)
		if remaining > cooldown then cooldown = remaining end
	end
	return { carried = carried, craftable = craftable, cooldown = cooldown }
end

-- ---------------------------------------------------------------------------
-- Contrôles du Check avant le départ
-- ---------------------------------------------------------------------------
if ns.AddCheck then
	ns.AddCheck{
		id = "campkit",
		inactiveText = "MODULE_INACTIVE",
		-- seulement sur Forever, module allumé, et pour un cuisinier (ou
		-- quelqu'un qui en porte un) : les autres ne peuvent pas poser de feu
		active = function()
			if not ns:CampEnabled() then return false end
			local status = ns:CampKitStatus()
			return status.cooking or status.count > 0
		end,
		icon = "Interface\\Icons\\Spell_Fire_Fire",
		weight = 5,
		advice = "ADV_CAMPKIT",
		label = function() return L.CHK_CAMPKIT end,
		run = function()
			local status = ns:CampKitStatus()
			if status.count <= 0 then return false, L.CHK_CAMPKIT_NONE, 0 end
			return true, ns:F("CHK_CAMPKIT_DETAIL", status.count), 100
		end,
	}

	ns.AddCheck{
		id = "campobject",
		inactiveText = "MODULE_INACTIVE",
		-- seulement si un de tes métiers a un objet de camp (ou si tu en portes un)
		active = function()
			if not ns:CampEnabled() then return false end
			local status = ns:CampObjectStatus()
			return #status.carried > 0 or #status.craftable > 0
		end,
		icon = "Interface\\Icons\\INV_Misc_Gear_01",
		weight = 5,
		advice = "ADV_CAMPOBJ",
		label = function() return L.CHK_CAMPOBJ end,
		run = function()
			local status = ns:CampObjectStatus()
			local shown = status.carried[1] and status.carried[1].entry
			if not shown then return false, L.CHK_CAMPOBJ_NONE, 30 end
			if status.cooldown > 0 then
				return false, ns:F("CHK_CAMPOBJ_CD", ItemName(shown), math.ceil(status.cooldown / 60)), 50
			end
			return true, ns:F("CHK_CAMPOBJ_READY", ItemName(shown)), 100
		end,
	}
end

-- ---------------------------------------------------------------------------
-- En quittant le camp : temps de buffs restant
-- Une ligne de chat, au moment du DEPARTURE : elle passe quel que soit le mode
-- d'alerte (fenêtre, ligne discrète, Check avant le départ coupé), sans
-- toucher à UI.lua. Le dernier relevé reste dans ns.lastCampDeparture.
-- ---------------------------------------------------------------------------
function ns:OnCampDeparture(from)
	if not (type(from) == "table" and from.source == "camp") then return end
	if not self:CampEnabled() or self:DB().campDepartureLine == false then return end
	local remaining, count = self:CampBuffRemaining()
	if count <= 0 or remaining <= 0 then
		self.lastCampDeparture = nil
		return
	end
	local minutes = math.ceil(remaining / 60)
	self.lastCampDeparture = { remaining = remaining, count = count, at = Now() }
	self:Print(self:F("CAMP_DEPART_BUFFS", minutes))
end

if ns.RegisterCallback then
	ns:RegisterCallback("DEPARTURE", function(self, from) self:OnCampDeparture(from) end)
end

-- ---------------------------------------------------------------------------
-- Au camp : compte à rebours discret jusqu'aux buffs
-- ---------------------------------------------------------------------------
local function Clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

ns.CAMP_ICON = "Interface\\Icons\\Spell_Fire_Fire"

-- bandeau (Theme.CreateToast) : liseré ambre, le décompte au centre
function ns:EnsureCampFrame()
	if self.campFrame then return self.campFrame end
	if not (Theme and Theme.CreateToast) then return nil end
	local frame = Theme.CreateToast(UIParent, 300, 28)
	if not frame then return nil end
	frame.text = Theme.Text(frame, Theme.F_LABEL, Theme.LABEL)
	frame.text:SetPoint("CENTER", frame, "CENTER", Theme.TOAST_ACCENT / 2 + 11, 0)
	-- l'icône du feu de camp, à gauche du texte (1.29.6)
	if frame.CreateTexture then
		frame.icon = frame:CreateTexture(nil, "ARTWORK")
		frame.icon:SetTexture(ns.CAMP_ICON)
		frame.icon:SetSize(18, 18)
		frame.icon:SetPoint("RIGHT", frame.text, "LEFT", -5, 0)
		if frame.icon.SetTexCoord then frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	end
	if self.RestorePoint then self:RestorePoint(frame, "campPoint", { point = "TOP", x = 0, y = -150 }) end
	frame:Hide()
	self.campFrame = frame
	return frame
end

-- Texte du cadre, ou nil s'il doit être masqué
function ns:CampTimerText(now)
	now = now or Now()
	if not self:CampEnabled() or self:DB().campCountdown == false or not self:AtCamp() then
		self.campArrivedAt = nil
		return nil
	end
	self.campArrivedAt = self.campArrivedAt or now

	local _, buffs = self:CampBuffRemaining()
	if buffs > 0 then return Theme.T_GREEN .. L.CAMP_TIMER_ACTIVE .. "|r" end

	-- le décompte exact, quand le client pose l'aura d'accueil
	for _, spellID in ipairs(WELCOME_AURAS) do
		local remaining = AuraRemaining(PlayerAura(spellID))
		if remaining then return self:F("CAMP_TIMER", Clock(remaining)) end
	end
	-- sinon une estimation depuis l'arrivée au camp
	local left = THRESHOLD - (now - self.campArrivedAt)
	if left > 0 then return self:F("CAMP_TIMER_EST", Clock(left)) end
	return L.CAMP_TIMER_HINT
end

function ns:UpdateCampFrame(now)
	local text = self:CampTimerText(now)
	if not text then
		if self.campFrame then self.campFrame:Hide() end
		return
	end
	local frame = self:EnsureCampFrame()
	if not frame then return end
	frame.text:SetText(text)
	frame:Show()
end

-- ---------------------------------------------------------------------------
-- Interrupteur, réglages, /r2q module camp
-- ---------------------------------------------------------------------------
if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "camp", title = "OPT_PAGE_CAMP", group = "OPT_GROUP_MODULES", power = "campEnabled",
		modules = { "campkit", "campobject" },
		rows = {
			{ key = "campCountdown",     label = "OPT_CAMP_COUNTDOWN",  kind = "bool" },
			{ key = "campDepartureLine", label = "OPT_CAMP_DEPARTLINE", kind = "bool" },
		},
	})
end
if ns.RegisterModule then
	ns.RegisterModule({ id = "camp", key = "campEnabled", label = "OPT_PAGE_CAMP",
		aliases = { "camp", "campement", "kit" } })
end

-- ---------------------------------------------------------------------------
-- Événements propres au module
-- ---------------------------------------------------------------------------
local TICK = 0.25
local frame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_AURA", "PLAYER_ENTERING_WORLD" }) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_AURA" and unit ~= "player" then return end
	local ok, err = pcall(ns.UpdateCampFrame, ns)
	if not ok and ns.RecordError then ns:RecordError("camp:" .. event, err) end
end)
-- le décompte avance sans événement : rafraîchi quatre fois par seconde
frame:SetScript("OnUpdate", ns.Throttle(TICK, function()
	local ok, err = pcall(ns.UpdateCampFrame, ns)
	if not ok and ns.RecordError then ns:RecordError("camp:tick", err) end
end))
ns.campEventFrame = frame

if ns.Mark then ns.Mark("Camp") end
