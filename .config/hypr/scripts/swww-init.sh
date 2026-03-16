#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
TEMP_DIR="$HOME/.cache/wallpaper_temp"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/default.jpg"
SDDM_WALLPAPER="$HOME/.local/share/sddm/wallpaper.jpg"

get_monitors() {
    mapfile -t MONITORS < <(hyprctl monitors | awk '/^Monitor / {print $2}')
    if [ ${#MONITORS[@]} -eq 0 ]; then
        echo "Не удалось получить список мониторов" >&2
        exit 1
    fi
}

pkill -x swww-daemon 2>/dev/null || true
sleep 0.5
swww-daemon &
sleep 1

max_attempts=10
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if swww query &>/dev/null; then
        break
    fi
    sleep 0.5
    ((attempt++))
done

is_ultra_wide() {
    local image="$1"
    if command -v identify &>/dev/null; then
        local resolution
        resolution=$(identify -format "%wx%h" "$image" 2>/dev/null || true)
        if [ -n "${resolution:-}" ]; then
            local width height aspect
            width=$(echo "$resolution" | cut -d'x' -f1)
            height=$(echo "$resolution" | cut -d'x' -f2)
            aspect=$(awk "BEGIN {printf \"%.2f\", $width / $height}")
            if (( $(awk "BEGIN {print ($aspect >= 3.0)}") )) || [ "$width" -ge 4700 ]; then
                return 0
            fi
        fi
    fi
    return 1
}

set_wallpaper() {
    local wallpaper="$1"
    get_monitors

    if [ ${#MONITORS[@]} -eq 1 ]; then
        swww img "$wallpaper" --outputs "${MONITORS[0]}" --transition-type fade --transition-duration 1
        return
    fi

    if is_ultra_wide "$wallpaper" && command -v convert &>/dev/null; then
        local resolution width height half_width
        resolution=$(identify -format "%wx%h" "$wallpaper" 2>/dev/null)
        width=$(echo "$resolution" | cut -d'x' -f1)
        height=$(echo "$resolution" | cut -d'x' -f2)
        half_width=$((width / 2))

        mkdir -p "$TEMP_DIR"
        local left_temp="$TEMP_DIR/left.jpg"
        local right_temp="$TEMP_DIR/right.jpg"

        convert "$wallpaper" -crop "${half_width}x${height}+0+0" "$left_temp" 2>/dev/null
        convert "$wallpaper" -crop "${half_width}x${height}+${half_width}+0" "$right_temp" 2>/dev/null

        swww img "$left_temp" --outputs "${MONITORS[0]}" --transition-type fade --transition-duration 1 &
        swww img "$right_temp" --outputs "${MONITORS[1]}" --transition-type fade --transition-duration 1 &
        wait
    elif command -v convert &>/dev/null && [ ${#MONITORS[@]} -ge 2 ]; then
        mkdir -p "$TEMP_DIR"
        local original_temp="$TEMP_DIR/original.jpg"
        local mirrored_temp="$TEMP_DIR/mirrored.jpg"

        cp "$wallpaper" "$original_temp"
        convert "$wallpaper" -flop "$mirrored_temp" 2>/dev/null

        swww img "$original_temp" --outputs "${MONITORS[0]}" --transition-type fade --transition-duration 1 &
        swww img "$mirrored_temp" --outputs "${MONITORS[1]}" --transition-type fade --transition-duration 1 &
        wait
    else
        swww img "$wallpaper" --transition-type fade --transition-duration 1
    fi
}

if [ -f "$CACHE_FILE" ]; then
    LAST_WALLPAPER=$(cat "$CACHE_FILE")
    if [ -f "$LAST_WALLPAPER" ]; then
        set_wallpaper "$LAST_WALLPAPER"
        mkdir -p "$(dirname "$SDDM_WALLPAPER")"
        cp "$LAST_WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null || true
        chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true
        exit 0
    fi
fi

if [ -f "$DEFAULT_WALLPAPER" ]; then
    set_wallpaper "$DEFAULT_WALLPAPER"
    echo "$DEFAULT_WALLPAPER" > "$CACHE_FILE"
    mkdir -p "$(dirname "$SDDM_WALLPAPER")"
    cp "$DEFAULT_WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null || true
    chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true
else
    swww clear 1e1e2e
fi
