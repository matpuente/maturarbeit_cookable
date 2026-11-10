# Cookable (Kühlschrank-App) – Projektspezifikation

Diese Datei beschreibt die App, die in diesem Projekt entwickelt wird.
Bei Unklarheiten: zuerst nachfragen, keine eigenen Annahmen treffen.

---

## 1. Zweck

**Problem:** Viele wissen nicht, was sie mit den Zutaten kochen sollen, die sie zuhause haben. Dadurch werden Lebensmittel vergessen und landen im Müll.

**Lösung:** Eine iOS-App, in der Nutzer ihre vorhandenen Zutaten eingeben und passende Rezepte vorgeschlagen bekommen.

---

## 2. Technische Rahmenbedingungen (verbindlich)

| Bereich | Vorgabe |
| --- | --- |
| App-Name | Cookable (Product Name in Xcode und Anzeigename auf dem Home-Bildschirm) |
| Plattform | iOS / iPadOS |
| Sprache / UI | Swift, SwiftUI |
| Projektstruktur | Normales Xcode-App-Projekt (kein App-Playground) |
| Entwicklungsumgebung | Xcode 27 (aktuelle Version, Swift 6.4) |
| Mindestversion | iOS / iPadOS 26.0 (Testgeräte: iPad mit iPadOS 27.2, iPhone mit iOS 26.6) |
| Speicherung der Nutzerdaten | SwiftData |
| Speicherung der Rezepte | SQLite-Datei, die in der App mitgeliefert wird (nur lesend, kein Server) |
| Tests | Simulator in Xcode |
| Test auf echtem Gerät | Direkt aus Xcode auf iPad und iPhone (per Kabel, kostenlose Apple-ID) |
| Rezeptquelle | Zwei Food.com-Datensätze auf Kaggle: `irkaal/foodcom-recipes-and-reviews` (Hauptquelle) und `realalexanderwei/food-com-recipes-with-ingredients-and-tags` (vollständige Zutatenzeilen mit Mengen und Einheiten) |
| Übersetzung | DeepL API Free |
| Internet | Vorausgesetzt für die Übersetzung der Rezepttexte; kein Offline-Modus |

- Die App muss auf iOS / iPadOS 26.0 laufen. Keine APIs oder Funktionen verwenden, die erst ab iOS 27 verfügbar sind.
- Die Oberfläche muss auf iPhone und iPad gut bedienbar sein.
- Keine Veröffentlichung im App Store.

### Ordnerstruktur und Git

```
Cookable/                    ← Hauptordner, Claude Code hier starten
├── CLAUDE.md
├── Cookable/                ← Xcode-App-Projekt
└── Datenaufbereitung/       ← Python-Skripte und Kaggle-Datensätze (nicht Teil der App)
```

- App-Code in `Cookable/Cookable/`: `Ansichten/`, `Modelle/` (SwiftData), `Daten/` (Zugriff auf die Rezeptdatenbank), `Ressourcen/rezepte.sqlite`.
- Zugriff auf die Rezeptdatenbank mit der eingebauten SQLite-Bibliothek (`import SQLite3`), nur lesend, keine zusätzlichen Pakete.
- Nach einer neuen Aufbereitung `Datenaufbereitung/ergebnisse/rezepte.sqlite` nach `Cookable/Cookable/Ressourcen/` kopieren.
- Ein Git-Repository im Hauptordner (Remote: `github.com/matpuente/maturarbeit_cookable`). **Jede Etappe bzw. jede Version wird committet**, auch Änderungen an Skripten, Zutatenliste und Datenbank. Rohdaten, `.venv` und Schlüsseldateien sind in `.gitignore` ausgeschlossen.
- Im Simulator ist nur die Laufzeit iOS 27.2 installiert; die Mindestversion iOS 26.0 prüft der Compiler (Verfügbarkeit der APIs).

---

## 3. Funktionen

### Version 1 (essenziell)

