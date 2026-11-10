"""Vereinheitlicht den Namen einer Zutatenzeile zu einem oder mehreren Grundnamen.

"fresh garlic cloves, minced" -> Name "fresh garlic cloves" -> ["fresh garlic clove"]
"salt & freshly ground black pepper" -> ["salt", "black pepper"]
"""
import re

# Wörter, die nur die Zubereitung oder den Zustand beschreiben, nicht die Zutat
ZUBEREITUNG = [
    "chopped", "finely", "coarsely", "roughly", "diced", "minced", "sliced", "thinly", "thickly",
    "grated", "shredded", "softened", "melted", "crushed", "freshly", "fresh ground", "cubed",
    "peeled", "beaten", "lightly", "halved", "quartered", "drained", "rinsed", "packed",
    "firmly", "trimmed", "seeded", "deveined", "julienned", "mashed", "sifted", "divided",
    "optional", "room temperature", "at room temperature", "well", "cut", "into", "pieces",
    "bite-size", "bite-sized", "to taste", "plus", "more", "extra", "about", "approximately",
]
RE_ZUBEREITUNG = re.compile(r"\b(" + "|".join(sorted(map(re.escape, ZUBEREITUNG), key=len, reverse=True)) + r")\b")

# Endet auf "s", ist aber keine Mehrzahl
KEINE_MEHRZAHL = {
    "hummus", "couscous", "asparagus", "molasses", "swiss", "brussels", "grits", "citrus",
    "lemongrass", "bitters", "schnapps", "series", "species", "harissa", "mascarpone",
    "watercress", "cress", "bass", "hibiscus", "octopus", "chives",
    "nuts", "oats", "greens", "herbs", "sprinkles", "noodles", "beans", "peas", "lentils",
    "chickpeas", "raisins", "capers", "oreos", "grapes", "berries", "chips", "flakes",
    "crumbs", "breadcrumbs", "seeds", "olives", "sprouts", "cornflakes", "rolled oats",
}
UNREGELMAESSIG = {"leaves": "leaf", "halves": "half", "loaves": "loaf", "knives": "knife",
                  "potatoes": "potato", "tomatoes": "tomato", "mangoes": "mango"}

# "salt and pepper" usw.: nur trennen, wenn ein Teil Salz oder Pfeffer ist
RE_SALZ_PFEFFER = re.compile(r"\s+(?:and|&|or)\s+")
SALZ_PFEFFER = re.compile(r"^(salt|kosher salt|sea salt|pepper|black pepper|white pepper|ground pepper|ground black pepper)$")


def einzahl(wort: str) -> str:
    if wort in UNREGELMAESSIG:
        return UNREGELMAESSIG[wort]
    if wort in KEINE_MEHRZAHL or len(wort) <= 3:
        return wort
    if wort.endswith("ies"):
        return wort[:-3] + "y"
    if wort.endswith(("ches", "shes", "sses", "xes")):
        return wort[:-2]
    if wort.endswith("s") and not wort.endswith(("ss", "us", "is")):
        return wort[:-1]
    return wort


def _bereinige(name: str) -> str:
    name = name.lower().replace("’", "'")
    name = RE_ZUBEREITUNG.sub(" ", name)
    name = re.sub(r"[^a-z&'\- ]", " ", name)
    name = re.sub(r"\s+-\s+|\s+-|-\s+", " ", name)
    name = re.sub(r"\s+", " ", name).strip(" -'&")
    name = re.sub(r"^(of|and|or|for)\s+|\s+(of|and|or|for)$", "", name).strip()
    if not name:
        return ""
    if name in KEINE_MEHRZAHL:
        return name
    woerter = name.split(" ")
    woerter[-1] = einzahl(woerter[-1])
    return " ".join(woerter)


def grundnamen(name: str) -> list:
    bereinigt = _bereinige(name)
    if not bereinigt:
        return []
    teile = RE_SALZ_PFEFFER.split(bereinigt)
    if len(teile) == 2 and any(SALZ_PFEFFER.match(t) for t in teile):
        return [t for t in (_bereinige(t) for t in teile) if t]
    return [bereinigt]
