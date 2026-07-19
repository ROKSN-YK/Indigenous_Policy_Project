# 跨年度摘要重建方法說明

## 樣本版本

- `full_sample`：保留各年度全部原始樣本，用於重現調查母體。
- `indigenous_analysis_sample`：跨年度分析版本；2017 年排除 `RACE == 非原住民族`，其他年度維持原樣。
- 所有主要摘要輸出均包含 `sample_definition`，不得混合兩種版本計算趨勢。

## 金額級距轉換

- 閉合級距採上下界組中點。
- 「未滿 B 元」以 0 至 B 的中點代表。
- 開放頂組以「頂組下界＋前一閉合級距寬度的一半」代表；若沒有可用的前一級距，保留缺失並列入人工檢查。
- 中點法會壓縮右尾，平均數與標準差均為近似值；對分配形狀敏感的分析應使用原始級距或區間模型。
- 只有完整符合「沒有這項收入／支出」、「無收入／支出」或單獨「無」的標籤才轉為 0；「無法回答／無法估計」等標籤保留 NA 並列入人工檢查。

## 教育與書報文具支出

- 2002（91-2）、2006、2010 問卷為教育、書報雜誌與文具合併題，輸出為 `EXP_EDU_BOOKS_COMBINED_EXPENDITURE`。
- 早期年度不另行產出可解釋為獨立分項的 `EXP_EDU_TUITION_EXPENDITURE` 或 `EXP_BOOKS_EXPENDITURE`。
- 2014 起問卷才分拆為學費補習家教與書報雜誌文具兩題。
- `EXP_TOTAL_SYN_EXPENDITURE` 依年度僅納入一份教育相關金額，禁止把早期同一題重複加總。

## 家庭總收入與總支出

- `*_REPORTED_*` 保留問卷可取得的自報總額，不以程式合成值覆蓋。
- `*_DERIVED_*` 是至少一個分項有效時的可用分項加總，可能因部分缺失而低估。
- `*_DERIVED_COMPLETE_*` 僅在該年度所有預期分項都有值時產出。
- respondent-level recoded values 同時保留 `component_expected_n`、`component_valid_n` 與 `component_complete`。
- 2002–2010 的總支出只納入 `EXP_EDU_BOOKS_COMBINED_EXPENDITURE`；2014 起只納入分拆後的學費與書報文具兩項。

## Coverage

- 一般人口與家庭變數的 coverage 以 harmonized label 計算。
- 收入與支出變數的 coverage 由最終 `recoded_midpoint` 重建，`coverage_basis = recoded_midpoint`。
- `income_expenditure_coverage_summary.csv` 應與 `income_expenditure_numeric_summary.csv` 的有效與缺失筆數一致。
- recoded coverage 無法單獨判定問卷跳答，其 Structural Missing 欄位保留 NA，並標記 `structural_missing_status = not_evaluated_in_recoded_coverage`。
- crosswalk 無法判定變數是否存在時不再預設為 present，改列入 `check_unknown_variable_presence.csv` 或 `check_unknown_income_expenditure_presence.csv`。
- RENT 的非租賃／配住戶另列為結構缺失；其他兩段式支出在確認 `_1`、`_2`、`_2o` resolver 前不預先宣告為結構缺失。

## 地理名稱

- `ADMIN_NAME_ORIGINAL`：raw data 原始縣市字串。
- `ADMIN_NAME_YEAR_SPECIFIC`：統一「台／臺」後、保留該年度行政名稱。
- `ADMIN_NAME_HARMONIZED`：跨年度統一到後期名稱，用於跨年彙整。
- 合併鄉鎮字串標為 `ambiguous_combined_townships`；在建立可辯護的拆分規則前，不直接指定單一 55 原鄉。

## 尚待遠端 raw data 驗證

- 2014、2017 的 `N_FAMILY`／`N_INDI` 實際欄名與非缺失筆數。
- 2002、2010、2017 RENT 修復後的 eligible 與 valid 差距。
- J7/M7/H7 兩段式題組選到的是 yes/no 欄、級距金額欄或開放金額欄。
