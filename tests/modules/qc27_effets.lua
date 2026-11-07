-- Compagnon : les effets du style Azeroth (QuestCompanion 2.7.0, AzerothStyle.lua) :
-- bulle façon « Talking Head » (parchemin, nom en petites capitales, texte brun),
-- lueur ronde quand il parle (plus de liseré rectangulaire en Azeroth, toujours là
-- en Sobre), éclats d'une brillante, évolution / niveau (volutes, texte, ligne de
-- lumière, poussière, bulle qui monte d'un cran), ailes et éclat des grandes
-- récompenses (ns:AzerothRewardFX), atlas manquant (effet sauté, sans erreur),
-- changement de style à chaud.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local FXT = { saved = {}, units = {}, savedHappy = NS.CompanionIsHappy }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitLevel", "SetRaidTarget",
	"GetRaidTargetIndex", "InCombatLockdown", "UnitAffectingCombat", "C_Texture" }
for _, name in ipairs(GLOBALS) do FXT.saved[name] = rawget(_G, name) end
local A = NS.AZEROTH_FX_ATLAS
local C = NS.AZEROTH_FX

function FXT.Reset(atlas)
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.companionRT, NS.companionSession, NS.companionFx, NS.notifyState, NS.shinyState, NS.azFx = nil, nil, nil, nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = FXT.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitLevel = function() return 20 end
	_G.SetRaidTarget = function() end
	_G.GetRaidTargetIndex = function() return nil end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(atlas or true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = "azeroth"
	NS:CompanionData().tutoDone = true
	NS.CompanionIsHappy = FXT.savedHappy
	NS:CompanionUpdateVisibility()
	return NS:EnsureCompanionFrame()
end
local function Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
local function Speak()
	Quiet()
	return NS:CompanionSay("EAT", { force = true })
end
-- fait tourner les horloges (Notify : la lueur ; AzerothStyle : les effets)
local function Run(seconds, step)
	step = step or 0.1
	local t = 0
	while t < seconds - 1e-6 do Mock:Advance(step); t = t + step end
end
local function Edges(frame)
	for _, tex in ipairs(type(frame.glow) == "table" and frame.glow or {}) do if tex:IsShown() then return true end end
	return false
end

-- 1. La bulle Talking Head ---------------------------------------------------------------------------
do
	Say("-- effets azeroth : bulle façon Talking Head")
	local frame = FXT.Reset()
	Check("[FX] cadre du compagnon en Azeroth", frame and frame.uiStyle == "azeroth")
	Check("[FX] il parle", Speak() == true)
	local bubble = NS.companionBubble
	local skin = bubble and bubble.azTalk
	-- 2.8.2 : le parchemin des hauts faits (130661) par son fichier, recadré
	Check("[FX] bulle : parchemin des hauts faits", skin and bubble.azBubble and skin.bg.texture == 130661
		and skin.bg.texCoord and skin.bg:IsShown())
	Check("[FX] bulle : texte brun foncé, sans ombre", skin and skin.text:GetText() == NS.companionBubbleText
		and skin.text.textColor[1] < 0.3 and skin.text.textColor[3] < 0.1 and skin.text.shadow and skin.text.shadow[4] == 0)
	Check("[FX] bulle : le nom du compagnon en capitales en haut", skin and skin.name:GetText() == NS.AzerothUpper(NS:CompanionName())
		and skin.name:IsShown() and select(5, skin.name:GetPoint(1)) == C.bubbleNameY)
	Check("[FX] bulle : l'habit Sobre masqué (fond, filet, pointe, texte)", bubble.bg.mockHidden and bubble.rule.mockHidden
		and bubble.tail.mockHidden and bubble.text.mockHidden and bubble.border.top.mockHidden)
	Check("[FX] bulle : largeur Talking Head, hauteur au moins le minimum", bubble:GetWidth() == C.bubbleW
		and bubble:GetHeight() >= C.bubbleMin)
	local short = bubble:GetHeight()
	bubble:SetText(string.rep("Un très long bavardage du compagnon sur la route. ", 6))
	Check("[FX] bulle : la hauteur suit le texte", bubble:GetHeight() > short, tostring(bubble:GetHeight()))
	Check("[FX] bulle : ne prend pas la souris, même ancre au-dessus du cadre", not bubble.mouseEnabled
		and select(2, bubble:GetPoint(1)) == frame and select(3, bubble:GetPoint(1)) == "TOP")
	bubble:SetText("Court.", 28)
	Check("[FX] bulle : la rangée de boutons du tutoriel compte", bubble:GetHeight() >= 30 + 14 + 18 + 28)
	Check("[FX] bulle : un reflet passe sur le parchemin", skin.sheen and (Run(0.3) or true) and skin.sheen:IsShown())
	Run(1)
	Check("[FX] bulle : le reflet s'en va", not skin.sheen:IsShown())
end

-- 2. La lueur ronde quand il parle ------------------------------------------------------------------
do
	Say("-- effets azeroth : lueur ronde")
	local frame = FXT.Reset()
	Speak()
	Run(0.5)
	local glow = frame.azGlow
	Check("[FX] il parle : lueur ronde dorée derrière l'anneau", glow and glow:IsShown() and glow.atlas == A.circle
		and glow.blendMode == "ADD" and glow.vertex[3] < 0.5 and glow.drawLayer == "BACKGROUND")
	Check("[FX] … centrée sur l'anneau", select(2, glow:GetPoint(1)) == frame and select(5, glow:GetPoint(1)) == NS.AZEROTH_RING.y)
	Check("[FX] Azeroth : pas de liseré rectangulaire", not Edges(frame))
	local a1, s1 = glow.alpha, glow:GetWidth()
	Run(1.1)
	Check("[FX] … elle respire (éclat et taille)", math.abs(glow.alpha - a1) > 0.05 and glow:GetWidth() ~= s1)
	NS:CompanionHideBubble()
	Run(1)
	Check("[FX] la bulle finie : la lueur s'éteint", not glow:IsShown())
	-- Sobre : le liseré revient, pas de lueur ronde
	NS:SetUIStyle("sobre")
	Speak()
	Run(0.3)
	Check("[FX] Sobre : le liseré pulse toujours", Edges(frame) and not glow:IsShown())
	Check("[FX] Sobre : la bulle d'avant revient", not NS.companionBubble.azBubble and NS.companionBubble.bg:IsShown()
		and NS.companionBubble.text:IsShown() and not NS.companionBubble.azTalk.bg:IsShown())
	-- à chaud : retour en Azeroth, bulle affichée rhabillée, liseré éteint
	NS:SetUIStyle("azeroth")
	Run(0.3)
	Check("[FX] retour en Azeroth à chaud : bulle rhabillée, lueur ronde, liseré éteint", NS.companionBubble.azBubble
		and NS.companionBubble.azTalk.text:GetText() == NS.companionBubbleText and glow:IsShown() and not Edges(frame))
	NS:CompanionHideBubble()
	Run(1)
end

-- 3. Brillante repérée ------------------------------------------------------------------------------
do
	Say("-- effets azeroth : brillante repérée")
	local frame = FXT.Reset()
	FXT.units.target = { name = "Raptor brillant" }
	local live = NS:ShinySpot("target", "Creature-0-1-1-1-7100-0000AA", { zoneID = 1413, npcID = 7100 }, { name = "Raptor brillant" })
	Check("[FX] brillante repérée : l'effet part", live ~= nil and NS.azFx and NS.azFx.shinyUntil ~= nil)
	Run(1.5)
	local sparks = frame.azSparks
	local shown = 0
	for _, tex in ipairs(sparks or {}) do if tex:IsShown() and (tex.alpha or 0) > 0 then shown = shown + 1 end end
	Check("[FX] … 4 éclats d'étoile dorés autour du cadre", sparks and #sparks == 4 and sparks[1].atlas == A.star
		and sparks[1].blendMode == "ADD" and shown >= 2, tostring(shown))
	Check("[FX] … décalés dans le temps", sparks and sparks[1].alpha ~= sparks[3].alpha)
	Check("[FX] … sur un calque sans souris, au-dessus du cadre", frame.azFxLayer and not frame.azFxLayer.mouseEnabled
		and frame.azFxLayer:GetFrameLevel() > frame:GetFrameLevel())
	Check("[FX] … la lueur bat plus vite", frame.azGlow and frame.azGlow:IsShown() and select(2, NS:AzerothGlowEnvelope(NS.Now())))
	NS:CompanionHideBubble()
	Run(C.shinyTime + 1)
	local any = false
	for _, tex in ipairs(sparks) do if tex:IsShown() then any = true end end
	Check("[FX] … puis tout s'éteint", not any and not frame.azGlow:IsShown() and NS.azFx.sparkAt == nil)
	Check("[FX] horloge des effets retirée au repos", NS.azFxDriver and not NS.azFxDriver.running
		and NS.azFxDriver.scripts.OnUpdate == nil)
end

-- 4. Évolution et niveau -----------------------------------------------------------------------------
do
	Say("-- effets azeroth : évolution et niveau")
	local frame = FXT.Reset()
	NS:CompanionData().stage = 2
	NS.CompanionIsHappy = function() return true end
	Quiet()
	local evolved = NS:CompanionCheckStage(20, true)
	local parts = frame.azLevel
	local group = parts and parts.group
	Check("[FX] évolution : l'effet part", evolved == true and NS.azFx.level and NS.azFx.level.kind == "evolve")
	Check("[FX] … « Aguerri ! » entre deux volutes", group and group:IsShown() and group.text:GetText() == "Aguerri !"
		and group.left.atlas == A.filigree and group.right.atlas == A.filigree)
	Check("[FX] … volutes collées au texte, de part et d'autre, centrées", group and select(2, group.left:GetPoint(1)) == group.text
		and select(3, group.left:GetPoint(1)) == "LEFT" and select(4, group.left:GetPoint(1)) == -C.filigreeGap
		and select(5, group.left:GetPoint(1)) == 0 and select(2, group.right:GetPoint(1)) == group.text
		and select(4, group.right:GetPoint(1)) == C.filigreeGap and group.left:GetWidth() == C.filigreeW)
	Check("[FX] … un seul groupe compact au-dessus du cadre, largeur qui suit le texte", group:GetHeight() <= 30
		and select(2, group:GetPoint(1)) == frame and select(3, group:GetPoint(1)) == "TOP"
		and group:GetWidth() == math.ceil(group.text:GetStringWidth()) + 2 * (C.filigreeW + C.filigreeGap))
	Check("[FX] … ne prend pas la souris", not group.mouseEnabled and not frame.azFxLayer.mouseEnabled)
	Run(0.6)
	Check("[FX] … lueur autour du portrait, ligne de lumière, poussière dorée", parts.iglow:IsShown()
		and parts.iglow.atlas == "AftLevelup-IconGlow" and group.line.atlas == A.line and (group.line.alpha or 0) > 0
		and parts.dots[1]:IsShown() and group.cloud.atlas == A.cloud)
	local bubble = NS.companionBubble
	Check("[FX] … la bulle d'évolution monte au-dessus du groupe", bubble:IsShown() and bubble.azLift
		and select(5, bubble:GetPoint(1)) == bubble.azLift[5] + C.groupLift and C.groupLift >= C.groupY + C.groupH - 4)
	local y1 = select(5, parts.dots[1]:GetPoint(1))
	Run(0.4)
	Check("[FX] … la poussière monte", select(5, parts.dots[1]:GetPoint(1)) > y1)
	Run(C.levelTime)
	Check("[FX] … puis tout s'efface, la bulle revient à sa place", not group:IsShown() and not parts.iglow:IsShown()
		and not bubble.azLift and select(5, bubble:GetPoint(1)) == 12)
	-- niveau sans évolution
	NS:CompanionHideBubble()
	Quiet()
	NS:CompanionOnLevel(21)
	Check("[FX] niveau : « Niveau 21 ! »", group:IsShown() and group.text:GetText() == "Niveau 21 !" and NS.azFx.level.kind == "level")
	Run(C.levelTime + 0.5)
	-- Sobre : rien
	NS:SetUIStyle("sobre")
	NS:CompanionOnLevel(22)
	Check("[FX] Sobre : pas d'effet de niveau", not group:IsShown() and NS.azFx.level == nil)
	NS:SetUIStyle("azeroth")
	-- changement de style pendant l'effet : tout s'arrête
	NS:AzerothLevelFX("Test !")
	NS:SetUIStyle("sobre")
	Check("[FX] style changé pendant l'effet : arrêté net", not group:IsShown() and NS.azFx.level == nil)
	NS:SetUIStyle("azeroth")
	NS.CompanionIsHappy = FXT.savedHappy
end

-- 5. Grandes récompenses ------------------------------------------------------------------------------
do
	Say("-- effets azeroth : ailes des grandes récompenses")
	FXT.Reset()
	local banner = NS:EnsureJournalToast()
	banner:Show()
	Check("[FX] API : ns:AzerothRewardFX part sur un bandeau", NS:AzerothRewardFX(banner) == true)
	local fx = banner.azReward
	Run(0.8)
	Check("[FX] … ailes à gauche et à droite, éclat derrière", fx and fx.left:IsShown() and fx.right:IsShown()
		and fx.burst:IsShown() and fx.left.atlas == A.wings and fx.burst.blendMode == "ADD"
		and fx.left.drawLayer == "BACKGROUND" and select(3, fx.left:GetPoint(1)) == "LEFT" and select(3, fx.right:GetPoint(1)) == "RIGHT")
	Run(C.rewardTime)
	Check("[FX] … puis tout s'efface", not fx.left:IsShown() and not fx.burst:IsShown())
	-- l'aile droite : l'atlas retourné quand le client donne ses coordonnées
	_G.C_Texture = { GetAtlasInfo = function() return { width = 277, height = 327, file = 123, leftTexCoord = 0.1,
		rightTexCoord = 0.5, topTexCoord = 0.2, bottomTexCoord = 0.9 } end }
	local tex = banner:CreateTexture(nil, "ARTWORK")
	NS.AzerothAtlasMirrored(tex, A.wings)
	Check("[FX] aile droite : coordonnées de l'atlas inversées", tex.texture == 123 and tex.texCoord[1] == 0.5
		and tex.texCoord[2] == 0.1 and tex.texCoord[3] == 0.2 and tex.texCoord[4] == 0.9)
	Mock.InstallAtlas(true)
	-- démonstration : un titre de dresseur gagné, dans la file du carnet
	banner:Hide()
	NS.journalToastHideAt = nil
	NS:JournalToastPush({ kind = "rank", name = "Dresseur confirmé" })
	Check("[FX] titre de dresseur : bandeau avec ailes", NS.journalToast:IsShown() and NS.journalToast.azReward
		and NS.journalToast.azReward.at ~= nil)
	Run(C.rewardTime + 0.2)
	NS.journalToastHideAt = nil
	NS:JournalToastPush({ kind = "seal", name = "Les Tarides" })
	Check("[FX] sceau de zone : pas d'ailes", NS.journalToast.azReward.at == nil)
	NS:SetUIStyle("sobre")
	Check("[FX] Sobre : l'API ne fait rien", NS:AzerothRewardFX(NS:EnsureJournalToast()) == false)
	NS:SetUIStyle("azeroth")
end

-- 6. Atlas manquants : l'effet est sauté, sans erreur -------------------------------------------------
do
	Say("-- effets azeroth : atlas manquants")
	local missing = { [A.talk] = true, [A.circle] = true, [A.circleAlt] = true, [A.star] = true,
		[A.filigree] = true, [A.wings] = true, [A.burst] = true, [A.iconGlow] = true }
	local frame = FXT.Reset(missing)
	Check("[FX] le style Azeroth tient (ses atlas sont là)", frame.uiStyle == "azeroth")
	local errors = NS.errors and #NS.errors or 0
	Speak()
	Run(0.5)
	local bubble = NS.companionBubble
	-- 2.8.2 : la bulle ne dépend plus de l'atlas des Talking Heads
	Check("[FX] sans atlas des Talking Heads : bulle Azeroth quand même", bubble.azBubble and bubble.bg.mockHidden
		and bubble.azTalk.bg.texture == 130661)
	Check("[FX] sans lueur ronde : ni lueur ni liseré", not frame.azGlow and not Edges(frame))
	Check("[FX] sans éclats : la brillante passe sans erreur", NS:AzerothShinyFX() == true and (Run(0.5) or true)
		and frame.azSparks == nil)
	Check("[FX] sans volutes : le texte seul", NS:AzerothLevelFX("Aguerri !") and frame.azLevel.group.left == nil
		and frame.azLevel.iglow == nil and frame.azLevel.group:GetWidth() == math.max(40, math.ceil(frame.azLevel.group.text:GetStringWidth())))
	Run(C.levelTime + 0.5)
	Check("[FX] sans ailes ni éclat : l'API rend false", NS:AzerothRewardFX(NS:EnsureJournalToast()) == false)
	Check("[FX] aucune erreur enregistrée", (NS.errors and #NS.errors or 0) == errors)
	NS:CompanionHideBubble()
end

-- Rangement : les autres modules testent le style Sobre (client sans atlas)
do
	NS:AzerothFxStop()
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.azFx = {}, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.CompanionIsHappy = FXT.savedHappy
	for _, name in ipairs(GLOBALS) do _G[name] = FXT.saved[name] end
	ResetWorld()
end
