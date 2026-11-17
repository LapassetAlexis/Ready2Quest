-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: Korean language pack of the spell parser.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- The wordings of WoW: Forever's Korean spell descriptions: "15에서 23의 화염 피해를 입히고 4초에 걸쳐 총 2의 추가 화염 피해를
-- 입힙니다", "생명력을 260에서 300만큼 회복시킵니다", "연계 점수 1점: 8초에 걸쳐 25의 피해". What a pack is, and how to add one, is
-- in Parser.lua (LANGUAGE PACKS).
-- WRITTEN FROM WOWHEAD'S FOREVER TOOLTIPS (nether.wowhead.com/forever/tooltip/spell/<id>?locale=ko), NOT from a /sdi dump of a
-- Korean client: the wording of the French and Spanish pages matched the game's own texts, the numbers did not always. It has not
-- been compared with a Korean client yet. A wording the pack does not know stays unread: it never guesses.
--
-- A number is followed by a particle or a unit without a space ("23의", "4초에", "300만큼"); rewrite puts a space after every number
-- so the engine finds the amount and its unit. Pure Lua 5.1, no game API.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser = ns.Parser

local U = Parser.util
local NUM, num, D, hasAny, stripFillers = U.NUM, U.num, U.D, U.hasAny, U.stripFillers
local find, sub, gsub, match = string.find, string.sub, string.gsub, string.match
local tonumber, floor = tonumber, math.floor

-- School words before "피해".
local SCHOOLS = {
  { "냉기화염", "frostfire" }, { "화염", "fire" }, { "냉기", "frost" }, { "자연", "nature" }, { "암흑", "shadow" },
  { "신성", "holy" }, { "비전", "arcane" }, { "물리", "physical" }, { "출혈", "physical" }, { "혼돈", "chaos" },
}

local FILLERS = { "의 ", "총 ", "추가로 ", "추가 ", "기본 ", "만큼 " }

-- Words of this language, for telling a Korean client's English texts.
local KOREAN_WORDS = { "피해", "대상", "입힙니다", "회복", "증가", "감소", "시킵니다" }

local function detect(t)
  return find(t, "피해", 1, true) or find(t, "대상", 1, true)
end

local function normaliseNumbers(t)
  local prev
  repeat prev = t; t = gsub(t, "([0-9]),([0-9][0-9][0-9])%f[^0-9]", "%1%2") until t == prev
  return t
end

local function toEnglish(text)
  text = gsub(text, "([0-9]) ?초", "%1 sec")
  return (gsub(text, "([0-9]) ?분", "%1 min"))
end

-- A space after every number, one spelling of the phrases the pack reads.
local function rewrite(t)
  t = gsub(t, "%$null~", " 에서 ")
  t = gsub(t, "(생명석[^%.]-)회복", "%1획득")
  -- a totem's own health ("5의 생명력을 지닌 불꽃의 토템") is no amount of the spell
  t = gsub(t, "(" .. NUM .. ") 의 생명력을 지닌", "지닌")
  t = gsub(t, "마나를 (" .. NUM .. ") 만큼 소진", "마나를 %1 만큼 소모")
  t = gsub(t, "(%d)([\234-\237])", "%1 %2")
  t = gsub(t, "%%([\234-\237])", "%% %1")
  t = gsub(t, "무기 피해", "무기 공격력")
  -- reductions: "전투력을 56만큼 감소시킵니다" -> an amount after a word of its own
  t = gsub(t, "([을를]) (" .. NUM .. ") 만큼 감소", "%1 감소량 %2 만큼 감소")
  -- Health Funnel: "12의 생명력을 시전자의 소환수에게 이전합니다" gives the pet health the caster pays, no heal
  t = gsub(t, "(" .. NUM .. ") 의 생명력을 시전자의 소환수에게", "%1 의 생명력 배정 소환수에게")
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  t = gsub(t, ", 추가로 대상에게 걸린 [^%.]-하나당 무기 공격력의 " .. NUM .. " ?%% 에 해당하는 피해를 입힙니다", "")
  return (gsub(t, " +", " "))
