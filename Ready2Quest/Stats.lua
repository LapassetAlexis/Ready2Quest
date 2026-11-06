-- Stats.lua -- résumé éphémère de changement d'équipement + stats du portrait
--
-- Les valeurs dérivées sont recalculées à partir des API du client :
--   UnitDamage       -> plage de dégâts main droite
--   UnitAttackSpeed  -> vitesse d'attaque
--   UnitArmor        -> armure, et réduction via armure / (armure + 85*niv + 400)
--   UnitStat         -> Force / Agilité / Endurance / Intelligence
--   UnitAttackPower  -> puissance d'attaque
--   GetCritChance / GetHaste -> si le client les expose
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local TOAST_SECONDS = 6
local EPSILON = 0.05

-- ---------------------------------------------------------------------------
-- Lecture des statistiques
-- ---------------------------------------------------------------------------
-- Appelle une API en renvoyant jusqu'à quatre valeurs de retour
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d
end

function ns:DamageReduction(armor, level)
	armor = tonumber(armor) or 0
	level = tonumber(level) or 60
	if armor <= 0 then return 0 end
	local denominator = armor + (85 * level) + 400
	if denominator <= 0 then return 0 end
	return (armor / denominator) * 100
end

-- Nombre lisible : une valeur secrète (moteur 12.0) compte comme absente
local function Num(value)
	return tonumber(ns.Plain(value))
end

-- Valeur d'une stat pour le relevé. Secrète (moteur 12.0) : 0, mais notée
-- dans snapshot.secret, pour ne pas la comparer (un faux « −500 Force »)
local function Stat(snapshot, key, value)
	if value ~= nil and ns.Plain(value) == nil then
		snapshot.secret[key] = true
		return 0
	end
	return tonumber(value) or 0
end

function ns:StatSnapshot()
	local snapshot = { secret = {} }
	local unitLevel = Call(UnitLevel, "player")
	local level = Num(unitLevel) or 60
	snapshot.level = level

	-- toujours passer par une locale : jamais un appel en argument de tonumber()
	local strength = Call(UnitStat, "player", 1)
	local agility = Call(UnitStat, "player", 2)
	local stamina = Call(UnitStat, "player", 3)
	local intellect = Call(UnitStat, "player", 4)
	snapshot.str = Stat(snapshot, "str", strength)
	snapshot.agi = Stat(snapshot, "agi", agility)
	snapshot.sta = Stat(snapshot, "sta", stamina)
	snapshot.int = Stat(snapshot, "int", intellect)

	-- UnitArmor(unit) -> base, effective, attackPower, damage
	local _, armorEffective = Call(UnitArmor, "player")
	snapshot.armor = Stat(snapshot, "armor", armorEffective)
	snapshot.reduction = self:DamageReduction(snapshot.armor, level)

	-- Esprit : 5e statistique primaire (UnitStat 5). Elle manquait au relevé,
	-- alors que c'est la statistique principale de certaines spécialisations.
	local spirit = Call(UnitStat, "player", 5)
	snapshot.spi = Stat(snapshot, "spi", spirit)

	-- UnitDamage(unit) -> min main, max main, mod, ...
	local dmgMin, dmgMax = Call(UnitDamage, "player")
	snapshot.dmgMin = Stat(snapshot, "dmgMin", dmgMin)
	snapshot.dmgMax = Stat(snapshot, "dmgMax", dmgMax)

	-- UnitAttackSpeed(unit) -> main, off : ne JAMAIS passer l'appel directement
	-- à tonumber(), le 2e retour deviendrait l'argument « base ».
	local speedMain = Call(UnitAttackSpeed, "player")
	snapshot.speed = Stat(snapshot, "speed", speedMain)
	if snapshot.secret.speed or snapshot.secret.dmgMin or snapshot.secret.dmgMax then snapshot.secret.dps = true end
	if snapshot.speed > 0 then
		snapshot.dps = ((snapshot.dmgMin + snapshot.dmgMax) / 2) / snapshot.speed
	else
		snapshot.dps = 0
	end

	-- UnitAttackPower(unit) -> base, posBuff, negBuff (trois retours seulement).
	-- La PA venue de l'équipement est dans posBuff : la PA réelle est la somme.
	local apBase, apPos, apNeg = Call(UnitAttackPower, "player")
	snapshot.ap = Stat(snapshot, "ap", apBase) + Stat(snapshot, "ap", apPos) + Stat(snapshot, "ap", apNeg)

	local crit = Call(GetCritChance)
	snapshot.crit = Stat(snapshot, "crit", crit)
	local haste = Call(GetHaste)
	snapshot.haste = Stat(snapshot, "haste", haste)

	local avg, equipped = Call(GetAverageItemLevel)
	snapshot.ilvl = Num(equipped) or Num(avg) or 0
	-- Era : GetAverageItemLevel peut manquer, on calcule depuis l'équipement
	if snapshot.ilvl <= 0 and self.AverageItemLevel then
		snapshot.ilvl = Num(self:AverageItemLevel()) or 0
	end

	-- Liens équipés, pour repérer l'emplacement modifié
	snapshot.slots = {}
	for slot = 1, 19 do
		snapshot.slots[slot] = ns.ItemLinkForSlot and ns.ItemLinkForSlot(slot) or nil
	end

	return snapshot
end

-- ---------------------------------------------------------------------------
-- Comparaison de deux relevés
--   higherIsBetter = false pour la vitesse d'attaque (plus court = mieux)
-- ---------------------------------------------------------------------------
local COMPARED = {
	{ key = "dmgMin", label = "DMG_MIN", kind = "range", polarity = true },
	{ key = "dmgMax", label = "DMG_MAX", kind = "hidden", polarity = true },
	{ key = "dps", label = "DPS", kind = "decimal", polarity = true },
	{ key = "speed", label = "SPEED", kind = "seconds", polarity = false },
	{ key = "armor", label = "ARMOR", kind = "integer", polarity = true },
	{ key = "ap", label = "ATTACK_POWER", kind = "integer", polarity = true },
	{ key = "str", label = "STR", kind = "integer", polarity = true },
	{ key = "agi", label = "AGI", kind = "integer", polarity = true },
	{ key = "int", label = "INT", kind = "integer", polarity = true },
	{ key = "sta", label = "STA", kind = "integer", polarity = true },
	{ key = "spi", label = "SPI", kind = "integer", polarity = true },
	{ key = "crit", label = "CRIT", kind = "decimal", polarity = true },
	{ key = "haste", label = "HASTE", kind = "decimal", polarity = true },
}

function ns:DiffSnapshots(before, after)
	local rows = {}
	if type(before) ~= "table" or type(after) ~= "table" then return rows end

	local secretBefore = type(before.secret) == "table" and before.secret or {}
	local secretAfter = type(after.secret) == "table" and after.secret or {}
	for _, def in ipairs(COMPARED) do
		-- une valeur secrète d'un côté ou de l'autre : pas de comparaison
		if def.kind ~= "hidden" and not secretBefore[def.key] and not secretAfter[def.key] then
			local old = tonumber(before[def.key]) or 0
			local new = tonumber(after[def.key]) or 0
			local delta = new - old
			if math.abs(delta) > EPSILON then
				rows[#rows + 1] = {
					key = def.key,
					label = def.label,
					kind = def.kind,
					polarity = def.polarity,
					delta = delta,
					old = old,
					new = new,
				}
			end
		end
	end

	return rows
end

local function FormatValue(kind, value)
	if kind == "decimal" then return string.format("%.1f", value) end
	if kind == "seconds" then return string.format("%.2f s", value) end
	if kind == "percent" then return string.format("%.1f %%", value) end
	return tostring(math.floor(value + 0.5))
end

