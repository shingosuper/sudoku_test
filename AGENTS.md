# 项目规则

适用范围：整个仓库。

## 分支规则

- 当前团队协作以朋友仓库 `jydoit` 的 `dev` 分支为集成分支：
  `https://github.com/jydoit/sudoku_test.git`
- 新开 Codex 对话或开始新任务时，先确认远端存在：
  `jydoit https://github.com/jydoit/sudoku_test.git`。
- 日常开发不要直接改 `dev` 或 `master`，应先从 `jydoit/dev` 拉取最新代码，再新建个人开发分支。
- 推荐本地开发分支命名：`codex-dev-iteration`，或按任务命名为 `codex/<task-name>`。
- 约定合并顺序：个人开发分支 -> `dev` -> `master`。
- `master` 作为最终稳定分支，不直接承接日常修改。
- 旧的 `codex-iteration -> main` 流程只用于历史仓库流程；除非用户明确要求，否则新工作按 `dev -> master` 流程处理。
- 提交前确认当前分支，避免把迭代直接提交到 `dev`、`master`、`main`。

开始新任务前推荐执行：

```bash
git fetch jydoit dev
git switch -c codex-dev-iteration jydoit/dev
```

如果 `codex-dev-iteration` 已存在，则执行：

```bash
git switch codex-dev-iteration
git pull
```

## 产品文档规则

- 产品功能事实源为 `docs/PRODUCT_REQUIREMENTS.md`。
- 新增、删除或修改功能时，必须同步更新该文档。
- 修改 UI、玩法、提示、经济、关卡、存档、编辑器或测试流程时，也必须同步更新该文档。
- 如果实现与文档不一致，要么修代码，要么修文档，不能留下隐性差异。

## 玩法硬约束

- 核心玩法必须保持为从棋盘格中找出皇冠：每行、每列、每个颜色区域有且仅有一个皇冠，皇冠不能八方向相邻。
- 核心棋盘交互必须区分普通排除 X、皇冠和错误红色 X；普通 X 可取消，错误红色 X 不可取消也不可撤销。
- 棋盘必须支持滑动批量处理普通排除 X：从空格开始滑动时连续标记普通 X；从普通 X 开始滑动时连续取消普通 X；滑动不得标记皇冠，也不得改变皇冠或错误红色 X。
- 棋盘颜色必须使用产品文档固化的“明亮经典”10 色默认色板；相邻区域不能使用相近颜色。
- 新手教程必须使用单张 5x5 教程棋盘图讲完核心规则，包含双击找皇冠、滑动排除皇冠周围格、同行同列排除、提示线索和完整找出全部皇冠；玩家可见文案必须使用“找到皇冠”或“找出皇冠”。

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

- 提示不能直接替玩家找出皇冠。
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
