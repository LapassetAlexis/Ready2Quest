-- CompanionEffects.lua -- Lot 2 : effets du compagnon (chasse et confort par type, mascottes, envies, changement) (QuestCompanion 2.0)
--
-- La créature capturée qu'on emmène donne deux effets liés à son TYPE : un
-- de chasse (capture, brillants, aides, repérage) et un de confort (envies,
-- friandises). Rien sur le combat, l'XP ou le butin, aucun pistage : la
-- seule chose que l'addon « voit » d'un monstre, c'est sa barre de nom, sa
-- cible, son survol.
--   * force : rang (normal ×1, élite ×1,5, rare et rare élite ×2, boss
--     ×2,5), +0,5 si brillante, +0,25 par étoile au-dessus de 1 (lot 1,
--     ns:CaptureStars), + bonus de complétion du type (lot 3,
--     ns:MenagerieTypeBonus) ;
--   * mascottes (apparences non capturées) : un bonus général modeste (un
--     peu de capture sur tout, envies qui baissent moins vite) dont la force
--     est l'étape d'évolution, comme le familier du chasseur ;
--   * envies : force pleine si les quatre sont à 50 % ou plus, sinon un
--     huitième de moins par envie en dessous (jamais sous la moitié) ;
--   * changement : une confirmation qui compare les effets, et l'effet ne
--     s'active qu'au bout de EFFECT_DELAY secondes (2 min, temps réel).
-- Les bonus passent par des enveloppes posées ici (CaptureChance,
-- ShinyChance, CaptureSpend, CaptureResolve, TreatCheckZone,
-- CompanionDecayFactor, CompanionTick, CompanionPet) : ces fonctions ne
-- savent rien des effets.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.EFFECT_DELAY = 120             -- s (temps réel) avant que les effets d'un nouveau compagnon s'activent
ns.EFFECT_NEED_OK = 50            -- une envie à ce niveau ou plus : comblée pour les effets
ns.EFFECT_TICK = 1                -- s entre deux relevés (activation, compte à rebours)
ns.EFFECT_RANK_STRENGTH = { trivial = 1, minus = 1, normal = 1, elite = 1.5, rare = 2, rareelite = 2, worldboss = 2.5 }
ns.EFFECT_SHINY_STRENGTH = 0.5
ns.EFFECT_STAR_STRENGTH = 0.25
ns.EFFECT_NAMED = { elite = true, rare = true, rareelite = true, worldboss = true }

-- Effets : `base` = valeur par point de force, `cap` = plafond. Les valeurs
-- sont des fractions (0,10 = 10 %). `type` : le type de créature visé.
--   capture   : chance de capture ×(1 + v) (sur `type`, ou les nommés)
--   shiny     : chance de brillant ×(1 + v) (sur `type`)
--   chain     : abattus comptés ×(1 + v) pour la chasse au brillant
--   spot      : patte sur les barres de nom (`type` pas encore capturé),
--               capture ×(1 + v) sur ces créatures-là
--   aidKeep   : chance qu'une aide utilisée ne soit pas consommée
--   aidRefund : chance qu'une capture ratée rende l'aide
--   aidZone   : chance d'une aide en plus à chaque palier de zone
--   treatZone : chance d'une friandise en plus à chaque palier de zone
--   decay     : l'envie `need` (ou toutes) baisse v moins vite
--   rest      : au repos, l'énergie remonte v plus vite
--   pet       : une caresse remonte le moral v en plus
local EFFECTS = {
	-- chasse
	spot             = { kind = "spot",      type = "beast",      base = 0.05, cap = 0.25 },
	capture_humanoid = { kind = "capture",   type = "humanoid",   base = 0.10, cap = 0.40 },
	shiny_undead     = { kind = "shiny",     type = "undead",     base = 0.15, cap = 0.60 },
	aid_keep         = { kind = "aidKeep",                        base = 0.08, cap = 0.30 },
	shiny_chain      = { kind = "chain",                          base = 0.50, cap = 1.50 },
	capture_named    = { kind = "capture",   named = true,        base = 0.12, cap = 0.45 },
	aid_zone         = { kind = "aidZone",                        base = 0.25, cap = 1.00 },
	aid_refund       = { kind = "aidRefund",                      base = 0.20, cap = 0.75 },
	capture_all      = { kind = "capture",   all = true,          base = 0.02, cap = 0.10 },
	-- confort
	decay_hunger     = { kind = "decay",     need = "hunger",     base = 0.10, cap = 0.40 },
	treat_zone       = { kind = "treatZone",                      base = 0.15, cap = 0.60 },
	decay_energy     = { kind = "decay",     need = "energy",     base = 0.10, cap = 0.40 },
	decay_curiosity  = { kind = "decay",     need = "curiosity",  base = 0.10, cap = 0.40 },
	decay_mood       = { kind = "decay",     need = "mood",       base = 0.10, cap = 0.40 },
	pet_mood         = { kind = "pet",                            base = 0.25, cap = 1.00 },
	decay_all        = { kind = "decay",     base = 0.05, cap = 0.25 },
	rest_energy      = { kind = "rest",                           base = 0.15, cap = 0.60 },
	-- mascottes : la force est l'étape d'évolution (1 à 5)
	mascot_decay     = { kind = "decay",     base = 0.04, cap = 0.20 },
}
for id, def in pairs(EFFECTS) do def.id = id end
ns.COMPANION_EFFECTS = EFFECTS

