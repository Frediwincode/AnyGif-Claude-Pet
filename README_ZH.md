📖 **Documentation:** [English](./README_EN.md) | [中文](./README_ZH.md)

# AnyGif Claude Pet 🐾

一只跟随你编程状态实时变化的桌面 GIF 宠物，通过 Claude Code hooks 驱动。
A desktop GIF pet that reacts to your Claude Code activity in real-time.

## 功能特性

- **桌面宠物窗口** -- 始终置顶、透明背景、可拖拽的 GIF 宠物
- **Claude Code hooks 集成** -- 实时监听 Claude Code 的工具调用事件，宠物状态随之变化
- **自定义 GIF 映射** -- 为 idle / thinking / working / happy / sad / celebrating / sleeping 七种状态各分配不同 GIF
- **Vibe Report** -- 每日 18:00 自动生成（或手动触发）基于 Gemini API 的编程氛围总结，以气泡形式弹出
- **菜单栏控制** -- 通过状态栏图标快速访问设置、安装 hooks、触发 Vibe Report
- **首次启动引导** -- 自动提示安装 Claude Code hooks
- **占位符动画** -- 未加载 GIF 时显示可爱的表情圆球，不同状态有不同动画表现

## 安装

### 使用 Swift Package Manager 构建

```bash
cd AnyGif-Claude-Pet
swift build -c release
```

### 使用 build.sh 脚本

```bash
chmod +x build.sh
./build.sh
```

构建产物位于 `.build/` 目录下。

> 需要安装 Xcode（完整版，非仅 Command Line Tools）。

## 使用方法

### 启动

```bash
# 直接运行（使用占位符动画或已配置的 GIF）
.build/AnyGifClaudePet

# 指定一个 GIF 文件
.build/AnyGifClaudePet /path/to/your.gif
```

### Hooks 工作原理

1. 首次启动时会提示安装 hooks，也可通过菜单栏 "Install Hooks" 手动安装
2. 安装后，hook 脚本被复制到 `~/.claude-pet/claude-pet-hook.sh`
3. 脚本注册到 `~/.claude/settings.json` 的 `hooks` 配置中
4. Claude Code 每次工具调用时，hook 脚本会将事件写入 `~/.claude-pet/events.jsonl`
5. 宠物应用通过轮询（每 0.5 秒检查一次）监听该文件变化，实时更新状态

### GIF 自定义

通过菜单栏 "Settings..." 打开设置窗口，为每种状态选择 GIF 文件：

| 状态 | 触发条件 |
|------|----------|
| idle | 默认状态 |
| thinking | Read / Grep / Glob 等工具调用 |
| working | Bash / Edit / Write 等工具调用 |
| happy | 工具调用完成 |
| sad | 出现错误 |
| celebrating | Claude Code 任务完成 |
| sleeping | 5 分钟无活动 |

GIF 映射保存在 `~/Library/Application Support/AnyGifClaudePet/settings.json`。

### Vibe Summary 设置

1. 在设置窗口中填入 Google API Key（Gemini API）
2. 每日 18:00 自动生成，或通过菜单栏 "Vibe Report" 手动触发
3. 总结内容基于当日的 Claude Code 使用统计

## ⚠️ 已知问题与注意事项

### GIF 路径问题（重要）

- GIF 文件选择后，系统保存的是「绝对路径」（如 `/Users/xxx/Downloads/cat.gif`）
- 如果 GIF 文件被移动、重命名或删除，桌宠将无法加载该 GIF，会回退到占位符动画
- 建议：将 GIF 文件放在一个固定目录（如 `~/Pictures/claude-pet/`）并且不要移动

### 配置变更需重启

- 修改 GIF 映射或 Hooks 配置后，需要：
  1. 重启桌宠应用（退出后重新打开）
  2. 重启 Claude Code 会话（hooks 配置在会话启动时加载，运行中的会话不会读取新配置）

### LSUIElement 限制

- 本应用以 LSUIElement 模式运行（无 Dock 图标），系统不会自动提供 Edit 菜单
- 已在代码中手动添加 Edit 菜单以支持 Cmd+C/V/X/A，但如果粘贴仍不工作，尝试先点击一次文本框再粘贴

### API Key 输入

- Gemini API Key 输入后 3 秒会自动遮盖为圆点，点击文本框可恢复明文显示
- Key 保存在 `~/Library/Application Support/AnyGifClaudePet/settings.json` 中（明文），请注意安全

### Hooks 格式

- Claude Code hooks 使用嵌套格式：`{ "hooks": [{"type": "command", "command": "..."}], "matcher": "" }`
- 如果从旧版本升级，建议通过菜单栏 "Install Hooks" 重新安装以确保格式正确

## 截图

<!-- TODO: 添加截图 -->

## 许可证

MIT
