-- Treats.lua -- friandises et garde-manger du compagnon (QuestCompanion 1.1.0)
--
-- La complétion nourrit la créature : chaque palier d'une zone (25, 50, 75 %)
-- donne une friandise, rangée dans un garde-manger. Le joueur la donne quand
-- il veut (Maj + clic sur la créature) : c'est un moment avec elle.
--   * Biscuit de voyage -> faim, Infusion douce -> énergie, Bonbon pétillant
--     -> moral (et des cœurs), Carte au trésor -> curiosité (et elle flaire
--     ce qui reste dans la zone), Festin -> les quatre envies ;
--   * 25 et 50 % : la friandise de l'envie la plus basse ; 75 % : un Festin ;
--     100 % : le coffre de zone, comme avant ;
--   * garde-manger : TREAT_CAP de chaque sorte, FESTIN_CAP Festins ; plein,
--     la friandise est mangée tout de suite (« tant pis, je la mange ! ») ;
--   * coffre doré (palier de cosmétiques déjà complet) : un Festin et deux
--     friandises au hasard, au lieu de rien ;
--   * à la mise à jour, les paliers déjà franchis sont rattrapés une fois,
--     avec une seule bulle de résumé ;
--   * Gourmand : chaque friandise remonte aussi le moral (double plaisir).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local TREAT_CAP, FESTIN_CAP = 3, 2
local MILESTONES = { 25, 50, 75 }
local GLUTTON_MOOD = 15
local KINDS = { "biscuit", "infusion", "bonbon", "carte", "festin" }
local BASIC = { "biscuit", "infusion", "bonbon", "carte" }
-- friandise -> envie qu'elle comble (le Festin : toutes)
local NEED_OF = { biscuit = "hunger", infusion = "energy", bonbon = "mood", carte = "curiosity" }
local KIND_OF = { hunger = "biscuit", energy = "infusion", mood = "bonbon", curiosity = "carte" }
local ICONS = {
	biscuit  = "Interface\\Icons\\INV_Misc_Food_11",
	infusion = "Interface\\Icons\\INV_Drink_07",
	bonbon   = "Interface\\Icons\\INV_ValentinesCandy",
	carte    = "Interface\\Icons\\INV_Misc_Map_01",
	festin   = "Interface\\Icons\\INV_Misc_Food_15",
}
ns.TREAT_RULES = { cap = TREAT_CAP, festinCap = FESTIN_CAP, milestones = MILESTONES, gluttonMood = GLUTTON_MOOD }
ns.TREAT_KINDS = KINDS
ns.TREAT_ICONS = ICONS

local FR = {
	TREAT_biscuit        = "Biscuit de voyage",
	TREAT_infusion       = "Infusion douce",
	TREAT_bonbon         = "Bonbon pétillant",
	TREAT_carte          = "Carte au trésor",
	TREAT_festin         = "Festin",
	TREAT_DESC_biscuit   = "Faim à 100 %.",
	TREAT_DESC_infusion  = "Énergie à 100 %.",
	TREAT_DESC_bonbon    = "Moral à 100 %, et des cœurs.",
	TREAT_DESC_carte     = "Curiosité à 100 %, et elle flaire ce qui reste dans la zone.",
	TREAT_DESC_festin    = "Les quatre envies à 100 %.",
	TREAT_MENU_TITLE     = "Garde-manger",
	TREAT_MENU_HINT      = "Clic : donner. Les paliers de zone (25, 50, 75 %) en rapportent.",
	TREAT_COUNT          = "%d / %d",
	TREAT_NONE           = "Pas encore de friandise : complète une zone à 25 % pour la première.",
}
local EN = {
	TREAT_biscuit        = "Travel biscuit",
	TREAT_infusion       = "Soothing tea",
	TREAT_bonbon         = "Fizzy candy",
	TREAT_carte          = "Treasure map",
	TREAT_festin         = "Feast",
	TREAT_DESC_biscuit   = "Hunger to 100%.",
	TREAT_DESC_infusion  = "Energy to 100%.",
	TREAT_DESC_bonbon    = "Mood to 100%, with hearts.",
	TREAT_DESC_carte     = "Curiosity to 100%, and it sniffs out what's left in the zone.",
	TREAT_DESC_festin    = "All four needs to 100%.",
	TREAT_MENU_TITLE     = "Pantry",
	TREAT_MENU_HINT      = "Click: give. Zone milestones (25, 50, 75%) earn more.",
	TREAT_COUNT          = "%d / %d",
	TREAT_NONE           = "No treat yet: bring a zone to 25% for the first one.",
}
ns.RegisterStrings(FR, EN)
ns.TREAT_STRINGS = { fr = FR, en = EN }

