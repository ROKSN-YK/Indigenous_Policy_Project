# 原住民族經濟調查資料檢視與調整計劃

檢視日期：2026-07-25  
檢視基準：`資料檢視報告_20260725.md`、目前 `output/` 摘要、檢核表與產製程式

## 一、結論

原報告的主要警示大致成立，且 P0/P1 問題足以阻止目前資料直接進入跨年估計。不過，執行順序需要調整：

1. 先凍結分析基準、建立可重現測試與年度／樣本定義契約。
2. 先修正會同時改變多張摘要的共用邏輯：樣本篩選、金額解析、欄位存在性判定。
3. 再修年度專屬 mapping：2014 收入、2014 教育、2017 兩段式支出、2014/2017 家戶人數。
4. 最後建立地理主鍵與可比性旗標，才產出 55 原鄉及 12 格分析資料。

在 P0 與核心 P1 驗收完成前：

- 2002 年不得用於任何金額跨年比較。
- 2014、2021 年不得使用目前的 `indigenous_analysis_sample`。
- 2014 年家戶收入不得納入跨年估計。
- 2017 年 `EXP_CARE_EXPENDITURE` 與完整合成總支出不得使用。
- 2014、2017 年不得計算 per-capita 指標。
- 鄉鎮層級資料不得直接用 `County` 單欄當跨年主鍵。

## 二、逐項核對結果

### 已由輸出與程式共同證實

| 項目 | 判定 | 核對結果 |
|---|---|---|
| 2002「萬」級距解析 | 證實 | 頂組被解析為 501、1,003、2,506、10,008、10,015；兩個混合「萬／千」閉區間無法解析。原因是頂組正則先匹配純數字，且 `parse_money_number()` 無法解析 `1萬5千`。 |
| 真零與未回答分類 | 證實 | 2002 的 `無此消費`／`無此收入` 共 8 個 label-value 組未辨識；2010 `未回答` 共 20 組；2006 未辨識項中同時混有拒答、純數字與格式化金額。 |
| 原住民族樣本篩選 | 證實 | `build_analysis_samples()` 明確只對 2017 排除非原住民族；2014 的 643 筆與 2021 的 1,017 筆仍留在分析樣本。 |
| 2014 家戶收入整批缺失 | 證實但根因未定 | 8 個 `INC_FAM_*` 衍生／分項欄位皆為 valid 3,345、missing 1,869。這只能證明共同上游問題，尚不能斷定是未抽出、join 失敗、跳答或樣本設計。 |
| 2017 支出異常缺失 | 證實 | full sample 中 `EXP_CARE_EXPENDITURE` valid 261、`EXP_CLEANING_EXPENDITURE` valid 42、完整合成總支出 valid 1。 |
| 2014 EDU 異常 | 證實 | full sample 的「專科以上」僅 44 筆、0.9726%，與相鄰年度斷裂。需回到 raw code/label 驗證，不能只按比例直接補字典。 |
| 2021 coverage 空白 | 證實且根因明確 | `build_present_lookup()` 的年度對照沒有 110/2021，因此核心變數 `Present` 成為未知；這是 metadata presence lookup 問題，不是觀測值缺失。 |
| 地理欄位不足與黏連 | 證實 | `sample_by_county.csv` 不含縣市；存在 `新埔鎮芎林鄉橫山鄉`、`烏日鄉霧峰鄉`、`南區東區` 等合併字串。 |
| 跳題文字殘留 | 證實 | 2014、2017、2021 均有含 `○11` 與符號串的「沒有」類別。 |

### 原報告需要修正或限縮的敘述

1. **2014/2017 `N_FAMILY`、`N_INDI` 並非 raw 欄位讀不到。**  
   `check_family_count_variables.csv` 顯示 2014 的 `f1`／`f1_1` 各有 5,214 筆，2017 的 `f1`／`f1_1_6` 各有 5,302 筆非缺失。問題發生在 raw 讀取之後、摘要之前，應優先追查 RDS 版本、join 後欄位名稱衝突或舊產物未重建。

2. **「2006 開放填答金額全部應直接採用」需逐欄驗證。**  
   `1e+05`、`34166`、`140,000元` 等高度可能是金額，但 `1`、`3`、`4` 也在同一未辨識集合中，可能是代碼而非元。不可用「可轉 numeric」作為唯一規則；須搭配原始變數、題型及 value label。

3. **2017 高缺失不應直接歸因為字串解析器。**  
   現有文件已指出兩段式題組可能選到 yes/no、級距或開放金額欄。應先驗證 resolver 選欄，再修 parser；否則可能把類別碼誤當金額。

4. **EXP_CLEANING／EXP_DINING_LODGING 的比例暫不足以判定真實離群。**  
   類別中仍殘留跳題文字，且兩段式欄位可能解析錯誤。應先清洗與重建，再決定是否標為不可比。

