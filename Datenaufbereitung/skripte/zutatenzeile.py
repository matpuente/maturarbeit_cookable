"""Zerlegt eine Zutatenzeile aus `ingredients_raw` (zweiter Datensatz) in Menge, Einheit, Name und Zusatz.

Beispiel: "1 (15   ounce) can   black beans, rinsed and drained"
  -> menge=1, menge_bis=None, packung=(15, "ounce"), einheit="can",
     name="black beans", zusatz="rinsed and drained"
"""
import re
from dataclasses import dataclass
from fractions import Fraction
from typing import Optional

UNICODE_BRUECHE = {"½": " 1/2", "¼": " 1/4", "¾": " 3/4", "⅓": " 1/3", "⅔": " 2/3", "⅛": " 1/8"}

# Schreibweisen -> einheitlicher Name der Einheit
EINHEITEN = {
    "cup": "cup", "cups": "cup", "c": "cup",
    "teaspoon": "teaspoon", "teaspoons": "teaspoon", "tsp": "teaspoon",
    "tablespoon": "tablespoon", "tablespoons": "tablespoon", "tbsp": "tablespoon",
    "fluid ounce": "fluid ounce", "fluid ounces": "fluid ounce", "fl oz": "fluid ounce",
    "ounce": "ounce", "ounces": "ounce", "oz": "ounce",
    "lb": "pound", "lbs": "pound", "pound": "pound", "pounds": "pound",
    "g": "g", "gram": "g", "grams": "g", "kg": "kg",
    "ml": "ml", "l": "l", "liter": "l", "liters": "l", "litre": "l", "litres": "l",
    "pint": "pint", "pints": "pint", "quart": "quart", "quarts": "quart",
    "gallon": "gallon", "gallons": "gallon",
    "pinch": "pinch", "pinches": "pinch", "dash": "dash", "dashes": "dash",
    "drop": "drop", "drops": "drop",
    "clove": "clove", "cloves": "clove", "slice": "slice", "slices": "slice",
    "can": "can", "cans": "can", "package": "package", "packages": "package",
    "jar": "jar", "jars": "jar", "bottle": "bottle", "bottles": "bottle",
    "box": "box", "boxes": "box", "bag": "bag", "bags": "bag",
    "container": "container", "containers": "container", "envelope": "envelope",
    "envelopes": "envelope", "packet": "packet", "packets": "packet",
    "stick": "stick", "sticks": "stick", "bunch": "bunch", "bunches": "bunch",
    "head": "head", "heads": "head", "sprig": "sprig", "sprigs": "sprig",
    "stalk": "stalk", "stalks": "stalk", "leaf": "leaf", "leaves": "leaf",
    "piece": "piece", "pieces": "piece", "cube": "cube", "cubes": "cube",
    "square": "square", "squares": "square", "fillet": "fillet", "fillets": "fillet",
    "loaf": "loaf", "loaves": "loaf", "carton": "carton", "cartons": "carton",
    "inch": "inch",
}
# Grössenangaben sind keine Einheit, sondern gehören zum Zusatz ("2 large eggs" = 2 Stück)
GROESSEN = {"large", "medium", "small", "whole", "extra large", "jumbo"}

ZAHL = r"(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"
RE_MENGE = re.compile(rf"^({ZAHL})(?:\s*(?:-|to)\s*({ZAHL}))?\s*(.*)$")
RE_PACKUNG = re.compile(rf"^\(({ZAHL})(?:\s*-\s*{ZAHL})?\s*([a-z ]+?)\)\s*(.*)$", re.I)
EINHEIT_SCHLUESSEL = sorted(EINHEITEN, key=len, reverse=True)
RE_EINHEIT = re.compile(r"^(" + "|".join(re.escape(e) for e in EINHEIT_SCHLUESSEL) + r")\.?(?=\s|$)\s*(.*)$", re.I)
# "whole wheat", "whole grain" usw. sind Teil des Namens, keine Grössenangabe
RE_GROESSE = re.compile(
    r"^(" + "|".join(sorted(GROESSEN, key=len, reverse=True)) + r")\b(?!\s+(?:wheat|grain|milk|kernel))\s*(.*)$",
    re.I,
)


@dataclass
class Zutatenzeile:
    roh: str
    menge: Optional[float] = None
    menge_bis: Optional[float] = None
    packung_menge: Optional[float] = None
    packung_einheit: Optional[str] = None
    einheit: Optional[str] = None
    groesse: Optional[str] = None
    name: str = ""
    zusatz: str = ""
    nach_belieben: bool = False


def zahl(text: str) -> float:
    return float(sum(Fraction(teil) for teil in text.split()))


def zerlege(roh: str) -> Zutatenzeile:
    z = Zutatenzeile(roh=roh)
    text = roh
    for zeichen, ersatz in UNICODE_BRUECHE.items():
        text = text.replace(zeichen, ersatz)
    text = re.sub(r"\s+", " ", text).strip()

    if text.lower().startswith("to taste"):
        z.nach_belieben = True
        text = text[8:].strip()

    m = RE_MENGE.match(text)
    if m:
        z.menge = zahl(m.group(1))
        z.menge_bis = zahl(m.group(2)) if m.group(2) else None
        text = m.group(3)
        p = RE_PACKUNG.match(text)
        if p:
            z.packung_menge = zahl(p.group(1))
            z.packung_einheit = EINHEITEN.get(p.group(2).strip().lower(), p.group(2).strip().lower())
            text = p.group(3)
    e = RE_EINHEIT.match(text)
    if e and (z.menge is not None or z.packung_menge is not None):
        z.einheit = EINHEITEN[e.group(1).lower()]
        text = e.group(2)
    g = RE_GROESSE.match(text)
    if g:
        z.groesse = g.group(1).lower()
        text = g.group(2)

    # Alternativen ("… or 1/2 cup mint") und Zusatz nach dem ersten Komma abtrennen
    text = re.split(r"\s+or\s+\d", text, maxsplit=1)[0]
    name, _, zusatz = text.partition(",")
    klammern = re.findall(r"\(([^)]*)\)", name)
    name = re.sub(r"\([^)]*\)", " ", name)
    z.name = re.sub(r"\s+", " ", name).strip(" -.;:").lower()
    z.zusatz = ", ".join([k.strip() for k in klammern] + ([zusatz.strip()] if zusatz.strip() else []))
    return z
