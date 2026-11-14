-- QuestCompanion 3.1.0 : le médaillon forgé du compagnon (ForgeCompanion.lua,
-- AzerothStyle.lua). État du produit (thème forgé, ancien habillage coupé,
-- sans les atlas du client) : l'anneau généré (Theme.ART.ring) centré sur le
-- portrait, la plaque du nom (titre de l'identité, ligne « stade · niveau »),
-- l'étiquette d'humeur teintée (encre ≥ 7:1), le fond en disque ; toutes les
-- fonctions de l'ancien habillage re-rattachées à l'anneau (teinte du cadre
-- gagné et halo, lueur ronde quand il parle, éclats d'une brillante,
-- « Niveau N ! », huit familles et halo prismatique, Voile d'hiver), avec
-- leurs replis en matières forgées ; la bulle forgée (nom de qui parle,
-- reflet) ; la bascule à chaud forgé <-> Sobre, sans reste ni fuite ; le
-- Sobre sans aucune brique forgée. Contrastes mesurés sur le fond réel.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame" }
local GLOBALS = { "UnitLevel" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local function Same(a, b, eps)
	eps = eps or 1e-6
	return type(a) == "table" and type(b) == "table" and math.abs(a[1] - b[1]) < eps
		and math.abs(a[2] - b[2]) < eps and math.abs(a[3] - b[3]) < eps
end

local function Errors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return table.concat(list, " | ")
end

-- le monde ; style : "azeroth" (thème forgé) ou "sobre" ; atlas : ceux du client
local function Fresh(style, atlas)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.azFx, NS.errors = nil, {}
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	NS.companionBubblePrio, NS.companionBubbleKey, NS.companionRT, NS.companionSession = nil, nil, nil, nil
	if NS.tutorialStep then NS.tutorialStep = nil end
	_G.UnitLevel = function() return 24 end
	if atlas then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style or "azeroth"
	NS:DB().winterVeil = "off"
	NS:ApplyUIStyle()
	local data = NS:CompanionData()
	data.tutoDone, data.name = true, "Brindille"
	data.needs = { hunger = 82, energy = 64, mood = 91, curiosity = 46 }
	NS:CompanionUpdateVisibility()
	return NS:EnsureCompanionFrame()
end

local function Done()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	ResetWorld()
end

local function SliceOf(slice, art)
	if type(slice) ~= "table" or type(slice.parts) ~= "table" then return false end
	for _, tex in pairs(slice.parts) do
		if tex.texture ~= Theme.ART[art].file then return false end
	end
	return true
end

local function Shown(region) return region ~= nil and region.IsShown and region:IsShown() == true end

-- une brique forgée (frame.forged, frame.forgeSkin, bubble.forgeTalk) dans le cadre ?
local function ForgedInside(root)
	if root.forged == true or root.forge == true then return true end
	for _, child in ipairs(root.mockChildren or {}) do
		if ForgedInside(child) then return true end
	end
	return false
end

-- 1. Le médaillon forgé, état du produit ------------------------------------------------------------
do
	Say("-- médaillon forgé : état du produit")
	local frame = Fresh("azeroth")
	local s = Steps()
	local skin = frame and frame.forgeSkin
	s.ok("thème forgé, ancien habillage coupé", Theme.Forged() and NS.QCForged() and not NS:AzerothOn())
	s.ok("prédicat de l'anneau vrai", NS:CompanionRingOn() == true)
	s.ok("anneau forgé posé", frame and frame.ring == "forge" and NS.CompanionRinged(frame)
		and NS.CompanionRingSkin(frame) == skin and Shown(skin))
	s.ok("cadre hors ancien habillage : uiStyle sobre, clé forge, pas d'anneau du client",
		frame.uiStyle == "sobre" and frame.styleKey == "forge" and frame.azSkin == nil and not frame.azeroth)
	local F = NS.FORGE_RING
	local ring = skin and skin.ring
	local p = ring and ring.lastPoint
	s.ok("anneau : notre matière, centrée sur le portrait", ring and ring.texture == Theme.ART.ring.file
		and ring.width == F.w and ring.height == F.h and p and p.point == "CENTER" and p.relTo == frame
		and p.relPoint == "TOP" and p.x == F.x and p.y == NS.AZEROTH_RING.y)
	s.ok("même centre que l'anneau du client (filet et pastilles en place)", F.y == NS.AZEROTH_RING.y)
	s.ok("plaque du nom : plaque en relief teinte carte", SliceOf(skin.plate, "plate")
		and Same(skin.plate.color, Theme.FORGE_PLATE.card))
	s.ok("plaque : sous le cadre, plus large que lui", skin.plateBox.lastPoint.point == "BOTTOM"
		and skin.plateBox.width == frame.width + 2 * NS.FORGE_COMPANION_PLATE.out
		and skin.plateBox.height == NS.FORGE_COMPANION_PLATE.height)
	s.ok("nom sur la plaque, encre des titres", frame.name:GetParent() == skin
		and frame.name.lastPoint.relTo == skin.plateBox and Same(frame.name.textColor, Theme.TITLE)
		and frame.name:GetText() == "Brindille")
	s.ok("ligne « stade · niveau »", skin.stage:GetText() == NS:CompanionStageLabel() .. " · niveau 24"
		and Same(skin.stage.textColor, Theme.MUTED_LIGHT), skin.stage:GetText())
	s.ok("humeur dans l'étiquette, sous la plaque", frame.mood:GetParent() == skin.moodTab
		and skin.moodTab.lastPoint.relTo == skin.plateBox and SliceOf(skin.moodTab.slice, "plate")
		and skin.moodTab:GetFrameLevel() < skin:GetFrameLevel())
	s.ok("bande carrée du Sobre et liserés cachés", not Shown(frame.plate) and not Shown(frame.top)
		and not Shown(frame.leftEdge))
	local base = frame.modelBase
	s.ok("portrait au centre de l'anneau, ses coins sous la bande d'or", base and base.w == F.model and base.h == F.model
		and base.x + base.w / 2 == frame.width / 2 and base.y - base.h / 2 == F.y
		and math.sqrt(2) * F.model / 2 < F.w / 2 * Theme.ART.ring.outer
		and math.sqrt(2) * F.model / 2 > F.w / 2 * Theme.ART.ring.inner)
	s.ok("fond gagné sous l'anneau (repli carré sans masque)", frame.bg.lastPoint.relPoint == "TOP"
		and frame.bg.width == F.square and frame.bg.forgePlaced)
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] médaillon forgé : anneau généré, plaque du nom (titre, stade · niveau), étiquette d'humeur, portrait centré")
end

-- 2. L'étiquette d'humeur : teinte par humeur, encre ≥ 7:1 ------------------------------------------
do
	Say("-- médaillon forgé : humeurs")
	local frame = Fresh("azeroth")
	local s = Steps()
	local tab = frame.forgeSkin.moodTab
	local seen = {}
	local data = NS:CompanionData()
	local cases = {
		{ "radiant", { hunger = 95, energy = 95, mood = 95, curiosity = 95 } },
		{ "happy", { hunger = 60, energy = 60, mood = 60, curiosity = 60 } },
		{ "dreamy", { hunger = 20, energy = 20, mood = 20, curiosity = 20 } },
	}
	for _, case in ipairs(cases) do
		data.sleepy = nil
		data.needs = case[2]
		NS:CompanionRefreshLabels()
		s.ok(case[1] .. " : étiquette posée", tab.mood == case[1], tab.mood)
		seen[case[1]] = tab.plate
	end
	data.sleepy = true
	NS:CompanionRefreshLabels()
	s.ok("sleepy : étiquette posée", tab.mood == "sleepy")
	seen.sleepy = tab.plate
	data.sleepy = nil
	local distinct = {}
	for _, plate in pairs(seen) do distinct[plate] = true end
	local n = 0
	for _ in pairs(distinct) do n = n + 1 end
	s.ok("quatre humeurs, quatre teintes", n == 4)
	s.ok("largeur au mot", tab.width >= 2 * NS.FORGE_MOOD_TAB.pad)
	-- encre sur chaque teinte, aux deux niveaux de la plaque sous un libellé
	local worst, at = 99, ""
	for mood, spec in pairs(NS.FORGE_MOOD_TINTS) do
		local tint = Theme.FORGE_PLATE[spec.plate]
		for _, level in ipairs({ Theme.FORGE.label.light, Theme.FORGE.label.dark }) do
			local c = Theme.Contrast(spec.ink(), Theme.ForgeSurface(tint, level))
			if c < worst then worst, at = c, mood end
		end
	end
	s.ok("encre ≥ 7:1 sur chaque teinte", worst >= 7, string.format("%.2f (%s)", worst, at))
	s.check("[FCOMP] humeur : une teinte de plaque par humeur, largeur au mot, encre ≥ 7:1 (" .. string.format("%.2f", worst) .. ")")
end

-- 3. Contrastes des nouveaux textes ------------------------------------------------------------------
do
	Say("-- médaillon forgé : contrastes")
	Fresh("azeroth")
	local s = Steps()
	local card = Theme.FORGE_PLATE.card
	local light = Theme.ForgeSurface(card, Theme.FORGE.plateTop)
	local dark = Theme.ForgeSurface(card, Theme.FORGE.plateBottom)
	local name = math.min(Theme.Contrast(Theme.TITLE, light), Theme.Contrast(Theme.TITLE, dark))
	local sub = math.min(Theme.Contrast(Theme.MUTED_LIGHT, light), Theme.Contrast(Theme.MUTED_LIGHT, dark))
	s.ok("nom (titre) sur la plaque ≥ 3 (et ≥ 4,5)", name >= 4.5, string.format("%.2f", name))
	s.ok("ligne « stade · niveau » ≥ 4,5", sub >= 4.5, string.format("%.2f", sub))
	-- bulle : fond WINDOW à 0,96 sur le monde (le plus clair : blanc)
	local bubbleBg = Theme.Over(Theme.WHITE, Theme.WINDOW, 0.96)
	local speaker = Theme.Contrast(Theme.TITLE, bubbleBg)
	s.ok("nom de qui parle (bulle) ≥ 4,5", speaker >= 4.5, string.format("%.2f", speaker))
	-- « Niveau N ! » : sur son nuage (point lumineux sombre) posé sur un monde gris moyen
	local cloud = Theme.Over({ 0.5, 0.5, 0.5 }, Theme.SHADOW, NS.FORGE_FX.cloudAlpha)
	local level = Theme.Contrast(Theme.TITLE, cloud)
	s.ok("« Niveau N ! » sur son nuage ≥ 3", level >= 3, string.format("%.2f", level))
	s.check(string.format("[FCOMP] contrastes : nom %.2f, stade %.2f, bulle %.2f, « Niveau N ! » %.2f", name, sub, speaker, level))
end

-- 4. Le cadre gagné teinte l'anneau, son halo ---------------------------------------------------------
do
	Say("-- médaillon forgé : cadre gagné")
	local frame = Fresh("azeroth")
	local s = Steps()
	local ring = frame.forgeSkin.ring
	s.ok("Ardoise (défaut) : gris ardoise désaturé", ring.azLook == "slate" and ring.azDesat == true
		and Same(ring.vertex, NS.AZEROTH_RING_TINTS.slate))
	local data = NS:CompanionData()
	data.unlocked["frame:frost"] = true
	NS:CompanionSetStyle("frame", "frost")
	local glow = frame.forgeSkin.ringGlow
	s.ok("Givre : argent-bleu, désaturé", ring.azLook == "frost" and ring.azDesat == true
		and Same(ring.vertex, NS.AZEROTH_RING_TINTS.frost))
	s.ok("Givre : halo glacé (point lumineux, sans l'atlas du client)", glow and Shown(glow) and glow.azAtlas == "forge"
		and glow.texture == Theme.ART.dot.file and glow.blendMode == "ADD"
		and Same(glow.vertex, NS.AZEROTH_RING_TINTS.frost.glow))
	data.unlocked["frame:copper"] = true
	NS:CompanionSetStyle("frame", "copper")
	s.ok("Cuivre : teinte cuivre, halo éteint", ring.azLook == "copper" and not ring.azDesat and not Shown(glow))
	s.ok("bordures carrées du client cachées", not (frame.styleBorder and Shown(frame.styleBorder)))
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] cadre gagné : teinte de l'anneau (Ardoise, Givre, Cuivre), halo glacé en point lumineux")
end

-- 5. Il parle : lueur ronde, plus vite pour une brillante ; éclats ---------------------------------
do
	Say("-- médaillon forgé : lueur et brillante")
	local frame = Fresh("azeroth")
	local s = Steps()
	NS:CompanionSay("EAT", { force = true })
	local now = Mock.now
	local alpha = NS:GlowUpdate(now + 0.5)
	local glow = frame.azGlow
	s.ok("il parle : lueur ronde (point lumineux doré), centrée sur l'anneau", alpha > 0 and glow and Shown(glow)
		and glow.forgeArt == "dot" and Same(glow.vertex, Theme.GOLD_LIGHT) and glow.lastPoint.y == NS.FORGE_RING.y)
	s.ok("pas de liseré rectangulaire", not (type(frame.glow) == "table" and frame.glow[1] and Shown(frame.glow[1])))
	local a1 = NS:GlowUpdate(now + 0.2)
	local a2 = NS:GlowUpdate(now + 1.3)
	s.ok("elle respire", math.abs(a1 - a2) > 0.01)
	s.ok("ancienne API des éclats : rien hors ancien habillage", NS:AzerothShinyFX() == false)
	s.ok("brillante repérée : éclats lancés", NS:CompanionShinyFX() == true and NS.azFx.shinyUntil ~= nil)
	local _, fast = NS:AzerothGlowEnvelope(Mock.now)
	s.ok("… lueur accélérée", fast == true)
	Mock:Advance(0.6)
	local sparks = frame.azSparks or {}
	local lit = 0
	for _, tex in ipairs(sparks) do if Shown(tex) and tex.forgeArt == "dot" then lit = lit + 1 end end
	s.ok("éclats : points lumineux dorés autour du cadre", #sparks == 4 and lit >= 1, lit)
	Mock:Advance(NS.AZEROTH_FX.shinyTime + 0.5)
	lit = 0
	for _, tex in ipairs(sparks) do if Shown(tex) then lit = lit + 1 end end
	s.ok("puis tout s'éteint, horloge retirée", lit == 0 and not (NS.azFxDriver and NS.azFxDriver.running))
	NS:GlowUpdate(Mock.now + 20)
	s.ok("la bulle finie : lueur éteinte", not Shown(glow))
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] il parle : lueur ronde dorée qui respire ; brillante : éclats en points lumineux, lueur plus vite")
end

-- 6. « Niveau N ! », « Aguerri ! » et la montée de la bulle --------------------------------------------
do
	Say("-- médaillon forgé : niveau et évolution")
	local frame = Fresh("azeroth")
	local s = Steps()
	NS:CompanionSay("EAT", { force = true })
	local bubble = NS.companionBubble
	local _, _, _, _, y0 = bubble:GetPoint()
	s.ok("ancienne API du niveau : rien hors ancien habillage", NS:AzerothLevelFX("x", "level") == false)
	NS:CompanionOnLevel(25)
	local parts = frame.azLevel
	local group = parts and parts.group
	s.ok("« Niveau 25 ! » lancé au gain de niveau", group and Shown(group) and group.text:GetText() == "Niveau 25 !",
		group and group.text:GetText())
	s.ok("titre à l'encre de l'identité", group and Same(group.text.textColor, Theme.TITLE))
	s.ok("volutes : deux filets lumineux de l'identité, qui s'éteignent vers l'extérieur", group.left and group.right
		and group.left.forgeArt == "line" and group.right.forgeArt == "line" and group.left.texCoord[1] == 1
		and Same(group.left.vertex, Theme.IDENTITY_LIGHT))
	s.ok("lueur du portrait : notre anneau en lumière ; nuage, ligne de lumière", parts.iglow and parts.iglow.forgeArt == "ring"
		and group.cloud and group.cloud.forgeArt == "dot" and group.line and group.line.forgeArt == "dot")
	Mock:Advance(0.9)
	local dots = 0
	for _, cluster in pairs(parts.dots) do if Shown(cluster) and cluster.points then dots = dots + 1 end end
	local _, _, _, _, y1 = bubble:GetPoint()
	s.ok("poussière dorée qui monte (grappes de points lumineux)", dots >= 1, dots)
	s.ok("la bulle monte au-dessus du titre", y1 == y0 + NS.AZEROTH_FX.groupLift, tostring(y0) .. " -> " .. tostring(y1))
	Mock:Advance(NS.AZEROTH_FX.levelTime)
	local _, _, _, _, y2 = bubble:GetPoint()
	s.ok("puis tout s'efface, la bulle revient", not Shown(group) and y2 == y0)
	NS:CompanionLevelFX(NS:F("AZ_FX_EVOLVE", "Aguerri"), "evolve")
	s.ok("évolution : « Aguerri ! »", Shown(group) and group.text:GetText() == "Aguerri !")
	NS:SetUIStyle("sobre")
	s.ok("thème changé pendant l'effet : arrêté net", not Shown(group) and NS.azFx.level == nil)
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] niveau et évolution : titre de l'identité entre deux filets, lueur, poussière, la bulle monte puis revient")
end

