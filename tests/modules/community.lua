-- Page « Communauté » du carnet (QuestCompanion 3.7.0, JournalCommunity.lua) :
-- la section et son rang, la pastille de la colonne (avant et après la
-- première visite), les deux onglets, le champ du lien, les salons (cinq, et
-- une grille propre à six), le mot de la version (empreinte, juste, faux,
-- déjà validé, version suivante et ses paillettes), la composition de l'avis,
-- le diagnostic, les astuces du compagnon (une fois, conditions de jour), le
-- clavier (focus au clic, rendu à Échap et à la fermeture), les contrastes
-- sur le vrai fond, et l'absence de tout envoi.
local Check, Say, ResetWorld, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local NS = QNS
local Theme = NS.Theme

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local C = { saved = { version = NS.version, words = NS.COMMUNITY_WORDS, UnitLevel = rawget(_G, "UnitLevel"),
	TallyAdd = rawget(NS, "TallyAdd"), TallyGet = rawget(NS, "TallyGet") } }

function C.Reset(style)
	ResetWorld()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame, NS.uiStyleCache = nil, {}
	NS:DB().journalTab, NS:DB().journalState = nil, nil
	NS:DB().community = nil
	NS:CommunityResetAnswers()
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:DB().companionStyle = style or "sobre"
	NS:ApplyUIStyle()
	NS:CompanionData().tutoDone = true
	NS.version = C.saved.version
	NS.COMMUNITY_WORDS = C.saved.words
	NS.TallyAdd, NS.TallyGet = C.saved.TallyAdd, C.saved.TallyGet
end

function C.Done()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame, NS.uiStyleCache = nil, {}
	NS.version, NS.COMMUNITY_WORDS = C.saved.version, C.saved.words
	NS.TallyAdd, NS.TallyGet = C.saved.TallyAdd, C.saved.TallyGet
	_G.UnitLevel = C.saved.UnitLevel
	Mock.InstallAtlas(nil)
	NS:DB().companionStyle = nil
	NS:ApplyUIStyle()
	ResetWorld()
end

function C.Open(kind)
	NS:ToggleJournal(true)
	NS:SelectJournalKind(kind or "community")
	return NS.journalFrame
end

local function Shown(region) return region ~= nil and region.IsShown and region:IsShown() and true or false end

