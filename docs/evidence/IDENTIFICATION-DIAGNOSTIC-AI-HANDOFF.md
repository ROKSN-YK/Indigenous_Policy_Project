# 文化健康站研究識別診斷：AI 審查交接文件

## 1. 交接目的

請以「獨立方法審查者」身分，檢視本 repository 內文化健康站（文健站）研究的識別診斷成果。

本批次目的不是估計或宣告最終因果效果，而是判斷現有資料結構能否支持下列設計：

- Primary：Callaway–Sant’Anna staggered Difference-in-Differences，repeated cross-sectional data。
- Primary control：not-yet-treated towns。
- Robustness control：registry-external／potential never-treated towns，但不得預設其真正 never-treated。
- Supporting：town treatment × before/after × Indigenous 55+ household eligibility 的 DDD。

請不要：

- 將非顯著 pre-trend 解釋為平行趨勢成立；
- 僅憑 p-value 判定 Gate；
- 將觀察到的 covariate adjustment 解釋為已消除 endogeneity；
- 提議依顯著性選擇模型；
- 把本批結果提升為最終因果結論。

## 2. 研究問題與主要定義

研究問題：文健站分期設置是否改變「至少有一位原住民族 55 歲以上成員」家庭的每月醫療／健康照護支出？

主要調查波：2006、2010、2014、2017；2002 僅作 extended pre-trend robustness。

目前 repository 證據支持的定義如下：

- Survey year：`DATA_Y`，西元年。
- Township key：`CITY + COUNTY`；不可只用鄉鎮名稱。
- Treatment first year：`care_station_first_year`，民國年。
- 55+ eligibility：`N_INDI_55_64 + N_INDI_65PLUS > 0`。
- Medical outcome：`EXP_MEDICAL_EXPENDITURE`。
- Care outcome：`EXP_CARE_EXPENDITURE`。
- Food outcome：`EXP_FOOD_EXPENDITURE`。
- 支出金額多為級距中點；開放金額如可取得則優先使用。中點不是精確支出。

診斷程式為了把成立年度映射到調查波，使用：

- ≤2005：always-treated／pre-window；
- 2006：2006 cohort；
- 2007–2010：2010 cohort；
- 2011–2014：2014 cohort；
- 2015–2017：2017 cohort；
- 2018+：not-yet-treated；
- 不在 114 年現存清冊：registry-external／potential never-treated。

這是「首次可由調查波觀察為已處置」的分組，不等同精確成立年度 cohort。最終研究前需由研究者確認。

## 3. Repository 狀態與關鍵限制

### OBSERVED

- Active canonical household dataset：`data/processed_data/04_analysis_ready/cross_year_combined_with_care_station.rds`。
- 該檔實際只有 2021 年 5,409 戶。
- 2021 地理只有四大區域，沒有可與文健站 panel 配對的鄉鎮。
- `data/processed_data/02_metadata/survey_datasets.rds` 與 imported index 也只含 2021。
- Archive 顯示 2002–2021 六波資料曾在受限離線環境中完成處理，但 repository 只保留鄉鎮 × 年 × 單一變數的邊際彙總，而沒有 2002–2017 household microdata。

### Consequence

現有邊際資料能重建：

- cohort × wave × eligibility 的戶數、鄉鎮數與集中度；
- 整體、非 eligibility-specific 的鄉鎮醫療支出 midpoint 趨勢；
- 有限的鄉鎮層 baseline selection comparisons；
- care／food 問卷跨波可比性。

現有資料不能重建：

- eligibility cell 內的有效醫療支出 N、平均數、中位數、SD、P80、P90、零值與缺失率；
- eligibility × medical outcome 聯合分布；
- 55+ minus non-55+ outcome gap；
- DDD pre-trend 或 DDD event-time coefficients；
- 個體層 regression-adjusted event study；
- HonestDiD 所需的可靠 covariance inputs；
- 可比較的 weighted household counts。

因此上述項目被明確標為 `BLOCKED — MISSING JOINT MICRODATA`，不是以邊際分布推算或補造。

## 4. 核心實證證據

### Gate 1：統計支持

證據標籤：**Insufficient information**。

- 2006 cohort：7 個可觀察鄉鎮；多數 cell 觸發 towns < 10、top-three share > 50% 等集中度警訊。
- 2010 cohort：
  - 55+ household N：2006/2010/2014 分別為 711/333/384；
  - unique towns：12/13/16；
  - top-three share：約 37%/41%/40%。
- 2014 cohort：
  - 55+ household N：2006/2010/2014 分別為 534/270/356；
  - unique towns：9/10/13；
  - top-three share：約 56%/55%/44%；
  - 非55+ cell 的最大單一鄉鎮占比在 2010/2014 約 37%/39%。
