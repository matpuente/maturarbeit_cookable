"""Ordnet jedes Rezept genau einer der fünf deutschen Kategoriegruppen zu (Entwurf zur Kontrolle).

1. Kurs-Tags aus dem zweiten Datensatz (`tags`), in der Reihenfolge von GRUPPEN_NACH_TAG.
2. Falls kein Kurs-Tag passt: `RecipeCategory` aus dem Hauptdatensatz (KATEGORIE_ZU_GRUPPE).
3. Sonst: keine Gruppe ("Sauce/Würze" oder "unklar").
"""
from typing import Optional

# Reihenfolge = Vorrang, falls ein Rezept mehrere Kurs-Tags hat
GRUPPEN_NACH_TAG = [
    ("Frühstück", {"breakfast"}),
    ("Dessert", {"desserts", "cookies-and-brownies", "cakes", "pies-and-tarts", "candy", "frozen-desserts"}),
    ("Hauptgericht", {"main-dish", "soups-stews"}),
    ("Beilage", {"side-dishes", "salads"}),
    # Süsse Schnellbrote (Banana Bread, Muffins) -> Frühstück, ausser mit eindeutigem Gang-Tag oben
    ("Frühstück", {"quick-breads", "muffins"}),
    ("Beilage", {"breads"}),
    ("Snack", {"appetizers", "snacks"}),
    ("Frühstück", {"brunch"}),
    ("Hauptgericht", {"lunch"}),
    ("Sauce/Würze", {"sauces", "condiments-etc"}),
]

KATEGORIE_ZU_GRUPPE = {
    **dict.fromkeys(["Breakfast", "Brunch", "Breakfast Eggs", "Oatmeal", "Scones", "Quick Breads"], "Frühstück"),
    **dict.fromkeys([
        "Dessert", "Frozen Desserts", "Pie", "Bar Cookie", "Drop Cookies", "Candy", "Cheesecake",
        "Tarts", "Gelatin", "Ice Cream", "Chocolate Chip Cookies", "Coconut Cream Pie",
        "Key Lime Pie", "Peanut Butter Pie", "Apple Pie", "Bread Pudding", "Lemon Cake",
        "Desserts Fruit", "Snacks Sweet",
    ], "Dessert"),
    **dict.fromkeys(["Lunch/Snacks"], "Snack"),
    **dict.fromkeys([
        "Vegetable", "Potato", "Rice", "Long Grain Rice", "White Rice", "Brown Rice",
        "Short Grain Rice", "Medium Grain Rice", "Breads", "Yeast Breads",
        "Sourdough Breads", "Mashed Potatoes", "Yam/Sweet Potato", "Corn", "Greens",
        "Collard Greens", "Spinach", "Cauliflower", "Grains", "Beans", "Black Beans",
        "Wheat Bread", "Buttermilk Biscuits",
    ], "Beilage"),
    **dict.fromkeys([
        "Sauces", "Salad Dressings", "Spreads", "Chutneys", "Jellies", "Stocks",
        "Spaghetti Sauce", "Turkey Gravy",
    ], "Sauce/Würze"),
}
# Alles übrige mit Fleisch, Fisch, Eintöpfen, Pasta usw. -> Hauptgericht
HAUPTGERICHT_STANDARD = "Hauptgericht"
OHNE_KURS = {  # Kategorien, die nichts über den Gang aussagen
    "< 15 Mins", "< 30 Mins", "< 60 Mins", "< 4 Hours", "Low Protein", "Low Cholesterol",
    "Very Low Carbs", "Healthy", "High Protein", "High In...", "Free Of...", "Easy",
    "Weeknight", "Kid Friendly", "For Large Groups", "Potluck", "Vegan", "Lactose Free",
    "Egg Free", "Kosher", "Toddler Friendly", "Beginner Cook", "Inexpensive", "Spicy", "Sweet",
    "Savory", "Summer", "Winter", "Spring", "Christmas", "Thanksgiving", "Halloween",
    "Oven", "Microwave", "Stove Top", "Broil/Grill", "Camping", "Canning", "No Cook",
    "Refrigerator", "Freezer", "Small Appliance", "Mixer", "Pressure Cooker", "Bread Machine",
    "Dehydrator", "Baking", "Birthday", "From Scratch", "Deep Fried", "Steam",
    "Fruit", "Berries", "Strawberry", "Apple", "Lemon", "Lime", "Oranges", "Pineapple",
    "Cheese", "Nuts", "Peanut Butter", "Coconut", "Melons", "Mango", "Citrus", "Pears",
    "Cherries", "Raspberries", "Plums", "Grapes", "Kiwifruit", "Papaya", "Tropical Fruits",
}


def gruppe(tags: list, kategorie: Optional[str]) -> str:
    gesetzt = set(tags)
    if kategorie == "Quick Breads":
        gesetzt.add("quick-breads")
    for name, tag_menge in GRUPPEN_NACH_TAG:
        if gesetzt & tag_menge:
            return name
    if kategorie in KATEGORIE_ZU_GRUPPE:
        return KATEGORIE_ZU_GRUPPE[kategorie]
    if kategorie is None or kategorie in OHNE_KURS:
        return "unklar"
    return HAUPTGERICHT_STANDARD
