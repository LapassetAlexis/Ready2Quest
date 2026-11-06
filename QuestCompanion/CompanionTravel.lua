-- CompanionTravel.lua -- la route parcourue ensemble (QuestCompanion 1.5.0)
--
-- Toutes les TRAVEL_STEP secondes, la position du joueur (coordonnées monde,
-- en yards, quand le client les donne) ; la distance depuis le relevé
-- précédent s'ajoute au compteur du compagnon, en mètres. Pas de triche :
--   * changement de continent, d'instance ou de carte sans coordonnées
--     monde : on repart de zéro, rien n'est compté ;
--   * un saut trop grand pour le temps écoulé (téléportation, pierre de foyer,
--     mort puis résurrection) : ignoré (TRAVEL_MAX_SPEED yards par seconde,
--     assez pour un griffon) ;
--   * compagnon coupé : rien ne compte.
-- Lu par la page Compagnon du carnet (ns:TravelText).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.TRAVEL_STEP = 1                 -- s entre deux relevés
ns.TRAVEL_MAX_SPEED = 45           -- yards par seconde au-delà : un saut, pas un trajet
ns.TRAVEL_MIN_MOVE = 0.5           -- yards : en dessous, c'est du bruit
local YARD = 0.9144                -- mètres

local FR = {
	TRAVEL_KM   = "%s km",
	TRAVEL_M    = "%d m",
	TRAVEL_LABEL = "parcourus ensemble",
}
local EN = {
	TRAVEL_KM   = "%s km",
	TRAVEL_M    = "%d m",
	TRAVEL_LABEL = "travelled together",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRAVEL_STRINGS = { fr = FR, en = EN } end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end
local function G(name) return rawget(_G, name) end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end

-- x, y d'une position (table ou objet vecteur)
local function XY(pos)
	if type(pos) ~= "table" then return nil end
	local x, y = pos.x, pos.y
	if (x == nil or y == nil) and type(pos.GetXY) == "function" then x, y = Call(pos.GetXY, pos) end
	x, y = tonumber(ns.Plain(x)), tonumber(ns.Plain(y))
	if not (x and y) then return nil end
	return x, y
end

-- Position monde du joueur : x, y (yards) et une clé de lieu (continent ou
-- instance) ; nil quand le client ne la donne pas
function ns:TravelPosition()
	-- 1) UnitPosition : coordonnées monde et instance, quand le client l'ouvre
	local y, x, _, instance = Call(G("UnitPosition"), "player")
	x, y, instance = tonumber(ns.Plain(x)), tonumber(ns.Plain(y)), ns.Plain(instance)
	if x and y and (x ~= 0 or y ~= 0) then return x, y, "i" .. tostring(instance) end
	-- 2) carte + position sur la carte -> position monde (comme Death.lua)
	local map = G("C_Map")
	if type(map) ~= "table" then return nil end
	local mapID = ns.Plain(Call(map.GetBestMapForUnit, "player"))
	if not mapID then return nil end
	local pos = Call(map.GetPlayerMapPosition, mapID, "player")
	if not pos then return nil end
	local continent, world = Call(map.GetWorldPosFromMapPos, mapID, pos)
	local wx, wy = XY(world)
	if wx then return wx, wy, "c" .. tostring(ns.Plain(continent)) end
	return nil
end

function ns:TravelData()
	local data = self:CompanionData()
	data.travel = math.max(0, tonumber(data.travel) or 0)
	return data
end

-- Un relevé : rend les mètres ajoutés (0 si rien ne compte)
function ns:TravelSample(now)
	if not ModuleOn() then self.travelLast = nil; return 0 end
	local x, y, place = self:TravelPosition()
	if not x then self.travelLast = nil; return 0 end
	local last = self.travelLast
	self.travelLast = { x = x, y = y, place = place, at = now }
	if not last or last.place ~= place then return 0 end
	local elapsed = math.max(0.001, now - (last.at or now))
	local yards = math.sqrt((x - last.x) ^ 2 + (y - last.y) ^ 2)
	if yards < ns.TRAVEL_MIN_MOVE or yards > ns.TRAVEL_MAX_SPEED * elapsed then return 0 end
	local meters = yards * YARD
	local data = self:TravelData()
	data.travel = data.travel + meters
	-- carnet ouvert sur le Compagnon : le chiffre suit, sans tout redessiner
	local frame = self.journalFrame
	local tile = frame and frame.evo and frame.evo.stats and frame.evo.stats.km
	if tile and frame:IsShown() and frame.kind == "evolution" then tile.value:SetText(self:TravelText()) end
	return meters
end

-- « 12,4 km » (une décimale, virgule en français), « 350 m » en dessous du km
function ns:TravelText(meters)
	meters = tonumber(meters) or self:TravelData().travel
	if meters < 1000 then return self:F("TRAVEL_M", math.floor(meters + 0.5)) end
	local km = meters / 1000
	local text = km >= 100 and tostring(math.floor(km + 0.5)) or string.format("%.1f", km)
	-- virgule décimale sur un client français (« 12,4 km »)
	if Call(G("GetLocale")) == "frFR" then text = text:gsub("%.", ",") end
	return self:F("TRAVEL_KM", text)
end

do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame and ns.Throttle then
		frame:SetScript("OnUpdate", ns.Throttle(ns.TRAVEL_STEP, function()
			local done, err = pcall(ns.TravelSample, ns, (ns.Now and ns.Now()) or 0)
			if not done and ns.RecordError then ns:RecordError("travel", err) end
		end))
		ns.travelFrame = frame
	end
end

if ns.Mark then ns.Mark("CompanionTravel") end