local function FormatDelta(kind, delta)
	local sign = delta > 0 and "+" or ""
	if kind == "decimal" then return sign .. string.format("%.1f", delta) end
	if kind == "seconds" then return sign .. string.format("%.2f s", delta) end
	if kind == "percent" then return sign .. string.format("%.1f %%", delta) end
	return sign .. tostring(math.floor(delta + (delta >= 0 and 0.5 or -0.5)))
end
ns.FormatStatDelta = FormatDelta

-- ---------------------------------------------------------------------------
-- Résumé éphémère
-- ---------------------------------------------------------------------------
-- Mise en page relevée sur la maquette de référence :
--
--   S T A T I S T I Q U E S                      <- titre espacé, petit et gris
--   ───────────────────────────────────────────  <- règle continue, or pâle
--   [icône] ▼ -12        DÉGÂTS                  <- valeur colorée à gauche,
--   [icône] ▼ -0,60 s    VITESSE D'ATTAQUE        libellé aligné à droite
--
-- Pas de cadre, pas de fond : deux colonnes de texte et une règle, l'ombre
-- portée suffit à les détacher du décor.
-- Une seule ligne par changement d'équipement : on montre la statistique la
-- plus parlante, pas un tableau. Les autres écarts sont calculés mais pas
-- affichés, pour que le bloc reste lisible d'un coup d'oeil.
local TOAST_ROWS = 1
local TOAST_WIDTH = 190         -- largeur du bloc, resserrée avec les colonnes
local TOAST_ICON = 14
local TOAST_ICON_GAP = 3
local TOAST_VALUE_LEFT = 20     -- après l'icône (14 + 6 de marge)
-- Colonnes resserrées après mesure en jeu : l'ancien écart (valeur à 20,
-- libellés à 84) laissait 64 px de vide entre le chiffre et la flèche, et le
-- bloc paraissait étiré.
-- Valeurs les plus longues mesurées en jeu : « +8 » finit à 30, « -0,60 s »
-- à environ 60 (l'ancien écart libellé-à-84 laissait donc 24 px de vide).
-- La flèche démarre à 62, le libellé à 76 : 8 px gagnés, sans chevauchement
-- possible puisque la valeur n'atteint jamais 62.
local TOAST_ARROW_LEFT = 62     -- flèche, après la valeur la plus longue
local TOAST_LABEL_LEFT = 76     -- colonne des libellés
local TOAST_ARROW_GAP = 4
-- Largeur du contenu le plus large, en unités 1920 : icône (14) jusqu'à la fin
-- du libellé le plus long (« Vitesse D'attaque » ≈ 105 depuis x=76, soit 181).
-- C'est cette largeur qu'on centre dans la règle, pas le bloc entier : sinon
-- le contenu reste collé à gauche et le vide s'accumule à droite.
local TOAST_CONTENT_LEFT = 0
local TOAST_CONTENT_WIDTH = 181
local TOAST_TITLE_Y = -6
local TOAST_RULE_Y = -22
local TOAST_ROW_TOP = -30
local TOAST_ROW_STEP = 14
-- Centrage vertical sur la ligne de texte. Une fontstring ancrée en TOPLEFT
-- pend sous son point d'ancrage : sa hauteur réelle (14) dépasse la hauteur
-- des chiffres (8). On centre donc l'icône et la flèche sur le milieu du corps
-- du texte, au lieu de les aligner sur le haut de la ligne.
local TOAST_TEXT_HEIGHT = 8     -- hauteur des chiffres, mesurée en jeu
-- Une fontstring ancrée en TOPLEFT descend sous son point d'ancrage : son
-- milieu est à TOAST_TEXT_HEIGHT / 2 EN DESSOUS du haut de ligne, donc en
-- coordonnées négatives. On mémorise ce décalage, puis on retire encore la
-- moitié de la hauteur de l'élément pour que les deux milieux coïncident.
local TOAST_LINE_MIDDLE = -TOAST_TEXT_HEIGHT / 2
-- Flèches en ASCII pur. Les polices du client n'embarquent PAS les blocs
-- Unicode au-delà de l'alphabet latin : ni triangle U+25BC, ni lettres
-- grecques U+03BB/U+03B1. Mesure faite sur le cache de glyphes du client
-- (Fonts\615960.slug, police « Friz Quadrata TT ») : les codepoints
-- enregistrés s'arrêtent à 0xCA. Tout caractère au-delà sort en case vide.
-- Les fleches sont des textures livrees avec l'addon, pas des caracteres :
-- la police du client s'arrete au latin et aucun glyphe de fleche ne s'affiche
-- (constate trois fois : triangle, lettre grecque, tous en carre vide).
-- chemin construit depuis le nom réel du dossier : un renommage ne casse plus les flèches
local ARROW_DOWN = ns.Theme.MEDIA .. "Textures\\fleche_baisse"
local ARROW_UP   = ns.Theme.MEDIA .. "Textures\\fleche_hausse"
local ARROW_SIZE = 10           -- cote de la fleche, en unites 1920
-- fond du bandeau autour du cadre (gauche, haut, droite, bas), en unités
-- 1920 : le contenu (titre à -6, ligne jusqu'à -44) y tient avec sa marge
local TOAST_PLATE = { 14, 8, 12, 50 }
ns.TOAST_PLATE = TOAST_PLATE

-- Exposées pour les tests : la géométrie du bloc est vérifiable sans client.
ns.TOAST_WIDTH = TOAST_WIDTH
ns.TOAST_VALUE_LEFT = TOAST_VALUE_LEFT
ns.TOAST_LABEL_LEFT = TOAST_LABEL_LEFT
ns.TOAST_ARROW_GAP = TOAST_ARROW_GAP
ns.TOAST_ARROW_LEFT = TOAST_ARROW_LEFT
ns.TOAST_CONTENT_WIDTH = TOAST_CONTENT_WIDTH
ns.TOAST_ICON = TOAST_ICON
ns.TOAST_TEXT_HEIGHT = TOAST_TEXT_HEIGHT
ns.TOAST_ROW_TOP = TOAST_ROW_TOP
ns.TOAST_LINE_MIDDLE = TOAST_LINE_MIDDLE
ns.ARROW_SIZE = ARROW_SIZE

-- Échelle du client. La maquette de référence fait 264 px de large sur un
-- écran de 1920 de côté ; les distances ci-dessus sont exprimées en unités
-- d'interface 1920. Sur un client qui expose UIParent:GetWidth(), on convertit ;
-- sinon on affiche tel quel.
local REFERENCE_WIDTH = 1920
local function Factor()
	local ok, width = pcall(function()
		local f = UIParent
		if not f or not f.GetWidth then return nil end
		return f:GetWidth()
	end)
	if ok and type(width) == "number" and width > 0 then
		return width / REFERENCE_WIDTH
	end
	return 1
end

-- Interlettrage du titre. Une espace littérale entre chaque lettre (la
-- méthode employée en 1.10.0) épaissit le texte et sature la ligne ; le client
-- expose un réglage natif. On ne retombe sur les espaces que s'il manque.
local TITLE_GAP = " "
local function SpacedTitle(text)
	if type(text) ~= "string" or text == "" then return text end
	local letters = {}
	for index = 1, #text do
		letters[#letters + 1] = text:sub(index, index)
	end
	return table.concat(letters, TITLE_GAP)
end
ns.SpacedTitle = SpacedTitle

-- Capitalise la première lettre de chaque mot : « armure » -> « Armure »,
-- « vitesse d'attaque » -> « Vitesse D'attaque ». L'apostrophe ne crée pas de
-- nouveau mot, sinon « D'Attaque » n'aurait pas de sens en français.
--
-- Les caractères accentés occupent deux octets en UTF-8 : on ne touche donc
-- JAMAIS aux octets de continuation (>= 0x80), sinon string.upper les corrompt
-- et affiche « DégÃ¢ts ».
local function PascalCase(text)
	if type(text) ~= "string" or text == "" then return text end
	local out = {}
	local atWordStart = true
	local index = 1
	local length = #text
	-- boucle while : en Lua 5.1 la variable d'un « for » ne peut pas être avancée
	while index <= length do
		local byte = string.byte(text, index)
		if byte >= 128 then
			-- début d'un caractère multi-octets : on recopie la séquence telle quelle
			local size = 1
			if byte >= 240 then size = 4
			elseif byte >= 224 then size = 3
			elseif byte >= 192 then size = 2 end
			out[#out + 1] = text:sub(index, index + size - 1)
			index = index + size
		else
			local char = text:sub(index, index)
			if char:match("%a") then
				out[#out + 1] = atWordStart and string.upper(char) or string.lower(char)
				atWordStart = false
			else
				out[#out + 1] = char
				if char ~= "'" then atWordStart = true end
			end
			index = index + 1
		end
	end
	return table.concat(out)
end

ns.PascalCase = PascalCase

-- Texture de l'objet équipé dans l'emplacement : d'abord le lien, par
-- ns.ItemInfo (10e retour), enfin l'API d'emplacement. Nil si aucune ne
-- répond : l'icône reste alors simplement vide.
local function SlotTexture(link, slot, previousLink)
	-- Retirer un item doit quand même montrer SON icône : c'est le repère
	-- visuel de la ligne. On essaie donc le lien actuel, puis le lien
	-- précédent (celui qui vient d'être enlevé), puis l'emplacement.
	local candidates = { link }
	if type(previousLink) == "string" then candidates[#candidates + 1] = previousLink end
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "string" then
			local texture = select(10, ns.ItemInfo(candidate))
			if texture then return texture end
		end
	end
	if slot and type(GetInventoryItemTexture) == "function" then
		local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
		if ok and texture then return texture end
	end
	return nil
end

function ns:EnsureToast()
	if self.toastFrame then return self.toastFrame end

	local factor = Factor()

	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(TOAST_WIDTH * factor, 10)
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(false)
	frame:SetMovable(true)
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
	if frame.StartMoving then frame:SetScript("OnDragStart", frame.StartMoving) end
	if frame.StopMovingOrSizing then frame:SetScript("OnDragStop", frame.StopMovingOrSizing) end

	ns:RestorePoint(frame, "toastPoint", { point = "CENTER", x = 0, y = -170 })
	-- habillage de bandeau (docs/UI.md) : fond WINDOW, filet EDGE, liseré
	-- ambre. Le cadre garde sa hauteur de 10 (position sauvegardée, zone de
	-- saisie en édition) : le fond déborde autour du titre et de la ligne.
	Theme.SkinToast(frame, { outset = { TOAST_PLATE[1] * factor, TOAST_PLATE[2] * factor,
		TOAST_PLATE[3] * factor, TOAST_PLATE[4] * factor } })
	-- décalage qui centre le contenu le plus large dans la largeur du bloc :
	-- calculé avant toute création de région, elles en dépendent toutes.
	local inset = ((TOAST_WIDTH - TOAST_CONTENT_WIDTH) / 2) - TOAST_CONTENT_LEFT


	-- Même corps de police que les lignes : c'est l'interlettrage et la teinte
	-- qui distinguent le titre, pas la taille. Un corps plus petit décalait le
	-- rythme vertical du bloc, alors que les deux font 14 px sur la référence.
	frame.title = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", inset * factor, TOAST_TITLE_Y * factor)
	frame.title:SetJustifyH("LEFT")
	frame.title:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3], 0.70)
	-- interlettrage natif si le client le propose (aucun repli requis : le
	-- texte reste juste, simplement plus serré)
	if frame.title.SetNonSpaceGlyphSpacing then
		frame.title:SetNonSpaceGlyphSpacing(2)
	end

	-- ombre portée sur chaque texte : la ligne reste lisible par-dessus le décor
	local function AddShadow(fontString)
		if fontString.SetShadowColor then
			fontString:SetShadowColor(0, 0, 0, 1)
			fontString:SetShadowOffset(1, -1)
		end
	end
	AddShadow(frame.title)

	frame.rule = frame:CreateTexture(nil, "ARTWORK")
	frame.rule:SetTexture(Theme.SOLID)
	frame.rule:SetVertexColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
	frame.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, TOAST_RULE_Y * factor)
	frame.rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, TOAST_RULE_Y * factor)
	frame.rule:SetHeight(1)

	frame.rows = {}
	for index = 1, TOAST_ROWS do
		local y = (TOAST_ROW_TOP - ((index - 1) * TOAST_ROW_STEP)) * factor

		-- y est le haut de la ligne. Le milieu du texte est SOUS ce haut : une
		-- fontstring ancrée en TOPLEFT pend sous son point d'ancrage. On ancre
		-- donc l'icône et la flèche en CENTER sur ce milieu, ce qui rend le
		-- résultat indépendant du sens des décalages entre textes et textures.
		local lineMiddle = y + TOAST_LINE_MIDDLE * factor

		local icon = frame:CreateTexture(nil, "ARTWORK")
		icon:SetSize(TOAST_ICON * factor, TOAST_ICON * factor)
		icon:SetPoint("CENTER", frame, "TOPLEFT", (inset + TOAST_ICON / 2) * factor, lineMiddle)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		icon:Hide()

		local value = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		value:SetPoint("TOPLEFT", frame, "TOPLEFT",
			(inset + TOAST_VALUE_LEFT + TOAST_ICON_GAP) * factor, y)
		value:SetJustifyH("LEFT")
		AddShadow(value)

		local label = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		label:SetPoint("TOPLEFT", frame, "TOPLEFT", (inset + TOAST_LABEL_LEFT) * factor, y)
		label:SetJustifyH("LEFT")
		label:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
		AddShadow(label)

		-- fleche : ancre CENTER aussi, meme milieu que l'icone et les chiffres
		local arrow = frame:CreateTexture(nil, "ARTWORK")
		arrow:SetSize(ARROW_SIZE * factor, ARROW_SIZE * factor)
		arrow:SetPoint("CENTER", frame, "TOPLEFT",
			(inset + TOAST_ARROW_LEFT + ARROW_SIZE / 2) * factor, lineMiddle)
		arrow:Hide()

		frame.rows[index] = { icon = icon, value = value, label = label, arrow = arrow }
	end

	-- Repère du mode édition : le fond s'éclaire d'ambre (sous le texte)
	frame.moveGlow = Theme.Solid(frame, "BORDER", Theme.GOLD, 0.12)
	frame.moveGlow:SetAllPoints(frame.bg)
	frame.moveGlow:Hide()

	self.toastFrame = frame
	return frame
end

function ns:HideToast()
	if self.toastFrame then self.toastFrame:Hide() end
end

-- Construit les lignes affichées : { label, value, improved, texture }
-- Un seul changement = une seule ligne, comme dans la référence.
function ns:ToastRows(diffRows, texture)
	local rows = {}
	if type(diffRows) ~= "table" then return rows end

	for _, entry in ipairs(diffRows) do
		if #rows >= TOAST_ROWS then break end
		rows[#rows + 1] = {
			label = PascalCase(L["STAT_" .. entry.label] or entry.label or ""),
			value = FormatDelta(entry.kind, entry.delta),
			improved = (entry.polarity and entry.delta > 0)
				or (not entry.polarity and entry.delta < 0),
			texture = texture,
		}
	end

	return rows
end

-- Contenu d'attente du mode édition : le cadre ne s'efface pas et montre sa
-- structure réelle, c'est ce que le joueur place.
function ns:ToastPlaceholderRows()
	local rows = {}
	for index = 1, TOAST_ROWS do
		rows[index] = {
			-- même casse que les vrais libellés (PascalCase) : en capitales, il
			-- débordait du bandeau
			label = index == 1 and PascalCase(L.STATS_NOCHANGE or "") or "",
			value = index == 1 and "-" or "",
			improved = true,
			placeholder = true,
		}
	end
	return rows
end

-- Remplit le cadre et renvoie le contenu sous forme de texte lisible :
-- « -12 DÉGÂTS / -0,60 s VITESSE D'ATTAQUE ». Les lignes non utilisées sont
-- vidées, elles ne laissent pas de trace.
function ns:ToastText(rows)
	local frame = self.toastFrame
	if not frame then return "" end

	if rows == "placeholder" then rows = self:ToastPlaceholderRows() end

	-- espaces entre les lettres seulement si l'interlettrage natif manque :
	-- sinon l'espacement serait doublé
	local titleText = string.upper(L.STATS_TITLE_SHORT or L.STATS_TITLE or "")
	if frame.title.SetNonSpaceGlyphSpacing then
		frame.title:SetText(titleText)
	else
		frame.title:SetText(SpacedTitle(titleText))
	end

	local lines = {}
	for index = 1, TOAST_ROWS do
		local row = frame.rows[index]
		local entry = rows and rows[index]
		if entry then
			if entry.placeholder then
				if row.arrow then row.arrow:Hide() end
				row.icon:Hide()
				row.value:SetText(entry.value or "-")
				row.value:SetTextColor(Theme.GREY[1], Theme.GREY[2], Theme.GREY[3])
				row.label:SetText(entry.label or "")
				row.label:SetTextColor(Theme.GREY[1], Theme.GREY[2], Theme.GREY[3])
			else
				row.value:SetText(tostring(entry.value or ""))
				row.arrow:SetTexture(entry.improved and ARROW_UP or ARROW_DOWN)
				if entry.improved then
					row.value:SetTextColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3])
					row.arrow:SetVertexColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3])
				else
					row.value:SetTextColor(Theme.RED[1], Theme.RED[2], Theme.RED[3])
					row.arrow:SetVertexColor(Theme.RED[1], Theme.RED[2], Theme.RED[3])
				end
				row.arrow:Show()
				row.label:SetText(entry.label or "")
				row.label:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
				if entry.texture then
					row.icon:SetTexture(entry.texture)
					row.icon:Show()
				else
					row.icon:Hide()
				end
			end
			lines[#lines + 1] = tostring(row.value:GetText()) .. " " .. tostring(row.label:GetText())
		else
			row.icon:Hide()
			if row.arrow then row.arrow:Hide() end
			row.value:SetText("")
			row.label:SetText("")
		end
	end

	-- le fond suit le libellé le plus long (« Aucun changement mesurable » du
	-- mode édition dépasse la colonne prévue)
	self:FitToastPlate(frame)

	frame.lastRows = rows
	return table.concat(lines, " / ")
end

-- Bord droit du fond : au moins TOAST_PLATE[3] après le cadre, plus si un
-- libellé déborde (12 de marge après lui)
function ns:FitToastPlate(frame)
	if not (frame and frame.bg and frame.rows) then return end
	local factor = Factor()
	local inset = ((TOAST_WIDTH - TOAST_CONTENT_WIDTH) / 2) - TOAST_CONTENT_LEFT
	local right = TOAST_PLATE[3]
	for _, row in ipairs(frame.rows) do
		local width = tonumber(row.label.GetStringWidth and row.label:GetStringWidth()) or 0
		local over = inset + TOAST_LABEL_LEFT + width / factor + 12 - TOAST_WIDTH
		if row.label:GetText() ~= "" and over > right then right = over end
	end
	frame.bg:ClearAllPoints()
	frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -TOAST_PLATE[1] * factor, TOAST_PLATE[2] * factor)
	frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right * factor, -TOAST_PLATE[4] * factor)
	frame.plateRight = right
