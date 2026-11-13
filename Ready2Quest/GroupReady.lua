-- GroupReady.lua -- « Groupe prêt » sur la fiche de donjon (Ready2Quest 1.35.0)
--
-- Forever n'a ni recherche de donjon ni pierre de rencontre : devant un
-- donjon, la question est toujours « qui est là, et qui est prêt ? ». Quand
-- ta fiche « Avant le donjon » sort et que tu es en groupe, Ready2Quest
-- demande leur état aux membres qui l'ont aussi, par message d'addon
-- (invisible, rien dans le chat du groupe). Chacun répond :
--   * où il est : dans le donjon, à l'entrée, ou en route ;
--   * sa préparation : les mêmes contrôles que la fiche (durabilité,
--     réparation, vivres, potions, foyer), et ceux qui clochent.
-- La fiche gagne une section « GROUPE » ; /r2q groupe la dit dans le chat.
-- Un membre sans Ready2Quest reste listé, sans état.
--
-- Sobriété : CHAT_MSG_ADDON n'est écouté qu'en groupe, module actif ; une
-- réponse au plus toutes les GROUP_REPLY_GAP secondes ; rien n'est calculé ni
-- envoyé en combat (la réponse part à la fin du combat, PLAYER_REGEN_ENABLED
-- n'est écouté que le temps de cette attente).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

ns.GROUP_PREFIX = "R2QGroup"
ns.GROUP_PROTOCOL = 1
ns.GROUP_REPLY_GAP = 5      -- s au moins entre deux réponses (ou deux demandes)
ns.GROUP_STALE = 600        -- s : un état plus vieux n'est plus montré
local READY_CHECKS = { "durability", "repair", "vivres", "potions", "hearth" }
local WHERE = { i = "inside", e = "entrance", a = "away" }
local WHERE_CODE = { inside = "i", entrance = "e", away = "a" }

local FR = {
	OPT_DUNGEON_GROUP = "Groupe prêt : demander leur état aux membres",
	OPT_DUNGEON_GROUP_DESC = "Devant un donjon, en groupe : la fiche montre qui est sur place et qui est prêt, pour les membres qui ont aussi Ready2Quest. Par message d'addon, rien dans le chat.",
	GRP_HEAD = "GROUPE (%d PRÊTS SUR %d)",
	GRP_WHERE_inside = "dans le donjon",
	GRP_WHERE_entrance = "à l'entrée",
	GRP_WHERE_away = "en route",
	GRP_READY = "prêt",
	GRP_ISSUES = "à voir : %s",
	GRP_UNKNOWN = "pas de réponse (sans Ready2Quest ?)",
	GRP_YOU = "Toi",
	GRP_CHAT_HEAD = "Groupe pour %s : %d prêts sur %d.",
	GRP_CHAT_NONE = "Tu n'es pas en groupe.",
	GRP_CHAT_NO_DUNGEON = "Pas de donjon en vue : approche-toi d'une entrée, puis /r2q groupe.",
	GRP_CHAT_OFF = "« Groupe prêt » est coupé (réglages, page Avant le donjon).",
	HELP_GROUP = "/r2q groupe : qui est sur place et prêt pour le donjon",
}
local EN = {
	OPT_DUNGEON_GROUP = "Group ready: ask members for their status",
	OPT_DUNGEON_GROUP_DESC = "At a dungeon, in a group: the sheet shows who is there and who is ready, for members who also run Ready2Quest. Sent as addon messages, nothing in chat.",
	GRP_HEAD = "GROUP (%d READY OUT OF %d)",
	GRP_WHERE_inside = "inside",
	GRP_WHERE_entrance = "at the entrance",
	GRP_WHERE_away = "on the way",
	GRP_READY = "ready",
	GRP_ISSUES = "to fix: %s",
	GRP_UNKNOWN = "no answer (no Ready2Quest?)",
	GRP_YOU = "You",
	GRP_CHAT_HEAD = "Group for %s: %d ready out of %d.",
	GRP_CHAT_NONE = "You are not in a group.",
	GRP_CHAT_NO_DUNGEON = "No dungeon in sight: walk up to an entrance, then /r2q groupe.",
	GRP_CHAT_OFF = "\"Group ready\" is off (settings, Before the dungeon page).",
	HELP_GROUP = "/r2q groupe: who is there and ready for the dungeon",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.GROUP_STRINGS = { fr = FR, en = EN } end
ns.RegisterDefaults({ dungeonGroup = true })

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Plain(value) return ns.Plain and ns.Plain(value) or value end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function InCombat()
	if Plain(Call(G("InCombatLockdown"))) then return true end
	return Plain(Call(G("UnitAffectingCombat"), "player")) and true or false
end
local function Api()
	local api = G("C_ChatInfo")
	if type(api) == "table" and type(api.SendAddonMessage) == "function" then return api end
	return nil
end
local function Short(name)
	name = Plain(name)
	if type(name) ~= "string" or name == "" then return nil end
	return name:match("^([^%-]+)") or name
end
local function Me() return Short(Call(G("UnitName"), "player")) end

function ns:GroupReadyOn()
	local db = self:DB()
	return db.enabled ~= false and db.dungeonEnabled ~= false and db.dungeonGroup ~= false
end

local function Channel()
	local instance, home = G("LE_PARTY_CATEGORY_INSTANCE"), G("LE_PARTY_CATEGORY_HOME")
	if instance and Plain(Call(G("IsInGroup"), instance)) and not (home and Plain(Call(G("IsInGroup"), home))) then
		return "INSTANCE_CHAT"
	end
	if Plain(Call(G("IsInRaid"))) then return "RAID" end
	if Plain(Call(G("IsInGroup"))) then return "PARTY" end
	return nil
end
ns.GroupChannel = Channel

-- Les membres du groupe (noms courts, toi compris, en premier)
function ns:GroupRoster()
	local roster = { Me() }
	local raid = Plain(Call(G("IsInRaid"))) and true or false
	local unitName = G("UnitName")
	for index = 1, raid and 40 or 4 do
		local name = Short(Call(unitName, (raid and "raid" or "party") .. index))
		if name and name ~= roster[1] then roster[#roster + 1] = name end
	end
	return roster
end

function ns:GroupState()
	local state = self.groupReady
	if not state then
		state = { members = {} }
		self.groupReady = state
	end
	return state
end

-- Mon état pour le donjon `key` : où je suis, et ce qui cloche dans ma
-- préparation (identifiants des contrôles). Jamais calculé en combat.
function ns:GroupMyStatus(key)
	local entry, how = self:DetectDungeon()
	local where = (entry and entry.key == key) and (how == "entrance" and "entrance" or "inside") or "away"
	local issues = {}
	for _, line in ipairs(self:DungeonReadiness()) do
		if not line.ok then issues[#issues + 1] = line.id end
	end
	return { where = where, issues = issues, level = tonumber(Plain(Call(G("UnitLevel"), "player"))) or 0, at = Clock() }
end

-- « S|1|clé|i|60|durability,vivres|1 » (dernier champ : 1 = « et vous ? »)
function ns:GroupEncode(key, status, ask)
	return table.concat({ "S", ns.GROUP_PROTOCOL, tostring(key), WHERE_CODE[status.where] or "a",
		tostring(status.level or 0), table.concat(status.issues or {}, ","), ask and "1" or "0" }, "|")
end

-- Rend la clé, l'état et « demande une réponse », ou nil (message d'une
-- autre version ou abîmé : ignoré sans bruit)
function ns:GroupDecode(text)
	if type(text) ~= "string" or #text > 200 then return nil end
	local kind, version, key, where, level, issues, ask = text:match("^(%a)|(%d+)|([^|]+)|(%a)|(%d+)|([%a,]*)|([01])$")
	if kind ~= "S" or tonumber(version) ~= ns.GROUP_PROTOCOL or not WHERE[where] then return nil end
	local list = {}
	for id in issues:gmatch("[^,]+") do
		-- seuls les contrôles connus comptent (un texte forgé n'entre pas dans la fiche)
		for _, known in ipairs(READY_CHECKS) do
			if id == known then list[#list + 1] = id end
		end
	end
	return key, { where = WHERE[where], level = tonumber(level) or 0, issues = list, at = Clock() }, ask == "1"
end

-- Envoie mon état au groupe. Rend true si le message est parti ; en combat,
-- il part à la fin du combat (un seul en attente).
function ns:GroupSend(key, ask)
	if not (key and self:GroupReadyOn()) then return false end
	local state = self:GroupState()
	if InCombat() then
		state.pending = { key = key, ask = ask or (state.pending and state.pending.ask) or false }
		self:GroupEvents()
		return false
	end
	local api, channel = Api(), Channel()
	if not (api and channel) then return false end
	self:GroupEvents()
	local now = Clock()
	if state.sentAt and now - state.sentAt < ns.GROUP_REPLY_GAP and now >= state.sentAt and state.sentKey == key and not ask then
		return false
	end
	local mine = self:GroupMyStatus(key)
	if state.key ~= key then state.key, state.members = key, {} end
	local me = Me()
	if me then state.members[me] = mine end
	local ok, result = pcall(api.SendAddonMessage, ns.GROUP_PREFIX, self:GroupEncode(key, mine, ask), channel)
	if not ok then
		if self.RecordError then self:RecordError("group:send", result) end
		return false
	end
	state.sentAt, state.sentKey = now, key
	return true
end

-- Un message du groupe : l'état d'un membre, et ma réponse s'il la demande
function ns:GroupReceive(prefix, text, _, sender)
	if prefix ~= ns.GROUP_PREFIX or not self:GroupReadyOn() then return false end
	local name = Short(sender)
	if not name or name == Me() then return false end
	local key, status, ask = self:GroupDecode(Plain(text))
	if not key then return false end
	local state = self:GroupState()
	-- un autre donjon que celui que je suis : je passe au sien (il vient d'y arriver)
	if state.key ~= key then state.key, state.members = key, {} end
	state.members[name] = status
	if ask then self:GroupSend(key, false) end
	self:GroupRefreshWindow()
	return true
end

-- Les lignes du groupe pour le donjon suivi : { name, me, where, ready,
-- issues = { libellés }, known }, et le nombre de prêts
function ns:GroupLines()
	local state = self:GroupState()
	local now, lines, ready = Clock(), {}, 0
	for index, name in ipairs(self:GroupRoster()) do
		local status = state.members[name]
		if status and (now - (status.at or 0) > ns.GROUP_STALE) then status = nil end
		local line = { name = name, me = index == 1, known = status ~= nil }
		if status then
			line.where = status.where
			line.issues = {}
			for _, id in ipairs(status.issues) do
				local def = self.FindCheck and self:FindCheck(id)
				local label = def and def.label
				if type(label) == "function" then label = label() end
				line.issues[#line.issues + 1] = tostring(label or id)
			end
			line.ready = #line.issues == 0 and status.where ~= "away"
			if line.ready then ready = ready + 1 end
		end
		lines[#lines + 1] = line
	end
	return lines, ready
end

-- « à l'entrée · prêt », « en route · à voir : Durabilité »
function ns:GroupLineText(line)
	if not line.known then return L.GRP_UNKNOWN end
	local where = L["GRP_WHERE_" .. tostring(line.where)] or ""
	if #line.issues == 0 then return where .. " · " .. L.GRP_READY end
	return where .. " · " .. self:F("GRP_ISSUES", table.concat(line.issues, ", "))
end

-- La section « GROUPE » de la fiche (Dungeon.lua, ShowDungeonWindow) :
-- `add(texte, état, sorte)` ; rien hors groupe ou pour un autre donjon
function ns:GroupSheetRows(sheet, add)
	if not (self:GroupReadyOn() and Channel() and sheet and self:GroupState().key == sheet.key) then return 0 end
	local lines, ready = self:GroupLines()
	if #lines < 2 then return 0 end
	add(self:F("GRP_HEAD", ready, #lines), nil, "head")
	for _, line in ipairs(lines) do
		local name = line.me and L.GRP_YOU or line.name
		add(name .. "  " .. Theme.T_GREY .. self:GroupLineText(line) .. "|r",
			(not line.known and "item") or (line.ready and "ok") or (line.where == "away" and "item") or "bad")
	end
	return #lines
end

-- La fiche ouverte se remet à jour quand un état arrive
function ns:GroupRefreshWindow()
	local frame, sheet = self.dungeonFrame, self.lastDungeonSheet
	if frame and frame:IsShown() and sheet and sheet.key == self:GroupState().key and self.ShowDungeonWindow then
		pcall(self.ShowDungeonWindow, self, sheet)
		return true
	end
	return false
end

-- La fiche sort : mon état part, avec la demande
do
	local show = ns.ShowDungeonSheet
	if show then
		function ns:ShowDungeonSheet(sheet, ...)
			if sheet and sheet.key and self:GroupReadyOn() and Channel() then
				local ok, err = pcall(self.GroupSend, self, sheet.key, true)
				if not ok and self.RecordError then self:RecordError("group:sheet", err) end
			end
			return show(self, sheet, ...)
		end
	end
end

-- /r2q groupe : l'état du groupe dans le chat (et une nouvelle demande)
function ns:GroupPrint()
	if not self:GroupReadyOn() then self:Print(L.GRP_CHAT_OFF); return false end
	if not Channel() then self:Print(L.GRP_CHAT_NONE); return false end
	local entry, _, instanceName = self:DetectDungeon()
	local state = self:GroupState()
	local key = (entry and entry.key) or state.key
	if not key then self:Print(L.GRP_CHAT_NO_DUNGEON); return false end
	self:GroupSend(key, true)
	local lines, ready = self:GroupLines()
	local name = (entry and self:DungeonName(entry, instanceName)) or (self.lastDungeonSheet and self.lastDungeonSheet.name) or key
	self:Print(self:F("GRP_CHAT_HEAD", Theme.T_GOLD .. tostring(name) .. "|r", ready, #lines))
	for _, line in ipairs(lines) do
		local color = (not line.known and Theme.T_GREY) or (line.ready and Theme.T_GREEN) or Theme.T_ORANGE
		self:Print("  " .. (line.me and L.GRP_YOU or line.name) .. " : " .. color .. self:GroupLineText(line) .. "|r")
	end
	return true
end
if ns.COMMANDS then
	ns.COMMANDS["groupe"] = function(self) self:GroupPrint() end
	ns.COMMANDS["group"] = ns.COMMANDS["groupe"]
end

-- ---------------------------------------------------------------------------
-- Événements : le strict nécessaire, au bon moment (cadre unique du socle,
-- ns.On / ns.Off)
-- ---------------------------------------------------------------------------
-- GROUP_ROSTER_UPDATE et PLAYER_ENTERING_WORLD toujours (rares) ;
-- CHAT_MSG_ADDON seulement en groupe et module actif ; PLAYER_REGEN_ENABLED
-- seulement tant qu'une réponse attend la fin du combat.
local OWNER = "groupReady"
local heard = {}
local function OnAddon(...) return ns:GroupReceive(...) end
local function OnRegen()
	local state = ns.groupReady
	local pending = state and state.pending
	if pending then
		state.pending = nil
		ns:GroupSend(pending.key, pending.ask)
	end
	ns:GroupEvents()
end
local function Set(event, on, fn)
	on = on and true or false
	if (heard[event] or false) == on then return end
	heard[event] = on or nil
	if on then ns.On(event, OWNER, fn, "group:" .. event) else ns.Off(event, OWNER) end
end

function ns:GroupEvents()
	local listening = self:GroupReadyOn() and Channel() ~= nil
	Set("CHAT_MSG_ADDON", listening, OnAddon)
	local state = self.groupReady
	Set("PLAYER_REGEN_ENABLED", listening and state ~= nil and state.pending ~= nil, OnRegen)
	if listening and not ns.groupPrefixed then
		local api = G("C_ChatInfo")
		local register = type(api) == "table" and api.RegisterAddonMessagePrefix or G("RegisterAddonMessagePrefix")
		if type(register) == "function" then ns.groupPrefixed = pcall(register, ns.GROUP_PREFIX) and true or nil end
	end
	-- groupe quitté : les états ne valent plus rien
	if not Channel() and state then state.members, state.key, state.pending = {}, nil, nil end
	return listening
end
-- (le réglage changé : la page des réglages rafraîchit, l'écoute suit)
function ns:GroupListening(event) return heard[event] == true end

do
	local refresh = ns.RefreshOptions
	if refresh then
		function ns:RefreshOptions(...)
			pcall(self.GroupEvents, self)
			return refresh(self, ...)
		end
	end
end

local function Resync() ns:GroupEvents() end
ns.On("GROUP_ROSTER_UPDATE", OWNER, Resync, "group:GROUP_ROSTER_UPDATE")
ns.On("PLAYER_ENTERING_WORLD", OWNER, Resync, "group:PLAYER_ENTERING_WORLD")

if ns.Mark then ns.Mark("GroupReady") end
