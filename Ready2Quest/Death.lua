-- Death.lua -- module QoL « Après la mort » (v1.24.0)
--
-- À la mort, puis une fois libéré en fantôme, une réponse claire à « courir
-- au corps ou passer par le guérisseur des esprits ? » : la distance jusqu'au
-- corps et le temps de course, face au prix du guérisseur (faiblesse de
-- résurrection et réparation de la durabilité perdue), avec un verdict.
--
-- Chiffres et sources (warcraft.wiki.gg, consultées en novembre 2026) :
--   * fantôme : « Run speed is increased to 125% of normal while you are a
--     spirit » (Death (gameplay)). Course normale = 7 m/s (yards/s) :
--     fantôme = 8,75 m/s. La distance est à vol d'oiseau : le temps affiché
--     est un minimum, le relief et les détours l'allongent.
--   * mort : 10 % de durabilité perdus sur l'équipement porté, tout de suite
--     (déjà payés au moment où la question se pose). Le guérisseur en prend
--     « an additional 25% » : c'est SEULEMENT ce surcoût qui entre dans le
--     choix (Death (gameplay) ; Resurrection sickness, patch 1.1.1 :
--     « durability loss reduced to 25% »).
--   * faiblesse de résurrection : aucune jusqu'au niveau 10, puis une minute
--     par niveau au-dessus de 10, plafonnée à 10 minutes dès le niveau 20
--     (table historique du jeu d'origine ; patch 1.1.1 : « limited to ten
--     minutes »). Le client a GetResSicknessDuration() (vanilla 1.15.9 et
--     Forever 1.60.1) : s'il répond une durée lisible, elle prime sur la table.
--
-- Unités : la carte du jeu compte en yards. Le client français les écrit
-- « m » (« à 30 m ») : on garde le même nombre, sans conversion, pour que la
-- distance se compare à ce que le jeu affiche ailleurs. En anglais : « yd ».
--
-- Instances et champs de bataille : rien. Le corps est dans l'instance et le
-- fantôme dehors (pas de position commune sur une carte), et en champ de
-- bataille le guérisseur relève tout le monde par vagues, sans faiblesse :
-- le calcul n'aurait pas de sens et une version « simplifiée » mentirait.
--
-- Forever : l'arbre Legacy « Resourcefulness » accélérerait la course de
-- fantôme. Aucune aura ni API fiable ne le signale : on n'en parle pas
-- plutôt que de deviner.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local RUN_SPEED      = 7        -- yards/s, course normale
local GHOST_BONUS    = 1.25     -- 125 % de la course normale
local GHOST_SPEED    = RUN_SPEED * GHOST_BONUS
local DEATH_LOSS     = 0.10     -- déjà perdu à la mort
local SPIRIT_LOSS    = 0.25     -- en plus, chez le guérisseur
local SICK_FREE_UPTO = 10       -- pas de faiblesse jusqu'à ce niveau inclus
local SICK_CAP_LEVEL = 20       -- 10 min à partir de ce niveau
local SICK_CAP       = 600      -- secondes
local REFRESH        = 1        -- s entre deux recalculs de distance

ns.DEATH_RULES = {
	ghostSpeed = GHOST_SPEED, deathLoss = DEATH_LOSS, spiritLoss = SPIRIT_LOSS, sicknessCap = SICK_CAP,
}

