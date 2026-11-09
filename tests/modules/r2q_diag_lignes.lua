-- Ready2Quest 1.31.0 : lignes d'« Avant le départ » entières (plus de coupe
-- à 46 octets), infobulle au survol, colonne des libellés adaptée.
local Check, ResetWorld, NS = T.Check, T.ResetWorld, T.NS

local function Def(id)
	for _, def in ipairs(NS.checks or {}) do if def.id == id then return def end end
end
local function Tip() return table.concat(GameTooltip.lines or {}, "\n") end

do
	T.Say("-- R2Q : lignes du diagnostic")
	ResetWorld()
	local long = string.rep("é", 40)   -- 80 octets accentués
	local results = {
		{ id = "a", label = "Buffs", ok = false, detail = long, score = 40, weight = 10, advice = "ADV_BUFFS" },
		{ id = "b", label = "Sacs", ok = true, detail = "ok", score = 100, weight = 5 },
	}
	NS:ShowWindow(results)
	local frame = NS.window
	local row1, row2 = frame.rows[1], frame.rows[2]
	Check("[DIAGL] détail entier, sans « ... » de l'addon", row1.detail.text == long, row1.detail.text)
	Check("[DIAGL] ligne trop longue marquée coupée", row1.cut == true)
	Check("[DIAGL] ligne : un bouton, survol", row1:GetScript("OnEnter") ~= nil and row1:GetScript("OnLeave") ~= nil)
	GameTooltip:ClearLines()
	row1:GetScript("OnEnter")(row1)
	Check("[DIAGL] survol : libellé, texte entier, conseil", Tip():find("Buffs", 1, true) ~= nil
		and Tip():find(long, 1, true) ~= nil and NS.L.ADV_BUFFS and Tip():find(NS.L.ADV_BUFFS, 1, true) ~= nil, Tip())
	Check("[DIAGL] survol : éclairage", row1.hover:IsShown() == true)
	row1:GetScript("OnLeave")(row1)
	Check("[DIAGL] sortie : infobulle masquée", GameTooltip.shown == false and row1.hover:IsShown() == false)
	GameTooltip:ClearLines()
	GameTooltip.shown = nil
	row2:GetScript("OnEnter")(row2)
	Check("[DIAGL] ligne OK et courte : pas d'infobulle", #(GameTooltip.lines or {}) == 0 and GameTooltip.shown ~= true)
	row2:GetScript("OnLeave")(row2)

	-- colonne des libellés : le plus long, borné à [110, 170]
	Check("[DIAGL] colonne courte : 110 au moins", frame.nameWidth == 110, frame.nameWidth)
	results[2].label = string.rep("x", 22)    -- 22 * 6,4 + 8 = 148,8
	NS:ShowWindow(results)
	Check("[DIAGL] colonne à la mesure du libellé", frame.nameWidth == 149 and row2.name.width == 149
		and 22 * 6.4 <= frame.nameWidth, frame.nameWidth)
	Check("[DIAGL] le détail prend le reste", row1.detail.width == frame.innerWidth - row1.textLeft - 149 - 24, row1.detail.width)
	results[2].label = string.rep("x", 60)
	NS:ShowWindow(results)
	Check("[DIAGL] colonne bornée à 170", frame.nameWidth == 170, frame.nameWidth)
	if NS.window then NS.window:Hide() end
end

do
	T.Say("-- R2Q : ligne Buffs, liste complète")
	ResetWorld()
	local def = Def("buffs")
	local savedEval = NS.EvaluateBuffs
	local eight = { "A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8" }
	NS.EvaluateBuffs = function() return eight, 8, 0 end
	local ok, detail, _, _, tip = def.run(NS:DB())
	Check("[DIAGL] buffs : la liste complète en tip", ok == false and type(tip) == "table" and #tip == 8
		and tip.title == NS.L.DIAG_TIP_MISSING and detail:find("+6", 1, true) ~= nil, detail)
	NS:RunChecklist("manual")
	local row
	for _, r in ipairs(NS.window and NS.window.rows or {}) do if r.result and r.result.id == "buffs" then row = r end end
	Check("[DIAGL] résultat : tip gardé", row ~= nil and row.result.tip ~= nil and #row.result.tip == 8)
	if row then
		GameTooltip:ClearLines()
		row:GetScript("OnEnter")(row)
		local names = 0
		for _, line in ipairs(GameTooltip.lines or {}) do if line:match("^  A%d$") then names = names + 1 end end
		Check("[DIAGL] infobulle Buffs : 8 noms", names == 8 and Tip():find(NS.L.DIAG_TIP_MISSING, 1, true) ~= nil, Tip())
		row:GetScript("OnLeave")(row)
	end
	NS.EvaluateBuffs = savedEval
	if NS.window then NS.window:Hide() end
end

do
	T.Say("-- R2Q : Rangs de sorts")
	ResetWorld()
	Check("[DIAGL] libellé : un nom", NS.L.CHK_SPELLRANKS == "Rangs de sorts")
	local savedScan = NS.SpellRankScan
	NS.SpellRankScan = function() return {} end
	local ok, detail = Def("barranks").run(NS:DB())
	Check("[DIAGL] succès : tous au meilleur rang", ok == true and detail == "tous au meilleur rang", detail)
	NS.SpellRankScan = savedScan
end