-- Répliques (même registre que CompanionLines : clés COMP_SAY_<RÉSERVOIR>[_n])
local P = {
	TREAT_GOT = {   -- %s = la friandise
		{ "Hop, au garde-manger : %s !", "Into the pantry: %s!" },
		{ "Ooh, %s ! Je garde ça pour plus tard.", "Ooh, %s! I'm saving it for later." },
		{ "%s ! Merci, je range ça.", "%s! Thanks, I'll put it away." },
	},
	TREAT_FULL = {  -- %s = la friandise
		{ "Plus de place pour : %s… tant pis, je mange ça !", "No room left for: %s… oh well, I'll eat it!" },
		{ "Garde-manger plein ! %s ? Hop, dans le ventre.", "Pantry's full! %s? Straight into my tummy." },
	},
	TREAT_EAT_biscuit = {
		{ "Croc ! Ça cale bien.", "Crunch! That hits the spot." },
		{ "Mmmh, un biscuit de voyage. Le meilleur.", "Mmm, a travel biscuit. The best." },
	},
	TREAT_EAT_infusion = {
		{ "Ahhh… je me sens tout neuf.", "Ahhh… I feel brand new." },
		{ "Une petite infusion, et c'est reparti !", "A little tea, and off we go again!" },
	},
	TREAT_EAT_bonbon = {
		{ "Ça pétille ! Hihi !", "It fizzes! Hehe!" },
		{ "Un bonbon pour moi ? Tu es le meilleur.", "A candy for me? You're the best." },
	},
	TREAT_EAT_carte = {
		{ "Une carte ! Voyons voir…", "A map! Let's see…" },
		{ "Ooh, une carte au trésor ! Mon flair s'éveille.", "Ooh, a treasure map! My nose is tingling." },
	},
	TREAT_EAT_festin = {
		{ "UN FESTIN ! Pour moi tout seul ?!", "A FEAST! All for me?!" },
		{ "Le plus beau jour de ma vie. Miam.", "Best day of my life. Yum." },
	},
	TREAT_SNIFF = { -- %s = ce qui reste (une part de la complétion)
		{ "Mon flair me dit : %s, il en reste par ici !", "My nose says: %s, there's more around here!" },
		{ "Je sens quelque chose… %s !", "I can smell something… %s!" },
	},
	TREAT_RETRO = { -- %d = friandises trouvées, %d = mangées tout de suite
		{ "J'ai fait des provisions : %d friandises… et j'en ai mangé %d !", "I've stocked up: %d treats… and I ate %d of them!" },
	},
	TREAT_RETRO_KEPT = { -- %d = friandises trouvées
		{ "Regarde ! J'ai trouvé %d friandises sur notre route.", "Look! I found %d treats along our way." },
	},
	TREAT_GOLDEN = {
		{ "Un coffre doré ? Pour moi, c'est un festin !", "A golden chest? For me, that's a feast!" },
	},
	-- Gourmand : le double plaisir (variantes du caractère)
	TREAT_EAT_biscuit__glutton = {
		{ "Encore ! ENCORE ! …Bon, merci.", "More! MORE! …OK, thank you." },
		{ "Croc, croc, croc. J'adore manger.", "Crunch, crunch, crunch. I love eating." },
	},
	TREAT_EAT_festin__glutton = {
		{ "Je ne bougerai plus jamais. C'est parfait.", "I'll never move again. It's perfect." },
	},
}
local LINES_FR, LINES_EN, POOLS = {}, {}, {}
for name, lines in pairs(P) do
	local keys = {}
	for index, pair in ipairs(lines) do
		local key = "COMP_SAY_" .. name .. (index > 1 and ("_" .. index) or "")
		LINES_FR[key], LINES_EN[key] = pair[1], pair[2]
		keys[index] = key
	end
	POOLS[name] = keys
