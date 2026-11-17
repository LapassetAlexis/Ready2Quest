-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: Chinese language pack of the spell parser (Simplified, zhCN, and
-- Traditional, zhTW).
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- The wordings of WoW: Forever's Chinese spell descriptions: "造成15至23点火焰伤害", "在12秒内造成累计40点伤害",
-- "每2秒恢复91点生命值", "1点：25点伤害，持续8秒". What a pack is, and how to add one, is in Parser.lua (LANGUAGE PACKS).
-- WRITTEN FROM WOWHEAD'S FOREVER TOOLTIPS (nether.wowhead.com/forever/tooltip/spell/<id>?locale=cn and tw), NOT from a /sdi dump
-- of a Chinese client: the wording of the French and Spanish pages matched the game's own texts, the numbers did not always.
-- It has not been compared with a Chinese client yet, and the Traditional text is read by turning its characters into
-- Simplified ones first (the table below) and mapping the few words Taiwan says differently. A wording the pack does not know
-- stays unread: it never guesses.
--
-- Chinese has no spaces: rewrite puts spaces around every number and the word of its unit, turns the full-width punctuation into
-- plain, and the engine then reads the text like the others. Pure Lua 5.1, no game API.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser = ns.Parser

local U = Parser.util
local NUM, num, D, hasAny, stripFillers = U.NUM, U.num, U.D, U.hasAny, U.stripFillers
local find, sub, gsub, match = string.find, string.sub, string.gsub, string.match
local tonumber, floor = tonumber, math.floor