-- Chasse et confort de chaque type
local TYPE_EFFECTS = {
	beast      = { hunt = "spot",             comfort = "decay_hunger" },
	humanoid   = { hunt = "capture_humanoid", comfort = "treat_zone" },
	undead     = { hunt = "shiny_undead",     comfort = "decay_energy" },
	elemental  = { hunt = "aid_keep",         comfort = "decay_curiosity" },
	dragonkin  = { hunt = "shiny_chain",      comfort = "decay_mood" },
	demon      = { hunt = "capture_named",    comfort = "pet_mood" },
	giant      = { hunt = "aid_zone",         comfort = "decay_all" },
	mechanical = { hunt = "aid_refund",       comfort = "rest_energy" },
}
local MASCOT_EFFECTS = { hunt = "capture_all", comfort = "mascot_decay" }
ns.COMPANION_TYPE_EFFECTS = TYPE_EFFECTS
ns.COMPANION_MASCOT_EFFECTS = MASCOT_EFFECTS

local FR = {
	EFF_HUNT               = "Chasse : %s",
	EFF_COMFORT            = "Confort : %s",
	EFF_spot               = "repère les Bêtes pas encore capturées (patte sur leur barre de nom), capture +%d %% sur elles",
	EFF_capture_humanoid   = "capture des Humanoïdes +%d %%",
	EFF_shiny_undead       = "chance de brillant des Morts-vivants +%d %%",
	EFF_aid_keep           = "%d %% de chance qu'une aide utilisée ne soit pas consommée",
	EFF_shiny_chain        = "chasse au brillant : abattus comptés +%d %%",
	EFF_capture_named      = "capture des élites et rares +%d %%",
	EFF_aid_zone           = "%d %% de chance d'une aide de capture en plus à chaque palier de zone",
	EFF_aid_refund         = "capture ratée : %d %% de chance que l'aide revienne",
	EFF_capture_all        = "capture +%d %% sur toutes les créatures",
	EFF_decay_hunger       = "la faim baisse %d %% moins vite",
	EFF_treat_zone         = "%d %% de chance d'une friandise en plus à chaque palier de zone",
	EFF_decay_energy       = "l'énergie baisse %d %% moins vite",
	EFF_decay_curiosity    = "la curiosité baisse %d %% moins vite",
	EFF_decay_mood         = "le moral baisse %d %% moins vite",
	EFF_pet_mood           = "une caresse remonte le moral de %d %% en plus",
	EFF_decay_all          = "les envies baissent %d %% moins vite",
	EFF_rest_energy        = "au repos, l'énergie remonte %d %% plus vite",
	EFF_mascot_decay       = "les envies baissent %d %% moins vite",
	EFF_SECTION            = "Ses effets",
	EFF_SECTION_MASCOT     = "Ses effets (mascotte, grandit avec l'étape)",
	EFF_STRENGTH           = "Force ×%s · envies %d/4 : %d %%",
	EFF_ACTIVE             = "Actifs",
	EFF_PENDING            = "Actifs dans %s",
	EFF_OFF                = "Compagnon coupé : aucun effet",
	EFF_CONFIRM_TITLE      = "Changer de compagnon ?",
	EFF_CONFIRM_SUB        = "Ses effets ne s'activent qu'au bout de 2 minutes.",
	EFF_CONFIRM_NOW        = "Aujourd'hui : %s",
	EFF_CONFIRM_NEW        = "Avec %s :",
	EFF_CONFIRM_OK         = "Emmener",
	EFF_CONFIRM_CANCEL     = "Annuler",
	EFF_MSG_SWITCH         = "%s t'accompagne : ses effets s'activent dans 2 minutes.",
	EFF_MSG_ACTIVE         = "Effets de %s actifs.",
	EFF_MSG_AID_KEPT       = "%s : ton compagnon a récupéré l'aide (%s), elle n'est pas consommée.",
	EFF_MSG_AID_REFUND     = "Ton compagnon rapporte l'aide (%s) : rien n'est perdu.",
	EFF_MSG_AID_ZONE       = "Palier de zone : ton compagnon déniche en plus un %s.",
	EFF_MSG_TREAT_ZONE     = "Palier de zone : ton compagnon déniche en plus une friandise (%s).",
	EFF_PLATE_TIP          = "Patte : espèce pas encore capturée (effet de ton compagnon)",
	OPT_DAILY_EFFECT_PLATE      = "Patte sur les espèces à capturer (effet de repérage)",
	OPT_DAILY_EFFECT_PLATE_DESC = "Si ton compagnon a l'effet de repérage : une patte au-dessus du nom des créatures de son type pas encore capturées.",
	MEN_TIP_TODO_BONUS     = "à capturer · %d %% (+%d)",
	EFF_DEC                = ",",
}
local EN = {
	EFF_HUNT               = "Hunting: %s",
	EFF_COMFORT            = "Comfort: %s",
	EFF_spot               = "spots Beasts not yet captured (paw on their nameplate), capture +%d%% on them",
	EFF_capture_humanoid   = "Humanoid capture +%d%%",
	EFF_shiny_undead       = "Undead shiny chance +%d%%",
	EFF_aid_keep           = "%d%% chance that a used aid is not spent",
	EFF_shiny_chain        = "shiny hunt: kills count +%d%%",
	EFF_capture_named      = "elite and rare capture +%d%%",
	EFF_aid_zone           = "%d%% chance of an extra capture aid at each zone milestone",
	EFF_aid_refund         = "failed capture: %d%% chance to get the aid back",
	EFF_capture_all        = "capture +%d%% on every creature",
	EFF_decay_hunger       = "hunger drops %d%% slower",
	EFF_treat_zone         = "%d%% chance of an extra treat at each zone milestone",
	EFF_decay_energy       = "energy drops %d%% slower",
	EFF_decay_curiosity    = "curiosity drops %d%% slower",
	EFF_decay_mood         = "mood drops %d%% slower",
	EFF_pet_mood           = "petting raises mood %d%% more",
	EFF_decay_all          = "needs drop %d%% slower",
	EFF_rest_energy        = "while resting, energy comes back %d%% faster",
	EFF_mascot_decay       = "needs drop %d%% slower",
	EFF_SECTION            = "Its effects",
	EFF_SECTION_MASCOT     = "Its effects (mascot, grows with the stage)",
	EFF_STRENGTH           = "Strength ×%s · needs %d/4: %d%%",
	EFF_ACTIVE             = "Active",
	EFF_PENDING            = "Active in %s",
	EFF_OFF                = "Companion off: no effect",
	EFF_CONFIRM_TITLE      = "Change companion?",
	EFF_CONFIRM_SUB        = "Its effects only start after 2 minutes.",
	EFF_CONFIRM_NOW        = "Now: %s",
	EFF_CONFIRM_NEW        = "With %s:",
	EFF_CONFIRM_OK         = "Take along",
	EFF_CONFIRM_CANCEL     = "Cancel",
	EFF_MSG_SWITCH         = "%s comes along: its effects start in 2 minutes.",
	EFF_MSG_ACTIVE         = "%s's effects are active.",
	EFF_MSG_AID_KEPT       = "%s: your companion caught the aid (%s), it is not spent.",
	EFF_MSG_AID_REFUND     = "Your companion brings the aid back (%s): nothing lost.",
	EFF_MSG_AID_ZONE       = "Zone milestone: your companion also digs up a %s.",
	EFF_MSG_TREAT_ZONE     = "Zone milestone: your companion also digs up a treat (%s).",
	EFF_PLATE_TIP          = "Paw: species not captured yet (your companion's effect)",
	OPT_DAILY_EFFECT_PLATE      = "Paw on species to capture (spotting effect)",
	OPT_DAILY_EFFECT_PLATE_DESC = "If your companion has the spotting effect: a paw above the name of creatures of its type not captured yet.",
	MEN_TIP_TODO_BONUS     = "to capture · %d%% (+%d)",
	EFF_DEC                = ".",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.EFFECT_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ companionEffectPlate = true })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local present = false
	for _, row in ipairs(ns.DAILY_OPTION_ROWS) do if row.key == "companionEffectPlate" then present = true end end
	if not present then
		ns.DAILY_OPTION_ROWS[#ns.DAILY_OPTION_ROWS + 1] = { key = "companionEffectPlate", label = "OPT_DAILY_EFFECT_PLATE",
			kind = "bool", describe = function() return L.OPT_DAILY_EFFECT_PLATE_DESC end,
			onChange = function() ns:EffectPlatesRefresh() end }
	end
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function G(name) return rawget(_G, name) end
local function Wall() return tonumber(Call(G("time"))) or 0 end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end
local function Pct(value) return math.floor((tonumber(value) or 0) * 100 + 0.5 + 1e-9) end

