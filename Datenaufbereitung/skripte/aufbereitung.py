"""Datenaufbereitung (Schritt 2): Auswahl der Rezepte und Erstellung der SQLite-Datei.

Aufruf:  ../.venv/bin/python aufbereitung.py
Ausgabe: ../ergebnisse/rezepte.sqlite
         ../ergebnisse/grundnamen_haeufigkeit.csv  (alle Grundnamen mit Häufigkeit und Beispielzeile)
         ../ergebnisse/aufbereitung_bericht.json
"""
import html
import json
import re
import sqlite3
from collections import Counter, defaultdict

import pandas as pd

from einheiten import ersetze_fahrenheit, metrisch
from grundname import grundnamen
from kandidaten import regel_maske, verknuepfe
from kategorien import gruppe
from laden import BASIS
from zutatenzeile import zerlege

AUSGABE = BASIS / "ergebnisse"
DATENBANK = AUSGABE / "rezepte.sqlite"
QUOTEN = {"Hauptgericht": 6000, "Beilage": 3500, "Dessert": 2500, "Frühstück": 1500, "Snack": 1500}

SCHEMA = """
CREATE TABLE rezept (
    id                  INTEGER PRIMARY KEY,   -- RecipeId von Food.com
    name                TEXT NOT NULL,         -- Englisch, wird in der App übersetzt
    gruppe              TEXT NOT NULL,         -- Frühstück, Hauptgericht, Beilage, Dessert, Snack
    zeit_min            INTEGER NOT NULL,      -- Gesamtzeit in Minuten
    portionen           INTEGER NOT NULL,
    portionsgewicht_g   REAL,
    kalorien            REAL NOT NULL,         -- alle Nährwerte pro Portion
    fett_g              REAL NOT NULL,
    gesaettigte_fette_g REAL NOT NULL,
    cholesterin_mg      REAL NOT NULL,
    natrium_mg          REAL NOT NULL,
    kohlenhydrate_g     REAL NOT NULL,
    ballaststoffe_g     REAL NOT NULL,
    zucker_g            REAL NOT NULL,
    protein_g           REAL NOT NULL,
    anleitung           TEXT NOT NULL,         -- JSON-Liste der Schritte (Englisch, Temperaturen in °C)
    bild_url            TEXT
);
CREATE TABLE zutatenzeile (
    rezept_id           INTEGER NOT NULL REFERENCES rezept(id),
    position            INTEGER NOT NULL,
    original            TEXT NOT NULL,         -- Zeile wie im Datensatz
    menge               REAL,
    menge_bis           REAL,                  -- bei Bereichen ("1-2 cups")
    einheit             TEXT,                  -- vereinheitlichte Originaleinheit (cup, ounce, can …)
    menge_metrisch      REAL,
    menge_bis_metrisch  REAL,
    einheit_metrisch    TEXT,                  -- g, ml, cm oder NULL
    packung_menge       REAL,                  -- "1 (15 ounce) can": 15
    packung_einheit     TEXT,                  -- ounce
    packung_metrisch    REAL,                  -- 425.25
    packung_einheit_metrisch TEXT,             -- g
    groesse             TEXT,                  -- large, medium, small, whole …
    name                TEXT NOT NULL,         -- Name aus der Zeile (Englisch)
    zusatz              TEXT,                  -- z. B. "finely chopped"
    PRIMARY KEY (rezept_id, position)
);
CREATE TABLE zeile_grundname (                 -- eine Zeile kann mehrere Grundnamen haben ("salt and pepper")
    rezept_id           INTEGER NOT NULL,
    position            INTEGER NOT NULL,
    grundname           TEXT NOT NULL,
    PRIMARY KEY (rezept_id, position, grundname),
    FOREIGN KEY (rezept_id, position) REFERENCES zutatenzeile(rezept_id, position)
);
CREATE INDEX idx_zeile_grundname ON zeile_grundname(grundname);
CREATE INDEX idx_rezept_gruppe_zeit ON rezept(gruppe, zeit_min);
CREATE TABLE info (schluessel TEXT PRIMARY KEY, wert TEXT);
"""


def minuten(iso: str) -> int:
    m = re.fullmatch(r"P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", iso or "")
    if not m:
        raise ValueError(f"Unbekanntes Zeitformat: {iso}")
    tage, stunden, minuten_, sekunden = (int(x) if x else 0 for x in m.groups())
    return tage * 1440 + stunden * 60 + minuten_ + round(sekunden / 60)


def auswahl() -> pd.DataFrame:
    g = verknuepfe()
    k = g[regel_maske(g)].copy()
    k["gruppe"] = [gruppe(t, c) for t, c in zip(k.tags, k.RecipeCategory)]
    teile = []
    for name, quote in QUOTEN.items():
        s = k[k.gruppe == name].sort_values(["ReviewCount", "AggregatedRating", "RecipeId"],
                                            ascending=[False, False, True])
        if len(s) < quote:
            raise RuntimeError(f"Zu wenige Kandidaten für {name}: {len(s)} < {quote}")
        teile.append(s.head(quote))
    return pd.concat(teile), k


