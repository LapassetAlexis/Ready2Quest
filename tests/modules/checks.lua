-- Lignes du Check avant le départ : métiers au plafond (Professions.lua,
-- 1.30.0), quêtes de voyage pas « prêtes à rendre » (1.30.0), lignes entières
-- avec infobulle et colonne des libellés (1.31.0), liste complète des buffs,
-- « Rangs de sorts » ; textes sans « → » (1.32.2).
local Check, Say, ResetWorld, NS, Mock, Result = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock, T.Result

local C = { savedNum = rawget(_G, "GetNumSkillLines"), savedInfo = rawget(_G, "GetSkillLineInfo"), skills = {} }
function C.Def(id)
	for _, def in ipairs(NS.checks or {}) do if def.id == id then return def end end
end
function C.Tip() return table.concat(GameTooltip.lines or {}, "\n") end

-- 1. Métiers au plafond de leur rang ---------------------------------------------------
do
	Say("-- check : métiers au plafond")
	ResetWorld()
	_G.GetNumSkillLines = function() return #C.skills end
	-- name, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank
	_G.GetSkillLineInfo = function(index)
		local s = C.skills[index]
		if not s then return nil end
		return s[1], s[2] == true, true, s[3] or 0, 0, 0, s[4] or 0
	end
	local def = C.Def("profcap")
	C.skills = {
		{ "Métiers", true },
		{ "Minage", false, 75, 75 },
		{ "Herboristerie", false, 60, 150 },
		{ "Compétences secondaires", true },
		{ "Cuisine", false, 150, 150 },
		{ "Compétences d'armes", true },
		{ "Épées", false, 75, 75 },        -- arme plafonnée au niveau : pas un métier
	}
	local capped = NS:ProfessionCaps()
	local ok, detail = def.run()
	Check("[PROF] métiers au plafond seulement (pas les armes) : le premier et le compte des autres", def ~= nil
		and NS.PROFCAP_STRINGS.en.CHK_PROFCAP == "Professions" and #capped == 2 and capped[1].name == "Minage"
		and capped[2].name == "Cuisine" and ok == false and detail:find("Minage", 1, true) and detail:find("75/75", 1, true)
		and detail:find("1 autre", 1, true), detail)
	C.skills = { { "Professions", true }, { "Mining", false, 300, 300 }, { "Herbalism", false, 120, 150 } }
	ok, detail = def.run()
	Check("[PROF] 300/300 : plafond du jeu, rien à rappeler", ok == true and detail == NS.L.CHK_PROFCAP_OK, detail)
	local active = def.active() == true
	_G.GetNumSkillLines = nil
	Check("[PROF] actif quand la fenêtre de compétences répond, inactif sans l'API", active and def.active() == false)
	_G.GetNumSkillLines, _G.GetSkillLineInfo = C.savedNum, C.savedInfo
end

