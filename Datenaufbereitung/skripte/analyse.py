"""Datenanalyse (Schritt 1): Verknüpfung, Zutatenzeilen, Nährwertprüfungen, Getränke.

Aufruf:  ../.venv/bin/python analyse.py
Ausgabe: ../ergebnisse/analyse.json und Konsolenausgabe
"""
import json
import re
from collections import Counter

import numpy as np
import pandas as pd

from laden import BASIS, NAEHRWERTE, lade_haupt, lade_zweit

AUSGABE = BASIS / "ergebnisse"
GETRAENKE_KATEGORIEN = ["Beverages", "Punch Beverage", "Smoothies", "Shakes", "Margarita"]
NICHT_LEBENSMITTEL = ["Bath/Beauty", "Household Cleaner", "Homeopathy/Remedies"]

ergebnis = {}


def ausgabe(schluessel, wert):
    ergebnis[schluessel] = wert
    print(f"{schluessel}: {wert}")


# ---------------------------------------------------------------- Laden
haupt = lade_haupt()
zweit_roh = lade_zweit()

# ---------------------------------------------------------------- 1. Verknüpfung
ausgabe("haupt_zeilen", len(haupt))
ausgabe("haupt_ids_eindeutig", int(haupt.RecipeId.nunique()))
ausgabe("zweit_zeilen", len(zweit_roh))
ausgabe("zweit_ids_eindeutig", int(zweit_roh.id.nunique()))
ausgabe("zweit_json_fehler", int(zweit_roh.ingredients_raw.isna().sum()))

vergleich = zweit_roh.assign(
    _ir=zweit_roh.ingredients_raw.map(str), _st=zweit_roh.steps.map(str),
    _tg=zweit_roh.tags.map(str),
)[["id", "name", "description", "_ir", "_st", "servings", "serving_size", "_tg"]].astype(str)
doppelt = vergleich[vergleich.id.duplicated(keep=False)]
abweichend = doppelt.groupby("id").nunique().gt(1).any(axis=1)
ausgabe("zweit_doppelte_ids", int(doppelt.id.nunique()))
ausgabe("zweit_doppelte_ids_mit_abweichendem_inhalt", int(abweichend.sum()))

# Doppelte IDs mit unterschiedlichem Inhalt verwerfen, sonst erste Zeile behalten
zweit = zweit_roh[~zweit_roh.id.isin(abweichend[abweichend].index)]
zweit = zweit[zweit.ingredients_raw.notna()].drop_duplicates("id")

gemeinsam = haupt.merge(zweit, left_on="RecipeId", right_on="id", how="inner")
ausgabe("gemeinsame_rezepte", len(gemeinsam))
ausgabe("nur_haupt", int((~haupt.RecipeId.isin(zweit.id)).sum()))
ausgabe("nur_zweit", int((~zweit.id.isin(haupt.RecipeId)).sum()))


def norm(s):
    return s.fillna("").str.lower().str.replace(r"[^a-z0-9]+", " ", regex=True).str.strip()


name_gleich = norm(gemeinsam.Name) == norm(gemeinsam.name)
ausgabe("name_identisch_anteil", round(float(name_gleich.mean()), 4))
ausgabe("name_beispiele_abweichend",
        gemeinsam.loc[~name_gleich, ["RecipeId", "Name", "name"]].head(8).values.tolist())


# Zutaten-Überschneidung als Plausibilitätsprüfung der Verknüpfung
def zutaten_ueberlappung(zeile):
    a = {str(x).lower() for x in (zeile.RecipeIngredientParts if zeile.RecipeIngredientParts is not None else [])}
    b = " ".join(zeile.ingredients_raw).lower()
    if not a:
        return np.nan
    return sum(1 for x in a if x in b) / len(a)


stichprobe = gemeinsam.sample(20000, random_state=1)
ueberlappung = stichprobe.apply(zutaten_ueberlappung, axis=1)
ausgabe("zutaten_ueberlappung_median", round(float(ueberlappung.median()), 3))
ausgabe("zutaten_ueberlappung_unter_50pct_anteil", round(float((ueberlappung < 0.5).mean()), 4))

# ---------------------------------------------------------------- 3. Zutatenzeilen
EINHEITEN = {
    "cup", "cups", "teaspoon", "teaspoons", "tablespoon", "tablespoons", "ounce", "ounces",
    "lb", "lbs", "pound", "pounds", "g", "kg", "ml", "liter", "liters", "l", "pint", "pints",
    "quart", "quarts", "gallon", "gallons", "dash", "dashes", "pinch", "pinches", "clove",
    "cloves", "can", "cans", "package", "packages", "jar", "jars", "bottle", "bottles",
    "slice", "slices", "stick", "sticks", "head", "heads", "bunch", "bunches", "sprig",
    "sprigs", "drop", "drops", "fluid", "inch", "envelope", "envelopes", "box", "boxes",
    "bag", "bags", "carton", "cartons", "container", "containers", "loaf", "loaves",
    "piece", "pieces", "packet", "packets", "stalk", "stalks", "leaf", "leaves", "cube",
    "cubes", "square", "squares", "large", "medium", "small", "whole", "fillet", "fillets",
}
MENGE = r"(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"
RE_MENGE = re.compile(rf"^({MENGE})(?:\s*-\s*({MENGE}))?\s+(.*)$")
RE_PACKUNG = re.compile(r"^\((\d+(?:\.\d+)?(?:\s*-\s*\d+(?:\.\d+)?)?)\s*([a-z]+)\)\s*(.*)$")

