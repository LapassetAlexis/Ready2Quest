-- Ready2Quest : « Groupe prêt » (GroupReady.lua, 1.35.0). Devant un donjon,
-- en groupe : mon état part par message d'addon avec la demande, les membres
-- équipés répondent ; la fiche gagne la section GROUPE ; /r2q groupe. Écoute
-- à la demande (CHAT_MSG_ADDON en groupe seulement, fin de combat seulement
-- quand une réponse attend), rien envoyé en combat, messages abîmés ignorés.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local GLOBALS = { "IsInGroup", "IsInRaid", "UnitName", "C_ChatInfo", "InCombatLockdown", "UnitAffectingCombat" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local savedDetect, savedReadiness = NS.DetectDungeon, NS.DungeonReadiness
local W = {}
_G.IsInGroup = function() return W.group == true end
_G.IsInRaid = function() return false end
_G.UnitName = function(unit)
	if unit == "player" then return "Dyo" end
	return W.party and W.party[unit] or nil
end
_G.InCombatLockdown = function() return W.combat == true end
_G.UnitAffectingCombat = function() return W.combat == true end
_G.C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) W.prefix = prefix; return true end,
	SendAddonMessage = function(prefix, text, channel) W.sent[#W.sent + 1] = { prefix = prefix, text = text, channel = channel }; return true end,
}
local ENTRY = { key = "deadmines", name = "The Deadmines", min = 17, max = 26 }
local function Reset()
	ResetWorld()
	NS:DB().reportIcon = false
	W = { sent = {}, group = true, party = { party1 = "Lia-Sulfuron", party2 = "Bran" }, how = "entrance", bad = {} }
	NS.groupReady, NS.dungeonVisit, NS.lastDungeonSheet = nil, nil, nil
	if NS.dungeonFrame then NS.dungeonFrame:Hide() end
	NS.DetectDungeon = function() if W.how then return ENTRY, W.how, "Les Mortemines" end end
	NS.DungeonReadiness = function()
		local lines = { { id = "durability", label = "Durabilité", ok = true, detail = "" }, { id = "vivres", label = "Vivres", ok = true, detail = "" } }
		for _, line in ipairs(lines) do if W.bad[line.id] then line.ok = false end end
		return lines
	end
	NS:GroupEvents()
