-- QuestCompanion 2.4 : exploits de la ménagerie annoncés à la guilde (GuildFeats.lua).
-- Envoi (réglages, guilde, combat, format versionné E~1~…, regroupement, écart), crochets de
-- capture / sceau / palier, réception stricte (canal, soi, champs, identifiants
-- inconnus), file des bandeaux, son, clic vers la fiche, découverte au survol,
-- réessai quand le client refuse un message pour cause de débit.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local GF = { saved = {} }
local GLOBALS = { "C_ChatInfo", "UnitName", "UnitFullName", "UnitIsPlayer", "UnitIsFriend", "UnitFactionGroup",
	"InCombatLockdown", "UnitAffectingCombat", "IsInGroup", "IsInRaid", "IsInGuild", "time", "GetNormalizedRealmName",
	"PlaySound", "IsInInstance", "GetRealZoneText" }
for _, name in ipairs(GLOBALS) do GF.saved[name] = rawget(_G, name) end
GF.saved.ZONE_CREATURES = rawget(NS, "ZONE_CREATURES")
GF.saved.GetUnit = GameTooltip.GetUnit

-- Durotar (une zone : un sanglier, une élite, un rare) et Mulgore (un kodo seul)
local ZONES = {
	[1411] = {
		[3098] = { lvl = { 1, 2 }, rank = 0, fr = "Sanglier tacheté", en = "Mottled Boar" },
		[3099] = { lvl = { 6, 7 }, rank = 1, fr = "Garde kolkar", en = "Kolkar Guard" },
		[3100] = { lvl = { 8, 9 }, rank = 4, fr = "Griffe-sanglante", en = "Bloodclaw" },
	},
	[1412] = { [201] = { lvl = { 5, 6 }, rank = 0, fr = "Kodo", en = "Kodo" } },
}

