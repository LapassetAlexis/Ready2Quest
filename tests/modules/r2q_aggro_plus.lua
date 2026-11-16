-- Ready2Quest 1.36.0 : portée d'aggro plus précise (AggroPlus.lua). Paliers
-- tirés des sorts du joueur, distance estimée entre deux paliers, portée
-- apprise en jouant (un monstre qui t'attaque sans que tu aies agi).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local NAMES = { "UnitGUID", "UnitName", "UnitCreatureType", "UnitClassification", "UnitIsUnit", "UnitThreatSituation",
	"IsInGroup", "UnitAffectingCombat", "GetUnitSpeed", "GetPlayerFacing", "GetSpellInfo", "IsSpellInRange" }
local saved = {}
for _, name in ipairs(NAMES) do saved[name] = rawget(_G, name) end
saved.C_Spell, saved.NewSpellsBook = rawget(_G, "C_Spell"), NS.NewSpellsBook

local W = {}
local function Install()
	W = { guid = "Creature-0-1-1-1-1-3100-0001", speed = 0, facing = 0, target = false, group = false, pet = false,
		name = "Loup des bois", ctype = "Bête", class = "normal" }
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1" end return W.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return W.name end
	_G.UnitCreatureType = function() return W.ctype end
	_G.UnitClassification = function() return W.class end
	_G.UnitIsUnit = function(a, b) return W.target and a:find("target") ~= nil and b == "player" end
	_G.UnitThreatSituation = function() return nil end
	_G.IsInGroup = function() return W.group end
	_G.UnitAffectingCombat = function(unit) if unit == "pet" then return W.pet end return false end
	_G.GetUnitSpeed = function() return W.speed end
	_G.GetPlayerFacing = function() return W.facing end
	NS.aggroTracks, NS.aggroLastAction, NS.aggroSpellSteps, NS.aggroLadder = nil, nil, nil, nil
	NS:DB().aggroLearnData, NS:DB().aggroLearn, NS:DB().aggroEnabled = nil, true, true
end

