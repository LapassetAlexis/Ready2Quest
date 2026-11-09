-- QuestCompanion 2.11.2 / Ready2Quest 1.32.2 (fiche 28) : test de garde des
-- couleurs et des textes en dur. Une couleur n'est écrite qu'à un endroit :
-- jetons du socle (Theme.*, ns.TC), encres Azeroth (ns.AZEROTH_INK,
-- ns.AZEROTH_BUTTONS, ns.AZEROTH_COLORS), ou constante nommée en capitales
-- (local NOM = { … }, ns.NOM = { … }) quand la valeur diffère d'un jeton.
-- Le test lit les sources (io.open) de tous les modules des .toc ; les
-- exceptions sont listées plus bas, avec la raison.
local Check, Say, NS, QNS = T.Check, T.Say, T.NS, T.QNS
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function ReadFile(path)
	local h = io.open(ROOT .. "/" .. path, "rb")
	if not h then return nil end
	local data = h:read("*a")
	h:close()
	return data
end

Say("-- fiche 28 : test de garde (couleurs et textes en dur)")

-- Tous les modules des deux addons (et la source du socle) sont lus, sauf
-- ceux de la liste blanche : fichier → raison. Le socle de QuestCompanion
-- est une copie (identité vérifiée par run_tests.py).
local ALLOWED = {
	["Ready2Quest/Libs/Socle/Theme.lua"] = "c'est la palette elle-même (jetons, briques)",
	["QuestCompanion/CompanionData.lua"] = "données : fonds, habits, cosmétiques du compagnon",
	["QuestCompanion/MenagerieCollection.lua"] = "données : teintes des collections",
	["QuestCompanion/FeatsCosmetics.lua"] = "données : lueur du feu de camp (feat_campfire)",
	["QuestCompanion/Companion.lua"] = "ornements fleur/cristal, lumière du modèle, fond « night » : "
		.. "données du compagnon, à déplacer dans CompanionData.lua",
	["Ready2Quest/Libs/Socle/Compat.lua"] = "« client = » du diagnostic, identique en FR et en EN",
	["QuestCompanion/Config.lua"] = "chargé avant le socle (ni ns.TC ni ns.L)",
}
local CLEAN, seen = {}, {}
-- la liste des fichiers : celle des deux .toc (le socle de QuestCompanion
-- est lu dans sa source)
for _, addon in ipairs({ "Ready2Quest", "QuestCompanion" }) do
	for line in (ReadFile(addon .. "/" .. addon .. ".toc") or ""):gmatch("[^\r\n]+") do
		local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
		if file then
			file = file:gsub("\\", "/")
			local path = file:match("^Libs/Socle/") and ("Ready2Quest/" .. file) or (addon .. "/" .. file)
			if not seen[path] and not ALLOWED[path] then seen[path] = true; CLEAN[#CLEAN + 1] = path end
		end
	end
end
Check("[HYG] modules lus (les deux addons et le socle)", #CLEAN >= 80, tostring(#CLEAN))

-- appel de couleur avec trois nombres littéraux (sauf la remise à blanc 1, 1, 1, 1)
local CALLS = { "SetVertexColor", "SetTextColor", "SetShadowColor", "SetColor", "SetColorTexture" }
local NUM = "%-?[%d%.]+"
local function LiteralCall(code)
	for _, name in ipairs(CALLS) do
		local start = 1
		while true do
			local a, b, r, g, bl = code:find(name .. "%(%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")", start)
			if not a then break end
			local rest = code:sub(b + 1)
			local reset = r == "1" and g == "1" and bl == "1" and rest:match("^%s*,%s*1%s*%)")
			if not reset then return true end
			start = b + 1
		end
	end
	return false
end
-- table { r, g, b… } de nombres littéraux entre 0 et 1 (une couleur ; une
-- liste de paliers { 10, 20, 30 } n'en est pas une)
local function LiteralTable(code)
	local start = 1
	while true do
		local a, b, x, y, z = code:find("{%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")%s*[,}]", start)
		if not a then return false end
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		if x and y and z and x >= 0 and x <= 1 and y >= 0 and y <= 1 and z >= 0 and z <= 1 then return true end
		start = b
	end
end
-- déclaration d'une constante nommée (en capitales) : local NOM = …, ns.NOM = …, Theme.NOM = …
local function NamedConstant(code)
	return code:match("^%s*local%s+[A-Z][A-Z0-9_]*[%s,%w_]*=") or code:match("^%s*ns%.[A-Z][A-Z0-9_]*[%.%w_]*%s*=")
		or code:match("^%s*Theme%.[A-Z][A-Z0-9_]*%s*=")
end
local function Depth(code)
	local _, open = code:gsub("{", "")
	local _, close = code:gsub("}", "")
	return open - close
end

local function Scan(src)
	local colours, prints = {}, {}
	local depth, n = 0, 0
	for line in (src .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		local code = line:gsub("%-%-.*$", "")
		local allowed = depth > 0 or NamedConstant(code)
		if not allowed and (LiteralCall(code) or LiteralTable(code)) then
			colours[#colours + 1] = n .. ": " .. code:gsub("^%s+", "")
		end
		-- texte affiché en dur : print("…lettres…") / :Print("…lettres…")
		if code:find("[%.:]?[Pp]rint%(%s*\"[^\"]*%a") then prints[#prints + 1] = n .. ": " .. code:gsub("^%s+", "") end
		if depth > 0 then
			depth = math.max(0, depth + Depth(code))
		elseif NamedConstant(code) then
			depth = math.max(0, Depth(code))
		end
	end
	return colours, prints
end

local colourDirty, printDirty = {}, {}
for _, path in ipairs(CLEAN) do
	local src = ReadFile(path)
	if not src then
		colourDirty[#colourDirty + 1] = path .. " (introuvable)"
	else
		local colours, prints = Scan(src)
		for _, hit in ipairs(colours) do colourDirty[#colourDirty + 1] = path .. ":" .. hit end
		for _, hit in ipairs(prints) do printDirty[#printDirty + 1] = path .. ":" .. hit end
	end
end
Check("[HYG] couleurs : aucune valeur numérique hors jeton ou constante nommée", #colourDirty == 0,
	table.concat(colourDirty, " / "))
Check("[HYG] textes : aucun print littéral dans les modules", #printDirty == 0, table.concat(printDirty, " / "))

-- le garde mord : une ligne fautive ajoutée est vue
local probeC = select(1, Scan("local x = 1\nfs:SetTextColor(1, 0, 0)\n"))
local probeT = select(1, Scan("Theme.Solid(f, \"BACKGROUND\", { 0.2, 0.3, 0.4 }, 1)\n"))
local probeOk = select(1, Scan("tex:SetVertexColor(1, 1, 1, 1)\nlocal NAMED = { 0.2, 0.3, 0.4 }\nns.X = {\n\ta = { 0.1, 0.2, 0.3 },\n}\n"))
local _, probeP = Scan("ns:Print(\"bonjour\")\n")
Check("[HYG] le garde mord (couleur, table, print) et laisse passer remise à blanc et constantes",
	#probeC == 1 and #probeT == 1 and #probeOk == 0 and #probeP == 1)

-- aucun |cff écrit à la main dans les modules : seuls Base.lua (ns.TC) et
-- Config.lua (avant le socle) en portent. Allow-list : fichier → raison.
local CFF_ALLOWED = {
	["Ready2Quest/Libs/Socle/Base.lua"] = "déclare ns.TC",
	["QuestCompanion/Libs/Socle/Base.lua"] = "copie du socle",
	["Ready2Quest/Config.lua"] = "chargé avant le socle",
	["QuestCompanion/Config.lua"] = "chargé avant le socle",
}
local cffFiles = {}
for _, path in ipairs(CLEAN) do
	local src = ReadFile(path) or ""
	for line in src:gmatch("[^\n]+") do
		local code = line:gsub("%-%-.*$", "")
		if not CFF_ALLOWED[path] and code:find("|cff%x%x%x%x%x%x") then cffFiles[#cffFiles + 1] = path end
	end
end
Check("[HYG] aucun |cff en dur dans les modules", #cffFiles == 0, table.concat(cffFiles, ", "))

-- jetons du socle (fiche 28, 2.11.2)
Check("[HYG] jetons du socle : ombre, voiles, brillante", Theme.SHADOW and Theme.SHADOW[1] == 0
	and Theme.SHADE and Theme.SHADE.strong == 0.8 and Theme.SHADE.mid == 0.45
	and Theme.SHINY and Theme.SHINY[2] == 0.89 and type(Theme.TextShadow) == "function")
do
	local fs = { calls = {} }
	function fs:SetShadowColor(r, g, b, a) self.color = { r, g, b, a } end
	function fs:SetShadowOffset(x, y) self.offset = { x, y } end
	Theme.TextShadow(fs)
	local plain = fs.color[4] == 1 and fs.offset[1] == 1 and fs.offset[2] == -1
	Theme.TextShadow(fs, 0.6, -2)
	Check("[HYG] Theme.TextShadow : noir (1, -1) opaque, alpha et décalage au choix", plain
		and fs.color[4] == 0.6 and fs.offset[2] == -2)
end
local QINK, BTN = QNS and QNS.AZEROTH_INK, QNS and QNS.AZEROTH_BUTTONS
Check("[HYG] palette unique des boutons Azeroth (capture et carnet)", BTN and QNS.AZEROTH_BUTTON_SKINS
	and QNS.AZEROTH_BUTTON_SKINS.gold == BTN.gold and QNS.CARNET_BUTTONS and QNS.CARNET_BUTTONS.red == BTN.red)
Check("[HYG] carnet : encres lues dans AZEROTH_INK", QINK and QNS.CARNET_COLORS
	and QNS.CARNET_COLORS.gold == QINK.goldHead and QNS.CARNET_COLORS.light == QINK.light
	and QNS.CARNET_COLORS.catGold == QINK.catGold and QNS.CARNET_COLORS.green == QINK.barGreen)
Check("[HYG] scène de capture : teintes partagées (CAPTURE_FX_COLORS)", QNS and QNS.CAPTURE_FX_COLORS
	and QNS.CAPTURE_FX_COLORS.white == QNS.Theme.WHITE and QNS.CAPTURE_FX_COLORS.fledName[1] == 0.7)
