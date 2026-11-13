-- Couloir des bandeaux du haut (QuestCompanion 3.0.1, Banners.lua) : carnet
-- (« Haut fait obtenu », tampons), guilde (« GUILDE ») et résultat
-- (« Capturé ! ») ne se superposent plus : une place, une file dans l'ordre
-- d'arrivée, le résultat devant la file sans couvrir un bandeau affiché ;
-- exploits d'un même membre fusionnés ; le bandeau de capture empilé
-- dessous ; un bandeau ne couvre pas une fenêtre centrale ; cadres réutilisés.
local Check, ResetWorld, Mock = T.Check, T.ResetWorld, T.Mock
local NS = T.QNS

local B = { W = 1920, H = 1080 }

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

function B.Reset()
	ResetWorld()
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	if NS.journalToast then NS.journalToast:Hide() end
	NS:GuildFeatsReset()
	NS.captureResultPending = nil
	NS:CaptureResultHide()
	if NS.captureToast then NS.captureToast:Hide() end
	NS.bannerLane.showing, NS.bannerLane.frame, NS.bannerLane.waiting = nil, nil, {}
	local db = NS:DB()
	db.journalToast, db.featToast = nil, nil
	db.journalToastPoint, db.guildFeatToastPoint, db.captureResultPoint, db.captureToastPoint = nil, nil, nil, nil
end

-- Une passe de chaque horloge, `dt` secondes plus tard
function B.Step(dt)
	Mock.now = Mock.now + (dt or 0)
	NS:UpdateJournalToast(NS.Now())
	NS:GuildFeatsToastTick(NS.Now())
	NS:CaptureResultTick(NS.Now())
end

