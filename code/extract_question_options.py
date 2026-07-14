from __future__ import annotations

import csv
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pdfplumber


ROOT = Path(__file__).resolve().parents[1]
PDF_DIR = ROOT / "docs" / "codebooks"
META_DIR = ROOT / "data" / "processed_data" / "02_metadata" / "survey_meta"
OUT_DIR = ROOT / "data" / "processed_data" / "02_metadata" / "question_options"
CHECK_DIR = ROOT / "output" / "checks"

QUESTION_RE = re.compile(r"^(?P<qid>[A-Z][0-9]+(?:-[0-9A-Z]+)*)\.(?P<body>.*)$")
OPTION_RE = re.compile(r"[□]\((?P<code>[^)]+)\)\s*(?P<text>.*?)(?=(?:[□]\([^)]+\))|$)")
META_Q_RE = re.compile(r"^(?P<qid>\d+(?:-\d+)*)[.、]?(?P<text>.*)$")


@dataclass
class QuestionBlock:
    question_id: str
    question_text: str
    body: str


def normalize_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.replace("\u3000", " ")).strip()


def extract_pdf_text(pdf_path: Path) -> str:
    parts: list[str] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            if text.strip():
                parts.append(text)
    return "\n".join(parts)


def build_question_blocks(text: str) -> list[QuestionBlock]:
    blocks: list[QuestionBlock] = []
    current_qid: str | None = None
    current_lines: list[str] = []

    for raw_line in text.splitlines():
        line = normalize_line(raw_line)
        if not line:
            continue
        match = QUESTION_RE.match(line)
        if match:
            if current_qid:
                blocks.append(materialize_block(current_qid, current_lines))
            current_qid = match.group("qid")
            current_lines = [match.group("body").strip()]
        elif current_qid:
            current_lines.append(line)

    if current_qid:
        blocks.append(materialize_block(current_qid, current_lines))
    return blocks


def materialize_block(question_id: str, lines: list[str]) -> QuestionBlock:
    body = "\n".join(lines).strip()
    question_text = lines[0].strip() if lines else ""
    if not question_text:
        question_text = body
    return QuestionBlock(question_id=question_id, question_text=question_text, body=body)


def extract_options(block: QuestionBlock) -> list[tuple[str, str]]:
    collapsed = " ".join(block.body.splitlines())
    matches = [
        (m.group("code").strip(), normalize_line(m.group("text")))
        for m in OPTION_RE.finditer(collapsed)
    ]
    cleaned: list[tuple[str, str]] = []
    for code, text in matches:
        text = re.sub(r"\s+", " ", text).strip(" ;，。")
        if text:
            cleaned.append((code, text))
    if cleaned:
        return cleaned
    return extract_plain_money_options(collapsed)


def extract_plain_money_options(text: str) -> list[tuple[str, str]]:
    """Recover amount choices when a PDF text layer drops checkbox glyphs."""
    amount_pattern = re.compile(
        r"未滿\s*\d[\d,]*\s*元"
        r"|\d[\d,]*\s*元\s*(?:及)?以下"
        r"|\d[\d,]*\s*(?:元)?\s*-\s*(?:未滿\s*)?\d[\d,]*\s*元"
        r"|\d[\d,]*\s*元\s*(?:及)?以上(?:，?\s*請記錄\s*_*\s*元)?"
    )
    matches = [(m.start(), normalize_line(m.group(0))) for m in amount_pattern.finditer(text)]
    for marker in ("沒有這項收入", "沒有這項支出", "不需要支付租金"):
        pos = text.find(marker)
        if pos >= 0:
            matches.append((pos, marker))
    matches.sort(key=lambda item: item[0])
    if len(matches) < 2:
        return []
    return [(str(i), label) for i, (_, label) in enumerate(matches, start=1)]


def rows_from_pdf(year: str, pdf_name: str) -> list[dict[str, str]]:
    text = extract_pdf_text(PDF_DIR / pdf_name)
    blocks = build_question_blocks(text)
    rows: list[dict[str, str]] = []
    for block in blocks:
        options = extract_options(block)
        if options:
            for code, option_text in options:
                rows.append(
                    {
                        "year": year,
                        "source_pdf": pdf_name,
                        "question_id": block.question_id,
                        "question_text": block.question_text,
                        "option_code": code,
                        "option_text": option_text,
                        "extraction_note": "",
                    }
                )
        else:
            rows.append(
                {
                    "year": year,
                    "source_pdf": pdf_name,
                    "question_id": block.question_id,
                    "question_text": block.question_text,
                    "option_code": "",
                    "option_text": "",
                    "extraction_note": "no_coded_option_detected",
                }
            )
    return repair_extraction_artifacts(year, rows)


