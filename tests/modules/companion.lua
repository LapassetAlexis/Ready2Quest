-- Module « Compagnon de route » (v1.25.0) : réglages par défaut, chaînes
-- fr/en, besoins (hausse, plancher), somnolence après absence, évolution
-- 10/20/40/60, réactions, bulles (écart minimal, sourdine, priorités),
-- cosmétiques donnés par le coffre (jamais au compteur), choix d'apparence,
-- repli sans modèle 3D, caresse et clic droit, renommage, module coupé ;
-- dialogues : réservoirs, tirage, combat, repas, PNJ, lieux, astuces,
-- conversation, envies, objectifs, tutoriel.
-- Un scénario = une assertion ; chaque étape en défaut est nommée dans le message.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

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

local C = {
	savedCreateFrame = _G.CreateFrame,
	savedJournal = rawget(NS, "JournalCounts"),
	savedSeason = rawget(NS, "WinterVeilSeason"),
	models = {},
}
-- 2.14.0 : l'horloge du banc (time() = 1000, le 1er janvier 1970) tombe en
-- plein Voile d'hiver ; ces tests sont hors saison (compagnons de saison :
-- winter_veil.lua)
NS.WinterVeilSeason = function() return false end
if NS.WinterCompanionsForget then NS:WinterCompanionsForget() end

-- Le mock ne connaît pas les cadres de modèle : on les fabrique ici, en
-- enregistrant les appels (affichage, échelle, animation).
function C.InstallModelAPI(failing)
	_G.CreateFrame = function(kind, ...)
		local frame = C.savedCreateFrame(kind, ...)
		if kind == "PlayerModel" or kind == "Model" then
			frame.calls = {}
			function frame:SetDisplayInfo(id)
				if failing then error("bad display") end
				self.display = id
			end
			function frame:SetCreature(id) self.creature = id end
			function frame:SetAnimation(id) self.anim = id end
			function frame:SetModelScale(s) self.modelScale = s end
			function frame:SetRotation(r) self.rotation = r end
			function frame:SetCamDistanceScale(s) self.cam = s end
			C.models[#C.models + 1] = frame
		end
		return frame
	end
end
function C.RemoveModelAPI() _G.CreateFrame = C.savedCreateFrame end

-- Monde neuf, compagnon neuf (le cadre est recréé au besoin)
function C.Reset(level, withModel, tutorial)
	ResetWorld()
	C.RemoveModelAPI()
	if withModel ~= false then C.InstallModelAPI() end
	NS.JournalCounts = nil
	for _, frame in ipairs({ NS.companionFrame, NS.companionBubble, NS.companionHover }) do
		if frame then frame:Hide() end
	end
	NS.companionFrame, NS.companionBubble, NS.companionHover = nil, nil, nil
	NS.companionSession, NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleText = nil, nil, nil, nil
	NS.companionBubbleUntil, NS.companionAnimUntil, NS.companionLastPet = nil, nil, nil
	NS.companionEating, NS.companionFed, NS.companionAtCamp = nil, nil, nil
	NS.companionRT, NS.companionBubblePrio, NS.companionBubbleLine = nil, nil, nil
	Mock.world.level = level or 11
	Mock.world.mapID, Mock.world.subzone = 20, "Clairière"
	-- le tutoriel de première apparition a ses propres tests : ailleurs, il
	-- est déjà vu (sinon sa priorité retiendrait toutes les réactions)
	if tutorial ~= true then NS:CompanionData().tutoDone = true end
end
-- Connexion : le premier PLAYER_ENTERING_WORLD de la session
function C.Login()
	NS.companionSession = nil
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
end
-- Laisse passer l'écart des bulles (sans faire tourner l'horloge des besoins)
function C.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	if NS.companionRT then NS.companionRT.cool, NS.companionRT.seq = {}, nil end
end
-- La ligne affichée appartient-elle au réservoir ?
function C.InPool(pool, key)
	key = key or NS.companionBubbleLine
	for _, k in ipairs(NS.COMPANION_POOLS[pool] or {}) do if k == key then return true end end
	return false
end
function C.Needs() return NS:CompanionData().needs end
function C.Key() return NS.companionBubbleKey end
function C.Shown() return NS.companionBubble ~= nil and NS.companionBubble:IsShown() == true end
function C.Play(minutes)
	for _ = 1, minutes do Mock:Advance(60) end
end
function C.Model() return NS.companionFrame and NS.companionFrame.model end


