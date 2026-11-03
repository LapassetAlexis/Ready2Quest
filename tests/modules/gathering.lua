-- Carnet : récolte selon le métier (Gathering.lua + GatheringData.lua, v1.25.0).
-- Table des ressources, détection des métiers et du rang, tranche de
-- compétence, butin du joueur compté (et pas celui des autres), zone retenue,
-- objectif + survol, part de complétion de zone, sans métier, par personnage,
-- interrupteur du module, robustesse.
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
local saved, MOCKED = {}, { "GetNumSkillLines", "GetSkillLineInfo", "IsInInstance", "UnitName",
	"LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }
for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
-- Ces tests couvrent le comportement 100 % dynamique (zone absente des tables
-- livrées, comme sur Forever) : tables mises de côté, remises à la fin.
-- Les zones préremplies sont testées dans zone_data.lua.
saved.ZONE_CREATURES, saved.ZONE_GATHERING = rawget(NS, "ZONE_CREATURES"), rawget(NS, "ZONE_GATHERING")
NS.ZONE_CREATURES, NS.ZONE_GATHERING = nil, nil

local G = { skills = {}, instance = false, char = "Testeur" }
_G.GetNumSkillLines = function() return #G.skills end
-- name, isHeader, isExpanded, skillRank
_G.GetSkillLineInfo = function(index)
	local s = G.skills[index]
	if not s then return nil end
	return s[1], s[2] == true, s[3] ~= false, s[4] or 0
end
_G.IsInInstance = function() return G.instance == true, G.instance and "party" or "none" end
_G.UnitName = function() return G.char end
_G.LOOT_ITEM_SELF = "Vous recevez le butin : %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "Vous recevez le butin : %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "Vous recevez l'objet : %s."
_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "Vous recevez l'objet : %sx%d."

local MAPS = {
	[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
	[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 },
	[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
}

local HEADER = { "Professions", true, true }
function G.Fresh(skills)
	ResetWorld()
	for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
	Mock.world.mapID = 1413
	Mock.world.level = 30
	G.skills, G.instance, G.char = skills or {}, false, "Testeur"
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
	NS.journalFrame = nil
end
function G.Link(itemID, name) return "|cffffffff|Hitem:" .. itemID .. "::::::::|h[" .. (name or "Objet") .. "]|h|r" end
function G.Loot(itemID, count)
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. G.Link(itemID) .. (count and ("x" .. count) or "") .. ".")
end
function G.Find(prefix)
	for _, goal in ipairs(NS:JournalObjectives()) do
		if goal.id:sub(1, #prefix) == prefix then return goal end
	end
end
function G.Ids(band)
	local out = {}
	for _, entry in ipairs(band) do out[#out + 1] = tostring(entry.itemID) end
	return table.concat(out, ",")
end
function G.Part()
	for _, def in ipairs(NS.ZONE_PARTS or {}) do if def.id == "gathering" then return def end end
end
local HERB_120 = { HEADER, { "Herboristerie", false, true, 120 }, { "Minage", false, true, 80 }, { "Couture", false, true, 50 } }

-- ---------------------------------------------------------------------------
-- Table des ressources
-- ---------------------------------------------------------------------------
do
	local items, profs = NS.GATHERING_ITEMS, NS.GATHERING_PROFESSIONS
	local bad, perProf = {}, {}
	for itemID, entry in pairs(items or {}) do
		local ok = type(itemID) == "number" and itemID > 0 and profs[entry.prof] ~= nil
			and type(entry.req) == "number" and type(entry.gray) == "number" and entry.req >= 1 and entry.req < entry.gray
			and type(entry.fr) == "string" and entry.fr ~= "" and type(entry.en) == "string" and entry.en ~= ""
		if not ok then bad[#bad + 1] = tostring(itemID) end
		perProf[entry.prof] = (perProf[entry.prof] or 0) + 1
	end
	Check("[GTH] table : chaque entrée a métier, requise < grise, noms fr/en", items and #bad == 0, table.concat(bad, ","))
	Check("[GTH] table : les trois métiers fournis", (perProf.herbalism or 0) >= 25 and (perProf.mining or 0) >= 10
		and (perProf.skinning or 0) >= 8, string.format("%s/%s/%s", tostring(perProf.herbalism), tostring(perProf.mining), tostring(perProf.skinning)))
	Check("[GTH] table : repères (Pacifique, Lotus noir, cuivre, thorium, cuir épais)",
		items[2447].en == "Peacebloom" and items[2447].req == 1 and items[13468].fr == "Lotus noir" and items[13468].req == 300
		and items[2770].prof == "mining" and items[10620].req == 245 and items[4304].fr == "Cuir épais")
	Check("[GTH] table : herbes et gisements gris à requise + 100", items[3369].gray == 220 and items[2771].gray == 165)
	-- chaînes : mêmes clés et mêmes jokers dans les deux langues
	local fr, en, mismatch = NS.GATHERING_STRINGS.fr, NS.GATHERING_STRINGS.en, {}
	local function Jokers(text) local out = {} for j in tostring(text):gmatch("%%[sd]") do out[#out + 1] = j end return table.concat(out) end
	for key, value in pairs(fr) do
		if en[key] == nil or Jokers(value) ~= Jokers(en[key]) then mismatch[#mismatch + 1] = key end
	end
	for key in pairs(en) do if fr[key] == nil then mismatch[#mismatch + 1] = key end end
	Check("[GTH] chaînes fr/en : mêmes clés, mêmes %s", #mismatch == 0, table.concat(mismatch, ","))
end

-- ---------------------------------------------------------------------------
-- Métiers et tranche
-- ---------------------------------------------------------------------------
do
	G.Fresh(HERB_120)
	local found = NS:GatheringProfessions()
	Check("[GTH] métiers : herboristerie et minage lus avec leur rang, couture ignorée", found.herbalism == 120 and found.mining == 80
		and found.skinning == nil and found.tailoring == nil)
	G.skills = { HEADER, { "Skinning", false, true, 42 } }
	found = NS:GatheringProfessions()
	Check("[GTH] métiers : nom anglais reconnu", found.skinning == 42 and found.herbalism == nil)
	G.skills = { HEADER, { "  MINAGE ", false, true, 3 } }
	Check("[GTH] métiers : casse et espaces ignorés", NS:GatheringProfessions().mining == 3)
	G.skills = { HEADER, { "Dépeçage", false, true, 7 } }
	Check("[GTH] métiers : Dépeçage accentué", NS:GatheringProfessions().skinning == 7)
	-- catégorie repliée : le dernier rang connu sert
	G.skills = HERB_120
	NS:GatheringProfessions()
	G.skills = { { "Professions", true, false } }
	found = NS:GatheringProfessions()
	Check("[GTH] catégorie repliée : dernier rang connu", found.herbalism == 120 and found.mining == 80)
	-- dépliée et sans le métier : oublié (désappris)
	G.skills = { HEADER, { "Minage", false, true, 81 } }
	found = NS:GatheringProfessions()
	Check("[GTH] métier désappris : oublié", found.herbalism == nil and found.mining == 81)

	local band, low = NS:GatheringBand("herbalism", 120)
	Check("[GTH] tranche 120 : de Mage royal à Tombeline, gris exclus", G.Ids(band) == "785,2450,3820,2453,3355,3369" and low == 120,
		G.Ids(band) .. " low=" .. tostring(low))
	band, low = NS:GatheringBand("herbalism", 101)
	Check("[GTH] bornes : grise exclue (Pacifique grise à 101), requise incluse", G.Ids(band) == "2449,785,2450,3820,2453" and low == 100,
		G.Ids(band) .. " low=" .. tostring(low))
	band, low = NS:GatheringBand("mining", 80)
	Check("[GTH] tranche minage 80 : minerais et pierres", #band == 5 and low == 75, G.Ids(band))
	band = NS:GatheringBand("herbalism", nil)
	Check("[GTH] tranche sans rang : vide", #band == 0)
	band, low = NS:GatheringBand("herbalism", 100)
	Check("[GTH] bornes : requise atteinte = incluse (Doulourante à 100)", band[#band].itemID == 2453 and low == 100 and #band == 7)
	Check("[GTH] nom : repli français sans cache client", NS:GatheringItemName(785) == "Mage royal")
	Mock.world.itemInfo[785] = { name = "Mage royal (client)" }
	Check("[GTH] nom : celui du client s'il le connaît", NS:GatheringItemName(785) == "Mage royal (client)")
end

-- ---------------------------------------------------------------------------
-- Butin
-- ---------------------------------------------------------------------------
do
	G.Fresh(HERB_120)
	G.Loot(785)
	local data = NS:GatheringData()
	Check("[GTH] butin : ressource comptée, zone retenue", data[785] and data[785].count == 1 and data[785].zones[1413] == 1)
	G.Loot(785, 3)
	Check("[GTH] butin multiple : quantité ajoutée", data[785].count == 4 and data[785].zones[1413] == 4)
	Mock.world.mapID = 1429
	G.Loot(785)
	Check("[GTH] autre zone : retenue à part", data[785].zones[1429] == 1 and data[785].zones[1413] == 4 and data[785].count == 5)
	Mock:Fire("CHAT_MSG_LOOT", "Bob reçoit le butin : " .. G.Link(2450) .. ".")
	Check("[GTH] butin d'un autre joueur : ignoré", data[2450] == nil)
	G.Loot(2000)
	Check("[GTH] objet hors table : ignoré", data[2000] == nil)
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez l'objet : " .. G.Link(2450) .. ".")
	Check("[GTH] objet reçu (achat, quête) : pas une récolte", data[2450] == nil)
	G.Loot(2318)
	Check("[GTH] ressource d'un métier inconnu (cuir sans dépeçage) : ignorée", data[2318] == nil)
	G.instance = true
	G.Loot(2770)
	Check("[GTH] en instance : compté, sans zone", data[2770] and data[2770].count == 1 and next(data[2770].zones) == nil)
	G.instance = false
	Check("[GTH] repli anglais reconnu", NS:GatheringParseLoot("You receive loot: " .. G.Link(2771) .. "x2.") == 2771)
	Check("[GTH] message vide ou étranger : rien", NS:GatheringParseLoot(nil) == nil and NS:GatheringParseLoot("bonjour") == nil)
end

-- ---------------------------------------------------------------------------
-- Objectifs et survol
-- ---------------------------------------------------------------------------
do
	G.Fresh(HERB_120)
	G.Loot(785)
	local goal = G.Find("gather:herbalism:")
	Check("[GTH] objectif : id stable, libellé, progression", goal and goal.id == "gather:herbalism:120"
		and goal.label == "Récolte à ton niveau : Herboristerie" and goal.progress == "1/6" and goal.unit == "ressources",
		goal and (goal.id .. " " .. goal.label .. " " .. goal.progress))
	local hint = goal and table.concat(goal.hint, " | ") or ""
	Check("[GTH] objectif : survol liste les manquantes avec leur compétence", hint:find("À récolter à ta compétence :", 1, true)
		and hint:find("Églantine (70)", 1, true) and hint:find("Tombeline (120)", 1, true) and not hint:find("Mage royal", 1, true), hint)
	Check("[GTH] objectif : ligne d'aide minicarte", hint:find("Découverte d'herbes", 1, true) ~= nil, hint)
	local mining = G.Find("gather:mining:")
	Check("[GTH] un objectif par métier de récolte", mining and mining.id == "gather:mining:75" and mining.progress == "0/5"
		and table.concat(mining.hint, " "):find("Découverte de gisements", 1, true), mining and mining.id)
	local tip = NS:ShowJournalGoalTooltip(UIParent, goal)
	local text = tip and table.concat(tip.lines or {}, " | ") or ""
	Check("[GTH] bulle du carnet : unité et noms", text:find("1/6 ressources", 1, true) and text:find("Doulourante (100)", 1, true), text)
	tip:Hide()
	-- haut niveau : liste coupée
	G.skills = { HEADER, { "Herboristerie", false, true, 300 } }
	goal = G.Find("gather:herbalism:")
	hint = goal and table.concat(goal.hint, " | ") or ""
	Check("[GTH] 300 : borne basse 300, 13 herbes, liste coupée à 6", goal and goal.id == "gather:herbalism:300"
		and goal.need == 13 and hint:find("… et 7 autres", 1, true), hint)
	-- tout récolté : objectif atteint, disparu
	G.skills = HERB_120
	for _, entry in ipairs((NS:GatheringBand("herbalism", 120))) do G.Loot(entry.itemID) end
	Check("[GTH] tranche complète : plus d'objectif", G.Find("gather:herbalism:") == nil)
	-- masquage par id (contrat du carnet)
	NS:JournalDismiss("gather:mining:75", true)
	Check("[GTH] objectif masquable", G.Find("gather:mining:").dismissed == true)
	-- nouvelle ressource dans la tranche : nouvel id, de retour
	G.skills = { HEADER, { "Minage", false, true, 125 } }
	Check("[GTH] nouvelle ressource dans la tranche : nouvel id visible", G.Find("gather:mining:").id == "gather:mining:125"
		and not G.Find("gather:mining:").dismissed)
end

-- ---------------------------------------------------------------------------
-- Part de complétion de zone
-- ---------------------------------------------------------------------------
do
	G.Fresh(HERB_120)
	local part = G.Part()
	Check("[GTH] part « gathering » enregistrée", part and part.label == "JRN_PART_gathering" and NS.L.JRN_PART_gathering == "Récolte")
	G.Loot(785); G.Loot(2770)
	Mock.world.mapID = 1429
	G.Loot(2450)
	local tarides = part.Compute(NS, 1413)
	Check("[GTH] part : ressources récoltées dans la zone / tranches réunies", tarides and tarides.have == 2 and tarides.need == 11,
		tarides and (tarides.have .. "/" .. tarides.need))
	local hint = tarides and table.concat(tarides.hint, " | ") or ""
	Check("[GTH] part : survol concret (zone, manquantes, aide)", hint:find("dans Les Tarides", 1, true)
		and hint:find("Églantine (70)", 1, true) and hint:find("Découverte de gisements", 1, true), hint)
	local elwynn = part.Compute(NS, 1429)
	Check("[GTH] part : autre zone comptée à part", elwynn and elwynn.have == 1 and elwynn.need == 11)
	Check("[GTH] part : zone inconnue -> rien récolté", part.Compute(NS, 4242).have == 0 and part.Compute(NS, nil) == nil)
	G.skills = { HEADER, { "Herboristerie", false, true, 120 } }
	for _, entry in ipairs((NS:GatheringBand("herbalism", 120))) do NS:GatheringRecord(entry.itemID, 1, 1413) end
	local done = part.Compute(NS, 1413)
	Check("[GTH] part complète : message de fin", done.have == 6 and done.need == 6 and done.hint[1]:find("Toutes", 1, true), done.hint[1])
end

-- ---------------------------------------------------------------------------
-- Sans métier, par personnage, interrupteur, robustesse
-- ---------------------------------------------------------------------------
do
	G.Fresh({ HEADER, { "Couture", false, true, 50 } })
	G.Loot(785)
	Check("[GTH] sans métier : butin non compté", NS:GatheringData()[785] == nil)
	Check("[GTH] sans métier : aucun objectif", G.Find("gather:") == nil)
	Check("[GTH] sans métier : pas de part", G.Part().Compute(NS, 1413) == nil)
	G.skills = {}
	Check("[GTH] fenêtre vide : rien", next(NS:GatheringProfessions()) == nil and G.Find("gather:") == nil)

	-- par personnage
	G.Fresh(HERB_120)
	G.Loot(785)
	G.char = "Autre"
	Check("[GTH] autre personnage : carnet de récolte vierge", NS:GatheringData()[785] == nil
		and G.Find("gather:herbalism:").progress == "0/6")
	G.Loot(2450)
	G.char = "Testeur"
	Check("[GTH] retour au premier : sa récolte intacte, pas celle de l'autre", NS:GatheringData()[785].count == 1
		and NS:GatheringData()[2450] == nil)
	Check("[GTH] rangé dans les données du carnet", NS:JournalData().gathering == NS:GatheringData())

	-- interrupteur du Compagnon (même module que le carnet)
	NS:DB().companionEnabled = false
	G.Loot(2450)
	Check("[GTH] module coupé : butin non compté", NS:GatheringData()[2450] == nil)
	Check("[GTH] module coupé : ni objectif ni part", G.Find("gather:") == nil and G.Part().Compute(NS, 1413) == nil)
	NS:DB().companionEnabled = true
	G.Loot(2450)
	Check("[GTH] module rallumé : compté", NS:GatheringData()[2450] ~= nil)
	NS:DB().enabled = false
	Check("[GTH] addon coupé : rien", G.Find("gather:") == nil)
	NS:DB().enabled = true

	-- API en panne : jamais d'erreur
	_G.GetSkillLineInfo = function() error("panne") end
	local ok, found = pcall(NS.GatheringProfessions, NS)
	Check("[GTH] GetSkillLineInfo en panne : pas d'erreur", ok and next(found) == nil)
	_G.GetNumSkillLines = function() return "?" end
	ok, found = pcall(NS.GatheringProfessions, NS)
	Check("[GTH] GetNumSkillLines incohérent : pas d'erreur", ok and next(found) == nil)
	_G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
	ok, found = pcall(NS.GatheringProfessions, NS)
	Check("[GTH] API absente : pas de métier, pas d'erreur", ok and next(found) == nil)
	local before = #(NS.errors or {})
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. G.Link(785) .. ".")
	Mock:Fire("SKILL_LINES_CHANGED")
	Check("[GTH] événements sans API : aucune erreur", #(NS.errors or {}) == before)
	Check("[GTH] enregistrement hors table : refusé", NS:GatheringRecord(2000, 1, 1413) == nil)
end

-- ipairs sur la liste : une globale absente avant (nil) doit le redevenir
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
NS.ZONE_CREATURES, NS.ZONE_GATHERING = saved.ZONE_CREATURES, saved.ZONE_GATHERING
if NS.journalTracker then NS.journalTracker:Hide() end
NS.journalTracker = nil
