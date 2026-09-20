#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/geminiapikey.sh" ]; then
    source "$SCRIPT_DIR/geminiapikey.sh"
fi
if [ -z "$GEMINI_API_KEY" ]; then
    notify-send -u critical "API Error" "GEMINI_API_KEY is not set."
    exit 1
fi

GEMINI_MODEL="gemini-3.6-flash"

ROFI_THEME='window {width: 20%; location: North;}'

if command -v rofi &>/dev/null; then
    if [[ "$XDG_CURRENT_DESKTOP" == "GNOME" ]]; then
        search=$(rofi -x11 -normal-window -dmenu -p "Ask Aurora:" -theme-str "$ROFI_THEME")
    else
        search=$(rofi -normal-window -dmenu -p "Ask Aurora:" -theme-str "$ROFI_THEME")
    fi
elif command -v wofi &>/dev/null; then
    search=$(wofi --dmenu --prompt "Ask Aurora:")
else
    notify-send "Aurora Error" "No supported launcher (rofi/wofi) found."
    exit 1
fi

[ -z "$search" ] && exit 0

trimmed_search="${search//[[:space:]]/}"
if [ -z "$trimmed_search" ]; then
    notify-send "Aurora" "Please say something e_e"
    exit 0
fi

MEMORY_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/Aurora-Assistant"
MEMORY_FILE="$MEMORY_DIR/memory.json"
LOCK_FILE="$MEMORY_DIR/compact.lock"
mkdir -p "$MEMORY_DIR"

if [ ! -f "$MEMORY_FILE" ]; then
    echo "[]" > "$MEMORY_FILE"
fi

if [ -n "$trimmed_search" ]; then
    SYSTEM_INS="$(cat "${SCRIPT_DIR}/sysprompt.txt")"

    api_payload=$(jq -n \
        --arg sys "$SYSTEM_INS" \
        --arg usr "$search" \
        --slurpfile history "$MEMORY_FILE" \
        '{
            systemInstruction: { parts: [{ text: $sys }] },
            contents: (
                ($history[0] // []) | map(
                    { role: "user", parts: [{ text: (.User // "Hello") }] },
		    { role: "model", parts: [{ text: (.Aurora // .AI // "Greetings.") }] }
                ) + [ { role: "user", parts: [{ text: $usr }] } ]
            )
        }')

    response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:generateContent?key=$GEMINI_API_KEY" \
        -H 'Content-Type: application/json' \
        -d "$api_payload")

    api_error=$(echo "$response" | jq -r '.error.message // empty')

    if [ -n "$api_error" ]; then
        notify-send -u critical "API Error" "$api_error"
        exit 1
    fi

    result=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // "No response generated."')

    clean_result=$(printf '%s' "$result" | sed -E \
        -e 's/<[^>]*>//g' \
        -e 's/&lt;/</g' \
        -e 's/&gt;/>/g' \
        -e 's/&amp;/&/g' \
        -e 's/&quot;/"/g' \
        -e "s/&apos;/'/g")

    jq --arg user "$search" --arg ai "$clean_result" \
        '. += [{"User": $user, "AI": $ai}]' "$MEMORY_FILE" > "${MEMORY_FILE}.tmp" && mv "${MEMORY_FILE}.tmp" "$MEMORY_FILE"

    entry_count=$(jq 'length' "$MEMORY_FILE")
    
    find "$MEMORY_DIR" -name "compact.lock" -mmin +5 -delete 2>/dev/null

    if [ "$entry_count" -ge 10 ] && [ ! -f "$LOCK_FILE" ]; then
        (
            touch "$LOCK_FILE"

            summary_payload=$(jq -n \
                --slurpfile history "$MEMORY_FILE" \
                '{
                    systemInstruction: { parts: [{ text: "You are a factual conversation summarizer. Distill user preferences, topics, and facts into concise bullet points. Retain specifics, omit pleasantries." }] },
                    contents: (
                        ($history[0][:-1] // []) | map(
                            { role: "user", parts: [{ text: (.User // "Hello") }] },
                            { role: "model", parts: [{ text: (.AI // "Understood.") }] }
                        ) + [ { role: "user", parts: [{ text: "Summarize our entire prior conversation above into a concise factual summary." }] } ]
                    )
                }')

            summary_res=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:generateContent?key=$GEMINI_API_KEY" \
                -H 'Content-Type: application/json' \
                -d "$summary_payload")

            summary_text=$(echo "$summary_res" | jq -r '.candidates[0].content.parts[0].text // empty')

            if [ -n "$summary_text" ]; then
                jq --arg summary "$summary_text" \
                    '[{"User": "[Prior conversation context]", "AI": $summary}] + .[-1:]' \
                    "$MEMORY_FILE" > "${MEMORY_FILE}.tmp" && mv "${MEMORY_FILE}.tmp" "$MEMORY_FILE"
            fi

            rm -f "$LOCK_FILE"
        ) &
    fi

    action=$(notify-send "Aurora" "$result" --action="copy=Copy")

    if [ "$action" = "copy" ]; then
        clipboard_text=$(printf 'Question : %s\nAurora : %s' "$search" "$clean_result")
        if command -v wl-copy &>/dev/null && [ "$XDG_SESSION_TYPE" = "wayland" ]; then
            printf '%s' "$clipboard_text" | wl-copy
        elif command -v xclip &>/dev/null; then
            printf '%s' "$clipboard_text" | xclip -selection clipboard
        fi
    fi

else
    notify-send "Aurora" "Please say something e_e"
fi
