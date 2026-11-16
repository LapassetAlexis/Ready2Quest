-- JournalAzeroth.lua -- Le carnet, la fiche de dresseur et les confirmations
-- gardés par clé de style (QuestCompanion 2.8.0 ; 3.1.2 : l'ancien habillage
-- « Azeroth » du carnet retiré, il ne reste que la relève)
--
-- Chaque fenêtre est construite une fois par clé (ns:StyleKey : « forge » au
-- thème forgé, « sobre » sinon) et gardée (ns.uiStyleCache) : un carnet né
-- forgé n'est jamais resservi en Sobre, ni l'inverse. Style changé à chaud
-- (/qc style) : un carnet (ou une fiche) affiché est remplacé tout de suite
-- par celui de l'autre clé, son état recopié ; un carnet fermé l'est à sa
-- prochaine ouverture.
local ADDON, ns = ...
if ns.blocked then return end

-- La clé de cache du carnet, de la fiche, des confirmations et du panneau
-- d'allure : « forge » ou « sobre ». Le cache, les noms globaux (Échap) et
-- la relève à chaud la suivent.
function ns:JournalStyleKey()
	return self.StyleKey and self:StyleKey() or "sobre"
end

local function Stash(self, field, frame, key)
	self.uiStyleCache[field] = self.uiStyleCache[field] or {}
	self.uiStyleCache[field][key] = frame
end

local function Cached(self, field, key)
	local slot = self.uiStyleCache and self.uiStyleCache[field]
	local frame = slot and slot[key]
	if frame then slot[key] = nil end
	return frame
end

-- Les confirmations du carnet (CompanionEffects.lua) : une par clé
do
	local ensure = ns.EnsureEffectsConfirm
	if ensure then
		function ns:EnsureEffectsConfirm(...)
			local key = self:JournalStyleKey()
			self.effectsConfirmByStyle = self.effectsConfirmByStyle or {}
			local cache = self.effectsConfirmByStyle
			local current = self.effectsConfirm
			if current and not current.styleKey then current.styleKey = ns.FrameStyleKey(current); cache[current.styleKey] = current end
			-- une question en cours garde sa fenêtre
			if current and (current.styleKey == key or (current.IsShown and current:IsShown())) then return current end
			if cache[key] then self.effectsConfirm = cache[key]; return cache[key] end
			self.effectsConfirm = nil
			local frame = ensure(self, ...)
			-- 3.1.0 (forgé) : la question est relevée au-dessus du carnet
			-- (SetFrameLevel, EffectsConfirmPlace) : l'habillage du socle (cadre,
			-- coins, médaillon, sur un cadre à part) monte avec elle, sinon le
			-- fond de la question le recouvre
			if frame and ns.QCForged() then ns.ForgeChromeFollows(frame) end
			if frame then frame.uiStyle, frame.styleKey = "sobre", key; cache[key] = frame end
			self.effectsConfirm = frame
			return frame
		end
	end
end

-- Le carnet et la fiche : repris du cache de leur clé, sinon construits
do
	local ensure = ns.EnsureJournalWindow
	if ensure then
		function ns:EnsureJournalWindow(...)
			if self.journalFrame then return self.journalFrame end
			local key = self:JournalStyleKey()
			local cached = Cached(self, "journalFrame", key)
			if cached then
				self.journalFrame = cached
				-- 2.11.0 (fiche 27) : suit les choix faits sous l'autre clé
				if self.JournalRestoreState then self:JournalRestoreState(cached) end
				return cached
			end
			local frame = ensure(self, ...)
			if frame then frame.uiStyle, frame.styleKey = "sobre", key end
			return frame
		end
	end
	local ensureTrainer = ns.EnsureTrainerWindow
	if ensureTrainer then
		function ns:EnsureTrainerWindow(...)
			if self.trainerFrame then return self.trainerFrame end
			local key = self:JournalStyleKey()
			local cached = Cached(self, "trainerFrame", key)
			if cached then
				self.trainerFrame = cached
				return cached
			end
			local frame = ensureTrainer(self, ...)
			if frame then frame.uiStyle, frame.styleKey = "sobre", key end
			return frame
		end
	end
end

-- ---------------------------------------------------------------------------
-- Changement de style à chaud : la fenêtre affichée est remplacée par celle
-- de la nouvelle clé (état recopié) ; fermée, elle le sera à l'ouverture
-- ---------------------------------------------------------------------------
local JOURNAL_STATE = { "kind", "activity", "offset", "zoneFilter", "zoneSort", "zoneOffset", "questFilter", "collKind",
	"menZone", "menState", "menRank", "menSort", "menSearch", "menType", "menOffset", "featsCat", "featsOffset",
	"zoneID", "zonePicked", "progPart", "progOffset", "progItemOffset", "guideSection", "guideOffset",
	"jukeView", "jukeOffset", "jukeSearch",   -- 2.12.0 : Juke-box
	"resView", "resSort", "resShow", "resNpc", "resOffset", "resPick" }   -- 2.15.0 : Réserve (3.0.0 : l'Échoppe a son onglet)

local function KeyOf(frame)
	return frame.styleKey or "sobre"
end

function ns:CarnetRestyle()
	local want = self:JournalStyleKey()
	local swapped = {}
	local journal = self.journalFrame
	if journal and KeyOf(journal) ~= want then
		local shown = journal:IsShown()
		journal:Hide()
		Stash(self, "journalFrame", journal, KeyOf(journal))
		self.journalFrame = nil
		if shown then
			local fresh = self:EnsureJournalWindow()
			if fresh then
				for _, key in ipairs(JOURNAL_STATE) do fresh[key] = journal[key] end
				if self.RefreshJournal then self:RefreshJournal() end
				if self.CloseOtherWindows then pcall(self.CloseOtherWindows, self, fresh) end
				fresh:Show()
			end
		end
		swapped.journal = true
	end
	local trainer = self.trainerFrame
	if trainer and KeyOf(trainer) ~= want then
		local shown = trainer:IsShown()
		trainer:Hide()
		Stash(self, "trainerFrame", trainer, KeyOf(trainer))
		self.trainerFrame = nil
		if shown then
			local fresh = self:EnsureTrainerWindow()
			if fresh then
				fresh.viewing = trainer.viewing
				fresh:Show()
				self:TrainerRefreshWindow()
			end
		end
		swapped.trainer = true
	end
	return swapped
end

do
	local apply = ns.ApplyUIStyle
	if apply then
		function ns:ApplyUIStyle(...)
			local style = apply(self, ...)
			local ok, err = pcall(self.CarnetRestyle, self)
			if not ok and self.RecordError then self:RecordError("carnet:restyle", err) end
			return style
		end
	end
end

if ns.Mark then ns.Mark("JournalAzeroth") end
