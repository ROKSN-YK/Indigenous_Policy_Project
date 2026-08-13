from __future__ import annotations

import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QUESTION_OPTIONS_DIR = ROOT / "data" / "processed_data" / "02_metadata" / "question_options"
CROSSWALK_DIR = ROOT / "data" / "processed_data" / "03_crosswalks"
UNIFIED_DEMOGRAPHIC_CROSSWALK = CROSSWALK_DIR / "unified_answer_crosswalk_basic_info.csv"
UNIFIED_INCOME_CROSSWALK = CROSSWALK_DIR / "unified_answer_crosswalk_income.csv"
UNIFIED_EXPENDITURE_CROSSWALK = CROSSWALK_DIR / "unified_answer_crosswalk_expenditure.csv"

YEARS = ("91_1", "91_2", "95", "99", "103", "106", "110")
HARMONIZED_YEAR = {
    "91_1": "91",
    "91_2": "91",
    "95": "95",
    "99": "99",
    "103": "103",
    "106": "106",
    "110": "110",
}
GREGORIAN_YEAR = {
    "91_1": "2002",
    "91_2": "2002",
    "95": "2006",
    "99": "2010",
    "103": "2014",
    "106": "2017",
    "110": "2021",
}


@dataclass(frozen=True)
class OptionRow:
    year: str
    source_pdf: str
    question_id: str
    question_text: str
    option_code: str
    option_text: str


@dataclass(frozen=True)
class ConceptSpec:
    concept_id: str
    concept_label: str
    domain: str
    base_question_ids_103: tuple[str, ...]
    question_ids_by_year: dict[str, tuple[str, ...]]
    comparison_level: str
    total_rule: str
    note: str


def load_question_options(year: str) -> list[OptionRow]:
    path = QUESTION_OPTIONS_DIR / f"question_options_{year}.csv"
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        rows = [
            OptionRow(
                year=row.get("year", year),
                source_pdf=row.get("source_pdf", ""),
                question_id=row.get("question_id", ""),
                question_text=row.get("question_text", ""),
                option_code=row.get("option_code", ""),
                option_text=row.get("option_text", ""),
            )
            for row in csv.DictReader(f)
        ]
    return repair_known_option_issues(year, rows)


def repair_known_option_issues(year: str, rows: list[OptionRow]) -> list[OptionRow]:
    # In 106/110 question option extraction, the personal government-benefit income
    # block was accidentally appended to the personal work-income block.
    if year == "106":
        rows = split_embedded_question_block(
            rows,
            source_qid="J1",
            target_qid="J2",
            target_question_marker="J2",
            target_question_text="請問經濟戶長個人每個月接受「政府津貼補助、各種社會保險、私人保險受益」收入總共是多少？【106年平均每個月的金額】",
        )
    if year == "110":
        rows = split_embedded_question_block(
            rows,
            source_qid="E1",
            target_qid="E2",
            target_question_marker="E2",
            target_question_text="請問經濟戶長個人每個月接受「政府津貼補助、各種社會保險、私人保險受益」收入總共是多少？【110年平均每個月的金額】",
        )
    rows = [sanitize_option_row(year, row) for row in rows]
    if year == "99":
        rows = repair_99_truncated_amount_text(rows)
    if year == "103":
        rows = split_embedded_same_question_options(
            rows,
            question_id="H2",
            first_code="11",
            first_label="20,000-29,999 元",
            extra_options=(("12", "30,000 元及以上，請記錄________元"), ("13", "沒有這項收入")),
        )
        rows = split_embedded_same_question_options(
            rows,
            question_id="H3",
            first_code="11",
            first_label="20,000-29,999 元",
            extra_options=(("12", "30,000 元及以上，請記錄________元"), ("13", "沒有這項收入")),
        )
    return rows


def sanitize_option_row(year: str, row: OptionRow) -> OptionRow:
    text = normalize_text(row.option_text)
    question_text = normalize_text(row.question_text)

    replacements = {
        "沒有這項收入": "沒有這項收入",
        "沒有這項支出": "沒有這項支出",
        "沒有在繳貸款": "沒有在繳貸款",
        "都沒有投資": "都沒有投資",
    }
    for marker, cleaned in replacements.items():
        if marker in text:
            text = cleaned
            break

    return OptionRow(
        year=year,
        source_pdf=row.source_pdf,
        question_id=row.question_id,
        question_text=question_text,
        option_code=row.option_code,
        option_text=text,
    )


def repair_99_truncated_amount_text(rows: list[OptionRow]) -> list[OptionRow]:
    repaired: list[OptionRow] = []
    for row in rows:
        text = row.option_text
        code = row.option_code.strip()
        false_prefix = text.startswith("000") or (
            text.startswith("999") and code.isdigit() and int(code) >= 9
        )
        if code and false_prefix:
            text = f"{code},{text}"
        repaired.append(
            OptionRow(
                year=row.year,
                source_pdf=row.source_pdf,
                question_id=row.question_id,
                question_text=row.question_text,
                option_code=row.option_code,
                option_text=text,
            )
        )
    return repaired


