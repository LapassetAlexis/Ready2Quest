-- CompanionRested.lua -- « bien reposé » : le retour après une absence (QuestCompanion 3.7.0)
--
-- Un personnage qui revient après 8 heures d'absence au moins retrouve son
-- compagnon Reposé (l'état existant, 45 minutes) ; après 3 jours au moins, les
-- trois états pour 20 minutes, donc Rayonnant (et Reposé garde ses 45 minutes
-- des 8 heures). On complète sans jamais raccourcir un état déjà plus long
-- (ns:CompanionGrant ne baisse rien) ; rien ne s'accumule au-delà.
-- L'absence : depuis CompanionData().lastSeen (posé à chaque relevé et à la
-- déconnexion, Companion.lua). La première connexion avec cette version ne
-- donne rien (data.restedV). La bulle de bonjour existante (somnolent au
-- retour) le dit, sans bulle de plus : ns:CompanionLogin appelle
-- ns:CompanionRestedLogin et prend la réplique rendue. La somnolence garde son
-- charme (et la caresse qui réveille) mais ne retire plus le bonus des états
-- (ns:CompanionRadiant, Companion.lua).
local ADDON, ns = ...
if ns.blocked then return end

ns.COMPANION_RESTED = { after = 8 * 3600, long = 3 * 86400, longMinutes = 20, schema = 1 }
-- le harnais de test l'endort (les scénarios d'absence d'avant) ; companion
-- rested : zone_37.lua le réveille
ns.companionRestedDormant = rawget(_G, "ADDON_TESTING") and true or nil

local FR = {
	COMP_SAY_RESTED      = "J'ai bien dormi !",
	COMP_SAY_RESTED_LONG = "Content de te revoir !",
}
local EN = {
	COMP_SAY_RESTED      = "I slept well!",
	COMP_SAY_RESTED_LONG = "Good to see you again!",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.COMPANION_RESTED_STRINGS = { fr = FR, en = EN } end

-- À la connexion (ns:CompanionLogin) : `away` secondes d'absence, `first` :
-- tout premier relevé. Pose les états mérités ; rend la clé de la réplique
-- de bonjour (nil : rien de mérité, la bulle d'avant).
function ns:CompanionRestedLogin(away, first)
	if ns.companionRestedDormant then return nil end
	local data = self:CompanionData()
	local R = ns.COMPANION_RESTED
	-- première connexion avec cette version : la marque, rien d'autre
	if (tonumber(data.restedV) or 0) < R.schema then
		data.restedV = R.schema
		return nil
	end
	away = tonumber(away) or 0
	if first or away < R.after then return nil end
	local S = ns.COMPANION_STATE
	self:CompanionGrant("energy", S.full)
	if away < R.long then return "COMP_SAY_RESTED" end
	local value = S.on + R.longMinutes * S.rate
	for _, key in ipairs(ns.COMPANION_NEED_KEYS or {}) do self:CompanionGrant(key, value) end
	return "COMP_SAY_RESTED_LONG"
end

if ns.Mark then ns.Mark("CompanionRested") end
