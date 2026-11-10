"""Übernimmt die von Hand kontrollierte Zutatenliste in die SQLite-Datei.

Voraussetzung: aufbereitung.py wurde ausgeführt, ergebnisse/zutatenliste_zur_kontrolle.csv ist kontrolliert.
Aufruf:  ../.venv/bin/python zutatenliste_uebernehmen.py
Kann beliebig oft ausgeführt werden; die Zutatentabellen werden jedes Mal neu erstellt.

Zusätzlich gelesen (falls vorhanden, beide von Hand kontrolliert):
  varianten_vorschlaege.csv – weitere englische Namen (uebernehmen = ja) für bestehende deutsche Begriffe
  austauschgruppen.csv      – Gruppe austauschbarer Zutaten pro deutschem Begriff (z. B. «Pasta»)

Neue Tabellen:
  zutat           – ein Eintrag pro deutschem Begriff (Suche und Autovervollständigung), mit Austauschgruppe
  zutat_variante  – englische Grundnamen, die zu einem deutschen Begriff gehören
  rezept_zutat    – welche Zutaten der Liste ein Rezept braucht (inkl. Grundzutaten, siehe zutat.grundzutat)
  rezept.anzahl_ohne_liste – Anzahl verschiedener Grundnamen eines Rezepts, die nicht in der
                  Zutatenliste stehen (gelten bei der Sortierung immer als fehlend)
"""
import csv
import sqlite3
import sys

import pandas as pd

from laden import BASIS

ERGEBNISSE = BASIS / "ergebnisse"
DATENBANK = ERGEBNISSE / "rezepte.sqlite"
LISTE = ERGEBNISSE / "zutatenliste_zur_kontrolle.csv"
VARIANTEN = ERGEBNISSE / "varianten_vorschlaege.csv"
GRUPPEN = ERGEBNISSE / "austauschgruppen.csv"

SCHEMA = """
DROP TABLE IF EXISTS rezept_zutat;
DROP TABLE IF EXISTS zutat_variante;
DROP TABLE IF EXISTS zutat;
CREATE TABLE zutat (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,      -- deutscher Begriff
    grundzutat  INTEGER NOT NULL,          -- 1 = gilt immer als vorhanden
    haeufigkeit INTEGER NOT NULL,          -- Anzahl Rezepte, für die Reihenfolge der Vorschläge
    austauschgruppe TEXT                   -- z. B. "Pasta"; Zutaten derselben Gruppe ersetzen sich gegenseitig
);
CREATE TABLE zutat_variante (
    grundname   TEXT PRIMARY KEY,          -- englischer Grundname aus zeile_grundname
    zutat_id    INTEGER NOT NULL REFERENCES zutat(id)
);
CREATE TABLE rezept_zutat (
    rezept_id   INTEGER NOT NULL REFERENCES rezept(id),
    zutat_id    INTEGER NOT NULL REFERENCES zutat(id),
    PRIMARY KEY (rezept_id, zutat_id)
);
CREATE INDEX idx_rezept_zutat_zutat ON rezept_zutat(zutat_id);
"""


def lies_csv(pfad) -> pd.DataFrame:
    text = pfad.read_text(encoding="utf-8-sig")
    trennzeichen = csv.Sniffer().sniff(text[:5000], delimiters=",;\t").delimiter
    tabelle = pd.read_csv(pfad, encoding="utf-8-sig", sep=trennzeichen, dtype=str, keep_default_na=False)
    return tabelle.apply(lambda spalte: spalte.str.strip())


def lies_varianten(liste: pd.DataFrame) -> pd.DataFrame:
    """Kontrollierte Varianten als zusätzliche Zeilen (englisch, deutsch, grundzutat)."""
    if not VARIANTEN.exists():
        return liste.iloc[0:0]
    varianten = lies_csv(VARIANTEN)
    varianten["uebernehmen"] = varianten.uebernehmen.str.lower()
    gewaehlt = varianten[(varianten.uebernehmen == "ja") & ~varianten.englisch.isin(liste.englisch)]
    fehler = []
    if not varianten.uebernehmen.isin(["ja", "nein"]).all():
        fehler.append("Spalte 'uebernehmen' darf nur ja oder nein enthalten")
    if (gewaehlt.deutsch == "").any():
        fehler.append(f"Ohne deutschen Begriff: {gewaehlt.englisch[gewaehlt.deutsch == ''].tolist()}")
    unbekannt = sorted(set(gewaehlt.deutsch) - set(liste.deutsch) - {""})
    if unbekannt:
        fehler.append(f"Nicht in der Zutatenliste: {unbekannt}")
    if fehler:
        sys.exit("varianten_vorschlaege.csv fehlerhaft:\n- " + "\n- ".join(fehler))
    markierung = liste.groupby("deutsch").grundzutat.first()
    return pd.DataFrame({"englisch": gewaehlt.englisch, "deutsch": gewaehlt.deutsch,
                         "grundzutat": gewaehlt.deutsch.map(markierung)})


