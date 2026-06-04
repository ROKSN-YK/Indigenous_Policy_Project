# Git Workflow

## 每次開始工作

執行：

```bash
git status
```

確認：

```text
nothing to commit, working tree clean
```

---

## 查看目前分支

```bash
git branch
```

---

## 查看 Worktree

```bash
git worktree list
```

---

## 完成修改後

```bash
git add .
git commit -m "說明本次修改"
git push
```

---

## 查看歷史紀錄

```bash
git log --oneline
```

---

## 查看差異

```bash
git diff
```

---

## 建立保險點

```bash
git tag version-name
```

例如：

```bash
git tag before-major-change
```

---

## 回到指定版本

查看：

```bash
git log --oneline
```

切換：

```bash
git checkout <commit-id>
```

---

## 常用檢查

```bash
git status
git branch
git worktree list
```