end

-- /sd stuff : le panneau flottant a disparu, la commande imprime le même
-- constat dans le chat. Sans écart, on le dit au lieu de rester muet.
function ns:ShowGearSummary()
	local current = self:StatSnapshot()
	local baseline = self.statBefore
	if not baseline then
		self.statBefore = current
		return self:Print(L.MSG_STUFF_NONE)
	end

	local rows = self:DiffSnapshots(baseline, current)
	if #rows == 0 then
		return self:Print(L.MSG_STUFF_NONE)
	end

	for _, row in ipairs(rows) do
		local label = row.label or row.key or "?"
		self:Print(string.format("%s : %s -> %s", label, tostring(row.old), tostring(row.new)))
	end
end

function ns:ShowGearToast(rows, texture, preview)
	local db = self:DB()
	if db.showGearToast == false and not preview then return end

	-- Un équipement peut changer sans modifier aucune statistique (même objet
	-- d'une autre apparence, bijou sans stat, etc.). Sans écart, il n'y a
	-- rien à dire : on n'affiche ni cadre vide ni titre orphelin.
	local built = self:ToastRows(rows, texture)
	if #built == 0 then
		if self.toastFrame then self.toastFrame:Hide() end
		self.toastHideAt = nil
		return
	end

	local frame = self:EnsureToast()
	if not frame then return end

	self:ToastText(built)
	-- aperçu lancé depuis les réglages : au-dessus du panneau (couche DIALOG),
	-- sinon il apparaîtrait dessous ; un vrai changement reprend la couche HIGH
	frame:SetFrameStrata(preview and "FULLSCREEN_DIALOG" or "HIGH")
	self.toastPreview = preview and true or nil
	frame:Show()
	frame:SetAlpha(1)

	self.toastHideAt = (ns.Now and ns:Now() or 0) + TOAST_SECONDS
end

-- Aperçu du résumé (bouton « Simuler un changement » des réglages) : un faux
-- changement d'équipement, sur la stat qui compte le plus pour TA classe et ta
-- spé, pour voir où le cadre apparaît et à quoi il ressemble. Le résumé
-- n'affiche qu'une ligne (TOAST_ROWS) : chaque clic alterne un gain et une
-- perte, pour voir les deux couleurs et les deux flèches.
function ns:SimulateGearToast()
	-- ns.StatsForPlayer : la fonction locale est définie plus bas dans ce fichier
	local order = (type(ns.StatsForPlayer) == "function" and ns.StatsForPlayer()) or { "STR", "AGI", "STA" }
	local first = order[1] or "STR"
	self.toastPreviewLoss = not self.toastPreviewLoss and self.toastPreviewShown or false
	self.toastPreviewShown = true
	local delta = self.toastPreviewLoss and -3 or 8
	local rows = {
		{ label = first, kind = "integer", polarity = true, delta = delta },
		{ label = "STA", kind = "integer", polarity = true, delta = 5 },
		{ label = "ARMOR", kind = "integer", polarity = true, delta = 32 },
	}
	self:ShowGearToast(rows, "Interface\\Icons\\INV_Chest_Chain_05", true)
	return rows
end

function ns:UpdateToast(now)
	local frame = self.toastFrame
	if not frame or not frame:IsShown() then return end
	if self.editMode then return end   -- pas de fondu en mode édition

	if not self.toastHideAt then return end
	local elapsed = now - self.toastHideAt

	if elapsed <= 0 then return end

	local alpha = 1 - (elapsed / 1.5)
	if alpha <= 0 then
		frame:Hide()
		frame:SetAlpha(1)
		self.toastHideAt = nil
		-- fin d'un aperçu : le cadre reprend sa couche normale
		if self.toastPreview then
			frame:SetFrameStrata("HIGH")
			self.toastPreview = nil
		end
		return
	end
	frame:SetAlpha(alpha)
end

-- ---------------------------------------------------------------------------
-- Panneau de stats au survol du portrait
-- ---------------------------------------------------------------------------
local STATS_WIDTH = 206
local STATS_VALUE = 96     -- colonne des valeurs, à droite (« 506  27,5 % »)
local STATS_ROW   = 15
local STATS_TOP   = 9      -- haut de la ligne de classe
local STATS_LINES = 30     -- haut de la première statistique (sous le filet)

-- Bandeau (Theme.CreateToast) : liseré à la couleur de la classe, classe et
-- niveau d'objet en tête, un filet, puis les statistiques (valeur à droite)
function ns:EnsurePortraitPanel()
	if self.portraitFrame then return self.portraitFrame end

	local frame = Theme.CreateToast(UIParent, STATS_WIDTH, 120, { strata = "TOOLTIP" })
	if not frame then return nil end
	frame:EnableMouse(false)
	local left = frame.contentLeft

	frame.moveGlow = Theme.Solid(frame, "BORDER", Theme.GOLD, 0.12)
	frame.moveGlow:SetAllPoints()
	frame.moveGlow:Hide()

	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		local pointName, _, _, x, y = f:GetPoint(1)
		ns:DB().portraitPoint = { point = pointName or "CENTER", x = x or 0, y = y or 0 }
		ns:DB().portraitManual = true
	end)

	frame.classLine = Theme.Text(frame, Theme.F_LABEL)
	frame.classLine:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -STATS_TOP)
	frame.classLine:SetWidth(STATS_WIDTH - left - 60)
	frame.classLine:SetJustifyH("LEFT")
	frame.classLine:SetWordWrap(false)

	frame.ilvlLine = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.ilvlLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -STATS_TOP - 1)

	frame.rule = Theme.Solid(frame, "ARTWORK", Theme.EDGE_SOFT, 1)
	frame.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -STATS_LINES + 6)
	frame.rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -STATS_LINES + 6)
	frame.rule:SetHeight(1)

	-- Cinq statistiques primaires (Force, Agilité, Intelligence, Esprit,
	-- Endurance) puis l'armure et le DPS : sept lignes au total. Une boucle
	-- trop courte tronquait le DPS sans le dire.
	frame.lines = {}
	for index = 1, 7 do
		local label = Theme.Text(frame, Theme.F_SMALL, Theme.TEXT)
		label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -STATS_LINES - ((index - 1) * STATS_ROW))
		label:SetWidth(STATS_WIDTH - left - 10 - STATS_VALUE)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		label:SetText("")

		local right = Theme.Text(frame, Theme.F_NUMBER, Theme.PARCHMENT)
		right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -STATS_LINES - ((index - 1) * STATS_ROW))
		right:SetText("")

		frame.lines[index] = { left = label, right = right }
	end

	self.portraitFrame = frame
	return frame
