# Phase 3 Plan Check — Goal-Backward Verification Report

**Checker**: gsd-plan-checker（goal-backward, adversarial）
**Date**: 2026-08-19
**Phase**: 3 — `03-dispatch-source-install-drift`（Source/安裝副本分岔修復, Milestone 1.2）
**Plan(s) verified**: `.planning/phases/03-dispatch-source-install-drift/03-PLAN.md`
**Status**: **ISSUES FOUND — 0 blocker(s), 3 warning(s), 3 info**

> 註：本工作目錄 `/Users/bryan/.claude/gsd-addon` 只是「已安裝鏡像」（僅含 soldier-logs），
> 真正的規劃 ground truth 在 `/Users/bryan/Documents/gsd-addon`。本報告基於後者產出。
> 另註：本 Phase 於 ROADMAP 已標記完成（commit 34123d7..a9d58e7），本檢查為對 03-PLAN.md 的靜態、pre-execution 審查。

---

## 1. Coverage Summary

| 需求來源 | 需求意圖（ROADMAP） | 覆蓋任務 | 覆蓋狀態 |
|----------|--------------------|----------|----------|
| Milestone 1.2 背景（新發現） | 修復已安裝副本 `build_prompt()` 插值 bug（派工假性 exit 1） | 3.2 (+3.1 驗證前提) | ✅ 已覆蓋 |
| Milestone 1.2 / Phase 3 | 消除 source repo 與安裝副本分岔, 兩份 `gsd-dispatch.sh` 完全一致 | 3.1 (盤點) + 3.3 (同步策略) | ✅ 已覆蓋 |
| ROADMAP Phase 3（回灌語） | prompts-based 設計回灌 source repo | 3.3 選項 A | ✅ 已覆蓋 |
| Phase 3 目標 | 真實派工驗證 bug 已修復 | 3.4 | ✅ 已覆蓋 |

ROADMAP 並未為 Phase 3 提供帶正式 requirement ID（R-XX）的段落；以 Milestone 1.2 意圖與 Phase 目標為準，
四項意圖皆有具體任務覆蓋，**無零覆蓋**。

---

## 2. Success Criteria Traceability

| 成功標準（03-PLAN.md L15-20） | 交付任務 | 判定 |
|------------------------------|----------|------|
| C1 確認已安裝副本重構設計與差異範圍 | 3.1 | ✅ 已覆蓋 |
| C2 決定策略（回灌 vs 重裝） | 3.3 | ✅ 已覆蓋 |
| C3 修復 build_prompt() 插值 bug | 3.2 | ⚠️ 已覆蓋, 但前提（bug 存在於 226 行）於規劃時未驗證（見 W2） |
| C4 兩份檔案語法檢查通過且邏輯一致 | 3.2 (bash -n) + 3.3 (一致) | ⚠️ 已覆蓋, 但措辭弱於 ROADMAP「完全一致」（見 W3） |
| C5 執行真實派工驗證 | 3.4 | ✅ 已覆蓋 |

---

## 3. Dimension Results

| # | 維度 | 判定 | 說明 |
|---|------|------|------|
| 1 | Requirement Coverage | ✅ PASS | 四項意圖全覆蓋, 無零覆蓋 blocker |
| 2 | Task Completeness | ✅ PASS | 4 任務皆具具體動作 + 驗收準則 |
| 3 | Dependency Correctness | ✅ PASS | 3.1→3.3、3.2→3.4 順序正確; 3.3 明示依賴 3.1 盤點 |
| 4 | Key Links / Wiring | ✅ PASS | 每個成功標準皆有對應任務 |
| 5 | Scope Sanity | ✅ PASS(INFO) | 4 任務略高於 2-3 目標值, 但含驗證型任務, 非拆分問題 |
| 6 | Success-Criteria Traceability | ✅ PASS | 5 個成功標準皆有任務交付（含 2 個 minor 弱化） |
| 7 | Locked Decision Compliance | ⚠️ WARNING | 見 W3（接受「刻意不同」弱化 ground truth 之「完全一致」） |
| 8 | Scope Reduction Detection | ✅ PASS | 無「v1/for now/placeholder/stub」套用在 in-scope 成功標準 |
| 9 | Verification Plan Quality | ✅ PASS(INFO) | bash -n / bash -x / diff 具體; bash 專案無 type checker; 缺自動化回歸單元測試（見 I2） |
| 10 | Fact-check load-bearing claims | ⚠️ WARNING | 行號內部矛盾 + prompts 路徑錯判（見 W1/W2） |