-- 7. Cosmétiques des hauts faits : huit familles, halo prismatique -----------------------------------
do
	Say("-- médaillon forgé : huit familles, prismatique")
	local frame = Fresh("azeroth")
	local s = Steps()
	local data = NS:CompanionData()
	data.unlocked["frame:feat_eight"], data.unlocked["frame:feat_prism"] = true, true
	NS:CompanionSetStyle("frame", "feat_eight")
	local eight = frame.featDeco and frame.featDeco.eight
	local F = NS.FORGE_RING
	local ok = eight and #eight == 8
	for _, icon in ipairs(eight or {}) do
		local p = icon.lastPoint
		local r = math.sqrt(p.x * p.x + (p.y - F.y) * (p.y - F.y))
		if not (Shown(icon) and p.relPoint == "TOP" and math.abs(r - (F.w / 2 - 3)) < 0.01) then ok = false end
	end
	s.ok("huit icônes en cercle sur l'anneau forgé", ok)
	NS:CompanionSetStyle("frame", "feat_prism")
	local halo = frame.featDeco.halo
	s.ok("prismatique sans l'atlas : notre anneau en lumière autour du médaillon", halo and Shown(halo)
		and halo.forgeArt == "ring" and halo.blendMode == "ADD")
	local v = halo and halo.vertex and halo.vertex[1]
	Mock:Advance(3)
	s.ok("sa teinte tourne", halo and halo.vertex and halo.vertex[1] ~= v)
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] hauts faits : huit familles autour de l'anneau forgé, halo prismatique en anneau de lumière qui tourne")
end

