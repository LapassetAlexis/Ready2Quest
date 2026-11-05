-- Minimap.lua -- lanceur circulaire autour de la minicarte
--
-- Aucune texture « minimap » n'est utilisée : ces chemins ne sont pas
-- vérifiables (Blizzard passe par des atlases). On réutilise les assets
-- confirmés du thème : WHITE8X8 teinté or + une icône d'objet.
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py. Clic gauche : ns:DefaultCommand() de l'addon ;
-- clic droit : ses réglages ; lignes propres à l'addon dans l'infobulle :
-- ns:MinimapTooltip(GameTooltip).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

-- Référence : LibDBIcon-1.0 (utilisé par AtlasLootClassic).
--   bouton 31x31, niveau de cadre 8
--   liseré  MiniMap-TrackingBorder   (fileID 136430) 53x53 ancré TOPLEFT
--   fond    UI-Minimap-Background    (fileID 136467) 20x20 à (7,-5)
--   icône                           17x17 à (7,-6)
--   rayon   = largeur de la minicarte / 2 + 5
--   angle par défaut : 225°
local FILE_ID = {
	trackingBorder    = 136430,   -- Interface\Minimap\MiniMap-TrackingBorder
	minimapBackground = 136467,   -- Interface\Minimap\UI-Minimap-Background
	zoomHighlight     = 136477,   -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
}

local BUTTON_SIZE = 31
local FRAME_LEVEL = 8
local RADIUS_PAD  = 5
local DEFAULT_ANGLE = 225

