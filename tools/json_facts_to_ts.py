#!/usr/bin/env python3
"""把 QGC 4.0.11 中 *.Fact*.json 里无法翻译的字符串合并进 qgc_zh_CN.ts。

这些字符串原本由 FactMetaData 直接读取、不经过 .ts，因此无论翻译文件多完整，
仪表面板等处的 Fact 名称始终是英文。配合 src/FactSystem/FactMetaData.cc 中的
jsonFactTr() 补丁（context 固定为 "QGCJson"）即可让它们也参与翻译。

用法: python gc40_json_to_ts.py <qgc_zh_CN.ts>
"""
import json
import os
import sys
import xml.etree.ElementTree as ET

SRC = r"C:\qgc40\src"
CONTEXT = "QGCJson"
DESC_KEYS = ("shortDescription", "longDescription")


def walk(node, out):
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(value, str):
                if key in DESC_KEYS:
                    if value.strip():
                        out.add(value)
                elif key == "enumStrings":
                    for part in value.split(","):
                        if part.strip():
                            out.add(part.strip())
            else:
                walk(value, out)
    elif isinstance(node, list):
        for item in node:
            walk(item, out)


def collect():
    strings = set()
    for dirpath, _, names in os.walk(SRC):
        for name in names:
            if not (name.endswith(".json") and "Fact" in name):
                continue
            try:
                with open(os.path.join(dirpath, name), encoding="utf-8") as fh:
                    walk(json.load(fh), strings)
            except Exception as exc:  # noqa: BLE001
                print(f"  跳过 {name}: {exc}")
    return strings


def main(ts_path):
    strings = collect()

    tree = ET.parse(ts_path)
    root = tree.getroot()

    ctx = None
    for c in root.findall("context"):
        el = c.find("name")
        if el is not None and (el.text or "") == CONTEXT:
            ctx = c
            break
    if ctx is None:
        ctx = ET.SubElement(root, "context")
        ET.SubElement(ctx, "name").text = CONTEXT

    existing = {(m.find("source").text or "") for m in ctx.findall("message") if m.find("source") is not None}

    added = 0
    for text in sorted(strings):
        if text in existing:
            continue
        msg = ET.SubElement(ctx, "message")
        ET.SubElement(msg, "source").text = text
        ET.SubElement(msg, "translation").set("type", "unfinished")
        added += 1

    tree.write(ts_path, encoding="utf-8", xml_declaration=True)
    print(f"JSON 中可翻译字符串 : {len(strings)}")
    print(f"新写入 .ts 的条目   : {added}")


if __name__ == "__main__":
    main(sys.argv[1])
