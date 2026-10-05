#!/usr/bin/env python3
"""修复 .ts 中既有的损坏译文 —— 形如「定高Altitude」「任务Mission」「返航Return」。

判定条件（三重保险，避免误伤正常译文）：
  1. 译文不等于英文原文
  2. 译文以英文原文结尾
  3. 英文原文之前的部分含中日韩字符

用法: python gc40_fix_broken.py <file.ts>
"""
import re
import sys
import xml.etree.ElementTree as ET

CJK = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\u3040-\u30ff]")


def main(path):
    tree = ET.parse(path)
    root = tree.getroot()

    fixed = []
    for ctx in root.findall("context"):
        for msg in ctx.findall("message"):
            src_el = msg.find("source")
            tr_el = msg.find("translation")
            if src_el is None or tr_el is None:
                continue
            src = (src_el.text or "").strip()
            txt = (tr_el.text or "").strip()
            if not src or not txt or txt == src:
                continue
            if not txt.endswith(src):
                continue
            head = txt[: -len(src)].strip()
            if not head or not CJK.search(head):
                continue
            tr_el.text = head
            fixed.append((src, txt, head))

    for src, old, new in fixed:
        print(f"  {old!r}  ->  {new!r}")

    tree.write(path, encoding="utf-8", xml_declaration=True)
    print(f"修复 {len(fixed)} 条损坏译文")


if __name__ == "__main__":
    main(sys.argv[1])