-- Traditional characters and the Simplified ones they become (the characters of Wowhead's Traditional spell texts that differ).
local T2S_FROM = "並亂來個們偵備傳傷僅儀優兇內兩凍別則剛劍動務勵區卻參叢員啟喚喪單嘗嘯嚇圍圖團堅報場塊墜壓夠夢奧學實審寵寶將專對導層屬崗師帶廢強彈後徑從復悶惡慄態憤應懲懼懾戰戲戶掃採換揮損撫擁擇擊擋擔據擲擺擾攜敗敵數斬斷於時暈暫書會條梟棲業極榮樂標樣樹機橫檢欄權歸殘殞殺毀氣決沒淨減測湧準滅滿漸潔潛災為無煉煩熱燒爐爾牆犧狀獄獅獎獲獵獸獻現瑪環產畫當疊瘋瘓療癒癡癱發盜監碼礎礦禍禦禱種積節範籠糾紅納純級細終結給經維綿線緩練縛縮總繞繳繼續纏罰羅習聖職聽脅脫腎腳膚臨與興荊蕩薩藥蘇處虛號蝕蟲蠍術衛衝裏裝裡製複襲見視觀觸計訊訓記設詛試話該語誠誦說調談請論諷識譯譴護譽讀變讓責費資賊賜賦蹤躍軍軸較輝轉轟這連週進遊運過達遠適遲選還邊鄰釋釘針鋒錐錘鍊鍵鎖鐘鐵長門閃開閒間閱闆關陣陸隊隕際隨隱隻雙離難電靈韌響項順須預領頭頻顆額類顯風飛飲餅餘館餵馬馴騎騰驅驗體鬆鬚鬥魯鷹麵麼黃點龍"
local T2S_TO = "并乱来个们侦备传伤仅仪优凶内两冻别则刚剑动务励区却参丛员启唤丧单尝啸吓围图团坚报场块坠压够梦奥学实审宠宝将专对导层属岗师带废强弹后径从复闷恶栗态愤应惩惧慑战戏户扫采换挥损抚拥择击挡担据掷摆扰携败敌数斩断于时晕暂书会条枭栖业极荣乐标样树机横检栏权归残殒杀毁气决没净减测涌准灭满渐洁潜灾为无炼烦热烧炉尔墙牺状狱狮奖获猎兽献现玛环产画当叠疯痪疗愈痴瘫发盗监码础矿祸御祷种积节范笼纠红纳纯级细终结给经维绵线缓练缚缩总绕缴继续缠罚罗习圣职听胁脱肾脚肤临与兴荆荡萨药苏处虚号蚀虫蝎术卫冲里装里制复袭见视观触计讯训记设诅试话该语诚诵说调谈请论讽识译谴护誉读变让责费资贼赐赋踪跃军轴较辉转轰这连周进游运过达远适迟选还边邻释钉针锋锥锤炼键锁钟铁长门闪开闲间阅板关阵陆队陨际随隐只双离难电灵韧响项顺须预领头频颗额类显风飞饮饼余馆喂马驯骑腾驱验体松须斗鲁鹰面么黄点龙"
local T2S = {}
do
  local function chars(s)
    local out = {}
    for c in s:gmatch("[\228-\233][\128-\191][\128-\191]") do out[#out + 1] = c end
    return out
  end
  local from, to = chars(T2S_FROM), chars(T2S_TO)
  for i = 1, #from do T2S[from[i]] = to[i] end
end

-- School words after "点", the Simplified wording first, Taiwan's after it.
local SCHOOLS = {
  { "霜火", "frostfire" }, { "暗焰", "shadowflame" }, { "法火", "spellfire" }, { "法霜", "spellfrost" }, { "暗霜", "shadowfrost" },
  { "火焰", "fire" }, { "冰霜", "frost" }, { "自然", "nature" }, { "暗影", "shadow" }, { "神圣", "holy" }, { "奥术", "arcane" },
  { "秘法", "arcane" }, { "物理", "physical" }, { "混乱", "chaos" }, { "混沌", "chaos" }, { "奇美拉", "chimeral" }, { "嵌合", "chimeral" },
  { "流血", "physical" }, { "出血", "physical" },
}

-- Words of this language, for telling a Chinese client's English texts (Forever leaves some of its spells in English; they
-- keep the Chinese unit: "over 21秒").
local CHINESE_WORDS = { "伤害", "目标", "造成", "恢复", "治疗", "持续", "法术", "生命值" }

local function detect(t)
  return find(t, "伤害", 1, true) or find(t, "目标", 1, true)
end

-- "1,742" -> "1742", full-width percent
local function normaliseNumbers(t)
  t = gsub(t, "％", "%%")
  local prev
  repeat prev = t; t = gsub(t, "([0-9]),([0-9][0-9][0-9])%f[^0-9]", "%1%2") until t == prev
  return t
end

local function toEnglish(text)
  text = gsub(text, "([0-9]) ?秒", "%1 sec")
  text = gsub(text, "([0-9]) ?分钟", "%1 min")
  return text
end

-- Spaces around numbers and units, plain punctuation, Simplified characters, one spelling of the phrases the pack reads.
local function rewrite(t)
  t = gsub(t, "[\228-\233][\128-\191][\128-\191]", T2S)
  t = gsub(t, "机率", "几率")
  t = gsub(t, "生命力", "生命值")
  -- Taiwan's words: "圣骑士生命值上限的生命值" (Lay on Hands), "每秒将12点生命值转移给施法者的宠物, 最多持续10秒" (Health Funnel)
  t = gsub(t, "生命值上限", "最大生命值")
  t = gsub(t, "转移给施法者的宠物", "宠物分配")
  t = gsub(t, "最多持续", "持续")
  t = gsub(t, "启动", "激活")
  t = gsub(t, "，", ", ")
  t = gsub(t, "。", ". ")
  t = gsub(t, "：", ": ")
  t = gsub(t, "；", "; ")
  t = gsub(t, "、", ", ")
  t = gsub(t, "（", " (")
  t = gsub(t, "）", ") ")
  t = gsub(t, "(%d)([\128-\255])", "%1 %2")
  t = gsub(t, "([\128-\255])(%d)", "%1 %2")
  t = gsub(t, "%%([\128-\255])", "%% %1")
  -- the unit of time is a word of its own, so the words after it stay in the clause
  for _, unit in ipairs({ "分钟", "小时", "秒" }) do
    t = gsub(t, "(%d) " .. unit, "%1 " .. unit .. " ")
  end
  t = gsub(t, "(%d) 到 (%d)", "%1 至 %2")
  -- Health Funnel: "为施法者的宠物恢复12点生命值" gives the pet health the caster pays, no heal
  t = gsub(t, "宠物恢复", "宠物分配")
  t = gsub(t, "并转移给施法者", " 转移给施法者")
  t = gsub(t, "(复活[^%.]-)恢复", "%1获得")
  t = gsub(t, "降低", " 降低")
  -- "150%的武器伤害" -> "150% 武器伤害": a particle is more than one byte, so a pattern cannot make it optional
  t = gsub(t, "的武器伤害", "武器伤害")
  t = gsub(t, "的普通伤害", "普通伤害")
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  t = gsub(t, ", 目标身上的每层[^%.,]-额外附加 " .. NUM .. " ?%% 武器伤害", "")
  t = gsub(t, ", 且目标身上每有一层[^%.,]-外加 " .. NUM .. " ?%% 武器伤害", "")
  return (gsub(t, " +", " "))
end

local function takeLasts(t, take)
  for _, unit in ipairs({ "分钟", "小时", "秒" }) do
    -- ", 持续10秒" and ". 持续10秒": the time the whole effect lasts, for the "every N sec" amounts that say none of their own
    t = gsub(t, "([%.,] )持续 (" .. NUM .. ") (" .. unit .. ")", function(dot, n, u)
      take(n, u)
      return dot
    end)
  end
  return t
end

local function takeInterval(c, onNumber, onOne)
  c = gsub(c, "每 (" .. NUM .. ") (秒)", onNumber)
  c = gsub(c, "每 (" .. NUM .. ") (分钟)", onNumber)
  c = gsub(c, "每秒", onOne)
  return c
end

local FILLERS = { "点", "额外的", "额外", "累计", "共", "基础", "的" }

-- The school named by the words after "点": its code, nil where the damage names none ("40点伤害"), false where the word is
-- no school.
local function schoolOf(s)
  if sub(s, 1, 6) == "伤害" then return "physical" end
  for _, school in ipairs(SCHOOLS) do
    local word = school[1]
    if sub(s, 1, #word) == word then
      if sub(s, #word + 1, #word + 6) == "伤害" then return school[2] end
      return false
    end
  end
  return false
end

local function classifyAfter(after, sentence)
  local s = stripFillers(after, FILLERS)
  local school = schoolOf(s)
  if school then return "damage", school end
  if sub(s, 1, 9) == "生命值" then
    if find(sentence, "吸取", 1, true) or find(sentence, "转移给施法者", 1, true) then return "drain", nil end
    if find(sentence, "宠物分配", 1, true) then return "petheal", nil end
  end
  return nil
end

local function healAmountOK(_, after)
  local s = stripFillers(after, { "点" })
  -- "为单一目标治疗819至920点伤害": a heal said in points of damage
  return sub(s, 1, 9) == "生命值" or sub(s, 1, 6) == "伤害"
end

local function ignoredClause(c)
  -- Hellfire: "对他自身造成86点火焰伤害，并对周围的所有敌人每1秒造成86点火焰伤害": the caster's own
  return find(c, "吸收", 1, true) or find(c, "自身", 1, true) or find(c, "每吸取", 1, true) or find(c, "分担", 1, true)
end

local function perPointTable(t)
  return find(" " .. t, "[^0-9]1 点 *:")
end

-- A consumable's amounts: health lo..hi, mana mlo..mhi, and a stated duration.
local function itemHeal(t)
  local lo, hi, mlo, mhi, dur
  dur, lo = match(t, "在 (" .. NUM .. ") 秒 内恢复 (" .. NUM .. ") 点生命值")
  if not lo then lo, dur = match(t, "恢复 (" .. NUM .. ") 点生命值, 持续 (" .. NUM .. ") 秒") end
  if not lo then
    lo, hi = match(t, "恢复 (" .. NUM .. ") 至 (" .. NUM .. ") 点生命值")
    if not lo then lo = match(t, "恢复 (" .. NUM .. ") 点生命值") end
  end
  mlo, mhi = match(t, "恢复 (" .. NUM .. ") 至 (" .. NUM .. ") 点法力")
  if not mlo then mlo = match(t, "恢复 (" .. NUM .. ") 点法力") end
  return lo, hi, mlo, mhi, dur, false
end

-- A drink: "使用: 在 18 秒内恢复 151 点法力值"
local function itemDrink(t)
  local d, m = match(t, "在 (" .. NUM .. ") 秒 内恢复 (" .. NUM .. ") 点法力")
  if m then return m, d end
  m, d = match(t, "恢复 (" .. NUM .. ") 点法力[^%d]-持续 (" .. NUM .. ") 秒")
  return m, d
end

local REDUCE_VERBS = { "降低", "减少", "削弱" }

local function reductionStat(c)
  return find(c, "攻击强度", 1, true), find(c, "伤害", 1, true)
end

local function attackPowerIn(sentence)
  if not find(sentence, "攻击强度", 1, true) then return nil end
  if hasAny(sentence, REDUCE_VERBS) or find(sentence, "几率", 1, true) then return nil end
  if find(sentence, "[^0-9]1 点 *:") then return nil end
  local a = match(sentence, "攻击强度提高 (" .. NUM .. ") 点") or match(sentence, "攻击强度提高 (" .. NUM .. ")")
  if not a then return nil end
  return { kind = "ap", amount = num(a), ranged = find(sentence, "远程", 1, true) ~= nil,
    plusAgility = find(sentence, "再加上敏捷", 1, true) ~= nil }
end

local function schoolCode(word)
  for _, school in ipairs(SCHOOLS) do
    if word == school[1] then return school[2] end
  end
  return nil
end

local function weaponZH(t)
  local p, a, b, school
  -- Windfury Weapon and Totem: "获得额外的2次攻击，且这些攻击的近战攻击强度提高104点"
  a, b = match(t, "额外的 (" .. NUM .. ") 次攻击[^%d]-攻击强度提高 (" .. NUM .. ") 点")
  -- Taiwan: "使你额外造成2次攻击，这些攻击获得额外104点近战攻击强度"
  if not a then a, b = match(t, "额外造成 (" .. NUM .. ") 次攻击[^%d]-获得额外 (" .. NUM .. ") 点近战攻击强度") end
  if a then return { kind = "extra", attacks = num(a), amount = num(b) } end
  -- Seal of Command: "有一定几率对目标造成与攻击伤害的70%等量的神圣伤害"
  p, school = match(t, "几率[^%d]-(" .. NUM .. ") ?%% ?等量的(......)伤害")
  -- Taiwan: "有一定几率对目标造成与武器伤害70%的等量神圣伤害"
  if not p then p, school = match(t, "几率[^%d]-武器伤害 (" .. NUM .. ") ?%% 的等量(......)伤害") end
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = schoolCode(school) } end
  if find(t, "几率", 1, true) then return nil end
  -- Flametongue, Seal of Righteousness, Seal of Fury: "额外造成14点神圣伤害", "额外造成X至Y点火焰伤害"
  local lo, hi
  lo, hi, school = match(t, "额外造成 (" .. NUM .. ") 至 (" .. NUM .. ") 点(......)伤害")
  if not lo then
    lo, school = match(t, "近战攻击额外造成 (" .. NUM .. ") 点(......)伤害")
    hi = lo
  end
  if lo then
    return { kind = "perhit", min = num(lo), max = num(hi), school = schoolCode(school),
      bySpeed = find(t, "武器速度", 1, true) and true or nil }
  end
  -- Mutilate: "每把武器造成90%武器伤害，外加40点伤害"
  p, a = match(t, "每把武器造成 (" .. NUM .. ") ?%% ?武器伤害[^%d]-(" .. NUM .. ") 点")
  if p then return { kind = "both", pct = num(p), bonus = num(a) } end
  -- Backstab, Ambush: "造成250%的武器伤害再加上70点额外伤害", Holy Strike: "造成29%武器伤害, 外加15至20点神圣伤害"
  p, a, b = match(t, "(" .. NUM .. ") ?%% ?武器伤害[^%d]-(" .. NUM .. ") 至 (" .. NUM .. ") 点")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a), bonusMax = num(b) } end
  p, a = match(t, "(" .. NUM .. ") ?%% ?武器伤害[^%d]-(" .. NUM .. ") 点")
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% ?普通伤害[^%d]-(" .. NUM .. ") 点") end
  -- Taiwan's Primal Bite: "造成100%普通伤害外加42，并产生大量威胁值"
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% ?普通伤害外加 (" .. NUM .. ")[ ,]") end
  if not p then p, a = match(t, "武器伤害的 (" .. NUM .. ") ?%%[^%d]-(" .. NUM .. ") 点") end
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Bloodthirst, Shuriken Toss: "造成相当于攻击强度45%外加30点的伤害"
  p, a = match(t, "攻击强度 (" .. NUM .. ") ?%%[^%d]-(" .. NUM .. ") 点")
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% ?攻击强度[^%d]-(" .. NUM .. ") 点") end
  if not p then p = match(t, "(" .. NUM .. ") ?%% ?攻击强度") end
  if not p then p = match(t, "攻击强度 (" .. NUM .. ") ?%%") end
  if p then return { kind = "appct", pct = num(p), bonus = num(a) or 0 } end
  -- "造成150%的武器伤害", "造成武器伤害外加5点伤害", "造成近战武器伤害，外加5点伤害", "造成普通武器伤害再加上3点额外伤害"
  p = match(t, "造成 (" .. NUM .. ") ?%% ?武器伤害")
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  -- Hammer of the Righteous: "造成相当于主手武器每秒伤害3倍的神圣伤害"
  a, school = match(t, "主手武器每秒伤害 (" .. NUM .. ") 倍的(......)伤害")
  if a then return { kind = "dps", times = num(a), school = schoolCode(school) or "physical" } end
  -- Sniper Shot: "造成远程伤害外加320点伤害": the ranged weapon's hit plus the amount
  a = match(t, "造成远程伤害外加 (" .. NUM .. ") 点")
  if a then return { kind = "weapon", pct = 100, bonus = num(a), ranged = true } end
  a = match(t, "造成[^%d]-武器伤害[^%d]-(" .. NUM .. ") 点")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  if find(t, "造成武器伤害", 1, true) then return { kind = "weapon", pct = 100, bonus = 0 } end
  -- the next swing, or a shot, gets more: "使近战攻击所造成的伤害提高11点", "使德鲁伊的下一次攻击造成额外的18点伤害", "使远程伤害提高40点"
  a = match(t, "近战攻击所造成的伤害提高 (" .. NUM .. ") 点") or match(t, "下一次攻击造成额外的 (" .. NUM .. ") 点伤害")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "远程伤害提高 (" .. NUM .. ") 点")
  if a then return { kind = "next", bonus = num(a), ranged = true } end
  -- Strength of Earth, Grace of Air
  -- (Taiwan writes "力量提高7，持续5分钟" without the 点)
  a = match(t, "力量提高 (" .. NUM .. ") 点") or match(t, "力量提高 (" .. NUM .. ")[ ,]")
  if a then return { kind = "stat", stat = "str", amount = num(a) } end
  a = match(t, "敏捷提高 (" .. NUM .. ") 点") or match(t, "敏捷提高 (" .. NUM .. ")[ ,]")
  if a then return { kind = "stat", stat = "agi", amount = num(a) } end
  return nil
