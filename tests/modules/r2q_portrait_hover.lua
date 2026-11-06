-- Stats du portrait au survol, quel que soit le cadre du joueur : accroches
-- sur les cadres connus (EllesmereUI, ElvUI…), cadres nés tard, repli par
-- sondage du cadre sous la souris, pas de double affichage, ancrage.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local saved = {
	GetMouseFoci = rawget(_G, "GetMouseFoci"),
	GetMouseFocus = rawget(_G, "GetMouseFocus"),
	Ellesmere = rawget(_G, "EllesmereUIUnitFrames_Player"),
	ElvUF = rawget(_G, "ElvUF_Player"),
	show = NS.ShowPortraitStats,
}
local H = { focus = nil, shows = 0 }
_G.GetMouseFoci = function() return { H.focus } end
-- le panneau compte ses affichages (double affichage = scintillement)
NS.ShowPortraitStats = function(self, ...)
	H.shows = H.shows + 1
	return saved.show(self, ...)
end

function H.Reset()
	ResetWorld()
	H.focus, H.shows = nil, 0
	NS.portraitHover, NS.portraitHoverSource, NS.portraitAnchor = nil, nil, nil
	if NS.portraitFrame then NS.portraitFrame:Hide() end
end
function H.Shown() return NS.portraitFrame ~= nil and NS.portraitFrame:IsShown() == true end
function H.AnchoredTo(frame)
	local point = NS.portraitFrame and NS.portraitFrame.lastPoint
	return point ~= nil and point.relTo == frame
end
-- cadre d'unité façon oUF : attribut sécurisé « unit »
function H.UnitFrame(name, unit, parent)
	local frame = CreateFrame("Button", name, parent)
	frame.attributes = { unit = unit }
	function frame:GetAttribute(key) return self.attributes[key] end
	frame:Show()   -- un cadre d'unité est à l'écran
	return frame
end

do
	Say("-- portrait : cadres d'interface connus")
	H.Reset()
	Check("[PORT] EllesmereUI et ElvUI dans la liste", (function()
		local found = {}
		for _, name in ipairs(NS.PORTRAIT_FRAMES) do found[name] = true end
		return found.PlayerFrame and found.EllesmereUIUnitFrames_Player and found.ElvUF_Player and found.SUFUnitplayer
	end)())
	local ellesmere = H.UnitFrame("EllesmereUIUnitFrames_Player", "player")
	_G.EllesmereUIUnitFrames_Player = ellesmere
	Check("[PORT] cadre EllesmereUI accroché", NS:HookPortraitFrames() >= 1 and ellesmere.hooks
		and type(ellesmere.hooks.OnEnter) == "function" and type(ellesmere.hooks.OnLeave) == "function")
	Check("[PORT] pas d'accroche en double", NS:HookPortraitFrames() == 0)
	ellesmere.hooks.OnEnter(ellesmere)
	Check("[PORT] survol EllesmereUI : panneau affiché", H.Shown())
	Check("[PORT] panneau posé au-dessus du cadre survolé", H.AnchoredTo(ellesmere))
	ellesmere.hooks.OnLeave(ellesmere)
	Check("[PORT] sortie : panneau masqué", not H.Shown())

	-- position choisie par le joueur : elle prime sur le cadre survolé
	NS:DB().portraitManual = true
	NS:DB().portraitPoint = { point = "CENTER", x = 10, y = 20 }
	ellesmere.hooks.OnEnter(ellesmere)
	Check("[PORT] position manuelle respectée", H.AnchoredTo(UIParent))
	ellesmere.hooks.OnLeave(ellesmere)
	NS:DB().portraitManual = false
end

