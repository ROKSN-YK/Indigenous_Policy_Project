# 2026-08-10 離線執行成果歸檔

## 來源與範圍

- 來源：`/Users/y.k.chiang/Downloads/20260810/`
- 歸檔日：2026-08-11
- 內容：離線執行所使用的程式、檢核輸出、摘要統計與可攜出的參考資料。
- 歸檔方式：保留來源相對目錄結構；排除 `.DS_Store`、`.Rhistory`、`.RData` 等系統或工作階段暫存檔。
- 本歸檔是唯讀歷史快照；品質確認後，其內容已依下述方式整併至正式目錄。

## 品質結論

結論：**通過，可作為 2026-08-10 離線執行成果快照。**

- `output/checks/check_offline_pipeline_acceptance.csv` 共 28 項驗收，全部為 `pass`。
- 來源內 53 個 CSV 均可用 UTF-8/UTF-8-BOM 解析，且各檔列寬一致。
- 六個調查年度（2002、2006、2010、2014、2017、2021）均存在。
- ID-year 無重複；文健站合併前後均為 40,078 筆，未改變受訪者筆數。
- 家戶人數關係、租金有效率、年齡組調和、2014 年 I1 結構性資格規則、2010 年兩階段支出指標等正式驗收均通過。
- `check_income_expenditure_before_after.csv` 共 332 筆；24 筆前後不同都位於允許變更的欄位，`expected_unchanged=TRUE` 的欄位沒有非預期變動。

## 已知但不阻擋歸檔的事項

- `check_care_station_invalid_established_year.csv` 只有標題列，表示沒有無效成立年份，並非缺漏。
- `check_income_expenditure_manual_review.csv` 有 15 筆人工覆核旗標，多為分析資格衍生欄位與自有住宅標籤；正式驗收已涵蓋相關規則，但後續發布前仍宜保留人工覆核紀錄。
- `check_question_option_ambiguities.csv` 有 12 筆原問卷選項碼對應多個文字的歧義，已保留供追溯。
- 未映射值明細仍保留於 checks：人口 3 筆、收入 82 筆、支出 436 筆；正式驗收中的類別未映射率門檻（每個已觀察變數年度低於 5%）已通過。
- `output/pipeline_manifest.csv` 的自身 MD5 不會等於表內預先記錄的自身 MD5；這是自我雜湊檔案的固有限制。其餘可由本離線包對應到 manifest 的 54 個檔案皆與所列 bytes/MD5 相符。

## 完整性與使用注意

- 歸檔共 120 個來源檔案，約 16 MB；另新增本說明檔。
- 原始下載資料夾未修改或刪除。
- manifest 描述的是離線環境中的完整專案狀態；此可攜包只包含允許攜出的程式、檢核、摘要與參考資料，因此不可把 manifest 中未隨包附帶的項目視為遺失。
- 正式 `code/` 已完整同步為本次離線版本；`output/` 與 `data/processed_data/05_reference/` 採增量整併，未攜出的正式內容保留。
- 整併前的舊版已保存於同日的 `../pre-20260810-offline-merge/`，可完整回復。
