#!/usr/bin/env python3
"""CI yardımcısı: flutter analyze çıktısını / flutter test JSON raporunu GitHub
uyarılarına (annotation) çevirir; böylece hatalar sürüm sayfasında ve check-run'da görünür.
  python3 tool/ci_annotate.py analyze /tmp/analyze.txt
  python3 tool/ci_annotate.py test /tmp/test.json
"""
import json
import re
import sys

LEVELS = ["error", "warning", "notice"]  # her biri adım başına en çok 10 annotation


def emit(i, file, line, msg):
    lvl = LEVELS[min(i // 10, 2)]
    msg = msg.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    loc = f" file={file},line={line}" if file else ""
    print(f"::{lvl}{loc}::{msg}")


def analyze(path):
    n = 0
    for raw in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\s*(error|warning|info)\s+•\s+(.*?)\s+•\s+(\S+):(\d+):\d+\s+•\s+(\S+)", raw)
        if not m or m.group(1) == "info":
            continue
        emit(n, m.group(3), m.group(4), f"{m.group(1)}: {m.group(2)} ({m.group(5)})")
        n += 1
    print(f"analyze: {n} hata/uyarı")


def test(path):
    names, errors, n = {}, {}, 0
    for raw in open(path, encoding="utf-8", errors="replace"):
        try:
            e = json.loads(raw)
        except ValueError:
            continue
        if e.get("type") == "testStart":
            names[e["test"]["id"]] = e["test"]["name"]
        elif e.get("type") == "error":
            errors.setdefault(e["testID"], []).append(e.get("error", "") + "\n" + e.get("stackTrace", "")[:600])
        elif e.get("type") == "testDone" and e.get("result") != "success" and not e.get("hidden"):
            emit(n, "", 0, f"TEST: {names.get(e['testID'], '?')}\n" + "\n".join(errors.get(e["testID"], []))[:1500])
            n += 1
    print(f"test: {n} başarısız")


if __name__ == "__main__":
    {"analyze": analyze, "test": test}[sys.argv[1]](sys.argv[2])
