#!/usr/bin/env python3
"""Convert a Markdown file to PDF using matplotlib PdfPages."""

import sys
import re
import textwrap
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

# A4 in inches
PAGE_W, PAGE_H = 8.27, 11.69
MARGIN_L, MARGIN_R = 0.75, 0.75
MARGIN_T, MARGIN_B = 0.75, 0.65
TEXT_W = PAGE_W - MARGIN_L - MARGIN_R

FONT_MONO = "DejaVu Sans Mono"
FONT_SANS = "DejaVu Sans"

def classify(line):
    if line.startswith("# "):    return ("h1", line[2:].strip())
    if line.startswith("## "):   return ("h2", line[3:].strip())
    if line.startswith("### "): return ("h3", line[4:].strip())
    if line.startswith("#### "): return ("h4", line[5:].strip())
    if line.startswith("---"):   return ("hr", "")
    if line.startswith("> "):    return ("blockquote", line[2:])
    if line.startswith("```"):   return ("fence", line[3:].strip())
    if line.startswith("| "):    return ("table", line)
    if line.startswith("- ") or line.startswith("* "): return ("bullet", line[2:])
    if re.match(r"^\d+\.", line): return ("numbul", re.sub(r"^\d+\.\s*","",line))
    if line.strip() == "":       return ("blank", "")
    return ("text", line)

def strip_md_inline(s):
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = re.sub(r"\*(.+?)\*", r"\1", s)
    s = re.sub(r"`(.+?)`", r"\1", s)
    s = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", s)
    return s

def wrap(text, width=88):
    return textwrap.wrap(strip_md_inline(text), width=width) or [""]

def parse_table(lines):
    rows = []
    for l in lines:
        if re.match(r"^\|[-| :]+\|$", l.strip()):
            continue
        cols = [c.strip() for c in l.strip().strip("|").split("|")]
        rows.append(cols)
    return rows

def render_pages(md_lines):
    """Convert parsed lines into a list of render commands per page."""
    pages = []
    cur = []   # list of (kind, content) draw commands
    y = PAGE_H - MARGIN_T

    # line heights in inches
    H = {
        "h1": 0.28, "h2": 0.24, "h3": 0.20, "h4": 0.18,
        "text": 0.145, "bullet": 0.145, "numbul": 0.145,
        "blockquote": 0.145, "code": 0.13,
        "hr": 0.07, "blank": 0.09, "table_row": 0.17,
    }

    def new_page():
        nonlocal cur, y
        pages.append(cur)
        cur = []
        y = PAGE_H - MARGIN_T

    def add(kind, data, h):
        nonlocal y
        if y - h < MARGIN_B + 0.05:
            new_page()
        cur.append((kind, data, y))
        y -= h

    i = 0
    in_fence = False
    fence_buf = []

    while i < len(md_lines):
        raw = md_lines[i].rstrip()
        kind, content = classify(raw)

        if kind == "fence":
            if not in_fence:
                in_fence = True
                fence_buf = []
            else:
                # flush fence block
                for cl in fence_buf:
                    for wl in [cl] if len(cl) < 100 else textwrap.wrap(cl, 98):
                        add("code", wl, H["code"])
                in_fence = False
                fence_buf = []
            i += 1
            continue

        if in_fence:
            fence_buf.append(raw)
            i += 1
            continue

        if kind == "h1":
            add("h1", strip_md_inline(content), H["h1"] + 0.06)
            add("hr", "", 0.04)
        elif kind == "h2":
            if y < PAGE_H - MARGIN_T - 0.5:
                add("blank", "", 0.06)
            add("h2", strip_md_inline(content), H["h2"] + 0.04)
        elif kind == "h3":
            add("blank", "", 0.03)
            add("h3", strip_md_inline(content), H["h3"])
        elif kind == "h4":
            add("h4", strip_md_inline(content), H["h4"])
        elif kind == "hr":
            add("hr", "", H["hr"])
        elif kind == "blank":
            add("blank", "", H["blank"])
        elif kind == "blockquote":
            for wl in wrap(content, 82):
                add("blockquote", wl, H["blockquote"])
        elif kind == "bullet":
            for j, wl in enumerate(wrap(content, 84)):
                add("bullet" if j == 0 else "bullet_cont", wl, H["bullet"])
        elif kind == "numbul":
            for j, wl in enumerate(wrap(content, 84)):
                add("bullet" if j == 0 else "bullet_cont", wl, H["bullet"])
        elif kind == "table":
            # collect all table lines
            tlines = [raw]
            j = i + 1
            while j < len(md_lines) and classify(md_lines[j].rstrip())[0] == "table":
                tlines.append(md_lines[j].rstrip())
                j += 1
            i = j - 1
            rows = parse_table(tlines)
            if rows:
                add("table_start", rows, 0)
                for ri, row in enumerate(rows):
                    add("table_row", (ri, rows), H["table_row"])
        elif kind == "text":
            for wl in wrap(content, 88):
                add("text", wl, H["text"])
        i += 1

    if cur:
        pages.append(cur)
    return pages

H_DRAW = {
    "h1": 0.28, "h2": 0.24, "h3": 0.20, "h4": 0.18,
    "text": 0.145, "bullet": 0.145, "numbul": 0.145,
    "blockquote": 0.145, "code": 0.13,
    "hr": 0.07, "blank": 0.09, "table_row": 0.17,
}

