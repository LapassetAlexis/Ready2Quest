-- Compagnon : réglette « Bavardage » (0 Muet, 1 Discret, 2 Calme, 3 Normal,
-- 4 Bavard). Ce que chaque cran laisse dire, à quel rythme ; reprise des
-- anciens interrupteurs ; ligne du panneau (nom du cran, phrase, infobulle,
-- bulle de confirmation) ; sourdine qui retient le cran.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local B = {}
function B.Reset(level)
	ResetWorld()
	NS.companionRT, NS.companionSession = nil, nil
	NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil, nil
	Mock.world.level = 11
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = level
end
-- chaque essai : on oublie la bulle précédente (seul le cran compte ici)
function B.Say(pool, opts)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	if NS.companionRT then NS.companionRT.lastAdvice = nil; NS.companionRT.cool = {} end
	return NS:CompanionSay(pool, opts) == true
end

-- 1. Reprise des anciens interrupteurs ------------------------------------------------------
do
	Say("-- bavardage : reprise")
	B.Reset(nil)
	Check("[CHAT] par défaut : Normal (3)", NS:CompanionChatterLevel() == 3 and NS:DB().companionChatter == 3)
	B.Reset(nil)
	NS:DB().companionBubbles = false
	Check("[CHAT] bulles coupées avant : Muet (0)", NS:CompanionChatterLevel() == 0)
	B.Reset(nil)
	NS:DB().companionTips = false
	Check("[CHAT] astuces coupées avant : Calme (2)", NS:CompanionChatterLevel() == 2)
	B.Reset(9)
	Check("[CHAT] valeur hors bornes ramenée à 4", NS:CompanionChatterLevel() == 4)
end

-- 2. Ce que chaque cran laisse dire --------------------------------------------------------
do
	Say("-- bavardage : crans")
	B.Reset(0)
	Check("[CHAT] Muet : rien, même un événement", not B.Say("QUEST") and not B.Say("EVOLVE", { force = true, args = { "X" } })
		and not B.Say("QUEST", { category = "advice", important = true }))

	B.Reset(1)
	Check("[CHAT] Discret : conseil important, oui", B.Say("QUEST", { category = "advice", important = true }))
	Check("[CHAT] Discret : conseil ordinaire, non", not B.Say("QUEST", { category = "advice" }))
	Check("[CHAT] Discret : ni réaction ni événement", not B.Say("QUEST") and not B.Say("EVOLVE", { args = { "X" } }))

	B.Reset(2)
	Check("[CHAT] Calme : tous les conseils et les grands moments", B.Say("QUEST", { category = "advice" })
		and B.Say("EVOLVE", { args = { "X" } }))
	Check("[CHAT] Calme : pas de réaction, pas d'astuce", not B.Say("QUEST") and NS:CompanionTryTip(true) == false)

	B.Reset(3)
	Check("[CHAT] Normal : réactions et conseils", B.Say("QUEST") and B.Say("QUEST", { category = "advice" }))

	-- rythme : écart entre deux bulles ordinaires, et entre deux conseils
	local gaps = {}
	for level = 3, 4 do
		B.Reset(level)
		NS:CompanionSay("QUEST")
		local start = NS.companionLastBubble
		Mock.now = start + NS.COMPANION_CHATTER[level].bubble - 1
		NS.companionBubbleUntil = nil
		local early = NS:CompanionSay("QUEST") == true
		Mock.now = start + NS.COMPANION_CHATTER[level].bubble + 1
		NS.companionBubbleUntil = nil
		local late = NS:CompanionSay("QUEST") == true
		gaps[level] = (not early) and late
	end
	Check("[CHAT] écart entre deux réactions : 20 s (Normal), 10 s (Bavard)", gaps[3] and gaps[4]
		and NS.COMPANION_CHATTER[3].bubble == 20 and NS.COMPANION_CHATTER[4].bubble == 10)

	B.Reset(3)
	NS:CompanionSay("QUEST", { category = "advice" })
	local first = NS.companionRT.lastAdvice
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	Mock.now = first + 60
	Check("[CHAT] deux conseils : pas avant 2 min (Normal)", NS:CompanionSay("QUEST", { category = "advice" }) == false)
	Mock.now = first + 121
	Check("[CHAT] … puis oui", NS:CompanionSay("QUEST", { category = "advice" }) == true)
	B.Reset(4)
	NS:CompanionSay("QUEST", { category = "advice" })
	first = NS.companionRT.lastAdvice
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	Mock.now = first + 61
	Check("[CHAT] Bavard : un conseil par minute", NS:CompanionSay("QUEST", { category = "advice" }) == true)
	B.Reset(4)
	NS:CompanionSay("QUEST", { cd = "kill" })
	Check("[CHAT] Bavard : pauses par famille divisées par deux",
		math.abs((NS.companionRT.cool.kill - Mock.now) - NS.COMPANION_RULES.cooldowns.kill / 2) < 0.01)