end

-- "30초 동안 지속됩니다": how long the whole effect lasts
local function takeLasts(t, take)
  t = gsub(t, "(" .. NUM .. ") (초) 동안 지속", take)
  t = gsub(t, "(" .. NUM .. ") (분) 동안 지속", take)
  t = gsub(t, "(" .. NUM .. ") (시간) 동안 지속", take)
  return t
end

local function takeInterval(c, onNumber, onOne)
  c = gsub(c, "(" .. NUM .. ") (초)마다", onNumber)
  c = gsub(c, "매 (" .. NUM .. ") (초)", onNumber)
  c = gsub(c, "(" .. NUM .. ") (초)당", onNumber)
  c = gsub(c, "매초마다", onOne)
  c = gsub(c, "매초", onOne)
  return c
end

local function schoolOf(s)
  if sub(s, 1, 6) == "피해" then return "physical" end
  for _, school in ipairs(SCHOOLS) do
    local word = school[1]
    if sub(s, 1, #word) == word and sub(s, #word + 2, #word + 7) == "피해" then return school[2] end
  end
  return false
end

local function classifyAfter(after, sentence)
  local s = stripFillers(after, FILLERS)
  local school = schoolOf(s)
  if school then return "damage", school end
  if sub(s, 1, 9) == "생명력" then
    if find(sentence, "생명력을 흡수", 1, true) or find(sentence, "생명력 흡수", 1, true) then return "drain", nil end
    if find(sentence, "생명력 배정", 1, true) then return "petheal", nil end
  end
  return nil
end

-- "생명력을 260에서 300만큼 회복시킵니다", "10초에 걸쳐 800의 생명력을 회복": the words before name health, not mana
local function healAmountOK(before, after)
  if find(before, "마나", 1, true) then return false end
  local s = stripFillers(after, { "의 " })
  if sub(s, 1, 9) == "생명력" or sub(s, 1, 6) == "치유" then return true end
  -- "아군 대상을 296에서 353만큼 치유합니다", "대상과 대상의 파티를 7초에 걸쳐 336만큼 치유합니다": the verb says it is health
  if match(after, "^ *만큼 치유") or match(after, "^ *만큼 회복") then return true end
  if match(after, "^ *만큼") then return find(before, "생명력", 1, true) ~= nil or find(before, "[을를] $") ~= nil end
  return false
end

local function ignoredClause(c)
  -- Hellfire: "매 1초마다 시전자에게 86의 화염 피해를 입히고": the caster's own
  return find(c, "피해를 흡수", 1, true) or find(c, "흡수된 피해", 1, true) or find(c, "시전자에게 " .. NUM .. " 의")
    or find(c, "대신 입습니다", 1, true) or find(c, "마나 당 ", 1, true)
end

local function perPointTable(t)
  return find(" " .. t, "[^0-9]1 점 *:")
end

-- A consumable's amounts: health lo..hi, mana mlo..mhi, and a stated duration.
local function itemHeal(t)
  local lo, hi, mlo, mhi, dur
  dur, lo = match(t, "(" .. NUM .. ") 초에 걸쳐 (" .. NUM .. ") 의 생명력을 회복")
  if not lo then
    lo, hi = match(t, "(" .. NUM .. ") 에서 (" .. NUM .. ") 의 생명력을 회복")
    if not lo then lo = match(t, "(" .. NUM .. ") 의 생명력을 회복") end
  end
  mlo, mhi = match(t, "(" .. NUM .. ") 에서 (" .. NUM .. ") 의 마나를 회복")
  if not mlo then mlo = match(t, "(" .. NUM .. ") 의 마나를 회복") end
  return lo, hi, mlo, mhi, dur, false
end

-- A drink: "18초에 걸쳐 151의 마나를 회복합니다"
local function itemDrink(t)
  local d, m = match(t, "(" .. NUM .. ") 초에 걸쳐 (" .. NUM .. ") 의 마나를 회복")
  return m, d
end

local REDUCE_VERBS = { "감소" }

local function reductionStat(c)
  return find(c, "전투력", 1, true), find(c, "물리 공격력", 1, true)
end

local function attackPowerIn(sentence)
  if not find(sentence, "전투력", 1, true) then return nil end
  if hasAny(sentence, REDUCE_VERBS) or find(sentence, "확률", 1, true) then return nil end
  if find(sentence, "[^0-9]1 점 *:") then return nil end
  local a = match(sentence, "전투력[^%d]-(" .. NUM .. ") 만큼 증가")
    -- the bear forms and Lion's Heart name other stats too: "방어도가 180%만큼, 전투력이 120만큼, 생명력이 560만큼 증가합니다"
    or match(sentence, "전투력[^%d]-(" .. NUM .. ") 만큼,")
  if not a then return nil end
  return { kind = "ap", amount = num(a), ranged = find(sentence, "원거리", 1, true) ~= nil,
    plusAgility = find(sentence, "민첩성에 추가로", 1, true) ~= nil }
end

local function schoolCode(word)
  for _, school in ipairs(SCHOOLS) do
    if word == school[1] then return school[2] end
  end
  return nil
end

local function weaponKO(t)
  local p, a, b, school
  -- Windfury Weapon and Totem: "20%의 확률로 근접 전투력이 104만큼 증가한 상태에서 2회의 추가 공격을 가합니다"
  b, a = match(t, "전투력이 (" .. NUM .. ") 만큼 증가한 상태에서 (" .. NUM .. ") 회의 추가 공격")
  if a then return { kind = "extra", attacks = num(a), amount = num(b) } end
  -- Seal of Command: "일정 확률로 무기 공격력의 70%만큼에 해당하는 추가 신성 피해를 입힙니다"
  p, school = match(t, "확률로 무기 공격력의 (" .. NUM .. ") ?%% [^%d]-추가 (%S+) 피해")
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = schoolCode(school) } end
  if find(t, "확률", 1, true) then return nil end
  -- Seal of Fury, Flametongue: "근접 공격 시 14의 추가 신성 피해를 입히게 합니다", "매 근접 공격 시 X에서 Y의 추가 신성 피해를"
  local lo, hi
  lo, hi, school = match(t, "공격 시 (" .. NUM .. ") 에서 (" .. NUM .. ") 의 추가 (%S+) 피해")
  if not lo then
    lo, school = match(t, "공격 시 (" .. NUM .. ") 의 추가 (%S+) 피해")
    hi = lo
  end
  if lo then
    return { kind = "perhit", min = num(lo), max = num(hi), school = schoolCode(school),
      bySpeed = find(t, "공격 속도에 따라", 1, true) and true or nil }
  end
  -- Holy Strike: "무기 공격력의 29%에 15에서 20의 추가 신성 피해를 입힙니다"
  p, a, b = match(t, "무기 공격력의 (" .. NUM .. ") ?%% 에 (" .. NUM .. ") 에서 (" .. NUM .. ") 의 추가")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a), bonusMax = num(b) } end
  -- Backstab, Ambush, Shred: "무기 공격력의 150%에 10의 추가 피해", "공격력의 435%에 추가로 42의 피해"; Claw: "일반 공격력의 140%에
  -- 해당하는 피해와 27의 추가 피해"
  p, a = match(t, "무기 공격력의 (" .. NUM .. ") ?%% 에 추가로 (" .. NUM .. ") 의")
  if not p then p, a = match(t, "무기 공격력의 (" .. NUM .. ") ?%% 에 (" .. NUM .. ") 의 추가") end
  if not p then p, a = match(t, "일반 공격력의 (" .. NUM .. ") ?%% 에 해당하는 피해와 (" .. NUM .. ") 의 추가") end
  if not p then p, a = match(t, "공격력의 (" .. NUM .. ") ?%% 에 추가로 (" .. NUM .. ") 의") end
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Primal Bite: "일반 공격력의 100%에 해당하는 피해에 추가로 42의 입히고"
  p, a = match(t, "일반 공격력의 (" .. NUM .. ") ?%% 에 해당하는 피해에 추가로 (" .. NUM .. ") 의")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Devastate, Chimera Shot, Saber Slash: "무기 공격력의 150%에 해당하는 추가 피해를", "무기 공격력의 135%에 해당하는 피해를 입힌 후" (not
  -- Lacerate's "중첩 하나당 무기 공격력의 10%에 해당하는 피해": that is the stacks' share)
  if not find(t, "하나당 무기 공격력", 1, true) then
    p = match(t, "무기 공격력의 (" .. NUM .. ") ?%% 에 해당하는 추가 피해") or match(t, "무기 공격력의 (" .. NUM .. ") ?%% 에 해당하는 피해를")
    if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  end
  -- Bloodthirst, Shuriken Toss: "전투력의 45%에 해당하는 피해와 30의 추가 피해를 입힙니다"
  p, a = match(t, "전투력의 (" .. NUM .. ") ?%% 에 해당하는 피해와 (" .. NUM .. ") 의 추가")
  if not p then p = match(t, "전투력의 (" .. NUM .. ") ?%% 에 해당하는 피해") end
  if p then return { kind = "appct", pct = num(p), bonus = num(a) or 0 } end
  -- "무기 공격력에 5의 추가 피해를 입힙니다", "무기 공격력에 추가로 32의 피해를", "근접 무기 공격력에 추가로 5의 피해를"
  -- Mortal Strike: "무기 공격력에 추가로 85만큼의 피해를", Slam's relative: "무기 공격력에 해당하는 피해와 16의 추가 피해를"
  a = match(t, "무기 공격력에 추가로 (" .. NUM .. ") 의 피해") or match(t, "무기 공격력에 (" .. NUM .. ") 의 추가 피해")
    or match(t, "무기 공격력에 추가로 (" .. NUM .. ") 만큼의 피해") or match(t, "무기 공격력에 해당하는 피해와 (" .. NUM .. ") 의 추가 피해")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  -- Sniper Shot: "원거리 공격력에 추가로 320만큼 피해를 입히고": the ranged weapon's hit plus the amount
  a = match(t, "원거리 공격력에 추가로 (" .. NUM .. ") 만큼 피해")
  if a then return { kind = "weapon", pct = 100, bonus = num(a), ranged = true } end
  -- Aimed Shot: "적을 정확하게 조준하여 40의 추가 원거리 피해를 입힙니다"
  a = match(t, "(" .. NUM .. ") 의 추가 원거리 피해")
  if a then return { kind = "next", bonus = num(a), ranged = true } end
  -- Seal of the Crusader: "근접 전투력이 60만큼, 근접 공격 속도가 40%만큼 증가합니다"
  a, p = match(t, "근접 전투력이 (" .. NUM .. ") 만큼, 근접 공격 속도가 (" .. NUM .. ") ?%% 만큼 증가")
  if a then return { kind = "ap", amount = num(a), faster = num(p) } end
  -- Hammer of the Righteous: "주무기 초당 공격력의 3배에 해당하는 신성 피해를 입힙니다"
  a, school = match(t, "주무기 초당 공격력의 (" .. NUM .. ") 배에 해당하는 (%S+) 피해")
  if a then return { kind = "dps", times = num(a), school = schoolCode(school) or "physical" } end
  -- Whirlwind: "두 근접 무기 모두의 공격력에 해당하는 피해를 입힙니다"
  if find(t, "무기 모두의 공격력에 해당하는 피해", 1, true) then return { kind = "weapon", pct = 100, bonus = 0 } end
  -- Strength of Earth, Grace of Air: "힘을 7만큼 증가시킵니다"
  a = match(t, "의 힘을 (" .. NUM .. ") 만큼 증가")
  if a then return { kind = "stat", stat = "str", amount = num(a) } end
  a = match(t, "의 민첩성을 (" .. NUM .. ") 만큼 증가")
  if a then return { kind = "stat", stat = "agi", amount = num(a) } end
  return nil
