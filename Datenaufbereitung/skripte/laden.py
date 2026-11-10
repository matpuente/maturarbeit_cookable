"""Gemeinsame Ladefunktionen für die beiden Food.com-Datensätze."""
import json
from pathlib import Path

import pandas as pd

BASIS = Path(__file__).resolve().parent.parent
DATEN = BASIS / "daten"
HAUPT_PARQUET = DATEN / "foodcom_irkaal" / "recipes.parquet"
ZWEIT_CSV = DATEN / "foodcom_wei" / "recipes_ingredients.csv"

NAEHRWERTE = [
    "Calories", "FatContent", "SaturatedFatContent", "CholesterolContent",
    "SodiumContent", "CarbohydrateContent", "FiberContent", "SugarContent",
    "ProteinContent",
]


def lade_haupt() -> pd.DataFrame:
    df = pd.read_parquet(HAUPT_PARQUET)
    df["RecipeId"] = df["RecipeId"].astype("int64")
    return df


def lade_zweit() -> pd.DataFrame:
    df = pd.read_csv(ZWEIT_CSV)
    for spalte in ("ingredients", "ingredients_raw", "steps", "tags"):
        df[spalte] = df[spalte].map(_json_liste)
    return df


def _json_liste(wert):
    if not isinstance(wert, str):
        return []
    try:
        return json.loads(wert)
    except json.JSONDecodeError:
        return None
