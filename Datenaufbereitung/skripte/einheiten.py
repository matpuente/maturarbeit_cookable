"""Umrechnung amerikanischer Masseinheiten in Gramm, Milliliter und Grad Celsius."""
import re
from typing import Optional, Tuple

# Einheit -> (Faktor, metrische Einheit)
NACH_METRISCH = {
    "cup": (240.0, "ml"),
    "tablespoon": (15.0, "ml"),
    "teaspoon": (5.0, "ml"),
    "fluid ounce": (30.0, "ml"),
    "pint": (473.0, "ml"),
    "quart": (946.0, "ml"),
    "gallon": (3785.0, "ml"),
    "l": (1000.0, "ml"),
    "ml": (1.0, "ml"),
    "ounce": (28.35, "g"),
    "pound": (453.6, "g"),
    "kg": (1000.0, "g"),
    "g": (1.0, "g"),
    "inch": (2.54, "cm"),
}


def metrisch(menge: Optional[float], einheit: Optional[str]) -> Tuple[Optional[float], Optional[str]]:
    """Gibt (Menge, Einheit) metrisch zurück oder (None, None), wenn die Einheit keine Masseinheit ist."""
    if menge is None or einheit not in NACH_METRISCH:
        return None, None
    faktor, ziel = NACH_METRISCH[einheit]
    return round(menge * faktor, 2), ziel


def celsius(fahrenheit: float) -> int:
    """Auf 5 °C gerundet, wie in Rezepten üblich."""
    return int(round((fahrenheit - 32) * 5 / 9 / 5) * 5)


# 350°F, 350 °F, 350 degrees F, 350 deg F, 350F, 350-375°F, "350 degrees" (ohne Einheit, typisch US).
# Eine nachfolgende Celsius-Angabe in Klammern ("400F (200C)") wird mitersetzt.
_ZAHL = r"(\d{2,3})"
_GRAD = r"(?:\s*-?\s*(?:°|º|˚|degrees?\b|deg\b\.?))+"
RE_FAHRENHEIT = re.compile(
    rf"(?<![\d.]){_ZAHL}(?:\s*(?:-|to|or)\s*{_ZAHL})?"
    rf"(?:{_GRAD}\s*F(?:ahrenheit)?\b|\s*F\b|{_GRAD}(?!\s*C\b|\s*Celsius))"
    r"(?:\s*\(\s*\d{2,3}\s*(?:°|º|degrees?)?\s*C\s*\))?",
    re.I,
)


def ersetze_fahrenheit(text: str) -> Tuple[str, int]:
    """Ersetzt Fahrenheit-Angaben durch °C. Gibt den neuen Text und die Anzahl Ersetzungen zurück."""
    anzahl = 0
    # Falsch kodiertes Gradzeichen im Datensatz ("350Â°F")
    text = text.replace("Ã‚Â°", "°").replace("Â°", "°")

    def ersetze(m):
        nonlocal anzahl
        f1 = int(m.group(1))
        f2 = int(m.group(2)) if m.group(2) else None
        # Ohne ausdrückliches "F" nur plausible Ofen-/Frittiertemperaturen als Fahrenheit deuten
        ausdruecklich_f = re.search(r"\d\s*(?:°|º|˚|degrees?|deg\.?)?\s*F", m.group(0), re.I) is not None
        if not ausdruecklich_f and not 150 <= f1 <= 550:
            return m.group(0)
        anzahl += 1
        abstand = " " if m.start() > 0 and m.string[m.start() - 1].isalpha() else ""  # "to350°F"
        if f2:
            return f"{abstand}{celsius(f1)}–{celsius(f2)} °C"
        return f"{abstand}{celsius(f1)} °C"

    return RE_FAHRENHEIT.sub(ersetze, text), anzahl
