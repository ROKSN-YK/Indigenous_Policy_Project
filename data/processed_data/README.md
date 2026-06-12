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

## 使用建議

- 找題目欄位與標籤：看 `02_metadata/survey_meta/`
- 找問卷選項：看 `02_metadata/question_options/`
- 做跨年變數比對：先看 `03_crosswalks/`
- 做 DID 或分析前整理：先看 `04_analysis_ready/`
