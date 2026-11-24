#!/usr/bin/env python3
"""Generates the nutrition data assets in CI (called from patch_android.py):
foods.json (local tr/en/ar table), usda.json (USDA SR28, public domain) and
aiy_map.json (offline food-model labels -> foods). Never fails the build:
if a download fails an empty but valid file is written."""
import json, os, subprocess, sys, urllib.request

here = os.path.dirname(os.path.abspath(__file__))
data = os.path.join(here, "..", "assets", "data")
tmp = "/tmp/kalori_src"
os.makedirs(tmp, exist_ok=True)

SRC = {
    "sr28.txt": "https://raw.githubusercontent.com/russellsteadman/foodweb/HEAD/raw/data.txt",
    "usda_nice.csv": "https://raw.githubusercontent.com/SarimAbidi/FitFuel/HEAD/data/raw/usda_foods.csv",
    "aiy_labels.csv": "https://raw.githubusercontent.com/wwb-cloud/open-calories/7cef62ffbc5354a55655601b416b256aee38ac6e/assets/models/aiy_food_V1_labelmap.csv",
}

def fetch(name):
    path = os.path.join(tmp, name)
    for _ in range(3):
        try:
            req = urllib.request.Request(SRC[name], headers={"User-Agent": "kalori-ci"})
            with urllib.request.urlopen(req, timeout=60) as r, open(path, "wb") as fh:
                fh.write(r.read())
            if os.path.getsize(path) > 1000:
                return path
        except Exception as e:
            print("download failed:", name, e)
    return None

def run(*args):
    print("+", " ".join(args))
    return subprocess.call([sys.executable, *args]) == 0

run(os.path.join(here, "gen_foods.py"))

# v1.0.11: add the Turkish / Arab dishes and household units (foods_extra.py)
sys.path.insert(0, here)
from foods_extra import X
fp = os.path.join(data, "foods.json")
table = json.load(open(fp, encoding="utf-8"))
ids = {f["id"] for f in table["foods"]}
for f in X:
    if f[0] in ids:
        raise SystemExit("duplicate id: " + f[0])
    ids.add(f[0])
    d = {"id": f[0], "en": f[1], "tr": f[2], "ar": f[3], "kcal": f[4], "p": f[5],
         "c": f[6], "f": f[7], "portion": f[8], "cat": f[9]}
    if len(f) > 10 and f[10]:
        d["u"] = f[10]
    table["foods"].append(d)
table["version"] = 2
json.dump(table, open(fp, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(table["foods"]), "foods in foods.json")
sr = fetch("sr28.txt")
nice = fetch("usda_nice.csv")
if not (sr and run(os.path.join(here, "gen_usda.py"), sr, *([nice] if nice else []))):
    json.dump({"foods": []}, open(os.path.join(data, "usda.json"), "w"))
    print("::warning::usda.json empty")
labels = fetch("aiy_labels.csv")
if not (labels and run(os.path.join(here, "gen_aiy_map.py"), labels)):
    json.dump({}, open(os.path.join(data, "aiy_map.json"), "w"))
    print("::warning::aiy_map.json empty")
for f in sorted(os.listdir(data)):
    print(f, os.path.getsize(os.path.join(data, f)))