def split_embedded_same_question_options(
    rows: list[OptionRow],
    *,
    question_id: str,
    first_code: str,
    first_label: str,
    extra_options: tuple[tuple[str, str], ...],
) -> list[OptionRow]:
    repaired: list[OptionRow] = []
    for row in rows:
        normalized_code = row.option_code.strip().removesuffix(".0")
        normalized_first_code = first_code.strip().removesuffix(".0")
        if (
            row.question_id == question_id
            and normalized_code == normalized_first_code
            and "□(" in row.option_text
        ):
            repaired.append(
                OptionRow(
                    year=row.year,
                    source_pdf=row.source_pdf,
                    question_id=row.question_id,
                    question_text=row.question_text,
                    option_code=first_code,
                    option_text=first_label,
                )
            )
            for option_code, option_text in extra_options:
                repaired.append(
                    OptionRow(
                        year=row.year,
                        source_pdf=row.source_pdf,
                        question_id=row.question_id,
                        question_text=row.question_text,
                        option_code=option_code,
                        option_text=option_text,
                    )
                )
            continue
        repaired.append(row)
    return repaired


def split_embedded_question_block(
    rows: list[OptionRow],
    *,
    source_qid: str,
    target_qid: str,
    target_question_marker: str,
    target_question_text: str,
) -> list[OptionRow]:
    repaired: list[OptionRow] = []
    target_block_started = False

    for row in rows:
        if row.question_id != source_qid:
            repaired.append(row)
            continue

        if target_question_marker in row.option_text:
            clean_option_text = row.option_text.split(target_question_marker, 1)[0].strip()
            repaired.append(
                OptionRow(
                    year=row.year,
                    source_pdf=row.source_pdf,
                    question_id=row.question_id,
                    question_text=row.question_text,
                    option_code=row.option_code,
                    option_text=clean_option_text,
                )
            )
            target_block_started = True
            continue

        if target_block_started:
            option_code = row.option_code
            option_text = row.option_text
            if "□(13" in option_text:
                option_text = option_text.split("□(13", 1)[0].strip()
                repaired.append(
                    OptionRow(
                        year=row.year,
                        source_pdf=row.source_pdf,
                        question_id=target_qid,
                        question_text=target_question_text,
                        option_code=option_code,
                        option_text=option_text,
                    )
                )
                repaired.append(
                    OptionRow(
                        year=row.year,
                        source_pdf=row.source_pdf,
                        question_id=target_qid,
                        question_text=target_question_text,
                        option_code="13.0",
                        option_text="沒有這項收入",
                    )
                )
                target_block_started = False
                continue

            repaired.append(
                OptionRow(
                    year=row.year,
                    source_pdf=row.source_pdf,
                    question_id=target_qid,
                    question_text=target_question_text,
                    option_code=option_code,
                    option_text=option_text,
                )
            )
            continue

        repaired.append(row)

    return repaired


def build_question_index(rows: list[OptionRow]) -> dict[str, list[OptionRow]]:
    question_index: dict[str, list[OptionRow]] = defaultdict(list)
    for row in rows:
        question_index[row.question_id].append(row)
    return dict(question_index)


def option_sort_key(option: OptionRow) -> tuple[float, str]:
    try:
        code = float(option.option_code)
    except ValueError:
        code = float("inf")
    return (code, option.option_text)


def natural_question_key(question_id: str) -> tuple[tuple[int, int | str], ...]:
    return tuple(
        (0, int(token)) if token.isdigit() else (1, token)
        for token in question_id.split("-")
    )


def normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\u3000", " ")).strip()


def expand_chinese_amount_units(text: str) -> str:
    text = text.replace(",", "")
    text = re.sub(
        r"(\d+)萬(\d+)千",
        lambda match: str(int(match.group(1)) * 10000 + int(match.group(2)) * 1000),
        text,
    )
    text = re.sub(
        r"(\d+)萬(\d{1,4})(?=元|至|-|－|~|～)",
        lambda match: str(int(match.group(1)) * 10000 + int(match.group(2))),
        text,
    )
    return re.sub(
        r"(\d+)萬",
        lambda match: str(int(match.group(1)) * 10000),
        text,
    )


def parse_amount_range(text: str) -> tuple[int | None, int | None, str]:
    normalized = (
        expand_chinese_amount_units(text)
        .replace("，", "")
        .replace(" ", "")
        .replace("（", "(")
        .replace("）", ")")
        .replace("萬5000", "15000")
        .replace("一萬元", "10000元")
        .replace("千元", "000元")
        .replace("1千", "1000元")
        .replace("2千", "2000元")
        .replace("3千", "3000元")
        .replace("4千", "4000元")
        .replace("5千", "5000元")
        .replace("6千", "6000元")
        .replace("7千", "7000元")
        .replace("8千", "8000元")
        .replace("9千", "9000元")
        .replace("9999元及以下", "未滿10000元")
        .replace("4999元及以下", "未滿5000元")
        .replace("999元及以下", "未滿1000元")
        .replace("沒有這項收入", "無")
    )
    normalized = normalized.replace("元元", "元")
    if (
        "沒有這項收入" in normalized
        or "沒有這項支出" in normalized
        or normalized == "無"
        or normalized == "沒有其他收入"
    ):
        return (0, 0, "none")
    if "以上" in normalized:
        match = re.search(r"(\d+)元(?:及)?以上", normalized)
        if match:
            return (int(match.group(1)), None, "open_upper")
    match = re.search(r"(\d+)元(?:至|-|－)未滿(\d+)元", normalized)
    if match:
        return (int(match.group(1)), int(match.group(2)) - 1, "closed")
    match = re.search(r"(\d+)(?:元)?-(\d+)元", normalized)
    if match:
        return (int(match.group(1)), int(match.group(2)), "closed")
    match = re.search(r"(\d+)-未滿(\d+)元", normalized)
    if match:
        return (int(match.group(1)), int(match.group(2)) - 1, "closed")
    match = re.search(r"(\d+)元及以下", normalized)
    if match:
        return (0, int(match.group(1)), "closed")
    match = re.search(r"未滿(\d+)元", normalized)
    if match:
        return (0, int(match.group(1)) - 1, "closed")
    return (None, None, "text_only")


