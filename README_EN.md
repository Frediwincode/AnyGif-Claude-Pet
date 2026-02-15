📖 **Documentation:** [English](./README_EN.md) | [中文](./README_ZH.md)

# AnyGif Claude Pet 🐾

A desktop GIF pet that reacts to your Claude Code activity in real-time, driven by Claude Code hooks.

## Features

- **Desktop Pet Window** -- Always-on-top, transparent background, draggable GIF pet
- **Claude Code Hooks Integration** -- Listens to Claude Code tool call events in real-time; the pet's state changes accordingly
- **Custom GIF Mapping** -- Assign different GIFs to seven states: idle / thinking / working / happy / sad / celebrating / sleeping
- **Vibe Report** -- Automatically generated daily at 18:00 (or triggered manually) using the Gemini API; appears as a speech bubble
- **Menu Bar Control** -- Quick access to settings, hook installation, and Vibe Report via the status bar icon
- **First Launch Onboarding** -- Automatically prompts to install Claude Code hooks on first run
- **Placeholder Animation** -- When no GIF is loaded, displays a cute emoji circle with different animations per state

## Installation

### Build with Swift Package Manager

```bash
cd AnyGif-Claude-Pet
swift build -c release
```

### Build with build.sh

```bash
chmod +x build.sh
./build.sh
```

Build artifacts are located in the `.build/` directory.

> Requires Xcode (full installation, not just Command Line Tools).

## Usage

### Launch

```bash
# Run directly (uses placeholder animations or configured GIFs)
.build/AnyGifClaudePet

# Specify a GIF file
.build/AnyGifClaudePet /path/to/your.gif
```

### How Hooks Work

1. On first launch, you will be prompted to install hooks. You can also install them manually via the menu bar "Install Hooks" option.
2. After installation, the hook script is copied to `~/.claude-pet/claude-pet-hook.sh`
3. The script is registered in the `hooks` configuration of `~/.claude/settings.json`
4. Each time Claude Code makes a tool call, the hook script writes the event to `~/.claude-pet/events.jsonl`
5. The pet app polls this file every 0.5 seconds to detect changes and update its state in real-time

### GIF Customization

Open the settings window via "Settings..." in the menu bar to assign a GIF file for each state:

| State | Trigger Condition |
|-------|-------------------|
| idle | Default state |
| thinking | Tool calls like Read / Grep / Glob |
| working | Tool calls like Bash / Edit / Write |
| happy | Tool call completed |
| sad | An error occurred |
| celebrating | Claude Code task completed |
| sleeping | 5 minutes of inactivity |

GIF mappings are saved in `~/Library/Application Support/AnyGifClaudePet/settings.json`.

### Vibe Summary Settings

1. Enter your Google API Key (Gemini API) in the settings window
2. Automatically generated daily at 18:00, or trigger manually via "Vibe Report" in the menu bar
3. The summary is based on the day's Claude Code usage statistics

## ⚠️ Known Issues and Notes

### GIF Path Issues (Important)

- After selecting a GIF, the system saves its absolute path (e.g., `/Users/xxx/Downloads/cat.gif`)
- If the GIF file is moved, renamed, or deleted, the pet will fail to load it and fall back to the placeholder animation
- Recommendation: Place your GIF files in a fixed directory (e.g., `~/Pictures/claude-pet/`) and do not move them

### Configuration Changes Require Restart

- After modifying GIF mappings or Hooks configuration, you need to:
  1. Restart the pet app (quit and reopen)
  2. Restart the Claude Code session (hooks configuration is loaded at session start; running sessions will not pick up new configuration)

### LSUIElement Limitation

- This app runs in LSUIElement mode (no Dock icon), so the system does not automatically provide an Edit menu
- An Edit menu has been manually added in code to support Cmd+C/V/X/A, but if paste still does not work, try clicking the text field once before pasting

### API Key Input

- The Gemini API Key is automatically masked with dots 3 seconds after input; click the text field to reveal it again
- The key is stored in plaintext in `~/Library/Application Support/AnyGifClaudePet/settings.json` -- please be mindful of security

### Hooks Format

- Claude Code hooks use a nested format: `{ "hooks": [{"type": "command", "command": "..."}], "matcher": "" }`
- If upgrading from an older version, it is recommended to reinstall via "Install Hooks" in the menu bar to ensure the correct format

## Screenshots

<!-- TODO: Add screenshots -->

## License

MIT
