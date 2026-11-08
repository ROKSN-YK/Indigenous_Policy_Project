# township_features：鄉鎮 × 年特徵資料

所有鄉鎮層級的外部行政資料都集中在這裡，只有原始下載檔放在 `data/raw_data/township_public/`。

## 資料夾

| 位置 | 內容 |
|---|---|
| `by_source/` | 各來源整理好的長表（已統一鄉鎮代碼與改制），**分析用這裡** |
| `by_source/ref_indigenous_areas_55.csv` | 55 個原住民族地區（30 山地、25 平地）對照 |
| `raw_names/` | 保留原始行政區名稱的中間表（供回查） |
| `qc/` | 完整度報告、逐年涵蓋表、一致性檢查 |
| `archive/` | 已被取代的舊版（v0 合併檔） |
| `source_log.csv` | 來源、網址、表名、年份、下載日、限制 |

原始檔：`data/raw_data/township_public/{ris_population, ncl_population_yearbook, cip_indigenous_population, fia_income_tax}/`
程式：`code/township_features/`
規格：專案資料夾 `2026-10-28_鄉鎮特徵表/2026-10-28_township_year_feature_panel_spec.md`

## 鍵值
`town_code_moi`（114 年內政部代碼）＋ `year_roc`。改制規則見 `code/township_features/township_harmonize.py`。

## 狀態（2026-11-08 更新）
- 四個來源已分列完成：人口（90–114）、原住民人口（92–114）、綜所稅所得（101–112）、醫療資源（104、109–114，衛福部〈醫事機構服務量縣市與鄉鎮統計表〉）。
- 合併主檔：`master/township_year_master_090_114.csv`（368 鄉鎮 × 90–114 年，9,200 列），欄位說明見 `master/township_year_master_codebook.csv`。
  - 所得 90–100 年：依回測結論用 101 年值固定（`income_*_fill`，`income_imputed=1`）；實值欄位保持空白。
  - 原住民人口 90–91 年：留空（`indig_observed=0`）。
  - 醫療資源：105–108 年衛福部未公布鄉鎮表，留空（`medical_observed=0`）；104 年來自〈104年度縣市別.zip〉。
- 尚缺：人均產值（擬用工業及服務業普查 90／95／100／105／110 年各縣市報告的鄉鎮表：場所單位數、從業員工、生產總額）。
