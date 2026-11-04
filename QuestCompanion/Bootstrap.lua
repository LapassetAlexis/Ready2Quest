-- Bootstrap.lua (QuestCompanion) -- chargé EN PREMIER par QuestCompanion.toc
--
-- QuestCompanion est un addon à part, qui s'appuie sur le socle de
-- Ready2Quest (## Dependencies) : sauvegarde des réglages, options, thème,
-- textes, lieux sûrs. Il ne crée pas de namespace : il reprend celui que
-- Ready2Quest publie dans _G.Ready2Quest (fin de Core.lua), si bien que ses
-- fichiers se lisent comme avant la séparation (ns:DB(), ns.Theme…).
--
-- Ce qui lui appartient en propre : la progression de chaque personnage
-- (compagnon, carnet de voyage, bestiaire, récolte, coffres), rangée dans
-- QuestCompanionDB. Elle était dans Ready2QuestDB jusqu'à Ready2Quest 1.25 :
-- elle est déplacée, personnage par personnage, à sa première lecture.
-- Les réglages (bulles, suivi à l'écran…) restent dans Ready2QuestDB, avec
-- la page d'options de Ready2Quest qui les affiche.
local ADDON, qc = ...

local ns = rawget(_G, "Ready2Quest")
if type(ns) ~= "table" then
	-- Ready2Quest absent, désactivé ou planté avant la fin de Core.lua
	if type(print) == "function" then
		print("|cffe8a54bQuestCompanion|r — Ready2Quest est requis : active-le, puis /reload.")
	end
	return
end

ns.QC = { version = "1.0.0", addon = ADDON or "QuestCompanion", private = qc, loaded = false }
_G.QuestCompanion = ns.QC

-- Clés de CharData déplacées de Ready2QuestDB vers QuestCompanionDB
local MOVED = { "companion", "journal" }
ns.QC.MOVED_KEYS = MOVED

-- Avant ADDON_LOADED("QuestCompanion"), le client n'a pas encore posé
-- QuestCompanionDB : y écrire, c'est écrire dans une table qu'il va écraser.
-- On sert alors un brouillon jamais sauvegardé, et surtout on ne déplace rien.
local scratch = { chars = {} }

function ns:QCDB()
	if not ns.QC.loaded then return scratch end
	if type(QuestCompanionDB) ~= "table" then QuestCompanionDB = {} end
	local db = QuestCompanionDB
	if type(db.chars) ~= "table" then db.chars = {} end
	return db
end

-- Reprend la progression du personnage laissée dans Ready2QuestDB (une fois)
local function MigrateChar(self, key, char)
	local r2q = self:DB()
	local old = type(r2q.chars) == "table" and r2q.chars[key]
	if type(old) == "table" then
		for _, field in ipairs(MOVED) do
			if type(old[field]) == "table" then
				if char[field] == nil then char[field] = old[field] end
				old[field] = nil
			end
		end
	end
	char.migrated = true
end

function ns:QCCharData()
	local db = self:QCDB()
	local key = self:CharKey()
	local char = db.chars[key]
	if type(char) ~= "table" then
		char = {}
		db.chars[key] = char
	end
	if ns.QC.loaded and not char.migrated then MigrateChar(self, key, char) end
	return char
end

function ns:QCOnAddonLoaded()
	if ns.QC.loaded then return end
	ns.QC.loaded = true
	scratch = { chars = {} }
end

local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	frame:RegisterEvent("ADDON_LOADED")
	frame:SetScript("OnEvent", function(self, event, name)
		if name ~= ns.QC.addon then return end
		self:UnregisterEvent("ADDON_LOADED")
		local done, err = pcall(ns.QCOnAddonLoaded, ns)
		if not done then ns:RecordError("QuestCompanion:ADDON_LOADED", err) end
	end)
end

if ns.Mark then ns.Mark("QC.Bootstrap") end
