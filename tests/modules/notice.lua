-- Rapports annoncés par une icône (Notice.lua) : le « ! » au départ et devant
-- un donjon, le « ? » au retour, dans la couleur du résultat ; pulsation,
-- puis atténuée, puis disparue ; clic = le rapport, clic droit = ignoré ;
-- en combat, attend la fin du combat. Barème unique de la note.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock
local Theme = NS.Theme

local N = { combatFn = rawget(_G, "UnitAffectingCombat") }
_G.UnitAffectingCombat = function() return Mock.world.combat == true end
function N.Reset()
	ResetWorld()
	NS:DB().popupScore = 100          -- toujours un rapport, quelle que soit la note
	if NS.window then NS.window:Hide() end
	if NS.expeditionFrame then NS.expeditionFrame:Hide() end
	if NS.dungeonFrame then NS.dungeonFrame:Hide() end
	NS:HideNotice()
	NS.expedition, NS.lastExpedition = nil, nil
	Mock.world.combat = nil
	Mock.world.money = 1000
	Mock.world.durability = { [1] = { 100, 100 } }
end
function N.Depart()
	Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	Mock.world.subzone = "Bois"
	Mock:Fire("ZONE_CHANGED")
	Mock:Advance(6)
end
function N.Shown() return NS.noticeFrame and NS.noticeFrame:IsShown() and NS.notice ~= nil end
function N.Same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
function N.Tinted(color)
	local v = NS.noticeFrame.icon.vertex or {}
	local r, g, b = v[1], v[2], v[3]
	return r == color[1] and g == color[2] and b == color[3]
end

