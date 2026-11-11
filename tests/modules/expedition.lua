-- Module « Retour d'expédition » (v1.23.0) : bilan du voyage au retour en zone
-- sûre (chiffres, fenêtre, chat), voyages triviaux, réglages, module coupé,
-- page, robustesse (API absentes, motifs de butin).
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

-- Globales du client absentes du harnais : posées ici, restaurées en fin de fichier
local saved = {
	UnitFactionGroup = rawget(_G, "UnitFactionGroup"),
	UnitXP = rawget(_G, "UnitXP"),
	LOOT_ITEM_SELF = rawget(_G, "LOOT_ITEM_SELF"),
	LOOT_ITEM_SELF_MULTIPLE = rawget(_G, "LOOT_ITEM_SELF_MULTIPLE"),
	LOOT_ITEM_PUSHED_SELF = rawget(_G, "LOOT_ITEM_PUSHED_SELF"),
	GetInventoryItemDurability = rawget(_G, "GetInventoryItemDurability"),
}
_G.UnitFactionGroup = function() return "Alliance" end
_G.UnitXP = function() return Mock.world.xp or 0 end
_G.LOOT_ITEM_SELF = "Vous recevez le butin : %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "Vous recevez le butin : %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "Vous recevez l'objet : %s."

local E = {}   -- une seule locale pour les aides (limite de 200 locales)

function E.Reset()
	ResetWorld()
	-- ces tests visent la fenêtre ; l'icône qui l'annonce : tests/modules/notice.lua
	NS:DB().reportIcon = false
	NS.expedition, NS.lastExpedition = nil, nil
	if NS.expeditionFrame then NS.expeditionFrame:Hide() end
	NS.expeditionFrame = nil
	Mock.world.money = 1000
	Mock.world.xp, Mock.world.xpMax = 100, 1000
	Mock.world.durability = { [1] = { 100, 100 }, [5] = { 80, 100 } }
end

-- Comté-de-l'Or (connu d'office pour l'Alliance) -> les bois, départ confirmé
function E.Depart()
	Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	Mock.world.subzone = "Bois"
	Mock:Fire("ZONE_CHANGED")
	Mock:Advance(6)
end

function E.Return(seconds)
	Mock.now = Mock.now + (seconds or 0)
	Mock.world.subzone = "Goldshire"
	Mock:Fire("ZONE_CHANGED")
end

function E.Output() return Mock:Output() end
function E.Has(text, needle) return tostring(text):find(needle, 1, true) ~= nil end

local GREEN = "|cff1eff00|Hitem:2000::::::::|h[Épée verte]|h|r"
local GRAY  = "|cff9d9d9d|Hitem:2001::::::::|h[Os brisé]|h|r"
local BLUE  = "|cff0070dd|Hitem:3000::::::::|h[Anneau bleu]|h|r"
local EPIC  = "|cnIQ4:|Hitem:4000::::::::|h[Hache violette]|h|r"

-- Un vrai voyage : XP avec un niveau, argent gagné puis dépensé, butin, morts, usure
function E.FullTrip()
	E.Depart()
	Mock.world.links[GREEN] = { name = "Épée verte", quality = 2 }
	Mock.world.links[GRAY] = { name = "Os brisé", quality = 0 }
	Mock.world.money = 1500; Mock:Fire("PLAYER_MONEY")
	Mock.world.money = 1300; Mock:Fire("PLAYER_MONEY")
	Mock.world.xp = 900; Mock:Fire("PLAYER_XP_UPDATE", "player")
	Mock.world.level, Mock.world.xp, Mock.world.xpMax = 12, 50, 1200
	Mock:Fire("PLAYER_LEVEL_UP", 12)
	Mock:Fire("PLAYER_XP_UPDATE", "player")
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. GREEN .. ".")
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. GRAY .. ".")
	Mock:Fire("CHAT_MSG_LOOT", "Bob reçoit le butin : " .. GREEN .. ".")
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. BLUE .. "x2.")
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez l'objet : " .. EPIC .. ".")
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. GREEN .. ".")
	Mock:Fire("PLAYER_DEAD"); Mock:Fire("PLAYER_DEAD")
	Mock.world.durability = { [1] = { 50, 100 }, [5] = { 60, 100 } }
	Mock.world.quests = { { questID = 7, title = "Les loups", ready = true } }
	E.Return(754)
end

