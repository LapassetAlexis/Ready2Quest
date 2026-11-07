-- Compagnon : le bandeau « Capture possible » enrichi (QuestCompanion 2.2.0) :
-- ce qu'on a déjà de l'espèce (étoiles), la chance, Ignorer, Sourdine (N
-- minutes), les sons de capture (kits du client, réglage, sourdine) et le
-- cadrage du compagnon dans son cadre (portrait / buste / en pied).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local FI = { saved = {}, random = math.random, units = {}, sounds = {}, savedCreateFrame = _G.CreateFrame }
-- un faux modèle 3D qui retient ce qu'on lui demande (comme companion_fx.lua)
function FI.InstallModel()
	_G.CreateFrame = function(kind, ...)
		local frame = FI.savedCreateFrame(kind, ...)
		if kind == "PlayerModel" or kind == "Model" then
			function frame:SetDisplayInfo(id) self.display = id end
			function frame:SetCreature(id) self.creature = id end
			function frame:SetAnimation(id) self.anim = id end
			function frame:SetModelScale(s) self.modelScale = s end
			function frame:SetRotation(r) self.rotation = r end
			function frame:SetCamDistanceScale(s) self.cam = s end
			function frame:SetPortraitZoom(z) self.portrait = z end
		end
		return frame
	end
end
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound" }
for _, name in ipairs(GLOBALS) do FI.saved[name] = rawget(_G, name) end
FI.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function FI.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function FI.Install()
	local w = FI
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function() return 20 end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
end
function FI.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
		"captureQueueList", "captureNetButton", "captureToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache = nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	FI.units, FI.combat, FI.sounds = {}, false, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	FI.Install()
	NS.SHINY_CHANCE = 0
	math.random = FI.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = false
	NS:DB().captureMuteUntil = nil
	NS:DB().companionCaptureSound = true
	NS:DB().companionCaptureToast = true
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
end
function FI.Roll(value)
	math.random = function(a, b)
		if a and b then return FI.random(a, b) end
		if a then return FI.random(a) end
		return value
	end