-- 1. La section, son rang, la page ---------------------------------------------------------------
do
	local s = Steps()
	for _, style in ipairs({ "sobre", "azeroth" }) do
		C.Reset(style)
		local f = C.Open("evolution")
		local list = NS.JOURNAL_SECTIONS
		local item, addons = f.sections.community, f.sections.addons
		s.ok(style .. " : onzième entrée, après Addons liés", #list == 11 and list[11] == "community" and list[10] == "addons")
		s.ok(style .. " : « Communauté » dans la colonne", item and item:GetText() == "Communauté")
		s.ok(style .. " : une ligne sous Addons liés", item and addons
			and select(5, item:GetPoint()) == select(5, addons:GetPoint()) - Theme.NAV_ITEM_HEIGHT)
		-- le résumé du bas descend d'un cran et tient
		local box = f.navSummary
		local top = -(box.lastPoint and box.lastPoint.y or 0)
		s.ok(style .. " : le résumé du bas sous la nouvelle ligne", top >= -select(5, item:GetPoint()) + Theme.NAV_ITEM_HEIGHT)
		NS:SelectJournalKind("community")
		s.ok(style .. " : la page s'ouvre, titre et sous-titre", f.kind == "community" and Shown(f.community)
			and f.header.title:GetText() == "Communauté"
			and f.header.subtitle:GetText() == "Le Discord, les dresseurs que tu connais, et ton avis sur l'addon.")
		s.ok(style .. " : les autres pages cachées", not Shown(f.addons) and not Shown(f.evo))
		C.Done()
	end
	s.check("[COM] section « Communauté » : onzième, sous Addons liés, la page et son en-tête (deux styles)")
end

-- 2. La pastille de la colonne -------------------------------------------------------------------
do
	local s = Steps()
	C.Reset("azeroth")
	local f = C.Open("evolution")
	local item = f.sections.community
	local dot = item.newDot
	s.ok("compte neuf : la pastille est là", dot ~= nil and Shown(dot))
	s.ok("dorée (or clair), à droite du mot", dot and dot.vertex[1] == Theme.GOLD_LIGHT[1] and dot.vertex[2] == Theme.GOLD_LIGHT[2]
		and dot.lastPoint.relTo == item.label and dot.lastPoint.relPoint == "RIGHT" and dot.lastPoint.x > 0)
	NS:SelectJournalKind("feats")
	s.ok("une autre page : toujours là", Shown(dot) and not NS:CommunitySeen())
	NS:SelectJournalKind("community")
	s.ok("première ouverture : elle s'éteint", not Shown(dot) and NS:CommunitySeen())
	NS:SelectJournalKind("evolution")
	s.ok("autre page ensuite : elle ne revient pas", not Shown(dot))
	-- le carnet refait (rechargement, autre style) : marque au compte
	f:Hide()
	NS.journalFrame = nil
	f = C.Open("evolution")
	s.ok("après rechargement : pas de pastille", not Shown(f.sections.community.newDot))
	s.ok("marque au compte (QuestCompanionDB.community.seen)", _G.QuestCompanionDB.community and _G.QuestCompanionDB.community.seen == true)
	C.Done()
	s.check("[COM] pastille dorée tant que la page n'a jamais été ouverte ; éteinte pour de bon à la première visite")
end

-- 3. Les onglets ---------------------------------------------------------------------------------
do
	local s = Steps()
	C.Reset("azeroth")
	local f = C.Open()
	local pane = f.community
	local ids = {}
	for _, chip in ipairs(pane.tabs.chips) do ids[#ids + 1] = chip.id end
	-- 3.7 (étape 3) : l'onglet Dresseurs (TrainerKnown.lua) en tête ; Discord reste ouvert par défaut
	s.ok("trois onglets : Dresseurs, Discord, Ton avis", table.concat(ids, ",") == "dresseurs,discord,avis"
		and pane.tabs.chips[1].text:GetText() == "Dresseurs" and pane.tabs.chips[2].text:GetText() == "Discord"
		and pane.tabs.chips[3].text:GetText() == "Ton avis")
	s.ok("Discord ouvert par défaut", pane.tab == "discord" and pane.tabs.selected == "discord" and Shown(pane.views.discord)
		and not Shown(pane.views.avis))
	s.ok("phrase de l'onglet Discord", pane.tabNote:GetText() == "Rien ne part d'ici : le lien se copie, c'est tout"
		and pane.tabNote.lastPoint.point == "RIGHT")
	pane.tabs.chips[3]:Click()
	s.ok("clic : Ton avis", pane.tab == "avis" and Shown(pane.views.avis) and not Shown(pane.views.discord)
		and pane.tabNote:GetText() == "Rien n'est envoyé d'ici : tu composes, tu copies, tu colles")
	-- la rangée accueille un onglet de plus en tête (étape suivante) sans refonte
	s.ok("onglets décrits par une table (Dresseurs posé en tête)", NS.COMMUNITY_TABS[1] == "dresseurs" and NS.COMMUNITY_TAB_DEFAULT == "discord")
	local right = pane.tabs.used
	s.ok("onglets et phrase sur la même rangée sans se toucher", right + 8 + pane.tabNote:GetStringWidth() <= NS.JournalUI.INNER, right)
	C.Done()
	s.check("[COM] trois onglets (Dresseurs en tête, Discord par défaut, Ton avis), la phrase de chaque onglet à droite")
end

-- 4. Onglet Discord : invitation, salons ---------------------------------------------------------
do
	local s = Steps()
	C.Reset("azeroth")
	local f = C.Open()
	local view = f.community.views.discord
	local head = view.head
	s.ok("titre de la tuile", head.title:GetText() == "Les Explorateurs De Mondes : le Discord des dresseurs")
	s.ok("tuile de tête choisie (filet doré)", head.selected == true)
	local box = head.link
	s.ok("le lien dans un champ", box:GetText() == "https://discord.gg/b9mYCUhxRb" and NS.COMMUNITY_INVITE == "https://discord.gg/b9mYCUhxRb")
	s.ok("pas de focus d'office", box.autoFocus == false and not box:HasFocus())
	box.HighlightText = function(self) self.highlighted = true end
	box:SetText("zzz")
	box.scripts.OnTextChanged(box)
	s.ok("lecture seule", box:GetText() == "https://discord.gg/b9mYCUhxRb")
	box.highlighted = nil
	box.scripts.OnMouseUp(box)
	s.ok("clic : focus et tout sélectionné", box:HasFocus() and box.highlighted == true)
	s.ok("consigne à côté", head.hint:GetText():find("Ctrl+C", 1, true) ~= nil and head.hint:GetText():find("Addons WoW Forever", 1, true) ~= nil)
	-- les cinq salons qui existent
	local names = {}
	for _, tile in ipairs(view.salons) do names[#names + 1] = tile.name:GetText() end
	s.ok("cinq salons, dans l'ordre", table.concat(names, ",") == "addons-annonces,captures-brillantes,addons-idées,addons-bugs,addons-english",
		table.concat(names, ","))
	s.ok("pas de fiches-de-dresseur (pas encore créé)", not table.concat(names, ","):find("fiches", 1, true))
	s.ok("textes de la maquette", view.salons[1].text:GetText() == "Les nouveautés et les bêtas. Le mot de la version y est épinglé."
		and view.salons[5].text:GetText() == "The same, in English.")
	s.ok("noms en bleu d'information", view.salons[1].name.comInk == Theme.ARCANE_LIGHT)
	local L = NS.JOURNAL_COMMUNITY_LAYOUT
	local function Pos(tile) return tile.lastPoint.x, -tile.lastPoint.y end
	local grid = true
	for index, tile in ipairs(view.salons) do
		local x, y = Pos(tile)
		local i = index - 1
		grid = grid and x == (i % 2) * L.salonX2 and y == L.salonY + math.floor(i / 2) * L.salonStep
	end
	s.ok("grille de deux colonnes, rangée par rangée", grid)
	local _, lastY = Pos(view.salons[#view.salons])
	s.ok("la grille finit avant le mot de la version", lastY + L.salonH < L.wordHeadY)
	C.Done()
	-- à six (le salon des fiches ouvert) : la grille reste propre
	for _, salon in ipairs(NS.COMMUNITY_SALONS) do if salon.id == "dresseurs" then salon.open = true end end
	C.Reset("sobre")
	f = C.Open()
	view = f.community.views.discord
	local six, clash = #view.salons == 6, false
	for i, a in ipairs(view.salons) do
		for j, b in ipairs(view.salons) do
			if i < j and a.lastPoint.x == b.lastPoint.x and a.lastPoint.y == b.lastPoint.y then clash = true end
		end
	end
	local _, y6 = Pos(view.salons[6])
	s.ok("à six : six tuiles, aucune sur une autre, au-dessus du mot", six and not clash and y6 + L.salonH < L.wordHeadY)
	for _, salon in ipairs(NS.COMMUNITY_SALONS) do if salon.id == "dresseurs" then salon.open = false end end
	C.Done()
	s.check("[COM] Discord : invitation dans un champ à copier (lecture seule, tout sélectionné au clic), cinq salons, grille propre à cinq comme à six")
end

-- 5. Le mot de la version ------------------------------------------------------------------------
do
	local s = Steps()
	s.ok("empreinte de contrôle (9.9, essai)", NS.CommunityWordHash("9.9", "essai") == "8f80158b", NS.CommunityWordHash("9.9", "essai"))
	s.ok("minuscules, espaces autour retirés", NS.CommunityWordHash("9.9", "  EsSaI ") == "8f80158b")
	s.ok("empreinte de la 3.7 posée", NS.COMMUNITY_WORDS["3.7"] == "df21dabd")
	local hex = true
	for _, h in pairs(NS.COMMUNITY_WORDS) do hex = hex and type(h) == "string" and h:match("^%x%x%x%x%x%x%x%x$") ~= nil end
	s.ok("seules des empreintes (8 chiffres hexadécimaux)", hex)
	C.Reset("azeroth")
	local adds = {}
	NS.TallyAdd = function(_, key) adds[#adds + 1] = key; return #adds end
	NS.version = "9.9.0"
	NS.COMMUNITY_WORDS = { ["9.9"] = NS.CommunityWordHash("9.9", "essai"), ["9.8"] = NS.CommunityWordHash("9.8", "avant"),
		["9.10"] = NS.CommunityWordHash("9.10", "apres") }
	s.ok("version en cours : 9.9", NS:CommunityVersion() == "9.9")
	local glitter = NS:Paillettes()
	local f = C.Open()
	local view = f.community.views.discord
	local word = view.word
	s.ok("tuile : texte de la maquette, champ, Valider inactif tant que rien n'est tapé",
		word.text:GetText():find("Explorateur des mondes", 1, true) ~= nil and Shown(word.box) and word.button.inactive == true)
	s.ok("champ : pas de focus d'office", word.box.autoFocus == false and not word.box:HasFocus())
	word.box:SetText("mauvais")
	word.box.scripts.OnTextChanged(word.box)
	s.ok("tapé : Valider actif", not word.button.inactive)
	word.button:Click()
	s.ok("mot faux : phrase douce, rien de compté", f.community.wordState == "wrong" and word.text:GetText():find("Pas tout à fait", 1, true)
		and not NS:CommunityWordDone("9.9") and #adds == 0 and NS:Paillettes() == glitter)
	s.ok("mot d'une autre version : faux ici", NS:CommunityWordSubmit("avant") == "wrong")
	word.box:SetText("  ESSAI ")
	word.box.scripts.OnTextChanged(word.box)
	word.box.scripts.OnEnterPressed(word.box)
	s.ok("mot juste (Entrée) : validé, compteur, pas de paillettes au premier", NS:CommunityWordDone("9.9") and adds[1] == "discordWord"
		and #adds == 1 and NS:Paillettes() == glitter)
	s.ok("confirmation dans la tuile, champ retiré", word.text:GetText() == "Mot juste, merci de ta visite ! Le mot de la 9.9 est validé."
		and not Shown(word.box) and not Shown(word.button))
	s.ok("déjà validé : rien de plus", NS:CommunityWordSubmit("essai") == "already" and #adds == 1 and NS:Paillettes() == glitter)
	-- carnet refait : la tuile dit que c'est fait
	f:Hide(); NS.journalFrame = nil
	f = C.Open()
	s.ok("plus tard : « validé », sans champ", f.community.views.discord.word.text:GetText():find("est validé", 1, true) ~= nil
		and not Shown(f.community.views.discord.word.box))
	-- version suivante : le deuxième mot du compte rapporte 25 paillettes
	NS.version = "9.10.2"
	s.ok("version suivante : 9.10 (majeure.mineure)", NS:CommunityVersion() == "9.10")
	local state, gift = NS:CommunityWordSubmit("Apres")
	s.ok("deuxième mot : 25 paillettes (raison « discord »)", state == "ok" and gift == 25 and NS:Paillettes() == glitter + 25
		and adds[2] == "discordWord")
	NS.version = "9.11.0"
	s.ok("version sans mot : dit qu'il viendra", NS:CommunityWordSubmit("x") == "none")
	s.ok("sauvegarde : les mots validés, au compte", _G.QuestCompanionDB.community.words["9.9"] == true
		and _G.QuestCompanionDB.community.words["9.10"] == true)
	-- sans compteurs (Tally.lua absent) : rien ne casse
	NS.TallyAdd = nil
	NS:DB().community.words = {}
	NS.version = "9.9.0"
	s.ok("sans compteurs : validé quand même", NS:CommunityWordSubmit("essai") == "ok")
	C.Done()
	s.check("[COM] mot de la version : empreinte djb2, juste (compteur), faux (doux, sans pénalité), déjà validé, deuxième mot : 25 paillettes")
end

-- 6. Ton avis : composer -------------------------------------------------------------------------
do
	local s = Steps()
	C.Reset("azeroth")
	_G.UnitLevel = function() return 38 end
	NS:CaptureData().count = 312
	local adds = {}
	local tally = {}
	NS.TallyAdd = function(_, key) adds[#adds + 1] = key; tally[key] = (tally[key] or 0) + 1 end
	NS.TallyGet = function(_, key) return tally[key] or 0 end
	local f = C.Open()
	NS:CommunitySelectTab("avis")
	local view = f.community.views.avis
	local picked = 0
	for _, q in ipairs(NS.COMMUNITY_QUESTIONS) do
		local row = view.questions[q.id]
		for _, chip in ipairs(row.chips) do if chip.selected then picked = picked + 1 end end
	end
	s.ok("trois questions, aucune réponse d'office", #view.questions == 3 and picked == 0)
	s.ok("libellés et réponses", view.questions.love.label:GetText() == "Quest Companion, pour toi :"
		and view.questions.love.chips[1].text:GetText() == "J'adore" and view.questions.fav.chips[3].text:GetText() == "les hauts faits")
	s.ok("champ libre vide, invite grisée, 600 caractères", view.free:GetText() == "" and Shown(view.free.placeholder)
		and view.free.edit.maxLetters == 600 and view.free.placeholder.comInk == Theme.MUTED)
	s.ok("rien de choisi : rien à composer, bouton inactif", NS:CommunityCompose() == nil and view.compose.inactive == true
		and view.copy:GetText() == "")
	s.ok("« Composer et copier » sans rien : rien", NS:CommunityComposeClick() == nil and #adds == 0)
	local days = NS:CompanionDaysTogether()
	local ctx = "(français, niveau 38, 312 espèces, " .. days .. (days > 1 and " jours)" or " jour)")
	local head = "**Avis sur Quest Companion " .. tostring(NS.version) .. "** " .. ctx
	s.ok("joint tout seul", view.joined:GetText() == "Joint tout seul : Quest Companion " .. tostring(NS.version)
		.. " · français · niveau 38 · 312 espèces · " .. days .. (days > 1 and " jours ensemble" or " jour ensemble"), view.joined:GetText())
	-- une réponse
	view.questions.love.chips[1]:Click()
	s.ok("une réponse : titre et ressenti", NS:CommunityCompose() == head .. "\nRessenti : j'adore", NS:CommunityCompose())
	s.ok("bouton actif dès une réponse", not view.compose.inactive)
	s.ok("la puce choisie se voit", view.questions.love.chips[1].selected and not view.questions.love.chips[2].selected)
	-- deux réponses (la deuxième question sautée)
	view.questions.fav.chips[3]:Click()
	s.ok("ressenti : seulement les questions répondues", NS:CommunityCompose() == head .. "\nRessenti : j'adore · je préfère les hauts faits")
	-- les trois et le texte libre
	view.questions.talk.chips[2]:Click()
	view.questions.fav.chips[1]:Click()
	view.free.edit:SetText("Pouvoir trier la Réserve par zone de capture.")
	view.free.edit.scripts.OnTextChanged(view.free.edit, true)
	local full = head .. "\nRessenti : j'adore · le compagnon parle juste bien · je préfère la capture\nPouvoir trier la Réserve par zone de capture."
	s.ok("trois réponses et texte libre : format de la maquette", NS:CommunityCompose() == full, NS:CommunityCompose())
	s.ok("la zone à copier montre l'avis avant le clic", view.copy:GetText() == full)
	view.copy.edit.HighlightText = function(self) self.highlighted = true end
	view.compose:Click()
	s.ok("« Composer et copier » : dans la zone, focus, tout sélectionné", view.copy:GetText() == full and view.copy.edit:HasFocus()
		and view.copy.edit.highlighted == true)
	s.ok("premier avis : compteur « feedback »", adds[1] == "feedback" and #adds == 1)
	view.compose:Click()
	s.ok("deuxième avis : pas de second compteur", #adds == 1)
	-- lecture seule
	view.copy.edit:SetText("bidouillé")
	view.copy.edit.scripts.OnTextChanged(view.copy.edit, true)
	s.ok("zone à copier en lecture seule", view.copy:GetText() == full)
	-- texte libre seul
	NS:CommunityResetAnswers()
	NS:CommunitySetFree("  Juste une idée.  ")
	s.ok("texte libre seul : titre et texte, sans ressenti", NS:CommunityCompose() == head .. "\nJuste une idée.")
	NS:CommunitySetFree("   ")
	s.ok("des espaces seulement : rien", NS:CommunityCompose() == nil)
	NS:CommunitySetFree(string.rep("a", 700))
	s.ok("texte libre plafonné à 600", #NS.communitySession.free == 600)
	-- réponses non sauvegardées
	local saved = false
	for _, v in pairs(_G.QuestCompanionDB.community or {}) do if type(v) == "table" and v.love then saved = true end end
	s.ok("réponses gardées le temps de la session seulement", not saved and NS.communitySession ~= nil)
	C.Done()
	s.check("[COM] Ton avis : aucune réponse d'office, chaque combinaison utile, texte libre seul, rien de choisi, zone à copier en lecture seule, compteur au premier avis")
end

-- 7. Le diagnostic -------------------------------------------------------------------------------
do
	local s = Steps()
	C.Reset("sobre")
	_G.UnitLevel = function() return 38 end
	local f = C.Open()
	NS:CommunitySelectTab("avis")
	local view = f.community.views.avis
	local print = rawget(NS, "Print")
	Mock:Reset()
	view.copy.edit.HighlightText = function(self) self.highlighted = true end
	view.diag:Click()
	local text = view.copy:GetText()
	s.ok("première ligne : version, client, langue, classe et niveau, Ready2Quest", text:find("^%*%*Diagnostic Quest Companion "
		.. tostring(NS.version):gsub("%.", "%%.") .. "%*%*") ~= nil and text:find("client ", 1, true) and text:find("français", 1, true)
		and text:find("Guerrier niveau 38", 1, true) and text:find("Ready2Quest", 1, true), text:match("^[^\n]*"))
	s.ok("puis le texte de /qc diag (en-tête, modules)", text:find("Diagnostic : v" .. tostring(NS.version), 1, true) ~= nil
		and text:find("client = ", 1, true) ~= nil, text)
	s.ok("sans codes de couleur", not text:find("|c", 1, true) and not text:find("|r", 1, true))
	s.ok("rien écrit dans le chat, Print rendu", Mock:Output() == "" and rawget(NS, "Print") == print)
	s.ok("dans la zone, tout sélectionné ; intertitre du diagnostic", view.copy.edit:HasFocus() and view.copy.edit.highlighted
		and view.copyHead.label:GetText() == Theme.Upper("Le diagnostic, à coller dans addons-bugs"))
	-- une action refusée gardée par le socle y figure
	NS:DB().actionLog = { { kind = "blocked", fn = "CastSpellByName", version = "3.7.0", at = "2026-11-22 10:00:00", zone = "Durotar", recent = {} } }
	s.ok("dernières actions refusées par le jeu", NS:CommunityDiagText():find("CastSpellByName", 1, true) ~= nil)
	-- retour à l'avis : l'intertitre revient
	NS:CommunityAnswer("love", 2)
	view.compose:Click()
	s.ok("« Composer et copier » ensuite : l'avis reprend la zone", view.copy:GetText():find("j'aime bien", 1, true) ~= nil
		and view.copyHead.label:GetText() == Theme.Upper("Ce que « Composer et copier » met dans la zone à copier"))
	C.Done()
	s.check("[COM] « Copier le diagnostic (bug) » : contexte puis /qc diag sans couleurs, actions refusées, rien dans le chat")
end

-- 8. Le clavier ----------------------------------------------------------------------------------
do
	local s = Steps()
	C.Reset("azeroth")
	local f = C.Open()
	local pane = f.community
	local auto, focused = true, false
	for _, edit in ipairs(pane.edits) do
		auto = auto and edit.autoFocus == false
		focused = focused or edit:HasFocus()
	end
	-- quatre champs, plus les deux de l'onglet Dresseurs (3.7, étape 3)
	s.ok("aucun champ ne prend le clavier d'office", auto and not focused and #pane.edits == 6)
	NS:CommunitySelectTab("avis")
	local free = pane.views.avis.free
	free.scripts.OnMouseDown(free)
	s.ok("clic dans le champ libre : le clavier", free.edit:HasFocus())
	free.edit.scripts.OnEscapePressed(free.edit)
	s.ok("Échap : rendu, le carnet reste ouvert", not free.edit:HasFocus() and f:IsShown())
	free.scripts.OnMouseDown(free)
	NS:CommunitySelectTab("discord")
	s.ok("changer d'onglet : rendu", not free.edit:HasFocus())
	local word = pane.views.discord.word.box
	word:SetFocus()
	NS:SelectJournalKind("guide")
	pane.scripts.OnHide(pane)
	s.ok("page quittée : rendu", not word:HasFocus())
	word:SetFocus()
	word.scripts.OnEscapePressed(word)
	s.ok("Échap dans le champ du mot : rendu", not word:HasFocus())
	C.Done()
	s.check("[COM] clavier : jamais d'office, au clic seulement ; rendu à Échap, au changement d'onglet et à la fermeture de la page")
end

-- 9. Les astuces du compagnon --------------------------------------------------------------------
do
	local s = Steps()
	C.Reset("sobre")
	-- une vraie date (l'horloge du banc part de presque zéro)
	Mock.now = math.max(Mock.now, 1800000000)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	NS:CommunityTipsInstall()
	local list, at = NS.DISCOVERY_TIPS, {}
	for index, tip in ipairs(list) do at[tip.id] = index end
	s.ok("dans la rotation existante, après le Guide", at.community and at.communityAvis and at.community == at.guide + 1
		and at.communityAvis == at.community + 1)
	NS:CommunityTipsInstall()
	local n = 0
	for _, tip in ipairs(list) do if tip.id == "community" then n = n + 1 end end
	s.ok("posées une seule fois", n == 1)
	s.ok("textes", NS.L.DISC_community:find("^Les dresseurs ont un Discord%. Regarde la page Communauté%.")
		and NS.L.DISC_communityAvis:find("^Une idée pour moi %? Page Communauté, onglet Ton avis%."))
	local tip1, tip2 = NS.DISCOVERY_BY_ID.community, NS.DISCOVERY_BY_ID.communityAvis
	local now = time()
	local function Since(days) NS:CompanionData().since = now - days * 86400 end
	Since(0)
	s.ok("premier jour du compte : aucune des deux", not tip1.eligible(NS) and not tip2.eligible(NS))
	Since(1)
	s.ok("deuxième jour : la première, pas la seconde", tip1.eligible(NS) and not tip2.eligible(NS))
	-- le plus ancien personnage du compte compte
	NS:DB().chars["Autre - Royaume"] = { companion = { since = now - 4 * 86400 } }
	s.ok("cinquième jour (un autre personnage du compte) : la seconde aussi", tip2.eligible(NS) and NS:CommunityAccountDay() == 5)
	-- une seule fois : DiscoveryPick la propose, dite, plus jamais
	local data = NS:DiscoveryData()
	for _, tip in ipairs(list) do if tip.id ~= "community" and tip.id ~= "communityAvis" then data.seen[tip.id] = true end end
	data.day, data.dayFirst = math.floor(now / 86400), now - NS.DISCOVERY_FIRST - 1
	NS.discoveryLastAt = nil
	local picked = NS:DiscoveryPick()
	s.ok("proposée par la rotation", picked == tip1, picked and picked.id)
	NS:DiscoveryShown(picked)
	s.ok("dite : vue au compte, jour noté", data.seen.community == true and data.seenDay and data.seenDay.community == math.floor(now / 86400))
	NS.discoveryLastAt = nil
	s.ok("la seconde : jamais le même jour que la première", NS:DiscoveryPick() == nil and not tip2.eligible(NS))
	Mock.now = Mock.now + 86400
	data.day, data.dayFirst = math.floor(time() / 86400), time() - NS.DISCOVERY_FIRST - 1
	NS.discoveryLastAt = nil
	s.ok("le lendemain : la seconde", NS:DiscoveryPick() == tip2)
	NS:DiscoveryShown(tip2)
	NS.discoveryLastAt = nil
	s.ok("puis plus rien (une fois chacune)", NS:DiscoveryPick() == nil)
	-- apprises : la page ouverte, l'onglet Ton avis vu
	data.seen.community, data.seen.communityAvis = nil, nil
	NS:DB().community = nil
	s.ok("pas encore apprises", not tip1.learned(NS) and not tip2.learned(NS))
	C.Open()
	s.ok("page ouverte : la première apprise", tip1.learned(NS) and not tip2.learned(NS))
	NS:CommunitySelectTab("avis")
	s.ok("onglet Ton avis vu : la seconde apprise", tip2.learned(NS))
	-- clic sur la bulle : la page et l'onglet
	NS.journalFrame:Hide()
	tip2.open(NS)
	s.ok("clic sur la bulle : Communauté, onglet Ton avis", NS.journalFrame:IsShown() and NS.journalFrame.kind == "community"
		and NS.journalFrame.community.tab == "avis")
	C.Done()
	s.check("[COM] astuces : dans la rotation, une fois chacune, pas avant le 2e (puis le 5e) jour du compte, jamais le même jour, apprises par la page")
end

-- 10. Contrastes sur le vrai fond ----------------------------------------------------------------
do
	local weakest = {}
	for _, style in ipairs({ "sobre", "azeroth" }) do
		local s = Steps()
		C.Reset(style)
		local f = C.Open()
		NS:CommunityAnswer("love", 1)
		NS:CommunitySelectTab("avis")
		NS:CommunitySelectTab("discord")
		local pane = f.community
		local forged = Theme.Forged()
		local K = Theme.FORGE_CARD
		local grounds = {
			page = { Theme.WINDOW },
			-- tuile : son fond, et en thème forgé le haut éclairci et le bas assombri de son relief
			tile = forged and { Theme.Over(Theme.ROW, Theme.WHITE, K.light), Theme.Over(Theme.ROW, Theme.SHADOW, K.dark) } or { Theme.ROW },
			-- creux : son fond au niveau insetFill (filet au repos et au focus), le noir de son ombre
			field = forged and { Theme.ForgeSurface(Theme.EDGE, Theme.FORGE.insetFill), Theme.ForgeSurface(Theme.ACTIVE, Theme.FORGE.insetFill),
				{ 0, 0, 0 } } or { Theme.FIELD },
			-- puce : la page, et le voile de la puce choisie
			chip = { Theme.WINDOW, Theme.Over(Theme.WINDOW, Theme.SELECT, forged and Theme.SelectAlpha(Theme.FORGE_CHIP.from) or 0.12) },
		}
		local worst, where = math.huge, ""
		local function Probe(name, ink, list, need)
			for _, bg in ipairs(list) do
				local c = Theme.Contrast(ink, bg)
				if c < need then s.ok(name, false, string.format("%.2f", c)) end
				if c < worst then worst, where = c, string.format("%s %.2f", name, c) end
			end
		end
		local count = 0
		for _, text in ipairs(pane.texts) do
			local ink = text.comInk
			local r, g, b = text:GetTextColor()
			-- la couleur posée est bien celle qu'on mesure (sauf puces : peintes par la brique)
			if text.comGround ~= "chip" and ink and (math.abs(r - ink[1]) > 0.002 or math.abs(g - ink[2]) > 0.002 or math.abs(b - ink[3]) > 0.002) then
				s.ok("encre posée = encre mesurée : " .. tostring(text:GetText()), false)
			end
			if ink and grounds[text.comGround] then
				count = count + 1
				Probe(text.comGround .. " « " .. tostring(text:GetText() or ""):sub(1, 24) .. " »", ink, grounds[text.comGround], 4.5)
			end
		end
		-- la puce choisie : parchemin sur son voile
		Probe("puce choisie", Theme.PARCHMENT, grounds.chip, 4.5)
		-- intertitres (texte en capitales, 10 px) : leur encre sur la page
		for _, section in ipairs(pane.sections) do
			local r, g, b = section.label:GetTextColor()
			Probe("intertitre " .. tostring(section.label:GetText()), { r, g, b }, grounds.page, 4.5)
		end
		-- titres (≥ 3) : en-tête de la tuile, titres d'idées
		Probe("titre de la tuile du Discord", Theme.PARCHMENT, grounds.tile, 3)
		-- confirmation et phrase douce du mot
		Probe("mot validé (vert)", Theme.GREEN, grounds.tile, 4.5)
		Probe("mot faux", Theme.LABEL, grounds.tile, 4.5)
		s.ok("tous les textes de la page mesurés (plus de 40)", count > 40, count)
		weakest[#weakest + 1] = style .. " : " .. where
		Say("-- communauté, contraste le plus faible (" .. style .. ") : " .. where)
		C.Done()
		s.check("[COM] " .. style .. " : contrastes de la page sur leur vrai fond (≥ 4,5 texte, ≥ 3 titres)")
	end
end

-- 11. Rien ne sort -------------------------------------------------------------------------------
do
	local s = Steps()
	C.Reset("azeroth")
	local sent = {}
	local saved = { SendChatMessage = rawget(_G, "SendChatMessage"), SendAddonMessage = rawget(_G, "SendAddonMessage"),
		C_ChatInfo = rawget(_G, "C_ChatInfo") }
	_G.SendChatMessage = function(...) sent[#sent + 1] = "chat" end
	_G.SendAddonMessage = function(...) sent[#sent + 1] = "addon" end
	_G.C_ChatInfo = { SendAddonMessage = function() sent[#sent + 1] = "addon" end,
		InChatMessagingLockdown = function() return false end, RegisterAddonMessagePrefix = function() return true end }
	Mock:Reset()
	local f = C.Open()
	local pane = f.community
	local word = pane.views.discord.word
	word.box:SetText("nimporte")
	NS:CommunityWordClick()
	NS:CommunitySelectTab("avis")
	NS:CommunityAnswer("love", 3)
	NS:CommunitySetFree("Une idée.")
	NS:CommunityAvisPaint()
	NS:CommunityComposeClick()
	NS:CommunityDiagClick()
	NS:CommunitySelectTab("discord")
	f:Hide()
	s.ok("aucun message envoyé (chat, addon)", #sent == 0, table.concat(sent, ","))
	s.ok("aucune ligne de chat", Mock:Output() == "", Mock:Output())
	local keys = {}
	for key in pairs(_G.QuestCompanionDB.community or {}) do keys[#keys + 1] = key end
	table.sort(keys)
	s.ok("gardé : page ouverte et mots validés, rien d'autre", table.concat(keys, ",") == "seen,words", table.concat(keys, ","))
	-- aucun appel d'envoi dans le fichier
	local handle = io.open(ADDON_ROOT .. "/QuestCompanion/JournalCommunity.lua", "r")
	local source = handle and handle:read("*a") or ""
	if handle then handle:close() end
	s.ok("le fichier n'appelle aucune fonction d'envoi", source ~= "" and not source:find("SendChatMessage", 1, true)
		and not source:find("SendAddonMessage", 1, true) and not source:find("ChatFrame", 1, true))
	for name, value in pairs(saved) do _G[name] = value end
	C.Done()
	s.check("[COM] rien ne sort : aucun message, aucune ligne de chat ; seuls « page ouverte » et les mots validés sont gardés")
end

-- 12. Textes et mise en page ---------------------------------------------------------------------
do
	local s = Steps()
	local pack = NS.JOURNAL_COMMUNITY_STRINGS
	local missing, glyphs = {}, {}
	for key, value in pairs(pack.fr) do
		if type(pack.en[key]) ~= "string" or pack.en[key] == "" or value == "" then missing[#missing + 1] = key end
	end
	for key in pairs(pack.en) do if pack.fr[key] == nil then missing[#missing + 1] = key end end
	for _, lang in ipairs({ "fr", "en" }) do
		for key, value in pairs(pack[lang]) do
			for _, glyph in ipairs({ "\226\152\133", "\226\152\134", "\226\156\147", "\226\156\148", "\226\156\151", "\226\156\152" }) do
				if value:find(glyph, 1, true) then glyphs[#glyphs + 1] = lang .. ":" .. key end
			end
		end
	end
	s.ok("chaque texte en français et en anglais", #missing == 0, table.concat(missing, ","))
	s.ok("jamais ★ ☆ ✓ ✗", #glyphs == 0, table.concat(glyphs, ","))
	s.ok("idées : une table en tête de fichier (titre, source), trois lignes", #NS.COMMUNITY_IDEAS == 3
		and NS.L.COM_IDEA_1 == "La collection commune à tout le compte" and NS.L.COM_IDEA_3_SRC == "demandée, livrée en 3.7")
	-- tout tient dans la page (au-dessus du pied) et rien ne chevauche la colonne de droite
	C.Reset("azeroth")
	local f = C.Open()
	local L = NS.JOURNAL_COMMUNITY_LAYOUT
	local ui = NS.JournalUI
	local room = -(ui.PAGER_Y - ui.TOP) + 24
	s.ok("note du bas (Discord) dans la page", L.discordNoteY + 2 * 15 <= room)
	s.ok("note du bas (Ton avis) dans la page", L.avisNoteY + 2 * 15 <= room)
	NS:CommunitySelectTab("avis")
	local view = f.community.views.avis
	for _, q in ipairs(NS.COMMUNITY_QUESTIONS) do
		local row = view.questions[q.id]
		s.ok("réponses « " .. q.id .. " » avant la colonne des idées", L.qLabelW + 4 + row.used <= L.ideasX - 10, row.used)
	end
	s.ok("questions dans leur colonne", L.qLabelW <= L.colW)
	for i, idea in ipairs(view.ideas) do
		s.ok("idée " .. i .. " sur sa ligne", idea.title:GetStringWidth() <= L.ideasW + 30 and idea.source:GetStringWidth() <= L.ideasW + 30)
	end
	local bottom = L.ideasY + (#NS.COMMUNITY_IDEAS - 1) * L.ideaStep + 16 + 14
	s.ok("idées au-dessus de leur note", bottom <= L.ideasNoteY)
	s.ok("boutons sous « Joint tout seul », au-dessus de la zone à copier", L.buttonsY >= L.joinedY + 14 and L.buttonsY + 24 <= L.copyHeadY - 10)
	C.Done()
	s.check("[COM] textes FR/EN sans glyphe, idées en table ; tout tient dans la page, rien sur la colonne des idées")
end
