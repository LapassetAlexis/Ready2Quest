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

function ns:StatSnapshot()
	local snapshot = {}
	local unitLevel = Call(UnitLevel, "player")
	local level = tonumber(unitLevel) or 60
	snapshot.level = level

	-- toujours passer par une locale : jamais un appel en argument de tonumber()
	local strength = Call(UnitStat, "player", 1)
	local agility = Call(UnitStat, "player", 2)
	local stamina = Call(UnitStat, "player", 3)
	local intellect = Call(UnitStat, "player", 4)
	snapshot.str = tonumber(strength) or 0
	snapshot.agi = tonumber(agility) or 0
	snapshot.sta = tonumber(stamina) or 0
	snapshot.int = tonumber(intellect) or 0

	-- UnitArmor(unit) -> base, effective, attackPower, damage
	local _, armorEffective = Call(UnitArmor, "player")
	snapshot.armor = tonumber(armorEffective) or 0
	snapshot.reduction = self:DamageReduction(snapshot.armor, level)

	-- Esprit : 5e statistique primaire (UnitStat 5). Elle manquait au relevé,
	-- alors que c'est la statistique principale de certaines spécialisations.
	local spirit = Call(UnitStat, "player", 5)
	snapshot.spi = tonumber(spirit) or 0

	-- UnitDamage(unit) -> min main, max main, mod, ...
	local dmgMin, dmgMax = Call(UnitDamage, "player")
	snapshot.dmgMin = tonumber(dmgMin) or 0
	snapshot.dmgMax = tonumber(dmgMax) or 0

	-- UnitAttackSpeed(unit) -> main, off : ne JAMAIS passer l'appel directement
	-- à tonumber(), le 2e retour deviendrait l'argument « base ».
	local speedMain = Call(UnitAttackSpeed, "player")
	snapshot.speed = tonumber(speedMain) or 0
	if snapshot.speed > 0 then
		snapshot.dps = ((snapshot.dmgMin + snapshot.dmgMax) / 2) / snapshot.speed
	else
		snapshot.dps = 0
	end

	-- UnitAttackPower(unit) -> base, posBuff, negBuff (trois retours seulement).
	-- La PA venue de l'équipement est dans posBuff : la PA réelle est la somme.
	local apBase, apPos, apNeg = Call(UnitAttackPower, "player")
	snapshot.ap = (tonumber(apBase) or 0) + (tonumber(apPos) or 0) + (tonumber(apNeg) or 0)

	local crit = Call(GetCritChance)
	snapshot.crit = tonumber(crit) or 0
	local haste = Call(GetHaste)
	snapshot.haste = tonumber(haste) or 0

	local avg, equipped = Call(GetAverageItemLevel)
	snapshot.ilvl = tonumber(equipped) or tonumber(avg) or 0
	-- Era : GetAverageItemLevel peut manquer, on calcule depuis l'équipement
	if snapshot.ilvl <= 0 and self.AverageItemLevel then
		snapshot.ilvl = tonumber(self:AverageItemLevel()) or 0
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

	for _, def in ipairs(COMPARED) do
		if def.kind ~= "hidden" then
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

-- Texture de l'objet équipé dans l'emplacement : d'abord le lien, puis
-- GetItemInfo (dernier retour), enfin l'API d'emplacement. Nil si aucune ne
-- répond : l'icône reste alors simplement vide.
local function SlotTexture(link, slot, previousLink)
	-- Retirer un item doit quand même montrer SON icône : c'est le repère
	-- visuel de la ligne. On essaie donc le lien actuel, puis le lien
	-- précédent (celui qui vient d'être enlevé), puis l'emplacement.
	local candidates = { link }
	if type(previousLink) == "string" then candidates[#candidates + 1] = previousLink end
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "string" and type(GetItemInfo) == "function" then
			local ok, _, _, _, _, _, _, _, _, _, texture = pcall(GetItemInfo, candidate)
			if ok and texture then return texture end
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
	frame.rule:SetVertexColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3], 0.45)
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

	-- Bordure visible uniquement en mode édition (sinon le cadre est invisible)
	frame.moveGlow = frame:CreateTexture(nil, "OVERLAY")
	frame.moveGlow:SetTexture(Theme.SOLID)
	frame.moveGlow:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.55)
	frame.moveGlow:SetPoint("TOPLEFT", -6, 4)
	frame.moveGlow:SetPoint("BOTTOMRIGHT", 6, -4)
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
			label = index == 1 and string.upper(L.STATS_NOCHANGE or "") or "",
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

	frame.lastRows = rows
	return table.concat(lines, " / ")
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
local STATS_WIDTH = 176
local STATS_ROW   = 14

