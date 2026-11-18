-- SpecimenStudy.lua -- étude d'espèce et records de taille (QuestCompanion 3.4.0)
--
-- 3.4.0 (docs/design-reserve-3.4) : les doublons nourrissent l'ÉTUDE de
-- l'espèce. Cinq tâches par espèce : capturée, trois étoiles, 5 captures,
-- 3 tailles, 3 caractères ; en plus, une pastille dorée : brillante.
--   * seules les captures faites soi-même comptent (origin == "capture") :
--     un échange ne prouve rien ;
--   * 2 paillettes par tâche finie APRÈS la mise à jour, 5 pour l'espèce
--     maîtrisée (les cinq) ; ce qui était déjà acquis est coché sans
--     paiement (capture.studyV) ;
--   * records par espèce : le plus petit et le plus grand indice de taille
--     de tes captures ; un nouveau record se dit dans le chat ;
--   * hauts faits : espèces maîtrisées (10, 50, 100), premier Familier et
--     premier Inséparable (lien), les 8 caractères et les 5 tailles capturés.
-- Données (au compte) : capture.study[npc] = { n = captures, z = bits de
-- tailles, t = bits de caractères, paid = bits des tâches payées, sh = brillante,
-- s3 = trois étoiles, lo, hi = indices records }.
--
-- API
--   ns.STUDY_TASKS = { "caught", "stars3", "five", "sizes", "traits" } (+ "shiny")
--   ns:SpecimenStudy(npc) -> { done = { [tâche] = bool }, count = n faites, mastered, n, sizes, traits, lo, hi, shiny }
--   ns:SpecimenStudyMastered() -> espèces maîtrisées
--   ns:SpecimenStudyNote(spec) (appelé à chaque capture)
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.STUDY_TASKS = { "caught", "stars3", "five", "sizes", "traits" }
ns.STUDY_REWARD = { task = 2, mastered = 5 }
ns.STUDY_NEED = { five = 5, sizes = 3, traits = 3 }
ns.STUDY_SCHEMA = 1

