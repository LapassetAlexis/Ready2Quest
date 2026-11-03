-- Intégration : TOUS les modules chargés en même temps. Chaque module, testé
-- seul, tient dans le panneau ; c'est leur somme qui a fait déborder la
-- navigation sur le pied en v1.23.0 (« Marchand » sous les boutons).
local Check, ResetWorld, NS = T.Check, T.ResetWorld, T.NS

ResetWorld()
NS.optionsFrame = nil
NS:ToggleOptions()
local frame, lay = NS.optionsFrame, NS.OPT_LAYOUT
local footerTop = -(lay.height - 44)          -- filet du pied : 44 px au-dessus du bas
local lowest, lowestId = 0, nil
for _, nav in ipairs(frame.navButtons) do
	local _, _, _, _, y = nav:GetPoint()
	local bottom = (y or 0) - (nav.height or 22)
	if bottom < lowest then lowest, lowestId = bottom, nav.pageId end
end
Check("[INT] navigation complète : rien sous le pied", lowest >= footerTop,
	tostring(lowestId) .. " " .. lowest .. " >= " .. footerTop)
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
Check("[INT] les 6 modules sont déclarés", seen.depart and seen.stuff and seen.portrait and seen.camp and seen.expedition and seen.dungeon,
	(function() local t = {} for id in pairs(seen) do t[#t + 1] = id end table.sort(t) return table.concat(t, ",") end)())
