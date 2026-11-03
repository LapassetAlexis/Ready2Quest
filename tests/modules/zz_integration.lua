-- Intégration : TOUS les modules chargés en même temps. Chaque module, testé
-- seul, tient dans le panneau ; c'est leur somme qui a fait déborder la
-- navigation sur le pied en v1.23.0 (« Marchand » sous les boutons).
local Check, ResetWorld, NS = T.Check, T.ResetWorld, T.NS

ResetWorld()
NS.optionsFrame = nil
NS:ToggleOptions()
local frame, lay = NS.optionsFrame, NS.OPT_LAYOUT
local footerTop = -(lay.height - 44)          -- filet du pied : 44 px au-dessus du bas
-- pire cas : chaque module à sous-pages déplié tour à tour
for _, pageId in ipairs({ "general", "bags", "merchant" }) do
	NS:SelectOptionsPage(pageId)
	local lowest, lowestId = 0, nil
	for _, nav in ipairs(frame.navButtons) do
		if nav:IsShown() then
			local _, _, _, _, y = nav:GetPoint()
			local bottom = (y or 0) - (nav.rowH or 22)
			if bottom < lowest then lowest, lowestId = bottom, nav.pageId end
		end
	end
	Check("[INT] navigation (" .. pageId .. " ouvert) : rien sous le pied", lowest >= footerTop,
		tostring(lowestId) .. " " .. lowest .. " >= " .. footerTop)
end
-- ordre : tous les modules avant le titre QOL, un seul titre par groupe
local seenQol, misplaced = false, {}
for _, def in ipairs(NS.OPTION_PAGES) do
	if def.group == "OPT_GROUP_QOL" then seenQol = true
	elseif seenQol then misplaced[#misplaced + 1] = def.id end
end
Check("[INT] aucun module rangé sous le QoL", #misplaced == 0, table.concat(misplaced, ","))
Check("[INT] un titre par groupe dans la navigation", #frame.navGroups == 2, #frame.navGroups)
Check("[INT] panneau toujours à l'écran", lay.height <= lay.maxHeight, lay.height)

local overflow = {}
for id, page in pairs(frame.pages) do
	if page.contentBottom < lay.contentLimit then overflow[#overflow + 1] = id .. "=" .. page.contentBottom end
end
Check("[INT] aucune page de module ne déborde", #overflow == 0, table.concat(overflow, ", "))

local seen, dup = {}, {}
for _, module in ipairs(NS.MODULES) do
	if seen[module.id] then dup[#dup + 1] = module.id end
	seen[module.id] = true
end
Check("[INT] identifiants de module uniques", #dup == 0, table.concat(dup, ","))
Check("[INT] les modules sont déclarés", seen.depart and seen.stuff and seen.portrait and seen.camp and seen.expedition and seen.dungeon
	and seen.reward and seen.pace and seen.bagspace and seen.death and seen.companion
	and not seen.journal,     -- le carnet fait partie du Compagnon de route (v1.25.0)
	(function() local t = {} for id in pairs(seen) do t[#t + 1] = id end table.sort(t) return table.concat(t, ",") end)())

-- un alias de module ne doit jamais masquer l'identifiant d'un contrôle :
-- « /r2q module bags off » (forme d'avant la v1.22.0) vise le contrôle Sacs
do
	local clash = {}
	for _, def in ipairs(NS.checks or {}) do
		if NS:FindModule(def.id) then clash[#clash + 1] = def.id end
	end
	Check("[INT] aucun alias de module ne masque un contrôle", #clash == 0, table.concat(clash, ","))
	ResetWorld()
	NS:HandleCommand("module bags off")
	Check("[INT] /r2q module bags off coupe le contrôle Sacs", NS:IsModuleEnabled("bags") == false
		and NS:DB().bagspaceEnabled ~= false)
	NS:SetModuleEnabled("bags", true)
end

-- un module ne doit jamais parler pendant qu'un autre agit : le premier relevé
-- du compagnon est silencieux, même s'il naît d'un tampon et pas d'une connexion
do
	ResetWorld()
	T.Mock.world.level = 45
	T.Mock:Reset()
	if NS.FireCallback then NS:FireCallback("STAMP", { id = "zone:1", kind = "zone", name = "Test", new = true }) end
	Check("[INT] compagnon : premier relevé silencieux (pas de rafale de déblocages)",
		not T.Mock:Output():find("débloqué", 1, true), T.Mock:Output())
end

-- réglages du compagnon : un ornement verrouillé n'affiche pas un interrupteur allumé
do
	ResetWorld()
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companion")
	local wrong = {}
	for _, def in ipairs(NS.COMPANION_ORNAMENTS or {}) do
		for _, row in ipairs(NS.optionsFrame.rows) do
			if row.def and row.def.key == def.key and not NS:CompanionIsUnlocked("orn", def) and row.toggle and row.toggle.checked then
				wrong[#wrong + 1] = def.key
			end
		end
	end
	Check("[INT] ornements verrouillés : interrupteur éteint", #wrong == 0, table.concat(wrong, ","))
end

-- Résumé de stuff : « Simuler un changement » montre un vrai cadre, au-dessus
-- du panneau de réglages, avec les stats de la classe et un gain + une perte
do
	ResetWorld()
	NS.optionsFrame = nil
	NS.toastFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("toast")
	local page = NS.optionsFrame.pages.toast
	Check("[INT] résumé : bouton « Simuler un changement »", page.actionButtons and page.actionButtons.toastPreview ~= nil)
	NS:DB().showGearToast = false            -- même module coupé, l'aperçu s'affiche
	page.actionButtons.toastPreview:Click()
	local toast = NS.toastFrame
	Check("[INT] simulation : le cadre s'affiche", toast and toast:IsShown() == true)
	Check("[INT] simulation : au-dessus des réglages", toast and toast.strata == "FULLSCREEN_DIALOG", toast and toast.strata)
	Check("[INT] simulation : le panneau reste ouvert", NS.optionsFrame:IsShown() == true)
	-- une seule ligne s'affiche : la stat principale de la classe, qui alterne
	-- gain (1er clic) et perte (2e clic) pour voir les deux flèches
	local first = NS:SimulateGearToast()
	local second = NS:SimulateGearToast()
	Check("[INT] simulation : stat principale de la classe", first[1].label == "STR" and second[1].label == "STR", first[1].label)   -- guerrier du harnais
	Check("[INT] simulation : un clic gain, le suivant perte", (first[1].delta > 0) ~= (second[1].delta > 0),
		first[1].delta .. " / " .. second[1].delta)
	-- l'aperçu s'efface tout seul et rend sa couche normale au cadre
	T.Mock:Advance(30)
	Check("[INT] simulation : s'efface toute seule", toast:IsShown() == false)
	Check("[INT] fin de l'aperçu : couche normale", toast.strata == "HIGH", toast.strata)
	NS:DB().showGearToast = true
	NS:ShowGearToast({ { label = "STR", kind = "integer", polarity = true, delta = 2 } })
	Check("[INT] vrai changement : couche normale", toast.strata == "HIGH", toast.strata)
end
