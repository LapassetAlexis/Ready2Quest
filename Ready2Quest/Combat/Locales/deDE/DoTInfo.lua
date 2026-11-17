-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the German texts of the DoTInfo tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT.RegisterLocale("deDE", {
  -- the tabs and buttons
  ["Kill icon"] = "Kill-Symbol",
  ["Behavior"] = "Verhalten",
  ["Pick"] = "Wählen",
  ["Copy from Marker tab"] = "Vom Reiter Markierung kopieren",
  ["Flash"] = "Aufblitzen",
  ["Simulate fight"] = "Kampf simulieren",
  ["Stop"] = "Stopp",
  ["View"] = "Ansehen",
  ["Info"] = "Info",
  ["Forget all"] = "Alle vergessen",

  -- the look presets, the kill icons and the lists
  ["Glass"] = "Glas",
  -- StatsInfo.lua has "Frost" too, but the Retail build does not load that file.
  ["Neon"] = "Neon",
  ["Carbon"] = "Carbon",
  ["Ember"] = "Glut",
  ["Debug"] = "Debug",
  ["Green checkmark"] = "Grünes Häkchen",
  ["Boss skull"] = "Boss-Totenkopf",
  ["Sunglasses"] = "Sonnenbrille",
  ["Fine dots (1px)"] = "Feine Punkte (1px)",
  ["Dots (2px)"] = "Punkte (2px)",
  ["Short dashes (4px)"] = "Kurze Striche (4px)",
  ["Dashes (8px)"] = "Striche (8px)",
  ["Long dashes (16px)"] = "Lange Striche (16px)",
  ["One color (fill color)"] = "Eine Farbe (Füllfarbe)",
  ["By effect type"] = "Nach Effektart",
  ["Never (estimate straight away)"] = "Nie (sofort schätzen)",
  ["When unsure"] = "Bei Unsicherheit",
  ["Always (real ticks only)"] = "Immer (nur echte Ticks)",
  ["Marker only"] = "Nur Markierung",
  ["Marker and kill icon"] = "Markierung und Kill-Symbol",
  ["Right of the health bar"] = "Rechts der Gesundheitsleiste",
  ["Left of the health bar"] = "Links der Gesundheitsleiste",
  ["Above the health bar"] = "Über der Gesundheitsleiste",
  ["Below the health bar"] = "Unter der Gesundheitsleiste",
  ["Fill direction"] = "Füllrichtung",
  ["Follow health bar"] = "Gesundheitsleiste folgen",
  ["Left to right"] = "Links nach rechts",
  ["Right to left"] = "Rechts nach links",
  ["Which end of the target health bar the marker starts from. Follow health bar turns it around on a mirrored bar that drains the other way; choose Right to left if your unit frame addon is not recognized."] =
    "An welchem Ende der Ziel-Gesundheitsleiste die Markierung beginnt. „Gesundheitsleiste folgen“ dreht sie auf einer gespiegelten Leiste um, die sich in die andere Richtung leert; wählt „Rechts nach links“, wenn Euer Einheitenfenster-Addon nicht erkannt wird.",
  ["Shows an icon at the chosen position when your DoTs on the target will kill it."] =
    "Zeigt ein Symbol an der gewählten Position, wenn Eure DoTs das Ziel töten werden.",

  -- the Kill icon tab
  ["Show icon on portrait"] = "Symbol auf Porträt zeigen",
  ["Shows an icon over the target's portrait when your DoTs on it will kill it."] =
    "Zeigt ein Symbol über dem Porträt des Ziels, wenn Eure DoTs es töten werden.",
  ["Pulse"] = "Pulsieren",
  ["Gently pulses the icon while it's showing."] =
    "Lässt das Symbol sanft pulsieren, solange es angezeigt wird.",
  ["Pixels right (+) or left (-) of the portrait's center."] =
    "Pixel rechts (+) oder links (-) von der Mitte des Porträts.",
  ["Pixels up (+) or down (-) from the portrait's center."] =
    "Pixel nach oben (+) oder unten (-) ab der Mitte des Porträts.",

  -- the Marker tab
  ["Show damage marker"] = "Schadensmarkierung zeigen",
  ["Marks the damage your DoTs still have to deal on the target's health bar. If the health ends inside it, the target dies."] =
    "Markiert auf der Gesundheitsleiste des Ziels den Schaden, den Eure DoTs noch verursachen. Endet die Gesundheit innerhalb der Markierung, stirbt das Ziel.",
  ["Keep this on to show the marker on your screen's target health bar. Plater changes nameplates, not that frame; if you use a separate unit frame addon, set its bar under Behavior > Target health bar. Turn off to keep the marker on nameplates and the focus frame only. On Retail this also hides the rogue's aura icons above the target bar. The kill icon has its own switch in the Kill icon tab."] =
    "Lasst dies eingeschaltet, damit die Markierung auf der Gesundheitsleiste Eures Zielfensters erscheint. Plater ändert Namensplaketten, nicht dieses Fenster; nutzt Ihr ein separates Einheitenfenster-Addon, legt dessen Leiste unter Verhalten > Gesundheitsleiste des Ziels fest. Schaltet dies aus, damit die Markierung nur auf Namensplaketten und im Fokusfenster bleibt. In Retail blendet dies auch die Aura-Symbole des Schurken über der Zielleiste aus. Das Kill-Symbol hat im Reiter Kill-Symbol einen eigenen Schalter.",
  ["DoT colors"] = "DoT-Farben",
  ["One color, or one segment per DoT with green poisons, purple curses/shadow damage and red bleeds. Rainbow gives each spell a separate color."] =
    "Eine Farbe oder ein Segment pro DoT, mit grünen Giften, violetten Flüchen/Schattenschaden und roten Blutungen. Regenbogen gibt jedem Zauber eine eigene Farbe.",
  ["Used when DoT colors is set to one color."] =
    "Gilt, wenn für die DoT-Farben nur eine Farbe gewählt ist.",
  ["Dividers between DoTs"] = "Trennlinien zwischen DoTs",
  ["Dash length"] = "Strichlänge",
  ["Outline thickness"] = "Umrissstärke",

  -- the Effects tab
  ["Smooth motion"] = "Sanfte Bewegung",
  ["The marker grows in when it appears and glides to new values instead of jumping."] =
    "Die Markierung wächst beim Erscheinen heran und gleitet zu neuen Werten, statt zu springen.",
  ["Flash on new DoT"] = "Aufblitzen bei neuem DoT",
  ["Spark"] = "Funke",
  ["A bright flare on the marker's edge when a DoT lands."] =
    "Ein heller Lichtblitz am Rand der Markierung, wenn ein DoT sein Ziel trifft.",
  ["Pulse outline"] = "Umriss pulsieren",
  ["Glow"] = "Glühen",
  ["Soft halo in the outline color."] = "Weicher Schein in der Umrissfarbe.",
  ["Glow size"] = "Größe des Glühens",
  ["Shine sweep"] = "Glanz-Durchlauf",
  ["Shine every"] = "Glanz alle",
  ["Scroll stripes"] = "Streifen scrollen",
  ["Animates the diagonal stripes fill."] = "Animiert die Füllung mit diagonalen Streifen.",

  -- the Text tab
  ["Show damage text"] = "Schadenstext zeigen",
  ["Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)."] =
    "Verbleibender DoT-Schaden neben der Gesundheitsleiste (mit den DoT-Farben nach DoT aufgeschlüsselt).",

  -- the Nameplates tab
  ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below."] =
    "Zeichnet eine Markierung (und wahlweise das Kill-Symbol) auf jede gegnerische Namensplakette mit Euren DoTs, in einer eigenen Optik weiter unten.",
  ["Draws the same marker (and optionally the kill icon) on your focus frame's health bar for your DoTs on the focused enemy, in the nameplate look below."] =
    "Zeichnet dieselbe Markierung (und wahlweise das Kill-Symbol) auf die Gesundheitsleiste Eures Fokusfensters für Eure DoTs auf dem Fokusziel, in der Namensplaketten-Optik weiter unten.",
  ["Kill icon size"] = "Größe des Kill-Symbols",
  ["Kill icon position"] = "Position des Kill-Symbols",
  ["Pixels right (+) or left (-) of the chosen position."] =
    "Pixel rechts (+) oder links (-) von der gewählten Position.",
  ["Pixels up (+) or down (-) from the chosen position."] =
    "Pixel nach oben (+) oder unten (-) ab der gewählten Position.",
  ["By effect type: green poisons, purple curses/shadow damage and red bleeds. Rainbow: a separate color per spell."] =
    "Nach Effektart: grüne Gifte, violette Flüche/Schattenschaden und rote Blutungen. Regenbogen: eine eigene Farbe pro Zauber.",

  -- the Behavior tab
  ["Wait for first tick"] = "Auf ersten Tick warten",
  ["Whether a new DoT counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points and spells the addon hasn't seen tick yet."] =
    "Ob ein neuer DoT schon vor seinem ersten Tick mitzählt. \"Bei Unsicherheit\" wartet bei Abschlussbewegungen mit unbekannter Anzahl an Combopunkten und bei Zaubern, deren Ticks das Addon noch nicht gesehen hat.",
  ["Show refresh marks"] = "Auffrischmarken zeigen",
  ["A gold edge on that DoT's segment while the time left is inside the refresh window: one tick, three seconds, or a quarter of the duration, whichever is longer. The damage number stays off unless you turn it on."] =
    "Ein goldener Rand am Segment dieses DoTs, solange die Restzeit im Auffrischfenster liegt: ein Tick, drei Sekunden oder ein Viertel der Dauer, je nachdem, was länger ist. Die Schadenszahl bleibt ausgeblendet, solange Ihr sie nicht einschaltet.",
  ["Ignite, Deep Wounds, traps"] = "Entzünden, Tiefe Wunden, Fallen",
  ["Mages and warriors: a critical hit lights Ignite (a share of the fire crit over 4 s) or Deep Wounds (a share of your weapon damage over 12 s), with no cast to say so. Assumes you have the talent (when the talent tree can be read and shows no points, nothing is drawn). A crit counts as yours when you cast at that mob just before, or, for Deep Wounds, swing at it while alone; the first tick confirms it. Traps (Immolation Trap) are tracked as well."] =
    "Magier und Krieger: Ein kritischer Treffer löst Entzünden (ein Teil des kritischen Feuerschadens über 4 Sek.) oder Tiefe Wunden (ein Teil Eures Waffenschadens über 12 Sek.) aus, ohne dass ein Zauber dies meldet. Setzt voraus, dass Ihr das Talent habt (ist der Talentbaum lesbar und zeigt keine Punkte, wird nichts gezeichnet). Ein kritischer Treffer gilt als Eurer, wenn Ihr kurz zuvor auf diesen Gegner gezaubert habt; für Tiefe Wunden genügt es auch, ihn allein (ohne Gruppe) im Nahkampf anzugreifen. Der erste Tick bestätigt es. Fallen (Feuerbrandfalle) werden ebenfalls verfolgt.",
  ["Death Mark (experimental)"] = "Todesmal (experimentell)",
  ["Rogues: shows what Death Mark has stored so far as one more segment, until it goes off 6 s after the finisher, never above the cap in its description. Garrote and Rupture ticks count twice. Experimental, off by default: the game doesn't say who hit the marked mob, so every hit on it counts as yours. In a party or raid the others' damage is counted too and the estimate runs high. Not tested in game."] =
    "Schurken: Zeigt als zusätzliches Segment, was Todesmal bisher gespeichert hat, bis es 6 Sek. nach der Abschlussbewegung ausgelöst wird, nie über der Obergrenze aus seiner Beschreibung. Ticks von Erdrosseln und Blutung zählen doppelt. Experimentell, standardmäßig aus: Das Spiel verrät nicht, wer den markierten Gegner getroffen hat, daher zählt jeder Treffer darauf als Eurer. In einer Gruppe oder einem Schlachtzug wird auch der Schaden der anderen mitgezählt, und die Schätzung fällt zu hoch aus. Im Spiel nicht getestet.",
  ["For packs of mobs with the same name. With the mouse over a second mob of the pack, the addon can't tell which of the two your spell goes to and hides the estimate. With this on, your target (or focus, or the soft target when nothing is targeted) wins over the mob under the mouse. (If you cast with @mouseover macros, the estimate could then show on the wrong mob.)"] =
    "Für Gruppen von Gegnern mit gleichem Namen. Befindet sich die Maus über einem zweiten Gegner der Gruppe, kann das Addon nicht erkennen, auf welchen der beiden Euer Zauber geht, und blendet die Schätzung aus. Ist dies aktiviert, hat Euer Ziel (oder Euer Fokus oder, wenn nichts anvisiert ist, das weiche Ziel) Vorrang vor dem Gegner unter der Maus. (Wirkt Ihr mit @mouseover-Makros, kann die Schätzung dann auf dem falschen Gegner erscheinen.)",
  ["Estimate during casting"] = "Schätzung beim Zaubern",
  ["Shows a DoT with a cast time while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or failed cast removes it."] =
    "Zeigt einen DoT mit Zauberzeit schon an, während Ihr ihn noch wirkt. Sobald der Zauber trifft, übernimmt die normale Schätzung; ein unterbrochener oder fehlgeschlagener Zauber entfernt sie.",
  ["Echo trace log to chat"] = "Ablaufprotokoll im Chat ausgeben",
  ["Prints each DoT cast, matched tick and estimate to chat."] =
    "Gibt jeden DoT-Zauber, zugeordneten Tick und jede Schätzung im Chat aus.",
  ["Learned tick sizes"] = "Gelernte Tickgrößen",
  ["What each of your DoTs really ticks for, learned from earlier casts and used instead of the tooltip's number. You can also type /dotinfo ticks."] =
    "Was jeder Eurer DoTs tatsächlich pro Tick verursacht, gelernt aus früheren Zaubern und anstelle der Zahl im Tooltip verwendet. Ihr könnt auch /dotinfo ticks eingeben.",
  ["Forget learned sizes"] = "Gelernte Größen vergessen",
  ["Forget the tick sizes learned from earlier casts."] =
    "Vergisst die aus früheren Zaubern gelernten Tickgrößen.",
  ["Target health bar"] = "Gesundheitsleiste des Ziels",
  ["For unit frame addons that replace Blizzard's target frame (ElvUI, Shadowed Unit Frames, ...). Target something, click Pick, then click its health bar; or type the frame's name (/fstack shows it), like ElvUF_Target.Health. For a bar that drains the other way, see Fill direction on the Marker tab. Empty: Blizzard's, or EllesmereUI's or X-Perl's when it shows its own. Shared with ShieldsInfo and HealPrediction. Plater replaces nameplates, not the screen target frame; its nameplate marker is handled separately."] =
    "Für Einheitenfenster-Addons, die Blizzards Zielfenster ersetzen (ElvUI, Shadowed Unit Frames, ...). Visiert etwas an, klickt auf Wählen und dann auf die Gesundheitsleiste des Fensters; oder tippt den Namen des Fensters ein (/fstack zeigt ihn an), etwa ElvUF_Target.Health. Für eine Leiste, die sich in die andere Richtung leert, siehe „Füllrichtung“ im Reiter Markierung. Leer: die Leiste von Blizzard oder die von EllesmereUI oder X-Perl, wenn dieses eine eigene zeigt. Wird mit ShieldsInfo und HealPrediction geteilt. Plater ersetzt Namensplaketten, nicht das Zielfenster auf dem Bildschirm; seine Markierung auf den Namensplaketten wird gesondert behandelt.",
  ["Kill icon spot"] = "Stelle für Kill-Symbol",
  ["Where the kill icon is centered (e.g. the custom frame's portrait). Empty: Blizzard's portrait, or EllesmereUI's; with a custom health bar and no spot the icon sits on that bar. Fine-tune with the offsets on the Kill icon tab."] =
    "Wo das Kill-Symbol zentriert wird (z. B. das Porträt des eigenen Fensters). Leer: das Porträt von Blizzard oder das von EllesmereUI; mit eigener Gesundheitsleiste und ohne Stelle sitzt das Symbol auf dieser Leiste. Feinabstimmung mit den Versätzen im Reiter Kill-Symbol.",
  ["Focus health bar"] = "Gesundheitsleiste des Fokus",
  ["The same for the focus frame. Empty: Blizzard's, or EllesmereUI's when it shows its own."] =
    "Dasselbe für das Fokusfenster. Leer: das von Blizzard oder das von EllesmereUI, wenn dieses ein eigenes zeigt.",
  ["Nameplate health bar"] = "Gesundheitsleiste der Namensplakette",
  ["Most nameplate addons' bars are found automatically (Plater, EllesmereUI, Platynator, ...). If the marker does not show on yours, type the keys from Blizzard's nameplate to its bar, like unitFrame.healthBar. /dotinfo plates logs what each plate uses. Empty: automatic."] =
    "Die Leisten der meisten Namensplaketten-Addons werden automatisch gefunden (Plater, EllesmereUI, Platynator, ...). Zeigt sich die Markierung bei Eurem nicht, tippt die Schlüssel von Blizzards Namensplakette bis zu ihrer Leiste ein, etwa unitFrame.healthBar. /dotinfo plates protokolliert, was jede Plakette nutzt. Leer: automatisch.",

  -- the Retail build
  ["Retail damage estimate"] = "Retail-Schadensschätzung",
  ["A gold edge when the estimated time left is within the 30% Pandemic refresh window."] =
    "Ein goldener Rand, wenn die geschätzte Restzeit im Pandemie-Fenster von 30% zum Auffrischen liegt.",
  ["Prints each DoT cast and damage estimate to chat."] =
    "Gibt jeden DoT-Zauber und jede Schadensschätzung im Chat aus.",
  ["The skull means estimated damage exceeds health. It is a prediction, not a confirmed kill."] =
    "Der Totenkopf bedeutet, dass der geschätzte Schaden die Gesundheit übersteigt. Das ist eine Prognose, kein bestätigter Kill.",
  ["Rogue bleed and poison icons use WoW's aura timers. DoT damage is estimated from your casts and spell descriptions; dispels, immunities, procs and damage modifiers may change it."] =
    "Die Symbole für Schurken-Blutungen und -Gifte nutzen die Aura-Timer von WoW. Der DoT-Schaden wird aus Euren Zaubern und Zauberbeschreibungen geschätzt; Bannungen, Immunitäten, Procs und Schadensmodifikatoren können ihn verändern.",

  -- the preview and the settings panel
  ["Both bars"] = "Beide Leisten",
  ["DoT damage"] = "DoT-Schaden",
  ["Remaining damage of two sample DoTs, in % of the target's max health."] =
    "Restschaden zweier Beispiel-DoTs in % der maximalen Gesundheit des Ziels.",
  ["Target died"] = "Ziel gestorben",
  ["No DoTs on the target"] = "Keine DoTs am Ziel",
  ["DoTs kill it"] = "DoTs töten das Ziel",
  ["%s vs %s"] = "%s gegen %s",
  ["Survives by %s"] = "Überlebt um %s",
  ["In combat: the marker and kill icon are showing on your target. The preview resumes after combat."] =
    "Im Kampf: Die Markierung und das Kill-Symbol liegen auf Eurem Ziel. Die Vorschau läuft nach dem Kampf weiter.",
  ["While this window is open, the marker and kill icon are drawn here instead of on your target."] =
    "Solange dieses Fenster geöffnet ist, werden die Markierung und das Kill-Symbol hier statt auf Eurem Ziel gezeichnet.",
  ["DoTInfo sample (not your bars)"] = "DoTInfo-Beispiel (nicht Eure Leisten)",
  ["450 over 3 ticks"] = "450 über 3 Ticks",
  ["Open the options window with a live preview. You can also type /dotinfo."] =
    "Öffnet das Einstellungsfenster mit einer Live-Vorschau. Ihr könnt auch /dotinfo eingeben.",
  ["Settings have their own window with a live preview. You can also type /dotinfo."] =
    "Die Einstellungen haben ein eigenes Fenster mit einer Live-Vorschau. Ihr könnt auch /dotinfo eingeben.",
  ["Click the health bar (you may need to move this window). Right-click cancels."] =
    "Klickt auf die Gesundheitsleiste (eventuell müsst Ihr dieses Fenster verschieben). Ein Rechtsklick bricht ab.",
  ["Click where the kill icon should go (you may need to move this window). Right-click cancels."] =
    "Klickt auf die Stelle für das Kill-Symbol (eventuell müsst Ihr dieses Fenster verschieben). Ein Rechtsklick bricht ab.",
  ["Picked %s."] = "%s gewählt.",
  ["%s preset applied to the target frame and nameplates."] =
    "Stilvorlage %s auf das Zielfenster und die Namensplaketten angewendet.",

  -- the chat messages
  ["DoTs: %s"] = "DoTs: %s",
  ["DoTs: %d"] = "DoTs: %d",
  ["Learned tick sizes cleared."] = "Gelernte Tickgrößen zurückgesetzt.",
  ["Couldn't create the options panel; slash commands still work (/dotinfo help)."] =
    "Das Einstellungsfenster konnte nicht erstellt werden; die Slash-Befehle funktionieren weiterhin (/dotinfo help).",
  ["Target portrait not found; kill icon shown beside the target frame."] =
    "Porträt des Ziels nicht gefunden; das Kill-Symbol wird neben dem Zielfenster gezeigt.",
  ["Target frame health bar not found; health bar markers unavailable."] =
    "Gesundheitsleiste des Zielfensters nicht gefunden; Markierungen der Gesundheitsleiste nicht verfügbar.",
  ["Health bar markers ON."] = "Markierungen der Gesundheitsleiste: AN.",
  ["Health bar markers OFF."] = "Markierungen der Gesundheitsleiste: AUS.",
  ["The target frame's stays off (Marker tab)."] = "Die Markierung im Zielfenster bleibt aus (Reiter Markierung).",
  ["Kill icon test for 5 seconds: one icon ON the portrait (the real one) and one ABOVE it (plain test)."] =
    "Kill-Symbol-Test für 5 Sekunden: ein Symbol AUF dem Porträt (das echte) und eines DARÜBER (reiner Test).",
  ["Debug ON."] = "Debug: AN.",
  ["Debug OFF."] = "Debug: AUS.",
  ["Tick sizes are not learned on this client."] = "Auf diesem Client werden keine Tickgrößen gelernt.",
  ["The kill icon on the target's portrait means your DoTs will kill it."] =
    "Das Kill-Symbol auf dem Porträt des Ziels bedeutet, dass Eure DoTs es töten werden.",
  ["/dotinfo - open the options window"] = "/dotinfo - öffnet das Einstellungsfenster",
  ["/dotinfo line - toggle health bar markers on/off"] =
    "/dotinfo line - schaltet die Markierungen der Gesundheitsleiste ein/aus",
  ["/dotinfo skull - show the kill icon for 5 seconds to check its position"] =
    "/dotinfo skull - zeigt das Kill-Symbol 5 Sekunden lang, um seine Position zu prüfen",
  ["/dotinfo plates - check what the addon can reach on visible nameplates (logged)"] =
    "/dotinfo plates - prüft, was das Addon auf sichtbaren Namensplaketten erreichen kann (wird protokolliert)",
  ["/dotinfo marker - report where the damage marker is (also logged); marker screen | marker bar choose what it hangs on"] =
    "/dotinfo marker - meldet, wo die Schadensmarkierung liegt (wird auch protokolliert); marker screen | marker bar wählt, woran sie hängt",
  ["/dotinfo debug - toggle echoing the trace log (casts, ticks, estimates) to chat"] =
    "/dotinfo debug - schaltet die Ausgabe des Ablaufprotokolls (Zauber, Ticks, Schätzungen) im Chat ein/aus",
  ["/dotinfo ticks - show the learned tick sizes"] = "/dotinfo ticks - zeigt die gelernten Tickgrößen",
  ["/dotinfo check - read every spell in your spellbook and list the DoT descriptions it cannot read"] =
    "/dotinfo check - liest jeden Zauber in Eurem Zauberbuch und listet die DoT-Beschreibungen auf, die es nicht lesen kann",
  ["/dotinfo reset - forget learned tick sizes"] = "/dotinfo reset - vergisst gelernte Tickgrößen",

  -- the learned tick sizes window
  ["Spell %d"] = "Zauber %d",
  ["ID %d"] = "ID %d",
  ["Learned per tick"] = "Gelernt pro Tick",
  ["Tooltip per tick"] = "Tooltip pro Tick",
  ["Ticks"] = "Ticks",
  ["%d, every %gs (%gs)"] = "%d, alle %gs (%gs)",
  ["Full duration"] = "Gesamtdauer",
  ["Learned from this spell's ticks on your targets; used instead of the tooltip's number, which leaves out spell power and attack power."] =
    "Aus den Ticks dieses Zaubers auf Euren Zielen gelernt; wird anstelle der Zahl im Tooltip verwendet, die Zaubermacht und Angriffskraft auslässt.",
  ["Shift-click to link it in chat."] = "Umschalt-Klick fügt es in den Chat ein.",
  ["Forget this tick size"] = "Diese Tickgröße vergessen",
  ["The next cast starts from the tooltip again and learns it anew."] =
    "Der nächste Zauber beginnt wieder beim Tooltip und lernt sie neu.",
  ["What each DoT really ticks for, learned from your casts and used instead of its tooltip. Tooltips leave out spell power and attack power: Bonus is how much more yours do. Hover a spell for details, shift-click to link it."] =
    "Was jeder DoT tatsächlich pro Tick verursacht, gelernt aus Euren Zaubern und anstelle seines Tooltips verwendet. Tooltips lassen Zaubermacht und Angriffskraft aus: Der Bonus zeigt, wie viel mehr Eure DoTs verursachen. Bewegt die Maus über einen Zauber für Details; Umschalt-Klick fügt ihn in den Chat ein.",
  ["Per tick"] = "Pro Tick",
  ["Tooltip"] = "Tooltip",
  ["Bonus"] = "Bonus",
  ["Total"] = "Gesamt",
  ["Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."] =
    "Noch nichts gelernt. Tickgrößen werden gelernt, während Eure DoTs auf Euren Zielen ticken.",
  ["(%d-%d shown; scroll for more)"] = "(%d-%d angezeigt; scrollt für mehr)",
  ["1 learned tick size"] = "1 gelernte Tickgröße",
  ["%d learned tick sizes"] = "%d gelernte Tickgrößen",
  -- the Kill icon tab: weapon hit and kill margin
  ["Count one weapon hit"] = "Einen Waffentreffer mitzählen",
  ["A weapon icon shows when your DoTs plus one average hit of your best weapon attack (melee swing, wand or ranged shot) would kill; the kill icon itself still means the DoTs alone are enough. The hit is the character sheet's average: armor, misses and crits are not counted, and the Kill margin applies. The marker itself still shows only the DoTs."] =
    "Ein Waffensymbol erscheint, wenn Eure DoTs plus ein durchschnittlicher Treffer Eures besten Waffenangriffs (Nahkampfschlag, Zauberstab- oder Fernkampfschuss) das Ziel töten würden; das Kill-Symbol bedeutet weiterhin, dass die DoTs allein genügen. Der Treffer ist der Durchschnitt aus dem Charakterblatt: Rüstung, Fehlschläge und kritische Treffer werden nicht gezählt, und die Kill-Marge gilt. Die Markierung selbst zeigt weiterhin nur die DoTs.",
  ["Kill margin"] = "Kill-Marge",
  ["The icon shows only when this share of the estimated DoT damage is enough to kill. Lower it if mobs that heal or regenerate survive the icon; 100% compares the full estimate. The marker always shows the full estimate."] =
    "Das Symbol erscheint nur, wenn dieser Anteil des geschätzten DoT-Schadens zum Töten reicht. Senkt den Wert, wenn Gegner, die sich heilen oder regenerieren, das Symbol überleben; bei 100% zählt die volle Schätzung. Die Markierung zeigt immer die volle Schätzung.",
  -- the recorded casts view of the learned sizes window
  ["Show casts and heals"] =
    "Zauber und Heilung zeigen",
  ["Show DoT ticks"] =
    "DoT-Ticks zeigen",
  ["Per cast"] =
    "Pro Zauber",
  ["Casts"] =
    "Zauber",
  ["%d spells recorded"] =
    "%d Zauber aufgezeichnet",
  ["Nothing recorded yet. Casts are recorded after each fight, once the damage meter can be read."] =
    "Noch nichts aufgezeichnet. Zauber werden nach jedem Kampf aufgezeichnet, sobald der Schadensmesser lesbar ist.",
  ["What your casts of each spell really did, averaged over the last 100: damage and healing from Blizzard's damage meter, read after each fight. Bonus is how much more yours do than the tooltip says. Hover a spell for details, shift-click to link it."] =
    "Was Eure Zauber jeder Art wirklich bewirkt haben, gemittelt über die letzten 100: Schaden und Heilung aus Blizzards Schadensmesser, nach jedem Kampf gelesen. Bonus ist, wie viel mehr Eure bewirken als der Tooltip angibt. Zauber anfahren für Details, Umschalt-Klick verlinkt ihn.",
  ["Healing per cast"] =
    "Heilung pro Zauber",
  ["Damage per cast"] =
    "Schaden pro Zauber",
  ["Tooltip, one cast"] =
    "Tooltip, ein Zauber",
  ["Casts recorded"] =
    "Aufgezeichnete Zauber",
  ["The average of your last 100 casts: misses, resists and crits are in it, a DoT or HoT counts what it did while you were in combat, and healing is what the damage meter counts."] =
    "Der Durchschnitt Eurer letzten 100 Zauber: Fehlschläge, Widerstände und kritische Treffer sind enthalten, ein DoT oder HoT zählt, was er im Kampf bewirkt hat, und Heilung ist das, was der Schadensmesser zählt.",
  ["Forget this spell's casts"] =
    "Die Zauber dieses Zaubers vergessen",
  ["Its recorded casts are deleted; the next fights start them again."] =
    "Seine aufgezeichneten Zauber werden gelöscht; die nächsten Kämpfe beginnen sie neu.",
})