-- ---------------------------------------------------------------------------
-- Textes (tutoiement, courts)
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_DEATH       = "Après la mort",
	OPT_PAGE_DEATH_SUB   = "Mort ou fantôme : courir au corps ou passer par le guérisseur des esprits ?",
	OPT_DEATH_ENABLED    = "Conseil après la mort",
	OPT_DEATH_PANEL      = "En fenêtre (sinon une ligne dans le chat)",
	DEATH_TITLE          = "Après la mort",
	DEATH_QUESTION       = "Courir au corps ou guérisseur ?",
	DEATH_ROW_RUN        = "Corps",
	DEATH_ROW_HEALER     = "Guérisseur",
	DEATH_RUN            = "%d m, ~%s à vol d'oiseau",
	DEATH_RUN_SHORT      = "%d m, ~%s",
	DEATH_RUN_UNKNOWN    = "distance inconnue",
	DEATH_RUN_RELEASE    = "libère ton esprit pour voir la distance",
	DEATH_REPAIR         = "-%s de réparation",
	DEATH_REPAIR_PCT     = "-%d %% de durabilité",
	DEATH_SICK           = "%s de faiblesse",
	DEATH_SICK_NONE      = "pas de faiblesse à ton niveau",
	DEATH_SICK_UNKNOWN   = "faiblesse inconnue",
	DEATH_LOSS_NOTE      = "Les %d %% de la mort sont déjà perdus ; le guérisseur en prend %d %% de plus.",
	DEATH_VERDICT_RUN    = "Cours : plus court que la faiblesse.",
	DEATH_VERDICT_HEALER = "Guérisseur : la course est plus longue que la faiblesse.",
	DEATH_VERDICT_NONE   = "À toi de voir : distance inconnue.",
	DEATH_RULE           = "Règle : cours si la course dure moins que la faiblesse, sauf si des monstres gardent ton corps.",
	DEATH_CHAT           = "Après la mort — Cours : %s · Guérisseur : %s → %s",
	DEATH_CHAT_RUN       = "cours",
	DEATH_CHAT_HEALER    = "guérisseur",
	DEATH_CHAT_NONE      = "à toi de voir",
	DEATH_SEC            = "%d s",
	DEATH_MIN            = "%d min",
	DEATH_MIN_SEC        = "%d min %02d",
}
local EN = {
	OPT_PAGE_DEATH       = "After death",
	OPT_PAGE_DEATH_SUB   = "Dead or ghost: run back to your corpse or use the spirit healer?",
	OPT_DEATH_ENABLED    = "Advice after death",
	OPT_DEATH_PANEL      = "In a window (otherwise one chat line)",
	DEATH_TITLE          = "After death",
	DEATH_QUESTION       = "Corpse run or spirit healer?",
	DEATH_ROW_RUN        = "Corpse",
	DEATH_ROW_HEALER     = "Healer",
	DEATH_RUN            = "%d yd, ~%s as the crow flies",
	DEATH_RUN_SHORT      = "%d yd, ~%s",
	DEATH_RUN_UNKNOWN    = "distance unknown",
	DEATH_RUN_RELEASE    = "release your spirit to see the distance",
	DEATH_REPAIR         = "-%s in repairs",
	DEATH_REPAIR_PCT     = "-%d %% durability",
	DEATH_SICK           = "%s of sickness",
	DEATH_SICK_NONE      = "no sickness at your level",
	DEATH_SICK_UNKNOWN   = "sickness unknown",
	DEATH_LOSS_NOTE      = "The %d %% from dying is already gone; the healer takes %d %% more.",
	DEATH_VERDICT_RUN    = "Run: shorter than the sickness.",
	DEATH_VERDICT_HEALER = "Healer: the run takes longer than the sickness.",
	DEATH_VERDICT_NONE   = "Your call: distance unknown.",
	DEATH_RULE           = "Rule: run if the run is shorter than the sickness, unless mobs guard your corpse.",
	DEATH_CHAT           = "After death — Run: %s · Healer: %s → %s",
	DEATH_CHAT_RUN       = "run",
	DEATH_CHAT_HEALER    = "healer",
	DEATH_CHAT_NONE      = "your call",
	DEATH_SEC            = "%d s",
	DEATH_MIN            = "%d min",
	DEATH_MIN_SEC        = "%d min %02d",
}
ns.RegisterStrings(FR, EN)
ns.DEATH_STRINGS = { fr = FR, en = EN }   -- exposé aux tests (parité fr/en)

ns.RegisterDefaults({
	deathEnabled = true,    -- module « Après la mort »
	deathPanel   = true,    -- false = une ligne dans le chat
	deathPoint   = { point = "CENTER", x = 0, y = -140 },
})

-- Sous-page du QoL : pas d'interrupteur dans la navigation pour une
-- sous-page, d'où la case « Conseil après la mort » en tête de page.
ns.AddOptionPage({
	id = "death", title = "OPT_PAGE_DEATH", parent = "qol", group = "OPT_GROUP_QOL",
	rows = {
		{ key = "deathEnabled", label = "OPT_DEATH_ENABLED", kind = "bool" },
		{ key = "deathPanel",   label = "OPT_DEATH_PANEL",   kind = "bool" },
	},
})
ns.RegisterModule({ id = "death", key = "deathEnabled", label = "OPT_PAGE_DEATH", aliases = { "mort", "death" } })

-- ---------------------------------------------------------------------------
-- Lectures défensives
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

-- vector2 du client (méthode GetXY) ou simple table { x, y }
local function XY(v)
	if type(v) ~= "table" then return nil end
	if type(v.GetXY) == "function" then
		local ok, x, y = pcall(v.GetXY, v)
		if ok and type(x) == "number" and type(y) == "number" then return x, y end
	end
	if type(v.x) == "number" and type(v.y) == "number" then return v.x, v.y end
	return nil
end

local function PlayerLevel()
	return tonumber((Call(rawget(_G, "UnitLevel"), "player")))