end
ns.RegisterStrings(LINES_FR, LINES_EN)
if type(ns.COMPANION_POOLS) == "table" then
	for name, keys in pairs(POOLS) do ns.COMPANION_POOLS[name] = keys end
end
local shared = ns.COMPANION_LINE_STRINGS
if type(shared) == "table" then
	for key, text in pairs(LINES_FR) do shared.fr[key], shared.en[key] = text, LINES_EN[key] end
end
ns.TREAT_POOLS = POOLS

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

local function ModuleOn()
	return ns.CompanionOn and ns.CompanionOn() or false
end

-- ---------------------------------------------------------------------------
-- Données (par personnage, dans la créature)
-- ---------------------------------------------------------------------------
function ns:TreatData()
	local data = self:CompanionData()
	local pantry = type(data.pantry) == "table" and data.pantry or {}
	for _, kind in ipairs(KINDS) do
		pantry[kind] = math.max(0, math.min(math.floor(tonumber(pantry[kind]) or 0), self:TreatCap(kind)))
	end
	data.pantry = pantry
	data.milestones = type(data.milestones) == "table" and data.milestones or {}
	return data
end

function ns:TreatCap(kind)
	return kind == "festin" and FESTIN_CAP or TREAT_CAP
end

function ns:TreatCount(kind)
	return self:TreatData().pantry[kind] or 0
end

function ns:TreatTotal()
	local total = 0
	for _, kind in ipairs(KINDS) do total = total + self:TreatCount(kind) end
	return total
end

function ns:TreatLabel(kind)
	return L["TREAT_" .. tostring(kind)] or tostring(kind)
end

-- La friandise de l'envie la plus basse (à égalité, l'ordre faim, énergie,
-- moral, curiosité)
function ns:TreatForLowestNeed()
	local needs = self:CompanionData().needs
	local best, low
	for _, need in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		local v = tonumber(needs[need]) or 0
		if not low or v < low then best, low = need, v end
	end
	return KIND_OF[best]
end

