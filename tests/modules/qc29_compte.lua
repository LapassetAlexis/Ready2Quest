-- QuestCompanion 2.9.0 : collection de captures au compte (Capture.lua,
-- ns:CaptureAccount) : chaque personnage y verse une fois la sienne.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS

do
	Say("-- qc29 : collection au compte")
	ResetWorld()
	local db = NS:DB()
	local me = NS:CharKey()
	db.chars = db.chars or {}
	db.chars[me] = db.chars[me] or {}
	db.chars[me].companion = { capture = { count = 2, tries = 7, items = { appat = 8, lasso = 1, sifflet = 0 }, creatures = {
		[1] = { name = "Loup", normal = true, stars = 1, at = 500 },
		[2] = { name = "Ancien brillant", at = 300, shiny = true },             -- fiche d'avant 1.6.0
	} } }
	db.chars["Alt-Royaume"] = { companion = { capture = { count = 2, tries = 3, items = { appat = 9, lasso = 4, sifflet = 2 }, creatures = {
		[1] = { name = "Loup", normal = false, shiny = true, shinyStars = 2, shinyAt = 900, stars = 3, at = 200 },
		[3] = { name = "Ours", normal = true, stars = 2, at = 100 },
	} } } }
	db.capture, NS.captureMergedChar = nil, nil
	local acc = NS:CaptureData()
	local wolf = acc.creatures[1]
	Check("[CPT] union des espèces des deux personnages", acc.creatures[1] and acc.creatures[2] and acc.creatures[3] and acc.count == 3)
	Check("[CPT] même espèce : les deux versions, meilleures étoiles, dates les plus anciennes", wolf.normal == true
		and wolf.shiny == true and wolf.stars == 3 and wolf.shinyStars == 2 and wolf.at == 200 and wolf.shinyAt == 900)
	Check("[CPT] fiche d'avant 1.6.0 : la brillante seule, sa date gardée", acc.creatures[2].normal == false
		and acc.creatures[2].shinyAt == 300 and NS:CaptureHas(2, true) and not NS:CaptureHas(2, false))
	Check("[CPT] aides additionnées, dans la limite de la besace", acc.items.appat == 10 and acc.items.lasso == 5
		and acc.items.sifflet == 2 and acc.tries == 10)
	Check("[CPT] anciennes collections gardées telles quelles", db.chars["Alt-Royaume"].companion.capture.creatures[3] ~= nil
		and db.chars[me].companion.capture.creatures[1].shiny == nil)
	Check("[CPT] le personnage voit toute la collection", NS:CaptureHas(3) and NS:CaptureHas(1, true))
	-- un personnage jamais vu verse la sienne une seule fois, à son arrivée
	db.chars["Nouveau-Royaume"] = { companion = { capture = { creatures = { [4] = { name = "Raptor", normal = true } }, items = {} } } }
	local realKey = NS.CharKey
	NS.CharKey = function() return "Nouveau-Royaume" end
	NS.captureMergedChar = nil
	acc = NS:CaptureData()
	Check("[CPT] nouveau personnage : sa collection rejoint le compte", acc.creatures[4] ~= nil and acc.count == 4
		and acc.mergedFrom["Nouveau-Royaume"] == true)
	acc.creatures[4] = nil
	NS.captureMergedChar = nil
	acc = NS:CaptureData()
	Check("[CPT] … une seule fois (pas reversée à la connexion suivante)", acc.creatures[4] == nil)
	NS.CharKey = realKey
	db.capture, NS.captureMergedChar = nil, nil
end