1. **Zutaten eingeben** – mit Autovervollständigung und Kategorisierung nach Lagerort (Kühlschrank, Tiefkühler, Vorratsschrank).
   - Pro Zutat: Name, Lagerort, optional Ablaufdatum. Einträge können bearbeitet (Lagerort, Ablaufdatum) und gelöscht werden.
   - Nur Zutaten aus der Zutatenliste können erfasst werden (keine freie Eingabe).
   - Dieselbe Zutat darf nicht zweimal am selben Lagerort stehen; an verschiedenen Lagerorten ist sie erlaubt.
   - Keine Mengenangaben.
   - Die Autovervollständigung nutzt die Zutatenliste (Abschnitt 6).
2. **Rezeptvorschläge** – aus den mitgelieferten Rezepten, passend zu den eingegebenen Zutaten.
   - Zusätzlicher kleiner Bereich **«Immer zuhause»** im Vorrat (ohne Ablaufdatum): beim ersten Start mit den 7 Grundzutaten gefüllt (Salz, Pfeffer, Zucker, Mehl, Wasser, Öl, Olivenöl). Man kann Grundzutaten daraus löschen (z. B. kein Mehl zuhause) und beliebige Zutaten der Liste hinzufügen, die man immer hat (z. B. Butter).
   - **Austauschbare Zutaten:** Zutaten derselben Austauschgruppe (z. B. «Pasta»: Penne, Spaghetti, Fusilli …) ersetzen sich gegenseitig. Fehlt eine Zutat, ist aber eine Zutat derselben Gruppe im Vorrat, zählt sie als «vorhanden (Ersatz)». Bei gleichem Anteil kommen Rezepte mit weniger Ersatz zuerst. Anzeige: «4 von 6 Zutaten vorhanden · 1 Ersatz». Die Gruppen stehen in `Datenaufbereitung/ergebnisse/austauschgruppen.csv` (von Hand kontrolliert).
   - Sortierung: Eine **vorhandene Grundzutat** zählt weder als vorhanden noch als fehlend. Eine **gelöschte Grundzutat** zählt als fehlend. Selbst hinzugefügte Zutaten in «Immer zuhause» zählen wie andere Vorratszutaten als vorhanden.
   - Sortierung nach Anteil der vorhandenen Zutaten (es erscheinen auch Rezepte, für die nicht alle Zutaten vorhanden sind).
3. **Filter**
   - Zubereitungszeit: bis 15 / 30 / 60 Minuten, über 60 Minuten oder beliebig.
   - Kategorie: Die Kategorien des Datensatzes werden zu wenigen deutschen Gruppen zusammengefasst: Frühstück, Hauptgericht, Beilage, Dessert, Snack.
   - **Muss enthalten:** Man wählt eine oder mehrere Zutaten aus dem eigenen Vorrat; es erscheinen nur Rezepte, die alle gewählten Zutaten enthalten (z. B. um ein Lebensmittel aufzubrauchen). Der übrige Vorrat zählt weiterhin für den Anteil. Rezepte mit einer austauschbaren Zutat erscheinen ebenfalls, aber erst nach allen Rezepten, die die gewählten Zutaten genau enthalten. Die Auswahl ist nach Lagerort gruppiert und durchsuchbar und wird nicht dauerhaft gespeichert.
4. **Portionsrechner** – rechnet die Zutatenmengen auf die gewünschte Portionenzahl um. Grundlage sind die vollständigen Zutatenzeilen aus dem zweiten Datensatz.
5. **Nährwerte** – pro Rezept.

### Später

6. **Fehlende Zutaten & Einkaufsliste** – fehlende Zutaten pro Rezept anzeigen und automatisch eine Einkaufsliste erstellen.
7. **Ablaufdatum-Tracking**
   - Farbliche Markierung im Vorrat: orange ab 3 Tagen vor Ablauf, rot wenn abgelaufen.
   - Mitteilungen auf dem Gerät nur, falls am Schluss noch Zeit bleibt.
