-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- SpellDamageInfo: Russian wordings from the WoW: Forever /sdi dump all.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser, U = ns.Parser, ns.Parser.util
local NUM, WORD = U.NUM, U.WORD
local match, find, gsub = string.match, string.find, string.gsub

local SCHOOLS = {
  ["магии льда"] = "frost", ["темной магии льда"] = "shadowfrost",
  ["темной магии"] = "shadow", ["тайной магии"] = "arcane",
  ["светлой магии"] = "holy", ["светлой"] = "holy",
  ["сил природы"] = "nature", ["огня"] = "fire",
  ["ледяного огня"] = "frostfire", ["пламени тьмы"] = "shadowflame",
  ["чар огня"] = "spellfire", ["чар льда"] = "spellfrost",
  ["кровотечения"] = "physical",
  ["магии хаоса"] = "chaos",
}

local function lower(t)
  -- An abbreviation followed by a new sentence keeps a sentence-ending dot.
  for _, unit in ipairs({ "сек", "мин" }) do
    t = gsub(t, "(" .. unit .. ")%. +([\208][\144-\175])", "%1.. %2")
  end
  t = gsub(t, "\208[\144-\175]", function(c)
    local b = c:byte(2)
    return b < 160 and string.char(208, b + 32) or string.char(209, b - 32)
  end)
  return (gsub(t, "Ё", "ё"))
end

local function normaliseNumbers(t)
  local prev
  repeat prev = t; t = gsub(t, "([0-9]) ([0-9][0-9][0-9])%f[^0-9]", "%1%2") until prev == t
  return (gsub(t, "([0-9]),([0-9])", "%1.%2"))
end

local function rewrite(t)
  t = gsub(t, "–", "-")
  t = gsub(t, "(" .. NUM .. ") *%- *(" .. NUM .. ")", "%1 до %2")
  t = gsub(t, "ед%.", "")
  -- the client's plural markup, left in a dump as text: "еще 1 l4атаку:атаки:атак; с повышенной на 95 силой атаки"
  t = gsub(t, "[l|]4[^:;]*:([^:;]*):[^;]*;", "%1")
  t = gsub(t, "теряет (" .. NUM .. ") и дополнительно ", "теряет %1 здоровья и дополнительно ")
  t = gsub(t, "восстанавливает вам и союзнику ", "восстанавливает союзнику и заклинателю ")
  t = gsub(t, "(" .. NUM .. ") ч%f[^a-z\128-\255]", "%1 час")
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  t = gsub(t, " и еще " .. NUM .. " ?%% урона от оружия за каждый эффект[^%.]*", "")
  return (gsub(t, " +", " "))
end

-- Forever leaves some spells in English on a Russian client ("Wounds the target causing them to bleed for 119 damage over 21 сек.")
local function toEnglish(text)
  text = gsub(text, "([0-9]) сек%.?", "%1 sec")
  return (gsub(text, "([0-9]) мин%.?", "%1 min"))
end

local function prepareSentences(t)
  t = gsub(t, "(сек)%.", "%1")
  t = gsub(t, "(мин)%.", "%1")
  t = gsub(t, "( м)%.", "%1")
  return t
end

local function takeLasts(t, take)
  t = gsub(t, "время действия %- (" .. NUM .. ") (" .. WORD .. ")", take)
  t = gsub(t, "эффект длится (" .. NUM .. ") (" .. WORD .. ")", take)
  return t
end

local function takeInterval(t, onNumber, onOne)
  t = gsub(t, "раз в (" .. NUM .. ") (" .. WORD .. ")", onNumber)
  t = gsub(t, "каждые (" .. NUM .. ") (" .. WORD .. ")", onNumber)
  t = gsub(t, "раз в сек[^\128-\255a-z]", onOne)
  t = gsub(t, "раз в секунду", onOne)
  t = gsub(t, "в секунду", onOne)
  return t
end

