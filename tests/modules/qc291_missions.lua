-- QuestCompanion 2.9.1 : page Missions du carnet refaite d'après la maquette
-- validée. Bande résumé (compagnon, jour, semaine : compte, pastilles,
-- bonus), missions en cartes sur deux colonnes (seule ou dernière impaire :
-- toute la largeur), icône de la sorte, titre et zone séparés, tampon
-- « Faite » qui ne recouvre pas le titre, bouton ↻ (même action, une fois
-- par jour), étiquettes à côté des intertitres, encarts des 3 en pointillés,
-- colonne de droite compacte (7 tampons ronds, garde-manger, besace), encres
-- mesurées de l'habit Azeroth, compteur des pagers à l'encre.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()
local L = NS.L
local INK = NS.AZEROTH_INK
local MIS = NS.JOURNAL_MISSIONS_LAYOUT

local MS = { saved = {}, trait = NS.CompanionTrait }
local GLOBALS = { "date", "C_DateAndTime", "C_Texture", "time" }
for _, name in ipairs(GLOBALS) do MS.saved[name] = rawget(_G, name) end

local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 0.011 end
local function Same(c, ref) return c and ref and Near(c[1], ref[1]) and Near(c[2], ref[2]) and Near(c[3], ref[3]) end
local function Role(key) return INK[NS.AZEROTH_CONTRAST[key][1]] end