-- 2,5 / 2.5 ; 2 sans décimale
local function Num(value)
	value = math.floor((tonumber(value) or 0) * 100 + 0.5) / 100
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	return (text:gsub("%.", L.EFF_DEC or "."))
end
ns.EffectNum = Num

-- ---------------------------------------------------------------------------
-- Force et valeurs
-- ---------------------------------------------------------------------------
-- La fiche d'une créature capturée (ou d'une espèce de la Ménagerie)
local function CaptureEntry(self, npc)
	if not (npc and self.CaptureData) then return nil end
	local ok, data = pcall(self.CaptureData, self)
	local creatures = ok and type(data) == "table" and data.creatures
	return type(creatures) == "table" and (creatures[npc] or creatures[tostring(npc)]) or nil
end

-- Envies comblées (>= EFFECT_NEED_OK) et facteur de force : 1 si les quatre,
-- un huitième de moins par envie en dessous (0,5 au pire)
function ns:CompanionEffectNeeds()
	local needs = self.CompanionData and self:CompanionData().needs or {}
	local ok = 0
	for _, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		if (tonumber(needs[key]) or 0) >= ns.EFFECT_NEED_OK then ok = ok + 1 end
	end
	return 0.5 + 0.5 * ok / 4, ok
end

-- Ce que donnerait une créature ou une mascotte.
-- `spec` : une apparence (def du catalogue ou « cap:<npc>[:s] »), ou
-- { npc, shiny, class, type } (Ménagerie) ; opts.full : sans les envies.
-- Rend { typeKey, mascot, strength, needs, needsOk, hunt = { id, value, label }, comfort = … }
function ns:CompanionEffectsFor(spec, opts)
	opts = opts or {}
	if type(spec) == "string" then spec = self.CompanionAppearanceDef and self:CompanionAppearanceDef(spec) end
	if type(spec) ~= "table" then return nil end
	local result = {}
	local npc = tonumber(spec.npc)
	local typeKey, strength, pair
	if npc then
		local entry = CaptureEntry(self, npc) or {}
		local class = spec.class or entry.class or "normal"
		typeKey = self.CreatureTypeKey and self:CreatureTypeKey(spec.type or entry.type) or nil
		pair = typeKey and TYPE_EFFECTS[typeKey]
		local shiny = spec.shiny and true or false
		strength = ns.EFFECT_RANK_STRENGTH[class] or 1
		if shiny then strength = strength + ns.EFFECT_SHINY_STRENGTH end
		local stars = self.CaptureStars and tonumber((Call(self.CaptureStars, self, npc, shiny))) or nil
		stars = math.max(1, math.min(3, math.floor(stars or 1)))
		strength = strength + ns.EFFECT_STAR_STRENGTH * (stars - 1)
		if typeKey and self.MenagerieTypeBonus then
			strength = strength + math.max(0, tonumber((Call(self.MenagerieTypeBonus, self, typeKey))) or 0)
		end
		result.npc, result.shiny, result.class, result.stars = npc, shiny, class, stars
	end
	if not pair then
		-- mascotte (ou créature de type inconnu) : l'effet général, à la force de l'étape
		pair = MASCOT_EFFECTS
		strength = self.CompanionStage and tonumber(self:CompanionStage()) or 1
		result.mascot = true
		typeKey = nil
	end
	local factor, needsOk = 1, 4
	if not opts.full then factor, needsOk = self:CompanionEffectNeeds() end
	result.typeKey, result.strength, result.needs, result.needsOk = typeKey, strength, factor, needsOk
	for _, slot in ipairs({ "hunt", "comfort" }) do
		local def = EFFECTS[pair[slot]]
		local value = math.min(def.cap, def.base * strength * factor)
		result[slot] = { id = def.id, value = value, label = self:F("EFF_" .. def.id, Pct(value)) }
	end
	return result
