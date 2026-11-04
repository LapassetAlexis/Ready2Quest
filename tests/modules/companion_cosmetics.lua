-- Compagnon : cosmétiques du coffre (v1.25.0). Catalogue (paliers, libellés,
-- numéros d'affichage), liste des récompenses, cadres et fonds posés sur le
-- cadre (et leurs replis), ornements ajoutés, choix dans les réglages.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local K = { savedIsUnlocked = NS.CompanionIsUnlocked, savedCreateColor = rawget(_G, "CreateColor"), savedJournal = rawget(NS, "JournalCounts") }

-- Règle du coffre, simulée (elle appartient au module du coffre) : un
-- cosmétique de palier sans `unlock` n'est possédé que s'il a été donné.
function NS:CompanionIsUnlocked(kind, def)
	if type(def) == "table" and not def.unlock and (tonumber(def.tier) or 0) >= 1 then
		return self:CompanionData().unlocked[kind .. ":" .. tostring(def.id)] == true
	end
	return K.savedIsUnlocked(self, kind, def)
end

function K.Reset()
	ResetWorld()
	for _, frame in ipairs({ NS.companionFrame, NS.companionBubble, NS.companionHover }) do
		if frame then frame:Hide() end
	end
	NS.companionFrame, NS.companionBubble, NS.companionHover = nil, nil, nil
	NS.companionRT, NS.companionSession = nil, nil
	NS.JournalCounts = nil
	Mock.world.level = 11
	NS:CompanionData().tutoDone = true
	return NS:EnsureCompanionFrame()
end
function K.Give(kind, id) NS:CompanionData().unlocked[kind .. ":" .. id] = true end
function K.Def(list, id) for _, def in ipairs(list) do if def.id == id then return def end end end
function K.Row(key)
	for _, row in ipairs(NS.optionsFrame.rows) do if row.def and row.def.key == key then return row end end
end
function K.Swatch(row, id) for _, s in ipairs(row.swatches or {}) do if s.def.id == id then return s end end end

do
	Say("-- cosmétiques : catalogue")
	local fr, en = NS.COMPANION_STRINGS.fr, NS.COMPANION_STRINGS.en
	local problems = {}
	local kinds = {}
	for _, group in ipairs(NS.COMPANION_CATALOG) do
		kinds[group.kind] = true
		local seen = {}
		for index, def in ipairs(group.list) do
			local where = group.kind .. ":" .. tostring(def.id)
			if type(def.id) ~= "string" or seen[def.id] then problems[#problems + 1] = "id " .. where end
			seen[def.id or index] = true
			if not (fr[def.label] and en[def.label] and fr[def.label] ~= "" and en[def.label] ~= "") then
				problems[#problems + 1] = "libellé " .. where
			end
			local tier = def.tier
			if type(tier) ~= "number" or tier < 0 or tier > 3 or tier % 1 ~= 0 then problems[#problems + 1] = "palier " .. where end
		end
		-- le premier de chaque liste est possédé d'office (les ornements sont tous à gagner)
		if group.kind ~= "orn" and not (group.list[1] and group.list[1].tier == 0 and not group.list[1].unlock) then
			problems[#problems + 1] = "départ " .. group.kind
		end
	end
	Check("[COSM] id unique, libellé fr+en, palier 0-3, départ au palier 0", #problems == 0, table.concat(problems, ", "))
	Check("[COSM] quatre types : apparences, ornements, cadres, fonds", kinds.app and kinds.orn and kinds.frame and kinds.bg)
	Check("[COSM] 6 à 8 cadres, 6 à 9 fonds", #NS.COMPANION_FRAMES >= 6 and #NS.COMPANION_FRAMES <= 8
		and #NS.COMPANION_BACKGROUNDS >= 6 and #NS.COMPANION_BACKGROUNDS <= 9, #NS.COMPANION_FRAMES .. "/" .. #NS.COMPANION_BACKGROUNDS)
	local displays, okDisplay = {}, true
	for _, def in ipairs(NS.COMPANION_APPEARANCES) do
		if type(def.display) ~= "number" or def.display <= 0 or displays[def.display] then okDisplay = false end
		displays[def.display or 0] = true
	end
	Check("[COSM] numéros d'affichage numériques et uniques", okDisplay)
	Check("[COSM] au moins 13 apparences, 8 ornements", #NS.COMPANION_APPEARANCES >= 13 and #NS.COMPANION_ORNAMENTS >= 8)
	-- les nouveaux ornements ont leur interrupteur (réglage par défaut + ligne)
	local page
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionMain" then page = p end end
	local rowKeys = {}
	for _, row in ipairs(page.rows) do if row.key then rowKeys[row.key] = true end end
	local orphans = {}
	for _, def in ipairs(NS.COMPANION_ORNAMENTS) do
		if not rowKeys[def.key] or NS:DB()[def.key] == nil then orphans[#orphans + 1] = def.id end
	end
	Check("[COSM] chaque ornement a sa ligne de réglage", #orphans == 0, table.concat(orphans, ","))
	Check("[COSM] lignes Cadre et Fond dans la page", rowKeys.companionFrameStyle and rowKeys.companionBackground)
end

do
	Say("-- cosmétiques : récompenses du coffre")
	local rewards = NS.COMPANION_REWARDS
	local perTier, expected, bad = { 0, 0, 0 }, 0, {}
	for _, group in ipairs(NS.COMPANION_CATALOG) do
		for _, def in ipairs(group.list) do if def.tier >= 1 then expected = expected + 1 end end
	end
	local keys = {}
	for _, r in ipairs(rewards) do
		local valid = (r.kind == "app" or r.kind == "orn" or r.kind == "frame" or r.kind == "bg")
			and type(r.id) == "string" and type(r.label) == "string" and (r.tier == 1 or r.tier == 2 or r.tier == 3)
			and not keys[r.kind .. ":" .. r.id]
		if not valid then bad[#bad + 1] = tostring(r.kind) .. ":" .. tostring(r.id) end
		keys[tostring(r.kind) .. ":" .. tostring(r.id)] = true
		if perTier[r.tier] then perTier[r.tier] = perTier[r.tier] + 1 end
	end
	Check("[COSM] récompenses : tous les cosmétiques de palier ≥ 1, bien formés", #rewards == expected and #bad == 0,
		#rewards .. "/" .. expected .. " " .. table.concat(bad, ","))
	Check("[COSM] au moins 7 récompenses par palier", perTier[1] >= 7 and perTier[2] >= 7 and perTier[3] >= 7,
		table.concat(perTier, "/"))
	local kindsPerTier = {}
	for _, r in ipairs(rewards) do kindsPerTier[r.tier .. r.kind] = true end
	local mixed = true
	for tier = 1, 3 do
		for _, kind in ipairs({ "app", "orn", "frame", "bg" }) do mixed = mixed and kindsPerTier[tier .. kind] == true end
	end
	Check("[COSM] chaque palier offre des quatre types", mixed)
	local frost
	for _, r in ipairs(rewards) do if r.kind == "frame" and r.id == "frost" then frost = r end end
	Check("[COSM] libellé d'une récompense", frost and NS:CompanionRewardLabel(frost) == "Givre", frost and NS:CompanionRewardLabel(frost))
	Check("[COSM] libellé avec son type", frost and NS:CompanionRewardLabel(frost, true) == "Cadre : Givre",
		frost and NS:CompanionRewardLabel(frost, true))
	Check("[COSM] libellé d'une récompense invalide : vide", NS:CompanionRewardLabel(nil) == "")
end

do
	Say("-- cosmétiques : cadre et fond posés")
	local frame = K.Reset()
	Check("[COSM] cadre par défaut : ardoise, sans bordure du client", frame.frameStyle == "slate" and not frame.frameBackdrop)
	Check("[COSM] fond par défaut : nuit, aplat", frame.bgStyle == "night" and frame.bg.texture == NS.Theme.SOLID
		and frame.bg.vertex[4] == 0.66)
	Check("[COSM] cadre verrouillé refusé", NS:CompanionSetStyle("frame", "gilded") == nil and frame.frameStyle == "slate")
	K.Give("frame", "gilded")
	NS:CompanionSetStyle("frame", "gilded")
	local border = frame.styleBorder
	Check("[COSM] or ciselé : bordure dorée du client posée", border and border:IsShown() and border.backdrop
		and border.backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Gold-Border" and frame.frameBackdrop == true)
	Check("[COSM] or ciselé : filet ambre et second filet", frame.top.vertex[1] == 0.91 and frame.styleInnerHolder:IsShown())
	Check("[COSM] choix persisté par personnage", NS:CharData().companion.frameStyle == "gilded")
	K.Give("frame", "frost")
	NS:CompanionSetStyle("frame", "frost")
	Check("[COSM] givre : teinte de la bordure", border.backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border"
		and border.backdropBorderColor[1] == 0.62)
	K.Give("frame", "copper")
	NS:CompanionSetStyle("frame", "copper")
	Check("[COSM] cuivre : filets seuls, bordure du client masquée", not border:IsShown() and frame.frameStyle == "copper")
	-- fonds : texture, dégradé (deux API), étoiles
	K.Give("bg", "velvet")
	NS:CompanionSetStyle("bg", "velvet")
	Check("[COSM] velours : texture du client teintée", frame.bg.texture == "Interface\\DialogFrame\\UI-DialogBox-Gold-Background"
		and frame.bg.vertex[1] == 0.70 and not frame.bgFallback)
	_G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	function frame.bg:SetGradient(orientation, minColor, maxColor) self.gradient = { orientation, minColor, maxColor } end
	K.Give("bg", "ember")
	NS:CompanionSetStyle("bg", "ember")
	Check("[COSM] braise : dégradé vertical (API récente), braise en bas", frame.bgGradient == "color"
		and frame.bg.gradient[1] == "VERTICAL" and frame.bg.gradient[2].r == 0.50 and frame.bg.gradient[3].r == 0.10)
	frame.bg.SetGradient = function() error("ancienne signature") end
	function frame.bg:SetGradientAlpha(orientation, r1) self.gradientAlpha = { orientation, r1 } end
	NS:CompanionApplyBackground()
	Check("[COSM] dégradé : repli sur SetGradientAlpha", frame.bgGradient == "alpha" and frame.bg.gradientAlpha[2] == 0.50)
	frame.bg.SetGradient, frame.bg.SetGradientAlpha = nil, nil
	NS:CompanionApplyBackground()
	Check("[COSM] sans API de dégradé : aplat teinté", frame.bgGradient == nil and frame.bg.vertex[1] == 0.30)
	_G.CreateColor = K.savedCreateColor
	K.Give("bg", "stars")
	NS:CompanionSetStyle("bg", "stars")
	local lit = frame.stars and #frame.stars > 0
	for _, star in ipairs(frame.stars or {}) do lit = lit and star:IsShown() end
	Check("[COSM] voûte étoilée : étoiles allumées", lit)
	K.Give("bg", "marble")
	NS:CompanionSetStyle("bg", "marble")
	Check("[COSM] autre fond : étoiles éteintes", not frame.stars[1]:IsShown() and frame.bg.texture:find("Marble", 1, true))
	-- repli : texture refusée par le client
	local baseSet = frame.bg.SetTexture
	frame.bg.SetTexture = function(self, path)
		if path ~= NS.Theme.SOLID then return false end
		return baseSet(self, path)
	end
	NS:CompanionApplyBackground()
	Check("[COSM] texture refusée : aplat teinté à la place", frame.bgFallback == true and frame.bg.texture == NS.Theme.SOLID
		and frame.bg.vertex[1] == 0.45)
	frame.bg.SetTexture = baseSet
	-- repli : SetBackdrop qui échoue
	NS:CompanionSetStyle("frame", "gilded")
	frame.styleBorder.SetBackdrop = function() error("no backdrop") end
	NS:CompanionApplyFrame()
	Check("[COSM] bordure du client en erreur : masquée, filets gardés", not frame.styleBorder:IsShown()
		and frame.frameBackdrop == false and frame.top.vertex[1] == 0.91)
	-- choix verrouillé dans la sauvegarde : retour au défaut
	NS:CompanionData().background = "frost"
	Check("[COSM] fond non possédé refusé", NS:CompanionCurrentStyle("bg").id == "night")
	-- cadre recréé (rechargement) : le choix revient
	NS:CompanionData().background = "marble"
	NS.companionFrame:Hide()
	NS.companionFrame = nil
	frame = NS:EnsureCompanionFrame()
	Check("[COSM] après rechargement : cadre et fond retrouvés", frame.frameStyle == "gilded" and frame.bgStyle == "marble")
end

do
	Say("-- cosmétiques : client sans BackdropTemplate ni CreateColor")
	K.Reset()
	Mock.world.noBackdropTemplate = true
	NS.companionFrame:Hide()
	NS.companionFrame = nil
	local frame = NS:EnsureCompanionFrame()
	K.Give("frame", "silver")
	local ok = pcall(NS.CompanionSetStyle, NS, "frame", "silver")
	Check("[COSM] sans BackdropTemplate : rien ne casse, cadre posé", ok and frame.frameStyle == "silver" and frame.styleBorder ~= nil)
	Mock.world.noBackdropTemplate = nil
	K.Give("bg", "dusk")
	ok = pcall(NS.CompanionSetStyle, NS, "bg", "dusk")
	Check("[COSM] sans CreateColor : fond en aplat", ok and frame.bgStyle == "dusk" and frame.bgGradient == nil)
end

do
	Say("-- cosmétiques : nouveaux ornements")
	local frame = K.Reset()
	local orn = frame.ornaments
	Check("[COSM] ornements construits", orn.flower and orn.pennant and orn.crystal and orn.crown)
	NS:CompanionApplyOrnaments()
	Check("[COSM] ornements du coffre masqués tant qu'ils ne sont pas gagnés", not orn.crown:IsShown() and not orn.flower:IsShown())
	K.Give("orn", "crown")
	NS:CompanionApplyOrnaments()
	Check("[COSM] couronne gagnée : affichée", orn.crown:IsShown())
	NS:DB().companionOrnCrown = false
	NS:CompanionApplyOrnaments()
	Check("[COSM] couronne coupée dans les réglages : masquée", not orn.crown:IsShown())
	NS:DB().companionOrnCrown = true
end

do
	Say("-- cosmétiques : réglages")
	K.Reset()
	K.Give("frame", "copper")
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companion")
	local row = K.Row("companionFrameStyle")
	local bgRow = K.Row("companionBackground")
	Check("[COSM] une pastille par cadre et par fond", row and #row.swatches == #NS.COMPANION_FRAMES
		and bgRow and #bgRow.swatches == #NS.COMPANION_BACKGROUNDS)
	Check("[COSM] ligne du cadre : nom du choix", row.label.text:find("Cadre : ", 1, true) and row.label.text:find("Ardoise", 1, true),
		row.label.text)
	local fel, copper = K.Swatch(row, "fel"), K.Swatch(row, "copper")
	Check("[COSM] cadre verrouillé : estompé, palier affiché", fel.locked and fel.alpha == 0.35 and fel.tier:IsShown()
		and fel.tier.text == "3")
	Check("[COSM] cadre possédé : plein, sans palier", not copper.locked and copper.alpha == 1 and not copper.tier:IsShown())
	_G.GameTooltip.lines = {}
	fel.scripts.OnEnter(fel)
	Check("[COSM] infobulle : « Palier 3 »", table.concat(_G.GameTooltip.lines, "|"):find("Palier 3", 1, true) ~= nil,
		table.concat(_G.GameTooltip.lines, "|"))
	fel:Click()
	Check("[COSM] clic sur un verrouillé : rien ne change", NS:CompanionData().frameStyle == "slate")
	copper:Click()
	Check("[COSM] clic sur une pastille : choix appliqué et persisté", NS:CompanionData().frameStyle == "copper"
		and NS.companionFrame.frameStyle == "copper" and row.label.text:find("Cuivre", 1, true) and copper.selected.top:IsShown()
		and not K.Swatch(row, "slate").selected.top:IsShown())
	row:Click()
	Check("[COSM] clic sur la ligne : style possédé suivant", NS:CompanionData().frameStyle == "slate")
	bgRow:Click()
	Check("[COSM] fond : un seul possédé, le cycle y reste", NS:CompanionData().background == "night")
	-- ornement du coffre verrouillé : son palier, pas de condition de tampons
	local crown = K.Row("companionOrnCrown")
	Check("[COSM] ornement du coffre verrouillé : « (palier 3) »", crown and crown.label.text:find("(palier 3)", 1, true),
		crown and crown.label.text)
	Check("[COSM] page Compagnon sans débordement", NS.optionsFrame.pages.companionMain.contentBottom >= NS.OPT_LAYOUT.contentLimit,
		NS.optionsFrame.pages.companionMain.contentBottom)
	NS.optionsFrame:Hide()
end

NS.CompanionIsUnlocked = K.savedIsUnlocked
_G.CreateColor = K.savedCreateColor
NS.JournalCounts = K.savedJournal
if NS.companionFrame then NS.companionFrame:Hide() end
