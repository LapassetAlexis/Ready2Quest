-- QuestCompanion 3.0.0 : interface harmonisée (docs/UI.md, « Composants 3.0 »).
-- Tailles canoniques (rangée d'outils, trois tailles de bouton), état
-- désactivé lisible dans les deux styles (Sobre : Theme.DISABLED opaque ;
-- Azeroth : bois délavé, libellé ≥ 4,5:1), bouton « inactif » qui garde son
-- clic, pastille de monnaie (Réserve, Échanges, Échoppe), l'Échoppe du
-- dresseur en onglet (navigation, visite guidée), « Acheter » sans assez de
-- paillettes : la raison dans le chat et la pastille secouée ; rangée du haut
-- de la Réserve à une seule hauteur ; colonne de navigation qui tient ; aucun
-- cadre créé au rafraîchissement.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local C = { saved = {} }
local GLOBALS = { "UnitLevel", "InCombatLockdown", "UnitAffectingCombat", "C_Timer" }
for _, name in ipairs(GLOBALS) do C.saved[name] = rawget(_G, name) end
local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "effectsConfirm" }
local ZONE = 1413

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.001 then return false end end
	return true
end
local function Has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end

function C.Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.uiStyleCache, NS.errors, NS.carnetInkMisses = nil, {}, {}, nil
	NS.specimenCountCache, NS.codexReserveCache, NS.codexZoneCache = nil, nil, nil
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
	Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = ZONE, 20
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.C_Timer = nil
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:CompanionData().tutoDone = true
	NS:CompanionData().appearance = nil
	local data = NS:CaptureData()
	data.creatures[900] = { name = "Raptor", normal = true, stars = 3, zoneID = ZONE, type = "Bête", at = 1793000000 }
	data.creatures[901] = { name = "Kodo", normal = true, stars = 1, zoneID = ZONE, type = "Bête", at = 1793000100 }
	data.count = 2
	NS:SpecimenMigrate()
	-- en Réserve : un Raptor moins bon (relâchable), un Kodo meilleur que le Codex (pas relâchable)
	C.low = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor", origin = "capture", by = "Dyokrion", zone = ZONE })
	local ref = NS:SpecimenReference(901, false)
	C.better = NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo", origin = "capture", by = "Dyokrion", zone = ZONE })
	NS:SpecimenSetReference(ref.id)
end

function C.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = C.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.codexReserveCache, NS.codexZoneCache = nil, nil
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
	ResetWorld()
end

