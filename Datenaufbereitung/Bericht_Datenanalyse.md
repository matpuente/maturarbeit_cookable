# Bericht Datenanalyse (Schritt 1)

Stand: 1. November 2026 · Skript: `skripte/analyse.py` · Rohzahlen: `ergebnisse/analyse.json`

| Kürzel | Datensatz | Datei | Zeilen |
| --- | --- | --- | --- |
| **H** (Hauptdatensatz) | `irkaal/foodcom-recipes-and-reviews` | `recipes.parquet` | 522'517 |
| **Z** (zweiter Datensatz) | `realalexanderwei/food-com-recipes-with-ingredients-and-tags` | `recipes_ingredients.csv` | 500'471 |

---

## 1. Lassen sich die Datensätze über die Rezept-ID verknüpfen?

**Ja.** `RecipeId` (H) entspricht `id` (Z).

- In H ist jede ID eindeutig.
- In Z kommen 7'841 IDs doppelt vor. Bei 7'796 davon sind die Zeilen identisch, die zweite Zeile wird verworfen. Bei 45 IDs unterscheiden sich die Zeilen inhaltlich; diese werden ganz verworfen.
- In 3 Zeilen von Z lässt sich die Zutatenliste nicht lesen; auch diese werden verworfen.
- **Kontrolle:** Bei 99,3 % der verknüpften Rezepte ist der Name gleich. Die restlichen 0,7 % sind leicht umbenannt (z. B. «Warm Chicken A La King» ↔ «Chicken a la King»). In einer Stichprobe von 20'000 Rezepten kommen die Zutaten aus H im Median zu 100 % in den Zutatenzeilen von Z vor. Kein Rezept liegt unter 50 %. Die Verknüpfung ist also zuverlässig.

## 2. Wie viele Rezepte sind in beiden enthalten?

| | Anzahl |
| --- | ---: |
| **In beiden Datensätzen** | **490'475** |
| nur in H | 32'042 |
| nur in Z | 2'152 |

Nach Regel 1 bleiben also genug Rezepte übrig. Regel 3 muss nicht gelockert werden.

## 3. In welcher Form stehen Mengen und Einheiten in Z?

Spalte `ingredients_raw`, eine JSON-Liste mit einer Zeile pro Zutat. Insgesamt sind es 4,63 Mio. Zeilen in den gemeinsamen Rezepten. Aufbau: **Menge – Einheit – Zutat, Zusatz**. Die Teile sind durch mehrere Leerzeichen getrennt:

```
"1/4  cup   melted margarine"
"2 (21   ounce) cans   cherry pie filling"
"1   tablespoon    lemons, rind of or 1   tablespoon    lemon, zest of"
"  to taste    salt"
```

**Mengen**
- 93,9 % der Zeilen beginnen mit einer Menge: ganze Zahl (`2`), Bruch (`1/4`), gemischte Zahl (`1 1/2`) oder Dezimalzahl (`0.5`).
- Bereiche: 92'028 Zeilen (`1 -2 tablespoon olive oil`). Mit Unicode-Brüchen (½) gibt es nur 266 Zeilen.
- Ohne Menge (6,1 %): meist `to taste …` (1,2 % aller Zeilen) oder nur ein Name (`salt`, `chocolate shavings`).

**Einheiten** (Wort nach der Menge, häufigste)

| Einheit | Zeilen | | Einheit | Zeilen |
| --- | ---: | --- | --- | ---: |
| cup / cups | 1'341'081 | | can / cans | 99'904 |
| teaspoon(s) | 829'433 | | g | 55'459 |
| tablespoon(s) | 651'516 | | package(s) | 45'819 |
| *keine Einheit (Stückzahl, z. B. «3 egg yolks»)* | 588'086 | | pinch / dash | 39'072 |
| ounce(s) | 166'104 | | ml | 15'545 |
| lb / lbs | 159'353 | | kg | 3'280 |
| large / medium / small | 182'706 | | pint, quart, clove, bunch … | < 10'000 je |