-- 8. Voile d'hiver sur le médaillon forgé -------------------------------------------------------------
do
	Say("-- médaillon forgé : Voile d'hiver")
	local frame = Fresh("azeroth")
	local s = Steps()
	NS:DB().winterVeil = "on"
	local shown = NS:WinterVeilCompanion()
	local d = frame.wvForgeDecor
	s.ok("décor posé sur l'habit forgé", shown == true and d and Shown(d) and d:GetParent() == frame.forgeSkin)
	s.ok("pas de décor de l'ancien habillage", frame.wvDecor == nil)
	local flakes = 0
	for _, tex in pairs(d.flakes or {}) do if Shown(tex) then flakes = flakes + 1 end end
	s.ok("quatre flocons aux coins", flakes == #NS.WINTER_VEIL_COMPANION.flakes)
	local swag = d.swags and d.swags[1]
	s.ok("guirlande posée sur la bande d'or du médaillon", swag and swag.lastPoint.y == NS.WINTER_VEIL_FORGE_LIGHTS.y
		and NS.WINTER_VEIL_FORGE_LIGHTS.y <= NS.WINTER_VEIL_FORGE_GOLD.top
		and NS.WINTER_VEIL_FORGE_LIGHTS.y >= NS.WINTER_VEIL_FORGE_GOLD.inner)
	s.ok("anneau Givre pendant le décor", frame.forgeSkin.ring.azLook == "frost")
	s.ok("neige qui tombe", d.snowing == true)
	NS:DB().winterVeil = "off"
	NS:WinterVeilCompanion()
	s.ok("décor coupé : caché, l'anneau reprend son cadre", not Shown(d) and frame.forgeSkin.ring.azLook == "slate")
	NS:DB().winterVeil = "on"
	NS:WinterVeilCompanion()
	NS:SetUIStyle("sobre")
	NS:WinterVeilApply()
	s.ok("Sobre : pas de décor", not Shown(d))
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] Voile d'hiver : flocons, guirlande sur la bande d'or, neige, anneau Givre ; coupé ou Sobre : caché")
end

