#!/usr/bin/env python3
"""查 .ts 中指定 source 字符串所属的 context / 译文 / 出处文件。

用法: python ts_lookup.py <file.ts> <source1> [source2 ...]
"""
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
keys = set(sys.argv[2:])

root = ET.parse(path).getroot()
found = set()
for ctx in root.findall("context"):
    name_el = ctx.find("name")
    name = (name_el.text or "") if name_el is not None else ""
    for msg in ctx.findall("message"):
        src_el = msg.find("source")
        src = (src_el.text or "") if src_el is not None else ""
        if src not in keys:
            continue
        found.add(src)
        tr = msg.find("translation")
        text = (tr.text or "").strip() if tr is not None else ""
        ttype = tr.get("type") if tr is not None else None
        locs = [l.get("filename") for l in msg.findall("location")]
        print(f"source      : {src!r}")
        print(f"  context   : {name!r}")
        print(f"  translation: {text!r}  type={ttype}")
        for l in locs[:3]:
            print(f"  location  : {l}")
        print()

for k in keys - found:
    print(f"source      : {k!r}")
    print("  >>> 不在 .ts 中 <<<\n")