end

-- Clé d'effet d'une apparence : toutes les mascottes partagent le même
-- (changer de mascotte ne change rien aux effets)
local function EffectKey(def)
	if type(def) ~= "table" then return "mascot" end
	if def.captured or def.npc then return tostring(def.id) end
	return "mascot"
end
ns.CompanionEffectKey = EffectKey

-- Le compagnon porté, sans passer par le catalogue (appelé souvent : pas de
-- liste reconstruite) : { id, npc, shiny, captured } ou { id } (mascotte)
local function CurrentSpec(self)
	local id = tostring(self:CompanionData().appearance or "")
	local npc, suffix = id:match("^cap:(%d+)(.*)$")
	npc = tonumber(npc)
	local shiny = suffix == ":s"
	if npc and self.CaptureHas and self:CaptureHas(npc, shiny) then
		return { id = id, npc = npc, shiny = shiny, captured = true }
	end
	return { id = id }
end

-- Suit le compagnon porté : un autre jeu d'effets relance le délai
function ns:CompanionEffectsSync()
	if not self.CompanionData then return nil end
	local data = self:CompanionData()
	local spec = CurrentSpec(self)
	local key = EffectKey(spec)
	local record = data.effects
	if type(record) ~= "table" then
		record = { app = spec.id, key = key, since = Wall() }
		data.effects = record
		self.effectWasActive = false
		return record, true, spec
	end
	if record.app ~= spec.id or record.key ~= key then
		local changed = record.key ~= key
		if changed then
			record.since = Wall()
			self.effectWasActive = false
		end
		record.app, record.key = spec.id, key
		return record, changed, spec
	end
	return record, false, spec
end

-- Le compagnon en cours. Contrat (docs/QC2-CONTRATS.md, lot 2) :
-- { typeKey, strength, active, activeAt, hunt = { id, value, label }, comfort = … }
-- Gardé tant que rien ne change (compagnon, étape, envies, captures) : il
-- est lu à chaque relevé des envies et à chaque chance de capture.
function ns:CompanionEffects()
	local record, _, spec = self:CompanionEffectsSync()
	if not (record and spec) then return nil end
	local capture = self.CaptureData and self:CaptureData() or {}
	local _, needsOk = self:CompanionEffectNeeds()
	local stage = self.CompanionStage and self:CompanionStage() or 1
	local key = table.concat({ spec.id, tostring(stage), tostring(needsOk), tostring(capture.serial), tostring(capture.count),
		tostring(self.CaptureStars ~= nil), tostring(self.MenagerieTypeBonus ~= nil) }, "|")
	local cache = self.effectCache
	local effects
	if cache and cache.key == key then
		effects = cache.effects
	else
		effects = self:CompanionEffectsFor(spec)
		if not effects then return nil end
		effects.app = spec.id
		self.effectCache = { key = key, effects = effects }
	end
	local now = Wall()
	effects.activeAt = (tonumber(record.since) or now) + ns.EFFECT_DELAY
	effects.remaining = math.max(0, effects.activeAt - now)
	effects.active = ModuleOn() and effects.remaining <= 0
	return effects
end

-- Valeur active d'un effet (0 s'il n'est pas actif ou pas celui du compagnon)
function ns:CompanionEffectValue(id)
	if not ModuleOn() then return 0 end
	local ok, effects = pcall(self.CompanionEffects, self)
	if not ok or type(effects) ~= "table" or not effects.active then return 0 end
	if effects.hunt and effects.hunt.id == id then return effects.hunt.value end
	if effects.comfort and effects.comfort.id == id then return effects.comfort.value end
	return 0
end

