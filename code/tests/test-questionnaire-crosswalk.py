from __future__ import annotations

import csv
import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read_rows(relative_path: str) -> list[dict[str, str]]:
    with (ROOT / relative_path).open("r", encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def question_options(year: str, question_id: str) -> list[tuple[str, str]]:
    rows = read_rows(
        f"data/processed_data/02_metadata/question_options/question_options_{year}.csv"
    )
    return [
        (row["option_code"], row["option_text"])
        for row in rows
        if row["question_id"] == question_id
    ]


def assert_codes(year: str, question_id: str, expected: list[str]) -> None:
    actual = [code for code, _ in question_options(year, question_id)]
    assert actual == expected, f"{year} {question_id}: expected {expected}, got {actual}"


def main() -> None:
    for version in ("91_1", "91_2"):
        assert question_options(version, "1") == [("1", "男"), ("2", "女")]
        assert_codes(version, "3", [str(i) for i in range(1, 10)])
        assert_codes(version, "19", ["1", "2", "3", "4", "5", "6", "6"])
        assert_codes(version, "20-1", [str(i) for i in range(1, 13)])
    assert_codes("91_1", "4", [str(i) for i in range(1, 11)])
    assert_codes("91_2", "4", [str(i) for i in range(1, 12)])
    assert_codes("91_1", "18", [str(i) for i in range(1, 5)])
    assert_codes("91_2", "18", [str(i) for i in range(1, 6)])

    assert question_options("95", "C10") == [("1", "男性"), ("2", "女性")]

    for version in ("91_1", "91_2"):
        assert_codes(version, "21", [str(i) for i in range(1, 9)])
        assert_codes(version, "22-2", [str(i) for i in range(1, 10)])
        assert_codes(version, "23", [str(i) for i in range(1, 9)])
    assert not question_options("91_1", "23-5")
    assert_codes("91_2", "23-5", [str(i) for i in range(1, 8)])
    assert_codes("91_2", "23-6", [str(i) for i in range(1, 8)])

    for qid in ("H2", "H3"):
        assert_codes("103", qid, [str(i) for i in range(1, 14)])
        options = dict(question_options("103", qid))
        assert options["11"] == "20,000-29,999 元"
        assert options["12"].startswith("30,000 元及以上")
        assert options["13"] == "沒有這項收入"

    for year, prefix, count in (
        ("99", "J7", 8),
        ("103", "J7", 10),
        ("106", "M7", 10),
        ("110", "H7", 10),
    ):
        for index in range(1, count + 1):
            assert_codes(year, f"{prefix}-{index}", [str(i) for i in range(1, 12)])

    assert question_options("103", "N4")[6:] == [
        ("7", "專科"), ("8", "大學"), ("9", "研究所及以上")
    ]

    income_rows = read_rows(
        "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv"
    )
    for qid in ("H2", "H3"):
        rows = [
            row for row in income_rows
            if row["data_year"] == "2014" and row["matched_question_id"] == qid
        ]
        assert [row["raw_option_code"] for row in rows] == [
            str(i) for i in range(1, 14)
        ]
        assert rows[-3]["mapping_rule"] == "exact_range"
        assert rows[-2]["mapping_rule"] == "exact_open_upper"
        assert rows[-1]["mapping_rule"] == "exact_none"

    module_path = ROOT / "code" / "build_income_expenditure_crosswalk.py"
    spec = importlib.util.spec_from_file_location("crosswalk_builder", module_path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    assert module.parse_amount_range("1萬5,000元至未滿2萬元") == (
        15000, 19999, "closed"
    )

    assert not read_rows("output/checks/check_question_option_extraction.csv")

    print("Questionnaire and crosswalk tests passed.")


if __name__ == "__main__":
    main()
