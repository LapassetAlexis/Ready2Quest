-- ReserveTidy.lua -- « Faire de la place » dans la Réserve (3.2.0)
--
-- Quand la Réserve est pleine ou presque (RESERVE_TIDY_NEAR places ou moins),
-- on propose de relâcher les spécimens les moins précieux, d'un coup :
--   * jamais un brillant, ni ce que SpecimenCanRelease refuse (référence du
--     Codex, apparence portée, meilleur que la référence) ;
--   * d'abord les moins d'étoiles, puis l'espèce la plus en double dans la
--     Réserve, puis le plus ancien.
-- La page Réserve du carnet montre la sélection (les autres vignettes
-- s'estompent ; un clic sur une vignette l'ajoute ou la retire), la fiche
-- de droite le total de paillettes et « Relâcher (n) » / « Annuler ».
-- Ouvert par le bouton « Faire de la place » de la page, ou /qc tri (le
-- message de capture refusée et la carte de capture le rappellent).
-- Le compagnon prévient une fois quand la Réserve arrive à RESERVE_TIDY_NEAR
-- places de la fin (de nouveau après être redescendu en dessous).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.RESERVE_TIDY_COUNT = 5
ns.RESERVE_TIDY_NEAR = 2
ns.RESERVE_TIDY_DIM = 0.4     -- vignettes hors sélection

local FR = {
	RES_TIDY_BUTTON   = "Faire de la place",
	RES_TIDY_TITLE    = "Faire de la place",
	RES_TIDY_LINE     = "%s %s : +%d",
	RES_TIDY_MORE     = "… et %d autre(s)",
	RES_TIDY_TOTAL    = "Total : +%d paillettes",
	RES_TIDY_HINT     = "Clique une vignette pour l'ajouter ou la retirer.",
	RES_TIDY_NONE     = "Rien à relâcher : brillants, références du Codex et apparences portées sont protégés.",
	RES_TIDY_YES      = "Relâcher (%d)",
	RES_TIDY_NO       = "Annuler",
	RES_TIDY_DONE     = "%d spécimen(s) relâché(s) : +%d paillettes (solde %d).",
	RES_TIDY_EMPTY    = "Réserve : rien à relâcher (brillants, références du Codex et apparences portées sont protégés).",
	HELP_TIDY         = "/qc tri -- faire de la place dans la Réserve (les spécimens les moins précieux)",
	CAPTURE_TIDY_HINT = " /qc tri pour faire de la place.",
}
local EN = {
	RES_TIDY_BUTTON   = "Make room",
	RES_TIDY_TITLE    = "Make room",
	RES_TIDY_LINE     = "%s %s: +%d",
	RES_TIDY_MORE     = "… and %d more",
	RES_TIDY_TOTAL    = "Total: +%d glitter",
	RES_TIDY_HINT     = "Click a tile to add or remove it.",
	RES_TIDY_NONE     = "Nothing to release: shinies, Codex references and worn looks are protected.",
	RES_TIDY_YES      = "Release (%d)",
	RES_TIDY_NO       = "Cancel",
	RES_TIDY_DONE     = "%d specimen(s) released: +%d glitter (balance %d).",
	RES_TIDY_EMPTY    = "Reserve: nothing to release (shinies, Codex references and worn looks are protected).",
	HELP_TIDY         = "/qc tri -- make room in the Reserve (the least precious specimens)",
	CAPTURE_TIDY_HINT = " /qc tri to make room.",
}
ns.RegisterStrings(FR, EN)

-- le compagnon : la Réserve presque pleine (%d/%d)
ns.RegisterCompanionLines({
	RESERVE_NEAR = {
		{ "Ma réserve déborde (%d/%d) ! On fait le tri ? /qc tri", "My reserve is overflowing (%d/%d)! Tidy up? /qc tri" },
		{ "Plus beaucoup de place (%d/%d)… On relâche les moins jolis ? /qc tri", "Running out of room (%d/%d)… Release the plainest ones? /qc tri" },
		{ "%d sur %d, ça se bouscule là-dedans ! /qc tri", "%d out of %d, it's getting crowded in there! /qc tri" },
	},
}, true)
local rules = ns.COMPANION_RULES
if rules and type(rules.cooldowns) == "table" then rules.cooldowns.reserve = 600 end