def repair_extraction_artifacts(year: str, rows: list[dict[str, str]]) -> list[dict[str, str]]:
    """Repair deterministic PDF text-layer artifacts without borrowing another year."""
    if year != "99":
        return rows

    repaired: list[dict[str, str]] = []
    for row in rows:
        item = dict(row)
        code = item["option_code"].strip()
        text = item["option_text"].strip()
        # In ques99.pdf the number before the thousands comma is captured inside
        # the checkbox parentheses.  It is an amount prefix, not an option code.
        false_prefix = text.startswith("000") or (
            text.startswith("999") and code.isdigit() and int(code) >= 9
        )
        if code and false_prefix:
            item["option_text"] = f"{code},{text}"
            item["option_code"] = ""
            item["extraction_note"] = "repaired_99_thousands_prefix_from_false_code"
        repaired.append(item)
    return repaired


def build_quality_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    quality: list[dict[str, str]] = []
    for row in rows:
        text = row["option_text"]
        issue = ""
        if re.match(r"^000(?:\D|$)", text):
            issue = "suspected_missing_thousands_prefix"
        elif "□(" in text or "(" in text:
            issue = "embedded_option_not_split"
        elif re.search(r"(?:收入|支出|租金)", row["question_text"]) and not text:
            issue = "money_question_without_option_text"
        if issue:
            quality.append({**row, "quality_issue": issue})
    return quality


def render_pdf_if_available(pdf_path: Path, output_prefix: Path) -> str:
    renderer = shutil.which("pdftoppm")
    if renderer is None:
        return "not_run_pdftoppm_unavailable"
    output_prefix.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [renderer, "-f", "1", "-l", "3", "-png", "-r", "120", str(pdf_path), str(output_prefix)],
        check=True,
    )
    return "rendered_first_three_pages"


def rows_from_meta(year: str, meta_name: str, pdf_name: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with open(META_DIR / meta_name, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            label = (row.get("label") or "").strip()
            if not label or label == "樣本編號":
                continue
            match = META_Q_RE.match(label)
            if match:
                qid = match.group("qid")
                qtext = match.group("text").strip() or label
            else:
                qid = row.get("variable", "").strip()
                qtext = label
            rows.append(
                {
                    "year": year,
                    "source_pdf": pdf_name,
                    "question_id": qid,
                    "question_text": qtext,
                    "option_code": "",
                    "option_text": "",
                    "extraction_note": "scan_pdf_no_ocr_question_from_metadata_only",
                }
            )
    return rows


def write_csv(path: Path, rows: Iterable[dict[str, str]]) -> None:
    fieldnames = [
        "year",
        "source_pdf",
        "question_id",
        "question_text",
        "option_code",
        "option_text",
        "extraction_note",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> None:
    pdf_map = {
        "95": "ques95.pdf",
        "99": "ques99.pdf",
        "103": "ques103.pdf",
        "106": "ques106.pdf",
        "110": "ques110.pdf",
    }
    all_quality_rows: list[dict[str, str]] = []
    render_status_rows: list[dict[str, str]] = []
    for year, pdf_name in pdf_map.items():
        rows = rows_from_pdf(year, pdf_name)
        write_csv(OUT_DIR / f"question_options_{year}.csv", rows)
        all_quality_rows.extend(build_quality_rows(rows))
        render_status_rows.append(
            {
                "year": year,
                "source_pdf": pdf_name,
                "render_status": render_pdf_if_available(
                    PDF_DIR / pdf_name, ROOT / "tmp" / "pdfs" / f"{Path(pdf_name).stem}_preview"
                ),
            }
        )

    rows_91_1 = rows_from_meta("91_1", "meta_91_1.csv", "ques91-1.pdf")
    write_csv(OUT_DIR / "question_options_91_1.csv", rows_91_1)

    rows_91_2 = rows_from_meta("91_2", "meta_91_2.csv", "ques91-2.pdf")
    write_csv(OUT_DIR / "question_options_91_2.csv", rows_91_2)
    write_csv(OUT_DIR / "question_options_91.csv", [*rows_91_1, *rows_91_2])

    CHECK_DIR.mkdir(parents=True, exist_ok=True)
    quality_fields = [
        "year", "source_pdf", "question_id", "question_text", "option_code",
        "option_text", "extraction_note", "quality_issue",
    ]
    with (CHECK_DIR / "check_question_option_extraction.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as f:
        writer = csv.DictWriter(f, fieldnames=quality_fields)
        writer.writeheader()
        writer.writerows(all_quality_rows)
    with (CHECK_DIR / "check_questionnaire_pdf_render.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as f:
        writer = csv.DictWriter(f, fieldnames=["year", "source_pdf", "render_status"])
        writer.writeheader()
        writer.writerows(render_status_rows)


if __name__ == "__main__":
    main()