def draw_page(fig, ax, cmds, page_num, total):
    H = H_DRAW
    ax.set_xlim(0, TEXT_W)
    ax.set_ylim(MARGIN_B, PAGE_H - MARGIN_T + 0.01)
    ax.axis("off")

    # page footer
    ax.text(TEXT_W / 2, MARGIN_B - 0.15, f"— {page_num} / {total} —",
            ha="center", va="bottom", fontsize=7, color="#888",
            fontfamily=FONT_SANS)

    seen_tables = set()

    for kind, data, y in cmds:
        x0 = 0.0
        yp = y  # y is in figure coords, we need axes coords

        if kind == "h1":
            ax.text(x0, yp, data, fontsize=14, fontweight="bold",
                    va="top", fontfamily=FONT_SANS, color="#1a1a2e")
            ax.axhline(y=yp - 0.20, xmin=0, xmax=1,
                       color="#1a1a2e", linewidth=0.8)
        elif kind == "h2":
            ax.text(x0, yp, data, fontsize=11.5, fontweight="bold",
                    va="top", fontfamily=FONT_SANS, color="#16213e")
            ax.axhline(y=yp - 0.18, xmin=0, xmax=1,
                       color="#aaa", linewidth=0.5)
        elif kind == "h3":
            ax.text(x0, yp, data, fontsize=10, fontweight="bold",
                    va="top", fontfamily=FONT_SANS, color="#0f3460")
        elif kind == "h4":
            ax.text(x0, yp, data, fontsize=9, fontstyle="italic",
                    va="top", fontfamily=FONT_SANS, color="#333")
        elif kind == "text":
            ax.text(x0, yp, data, fontsize=8.5, va="top",
                    fontfamily=FONT_SANS, color="#111")
        elif kind == "bullet":
            ax.text(x0 + 0.15, yp, "•", fontsize=8.5, va="top",
                    fontfamily=FONT_SANS, color="#444")
            ax.text(x0 + 0.32, yp, data, fontsize=8.5, va="top",
                    fontfamily=FONT_SANS, color="#111")
        elif kind == "bullet_cont":
            ax.text(x0 + 0.32, yp, data, fontsize=8.5, va="top",
                    fontfamily=FONT_SANS, color="#111")
        elif kind == "blockquote":
            rect = mpatches.FancyBboxPatch(
                (x0, yp - 0.13), TEXT_W, 0.145,
                boxstyle="square,pad=0", linewidth=0,
                facecolor="#f5f5f5", zorder=0)
            ax.add_patch(rect)
            ax.axvline(x=x0 + 0.04, ymin=(yp - 0.13 - MARGIN_B) / (PAGE_H - MARGIN_T - MARGIN_B),
                       ymax=(yp + 0.015 - MARGIN_B) / (PAGE_H - MARGIN_T - MARGIN_B),
                       color="#999", linewidth=2)
            ax.text(x0 + 0.18, yp, data, fontsize=8, va="top",
                    fontfamily=FONT_SANS, color="#555", fontstyle="italic")
        elif kind == "code":
            ax.text(x0 + 0.1, yp, data, fontsize=7.2, va="top",
                    fontfamily=FONT_MONO, color="#222",
                    backgroundcolor="#f8f8f8")
        elif kind == "hr":
            ax.axhline(y=yp, xmin=0, xmax=1, color="#ccc", linewidth=0.5)
        elif kind == "table_start":
            pass  # handled by table_row
        elif kind == "table_row":
            ri, rows = data
            tid = id(rows)
            if tid not in seen_tables:
                seen_tables.add(tid)
            # figure out column widths
            ncols = max(len(r) for r in rows)
            col_w = TEXT_W / max(ncols, 1)
            is_header = (ri == 0)
            bg = "#e8eaf6" if is_header else ("#fafafa" if ri % 2 == 0 else "#ffffff")
            rect = mpatches.FancyBboxPatch(
                (x0, yp - H["table_row"] + 0.01), TEXT_W, H["table_row"],
                boxstyle="square,pad=0", linewidth=0,
                facecolor=bg, zorder=0)
            ax.add_patch(rect)
            row = rows[ri]
            for ci, cell in enumerate(row):
                cx = x0 + ci * col_w + 0.05
                ax.text(cx, yp - 0.03, strip_md_inline(cell)[:30],
                        fontsize=7, va="top",
                        fontfamily=FONT_SANS,
                        fontweight="bold" if is_header else "normal",
                        color="#111")

def build_pdf(md_path, pdf_path):
    with open(md_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    pages_cmds = render_pages(lines)
    total = len(pages_cmds)

    with PdfPages(pdf_path) as pdf:
        for pn, cmds in enumerate(pages_cmds, 1):
            fig = plt.figure(figsize=(PAGE_W, PAGE_H))
            ax = fig.add_axes([MARGIN_L / PAGE_W, MARGIN_B / PAGE_H,
                               TEXT_W / PAGE_W,
                               (PAGE_H - MARGIN_T - MARGIN_B) / PAGE_H])
            draw_page(fig, ax, cmds, pn, total)
            pdf.savefig(fig, dpi=150)
            plt.close(fig)
            print(f"  Page {pn}/{total}", end="\r")

    print(f"\nPDF saved: {pdf_path}  ({total} pages)")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 md_to_pdf.py <input.md> <output.pdf>")
        sys.exit(1)
    build_pdf(sys.argv[1], sys.argv[2])
