# Output 增量整併判斷

## 加回正式 output

- `README_output-folder-guide.md`：正式輸出目錄說明。
- `basic_info_from_02.csv`、`demographic_data_from_02.csv`、`family_data_from_02.csv`：現行程式仍會產生的中間成果；離線包未攜出不代表已停用。
- `checks/check_question_option_extraction.csv`、`checks/check_questionnaire_pdf_render.csv`：仍具問卷處理品質追蹤用途，且不與新版同名檔衝突。
- `figures/`、`hetero/`、`models/`、`reports/`、`summary/`、`tables/`：正式分析輸出結構。

## 僅保留於日期封存區

- `output/archive/` 原有內容：已明確標示為舊版收入／支出衍生資料與 2026-07-21 歷史快照。
- `offline_hotfix_2026-07-30_2002-survey-tag.zip`。
- `offline_pipeline_transfer_2026-07-28.zip`、`offline_pipeline_transfer_2026-07-29.zip`、`offline_pipeline_transfer_2026-07-30.zip`。

以上 ZIP 是過往離線交換包，不是分析程式直接讀取的成果；保留於封存區即可追溯，避免與目前正式輸出混用。