-- ---------------------------------------------------------------------------
-- Choix des spécimens
-- ---------------------------------------------------------------------------
-- Les relâchables, du moins précieux au plus précieux (table neuve)
function ns:ReserveTidyRanked()
	local all = self:SpecimenList({ where = "reserve" })
	local perNpc = {}
	for _, spec in ipairs(all) do perNpc[spec.npc] = (perNpc[spec.npc] or 0) + 1 end
	local list = {}
	for _, spec in ipairs(all) do
		if not spec.shiny and self:SpecimenCanRelease(spec.id) then list[#list + 1] = spec end
	end
	table.sort(list, function(a, b)
		local sa, sb = tonumber(a.stars) or 1, tonumber(b.stars) or 1
		if sa ~= sb then return sa < sb end
		local da, db = perNpc[a.npc] or 0, perNpc[b.npc] or 0
		if da ~= db then return da > db end
		local ta, tb = tonumber(a.at) or 0, tonumber(b.at) or 0
		if ta ~= tb then return ta < tb end
		return tostring(a.id) < tostring(b.id)
	end)
	return list
end

-- Les `n` premiers (RESERVE_TIDY_COUNT) : liste, paillettes rendues
function ns:ReserveTidyCandidates(n)
	n = tonumber(n) or ns.RESERVE_TIDY_COUNT
	local ranked, list, gain = self:ReserveTidyRanked(), {}, 0
	for index = 1, math.min(n, #ranked) do
		list[index] = ranked[index]
		gain = gain + self:SpecimenReleaseValue(ranked[index])
	end
	return list, gain
end

function ns:ReserveNearFull()
	return self:SpecimenReserveCount() >= self:ReserveCapacity() - ns.RESERVE_TIDY_NEAR
end

-- ---------------------------------------------------------------------------
-- Sélection (frame.resTidy = { [id] = true }, frame.resTidyOrder = { id, … })
-- ---------------------------------------------------------------------------
local function Frame(self) return self.journalFrame end

function ns:ReserveTidyActive()
	local frame = Frame(self)
	return frame ~= nil and frame.resTidy ~= nil
end

-- Ouvre la sélection : rend le nombre de spécimens proposés
function ns:ReserveTidyStart()
	local frame = Frame(self)
	local list = self:ReserveTidyCandidates()
	if #list == 0 then
		self:Print(L.RES_TIDY_EMPTY)
		if frame then frame.resTidy, frame.resTidyOrder = nil, nil end
		if self.RefreshJournal then self:RefreshJournal() end
		return 0
	end
	if frame then
		frame.resTidy, frame.resTidyOrder = {}, {}
		for _, spec in ipairs(list) do
			frame.resTidy[spec.id] = true
			frame.resTidyOrder[#frame.resTidyOrder + 1] = spec.id
		end
		frame.resConfirm, frame.resView = nil, "reserve"
	end
	if self.RefreshJournal then self:RefreshJournal() end
	return #list
end

-- Clic sur une vignette pendant la sélection : ajoute ou retire
function ns:ReserveTidyToggle(id)
	local frame = Frame(self)
	if not (frame and frame.resTidy and id) then return false end
	if frame.resTidy[id] then
		frame.resTidy[id] = nil
		for index, other in ipairs(frame.resTidyOrder) do
			if other == id then table.remove(frame.resTidyOrder, index); break end
		end
	else
		local spec = self:SpecimenGet(id)
		if not spec or spec.shiny or not self:SpecimenCanRelease(id) then return false end
		frame.resTidy[id] = true
		frame.resTidyOrder[#frame.resTidyOrder + 1] = id
	end
	if self.RefreshJournal then self:RefreshJournal() end
	return frame.resTidy[id] == true
end

function ns:ReserveTidyCancel()
	local frame = Frame(self)
	if frame then frame.resTidy, frame.resTidyOrder = nil, nil end
	if self.RefreshJournal then self:RefreshJournal() end
end

-- La sélection : spécimens (dans l'ordre), paillettes
function ns:ReserveTidySelection()
	local frame = Frame(self)
	local list, gain = {}, 0
	for _, id in ipairs(frame and frame.resTidyOrder or {}) do
		local spec = self:SpecimenGet(id)
		if spec then
			list[#list + 1] = spec
			gain = gain + self:SpecimenReleaseValue(spec)
		end
	end
	return list, gain
end

-- « Relâcher (n) » : rend le nombre relâché, les paillettes gagnées
function ns:ReserveTidyConfirm()
	local list = self:ReserveTidySelection()
	local count, gain = 0, 0
	for _, spec in ipairs(list) do
		local got = self:SpecimenRelease(spec.id, true)
		if got then count, gain = count + 1, gain + got end
	end
	local frame = Frame(self)
	if frame then frame.resTidy, frame.resTidyOrder, frame.resPick = nil, nil, nil end
	if count > 0 then self:Print(self:F("RES_TIDY_DONE", count, gain, self:Paillettes())) end
	if self.RefreshJournal then self:RefreshJournal() end
	return count, gain
end

-- /qc tri : le carnet sur la Réserve, sélection ouverte
function ns:OpenJournalReserveTidy()
	if not self.ToggleJournal then return self:ReserveTidyStart() end
	local frame = self:ToggleJournal(true)
	if frame then
		frame.resView = "reserve"
		if self.SelectJournalKind then self:SelectJournalKind("reserve") end
	end
	return self:ReserveTidyStart()
end

ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["tri"] = function(self) return self:OpenJournalReserveTidy() end
ns.EXTRA_COMMANDS["tidy"] = ns.EXTRA_COMMANDS["tri"]
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then table.insert(section[2], "HELP_TIDY") end
	end
end

-- ---------------------------------------------------------------------------
-- Le compagnon prévient, une fois, quand la Réserve arrive presque au bout
-- ---------------------------------------------------------------------------
function ns:ReserveTidyWarn()
	local capture = self.CaptureData and self:CaptureData()
	if not capture then return false end
	if not self:ReserveNearFull() then
		capture.tidyWarned = nil
		return false
	end
	if capture.tidyWarned or #self:ReserveTidyCandidates(1) == 0 then return false end
	local said = self.CompanionSay and self:CompanionSay("RESERVE_NEAR", { cd = "reserve",
		args = { self:SpecimenReserveCount(), self:ReserveCapacity() } })
	if said then capture.tidyWarned = true end
	return said and true or false
end

if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self, what)
		if what == "add" or what == "release" or what == "take" or what == "slots" then pcall(self.ReserveTidyWarn, self) end
	end)
end

if ns.Mark then ns.Mark("ReserveTidy") end
