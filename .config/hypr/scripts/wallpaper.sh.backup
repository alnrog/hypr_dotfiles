#!/usr/bin/env bash
set -euo pipefail

source ~/.config/hypr/scripts/locale.sh

# Wallpaper switcher для swww с сохранением для SDDM

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
SDDM_DIR="$HOME/.local/share/sddm"
SDDM_WALLPAPER="$SDDM_DIR/wallpaper.jpg"

# Transition effects
TRANSITION_TYPE="fade"
TRANSITION_DURATION=2

# Create directories
mkdir -p "$WALLPAPER_DIR"
mkdir -p "$(dirname "$CACHE_FILE")"
mkdir -p "$SDDM_DIR"

# Get list of wallpapers
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort)

if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "$(t "wallpaper")" "$(t "no_wallpapers") $WALLPAPER_DIR" --urgency=critical
    exit 1
fi

# Get current wallpaper index
get_current_index() {
    if [ -f "$CACHE_FILE" ]; then
        current=$(cat "$CACHE_FILE")
        for i in "${!WALLPAPERS[@]}"; do
            if [ "${WALLPAPERS[$i]}" = "$current" ]; then
                echo "$i"
                return
            fi
        done
    fi
    echo "0"
}

# Set wallpaper
set_wallpaper() {
    local wallpaper="$1"
    
    # Set wallpaper with swww
    swww img "$wallpaper" \
        --transition-type "$TRANSITION_TYPE" \
        --transition-duration "$TRANSITION_DURATION"
    
    # Save current wallpaper path
    echo "$wallpaper" > "$CACHE_FILE"
    
    # Copy for SDDM (просто cp, без sudo!)
    cp "$wallpaper" "$SDDM_WALLPAPER" 2>/dev/null || true
    chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true
    
    local filename=$(basename "$wallpaper")
    notify-send "$(t "wallpaper_changed")" "$filename" \
        --icon="$wallpaper" \
        --urgency=low \
        --expire-time=2000
}

case "${1:-random}" in
    random)
        random_index=$((RANDOM % ${#WALLPAPERS[@]}))
        set_wallpaper "${WALLPAPERS[$random_index]}"
        ;;
    
    next)
        current_index=$(get_current_index)
        next_index=$(( (current_index + 1) % ${#WALLPAPERS[@]} ))
        set_wallpaper "${WALLPAPERS[$next_index]}"
        ;;
    
    prev)
        current_index=$(get_current_index)
        prev_index=$(( (current_index - 1 + ${#WALLPAPERS[@]}) % ${#WALLPAPERS[@]} ))
        set_wallpaper "${WALLPAPERS[$prev_index]}"
        ;;
    
    *)
        if [ -f "$1" ]; then
            set_wallpaper "$1"
        else
            echo "File not found: $1"
            exit 1
        fi
        ;;
esac
