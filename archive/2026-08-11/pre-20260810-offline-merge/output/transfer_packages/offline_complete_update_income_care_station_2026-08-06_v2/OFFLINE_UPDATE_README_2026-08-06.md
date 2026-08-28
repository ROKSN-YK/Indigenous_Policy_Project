# 請先看：2026-08-06 收支修正＋文健站整併完整更新包

這不是上次離線攜出資料的備份。本包包含可覆蓋到離線專案的程式、規則、文健站輸入資料及預先建好的鄉鎮年度panel。

## 一眼辨識本包的新檔

### 文健站

- `data/raw_data/114年文健站營運單位清冊.csv`：525站原始清冊。
- `data/processed_data/05_reference/care_station_town_year_panel_long.csv`：122鄉鎮×民國90–114年的預建panel，包含民國110年。
- `code/03-05-build-care-station-town-year-panel.R`：在離線環境重建panel。
- `code/04-02-merge-care-station-exposure.R`：以縣市、鄉鎮、調查年度併入個體資料。

### 本輪收支修正

- `data/processed_data/03_crosswalks/dataset_variable_overrides.csv`：2010 `INC_FAM_OTHER`的`I6→i7`。
- `data/processed_data/03_crosswalks/two_stage_indicator_overrides.csv`：2017三項支出的indicator修正。
- `code/03-04-make-income-expense-data-from-02.R`：套用欄位例外、indicator與未貼標籤代碼規則。
- `code/04-01-aggregate-cross-year-data.R`：加入2014家庭收入分析資格旗標。
- `code/05-02-income-expenditure-recode-summary.R`：修正RENT亂碼並建立固定共同項總額。
- `code/05-99-validate-offline-pipeline.R`：加入上述修正與文健站合併驗收。

## 使用方式

將壓縮包內容合併到離線專案根目錄；不要刪除或覆蓋離線環境中的調查原始個體資料。接著依
`docs/OFFLINE_CORRECTION_AND_CARE_STATION_GUIDE_2026-08-06.md`逐步執行。

合併後個體檔為：

`data/processed_data/04_analysis_ready/cross_year_combined_with_care_station.rds`

該RDS不得攜出受限環境。預建的文健站panel與聚合檢查表不含調查個體資料。