do
	Say("-- portrait : cadre créé après l'entrée en jeu")
	H.Reset()
	_G.ElvUF_Player = nil
	NS.portraitRetried = nil
	Mock.world.timers = {}
	NS:InitPlayerFrameHooks()
	Check("[PORT] trois nouvelles tentatives programmées", #(Mock.world.timers or {}) == #NS.PORTRAIT_RETRY,
		#(Mock.world.timers or {}))
	local elv = H.UnitFrame("ElvUF_Player", "player")
	_G.ElvUF_Player = elv
	Mock:RunTimers()
	Check("[PORT] ElvUI accroché à retardement", elv.hooks and type(elv.hooks.OnEnter) == "function")
	Check("[PORT] sondeur créé une seule fois", NS.portraitPoller ~= nil and (function()
		local poller = NS.portraitPoller
		NS:InitPlayerFrameHooks()
		return NS.portraitPoller == poller
	end)())
end

do
	Say("-- portrait : repli générique (cadre sous la souris)")
	H.Reset()
	-- un cadre d'addon inconnu : l'unité est sur le parent du bouton survolé
	local custom = H.UnitFrame("MonAddonCadreJoueur", "player")
	local portrait = CreateFrame("Button", nil, custom)
	H.focus = portrait
	Check("[PORT] cadre du joueur trouvé via le parent", NS:PortraitHoveredFrame() == custom)
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] sondage : panneau affiché", H.Shown() and NS.portraitHoverSource == "poll")
	Check("[PORT] sondage : posé au-dessus du cadre trouvé", H.AnchoredTo(custom))
	local shows = H.shows
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] sondage : pas de réaffichage à chaque passe", H.shows == shows, H.shows - shows)
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] sondage : masqué en partant", not H.Shown() and NS.portraitHover == nil)

	-- une cible n'est pas le joueur
	H.focus = H.UnitFrame("MonAddonCadreCible", "target")
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] cadre de la cible : rien", not H.Shown())

	-- champ .unit (cadres sans attribut sécurisé)
	local plain = CreateFrame("Frame", "CadreSimple")
	plain.unit = "player"
	H.focus = plain
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] champ .unit reconnu", H.Shown())
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)

	-- trop loin dans la hiérarchie (plus de trois parents) : ignoré
	local deep = CreateFrame("Frame", nil, CreateFrame("Frame", nil, CreateFrame("Frame", nil,
		CreateFrame("Frame", nil, H.UnitFrame("Profond", "player")))))
	H.focus = deep
	Check("[PORT] au-delà de trois parents : ignoré", NS:PortraitHoveredFrame() == nil)

	-- GetMouseFocus (ancien client) en repli
	_G.GetMouseFoci = nil
	_G.GetMouseFocus = function() return custom end
	Check("[PORT] GetMouseFocus en repli", NS:PortraitHoveredFrame() == custom)
	_G.GetMouseFocus = saved.GetMouseFocus
	_G.GetMouseFoci = function() return { H.focus } end
end

do
	Say("-- portrait : accroche et sondage ensemble")
	H.Reset()
	local ellesmere = _G.EllesmereUIUnitFrames_Player
	ellesmere.hooks.OnEnter(ellesmere)
	H.focus = ellesmere
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] un seul affichage quand les deux voies le voient", H.shows == 1, H.shows)
	-- la souris est partie, l'OnLeave n'est pas encore arrivé : le sondage
	-- ne masque pas ce que l'accroche a montré
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] le sondage ne masque pas l'affichage de l'accroche", H.Shown())
	ellesmere.hooks.OnLeave(ellesmere)
	Check("[PORT] l'accroche le masque", not H.Shown())
	-- après un masquage par commande, un nouveau survol réaffiche
	ellesmere.hooks.OnEnter(ellesmere)
	NS:HidePortraitStats()
	ellesmere.hooks.OnEnter(ellesmere)
	Check("[PORT] réaffiché après un masquage externe", H.Shown())
	ellesmere.hooks.OnLeave(ellesmere)

	-- module coupé : le sondage ne fait rien
	NS:DB().showPortraitStats = false
	H.focus = ellesmere
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] module coupé : pas de sondage", not H.Shown() and NS.portraitHover == nil)
	NS:DB().showPortraitStats = true
	H.focus = nil
end

do
	Say("-- portrait : ElvUI")
	H.Reset()
	local elv = H.UnitFrame("ElvUF_Player", "player")
	_G.ElvUF_Player = elv
	NS:HookPortraitFrames()
	-- ElvUI remet ses scripts en reconfigurant ses cadres (SetScript efface
	-- les accroches) : le sondage prend le relais
	elv.hooks = nil
	local health = CreateFrame("StatusBar", nil, elv)
	H.focus = health
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] ElvUI, accroche perdue : le sondage affiche", H.Shown() and NS.portraitHover == elv)
	Check("[PORT] ElvUI : panneau posé au-dessus de son cadre", H.AnchoredTo(elv))
	H.focus = nil
	Mock:Advance(NS.PORTRAIT_POLL)
	Check("[PORT] ElvUI : masqué en partant", not H.Shown())
	-- ElvUI masque le PlayerFrame de Blizzard : on ne s'y ancre pas
	local blizzard = rawget(_G, "PlayerFrame")
	local wasShown = blizzard and blizzard:IsShown()
	if blizzard then blizzard:Hide() end
	-- un seul jeu de cadres à l'écran : celui d'ElvUI
	local ellesmere = rawget(_G, "EllesmereUIUnitFrames_Player")
	local ellesmereShown = ellesmere and ellesmere:IsShown()
	if ellesmere then ellesmere:Hide() end
	NS.portraitAnchor = nil
	Check("[PORT] ElvUI : ancre par défaut = son cadre, pas le PlayerFrame masqué", NS:PortraitAnchorFrame() == elv,
		tostring(NS:PortraitAnchorFrame() and NS:PortraitAnchorFrame():GetName()))
	if blizzard and wasShown then blizzard:Show() end
	if ellesmere and ellesmereShown then ellesmere:Show() end
	_G.ElvUF_Player = saved.ElvUF
end

_G.GetMouseFoci = saved.GetMouseFoci
_G.GetMouseFocus = saved.GetMouseFocus
_G.EllesmereUIUnitFrames_Player = saved.Ellesmere
_G.ElvUF_Player = saved.ElvUF
NS.ShowPortraitStats = saved.show
NS.portraitHover, NS.portraitHoverSource, NS.portraitAnchor = nil, nil, nil
