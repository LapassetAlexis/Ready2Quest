-- Module « Kit de camp » (Camp.lua, v1.23.0) : déclaration et chaînes,
-- contrôles kit/objet avant le départ, module coupé, compte à rebours au camp
-- (feu en ville 1.33.3), temps de buffs restant en quittant le camp, page.
local Check, ResetWorld, NS, Mock, Result = T.Check, T.ResetWorld, T.NS, T.Mock, T.Result

local CAMP_NEARBY, WELCOME, BENEFITS, BOOSTED_AP = 1283391, 1229739, 1229741, 1230164
local BASIC_KIT, EXPERT_KIT = 279981, 279974
local SHARPENING_WHEEL, CAMP_TENT = 279944, 279978

-- Fenêtre de compétences : absente du mock commun, simulée ici puis rendue
local savedNum, savedInfo = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
local skills = {}
_G.GetNumSkillLines = function() return #skills end
_G.GetSkillLineInfo = function(index)
	local s = skills[index]
	if not s then return nil end
	-- name, isHeader, isExpanded, skillRank
	return s[1], s[2] == true, true, s[3] or 0
end
local function SetSkills(list) skills = list end

local function Bag(items)
	local slots = {}
	for index, item in ipairs(items) do slots[index] = { itemID = item[1], stackCount = item[2] or 1 } end
	Mock.world.bags = { [0] = { size = 16, items = slots } }
end

local function Fresh()
	ResetWorld()
	SetSkills({})
	NS.campArrivedAt = nil
	NS.campFrame = nil
	NS.lastCampDeparture = nil
	NS:DetectCapabilities()
end

local function FrameText() return NS.campFrame and NS.campFrame.text:GetText() end
local function FrameShown() return NS.campFrame ~= nil and NS.campFrame:IsShown() end

-- ---------------------------------------------------------------------------
-- Chargement et déclaration
-- ---------------------------------------------------------------------------
do
	Check("[CAMP] Camp.lua listé dans le .toc", (function()
		for _, file in ipairs(TOC_FILES) do if file == "Ready2Quest/Camp.lua" then return true end end
		return false
	end)())
	local kit, object = NS:FindCheck("campkit"), NS:FindCheck("campobject")
	Check("[CAMP] contrôles kit et objet déclarés, poids faibles (5..10), module listé", kit and object
		and kit.weight >= 5 and kit.weight <= 10 and object.weight >= 5 and object.weight <= 10
		and NS:FindModule("camp") ~= nil and NS:FindModule("camp").key == "campEnabled")
	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "camp" then page = def end end
	Check("[CAMP] page de réglages avec interrupteur, avant la section QoL", page ~= nil and page.power == "campEnabled"
		and page.group == "OPT_GROUP_MODULES" and (function()
		local campIndex, merchantIndex
		for index, def in ipairs(NS.OPTION_PAGES) do
			if def.id == "camp" then campIndex = index elseif def.id == "merchant" then merchantIndex = index end
		end
		return campIndex and merchantIndex and campIndex < merchantIndex
	end)())
	Check("[CAMP] buffs du camp jamais appris (Buffs.lua)", NS.IGNORED_BUFF_SPELLS[BOOSTED_AP] == true and NS.IGNORED_BUFF_SPELLS[BENEFITS] == true)
end

