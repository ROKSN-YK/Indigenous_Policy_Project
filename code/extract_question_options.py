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

STANDARD_103_J7_AMOUNT_OPTIONS = (
    ("1", "999 元及以下"),
    ("2", "1,000-1,999 元"),
    ("3", "2,000-2,999 元"),
    ("4", "3,000-3,999 元"),
    ("5", "4,000-4,999 元"),
    ("6", "5,000-6,999 元"),
    ("7", "7,000-9,999 元"),
    ("8", "10,000-14,999 元"),
    ("9", "15,000-19,999 元"),
    ("10", "20,000-29,999 元"),
    ("11", "30,000 元及以上，請記錄________元"),
)

MANUAL_91_MONEY_OPTIONS = {
    "19": (
        ("1", "未滿1千元"), ("2", "1千元至未滿3千元"),
        ("3", "3千元至未滿5千元"), ("4", "5千元至未滿7千元"),
        ("5", "7千元至未滿1萬元"), ("6", "1萬元至未滿2萬元"),
        ("6", "2萬元以上（請記錄金額）"),
    ),
    "20-1": (
        ("1", "未滿5千元"), ("2", "5千元至未滿1萬元"),
        ("3", "1萬元至未滿2萬元"), ("4", "2萬元至未滿3萬元"),
        ("5", "3萬元至未滿4萬元"), ("6", "4萬元至未滿5萬元"),
        ("7", "5萬元至未滿6萬元"), ("8", "6萬元至未滿7萬元"),
        ("9", "7萬元至未滿8萬元"), ("10", "8萬元至未滿9萬元"),
        ("11", "9萬元至未滿10萬元"), ("12", "10萬元以上（請記錄金額）"),
    ),
    "21": (
        ("1", "未滿2萬元"), ("2", "2萬元至未滿4萬元"),
        ("3", "4萬元至未滿6萬元"), ("4", "6萬元至未滿8萬元"),
        ("5", "8萬元至未滿10萬元"), ("6", "10萬元至未滿12萬元"),
        ("7", "12萬元至未滿15萬元"), ("8", "15萬元以上（請記錄金額）"),
    ),
    "22-1": (
        ("1", "未滿2萬元"), ("2", "2萬元至未滿4萬元"),
        ("3", "4萬元至未滿6萬元"), ("4", "6萬元至未滿8萬元"),
        ("5", "8萬元至未滿10萬元"), ("6", "10萬元至未滿12萬元"),
        ("7", "12萬元至未滿15萬元"), ("8", "15萬元以上（請記錄金額）"),
    ),
    "22-2": (
        ("1", "未滿2,000元"), ("2", "2,000元至未滿4,000元"),
        ("3", "4,000元至未滿6,000元"), ("4", "6,000元至未滿1萬元"),
        ("5", "1萬元至未滿1萬5,000元"), ("6", "1萬5,000元至未滿2萬元"),
        ("7", "2萬元至未滿3萬元"), ("8", "3萬元以上（請記錄金額）"),
        ("9", "沒有這項收入"),
    ),
    "22-3": (
        ("1", "未滿5,000元"), ("2", "5,000元至未滿1萬元"),
        ("3", "1萬元至未滿2萬元"), ("4", "2萬元至未滿3萬元"),
        ("5", "3萬元至未滿4萬元"), ("6", "4萬元至未滿5萬元"),
        ("7", "5萬元至未滿6萬元"), ("8", "6萬元以上（請記錄金額）"),
        ("9", "沒有其他收入"),
    ),
    "23": (
        ("1", "未滿2萬元"), ("2", "2萬元至未滿3萬元"),
        ("3", "3萬元至未滿4萬元"), ("4", "4萬元至未滿5萬元"),
        ("5", "5萬元至未滿6萬元"), ("6", "6萬元至未滿7萬元"),
        ("7", "7萬元至未滿8萬元"), ("8", "8萬元以上（請記錄金額）"),
    ),
    "23-1": (
        ("1", "未滿3,000元"), ("2", "3,000元至未滿5,000元"),
        ("3", "5,000元至未滿1萬元"), ("4", "1萬元至未滿2萬元"),
        ("5", "2萬元至未滿3萬元"), ("6", "3萬元至未滿4萬元"),
        ("7", "4萬元至未滿5萬元"), ("8", "5萬元以上（請記錄金額）"),
    ),
}

