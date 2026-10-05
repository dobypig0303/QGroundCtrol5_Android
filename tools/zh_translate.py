#!/usr/bin/env python3
"""
QGC 中文翻译辅助工具
1) analyze  : 统计完成度，并分析有多少未翻译条目可以从已有译文复用
2) autofill : 用同一文件内已存在的同名 source 译文，自动填充 unfinished 条目
3) export   : 导出未翻译条目为 JSON（供人工/AI 翻译）
4) apply    : 把 JSON 译文写回 .ts
"""
import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def load(path: Path):
    tree = ET.parse(path)
    return tree


def iter_messages(root):
    for ctx in root.findall("context"):
        name_el = ctx.find("name")
        ctx_name = name_el.text if name_el is not None else ""
        for msg in ctx.findall("message"):
            src_el = msg.find("source")
            tr_el = msg.find("translation")
            if src_el is None or tr_el is None:
                continue
            yield ctx_name, msg, src_el, tr_el


def is_finished(tr_el) -> bool:
    return tr_el.get("type") not in ("unfinished", "vanished") and (tr_el.text or "").strip() != ""


def analyze(path: Path):
    root = load(path).getroot()
    finished_map = {}
    total = finished = unfinished = 0
    for ctx, msg, src_el, tr_el in iter_messages(root):
        src = (src_el.text or "")
        total += 1
        if is_finished(tr_el):
            finished += 1
            finished_map.setdefault(src, (tr_el.text or "").strip())
        else:
            unfinished += 1

    reusable = 0
    for ctx, msg, src_el, tr_el in iter_messages(root):
        if not is_finished(tr_el):
            if (src_el.text or "") in finished_map:
                reusable += 1

    pct = round(100 * finished / total, 1) if total else 0
    print(f"{path.name}")
    print(f"  总条目     : {total}")
    print(f"  已翻译     : {finished}  ({pct}%)")
    print(f"  未翻译     : {unfinished}")
    print(f"  可自动复用 : {reusable}")
    print(f"  仍需翻译   : {unfinished - reusable}")
    return finished_map


def autofill(path: Path):
    root = load(path)
    r = root.getroot()
    finished_map = {}
    for ctx, msg, src_el, tr_el in iter_messages(r):
        if is_finished(tr_el):
            finished_map.setdefault((src_el.text or ""), (tr_el.text or "").strip())

    n = 0
    for ctx, msg, src_el, tr_el in iter_messages(r):
        if not is_finished(tr_el):
            src = src_el.text or ""
            if src in finished_map:
                tr_el.text = finished_map[src]
                if "type" in tr_el.attrib:
                    del tr_el.attrib["type"]
                n += 1
    if n:
        root.write(path, encoding="utf-8", xml_declaration=True)
    print(f"{path.name}: 自动填充 {n} 条")


def export(path: Path, out: Path):
    """导出未翻译条目（排除可复用的）"""
    root = load(path).getroot()
    finished_map = {}
    for ctx, msg, src_el, tr_el in iter_messages(root):
        if is_finished(tr_el):
            finished_map.setdefault((src_el.text or ""), (tr_el.text or "").strip())

    items = []
    for idx, (ctx, msg, src_el, tr_el) in enumerate(iter_messages(root)):
        if is_finished(tr_el):
            continue
        src = src_el.text or ""
        if src in finished_map:
            continue  # 可复用，不用导出
        items.append({"i": idx, "s": src, "c": ctx})
    out.write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{path.name}: 导出 {len(items)} 条到 {out}")


def apply(path: Path, data: Path):
    root = load(path)
    r = root.getroot()
    tr_map = {int(k): v for k, v in json.loads(data.read_text(encoding="utf-8")).items()}
    n = 0
    for idx, (ctx, msg, src_el, tr_el) in enumerate(iter_messages(r)):
        if idx in tr_map and tr_map[idx]:
            tr_el.text = tr_map[idx].replace("\\n", "\n")
            if "type" in tr_el.attrib:
                del tr_el.attrib["type"]
            n += 1
    root.write(path, encoding="utf-8", xml_declaration=True)
    print(f"{path.name}: 写回 {n} 条")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["analyze", "autofill", "export", "apply"])
    ap.add_argument("ts", type=Path)
    ap.add_argument("--out", type=Path)
    a = ap.parse_args()
    if a.cmd == "analyze":
        analyze(a.ts)
    elif a.cmd == "autofill":
        autofill(a.ts)
    elif a.cmd == "export":
        export(a.ts, a.out)
    elif a.cmd == "apply":
        apply(a.ts, a.out)