local function damageAfter(after)
  local s = U.stripFillers(after, { "дополнительного ", "физического ", "химерического " })
  if s:sub(1, #"урона") ~= "урона" then return nil end
  if find(after, "химерического ", 1, true) then return "chimeral" end
  local school = match(s, "^урона от ([^,%.#]+)")
  if school then
    -- Longest school first: "темной магии льда" must not become shadow.
    local best, value = 0, nil
    for words, code in pairs(SCHOOLS) do
      if school:sub(1, #words) == words and #words > best then best, value = #words, code end
    end
    return value
  end
  if find(s, "^урона светлой магии") then return "holy" end
  return "physical"
end

local function classifyAfter(after, sentence)
  local school = damageAfter(after)
  if school then return "damage", school end
  if match(after, "^ *здоровья") then
    if find(sentence, "похища", 1, true) then return "drain" end
    if find(sentence, "передает прислужнику", 1, true) then return "petheal" end
    if find(sentence, "теряет", 1, true) then return "damage", "physical" end
  end
  return nil
end

local function healAmountOK(_, after)
  return match(after, "^ *здоровья") or match(after, "^ *исцеления")
    or match(after, "^ *[%.# ]*$") or match(after, "^ *в течение")
end

local function ignoredClause(t)
  return find(t, "погло", 1, true) or find(t, "нанесенного урона", 1, true)
    or find(t, "за каждую", 1, true) or find(t, "скорость восстановления", 1, true)
    or find(t, "наносящие заклинателю ", 1, true) or match(t, "создает .-камень")
end

local function perPointTable(t)
  return find(" " .. t, "[^0-9]1 прием *:")
end

local function finisherDot(t)
  return match(t, "^ *(" .. NUM .. ") урона за (" .. NUM .. ") сек")
end

local function reductionStat(t)
  return find(t, "силу атаки", 1, true), find(t, "урон", 1, true)
end

local function attackPower(t)
  if U.hasAny(t, { "сниж", "уменьш", "ослаб", "получаемый", "против отмеченной" }) then return nil end
  if not U.hasAny(t, { "повыш", "увелич", "усилив" }) then return nil end
  local strength = match(t, "повышает силу участников.-на (" .. NUM .. ")")
  if strength then return { kind = "stat", stat = "str", amount = tonumber(strength) } end
  -- Grace of Air Totem: "повышает ловкость участников группы или рейда в радиусе 30 м на 49"
  local agility = match(t, "повышает ловкость участников.-на (" .. NUM .. ")")
  if agility then return { kind = "stat", stat = "agi", amount = tonumber(agility) } end
  if U.hasAny(t, { "силу атаки", "сила атаки" }) then
    local amount = match(t, "силу атаки.-на (" .. NUM .. ")")
      or match(t, "сила атаки.-на (" .. NUM .. ")")
      or match(t, "сила атаки увеличивается на показатель ловкости %+" .. "(" .. NUM .. ")")
    if amount then
      return { kind = "ap", amount = tonumber(amount), ranged = find(t, "дальнего боя", 1, true) ~= nil,
        plusAgility = find(t, "показатель ловкости", 1, true) ~= nil }
    end
  end
end

local function weapon(t)
  local pct, bonus, hi
  -- Hammer of the Righteous: "нанося урон от светлой магии, равный урону в секунду от оружия в правой руке, умноженному на 3"
  pct = match(t, "равный урону в секунду от оружия в правой руке, умноженному на (" .. NUM .. ")")
  if pct then return { kind = "dps", times = tonumber(pct), school = find(t, "светлой магии", 1, true) and "holy" or "physical" } end
  local attacks, amount = match(t, "еще (" .. NUM .. ") атаки с увеличенной на (" .. NUM .. ") силой атаки")
  if not attacks then attacks, amount = match(t, "еще (" .. NUM .. ") атаки с повышенной на (" .. NUM .. ") силой атаки") end
  if attacks then return { kind = "extra", attacks = tonumber(attacks), amount = tonumber(amount) } end
  -- Sniper Shot: "наносящий урон в дальнем бою +320": the ranged weapon's hit plus the amount
  bonus = match(t, "урон в дальнем бою %+ ?(" .. NUM .. ")")
  if bonus then return { kind = "weapon", pct = 100, bonus = tonumber(bonus), ranged = true } end
  bonus = match(t, "наносящий (" .. NUM .. ") дополнительного урона в дальнем бою")
  if bonus then return { kind = "next", bonus = tonumber(bonus), ranged = true } end
  if find(t, "каждым оружием", 1, true) then
    pct, bonus = match(t, "(" .. NUM .. ")%% урона от оружия и еще (" .. NUM .. ")")
    if pct then return { kind = "both", pct = tonumber(pct), bonus = tonumber(bonus) } end
  end
  pct, bonus = match(t, "урон в размере (" .. NUM .. ")%% силы атаки и еще (" .. NUM .. ")")
  if not pct then pct = match(t, "(" .. NUM .. ")%% вашей силы атаки") end
  if pct then return { kind = "appct", pct = tonumber(pct), bonus = tonumber(bonus or 0) } end
  if find(t, "с некоторой вероятностью", 1, true) and find(t, "70%%") and find(t, "урона") then
    return { kind = "weapon", pct = 70, bonus = 0, school = "holy" }
  end
  pct, bonus = match(t, "нанося цели (" .. NUM .. ")%% урона и еще (" .. NUM .. ")")
  if pct then return { kind = "weapon", pct = tonumber(pct), bonus = tonumber(bonus) } end
  if U.hasAny(t, { "урона от оружия", "урон от оружия", "урона оружия", "урона плюс", "базового и" }) then
    pct = match(t, "(" .. NUM .. ")%% урона") or match(t, "(" .. NUM .. ")%% базового")
    bonus, hi = match(t, "и еще (" .. NUM .. ") до (" .. NUM .. ")")
    if not bonus then
      bonus = match(t, "и еще (" .. NUM .. ")") or match(t, "плюс (" .. NUM .. ")")
        or match(t, "и дополнительно (" .. NUM .. ")") or match(t, "(" .. NUM .. ") дополнительного урона")
        or match(t, "наносящий (" .. NUM .. ") урона сверх базового")
    end
    return { kind = "weapon", pct = tonumber(pct or 100), bonus = tonumber(bonus or 0), bonusMax = tonumber(hi) }
  end
  bonus = match(t, "увеличивающая урон в ближнем бою на (" .. NUM .. ")")
    or match(t, "на (" .. NUM .. ") больше урона при следующей атаке")
  if bonus then return { kind = "next", bonus = tonumber(bonus) } end
  if find(t, "чем медленнее оружие", 1, true) or find(t, "атаки ближнего боя наносят еще", 1, true)
    or find(t, "позволяющим атакам ближнего боя дополнительно наносить", 1, true) then
    local lo
    lo, hi = match(t, "(" .. NUM .. ") до (" .. NUM .. ") дополнительного урона")
    if not lo then lo, hi = match(t, "(" .. NUM .. ") до (" .. NUM .. ") урона") end
    if not lo then lo = match(t, "наносят еще (" .. NUM .. ") урона") end
    if lo then return { kind = "perhit", min = tonumber(lo), max = tonumber(hi or lo),
      school = find(t, "светлой магии", 1, true) and "holy" or "fire",
      bySpeed = find(t, "чем медленнее", 1, true) ~= nil } end
  end
end

local function special(t)
  -- Dark Sacrifice: "Вы расходуете 400 здоровья в течение 15 сек., чтобы восполнить 428 маны"
  local hcost, hsec, hmana = match(t, "вы расходуете (" .. NUM .. ") здоровья в течение (" .. NUM .. ") сек%.?, чтобы восполнить (" .. NUM .. ") маны")
  if hcost then return { healthCost = tonumber(hcost), manaGain = tonumber(hmana), healthCostDuration = tonumber(hsec) } end
  local absorb = match(t, "поглощающий (" .. NUM .. ") урона")
    or match(t, "поглощает (" .. NUM .. ") [^0-9]-урона")
    or match(t, "поглотить (" .. NUM .. ") урона")
  if absorb then
    local r = { absorb = tonumber(absorb) }
    local total, seconds = match(t, "восполнит (" .. NUM .. ") здоровья за (" .. NUM .. ") сек")
    if total then r.hot = { total = tonumber(total), duration = tonumber(seconds) } end
    return r
  end
  if find(t, "здоровье в объеме максимального запаса здоровья паладина", 1, true) then return { healMaxHealth = true } end
  local cost, mana = match(t, "преобразует (" .. NUM .. ") здоровья в (" .. NUM .. ") маны")
  if cost then return { healthCost = tonumber(cost), mana = U.D(mana) } end
  local lo, hi = match(t, "который регулярно атакует[^%.]-нанося (" .. NUM .. ") до (" .. NUM .. ") урона")
  if lo then return { direct = U.D(lo, hi), school = "fire", perAttack = true } end
  local heal, every = match(t, "который исцеляет.-на (" .. NUM .. ") здоровья раз в (" .. NUM .. ") сек")
  if heal then return { heal = U.D(heal), every = tonumber(every) } end
  lo, hi = match(t, "нанося (" .. NUM .. ") до (" .. NUM .. ") урона от светлой магии противнику")
  local hmin, hmax = match(t, "обеспечивая (" .. NUM .. ") до (" .. NUM .. ") исцеления союзнику")
  if lo and hmin then return { direct = U.D(lo, hi), heal = U.D(hmin, hmax), school = "holy" } end
  lo = match(t, "наносит (" .. NUM .. ") урона от светлой магии противникам, атакующим")
  if lo then return { direct = U.D(lo), school = "holy", perStrike = true } end
  lo = match(t, "при успешном блокировании[^%.]-(" .. NUM .. ") урона")
  if lo then return { direct = U.D(lo), school = "holy", perBlock = true } end
  local bonus
  lo, bonus = match(t, "нанося (" .. NUM .. ") урона и еще (" .. NUM .. ") урона за каждую единицу ярости")
  if lo then return { direct = U.D(lo), school = "physical", perRage = tonumber(bonus) } end
  local total, seconds = match(t, "в области действия (" .. NUM .. ") урона от светлой магии за (" .. NUM .. ") сек")
  local first, extra = match(t, "наносит (" .. NUM .. ") первым противникам[^%.]-еще (" .. NUM .. ") урона")
  if total and first then return { dot = { total = tonumber(total) + tonumber(extra), duration = tonumber(seconds) },
    school = "holy", first = tonumber(first) } end
  local amount = match(t, "атаки ближнего боя могут восстановить (" .. NUM .. ") здоровья")
    -- Seal of Light's other wording: "способным исцелять паладина на 94 при некоторых атаках ближнего боя"
    or match(t, "исцелять паладина на (" .. NUM .. ") при некоторых атаках")
  if amount then return { heal = U.D(amount) } end
  local seconds
  amount, seconds = match(t, "для восстановления (" .. NUM .. ") здоровья в течение (" .. NUM .. ") сек")
  if amount then return { hot = { total = tonumber(amount), duration = tonumber(seconds) } } end
  lo = match(t, "нанесение ему (" .. NUM .. ") урона от темной магии")
  if lo and find(t, "в объеме 100%% от нанесенного урона") then
    return { direct = U.D(lo), heal = U.D(lo), school = "shadow", transfer = true }
  end
end

local function healthPercent(t)
  local n = match(t, "восстанавливает (" .. NUM .. ")%% максимального запаса здоровья")
  return n
end

local function itemHeal(t)
  local lo, hi = match(t, "восстанавливает (" .. NUM .. ") до (" .. NUM .. ") здоровья")
  if not lo then lo = match(t, "восстанавливает (" .. NUM .. ") здоровья") end
  local mlo, mhi = match(t, "восстанавливает (" .. NUM .. ") до (" .. NUM .. ") маны")
  if not mlo then mlo = match(t, "восстанавливает (" .. NUM .. ") маны") end
  local seconds = lo and match(t, "здоровья за (" .. NUM .. ") сек")
  return lo, hi, mlo, mhi, seconds
end

-- A drink: mana total, seconds, and the health total where one wording names both.
-- "Восполняет 151 ед. маны в течение 18 сек." / "Восстанавливает 151 маны за 18 сек."
local function itemDrink(t)
  -- "ед." between an amount and its unit is optional
  t = gsub(t, "(" .. NUM .. ") ед%.? ", "%1 ")
  for _, verb in ipairs({ "восстанавливает", "восполняет", "восполнение" }) do
    for _, over in ipairs({ "в течение", "за" }) do
      local h, m, d = match(t, verb .. " (" .. NUM .. ") здоровья и (" .. NUM .. ") маны " .. over .. " (" .. NUM .. ") сек")
      if m then return m, d, h end
      m, d = match(t, verb .. " (" .. NUM .. ") маны " .. over .. " (" .. NUM .. ") сек")
      if m then return m, d end
    end
  end
end

-- A drink's share of maximum mana: percent, duration.
local function manaPercent(t)
  for _, verb in ipairs({ "восстанавливает", "восполняет", "восполнение" }) do
    for _, of in ipairs({ "маны", "максимального запаса маны" }) do
      local head = verb .. " (" .. NUM .. ")%s*%% " .. of
      local p, d = match(t, head .. " за (" .. NUM .. ") сек")
      if not p then p, d = match(t, head .. " в течение (" .. NUM .. ") сек") end
      if p then return p, d end
      -- Instant: only as the whole text, never the tail of another effect.
      p = match(t, "^" .. head .. "[%. ]*$") or match(t, "^использование: " .. head .. "[%. ]*$")
      if p then return p end
    end
  end
end

local function judgement(t)
  local lo, hi = match(t, "наносит противнику (" .. NUM .. ") до (" .. NUM .. ") урона от светлой магии")
  if not lo then lo, hi = match(t, "уроном от светлой магии в (" .. NUM .. ") до (" .. NUM .. ")") end
  return lo, hi, "holy"
end

local function procChance(t)
  local n = match(t, "каждый удар с вероятностью (" .. NUM .. ")%%")
  if n then return tonumber(n) end
  if U.hasAny(t, { "с некоторой вероятностью", "атаки ближнего боя могут", "при любой атаке",
    "в следующий раз атакуют", "каждое попадание", "одна из оставшихся шаровых" }) then return true end
end

local function unreadKind(t)
  if find(t, "к жизни", 1, true) or match(t, "создает .-камень")
    or find(t, "не наносящ", 1, true) or find(t, "превращает противника в ", 1, true)
    or find(t, "получение информации", 1, true) or find(t, "после смерти", 1, true)
    or match(t, "исцеление " .. NUM .. " эффекта") or match(t, "исцеление " .. NUM .. " болезни") then return "utility" end
  for after in t:gmatch(NUM .. "([^0-9]*)") do
    if damageAfter(after) then return "unread-damage" end
  end
  if U.hasAny(t, { "урона", "периодический урон" }) and not find(t, "получ", 1, true) then return "unread-effect" end
  if U.hasAny(t, { "исцел", "здоров", "силу атаки", "сила атаки", "поглоща" }) then return "unread-effect" end
  return "utility"
end

Parser.RegisterPack("ru", {
  rangeWord = "до", damageWord = "урона", weaponWord = "от оружия",
  pointsMarker = "прием[^ :]*",
  healWords = { "исцел", "излеч", "восполня", "восстанавл", "восстановить", "восстановит " },
  clauseSeparators = { " и ", ", а ", " или ", ", а затем ", ", а также " },
  reduceVerbs = { "сниж", "уменьш" }, enemyWords = { "цел", "противник" },
  selfWords = { "получаем", "вам", "вас" }, increaseWord = "увелич", byWord = "на ",
  sealEnergy = "высвобождение энергии", judgementSpell = "высвобождает энергию печати",
  words = { "урон", "здоров", "противник", "цел", "заклинан" },
  units = { ["сек"] = 1, ["мин"] = 60, ["час"] = 3600 },
  distanceWords = { ["м"] = true, ["метров"] = true, ["метрах"] = true },
  hp5 = "скорость восстановления здоровья[^0-9]-(" .. NUM .. ") раз в (" .. NUM .. ") сек",
  tickTails = { "^ *раз в ", "^ *в секунду" },
  durationMarkers = { " сек", " мин", "в течение", "раз в " },
  drainWords = { "похищ" }, manaWord = "маны",
  healing = {
    targets = { "союзнику и заклинателю" },
    channel = { "поддержани", "регенерация", "регенерации" },
    trigger = { "при следующем", "в следующий раз", "могут восстановить", "исцеляет его при", "исцеления при", "могут испить" },
    stack = { "суммируется", "истечении" },
    pet = { "питомцу", "прислужнику" },
    target = { "исцеление цели", "исцеление дружественной цели", "исцеляет дружественную цель", "исцеляет цель",
      "излечение цели", "излечивает одну цель", "восполняет союзнику", "восстанавливает союзнику", "восстанавливает цели" },
  },
  lower = lower,
  -- Russian text has a good many Cyrillic letters; an English description with only the unit "сек" in it (Forever's Mangle) has three
  detect = function(t) local _, n = gsub(t, "[\208\209][\128-\191]", "") return n >= 6 end, detectAlways = true, toEnglish = toEnglish,
  normaliseNumbers = normaliseNumbers, rewrite = rewrite, prepareSentences = prepareSentences,
  takeLasts = takeLasts, takeInterval = takeInterval, classifyAfter = classifyAfter,
  healAmountOK = healAmountOK, ignoredClause = ignoredClause, perPointTable = perPointTable,
  healthPercent = healthPercent, instantPercent = function() end, extraPercent = function() end,
  itemHeal = itemHeal, itemDrink = itemDrink, manaPercent = manaPercent, reductionStat = reductionStat, weapon = weapon, attackPower = attackPower,
  judgement = judgement, sealDuration = function(t) return match(t, "(" .. NUM .. ") сек") end,
  special = special, finisherDot = finisherDot, procChance = procChance,
  unreadKind = unreadKind,
})