function GF.Reset()
	ResetWorld()
	NS:TrainerResetSession()
	NS:GuildFeatsReset()
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	GF.sent, GF.sounds, GF.codes = {}, {}, {}
	GF.now = 1800000000
	GF.combat, GF.lockdown, GF.guild = false, false, true
	GF.units = {}
	Mock.world.maps[1411] = { mapID = 1411, name = "Durotar", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1412] = { mapID = 1412, name = "Mulgore", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1411, 20
	NS.ZONE_CREATURES = ZONES
	_G.time = function() return GF.now end
	_G.C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return 0 end,
		SendAddonMessage = function(prefix, text, channel, target)
			local code = table.remove(GF.codes, 1)
			if code then return code end
			GF.sent[#GF.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
			return 0
		end,
		InChatMessagingLockdown = function() return GF.lockdown end,
	}
	_G.InCombatLockdown = function() return GF.combat end
	_G.UnitAffectingCombat = function() return GF.combat end
	_G.UnitName = function(unit)
		if unit == "player" then return "Testeur" end
		local u = GF.units[unit]
		if u then return u.name, u.realm end
		return nil
	end
	_G.UnitFullName = nil
	_G.UnitIsPlayer = function(unit) return GF.units[unit] ~= nil end
	_G.UnitIsFriend = function() return true end
	_G.UnitFactionGroup = function() return "Horde" end
	_G.IsInGroup = function() return false end
	_G.IsInRaid = function() return false end
	_G.IsInGuild = function() return GF.guild end
	_G.IsInInstance = function() return false, "none" end
	_G.GetRealZoneText = function() return "" end
	_G.GetNormalizedRealmName = function() return "Royaume" end
	_G.PlaySound = function(id) GF.sounds[#GF.sounds + 1] = id; return true end
	local db = NS:DB()
	db.guildFeatsSend, db.guildFeatsShow, db.guildFeatsChat, db.trainerShare = nil, nil, nil, true
	db.companionCaptureSound, db.captureMuteUntil = nil, nil
	local data = NS:CompanionData()
	data.tutoDone, data.capture, data.collection = true, nil, nil
	NS:JournalData().bestiary = {}
	NS:DB().journalTracker = false
	NS:TrainerHolders()
	-- 3.0.1 : une seule place pour les bandeaux du haut (Banners.lua) ; un
	-- bandeau du carnet resté d'avant la retiendrait
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	if NS.journalToast then NS.journalToast:Hide() end
	NS.bannerLane.showing, NS.bannerLane.frame, NS.bannerLane.waiting = nil, nil, {}
	-- les tampons gagnés en route (zone de Mulgore) ne passent pas devant
	db.journalToast = false
end

function GF.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = GF.saved[name] end
	NS.ZONE_CREATURES = GF.saved.ZONE_CREATURES
	GameTooltip.GetUnit = GF.saved.GetUnit
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	NS:GuildFeatsReset()
	NS:TrainerResetSession()
	ResetWorld()
	NS:DB().journalToast = nil
end

-- l'horloge de l'addon (celle de la fiche) : exploits en attente, bandeaux,
-- puis la file des messages
function GF.Tick(seconds)
	Mock.now = Mock.now + (seconds or 0)
	for _ = 1, 5 do NS:TrainerPump(10) end
end

function GF.Take()
	local list = GF.sent
	GF.sent = {}
	return list
end

-- un message d'exploit reçu (par le crochet de TrainerCard.lua, comme le client)
function GF.Receive(text, sender, channel)
	return NS:TrainerOnAddonMessage("QCTrainer", text, channel or "GUILD", sender or "Dyokrion-Royaume")
end

function GF.Caught(npcID, fields)
	fields = fields or {}
	local capture = NS:CaptureData()
	if capture.creatures[npcID] == nil then capture.count = capture.count + 1 end
	capture.creatures[npcID] = { name = fields.name or ("Créature " .. npcID), class = fields.class or "normal",
		zoneID = fields.zoneID or 1411, normal = not fields.shinyOnly, shiny = fields.shiny or fields.shinyOnly or nil, at = 1 }
end

-- 1. Chaînes et réglages ------------------------------------------------------------------------
do
	Say("-- exploits de guilde : chaînes et réglages")
	GF.Reset()
	local strings, bad = NS.GFEAT_STRINGS, {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then bad[#bad + 1] = "en:" .. key end
		if NS.L[key] ~= value then bad[#bad + 1] = "fr:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then bad[#bad + 1] = "fr manquant:" .. key end end
	Check("[GLD] chaînes françaises et anglaises complètes", #bad == 0, table.concat(bad, ", "))
	local keys, trainerAt = {}, nil
	for index, row in ipairs(NS.DAILY_OPTION_ROWS) do
		keys[row.key] = index
		if row.key == "trainerShare" then trainerAt = index end
	end
	Check("[GLD] par défaut : annoncer, tout voir, pas de chat ; réglages sous le partage de la fiche", NS:GuildFeatsSending()
		and NS:GuildFeatsShowMode() == "all" and NS:DB().guildFeatsChat ~= true and trainerAt
		and keys.guildFeatsSend == trainerAt + 1 and keys.guildFeatsShow == trainerAt + 2 and keys.guildFeatsChat == trainerAt + 3)
	local choices = NS:GuildFeatsShowChoices()
	Check("[GLD] trois choix (tous, brillantes seulement, aucun), choix inconnu refusé", #choices == 3
		and choices[1].value == "all" and choices[2].label == "Brillantes seulement" and choices[3].value == "off"
		and NS:GuildFeatsSetShowMode("tout") == nil and NS:GuildFeatsShowMode() == "all")
	NS:GuildFeatsSetShowMode("shiny")
	local kept = NS:DB().guildFeatsShow == "shiny" and NS:GuildFeatsShowMode() == "shiny"
	NS:DB().guildFeatsShow = "n'importe quoi"
	Check("[GLD] choix gardé dans la sauvegarde ; valeur illisible : tous", kept and NS:GuildFeatsShowMode() == "all")
end

-- 2. Envoi : réglages, guilde, combat, format ---------------------------------------------------
do
	Say("-- exploits de guilde : envoi")
	GF.Reset()
	local shiny = { kind = "s", id = 3098, zone = 1411, stars = 3, class = "normal" }
	local refused = {}
	GF.guild = false
	if NS:GuildFeatNote(shiny) then refused[#refused + 1] = "hors guilde" end
	GF.guild = true
	NS:DB().guildFeatsSend = false
	if NS:GuildFeatNote(shiny) then refused[#refused + 1] = "annonce coupée" end
	NS:DB().guildFeatsSend = true
	NS:DB().trainerShare = false
	if NS:GuildFeatNote(shiny) then refused[#refused + 1] = "fiche non partagée" end
	NS:DB().trainerShare = true
	if NS:GuildFeatNote({ kind = "x", id = 1 }) then refused[#refused + 1] = "sorte inconnue" end
	Check("[GLD] rien de retenu hors guilde, annonce coupée, fiche non partagée, sorte inconnue", #refused == 0,
		table.concat(refused, ", "))
	local noted = NS:GuildFeatNote(shiny)
	GF.Tick(1)
	Check("[GLD] exploit retenu, la série attend quelques secondes (regroupement)", noted and #GF.sent == 0)
	GF.Tick(NS.GFEAT_GATHER)
	local sent = GF.Take()
	Check("[GLD] une annonce, à la guilde, préfixe de la fiche, format versionné E~1~s~npc~zone~étoiles~rang~autres",
		#sent == 1 and sent[1].channel == "GUILD" and sent[1].prefix == "QCTrainer" and sent[1].target == nil
		and sent[1].text == "E~1~s~3098~1411~3~normal~0", sent[1] and sent[1].text)
	local feat = NS:GuildFeatParse(sent[1].text)
	Check("[GLD] le message relu est le même exploit", feat and feat.kind == "s" and feat.id == 3098 and feat.zone == 1411
		and feat.stars == 3 and feat.more == 0)
	-- combat, verrou de messagerie : la série attend
	NS:GuildFeatsReset()
	NS:GuildFeatNote({ kind = "z", id = 1412, zone = 0, stars = 0 })
	GF.combat = true
	GF.Tick(NS.GFEAT_GATHER + 1)
	local combat = #GF.sent == 0 and NS.guildFeatsState.out ~= nil
	GF.combat, GF.lockdown = false, true
	GF.Tick(1)
	local lockdown = #GF.sent == 0
	GF.lockdown = false
	GF.Tick(1)
	sent = GF.Take()
	Check("[GLD] en combat, verrou de messagerie : rien ; après : l'annonce part", combat and lockdown and #sent == 1
		and sent[1].text == "E~1~z~1412~0~0~-~0", sent[1] and sent[1].text)
	-- sorti de la guilde entre-temps : la série est oubliée
	NS:GuildFeatsReset()
	NS:GuildFeatNote(shiny)
	GF.guild = false
	GF.Tick(NS.GFEAT_GATHER + 1)
	Check("[GLD] sorti de la guilde avant l'envoi : rien", #GF.sent == 0 and NS.guildFeatsState.out == nil)
end

-- 3. Regroupement et écart ----------------------------------------------------------------------
do
	Say("-- exploits de guilde : regroupement")
	GF.Reset()
	NS:GuildFeatNote({ kind = "n", id = 3099, zone = 1411, stars = 1, class = "elite" })
	NS:GuildFeatNote({ kind = "n", id = 3100, zone = 1411, stars = 2, class = "rare" })
	NS:GuildFeatNote({ kind = "s", id = 3098, zone = 1411, stars = 1, class = "normal" })
	NS:GuildFeatNote({ kind = "z", id = 1411, zone = 0, stars = 0 })
	NS:GuildFeatNote({ kind = "r", id = 10, zone = 0, stars = 0 })
	GF.Tick(NS.GFEAT_GATHER + 1)
	local sent = GF.Take()
	Check("[GLD] 5 exploits d'un coup : une annonce, la brillante, « et 4 autres »", #sent == 1
		and sent[1].text == "E~1~s~3098~1411~1~normal~4", sent[1] and sent[1].text)
	Check("[GLD] ordre : brillante > palier > sceau > rare > élite", NS.GuildFeatScore({ kind = "s", stars = 1 })
		> NS.GuildFeatScore({ kind = "r", id = 250 }) and NS.GuildFeatScore({ kind = "r", id = 10 }) > NS.GuildFeatScore({ kind = "z" })
		and NS.GuildFeatScore({ kind = "z" }) > NS.GuildFeatScore({ kind = "n", class = "worldboss", stars = 3 })
		and NS.GuildFeatScore({ kind = "n", class = "rare" }) > NS.GuildFeatScore({ kind = "n", class = "elite", stars = 3 }))
	NS:GuildFeatNote({ kind = "n", id = 3099, zone = 1411, stars = 1, class = "elite" })
	GF.Tick(NS.GFEAT_GATHER + 1)
	local waited = #GF.sent == 0
	GF.Tick(NS.GFEAT_GAP)
	sent = GF.Take()
	Check("[GLD] écart entre deux annonces respecté, puis l'annonce suivante part", waited and #sent == 1
		and sent[1].text:find("^E~1~n~3099~") ~= nil, sent[1] and sent[1].text)
	local parts = NS:GuildFeatMessage({ kind = "s", id = 3098, zone = 1411, stars = 9, class = "dieu" }, 500)
	Check("[GLD] champs bornés à l'envoi (étoiles, rang inconnu, autres)", parts[4] == 3 and parts[5] == "-" and parts[6] == 99)
end

-- 4. Crochets : capture, sceau, palier ----------------------------------------------------------
do
	Say("-- exploits de guilde : captures, sceaux, paliers")
	GF.Reset()
	NS:MenagerieCollectionData().init = true
	local function Last()
		local out = NS.guildFeatsState.out
		NS.guildFeatsState.out = nil
		return out and out.feat
	end
	NS:CaptureResolve({ success = true, target = { npcID = 3098, name = "Sanglier tacheté", class = "normal", zoneID = 1411 } })
	local common = Last() == nil
	NS:CaptureResolve({ success = true, target = { npcID = 3099, name = "Garde kolkar", class = "elite", zoneID = 1411 } })
	local feat = Last()
	Check("[GLD] espèce commune nouvelle : rien ; élite nouvelle : annoncée", common and feat and feat.kind == "n"
		and feat.id == 3099 and feat.zone == 1411 and feat.class == "elite" and feat.stars >= 1)
	NS:CaptureResolve({ success = true, target = { npcID = 3099, name = "Garde kolkar", class = "elite", zoneID = 1411 } })
	local again = Last() == nil
	NS:CaptureResolve({ success = false, target = { npcID = 3100, name = "Griffe-sanglante", class = "rare", zoneID = 1411 } })
	Check("[GLD] élite recapturée, capture ratée : pas d'annonce", again and Last() == nil)
	NS:CaptureResolve({ success = true, target = { npcID = 3098, name = "Sanglier tacheté", class = "normal", zoneID = 1411, shiny = true } })
	feat = Last()
	NS:CaptureResolve({ success = true, stars = 1, target = { npcID = 3098, name = "Sanglier tacheté", class = "normal", zoneID = 1411, shiny = true } })
	Check("[GLD] brillante : annoncée même d'une espèce commune ; la même, pas mieux : rien", feat and feat.kind == "s"
		and feat.id == 3098 and Last() == nil)
	-- le kodo, seule espèce de Mulgore : la zone est scellée
	NS:CaptureResolve({ success = true, target = { npcID = 201, name = "Kodo", class = "normal", zoneID = 1412 } })
	feat = Last()
	Check("[GLD] sceau de zone : annoncé", NS:MenagerieSealed(1412) and feat and feat.kind == "z" and feat.id == 1412)
	GF.Caught(3100, { class = "rare" })
	NS:MenagerieSealCheck(1411, { quiet = true })
	local quietSeal = NS:MenagerieSealed(1411) and Last() == nil
	for index = 1, 10 do GF.Caught(5000 + index) end
	NS:MenagerieRankCheck({ quiet = true })
	Check("[GLD] rattrapages silencieux (sceau, palier) : pas d'annonce", quietSeal and Last() == nil)
	NS:MenagerieCollectionData().ranks = {}
	for index = 11, 25 do GF.Caught(5000 + index) end
	NS:MenagerieRankCheck()
	feat = Last()
	Check("[GLD] paliers franchis d'un coup : le plus haut annoncé", feat and feat.kind == "r" and feat.id == 25, feat and feat.id)
	GF.guild = false
	NS:CaptureResolve({ success = true, target = { npcID = 6001, name = "Rare perdu", class = "rare", zoneID = 1411 } })
	Check("[GLD] hors guilde : la capture n'annonce rien", Last() == nil)
end

-- 5. Réception : canal, soi, champs, identifiants -----------------------------------------------
do
	Say("-- exploits de guilde : réception")
	GF.Reset()
	local retained = GF.Receive("E~1~s~3098~1411~3~normal~0")
	local item = NS:GuildFeatsQueue()[1]
	Check("[GLD] brillante reçue de la guilde : retenue, la ligne refaite chez nous", retained and item
		and item.info.line == "Dyokrion a capturé une brillante !" and item.info.name == "Sanglier tacheté"
		and item.info.stars == 3 and item.sender == "Dyokrion-Royaume", item and item.info.line)
	Check("[GLD] l'expéditeur devient un détenteur connu (menu du clic droit)", NS:TrainerIsHolder("Dyokrion"))
	NS:GuildFeatsReset()
	GF.Receive("E~1~s~3098~1411~3~normal~0", "Bob-Royaume", "WHISPER")
	GF.Receive("E~1~s~3098~1411~3~normal~0", "Bob-Royaume", "PARTY")
	local otherChannel = #NS:GuildFeatsQueue() == 0 and NS:TrainerIsHolder("Bob")
	GF.Receive("E~1~s~3098~1411~3~normal~0", "Testeur-Royaume")
	Check("[GLD] hors du canal GUILD (détenteur noté quand même), son propre message : ignorés, en lecture directe aussi",
		otherChannel and #NS:GuildFeatsQueue() == 0
		and not NS:GuildFeatsOnMessage("E~1~s~3098~1411~3~normal~0", "WHISPER", "Bob")
		and not NS:GuildFeatsOnMessage("E~1~s~3098~1411~3~normal~0", "GUILD", "Testeur"))
	local bad = {
		"E~1~x~3098~1411~3~normal~0",           -- sorte inconnue
		"E~1~s~30a8~1411~3~normal~0",           -- id illisible
		"E~1~s~3098~1411~4~normal~0",           -- étoiles hors bornes
		"E~1~s~3098~1411~3~dieu~0",             -- rang inconnu
		"E~1~s~3098~1411~3~normal",             -- champ manquant
		"E~1~s~12345678~1411~3~normal~0",       -- id trop long
		"E~1~s~-3~1411~3~normal~0",             -- négatif
		"E~1~s~0~1411~3~normal~0",              -- id nul
		"E~x~s~3098~1411~3~normal~0",           -- version illisible
		"E~1~s~3098|cffff0000~1411~3~normal~0", -- code couleur glissé
		"E~1~s~9999~1411~3~normal~0",           -- créature inconnue chez nous
		"E~1~s~3098~1450~3~normal~0",           -- mauvaise zone : créature introuvable
		"E~1~n~3098~1411~1~rare~0",             -- espèce commune annoncée comme rare
		"E~1~z~1450~0~0~-~0",                   -- zone inconnue
		"E~1~z~20~0~0~-~0",                     -- carte connue, mais pas une zone à sceau
		"E~1~r~11~0~0~-~0",                     -- palier inexistant
		"E~1~r~10~0~0~-~1234",                  -- « autres » trop long
		"E~1~s~3098~1411~3~normal~0" .. string.rep("~x", 120), -- trop long
	}
	local accepted = {}
	for _, text in ipairs(bad) do
		if NS:GuildFeatParse(text) and NS:GuildFeatDescribe(NS:GuildFeatParse(text), "Bob-Royaume") then
			accepted[#accepted + 1] = text
		end
		GF.Receive(text, "Bob-Royaume")
	end
	Check("[GLD] champs invalides ou identifiants inconnus : tous rejetés", #accepted == 0 and #NS:GuildFeatsQueue() == 0,
		table.concat(accepted, " | "))
	local future = NS:GuildFeatParse("E~2~n~3100~1411~2~rare~0~futur~x")
	Check("[GLD] version future avec champs en plus : lue", future and future.proto == 2 and future.kind == "n"
		and future.class == "rare")
	-- le rang de la créature vient de NOS tables, pas du message
	local info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~n~3100~1411~2~elite~0"), "Bob-Royaume")
	Check("[GLD] espèce nouvelle : rang et nom de nos tables", info and info.class == "rare" and info.line == "Bob a capturé un rare !"
		and info.name == "Griffe-sanglante", info and info.line)
	local seal = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~z~1412~0~0~-~2"), "Bob-Royaume")
	local rank = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~1"), "Bob-Royaume")
	Check("[GLD] sceau (nom de zone de notre client) et palier (titre dans notre langue), « et N autres »", seal
		and seal.line == "Bob a scellé une zone !" and seal.sub == "Sceau de zone : Mulgore"
		and NS:GuildFeatMoreText(seal.more) == "et 2 autres exploits" and rank and rank.line == "Bob a capturé 25 espèces !"
		and rank.sub:find("Nouveau titre : ", 1, true) == 1 and NS:GuildFeatMoreText(rank.more) == "et 1 autre exploit",
		rank and rank.sub)
	-- espèce apprise par notre carnet (absente des tables livrées) : connue ; noms désarmés
	GF.Caught(7777, { name = "Bête|cffff0000 piégée", class = "rareelite", zoneID = 1450 })
	info = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~n~7777~1450~1~-~0"), "Bob-Royaume")
	local a = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~s~3098~1411~1~-~0"), "Ève-AutreRoyaume")
	local b = NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~s~3098~1411~1~-~0"), "Mé|chant-Royaume")
	Check("[GLD] créature de notre carnet et expéditeur (royaume étranger gardé) : noms désarmés", info
		and info.line == "Bob a capturé un rare élite !" and info.name:find("||c", 1, true) ~= nil
		and a and a.line:find("Ève-AutreRoyaume", 1, true) == 1 and b and b.line:find("Mé||chant", 1, true) == 1,
		info and info.name)
end

-- 6. Réglages de réception, chat ----------------------------------------------------------------
do
	Say("-- exploits de guilde : réglages de réception")
	GF.Reset()
	NS:GuildFeatsSetShowMode("shiny")
	GF.Receive("E~1~n~3100~1411~2~rare~0", "Bob-Royaume")
	GF.Receive("E~1~s~3098~1411~1~normal~0", "Cid-Royaume")
	local queue = NS:GuildFeatsQueue()
	Check("[GLD] brillantes seulement : le rare ignoré, la brillante retenue", #queue == 1 and queue[1].feat.kind == "s")
	GF.Receive("E~1~n~3100~1411~2~rare~0", "Dan-Royaume")
	NS:GuildFeatsSetShowMode("all")
	GF.Receive("E~1~n~3100~1411~2~rare~0", "Dan-Royaume")
	local all = #NS:GuildFeatsQueue() == 2
	NS:GuildFeatsSetShowMode("shiny")
	Check("[GLD] tous : le rare retenu ; repasser à « brillantes seulement » vide les autres", all and #NS:GuildFeatsQueue() == 1)
	NS:GuildFeatsSetShowMode("off")
	GF.Receive("E~1~s~3098~1411~1~normal~0", "Eve-Royaume")
	Check("[GLD] aucun : rien retenu, file vidée", #NS:GuildFeatsQueue() == 0)
	NS:GuildFeatsSetShowMode("all")
	local before = #Mock.output
	GF.Receive("E~1~s~3098~1411~1~normal~0", "Fay-Royaume")
	local silent = #Mock.output == before
	NS:DB().guildFeatsChat = true
	GF.Receive("E~1~s~3099~1411~2~elite~0", "Gus-Royaume")
	local line = Mock.output[#Mock.output] or ""
	Check("[GLD] chat coupé par défaut ; activé : une ligne « Guilde — … »", silent and #Mock.output == before + 1
		and line:find("Guilde — Gus a capturé une brillante !", 1, true) ~= nil and line:find("Garde kolkar", 1, true) ~= nil, line)
end

-- 7. File des bandeaux, son, clic ---------------------------------------------------------------
do
	Say("-- exploits de guilde : bandeaux")
	GF.Reset()
	GF.Receive("E~1~n~3099~1411~1~elite~0", "Ann-Royaume")
	GF.Receive("E~1~n~3100~1411~1~rare~0", "Ann-Royaume")
	GF.Receive("E~1~n~3099~1411~1~elite~0", "Ann-Royaume")
	local queue = NS:GuildFeatsQueue()
	Check("[GLD] un bandeau par membre : le meilleur gardé", #queue == 1 and queue[1].feat.id == 3100)
	local function Has(prefix)
		for _, item in ipairs(NS:GuildFeatsQueue()) do if item.key:find("^" .. prefix) then return true end end
		return false
	end
	GF.Receive("E~1~n~3099~1411~1~elite~0", "Ben-Royaume")
	GF.Receive("E~1~z~1412~0~0~-~0", "Cal-Royaume")
	GF.Receive("E~1~n~3099~1411~2~elite~0", "Dee-Royaume")
	local replaced = #queue == 3 and not Has("ben")
	GF.Receive("E~1~n~3099~1411~1~elite~0", "Eli-Royaume")
	Check("[GLD] file de 3 : le moins bon remplacé par un meilleur, un moins bon laissé", replaced
		and #NS:GuildFeatsQueue() == 3 and not Has("eli"))
	GF.combat = true
	GF.Tick(0.2)
	Check("[GLD] en combat : pas de bandeau", NS:GuildFeatsShowing() == nil)
	GF.combat = false
	GF.Tick(0.2)
	local f = NS.guildFeatToast
	local showing = NS:GuildFeatsShowing()
	-- 3.1.0 : « Clic : sa fiche » n'est plus une 4e ligne du bandeau, il est
	-- dans l'infobulle au survol
	GameTooltip:ClearLines()
	if f and f.button then f.button:GetScript("OnEnter")(f.button) end
	local tipHint = GameTooltip.lines and GameTooltip.lines[1]
	if f and f.button then f.button:GetScript("OnLeave")(f.button) end
	Check("[GLD] un bandeau : le meilleur d'abord (le sceau), liseré doré, aide « Clic : sa fiche » au survol, son de réussite",
		f and f:IsShown() and showing and showing.feat.kind == "z" and f.title.text == "GUILDE"
		and f.text.text == "Cal a scellé une zone !" and f.info.text == "Sceau de zone : Mulgore"
		and (f.hint.text or "") == "" and tipHint == "Clic : sa fiche de dresseur" and f.accentColor == NS.Theme.GOLD
		and #GF.sounds == 1 and GF.sounds[1] == 17316, f and (f.text.text .. " / " .. tostring(f.hint.text) .. " / " .. tostring(tipHint)))
	GF.Tick(1)
	local single = NS:GuildFeatsShowing() == showing and #NS:GuildFeatsQueue() == 2
	GF.Tick(NS.GFEAT_TOAST_SECONDS)
	local second = NS:GuildFeatsShowing()
	Check("[GLD] un seul bandeau à la fois ; fini : le suivant (rang à la couleur du thème)", single and second
		and second ~= showing and second.feat.kind == "n" and f.info.text:find("Griffe-sanglante", 1, true)
		and f.info.text:find(NS.Theme.Hex(NS.Theme.RANK.rare), 1, true) ~= nil, f.info.text)   -- 2.11.0 : jeton Theme.RANK
	-- son limité : deux bandeaux à moins d'une seconde
	local sounds = #GF.sounds
	NS:GuildFeatsShowToast({ key = "x", sender = "Xan-Royaume", feat = { kind = "s" }, score = 1000, at = Mock.now,
		info = { line = "Xan a capturé une brillante !", shiny = true, class = "normal", name = "Sanglier", stars = 2 } })
	local throttled = #GF.sounds == sounds
	Mock.now = Mock.now + 1.1
	NS:GuildFeatsShowToast({ key = "x", sender = "Xan-Royaume", feat = { kind = "s" }, score = 1000, at = Mock.now,
		info = { line = "Xan a capturé une brillante !", shiny = true, class = "normal", name = "Sanglier", stars = 2 } })
	Check("[GLD] son : pas deux en moins d'une seconde ; brillante : la fanfare, liseré doré clair", throttled
		and GF.sounds[#GF.sounds] == 63971 and f.accentColor == (NS.Theme.GOLD_LIGHT or NS.Theme.GOLD))
	NS:DB().companionCaptureSound = false
	sounds = #GF.sounds
	Mock.now = Mock.now + 2
	NS:GuildFeatsShowToast(NS:GuildFeatsShowing())
	Check("[GLD] sons de capture coupés : muet", #GF.sounds == sounds)
	-- clic : la fiche de dresseur de l'expéditeur (la file vidée : rien ne prend la place)
	NS.guildFeatsState.toasts = {}
	GF.Take()
	f.button:Click("LeftButton")
	NS:TrainerPump(10)
	local sent = GF.Take()
	Check("[GLD] clic : la fiche de ce joueur est demandée", not f:IsShown() and NS.trainerFrame and NS.trainerFrame:IsShown()
		and sent[1] and sent[1].text == "R~1" and sent[1].channel == "WHISPER" and sent[1].target == "Xan-Royaume",
		sent[1] and sent[1].text)
	NS.trainerFrame:Hide()
	NS:GuildFeatsShowToast({ key = "y", sender = "Yan-Royaume", feat = { kind = "z" }, score = 700, at = Mock.now,
		info = { line = "Yan a scellé une zone !", sub = "Sceau de zone : Mulgore" } })
	f.button:Click("RightButton")
	NS:TrainerPump(10)
	Check("[GLD] clic droit : le bandeau se ferme, rien demandé ; bandeau déplaçable", not f:IsShown() and #GF.Take() == 0
		and f.button.scripts.OnDragStart ~= nil and f.scripts.OnDragStop ~= nil)
	-- périmés
	NS:GuildFeatsReset()
	GF.Receive("E~1~s~3098~1411~1~normal~0", "Zed-Royaume")
	GF.combat = true
	GF.Tick(NS.GFEAT_TOAST_STALE + 1)
	GF.combat = false
	GF.Tick(0.2)
	Check("[GLD] exploit de plus d'une minute : jamais montré", NS:GuildFeatsShowing() == nil and #NS:GuildFeatsQueue() == 0)
end

-- 8. Découverte au survol -----------------------------------------------------------------------
do
	Say("-- exploits de guilde : découverte au survol")
	GF.Reset()
	local hovered
	GameTooltip.GetUnit = function() return hovered and GF.units[hovered].name, hovered end
	GF.units.mouseover = { name = "Ilda" }
	hovered = "mouseover"
	local probed = NS:GuildFeatsTooltipProbe(GameTooltip)
	NS:TrainerPump(10)
	local sent = GF.Take()
	Check("[GLD] survol d'un joueur : une sonde P en chuchotement", probed and sent[1] and sent[1].text == "P~1"
		and sent[1].channel == "WHISPER" and sent[1].target == "Ilda-Royaume")
	GF.units.mouseover = { name = "Jorn" }
	local throttled = not NS:GuildFeatsTooltipProbe(GameTooltip)
	Mock.now = Mock.now + 1
	Check("[GLD] une sonde par seconde au plus", throttled and NS:GuildFeatsTooltipProbe(GameTooltip))
	Mock.now = Mock.now + 1
	Check("[GLD] même joueur : pas deux fois par session", not NS:GuildFeatsTooltipProbe(GameTooltip))
	NS:TrainerMarkHolder("Kara")
	GF.units.mouseover = { name = "Kara" }
	local fresh = not NS:GuildFeatsTooltipProbe(GameTooltip)
	GF.now = GF.now + NS.GFEAT_PROBE_FRESH + 1
	GF.combat = true
	Check("[GLD] pas de sonde : détenteur vu il y a peu, en combat", fresh and not NS:GuildFeatsTooltipProbe(GameTooltip))
	GF.combat = false
	Check("[GLD] détenteur vu il y a longtemps : resondé", NS:GuildFeatsTooltipProbe(GameTooltip))
	GF.units.mouseover, hovered = nil, nil
	Mock.now = Mock.now + 2
	Check("[GLD] survol d'une créature : rien", not NS:GuildFeatsTooltipProbe(GameTooltip))
end

-- 9. Débit refusé par le client : réessai -------------------------------------------------------
do
	Say("-- exploits de guilde : réessai")
	GF.Reset()
	NS:TrainerSend("E", "GUILD", nil, "z", 1412, 0, 0, "-", 0)
	GF.codes = { 3 }
	Check("[GLD] refus du client (débit) : rien d'envoyé, gardé, pas de nouvel essai avant une seconde",
		NS:TrainerPump(10) == 0 and #NS.trainerState.queue == 1 and NS:TrainerPump(0.2) == 0)
	Mock.now = Mock.now + 1
	Check("[GLD] une seconde plus tard : envoyé", NS:TrainerPump(1) == 1 and GF.sent[1] and GF.sent[1].text == "E~1~z~1412~0~0~-~0")
	NS:TrainerSend("E", "GUILD", nil, "z", 1412, 0, 0, "-", 0)
	GF.codes = { 8, 8, 8, 8, 8, 8, 8 }
	for _ = 1, 8 do Mock.now = Mock.now + 1; NS:TrainerPump(1) end
	Check("[GLD] refus répétés : abandonné au bout de 5 essais", #NS.trainerState.queue == 0 and #GF.sent == 1)
end

GF.Done()
