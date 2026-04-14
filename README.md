# Click Floater

A floating auto-clicker prototype for macOS.

## Current features

- Floating control panel
- New click points spawn as draggable floating markers
- Markers can be dragged anywhere on screen
- Each point can have its own name, click interval, and enabled state
- Each point can be started or stopped independently
- Each point can have its own run duration in hours, minutes, and seconds
- Start all / stop all controls
- Running markers switch into click-through mode so they do not block the real target underneath
- The mouse is moved back to its original location immediately after each click attempt
- Global shortcuts: `Command + .` to start/pause, `Command + /` to show/hide the floater
- Click point positions are persisted between launches

## How to run

### Option 1, double-click the launcher

Double-click:

- `run-click-floater.command`

### Option 2, run from Terminal

```bash
cd /Users/William/.openclaw/workspace/mac-click-floater
swift run
```

## First-time setup

1. Launch the app and click `Check Permissions`
2. Open **System Settings > Privacy & Security > Accessibility**
3. Allow the app to control your Mac
4. Return to the app and click `Start`

## Current limitations

- This is still a point-based clicker, not an area-based random clicker
- System-level clicking still takes over the mouse briefly at click time, so it is not fully invisible yet
- More advanced scheduling, such as delayed starts or grouped patterns, is not implemented yet

## Planned improvements

- Area click mode instead of single-point only
- Click count limits
- Left-click / right-click switching
- Per-point delayed start and staggered scheduling
- Menu bar mode
