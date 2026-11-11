-- Socle commun (Libs/Socle) : jeton de rareté, contraste des paires réelles
-- (texte/fond, boutons), états des contrôles (survol, appui, désactivé,
-- module coupé), pictos et cases du client avec repli, pulsations et fondus,
-- socle chargé une fois (fabriques partagées, empreinte, ns.Shared, seul),
-- pluriels, « Avant le départ » hiérarchisé (R2Q 1.32.0), couleurs du texte
-- déclarées une fois (ns.TC) et messages traduits (fiche 28), horloge unique
-- par addon (ns.Every / ns.Soon / ns.Cancel, fiche 25).
local Check, Say, NS, QNS, Mock, ResetWorld, Result = T.Check, T.Say, T.NS, T.QNS, T.Mock, T.ResetWorld, T.Result
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.002 then return false end end
	return true
end
local function ReadFile(path)
	local h = io.open(ROOT .. "/" .. path, "rb")
	if not h then return nil end
	local data = h:read("*a")
	h:close()
	return data
end
-- plusieurs points d'un même sujet : une vérification, les points en échec nommés
local failed = {}
local function Want(label, ok) if not ok then failed[#failed + 1] = label end return ok end
local function Verdict(name) Check(name, #failed == 0, table.concat(failed, " | ")); failed = {} end
local DARK = { "WINDOW", "NAV", "ROW", "ROW_ALT", "FIELD" }

-- 1. Jeton de rareté (Theme.RANK) -----------------------------------------------------------------
do
	Say("-- socle : jeton de rareté")
	local bad = {}
	for key, color in pairs(Theme.RANK) do
		for _, bg in ipairs(DARK) do
			local r = Theme.Contrast(color, Theme[bg])
			if r < 4.5 then bad[#bad + 1] = string.format("%s/%s=%.2f", key, bg, r) end
		end
	end
	Check("[SOC] Theme.RANK : 4,5:1 sur WINDOW, NAV, ROW, ROW_ALT, FIELD", #bad == 0, table.concat(bad, ", "))
	local missing = {}
	for class in pairs(Theme.RANK_KEYS) do if type(Theme.RankColor(class)) ~= "table" then missing[#missing + 1] = class end end
	Want("classification -> clé", Theme.RankKey("rareelite") == "rare" and Theme.RankKey("worldboss") == "boss"
		and Theme.RankKey("minus") == "trivial" and Theme.RankKey(nil) == "normal" and Theme.RankKey("inconnu") == "normal")
	Want("couleur manquante : " .. table.concat(missing, ","), #missing == 0)
	Want("brillante : or clair", Theme.RankColor("elite", true) == Theme.GOLD_LIGHT)
	Want("copie de QuestCompanion", Same(QNS.Theme.RANK.elite, Theme.RANK.elite) and QNS.Theme.RankKey("rareelite") == "rare")
	Verdict("[SOC] rareté : clé par classification, une couleur chacune, brillante en or, même jeton dans QC")
end

-- 2. Contraste du socle (paires réelles) -------------------------------------------------------------
do
	Say("-- socle : contraste des paires réelles")
	local Over = Theme.Over
	local BG = {
		WINDOW = Theme.WINDOW, NAV = Theme.NAV, FIELD = Theme.FIELD, ROW = Theme.ROW, ROW_ALT = Theme.ROW_ALT,
		ROW_HOVER = Over(Theme.ROW, Theme.WHITE, Theme.HOVER_ALPHA), ROW_ALT_HOVER = Over(Theme.ROW_ALT, Theme.WHITE, Theme.HOVER_ALPHA),
		DROP_HOVER = Over(Theme.FIELD, Theme.GOLD, 0.10),
	}
	local PAIRS = {
		PARCHMENT = { "WINDOW", "NAV", "ROW", "ROW_ALT", "ROW_HOVER", "ROW_ALT_HOVER" },
		LABEL = { "WINDOW", "NAV", "FIELD", "ROW", "ROW_ALT", "ROW_HOVER", "ROW_ALT_HOVER", "DROP_HOVER" },
		TEXT = { "WINDOW", "NAV", "ROW", "ROW_ALT", "ROW_HOVER", "ROW_ALT_HOVER" },
		MUTED_LIGHT = { "WINDOW", "NAV", "ROW", "ROW_ALT", "ROW_HOVER", "ROW_ALT_HOVER" },
		MUTED = { "WINDOW", "NAV", "FIELD", "ROW", "ROW_ALT", "ROW_HOVER", "ROW_ALT_HOVER", "DROP_HOVER" },
		GOLD = { "WINDOW", "NAV", "ROW", "ROW_ALT", "ROW_HOVER", "ROW_ALT_HOVER" },
		BLUE = { "WINDOW", "NAV", "ROW", "ROW_ALT" }, GREEN = { "WINDOW", "ROW", "ROW_ALT" }, RED = { "WINDOW", "ROW", "ROW_ALT" },
	}
	local bad = {}
	for fg, list in pairs(PAIRS) do
		for _, bg in ipairs(list) do
			local r = Theme.Contrast(Theme[fg], BG[bg])
			if r < 4.5 then bad[#bad + 1] = string.format("%s/%s=%.2f", fg, bg, r) end
		end
	end
	Check("[SOC] paires texte/fond du socle : 4,5:1", #bad == 0, table.concat(bad, ", "))
	bad = {}
	for name, s in pairs(Theme.BUTTON_STYLES) do
		local under = (s.bgAlpha or 0) < 1 and { BG.WINDOW, BG.NAV, BG.ROW } or { s.bg }
		for _, base in ipairs(under) do
			local rest = (s.bgAlpha or 0) < 1 and Over(base, s.bg, s.bgAlpha or 0) or s.bg
			if Theme.Contrast(s.text, rest) < 4.5 then bad[#bad + 1] = name .. " repos" end
			local hover = s.hoverBg or (s.hoverAlpha and Over(base, s.bg, s.hoverAlpha)) or rest
			if Theme.Contrast(s.text, hover) < 4.5 then bad[#bad + 1] = name .. " survol" end
		end
		if s.filled and Theme.Contrast(s.text, Over(s.bg, Theme.INK, Theme.PRESS_SHADE)) < 4.5 then bad[#bad + 1] = name .. " enfoncé" end
	end
	Check("[SOC] chaque style de bouton : 4,5:1 au repos, au survol, enfoncé", #bad == 0, table.concat(bad, ", "))
	Check("[SOC] formule : noir/blanc = 21, luminance acceptée, la même que le carnet",
		math.abs(Theme.Contrast({ 0, 0, 0 }, { 1, 1, 1 }) - 21) < 0.01 and math.abs(Theme.Contrast({ 1, 1, 1 }, 0) - 21) < 0.01
		and math.abs(Theme.Contrast(Theme.GOLD, Theme.ROW) - QNS.AzerothContrast(Theme.GOLD, QNS.AzerothLuminance(Theme.ROW))) < 0.001)
end

-- 3. États des contrôles ---------------------------------------------------------------------------
do
	Say("-- socle : survol, appui, désactivé")
	local parent = CreateFrame("Frame", nil, UIParent)
	local card = Theme.CreateSettingCard(parent, 300, 38, "Button")
	Want("repos : voile caché", card.hover.vertex[4] == Theme.HOVER_ALPHA and not card.hover:IsShown() and not card.hover.edge.top:IsShown())
	card.scripts.OnEnter(card)
	Want("survol : voile et filet EDGE", card.hover:IsShown() and card.hover.edge.top:IsShown() and Same(card.hover.edge.left.vertex, Theme.EDGE))
	card.scripts.OnLeave(card)
	Want("quittée : caché", not card.hover:IsShown() and not card.hover.edge.right:IsShown())
	local row = Theme.CreateListRow(parent, 300, 26, { kind = "Button" })
	Want("ligne : même voile", row.hover.vertex[4] == Theme.HOVER_ALPHA and row.hover.edge ~= nil)
	Verdict("[SOC] carte et ligne : voile HOVER_ALPHA et filet EDGE au survol seulement")

	local btn = Theme.CreateButton(parent, 120, 28, "Partir", nil, "adventure")
	btn.scripts.OnMouseDown(btn, "LeftButton")
	Want("plein enfoncé : libellé (1, -1), fond assombri", btn.text.lastPoint.x == 1 and btn.text.lastPoint.y == -1
		and Same(btn.bg.vertex, Theme.Over(Theme.BLUE, Theme.INK, Theme.PRESS_SHADE)))
	btn.scripts.OnMouseUp(btn)
	Want("relâché : repos", btn.text.lastPoint.x == 0 and Same(btn.bg.vertex, Theme.BLUE))
	local outline = Theme.CreateButton(parent, 120, 28, "Réinitialiser", nil, "outline")
	outline.scripts.OnMouseDown(outline, "LeftButton")
	Want("au trait enfoncé : contour ambre sombre", Same(outline.border.top.vertex, Theme.GOLD_SOFT))
	outline.scripts.OnMouseUp(outline)
	Verdict("[SOC] bouton enfoncé : libellé décalé, fond assombri ou contour ambre ; relâché : repos")

	-- désactivé (socle 3.0 : opaque, plus d'estompe illisible)
	btn.IsEnabled = function() return false end
	btn.disabledTip = "Pas maintenant"
	Theme.ButtonRest(btn)
	Want("opaque, MUTED sur CONTROL", btn.alpha == 1 and Same(btn.text.textColor, Theme.MUTED) and Same(btn.bg.vertex, Theme.CONTROL)
		and btn.disabledLook == true)
	btn.scripts.OnEnter(btn)
	Want("pas de survol", Same(btn.bg.vertex, Theme.CONTROL))
	btn.scripts.OnMouseDown(btn, "LeftButton")
	Want("pas d'appui", btn.text.lastPoint.x == 0)
	btn.IsEnabled = function() return true end
	Theme.ButtonRest(btn)
	Want("réactivé : style d'origine", btn.alpha == 1 and Same(btn.text.textColor, Theme.INK) and Same(btn.bg.vertex, Theme.BLUE))
	Verdict("[SOC] bouton désactivé : opaque, MUTED sur CONTROL, ni survol ni appui ; réactivé : son style")
	parent:Hide()

	-- module coupé : cartes estompées, bandeau « Rallumer » (R2Q, page Déclencheurs)
	ResetWorld()
	local frame = NS:EnsureOptions()
	NS:SelectOptionsPage("trigger")
	local key = NS:OptionsPageModuleKey("trigger")
	NS:ToggleModuleKey(key)
	local dimmed, total = 0, 0
	for _, c in ipairs(frame.rows) do
		if c.pageId == "trigger" then total = total + 1; if c.alpha == Theme.DIM_ALPHA and c.dimmed then dimmed = dimmed + 1 end end
	end
	Want("clé du module de la page parente : " .. tostring(key), key == "departureEnabled")
	Want("cartes estompées " .. dimmed .. "/" .. total, total > 0 and dimmed == total)
	Want("bandeau et « Rallumer »", frame.offBanner:IsShown() and frame.header.subtitle.text == NS.L.OPT_PAGE_OFF
		and frame.offBanner:GetText() == NS.L.OPT_PAGE_OFF_ON)
	Verdict("[SOC] module coupé : cartes de sa page estompées, bandeau « Rallumer »")
	frame.offBanner:Click()
	local back, moduleCards = 0, 0
	for _, c in ipairs(frame.rows) do
		if c.pageId == "trigger" and c.alpha == 1 then back = back + 1 end
		if c.isModule and (c.alpha or 1) == 1 then moduleCards = moduleCards + 1 end
	end
	Check("[SOC] « Rallumer » : module actif, cartes pleines, bandeau caché ; cartes de module jamais estompées",
		NS:DB()[key] ~= false and back == total and not frame.offBanner:IsShown()
		and frame.header.subtitle.text ~= NS.L.OPT_PAGE_OFF and moduleCards > 0)
	frame:Hide()
end

-- 4. Pictos et cases du client, repli sans atlas -----------------------------------------------------
do
	Say("-- socle : atlas du client, repli")
	local parent = CreateFrame("Frame", nil, UIParent)
	Mock.InstallAtlas(nil)
	local d = Theme.CreateDiamond(parent, 10, false)
	-- socle 2.12.1 : le repli est un fichier du client (marqueur de raid losange), grisé
	Want("sans C_Texture : losange du client", d.texture == Theme.DIAMOND_FILE and d.clientSource == "fallback"
		and Theme.DIAMOND_FILE:find("^Interface\\") ~= nil and Theme.DIAMOND == nil)
	Mock.InstallAtlas(true)
	d = Theme.CreateDiamond(parent, 10, false)
	local line = Theme.CreateDiamond(parent, 10, true)
	Want("plein / au trait", d.atlas == "activities-complete-diamond" and d.clientSource == "activities-complete-diamond"
		and line.atlas == "activities-incomplete-diamond")
	Mock.InstallAtlas({ ["activities-complete-diamond"] = true })
	Want("premier atlas absent : le suivant", Theme.CreateDiamond(parent, 10, false).atlas == "genericwidgetbar-marker-diamond")
	Verdict("[SOC] losange : atlas du client, repli sur un fichier du client, jamais une image à nous")

	Mock.InstallAtlas(true)
	local gear = Theme.CreateGearButton(parent, 22, function() end, "Réglages")
	Want("atlas, sans carré", gear.icon.atlas == "questlog-icon-setting" and not gear.border.top:IsShown()
		and gear.gearAtlas == "questlog-icon-setting")
	Want("repos estompé", Same(gear.icon.vertex, Theme.GEAR.rest) and gear.icon.alpha == Theme.GEAR.rest[4])
	gear.scripts.OnEnter(gear)
	Want("survol plus clair", gear.gearHot == true and gear.icon.alpha == 1)
	gear.scripts.OnLeave(gear)
	Mock.InstallAtlas(nil)
	Want("sans atlas : UI-OptionsButton", Theme.CreateGearButton(parent, 22).icon.texture == "Interface\\Buttons\\UI-OptionsButton")
	Verdict("[SOC] roue : atlas du client, estompée au repos, claire au survol, repli UI-OptionsButton")

	Mock.InstallAtlas(true)
	local toggle = Theme.CreateToggle(parent)
	Want("case « checkbox-minimal »", toggle.checkbox and toggle.box.atlas == "checkbox-minimal" and toggle.width == Theme.CHECKBOX_SIZE
		and not toggle.track:IsShown() and not toggle.check:IsShown())
	toggle:SetChecked(true)
	Want("cochée", toggle.check:IsShown() and toggle.check.atlas == "checkmark-minimal" and toggle:GetChecked())
	toggle:SetPartial()
	Want("partielle", toggle.partialMark:IsShown() and not toggle.check:IsShown() and toggle.partialMark.atlas == "common-checkbox-partial")
	local power = Theme.CreatePowerButton(parent, 16)
	Theme.SetPowerState(power, true)
	Want("module : case cochée si actif", power.checkbox and power.check:IsShown() and not power.icon:IsShown())
	Mock.InstallAtlas(nil)
	local drawn = Theme.CreateToggle(parent)
	Want("sans atlas : interrupteur dessiné", not drawn.checkbox and drawn.track.mockHidden ~= true)
	Verdict("[SOC] cases à cocher du client (cochée, partielle, module), repli sur l'interrupteur dessiné")

	Mock.InstallAtlas(true)
	local dd = Theme.CreateDropdown(parent, 160, function() end, {})
	local pager = Theme.CreatePager(parent, function() end)
	Check("[SOC] chevrons du client : liste, pagination (tourné pour « haut »)",
		dd.chevron.atlas == "friendslist-categorybutton-arrow-down" and pager.up.icon.atlas == "friendslist-categorybutton-arrow-down"
		and pager.up.icon.rotation == math.pi)
	Mock.InstallAtlas(nil)
	parent:Hide()
end

-- 5. Pulsations et fondus ----------------------------------------------------------------------------
do
	Say("-- socle : AnimationGroup")
	local function FakeRegion()
		local region = { shown = true, alpha = 1 }
		function region:IsShown() return self.shown end
		function region:Hide() self.shown = false end
		function region:SetAlpha(a) self.alpha = a end
		function region:CreateAnimationGroup()
			local g = { anims = {}, plays = 0, playing = false, scripts = {} }
			function g:SetLooping(v) self.looping = v end
			function g:CreateAnimation(kind)
				local a = { kind = kind }
				function a:SetFromAlpha(v) self.from = v end
				function a:SetToAlpha(v) self.to = v end
				function a:SetDuration(v) self.duration = v end
				function a:SetSmoothing(v) self.smoothing = v end
				if kind == "Scale" then
					function a:SetScaleFrom(x, y) self.scaleFrom = { x, y } end
					function a:SetScaleTo(x, y) self.scaleTo = { x, y } end
				end
				self.anims[#self.anims + 1] = a
				return a
			end
			function g:Play() self.plays = self.plays + 1; self.playing = true end
			function g:Stop() self.playing = false end
			function g:IsPlaying() return self.playing end
			function g:SetScript(k, fn) self.scripts[k] = fn end
			return g
		end
		return region
	end
	local r = FakeRegion()
	Want("BOUNCE, Alpha adouci, Scale", Theme.PulseOn(r, true, { from = 1, to = 0.45, period = Theme.PULSE.alert, scale = 1.3 })
		and r.pulse.looping == "BOUNCE" and r.pulse.anims[1].smoothing == "IN_OUT" and r.pulse.anims[1].to == 0.45
		and r.pulse.anims[2].scaleTo[1] == 1.3)
	Theme.PulseOn(r, true)
	Want("pas relancée", r.pulse.plays == 1 and r.pulsing)
	Theme.PulseOn(r, false)
	Want("arrêtée", r.pulse.playing == false and not r.pulsing)
	Want("sans SetLooping : statique", Theme.PulseOn(CreateFrame("Frame", nil, UIParent):CreateTexture(), true) == false)
	Verdict("[SOC] pulsation : groupe en boucle joué une fois, arrêt, client sans SetLooping statique")

	local f = FakeRegion()
	local done = 0
	Want("lancé", Theme.FadeOut(f, 0.2, function() done = done + 1 end) and f.fadeOut.playing and f.shown)
	f.fadeOut.scripts.OnFinished()
	Want("fin : caché, rappel", not f.shown and done == 1)
	f.shown = true
	Theme.FadeOut(f, 0.2)
	f.fadeIn = { Stop = function() end, Play = function() end }
	Theme.FadeIn(f)
	f.fadeOut.scripts.OnFinished()
	Want("FadeIn pendant le fondu : reste affiché", f.shown == true)
	local bare = CreateFrame("Frame", nil, UIParent)
	bare:Show()
	local hidden = 0
	Theme.FadeOut(bare, 0.2, function() hidden = hidden + 1 end)
	Want("sans API : caché tout de suite", not bare:IsShown() and hidden == 1)
	Verdict("[SOC] fondu de sortie : caché à la fin avec rappel, annulé par FadeIn, immédiat sans API")
end

-- 6. Socle chargé une fois, coordination ----------------------------------------------------------------
do
	Say("-- socle : fabriques partagées")
	local registry = rawget(_G, "ReadyToQuestSocle")
	Want("empreinte écrite par l'outil", type(NS.SOCLE_ID) == "string" and #NS.SOCLE_ID == 8 and NS.SOCLE_ID == QNS.SOCLE_ID
		and NS.SOCLE_ID ~= "00000000")
	Want("QC reprend les fabriques de R2Q", QNS.socleShared == true and NS.socleShared == nil)
	Want("registre : fabrique de Theme", type(registry) == "table" and type(registry["Theme@" .. NS.SOCLE_ID]) == "function")
	Want("données partagées", NS.HUBS == QNS.HUBS and NS.PLACE_DATA == QNS.PLACE_DATA and NS.DUNGEONS == QNS.DUNGEONS
		and next(NS.HUBS) ~= nil)
	Verdict("[SOC] socle partagé : même empreinte, fabriques reprises par QC, données en lecture seule communes")
	ResetWorld()
	NS:DB().diagProbe = 1
	Want("Theme et chaînes", NS.Theme ~= QNS.Theme and NS.L ~= QNS.L and tostring(NS.L.TAG):find("Ready") ~= nil
		and tostring(QNS.L.TAG):find("Quest") ~= nil)
	Want("polices et logo", NS.Theme.F_BODY == "Ready2QuestFontBody" and QNS.Theme.F_BODY == "QuestCompanionFontBody"
		and QNS.Theme.LOGO:find("Interface\\AddOns\\QuestCompanion\\", 1, true) == 1)
	Want("sauvegardes", QNS:DB().diagProbe == nil)
	NS:DB().diagProbe = nil
	Verdict("[SOC] chacun son Theme, ses chaînes, ses polices, son logo, sa sauvegarde")
	-- coordination
	local Shared = NS.Shared
	Want("même table", Shared == QNS.Shared and Shared.Has("Ready2Quest") ~= nil and Shared.Has("QuestCompanion") ~= nil)
	Want("chacun voit l'autre", NS.OtherAddon().id == "QuestCompanion" and QNS.OtherAddon().id == "Ready2Quest")
	local before = Shared.Owner("aggro")
	Shared.Claim("aggro", "Ready2Quest")
	Want("aggro tenue par R2Q : QC se tait", Shared.Defers("aggro", "QuestCompanion") and not Shared.Defers("aggro", "Ready2Quest"))
	Shared.Claim("aggro", "Ready2Quest", false)
	Want("rendue : personne ne se tait", not Shared.Defers("aggro", "QuestCompanion") and Shared.Owner("aggro") == nil)
	Shared.Claim("aggro", before, before ~= nil)
	Verdict("[SOC] ns.Shared : une table pour les deux, sujet tenu par l'un, l'autre se tait")
	Check("[SOC] diag : socle propre (R2Q) / partagé (QC), avec l'empreinte",
		NS:SocleDiagLine():find(NS.L.DIAG_SOCLE_OWN, 1, true) ~= nil
		and QNS:SocleDiagLine():find(QNS.L.DIAG_SOCLE_SHARED, 1, true) ~= nil and NS:SocleDiagLine():find(NS.SOCLE_ID, 1, true) ~= nil)
	-- un addon seul (registre vide) : sa propre copie, rien de partagé
	local saved = registry
	_G.ReadyToQuestSocle = nil
	local solo = { APP = { id = "Solo", version = "0", slash = {}, coreFiles = {} } }
	local savedPrint = _G.print
	_G.print = function() end
	local ok, err = pcall(function()
		for _, file in ipairs({ "Base", "Strings", "Compat", "Hubs", "DungeonData", "Places", "Theme" }) do
			assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/" .. file .. ".lua"))("Solo", solo)
		end
	end)
	_G.print = savedPrint
	Check("[SOC] seul : chargé sans erreur, socle propre", ok and solo.socleShared == nil and type(solo.Theme) == "table"
		and solo.Theme ~= NS.Theme and solo.HUBS ~= NS.HUBS and solo.Theme.F_BODY == "SoloFontBody", tostring(err))
	-- empreintes différentes : pas de partage
	_G.ReadyToQuestSocle = { ["Theme@ffffffff"] = function() error("pas la bonne empreinte") end }
	local solo2 = { APP = { id = "Solo2", version = "0", slash = {}, coreFiles = {} } }
	_G.print = function() end
	ok, err = pcall(function()
		for _, file in ipairs({ "Base", "Strings", "Compat", "Theme" }) do
			assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/" .. file .. ".lua"))("Solo2", solo2)
		end
	end)
	_G.print = savedPrint
	Check("[SOC] empreinte différente : copie locale", ok and solo2.socleShared == nil and type(solo2.Theme) == "table", tostring(err))
	_G.ReadyToQuestSocle = saved
	if _G.SlashCmdList then _G.SlashCmdList.SOLO = nil end
end

-- 7. Pluriels et textes du Check ----------------------------------------------------------------------
do
	Say("-- socle : pluriels")
	local L = NS.L
	Want("FR : 0 et 1 au singulier", NS:FP("CHK_BAGS_DETAIL", 0) == "0 emplacement libre"
		and NS:FP("CHK_BAGS_DETAIL", 1) == "1 emplacement libre" and NS:FP("CHK_BAGS_DETAIL", 7) == "7 emplacements libres")
	Want("zéro propre", NS:FP("CHK_VIVRES_DETAIL", 0) == L.CHK_VIVRES_DETAIL_ZERO)
	Want("sans variante : la clé", NS:FP("CHK_REST_DETAIL", 12) == NS:F("CHK_REST_DETAIL", 12))
	local french = NS.STRINGS_FRENCH
	NS.STRINGS_FRENCH = false
	Want("EN : 0 au pluriel", NS:FP("CHK_GRAY_DETAIL", 0) == NS:F("CHK_GRAY_DETAIL_MANY", 0)
		and NS:FP("CHK_GRAY_DETAIL", 1) == NS:F("CHK_GRAY_DETAIL_ONE", 1))
	NS.STRINGS_FRENCH = french
	Verdict("[SOC] pluriels : règle française, règle anglaise, zéro propre, repli sur la clé")
	local bad = {}
	for key, text in pairs(L) do
		if type(key) == "string" and key:find("^CHK_") and type(text) == "string" and (text:find("(s)", 1, true) or text:find("->", 1, true)) then
			bad[#bad + 1] = key
		end
		if type(key) == "string" and key:find("_ONE$") and L[key:gsub("_ONE$", "_MANY")] == key:gsub("_ONE$", "_MANY") then
			bad[#bad + 1] = key .. " sans _MANY"
		end
	end
	-- 1.32.2 : flèche toujours en ASCII (glyphe absent de la police en jeu)
	Check("[SOC] lignes du Check : ni « (s) » ni « -> », chaque _ONE a son _MANY, flèche ASCII", #bad == 0 and Theme.ARROW == "->",
		table.concat(bad, ", "))
end

-- 8. « Avant le départ » hiérarchisé (R2Q 1.32.0) -----------------------------------------------------------
do
	Say("-- R2Q 1.32.0 : Avant le départ")
	ResetWorld()
	Mock.world.durability = { [5] = { 5, 100 } }
	NS.window = nil
	NS:RunChecklist("manual")
	local w = NS.window
	local shown = {}
	for i = 1, w.visibleRows do shown[#shown + 1] = w.rows[i].name.text end
	local last = w.rows[w.visibleRows]
	Check("[R132] points en ordre repliés en bas : « N points en ordre », losange au trait, la fenêtre suit", last.result
		and last.result.fold and last.name.text:find("en ordre", 1, true) ~= nil and last.result.count >= 4
		and last.status.state == "ok" and w.height == NS:WindowHeight(w.visibleRows), table.concat(shown, ", "))
	local foldedRows = w.visibleRows
	last:Click()
	Want("dépliée et mémorisée, « Masquer » en bas", NS:DB().diagFoldOk == false and w.visibleRows > foldedRows
		and w.rows[w.visibleRows].name.text == NS.L.CHK_OK_UNFOLD)
	local okRow
	for i = 1, w.visibleRows do local r = w.rows[i].result; if r and r.ok and not r.disabled then okRow = w.rows[i]; break end end
	Want("en ordre : MUTED_LIGHT ; manque : TEXT", okRow and Same(okRow.name.textColor, Theme.MUTED_LIGHT)
		and Same(w.rows[1].name.textColor, Theme.TEXT))
	w.rows[w.visibleRows]:Click()
	Want("« Masquer » : replié", NS:DB().diagFoldOk == true and w.visibleRows == foldedRows)
	Verdict("[R132] clic : déplié (en ordre en retrait), mémorisé, « Masquer » replie")
	local list = NS:DisplayOrder({
		{ id = "durability", label = "Durabilité", ok = true, detail = "équipement sain", weight = 15 },
		{ id = "repair", label = "Réparation", ok = true, detail = "rien à réparer", weight = 10 },
		{ id = "bags", label = "Sacs", ok = false, detail = "1 emplacement libre", weight = 20 },
	})
	Want("durabilité + réparation OK : une ligne", #list == 2 and list[2].shownDetail == "équipement sain · rien à réparer")
	list = NS:DisplayOrder({
		{ id = "durability", label = "Durabilité", ok = true, detail = "équipement sain", weight = 15 },
		{ id = "repair", label = "Réparation", ok = false, detail = "or insuffisant", weight = 10 },
	})
	Want("réparation en échec : deux lignes", #list == 2 and list[1].id == "repair" and list[2].shownDetail == nil)
	list = NS:DisplayOrder({ { id = "rest", info = true, ok = false, detail = "x", weight = 0 }, { id = "a", ok = true },
		{ id = "b", ok = true }, { id = "c", ok = true }, { id = "d", ok = true } }, true)
	Want("repos en échec : avec les manques", list[1].id == "rest" and list[2].fold and #list == 2)
	Verdict("[R132] ordre d'affichage : durabilité et réparation réunies si OK, repos avec les manques")
	ResetWorld()
	Mock.world.rested = nil
	NS:RunChecklist("manual")
	Check("[R132] sans repos (GetXPExhaustion nil) : « aucun repos d'avance »", Result("rest")
		and Result("rest").detail == NS.L.CHK_REST_NONE, Result("rest") and Result("rest").detail)
	NS.window:Hide()
	ResetWorld()
end

-- 9. Couleurs du texte déclarées une fois, messages traduits (fiche 28) --------------------------------------
do
	Say("-- fiche 28 : couleurs et textes en dur")
	Check("[F28] ns.TC : alias Theme.T_*, le même dans QuestCompanion", NS.TC and NS.TC.GREY == Theme.T_GREY and NS.TC.RED == Theme.T_RED
		and NS.TC.GOLD == Theme.T_GOLD and NS.TC.BLUE == Theme.T_BLUE and QNS.TC and QNS.TC.GREY == NS.TC.GREY)
	-- Theme.lua et Compat.lua sont en liste blanche de code_hygiene : on les garde ici
	local CLEAN = {
		"Ready2Quest/Libs/Socle/Strings.lua", "Ready2Quest/Libs/Socle/Commands.lua", "Ready2Quest/Libs/Socle/Compat.lua",
		"Ready2Quest/Libs/Socle/Theme.lua", "Ready2Quest/Locales.lua", "Ready2Quest/Core.lua", "Ready2Quest/Reagents.lua",
		"Ready2Quest/OptionPages.lua", "QuestCompanion/Locales.lua", "QuestCompanion/Tooltips.lua", "QuestCompanion/GuildFeats.lua",
		"QuestCompanion/JournalCompletion.lua",
	}
	local dirty = {}
	for _, path in ipairs(CLEAN) do
		for line in (ReadFile(path) or ""):gmatch("[^\n]+") do
			local code = line:gsub("%-%-.*$", "")
			if code:find("|cff%x%x%x%x%x%x") then dirty[#dirty + 1] = path .. " : " .. line:gsub("^%s+", "") end
		end
	end
	Check("[F28] aucun |cff en dur hors Base.lua et Config.lua", #dirty == 0, table.concat(dirty, " / "))
	local KEYS = { "MSG_DIAG_MODULES", "MSG_DIAG_MISSING", "MSG_DIAG_ERROR", "MSG_DIAG_WHERE", "MSG_DIAG_UNSUPPORTED",
		"MSG_CLIENT_MODERN", "MSG_CLIENT_UNKNOWN", "CHK_REAGENTS_HOWTO", "REAGENT_CRAFTABLE", "REAGENT_BLOCKED",
		"REAGENT_MISSING_ROW", "PACE_ROW" }
	-- deux déclarations dans le fichier (frFR puis enUS)
	local function Twice(src, key)
		local first = src:find("\n%s*" .. key .. "%s*=")
		return first ~= nil and src:find("\n%s*" .. key .. "%s*=", first + 1) ~= nil
	end
	local all = (ReadFile("Ready2Quest/Libs/Socle/Strings.lua") or "") .. (ReadFile("Ready2Quest/Locales.lua") or "")
		.. (ReadFile("Ready2Quest/LevelPace.lua") or "")
	local best = ReadFile("QuestCompanion/Bestiary.lua") or ""
	local missing = {}
	for _, key in ipairs(KEYS) do if not Twice(all, key) then missing[#missing + 1] = key end end
	for _, key in ipairs({ "BESTIARY_DIAG", "BESTIARY_DIAG_CLOG" }) do if not Twice(best, key) then missing[#missing + 1] = key end end
	Check("[F28] messages du diagnostic et des réactifs : FR et EN ; client français en français (espace avant « : »)", #missing == 0
		and NS:F("MSG_DIAG_MODULES", "", 3, 4):find("chargés", 1, true) ~= nil and NS:F("PACE_ROW", "Repos", "x") == "Repos : x",
		table.concat(missing, ", "))
	-- messages de démarrage (avant Strings.lua) : table bilingue de Base.lua
	local base = ReadFile("Ready2Quest/Libs/Socle/Base.lua") or ""
	local cfg = ReadFile("QuestCompanion/Config.lua") or ""
	Check("[F28] démarrage : table bilingue, choisie selon le client ; ancien Ready2Quest prévenu en anglais",
		base:find('LOADED = "%%s — files loaded"') ~= nil and base:find('LOADED = "%%s — fichiers chargés"') ~= nil
		and NS.BOOT_STRINGS and NS.BOOT_STRINGS.LOADED:find("chargés", 1, true) ~= nil
		and cfg:find("already contains the companion", 1, true) ~= nil)
end

-- 10. Horloge unique par addon (fiche 25) -----------------------------------------------------------------
do
	Say("-- fiche 25 : horloge unique")
	local clock = NS.clockFrame
	local function Tick(seconds, frames)
		for _ = 1, frames or 1 do
			Mock.now = Mock.now + seconds
			clock.scripts.OnUpdate(clock, seconds)
		end
	end
	local runs, steps = 0, {}
	NS.Every("test:every", 0.5, function(step) runs = runs + 1; steps[#steps + 1] = step end)
	Tick(1 / 60, 125)   -- un peu plus de 2 s (somme de flottants)
	Check("[CLK] une horloge par addon ; Every 0,5 s : 4 passages en 2 s, temps écoulé reçu", clock ~= nil and QNS.clockFrame ~= nil
		and QNS.clockFrame ~= clock and runs == 4 and math.abs((steps[2] or 0) - 0.5) < 0.02, runs .. " / " .. tostring(steps[2]))
	Tick(10)
	local afterGap = runs
	NS.Cancel("test:every")
	Tick(1, 3)
	Check("[CLK] grand écart (écran de chargement) : un seul passage ; Cancel : plus rien", afterGap == 5 and runs == 5
		and math.abs(steps[5] - 10) < 0.6, runs)

	local soon, at = 0, nil
	local start = Mock.now
	NS.Soon("test:soon", 1, function() soon = soon + 1; at = Mock.now - start end)
	NS.Soon("test:soon", 0.2)
	NS.Soon("test:soon", 0.8)
	Tick(0.05, 40)
	local n, keys = NS.ClockJobs()
	local listed = false
	for i = 1, n do if keys[i] == "test:soon" then listed = true end end
	Check("[CLK] Soon : un passage, à la plus proche échéance, puis retirée", soon == 1 and at and math.abs(at - 0.2) < 0.06
		and not listed, at)

	local untilRuns, beats = 0, 0
	NS.Every("test:until", 0, function() untilRuns = untilRuns + 1; return untilRuns < 3 end)
	Tick(1 / 60, 10)
	NS.Every("test:adaptive", 1, function() beats = beats + 1; return beats < 4 and 0 or 1 end)
	Tick(1 / 60, 70)
	NS.Cancel("test:adaptive")
	Check("[CLK] fn rend false : se retire ; rend 0 : chaque image, puis repos", untilRuns == 3 and beats == 4,
		untilRuns .. " / " .. beats)

	local after, errors = 0, #NS.errors
	NS.Every("test:boom", 0, function() error("boum") end)
	NS.Every("test:after", 0, function() after = after + 1 end)
	Tick(1 / 60, 5)
	local noted = 0
	for i = errors + 1, #NS.errors do if NS.errors[i].where == "clock:test:boom" then noted = noted + 1 end end
	Check("[CLK] erreur : notée une fois (clock:clé), les autres tâches tournent", noted == 1 and after == 5, noted .. "/" .. after)
	NS.Cancel("test:boom")
	NS.Cancel("test:after")
	for i = #NS.errors, errors + 1, -1 do table.remove(NS.errors, i) end

	-- coût : une seule fonction Lua par image et rien d'alloué, sur une horloge neuve
	local chunk = loadfile(ROOT .. "/Ready2Quest/Libs/Socle/Base.lua")
	local fake = { APP = { id = "ClockTest", version = "0", slash = {}, coreFiles = {} } }
	local loaded = chunk and pcall(chunk, "ClockTest", fake)
	local own = loaded and fake.Every and fake.Every("idle", 3600, function() end) and fake.clockFrame
	if own then
		local calls = 0
		local function Hook() calls = calls + 1 end
		for _ = 1, 20 do own.scripts.OnUpdate(own, 1 / 60) end
		collectgarbage("collect"); collectgarbage("stop")
		local before = collectgarbage("count")
		debug.sethook(Hook, "c")
		for _ = 1, 600 do own.scripts.OnUpdate(own, 1 / 60) end
		debug.sethook()
		local kb = collectgarbage("count") - before
		collectgarbage("restart")
		fake.Cancel("idle")
		Check("[CLK] au repos : un appel par image, rien d'alloué ; plus rien de posé : horloge cachée",
			calls - 1 <= 600 and kb < 0.5 and own.shown == false,   -- (- 1 : debug.sethook)
			string.format("%d appels, %.2f Ko", calls - 1, kb))
	else
		Check("[CLK] horloge neuve chargée", false)
	end

	-- les anciennes boucles permanentes passent par l'horloge
	local function Has(ns, key)
		local count, list = ns.ClockJobs()
		for i = 1, count do if list[i] == key then return true end end
		return false
	end
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)   -- pose la sonde du portrait
	local missing = {}
	for _, key in ipairs({ "core:exit", "portrait", "camp", "death", "aggro" }) do
		if not Has(NS, key) then missing[#missing + 1] = "R2Q " .. key end
	end
	for _, key in ipairs({ "companion", "companion:aggro", "travel", "advice", "group", "shiny", "capture", "effects",
		"daily", "notify", "trainer", "feats:minute" }) do
		if not Has(QNS, key) then missing[#missing + 1] = "QC " .. key end
	end
	for _, name in ipairs({ "eventFrame", "campEventFrame", "aggroEventFrame", "deathEvents", "spellRanksEventFrame" }) do
		local f = NS[name]
		if f and f.scripts and f.scripts.OnUpdate then missing[#missing + 1] = "OnUpdate R2Q " .. name end
	end
	for _, name in ipairs({ "adviceEventFrame", "groupEventFrame", "dailyEventFrame", "journalEventFrame",
		"notifyEventFrame", "trainerEventFrame", "featEventFrame" }) do
		local f = QNS[name]
		if f and f.scripts and f.scripts.OnUpdate then missing[#missing + 1] = "OnUpdate QC " .. name end
	end
	Check("[CLK] vérifications espacées : tâches de l'horloge, plus d'OnUpdate sur les cadres d'événements", #missing == 0,
		table.concat(missing, ", "))

	-- échéance posée à la demande : sorts (R2Q)
	local checks, saved = 0, NS.SpellRanksCheck
	NS.SpellRanksCheck = function() checks = checks + 1 end
	NS.spellRanksDueAt = nil
	NS.spellRanksEventFrame.script(NS.spellRanksEventFrame, "LEARNED_SPELL_IN_TAB")
	Tick(0.25, 3)
	local early = checks
	Tick(0.25, 2)
	Check("[CLK] sorts : rien avant l'échéance, vérifiés une fois à l'échéance", early == 0 and checks == 1
		and NS.spellRanksDueAt == nil, early .. " / " .. checks)
	NS.SpellRanksCheck = saved
end