5. **「55 原鄉缺的是那瑪夏」需改寫。**  
   同一地區跨年使用 `三民鄉`、`那瑪夏鄉`、`那瑪夏區`，目前的零樣本更可能是 key 未調和，而不是實際無樣本。

## 三、調整工作分解

### Phase 0：凍結基準與建立回歸測試

目標：任何修正都可重現、可比較、可回退。

- 建立單一 pipeline 入口，固定 input 清單、產物清單與執行順序。
- 將目前 29 個新版摘要／檢核檔記錄為「問題基準」，保存 row count、欄位 schema、摘要 hash。
- 為 `ID + DATA_Y` 唯一性、年度筆數、join 前後筆數不變建立硬性 assertion。
- 明確定義 `full_sample` 與 `indigenous_analysis_sample`；在文件與程式只保留一份規則來源。
- 所有 summary 同時輸出 `pipeline_run_id` 或 manifest，避免新舊 RDS/CSV 混用。

驗收：

- 從 raw/intermediate 重新執行兩次，產物 hash 一致。
- 任一年度 join 造成增列、減列或重複 key 時 pipeline 直接失敗。
- 摘要所讀取的 RDS 可追溯至同一次 pipeline run。

### Phase 1：修正樣本與金額共用邏輯（P0）

#### 1.1 樣本篩選

- 將 `indigenous_exclusion_year = 2017L` 改為依年度可設定的 inclusion policy。
- 2014、2017、2021 在 `RACE` 可辨識時排除 `非原住民族`。
- 對缺失／未知族別另列 audit，不可靜默納入或排除。
- 2002–2010 若問卷母體本身即限定原住民族，應在 metadata 記為 `universe_already_indigenous`，而非假裝套用同一欄位篩選。

驗收：

- 2014 indigenous N = 5,214 − 643 = 4,571（若無 race missing）。
- 2017 indigenous N = 4,494，維持現況。
- 2021 indigenous N = 5,409 − 1,017 = 4,392（若無 race missing）。
- audit 的排除數與 categorical `RACE` 計數逐年完全相等。

#### 1.2 金額 parser 與狀態分類

- 將金額 token parser 改為可組合單位：支援 `15萬`、`1萬5千`、逗號、科學記號與 `元`。
- 修正頂組擷取順序，禁止先以 `^[0-9,.]+` 截斷 `萬元`。
- 將 `無此消費`、`無此收入` 納入精確零值字典。
- 建立互斥狀態：`observed_amount`、`exact_zero`、`response_missing`、`structural_missing`、`unrecognized`。
- `未回答`、`不知道/拒答` 必須是 `response_missing`，不可列為 parser error，也不可轉 0。
- 開放填答值只在 metadata 證明該欄為金額欄時直接採用。

最低單元測試：

| 輸入 | 預期 |
|---|---:|
| `1萬元以上` | lower = 10,000；midpoint 依同變數前一級寬推算 |
| `15萬元以上` | lower = 150,000 |
| `1萬~未滿1萬5千元` | midpoint = 12,500 |
| `1萬5千~未滿2萬元` | midpoint = 17,500 |
| `無此消費` | 0 / exact_zero |
| `無此收入` | 0 / exact_zero |
| `未回答` | NA / response_missing |
| `不知道/拒答` | NA / response_missing |

驗收：

- 2002 所有含「萬」的已知級距皆不需人工檢核。
- 2002 支出／收入變數可觀察到合法 0 值。
- 人工檢核表不再混合拒答與可解析金額。
- 每個 recode 規則均有 label-level fixture test。

### Phase 2：修正年度 mapping 與整併（P0/P1）

#### 2.1 2014 `INC_FAM_*`

依序檢查：

1. raw 題目是否為共同跳答區塊，以及 1,869 戶的跳答條件。
2. resolver 對 8 個變數選到的 raw 欄是否相同來源／同一錯誤 suffix。
3. income intermediate 在 join 前後的 ID 集合與非缺失數。
4. 3,345 與 1,869 兩群在族別、地區、收入相關欄位的分布。
5. 2014 級距單位及 label dictionary。

禁止在根因不明時以 0 補值或完整案例直接估計。

驗收：

- 為 1,869 筆逐筆指定 `observed`、`structural_missing` 或 `response_missing` 原因。
- 8 個欄位不再因同一技術性原因同步缺失。
- 修復前後 2014 收入分布與原始問卷頻數交叉核對一致。

#### 2.2 2017 兩段式支出

- 對每個題組明列 indicator、bracket、open amount 欄位。
- resolver 順序應為：適用性／有無 → 金額來源 → 未回答狀態。
- 不得把 yes/no code 當作金額；也不得把回答「沒有」者丟成 NA。
- 先處理核心 `EXP_CARE_EXPENDITURE`，再批次套用到 cleaning、loan interest、books、travel、tuition、dining/lodging。

驗收：