8. **Favoriten** – Rezepte speichern.
9. **Bewertungen** – eigene Bewertung von Rezepten; ganz am Schluss, falls noch Zeit bleibt.

Funktionen aus «Später» erst umsetzen, wenn Version 1 fertig ist und ausdrücklich danach gefragt wird.

---

## 4. Bildschirme

Navigation über Tabs.

### Version 1

- **Vorrat:** Bereich «Immer zuhause» (kompakt, oben) und Zutaten nach Lagerort gruppiert; Zutaten hinzufügen, bearbeiten und löschen.
- **Rezepte:** Vorschlagsliste mit Filtern.
  - **Detailansicht:** Zutaten, Anleitung, Nährwerte, Portionsrechner.

### Später

- **Einkaufsliste**
- **Favoriten**

---

## 5. Rezeptdaten

- Alle Rezepte stammen ausschliesslich aus den beiden Food.com-Datensätzen (Abschnitt 2).
- **Nicht** RecipeNLG verwenden.
- **Keine** Rezepte durch KI generieren oder ergänzen.

### Bekannte Datenprobleme im Hauptdatensatz

- `RecipeIngredientQuantities` enthält nur Zahlen ohne Masseinheiten; teilweise fehlen Werte (`NA`).
- `RecipeIngredientQuantities` und `RecipeIngredientParts` sind oft unterschiedlich lang. Eine Menge lässt sich deshalb nicht zuverlässig einer Zutat zuordnen.
- Listen sind im R-Format gespeichert (`c("…", "…")`), Zeiten im ISO-8601-Format (z. B. `PT45M`).

### Aufbereitung

Die Aufbereitung erfolgt mit Python-Skripten auf dem Mac. Die Skripte sind nicht Teil der App und liegen getrennt vom App-Code. Ergebnis ist eine SQLite-Datei, die in der App mitgeliefert wird.

**Auswahlregeln** (Ziel: etwa 15'000 Rezepte):

1. Das Rezept ist in beiden Datensätzen enthalten.
2. Nährwerte, Zubereitungszeit und Portionenzahl sind vorhanden, und die Nährwerte bestehen die Plausibilitätsprüfung (siehe unten).
   - Die Portionenzahl muss im Hauptdatensatz (`RecipeServings`) stehen; sie wird nicht aus dem zweiten Datensatz ergänzt (ohne sie gelten die Nährwerte oft für das ganze Rezept).
   - Zubereitungszeit fehlt, wenn `TotalTime` leer oder `PT0S` ist.
   - Die Portionenzahl muss in beiden Datensätzen gleich sein (`RecipeServings` = `servings`), damit Portionsrechner und Nährwerte zusammenpassen.
   - Höchstens 100 Portionen.
3. Mindestens 5 Bewertungen und eine Durchschnittsbewertung von mindestens 4. Die Bewertungen dienen nur der Auswahl und erscheinen nicht in der App.
4. Pro Kategoriegruppe (Abschnitt 3, Filter) werden die meistbewerteten Rezepte gewählt (nach `ReviewCount`), sodass alle Gruppen vertreten sind. Quoten: Hauptgericht 6'000, Beilage 3'500, Dessert 2'500, Frühstück 1'500, Snack 1'500 (total 15'000).
   - Zuordnung zur Gruppe: zuerst über die Kurs-Tags des zweiten Datensatzes (`breakfast`, `desserts`, `main-dish`, `side-dishes`, `appetizers` …), sonst über `RecipeCategory`. Skript: `Datenaufbereitung/skripte/kategorien.py`.
   - Süsse Schnellbrote (`Quick Breads`, z. B. Banana Bread, Muffins) gehören zu Frühstück, Hefebrote zu Beilage.
   - Saucen/Würzen und Rezepte ohne erkennbaren Gang werden ausgeschlossen.
