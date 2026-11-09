-- CaptureSkip.lua -- espèces écartées du filet, filet discret (QuestCompanion 2.10.0)
--
-- « Ne plus proposer cette espèce » (retour de SoH, 8/11) : une croix au bout
-- de chaque ligne de la liste du filet (clic droit). L'espèce sort de la file
-- et n'y revient plus, sur tout le compte, sauf en brillante (rare et voulue).
-- Un message dans le chat dit comment annuler ; la carte « Espèces écartées
-- du filet » (page Au jour le jour) compte et propose « Tout reproposer ».
-- Aussi : le filet suit le contexte du compagnon (estompé en combat, caché en
-- donjon avec le réglage), Companion.lua, ns:CompanionNetContext.
-- Tout passe par des enveloppes des fonctions de CaptureQueue.lua (chargé
-- avant) : ce fichier ne touche à rien d'autre.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	CAPTURE_Q_SKIP_TIP       = "Ne plus proposer cette espèce au filet (une brillante le sera toujours).",
	CAPTURE_MSG_SKIPPED      = "%s ne sera plus proposée au filet. Pour annuler : réglages, Au jour le jour.",
	CAPTURE_MSG_UNSKIPPED    = "Toutes les espèces sont de nouveau proposées au filet.",
	OPT_CAPTURE_SKIPPED      = "Espèces écartées du filet",
	OPT_CAPTURE_SKIPPED_NONE = "aucune",
	OPT_CAPTURE_SKIPPED_ONE  = "1 espèce",
	OPT_CAPTURE_SKIPPED_MANY = "%d espèces",
	OPT_CAPTURE_UNSKIP       = "Tout reproposer",
}
local EN = {
	CAPTURE_Q_SKIP_TIP       = "Stop offering this species in the net (a shiny still will be).",
	CAPTURE_MSG_SKIPPED      = "%s won't be offered in the net any more. To undo: settings, Day to day.",
	CAPTURE_MSG_UNSKIPPED    = "Every species is offered in the net again.",
	OPT_CAPTURE_SKIPPED      = "Species left out of the net",
	OPT_CAPTURE_SKIPPED_NONE = "none",
	OPT_CAPTURE_SKIPPED_ONE  = "1 species",
	OPT_CAPTURE_SKIPPED_MANY = "%d species",
	OPT_CAPTURE_UNSKIP       = "Offer them all again",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_SKIP_STRINGS = { fr = FR, en = EN } end   -- exposé aux tests (parité fr/en)

-- croix « Passer » du butin (texture du client)
ns.CAPTURE_SKIP_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
ns.CAPTURE_SKIP_SIZE = 18

-- ---------------------------------------------------------------------------
-- Données : db.capture.skip = { [npcID] = true } (au compte)
-- ---------------------------------------------------------------------------
local function SkipTable(self, create)
	if not self.CaptureAccount then return nil end
	local account = self:CaptureAccount()
	if type(account.skip) ~= "table" then
		if not create then return nil end
		account.skip = {}
	end
	return account.skip
end

function ns:CaptureSkipped(npcID)
	local skip = SkipTable(self, false)
	return skip ~= nil and npcID ~= nil and skip[tonumber(npcID) or npcID] == true
end

function ns:CaptureSkippedCount()
	local count = 0
	for _, on in pairs(SkipTable(self, false) or {}) do if on == true then count = count + 1 end end
	return count
end

function ns:CaptureSkipSpecies(npcID, name)
	if npcID == nil then return false end
	SkipTable(self, true)[tonumber(npcID) or npcID] = true
	-- la raison devient nil : l'espèce sort de la file
	if self.CaptureQueuePrune then self:CaptureQueuePrune() end
	if self.CaptureQueueRefresh then self:CaptureQueueRefresh() end
	self:Print(self:F("CAPTURE_MSG_SKIPPED", tostring(name or npcID)))
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return true
end

function ns:CaptureUnskipAll()
	local skip = SkipTable(self, false)
	if skip then for key in pairs(skip) do skip[key] = nil end end
	self:Print(L.CAPTURE_MSG_UNSKIPPED)
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return true
end

function ns:CaptureSkippedText()
	local count = self:CaptureSkippedCount()
	if count == 0 then return L.OPT_CAPTURE_SKIPPED_NONE end
	if count == 1 then return L.OPT_CAPTURE_SKIPPED_ONE end
	return self:F("OPT_CAPTURE_SKIPPED_MANY", count)
end

-- ---------------------------------------------------------------------------
-- Enveloppes de CaptureQueue.lua
-- ---------------------------------------------------------------------------
do
	-- une espèce écartée n'entre plus dans la file (sauf brillante)
	local reason = ns.CaptureQueueReason
	if reason then
		function ns:CaptureQueueReason(candidate, ...)
			if type(candidate) == "table" and not candidate.shiny and self:CaptureSkipped(candidate.npcID) then return nil end
			return reason(self, candidate, ...)
		end
	end

	-- une croix au bout de chaque ligne de la liste
	local ensure = ns.EnsureCaptureQueueList
	if ensure then
		function ns:EnsureCaptureQueueList(...)
			local frame = ensure(self, ...)
			if not frame or frame.skipReady or not (Theme and Theme.CreateIconButton) then return frame end
			frame.skipReady = true
			for _, row in ipairs(frame.rows or {}) do
				row.skip = Theme.CreateIconButton(row, ns.CAPTURE_SKIP_SIZE, ns.CAPTURE_SKIP_ICON, function(b)
					local candidate = b:GetParent().candidate
					if candidate then ns:CaptureSkipSpecies(candidate.npcID, candidate.name) end
				end, L.CAPTURE_Q_SKIP_TIP)
				row.skip:SetPoint("RIGHT", row, "RIGHT", -2, 0)
				if row.detail and row.detail.GetWidth then
					local width = tonumber(row.detail:GetWidth()) or 0
					if width > 40 then row.detail:SetWidth(width - ns.CAPTURE_SKIP_SIZE - 4) end
				end
				row.skip:Hide()
			end
			return frame
		end
	end

	-- la croix est cachée pour une brillante (toujours proposée)
	local refreshList = ns.CaptureRefreshQueueList
	if refreshList then
		function ns:CaptureRefreshQueueList(...)
			local a, b = refreshList(self, ...)
			local frame = self.captureQueueList
			for _, row in ipairs(frame and frame.rows or {}) do
				if row.skip then
					if row.candidate and not row.candidate.shiny then row.skip:Show() else row.skip:Hide() end
				end
			end
			return a, b
		end
	end

	-- le filet suit le compagnon : estompé en combat, caché en donjon (réglage)
	local refresh = ns.CaptureQueueRefresh
	if refresh then
		function ns:CaptureQueueRefresh(...)
			local a, b = refresh(self, ...)
			local button = self.captureNetButton
			if button and button:IsShown() and self.CompanionNetContext then self:CompanionNetContext(button) end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Réglages : page Au jour le jour, après les limites de recapture
-- ---------------------------------------------------------------------------
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local at, present = #ns.DAILY_OPTION_ROWS + 1, false
	for index, row in ipairs(ns.DAILY_OPTION_ROWS) do
		if row.key == "companionRetryRare" then at = index + 1 end
		if row.key == "captureSkipReset" then present = true end
	end
	if not present then
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = "captureSkipReset", label = "OPT_CAPTURE_SKIPPED", kind = "action",
			button = "OPT_CAPTURE_UNSKIP" })
	end
end
do
	local run = ns.RunOptionAction
	function ns:RunOptionAction(key, ...)
		if key == "captureSkipReset" then return self:CaptureUnskipAll() end
		if run then return run(self, key, ...) end
	end
	-- la carte montre le nombre d'espèces écartées, à gauche du bouton
	local refresh = ns.RefreshOptions
	if refresh then
		function ns:RefreshOptions(...)
			local a, b = refresh(self, ...)
			local frame = self.optionsFrame
			for _, card in ipairs(frame and frame.rows or {}) do
				if card.def and card.def.key == "captureSkipReset" and card.value then
					card.value:SetText(self:CaptureSkippedText())
					card.value:Show()
				end
			end
			return a, b
		end
	end
end

if ns.Mark then ns.Mark("CaptureSkip") end