for _qid in ("23-2", "23-3", "23-4", "23-5", "23-6"):
    MANUAL_91_MONEY_OPTIONS[_qid] = (
        ("1", "未滿1,000元"), ("2", "1,000元至未滿3,000元"),
        ("3", "3,000元至未滿5,000元"), ("4", "5,000元至未滿7,000元"),
        ("5", "7,000元至未滿1萬元"), ("6", "1萬元以上（請記錄金額）"),
        ("7", "無"),
    )

MANUAL_91_COMMON_OPTIONS = {
    "1": (("1", "男"), ("2", "女")),
    "2": (
        ("1", "15至未滿20歲"), ("2", "20至未滿30歲"),
        ("3", "30至未滿40歲"), ("4", "40至未滿50歲"),
        ("5", "50至未滿60歲"), ("6", "60歲以上"),
    ),
    "3": (
        ("1", "不識字"), ("2", "自修"), ("3", "國小"),
        ("4", "國（初）中"), ("5", "高中"),
        ("6", "高職（含五專前三年）"), ("7", "專科"),
        ("8", "大學"), ("9", "研究所或以上"),
    ),
    "5": (
        ("1", "未婚"), ("2", "有配偶（含與人同居）"),
        ("3", "離婚、分居"), ("4", "喪偶"),
    ),
    "6": (("1", "是"), ("2", "不是")),
    "9": (
        ("1", "農、林、漁、牧業"), ("2", "礦業及土石採取業"),
        ("3", "製造業"), ("4", "水電燃氣業"), ("5", "營造業"),
        ("6", "批發及零售業"), ("7", "住宿及餐飲業"),
        ("8", "運輸、倉儲及通信業"), ("9", "金融及保險業"),
        ("10", "不動產及租賃業"), ("11", "專業、科學及技術服務業"),
        ("12", "教育服務業"), ("13", "醫療保健及社會福利服務業"),
        ("14", "文化、運動及休閒服務業"), ("15", "其他服務業"),
        ("16", "公共行政業"),
    ),
    "10": (
        ("1", "雇主"), ("2", "自營作業者"), ("3", "受政府僱用者"),
        ("4", "受私人僱用者"), ("5", "無酬家屬工作者"),
    ),
    "20": (("1", "有"), ("2", "沒有")),
    "24": (("1", "有"), ("2", "沒有")),
    "25": (("1", "希望"), ("2", "不希望")),
    "25-1": (
        ("1", "無法找到工作"), ("2", "小孩無人照顧"),
        ("3", "需要照顧其他家人或料理家事"),
        ("4", "改善經濟是我的責任"), ("5", "其他，請說明"),
    ),
    "26": (("1", "需要"), ("2", "不需要")),
    "26-1": (
        ("1", "提供職業訓練、輔導就業或轉業"),
        ("2", "提供短期低利貸款來協助自行創業"),
        ("3", "提供長期低利貸款來協助購屋或換屋"),
        ("4", "其他，請說明"),
    ),
    "27": (("1", "會"), ("2", "不會")),
    "27-2": (
        ("1", "沒有能力繳納利息"), ("2", "沒有需要"),
        ("3", "不知道作什麼用"), ("4", "找不到擔保品或擔保人"),
        ("5", "其他，請說明"),
    ),
}

