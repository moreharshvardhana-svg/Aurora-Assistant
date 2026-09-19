# Aurora AI-Assistant

A quick, time-saving AI overlay for Linux desktops running Wayland, Rofi, and SwayNC.

## Features
- Context-aware multi-turn memory saved across prompts.
- Native SwayNC GTK Pango styling.
- One-click copy action to clipboard with stripped markup tags for clean pasting.

## Dependencies
- `curl`
- `jq`
- `rofi-wayland` (or `wofi`)
- `notify-send` / `swaync`
- `wl-clipboard`

## Setup
1. Clone this repository:
```bash
git clone [https://github.com/moreharshvardhana-svg/Aurora-Assistant](https://github.com/moreharshvardhana-svg/Aurora-Assistant)
cd Aurora-Assistant
chmod +x Aurora-Assistant.sh

```

2. Set up your Gemini API key:

```bash
cp geminiapikey.sh.example geminiapikey.sh
# Edit geminiapikey.sh and paste your Gemini API key from [https://aistudio.google.com/](https://aistudio.google.com/)

```

3. Bind `Aurora-Assistant.sh` to a key in your Hyprland or Sway config:

**Hyprland (`hyprland.conf`):**

```ini
bind = $mainMod, G, exec, /path/to/Aurora-Assistant/Aurora-Assistant.sh

```

**Hyprland Lua (`hyprland.lua`):**

```lua
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("/path/to/Aurora-Assistant/Aurora-Assistant.sh"))

```

> [!NOTE]
> If you are on GNOME or KDE Plasma, you can add a shortcut pointing to the script directly in your system settings.

More features coming soon!