end

function ns:IsGhost()
	return Call(rawget(_G, "UnitIsGhost"), "player") == true
end

function ns:IsDead()
	return Call(rawget(_G, "UnitIsDeadOrGhost"), "player") == true
end

-- ---------------------------------------------------------------------------
-- Distance au corps, en yards (nil si une API manque : jamais d'invention)
-- ---------------------------------------------------------------------------
function ns:CorpseDistance()
	if not (C_Map and C_DeathInfo) then return nil end
	local mapID = self:CurrentMap()
	if not mapID then return nil end
	local corpse = Call(C_DeathInfo.GetCorpseMapPosition, mapID)
	local player = Call(C_Map.GetPlayerMapPosition, mapID, "player")
	local cx, cy = XY(corpse)
	local px, py = XY(player)
	if not (cx and px) then return nil end
	-- 1) positions monde (yards) : vaut partout où les deux API répondent
	if type(C_Map.GetWorldPosFromMapPos) == "function" then
		local okC, contC, worldC = pcall(C_Map.GetWorldPosFromMapPos, mapID, corpse)
		local okP, contP, worldP = pcall(C_Map.GetWorldPosFromMapPos, mapID, player)
		local wcx, wcy = XY(okC and worldC or nil)
		local wpx, wpy = XY(okP and worldP or nil)
		if wcx and wpx and contC == contP then
			return math.sqrt((wcx - wpx) ^ 2 + (wcy - wpy) ^ 2)
		end
	end
	-- 2) taille de la carte en yards (Forever, client récent)
	local width, height = Call(C_Map.GetMapWorldSize, mapID)
	if type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
		return math.sqrt(((cx - px) * width) ^ 2 + ((cy - py) * height) ^ 2)
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Faiblesse de résurrection, en secondes
-- ---------------------------------------------------------------------------
function ns:SicknessFromLevel(level)
	level = tonumber(level)
	if not level then return nil end
	if level <= SICK_FREE_UPTO then return 0 end
	if level >= SICK_CAP_LEVEL then return SICK_CAP end
	return (level - SICK_FREE_UPTO) * 60
end

-- « 10 Min », « 5 min », « 30 Sec » : seul un nombre suivi d'une unité
-- reconnue compte, sinon la table (une chaîne du client mal lue ne doit pas
-- fausser le verdict).
function ns:ParseSicknessText(text)
	if type(text) ~= "string" then return nil end
	local s = ns.AsciiLower and ns.AsciiLower(text) or text:lower()
	local n = tonumber(s:match("(%d+)"))
	if not n then return nil end
	if s:find("sec") then return n end
	if s:find("min") then return n * 60 end
	return nil
end

function ns:DeathSickness(level)
	local fromGame = self:ParseSicknessText((Call(rawget(_G, "GetResSicknessDuration"))))
	if fromGame then return fromGame end
	return self:SicknessFromLevel(level or PlayerLevel())
end

-- ---------------------------------------------------------------------------
-- Durabilité que prendrait le guérisseur (équipement porté)
-- ---------------------------------------------------------------------------
function ns:SpiritDurabilityLoss()
	local fn = rawget(_G, "GetInventoryItemDurability")
	if type(fn) ~= "function" then return nil end
	local points, any = 0, false
	for slot = 1, 19 do
		local ok, current, max = pcall(fn, slot)
		if ok and type(current) == "number" and type(max) == "number" and max > 0 then
			any = true
			-- 25 % du maximum, sans descendre sous zéro
			points = points + math.min(current, math.floor(max * SPIRIT_LOSS))
		end
	end
	if not any then return nil end
	return points
end

-- ---------------------------------------------------------------------------
-- Bilan et verdict
-- ---------------------------------------------------------------------------
function ns:DeathAdvice()
	local ghost = self:IsGhost()
	local advice = { ghost = ghost, level = PlayerLevel() }
	advice.sickness = self:DeathSickness(advice.level)
	if ghost then
		advice.distance = self:CorpseDistance()
		if advice.distance then advice.runTime = advice.distance / GHOST_SPEED end
	end
	advice.points = self:SpiritDurabilityLoss()
	local rate = self:CharData().repairRate
	if type(rate) == "number" and rate > 0 and advice.points then
		advice.cost = math.floor(rate * advice.points + 0.5)
	end
	-- Règle simple, dite au joueur : le temps de course contre le temps de
	-- faiblesse. La réparation s'ajoute au guérisseur, donc à égalité on court.
	if advice.runTime and advice.sickness then
		advice.verdict = (advice.runTime < advice.sickness) and "run" or "healer"
	end
	return advice
