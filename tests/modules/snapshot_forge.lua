-- Aperçu hors-jeu (tests/snapshot.lua) et thème forgé (socle 3.2) : découpe
-- et miroirs des textures (SetTexCoord), niveau des cadres comme en jeu, thème
-- d'une scène (« sobre:<scène> »), habillage forgé rendu au-dessus des enfants
-- et sans rien couper (ombre, médaillon), scènes « forge-bricks » et
-- « forge-dialog-toast ». La teinte qui multiplie la texture est posée par
-- tests/snapshot.py (vérifiée au rendu, pas ici).
local Check, Say, NS, QNS, Mock, ResetWorld = T.Check, T.Say, T.NS, T.QNS, T.Mock, T.ResetWorld
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()
local Theme = NS.Theme
local SKIN0 = { NS.Theme.skin, QNS.Theme.skin }

local function Count(text, pattern)
	local n = 0
	for _ in text:gmatch(pattern) do n = n + 1 end
	return n
end

-- une scène jouée comme Snap.RunScene (dégradés de l'API récente)
local function Play(name)
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = Mock.CreateColor
	local ok, frame = pcall(Snap.scenes[name], T)
	_G.CreateColor = savedColor
	return ok, frame
end

do
	Say("-- aperçu : découpe et miroirs des textures")
	local host = CreateFrame("Frame", nil, UIParent)
	local tex = host:CreateTexture(nil, "ARTWORK")
	Check("[SNAPF] texture entière : pas de découpe", Snap.TexCoord(tex) == nil)
	tex:SetTexCoord(1, 0, 0, 1)
	local c = Snap.TexCoord(tex)
	Check("[SNAPF] gauche > droite : découpe remise dans l'ordre, miroir horizontal seul",
		c[1] == 0 and c[2] == 1 and c[3] == 0 and c[4] == 1 and c.flipX and not c.flipY)
	tex:SetTexCoord(0.75, 0.25, 1, 0.5)
	c = Snap.TexCoord(tex)
	Check("[SNAPF] miroir dans les deux sens : les deux drapeaux, la découpe gardée",
		c[1] == 0.25 and c[2] == 0.75 and c[3] == 0.5 and c[4] == 1 and c.flipX and c.flipY)
	tex:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	c = Snap.TexCoord(tex)
	Check("[SNAPF] forme à 8 nombres (coins) : lue comme gauche, droite, haut, bas",
		c[1] == 0 and c[2] == 1 and c[3] == 0 and c[4] == 1 and not c.flipX and not c.flipY)
end

do
	Say("-- aperçu : niveau des cadres comme en jeu")
	local a = CreateFrame("Frame", nil, UIParent)
	local b = CreateFrame("Frame", nil, a)
	local c = CreateFrame("Frame", nil, b)
	Check("[SNAPF] niveau non posé : celui du parent + 1, depuis UIParent", Snap.LiveLevel(a) == 1
		and Snap.LiveLevel(b) == 2 and Snap.LiveLevel(c) == 3)
	b:SetFrameLevel(40)
	Check("[SNAPF] niveau posé (SetFrameLevel) : gardé, ses enfants le suivent", Snap.LiveLevel(b) == 40
		and Snap.LiveLevel(c) == 41)
end

do
	Say("-- aperçu : thème d'une scène")
	local skin, name = Snap.SplitSkin("sobre:r2q-options")
	local skin2, name2 = Snap.SplitSkin("r2q-options")
	local skin3, name3 = Snap.SplitSkin("azeroth:bricks")
	Check("[SNAPF] « sobre:<scène> » : Sobre ; sans préfixe : Azeroth (le thème par défaut)",
		skin == "sobre" and name == "r2q-options" and skin2 == "azeroth" and name2 == "r2q-options"
		and skin3 == "azeroth" and name3 == "bricks" and Theme.SKIN_DEFAULT == "azeroth")
	ResetWorld()
	local restore = Snap.ForceSkin("sobre", T)
	local forced = NS.Theme.skin == "sobre" and QNS.Theme.skin == "sobre"
	-- un ADDON_LOADED rejoué ou un choix de style reposerait la sauvegarde : rien n'y fait
	NS.Theme.ApplySkin(NS:UISkinChoice())
	QNS.Theme.ApplySkin("azeroth")
	local held = NS.Theme.skin == "sobre" and QNS.Theme.skin == "sobre" and NS:UISkinChoice() == "sobre"
		and QNS:UIStyleChoice() == "sobre"
	restore()
	NS.Theme.ApplySkin(NS:UISkinChoice())
	Check("[SNAPF] Sobre forcé dans les deux addons le temps de la scène, puis tout revient",
		forced and held and NS:UISkinChoice() == "azeroth" and NS.Theme.skin == "azeroth"
		and rawget(NS.Theme, "ApplySkin") ~= nil, NS.Theme.skin)
	-- un socle chargé pendant la scène (T.LoadModules : celui de QuestCompanion
	-- en aperçu) : pris au vol à son ADDON_LOADED
	local late = {}
	local fakeT = { NS = NS, QNS = late, Mock = Mock }
	local fire0 = Mock.Fire
	local undo = Snap.ForceSkin("sobre", fakeT)
	late.Theme = { ApplySkin = function(id) late.skin = id; return id end }
	Mock:Fire("ADDON_LOADED", "SnapshotForgeAucun")
	late.Theme.ApplySkin("azeroth")
	local caught = late.skin == "sobre" and late:UISkinChoice() == "sobre"
	undo()
	NS.Theme.ApplySkin(NS:UISkinChoice())
	Check("[SNAPF] socle chargé en cours de scène : tenu dès son ADDON_LOADED ; ensuite Mock:Fire rendu",
		caught and Mock.Fire == fire0 and NS.Theme.skin == "azeroth", late.skin)
end

do
	Say("-- aperçu : l'habillage forgé d'une fenêtre")
	ResetWorld()
	NS.Theme.ApplySkin("azeroth")
	local ok, frame = Play("forge-dialog-toast")
	local html = ok and Snap.Render(frame, { title = "test" }) or ""
	local dialog = ok and frame.mockChildren[1]
	local chrome = dialog and dialog.skinChrome
	Check("[SNAPF] « forge-dialog-toast » : fenêtre et bandeau habillés en Azeroth, médaillon sur la fenêtre seule",
		ok and chrome ~= nil and chrome.emblem ~= nil and frame.mockChildren[2].skinDressed == true
		and frame.mockChildren[2].skinChrome.emblem == nil, ok and "" or frame)
	-- les coins : un sans miroir, un en miroir horizontal, un vertical, un des deux
	local corners = {}
	for _, tex in ipairs(chrome and chrome.corners or {}) do
		local c = Snap.TexCoord(tex)
		corners[#corners + 1] = (c.flipX and "x" or "-") .. (c.flipY and "y" or "-")
	end
	Check("[SNAPF] quatre coins : haut gauche tel quel, les autres retournés (miroirs lus par l'aperçu)",
		table.concat(corners, " ") == "-- x- -y xy", table.concat(corners, " "))
	Check("[SNAPF] rendu : les miroirs passent en transform (deux horizontaux, deux verticaux, coins du bandeau à part)",
		Count(html, "scaleX%(%-1%)") >= 2 and Count(html, "scaleY%(%-1%)") >= 2)
	-- le cadre du dessus (niveau + 30) passe après le contenu : le titre est dessiné avant les coins
	local titleAt = html:find("Avant le donjon", 1, true)
	local cornerAt = html:find("coin", 1, true)
	Check("[SNAPF] ordre de dessin : cadre d'orfèvre et coins au-dessus du contenu de la fenêtre",
		titleAt ~= nil and cornerAt ~= nil and cornerAt > titleAt)
	-- rien ne déborde de la scène : ombre (20 px) et médaillon (au-delà du coin) compris
	local rect = Snap.Rect(dialog, { memo = {}, root = frame })
	local emblem = chrome and Snap.Rect(chrome.emblem, { memo = {}, root = frame })
	Check("[SNAPF] médaillon et ombre hors de la fenêtre, et la scène leur laisse la place (aucune position négative)",
		rect and emblem and emblem.left < rect.left and emblem.top < rect.top
		and html:find("left:%-") == nil and html:find("top:%-") == nil)
	-- nos textures partent avec leur fichier et leur teinte (snapshot.py les incruste)
	Check("[SNAPF] textures de l'addon : ombre et cadre transmis à snapshot.py avec leur teinte",
		html:find('data%-src="[^"]*ombre" data%-tint="rgba%(') ~= nil
		and html:find('data%-src="[^"]*cadre" data%-tint="rgba%(') ~= nil)
	frame:Hide()
end

do
	Say("-- aperçu : le tableau des matières")
	ResetWorld()
	NS.Theme.ApplySkin("azeroth")
	local ok, win = Play("forge-bricks")
	local html = ok and Snap.Render(win, { title = "test" }) or ""
	local missing = {}
	for key, spec in pairs(Theme.ART) do
		local base = tostring(spec.file):match("([^\\]+)$")
		if not html:find(base, 1, true) then missing[#missing + 1] = key end
	end
	Check("[SNAPF] « forge-bricks » : chaque matière de Theme.ART dessinée, fenêtre habillée",
		ok and #missing == 0 and win.skinDressed == true, ok and table.concat(missing, ", ") or win)
	Check("[SNAPF] « forge-bricks » : plaques teintées (couleur de sommet transmise) et lueur additive",
		html:find('plaque" data%-tint="rgba%(255,214,143') ~= nil and html:find("plus%-lighter") ~= nil)
	win:Hide()
	ResetWorld()
	local restore = Snap.ForceSkin("sobre", T)
	local ok2, win2 = Play("forge-bricks")
	restore()
	Check("[SNAPF] « sobre:forge-bricks » : mêmes matières, la fenêtre sans habillage forgé",
		ok2 and win2.skinDressed == false, ok2 and "" or win2)
	if ok2 then win2:Hide() end
end

NS.Theme.ApplySkin(SKIN0[1]); QNS.Theme.ApplySkin(SKIN0[2])
