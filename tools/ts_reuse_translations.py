#!/usr/bin/env python3
"""用 lupdate 之前的旧 .ts 作译文来源，回填新 .ts 中 source 相同的未完成条目。

lupdate 会把因换文件/改文案而失配的条目标记为 obsolete，其译文仍保留在文件里。
本脚本不分 context、只看 source 文本，因此能把这些译文抢救回来。

用法: python gc40_reuse.py <旧.ts> <新.ts>
"""
import sys
import xml.etree.ElementTree as ET


def collect(path):
    """收集 source -> translation，只要译文非空就收，不管 type 是 obsolete/vanished"""
    pool = {}
    root = ET.parse(path).getroot()
    for ctx in root.findall("context"):
        for msg in ctx.findall("message"):
            src_el = msg.find("source")
            tr_el = msg.find("translation")
            if src_el is None or tr_el is None:
                continue
            src = src_el.text or ""
            text = (tr_el.text or "").strip()
            if src and text:
                pool.setdefault(src, text)
    return pool


def main(old_path, new_path):
    pool = collect(old_path)
    print(f"旧文件可用译文 : {len(pool)} 条")

    tree = ET.parse(new_path)
    root = tree.getroot()

    filled = 0
    for ctx in root.findall("context"):
        for msg in ctx.findall("message"):
            src_el = msg.find("source")
            tr_el = msg.find("translation")
            if src_el is None or tr_el is None:
                continue
            text = (tr_el.text or "").strip()
            if tr_el.get("type") not in ("unfinished", "vanished") and text:
                continue
            src = src_el.text or ""
            if src in pool:
                tr_el.text = pool[src]
                tr_el.attrib.pop("type", None)
                filled += 1

    tree.write(new_path, encoding="utf-8", xml_declaration=True)
    print(f"回填完成       : {filled} 条")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