zeilen = [re.sub(r"\s+", " ", z).strip() for liste in gemeinsam.ingredients_raw for z in liste]
ausgabe("zutatenzeilen_total", len(zeilen))

mit_menge = bereich = packung = unicode_bruch = 0
einheit_zaehler, packung_einheit = Counter(), Counter()
ohne_menge_beispiele, packung_beispiele, bereich_beispiele = [], [], []
for z in zeilen:
    if re.search(r"[½¼¾⅓⅔⅛]", z):
        unicode_bruch += 1
    m = RE_MENGE.match(z)
    if not m:
        if len(ohne_menge_beispiele) < 15 and z:
            ohne_menge_beispiele.append(z)
        continue
    mit_menge += 1
    if m.group(2):
        bereich += 1
        if len(bereich_beispiele) < 5:
            bereich_beispiele.append(z)
    rest = m.group(3)
    p = RE_PACKUNG.match(rest)
    if p:
        packung += 1
        packung_einheit[p.group(2)] += 1
        if len(packung_beispiele) < 6:
            packung_beispiele.append(z)
        rest = p.group(3)
    erstes = rest.split(" ")[0].lower().strip(".,") if rest else ""
    einheit_zaehler[erstes if erstes in EINHEITEN else "(keine Einheit / Stückzahl)"] += 1

ausgabe("zeilen_mit_fuehrender_menge_anteil", round(mit_menge / len(zeilen), 4))
ausgabe("zeilen_mit_mengenbereich", bereich)
ausgabe("zeilen_mit_packungsgroesse_in_klammern", packung)
ausgabe("zeilen_mit_unicode_bruch", unicode_bruch)
ausgabe("einheiten_top40", einheit_zaehler.most_common(40))
ausgabe("packungsgroesse_einheiten", packung_einheit.most_common(10))
ausgabe("beispiele_ohne_menge", ohne_menge_beispiele)
ausgabe("beispiele_packung", packung_beispiele)
ausgabe("beispiele_bereich", bereich_beispiele)

laengen_gleich = (gemeinsam.ingredients_raw.map(len) == gemeinsam.ingredients.map(lambda x: -1 if x is None else len(x)))
ausgabe("anzahl_zeilen_gleich_anzahl_zutatennamen_anteil", round(float(laengen_gleich.mean()), 4))
teile_laenge = gemeinsam.RecipeIngredientParts.map(lambda x: 0 if x is None else len(x))
mengen_laenge = gemeinsam.RecipeIngredientQuantities.map(lambda x: 0 if x is None else len(x))
ausgabe("haupt_mengen_und_teile_gleich_lang_anteil", round(float((teile_laenge == mengen_laenge).mean()), 4))

# Portionsgewicht
gewicht = pd.to_numeric(gemeinsam.serving_size.str.extract(r"\((\d+(?:\.\d+)?)\s*g\)")[0], errors="coerce")
gemeinsam["portionsgewicht_g"] = gewicht
ausgabe("portionsgewicht_vorhanden", int(gewicht.notna().sum()))
ausgabe("portionsgewicht_null", int((gewicht == 0).sum()))
servings_gleich = gemeinsam.RecipeServings == gemeinsam.servings
ausgabe("portionen_beide_gleich_anteil", round(float(servings_gleich[gemeinsam.RecipeServings.notna() & gemeinsam.servings.notna()].mean()), 4))

# Temperaturen in Anleitungen
anleitung = gemeinsam.RecipeInstructions.map(lambda x: " ".join(x) if x is not None else "")
ausgabe("anleitungen_mit_fahrenheit", int(anleitung.str.contains(r"\d\s*°?\s*(?:degrees?\s*)?F\b", regex=True).sum()))

