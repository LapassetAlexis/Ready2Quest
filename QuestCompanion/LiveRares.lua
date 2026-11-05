-- LiveRares.lua -- rares signalés en direct par la minicarte (QuestCompanion)
--
-- Moteur récent seulement (C_VignetteInfo, sonde ns.Caps.vignettes) : quand
-- une vignette de créature rare apparaît (VIGNETTE_MINIMAP_UPDATED,
-- VIGNETTES_UPDATED), le compagnon la signale d'une bulle, le bestiaire la
-- note « vue » et le carnet la retient (sa mort comptera si tu l'engages,
-- comme un rare ciblé : Journal.lua). Une fois par créature (numéro de PNJ)
-- toutes les RARE_ALERT_GAP s.
-- Rare ou pas : le rang de la table livrée (ZoneCreatures_<client>.lua) ou
-- celui appris en jeu s'il est connu, sinon l'icône de la vignette
-- (atlasName « VignetteKill… »).
-- Sans C_VignetteInfo, rien ne s'enregistre : comportement d'avant.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.RARE_ALERT_GAP = 600       -- s entre deux alertes pour la même créature

local FR = {
	OPT_DAILY_RARE      = "Rares signalés en direct",
	OPT_DAILY_RARE_DESC = "Le compagnon te prévient quand un rare apparaît sur la minicarte.",
}
local EN = {
	OPT_DAILY_RARE      = "Live rare alerts",
	OPT_DAILY_RARE_DESC = "Your companion tells you when a rare shows up on the minimap.",
}
ns.RegisterStrings(FR, EN)
ns.LIVE_RARE_STRINGS = { fr = FR, en = EN }

local P = {
	RARE_LIVE = {   -- %s = le rare
		{ "Regarde la carte : %s rôde dans le coin !", "Check the map: %s is prowling nearby!" },
		{ "Un rare ! %s, pas loin d'ici.", "A rare! %s, not far from here." },
		{ "Psst… %s traîne par ici. On va voir ?", "Psst… %s is around. Shall we take a look?" },
	},
}
local LINES_FR, LINES_EN, POOLS = {}, {}, {}
for name, lines in pairs(P) do
	local keys = {}
	for index, pair in ipairs(lines) do
		local key = "COMP_SAY_" .. name .. (index > 1 and ("_" .. index) or "")
		LINES_FR[key], LINES_EN[key] = pair[1], pair[2]
		keys[index] = key
	end
	POOLS[name] = keys
end
ns.RegisterStrings(LINES_FR, LINES_EN)
if type(ns.COMPANION_POOLS) == "table" then
	for name, keys in pairs(POOLS) do ns.COMPANION_POOLS[name] = keys end
end
local shared = ns.COMPANION_LINE_STRINGS
if type(shared) == "table" then
	for key, text in pairs(LINES_FR) do shared.fr[key], shared.en[key] = text, LINES_EN[key] end
end
ns.LIVE_RARE_POOLS = POOLS

ns.RegisterDefaults({ companionRareAlert = true })
-- l'interrupteur n'a de sens que si le client signale les rares
if ns.Caps and ns.Caps.vignettes and type(ns.DAILY_OPTION_ROWS) == "table" then
	table.insert(ns.DAILY_OPTION_ROWS, { key = "companionRareAlert", label = "OPT_DAILY_RARE", kind = "bool",
		describe = function() return L.OPT_DAILY_RARE_DESC end })
end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end

local function Api()
	local api = G("C_VignetteInfo")
	if type(api) == "table" and type(api.GetVignettes) == "function" and type(api.GetVignetteInfo) == "function" then
		return api
	end
	return nil
end

function ns:LiveRaresOn()
	if not (ns.CompanionOn and ns.CompanionOn()) then return false end
	return self:DB().companionRareAlert ~= false
end