MANUAL_91_VERSION_OPTIONS = {
    "91_1": {
        "4": tuple((str(i), label) for i, label in enumerate(
            ("阿美族", "泰雅族", "排灣族", "魯凱族", "布農族",
             "賽夏族", "雅美族", "卑南族", "鄒族", "邵族"), 1
        )),
        "6-1": tuple((str(i), label) for i, label in enumerate(
            ("阿美族", "泰雅族", "排灣族", "魯凱族", "布農族",
             "賽夏族", "雅美族", "卑南族", "鄒族", "邵族"), 1
        )),
        "8": tuple((str(i), label) for i, label in enumerate(
            ("民意代表、行政主管、企業主管及經理人員", "專業人員",
             "技術員及助理專業人員", "事務工作人員", "服務工作人員及售貨員",
             "農林漁牧工作人員", "技術工及有關工作人員",
             "機械設備操作工及組裝工", "非技術工及體力工", "無工作、退休"), 1
        )),
        "16": tuple((str(i), label) for i, label in enumerate(
            ("鋼筋混凝土造", "磚造", "木造", "石造", "土造", "竹（草）造", "其他"), 1
        )),
        "18": (
            ("1", "自有（跳答20題）"), ("2", "租賃（續答19題）"),
            ("3", "配住（續答19題）"), ("4", "借用（跳答21題）"),
        ),
    },
    "91_2": {
        "4": tuple((str(i), label) for i, label in enumerate(
            ("阿美族", "泰雅族", "排灣族", "魯凱族", "布農族",
             "賽夏族", "雅美族", "卑南族", "鄒族", "邵族", "噶瑪蘭族"), 1
        )),
        "6-1": tuple((str(i), label) for i, label in enumerate(
            ("阿美族", "泰雅族", "排灣族", "魯凱族", "布農族",
             "賽夏族", "雅美族", "卑南族", "鄒族", "邵族", "噶瑪蘭族"), 1
        )),
        "8": tuple((str(i), label) for i, label in enumerate(
            ("民意代表、行政主管、企業主管及經理人員", "專業人員",
             "技術員及助理專業人員", "事務工作人員", "服務工作人員及售貨員",
             "農林漁牧工作人員", "技術工及有關工作人員",
             "機械設備操作工及組裝工", "非技術工及體力工", "無工作",
             "退休", "家庭管理", "學生"), 1
        )),
        "16": tuple((str(i), label) for i, label in enumerate(
            ("鋼筋混凝土造", "磚造", "木造", "石造", "土造",
             "竹（草）造", "鐵皮屋", "其他"), 1
        )),
        "18": (
            ("1", "自有（跳答20題）"), ("2", "租賃（續答19題）"),
            ("3", "配住（續答19題）"), ("4", "借用（跳答21題）"),
            ("5", "未經許可自行搭建（跳答21題）"),
        ),
    },
}