end

-- "对其立刻造成69至73点神圣伤害"
local function judgement(part)
  local lo, hi, school = match(part, "造成 (" .. NUM .. ") 至 (" .. NUM .. ") 点(......)伤害")
  if not lo then return nil end
  return lo, hi, schoolCode(school)
end

local function sealDuration(t)
  return match(t, "持续 (" .. NUM .. ") 秒")
end

local function special(t)
  local n, m, dur, lo, hi, school, first, extra
  -- shields: "吸收162点火焰伤害"
  n = match(t, "吸收 (" .. NUM .. ") 点")
  if n then return { absorb = num(n) } end
  -- Lay on Hands: "恢复相当于圣骑士最大生命值的生命值", "治疗量等同于圣骑士最大生命值"
  if find(t, "圣骑士最大生命值", 1, true) then return { healMaxHealth = true } end
  -- Life Tap: "将你的48点生命值转化为48点法力值"
  n, m = match(t, "将你的 (" .. NUM .. ") 点生命值转化为 (" .. NUM .. ") 点法力")
  if n then return { healthCost = num(n), manaGain = num(m) } end
  -- Holy Shock: "造成175至189点神圣伤害，或为盟友恢复150至162点生命值"
  local hlo, hhi
  lo, hi, school, hlo, hhi = match(t, "(" .. NUM .. ") 至 (" .. NUM .. ") 点(......)伤害, 或为[^%d]-恢复 (" .. NUM .. ") 至 (" .. NUM .. ") 点生命值")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = schoolCode(school) } end
  -- Death Coil: "对其造成285点暗影伤害，所有伤害都被用来治疗施法者"
  n, school = match(t, "造成 (" .. NUM .. ") 点(......)伤害, 所有伤害都被用来治疗施法者")
  if n then return { direct = D(n), heal = D(n), school = schoolCode(school), transfer = true } end
  -- Execute: "造成125点基础伤害，并将每一个额外的怒气点数转化为3点额外伤害"
  n, m = match(t, "造成 (" .. NUM .. ") 点基础伤害, 并将每一个额外的怒气点数转化为 (" .. NUM .. ") 点额外伤害")
  if n then return { direct = D(n), school = "physical", perRage = num(m) } end
  -- Searing Totem: "它可以频繁攻击半径20码范围内的某个敌人，每次对其造成9至11点火焰伤害"
  lo, hi, school = match(t, "频繁攻击[^%.]-每次对其造成 (" .. NUM .. ") 至 (" .. NUM .. ") 点(......)伤害")
  if lo then return { direct = D(lo, hi), school = schoolCode(school), perAttack = true } end
  -- Healing Stream Totem: "每2秒对半径30码范围内的所有小队成员恢复5点生命值"
  m, n = match(t, "每 (" .. NUM .. ") 秒 对半径[^%.]-恢复 (" .. NUM .. ") 点生命值")
  if n then return { heal = D(n), every = num(m) } end
  -- Retribution Aura: "对任何攻击30码内队伍成员的生物造成5点神圣伤害"
  n, school = match(t, "对任何攻击[^%d]-码内队伍成员的生物造成 (" .. NUM .. ") 点(......)伤害")
  if n then return { direct = D(n), school = schoolCode(school), perStrike = true } end
  -- Holy Shield: "每次成功格挡都会对攻击者造成75点神圣伤害"
  n, school = match(t, "每次成功格挡都会对攻击者造成 (" .. NUM .. ") 点(......)伤害")
  if n then return { direct = D(n), school = schoolCode(school), perBlock = true } end
  -- Consecration: "对进入该区域的敌人在8秒内造成24点神圣伤害。最先进入该区域的4个敌人还会在8秒内额外受到56点伤害"
  dur, n, school, first, extra = match(t, "在 (" .. NUM .. ") 秒 内造成 (" .. NUM .. ") 点(......)伤害%. ?最先进入该区域的 (" .. NUM
    .. ") 个敌人还会在 " .. NUM .. " 秒 内额外受到 (" .. NUM .. ") 点伤害")
  -- Taiwan: "在8秒内对进入该区域的所有敌人造成24点神圣伤害。前4个进入该区域的敌人在8秒内额外受到56点伤害"
  if not n then
    dur, n, school, first, extra = match(t, "在 (" .. NUM .. ") 秒 内对进入该区域的所有敌人造成 (" .. NUM .. ") 点(......)伤害%. ?前 (" .. NUM
      .. ") 个进入该区域的敌人在 " .. NUM .. " 秒 内额外受到 (" .. NUM .. ") 点伤害")
  end
  if n then
    return { dot = { total = num(n) + num(extra), duration = num(dur) }, school = schoolCode(school), first = num(first) }
  end
  -- Dark Sacrifice: "在15秒内吞噬自身的440点生命值，以恢复431点法力值", Taiwan: "在15秒内牺牲自身440点生命值，以获得431点法力"
  dur, n, m = match(t, "在 (" .. NUM .. ") 秒 内吞噬自身的 (" .. NUM .. ") 点生命值, 以恢复 (" .. NUM .. ") 点法力")
  if not n then dur, n, m = match(t, "在 (" .. NUM .. ") 秒 内牺牲自身 (" .. NUM .. ") 点生命值, 以获得 (" .. NUM .. ") 点法力") end
  if n then return { healthCost = num(n), manaGain = num(m), healthCostDuration = num(dur) } end
  -- Seal of Light, per trigger: "每次近战攻击都有一定几率回复39点生命值"
  n = match(t, "每次近战攻击都有一定几率回复 (" .. NUM .. ") 点生命值")
  if n then return { heal = D(n) } end
  return nil