def lies_gruppen(liste: pd.DataFrame) -> dict:
    """Deutscher Begriff -> Austauschgruppe."""
    if not GRUPPEN.exists():
        return {}
    gruppen = lies_csv(GRUPPEN)
    unbekannt = sorted(set(gruppen.deutsch) - set(liste.deutsch))
    doppelt = gruppen.deutsch[gruppen.deutsch.duplicated()].tolist()
    if unbekannt or doppelt:
        sys.exit(f"austauschgruppen.csv fehlerhaft:\n- Nicht in der Zutatenliste: {unbekannt}\n- Doppelt: {doppelt}")
    return {d: g for d, g in zip(gruppen.deutsch, gruppen.austauschgruppe) if g}


def lies_liste() -> pd.DataFrame:
    liste = lies_csv(LISTE)
    liste["englisch"] = liste.englisch.str.strip()
    liste["deutsch"] = liste.deutsch.str.strip()
    liste["grundzutat"] = liste.grundzutat.str.strip().str.lower()

    fehler = []
    if liste.englisch.duplicated().any():
        fehler.append(f"Doppelte englische Namen: {liste.englisch[liste.englisch.duplicated()].tolist()}")
    if (liste.deutsch == "").any():
        fehler.append(f"Ohne deutschen Begriff: {liste.englisch[liste.deutsch == ''].tolist()}")
    if not liste.grundzutat.isin(["ja", "nein"]).all():
        fehler.append(f"grundzutat nicht ja/nein: {liste.englisch[~liste.grundzutat.isin(['ja', 'nein'])].tolist()}")
    gemischt = liste.groupby("deutsch").grundzutat.nunique()
    if (gemischt > 1).any():
        fehler.append(f"Grundzutat uneinheitlich bei: {gemischt[gemischt > 1].index.tolist()}")
    if fehler:
        sys.exit("Zutatenliste fehlerhaft:\n- " + "\n- ".join(fehler))
    return liste


def main():
    liste = lies_liste()
    gruppen = lies_gruppen(liste)
    varianten = lies_varianten(liste)
    db = sqlite3.connect(DATENBANK)
    db.executescript(SCHEMA)
    spalten = [r[1] for r in db.execute("PRAGMA table_info(rezept)")]
    if "anzahl_ohne_liste" not in spalten:
        db.execute("ALTER TABLE rezept ADD COLUMN anzahl_ohne_liste INTEGER NOT NULL DEFAULT 0")

    unbekannt = set(liste.englisch) - {r[0] for r in db.execute("SELECT DISTINCT grundname FROM zeile_grundname")}
    if unbekannt:
        sys.exit(f"Englische Namen kommen in keinem Rezept vor: {sorted(unbekannt)[:20]}")

    for name, gruppe in liste.groupby("deutsch", sort=False):
        db.execute("INSERT INTO zutat (name, grundzutat, haeufigkeit, austauschgruppe) VALUES (?, ?, 0, ?)",
                   (name, int(gruppe.grundzutat.iloc[0] == "ja"), gruppen.get(name)))
    ids = dict(db.execute("SELECT name, id FROM zutat"))
    alle = pd.concat([liste[["englisch", "deutsch"]], varianten[["englisch", "deutsch"]]])
    db.executemany("INSERT INTO zutat_variante VALUES (?, ?)",
                   [(e, ids[d]) for e, d in zip(alle.englisch, alle.deutsch)])

    db.executescript("""
        INSERT INTO rezept_zutat
        SELECT DISTINCT zg.rezept_id, z.id
        FROM zeile_grundname zg
        JOIN zutat_variante v ON v.grundname = zg.grundname
        JOIN zutat z ON z.id = v.zutat_id;

        UPDATE zutat SET haeufigkeit = (
            SELECT COUNT(DISTINCT zg.rezept_id) FROM zeile_grundname zg
            JOIN zutat_variante v ON v.grundname = zg.grundname WHERE v.zutat_id = zutat.id);

        UPDATE rezept SET anzahl_ohne_liste =
            (SELECT COUNT(DISTINCT zg.grundname) FROM zeile_grundname zg
             LEFT JOIN zutat_variante v ON v.grundname = zg.grundname
             WHERE zg.rezept_id = rezept.id AND v.grundname IS NULL);
    """)
    db.execute("INSERT OR REPLACE INTO info VALUES ('zutatenliste', ?)",
               (pd.Timestamp(LISTE.stat().st_mtime, unit="s").strftime("%Y-%m-%d"),))
    db.commit()

    zahlen = {
        "zutaten (deutsch)": db.execute("SELECT COUNT(*) FROM zutat").fetchone()[0],
        "davon grundzutaten": db.execute("SELECT COUNT(*) FROM zutat WHERE grundzutat = 1").fetchone()[0],
        "englische varianten": db.execute("SELECT COUNT(*) FROM zutat_variante").fetchone()[0],
        "davon aus varianten_vorschlaege.csv": len(varianten),
        "zutaten in austauschgruppen": db.execute(
            "SELECT COUNT(*) FROM zutat WHERE austauschgruppe IS NOT NULL").fetchone()[0],
        "rezept_zutat": db.execute("SELECT COUNT(*) FROM rezept_zutat").fetchone()[0],
        "median anzahl_ohne_liste": db.execute(
            "SELECT anzahl_ohne_liste FROM rezept ORDER BY anzahl_ohne_liste LIMIT 1 OFFSET 7500").fetchone()[0],
    }
    db.execute("VACUUM")
    db.close()
    for k, v in zahlen.items():
        print(f"{k}: {v}")


if __name__ == "__main__":
    main()
