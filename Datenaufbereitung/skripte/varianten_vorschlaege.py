"""Schlägt für Grundnamen ausserhalb der Zutatenliste einen bestehenden deutschen Begriff vor.

Betrifft nur Grundnamen, die in mindestens MIN_REZEPTE Rezepten vorkommen (z. B. "penne" -> Penne-Nudeln).
zutatenliste_uebernehmen.py liest die kontrollierte Datei und ordnet die Varianten den deutschen
Begriffen zu; neue deutsche Begriffe entstehen dabei nicht.

Aufruf:  ../.venv/bin/python varianten_vorschlaege.py [--neu]
Ausgabe: ../ergebnisse/varianten_vorschlaege.csv  (wird ohne --neu nicht überschrieben)
Danach:  zutatenliste_uebernehmen.py

Spalten: "deutsch" ist mit dem Vorschlag vorausgefüllt und kann geändert werden;
"uebernehmen" = ja/nein. Vorschläge über Einzahl/Mehrzahl, Weglassen von Zusatzwörtern oder von Hand sind sicherer (ja),
Vorschläge über einen enthaltenen Namen unsicherer (nein, zum Prüfen).
"""
import csv
import re
import sys

import pandas as pd

from laden import BASIS
from zusammenfassen_vorschlaege import basis

ERGEBNISSE = BASIS / "ergebnisse"
LISTE = ERGEBNISSE / "zutatenliste_zur_kontrolle.csv"
AUSGABE = ERGEBNISSE / "varianten_vorschlaege.csv"
MIN_REZEPTE = 3

# Von Hand: Fälle, die die automatische Suche nicht erkennt
VON_HAND = {
    "penne": "penne pasta",
    "penne rigate": "penne pasta",
    "whole wheat penne": "penne pasta",
    "hot cooked penne": "penne pasta",
    "dry penne pasta": "penne pasta",
    "uncooked penne": "penne pasta",
}


def lies_liste() -> pd.DataFrame:
    text = LISTE.read_text(encoding="utf-8-sig")
    trennzeichen = csv.Sniffer().sniff(text[:5000], delimiters=",;\t").delimiter
    return pd.read_csv(LISTE, encoding="utf-8-sig", sep=trennzeichen, dtype=str, keep_default_na=False)


def enthaltener_name(grundname: str, alle: set) -> str:
    """Längster Listenname, der als ganze Wortfolge im Grundnamen vorkommt ("uncooked dry penne pasta" -> "penne pasta")."""
    treffer = [e for e in alle if re.search(rf"(^| ){re.escape(e)}( |$)", grundname)]
    return max(treffer, key=len) if treffer else ""


def einzahl_mehrzahl(grundname: str, alle: set) -> str:
    """"olive" -> "olives", "kidney beans" -> "kidney bean" (die Vereinheitlichung lässt manche Mehrzahl stehen)."""
    for form in (grundname + "s", grundname + "es", grundname[:-1] if grundname.endswith("s") else ""):
        if form and form in alle:
            return form
    return ""


def main():
    if AUSGABE.exists() and "--neu" not in sys.argv:
        sys.exit(f"{AUSGABE.name} existiert schon (evtl. von Hand kontrolliert). Mit --neu überschreiben.")
    liste = lies_liste()
    de = dict(zip(liste.englisch, liste.deutsch))
    alle = set(de)
    haeufigkeit = pd.read_csv(ERGEBNISSE / "grundnamen_haeufigkeit.csv")
    ausserhalb = haeufigkeit[~haeufigkeit.grundname.isin(alle) & (haeufigkeit.rezepte >= MIN_REZEPTE)]

    zeilen = []
    for r in ausserhalb.itertuples():
        if r.grundname in VON_HAND:
            ziel, art = VON_HAND[r.grundname], "von Hand"
        elif ziel := einzahl_mehrzahl(r.grundname, alle):
            art = "Einzahl/Mehrzahl"
        elif ziel := basis(r.grundname, alle):
            art = "Zusatzwort weggelassen"
        elif ziel := enthaltener_name(r.grundname, alle):
            art = "Name enthalten (prüfen)"
        else:
            art = ""
        zeilen.append({
            "englisch": r.grundname,
            "deutsch": de.get(ziel, ""),
            "uebernehmen": "ja" if art in ("von Hand", "Einzahl/Mehrzahl", "Zusatzwort weggelassen") else "nein",
            "art": art,
            "vorschlag_englisch": ziel,
            "rezepte": r.rezepte,
            "beispielzeile": r.beispielzeile,
        })
    # Sichere Vorschläge zuerst, dann unsichere, dann die ohne Vorschlag; innerhalb nach Häufigkeit
    tabelle = pd.DataFrame(zeilen)
    tabelle["_stufe"] = tabelle.uebernehmen.eq("nein").astype(int) + tabelle.deutsch.eq("").astype(int)
    tabelle = tabelle.sort_values(["_stufe", "rezepte"], ascending=[True, False]).drop(columns="_stufe")
    tabelle.to_csv(AUSGABE, sep=";", index=False, encoding="utf-8-sig")
    print(f"{len(tabelle)} Grundnamen, davon mit Vorschlag: {(tabelle.deutsch != '').sum()}, "
          f"Empfehlung ja: {(tabelle.uebernehmen == 'ja').sum()}")
    print(tabelle.art.value_counts().to_dict())


if __name__ == "__main__":
    main()