end

-- "1点：25点伤害，持续8秒": the damage over time in one point's row, or "8秒内造成25点伤害" (Taiwan's order).
local function finisherDot(seg)
  local total, dur = match(seg, "^ *(" .. NUM .. ") 点伤害,? ?持续 (" .. NUM .. ") 秒")
  if not total then dur, total = match(seg, "^ *(" .. NUM .. ") 秒 内造成 (" .. NUM .. ") 点伤害") end
  if not total then dur, total = match(seg, "^ *(" .. NUM .. ") 秒 内 (" .. NUM .. ") 点伤害") end
  if not total then dur, total = match(seg, "^ *持续 (" .. NUM .. ") 秒 内造成 (" .. NUM .. ") 点伤害") end
  return total, dur
end

local function procChance(t)
  -- "每次击中敌人都有20%的几率", "每次主手命中都有20%的几率": a hit, not any chance in the text
  local p = match(t, "每次[^%.,]-命中都有 (" .. NUM .. ") ?%% 的几率") or match(t, "每次击中敌人都有 (" .. NUM .. ") ?%% 的几率")
    or match(t, "每次近战攻击都有 (" .. NUM .. ") ?%% 的几率") or match(t, "每次命中敌人时都有 (" .. NUM .. ") ?%% 的几率")
  if p then return num(p) end
  if find(t, "一定几率", 1, true) then return true end
  return nil