end
local function Printed()
	local lines, old = {}, NS.Print
	NS.Print = function(_, msg) lines[#lines + 1] = tostring(msg) end
	return lines, function() NS.Print = old end
end

do
	Say("-- groupe prêt : protocole")
	Reset()
	local text = NS:GroupEncode("deadmines", { where = "entrance", level = 22, issues = { "durability", "vivres" } }, true)
	local key, status, ask = NS:GroupDecode(text)
	Check("[GRP] message : aller-retour (clé, lieu, niveau, soucis, demande)", text == "S|1|deadmines|e|22|durability,vivres|1"
		and key == "deadmines" and status.where == "entrance" and status.level == 22 and #status.issues == 2 and ask == true, text)
	Check("[GRP] message abîmé, d'une autre version ou trop long : ignoré", NS:GroupDecode("S|2|deadmines|e|22||0") == nil
		and NS:GroupDecode("n'importe quoi") == nil and NS:GroupDecode(string.rep("x", 300)) == nil
		and NS:GroupDecode("S|1|deadmines|z|22||0") == nil)
	local _, forged = NS:GroupDecode("S|1|deadmines|i|22|durability,pirate|0")
	Check("[GRP] un souci inconnu n'entre pas dans la fiche", forged and #forged.issues == 1 and forged.issues[1] == "durability")
end

do
	Say("-- groupe prêt : la fiche sort, l'état part, les réponses arrivent")
	Reset()
	local sheet = NS:BuildDungeonSheet(ENTRY, "entrance", "Les Mortemines")
	NS:ShowDungeonSheet(sheet)
	Check("[GRP] fiche en groupe : mon état part au groupe avec la demande, préfixe enregistré",
		#W.sent == 1 and W.sent[1].prefix == NS.GROUP_PREFIX and W.sent[1].channel == "PARTY"
		and W.sent[1].text:find("|1$") ~= nil and NS.groupPrefixed == true, W.sent[1] and W.sent[1].text)
	Mock:Fire("CHAT_MSG_ADDON", NS.GROUP_PREFIX, "S|1|deadmines|i|24||0", "PARTY", "Lia-Sulfuron")
	local lines, ready = NS:GroupLines()
	Check("[GRP] réponse reçue : trois membres, toi en premier, Lia dedans et prête, Bran sans réponse",
		#lines == 3 and lines[1].me and lines[2].name == "Lia" and lines[2].where == "inside" and lines[2].ready
		and lines[3].known == false and ready == 2, ready)
	Check("[GRP] une réponse ne relance pas de message (pas de boucle)", #W.sent == 1, #W.sent)
	local frame = NS.dungeonFrame
	local head, found
	for index = 1, frame and frame.visibleLines or 0 do
		local t = frame.lines[index].text:GetText() or ""
		if t == NS.Theme.Upper(NS:F("GRP_HEAD", 2, 3)) then head = true end
		if t:find("Lia", 1, true) and t:find(NS.L.GRP_WHERE_inside, 1, true) then found = true end
	end
	Check("[GRP] fenêtre ouverte : la section GROUPE se met à jour à la réponse", frame and frame:IsShown() and head and found)
	W.bad.durability = true
	Mock.now = Mock.now + NS.GROUP_REPLY_GAP + 1
	Mock:Fire("CHAT_MSG_ADDON", NS.GROUP_PREFIX, "S|1|deadmines|e|20|vivres|1", "PARTY", "Bran")
	Check("[GRP] un membre demande : je réponds, avec ce qui cloche chez moi, sans redemander",
		#W.sent == 2 and W.sent[2].text == "S|1|deadmines|e|11|durability|0", W.sent[2] and W.sent[2].text)
	lines, ready = NS:GroupLines()
	Check("[GRP] ses soucis en clair, lui et moi pas prêts", lines[3].issues[1] ~= nil and lines[3].ready == false
		and lines[1].ready == false and ready == 1 and NS:GroupLineText(lines[3]):find(NS.L.GRP_WHERE_entrance, 1, true) ~= nil)
	Mock:Fire("CHAT_MSG_ADDON", NS.GROUP_PREFIX, "S|1|deadmines|e|22||1", "PARTY", "Dyo")
	Mock:Fire("CHAT_MSG_ADDON", "AutrePrefixe", "S|1|deadmines|e|22||1", "PARTY", "Bran")
	Check("[GRP] mon propre écho et les autres préfixes : ignorés", #W.sent == 2)
end

do
	Say("-- groupe prêt : combat, écoute à la demande, commande")
	Reset()
	W.combat = true
	Mock:Fire("CHAT_MSG_ADDON", NS.GROUP_PREFIX, "S|1|deadmines|i|24||1", "PARTY", "Bran")
	Check("[GRP] en combat : rien n'est envoyé, la fin du combat est écoutée", #W.sent == 0
		and NS:GroupListening("PLAYER_REGEN_ENABLED") and NS.groupReady.pending ~= nil)
	W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[GRP] fin du combat : la réponse part, l'écoute de fin de combat est rendue", #W.sent == 1
		and not NS:GroupListening("PLAYER_REGEN_ENABLED") and NS.groupReady.pending == nil)
	W.group = false
	Mock:Fire("GROUP_ROSTER_UPDATE")
	Check("[GRP] groupe quitté : CHAT_MSG_ADDON n'est plus écouté, les états sont oubliés",
		not NS:GroupListening("CHAT_MSG_ADDON") and NS.groupReady.key == nil and next(NS.groupReady.members) == nil)
	local printed, restore = Printed()
	Check("[GRP] /r2q groupe hors groupe : il le dit", NS:GroupPrint() == false and printed[1] == NS.L.GRP_CHAT_NONE)
	W.group = true
	Mock:Fire("GROUP_ROSTER_UPDATE")
	Check("[GRP] groupe rejoint : l'écoute revient", NS:GroupListening("CHAT_MSG_ADDON"))
	NS:HandleCommand("groupe")
	restore()
	Check("[GRP] /r2q groupe : une demande part, le bilan et une ligne par membre dans le chat",
		#W.sent == 2 and W.sent[2].text:find("|1$") ~= nil and #printed == 1 + 1 + 3, #printed)
	NS:DB().dungeonGroup = false
	NS:RefreshOptions()
	local before = #W.sent
	NS:ShowDungeonSheet(NS:BuildDungeonSheet(ENTRY, "entrance", "Les Mortemines"))
	Check("[GRP] réglage coupé : plus d'écoute, plus d'envoi, pas de section", not NS:GroupListening("CHAT_MSG_ADDON")
		and #W.sent == before and NS:GroupSheetRows({ key = "deadmines" }, function() end) == 0)
	W.group = false
	NS:DB().dungeonGroup = true
	NS:GroupEvents()
	Check("[GRP] seul : la fiche n'a pas de section GROUPE", NS:GroupSheetRows({ key = "deadmines" }, function() end) == 0)
end

for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
NS.DetectDungeon, NS.DungeonReadiness = savedDetect, savedReadiness
NS.groupReady = nil
NS:GroupEvents()
if NS.dungeonFrame then NS.dungeonFrame:Hide() end
