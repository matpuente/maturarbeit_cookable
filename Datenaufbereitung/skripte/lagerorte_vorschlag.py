"""Entwurf des Standard-Lagerorts pro Zutat (Kühlschrank, Tiefkühler oder Vorratsschrank).

Die App schlägt diesen Lagerort beim Hinzufügen einer Zutat vor; eine eigene Wahl des Nutzers hat Vorrang.

Aufruf:  ../.venv/bin/python lagerorte_vorschlag.py [--neu]
Ausgabe: ../ergebnisse/lagerorte.csv  (wird ohne --neu nicht überschrieben)

Eine Zeile pro deutschem Begriff. Die Spalte "lagerort" (Kühlschrank / Tiefkühler / Vorratsschrank) ist
mit Regeln anhand der englischen Namen vorausgefüllt und wird von Hand kontrolliert.
zutatenliste_uebernehmen.py speichert sie in zutat.lagerort.
"""
import re
import sys

import pandas as pd

from laden import BASIS
from zusammenfassen_anwenden import lies

ERGEBNISSE = BASIS / "ergebnisse"
LISTE = ERGEBNISSE / "zutatenliste_zur_kontrolle.csv"
AUSGABE = ERGEBNISSE / "lagerorte.csv"


def wort(*woerter: str) -> re.Pattern:
    return re.compile(r"\b(" + "|".join(woerter) + r")\b")


TIEFKUEHLER = wort("frozen", "ice cream", "sorbet", "sherbet", "puff pastry", "phyllo", "filo")
# Haltbare Formen gehören in den Vorratsschrank, auch wenn das Grundprodukt gekühlt wird
HALTBAR = wort(
    "dried", "dry", "powder", "powdered", "canned", "can", "condensed", "evaporated", "cream of", "soup", "mix",
    "bouillon", "broth", "stock", "base", "flakes", "extract", "chips", "crackers?", "cereal", "flour",
    "noodles?", "pasta", "chocolate", "butterscotch", "peanut butter", "apple butter", "butternut",
    "coconut milk", "cream of tartar", "creamed corn", "cream-style", "marshmallow", "crumbs", "seasoning",
    "sauce", "ketchup", "vinegar", "oil", "syrup", "jam", "jelly", "preserves", "in water", "in oil",
    "ground (red|black|white) pepper", "red pepper flakes", "cayenne", "buns?", "rolls", "salt", "consomme",
    "jell-o", "gelatin", "roasted red peppers?",
)
# Ausnahmen: trotz eines Worts aus HALTBAR gekühlt
GEKUEHLT_TROTZDEM = wort("pesto", "alfredo sauce", "refrigerated", "cream cheese", "sour cream", "tortellini",
                         "ravioli", "fresh pasta", "egg roll wrap", "wonton wrap")
KUEHLSCHRANK = wort(
    # Milchprodukte und Eier
    "milk", "buttermilk", "butter", "margarine", "cream", "half-and-half", "cheese", "parmesan", "mozzarella",
    "feta", "ricotta", "yogurt", "yoghurt", "eggs?", "egg whites?", "egg yolks?", "tofu", "mascarpone",
    # Fleisch und Fisch
    "chicken", "beef", "pork", "turkey", "lamb", "veal", "ham", "bacon", "sausages?", "chorizo", "pepperoni",
    "salami", "prosciutto", "hot dogs?", "meat", "steak", "chops?", "roast", "fillets?", "breast", "thighs?",
    "wings?", "drumsticks?", "hamburger", "salmon", "shrimp", "prawns?", "fish", "cod", "tilapia",
    "halibut", "crab", "crabmeat", "lobster", "scallops?", "mussels", "clams", "catfish", "trout",
    # Frisches Gemüse, Kräuter, Obst
    "lettuce", "spinach", "arugula", "kale", "cabbage", "broccoli", "cauliflower", "carrots?", "celery",
    "cucumbers?", "zucchini", "bell peppers?", "red peppers?", "green peppers?", "mushrooms?", "asparagus",
    "green beans", "snow peas", "sugar snap peas", "leeks?", "radish(es)?", "sprouts", "parsley", "cilantro",
    "basil", "mint", "dill", "chives", "coriander leaf", "fresh", "strawberr(y|ies)", "blueberr(y|ies)",
    "raspberr(y|ies)", "blackberr(y|ies)", "grapes", "cherries", "jalapenos?", "green onions?", "scallions?",
    # Gekühlte Fertigprodukte
    "mayonnaise", "salsa", "hummus", "tortellini", "crescent", "biscuits", "pie crust", "pizza dough",
)


def lagerort(englische_namen: list) -> str:
    stimmen = {"Kühlschrank": 0, "Tiefkühler": 0, "Vorratsschrank": 0}
    for name in englische_namen:
        if TIEFKUEHLER.search(name):
            stimmen["Tiefkühler"] += 1
        elif GEKUEHLT_TROTZDEM.search(name):
            stimmen["Kühlschrank"] += 1
        elif HALTBAR.search(name):
            stimmen["Vorratsschrank"] += 1
        elif KUEHLSCHRANK.search(name):
            stimmen["Kühlschrank"] += 1
        else:
            stimmen["Vorratsschrank"] += 1
    # Mehrheit der englischen Varianten; bei Gleichstand der erste Name (= häufigster)
    beste = max(stimmen.values())
    kandidaten = [ort for ort, n in stimmen.items() if n == beste]
    return kandidaten[0] if len(kandidaten) == 1 else lagerort(englische_namen[:1])


def main():
    if AUSGABE.exists() and "--neu" not in sys.argv:
        sys.exit(f"{AUSGABE.name} existiert schon (evtl. von Hand kontrolliert). Mit --neu überschreiben.")
    liste, _ = lies(LISTE)
    tabelle = (
        liste.assign(rezepte=pd.to_numeric(liste.rezepte, errors="coerce").fillna(0).astype(int))
        .groupby("deutsch", sort=False)
        .agg(rezepte=("rezepte", "sum"), englische_namen=("englisch", list))
        .reset_index()
    )
    tabelle.insert(1, "lagerort", tabelle.englische_namen.map(lagerort))
    tabelle["englische_namen"] = tabelle.englische_namen.map(", ".join)
    tabelle = tabelle.sort_values(["lagerort", "rezepte"], ascending=[True, False])
    tabelle.to_csv(AUSGABE, sep=";", index=False, encoding="utf-8-sig")
    print(f"{len(tabelle)} Begriffe:", tabelle.lagerort.value_counts().to_dict())


if __name__ == "__main__":
    main()