-- 1. Chaînes ------------------------------------------------------------------
do
	local strings = NS.EXPEDITION_STRINGS
	local missing = {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then missing[#missing + 1] = "en:" .. key end
		if value == "" or NS.L[key] ~= value then missing[#missing + 1] = "fr:" .. key end
	end
	for key in pairs(strings.en) do
		if strings.fr[key] == nil then missing[#missing + 1] = "fr?" .. key end
	end
	-- les mêmes placeholders dans les deux langues (sinon string.format se trompe)
	local mismatch = {}
	local function Placeholders(text)
		local list = {}
		for p in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = p end
		return table.concat(list, ",")
	end
	for key, value in pairs(strings.fr) do
		if Placeholders(value) ~= Placeholders(strings.en[key]) then mismatch[#mismatch + 1] = key end
	end
	Check("[EXP] chaînes en fr et en en, mêmes placeholders", #missing == 0 and #mismatch == 0,
		table.concat(missing, ", ") .. " / " .. table.concat(mismatch, ", "))
end

-- 2. Voyage complet : fenêtre et chiffres -------------------------------------
do
	E.Reset()
	E.FullTrip()
	local r = NS.lastExpedition
	Check("[EXP] bilan produit au retour, voyage refermé", r ~= nil and NS.expedition == nil)
	if r then
		local bad = {}
		local function Want(name, ok) if not ok then bad[#bad + 1] = name end end
		Want("durée", math.floor(r.duration) == 754)
		Want("XP (passage de niveau compris)", r.xp == 950 and r.levels == 1)
		Want("argent gagné/dépensé/net", r.earned == 500 and r.spent == 200 and r.net == 300)
		Want("morts", r.deaths == 2)
		Want("usure 90 % -> 55 %", r.duraLost == 35 and math.floor(r.durability + 0.5) == 55)
		Want("quêtes", r.quests == 1 and r.newQuests == 1)
		Want("place de retour", r.place and r.place.name == "Goldshire")
		Check("[EXP] chiffres du bilan", #bad == 0, table.concat(bad, ", "))
		Check("[EXP] butin : 3 objets (gris et butin d'autrui ignorés), regroupés, « x2 », qualité lue sur la couleur, |cnIQ4",
			#r.loot == 3 and r.loot[1].link == GREEN and r.loot[1].count == 2
			and r.loot[2].count == 2 and r.loot[2].quality == 3 and r.loot[3].quality == 4, #r.loot)
		Check("[EXP] à racheter : vivres (sacs vides)", #r.restock == 1 and r.restock[1] == NS.L.CHK_VIVRES,
			table.concat(r.restock, ","))
	end

	local f = NS.expeditionFrame
	Check("[EXP] fenêtre affichée : durée en grand, retour à Goldshire", f ~= nil and f.shown == true
		and f.duration.text == "12 min 34" and E.Has(f.subtitle.text, "Goldshire"), f and f.subtitle.text)
	if f then
		local texts = {}
		for index = 1, f.visibleLines do
			local row = f.lines[index]
			texts[#texts + 1] = tostring(row.name.text) .. "=" .. tostring(row.value.text)
		end
		local all = table.concat(texts, " | ")
		local missing = {}
		for _, part in ipairs({ "+950 XP", "+1 niveau", "+3 pa", "gagné 5 pa, dépensé 2 pa", "[Épée verte]", "[Anneau bleu]|h|r x2",
			NS.L.EXP_ROW_DEATHS .. "=2", "-35 pts, 55 % restant", "1 à rendre (+1 pendant le voyage)",
			NS.L.EXP_ROW_RESTOCK .. "=" .. NS.L.CHK_VIVRES }) do
			if not E.Has(all, part) then missing[#missing + 1] = part end
		end
		Check("[EXP] lignes : XP, argent, butin, morts, usure, quêtes, à racheter", #missing == 0, table.concat(missing, " / ") .. " :: " .. all)
		local deathRow
		for index = 1, f.visibleLines do
			if f.lines[index].name.text == NS.L.EXP_ROW_DEATHS then deathRow = f.lines[index] end
		end
		Check("[EXP] morts : losange plein", deathRow and deathRow.status.state == "filled")
		-- la fenêtre suit le nombre de lignes : la dernière carte au-dessus du
		-- pied, sans chevaucher ni laisser un grand vide
		local _, _, _, _, lastY = f.lines[f.visibleLines]:GetPoint()
		local lastBottom = -lastY + NS.EXP_LAYOUT.rowCard
		local room = f.height - NS.Theme.DIALOG_FOOTER - lastBottom
		Check("[EXP] hauteur suit le nombre de lignes", room >= 8 and room <= 24 and not f.lines[f.visibleLines + 1]:IsShown(),
			f.height .. " : " .. room)
		local escape = false
		for _, name in ipairs(UISpecialFrames) do if name == "Ready2QuestExpeditionFrame" then escape = true end end
		f.closeButton:Click()
		Check("[EXP] Échap et bouton Fermer ferment la fenêtre", escape and f.shown == false)
	end
	Check("[EXP] pas de résumé chat par défaut", not E.Has(E.Output(), "Retour d'expédition ("), E.Output())
end

-- 3. Voyage trivial -----------------------------------------------------------
do
	E.Reset()
	E.Depart()
	local tracked = NS.expedition ~= nil
	E.Return(10)
	Check("[EXP] voyage trivial : suivi, refermé, pas de bilan", tracked and NS.lastExpedition == nil
		and NS.expeditionFrame == nil and NS.expedition == nil)

	-- court, mais il s'est passé quelque chose
	E.Reset()
	E.Depart()
	Mock:Fire("PLAYER_DEAD")
	E.Return(10)
	local death = NS.lastExpedition ~= nil and NS.lastExpedition.deaths == 1

	E.Reset()
	E.Depart()
	Mock.world.xp = 150; Mock:Fire("PLAYER_XP_UPDATE", "player")
	E.Return(10)
	Check("[EXP] voyage court avec une mort ou de l'XP : bilan", death and NS.lastExpedition ~= nil and NS.lastExpedition.xp == 50)

	-- long et calme : bilan (la durée suffit)
	E.Reset()
	E.Depart()
	E.Return(300)
	Check("[EXP] voyage long sans événement : bilan", NS.lastExpedition ~= nil)
end

-- 4. Réglages -------------------------------------------------------------------
do
	E.Reset()
	NS:DB().expeditionMinTrip = 600
	E.Depart(); E.Return(300)
	Check("[EXP] seuil 600 s : voyage calme de 300 s ignoré", NS.lastExpedition == nil)

	E.Reset()
	NS:DB().expeditionMinTrip = 0
	E.Depart(); E.Return(5)
	Check("[EXP] seuil 0 : même un voyage éclair a son bilan", NS.lastExpedition ~= nil)

	E.Reset()
	NS:DB().expeditionChat = true
	NS:DB().expeditionWindow = false
	E.FullTrip()
	local out = E.Output()
	local count = 0
	for _ in out:gmatch("Retour d'expédition %(") do count = count + 1 end
	Check("[EXP] mode chat : une seule ligne (durée, XP, argent, butin, morts, usure, quêtes), pas de fenêtre", count == 1
		and E.Has(out, "Retour d'expédition (12 min 34) : ")
		and E.Has(out, "+950 XP, +1 niveau(x), +3 pa, ") and E.Has(out, GREEN .. "x2")
		and E.Has(out, "2 mort(s)") and E.Has(out, "usure -35 pts") and E.Has(out, "1 quête(s) à rendre")
		and NS.expeditionFrame == nil, out)

	E.Reset()
	NS:DB().expeditionChat = true
	E.FullTrip()
	Check("[EXP] chat et fenêtre ensemble", NS.expeditionFrame and NS.expeditionFrame.shown
		and E.Has(E.Output(), "Retour d'expédition ("))

	-- le Check avant le départ coupé : bilan quand même, sans liste à racheter
	E.Reset()
	NS:DB().departureEnabled = false
	E.FullTrip()
	Check("[EXP] départ coupé : bilan quand même, rien à racheter", NS.lastExpedition ~= nil and #NS.lastExpedition.restock == 0)

	-- contrôle « vivres » coupé : il ne figure pas dans « à racheter »
	E.Reset()
	NS:SetModuleEnabled("vivres", false)
	E.FullTrip()
	Check("[EXP] contrôle coupé : absent de « à racheter »", NS.lastExpedition and #NS.lastExpedition.restock == 0)
end

-- 5. Module coupé ---------------------------------------------------------------
do
	E.Reset()
	NS:DB().expeditionEnabled = false
	E.FullTrip()
	Check("[EXP] module coupé : rien suivi, rien affiché", NS.expedition == nil and NS.lastExpedition == nil
		and NS.expeditionFrame == nil and not E.Has(E.Output(), "Retour d'expédition ("))

	-- coupé pendant le voyage
	E.Reset()
	E.Depart()
	Mock:Fire("PLAYER_DEAD")
	NS:HandleCommand("module expedition off")
	local off = NS:DB().expeditionEnabled == false
	E.Return(300)
	Check("[EXP] /r2q module expedition off en route : pas de bilan", off and NS.lastExpedition == nil and NS.expedition == nil)
	NS:HandleCommand("module retour on")
	Check("[EXP] alias « retour » : rallumé", NS:DB().expeditionEnabled == true)

	Mock:Reset()
	NS:HandleCommand("modules")
	Check("[EXP] /r2q modules liste le module", E.Has(E.Output(), "expedition") and E.Has(E.Output(), NS.L.OPT_PAGE_EXPEDITION), E.Output())

	-- l'addon entier coupé
	E.Reset()
	NS:DB().enabled = false
	E.FullTrip()
	Check("[EXP] addon coupé : pas de bilan", NS.lastExpedition == nil)
end

-- 6. Page de réglages -------------------------------------------------------------
do
	E.Reset()
	NS.optionsFrame = nil
	NS:ToggleOptions()
	local o = NS.optionsFrame
	local nav, page
	for _, button in ipairs(o.navButtons) do if button.pageId == "expedition" then nav = button end end
	page = o.pages.expedition
	Check("[EXP] page avec interrupteur, rangée avant Marchand, trois réglages", nav ~= nil and nav.powerKey == "expeditionEnabled"
		and page ~= nil and page.subText == NS.L.OPT_PAGE_EXPEDITION_SUB and #page.rows == 3 and (function()
		local seen
		for _, def in ipairs(NS.OPTION_PAGES) do
			if def.id == "expedition" then seen = true end
			if def.id == "merchant" then return seen == true end
		end
	end)(), page and #page.rows)
	if nav then
		nav.power:Click()
		local off = NS:DB().expeditionEnabled == false
		nav.power:Click()
		Check("[EXP] interrupteur : coupe puis rallume", off and NS:DB().expeditionEnabled == true)
	end
	local minRow
	for _, row in ipairs(page and page.rows or {}) do if row.def.key == "expeditionMinTrip" then minRow = row end end
	if minRow then
		minRow:Step(1)
		Check("[EXP] seuil réglable par pas de 30 s", NS:DB().expeditionMinTrip == 90, NS:DB().expeditionMinTrip)
	end
	o:Hide()
	NS.optionsFrame = nil
end

-- 7. Robustesse : API absentes, motifs de butin -------------------------------
do
	E.Reset()
	_G.UnitXP = nil
	_G.GetInventoryItemDurability = nil
	local ok, err = pcall(function()
		E.Depart()
		Mock:Fire("PLAYER_XP_UPDATE", "player")
		Mock:Fire("PLAYER_DEAD")
		E.Return(120)
	end)
	Check("[EXP] sans UnitXP ni durabilité : pas d'erreur", ok, err)
	local r = NS.lastExpedition
	Check("[EXP] sans API : bilan partiel, pas de ligne usure", r ~= nil and r.xp == 0 and r.duraLost == 0
		and r.durability == nil and NS.expeditionFrame and (function()
		for index = 1, NS.expeditionFrame.visibleLines do
			if NS.expeditionFrame.lines[index].name.text == NS.L.EXP_ROW_DURA then return false end
		end
		return true
	end)())
	_G.UnitXP = function() return Mock.world.xp or 0 end
	_G.GetInventoryItemDurability = saved.GetInventoryItemDurability

	-- globales de butin absentes : motifs de repli (fr / en)
	_G.LOOT_ITEM_SELF, _G.LOOT_ITEM_SELF_MULTIPLE, _G.LOOT_ITEM_PUSHED_SELF = nil, nil, nil
	local link, count = NS:ParseSelfLoot("You receive loot: " .. BLUE .. "x3.")
	local fr = NS:ParseSelfLoot("Vous recevez le butin : " .. GREEN .. ".")
	Check("[EXP] motifs de repli anglais (lien et quantité) et français", link == BLUE and count == 3 and fr == GREEN,
		tostring(link) .. " " .. tostring(count))
	-- forme positionnelle (%1$s) de certaines langues
	_G.LOOT_ITEM_SELF = "Beute: %1$s."
	link = NS:ParseSelfLoot("Beute: " .. GREEN .. ".")
	Check("[EXP] format positionnel %1$s ; autre joueur et message sans lien ignorés", link == GREEN
		and NS:ParseSelfLoot("Bob: " .. GREEN .. ".") == nil and NS:ParseSelfLoot("Vous recevez le butin : rien.") == nil)
	_G.LOOT_ITEM_SELF = "Vous recevez le butin : %s."
	_G.LOOT_ITEM_SELF_MULTIPLE = "Vous recevez le butin : %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "Vous recevez l'objet : %s."

	-- hors voyage, les événements ne comptent rien
	E.Reset()
	Mock:Fire("PLAYER_DEAD")
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. GREEN .. ".")
	Check("[EXP] hors voyage : rien n'est compté", NS.expedition == nil)

	Check("[EXP] durées : secondes, minutes, heures",
		NS:FormatTripDuration(45) == "45 s" and NS:FormatTripDuration(754) == "12 min 34" and NS:FormatTripDuration(3720) == "1 h 02",
		NS:FormatTripDuration(3720))
end

for key, value in pairs(saved) do _G[key] = value end
E.Reset()