-- L'effet actif d'une sorte (capture, decay…) : def et valeur, ou nil
local function ActiveOf(self, kind)
	if not ModuleOn() then return nil end
	local ok, effects = pcall(self.CompanionEffects, self)
	if not ok or type(effects) ~= "table" or not effects.active then return nil end
	local found = {}
	for _, slot in ipairs({ "hunt", "comfort" }) do
		local effect = effects[slot]
		local def = effect and EFFECTS[effect.id]
		if def and def.kind == kind and effect.value > 0 then found[#found + 1] = { def = def, value = effect.value } end
	end
	return found[1] and found or nil
end

-- Les deux lignes « Chasse : … / Confort : … »
function ns:CompanionEffectsText(effects)
	if type(effects) ~= "table" then return {} end
	return { self:F("EFF_HUNT", effects.hunt.label), self:F("EFF_COMFORT", effects.comfort.label) }
end

-- Fiche de la Ménagerie : les effets de cette créature (pleine force,
-- version montrée) ; une espèce jamais croisée : rien
function ns:CompanionEffectsLines(entry, shiny)
	if type(entry) ~= "table" or not entry.known or not entry.npc then return {} end
	local effects = self:CompanionEffectsFor({ npc = entry.npc, shiny = shiny, class = entry.class, type = entry.type },
		{ full = true })
	if not effects or effects.mascot then return {} end
	return self:CompanionEffectsText(effects)
end

-- ---------------------------------------------------------------------------
-- Enveloppes : les bonus
-- ---------------------------------------------------------------------------
-- Type d'une créature (texte du client, clé, ou unité)
local function TypeOf(self, info)
	if type(info) ~= "table" then return nil end
	if info.typeKey then return info.typeKey end
	return self.CreatureTypeKey and self:CreatureTypeKey(info.type) or nil
end

-- Multiplicateur de capture des effets actifs pour cette créature
function ns:CompanionCaptureBonus(info)
	local found = ActiveOf(self, "capture")
	local spot = ActiveOf(self, "spot")
	local bonus = 0
	local typeKey = TypeOf(self, info)
	local class = type(info) == "table" and info.class or "normal"
	for _, item in ipairs(found or {}) do
		local def = item.def
		if def.all or (def.named and ns.EFFECT_NAMED[class or ""]) or (def.type and def.type == typeKey) then
			bonus = bonus + item.value
		end
	end
	for _, item in ipairs(spot or {}) do
		local npc = type(info) == "table" and tonumber(info.npcID or info.npc)
		local missing = npc and self.CaptureHas and not self:CaptureHas(npc, info.shiny and true or false)
		if item.def.type == typeKey and missing then bonus = bonus + item.value end
	end
	return bonus
end

do
	local chance = ns.CaptureChance
	if chance then
		-- la chance sans les effets (infobulle : « 45 % (+15) »)
		ns.CaptureChanceBase = chance
		function ns:CaptureChance(info, aidID, playerLevel, ...)
			local value, sure = chance(self, info, aidID, playerLevel, ...)
			if sure or not value or value <= 0 then return value, sure end
			local ok, bonus = pcall(self.CompanionCaptureBonus, self, info)
			if not ok or not bonus or bonus <= 0 then return value, sure end
			return math.max(0, math.min(ns.CAPTURE_MAX or 0.95, value * (1 + bonus))), sure
		end
	end
end

-- Brillants : la chance d'une créature (type passé en 3e argument, ou celui
-- de la créature en cours de tirage)
do
	local shinyChance = ns.ShinyChance
	if shinyChance then
		function ns:ShinyChance(class, killed, typeKey, ...)
			typeKey = typeKey or self.effectShinyType
			local chain = ActiveOf(self, "chain")
			if chain and killed then killed = (tonumber(killed) or 0) * (1 + chain[1].value) end
			local value = shinyChance(self, class, killed, typeKey, ...)
			local found = ActiveOf(self, "shiny")
			for _, item in ipairs(found or {}) do
				if item.def.type == typeKey then value = value * (1 + item.value) end
			end
			return value
		end
	end
	local roll = ns.ShinyRoll
	if roll then
		function ns:ShinyRoll(unit, entry, ...)
			-- type secret ou illisible : pas de bonus de type, le tirage se fait quand même
			local text = Call(G("UnitCreatureType"), unit)
			self.effectShinyType = self.CreatureTypeKey and Call(self.CreatureTypeKey, self, text) or nil
			local ok, result = pcall(roll, self, unit, entry, ...)
			self.effectShinyType = nil
			if not ok then error(result, 0) end
			return result
		end
	end
end

-- Élémentaire : une aide parfois pas consommée
do
	local spend = ns.CaptureSpend
	if spend then
		function ns:CaptureSpend(id, ...)
			local found = ActiveOf(self, "aidKeep")
			local items = self.CaptureData and self:CaptureData().items
			if found and items and (items[id] or 0) > 0 and math.random() < found[1].value then
				self:Print(self:F("EFF_MSG_AID_KEPT", self:CompanionName(), self:CaptureAidLabel(id)))
				return true
			end
			return spend(self, id, ...)
		end
	end
end

-- Mécanique : une capture ratée rend parfois l'aide
do
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local result = resolve(self, rolling, ...)
			local ok, err = pcall(function()
				if type(rolling) ~= "table" then return end
				if rolling.success then
					-- une espèce de moins à repérer
					if self.EffectPlatesRefresh then self:EffectPlatesRefresh() end
					return
				end
				local found = rolling.aid and ActiveOf(self, "aidRefund")
				if found and math.random() < found[1].value then
					local back = self:CaptureGrant(rolling.aid, { quiet = true, silent = true })
					if back == "ok" then self:Print(self:F("EFF_MSG_AID_REFUND", self:CaptureAidLabel(rolling.aid))) end
				end
			end)
			if not ok and self.RecordError then self:RecordError("effects:resolve", err) end
			return result
		end
	end
end

-- Géant (une aide) et Humanoïde (une friandise) : un palier de zone donne en plus
do
	local check = ns.TreatCheckZone
	if check then
		function ns:TreatCheckZone(zoneID, opts, ...)
			local gained = check(self, zoneID, opts, ...)
			-- rattrapage (mise à jour) : pas d'effet rétroactif
			if type(gained) ~= "table" or #gained == 0 or (opts and opts.quiet) then return gained end
			local ok, err = pcall(function()
				local aid, treat = ActiveOf(self, "aidZone"), ActiveOf(self, "treatZone")
				for _ in ipairs(gained) do
					if aid and self.CaptureGrant and math.random() < aid[1].value then
						local result, id = self:CaptureGrant("draw", { quiet = true, silent = true })
						if result == "ok" then self:Print(self:F("EFF_MSG_AID_ZONE", self:CaptureAidLabel(id))) end
					end
					if treat and self.TreatGrant and self.TreatRandom and math.random() < treat[1].value then
						local kind = self:TreatRandom()
						if kind and self:TreatGrant(kind, { quiet = true }) then
							self:Print(self:F("EFF_MSG_TREAT_ZONE", self:TreatLabel(kind)))
						end
					end
				end
			end)
			if not ok and self.RecordError then self:RecordError("effects:zone", err) end
			return gained
		end
	end
