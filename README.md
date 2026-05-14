<div align="center">

<a href="https://github.com/JDKamalakar/DMS-ScreenCapture_Toolbar">
    <img src="https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/f2df53afcd0870445e7f3cd45e91ac135a04442e/assets/danklogo.svg" alt="Toolbar Logo" title="Toolbar Logo" width="80"/>
</a>

# [DMS-ScreenCapture_Toolbar](#)

### Premium Screen Capture Management

A high-end, glassmorphic floating pill toolbar for the Dank Material Shell. Seamlessly switch between photo and video modes with tactile animations and dynamic, mode-aware controls.

[![DMS Compatible](https://img.shields.io/badge/DMS-Compatible-purple.svg?labelColor=27303D)](https://github.com/Dank-Material-Shell)
[![License](https://img.shields.io/badge/License-DMS-blue.svg?labelColor=27303D&color=0877d2)](https://github.com/DankMaterialShell)
[![Maintenance Status](https://img.shields.io/badge/Status-Maintained-green.svg?labelColor=27303D&color=946300)](https://github.com/JDKamalakar/DMS-ScreenCapture_Toolbar/graphs/commit-activity)

## Download

[![DMS Plugin Gallery](https://img.shields.io/badge/DMS-Plugin%20Gallery-06599d?style=flat-square&logo=linux&logoColor=white)](https://danklinux.com/plugins)

*Requires Dank Material Shell (DMS) 1.0 or higher.*

## Requirements

The toolbar uses DMS for its standard capture path and optional Wayland utilities for the enhanced workflows:

* `slurp` — interactive region selection for recording and optional multi-monitor screenshots
* `grim` — optional multi-monitor screenshot capture
* `wl-clipboard` — clipboard support for the optional multi-monitor screenshot path
* `satty` — default screenshot editor used by `Ctrl+Space` when no custom editor pipe is configured

<div align="left">

```bash
# Debian/Ubuntu
sudo apt install slurp grim wl-clipboard satty
```

```bash
# Fedora
sudo dnf install slurp grim wl-clipboard satty
```

```bash
# Arch Linux
sudo pacman -S slurp grim wl-clipboard satty
```

```bash
# Other distributions
# Install the equivalent packages: slurp grim wl-clipboard satty
```

</div>

## Features

<div align="left">

* **Premium Glassmorphism**: Translucent, theme-aware "Floating Pill" design with configurable toolbar and recording pill opacity.
* **Multi-Monitor Recording Pill**: "Click-to-Move" logic with screen-aware positioning, allowing you to move the recording pill across connected displays.
* **Adaptive Theme Support**: Intelligent UI that dynamically flips icon and text colors between black and white based on your theme brightness for guaranteed visibility.
* **Smart Recording Pill**: A collapsible, high-frequency overlay that displays live recording duration and provides instant access to stop, pause, and screenshot actions.
* **Tactile Interaction**: Features playful 360° spins, tilt-and-jump micro-animations, and responsive Dank Ripples on every interactive element.
* **Dynamic Settings**: A context-aware popup bubble that automatically filters capture settings (FPS, Audio, Formats) based on your active mode (Photo vs. Video).
* **Flexible Recording Audio**: Record system output audio and microphone input independently.
* **Separate Output Settings**: Screenshots and recordings can use independent custom directories and filenames.
* **Versatile Capture**: Native support for interactive region selection, active monitor focus, full-workspace grabbing, and optional `slurp` + `grim` multi-monitor screenshots.
* **Power Workflow**: Lightning-fast controls with `Spacebar` to trigger captures, `Ctrl+Space` to send a screenshot to the editor, and `Escape` for instant dismissal.

</div>

## Shortcuts

<div align="left">

* `Space`: run the normal capture or recording action for the selected mode.
* `Ctrl+Space`: take a screenshot and pipe it to the configured editor command.
* `Escape`: close the toolbar.

If the editor pipe command is empty, the toolbar uses:

```bash
{ mkdir -p "$HOME/Pictures/Screenshots"; satty --filename - --output-filename "$HOME/Pictures/Screenshots/screenshot_$(date '+%Y-%m-%d_%H-%M-%S')_edit.png"; }
```

If `satty` is not installed, a notification is shown so you can install it or set a custom editor pipe command such as `swappy -f -`.

</div>

## DMS Shortcut Setup

<div align="left">

To open the toolbar from a keyboard shortcut, add an entry in **DMS Settings** -> **Keyboard Shortcuts**:

* Type: `Run a program`
* Action: `dms ipc call screenCaptureToolbar toggle`

</div>

## Multi-Monitor Screenshots

<div align="left">

Interactive screenshot capture can optionally use `slurp` and `grim` for region selection across displays. Enable **Multi-Monitor Screenshots** in settings to use this path. When disabled, screenshots keep using the standard `dms screenshot` behavior.

</div>

## Interface

<div align="center">
    <img src="assets/Screen_Recording_UI.png" width="49%" alt="Screen Recording UI"/>
    <img src="assets/Screenshot_UI.png" width="49%" alt="Screenshot UI"/>
</div>
<br>
<div align="center">
    <img src="assets/Recording_Pill_UI.png" width="30%" alt="Recording Pill Collapsed"/>
    <img src="assets/Recording_Pill_E_UI.png.png" width="60%" alt="Recording Pill Expanded"/>
</div>

## Configuration

<div align="center">
    <img src="assets/Settings.png" width="40%" alt="Settings"/>
</div>

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Before reporting a new issue, take a look at the [FAQ](https://github.com/JDKamalakar/DMS-ScreenCapture_Toolbar/wiki), the [changelog](https://github.com/JDKamalakar/DMS-ScreenCapture_Toolbar/releases) and the already opened [issues](https://github.com/JDKamalakar/DMS-ScreenCapture_Toolbar/issues).

### Credits

Built with ❤️ for the [Dank Material Shell](https://github.com/DankMaterialShell) community.

<a href="https://github.com/JDKamalakar/DMS-ScreenCapture_Toolbar/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=JDKamalakar/DMS-ScreenCapture_Toolbar" alt="Screen Capture Toolbar contributors" title="Screen Capture Toolbar contributors" width="100"/>
</a>

### Disclaimer

This application is an independent utility for Dank Material Shell.

### 📜 License

Part of DankMaterialShell. Check the main repository for license information.

</div>
