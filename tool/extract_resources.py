"""Turns the two Word documents in the project root into app data.

    python tool/extract_resources.py

Writes:
  assets/data/resources.json   — searchable content for the AI Scan "Resources" section
  assets/resources/*.jpg|png   — the photos pulled out of the documents

Re-run it whenever the .docx files change; nothing downstream is hand-edited.
"""

import io
import json
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PEST_DOC = os.path.join(ROOT, "pole1.docx")
RICE_DOC = os.path.join(ROOT, "မြန်မာနိုင်ငံမှာအများဆုံးတွေ့ရသောစပါးအမျိုးအစားများ.docx")
IMG_DIR = os.path.join(ROOT, "assets", "resources")
DATA_DIR = os.path.join(ROOT, "assets", "data")

# Word anchors floating images with a long digit id in the paragraph text (e.g.
# "24643254293456001. Topedo"). Strip runs of 5+ digits only — list numbering is
# 1-2 digits and must survive, or "1. Topedo" turns into a heading of its own.
LEADING_DIGITS = re.compile(r"^\s*-?\d{5,}\s*")
# The anchor id often runs straight into the list number ("...34560" + "1. Topedo").
# Stop the strip one digit early when a list number is clearly attached.
# The list number may be written "2." or just "2 " — allow both.
ANCHOR_THEN_NUMBER = re.compile(r"^\s*-?\d{4,}(?=\d[.)]?\s)")
TAG = re.compile(r"<[^>]+>")
# "ကောမက်(ပုလဲ / ယူရီးယား): ..." / "အာမို (Armo): ..." — the paren is what marks a brand.
# The name must start on a Burmese letter, so it cannot swallow the tail of the
# preceding sentence ("...အချိုးစုံ)အာမို (Armo)" → "အာမို (Armo)").
# The trailing "name (type)" of a bold brand heading.
BRAND_TAIL = re.compile(r"([က-႟]*\s*\([^)]+\))\s*$")
# Bold section titles that get glued onto the first heading underneath them.
SECTION_TITLES = ("အချက်အလက်လိုက်နာရမည့် နည်းလမ်း", "အချက်အလက်လိုက်နာရမည့်နည်းလမ်း", "နာမည်ကြီး ဓာတ်မြေဩဇာများ")
# "၈၅ ရက်မှ ၁၀၅ ရက်" out of a growth-stage caption.
AGE_RANGE = re.compile(r"([၀-၉]+\s*ရက်\s*မှ\s*[၀-၉]+)\s*ရက်")


def _clean(block):
    text = TAG.sub("", block)
    stripped = ANCHOR_THEN_NUMBER.sub("", text)
    if stripped == text:
        stripped = LEADING_DIGITS.sub("", text)
    return stripped.strip()


def bold_groups(block):
    """Splits a paragraph into alternating (is_bold, text) groups.

    Word marks every heading inside these documents as a bold run — that is a far
    more reliable structure signal than punctuation, because whole sections are
    written as one run-on paragraph ("...ရေပြန်သွင်းပါ။ပေါင်းသတ်ဆေးနှင့်...").
    """
    groups = []
    for run in re.findall(r"<w:r[ >].*?</w:r>", block, re.S):
        bold = "<w:b/>" in run or "<w:b " in run
        text = TAG.sub("", run)
        if not text:
            continue
        if groups and groups[-1][0] == bold:
            groups[-1][1] += text
        else:
            groups.append([bold, text])
    return [(bold, text.strip()) for bold, text in groups if text.strip()]


def paragraphs(docx):
    """Yields (text, [images], [(is_bold, text)]) per paragraph, skipping tables."""
    z = zipfile.ZipFile(docx)
    xml = z.read("word/document.xml").decode("utf-8")
    rels = z.read("word/_rels/document.xml.rels").decode("utf-8")
    target = dict(re.findall(r'Id="([^"]+)"[^>]*Target="media/([^"]+)"', rels))
    z.close()

    # Table paragraphs are handled by rows(); drop them so they are not read twice.
    body = re.sub(r"<w:tbl[ >].*?</w:tbl>", "", xml, flags=re.S)
    for block in re.findall(r"<w:p[ >].*?</w:p>", body, re.S):
        text = _clean(block)
        images = [target[rid] for rid in re.findall(r'r:embed="([^"]+)"', block) if rid in target]
        if text or images:
            yield text, images, bold_groups(block)