-- 9. La bulle forgée : nom de qui parle, reflet à chaque réplique ------------------------------------
do
	Say("-- médaillon forgé : bulle")
	Fresh("azeroth")
	local s = Steps()
	NS:CompanionSay("EAT", { force = true })
	local bubble = NS.companionBubble
	local parts = bubble and bubble.forgeTalk
	local pad = Theme.BUBBLE_PAD
	s.ok("bulle du socle, forgée (filet lumineux)", bubble and bubble.forged == true and bubble.forgeBubble == true
		and not bubble.azBubble)
	s.ok("nom de qui parle, en capitales, encre des titres", parts and Shown(parts.name)
		and parts.name:GetText() == Theme.Upper(NS:CompanionName()) and Same(parts.name.textColor, Theme.TITLE))
	s.ok("la réplique dessous", bubble.text.lastPoint.y == -pad - 1 - NS.FORGE_BUBBLE.nameH)
	local base = math.max(Theme.BUBBLE_MIN, math.ceil(bubble.textHeight + 2 * pad + 2))
	s.ok("hauteur : réplique + nom", bubble.height == base + NS.FORGE_BUBBLE.nameH, tostring(bubble.height) .. " / " .. base)
	s.ok("reflet lancé à la réplique", NS.azFx and NS.azFx.sheenAt == Mock.now)
	Mock:Advance(0.3)
	local sheen = parts.sheen
	local x1 = sheen.lastPoint and sheen.lastPoint.x
	s.ok("il traverse la bulle", Shown(sheen) and sheen.blendMode == "ADD" and x1 and x1 > 0)
	Mock:Advance(0.3)
	s.ok("… de gauche à droite", sheen.lastPoint.x > x1)
	Mock:Advance(1)
	s.ok("puis s'éteint", not Shown(sheen))
	-- le tutoriel : boutons Suivant / Passer dans la bulle forgée
	NS:CompanionData().tutoDone = nil
	NS:CompanionStartTutorial(true)
	s.ok("tutoriel : Suivant et Passer, nom gardé", Shown(bubble.nextButton) and Shown(bubble.skipButton)
		and Shown(parts.name))
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] bulle forgée : nom de qui parle en capitales, réplique dessous, reflet qui la traverse, tutoriel")
end