end

local function special(t)
  local n, m, dur, lo, hi, school, first, extra
  -- shields: "48의 피해를 흡수합니다", "162의 화염 피해를 흡수합니다"
  n = match(t, "(" .. NUM .. ") 의 [^%d]-피해를 흡수")
  if n then return { absorb = num(n) } end
  -- Lay on Hands: "성기사의 최대 생명력만큼 아군 대상을 치유합니다"
  if find(t, "성기사의 최대 생명력만큼", 1, true) then return { healMaxHealth = true } end
  -- Life Tap: "48의 생명력을 48의 마나로 변환합니다"
  n, m = match(t, "(" .. NUM .. ") 의 생명력을 (" .. NUM .. ") 의 마나로 변환")
  if n then return { healthCost = num(n), manaGain = num(m) } end
  -- Death Coil: "285의 암흑 피해를 입힙니다. 시전자는 입힌 피해의 100%만큼 생명력을 회복합니다"
  n, school = match(t, "(" .. NUM .. ") 의 (%S+) 피해를 입힙니다%. 시전자는 입힌 피해의 100 ?%% 만큼 생명력을 회복")
  if n then return { direct = D(n), heal = D(n), school = schoolCode(school), transfer = true } end
  -- Execute: "125의 피해를 입히고 나머지 분노를 모두 소모하여 분노당 3의 피해를 추가로 입힙니다"
  n, m = match(t, "(" .. NUM .. ") 의 피해를 입히고 [^%d]-분노당 (" .. NUM .. ") 의 피해")
  if n then return { direct = D(n), school = "physical", perRage = num(m) } end
  -- Searing Totem: "공격하여 9에서 11의 화염 피해를 입히게 합니다"
  lo, hi, school = match(t, "공격하여 (" .. NUM .. ") 에서 (" .. NUM .. ") 의 (%S+) 피해를 입히게")
  if lo then return { direct = D(lo, hi), school = schoolCode(school), perAttack = true } end
  -- Healing Stream Totem: "파티원의 생명력을 매 2초마다 5만큼 회복시키게 합니다"
  m, n = match(t, "생명력을 매 (" .. NUM .. ") 초마다 (" .. NUM .. ") 만큼 회복시키게")
  if n then return { heal = D(n), every = num(m) } end
  -- Retribution Aura: "공격하는 모든 생물에게 5의 신성 피해를 입힙니다"
  n, school = match(t, "모든 생물에게 (" .. NUM .. ") 의 (%S+) 피해를 입힙니다")
  if n then return { direct = D(n), school = schoolCode(school), perStrike = true } end
  -- Holy Shield: "공격을 방패로 막을 때마다 공격자에게 75의 신성 피해를 입힙니다"
  n, school = match(t, "막을 때마다 공격자에게 (" .. NUM .. ") 의 (%S+) 피해를 입힙니다")
  if n then return { direct = D(n), school = schoolCode(school), perBlock = true } end
  -- Consecration: "8초에 걸쳐 24의 신성 피해를 입힙니다. 가장 먼저 해당 지역에 들어서는 적 4명은 8초에 걸쳐 56의 추가 피해를"
  dur, n, school, first, extra = match(t, "(" .. NUM .. ") 초에 걸쳐 (" .. NUM .. ") 의 (%S+) 피해를 입힙니다%.[^%.]-적 (" .. NUM
    .. ") 명은 " .. NUM .. " 초에 걸쳐 (" .. NUM .. ") 의 추가 피해")
  if n then
    return { dot = { total = num(n) + num(extra), duration = num(dur) }, school = schoolCode(school), first = num(first) }
  end
  -- Dark Sacrifice: "15초에 걸쳐 자신의 생명력을 440만큼 포식해 431의 마나를 회복합니다"
  dur, n, m = match(t, "(" .. NUM .. ") 초에 걸쳐 자신의 생명력을 (" .. NUM .. ") 만큼 포식해 (" .. NUM .. ") 의 마나를 회복")
  if n then return { healthCost = num(n), manaGain = num(m), healthCostDuration = num(dur) } end
  -- Seal of Light, per trigger: "일정 확률로 성기사의 생명력을 39만큼 회복시킵니다"
  n = match(t, "일정 확률로 성기사의 생명력을 (" .. NUM .. ") 만큼 회복")
  if n then return { heal = D(n) } end
  return nil