do
	Say("-- chargement, réglages, chaînes")
	local S = Scenario("[COMP] chargement et réglages par défaut")
	C.Reset()
	local db = NS:DB()
	S.ok("réglages par défaut", db.companionEnabled == true and db.companionShow == true
		and NS:CompanionChatterLevel() == 3 and db.companionChatter == 3)
	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "companion" then page = def end end
	S.ok("page MODULES avec interrupteur", page and page.group == "OPT_GROUP_MODULES" and page.power == "companionEnabled")
	S.ok("module trouvé par ses alias", NS:FindModule("compagnon") and NS:FindModule("pet")
		and NS:FindModule("pet").key == "companionEnabled")
	S.ok("chaîne française active", NS.L.COMP_SAY_VIEW == "Quelle vue !" and NS.L.COMP_SAY_DEAD:find("Aïe", 1, true) == 1)
	S.done()
	-- fr et en : mêmes clés, aucune vide ; toute clé du catalogue traduite
	local fr, en = NS.COMPANION_STRINGS.fr, NS.COMPANION_STRINGS.en
	local missing = {}
	for key, value in pairs(fr) do
		if type(en[key]) ~= "string" or en[key] == "" or value == "" then missing[#missing + 1] = key end
	end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	for _, list in ipairs({ NS.COMPANION_APPEARANCES, NS.COMPANION_ORNAMENTS, NS.COMPANION_STAGES }) do
		for _, def in ipairs(list) do if not (fr[def.label] and en[def.label]) then missing[#missing + 1] = def.label end end
	end
	Check("[COMP] chaînes fr/en : mêmes clés, aucune vide, catalogue traduit", #missing == 0, table.concat(missing, ","))
end

do
	Say("-- première connexion")
	local S = Scenario("[COMP] première connexion")
	C.Reset(11)
	Mock:Reset()
	C.Login()
	local data = NS:CompanionData()
	S.ok("bonjour à la première connexion", C.Key() == "HELLO" and C.Shown(), C.Key())
	S.ok("nom par défaut dans la bulle", NS.companionBubbleText:find("Brindille", 1, true) ~= nil, NS.companionBubbleText)
	S.ok("stade posé sans fête (niveau 11 : Jeune)", data.stage == 2 and not Mock:Output():find("devient", 1, true), data.stage)
	S.ok("pas somnolent au premier jour", not data.sleepy)
	S.ok("cadre affiché", NS.companionFrame and NS.companionFrame:IsShown())
	S.ok("la bulle se referme seule", (function() Mock:Advance(7); return not C.Shown() end)())
	S.done()
end

do
	Say("-- besoins : baisse douce, jamais à zéro")
	local S = Scenario("[COMP] besoins : baisse douce, jamais à zéro")
	C.Reset(11)
	C.Login()
	local start = C.Needs().hunger
	C.Play(30)
	S.ok("la faim baisse en jouant", C.Needs().hunger < start, C.Needs().hunger)
	C.Play(600)    -- 10 h de jeu sans rien faire
	local low = true
	for _, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		low = low and C.Needs()[key] >= NS.COMPANION_RULES.floor and C.Needs()[key] > 0
	end
	S.ok("après 10 h : aucun besoin sous le plancher", low, C.Needs().hunger .. "/" .. C.Needs().mood)
	S.ok("plancher atteint (la baisse a bien eu lieu)", C.Needs().curiosity == NS.COMPANION_RULES.floor, C.Needs().curiosity)
	-- une valeur corrompue de la sauvegarde est ramenée dans les bornes
	NS:CompanionData().needs.mood = -40
	S.ok("sauvegarde corrompue ramenée au plancher", NS:CompanionData().needs.mood == NS.COMPANION_RULES.floor)
	NS:CompanionAdd("mood", 500)
	S.ok("jamais plus de 100", C.Needs().mood == 100)
	S.done()
end

do
	Say("-- besoins : ce qui les fait monter")
	local S = Scenario("[COMP] besoins : ce qui les fait monter")
	C.Reset(11)
	C.Login()
	for _, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do C.Needs()[key] = 40 end
	-- repas : aura « Nourriture »
	C.Quiet()
	Mock.world.auraOrder = { 433 }
	Mock.world.auras = { [433] = { name = "Nourriture", duration = 30 } }
	Mock:Fire("UNIT_AURA", "player")
	S.ok("manger : la faim remonte", C.Needs().hunger >= 75, C.Needs().hunger)
	S.ok("manger : « Miam ! »", C.Key() == "EAT", C.Key())
	local h = C.Needs().hunger
	Mock:Fire("UNIT_AURA", "player")
	S.ok("même repas : compté une fois", C.Needs().hunger == h)
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	Mock:Fire("UNIT_AURA", "player")
	-- repos à l'auberge
	Mock.world.resting = true
	local e = C.Needs().energy
	C.Play(5)
	S.ok("au repos : l'énergie remonte", C.Needs().energy > e, e .. " -> " .. C.Needs().energy)
	Mock.world.resting = false
	-- quête rendue
	C.Quiet()
	local m = C.Needs().mood
	Mock:Fire("QUEST_TURNED_IN", 123, 500, 0)
	S.done()
	S = Scenario("[COMP] besoins : quête, zone, butin")
	S.ok("quête rendue : le moral monte", C.Needs().mood > m and C.Key() == "QUEST", C.Key())
	-- nouvelle zone
	C.Quiet()
	local c = C.Needs().curiosity
	Mock.world.mapID = 30
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	S.ok("nouvelle zone : curiosité et « Quelle vue ! »", C.Needs().curiosity > c and C.Key() == "VIEW", C.Key())
	C.Quiet()
	c = C.Needs().curiosity
	Mock.world.mapID = 20
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	S.ok("zone de connexion déjà connue : rien", C.Needs().curiosity == c and NS.companionLastBubble == nil)
	c = C.Needs().curiosity
	Mock.world.subzone = "Vieux moulin"
	Mock:Fire("ZONE_CHANGED")
	S.ok("nouvelle sous-zone : un peu de curiosité", C.Needs().curiosity > c)
	-- butin notable
	C.Quiet()
	m = C.Needs().mood
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : |cff0070dd|Hitem:4444::::::::|h[Épée bleue]|h|r.")
	S.ok("butin rare : moral et « ça brille »", C.Needs().mood > m and C.Key() == "LOOT", C.Key())
	C.Quiet()
	m = C.Needs().mood
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : |cff9d9d9d|Hitem:5555::::::::|h[Caillou]|h|r.")
	S.ok("butin gris : rien", C.Needs().mood == m and NS.companionLastBubble == nil)
	S.done()
end

do
	Say("-- absence : somnolent, sans pénalité")
	local S = Scenario("[COMP] absence : somnolent, sans pénalité")
	C.Reset(11)
	C.Login()
	local data = NS:CompanionData()
	data.needs.hunger, data.needs.mood = 63, 71
	data.lastSeen = time() - 10 * 3600     -- 10 h d'absence
	C.Login()
	S.ok("après 10 h : somnolent", data.sleepy == true)
	S.ok("« Tu m'as manqué ! »", C.Key() == "MISSED", C.Key())
	S.ok("aucune pénalité sur les besoins", data.needs.hunger == 63 and data.needs.mood == 71, data.needs.hunger)
	S.ok("humeur somnolente, animation de sommeil", NS:CompanionMood() == "sleepy" and NS.companionFrame.animation == "sleep")
	S.ok("somnolence proportionnée (10 h -> 200 s)", data.sleepyLeft == 200, data.sleepyLeft)
	C.Play(4)
	S.ok("il se réveille en jouant", not data.sleepy and C.Key() == "AWAKE", C.Key())
	-- 60 jours : plafond
	data.lastSeen = time() - 60 * 86400
	C.Login()
	S.ok("longue absence : somnolence plafonnée", data.sleepyLeft == NS.COMPANION_RULES.sleepyMax, data.sleepyLeft)
	S.ok("longue absence : besoins intacts", data.needs.mood >= 15)
	-- 30 min : rien
	NS:CompanionWake(false)
	data.lastSeen = time() - 1800
	C.Login()
	S.ok("courte absence : pas somnolent", not data.sleepy)
	-- PEW suivant (écran de chargement) : pas de nouveau relevé
	data.lastSeen = time() - 10 * 3600
	Mock:Fire("PLAYER_ENTERING_WORLD", false, false)
	S.ok("écran de chargement : pas de relevé d'absence", not data.sleepy)
	S.done()
end

do
	Say("-- évolution 10 / 20 / 40 / 60")
	local S = Scenario("[COMP] évolution 10 / 20 / 40 / 60")
	C.Reset(5)
	C.Login()
	local data = NS:CompanionData()
	S.ok("niveau 5 : Nouveau-né", data.stage == 1)
	local scales = { C.Model() and C.Model().modelScale }
	local evolved = {}
	for _, level in ipairs({ 10, 20, 40, 60 }) do
		Mock.world.level = level
		Mock:Reset()
		C.Quiet()
		Mock:Fire("PLAYER_LEVEL_UP", level)
		evolved[#evolved + 1] = data.stage
		scales[#scales + 1] = C.Model() and C.Model().modelScale
		S.ok("niveau " .. level .. " : fête (bulle + chat + danse)", C.Key() == "EVOLVE"
			and Mock:Output():find("devient", 1, true) ~= nil and NS.companionFrame.animation == "dance", C.Key())
	end
	S.ok("stades 2, 3, 4, 5", table.concat(evolved, ",") == "2,3,4,5", table.concat(evolved, ","))
	local growing = true
	for i = 2, #scales do growing = growing and scales[i] and scales[i] > scales[i - 1] end
	S.ok("le modèle grandit à chaque stade", growing, table.concat(scales, ","))
	S.ok("nom du stade dans la bulle", NS.companionBubbleText:find("Légendaire", 1, true) ~= nil, NS.companionBubbleText)
	Mock:Advance(4)
	S.ok("la danse s'arrête", NS.companionFrame.animation == "idle", NS.companionFrame.animation)
	NS:CompanionCheckStage(12, true)
	S.ok("jamais de retour en arrière", data.stage == 5)
	-- niveau sans palier : bravo simple
	C.Reset(11)
	C.Login()
	C.Quiet()
	Mock.world.level = 12
	Mock:Fire("PLAYER_LEVEL_UP", 12)
	S.ok("niveau 12 : « Niveau 12 ! »", C.Key() == "LEVEL" and NS.companionBubbleText:find("12", 1, true), C.Key())
	S.done()
end

do
	Say("-- réactions : départ, retour, mort, tampon, camp")
	local S = Scenario("[COMP] réactions : départ, retour, mort, tampon, camp")
	C.Reset(11)
	C.Login()
	C.Quiet()
	NS:FireCallback("DEPARTURE", { name = "Comté-de-l'Or" })
	S.ok("départ sans vivres : il le fait remarquer", C.Key() == "NOFOOD", C.Key())
	S.ok("... gentiment (une ligne du réservoir NOFOOD)", C.InPool("NOFOOD"))
	C.Quiet()
	Mock.world.itemInfo[117] = { classID = 0, subClassID = 5 }
	Mock.world.bags[0].items[1] = { itemID = 117, stackCount = 5 }
	local h = C.Needs().hunger
	NS:FireCallback("DEPARTURE", { name = "Comté-de-l'Or" })
	S.ok("départ avec vivres : en route, la faim monte", C.Key() == "DEPART" and C.Needs().hunger > h, C.Key())
	C.Quiet()
	NS:FireCallback("RETURN", { name = "Comté-de-l'Or" })
	S.ok("retour : « on est rentrés »", C.Key() == "RETURN", C.Key())
	C.Quiet()
	Mock:Fire("PLAYER_DEAD")
	S.ok("mort : une ligne du réservoir DEAD", C.Key() == "DEAD" and C.InPool("DEAD"), C.Key())
	C.Quiet()
	local c = C.Needs().curiosity
	NS:FireCallback("STAMP", { id = "zone:1519", kind = "zone", name = "Hurlevent", new = true })
	S.ok("tampon : curiosité et bulle avec le nom", C.Needs().curiosity > c and C.Key() == "STAMP"
		and NS.companionBubbleText:find("Hurlevent", 1, true), NS.companionBubbleText)
	C.Quiet()
	c = C.Needs().curiosity
	NS:FireCallback("STAMP", { id = "zone:1519", kind = "zone", name = "Hurlevent", new = false })
	S.ok("tampon déjà vu : rien", C.Needs().curiosity == c and NS.companionLastBubble == nil)
	-- feu de camp (Forever) : aura « Campfire Nearby »
	C.Quiet()
	Mock.world.auras = { [1283391] = { name = "Campfire Nearby", duration = 0 } }
	Mock.world.auraOrder = { 1283391 }
	Mock:Fire("UNIT_AURA", "player")
	S.ok("feu de camp : « On se réchauffe ? »", C.Key() == "CAMP", C.Key())
	local e = C.Needs().energy
	C.Play(3)
	S.ok("au camp : l'énergie remonte", C.Needs().energy > e)
	S.done()
end

do
	Say("-- bulles : écart minimal et sourdine")
	local S = Scenario("[COMP] bulles : écart minimal et sourdine")
	C.Reset(11)
	C.Login()
	C.Quiet()
	S.ok("première bulle affichée", NS:CompanionSay("QUEST") == true)
	S.ok("deuxième bulle trop tôt : retenue", NS:CompanionSay("DEAD") == false and C.Key() == "QUEST")
	Mock:Fire("PLAYER_DEAD")
	S.ok("rafale d'événements : toujours une seule bulle", C.Key() == "QUEST")
	Mock.now = Mock.now + NS.COMPANION_RULES.bubbleGap + 1
	S.ok("après l'écart : de nouveau permise", NS:CompanionSay("DEAD") == true and C.Key() == "DEAD")
	S.done()
	S = Scenario("[COMP] bulles : priorité, sourdine, cadre masqué")
	S.ok("une bulle prioritaire passe l'écart", NS:CompanionSay("EVOLVE", { force = true, args = { "X" } }) == true)
	C.Quiet()
	NS:DB().companionChatter = 0
	NS.companionBubbleKey = nil
	Mock:Reset()
	NS:HandleCommand("compagnon muet")
	S.ok("« muet » rallume les bulles (cran Normal)", NS:DB().companionChatter == 3 and Mock:Output():find("Bulles", 1, true))
	NS:HandleCommand("compagnon muet")
	S.ok("« muet » les recoupe (cran 0, l'ancien retenu)", NS:DB().companionChatter == 0
		and NS:DB().companionChatterBefore == 3)
	NS:DB().companionChatter = 3
	NS:DB().companionShow = false
	NS:CompanionUpdateVisibility()
	C.Quiet()
	S.ok("cadre masqué : ni cadre ni bulle", NS:CompanionSay("QUEST") == false and not NS.companionFrame:IsShown())
	NS:DB().companionShow = true
	S.done()
end

do
	Say("-- cosmétiques : gagnés au coffre, jamais au compteur")
	local S = Scenario("[COMP] cosmétiques : gagnés au coffre, jamais au compteur")
	C.Reset(11)
	C.Login()
	S.ok("sans Carnet : compteurs à zéro", NS:CompanionCounts().total == 0 and NS:CompanionCounts().zone == 0)
	S.ok("au départ : seule l'apparence de départ", #NS:CompanionUnlockedAppearances() == 1)
	local fake = { zone = 50, subzone = 100, dungeon = 20, rare = 10, level = 6, total = 186 }
	NS.JournalCounts = function() return fake end
	Mock:Reset()
	C.Quiet()
	NS:FireCallback("STAMP", { id = "subzone:42", kind = "subzone", name = "Vieux moulin", new = true })
	local data = NS:CompanionData()
	S.ok("gros compteurs : rien de débloqué (seul le coffre donne)", not data.unlocked["app:whelp_red"]
		and not data.unlocked["orn:ribbon"] and #NS:CompanionUnlockedAppearances() == 1)
	S.ok("tampon : sa bulle à lui", C.Key() == "STAMP", C.Key())
	Mock.world.level = 60
	Mock:Fire("PLAYER_LEVEL_UP", 60)
	S.ok("niveau 60 : rien de débloqué non plus", not data.unlocked["orn:gold"] and not data.unlocked["app:whelp_black"])
	NS.JournalCounts = function() error("boom") end
	S.ok("Carnet en erreur : compteurs à zéro", NS:CompanionCounts().zone == 0)
	NS.JournalCounts = nil
	-- ce que le coffre a donné s'affiche, et reste
	data.unlocked["orn:ribbon"] = true
	NS:CompanionApplyOrnaments()
	S.done()
	S = Scenario("[COMP] cosmétiques : ce que le coffre a donné s'affiche et reste")
	S.ok("ruban gagné : affiché sur le cadre", NS.companionFrame.ornaments.ribbon:IsShown())
	NS:DB().companionOrnRibbon = false
	NS:CompanionApplyOrnaments()
	S.ok("ruban coupé dans les réglages : masqué", not NS.companionFrame.ornaments.ribbon:IsShown())
	NS:DB().companionOrnRibbon = true
	S.ok("lanterne encore verrouillée : masquée", not NS.companionFrame.ornaments.lantern:IsShown())
	data.unlocked["orn:gold"] = true
	NS:CompanionCheckUnlocks()
	NS:CompanionApplyOrnaments()
	-- (3.1.0 : le double liseré carré n'est pas posé sur le médaillon forgé,
	-- dont l'anneau d'or tient lieu : companion_forge.lua)
	S.ok("gains définitifs", data.unlocked["orn:ribbon"] and data.unlocked["orn:gold"]
		and NS.companionFrame.ornaments.gold:IsShown() == (NS.companionFrame.ring ~= "forge"))
	S.ok("condition lisible", NS:CompanionRequirement({ stamp = "dungeon", count = 5 }) == "5 donjons"
		and NS:CompanionRequirement({ level = 20 }) == "niveau 20")
	S.done()
end

do
	Say("-- choix d'apparence")
	local S = Scenario("[COMP] choix d'apparence")
	C.Reset(11)
	C.Login()
	local data = NS:CompanionData()
	S.ok("modèle 3D : apparence de départ affichée", C.Model() and C.Model().display == 6291, C.Model() and C.Model().display)
	S.ok("une seule apparence : le cycle y reste", NS:CompanionCycleAppearance().id == "whelp_green")
	-- deux apparences gagnées au coffre
	data.unlocked["app:frog"], data.unlocked["app:whelp_red"] = true, true
	local seen = {}
	for _ = 1, 3 do seen[#seen + 1] = NS:CompanionCycleAppearance().id end
	S.ok("le cycle ne passe que par les apparences débloquées", table.concat(seen, ",") == "frog,whelp_red,whelp_green",
		table.concat(seen, ","))
	NS:RunOptionAction("companionAppearance")
	S.ok("bouton des réglages : apparence suivante", data.appearance == "frog" and C.Model().display == 6295, data.appearance)
	-- apparence verrouillée dans la sauvegarde : retour à celle de départ
	data.appearance = "whelp_black"
	S.ok("apparence non débloquée refusée", NS:CompanionCurrentAppearance().id == "whelp_green")
	-- page de réglages : nom de l'apparence et verrous
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companion")
	local appRow, lanternRow
	for _, row in ipairs(NS.optionsFrame.rows) do
		if row.def and row.def.key == "companionAppearance" then appRow = row end
		if row.def and row.def.key == "companionOrnLantern" then lanternRow = row end
	end
	local dd = appRow and appRow.dropdown
	S.done()
	S = Scenario("[COMP] apparence : liste des réglages, verrous")
	S.ok("réglages : apparence en liste déroulante, nom affiché", dd and dd.text.text:find("Dragonnet émeraude", 1, true),
		dd and dd.text.text)
	local byValue = {}
	for _, entry in ipairs(dd and dd.options or {}) do byValue[entry.value] = entry end
	S.ok("liste : toutes les apparences, les gagnées d'abord", dd and #dd.options == #NS.COMPANION_APPEARANCES
		and not dd.options[1].disabled and not dd.options[2].disabled and dd.options[#dd.options].disabled == true)
	S.ok("liste : verrouillée = grisée avec sa condition", byValue.owl and byValue.owl.disabled and byValue.owl.hint == "Palier 2"
		and byValue.chicken and byValue.chicken.hint == NS:CompanionRequirement({ inn = 3 }), byValue.owl and byValue.owl.hint)
	local appBefore = data.appearance
	S.ok("liste : un choix verrouillé est refusé", dd:Choose("owl") == false and data.appearance == appBefore)
	dd:Choose("whelp_red")
	S.ok("liste : choix d'une apparence gagnée", data.appearance == "whelp_red" and C.Model().display == 6290, data.appearance)
	dd:Choose("frog")
	S.ok("réglages : ornement verrouillé, verrou avec son palier", lanternRow and lanternRow.locked
		and lanternRow.lock.label.text == "Palier 2" and lanternRow.lock:IsShown() and not lanternRow.toggle:IsShown(),
		lanternRow and lanternRow.lock and lanternRow.lock.label.text)
	local lanternBefore = NS:DB().companionOrnLantern
	lanternRow:Click()
	S.ok("ornement verrouillé : le clic ne change rien", NS:DB().companionOrnLantern == lanternBefore)
	S.ok("page sans débordement", #NS:OptionsUnreachable("companionMain") == 0,
		table.concat(NS:OptionsUnreachable("companionMain"), ", "))
	NS.optionsFrame:Hide()
	S.done()
end

do
	Say("-- repli sans modèle 3D")
	local S = Scenario("[COMP] repli sans modèle 3D")
	C.Reset(11, false)          -- CreateFrame du mock : pas de SetDisplayInfo
	C.Login()
	local frame = NS.companionFrame
	S.ok("sans API de modèle : boussole affichée", frame.usesFallback == true and frame.fallback:IsShown()
		and frame.fallback.texture == NS.Theme.LOGO_SMALL, tostring(frame.fallback.texture))
	S.ok("sans API de modèle : pas de modèle", frame.model == nil)
	S.ok("sans API de modèle : bulles et caresses marchent", C.Key() == "HELLO" and NS:CompanionPet() == true)
	Mock:Reset()
	NS:HandleCommand("compagnon")
	S.ok("statut : repli signalé", Mock:Output():find("boussole", 1, true) ~= nil)
	-- modèle présent mais affichage refusé : repli aussi
	C.Reset(11, false)
	C.InstallModelAPI(true)
	C.Login()
	S.ok("SetDisplayInfo en erreur : boussole", NS.companionFrame.usesFallback == true and NS.companionFrame.fallback:IsShown())
	C.Reset(11)
	C.Login()
	S.ok("avec modèle : boussole cachée", NS.companionFrame.usesFallback == false and not NS.companionFrame.fallback:IsShown())
	-- il salue en parlant (animation « talk »), puis revient au repos
	S.ok("avec modèle : il parle en saluant", C.Model().anim == NS.COMPANION_ANIMS.talk)
	Mock:Advance(NS.COMPANION_TALK_TIME + 0.1)
	S.ok("avec modèle : animation de repos", C.Model().anim == NS.COMPANION_ANIMS.idle)
	Mock:Advance(1)
	S.ok("avec modèle : léger balancement", type(C.Model().rotation) == "number")
	S.done()
end

do
	Say("-- caresse, survol")
	local S = Scenario("[COMP] caresse, survol")
	C.Reset(11)
	C.Login()
	C.Quiet()
	C.Needs().mood = 50
	NS.companionFrame.scripts.OnMouseDown(NS.companionFrame)
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "LeftButton")
	S.ok("clic : moral +8 et petite conversation", C.Needs().mood == 58 and (C.Key() or ""):find("^CONVO_"), C.Key())
	S.ok("clic : animation de joie", NS.companionFrame.animation == "cheer")
	S.ok("caresse trop tôt : sans effet", NS:CompanionPet() == false and C.Needs().mood == 58)
	Mock.now = Mock.now + NS.COMPANION_RULES.petCooldown + 1
	S.ok("après la pause : de nouveau", NS:CompanionPet() == true and C.Needs().mood == 66)
	-- glisser n'est pas caresser
	Mock.now = Mock.now + 60
	Mock.world.cursorX = 500
	NS.companionFrame.scripts.OnMouseDown(NS.companionFrame)
	Mock.world.cursorX = 560
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "LeftButton")
	S.ok("glisser le cadre : pas de caresse", C.Needs().mood == 66)
	Mock.world.cursorX = nil
	-- clic droit : son carnet, sur son dernier onglet (pas une caresse)
	Mock.now = Mock.now + 60
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS:DB().journalTab = "evolution"
	NS.JournalCounts = C.savedJournal
	-- 3.0.0 : clic droit = le carnet, d'un geste (comme avant la 3.0) ;
	-- Maj + clic droit = le petit menu (carnet de voyage, mode chasse)
	local shiftSaved = rawget(_G, "IsShiftKeyDown")
	_G.IsShiftKeyDown = function() return false end
	NS.companionFrame.scripts.OnMouseDown(NS.companionFrame)
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "RightButton")
	S.done()
	S = Scenario("[COMP] clic droit : carnet ; Maj + clic droit : menu")
	S.ok("clic droit : le carnet sur son dernier onglet, sans menu ni caresse", NS.journalFrame and NS.journalFrame:IsShown()
		and NS.journalFrame.kind == "evolution" and not (NS.companionMenu and NS.companionMenu:IsShown()) and C.Needs().mood == 66)
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "RightButton")
	S.ok("clic droit de nouveau : carnet refermé", not NS.journalFrame:IsShown())
	_G.IsShiftKeyDown = function() return true end
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "RightButton")
	S.ok("Maj + clic droit : le menu (carnet, chasse), sans carnet ni caresse", NS.companionMenu and NS.companionMenu:IsShown()
		and not NS.journalFrame:IsShown() and C.Needs().mood == 66)
	NS.companionMenu.journal:Click()
	S.ok("menu « Carnet de voyage » : carnet ouvert, menu fermé", NS.journalFrame:IsShown() and not NS.companionMenu:IsShown())
	NS:CompanionMenuShow()
	NS.companionMenu.journal:Click()
	S.ok("de nouveau : carnet refermé", not NS.journalFrame:IsShown())
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "RightButton")
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "RightButton")
	S.ok("second Maj + clic droit : le menu se ferme", not NS.companionMenu:IsShown())
	_G.IsShiftKeyDown = shiftSaved
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "MiddleButton")
	S.ok("autre bouton : rien", not NS.journalFrame:IsShown() and C.Needs().mood == 66)
	NS.JournalCounts = nil
	S.done()
	S = Scenario("[COMP] survol : aide, barres ; caresse qui réveille")
	S.ok("survol : clic droit (carnet) et Maj + clic droit (chasse) annoncés",
		NS.L.COMP_HOVER_HINT:find("clic droit : carnet", 1, true) ~= nil and NS.L.COMP_HOVER_HINT:find("Maj + clic droit : chasse", 1, true) ~= nil
		and NS.L.COMP_HOVER_HINT_locked:find("Maj + clic droit : chasse", 1, true) ~= nil)
	-- une caresse réveille
	local data = NS:CompanionData()
	data.sleepy, data.sleepyLeft = true, 300
	Mock.now = Mock.now + 60
	NS:CompanionPet()
	S.ok("une caresse le réveille", not data.sleepy and C.Key() == "PET_sleepy", C.Key())
	NS.companionFrame.scripts.OnEnter(NS.companionFrame)
	local hover = NS.companionHover
	S.ok("survol : quatre barres de besoins", hover and hover:IsShown() and hover.bars.hunger and hover.bars.energy
		and hover.bars.mood and hover.bars.curiosity)
	S.ok("survol : barre au bon niveau", math.abs(hover.bars.mood.ratio - C.Needs().mood / 100) < 0.001, hover.bars.mood.ratio)
	NS.companionFrame.scripts.OnLeave(NS.companionFrame)
	S.ok("fin du survol : masqué", not hover:IsShown())
	S.done()
end

do
	Say("-- commande, renommage")
	local S = Scenario("[COMP] commande, renommage")
	C.Reset(11)
	C.Login()
	Mock:Reset()
	NS:HandleCommand("compagnon nom   Pépite  ")
	S.ok("renommé", NS:CompanionName() == "Pépite" and NS.companionFrame.name.text == "Pépite", NS:CompanionName())
	S.ok("renommage confirmé", Mock:Output():find("Pépite", 1, true) ~= nil)
	NS:HandleCommand("compagnon nom |cffff0000Rouge|r")
	S.ok("codes de couleur retirés", NS:CompanionName() == "Rouge", NS:CompanionName())
	Mock:Reset()
	NS:HandleCommand("compagnon nom    ")
	S.ok("nom vide refusé", not NS:CompanionName():find("^%s*$") and Mock:Output():find("Donne-lui un nom", 1, true))
	NS:HandleCommand("compagnon nom " .. string.rep("é", 20))
	local name = NS:CompanionName()
	S.ok("nom trop long coupé sans casser l'UTF-8", #name <= 24 and #name % 2 == 0 and name:sub(1, 2) == "é", #name)
	Mock:Reset()
	NS:HandleCommand("compagnon")
	local out = Mock:Output()
	S.ok("statut : nom, stade, besoins, collection", out:find(NS:CompanionName(), 1, true) and out:find("Jeune", 1, true)
		and out:find("Faim", 1, true) and out:find("Apparences 1/" .. #NS.COMPANION_APPEARANCES, 1, true), out)
	NS:HandleCommand("compagnon apparence")
	S.ok("« apparence » : cycle et confirmation", Mock:Output():find("Apparence :", 1, true) ~= nil)
	S.ok("aide : commande listée", (function()
		for _, section in ipairs(NS.HELP) do
			for _, key in ipairs(section[2]) do if key == "HELP_COMPANION" then return true end end
		end
		return false
	end)())
	S.done()
end

do
	Say("-- module coupé : plus rien")
	local S = Scenario("[COMP] module coupé : plus rien")
	C.Reset(11)
	C.Login()
	Mock:Reset()
	NS:HandleCommand("module compagnon off")
	S.ok("module coupé : cadre masqué", NS:DB().companionEnabled == false and not NS.companionFrame:IsShown())
	local before = {}
	for k, v in pairs(C.Needs()) do before[k] = v end
	C.Quiet()
	NS.companionBubbleKey = nil
	Mock:Fire("QUEST_TURNED_IN", 1, 10, 0)
	Mock:Fire("PLAYER_DEAD")
	NS:FireCallback("DEPARTURE", { name = "X" })
	NS:FireCallback("STAMP", { id = "zone:1", kind = "zone", name = "Y", new = true })
	Mock.world.level = 20
	Mock:Fire("PLAYER_LEVEL_UP", 20)
	C.Play(30)
	local same = true
	for k, v in pairs(C.Needs()) do same = same and before[k] == v end
	S.ok("module coupé : aucun besoin ne bouge", same)
	S.ok("module coupé : aucune bulle", C.Key() == nil and not C.Shown())
	S.ok("module coupé : pas d'évolution", NS:CompanionData().stage == 2)
	S.ok("module coupé : pas de caresse", NS:CompanionPet() == false)
	Mock:Reset()
	NS:HandleCommand("compagnon")
	S.ok("module coupé : la commande le dit", Mock:Output():find("coupé", 1, true) ~= nil)
	NS:ToggleModuleKey("companionEnabled")
	S.ok("interrupteur de la navigation : rallumé et affiché", NS:DB().companionEnabled == true and NS.companionFrame:IsShown())
	NS:DB().enabled = false
	S.ok("addon coupé : compagnon inactif", NS:CompanionPet() == false)
	NS:DB().enabled = true
	S.done()
end

-- ===========================================================================
-- v1.25.0 : dialogues, astuces, conversation, besoins exprimés, objectifs,
-- tutoriel. Mocks propres à ces scénarios (restaurés à la fin du fichier).
-- ===========================================================================
local D = { saved = {}, W = {} }
D.MOCKED = { "UnitName", "UnitCreatureType", "CombatLogGetCurrentEventInfo", "UnitGUID", "InCombatLockdown",
	"GetRealZoneText", "GetGameTime", "C_GossipInfo" }
for _, name in ipairs(D.MOCKED) do D.saved[name] = rawget(_G, name) end
D.PLAYER_GUID = "Player-1-0000AAAA"
_G.UnitName = function(unit)
	-- "player" reste « Testeur » : c'est la clé des données du personnage
	if unit == "npc" then return D.W.npcName end
	return "Testeur"
end
_G.UnitCreatureType = function(unit) if unit == "npc" then return D.W.npcType end return nil end
_G.UnitGUID = function(unit)
	if unit == "player" then return D.PLAYER_GUID end
	if unit == "npc" then return D.W.npcGUID end
	return nil
end
_G.CombatLogGetCurrentEventInfo = function() return unpack(D.W.cleu or {}) end
_G.InCombatLockdown = function() return D.W.combat == true end
_G.GetRealZoneText = function() return D.W.zone or "" end
_G.GetGameTime = function() return D.W.hour or 12, 0 end
_G.C_GossipInfo = nil

function D.Reset(level, tutorial)
	C.Reset(level, nil, tutorial)
	D.W = { npcName = "Gizzle", npcType = "Humanoïde", npcGUID = "Creature-0-1-1-1-100-0001" }
	NS.hubIndex = nil
	NS.COMPANION_RULES.npcCreatureChance = 0.5
	_G.C_GossipInfo = nil
end
-- Coupe les sources spontanées (astuces, objectifs, envies) pour isoler un test
function D.Calm()
	local rt = NS.companionRT
	rt.tipAt, rt.goalAt = math.huge, math.huge
	rt.cool.need, rt.cool.night = math.huge, math.huge
end
function D.Npc(event, guid)
	C.Quiet()
	D.W.npcGUID = guid or ("Creature-" .. tostring(math.random(1, 1e6)))
	Mock:Fire(event)
	return C.Key()
end
-- Combien de bulles d'un réservoir en `minutes` de jeu
function D.Count(pool, minutes)
	local count, last = 0, NS.companionLastBubble
	for _ = 1, minutes do
		Mock:Advance(60)
		if NS.companionLastBubble ~= last then
			last = NS.companionLastBubble
			if C.Key() == pool then count = count + 1 end
		end
	end
	return count
end

do
	Say("-- répliques : réservoirs fr / en")
	local S = Scenario("[COMP] répliques : réservoirs fr / en")
	local fr, en = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en
	local bad, placeholders = {}, {}
	for pool, keys in pairs(NS.COMPANION_POOLS) do
		for _, key in ipairs(keys) do
			if type(fr[key]) ~= "string" or fr[key] == "" or type(en[key]) ~= "string" or en[key] == "" then bad[#bad + 1] = key end
			local a = (fr[key] or ""):gsub("[^%%]*(%%?[sd]?)", "%1")
			local b = (en[key] or ""):gsub("[^%%]*(%%?[sd]?)", "%1")
			if a ~= b then placeholders[#placeholders + 1] = key end
		end
	end
	S.ok("chaque ligne a son français et son anglais", #bad == 0, table.concat(bad, ","))
	local minimum = {
		KILL = 6, EAT = 5, DRINK = 3, LOOT = 5, LEVEL = 5, QUEST = 5, DEAD = 4, REZ = 4, CITY = 4, VILLAGE = 4,
		CAMP = 4, INN = 4, VIEW = 5, IDLE = 5, NIGHT = 3, STAMP = 4, EVOLVE = 3, UNLOCK = 3,
		NPC_merchant = 5, NPC_innkeeper = 4, NPC_trainer = 4, NPC_flight = 4, NPC_banker = 4, NPC_quest = 5, NPC_talk = 4,
		NEED_hunger = 3, NEED_energy = 3, NEED_mood = 3, NEED_curiosity = 3, GOAL = 2, GOAL_STAGE = 2, TIP = 20, TUTO = 4,
	}
	local short = {}
	for pool, n in pairs(minimum) do
		if #(NS.COMPANION_POOLS[pool] or {}) < n then short[#short + 1] = pool .. "=" .. #(NS.COMPANION_POOLS[pool] or {}) end
	end
	table.sort(short)
	S.done()
	S = Scenario("[COMP] répliques : volume, conversations, types de créature")
	S.ok("plusieurs lignes par situation (20+ astuces)", #short == 0, table.concat(short, ","))
	S.ok("tutoriel : 4 à 8 bulles", #NS.COMPANION_POOLS.TUTO >= 4 and #NS.COMPANION_POOLS.TUTO <= 8)
	local convos = true
	for _, name in ipairs(NS.COMPANION_CONVOS) do
		local n = #(NS.COMPANION_POOLS[name] or {})
		convos = convos and n >= 2 and n <= 3
	end
	S.ok("conversations : plusieurs, de 2 ou 3 bulles", #NS.COMPANION_CONVOS >= 6 and convos, #NS.COMPANION_CONVOS)
	-- une bulle tient dans le cadre (~4 lignes de 30 caractères)
	local long = {}
	for _, key in ipairs(NS.COMPANION_POOLS.TIP) do if #fr[key] > 130 or #en[key] > 130 then long[#long + 1] = key end end
	local types = {}
	for _, ct in pairs(NS.COMPANION_CREATURE_TYPES) do
		if ct ~= "humanoid" and not NS.COMPANION_POOLS["NPC_CT_" .. ct] then types[#types + 1] = ct end
	end
	S.ok("chaque type de créature reconnu a ses avis", #types == 0, table.concat(types, ","))
	S.done()
end

do
	Say("-- répliques : tirage sans répétition")
	local S = Scenario("[COMP] répliques : tirage sans répétition")
	D.Reset(11)
	local problems = {}
	for _, pool in ipairs({ "KILL", "EAT", "DRINK", "LOOT", "LEVEL", "QUEST", "DEAD", "REZ", "CITY", "VILLAGE", "CAMP",
		"INN", "VIEW", "IDLE", "NPC_merchant", "NPC_innkeeper", "NPC_trainer", "NPC_flight", "NPC_banker", "NPC_quest",
		"NPC_talk", "NEED_hunger", "TIP" }) do
		local previous, distinct, outside, repeated = nil, {}, false, false
		for _ = 1, 40 do
			local key = NS:CompanionPick(pool, { "X" })
			if not C.InPool(pool, key) then outside = true end
			if key == previous then repeated = true end
			distinct[key or "?"] = true
			previous = key
		end
		local n = 0
		for _ in pairs(distinct) do n = n + 1 end
		if outside or repeated or n < math.min(3, #NS.COMPANION_POOLS[pool]) then problems[#problems + 1] = pool end
	end
	S.ok("chaque situation tire dans son réservoir, jamais deux fois de suite", #problems == 0, table.concat(problems, ","))
	-- les deux dernières sont évitées (réservoir assez grand)
	local last2 = true
	local history = {}
	for i = 1, 30 do
		local key = NS:CompanionPick("KILL")
		if history[i - 1] == key or history[i - 2] == key then last2 = false end
		history[i] = key
	end
	S.ok("ni la dernière ni l'avant-dernière", last2)
	-- sans argument : les lignes à « %s » sont écartées (PNJ sans nom)
	-- (PNJ sans nom : avis sans trou, vérifié de bout en bout plus bas)
	S.done()
end

do
	Say("-- monstre tué : journal de combat et XP")
	local S = Scenario("[COMP] monstre tué : journal de combat et XP")
	D.Reset(11)
	C.Login()
	D.Calm()
	C.Quiet()
	D.W.cleu = { 1, "PARTY_KILL", false, D.PLAYER_GUID, "Testeur", 0x511, 0, "Creature-0-1-1-1-299-1", "Loup", 0xa48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	S.ok("PARTY_KILL du joueur : une réplique de combat", C.Key() == "KILL" and C.InPool("KILL"), C.Key())
	C.Quiet()      -- pause « combat » levée : seul le dédoublonnage peut retenir
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 40 points d'expérience.")
	S.ok("même mort par l'XP : comptée une fois", NS.companionLastBubble == nil)
	C.Quiet()
	Mock:Advance(3)
	D.W.cleu = { 1, "PARTY_KILL", false, "Player-1-0000BBBB", "Autre", 0x511, 0, "Creature-0-1-1-1-299-2", "Loup", 0xa48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	D.W.cleu = { 1, "SPELL_DAMAGE", false, D.PLAYER_GUID, "Testeur", 0x511, 0, "Creature-0-1-1-1-299-2", "Loup", 0xa48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	S.ok("mort d'un autre, dégâts : rien", NS.companionLastBubble == nil)
	D.W.cleu = { 1, "PARTY_KILL", false, D.PLAYER_GUID, "Testeur", 0x511, 0, "Creature-0-1-1-1-299-3", "Loup", 0xa48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	S.ok("monstre suivant : réplique", C.Key() == "KILL" and NS.companionLastBubble ~= nil)
	-- pause de la catégorie : l'écart global passé, toujours rien
	Mock:Advance(5)
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Sanglier meurt, vous gagnez 42 points d'expérience.")
	S.ok("pause du combat : pas de commentaire à chaque monstre", NS.companionLastBubble == nil)
	Mock.now = Mock.now + NS.COMPANION_RULES.cooldowns.kill + 1
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Sanglier meurt, vous gagnez 42 points d'expérience.")
	S.ok("XP d'un monstre (sans journal de combat) : réplique", C.Key() == "KILL", C.Key())
	C.Quiet()
	Mock.now = Mock.now + 5
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Vous gagnez 300 points d'expérience.")
	S.ok("XP de quête : pas un monstre", NS.companionLastBubble == nil)
	S.done()
end

do
	Say("-- repas : manger, boire")
	local S = Scenario("[COMP] repas : manger, boire")
	D.Reset(11)
	C.Login()
	D.Calm()
	C.Quiet()
	Mock.world.auraOrder, Mock.world.auras = { 430 }, { [430] = { name = "Boisson", duration = 30 } }
	Mock:Fire("UNIT_AURA", "player")
	S.ok("boire : réplique de boisson", C.Key() == "DRINK" and C.InPool("DRINK"), C.Key())
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	Mock:Fire("UNIT_AURA", "player")
	C.Quiet()
	Mock.world.auraOrder, Mock.world.auras = { 433 }, { [433] = { name = "Food", duration = 30 } }
	Mock:Fire("UNIT_AURA", "player")
	S.ok("manger : réplique de repas", C.Key() == "EAT" and C.InPool("EAT"), C.Key())
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	Mock:Fire("UNIT_AURA", "player")
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	Mock.world.auraOrder, Mock.world.auras = { 433 }, { [433] = { name = "Food", duration = 30 } }
	Mock:Fire("UNIT_AURA", "player")
	S.ok("deux repas rapprochés : un seul commentaire", NS.companionLastBubble == nil)
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	S.done()
end

do
	Say("-- avis sur les PNJ")
	local S = Scenario("[COMP] avis sur les PNJ")
	D.Reset(11)
	C.Login()
	D.Calm()
	-- tampon d'auberge déjà reçu aujourd'hui : l'aubergiste a son avis (Daily.lua)
	local _, inn = NS:DailyData()
	inn.day = NS:DailyToday()
	local seen = {
		merchant = D.Npc("MERCHANT_SHOW"), trainer = D.Npc("TRAINER_SHOW"), flight = D.Npc("TAXIMAP_OPENED"),
		banker = D.Npc("BANKFRAME_OPENED"), quest = D.Npc("QUEST_DETAIL"), greeting = D.Npc("QUEST_GREETING"),
		binder = D.Npc("CONFIRM_BINDER"), talk = D.Npc("GOSSIP_SHOW"),
	}
	S.ok("marchand", seen.merchant == "NPC_merchant", seen.merchant)
	S.ok("maître", seen.trainer == "NPC_trainer", seen.trainer)
	S.ok("maître de vol", seen.flight == "NPC_flight", seen.flight)
	S.ok("banquier", seen.banker == "NPC_banker", seen.banker)
	S.ok("donneur de quête (détail et accueil)", seen.quest == "NPC_quest" and seen.greeting == "NPC_quest")
	S.ok("aubergiste (foyer)", seen.binder == "NPC_innkeeper", seen.binder)
	S.ok("simple bavardage", seen.talk == "NPC_talk", seen.talk)
	_G.C_GossipInfo = { GetOptions = function() return { { name = "Faire de cette auberge votre foyer", type = "binder" } } end }
	S.ok("bavardage d'aubergiste reconnu", D.Npc("GOSSIP_SHOW") == "NPC_innkeeper", C.Key())
	_G.C_GossipInfo = { GetOptions = function() return {} end, GetNumAvailableQuests = function() return 2 end }
	S.ok("bavardage avec quêtes : donneur de quête", D.Npc("GOSSIP_SHOW") == "NPC_quest", C.Key())
	_G.C_GossipInfo = nil
	-- même PNJ : bavardage puis vendeur, un seul avis
	D.Npc("GOSSIP_SHOW", "Creature-same")
	local at = NS.companionLastBubble
	D.Npc("MERCHANT_SHOW", "Creature-same")
	S.done()
	S = Scenario("[COMP] avis sur les PNJ : un par PNJ, nom, nature, pause")
	S.ok("même PNJ : un seul avis", NS.companionLastBubble == nil and at ~= nil)
	-- le nom du PNJ entre parfois dans l'avis
	local withName = false
	for _ = 1, 30 do
		D.Npc("MERCHANT_SHOW")
		if (NS.companionBubbleText or ""):find("Gizzle", 1, true) then withName = true end
	end
	S.ok("avis avec le nom du PNJ", withName)
	D.W.npcName = nil
	local hole = false
	for _ = 1, 30 do
		D.Npc("MERCHANT_SHOW")
		if (NS.companionBubbleText or ""):find("%", 1, true) or C.Key() ~= "NPC_merchant" then hole = true end
	end
	S.ok("PNJ sans nom : avis sans trou", not hole)
	D.W.npcName = "Gizzle"
	-- nature de la créature (UnitCreatureType, traduit par le client)
	NS.COMPANION_RULES.npcCreatureChance = 1
	D.W.npcType = "Mort-vivant"
	S.ok("PNJ mort-vivant : avis sur sa nature", D.Npc("MERCHANT_SHOW") == "NPC_CT_undead", C.Key())
	D.W.npcType = "Beast"
	S.ok("type anglais reconnu (Beast)", D.Npc("TRAINER_SHOW") == "NPC_CT_beast", C.Key())
	D.W.npcType = "Humanoïde"
	S.ok("humanoïde : avis sur son rôle", D.Npc("MERCHANT_SHOW") == "NPC_merchant", C.Key())
	D.W.npcType = "Inconnu"
	S.ok("type inconnu : avis sur son rôle", D.Npc("BANKFRAME_OPENED") == "NPC_banker", C.Key())
	NS.COMPANION_RULES.npcCreatureChance = 0
	D.W.npcType = "Mort-vivant"
	S.ok("hasard à zéro : toujours le rôle", D.Npc("MERCHANT_SHOW") == "NPC_merchant", C.Key())
	NS.COMPANION_RULES.npcCreatureChance = 0.5
	D.W.npcType = "Humanoïde"
	-- pause de catégorie : deux PNJ coup sur coup, un seul avis
	C.Quiet()
	D.W.npcGUID = "Creature-a"
	Mock:Fire("MERCHANT_SHOW")
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	D.W.npcGUID = "Creature-b"
	Mock:Fire("TRAINER_SHOW")
	S.ok("deux PNJ coup sur coup : un seul avis", C.Key() == "NPC_merchant", C.Key())
	S.done()
end

do
	Say("-- mort, résurrection, lieux")
	local S = Scenario("[COMP] mort, résurrection, lieux")
	D.Reset(11)
	C.Login()
	D.Calm()
	C.Quiet()
	Mock:Fire("PLAYER_DEAD")
	Mock.world.dead = true
	C.Quiet()
	Mock:Fire("PLAYER_ALIVE")      -- esprit libéré : fantôme, pas encore vivant
	S.ok("fantôme : pas de « te revoilà »", NS.companionLastBubble == nil)
	Mock.world.dead = false
	Mock:Fire("PLAYER_UNGHOST")
	S.ok("résurrection : réplique de retour", C.Key() == "REZ" and C.InPool("REZ"), C.Key())
	C.Quiet()
	Mock:Fire("PLAYER_ALIVE")
	S.ok("pas de résurrection sans mort", NS.companionLastBubble == nil)
	-- village connu (Hubs.lua) : un mot en entrant, pas à chaque sous-zone
	C.Quiet()
	Mock.world.subzone = "Goldshire"
	Mock:Fire("ZONE_CHANGED")
	S.done()
	S = Scenario("[COMP] lieux : village, capitale")
	S.ok("entrée dans un village", C.Key() == "VILLAGE" and C.InPool("VILLAGE"), C.Key())
	C.Quiet()
	Mock:Fire("ZONE_CHANGED_INDOORS")
	S.ok("même village : rien de plus", NS.companionLastBubble == nil)
	Mock.now = Mock.now + 700
	C.Quiet()
	Mock:Fire("ZONE_CHANGED")
	S.ok("longtemps dans le même village : rien de plus", NS.companionLastBubble == nil)
	Mock.world.subzone = "Bois"
	Mock:Fire("ZONE_CHANGED")
	C.Quiet()
	Mock.world.subzone = "Goldshire"
	Mock:Fire("ZONE_CHANGED")
	S.ok("ressorti puis revenu aussitôt : rien", NS.companionLastBubble == nil)
	C.Quiet()
	Mock.world.subzone = "Quartier commerçant"
	D.W.zone = "Stormwind City"
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	S.ok("entrée dans une capitale", C.Key() == "CITY" and C.InPool("CITY"), C.Key())
	D.W.zone = nil
	S.done()
end

do
	Say("-- bavardage : repos prolongé, nuit")
	local S = Scenario("[COMP] bavardage : repos prolongé, nuit")
	D.Reset(11)
	C.Login()
	D.Calm()
	C.Quiet()
	Mock.world.resting = true
	-- (les blagues tirées au hasard prendraient la place du mot : coupées ici)
	local jokes = NS:DB().companionJokes
	NS:DB().companionJokes = false
	C.Play(4)
	S.ok("4 min au repos : rien encore", NS.companionLastBubble == nil)
	C.Play(1)
	S.ok("5 min au repos : un mot", C.Key() == "IDLE" and C.InPool("IDLE"), C.Key())
	S.ok("puis le repos continue sans bavarder", D.Count("IDLE", 10) == 0)
	NS:DB().companionJokes = jokes
	Mock.world.resting = false
	D.Reset(11)
	C.Login()
	D.Calm()
	NS.companionRT.cool.night = nil
	D.W.hour = 14
	S.ok("en journée : pas de mot de nuit", D.Count("NIGHT", 10) == 0)
	D.W.hour = 23
	S.ok("la nuit : un mot, puis une pause", D.Count("NIGHT", 30) == 1)
	S.done()
end

do
	Say("-- astuces")
	local S = Scenario("[COMP] astuces")
	D.Reset(11)
	C.Login()
	D.Calm()
	NS.companionRT.tipAt = nil
	S.ok("pas d'astuce dans les 10 premières minutes", D.Count("TIP", 9) == 0)
	local times, last = {}, NS.companionLastBubble
	for _ = 1, 90 do
		Mock:Advance(60)
		if NS.companionLastBubble ~= last then
			last = NS.companionLastBubble
			if C.Key() == "TIP" then times[#times + 1] = Mock.now end
		end
	end
	local spaced = #times > 0
	for i = 2, #times do spaced = spaced and times[i] - times[i - 1] >= NS.COMPANION_RULES.tipGap end
	S.ok("1 h 30 de jeu : une astuce toutes les 10 à 15 min", #times >= 6 and #times <= 9 and spaced, #times)
	-- en combat : jamais
	C.Quiet()
	NS.companionRT.tipAt = 0
	D.W.combat = true
	S.ok("astuce en combat : non", NS:CompanionTryTip() == false and D.Count("TIP", 3) == 0)
	D.W.combat = false
	S.ok("hors combat : de nouveau", NS:CompanionTryTip() == true and C.Key() == "TIP")
	-- réglage « Astuces » coupé
	C.Quiet()
	-- réglette « Bavardage » sous Normal : plus d'astuces
	NS:DB().companionChatter = 2
	NS.companionRT.tipAt = 0
	S.ok("astuces coupées (cran Calme) : aucune", NS:CompanionTryTip(true) == false and D.Count("TIP", 30) == 0)
	NS:DB().companionChatter = 3
	-- pas de redite avant d'avoir tout vu
	D.Reset(11)
	C.Login()
	local total, seen, dup = #NS.COMPANION_POOLS.TIP, {}, false
	for _ = 1, total do
		C.Quiet()
		NS:CompanionTryTip(true)
		local key = NS.companionBubbleLine
		if seen[key] then dup = true end
		seen[key] = true
	end
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	S.done()
	S = Scenario("[COMP] astuces : toutes vues avant la moindre redite")
	S.ok("astuces : toutes vues avant la moindre redite", not dup and n == total, n .. "/" .. total)
	local lastTip = NS.companionBubbleLine
	C.Quiet()
	NS:CompanionTryTip(true)
	S.ok("nouveau tour : pas la dernière astuce", C.Key() == "TIP" and NS.companionBubbleLine ~= lastTip)
	S.ok("tours d'astuces gardés par personnage", NS:CompanionData().tipsSeen[NS.companionBubbleLine] == true)
	S.done()
end

do
	Say("-- clic : petite conversation")
	local S = Scenario("[COMP] clic : petite conversation")
	D.Reset(11)
	C.Login()
	D.Calm()
	C.Quiet()
	NS:CompanionPet()
	local name = C.Key()
	local steps = NS.COMPANION_POOLS[name] or {}
	local shown = { NS.companionBubbleLine }
	for _ = 2, #steps do
		Mock:Advance(NS.COMPANION_RULES.convoStep)
		shown[#shown + 1] = NS.companionBubbleLine
	end
	S.ok("conversation : ses bulles dans l'ordre", #steps >= 2 and table.concat(shown, ",") == table.concat(steps, ","),
		table.concat(shown, ","))
	Mock:Advance(NS.COMPANION_RULES.convoStep)
	S.ok("conversation terminée", NS.companionRT.seq == nil)
	-- une réaction ne coupe pas la conversation ; une évolution, si
	Mock.now = Mock.now + NS.COMPANION_RULES.petCooldown + 1
	NS:CompanionPet()
	local convo = C.Key()
	Mock:Fire("QUEST_TURNED_IN", 1, 10, 0)
	NS.companionLastBubble = nil
	S.done()
	S = Scenario("[COMP] conversation : priorités et variété")
	S.ok("réaction pendant la conversation : retenue", NS:CompanionSay("QUEST", { force = true }) == false and C.Key() == convo)
	Mock.world.level = 20
	Mock:Fire("PLAYER_LEVEL_UP", 20)
	S.ok("évolution pendant la conversation : elle passe", C.Key() == "EVOLVE" and NS.companionRT.seq == nil, C.Key())
	-- plusieurs conversations, jamais la même deux fois de suite
	local previous, repeated, distinct = nil, false, {}
	for _ = 1, 12 do
		Mock:Advance(NS.COMPANION_RULES.petCooldown + 1)
		C.Quiet()
		NS:CompanionPet()
		if C.Key() == previous then repeated = true end
		distinct[C.Key() or "?"] = true
		previous = C.Key()
	end
	local n = 0
	for _ in pairs(distinct) do n = n + 1 end
	S.ok("conversations variées, sans redite immédiate", not repeated and n >= 4, n)
	S.done()
end

do
	Say("-- besoins exprimés")
	local S = Scenario("[COMP] besoins exprimés")
	D.Reset(11)
	C.Login()
	D.Calm()
	NS.companionRT.cool.need = nil
	S.ok("besoins hauts : aucune envie", D.Count("NEED_hunger", 20) == 0 and NS.companionBubbleKey ~= "NEED_mood")
	-- connexion avec un besoin bas : un répit, puis une envie
	D.Reset(11)
	C.Login()
	D.Calm()
	C.Quiet()
	D.Calm()
	NS.companionRT.cool.need = Mock.now + NS.COMPANION_RULES.needGrace
	C.Needs().hunger = 25
	C.Play(1)
	S.ok("répit après la connexion", NS.companionLastBubble == nil)
	C.Play(2)
	S.ok("faim basse : il le dit", C.Key() == "NEED_hunger" and C.InPool("NEED_hunger"), C.Key())
	S.ok("... sans reproche", not NS.companionBubbleText:find("abandon", 1, true) and not NS.companionBubbleText:find("oubli", 1, true))
	C.Needs().hunger = 25
	S.ok("envie : rare (au plus 1 toutes les 15 min)", D.Count("NEED_hunger", 30) <= 2)
	-- le besoin le plus bas d'abord
	D.Reset(11)
	C.Login()
	D.Calm()
	NS.companionRT.cool.need = nil
	C.Needs().hunger, C.Needs().curiosity = 30, 20
	C.Play(1)
	S.done()
	S = Scenario("[COMP] envies : la plus basse, jamais en combat ni somnolent")
	S.ok("plusieurs besoins bas : le plus bas", C.Key() == "NEED_curiosity", C.Key())
	-- jamais en combat, jamais en somnolant
	D.Reset(11)
	C.Login()
	D.Calm()
	NS.companionRT.cool.need = nil
	C.Needs().energy = 20
	D.W.combat = true
	S.ok("en combat : pas d'envie", D.Count("NEED_energy", 5) == 0 and NS:CompanionTryNeed() == false)
	D.W.combat = false
	NS:CompanionData().sleepy, NS:CompanionData().sleepyLeft = true, 9999
	S.ok("somnolent : pas d'envie", D.Count("NEED_energy", 5) == 0)
	NS:CompanionWake(false)
	C.Quiet()
	C.Play(1)
	S.ok("réveillé, fatigué : il le dit", C.Key() == "NEED_energy", C.Key())
	S.done()
end

do
	Say("-- priorités")
	local S = Scenario("[COMP] priorités")
	D.Reset(11)
	C.Login()
	D.Calm()
	C.Quiet()
	NS:CompanionTryTip(true)
	S.ok("une astuce affichée", C.Key() == "TIP")
	Mock.world.level = 20
	Mock:Fire("PLAYER_LEVEL_UP", 20)
	S.ok("une évolution remplace l'astuce", C.Key() == "EVOLVE", C.Key())
	NS.companionLastBubble = nil       -- l'écart global passé, la bulle encore affichée
	S.ok("une astuce n'efface pas l'évolution", NS:CompanionTryTip(true) == false and C.Key() == "EVOLVE")
	S.ok("une réaction forcée non plus", NS:CompanionSay("QUEST", { force = true }) == false and C.Key() == "EVOLVE")
	C.Needs().hunger = 20
	NS.companionRT.cool.need = nil
	S.ok("une envie non plus", NS:CompanionTryNeed() == false and C.Key() == "EVOLVE")
	Mock:Advance(NS.COMPANION_RULES.bubbleTime + 1)
	NS.companionLastBubble = nil
	S.ok("évolution finie : l'envie passe", NS:CompanionTryNeed() == true and C.Key() == "NEED_hunger")
	S.ok("une réaction passe devant une envie affichée", NS:CompanionSay("QUEST", { force = true }) == true)
	S.ok("une envie n'efface pas une réaction", NS:CompanionSay("NEED_mood") == false and C.Key() == "QUEST")
	Mock:Advance(1)
	NS.companionLastBubble = NS.companionLastBubble    -- écart global : 1 s seulement
	S.ok("écart global : bavardage retenu", NS:CompanionSay("IDLE") == false)
	S.done()
end

do
	Say("-- prochains déblocages (contrat Carnet)")
	local S = Scenario("[COMP] prochains déblocages (contrat Carnet)")
	D.Reset(11)
	C.Login()
	local list = NS:CompanionNextUnlocks()
	local fields, kinds = true, { app = true, orn = true, stage = true }
	local stats = { zone = true, subzone = true, dungeon = true, rare = true, level = true, total = true, happy = true }
	for _, item in ipairs(list) do
		fields = fields and type(item.label) == "string" and kinds[item.kind] and stats[item.stat]
			and type(item.have) == "number" and type(item.need) == "number" and item.have < item.need
	end
	S.ok("objectifs : champs du contrat", #list > 0 and fields)
	S.ok("objectifs : plus de cosmétique au compteur, le prochain stade seul", #list == 1, #list)
	S.ok("objectif de stade : Aguerri au niveau 20", list[1].kind == "stage" and list[1].label == "Aguerri"
		and list[1].stat == "level" and list[1].have == 11 and list[1].need == 20, list[1].label)
	Mock:Reset()
	NS:HandleCommand("compagnon")
	S.ok("statut : prochain stade", Mock:Output():find("Prochain : Aguerri (11/20)", 1, true) ~= nil, Mock:Output())
	-- rien de proche : pas de rappel
	D.Reset(5)
	C.Login()
	C.Quiet()
	NS.companionRT.goalAt = 0
	S.ok("objectif lointain : pas de rappel", NS:CompanionTryGoal() == false)
	-- stade : « Encore 2 niveaux et je deviendrai Jeune ! »
	Mock.world.level = 8
	C.Quiet()
	NS.companionRT.goalAt = 0
	S.ok("rappel de stade", NS:CompanionTryGoal() == true and C.Key() == "GOAL_STAGE"
		and NS.companionBubbleText:find("2 niveaux", 1, true) and NS.companionBubbleText:find("Jeune", 1, true), NS.companionBubbleText)
	C.Quiet()
	NS.companionRT.goalAt = 0
	NS.companionRT.cool.goal = Mock.now + 10
	S.ok("rappel : rare (pause)", NS:CompanionTryGoal() == false)
	Mock.world.level = 60
	NS:CompanionCheckStage(60, false)
	local stage = false
	for _, item in ipairs(NS:CompanionNextUnlocks()) do if item.kind == "stage" then stage = true end end
	S.ok("niveau 60 : plus de stade à venir", not stage)
	S.done()
end

do
	Say("-- tutoriel")
	local S = Scenario("[COMP] tutoriel")
	D.Reset(11, true)
	Mock:Reset()
	C.Login()
	local data = NS:CompanionData()
	local tuto = NS.COMPANION_POOLS.TUTO
	S.ok("première apparition : le tutoriel", C.Key() == "TUTO" and NS.companionBubbleLine == tuto[1], C.Key())
	S.ok("tutoriel : il se présente", NS.companionBubbleText:find("Brindille", 1, true) ~= nil)
	S.ok("tutoriel : boutons Suivant et Passer", NS.companionBubble.nextButton:IsShown() and NS.companionBubble.skipButton:IsShown())
	Mock:Fire("QUEST_TURNED_IN", 1, 10, 0)
	S.ok("tutoriel : une réaction ne le coupe pas", NS:CompanionSay("QUEST", { force = true }) == false and C.Key() == "TUTO")
	Mock:Advance(NS.COMPANION_RULES.tutoStep)
	S.ok("tutoriel : bulle 2 toute seule", NS.companionBubbleLine == tuto[2])
	NS.companionBubble.nextButton:Click()
	S.ok("« Suivant » : bulle 3", NS.companionBubbleLine == tuto[3])
	local mood = C.Needs().mood
	NS.companionFrame.scripts.OnMouseDown(NS.companionFrame)
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "LeftButton")
	S.ok("clic sur le compagnon : bulle suivante (pas de câlin)", NS.companionBubbleLine == tuto[4] and C.Needs().mood == mood)
	-- combat : la bulle s'efface, la même étape revient après
	D.W.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	S.ok("combat : le tutoriel s'efface", not C.Shown())
	Mock:Advance(30)
	S.ok("en combat : il attend", not C.Shown() and NS:CompanionTutorialActive())
	D.W.combat = false
	Mock:Advance(1)
	S.ok("fin du combat : la même étape revient", NS.companionBubbleLine == tuto[4] and C.Shown(), NS.companionBubbleLine)
	-- une évolution passe devant, puis l'étape reprend
	Mock.world.level = 20
	Mock:Fire("PLAYER_LEVEL_UP", 20)
	S.done()
	S = Scenario("[COMP] tutoriel : évolution, fin, connexion suivante")
	S.ok("évolution pendant le tutoriel : elle passe", C.Key() == "EVOLVE", C.Key())
	Mock:Advance(NS.COMPANION_RULES.bubbleTime)
	S.ok("puis le tutoriel reprend son étape", C.Key() == "TUTO" and NS.companionBubbleLine == tuto[4], NS.companionBubbleLine)
	for _ = 5, #tuto do Mock:Advance(NS.COMPANION_RULES.tutoStep) end
	S.ok("dernière bulle", NS.companionBubbleLine == tuto[#tuto])
	S.ok("pas encore fini tant qu'elle est lue", not data.tutoDone)
	Mock:Advance(NS.COMPANION_RULES.tutoStep)
	S.ok("tutoriel fini : vu, bulle fermée", data.tutoDone == true and not C.Shown() and not NS:CompanionTutorialActive())
	-- prochaine connexion : plus de tutoriel
	C.Login()
	S.ok("connexion suivante : pas de tutoriel", C.Key() ~= "TUTO" or not C.Shown())
	-- Passer
	D.Reset(11, true)
	C.Login()
	Mock:Reset()
	NS.companionBubble.skipButton:Click()
	S.done()
	S = Scenario("[COMP] tutoriel : Passer, commande, réglages")
	S.ok("« Passer » : fini, vu, bulle fermée", NS:CompanionData().tutoDone == true and not C.Shown()
		and not NS:CompanionTutorialActive() and Mock:Output():find("passé", 1, true))
	-- commande et bouton des réglages
	C.Quiet()
	NS:HandleCommand("compagnon tuto")
	S.ok("/r2q compagnon tuto : rejoué", C.Key() == "TUTO" and NS.companionBubbleLine == tuto[1])
	NS:HandleCommand("compagnon tuto passer")
	S.ok("/r2q compagnon tuto passer", not NS:CompanionTutorialActive() and not C.Shown())
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companion")
	local tutoRow, chatterRow
	for _, row in ipairs(NS.optionsFrame.rows) do
		if row.def and row.def.key == "companionTutorial" then tutoRow = row end
		if row.def and (row.def.key == "companionTips" or row.def.key == "companionBubbles") then chatterRow = false end
		if row.def and row.def.key == "companionChatter" and chatterRow == nil then chatterRow = row end
	end
	S.ok("réglages : la réglette « Bavardage » remplace bulles et astuces", chatterRow
		and chatterRow.def.kind == "number" and chatterRow.label.text == "Bavardage")
	S.ok("réglages : bouton « Rejouer le tutoriel »", tutoRow and tutoRow.label.text == "Rejouer le tutoriel")
	C.Quiet()
	if tutoRow then tutoRow:Click() end
	S.ok("bouton des réglages : tutoriel rejoué", C.Key() == "TUTO" and NS:CompanionTutorialActive())
	NS.optionsFrame:Hide()
	NS:CompanionSkipTutorial()
	-- jamais en combat : première apparition en plein combat
	D.Reset(11, true)
	D.W.combat = true
	C.Login()
	S.done()
	S = Scenario("[COMP] tutoriel : combat et sourdine")
	S.ok("connexion en combat : pas de tutoriel", C.Key() ~= "TUTO" and not NS:CompanionTutorialActive())
	Mock:Reset()
	NS:HandleCommand("compagnon tuto")
	S.ok("demandé en combat : après le combat", not NS:CompanionTutorialActive() and Mock:Output():find("après le combat", 1, true))
	D.W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	S.ok("sortie du combat : le tutoriel démarre", C.Key() == "TUTO" and NS.companionBubbleLine == tuto[1])
	NS:CompanionSkipTutorial()
	-- sourdine : pas de tutoriel, pas marqué vu (il reviendra)
	D.Reset(11, true)
	NS:DB().companionChatter = 0
	C.Login()
	S.ok("sourdine : pas de tutoriel, il reste à voir", not NS:CompanionTutorialActive() and not NS:CompanionData().tutoDone
		and not C.Shown())
	Mock:Reset()
	NS:HandleCommand("compagnon tuto")
	S.ok("sourdine : la commande explique", Mock:Output():find("coupées", 1, true) ~= nil)
	NS:DB().companionChatter = 3
	-- sourdine en plein tutoriel : il s'arrête sans être marqué vu
	C.Quiet()
	NS:CompanionStartTutorial(true)
	NS:DB().companionChatter = 0
	Mock:Advance(NS.COMPANION_RULES.tutoStep)
	S.ok("sourdine en route : arrêté, pas vu", not NS:CompanionTutorialActive() and not NS:CompanionData().tutoDone)
	NS:DB().companionChatter = 3
	S.done()
end

do
	Say("-- sourdine : plus rien du tout")
	local S = Scenario("[COMP] sourdine : plus rien du tout")
	D.Reset(11)
	C.Login()
	NS:DB().companionChatter = 0
	NS:CompanionHideBubble()
	NS.companionBubbleKey = nil
	C.Quiet()
	D.W.cleu = { 1, "PARTY_KILL", false, D.PLAYER_GUID, "Testeur", 0x511, 0, "Creature-0-1-1-1-299-1", "Loup", 0xa48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	D.Npc("MERCHANT_SHOW")
	Mock.world.auraOrder, Mock.world.auras = { 433 }, { [433] = { name = "Food", duration = 30 } }
	Mock:Fire("UNIT_AURA", "player")
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	NS:CompanionTryTip(true)
	C.Needs().hunger = 20
	NS.companionRT.cool.need, NS.companionRT.goalAt, NS.companionRT.tipAt = nil, 0, 0
	Mock.world.resting = true
	C.Play(20)
	Mock.world.resting = false
	NS:CompanionPet()
	Mock:Advance(10)
	Mock:Fire("PLAYER_DEAD")
	NS:CompanionStartTutorial(true)
	S.ok("sourdine : aucune bulle (combat, PNJ, repas, astuce, envie, câlin, tutoriel)",
		NS.companionBubbleKey == nil and not C.Shown(), NS.companionBubbleKey)
	NS:DB().companionChatter = 3
	S.done()
end

for _, name in ipairs(D.MOCKED) do _G[name] = D.saved[name] end
NS.COMPANION_RULES.npcCreatureChance = 0.5
NS.hubIndex = nil

C.RemoveModelAPI()
NS.JournalCounts = C.savedJournal
NS.WinterVeilSeason = C.savedSeason
if NS.WinterCompanionsForget then NS:WinterCompanionsForget() end
if NS.companionFrame then NS.companionFrame:Hide() end
