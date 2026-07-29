# 問卷辨識覆核樣本

日期：2026-07-25

本文件列出已用問卷 PDF 頁面視覺核對的樣本。`confirmed` 表示已由使用者核准並寫入規則；`pending_raw_validation` 表示須在遠端取得相應年度 raw data 後由 audit 判定。

## 樣本一：2014 教育程度（confirmed）

來源：`docs/codebooks/ques103.pdf`，PDF 第 10 頁，N4。

| 原始代碼 | 問卷選項 | 建議統一類別 | 判定 |
|---:|---|---|---|
| 1 | 不識字 | 不識字/自修 | confirmed |
| 2 | 自修 | 不識字/自修 | confirmed |
| 3 | 國小 | 國小 | confirmed |
| 4 | 國(初)中 | 國(初)中 | confirmed |
| 5 | 高中 | 高中職 | confirmed |
| 6 | 高職（含五專前三年） | 高中職 | confirmed |
| 7 | 專科 | 專科以上 | confirmed |
| 8 | 大學 | 專科以上 | confirmed |
| 9 | 研究所及以上 | 專科以上 | confirmed |

發現：既有 crosswalk 只留下代碼 9，且把該列的 `raw_option_order` 寫成 7；代碼 7、8 缺列。使用者已同意 7–9 均為「專科以上」，問卷抽取器、crosswalk 重建器及目前 crosswalk 均已補正。

## 樣本二：2017 M7 兩段式支出（confirmed）

來源：`docs/codebooks/ques106.pdf`，PDF 第 12 頁。

每個 M7-1 至 M7-10 題目都有兩段：

1. `有沒有支出`：代碼 1 = 有、2 = 沒有。
2. `平均每個月支出金額`：代碼 1 至 11；代碼 11 為 30,000 元以上並另有開放填答欄。

以 M7-9 為例：

| 欄位角色 | 問卷內容 | 正確資料處理 | 判定 |
|---|---|---|---|
| indicator | 保姆費／安養院／身障者照顧，有或沒有 | 「沒有」必須轉成確定 0 元 | confirmed |
| bracket | 1 至 11 級金額 | 轉為級距中點 | confirmed |
| open amount | 第 11 級後的記錄金額 | 僅在確認 raw 欄位及填答單位後優先使用 | pending_raw_validation |

發現：目前 resolver 已選到 `_2` 金額級距欄，但未把 `_1 = 沒有` 的受訪者補成 0，因此大量「沒有支出」者被誤列為缺失。使用者已同意 `_1 = 沒有` 一律視為 0，程式已加入 indicator-to-zero 規則。

## 樣本三：2017 類別文字中的 `○11`（confirmed）

來源：同上，PDF 第 12 頁。

`○11` 是金額選項編號的一部分，不是「沒有」答案的文字。PDF 抽取把同一列後面的金額選項黏到「沒有」，形成：

`沒有 ... ○11`

正確分類應為：

`沒有`

摘要清洗已加入規則，將以「沒有」開頭且包含 `○11` 的抽取殘文統一成「沒有」。

## 樣本四：2006 支出題的開放填答（部分 confirmed）

來源：`docs/codebooks/ques95.pdf`，PDF 第 10 頁附近的 Q12-A 與後續金額題。

問卷結構確認：

- 先由 Q12-A 勾選是否有特定支出。
- 後續題目提供金額級距。
- 最高級距後另有「請記錄 ___ 元」的開放填答位置。
- `沒有這項支出` 是確定 0，不是未回答。

因此：

| 觀察值例 | 初步判讀 | 判定 |
|---|---|---|
| `140,000元` | 很可能是開放填答金額 | pending_raw_validation |
| `1e+05` | 很可能是 100,000 元的儲存格式 | pending_raw_validation |
| `34166`、`50000` | 很可能是開放填答金額 | pending_raw_validation |
| `1`、`3`、`4` | 可能是級距代碼，不能直接當元 | pending_raw_validation |
| `不知道/拒答` | response missing | confirmed |

遠端程式會利用 Stata value-label code set 自動分類：屬於 code set 的數值是級距代碼；不屬於 code set 的數值才列為 `unlabelled_numeric_exact_amount`。分類結果會輸出樣本值供再次覆核。

## 請覆核的重點

1. 2014 教育代碼 7、8、9 統一為「專科以上」：已同意、已實作。
2. 2017 M7 系列中 indicator = 2 視為確定 0 元：已同意、已實作。
3. 2006 開放填答先依 raw 欄位的 Stata labels 判型：已同意、已實作遠端 audit。