end

-- 3. Ligne du panneau ----------------------------------------------------------------------
do
	Say("-- bavardage : réglage")
	B.Reset(3)
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companionMain")
	local row
	for _, r in ipairs(NS.optionsFrame.rows) do if r.def and r.def.key == "companionChatter" then row = r end end
	Check("[CHAT] réglette dans la page Compagnon", row and row.def.kind == "number" and row.def.min == 0 and row.def.max == 4)
	Check("[CHAT] le cran s'affiche par son nom", row and row.value.text:find("Normal", 1, true) ~= nil, row and row.value.text)
	Check("[CHAT] une phrase dit ce qu'il fait", row and row.note and row.note.text == NS.L.COMP_CHATTER_DESC_3)
	_G.GameTooltip.lines = {}
	row.scripts.OnEnter(row)
	local tip = table.concat(_G.GameTooltip.lines, " | ")
	Check("[CHAT] infobulle : les cinq crans, le choisi en avant", #_G.GameTooltip.lines >= 7
		and tip:find(NS.L.COMP_CHATTER_DESC_0, 1, true) and tip:find("> " .. NS.L.COMP_CHATTER_DESC_3, 1, true), tip)
	row.scripts.OnLeave(row)

	NS.companionBubbleKey = nil
	row:Step(-1)
	Check("[CHAT] « - » : Calme, il le confirme", NS:DB().companionChatter == 2 and NS.companionBubbleKey == "CHATTER_2"
		and row.value.text:find("Calme", 1, true) and row.note.text == NS.L.COMP_CHATTER_DESC_2)
	row:Step(-1); row:Step(-1)
	Check("[CHAT] jusqu'à Muet : la bulle s'en va", NS:DB().companionChatter == 0
		and not (NS.companionBubble and NS.companionBubble:IsShown()))
	row:Step(-1)
	Check("[CHAT] pas en dessous de 0", NS:DB().companionChatter == 0)
	local missing = {}
	for level = 0, 4 do
		for _, key in ipairs({ "COMP_CHATTER_" .. level, "COMP_CHATTER_DESC_" .. level }) do
			if NS.COMPANION_STRINGS.en[key] == nil or NS.COMPANION_STRINGS.fr[key] == nil then missing[#missing + 1] = key end
		end
	end
	Check("[CHAT] textes des crans en français et en anglais", #missing == 0, table.concat(missing, ", "))
	NS.optionsFrame:Hide()
end

-- 4. Sourdine et tutoriel ------------------------------------------------------------------
do
	Say("-- bavardage : sourdine")
	B.Reset(2)
	NS:HandleCommand("compagnon muet")
	Check("[CHAT] muet : réglette à 0, le cran d'avant retenu", NS:DB().companionChatter == 0
		and NS:DB().companionChatterBefore == 2)
	NS:HandleCommand("compagnon muet")
	Check("[CHAT] muet à nouveau : retour au cran d'avant (Calme)", NS:DB().companionChatter == 2)
	local tuto = {}
	for _, key in ipairs(NS.COMPANION_POOLS.TUTO) do tuto[#tuto + 1] = NS.L[key] end
	Check("[CHAT] le tutoriel présente les conseils de route et la réglette",
		table.concat(tuto, " "):find("Bavardage", 1, true) and table.concat(tuto, " "):find("munitions", 1, true))
	B.Reset(3)
end