end

local function unreadKind(t)
  for after in t:gmatch(NUM .. "([^0-9]*)") do
    local s = stripFillers(after, FILLERS)
    if sub(s, 1, 6) == "伤害" then return "unread-damage" end
  end
  if hasAny(t, { "伤害", "生命值", "攻击强度", "吸收" }) then return "unread-effect" end
  return "utility"
end

Parser.RegisterPack("zh", {
  rangeWord = "至",
  damageWord = "伤害",
  weaponWord = "武器伤害",
  pointsMarker = "点",
  healWords = { "恢复", "治疗", "回复" },
  clauseSeparators = { ", ", "并", "且", "同时" },
  reduceVerbs = REDUCE_VERBS,
  enemyWords = { "目标", "敌人", "攻击者" },
  selfWords = { "你的", "你受到" },
  increaseWord = "提高",
  byWord = "降低 ",
  sealEnergy = "释放这种圣印的能量",
  judgementSpell = "对敌人释放圣印法术的能量",
  words = CHINESE_WORDS,
  units = { ["秒"] = 1, ["分钟"] = 60, ["小时"] = 3600 },
  distanceWords = { ["码"] = true, ["米"] = true },
  hp5 = "不会匹配的(" .. NUM .. ")(" .. NUM .. ")",
  tickTails = { "^ *每 " },
  durationMarkers = { "秒", "分钟", "每 " },
  drainWords = { "吸取" },
  manaWord = "法力",
  healing = {
    targets = {},
    channel = { "引导" },
    trigger = { "几率", "点击" },
    stack = { "叠加" },
    pet = { "宠物" },
    target = { "目标", "友方" },
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
  weapon = weaponZH,
  attackPower = attackPowerIn,
  judgement = judgement,
  sealDuration = sealDuration,
  special = special,
  finisherDot = finisherDot,
  procChance = procChance,
  unreadKind = unreadKind,
})
