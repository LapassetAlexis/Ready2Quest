-- SpecStats.lua -- attributs qui comptent pour la classe et la spé
--
-- Restes de Stats.lua (stats du portrait et résumé de stuff, retirés en
-- 1.37.0) : la priorité des attributs par spé sert encore au choix de la
-- récompense de quête (QuestReward.lua).
local ADDON, ns = ...

-- Appelle une API en renvoyant jusqu'à quatre valeurs de retour
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d
end

-- Spécialisation : GetSpecialization sur Forever ; sur Era (pas de spés),
-- l'onglet de talents qui a reçu le plus de points. L'ordre des onglets est
-- celui des spés (Sacré, Protection, Vindicte pour le paladin).
-- GetTalentTabInfo : Era -> name, icon, pointsSpent, fileName ;
-- clients plus récents -> id, name, description, icon, pointsSpent, …
local function TalentTab(index)
	local fn = rawget(_G, "GetTalentTabInfo")
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, index) }
	if not r[1] then return nil end
	if type(r[2]) == "number" and type(r[3]) == "string" then
		return r[3], tonumber(r[6]) or 0
	end
	return r[2], tonumber(r[4]) or 0
end

local function SpecIndex()
	local index = tonumber((Call(rawget(_G, "GetSpecialization"))))
	if index and index >= 1 then return index end
	local count = tonumber((Call(rawget(_G, "GetNumTalentTabs")))) or 0
	local best, bestPoints = nil, 0
	for tab = 1, count do
		local _, points = TalentTab(tab)
		if points and points > bestPoints then best, bestPoints = tab, points end
	end
	return best
end
ns.SpecIndex = SpecIndex

-- ---------------------------------------------------------------------------
-- Attributs qui comptent, par classe et par spécialisation
-- ---------------------------------------------------------------------------
-- Chaque spécialisation ne retient QUE les attributs qui lui servent, dans
-- l'ordre de sa priorité officielle (l'Esprit ne compte pas pour un guerrier).
--
-- SOURCE : les guides de statistiques de Wowhead pour le client Forever
-- (wowhead.com/forever/guide/classes/<classe>/<spé>/stat-priority-*), relevés
-- le 2026-11-02. Les priorités complètes mêlent des statistiques secondaires
-- (toucher, expertise, hâte, spé...) qu'on ne compare pas : on n'en
-- garde que les cinq attributs primaires, et l'ordre relatif est conservé.
--
-- Deux règles de tri que la source ne dicte pas :
--  • une statistique primaire reléguée après toutes les secondaires dans la
--    liste officielle (Esprit chez un mage, par exemple) est omise : elle ne
--    fait pas partie de ce qui « compte » pour la spé ;
--  • sans mention dans la liste, l'attribut est écarté.
--
-- Les paliers de toucher (« Hit Chance jusqu'à 9 % ») ne sont pas des
-- attributs : ils n'y figurent pas.
local SPEC_STATS = {
	-- Guerrier : Force et Agilité, l'Endurance n'apparaît en protection que
	-- parce que la survie y est le métier.
	WARRIOR = {
		{ "STR", "AGI" },                       -- Armes
		{ "STR", "AGI", "STA" },                -- Fureur
		{ "STA", "AGI", "STR" },                -- Protection
	},
	-- Paladin : l'Intelligence d'abord en Sacré et en Vindicte (Champion de
	-- la Lumière la convertit en puissance des sorts), l'Endurance n'est pas
	-- listée en Sacré.
	PALADIN = {
		{ "INT", "SPI" },                       -- Sacré
		{ "STA", "AGI", "STR" },                -- Protection (spé / onglet 2)
		{ "INT", "STR", "AGI", "STA" },         -- Vindicte (spé / onglet 3)
	},
	-- Chasseur : l'Intellect nourrit le mana, donc Flèche mortelle et les
	-- tirs ; l'Esprit reste listé par les guides, en fin de liste.
	HUNTER = {
		{ "AGI", "INT", "SPI", "STA" },         -- Maîtrise
		{ "AGI", "INT", "SPI", "STA" },         -- Précision
		{ "AGI", "STR", "INT", "SPI", "STA" },  -- Survie
	},
	-- Voleur : l'Agilité donne attaque et critique ; la Force n'ajoute qu'un
	-- point d'attaque par point, d'où sa place derrière.
	ROGUE = {
		{ "AGI", "STR", "STA" },                -- Assassinat
		{ "AGI", "STR", "STA" },                -- Combat
		{ "AGI", "STR", "STA" },                -- Finesse
	},
	-- Prêtre : l'Intellect passe devant partout, l'Esprit juste après.
	PRIEST = {
		{ "INT", "SPI", "STA" },                -- Discipline
		{ "INT", "SPI", "STA" },                -- Sacré
		{ "INT", "SPI", "STA" },                -- Ombre
	},
	-- Chaman : l'Intellect d'abord pour les deux lanceurs ; l'Amélioration
	-- est à égalité Force/Intellect dans sa liste, puis l'Agilité.
	SHAMAN = {
		{ "INT", "SPI", "STR", "STA" },         -- Élémentaire
		{ "STR", "INT", "AGI", "SPI", "STA" },  -- Amélioration
		{ "INT", "SPI", "STR", "STA" },         -- Restauration
	},
	-- Mage : l'Intellect, puis l'Esprit (il alimente la régénération, même
	-- avec Armure de givre). L'Esprit n'est PAS inutile à un mage en Forever.
	MAGE = {
		{ "INT", "SPI", "STA" },                -- Arcanes
		{ "INT", "SPI", "STA" },                -- Feu
		{ "INT", "SPI", "STA" },                -- Givre (page inaccessible, aligné)
	},
	-- Démoniste : l'Esprit arrive en fin de liste mais y est.
	WARLOCK = {
		{ "INT", "SPI" },                       -- Affliction
		{ "INT", "SPI" },                       -- Démonologie
		{ "INT", "SPI" },                       -- Destruction
	},
	-- Druide : trois métiers sans rien en commun.
	DRUID = {
		{ "INT", "SPI", "STA" },                -- Équilibre
		{ "AGI", "STR", "INT", "SPI", "STA" },  -- Farouche (DPS)
		{ "SPI", "INT", "STA" },                -- Restauration
	},
}

-- Le druide Farouche est joué en ours (tank) ou en félin (DPS), et l'ordre
-- change : l'Endurance passe devant pour l'ours. On lit la forme actuelle.
local FERAL_TANK_ORDER = { "STA", "AGI", "STR" }

-- Lue par QuestReward.lua, et vérifiée classe par classe par les tests.
ns.SPEC_STATS = SPEC_STATS
ns.FERAL_TANK_ORDER = FERAL_TANK_ORDER

-- Le druide Farouche change de statistiques selon sa forme : en ours c'est
-- l'Endurance qui décide de la survie, en félin l'Agilité. On lit la forme
-- courante pour ne pas favoriser le mauvais attribut.
local function IsBearForm()
	local form = Call(GetShapeshiftForm)
	return tonumber(form) == 1
end

-- Exposé : lu par QuestReward.lua et par les tests.
ns.IsBearForm = IsBearForm

if ns.Mark then ns.Mark("SpecStats") end
