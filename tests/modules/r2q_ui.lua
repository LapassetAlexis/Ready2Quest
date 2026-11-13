-- Ready2Quest 1.35.0 : passe de cohérence de l'interface (docs/UI.md,
-- « Passe de cohérence Ready2Quest 1.35.0 »). Combat (rien d'ouvert tout seul
-- ne reste à l'écran, retour après), clic des lignes du check, Échap et
-- [×] comme « Fermer », mises à jour de sorts retenues en combat, infobulles
-- par les briques du thème, contrastes et textes bornés.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local R = { savedG = {} }
for _, name in ipairs({ "UnitAffectingCombat", "InCombatLockdown", "OpenAllBags", "ToggleBackpack", "ToggleQuestLog",
	"GetActionInfo", "GetSpellInfo", "GetSpellSubtext", "GetSpellTexture", "PickupSpell", "PlaceAction", "ClearCursor",
	"GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemInfo", "C_Spell", "C_SpellBook" }) do
	R.savedG[name] = { value = rawget(_G, name) }
end
_G.UnitAffectingCombat = function() return Mock.world.combat == true end
_G.InCombatLockdown = function() return Mock.world.combat == true end

-- plusieurs étapes d'un même sujet : un contrôle, les étapes ratées nommées
function R.Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end
function R.Reset()
	ResetWorld()
	NS:DB().popupScore = 100          -- toujours un rapport, quelle que soit la note
	for _, field in ipairs({ "window", "expeditionFrame", "dungeonFrame", "bagspaceFrame", "toastFrame", "spellRanksFrame" }) do
		if NS[field] then NS[field]:Hide() end
	end
	NS:HideNotice()
	NS.combatHidden, NS.reportsAfterCombat, NS.spellRanksQueued, NS.toastPreview = nil, nil, nil, nil
	Mock.world.combat = nil
	Mock.world.money = 1000
	Mock.world.durability = { [1] = { 100, 100 } }
end
function R.Depart()
	Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	Mock.world.subzone = "Bois"
	Mock:Fire("ZONE_CHANGED")
	Mock:Advance(6)
end
function R.CombatStart() Mock.world.combat = true; Mock:Fire("PLAYER_REGEN_DISABLED") end
function R.CombatEnd() Mock.world.combat = nil; Mock:Fire("PLAYER_REGEN_ENABLED") end
function R.Shown(frame) return frame ~= nil and frame:IsShown() == true end
function R.Same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

-- 1. Combat : l'icône d'annonce -----------------------------------------------------------------
do
	Say("-- 1.35.0 : combat, icône d'annonce")
	local s = R.Steps()
	R.Reset()
	NS:ShowNotice(NS:NoticeDepart(40, "Pas prêt"))
	Mock:Advance(2)
	R.CombatStart()
	s.ok("fraîche : effacée au premier coup", not R.Shown(NS.noticeFrame) and NS.noticePending == true)
	R.CombatEnd()
	s.ok("fraîche : revient après le combat", R.Shown(NS.noticeFrame) and NS.notice and NS.notice.kind == "depart")
	NS:HideNotice()
	NS:ShowNotice(NS:NoticeDepart(40, "Pas prêt"))
	Mock:Advance((NS.NOTICE_PULSE + NS.NOTICE_LINGER) / 2 + 4)
	local still = R.Shown(NS.noticeFrame)
	R.CombatStart()
	R.CombatEnd()
	s.ok("plus de la moitié de son temps : oubliée", still and not R.Shown(NS.noticeFrame) and NS.notice == nil)
	s.check("[R2QUI] combat : l'icône s'efface ; revient après si elle était fraîche, sinon oubliée")
end

-- 2. Combat : rapports ouverts tout seuls / par le joueur ----------------------------------------
do
	Say("-- 1.35.0 : combat, rapports")
	local s = R.Steps()
	R.Reset()
	NS:DB().reportIcon = false
	R.Depart()
	s.ok("icône coupée : le rapport s'ouvre seul", R.Shown(NS.window))
	R.CombatStart()
	s.ok("ouvert seul : rangé au premier coup", not R.Shown(NS.window))
	R.CombatEnd()
	s.ok("ouvert seul : revient après le combat", R.Shown(NS.window))
	NS.window:Hide()

	R.Reset()
	NS:RunChecklist("manual")
	R.CombatStart()
	s.ok("/r2q (à la main) : reste en combat", R.Shown(NS.window))
	R.CombatEnd()
	NS.window:Hide()

	R.Reset()
	NS:DB().reportIcon = true
	R.Depart()
	NS.noticeFrame:GetScript("OnClick")(NS.noticeFrame, "LeftButton")
	R.CombatStart()
	s.ok("ouvert d'un clic sur l'icône : reste en combat", R.Shown(NS.window))
	R.CombatEnd()
	NS.window:Hide()

	NS:DB().reportIcon = false
	s.ok("icône coupée : bilan et fiche de donjon sont « ouverts seuls »", NS:ReportOpenedAlone("expeditionFrame")
		and NS:ReportOpenedAlone("dungeonFrame"))
	NS:DB().reportIcon = true
	s.ok("icône : bilan et fiche ne s'ouvrent qu'au clic (gardés)", not NS:ReportOpenedAlone("expeditionFrame")
		and not NS:ReportOpenedAlone("dungeonFrame"))
	s.check("[R2QUI] combat : rapport ouvert seul rangé puis rendu ; ouvert par le joueur, il reste")
end

-- 3. Combat : bandeaux (Sac plein, résumé de stuff) ; Échap du bandeau Sac plein -------------------
do
	Say("-- 1.35.0 : combat, bandeaux")
	local s = R.Steps()
	R.Reset()
	_G.UISpecialFrames = {}
	NS.bagspaceFrame = nil
	local frame = NS:EnsureBagSpaceFrame()
	local declared = false
	for _, name in ipairs(UISpecialFrames) do if name == "Ready2QuestBagSpace" then declared = true end end
	s.ok("Sac plein : nommé et inscrit à Échap", frame and frame:GetName() == "Ready2QuestBagSpace" and declared)
	-- candidat factice : le bandeau ne dépend ici que de « sacs pleins »
	local saved = {}
	for _, key in ipairs({ "BagSpaceFreeSlots", "BagSpaceRebuild", "BagSpaceCurrent", "BagSpaceLine" }) do saved[key] = NS[key] end
	local free = 0
	NS.BagSpaceFreeSlots = function() return free end
	NS.BagSpaceRebuild = function() return { 1 } end
	NS.BagSpaceCurrent = function() return { link = "[Caillou]", itemID = 1, bag = 0, slot = 1, count = 1 } end
	NS.BagSpaceLine = function() return "Jeter [Caillou] ?" end
	NS:ShowBagSpaceFrame()
	R.CombatStart()
	s.ok("Sac plein : rangé au premier coup", not R.Shown(frame))
	R.CombatEnd()
	s.ok("Sac plein : revient après le combat, sacs toujours pleins", R.Shown(frame))
	R.CombatStart()
	free = 2
	R.CombatEnd()
	s.ok("Sac plein : une place libérée entre-temps, il ne revient pas", not R.Shown(frame))
	for key, fn in pairs(saved) do NS[key] = fn end

	-- résumé de stuff : effacé au premier coup ; pas de nouveau en combat ; l'aperçu reste
	local rows = { { label = "STR", kind = "integer", polarity = true, delta = 8 } }
	NS:ShowGearToast(rows, "Interface\\Icons\\INV_Chest_Chain_05")
	local toast = NS.toastFrame
	s.ok("résumé : affiché hors combat", R.Shown(toast))
	R.CombatStart()
	s.ok("résumé : effacé au premier coup", not R.Shown(toast))
	NS:ShowGearToast(rows, "Interface\\Icons\\INV_Chest_Chain_05")
	s.ok("résumé : pas de nouveau en combat", not R.Shown(toast))
	NS:ShowGearToast(rows, "Interface\\Icons\\INV_Chest_Chain_05", true)
	s.ok("résumé : l'aperçu des réglages s'affiche quand même", R.Shown(toast))
	R.CombatEnd()
	toast:Hide()
	NS.toastPreview = nil
	s.check("[R2QUI] combat : bandeau Sac plein rangé puis rendu (si toujours plein), résumé de stuff effacé ; Échap ferme Sac plein")
end

-- 4. Lignes du check : le clic fait le geste du conseil ; voile seulement sur une ligne qui répond ----
do
	Say("-- 1.35.0 : clic des lignes du check")
	local s = R.Steps()
	R.Reset()
	local called = {}
	_G.OpenAllBags = function() called.bags = true end
	_G.ToggleQuestLog = function() called.quests = true end
	NS.score, NS.lastAdvice = 50, {}
	NS:DB().diagFoldOk = true
	local results = {
		{ id = "bags",     label = "Sacs",           ok = false, detail = "1 place", weight = 15, score = 20, advice = "ADV_BAGS" },
		{ id = "quests",   label = "Quêtes",         ok = false, detail = "2 à rendre", weight = 5, score = 50, advice = "ADV_QUESTS" },
		{ id = "barranks", label = "Rangs de sorts", ok = false, detail = "1 sort", weight = 5, score = 50 },
		{ id = "vivres",   label = "Vivres",         ok = true,  detail = "ok", weight = 10, score = 100 },
	}
	local frame = NS:ShowWindow(results)
	local byId = {}
	for _, row in ipairs(frame.rows) do if row.result and row.result.id then byId[row.result.id] = row end end
	for _, id in ipairs({ "bags", "quests", "barranks" }) do
		local row = byId[id]
		s.ok(id .. " : une ligne", row ~= nil)
		if row then
			GameTooltip:ClearLines()
			row:GetScript("OnEnter")(row)
			local st = GameTooltip.styled or {}
			local last = st[#st]
			s.ok(id .. " : voile au survol", row.hover:IsShown())
			s.ok(id .. " : l'aide du clic en dernier (MUTED clair)", last and R.Same(last.color, Theme.MUTED_LIGHT)
				and last.text:find(NS.L.DIAG_CLICK_BAGS:sub(1, 5), 1, true) == 1, last and last.text)
			row:GetScript("OnLeave")(row)
			row:Click()
		end
	end
	s.ok("Sacs : les sacs s'ouvrent", called.bags == true)
	s.ok("Quêtes : le journal s'ouvre", called.quests == true)
	s.ok("Rangs de sorts : sa fenêtre s'ouvre", R.Shown(NS.spellRanksFrame))
	if NS.spellRanksFrame then NS.spellRanksFrame:Hide() end
	frame = NS:ShowWindow(results)
	local quiet = byId.vivres
	if quiet then
		quiet:GetScript("OnEnter")(quiet)
		s.ok("ligne en ordre, sans infobulle ni clic : pas de voile", not quiet.hover:IsShown())
		quiet:GetScript("OnLeave")(quiet)
	end
	-- client sans la fonction : pas de clic promis
	_G.OpenAllBags, _G.ToggleBackpack = nil, nil
	s.ok("client sans OpenAllBags ni ToggleBackpack : pas d'action Sacs", NS:DiagRowAction(results[1]) == nil)
	s.ok("ligne d'un module coupé : pas d'action", NS:DiagRowAction({ id = "quests", disabled = true }) == nil)
	local fr, en, missing = NS.DIAG_UI_STRINGS.fr, NS.DIAG_UI_STRINGS.en, {}
	for key in pairs(fr) do if type(en[key]) ~= "string" or en[key] == "" then missing[#missing + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	s.ok("textes fr / en", #missing == 0, table.concat(missing, ", "))
	frame:Hide()
	GameTooltip:Hide()
	s.check("[R2QUI] check : clic sur Sacs, Quêtes, Rangs de sorts = le geste du conseil, annoncé en infobulle ; voile seulement si la ligne répond")
end

-- 5. Après la mort : [×] et Échap valent « Fermer » ----------------------------------------------
do
	Say("-- 1.35.0 : après la mort, [×] et Échap")
	local s = R.Steps()
	R.Reset()
	NS.deathFrame = nil
	local frame = NS:EnsureDeathPanel()
	-- comme le client : Hide() déclenche OnHide
	local hide = frame.Hide
	frame.Hide = function(f) hide(f); local script = f:GetScript("OnHide"); if script then script(f) end end
	NS.deathDismissed = nil
	frame:Show()
	frame.close:Click()
	s.ok("[×] : plus rien jusqu'à la prochaine mort", NS.deathDismissed == true)
	NS.deathDismissed = nil
	frame:Show()
	frame:Hide()            -- Échap (UISpecialFrames) : Hide()
	s.ok("Échap : idem", NS.deathDismissed == true)
	NS.deathDismissed = nil
	frame:Show()
	NS:HideDeathPanel()
	s.ok("rangée par l'addon (résurrection) : pas un refus", NS.deathDismissed == nil)
	frame:Show()
	frame:GetScript("OnHide")(frame)   -- interface masquée (Alt+Z) : la fenêtre reste « montrée »
	s.ok("interface masquée : pas un refus", NS.deathDismissed == nil)
	frame.Hide = hide
	frame:Hide()
	s.check("[R2QUI] après la mort : [×] et Échap comme « Fermer » ; le rangement par l'addon n'en est pas un")
end

-- 6. Rangs de sorts : en combat, la mise à jour attend vraiment la fin du combat ---------------------
do
	Say("-- 1.35.0 : rangs de sorts en combat")
	local s = R.Steps()
	R.Reset()
	local SPELLS = { [101] = { "Lumière sacrée", "Rang 3" }, [102] = { "Lumière sacrée", "Rang 5" } }
	local W = { actions = { [4] = 101, [16] = 101 }, placed = {} }
	_G.C_Spell, _G.C_SpellBook = nil, nil
	_G.GetActionInfo = function(slot) local id = W.actions[slot]; if id then return "spell", id end end
	_G.GetSpellInfo = function(id) return SPELLS[id] and SPELLS[id][1] end
	_G.GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end
	_G.GetSpellTexture = function() return "Interface\\Icons\\Spell_Holy_HolyBolt" end
	_G.GetNumSpellTabs = function() return 1 end
	_G.GetSpellTabInfo = function() return "Sacré", "", 0, 1 end
	_G.GetSpellBookItemInfo = function() return "SPELL", 102 end
	_G.PickupSpell = function(id) W.picked = id end
	_G.PlaceAction = function(slot) W.actions[slot] = W.picked; W.placed[#W.placed + 1] = slot end
	_G.ClearCursor = function() end
	NS:DB().spellranksIgnore = {}
	local list = NS:SpellRankScan()
	s.ok("deux cases à mettre à jour", #list == 2, #list)
	Mock.world.combat = true
	local before = #Mock:Output()
	NS:SpellRankUpdate(list[1])
	NS:SpellRankUpdate(list[1])
	s.ok("en combat : rien de touché", W.actions[4] == 101 and #W.placed == 0)
	s.ok("en combat : retenue une fois, le chat le dit une fois", NS.spellRanksQueued and #NS.spellRanksQueued == 1
		and select(2, Mock:Output():sub(before + 1):gsub(NS.L.SR_COMBAT:sub(1, 10), "")) == 1)
	R.CombatEnd()
	s.ok("fin du combat : la case est mise à jour", W.actions[4] == 102 and W.actions[16] == 101 and NS.spellRanksQueued == nil)
	Mock.world.combat = true
	NS:SpellRankUpdateAll()
	W.actions[16] = 101          -- inchangée
	R.CombatEnd()
	s.ok("« Tout mettre à jour » en combat : tout passe à la fin", W.actions[16] == 102)
	-- textes bornés de la fenêtre
	local frame = NS:SpellRanksOpen()
	local row = frame and frame.rows[1]
	s.ok("« barre N, case N » sur une ligne, bornée", row and row.where.wordWrap == false and row.where.width == row.text.width)
	local pad = Theme.DIALOG_PAD
	s.ok("« et N autre(s) » s'arrête avant « Tout mettre à jour »", frame and frame.more.wordWrap == false
		and frame.more.width + frame.all:GetWidth() + 12 <= frame:GetWidth() - 2 * pad + 0.5,
		frame and (tostring(frame.more.width) .. "+" .. tostring(frame.all:GetWidth())))
	if frame then frame:Hide() end
	s.check("[R2QUI] rangs de sorts : en combat, le clic est retenu et joué à la fin (plus perdu) ; textes du pied et des lignes bornés")
end

-- 7. Infobulles par les briques du thème ; contrastes -----------------------------------------------
do
	Say("-- 1.35.0 : infobulles, contrastes")
	local s = R.Steps()
	local raw = {}
	for _, file in ipairs({ "UI.lua", "Notice.lua", "Stats.lua", "Camp.lua", "Expedition.lua", "LootRoom.lua", "BagSpace.lua",
		"Favorites.lua", "Death.lua", "LevelPace.lua", "QuestReward.lua", "SpellRanks.lua", "Aggro.lua", "Merchant.lua",
		"OptionPages.lua", "Core.lua" }) do
		local h = io.open(ROOT .. "/Ready2Quest/" .. file, "r")
		local src = h and h:read("*a") or ""
		if h then h:close() end
		if src == "" then raw[#raw + 1] = file .. " (illisible)" end
		if src:find(":AddLine%(") or src:find("tooltip%.AddLine,") then raw[#raw + 1] = file end
	end
	s.ok("plus d'AddLine écrit à la main", #raw == 0, table.concat(raw, ", "))
	-- fond d'une infobulle du jeu (même valeur que ui_bricks.lua [UI31])
	local tipBg = { 0.03, 0.03, 0.06 }
	local bad = {}
	for name, c in pairs({ GREEN = Theme.GREEN, RED = Theme.RED, ORANGE_DEEP = Theme.ORANGE_DEEP, BLUE = Theme.BLUE,
		GOLD = Theme.GOLD, MUTED_LIGHT = Theme.MUTED_LIGHT }) do
		local r = Theme.Contrast(c, tipBg)
		if r < 4.5 then bad[#bad + 1] = name .. string.format("=%.2f", r) end
	end
	s.ok("verdicts d'aggro, rapports, conseils sur le fond d'infobulle ≥ 4,5:1", #bad == 0, table.concat(bad, ", "))
	-- Place au butin : plus cher que le butin, prix MUTED sur une ligne opaque
	for name, bg in pairs({ ROW = Theme.ROW, ROW_ALT = Theme.ROW_ALT }) do
		local r = Theme.Contrast(Theme.MUTED, bg)
		s.ok("butin plus cher : prix MUTED sur " .. name .. " ≥ 4,5:1", r >= 4.5, string.format("%.2f", r))
	end
	s.check("[R2QUI] infobulles par Theme.Tooltip* (aggro, favoris, allure, récompense) ; encres ≥ 4,5:1 ; ligne de butin opaque")
end

-- 8. Kit de camp : le texte long tient dans le bandeau ---------------------------------------------
do
	Say("-- 1.35.0 : bandeau du camp")
	local s = R.Steps()
	R.Reset()
	local savedText = NS.CampTimerText
	local text = NS.L.CAMP_TIMER_HINT
	NS.CampTimerText = function() return text end
	NS:UpdateCampFrame(Mock.now)
	local frame = NS.campFrame
	local need = Theme.TextWidth(frame, text, Theme.F_LABEL)
	s.ok("texte long : le bandeau s'élargit, le texte tient", frame and frame.text.width >= need
		and frame:GetWidth() >= frame.text.width + 2 * (18 + 5) and frame:GetWidth() <= 440,
		frame and (tostring(frame.text.width) .. " / " .. tostring(frame:GetWidth())))
	text = NS:F("CAMP_TIMER", "1:00")
	NS:UpdateCampFrame(Mock.now)
	s.ok("texte court : 300 de large", frame:GetWidth() == 300, frame:GetWidth())
	NS.CampTimerText = savedText
	frame:Hide()
	s.check("[R2QUI] kit de camp : le texte ne déborde pas du bandeau (il s'élargit jusqu'à 440)")
end

for name, entry in pairs(R.savedG) do _G[name] = entry.value end