end

local function ClassColor()
	local _, classFile = UnitClass("player")
	local colors = RAID_CLASS_COLORS
	if colors and classFile and colors[classFile] then
		local c = colors[classFile]
		return c.r, c.g, c.b
	end
	return 1, 0.82, 0
end

-- Spécialisation : GetSpecialization sur Forever ; sur Era (pas de spés),
-- l'onglet de talents qui a reçu le plus de points. L'ordre des onglets est
-- celui des spés (Sacré, Protection, Vindicte pour le paladin).
-- GetTalentTabInfo : Era -> name, icon, pointsSpent, fileName ;
-- clients plus récents -> id, name, description, icon, pointsSpent, …
local function TalentTab(index)
	local fn = rawget(_G, "GetTalentTabInfo")
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, index) }
	if not r[1] then return nil end
	if type(r[2]) == "number" and type(r[3]) == "string" then
		return r[3], tonumber(r[6]) or 0
	end
	return r[2], tonumber(r[4]) or 0
end

local function SpecIndex()
	local index = tonumber((Call(rawget(_G, "GetSpecialization"))))
	if index and index >= 1 then return index end
	local count = tonumber((Call(rawget(_G, "GetNumTalentTabs")))) or 0
	local best, bestPoints = nil, 0
	for tab = 1, count do
		local _, points = TalentTab(tab)
		if points and points > bestPoints then best, bestPoints = tab, points end
	end
	return best
