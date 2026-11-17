-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: русские тексты вкладки DoTInfo. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT.RegisterLocale("ruRU", {
  -- вкладки и кнопки
  ["Kill icon"] = "Значок убийства",
  ["Behavior"] = "Поведение",
  ["Pick"] = "Выбрать",
  ["Copy from Marker tab"] = "Скопировать с вкладки «Маркер»",
  ["Flash"] = "Вспышка",
  ["Simulate fight"] = "Сымитировать бой",
  ["Stop"] = "Остановить",
  ["View"] = "Просмотр",
  ["Info"] = "Сведения",
  ["Forget all"] = "Забыть всё",

  -- шаблоны оформления, значки убийства и списки
  ["Glass"] = "Стекло",
  -- В StatsInfo.lua также есть «Frost», но эта версия для Retail не загружает тот файл.
  ["Neon"] = "Неон",
  ["Carbon"] = "Карбон",
  ["Ember"] = "Угольки",
  ["Debug"] = "Отладка",
  ["Green checkmark"] = "Зелёная галочка",
  ["Boss skull"] = "Череп босса",
  ["Sunglasses"] = "Солнцезащитные очки",
  ["Fine dots (1px)"] = "Мелкие точки (1 пикс.)",
  ["Dots (2px)"] = "Точки (2 пикс.)",
  ["Short dashes (4px)"] = "Короткие штрихи (4 пикс.)",
  ["Dashes (8px)"] = "Штрихи (8 пикс.)",
  ["Long dashes (16px)"] = "Длинные штрихи (16 пикс.)",
  ["One color (fill color)"] = "Один цвет (цвет заливки)",
  ["By effect type"] = "По типу эффекта",
  ["Never (estimate straight away)"] = "Никогда (сразу оценивать)",
  ["When unsure"] = "Если нет уверенности",
  ["Always (real ticks only)"] = "Всегда (только реальные тики)",
  ["Marker only"] = "Только маркер",
  ["Marker and kill icon"] = "Маркер и значок убийства",
  ["Right of the health bar"] = "Справа от полосы здоровья",
  ["Left of the health bar"] = "Слева от полосы здоровья",
  ["Above the health bar"] = "Над полосой здоровья",
  ["Below the health bar"] = "Под полосой здоровья",
  ["Fill direction"] = "Направление заполнения",
  ["Follow health bar"] = "Как у полосы здоровья",
  ["Left to right"] = "Слева направо",
  ["Right to left"] = "Справа налево",
  ["Which end of the target health bar the marker starts from. Follow health bar turns it around on a mirrored bar that drains the other way; choose Right to left if your unit frame addon is not recognized."] =
    "С какого края полосы здоровья цели начинается метка. «Как у полосы здоровья» разворачивает её на зеркальной полосе, которая убывает в другую сторону; выберите «Справа налево», если ваш аддон рамок не распознан.",
  ["Shows an icon at the chosen position when your DoTs on the target will kill it."] =
    "Показывает значок в выбранном месте, когда ваши DoT убьют цель.",

  -- вкладка «Значок убийства»
  ["Show icon on portrait"] = "Показывать значок на портрете",
  ["Shows an icon over the target's portrait when your DoTs on it will kill it."] =
    "Показывает значок над портретом цели, если ваши DoT-эффекты её убьют.",
  ["Pulse"] = "Пульсация",
  ["Gently pulses the icon while it's showing."] =
    "Значок плавно пульсирует, пока отображается.",
  ["Pixels right (+) or left (-) of the portrait's center."] =
    "Смещение в пикселях вправо (+) или влево (−) от центра портрета.",
  ["Pixels up (+) or down (-) from the portrait's center."] =
    "Смещение в пикселях вверх (+) или вниз (−) от центра портрета.",

  -- вкладка «Маркер»
  ["Show damage marker"] = "Показывать маркер урона",
  ["Marks the damage your DoTs still have to deal on the target's health bar. If the health ends inside it, the target dies."] =
    "Отмечает на полосе здоровья цели оставшийся урон от ваших DoT-эффектов. Если здоровье заканчивается внутри отметки, цель погибает.",
  ["Keep this on to show the marker on your screen's target health bar. Plater changes nameplates, not that frame; if you use a separate unit frame addon, set its bar under Behavior > Target health bar. Turn off to keep the marker on nameplates and the focus frame only. On Retail this also hides the rogue's aura icons above the target bar. The kill icon has its own switch in the Kill icon tab."] =
    "Оставьте настройку включённой, чтобы маркер отображался на полосе здоровья цели на экране. Plater изменяет таблички, а не эту рамку; если вы используете отдельный аддон рамок, укажите его полосу в разделе «Поведение > Полоса здоровья цели». Отключите настройку, чтобы маркер оставался только на табличках и рамке фокуса. В Retail это также скрывает значки аур разбойника над полосой цели. У значка убийства отдельная настройка на вкладке «Значок убийства».",
  ["DoT colors"] = "Цвета DoT",
  ["One color, or one segment per DoT with green poisons, purple curses/shadow damage and red bleeds. Rainbow gives each spell a separate color."] =
    "Один цвет или отдельный сегмент для каждого DoT: зелёный для ядов, пурпурный для проклятий и урона от темной магии, красный для кровотечений. В режиме «Радуга» каждому заклинанию назначается отдельный цвет.",
  ["Used when DoT colors is set to one color."] =
    "Используется, если для DoT выбран один цвет.",
  ["Dividers between DoTs"] = "Разделители между DoT",
  ["Dash length"] = "Длина штриха",
  ["Outline thickness"] = "Толщина контура",

  -- вкладка «Эффекты»
  ["Smooth motion"] = "Плавное движение",
  ["The marker grows in when it appears and glides to new values instead of jumping."] =
    "Маркер плавно появляется и перемещается к новым значениям, а не прыгает.",
  ["Flash on new DoT"] = "Вспышка при новом DoT",
  ["Spark"] = "Искра",
  ["A bright flare on the marker's edge when a DoT lands."] =
    "Яркая вспышка на краю маркера при попадании DoT.",
  ["Pulse outline"] = "Пульсирующий контур",
  ["Glow"] = "Свечение",
  ["Soft halo in the outline color."] = "Мягкий ореол цвета контура.",
  ["Glow size"] = "Размер свечения",
  ["Shine sweep"] = "Пробегающий блик",
  ["Shine every"] = "Интервал блика",
  ["Scroll stripes"] = "Движение полос",
  ["Animates the diagonal stripes fill."] = "Анимирует заливку диагональными полосами.",

  -- вкладка «Текст»
  ["Show damage text"] = "Показывать текст урона",
  ["Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)."] =
    "Оставшийся урон от DoT рядом с полосой здоровья (разбивка по эффектам цветами DoT).",

  -- вкладка «Таблички»
  ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below."] =
    "Отображает маркер (и, при желании, значок убийства) на каждой табличке противника с вашими DoT, используя настроенное ниже оформление.",
  ["Draws the same marker (and optionally the kill icon) on your focus frame's health bar for your DoTs on the focused enemy, in the nameplate look below."] =
    "Отображает такой же маркер (и, при желании, значок убийства) на полосе здоровья рамки фокуса для ваших DoT на противнике в фокусе, используя оформление таблички ниже.",
  ["Kill icon size"] = "Размер значка убийства",
  ["Kill icon position"] = "Положение значка убийства",
  ["Pixels right (+) or left (-) of the chosen position."] =
    "Смещение в пикселях вправо (+) или влево (−) от выбранного положения.",
  ["Pixels up (+) or down (-) from the chosen position."] =
    "Смещение в пикселях вверх (+) или вниз (−) от выбранного положения.",
  ["By effect type: green poisons, purple curses/shadow damage and red bleeds. Rainbow: a separate color per spell."] =
    "По типу эффекта: зелёный для ядов, пурпурный для проклятий и урона от темной магии, красный для кровотечений. Радуга: отдельный цвет для каждого заклинания.",

  -- вкладка «Поведение»
  ["Wait for first tick"] = "Ждать первого тика",
  ["Whether a new DoT counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points and spells the addon hasn't seen tick yet."] =
    "Учитывать ли новый DoT до первого тика. В режиме «Если нет уверенности» ожидание применяется к завершающим приёмам с неизвестным количеством очков серии и заклинаниям, чьи тики аддон ещё не видел.",
  ["Show refresh marks"] = "Показывать отметки обновления",
  ["A gold edge on that DoT's segment while the time left is inside the refresh window: one tick, three seconds, or a quarter of the duration, whichever is longer. The damage number stays off unless you turn it on."] =
    "Золотая граница сегмента DoT, когда оставшееся время попадает в окно обновления: один тик, три секунды или четверть длительности — в зависимости от того, что дольше. Число урона скрыто, пока вы его не включите.",
  ["Ignite, Deep Wounds, traps"] = "Воспламенение, Глубокие раны, ловушки",
  ["Mages and warriors: a critical hit lights Ignite (a share of the fire crit over 4 s) or Deep Wounds (a share of your weapon damage over 12 s), with no cast to say so. Assumes you have the talent (when the talent tree can be read and shows no points, nothing is drawn). A crit counts as yours when you cast at that mob just before, or, for Deep Wounds, swing at it while alone; the first tick confirms it. Traps (Immolation Trap) are tracked as well."] =
    "Маги и воины: критический удар запускает Воспламенение (часть критического урона от огня за 4 сек.) или Глубокие раны (часть урона оружием за 12 сек.), хотя отдельного применения заклинания нет. Предполагается, что у вас есть этот талант (если дерево талантов доступно и в нём нет очков, эффект не отображается). Критический удар считается вашим, если незадолго до этого вы применили заклинание к противнику; для Глубоких ран также достаточно атаковать его оружием в одиночку. Первый тик подтверждает эффект. Ловушки (Огненная ловушка) тоже отслеживаются.",
  ["Death Mark (experimental)"] = "Метка смерти (экспериментально)",
  ["Rogues: shows what Death Mark has stored so far as one more segment, until it goes off 6 s after the finisher, never above the cap in its description. Garrote and Rupture ticks count twice. Experimental, off by default: the game doesn't say who hit the marked mob, so every hit on it counts as yours. In a party or raid the others' damage is counted too and the estimate runs high. Not tested in game."] =
    "Разбойники: показывает отдельным сегментом урон, накопленный Меткой смерти, до её срабатывания через 6 сек. после завершающего приёма, но не выше предела из описания. Тики Гарроты и Кровоизлияния учитываются вдвойне. Экспериментальная настройка, выключена по умолчанию: игра не сообщает, кто атаковал отмеченного противника, поэтому каждый удар считается вашим. В группе или рейде учитывается и урон остальных, из-за чего оценка завышена. В игре не проверялась.",
  ["For packs of mobs with the same name. With the mouse over a second mob of the pack, the addon can't tell which of the two your spell goes to and hides the estimate. With this on, your target (or focus, or the soft target when nothing is targeted) wins over the mob under the mouse. (If you cast with @mouseover macros, the estimate could then show on the wrong mob.)"] =
    "Для групп противников с одинаковыми именами. Если курсор наведён на другого противника из группы, аддон не может определить, по кому из них будет применено заклинание, и скрывает оценку. Если включить эту настройку, приоритет получит ваша цель (или фокус, либо условная цель, если обычная цель не выбрана), а не противник под курсором. (При применении заклинаний макросами @mouseover оценка может отображаться не на том противнике.)",
  ["Estimate during casting"] = "Оценивать во время применения",
  ["Shows a DoT with a cast time while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or failed cast removes it."] =
    "Показывает DoT с временем применения, пока вы ещё его применяете. После попадания отображается обычная оценка; при прерывании или неудаче она удаляется.",
  ["Echo trace log to chat"] = "Выводить журнал событий в чат",
  ["Prints each DoT cast, matched tick and estimate to chat."] =
    "Выводит в чат каждое применение DoT, соответствующий тик и оценку.",
  ["Learned tick sizes"] = "Изученные значения тика",
  ["What each of your DoTs really ticks for, learned from earlier casts and used instead of the tooltip's number. You can also type /dotinfo ticks."] =
    "Фактический урон за тик каждого вашего DoT, полученный из предыдущих применений и используемый вместо значения из подсказки. Также можно ввести /dotinfo ticks.",
  ["Forget learned sizes"] = "Забыть изученные значения",
  ["Forget the tick sizes learned from earlier casts."] =
    "Забыть значения тиков, полученные из предыдущих применений.",
  ["Target health bar"] = "Полоса здоровья цели",
  ["For unit frame addons that replace Blizzard's target frame (ElvUI, Shadowed Unit Frames, ...). Target something, click Pick, then click its health bar; or type the frame's name (/fstack shows it), like ElvUF_Target.Health. For a bar that drains the other way, see Fill direction on the Marker tab. Empty: Blizzard's, or EllesmereUI's or X-Perl's when it shows its own. Shared with ShieldsInfo and HealPrediction. Plater replaces nameplates, not the screen target frame; its nameplate marker is handled separately."] =
    "Для аддонов рамок, заменяющих рамку цели Blizzard (ElvUI, Shadowed Unit Frames и другие). Выберите цель, нажмите «Выбрать», затем щёлкните её полосу здоровья; либо введите имя рамки (команда /fstack его покажет), например ElvUF_Target.Health. Для полосы, которая убывает в другую сторону, см. «Направление заполнения» на вкладке метки. Пустое значение: рамка Blizzard либо собственная рамка EllesmereUI или X-Perl, если она отображается. Настройка общая для ShieldsInfo и HealPrediction. Plater заменяет таблички, а не экранную рамку цели; маркер таблички настраивается отдельно.",
  ["Kill icon spot"] = "Место значка убийства",
  ["Where the kill icon is centered (e.g. the custom frame's portrait). Empty: Blizzard's portrait, or EllesmereUI's; with a custom health bar and no spot the icon sits on that bar. Fine-tune with the offsets on the Kill icon tab."] =
    "Место, в котором будет центрирован значок убийства (например, портрет собственной рамки). Пустое значение: портрет Blizzard или EllesmereUI; если задана своя полоса здоровья, но место не указано, значок отображается на этой полосе. Точная настройка смещений — на вкладке «Значок убийства».",
  ["Focus health bar"] = "Полоса здоровья фокуса",
  ["The same for the focus frame. Empty: Blizzard's, or EllesmereUI's when it shows its own."] =
    "То же для рамки фокуса. Пустое значение: рамка Blizzard или собственная рамка EllesmereUI, если она отображается.",
  ["Nameplate health bar"] = "Полоса здоровья таблички",
  ["Most nameplate addons' bars are found automatically (Plater, EllesmereUI, Platynator, ...). If the marker does not show on yours, type the keys from Blizzard's nameplate to its bar, like unitFrame.healthBar. /dotinfo plates logs what each plate uses. Empty: automatic."] =
    "Полосы большинства аддонов табличек определяются автоматически (Plater, EllesmereUI, Platynator и другие). Если маркер не отображается на вашей табличке, укажите путь от таблички Blizzard до её полосы, например unitFrame.healthBar. Команда /dotinfo plates записывает, какую полосу использует каждая табличка. Пустое значение: автоматически.",

  -- версия Retail
  ["Retail damage estimate"] = "Оценка урона в Retail",
  ["A gold edge when the estimated time left is within the 30% Pandemic refresh window."] =
    "Золотая граница, когда расчётное оставшееся время попадает в 30%-ное окно обновления эффекта «Пандемия».",
  ["Prints each DoT cast and damage estimate to chat."] =
    "Выводит в чат каждое применение DoT и оценку урона.",
  ["The skull means estimated damage exceeds health. It is a prediction, not a confirmed kill."] =
    "Череп означает, что расчётный урон превышает запас здоровья. Это прогноз, а не подтверждённое убийство.",
  ["Rogue bleed and poison icons use WoW's aura timers. DoT damage is estimated from your casts and spell descriptions; dispels, immunities, procs and damage modifiers may change it."] =
    "Значки кровотечений и ядов разбойника используют таймеры аур WoW. Урон DoT оценивается по вашим заклинаниям и их описаниям; снятие эффектов, невосприимчивость, срабатывания и модификаторы урона могут изменить результат.",

  -- предпросмотр и панель настроек
  ["Both bars"] = "Обе полосы",
  ["DoT damage"] = "Урон DoT",
  ["Remaining damage of two sample DoTs, in % of the target's max health."] =
    "Оставшийся урон двух примеров DoT в процентах от максимального здоровья цели.",
  ["Target died"] = "Цель погибла",
  ["No DoTs on the target"] = "На цели нет DoT",
  ["DoTs kill it"] = "DoT убьют цель",
  ["%s vs %s"] = "%s против %s",
  ["Survives by %s"] = "Остаток здоровья: %s",
  ["In combat: the marker and kill icon are showing on your target. The preview resumes after combat."] =
    "В бою маркер и значок убийства отображаются на вашей цели. Предпросмотр возобновится после боя.",
  ["While this window is open, the marker and kill icon are drawn here instead of on your target."] =
    "Пока это окно открыто, маркер и значок убийства отображаются здесь, а не на вашей цели.",
  ["DoTInfo sample (not your bars)"] = "Пример DoTInfo (не ваши полосы)",
  ["450 over 3 ticks"] = "450 за 3 тика",
  ["Open the options window with a live preview. You can also type /dotinfo."] =
    "Открывает окно настроек с предпросмотром. Также можно ввести /dotinfo.",
  ["Settings have their own window with a live preview. You can also type /dotinfo."] =
    "Настройки открываются в отдельном окне с предпросмотром. Также можно ввести /dotinfo.",
  ["Click the health bar (you may need to move this window). Right-click cancels."] =
    "Щёлкните полосу здоровья (возможно, это окно придётся переместить). Правый щелчок отменяет выбор.",
  ["Click where the kill icon should go (you may need to move this window). Right-click cancels."] =
    "Щёлкните место для значка убийства (возможно, это окно придётся переместить). Правый щелчок отменяет выбор.",
  ["Picked %s."] = "Выбрано: %s.",
  ["%s preset applied to the target frame and nameplates."] =
    "Шаблон %s применён к рамке цели и табличкам.",

  -- сообщения чата
  ["DoTs: %s"] = "DoT: %s",
  ["DoTs: %d"] = "DoT: %d",
  ["Learned tick sizes cleared."] = "Изученные значения тиков сброшены.",
  ["Couldn't create the options panel; slash commands still work (/dotinfo help)."] =
    "Не удалось создать панель настроек; команды по-прежнему работают (/dotinfo help).",
  ["Target portrait not found; kill icon shown beside the target frame."] =
    "Портрет цели не найден; значок убийства отображается рядом с рамкой цели.",
  ["Target frame health bar not found; health bar markers unavailable."] =
    "Полоса здоровья рамки цели не найдена; маркеры на полосе здоровья недоступны.",
  ["Health bar markers ON."] = "Маркеры полосы здоровья включены.",
  ["Health bar markers OFF."] = "Маркеры полосы здоровья выключены.",
  ["The target frame's stays off (Marker tab)."] = "Маркер рамки цели остаётся выключенным (вкладка «Маркер»).",
  ["Kill icon test for 5 seconds: one icon ON the portrait (the real one) and one ABOVE it (plain test)."] =
    "Проверка значка убийства в течение 5 секунд: один значок НА портрете (настоящий), второй НАД ним (простой тест).",
  ["Debug ON."] = "Отладка включена.",
  ["Debug OFF."] = "Отладка выключена.",
  ["Tick sizes are not learned on this client."] = "Этот клиент не поддерживает изучение значений тиков.",
  ["The kill icon on the target's portrait means your DoTs will kill it."] =
    "Значок убийства на портрете цели означает, что ваши DoT убьют её.",
  ["/dotinfo - open the options window"] = "/dotinfo — открыть окно настроек",
  ["/dotinfo line - toggle health bar markers on/off"] =
    "/dotinfo line — включить/выключить маркеры полосы здоровья",
  ["/dotinfo skull - show the kill icon for 5 seconds to check its position"] =
    "/dotinfo skull — показать значок убийства на 5 секунд, чтобы проверить его положение",
  ["/dotinfo plates - check what the addon can reach on visible nameplates (logged)"] =
    "/dotinfo plates — проверить доступные элементы видимых табличек (результат записывается в журнал)",
  ["/dotinfo marker - report where the damage marker is (also logged); marker screen | marker bar choose what it hangs on"] =
    "/dotinfo marker — показать, где находится маркер урона (также пишется в журнал); marker screen | marker bar — на чём он закреплён",
  ["/dotinfo debug - toggle echoing the trace log (casts, ticks, estimates) to chat"] =
    "/dotinfo debug — включить/выключить вывод журнала событий (применения, тики, оценки) в чат",
  ["/dotinfo ticks - show the learned tick sizes"] = "/dotinfo ticks — показать изученные значения тиков",
  ["/dotinfo check - read every spell in your spellbook and list the DoT descriptions it cannot read"] =
    "/dotinfo check — проверить заклинания в книге и вывести описания DoT, которые не удалось прочитать",
  ["/dotinfo reset - forget learned tick sizes"] = "/dotinfo reset — забыть изученные значения тиков",

  -- окно изученных значений тиков
  ["Spell %d"] = "Заклинание %d",
  ["ID %d"] = "ID %d",
  ["Learned per tick"] = "Изучено за тик",
  ["Tooltip per tick"] = "В подсказке за тик",
  ["Ticks"] = "Тики",
  ["%d, every %gs (%gs)"] = "%d, каждые %gs (%gs)",
  ["Full duration"] = "Полная длительность",
  ["Learned from this spell's ticks on your targets; used instead of the tooltip's number, which leaves out spell power and attack power."] =
    "Изучено по тикам этого заклинания на ваших целях; используется вместо значения из подсказки, где не учитываются сила заклинаний и сила атаки.",
  ["Shift-click to link it in chat."] = "Щёлкните, удерживая Shift, чтобы вставить ссылку в чат.",
  ["Forget this tick size"] = "Забыть это значение тика",
  ["The next cast starts from the tooltip again and learns it anew."] =
    "При следующем применении снова будет использоваться подсказка, а значение изучится заново.",
  ["What each DoT really ticks for, learned from your casts and used instead of its tooltip. Tooltips leave out spell power and attack power: Bonus is how much more yours do. Hover a spell for details, shift-click to link it."] =
    "Фактический урон за тик каждого DoT, полученный из ваших применений и используемый вместо подсказки. Подсказки не учитывают силу заклинаний и силу атаки: бонус показывает дополнительный урон ваших эффектов. Наведите курсор на заклинание для подробностей, щёлкните по нему с Shift, чтобы вставить ссылку.",
  ["Per tick"] = "За тик",
  ["Tooltip"] = "Подсказка",
  ["Bonus"] = "Бонус",
  ["Total"] = "Всего",
  ["Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."] =
    "Данных пока нет. Значения тиков изучаются, когда ваши DoT наносят урон целям.",
  ["(%d-%d shown; scroll for more)"] = "(показано %d–%d; прокрутите, чтобы увидеть остальные)",
  ["1 learned tick size"] = "Изучено 1 значение тика",
  ["%d learned tick sizes"] = "Изучено значений тиков: %d",
  -- вкладка «Значок убийства»: удар оружием и порог убийства
  ["Count one weapon hit"] = "Учитывать один удар оружием",
  ["A weapon icon shows when your DoTs plus one average hit of your best weapon attack (melee swing, wand or ranged shot) would kill; the kill icon itself still means the DoTs alone are enough. The hit is the character sheet's average: armor, misses and crits are not counted, and the Kill margin applies. The marker itself still shows only the DoTs."] =
    "Значок оружия появляется, если ваши DoT плюс один средний удар вашей лучшей атаки оружием (удар в ближнем бою, выстрел из жезла или дальнего оружия) убьют цель; значок убийства по-прежнему означает, что хватит одних DoT. Берётся среднее значение с листа персонажа: броня, промахи и критические удары не учитываются, порог убийства применяется. Сама отметка по-прежнему показывает только DoT.",
  ["Kill margin"] = "Порог убийства",
  ["The icon shows only when this share of the estimated DoT damage is enough to kill. Lower it if mobs that heal or regenerate survive the icon; 100% compares the full estimate. The marker always shows the full estimate."] =
    "Значок показывается, только если такой доли оценённого урона DoT достаточно для убийства. Уменьшите значение, если цели, которые лечатся или восстанавливают здоровье, переживают значок; 100% сравнивает полную оценку. Отметка всегда показывает полную оценку.",
  -- the recorded casts view of the learned sizes window
  ["Show casts and heals"] =
    "Показать применения и исцеление",
  ["Show DoT ticks"] =
    "Показать тики DoT",
  ["Per cast"] =
    "За применение",
  ["Casts"] =
    "Применения",
  ["%d spells recorded"] =
    "Записано заклинаний: %d",
  ["Nothing recorded yet. Casts are recorded after each fight, once the damage meter can be read."] =
    "Пока ничего не записано. Применения записываются после каждого боя, когда счётчик урона можно прочитать.",
  ["What your casts of each spell really did, averaged over the last 100: damage and healing from Blizzard's damage meter, read after each fight. Bonus is how much more yours do than the tooltip says. Hover a spell for details, shift-click to link it."] =
    "Что ваши применения каждого заклинания дали на самом деле, в среднем за последние 100: урон и исцеление из счётчика урона Blizzard, прочитанные после каждого боя. Бонус показывает, на сколько больше у вас, чем в подсказке. Наведите на заклинание для подробностей, Shift-щелчок вставляет ссылку.",
  ["Healing per cast"] =
    "Исцеление за применение",
  ["Damage per cast"] =
    "Урон за применение",
  ["Tooltip, one cast"] =
    "Подсказка, одно применение",
  ["Casts recorded"] =
    "Записано применений",
  ["The average of your last 100 casts: misses, resists and crits are in it, a DoT or HoT counts what it did while you were in combat, and healing is what the damage meter counts."] =
    "Среднее по вашим последним 100 применениям: промахи, сопротивления и критические удары учтены, DoT и HoT считаются по тому, что они сделали за время боя, а исцеление — это то, что считает счётчик урона.",
  ["Forget this spell's casts"] =
    "Забыть применения этого заклинания",
  ["Its recorded casts are deleted; the next fights start them again."] =
    "Записанные применения удаляются; следующие бои начнут запись заново.",
})