def rows(docx):
    """Yields one list of cell strings per table row."""
    z = zipfile.ZipFile(docx)
    xml = z.read("word/document.xml").decode("utf-8")
    z.close()
    for table in re.findall(r"<w:tbl[ >].*?</w:tbl>", xml, re.S):
        for row in re.findall(r"<w:tr[ >].*?</w:tr>", table, re.S):
            cells = [_clean(c) for c in re.findall(r"<w:tc[ >].*?</w:tc>", row, re.S)]
            if any(cells):
                yield cells


def export_images(docx, prefix):
    """Copies the document's media into assets/resources with a stable prefix."""
    z = zipfile.ZipFile(docx)
    written = {}
    for name in z.namelist():
        if not name.startswith("word/media/"):
            continue
        base = os.path.basename(name)
        out_name = f"{prefix}_{base}"
        with z.open(name) as src, io.open(os.path.join(IMG_DIR, out_name), "wb") as dst:
            shutil.copyfileobj(src, dst)
        written[base] = f"assets/resources/{out_name}"
    z.close()
    return written


def parse_pests():
    """pole1.docx — a pest per heading, each with a symptom and numbered treatments."""
    media = export_images(PEST_DOC, "pest")
    items, current, medicine = [], None, None

    for text, images, _ in paragraphs(PEST_DOC):
        pictures = [media[i] for i in images if i in media]

        if text.startswith("လက္ခဏ"):  # လက္ခဏာ — symptom
            if current:
                current["symptom"] = text.split(":", 1)[-1].strip()
            continue
        if text.startswith("ကာကွယ်"):  # ကာကွယ် — "treatments" divider
            continue
        if text.startswith("အသုံးပြုပုံ"):  # အသုံးပြုပုံ — how to use
            if medicine:
                medicine["usage"] = text.split(":", 1)[-1].strip()
            continue

        numbered = re.match(r"^(\d+)\s*[\.\s]+\.?\s*(.+)$", text)
        if numbered and current and len(numbered.group(2)) < 60:
            medicine = {"name": numbered.group(2).strip(" .​"), "usage": "", "images": pictures}
            current["treatments"].append(medicine)
            continue

        if text and len(text) < 90 and "(" in text:  # a new pest heading
            current = {"name": text.strip(), "symptom": "", "treatments": [], "images": pictures}
            items.append(current)
            medicine = None
        elif pictures and medicine:
            medicine["images"].extend(pictures)
        elif pictures and current:
            current["images"].extend(pictures)

    # The same product appears under several pests, and Word sometimes drops its
    # photo next to one mention but not the others. Pick one canonical photo per
    # product name so every treatment row shows the right bottle.
    canonical = {}
    for pest in items:
        for medicine in pest["treatments"]:
            key = _product_key(medicine["name"])
            if medicine["images"] and key not in canonical:
                canonical[key] = medicine["images"][0]
    for pest in items:
        for medicine in pest["treatments"]:
            photo = canonical.get(_product_key(medicine["name"]))
            medicine["images"] = [photo] if photo else []

    return items


def _product_key(name):
    """"2. . Suntap 50 SP" and "Suntap 50 SP" must resolve to the same product."""
    return re.sub(r"[^a-z0-9]", "", name.lower())


