-- QuestCompanion 2.7.0, intégration des hauts faits : encodage compact du
-- catalogue (lignes décodées à la demande, mêmes ids, codes, points, portées,
-- critères et récompenses qu'avant : empreinte du catalogue), registre des
-- titres unique (FeatsTitles.lua), « le Malchanceux », dédoublonnage des
-- annonces de guilde, statistiques du diagnostic.
local Check, Say, NS = T.Check, T.Say, T.QNS

local I = {}

-- Sérialisation stable d'une valeur (clés triées)
function I.Ser(value)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		local parts = {}
		for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. I.Ser(value[key]) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	if kind == "function" then return "fn" end
	return tostring(value)
end

-- Empreinte 32 bits (djb2) d'une chaîne
function I.Hash(text)
	local h = 5381
	for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
	return string.format("%08x", h)
end

function I.Catalogue()
	local defs = {}
	for _, def in ipairs(NS:FeatDefs()) do defs[#defs + 1] = def end
	table.sort(defs, function(a, b) return a.n < b.n end)
	local lines = {}
	for _, def in ipairs(defs) do
		lines[#lines + 1] = table.concat({ def.id, def.n, def.cat, def.pts, def.scope, I.Ser(def.crit), I.Ser(def.reward),
			tostring(def.desc), tostring(def.pending == true), type(def.paid) }, "|")
	end
	return table.concat(lines, "\n"), #defs
end

-- 1. Catalogue décodé : identique ligne à ligne ------------------------------------------------------------
do
	Say("-- qc27 hauts faits : intégration (catalogue compact)")
	local text, count = I.Catalogue()
	local hash = I.Hash(text)
	Check("[HF-I] catalogue décodé : empreinte inchangée (ids, codes, points, portées, critères, récompenses)",
		hash == "beba8d94", "empreinte " .. hash .. " (" .. count .. " lignes)")
end
