# Agent Workflow

## 基本原則

主專案：

```text
Indigenous_Policy_Project
```

Agent 工作區：

```text
Indigenous_Policy_Project.worktrees
```

原則：

- 主專案是正式版本
- Agent 工作區是測試版本
- 不直接在 Agent 工作區工作
- 合併前一定先檢查

---

## 開始 Agent 任務前

確認主專案乾淨：

```bash
git status
```

看到：

```text
nothing to commit, working tree clean
```

才開始。

---

## 查看有哪些 Agent

```bash
git worktree list
```

---

## 查看有哪些分支

```bash
git branch
```

---

## 查看 Agent 改了哪些檔案

例如：

```bash
git diff main..agents/indigenous-economy-survey-analysis --stat
```

---

## 查看詳細修改內容

```bash
git diff main..agents/indigenous-economy-survey-analysis
```

---

## 合併前建立保險點

```bash
git tag before-agent-merge
```

---

## 合併 Agent

```bash
git merge agents/indigenous-economy-survey-analysis
```

---

## 合併後檢查

確認：

- 程式可以執行
- Outputs 正常
- 原始資料沒有被修改
- 結果符合預期

---

## 推送到 GitHub

```bash
git push
```

---

## 發現問題要回退

```bash
git reset --hard before-agent-merge
```

注意：

此動作會捨棄合併後修改。