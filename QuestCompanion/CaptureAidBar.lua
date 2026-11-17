-- CaptureAidBar.lua -- Aides au survol du filet (QuestCompanion 3.1.2)
--
-- Retour joueur : la capture express est rapide, mais on ne pouvait plus
-- choisir une aide sans ouvrir la carte (Ctrl+clic). En capture express, le
-- survol du filet fait apparaître juste au-dessus une petite barre des trois
-- aides (appât, lasso, sifflet) avec ce qu'il en reste ; un clic sur une aide
-- lance le filet tout de suite avec elle (l'aide ne sert qu'à ce lancer).
-- L'infobulle d'une aide donne la chance du lancer avec elle. Une aide qu'on
-- n'a plus est grisée. La barre se range quand la souris quitte le filet et la
-- barre, ou quand le filet est vide. Cadres de l'addon, rien de protégé :
-- utilisable en combat, comme le filet express.
local ADDON, ns = ...
if ns.blocked or not ns.CaptureExpressThrow then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	CAPTURE_AIDBAR_CLICK  = "Clic : capturer tout de suite avec cette aide.",
	CAPTURE_AIDBAR_CHANCE = "Chance : %d %%",
	CAPTURE_AIDBAR_SURE   = "Capture assurée",
	CAPTURE_AIDBAR_LEFT   = "%d en poche",
	CAPTURE_AIDBAR_EMPTY  = "Plus aucun en poche.",
	CAPTURE_AIDBAR_TIP    = "Survol : les aides au-dessus du filet, un clic capture avec.",
}
local EN = {
	CAPTURE_AIDBAR_CLICK  = "Click: catch right away with this aid.",
	CAPTURE_AIDBAR_CHANCE = "Chance: %d%%",
	CAPTURE_AIDBAR_SURE   = "Guaranteed catch",
	CAPTURE_AIDBAR_LEFT   = "%d left",
	CAPTURE_AIDBAR_EMPTY  = "None left.",
	CAPTURE_AIDBAR_TIP    = "Hover: aids above the net, click one to catch with it.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_AIDBAR_STRINGS = { fr = FR, en = EN } end

ns.CAPTURE_AIDBAR = { size = 28, gap = 4, pad = 4, above = 6, hideDelay = 0.35, bgAlpha = 0.9, hlAlpha = 0.25 }
local B = ns.CAPTURE_AIDBAR

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Tooltip() return G("GameTooltip") end
local function Over(frame)
	if not (frame and frame.IsShown and frame:IsShown()) then return false end
	if type(frame.IsMouseOver) ~= "function" then return false end
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and over == true
end

-- Le premier candidat du filet (celui qu'un clic lancerait), ou nil
local function FirstCandidate(self)
	local queue = self.CaptureQueuePrune and self:CaptureQueuePrune() or {}
	return queue[1]
end

function ns:CaptureAidBarChance(aidID)
	local candidate = FirstCandidate(self)
	if not candidate then return nil end
	if self.CapturePrepChance then return self:CapturePrepChance(candidate, aidID) end
	return self:CaptureChance(candidate, aidID)
end

local function ShowAidTooltip(button)
	local tooltip = Tooltip()
	if not tooltip then return end
	local id = button.aidID
	tooltip:SetOwner(button, "ANCHOR_TOP")
	if tooltip.ClearLines then tooltip:ClearLines() end
	Theme.TooltipLine(tooltip, L["CAPTURE_aid_" .. id] or id, Theme.GOLD_LIGHT or Theme.GOLD)
	Theme.TooltipLine(tooltip, L["CAPTURE_AID_DESC_" .. id] or "", Theme.TEXT)
	local count = ns:CaptureAidCount(id)
	if count <= 0 then
		Theme.TooltipLine(tooltip, L.CAPTURE_AIDBAR_EMPTY, Theme.MUTED_LIGHT)
	else
		local chance, sure = ns:CaptureAidBarChance(id)
		if sure then
			Theme.TooltipLine(tooltip, L.CAPTURE_AIDBAR_SURE, Theme.GREEN)
		elseif chance then
			Theme.TooltipLine(tooltip, ns:F("CAPTURE_AIDBAR_CHANCE", math.floor(chance * 100 + 0.5)), Theme.GREEN)
		end
		Theme.TooltipLine(tooltip, ns:F("CAPTURE_AIDBAR_LEFT", count), Theme.MUTED_LIGHT)
		Theme.TooltipLine(tooltip, L.CAPTURE_AIDBAR_CLICK, Theme.MUTED_LIGHT)
	end
	tooltip:Show()
end

-- Un clic sur une aide : le filet part avec elle
function ns:CaptureAidBarUse(aidID)
	if self:CaptureAidCount(aidID) <= 0 then return false, "none" end
	if not FirstCandidate(self) then return false, "empty" end
	local state = self:CaptureState()
	local previous = state.aid
	state.aid = aidID
	local rolling, why = self:CaptureExpressThrow()
	if not rolling then state.aid = previous end
	self:CaptureAidBarRefresh()
	return rolling, why
end

function ns:EnsureCaptureAidBar()
	if self.captureAidBar then return self.captureAidBar end
	local count = #(ns.CAPTURE_AIDS or {})
	local bar = CreateFrame("Frame", nil, UIParent)
	bar:SetSize(count * B.size + (count - 1) * B.gap + 2 * B.pad, B.size + 2 * B.pad)
	if bar.SetFrameStrata then bar:SetFrameStrata("DIALOG") end
	if bar.EnableMouse then bar:EnableMouse(true) end
	bar.bg = Theme.Solid(bar, "BACKGROUND", Theme.INK, B.bgAlpha)
	bar.bg:SetAllPoints(bar)
	if Theme.Border then bar.edge = Theme.Border(bar, Theme.GOLD, 1, "BORDER") end
	bar.buttons = {}
	for index, aid in ipairs(ns.CAPTURE_AIDS or {}) do
		local button = CreateFrame("Button", nil, bar)
		button:SetSize(B.size, B.size)
		button:SetPoint("LEFT", bar, "LEFT", B.pad + (index - 1) * (B.size + B.gap), 0)
		button.aidID = aid.id
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		button.icon:SetTexture(aid.icon)
		if button.icon.SetTexCoord then button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
		button.count = Theme.Text(button, Theme.F_SMALL, Theme.TEXT)
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		if Theme.TextShadow then Theme.TextShadow(button.count) end
		button.hl = button:CreateTexture(nil, "HIGHLIGHT")
		button.hl:SetAllPoints(button)
		button.hl:SetTexture(Theme.SOLID or "Interface\\Buttons\\WHITE8X8")
		button.hl:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], B.hlAlpha)
		if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp") end
		button:SetScript("OnClick", function(b)
			local ok, err = pcall(ns.CaptureAidBarUse, ns, b.aidID)
			if not ok and ns.RecordError then ns:RecordError("capture:aidbar", err) end
			if b:IsShown() and Over(b) then ShowAidTooltip(b) end
		end)
		button:SetScript("OnEnter", ShowAidTooltip)
		button:SetScript("OnLeave", function()
			local tooltip = Tooltip()
			if tooltip and tooltip.Hide then tooltip:Hide() end
		end)
		bar.buttons[index] = button
	end
	-- se range quand la souris a quitté le filet et la barre un court instant
	bar:SetScript("OnUpdate", function(b)
		local net = ns.captureNetButton
		if Over(b) or Over(net) then b.leftAt = nil; return end
		local now = Clock()
		b.leftAt = b.leftAt or now
		if now - b.leftAt >= B.hideDelay then b.leftAt = nil; b:Hide() end
	end)
	bar:Hide()
	self.captureAidBar = bar
	return bar
