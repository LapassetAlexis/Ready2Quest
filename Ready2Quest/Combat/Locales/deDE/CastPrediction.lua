-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the German texts of the CastPrediction tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT.RegisterLocale("deDE", {
  -- the sub-tabs and the preview
  ["Prediction"] = "Prognose",
  ["In combat: the marker is on your target. The preview resumes after combat."] =
    "Im Kampf: Die Markierung liegt auf Eurem Ziel. Die Vorschau läuft nach dem Kampf weiter.",
  ["Sample spell"] = "Beispielzauber",
  ["Same marker on mock frames; sample damage is illustrative. Raise target health to hide the kill icon. While in combat, the marker returns to your target."] =
    "Dieselbe Markierung auf Beispielfenstern; der Beispielschaden dient nur der Veranschaulichung. Erhöht die Zielgesundheit, um das Kill-Symbol auszublenden. Im Kampf kehrt die Markierung zu Eurem Ziel zurück.",
  ["The marker shows what the description and your spell power give; hits seen in combat tune it. Crits, procs and resists stay unpredictable."] =
    "Die Markierung zeigt, was die Beschreibung und Eure Zaubermacht ergeben; im Kampf gesehene Treffer stimmen sie fein ab. Kritische Treffer, Procs und Widerstände bleiben unvorhersehbar.",
  ["CastPrediction sample"] = "Zauberprognose-Beispiel",
  ["Frostbolt 410-450 (estimate)"] = "Frostbolt 410-450 (Schätzung)",

  -- the Marker tab
  ["Show on party frames"] = "In Gruppenfenstern zeigen",
  ["Show on raid frames"] = "In Schlachtzugsfenstern zeigen",
  ["Show the prediction on the Blizzard or configured target frame."] =
    "Zeigt die Prognose im Zielfenster von Blizzard oder im konfigurierten Zielfenster.",
  ["Also show the prediction on the focus frame when it represents the cast's target."] =
    "Zeigt die Prognose auch im Fokusfenster, wenn es das Ziel des Zaubers darstellt.",
  ["Show the prediction only if a party frame represents the cast's recipient. Ordinary damage casts target enemies, not party members."] =
    "Zeigt die Prognose nur, wenn ein Gruppenfenster den Empfänger des Zaubers darstellt. Gewöhnliche Schadenszauber zielen auf Feinde, nicht auf Gruppenmitglieder.",
  ["Show the prediction only if a raid frame represents the cast's recipient. Ordinary damage casts target enemies, not raid members."] =
    "Zeigt die Prognose nur, wenn ein Schlachtzugsfenster den Empfänger des Zaubers darstellt. Gewöhnliche Schadenszauber zielen auf Feinde, nicht auf Schlachtzugsmitglieder.",
  ["Show the prediction on the cast target's nameplate."] =
    "Zeigt die Prognose auf der Namensplakette des Zauberziels.",
  ["For packs of mobs with the same name. With the mouse over a second mob of the pack, the addon can't tell which of the two your spell goes to and hides the prediction. With this on, your target (or focus, or the soft target when nothing is targeted) wins over the mob under the mouse. (If you cast with @mouseover macros, the prediction could then show on the wrong mob.)"] =
    "Für Gruppen von Gegnern mit gleichem Namen. Befindet sich die Maus über einem zweiten Gegner der Gruppe, kann das Addon nicht erkennen, auf welchen der beiden Euer Zauber geht, und blendet die Prognose aus. Ist dies aktiviert, hat Euer Ziel (oder Euer Fokus oder, wenn nichts anvisiert ist, das weiche Ziel) Vorrang vor dem Gegner unter der Maus. (Wirkt Ihr mit @mouseover-Makros, kann die Prognose dann auf dem falschen Gegner erscheinen.)",
  ["THE MARKER"] = "DIE MARKIERUNG",
  ["Show the marker"] = "Markierung zeigen",
  ["The predicted damage, drawn across enabled health bars while a cast is in flight."] =
    "Der vorhergesagte Schaden, eingezeichnet über aktivierten Gesundheitsleisten, solange ein Zauber im Gange ist.",
  ["CASTS AND CHANNELS"] = "ZAUBER UND KANALISIERUNGEN",
  ["Spell school"] = "Zauberschule",
  ["Only your own cast is ever drawn on the bar."] = "Auf der Leiste wird immer nur Euer eigener Zauber eingezeichnet.",
  ["How strongly the fill covers the health bar."] = "Wie stark die Füllung die Gesundheitsleiste bedeckt.",
  ["Cast fill style"] = "Füllstil für Zauber",
  ["The fill of a cast in flight. Patterns, glass and bevel shadings, Blizzard's bar textures and every texture LibSharedMedia knows (ElvUI, Details, ...) are in the list; the fill color tints them."] =
    "Die Füllung eines laufenden Zaubers. In der Liste stehen Muster, Glas- und Abschrägungsschattierungen, die Balkentexturen von Blizzard und jede Textur, die LibSharedMedia kennt (ElvUI, Details, ...); die Füllfarbe färbt sie ein.",
  ["Channel fill style"] = "Füllstil für Kanalisierungen",
  ["The fill of a channel (the damage that remains): a pattern shows it is a channel, not a single hit."] =
    "Die Füllung einer Kanalisierung (der verbleibende Schaden): Ein Muster zeigt, dass es eine Kanalisierung ist und kein einzelner Treffer.",
  ["A hairline around the marker; it can pulse while the cast is in flight."] =
    "Eine haarfeine Linie um die Markierung; sie kann pulsieren, solange der Zauber im Gange ist.",
  ["Pulse the outline"] = "Umriss pulsieren lassen",
  ["A soft breathing of the outline while the cast is in flight."] =
    "Ein sanftes Atmen des Umrisses, solange der Zauber im Gange ist.",
  ["Kill icon on the portrait"] = "Kill-Symbol auf dem Porträt",
  ["An icon when even the lowest end of the cast's range would finish the target. Drawn by a status bar, so it works with hidden health too."] =
    "Ein Symbol, wenn schon das untere Ende der Spanne des Zaubers das Ziel erledigen würde. Es wird von einer Statusleiste gezeichnet und funktioniert deshalb auch bei verborgener Gesundheit.",
  ["Show killing spell icon"] = "Symbol des tötenden Zaubers zeigen",
  ["Enabled by default. When a cast or finisher would kill, show its spell icon instead of the generic kill icon. The finisher preview uses the icon for the finisher that would kill."] =
    "Standardmäßig aktiviert. Wenn ein Zauber oder eine Abschlussbewegung töten würde, wird deren Zaubersymbol statt des allgemeinen Kill-Symbols gezeigt. Die Vorschau der Abschlussbewegung nutzt das Symbol der Abschlussbewegung, die töten würde.",
  ["Fallback kill icon"] = "Ersatz-Kill-Symbol",
  ["Impact"] = "Einschlag",
  ["Shown when the spell icon option is off or that spell's icon is unavailable."] =
    "Wird gezeigt, wenn die Option für das Zaubersymbol aus ist oder das Symbol dieses Zaubers nicht verfügbar ist.",
  ["FINISHER PREVIEW"] = "VORSCHAU DER ABSCHLUSSBEWEGUNG",
  ["Preview fill style"] = "Füllstil der Vorschau",
  ["The fill of the finisher preview (Prediction tab), so it never reads as a real cast."] =
    "Die Füllung der Vorschau der Abschlussbewegung (Reiter Prognose), damit sie nie wie ein echter Zauber wirkt.",
  ["Preview fill color"] = "Füllfarbe der Vorschau",
  ["Spell school, one of the colors, or a custom color from the picker. A fill style from the Colorful group (the default, Flame) has colors of its own and ignores this color; only its opacity applies."] =
    "Zauberschule, eine der Farben oder eine eigene Farbe aus der Farbauswahl. Ein Füllstil aus der Gruppe Bunt (der Standard, Flamme) hat eigene Farben und ignoriert diese Farbe; nur seine Deckkraft gilt.",
  ["Preview fill opacity"] = "Deckkraft der Vorschau-Füllung",
  ["The marker covers health backwards from the current HP edge. At 60/100 HP, 20 damage covers 60 down to 40. Overkill is clipped inside the bar."] =
    "Die Markierung deckt die Gesundheit rückwärts ab der aktuellen LP-Kante ab. Bei 60/100 LP deckt 20 Schaden die Spanne von 60 bis 40 ab. Überschüssiger Schaden (Overkill) wird innerhalb der Leiste abgeschnitten.",

  -- the Text tab
  ["THE TEXT"] = "DER TEXT",
  ["Show text"] = "Text zeigen",
  ["The spell name and the number, at the spot picked below."] =
    "Der Zaubername und die Zahl an der unten gewählten Stelle.",
  ["Text shows"] = "Text zeigt",
  ["Damage"] = "Schaden",
  ["Damage range"] = "Schadensspanne",
  ["Percent of the target's health"] = "Prozent der Gesundheit des Ziels",
  ["Damage is the single estimate picked on the Prediction tab; the range shows both ends; the percent needs a readable target health (out of combat in Forever)."] =
    "Schaden ist die einzelne Schätzung, die im Reiter Prognose gewählt wurde; die Spanne zeigt beide Enden; für den Prozentwert muss die Gesundheit des Ziels lesbar sein (in Forever außerhalb des Kampfes).",

  -- the Nameplates tab
  ["NAMEPLATES"] = "NAMENSPLAKETTEN",
  ["Nameplate style"] = "Stil der Namensplakette",
  ["Marker on the health bar"] = "Markierung auf der Gesundheitsleiste",
  ["Marker and an impact icon"] = "Markierung und ein Einschlagsymbol",
  ["The target's own plate gets the same marker, with its own colors; enemy bars are red."] =
    "Die Namensplakette des Ziels erhält dieselbe Markierung, mit eigenen Farben; Gegnerleisten sind rot.",
  ["The impact icon beside or above the plate."] = "Das Einschlagsymbol neben oder über der Namensplakette.",
  ["Icon position"] = "Symbolposition",
  ["Portrait"] = "Porträt",
  ["Show kill icon"] = "Kill-Symbol zeigen",
  ["An icon when even the lowest end of the cast's range would finish the target. With secret health, native clipping can reveal part of the icon shortly before lethal."] =
    "Ein Symbol, wenn schon das untere Ende der Zauberspanne das Ziel erledigen würde. Bei verborgener Gesundheit kann das native Clipping kurz vor dem tödlichen Treffer einen Teil des Symbols zeigen.",
  ["Below the bar"] = "Unter der Leiste",
  ["Above the bar"] = "Über der Leiste",
  ["Right of the bar"] = "Rechts der Leiste",

  -- the Prediction tab
  ["THE PREDICTION"] = "DIE PROGNOSE",
  ["The marker shows"] = "Die Markierung zeigt",
  ["Average of the range"] = "Durchschnitt der Spanne",
  ["Lowest of the range"] = "Niedrigster Wert der Spanne",
  ["Highest of the range"] = "Höchster Wert der Spanne",
  ["The expected damage the description and your spell power give."] =
    "Der erwartete Schaden, den die Beschreibung und Eure Zaubermacht ergeben.",
  ["Only cast spells"] = "Nur gewirkte Zauber",
  ["Show casts and channels. Instant spells are hidden unless this option is switched off."] =
    "Zeigt gewirkte und kanalisierte Zauber. Spontanzauber werden ausgeblendet, solange diese Option nicht ausgeschaltet ist.",
  ["Finisher preview"] = "Vorschau der Abschlussbewegung",
  ["Rogues and druids: while your target has combo points, show on its health bar and plate what your strongest damage finisher on the action bars (Eviscerate, Ferocious Bite, a rune's Between the Eyes) would deal at that count. On Forever the description's numbers leave out attack power, so the real hit is at least this much. Damage-over-time finishers (Rupture, Rip) and combo point builders are not shown. Needs SpellDamageInfo."] =
    "Schurken und Druiden: Solange Euer Ziel Combopunkte hat, wird auf seiner Gesundheitsleiste und Namensplakette gezeigt, was Eure stärkste Schadens-Abschlussbewegung auf den Aktionsleisten (Eviscerate, Ferocious Bite, Between the Eyes einer Rune) bei dieser Punktzahl verursachen würde. In Forever lassen die Zahlen der Beschreibung die Angriffskraft aus, der echte Treffer ist also mindestens so hoch. Abschlussbewegungen mit Schaden über Zeit (Rupture, Rip) und Combopunkt-Aufbauer werden nicht gezeigt. Benötigt SpellDamageInfo.",
  ["Learn from hits"] = "Aus Treffern lernen",
  ["Every non-crit hit that matches the cast bends the estimate toward what you actually deal. On Retail the description already holds your spell power, so only physical hits are learned there: the target's armor takes a share off them that the description does not say."] =
    "Jeder nicht kritische Treffer, der zum Zauber passt, biegt die Schätzung in Richtung dessen, was Ihr tatsächlich verursacht. In Retail enthält die Beschreibung bereits Eure Zaubermacht, daher werden dort nur physische Treffer gelernt: Die Rüstung des Ziels nimmt ihnen einen Anteil ab, den die Beschreibung nicht nennt.",
  ["Manual spell power"] = "Manuelle Zaubermacht",
  ["Use your own number instead of the client's reading, for testing or when the client hides it."] =
    "Verwendet Eure eigene Zahl statt des vom Client gelesenen Werts, zum Testen oder wenn der Client ihn verbirgt.",
  ["Spell power"] = "Zaubermacht",
  ["Applied through the spell's own coefficient, like the client's own reading would be."] =
    "Wird über den eigenen Koeffizienten des Zaubers angewendet, so wie es der vom Client gelesene Wert würde.",
  ["Learned factors"] = "Gelernte Faktoren",
  ["Forget what earlier hits taught the estimate."] = "Vergisst, was frühere Treffer die Schätzung gelehrt haben.",
  ["TALENTS (FOREVER)"] = "TALENTE (FOREVER)",
  ["No curated passive talent multipliers for this class (or the character class could not be read). Retail tooltips already include talents, so nothing is added there."] =
    "Für diese Klasse gibt es keine ausgewählten passiven Talent-Multiplikatoren (oder die Klasse des Charakters konnte nicht gelesen werden). Retail-Tooltips enthalten Talente bereits, daher wird dort nichts hinzugefügt.",
  ["Auto (detect)"] = "Automatisch (erkennen)",
  ["Max rank"] = "Höchster Rang",
  ["Auto reads the talent's rank from the client's talent tree (C_Traits). Off skips it; Max rank applies it without asking. Retail never adds talents: its descriptions hold them."] =
    "Automatisch liest den Rang des Talents aus dem Talentbaum des Clients (C_Traits). Aus überspringt es; Höchster Rang wendet es ohne Nachfrage an. Retail fügt nie Talente hinzu: Seine Beschreibungen enthalten sie bereits.",
  ["AURAS (READ WHEN VISIBLE)"] = "AUREN (GELESEN, WENN SICHTBAR)",
  ["Include auras"] = "Auren einbeziehen",
  ["Buffs on you and debuffs on the target that the description does not hold: Arcane Power, Power Infusion, Improved Scorch, Curse of the Elements."] =
    "Stärkungszauber auf Euch und Schwächungszauber auf dem Ziel, die die Beschreibung nicht enthält: Arcane Power, Power Infusion, Improved Scorch, Curse of the Elements.",
  ["Auto (read)"] = "Automatisch (auslesen)",
  ["Auto applies this while the client shows it. WoW: Forever hides auras in combat, so there it only ever applies out of combat; the hit calibration carries the rest. /upt castpred auras prints what is readable right now."] =
    "Automatisch wendet dies an, solange der Client es anzeigt. WoW: Forever verbirgt Auren im Kampf, daher gilt es dort nur außerhalb des Kampfes; den Rest übernimmt die Kalibrierung durch Treffer. /upt castpred auras gibt aus, was gerade lesbar ist.",
  ["The estimate is the description's own damage range plus your spell power through the spell's coefficient, the detected passive talents and the readable auras. Critical strikes roll about double, so a crit can outrun the marker: the prediction is an honest estimate, never a promise. /upt castpred talents and /upt castpred auras print what the client answers."] =
    "Die Schätzung ist die eigene Schadensspanne der Beschreibung plus Eure Zaubermacht über den Koeffizienten des Zaubers, die erkannten passiven Talente und die lesbaren Auren. Kritische Treffer verursachen etwa doppelt so viel, ein kritischer Treffer kann die Markierung also überholen: Die Prognose ist eine ehrliche Schätzung, nie ein Versprechen. /upt castpred talents und /upt castpred auras geben aus, was der Client antwortet.",

  -- the talents and auras of the rows (the spell names stay as they are)
  ["Fire Power"] = "Fire Power",
  ["Crusade"] = "Crusade",
  ["Sacred Arbiter"] = "Sacred Arbiter",
  ["Improved Shadow Bolt"] = "Improved Shadow Bolt",
  ["Shadow and Flame"] = "Shadow and Flame",
  ["Decimation"] = "Decimation",
  ["Power in Light"] = "Power in Light",
  ["Arcane Power (player)"] = "Arcane Power (Spieler)",
  ["Power Infusion (player)"] = "Power Infusion (Spieler)",
  ["Improved Scorch (target)"] = "Improved Scorch (Ziel)",
  ["Curse of the Elements (rank 2) (target)"] = "Curse of the Elements (Rang 2) (Ziel)",
  ["Curse of the Elements (target)"] = "Curse of the Elements (Ziel)",
  ["Frigid Power (Ice Barrier) (player)"] = "Frigid Power (Ice Barrier) (Spieler)",
  ["Ice Barrier (shield up) (player)"] = "Ice Barrier (Schild aktiv) (Spieler)",
  ["Fingers of Frost (player)"] = "Fingers of Frost (Spieler)",
  ["Improved Shadow Bolt (target)"] = "Improved Shadow Bolt (Ziel)",
  ["Shadow and Flame (player)"] = "Shadow and Flame (Spieler)",
  ["Decimation (player)"] = "Decimation (Spieler)",
  ["Demonic Sacrifice (Imp) (player)"] = "Demonic Sacrifice (Wichtel) (Spieler)",
  ["Demonic Sacrifice (Succubus) (player)"] = "Demonic Sacrifice (Sukkubus) (Spieler)",
  ["Immolate (Incinerate +25%) (target)"] = "Immolate (Incinerate +25%) (Ziel)",
  ["Power in Light (Holy Fire, Shadow Word: Pain) (target)"] = "Power in Light (Holy Fire, Shadow Word: Pain) (Ziel)",
  ["Shadow Weaving (target)"] = "Shadow Weaving (Ziel)",
  ["Shadowform (player)"] = "Shadowform (Spieler)",
  ["Stormstrike (target)"] = "Stormstrike (Ziel)",
  ["Rage of the Farseer (player)"] = "Rage of the Farseer (Spieler)",
  ["Eureka! (Gnome) (player)"] = "Eureka! (Gnom) (Spieler)",

  -- the chat messages
  ["Learned factors cleared."] = "Gelernte Faktoren zurückgesetzt.",
  ["Nothing learned yet: cast damage spells at an enemy."] =
    "Noch nichts gelernt: Wirkt Schadenszauber auf einen Feind.",
  ["%s (%d): x%.2f from %d hit(s)%s"] = "%s (%d): x%.2f aus %d Treffer(n)%s",
  [", %d hit(s) too far from the estimate to learn from"] =
    ", %d Treffer zu weit von der Schätzung entfernt, um daraus zu lernen",
  ["... and %d more"] = "... und %d weitere",
  ["Health bar marker ON."] = "Markierung der Gesundheitsleiste: AN.",
  ["Health bar marker OFF."] = "Markierung der Gesundheitsleiste: AUS.",
  ["/upt castpred - open the settings; line - toggle the marker; talents - what the talent tree answers; auras - what buffs/debuffs are readable; learned - what the hits taught; census - read the whole talent tree into the saved settings (census clear removes it); reset - forget learned factors; debug - echo the trace log"] =
    "/upt castpred - öffnet die Einstellungen; line - schaltet die Markierung um; talents - was der Talentbaum antwortet; auras - welche Stärkungs- und Schwächungszauber lesbar sind; learned - was die Treffer gelehrt haben; census - liest den ganzen Talentbaum in die gespeicherten Einstellungen ein (census clear entfernt ihn); reset - vergisst gelernte Faktoren; debug - gibt das Ablaufprotokoll im Chat aus",
  ["Show mana cost on your mana bar"] = "Manakosten auf Eurer Manaleiste zeigen",
  ["While you cast a spell with a cast time, marks its estimated mana cost on your mana bar."] =
    "Während Ihr einen Zauber mit Zauberzeit wirkt, markiert ein Abschnitt auf Eurer Manaleiste seine geschätzten Manakosten.",
  ["While you cast a spell with a cast time, marks its estimated cost to the right of your remaining mana. This illustrates mana already spent, not another deduction."] =
    "Während Ihr einen Zauber mit Zauberzeit wirkt, markiert ein Abschnitt rechts vom verbleibenden Mana seine geschätzten Kosten. Er zeigt bereits verbrauchtes Mana, keinen weiteren Abzug.",
})