5. Keine Getränke: Rezepte aus den Getränke-Kategorien `Beverages`, `Smoothies`, `Punch Beverage`, `Shakes` und `Margarita` werden ausgeschlossen (ermittelt in der Datenanalyse). Massgebend ist `RecipeCategory`; Rezepte mit Getränke-Tag, aber anderer Kategorie (z. B. `Frozen Desserts`) bleiben.
6. Keine Nicht-Lebensmittel: Die Kategorien `Bath/Beauty`, `Household Cleaner` und `Homeopathy/Remedies` werden ebenfalls ausgeschlossen.

Doppelte IDs im zweiten Datensatz: Bei identischen Zeilen wird eine behalten; IDs mit inhaltlich abweichenden Zeilen (45) und Zeilen mit unlesbarer Zutatenliste werden verworfen.

Wenn nach Regel 1 zu wenige Rezepte übrig bleiben: nachfragen, bevor Regel 3 gelockert wird.

### Weitere Festlegungen

- Rezeptnamen werden von HTML-Zeichen bereinigt (`&amp;` → `&`).
- Die Bild-URL von Food.com wird in der SQLite-Datei mitgespeichert; in der App wird sie nur angezeigt, wenn ausdrücklich gewünscht.
- Der DeepL-API-Schlüssel für die Aufbereitungsskripte steht in `Datenaufbereitung/deepl_api_key.txt` (eine Zeile, nicht im Code).

### Zutatenzeilen und Zutatennamen

- Quelle ist `ingredients_raw` aus dem zweiten Datensatz. `ingredients` (Z) und `RecipeIngredientParts` (H) sind unvollständig und werden nicht verwendet.
- Jede Zeile wird zerlegt in: Menge, Menge bis (bei Bereichen), Packungsgrösse mit Einheit, Einheit, Grösse (large/medium/small), Name und Zusatz. Bei Alternativen («… or …») zählt die erste.
- Der Name wird zu einem **Grundnamen** vereinheitlicht: Zubereitungswörter entfernen (chopped, minced …), Mehrzahl → Einzahl; bestimmende Wörter bleiben («ground beef» ≠ «ground cinnamon»). Kombinationen wie «salt and pepper» werden in zwei Zutaten aufgeteilt.
- Die Zutatenliste (Abschnitt 6) besteht aus den 1'000 häufigsten Grundnamen (Abdeckung ca. 88 % aller Zeilen).
- Zutaten, die nicht in der Zutatenliste stehen, zählen bei der Sortierung der Rezeptvorschläge als «nicht vorhanden»; im Rezept werden sie normal angezeigt.

### Plausibilitätsprüfung der Nährwerte

Die Nährwerte im Hauptdatensatz gelten pro Portion. Ein Rezept wird nur übernommen, wenn es alle folgenden Prüfungen besteht:

1. **Keine negativen Werte** in den Nährwertspalten (`Calories`, `FatContent`, `SaturatedFatContent`, `CholesterolContent`, `SodiumContent`, `CarbohydrateContent`, `FiberContent`, `SugarContent`, `ProteinContent`).
2. **Teilmengen:** `SaturatedFatContent` ≤ `FatContent`, `SugarContent` ≤ `CarbohydrateContent`, `FiberContent` ≤ `CarbohydrateContent`.
3. **Energiebilanz:** Die Kalorien müssen zu den Makronährstoffen passen. Berechnet: 4 × Kohlenhydrate + 4 × Protein + 9 × Fett (in kcal). Die Abweichung von `Calories` darf höchstens 20 % oder 20 kcal betragen (der grössere Wert gilt).
4. **Obergrenze:** höchstens 2'500 kcal pro Portion.
5. **Portionsgewicht** (nur wenn im zweiten Datensatz vorhanden): Fett + Kohlenhydrate + Protein (in g) ≤ Portionsgewicht (in g). Ein Portionsgewicht von `0 g` gilt als nicht vorhanden.