end

-- Compteurs et grisé ; la barre se range si le filet est vide
function ns:CaptureAidBarRefresh()
	local bar = self.captureAidBar
	if not bar then return end
	if not FirstCandidate(self) or not self:CaptureExpressOn() then bar:Hide(); return end
	for _, button in ipairs(bar.buttons) do
		local count = self:CaptureAidCount(button.aidID)
		button.count:SetText(count > 0 and tostring(count) or "")
		local empty = count <= 0
		if button.icon.SetDesaturated then button.icon:SetDesaturated(empty) end
		button.icon:SetAlpha(empty and 0.35 or 1)
		button.empty = empty
	end
end

-- Au survol du filet, en capture express, avec un candidat
function ns:CaptureAidBarShow()
	local net = self.captureNetButton
	if not (net and net:IsShown()) or not self:CaptureExpressOn() or not FirstCandidate(self) then return false end
	if self.CapturePrepShown and self:CapturePrepShown() then return false end
	local bar = self:EnsureCaptureAidBar()
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOM", net, "TOP", 0, B.above)
	bar.leftAt = nil
	bar:Show()
	self:CaptureAidBarRefresh()
	return bar:IsShown()
end

-- Le filet : survol -> la barre (post-crochet, le filet garde son infobulle)
do
	local ensure = ns.EnsureCaptureNet
	if ensure then
		function ns:EnsureCaptureNet(...)
			local button = ensure(self, ...)
			local net = button or self.captureNetButton
			if net and not net.aidBarHooked and net.HookScript then
				net.aidBarHooked = true
				net:HookScript("OnEnter", function()
					local ok, err = pcall(ns.CaptureAidBarShow, ns)
					if not ok and ns.RecordError then ns:RecordError("capture:aidbar", err) end
				end)
			end
			return button
		end
	end
	-- le filet change (lancer, prise, file vidée) : compteurs et visibilité suivis
	local refresh = ns.CaptureQueueRefresh
	if refresh then
		function ns:CaptureQueueRefresh(...)
			local a, b, c = refresh(self, ...)
			if self.captureAidBar and self.captureAidBar:IsShown() then pcall(self.CaptureAidBarRefresh, self) end
			return a, b, c
		end
	end
	-- une ligne de plus dans l'infobulle du filet express
	local tip = ns.CaptureExpressTipLines
	if tip then
		function ns:CaptureExpressTipLines(tooltip, queue, name)
			local wrote = tip(self, tooltip, queue, name)
			if wrote then Theme.TooltipLine(tooltip, L.CAPTURE_AIDBAR_TIP, Theme.MUTED_LIGHT) end
			return wrote
		end
	end
end

if ns.Mark then ns.Mark("CaptureAidBar") end
