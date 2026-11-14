-- Contrôles forgés du socle (thème Azeroth, socle 3.2) : boutons en plaque de
-- relief teintée par style (or principal, vert ajouter, rouge retirer, bleu
-- arcane action neutre), petits boutons ([×], icône, roue), case en creux à
-- coche or, interrupteur à piste en creux et curseur arcane, voyant de
-- module, curseur, liste déroulante, recherche, nuancier, barre ; leurs
-- états (survol, appui, désactivé, choisi) ; contrastes mesurés sur la plaque
-- réelle (point le plus clair et le plus sombre sous le libellé) ; Sobre sans
-- rien de plus ; aucune dépendance aux atlas du client.
local Check, Say, NS, QNS, Mock, ResetWorld = T.Check, T.Say, T.NS, T.QNS, T.Mock, T.ResetWorld
local Theme = NS.Theme
local SKIN0 = { NS.Theme.skin, QNS.Theme.skin }

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.002 then return false end end
	return true
end
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
		return cond
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end
local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function SliceColor(slice) return slice and slice.parts and slice.parts.c and slice.parts.c.vertex end
local function SliceShown(slice) return slice and slice.parts.tl:IsShown() and true or false end
-- une région porte-t-elle un atlas du client ? (le thème forgé n'en dépend pas)
local function Atlases(frame)
	local found = {}
	local function Walk(node, depth)
		if type(node) ~= "table" or depth > 3 then return end
		for key, value in pairs(node) do
			if type(value) == "table" and key ~= "mockParent" and key ~= "spec" and key ~= "forge" then
				if value.kind == "Texture" and value.atlas then found[#found + 1] = tostring(key) .. "=" .. value.atlas end
				if value.kind == nil then Walk(value, depth + 1) end
			end
		end
	end
	Walk(frame, 0)
	return found
end

local parent = CreateFrame("Frame", nil, UIParent)
parent:SetSize(600, 400)

do
	Say("-- contrôles forgés : Sobre inchangé")
	Theme.ApplySkin("sobre")
	local s = Steps()
	local b = Theme.CreateButton(parent, 120, 28, "Sobre", nil, "primary")
	s.ok("bouton sans plaque", b.plate == nil and b.forge == nil)
	s.ok("styles ajoutés = contour en Sobre", Theme.BUTTON_STYLES.add == Theme.BUTTON_STYLES.outline
		and Theme.BUTTON_STYLES.danger == Theme.BUTTON_STYLES.outline and Theme.BUTTON_STYLES.arcane == Theme.BUTTON_STYLES.outline)
	s.ok("[×] au trait", Theme.CreateCloseButton(parent).plate == nil)
	s.ok("bouton-icône au trait", Theme.CreateIconButton(parent, 24, "x").plate == nil)
	s.ok("roue sans plaque", Theme.CreateGearButton(parent, 22).plate == nil)
	s.ok("interrupteur d'avant", Theme.CreateToggle(parent).inset == nil)
	local slider = Theme.CreateSlider(parent, 200, 0, 10, 1)
	s.ok("curseur d'avant (piste 3 px, poignée 8 x 12)", not slider.forge and slider.track.height == 3 and slider.handle.width == 8)
	local dd = Theme.CreateDropdown(parent, 160)
	s.ok("liste d'avant", dd.plate == nil and dd.caret == nil)
	s.ok("recherche d'avant", Theme.CreateSearchBox(parent, 120, "x").inset == nil)
	s.ok("nuancier d'avant", Theme.CreateSwatch(parent).inset == nil)
	local bar = Theme.CreateBar(parent, 100, 6)
	s.ok("barre d'avant", not bar.forge and bar.fillShade == nil and Same(bar.bg.vertex, { 0.15, 0.17, 0.20 }))
	local power = Theme.CreatePowerButton(parent, 16)
	s.ok("interrupteur de module d'avant", not power.forgeLed)
	s.check("[FORGE] Sobre : les contrôles gardent leurs régions d'avant, rien de plus")
end

Theme.ApplySkin("azeroth")

do
	Say("-- contrôles forgés : boutons")
	local s = Steps()
	local missing = {}
	for style in pairs(Theme.BUTTON_STYLES) do
		local f = Theme.FORGE_BUTTONS[style]
		if not (f and Theme.FORGE_PLATE[f.plate] and f.text) then missing[#missing + 1] = style end
	end
	Check("[FORGE] chaque style de bouton a sa plaque et son encre forgées", #missing == 0, table.concat(missing, ", "))
	Check("[FORGE] les sens : principal et aventure en or, accent bronze, ajouter vert, retirer rouge, action neutre arcane",
		Theme.FORGE_BUTTONS.primary.plate == "gold" and Theme.FORGE_BUTTONS.adventure.plate == "gold"
		and Theme.FORGE_BUTTONS.accent.plate == "bronze" and Theme.FORGE_BUTTONS.add.plate == "green"
		and Theme.FORGE_BUTTONS.danger.plate == "red" and Theme.FORGE_BUTTONS.arcane.plate == "arcane"
		and Theme.FORGE_BUTTONS.outline.plate == "neutral")

	for _, style in ipairs({ "outline", "primary", "danger" }) do
		local b = Theme.CreateButton(parent, 120, 28, style, nil, style)
		local f = b.forge
		local plate = Theme.FORGE_PLATE[f.plate]
		s.ok(style .. " : plaque 9 tranches", b.plate and Count(b.plate.parts) == 9 and b.plate.parts.c.texture == Theme.ART.plate.file)
		s.ok(style .. " : repos teinté", Same(SliceColor(b.plate), plate) and Same(b.text.textColor, f.text))
		s.ok(style .. " : fond et contour du Sobre transparents", b.bg.vertex[4] == 0 and b.border.top.vertex[4] == 0)
		b.scripts.OnEnter(b)
		s.ok(style .. " : survol éclairé", Same(SliceColor(b.plate), Theme.ForgeHover(plate))
			and Theme.Luminance(SliceColor(b.plate)) > Theme.Luminance(plate))
		b.scripts.OnMouseDown(b, "LeftButton")
		s.ok(style .. " : appui assombri, libellé enfoncé", Same(SliceColor(b.plate), Theme.ForgeTint(plate, f.press or Theme.FORGE.press))
			and Theme.Luminance(SliceColor(b.plate)) < Theme.Luminance(plate) and b.text.lastPoint.x == 1 and b.text.lastPoint.y == -1)
		b.scripts.OnMouseUp(b)
		s.ok(style .. " : relâché au repos", Same(SliceColor(b.plate), plate) and b.text.lastPoint.x == 0)
		b:Disable()
		s.ok(style .. " : désactivé désaturé, lisible", Same(SliceColor(b.plate), Theme.FORGE_PLATE.disabled)
			and Same(b.text.textColor, Theme.DISABLED.text) and b.disabledLook == true)
		b.scripts.OnEnter(b)
		s.ok(style .. " : désactivé, pas de survol", Same(SliceColor(b.plate), Theme.FORGE_PLATE.disabled))
		b:Enable()
		s.ok(style .. " : réactivé", Same(SliceColor(b.plate), plate))
	end
	local gold = Theme.CreateButton(parent, 120, 28, "Or", nil, "primary")
	local light = Theme.CreateButton(parent, 120, 28, "Clair", nil, "outline")
	s.ok("encre sombre sur l'or sans ombre, libellé clair ombré", gold.text.shadow and gold.text.shadow[4] == 0
		and light.text.shadow and light.text.shadow[4] > 0)
	s.check("[FORGE] bouton : plaque teintée, survol, appui, désactivé, réactivé")

	local carnet = Theme.CreateButton(parent, 120, 28, "Carnet", nil, "primary")
	carnet.skinPaint = function(self, state) self.skinned = state end
	Theme.ButtonRest(carnet)
	Check("[FORGE] un habillage (skinPaint, carnet Azeroth) efface la plaque et peint seul",
		not SliceShown(carnet.plate) and carnet.skinned == "rest")
end

do
	Say("-- contrôles forgés : contrastes des boutons")
	local L, F = Theme.FORGE.label, Theme.FORGE
	local worst, where = math.huge, ""
	local function Probe(name, ink, tint)
		for _, level in ipairs({ L.light, L.dark }) do
			local ratio = Theme.Contrast(ink, Theme.ForgeSurface(tint, level))
			if ratio - 4.5 < worst then worst, where = ratio - 4.5, string.format("%s %.2f", name, ratio) end
		end
	end
	for style, f in pairs(Theme.FORGE_BUTTONS) do
		local plate = Theme.FORGE_PLATE[f.plate]
		Probe(style .. " repos", f.text, plate)
		Probe(style .. " survol", f.text, Theme.ForgeHover(plate))
		Probe(style .. " appui", f.text, Theme.ForgeTint(plate, f.press or F.press))
	end
	Probe("désactivé", Theme.DISABLED.text, Theme.FORGE_PLATE.disabled)
	Check("[FORGE] libellé de chaque bouton forgé ≥ 4,5:1 sur sa plaque (plus clair et plus sombre point, repos, survol, appui, désactivé)",
		worst >= 0, where)
	-- le point le plus sombre sous un libellé est celui de la texture (tranche du centre)
	Check("[FORGE] niveaux de la plaque sous un libellé : ceux de la texture générée (0,786 à 0,593)",
		math.abs(L.light - 0.786) < 0.01 and math.abs(L.dark - 0.593) < 0.01 and L.light > L.dark)

	local worstSmall, whereSmall = math.huge, ""
	for _, pair in ipairs({
		{ "× repos", Theme.MUTED_LIGHT, Theme.FORGE_PLATE.neutral },
		{ "× survol", Theme.GOLD_LIGHT, Theme.ForgeHover(Theme.FORGE_PLATE.bronze) },
		{ "liste : libellé", Theme.LABEL, Theme.FORGE_PLATE.neutral },
		{ "liste survolée : libellé", Theme.LABEL, Theme.ForgeHover(Theme.FORGE_PLATE.neutral) },
		{ "liste ouverte : libellé", Theme.LABEL, Theme.FORGE_PLATE.arcane },
	}) do
		for _, level in ipairs({ L.light, L.dark }) do
			local ratio = Theme.Contrast(pair[2], Theme.ForgeSurface(pair[3], level))
			if ratio < worstSmall then worstSmall, whereSmall = ratio, string.format("%s %.2f", pair[1], ratio) end
		end
	end
	Check("[FORGE] [×] et liste déroulante : libellé ≥ 4,5:1 sur leur plaque (repos, survol, ouverte)", worstSmall >= 4.5, whereSmall)
end

do
	Say("-- contrôles forgés : champs, listes, cases (contrastes)")
	local fill = Theme.FORGE.insetFill
	local worst, where = math.huge, ""
	local function Probe(name, ink, bg, need)
		local ratio = Theme.Contrast(ink, bg)
		if ratio - need < worst then worst, where = ratio - need, string.format("%s %.2f", name, ratio) end
	end
	-- fond d'un creux : niveau insetFill (le plus clair) ; ombre du haut : noir (le plus sombre)
	for _, rim in ipairs({ { "repos", Theme.EDGE }, { "focus", Theme.ACTIVE }, { "or", Theme.GOLD_SOFT } }) do
		for _, bg in ipairs({ Theme.ForgeSurface(rim[2], fill), { 0, 0, 0 } }) do
			Probe("texte du champ / creux " .. rim[1], Theme.LABEL, bg, 4.5)
			Probe("indication / creux " .. rim[1], Theme.MUTED, bg, 4.5)
		end
	end
	-- liste ouverte : carte en relief ; ligne survolée : dégradé arcane sur la carte
	local L = Theme.FORGE.label
	for _, level in ipairs({ L.light, L.dark }) do
		local card = Theme.ForgeSurface(Theme.FORGE_PLATE.card, level)
		Probe("choix / carte", Theme.LABEL, card, 4.5)
		Probe("choix courant / carte", Theme.GOLD_LIGHT, card, 4.5)
		Probe("choix grisé / carte", Theme.MUTED, card, 4.5)
		Probe("choix survolé / arcane", Theme.LABEL, Theme.Over(card, Theme.ACTIVE, Theme.FORGE.rowSelect), 4.5)
		Probe("choix courant survolé / arcane", Theme.GOLD_LIGHT, Theme.Over(card, Theme.ACTIVE, Theme.FORGE.rowSelect), 4.5)
	end
	Check("[FORGE] champs en creux et liste ouverte : chaque texte ≥ 4,5:1 (fond le plus clair et ombre)", worst >= 0, where)
	-- éléments graphiques (WCAG 1.4.11, 3:1) : coche or et filet du focus sur le fond du creux
	Check("[FORGE] coche or clair et filet arcane du focus visibles sur le fond du creux (≥ 3:1)",
		Theme.Contrast(Theme.GOLD_LIGHT, Theme.ForgeSurface(Theme.GOLD_SOFT, fill)) >= 3
		and Theme.Contrast(Theme.ACTIVE, Theme.ForgeSurface(Theme.ACTIVE, fill)) >= 3)
end

do
	Say("-- contrôles forgés : petits boutons")
	local s = Steps()
	local close = Theme.CreateCloseButton(parent, 22)
	local neutral, bronze = Theme.FORGE_PLATE.neutral, Theme.FORGE_PLATE.bronze
	s.ok("[×] : petite plaque, contour caché", close.plate and Same(SliceColor(close.plate), neutral)
		and not close.border.top:IsShown() and close.plate.margin == Theme.FORGE.marginSmall)
	close.scripts.OnEnter(close)
	s.ok("[×] survol : bronze, « × » or clair", Same(SliceColor(close.plate), Theme.ForgeHover(bronze))
		and Same(close.label.textColor, Theme.GOLD_LIGHT))
	close.scripts.OnMouseDown(close, "LeftButton")
	s.ok("[×] appui : plaque assombrie, « × » enfoncé", Same(SliceColor(close.plate), Theme.ForgeTint(bronze, Theme.FORGE.press))
		and close.label.lastPoint.x == 1)
	close.scripts.OnMouseUp(close)
	s.ok("[×] relâché : repos", Same(SliceColor(close.plate), neutral) and Same(close.label.textColor, Theme.MUTED_LIGHT))
	local icon = Theme.CreateIconButton(parent, 24, "Interface\\Icons\\X", nil, "Astuce")
	s.ok("icône : plaque neutre", icon.plate and Same(SliceColor(icon.plate), neutral))
	icon.scripts.OnEnter(icon)
	s.ok("icône survol : bronze, icône en couleurs", Same(SliceColor(icon.plate), Theme.ForgeHover(bronze)) and icon.icon.alpha == 1)
	icon.scripts.OnLeave(icon)
	icon:Disable()
	s.ok("icône désactivée : plaque éteinte", Same(SliceColor(icon.plate), Theme.FORGE_PLATE.disabled) and icon.disabledLook)
	icon.scripts.OnEnter(icon)
	s.ok("icône désactivée : pas de survol", Same(SliceColor(icon.plate), Theme.FORGE_PLATE.disabled))
	local gear = Theme.CreateGearButton(parent, 22)
	s.ok("roue : plaque neutre", gear.plate and Same(SliceColor(gear.plate), neutral))
	gear.scripts.OnEnter(gear)
	s.ok("roue survol : or clair, plaque bronze", gear.gearHot and Same(gear.icon.vertex, Theme.GOLD_LIGHT)
		and Same(SliceColor(gear.plate), Theme.ForgeHover(bronze)))
	gear.scripts.OnLeave(gear)
	s.ok("roue quittée : repos", Same(gear.icon.vertex, Theme.GEAR.rest) and Same(SliceColor(gear.plate), neutral))
	s.check("[FORGE] [×], bouton-icône, roue : petite plaque, bronze et or au survol, appui, désactivé")
end

do
	Say("-- contrôles forgés : cases, interrupteurs, voyants")
	local s = Steps()
	Mock.InstallAtlas(nil)
	local box = CreateFrame("Button", nil, parent)
	box:SetSize(18, 18)
	s.ok("case sans atlas du client : posée quand même", Theme.ApplyCheckbox(box, 18) == true and box.forgeCheck)
	s.ok("case : creux et coche du fichier du jeu", box.inset and box.inset.parts.c.texture == Theme.ART.inset.file
		and box.check.texture == Theme.CHECK_FILE and box.check.atlas == nil)
	Theme.SetCheckboxState(box, true)
	s.ok("cochée : coche or clair qui luit, filet or", box.check:IsShown() and box.glow:IsShown()
		and Same(box.check.vertex, Theme.GOLD_LIGHT) and Same(SliceColor(box.inset), Theme.GOLD_SOFT))
	Theme.SetCheckboxState(box, false)
	s.ok("vide : ni coche ni lueur, filet or patiné", not box.check:IsShown() and not box.glow:IsShown()
		and Same(SliceColor(box.inset), Theme.EDGE))
	Theme.SetCheckboxState(box, "partial")
	s.ok("partielle : trait clair", box.partialMark:IsShown() and not box.check:IsShown())
	s.check("[FORGE] case : creux, coche or qui luit, vide, partielle ; sans atlas du client")

	s = Steps()
	Mock.InstallAtlas(true)
	local t = Theme.CreateToggle(parent)
	s.ok("interrupteur dessiné même si le client a la case", t.forgeSwitch and not t.checkbox and t.inset and t.thumb
		and t.width == 32 and t.height == 15)
	s.ok("piste et curseur du Sobre invisibles", t.track.alpha == 0 and t.knob.alpha == 0 and not t.edge.top:IsShown())
	s.ok("coupé : curseur à gauche, filet or patiné, sans lueur", t.knob.lastPoint.point == "LEFT"
		and Same(SliceColor(t.inset), Theme.EDGE) and Same(SliceColor(t.thumb), Theme.FORGE_PLATE.thumb) and not t.glow:IsShown())
	t:SetChecked(true)
	s.ok("actif : curseur à droite, arcane, qui luit", t.knob.lastPoint.point == "RIGHT" and t:GetChecked()
		and Same(SliceColor(t.inset), Theme.ACTIVE) and Same(SliceColor(t.thumb), Theme.FORGE_PLATE.thumbOn) and t.glow:IsShown())
	t:SetPartial()
	s.ok("partiel : curseur au centre, filet or", t.knob.lastPoint.point == "CENTER" and Same(SliceColor(t.inset), Theme.GOLD)
		and not t.glow:IsShown())
	s.ok("le curseur suit sa place", t.thumb.parts.tl.lastPoint.relTo == t.knob)
	s.ok("aucun atlas du client", #Atlases(t) == 0, table.concat(Atlases(t), ","))
	Mock.InstallAtlas(nil)
	s.check("[FORGE] interrupteur : piste en creux, curseur en relief, arcane et lueur si actif, partiel ; jamais la case du client")

	s = Steps()
	local power = Theme.CreatePowerButton(parent, 16)
	Theme.SetPowerState(power, true)
	s.ok("voyant allumé : point vert", power.forgeLed and power.icon.texture == Theme.ART.dot.file
		and Same(power.icon.vertex, Theme.GREEN) and power.icon.width == Theme.FORGE.led)
	Theme.SetPowerState(power, false)
	s.ok("voyant éteint : petit point sombre", Same(power.icon.vertex, Theme.FORGE.ledOff) and power.icon.width < Theme.FORGE.led)
	s.check("[FORGE] interrupteur de module : voyant vert allumé, sombre éteint")
end

do
	Say("-- contrôles forgés : curseur, liste, recherche, nuancier, barre")
	local s = Steps()
	local slider = Theme.CreateSlider(parent, 220, 0, 100, 5)
	slider:SetValue(40)
	local F = Theme.FORGE
	s.ok("case de valeur en creux", slider.box.inset and slider.box.bg.alpha == 0 and not slider.box.border.top:IsShown())
	s.ok("piste sombre, ombre et filet", slider.track.height == F.sliderTrack and Same(slider.track.vertex, F.track)
		and slider.trackShade and slider.trackRim)
	s.ok("part remplie : dégradé or sombre -> or clair", slider.fill.gradientSpec and slider.fill.gradientSpec[1] == "HORIZONTAL"
		and Same(slider.fill.gradientSpec[2], F.goldDeep) and Same(slider.fill.gradientSpec[4], Theme.GOLD_LIGHT))
	s.ok("poignée claire, liseré noir, lueur", slider.handle.width == F.thumb[1] and slider.handle.height == F.thumb[2]
		and slider.handleEdge and slider.glow:IsShown() and slider.glow.lastPoint.relTo == slider.handle)
	s.ok("pas de suivi au repos (OnUpdate)", slider.hit.scripts.OnUpdate == nil)
	s.check("[FORGE] curseur : piste en creux, dégradé or, poignée qui luit, case de valeur en creux")

	s = Steps()
	local dd = Theme.CreateDropdown(parent, 160, nil)
	dd:SetOptions({ { value = "a", label = "A" }, { value = "b", label = "B" } })
	dd:SetValue("a")
	local neutral = Theme.FORGE_PLATE.neutral
	s.ok("plaque et chevron or dessiné", dd.plate and #dd.caret == #F.caret and not dd.chevron:IsShown()
		and Same(dd.caret[1].vertex, Theme.GOLD_LIGHT) and dd.caret[1].width > dd.caret[#dd.caret].width)
	s.ok("fond et contour transparents", dd.bg.vertex[4] == 0 and dd.border.top.vertex[4] == 0)
	dd.scripts.OnEnter(dd)
	s.ok("survol éclairé", Same(SliceColor(dd.plate), Theme.ForgeHover(neutral)))
	dd:Open()
	s.ok("ouverte : bleu arcane, contour toujours transparent", Same(SliceColor(dd.plate), Theme.FORGE_PLATE.arcane)
		and dd.border.top.vertex[4] == 0)
	s.ok("liste : carte en relief", dd.list.plate and dd.list.bg.alpha == 0)
	s.ok("choix courant en or clair", Same(dd.list.rows[1].label.textColor, Theme.GOLD_LIGHT))
	s.ok("ligne survolée : dégradé arcane", dd.list.rows[2].hover.gradientSpec
		and Same(dd.list.rows[2].hover.gradientSpec[2], Theme.ACTIVE))
	dd:Close()
	s.ok("fermée : repos", Same(SliceColor(dd.plate), neutral))
	dd.azSurface = "dark"
	dd:Open()
	s.ok("habillée par son module : contour or du Sobre à l'ouverture", dd.border.top.vertex[4] == 1)
	dd:Close()
	s.ok("aucun atlas du client", #Atlases(dd) == 0, table.concat(Atlases(dd), ","))
	s.check("[FORGE] liste déroulante : plaque, chevron or, survol, ouverte arcane, liste en carte ; habillage respecté")

	s = Steps()
	local box = Theme.CreateSearchBox(parent, 120, "Chercher")
	s.ok("champ en creux, fond et contour transparents", box.inset and box.bg.vertex[4] == 0 and box.border.top.vertex[4] == 0
		and Same(SliceColor(box.inset), Theme.EDGE))
	box.scripts.OnEditFocusGained(box)
	s.ok("focus : filet arcane", Same(SliceColor(box.inset), Theme.ACTIVE) and box.border.top.vertex[4] == 0)
	box.scripts.OnEditFocusLost(box)
	s.ok("focus perdu : or patiné", Same(SliceColor(box.inset), Theme.EDGE))
	box.azSurface = "dark"
	box.scripts.OnEditFocusGained(box)
	s.ok("habillé par son module : contour du Sobre au focus", box.border.top.vertex[4] == 1)
	s.check("[FORGE] recherche : champ en creux, filet arcane au focus ; habillage respecté")

	s = Steps()
	local sw = Theme.CreateSwatch(parent, 15)
	s.ok("nuancier : la couleur au fond d'un creux", sw.inset and not sw.border.top:IsShown() and sw.color.lastPoint.x < 0)
	local bar = Theme.CreateBar(parent, 100, 6)
	bar:SetColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3])
	bar:SetValue(0.5)
	s.ok("barre : piste sombre", bar.forge and Same(bar.bg.vertex, F.track))
	s.ok("remplissage : sa couleur, voile en dégradé et reflet", Same(bar.fill.vertex, Theme.GREEN) and bar.fillShade:IsShown()
		and bar.fillShade.gradientSpec[1] == "VERTICAL" and bar.sheen:IsShown() and bar.sheen.height == 1)
	bar:SetValue(0)
	s.ok("vide : ni voile ni reflet", not bar.fillShade:IsShown() and not bar.sheen:IsShown())
	local thin = Theme.CreateBar(parent, 100, 2)
	thin:SetValue(1)
	s.ok("barre fine : voile seul (pas de reflet ni de filet)", thin.fillShade:IsShown() and thin.sheen == nil and thin.trackRim == nil)
	bar.azSurface = "dark"
	bar:SetValue(0.5)
	s.ok("barre habillée par son module : ses seules matières", not bar.fillShade:IsShown() and not bar.sheen:IsShown()
		and not bar.trackRim:IsShown())
	s.ok("barre : pas de découpe en 9 tranches (listes longues)", bar.plate == nil and bar.inset == nil)
	s.check("[FORGE] nuancier en creux ; barre : piste sombre, voile et reflet suivent le remplissage, pas de découpe")
end

do
	Say("-- contrôles forgés : réglages")
	ResetWorld()
	local frame = NS:EnsureOptions()
	local s = Steps()
	s.ok("Terminé : bouton principal en or", frame.closeButton and frame.closeButton.style == "primary"
		and frame.closeButton.plate ~= nil)
	s.ok("« Rallumer » : bouton vert", frame.offBanner and frame.offBanner.style == "add")
	local action
	for _, card in ipairs(frame.rows or {}) do
		if card.button and card.def then action = card.button break end
	end
	s.ok("bouton d'action d'une carte : bleu arcane", action ~= nil and action.style == "arcane")
	s.ok("recherche de la navigation en creux", frame.search and frame.search.inset ~= nil)
	s.check("[FORGE] réglages : Terminé en or, Rallumer en vert, actions en arcane, recherche en creux")
	frame:Hide()
end

parent:Hide()
NS.Theme.ApplySkin(SKIN0[1]); QNS.Theme.ApplySkin(SKIN0[2])