def mapping_relation(source_range: tuple[int | None, int | None, str], base_range: tuple[int | None, int | None, str]) -> str:
    s_min, s_max, s_kind = source_range
    b_min, b_max, b_kind = base_range
    if s_kind == "none" and b_kind == "none":
        return "exact_none"
    if s_kind == "none" or b_kind == "none":
        return "no_overlap"
    if "text_only" in (s_kind, b_kind):
        return "no_overlap"
    if s_kind == "open_upper" and b_kind == "open_upper" and s_min == b_min:
        return "exact_open_upper"
    if s_min == b_min and s_max == b_max:
        return "exact_range"
    overlap_low = max(s_min, b_min)
    overlap_high = min(s_max if s_max is not None else 10**12, b_max if b_max is not None else 10**12)
    if overlap_low <= overlap_high:
        if s_min >= b_min and (b_max is None or (s_max is not None and s_max <= b_max)):
            return "source_bin_within_base_bin"
        if b_min >= s_min and (s_max is None or (b_max is not None and b_max <= s_max)):
            return "source_bin_spans_multiple_base_bins"
        return "partial_overlap"
    return "no_overlap"


def combine_91_versions() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    rows_91_1 = load_question_options("91_1")
    rows_91_2 = load_question_options("91_2")
    keyed: dict[tuple[str, str, str], dict[str, str]] = {}

    for version, rows in (("91_1", rows_91_1), ("91_2", rows_91_2)):
        for row in rows:
            key = (row.question_id, row.option_code, row.option_text)
            current = keyed.setdefault(
                key,
                {
                    "year": "91",
                    "source_version": "",
                    "source_pdf": "",
                    "question_id": row.question_id,
                    "question_text": normalize_text(row.question_text),
                    "option_code": row.option_code,
                    "option_text": row.option_text,
                    "available_in_91_1": "0",
                    "available_in_91_2": "0",
                    "integration_note": "",
                },
            )
            current[f"available_in_{version}"] = "1"
            current["source_version"] = ";".join(v for v in ("91_1", "91_2") if current[f"available_in_{v}"] == "1")
            current["source_pdf"] = ";".join(
                sorted({candidate.source_pdf for candidate in rows_91_1 + rows_91_2 if candidate.question_id == row.question_id})
            )

    combined_rows = []
    for row in keyed.values():
        if row["available_in_91_1"] == "1" and row["available_in_91_2"] == "1":
            row["integration_note"] = "shared_in_both_versions"
        elif row["available_in_91_2"] == "1":
            row["integration_note"] = "version_specific_to_91_2"
        else:
            row["integration_note"] = "version_specific_to_91_1"
        combined_rows.append(row)

    combined_rows.sort(
        key=lambda row: (
            natural_question_key(row["question_id"]),
            row["option_code"],
            row["option_text"],
        )
    )

    idx_91_1 = build_question_index(rows_91_1)
    idx_91_2 = build_question_index(rows_91_2)
    notes = {
        "4": "91_2 新增噶瑪蘭族。",
        "6-1": "91_2 的配偶族別也新增噶瑪蘭族。",
        "8": "91_2 把無工作、退休、家庭管理、學生拆開。",
        "16": "91_2 新增鐵皮屋類別。",
        "18": "91_2 新增未經許可自行搭建。",
        "23-5": "91_2 新增教育/書報文具支出。",
        "23-6": "91_2 新增旅遊娛樂消遣支出。",
    }
    summary_rows = []
    for qid in sorted(set(idx_91_1) | set(idx_91_2), key=natural_question_key):
        options_91_1 = {(r.option_code, r.option_text) for r in idx_91_1.get(qid, [])}
        options_91_2 = {(r.option_code, r.option_text) for r in idx_91_2.get(qid, [])}
        if options_91_1 == options_91_2:
            status = "identical"
        elif options_91_1 and options_91_2:
            status = "same_question_with_version_difference"
        elif options_91_1:
            status = "91_1_only"
        else:
            status = "91_2_only"
        summary_rows.append(
            {
                "harmonized_year": "91",
                "question_id": qid,
                "status": status,
                "question_text_91_1": normalize_text(idx_91_1[qid][0].question_text) if qid in idx_91_1 else "",
                "question_text_91_2": normalize_text(idx_91_2[qid][0].question_text) if qid in idx_91_2 else "",
                "option_count_91_1": str(len(options_91_1)),
                "option_count_91_2": str(len(options_91_2)),
                "note": notes.get(qid, ""),
            }
        )
    return combined_rows, summary_rows


