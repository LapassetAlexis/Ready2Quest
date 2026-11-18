-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: русские тексты вкладки CastPrediction. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT.RegisterLocale("ruRU", {
  -- под-вкладки и предпросмотр
  ["Prediction"] = "Прогноз",
  ["In combat: the marker is on your target. The preview resumes after combat."] =
    "В бою маркер отображается на вашей цели. Предпросмотр возобновится после боя.",
  ["Sample spell"] = "Пример заклинания",
  ["Same marker on mock frames; sample damage is illustrative. Raise target health to hide the kill icon. While in combat, the marker returns to your target."] =
    "Тот же маркер на тестовых рамках; урон приведён для примера. Увеличьте здоровье цели, чтобы скрыть значок убийства. В бою маркер возвращается на вашу цель.",
  ["The marker shows what the description and your spell power give; hits seen in combat tune it. Crits, procs and resists stay unpredictable."] =
    "Маркер показывает урон по описанию заклинания и вашей силе заклинаний; попадания в бою уточняют оценку. Критические удары, срабатывания эффектов и сопротивление непредсказуемы.",
  ["CastPrediction sample"] = "Пример CastPrediction",
  ["Frostbolt 410-450 (estimate)"] = "Ледяная стрела 410–450 (оценка)",

  -- вкладка «Маркер»
  ["Show on party frames"] = "Показывать на рамках группы",
  ["Show on raid frames"] = "Показывать на рамках рейда",
  ["Show the prediction on the Blizzard or configured target frame."] =
    "Показывать прогноз на стандартной рамке цели Blizzard или настроенной рамке.",
  ["Also show the prediction on the focus frame when it represents the cast's target."] =
    "Также показывать прогноз на рамке фокуса, если фокус — цель заклинания.",
  ["Show the prediction only if a party frame represents the cast's recipient. Ordinary damage casts target enemies, not party members."] =
    "Показывать прогноз только тогда, когда получатель заклинания отображается на рамке группы. Обычные атакующие заклинания направлены на противников, а не на участников группы.",
  ["Show the prediction only if a raid frame represents the cast's recipient. Ordinary damage casts target enemies, not raid members."] =
    "Показывать прогноз только тогда, когда получатель заклинания отображается на рамке рейда. Обычные атакующие заклинания направлены на противников, а не на участников рейда.",
  ["Show the prediction on the cast target's nameplate."] =
    "Показывать прогноз на табличке цели заклинания.",
  ["For packs of mobs with the same name. With the mouse over a second mob of the pack, the addon can't tell which of the two your spell goes to and hides the prediction. With this on, your target (or focus, or the soft target when nothing is targeted) wins over the mob under the mouse. (If you cast with @mouseover macros, the prediction could then show on the wrong mob.)"] =
    "Для групп противников с одинаковыми именами. Если курсор наведён на другого противника из группы, аддон не может определить, по кому из них будет применено заклинание, и скрывает прогноз. Если включить эту настройку, приоритет получит ваша цель (или фокус, либо условная цель, если обычная цель не выбрана), а не противник под курсором. (При применении заклинаний макросами @mouseover прогноз может отображаться не на том противнике.)",
  ["THE MARKER"] = "МАРКЕР",
  ["Show the marker"] = "Показывать маркер",
  ["The predicted damage, drawn across enabled health bars while a cast is in flight."] =
    "Предсказанный урон отображается на включённых полосах здоровья, пока применяется заклинание.",
  ["CASTS AND CHANNELS"] = "ПРИМЕНЕНИЕ И НАПРАВЛЕННЫЕ ЗАКЛИНАНИЯ",
  ["Spell school"] = "Школа магии",
  ["Only your own cast is ever drawn on the bar."] = "На полосе отображается только ваше заклинание.",
  ["How strongly the fill covers the health bar."] = "Насколько непрозрачная заливка полосы здоровья.",
  ["Cast fill style"] = "Стиль заливки при применении",
  ["The fill of a cast in flight. Patterns, glass and bevel shadings, Blizzard's bar textures and every texture LibSharedMedia knows (ElvUI, Details, ...) are in the list; the fill color tints them."] =
    "Заливка во время применения заклинания. Список включает узоры, стеклянные и рельефные эффекты, текстуры полос Blizzard и все текстуры LibSharedMedia (ElvUI, Details и другие); цвет заливки окрашивает их.",
  ["Channel fill style"] = "Стиль заливки направленного заклинания",
  ["The fill of a channel (the damage that remains): a pattern shows it is a channel, not a single hit."] =
    "Заливка направленного заклинания (оставшийся урон): узор отличает его от одиночного удара.",
  ["A hairline around the marker; it can pulse while the cast is in flight."] =
    "Тонкая линия по краю маркера; во время применения она может пульсировать.",
  ["Pulse the outline"] = "Пульсирующий контур",
  ["A soft breathing of the outline while the cast is in flight."] =
    "Плавная пульсация контура во время применения заклинания.",
  ["Kill icon on the portrait"] = "Значок убийства на портрете",
  ["An icon when even the lowest end of the cast's range would finish the target. Drawn by a status bar, so it works with hidden health too."] =
    "Значок появляется, если даже минимальный урон заклинания убьёт цель. Он отображается на статус-баре, поэтому работает и при скрытой полосе здоровья.",
  ["Show killing spell icon"] = "Показывать значок убивающего заклинания",
  ["Enabled by default. When a cast or finisher would kill, show its spell icon instead of the generic kill icon. The finisher preview uses the icon for the finisher that would kill."] =
    "Включено по умолчанию. Если заклинание или завершающий приём убьёт цель, вместо обычного значка убийства показывается значок заклинания. В предпросмотре завершающего приёма отображается значок того приёма, который нанесёт смертельный удар.",
  ["Fallback kill icon"] = "Запасной значок убийства",
  ["Impact"] = "Удар",
  ["Shown when the spell icon option is off or that spell's icon is unavailable."] =
    "Показывается, если значок заклинания отключён или недоступен.",
  ["FINISHER PREVIEW"] = "ПРЕДПРОСМОТР ЗАВЕРШАЮЩЕГО ПРИЁМА",
  ["Preview fill style"] = "Стиль заливки предпросмотра",
  ["The fill of the finisher preview (Prediction tab), so it never reads as a real cast."] =
    "Заливка предпросмотра завершающего приёма (вкладка «Прогноз»), чтобы его нельзя было принять за настоящее применение заклинания.",
  ["Preview fill color"] = "Цвет заливки предпросмотра",
  ["Spell school, one of the colors, or a custom color from the picker. A fill style from the Colorful group (the default, Flame) has colors of its own and ignores this color; only its opacity applies."] =
    "Школа магии, один из цветов или выбранный вами цвет. Стиль заливки из группы «Цветные» (по умолчанию — «Пламя») использует собственные цвета и игнорирует этот цвет; применяется только непрозрачность.",
  ["Preview fill opacity"] = "Непрозрачность заливки предпросмотра",
  ["The marker covers health backwards from the current HP edge. At 60/100 HP, 20 damage covers 60 down to 40. Overkill is clipped inside the bar."] =
    "Маркер отсчитывает урон назад от текущего уровня здоровья. При 60/100 здоровья урон в 20 единиц занимает диапазон от 60 до 40. Избыточный урон ограничивается размером полосы.",

  -- вкладка «Текст»
  ["THE TEXT"] = "ТЕКСТ",
  ["Show text"] = "Показывать текст",
  ["The spell name and the number, at the spot picked below."] =
    "Название заклинания и число в выбранном ниже месте.",
  ["Text shows"] = "Что показывает текст",
  ["Damage"] = "Урон",
  ["Damage range"] = "Диапазон урона",
  ["Percent of the target's health"] = "Процент здоровья цели",
  ["Damage is the single estimate picked on the Prediction tab; the range shows both ends; the percent needs a readable target health (out of combat in Forever)."] =
    "Урон — это выбранная на вкладке «Прогноз» оценка; диапазон показывает обе границы. Для расчёта процента здоровье цели должно быть доступно (в Forever — вне боя).",

  -- вкладка «Таблички»
  ["NAMEPLATES"] = "ТАБЛИЧКИ",
  ["Nameplate style"] = "Стиль таблички",
  ["Marker on the health bar"] = "Маркер на полосе здоровья",
  ["Marker and an impact icon"] = "Маркер и значок удара",
  ["The target's own plate gets the same marker, with its own colors; enemy bars are red."] =
    "На табличке цели отображается такой же маркер в её цветах; полосы противников красные.",
  ["The impact icon beside or above the plate."] = "Значок удара рядом с табличкой или над ней.",
  ["Icon position"] = "Положение значка",
  ["Portrait"] = "Портрет",
  ["Show kill icon"] = "Показывать значок убийства",
  ["An icon when even the lowest end of the cast's range would finish the target. With secret health, native clipping can reveal part of the icon shortly before lethal."] =
    "Значок, когда даже минимальный урон заклинания убьёт цель. При скрытом здоровье нативное обрезание может показать часть значка незадолго до смертельного урона.",
  ["Below the bar"] = "Под полосой",
  ["Above the bar"] = "Над полосой",
  ["Right of the bar"] = "Справа от полосы",

  -- вкладка «Прогноз»
  ["THE PREDICTION"] = "ПРОГНОЗ",
  ["The marker shows"] = "Маркер показывает",
  ["Average of the range"] = "Среднее значение диапазона",
  ["Lowest of the range"] = "Минимальное значение диапазона",
  ["Highest of the range"] = "Максимальное значение диапазона",
  ["The expected damage the description and your spell power give."] =
    "Ожидаемый урон по описанию заклинания и вашей силе заклинаний.",
  ["Only cast spells"] = "Только применяемые заклинания",
  ["Show casts and channels. Instant spells are hidden unless this option is switched off."] =
    "Показывать применяемые и направленные заклинания. Мгновенные заклинания скрыты, пока эта настройка включена.",
  ["Finisher preview"] = "Предпросмотр завершающего приёма",
  ["Rogues and druids: while your target has combo points, show on its health bar and plate what your strongest damage finisher on the action bars (Eviscerate, Ferocious Bite, a rune's Between the Eyes) would deal at that count. On Forever the description's numbers leave out attack power, so the real hit is at least this much. Damage-over-time finishers (Rupture, Rip) and combo point builders are not shown. Needs SpellDamageInfo."] =
    "Разбойники и друиды: пока у цели есть очки серии приёмов, на её полосе здоровья и табличке показывается урон самого сильного завершающего приёма на панели действий (Потрошение, Свирепый укус или «Выстрел в упор» с руной) при текущем количестве очков. В Forever в числах описания не учитывается сила атаки, поэтому реальный урон будет не меньше указанного. Завершающие приёмы с периодическим уроном (Рваная рана, Разорвать) и приёмы, накапливающие очки серии, не отображаются. Требуется SpellDamageInfo.",
  ["Learn from hits"] = "Уточнять по попаданиям",
  ["Every non-crit hit that matches the cast bends the estimate toward what you actually deal. On Retail the description already holds your spell power, so only physical hits are learned there: the target's armor takes a share off them that the description does not say."] =
    "Каждое подходящее попадание без критического удара уточняет оценку в соответствии с фактическим уроном. В Retail описание уже учитывает силу заклинаний, поэтому там учитываются только физические удары: броня цели поглощает часть урона, не указанную в описании.",
  ["Manual spell power"] = "Задать силу заклинаний вручную",
  ["Use your own number instead of the client's reading, for testing or when the client hides it."] =
    "Использовать указанное вами значение вместо полученного от клиента — для проверки или если клиент его скрывает.",
  ["Spell power"] = "Сила заклинаний",
  ["Applied through the spell's own coefficient, like the client's own reading would be."] =
    "Учитывается с коэффициентом самого заклинания, как и значение, полученное от клиента.",
  ["Learned factors"] = "Накопленные коэффициенты",
  ["Forget what earlier hits taught the estimate."] = "Забыть, чему предыдущие попадания научили оценку.",
  ["TALENTS (FOREVER)"] = "ТАЛАНТЫ (FOREVER)",
  ["No curated passive talent multipliers for this class (or the character class could not be read). Retail tooltips already include talents, so nothing is added there."] =
    "Для этого класса нет настроенных множителей пассивных талантов (либо класс персонажа не удалось определить). В Retail подсказки уже учитывают таланты, поэтому дополнительные значения не применяются.",
  ["Auto (detect)"] = "Автоматически (определять)",
  ["Max rank"] = "Максимальный ранг",
  ["Auto reads the talent's rank from the client's talent tree (C_Traits). Off skips it; Max rank applies it without asking. Retail never adds talents: its descriptions hold them."] =
    "Автоматически считывает ранг таланта из дерева талантов клиента (C_Traits). «Выкл.» не учитывает талант; «Максимальный ранг» применяет его на максимуме. В Retail таланты не добавляются отдельно: они уже учтены в описаниях.",
  ["AURAS (READ WHEN VISIBLE)"] = "АУРЫ (СЧИТЫВАЮТСЯ, КОГДА ВИДНЫ)",
  ["Include auras"] = "Учитывать ауры",
  ["Buffs on you and debuffs on the target that the description does not hold: Arcane Power, Power Infusion, Improved Scorch, Curse of the Elements."] =
    "Положительные эффекты на вас и отрицательные эффекты на цели, не учтённые в описании: Arcane Power, Power Infusion, Improved Scorch, Curse of the Elements.",
  ["Auto (read)"] = "Автоматически (считывать)",
  ["Auto applies this while the client shows it. WoW: Forever hides auras in combat, so there it only ever applies out of combat; the hit calibration carries the rest. /upt castpred auras prints what is readable right now."] =
    "Автоматически учитывает эффект, пока клиент его показывает. WoW: Forever скрывает ауры в бою, поэтому там они учитываются только вне боя; остальное уточняется по попаданиям. Команда /upt castpred auras выводит доступные данные.",
  ["The estimate is the description's own damage range plus your spell power through the spell's coefficient, the detected passive talents and the readable auras. Critical strikes roll about double, so a crit can outrun the marker: the prediction is an honest estimate, never a promise. /upt castpred talents and /upt castpred auras print what the client answers."] =
    "Оценка складывается из диапазона урона в описании, вашей силы заклинаний с коэффициентом заклинания, обнаруженных пассивных талантов и доступных аур. Критические удары наносят примерно вдвое больше урона, поэтому могут превысить маркер: прогноз — честная оценка, а не гарантия. Команды /upt castpred talents и /upt castpred auras выводят ответы клиента.",

  -- таланты и ауры в списках (названия заклинаний не переводятся)
  ["Fire Power"] = "Fire Power",
  ["Crusade"] = "Crusade",
  ["Sacred Arbiter"] = "Sacred Arbiter",
  ["Improved Shadow Bolt"] = "Improved Shadow Bolt",
  ["Shadow and Flame"] = "Shadow and Flame",
  ["Decimation"] = "Decimation",
  ["Power in Light"] = "Power in Light",
  ["Arcane Power (player)"] = "Arcane Power (игрок)",
  ["Power Infusion (player)"] = "Power Infusion (игрок)",
  ["Improved Scorch (target)"] = "Improved Scorch (цель)",
  ["Curse of the Elements (rank 2) (target)"] = "Curse of the Elements (ранг 2) (цель)",
  ["Curse of the Elements (target)"] = "Curse of the Elements (цель)",
  ["Frigid Power (Ice Barrier) (player)"] = "Frigid Power (Ice Barrier) (игрок)",
  ["Ice Barrier (shield up) (player)"] = "Ice Barrier (щит активен) (игрок)",
  ["Fingers of Frost (player)"] = "Fingers of Frost (игрок)",
  ["Improved Shadow Bolt (target)"] = "Improved Shadow Bolt (цель)",
  ["Shadow and Flame (player)"] = "Shadow and Flame (игрок)",
  ["Decimation (player)"] = "Decimation (игрок)",
  ["Demonic Sacrifice (Imp) (player)"] = "Demonic Sacrifice (бес) (игрок)",
  ["Demonic Sacrifice (Succubus) (player)"] = "Demonic Sacrifice (суккуб) (игрок)",
  ["Immolate (Incinerate +25%) (target)"] = "Immolate (Incinerate +25%) (цель)",
  ["Power in Light (Holy Fire, Shadow Word: Pain) (target)"] = "Power in Light (Holy Fire, Shadow Word: Pain) (цель)",
  ["Shadow Weaving (target)"] = "Shadow Weaving (цель)",
  ["Shadowform (player)"] = "Shadowform (игрок)",
  ["Stormstrike (target)"] = "Stormstrike (цель)",
  ["Rage of the Farseer (player)"] = "Rage of the Farseer (игрок)",
  ["Eureka! (Gnome) (player)"] = "Eureka! (гном) (игрок)",

  -- сообщения чата
  ["Learned factors cleared."] = "Накопленные коэффициенты сброшены.",
  ["Nothing learned yet: cast damage spells at an enemy."] =
    "Данных пока нет: применяйте атакующие заклинания к противнику.",
  ["%s (%d): x%.2f from %d hit(s)%s"] = "%s (%d): x%.2f по %d попаданиям%s",
  [", %d hit(s) too far from the estimate to learn from"] =
    ", слишком далеко от оценки для анализа: попаданий — %d",
  ["... and %d more"] = "... и ещё %d",
  ["Health bar marker ON."] = "Маркер полосы здоровья включён.",
  ["Health bar marker OFF."] = "Маркер полосы здоровья выключен.",
  ["/upt castpred - open the settings; line - toggle the marker; talents - what the talent tree answers; auras - what buffs/debuffs are readable; learned - what the hits taught; census - read the whole talent tree into the saved settings (census clear removes it); reset - forget learned factors; debug - echo the trace log"] =
    "/upt castpred — открыть настройки; line — переключить маркер; talents — ответ дерева талантов; auras — доступные положительные и отрицательные эффекты; learned — вывод данных попаданий; census — сохранить всё дерево талантов в настройках (census clear удаляет его); reset — сбросить накопленные коэффициенты; debug — вывести журнал отладки",
  ["Show mana cost on your mana bar"] = "Показывать стоимость маны на вашей полосе маны",
  ["While you cast a spell with a cast time, marks its estimated mana cost on your mana bar."] =
    "Пока вы произносите заклинание со временем сотворения, на полосе маны отмечается его примерная стоимость.",
  ["While you cast a spell with a cast time, marks its estimated cost to the right of your remaining mana. This illustrates mana already spent, not another deduction."] =
    "Пока вы произносите заклинание со временем сотворения, его примерная стоимость отмечается справа от оставшейся маны. Это уже потраченная мана, а не дополнительное списание.",
})