-- 10. Bascule à chaud forgé <-> Sobre : le bon cadre, sans reste, sans fuite ---------------------------
do
	Say("-- médaillon forgé : bascule à chaud")
	local frame = Fresh("azeroth")
	local s = Steps()
	NS:CompanionSay("EAT", { force = true })
	local bubble = NS.companionBubble
	local skin = frame.forgeSkin
	NS:SetUIStyle("sobre")
	s.ok("Sobre : anneau ôté", frame.ring == nil and not Shown(skin) and frame.uiStyle == "sobre"
		and frame.styleKey == "sobre")
	s.ok("Sobre : cadre carré revenu (liserés, bande, nom et humeur à leur place)", Shown(frame.top) and Shown(frame.plate)
		and frame.name:GetParent() == frame and frame.name.lastPoint.relTo == frame and frame.name.lastPoint.y == 19
		and frame.mood:GetParent() == frame and frame.mood.lastPoint.y == 6)
	s.ok("Sobre : polices et encres d'avant", frame.name.fontObject == Theme.F_LABEL and frame.mood.fontObject == Theme.F_SMALL
		and Same(frame.name.textColor, Theme.PARCHMENT) and Same(frame.mood.textColor, Theme.TEXT))
	s.ok("Sobre : fond plein cadre, portrait d'avant", frame.bg.allPoints == frame and not frame.bg.forgePlaced
		and frame.modelBase == NS.COMPANION_MODEL_BASE)
	s.ok("Sobre : bulle sans nom ni filet forgé, aplat d'or", not Shown(bubble.forgeTalk.name) and not bubble.forgeBubble
		and bubble.sobreRule and Shown(bubble.sobreRule) and not Shown(bubble.rule)
		and bubble.text.lastPoint.y == -Theme.BUBBLE_PAD - 1)
	s.ok("Sobre : l'anneau n'est plus teint", NS:CompanionPaintRing() == nil)
	local before = #Mock.frames
	NS:SetUIStyle("azeroth")
	s.ok("forgé de nouveau : le même habit revient", frame.forgeSkin == skin and Shown(skin) and frame.ring == "forge"
		and frame.name:GetParent() == skin and not Shown(frame.plate) and frame.bg.forgePlaced)
	s.ok("forgé de nouveau : bulle forgée", bubble.forgeBubble and Shown(bubble.forgeTalk.name) and Shown(bubble.rule)
		and not Shown(bubble.sobreRule))
	NS:SetUIStyle("sobre")
	NS:SetUIStyle("azeroth")
	NS:SetUIStyle("sobre")
	NS:SetUIStyle("azeroth")
	s.ok("allers-retours : aucun cadre créé", #Mock.frames == before, #Mock.frames - before)
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] bascule à chaud forgé ↔ Sobre : le bon cadre chaque fois, sans reste de l'autre, sans fuite")
end