end

-- Envies qui baissent moins vite
do
	local decay = ns.CompanionDecayFactor
	function ns:CompanionDecayFactor(key, ...)
		local factor = decay and decay(self, key, ...) or 1
		local found = ActiveOf(self, "decay")
		for _, item in ipairs(found or {}) do
			if item.def.need == nil or item.def.need == key then factor = factor * (1 - item.value) end
		end
		return factor
	end
end

-- Mécanique : l'énergie remonte plus vite au repos
do
	local tick = ns.CompanionTick
	if tick then
		function ns:CompanionTick(seconds, ...)
			local result = tick(self, seconds, ...)
			local found = ModuleOn() and (tonumber(seconds) or 0) > 0 and ActiveOf(self, "rest")
			if found and self:CompanionResting() and not self:CompanionData().sleepy then
				local rules = ns.COMPANION_RULES or {}
				local needs = self:CompanionData().needs
				local gain = (tonumber(rules.restGain) or 4) * (seconds / 60) * found[1].value
				needs.energy = math.min(tonumber(rules.max) or 100, (tonumber(needs.energy) or 0) + gain)
			end
			return result
		end
	end
end

-- Démon : une caresse compte plus. Seulement une vraie caresse : l'appel
-- rend vrai aussi pour le garde-manger (Maj + clic, Treats.lua) et le
-- tutoriel ; une caresse, elle, remet companionLastPet à l'heure.
do
	local pet = ns.CompanionPet
	if pet then
		function ns:CompanionPet(...)
			local before = self.companionLastPet
			local done = pet(self, ...)
			if done and self.companionLastPet ~= nil and self.companionLastPet ~= before then
				local found = ActiveOf(self, "pet")
				if found then self:CompanionAdd("mood", 8 * found[1].value) end
			end
			return done
		end
	end
end

-- Toute nouvelle apparence passe par là : le délai repart
do
	for _, name in ipairs({ "CompanionSetAppearance", "CompanionCycleAppearance" }) do
		local original = ns[name]
		if original then
			ns[name] = function(self, ...)
				local result = original(self, ...)
				local ok, record, changed = pcall(self.CompanionEffectsSync, self)
				if ok and changed and result then
					self.effectWasActive = false
					if self.EffectPlatesRefresh then pcall(self.EffectPlatesRefresh, self) end
				end
				return result
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Changer de compagnon : confirmation qui compare les effets
-- ---------------------------------------------------------------------------
local CONFIRM_W = 420

function ns:EnsureEffectsConfirm()
	if self.effectsConfirm then return self.effectsConfirm end
	if not (Theme and Theme.CreateDialog) then return nil end
	local frame = Theme.CreateDialog(UIParent, CONFIRM_W, 240, { title = L.EFF_CONFIRM_TITLE, subtitle = L.EFF_CONFIRM_SUB })
	if not frame then return nil end
	frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
	frame.text = Theme.Text(frame, Theme.F_BODY, Theme.LABEL)
	frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.pad, frame.contentTop - 18)
	frame.text:SetWidth(frame.innerWidth)
	frame.text:SetJustifyH("LEFT")
	if frame.text.SetWordWrap then frame.text:SetWordWrap(true) end
	frame.ok = frame:AddFooterButton(L.EFF_CONFIRM_OK, function() ns:CompanionConfirmAnswer(true) end, "primary")
	frame.cancel = frame:AddFooterButton(L.EFF_CONFIRM_CANCEL, function() ns:CompanionConfirmAnswer(false) end, "outline")
	if frame.close then frame.close:SetScript("OnClick", function() ns:CompanionConfirmAnswer(false) end) end
	frame:Hide()
	self.effectsConfirm = frame
	return frame
end

