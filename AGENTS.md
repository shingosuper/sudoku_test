# 项目规则

适用范围：整个仓库。

## 分支规则

- 日常迭代默认在 `codex-iteration` 分支进行。
- `main` 作为稳定分支，不直接承接日常实验性修改。
- 提交前确认当前分支，避免把迭代直接提交到 `main`。

## 产品文档规则

- 产品功能事实源为 `docs/PRODUCT_REQUIREMENTS.md`。
- 新增、删除或修改功能时，必须同步更新该文档。
- 修改 UI、玩法、提示、经济、关卡、存档、编辑器或测试流程时，也必须同步更新该文档。
- 如果实现与文档不一致，要么修代码，要么修文档，不能留下隐性差异。

## 测试与验证规则

正式发布前必须按 `docs/PRODUCT_REQUIREMENTS.md` 的“发布前回归测试清单”执行回归。

每次代码改动后至少运行：

```bash
HOME=/Users/shingo_mac/Documents/Codex/2026-06-29/du-y/work/godot_home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/shingo_mac/Desktop/push_sudoku_shingosuper --script res://tests/smoke_test.gd
```

如果改动涉及关卡编辑器，还必须运行：

```bash
HOME=/Users/shingo_mac/Documents/Codex/2026-06-29/du-y/work/godot_home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/shingo_mac/Desktop/push_sudoku_shingosuper --script res://tests/editor_smoke_test.gd
```

## 关卡数据规则

- `data/levels.json` 中默认关卡必须保持唯一解。
- 默认关卡必须包含难度标记。
- 默认关卡必须包含 `logicStatus: no_guess`。
- 默认关卡必须包含 `hintSteps` 和 `solveSteps`。
- 修改关卡后必须运行核心冒烟测试，确认唯一解和无猜路径校验仍通过。

## 提示系统规则

- 提示不能直接替玩家放置皇冠。
- 提示必须解释原因，不能只给“最佳格子”结论。
- 提示文案应使用可见颜色名，例如黄色区域、绿色区域，避免使用“颜色区域 5”这类内部编号。
- 如果新增解题策略，必须同步更新产品需求文档中的提示模块和回归测试重点。

## UI 规则

- 项目以竖屏移动端体验为优先。
- 修改 UI 后需要检查移动端宽度下是否有裁切、遮挡、按钮过小或文本溢出。
- 首页和关卡页职责分离：金币、排行榜等资源与社交入口主要放首页；关卡页优先服务解题。

## 提交前检查

提交前确认：

- 当前分支正确。
- 工作区只包含本次任务相关改动。
- 产品文档已同步。
- 自动测试已运行，无法运行时需在提交说明或交付说明中明确原因。
