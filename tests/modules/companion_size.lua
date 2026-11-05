-- Compagnon : réglette « Taille » (Petit, Moyen, Grand, Très grand). Échelle
-- du cadre seulement (la bulle reste lisible), position recalée pour qu'il ne
-- saute pas ; ornements dans leur sous-page.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

do
	Say("-- compagnon : taille")
	ResetWorld()
	NS.companionRT, NS.companionSession = nil, nil
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:CompanionData().tutoDone = true
	Check("[SIZE] par défaut : Moyen (échelle 1)", NS:DB().companionSize == 2 and NS:CompanionSizeLevel() == 2)
	local frame = NS:EnsureCompanionFrame()
	Check("[SIZE] cadre à l'échelle du réglage", frame and frame:GetScale() == 1, frame and frame:GetScale())

	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companionMain")
	local row
	for _, r in ipairs(NS.optionsFrame.rows) do if r.def and r.def.key == "companionSize" then row = r end end
	Check("[SIZE] réglette « Taille » dans la page Compagnon", row and row.def.kind == "number" and row.label.text == "Taille"
		and row.value.text:find("Moyen", 1, true), row and row.value.text)
	local point = NS:DB().companionPoint
	local x, y = point.x, point.y
	row:Step(1)
	Check("[SIZE] « + » : Grand, cadre agrandi (1,3)", NS:DB().companionSize == 3 and frame:GetScale() == 1.3
		and row.value.text:find("Grand", 1, true))
	Check("[SIZE] position recalée : il reste au même endroit à l'écran", math.abs(point.x * 1.3 - x) < 0.01
		and math.abs(point.y * 1.3 - y) < 0.01, point.x .. "," .. point.y)
	row:Step(1)
	row:Step(1)
	Check("[SIZE] pas au-delà de Très grand (1,6)", NS:DB().companionSize == 4 and frame:GetScale() == 1.6)
	for _ = 1, 5 do row:Step(-1) end
	Check("[SIZE] pas en deçà de Petit (0,8)", NS:DB().companionSize == 1 and frame:GetScale() == 0.8)
	Check("[SIZE] repositionné : de retour au même endroit à l'écran", math.abs(point.x * 0.8 - x) < 0.01, point.x)

	NS:CompanionSay("EVOLVE", { force = true, args = { "X" } })
	Check("[SIZE] la bulle garde sa taille", NS.companionBubble and NS.companionBubble:GetScale() == 1)
	NS:DB().companionSize = 9
	Check("[SIZE] valeur hors bornes ramenée à 4", NS:CompanionSizeLevel() == 4)
	NS:DB().companionSize = 2
	NS:CompanionApplySize()

	-- réglage déjà sur Très grand : le cadre naît à cette taille
	NS.companionFrame:Hide()
	if NS.companionBubble then NS.companionBubble:Hide() end
	NS.companionFrame, NS.companionBubble, NS.companionHover = nil, nil, nil
	NS:DB().companionSize = 4
	Check("[SIZE] cadre créé à la taille réglée (Très grand)", NS:EnsureCompanionFrame():GetScale() == 1.6)
	NS:DB().companionSize = 2
	NS:CompanionApplySize()

	local ornaments
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionOrnaments" then ornaments = p end end
	Check("[SIZE] ornements dans leur sous-page", ornaments and ornaments.parent == "companion" and #ornaments.rows >= 8)
	local missing = {}
	for level = 1, 4 do
		local key = "COMP_SIZE_" .. level
		if not (NS.COMPANION_STRINGS.fr[key] and NS.COMPANION_STRINGS.en[key]) then missing[#missing + 1] = key end
	end
	Check("[SIZE] noms des tailles en français et en anglais", #missing == 0, table.concat(missing, ", "))
	NS.optionsFrame:Hide()
	ResetWorld()
end
