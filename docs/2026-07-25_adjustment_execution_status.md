# 資料調整計劃執行狀態

更新日期：2026-07-25

## 已完成

- `indigenous_analysis_sample` 改為對 2014、2017、2021 套用族別篩選，並記錄各年是否套用、排除非原住民族及排除族別缺失的筆數。
- 金額 parser 支援 `1萬5千` 等混合單位，修正「萬元以上」被截成個位數。
- `無此消費`、`無此收入` 改為確定 0；`未回答`、`不知道/拒答` 改為 response missing。
- 2021 (`110_present`) 納入兩個 coverage presence lookup。
- 2014 N4 教育代碼 7、8、9 依問卷補為「專科以上」。
- 2017 等兩段式支出在 indicator 明確為「沒有」時轉為 0。
- 家戶人數加入 join 前後有效筆數 assertion 與檢核輸出。
- township 摘要加入縣市欄；新增跨年 township 名稱與 `縣市::鄉鎮` 複合鍵。
- `三民鄉`、`那瑪夏鄉` 統一到 `那瑪夏區`。
- 摘要清除「沒有」後黏入的 `○11` 金額選項文字。
- 完整 pipeline 加入原始年度檔案防護；缺任一年度時在覆寫產物前停止。
- 新增金額與樣本規則測試，已通過。

## 尚未完成

- 2014 家戶收入 1,869 筆共同缺失的逐筆根因。
- 2006 開放填答金額與代碼的遠端逐筆結果覆核（判型程式已完成）。
- 2017 最高級距的遠端逐筆結果覆核（開放欄優先程式已完成）。
- 全年度重跑、修復後摘要驗收及可比性矩陣。

## 阻擋原因

目前專案中的：

- `survey_datasets.rds`
- `basic_info_from_02.rds`
- `demographic_data_from_02.rds`
- `family_data_from_02.rds`
- `income_expenditure_data.rds`
- `cross_year_combined_data.rds`

都只包含 2021 年，共 5,409 筆。專案及 `Documents` 目錄中也找不到
`data91_1.dta`、`data91_2.dta`、`data95.dta`、`data99.dta`、
`data103.dta`、`data106.dta`。

現有跨年 CSV 是摘要資料，不能安全還原受訪者層級的 0、缺失、跳答與開放填答。
因此未用摘要反推個體資料，也未執行會把現有跨年輸出覆寫成只剩 2021 年的管線。

## 遠端恢復執行

將上述六個缺少的 `.dta` 放入同一 raw data 根目錄後，執行：

```bash
Rscript code/00-00-run-remote-pipeline.R /path/to/raw_data
```

管線會先確認七個 raw 檔全部存在，再開始重建。

本機已完成2021 fixture 驗證：5,409 筆均成功處理；`EXP_CARE` 分為
5,104 筆 `indicator_no_zero`、287 筆級距及18筆 `open_amount`，
重算後 valid N = 5,409、missing N = 0。
