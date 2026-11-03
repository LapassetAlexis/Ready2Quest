-- Module « Compagnon de route » (v1.25.0) : besoins (hausse, plancher),
-- somnolence après absence, évolution 10/20/40/60, réactions, bulles
-- (écart minimal, sourdine), cosmétiques débloqués par un FAUX Carnet de
-- voyage, choix d'apparence, repli sans modèle 3D, renommage, module coupé.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local C = {
	savedCreateFrame = _G.CreateFrame,
	savedJournal = rawget(NS, "JournalCounts"),
	models = {},
}

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
function C.Reset(level, withModel)
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
	Mock.world.level = level or 11
	Mock.world.mapID, Mock.world.subzone = 20, "Clairière"
end
-- Connexion : le premier PLAYER_ENTERING_WORLD de la session
function C.Login()
	NS.companionSession = nil
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
end
-- Laisse passer l'écart des bulles (sans faire tourner l'horloge des besoins)
function C.Quiet() NS.companionLastBubble = nil end
function C.Needs() return NS:CompanionData().needs end
function C.Key() return NS.companionBubbleKey end
function C.Shown() return NS.companionBubble ~= nil and NS.companionBubble:IsShown() == true end
function C.Play(minutes)
	for _ = 1, minutes do Mock:Advance(60) end
end
function C.Model() return NS.companionFrame and NS.companionFrame.model end

