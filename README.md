# Aurora AI-Assistant

A quick, time-saving AI overlay for Linux desktops running Wayland, Rofi, and SwayNC.

## Features
- Context-aware multi-turn memory saved across prompts.
- Native SwayNC GTK Pango styling.
- One-click copy action to clipboard with stripped markup tags for clean pasting.

## What's New

- **Optional On-Device Code Execution:** Direct execution of terminal tasks, Includes safety prompts and manual confirmation buttons.
- **Configurable Settings:** You can now easily adjust your model choice and features.
- **Enhanced Formatting:** Native text styling, color highlights, and automatic XML entity escaping for SwayNC and notification daemons.
- **Smart Context Compaction:** Long conversation history is now summarized in a more streamlined way.

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

### Configuration

Aurora includes a configuration file (`Aurora.conf`).

#### Model Selection
Aurora defaults to `gemini-3.6-flash`. You can change the model through the config file.

#### Code Execution
Aurora supports on-device code execution. By default, this feature is disabled for safety reasons, but you can enable it through the config file by setting `"allow-code-execution": true`.

> [!WARNING]
> Enabling Code Execution may carry risks even with guardrails in place. **Always** double-check the displayed code before clicking the "Execute Code" button.

> [!NOTE]
> Ensure your selected model supports free-tier requests and check your daily quota limits on Google AI Studio if you experience rate limiting.

More features coming soon!