# ---------------------------------------------------------------- 4. Nährwerte
g = gemeinsam
pruefung = pd.DataFrame(index=g.index)
pruefung["naehrwerte_fehlen"] = g[NAEHRWERTE].isna().any(axis=1)
pruefung["zeit_fehlt"] = g.TotalTime.isna() | (g.TotalTime == "PT0S")
pruefung["portionen_fehlen"] = g.RecipeServings.isna() & g.servings.isna()
pruefung["p1_negativ"] = (g[NAEHRWERTE] < 0).any(axis=1)
pruefung["p2_teilmengen"] = (
    (g.SaturatedFatContent > g.FatContent)
    | (g.SugarContent > g.CarbohydrateContent)
    | (g.FiberContent > g.CarbohydrateContent)
)
pruefung["p2a_gesfett_gt_fett"] = g.SaturatedFatContent > g.FatContent
pruefung["p2b_zucker_gt_kh"] = g.SugarContent > g.CarbohydrateContent
pruefung["p2c_faser_gt_kh"] = g.FiberContent > g.CarbohydrateContent
berechnet = 4 * g.CarbohydrateContent + 4 * g.ProteinContent + 9 * g.FatContent
abweichung = (berechnet - g.Calories).abs()
pruefung["p3_energiebilanz"] = abweichung > np.maximum(0.20 * g.Calories, 20)
pruefung["p4_ueber_2500kcal"] = g.Calories > 2500
makro_g = g.FatContent + g.CarbohydrateContent + g.ProteinContent
pruefung["p5_portionsgewicht"] = g.portionsgewicht_g.notna() & (makro_g > g.portionsgewicht_g)

basis = len(g)
ausgabe("pruef_basis_regel1", basis)
ausgabe("pruef_einzeln", {k: [int(v), round(100 * v / basis, 2)] for k, v in pruefung.sum().items()})
plaus = ["p1_negativ", "p2_teilmengen", "p3_energiebilanz", "p4_ueber_2500kcal", "p5_portionsgewicht"]
irgendeine = pruefung[plaus].any(axis=1)
ausgabe("plausibilitaet_mind_eine_nicht_bestanden", [int(irgendeine.sum()), round(100 * irgendeine.mean(), 2)])

# Sensitivität der Energiebilanz
sens = {}
for pct in (0.15, 0.20, 0.25, 0.30):
    for kcal in (20, 50):
        f = abweichung > np.maximum(pct * g.Calories, kcal)
        sens[f"{int(pct*100)}% / {kcal} kcal"] = [int(f.sum()), round(100 * f.mean(), 2)]
ausgabe("energiebilanz_sensitivitaet", sens)
# Alkohol erklärt oft fehlende Kalorien
alkohol = g.RecipeIngredientParts.map(lambda x: x is not None and any(
    re.search(r"\b(rum|vodka|wine|beer|whiskey|bourbon|tequila|brandy|gin|liqueur|kahlua|sherry)\b", str(i).lower()) for i in x))
ausgabe("energiebilanz_durchgefallen_mit_alkohol", int((pruefung.p3_energiebilanz & alkohol).sum()))

# ---------------------------------------------------------------- 5. Getränke
kat = g.RecipeCategory.fillna("(keine)")
ausgabe("getraenke_kategorien_gemeinsam", {k: int((kat == k).sum()) for k in GETRAENKE_KATEGORIEN})
ausgabe("nicht_lebensmittel_kategorien_gemeinsam", {k: int((kat == k).sum()) for k in NICHT_LEBENSMITTEL})
ist_getraenk_kat = kat.isin(GETRAENKE_KATEGORIEN)
tag_getraenk = g.tags.map(lambda t: any(x in ("beverages", "cocktails", "smoothies", "shakes", "punch") for x in t))
kw_getraenk = g.Keywords.map(lambda k: k is not None and any(x in ("Beverages", "Smoothies", "Shakes", "Punch Beverage") for x in k))
ausgabe("getraenk_tag_aber_andere_kategorie", int((tag_getraenk & ~ist_getraenk_kat).sum()))
ausgabe("getraenk_tag_aber_andere_kategorie_top",
        kat[tag_getraenk & ~ist_getraenk_kat].value_counts().head(10).to_dict())
ausgabe("getraenk_keyword_aber_andere_kategorie", int((kw_getraenk & ~ist_getraenk_kat).sum()))

# ---------------------------------------------------------------- Vorschau Auswahl
bestanden = ~(pruefung[["naehrwerte_fehlen", "zeit_fehlt", "portionen_fehlen"] + plaus].any(axis=1))
bewertung = (g.ReviewCount >= 5) & (g.AggregatedRating >= 4)
kein_getraenk = ~ist_getraenk_kat & ~kat.isin(NICHT_LEBENSMITTEL)
ausgabe("vorschau_regel1_2", int(bestanden.sum()))
ausgabe("vorschau_regel1_2_3", int((bestanden & bewertung).sum()))
ausgabe("vorschau_regel1_2_3_5", int((bestanden & bewertung & kein_getraenk).sum()))
ausgabe("vorschau_kategorien_top25",
        kat[bestanden & bewertung & kein_getraenk].value_counts().head(25).to_dict())

AUSGABE.mkdir(exist_ok=True)
(AUSGABE / "analyse.json").write_text(json.dumps(ergebnis, ensure_ascii=False, indent=2, default=str))