do
	Say("-- chargement, réglages, chaînes")
	C.Reset()
	Check("[COMP] fichiers chargés", NS.Loaded.Companion == true and NS.Loaded.CompanionData == true)
	local db = NS:DB()
	Check("[COMP] réglages par défaut", db.companionEnabled == true and db.companionShow == true and db.companionBubbles == true)
	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "companion" then page = def end end
	Check("[COMP] page MODULES avec interrupteur", page and page.group == "OPT_GROUP_MODULES" and page.power == "companionEnabled")
	Check("[COMP] module trouvé par ses alias", NS:FindModule("compagnon") and NS:FindModule("pet")
		and NS:FindModule("pet").key == "companionEnabled")
	local fr, en = NS.COMPANION_STRINGS.fr, NS.COMPANION_STRINGS.en
	local missing = {}
	for key, value in pairs(fr) do
		if type(en[key]) ~= "string" or en[key] == "" or value == "" then missing[#missing + 1] = key end
	end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	Check("[COMP] fr et en : mêmes clés, aucune vide", #missing == 0, table.concat(missing, ","))
	Check("[COMP] chaîne française active", NS.L.COMP_SAY_VIEW == "Quelle vue !" and NS.L.COMP_SAY_DEAD:find("Aïe", 1, true) == 1)
	-- toute clé de catalogue a son texte dans les deux langues
	local labels = {}
	for _, list in ipairs({ NS.COMPANION_APPEARANCES, NS.COMPANION_ORNAMENTS, NS.COMPANION_STAGES }) do
		for _, def in ipairs(list) do if not (fr[def.label] and en[def.label]) then labels[#labels + 1] = def.label end end
	end
	Check("[COMP] catalogue entièrement traduit", #labels == 0, table.concat(labels, ","))
	local ids = true
	for _, def in ipairs(NS.COMPANION_APPEARANCES) do ids = ids and type(def.display) == "number" and def.display > 0 end
	Check("[COMP] chaque apparence a un numéro d'affichage", ids)
	Check("[COMP] une apparence de départ sans condition", NS.COMPANION_APPEARANCES[1].unlock == nil)
end

do
	Say("-- première connexion")
	C.Reset(11)
	Mock:Reset()
	C.Login()
	local data = NS:CompanionData()
	Check("[COMP] bonjour à la première connexion", C.Key() == "HELLO" and C.Shown(), C.Key())
	Check("[COMP] nom par défaut dans la bulle", NS.companionBubbleText:find("Brindille", 1, true) ~= nil, NS.companionBubbleText)
	Check("[COMP] stade posé sans fête (niveau 11 : Jeune)", data.stage == 2 and not Mock:Output():find("devient", 1, true), data.stage)
	Check("[COMP] pas somnolent au premier jour", not data.sleepy)
	Check("[COMP] cadre affiché", NS.companionFrame and NS.companionFrame:IsShown())
	Check("[COMP] la bulle se referme seule", (function() Mock:Advance(7); return not C.Shown() end)())
end

do
	Say("-- besoins : baisse douce, jamais à zéro")
	C.Reset(11)
	C.Login()
	local start = C.Needs().hunger
	C.Play(30)
	Check("[COMP] la faim baisse en jouant", C.Needs().hunger < start, C.Needs().hunger)
	C.Play(600)    -- 10 h de jeu sans rien faire
	local low = true
	for _, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		low = low and C.Needs()[key] >= NS.COMPANION_RULES.floor and C.Needs()[key] > 0
	end
	Check("[COMP] après 10 h : aucun besoin sous le plancher", low, C.Needs().hunger .. "/" .. C.Needs().mood)
	Check("[COMP] plancher atteint (la baisse a bien eu lieu)", C.Needs().curiosity == NS.COMPANION_RULES.floor, C.Needs().curiosity)
	-- une valeur corrompue de la sauvegarde est ramenée dans les bornes
	NS:CompanionData().needs.mood = -40
	Check("[COMP] sauvegarde corrompue ramenée au plancher", NS:CompanionData().needs.mood == NS.COMPANION_RULES.floor)
	NS:CompanionAdd("mood", 500)
	Check("[COMP] jamais plus de 100", C.Needs().mood == 100)
end

do
	Say("-- besoins : ce qui les fait monter")
	C.Reset(11)
	C.Login()
	for _, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do C.Needs()[key] = 40 end
	-- repas : aura « Nourriture »
	C.Quiet()
	Mock.world.auraOrder = { 433 }
	Mock.world.auras = { [433] = { name = "Nourriture", duration = 30 } }
	Mock:Fire("UNIT_AURA", "player")
	Check("[COMP] manger : la faim remonte", C.Needs().hunger >= 75, C.Needs().hunger)
	Check("[COMP] manger : « Miam ! »", C.Key() == "EAT", C.Key())
	local h = C.Needs().hunger
	Mock:Fire("UNIT_AURA", "player")
	Check("[COMP] même repas : compté une fois", C.Needs().hunger == h)
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	Mock:Fire("UNIT_AURA", "player")
	-- repos à l'auberge
	Mock.world.resting = true
	local e = C.Needs().energy
	C.Play(5)
	Check("[COMP] au repos : l'énergie remonte", C.Needs().energy > e, e .. " -> " .. C.Needs().energy)
	Mock.world.resting = false
	-- quête rendue
	C.Quiet()
	local m = C.Needs().mood
	Mock:Fire("QUEST_TURNED_IN", 123, 500, 0)
	Check("[COMP] quête rendue : le moral monte", C.Needs().mood > m and C.Key() == "QUEST", C.Key())
	-- nouvelle zone
	C.Quiet()
	local c = C.Needs().curiosity
	Mock.world.mapID = 30
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[COMP] nouvelle zone : curiosité et « Quelle vue ! »", C.Needs().curiosity > c and C.Key() == "VIEW", C.Key())
	C.Quiet()
	c = C.Needs().curiosity
	Mock.world.mapID = 20
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[COMP] zone de connexion déjà connue : rien", C.Needs().curiosity == c and NS.companionLastBubble == nil)
	c = C.Needs().curiosity
	Mock.world.subzone = "Vieux moulin"
	Mock:Fire("ZONE_CHANGED")
	Check("[COMP] nouvelle sous-zone : un peu de curiosité", C.Needs().curiosity > c)
	-- butin notable
	C.Quiet()
	m = C.Needs().mood
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : |cff0070dd|Hitem:4444::::::::|h[Épée bleue]|h|r.")
	Check("[COMP] butin rare : moral et « ça brille »", C.Needs().mood > m and C.Key() == "LOOT", C.Key())
	C.Quiet()
	m = C.Needs().mood
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : |cff9d9d9d|Hitem:5555::::::::|h[Caillou]|h|r.")
	Check("[COMP] butin gris : rien", C.Needs().mood == m and NS.companionLastBubble == nil)
end

do
	Say("-- absence : somnolent, sans pénalité")
	C.Reset(11)
	C.Login()
	local data = NS:CompanionData()
	data.needs.hunger, data.needs.mood = 63, 71
	data.lastSeen = time() - 10 * 3600     -- 10 h d'absence
	C.Login()
	Check("[COMP] après 10 h : somnolent", data.sleepy == true)
	Check("[COMP] « Tu m'as manqué ! »", C.Key() == "MISSED", C.Key())
	Check("[COMP] aucune pénalité sur les besoins", data.needs.hunger == 63 and data.needs.mood == 71, data.needs.hunger)
	Check("[COMP] humeur somnolente, animation de sommeil", NS:CompanionMood() == "sleepy" and NS.companionFrame.animation == "sleep")
	Check("[COMP] somnolence proportionnée (10 h -> 200 s)", data.sleepyLeft == 200, data.sleepyLeft)
	C.Play(4)
	Check("[COMP] il se réveille en jouant", not data.sleepy and C.Key() == "AWAKE", C.Key())
	-- 60 jours : plafond
	data.lastSeen = time() - 60 * 86400
	C.Login()
	Check("[COMP] longue absence : somnolence plafonnée", data.sleepyLeft == NS.COMPANION_RULES.sleepyMax, data.sleepyLeft)
	Check("[COMP] longue absence : besoins intacts", data.needs.mood >= 15)
	-- 30 min : rien
	NS:CompanionWake(false)
	data.lastSeen = time() - 1800
	C.Login()
	Check("[COMP] courte absence : pas somnolent", not data.sleepy)
	-- PEW suivant (écran de chargement) : pas de nouveau relevé
	data.lastSeen = time() - 10 * 3600
	Mock:Fire("PLAYER_ENTERING_WORLD", false, false)
	Check("[COMP] écran de chargement : pas de relevé d'absence", not data.sleepy)
end

do
	Say("-- évolution 10 / 20 / 40 / 60")
	C.Reset(5)
	C.Login()
	local data = NS:CompanionData()
	Check("[COMP] niveau 5 : Nouveau-né", data.stage == 1)
	local scales = { C.Model() and C.Model().modelScale }
	local evolved = {}
	for _, level in ipairs({ 10, 20, 40, 60 }) do
		Mock.world.level = level
		Mock:Reset()
		C.Quiet()
		Mock:Fire("PLAYER_LEVEL_UP", level)
		evolved[#evolved + 1] = data.stage
		scales[#scales + 1] = C.Model() and C.Model().modelScale
		Check("[COMP] niveau " .. level .. " : fête (bulle + chat + danse)", C.Key() == "EVOLVE"
			and Mock:Output():find("devient", 1, true) ~= nil and NS.companionFrame.animation == "dance", C.Key())
	end
	Check("[COMP] stades 2, 3, 4, 5", table.concat(evolved, ",") == "2,3,4,5", table.concat(evolved, ","))
	local growing = true
	for i = 2, #scales do growing = growing and scales[i] and scales[i] > scales[i - 1] end
	Check("[COMP] le modèle grandit à chaque stade", growing, table.concat(scales, ","))
	Check("[COMP] nom du stade dans la bulle", NS.companionBubbleText:find("Légendaire", 1, true) ~= nil, NS.companionBubbleText)
	Mock:Advance(4)
	Check("[COMP] la danse s'arrête", NS.companionFrame.animation == "idle", NS.companionFrame.animation)
	NS:CompanionCheckStage(12, true)
	Check("[COMP] jamais de retour en arrière", data.stage == 5)
	-- niveau sans palier : bravo simple
	C.Reset(11)
	C.Login()
	C.Quiet()
	Mock.world.level = 12
	Mock:Fire("PLAYER_LEVEL_UP", 12)
	Check("[COMP] niveau 12 : « Niveau 12 ! »", C.Key() == "LEVEL" and NS.companionBubbleText:find("12", 1, true), C.Key())
end

do
	Say("-- réactions : départ, retour, mort, tampon, camp")
	C.Reset(11)
	C.Login()
	C.Quiet()
	NS:FireCallback("DEPARTURE", { name = "Comté-de-l'Or" })
	Check("[COMP] départ sans vivres : il le fait remarquer", C.Key() == "NOFOOD", C.Key())
	Check("[COMP] ... gentiment (pas de reproche)", NS.companionBubbleText:find("grignoter", 1, true) ~= nil)
	C.Quiet()
	Mock.world.itemInfo[117] = { classID = 0, subClassID = 5 }
	Mock.world.bags[0].items[1] = { itemID = 117, stackCount = 5 }
	local h = C.Needs().hunger
	NS:FireCallback("DEPARTURE", { name = "Comté-de-l'Or" })
	Check("[COMP] départ avec vivres : en route, la faim monte", C.Key() == "DEPART" and C.Needs().hunger > h, C.Key())
	C.Quiet()
	NS:FireCallback("RETURN", { name = "Comté-de-l'Or" })
	Check("[COMP] retour : « on est rentrés »", C.Key() == "RETURN", C.Key())
	C.Quiet()
	Mock:Fire("PLAYER_DEAD")
	Check("[COMP] mort : « Aïe… »", C.Key() == "DEAD" and NS.companionBubbleText:find("Aïe", 1, true) == 1, C.Key())
	C.Quiet()
	local c = C.Needs().curiosity
	NS:FireCallback("STAMP", { id = "zone:1519", kind = "zone", name = "Hurlevent", new = true })
	Check("[COMP] tampon : curiosité et bulle avec le nom", C.Needs().curiosity > c and C.Key() == "STAMP"
		and NS.companionBubbleText:find("Hurlevent", 1, true), NS.companionBubbleText)
	C.Quiet()
	c = C.Needs().curiosity
	NS:FireCallback("STAMP", { id = "zone:1519", kind = "zone", name = "Hurlevent", new = false })
	Check("[COMP] tampon déjà vu : rien", C.Needs().curiosity == c and NS.companionLastBubble == nil)
	-- feu de camp (Forever) : aura « Campfire Nearby »
	C.Quiet()
	Mock.world.auras = { [1283391] = { name = "Campfire Nearby", duration = 0 } }
	Mock.world.auraOrder = { 1283391 }
	Mock:Fire("UNIT_AURA", "player")
	Check("[COMP] feu de camp : « On se réchauffe ? »", C.Key() == "CAMP", C.Key())
	local e = C.Needs().energy
	C.Play(3)
	Check("[COMP] au camp : l'énergie remonte", C.Needs().energy > e)
end

do
	Say("-- bulles : écart minimal et sourdine")
	C.Reset(11)
	C.Login()
	C.Quiet()
	Check("[COMP] première bulle affichée", NS:CompanionSay("QUEST") == true)
	Check("[COMP] deuxième bulle trop tôt : retenue", NS:CompanionSay("DEAD") == false and C.Key() == "QUEST")
	Mock:Fire("PLAYER_DEAD")
	Check("[COMP] rafale d'événements : toujours une seule bulle", C.Key() == "QUEST")
	Mock.now = Mock.now + NS.COMPANION_RULES.bubbleGap + 1
	Check("[COMP] après l'écart : de nouveau permise", NS:CompanionSay("DEAD") == true and C.Key() == "DEAD")
	Check("[COMP] une bulle prioritaire passe l'écart", NS:CompanionSay("EVOLVE", { force = true, args = { "X" } }) == true)
	C.Quiet()
	NS:DB().companionBubbles = false
	NS.companionBubbleKey = nil
	Check("[COMP] sourdine : aucune bulle", NS:CompanionSay("QUEST") == false and NS:CompanionSay("UNLOCK", { force = true }) == false
		and C.Key() == nil)
	Mock:Reset()
	NS:HandleCommand("compagnon muet")
	Check("[COMP] « muet » rallume les bulles", NS:DB().companionBubbles == true and Mock:Output():find("Bulles", 1, true))
	NS:HandleCommand("compagnon muet")
	Check("[COMP] « muet » les recoupe", NS:DB().companionBubbles == false)
	NS:DB().companionBubbles = true
	NS:DB().companionShow = false
	NS:CompanionUpdateVisibility()
	C.Quiet()
	Check("[COMP] cadre masqué : ni cadre ni bulle", NS:CompanionSay("QUEST") == false and not NS.companionFrame:IsShown())
	NS:DB().companionShow = true
end

do
	Say("-- cosmétiques : faux Carnet de voyage")
	C.Reset(11)
	C.Login()
	Check("[COMP] sans Carnet : compteurs à zéro", NS:CompanionCounts().total == 0 and NS:CompanionCounts().zone == 0)
	Check("[COMP] sans Carnet : seule l'apparence de départ", #NS:CompanionUnlockedAppearances() == 1)
	local fake = { zone = 5, subzone = 10, dungeon = 0, rare = 0, level = 0, total = 15 }
	NS.JournalCounts = function() return fake end
	Mock:Reset()
	C.Quiet()
	NS:FireCallback("STAMP", { id = "subzone:42", kind = "subzone", name = "Vieux moulin", new = true })
	local data = NS:CompanionData()
	Check("[COMP] 5 zones : dragonnet cramoisi débloqué", data.unlocked["app:whelp_red"] == true)
	Check("[COMP] 10 lieux : rainette débloquée", data.unlocked["app:frog"] == true)
	Check("[COMP] 4 zones de trop peu : pas de ruban", not data.unlocked["orn:ribbon"])
	Check("[COMP] déblocage annoncé dans le chat", Mock:Output():find("nouvelle apparence", 1, true) ~= nil, Mock:Output())
	Check("[COMP] déblocage annoncé en bulle (prioritaire sur le tampon)", C.Key() == "UNLOCK", C.Key())
	fake.zone = 10
	Mock:Reset()
	NS:FireCallback("STAMP", { id = "zone:12", kind = "zone", name = "Elwynn", new = true })
	Check("[COMP] 10 zones : ruban débloqué", data.unlocked["orn:ribbon"] == true and Mock:Output():find("ornement", 1, true))
	Check("[COMP] ruban affiché sur le cadre", NS.companionFrame.ornaments.ribbon:IsShown())
	NS:DB().companionOrnRibbon = false
	NS:CompanionApplyOrnaments()
	Check("[COMP] ruban coupé dans les réglages : masqué", not NS.companionFrame.ornaments.ribbon:IsShown())
	NS:DB().companionOrnRibbon = true
	Check("[COMP] lanterne encore verrouillée : masquée", not NS.companionFrame.ornaments.lantern:IsShown())
	-- le Carnet disparaît (module coupé) : rien n'est repris
	NS.JournalCounts = nil
	NS:CompanionCheckUnlocks()
	Check("[COMP] déblocages définitifs", data.unlocked["app:whelp_red"] and data.unlocked["orn:ribbon"])
	-- un Carnet qui plante ne casse rien
	NS.JournalCounts = function() error("boom") end
	Check("[COMP] Carnet en erreur : compteurs à zéro", NS:CompanionCounts().zone == 0)
	NS.JournalCounts = nil
	-- conditions de niveau
	Mock.world.level = 60
	Mock:Fire("PLAYER_LEVEL_UP", 60)
	Check("[COMP] niveau 60 : cadre doré et dragonnet sombre", data.unlocked["orn:gold"] and data.unlocked["app:whelp_black"]
		and data.unlocked["app:owl"] and data.unlocked["app:whelp_blue"])
	Check("[COMP] cadre doré affiché", NS.companionFrame.ornaments.gold:IsShown())
	Check("[COMP] condition lisible", NS:CompanionRequirement({ stamp = "dungeon", count = 5 }) == "5 donjons"
		and NS:CompanionRequirement({ level = 20 }) == "niveau 20")
end

do
	Say("-- choix d'apparence")
	C.Reset(11)
	C.Login()
	local data = NS:CompanionData()
	Check("[COMP] modèle 3D : apparence de départ affichée", C.Model() and C.Model().display == 6291, C.Model() and C.Model().display)
	Check("[COMP] une seule apparence : le cycle y reste", NS:CompanionCycleAppearance().id == "whelp_green")
	NS.JournalCounts = function() return { zone = 5, subzone = 10 } end
	NS:CompanionCheckUnlocks(nil, true)
	NS.JournalCounts = nil
	local seen = {}
	for _ = 1, 3 do seen[#seen + 1] = NS:CompanionCycleAppearance().id end
	Check("[COMP] le cycle ne passe que par les apparences débloquées", table.concat(seen, ",") == "frog,whelp_red,whelp_green",
		table.concat(seen, ","))
	NS:RunOptionAction("companionAppearance")
	Check("[COMP] bouton des réglages : apparence suivante", data.appearance == "frog" and C.Model().display == 6295, data.appearance)
	-- apparence verrouillée dans la sauvegarde : retour à celle de départ
	data.appearance = "whelp_black"
	Check("[COMP] apparence non débloquée refusée", NS:CompanionCurrentAppearance().id == "whelp_green")
	-- page de réglages : nom de l'apparence et verrous
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companion")
	local appRow, lanternRow
	for _, row in ipairs(NS.optionsFrame.rows) do
		if row.def and row.def.key == "companionAppearance" then appRow = row end
		if row.def and row.def.key == "companionOrnLantern" then lanternRow = row end
	end
	Check("[COMP] réglages : nom de l'apparence affiché", appRow and appRow.value.text:find("Dragonnet émeraude", 1, true), appRow and appRow.value.text)
	Check("[COMP] réglages : ornement verrouillé avec sa condition", lanternRow and lanternRow.label.text:find("25 lieux", 1, true),
		lanternRow and lanternRow.label.text)
	Check("[COMP] page sans débordement", NS.optionsFrame.pages.companion.contentBottom >= NS.OPT_LAYOUT.contentLimit,
		NS.optionsFrame.pages.companion.contentBottom)
	NS.optionsFrame:Hide()
end

do
	Say("-- repli sans modèle 3D")
	C.Reset(11, false)          -- CreateFrame du mock : pas de SetDisplayInfo
	C.Login()
	local frame = NS.companionFrame
	Check("[COMP] sans API de modèle : boussole affichée", frame.usesFallback == true and frame.fallback:IsShown()
		and frame.fallback.texture == NS.Theme.LOGO_SMALL, tostring(frame.fallback.texture))
	Check("[COMP] sans API de modèle : pas de modèle", frame.model == nil)
	Check("[COMP] sans API de modèle : bulles et caresses marchent", C.Key() == "HELLO" and NS:CompanionPet() == true)
	Mock:Reset()
	NS:HandleCommand("compagnon")
	Check("[COMP] statut : repli signalé", Mock:Output():find("boussole", 1, true) ~= nil)
	-- modèle présent mais affichage refusé : repli aussi
	C.Reset(11, false)
	C.InstallModelAPI(true)
	C.Login()
	Check("[COMP] SetDisplayInfo en erreur : boussole", NS.companionFrame.usesFallback == true and NS.companionFrame.fallback:IsShown())
	C.Reset(11)
	C.Login()
	Check("[COMP] avec modèle : boussole cachée", NS.companionFrame.usesFallback == false and not NS.companionFrame.fallback:IsShown())
	Check("[COMP] avec modèle : animation de repos", C.Model().anim == NS.COMPANION_ANIMS.idle)
	Mock:Advance(1)
	Check("[COMP] avec modèle : léger balancement", type(C.Model().rotation) == "number")
end

do
	Say("-- caresse, survol")
	C.Reset(11)
	C.Login()
	C.Quiet()
	C.Needs().mood = 50
	NS.companionFrame.scripts.OnMouseDown(NS.companionFrame)
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "LeftButton")
	Check("[COMP] clic : moral +8 et bulle mignonne", C.Needs().mood == 58 and (C.Key() or ""):find("^PET_"), C.Key())
	Check("[COMP] clic : animation de joie", NS.companionFrame.animation == "cheer")
	Check("[COMP] caresse trop tôt : sans effet", NS:CompanionPet() == false and C.Needs().mood == 58)
	Mock.now = Mock.now + NS.COMPANION_RULES.petCooldown + 1
	Check("[COMP] après la pause : de nouveau", NS:CompanionPet() == true and C.Needs().mood == 66)
	-- glisser n'est pas caresser
	Mock.now = Mock.now + 60
	Mock.world.cursorX = 500
	NS.companionFrame.scripts.OnMouseDown(NS.companionFrame)
	Mock.world.cursorX = 560
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "LeftButton")
	Check("[COMP] glisser le cadre : pas de caresse", C.Needs().mood == 66)
	Mock.world.cursorX = nil
	-- une caresse réveille
	local data = NS:CompanionData()
	data.sleepy, data.sleepyLeft = true, 300
	Mock.now = Mock.now + 60
	NS:CompanionPet()
	Check("[COMP] une caresse le réveille", not data.sleepy and C.Key() == "PET_sleepy", C.Key())
	NS.companionFrame.scripts.OnEnter(NS.companionFrame)
	local hover = NS.companionHover
	Check("[COMP] survol : quatre barres de besoins", hover and hover:IsShown() and hover.bars.hunger and hover.bars.energy
		and hover.bars.mood and hover.bars.curiosity)
	Check("[COMP] survol : barre au bon niveau", math.abs(hover.bars.mood.ratio - C.Needs().mood / 100) < 0.001, hover.bars.mood.ratio)
	NS.companionFrame.scripts.OnLeave(NS.companionFrame)
	Check("[COMP] fin du survol : masqué", not hover:IsShown())
end

do
	Say("-- commande, renommage")
	C.Reset(11)
	C.Login()
	Mock:Reset()
	NS:HandleCommand("compagnon nom   Pépite  ")
	Check("[COMP] renommé", NS:CompanionName() == "Pépite" and NS.companionFrame.name.text == "Pépite", NS:CompanionName())
	Check("[COMP] renommage confirmé", Mock:Output():find("Pépite", 1, true) ~= nil)
	NS:HandleCommand("compagnon nom |cffff0000Rouge|r")
	Check("[COMP] codes de couleur retirés", NS:CompanionName() == "Rouge", NS:CompanionName())
	Mock:Reset()
	NS:HandleCommand("compagnon nom    ")
	Check("[COMP] nom vide refusé", not NS:CompanionName():find("^%s*$") and Mock:Output():find("Donne-lui un nom", 1, true))
	NS:HandleCommand("compagnon nom " .. string.rep("é", 20))
	local name = NS:CompanionName()
	Check("[COMP] nom trop long coupé sans casser l'UTF-8", #name <= 24 and #name % 2 == 0 and name:sub(1, 2) == "é", #name)
	Mock:Reset()
	NS:HandleCommand("compagnon")
	local out = Mock:Output()
	Check("[COMP] statut : nom, stade, besoins, collection", out:find(NS:CompanionName(), 1, true) and out:find("Jeune", 1, true)
		and out:find("Faim", 1, true) and out:find("Apparences 1/9", 1, true), out)
	NS:HandleCommand("compagnon apparence")
	Check("[COMP] « apparence » : cycle et confirmation", Mock:Output():find("Apparence :", 1, true) ~= nil)
	Check("[COMP] aide : commande listée", (function()
		for _, section in ipairs(NS.HELP) do
			for _, key in ipairs(section[2]) do if key == "HELP_COMPANION" then return true end end
		end
		return false
	end)())
end

do
	Say("-- module coupé : plus rien")
	C.Reset(11)
	C.Login()
	Mock:Reset()
	NS:HandleCommand("module compagnon off")
	Check("[COMP] module coupé : cadre masqué", NS:DB().companionEnabled == false and not NS.companionFrame:IsShown())
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
	Check("[COMP] module coupé : aucun besoin ne bouge", same)
	Check("[COMP] module coupé : aucune bulle", C.Key() == nil and not C.Shown())
	Check("[COMP] module coupé : pas d'évolution", NS:CompanionData().stage == 2)
	Check("[COMP] module coupé : pas de caresse", NS:CompanionPet() == false)
	Mock:Reset()
	NS:HandleCommand("compagnon")
	Check("[COMP] module coupé : la commande le dit", Mock:Output():find("coupé", 1, true) ~= nil)
	NS:ToggleModuleKey("companionEnabled")
	Check("[COMP] interrupteur de la navigation : rallumé et affiché", NS:DB().companionEnabled == true and NS.companionFrame:IsShown())
	NS:DB().enabled = false
	Check("[COMP] addon coupé : compagnon inactif", NS:CompanionPet() == false)
	NS:DB().enabled = true
end

C.RemoveModelAPI()
NS.JournalCounts = C.savedJournal
if NS.companionFrame then NS.companionFrame:Hide() end
