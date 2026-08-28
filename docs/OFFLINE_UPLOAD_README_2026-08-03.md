# 2026-08-03 v2＋v3 離線完整重跑更新包

壓縮檔：`offline_v2_v3_full_rerun_2026-08-03.zip`

## 本包用途

將 v2、v3 修正後的程式與配套表帶入既有離線專案，先封存修正前 output，再執行六波完整重跑與驗收。壓縮包不含限制性 raw data，也不會取代離線機上的 `data/raw_data`。

## 內容

- `code/`：完整重跑所需 R 程式、檢查程式與操作說明。
- `data/processed_data/02_metadata/question_options/`：七份問卷選項表。
- `data/processed_data/03_crosswalks/`：本次流程所需 crosswalk，包括 F14 與 structural eligibility。
- `docs/`：v3 實作紀錄及 v2＋v3 完整驗收清單。
- `offline_baseline/pre_v2_v3_output/`：目前修正前 output 的唯讀參考副本；不要直接用它覆蓋離線端較完整資料。
- `TRANSFER_MANIFEST_SHA256.csv`：傳輸包內檔案的 SHA-256。

## 安裝與執行順序

1. 關閉 RStudio，先複製整個離線專案作外部備份。
2. 解壓本包；將其中 `code`、`data`、`docs` 合併到既有專案根目錄。只取代同名程式與配套 CSV，不刪除 raw data 或其他資料夾。
3. 用既有 `.Rproj` 開啟正式專案，Restart R，確認 `getwd()` 是專案根目錄。
4. 執行 `source("code/00-02-check-offline-transfer-bundle.R", encoding="UTF-8")`。
5. 執行 `source("code/00-01-validate-offline-inputs.R", encoding="UTF-8")`。
6. **重跑前**執行 `source("code/00-03-archive-output-before-rerun.R", encoding="UTF-8")`，確認 archive 與 MD5 manifest 已建立。
7. 設定 `RAW_DATA_DIR`，執行 `source("code/00-00-run-remote-pipeline.R", encoding="UTF-8")`。
8. 按 `docs/offline_validation_checklist_v2_v3.md` 逐條核對；任何必須項失敗時，不要以新版 output 取代正式結果。

詳細 Windows 路徑、套件檢查與故障排除請看 `code/REMOTE_BEGINNER_OPERATION_MANUAL.md`。

## 舊 output 原則

離線端目前 output 與本包 baseline 一致時，不需要退回更舊版本；它正是 F9 before/after 比對基準。若離線端 output 已被意外覆寫，才使用 `offline_baseline/pre_v2_v3_output/` 協助恢復或比對。更早的 7 月輸出不應作為本輪主要基準。