-- 11. Sobre à la création : aucune brique forgée ; né Sobre puis forgé ---------------------------------
do
	Say("-- médaillon forgé : Sobre")
	local frame = Fresh("sobre")
	local s = Steps()
	NS:CompanionSay("EAT", { force = true })
	local bubble = NS.companionBubble
	s.ok("Sobre : thème Sobre, pas d'anneau", not Theme.Forged() and NS:CompanionRingOn() == false and frame.ring == nil)
	s.ok("Sobre : aucune brique forgée (cadre, bulle)", frame.forgeSkin == nil and not ForgedInside(frame)
		and bubble.forgeTalk == nil and not bubble.forged)
	s.ok("Sobre : effets du médaillon muets", NS:CompanionShinyFX() == false and NS:CompanionLevelFX("x") == false)
	NS:SetUIStyle("azeroth")
	s.ok("né Sobre puis forgé : médaillon et bulle forgés posés", frame.ring == "forge" and Shown(frame.forgeSkin)
		and bubble.forgeBubble and bubble.forgeTalk.rule and Shown(bubble.forgeTalk.rule) and not Shown(bubble.rule))
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FCOMP] Sobre : aucune brique forgée, effets muets ; né Sobre puis forgé : médaillon et filet lumineux posés")
end

-- 12. L'ancien habillage (drapeau rallumé, atlas du client) : son anneau, pas le forgé -----------------
do
	Say("-- médaillon forgé : ancien habillage")
	T.Legacy(true)
	local frame = Fresh("azeroth", true)
	local s = Steps()
	s.ok("ancien habillage : anneau du client, pas de médaillon forgé", frame.ring == "azeroth" and frame.uiStyle == "azeroth"
		and frame.azSkin and Shown(frame.azSkin) and frame.forgeSkin == nil)
	s.ok("ses effets répondent par l'ancienne API", NS:AzerothShinyFX() == true)
	T.Legacy(false)
	s.check("[FCOMP] ancien habillage (drapeau) : l'anneau du client, le médaillon forgé jamais construit")
end

Done()
