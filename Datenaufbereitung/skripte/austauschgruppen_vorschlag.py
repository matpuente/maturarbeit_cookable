"""Entwurf der Austauschgruppen: Zutaten, die sich in den meisten Rezepten gegenseitig ersetzen lassen
(z. B. Penne, Spaghetti und Fusilli in der Gruppe «Pasta»).

Aufruf:  ../.venv/bin/python austauschgruppen_vorschlag.py [--neu]
Ausgabe: ../ergebnisse/austauschgruppen.csv  (wird ohne --neu nicht überschrieben)

Eine Zeile pro deutschem Begriff der Zutatenliste. Die Spalte "austauschgruppe" ist für die
vorgeschlagenen Gruppen vorausgefüllt und wird von Hand kontrolliert: Gruppen können umbenannt,
ergänzt oder gelöscht werden (leer = keine Gruppe). Jeder Begriff gehört zu höchstens einer Gruppe.
zutatenliste_uebernehmen.py liest die Datei und speichert die Gruppe in zutat.austauschgruppe.
"""
import sys

import pandas as pd

from laden import BASIS
from zusammenfassen_anwenden import lies

ERGEBNISSE = BASIS / "ergebnisse"
LISTE = ERGEBNISSE / "zutatenliste_zur_kontrolle.csv"
AUSGABE = ERGEBNISSE / "austauschgruppen.csv"

VORSCHLAG = {
    "Pasta": ["Nudeln", "Penne-Nudeln", "Spaghetti", "dünne Spaghetti", "Linguine", "Fettuccine",
              "Fettuccine-Nudeln", "Engelshaar-Nudeln", "Fliegennudeln", "Muschel-Nudeln", "Muschelnudeln",
              "Ziti-Nudeln", "Makkaroni", "Winkelmakkaroni"],
    "Reis": ["Reis", "weisser Reis", "Langkornreis", "langkörniger weisser Reis", "Basmatireis", "Jasminreis"],
    "Zwiebeln": ["Zwiebel", "gelbe Zwiebel", "weisse Zwiebel", "süsse Zwiebel", "Vidalia-Zwiebel",
                 "spanische Zwiebel", "rote Zwiebel"],
    "Peperoni": ["Peperoni", "rote Peperoni", "grüne Peperoni", "gelbe Peperoni"],
    "Walnüsse/Pekannüsse": ["Walnuss", "Pekannuss"],
    "Blattsalat": ["Salat", "Eisbergsalat", "Römersalat"],
    "Bouillon": ["Hühnerbouillon", "Gemüsebouillon"],
    "Heller Essig": ["Essig", "weisser Essig", "destillierter weisser Essig", "Weinessig", "Weissweinessig",
                     "Apfelessig"],
    "Rosinen": ["Rosinen", "goldene Rosine"],
    "Cheddar": ["Cheddar-Käse", "alter Cheddar-Käse"],
}


def main():
    if AUSGABE.exists() and "--neu" not in sys.argv:
        sys.exit(f"{AUSGABE.name} existiert schon (evtl. von Hand kontrolliert). Mit --neu überschreiben.")
    liste, _ = lies(LISTE)
    gruppe = {begriff: name for name, begriffe in VORSCHLAG.items() for begriff in begriffe}
    fehlend = sorted(set(gruppe) - set(liste.deutsch))
    if fehlend:
        sys.exit(f"Begriffe nicht in der Zutatenliste: {fehlend}")

    tabelle = (
        liste.assign(rezepte=pd.to_numeric(liste.rezepte, errors="coerce").fillna(0).astype(int))
        .groupby("deutsch", sort=False)
        .agg(rezepte=("rezepte", "sum"), englische_namen=("englisch", ", ".join))
        .reset_index()
    )
    tabelle.insert(1, "austauschgruppe", tabelle.deutsch.map(gruppe).fillna(""))
    tabelle["_ohne"] = tabelle.austauschgruppe.eq("")
    tabelle = tabelle.sort_values(["_ohne", "austauschgruppe", "rezepte"], ascending=[True, True, False])
    tabelle.drop(columns="_ohne").to_csv(AUSGABE, sep=";", index=False, encoding="utf-8-sig")
    print(f"{len(tabelle)} Begriffe, davon {len(gruppe)} in {len(VORSCHLAG)} Gruppen vorgeschlagen.")


if __name__ == "__main__":
    main()
