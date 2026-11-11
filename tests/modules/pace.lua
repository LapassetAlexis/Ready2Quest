-- Module « Rythme de leveling » (v1.24.0) : XP/h (session, fenêtre glissante),
-- passage de niveau, monstres et quêtes restants, temps avant le niveau,
-- repos, /r2q xp, infobulle de la barre d'XP, niveau max, module coupé.
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

-- Globales du client absentes du harnais : posées ici, restaurées en fin de fichier
local saved = {
	UnitXP = rawget(_G, "UnitXP"),
	COMBATLOG_XPGAIN_FIRSTPERSON = rawget(_G, "COMBATLOG_XPGAIN_FIRSTPERSON"),
	COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = rawget(_G, "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED"),
	MainMenuExpBar = rawget(_G, "MainMenuExpBar"),
	MainStatusTrackingBarContainer = rawget(_G, "MainStatusTrackingBarContainer"),
}
_G.UnitXP = function() return Mock.world.xp or 0 end

local P = {}   -- une seule locale pour les aides (limite de 200 locales)

function P.Reset()
	ResetWorld()
	Mock.world.level, Mock.world.xp, Mock.world.xpMax, Mock.world.rested = 20, 1000, 10000, 0
	NS:PaceReset()
	GameTooltip:ClearLines()
	GameTooltip.shown = false
end

-- un gain d'XP : la valeur monte, le client le signale
function P.Gain(amount, after)
	if after then Mock.now = Mock.now + after end
	local x = Mock.world.xp + amount
	if x >= Mock.world.xpMax then
		x = x - Mock.world.xpMax
		Mock.world.level = Mock.world.level + 1
		Mock:Fire("PLAYER_LEVEL_UP", Mock.world.level)
	end
	Mock.world.xp = x
	Mock:Fire("PLAYER_XP_UPDATE", "player")
end

function P.Has(text, needle) return tostring(text):find(needle, 1, true) ~= nil end
function P.Tip() return table.concat(GameTooltip.lines or {}, "\n") end