-- 1. Tailles canoniques (socle) ---------------------------------------------------------------------------
do
	Say("-- qc30 composants : tailles canoniques")
	ResetWorld()
	local parent = CreateFrame("Frame", nil, UIParent)
	local S = Theme.BUTTON_SIZES
	Check("[UI30] jetons : rangée d'outils 24, boutons xs 18 / sm 24 / md 28", Theme.CONTROL_HEIGHT == 24 and S.xs == 18
		and S.sm == 24 and S.md == 28 and Theme.CHIP_HEIGHT == Theme.CONTROL_HEIGHT)
	local sm = Theme.CreateButton(parent, 100, "sm", "Un")
	local md = Theme.CreateButton(parent, 100, nil, "Deux")
	local xs = Theme.CreateButton(parent, 100, "xs", "Trois")
	local n = Theme.CreateButton(parent, 100, 30, "Quatre")
	Check("[UI30] bouton : taille nommée ou nombre (nil : md)", sm:GetHeight() == 24 and sm.size == "sm" and md:GetHeight() == 28
		and xs:GetHeight() == 18 and n:GetHeight() == 30 and n.size == nil)
	local chips = Theme.CreateChips(parent, { { id = "a", label = "Tous" }, { id = "b", label = "Brillants" } })
	local drop = Theme.CreateDropdown(parent, 120)
	local search = Theme.CreateSearchBox(parent, 120, "…")
	local badge = Theme.CreateCurrency(parent, { icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02", label = "paillettes" })
	Check("[UI30] puces, liste déroulante, recherche, pastille : une seule hauteur", chips:GetHeight() == 24
		and chips.byId.a:GetHeight() == 24 and drop:GetHeight() == 24 and search:GetHeight() == 24 and badge:GetHeight() == 24)
	Check("[UI30] liste déroulante : hauteur à la demande", Theme.CreateDropdown(parent, 120, nil, { height = 30 }):GetHeight() == 30)
	badge:SetValue(40)
	local narrow = badge:GetWidth()
	badge:SetValue(12345)
	Check("[UI30] pastille : chiffre, libellé, largeur au contenu", badge.value:GetText() == "12345" and badge.label:GetText() == "paillettes"
		and badge:GetWidth() > narrow and badge.amount == 12345)
	Check("[UI30] pastille : icône du client", badge.icon.texture == "Interface\\Icons\\INV_Misc_Gem_Diamond_02"
		or badge.icon.file == "Interface\\Icons\\INV_Misc_Gem_Diamond_02" or badge.icon.tex == "Interface\\Icons\\INV_Misc_Gem_Diamond_02"
		or (badge.icon.GetTexture and badge.icon:GetTexture() == "Interface\\Icons\\INV_Misc_Gem_Diamond_02"))
	local plays = badge.shake and badge.shake.plays or 0
	Check("[UI30] pastille secouée : secousse jouée, voile rouge", badge:Flash() == 1 and badge.shake ~= nil
		and badge.shake.plays == plays + 1 and #badge.shake.animations == #Theme.CURRENCY.shake
		and badge.shake.animations[1].kind == "Translation")
	parent:Hide()
end

-- 2. État désactivé (Sobre) : lisible, opaque ; bouton inactif ----------------------------------------------
do
	Say("-- qc30 composants : désactivé et inactif (Sobre)")
	ResetWorld()
	local parent = CreateFrame("Frame", nil, UIParent)
	local D = Theme.DISABLED
	local bad = {}
	for _, style in ipairs({ "outline", "accent", "primary", "adventure" }) do
		local b = Theme.CreateButton(parent, 100, "sm", style, nil, style)
		b:SetEnabled(false)
		local filled = Theme.BUTTON_STYLES[style].filled
		local under = filled and D.bg or Theme.WINDOW
		local ratio = Theme.Contrast(D.text, under)
		if not (b.disabledLook and b.alpha == 1 and Same(b.text.textColor, D.text) and ratio >= 4.5) then
			bad[#bad + 1] = style .. string.format("=%.2f", ratio)
		end
		b:SetEnabled(true)
		if b.disabledLook or not Same(b.text.textColor, Theme.BUTTON_STYLES[style].text) then bad[#bad + 1] = style .. " (réactivé)" end
	end
	Check("[UI30] désactivé : opaque, libellé MUTED ≥ 4,5:1 (fond CONTROL ou fenêtre), quel que soit le style", #bad == 0,
		table.concat(bad, ", "))
	local clicks = 0
	local b = Theme.CreateButton(parent, 100, "sm", "Acheter", function() clicks = clicks + 1 end, "primary")
	b:SetInactive(true, "Il te manque 5 paillettes.")
	b.scripts.OnEnter(b)
	Check("[UI30] inactif : aspect désactivé, pas de survol, raison en infobulle", b.disabledLook and b.paintState == "disabled"
		and b.disabledTip == "Il te manque 5 paillettes.")
	b.scripts.OnMouseDown(b, "LeftButton")
	Check("[UI30] inactif : pas d'appui", b.text.lastPoint.x == 0)
	b:GetScript("OnClick")(b)
	Check("[UI30] inactif : le clic passe (le module explique)", clicks == 1)
	b:SetInactive(false)
	Check("[UI30] actif de nouveau : style d'origine", not b.disabledLook and b.disabledTip == nil
		and Same(b.text.textColor, Theme.INK))
	parent:Hide()
end

-- 3. Boutons Azeroth : un seul peintre d'états (carnet et capture) -------------------------------------------
do
	Say("-- qc30 composants : boutons Azeroth")
	C.Reset("azeroth")
	local AZB, INK = NS.AZEROTH_BUTTONS, NS.AZEROTH_INK
	local f = NS:OpenReserve()
	local rv = f.res.reserve
	NS:ReservePick(C.better)
	local toCodex, release = rv.toCodex, rv.release
	-- le défaut de la bêta 4 : après Enable(true), l'encre sombre du bouton plein retombait sur le rouge
	Check("[UI30] « Mettre au Codex » : rouge, libellé doré (pas l'encre sombre)", toCodex.azSkin == "red"
		and toCodex.skinPaint == NS.AzerothButtonState and Same(toCodex.text.textColor, INK.goldText)
		and not Same(toCodex.text.textColor, Theme.INK) and toCodex.alpha == 1)
	Check("[UI30] « Relâcher » refusé : bois délavé, libellé clair atténué", release.qcEnabled == false and release.disabledLook
		and release.azState == "disabled" and Same(release.text.textColor, AZB.offText) and release.alpha == 1)
	local off = NS.AzerothContrast(AZB.offText, NS.AzerothLuminance(AZB.off.top))
	local role = NS.AZEROTH_CONTRAST["button.off"]
	Check("[UI30] libellé désactivé : ≥ 4,5:1 sur le haut du dégradé (le plus clair), rôle button.off", off >= 4.5 and role
		and role[1] == "buttonOff" and math.abs(role[2] - NS.AzerothLuminance(AZB.off.top)) < 0.001, string.format("%.2f", off))
	local onRed = NS.AzerothContrast(INK.goldText, NS.AzerothLuminance(AZB.red.top))
	local onBrown = NS.AzerothContrast(INK.goldText, NS.AzerothLuminance(AZB.brown.top))
	Check("[UI30] libellé actif : ≥ 4,5:1 sur le rouge et le brun", onRed >= 4.5 and onBrown >= 4.5,
		string.format("%.2f / %.2f", onRed, onBrown))
	toCodex.scripts.OnEnter(toCodex)
	Check("[UI30] survol : voile doré", toCodex.azState == "hover" and toCodex.azHover:IsShown())
	toCodex.scripts.OnMouseDown(toCodex, "LeftButton")
	Check("[UI30] appui : voile sombre, libellé décalé", toCodex.azState == "pressed" and toCodex.azPress:IsShown()
		and toCodex.text.lastPoint.x == 1)
	toCodex.scripts.OnMouseUp(toCodex)
	toCodex.scripts.OnLeave(toCodex)
	Check("[UI30] repos", toCodex.azState == "rest" and not toCodex.azHover:IsShown() and not toCodex.azPress:IsShown())
	-- les boutons dessinés des fenêtres de capture : mêmes états
	local cap = NS:AzerothButton(UIParent, 120, 30, "Lancer", nil, "gold")
	cap:Disable()
	Check("[UI30] bouton de capture désactivé : même bois délavé", cap.azState == "disabled" and Same(cap.text.textColor, AZB.offText))
	cap:Enable()
	Check("[UI30] … réactivé : doré", cap.azState == "rest" and Same(cap.text.textColor, AZB.text))
	cap:Hide()
	Check("[UI30] aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
	C.Done()
end

-- 4. Réserve : rangée du haut à une hauteur, pastille, deuxième rangée -------------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc30 composants : Réserve (" .. style .. ")")
	C.Reset(style)
	NS:PaillettesAdd(40, "test")
	local f = NS:OpenReserve()
	local pane, rv = f.res, f.res.reserve
	local H = Theme.CONTROL_HEIGHT
	local chip = pane.views.chips[1]
	Check("[UI30] " .. style .. " : puces Réserve / Échanges (l'Échoppe n'y est plus)", #pane.views.chips == 2
		and pane.views.byId.reserve and pane.views.byId.trade and not pane.views.byId.shop)
	Check("[UI30] " .. style .. " : rangée du haut : puces, « Échanger avec ma cible », pastille à la même hauteur",
		chip:GetHeight() == H and rv.tradeButton:GetHeight() == H and pane.balance:GetHeight() == H and rv.tradeButton.size == "sm",
		chip:GetHeight() .. "/" .. rv.tradeButton:GetHeight() .. "/" .. pane.balance:GetHeight())
	local p = rv.tradeButton.lastPoint or {}
	Check("[UI30] " .. style .. " : « Échanger avec ma cible » calé sur le haut des puces", p.point == "TOPLEFT" and p.relTo == pane.views
		and p.relPoint == "TOPRIGHT" and p.y == 0)
	Check("[UI30] " .. style .. " : 2e rangée : listes et puces Tous / Brillants à la même hauteur", rv.sort:GetHeight() == H
		and rv.species:GetHeight() == H and rv.show.chips[1]:GetHeight() == H and rv.show:GetHeight() == H)
	Check("[UI30] " .. style .. " : pastille de la Réserve : solde", not pane.balance.mockHidden and pane.balance.value:GetText() == "40"
		and pane.balance.flash ~= nil, tostring(pane.balance:IsShown()) .. " " .. tostring(pane.balance.value:GetText()))
	local before = #Mock.frames
	NS:RefreshJournal(); NS:RefreshJournal()
	Check("[UI30] " .. style .. " : rafraîchi sans créer de cadre", #Mock.frames == before, #Mock.frames .. "/" .. before)
	-- Échanges : la même pastille (celle de la page), toujours visible
	pane.views:Select("trade")
	Check("[UI30] " .. style .. " : vue Échanges : la pastille reste", f.resView == "trade" and pane.trade:IsShown()
		and not pane.balance.mockHidden and pane.balance.value:GetText() == "40")
	if style == "azeroth" then
		Check("[UI30] azeroth : pastille sur aplat sombre, encres currency.*", pane.balance.azSurface == "dark"
			and pane.balance.value.azRole == "currency.value" and pane.balance.label.azRole == "currency.label")
		Check("[UI30] azeroth : intertitre de l'historique canonique", pane.trade.histHead.label ~= nil)
	end
	Check("[UI30] " .. style .. " : aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
	C.Done()
end

-- 5. L'Échoppe du dresseur : son onglet, sa pastille, le refus expliqué au clic ------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc30 composants : Échoppe (" .. style .. ")")
	C.Reset(style)
	NS:PaillettesAdd(30, "test")
	local f = NS:ToggleJournal(true) and NS.journalFrame or NS.journalFrame
	Check("[UI30] " .. style .. " : onglet « Échoppe du dresseur » après la Réserve", f.sections.shop ~= nil
		and f.sections.shop:GetText() == "Échoppe du dresseur" and NS.JOURNAL_SECTIONS[4] == "shop")
	f.sections.shop:GetScript("OnClick")(f.sections.shop)
	local sv = f.shopPane
	Check("[UI30] " .. style .. " : clic sur l'onglet : la page, titre et sous-titre", f.kind == "shop" and sv:IsShown()
		and not f.res:IsShown() and f.header.title:GetText() == "Échoppe du dresseur" and f.sections.shop.selected ~= false)
	Check("[UI30] " .. style .. " : pastille de l'Échoppe : même composant, même solde", sv.balance ~= f.res.balance
		and sv.balance:GetHeight() == f.res.balance:GetHeight() and sv.balance.value:GetText() == "30" and sv.balance.Flash ~= nil)
	local rows = {}
	for _, row in ipairs(sv.rows) do rows[row.item.id] = row end
	local buy = rows.sifflet.buy
	Check("[UI30] " .. style .. " : Sifflet (40) : hors de portée, aspect désactivé mais cliquable", rows.sifflet.state == "short"
		and buy.disabledLook and buy.inactive and buy.qcEnabled == false and buy.size == "sm")
	Mock:Reset()
	local flashes = sv.balance.flashes or 0
	buy:GetScript("OnClick")(buy)
	Check("[UI30] " .. style .. " : clic : « Il te manque 10 paillettes pour Sifflet du dompteur. » dans le chat",
		Has(Mock:Output(), "Il te manque 10 paillettes pour Sifflet du dompteur."), Mock:Output())
	Check("[UI30] " .. style .. " : … la pastille secouée, rien d'acheté, pas de confirmation", (sv.balance.flashes or 0) == flashes + 1
		and NS:Paillettes() == 30 and f.shopConfirm == nil and buy:IsShown())
	NS:CaptureData().items = NS:CaptureData().items or {}
	NS:CaptureData().items.appat = 99
	NS:RefreshJournal()
	Mock:Reset()
	rows.appat.buy:GetScript("OnClick")(rows.appat.buy)
	Check("[UI30] " .. style .. " : besace pleine : la limite dite au clic, pas de secousse", rows.appat.state == "full"
		and Has(Mock:Output(), "Besace pleine") and (sv.balance.flashes or 0) == flashes + 1)
	NS:CaptureData().items.appat = 0
	NS:RefreshJournal()
	rows.lasso.buy:GetScript("OnClick")(rows.lasso.buy)
	Check("[UI30] " .. style .. " : à portée : la confirmation dans la ligne", f.shopConfirm == "lasso" and rows.lasso.yes:IsShown()
		and not rows.lasso.buy.disabledLook)
	NS:ReserveCancelConfirm()
	local before = #Mock.frames
	NS:RefreshJournal(); NS:RefreshJournal()
	Check("[UI30] " .. style .. " : rafraîchi sans créer de cadre", #Mock.frames == before)
	Check("[UI30] " .. style .. " : OpenReserve(\"shop\") mène à l'onglet", NS:OpenReserve("shop") and f.kind == "shop")
	if style == "azeroth" then
		Check("[UI30] azeroth : boutons Acheter rouges ; refusé : bois délavé", rows.lasso.buy.azSkin == "red"
			and rows.sifflet.buy.azState == "disabled" and Same(rows.sifflet.buy.text.textColor, NS.AZEROTH_BUTTONS.offText))
		Check("[UI30] azeroth : aucun rôle manquant", NS.carnetInkMisses == nil, table.concat(NS.carnetInkMisses or {}, ", "))
	end
	Check("[UI30] " .. style .. " : aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
	C.Done()
end

-- 6. Visite du carnet : l'étape de l'Échoppe ----------------------------------------------------------------
do
	Say("-- qc30 composants : visite guidée")
	local ids = {}
	for _, step in ipairs(NS.TOUR_DEFS.journal.steps) do ids[#ids + 1] = step.id end
	local list = table.concat(ids, ",")
	Check("[UI30] visite du carnet : l'Échoppe entre la Réserve et les hauts faits", Has(list, "reserve,shop,feats"), list)
	Check("[UI30] textes de l'étape (FR)", Has(NS.L.TOUR_B_shop, "paillettes") and Has(NS.L.TOUR_B_reserve, "onglet suivant"))
end

-- 7. Colonne de navigation : neuf entrées qui tiennent, dans les deux styles --------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc30 composants : navigation (" .. style .. ")")
	C.Reset(style)
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	local count = 0
	for _ in pairs(f.sections) do count = count + 1 end
	local box = f.navSummary
	local lay = NS.CARNET_LAYOUT
	local navH = style == "azeroth" and (f:GetHeight() - lay.band - lay.wood) or (f:GetHeight() - 2)
	local bottom = -(box.lastPoint and box.lastPoint.y or 0) + box:GetHeight()
	local reserved = style == "azeroth" and 50 + 16 or 18 + 16
	Check("[UI30] " .. style .. " : neuf onglets, le tableau de bord tient au-dessus du bas", count == 9 and bottom <= navH - reserved,
		count .. " / " .. bottom .. " / " .. navH)
	C.Done()
end