-- 2. Quêtes de voyage (« fil d'Ariane », sans objectif) ---------------------------------
do
	Say("-- check : quêtes de voyage")
	ResetWorld()
	local saved = C_QuestLog.GetQuestObjectives
	C_QuestLog.GetQuestObjectives = function(questID)
		if questID == 21 then return {} end
		return { { text = "Loups tués : 10/10", finished = true } }
	end
	Mock.world.quests = { { questID = 21, title = "Va voir Sven", ready = true } }
	NS:RunChecklist("manual")
	local r = Result("quests")
	Check("[TRAVEL] seule une quête de voyage : rien à reprocher, elle est citée", r and r.ok == true
		and r.detail == NS:FP("CHK_QUESTS_TRAVEL", 1), r and r.detail)
	Mock.world.quests = { { questID = 21, title = "Va voir Sven", ready = true }, { questID = 22, title = "Loups", ready = true } }
	NS:RunChecklist("manual")
	r = Result("quests")
	Check("[TRAVEL] une vraie quête prête : comptée seule", r and r.ok == false and r.detail == NS:FP("CHK_QUESTS_DETAIL", 1),
		r and r.detail)
	C_QuestLog.GetQuestObjectives = nil
	Check("[TRAVEL] objectifs illisibles : on ne présume rien", NS.QuestIsTravel(21) == false)
	C_QuestLog.GetQuestObjectives = saved
	Mock.world.quests = {}
	if NS.window then NS.window:Hide() end
end

-- 3. Lignes entières, infobulle, colonne des libellés ------------------------------------
do
	Say("-- check : lignes du diagnostic")
	ResetWorld()
	local long = string.rep("é", 40)   -- 80 octets accentués
	local results = {
		{ id = "a", label = "Buffs", ok = false, detail = long, score = 40, weight = 10, advice = "ADV_BUFFS" },
		{ id = "b", label = "Sacs", ok = true, detail = "ok", score = 100, weight = 5 },
	}
	NS:ShowWindow(results)
	local frame = NS.window
	local row1, row2 = frame.rows[1], frame.rows[2]
	Check("[DIAGL] détail entier, sans « ... » de l'addon, ligne marquée coupée", row1.detail.text == long and row1.cut == true,
		row1.detail.text)
	GameTooltip:ClearLines()
	row1:GetScript("OnEnter")(row1)
	Check("[DIAGL] survol : libellé, texte entier, conseil, éclairage", C.Tip():find("Buffs", 1, true) ~= nil
		and C.Tip():find(long, 1, true) ~= nil and NS.L.ADV_BUFFS and C.Tip():find(NS.L.ADV_BUFFS, 1, true) ~= nil
		and row1.hover:IsShown() == true, C.Tip())
	row1:GetScript("OnLeave")(row1)
	Check("[DIAGL] sortie : infobulle masquée", GameTooltip.shown == false and row1.hover:IsShown() == false)
	GameTooltip:ClearLines()
	GameTooltip.shown = nil
	row2:GetScript("OnEnter")(row2)
	Check("[DIAGL] ligne OK et courte : pas d'infobulle", #(GameTooltip.lines or {}) == 0 and GameTooltip.shown ~= true)
	row2:GetScript("OnLeave")(row2)

	-- colonne des libellés : le plus long, borné à [110, 170] ; le détail prend le reste
	local short = frame.nameWidth
	results[2].label = string.rep("x", 22)    -- 22 * 6,4 + 8 = 148,8
	NS:ShowWindow(results)
	local fitted = frame.nameWidth == 149 and row2.name.width == 149
		and row1.detail.width == frame.innerWidth - row1.textLeft - 149 - 24
	results[2].label = string.rep("x", 60)
	NS:ShowWindow(results)
	Check("[DIAGL] colonne des libellés à la mesure du plus long, bornée à [110, 170], le détail prend le reste",
		short == 110 and fitted and frame.nameWidth == 170, tostring(short) .. " / " .. tostring(frame.nameWidth))
	if NS.window then NS.window:Hide() end
end

-- 4. Ligne Buffs : la liste complète en infobulle ----------------------------------------
do
	Say("-- check : ligne Buffs, liste complète")
	ResetWorld()
	local def = C.Def("buffs")
	local savedEval = NS.EvaluateBuffs
	local eight = { "A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8" }
	NS.EvaluateBuffs = function() return eight, 8, 0 end
	local ok, detail, _, _, tip = def.run(NS:DB())
	Check("[DIAGL] buffs : la liste complète en tip, « +6 » dans la ligne", ok == false and type(tip) == "table" and #tip == 8
		and tip.title == NS.L.DIAG_TIP_MISSING and detail:find("+6", 1, true) ~= nil, detail)
	NS:RunChecklist("manual")
	local row
	for _, r in ipairs(NS.window and NS.window.rows or {}) do if r.result and r.result.id == "buffs" then row = r end end
	local names = 0
	if row then
		GameTooltip:ClearLines()
		row:GetScript("OnEnter")(row)
		for _, line in ipairs(GameTooltip.lines or {}) do if line:match("^  A%d$") then names = names + 1 end end
		row:GetScript("OnLeave")(row)
	end
	Check("[DIAGL] fenêtre : tip gardé, infobulle Buffs avec les 8 noms", row ~= nil and #row.result.tip == 8 and names == 8)
	NS.EvaluateBuffs = savedEval
	if NS.window then NS.window:Hide() end
end

-- 5. Rangs de sorts, flèche ---------------------------------------------------------------
do
	Say("-- check : rangs de sorts, textes")
	ResetWorld()
	local savedScan = NS.SpellRankScan
	NS.SpellRankScan = function() return {} end
	local ok, detail = C.Def("barranks").run(NS:DB())
	Check("[DIAGL] « Rangs de sorts » : tous au meilleur rang", NS.L.CHK_SPELLRANKS == "Rangs de sorts" and ok == true
		and detail == "tous au meilleur rang", detail)
	NS.SpellRankScan = savedScan
	-- 1.32.2 : flèche ASCII, plus de « → » dans les textes affichés
	local bad = {}
	for _, key in ipairs({ "CHK_SPELLS_DETAIL", "SR_LINE", "DEATH_CHAT" }) do
		if tostring(NS.L[key]):find("\226\134\146", 1, true) then bad[#bad + 1] = key end
	end
	Check("[DIAGL] Theme.ARROW en ASCII (R2Q et QC), « niv. 18 à 20 », plus de « → »", NS.Theme.ARROW == "->"
		and T.QNS.Theme.ARROW == "->" and NS:F("CHK_SPELLS_DETAIL", 18, 20) == "niv. 18 à 20 : à apprendre" and #bad == 0,
		table.concat(bad, ","))
end