def main():
    bericht = {}
    gewaehlt, kandidaten = auswahl()
    bericht["kandidaten"] = len(kandidaten)
    bericht["kandidaten_pro_gruppe"] = kandidaten.gruppe.value_counts().to_dict()
    bericht["gewaehlt"] = len(gewaehlt)
    bericht["min_bewertungen_pro_gruppe"] = gewaehlt.groupby("gruppe").ReviewCount.min().astype(int).to_dict()

    AUSGABE.mkdir(exist_ok=True)
    DATENBANK.unlink(missing_ok=True)
    db = sqlite3.connect(DATENBANK)
    db.executescript(SCHEMA)

    grund_zaehler, grund_beispiel = Counter(), {}
    grund_rezepte = defaultdict(set)
    fahrenheit_ersetzt = 0
    zeilen_total = zeilen_metrisch = 0
    for r in gewaehlt.itertuples():
        schritte = []
        for schritt in r.RecipeInstructions:
            neu, n = ersetze_fahrenheit(html.unescape(schritt))
            fahrenheit_ersetzt += n
            schritte.append(neu)
        bilder = r.Images if r.Images is not None else []
        db.execute(
            "INSERT INTO rezept VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (int(r.RecipeId), html.unescape(r.Name).strip(), r.gruppe, minuten(r.TotalTime),
             int(r.RecipeServings), None if pd.isna(r.portionsgewicht_g) else float(r.portionsgewicht_g),
             r.Calories, r.FatContent, r.SaturatedFatContent, r.CholesterolContent, r.SodiumContent,
             r.CarbohydrateContent, r.FiberContent, r.SugarContent, r.ProteinContent,
             json.dumps(schritte, ensure_ascii=False), bilder[0] if len(bilder) else None),
        )
        for pos, roh in enumerate(r.ingredients_raw):
            z = zerlege(html.unescape(roh))
            if not z.name:
                continue
            zeilen_total += 1
            m, e = metrisch(z.menge, z.einheit)
            mb, _ = metrisch(z.menge_bis, z.einheit)
            pm, pe = metrisch(z.packung_menge, z.packung_einheit)
            zeilen_metrisch += m is not None
            original = re.sub(r"\s+", " ", html.unescape(roh)).strip()
            db.execute(
                "INSERT INTO zutatenzeile VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (int(r.RecipeId), pos, original, z.menge, z.menge_bis, z.einheit, m, mb, e,
                 z.packung_menge, z.packung_einheit, pm, pe, z.groesse, z.name, z.zusatz or None),
            )
            for gn in dict.fromkeys(grundnamen(z.name)):
                db.execute("INSERT INTO zeile_grundname VALUES (?,?,?)", (int(r.RecipeId), pos, gn))
                grund_zaehler[gn] += 1
                grund_rezepte[gn].add(int(r.RecipeId))
                grund_beispiel.setdefault(gn, original)

    db.executemany("INSERT INTO info VALUES (?,?)", [
        ("quelle", "Food.com (Kaggle: irkaal/foodcom-recipes-and-reviews, "
                   "realalexanderwei/food-com-recipes-with-ingredients-and-tags)"),
        ("anzahl_rezepte", str(len(gewaehlt))),
        ("erstellt", pd.Timestamp.now().strftime("%Y-%m-%d")),
    ])
    db.commit()
    db.execute("VACUUM")
    db.close()

    haeufigkeit = pd.DataFrame(
        [(gn, n, len(grund_rezepte[gn]), grund_beispiel[gn]) for gn, n in grund_zaehler.most_common()],
        columns=["grundname", "zeilen", "rezepte", "beispielzeile"],
    )
    haeufigkeit.to_csv(AUSGABE / "grundnamen_haeufigkeit.csv", index=False)

    top1000 = set(haeufigkeit.grundname.head(1000))
    bericht["zutatenzeilen"] = zeilen_total
    bericht["zeilen_mit_metrischer_menge_anteil"] = round(zeilen_metrisch / zeilen_total, 4)
    bericht["grundnamen_verschieden"] = len(haeufigkeit)
    bericht["abdeckung_top1000_zeilen"] = round(
        haeufigkeit[haeufigkeit.grundname.isin(top1000)].zeilen.sum() / haeufigkeit.zeilen.sum(), 4)
    bericht["fahrenheit_ersetzt"] = fahrenheit_ersetzt
    bericht["datenbank_mb"] = round(DATENBANK.stat().st_size / 1e6, 1)
    (AUSGABE / "aufbereitung_bericht.json").write_text(json.dumps(bericht, ensure_ascii=False, indent=2))
    print(json.dumps(bericht, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
