#!/usr/bin/env bash
set -euo pipefail

source ~/.config/hypr/scripts/locale.sh

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
TEMP_DIR="$HOME/.cache/wallpaper_temp"
SDDM_DIR="$HOME/.local/share/sddm"
SDDM_WALLPAPER="$SDDM_DIR/wallpaper.jpg"

TRANSITION_TYPE="fade"
TRANSITION_DURATION=2

mkdir -p "$WALLPAPER_DIR" "$TEMP_DIR" "$(dirname "$CACHE_FILE")" "$SDDM_DIR"

get_monitors() {
    mapfile -t MONITORS < <(hyprctl monitors | awk '/^Monitor / {print $2}')
    if [ ${#MONITORS[@]} -eq 0 ]; then
        echo "Не удалось получить список мониторов" >&2
        exit 1
    fi
}

get_image_resolution() {
    local image="$1"

    if command -v identify &>/dev/null; then
        local resolution
        resolution=$(identify -format "%wx%h" "$image" 2>/dev/null || true)
        if [ -n "${resolution:-}" ]; then
            IMAGE_WIDTH=$(echo "$resolution" | cut -d'x' -f1)
            IMAGE_HEIGHT=$(echo "$resolution" | cut -d'x' -f2)
            return 0
        fi
    fi

    if command -v file &>/dev/null; then
        local file_info
        file_info=$(file "$image")
        if [[ "$file_info" =~ ([0-9]+)[[:space:]]*x[[:space:]]*([0-9]+) ]]; then
            IMAGE_WIDTH="${BASH_REMATCH[1]}"
            IMAGE_HEIGHT="${BASH_REMATCH[2]}"
            return 0
        fi
    fi

    IMAGE_WIDTH=1920
    IMAGE_HEIGHT=1080
    return 1
}

is_ultra_wide() {
    local image="$1"
    get_image_resolution "$image"

    local aspect_ratio
    aspect_ratio=$(awk "BEGIN {printf \"%.2f\", $IMAGE_WIDTH / $IMAGE_HEIGHT}")

    if (( $(awk "BEGIN {print ($aspect_ratio >= 3.0)}") )); then
        return 0
    fi

    if [ "$IMAGE_WIDTH" -ge 4700 ] && [ "$IMAGE_WIDTH" -le 5500 ]; then
        return 0
    fi

    return 1
}

set_wallpaper() {
    local wallpaper="$1"

    get_monitors

    echo "$wallpaper" > "$CACHE_FILE"
    cp "$wallpaper" "$SDDM_WALLPAPER" 2>/dev/null || true
    chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true

    if [ ${#MONITORS[@]} -eq 1 ]; then
        swww img "$wallpaper" \
            --outputs "${MONITORS[0]}" \
            --transition-type "$TRANSITION_TYPE" \
            --transition-duration "$TRANSITION_DURATION"
        STRATEGY="single monitor"
    elif is_ultra_wide "$wallpaper"; then
        if ! command -v convert &>/dev/null; then
            notify-send "Error" "ImageMagick required for ultra-wide wallpapers" --urgency=critical
            return 1
        fi

        local half_width=$((IMAGE_WIDTH / 2))
        local left_temp="$TEMP_DIR/left.jpg"
        local right_temp="$TEMP_DIR/right.jpg"

        convert "$wallpaper" -crop "${half_width}x${IMAGE_HEIGHT}+0+0" "$left_temp" 2>/dev/null
        convert "$wallpaper" -crop "${half_width}x${IMAGE_HEIGHT}+${half_width}+0" "$right_temp" 2>/dev/null

        swww img "$left_temp" \
            --outputs "${MONITORS[0]}" \
            --transition-type "$TRANSITION_TYPE" \
            --transition-duration "$TRANSITION_DURATION" &

        swww img "$right_temp" \
            --outputs "${MONITORS[1]}" \
            --transition-type "$TRANSITION_TYPE" \
            --transition-duration "$TRANSITION_DURATION" &

        wait
        STRATEGY="stretched (split)"
    else
        if ! command -v convert &>/dev/null; then
            swww img "$wallpaper" \
                --transition-type "$TRANSITION_TYPE" \
                --transition-duration "$TRANSITION_DURATION"
            STRATEGY="duplicated"
        else
            local original_temp="$TEMP_DIR/original.jpg"
            local mirrored_temp="$TEMP_DIR/mirrored.jpg"

            cp "$wallpaper" "$original_temp"
            convert "$wallpaper" -flop "$mirrored_temp" 2>/dev/null

            swww img "$original_temp" \
                --outputs "${MONITORS[0]}" \
                --transition-type "$TRANSITION_TYPE" \
                --transition-duration "$TRANSITION_DURATION" &

            swww img "$mirrored_temp" \
                --outputs "${MONITORS[1]}" \
                --transition-type "$TRANSITION_TYPE" \
                --transition-duration "$TRANSITION_DURATION" &

            wait
            STRATEGY="mirrored (symmetric)"
        fi
    fi

    local filename
    filename=$(basename "$wallpaper")

    notify-send "$(t "wallpaper_changed")" "$filename\n${IMAGE_WIDTH}x${IMAGE_HEIGHT} → $STRATEGY" \
        --icon="$wallpaper" \
        --urgency=low \
        --expire-time=3000
}

mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort)

if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "$(t "wallpaper")" "$(t "no_wallpapers") $WALLPAPER_DIR" --urgency=critical
    exit 1
fi

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

case "${1:-random}" in
    random)
        set_wallpaper "${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"
        ;;
    next)
        current_index=$(get_current_index)
        set_wallpaper "${WALLPAPERS[$(((current_index + 1) % ${#WALLPAPERS[@]}))]}"
        ;;
    prev)
        current_index=$(get_current_index)
        set_wallpaper "${WALLPAPERS[$(((current_index - 1 + ${#WALLPAPERS[@]}) % ${#WALLPAPERS[@]}))]}"
        ;;
    *)
        if [ -f "$1" ]; then
            set_wallpaper "$1"
        else
            echo "Usage: $0 [random|next|prev|/path/to/wallpaper.jpg]"
            exit 1
        fi
        ;;
esac
