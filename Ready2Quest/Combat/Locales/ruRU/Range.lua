-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: русские тексты вкладки Range. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT.RegisterLocale("ruRU", {
  -- предпросмотр и блок «Попробуйте»
  ["Simulate: out of range"] = "Сымитировать выход за пределы дальности",
  ["Simulate: no nameplate"] = "Без таблички цели",
  ["Preview the target without a visible nameplate."] = "Показать цель без видимой таблички в предпросмотре.",
  ["No nameplate - marker hidden"] = "Нет таблички — отметка скрыта",
  ["The preview only: the red X while it is checked, the green checkmark while it is not."] =
    "Только для предпросмотра: при установленном флажке отображается красный крест, без него — зелёная галочка.",
  ["In range - the green checkmark"] = "В пределах дальности — зелёная галочка",
  ["Out of range - the red X"] = "Вне дальности — красный крест",
  ["%s (off on your target)"] = "%s (выключено для вашей цели)",
  ["Grey and dim out of range"] = "Затемнять и обесцвечивать вне дальности",
  ["Left alone - the dimming is off"] = "Без изменений — затемнение отключено",
  ["Its own colours in range"] = "Собственные цвета в пределах дальности",
  ["A sample only: the mark and the dimming happen on your own target and bars."] =
    "Только пример: отметка и затемнение применяются к вашей цели и панелям действий.",

  -- вкладки
  ["Icon"] = "Значок",
  ["Action bar"] = "Панель действий",

  -- вкладка «Значок»
  ["Checkmark in range"] = "Галочка в пределах дальности",
  ["The green checkmark over your target while one of the measuring spells reaches it."] =
    "Зелёная галочка над целью, когда до неё достаёт одно из проверочных заклинаний.",
  ["Red X out of range"] = "Красный крест вне дальности",
  ["The red X over your target while none of the measuring spells reaches it."] =
    "Красный крест над целью, когда ни одно из проверочных заклинаний до неё не достаёт.",
  ["Beside the target frame, even with a nameplate"] = "Рядом с рамкой цели, даже при видимой табличке",
  ["The mark sits beside the target frame instead of above the target's nameplate. Without a target frame on screen it stays above the nameplate."] =
    "Отметка отображается рядом с рамкой цели, а не над табличкой. Если рамки цели нет на экране, отметка остаётся над табличкой.",
  ["Beside the target frame without a nameplate"] = "Рядом с рамкой цели, если табличка не видна",
  ["Without a nameplate (nameplates off, the target off screen) the mark sits beside the target frame instead."] =
    "Если табличка не отображается (таблички отключены или цель за экраном), отметка появляется рядом с рамкой цели.",
  ["The mark's size in pixels."] = "Размер отметки в пикселях.",
  ["Height above the bar"] = "Высота над полосой",
  ["Pixels above the nameplate's health bar: over the row of debuff icons there."] =
    "Расстояние в пикселях над полосой здоровья таблички, выше ряда значков отрицательных эффектов.",

  -- вкладка «Панель действий»
  ["Grey out action bar icons"] = "Затемнять значки на панели действий",
  ["While the target is out of an action's range its icon goes grey and dim, on top of the game's red key binding."] =
    "Когда цель вне досягаемости способности, её значок становится серым и тусклым поверх красной подсказки клавиши игры.",

  -- вкладка «Заклинание»
  ["Measure by this spell"] = "Измерять дальность этим заклинанием",
  ["A spell name or id of your own to measure the range by; empty: your class's main attacks."] =
    "Название или ID заклинания, по которому измерять дальность; если поле пустое — основные атаки вашего класса.",
  ["Measured by: %s"] = "Измерение: %s",
  ["no spell of this class"] = "у этого класса нет заклинания",

  -- шаблоны
  ["Bare"] = "Простой",
  ["%s preset applied."] = "Применён шаблон «%s».",

  -- пример оформления
  ["Range sample (not your target)"] = "Пример дальности (не ваша цель)",
  ["In range - above nameplate"] = "В пределах дальности — над табличкой",
  ["Out of range - beside target frame"] = "Вне дальности — рядом с рамкой цели",
})
