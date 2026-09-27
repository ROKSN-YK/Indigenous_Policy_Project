# Repository inspection（Step 0）

## Canonical 與資料狀態

- **OBSERVED** canonical household-level 候選：`data/processed_data/04_analysis_ready/cross_year_combined_with_care_station.rds`（5409 列、年度：2021）。
- **OBSERVED** 具可用鄉鎮地理的 canonical 列數：0。2021 僅四大區域，不能與鄉鎮文健站 panel 配對。
- **OBSERVED** imported survey index 僅列：2021；`survey_datasets.rds` 同樣僅含 2021。
- **DOCUMENTED** 2002–2021 六波曾於受限離線環境運行；其聚合檢查表位於 `archive/2026-08-11/20260810-offline-run/output/summary_statistics/sample_by_year.csv`，但 repository 不含 2002–2017 household microdata。
- **INFERRED** 現存 household canonical 不是本研究 2006–2017 主視窗可直接使用的跨波 canonical；archive 的鄉鎮邊際彙總只能支持部分診斷。

## Discovered definitions and files

- station town-year panel：`data/processed_data/05_reference/care_station_town_year_panel_long.csv`。
- treatment first year：`care_station_first_year`（民國年）；來源為 114 年現存營運清冊回推。
- survey year：`DATA_Y`（西元年）；station panel 對應欄為 `survey_roc_year`（民國年）。
- township key：`CITY + COUNTY`；不得只用鄉鎮名稱。
- Indigenous household/member counts：`N_INDI` 及 F14 年齡格。
- 55+ rule：`N_INDI_55_64 + N_INDI_65PLUS > 0`；程式證據 `code/03-03-make-family-data-from-02.R`。
- medical outcome：`EXP_MEDICAL_EXPENDITURE`；級距以中點、開放金額優先，非精確連續金額。
- survey weights：候選欄位見 `data/processed_data/03_crosswalks/manual_question_crosswalk.tsv`；跨波定義未齊，故本批不計 weighted count。
- care outcome：`EXP_CARE_EXPENDITURE`；food outcome：`EXP_FOOD_EXPENDITURE`。
- questionnaire PDFs：`docs/codebooks/ques95.pdf`、`ques99.pdf`、`ques103.pdf`、`ques106.pdf`。
- expenditure crosswalk：`data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv`。
- existing policy scripts：`code/03-05-build-care-station-town-year-panel.R`、`code/04-02-merge-care-station-exposure.R`。
- existing summary scripts：`code/05-01-summary-statistics.R`、`code/05-02-income-expenditure-recode-summary.R`。
- existing DID note：`data/processed_data/01_documentation/DID_ANALYSIS_GUIDE.md`；未發現已完成的 Callaway–Sant’Anna 或 eligibility DDD 程式。

## Material limitations

- **BLOCKED — MISSING JOINT MICRODATA**：archive 只保留各變數的鄉鎮邊際分布，無法把 eligibility 與 medical outcome 交叉。
- **BLOCKED — WEIGHT DEFINITION AMBIGUITY**：權數名稱與定義跨波不同，尚無逐波可比性認定。
- **WARNING — HISTORICAL ROSTER**：registry-external 代表不在 114 年現存清冊，不等於經證實 never-treated。
- **WARNING — COHORT BINNING**：本診斷把 canonical first year 映射至『下一個調查波首次可觀察為已處置』；若研究者意指精確成立年度 cohort，需另行決定。