def parse_rice():
    """The rice document holds a fertiliser schedule, brand notes and guidelines."""
    media = export_images(RICE_DOC, "fert")
    schedule, brands, guidelines, stages = [], [], [], []
    pending_pictures = []
    seen_schedule_header = False
    in_stages = False  # past the "စပါးပင်များ" heading the photos are crop stages

    for cells in rows(RICE_DOC):
        cells = [c for c in cells if c]
        # The variety table (name | days) is deliberately not imported.
        if len(cells) == 2:
            continue

        # Fertiliser schedule table: stage | age | urea | phosphate | potash | purpose
        if len(cells) >= 5:
            if not seen_schedule_header:
                seen_schedule_header = True  # the header row itself
                continue
            schedule.append(
                {
                    "stage": cells[0],
                    "age": cells[1],
                    "urea": cells[2],
                    "phosphate": cells[3],
                    "potash": cells[4],
                    "purpose": cells[5] if len(cells) > 5 else "",
                }
            )

    for text, images, groups in paragraphs(RICE_DOC):
        pictures = [media[i] for i in images if i in media]

        if text.startswith("စပါးပင်များ"):
            in_stages = True

        # Walk the bold/normal pairs: a bold heading followed by normal text is an entry.
        found = False
        declared_here = False
        for i, (bold, heading) in enumerate(groups):
            if not bold or i + 1 >= len(groups) or groups[i + 1][0]:
                continue
            body = groups[i + 1][1]
            if not body:
                continue

            if "အပင်သက်တမ်း" in heading:  # a rice plant growth-stage photo caption
                detail = " ".join(g[1] for g in groups[i + 1 :]).strip()
                # "...ရက်မှ ၈၅ ရက်မှ ၁၀၅ ရက် ခန့်..." — pull the day range out for the card title.
                age = AGE_RANGE.search(detail)
                stages.append(
                    {
                        "title": f"အပင်သက်တမ်း {age.group(1)} ရက်" if age else heading,
                        "detail": detail,
                        # The photo sits in the paragraph just above its caption.
                        "images": list(pending_pictures[-1:]),
                    }
                )
                pending_pictures.clear()
                found = True
                break

            if heading.rstrip().endswith((":", "：")):
                # A brand. The heading may still carry the section title in front of it
                # ("၂။ နာမည်ကြီး ... (NPK အချိုးစုံ)အာမို (Armo):") — keep only the
                # trailing "name (type)" part.
                label = heading.rstrip().rstrip(":：").strip()
                tail = BRAND_TAIL.search(label)
                brands.append({"name": (tail.group(1).strip() if tail else label), "detail": body, "images": []})
                found = True
                declared_here = True
            else:
                # A guideline. The first one is glued to the section title, which is
                # bold too ("အချက်အလက်လိုက်နာရမည့် နည်းလမ်း" + "ရေသွင်းရေထုတ်").
                title = heading
                for prefix in SECTION_TITLES:
                    if title.startswith(prefix):
                        title = title[len(prefix) :].strip()
                if title:
                    guidelines.append({"title": title, "detail": body})

        # ── photo placement ────────────────────────────────────────────────
        # Word anchors each bag photo in the paragraph AFTER its brand, and
        # sometimes in the same paragraph as the NEXT brand's text. So:
        #   · photos in a paragraph with no brand text  → the brand just declared
        #   · photos in a paragraph that declares a brand → the earliest brand
        #     still waiting for a photo (the picture floats above that text)
        if pictures:
            if declared_here:
                for photo in pictures:
                    waiting = next((b for b in brands if not b["images"]), None)
                    if waiting is not None:
                        waiting["images"].append(photo)
                    else:
                        pending_pictures.extend(pictures)
                        break
            elif brands and not in_stages:
                brands[-1]["images"].extend(pictures)
                pending_pictures.extend(pictures)
            else:
                # Past the brand list — these belong to the growth-stage captions.
                pending_pictures.extend(pictures)

    return schedule, stages, brands, guidelines


def main():
    # Burmese text in a Windows console dies on cp1252 without this.
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except AttributeError:
        pass
    for d in (IMG_DIR, DATA_DIR):
        os.makedirs(d, exist_ok=True)

    pests = parse_pests()
    schedule, stages, brands, guidelines = parse_rice()

    data = {
        "pests": pests,
        "fertiliserSchedule": schedule,
        "fertiliserBrands": brands,
        "growthStages": stages,
        "guidelines": guidelines,
    }
    out = os.path.join(DATA_DIR, "resources.json")
    with io.open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"pests: {len(pests)}  schedule: {len(schedule)}  brands: {len(brands)}  guidelines: {len(guidelines)}  stages: {len(stages)}")
    for p in pests:
        print("  -", p["name"][:44], "| treatments:", len(p["treatments"]), "| imgs:", len(p["images"]))
    for b in brands:
        print("  *", b["name"][:40], "| imgs:", len(b["images"]))
    for g in guidelines:
        print("  >", g["title"][:38], "|", g["detail"][:40])
    for st in stages:
        print("  ~", st["title"][:30], "| imgs:", len(st["images"]))
    print("wrote", out)


if __name__ == "__main__":
    main()