- 每個題組輸出來源欄位 audit 與狀態轉移表。
- `EXP_CARE_EXPENDITURE` 的 valid/zero/missing 總和等於 eligible N。
- `EXP_TOTAL_DERIVED_COMPLETE_EXPENDITURE` 完整率不再由單一解析錯誤壓至近零。

#### 2.3 2014 教育字典

- 以 2014 raw code、value label、問卷選項三方核對。
- 列出所有 raw code 到 harmonized category 的 mapping 與未對應筆數。
- 不以相鄰年度比例推定 mapping。

驗收：

- raw 非缺失筆數 = harmonized 類別計數 + 明確 response missing。
- 未對應教育代碼為 0。
- mapping 表有來源與版本註記。

#### 2.4 2014/2017 家戶人數

- 比較 `family_data_from_02.rds` 與 `cross_year_combined_data.rds` 的欄位名稱、型別、suffix 與非缺失數。
- 確認執行 05 摘要前，04 analysis-ready RDS 已由最新 family RDS 重建。
- 加入 join 後非缺失數 assertion，禁止完整欄位在後續變成全 NA。

驗收：

- 2014 `N_FAMILY`／`N_INDI` valid N 均為 5,214。
- 2017 full sample valid N 均為 5,302；indigenous sample 依篩選後筆數一致。
- 值域、整數性與 `N_INDI <= N_FAMILY` 通過逐筆檢查。

#### 2.5 2021 presence metadata

- 在年度對照加入 110/2021，或改由 long-form metadata 直接提供 survey year，避免硬編欄名。
- 將「資料欄存在」與「crosswalk 聲稱存在」分開檢核，兩者不一致時 fail fast。

驗收：

- 2021 七個核心變數不再是 `review_required`。
- `coverage_summary` 的 Valid N 與 numeric/categorical 摘要逐欄一致。
- unknown presence 清單只保留真正無法判定者。

### Phase 3：地理主鍵與標籤清洗（P2）

- 建立 `city_original`、`city_year_specific`、`city_harmonized`。
- 建立 `township_original`、`township_year_specific`、`township_harmonized`。
- 正式主鍵使用 `city_harmonized + township_harmonized`，不可只用鄉鎮名稱。
- 建立具有效期的行政區 crosswalk，涵蓋縣市合併與 `三民鄉 → 那瑪夏鄉 → 那瑪夏區`。
- 對合併地名標為 `ambiguous_combined_townships`；無可靠拆分依據時不得硬拆或分配人數。
- 標籤清洗移除跳題符號及其後指示文字，但保留 raw label 與清洗規則 audit。

驗收：

- 鄉鎮主鍵在每個年度內唯一且能反查縣市。
- 55 原鄉 coverage 以 harmonized key 重算，三民／那瑪夏跨年連續。
- 所有過長／合併地名皆進入已解決或待人工處理清單。
- summary 中不再出現 `○11` 或同類跳題符號。

### Phase 4：可比性決策與分析放行（P3）

為每個變數 × 年度建立：

- `availability_status`
- `measurement_type`（exact amount / bracket midpoint / binary / not present）
- `comparability_group`
- `known_limitation`
- `analysis_allowed`

`RENT`、`EXP_CLEANING`、`EXP_DINING_LODGING` 應在修復後再決定：

- 若題型本質不同，拆成不同 comparability group。
- 若可由正確欄位重建一致金額，再重新納入。
- 無法調和時，不刪資料；保留原值並將跨年分析設為不允許。

## 四、建議執行順序

1. Phase 0：可重現基準與 assertion。
2. Phase 1.1：樣本篩選。
3. Phase 1.2：金額 parser、零值與缺失狀態。
4. Phase 2.5：2021 presence metadata。
5. Phase 2.4：家戶人數資料鏈。
6. Phase 2.1：2014 家戶收入根因調查。
7. Phase 2.2：2017 兩段式支出。
8. Phase 2.3：2014 教育 mapping。
9. Phase 3：地理 crosswalk 與標籤清洗。
10. Phase 4：可比性矩陣與分析放行。

每完成一項，都必須從上游資料重新跑完整 pipeline，不接受只手改輸出 CSV。

## 五、最終放行條件

只有同時滿足以下條件，資料才可進入正式跨年估計：

- 所有 P0 的單元測試與資料 assertion 通過。
- 樣本排除 audit 與族別頻數完全一致。
- 金額值的 zero、observed、response missing、structural missing 可互斥且加總回 eligible N。
- 2014 家戶收入 1,869 筆缺失有可稽核原因。
- 2017 核心照護支出完成 resolver 驗證。
- 2014/2017 家戶人數可用且符合邏輯限制。
- 2021 coverage metadata 修復。
- 地理資料以縣市＋鄉鎮複合鍵運作。
- 建立變數 × 年度可比性矩陣，分析程式只讀取 `analysis_allowed = TRUE` 的組合。

