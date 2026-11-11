-- QuestCompanion 1.2.0 : cadres et fonds tirés des images du jeu (bordures de
-- fenêtres, papiers à lettres, parchemin des hauts faits, écrans de chargement) :
-- palier de chacun et coffre qui le propose, pose sur le cadre (recadrage des
-- écrans de chargement), libellés fr et en.
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
	local bad = {}
	for id, tier in pairs(frames) do
		local def = NS:CompanionStyleDef("frame", id)
		if not (def and def.backdrop and def.backdrop.file and def.tier == tier and inChests["frame:" .. id] == tier) then
			bad[#bad + 1] = "cadre " .. id
		end
	end
	for id, tier in pairs(bgs) do
		local def = NS:CompanionStyleDef("bg", id)
		if not (def and def.texture and def.tier == tier and inChests["bg:" .. id] == tier) then bad[#bad + 1] = "fond " .. id end
	end
	Check("[ASSET] cadres (bordures du jeu) et fonds (images du jeu) : au bon palier, proposés par le coffre de ce palier",
		#bad == 0, table.concat(bad, ", "))
	local data = NS:CompanionData()
	data.unlocked["frame:carved"], data.unlocked["bg:kalimdor"], data.unlocked["bg:mail_og"] = true, true, true
	local frame = NS.companionFrame
	NS:CompanionSetStyle("frame", "carved")
	Check("[ASSET] cadre sculpté posé", frame.frameStyle == "carved" and frame.frameBackdrop == true)
	NS:CompanionSetStyle("bg", "kalimdor")
	local cropped = frame.bgTexture:find("LoadScreenKalimdor", 1, true) and frame.bgCoords and frame.bgCoords[1] == 0.25
	NS:CompanionSetStyle("bg", "mail_og")
	Check("[ASSET] fond écran de chargement recadré au centre ; lettre d'Orgrimmar entière, sans recadrage", cropped
		and frame.bgTexture:find("Stationery_OG1", 1, true) and frame.bgCoords == nil, tostring(frame.bgTexture))
	Check("[ASSET] libellés fr et en", NS.COMPANION_STRINGS.fr.COMP_BG_MOLTENCORE == "Cœur du Magma"
		and NS.COMPANION_STRINGS.en.COMP_FRAME_CARVED == "Carved")
	ResetWorld()
end
