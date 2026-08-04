# 2026-08-04 離線程式碼完整稽核

## 稽核範圍

本次以 2026-08-03 離線執行實際遇到的失敗模式為主軸，檢查正式入口
`code/00-00-run-remote-pipeline.R` 會使用的程式、七份問卷選項表、八份 crosswalk、
摘要與驗收程式。`code/main/` 與 `code/archive/` 為舊副本，不屬於正式執行或本次傳輸範圍。

## 檢視角度與結果

| 角度 | 檢查內容 | 結果 |
|---|---|---|
| 語法 | 逐支 `parse()` 全部 50 支 R 檔 | 通過 |
| 文字編碼 | 101 支 R、Python、CSV、TSV、Markdown 以 UTF-8 解碼 | 0 支無效 |
| CSV 結構 | 26 份 CSV 的欄數、空白欄名、重複欄名 | 0 份異常 |
| 必要檔案／欄位 | 預檢 7 份 option、8 份 crosswalk 及 crosswalk 必要欄 | 通過；缺檔或缺欄會中止 |
| 選項漏列 | 2002 分卷、2010／2014／2017／2021 兩段式支出、2014 教育與收支尾端選項 | 自動測試通過 |
| 選項誤認 | 性別、教育、沒有／無、未回答、金額區間與特殊缺失 | 自動測試通過 |
| 來源重複代碼 | 全七波掃描同題同碼多標籤 | 找到 12 組並寫入 `check_question_option_ambiguities.csv` |
| Crosswalk 衝突 | 同一標準化答案是否導向兩個不同結果 | 0 組；測試確認遇到衝突會中止 |
| 重複代碼防誤判 | 同一數字碼有兩個答案時不得以數字猜測 | 測試通過；必須靠標籤文字辨識 |
| 兩段式支出 | 有／沒有／無、空值、特殊缺失、indicator 與金額衝突 | 測試通過；保留 conflict check |
| F14 家庭年齡 | 逐年 crosswalk、2014 總計欄差異、2006 特殊缺失、加總對帳 | 程式與既有攜出證據通過；正式六波仍須離線重跑 |
| F8 eligibility | 2002 分卷與 2014 `i1` 是否被 05-01／05-02 實際讀取 | 合成串跑通過 |
| 跨年欄型 | `SOURCE_ID` 類別與 F14 數值欄是否混入同一 pivot | 合成串跑通過 |
| 摘要完整性 | AGE、F14、收支欄位是否全部進 coverage | 驗收程式已設守門條件 |
| Baseline | 修正前輸出缺失或比較欄位不齊時是否誤放行 | 缺 baseline 會中止；正式數值待離線重跑 |
| 敏感資料外帶 | `.RData`、`.Rhistory`、RDS 是否混入清單 | 傳輸清單會封鎖；新包不含個案資料 |
| 舊版誤用 | 根目錄正式碼與 `code/main/` 同名舊碼 | 11 支不同；新包排除整個 `code/main/` |

## 問卷來源的已知重複代碼

來源問卷本身存在印刷代碼重複，例如 2006 C2 的「60-64歲」及「65歲及以上」
同為 6，2014 F2-1 的「拉阿魯哇族」及「其他」同為 15。這不是將其中一列刪除就能
解決的資料清理問題。本版採以下原則：

1. 原樣保留並產出 ambiguity check，維持來源可追溯性。
2. 優先依 DTA／SAV 的 value label 文字配對。
3. 當同一數字碼對應多個標籤時，不啟用數字碼 fallback；無法辨識者留在 unmapped check。
4. 同一標籤若在 crosswalk 中導向不同結果，預檢立即中止。

## 測試結果

- `code/tests/test-questionnaire-crosswalk.py`：通過。
- `code/tests/test-summary-rules.R`：通過。
- `code/tests/test-downstream-synthetic.R`：通過。
- `code/00-01-validate-offline-inputs.R`：通過。
- 正式入口所需 R 程式全數可解析。

## 結論與剩餘限制

就可在外部環境驗證的程式邏輯，已處理過去發生的語法損壞、MBCS／UTF-8、欄型衝突、
選項漏列、否定選項方向、特殊缺失、結構性缺失、舊碼誤用及敏感檔混入風險。新程式可進入
限制性環境重跑；但外部環境沒有六波 respondent-level raw data，因此不能宣稱正式統計驗收
已完成。最終判定仍以離線執行 `05-99` 後 `check_offline_pipeline_acceptance.csv` 全部 `pass`
為準，任何 `fail` 都不得以新版 output 取代正式結果。