INCOME_SPECS = (
    ConceptSpec("INC_PERS_WORK", "個人工作/營業收入", "income", ("H1",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q10-1",), "99": ("H1",), "103": ("H1",), "106": ("J1",), "110": ("E1",)}, "option", "source_question", "95+ 同概念；106/110 對象為經濟戶長。"),
    ConceptSpec("INC_PERS_GOV", "個人政府津貼補助/保險收入", "income", ("H2",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q10-2",), "99": ("H2",), "103": ("H2",), "106": ("J2",), "110": ("E2",)}, "option", "source_question", "95+ 同概念；106/110 對象為經濟戶長。106/110 原始 question_options 有抽取錯位，已在建表時修補。"),
    ConceptSpec("INC_PERS_TRANSFER", "個人私人移轉/紅白包/救濟慰問收入", "income", ("H3",), {"91_1": tuple(), "91_2": tuple(), "95": tuple(), "99": tuple(), "103": ("H3",), "106": ("J3",), "110": ("E3",)}, "option", "source_question", "103+ 更明確；95 將其他收入拆成利息、租金、其他，未見此獨立項。106/110 對象為經濟戶長。"),
    ConceptSpec("INC_PERS_INTEREST", "個人利息/投資收入", "income", ("H4",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q10-3",), "99": ("H3",), "103": ("H4",), "106": ("J4",), "110": ("E4",)}, "option", "source_question", "99 H3 與 95 Q10-3 是利息、股票、投資收入；103+ 為存款/跟會/股票/投資利息。106/110 對象為經濟戶長。"),
    ConceptSpec("INC_PERS_RENT", "個人房屋土地租金收入", "income", ("H5",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q10-4",), "99": ("H4",), "103": ("H5",), "106": ("J5",), "110": ("E5",)}, "option", "source_question", "95+ 同概念；106/110 對象為經濟戶長。"),
    ConceptSpec("INC_PERS_OTHER", "個人其他收入", "income", ("H6",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q10-5",), "99": ("H5",), "103": ("H6",), "106": ("J6",), "110": ("E6",)}, "option", "source_question", "95+ 同概念；106/110 對象為經濟戶長。"),
    ConceptSpec("INC_FAM_TOTAL", "家庭總收入", "income", tuple(), {"91_1": ("21",), "91_2": ("21",), "95": tuple(), "99": tuple(), "103": tuple(), "106": tuple(), "110": tuple()}, "question_only", "source_question", "91 有家庭總收入級距；95 之後未單獨詢問家庭總收入。"),
    ConceptSpec("INC_FAM_WORK", "家庭工作收入", "income", ("I3",), {"91_1": ("22-1",), "91_2": ("22-1",), "95": ("Q11-1",), "99": ("I2",), "103": ("I3",), "106": ("L3",), "110": ("G3",)}, "option", "source_question", "以 103 年 I3 為基準。"),
    ConceptSpec("INC_FAM_GOV", "家庭政府補助與保險收入", "income", ("I4",), {"91_1": ("22-2",), "91_2": ("22-2",), "95": ("Q11-2",), "99": ("I3",), "103": ("I4",), "106": ("L4",), "110": ("G4",)}, "option", "source_question", "91 為政府補助及津貼；95 之後含各種保險。"),
    ConceptSpec("INC_FAM_TRANSFER", "家庭私人移轉/禮金/救濟收入", "income", ("I5",), {"91_1": tuple(), "91_2": tuple(), "95": tuple(), "99": tuple(), "103": ("I5",), "106": ("L5",), "110": ("G5",)}, "option", "source_question", "103 起拆出私人移轉類收入。"),
    ConceptSpec("INC_FAM_INTEREST", "家庭利息與投資收入", "income", ("I6",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q11-3",), "99": ("I4",), "103": ("I6",), "106": ("L6",), "110": ("G6",)}, "option", "source_question", "91 無獨立家庭利息投資題。"),
    ConceptSpec("INC_FAM_RENT", "家庭房屋土地租金收入", "income", ("I7",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q11-4",), "99": ("I5",), "103": ("I7",), "106": ("L7",), "110": ("G7",)}, "option", "source_question", "以 103 年 I7 為基準。"),
    ConceptSpec("INC_FAM_OTHER", "家庭其他收入", "income", ("I8",), {"91_1": ("22-3",), "91_2": ("22-3",), "95": ("Q11-5",), "99": ("I6",), "103": ("I8",), "106": ("L8",), "110": ("G8",)}, "concept", "source_question", "91 的其他收入較廣，混合利息、租金、民間補助、退休俸與奉養費。"),
)


EXPENDITURE_SPECS = (
    ConceptSpec("EXP_TOTAL_SYN", "家庭總支出（合成）", "expenditure", tuple(), {"91_1": ("23",), "91_2": ("23",), "95": ("Q12-1", "Q12-2", "Q12-3", "Q12-4", "Q12-5", "Q12-6", "Q12-7", "Q12-8", "Q12-9", "Q12-10", "Q12-11", "Q12-12", "Q12-13", "Q12-14"), "99": ("J1", "J2", "J3", "J4", "J5", "J6", "J7-1", "J7-2", "J7-3", "J7-4", "J7-5", "J7-6", "J7-7", "J7-8"), "103": ("J1", "J2", "J3", "J4", "J5", "J6", "J7-1", "J7-2", "J7-3", "J7-4", "J7-5", "J7-6", "J7-7", "J7-8", "J7-9", "J7-10"), "106": ("M1", "M2", "M3", "M4", "M5", "M6", "M7-1", "M7-2", "M7-3", "M7-4", "M7-5", "M7-6", "M7-7", "M7-8", "M7-9", "M7-10"), "110": ("H1", "H2", "H3", "H4", "H5", "H6", "H7-1", "H7-2", "H7-3", "H7-4", "H7-5", "H7-6", "H7-7", "H7-8", "H7-9", "H7-10")}, "derived_total", "sum_components_if_total_missing", "若問卷無總支出題，後續 R 以所有可比對支出分項加總為總支出。"),
    ConceptSpec("EXP_FOOD", "食品飲食支出", "expenditure", ("J1",), {"91_1": ("23-1",), "91_2": ("23-1",), "95": ("Q12-1",), "99": ("J1",), "103": ("J1",), "106": ("M1",), "110": ("H1",)}, "option", "source_question", "91 食品消費；95 之後為買菜/飲料/零食等。"),
    ConceptSpec("EXP_HOUSING_UTIL", "房租水電住宅相關支出", "expenditure", ("J2",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-2",), "99": ("J2",), "103": ("J2",), "106": ("M2",), "110": ("H2",)}, "option", "source_question", "91 無可直接對照之房租水電住宅支出分項。"),
    ConceptSpec("EXP_TRANSPORT_COMM", "交通與通訊支出", "expenditure", ("J3",), {"91_1": ("23-4",), "91_2": ("23-4",), "95": ("Q12-3",), "99": ("J3",), "103": ("J3",), "106": ("M3",), "110": ("H3",)}, "option", "source_question", "以 103 年 J3 為基準。"),
    ConceptSpec("EXP_MEDICAL", "醫療保健支出", "expenditure", ("J4",), {"91_1": ("23-3",), "91_2": ("23-3",), "95": ("Q12-4",), "99": ("J4",), "103": ("J4",), "106": ("M4",), "110": ("H4",)}, "option", "source_question", "以 103 年 J4 為基準。"),
    ConceptSpec("EXP_ALCOHOL", "菸酒檳榔支出", "expenditure", ("J5",), {"91_1": ("23-2",), "91_2": ("23-2",), "95": ("Q12-5",), "99": ("J5",), "103": ("J5",), "106": ("M5",), "110": ("H5",)}, "option", "source_question", "以 103 年 J5 為基準。"),
    ConceptSpec("EXP_TAX_INS_GIFT", "稅保險紅白包捐款等支出", "expenditure", ("J6",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-6",), "99": ("J6",), "103": ("J6",), "106": ("M6",), "110": ("H6",)}, "option", "source_question", "91 無可直接對照之分項。"),
    ConceptSpec("EXP_CLEANING", "家務清潔/請傭人支出", "expenditure", ("J7-1",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-7",), "99": ("J7-1",), "103": ("J7-1",), "106": ("M7-1",), "110": ("H7-1",)}, "option", "source_question", "95 起穩定出現。"),
    ConceptSpec("EXP_EDU_BOOKS_COMBINED", "教育、書報雜誌與文具合併支出", "expenditure", tuple(), {"91_1": tuple(), "91_2": ("23-5",), "95": ("Q12-8",), "99": ("J7-2",), "103": tuple(), "106": tuple(), "110": tuple()}, "concept", "source_question", "91_2、95、99 問卷為不可分拆的教育與書報文具合併題；總支出僅納入一次。"),
    ConceptSpec("EXP_EDU_TUITION", "學費補習家教支出", "expenditure", ("J7-2",), {"91_1": tuple(), "91_2": tuple(), "95": tuple(), "99": tuple(), "103": ("J7-2",), "106": ("M7-2",), "110": ("H7-2",)}, "concept", "source_question", "103 起才可與書報雜誌文具分拆。"),
    ConceptSpec("EXP_BOOKS", "書報雜誌文具支出", "expenditure", ("J7-3",), {"91_1": tuple(), "91_2": tuple(), "95": tuple(), "99": tuple(), "103": ("J7-3",), "106": ("M7-3",), "110": ("H7-3",)}, "concept", "source_question", "103 起才可與學費補習家教分拆。"),
    ConceptSpec("EXP_TRAVEL", "旅遊娛樂消遣支出", "expenditure", ("J7-4",), {"91_1": tuple(), "91_2": ("23-6",), "95": ("Q12-9",), "99": ("J7-3",), "103": ("J7-4",), "106": ("M7-4",), "110": ("H7-4",)}, "concept", "source_question", "各年文字略有不同，但屬同概念。"),
    ConceptSpec("EXP_LOAN_INTEREST", "貸款/跟會/利息支出", "expenditure", ("J7-5",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-10",), "99": ("J7-4",), "103": ("J7-5",), "106": ("M7-5",), "110": ("H7-5",)}, "concept", "source_question", "91 無獨立分項。"),
    ConceptSpec("EXP_DINING_LODGING", "外食與住宿服務支出", "expenditure", ("J7-6",), {"91_1": tuple(), "91_2": tuple(), "95": tuple(), "99": tuple(), "103": ("J7-6",), "106": ("M7-6",), "110": ("H7-6",)}, "option", "source_question", "103 起新增。"),
    ConceptSpec("EXP_CLOTHING", "衣著鞋襪支出", "expenditure", ("J7-7",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-11",), "99": ("J7-5",), "103": ("J7-7",), "106": ("M7-7",), "110": ("H7-7",)}, "concept", "source_question", "95 起穩定出現。"),
    ConceptSpec("EXP_FURNITURE", "家具家電廚具支出", "expenditure", ("J7-8",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-12",), "99": ("J7-6",), "103": ("J7-8",), "106": ("M7-8",), "110": ("H7-8",)}, "concept", "source_question", "95 起穩定出現。"),
    ConceptSpec("EXP_CARE", "兒童老人身障照顧支出", "expenditure", ("J7-9",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-13",), "99": ("J7-7",), "103": ("J7-9",), "106": ("M7-9",), "110": ("H7-9",)}, "concept", "source_question", "106/110 文案改成保姆費/安養院/身障者照顧。"),
    ConceptSpec("EXP_OTHER", "其他支出", "expenditure", ("J7-10",), {"91_1": tuple(), "91_2": tuple(), "95": ("Q12-14",), "99": ("J7-8",), "103": ("J7-10",), "106": ("M7-10",), "110": ("H7-10",)}, "concept", "source_question", "95 起穩定出現。"),
)


def question_rows(index: dict[str, list[OptionRow]], qids: tuple[str, ...]) -> list[OptionRow]:
    rows: list[OptionRow] = []
    for qid in qids:
        rows.extend(sorted(index.get(qid, []), key=option_sort_key))
    return rows


def make_derived_total_row(spec: ConceptSpec, source_year: str, data: dict[str, dict[str, list[OptionRow]]]) -> dict[str, str]:
    source_qids = spec.question_ids_by_year.get(source_year, tuple())
    available = [qid for qid in source_qids if qid in data[source_year]]
    base_qids = spec.question_ids_by_year.get("103", tuple())
    return {
        "domain": spec.domain,
        "concept_id": spec.concept_id,
        "concept_label": spec.concept_label,
        "harmonized_year": HARMONIZED_YEAR[source_year],
        "source_dataset": source_year,
        "source_question_ids": ";".join(source_qids),
        "source_question_texts": " | ".join(normalize_text(data[source_year][qid][0].question_text) for qid in available if data[source_year].get(qid)),
        "base_question_ids_103": ";".join(base_qids),
        "base_question_texts_103": " | ".join(normalize_text(data["103"][qid][0].question_text) for qid in base_qids if data["103"].get(qid)),
        "source_option_code": "",
        "source_option_text": "",
        "source_min_value": "",
        "source_max_value": "",
        "base_option_code_103": "",
        "base_option_text_103": "",
        "base_min_value_103": "",
        "base_max_value_103": "",
        "comparison_level": spec.comparison_level,
        "mapping_relation": "derived_total_from_components" if source_year != "91_1" and source_year != "91_2" else "reported_total_in_source",
        "total_construction_rule": "use_reported_total" if source_year in {"91_1", "91_2"} else "sum_of_component_amounts",
        "note": spec.note,
    }


def build_crosswalk(specs: tuple[ConceptSpec, ...]) -> list[dict[str, str]]:
    data = {year: build_question_index(load_question_options(year)) for year in YEARS}
    rows: list[dict[str, str]] = []

    for spec in specs:
        for source_year in YEARS:
            source_qids = spec.question_ids_by_year.get(source_year, tuple())
            base_qids = spec.base_question_ids_103

            if spec.comparison_level == "derived_total":
                rows.append(make_derived_total_row(spec, source_year, data))
                continue

            if not source_qids:
                rows.append(
                    {
                        "domain": spec.domain,
                        "concept_id": spec.concept_id,
                        "concept_label": spec.concept_label,
                        "harmonized_year": HARMONIZED_YEAR[source_year],
                        "source_dataset": source_year,
                        "source_question_ids": "",
                        "source_question_texts": "",
                        "base_question_ids_103": ";".join(base_qids),
                        "base_question_texts_103": " | ".join(normalize_text(data["103"][qid][0].question_text) for qid in base_qids if data["103"].get(qid)),
                        "source_option_code": "",
                        "source_option_text": "",
                        "source_min_value": "",
                        "source_max_value": "",
                        "base_option_code_103": "",
                        "base_option_text_103": "",
                        "base_min_value_103": "",
                        "base_max_value_103": "",
                        "comparison_level": spec.comparison_level,
                        "mapping_relation": "not_available_in_source_dataset",
                        "total_construction_rule": spec.total_rule,
                        "note": spec.note,
                    }
                )
                continue

            source_rows = question_rows(data[source_year], source_qids)
            base_rows = question_rows(data["103"], base_qids)
            source_texts = " | ".join(dict.fromkeys(normalize_text(r.question_text) for r in source_rows))
            base_texts = " | ".join(dict.fromkeys(normalize_text(r.question_text) for r in base_rows))

            if spec.comparison_level == "concept":
                rows.append(
                    {
                        "domain": spec.domain,
                        "concept_id": spec.concept_id,
                        "concept_label": spec.concept_label,
                        "harmonized_year": HARMONIZED_YEAR[source_year],
                        "source_dataset": source_year,
                        "source_question_ids": ";".join(source_qids),
                        "source_question_texts": source_texts,
                        "base_question_ids_103": ";".join(base_qids),
                        "base_question_texts_103": base_texts,
                        "source_option_code": "",
                        "source_option_text": "",
                        "source_min_value": "",
                        "source_max_value": "",
                        "base_option_code_103": "",
                        "base_option_text_103": "",
                        "base_min_value_103": "",
                        "base_max_value_103": "",
                        "comparison_level": spec.comparison_level,
                        "mapping_relation": "conceptual_match_requires_manual_recode",
                        "total_construction_rule": spec.total_rule,
                        "note": spec.note,
                    }
                )
                continue

            for source_row in source_rows:
                source_range = parse_amount_range(source_row.option_text)
                matched = False
                for base_row in base_rows:
                    base_range = parse_amount_range(base_row.option_text)
                    if source_range[2] == "text_only" and base_range[2] == "text_only":
                        source_text_key = normalize_text(source_row.option_text)
                        base_text_key = normalize_text(base_row.option_text)
                        if source_text_key.startswith("沒有"):
                            source_text_key = "沒有"
                        if base_text_key.startswith("沒有"):
                            base_text_key = "沒有"
                        relation = "exact_text" if source_text_key == base_text_key else "no_overlap"
                    else:
                        relation = mapping_relation(source_range, base_range)
                    if relation == "no_overlap":
                        continue
                    matched = True
                    rows.append(
                        {
                            "domain": spec.domain,
                            "concept_id": spec.concept_id,
                            "concept_label": spec.concept_label,
                            "harmonized_year": HARMONIZED_YEAR[source_year],
                            "source_dataset": source_year,
                            "source_question_ids": ";".join(source_qids),
                            "source_question_texts": source_texts,
                            "base_question_ids_103": ";".join(base_qids),
                            "base_question_texts_103": base_texts,
                            "source_option_code": source_row.option_code,
                            "source_option_text": source_row.option_text,
                            "source_min_value": "" if source_range[0] is None else str(source_range[0]),
                            "source_max_value": "" if source_range[1] is None else str(source_range[1]),
                            "base_option_code_103": base_row.option_code,
                            "base_option_text_103": base_row.option_text,
                            "base_min_value_103": "" if base_range[0] is None else str(base_range[0]),
                            "base_max_value_103": "" if base_range[1] is None else str(base_range[1]),
                            "comparison_level": spec.comparison_level,
                            "mapping_relation": relation,
                            "total_construction_rule": spec.total_rule,
                            "note": spec.note,
                        }
                    )
                if not matched:
                    rows.append(
                        {
                            "domain": spec.domain,
                            "concept_id": spec.concept_id,
                            "concept_label": spec.concept_label,
                            "harmonized_year": HARMONIZED_YEAR[source_year],
                            "source_dataset": source_year,
                            "source_question_ids": ";".join(source_qids),
                            "source_question_texts": source_texts,
                            "base_question_ids_103": ";".join(base_qids),
                            "base_question_texts_103": base_texts,
                            "source_option_code": source_row.option_code,
                            "source_option_text": source_row.option_text,
                            "source_min_value": "" if source_range[0] is None else str(source_range[0]),
                            "source_max_value": "" if source_range[1] is None else str(source_range[1]),
                            "base_option_code_103": "",
                            "base_option_text_103": "",
                            "base_min_value_103": "",
                            "base_max_value_103": "",
                            "comparison_level": spec.comparison_level,
                            "mapping_relation": "no_matching_103_option_bin",
                            "total_construction_rule": spec.total_rule,
                            "note": spec.note,
                        }
                    )

    return rows


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def repair_demographic_crosswalk() -> None:
    """Apply questionnaire-verified demographic mappings reproducibly."""
    with UNIFIED_DEMOGRAPHIC_CROSSWALK.open(
        "r", encoding="utf-8-sig", newline=""
    ) as stream:
        reader = csv.DictReader(stream)
        fieldnames = list(reader.fieldnames or [])
        rows = list(reader)

    target = [
        row for row in rows
        if row["data_year"] == "2014"
        and row["integrated_var"] == "EDU"
        and row["raw_var"].lower() == "n4"
    ]
    if not target:
        raise RuntimeError("Cannot repair 2014 EDU: N4 crosswalk rows are missing")

    target_indexes = [
        index for index, row in enumerate(rows)
        if row["data_year"] == "2014"
        and row["integrated_var"] == "EDU"
        and row["raw_var"].lower() == "n4"
        and row["raw_option_code"].rstrip(".0") in {"7", "8", "9"}
    ]
    insert_at = min(target_indexes) if target_indexes else len(rows)
    template = next(
        (row for row in target if row["raw_option_code"].rstrip(".0") == "9"),
        target[-1],
    )
    rows = [
        row for row in rows
        if not (
            row["data_year"] == "2014"
            and row["integrated_var"] == "EDU"
            and row["raw_var"].lower() == "n4"
            and row["raw_option_code"].rstrip(".0") in {"7", "8", "9"}
        )
    ]
    repaired_rows = []
    for code, text in (("7", "專科"), ("8", "大學"), ("9", "研究所及以上")):
        row = dict(template)
        row.update(
            {
                "raw_option_order": code,
                "raw_option_code": code,
                "raw_option_text": text,
                "unified_code": "5",
                "unified_label": "專科以上",
                "mapping_rule": "專科、大學、研究所合併",
                "row_note": "questionnaire_visual_review_confirmed_2026-07-25",
            }
        )
        repaired_rows.append(row)
    rows[insert_at:insert_at] = repaired_rows
    write_csv(UNIFIED_DEMOGRAPHIC_CROSSWALK, fieldnames, rows)


def comparison_level_to_mapping_type(level: str, relation: str) -> str:
    if level == "derived_total":
        return "derived_total"
    if relation == "not_available_in_source_dataset":
        return "question_not_available"
    if level == "concept":
        return "conceptual_only"
    if level == "question_only":
        return "question_only"
    return "range_overlap"


def build_unified_answer_crosswalk_rows(
    crosswalk_rows: list[dict[str, str]],
    *,
    category: str,
    source_file: str,
) -> list[dict[str, str]]:
    grouped_order: dict[tuple[str, str, str], int] = defaultdict(int)
    output_rows: list[dict[str, str]] = []
    preserved_source_bins: set[tuple[str, str, str]] = set()
    source_bins_to_preserve = {
        (row["source_dataset"], row["concept_id"], row["source_option_code"])
        for row in crosswalk_rows
        if row["mapping_relation"] in {
            "source_bin_spans_multiple_base_bins",
            "partial_overlap",
        }
        or (
            row["mapping_relation"] == "no_matching_103_option_bin"
            and row["source_min_value"] != ""
        )
    }

    for row in crosswalk_rows:
        key = (row["source_dataset"], row["concept_id"], row["source_option_code"])
        preserve_source_bin = key in source_bins_to_preserve
        if preserve_source_bin and key in preserved_source_bins:
            continue
        if preserve_source_bin:
            preserved_source_bins.add(key)
        if row["source_option_text"]:
            grouped_order[key] += 1
        raw_option_order = str(grouped_order[key]) if row["source_option_text"] else ""

        concept_note = row["note"]
        if row["base_question_ids_103"]:
            concept_note = f"{concept_note} 103基準題號：{row['base_question_ids_103']}。".strip()

        row_note_parts = []
        if row["mapping_relation"]:
            row_note_parts.append(f"mapping_relation={row['mapping_relation']}")
        if row["total_construction_rule"]:
            row_note_parts.append(f"total_rule={row['total_construction_rule']}")
        row_note = "; ".join(row_note_parts)
        resolved_category = category
        if row["concept_id"].startswith("INC_PERS_"):
            resolved_category = "個人收入"
        elif row["concept_id"].startswith("INC_FAM_"):
            resolved_category = "家庭收入"

        output_rows.append(
            {
                "source_file": source_file,
                "concept_id": row["concept_id"],
                "category": resolved_category,
                "integrated_var": row["concept_id"],
                "concept": row["concept_label"],
                "mapping_type": comparison_level_to_mapping_type(row["comparison_level"], row["mapping_relation"]),
                "data_year": GREGORIAN_YEAR[row["source_dataset"]],
                "option_year": row["source_dataset"],
                "raw_var": row["source_question_ids"],
                "matched_question_id": row["base_question_ids_103"],
                "raw_option_order": raw_option_order,
                "raw_option_code": row["source_option_code"],
                "raw_option_text": row["source_option_text"],
                "unified_code": row["source_option_code"] if preserve_source_bin else row["base_option_code_103"],
                "unified_label": row["source_option_text"] if preserve_source_bin else row["base_option_text_103"],
                "mapping_rule": "source_bin_preserved_for_numeric_recode" if preserve_source_bin else row["mapping_relation"],
                "question_text": row["source_question_texts"],
                "option_source_file": f"question_options_{row['source_dataset']}.csv",
                "concept_note": concept_note,
                "row_note": row_note,
            }
        )

    return output_rows


def main() -> None:
    repair_demographic_crosswalk()
    combined_91_rows, summary_rows = combine_91_versions()
    write_csv(
        QUESTION_OPTIONS_DIR / "question_options_91.csv",
        [
            "year",
            "source_version",
            "source_pdf",
            "question_id",
            "question_text",
            "option_code",
            "option_text",
            "available_in_91_1",
            "available_in_91_2",
            "integration_note",
        ],
        combined_91_rows,
    )
    write_csv(
        CROSSWALK_DIR / "questionnaire_91_version_summary.csv",
        [
            "harmonized_year",
            "question_id",
            "status",
            "question_text_91_1",
            "question_text_91_2",
            "option_count_91_1",
            "option_count_91_2",
            "note",
        ],
        summary_rows,
    )

    fieldnames = [
        "domain",
        "concept_id",
        "concept_label",
        "harmonized_year",
        "source_dataset",
        "source_question_ids",
        "source_question_texts",
        "base_question_ids_103",
        "base_question_texts_103",
        "source_option_code",
        "source_option_text",
        "source_min_value",
        "source_max_value",
        "base_option_code_103",
        "base_option_text_103",
        "base_min_value_103",
        "base_max_value_103",
        "comparison_level",
        "mapping_relation",
        "total_construction_rule",
        "note",
    ]

    write_csv(CROSSWALK_DIR / "income_crosswalk_103base.csv", fieldnames, build_crosswalk(INCOME_SPECS))
    write_csv(CROSSWALK_DIR / "expenditure_crosswalk_103base.csv", fieldnames, build_crosswalk(EXPENDITURE_SPECS))

    income_rows = build_crosswalk(INCOME_SPECS)
    expenditure_rows = build_crosswalk(EXPENDITURE_SPECS)

    unified_fieldnames = [
        "source_file",
        "concept_id",
        "category",
        "integrated_var",
        "concept",
        "mapping_type",
        "data_year",
        "option_year",
        "raw_var",
        "matched_question_id",
        "raw_option_order",
        "raw_option_code",
        "raw_option_text",
        "unified_code",
        "unified_label",
        "mapping_rule",
        "question_text",
        "option_source_file",
        "concept_note",
        "row_note",
    ]
    write_csv(
        UNIFIED_INCOME_CROSSWALK,
        unified_fieldnames,
        build_unified_answer_crosswalk_rows(
            income_rows,
            category="家庭收入",
            source_file="build_income_expenditure_crosswalk.py",
        ),
    )
    write_csv(
        UNIFIED_EXPENDITURE_CROSSWALK,
        unified_fieldnames,
        build_unified_answer_crosswalk_rows(
            expenditure_rows,
            category="家庭支出",
            source_file="build_income_expenditure_crosswalk.py",
        ),
    )


if __name__ == "__main__":
    main()