-- ---------------------------------------------------------------------------
-- Chaînes : fr et en complètes, mêmes paramètres
-- ---------------------------------------------------------------------------
do
	local fr, en = NS.CAMP_STRINGS.fr, NS.CAMP_STRINGS.en
	local missing = {}
	for key in pairs(fr) do if type(en[key]) ~= "string" or en[key] == "" then missing[#missing + 1] = "en:" .. key end end
	for key in pairs(en) do if type(fr[key]) ~= "string" or fr[key] == "" then missing[#missing + 1] = "fr:" .. key end end
	local mismatch = {}
	for key, value in pairs(fr) do
		local a = select(2, value:gsub("%%[ds]", ""))
		local b = select(2, (en[key] or ""):gsub("%%[ds]", ""))
		if a ~= b then mismatch[#mismatch + 1] = key end
	end
	for _, id in ipairs({ "campkit", "campobject" }) do
		local def = NS:FindCheck(id)
		if not (fr[def.advice] and en[def.advice]) then missing[#missing + 1] = "conseil:" .. id end
	end
	Check("[CAMP] chaînes et conseils en fr et en en, mêmes paramètres, lisibles via L", #missing == 0 and #mismatch == 0
		and NS.L.CHK_CAMPKIT == "Kit de feu de camp",
		table.concat(missing, ", ") .. " / " .. table.concat(mismatch, ", "))
end

-- ---------------------------------------------------------------------------
-- Contrôles avant le départ
-- ---------------------------------------------------------------------------
do
	-- sans métier ni objet : rien à dire
	Fresh()
	NS:RunChecklist("manual")
	Check("[CAMP] sans métier ni objet : kit et objet inactifs", Result("campkit").inactive == true
		and Result("campobject").inactive == true)

	-- cuisinier sans kit
	Fresh()
	SetSkills({ { "Professions", true }, { "Cuisine", false, 75 } })
	NS:RunChecklist("manual")
	local kit = Result("campkit")
	Check("[CAMP] cuisinier sans kit : actif, échec, conseil", kit and not kit.disabled and kit.ok == false
		and kit.detail == NS.L.CHK_CAMPKIT_NONE and (function()
		for _, a in ipairs(NS.lastAdvice or {}) do if a.text == NS.L.ADV_CAMPKIT then return true end end
		return false
	end)(), kit and kit.detail)

	-- cuisinier avec kits
	Fresh()
	SetSkills({ { "Cooking", false, 230 } })
	Bag({ { BASIC_KIT, 2 }, { EXPERT_KIT, 1 } })
	NS:RunChecklist("manual")
	kit = Result("campkit")
	Check("[CAMP] kits présents : réussite, nombre affiché", kit and kit.ok == true and kit.score == 100
		and kit.detail == "3 dans tes sacs", kit and kit.detail)

	-- pas cuisinier, mais un kit en sac (ramassé, échangé) : on le compte
	Fresh()
	Bag({ { BASIC_KIT, 1 } })
	NS:RunChecklist("manual")
	Check("[CAMP] kit porté sans cuisine : actif et réussi", Result("campkit").disabled ~= true and Result("campkit").ok == true)

	-- forgeron : objet de camp
	Fresh()
	SetSkills({ { "Forge", false, 50 } })
	NS:RunChecklist("manual")
	local object = Result("campobject")
	Check("[CAMP] forgeron sans objet : actif, échec", object and not object.disabled and object.ok == false
		and object.detail == NS.L.CHK_CAMPOBJ_NONE, object and object.detail)

	-- forgeron rang trop bas pour le premier palier (20) : rien à fabriquer
	Fresh()
	SetSkills({ { "Blacksmithing", false, 5 } })
	NS:RunChecklist("manual")
	Check("[CAMP] métier sous le palier 20 : objet inactif", Result("campobject").inactive == true)

	-- objet en sac, recharge prête
	Fresh()
	SetSkills({ { "Forge", false, 50 } })
	Mock.world.itemInfo[SHARPENING_WHEEL] = { name = "Meule à aiguiser" }
	Bag({ { SHARPENING_WHEEL, 1 } })
	NS:RunChecklist("manual")
	object = Result("campobject")
	Check("[CAMP] objet prêt : réussite, nom traduit par le client", object and object.ok == true and object.score == 100
		and object.detail == "Meule à aiguiser, prêt", object and object.detail)

	-- recharge partagée : un autre objet de camp vient d'être posé
	Mock.world.cooldowns = { [CAMP_TENT] = { Mock.now - 600, 3600 } }
	NS:RunChecklist("manual")
	object = Result("campobject")
	Check("[CAMP] recharge partagée en cours : échec, minutes restantes", object and object.ok == false
		and object.detail == "Meule à aiguiser, encore 50 min", object and object.detail)

	-- le GCD n'est pas une recharge
	Mock.world.cooldowns = { [SHARPENING_WHEEL] = { Mock.now, 1.5 } }
	NS:RunChecklist("manual")
	Check("[CAMP] GCD ignoré", Result("campobject").ok == true, Result("campobject").detail)

	-- objet porté sans métier connu (API de compétences absente)
	Fresh()
	_G.GetNumSkillLines = nil
	Bag({ { CAMP_TENT, 1 } })
	NS:RunChecklist("manual")
	Check("[CAMP] sans API de compétences : objet porté suffit, kit inactif", Result("campobject").disabled ~= true
		and Result("campobject").ok == true and Result("campkit").inactive == true)
	_G.GetNumSkillLines = function() return #skills end

	-- contrôle coupé par le joueur
	Fresh()
	SetSkills({ { "Cuisine", false, 75 } })
	NS:SetModuleEnabled("campkit", false)
	NS:RunChecklist("manual")
	Check("[CAMP] contrôle coupé : exclu de la note", Result("campkit").disabled == true and Result("campkit").weight == 0)
end

-- ---------------------------------------------------------------------------
-- Forever : module coupé = rien
-- ---------------------------------------------------------------------------
do
	Fresh()
	NS:DB().campEnabled = false
	SetSkills({ { "Cuisine", false, 300 }, { "Forge", false, 300 } })
	Bag({ { BASIC_KIT, 1 }, { SHARPENING_WHEEL, 1 } })
	NS:RunChecklist("manual")
	local inactive = Result("campkit").inactive == true and Result("campobject").inactive == true
	Mock.world.auras[CAMP_NEARBY] = { spellId = CAMP_NEARBY }
	Mock:Fire("UNIT_AURA", "player"); Mock:Advance(0.3)
	Mock.world.auras[BENEFITS] = { spellId = BENEFITS, expirationTime = Mock.now + 1800 }
	Mock:Reset()
	NS:OnCampDeparture({ name = "le campement", source = "camp" })
	Check("[CAMP] module coupé : contrôles inactifs, ni compte à rebours ni ligne au départ", inactive and not FrameShown()
		and not Mock:Output():find("Buffs du camp", 1, true), Mock:Output())

	-- /r2q module camp on|off
	Fresh()
	NS:HandleCommand("module camp off")
	local off = NS:DB().campEnabled == false
	NS:HandleCommand("module campement on")
	Check("[CAMP] /r2q module camp off, campement on (alias)", off and NS:DB().campEnabled == true)
end

-- ---------------------------------------------------------------------------
-- Au camp : compte à rebours discret
-- ---------------------------------------------------------------------------
do
	Fresh()
	local before = FrameShown()
	Mock.world.auras[CAMP_NEARBY] = { spellId = CAMP_NEARBY }
	Mock:Fire("UNIT_AURA", "player")
	Check("[CAMP] arrivée au camp : cadre affiché, estimation 1:00", not before and FrameShown()
		and FrameText() == "Au camp : buffs dans ~1:00", FrameText())
	Mock:Advance(18)
	Check("[CAMP] décompte : ~0:42 après 18 s", FrameText() == "Au camp : buffs dans ~0:42", FrameText())
	-- image suivante 0,1 s plus tard (horloge poussée de 5 s) : pas encore de
	-- rafraîchissement, le cadre ne se recalcule que toutes les 0,25 s
	Mock.now = Mock.now + 5
	Mock:Advance(0.1)
	Check("[CAMP] rafraîchi au plus 4 fois par seconde", FrameText() == "Au camp : buffs dans ~0:42", FrameText())
	Mock:Advance(0.2)
	Check("[CAMP] rafraîchi au tic suivant", FrameText() == "Au camp : buffs dans ~0:37", FrameText())

	-- l'aura d'accueil donne le décompte exact
	Mock.world.auras[WELCOME] = { spellId = WELCOME, expirationTime = Mock.now + 30 }
	Mock:Advance(0.3)
	Check("[CAMP] aura d'accueil : décompte exact", FrameText() == "Au camp : buffs dans 0:30", FrameText())

	-- assez attendu sans aura d'accueil : invitation à s'asseoir
	Mock.world.auras[WELCOME] = nil
	Mock:Advance(60)
	Check("[CAMP] seuil passé sans buff : invitation", FrameText() == NS.L.CAMP_TIMER_HINT, FrameText())

	-- les buffs tombent
	Mock.world.auras[BENEFITS] = { spellId = BENEFITS, expirationTime = Mock.now + 3600 }
	Mock:Fire("UNIT_AURA", "player")
	Check("[CAMP] buffs reçus : « actifs »", FrameText() and FrameText():find(NS.L.CAMP_TIMER_ACTIVE, 1, true) ~= nil, FrameText())

	-- départ du camp : cadre masqué
	Mock.world.auras[CAMP_NEARBY] = nil
	Mock:Fire("UNIT_AURA", "player")
	Check("[CAMP] quitte le camp : cadre masqué, arrivée oubliée", not FrameShown() and NS.campArrivedAt == nil)

	-- retour au camp : le décompte repart de zéro
	Mock.world.auras[BENEFITS] = nil
	Mock.world.auras[CAMP_NEARBY] = { spellId = CAMP_NEARBY }
	Mock:Advance(0.3)
	Check("[CAMP] retour au camp : décompte neuf", FrameText() == "Au camp : buffs dans ~1:00", FrameText())

	-- 1.33.3 : feu de camp dans une ville apprise : pas de décompte
	local savedMap, savedSub = Mock.world.mapID, Mock.world.subzone
	Mock.world.mapID, Mock.world.subzone = 20, "Bois"
	NS:DB().safe["c:20"] = { kind = "city", source = "resting" }
	Mock:Advance(0.3)
	Check("[CAMP] feu de camp en ville : cadre masqué, le camp reste une zone sûre", not FrameShown()
		and NS:IsCurrentZoneSafe() == true)
	NS:DB().safe["c:20"] = nil
	Mock.world.resting = true
	Mock:Advance(0.3)
	Check("[CAMP] repos seul (feu en pleine nature) : cadre affiché", FrameShown())
	Mock.world.resting = false
	Mock.world.mapID, Mock.world.subzone = savedMap, savedSub
	Mock:Advance(0.3)

	-- réglage coupé
	NS:DB().campCountdown = false
	Mock:Advance(0.3)
	local hidden = not FrameShown()
	NS:DB().campCountdown = true
	Mock:Advance(0.3)
	Check("[CAMP] réglage coupé : cadre masqué ; rallumé : de retour", hidden and FrameShown())

	-- interrupteur du module (navigation des réglages)
	NS:ToggleModuleKey("campEnabled")
	Mock:Advance(0.3)
	Check("[CAMP] interrupteur coupé : cadre masqué", NS:DB().campEnabled == false and not FrameShown())
	NS:ToggleModuleKey("campEnabled")

	-- lecture d'aura qui lève une erreur : jamais de plantage
	Mock.secretAuras = true
	local ok = pcall(function() Mock:Fire("UNIT_AURA", "player"); Mock:Advance(0.3) end)
	Check("[CAMP] auras illisibles : pas d'erreur", ok)
	Mock.secretAuras = false
end

-- ---------------------------------------------------------------------------
-- En quittant le camp : temps de buffs restant
-- ---------------------------------------------------------------------------
do
	local function LeaveCamp(buffs)
		Fresh()
		_G.UnitFactionGroup = function() return "Alliance" end
		Mock.world.mapID, Mock.world.subzone = 20, "Bois"
		Mock.world.auras[CAMP_NEARBY] = { spellId = CAMP_NEARBY }
		for spellID, remaining in pairs(buffs) do
			Mock.world.auras[spellID] = { spellId = spellID, expirationTime = Mock.now + remaining }
		end
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		Mock.now = Mock.now + 60
		Mock:Reset()
		Mock.world.auras[CAMP_NEARBY] = nil
		Mock:Fire("UNIT_AURA", "player")
		Mock:Advance(7)
		_G.UnitFactionGroup = nil
		return Mock:Output()
	end

	-- l'aura d'il y a 60 s : Camp Benefits 50 min, Boosted AP 42 min (au moment du départ)
	local out = LeaveCamp({ [BENEFITS] = 60 + 50 * 60, [BOOSTED_AP] = 60 + 42 * 60 })
	Check("[CAMP] départ du camp : source « camp », relevé exposé", NS.lastDeparture and NS.lastDeparture.source == "camp"
		and NS.lastCampDeparture and NS.lastCampDeparture.count == 2, NS.lastDeparture and NS.lastDeparture.source)
	Check("[CAMP] départ du camp : une seule ligne des buffs (le plus long)", out:find("Buffs du camp : encore 50 min.", 1, true) ~= nil
		and select(2, out:gsub("Buffs du camp", "")) == 1, out)

	out = LeaveCamp({})
	Check("[CAMP] départ sans buffs : rien", not out:find("Buffs du camp", 1, true), out)

	-- départ d'un village : pas de ligne, même avec des buffs du camp
	Fresh()
	Mock.world.auras[BENEFITS] = { spellId = BENEFITS, expirationTime = Mock.now + 1200 }
	Mock:Reset()
	NS:OnCampDeparture({ name = "Comté-de-l'Or", source = "known" })
	local village = Mock:Output()
	-- réglage coupé
	NS:DB().campDepartureLine = false
	Mock:Reset()
	NS:OnCampDeparture({ name = "le campement", source = "camp" })
	Check("[CAMP] départ d'un village, ou réglage coupé : pas de ligne", not village:find("Buffs du camp", 1, true)
		and not Mock:Output():find("Buffs du camp", 1, true), village .. Mock:Output())
	NS:DB().campDepartureLine = true

	-- Check avant le départ coupé : la ligne part quand même (DEPARTURE suit toujours)
	Fresh()
	NS:DB().departureEnabled = false
	_G.UnitFactionGroup = function() return "Alliance" end
	Mock.world.mapID, Mock.world.subzone = 20, "Bois"
	Mock.world.auras[CAMP_NEARBY] = { spellId = CAMP_NEARBY }
	Mock.world.auras[BENEFITS] = { spellId = BENEFITS, expirationTime = Mock.now + 3600 }
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	Mock:Reset()
	Mock.world.auras[CAMP_NEARBY] = nil
	Mock:Fire("UNIT_AURA", "player"); Mock:Advance(7)
	_G.UnitFactionGroup = nil
	Check("[CAMP] Check avant le départ coupé : ligne quand même", Mock:Output():find("Buffs du camp : encore 59 min.", 1, true) ~= nil, Mock:Output())

	-- en anglais
	Check("[CAMP] ligne et décompte anglais formatés", string.format(NS.CAMP_STRINGS.en.CAMP_DEPART_BUFFS, 12) == "Camp buffs: 12 min left."
		and string.format(NS.CAMP_STRINGS.en.CAMP_TIMER, "0:42") == "At camp: buffs in 0:42")
end

-- ---------------------------------------------------------------------------
-- Réglages : page construite, lignes et interrupteurs
-- ---------------------------------------------------------------------------
do
	Fresh()
	local frame = NS:EnsureOptions()
	local page = frame and frame.pages and frame.pages.camp
	local keys = {}
	for _, row in ipairs(page and page.rows or {}) do keys[#keys + 1] = tostring(row.moduleId or (row.def and row.def.key)) end
	local nav
	for _, n in ipairs(frame.navButtons) do if n.pageId == "camp" then nav = n end end
	Check("[CAMP] page construite : 2 contrôles et 2 réglages, sous-titre, interrupteur dans la navigation", page ~= nil
		and table.concat(keys, ",") == "campkit,campobject,campCountdown,campDepartureLine"
		and page.subText == NS.L.OPT_PAGE_CAMP_SUB and nav and nav.powerKey == "campEnabled", table.concat(keys, ","))
	NS.optionsFrame = nil
end

_G.GetNumSkillLines, _G.GetSkillLineInfo = savedNum, savedInfo
ResetWorld()
NS.campArrivedAt = nil
if NS.campFrame then NS.campFrame:Hide() end