---

## 4. Issues

### Blockers
無。

### Warnings

- **W1 — build_prompt() 行號內部矛盾（fact-check）**
  - 位置: 03-PLAN.md L18（成功標準/任務 3.2）「第 226 行附近」vs L36（背景）「函式（約第 130-150 行）附近」。
  - 兩處對同一函式的行號引用互相矛盾。現行檔案（437 行）中 `build_prompt()` 位於 L167、`FULL_PROMPT="$(build_prompt …)"` 位於 L230——「226」接近 FULL_PROMPT 賦值處, 而「130-150」與之不符。
  - fix_hint: 統一為單一可信行號來源（以 `rg -n build_prompt` 實查）; 若為帶 bug 的舊版本, 於背景補一枝術註記「行號以執行時實際版為準」。

- **W2 — prompts 路徑錯判（fact-check）**
  - 位置: 03-PLAN.md L54（任務 3.1）「`ls ~/.claude/gsd-addon/scripts/prompts/` 或類似路徑」。
  - 實際 prompts 目錄為 repo 根 `~/.claude/gsd-addon/prompts/`（與 scripts/ 平級, 非其子目錄）; 該錯誤路徑 `scripts/prompts/` 不存在。SUMMARY 亦自承此為「初始搜尋路徑誤判」。
  - fix_hint: 改為 `ls -la "$PROJECT_DIR/prompts/"`（`PROJECT_DIR` 由腳本 L92 定義）, 或直接以 `PROMPTS_DIR="${PROJECT_DIR}/prompts"`（L99）為準。

- **W3 — 成功標準/驗收措辭弱於 ROADMAP ground truth（locked-decision 弱化）**
  - 位置: 03-PLAN.md L89（任務 3.3 驗收「…或明確記錄為何刻意不同」）; L19（成功標準 C4「邏輯一致」）。
  - ROADMAP Phase 3 / 背景明示既有假設為「兩者應永遠保持**逐字元相同**」與「兩份 gsd-dispatch.sh **完全一致**」。計畫允許「記錄刻意不同」與「邏輯一致」為完成條件, 比 ground truth 的「完全一致/逐字元相同」弱一階, 屬低度 rigor 縮減。
  - fix_hint: 將端態收斂條件收緊為「`diff` 輸出為空（逐字元一致）」, 把「刻意不同」僅保留為例外並需明確 ADR 佐證。實際執行已達逐字元一致（見下）, 故不阻斷執行。

### Info

- **I1 — 任務 3.2 前提（bug 存在於 226 行）於規劃時未經證實**
  - 計畫正向作法是把盤點（3.1）排在修復（3.2）之前, 已能吸收「bug 其實已修復」的情形（SUMMARY 即記錄 Task 3.2 降級為驗證）。此屬良好的 de-risking, 非缺陷; 僅提醒成功標準 C3 預設「需要修復」。
  - fix_hint（選用）: 於成功標準 C3 加注「若盤點發現 bug 已不存在, 則驗證即可視為完成」。

- **I2 — 對 build_prompt() 缺自動化回歸測試**
  - 驗證僅仰賴 `bash -n` + E2E 派工。bash 專案無測試框架, 可接受; 若有意長期維護, 可加一個針對 `build_prompt()` 變數代換的小型 assert script。
  - fix_hint（選用）: 新增 `test/build_prompt_test.sh` 覆蓋 `{{PHASE}}`/`{{TARGET_DIR}}`/`{{TODAY}}`/`{{PHASE_SECTION}}` 代換與特殊字元（ROADMAP 含 `/`）。

- **I3 — 任務數稍高於 2-3 目標值**
  - 4 個任務, 但 3.2 為修復、3.4 為驗證, 規模合理, 非 5+ 拆分問題。僅供參考。

---

## 5. Recommendation

**可執行（Ready to proceed）。** 0 blocker。計畫目標（分岔修復、回灌、兩檔一致、bug 修復、E2E 驗證）與 ROADMAP 意圖一致, 任務可驗收、依賴無環、成功標準皆可追溯。三項 warning 皆為限界/措辭層級（行號內部矛盾、prompts 路徑、端態收緊）, 不影響達成 Phase 目標, 建議於執行或後續補行（W1/W2 修正文句、W3 於 SUMMARY 明記達成逐字元一致）。

交叉核實：本 Phase 現已按計畫完成（source 與安裝副本 `diff` 為空 = 逐字元一致, `bash -n` 通過, SUMMARY 記錄 Option A 回灌 + install.sh 補拷 prompts）。
