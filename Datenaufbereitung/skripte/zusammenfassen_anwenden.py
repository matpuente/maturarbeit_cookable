"""Übernimmt die kontrollierten Vorschläge (uebernehmen = ja) in die Zutatenliste.

Aufruf:  ../.venv/bin/python zusammenfassen_anwenden.py
Danach:  ../.venv/bin/python zutatenliste_uebernehmen.py

Vor der Änderung wird eine Sicherung der Zutatenliste angelegt. Der übernommene Begriff erhält
die Grundzutat-Markierung des Zielbegriffs.
"""
import csv
import shutil
import sys

import pandas as pd

from laden import BASIS

ERGEBNISSE = BASIS / "ergebnisse"
LISTE = ERGEBNISSE / "zutatenliste_zur_kontrolle.csv"
VORSCHLAEGE = ERGEBNISSE / "zusammenfassen_vorschlaege.csv"


def lies(pfad) -> tuple:
    text = pfad.read_text(encoding="utf-8-sig")
    trennzeichen = csv.Sniffer().sniff(text[:5000], delimiters=",;\t").delimiter
    return pd.read_csv(pfad, encoding="utf-8-sig", sep=trennzeichen, dtype=str, keep_default_na=False), trennzeichen


def main():
    liste, trennzeichen = lies(LISTE)
    vorschlaege, _ = lies(VORSCHLAEGE)
    vorschlaege["uebernehmen"] = vorschlaege.uebernehmen.str.strip().str.lower()
    if not vorschlaege.uebernehmen.isin(["ja", "nein"]).all():
        sys.exit("Spalte 'uebernehmen' darf nur ja oder nein enthalten.")
    gewaehlt = vorschlaege[vorschlaege.uebernehmen == "ja"]

    begriffe = set(liste.deutsch)
    fehlend = set(gewaehlt.vorschlag_deutsch.str.strip()) - begriffe
    if fehlend:
        sys.exit(f"Zielbegriffe nicht in der Zutatenliste: {sorted(fehlend)}")

    sicherung = LISTE.with_name(f"{LISTE.stem}_vor_zusammenfassen_{pd.Timestamp.now():%Y-%m-%d_%H%M}.csv")
    shutil.copy(LISTE, sicherung)

    markierung = liste.groupby("deutsch").grundzutat.first().to_dict()
    ziel = dict(zip(gewaehlt.englisch, gewaehlt.vorschlag_deutsch.str.strip()))
    maske = liste.englisch.isin(ziel)
    liste.loc[maske, "deutsch"] = liste.loc[maske, "englisch"].map(ziel)
    liste.loc[maske, "grundzutat"] = liste.loc[maske, "deutsch"].map(markierung)
    liste.to_csv(LISTE, sep=trennzeichen, index=False, encoding="utf-8-sig")

    print(f"Sicherung: {sicherung.name}")
    print(f"{maske.sum()} Varianten zusammengefasst, jetzt {liste.deutsch.nunique()} deutsche Begriffe.")


if __name__ == "__main__":
    main()
