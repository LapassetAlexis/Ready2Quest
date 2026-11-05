-- Notice.lua -- les rapports s'annoncent par une icône, sans s'ouvrir seuls
--
-- Une fenêtre qui s'ouvre au moment où l'on part était trop intrusive. Les
-- trois rapports automatiques (Avant le départ, Retour d'expédition, Avant le
-- donjon) s'annoncent désormais par une icône du jeu : le « ! » des quêtes à
-- prendre au départ et devant un donjon, le « ? » des quêtes à rendre au
-- retour. Elle pulse NOTICE_PULSE secondes dans la couleur du résultat, reste
-- ensuite visible et atténuée NOTICE_LINGER secondes, puis disparaît.
-- Clic : le rapport s'ouvre. Clic droit : on l'ignore. En combat, elle attend
-- la fin du combat. La ligne courte dans le chat reste.
--
-- Couleurs : départ = barème de la note (Theme.ScoreColor : rouge, orange,
-- ambre, vert) ; retour = rouge si mort, orange s'il faut réparer ou
-- racheter, bleu sinon ; donjon = rouge si trop bas niveau, orange si la
-- préparation a un manque, bleu sinon.
--
-- Réglage : db.reportIcon (Général › Affichage). Coupé, les rapports s'ouvrent
-- comme avant. Un check lancé à la main ouvre toujours la fenêtre.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local FR = {
	OPT_REPORT_ICON    = "Rapports annoncés par une icône",
	NOTICE_CLICK       = "Clic : ouvrir · clic droit : ignorer",
	NOTICE_DEPART      = "Avant le départ : %d/100 — %s",
	NOTICE_RETURN      = "Retour d'expédition",
	NOTICE_DUNGEON     = "Avant le donjon : %s",
	NOTICE_DEATHS      = "%d mort(s) pendant la sortie",
	NOTICE_RESTOCK     = "À racheter : %s",
	NOTICE_REPAIR      = "Équipement à réparer (%d %%)",
	NOTICE_QUIET       = "Rien à signaler",
	NOTICE_DUNGEON_LOW = "Niveau trop bas pour ce donjon",
	NOTICE_DUNGEON_PREP = "Préparation à revoir",
	NOTICE_CHAT_DUNGEON = "Avant le donjon : %s. Clique sur le « ! » pour sa fiche.",
	NOTICE_PLACEHOLDER = "Rapport",
}
local EN = {
	OPT_REPORT_ICON    = "Reports announced by an icon",
	NOTICE_CLICK       = "Click: open · right-click: dismiss",
	NOTICE_DEPART      = "Before leaving: %d/100 — %s",
	NOTICE_RETURN      = "Expedition report",
	NOTICE_DUNGEON     = "Before the dungeon: %s",
	NOTICE_DEATHS      = "%d death(s) during the trip",
	NOTICE_RESTOCK     = "To restock: %s",
	NOTICE_REPAIR      = "Gear needs repair (%d %%)",
	NOTICE_QUIET       = "Nothing to report",
	NOTICE_DUNGEON_LOW = "Level too low for this dungeon",
	NOTICE_DUNGEON_PREP = "Readiness to check",
	NOTICE_CHAT_DUNGEON = "Before the dungeon: %s. Click the \"!\" for its sheet.",
	NOTICE_PLACEHOLDER = "Report",
}
ns.RegisterStrings(FR, EN)
ns.NOTICE_STRINGS = { fr = FR, en = EN }   -- exposé aux tests (parité fr/en)

ns.RegisterDefaults({
	reportIcon  = true,
	noticePoint = { point = "TOP", x = 0, y = -150 },
})

-- Réglage dans Général › Affichage, sous « Fenêtre ou chat »
for _, def in ipairs(ns.OPTION_PAGES or {}) do
	if def.id == "general" and type(def.rows) == "table" then
		local at = #def.rows + 1
		for index, row in ipairs(def.rows) do if row.key == "showWindow" then at = index + 1 end end
		table.insert(def.rows, at, { key = "reportIcon", label = "OPT_REPORT_ICON", kind = "bool" })
	end
end

-- Icônes du jeu (présentes sur Era et Forever) : « ! » quête à prendre, « ? » quête à rendre
ns.NOTICE_ICONS = {
	depart  = "Interface\\GossipFrame\\AvailableQuestIcon",
	dungeon = "Interface\\GossipFrame\\AvailableQuestIcon",
	["return"] = "Interface\\GossipFrame\\ActiveQuestIcon",
}
ns.NOTICE_GLOW = "Interface\\Buttons\\UI-ActionButton-Border"
ns.NOTICE_PULSE = 8        -- secondes de pulsation
ns.NOTICE_LINGER = 60      -- puis visible, atténuée, avant de disparaître
local SIZE = 40            -- la tuile ; l'icône du jeu tient dedans, à 5 px du bord
local ICON_INSET = 5