MANUAL_91_OPEN_RESPONSE_IDS = {
    "7", "11", "12", "13", "14", "15", "17", "27-1",
}


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
    repaired: list[dict[str, str]] = []
    for row in rows:
        item = dict(row)
        code = item["option_code"].strip()
        text = item["option_text"].strip()
        # In ques99.pdf the number before the thousands comma is captured inside
        # the checkbox parentheses.  It is an amount prefix, not an option code.
        false_prefix = year == "99" and (
            text.startswith("000") or
            (text.startswith("999") and code.isdigit() and int(code) >= 9)
        )
        if false_prefix:
            item["option_text"] = f"{code},{text}"
            item["option_code"] = ""
            item["extraction_note"] = "repaired_99_thousands_prefix_from_false_code"
        if year == "95" and item["question_id"] == "C10" and code == "2":
            item["option_text"] = "女性"
            item["extraction_note"] = "repaired_95_c10_footer_contamination"
        repaired.append(item)

    if year == "99":
        for qid in ("F1", "I1"):
            repaired = replace_question_options(
                repaired,
                question_id=qid,
                options=(("1", "是"), ("2", "不是")),
                note="manual_visual_review_yes_no_2026-07-26",
            )
        for qid in (f"J7-{i}" for i in range(1, 9)):
            repaired = replace_question_options(
                repaired,
                question_id=qid,
                options=STANDARD_103_J7_AMOUNT_OPTIONS,
                note="repaired_99_j7_amount_table_visual_review",
            )
        repaired = mark_question_note(
            repaired, ("I1-1",), "open_numeric_response_confirmed_2026-07-26"
        )
        repaired = mark_question_note(
            repaired, ("J7",), "parent_multiple_response_heading_confirmed_2026-07-26"
        )

    # ques103.pdf N4 is laid out in three visual columns.  Its text layer drops
    # the middle-column choices 7 and 8 even though visual inspection confirms
    # the standard sequence 專科 / 大學 / 研究所及以上.
    if year == "103":
        n4_rows = [row for row in repaired if row["question_id"] == "N4"]
        existing_codes = {row["option_code"].rstrip(".0") for row in n4_rows}
        if n4_rows:
            template = n4_rows[0]
            additions: list[dict[str, str]] = []
            for option_code, option_text in (("7", "專科"), ("8", "大學")):
                if option_code not in existing_codes:
                    additions.append(
                        {
                            **template,
                            "option_code": option_code,
                            "option_text": option_text,
                            "extraction_note": "repaired_103_n4_visual_column_omission",
                        }
                    )
            if additions:
                insert_at = next(
                    (
                        index for index, row in enumerate(repaired)
                        if row["question_id"] == "N4"
                        and row["option_code"].rstrip(".0") == "9"
                    ),
                    len(repaired),
                )
                repaired[insert_at:insert_at] = additions
        for qid in ("H2", "H3"):
            repaired = split_embedded_option_row(
                repaired,
                question_id=qid,
                first_code="11",
                first_label="20,000-29,999 元",
                extra_options=(
                    ("12", "30,000 元及以上，請記錄________元"),
                    ("13", "沒有這項收入"),
                ),
                note="repaired_103_h2_h3_embedded_options",
            )
        for qid in (f"J7-{i}" for i in range(1, 11)):
            repaired = replace_question_options(
                repaired,
                question_id=qid,
                options=STANDARD_103_J7_AMOUNT_OPTIONS,
                note="repaired_103_j7_amount_table_visual_review",
            )
        repaired = mark_question_note(
            repaired, ("I2-1",), "open_numeric_response_confirmed_2026-07-26"
        )
        repaired = mark_question_note(
            repaired, ("J7",), "parent_multiple_response_heading_confirmed_2026-07-26"
        )
    if year in {"106", "110"}:
        source_qid, target_qid = ("J1", "J2") if year == "106" else ("E1", "E2")
        repaired = split_embedded_next_question(
            repaired,
            source_qid=source_qid,
            target_qid=target_qid,
            target_marker=target_qid,
            target_question_text=(
                f"請問經濟戶長個人每個月接受「政府津貼補助、各種社會保險、"
                f"私人保險受益」收入總共是多少？【{year}年平均每個月的金額】"
            ),
            note=f"repaired_{year}_{source_qid}_{target_qid}_embedded_question",
        )
        j7_prefix = "M7" if year == "106" else "H7"
        for qid in (f"{j7_prefix}-{i}" for i in range(1, 11)):
            repaired = replace_question_options(
                repaired,
                question_id=qid,
                options=STANDARD_103_J7_AMOUNT_OPTIONS,
                note=f"repaired_{year}_{j7_prefix}_amount_table_visual_review",
            )
        open_qid = "H5" if year == "106" else "C5"
        repaired = mark_question_note(
            repaired, (open_qid,), "open_numeric_response_confirmed_2026-07-26"
        )
        repaired = mark_question_note(
            repaired,
            (j7_prefix,),
            "parent_multiple_response_heading_confirmed_2026-07-26",
        )
    return repaired


def replace_question_options(
    rows: list[dict[str, str]],
    *,
    question_id: str,
    options: Iterable[tuple[str, str]],
    note: str,
) -> list[dict[str, str]]:
    matching = [row for row in rows if row["question_id"] == question_id]
    if not matching:
        return rows
    template = matching[0]
    replacement = [
        {
            **template,
            "option_code": code,
            "option_text": text,
            "extraction_note": note,
        }
        for code, text in options
    ]
    output: list[dict[str, str]] = []
    inserted = False
    for row in rows:
        if row["question_id"] != question_id:
            output.append(row)
        elif not inserted:
            output.extend(replacement)
            inserted = True
    return output


