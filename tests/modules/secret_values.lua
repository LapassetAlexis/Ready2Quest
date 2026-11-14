-- Valeurs secrètes du client (WoW Forever, 3.0.2 / 3.0.3) : le nom, le type,
-- le niveau ou la classification d'une unité peuvent être rendus « secrets »
-- (« attempt to compare local 'name' (a secret string value) »). L'addon ne
-- les lit pas : pas d'erreur, il fait comme s'il ne savait pas.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS

Say("-- valeurs secrètes")
ResetWorld()
local SECRET = "Nom secret"
local saved = {}
for _, name in ipairs({ "issecretvalue", "UnitName", "UnitGUID", "UnitCreatureType", "UnitClassification", "UnitLevel" }) do
	saved[name] = rawget(_G, name)
end
_G.issecretvalue = function(v) return v == SECRET end
_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return SECRET end
_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end return SECRET end
_G.UnitCreatureType = function() return SECRET end
_G.UnitClassification = function() return SECRET end
_G.UnitLevel = function(unit) if unit == "player" then return 20 end return SECRET end

local errors = #(NS.errors or {})
local bad = {}
local function Try(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then bad[#bad + 1] = label .. " : " .. tostring(err) end
end
Try("PNJ (GOSSIP_SHOW)", function() return NS:CompanionOnNpc("talk") end)
Try("bulle sans le nom", function()
	local text = NS.companionBubbleText
	if type(text) == "string" and text:find(SECRET, 1, true) then error("nom secret affiché") end
end)
if NS.TrainerUnitName then Try("nom d'un joueur", function() NS:TrainerUnitName("target") end) end
if NS.CompanionCreatureType then Try("type de créature", function() NS:CompanionCreatureType("npc") end) end
Check("[SECRET] PNJ, joueur, créature : valeurs secrètes ignorées, aucune erreur",
	#bad == 0 and #(NS.errors or {}) == errors, table.concat(bad, " ; "))


-- Garde de code : toute lecture d'une unité autre que « player » (nom, GUID,
-- type, famille, classification, niveau) passe par Plain / ns.Plain.
do
	local ROOT = rawget(_G, "ADDON_ROOT") or "."
	local function ReadFile(path)
		local h = io.open(ROOT .. "/" .. path, "rb")
		if not h then return nil end
		local data = h:read("*a")
		h:close()
		return data
	end
	local APIS = { "UnitName", "UnitFullName", "UnitGUID", "UnitCreatureType", "UnitCreatureFamily",
		"UnitClassification", "UnitLevel" }
	local offenders, files = {}, 0
	for line in (ReadFile("QuestCompanion/QuestCompanion.toc") or ""):gmatch("[^\r\n]+") do
		local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
		if file and not file:match("^Libs/") then
			local src = ReadFile("QuestCompanion/" .. file:gsub("\\", "/"))
			if src then
				files = files + 1
				local n = 0
				for l in (src .. "\n"):gmatch("([^\n]*)\n") do
					n = n + 1
					if not l:match("^%s*%-%-") and not l:find("Plain", 1, true) and not l:find('"player"', 1, true) then
						for _, api in ipairs(APIS) do
							if l:find('"' .. api .. '"', 1, true) and l:find("Call(", 1, true) then
								offenders[#offenders + 1] = file .. ":" .. n
								break
							end
						end
					end
				end
			end
		end
	end
	Check("[SECRET] lectures d'unité (hors joueur) protégées par Plain", files > 50 and #offenders == 0,
		table.concat(offenders, ", "))
end

for name, value in pairs(saved) do _G[name] = value end
ResetWorld()
