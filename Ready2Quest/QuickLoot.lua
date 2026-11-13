-- QuickLoot.lua -- butin rapide (Ready2Quest 1.35.0)
--
-- Le butin automatique du jeu ramasse case par case, avec un délai entre
-- deux objets. Butin rapide ramasse tout d'un coup, dès que le butin est
-- prêt (LOOT_READY) : la fenêtre de butin n'a presque pas le temps de
-- s'afficher.
--   * il suit ton réglage du jeu : il n'agit que si le butin automatique est
--     actif, ou forcé par ta touche de butin automatique (comme le jeu) ;
--   * une case verrouillée (objet réservé à un autre, tirage en cours) n'est
--     pas touchée ; ce qui ne rentre pas reste dans la fenêtre, où « Place
--     au butin » (LootRoom.lua) prend le relais ;
--   * un passage au plus toutes les QUICKLOOT_GAP secondes (le serveur refuse
--     les rafales) ;
--   * un autre addon de butin rapide connu est actif : celui-ci lui laisse la
--     main (deux boucles sur le même butin se gênent) ;
--   * coupé par défaut ; l'événement n'est écouté que réglage actif.
local ADDON, ns = ...
local L = ns.L

ns.QUICKLOOT_GAP = 0.3
-- addons qui font déjà le butin rapide : { nom du dossier, test « son réglage est actif » }
ns.QUICKLOOT_RIVALS = {
	{ "SpeedyAutoLoot" },
	{ "Leatrix_Plus", function()
		local db = rawget(_G, "LeaPlusDB")
		return type(db) == "table" and db.FasterLooting == "On"
	end },
}

local FR = {
	OPT_QUICKLOOT       = "Butin rapide",
	OPT_QUICKLOOT_DESC  = "Avec le butin automatique du jeu : tout est ramassé d'un coup, sans le délai entre deux objets. Ce qui ne rentre pas dans tes sacs reste dans la fenêtre.",
	QUICKLOOT_RIVAL     = "Butin rapide : %s s'en charge déjà, Ready2Quest lui laisse la main.",
}
local EN = {
	OPT_QUICKLOOT       = "Fast loot",
	OPT_QUICKLOOT_DESC  = "With the game's auto loot: everything is picked up at once, without the delay between items. What does not fit in your bags stays in the loot window.",
	QUICKLOOT_RIVAL     = "Fast loot: %s already does it, Ready2Quest stands aside.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.QUICKLOOT_STRINGS = { fr = FR, en = EN } end
ns.RegisterDefaults({ quickLootEnabled = false })

-- réglage : sur la page « Place au butin » (les deux vivent sur la fenêtre de butin)
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "lootroom" and type(page.rows) == "table" then
		local present = false
		for _, row in ipairs(page.rows) do if row.key == "quickLootEnabled" then present = true end end
		if not present then
			page.rows[#page.rows + 1] = { key = "quickLootEnabled", label = "OPT_QUICKLOOT", kind = "bool",
				describe = function() return L.OPT_QUICKLOOT_DESC end }
		end
	end
end

local function G(name) return rawget(_G, name) end
local function Plain(value) return ns.Plain and ns.Plain(value) or value end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if ok then return a, b, c, d, e, f end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end

function ns:QuickLootOn()
	local db = self:DB()
	return db.enabled ~= false and db.quickLootEnabled == true
end

-- Un autre addon fait-il déjà le butin rapide ? Rend son nom.
function ns:QuickLootRival()
	local addons = G("C_AddOns")
	local loaded = type(addons) == "table" and addons.IsAddOnLoaded or G("IsAddOnLoaded")
	if type(loaded) ~= "function" then return nil end
	for _, rival in ipairs(ns.QUICKLOOT_RIVALS) do
		if Plain(Call(loaded, rival[1])) and (not rival[2] or Call(rival[2])) then return rival[1] end
	end
	return nil
end

-- Le butin automatique est-il voulu pour ce butin ? (réglage du jeu, inversé
-- par la touche de butin automatique : comme le client)
local function AutoLootWanted()
	local cvars = G("C_CVar")
	local getBool = type(cvars) == "table" and cvars.GetCVarBool or G("GetCVarBool")
	local auto = Plain(Call(getBool, "autoLootDefault")) and true or false
	local modified = Plain(Call(G("IsModifiedClick"), "AUTOLOOTTOGGLE")) and true or false
	return auto ~= modified
end
ns.QuickLootWanted = AutoLootWanted

-- Ramasse toutes les cases libres, de la dernière à la première. Rend le
-- nombre de cases demandées (0 : rien à faire, pas voulu, trop tôt).
function ns:QuickLootRun()
	if not self:QuickLootOn() or not AutoLootWanted() then return 0 end
	local now = Clock()
	if self.quickLootAt and now - self.quickLootAt < ns.QUICKLOOT_GAP and now >= self.quickLootAt then return 0 end
	local rival = self:QuickLootRival()
	if rival then
		if self.quickLootRivalSaid ~= rival then
			self.quickLootRivalSaid = rival
			self:Print(self:F("QUICKLOOT_RIVAL", rival))
		end
		return 0
	end
	local total = tonumber(Plain(Call(G("GetNumLootItems")))) or 0
	if total <= 0 then return 0 end
	self.quickLootAt = now
	local info, take, asked = G("GetLootSlotInfo"), G("LootSlot"), 0
	if type(take) ~= "function" then return 0 end
	for slot = total, 1, -1 do
		-- 6e retour : case verrouillée (pas pour toi, tirage en cours)
		local _, _, _, _, _, locked = Call(info, slot)
		if not Plain(locked) then
			local ok, err = pcall(take, slot)
			if ok then
				asked = asked + 1
			elseif self.RecordError then
				self:RecordError("quickloot:slot", err)
			end
		end
	end
	return asked
end

-- ---------------------------------------------------------------------------
-- Événement : écouté seulement réglage actif (cadre unique du socle)
-- ---------------------------------------------------------------------------
local OWNER, listening = "quickLoot", false
local function OnLoot() ns:QuickLootRun() end
function ns:QuickLootEvents()
	local want = self:QuickLootOn()
	if want == listening then return want end
	listening = want
	if want then
		-- LOOT_READY : le butin est connu avant que la fenêtre ne s'ouvre ; sur
		-- un client qui ne l'envoie pas, LOOT_OPENED (un peu plus tard)
		if not ns.On("LOOT_READY", OWNER, OnLoot, "quickloot:LOOT_READY") then
			ns.Off("LOOT_READY", OWNER)
			ns.On("LOOT_OPENED", OWNER, OnLoot, "quickloot:LOOT_OPENED")
		end
	else
		ns.Off("LOOT_READY", OWNER)
		ns.Off("LOOT_OPENED", OWNER)
	end
	return want
end
function ns:QuickLootListening() return listening end

do
	local refresh = ns.RefreshOptions
	if refresh then
		function ns:RefreshOptions(...)
			pcall(self.QuickLootEvents, self)
			return refresh(self, ...)
		end
	end
end
ns.On("PLAYER_ENTERING_WORLD", OWNER, function() ns:QuickLootEvents() end, "quickloot:PLAYER_ENTERING_WORLD")

if ns.Mark then ns.Mark("QuickLoot") end
