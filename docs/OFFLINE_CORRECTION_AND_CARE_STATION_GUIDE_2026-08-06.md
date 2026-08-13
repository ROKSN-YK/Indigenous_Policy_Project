# 2026-08-06 收支修正與文健站整併：離線逐步操作

## 本版處理內容

1. 2010 `INC_FAM_OTHER`：保留問卷題號 `I6`，以可稽核例外表解析到原始欄位 `i7`。
2. 2017 `EXP_CLOTHING`、`EXP_FURNITURE`、`EXP_OTHER`：106年問卷明載indicator代碼2為「沒有」，原始標籤亂碼時以年度專屬規則將該筆支出設為0；原金額衝突仍留在檢查表。
3. 2006未貼標籤數值若也是該題既有級距代碼，按級距處理，不誤當元金額。
4. 2014 RENT標籤尾端私用字元先清除，再解析閉區間。
5. 2014家庭收入：`I1=沒有`依問卷跳答I9列為結構性不適用；`I1=有`的個案正常納入，不再排除整個2014波次。不得把跳答者補成0。
6. 新增固定共同項指標：`INC_FAM_TOTAL_COMMON3_INCOME`與`EXP_TOTAL_COMMON5_EXPENDITURE`。
7. 由114年現存文健站清冊建立鄉鎮×民國年度panel，並在受限環境內併入個體資料。

## 攜入檔案

請將更新包中的 `code/`、`docs/`、`data/processed_data/03_crosswalks/`，以及
`data/raw_data/114年文健站營運單位清冊.csv` 合併到離線專案的相同位置。
不要覆蓋離線環境中的調查原始個體資料。

## 建議從收支步驟開始重跑

在專案根目錄開啟全新的R session：

```r
options(indigenous.pipeline.ready = NULL)
source("code/00-02-check-offline-transfer-bundle.R", encoding = "UTF-8")
source("code/00-01-validate-offline-inputs.R", encoding = "UTF-8")
source("code/00-03-archive-output-before-rerun.R", encoding = "UTF-8")

source("code/03-04-make-income-expense-data-from-02.R", encoding = "UTF-8")
source("code/03-05-build-care-station-town-year-panel.R", encoding = "UTF-8")
source("code/04-01-aggregate-cross-year-data.R", encoding = "UTF-8")
source("code/04-02-merge-care-station-exposure.R", encoding = "UTF-8")
source("code/05-01-summary-statistics.R", encoding = "UTF-8")
source("code/05-02-income-expenditure-recode-summary.R", encoding = "UTF-8")
source("code/05-99-validate-offline-pipeline.R", encoding = "UTF-8")
```

完整重跑亦可直接執行：

```r
Sys.setenv(RAW_DATA_DIR = "離線原始資料資料夾")
source("code/00-00-run-remote-pipeline.R", encoding = "UTF-8")
```

## 個體資料與可攜出資料

合併後個體檔為：

`data/processed_data/04_analysis_ready/cross_year_combined_with_care_station.rds`

此檔仍是個體層資料，不得攜出受限環境。程式預設不輸出個體CSV；不要設定
`EXPORT_STATION_MERGED_INDIVIDUAL_CSV=true`，除非只在受限環境內暫時檢查且能確保不攜出。

可攜出的是不含個體紀錄的檢查表與後續另行建立的鄉鎮年度聚合分析檔。

## 文健站暴露欄位

- `care_station_count`：調查年度累積站數。
- `care_station_new_count`：當年新成立站數。
- `care_station_any`：當年是否已有站。
- `care_station_first_year`：第一站成立年度。
- `care_station_years_since_first`、`care_station_event_time`：相對成立時間。
- `care_station_exposed_1y/3y/5y`：至少暴露1／3／5年。
- `care_station_match_status`：鄉鎮配對狀態。

2021只有四大區域，預期為 `geography_not_township`，不可放進鄉鎮層主模型。2002合併鄉鎮或缺鄉鎮者同樣不強制配對。

## 必查輸出

- `check_income_variable_mapping.csv`：2010 `INC_FAM_OTHER`須為`i7 / ok_override`。
- `check_two_stage_indicator_conflict.csv`：保留2017 indicator與金額衝突數供稽核。
- `check_structural_eligibility_i1.csv`：2014 I1分布及納入狀態。
- `check_care_station_panel_build.csv`：應為525站、122鄉鎮，且`has_110_panel=TRUE`。
- `check_care_station_merge_coverage.csv`：各年度地理配對率。
- `check_care_station_exposure_by_survey_year.csv`：各波暴露概況。
- `check_offline_pipeline_acceptance.csv`：不得有`fail`。

## 解讀限制

目前panel是依114年「現存」清冊的成立年度回推，可能漏掉過去已停辦或撤站的站點。研究中應標示為
「依114年現存清冊回推的文健站暴露」，取得歷年核定及停辦清冊後可替換panel來源，個體合併介面不需重寫。