function ns:EnsurePortraitPanel()
	if self.portraitFrame then return self.portraitFrame end

	local frame = Theme.CreateDiscreet(UIParent, STATS_WIDTH, 120)
	if not frame then return nil end
	frame:SetFrameStrata("TOOLTIP")
	frame:EnableMouse(false)

	frame.moveGlow = frame:CreateTexture(nil, "OVERLAY")
	frame.moveGlow:SetTexture(Theme.SOLID)
	frame.moveGlow:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.14)
	frame.moveGlow:SetAllPoints()
	frame.moveGlow:Hide()

	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		local pointName, _, _, x, y = f:GetPoint(1)
		ns:DB().portraitPoint = { point = pointName or "CENTER", x = x or 0, y = y or 0 }
		ns:DB().portraitManual = true
	end)

	frame.classLine = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.classLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -6)
	frame.classLine:SetWidth(STATS_WIDTH - 60)
	frame.classLine:SetJustifyH("LEFT")
	frame.classLine:SetWordWrap(false)

	frame.ilvlLine = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.ilvlLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -6)
	frame.ilvlLine:SetTextColor(0.70, 0.70, 0.70)

	-- Cinq statistiques primaires (Force, Agilité, Intelligence, Esprit,
	-- Endurance) puis l'armure et le DPS : sept lignes au total. Une boucle
	-- trop courte tronquait le DPS sans le dire.
	frame.lines = {}
	for index = 1, 7 do
		local left = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		left:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -22 - ((index - 1) * STATS_ROW))
		left:SetWidth(STATS_WIDTH - 70)
		left:SetJustifyH("LEFT")
		left:SetWordWrap(false)
		left:SetText("")

		local right = frame:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
		right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -22 - ((index - 1) * STATS_ROW))
		right:SetText("")

		frame.lines[index] = { left = left, right = right }
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
			line.left:SetTextColor(0.86, 0.84, 0.78)
			line.right:SetText(entry.right)
			line.left:Show()
			line.right:Show()
		else
			line.left:Hide()
			line.right:Hide()
		end
	end

	-- pas de cadre vide : la hauteur suit le nombre de lignes
	frame:SetHeight(28 + (#entries * STATS_ROW) + 6)

	-- Ancrage : position choisie par le joueur, sinon au-dessus du portrait
	frame:ClearAllPoints()
	if db.portraitManual and db.portraitPoint then
		local point = db.portraitPoint
		frame:SetPoint(point.point or "CENTER", UIParent, point.point or "CENTER",
			point.x or 0, point.y or 0)
	elseif type(PlayerFrame) == "table" then
		frame:SetPoint("BOTTOM", PlayerFrame, "TOP", 0, 6)
	else
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
	end

	frame:Show()
end

function ns:HidePortraitStats()
	if self.editMode then return end   -- verrouillé affiché pendant l'édition
	if self.portraitFrame then self.portraitFrame:Hide() end
end

function ns:InitPlayerFrameHooks()
	if self.portraitHooked then return end
	if type(PlayerFrame) ~= "table" or type(PlayerFrame.HookScript) ~= "function" then return end

	local ok = pcall(PlayerFrame.HookScript, PlayerFrame, "OnEnter", function()
		ns:ShowPortraitStats()
	end)
	if not ok then return end

	pcall(PlayerFrame.HookScript, PlayerFrame, "OnLeave", function()
		ns:HidePortraitStats()
	end)

	self.portraitHooked = true
end

-- ---------------------------------------------------------------------------
-- Changement d'équipement
-- ---------------------------------------------------------------------------
function ns:CaptureStatBaseline()
	self.statBefore = self:StatSnapshot()
end

function ns:OnEquipmentChanged()
	local db = self:DB()
	local before = self.statBefore
	local after = self:StatSnapshot()

	if not before then
		self.statBefore = after
		return
	end

	-- Emplacement modifié (pour l'icône du toast)
	local changedSlot
	for slot = 1, 19 do
		if (before.slots and before.slots[slot]) ~= (after.slots and after.slots[slot]) then
			changedSlot = slot
			break
		end
	end
	if not changedSlot then return end   -- rien de visible : on ignore

	local rows = self:DiffSnapshots(before, after)

	if db.showGearToast ~= false then
		local beforeLink = before.slots and before.slots[changedSlot]
		local afterLink = after.slots and after.slots[changedSlot]
		self:ShowGearToast(rows, SlotTexture(afterLink, changedSlot, beforeLink))
	end

	self.statBefore = after
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
