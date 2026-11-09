-- Socle 2.11.0 / Ready2Quest 1.32.0 : jeton de rareté, contraste du socle,
-- pictos et roue du client, états des contrôles, pulsations, socle chargé une
-- fois (fabriques partagées) et coordination entre les deux addons, « Avant le
-- départ » hiérarchisé.
local Check, Say, NS, QNS, Mock, ResetWorld, Result = T.Check, T.Say, T.NS, T.QNS, T.Mock, T.ResetWorld, T.Result
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.002 then return false end end
	return true
end
local DARK = { "WINDOW", "NAV", "ROW", "ROW_ALT", "FIELD" }

-- 1. Theme.RANK (n° 21) --------------------------------------------------------------------------
do
	Say("-- socle 2.11.0 : jeton de rareté")
	local bad = {}
	for key, color in pairs(Theme.RANK) do
		for _, bg in ipairs(DARK) do
			local r = Theme.Contrast(color, Theme[bg])
			if r < 4.5 then bad[#bad + 1] = string.format("%s/%s=%.2f", key, bg, r) end
		end
	end
	Check("[S211] Theme.RANK : 4,5:1 sur WINDOW, NAV, ROW, ROW_ALT, FIELD", #bad == 0, table.concat(bad, ", "))
	Check("[S211] mesures de la fiche : élite 6,33 / rare 6,31 sur ROW", math.abs(Theme.Contrast(Theme.RANK.elite, Theme.ROW) - 6.33) < 0.05
		and math.abs(Theme.Contrast(Theme.RANK.rare, Theme.ROW) - 6.31) < 0.05)
	Check("[S211] classification -> clé", Theme.RankKey("rareelite") == "rare" and Theme.RankKey("worldboss") == "boss"
		and Theme.RankKey("minus") == "trivial" and Theme.RankKey(nil) == "normal" and Theme.RankKey("inconnu") == "normal")
	local missing = {}
	for class in pairs(Theme.RANK_KEYS) do if type(Theme.RankColor(class)) ~= "table" then missing[#missing + 1] = class end end
	Check("[S211] chaque classification a sa couleur", #missing == 0, table.concat(missing, ","))
	Check("[S211] brillante : l'or clair", Theme.RankColor("elite", true) == Theme.GOLD_LIGHT)
	Check("[S211] élite : |cff669ef2", Theme.Hex(Theme.RANK.elite) == "|cff669ef2", Theme.Hex(Theme.RANK.elite))
	Check("[S211] même jeton dans la copie de QuestCompanion", Same(QNS.Theme.RANK.elite, Theme.RANK.elite)
		and QNS.Theme.RankKey("rareelite") == "rare")
end

-- 2. Contraste du socle (n° 7) ---------------------------------------------------------------------
do
	Say("-- socle 2.11.0 : contraste des paires réelles (socle_contrast)")
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
	Check("[SC] paires texte/fond du socle : 4,5:1", #bad == 0, table.concat(bad, ", "))
	bad = {}
	for name, s in pairs(Theme.BUTTON_STYLES) do
		local under = (s.bgAlpha or 0) < 1 and { BG.WINDOW, BG.NAV, BG.ROW } or { s.bg }
		for _, base in ipairs(under) do
			local rest = (s.bgAlpha or 0) < 1 and Over(base, s.bg, s.bgAlpha or 0) or s.bg
			if Theme.Contrast(s.text, rest) < 4.5 then bad[#bad + 1] = name .. " repos" end
			local hover = s.hoverBg or (s.hoverAlpha and Over(base, s.bg, s.hoverAlpha)) or rest
			if Theme.Contrast(s.text, hover) < 4.5 then bad[#bad + 1] = name .. " survol" end
		end
	end
	for name, st in pairs(Theme.BUTTON_STYLES) do
		if st.filled and Theme.Contrast(st.text, Over(st.bg, Theme.INK, Theme.PRESS_SHADE)) < 4.5 then bad[#bad + 1] = name .. " enfoncé" end
	end
	Check("[SC] chaque style de bouton : 4,5:1 au repos, au survol, enfoncé", #bad == 0, table.concat(bad, ", "))
	Check("[SC] bouton bleu : 5,67:1 au repos, plus de blanc", math.abs(Theme.Contrast(Theme.INK, Theme.BLUE) - 5.67) < 0.05
		and Theme.BUTTON_STYLES.adventure.text == Theme.INK)
	Check("[SC] formule : noir/blanc = 21, luminance acceptée", math.abs(Theme.Contrast({ 0, 0, 0 }, { 1, 1, 1 }) - 21) < 0.01
		and math.abs(Theme.Contrast({ 1, 1, 1 }, 0) - 21) < 0.01)
	Check("[SC] même formule que le carnet", math.abs(Theme.Contrast(Theme.GOLD, Theme.ROW)
		- QNS.AzerothContrast(Theme.GOLD, QNS.AzerothLuminance(Theme.ROW))) < 0.001)
	Check("[SC] MUTED éclairci : #91969e, 5,49:1 sur ROW_ALT", Theme.T_GREY == "|cff91969e"
		and Theme.Contrast(Theme.MUTED, Theme.ROW_ALT) >= 5.4)
end

-- 3. États des contrôles (n° 23) --------------------------------------------------------------------
do
	Say("-- socle 2.11.0 : survol, appui, désactivé")
	local parent = CreateFrame("Frame", nil, UIParent)
	local card = Theme.CreateSettingCard(parent, 300, 38, "Button")
	Check("[S211] carte : voile à HOVER_ALPHA (6 %), caché", card.hover.vertex[4] == Theme.HOVER_ALPHA and not card.hover:IsShown()
		and not card.hover.edge.top:IsShown())
	card.scripts.OnEnter(card)
	Check("[S211] carte survolée : voile et filet EDGE", card.hover:IsShown() and card.hover.edge.top:IsShown()
		and Same(card.hover.edge.left.vertex, Theme.EDGE))
	card.scripts.OnLeave(card)
	Check("[S211] carte quittée : voile et filet cachés", not card.hover:IsShown() and not card.hover.edge.right:IsShown())
	local row = Theme.CreateListRow(parent, 300, 26, { kind = "Button" })
	Check("[S211] ligne : même voile", row.hover.vertex[4] == Theme.HOVER_ALPHA and row.hover.edge ~= nil)

	local btn = Theme.CreateButton(parent, 120, 28, "Partir", nil, "adventure")
	btn.scripts.OnMouseDown(btn, "LeftButton")
	local pressed = Theme.Over(Theme.BLUE, Theme.INK, Theme.PRESS_SHADE)
	Check("[S211] bouton plein enfoncé : libellé (1, -1), fond assombri", btn.text.lastPoint.x == 1 and btn.text.lastPoint.y == -1
		and Same(btn.bg.vertex, pressed))
	btn.scripts.OnMouseUp(btn)
	Check("[S211] relâché hors du bouton : repos", btn.text.lastPoint.x == 0 and Same(btn.bg.vertex, Theme.BLUE))
	local outline = Theme.CreateButton(parent, 120, 28, "Réinitialiser", nil, "outline")
	outline.scripts.OnMouseDown(outline, "LeftButton")
	Check("[S211] bouton au trait enfoncé : contour ambre sombre", Same(outline.border.top.vertex, Theme.GOLD_SOFT))
	outline.scripts.OnMouseDown(outline, "RightButton")
	outline.scripts.OnMouseUp(outline)
	-- désactivé : IsEnabled faux
	btn.IsEnabled = function() return false end
	btn.disabledTip = "Pas maintenant"
	Theme.ButtonRest(btn)
	Check("[S211] désactivé : estompé, texte MUTED, fond CONTROL", btn.alpha == Theme.DIM_ALPHA
		and Same(btn.text.textColor, Theme.MUTED) and Same(btn.bg.vertex, Theme.CONTROL) and btn.disabledLook == true)
	btn.scripts.OnEnter(btn)
	Check("[S211] désactivé : pas de survol", Same(btn.bg.vertex, Theme.CONTROL))
	btn.scripts.OnMouseDown(btn, "LeftButton")
	Check("[S211] désactivé : pas d'appui", btn.text.lastPoint.x == 0)
	btn.IsEnabled = function() return true end
	Theme.ButtonRest(btn)
	Check("[S211] réactivé : style d'origine", btn.alpha == 1 and Same(btn.text.textColor, Theme.INK) and Same(btn.bg.vertex, Theme.BLUE))
	-- Disable / Enable de l'instance suivent
	local wrapped = 0
	local fake = Theme.CreateButton(parent, 80, 22, "x")
	local enabled = true
	fake.IsEnabled = function() return enabled end
	fake.Disable = function(self) enabled = false end
	Theme.ButtonRest(fake)
	Check("[S211] bouton créé : sans erreur ni effet sans IsEnabled", fake.alpha == 1 and wrapped == 0)
	parent:Hide()

	-- module coupé : cartes estompées, bandeau « Rallumer » (R2Q, page Déclencheurs)
	ResetWorld()
	local frame = NS:EnsureOptions()
	NS:SelectOptionsPage("trigger")
	local key = NS:OptionsPageModuleKey("trigger")
	Check("[S211] page fille : clé du module de sa page parente", key == "departureEnabled", tostring(key))
	NS:ToggleModuleKey(key)
	local dimmed, total = 0, 0
	for _, c in ipairs(frame.rows) do
		if c.pageId == "trigger" then total = total + 1; if c.alpha == Theme.DIM_ALPHA and c.dimmed then dimmed = dimmed + 1 end end
	end
	Check("[S211] module coupé : ses cartes estompées", total > 0 and dimmed == total, dimmed .. "/" .. total)
	Check("[S211] module coupé : bandeau et « Rallumer »", frame.offBanner:IsShown() and frame.header.subtitle.text == NS.L.OPT_PAGE_OFF
		and frame.offBanner:GetText() == NS.L.OPT_PAGE_OFF_ON)
	frame.offBanner:Click()
	local back = 0
	for _, c in ipairs(frame.rows) do if c.pageId == "trigger" and c.alpha == 1 then back = back + 1 end end
	Check("[S211] « Rallumer » : module actif, cartes pleines, bandeau caché", NS:DB()[key] ~= false and back == total
		and not frame.offBanner:IsShown() and frame.header.subtitle.text ~= NS.L.OPT_PAGE_OFF)
	local moduleCards = 0
	for _, c in ipairs(frame.rows) do if c.isModule and (c.alpha or 1) == 1 then moduleCards = moduleCards + 1 end end
	Check("[S211] cartes de module jamais estompées", moduleCards > 0)
	frame:Hide()
end

-- 4. Pictos et roue du client (n° 12, 22, B5) ---------------------------------------------------------
do
	Say("-- socle 2.11.0 : atlas du client, repli sur nos fichiers")
	local parent = CreateFrame("Frame", nil, UIParent)
	Mock.InstallAtlas(nil)
	local d = Theme.CreateDiamond(parent, 10, false)
	Check("[S211] sans C_Texture : losange du socle", d.texture == Theme.DIAMOND and d.clientSource == "fallback")
	Mock.InstallAtlas(true)
	d = Theme.CreateDiamond(parent, 10, false)
	local line = Theme.CreateDiamond(parent, 10, true)
	Check("[S211] atlas : losange plein « activities-complete-diamond », désaturé pour la teinte",
		d.atlas == "activities-complete-diamond" and d.clientSource == "activities-complete-diamond")
	Check("[S211] atlas : losange au trait « activities-incomplete-diamond »", line.atlas == "activities-incomplete-diamond")
	Mock.InstallAtlas({ ["activities-complete-diamond"] = true })
	d = Theme.CreateDiamond(parent, 10, false)
	Check("[S211] premier atlas absent : « genericwidgetbar-marker-diamond »", d.atlas == "genericwidgetbar-marker-diamond")
	Mock.InstallAtlas(true)
	local gear = Theme.CreateGearButton(parent, 22, function() end, "Réglages")
	Check("[S211] roue : atlas « questlog-icon-setting », 16 px, sans carré", gear.icon.atlas == "questlog-icon-setting"
		and gear.icon.width == 16 and not gear.border.top:IsShown() and gear.gearAtlas == "questlog-icon-setting")
	Check("[S211] roue au repos : grise estompée", Same(gear.icon.vertex, Theme.GEAR.rest) and gear.icon.alpha == Theme.GEAR.rest[4])
	gear.scripts.OnEnter(gear)
	Check("[S211] roue au survol : plus claire", gear.gearHot == true and gear.icon.alpha == 1)
	gear.scripts.OnLeave(gear)
	local toggle = Theme.CreateToggle(parent)
	Check("[S211] interrupteur : case du client « checkbox-minimal », carrée", toggle.checkbox and toggle.box.atlas == "checkbox-minimal"
		and toggle.width == Theme.CHECKBOX_SIZE and not toggle.track:IsShown() and not toggle.check:IsShown())
	toggle:SetChecked(true)
	Check("[S211] case cochée : la coche du client", toggle.check:IsShown() and toggle.check.atlas == "checkmark-minimal"
		and toggle:GetChecked())
	toggle:SetPartial()
	Check("[S211] case partielle : « common-checkbox-partial »", toggle.partialMark:IsShown() and not toggle.check:IsShown()
		and toggle.partialMark.atlas == "common-checkbox-partial")
	local power = Theme.CreatePowerButton(parent, 16)
	Theme.SetPowerState(power, true)
	Check("[S211] interrupteur de module : case du client, cochée si actif", power.checkbox and power.check:IsShown()
		and not power.icon:IsShown())
	local dd = Theme.CreateDropdown and Theme.CreateDropdown(parent, 160, function() end, {})
	Check("[S211] liste : chevron du client", dd == nil or dd.chevron.atlas == "friendslist-categorybutton-arrow-down")
	local pager = Theme.CreatePager(parent, function() end)
	Check("[S211] pagination : chevron du client, tourné pour « haut »", pager.up.icon.atlas == "friendslist-categorybutton-arrow-down"
		and pager.up.icon.rotation == math.pi)
	Mock.InstallAtlas(nil)
	gear = Theme.CreateGearButton(parent, 22)
	toggle = Theme.CreateToggle(parent)
	Check("[S211] sans atlas : roue UI-OptionsButton, interrupteur dessiné", gear.icon.texture == "Interface\\Buttons\\UI-OptionsButton"
		and not toggle.checkbox and toggle.width == 32 and toggle.track.mockHidden ~= true,
		tostring(gear.icon.texture) .. " " .. tostring(toggle.checkbox) .. " " .. tostring(toggle.width))
	parent:Hide()
end

-- 5. Pulsations (n° 24) ---------------------------------------------------------------------------
do
	Say("-- socle 2.11.0 : AnimationGroup")
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
	Check("[S211] pulsation : groupe en BOUNCE, Alpha adouci, Scale par SetScaleFrom", Theme.PulseOn(r, true,
		{ from = 1, to = 0.45, period = Theme.PULSE.alert, scale = 1.3 }) and r.pulse.looping == "BOUNCE"
		and r.pulse.anims[1].smoothing == "IN_OUT" and r.pulse.anims[1].to == 0.45 and r.pulse.anims[2].scaleTo[1] == 1.3)
	Theme.PulseOn(r, true)
	Check("[S211] pulsation déjà jouée : pas relancée", r.pulse.plays == 1 and r.pulsing)
	Theme.PulseOn(r, false)
	Check("[S211] pulsation arrêtée", r.pulse.playing == false and not r.pulsing)
	local plain = CreateFrame("Frame", nil, UIParent):CreateTexture()
	Check("[S211] client sans SetLooping : statique, sans erreur", Theme.PulseOn(plain, true) == false)
	local f = FakeRegion()
	local done = 0
	Check("[S211] fondu de sortie lancé", Theme.FadeOut(f, 0.2, function() done = done + 1 end) and f.fadeOut.playing and f.shown)
	f.fadeOut.scripts.OnFinished()
	Check("[S211] fin du fondu : caché, rappel fait", not f.shown and done == 1)
	f.shown = true
	Theme.FadeOut(f, 0.2)
	f.fadeIn = { Stop = function() end, Play = function() end }
	f.CreateAnimationGroup = f.CreateAnimationGroup
	Theme.FadeIn(f)
	f.fadeOut.scripts.OnFinished()
	Check("[S211] FadeIn pendant le fondu : reste affiché", f.shown == true)
	local bare = CreateFrame("Frame", nil, UIParent)
	bare:Show()
	local hidden = 0
	Theme.FadeOut(bare, 0.2, function() hidden = hidden + 1 end)
	Check("[S211] sans API : caché tout de suite", not bare:IsShown() and hidden == 1)
end

-- 6. Socle chargé une fois, coordination (n° 26) -------------------------------------------------------
do
	Say("-- socle 2.11.0 : fabriques partagées")
	Check("[S211] même empreinte, écrite par l'outil", type(NS.SOCLE_ID) == "string" and #NS.SOCLE_ID == 8
		and NS.SOCLE_ID == QNS.SOCLE_ID and NS.SOCLE_ID ~= "00000000")
	Check("[S211] QuestCompanion reprend les fabriques de Ready2Quest", QNS.socleShared == true and NS.socleShared == nil)
	Check("[S211] chacun sa table Theme, ses chaînes", NS.Theme ~= QNS.Theme and NS.L ~= QNS.L
		and tostring(NS.L.TAG):find("Ready") ~= nil and tostring(QNS.L.TAG):find("Quest") ~= nil)
	Check("[S211] chacun ses polices et son logo", NS.Theme.F_BODY == "Ready2QuestFontBody" and QNS.Theme.F_BODY == "QuestCompanionFontBody"
		and QNS.Theme.LOGO:find("Interface\\AddOns\\QuestCompanion\\", 1, true) == 1)
	Check("[S211] données partagées (une seule table)", NS.HUBS == QNS.HUBS and NS.PLACE_DATA == QNS.PLACE_DATA
		and NS.DUNGEONS == QNS.DUNGEONS and next(NS.HUBS) ~= nil)
	local registry = rawget(_G, "ReadyToQuestSocle")
	Check("[S211] registre : fabrique de Theme sous son empreinte", type(registry) == "table"
		and type(registry["Theme@" .. NS.SOCLE_ID]) == "function")
	ResetWorld()
	NS:DB().diagProbe = 1
	Check("[S211] sauvegardes distinctes", QNS:DB().diagProbe == nil)
	NS:DB().diagProbe = nil
	-- coordination
	local Shared = NS.Shared
	Check("[S211] ns.Shared : la même table pour les deux", Shared == QNS.Shared and Shared.Has("Ready2Quest") ~= nil
		and Shared.Has("QuestCompanion") ~= nil)
	Check("[S211] chacun voit l'autre", NS.OtherAddon().id == "QuestCompanion" and QNS.OtherAddon().id == "Ready2Quest")
	local before = Shared.Owner("aggro")
	Shared.Claim("aggro", "Ready2Quest")
	Check("[S211] aggro tenue par R2Q : le compagnon se tait, pas R2Q", Shared.Defers("aggro", "QuestCompanion")
		and not Shared.Defers("aggro", "Ready2Quest"))
	Shared.Claim("aggro", "Ready2Quest", false)
	Check("[S211] aggro rendue : personne ne se tait", not Shared.Defers("aggro", "QuestCompanion") and Shared.Owner("aggro") == nil)
	Shared.Claim("aggro", before, before ~= nil)
	-- diag
	Check("[S211] diag : socle propre (R2Q) / partagé (QC)", NS:SocleDiagLine():find(NS.L.DIAG_SOCLE_OWN, 1, true) ~= nil
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
	Check("[S211] seul : chargé sans erreur, socle propre", ok and solo.socleShared == nil and type(solo.Theme) == "table"
		and solo.Theme ~= NS.Theme and solo.HUBS ~= NS.HUBS and solo.Theme.F_BODY == "SoloFontBody", tostring(err))
	-- empreintes différentes : pas de partage
	local other = {}
	for k, v in pairs(_G.ReadyToQuestSocle or {}) do other[k] = v end
	_G.ReadyToQuestSocle = { ["Theme@ffffffff"] = function() error("pas la bonne empreinte") end }
	local solo2 = { APP = { id = "Solo2", version = "0", slash = {}, coreFiles = {} } }
	_G.print = function() end
	ok, err = pcall(function()
		for _, file in ipairs({ "Base", "Strings", "Compat", "Theme" }) do
			assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/" .. file .. ".lua"))("Solo2", solo2)
		end
	end)
	_G.print = savedPrint
	Check("[S211] empreinte différente : copie locale", ok and solo2.socleShared == nil and type(solo2.Theme) == "table", tostring(err))
	_G.ReadyToQuestSocle = saved
	if _G.SlashCmdList then _G.SlashCmdList.SOLO = nil end
end

-- 7. Pluriels (n° 16, socle) --------------------------------------------------------------------------
do
	Say("-- socle 2.11.0 : pluriels")
	local L = NS.L
	Check("[S211] FR : 0 et 1 au singulier, 2 au pluriel", NS:FP("CHK_BAGS_DETAIL", 0) == "0 emplacement libre"
		and NS:FP("CHK_BAGS_DETAIL", 1) == "1 emplacement libre" and NS:FP("CHK_BAGS_DETAIL", 7) == "7 emplacements libres")
	Check("[S211] zéro propre : « rien à manger ni à boire »", NS:FP("CHK_VIVRES_DETAIL", 0) == L.CHK_VIVRES_DETAIL_ZERO)
	Check("[S211] clé sans variante : repli sur la clé", NS:FP("CHK_REST_DETAIL", 12) == NS:F("CHK_REST_DETAIL", 12))
	local french = NS.STRINGS_FRENCH
	NS.STRINGS_FRENCH = false
	Check("[S211] règle anglaise : 0 au pluriel, 1 au singulier", NS:FP("CHK_GRAY_DETAIL", 0) == NS:F("CHK_GRAY_DETAIL_MANY", 0)
		and NS:FP("CHK_GRAY_DETAIL", 1) == NS:F("CHK_GRAY_DETAIL_ONE", 1))
	NS.STRINGS_FRENCH = french
	-- parité et garde-fou des textes du Check
	local src = NS.STRINGS_SOURCES or {}
	local bad = {}
	for key, text in pairs(L) do
		if type(key) == "string" and key:find("^CHK_") and type(text) == "string" and (text:find("(s)", 1, true) or text:find("->", 1, true)) then
			bad[#bad + 1] = key
		end
		if type(key) == "string" and key:find("_ONE$") and L[key:gsub("_ONE$", "_MANY")] == key:gsub("_ONE$", "_MANY") then
			bad[#bad + 1] = key .. " sans _MANY"
		end
	end
	Check("[S211] lignes du Check : ni « (s) » ni « -> », chaque _ONE a son _MANY", #bad == 0, table.concat(bad, ", "))
	Check("[S211] flèche : « → » si Inter, sinon « -> »", Theme.ARROW == (Theme.fonts.BODY.inter and "→" or "->"))
end

-- 8. « Avant le départ » hiérarchisé (n° 16, R2Q 1.32.0) ----------------------------------------------------
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
	Check("[R132] points en ordre repliés : manques puis une ligne « N points en ordre · Afficher »", last.result and last.result.fold
		and last.name.text:find("en ordre", 1, true) ~= nil and last.result.count >= 4, table.concat(shown, ", "))
	Check("[R132] repli : losange au trait vert, la fenêtre suit", last.status.state == "ok" and w.height == NS:WindowHeight(w.visibleRows))
	local foldedRows = w.visibleRows
	last:Click()
	Check("[R132] clic : dépliée et mémorisée, « Masquer » en bas", NS:DB().diagFoldOk == false and w.visibleRows > foldedRows
		and w.rows[w.visibleRows].name.text == NS.L.CHK_OK_UNFOLD)
	local okRow
	for i = 1, w.visibleRows do local r = w.rows[i].result; if r and r.ok and not r.disabled then okRow = w.rows[i]; break end end
	Check("[R132] point en ordre en retrait : nom MUTED_LIGHT", okRow and Same(okRow.name.textColor, Theme.MUTED_LIGHT))
	Check("[R132] manque : nom en TEXT", Same(w.rows[1].name.textColor, Theme.TEXT))
	w.rows[w.visibleRows]:Click()
	Check("[R132] « Masquer » : replié de nouveau", NS:DB().diagFoldOk == true and w.visibleRows == foldedRows)
	-- durabilité et réparation OK : une seule ligne
	local list = NS:DisplayOrder({
		{ id = "durability", label = "Durabilité", ok = true, detail = "équipement sain", weight = 15 },
		{ id = "repair", label = "Réparation", ok = true, detail = "rien à réparer", weight = 10 },
		{ id = "bags", label = "Sacs", ok = false, detail = "1 emplacement libre", weight = 20 },
	})
	Check("[R132] durabilité + réparation OK : une ligne, détails réunis", #list == 2 and list[2].shownDetail == "équipement sain · rien à réparer")
	list = NS:DisplayOrder({
		{ id = "durability", label = "Durabilité", ok = true, detail = "équipement sain", weight = 15 },
		{ id = "repair", label = "Réparation", ok = false, detail = "or insuffisant", weight = 10 },
	})
	Check("[R132] réparation en échec : deux lignes", #list == 2 and list[1].id == "repair" and list[2].shownDetail == nil)
	list = NS:DisplayOrder({ { id = "rest", info = true, ok = false, detail = "x", weight = 0 }, { id = "a", ok = true },
		{ id = "b", ok = true }, { id = "c", ok = true }, { id = "d", ok = true } }, true)
	Check("[R132] repos en échec : reste avec les manques, puis le repli", list[1].id == "rest" and list[2].fold and #list == 2)
	-- repos : GetXPExhaustion rend nil
	ResetWorld()
	Mock.world.rested = nil
	NS:RunChecklist("manual")
	Check("[R132] sans repos (nil) : « aucun repos d'avance »", Result("rest") and Result("rest").detail == NS.L.CHK_REST_NONE,
		Result("rest") and Result("rest").detail)
	-- module coupé : MUTED_LIGHT, lisible
	Check("[R132] lignes en retrait : MUTED_LIGHT ≥ 4,5:1 sur ROW et ROW_ALT", Theme.Contrast(Theme.MUTED_LIGHT, Theme.ROW) >= 4.5
		and Theme.Contrast(Theme.MUTED_LIGHT, Theme.ROW_ALT) >= 4.5)
	NS.window:Hide()
	ResetWorld()
end