- Für jede Prüfung wird gezählt, wie viele Rezepte sie nicht bestehen. Diese Zahlen gehören in den Bericht der Datenanalyse (Abschnitt 7).
- Fallen mehr als 10 % der Rezepte, die Regel 1 erfüllen, durch: nachfragen, bevor sie ausgeschlossen werden.
- Die Grenzwerte (20 %, 20 kcal, 2'500 kcal) wurden nach der Datenanalyse bestätigt.
- Ergebnis der Datenanalyse: 490'475 Rezepte in beiden Datensätzen; 5,4 % bestehen mindestens eine Prüfung nicht und werden ausgeschlossen. Details: `Datenaufbereitung/Bericht_Datenanalyse.md`.

---

## 6. Sprache und Übersetzung

- Die Benutzeroberfläche ist komplett auf **Deutsch**.

### Zutatenliste (Suche und Autovervollständigung)

- Ein Skript ermittelt die 1'000 häufigsten Zutatennamen im Datensatz.
- DeepL übersetzt sie einmalig ins Deutsche.
- Die Liste wird als Datei ausgegeben, die von Hand kontrolliert und korrigiert wird, bevor sie in die App kommt.
- Die Liste enthält auch die heiklen Begriffe wie «Peperoni», «Rahm» oder «Nüsslisalat».
- Ein deutscher Begriff kann mehreren englischen Namen aus dem Datensatz zugeordnet sein (z. B. «Rahm» zu mehreren Rahm-Varianten).
- Die App sucht ausschliesslich über diese Liste; für die Zutatensuche wird DeepL in der App nicht aufgerufen.

### Übersetzung der Rezepte

- Rezepte werden beim Öffnen über DeepL ins Deutsche übersetzt.
- Übersetzte Rezepte werden gespeichert und nie ein zweites Mal übersetzt (DeepL API Free: 500'000 Zeichen pro Monat).
- Ohne Internetverbindung erscheint eine kurze Meldung.
- Der DeepL-API-Schlüssel steht in einer separaten Datei, nicht im Code, und wird nicht mitveröffentlicht.

### Masseinheiten

- Cups, Ounces und Fahrenheit werden in Gramm, Milliliter und Grad Celsius umgerechnet.
- Grundlage sind die Zutatenzeilen aus dem zweiten Datensatz sowie Temperaturangaben in den Anleitungstexten.

---

## 7. Reihenfolge

1. **Datenanalyse** (erledigt, bestätigt am 1. November 2026): Beide Datensätze analysieren und berichten:
   - Lassen sie sich über die Rezept-ID verknüpfen?
   - Wie viele Rezepte sind in beiden enthalten?
   - In welcher Form stehen Mengen und Einheiten in den Zutatenzeilen des zweiten Datensatzes?
   - Wie viele Rezepte bestehen die einzelnen Prüfungen der Nährwerte nicht (Abschnitt 5)?
   - Welche Kategorien des Datensatzes sind Getränke und werden ausgeschlossen?
   Erst nach diesem Bericht und Bestätigung weitermachen.
2. **Datenaufbereitung** (erledigt): SQLite-Datei nach den Auswahlregeln erstellen; Zutatenliste zur Kontrolle ausgeben.
   - Skripte in `Datenaufbereitung/skripte/` (Python-Umgebung: `Datenaufbereitung/.venv`), in dieser Reihenfolge:
     1. `aufbereitung.py` erstellt `ergebnisse/rezepte.sqlite` (überschreibt die Datei).
     2. `zutatenliste.py` erstellt `ergebnisse/zutatenliste_zur_kontrolle.csv` mit DeepL. **Nicht erneut ausführen**, sonst wird die von Hand kontrollierte Liste überschrieben.
     3. `zutatenliste_uebernehmen.py` übernimmt die kontrollierte Liste in die SQLite-Datei (Tabellen `zutat`, `zutat_variante`, `rezept_zutat` inkl. Grundzutaten, Spalte `rezept.anzahl_ohne_liste`).
   - Seltene Varianten (ausserhalb der 1'000 häufigsten Namen, mind. 3 Rezepte): `varianten_vorschlaege.py` erstellt `ergebnisse/varianten_vorschlaege.csv` (Spalte `uebernehmen` von Hand kontrollieren). `zutatenliste_uebernehmen.py` liest die Datei direkt und ordnet die Varianten bestehenden deutschen Begriffen zu.
   - Austauschgruppen: `austauschgruppen_vorschlag.py` erstellt `ergebnisse/austauschgruppen.csv` (eine Zeile pro deutschem Begriff, Spalte `austauschgruppe` von Hand kontrollieren); `zutatenliste_uebernehmen.py` speichert sie in `zutat.austauschgruppe`. Beide Vorschlags-Skripte überschreiben eine bestehende Datei nur mit `--neu`.
   - Nachbessern der Zutatenliste: `zusammenfassen_vorschlaege.py` schlägt Varianten zum Zusammenfassen vor (`ergebnisse/zusammenfassen_vorschlaege.csv`, Spalte `uebernehmen` von Hand kontrollieren), `zusammenfassen_anwenden.py` übernimmt sie in die Zutatenliste (mit Sicherung). Danach `zutatenliste_uebernehmen.py`.
   - Stand 10. November 2026: 15'000 Rezepte, 698 deutsche Zutaten (Rahm, Vollrahm und Schlagrahm zu «Rahm» zusammengefasst). Die Grundzutaten sind auf 7 Begriffe zusammengefasst (Salz, Pfeffer, Zucker, Mehl, Wasser, Öl, Olivenöl). Die kontrollierte Liste ist die verbindliche Quelle.
   - Poulet-Teile: chicken thigh = Pouletoberschenkel, chicken drumstick = Pouletunterschenkel, chicken leg = Pouletschenkel (ganzer Schenkel).
   - Ein deutscher Begriff gilt nur ganz oder gar nicht als Grundzutat. Varianten werden zusammengefasst, wenn man mit der Zutat zuhause das Rezept kochen kann (garlic clove → Knoblauch). Verschiedene Produkte bleiben getrennt (Knoblauch ≠ Knoblauchpulver, Rahm ≠ Sauerrahm).
   - Anteil vorhandener Zutaten: siehe Abschnitt 3, Funktion 2 (Regel für Grundzutaten). `rezept_zutat` enthält auch die Grundzutaten (Markierung in `zutat.grundzutat`); Zutaten ausserhalb der Liste stehen als Anzahl in `rezept.anzahl_ohne_liste`.
   - `rezept.beliebtheit` = Rang nach Anzahl Bewertungen; nur zur Sortierung bei Gleichstand, erscheint nicht in der App.
   - Die IDs in `zutat` sind nicht dauerhaft (sie können sich bei einer neuen Übernahme ändern). Die App gleicht gespeicherte Vorratseinträge beim Start über den deutschen Namen ab.
3. **App Version 1:** Funktionen 1–5 in Etappen umsetzen.
   1. Grundgerüst (erledigt 10. November 2026): Projekt «Cookable» (iOS 26.0, Swift 6), Rezeptdatenbank eingebunden, Tabs «Vorrat» und «Rezepte», SwiftData-Modell `VorratsEintrag`.
   2. Vorrat (erledigt 10. November 2026): Zutaten mit Autovervollständigung erfassen, Bereich «Immer zuhause», nach Lagerort gruppieren, Ablaufdatum, bearbeiten, löschen.
      - «Immer zuhause» ist der Lagerort `immerZuhause` im SwiftData-Modell; die Grundzutaten werden beim ersten Start eingetragen (`@AppStorage("grundzutatenAngelegt")`).
      - Suche: ohne Gross-/Kleinschreibung und Akzente; Reihenfolge Namensanfang → Wortanfang → irgendwo, innerhalb häufige Zutaten zuerst. Anzeige mit grossem Anfangsbuchstaben.
      - Die Oberfläche verwendet immer das Gebietsschema `de_CH` (Datum, Zahlen).
   3. Rezeptvorschläge (erledigt 10. November 2026): Sortierung nach Anteil vorhandener Zutaten, Filter Zeit und Kategorie.
      - Es erscheinen nur Rezepte mit mindestens einer vorhandenen Zutat. Anzeige «4 von 6 Zutaten vorhanden» (vorhandene Grundzutaten zählen nicht mit).
      - Sortierung: Anteil absteigend, dann weniger fehlende Zutaten, dann `beliebtheit`.
      - Berechnung im Speicher (alle Rezepte mit ihren Zutaten werden beim Start geladen), dauert wenige Millisekunden.
      - Filter bleiben gespeichert (`@AppStorage`). Auf dem iPad Liste und Detail nebeneinander (`NavigationSplitView`).
      - Keine Bilder in der Liste. In der Detailansicht kommt das Foto von Food.com dazu (beschlossen für Etappe 4).
      - Filter «Muss enthalten» (ergänzt 10. November 2026).
      - Suche (ergänzt 10. November 2026): Suchfeld «Rezept oder Zutat suchen» über der Liste. Gesucht wird im Rezeptnamen (vorerst Englisch) und in den deutschen Zutatennamen. Bei einer Suche erscheinen auch Rezepte ohne vorhandene Zutat; Treffer im Namen kommen zuerst. Die übrigen Filter gelten weiterhin.
   4. Detailansicht (erledigt 10. November 2026): Foto, Zutaten (metrisch), Anleitung, Nährwerte, Portionsrechner.
      - Foto von Food.com oben (Platzhalter, wenn keines vorhanden); Zwischenspeicher bis 100 MB (`URLCache`).
      - Mengen: Cups, Pints, Quarts → ml; Ounces, Pounds → g; Butter-«sticks» → 113 g; **EL und TL bleiben** (nicht in ml). Rundung: unter 10 auf 1, unter 50 auf 5, sonst auf 10; ab 1000 in l bzw. kg. Stückzahlen und Löffel als Brüche (½, ⅓ …). Einheiten auf Deutsch (Dose, Packung, Zehe …).
      - Portionsrechner von 1 bis zum Vierfachen der Originalportionen (höchstens 100). Nährwerte bleiben pro Portion.
      - Zutaten: ✓ = vorhanden (auch vorhandene Grundzutaten), orange = Ersatz («Ersatz: du hast Penne-Nudeln»). Fehlende Zutaten werden nicht markiert (Funktion 6).
   5. Übersetzung mit DeepL in der App, gespeicherte Übersetzungen, Meldung ohne Internet.
   - Rezeptnamen in der Vorschlagsliste: nur die sichtbaren Namen werden übersetzt (in Paketen beim Scrollen) und gespeichert; keine Vorab-Übersetzung aller Namen (416'000 Zeichen).
4. **Design:** Nach Version 1 eine eigene Etappe für das Design (Farben, App-Symbol, Gestaltung der Ansichten). Die Darstellung (`Ansichten/`) ist von Logik und Daten getrennt und lässt sich ändern, ohne die Funktionen zu beeinträchtigen.
5. **Später:** Funktionen 6–9, nur auf ausdrückliche Anfrage.

---

## 8. Arbeitsweise

- Vor jeder grösseren Umsetzung zuerst einen kurzen Plan vorschlagen und auf Bestätigung warten.
- In kleinen Etappen arbeiten; nach jeder Etappe muss die App im Simulator lauffähig sein.
- Nach jeder Änderung am App-Code die App selbst mit `xcodebuild` bauen und alle Fehler beheben, bevor die Etappe als fertig gemeldet wird.
- Diese Datei aktuell halten, wenn sich Entscheidungen ändern.
