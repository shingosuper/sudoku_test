# Color Queens（Godot MVP）

一款竖屏休闲逻辑谜题原型。玩家需要在彩色区域棋盘上放置皇冠，同时满足每行、每列、每个颜色区域各一个皇冠，且皇冠不能八方向相邻。

## 当前版本改动

本仓库基于 `jydoit/sudoku_test` 扩展，当前版本主要做了这些更新：

- 关卡页保留原棋盘规则，并提供返回首页入口
- 默认关卡从 5 个扩展到 50 个，全部为 6×6 唯一解关卡
- 50 个关卡均标记难度：新手、普通、困难、专家
- 每关预置 `hintSteps` 和完整 `solveSteps`，标记为 `no_guess`，用于记录无需猜测的逻辑解题路径
- 顶部增加关卡下拉选择，方便调试和快速切换关卡
- 增加内置关卡编辑器，可编辑关卡名称、提示文字、颜色区域和答案点位
- 增加编辑器入口按钮，可从主界面进入编辑器
- 更新冒烟测试，覆盖 50 关数据结构、答案合法性、唯一解和无猜解题路径检查
- 新增编辑器冒烟测试，验证编辑器加载、涂色和答案模式切换

## 运行

项目基于 **Godot 4.7**。使用 Godot Project Manager 导入根目录的 `project.godot`，然后点击运行即可。

macOS 也可以直接执行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .
```

无界面启动检查：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5
```

完整冒烟测试：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
```

## 已实现

- 竖屏移动端 UI：资源栏、关卡信息、进度、棋盘、操作按钮、广告占位区
- 休闲闯关首页：金币、生命、庭院进度、开始关卡、每日奖励和宝箱入口
- JSON 关卡加载，内置 50 个 6×6 唯一解关卡
- 格子状态循环：空白 → 排除标记 → 皇冠 → 空白
- 行、列、颜色区域和八方向相邻的即时冲突提示
- 撤销、清除、教学提示、通关奖励与下一关
- 教学提示会直接寻找当前棋盘上最优先判断的一步，一次性标出观察范围、候选格、排除格和下一步建议
- 教学提示支持候选锁定、成组锁定和反证排除，并使用可见颜色名说明区域，例如红色区域、绿色区域
- 教学提示不会直接替玩家放置皇冠，玩家需要根据解释自己操作
- 本地保存当前关卡、棋盘、金币、提示次数和完成记录
- 内置关卡编辑器，支持调整区域和答案点位
- 预留主题入口；棋盘和关卡结构支持任意 N×N 扩展

## 代码结构

```text
AGENTS.md                  项目协作、文档和测试规则
data/levels.json           关卡配置
docs/PRODUCT_REQUIREMENTS.md 产品需求文档与回归测试清单
scenes/main.tscn           主场景
scenes/level_editor.tscn   关卡编辑器场景
scripts/main.gd            UI、游戏状态、规则、存档与通关流程
scripts/game_board.gd      自绘响应式棋盘与点击反馈
scripts/level_editor.gd    关卡编辑器逻辑
scripts/level_store.gd     JSON 加载与基础数据校验
tests/smoke_test.gd        核心流程冒烟测试
tests/editor_smoke_test.gd 编辑器冒烟测试
```

新增关卡时在 `data/levels.json` 中加入配置即可。`solution` 用于提示系统；正常通关判断只依赖玩家摆放是否满足规则，不会硬编码答案。
