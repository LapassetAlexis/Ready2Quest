-- Module « Portée d'aggro » : formule, verdicts, distance par paliers,
-- touche, combat, infobulle, anneaux des barres de nom, diag.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local NAMES = { "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitCanAttack", "UnitCreatureType", "UnitReaction",
	"IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "InCombatLockdown", "UnitAffectingCombat",
	"C_NamePlate", "CheckInteractDistance", "UnitLevel" }
local saved = {}
for _, name in ipairs(NAMES) do saved[name] = rawget(_G, name) end
saved.inRange = C_Item.IsItemInRange

local A = { W = {} }   -- une seule locale pour les aides
-- portée de chaque objet du barème, d'après la table du module
A.itemRange = {}
for _, step in ipairs(NS.AGGRO_RANGE_ITEMS) do
	for _, itemID in ipairs(step[2]) do A.itemRange[itemID] = step[1] end
end

local function Unit(unit) return A.W.units[unit] end
function A.Install()
	_G.UnitExists = function(unit) return unit == "player" or Unit(unit) ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" or (Unit(unit) and Unit(unit).player) or false end
	_G.UnitIsDead = function(unit) return Unit(unit) and Unit(unit).dead or false end
	_G.UnitCanAttack = function(_, unit) return Unit(unit) ~= nil and not Unit(unit).friendly end
	_G.UnitCreatureType = function(unit) return Unit(unit) and Unit(unit).creature or "Humanoïde" end
	_G.UnitReaction = function(unit) return Unit(unit) and Unit(unit).reaction or 2 end
	_G.UnitLevel = function(unit)
		if unit == "player" then return A.W.level end
		return Unit(unit) and Unit(unit).level
	end
	_G.IsShiftKeyDown = function() return A.W.shift == true end
	_G.IsControlKeyDown = function() return A.W.ctrl == true end
	_G.IsAltKeyDown = function() return A.W.alt == true end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function(unit) return unit == "player" and A.W.combat == true end
	C_Item.IsItemInRange = function(itemID, unit)
		if A.W.noItems then return nil end
		local u, range = Unit(unit), A.itemRange[itemID]
		if not u or not u.dist or not range then return nil end
		-- 1.31.0 : paliers muets (objets absents du client classique)
		if A.W.silent and A.W.silent[range] then return nil end
		return u.dist <= range
	end
	_G.CheckInteractDistance = function(unit, index)
		local u = Unit(unit)
		if not u or not u.dist or not A.W.interact then return nil end
		return u.dist <= ({ [3] = 10, [4] = 28 })[index]
	end
	_G.C_NamePlate = {
		GetNamePlateForUnit = function(unit) return A.W.plates[unit] end,
		GetNamePlates = function()
			local list = {}
			for _, plate in pairs(A.W.plates) do list[#list + 1] = plate end
			return list
		end,
	}
end

-- fresh : sauvegarde neuve (défauts) ; sinon le mode « Maj » d'avant la
-- 1.31.0, celui des tests historiques (le mode « danger seul » a les siens)
function A.Reset(fresh)
	ResetWorld()
	if not fresh then NS:DB().aggroKey, NS:DB().aggroKeySchema = "shift", 2 end
	A.W = { level = 20, units = {}, plates = {} }
	A.Install()
	NS.aggroPlates, NS.aggroRings, NS.aggroScanned, NS.aggroShowing, NS.aggroMeasured = {}, {}, nil, nil, nil
	NS.aggroSteps = nil
	-- mesures fraîches à chaque appel : les tests déplacent les monstres sans
	-- faire avancer l'horloge (le cache a son propre test, à la fin)
	NS.aggroDistCache, NS.AGGRO_DISTANCE_CACHE = nil, 0
	GameTooltip:ClearLines()
end
function A.Mob(unit, level, dist, extra)
	local mob = { level = level, dist = dist }
	for k, v in pairs(extra or {}) do mob[k] = v end
	A.W.units[unit] = mob
	return mob
end
function A.Plate(unit)
	local plate = CreateFrame("Frame", "NamePlate_" .. unit)
	plate.namePlateUnitToken = unit
	A.W.plates[unit] = plate
	Mock:Fire("NAME_PLATE_UNIT_ADDED", unit)
	return plate
end
function A.Ring(unit)
	local plate = A.W.plates[unit]
	return plate and NS.aggroRings[plate]
end
function A.RingShown(unit) local ring = A.Ring(unit); return ring ~= nil and ring:IsShown() == true end
function A.Tip() return table.concat(GameTooltip.lines or {}, "\n") end

-- 1. Chaînes, module, page -----------------------------------------------------
do
	Say("-- aggro : chaînes, module, réglages")
	A.Reset(true)
	local strings = NS.AGGRO_STRINGS
	local missing = {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" then missing[#missing + 1] = "en:" .. key end
		if NS.L[key] ~= value then missing[#missing + 1] = "fr:" .. key end
		local function Specs(text)
			local list = {}
			for spec in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = spec end
			return table.concat(list, ",")
		end
		if Specs(value) ~= Specs(strings.en[key] or "") then missing[#missing + 1] = "spec:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then missing[#missing + 1] = "fr?" .. key end end
	Check("[AGGRO] chaînes en français et en anglais, mêmes placeholders", #missing == 0, table.concat(missing, ", "))
	Check("[AGGRO] Aggro.lua chargé", NS.Loaded.Aggro == true)
	Check("[AGGRO] module « aggro » inscrit", NS:FindModule("aggro") and NS:FindModule("aggro").key == "aggroEnabled"
		and NS:FindModule("portee") ~= nil)
	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "aggro" then page = def end end
	Check("[AGGRO] sous-page du QoL, 5 réglages (dont le style de marque)", page and page.parent == "qol" and page.group == "OPT_GROUP_QOL"
		and #page.rows == 5 and page.rows[5].key == "aggroStyle")
	local db = NS:DB()
	Check("[AGGRO] défauts : actif, danger seul, infobulle, anneaux", db.aggroEnabled == true and db.aggroKey == "alert"
		and NS:AggroKey() == "alert" and db.aggroTooltip == true and db.aggroRings == true)
	local choices = NS:AggroKeyChoices()
	Check("[AGGRO] cinq choix, « danger seul » en premier", #choices == 5 and choices[1].value == "alert"
		and choices[1].label == "Danger seul (tout avec Maj)" and choices[2].value == "shift" and choices[5].value == "always")
	Check("[AGGRO] réglage nommé « Affichage »", NS.L.OPT_AGGRO_KEY == "Affichage" and NS.AGGRO_STRINGS.en.OPT_AGGRO_KEY == "Display")
	NS:AggroSetKey("n'importe quoi")
	Check("[AGGRO] touche inconnue refusée", NS:AggroKey() == "alert")
	db.aggroKey = "n'importe quoi"
	Check("[AGGRO] valeur inconnue en sauvegarde : repli « danger seul »", NS:AggroKey() == "alert")
	-- la liste déroulante des réglages : choisir, puis relire
	page.rows[2].choose("ctrl")
	Check("[AGGRO] choix de la liste enregistré", db.aggroKey == "ctrl" and page.rows[2].current() == "ctrl")
	db.aggroKey = "alert"

	-- 1.31.0 : migration, une fois : Maj (ancien défaut) -> danger seul
	db.aggroKey, db.aggroKeySchema = "shift", nil
	Check("[AGGRO] migration : Maj devient « danger seul »", NS:AggroKey() == "alert" and db.aggroKey == "alert"
		and db.aggroKeySchema == 2)
	NS:AggroSetKey("shift")
	Check("[AGGRO] migration : Maj rechoisi ensuite est gardé", NS:AggroKey() == "shift" and NS:AggroKey() == "shift")
	db.aggroKey, db.aggroKeySchema = "ctrl", nil
	Check("[AGGRO] migration : Ctrl gardé", NS:AggroKey() == "ctrl" and db.aggroKeySchema == 2)
	db.aggroKey, db.aggroKeySchema = "always", nil
	Check("[AGGRO] migration : « toujours » gardé", NS:AggroKey() == "always")
	db.aggroKey = "alert"
end

-- 2. Formule et verdicts -------------------------------------------------------
do
	Say("-- aggro : portée estimée")
	local R = NS.AggroRadius
	Check("[AGGRO] niveau égal : 20", R(20, 20) == 20)
	Check("[AGGRO] joueur 5 niveaux au-dessus : 15", R(25, 20) == 15)
	Check("[AGGRO] joueur 5 niveaux en dessous : 25", R(20, 25) == 25)
	Check("[AGGRO] borné à 5", R(60, 1) == 5, R(60, 1))
	Check("[AGGRO] borné à 45", R(1, 60) == 45, R(1, 60))
	Check("[AGGRO] niveau « ?? » : dix de plus", R(30, -1) == 30, R(30, -1))
	Check("[AGGRO] niveau illisible : rien", R(nil, 20) == nil and R(20, nil) == nil)

	local V = NS.AggroVerdict
	Check("[AGGRO] 10-15 m pour 17 : rouge", V(17, 10, 15) == "red")
	-- 1.30.0 : le rouge prévient 5 m avant la portée, l'ambre jusqu'à 12 m au-delà
	Check("[AGGRO] 15-20 m pour 17 : rouge (à moins de 5 m du bord, on prévient)", V(17, 15, 20) == "red")
	-- 1.31.0 : la borne basse décide (20 < 17 + 5 : on PEUT être trop près)
	Check("[AGGRO] 20-25 m pour 17 : rouge (borne basse)", V(17, 20, 25) == "red")
	Check("[AGGRO] 20-28 m pour 20 : rouge (pas de palier entre 20 et 28)", V(20, 20, 28) == "red")
	Check("[AGGRO] 28-30 m pour 20 : ambre", V(20, 28, 30) == "amber")
	Check("[AGGRO] 35 m et plus pour 20 : vert", V(20, 35, nil) == "green")
	Check("[AGGRO] 25-30 m pour 17 : ambre (moins de 12 m de marge)", V(17, 25, 30) == "amber")
	Check("[AGGRO] 30-35 m pour 17 : vert", V(17, 30, 35) == "green")
	Check("[AGGRO] moins de 5 m : rouge", V(5, 0, 5) == "red")
	Check("[AGGRO] au-delà de 80 m : vert", V(45, 80, nil) == "green")
	Check("[AGGRO] sans mesure : pas de verdict", V(20, nil, nil) == nil)
end

-- 3. Distance par paliers ------------------------------------------------------
do
	Say("-- aggro : distance")
	A.Reset()
	A.Mob("nameplate1", 20, 22)
	local low, high = NS:AggroDistance("nameplate1")
	Check("[AGGRO] 22 m : entre 20 et 25", low == 20 and high == 25, tostring(low) .. "-" .. tostring(high))
	A.Mob("nameplate1", 20, 3)
	low, high = NS:AggroDistance("nameplate1")
	Check("[AGGRO] 3 m : moins de 5", low == 0 and high == 5, tostring(low) .. "-" .. tostring(high))
	A.Mob("nameplate1", 20, 120)
	low, high = NS:AggroDistance("nameplate1")
	Check("[AGGRO] 120 m : plus de 80", low == 80 and high == nil, tostring(low) .. "-" .. tostring(high))
	Check("[AGGRO] mesure notée pour le diag", NS.aggroMeasured == true)

	-- objets muets (pas en cache, ou client fermé) : CheckInteractDistance prend le relais
	A.W.noItems, A.W.interact = true, true
	A.Mob("nameplate1", 20, 22)
	low, high = NS:AggroDistance("nameplate1")
	Check("[AGGRO] repli interaction : entre 10 et 28", low == 10 and high == 28, tostring(low) .. "-" .. tostring(high))
	Check("[AGGRO] repli interaction : rouge pour un monstre de même niveau", NS.AggroVerdict(20, low, high) == "red")
	A.W.interact = false
	low, high = NS:AggroDistance("nameplate1")
	Check("[AGGRO] aucune réponse : pas de distance", low == nil and high == nil)
	-- une API qui lève une erreur ne casse rien
	C_Item.IsItemInRange = function() error("restricted") end
	_G.CheckInteractDistance = function() error("restricted") end
	local ok, l2 = pcall(NS.AggroDistance, NS, "nameplate1")
	Check("[AGGRO] API refusée : pas d'erreur, pas de distance", ok and l2 == nil)
	A.Install()

	-- 1.31.0 : paliers mesurés en jeu sur Forever (9/11) : 5, 20, 28
	-- (interaction), 30 et 35 m répondent ; 10, 15, 25 et 45 m jamais
	A.Reset()
	A.W.silent = { [8] = true, [10] = true, [15] = true, [25] = true, [40] = true, [45] = true, [60] = true, [80] = true }
	A.W.interact = true
	A.Mob("nameplate1", 20, 22)
	low, high = NS:AggroDistance("nameplate1")
	Check("[AGGRO] client classique, 22 m : entre 20 et 28, rouge", low == 20 and high == 28
		and NS.AggroVerdict(20, low, high) == "red", tostring(low) .. "-" .. tostring(high))
	A.Mob("nameplate1", 20, 29)
	low, high = NS:AggroDistance("nameplate1")
	Check("[AGGRO] client classique, 29 m : entre 28 et 30, ambre", low == 28 and high == 30
		and NS.AggroVerdict(20, low, high) == "amber", tostring(low) .. "-" .. tostring(high))
	A.Mob("nameplate1", 20, 40)
	NS:AggroDistance("nameplate1")
	local line = NS:AggroDiagLine()
	Check("[AGGRO] diag : paliers qui répondent", line:find("paliers qui répondent : 5, 10, 20, 28, 30, 35 m", 1, true) ~= nil, line)
	NS.aggroSteps = nil
	Check("[AGGRO] diag : aucun palier encore", NS:AggroDiagLine():find("paliers qui répondent : aucun", 1, true) ~= nil)
	-- préchargement des objets des paliers, et mesures oubliées à leur arrivée
	local asked = {}
	local savedReq = C_Item.RequestLoadItemDataByID
	C_Item.RequestLoadItemDataByID = function(id) asked[id] = true end
	NS.aggroPreloaded = nil
	Mock:Fire("PLAYER_ENTERING_WORLD")
	local n, all = 0, true
	for id in pairs(NS.AGGRO_ITEM_SET) do n = n + 1; if not asked[id] then all = false end end
	Check("[AGGRO] objets des paliers demandés à l'entrée en jeu", all and n > 10 and NS.aggroPreloaded == true)
	asked = {}
	Mock:Fire("PLAYER_ENTERING_WORLD")
	Check("[AGGRO] … une seule fois", next(asked) == nil)
	C_Item.RequestLoadItemDataByID = savedReq
	NS.aggroDistCache = { nameplate1 = { low = 1 } }
	Mock:Fire("GET_ITEM_INFO_RECEIVED", 32321, true)
	Check("[AGGRO] objet d'un palier reçu : mesures oubliées", NS.aggroDistCache == nil)
	NS.aggroDistCache = { nameplate1 = { low = 1 } }
	Mock:Fire("GET_ITEM_INFO_RECEIVED", 2589, true)
	Check("[AGGRO] autre objet reçu : mesures gardées", NS.aggroDistCache ~= nil)
end

-- 4. Touche et combat ----------------------------------------------------------
do
	Say("-- aggro : touche et combat")
	A.Reset()
	Check("[AGGRO] sans touche : inactif", NS:AggroActive() == false)
	A.W.shift = true
	Check("[AGGRO] Maj tenue : actif", NS:AggroActive() == true)
	A.W.combat = true
	Check("[AGGRO] en combat : inactif", NS:AggroActive() == false)
	A.W.combat, A.W.shift = false, false
	NS:DB().aggroKey = "ctrl"
	A.W.ctrl = true
	Check("[AGGRO] Ctrl choisi : Ctrl suffit", NS:AggroActive() == true)
	A.W.ctrl, A.W.shift = false, true
	Check("[AGGRO] Ctrl choisi : Maj ne suffit pas", NS:AggroActive() == false)
	NS:DB().aggroKey = "alt"
	A.W.alt = true
	Check("[AGGRO] Alt choisi", NS:AggroActive() == true)
	NS:DB().aggroKey = "always"
	A.W.alt, A.W.shift = false, false
	Check("[AGGRO] « toujours » : sans touche", NS:AggroActive() == true)
	NS:DB().aggroEnabled = false
	Check("[AGGRO] module coupé : inactif", NS:AggroActive() == false)
	NS:DB().aggroEnabled, NS:DB().aggroKey = true, "shift"

	-- 1.31.0 : « danger seul »
	NS:DB().aggroKey = "alert"
	A.W.shift, A.W.ctrl, A.W.alt = false, false, false
	Check("[AGGRO] danger seul, sans touche : actif, rouge seul", NS:AggroActive() == true and NS:AggroMode() == "red-only")
	A.W.shift = true
	Check("[AGGRO] danger seul, Maj tenue : tout", NS:AggroMode() == "full")
	A.W.combat = true
	Check("[AGGRO] danger seul, en combat : inactif", NS:AggroActive() == false)
	A.W.combat, A.W.shift = false, false
	NS:DB().aggroKey = "shift"
	Check("[AGGRO] Maj choisi, sans touche : rien", NS:AggroMode() == nil)
end

-- 5. Infobulle -----------------------------------------------------------------
do
	Say("-- aggro : infobulle")
	A.Reset()
	A.Mob("mouseover", 20, 22)
	GameTooltip:ClearLines()
	Check("[AGGRO] sans la touche : rien dans l'infobulle", NS:AggroOnTooltip(GameTooltip, {}) == false and #GameTooltip.lines == 0)
	A.W.shift = true
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] ligne : portée, distance, verdict",
		A.Tip():find("Aggro ~20 m · tu es à 20-25 m · danger, trop près", 1, true) ~= nil, A.Tip())   -- 1.30.0 : on prévient avant
	Check("[AGGRO] couleur rouge (5 m avant la portée)", GameTooltip.styled[1].color[1] == NS.Theme.RED[1])
	Check("[AGGRO] mention d'estimation", A.Tip():find("Estimation", 1, true) ~= nil)

	GameTooltip:ClearLines()
	A.Mob("mouseover", 20, 12)
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] 12 m d'un monstre de même niveau : dans sa portée, rouge",
		A.Tip():find("danger, trop près", 1, true) ~= nil and GameTooltip.styled[1].color[1] == NS.Theme.RED[1], A.Tip())

	GameTooltip:ClearLines()
	A.W.level = 30
	A.Mob("mouseover", 20, 22)     -- 10 niveaux de moins : portée 10
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] monstre bien plus faible : à la limite, ambre (marge de 12 m)",
		A.Tip():find("Aggro ~10 m", 1, true) ~= nil and A.Tip():find("à la limite", 1, true) ~= nil
		and GameTooltip.styled[1].color[1] == NS.Theme.ORANGE[1], A.Tip())
	A.W.level = 20

	GameTooltip:ClearLines()
	A.Mob("mouseover", 20, nil)     -- aucune mesure possible
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] sans distance : la portée seule", A.Tip():find("Aggro ~20 m", 1, true) ~= nil
		and A.Tip():find("tu es", 1, true) == nil, A.Tip())

	GameTooltip:ClearLines()
	A.Mob("mouseover", 20, 22, { reaction = 4 })
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] neutre : n'attaque pas", A.Tip():find("neutre, n'attaque pas", 1, true) ~= nil, A.Tip())

	GameTooltip:ClearLines()
	A.Mob("mouseover", 20, 22, { player = true })
	Check("[AGGRO] joueur : rien", NS:AggroOnTooltip(GameTooltip, {}) == false)
	A.Mob("mouseover", 1, 5, { creature = "Bestiole" })
	Check("[AGGRO] bestiole : rien", NS:AggroOnTooltip(GameTooltip, {}) == false)
	A.Mob("mouseover", 20, 5, { friendly = true })
	Check("[AGGRO] PNJ amical : rien", NS:AggroOnTooltip(GameTooltip, {}) == false)

	A.Mob("mouseover", 20, 22)
	A.W.combat = true
	Check("[AGGRO] en combat : rien", NS:AggroOnTooltip(GameTooltip, {}) == false)
	A.W.combat = false
	NS:DB().aggroTooltip = false
	Check("[AGGRO] infobulle coupée : rien", NS:AggroOnTooltip(GameTooltip, {}) == false)
	NS:DB().aggroTooltip = true

	-- 1.31.0 : danger seul : la ligne sans touche, fourchette complète, même loin
	NS:DB().aggroKey = "alert"
	A.W.shift = false
	A.W.silent = { [8] = true, [10] = true, [15] = true, [25] = true, [40] = true, [45] = true, [60] = true, [80] = true }
	A.W.interact = true
	GameTooltip:ClearLines()
	A.Mob("mouseover", 20, 22)
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] danger seul : infobulle sans touche, paliers classiques",
		A.Tip():find("tu es à 20-28 m · danger, trop près", 1, true) ~= nil, A.Tip())
	GameTooltip:ClearLines()
	A.W.level = 30
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] danger seul : monstre faible (rayon 10) à 22 m, ambre dans l'infobulle",
		A.Tip():find("à la limite", 1, true) ~= nil, A.Tip())
	A.W.level = 20
	GameTooltip:ClearLines()
	A.Mob("mouseover", 20, 60)
	NS:AggroOnTooltip(GameTooltip, {})
	Check("[AGGRO] danger seul : loin, fourchette complète (pas coupée)", A.Tip():find("plus de 35 m", 1, true) ~= nil, A.Tip())
	A.W.silent = nil
	NS:DB().aggroKey = "shift"
