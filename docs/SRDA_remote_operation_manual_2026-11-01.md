# SRDA 遠端代操作業手冊（2026-11-01 建立）

> 用途：讓任何新對話中的 Claude 能直接接手「代 YK 操作 SRDA 限制性資料遠端環境」。
> 原則：YK 偏好由 Claude 直接操作，人工打字或攜入只作為最後手段。

## 1. 環境事實（2026-11-01 實測）
- 連線：FortiClient VPN → Mac 上的 **Windows App**（`com.microsoft.rdc.macos`，存好的電腦是 192.168.3.55）。VPN 連線期間 Mac 仍可上網，Claude 可同時操作。
- 遠端：Windows，**R 4.5.0（RGui，不是 RStudio）**。8 個 pipeline 套件（haven、dplyr、data.table、purrr、readr、stringr、tidyr、tibble）都已安裝。
- 專案路徑：`C:/Users/SRDAR052025002/Desktop/Indigenous_Policy_Project`
- 攜出／上傳資料夾：**Z:（SRDAR052025002，\\csr.securedata\SDUserFolder）**，底下有 `上傳` 和 `攜出` 兩個資料夾。
- 遠端 `code/` 的 19 支 R 程式，與本機 repo（branch `codex/streamline-offline-pipeline`）**逐檔 MD5 一致**（以統一換行格式後的內容計算）。遠端沒有 `code/utils/safe_run.R`。
- Pipeline 裡沒有 print／head／View；直接 `source("code/00-00-run-remote-pipeline.R")`，畫面上只會出現進度訊息，不會出現個體資料。`safe_run.R` 屬於加分項，不是必要。
- RGui 開啟時會自動載入舊的 `.RData` 工作空間。關閉 R 時，「儲存工作空間影像？」一律選**「否」**。

## 2. 鍵盤限制與解法
- Windows App 是 Scancode 模式。電腦操控的 `type`（整串送字）會變成 `a`，**只能用 `key` 一鍵一鍵送**。
- Mac 輸入法必須是 **ABC**（注音模式下，字母和多數符號會變成 `a`）。YK 已關閉 macOS「自動切換到文件的輸入方式」。
- 遠端輸入法要保持「英」。它會自己跳回「中」，點工作列上的「中」即可切回。
- 可正確送出的鍵：英文字母（含 shift+字母）、數字、空白、Enter、`= - . ' ,`、shift+數字，以及 `[ ] \ { } | ~ : ; < # "` 和反引號。
- **無法送出**：`+ _ > ? /`。
- 背景模式的 app_* 點擊和打字在遠端畫面上不可靠，**請用全螢幕控制**（每次都要 YK 核准）。
- 點擊切換焦點後，要等約 1.5 秒再送鍵，否則最前面幾個鍵會遺失。

## 3. 送程式碼的標準流程（字元編號法）
任何 R 程式碼都可以只用「字母、數字、括號、=、空白、Enter」送進去：
1. 本機計算：`cps = [ord(c) for c in src]`，記下字元數 `len` 和編號總和 `sum`。每 16 個編號排成一行。
2. 遠端執行 `kqz = scan()`，按 Enter 前**先放大截圖確認字母正確**（試探字）。
3. 分批送出編號行，每行結尾按 Enter。每批之後確認 scan 的進度編號（例如 `161:`）。全部送完後，再按一次 Enter（空行）結束輸入。
4. 執行 `length(kqz)` 和 `sum(kqz)`，**與本機一致才繼續**。
5. 執行 `eval(parse(text = intToUtf8(kqz)))`。
- 程式一律包在 `local({ ... })` 裡，避免覆蓋使用者工作空間中的物件。
- 每次開始前先截圖確認版面（YK 可能移動視窗或切換全螢幕），並確認遠端是「英」。
- 吞吐量：約 500 鍵一批，一批約半分鐘。
- 已完成的批次：環境探測（298／22677）、資料夾列表（292／23035）、MD5 比對（381／29241）。

## 4. 資料規範（SRDA 使用者手冊 2024-07 版）
- 八.2：禁止以截圖、抄錄等方式取得資料內容。代操時**只看程式碼、錯誤訊息和結構資訊**（欄名、筆數、型態），不開 viewer，不印資料。
- 七.2：只能攜出彙總結果和程式檔，不得攜出個體資料。七.3：攜出要寄信向 onsite@gate.sinica.edu.tw 申請，檢查需 2 個工作天，通過後以加密壓縮檔寄回。
- 七.1：事先寫好的程式要寄給工作人員掃毒後放入。短指令和小修改用代操送；整支新程式要不要用代操送，由 YK 決定。
- 帳號、密碼、Token 一律由 YK 自己輸入。

## 5. 分工
- Codex：寫 pipeline 程式。Claude：審查、遠端代操、分析結果。代操時修改的程式碼，要寫回 repo 並交給 Codex 反向審查。
