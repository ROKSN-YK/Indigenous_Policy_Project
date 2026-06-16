from __future__ import annotations

import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QUESTION_OPTIONS_DIR = ROOT / "data" / "processed_data" / "02_metadata" / "question_options"
CROSSWALK_DIR = ROOT / "data" / "processed_data" / "03_crosswalks"

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
        return [OptionRow(**row) for row in csv.DictReader(f)]


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


def normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\u3000", " ")).strip()


def parse_amount_range(text: str) -> tuple[int | None, int | None, str]:
    normalized = (
        text.replace(",", "")
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
        .replace("1萬", "10000元")
        .replace("2萬", "20000元")
        .replace("3萬", "30000元")
        .replace("4萬", "40000元")
        .replace("5萬", "50000元")
        .replace("6萬", "60000元")
        .replace("7萬", "70000元")
        .replace("8萬", "80000元")
        .replace("9萬", "90000元")
        .replace("10萬", "100000元")
        .replace("12萬", "120000元")
        .replace("15萬", "150000元")
        .replace("16萬", "160000元")
        .replace("20萬", "200000元")
        .replace("30萬", "300000元")
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
    if None in (s_min, b_min):
        return "text_only_review"
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

    combined_rows.sort(key=lambda row: ([int(t) if t.isdigit() else t for t in row["question_id"].split("-")], row["option_code"], row["option_text"]))

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
    for qid in sorted(set(idx_91_1) | set(idx_91_2), key=lambda x: [int(t) if t.isdigit() else t for t in x.split("-")]):
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
    ConceptSpec("EXP_EDU_TUITION", "學費補習家教支出", "expenditure", ("J7-2",), {"91_1": tuple(), "91_2": ("23-5",), "95": ("Q12-8",), "99": ("J7-2",), "103": ("J7-2",), "106": ("M7-2",), "110": ("H7-2",)}, "concept", "source_question", "91_2 與 95/99 將學費與書報文具合併；103 起拆成學費補習家教。"),
    ConceptSpec("EXP_BOOKS", "書報雜誌文具支出", "expenditure", ("J7-3",), {"91_1": tuple(), "91_2": ("23-5",), "95": ("Q12-8",), "99": ("J7-2",), "103": ("J7-3",), "106": ("M7-3",), "110": ("H7-3",)}, "concept", "source_question", "91_2 與 95/99 合併於教育書報文具。"),
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
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
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


if __name__ == "__main__":
    main()