end

-- 6. Anneaux des barres de nom -------------------------------------------------
do
	Say("-- aggro : anneaux")
	A.Reset()
	A.Mob("nameplate1", 20, 12)                       -- rouge
	A.Mob("nameplate2", 20, 28)                       -- ambre (1.30.0 : 22 m est déjà rouge)
	A.Mob("nameplate3", 20, 60)                       -- vert
	A.Mob("nameplate4", 20, 12, { reaction = 4 })     -- neutre : pas d'anneau
	for i = 1, 4 do A.Plate("nameplate" .. i) end
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] touche relâchée : aucun anneau", not A.RingShown("nameplate1") and not A.RingShown("nameplate2"))

	A.W.shift = true
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] dans la portée : anneau rouge", A.RingShown("nameplate1") and A.Ring("nameplate1").verdict == "red"
		and A.Ring("nameplate1").texture.vertex[1] == NS.Theme.RED[1])
	Check("[AGGRO] à la limite : anneau ambre", A.RingShown("nameplate2") and A.Ring("nameplate2").verdict == "amber")
	Check("[AGGRO] loin : anneau vert, discret", A.RingShown("nameplate3") and A.Ring("nameplate3").verdict == "green"
		and A.Ring("nameplate3").alpha < 0.9)
	Check("[AGGRO] neutre : pas d'anneau", not A.RingShown("nameplate4"))
	Check("[AGGRO] anneau accroché au cadre de base de la barre", A.Ring("nameplate1"):GetParent() == A.W.plates.nameplate1
		and A.Ring("nameplate1").lastPoint and A.Ring("nameplate1").lastPoint.relTo == A.W.plates.nameplate1)

	-- style par défaut : la pastille (losange à gauche), pas le grand anneau
	local r1 = A.Ring("nameplate1")
	Check("[AGGRO] marque par défaut : pastille, anneau caché", NS:AggroStyle() == "dot" and r1.dot:IsShown()
		and not r1.ringTexture:IsShown() and not r1.bar:IsShown() and r1.texture == r1.dot)
	Check("[AGGRO] pastille : 16 px, rentrée vers le nom", NS.AGGRO_DOT_SIZE == 16 and r1.dot.width == 16
		and r1.dotBack.lastPoint.x == NS.AGGRO_DOT_INSET and NS.AGGRO_DOT_INSET > 2)
	Check("[AGGRO] pastille : à gauche de la barre, au-dessus d'elle", r1.dotBack.lastPoint and r1.dotBack.lastPoint.relTo == A.W.plates.nameplate1
		and r1.dotBack.lastPoint.point == "RIGHT")
	NS:AggroSetStyle("bar")
	Check("[AGGRO] style trait : une ligne sous la barre, à la couleur", r1.bar:IsShown() and not r1.dot:IsShown()
		and r1.texture == r1.bar and r1.bar.vertex[1] == NS.Theme.RED[1])
	NS:AggroSetStyle("ring")
	Check("[AGGRO] style anneau : l'ancien halo", r1.ringTexture:IsShown() and not r1.bar:IsShown()
		and r1.width == NS.AGGRO_RING_SIZE)
	NS:AggroSetStyle("nimportequoi")
	Check("[AGGRO] style inconnu : refusé", NS:AggroStyle() == "ring")
	Check("[AGGRO] trois styles proposés", #NS:AggroStyleChoices() == 3)
	NS:AggroSetStyle("dot")

	-- le joueur s'approche : le verdict suit au passage suivant
	A.W.units.nameplate3.dist = 18
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] rafraîchi pendant que la touche est tenue", A.Ring("nameplate3").verdict == "red")

	-- nouvelle barre pendant que la touche est tenue : anneau tout de suite
	A.Mob("nameplate5", 20, 3)
	A.Plate("nameplate5")
	Check("[AGGRO] barre ajoutée : anneau immédiat", A.RingShown("nameplate5"))

	-- barre retirée : anneau masqué et oublié
	local ring5 = A.Ring("nameplate5")
	A.W.plates.nameplate5 = nil
	Mock:Fire("NAME_PLATE_UNIT_REMOVED", "nameplate5")
	Check("[AGGRO] barre retirée : anneau masqué", ring5:IsShown() == false and NS.aggroPlates.nameplate5 == nil)

	-- combat : tout disparaît
	A.W.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[AGGRO] entrée en combat : anneaux masqués", not A.RingShown("nameplate1") and not A.RingShown("nameplate2"))
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] en combat : pas de retour des anneaux", not A.RingShown("nameplate1"))
	A.W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[AGGRO] sortie de combat, touche tenue : anneaux revenus", A.RingShown("nameplate1"))

	-- touche relâchée : tout disparaît (MODIFIER_STATE_CHANGED, sans attendre)
	A.W.shift = false
	Mock:Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
	Check("[AGGRO] touche relâchée : anneaux masqués aussitôt", not A.RingShown("nameplate1") and not A.RingShown("nameplate3"))

	-- option anneaux coupée
	A.W.shift = true
	NS:DB().aggroRings = false
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] anneaux coupés dans les réglages", not A.RingShown("nameplate1"))
	NS:DB().aggroRings = true

	-- sans mesure de distance : pas d'anneau
	A.W.noItems = true
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] sans distance : pas d'anneau", not A.RingShown("nameplate1"))
	A.W.noItems = false