-- Rare d'après ce qu'on sait de l'espèce dans la zone, sinon d'après l'icône
local RARE = { rare = true, rareelite = true }
function ns:LiveRareIsRare(zoneID, npcID, atlas)
	local static = self.BestiaryStaticZone and self:BestiaryStaticZone(zoneID)
	local entry = static and static[npcID]
	if type(entry) == "table" then
		return RARE[(ns.BESTIARY_RANK_CLASS or {})[tonumber(entry.rank) or 0] or ""] == true
	end
	local learned = self.BestiaryZone and self:BestiaryZone(zoneID)
	learned = learned and learned[npcID]
	if type(learned) == "table" and RARE[learned.class or ""] then return true end
	return type(atlas) == "string" and atlas:find("VignetteKill", 1, true) ~= nil
end

-- Une vignette : renvoie true si elle a déclenché l'alerte
function ns:LiveRareCheck(vignetteGUID)
	local api = Api()
	if not api or vignetteGUID == nil or not self:LiveRaresOn() then return false end
	local ok, info = pcall(api.GetVignetteInfo, vignetteGUID)
	if not ok or type(info) ~= "table" then return false end
	-- hors de la minicarte (carte du monde seulement) : pas encore « là »
	if ns.Plain(info.onMinimap) == false then return false end
	local guid = ns.Plain(info.objectGUID)
	local npcID = ns.BestiaryNpcID and ns.BestiaryNpcID(guid)
	if not npcID then return false end              -- trésor, objet, joueur…
	local zoneID = self.JournalZone and self:JournalZone()
	if not zoneID then return false end             -- en instance : pas de bestiaire de zone
	local atlas = ns.Plain(info.atlasName)
	if not self:LiveRareIsRare(zoneID, npcID, atlas) then return false end
	local name = ns.Plain(info.name)
	if type(name) ~= "string" or name == "" then
		local static = self:BestiaryStaticZone(zoneID)
		name = (static and self:BestiaryStaticName(static[npcID])) or tostring(npcID)
	end
	-- carnet et bestiaire : à chaque passage (la mémoire du rare se rafraîchit)
	if self.BestiarySeeGUID then self:BestiarySeeGUID(guid, name, "rare") end
	if self.JournalSeeRare then self:JournalSeeRare(guid, name) end

	self.liveRareAlerts = self.liveRareAlerts or {}
	local now = Clock()
	local last = self.liveRareAlerts[npcID]
	if last and now >= last and now - last < ns.RARE_ALERT_GAP then return false end
	local said, why = self:CompanionSay("RARE_LIVE", { force = true, category = "event", args = { name } })
	-- occupé (une bulle plus importante) : on réessaiera à la prochaine mise à jour
	if not said and why == "busy" then return false end
	self.liveRareAlerts[npcID] = now
	if said and self.CompanionFx then self:CompanionFx("alert") end
	return said == true
end

function ns:LiveRareScan()
	local api = Api()
	if not api or not self:LiveRaresOn() then return 0 end
	local ok, list = pcall(api.GetVignettes)
	if not ok or type(list) ~= "table" then return 0 end
	local alerts = 0
	for _, vignetteGUID in ipairs(list) do
		if self:LiveRareCheck(vignetteGUID) then alerts = alerts + 1 end
	end
	return alerts
end

-- ---------------------------------------------------------------------------
-- Événements : seulement si le client a C_VignetteInfo
-- ---------------------------------------------------------------------------
local HANDLERS = {
	VIGNETTE_MINIMAP_UPDATED = function(vignetteGUID, onMinimap)
		if onMinimap == false then return end
		ns:LiveRareCheck(vignetteGUID)
	end,
	VIGNETTES_UPDATED = function() ns:LiveRareScan() end,
}

local okFrame, eventFrame = pcall(CreateFrame, "Frame")
if okFrame and eventFrame then
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		local done, err = pcall(HANDLERS[event], ...)
		if not done and ns.RecordError then ns:RecordError("rares:" .. tostring(event), err) end
	end)
	ns.liveRareFrame = eventFrame
end

-- Écoute posée une fois, si le client a l'API ; renvoie true si elle l'est
function ns:LiveRareListen()
	local frame = self.liveRareFrame
	if not frame or not Api() then return false end
	if not self.liveRareListening then
		for event in pairs(HANDLERS) do
			-- un événement inconnu du client ne bloque pas l'autre
			pcall(frame.RegisterEvent, frame, event)
		end
		self.liveRareListening = true
	end
	return true
end
ns:LiveRareListen()

if ns.Mark then ns.Mark("LiveRares") end
