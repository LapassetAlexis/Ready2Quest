-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- DoTInfo: use SDI's dump-backed Russian reader rather than duplicate its wordings.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")
local Parser = BIT.Module("SpellDamageInfo").Parser
local SCHOOLS = { physical = 1, holy = 2, fire = 4, nature = 8, frost = 16, shadow = 32, arcane = 64,
  frostfire = 20, shadowflame = 36, spellfire = 68, spellfrost = 80, shadowfrost = 48, chaos = 127, chimeral = 84 }

ns.locale.register({
  tag = "ruRU",
  isFinisher = function(desc) return desc:find("Завершающий", 1, true) ~= nil end,
  comboPointsAwarded = function(desc)
    return tonumber(desc:match("Длина серии приемов увеличивается на (%d+)")
      or desc:match("Продлевает серию приемов на (%d+)"))
  end,
  parseDot = function(desc, comboPoints)
    if not desc:find("[\208\209][\128-\191]") then return nil end
    if desc:find("Смазать оружие", 1, true) then return nil end
    local entry = Parser.Read(desc, "ru")
    if entry.finisher and entry.finisher.kind == "dot" then
      local points = entry.finisher.points
      local p = math.max(1, math.min(comboPoints or 1, entry.finisher.top))
      local dot = points[p] or points[entry.finisher.top]
      return dot.total, 1, dot.duration
    end
    local parsed = entry.parsed
    if parsed and parsed.dot then
      return parsed.dot.total, SCHOOLS[parsed.school] or (parsed.transfer and 32) or 1, parsed.dot.duration
    end
  end,
  names = {
    ["Arcane Missiles"] = { "Чародейские снаряды" },
    ["Bane of Agony"] = { "Бич агонии" },
    ["Black Arrow"] = { "Черная стрела" },
    ["Blizzard"] = { "Снежная буря" },
    ["Consecration"] = { "Освящение" },
    ["Corruption"] = { "Порча" },
    ["Curse of Agony"] = { "Бич агонии" },
    ["Deadly Poison"] = { "Смертельный яд" },
    ["Drain Life"] = { "Похищение жизни" },
    ["Drain Mana"] = { "Похищение маны" },
    ["Drain Soul"] = { "Похищение души" },
    ["Explosive Trap"] = { "Взрывная ловушка" },
    ["Fireball"] = { "Огненный шар" },
    ["Flamestrike"] = { "Огненный столб" },
    ["Frostfire Bolt"] = { "Стрела ледяного огня" },
    ["Garrote"] = { "Гаррота" },
    ["Health Funnel"] = { "Канал здоровья" },
    ["Hellfire"] = { "Адское Пламя" },
    ["Holy Fire"] = { "Священный огонь" },
    ["Hurricane"] = { "Гроза" },
    ["Immolation Trap"] = { "Обжигающая ловушка" },
    ["Insect Swarm"] = { "Рой насекомых" },
    ["Instant Poison"] = { "Быстродействующий яд" },
    ["Lacerate"] = { "Растерзать" },
    ["Mind Flay"] = { "Пытка разума" },
    ["Pyroblast"] = { "Огненная глыба" },
    ["Rain of Fire"] = { "Огненный ливень" },
    ["Rake"] = { "Глубокая рана" },
    ["Rend"] = { "Кровопускание" },
    ["Rip"] = { "Разорвать" },
    ["Rupture"] = { "Рваная рана" },
    ["Serpent Sting"] = { "Укус змеи" },
    ["Shadow Word: Pain"] = { "Слово Тьмы: Боль" },
    ["Siphon Life"] = { "Вытягивание жизни" },
    ["Starshards"] = { "Звездные осколки" },
    ["Volley"] = { "Град стрел" },
    ["Wound Poison"] = { "Нейтрализующий яд" },
  },
})
