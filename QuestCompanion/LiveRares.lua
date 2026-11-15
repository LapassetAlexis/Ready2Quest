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
if ns.KEEP_STRINGS then ns.LIVE_RARE_STRINGS = { fr = FR, en = EN } end

local P = {
	RARE_LIVE = {   -- %s = le rare
		{ "Regarde la carte : %s rôde dans le coin !", "Check the map: %s is prowling nearby!" },
		{ "Un rare ! %s, pas loin d'ici.", "A rare! %s, not far from here." },
		{ "Psst… %s traîne par ici. On va voir ?", "Psst… %s is around. Shall we take a look?" },
	},
}
-- enregistrement commun (CompanionLines.lua) ; listes de clés en test seulement
local POOLS = ns.RegisterCompanionLines(P)
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
	-- classe déjà apprise (rare élite…) gardée ; sinon « rare » (la table de
	-- zone, si elle connaît l'espèce, l'emporte de toute façon à l'affichage)
	local known = self.BestiaryZone and self:BestiaryZone(zoneID)
	known = known and known[npcID]
	local class = (type(known) == "table" and RARE[known.class or ""] and known.class) or "rare"
	if self.BestiarySeeGUID then self:BestiarySeeGUID(guid, name, class) end
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

-- Écoute posée une fois, si le client a l'API ; renvoie true si elle l'est
-- 3.1.0 : cadre d'événements commun (ns.On, Libs/Socle/Compat.lua) ; un
-- événement inconnu du client ne bloque pas l'autre
function ns:LiveRareListen()
	if not Api() then return false end
	if not self.liveRareListening then
		-- les deux gestionnaires ne font rien alerte coupée : la porte retire l'écoute
		ns.EventGate("rares", function() return ns:LiveRaresOn() end)
		for event, fn in pairs(HANDLERS) do ns.On(event, "rares", fn) end
		self.liveRareListening = true
	end
	return true
end
ns:LiveRareListen()

if ns.Mark then ns.Mark("LiveRares") end