def mark_question_note(
    rows: list[dict[str, str]],
    question_ids: Iterable[str],
    note: str,
) -> list[dict[str, str]]:
    target = set(question_ids)
    return [
        {**row, "extraction_note": note}
        if row["question_id"] in target and not row["option_text"]
        else row
        for row in rows
    ]


def split_embedded_option_row(
    rows: list[dict[str, str]],
    *,
    question_id: str,
    first_code: str,
    first_label: str,
    extra_options: Iterable[tuple[str, str]],
    note: str,
) -> list[dict[str, str]]:
    output: list[dict[str, str]] = []
    for row in rows:
        code = row["option_code"].strip().removesuffix(".0")
        if (
            row["question_id"] == question_id
            and code == first_code.removesuffix(".0")
            and "□(" in row["option_text"]
        ):
            output.append(
                {
                    **row,
                    "option_code": first_code,
                    "option_text": first_label,
                    "extraction_note": note,
                }
            )
            for extra_code, extra_text in extra_options:
                output.append(
                    {
                        **row,
                        "option_code": extra_code,
                        "option_text": extra_text,
                        "extraction_note": note,
                    }
                )
        else:
            output.append(row)
    return output


def split_embedded_next_question(
    rows: list[dict[str, str]],
    *,
    source_qid: str,
    target_qid: str,
    target_marker: str,
    target_question_text: str,
    note: str,
) -> list[dict[str, str]]:
    output: list[dict[str, str]] = []
    target_started = False
    for row in rows:
        if row["question_id"] != source_qid:
            output.append(row)
            continue
        text = row["option_text"]
        if target_marker in text:
            output.append(
                {
                    **row,
                    "option_text": text.split(target_marker, 1)[0].strip(),
                    "extraction_note": note,
                }
            )
            target_started = True
            continue
        if target_started:
            clean_text = text
            embedded_none = "□(13" in clean_text
            if embedded_none:
                clean_text = clean_text.split("□(13", 1)[0].strip()
            output.append(
                {
                    **row,
                    "question_id": target_qid,
                    "question_text": target_question_text,
                    "option_text": clean_text,
                    "extraction_note": note,
                }
            )
            if embedded_none:
                output.append(
                    {
                        **row,
                        "question_id": target_qid,
                        "question_text": target_question_text,
                        "option_code": "13",
                        "option_text": "沒有這項收入",
                        "extraction_note": note,
                    }
                )
                target_started = False
            continue
        output.append(row)
    return output


def build_quality_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    quality: list[dict[str, str]] = []
    for row in rows:
        text = row["option_text"]
        issue = ""
        if re.match(r"^000(?:\D|$)", text):
            issue = "suspected_missing_thousands_prefix"
        elif "□(" in text or "(" in text:
            issue = "embedded_option_not_split"
        elif (
            re.search(r"(?:收入|支出|租金)", row["question_text"])
            and not text
            and not row["extraction_note"].startswith(
                ("open_numeric_response_", "parent_multiple_response_heading_")
            )
        ):
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
    option_sets = {
        **MANUAL_91_COMMON_OPTIONS,
        **MANUAL_91_VERSION_OPTIONS[year],
        **MANUAL_91_MONEY_OPTIONS,
    }
    for qid, options in option_sets.items():
        rows = replace_question_options(
            rows,
            question_id=qid,
            options=options,
            note="manual_visual_review_91_questionnaire_options_2026-07-26",
        )
    rows = mark_question_note(
        rows,
        MANUAL_91_OPEN_RESPONSE_IDS,
        "open_numeric_or_text_response_confirmed_2026-07-26",
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
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
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
    all_quality_rows.extend(build_quality_rows(rows_91_1))

    rows_91_2 = rows_from_meta("91_2", "meta_91_2.csv", "ques91-2.pdf")
    write_csv(OUT_DIR / "question_options_91_2.csv", rows_91_2)
    all_quality_rows.extend(build_quality_rows(rows_91_2))
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
