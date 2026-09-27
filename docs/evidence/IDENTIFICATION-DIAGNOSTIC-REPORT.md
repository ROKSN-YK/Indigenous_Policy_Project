# 文化健康站研究：識別診斷證據報告

## 12.1 執行摘要

本批次檢查統計支持、處置選擇、醫療支出前趨勢、55+ eligibility DDD 前趨勢，以及照顧與食物支出的跨波可比性。**OBSERVED**：repository 的 active canonical 個體檔只有 2021，且無鄉鎮地理；六波資料只留下鄉鎮層的單變數邊際彙總。這些彙總足以重建 eligibility 戶數／集中度、整體（非 eligibility-specific）醫療支出描述趨勢，以及有限的處置選擇比較。**UNRESOLVED**：eligibility × medical outcome 的聯合分布、有效樣本、DDD gap、個體層調整與正式推論均無法重建。最大風險是歷史站點清冊誤分類、關鍵 cohort 的有限前期、缺 joint microdata、處置選擇與 survey weight 定義未驗證。此報告不作最終因果研究決定。

## 12.2 Gate 1 — 統計支持

整體證據：**insufficient information**。2006 cohort 僅 7 個可觀察鄉鎮且高度集中；2010 cohort 的 55+ cell 在 2006/2010/2014 分別有 711/333/384 戶、12/13/16 鄉鎮，top-three share 約 37%–41%；2014 cohort 同期為 534/270/356 戶、9/10/13 鄉鎮，但 top-three share 約 44%–56%，非55+ cell 的單一鄉鎮占比最高約 39%。2017 cohort 不提供有意義的 post-treatment dynamics。eligibility-specific outcome moments 皆為 BLOCKED，因此不能只憑邊際支持戶數認定關鍵 cohort 足以承載主分析。

## 12.3 Gate 2 — 處置選擇與前趨勢

### Observable baseline selection

**OBSERVED** 較早採用鄉鎮在 older-Indigenous composition 上有大幅標準化差異：2010 cohort 對較晚／清冊外控制的 2006 基線 `N_INDI_55PLUS` 約 +1.19 SD、`N_INDI_65PLUS` 約 +0.90 SD；2014 cohort 的 2010 基線約 +1.86 SD、+2.09 SD，家庭規模約 -0.93 SD，醫療支出約 -0.34 SD。這些是 treatment selection 的 concerning evidence。**INFERRED** 差異可能同時關聯採用時點與醫療支出趨勢。**UNRESOLVED** 醫療資源、偏遠性、人口母數及已撤站歷史；觀察到的 covariate adjustment 不會消除 endogeneity。

### Outcome pre-trends

**OBSERVED** 整體醫療支出 midpoint 趨勢可由鄉鎮 × 類別邊際表重建。2006 cohort 無可估 trajectory 的 primary pre-period；2010 cohort 需依賴 2002 才有兩點；2014 cohort 有 2006/2010 一段 primary pre-change。**INFERRED** 非顯著或寬區間不能證明平行趨勢，也未必排除具經濟意義的分歧。

## 12.4 Gate 3 — Eligibility DDD

證據：**insufficient information**。**OBSERVED** 支持戶數與集中度可見；**BLOCKED** 55+ 與非55+ 的醫療支出差距、相對前趨勢及 DDD coefficients。DDD 即使日後可估，也只應解釋為 target-eligible households 的 differential effect；無法排除差異影響 older households 的 town-time shocks、同時期年齡政策或社區 spillovers。

## 12.5 Outcome comparability

- **Medical — DOCUMENTED**：四波概念大致可比，但 2014 改變級距邊界；midpoint 為測量近似。
- **Care — DOCUMENTED**：2006–2014 可作 restricted-period；2017 定義改為保姆／安養院／身障照顧，屬 material change。
- **Food — DOCUMENTED**：2006–2010 與 2014–2017 各自較可比；2014 起外食／住宿另列，四波單一 causal comparison 不宜在未決定 harmonization 前執行。

## 12.6 Threat register

| Threat | Evidence | Severity | Can current data address it? | Recommended response |
|---|---|---|---|---|
| Endogenous station placement | Baseline aggregate differences can be measured; key resources/remoteness absent | High | Partly | Restore covariates and treat estimates as sensitivity evidence |
| Limited treated clusters | Gate 1 concentration/town counts observable but outcome joint cells absent | High | Partly | Restore joint cells; report cluster counts and leave-one-town-out |
| Repeated-cross-section composition change | Age marginals vary by wave; cannot link composition to outcome | High | Partly | Joint household extract and composition diagnostics |
| Historical station-list misclassification | Panel explicitly uses 114-year current roster and may omit closed stations | Critical | No | Obtain complete opening/closure history before defining never-treated |
| Care definition drift | 2017 wording materially changes service boundary | High | Yes | Restrict to 2006–2014 or supplementary use |
| Food definition drift | 2014 separates eating out/accommodation | High | Yes | Period-restricted analysis or explicit harmonization decision |
| Midpoint expenditure measurement | Repository documents midpoint/open-bin approximations | Medium | Partly | Retain interval coding; sensitivity/interval methods later |
| Survey-weight comparability | Candidate weights differ and definitions are unverified | High | No | Validate each wave's sampling/weight documentation |
| Spillovers | Community stations may affect non-eligible households | Medium | No direct measure | Interpret DDD as differential effect; add spillover sensitivity |
| Concurrent age-targeted policies | No township-year policy inventory in repository | High | No | Build concurrent-policy timeline/data before final DDD |

## 12.7 What would falsify the current research strategy?

- Strong cohort-vs-not-yet differential medical pre-trends, especially for 2014 where two primary pre-waves exist.
- Baseline selection aligned with medical outcomes/resources and not credibly addressed by design or sensitivity analysis.
- Restored joint data showing inadequate 55+ support, very few towns, or dominance by one town in 2010/2014.
- Restored DDD data showing the 55+ minus non-55+ gap diverged before treatment.
- Historical roster showing many registry-external controls were previously treated or station closures were selective.

## Unresolved items and smallest next actions

1. **BLOCKED — MISSING JOINT MICRODATA**：restore restricted household data or export joint sufficient statistics with outcome moments and inference inputs.
2. **BLOCKED — HISTORICAL TREATMENT HISTORY**：obtain complete station openings and closures; rebuild first-treatment and never-treated status.
3. **BLOCKED — WEIGHT DEFINITIONS**：supply per-wave sampling manuals and validated household weights.
4. **BLOCKED — DDD**：joint eligibility × medical outcome distribution is required; separate marginals cannot substitute.
5. **UNRESOLVED — COHORT MAPPING DECISION**：confirm whether cohorts are exact establishment years or first-observed survey-wave intervals before final causal estimation.