end

function ns:FormatDeathTime(seconds)
	seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	if seconds < 60 then return self:F("DEATH_SEC", seconds) end
	if seconds % 60 == 0 then return self:F("DEATH_MIN", seconds / 60) end
	return self:F("DEATH_MIN_SEC", math.floor(seconds / 60), seconds % 60)
end

function ns:DeathRunText(advice, short)
	if not advice.ghost then return L.DEATH_RUN_RELEASE end
	if not advice.distance then return L.DEATH_RUN_UNKNOWN end
	return self:F(short and "DEATH_RUN_SHORT" or "DEATH_RUN", math.floor(advice.distance + 0.5), self:FormatDeathTime(advice.runTime))
end

function ns:DeathHealerText(advice)
	local parts = {}
	if advice.cost then
		parts[#parts + 1] = self:F("DEATH_REPAIR", self:FormatMoney(advice.cost))
	else
		-- taux de réparation jamais mesuré chez un marchand : le pourcentage seul
		parts[#parts + 1] = self:F("DEATH_REPAIR_PCT", SPIRIT_LOSS * 100)
	end
	if advice.sickness == nil then
		parts[#parts + 1] = L.DEATH_SICK_UNKNOWN
	elseif advice.sickness == 0 then
		parts[#parts + 1] = L.DEATH_SICK_NONE
	else
		parts[#parts + 1] = self:F("DEATH_SICK", self:FormatDeathTime(advice.sickness))
	end
	return table.concat(parts, ", ")
end

function ns:DeathVerdictText(advice)
	if advice.verdict == "run" then return Theme.T_GREEN .. L.DEATH_VERDICT_RUN .. "|r" end
	if advice.verdict == "healer" then return Theme.T_GOLD .. L.DEATH_VERDICT_HEALER .. "|r" end
	if advice.ghost then return Theme.T_GREY .. L.DEATH_VERDICT_NONE .. "|r" end
	return nil
end

function ns:DeathChatLine(advice)
	local word = (advice.verdict == "run" and L.DEATH_CHAT_RUN) or (advice.verdict == "healer" and L.DEATH_CHAT_HEALER) or L.DEATH_CHAT_NONE
	return self:F("DEATH_CHAT", self:DeathRunText(advice, true), self:DeathHealerText(advice), word)
end

-- ---------------------------------------------------------------------------
-- Fenêtre
-- ---------------------------------------------------------------------------
local WIDTH, MAX_LINES = 400, 6
local ROW_CARD, ROW_STEP = 24, 26    -- ligne en carte (corps, guérisseur, verdict)
local NOTE_LINE = 15                 -- interligne d'une note pâle (sur deux lignes)
local GAP = 14

-- Les lignes sont placées à chaque affichage : la note et la règle, plus
-- longues que la fenêtre, passent sur deux lignes (texte pâle, sans carte)
-- plutôt que d'être coupées.
local function Line(frame, index)
	frame.lines = frame.lines or {}
	local line = frame.lines[index]
	if line then return line end
	line = Theme.CreateListRow(frame, frame.innerWidth, ROW_CARD)
	line.text:ClearAllPoints()
	line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 12, -5)
	line.text:SetWidth(frame.innerWidth - 24)
	frame.lines[index] = line
	return line
end

function ns:EnsureDeathPanel()
	if self.deathFrame then return self.deathFrame end
	if not (Theme and Theme.CreateDialog) then return nil end
	local frame = Theme.CreateDialog(UIParent, WIDTH, 160, { name = "Ready2QuestDeathFrame", title = L.DEATH_TITLE,
		subtitle = L.DEATH_QUESTION })
	if not frame then return nil end
	if self.RestorePoint then self:RestorePoint(frame, "deathPoint", { point = "CENTER", x = 0, y = -140 }) end
	-- fermée à la main : plus rien jusqu'à la prochaine mort
	frame.closeButton = frame:AddFooterButton(L.OPT_CLOSE, function()
		ns.deathDismissed = true
		frame:Hide()
	end, "accent")
	self.deathFrame = frame
	return frame
end

function ns:DeathPanelRows(advice)
	local rows = {
		Theme.T_GOLD .. L.DEATH_ROW_RUN .. "|r  " .. self:DeathRunText(advice),
		Theme.T_GOLD .. L.DEATH_ROW_HEALER .. "|r  " .. self:DeathHealerText(advice),
		Theme.T_GREY .. self:F("DEATH_LOSS_NOTE", DEATH_LOSS * 100, SPIRIT_LOSS * 100) .. "|r",
	}
	local tall = { [3] = true }
	local verdict = self:DeathVerdictText(advice)
	if verdict then rows[#rows + 1] = verdict end
	rows[#rows + 1] = Theme.T_GREY .. L.DEATH_RULE .. "|r"
	tall[#rows] = true
	return rows, tall
end

function ns:ShowDeathPanel(advice)
	local ok, frame = pcall(self.EnsureDeathPanel, self)
	if not ok or not frame then
		if not ok and self.RecordError then self:RecordError("death:panel", frame) end
		return false
	end
	local rows, tall = self:DeathPanelRows(advice)
	local y = (frame.contentTop or -65) - GAP
	local rank = 0
	for index = 1, MAX_LINES do
		local text = rows[index]
		if text or (frame.lines and frame.lines[index]) then
			local line = Line(frame, index)
			local note = tall[index] == true
			local height = note and (2 * NOTE_LINE + 4) or ROW_CARD
			if note then
				line.bg:Hide()
				line.text:ClearAllPoints()
				line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 12, -2)
			else
				rank = rank + 1
				line.bg:Show()
				line:SetIndex(rank)
				line.text:ClearAllPoints()
				line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 12, -5)
			end
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.pad + 1, y)
			line:SetSize(frame.innerWidth, height)
			line.text:SetWordWrap(note)
			line.text:SetHeight(note and (height - 4) or 14)
			line.text:SetText(text or "")
			if text then line:Show(); y = y - height - (ROW_STEP - ROW_CARD) else line:Hide() end
		end
	end
	frame.visibleLines = #rows
	frame:SetHeight(-y - (ROW_STEP - ROW_CARD) + GAP + Theme.DIALOG_FOOTER)
	if not frame:IsShown() then
		frame:Show()
		if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	end
	return true
end

function ns:HideDeathPanel()
	if self.deathFrame then self.deathFrame:Hide() end
end

-- ---------------------------------------------------------------------------
-- Orchestration. `announce` = moment où une ligne de chat a du sens (la
-- libération, la fenêtre du guérisseur) ; le rafraîchissement de la distance
-- ne réécrit jamais dans le chat.
-- ---------------------------------------------------------------------------
function ns:EvaluateDeath(announce)
	local db = self:DB()
	if db.enabled == false or db.deathEnabled == false or not self:IsDead() or self:InInstance() then
		self.deathAdvice = nil
		self:HideDeathPanel()
		return nil
	end
	local advice = self:DeathAdvice()
	self.deathAdvice = advice
	if db.deathPanel ~= false then
		if not self.deathDismissed then self:ShowDeathPanel(advice) end
	else
		self:HideDeathPanel()
		if announce and advice.ghost then self:Print(self:DeathChatLine(advice)) end
	end
	return advice
end

function ns:EndDeath()
	self.deathAdvice, self.deathDismissed = nil, nil
	self:HideDeathPanel()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "CONFIRM_XP_LOSS",
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
	pcall(events.RegisterEvent, events, event)
end
local HANDLERS = {
	PLAYER_DEAD = function()
		ns.deathDismissed = nil      -- nouvelle mort : la fenêtre revient
		ns:EvaluateDeath(false)
	end,
	-- PLAYER_ALIVE : libéré en fantôme, OU relevé avant la libération
	PLAYER_ALIVE = function()
		if ns:IsGhost() then ns:EvaluateDeath(true) else ns:EndDeath() end
	end,
	PLAYER_UNGHOST = function() ns:EndDeath() end,
	CONFIRM_XP_LOSS = function() ns:EvaluateDeath(true) end,
	PLAYER_ENTERING_WORLD = function()
		if ns:IsDead() then ns:EvaluateDeath(false) else ns:EndDeath() end
	end,
	ZONE_CHANGED_NEW_AREA = function()
		if ns:IsDead() then ns:EvaluateDeath(false) else ns:EndDeath() end
	end,
}
events:SetScript("OnEvent", function(_, event)
	local handler = HANDLERS[event]
	if not handler then return end
	local ok, err = pcall(handler)
	if not ok and ns.RecordError then ns:RecordError("death:" .. tostring(event), err) end
end)
-- la distance baisse pendant la course : recalcul chaque seconde, seulement
-- quand la fenêtre est ouverte sur un fantôme
events:SetScript("OnUpdate", ns.Throttle(REFRESH, function()
	local frame = ns.deathFrame
	if not (frame and frame:IsShown() and ns.deathAdvice and ns.deathAdvice.ghost) then return end
	local ok, err = pcall(ns.EvaluateDeath, ns, false)
	if not ok and ns.RecordError then ns:RecordError("death:refresh", err) end
end))
ns.deathEvents = events

if ns.Mark then ns.Mark("Death") end
