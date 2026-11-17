-- CaptureNetMove.lua -- Le filet se déplace seul (QuestCompanion 3.1.2)
--
-- Retour joueur : on veut placer le filet ailleurs que collé au portrait du
-- compagnon. Même règle que pour déplacer le compagnon (réglage « Déplacer le
-- compagnon » : Alt + glisser par défaut, glisser libre, ou verrouillé) : le
-- filet glissé se détache et garde sa place (db.captureNetPoint, par rapport
-- à l'écran), compagnon déplacé ou non. « Rattacher le filet au compagnon »
-- (réglages du compagnon, ou /qc filet rattacher) le remet à côté du
-- portrait. Un glisser ne lance pas le filet. Rien de protégé : le filet est
-- un cadre de l'addon.
local ADDON, ns = ...
if ns.blocked or not ns.CapturePlaceNet then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	CAPTURE_NET_MOVE_alt   = "Alt + glisser : déplacer le filet.",
	CAPTURE_NET_MOVE_free  = "Glisser : déplacer le filet.",
	CAPTURE_NET_ATTACH     = "Rattacher le filet au compagnon",
	CAPTURE_NET_ATTACH_DESC = "Le filet déplacé revient à côté du portrait du compagnon.",
	CAPTURE_NET_ATTACHED   = "Filet rattaché au compagnon.",
	CAPTURE_NET_ATTACH_BTN = "Rattacher",
}
local EN = {
	CAPTURE_NET_MOVE_alt   = "Alt + drag: move the net.",
	CAPTURE_NET_MOVE_free  = "Drag: move the net.",
	CAPTURE_NET_ATTACH     = "Attach the net to the companion",
	CAPTURE_NET_ATTACH_DESC = "A moved net goes back next to the companion's portrait.",
	CAPTURE_NET_ATTACHED   = "Net attached to the companion.",
	CAPTURE_NET_ATTACH_BTN = "Attach",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_NET_MOVE_STRINGS = { fr = FR, en = EN } end

ns.CAPTURE_NET_CLICK_AFTER_DRAG = 0.2   -- s : un relâcher juste après un glisser n'est pas un clic

local function Clock() return (ns.Now and ns.Now()) or 0 end

-- La place enregistrée (point d'écran) ou nil : collé au compagnon
function ns:CaptureNetPoint()
	local saved = self:DB().captureNetPoint
	if type(saved) == "table" and saved.point and tonumber(saved.x) and tonumber(saved.y) then return saved end
	return nil
end

function ns:CaptureNetAttach()
	self:DB().captureNetPoint = nil
	if self.captureNetButton then self.captureNetButton.moved = nil; self:CapturePlaceNet() end
	if self.captureExpressFeed and self.CaptureExpressPlace then pcall(self.CaptureExpressPlace, self) end
	if self.Print then self:Print(L.CAPTURE_NET_ATTACHED) end
	return true
end

-- Placement : la place enregistrée d'abord ; sinon comme avant (compagnon ou
-- seul au milieu de l'écran)
do
	local place = ns.CapturePlaceNet
	function ns:CapturePlaceNet(...)
		local button = self.captureNetButton
		local saved = button and self:CaptureNetPoint()
		if not saved then return place(self, ...) end
		local frame = self.companionFrame
		local scale = (frame and frame.GetScale and frame:GetScale()) or 1
		button:ClearAllPoints()
		if button.SetScale then button:SetScale(scale) end
		button:SetPoint(saved.point, UIParent, saved.point, tonumber(saved.x), tonumber(saved.y))
		if button.SetFrameStrata then pcall(button.SetFrameStrata, button, "MEDIUM") end
		button.side, button.alone, button.moved = nil, false, true
		if frame then frame.captureNet = nil end
		return "moved"
	end
end

local StopDrag
StopDrag = function(button)
	if not button.netDragging then return end
	button.netDragging = nil
	if button.StopMovingOrSizing then button:StopMovingOrSizing() end
	button.draggedAt = Clock()
	local point, _, _, x, y = button:GetPoint(1)
	if point and x and y then
		-- en unités d'écran du filet (son échelle suit celle du compagnon)
		ns:DB().captureNetPoint = { point = point, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
	end
	ns:CapturePlaceNet()
end

local function MoveHint(tooltip)
	if not (tooltip and tooltip.IsShown and tooltip:IsShown()) then return end
	local mode = ns.CompanionMoveMode and ns:CompanionMoveMode() or "alt"
	local line = L["CAPTURE_NET_MOVE_" .. mode]
	if not line then return end
	Theme.TooltipLine(tooltip, line, Theme.MUTED)
	tooltip:Show()
end

-- Le filet : glisser selon la règle du compagnon
do
	local ensure = ns.EnsureCaptureNet
	if ensure then
		function ns:EnsureCaptureNet(...)
			local button = ensure(self, ...)
			local net = button or self.captureNetButton
			if net and not net.moveHooked then
				net.moveHooked = true
				if net.SetMovable then net:SetMovable(true) end
				if net.SetClampedToScreen then net:SetClampedToScreen(true) end
				if net.RegisterForDrag then net:RegisterForDrag("LeftButton") end
				net:SetScript("OnDragStart", function(b)
					if ns.CompanionMoveAllowed and ns:CompanionMoveAllowed() and b.StartMoving then
						b.netDragging = true
						b:StartMoving()
					end
				end)
				net:SetScript("OnDragStop", StopDrag)
				if net.HookScript then
					net:HookScript("OnEnter", function() MoveHint(rawget(_G, "GameTooltip")) end)
				end
			end
			if net and self:CaptureNetPoint() then self:CapturePlaceNet() end
			return button
		end
	end
	-- un relâcher juste après un glisser n'est pas un lancer
	local click = ns.CaptureNetClick
	if click then
		function ns:CaptureNetClick(mouse, ...)
			local net = self.captureNetButton
			if net and (net.netDragging or (net.draggedAt and Clock() - net.draggedAt < ns.CAPTURE_NET_CLICK_AFTER_DRAG)) then
				return nil
			end
			return click(self, mouse, ...)
		end
	end
end

-- Le fil des pastilles express suit le filet détaché (retour joueur) : sous
-- le filet s'il y a la place (la barre d'aides est au-dessus), sinon au-dessus
-- de la barre d'aides
ns.CAPTURE_NET_FEED_GAP = 6
do
	local place = ns.CaptureExpressPlace
	if place then
		function ns:CaptureExpressPlace(...)
			local feed, net = self.captureExpressFeed, self.captureNetButton
			if not (feed and net and net.moved and self:CaptureNetPoint()) then return place(self, ...) end
			feed:ClearAllPoints()
			local height = ns.CaptureExpressHeight and ns.CaptureExpressHeight() or 0
			local scale = (net.GetEffectiveScale and net:GetEffectiveScale()) or 1
			local bottom = net.GetBottom and net:GetBottom()
			local gap = ns.CAPTURE_NET_FEED_GAP
			local mode, stack
			if not bottom or bottom * scale - gap - height >= 0 then
				feed:SetPoint("TOP", net, "BOTTOM", 0, -gap)
				mode, stack = "net-below", "down"
			else
				local B = ns.CAPTURE_AIDBAR or { size = 28, pad = 4, above = 6 }
				feed:SetPoint("BOTTOM", net, "TOP", 0, B.above + B.size + 2 * B.pad + gap)
				mode, stack = "net-above", "up"
			end
			feed.side = "CENTER"
			if feed.stack ~= stack then
				for index = 1, #(feed.rows or {}) do feed.rows[index].slid = nil end
				feed.stack, feed.dirty = stack, true
			end
			feed.mode = mode
			return mode, stack
		end
	end
	-- le filet glissé ou rattaché : le fil se replace
	local stop = StopDrag
	StopDrag = function(button)
		stop(button)
		if ns.captureExpressFeed and ns.CaptureExpressPlace then pcall(ns.CaptureExpressPlace, ns) end
	end
end

-- Réglage (page du compagnon, après « Déplacer le compagnon ») : rattacher le filet
ns.OPTION_ACTIONS = ns.OPTION_ACTIONS or {}
ns.OPTION_ACTIONS.captureNetAttach = function(self) self:CaptureNetAttach() end
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "companionMain" and type(page.rows) == "table" then
		local at, present = nil, false
		for index, row in ipairs(page.rows) do
			if row.key == "companionMove" then at = index + 1 end
			if row.key == "captureNetAttach" then present = true end
		end
		if not present then
			table.insert(page.rows, at or (#page.rows + 1), { key = "captureNetAttach", label = "CAPTURE_NET_ATTACH",
				kind = "action", button = "CAPTURE_NET_ATTACH_BTN",
				describe = function() return L.CAPTURE_NET_ATTACH_DESC end })
		end
	end
end

-- /qc filet rattacher (attach)
if ns.EXTRA_COMMANDS and ns.EXTRA_COMMANDS["filet"] then
	local base = ns.EXTRA_COMMANDS["filet"]
	ns.EXTRA_COMMANDS["filet"] = function(self, rest, ...)
		local sub = (tostring(rest or ""):match("^%s*(%S*)") or ""):lower()
		if sub == "rattacher" or sub == "attach" then return self:CaptureNetAttach() end
		return base(self, rest, ...)
	end
	ns.EXTRA_COMMANDS["net"] = ns.EXTRA_COMMANDS["filet"]
end

if ns.Mark then ns.Mark("CaptureNetMove") end