-- 1. Chaînes ------------------------------------------------------------------
do
	local strings = NS.PACE_STRINGS
	local missing, mismatch = {}, {}
	local function Placeholders(text)
		local list = {}
		for p in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = p end
		return table.concat(list, ",")
	end
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then missing[#missing + 1] = "en:" .. key end
		if value == "" or NS.L[key] ~= value then missing[#missing + 1] = "fr:" .. key end
		if Placeholders(value) ~= Placeholders(strings.en[key]) then mismatch[#mismatch + 1] = key end
	end
	for key in pairs(strings.en) do
		if strings.fr[key] == nil then missing[#missing + 1] = "fr?" .. key end
	end
	local formatErrors = {}
	for _, lang in ipairs({ "fr", "en" }) do
		for key, value in pairs(strings[lang]) do
			local args = {}
			for spec in value:gsub("%%%%", ""):gmatch("%%[%d%$]*([sd])") do args[#args + 1] = spec == "d" and 1 or "x" end
			if not pcall(string.format, value, unpack(args)) then formatErrors[#formatErrors + 1] = lang .. ":" .. key end
		end
	end
	Check("[PACE] chaînes fr/en, mêmes placeholders, toutes se formatent", #missing == 0 and #mismatch == 0 and #formatErrors == 0,
		table.concat(missing, ", ") .. " / " .. table.concat(mismatch, ", ") .. " / " .. table.concat(formatErrors, ", "))
	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "pace" then page = def end end
	local inHelp = false
	for _, key in ipairs(NS.HELP[1][2]) do if key == "HELP_PACE" then inHelp = true end end
	Check("[PACE] module inscrit (alias xp), sous-page QoL, défauts (actif, infobulle, 30 min), dans l'aide",
		NS:FindModule("xp") and NS:FindModule("xp").id == "pace"
		and page and page.parent == "qol" and page.group == "OPT_GROUP_QOL" and #page.rows == 3
		and NS:DB().paceEnabled == true and NS:DB().paceTooltip == true and NS:DB().paceWindow == 30 and inHelp)
end

-- 2. XP/h : session et fenêtre glissante -------------------------------------
do
	P.Reset()
	local session, recent = NS:PaceXPPerHour()
	Check("[PACE] trop tôt : pas de taux", session == nil and recent == nil)
	-- 60 min de session : 3000 XP pendant la première demi-heure, 1000 dans la seconde
	P.Gain(1500, 300); P.Gain(1500, 900)        -- t = 5 min et 20 min
	P.Gain(1000, 1800)                            -- t = 50 min
	Mock.now = Mock.now + 600                     -- t = 60 min
	session, recent = NS:PaceXPPerHour()
	Check("[PACE] XP/h de la session et des 30 dernières minutes", math.floor(session + 0.5) == 4000
		and math.floor(recent + 0.5) == 2000, session .. " / " .. recent)
	NS:DB().paceWindow = 60
	local _, hour = NS:PaceXPPerHour(60 * 60)
	NS:DB().paceWindow = 15
	local _, quarter = NS:PaceXPPerHour(15 * 60)
	-- seul le gain de la 50e minute tombe dans le dernier quart d'heure
	Check("[PACE] fenêtres de 60 et 15 min", math.floor(hour + 0.5) == 4000 and math.floor(quarter + 0.5) == 4000,
		hour .. " / " .. quarter)
	NS:DB().paceWindow = 30

	-- début de session : la fenêtre ne dépasse pas le temps écoulé
	P.Reset()
	P.Gain(500, 300)
	Mock.now = Mock.now + 300
	session, recent = NS:PaceXPPerHour(30 * 60)
	Check("[PACE] fenêtre tronquée au temps écoulé (10 min)", math.floor(recent + 0.5) == 3000, recent)
end

-- 3. Passage de niveau --------------------------------------------------------
do
	P.Reset()
	Mock.world.xp = 9500
	NS:PaceReset()
	P.Gain(800, 120)          -- 500 pour finir le niveau, 300 dans le suivant
	Check("[PACE] passage de niveau : XP comptée", NS.pace.total == 800 and Mock.world.level == 21, NS.pace.total)
	-- le niveau suivant est plus long : UnitXPMax change après coup
	Mock.world.xpMax = 12000
	P.Gain(200, 10)
	Check("[PACE] après le niveau : gains suivants normaux", NS.pace.total == 1000, NS.pace.total)
end

-- 4. Monstres : messages du client, fr et en ---------------------------------
do
	P.Reset()
	-- sans globales : repli fr/en
	_G.COMBATLOG_XPGAIN_FIRSTPERSON, _G.COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = nil, nil
	local bad = {}
	for _, case in ipairs({
		{ "Kobold vermin dies, you gain 45 experience.", 45, true },
		{ "Kobold vermin dies, you gain 90 experience. (45 exp Rested bonus)", 90, true },   -- bonus de repos ignoré
		{ "Murloc dies, you gain 30 experience. (+6 group bonus)", 30, true },              -- l'XP est la 1re valeur
		{ "Vermine kobold meurt, vous gagnez 45 points d'expérience.", 45, true },
		{ "Vous gagnez 12 points d'expérience.", 12, false },
		{ "Vous recevez le butin : [Os].", nil, nil },
	}) do
		local xp, named = NS:ParseCombatXP(case[1])
		if xp ~= case[2] or (case[2] and named ~= case[3]) then bad[#bad + 1] = case[1] .. " -> " .. tostring(xp) end
	end
	Check("[PACE] messages fr/en : nommé ou non, bonus ignorés, sans rapport ignoré", #bad == 0, table.concat(bad, " | "))
	local xp, named
	-- chaîne du client positionnelle (traduction qui inverse l'ordre)
	_G.COMBATLOG_XPGAIN_FIRSTPERSON = "Gain de %2$d XP : %1$s est mort."
	xp, named = NS:ParseCombatXP("Gain de 77 XP : Loup est mort.")
	Check("[PACE] chaîne du client positionnelle", xp == 77 and named == true, tostring(xp))
	_G.COMBATLOG_XPGAIN_FIRSTPERSON = saved.COMBATLOG_XPGAIN_FIRSTPERSON

	-- moyenne des derniers monstres -> nombre de monstres restants
	for _ = 1, 4 do
		Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup dies, you gain 100 experience.")
		P.Gain(100, 30)
	end
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Sanglier meurt, vous gagnez 200 points d'expérience.")
	P.Gain(200, 30)
	local card = NS:PaceCard()
	-- 1000 + 600 = 1600 / 10000 : 8400 restants, moyenne 120 -> 70 monstres
	Check("[PACE] monstres restants (moyenne fr + en), pas encore d'estimation des quêtes", card and card.kills == 70
		and card.quests == nil, card and card.kills)
end

-- 5. Quêtes : QUEST_TURNED_IN, puis repli sur l'écran de récompense ---------
do
	P.Reset()
	Mock:Fire("QUEST_COMPLETE")
	Mock:Fire("QUEST_TURNED_IN", 42, 1400, 500)
	P.Gain(1400, 0)
	Check("[PACE] quête : XP de QUEST_TURNED_IN, pas comptée deux fois", #NS.pace.quests == 1
		and NS.pace.quests[1].xp == 1400, #NS.pace.quests)
	-- gain avant l'événement : la valeur exacte remplace l'estimation
	Mock.now = Mock.now + 10
	Mock:Fire("QUEST_COMPLETE"); Mock:Fire("QUEST_FINISHED")
	P.Gain(1000, 1)
	Mock:Fire("QUEST_TURNED_IN", 43, 1000, 0)
	Check("[PACE] quête : gain puis événement = une seule entrée", #NS.pace.quests == 2 and NS.pace.quests[2].xp == 1000,
		#NS.pace.quests)
	-- repli : pas d'XP dans l'événement (client qui ne la donne pas)
	Mock:Fire("QUEST_COMPLETE")
	Mock.now = Mock.now + 20
	Mock:Fire("QUEST_TURNED_IN", 44, 0, 0)
	Mock:Fire("QUEST_FINISHED")
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Vous gagnez 1600 points d'expérience.")
	P.Gain(1600, 1)
	Check("[PACE] repli : premier gain après la récompense, le message sans nom n'est pas un monstre", #NS.pace.quests == 3
		and NS.pace.quests[3].xp == 1600 and #NS.pace.kills == 0, #NS.pace.kills)
	-- un monstre tué après la fenêtre n'est pas une quête
	Mock.now = Mock.now + 10
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 100 points d'expérience.")
	P.Gain(100, 0)
	local outside = #NS.pace.quests == 3 and #NS.pace.kills == 1
	-- écran de récompense ouvert, mais l'XP vient d'un monstre
	Mock:Fire("QUEST_COMPLETE")
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 100 points d'expérience.")
	P.Gain(100, 0)
	Check("[PACE] monstre hors récompense ou pendant la récompense : pas une quête", outside and #NS.pace.quests == 3)
	Mock:Fire("QUEST_FINISHED")
	Mock.now = Mock.now + 30
	local card = NS:PaceCard()
	-- xp = 1000 + 1400 + 1000 + 1600 + 200 = 5200 ; 4800 restants ; moyenne 4000/3
	Check("[PACE] quêtes restantes", card and card.quests == 4, card and card.quests)
	-- on ne garde que les 5 dernières
	for i = 1, 6 do Mock:Fire("QUEST_TURNED_IN", 100 + i, 10 * i, 0); Mock.now = Mock.now + 5 end
	Check("[PACE] 5 dernières quêtes seulement", #NS.pace.quests == 5 and NS.pace.quests[1].xp == 20)
end

-- 6. Temps avant le niveau ----------------------------------------------------
do
	P.Reset()
	P.Gain(2000, 600)                 -- 2000 XP en 30 min -> 4000 XP/h
	Mock.now = Mock.now + 1200
	local card = NS:PaceCard()
	-- 7000 restants à 4000/h = 1 h 45
	Check("[PACE] temps estimé, durée lisible", card and math.floor(card.seconds + 0.5) == 6300
		and NS:PaceDuration(6300) == "1 h 45" and NS:PaceDuration(600) == "10 min", card and card.seconds)
end

-- 7. Repos : auberge, dehors, plafond ----------------------------------------
do
	P.Reset()
	Mock.world.rested = 2500           -- 25 % du niveau
	Mock.world.resting = true
	local rest = NS:PaceRest()
	-- 5 % par 8 h -> 15 % en 24 h
	Check("[PACE] repos restant 25 %, auberge : +15 % d'ici demain", math.floor(rest.pct + 0.5) == 25
		and math.abs(rest.gain - 15) < 0.001, rest.gain)
	Mock.world.resting = false
	rest = NS:PaceRest()
	Check("[PACE] dehors : quatre fois moins (3,75 %)", math.abs(rest.gain - 3.75) < 0.001 and math.abs(rest.gainInn - 15) < 0.001,
		rest.gain)
	Check("[PACE] pourcentage à la française", NS.PacePct(3.75) == "3,8" and NS.PacePct(15) == "15", NS.PacePct(3.75))
	Mock.world.rested = 14000          -- 140 % : il ne reste que 10 %
	Mock.world.resting = true
	rest = NS:PaceRest()
	Check("[PACE] plafond 150 % : gain limité", math.abs(rest.gain - 10) < 0.001, rest.gain)
	Mock.world.rested = 15000
	rest = NS:PaceRest()
	Mock:Reset()
	NS:HandleCommand("xp")
	Check("[PACE] au plafond : rien à gagner, /r2q xp le dit", rest.gain == 0 and rest.capped
		and P.Has(Mock:Output(), "Repos au maximum"), Mock:Output())
	Mock.world.rested = nil            -- GetXPExhaustion renvoie nil sans repos
	rest = NS:PaceRest()
	Check("[PACE] sans repos : 0 %", rest.pct == 0)
end

-- 8. /r2q xp ------------------------------------------------------------------
do
	P.Reset()
	Mock.world.rested = 2500
	Mock.world.resting = false
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 100 points d'expérience.")
	P.Gain(100, 30)
	Mock.now = Mock.now + 60
	Mock:Reset()
	NS:HandleCommand("xp")
	local out = Mock:Output()
	local missing = {}
	for _, part in ipairs({ "Rythme de leveling", "XP/h", "(session)", "(30 min)", "8 900 XP", "~89 monstre(s)",
		"+3,8 % d'un niveau d'ici demain (+15 % à l'auberge)" }) do
		if not P.Has(out, part) then missing[#missing + 1] = part end
	end
	Check("[PACE] /r2q xp : titre, XP/h, XP restante, monstres, projection ; pas de camp hors du camp", #missing == 0
		and not P.Has(out, "Au camp"), table.concat(missing, " / ") .. " :: " .. out)
	-- au camp (Forever)
	Mock.world.auras[1283391] = { name = "Campfire Nearby" }
	NS.atCampAt = nil   -- 1.32.1 : AtCamp lu une fois par image, la maquette ne bouge pas l'horloge
	Mock:Reset()
	NS:HandleCommand("xp")
	Check("[PACE] au camp : information de la tente", P.Has(Mock:Output(), "tente de camp"), Mock:Output())
	Mock.world.auras[1283391] = nil
	NS.atCampAt = nil
	Mock:Reset()
	NS:HandleCommand("inconnue")
	Check("[PACE] commande inconnue toujours signalée", P.Has(Mock:Output(), "Commande inconnue"))
end

-- 9. Infobulle de la barre d'XP ----------------------------------------------
do
	P.Reset()
	P.Gain(500, 120)
	-- Era : MainMenuExpBar n'ouvre pas d'infobulle, on ouvre la nôtre
	_G.MainMenuExpBar = CreateFrame("StatusBar", "MainMenuExpBar")
	local hooked = NS:PaceHookXPBar()
	Check("[PACE] barre d'XP d'Era accrochée, pas deux fois", hooked == 1 and MainMenuExpBar.hooks
		and MainMenuExpBar.hooks.OnEnter ~= nil and NS:PaceHookXPBar() == 0, hooked)
	MainMenuExpBar.hooks.OnEnter(MainMenuExpBar)
	local tip = P.Tip()
	Check("[PACE] survol : lignes ajoutées", GameTooltip.shown and P.Has(tip, "Rythme de leveling")
		and P.Has(tip, "Prochain niveau") and P.Has(tip, "Repos"), tip)
	MainMenuExpBar.hooks.OnLeave(MainMenuExpBar)
	Check("[PACE] sortie : notre infobulle refermée", GameTooltip.shown == false)
	-- infobulle déjà ouverte par la barre (Forever) : on complète sans effacer
	GameTooltip:ClearLines()
	GameTooltip:AddLine("XP 1500 / 10000")
	GameTooltip.shown = true
	GameTooltip.GetOwner = function() return MainMenuExpBar end
	MainMenuExpBar.hooks.OnEnter(MainMenuExpBar)
	tip = P.Tip()
	MainMenuExpBar.hooks.OnLeave(MainMenuExpBar)
	Check("[PACE] infobulle du client complétée sans effacer, laissée au client", P.Has(tip, "XP 1500 / 10000")
		and P.Has(tip, "Rythme de leveling") and GameTooltip.shown == true, tip)
	GameTooltip.GetOwner = nil
	-- réglage : infobulle coupée
	NS:DB().paceTooltip = false
	GameTooltip:ClearLines(); GameTooltip.shown = false
	MainMenuExpBar.hooks.OnEnter(MainMenuExpBar)
	Check("[PACE] infobulle coupée : rien", #(GameTooltip.lines or {}) == 0 and not GameTooltip.shown)
	NS:DB().paceTooltip = true
	-- Forever (code retail) : la barre d'XP dans le conteneur
	_G.MainMenuExpBar = nil
	local container = CreateFrame("Frame", "MainStatusTrackingBarContainer")
	local rep = CreateFrame("StatusBar")
	local exp = CreateFrame("StatusBar")
	exp.ExhaustionLevelFillBar = CreateFrame("StatusBar")
	container.bars = { rep, exp }
	_G.MainStatusTrackingBarContainer = container
	hooked = NS:PaceHookXPBar()
	Check("[PACE] Forever : seule la barre d'XP du conteneur", hooked == 1 and exp.hooks and exp.hooks.OnEnter
		and not rep.hooks and not container.hooks, hooked)
	-- conteneur sans barre reconnaissable : le conteneur lui-même
	local plain = CreateFrame("Frame", "MainStatusTrackingBarContainer")
	_G.MainStatusTrackingBarContainer = plain
	local fallback = NS:PaceHookXPBar() == 1 and plain.hooks and plain.hooks.OnEnter
	_G.MainStatusTrackingBarContainer = nil
	Check("[PACE] repli : conteneur accroché ; aucune barre : rien, sans erreur", fallback and NS:PaceHookXPBar() == 0)
end

-- 10. Niveau maximum et module coupé : silence --------------------------------
do
	P.Reset()
	P.Gain(500, 120)
	local bar = CreateFrame("StatusBar", "MainMenuExpBar")
	_G.MainMenuExpBar = bar
	NS:PaceHookXPBar()
	Mock.world.level = 60
	local card = NS:PaceCard()
	bar.hooks.OnEnter(bar)
	local tipIntact = #(GameTooltip.lines or {}) == 0 and not GameTooltip.shown
	Mock.world.xp = 0
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 100 points d'expérience.")
	Mock:Fire("PLAYER_XP_UPDATE", "player")
	Mock:Reset()
	NS:HandleCommand("xp")
	Check("[PACE] niveau 60 : ni fiche ni infobulle ni suivi, « Niveau maximum » dans le chat", card == nil and tipIntact
		and (NS.pace == nil or #NS.pace.kills == 0) and P.Has(Mock:Output(), "Niveau maximum")
		and not P.Has(Mock:Output(), "XP/h"), Mock:Output())

	P.Reset()
	P.Gain(500, 120)
	NS:HandleCommand("module pace off")
	local off = NS:DB().paceEnabled == false and NS:PaceCard() == nil
	GameTooltip:ClearLines(); GameTooltip.shown = false
	bar.hooks.OnEnter(bar)
	tipIntact = #(GameTooltip.lines or {}) == 0 and not GameTooltip.shown
	Mock:Reset()
	NS:HandleCommand("xp")
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 100 points d'expérience.")
	Check("[PACE] /r2q module pace off : ni fiche ni infobulle ni suivi, la commande le dit", off and tipIntact
		and not P.Has(Mock:Output(), "XP/h") and P.Has(Mock:Output(), "coupé") and NS.pace == nil, Mock:Output())
	-- reprise : l'XP gagnée pendant la coupure n'est pas comptée d'un bloc
	Mock.world.xp = 5000
	NS:HandleCommand("module pace on")
	Mock:Fire("PLAYER_XP_UPDATE", "player")     -- premier relevé après la reprise : la base
	P.Gain(100, 10)
	Check("[PACE] reprise : suivi reparti de zéro", NS.pace and NS.pace.total == 100, NS.pace and NS.pace.total)
	NS:DB().enabled = false
	Check("[PACE] addon coupé : pas de fiche", NS:PaceCard() == nil)
	NS:DB().enabled = true
	_G.MainMenuExpBar = nil
end

-- 11. Page de réglages --------------------------------------------------------
do
	P.Reset()
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("pace")
	Check("[PACE] page de réglages construite", NS.optionsFrame.pages.pace ~= nil)
	if NS.optionsFrame then NS.optionsFrame:Hide() end
	NS.optionsFrame = nil
end

for name, value in pairs(saved) do _G[name] = value end
NS.pace = nil
