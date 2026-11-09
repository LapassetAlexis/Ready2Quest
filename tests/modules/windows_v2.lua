-- tests/modules/windows_v2.lua -- refonte 2026-11, lot 3 : briques des fenêtres
-- de modules (Theme.CreateDialog, CreateListRow, CreateToast, SkinToast,
-- CreateIconButton, SetStatus, boutons à la largeur du libellé, infobulles)
-- et chaque fenêtre de Ready2Quest construite sans chevauchement (géométrie
-- absolue de tests/snapshot.lua, scènes de l'aperçu hors-jeu).
local Check, Say, NS, Mock = T.Check, T.Say, T.NS, T.Mock
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 0.01 end
local function SameColor(c, token) return c and Near(c[1], token[1]) and Near(c[2], token[2]) and Near(c[3], token[3]) end

-- 1. Fenêtre de module ------------------------------------------------------
do
	Say("-- fenêtres v2 : briques")
	local dialog = Theme.CreateDialog(UIParent, 420, 300, { name = "TestDialogV2", title = "Titre", subtitle = "Sous-titre" })
	Check("[WIN2] fenêtre de module : chrome, en-tête compact, pied", dialog.chrome == "dialog" and dialog.header.compact
		and dialog.footer ~= nil and dialog.footer.height == Theme.DIALOG_FOOTER)
	Check("[WIN2] en-tête : logo, titre F_TITLE, sous-titre F_BODY", dialog.logo ~= nil and dialog.title.text == "Titre"
		and dialog.title.fontObject == Theme.F_TITLE and dialog.subtitle.text == "Sous-titre"
		and dialog.subtitle.fontObject == Theme.F_BODY)
	Check("[WIN2] contenu sous l'en-tête", dialog.contentTop == -Theme.HEADER_COMPACT_HEIGHT - 1
		and dialog.innerWidth == 420 - 2 - 2 * Theme.DIALOG_PAD)
	Check("[WIN2] filet ambre lumineux dans l'en-tête", #dialog.header.rule.segments == 3)
	local escape = false
	for _, name in ipairs(UISpecialFrames) do if name == "TestDialogV2" then escape = true end end
	Check("[WIN2] Échap et [×]", escape and dialog.close ~= nil)
	local free = Theme.CreateDialog(UIParent, 300, 200, { footer = false, logo = false })
	Check("[WIN2] sans pied ni logo", free.footer == nil and free.logo == nil and free.header.textLeft == Theme.DIALOG_PAD)

	-- pied : principal à droite, secondaires à gauche, au centre
	local done = dialog:AddFooterButton("Terminé", nil, "accent")
	local close = dialog:AddFooterButton("Fermer", nil, "outline")
	local reset = dialog:AddFooterButton("Réinitialiser", nil, "outline", "left")
	local more = dialog:AddFooterButton("Encore", nil, nil, "left")
	Check("[WIN2] pied : premier bouton à droite, collé au bord", select(1, done:GetPoint()) == "RIGHT"
		and select(2, done:GetPoint()) == dialog.footer and select(4, done:GetPoint()) == -Theme.DIALOG_PAD)
	Check("[WIN2] pied : le suivant à sa gauche", select(2, close:GetPoint()) == done and select(3, close:GetPoint()) == "LEFT")
	Check("[WIN2] pied : secondaires de gauche à droite", select(1, reset:GetPoint()) == "LEFT"
		and select(4, reset:GetPoint()) == Theme.DIALOG_PAD and select(2, more:GetPoint()) == reset)
	Check("[WIN2] pied : boutons dans le pied, hauteur commune", done:GetParent() == dialog.footer
		and done:GetHeight() == Theme.DIALOG_BUTTON_HEIGHT)

	-- largeur au libellé
	local long = Theme.CreateButton(UIParent, nil, 24, "Terminer le déplacement des cadres", nil, "primary")
	Check("[WIN2] bouton « auto » : le libellé tient (16 de chaque côté)",
		long:GetWidth() >= long.text:GetStringWidth() + Theme.BUTTON_PAD, long:GetWidth())
	local short = Theme.CreateButton(UIParent, "auto", 24, "OK")
	Check("[WIN2] bouton « auto » : largeur minimale", short:GetWidth() == Theme.BUTTON_MIN, short:GetWidth())
	Check("[WIN2] largeur posée : respectée", Theme.CreateButton(UIParent, 90, 24, "Libellé très long à souhait"):GetWidth() == 90)

	-- en-tête compact et grand en-tête
	local big = Theme.CreatePageHeader(UIParent, 600)
	local small = Theme.CreatePageHeader(UIParent, 600, { compact = true })
	Check("[WIN2] grand en-tête inchangé (F_DISPLAY, 100, sans logo)", big.height == Theme.HEADER_HEIGHT
		and big.title.fontObject == Theme.F_DISPLAY and big.logo == nil and not big.compact)
	Check("[WIN2] en-tête compact : 64, titre F_TITLE à droite du logo", small.height == Theme.HEADER_COMPACT_HEIGHT
		and small.title.fontObject == Theme.F_TITLE and small.logo ~= nil and small.textLeft > 20 + 28)
end

-- 2. Lignes, statuts, bandeaux, boutons-icônes, infobulles -------------------
do
	local row1 = Theme.CreateListRow(UIParent, 300, nil, { status = true, detail = true })
	local row2 = Theme.CreateListRow(UIParent, 300, 30, { icon = 24 })
	row1:SetIndex(1); row2:SetIndex(2)
	Check("[WIN2] ligne : carte ROW, rang pair en ROW_ALT", SameColor(row1.bg.vertex, Theme.ROW)
		and SameColor(row2.bg.vertex, Theme.ROW_ALT) and row1.height == Theme.LIST_ROW_HEIGHT and row2.height == 30)
	row2:SetIndex(3)
	Check("[WIN2] ligne : rang impair repasse en ROW", SameColor(row2.bg.vertex, Theme.ROW))
	Check("[WIN2] ligne : losange, texte après lui, détail aligné à droite", row1.status ~= nil
		and row1.textLeft == 12 + 9 + 10 and row1.detail.justifyH == "RIGHT" and select(1, row1.detail:GetPoint()) == "RIGHT")
	Check("[WIN2] ligne : icône, texte après elle", row2.icon ~= nil and row2.textLeft == 6 + 24 + 10 and row2.status == nil)
	local hover = Theme.CreateListRow(UIParent, 300, nil, { kind = "Button" })
	hover.scripts.OnEnter(hover)
	Check("[WIN2] ligne cliquable : éclairée au survol", hover.hover:IsShown())

	local d = row1.status
	local states = { ok = { Theme.GREEN, true }, info = { Theme.BLUE, true }, warn = { Theme.ORANGE, false },
		bad = { Theme.RED, false }, off = { Theme.MUTED, true }, item = { Theme.GOLD, true } }
	local wrong = {}
	for state, spec in pairs(states) do
		Theme.SetStatus(d, state)
		local role = spec[2] and "diamondLine" or "diamond"
		if not (d.state == state and d.clientRole == role and SameColor(d.vertex, spec[1]) and d:IsShown()) then
			wrong[#wrong + 1] = state
		end
	end
	Check("[WIN2] statuts : forme et couleur (plein = à voir, trait = bon)", #wrong == 0, table.concat(wrong, ","))
	Theme.SetStatus(d, "none")
	Check("[WIN2] statut « none » : losange masqué", not d:IsShown() and d.state == "none")

	local toast = Theme.CreateToast(UIParent, 200, 30)
	Check("[WIN2] bandeau : fond WINDOW, filet EDGE, liseré ambre", toast.chrome == "toast"
		and SameColor(toast.bg.vertex, Theme.WINDOW) and SameColor(toast.border.top.vertex, Theme.EDGE)
		and SameColor(toast.accent.vertex, Theme.GOLD) and toast.accent.width == Theme.TOAST_ACCENT)
	Check("[WIN2] bandeau : souris coupée hors édition, contenu après le liseré", toast.mouseEnabled == false
		and toast.contentLeft > Theme.TOAST_ACCENT)
	toast:SetAccent(Theme.RED)
	Check("[WIN2] bandeau : liseré de statut", SameColor(toast.accent.vertex, Theme.RED))
	toast:SetAccent(false)
	Check("[WIN2] bandeau : sans liseré", not toast.accent:IsShown())
	local plate = CreateFrame("Frame", nil, UIParent)
	plate:SetSize(100, 10)
	Theme.SkinToast(plate, { outset = { 10, 4, 6, 30 } })
	Check("[WIN2] habillage : le fond déborde du cadre", plate.bg.points[1].x == -10 and plate.bg.points[1].y == 4
		and plate.bg.points[2].x == 6 and plate.bg.points[2].y == -30 and plate.border.top.points[1].relTo == plate.bg)

	local clicked = false
	local icon = Theme.CreateIconButton(UIParent, 22, Theme.REFRESH, function() clicked = true end, "Relancer")
	Check("[WIN2] bouton-icône : estompé au repos, filet EDGE", (icon.icon.alpha or 1) < 1 and SameColor(icon.border.top.vertex, Theme.EDGE))
	GameTooltip:ClearLines()
	icon.scripts.OnEnter(icon)
	Check("[WIN2] bouton-icône : plein et filet ambre au survol, infobulle", icon.icon.alpha == 1
		and SameColor(icon.border.top.vertex, Theme.GOLD) and GameTooltip.lines[1] == "Relancer")
	icon.scripts.OnLeave(icon)
	icon:Click()
	Check("[WIN2] bouton-icône : clic", clicked and (icon.icon.alpha or 1) < 1)

	GameTooltip:ClearLines()
	Theme.TooltipTitle(GameTooltip, "Titre")
	Theme.TooltipLine(GameTooltip, "Texte")
	Theme.TooltipHint(GameTooltip, "Aide", true)
	Theme.TooltipPair(GameTooltip, "Libellé", "Valeur")
	local s = GameTooltip.styled
	Check("[WIN2] infobulle : titre ambre, texte, aide pâle, paire", SameColor(s[1].color, Theme.GOLD)
		and SameColor(s[2].color, Theme.TEXT) and SameColor(s[3].color, Theme.MUTED_LIGHT) and s[3].wrap == true
		and s[4].right == "Valeur" and SameColor(s[4].rightColor, Theme.PARCHMENT))
end

-- 3. Chaque fenêtre : construite sans chevauchement -------------------------
-- Les scènes de l'aperçu posent des données d'exemple ; elles remplacent des
-- méthodes de NS (scans) et la taille d'UIParent : tout est rendu ensuite.
local function Scene(name)
	local saved, savedW, savedH = {}, UIParent.width, UIParent.height
	for key, value in pairs(NS) do saved[key] = value end
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = savedColor or Mock.CreateColor
	local ok, frame = pcall(Snap.scenes[name], T)
	_G.CreateColor = savedColor
	local restore = function()
		for key in pairs(NS) do if saved[key] == nil then NS[key] = nil end end
		for key, value in pairs(saved) do NS[key] = value end
		UIParent.width, UIParent.height = savedW, savedH
		for index = 1, 3 do _G["QuestInfoRewardsFrameQuestInfoItem" .. index] = nil end
	end
	if not ok then restore(); return nil, frame end
	return frame, restore
end

-- blocs, chevauchements, sorties du cadre : tests/snapshot.lua
local function Layout(root) return Snap.Layout(root) end

do
	Say("-- fenêtres v2 : chaque fenêtre, sans chevauchement")
	local scenes = { "r2q-check", "r2q-dungeon", "r2q-expedition", "r2q-death", "r2q-lootroom", "r2q-spellranks",
		"r2q-bagspace", "r2q-camp", "r2q-portrait", "r2q-gear-toast", "r2q-settings-canvas" }
	for _, name in ipairs(scenes) do
		local frame, restore = Scene(name)
		if not frame then
			Check("[WIN2] " .. name .. " : construite", false, restore)
		else
			local overlaps, outside, count = Layout(frame)
			Check("[WIN2] " .. name .. " : construite, du texte à lire", count >= (name == "r2q-camp" and 1 or 2), count)
			Check("[WIN2] " .. name .. " : aucun chevauchement", #overlaps == 0, table.concat(overlaps, " | "))
			Check("[WIN2] " .. name .. " : rien ne sort du cadre", #outside == 0, table.concat(outside, " | "))
			-- boutons du pied : dans le pied, libellé tenu
			if frame.footer then
				local bad = {}
				for _, side in pairs(frame.footerButtons or {}) do
					for _, button in ipairs(side) do
						if button:GetWidth() < button.text:GetStringWidth() + 16 then bad[#bad + 1] = button:GetText() end
					end
				end
				Check("[WIN2] " .. name .. " : libellés des boutons du pied tenus", #bad == 0, table.concat(bad, ","))
			end
			restore()
		end
	end

	-- fenêtres de module : en-tête compact et pied partout
	local dialogs = {}
	for _, name in ipairs({ "r2q-check", "r2q-dungeon", "r2q-expedition", "r2q-death", "r2q-lootroom", "r2q-spellranks" }) do
		local frame, restore = Scene(name)
		if frame then
			if not (frame.chrome == "dialog" and frame.header.compact and frame.footer and frame.title.text ~= "") then
				dialogs[#dialogs + 1] = name
			end
			restore()
		end
	end
	Check("[WIN2] six fenêtres de module : en-tête compact titré et pied", #dialogs == 0, table.concat(dialogs, ","))

	-- les listes suivent leur nombre de lignes : la dernière carte au-dessus du pied
	for _, spec in ipairs({ { "r2q-lootroom", "lootRoomFrame" }, { "r2q-spellranks", "spellRanksFrame" } }) do
		local frame, restore = Scene(spec[1])
		if frame then
			local last
			for _, row in ipairs(frame.rows) do if row:IsShown() then last = row end end
			local _, _, _, _, y = last:GetPoint()
			local room = frame:GetHeight() - Theme.DIALOG_FOOTER - (-y + last:GetHeight())
			Check("[WIN2] " .. spec[1] .. " : hauteur suit la liste (pas de cartes vides)", room >= 8 and room <= 20, room)
			restore()
		end
	end

	-- rangées alternées dans les listes
	local frame, restore = Scene("r2q-check")
	if frame then
		Check("[WIN2] check : rangées alternées", SameColor(frame.rows[1].bg.vertex, Theme.ROW)
			and SameColor(frame.rows[2].bg.vertex, Theme.ROW_ALT))
		Check("[WIN2] check : le tampon tient son verdict", frame.stamp:GetWidth() >= frame.verdict:GetStringWidth() + 16)
		restore()
	end
end