function MS.Reset(style)
	ResetWorld()
	for _, field in ipairs({ "journalFrame", "companionFrame", "companionBubble" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	Mock.world.maps[9800] = { mapID = 9800, name = "Val des missions", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 9800, 20
	_G.date = function(format) if format == "%Y-%m-%d" then return "2026-11-09" end return "2026-45" end
	_G.time = function() return 1800000000 end
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 2 * 86400 + 600 end }
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "azeroth" and "azeroth" or "sobre"
	NS:DB().companionMissions = true
	NS:CompanionData().tutoDone = true
	NS.CompanionTrait = function() return "glutton" end
	-- jour : 1 = quêtes (faite), 2 = récolte, 3 = caresses (compagnon)
	local daily, inn = NS:DailyData()
	daily.day, daily.zoneID, daily.rerolled, daily.allDone = NS:DailyToday(), 9800, nil, nil
	daily.missions = {
		{ kind = "quests", need = 2, have = 2, done = true, zoneID = 9800, source = "zone" },
		{ kind = "gather", need = 5, have = 1, zoneID = 9800, source = "zone" },
		{ kind = "pets", need = 3, have = 0, source = "trait", trait = "glutton" },
	}
	inn.card, inn.total, inn.full = 3, 10, 0
	-- semaine : captures (faite), brillante, récolte
	local weekly = NS:WeeklyData()
	weekly.week, weekly.allDone = NS:WeeklyId(), nil
	weekly.missions = {
		{ kind = "captures", need = 6, have = 6, done = true, source = "week" },
		{ kind = "shinyKill", need = 1, have = 0, source = "week" },
		{ kind = "gather", need = 20, have = 15, source = "week" },
	}
end
function MS.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = MS.saved[name] end
	NS.CompanionTrait = MS.trait
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.uiStyleCache = {}
	NS:AzerothAtlasOK(true)
	ResetWorld()
end
local function Open(kind)
	NS:DB().journalTracker = false
	local frame = NS:ToggleJournal(true) or NS.journalFrame
	NS:SelectJournalKind(kind or "day")
	return NS.journalFrame
end
local function Rect(region, frame) return Snap.Rect(region, { memo = {}, root = frame }) end

-- 1. Gabarit ---------------------------------------------------------------------------------------
do
	Say("-- 2.9.1 missions : gabarit")
	Check("[M291] colonnes : missions 420, droite 274 (écart 16), cartes demies de 206", MIS.leftW == 420
		and MIS.rightW == 274 and MIS.rightX == 436 and MIS.half == 206, MIS.rightW .. " / " .. MIS.half)
	-- 2.11.0 : plaques plus hautes (détail sur deux lignes, pastilles en bas)
	Check("[M291] bande résumé : trois plaques de 230 × 56", MIS.sumW == 230 and MIS.sumH == 56)
	Check("[M291] icônes des sortes : filet, quêtes, lieux, récolte, repas, brillante, combat",
		NS.MissionKindIcon("captures"):find("Spell_Nature_Web", 1, true) and NS.MissionKindIcon("turnins"):find("INV_Misc_Book_09", 1, true)
		and NS.MissionKindIcon("places"):find("INV_Misc_Map_01", 1, true) and NS.MissionKindIcon("gather"):find("Trade_Mining", 1, true)
		and NS.MissionKindIcon("meals"):find("Spell_Misc_Food", 1, true) and NS.MissionKindIcon("shinyKill"):find("Gem_Pearl", 1, true)
		and NS.MissionKindIcon("kills"):find("INV_Sword_04", 1, true) and NS.MissionKindIcon("inconnue"):find("QuestionMark", 1, true))
	local missing = {}
	for _, kind in ipairs({ "species", "named", "gather", "quests", "village", "percent", "kills", "places", "meals", "elites",
		"rest", "pets", "turnins", "talks", "nightKills", "calm", "gold", "captures", "capNew", "capNamed", "capType",
		"captureNamed", "dailies", "stamps", "shinyKill", "shinyCapture", "typeCapture" }) do
		if not NS.MISSION_KIND_ICONS[kind] then missing[#missing + 1] = kind end
	end
	Check("[M291] chaque sorte de mission a son icône", #missing == 0, table.concat(missing, ","))
	local strings = { "MIS_ANYWHERE", "MIS_STAMP", "SUM_trait", "SUM_zone", "SUM_week", "SUM_TRAIT", "SUM_BONUS", "SUM_WEEK", "SUM_LEFT", "SUM_DONE" }
	local fr, en = NS.DAILY_STRINGS and NS.DAILY_STRINGS.fr, NS.DAILY_STRINGS and NS.DAILY_STRINGS.en
	local bad = {}
	for _, key in ipairs(strings) do if not (fr and fr[key] and en and en[key]) then bad[#bad + 1] = key end end
	Check("[M291] textes FR et EN", fr ~= nil and #bad == 0, table.concat(bad, ","))
end

-- 2. Cartes, grille, tampon, bouton ↻ (habit Sobre) -------------------------------------------------
do
	Say("-- 2.9.1 missions : cartes")
	MS.Reset("sobre")
	local f = Open("day")
	local day = f.day
	local m = day.missions
	Check("[M291] six cartes (compagnon, 2 du jour, 3 de la semaine)", #m == 6 and m[1].group == "trait"
		and m[2].group == "zone" and m[4].group == "week")
	-- grille : le compagnon seul en large ; les deux du jour côte à côte ; semaine 2 + 1 large
	local r = {}
	for i = 1, 6 do r[i] = Rect(m[i], f) end
	Check("[M291] compagnon seul : toute la largeur", m[1].cardW == MIS.leftW and m[1].wide == true)
	Check("[M291] du jour : deux demies côte à côte", m[2].cardW == MIS.half and m[3].cardW == MIS.half
		and Near(r[2].top, r[3].top) and Near(r[3].left - r[2].left, MIS.half + MIS.cardGap), (r[3].left - r[2].left))
	Check("[M291] semaine : deux demies puis la dernière (impaire) en large", m[4].cardW == MIS.half and m[5].cardW == MIS.half
		and m[6].cardW == MIS.leftW and Near(r[6].left, r[4].left) and r[6].top >= r[4].top + MIS.cardH)
	Check("[M291] cartes de 68 de haut, sous la bande résumé", Near(r[1].height, MIS.cardH)
		and r[1].top >= Rect(day.summary.trait, f).top + MIS.sumH)
	-- contenu : icône de la sorte, titre sans la zone, zone à part, barre, compte, gains en icônes
	Check("[M291] titre et zone séparés", m[2].label.text == "Rends 2 quêtes" and m[2].zone.text == "Val des missions",
		m[2].label.text .. " / " .. tostring(m[2].zone.text))
	Check("[M291] mission du compagnon : « N'importe où »", m[1].zone.text == L.MIS_ANYWHERE and m[1].label.text == "Fais-moi 3 caresses")
	Check("[M291] icône de la sorte (quêtes, récolte, brillante)", m[2].icon.texture == NS.MISSION_KIND_ICONS.quests
		and m[3].icon.texture == NS.MISSION_KIND_ICONS.gather and m[5].icon.texture == NS.MISSION_KIND_ICONS.shinyKill)
	Check("[M291] vraie barre et compte", m[6].count.text == "15/20" and Near(m[6].bar.ratio, 0.75) and m[6].bar:IsShown())
	local appat, lasso = NS.CAPTURE_AIDS[1].icon, NS.CAPTURE_AIDS[2].icon
	Check("[M291] gains en icônes d'objet (friandise + Appât / Lasso)", m[1].rewards[2].texture == appat
		and m[4].rewards[2].texture == lasso and m[1].rewards[1]:IsShown())
	Check("[M291] gain en clair sur une carte large seulement", m[1].source:IsShown() and not m[4].source:IsShown()
		and m[4].source.text:find("Lasso tressé", 1, true) ~= nil)
	-- faite : voile vert et tampon, le titre s'arrête avant
	local stamp, title = Rect(m[2].stamp, f), Rect(m[2].label, f)
	Check("[M291] faite : voile vert et tampon « Faite »", m[2].tint:IsShown() and m[2].stamp:IsShown()
		and m[2].stamp.text.text == L.MIS_STAMP and not m[3].stamp:IsShown() and not m[3].tint:IsShown())
	Check("[M291] faite sur une demie carte : titre sur deux lignes au plus, à la place de la zone", m[2].label.wordWrap == true
		and not m[2].zone:IsShown() and m[2].label:GetHeight() <= 30 and m[3].label.wordWrap == false and m[3].zone:IsShown())
	Check("[M291] le titre ne passe pas sous le tampon", title.left + title.width <= stamp.left - 2,
		(title.left + title.width) .. " / " .. stamp.left)
	Check("[M291] tampon en haut à droite de la carte", Near(stamp.left + stamp.width, r[2].left + r[2].width - 6)
		and Near(stamp.top, r[2].top + 6))
	Check("[M291] tampon : vert sombre, texte blanc (7,8:1)", Same(m[2].stamp.bg.vertex or {}, NS.MISSION_COLORS.stamp)
		and Same(m[2].stamp.text.textColor, { 1, 1, 1 }))
	-- bouton ↻ : seulement sur la carte du jour pas faite, une fois par jour
	local swap = m[3].reroll
	Check("[M291] ↻ : petit bouton rond dans le coin de la carte du jour", swap and swap:IsShown() and swap.icon.texture == NS.Theme.REFRESH
		and Near(swap:GetWidth(), MIS.swap) and m[1].reroll == nil and m[4].reroll == nil)
	Check("[M291] ↻ : caché sur une mission faite", m[2].reroll and not m[2].reroll:IsShown())
	local sr, tr = Rect(swap, f), Rect(m[3].label, f)
	Check("[M291] ↻ : le titre s'arrête avant", tr.left + tr.width <= sr.left - 2, (tr.left + tr.width) .. " / " .. sr.left)
	local called
	local reroll = NS.MissionReroll
	NS.MissionReroll = function(self, index) called = index; return reroll(self, index) end
	swap:Click()
	NS.MissionReroll = reroll
	NS:RefreshJournal()
	Check("[M291] ↻ : même action (MissionReroll de la mission 2)", called == 2 and NS:DailyData().rerolled == true, tostring(called))
	Check("[M291] ↻ : une fois par jour (caché ensuite)", not swap:IsShown())
	-- infobulle : l'explication d'avant
	local tip = rawget(_G, "GameTooltip")
	NS:DailyData().rerolled = nil
	NS:RefreshJournal()
	if tip then tip.lines = {} end
	swap:GetScript("OnEnter")(swap)
	local found = false
	for _, line in ipairs(tip and tip.lines or {}) do if tostring(line):find(L.MIS_REROLL_TIP, 1, true) then found = true end end
	Check("[M291] ↻ : infobulle « une fois par jour »", found, table.concat(tip and tip.lines or {}, " | "))
	if swap:GetScript("OnLeave") then swap:GetScript("OnLeave")(swap) end

	-- bande résumé : comptes, pastilles, bonus
	local sum = day.summary
	Check("[M291] résumé : compagnon 0/1 et son caractère", sum.trait.count.text == "0/1" and #sum.trait.pips == 1
		and not sum.trait.pips[1].on and sum.trait.detail.text:find(NS:PersonaLabel("glutton"), 1, true) ~= nil, sum.trait.detail.text)
	Check("[M291] résumé : du jour 1/3 (compagnon compris), une pastille sur trois", sum.zone.count.text == "1/3"
		and sum.zone.pips[1].on and not sum.zone.pips[2].on and not sum.zone.pips[3].on)
	Check("[M291] résumé : bonus des 3 du jour (Festin + Lasso)", sum.zone.detail.text:find(NS:TreatLabel("festin"), 1, true)
		and sum.zone.detail.text:find(NS:CaptureAidLabel("lasso"), 1, true), sum.zone.detail.text)
	Check("[M291] résumé : semaine 1/3, jours restants et bonus", sum.week.count.text == "1/3" and sum.week.pips[1].on
		and sum.week.detail.text:find("2", 1, true) and sum.week.detail.text:find(NS:CaptureAidLabel("sifflet"), 1, true), sum.week.detail.text)
	-- étiquettes des intertitres
	Check("[M291] étiquettes : zone du jour, caractère, décompte de la semaine", day.chips.zone:IsShown()
		and day.chips.zone.text.text == "Val des missions" and day.chips.trait.text.text == NS:PersonaLabel("glutton")
		and day.chips.week:IsShown() and day.chips.week.text.text == NS:F("SUM_LEFT", NS:WeeklyEndsText()))
	-- encarts des 3
	local zbox, wbox = day.callouts.zone, day.callouts.week
	Check("[M291] encart du jour : bonus des 3, Festin et Lasso en icônes", zbox:IsShown() and zbox.text.text == L.MIS_ALL_BONUS
		and zbox.icons[1].texture == NS.TREAT_ICONS.festin and zbox.icons[2].texture == lasso)
	Check("[M291] encart de la semaine : Festin et Sifflet", wbox:IsShown() and wbox.text.text == L.WK_ALL_BONUS
		and wbox.icons[2].texture == NS.CAPTURE_AIDS[3].icon)
	local shown = 0
	for _, dash in ipairs(zbox.dashes) do if dash:IsShown() then shown = shown + 1 end end
	Check("[M291] encart en pointillés (tirets réutilisés)", shown >= 40 and shown == #zbox.dashes, shown .. " / " .. #zbox.dashes)
	local zr, last = Rect(zbox, f), Rect(m[3], f)
	Check("[M291] encart sous son groupe, toute la largeur", zr.top >= last.top + MIS.cardH and Near(zr.width, MIS.leftW))
	-- droite : 7 tampons ronds, garde-manger, besace
	Check("[M291] auberges : 7 tampons, 3 obtenus, le 7e : le Festin", #day.stamps == 7 and day.stamps[3].got
		and not day.stamps[4].got and day.stamps[1].texture == NS.INN_STAMP_ICONS.stamp and day.stamps[7].texture == NS.TREAT_ICONS.festin)
	Check("[M291] garde-manger dans son cadre (compte, Donner)", #day.slots == 5 and day.slots[1]:GetParent() == day.pantryPanel
		and day.slots[1].count.text:find("/", 1, true) ~= nil)
	Check("[M291] besace dans son cadre (3 aides)", #day.aids == 3 and day.aids[1]:GetParent() == day.aidPanel)
	local inn, pantry, aid = Rect(day.innPanel, f), Rect(day.pantryPanel, f), Rect(day.aidPanel, f)
	Check("[M291] colonne de droite empilée, au-dessus du pied", pantry.top > inn.top + inn.height and aid.top > pantry.top + pantry.height
		and aid.top + aid.height <= Rect(f.footer, f).top, (aid.top + aid.height) .. " / " .. Rect(f.footer, f).top)
	-- construit une fois : un rafraîchissement ne crée rien
	local before = #zbox.dashes
	local card1 = m[1]
	NS:RefreshJournal()
	Check("[M291] rafraîchi : mêmes cartes, mêmes tirets", day.missions[1] == card1 and #zbox.dashes == before)
	-- missions coupées : une carte large explique
	NS:DB().companionMissions = false
	NS:RefreshJournal()
	Check("[M291] coupées : une carte large par groupe le dit", m[1].label.text == L.MIS_OFF and m[1].cardW == MIS.leftW
		and not m[1].bar:IsShown() and not m[1].stamp:IsShown() and m[2].label.text == L.MIS_OFF and m[2].cardW == MIS.leftW
		and not m[3]:IsShown())
	Check("[M291] coupées : résumé sans compte, pas d'encart", day.summary.zone.count.text == "-" and not day.callouts.zone:IsShown())
	NS:DB().companionMissions = true
	f:Hide()
	MS.Done()
end

-- 3. Habit Azeroth : encres mesurées, anneaux, pager --------------------------------------------------
do
	Say("-- 2.9.1 missions : habit Azeroth")
	MS.Reset("azeroth")
	local f = Open("day")
	local day = f.day
	local m = day.missions
	Check("[M291] Azeroth : carnet habillé", f.azeroth == true)
	Check("[M291] Azeroth : cartes sur le fond des hauts faits, icône dans son cadre", m[1].azBg and m[1].azBg.texture == 235397
		and m[1].azRing ~= nil)
	Check("[M291] Azeroth : carte faite, encres « mcardDone »", Same(m[2].label.textColor, Role("mcardDone.title"))
		and Same(m[2].zone.textColor, Role("mcardDone.zone")) and Same(m[2].count.textColor, Role("mcardDone.count")))
	Check("[M291] Azeroth : carte à faire, encres « mcard »", Same(m[3].label.textColor, Role("mcard.title"))
		and Same(m[3].zone.textColor, Role("mcard.zone")) and Same(m[1].source.textColor, Role("mcard.reward")))
	Check("[M291] Azeroth : voile vert mesuré d'une carte faite", Same(m[2].tint.vertex or {}, NS.AZEROTH_MISSION.tint))
	Check("[M291] Azeroth : tampon blanc sur vert", Same(m[2].stamp.text.textColor, Role("mission.stamp")))
	Check("[M291] Azeroth : ↻ dans l'anneau rond des hauts faits", m[3].reroll.azRing and m[3].reroll.azRing.atlas == NS.AZEROTH_ATLAS.frameRound)
	Check("[M291] Azeroth : plaques du résumé sombres, encres mesurées", day.summary.zone.azStyle == "dark"
		and Same(day.summary.zone.label.textColor, Role("summary.label")) and Same(day.summary.zone.count.textColor, Role("summary.count"))
		and Same(day.summary.zone.detail.textColor, Role("summary.detail")))
	Check("[M291] Azeroth : encart des 3 à l'encre, pointillés bruns", Same(day.callouts.zone.text.textColor, Role("bonus.text"))
		and Same(day.callouts.zone.dashes[1].vertex or {}, NS.AZEROTH_MISSION.dash))
	Check("[M291] Azeroth : étiquettes blanches sur aplat", Same(day.chips.zone.text.textColor, Role("chip.zone"))
		and Same(day.chips.trait.bg.vertex or {}, NS.AZEROTH_MISSION.chipTrait))
	Check("[M291] Azeroth : colonne de droite à l'encre", Same(day.innTotal.textColor, Role("panel.text"))
		and Same(day.innHint.textColor, Role("panel.soft")) and Same(day.slots[1].count.textColor, Role("panel.text")))
	-- carte large puis demie : le fond est recadré à sa taille
	Check("[M291] Azeroth : fond recadré à la largeur de la carte", m[1].azCoverW == MIS.leftW and m[2].azCoverW == MIS.half)
	-- les rôles mesurés de la page
	local roles = { "mcard.title", "mcard.zone", "mcard.count", "mcard.reward", "mcardDone.title", "mcardDone.zone",
		"mcardDone.count", "mcardDone.reward", "mission.stamp", "chip.zone", "chip.trait", "summary.label", "summary.count",
		"summary.detail", "bonus.text", "panel.text", "panel.soft", "panel.muted", "pager.position" }
	local bad = {}
	for _, key in ipairs(roles) do
		local role = NS.AZEROTH_CONTRAST[key]
		if not role or NS.AzerothContrast(INK[role[1]], role[2]) < role[3] then bad[#bad + 1] = key end
	end
	Check("[M291] rôles mesurés de la page Missions : 4,5:1 au moins", #bad == 0, table.concat(bad, ","))
	-- les aplats : la luminance déclarée est celle de leur couleur
	Check("[M291] aplats : luminance exacte du tampon et des étiquettes",
		Near(NS.AzerothLuminance(NS.AZEROTH_MISSION.stamp), NS.AZEROTH_CONTRAST["mission.stamp"][2])
		and Near(NS.AzerothLuminance(NS.AZEROTH_MISSION.chipZone), NS.AZEROTH_CONTRAST["chip.zone"][2])
		and Near(NS.AzerothLuminance(NS.AZEROTH_MISSION.chipTrait), NS.AZEROTH_CONTRAST["chip.trait"][2]))
	-- 2.9.1 : compteur des pagers (Exploration, Créatures) à l'encre mesurée
	NS:SelectJournalKind("progress")
	local prog = f.prog
	Check("[M291] Exploration : compteurs des pagers à l'encre", prog and Same(prog.zonePager.position.textColor, Role("pager.position"))
		and prog.zonePager.position.azKeep and Same(prog.listPager.position.textColor, Role("pager.position")))
	Check("[M291] Créatures : compteur du pager à l'encre", f.men and Same(f.men.pager.position.textColor, Role("pager.position")))
	f:Hide()
	MS.Done()
end