function ns:TreatRandom()
	return BASIC[math.random(#BASIC)]
end

-- ---------------------------------------------------------------------------
-- Manger, gagner, donner
-- ---------------------------------------------------------------------------
-- Ce qui reste à faire dans la zone : la part la moins avancée
function ns:TreatSniff()
	local zoneID = self.JournalZone and self:JournalZone()
	local done = zoneID and self.ZoneCompletion and self:ZoneCompletion(zoneID)
	if not done then return nil end
	local best
	for _, part in ipairs(done.parts) do
		if part.have < part.need and (not best or part.ratio < best.ratio) then best = part end
	end
	return best and best.label or nil
end

-- La créature mange : les envies montent, un effet, une bulle (forcée : c'est
-- le joueur qui donne, ou le garde-manger qui déborde). quiet : sans bulle.
function ns:TreatEat(kind, opts)
	opts = opts or {}
	if not NEED_OF[kind] and kind ~= "festin" then return false end
	if kind == "festin" then
		for _, need in ipairs({ "hunger", "energy", "mood", "curiosity" }) do self:CompanionAdd(need, 100) end
	else
		self:CompanionAdd(NEED_OF[kind], 100)
	end
	local trait = self.CompanionTrait and self:CompanionTrait()
	if trait == "glutton" then self:CompanionAdd("mood", GLUTTON_MOOD) end
	if self.CompanionFx then
		if kind == "bonbon" then self:CompanionFx("hearts")
		elseif kind == "festin" then self:CompanionFx("bounce"); self:CompanionFx("crumbs")
		elseif kind == "carte" then self:CompanionFx("alert")
		else self:CompanionFx("crumbs") end
	end
	if self.CompanionAnimate then pcall(self.CompanionAnimate, self, "cheer", 2) end
	if opts.quiet then return true end
	if kind == "carte" then
		local left = self:TreatSniff()
		if left then return true, self:CompanionSay("TREAT_SNIFF", { force = true, args = { left } }) end
	end
	self:CompanionSay("TREAT_EAT_" .. kind, { force = true })
	return true
end

-- Une friandise gagnée : au garde-manger, ou mangée tout de suite s'il est
-- plein. quiet : sans bulle (rattrapage). Renvoie "stored" ou "eaten".
function ns:TreatGrant(kind, opts)
	opts = opts or {}
	if not ModuleOn() then return nil end
	local pantry = self:TreatData().pantry
	if pantry[kind] == nil then return nil end
	if pantry[kind] >= self:TreatCap(kind) then
		self:TreatEat(kind, { quiet = true })
		if not opts.quiet then self:CompanionSay("TREAT_FULL", { args = { self:TreatLabel(kind) } }) end
		return "eaten"
	end
	pantry[kind] = pantry[kind] + 1
	if not opts.quiet then self:CompanionSay("TREAT_GOT", { args = { self:TreatLabel(kind) } }) end
	if self.TreatMenuRefresh then self:TreatMenuRefresh() end
	return "stored"
end

-- Le joueur donne une friandise du garde-manger
function ns:TreatGive(kind)
	if not ModuleOn() then return false end
	local pantry = self:TreatData().pantry
	if (pantry[kind] or 0) < 1 then return false end
	pantry[kind] = pantry[kind] - 1
	if self.CompanionWake then pcall(self.CompanionWake, self, false) end
	self:TreatEat(kind)
	self:TreatMenuRefresh()
	return true
end

-- ---------------------------------------------------------------------------
-- Paliers de zone
-- ---------------------------------------------------------------------------
-- Franchit les paliers non réclamés d'une zone. Renvoie les friandises
-- gagnées ({ kind, result }...). Au moins deux parts, comme le coffre.
function ns:TreatCheckZone(zoneID, opts)
	opts = opts or {}
	if not ModuleOn() or not zoneID or not self.ZoneCompletion then return {} end
	local done = self:ZoneCompletion(zoneID)
	if not done or #done.parts < 2 then return {} end
	local milestones = self:TreatData().milestones
	local claimed = tonumber(milestones[zoneID]) or 0
	local gained = {}
	for _, mark in ipairs(MILESTONES) do
		if done.percent >= mark and claimed < mark then
			local kind = mark >= 75 and "festin" or self:TreatForLowestNeed()
			gained[#gained + 1] = { kind = kind, mark = mark, result = self:TreatGrant(kind, { quiet = opts.quiet }) }
			claimed = mark
			milestones[zoneID] = mark
		end
	end
	return gained
end

-- Rattrapage, une fois : les paliers déjà franchis dans toutes les zones du
-- carnet, une seule bulle de résumé
function ns:TreatCatchUp()
	local data = self:TreatData()
	if data.treatsInit then return nil end
	data.treatsInit = true
	if not self.JournalKnownZones then return nil end
	local found, eaten = 0, 0
	for _, zone in ipairs(self:JournalKnownZones()) do
		for _, gain in ipairs(self:TreatCheckZone(zone.id, { quiet = true })) do
			found = found + 1
			if gain.result == "eaten" then eaten = eaten + 1 end
		end
	end
	if found > 0 then
		if eaten > 0 then
			self:CompanionSay("TREAT_RETRO", { force = true, args = { found, eaten } })
		else
			self:CompanionSay("TREAT_RETRO_KEPT", { force = true, args = { found } })
		end
	end
	return found, eaten
end

-- Les paliers se vérifient quand le suivi se recalcule (comme le coffre),
-- après lui : sa bulle passe d'abord
do
	local previous = ns.RefreshJournalTracker
	if previous then
		function ns:RefreshJournalTracker(...)
			local a, b = previous(self, ...)
			if ModuleOn() then
				local ok, err = pcall(function()
					if not self:TreatData().treatsInit then
						self:TreatCatchUp()
					else
						local zoneID = self.JournalZone and self:JournalZone()
						if zoneID then self:TreatCheckZone(zoneID) end
					end
				end)
				if not ok and self.RecordError then self:RecordError("treats:check", err) end
			end
			return a, b
		end
	end
end

-- Coffre doré : un Festin et deux friandises au hasard
do
	local original = ns.ChestCheck
	if original then
		function ns:ChestCheck(...)
			local chest = original(self, ...)
			if chest and chest.golden then
				local ok, err = pcall(function()
					self:TreatGrant("festin", { quiet = true })
					self:TreatGrant(self:TreatRandom(), { quiet = true })
					self:TreatGrant(self:TreatRandom(), { quiet = true })
					chest.treats = true
					self:CompanionSay("TREAT_GOLDEN", { force = true })
				end)
				if not ok and self.RecordError then self:RecordError("treats:golden", err) end
			end
			return chest
		end
	end
end

-- ---------------------------------------------------------------------------
-- Menu du garde-manger : Maj + clic sur la créature
-- ---------------------------------------------------------------------------
local BTN, GAP = 34, 6

function ns:EnsureTreatMenu()
	if self.treatMenu then return self.treatMenu end
	local parent = self.companionFrame
	if not parent then return nil end
	local width = #KINDS * (BTN + GAP) + GAP
	local ok, menu = pcall(CreateFrame, "Frame", "QuestCompanionTreatMenu", parent, "BackdropTemplate")
	if not ok or not menu then ok, menu = pcall(CreateFrame, "Frame", "QuestCompanionTreatMenu", parent) end
	if not ok or not menu then return nil end
	menu:SetSize(width, BTN + 30)
	menu:SetPoint("BOTTOM", parent, "TOP", 0, 26)
	if menu.SetBackdrop then
		pcall(menu.SetBackdrop, menu, { bgFile = Theme.SOLID, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		pcall(menu.SetBackdropColor, menu, Theme.SURFACE[1], Theme.SURFACE[2], Theme.SURFACE[3], 0.95)
		pcall(menu.SetBackdropBorderColor, menu, Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3], 1)
	end
	if menu.SetFrameStrata then menu:SetFrameStrata("DIALOG") end
	menu.title = menu:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	menu.title:SetPoint("TOP", menu, "TOP", 0, -5)
	menu.title:SetText(L.TREAT_MENU_TITLE)
	menu.buttons = {}
	for index, kind in ipairs(KINDS) do
		local button = CreateFrame("Button", nil, menu)
		button:SetSize(BTN, BTN)
		button:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", GAP + (index - 1) * (BTN + GAP), GAP)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button.icon:SetTexture(ICONS[kind])
		button.count = button:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		button.kind = kind
		button:SetScript("OnClick", function(b) ns:TreatGive(b.kind) end)
		button:SetScript("OnEnter", function(b)
			if not GameTooltip then return end
			GameTooltip:SetOwner(b, "ANCHOR_TOP")
			GameTooltip:SetText(ns:TreatLabel(b.kind))
			GameTooltip:AddLine(L["TREAT_DESC_" .. b.kind], 1, 1, 1, true)
			GameTooltip:AddLine(ns:F("TREAT_COUNT", ns:TreatCount(b.kind), ns:TreatCap(b.kind)), 0.49, 0.51, 0.54)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		menu.buttons[kind] = button
	end
	menu:Hide()
	self.treatMenu = menu
	return menu
end

function ns:TreatMenuRefresh()
	local menu = self.treatMenu
	if not menu then return end
	for kind, button in pairs(menu.buttons) do
		local count = self:TreatCount(kind)
		button.count:SetText(tostring(count))
		if button.icon.SetDesaturated then button.icon:SetDesaturated(count == 0) end
		button:SetAlpha(count == 0 and 0.4 or 1)
		if button.SetEnabled then button:SetEnabled(count > 0) end
	end
end

function ns:TreatMenuToggle()
	if not ModuleOn() then return false end
	local menu = self:EnsureTreatMenu()
	if not menu then return false end
	if menu:IsShown() then menu:Hide(); return false end
	self:TreatMenuRefresh()
	menu:Show()
	return true
end

-- Maj + clic sur la créature : le garde-manger au lieu de la caresse
do
	local pet = ns.CompanionPet
	if pet then
		function ns:CompanionPet(...)
			if Call(rawget(_G, "IsShiftKeyDown")) then return self:TreatMenuToggle() end
			return pet(self, ...)
		end
	end
end

if ns.Mark then ns.Mark("Treats") end