function B.Shown()
	local list = {}
	if NS.journalToast and NS.journalToast:IsShown() then list[#list + 1] = "journal" end
	if NS.guildFeatToast and NS.guildFeatToast:IsShown() then list[#list + 1] = "guild" end
	if NS.captureResult and NS.captureResult:IsShown() then list[#list + 1] = "result" end
	return list
end

function B.Feat(name) return { kind = "feat", id = "x", title = "Haut fait obtenu", name = name, points = 5 } end
function B.Guild(key, line, score)
	return { key = key, sender = key, feat = { kind = "n" }, info = { kind = "n", line = line, sub = "Raptor" },
		score = score or 1, at = Mock.now }
end

-- Joue l'horloge jusqu'à ce que tout soit passé ; rend l'ordre d'apparition
-- et la plus grande foule à l'écran
function B.Play(seconds)
	local order, most, last = {}, 0, nil
	for _ = 1, math.floor((seconds or 40) / 0.25) do
		local shown = B.Shown()
		most = math.max(most, #shown)
		local now = shown[1]
		if now and now ~= last then order[#order + 1] = now end
		last = now
		B.Step(0.25)
	end
	return order, most
end

-- 1. Trois bandeaux dans la même image : un à la fois, tous montrés -----------------
do
	local s = Steps()
	B.Reset()
	NS:JournalToastPush(B.Feat("Premier filet"))
	NS:GuildFeatsEnqueue(B.Guild("bob", "Bob a capturé 10 espèces !"))
	NS:CaptureResultQueue({ name = "Raptor" })
	B.Step(0)
	local order, most = B.Play(40)
	s.ok("jamais deux à la fois", most == 1, most)
	s.ok("tous montrés", #order == 3, table.concat(order, ","))
	s.ok("le carnet (arrivé seul) d'abord, puis le résultat devant la guilde", table.concat(order, ",") == "journal,result,guild",
		table.concat(order, ","))
	s.ok("place rendue à la fin", NS:BannerShowing() == nil)
	s.check("[BAN] trois bandeaux d'un coup : un seul à la fois, chacun montré, le résultat passe devant la file")
end

-- 2. Ordre d'arrivée, chacun sa durée entière ------------------------------------------
do
	local s = Steps()
	B.Reset()
	NS:GuildFeatsEnqueue(B.Guild("ann", "Ann a scellé une zone !"))
	B.Step(0)
	NS:JournalToastPush(B.Feat("Bourlingueur"))
	s.ok("la guilde arrivée d'abord est à l'écran, le carnet attend", B.Shown()[1] == "guild" and #B.Shown() == 1)
	local start = Mock.now
	local journalAt
	for _ = 1, 80 do
		B.Step(0.25)
		if not journalAt and B.Shown()[1] == "journal" then journalAt = Mock.now end
	end
	s.ok("le carnet après la durée entière de la guilde", journalAt and journalAt - start >= NS.GFEAT_TOAST_SECONDS, journalAt and journalAt - start)
	-- le résultat n'interrompt pas un bandeau affiché
	B.Reset()
	NS:JournalToastPush(B.Feat("Sur la route"))
	B.Step(0.25)
	NS:CaptureResultQueue({ name = "Loup" })
	B.Step(0.25)
	s.ok("résultat : attend la fin du bandeau affiché", B.Shown()[1] == "journal" and #B.Shown() == 1)
	-- (3.1.0 : un haut fait porte le bouton Partager, 3 s de plus)
	B.Step(5 + (NS.SHARE_EXTRA or 0))
	s.ok("puis s'affiche", B.Shown()[1] == "result")
	s.check("[BAN] file : ordre d'arrivée, durée entière ; le résultat n'interrompt jamais un bandeau affiché")
end

-- 3. Exploits d'un même membre : un seul bandeau -----------------------------------------
do
	local s = Steps()
	B.Reset()
	NS:GuildFeatsEnqueue(B.Guild("lio", "Lio a capturé 10 espèces !", 2))
	NS:GuildFeatsEnqueue(B.Guild("lio", "Lio : nouveau titre", 5))
	NS:GuildFeatsEnqueue(B.Guild("lio", "Lio a capturé un loup", 1))
	local queue = NS:GuildFeatsQueue()
	s.ok("un seul en file, le meilleur", #queue == 1 and queue[1].score == 5)
	s.ok("les deux autres comptés", queue[1] and queue[1].info.more == 2, queue[1] and queue[1].info.more)
	B.Step(0)
	local f = NS.guildFeatToast
	s.ok("bandeau : « et 2 autres exploits »", f and f.hint.text:find("et 2 autres exploits", 1, true) ~= nil, f and f.hint.text)
	NS:GuildFeatsEnqueue(B.Guild("lio", "Lio a capturé un sanglier", 1))
	s.ok("pendant l'affichage : compté sur le bandeau, pas de second", #NS:GuildFeatsQueue() == 0
		and f.hint.text:find("et 3 autres exploits", 1, true) ~= nil, f.hint.text)
	NS:GuildFeatsEnqueue(B.Guild("max", "Max a scellé une zone !", 1))
	s.ok("un autre membre : sa propre place en file", #NS:GuildFeatsQueue() == 1)
	s.check("[BAN] exploits de guilde d'un même membre fusionnés en un bandeau")
end

-- 4. Cadres réutilisés --------------------------------------------------------------------
do
	local s = Steps()
	B.Reset()
	NS:JournalToastPush(B.Feat("Un"))
	NS:GuildFeatsEnqueue(B.Guild("a", "A !"))
	NS:CaptureResultQueue({ name = "Raptor" })
	B.Play(30)
	local frames = #Mock.frames
	for round = 1, 3 do
		NS:JournalToastPush(B.Feat("Encore " .. round))
		NS:GuildFeatsEnqueue(B.Guild("b" .. round, "B !"))
		NS:CaptureResultQueue({ name = "Loup" })
		B.Play(30)
	end
	s.ok("aucun cadre de plus", #Mock.frames == frames, #Mock.frames - frames)
	s.check("[BAN] bandeaux : les mêmes cadres resservent")
end

-- 5. Bandeau de capture dessous, fenêtres centrales évitées ------------------------------
do
	local s = Steps()
	B.Reset()
	local FRACTION = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, CENTER = { 0.5, 0.5 }, BOTTOMLEFT = { 0, 0 } }
	local function Edges(frame)
		local p = frame.lastPoint or { point = "CENTER" }
		local own = FRACTION[p.point] or FRACTION.CENTER
		local rel = FRACTION[p.relPoint or p.point] or FRACTION.CENTER
		local x, y = rel[1] * B.W + (p.x or 0), rel[2] * B.H + (p.y or 0)
		local l, b = x - own[1] * frame.width, y - own[2] * frame.height
		return l, l + frame.width, b + frame.height, b
	end
	local function Geo(frame)
		frame.GetLeft = function(self) return (Edges(self)) end
		frame.GetRight = function(self) return (select(2, Edges(self))) end
		frame.GetTop = function(self) return (select(3, Edges(self))) end
		frame.GetBottom = function(self) return (select(4, Edges(self))) end
		return frame
	end
	local function Rect(f) local l, r, t, b = Edges(f); return { l = l, r = r, t = t, b = b } end
	local function Overlap(a, b)
		local x, y = Rect(a), Rect(b)
		return x.l < y.r and y.l < x.r and x.b < y.t and y.b < x.t
	end
	local saved = { width = UIParent.width, height = UIParent.height }
	UIParent.width, UIParent.height = B.W, B.H
	local journal = Geo(NS:EnsureJournalToast())
	journal:SetSize(300, 110)
	local toast = Geo(NS:EnsureCaptureToast())
	toast:SetSize(320, 100)
	toast:Show()
	NS:BannerStackCapture()
	NS:JournalToastPush(B.Feat("Premier filet"))
	s.ok("carnet et capture à l'écran", journal:IsShown() and toast:IsShown())
	s.ok("capture sous le bandeau, sans le toucher", not Overlap(journal, toast) and Rect(toast).t <= Rect(journal).b)
	journal:Hide(); NS:BannerDone("journal")
	local home = Rect(toast)
	s.ok("bandeau parti : la capture revient à sa place", math.abs(home.t - (B.H - 240)) < 0.01, home.t)
	toast:Hide()
	-- une fenêtre centrale (couloir du socle) sous le bandeau : il passe ailleurs
	B.Reset()
	local window = Geo(CreateFrame("Frame", nil, UIParent))
	window:SetSize(500, 400)
	window:SetPoint("CENTER", UIParent, "CENTER", 0, 300)
	window:Show()
	NS.PopupPlace(window)
	NS:JournalToastPush(B.Feat("Bourlingueur"))
	s.ok("bandeau hors de la fenêtre", journal:IsShown() and not Overlap(journal, window))
	s.ok("la fenêtre n'a pas bougé", Rect(window).t == B.H / 2 + 300 + 200)
	journal:Hide(); NS:BannerDone("journal")
	-- placé par le joueur : jamais bougé
	NS:DB().journalToastPoint = { point = "TOP", x = 0, y = -190 }
	journal:ClearAllPoints(); journal:SetPoint("TOP", UIParent, "TOP", 0, -190)
	NS:JournalToastPush(B.Feat("Sur la route"))
	s.ok("placé par le joueur : laissé", journal.lastPoint.point == "TOP" and journal.lastPoint.y == -190)
	window:Hide()
	journal:Hide()
	NS.Popups.frames[window] = nil
	UIParent.width, UIParent.height = saved.width, saved.height
	B.Reset()
	s.check("[BAN] capture empilée sous le bandeau ; bandeau hors des fenêtres centrales ; place du joueur gardée")
end

-- 6. Lot de hauts faits : le bandeau les nomme, le chat les liste, le clic ouvre la page --------
do
	local s = Steps()
	B.Reset()
	local three = { "Premiers pas", "Sur la route", "Vétéran" }
	local five = { "Premiers pas", "Sur la route", "Vétéran", "Bourlingueur", "Le traqueur" }
	s.ok("trois : les trois", NS:FeatNamesLine(three) == "Premiers pas · Sur la route · Vétéran", NS:FeatNamesLine(three))
	s.ok("cinq : trois, « et 2 autres »", NS:FeatNamesLine(five) == "Premiers pas · Sur la route · Vétéran et 2 autres",
		NS:FeatNamesLine(five))
	local narrow = NS:FeatNamesLine(five, function(text) return #text <= 30 end)
	s.ok("étroit : moins de noms, toujours le compte", narrow == "Premiers pas et 4 autres", narrow)
	local tiny = NS:FeatNamesLine(five, function(text) return #text <= 18 end)
	s.ok("très étroit : premier nom raccourci", #tiny <= 18 and tiny:find("…", 1, true) ~= nil and tiny:find("et 4 autres", 1, true) ~= nil, tiny)
	-- chat : tous les noms, en lignes d'environ 250 caractères
	local many = {}
	for i = 1, 40 do many[i] = "Haut fait numéro " .. i end
	local lines = NS:FeatChatLines(many, 400)
	local joined = table.concat(lines, " ")
	local missing, long = 0, 0
	for _, name in ipairs(many) do if not joined:find(name .. ",", 1, true) and not joined:find(name .. " (", 1, true) then missing = missing + 1 end end
	for _, line in ipairs(lines) do if #line > 270 then long = long + 1 end end
	s.ok("chat : tous les noms", missing == 0, missing)
	s.ok("chat : coupé en lignes courtes", #lines > 1 and long == 0, #lines)
	s.ok("chat : en tête et points à la fin", lines[1]:find("Hauts faits obtenus : ", 1, true) == 1
		and lines[#lines]:find("(400 points).", 1, true) ~= nil)
	-- bandeau réel, puis clic : la page Hauts faits, les obtenus du plus récent
	Mock:Reset()
	NS:DB().featChat = nil
	NS.featPending = {}
	for i, name in ipairs(five) do NS.featPending[i] = { id = "x" .. i, name = name, pts = 5 } end
	NS:FeatFlush(true)
	local toast = NS.journalToast
	s.ok("un bandeau qui nomme", toast and toast:IsShown() and toast.text:GetText():find("Premiers pas", 1, true) == 1
		and toast.text:GetText():find("autres", 1, true) ~= nil, toast and toast.text:GetText())
	s.ok("une ligne de chat même réglage coupé", Mock:Output():find("Hauts faits obtenus : Premiers pas, Sur la route, Vétéran, Bourlingueur, Le traqueur (25 points).", 1, true) ~= nil,
		Mock:Output())
	local saved = NS.OpenJournalFeats
	local opened
	NS.OpenJournalFeats = function(_, cat) opened = cat; return nil end
	NS:DB().featsFilter = "open"
	toast.button:Click("LeftButton")
	s.ok("clic : page Hauts faits, filtre « obtenus »", opened == "all" and NS:DB().featsFilter == "got")
	s.ok("clic : bandeau fermé, place rendue", not toast:IsShown() and NS:BannerShowing() == nil)
	-- rattrapage de connexion : sans noms, son texte d'avant, même clic
	opened = nil
	NS.featPending = { { many = 4, pts = 20 } }
	NS:FeatFlush(true)
	s.ok("rattrapage : texte d'avant", toast:IsShown() and toast.text:GetText() == NS:F("FEAT_TOAST_MANY", 4, 20), toast.text:GetText())
	toast.button:Click("LeftButton")
	s.ok("rattrapage : clic vers la page", opened == "all")
	NS.OpenJournalFeats = saved
	NS:DB().featsFilter = nil
	B.Reset()
	s.check("[BAN] lot de hauts faits : noms au bandeau (3, puis « et N autres », ajustés), chat complet, clic vers la page")
end