- **Packungsgrössen in Klammern:** 188'712 Zeilen, z. B. `1 (15 ounce) can black beans`. Darin steht fast immer `ounce`, seltener `g`, `lb`, `ml` oder `inch`.
- **Alternativen** in einer Zeile (`1/2 cup cilantro or 1/2 cup mint leaf`) kommen vor. Für die Umrechnung wird nur die erste Menge verwendet.
- Für die Umrechnung nach Gramm/Milliliter sind damit Cups, Löffel, Ounces und Pounds die wichtigsten Einheiten. Cups → Gramm hängt von der Zutat ab. Mein Vorschlag: Cups/Löffel in **Milliliter** umrechnen und nur Ounces/Pounds in **Gramm**.

**Wichtig für später**
- Die Spalte `ingredients` in Z (bereinigte Namen) passt **nicht** zeilenweise zu `ingredients_raw`. Nur bei 26,6 % sind die Listen gleich lang. Grundzutaten wie Salz, Zucker oder Mehl fehlen dort oft. Der Zutatenname für den Abgleich muss deshalb aus `ingredients_raw` selbst gewonnen oder aus `RecipeIngredientParts` (H) genommen werden.
- In H sind `RecipeIngredientQuantities` und `RecipeIngredientParts` nur bei 22 % gleich lang. Das bestätigt die bekannte Schwäche aus der CLAUDE.md.
- `serving_size` in Z hat immer die Form `1 (347 g)`. Ein Portionsgewicht ist bei praktisch allen Rezepten vorhanden, bei 903 steht aber `0 g`.
- **Fahrenheit** kommt in 78'170 Anleitungen vor (z. B. `375°F`).

## 4. Prüfungen der Nährwerte

Basis sind die 490'475 Rezepte, die Regel 1 erfüllen. Ein Rezept kann bei mehreren Prüfungen durchfallen.

**Vollständigkeit (Regel 2)**

| Prüfung | nicht bestanden |
| --- | ---: |
| Nährwerte fehlen | 0 |
| Zubereitungszeit fehlt (`TotalTime` leer oder `PT0S`) | 1'352 (0,28 %) |
| Portionenzahl fehlt (in H **und** Z) | 445 (0,09 %) |

**Plausibilität**

| Prüfung | nicht bestanden | Anteil |
| --- | ---: | ---: |
| 1. Negative Werte | 0 | 0,00 % |
| 2. Teilmengen (total) | 364 | 0,07 % |
|   – gesättigte Fette > Fett | 0 | |
|   – Zucker > Kohlenhydrate | 364 | |
|   – Ballaststoffe > Kohlenhydrate | 0 | |
| 3. Energiebilanz (±20 % oder ±20 kcal) | 7'844 | 1,60 % |
| 4. Über 2'500 kcal pro Portion | 9'734 | 1,98 % |
| 5. Makronährstoffe > Portionsgewicht | 9'075 | 1,85 % |
| **Mindestens eine Prüfung nicht bestanden** | **26'386** | **5,38 %** |

→ **Unter der 10-%-Grenze.** Die durchgefallenen Rezepte können ohne Rückfrage ausgeschlossen werden.

**Beobachtungen**
- **Energiebilanz:** 5'282 der 7'844 durchgefallenen Rezepte enthalten Alkohol (Rum, Wein, Wodka …). Alkohol liefert 7 kcal/g, das fehlt in der Formel. Die meisten davon sind Getränke und fallen ohnehin weg. Bei anderen Grenzwerten fallen so viele Rezepte durch: 25 %/20 kcal → 6'448, 30 %/50 kcal → 4'754. Die vorgeschlagenen 20 % / 20 kcal passen gut.
- **Über 2'500 kcal:** 8'354 der 9'734 Fälle haben in H **keine** Portionenzahl (`RecipeServings` leer, stattdessen nur `RecipeYield`). Dort gelten die Nährwerte offenbar oft für das ganze Rezept, z. B. «Sour Cream Cake» mit 9'383 kcal.
- **Portionsgewicht:** 130 der 9'075 Fälle sind Rezepte mit Portionsgewicht `0 g`. Die übrigen haben unrealistisch kleine Portionen (z. B. «Spice Scones», `1 (4 g)`).

## 5. Welche Kategorien sind Getränke?

Die Kategorien stammen aus `RecipeCategory` (H). Es gibt 311 verschiedene, die vollständige Liste steht in der Konsolenausgabe der Analyse.

