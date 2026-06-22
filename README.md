# Color Queens（Godot MVP）

一款竖屏休闲逻辑谜题原型。玩家需要在彩色区域棋盘上放置皇冠，同时满足每行、每列、每个颜色区域各一个皇冠，且皇冠不能八方向相邻。

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
- JSON 关卡加载，内置 5 个 6×6 唯一解关卡
- 格子状态循环：空白 → 皇冠 → 排除标记 → 空白
- 行、列、颜色区域和八方向相邻的即时冲突提示
- 撤销、清除、金币提示、通关奖励与下一关
- 本地保存当前关卡、棋盘、金币、提示次数和完成记录
- 预留主题入口；棋盘和关卡结构支持任意 N×N 扩展

## 代码结构

```text
data/levels.json           关卡配置
scenes/main.tscn           主场景
scripts/main.gd            UI、游戏状态、规则、存档与通关流程
scripts/game_board.gd      自绘响应式棋盘与点击反馈
scripts/level_store.gd     JSON 加载与基础数据校验
tests/smoke_test.gd        核心流程冒烟测试
```

新增关卡时在 `data/levels.json` 中加入配置即可。`solution` 用于提示系统；正常通关判断只依赖玩家摆放是否满足规则，不会硬编码答案。
