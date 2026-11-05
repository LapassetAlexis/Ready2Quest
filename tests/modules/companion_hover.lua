-- Compagnon : la fiche au survol (nom, stade, humeur, caractère, envies, aide).
-- Signalé en jeu (1.1.0-beta1) : l'aide en gris passait sous les barres des
-- envies. Tout est placé de haut en bas, le cadre prend la hauteur du contenu.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

do
	Say("-- compagnon : fiche au survol")
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
	NS:CompanionShowHover()
	local hover = NS.companionHover
	local last = hover.bars.curiosity
	Check("[HOVER] l'aide sous la dernière barre, sans la toucher", hover.hint.top < last.top - 12,
		tostring(hover.hint.top) .. " / " .. tostring(last.top))
	Check("[HOVER] les envies sous la ligne du stade", hover.bars.hunger.top < -22)
	local short = hover.layoutHeight
	Check("[HOVER] le cadre englobe l'aide", short >= -hover.hint.top + 12, short)
	-- une ligne de stade plus longue (le caractère) : tout descend, le cadre grandit
	local saved = NS.CompanionTrait
	NS.CompanionTrait = function() return "mischievous" end
	NS:CompanionRefreshHover()
	NS.CompanionTrait = saved
	Check("[HOVER] le caractère dans la ligne du stade", hover.sub:GetText():find("Espiègle", 1, true) ~= nil, hover.sub:GetText())
	local subBottom = -22 - NS.CompanionHoverTextHeight(hover.sub, 34)
	Check("[HOVER] ligne du stade sur deux lignes : les barres descendent dessous", hover.bars.hunger.top <= subBottom - 4,
		tostring(hover.bars.hunger.top) .. " / " .. tostring(subBottom))
	Check("[HOVER] l'aide reste sous les barres", hover.hint.top < hover.bars.curiosity.top - 12)
	Check("[HOVER] une ligne plus longue : le cadre grandit, rien ne se chevauche", hover.layoutHeight >= short)
	local before = hover.layoutHeight
	hover.hint:SetText(string.rep("aide très longue ", 12))
	NS:CompanionLayoutHover()
	Check("[HOVER] aide plus longue : le cadre grandit", hover.layoutHeight > before, hover.layoutHeight)
	hover.hint:SetText(NS.L.COMP_HOVER_HINT)
	NS:CompanionHideHover()
	ResetWorld()
end
