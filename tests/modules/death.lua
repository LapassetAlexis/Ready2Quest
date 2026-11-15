-- Module « Après la mort » (v1.24.0) : distance au corps, coût du guérisseur
-- (faiblesse, réparation), verdict, fenêtre ou chat, instances, API absentes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

-- Globales du client absentes du harnais : posées ici, restaurées à la fin
local saved = {
	UnitIsGhost = rawget(_G, "UnitIsGhost"), IsInInstance = rawget(_G, "IsInInstance"),
	C_DeathInfo = rawget(_G, "C_DeathInfo"), GetResSicknessDuration = rawget(_G, "GetResSicknessDuration"),
	GetPlayerMapPosition = C_Map.GetPlayerMapPosition, GetWorldPosFromMapPos = C_Map.GetWorldPosFromMapPos,
	GetMapWorldSize = C_Map.GetMapWorldSize,
}

local D = { W = {} }   -- une seule locale pour les aides
local function Vec(x, y)
	return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
-- carte 1 : 1000 x 500 yards, origine monde (0, 0)
local function InstallMap()
	_G.UnitIsGhost = function() return D.W.ghost == true end
	_G.IsInInstance = function() return D.W.instance == true, D.W.instance and "party" or "none" end
	_G.C_DeathInfo = { GetCorpseMapPosition = function() return D.W.corpse and Vec(D.W.corpse[1], D.W.corpse[2]) or nil end }
	_G.GetResSicknessDuration = function() return D.W.sickText end
	C_Map.GetPlayerMapPosition = function() return D.W.player and Vec(D.W.player[1], D.W.player[2]) or nil end
	C_Map.GetWorldPosFromMapPos = function(_, pos) return 0, Vec(pos.x * 1000, pos.y * 500) end
	C_Map.GetMapWorldSize = function() return 1000, 500 end
end

function D.Reset(level)
	ResetWorld()
	D.W = {}
	InstallMap()
	NS.deathAdvice, NS.deathDismissed = nil, nil
	if NS.deathFrame then NS.deathFrame:Hide() end
	NS.deathFrame = nil
	Mock.world.level = level or 25
	Mock.world.durability = { [1] = { 100, 100 }, [5] = { 80, 100 } }   -- 25 + 25 = 50 points au guérisseur
end
function D.Die()
	Mock.world.dead = true
	Mock:Fire("PLAYER_DEAD")
end
-- libération : le fantôme apparaît au cimetière
function D.Release(corpse, player)
	D.W.ghost, D.W.corpse, D.W.player = true, corpse, player
	Mock:Fire("PLAYER_ALIVE")
