"""Verknüpfte Rezepte laden und die Auswahlregeln 1–3, 5 und 6 anwenden (Regel 4 folgt in Schritt 2)."""
import numpy as np
import pandas as pd

from laden import NAEHRWERTE, lade_haupt, lade_zweit

GETRAENKE_KATEGORIEN = ["Beverages", "Punch Beverage", "Smoothies", "Shakes", "Margarita"]
NICHT_LEBENSMITTEL = ["Bath/Beauty", "Household Cleaner", "Homeopathy/Remedies"]


def bereinige_zweit(zweit: pd.DataFrame) -> pd.DataFrame:
    vergleich = zweit.assign(
        _ir=zweit.ingredients_raw.map(str), _st=zweit.steps.map(str), _tg=zweit.tags.map(str),
    )[["id", "name", "description", "_ir", "_st", "servings", "serving_size", "_tg"]].astype(str)
    doppelt = vergleich[vergleich.id.duplicated(keep=False)]
    abweichend = doppelt.groupby("id").nunique().gt(1).any(axis=1)
    zweit = zweit[~zweit.id.isin(abweichend[abweichend].index)]
    return zweit[zweit.ingredients_raw.notna()].drop_duplicates("id")


def verknuepfe() -> pd.DataFrame:
    """Regel 1: Rezepte, die in beiden Datensätzen enthalten sind."""
    g = lade_haupt().merge(bereinige_zweit(lade_zweit()), left_on="RecipeId", right_on="id")
    gewicht = pd.to_numeric(g.serving_size.str.extract(r"\((\d+(?:\.\d+)?)\s*g\)")[0], errors="coerce")
    g["portionsgewicht_g"] = gewicht.where(gewicht > 0)
    return g


def regel_maske(g: pd.DataFrame) -> pd.Series:
    vollstaendig = (
        g[NAEHRWERTE].notna().all(axis=1)
        & g.TotalTime.notna() & (g.TotalTime != "PT0S")
        & g.RecipeServings.notna()
        & (g.RecipeServings == g.servings)
        & (g.RecipeServings <= 100)
    )
    berechnet = 4 * g.CarbohydrateContent + 4 * g.ProteinContent + 9 * g.FatContent
    plausibel = (
        ~(g[NAEHRWERTE] < 0).any(axis=1)
        & (g.SaturatedFatContent <= g.FatContent)
        & (g.SugarContent <= g.CarbohydrateContent)
        & (g.FiberContent <= g.CarbohydrateContent)
        & ((berechnet - g.Calories).abs() <= np.maximum(0.20 * g.Calories, 20))
        & (g.Calories <= 2500)
        & ~(g.portionsgewicht_g.notna()
            & (g.FatContent + g.CarbohydrateContent + g.ProteinContent > g.portionsgewicht_g))
    )
    bewertet = (g.ReviewCount >= 5) & (g.AggregatedRating >= 4)
    kategorie_ok = ~g.RecipeCategory.isin(GETRAENKE_KATEGORIEN + NICHT_LEBENSMITTEL)
    return vollstaendig & plausibel & bewertet & kategorie_ok
