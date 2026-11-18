-- Espagnol (esES, esMX ; socle 3.6, R2Q 2.0.0, QC 3.3.0) : chaque texte des
-- deux addons a son espagnol, avec les mêmes codes que l'anglais (%s, %d,
-- couleurs, textures, retours à la ligne) ; données propres à la langue
-- (titres, juke-box, histoire des lieux, noms de Questie) complètes.
-- Le rendu en espagnol (ce qui tient à sa place) : python3 tools/i18n.py fit.
local Check, Say, NS, QNS = T.Check, T.Say, T.NS, T.QNS

Say("-- espagnol")

local CODES = {
	"%%[%-+ #0]*%d*%.?%d*[sdifgxXcq%%]", "|c%x%x%x%x%x%x%x%x", "|r", "|T[^|]*|t", "|A[^|]*|a", "\n", "|n",
}
local function Codes(text)
	local list = {}
	text = tostring(text or "")
	for _, pattern in ipairs(CODES) do
		for code in text:gmatch(pattern) do list[#list + 1] = code end
	end
	table.sort(list)
	return table.concat(list, " ")
end

for _, pair in ipairs({ { "R2Q", NS }, { "QC", QNS } }) do
	local name, ns = pair[1], pair[2]
	local tables = ns.STRINGS_TABLES
	local missing, bad, count = {}, {}, 0
	for key, en in pairs(tables.en) do
		if key ~= "TAG" and type(en) == "string" then
			count = count + 1
			local es = tables.es[key]
			if type(es) ~= "string" then missing[#missing + 1] = key
			elseif Codes(en) ~= Codes(es) then bad[#bad + 1] = key end
		end
	end
	table.sort(missing); table.sort(bad)
	Check("[ES] " .. name .. " : chaque texte anglais a son espagnol (" .. count .. ")", #missing == 0,
		table.concat(missing, ", ", 1, math.min(#missing, 15)))
	Check("[ES] " .. name .. " : mêmes codes que l'anglais (%s, %d, couleurs, textures, retours)", #bad == 0,
		table.concat(bad, ", ", 1, math.min(#bad, 15)))
end

-- titres des hauts faits : masculin et féminin, un seul %s, à la même place
do
	local problems = {}
	for code, title in pairs(QNS.FEAT_TITLES or {}) do
		local es = QNS.FEAT_TITLES_ES and QNS.FEAT_TITLES_ES[code]
		if not es then problems[#problems + 1] = tostring(code)
		else
			for _, form in ipairs({ es.m, es.f }) do
				local _, n = tostring(form):gsub("%%s", "")
				if n ~= 1 then problems[#problems + 1] = code .. ":" .. tostring(form) end
			end
		end
	end
	Check("[ES] titres : chacun en masculin et féminin, un %s", #problems == 0, table.concat(problems, ", "))
end

-- juke-box : un nom espagnol par groupe, dans le même ordre
do
	local groups = QNS.MUSIC_GROUPS_KEPT or QNS.MUSIC_GROUPS or ""
	local count = 0
	for _ in groups:gmatch("[^\n]*\t[^\n]*\t[^\n]*") do count = count + 1 end
	local es = QNS.MUSIC_GROUPS_ES or {}
	local empty = 0
	for _, name in ipairs(es) do if name == "" or name:find("[\t\n]") then empty = empty + 1 end end
	Check("[ES] juke-box : un nom par groupe (" .. count .. ")", count > 0 and #es == count and empty == 0, #es .. " / " .. count)
end

-- histoire des lieux : autant de lignes qu'en anglais, noms du client espagnol
do
	local raw = QNS.LORE_RAW or {}
	local function Lines(text, kind)
		local n = 0
		for _ in tostring(text or ""):gmatch("\n" .. kind .. "\t") do n = n + 1 end
		return n
	end
	local enZ, esZ = Lines(raw.en, "Z"), Lines(raw.es, "Z")
	local enS, esS = Lines(raw.en, "S"), Lines(raw.es, "S")
	Check("[ES] histoire des lieux : zones et sous-zones toutes en espagnol", esZ == enZ and esS == enS and enS > 0,
		esZ .. "/" .. enZ .. " " .. esS .. "/" .. enS)
	local spanishName = tostring(raw.es or ""):find("\nS\t1453\t[^\t]*Valle de los Héroes") ~= nil
	Check("[ES] histoire des lieux : le nom du client espagnol d'abord (Valle de los Héroes)", spanishName)
end

-- noms de Questie : créatures, quêtes, objets de récolte
do
	local raw = QNS.NAMES_ES_RAW or {}
	local npc = select(2, tostring(raw.npc or ""):gsub("\n", ""))
	local quest = select(2, tostring(raw.quest or ""):gsub("\n", ""))
	local item = select(2, tostring(raw.item or ""):gsub("\n", ""))
	Check("[ES] noms du jeu (Questie esES / esMX) : créatures, quêtes, objets", npc > 2000 and quest > 1500 and item > 40,
		npc .. " / " .. quest .. " / " .. item)
	Check("[ES] client français : pas de nom espagnol chargé (ns.SpanishName absent)", QNS.SpanishName == nil
		and QNS.STRINGS_LANG == "fr" and NS.STRINGS_LANG == "fr")
end
