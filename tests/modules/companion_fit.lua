-- Compagnon : cadrage automatique (3.1.0). La taille réelle de chaque
-- apparence (DisplaySizes_Forever.lua, tables du client), l'échelle qui ramène
-- toute créature à la même taille, la distance commune ; l'apparence apprise,
-- ou lue sur le modèle chargé ; les surcharges par espèce et les mascottes
-- inchangées ; l'interrupteur de réglage ; rien n'est demandé au joueur.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local FIT = NS.COMPANION_FIT
local function Near(a, b, tol) return a ~= nil and b ~= nil and math.abs(a - b) <= (tol or 0.06) * math.abs(b) end
-- un modèle factice : note ce que le cadrage lui pose
local function Model(display)
	local m = { calls = {}, display = display }
	function m:SetModelScale(v) self.scale = v end
	function m:SetCamDistanceScale(v) self.cam = v end
	function m:SetPortraitZoom(v) self.zoom = v end
	function m:SetPosition() end
	function m:SetDisplayInfo(id) self.display = id; return true end
	function m:SetCreature(npc) self.npc = npc; return true end
	function m:GetDisplayInfo() return self.display or 0 end
	function m:Show() self.shown = true end
	function m:Hide() self.shown = false end
	function m:HookScript() end
	return m
end

do
	Say("-- cadrage automatique : la table des tailles")
	Check("[FIT] table chargée : une chaîne compacte (moins de 40 Ko), jamais mise en table",
		type(NS.DISPLAY_SIZES) == "string" and #NS.DISPLAY_SIZES > 20000 and #NS.DISPLAY_SIZES < 40000, #(NS.DISPLAY_SIZES or ""))
	-- valeurs des tables du client : Grand-père Hiver 1,785 ; Renne de l'Hiver 0,558 ;
	-- le même renne à l'échelle 1 : 2,792 ; un rat 0,502 ; Onyxia 39,1
	Check("[FIT] tailles lues (à un palier près) : Grand-père Hiver, les deux rennes, un rat, Onyxia",
		Near(NS:DisplaySize(13369), 1.785) and Near(NS:DisplaySize(15904), 0.558) and Near(NS:DisplaySize(15902), 2.792)
		and Near(NS:DisplaySize(134), 0.502) and Near(NS:DisplaySize(8570), 39.131), NS:DisplaySize(13369))
	Check("[FIT] première et dernière apparence lues ; inconnue, nulle ou invalide : rien",
		NS:DisplaySize(13) ~= nil and NS:DisplaySize(149301) ~= nil and NS:DisplaySize(5) == nil and NS:DisplaySize(149300) == nil and NS:DisplaySize(999999) == nil
		and NS:DisplaySize(0) == nil and NS:DisplaySize("x") == nil)
	local a = NS:DisplaySize(607)
	Check("[FIT] relue : même valeur (gardée, bornée)", NS:DisplaySize(607) == a and NS.DISPLAY_SIZE_CACHE_MAX <= 512)
end

do
	Say("-- cadrage automatique : la même taille pour toutes")
	-- taille à l'écran ∝ taille réelle × échelle / distance : la même pour toutes
	local function Apparent(display) return NS:DisplaySize(display) * NS:CompanionFitScale(display) end
	Check("[FIT] un rat, un loup, un renne, un géant : ramenés à la taille de référence",
		Near(Apparent(134), FIT.ref, 0.001) and Near(Apparent(607), FIT.ref, 0.001) and Near(Apparent(15902), FIT.ref, 0.001)
		and Near(Apparent(12110), FIT.ref, 0.001), Apparent(134))
	Check("[FIT] la référence réglée en jeu ne bouge pas : Grand-père Hiver à l'échelle 1 (à un palier près)",
		Near(NS:CompanionFitScale(13369), 1, 0.06), NS:CompanionFitScale(13369))
	Check("[FIT] le petit renne réglé en jeu à 0,6 : même cadrage que 1,5 avec son échelle",
		Near(FIT.cam / NS:CompanionFitScale(15904), 0.6, 0.3), FIT.cam / NS:CompanionFitScale(15904))
	Check("[FIT] échelle bornée ; apparence inconnue : pas d'échelle", NS:CompanionFitScale(8570) >= FIT.min
		and NS:CompanionFitScale(134) <= FIT.max and NS:CompanionFitScale(999999) == nil)
end

do
	Say("-- cadrage automatique : le modèle")
	ResetWorld()
	local m = Model()
	NS.ShowModel(m, { npc = 3100, cam = 2.4, scale = 1.1, fit = true, fitCam = 1.32, fitDisplay = 12110 }, "companion")
	Check("[FIT] apparence apprise : échelle de la taille (fois la taille du spécimen), distance commune",
		Near(m.scale, 1.1 * NS:CompanionFitScale(12110), 0.001) and m.cam == 1.32 and m.fitDisplay == 12110, m.scale)
	local late = Model()
	NS.ShowModel(late, { npc = 3101, cam = 1.5, fit = true, fitCam = 1.32 }, "companion")
	local before = late.cam
	late.display = 134
	late.framing(late)   -- (OnModelLoaded : le client connaît maintenant l'apparence)
	Check("[FIT] apparence pas encore connue : distance par type ; une fois chargée, lue sur le modèle",
		before == 1.5 and late.cam == 1.32 and Near(late.scale, NS:CompanionFitScale(134), 0.001), before)
	local plain = Model()
	NS.ShowModel(plain, { display = 134, cam = 1, zoom = 0.55, scale = 0.8 }, "companion")
	Check("[FIT] mascotte (sans cadrage automatique) : échelle et distance inchangées", plain.scale == 0.8 and plain.cam == 1
		and plain.fitScale == nil)
	local _, _, _, fitGfw = NS:CompanionModelCam({ npc = 13444 }, "pied")
	local camWolf, _, _, fitWolf = NS:CompanionModelCam({ npc = 3100, type = "Bête" }, "pied")
	Check("[FIT] espèce avec surcharge réglée en jeu : pas de cadrage automatique ; les autres : oui",
		fitGfw == false and fitWolf == true and camWolf == NS.COMPANION_MODEL_TYPE_CAM["Bête"])
	Check("[FIT] le réglage Cadrage rapproche toujours (portrait < buste < pied)",
		NS:CompanionFitCam("portrait") < NS:CompanionFitCam("buste") and NS:CompanionFitCam("buste") < NS:CompanionFitCam("pied")
		and NS:CompanionFitCam("pied") == FIT.cam)
	NS.companionFitOff = true
	local off = Model()
	NS.ShowModel(off, { npc = 3100, cam = 2.4, fit = true, fitCam = 1.32, fitDisplay = 12110 }, "companion")
	NS.companionFitOff = nil
	Check("[FIT] /qc compagnon cadrage off : la distance par type, comme avant", off.cam == 2.4 and off.scale == nil)
end
