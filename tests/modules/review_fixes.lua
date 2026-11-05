-- Relecture de QuestCompanion (1.2.0) : un test par défaut corrigé.
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
	NS.companionRT, NS.companionSession, NS.memoryState = nil, nil, nil
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubbleKey = nil, nil, nil
end

do
	Say("-- relecture : correctifs")
	RF.Reset()
	-- textes : le pourcentage de mission en anglais, les astuces à « 100 % »
	local en = NS.DAILY_STRINGS.en.MIS_percent
	local ok, text = pcall(string.format, en, 3, "Westfall")
	Check("[FIX] mission « +3 % » en anglais : lisible", ok and text == "Gain 3% in Westfall", tostring(text))
	ok = pcall(NS.F, NS, "COMP_SAY_TIP_" .. 1)
	Check("[FIX] astuces : aucun « % » seul", ok)
	-- aperçu d'une créature normale : son rang écrit
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	NS:JournalPreviewCreature({ id = 1, rawName = "Loup", seen = true, killed = 2, levelText = "10" })
	local said = {}
	for _, line in ipairs(NS.journalFrame.comp.preview.lines) do said[#said + 1] = line.text or "" end
	Check("[FIX] créature normale : « Rang : normal »", table.concat(said, "|"):find("Rang : normal", 1, true) ~= nil,
		table.concat(said, "|"))
	Check("[FIX] fiches : 6 rangées, au-dessus du défilement", NS.JOURNAL_LAYOUT.cardRows == 6)
	-- Collection : plus d'objets qu'une page, la molette
	local f = NS.journalFrame
	f.sections.collection:Click()
	local saved = NS.JournalCollection
	NS.JournalCollection = function(self, kind)
		local list = saved(self, kind)
		for index = 1, 12 do list[#list + 1] = { kind = kind, def = { id = "extra" .. index }, owned = false, equipped = false,
			label = "Extra " .. index, tier = 0 } end
		return list
	end
	NS:RefreshJournal()
	NS:ScrollJournal(-1)
	Check("[FIX] Collection : la molette avance d'une rangée", f.collOffset == 5 and f.coll.items[1].entry ~= nil)
	NS.JournalCollection = saved
	f:Hide()
	-- nom : couper sans perdre un « é » complet
	local name = NS:CompanionSanitizeName(string.rep("a", 22) .. "éx")
	Check("[FIX] nom de 24 octets : le « é » complet reste", name == string.rep("a", 22) .. "é", name)
	name = NS:CompanionSanitizeName(string.rep("a", 23) .. "éx")
	Check("[FIX] nom coupé au milieu d'un « é » : il part", name == string.rep("a", 23), name)
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
	Say("-- relecture : PNJ, photos, conseils")
	RF.Reset()
	-- « parle à N personnes » : un PNJ compte une fois
	local daily = NS:DailyData()
	daily.day = NS:DailyToday()
	daily.missions = { { kind = "talks", need = 3, have = 0, source = "trait" } }
	daily.talked = {}
	_G.UnitGUID = function(unit) if unit == "npc" then return "Creature-0-1-1-1-777-0001" end return nil end
	NS:CompanionOnNpc("quest")
	NS:CompanionOnNpc("quest")
	Check("[FIX] même PNJ, deux fenêtres : compté une fois", daily.missions[1].have == 1, daily.missions[1].have)
	_G.UnitGUID = RF.saved.UnitGUID
	-- photos : une question laissée ouverte (rechargement) revient
	local shown = 0
	_G.StaticPopupDialogs = {}
	_G.StaticPopup_Show = function() shown = shown + 1 end
	NS:DB().companionPhotos, NS:DB().companionPhotosAsked = false, "asking"
	NS.memoryState = nil
	NS:MemoryWantPhoto({ kind = "level" })
	Check("[FIX] question des photos perdue au rechargement : redemandée", shown == 1)
	NS:MemoryWantPhoto({ kind = "level" })
	Check("[FIX] … mais pas deux fois dans la même session", shown == 1)
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
	Check("[FIX] élite vu en combat : rien de retenu", NS:AdviceSeeUnit("target") == false and NS:AdviceState().elite == nil)
	_G.InCombatLockdown = function() return false end
	Check("[FIX] hors combat : retenu", NS:AdviceSeeUnit("target") == true)
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

ResetWorld()