-- Formes de minicarte : quels quadrants sont « pleins » (repris de LibDBIcon)
local MINIMAP_SHAPES = {
	["ROUND"]                 = { true,  true,  true,  true  },
	["SQUARE"]                = { false, false, false, false },
	["CORNER-TOPLEFT"]        = { false, false, false, true  },
	["CORNER-TOPRIGHT"]       = { false, false, true,  true  },
	["CORNER-BOTTOMLEFT"]     = { false, true,  false, true  },
	["CORNER-BOTTOMRIGHT"]    = { true,  true,  false, true  },
	["SIDE-LEFT"]             = { false, true,  false, true  },
	["SIDE-RIGHT"]            = { true,  true,  false, true  },
	["SIDE-TOP"]              = { false, false, true,  true  },
	["SIDE-BOTTOM"]           = { false, true,  true,  true  },
	["TRICORNER-TOPLEFT"]     = { false, true,  true,  true  },
	["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
	["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
	["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

-- Les clients récents (et Forever) utilisent le chrome « mainline »
local function UsesMainlineChrome()
	if type(WOW_PROJECT_ID) == "number" and type(WOW_PROJECT_MAINLINE) == "number"
		and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		return true
	end
	local info = ns.BuildInfo and ns:BuildInfo()
	local toc = info and info.toc
	if not toc then return false end
	return toc >= 120000 or (toc >= 16000 and toc < 17000)
end

local function Atan2(y, x)
	if math.atan2 then return math.atan2(y, x) end
	return math.atan(y, x)
end

-- ---------------------------------------------------------------------------
-- Position sur l'anneau (formule LibDBIcon, gère les minicartes carrées)
-- ---------------------------------------------------------------------------
function ns:PositionMinimapButton()
	local button = self.minimapButton
	if not button or not Minimap then return end

	local angle = math.rad(self:DB().minimapAngle or DEFAULT_ANGLE)
	local x, y = math.cos(angle), math.sin(angle)
	local quadrant = 1
	if x < 0 then quadrant = quadrant + 1 end
	if y > 0 then quadrant = quadrant + 2 end

	local shape = "ROUND"
	if type(GetMinimapShape) == "function" then
		local ok, value = pcall(GetMinimapShape)
		if ok and type(value) == "string" then shape = value end
	end
	local quad = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES["ROUND"]

	local w = ((Minimap:GetWidth() or 140) / 2) + RADIUS_PAD
	local h = ((Minimap:GetHeight() or 140) / 2) + RADIUS_PAD

	if quad[quadrant] then
		x, y = x * w, y * h
	else
		local diagonalW = math.sqrt(2 * (w ^ 2)) - 10
		local diagonalH = math.sqrt(2 * (h ^ 2)) - 10
		x = math.max(-w, math.min(x * diagonalW, w))
		y = math.max(-h, math.min(y * diagonalH, h))
	end

	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function ns:UpdateMinimapDrag()
	local button = self.minimapButton
	if not button or not Minimap then return end
	if type(GetCursorPosition) ~= "function" then return end

	local mx, my = Minimap:GetCenter()
	if type(mx) ~= "number" or type(my) ~= "number" then return end

	local scale = 1
	if Minimap.GetEffectiveScale then
		local ok, value = pcall(Minimap.GetEffectiveScale, Minimap)
		if ok and type(value) == "number" and value > 0 then scale = value end
	end

	local cx, cy = GetCursorPosition()
	if type(cx) ~= "number" then return end
	cx, cy = cx / scale, cy / scale

	self:DB().minimapAngle = math.deg(Atan2(cy - my, cx - mx))
	self:PositionMinimapButton()
	self.minimapDragMoved = true
end

-- Infobulle du lanceur : nom, lignes de l'addon (ns:MinimapTooltip), clic
-- gauche ; clic droit et glisser seulement pour le bouton de la minicarte.
function ns:ShowMinimapTooltip(owner, fromButton)
	if type(GameTooltip) ~= "table" or not GameTooltip.SetOwner then return end
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	Theme.TooltipTitle(GameTooltip, L.ADDON_NAME)
	if self.MinimapTooltip then self:MinimapTooltip(GameTooltip) end
	Theme.TooltipLine(GameTooltip, L.MINIMAP_LEFT, Theme.TEXT)
	if fromButton then
		Theme.TooltipLine(GameTooltip, L.MINIMAP_RIGHT, Theme.TEXT)
		Theme.TooltipHint(GameTooltip, L.MINIMAP_DRAG)
	end
	GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Création
-- ---------------------------------------------------------------------------
function ns:EnsureMinimapButton()
	if self.minimapButton then return self.minimapButton end
	if type(Minimap) ~= "table" and type(Minimap) ~= "userdata" then return nil end
	if type(CreateFrame) ~= "function" then return nil end

	local button = CreateFrame("Button", ns.APP.id .. "MinimapButton", Minimap)
	if not button then return nil end

	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:SetFrameStrata("MEDIUM")
	if button.SetFixedFrameStrata then button:SetFixedFrameStrata(true) end
	button:SetFrameLevel(FRAME_LEVEL)
	if button.SetFixedFrameLevel then button:SetFixedFrameLevel(true) end

	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")

	-- Surbrillance native du bouton de zoom de la minicarte
	if button.SetHighlightTexture then
		local ok = pcall(button.SetHighlightTexture, button, FILE_ID.zoomHighlight)
		if not ok then pcall(button.SetHighlightTexture, button, Theme.SOLID) end
	end

	local mainline = UsesMainlineChrome()

	-- Liseré circulaire (MiniMap-TrackingBorder)
	button.bg = button:CreateTexture(nil, "OVERLAY")
	button.bg:SetTexture(FILE_ID.trackingBorder)
	if mainline then
		button.bg:SetSize(50, 50)
		button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	else
		button.bg:SetSize(53, 53)
		button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	end
	button.artStyle = mainline and "mainline" or "classic"

	-- Pastille sombre derrière l'icône (UI-Minimap-Background)
	button.plate = button:CreateTexture(nil, "BACKGROUND")
	button.plate:SetTexture(FILE_ID.minimapBackground)
	if mainline then
		button.plate:SetSize(24, 24)
		button.plate:SetPoint("CENTER", button, "CENTER", 0, 1)
	else
		button.plate:SetSize(20, 20)
		button.plate:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
	end

	button.icon = button:CreateTexture(nil, "ARTWORK")
	-- la marque de l'addon (boussole) plutôt qu'une icône d'objet générique
	button.icon:SetTexture(ns.Theme and ns.Theme.LOGO_SMALL or "Interface\\Icons\\INV_Misc_Bag_10")
	button.icon:SetTexCoord(0, 1, 0, 1)
	if mainline then
		button.icon:SetSize(18, 18)
		button.icon:SetPoint("CENTER", button, "CENTER", 0, 1)
	else
		button.icon:SetSize(17, 17)
		button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
	end

	button:SetScript("OnClick", function(_, mouseButton)
		if ns.minimapDragMoved then
			ns.minimapDragMoved = nil
			return
		end
		-- clic gauche = l'action principale de l'addon (le check, le carnet…)
		if mouseButton == "RightButton" then
			ns:ToggleOptions()
		elseif ns.DefaultCommand then
			ns:DefaultCommand()
		end
	end)

	button:SetScript("OnEnter", function(self) ns:ShowMinimapTooltip(self, true) end)

	button:SetScript("OnLeave", function()
		if type(GameTooltip) == "table" and GameTooltip.Hide then GameTooltip:Hide() end
	end)

	button:SetScript("OnDragStart", function()
		ns.minimapDragMoved = nil
		button:SetScript("OnUpdate", function() ns:UpdateMinimapDrag() end)
	end)

	button:SetScript("OnDragStop", function()
		button:SetScript("OnUpdate", nil)
		ns:PositionMinimapButton()
	end)

	self.minimapButton = button
	self:PositionMinimapButton()
	return button
end

function ns:ShowMinimapButton()
	local button = self:EnsureMinimapButton()
	if button then button:Show() end
end

function ns:HideMinimapButton()
	if self.minimapButton then self.minimapButton:Hide() end
end

function ns:ToggleMinimapButton()
	local db = self:DB()
	db.showMinimap = not (db.showMinimap ~= false)
	if db.showMinimap then
		self:ShowMinimapButton()
	else
		self:HideMinimapButton()
	end
	return db.showMinimap
end

-- Fait tourner le bouton parmi les positions usuelles de l'anneau
local ANGLES = { 225, 270, 315, 0, 45, 90, 135, 180 }

function ns:CycleMinimapAngle()
	local db = self:DB()
	local current = db.minimapAngle or DEFAULT_ANGLE
	local nextAngle = (current + 45) % 360

	for index, angle in ipairs(ANGLES) do
		if math.abs(angle - current) < 1 then
			nextAngle = ANGLES[(index % #ANGLES) + 1]
			break
		end
	end

	db.minimapAngle = nextAngle
	self:PositionMinimapButton()
	self:Print(self:F("MSG_MINIMAP_POS", math.floor(nextAngle + 0.5)))
end

-- ---------------------------------------------------------------------------
-- Bouton des addons de la minicarte (AddonCompartmentFrame, moteur récent)
-- ---------------------------------------------------------------------------
-- Une entrée par addon, inscrite une fois à la connexion : même icône et même
-- clic gauche que le bouton de la minicarte, même infobulle (sans les lignes
-- propres au bouton). Sans AddonCompartmentFrame.RegisterAddon : rien.
function ns:RegisterAddonCompartment()
	if self.compartmentEntry ~= nil then return self.compartmentEntry or nil end
	local compartment = rawget(_G, "AddonCompartmentFrame")
	if not compartment or type(compartment.RegisterAddon) ~= "function" then return nil end
	local entry = {
		text = tostring(ns.APP.id),
		icon = ns.Theme and ns.Theme.LOGO_SMALL or "Interface\\Icons\\INV_Misc_Bag_10",
		notCheckable = true,
		func = function() if ns.DefaultCommand then ns:DefaultCommand() end end,
		funcOnEnter = function(owner)
			ns:ShowMinimapTooltip(type(owner) == "table" and owner or compartment, false)
		end,
		funcOnLeave = function()
			if type(GameTooltip) == "table" and GameTooltip.Hide then GameTooltip:Hide() end
		end,
	}
	-- marqué avant l'appel : un refus du client ne se retente pas
	self.compartmentEntry = false
	if not pcall(compartment.RegisterAddon, compartment, entry) then return nil end
	self.compartmentEntry = entry
	return entry
end

do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame then
		pcall(frame.RegisterEvent, frame, "PLAYER_LOGIN")
		frame:SetScript("OnEvent", function()
			local done, err = pcall(ns.RegisterAddonCompartment, ns)
			if not done then ns:RecordError("compartment", err) end
		end)
		ns.compartmentEventFrame = frame
	end
end

ns.Mark("Minimap")