end
ns.SpecIndex = SpecIndex

local function SpecName()
	local index = SpecIndex()
	if type(index) ~= "number" or index < 1 then return nil end
	if type(rawget(_G, "GetSpecializationInfo")) == "function" then
		local _, name = Call(GetSpecializationInfo, index)
		if name then return name end
	end
	return (TalentTab(index))
end

-- ---------------------------------------------------------------------------
-- Statistiques affichées par classe et par spécialisation
-- ---------------------------------------------------------------------------
-- Chaque spécialisation ne montre QUE les statistiques qui lui servent, dans
-- l'ordre de sa priorité officielle. Afficher l'Esprit d'un guerrier, c'est
-- une ligne pour un nombre sans effet.
--
-- SOURCE : les guides de statistiques de Wowhead pour le client Forever
-- (wowhead.com/forever/guide/classes/<classe>/<spé>/stat-priority-*), relevés
-- le 2026-11-02. Les priorités complètes mêlent des statistiques secondaires
-- (toucher, expertise, hâte, spé...) que ce panneau n'affiche pas : on n'en
-- garde que les cinq attributs primaires, et l'ordre relatif est conservé.
--
-- Deux règles de tri que la source ne dicte pas :
--  • une statistique primaire reléguée après toutes les secondaires dans la
--    liste officielle (Esprit chez un mage, par exemple) est omise : elle ne
--    fait pas partie de ce qui « compte » pour la spé ;
--  • sans mention dans la liste, l'attribut est écarté.
--
-- Les paliers de toucher (« Hit Chance jusqu'à 9 % ») ne concernent pas ce
-- panneau, qui n'affiche que des attributs.
local SPEC_STATS = {
	-- Guerrier : Force et Agilité, l'Endurance n'apparaît en protection que
	-- parce que la survie y est le métier.
	WARRIOR = {
		{ "STR", "AGI" },                       -- Armes
		{ "STR", "AGI", "STA" },                -- Fureur
		{ "STA", "AGI", "STR" },                -- Protection
	},
	-- Paladin : l'Intelligence d'abord en Sacré et en Vindicte (Champion de
	-- la Lumière la convertit en puissance des sorts), l'Endurance n'est pas
	-- listée en Sacré.
	PALADIN = {
		{ "INT", "SPI" },                       -- Sacré
		{ "STA", "AGI", "STR" },                -- Protection (spé / onglet 2)
		{ "INT", "STR", "AGI", "STA" },         -- Vindicte (spé / onglet 3)
	},
	-- Chasseur : l'Intellect nourrit le mana, donc Flèche mortelle et les
	-- tirs ; l'Esprit reste listé par les guides, en fin de liste.
	HUNTER = {
		{ "AGI", "INT", "SPI", "STA" },         -- Maîtrise
		{ "AGI", "INT", "SPI", "STA" },         -- Précision
		{ "AGI", "STR", "INT", "SPI", "STA" },  -- Survie
	},
	-- Voleur : l'Agilité donne attaque et critique ; la Force n'ajoute qu'un
	-- point d'attaque par point, d'où sa place derrière.
	ROGUE = {
		{ "AGI", "STR", "STA" },                -- Assassinat
		{ "AGI", "STR", "STA" },                -- Combat
		{ "AGI", "STR", "STA" },                -- Finesse
	},
	-- Prêtre : l'Intellect passe devant partout, l'Esprit juste après.
	PRIEST = {
		{ "INT", "SPI", "STA" },                -- Discipline
		{ "INT", "SPI", "STA" },                -- Sacré
		{ "INT", "SPI", "STA" },                -- Ombre
	},
	-- Chaman : l'Intellect d'abord pour les deux lanceurs ; l'Amélioration
	-- est à égalité Force/Intellect dans sa liste, puis l'Agilité.
	SHAMAN = {
		{ "INT", "SPI", "STR", "STA" },         -- Élémentaire
		{ "STR", "INT", "AGI", "SPI", "STA" },  -- Amélioration
		{ "INT", "SPI", "STR", "STA" },         -- Restauration
	},
	-- Mage : l'Intellect, puis l'Esprit (il alimente la régénération, même
	-- avec Armure de givre). L'Esprit n'est PAS inutile à un mage en Forever.
	MAGE = {
		{ "INT", "SPI", "STA" },                -- Arcanes
		{ "INT", "SPI", "STA" },                -- Feu
		{ "INT", "SPI", "STA" },                -- Givre (page inaccessible, aligné)
	},
	-- Démoniste : l'Esprit arrive en fin de liste mais y est.
	WARLOCK = {
		{ "INT", "SPI" },                       -- Affliction
		{ "INT", "SPI" },                       -- Démonologie
		{ "INT", "SPI" },                       -- Destruction
	},
	-- Druide : trois métiers sans rien en commun.
	DRUID = {
		{ "INT", "SPI", "STA" },                -- Équilibre
		{ "AGI", "STR", "INT", "SPI", "STA" },  -- Farouche (DPS)
		{ "SPI", "INT", "STA" },                -- Restauration
	},
}

-- Le druide Farouche est joué en ours (tank) ou en félin (DPS), et l'ordre
-- change : l'Endurance passe devant pour l'ours. On lit la forme actuelle.
local FERAL_TANK_ORDER = { "STA", "AGI", "STR" }

-- Exposé aux tests : c'est la seule source de vérité de ce qu'affiche le
-- panneau, elle doit donc être vérifiable classe par classe.
ns.SPEC_STATS = SPEC_STATS
ns.FERAL_TANK_ORDER = FERAL_TANK_ORDER

-- Ordre physionomique des statistiques primaires, utilisé comme repli quand la
-- classe n'est pas connue (classe ajoutée par un client modifié, par exemple).
local STAT_KEY_ORDER = { "STR", "AGI", "INT", "SPI", "STA" }

-- Le druide Farouche change de statistiques selon sa forme : en ours c'est
-- l'Endurance qui décide de la survie, en félin l'Agilité. On lit la forme
-- courante pour ne pas afficher les mauvaises valeurs.
local function IsBearForm()
	local form = Call(GetShapeshiftForm)
	return tonumber(form) == 1
end

-- Exposé : la détection de forme est utilisée par les tests.
ns.IsBearForm = IsBearForm

-- Renvoie la liste des clés de statistiques à afficher pour le joueur, dans
-- l'ordre voulu. Repli : toutes les primaires, dans l'ordre physionomique.
local function StatsForPlayer()
	local _, classFile = Call(UnitClass, "player")
	classFile = type(classFile) == "string" and string.upper(classFile) or nil
	local bySpec = classFile and SPEC_STATS[classFile]
	if not bySpec then return STAT_KEY_ORDER end

	local index = SpecIndex() or 0
	if classFile == "DRUID" and index == 2 and IsBearForm() then
		return FERAL_TANK_ORDER
	end
	return bySpec[index] or bySpec[1]
end
ns.StatsForPlayer = StatsForPlayer

function ns:ShowPortraitStats()
	local db = self:DB()
	-- `forceStats` permet de l'afficher en mode édition même si le joueur l'a désactivé
	if db.showPortraitStats == false and not self.forceStats then return end

	local frame = self:EnsurePortraitPanel()
	if not frame then return end

	local snapshot = self:StatSnapshot()
	local r, g, b = ClassColor()

	local className, classFile = UnitClass("player")
	local spec = SpecName()
	local classText = tostring(className or classFile or "?")
	if spec then classText = classText .. " · " .. tostring(spec) end

	frame.classLine:SetText(classText)
	frame.classLine:SetTextColor(r, g, b)
	if frame.SetAccent then frame:SetAccent({ r, g, b }) end
	frame.ilvlLine:SetText(string.format("ilvl %d", math.floor(snapshot.ilvl + 0.5)))

	-- Le panneau ne montre que les statistiques UTILES à la classe et à la
	-- spécialisation, dans l'ordre déclaré par SPEC_STATS. Afficher l'Esprit
	-- d'un guerrier, c'est une ligne de plus pour un nombre sans effet.
	local values = {
		STR = snapshot.str,
		AGI = snapshot.agi,
		INT = snapshot.int,
		SPI = snapshot.spi,
		STA = snapshot.sta,
	}
	local keys = StatsForPlayer()

	local entries = {}
	for position, key in ipairs(keys) do
		local text = L["STAT_" .. key] or key
		-- seule la première statistique de la liste est mise en avant
		if position == 1 then text = Theme.T_GOLD .. text .. "|r" end
		entries[#entries + 1] = {
			left = text,
			right = tostring(math.floor((values[key] or 0) + 0.5)),
		}
	end

	entries[#entries + 1] = {
		left = L["STAT_ARMOR"] or "ARMOR",
		right = string.format("%d  %s%.1f %%|r", math.floor(snapshot.armor + 0.5), Theme.T_PARCHMENT,
			snapshot.reduction),
	}
	entries[#entries + 1] = {
		left = L["STAT_DPS"] or "DPS",
		right = string.format("%.1f", snapshot.dps),
	}

	for index, line in ipairs(frame.lines) do
		local entry = entries[index]
		if entry then
			line.left:SetText(entry.left)
			line.left:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
			line.right:SetText(entry.right)
			line.left:Show()
			line.right:Show()
		else
			line.left:Hide()
			line.right:Hide()
		end
	end

	-- pas de cadre vide : la hauteur suit le nombre de lignes
	frame:SetHeight(STATS_LINES + (#entries * STATS_ROW) + 8)

	-- Ancrage : position choisie par le joueur, sinon au-dessus du portrait
	frame:ClearAllPoints()
	if db.portraitManual and db.portraitPoint then
		local point = db.portraitPoint
		frame:SetPoint(point.point or "CENTER", UIParent, point.point or "CENTER",
			point.x or 0, point.y or 0)
	elseif self:PortraitAnchorFrame() then
		-- au-dessus du cadre survolé : celui de Blizzard ou d'un addon d'interface
		frame:SetPoint("BOTTOM", self:PortraitAnchorFrame(), "TOP", 0, 6)
	else
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
	end

	frame:Show()
end

function ns:HidePortraitStats()
	if self.editMode then return end   -- verrouillé affiché pendant l'édition
	if self.portraitFrame then self.portraitFrame:Hide() end
end

-- ---------------------------------------------------------------------------
-- Survol du cadre du joueur
--
-- Le cadre de Blizzard (PlayerFrame) n'est pas toujours là : une interface
-- complète (EllesmereUI, ElvUI, Shadowed Unit Frames…) le masque et pose le
-- sien. Deux voies, qui se complètent :
--   * accroches OnEnter/OnLeave sur les cadres connus, quand ils existent
--     (ils naissent parfois tard : on réessaie à 1, 3 et 6 s de l'entrée en jeu) ;
--   * repli générique : dix fois par seconde (module actif seulement), le
--     cadre sous la souris, ou l'un de ses trois parents, dont l'unité est
--     « player ».
-- Un seul cadre survolé à la fois (ns.portraitHover) : quand les deux voies
-- le voient, le panneau n'est montré qu'une fois, et seule la voie qui l'a
-- montré le masque.
-- ---------------------------------------------------------------------------
ns.PORTRAIT_FRAMES = {
	"PlayerFrame",                    -- Blizzard
	"EllesmereUIUnitFrames_Player",   -- EllesmereUI (oUF)
	"ElvUF_Player",                   -- ElvUI (oUF)
	"SUFUnitplayer",                  -- Shadowed Unit Frames
	"LUFUnitplayer",                  -- Luna Unit Frames
	"PitBull4_Frames_Player",         -- PitBull 4
	"XPerl_Player",                   -- Z-Perl
	"UUF_Player",                     -- UnhaltedUnitFrames (oUF)
	"TukuiPlayerFrame", "TukuiPlayer",
	"oUF_Player", "oUF_PlayerFrame", "oUF_player",
}
ns.PORTRAIT_RETRY = { 1, 3, 6 }
ns.PORTRAIT_POLL = 0.1
local PORTRAIT_PARENTS = 3

-- Unité affichée par un cadre (attribut sécurisé, sinon champ .unit), ou nil
local function FrameUnit(frame)
	if type(frame) ~= "table" then return nil end
	local unit
	if type(frame.GetAttribute) == "function" then
		local ok, value = pcall(frame.GetAttribute, frame, "unit")
		if ok then unit = ns.Plain(value) end
	end
	if type(unit) ~= "string" then
		local ok, value = pcall(function() return frame.unit end)
		unit = ok and ns.Plain(value) or nil
	end
	return type(unit) == "string" and unit or nil
end
ns.PortraitFrameUnit = FrameUnit

-- Cadre sous la souris : GetMouseFoci (moteur récent), sinon GetMouseFocus
local function MouseFocus()
	local foci = rawget(_G, "GetMouseFoci")
	if type(foci) == "function" then
		local ok, list = pcall(foci)
		if ok and type(list) == "table" then return list[1] end
	end
	local focus = rawget(_G, "GetMouseFocus")
	if type(focus) == "function" then
		local ok, frame = pcall(focus)
		if ok then return frame end
	end
	return nil
end

-- Le cadre du joueur sous la souris (le survolé ou l'un de ses parents), ou nil
function ns:PortraitHoveredFrame()
	local frame = MouseFocus()
	for _ = 0, PORTRAIT_PARENTS do
		if type(frame) ~= "table" then return nil end
		if FrameUnit(frame) == "player" then return frame end
		if type(frame.GetParent) ~= "function" then return nil end
		local ok, parent = pcall(frame.GetParent, frame)
		frame = ok and parent or nil
	end
	return nil
end

-- Cadre au-dessus duquel le panneau se pose : le dernier survolé, sinon
-- PlayerFrame, sinon le premier cadre connu
function ns:PortraitAnchorFrame()
	if type(self.portraitAnchor) == "table" then return self.portraitAnchor end
	for _, name in ipairs(self.PORTRAIT_FRAMES) do
		local frame = rawget(_G, name)
		-- un PlayerFrame masqué par une interface de remplacement : on passe
		if type(frame) == "table" then
			local ok, visible = true, true
			if type(frame.IsVisible) == "function" then ok, visible = pcall(frame.IsVisible, frame) end
			if ok and visible then return frame end
		end
	end
	return nil
end

function ns:PortraitHoverEnter(frame, source)
	if type(frame) ~= "table" then return end
	local panel = self.portraitFrame
	if self.portraitHover == frame and panel and panel:IsShown() then return end
	self.portraitHover, self.portraitHoverSource = frame, source or "hook"
	self.portraitAnchor = frame
	self:ShowPortraitStats()
end

function ns:PortraitHoverLeave(frame)
	if self.portraitHover == nil or (frame ~= nil and self.portraitHover ~= frame) then return end
	self.portraitHover, self.portraitHoverSource = nil, nil
	self:HidePortraitStats()
end

local function HookPortraitFrame(frame)
	if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then return false end
	ns.portraitHooks = ns.portraitHooks or {}
	if ns.portraitHooks[frame] then return false end
	local ok = pcall(frame.HookScript, frame, "OnEnter", function(self) ns:PortraitHoverEnter(self, "hook") end)
	if not ok then return false end
	pcall(frame.HookScript, frame, "OnLeave", function(self) ns:PortraitHoverLeave(self) end)
	ns.portraitHooks[frame] = true
	return true
end

-- Accroche les cadres connus présents ; rend le nombre de nouvelles accroches
function ns:HookPortraitFrames()
	local count = 0
	for _, name in ipairs(self.PORTRAIT_FRAMES) do
		if HookPortraitFrame(rawget(_G, name)) then count = count + 1 end
	end
	if count > 0 then self.portraitHooked = true end
	return count
end

-- Repli générique, une fois tous les PORTRAIT_POLL : il montre le panneau
-- quand aucune accroche ne l'a fait, et ne masque que ce qu'il a montré
function ns:PortraitPoll()
	local db = self:DB()
	if db.showPortraitStats == false or self.editMode then return end
	local frame = self:PortraitHoveredFrame()
	if frame then
		if not self.portraitHover then self:PortraitHoverEnter(frame, "poll") end
	elseif self.portraitHover then
		-- montré par le repli : il le masque ; montré par une accroche dont le
		-- cadre a disparu (fondu, masqué) sans OnLeave : aussi
		local hover = self.portraitHover
		local visible = true
		if type(hover.IsVisible) == "function" then
			local ok, v = pcall(hover.IsVisible, hover)
			visible = ok and v and true or false
		end
		if self.portraitHoverSource == "poll" or not visible then self:PortraitHoverLeave() end
	end
end

function ns:InitPlayerFrameHooks()
	self:HookPortraitFrames()
	if not self.portraitPoller and type(CreateFrame) == "function" then
		local ok, poller = pcall(CreateFrame, "Frame")
		if ok and poller then
			poller:SetScript("OnUpdate", ns.Throttle(self.PORTRAIT_POLL, function()
				local okPoll, err = pcall(ns.PortraitPoll, ns)
				if not okPoll and ns.RecordError then ns:RecordError("portrait:poll", err) end
			end))
			self.portraitPoller = poller
		end
	end
	-- les interfaces complètes créent leurs cadres après l'entrée en jeu
	if not self.portraitRetried and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		self.portraitRetried = true
		for _, delay in ipairs(self.PORTRAIT_RETRY) do
			C_Timer.After(delay, function() pcall(ns.HookPortraitFrames, ns) end)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Changement d'équipement
--
-- Un PLAYER_EQUIPMENT_CHANGED par emplacement : un ensemble équipé d'un coup
-- en donne plusieurs. On les regroupe (ns.gearPending) et on compare au
-- relevé d'AVANT la première pièce. Sur le moteur récent, les statistiques ne
-- sont pas toujours recalculées 0,2 s après l'événement : sans écart, on
-- réessaie (GEAR_RETRY, et à chaque UNIT_STATS / PLAYER_AVG_ITEM_LEVEL_UPDATE
-- du joueur). Le relevé de référence n'avance qu'une fois l'écart trouvé, ou
-- à la dernière tentative : avant, un diff vide écrasait la référence et le
-- vrai changement n'était plus jamais montré.
-- ---------------------------------------------------------------------------
ns.GEAR_RETRY = { 0.3, 0.8, 1.5 }

function ns:CaptureStatBaseline()
	self.statBefore = self:StatSnapshot()
	self.gearPending = nil
end

-- Un événement : l'emplacement s'ajoute à la série, les tentatives repartent
function ns:QueueEquipmentChange(slot)
	slot = tonumber(ns.Plain(slot))
	local pending = self.gearPending
	if not pending then
		pending = { slots = {}, serial = 0, startedAt = self:Now() }
		self.gearPending = pending
	end
	if slot then
		local known = false
		for _, value in ipairs(pending.slots) do if value == slot then known = true end end
		if not known then pending.slots[#pending.slots + 1] = slot end
	end
	pending.serial = pending.serial + 1
	local serial = pending.serial
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return self:OnEquipmentChanged(true)
	end
	local retries = self.GEAR_RETRY
	for index, delay in ipairs(retries) do
		C_Timer.After(delay, function()
			-- une pièce de plus entre-temps : ses propres tentatives prennent le relais
			if ns.gearPending ~= pending or pending.serial ~= serial then return end
			local ok, err = pcall(ns.OnEquipmentChanged, ns, index == #retries)
			if not ok and ns.RecordError then ns:RecordError("stuff:diff", err) end
		end)
	end
end

-- Statistiques recalculées par le client : une tentative de plus, s'il en attend
function ns:OnStatsUpdated(unit)
	if unit ~= nil and ns.Plain(unit) ~= "player" then return end
	if not self.gearPending then return end
	self:OnEquipmentChanged(false)
end

-- Emplacement modifié (pour l'icône du toast) : d'abord ceux de la série
local function ChangedSlot(before, after, pending)
	local beforeSlots, afterSlots = before.slots or {}, after.slots or {}
	for _, slot in ipairs(pending and pending.slots or {}) do
		if beforeSlots[slot] ~= afterSlots[slot] then return slot end
	end
	for slot = 1, 19 do
		if beforeSlots[slot] ~= afterSlots[slot] then return slot end
	end
	return nil
end

local function GearOutcome(state, slot, rows, pending)
	local waited
	if pending and pending.startedAt then waited = math.max(0, ns:Now() - pending.startedAt) end
	ns.gearLast = { state = state, slot = slot, rows = rows or 0, waited = waited,
		events = pending and pending.serial or 0 }
end

-- final : dernière tentative (sans écart, on s'y résout). Appel direct, sans
-- série en cours : une tentative unique, donc finale.
function ns:OnEquipmentChanged(final)
	local db = self:DB()
	local pending = self.gearPending
	if final == nil then final = (pending == nil) end
	local before = self.statBefore
	local after = self:StatSnapshot()

	if not before then
		self.statBefore, self.gearPending = after, nil
		GearOutcome("nobaseline", nil, 0, pending)
		return "nobaseline"
	end

	local changedSlot = ChangedSlot(before, after, pending)
	if not changedSlot then
		if not final then return "wait" end
		-- rien de visible (même objet remis) : on ignore, la référence suit
		self.statBefore, self.gearPending = after, nil
		GearOutcome("noslot", nil, 0, pending)
		return "noslot"
	end

	-- des stats illisibles pour l'instant (secrètes) : on attend la relecture
	-- suivante, sans toucher à la référence
	if not final and next(after.secret or {}) ~= nil then return "wait" end
	local rows = self:DiffSnapshots(before, after)
	if #rows == 0 and not final then return "wait" end

	-- référence suivante : une stat restée secrète garde sa dernière valeur lue
	for key in pairs(after.secret or {}) do
		if before[key] ~= nil and not (before.secret or {})[key] then after[key] = before[key]; after.secret[key] = nil end
	end
	self.statBefore, self.gearPending = after, nil
	if #rows == 0 then
		GearOutcome("nodelta", changedSlot, 0, pending)
		return "nodelta"
	end
	if db.showGearToast == false then
		GearOutcome("disabled", changedSlot, #rows, pending)
		return "disabled"
	end
	local beforeLink = before.slots and before.slots[changedSlot]
	local afterLink = after.slots and after.slots[changedSlot]
	self:ShowGearToast(rows, SlotTexture(afterLink, changedSlot, beforeLink))
	GearOutcome("shown", changedSlot, #rows, pending)
	return "shown"
end

-- Ligne de /r2q diag : issue du dernier changement d'équipement
function ns:GearDiagLine()
	local last = self.gearLast
	if self.gearPending then
		return self:F("MSG_DIAG_GEAR_PENDING", #self.gearPending.slots)
	end
	if not last then return L.MSG_DIAG_GEAR_NONE end
	local slot = tostring(last.slot or "?")
	if last.state == "shown" then return self:F("MSG_DIAG_GEAR_SHOWN", slot, last.rows) end
	if last.state == "disabled" then return self:F("MSG_DIAG_GEAR_DISABLED", slot, last.rows) end
	if last.state == "nodelta" then
		local retries = self.GEAR_RETRY
		local seconds = string.format("%.1f", retries[#retries] or 0):gsub("%.", L.MSG_DIAG_DECIMAL or ".")
		return self:F("MSG_DIAG_GEAR_NODELTA", slot, seconds)
	end
	if last.state == "noslot" then return L.MSG_DIAG_GEAR_NOSLOT end
	return L.MSG_DIAG_GEAR_NOBASE
end

-- UNIT_STATS et PLAYER_AVG_ITEM_LEVEL_UPDATE : un cadre à part, l'un ou
-- l'autre peut manquer au client (pcall, sans alerte)
do
	local ok, statsFrame = pcall(CreateFrame, "Frame")
	if ok and statsFrame then
		pcall(statsFrame.RegisterEvent, statsFrame, "UNIT_STATS")
		pcall(statsFrame.RegisterEvent, statsFrame, "PLAYER_AVG_ITEM_LEVEL_UPDATE")
		statsFrame:SetScript("OnEvent", function(_, event, unit)
			if event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then unit = "player" end
			local okStats, err = pcall(ns.OnStatsUpdated, ns, unit)
			if not okStats and ns.RecordError then ns:RecordError("stuff:" .. tostring(event), err) end
		end)
		ns.statsEventFrame = statsFrame
	end
end

-- ---------------------------------------------------------------------------
-- Mode déplacement : déverrouille un cadre pour le placer à la souris
-- ---------------------------------------------------------------------------
function ns:EditTargets()
	return {
		{ key = "toast", frame = self.toastFrame },
		{ key = "portrait", frame = self.portraitFrame },
	}
end

local function SetFrameEditable(frame, editable)
	if not frame then return end
	if frame.EnableMouse then frame:EnableMouse(editable and true or false) end
	if frame.moveGlow then
		if editable then frame.moveGlow:Show() else frame.moveGlow:Hide() end
	end
end

-- Entrée en mode édition : les deux blocs s'affichent, déverrouillés
function ns:StartEditMode()
	if self.editMode then return end

	local toast = self:EnsureToast()
	if toast then
		toast:Show()
		toast:SetAlpha(1)
		self:ToastText("placeholder")
		self.toastHideAt = nil
	end

	-- affiché même si le joueur a désactivé les stats du portrait
	self.forceStats = true
	self:ShowPortraitStats()
	self.forceStats = nil

	self.editMode = true
	SetFrameEditable(self.toastFrame, true)
	SetFrameEditable(self.portraitFrame, true)

	-- le panneau de réglages se ferme à l'entrée ; sans ce bandeau, le bouton
	-- « Terminer » disparaissait avec lui et l'édition devenait un cul-de-sac
	if self.ShowEditBanner then self:ShowEditBanner() end

	self:Print(L.MSG_EDIT_START)
	if self.RefreshOptions then self:RefreshOptions() end
end

function ns:StopEditMode()
	if not self.editMode then return end
	self.editMode = nil

	SetFrameEditable(self.toastFrame, false)
	SetFrameEditable(self.portraitFrame, false)
	if self.HideEditBanner then self:HideEditBanner() end

	-- ces deux cadres n'étaient affichés que pour le placement
	if self.toastFrame then
		self.toastFrame:Hide()
		self.toastFrame:SetAlpha(1)
	end
	if self.portraitFrame then
		self.portraitFrame:Hide()   -- revient au déclenchement par survol
	end

	self:Print(L.MSG_EDIT_STOP)
	if self.RefreshOptions then self:RefreshOptions() end
end

function ns:ToggleEditMode()
	if self.editMode then
		self:StopEditMode()
	else
		self:StartEditMode()
	end
	return self.editMode
end

function ns:IsEditing()
	return self.editMode and true or false
end

ns.Mark("Stats")
