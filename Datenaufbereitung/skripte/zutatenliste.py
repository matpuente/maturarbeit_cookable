"""Zutatenliste zur Kontrolle: die 1'000 häufigsten Grundnamen, mit DeepL ins Deutsche übersetzt.

Voraussetzung: aufbereitung.py wurde ausgeführt (ergebnisse/grundnamen_haeufigkeit.csv).
Aufruf:  ../.venv/bin/python zutatenliste.py            -> mit DeepL-Übersetzung
         ../.venv/bin/python zutatenliste.py --ohne-deepl -> nur englische Liste
Ausgabe: ../ergebnisse/zutatenliste_zur_kontrolle.csv

Bereits übersetzte Namen werden in ergebnisse/deepl_cache.json gespeichert und nie ein
zweites Mal an DeepL geschickt (Zeichenkontingent).
"""
import json
import re
import sys
import urllib.parse
import urllib.request

import pandas as pd

from laden import BASIS

ERGEBNISSE = BASIS / "ergebnisse"
SCHLUESSEL_DATEI = BASIS / "deepl_api_key.txt"
CACHE = ERGEBNISSE / "deepl_cache.json"
AUSGABE = ERGEBNISSE / "zutatenliste_zur_kontrolle.csv"
ANZAHL = 1000

# Grundzutaten (immer vorhanden): Salz, Pfeffer, Wasser, Öl, Zucker, Mehl – Vorschlag, wird von Hand kontrolliert
GRUNDZUTATEN = {
    "salt", "kosher salt", "sea salt", "table salt", "coarse salt",
    "pepper", "black pepper", "ground black pepper", "ground pepper", "fresh black pepper",
    "fresh ground pepper", "fresh ground black pepper", "white pepper", "black peppercorn",
    "water", "cold water", "hot water", "warm water", "boiling water", "ice water", "lukewarm water",
    "oil", "vegetable oil", "olive oil", "extra virgin olive oil", "canola oil", "cooking oil",
    "light olive oil", "salad oil",
    "sugar", "white sugar", "granulated sugar",
    "flour", "all-purpose flour", "plain flour", "white flour", "unbleached all-purpose flour",
}

# Schweizer Begriffe statt bundesdeutscher (CLAUDE.md, Abschnitt 6); ß gibt es in der Schweiz nicht
SCHWEIZ = {"saure Sahne": "Sauerrahm", "Saure Sahne": "Sauerrahm", "Schlagsahne": "Schlagrahm",
           "Sahne": "Rahm", "Feldsalat": "Nüsslisalat", "Paprikaschote": "Peperoni",
           "Brötchen": "Brötli", "Hähnchenbrust": "Pouletbrust", "Hühnerbrust": "Pouletbrust",
           "Hähnchen": "Poulet", "Möhre": "Rüebli", "Zucchini": "Zucchetti", "Soße": "Sauce", "soße": "sauce"}
# Sahne ist weiblich, Rahm männlich: "leichte Sahne" -> "leichter Rahm"
RE_RAHM_ADJEKTIV = re.compile(r"\b(\w+)e (saure Sahne|Saure Sahne|Schlagsahne|Sahne)\b")
# Im US-Englisch ist "green/red pepper" meist Gemüsepaprika, nicht Gewürz
RE_GEMUESEPAPRIKA = re.compile(r"\bbell pepper\b|^(sweet )?(red|green|yellow|orange) (sweet )?pepper$")
DEEPL_URL = "https://api-free.deepl.com/v2/translate"


def schweizerisch(text: str, englisch: str) -> str:
    text = RE_RAHM_ADJEKTIV.sub(lambda m: f"{m.group(1)}er {m.group(2)}", text)
    for de, ch in sorted(SCHWEIZ.items(), key=lambda p: -len(p[0])):  # längere Begriffe zuerst
        text = text.replace(de, ch)
    if RE_GEMUESEPAPRIKA.search(englisch):
        text = text.replace("Paprika", "Peperoni")
    return text.replace("ß", "ss")


def deepl(texte: list, schluessel: str) -> list:
    daten = [("text", t) for t in texte] + [
        ("source_lang", "EN"), ("target_lang", "DE"),
        ("context", "Names of cooking ingredients from recipes."),
    ]
    anfrage = urllib.request.Request(
        DEEPL_URL, data=urllib.parse.urlencode(daten).encode(),
        headers={"Authorization": f"DeepL-Auth-Key {schluessel}"},
    )
    with urllib.request.urlopen(anfrage, timeout=60) as antwort:
        return [t["text"] for t in json.load(antwort)["translations"]]


def main():
    haeufigkeit = pd.read_csv(ERGEBNISSE / "grundnamen_haeufigkeit.csv")
    liste = haeufigkeit.head(ANZAHL).copy()
    liste.insert(0, "englisch", liste.pop("grundname"))
    liste["grundzutat"] = liste.englisch.isin(GRUNDZUTATEN).map({True: "ja", False: "nein"})

    if "--ohne-deepl" not in sys.argv:
        if not SCHLUESSEL_DATEI.exists():
            sys.exit(f"DeepL-Schlüssel fehlt: {SCHLUESSEL_DATEI} anlegen (eine Zeile).")
        schluessel = SCHLUESSEL_DATEI.read_text().strip()
        cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
        offen = [e for e in liste.englisch if e not in cache]
        zeichen = sum(len(e) for e in offen)
        print(f"Übersetze {len(offen)} Namen ({zeichen} Zeichen) mit DeepL …")
        for i in range(0, len(offen), 50):
            teil = offen[i:i + 50]
            cache.update(zip(teil, deepl(teil, schluessel)))
            CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
        liste["deepl"] = liste.englisch.map(cache)
        liste["deutsch"] = [schweizerisch(d, e) for d, e in zip(liste.deepl, liste.englisch)]
    else:
        liste["deepl"] = ""
        liste["deutsch"] = ""

    spalten = ["englisch", "deutsch", "grundzutat", "deepl", "zeilen", "rezepte", "beispielzeile"]
    liste[spalten].to_csv(AUSGABE, index=False, encoding="utf-8-sig")  # utf-8-sig: Umlaute korrekt in Excel/Numbers
    print(f"Geschrieben: {AUSGABE} ({len(liste)} Zeilen)")


if __name__ == "__main__":
    main()
