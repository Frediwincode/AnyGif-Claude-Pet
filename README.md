# AnyGif Claude Pet 🐾

> 一只跟随你编程状态实时变化的桌面 GIF 宠物，通过 Claude Code hooks 驱动。
> A macOS desktop GIF pet that reacts to your Claude Code activity in real-time via hooks.

📖 **Documentation:** [English](./README_EN.md) | [中文](./README_ZH.md)

---

## Features

- 🖥️ **Desktop Pet Window** -- Always-on-top, transparent, draggable GIF pet
- 🔗 **Claude Code Hooks** -- Real-time tool call event monitoring, pet state changes accordingly
- 🎨 **Custom GIF Mapping** -- Assign different GIFs to 7 states: idle / thinking / working / happy / sad / celebrating / sleeping
- 📊 **Vibe Report** -- Daily AI-generated coding vibe summary via Gemini API
- 🎛️ **Menu Bar Control** -- Quick access to settings, hooks installation, and vibe reports
- 🎭 **Placeholder Animations** -- Built-in animated emoji when no GIF is loaded

## Quick Start

### Build

```bash
cd AnyGif-Claude-Pet
swift build -c release
# or
chmod +x build.sh && ./build.sh
```

### Run

```bash
.build/AnyGifClaudePet
```

> Requires macOS 13+ (Ventura) and Xcode.

## License

MIT
