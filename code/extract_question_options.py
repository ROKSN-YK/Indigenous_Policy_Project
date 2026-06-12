from __future__ import annotations

import csv
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pdfplumber


ROOT = Path(__file__).resolve().parents[1]
PDF_DIR = ROOT / "docs" / "codebooks"
META_DIR = ROOT / "outputs" / "meta"
OUT_DIR = ROOT / "outputs" / "question_options"

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
    return cleaned


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
    return rows


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
    for year, pdf_name in pdf_map.items():
        rows = rows_from_pdf(year, pdf_name)
        write_csv(OUT_DIR / f"question_options_{year}.csv", rows)

    rows_91_1 = rows_from_meta("91_1", "meta_91_1.csv", "ques91-1.pdf")
    write_csv(OUT_DIR / "question_options_91_1.csv", rows_91_1)

    rows_91_2 = rows_from_meta("91_2", "meta_91_2.csv", "ques91-2.pdf")
    write_csv(OUT_DIR / "question_options_91_2.csv", rows_91_2)
    write_csv(OUT_DIR / "question_options_91.csv", [*rows_91_1, *rows_91_2])


if __name__ == "__main__":
    main()