Say("-- aggro+ : paliers des sorts")
ResetWorld()
Install()
do
	-- un sort par portée, sans portée minimale, entre 5 et 60 m
	local SPELLS = {
		["Éclair de givre"] = { id = 116, min = 0, max = 30 },
		["Boule de feu"]    = { id = 133, min = 0, max = 35 },
		["Projectile"]      = { id = 5019, min = 0, max = 30 },    -- même portée : un seul gardé
		["Tir automatique"] = { id = 75, min = 8, max = 35 },       -- portée minimale : écarté
		["Contact"]         = { id = 999, min = 0, max = 3 },       -- trop court
		["Signal lointain"] = { id = 998, min = 0, max = 100 },     -- trop long
	}
	local byID, inRange = {}, {}
	for name, s in pairs(SPELLS) do byID[s.id] = { name = name, minRange = s.min, maxRange = s.max } end
	NS.NewSpellsBook = function()
		local book = {}
		for name, s in pairs(SPELLS) do book[name] = { id = s.id, rank = 1 } end
		return book
	end
	_G.C_Spell = { GetSpellInfo = function(id) return byID[id] end,
		IsSpellInRange = function(id, unit) return inRange[id] end }
	local steps = NS:AggroSpellSteps()
	local ranges = {}
	for _, step in ipairs(steps) do ranges[#ranges + 1] = step.range end
	inRange[116], inRange[5019], inRange[133] = false, false, true
	local test30 = steps[1] and steps[1].test("nameplate1")
	inRange[116], inRange[5019] = nil, nil
	local silent = steps[1] and steps[1].test("nameplate1")
	-- le grimoire change : relus
	SPELLS["Trait de sorcier"] = { id = 777, min = 0, max = 20 }
	byID[777] = { name = "Trait de sorcier", minRange = 0, maxRange = 20 }
	local before = NS:AggroSpellSteps()
	NS:AggroSpellsChanged()
	local after = NS:AggroSpellSteps()
	Check("[AGGRO+] sorts : un palier par portée (30, 35), sans portée minimale, entre 5 et 60 m ; relus quand le grimoire change",
		table.concat(ranges, ",") == "30,35" and test30 == false and silent == nil and #before == 2 and #after == 3
		and after[1].range == 20 and NS.aggroLadder == nil, table.concat(ranges, ","))
	NS.NewSpellsBook, _G.C_Spell = saved.NewSpellsBook, saved.C_Spell
	NS.aggroSpellSteps = nil
end

Say("-- aggro+ : distance estimée entre deux paliers")
ResetWorld()
Install()
do
	local u = "nameplate1"
	local est1, sure1 = NS:AggroTrack(u, 20, 25, 20, 20)
	-- il avance : palier franchi vers le monstre -> sur la nouvelle borne haute (un
	-- demi-mètre en dedans : l'estimation reste dans la fourchette)
	Mock:Advance(0.2)
	local est2, sure2 = NS:AggroTrack(u, 15, 20, 20, 20)
	-- il court 1 s tout droit à 7 m/s : moitié comptée -> 3,5 m de moins (16)
	W.speed = 7
	Mock:Advance(1)
	local est3 = NS:AggroTrack(u, 15, 20, 20, 20)
	-- il tourne : l'estimation est tenue
	W.facing = 2
	Mock:Advance(1)
	local est4 = NS:AggroTrack(u, 15, 20, 20, 20)
	Mock:Advance(1)
	local est5 = NS:AggroTrack(u, 15, 20, 20, 20)
	-- jamais hors de la fourchette
	local guard = true
	W.facing, W.speed = 2, 50
	NS.aggroTracks[u].dir, NS.aggroTracks[u].face = -1, 2
	Mock:Advance(2)
	local low = NS:AggroTrack(u, 15, 20, 20, 20)
	if low < 15.5 - 1e-6 then guard = false end
	-- autre monstre sous le même jeton, au-delà du dernier palier, sans GUID : rien
	W.guid = "Creature-0-1-1-1-1-3200-0002"
	local _, sureNew = NS:AggroTrack(u, 15, 20, 20, 20)
	local beyond = NS:AggroTrack(u, 35, nil, 20, 20)
	W.guid = nil
	local noGuid = NS:AggroTrack(u, 15, 20, 20, 20)
	Check("[AGGRO+] estimation : milieu d'abord, palier franchi = borne, avance à la moitié de la vitesse, tenue s'il tourne",
		est1 == 22.5 and not sure1 and est2 == 19.5 and sure2 and math.abs(est3 - 16) < 1e-6
		and math.abs(est4 - 16) < 1e-6 and math.abs(est5 - 16) < 1e-6,
		table.concat({ tostring(est1), tostring(est2), tostring(est3), tostring(est4), tostring(est5) }, " / "))
	Check("[AGGRO+] estimation bornée à la fourchette ; autre monstre, au-delà ou sans GUID : pas de piste sûre",
		guard and sureNew == false and beyond == nil and noGuid == nil)
end

Say("-- aggro+ : portée apprise")
ResetWorld()
Install()
do
	local u = "nameplate1"
	local function Prime(est, level)
		NS.aggroTracks = {}
		NS:AggroTrack(u, 20, 25, 20, level or 20)
		Mock:Advance(0.1)
		NS:AggroTrack(u, 10, 20, 20, level or 20)
		NS.aggroTracks[u].est = est
	end
	-- seul, sans avoir agi, le loup t'attaque : un échantillon
	W.target = true
	Prime(14)
	local first = NS:AggroLearnOnCombat()
	local afterOne = NS:AggroLearnedRadius(u, 20, 20)
	Prime(16)
	NS:AggroLearnOnCombat()
	local named = NS:AggroLearnedRadius(u, 20, 20)
	local higher = NS:AggroLearnedRadius(u, 20, 23)     -- 3 niveaux de plus : +3 m
	-- un autre monstre du même type : la liste du type attend 3 échantillons
	W.name = "Sanglier"
	local typeShort = NS:AggroLearnedRadius(u, 20, 20)
	-- refus : action récente, groupe, familier en combat, réglage coupé, valeur aberrante, il ne t'attaque pas
	local refused = {}
	W.name = "Loup des bois"
	Prime(15); NS:AggroMarkAction()
	if NS:AggroLearnOnCombat() then refused[#refused + 1] = "action" end
	Mock:Advance(5)
	Prime(15); W.group = true
	if NS:AggroLearnOnCombat() then refused[#refused + 1] = "groupe" end
	W.group = false
	Prime(15); W.pet = true
	if NS:AggroLearnOnCombat() then refused[#refused + 1] = "familier" end
	W.pet = false
	Prime(19.5)
	NS.aggroTracks[u].est = 40
	if NS:AggroLearnOnCombat() then refused[#refused + 1] = "aberrant" end
	Prime(15); W.target = false
	if NS:AggroLearnOnCombat() then refused[#refused + 1] = "pas lui" end
	W.target = true
	NS:DB().aggroLearn = false
	Prime(15)
	if NS:AggroLearnOnCombat() then refused[#refused + 1] = "coupé" end
	local offRadius = NS:AggroLearnedRadius(u, 20, 20)
	NS:DB().aggroLearn = true
	local q = NS.AggroQuantile({ 10, 20 }, 0.65)
	Check("[AGGRO+] apprise : un échantillon quand un monstre t'attaque seul ; par nom dès 2, 65e centile, +1 m par niveau",
		first == 14 and afterOne == nil and math.abs(named - 15.3) < 1e-6 and math.abs(higher - 18.3) < 1e-6
		and typeShort == nil and math.abs(q - 16.5) < 1e-6 and NS:AggroLearnCount() == 2,
		table.concat({ tostring(first), tostring(afterOne), tostring(named), tostring(higher), tostring(typeShort) }, " / "))
	Check("[AGGRO+] apprise : rien après une action, en groupe, familier en combat, valeur aberrante, s'il ne t'attaque pas, réglage coupé",
		#refused == 0 and offRadius == nil and NS:AggroLearnCount() == 2, table.concat(refused, ", "))
	-- la portée apprise passe dans l'infobulle et le verdict (marquée d'une étoile)
	NS:AggroLearnReset()
	Check("[AGGRO+] remise à zéro des données apprises", NS:AggroLearnCount() == 0 and NS:AggroLearnedRadius(u, 20, 20) == nil)
end

for _, name in ipairs(NAMES) do _G[name] = saved[name] end
_G.C_Spell, NS.NewSpellsBook = saved.C_Spell, saved.NewSpellsBook
NS.aggroTracks, NS.aggroLastAction, NS.aggroSpellSteps, NS.aggroLadder = nil, nil, nil, nil
NS:DB().aggroLearnData = nil
ResetWorld()