end

-- "연계 점수 1점: 8초에 걸쳐 25의 피해": the damage over time in one point's row (duration first), or "25의 피해, 8초에 걸쳐"
local function finisherDot(seg)
  local dur, total = match(seg, "^ *(" .. NUM .. ") 초에 걸쳐 (" .. NUM .. ") 의 피해")
  if not total then total, dur = match(seg, "^ *(" .. NUM .. ") 의 피해[^%d]-(" .. NUM .. ") 초에 걸쳐") end
  return total, dur
end

local function procChance(t)
  local p = match(t, "매 공격 시 (" .. NUM .. ") ?%% 의 확률로") or match(t, "공격할 때마다 (" .. NUM .. ") ?%% 의 확률로")
  if p then return num(p) end
  if find(t, "일정 확률로", 1, true) then return true end
  return nil
end

local function unreadKind(t)
  for after in t:gmatch(NUM .. "([^0-9]*)") do
    local s = stripFillers(after, FILLERS)
    if schoolOf(s) then return "unread-damage" end
  end
  if hasAny(t, { "피해", "생명력", "전투력", "흡수" }) then return "unread-effect" end
  return "utility"
end

Parser.RegisterPack("ko", {
  rangeWord = "에서",
  damageWord = "피해",
  weaponWord = "무기 공격력",
  pointsMarker = "점",
  healWords = { "회복", "치유", "치료" },
  clauseSeparators = { "고 ", ", ", "며 " },
  reduceVerbs = REDUCE_VERBS,
  enemyWords = { "대상", "적" },
  selfWords = { "받는 피해" },
  increaseWord = "증가",
  byWord = "감소량 ",
  sealEnergy = "문장의 에너지를 폭발시키면",
  judgementSpell = "문장의 에너지를 적에게 폭발시킵니다",
  words = KOREAN_WORDS,
  units = { ["초"] = 1, ["분"] = 60, ["시간"] = 3600 },
  distanceWords = { ["미터"] = true },
  hp5 = "일치하지않는(" .. NUM .. ")(" .. NUM .. ")",
  tickTails = { "^ *마다" },
  durationMarkers = { "초", "분", "마다" },
  drainWords = { "흡수" },
  manaWord = "마나",
  healing = {
    targets = {},
    channel = { "정신을 집중" },
    trigger = { "확률", "클릭" },
    stack = { "중첩" },
    pet = { "소환수" },
    target = { "대상", "아군" },
  },
  detect = detect,
  toEnglish = toEnglish,
  normaliseNumbers = normaliseNumbers,
  rewrite = rewrite,
  prepareSentences = function(t) return t end,
  takeLasts = takeLasts,
  takeInterval = takeInterval,
  classifyAfter = classifyAfter,
  healAmountOK = healAmountOK,
  ignoredClause = ignoredClause,
  perPointTable = perPointTable,
  healthPercent = function() end,
  instantPercent = function() end,
  extraPercent = function() end,
  itemHeal = itemHeal, itemDrink = itemDrink,
  reductionStat = reductionStat,
  weapon = weaponKO,
  attackPower = attackPowerIn,
  judgement = function(part)
    local lo, hi, school = match(part, "(" .. NUM .. ") 에서 (" .. NUM .. ") 의 (%S+) 피해")
    if not lo then return nil end
    return lo, hi, schoolCode(school)
  end,
  sealDuration = function(t) return match(t, "(" .. NUM .. ") 초 동안") end,
  special = special,
  finisherDot = finisherDot,
  procChance = procChance,
  unreadKind = unreadKind,
})
