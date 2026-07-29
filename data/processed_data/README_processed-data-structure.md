# Processed Data 結構說明

`data/processed_data` 已依一般資料處理流程整理為下列子資料夾：

- `01_documentation/`
  - 流程說明、分析指南、crosswalk 使用說明。
- `02_metadata/`
  - 問卷 `meta`、`question_options`、年份摘要、section 定義與年度比較。
- `03_crosswalks/`
  - 跨年度變數對照、manual crosswalk、mapping、題項比較表。
- `04_analysis_ready/`
  - 可直接作分析前處理或 DID 準備的衍生資料表。
- `05_reference/`
  - 值得留存、但不屬於主流程輸出的參考資料。
- `archive/`
  - 已退出現行程序、但為便於追溯而保留的舊成果。

根目錄的 `basic_info_from_02.rds`、`demographic_data_from_02.rds`、
`family_data_from_02.rds` 是現行遠端程序的正式中間產出，不是散落的舊檔。
所得與支出正式產出統一放在 `03_income_expense/`。

## 這次整理重點

- 已將 `outputs/meta/` 移入 `02_metadata/survey_meta/`
- 已將 `outputs/question_options/` 移入 `02_metadata/question_options/`
- 已刪除明確重複或不必要檔案：
  - `outputs/meta/meta_106_.csv`
  - `outputs/meta/meta_110_with_labels.csv`
  - `data/processed_data/manual_question_crosswalk - manual_question_crosswalk.csv`
  - 各資料夾中的 `.DS_Store`
- 已保留有資訊差異的版本：
  - `02_metadata/survey_meta/meta_110.csv`
  - `02_metadata/survey_meta/meta_110_original.csv`
- 2026-07-26 已將六個舊版所得／支出 RDS 移入
  `archive/2026-07-26/legacy_income_expense/`，並移除正式程序的舊路徑備援。

## 使用建議

- 找題目欄位與標籤：看 `02_metadata/survey_meta/`
- 找問卷選項：看 `02_metadata/question_options/`
- 做跨年變數比對：先看 `03_crosswalks/`
- 做 DID 或分析前整理：先看 `04_analysis_ready/`
