"""Sucht in der kontrollierten Zutatenliste Varianten, die man zusammenfassen könnte.

Eine Variante ist ein englischer Name, der nach Entfernen von Zusatzwörtern (fresh, boneless,
low-fat …) einem anderen Namen der Liste entspricht, aber einen anderen deutschen Begriff hat.
Beispiel: "boneless skinless chicken breast" -> "chicken breast" -> Pouletbrust.

Aufruf:  ../.venv/bin/python zusammenfassen_vorschlaege.py
Ausgabe: ../ergebnisse/zusammenfassen_vorschlaege.csv
         Spalte "uebernehmen" ist mit einer Empfehlung vorausgefüllt (ja/nein) und wird von Hand kontrolliert.
         Danach: zusammenfassen_anwenden.py
"""
import csv
import re

import pandas as pd

from laden import BASIS

ERGEBNISSE = BASIS / "ergebnisse"
LISTE = ERGEBNISSE / "zutatenliste_zur_kontrolle.csv"
AUSGABE = ERGEBNISSE / "zusammenfassen_vorschlaege.csv"

# Zusatzwörter, die beim Vergleich ignoriert werden (längere zuerst)
ZUSATZ = sorted([
    "boneless", "skinless", "fresh", "large", "small", "medium", "whole", "plain", "pure", "raw",
    "ripe", "extra virgin", "virgin", "fillet", "half", "chunk", "crumbled", "leaf", "ground",
    "dried", "frozen", "canned", "low-fat", "lowfat", "low fat", "light", "lite", "nonfat",
    "non-fat", "fat-free", "fat free", "reduced-fat", "reduced fat", "reduced-sodium",
    "low sodium", "low-sodium", "unsalted", "salted", "cooked", "uncooked", "hot", "cold",
    "sweetened", "unsweetened", "prepared", "instant", "toasted", "roasted", "skim",
    "part-skim", "lean", "sharp", "mild", "baby", "refrigerated", "italian", "weed",
], key=len, reverse=True)
RE_ZUSATZ = re.compile(r"\b(" + "|".join(map(re.escape, ZUSATZ)) + r")\b")

# Empfehlung "nein": anderes Produkt, nicht einfach austauschbar
NEIN = {
    "ground beef": "Hackfleisch ist ein eigenes Produkt",
    "ground turkey": "Hackfleisch ist ein eigenes Produkt",
    "ground pork": "Hackfleisch ist ein eigenes Produkt",
    "ground chicken": "Hackfleisch ist ein eigenes Produkt",
    "ground ginger": "Ingwerpulver ≠ frischer Ingwer",
    "ground mustard": "Senfpulver ≠ Senf",
    "ground coriander": "Koriandersamen (Pulver) ≠ Korianderblätter",
    "ground red pepper": "Cayennepfeffer ≠ Peperoni",
    "roasted red pepper": "eingelegte geröstete Peperoni sind ein Fertigprodukt",
    "sweetened condensed milk": "Kondensmilch ≠ Milch",
    "condensed milk": "Kondensmilch ≠ Milch",
    "condensed tomato soup": "Konzentrat ≠ Tomatensuppe",
    "instant onion": "Trockenprodukt ≠ frische Zwiebel",
    "dried onion": "Trockenprodukt ≠ frische Zwiebel",
    "dried onion flakes": "Trockenprodukt ≠ frische Zwiebel",
    "dried cranberry": "Trockenfrüchte ≠ frische Beeren",
    "frozen whipped topping": "Fertigprodukt (Cool Whip) ≠ Schlagrahm",
    "italian sausage": "bestimmte Wurstsorte",
    "italian bread": "bestimmte Brotsorte",
}


def lies_liste() -> pd.DataFrame:
    text = LISTE.read_text(encoding="utf-8-sig")
    trennzeichen = csv.Sniffer().sniff(text[:5000], delimiters=",;\t").delimiter
    return pd.read_csv(LISTE, encoding="utf-8-sig", sep=trennzeichen, dtype=str, keep_default_na=False)


def basis(englisch: str, alle: set) -> str:
    """Kürzester Name der Liste, der durch Weglassen von Zusatzwörtern entsteht ("chicken breast half" -> "chicken breast")."""
    woerter = englisch.split(" ")
    kandidaten = []
    for maske in range(1, 2 ** len(woerter)):
        weg = [w for i, w in enumerate(woerter) if maske >> i & 1]
        rest = " ".join(w for i, w in enumerate(woerter) if not maske >> i & 1)
        if rest and rest in alle and all(RE_ZUSATZ.fullmatch(w) for w in weg):
            kandidaten.append(rest)
    # Mehrwortige Zusätze wie "low fat" einzeln nicht erkennbar -> zusätzlich ganze Ersetzung prüfen
    ersetzt = re.sub(r"\s+", " ", RE_ZUSATZ.sub(" ", englisch)).strip()
    if ersetzt in alle and ersetzt != englisch:
        kandidaten.append(ersetzt)
    kandidaten = [k for k in kandidaten if k != englisch]
    # möglichst wenig weglassen: "chicken breast half" -> "chicken breast", nicht "chicken"
    return max(kandidaten, key=len) if kandidaten else ""


def main():
    liste = lies_liste()
    de = dict(zip(liste.englisch, liste.deutsch))
    rezepte = dict(zip(liste.englisch, liste.rezepte.astype(int)))
    alle = set(de)

    zeilen = []
    for e in liste.englisch:
        b = basis(e, alle)
        if not b or de[b] == de[e]:
            continue
        # Ketten auflösen: "fresh basil leaf" -> "basil leaf" -> "basil"; nicht über eine
        # "nein"-Stufe hinweg ("lean ground beef" -> "ground beef", nicht weiter zu "beef")
        ziel = b
        while ziel not in NEIN and basis(ziel, alle) and basis(ziel, alle) != ziel:
            ziel = basis(ziel, alle)
        if de[ziel] == de[e]:
            continue
        grund = NEIN.get(e, "")
        zeilen.append({
            "englisch": e,
            "deutsch_jetzt": de[e],
            "vorschlag_deutsch": de[ziel],
            "uebernehmen": "nein" if grund else "ja",
            "begruendung_nein": grund,
            "rezepte": rezepte[e],
            "basis_englisch": ziel,
        })

    vorschlaege = pd.DataFrame(zeilen).sort_values("rezepte", ascending=False)
    vorschlaege.to_csv(AUSGABE, sep=";", index=False, encoding="utf-8-sig")
    print(f"{len(vorschlaege)} Vorschläge, davon Empfehlung ja: {(vorschlaege.uebernehmen == 'ja').sum()}")
    print(f"Geschrieben: {AUSGABE}")


if __name__ == "__main__":
    main()
