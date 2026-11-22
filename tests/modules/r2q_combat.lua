-- Ready2Quest 1.38.0 : le module Combat. Le moteur repris de DoesItDiePlus
-- (Ready2Quest/Combat/, tools/sync_combat.py) n'est pas chargé par le harnais :
-- ici, il est compilé fichier par fichier et son import vérifié ; notre
-- intégration (CombatBoot.lua, Combat.lua) tourne avec un moteur simulé.
local Check, Say, NS = T.Check, T.Say, T.NS
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local load5 = rawget(_G, "loadstring") or load

local function ReadFile(path)
	local h = io.open(ROOT .. "/" .. path, "rb")
	if not h then return nil end
	local data = h:read("*a")
	h:close()
	return data
end

-- ---------------------------------------------------------------------------
-- 1. L'import
-- ---------------------------------------------------------------------------
do
	Say("-- combat : moteur importé")
	local list = ReadFile("Ready2Quest/Combat/files.txt") or ""
	local files, bad, leftovers, guards = {}, {}, {}, 0
	for line in list:gmatch("[^\r\n]+") do files[#files + 1] = line end
	for _, file in ipairs(files) do
		local src = ReadFile("Ready2Quest/Combat/" .. file)
		if not src then
			bad[#bad + 1] = file .. " absent"
		else
			local fn, err = load5(src, file)
			if not fn then bad[#bad + 1] = tostring(err) end
			-- le vrai nom de l'addon (trois modules comparent ADDON_LOADED à cette
			-- variable : avec un autre nom, ils ne démarraient jamais — bêta 1)
			if src:find('BIT = "Ready2Quest", (select(2, ...)).combat', 1, true) and src:find("if not BIT then return end", 1, true) then
				guards = guards + 1
			end
			if src:find('"Interface\\AddOns\\"%s*%.%.') then bad[#bad + 1] = file .. " : chemin construit avec le nom de l'addon" end
			for _, word in ipairs({ "UsefulPlatesAndTooltips", '"/upt"', '"/sdi"', '"/dotinfo"', "SlashCmdList%.BITDOTINFO" }) do
				if src:find(word) then leftovers[#leftovers + 1] = file .. ":" .. word end
			end
		end
	end
	Check("[COMBAT] moteur : les fichiers importés se compilent", #files >= 70 and #bad == 0,
		#files .. " fichiers ; " .. table.concat(bad, " | "))
	Check("[COMBAT] moteur : chaque fichier vit dans ns.combat et s'arrête sans lui", guards == #files, guards .. "/" .. #files)
	Check("[COMBAT] moteur : plus aucun nom global ni commande de DoesItDiePlus (pas de conflit s'il est installé)",
		#leftovers == 0, table.concat(leftovers, ", "))

	-- le TOC charge le moteur entre CombatBoot.lua et Combat.lua, dans l'ordre importé
	local toc = ReadFile("Ready2Quest/Ready2Quest.toc") or ""
	local lines = {}
	for line in toc:gmatch("[^\r\n]+") do lines[#lines + 1] = (line:gsub("\\", "/")) end
	local boot, first, last, glue
	for index, line in ipairs(lines) do
		if line == "CombatBoot.lua" then boot = index end
		if line == "Combat/" .. files[1] then first = index end
		if line == "Combat/" .. files[#files] then last = index end
		if line == "Combat.lua" then glue = index end
	end
	Check("[COMBAT] TOC : CombatBoot, le moteur dans l'ordre importé, puis Combat.lua ; ses variables sauvegardées",
		boot and first and last and glue and boot < first and last - first + 1 == #files and glue > last
		and toc:find("Ready2QuestCombatDB", 1, true) and toc:find("Ready2QuestCombat_DoTInfoDB", 1, true)
		and toc:find("Ready2QuestCombat_SpellDamageInfoDB", 1, true),
		tostring(boot) .. " " .. tostring(first) .. " " .. tostring(last) .. " " .. tostring(glue))

	-- textures appelées par le moteur : présentes, au chemin de Ready2Quest
	local missing, paths = {}, 0
	for _, file in ipairs(files) do
		local src = ReadFile("Ready2Quest/Combat/" .. file) or ""
		for dir in src:gmatch('"Interface\\\\AddOns\\\\Ready2Quest\\\\Combat\\\\([^"]-)\\\\"') do
			paths = paths + 1
			local probe = io.open(ROOT .. "/Ready2Quest/Combat/" .. dir:gsub("\\\\", "/"), "rb")
			if probe then probe:close() else
				-- un dossier : on vérifie qu'il contient au moins un fichier
				local listing = io.popen and io.popen('ls "' .. ROOT .. "/Ready2Quest/Combat/" .. dir:gsub("\\\\", "/") .. '" 2>/dev/null')
				local any = listing and listing:read("*l")
				if listing then listing:close() end
				if not any then missing[#missing + 1] = dir end
			end
		end
	end
	Check("[COMBAT] textures du moteur : dossiers présents sous Ready2Quest/Combat", paths > 0 and #missing == 0,
		table.concat(missing, ", "))
	Check("[COMBAT] crédit et licences recopiés", ReadFile("Ready2Quest/Combat/LICENSE") ~= nil
		and ReadFile("Ready2Quest/Combat/Modules/DoTInfo/LICENSE-DoesItDie.txt") ~= nil
		and (ReadFile("Ready2Quest/Combat/UPSTREAM.txt") or ""):find("Ironship/UsefulPlatesAndTooltips", 1, true) ~= nil)
end

-- ---------------------------------------------------------------------------
-- 2. CombatBoot : DoesItDiePlus ou Does It Die activé, notre moteur s'efface
-- ---------------------------------------------------------------------------
do
	Say("-- combat : détection de DoesItDiePlus")
	local src = ReadFile("Ready2Quest/CombatBoot.lua")
	local chunk = load5(src, "CombatBoot.lua")
	local saved = { C_AddOns = rawget(_G, "C_AddOns"), GetAddOnEnableState = rawget(_G, "GetAddOnEnableState"),
		IsAddOnLoaded = rawget(_G, "IsAddOnLoaded") }
	local function Boot(enabled, legacyOnly)
		if legacyOnly then
			_G.C_AddOns = nil
			_G.GetAddOnEnableState = function(_, name) return enabled[name] and 2 or 0 end
		else
			_G.C_AddOns = { IsAddOnLoaded = function() return false end,
				GetAddOnEnableState = function(name) return enabled[name] and 2 or 0 end }
		end
		local ns = {}
		chunk("Ready2Quest", ns)
		return ns
	end
	local none = Boot({})
	local plus = Boot({ UsefulPlatesAndTooltips = true })
	local original = Boot({ DoesItDie = true }, true)
	for k, v in pairs(saved) do _G[k] = v end
	Check("[COMBAT] CombatBoot : sans rival le moteur tourne ; DoesItDiePlus ou Does It Die (ancienne API aussi) : il s'efface",
		type(none.combat) == "table" and none.combatRival == nil and plus.combat == nil
		and plus.combatRival == "UsefulPlatesAndTooltips" and original.combat == nil and original.combatRival == "DoesItDie")
end

-- ---------------------------------------------------------------------------
-- 3. Combat.lua avec un moteur simulé
-- ---------------------------------------------------------------------------
local function Glue(engine, rival)
	local db, printed, strings = {}, {}, {}
	local ns = {
		combat = engine, combatRival = rival, OPTION_ACTIONS = {}, COMMANDS = {}, HELP = { { "HELP_H_OPEN", {} } },
		OPTION_PAGES = { { id = "general" }, { id = "merchant", group = "OPT_GROUP_QOL" },
			{ id = "aggro", group = "OPT_GROUP_QOL", parent = "qol" }, { id = "death", group = "OPT_GROUP_QOL" } },
		RegisterDefaults = function(defaults) for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end end,
		RegisterStrings = function(fr) for k, v in pairs(fr) do strings[k] = v end end,
	}
	ns.EXTRA_COMMANDS = ns.COMMANDS
	ns.L = setmetatable({}, { __index = function(_, k) return strings[k] or k end })
	ns.selected = {}
	function ns:ToggleOptions() self.optionsShown = true end
	function ns:SelectOptionsPage(id) self.selected[#self.selected + 1] = id end
	function ns:DB() return db end
	function ns:Print(msg) printed[#printed + 1] = msg end
	function ns:F(key, ...) return string.format(strings[key] or key, ...) end
	load5(ReadFile("Ready2Quest/Combat.lua"), "Combat.lua")("Ready2Quest", ns)
	return ns, db, printed
end

do
	Say("-- combat : nos interrupteurs, les pages, /r2q combat")
	local opened = {}
	local engine = { state = {}, OpenSettings = function(name) opened[#opened + 1] = tostring(name) end }
	function engine.ShouldRun(name) engine.state[name] = "on"; return true end
	local ns, db = Glue(engine)
	local order = {}
	for _, page in ipairs(ns.OPTION_PAGES) do order[#order + 1] = page.id end
	local aggro
	for _, page in ipairs(ns.OPTION_PAGES) do if page.id == "aggro" then aggro = page end end
	Check("[COMBAT] pages : la portée d'aggro quitte le confort de jeu, puis les quatre parties, groupe COMBAT",
		table.concat(order, ",") == "general,merchant,death,aggro,combatRange,combatDots,combatCast,combatBars"
		and aggro.group == "OPT_GROUP_COMBAT" and aggro.parent == nil, table.concat(order, ","))

	db.combatDots = false
	local dots, range = engine.ShouldRun("DoTInfo"), engine.ShouldRun("Range")
	Check("[COMBAT] interrupteur de Ready2Quest d'abord : DoT coupé, le moteur le laisse éteint ; la portée tourne",
		dots == false and engine.state.DoTInfo == "off" and range == true and engine.state.Range == "on")

	ns.COMMANDS.combat(ns, "dots")
	ns.COMMANDS.combat(ns, "")
	engine.OpenSettings("CastPrediction")
	Check("[COMBAT] /r2q combat [dots] et les portes du moteur (/r2qc, options du jeu) ouvrent NOS pages, sur la bonne partie",
		ns.optionsShown and table.concat(ns.selected, ",") == "combatDots,combatRange,combatCast" and #opened == 0
		and #ns.HELP[1][2] == 1, table.concat(ns.selected, ","))

	-- les réglages du moteur dans nos pages : lus et écrits dans ses tables
	local rows = ns.COMBAT_ROWS
	engine.Settings = function(name) engine.stores = engine.stores or {}; engine.stores[name] = engine.stores[name] or {}; return engine.stores[name] end
	_G.Ready2QuestCombat_DoTInfoDB = { showSkull = true }
	_G.Ready2QuestCombat_SpellDamageInfoDB = { button = "total" }
	local refreshed = 0
	engine.modules = { SpellDamageInfo = { Refresh = function() refreshed = refreshed + 1 end } }
	local function Row(page, key) for _, r in ipairs(rows[page]) do if r.key == key then return r end end end
	Row("combatRange", "showOut").store().showOut = false
	local skull = Row("combatDots", "skullPosition")
	skull.choose("above")
	local button = Row("combatBars", "button")
	button.choose("dps")
	local labels = {}
	for _, c in ipairs(button.choices()) do labels[#labels + 1] = c.label end
	Check("[COMBAT] réglages du moteur dans nos pages : portée, DoT (crâne), barres (chiffre, rafraîchi), libellés traduits",
		engine.stores.Range.showOut == false and _G.Ready2QuestCombat_DoTInfoDB.skullPosition == "above"
		and _G.Ready2QuestCombat_SpellDamageInfoDB.button == "dps" and refreshed == 1 and skull.current() == "above"
		and labels[3] == "Par seconde" and #rows.combatRange >= 4 and #rows.combatDots >= 6 and #rows.combatCast >= 6
		and #rows.combatBars >= 5, table.concat(labels, ","))
	_G.Ready2QuestCombat_DoTInfoDB, _G.Ready2QuestCombat_SpellDamageInfoDB = nil, nil

	local printed = {}
	ns.Print = function(_, msg) printed[#printed + 1] = msg end
	local pending = 0
	ns.MarkReloadPending = function() pending = pending + 1 end
	ns:OnModuleToggled("combatBars", false)
	ns:OnModuleToggled("autoSellGray", false)
	Check("[COMBAT] un interrupteur du Combat rappelle le rechargement (chat, bouton du pied), pas les autres", #printed == 1
		and printed[1]:find("reload", 1, true) ~= nil and pending == 1 and ns.OPTION_ACTIONS.combatReload == nil,
		table.concat(printed, " | "))
end

do
	Say("-- combat : une seule icône au-dessus de la cible")
	local window = CreateFrame("Frame")
	local state = "in"
	local stores = { Range = { offset = 56, size = 26, showOut = true } }
	local engine = { state = {}, Settings = function(name) stores[name] = stores[name] or {}; return stores[name] end,
		Plate = { HealthBar = function() return { GetFrameStrata = function() return "LOW" end } end },
		modules = { Range = { Check = function() return state end },
			DoTInfo = { barMarker = { widgetsFor = function() return { iconWindow = window } end } } } }
	engine.ShouldRun = function() return true end
	local ns, db = Glue(engine)
	local savedPlate = rawget(_G, "C_NamePlate")
	_G.C_NamePlate = { GetNamePlateForUnit = function() return {} end }
	_G.Ready2QuestCombat_DoTInfoDB = { nameplateIconPosition = "right" }
	local w = nil
	engine.modules.DoTInfo.barMarker.widgetsFor = function() w = w or { iconWindow = window }; return w end
	local first = ns:CombatIconsTick()
	local dots = _G.Ready2QuestCombat_DoTInfoDB
	local aligned = dots.nameplateIconPosition == "above" and dots.plateIconOffsetY == 52 and dots.plateIconOffsetX == 0
		and dots.nameplateIconSize == 28
	local strata = window.strata or (window.GetFrameStrata and window:GetFrameStrata())
	state = "out"
	local out = ns:CombatIconsTick()
	local hiddenAlpha = window.alpha
	state = "in"
	ns:CombatIconsTick()
	local back = window.alpha
	db.combatOneIcon = false
	state = "out"
	local off = ns:CombatIconsTick()
	_G.C_NamePlate, _G.Ready2QuestCombat_DoTInfoDB = savedPlate, nil
	Check("[COMBAT] une icône : crâne/arme à la place de la coche (même hauteur, un peu plus grands, une strate au-dessus) ; hors de portée masqués, la croix revient ; réglage coupé : rien",
		first == "in" and aligned and strata == "MEDIUM" and out == "out" and hiddenAlpha == 0 and back == 1 and off == nil,
		tostring(strata) .. " " .. tostring(hiddenAlpha) .. " " .. tostring(back))
end

do
	Say("-- combat : DoesItDiePlus installé")
	local ns = Glue(nil, "UsefulPlatesAndTooltips")
	local printed = {}
	ns.Print = function(_, msg) printed[#printed + 1] = msg end
	local opened = ns:CombatOpenPage("combatRange")
	local page
	for _, def in ipairs(ns.OPTION_PAGES) do if def.id == "combatDots" then page = def end end
	local first = type(page.info[1]) == "function" and page.info[1]() or ""
	Check("[COMBAT] rival : nos pages s'ouvrent, le chat et chaque page le disent (la portée d'aggro reste)",
		opened == false and printed[1]:find("DoesItDiePlus", 1, true) ~= nil and first:find("DoesItDiePlus", 1, true) ~= nil
		and not ns:CombatPartOn(ns.COMBAT_PARTS[1]), first)
end

-- 3a. 2.1.0 bêta 3 : plus de grandes icônes sur le cadre de la cible (par défaut)
do
	Say("-- combat : grandes icônes du cadre de la cible")
	local parents = {}
	local function Icon(name)
		local f = { name = name }
		function f:SetParent(p) parents[name] = p end
		_G[name] = f
	end
	Icon("Ready2QuestCombat_DoTInfoSkull"); Icon("Ready2QuestCombat_CastPredictionKill")
	local engine = { state = {}, ShouldRun = function() return true end }
	local ns, db = Glue(engine)
	local skull, kill = parents.Ready2QuestCombat_DoTInfoSkull, parents.Ready2QuestCombat_CastPredictionKill
	local hidden = skull ~= nil and skull == kill and skull ~= UIParent and not skull:IsShown()
	local row
	for _, r in ipairs(ns.COMBAT_ROWS.combatDots) do if r.key == "combatFrameIcons" then row = r end end
	db.combatFrameIcons = true
	row.onChange(true)
	local back = parents.Ready2QuestCombat_DoTInfoSkull == UIParent and parents.Ready2QuestCombat_CastPredictionKill == UIParent
	_G.Ready2QuestCombat_DoTInfoSkull, _G.Ready2QuestCombat_CastPredictionKill = nil, nil
	Check("[COMBAT] cadre de la cible : crâne et icône du sort qui tue rangés sous un cadre caché par défaut ; le réglage les rend",
		db.combatFrameIcons == true and hidden and back)
end

-- 3b. 2.1.0 : Mot de l'ombre : Mort sans retour (CombatDeath.lua)
do
	Say("-- combat : Mot de l'ombre : Mort")
	local db = { combatDots = true }
	local plate, bar = {}, nil
	local rangeState = "in"
	local engine = { Plate = { HealthBar = function() return { GetFrameStrata = function() return "LOW" end,
		GetFrameLevel = function() return 10 end } end }, modules = { Range = { Check = function() return rangeState end } } }
	local ns = { combat = engine, RegisterDefaults = function(d) for k, v in pairs(d) do if db[k] == nil then db[k] = v end end end }
	function ns:DB() return db end
	load5(ReadFile("Ready2Quest/CombatDeath.lua"), "CombatDeath.lua")("Ready2Quest", ns)
	local saved = {}
	for _, k in ipairs({ "IsPlayerSpell", "UnitLevel", "GetSpellBonusDamage", "UnitExists", "UnitIsDead", "UnitCanAttack",
		"C_NamePlate", "UnitHealth", "C_Spell", "Ready2QuestCombat_DoTInfoDB", "CreateFrame", "Ready2QuestCombat_RangeIcon",
		"GetTime", "hooksecurefunc" }) do saved[k] = rawget(_G, k) end
	local known = {}
	_G.IsPlayerSpell = function(id) return known[id] == true end
	_G.UnitLevel = function() return 44 end
	_G.GetSpellBonusDamage = function(school) return school == 6 and 100 or 0 end
	-- le rang : aucun, puis le plus haut appris
	local none = ns:ShadowDeathRank()
	known[1309595], known[1309633] = true, true
	local rank = ns:ShadowDeathRank()
	-- rang 2 au niveau 44 : (370 + 1,9 × 4) × (1 - 0,0605) + 0,429 × 100 ; puis plafonné au niveau 45
	local want = (370 + 1.9 * 4) * (1 - 0.0605) + 42.9
	local damage = ns:ShadowDeathDamage(rank, 44, 100)
	local capped = ns:ShadowDeathDamage(rank, 60, 0)
	_G.Ready2QuestCombat_DoTInfoDB = { killMargin = 80, nameplateIconPosition = "above", plateIconOffsetX = 0, plateIconOffsetY = 52,
		nameplateIconSize = 28 }
	local lethal = ns:ShadowDeathLethal()
	Check("[COMBAT] Mot de l'ombre : Mort : rang appris le plus haut, dégâts au bas de la fourchette (niveau plafonné), marge des DoT",
		none == nil and rank and rank.id == 1309633 and math.abs(damage - want) < 0.01
		and math.abs(capped - (370 + 1.9 * 5) * (1 - 0.0605)) < 0.01 and math.abs(lethal - want * 0.8) < 0.01,
		tostring(damage) .. " / " .. tostring(lethal))

	-- le passage : une barre invisible reçoit max = vie (secrète), valeur = dégâts sûrs
	local frames = {}
	_G.CreateFrame = function(kind)
		local f = { kind = kind, shown = false, points = {} }
		function f:SetClipsChildren() end
		function f:Hide() self.shown = false end
		function f:Show() self.shown = true end
		function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
		function f:ClearAllPoints() self.points = {} end
		function f:SetSize(w, h) self.w, self.h = w, h end
		function f:SetFrameStrata(s) self.strata = s end
		function f:SetFrameLevel(l) self.level = l end
		function f:SetParent(p) self.parent = p end
		function f:GetParent() return self.parent end
		function f:SetStatusBarTexture() end
		function f:SetStatusBarColor() end
		function f:GetStatusBarTexture() return {} end
		function f:SetMinMaxValues(a, b) self.min, self.max = a, b end
		function f:SetValue(v) self.value = v end
		function f:CreateTexture()
			local t = {}
			function t:SetPoint() end
			function t:SetTexture(x) self.texture = x end
			function t:SetSize() end
			function t:SetDesaturated(d) self.desaturated = d end
			function t:SetAlpha(a) self.alpha = a end
			f.icon = t
			return t
		end
		frames[#frames + 1] = f
		return f
	end
	_G.UnitExists = function() return true end
	_G.UnitIsDead = function() return false end
	_G.UnitCanAttack = function() return true end
	_G.UnitHealth = function() return 300 end
	_G.C_NamePlate = { GetNamePlateForUnit = function() return plate end }
	_G.C_Spell = { GetSpellCooldown = function() return { startTime = 0, duration = 0 } end }
	-- la coche de portée (nom global donné à l'import) : un cadre à cacher
	local check = { parent = plate }
	function check:SetParent(p) self.parent = p; for _, h in ipairs(self.hooks or {}) do h(self, p) end end
	function check:GetParent() return self.parent end
	_G.Ready2QuestCombat_RangeIcon = check
	_G.hooksecurefunc = function(obj, method, fn)
		if obj == check and method == "SetParent" then check.hooks = check.hooks or {}; table.insert(check.hooks, fn) end
	end
	local now = 100
	_G.GetTime = function() return now end
	local shown = ns:ShadowDeathTick()
	local window, statusBar, curtain = frames[1], frames[2], frames[3]
	local held = check.parent == curtain and curtain ~= nil and window.parent == plate and curtain.parent == plate
	check:SetParent(plate)          -- le moteur la replace : elle revient derrière le rideau
	local heldAgain = check.parent == curtain
	-- la recharge comptée par Ready2Quest : un lancer réussi, 18 s (le jeu la cache)
	local castOk = ns:ShadowDeathCast("player", "x", 1309633)
	local castOther = ns:ShadowDeathCast("player", "x", 589)
	local selfCooling = ns:ShadowDeathTick()
	local released = check.parent == plate
	now = 119
	local afterCd = ns:ShadowDeathTick()
	ns.shadowDeathCastAt = nil
	_G.C_Spell = { GetSpellCooldown = function() return { startTime = 10, duration = 18 } end }
	local cooling = ns:ShadowDeathTick()
	local hiddenCooling = window and window.shown
	_G.C_Spell = { GetSpellCooldown = function() return { startTime = 10, duration = 1.5 } end }
	local gcd = ns:ShadowDeathTick()
	rangeState = "out"
	local out = ns:ShadowDeathTick()
	rangeState = "in"
	_G.C_NamePlate = { GetNamePlateForUnit = function() return nil end }
	local noPlate = ns:ShadowDeathTick()
	local hiddenNoPlate = window and window.shown
	_G.C_NamePlate = { GetNamePlateForUnit = function() return plate end }
	db.combatDeath = false
	local off = ns:ShadowDeathTick()
	db.combatDeath = true
	known = {}
	local notPriest = ns:ShadowDeathTick()
	for k, v in pairs(saved) do _G[k] = v end
	Check("[COMBAT] Mot de l'ombre : Mort : à la place du crâne, rattachée à la barre de nom, la coche derrière un rideau (et y revient), rendue en recharge ; recharge comptée au lancer (18 s) ; deux strates au-dessus de la barre, 4 px de plus (vie en max, dégâts sûrs en valeur) ; en recharge (pas le temps global), hors de portée, sans barre de nom, coupée ou sans le sort : cachée",
		shown == "shown" and window and statusBar and statusBar.max == 300 and math.abs(statusBar.value - lethal) < 0.01
		and window.points[1] and window.points[1][1] == "BOTTOM" and window.points[1][3] == "TOP" and window.points[1][5] == 56
		and window.w == 32 and window.strata == "HIGH" and window.level == 50 and statusBar.icon.texture == 136149
		and cooling == "cooling" and hiddenCooling == false and gcd == "shown" and out == "hidden" and noPlate == "hidden" and hiddenNoPlate == false
		and off == "hidden" and notPriest == "hidden" and held and heldAgain and castOk and not castOther
		and selfCooling == "cooling" and released and afterCd == "shown",
		tostring(shown) .. " " .. tostring(cooling) .. " " .. tostring(gcd) .. " " .. tostring(noPlate))
end

-- 4. Dans le vrai Ready2Quest : les pages et la commande sont là
do
	local ids = {}
	for _, page in ipairs(NS.OPTION_PAGES or {}) do ids[page.id] = page.group end
	Check("[COMBAT] Ready2Quest : groupe COMBAT (aggro + 4 parties), /r2q combat", ids.aggro == "OPT_GROUP_COMBAT"
		and ids.combatRange == "OPT_GROUP_COMBAT" and ids.combatBars == "OPT_GROUP_COMBAT"
		and type((NS.COMMANDS or NS.EXTRA_COMMANDS or {}).combat) == "function")
end

-- 4b. Le pied des réglages : « Recharger l'interface » seulement quand un réglage l'attend
do
	T.ResetWorld()
	NS.optionsFrame, NS.reloadPending = nil, nil
	NS:ToggleOptions()
	local frame = NS.optionsFrame
	local before = frame.reloadButton and frame.reloadButton:IsShown()
	NS:MarkReloadPending()
	local after = frame.reloadButton:IsShown()
	local reloaded = false
	local saved = rawget(_G, "ReloadUI")
	_G.ReloadUI = function() reloaded = true end
	frame.reloadButton:GetScript("OnClick")(frame.reloadButton)
	_G.ReloadUI = saved
	NS.reloadPending = nil
	frame:Hide()
	Check("[COMBAT] pied des réglages : « Recharger l'interface » caché, puis montré quand un réglage l'attend ; il recharge",
		frame.reloadButton ~= nil and before == false and after == true and reloaded
		and frame.reloadButton:GetText() == "Recharger l'interface")
end
