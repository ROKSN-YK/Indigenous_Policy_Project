# 人工確認清單

更新日期：2026-06-18

## 目的

本文件整理目前 `02` 與 `03` 主線流程執行後，仍需要人工確認、人工補表或人工決策的項目。後續若完成確認，請直接更新本文件。

## 確認原則

- `unmapped` 不為 0 的項目，優先處理。
- `missing_in_metadata` 但屬於設計上可接受的衍生變數，需標記為「已知可接受」。
- 跨年度有些年份有題目、有些年份沒有題目時：
  - analysis-ready 資料維持固定欄位結構。
  - 沒有該題的年份填 `NA`。
  - 不可硬補成 `0`。
  - 需在 crosswalk / metadata / 本清單中註記為「題目不存在」而非「受訪者漏答」。

## A. 高優先

### 1. `RACE` 尚有 1 筆未對應值

來源檔：
- `output/checks/check_unmapped_demographic_values.csv`

目前內容：
- `2021 / 110 / RACE / 邵族、噶瑪蘭族、撒奇萊雅族、拉阿魯哇族、卡那卡那富族 / 42`

需要人工決策：
- 確認此選項在 harmonized dictionary 中應歸到哪一個 `unified_code` / `unified_label`
- 或決定是否需要新增一個合併類別，例如較細部族群整併組

建議處理方式：
- 優先補在 `unified_answer_crosswalk_basic_info.csv`
- 補完後重跑：
  - `code/03-02-make-demographic-data-from-02.R`
  - 檢查 `output/checks/check_unmapped_demographic_values.csv` 是否清空

## B. 中優先

### 2. `INC_FAM_TOTAL` 缺少 metadata 對應

來源檔：
- `output/checks/check_income_variable_mapping.csv`

目前內容：
- `2021 / NA / INC_FAM_TOTAL / NA / NA / missing_in_metadata`

判讀：
- 這不是程式錯誤，代表目前資料並沒有一個單一原始欄位可直接對應 `家庭總收入`
- 此變數較可能屬於：
  - 問卷未單獨詢問
  - 需由多個收入項目加總而成的衍生變數

需要人工決策：
- 是否要在主線中正式建立 `INC_FAM_TOTAL`

建議選項：
- 若研究上需要：
  - 明確定義是否由 `INC_FAM_WORK + INC_FAM_GOV + INC_FAM_TRANSFER + INC_FAM_RENT + INC_FAM_INTEREST + INC_FAM_OTHER` 衍生
  - 並確認各欄位目前是「級距」而不是「連續金額」，是否適合直接加總
- 若研究上不需要：
  - 保持 `missing_in_metadata`
  - 在文件中註記為已知不建立

### 3. `EXP_TOTAL_SYN` 缺少 metadata 對應

來源檔：
- `output/checks/check_expenditure_variable_mapping.csv`

目前內容：
- `2021 / 110 / EXP_TOTAL_SYN / H1;H2;H3;...;H7-10 / NA / missing_in_metadata`

判讀：
- 這是設計上的「合成總支出」概念，不是單一原始欄位
- 目前流程已保留各支出子項，但未建立正式總支出合成欄位

需要人工決策：
- 是否要在主線中正式建立 `EXP_TOTAL_SYN`

建議選項：
- 若研究上需要：
  - 先確認各原始子項是否為可加總的金額或級距
  - 若是級距資料，需先定義如何轉換成可加總值
- 若研究上不需要：
  - 保持 `missing_in_metadata`
  - 在文件中註記為已知不建立

## C. 低優先

### 4. `RENT` 補值邏輯已完成，但建議人工 spot check

來源檔：
- `output/checks/check_rent_imputation.csv`

目前狀態：
- from-02 主線已保留補值流程
- 2021 年資料顯示：
  - 大多數來自主欄位 `c2`
  - 少數由補充欄位 `c2o` 補入

建議人工檢查重點：
- `20,000元以上` 搭配不同 `c2o` 連續值時，是否都符合研究預期
- `missing` 的 4271 筆是否符合樣本真實情況，而不是欄位讀取錯誤

### 5. `MALE` 建議人工確認已統一結果

來源檔：
- `output/checks/check_male_mapping.csv`

目前狀態：
- `男性 -> 男性`
- `女性 -> 非男性`

建議人工檢查重點：
- 若未來納入較早年度，請確認是否出現：
  - `男`
  - `女`
  - `1`
  - `0`
  - `2`
- 若出現，請再次檢視 fallback 與 crosswalk 映射是否仍正確

## D. 目前已清空項目

以下項目目前不需要人工補表：

- `output/checks/check_unmapped_income_values.csv`
  - 目前僅剩表頭，表示收入口徑沒有未對應值

- `output/checks/check_unmapped_expenditure_values.csv`
  - 目前僅剩表頭，表示支出口徑沒有未對應值

- `unified_answer_crosswalk_income.csv`
  - 已完成 CSV parsing cleanup

- `unified_answer_crosswalk_expenditure.csv`
  - 已完成 CSV parsing cleanup

## E. 後續新增年度時的人工確認順序

若未來新增 91、95、99、103、106 等年度 raw data，建議人工確認順序如下：

1. 先跑 `code/02-00-import-cross-year-survey-data.R`
2. 再跑 `code/03-00-make-year-survey-meta.R`
3. 依序跑：
   - `code/03-01-make-basic-info-from-02.R`
   - `code/03-02-make-demographic-data-from-02.R`
   - `code/03-03-make-family-data-from-02.R`
   - `code/03-04-make-income-expense-data-from-02.R`
4. 優先看這些檢查檔：
   - `output/checks/check_missing_variables_by_year.csv`
   - `output/checks/check_unmapped_demographic_values.csv`
   - `output/checks/check_unmapped_income_values.csv`
   - `output/checks/check_unmapped_expenditure_values.csv`
   - `output/checks/check_rent_imputation.csv`

## F. 目前總結

截至 2026-06-18，真正尚待人工確認的核心項目為：

1. `RACE` 的未對應合併族群選項
2. 是否要正式建立 `INC_FAM_TOTAL`
3. 是否要正式建立 `EXP_TOTAL_SYN`

其餘主線流程目前可視為已可穩定執行。
