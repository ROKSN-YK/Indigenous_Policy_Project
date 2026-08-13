# 2026-08-06 離線完整更新包複核紀錄

## 原包問題

第一版壓縮包實際包含文健站原始清冊與兩支整併程式，解包後51檔MD5均與來源相符；但沒有納入預先產出的文健站鄉鎮年度panel，且混入多份2026-08-04舊說明，使用者難以辨識本輪新增內容。因此第一版不再建議使用。

## v2封裝改善

- 根目錄加入`OFFLINE_UPDATE_README_2026-08-06.md`與檔案索引。
- 同時納入525站原始清冊與122鄉鎮×民國90–114年panel。
- 只保留本輪離線操作說明，不再混入8月4日變更紀錄。
- 文健站panel明確含民國110年。

## 修正項目複核

| 修正 | 實作位置 | 自動測試 |
|---|---|---|
| 2010家庭其他收入I6→i7 | `dataset_variable_overrides.csv`、resolver | `test-care-station-and-overrides.R` |
| 2017三項支出indicator亂碼 | `two_stage_indicator_overrides.csv`、`apply_two_stage_indicator_override()` | `test-summary-rules.R` |
| 2006代碼1/3/4誤當元金額 | `classify_unlabelled_numeric()` | `test-summary-rules.R` |
| 2014 RENT尾端私用字元 | `normalize_money_label()` | `test-summary-rules.R` |
| 2014家庭收入可用個案納入 | `INC_FAM_ANALYSIS_ELIGIBLE`與驗收 | `test-downstream-synthetic.R`及正式離線驗收 |
| 固定共同項所得／支出 | `append_fixed_common_totals()` | `test-downstream-synthetic.R` |
| 文健站panel及個體合併 | `03-05`、`04-02` | `test-care-station-and-overrides.R`及正式離線驗收 |

## 獨立解包驗證

v2曾解壓至全新暫存目錄，並直接從解包內容執行：

- `00-02-check-offline-transfer-bundle.R`
- `test-summary-rules.R`
- `test-downstream-synthetic.R`
- `test-care-station-and-overrides.R`
- `test-questionnaire-crosswalk.py`

全部通過；解包檔案與來源MD5全部一致。正式六波數值仍須在持有受限個體資料的離線環境重跑確認。