-- Texte de la comparaison : aujourd'hui, puis avec le nouveau
function ns:CompanionConfirmText(def)
	local current = self:CompanionEffects()
	local fresh = self:CompanionEffectsFor(def)
	local lines = {}
	local name = self.CompanionName and self:CompanionName() or "?"
	lines[#lines + 1] = self:F("EFF_CONFIRM_NOW", name)
	for _, line in ipairs(self:CompanionEffectsText(current)) do lines[#lines + 1] = "  " .. line end
	lines[#lines + 1] = ""
	lines[#lines + 1] = self:F("EFF_CONFIRM_NEW", tostring(L[def.label] or def.label))
	for _, line in ipairs(self:CompanionEffectsText(fresh)) do lines[#lines + 1] = "  " .. line end
	return table.concat(lines, "\n")
end

-- Choisir une apparence en passant par la confirmation. onDone(def) quand
-- c'est fait (tout de suite, ou après « Emmener »). Rend la def si c'est
-- fait, "ask" si la confirmation attend, nil si c'est refusé (verrouillé).
-- Mascotte vers mascotte : mêmes effets, pas de question.
function ns:CompanionAskAppearance(id, onDone)
	local def = self.CompanionAppearanceDef and self:CompanionAppearanceDef(id)
	if not (def and self:CompanionIsUnlocked("app", def)) then return nil end
	local current = self:CompanionCurrentAppearance()
	local function Apply()
		local done = self:CompanionSetAppearance(def.id)
		if done and onDone then
			local ok, err = pcall(onDone, done)
			if not ok and self.RecordError then self:RecordError("effects:apply", err) end
		end
		return done
	end
	if current.id == def.id or EffectKey(current) == EffectKey(def) or not ModuleOn() then return Apply() end
	local frame = self:EnsureEffectsConfirm()
	if not frame then return Apply() end
	frame.pending = { def = def, apply = Apply }
	frame.text:SetText(self:CompanionConfirmText(def))
	local h = Theme.TextHeight and Theme.TextHeight(frame.text, frame.innerWidth, Theme.F_BODY) or 120
	frame:SetHeight(math.ceil(-frame.contentTop + 18 + h + 22 + (Theme.DIALOG_FOOTER or 56)))
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.15) end
	return "ask"
end

function ns:CompanionConfirmAnswer(yes)
	local frame = self.effectsConfirm
	local pending = frame and frame.pending
	if frame then frame.pending = nil; frame:Hide() end
	if not (yes and pending) then return nil end
	local done = pending.apply()
	if done then self:Print(self:F("EFF_MSG_SWITCH", self:CompanionName())) end
	return done
end

-- ---------------------------------------------------------------------------
-- Page Compagnon du carnet : effets en cours, force, compte à rebours
-- (JournalWindow.lua appelle ces deux fonctions)
-- ---------------------------------------------------------------------------
function ns:CompanionEffectsBuildPane(pane, content, x, y, width)
	local UI = ns.JournalUI
	if not (UI and pane and Theme.CreateSection) then return end
	pane.effTitle = Theme.CreateSection(pane, L.EFF_SECTION)
	pane.effTitle:SetWidth(width)
	UI.At(pane.effTitle, content, x, y)
	local function Line(dy, color)
		local text = UI.Text(pane, Theme.F_SMALL, color, width)
		if text.SetWordWrap then text:SetWordWrap(false) end
		UI.At(text, content, x, y + dy)
		return text
	end
	pane.effHunt = Line(-24, Theme.TEXT)
	pane.effComfort = Line(-40, Theme.TEXT)
	pane.effState = Line(-58, Theme.MUTED_LIGHT)
end

local function Clockface(seconds)
	seconds = math.max(0, math.ceil(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function ns:CompanionEffectsRefreshPane(pane)
	if not (pane and pane.effHunt) then return end
	local effects = self:CompanionEffects()
	if not effects then return end
	local title = effects.mascot and L.EFF_SECTION_MASCOT or L.EFF_SECTION
	local label, detail = tostring(title):match("^(.-)%s*%((.*)%)%s*$")
	pane.effTitle:SetText(label or title, detail)
	local lines = self:CompanionEffectsText(effects)
	pane.effHunt:SetText(lines[1] or "")
	pane.effComfort:SetText(lines[2] or "")
	local state
	if not ModuleOn() then
		state = L.EFF_OFF
	elseif effects.active then
		state = L.EFF_ACTIVE
	else
		state = self:F("EFF_PENDING", Clockface(effects.remaining))
	end
	pane.effState:SetText(self:F("EFF_STRENGTH", Num(effects.strength), effects.needsOk, Pct(effects.needs)) .. " · " .. state)
	local c = effects.active and Theme.GOLD or Theme.MUTED_LIGHT
	pane.effState:SetTextColor(c[1], c[2], c[3])
	local tc = effects.active and Theme.TEXT or Theme.MUTED
	pane.effHunt:SetTextColor(tc[1], tc[2], tc[3])
	pane.effComfort:SetTextColor(tc[1], tc[2], tc[3])
end

-- ---------------------------------------------------------------------------
-- Repérage : une patte sur la barre de nom des créatures du type visé pas
-- encore capturées (comme le losange des brillantes, Shiny.lua)
-- ---------------------------------------------------------------------------
ns.EFFECT_PLATE_SIZE = 16
ns.EFFECT_SPOT_TTL = 5            -- s : type repéré gardé entre deux barres de nom
ns.EFFECT_PLATE_X = -24           -- à gauche du losange des brillantes
ns.EFFECT_PLATE_Y = 6
ns.EFFECT_PAW = "Interface\\Icons\\Ability_Tracking"
ns.effectPlates = ns.effectPlates or {}       -- unité -> cadre de base de la barre
ns.effectPlateMarks = ns.effectPlateMarks or {}  -- cadre de base -> patte

local function PlateFor(unit)
	local api = G("C_NamePlate")
	if type(api) ~= "table" or type(api.GetNamePlateForUnit) ~= "function" then return nil end
	local ok, plate = pcall(api.GetNamePlateForUnit, unit)
	if not ok or type(plate) ~= "table" then return nil end
	if type(plate.IsForbidden) == "function" then
		local okF, forbidden = pcall(plate.IsForbidden, plate)
		if okF and forbidden then return nil end
	end
	return plate
end

local function PawFor(plate)
	local mark = ns.effectPlateMarks[plate]
	if mark then return mark end
	local ok, frame = pcall(CreateFrame, "Frame", nil, plate)
	if not ok or not frame then return nil end
	local size = ns.EFFECT_PLATE_SIZE
	frame:SetSize(size + 4, size + 4)
	frame:SetPoint("BOTTOM", plate, "TOP", ns.EFFECT_PLATE_X, ns.EFFECT_PLATE_Y - size / 2)
	if frame.SetFrameLevel and plate.GetFrameLevel then
		pcall(frame.SetFrameLevel, frame, (tonumber(plate:GetFrameLevel()) or 1) + 6)
	end
	frame.back = frame:CreateTexture(nil, "ARTWORK")
	frame.back:SetTexture(Theme.SOLID or "Interface\\Buttons\\WHITE8X8")
	frame.back:SetAllPoints()
	frame.back:SetVertexColor(0, 0, 0, 0.8)
	frame.icon = frame:CreateTexture(nil, "OVERLAY")
	frame.icon:SetTexture(ns.EFFECT_PAW)
	frame.icon:SetSize(size, size)
	frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
	if frame.icon.SetTexCoord then frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	frame:Hide()
	ns.effectPlateMarks[plate] = frame
	return frame
end

-- Le type repéré par le compagnon (effet actif), ou nil
function ns:EffectSpotType()
	if self:DB().companionEffectPlate == false then return nil end
	local found = ActiveOf(self, "spot")
	return found and found[1].def.type or nil
end

-- Cette unité est-elle une créature à repérer ?
function ns:EffectSpotUnit(unit, spotType)
	spotType = spotType or self:EffectSpotType()
	if not spotType then return false end
	-- retours du client passés par ns.Plain : une valeur secrète ne se compare pas
	if ns.Plain(Call(G("UnitIsPlayer"), unit)) or ns.Plain(Call(G("UnitPlayerControlled"), unit)) then return false end
	local reaction = tonumber(ns.Plain(Call(G("UnitReaction"), unit, "player")))
	if reaction then
		if reaction > 4 then return false end
	elseif ns.Plain(Call(G("UnitCanAttack"), "player", unit)) ~= true then
		return false
	end
	if not self.CreatureTypeKey or Call(self.CreatureTypeKey, self, Call(G("UnitCreatureType"), unit)) ~= spotType then return false end
	local guid = ns.Plain(Call(G("UnitGUID"), unit))
	local npc = type(guid) == "string" and ns.BestiaryNpcID and ns.BestiaryNpcID(guid)
	if not npc then return false end
	return not (self.CaptureHas and self:CaptureHas(npc, false))
end

-- Pose ou retire la patte d'une unité ; rend true si elle est montrée
function ns:EffectPlateUpdate(unit, spotType)
	local plate = self.effectPlates[unit] or PlateFor(unit)
	if not plate then return false end
	self.effectPlates[unit] = plate
	local show = ModuleOn() and self:EffectSpotUnit(unit, spotType or self:EffectSpotType())
	local mark = show and PawFor(plate) or self.effectPlateMarks[plate]
	if not mark then return false end
	if show then mark:Show() else mark:Hide() end
	return show and true or false
end

function ns:EffectPlatesRefresh()
	local api = G("C_NamePlate")
	if type(api) == "table" and type(api.GetNamePlates) == "function" then
		local ok, plates = pcall(api.GetNamePlates)
		for _, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
			local unit = ns.Plain(plate.namePlateUnitToken)
			if type(unit) == "string" then self.effectPlates[unit] = plate end
		end
	end
	local spotType = self:EffectSpotType()
	self.effectSpotCache = { type = spotType or false, at = ns.Now and ns.Now() or 0 }
	local shown = 0
	for unit in pairs(self.effectPlates) do
		local ok, on = pcall(self.EffectPlateUpdate, self, unit, spotType or false)
		if ok and on then shown = shown + 1 end
	end
	return shown
end

do
	local ok, plateFrame = pcall(CreateFrame, "Frame")
	if ok and plateFrame then
		local PLATE_EVENTS = {
			-- chaque barre de nom qui apparaît : rien de coûteux sans l'effet de
			-- repérage (type gardé par EffectPlatesRefresh, relu au plus toutes
			-- les EFFECT_SPOT_TTL secondes)
			NAME_PLATE_UNIT_ADDED = function(unit)
				if type(unit) ~= "string" then return end
				ns.effectPlates[unit] = nil
				if not ModuleOn() then return end
				local cache, now = ns.effectSpotCache, ns.Now and ns.Now() or 0
				if not cache or now - cache.at >= ns.EFFECT_SPOT_TTL or now < cache.at then
					cache = { type = ns:EffectSpotType() or false, at = now }
					ns.effectSpotCache = cache
				end
				if cache.type then ns:EffectPlateUpdate(unit, cache.type) end
			end,
			NAME_PLATE_UNIT_REMOVED = function(unit)
				local plate = type(unit) == "string" and ns.effectPlates[unit]
				local mark = plate and ns.effectPlateMarks[plate]
				if mark then mark:Hide() end
				if type(unit) == "string" then ns.effectPlates[unit] = nil end
			end,
		}
		for event in pairs(PLATE_EVENTS) do pcall(plateFrame.RegisterEvent, plateFrame, event) end
		plateFrame:SetScript("OnEvent", function(_, event, ...)
			local done, err = pcall(PLATE_EVENTS[event], ...)
			if not done and ns.RecordError then ns:RecordError("effects:plate", err) end
		end)
		ns.effectPlateFrame = plateFrame
	end
end

-- ---------------------------------------------------------------------------
-- Horloge : activation (annoncée une fois), compte à rebours de la page
-- ---------------------------------------------------------------------------
function ns:CompanionEffectsTick()
	if not ModuleOn() then return nil end
	local frame = self.journalFrame
	local pageShown = frame and frame.evo and frame.kind == "evolution" and frame.IsShown and frame:IsShown()
	-- déjà actifs et page fermée : rien à suivre (un changement d'apparence
	-- remet effectWasActive à false, CompanionEffectsSync)
	if self.effectWasActive == true and not pageShown then return nil end
	local effects = self:CompanionEffects()
	if not effects then return nil end
	if effects.active and self.effectWasActive == false then
		self:Print(self:F("EFF_MSG_ACTIVE", self:CompanionName()))
		if self.CompanionFx then pcall(self.CompanionFx, self, "sparkle") end
	end
	if effects.active ~= self.effectWasActive then
		self.effectWasActive = effects.active
		pcall(self.EffectPlatesRefresh, self)
	end
	if pageShown then self:CompanionEffectsRefreshPane(frame.evo) end
	return effects
end

do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame and ns.Throttle then
		frame:SetScript("OnUpdate", ns.Throttle(ns.EFFECT_TICK, function()
			local done, err = pcall(ns.CompanionEffectsTick, ns)
			if not done and ns.RecordError then ns:RecordError("effects:tick", err) end
		end))
		ns.effectEventFrame = frame
	end
end

if ns.Mark then ns.Mark("CompanionEffects") end