- 2017 cohort：可提供 treatment 前描述，但 2017 是資料終點，不能提供有意義的 post-treatment dynamics。

2010 cohort 的支持度邊際證據相對較好；2014 cohort 有較明顯的早期鄉鎮數與集中度警訊。但因 eligibility-specific medical outcome moments 缺失，不能據此判定任何 cohort 足以承載主分析。

### Gate 2A：Observable treatment selection

證據標籤：**Concerning**。

較早採用鄉鎮相對較晚／清冊外鄉鎮的 standardized differences：

- 2010 cohort，2006 baseline：
  - `N_INDI_55PLUS`：約 +1.19 SD；
  - `N_INDI_65PLUS`：約 +0.90 SD；
  - household size：約 +0.24 SD；
  - medical expenditure：約 -0.18 SD。
- 2014 cohort，2010 baseline：
  - `N_INDI_55PLUS`：約 +1.86 SD；
  - `N_INDI_65PLUS`：約 +2.09 SD；
  - household size：約 -0.93 SD；
  - medical expenditure：約 -0.34 SD。

這些是早期採用與 older-Indigenous composition 系統性相關的觀察證據。它們可能威脅醫療支出 DID，但不能單獨證明或量化 endogeneity。

採用模型是 descriptive linear model of calendar adoption year，不是 causal hazard model，也不是 selection correction。

### Gate 2B：Medical expenditure pre-trends

證據標籤：**Mixed／Insufficient**。

- 2006 cohort：primary window 沒有 treatment 前調查波；2002 只有一個 extended pre observation，無法判斷 trajectory。
- 2010 cohort：primary window 只有 2006 一個 pre-wave；加入 2002 才有兩點。
- 2014 cohort：2006、2010 提供一段 primary-window pre-change。
- 2014 cohort 相對 not-yet-treated 的整體 midpoint medical gap：
  - 2006：約 -377；
  - 2010：約 -335。

上述 confidence intervals 是以鄉鎮分布建立的 descriptive approximation，不是完整 repeated-cross-section cluster inference。不得把區間包含零解釋為已證明平行趨勢。

2002 robustness：

- archived merge audit 顯示 12,146/13,113 戶具有 township geography，約 92.63%；
- 診斷進一步排除 documented combined-township 與 unknown labels；
- 保留 11,278 個 valid-medical observations、118 個 precise town labels；
- 2002 沒有 F14 eligibility，醫療級距較粗，因此只作 robustness evidence。

### Gate 3：Eligibility DDD

證據標籤：**Insufficient information**。

- Eligibility 的戶數、鄉鎮數、集中度可以觀察。
- Eligibility-specific medical outcomes 與相對 gap 不可觀察。
- DDD pre-trend、DDD event-time coefficients、non-55+ comparison selection 均 BLOCKED。

即使之後取得資料，DDD 也只能作 supporting evidence，estimand 應描述為「differential effect for target-eligible households」。DDD 不能排除：

- town-time shocks 對 older households 的差異影響；
- concurrent age-targeted policies；
- community spillovers。

## 5. Outcome comparability

### Medical

結論：可作四波主要結果，但屬 **Partially comparable**。

- 各波概念均涵蓋看病就醫、醫療保險與醫療用品／設備。
- 2014 起低金額級距變細。
- Midpoint conversion 與 open-top coding 造成測量近似。

### Care

結論：2006–2014 可考慮 restricted-period analysis；2017 只宜作 supplementary/mechanism-consistent evidence。

- 2006–2014：兒童／老人／身心障礙者照顧。
- 2017：保姆費／安養院／身障者照顧。
- 2017 的服務邊界屬 material definition change。

### Food

結論：適合 2006–2010 或 2014–2017 分段比較；不宜直接作單一四波 causal DID。

- 2006/2010 使用「吃飯、蔬菜魚肉、水果、飲料」等文案，未以相同方式分離外食。
- 2014/2017 改為買菜／米肉菜／水果／非酒精飲料／零食，並把外食與住宿另列。
- 2014 是 consumption basket boundary 的 material change。

## 6. 主要威脅

