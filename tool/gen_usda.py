#!/usr/bin/env python3
"""Builds assets/data/usda.json from USDA SR28 ABBREV (public domain).

Usage: python3 tool/gen_usda.py ABBREV.txt [nice_descriptions.csv]
Row: [description, kcal, protein, carbs, fat, household_g, household_desc]
(all per 100 g). Used as a fallback when a food is not in foods.json.
"""
import csv, json, os, re, sys

ABBR = {
 "CKD":"cooked","RSTD":"roasted","BRST":"breast","BLD":"boiled","BKD":"baked","BRLD":"broiled",
 "FRZ":"frozen","CND":"canned","DRND":"drained","UNPREP":"unprepared","PREP":"prepared",
 "FRSH":"fresh","SWTND":"sweetened","UNSWTND":"unsweetened","W/":"with ","WO/":"without ",
 "STMD":"steamed","STWD":"stewed","FRIED":"fried","SKN":"skin","LN":"lean","FAT":"fat",
 "TRMD":"trimmed","CHOIC":"choice","SEL":"select","GRD":"ground","VEG":"vegetable",
 "VEGS":"vegetables","PDR":"powder","LIQ":"liquid","CONC":"concentrate","DEHYD":"dehydrated",
 "RTE":"ready-to-eat","RTS":"ready-to-serve","SL":"sliced","CHOPD":"chopped","SHRD":"shredded",
 "WHL":"whole","ENR":"enriched","UNENR":"unenriched","REG":"regular","LO":"low","NFS":"",
 "BNLESS":"boneless","SHLDR":"shoulder","LEG":"leg","LOIN":"loin","MICROWAVED":"microwaved",
 "PAN-FRIED":"pan-fried","SAUSAGE":"sausage","CHS":"cheese","BF":"beef","CHICK":"chicken",
 "RICE":"rice","MILK":"milk","PNUT":"peanut","PNUTS":"peanuts","SMMR":"summer","SPRD":"spread",
 "SOUR CRM":"sour cream","CRM":"cream","SOY":"soy","FLR":"flour","WHT":"wheat","WHEAT":"wheat",
 "BRWN":"brown","DK":"dark","LT":"light","MEAT":"meat","ONLY":"only","SALTED":"salted",
 "UNSALTED":"unsalted","NO SALT":"no salt","SOL":"solids","JUC":"juice","SYR":"syrup",
 "HVY":"heavy","EX":"extra","PCKD":"packed","DRK":"dark","CHOC":"chocolate","COMM":"commercial",
 "HOME-PREPARED":"home-prepared","APPL":"apple","ORG":"organic",
}

def nice(desc):
    s = desc.replace("W/", "W/ ").replace("WO/", "WO/ ")
    parts = [p.strip() for p in s.split(",")]
    out = []
    for p in parts:
        words = []
        for w in p.split():
            key = w.upper()
            if key in ABBR:
                if ABBR[key]:
                    words.append(ABBR[key].strip())
            else:
                words.append(w.lower())
        if words:
            out.append(" ".join(words))
    t = ", ".join(out)
    return t[:1].upper() + t[1:]

def main():
    src = sys.argv[1]
    better = {}
    if len(sys.argv) > 2:
        with open(sys.argv[2], encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                better[r["food_id"].zfill(5)] = r["description"]
    csv.register_dialect("usda", delimiter="^", quoting=csv.QUOTE_NONNUMERIC, quotechar="~")
    rows = []
    with open(src, encoding="latin-1") as fh:
        for r in csv.reader(fh, "usda"):
            ndb, desc = str(r[0]).zfill(5), r[1]
            if desc.upper().startswith(("BABYFOOD", "INFANT FORMULA")):
                continue
            def num(i):
                try:
                    return round(float(r[i]), 1)
                except (ValueError, TypeError, IndexError):
                    return 0.0
            kcal, pro, fat, carb = num(3), num(4), num(5), num(7)
            name = better.get(ndb) or nice(desc)
            gm = num(48)
            gmd = (r[49] if len(r) > 49 and isinstance(r[49], str) else "").strip()
            rows.append([name, kcal, pro, carb, fat, gm, gmd])
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets", "data", "usda.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"source": "USDA National Nutrient Database for Standard Reference, Release 28 (public domain)",
                   "fields": ["desc", "kcal", "p", "c", "f", "hg", "hd"], "foods": rows},
                  fh, ensure_ascii=False, separators=(",", ":"))
    print(len(rows), "USDA foods ->", out)

main()
