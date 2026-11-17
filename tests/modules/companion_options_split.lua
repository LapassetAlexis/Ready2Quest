-- Réglages du compagnon découpés en quatre pages (OptionsCompanionSplit.lua,
-- 3.1.2) : chaque réglage sur sa page, aucun perdu, aucune page trop longue.
local Check, Say, NS = T.Check, T.Say, T.QNS

Say("-- réglages du compagnon : quatre pages")
local pages, where, total = {}, {}, 0
for _, page in ipairs(NS.OPTION_PAGES or {}) do
	if page.id == "companionMain" or page.id == "companionQuiet" or page.id == "companionTalk" or page.id == "companionKeys" then
		pages[page.id] = page
		for _, row in ipairs(page.rows or {}) do
			if row.key then where[row.key] = page.id; total = total + 1 end
		end
	end
end
local wrong = {}
local want = {
	companionShow = "companionMain", companionNetShow = "companionMain", companionSize = "companionMain",
	companionAppearance = "companionMain", companionMove = "companionMain", captureNetAttach = "companionMain",
	companionStyle = "companionMain",
	companionCombatFade = "companionQuiet", companionHideInstance = "companionQuiet", companionHideTaxi = "companionQuiet",
	companionAggroBlink = "companionQuiet",
	companionChatter = "companionTalk", companionDiscovery = "companionTalk", companionJokes = "companionTalk", companionShouts = "companionTalk",
	companionLore = "companionTalk", companionTutorial = "companionTalk",
	bindToggle = "companionKeys", bindNet = "companionKeys", bindHunt = "companionKeys",
}
for key, id in pairs(want) do
	if where[key] ~= id then wrong[#wrong + 1] = key .. "->" .. tostring(where[key]) end
end
local longest = 0
for _, page in pairs(pages) do longest = math.max(longest, #(page.rows or {})) end
Check("[OPTS] compagnon : Compagnon, Discrétion, Paroles, Raccourcis ; chaque réglage à sa place, plus de page à rallonge",
	pages.companionMain and pages.companionQuiet and pages.companionTalk and pages.companionKeys and #wrong == 0
	and longest <= 12 and NS:CompanionOptionsSplit() == false, table.concat(wrong, ", ") .. " / max " .. longest)
local missing = {}
for _, id in ipairs({ "companionMain", "companionQuiet", "companionTalk", "companionKeys" }) do
	if #NS:OptionsUnreachable(id) > 0 then missing[#missing + 1] = id end
end
Check("[OPTS] chaque page découpée : tout atteignable, sans débordement", #missing == 0, table.concat(missing, ", "))

-- 3.1.2 : les étoiles d'un fond étoilé semées dans le médaillon rond
do
	Say("-- fond étoilé : étoiles dans le disque du médaillon")
	local frame = { stars = {} }
	for i = 1, #NS.COMPANION_STARS do
		local star = CreateFrame("Frame")
		frame.stars[i] = star
	end
	frame.ring = "forge"
	local mode = NS:CompanionPlaceStars(frame)
	local out, R = {}, NS.FORGE_RING
	local radius = (R.disc or 88) / 2
	for i, star in ipairs(frame.stars) do
		local p = star.lastPoint
		local dx, dy = (p.x or 0) - (R.x or 0), (p.y or 0) - (R.y or 0)
		if p.point ~= "CENTER" or p.relPoint ~= "TOP" or math.sqrt(dx * dx + dy * dy) > radius - 4 then out[#out + 1] = i end
	end
	local square = NS:CompanionPlaceStars(frame, true)
	Check("[OPTS] fond étoilé : en thème forgé, toutes les étoiles dans le disque ; sinon sur le cadre carré",
		mode == "forge" and #out == 0 and square == "square" and frame.stars[1].lastPoint.point == "TOPLEFT",
		table.concat(out, ","))
end

-- 3.1.2 : les étoiles scintillent au hasard, et reparaissent ailleurs dans le disque
do
	Say("-- fond étoilé : scintillement")
	local saved, savedRandom = NS.companionFrame, math.random
	local frame = CreateFrame("Frame")
	frame:SetSize(104, 104)
	frame.stars, frame.starsOn, frame.ring = {}, true, "forge"
	for i = 1, #NS.COMPANION_STARS do frame.stars[i] = CreateFrame("Frame") end
	NS.companionFrame = frame
	frame:Show()
	local seq, n = { 0.9, 0.1, 0.5, 0.3, 0.7 }, 0
	math.random = function() n = n + 1; return seq[(n - 1) % #seq + 1] end
	local alphas, moved, outside = {}, 0, 0
	local now = 0
	for _ = 1, 120 do
		now = now + 0.1
		NS:CompanionStarsTick(now)
		alphas[#alphas + 1] = frame.stars[1].alpha or 1
	end
	local R, lo, hi = NS.FORGE_RING, 1, 0
	for _, a in ipairs(alphas) do lo, hi = math.min(lo, a), math.max(hi, a) end
	for _, star in ipairs(frame.stars) do
		if star.moved then
			moved = moved + 1
			local p = star.lastPoint
			local dx, dy = (p.x or 0) - (R.x or 0), (p.y or 0) - (R.y or 0)
			if math.sqrt(dx * dx + dy * dy) > (R.disc or 88) / 2 then outside = outside + 1 end
		end
	end
	frame.starsOn = nil
	local idle = NS:CompanionStarsTick(now + 1) == false
	math.random, NS.companionFrame = savedRandom, saved
	Check("[OPTS] fond étoilé : chaque étoile s'allume et s'éteint en douceur, reparaît ailleurs dans le disque ; rien sans fond étoilé",
		hi - lo > 0.5 and moved > 0 and outside == 0 and idle,
		string.format("%.2f-%.2f, déplacées %d, hors disque %d", lo, hi, moved, outside))
end
