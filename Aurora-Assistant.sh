#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/geminiapikey.sh" ]; then
    source "$SCRIPT_DIR/geminiapikey.sh"
fi
if [ -z "$GEMINI_API_KEY" ]; then
    notify-send -u critical "Aurora API Error" "GEMINI_API_KEY is not set."
    exit 1
fi

if [ -f "$SCRIPT_DIR/Aurora.conf" ]; then
	ALLOW_CODE_EXEC=$(jq -r '.["allow-code-execution"]' "$SCRIPT_DIR/Aurora.conf")
	GEMINI_MODEL=$(jq -r '."gemini-model"' "$SCRIPT_DIR/Aurora.conf")
else
	cat <<- 'EOF' > "$SCRIPT_DIR/Aurora.conf"
	{
		"allow-code-execution": false,
		"gemini-model": "gemini-3.6-flash"
	}
	EOF
	
	notify-send "Aurora Config not set" "$(printf "Created Config \n%s" "$(jq -r 'to_entries | map("\(.key) set to \(.value)") | join("\n")' "$SCRIPT_DIR/Aurora.conf")")\n Config path : $SCRIPT_DIR/Aurora.conf"
fi

MEMORY_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/Aurora-Assistant"
MEMORY_FILE="$MEMORY_DIR/memory.json"
LOCK_FILE="$MEMORY_DIR/compact.lock"
mkdir -p "$MEMORY_DIR"

if [ ! -f "$MEMORY_FILE" ]; then
    echo "[]" > "$MEMORY_FILE"
    raw_name=$(getent passwd "$USER" 2>/dev/null | cut -d ':' -f 5 | cut -d ',' -f 1 | awk '{print $1}')
    user_display_name="${raw_name:-$USER}"
    user_display_name="${user_display_name^}"
    notify-send "Aurora" "Greetings ${user_display_name}! (✿◠‿◠) I'm Aurora, your desktop companion. Nice to meet you!"
fi

ROFI_THEME='window {width: 20%; location: center;}'

if command -v rofi &>/dev/null; then
    if [[ "$XDG_CURRENT_DESKTOP" == "GNOME" ]]; then
        search=$(rofi -x11 -normal-window -dmenu -p "Ask Aurora:" -theme-str "$ROFI_THEME")
    else
        search=$(rofi -normal-window -dmenu -p "Ask Aurora:" -theme-str "$ROFI_THEME")
    fi
elif command -v wofi &>/dev/null; then
    search=$(wofi --dmenu --prompt "Ask Aurora:")
else
    notify-send "Aurora UI Error" "No supported launcher (rofi/wofi) found."
    exit 1
fi

[ -z "$search" ] && exit 0

trimmed_search="${search//[[:space:]]/}"
if [ -z "$trimmed_search" ]; then
    notify-send "Aurora" "Please say something e_e"
    exit 0
fi

