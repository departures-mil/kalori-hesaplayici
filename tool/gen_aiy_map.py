#!/usr/bin/env python3
"""Maps the labels of Google's AIY food classifier (food_V1, Apache-2.0,
2023 dishes) to foods.json ids -> assets/data/aiy_map.json."""
import csv, json, os, re, sys, unicodedata

here = os.path.dirname(os.path.abspath(__file__))
foods = json.load(open(os.path.join(here, "..", "assets", "data", "foods.json"), encoding="utf-8"))["foods"]
ids = {f["id"] for f in foods}

def n(s):
    s = unicodedata.normalize("NFKD", s.lower().replace("ı", "i"))
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z ]", "", s).strip()

idx = {}
for f in foods:
    for k in (f["en"], f["tr"], f["id"].replace("_", " ")):
        idx.setdefault(n(k), f["id"])

MANUAL = {
 "Sarma": "zy_yaprak_sarma", "Dolma": "zy_biber_dolma", "Manti": "manti", "Kanafeh": "kunefe",
 "Maqluba": "maqluba", "Shawarma": "shawarma_sandwich", "Fattoush": "fattoush", "Fatteh": "fatteh_hummus",
 "Shami kebab": "kofta_kebab", "Alinazik kebab": "ali_nazik", "Cherry kebab": "kabab_halabi",
 "Hummus": "hummus", "Pilaf": "rice_cooked", "White rice": "rice_plain_boiled", "Hamburger": "burger",
 "Doughnut": "donut", "Sandwich": "sandwich", "Spaghetti": "spaghetti_tomato", "Shahan ful": "ful",
 "Home fries": "patates_firinda", "Cheese fries": "fries", "Chicken nugget": "nuggets",
 "Crispy fried chicken": "chicken_fried", "Chicken fingers": "crispy_chicken", "Cupcake": "muffin",
 "Deviled egg": "egg_boiled", "Garden salad": "green_salad", "Cobb salad": "chicken_salad",
 "Caprese salad": "greek_salad", "Neapolitan pizza": "pizza_slice_margherita", "Pierogi": "dumplings",
 "Sulu köfte": "sulu_kofte", "Toyga soup": "toyga", "Baklava": "baklava", "Lentil soup": "lentil_soup",
 "Chicken sandwich": "chicken_burger", "Veggie burger": "burger", "Fried eggplant": "sebze_kizartma",
 "Stir-fried tomato and scrambled eggs": "menemen", "Tuna fish sandwich": "sandwich",
 "Ham and cheese sandwich": "tost_karisik", "Cheese sandwich": "toast", "Pasta salad": "pasta_salad",
 "Macaroni salad": "pasta_salad", "Chocolate chip cookie": "cookie_chocochip", "Butter cookie": "kurabiye_un",
 "Pound cake": "kek_dilim", "Red velvet cake": "pasta_dilim", "Ice cream cake": "pasta_dilim",
 "Steak sandwich": "sandwich", "Breakfast sandwich": "sandwich", "Kimchi fried rice": "fried_rice",
}
KEYWORDS = [
 (r"pizza", "pizza_mixed"), (r"burger", "burger"), (r"fried rice", "fried_rice"), (r"kebab|kebap", "shish_kebab"),
 (r"k[oö]fte|meatball", "meatballs"), (r"soup|chowder|broth", "sebze_corbasi"), (r"salad", "mevsim_salata"),
 (r"cheesecake", "cheesecake"), (r"cake", "kek_dilim"), (r"\bpie\b", "apple_pie"), (r"cookie|biscuit", "cookie"),
 (r"pudding", "puding"), (r"sandwich|sub\b", "sandwich"), (r"steak", "beef_steak"), (r"donut|doughnut", "donut"),
 (r"omelet|egg", "omelette"), (r"spaghetti|pasta|macaroni|lasagn|ravioli|penne|fettuccine", "pasta_cooked"),
 (r"noodle|ramen|udon|pho\b", "noodles"), (r"curry", "chicken_curry"), (r"fried chicken", "chicken_fried"),
 (r"chicken", "chicken_grilled"), (r"\bfish\b|salmon|tuna|cod\b", "fish_fried"), (r"shrimp|prawn", "shrimp"),
 (r"sushi|maki", "sushi"), (r"dumpling|gyoza|wonton|pierog", "dumplings"), (r"\brice\b|risotto|pilaf|biryani", "rice_cooked"),
 (r"bread|bun\b|roll\b|loaf", "bread_white"), (r"fries|chips", "fries"), (r"ice cream|gelato", "ice_cream"),
 (r"pancake|crepe|crêpe", "pancake"), (r"waffle", "waffle"), (r"taco", "tacos"), (r"burrito|wrap", "wrap"),
 (r"stew|casserole|goulash|tagine", "guvec"), (r"beef|lamb|pork|meat", "beef_steak"), (r"bean|lentil|chickpea", "beans_stew"),
 (r"tart|pastry|strudel", "fruit_pie"), (r"chocolate", "chocolate_milk"), (r"yogurt|yoghurt", "yogurt"),
 (r"cheese", "white_cheese"), (r"potato", "potato_boiled"), (r"sausage|hot dog", "sausage"),
]

out, how = {}, {"exact": 0, "manual": 0, "keyword": 0}
for r in csv.DictReader(open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "data", "aiy_food_V1_labelmap.csv"), encoding="utf-8")):
    lab = r["name"].strip().strip('"')
    if lab == "__background__":
        continue
    fid = None
    if lab in MANUAL:
        fid, k = MANUAL[lab], "manual"
    elif n(lab) in idx:
        fid, k = idx[n(lab)], "exact"
    else:
        for pat, t in KEYWORDS:
            if re.search(pat, lab, re.I):
                fid, k = t, "keyword"
                break
    if fid:
        assert fid in ids, (lab, fid)
        out[lab.lower()] = fid
        how[k] += 1
json.dump(out, open(os.path.join(here, "..", "assets", "data", "aiy_map.json"), "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))
print(len(out), "AIY labels mapped", how)
