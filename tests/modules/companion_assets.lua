-- QuestCompanion 1.2.0 : cadres et fonds tirés des images du jeu (bordures de
-- fenêtres, papiers à lettres, parchemin des hauts faits, écrans de chargement).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

do
	Say("-- cosmétiques : images du jeu")
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
	local frames = { stone = 1, toast = 1, glue = 2, carved = 3 }
	local bgs = { mail_og = 1, mail_uc = 1, mail_tb = 1, deeds = 1, mail_ill = 2, mail_val = 2, mail_chr = 2,
		kalimdor = 2, eastern = 3, moltencore = 3, ahnqiraj = 3 }
	local inChests = {}
	for _, reward in ipairs(NS:ChestRewards()) do inChests[reward.kind .. ":" .. reward.id] = reward.tier end
	for id, tier in pairs(frames) do
		local def = NS:CompanionStyleDef("frame", id)
		Check("[ASSET] cadre " .. id .. " : bordure du jeu, palier " .. tier, def and def.backdrop and def.backdrop.file
			and def.tier == tier and inChests["frame:" .. id] == tier)
	end
	for id, tier in pairs(bgs) do
		local def = NS:CompanionStyleDef("bg", id)
		Check("[ASSET] fond " .. id .. " : image du jeu, palier " .. tier, def and def.texture and def.tier == tier
			and inChests["bg:" .. id] == tier)
	end
	local data = NS:CompanionData()
	data.unlocked["frame:carved"], data.unlocked["bg:kalimdor"], data.unlocked["bg:mail_og"] = true, true, true
	local frame = NS.companionFrame
	NS:CompanionSetStyle("frame", "carved")
	Check("[ASSET] cadre sculpté posé", frame.frameStyle == "carved" and frame.frameBackdrop == true)
	NS:CompanionSetStyle("bg", "kalimdor")
	Check("[ASSET] fond Kalimdor : l'écran de chargement, recadré au centre", frame.bgTexture:find("LoadScreenKalimdor", 1, true)
		and frame.bgCoords and frame.bgCoords[1] == 0.25, tostring(frame.bgTexture))
	NS:CompanionSetStyle("bg", "mail_og")
	Check("[ASSET] fond lettre d'Orgrimmar : image entière, plus de recadrage", frame.bgTexture:find("Stationery_OG1", 1, true)
		and frame.bgCoords == nil)
	Check("[ASSET] libellés fr et en", NS.COMPANION_STRINGS.fr.COMP_BG_MOLTENCORE == "Cœur du Magma"
		and NS.COMPANION_STRINGS.en.COMP_FRAME_CARVED == "Carved")
	ResetWorld()
end
