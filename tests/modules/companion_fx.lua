-- Compagnon : effets à l'écran (CompanionFx.lua). Rebond, tremblement,
-- flottement heureux, cœurs, miettes, « ! », « Zzz » ; animations
-- de créature coupées par apparence ; /qc compagnon anim.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- Un scénario = une assertion ; chaque étape en défaut est nommée dans le message.
local function Scenario(name)
	local bad = {}
	return {
		ok = function(label, cond, extra)
			if not cond then bad[#bad + 1] = label .. (extra ~= nil and (" [" .. tostring(extra) .. "]") or "") end
			return cond
		end,
		done = function() Check(name, #bad == 0, table.concat(bad, " ; ")) end,
	}
end

local FX = { savedCreateFrame = _G.CreateFrame, savedHappy = NS.CompanionIsHappy }

-- cadres de modèle enregistrant l'animation jouée
function FX.InstallModel()
	_G.CreateFrame = function(kind, ...)
		local frame = FX.savedCreateFrame(kind, ...)
		if kind == "PlayerModel" or kind == "Model" then
			function frame:SetDisplayInfo(id) self.display = id end
			function frame:SetCreature(id) self.creature = id end
			function frame:SetAnimation(id) self.anim = id end
			function frame:SetModelScale(s) self.modelScale = s end
			function frame:SetRotation(r) self.rotation = r end
			function frame:SetCamDistanceScale(s) self.cam = s end
		end
		return frame
	end
end

function FX.Reset(withModel)
	ResetWorld()
	_G.CreateFrame = FX.savedCreateFrame
	if withModel then FX.InstallModel() end
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.companionAnimTest = nil, nil, nil, nil
	NS.companionCrumbsAt, NS.companionZzzAt, NS.companionEating = nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.CompanionIsHappy = function() return false end
	NS:CompanionData().tutoDone = true
	NS:CompanionData().animOff = nil
	NS:CompanionUpdateVisibility()
	return NS:EnsureCompanionFrame()
end
function FX.Done()
	_G.CreateFrame = FX.savedCreateFrame
	NS.CompanionIsHappy = FX.savedHappy
	ResetWorld()
end
-- position verticale du modèle (ou de la boussole) dans son cadre
function FX.Y(frame)
	local region = frame.usesFallback and frame.fallback or frame.model
	return region.lastPoint and region.lastPoint.y or 0
end
function FX.X(frame)
	local region = frame.usesFallback and frame.fallback or frame.model
	return region.lastPoint and region.lastPoint.x or 0
end
function FX.Particles(kind)
	local n = 0
	for _, p in ipairs(NS.companionFx and NS.companionFx.particles or {}) do
		if p.kind == kind and p.region:IsShown() then n = n + 1 end
	end
	return n
end

do
	Say("-- compagnon : effets")
	local S = Scenario("[FX] compagnon : effets")
	local frame = FX.Reset(true)
	S.ok("cadre visible avec modèle", frame:IsShown() and not frame.usesFallback)
	local rest = FX.Y(frame)

	S.ok("rebond lancé", NS:CompanionFx("bounce") == true)
	Mock:Advance(0.15)
	S.ok("rebond : il monte", FX.Y(frame) > rest + 5, FX.Y(frame))
	Mock:Advance(1)
	S.ok("rebond fini : de retour en place", FX.Y(frame) == rest, FX.Y(frame))

	NS:CompanionFx("shake")
	local xs = {}
	for _ = 1, 4 do Mock:Advance(0.05); xs[#xs + 1] = FX.X(frame) end
	local moved = false
	local baseX = (frame.modelBase or NS.COMPANION_MODEL_BASE).x   -- 3.1.0 : le médaillon forgé place le portrait au centre de l'anneau
	for _, x in ipairs(xs) do moved = moved or math.abs(x - baseX) > 0.5 end
	S.ok("tremblement : il bouge de côté", moved, table.concat(xs, ","))
	Mock:Advance(1)
	S.ok("tremblement fini : en place", FX.X(frame) == baseX, FX.X(frame))

	NS.CompanionIsHappy = function() return true end
	local ys = {}
	for _ = 1, 6 do Mock:Advance(0.4); ys[FX.Y(frame)] = true end
	local count = 0
	for _ in pairs(ys) do count = count + 1 end
	S.ok("heureux : il flotte doucement", count >= 3)
	NS.CompanionIsHappy = function() return false end
	Mock:Advance(0.1)
	S.ok("plus heureux : immobile", FX.Y(frame) == rest)

	NS:CompanionFx("hearts")
	S.done()
	S = Scenario("[FX] particules : cœurs, miettes réemployées")
	S.ok("cœurs : 4 roses", FX.Particles("hearts") == 4 and NS.companionFx.particles[1].region.vertex[1] == 1)
	local y0 = NS.companionFx.particles[1].region.lastPoint.y
	Mock:Advance(0.8)
	local p = NS.companionFx.particles[1]
	S.ok("cœurs : ils montent et pâlissent", p.region.lastPoint.y > y0 and p.region.alpha < 1 and p.region.alpha > 0)
	Mock:Advance(1)
	S.ok("cœurs : partis au bout de 1,6 s", FX.Particles("hearts") == 0 and #NS.companionFx.pool >= 4)
	NS:CompanionFx("crumbs")
	S.ok("miettes : régions réemployées", FX.Particles("crumbs") == 5 and #NS.companionFx.pool == 0)
	Mock:Advance(2)

	NS:CompanionFx("alert")
	S.done()
	S = Scenario("[FX] « ! », effet inconnu, cadre caché")
	S.ok("« ! » au-dessus de lui", frame.alert and frame.alert:IsShown())
	Mock:Advance(2.1)
	S.ok("« ! » disparaît après 2 s", not frame.alert:IsShown())
	S.ok("effet inconnu : rien", NS:CompanionFx("boum") == false)
	frame:Hide()
	S.ok("cadre caché : rien", NS:CompanionFx("bounce") == false)
	frame:Show()
	S.done()
end

do
	Say("-- compagnon : effets sur les moments")
	local S = Scenario("[FX] compagnon : effets sur les moments")
	local frame = FX.Reset(true)
	NS:CompanionPet()
	S.ok("caresse : des cœurs", FX.Particles("hearts") > 0)
	Mock:Advance(2)
	NS:CompanionOnLevel(12)
	S.ok("niveau : rebond", NS.companionFx.motion and NS.companionFx.motion.kind == "bounce")
	Mock:Advance(2)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	NS:CompanionSay("ADVICE_ELITE", { category = "advice", force = true, args = { "Ogre" } })
	S.ok("élite repéré : tremblement et « ! »", NS.companionFx.motion and NS.companionFx.motion.kind == "shake"
		and frame.alert:IsShown())
	Mock:Advance(3)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	NS:CompanionSay("GROUP_NO_HEALER", { category = "advice", force = true })
	S.ok("conseil : « ! » sans tremblement", frame.alert:IsShown() and not NS.companionFx.motion)
	Mock:Advance(3)
	NS:DB().companionChatter = 0
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	NS:CompanionSay("GROUP_NO_HEALER", { category = "advice" })
	S.ok("conseil tu (sourdine) : pas de « ! »", not frame.alert:IsShown())
	NS:DB().companionChatter = nil

	-- repas : miettes au début, puis toutes les 4 s
	local savedState = NS.CompanionAuraState
	local eating = true
	NS.CompanionAuraState = function() return eating, false, false end
	NS:CompanionCheckAuras()
	S.done()
	S = Scenario("[FX] repas : miettes toutes les 4 s ; sommeil : Zzz")
	S.ok("repas : des miettes", FX.Particles("crumbs") == 5)
	Mock:Advance(2)
	NS:CompanionCheckAuras()
	S.ok("miettes pas en rafale", FX.Particles("crumbs") == 0)
	Mock:Advance(2.5)
	NS:CompanionCheckAuras()
	S.ok("miettes de nouveau 4 s plus tard", FX.Particles("crumbs") == 5)
	eating = false
	Mock:Advance(5)
	NS:CompanionCheckAuras()
	S.ok("fin du repas : plus de miettes", FX.Particles("crumbs") == 0)
	NS.CompanionAuraState = savedState
	NS.companionEating = nil
	Mock:Advance(2)

	-- sommeil : des « Zzz » qui montent, toutes les 3 s
	NS:CompanionAnimate("sleep")
	Mock:Advance(0.1)
	S.ok("il dort : des Zzz", FX.Particles("zzz") == 2 and NS.companionFx.particles[1].region.text ~= nil)
	NS:CompanionAnimate("idle")
	Mock:Advance(3)
	S.ok("réveillé : plus de Zzz", FX.Particles("zzz") == 0)
	S.done()
end

do
	Say("-- compagnon : effets sans modèle (boussole)")
	local S = Scenario("[FX] compagnon : effets sans modèle (boussole)")
	local frame = FX.Reset(false)
	S.ok("repli boussole", frame.usesFallback == true)
	local rest = FX.Y(frame)
	NS:CompanionFx("bounce")
	Mock:Advance(0.15)
	S.ok("la boussole rebondit aussi", FX.Y(frame) > rest + 5 and frame.fallback.lastPoint.point == "TOP")
	Mock:Advance(1)
	S.done()
end

do
	Say("-- compagnon : animations par apparence")
	local S = Scenario("[FX] compagnon : animations par apparence")
	local frame = FX.Reset(true)
	local anims = NS.COMPANION_ANIMS
	NS:CompanionAnimate("dance", 3)
	S.ok("danse jouée par défaut", frame.model.anim == anims.dance)
	NS:CompanionAnimate()
	Mock:Output()
	Mock.output = {}
	NS:CompanionCommand("anim non dance")
	S.ok("/qc compagnon anim non dance : retenu", NS:CompanionAnimSupported("dance") == false
		and Mock:Output():find("dance", 1, true))
	NS:CompanionAnimate("dance", 3)
	S.ok("danse coupée : il reste immobile", frame.model.anim == anims.idle and frame.animation == "dance")
	S.ok("… mais la durée compte", NS.companionAnimUntil ~= nil)
	local data = NS:CompanionData()
	local before = data.appearance
	data.appearance = "autre"
	S.ok("autre apparence : danse jouée", NS:CompanionAnimSupported("dance") == true)
	data.appearance = before
	NS:CompanionCommand("anim oui dance")
	S.ok("/qc compagnon anim oui dance : de nouveau jouée", NS:CompanionAnimSupported("dance") == true)
	Mock.output = {}
	NS:CompanionCommand("anim non idle")
	S.ok("le repos ne se coupe pas", NS:CompanionAnimSupported("idle") == true
		and Mock:Output():find("inconnue", 1, true))
	NS:CompanionCommand("anim non boum")
	S.ok("animation inconnue : liste des noms", Mock:Output():find("walk", 1, true) ~= nil)

	-- défilé : chaque animation 3 s, même celles coupées
	NS:CompanionCommand("anim non run")
	Mock.output = {}
	NS:CompanionCommand("anim")
	local order = NS.COMPANION_ANIM_ORDER
	S.done()
	S = Scenario("[FX] défilé /qc compagnon anim, textes fr/en, module coupé")
	S.ok("défilé : première animation", frame.model.anim == anims[order[1]] and Mock:Output():find("1/" .. #order, 1, true))
	local seen = { [frame.model.anim] = true }
	for _ = 2, #order do
		Mock:Advance(NS.COMPANION_ANIM_STEP)
		seen[frame.model.anim] = true
	end
	S.ok("défilé : la course coupée est montrée aussi", seen[anims.run] == true and seen[anims.sleep] == true)
	Mock:Advance(NS.COMPANION_ANIM_STEP)
	S.ok("fin du défilé : la liste des coupées", NS.companionAnimTest == nil
		and Mock:Output():find("run", 1, true) and frame.model.anim == anims.idle, Mock:Output())

	local fx = NS.COMPANION_FX_STRINGS
	local missing = {}
	for key in pairs(fx.fr) do if not fx.en[key] then missing[#missing + 1] = key end end
	for key in pairs(fx.en) do if not fx.fr[key] then missing[#missing + 1] = key end end
	S.ok("textes en français et en anglais", #missing == 0, table.concat(missing, ", "))
	NS:DB().companionEnabled = false
	Mock.output = {}
	NS:CompanionCommand("anim")
	S.ok("module coupé : pas de défilé", NS.companionAnimTest == nil)
	NS:DB().companionEnabled = nil
	FX.Done()
	S.done()
end