1. **Critical — Historical treatment misclassification**：處置 panel 由 114 年現存營運清冊回推，可能漏掉已停辦／撤站站點。
2. **High — Endogenous station placement**：older-Indigenous composition 與採用時點有大 standardized differences。
3. **High — Missing joint microdata**：無法完成 Gate 1 outcome cells 與 Gate 3 DDD。
4. **High — Limited treated clusters/concentration**：2006 cohort 與 2014 cohort 早期 cell 特別明顯。
5. **High — Repeated-cross-section composition change**：只能觀察邊際年齡組成，無法連結到 outcome。
6. **High — Survey-weight ambiguity**：各波候選權數名稱與母體／樣本定義不同，尚未驗證。
7. **High — Concurrent age-targeted policies**：repository 沒有可控制或描述的 township-year policy inventory。
8. **Medium — Midpoint expenditure measurement**。
9. **Medium — Spillovers to nominal comparison households**。

## 7. 可重現方式

在 repository root 執行：

```bash
Rscript code/diagnostics/run_identification_diagnostic_batch.R
```

程式：

- 使用固定 seed `20260814`；
- 只讀 repository 既有資料；
- 只寫入 `diagnostics/` 與 `docs/evidence/`；
- 不修改 raw 或 canonical datasets；
- 對必要欄位、主調查年份與 treatment-year 合法範圍做 fail-loudly checks；
- 未使用新套件或安裝依賴。

## 8. 優先閱讀檔案

1. `docs/evidence/IDENTIFICATION-DIAGNOSTIC-REPORT.md`：繁中正式證據報告。
2. `diagnostics/repository_inspection.md`：Step 0 與資料缺口。
3. `diagnostics/diagnostic_manifest.csv`：machine-readable reproducibility manifest。
4. `diagnostics/gate1_cohort_wave_eligibility.csv`：支持矩陣。
5. `diagnostics/gate1_town_concentration.csv`：cell 的鄉鎮集中度明細。
6. `diagnostics/gate2_baseline_balance.csv`：standardized differences。
7. `diagnostics/gate2_adoption_predictors.csv`：descriptive adoption model。
8. `diagnostics/gate2_pretrend_eventtime.csv`：primary-window descriptive trends。
9. `diagnostics/gate2_pretrend_2002_robustness.csv`：含 2002 robustness。
10. `diagnostics/gate3_ddd_pretrend.csv`：DDD BLOCKED 原因與最小下一步。
11. `diagnostics/outcome_care_crosswave_audit.csv`。
12. `diagnostics/outcome_food_crosswave_audit.csv`。
13. `code/diagnostics/run_identification_diagnostic_batch.R`：全部輸出的生成程式。

## 9. 請審查者回答的問題

請將每項回答區分為 `OBSERVED`、`DOCUMENTED`、`INFERRED` 或 `UNRESOLVED`，並附 repository 檔案與欄位依據。

1. 程式是否有把邊際分布誤當作 joint distribution？
2. Cohort mapping 是否清楚且沒有悄悄改變 treatment definition？
3. Registry-external controls 是否被過度解釋為 never-treated？
4. Gate 1 的戶數、鄉鎮數及集中度計算是否正確？
5. 2010 與 2014 cohort 的支持度描述是否符合數據？
6. Baseline standardized differences 的比較組與 baseline timing 是否合理？
7. Adoption model 是否被正確限制為 descriptive evidence？
8. Pre-trend control group 是否真的是該波 not-yet-treated，是否有 treatment-timing contamination？
9. 2002 geographic exclusions、保留率與 robustness 定位是否合理？
10. Midpoint reconstruction 是否與 repository 既有 recoding 一致，是否存在未映射或錯誤級距？
11. Descriptive confidence intervals 是否可能讓讀者誤以為是正式 cluster inference？
12. Gate 3 被標為 BLOCKED 是否必要，或 repository 是否另有合法 joint data 可用？
13. Care 與 food 的 pairwise comparability classification 是否被問卷原文支持？
14. Threat register 的 severity 是否均有相應證據？
15. 是否有任何文字超出資料能支持的程度，或構成因果結論？

## 10. 建議審查輸出格式

請輸出：

### A. 總評

- Reproducibility：Adequate／Needs revision／Not reproducible
- Evidence discipline：Adequate／Needs revision／Material overclaim
- Gate 1 evidence：Supportive／Mixed／Concerning／Insufficient
- Gate 2 evidence：Supportive／Mixed／Concerning／Insufficient
- Gate 3 evidence：Supportive／Mixed／Concerning／Insufficient

### B. Findings

逐項列出：

- Severity：Critical／High／Medium／Low
- File and line／column
- Finding
- Why it matters
- Smallest valid correction

### C. Verified claims

列出已由程式與 repository evidence 核對正確的重要結論。

### D. Unresolved items

只列無法由現有 repository 合法判定的問題，以及所需的最小新增資料或決策。

### E. 禁止事項

不要提出或執行 final causal estimate、Synthetic Control、IV、依顯著性選模型，或將非顯著 pre-trend 解讀為設計已通過。