| Getränke-Kategorie (wird ausgeschlossen) | in beiden Datensätzen |
| --- | ---: |
| Beverages | 10'254 |
| Smoothies | 3'278 |
| Punch Beverage | 1'577 |
| Shakes | 736 |
| Margarita | 1 |
| **Total** | **15'846** |

- **Zusätzlich gefunden (keine Getränke, aber auch keine Rezepte):** `Bath/Beauty` (20), `Household Cleaner` (18) und `Homeopathy/Remedies` (4). Darunter sind Badesalz und Putzmittel. Vorschlag: ebenfalls ausschliessen.
- 276 Rezepte tragen ein Getränke-Tag, haben aber eine andere Kategorie. Meist sind es `Frozen Desserts` (201) und `Gelatin` (34), also Eis und Wackelpudding. Vorschlag: behalten, weil die Kategorie massgebend ist.

---

## Vorschau auf die Auswahl (zur Einschätzung des Ziels von ~15'000)

| Schritt | übrig |
| --- | ---: |
| Regel 1 (in beiden) | 490'475 |
| + Regel 2 (vollständig und plausibel) | 462'513 |
| + Regel 3 (≥ 5 Bewertungen, Ø ≥ 4) | 58'446 |
| + Regel 5 (ohne Getränke und Nicht-Lebensmittel) | **56'800** |

Damit stehen genug Rezepte für ~15'000 zur Verfügung, und alle Kategoriegruppen sind gut gefüllt. Die häufigsten Kategorien darunter: Dessert 5'568, Lunch/Snacks 4'476, One Dish Meal 4'253, Vegetable 3'557, Breakfast 2'816. Die Zuordnung der 311 Kategorien zu den 5 deutschen Gruppen erstelle ich in Schritt 2 als Vorschlag zur Kontrolle.

---

## Offene Entscheidungen

1. **Portionenzahl:** Bei 171'000 Rezepten fehlt `RecipeServings` in H, nur Z hat dort einen Wert (davon 67'000 mit «1 Portion»). Bei diesen Rezepten sind die Nährwerte häufiger unplausibel.
   - **a) Vorschlag:** Nur Rezepte mit `RecipeServings` in H übernehmen. Es bleiben 36'628 Kandidaten, also immer noch genug.
   - b) Fehlende Werte aus Z ergänzen (56'800 Kandidaten).
2. **Nicht-Lebensmittel** (`Bath/Beauty`, `Household Cleaner`, `Homeopathy/Remedies`) ebenfalls ausschliessen? Vorschlag: ja.
3. **Grenzwerte** der Plausibilitätsprüfung (20 % / 20 kcal / 2'500 kcal) beibehalten? Vorschlag: ja.
4. **Portionsgewicht `0 g`:** als «nicht vorhanden» behandeln, statt die Prüfung dort durchfallen zu lassen? Vorschlag: ja (betrifft 130 Rezepte).

---

## Nachtrag: Stimmen die Portionenzahlen beider Datensätze überein?

Die Nährwerte in H gelten pro Portion bezogen auf `RecipeServings`. Die Zutatenzeilen in Z gehören zu `servings`. Der Portionsrechner geht von der Portionenzahl aus, die zu den Nährwerten gehört.

| | Rezepte | `servings` fehlt in Z | Portionenzahl verschieden |
| --- | ---: | ---: | ---: |
| Verknüpft, mit `RecipeServings` | 319'486 | 12 | 38 (0,01 %) |
| Kandidaten (alle Regeln ausser Regel 4) | 36'642 | 0 | **10** |

Abweichungen gibt es fast nur bei Rezepten, deren Portionenzahl später geändert wurde, z. B. «My Favorite Chocolate Chip Cookies» mit 84 in H und 1 in Z. In diesen Fällen ist nicht klar, welche Zahl zu den Nährwerten gehört. Das Portionsgewicht in Z (`1 (347 g)`) bezieht sich auf die Portionenzahl von Z.

- Alle Portionenzahlen der Kandidaten sind ganzzahlig. Median: 6, 99 % liegen bei ≤ 48.
- 29 Kandidaten haben mehr als 100 Portionen. Meist sind es Guetzli, Glasuren und Gewürzmischungen. Dazu kommen Scherzrezepte wie «Elephant Stew» mit 3'800 Portionen.