local function InCombat()
	if type(InCombatLockdown) == "function" and InCombatLockdown() then return true end
	if type(UnitAffectingCombat) == "function" then
		local ok, res = pcall(UnitAffectingCombat, "player")
		return ok and res and true or false
	end
	return false
end

-- Les rapports passent-ils par l'icône ?
function ns:WantsNotice()
	return self:DB().reportIcon ~= false and Theme and Theme.CreateDialog ~= nil
end

-- ---------------------------------------------------------------------------
-- Couleur et texte de chaque rapport
-- ---------------------------------------------------------------------------
function ns:NoticeDepart(score, verdict)
	return {
		kind = "depart",
		color = Theme.ScoreColor((score or 0) / 100),
		lines = { self:F("NOTICE_DEPART", score or 0, tostring(verdict or "")) },
	}
end

function ns:NoticeReturn(report)
	local db, lines, color = self:DB(), { L.NOTICE_RETURN }, Theme.BLUE
	local repair = report.durability and report.durability < (db.durabilityMinPct or 25)
	if (report.deaths or 0) > 0 then
		color = Theme.RED
		lines[#lines + 1] = self:F("NOTICE_DEATHS", report.deaths)
	end
	if repair then
		if color ~= Theme.RED then color = Theme.ORANGE_DEEP end
		lines[#lines + 1] = self:F("NOTICE_REPAIR", math.floor(report.durability + 0.5))
	end
	if report.restock and #report.restock > 0 then
		if color ~= Theme.RED then color = Theme.ORANGE_DEEP end
		lines[#lines + 1] = self:F("NOTICE_RESTOCK", table.concat(report.restock, ", "))
	end
	if #lines == 1 then lines[2] = L.NOTICE_QUIET end
	return { kind = "return", color = color, lines = lines }
end

function ns:NoticeDungeon(sheet)
	local lines, color = { self:F("NOTICE_DUNGEON", tostring(sheet.name)) }, Theme.BLUE
	if sheet.verdict == "low" then
		color = Theme.RED
		lines[#lines + 1] = L.NOTICE_DUNGEON_LOW
	else
		for _, line in ipairs(sheet.readiness or {}) do
			if not line.ok then
				color = Theme.ORANGE_DEEP
				lines[#lines + 1] = L.NOTICE_DUNGEON_PREP
				break
			end
		end
	end
	return { kind = "dungeon", color = color, lines = lines }
end

-- ---------------------------------------------------------------------------
-- L'icône
-- ---------------------------------------------------------------------------
function ns:EnsureNotice()
	if self.noticeFrame then return self.noticeFrame end
	local ok, frame = pcall(CreateFrame, "Button", "Ready2QuestNotice", UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(SIZE, SIZE)
	frame:SetFrameStrata("HIGH")
	if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
	if frame.SetMovable then frame:SetMovable(true) end
	if frame.RegisterForClicks then frame:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end

	-- halo de la couleur du résultat, derrière l'icône
	frame.glow = frame:CreateTexture(nil, "BACKGROUND")
	frame.glow:SetTexture(ns.NOTICE_GLOW)
	if frame.glow.SetBlendMode then frame.glow:SetBlendMode("ADD") end
	frame.glow:SetSize(SIZE * 1.9, SIZE * 1.9)
	frame.glow:SetPoint("CENTER", frame, "CENTER", 0, 0)

	-- tuile (docs/UI.md, bandeaux) : fond WINDOW, filet EDGE, barre basse à la
	-- couleur du rapport
	frame.tile = Theme.Solid(frame, "BORDER", Theme.WINDOW, 0.94)
	frame.tile:SetAllPoints()
	frame.border = Theme.Border(frame, Theme.EDGE, 1, "ARTWORK")
	frame.accent = Theme.Solid(frame, "OVERLAY", Theme.GOLD, 1)
	frame.accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	frame.accent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	frame.accent:SetHeight(2)

	-- icône du jeu, désaturée puis teintée : un jaune teinté donnerait un vert sale
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", ICON_INSET, -ICON_INSET)
	frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)

	-- repère du mode édition (même habillage que le résumé et le portrait)
	frame.moveGlow = Theme.Solid and Theme.Solid(frame, "OVERLAY", Theme.GOLD, 0.25) or nil
	if frame.moveGlow then frame.moveGlow:SetAllPoints(); frame.moveGlow:Hide() end

	frame:SetScript("OnClick", function(_, button)
		local notice = ns.notice
		ns:HideNotice()
		if button ~= "RightButton" and notice and notice.onClick then notice.onClick() end
	end)
	frame:SetScript("OnDragStart", function(f) if ns.editMode and f.StartMoving then f:StartMoving() end end)
	frame:SetScript("OnEnter", function(f)
		local notice = ns.notice
		if not notice or type(GameTooltip) ~= "table" or not GameTooltip.SetOwner then return end
		GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
		for index, line in ipairs(notice.lines or {}) do
			Theme.TooltipLine(GameTooltip, line, index == 1 and (notice.color or Theme.GOLD) or Theme.TEXT)
		end
		Theme.TooltipHint(GameTooltip, L.NOTICE_CLICK)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		if type(GameTooltip) == "table" and GameTooltip.Hide then GameTooltip:Hide() end
	end)
	frame:SetScript("OnUpdate", function() ns:UpdateNotice(ns.Now()) end)

	ns:RestorePoint(frame, "noticePoint", { point = "TOP", x = 0, y = -150 })
	frame:Hide()
	self.noticeFrame = frame
	return frame
end

-- Pose l'icône (une seule à la fois : la plus récente remplace l'autre)
-- notice = { kind, color, lines, onClick }
function ns:ShowNotice(notice)
	if not notice then return nil end
	self.notice = notice
	if InCombat() then
		self.noticePending = true
		return nil
	end
	return self:DisplayNotice()
end

function ns:DisplayNotice()
	local notice, frame = self.notice, self:EnsureNotice()
	if not notice or not frame then return nil end
	self.noticePending = nil
	local color = notice.color or Theme.GOLD
	frame.icon:SetTexture(ns.NOTICE_ICONS[notice.kind] or ns.NOTICE_ICONS.depart)
	if frame.icon.SetDesaturated then frame.icon:SetDesaturated(true) end
	frame.icon:SetVertexColor(color[1], color[2], color[3], 1)
	frame.glow:SetVertexColor(color[1], color[2], color[3], 1)
	frame.accent:SetVertexColor(color[1], color[2], color[3], 1)
	local now = ns.Now()
	notice.shownAt = now
	notice.pulseUntil = now + ns.NOTICE_PULSE
	notice.hideAt = notice.pulseUntil + ns.NOTICE_LINGER
	frame:SetAlpha(1)
	frame:Show()
	self:UpdateNotice(now)
	return frame
end

-- Pulsation (halo et icône), puis icône atténuée, puis disparition
function ns:UpdateNotice(now)
	local frame, notice = self.noticeFrame, self.notice
	if not frame or not notice or not notice.shownAt or self.editMode then return end
	if now >= notice.hideAt then
		self:HideNotice()
		return
	end
	if now < notice.pulseUntil then
		local wave = 0.5 + 0.5 * math.sin((now - notice.shownAt) * math.pi * 2 / 1.2)
		frame.glow:SetAlpha(0.35 + 0.65 * wave)
		frame.icon:SetAlpha(0.75 + 0.25 * wave)
		frame:SetAlpha(1)
	else
		frame.glow:SetAlpha(0.25)
		frame.icon:SetAlpha(1)
		frame:SetAlpha(0.6)
	end
end

function ns:HideNotice()
	self.notice, self.noticePending = nil, nil
	if self.noticeFrame and not self.editMode then self.noticeFrame:Hide() end
	if type(GameTooltip) == "table" and GameTooltip.Hide and GameTooltip.GetOwner
		and self.noticeFrame and GameTooltip:GetOwner() == self.noticeFrame then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------------------
-- Fin de combat : l'icône en attente s'affiche
-- ---------------------------------------------------------------------------
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
	if ns.noticePending and ns.notice then ns:DisplayNotice() end
end)
ns.noticeEventFrame = events

-- ---------------------------------------------------------------------------
-- Mode « Déplacer les cadres » : l'icône s'affiche pour être placée
-- ---------------------------------------------------------------------------
local StartEdit, StopEdit = ns.StartEditMode, ns.StopEditMode
if StartEdit and StopEdit then
	function ns:StartEditMode()
		StartEdit(self)
		local frame = self:EnsureNotice()
		if frame then
			if not self.notice then
				frame.icon:SetTexture(ns.NOTICE_ICONS.depart)
				frame.icon:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
				frame.accent:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
				frame.glow:SetAlpha(0.5)
			end
			frame:SetAlpha(1)
			frame:Show()
			if frame.EnableMouse then frame:EnableMouse(true) end
			if frame.moveGlow then frame.moveGlow:Show() end
		end
	end
	function ns:StopEditMode()
		StopEdit(self)
		local frame = self.noticeFrame
		if frame then
			if frame.moveGlow then frame.moveGlow:Hide() end
			if not self.notice then frame:Hide() end
		end
	end
end

if ns.Mark then ns.Mark("Notice") end