local FR = {
	STUDY_caught  = "Capturée",
	STUDY_stars3  = "Trois étoiles",
	STUDY_five    = "5 captures",
	STUDY_sizes   = "3 tailles",
	STUDY_traits  = "3 caractères",
	STUDY_shiny   = "Brillante",
	STUDY_TITLE   = "Étude de l'espèce",
	STUDY_DONE    = "Étude de %s : %s (+%d paillettes).",
	STUDY_MASTER  = "%s : espèce maîtrisée ! (+%d paillettes)",
	STUDY_RECORD_SMALL = "Record : ton plus petit %s (taille %d).",
	STUDY_RECORD_BIG   = "Record : ton plus grand %s (taille %d).",
	STUDY_RECORDS = "Records : %d à %d",
	STUDY_TODO    = "Étude à finir",
	STUDY_LINE    = "Étude %d / %d",
	STUDY_LEFT    = "reste : %s",
	STUDY_MASTERED_LINE = "Espèce maîtrisée",
}
local EN = {
	STUDY_caught  = "Caught",
	STUDY_stars3  = "Three stars",
	STUDY_five    = "5 catches",
	STUDY_sizes   = "3 sizes",
	STUDY_traits  = "3 personalities",
	STUDY_shiny   = "Shiny",
	STUDY_TITLE   = "Species study",
	STUDY_DONE    = "%s study: %s (+%d glitter).",
	STUDY_MASTER  = "%s: species mastered! (+%d glitter)",
	STUDY_RECORD_SMALL = "Record: your smallest %s (size %d).",
	STUDY_RECORD_BIG   = "Record: your biggest %s (size %d).",
	STUDY_RECORDS = "Records: %d to %d",
	STUDY_TODO    = "Study to finish",
	STUDY_LINE    = "Study %d / %d",
	STUDY_LEFT    = "left: %s",
	STUDY_MASTERED_LINE = "Species mastered",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.STUDY_STRINGS = { fr = FR, en = EN } end

local function Bit(index) return 2 ^ (index - 1) end
local function Has(bits, index) return math.floor((tonumber(bits) or 0) / Bit(index)) % 2 == 1 end
local function With(bits, index) if Has(bits, index) then return bits end return (tonumber(bits) or 0) + Bit(index) end
local function Count(bits)
	local n, b = 0, math.floor(tonumber(bits) or 0)
	while b > 0 do n = n + (b % 2); b = math.floor(b / 2) end
	return n
end

local SIZE_INDEX, TRAIT_INDEX = {}, {}
local function Indexes()
	if next(SIZE_INDEX) == nil then
		for index, def in ipairs(ns.SPECIMEN_SIZES or {}) do SIZE_INDEX[def.id] = index end
		for index, id in ipairs(ns.PERSONALITY_ORDER or {}) do TRAIT_INDEX[id] = index end
	end
end

local function StudyTable(self)
	local capture = self:CaptureData()
	if type(capture.study) ~= "table" then capture.study = {} end
	return capture.study, capture
end

local function Row(study, npc)
	npc = tonumber(npc) or npc
	local row = study[npc]
	if type(row) ~= "table" then row = { n = 0, z = 0, t = 0, paid = 0 }; study[npc] = row end
	return row
end

local function TaskDone(row, task)
	if task == "caught" then return (row.n or 0) >= 1 end
	if task == "stars3" then return row.s3 == true end
	if task == "five" then return (row.n or 0) >= ns.STUDY_NEED.five end
	if task == "sizes" then return Count(row.z) >= ns.STUDY_NEED.sizes end
	if task == "traits" then return Count(row.t) >= ns.STUDY_NEED.traits end
	if task == "shiny" then return row.sh == true end
	return false
end

-- une capture de plus dans la fiche d'étude
local function Note(row, spec, self)
	Indexes()
	row.n = (row.n or 0) + 1
	if SIZE_INDEX[spec.size or "normal"] then row.z = With(row.z, SIZE_INDEX[spec.size or "normal"]) end
	if spec.trait and TRAIT_INDEX[spec.trait] then row.t = With(row.t, TRAIT_INDEX[spec.trait]) end
	if (tonumber(spec.stars) or 1) >= 3 then row.s3 = true end
	if spec.shiny then row.sh = true end
	local zi = self.SpecimenSizeIndex and self:SpecimenSizeIndex(spec) or nil
	local record
	if zi then
		if not row.lo or zi < row.lo then
			if row.lo then record = "small" end
			row.lo = zi
		end
		if not row.hi or zi > row.hi then
			if row.hi then record = record or "big" end
			row.hi = zi
		end
	end
	return record, zi
end

-- Une fois : l'étude d'après tes captures actuelles, tâches cochées sans paiement
function ns:SpecimenStudyRetro()
	local study, capture = StudyTable(self)
	if capture.studyV == ns.STUDY_SCHEMA then return false end
	capture.studyV = ns.STUDY_SCHEMA
	-- refaite de zéro d'après les spécimens (jamais ajoutée à une étude existante)
	study = {}
	capture.study = study
	local specimens = ns.SpecimenStore and ns.SpecimenStore(self).specimens or capture.specimens or {}
	local n = 0
	for _, spec in pairs(specimens) do
		if spec.origin == "capture" then
			Note(Row(study, spec.npc), spec, self)
			n = n + 1
		end
	end
	for npc, row in pairs(study) do
		for index, task in ipairs(ns.STUDY_TASKS) do
			if TaskDone(row, task) then row.paid = With(row.paid, index) end
		end
		if Count(row.paid) >= #ns.STUDY_TASKS then row.paid = With(row.paid, #ns.STUDY_TASKS + 1) end
	end
	return true, n
end

-- La fiche d'étude d'une espèce
function ns:SpecimenStudy(npc)
	self:SpecimenStudyRetro()
	local study = StudyTable(self)
	local row = study[tonumber(npc) or npc] or { n = 0, z = 0, t = 0 }
	local done, count = {}, 0
	for _, task in ipairs(ns.STUDY_TASKS) do
		done[task] = TaskDone(row, task)
		if done[task] then count = count + 1 end
	end
	done.shiny = TaskDone(row, "shiny")
	return { done = done, count = count, mastered = count >= #ns.STUDY_TASKS, n = row.n or 0,
		sizes = Count(row.z), traits = Count(row.t), lo = row.lo, hi = row.hi, shiny = done.shiny }
end

function ns:SpecimenStudyMastered()
	self:SpecimenStudyRetro()
	local study = StudyTable(self)
	local n = 0
	for _, row in pairs(study) do
		local all = true
		for _, task in ipairs(ns.STUDY_TASKS) do if not TaskDone(row, task) then all = false; break end end
		if all then n = n + 1 end
	end
	return n
end

-- les caractères et tailles déjà capturés (hauts faits)
local function Distinct(self)
	local study = StudyTable(self)
	-- union des bits de toutes les espèces
	local zs, ts = {}, {}
	for _, row in pairs(study) do
		for i = 1, 16 do
			if Has(row.z, i) then zs[i] = true end
			if Has(row.t, i) then ts[i] = true end
		end
	end
	local nz, nt = 0, 0
	for _ in pairs(zs) do nz = nz + 1 end
	for index in pairs(ts) do
		local id = (ns.PERSONALITY_ORDER or {})[index]
		if id and ns.SPECIMEN_TRAIT_WEIGHTS then
			for _, pair in ipairs(ns.SPECIMEN_TRAIT_WEIGHTS) do if pair[1] == id then nt = nt + 1 end end
		end
	end
	return nz, nt
end
ns.SpecimenStudyDistinct = Distinct

-- À chaque capture faite soi-même : l'étude, ses paiements, les records
function ns:SpecimenStudyNote(spec)
	if type(spec) ~= "table" or spec.origin ~= "capture" or ns.studyDormant then return nil end
	local study = StudyTable(self)
	-- première lecture : la rétro compte déjà cette capture, sans paiement
	if self:SpecimenStudyRetro() then return 0 end
	local row = Row(study, spec.npc)
	local record, zi = Note(row, spec, self)
	local name = self:SpecimenLabel(spec)
	local gained = 0
	for index, task in ipairs(ns.STUDY_TASKS) do
		if TaskDone(row, task) and not Has(row.paid, index) then
			row.paid = With(row.paid, index)
			gained = gained + ns.STUDY_REWARD.task
			self:PaillettesAdd(ns.STUDY_REWARD.task, "study")
			self:Print(self:F("STUDY_DONE", name, L["STUDY_" .. task], ns.STUDY_REWARD.task))
		end
	end
	local masteredBit = #ns.STUDY_TASKS + 1
	if Count(row.paid) >= #ns.STUDY_TASKS and not Has(row.paid, masteredBit) then
		row.paid = With(row.paid, masteredBit)
		gained = gained + ns.STUDY_REWARD.mastered
		self:PaillettesAdd(ns.STUDY_REWARD.mastered, "study")
		self:Print(self:F("STUDY_MASTER", name, ns.STUDY_REWARD.mastered))
		-- (haut fait : la source « studyMastered » relit le nombre d'espèces maîtrisées)
		if self.FeatTouch and not ns.featsDormant then pcall(self.FeatTouch, self, "capture") end
	end
	if record and zi then
		self:Print(self:F(record == "small" and "STUDY_RECORD_SMALL" or "STUDY_RECORD_BIG", name, zi))
		if self.GuildFeatAnnounce then pcall(self.GuildFeatAnnounce, self, "record", { npc = spec.npc, zi = zi, kind = record }) end
	end
	-- hauts faits : toutes les tailles, tous les caractères tirés
	if self.FeatFlag and not ns.featsDormant then
		local nz, nt = Distinct(self)
		if nz >= #(ns.SPECIMEN_SIZES or {}) then pcall(self.FeatFlag, self, "sizesAll", "account") end
		if nt >= #(ns.SPECIMEN_TRAIT_WEIGHTS or {}) then pcall(self.FeatFlag, self, "traitsAll", "account") end
	end
	return gained
end

if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self, what, id)
		if what ~= "add" then return end
		local spec = self:SpecimenGet(id)
		if spec then pcall(self.SpecimenStudyNote, self, spec) end
	end)
	-- hauts faits du lien
	ns:RegisterCallback("BOND", function(self, what, id, level)
		if what ~= "level" or not self.FeatFlag or ns.featsDormant then return end
		if level >= 2 then pcall(self.FeatFlag, self, "bondFamiliar", "account") end
		if level >= 5 then pcall(self.FeatFlag, self, "bondInseparable", "account") end
	end)
end

if ns.On then
	ns.On("PLAYER_LOGIN", "study", function() pcall(ns.SpecimenStudyRetro, ns) end, "study:retro")
end

-- 3.4.0 : la ligne de la fiche des Créatures : « Étude 3 / 5, reste : 5
-- captures, 3 tailles · Records : 88 à 121 »
function ns:SpecimenStudyLine(npc)
	local st = self:SpecimenStudy(npc)
	local parts = {}
	if st.mastered then
		parts[1] = L.STUDY_MASTERED_LINE
	else
		local left = {}
		for _, task in ipairs(ns.STUDY_TASKS) do if not st.done[task] then left[#left + 1] = L["STUDY_" .. task] end end
		parts[1] = self:F("STUDY_LINE", st.count or 0, #ns.STUDY_TASKS) .. ", " .. self:F("STUDY_LEFT", table.concat(left, ", "))
	end
	if st.lo and st.hi then parts[#parts + 1] = self:F("STUDY_RECORDS", st.lo, st.hi) end
	return table.concat(parts, " · ")
end

if ns.Mark then ns.Mark("SpecimenStudy") end