end

-- 6 bis. « Danger seul » (1.31.0) ---------------------------------------------
do
	Say("-- aggro : danger seul")
	A.Reset(true)
	A.Mob("nameplate1", 20, 12)                       -- rouge
	A.Mob("nameplate2", 20, 28)                       -- ambre
	A.Mob("nameplate3", 20, 60)                       -- vert
	for i = 1, 3 do A.Plate("nameplate" .. i) end
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] danger seul, sans touche : marque rouge", A.RingShown("nameplate1") and A.Ring("nameplate1").verdict == "red")
	Check("[AGGRO] danger seul, sans touche : ni ambre ni vert", not A.RingShown("nameplate2") and not A.RingShown("nameplate3"))
	A.W.shift = true
	Mock:Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
	Check("[AGGRO] danger seul, Maj tenue : les trois couleurs", A.RingShown("nameplate1") and A.RingShown("nameplate2")
		and A.RingShown("nameplate3") and A.Ring("nameplate2").verdict == "amber" and A.Ring("nameplate3").verdict == "green")
	A.W.shift = false
	Mock:Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
	Check("[AGGRO] danger seul, Maj relâchée : le rouge reste seul", A.RingShown("nameplate1")
		and not A.RingShown("nameplate2") and not A.RingShown("nameplate3"))
	A.W.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] danger seul, en combat : rien", not A.RingShown("nameplate1"))
	A.W.combat = false
	Check("[AGGRO] danger seul : diag « danger seul »", NS:AggroDiagLine():find("danger seul", 1, true) ~= nil, NS:AggroDiagLine())

	-- mesure coupée : rien au-delà du seuil du rouge (rayon 20 + 5 = 25 m)
	A.Reset(true)
	A.Mob("nameplate1", 20, 60)
	A.Plate("nameplate1")
	local queried = {}
	local inner = C_Item.IsItemInRange
	C_Item.IsItemInRange = function(itemID, unit) queried[#queried + 1] = A.itemRange[itemID]; return inner(itemID, unit) end
	Mock:Advance(NS.AGGRO_TICK)
	local beyond = 0
	for _, range in ipairs(queried) do if range > 20 + NS.AGGRO_WARN then beyond = beyond + 1 end end
	Check("[AGGRO] danger seul : aucun palier au-delà du seuil du rouge", #queried > 0 and beyond == 0
		and not A.RingShown("nameplate1"), table.concat(queried, ","))
	C_Item.IsItemInRange = inner
end

do
	Say("-- aggro : barres présentes avant le premier passage, diag")
	A.Reset()
	A.Mob("nameplate7", 20, 12)
	local plate = CreateFrame("Frame", "NamePlate7")
	plate.namePlateUnitToken = "nameplate7"
	A.W.plates.nameplate7 = plate     -- pas d'événement : déjà là au /reload
	A.W.shift = true
	Mock:Advance(NS.AGGRO_TICK)
	Check("[AGGRO] barres existantes reprises (GetNamePlates)", A.RingShown("nameplate7"))
	local line = NS:AggroDiagLine()
	Check("[AGGRO] diag : touche, état, barres, anneaux", line:find("touche Maj", 1, true) ~= nil
		and line:find("actif", 1, true) ~= nil and line:find("1 barre", 1, true) ~= nil
		and line:find("1 anneau", 1, true) ~= nil and line:find("oui", 1, true) ~= nil, line)
	Mock:Reset()
	NS:HandleCommand("diag")
	Check("[AGGRO] /r2q diag dit l'état de l'aggro", Mock:Output():find("aggro :", 1, true) ~= nil)
	NS:DB().aggroEnabled = false
	Check("[AGGRO] diag : module coupé", NS:AggroDiagLine():find("désactivé", 1, true) ~= nil)
	NS:DB().aggroEnabled = true
	-- C_NamePlate absent (client restreint) : rien ne casse
	_G.C_NamePlate = nil
	NS.aggroPlates, NS.aggroScanned = {}, nil
	local ok = pcall(function()
		Mock:Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
		Mock:Advance(NS.AGGRO_TICK)
	end)
	Check("[AGGRO] sans C_NamePlate : aucune erreur", ok and NS.aggroPlates.nameplate8 == nil)
end

-- Cache des mesures : une par unité et par demi-seconde
do
	T.Say("-- aggro : cache des mesures")
	A.Reset()
	NS.AGGRO_DISTANCE_CACHE = 0.5
	A.Mob("nameplate1", 20, 22, { guid = "Creature-0-1-1-1-500-1" })
	local calls = 0
	local inner = C_Item.IsItemInRange
	C_Item.IsItemInRange = function(...) calls = calls + 1; return inner(...) end
	local low1 = NS:AggroDistance("nameplate1")
	local first = calls
	A.W.units.nameplate1.dist = 3
	local low2 = NS:AggroDistance("nameplate1")
	T.Check("[AGGRO] cache : même mesure dans la demi-seconde, sans rappeler le client", calls == first and low1 == low2 and first > 0)
	T.Mock:Advance(1)
	local low3 = NS:AggroDistance("nameplate1")
	T.Check("[AGGRO] cache : remesuré ensuite", calls > first and low3 ~= low1, tostring(low3))
	C_Item.IsItemInRange = inner
	NS.AGGRO_DISTANCE_CACHE = 0.5
end

for _, name in ipairs(NAMES) do _G[name] = saved[name] end
C_Item.IsItemInRange = saved.inRange
NS.aggroPlates, NS.aggroRings, NS.aggroShowing, NS.aggroScanned = {}, {}, nil, nil
