-- TrainerCode.lua -- 3.7.0 : le code de dresseur (docs/qc-gameplay-viral,
-- étape 3, chantier S2, point 1)
--
-- Sa fiche de dresseur sous forme d'un texte à copier : le joueur le colle
-- où il veut (Discord), n'importe qui l'ouvre chez lui, d'un autre royaume ou
-- de l'autre faction. Rien ne sort du jeu tout seul : l'addon ne peut pas
-- écrire dans le presse-papiers, le joueur copie lui-même (Ctrl+C).
--
-- Format : « QC1:<corps>:<somme> »
--   * QC1 : préfixe de version. Un « QC2: » (version future) est refusé
--     poliment (« mets l'addon à jour »), jamais lu de travers.
--   * corps : la fiche telle que l'envoie ns:TrainerSerializeCard (son champ
--     « n= », le nom, passé en tête pour qu'on le lise), suivie de
--     « ;fa=A » ou « ;fa=H » (la faction du dresseur : un code voyage d'une
--     faction à l'autre, un message d'addon jamais). Le corps n'a aucun « : »
--     (caractère réservé de la fiche, échappé en %3A). Pour survivre à un
--     copier-coller et à la mise en forme de Discord : « ! » et « + »
--     deviennent %21 et %2B, puis « _ » devient « ! » (Discord met en
--     italique ou souligne ce qui est entre deux « _ » et les mange ; les
--     bits des hauts faits en sont pleins) et l'espace devient « + ».
--   * somme : djb2 sur 32 bits (départ 5381, h = h * 33 + octet, modulo
--     2^32) de « QC1:<corps> », en 8 chiffres hexadécimaux minuscules.
-- Lecture tolérante : blancs (espaces, tabulations, retours à la ligne,
-- espace insécable, espaces de largeur nulle) retirés partout ; guillemets,
-- accents graves (bloc de code Discord) et astérisques retirés aux deux
-- bouts ; préfixe en minuscules accepté. Refus, avec la raison : "empty"
-- (rien de collé), "long" (plus de TRAINER_CODE_MAX caractères), "prefix"
-- (pas un code de dresseur), "newer" (code d'une version plus récente),
-- "sum" (code abîmé ou retouché : somme fausse), "card" (somme juste mais
-- pas de fiche lisible dedans).
-- Une fiche pleine (tous les champs au maximum) fait moins de 1 000
-- caractères (tests/modules/trainer_code.lua le mesure).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

local FR = {
	TRAINER_CODE_ERR_empty  = "Colle d'abord un code de dresseur dans le champ.",
	TRAINER_CODE_ERR_long   = "Ce texte est trop long pour un code de dresseur.",
	TRAINER_CODE_ERR_prefix = "Ce texte n'est pas un code de dresseur (il commence par QC1:).",
	TRAINER_CODE_ERR_newer  = "Ce code vient d'une version plus récente de Quest Companion : mets l'addon à jour.",
	TRAINER_CODE_ERR_sum    = "Ce code est abîmé ou incomplet : recopie-le en entier.",
	TRAINER_CODE_ERR_card   = "Ce code ne contient pas de fiche lisible.",
}
local EN = {
	TRAINER_CODE_ERR_empty  = "Paste a trainer code in the field first.",
	TRAINER_CODE_ERR_long   = "This text is too long for a trainer code.",
	TRAINER_CODE_ERR_prefix = "This text is not a trainer code (it starts with QC1:).",
	TRAINER_CODE_ERR_newer  = "This code comes from a newer version of Quest Companion: update the addon.",
	TRAINER_CODE_ERR_sum    = "This code is damaged or incomplete: copy it again in full.",
	TRAINER_CODE_ERR_card   = "This code holds no readable card.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRAINER_CODE_STRINGS = { fr = FR, en = EN } end

ns.TRAINER_CODE_VERSION = 1
ns.TRAINER_CODE_PREFIX = "QC1:"
ns.TRAINER_CODE_MAX = 1500          -- caractères d'un code nettoyé, au plus
ns.TRAINER_CODE_REASONS = { "empty", "long", "prefix", "newer", "sum", "card" }

local function G(name) return rawget(_G, name) end
local function Plain(v) if ns.Plain then return ns.Plain(v) end return v end

-- djb2 sur 32 bits, en deux moitiés de 16 bits (%x d'un nombre de plus de
-- 31 bits n'est pas sûr partout)
function ns.TrainerCodeSum(text)
	local h = 5381
	text = tostring(text or "")
	for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
	return string.format("%04x%04x", math.floor(h / 65536), h % 65536)
end

-- « A » (Alliance), « H » (Horde) ou nil
function ns:TrainerFaction()
	local fn = G("UnitFactionGroup")
	if type(fn) ~= "function" then return nil end
	local ok, faction = pcall(fn, "player")
	faction = ok and Plain(faction) or nil
	if faction == "Alliance" then return "A" elseif faction == "Horde" then return "H" end
	return nil
end

-- corps de fiche -> corps de transport (et retour)
-- (« ! » et « + » d'un texte passent en %21 et %2B, que la fiche relue
-- rend tels quels ; « _ » et l'espace prennent leur place)
local function Pack(body)
	return (body:gsub("!", "%%21"):gsub("%+", "%%2B"):gsub("_", "!"):gsub(" ", "+"))
end
local function Unpack(body)
	return (body:gsub("!", "_"):gsub("%+", " "))
end

-- le code d'une fiche (table) ; ma fiche par défaut
function ns:TrainerCodeOf(card, faction)
	local body = card and self:TrainerSerializeCard(card) or self:TrainerOwnCardText()
	-- le nom en tête : lisible au début du code collé (l'ordre des champs est libre)
	local name = body:match("^n=[^;]*") or body:match(";(n=[^;]*)")
	if name and body:sub(1, #name) ~= name then
		body = name .. ";" .. body:gsub(";n=[^;]*", "", 1)
	end
	if faction == "A" or faction == "H" then body = body .. ";fa=" .. faction end
	local packed = ns.TRAINER_CODE_PREFIX .. Pack(body)
	return packed .. ":" .. ns.TrainerCodeSum(packed)
end

function ns:TrainerCodeMake()
	return self:TrainerCodeOf(nil, self:TrainerFaction())
end

-- blancs (ASCII, insécable, largeur nulle, BOM) retirés partout ; guillemets,
-- accents graves et astérisques aux deux bouts
local INVISIBLE = { "\194\160", "\226\128\139", "\226\128\140", "\226\128\141", "\226\129\160", "\239\187\191",
	"\226\128\175", "\226\128\136", "\226\128\137" }
local WRAPPERS = { "`", "\"", "'", "*", "\194\171", "\194\187", "\226\128\156", "\226\128\157", "\226\128\152", "\226\128\153",
	"\226\128\158", "\226\128\185", "\226\128\186" }
function ns.TrainerCodeClean(text)
	text = tostring(text or "")
	for _, mark in ipairs(INVISIBLE) do text = text:gsub(mark, "") end
	text = text:gsub("%s+", "")
	local changed = true
	while changed and text ~= "" do
		changed = false
		for _, mark in ipairs(WRAPPERS) do
			if text:sub(1, #mark) == mark then text, changed = text:sub(#mark + 1), true end
			if #text >= #mark and text:sub(-#mark) == mark then text, changed = text:sub(1, -#mark - 1), true end
		end
	end
	return text
end

-- texte collé -> fiche (table), nil et rien ; ou nil et la raison. Troisième
-- retour : { faction = "A" | "H" | nil, code = texte nettoyé }
function ns:TrainerCodeRead(text)
	local clean = ns.TrainerCodeClean(text)
	if clean == "" then return nil, "empty" end
	if #clean > ns.TRAINER_CODE_MAX then return nil, "long" end
	local head = clean:sub(1, 2):upper()
	local version, rest = clean:sub(3):match("^(%d+):(.*)$")
	if head ~= "QC" or not version then return nil, "prefix" end
	version = tonumber(version)
	if version > ns.TRAINER_CODE_VERSION then return nil, "newer" end
	if version ~= ns.TRAINER_CODE_VERSION then return nil, "prefix" end
	local body, sum = rest:match("^([^:]*):(%x%x%x%x%x%x%x%x)$")
	if not body then return nil, "sum" end
	local packed = ns.TRAINER_CODE_PREFIX .. body
	if ns.TrainerCodeSum(packed) ~= sum:lower() then return nil, "sum" end
	local plain = Unpack(body)
	local ok, card = pcall(self.TrainerParseCard, self, plain)
	if not ok or type(card) ~= "table" or not card.name then return nil, "card" end
	local fields = ns.TrainerDecode(plain)
	local faction = (fields.fa == "A" or fields.fa == "H") and fields.fa or nil
	return card, nil, { faction = faction, code = packed .. ":" .. sum:lower() }
end

function ns:TrainerCodeReason(reason)
	local key = "TRAINER_CODE_ERR_" .. tostring(reason)
	local text = L[key]
	if type(text) ~= "string" or text == key then text = L.TRAINER_CODE_ERR_sum end
	return text
end

-- le bouton « Code de dresseur » du pied de la fiche (TrainerCard.lua le
-- montre dès que cette fonction existe) : la page Communauté, onglet Dresseurs
function ns:TrainerCodeShow()
	if self.trainerFrame and self.trainerFrame.Hide then self.trainerFrame:Hide() end
	if self.CommunityOpen then return self:CommunityOpen("dresseurs") end
	return nil
end

if ns.Mark then ns.Mark("TrainerCode") end
