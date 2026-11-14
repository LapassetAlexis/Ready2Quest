-- Compagnon : il annonce ce qui entre au carnet, et son cadre brille quand il
-- parle (Notify.lua). Espèce, nommé, ressource, quête de la zone ; une annonce
-- par NOTIFY_GAP s, le reste regroupé ; liseré qui pulse puis s'éteint.
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

local NO = { saved = {}, units = {}, savedList = NS.ZoneQuestList }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"IsInInstance", "GetItemInfo" }
for _, name in ipairs(GLOBALS) do NO.saved[name] = rawget(_G, name) end
local PLAYER = "Player-1-00000001"

function NO.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
function NO.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.notifyState, NS.shinyState = nil, nil, nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt = {}, nil
	NO.units = {}
	Mock.world.maps[9900] = { mapID = 9900, name = "Val du carnet", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 9900, 20
	local w = NO
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
	_G.UnitLevel = function(unit) if unit == "player" or unit == nil then return 20 end return 18 end
	_G.IsInInstance = function() return false, "none" end
	_G.GetItemInfo = function() return nil end
	NS.ZoneQuestList = NO.savedList
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
	NO.Quiet()
end
function NO.Kill(npcID, fields)
	fields = fields or {}
	fields.guid = string.format("Creature-0-4378-1-12-%d-%s", npcID, fields.spawn or "00001A2B3C")
	fields.name = fields.name or ("Bête " .. npcID)
	NO.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
end

-- 1. Bestiaire ---------------------------------------------------------------------------------
do
	Say("-- carnet annoncé : bestiaire")
	local S = Scenario("[NOTIFY] carnet annoncé : bestiaire")
	NO.Reset()
	-- de quoi ne pas finir la zone (sinon c'est le coffre qui parle)
	local book = NS:BestiaryData()
	book[9900] = {}
	for index = 1, 6 do book[9900][4190 + index] = { name = "Ombre " .. index, seen = true, killed = 0 } end
	book[9900][4199] = { name = "Roi caché", seen = true, killed = 0, class = "rare" }
	NO.Kill(4100, { name = "Loup gris" })
	S.ok("espèce abattue pour la première fois : annoncée", NS.companionBubbleKey == "FOUND"
		and NS.companionBubbleText:find("Loup gris", 1, true) and NS.companionBubbleText:find("bestiaire", 1, true),
		NS.companionBubbleText)
	NO.Quiet()
	Mock:Advance(NS.NOTIFY_GAP + 1)
	NO.Kill(4100, { name = "Loup gris", spawn = "00002B3C4D" })
	S.ok("même espèce, deuxième fois : rien", NS.companionBubbleKey ~= "FOUND", NS.companionBubbleKey)
	NO.Quiet()
	NO.Kill(4101, { name = "Chef ogre", class = "elite" })
	S.ok("un nommé : sa part « nommés »", NS.companionBubbleKey == "FOUND"
		and NS.companionBubbleText:find("nommés", 1, true), NS.companionBubbleText)
	-- deux de suite : la seconde attend, puis le regroupement
	NO.Quiet()
	NO.Kill(4102, { name = "Sanglier" })
	S.done()
	S = Scenario("[NOTIFY] écart entre deux annonces, regroupement, brillante à part")
	S.ok("trop tôt après la précédente : mise de côté", NS.companionBubbleKey ~= "FOUND"
		and NS:NotifyState().pending == 1)
	Mock:Advance(1)
	S.ok("pas de regroupement avant l'écart", NS.companionBubbleKey ~= "FOUND_MANY" and NS:NotifyState().pending == 1)
	NO.Quiet()
	Mock:Advance(NS.NOTIFY_GAP)
	S.ok("l'écart passé : « et 1 de plus au carnet »", NS.companionBubbleKey == "FOUND_MANY"
		and NS.companionBubbleText:find("1", 1, true) and NS:NotifyState().pending == 0, NS.companionBubbleText)
	S.ok("rien en attente : rien de plus", NS:NotifyFlush(Mock.now + 100) == false)
	-- une brillante : sa propre bulle, pas celle du carnet
	NO.Quiet()
	local guid = string.format("Creature-0-4378-1-12-%d-%s", 4150, "00001A2B3C")
	NO.units.target = { guid = guid, name = "Kodo d'or" }
	NS:BestiarySeeUnit("target")
	NS:ShinySpot("target", guid, NS.bestiaryUnits[guid], { name = "Kodo d'or" })
	NO.Quiet()
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	S.ok("brillante abattue : sa bulle à elle", NS.companionBubbleKey == "SHINY_KILLED", NS.companionBubbleKey)
	S.done()
end

-- 2. Récolte, quêtes -------------------------------------------------------------------------------
do
	Say("-- carnet annoncé : récolte et quêtes")
	local S = Scenario("[NOTIFY] carnet annoncé : récolte et quêtes")
	NO.Reset()
	NS:GatheringRecord(765, 1, 9900)
	S.ok("ressource récoltée pour la première fois ici : annoncée", NS.companionBubbleKey == "FOUND"
		and NS.companionBubbleText:find("765", 1, true) or (NS.companionBubbleText or ""):find("Feuillargent", 1, true),
		NS.companionBubbleText)
	NO.Quiet()
	Mock:Advance(NS.NOTIFY_GAP + 1)
	NS:GatheringRecord(765, 1, 9900)
	S.ok("même ressource, même zone : rien", NS.companionBubbleKey == nil)
	NS:GatheringRecord(765, 1, nil)
	S.ok("sans zone (instance) : rien", NS.companionBubbleKey == nil)
	NS.ZoneQuestList = function() return { { id = 321, name = "Le ragoût du val", done = true } } end
	Mock:Fire("QUEST_TURNED_IN", 321, 0, 0)
	S.ok("quête de la zone rendue : annoncée", NS.companionBubbleKey == "FOUND"
		and NS.companionBubbleText:find("Le ragoût du val", 1, true), NS.companionBubbleText)
	NO.Quiet()
	Mock:Advance(NS.NOTIFY_GAP + 1)
	Mock:Fire("QUEST_TURNED_IN", 999, 0, 0)
	S.ok("quête d'ailleurs : pas d'annonce du carnet", NS.companionBubbleKey ~= "FOUND")
	NS.ZoneQuestList = NO.savedList
	NS:DB().companionEnabled = false
	local pending = NS:NotifyState().pending
	S.ok("compagnon coupé : rien, pas même en attente", NS:NotifyFound("x", 9900, "bestiary") == false
		and NS:NotifyState().pending == pending)
	NS:DB().companionEnabled = true
	S.ok("texte de la part", NS:NotifyPartText(nil, "quests") == "quêtes")
	S.done()
end

-- 3. Le cadre brille quand il parle ----------------------------------------------------------------
do
	Say("-- cadre qui brille")
	local S = Scenario("[GLOW] cadre qui brille")
	NO.Reset()
	-- 3.1.0 : le liseré rectangulaire est celui du cadre carré (Sobre) ; le
	-- médaillon forgé a sa lueur ronde (tests/modules/companion_forge.lua)
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
	S.ok("sans bulle : éteint", NS:GlowAlpha(Mock.now) == 0 and NS:GlowUpdate(Mock.now) == 0)
	NS:CompanionSay("EAT", { force = true })
	local frame = NS.companionFrame
	local untilAt = NS.companionBubbleUntil
	local alpha = NS:GlowUpdate(Mock.now)
	S.ok("il parle : le liseré s'allume", alpha > 0 and frame.glow and frame.glow[1]:IsShown())
	S.ok("… sans dépasser l'éclat prévu", alpha <= NS.GLOW_ALPHA)
	local a, b = NS:GlowAlpha(untilAt - 1.0), NS:GlowAlpha(untilAt - 1.25)
	S.ok("… il pulse", math.abs(a - b) > 0.01)
	S.ok("juste après la bulle : il s'éteint doucement", NS:GlowAlpha(untilAt + NS.GLOW_FADE / 2) > 0)
	S.ok("longtemps après : zéro, pas moins", NS:GlowAlpha(untilAt + NS.GLOW_FADE + 1) == 0)
	NS:GlowUpdate(untilAt + NS.GLOW_FADE + 0.1)
	S.ok("puis éteint", not frame.glow[1]:IsShown())
	Mock:Advance(0.1)
	NS:CompanionSay("EAT", { force = true })
	Mock:Advance(0.1)
	S.done()
	S = Scenario("[GLOW] horloge, compagnon coupé, répliques et textes")
	S.ok("l'horloge l'allume toute seule", frame.glowAlpha and frame.glowAlpha > 0)
	NS:DB().companionEnabled = false
	S.ok("compagnon coupé : éteint", NS:GlowUpdate(Mock.now) == 0)
	NS:DB().companionEnabled = true
	local missing = {}
	for key in pairs(NS.NOTIFY_STRINGS.fr) do if not NS.NOTIFY_STRINGS.en[key] then missing[#missing + 1] = key end end
	for name, keys in pairs(NS.NOTIFY_POOLS) do
		S.ok("répliques enregistrées : " .. name, NS.COMPANION_POOLS[name] == keys)
	end
	S.ok("textes fr et en", #missing == 0, table.concat(missing, ", "))
	S.done()
end

for _, name in ipairs(GLOBALS) do _G[name] = NO.saved[name] end
NS.ZoneQuestList = NO.savedList
ResetWorld()
