#!/usr/bin/env bash
set -euo pipefail

# Initialize swww daemon and restore last wallpaper
# Supports split ultra-wide and mirrored standard wallpapers

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
TEMP_DIR="$HOME/.cache/wallpaper_temp"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/default.jpg"
SDDM_WALLPAPER="$HOME/.local/share/sddm/wallpaper.jpg"

# Kill existing swww daemon
pkill -x swww-daemon 2>/dev/null || true
sleep 0.5

# Start swww daemon
swww-daemon &
sleep 1

# Wait for swww to be ready
max_attempts=10
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if swww query &>/dev/null; then
        break
    fi
    sleep 0.5
    ((attempt++))
done

# Helper: check if ultra-wide
is_ultra_wide() {
    local image="$1"
    
    if command -v identify &>/dev/null; then
        local resolution=$(identify -format "%wx%h" "$image" 2>/dev/null)
        if [ -n "$resolution" ]; then
            local width=$(echo "$resolution" | cut -d'x' -f1)
            local height=$(echo "$resolution" | cut -d'x' -f2)
            local aspect=$(awk "BEGIN {printf \"%.2f\", $width / $height}")
            
            if (( $(awk "BEGIN {print ($aspect >= 3.0)}") )) || [ "$width" -ge 4700 ]; then
                return 0
            fi
        fi
    fi
    return 1
}

# Helper: set wallpaper
set_wallpaper() {
    local wallpaper="$1"
    
    if is_ultra_wide "$wallpaper" && command -v convert &>/dev/null; then
        # Ultra-wide: split and set
        local resolution=$(identify -format "%wx%h" "$wallpaper" 2>/dev/null)
        local width=$(echo "$resolution" | cut -d'x' -f1)
        local height=$(echo "$resolution" | cut -d'x' -f2)
        local half_width=$((width / 2))
        
        mkdir -p "$TEMP_DIR"
        local left_temp="$TEMP_DIR/left.jpg"
        local right_temp="$TEMP_DIR/right.jpg"
        
        convert "$wallpaper" -crop "${half_width}x${height}+0+0" "$left_temp" 2>/dev/null
        convert "$wallpaper" -crop "${half_width}x${height}+${half_width}+0" "$right_temp" 2>/dev/null
        
        swww img "$left_temp" --outputs DP-1 --transition-type fade --transition-duration 1 &
        swww img "$right_temp" --outputs DP-2 --transition-type fade --transition-duration 1 &
        wait
    elif command -v convert &>/dev/null; then
        # Standard: original + mirrored
        mkdir -p "$TEMP_DIR"
        local original_temp="$TEMP_DIR/original.jpg"
        local mirrored_temp="$TEMP_DIR/mirrored.jpg"
        
        cp "$wallpaper" "$original_temp"
        convert "$wallpaper" -flop "$mirrored_temp" 2>/dev/null
        
        swww img "$original_temp" --outputs DP-1 --transition-type fade --transition-duration 1 &
        swww img "$mirrored_temp" --outputs DP-2 --transition-type fade --transition-duration 1 &
        wait
    else
        # Fallback: just duplicate (no ImageMagick)
        swww img "$wallpaper" --transition-type fade --transition-duration 1
    fi
}

# Try to restore last wallpaper
if [ -f "$CACHE_FILE" ]; then
    LAST_WALLPAPER=$(cat "$CACHE_FILE")
    
    if [ -f "$LAST_WALLPAPER" ]; then
        set_wallpaper "$LAST_WALLPAPER"
        
        # Copy for SDDM
        mkdir -p "$(dirname "$SDDM_WALLPAPER")"
        cp "$LAST_WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null || true
        chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true
        
        exit 0
    fi
fi

# Fallback: try default wallpaper
if [ -f "$DEFAULT_WALLPAPER" ]; then
    set_wallpaper "$DEFAULT_WALLPAPER"
    echo "$DEFAULT_WALLPAPER" > "$CACHE_FILE"
    
    mkdir -p "$(dirname "$SDDM_WALLPAPER")"
    cp "$DEFAULT_WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null || true
    chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true
else
    # No wallpaper - solid color
    swww clear 1e1e2e
fi