end
function FI.SeeKill(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or FI.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	FI.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
	return fields.guid
end
function FI.Settle()
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
end
local function Has(list, id) for _, v in ipairs(list) do if v == id then return true end end return false end

-- 1. Le bandeau dit ce qu'on a déjà, et la chance -------------------------------------------
do
	Say("-- filet : bandeau enrichi")
	FI.Reset()
	FI.SeeKill(5100, { name = "Raptor" })
	local toast = NS.captureToast
	Check("[FI] espèce jamais capturée : « Jamais capturée · 30 % de chance », en doré", toast and toast:IsShown()
		and toast.info:GetText() == NS.L.CAPTURE_TOAST_NEW .. " · " .. NS:F("CAPTURE_TOAST_CHANCE", 30)
		and toast.info.textColor[1] == NS.Theme.GOLD[1], toast and toast.info:GetText())
	Check("[FI] bandeau plus grand : boutons Ignorer et Sourdine, par-dessus le clic", toast.ignore and toast.mute
		and toast.ignore:IsShown() and toast.mute:IsShown() and toast.height >= 80)
	-- déjà capturée, 2 étoiles : le bandeau le dit, et « peut faire mieux »
	FI.Roll(0)
	NS:CaptureThrow()
	FI.Settle()
	NS:CaptureData().creatures[5100].stars = 2
	NS:CaptureData().serial = (NS:CaptureData().serial or 0) + 1
	FI.SeeKill(5100, { name = "Raptor", spawn = "0000000002" })
	Check("[FI] déjà capturée : ses étoiles et « peut faire mieux »", toast:IsShown()
		and toast.info:GetText():find(NS.L.CAPTURE_TOAST_BETTER, 1, true) ~= nil
		and toast.info:GetText():find("Déjà capturée", 1, true) ~= nil
		and toast.info:GetText():find(NS:CaptureStarsText(2, 10), 1, true) ~= nil, toast.info:GetText())
	-- brillante déjà capturée aussi : les deux versions
	NS:CaptureData().creatures[5100].shiny, NS:CaptureData().creatures[5100].shinyStars = true, 1
	NS:CaptureToastShow()
	Check("[FI] … et la brillante possédée", toast.info:GetText():find("brillante", 1, true) ~= nil, toast.info:GetText())
end

-- 2. Ignorer ---------------------------------------------------------------------------------------
do
	Say("-- filet : ignorer depuis le bandeau")
	FI.Reset()
	FI.SeeKill(5200, { name = "Loup A" })
	FI.SeeKill(5201, { name = "Loup B" })
	local toast = NS.captureToast
	Check("[FI] deux candidats : le bandeau montre le premier", toast.text:GetText() == "Loup A" and #NS:CaptureQueue() == 2)
	toast.ignore:Click()
	Check("[FI] Ignorer : le premier sort du filet, le bandeau passe au suivant", #NS:CaptureQueue() == 1
		and toast:IsShown() and toast.text:GetText() == "Loup B", toast.text:GetText())
	toast.ignore:Click()
	Check("[FI] Ignorer le dernier : filet vide, bandeau effacé", #NS:CaptureQueue() == 0 and not toast:IsShown()
		and not NS.captureNetButton:IsShown())
end

-- 3. Sourdine ----------------------------------------------------------------------------------------
do
	Say("-- filet : sourdine")
	FI.Reset()
	FI.SeeKill(5300, { name = "Kodo" })
	local toast = NS.captureToast
	toast.mute:Click()
	Check("[FI] Sourdine : la rangée des durées (5, 15, 30 min, 1 h) et Annuler", toast.muteRow:IsShown()
		and #toast.muteRow.choices == 4 and toast.muteRow.choices[4].minutes == 60
		and toast.muteRow.choices[4].text:GetText() == NS.L.CAPTURE_TOAST_MUTE_HOUR)
	do
		-- 2.3.1 : les durées et Annuler tiennent dans la largeur du bandeau, sans se chevaucher
		local total = toast.muteRow.cancel:GetWidth() + 8
		for _, c in ipairs(toast.muteRow.choices) do total = total + c:GetWidth() + 4 end
		Check("[FI] rangée de sourdine : tout tient dans le bandeau", total <= toast:GetWidth() - 12, total)
		-- l'aide a sa propre ligne, au-dessus de la rangée des boutons
		local _, _, _, _, hintY = toast.hint:GetPoint(1)
		Check("[FI] aide sur sa ligne, au-dessus des boutons", toast.hint:GetWidth() > 200
			and type(hintY) == "number" and hintY < -50 and hintY > -(toast:GetHeight() - 30), hintY)
	end
	toast.muteRow.cancel:Click()
	Check("[FI] Annuler : la rangée se cache", not toast.muteRow:IsShown())
	toast.mute:Click()
	local printed = {}
	local oldPrint = NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = msg end
	toast.muteRow.choices[2]:Click()
	NS.Print = oldPrint
	FI.sounds = {}
	Check("[FI] 15 min : sourdine posée, bandeau effacé, annoncé", NS:DB().captureMuteUntil ~= nil
		and math.abs(NS:CaptureMuted() - 15 * 60) <= 1 and not toast:IsShown() and printed[1] and printed[1]:find("15 min", 1, true))
	FI.SeeKill(5301, { name = "Kodo B" })
	Check("[FI] en sourdine : pas de bandeau, mais le filet", not toast:IsShown() and NS.captureNetButton:IsShown())
	Check("[FI] en sourdine : pas de son", #FI.sounds == 0, #FI.sounds)
	Check("[FI] texte de durée", NS:CaptureMuteText(90) == "2 min" and NS:CaptureMuteText(3600) == "1 h"
		and NS:CaptureMuteText(3900) == "1 h 05" and NS:CaptureMuteText(40) == "40 s")
	Mock:Advance(16 * 60)
	Check("[FI] au bout du temps : plus de sourdine", NS:CaptureMuted() == nil)
	FI.SeeKill(5302, { name = "Kodo C" })
	Check("[FI] … et le bandeau revient", toast:IsShown() and toast.text:GetText() == "Kodo C")
	-- /qc filet sourdine [min|off]
	NS:CaptureQueueClear()
	NS.EXTRA_COMMANDS["filet"](NS, "sourdine 5")
	Check("[FI] /qc filet sourdine 5", NS:CaptureMuted() and NS:CaptureMuted() <= 5 * 60)
	NS.EXTRA_COMMANDS["filet"](NS, "sourdine off")
	Check("[FI] /qc filet sourdine off", NS:CaptureMuted() == nil)
	NS.EXTRA_COMMANDS["filet"](NS, "sourdine")
	Check("[FI] /qc filet sourdine : 15 min par défaut", NS:CaptureMuted() and NS:CaptureMuted() > 14 * 60)
	NS:CaptureUnmute()
end

-- 4. Sons ---------------------------------------------------------------------------------------------
do
	Say("-- filet : sons de capture")
	FI.Reset()
	FI.SeeKill(5400, { name = "Ours" })
	Check("[FI] capture possible : le carillon (piège prêt des mascottes)", Has(FI.sounds, NS.CAPTURE_SOUNDS.ready), table.concat(FI.sounds, ","))
	NS:CaptureToastShow()
	Check("[FI] bandeau remis à jour : pas de second carillon", #FI.sounds == 1)
	FI.Roll(0)
	NS:CaptureThrow()
	Check("[FI] lancer : son du lancer", Has(FI.sounds, NS.CAPTURE_SOUNDS.throw))
	FI.Settle()
	Check("[FI] capturé : la petite musique de récompense", Has(FI.sounds, NS.CAPTURE_SOUNDS.ok) and not Has(FI.sounds, NS.CAPTURE_SOUNDS.fail))
	FI.sounds = {}
	FI.Roll(0.99)
	FI.SeeKill(5401, { name = "Ours B" })
	NS:CaptureThrow()
	FI.Settle()
	Check("[FI] échappé : son d'échec", Has(FI.sounds, NS.CAPTURE_SOUNDS.fail) and not Has(FI.sounds, NS.CAPTURE_SOUNDS.ok))
	-- brillante : fanfare
	FI.sounds = {}
	NS.SHINY_CHANCE = 1
	FI.Roll(0)
	FI.SeeKill(5402, { name = "Ours doré" })
	NS.SHINY_CHANCE = 0
	NS:CaptureThrow()
	FI.Settle()
	Check("[FI] brillante capturée : la fanfare", Has(FI.sounds, NS.CAPTURE_SOUNDS.shiny))
	-- réglage coupé : silence
	FI.sounds = {}
	NS:DB().companionCaptureSound = false
	FI.Roll(0)
	FI.SeeKill(5403, { name = "Ours C" })
	NS:CaptureThrow()
	FI.Settle()
	Check("[FI] réglage « Sons de capture » coupé : silence", #FI.sounds == 0, #FI.sounds)
	NS:DB().companionCaptureSound = true
	local row
	for _, def in ipairs(NS.DAILY_OPTION_ROWS) do if def.key == "companionCaptureSound" then row = def end end
	Check("[FI] réglage « Sons de capture » dans la page Au jour le jour", row and row.kind == "bool")
	Check("[FI] sans PlaySound (client) : rien ne casse", (function() _G.PlaySound = nil; local ok = NS:CapturePlaySound("ok"); FI.Install(); return ok == false end)())
	-- la scène ne joue plus ses propres kits (plus de doublon)
	FI.sounds = {}
	NS:DB().companionCaptureAnim = true
	FI.Roll(0)
	FI.SeeKill(5404, { name = "Ours D" })
	NS:CaptureThrow()
	FI.Settle()
	local okCount = 0
	for _, id in ipairs(FI.sounds) do if id == NS.CAPTURE_SOUNDS.ok then okCount = okCount + 1 end end
	Check("[FI] scène animée : une seule musique de réussite", okCount == 1, okCount)
	NS:DB().companionCaptureAnim = false
end

-- 5. Cadrage du compagnon --------------------------------------------------------------------------------
do
	Say("-- compagnon : cadrage")
	FI.InstallModel()
	FI.Reset()
	local frame = NS:EnsureCompanionFrame()
	local model = frame and frame.model
	Check("[FI] cadrage par défaut : portrait", NS:CompanionFraming() == "portrait")
	if model then
		NS:CompanionApplyModel()
		Check("[FI] portrait : caméra « portrait » à fond, distance 1, échelle du stade gardée", model.portrait == 1 and model.cam == 1
			and model.modelScale == NS.COMPANION_STAGES[NS:CompanionStage()].scale)
		NS:CompanionSetFraming("buste")
		Check("[FI] buste : caméra à mi-hauteur", model.portrait == NS.COMPANION_FRAMING_ZOOM.buste and model.cam == 1)
		NS:CompanionSetFraming("pied")
		Check("[FI] en pied : comme avant (pas de zoom, caméra reculée)", model.portrait == 0 and model.cam == 1.6)
		Check("[FI] cadrage inconnu : refusé", NS:CompanionSetFraming("plafond") == nil and NS:CompanionFraming() == "pied")
		NS:CompanionSetFraming("portrait")
	else
		Check("[FI] un modèle pour le test", false)
	end
	_G.CreateFrame = FI.savedCreateFrame
	local choices = NS:CompanionFramingChoices()
	Check("[FI] trois cadrages proposés, libellés courts", #choices == 3 and choices[1].value == "portrait"
		and #NS.L.COMP_FRAMING_portrait <= 24 and NS.L.COMP_FRAMING_pied == "En pied")
	local row
	for _, def in ipairs(NS.COMPANION_OPTION_ROWS or {}) do if def.key == "companionFraming" then row = def end end
	Check("[FI] réglage « Cadrage » dans la page du compagnon", row ~= nil or (function()
		for _, page in ipairs(NS.OPTION_PAGES or {}) do
			for _, def in ipairs(page.rows or {}) do if def.key == "companionFraming" then return true end end
		end
		return false
	end)())
end

-- 6. Textes ----------------------------------------------------------------------------------------------
do
	local missing = {}
	for _, key in ipairs({ "CAPTURE_TOAST_NEW", "CAPTURE_TOAST_OWNED", "CAPTURE_TOAST_IGNORE", "CAPTURE_TOAST_MUTE",
		"CAPTURE_MSG_MUTED", "OPT_DAILY_CAPTURE_SOUND" }) do
		if not (NS.CAPTURE_QUEUE_STRINGS.fr[key] and NS.CAPTURE_QUEUE_STRINGS.en[key]) then missing[#missing + 1] = key end
	end
	Check("[FI] textes fr et en", #missing == 0, table.concat(missing, ", "))
end

-- 7. Filet lisible sur sol clair (2.3.1) ----------------------------------------------------------------
do
	Say("-- filet : contraste")
	FI.Reset()
	FI.SeeKill(5400, { name = "Hyène" })
	local net = NS.captureNetButton
	local function near(v, c) return v and math.abs((v[1] or -1) - c[1]) < 0.01 and math.abs((v[2] or -1) - c[2]) < 0.01
		and math.abs((v[3] or -1) - c[3]) < 0.01 end
	Check("[FI] filet : plaque sombre opaque et ombre portée", net.plate and net.shadow
		and (net.plate.alpha or net.plate.vertex and net.plate.vertex[4] or 1) > 0.9, net.plate and net.plate.alpha)
	Check("[FI] filet : liseré doré dedans, noir dehors", net.ring and near(net.ring.top.vertex, NS.Theme.GOLD)
		and near(net.border.top.vertex, { 0, 0, 0 }))
	Check("[FI] filet : compteur en pastille dorée", near(net.countBack.vertex, NS.Theme.GOLD) and net.count:GetText() == "1")
end

for _, name in ipairs(GLOBALS) do _G[name] = FI.saved[name] end
math.random = FI.random
NS.SHINY_CHANCE = FI.savedShiny
NS:DB().captureMuteUntil = nil
ResetWorld()