if [ -n "$trimmed_search" ]; then
    SYSTEM_INS="$(cat "${SCRIPT_DIR}/sysprompt.txt")"

    api_payload=$(jq -n \
        --arg sys "$SYSTEM_INS" \
        --arg usr "$search" \
        --slurpfile history "$MEMORY_FILE" \
        '{
            systemInstruction: { parts: [{ text: $sys }] },
            tools: [{ googleSearch: {} }],
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
        notify-send -u critical "Aurora API Error" "$api_error"
        exit 1
    fi

    result=$(echo "$response" | jq -r ' [.candidates[0].content.parts[]?.text // empty] | if length > 0 then join("") else "No response generated." end')

    jq --arg user "$search" --arg ai "$result" \
        '. += [{"User": $user, "AI": $ai}]' "$MEMORY_FILE" > "${MEMORY_FILE}.tmp" && mv "${MEMORY_FILE}.tmp" "$MEMORY_FILE"

    entry_count=$(jq 'length' "$MEMORY_FILE")
    
    find "$MEMORY_DIR" -name "compact.lock" -mmin +5 -delete 2>/dev/null

    if [ "$entry_count" -ge 10 ] && [ ! -f "$LOCK_FILE" ]; then
        (
            touch "$LOCK_FILE"


	    SYSTEM_PROMPT='You are an internal memory updater for a personalized assistant. Your job is to extract long-term user context from the conversation to maintain an evolving profile of the user.
		What to capture:
		- User Profile: Habits, preferences, constraints, technical skill level, interaction style, and personality traits.
		- Personal Entities & Projects: The users ongoing projects, tools/tech stacks they use, specific devices, and named people , calendar date and time or places relevant to their life.
		- Explicit Directives: Standing instructions the user has given for future conversations (e.g., "always format code in TypeScript", "keep answers under 3 sentences").

		Strict Exclusions:
		- General World Knowledge: Do NOT record publicly known facts, trivia, dates, math truths, or encyclopedic definitions (e.g., release dates, unit conversions, historical facts), even if discussed.
		- Formatting: Do NOT use HTML, XML, or Pango markup tags (such as <span>, <b>, or <code>) in the summary. Produce plain text bullet points only.
		- Assistant Content: Never summarize explanations or answers provided by the assistant; only extract details revealed by or about the user.
		- Ephemeral Chatter: Omit pleasantries, one-off lookups, temporary troubleshooting, and transactional exchanges.

		Aging & Cleanup:
		- Retain only ongoing or active context. Gradually omit stale projects, solved one-off problems, or topics not referenced over time.'

		summary_payload=$(jq -n \
		  --slurpfile history "$MEMORY_FILE" \
		  --arg prompt "$SYSTEM_PROMPT" \
		  '{
		    systemInstruction: { parts: [{ text: $prompt }] },
		    contents: (
		      (($history[0][:-1] // []) | map(
			{ role: "user", parts: [{ text: (.User // "Hello") }] },
			{ role: "model", parts: [{ text: (.AI // "Understood.") }] }
		      )) + [ { role: "user", parts: [{ text: "Summarize our entire prior conversation above into a concise factual summary." }] } ]
		    )
		  }')

            summary_res=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:generateContent?key=$GEMINI_API_KEY" \
                -H 'Content-Type: application/json' \
                -d "$summary_payload")

	    summary_text=$(echo "$summary_res" | jq -r '  [.candidates[0].content.parts[]?.text // empty] | join("")')
            
            if [ -n "$summary_text" ]; then
                jq --arg summary "$summary_text" \
                    '[{"User": "[Prior conversation context]", "AI": $summary}] + .[-1:]' \
                    "$MEMORY_FILE" > "${MEMORY_FILE}.tmp" && mv "${MEMORY_FILE}.tmp" "$MEMORY_FILE"
            fi

            rm -f "$LOCK_FILE"
        ) &
    fi

    if [[ "$result" =~ \<tt\>(.*)\<\/tt\> ]] || [[ "$result" =~ \<code\>(.*)\<\/code\> ]]; then
        raw_cmd="${BASH_REMATCH[1]}"
        clean_cmd=$(printf '%s' "$raw_cmd" | sed -E \
            -e 's/&lt;/</g' \
            -e 's/&gt;/>/g' \
            -e 's/&amp;/&/g' \
            -e 's/&quot;/"/g' \
            -e "s/&apos;/'/g")
    else
        clean_cmd=""
    fi
    
	clean_result=$(printf '%s' "$result" | sed -E \
	    -e 's/<[^>]*>//g' \
	    -e 's/&lt;/</g' \
	    -e 's/&gt;/>/g' \
	    -e 's/&amp;/&/g' \
	    -e 's/&quot;/"/g' \
	    -e "s/&apos;/'/g")

	
	copy_to_clipboard() {
	    local name="$1"
	    local output="$2"
	    local namestring="$3"
	    local outputstring="$4"
	    local clipboard_text
	    clipboard_text=$(printf '%s : %s\n%s : %s' "$name" "$namestring" "$output" "$outputstring")
	    if command -v wl-copy &>/dev/null && [ "$XDG_SESSION_TYPE" = "wayland" ]; then
		printf '%s' "$clipboard_text" | wl-copy
	    elif command -v xclip &>/dev/null; then
		printf '%s' "$clipboard_text" | xclip -selection clipboard
	    fi
	}

	display_result=$(printf '%s' "$result" | perl -pe 's/&(?!([a-zA-Z]+|#\d+|#x[0-9a-fA-F]+);)/&amp;/g')

	notify_args=("Aurora" "$display_result" "--action=copy=Copy")
	if [[ -n "$clean_cmd" && "$ALLOW_CODE_EXEC" == "true" ]]; then
	    notify_args+=("--action=test=Execute Code")
	fi

	action=$(notify-send "${notify_args[@]}")

	if [ "$action" = "copy" ]; then
	    copy_to_clipboard "Question" "Aurora" "$search" "$clean_result"
	elif [ "$action" = "test" ] && [[ -n "$clean_cmd" && "$ALLOW_CODE_EXEC" == "true" ]]; then
	    notify-send "Executing code" "$clean_cmd"        
	    output=$(bash -c "$clean_cmd" 2>&1)
	 	
	    exec_action=$(notify-send "Code executed" "${output:-[Execution completed with no output]}" "--action=copy=Copy")
	    if [ "$exec_action" = "copy" ]; then
		copy_to_clipboard "Code" "Output" "$clean_cmd" "$output"
	    fi
	    
	fi
    
    notify-send "Aurora" "$display_result"
    
else
    notify-send "Aurora" "Please say something e_e"
fi
