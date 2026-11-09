# SRDA 攜出 20261108：就業調查（限制版）分析結果

- 來源：SRDA 遠端 `Z:/攜出/20261108/`，YK 於 2026-11-09 取回；9 檔 MD5 與遠端 MANIFEST 一致（見 `../srda_exports/20261108/MANIFEST_20261108.csv`）。
- 內容只有係數、標準誤、p 值、平均數、樣本數；最小 n＝37,964，最少群集 18。
- 已通過 SRDA 攜出審查（2026-11-09 取回）；YK 2026-11-09 同意推上公開 repo。未經審查的 SRDA 結果仍不推。
- 結論摘要：`docs/文健站研究_04_攜出結果摘要_20261108.md`。
- 產生程式：`code/employment_cell/`（遠端讀檔輔助函式尚未存檔，見交接說明 03「11/8 晚補充」）。

## 共同代碼
| 代碼 | 意思 |
|---|---|
| emp | 有工作（就業） |
| lf | 勞動參與（就業＋找工作） |
| hw | 料理家務（在家照顧的代理變項） |
| F / M | 女性 25–64 歲／男性 25–64 歲 |
| F_yx、yx | 原鄉（山地＋平地原住民鄉鎮）女性 25–64 歲 |
| F45 | 女性 45–64 歲 |
| P | 安慰劑：15–24 歲 |
| dose1、p1、cell | 格子劑量：縣市×層別內，前一年底文健站數／每千名原住民 55+ |
| dose2、p2、cell_tribe | 格子劑量＋依受訪者族別調整 |
| cnt、exact | 真實鄉鎮的站數（90–102 有鄉鎮碼的年份） |
| b、se、t | 係數、群集穩健標準誤、t 值 |
| p_cr、p_wcb | 傳統群集 p 值、wild cluster bootstrap p 值（Webb 權重、999 次） |
| ybar | 加權平均（結果變數的基準水準） |
| n、G | 樣本數、群集數 |

## 檔案
| 檔案 | 內容 | 模型 |
|---|---|---|
| L2_dose_response/cell_dose1_103_112.csv | 103–112 格子劑量，5 樣本 × 3 結果 | 加權 LPM，格子 FE＋年 FE，格子群集 |
| L2_dose_response/tribe_dose2_103_112.csv | 同上，dose1 與 dose2 並列（e＝就業、h＝料理家務；開頭 y＝原鄉；1／2＝dose1／dose2） | 同上 |
| L2_dose_response/wcb_dose1_103_112.csv | dose1 的 WCB | 同上 |
| L2_dose_response/wcb_dose2_103_112.csv | dose2 的 WCB | 同上 |
| L3_event_study/es_93_102_yx_female.csv | 原鄉女 25–64，93–102 事件研究；e−1 為基準，e−4、e4 為端點合併 | 鄉鎮 FE＋年 FE，鄉鎮群集（G＝55），未加權 |
| L3_event_study/es_90_102_yx_female.csv | 同上，90–102（加入 90、91、94 年） | 同上 |
| L3_event_study/cs_90_102_female25_64.csv | Callaway–Sant'Anna，原鄉女 25–64，90–102；列＝就業／料理家務的估計與標準誤 | 欄位 pf、pn、p01、p23、p4、post：**推測**為遠期前期、近期前期、設站後 0–1、2–3、4 年以上、設站後合計，待對照程式確認 |
| L4_design_validation/beta_compare_93_102.csv | 同一模型改用三種曝露（真實鄉鎮／格子／格子×族別）的 β 比較，女 25–64，未加權 | 真實鄉鎮用鄉鎮 FE；格子用格子 FE |
| L4_design_validation/beta_compare_90_102.csv | 同上，90–102 | 同上 |