end
function D.Text()
	local out = {}
	local frame = NS.deathFrame
	for i = 1, (frame and frame.visibleLines or 0) do out[#out + 1] = frame.lines[i].text.text or "" end
	return table.concat(out, " | ")
end
function D.Shown() return NS.deathFrame ~= nil and NS.deathFrame:IsShown() == true end

do
	Say("-- chargement, réglages")
	D.Reset()
	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "death" then page = def end end
	Check("[MORT] chargé, réglages par défaut, sous-page du QoL, module « mort »", NS.Loaded.Death == true
		and NS:DB().deathEnabled == true and NS:DB().deathPanel == true
		and page and page.parent == "qol" and page.group == "OPT_GROUP_QOL" and #page.rows == 2
		and NS:FindModule("mort") and NS:FindModule("mort").key == "deathEnabled")
end

do
	Say("-- faiblesse par niveau")
	local bad = {}
	for level, want in pairs({ [5] = 0, [10] = 0, [15] = 300, [20] = 600, [25] = 600 }) do
		if NS:SicknessFromLevel(level) ~= want then bad[#bad + 1] = level .. "=" .. tostring(NS:SicknessFromLevel(level)) end
	end
	Check("[MORT] table : rien jusqu'au niveau 10, 5 min au 15, plafond 10 min dès le 20", #bad == 0, table.concat(bad, ", "))
	Check("[MORT] durée du client lue (« 3 Min »), illisible ignorée", NS:ParseSicknessText("3 Min") == 180
		and NS:ParseSicknessText("bientôt") == nil)
	D.Reset(25)
	D.W.sickText = "3 Min"
	Check("[MORT] la durée du client prime sur la table", NS:DeathSickness(25) == 180, NS:DeathSickness(25))
end

do
	Say("-- mort, puis fantôme")
	D.Reset(25)
	NS:CharData().repairRate = 500              -- 50 points * 500 = 2 po 50 pa
	D.Die()
	Check("[MORT] fenêtre à la mort ; avant libération : distance à venir, pas de verdict", D.Shown()
		and D.Text():find("libère ton esprit", 1, true) ~= nil and NS.deathAdvice.verdict == nil, D.Text())
	-- 175 yards sur l'axe x : 175 / 8,75 = 20 s
	D.Release({ 0.5, 0.5 }, { 0.675, 0.5 })
	local a = NS.deathAdvice
	Check("[MORT] distance depuis les positions monde, temps à vitesse de fantôme (125 %)", a and math.abs(a.distance - 175) < 0.01
		and math.abs(a.runTime - 20) < 0.01, a and a.distance)
	Check("[MORT] réparation du guérisseur (25 % du max)", a.points == 50 and a.cost == 25000, tostring(a.points) .. "/" .. tostring(a.cost))
	Check("[MORT] verdict : cours (20 s < 10 min)", a.verdict == "run", a.verdict)
	local missing = {}
	for _, part in ipairs({ "175 m, ~20 s", "-2 po 50 pa de réparation, 10 min de faiblesse", "Les 10 % de la mort sont déjà perdus",
		"Cours :", "Règle :" }) do
		if not D.Text():find(part, 1, true) then missing[#missing + 1] = part end
	end
	Check("[MORT] texte : distance, coût, rappel des 10 %, verdict, règle", #missing == 0, table.concat(missing, " / "))
	local lines = NS.deathFrame.lines
	-- 1.35.0 : le verdict (3e) avant la note (4e) et la règle (5e)
	Check("[MORT] verdict avant les notes ; note et règle sur deux lignes, pas coupées", lines[4].height > lines[1].height
		and lines[5].height > lines[1].height and lines[3].height == lines[1].height
		and (lines[3].text.text or ""):find("Cours :", 1, true) ~= nil,
		lines[1].height .. "/" .. lines[3].height .. "/" .. lines[4].height .. "/" .. lines[5].height)
	-- la course avance : recalcul à la seconde
	D.W.player = { 0.5875, 0.5 }
	Mock:Advance(1)
	Check("[MORT] distance rafraîchie pendant la course", math.abs(NS.deathAdvice.distance - 87.5) < 0.01, NS.deathAdvice.distance)
	Mock.world.dead, D.W.ghost = false, false
	Mock:Fire("PLAYER_UNGHOST")
	Check("[MORT] cachée à la résurrection (UNGHOST)", not D.Shown() and NS.deathAdvice == nil)
end

do
	Say("-- verdict guérisseur, sans taux de réparation")
	D.Reset(11)                                 -- 1 min de faiblesse
	D.Die()
	D.Release({ 0, 0.5 }, { 1, 0.5 })           -- 1000 yards : ~114 s
	local a = NS.deathAdvice
	Check("[MORT] verdict : guérisseur (114 s > 1 min)", a.verdict == "healer"
		and D.Text():find("Guérisseur : la course est plus longue", 1, true) ~= nil, D.Text())
	Check("[MORT] sans taux mesuré : le % seul, 1 min de faiblesse", a.cost == nil and D.Text():find("-25 % de durabilité", 1, true) ~= nil
		and D.Text():find("1 min de faiblesse", 1, true) ~= nil, D.Text())
	-- limite : course juste sous la faiblesse -> cours
	D.Reset(11)
	D.Die()
	D.Release({ 0, 0.5 }, { 0.52, 0.5 })        -- 520 yards : 59,4 s < 60 s
	Check("[MORT] limite : 59 s < 1 min -> cours", NS.deathAdvice.verdict == "run", NS.deathAdvice.runTime)
	D.Reset(5)
	D.Die()
	D.Release({ 0, 0.5 }, { 0.1, 0.5 })
	Check("[MORT] niveau 5 : pas de faiblesse affichée", D.Text():find("pas de faiblesse à ton niveau", 1, true) ~= nil, D.Text())
	-- relevé par un joueur avant la libération
	D.Reset(25)
	D.Die()
	Mock.world.dead = false
	Mock:Fire("PLAYER_ALIVE")
	Check("[MORT] relevé sans être fantôme : cachée", not D.Shown())
end

do
	Say("-- instances")
	D.Reset(25)
	D.W.instance = true
	D.Die()
	local noFrame = not D.Shown() and NS.deathAdvice == nil
	NS:DB().deathPanel = false
	Mock:Reset()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	Check("[MORT] en instance : ni fenêtre ni chat", noFrame and Mock:Output() == "", Mock:Output())
	-- mort dehors, puis entrée du fantôme dans l'instance
	D.Reset(25)
	D.Die()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	local outside = D.Shown()
	D.W.instance = true
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[MORT] fenêtre dehors, cachée quand le fantôme entre dans l'instance", outside and not D.Shown())
end

do
	Say("-- API absentes")
	local errors = #NS.errors
	D.Reset(25)
	_G.C_DeathInfo = nil
	D.Die()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	Check("[MORT] sans C_DeathInfo : distance inconnue, pas de verdict inventé", NS.deathAdvice.distance == nil
		and D.Text():find("distance inconnue", 1, true) ~= nil and NS.deathAdvice.verdict == nil
		and D.Text():find("À toi de voir", 1, true) ~= nil, D.Text())
	D.Reset(25)
	C_Map.GetWorldPosFromMapPos = nil
	D.Die()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	Check("[MORT] sans positions monde : taille de carte", NS.deathAdvice.distance and math.abs(NS.deathAdvice.distance - 100) < 0.01, NS.deathAdvice.distance)
	D.Reset(25)
	-- sans aucune conversion, API qui lève une erreur, pas de corps (déjà repris) : inconnue
	local known = {}
	D.Reset(25)
	C_Map.GetWorldPosFromMapPos, C_Map.GetMapWorldSize = nil, nil
	D.Die()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	if NS.deathAdvice.distance ~= nil then known[#known + 1] = "conversion" end
	D.Reset(25)
	C_Map.GetPlayerMapPosition = function() error("restreint") end
	D.Die()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	if NS.deathAdvice.distance ~= nil then known[#known + 1] = "erreur" end
	D.Reset(25)
	D.Die()
	D.Release(nil, { 0.6, 0.5 })
	if NS.deathAdvice.distance ~= nil then known[#known + 1] = "corps" end
	Check("[MORT] sans conversion, API en erreur, sans corps : distance inconnue, aucune erreur enregistrée", #known == 0
		and #NS.errors == errors, table.concat(known, ",") .. " " .. tostring(NS.errors[#NS.errors] and NS.errors[#NS.errors].message))
end

do
	Say("-- module coupé, chat, fermeture")
	D.Reset(25)
	NS:DB().deathEnabled = false
	Mock:Reset()
	D.Die()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	Check("[MORT] module coupé : ni fenêtre ni chat", not D.Shown() and NS.deathAdvice == nil and Mock:Output() == "", Mock:Output())

	D.Reset(25)
	NS:DB().deathPanel = false
	NS:CharData().repairRate = 500
	Mock:Reset()
	D.Die()
	Check("[MORT] chat : rien à la mort même", Mock:Output() == "", Mock:Output())
	D.Release({ 0.5, 0.5 }, { 0.675, 0.5 })
	local out = Mock:Output()
	Check("[MORT] chat : une ligne à la libération, pas de fenêtre", out:find("Après la mort — Cours : 175 m, ~20 s · Guérisseur : -2 po 50 pa de réparation, 10 min de faiblesse · conseil : cours", 1, true) ~= nil
		and not D.Shown(), out)
	Mock:Reset()
	Mock:Advance(3)
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[MORT] chat : pas de répétition pendant la course", Mock:Output() == "", Mock:Output())
	Mock:Fire("CONFIRM_XP_LOSS")
	Check("[MORT] chat : rappel chez le guérisseur", Mock:Output():find("Après la mort", 1, true) ~= nil)

	D.Reset(25)
	D.Die()
	NS.deathFrame.closeButton:Click()
	D.Release({ 0.5, 0.5 }, { 0.6, 0.5 })
	Mock:Advance(1)
	Check("[MORT] fermée à la main : ne revient pas pendant cette mort", not D.Shown())
	Mock.world.dead, D.W.ghost = false, false
	Mock:Fire("PLAYER_UNGHOST")
	D.Die()
	Check("[MORT] mort suivante : la fenêtre revient", D.Shown())
end

do
	Say("-- textes fr / en")
	local S, missing = NS.DEATH_STRINGS, {}
	for k in pairs(S.fr) do if S.en[k] == nil then missing[#missing + 1] = "en:" .. k end end
	for k in pairs(S.en) do if S.fr[k] == nil then missing[#missing + 1] = "fr:" .. k end end
	Check("[MORT] chaque clé dans les deux langues", #missing == 0, table.concat(missing, ","))
	Check("[MORT] anglais : yards, ligne de chat", string.format(S.en.DEATH_RUN_SHORT, 175, "20 s") == "175 yd, ~20 s"
		and string.format(S.en.DEATH_CHAT, "175 yd, ~20 s", "-2g 50s in repairs, 10 min of sickness", "run")
		== "After death — Run: 175 yd, ~20 s · Healer: -2g 50s in repairs, 10 min of sickness · advice: run")
end

-- remise en état pour les fichiers suivants
D.Reset()
_G.UnitIsGhost, _G.IsInInstance = saved.UnitIsGhost, saved.IsInInstance
_G.C_DeathInfo, _G.GetResSicknessDuration = saved.C_DeathInfo, saved.GetResSicknessDuration
C_Map.GetPlayerMapPosition, C_Map.GetWorldPosFromMapPos, C_Map.GetMapWorldSize =
	saved.GetPlayerMapPosition, saved.GetWorldPosFromMapPos, saved.GetMapWorldSize
Mock.world.dead = false
