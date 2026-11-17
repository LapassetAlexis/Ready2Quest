-- CombatBoot.lua -- avant le moteur Combat (1.38.0)
--
-- Le moteur de combat (Ready2Quest/Combat/, repris de DoesItDiePlus par
-- tools/sync_combat.py) vit dans ns.combat. Chacun de ses fichiers s'arrête
-- quand ns.combat est nil : c'est le cas quand DoesItDiePlus
-- (UsefulPlatesAndTooltips) ou Does It Die (DoesItDie) est activé pour ce
-- personnage. Leur addon fait alors le travail, et le nôtre s'efface pour ne
-- pas doubler marqueurs, crânes et chiffres (CombatRival dit lequel).
--
-- Les variables sauvegardées ne sont pas encore lues ici : l'interrupteur de
-- chaque partie (Réglages › Combat) agit à ADDON_LOADED (Combat.lua).
local ADDON, ns = ...

ns.COMBAT_RIVALS = { "UsefulPlatesAndTooltips", "DoesItDie" }

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

-- Activé pour ce personnage ? GetAddOnEnableState change l'ordre de ses
-- arguments selon le client : on essaie les deux. Chargé (déjà passé avant
-- nous) : oui aussi.
function ns.CombatAddonEnabled(name)
	local api = rawget(_G, "C_AddOns")
	local loaded = (api and api.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
	if Call(loaded, name) == true then return true end
	local me = Call(rawget(_G, "UnitName"), "player")
	local modern = api and api.GetAddOnEnableState
	if modern then
		local state = tonumber((Call(modern, name, me))) or tonumber((Call(modern, name)))
		if state then return state > 0 end
	end
	local legacy = rawget(_G, "GetAddOnEnableState")
	if legacy then
		local state = tonumber((Call(legacy, me, name)))
		if state then return state > 0 end
	end
	local loadable = (api and api.IsAddOnLoadable) or rawget(_G, "IsAddOnLoadable")
	local ok, reason = Call(loadable, name)
	if ok == true then return true end
	return false
end

ns.combatRival = nil
for _, name in ipairs(ns.COMBAT_RIVALS) do
	if ns.CombatAddonEnabled(name) then ns.combatRival = name; break end
end
ns.combat = (not ns.combatRival) and {} or nil

if ns.Mark then ns.Mark("CombatBoot") end