-- 1. Réglage, textes, barème ---------------------------------------------------------------
do
	Say("-- icône : réglage et barème")
	N.Reset()
	local fr, en, missing = NS.NOTICE_STRINGS.fr, NS.NOTICE_STRINGS.en, {}
	for key in pairs(fr) do if type(en[key]) ~= "string" or en[key] == "" then missing[#missing + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	Check("[NTC] textes en français et en anglais", #missing == 0, table.concat(missing, ", "))
	Check("[NTC] icône par défaut", NS:DB().reportIcon == true and NS:WantsNotice())
	local row
	for _, def in ipairs(NS.OPTION_PAGES) do
		if def.id == "general" then
			for index, r in ipairs(def.rows) do
				if r.key == "reportIcon" then row = def.rows[index - 1] end
			end
		end
	end
	Check("[NTC] réglage dans Général, sous « fenêtre ou chat »", row and row.key == "showWindow")
	Check("[NTC] icônes du jeu : « ! » au départ et au donjon, « ? » au retour",
		NS.NOTICE_ICONS.depart == "Interface\\GossipFrame\\AvailableQuestIcon"
		and NS.NOTICE_ICONS.dungeon == NS.NOTICE_ICONS.depart
		and NS.NOTICE_ICONS["return"] == "Interface\\GossipFrame\\ActiveQuestIcon")
	Check("[NTC] barème : 0-24 rouge, 25-59 orange, 60-84 ambre, 85+ vert",
		N.Same(Theme.ScoreColor(0.10), Theme.RED) and N.Same(Theme.ScoreColor(0.24), Theme.RED)
		and N.Same(Theme.ScoreColor(0.25), Theme.ORANGE_DEEP) and N.Same(Theme.ScoreColor(0.59), Theme.ORANGE_DEEP)
		and N.Same(Theme.ScoreColor(0.60), Theme.ORANGE) and N.Same(Theme.ScoreColor(0.84), Theme.ORANGE)
		and N.Same(Theme.ScoreColor(0.85), Theme.GREEN))
	Check("[NTC] la note et son verdict changent de couleur au même seuil (60)",
		Theme.ScoreTextColor(0.59) == Theme.T_ORANGE_DEEP and Theme.ScoreTextColor(0.60) == Theme.T_ORANGE)
	Check("[NTC] « ! » du départ : couleur de la note", N.Same(NS:NoticeDepart(12, "x").color, Theme.RED)
		and N.Same(NS:NoticeDepart(40, "x").color, Theme.ORANGE_DEEP) and N.Same(NS:NoticeDepart(70, "x").color, Theme.ORANGE)
		and N.Same(NS:NoticeDepart(90, "x").color, Theme.GREEN))
	local quiet = { deaths = 0, restock = {}, durability = 90 }
	Check("[NTC] « ? » du retour : bleu sans souci, orange s'il faut réparer ou racheter, rouge si mort",
		N.Same(NS:NoticeReturn(quiet).color, Theme.BLUE)
		and N.Same(NS:NoticeReturn({ deaths = 0, restock = { "Pain" }, durability = 90 }).color, Theme.ORANGE_DEEP)
		and N.Same(NS:NoticeReturn({ deaths = 0, restock = {}, durability = 10 }).color, Theme.ORANGE_DEEP)
		and N.Same(NS:NoticeReturn({ deaths = 2, restock = { "Pain" }, durability = 10 }).color, Theme.RED))
	Check("[NTC] « ! » du donjon : rouge trop bas, orange si préparation à revoir, bleu sinon",
		N.Same(NS:NoticeDungeon({ name = "X", verdict = "low", readiness = {} }).color, Theme.RED)
		and N.Same(NS:NoticeDungeon({ name = "X", verdict = "ok", readiness = { { ok = false } } }).color, Theme.ORANGE_DEEP)
		and N.Same(NS:NoticeDungeon({ name = "X", verdict = "ok", readiness = { { ok = true } } }).color, Theme.BLUE))
end

-- 2. Départ : l'icône au lieu de la fenêtre -------------------------------------------------
do
	Say("-- icône : départ")
	N.Reset()
	Mock:Reset()
	N.Depart()
	Check("[NTC] départ : la fenêtre ne s'ouvre pas", not (NS.window and NS.window:IsShown()))
	Check("[NTC] départ : le « ! » s'affiche", N.Shown() and NS.notice.kind == "depart"
		and NS.noticeFrame.icon.texture == NS.NOTICE_ICONS.depart)
	Check("[NTC] départ : dans la couleur de la note", N.Tinted(Theme.ScoreColor((NS.score or 0) / 100)))
	Check("[NTC] départ : la ligne du chat reste", Mock:Output():find(tostring(NS.score) .. "/100", 1, true) ~= nil,
		Mock:Output())
	NS.noticeFrame:GetScript("OnClick")(NS.noticeFrame, "LeftButton")
	Check("[NTC] clic : la fenêtre Avant le départ s'ouvre, l'icône s'en va", NS.window and NS.window:IsShown()
		and not N.Shown())
	NS.window:Hide()

	N.Reset()
	NS:RunChecklist("manual")
	Check("[NTC] check à la main : la fenêtre, sans icône", NS.window and NS.window:IsShown() and not N.Shown())
	NS.window:Hide()

	N.Reset()
	NS:DB().reportIcon = false
	N.Depart()
	Check("[NTC] icône coupée : la fenêtre s'ouvre comme avant", NS.window and NS.window:IsShown() and not N.Shown())
	NS.window:Hide()
end

-- 3. Pulsation, puis atténuée, puis disparue ; clic droit ; combat ---------------------------
do
	Say("-- icône : durée, clics, combat")
	N.Reset()
	local clicked = 0
	local notice = NS:NoticeDepart(40, "Pas prêt")
	notice.onClick = function() clicked = clicked + 1 end
	NS:ShowNotice(notice)
	local first = NS.noticeFrame.glow.alpha
	Mock:Advance(0.3)
	local second = NS.noticeFrame.glow.alpha
	Check("[NTC] pulsation : le halo varie", N.Shown() and first ~= second, tostring(first) .. " / " .. tostring(second))
	Mock:Advance(NS.NOTICE_PULSE)
	Check("[NTC] après la pulsation : toujours là, atténuée", N.Shown() and NS.noticeFrame.alpha == 0.6)
	Mock:Advance(NS.NOTICE_LINGER)
	Check("[NTC] puis disparue", not N.Shown())

	NS:ShowNotice(notice)
	NS.noticeFrame:GetScript("OnClick")(NS.noticeFrame, "RightButton")
	Check("[NTC] clic droit : ignorée, rien ne s'ouvre", not N.Shown() and clicked == 0)

	Mock.world.combat = true
	NS:ShowNotice(notice)
	Check("[NTC] en combat : elle attend", not N.Shown() and NS.noticePending == true)
	Mock.world.combat = nil
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[NTC] fin du combat : elle s'affiche", N.Shown())
	NS.noticeFrame:GetScript("OnClick")(NS.noticeFrame, "LeftButton")
	Check("[NTC] clic : le rapport demandé", clicked == 1)

	NS:ShowNotice(NS:NoticeDepart(20, "x"))
	NS:ShowNotice(NS:NoticeReturn({ deaths = 0, restock = {}, durability = 90 }))
	Check("[NTC] une seule icône : la plus récente", N.Shown() and NS.notice.kind == "return"
		and NS.noticeFrame.icon.texture == NS.NOTICE_ICONS["return"])
	NS:HideNotice()
end

-- 4. Retour d'expédition et donjon --------------------------------------------------------
do
	Say("-- icône : retour et donjon")
	N.Reset()
	N.Depart()
	NS:HideNotice()
	Mock:Fire("PLAYER_DEAD")
	Mock.now = Mock.now + 120
	Mock.world.subzone = "Goldshire"
	Mock:Reset()
	Mock:Fire("ZONE_CHANGED")
	Check("[NTC] retour : le « ? » au lieu du bilan", N.Shown() and NS.notice.kind == "return"
		and not (NS.expeditionFrame and NS.expeditionFrame:IsShown()))
	Check("[NTC] retour avec une mort : rouge", N.Tinted(Theme.RED))
	Check("[NTC] retour : la ligne du chat reste", Mock:Output() ~= "")
	NS.noticeFrame:GetScript("OnClick")(NS.noticeFrame, "LeftButton")
	Check("[NTC] clic : le bilan s'ouvre", NS.expeditionFrame and NS.expeditionFrame:IsShown())

	N.Reset()
	Mock:Reset()
	NS:ShowDungeonSheet({ key = "deadmines", name = "Les Mortemines", how = "instance", verdict = "ok",
		quests = {}, readiness = {}, blueprints = {} })
	Check("[NTC] donjon : le « ! » au lieu de la fiche", N.Shown() and NS.notice.kind == "dungeon"
		and not (NS.dungeonFrame and NS.dungeonFrame:IsShown()) and N.Tinted(Theme.BLUE))
	Check("[NTC] donjon : une ligne dans le chat", Mock:Output():find("Les Mortemines", 1, true) ~= nil, Mock:Output())
	NS.noticeFrame:GetScript("OnClick")(NS.noticeFrame, "LeftButton")
	Check("[NTC] clic : la fiche s'ouvre", NS.dungeonFrame and NS.dungeonFrame:IsShown())
	NS.dungeonFrame:Hide()
end

-- 5. Mode « Déplacer les cadres » -----------------------------------------------------------
do
	Say("-- icône : placement")
	N.Reset()
	NS:StartEditMode()
	Check("[NTC] mode édition : l'icône s'affiche pour être placée", NS.noticeFrame:IsShown()
		and NS.noticeFrame.moveGlow:IsShown())
	NS:StopEditMode()
	Check("[NTC] fin du mode édition : elle repart", not NS.noticeFrame:IsShown())
	N.Reset()
end
_G.UnitAffectingCombat = N.combatFn
