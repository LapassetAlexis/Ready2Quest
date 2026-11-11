-- Relecture de QuestCompanion (1.2.0) et correctifs Forever : un test par
-- défaut corrigé. Astuces sans « % » seul, rang d'une créature normale dans
-- l'aperçu, nom coupé sans casser l'UTF-8, niveau dit au cran Calme, pas de
-- rappel en niveaux quand l'évolution est prête, conseils (élite vu en
-- combat), rare engagé oublié, morts comptées par le message d'XP, valeurs
-- secrètes (vie, remarque du caractère). Missions (« +3 % » en anglais, un
-- PNJ compté une fois) : missions.lua et companion_daily.lua.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local RF = { saved = {} }
for _, name in ipairs({ "UnitGUID", "InCombatLockdown", "UnitAffectingCombat", "UnitExists", "UnitIsDead", "UnitCanAttack",
	"UnitClassification", "UnitLevel", "UnitName", "IsInInstance", "StaticPopup_Show", "StaticPopupDialogs", "UnitIsPlayer" }) do
	RF.saved[name] = rawget(_G, name)
end
function RF.Restore() for name, fn in pairs(RF.saved) do _G[name] = fn end end
function RF.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession = nil, nil
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubbleKey = nil, nil, nil
end

do
	Say("-- relecture : correctifs")
	RF.Reset()
	-- textes : les astuces à « 100 % »
	local ok = pcall(NS.F, NS, "COMP_SAY_TIP_" .. 1)
	Check("[FIX] astuces : aucun « % » seul", ok)
	-- aperçu d'une créature normale : son rang écrit (la fiche de Zone est
	-- retirée, l'aperçu des créatures est celui de la Ménagerie)
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	NS:SelectJournalKind("menagerie")
	NS:JournalPreviewMenagerie({ npc = 1, no = 1, name = "Loup", known = true, class = "normal", level = 10, killed = 2 })
	local said = {}
	for _, line in ipairs(NS.journalFrame.men.preview.lines) do said[#said + 1] = line.text or "" end
	Check("[FIX] créature normale : « Normal · niveau 10 »", table.concat(said, "|"):find("Normal · niveau 10", 1, true) ~= nil,
		table.concat(said, "|"))
	-- (fiches du Combat sur 6 rangées et molette de la grille Collection : retirées
	-- avec la page Zone et la page Collection)
	NS.journalFrame:Hide()
	-- nom : couper sans perdre un « é » complet
	local name = NS:CompanionSanitizeName(string.rep("a", 22) .. "éx")
	local cut = NS:CompanionSanitizeName(string.rep("a", 23) .. "éx")
	Check("[FIX] nom de 24 octets : le « é » complet reste, coupé au milieu il part", name == string.rep("a", 22) .. "é"
		and cut == string.rep("a", 23), name .. " / " .. cut)
	-- un niveau : grand moment, dit au cran Calme
	NS:DB().companionChatter = 2
	NS:CompanionOnLevel(13)
	Check("[FIX] cran Calme : le niveau est dit", NS.companionBubbleKey ~= nil, tostring(NS.companionBubbleKey))
	NS:DB().companionChatter = 3
	-- prêt à évoluer : pas de « encore 2 niveaux »
	local real = NS.CompanionNextUnlocks
	NS.CompanionNextUnlocks = function() return { { label = "Vaillant", kind = "stage", stat = "happy", have = 2, need = 4,
		source = "player", ready = true } } end
	NS.companionRT.goalAt = 0
	Check("[FIX] prêt à évoluer : pas de rappel en niveaux", NS:CompanionTryGoal() == false)
	NS.CompanionNextUnlocks = real
end

do
	Say("-- relecture : conseils")
	RF.Reset()
	-- conseils : un élite vu en plein combat n'est pas annoncé après
	_G.IsInInstance = function() return false, "none" end
	_G.UnitExists = function() return true end
	_G.UnitIsDead = function() return false end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function() return "elite" end
	_G.UnitLevel = function(unit) if unit == "player" or unit == nil then return 10 end return 20 end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return "Ogre" end
	_G.UnitGUID = function() return "Creature-0-1-1-1-888-0001" end
	_G.InCombatLockdown = function() return true end
	local inCombat = NS:AdviceSeeUnit("target") == false and NS:AdviceState().elite == nil
	_G.InCombatLockdown = function() return false end
	Check("[FIX] élite vu en combat : rien de retenu ; hors combat : retenu", inCombat and NS:AdviceSeeUnit("target") == true)
	RF.Restore()
end

do
	Say("-- relecture : rare engagé puis laissé")
	RF.Reset()
	NS.journalRares = { ["Creature-0-1-1-1-999-0001"] = { name = "Rare", engaged = true, seen = Mock.now - 4000 } }
	_G.UnitIsPlayer = function() return false end
	_G.UnitGUID = function() return "Creature-0-1-1-1-998-0001" end
	_G.UnitName = function() return "Autre rare" end
	_G.UnitClassification = function() return "rare" end
	NS:JournalSeeUnit("target")
	Check("[FIX] rare engagé il y a plus de 30 min : oublié", NS.journalRares["Creature-0-1-1-1-999-0001"] == nil)
	RF.Restore()
end

do
	Say("-- bestiaire : morts par le message d'XP (Forever)")
	RF.Reset()
	Mock.world.maps[9950] = { mapID = 9950, name = "Val de l'XP", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID = 9950
	NS.bestiaryUnits, NS.bestiaryKilled = {}, {}
	local w = { dead = false, guid = "Creature-0-4378-1-12-6100-0000AAAA01" }
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-1" end if unit == "target" then return w.guid end end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return "Loup" end
	_G.UnitExists = function() return true end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function(unit) return unit == "target" and w.dead end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function() return "normal" end
	_G.UnitLevel = function() return 10 end
	NS:BestiarySeeUnit("target")
	local book = NS:BestiaryData()[9950]
	Check("[BSTXP] cible vue : au bestiaire", book and book[6100] and book[6100].killed == 0)
	local before = NS.bestiaryStats.xpKills
	w.dead = true
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 40 points d'expérience.")
	Check("[BSTXP] sans journal de combat : la mort comptée par l'XP", book[6100].killed == 1
		and NS.bestiaryStats.xpKills == before + 1, book[6100].killed)
	NS:BestiaryCombat("PARTY_KILL", "Player-1-1", 0, w.guid, 0)
	Check("[BSTXP] le journal de combat arrive après : pas compté deux fois", book[6100].killed == 1)
	-- l'inverse : le journal d'abord, l'XP ensuite
	w.guid, w.dead = "Creature-0-4378-1-12-6100-0000AAAA02", false
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", "Player-1-1", 0, w.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", "Player-1-1", 0, w.guid, 0)
	w.dead = true
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 40 points d'expérience.")
	Check("[BSTXP] journal puis XP : une seule mort de plus", book[6100].killed == 2, book[6100].killed)
	-- cible vivante (l'XP vient d'un autre monstre) : rien
	w.guid, w.dead = "Creature-0-4378-1-12-6100-0000AAAA03", false
	NS:BestiarySeeUnit("target")
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Loup meurt, vous gagnez 40 points d'expérience.")
	Check("[BSTXP] cible encore vivante, ou XP sans nom (quête) : rien", book[6100].killed == 2
		and NS:BestiaryOnXP("Vous gagnez 40 points d'expérience.") == false)
	-- /qc diag : ce que le bestiaire a reçu
	local lines = {}
	local print = NS.Print
	NS.Print = function(_, text) lines[#lines + 1] = tostring(text) end
	NS:DiagExtra()
	NS.Print = print
	Check("[BSTXP] /qc diag : la ligne du bestiaire", table.concat(lines, " "):find("victimes comptées", 1, true) ~= nil,
		table.concat(lines, " | "))
	RF.Restore()
end

do
	Say("-- valeurs secrètes (Forever) : vie et icône de cible")
	RF.Reset()
	-- comme en jeu : tonumber la laisse passer, tout calcul ou comparaison échoue
	local function Refuse() error("attempt to perform arithmetic on a secret number value") end
	local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end, __div = Refuse, __lt = Refuse,
		__le = Refuse, __sub = Refuse, __add = Refuse, __mul = Refuse })
	local realTonumber = tonumber
	_G.tonumber = function(v, ...) if v == SECRET then return SECRET end return realTonumber(v, ...) end
	local saved = { rawget(_G, "issecretvalue"), rawget(_G, "UnitHealth"), rawget(_G, "UnitHealthMax"),
		rawget(_G, "UnitAffectingCombat"), rawget(_G, "GetRaidTargetIndex") }
	_G.issecretvalue = function(v) return v == SECRET end
	_G.UnitHealth = function() return SECRET end
	_G.UnitHealthMax = function() return SECRET end
	_G.UnitAffectingCombat = function() return true end
	Check("[SECRET] ns.Plain : la valeur secrète devient nil", NS.Plain(SECRET) == nil and NS.Plain(42) == 42)
	NS.errors = {}
	Mock:Fire("PLAYER_REGEN_ENABLED")
	local errs = {}
	for _, e in ipairs(NS.errors) do errs[#errs + 1] = tostring(e.where) .. " : " .. tostring(e.message) end
	Check("[SECRET] fin de combat, vie secrète : aucune erreur, pas de conseil « vie basse »", #errs == 0
		and NS:AdviceState().health == nil, table.concat(errs, " || "))
	local failed = {}
	for _, look in ipairs({ "turtle", "chicken" }) do
		NS:CompanionData().appearance = look
		local ok, err = pcall(NS.PersonaTickNotice, NS, Mock.now, NS:PersonaState())
		if not ok then failed[#failed + 1] = look .. " : " .. tostring(err) end
	end
	Check("[SECRET] remarque du caractère (tortue, poulet) : pas d'erreur", #failed == 0, table.concat(failed, " || "))
	_G.issecretvalue, _G.UnitHealth, _G.UnitHealthMax, _G.UnitAffectingCombat, _G.GetRaidTargetIndex =
		saved[1], saved[2], saved[3], saved[4], saved[5]
	_G.tonumber = realTonumber
end

ResetWorld()
