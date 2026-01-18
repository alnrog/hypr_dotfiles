#!/usr/bin/env bash
set -euo pipefail

# Initialize swww daemon and restore last wallpaper

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/default.jpg"
SDDM_WALLPAPER="$HOME/.local/share/sddm/wallpaper.jpg"

# Kill existing swww daemon if running
pkill -x swww-daemon 2>/dev/null || true
sleep 0.5

# Start swww daemon
swww-daemon &
sleep 1

# Try to restore last wallpaper
if [ -f "$CACHE_FILE" ]; then
    LAST_WALLPAPER=$(cat "$CACHE_FILE")
    
    if [ -f "$LAST_WALLPAPER" ]; then
        # Restore last wallpaper
        swww img "$LAST_WALLPAPER" \
            --transition-type fade \
            --transition-duration 1
        
        # Copy for SDDM
        mkdir -p "$(dirname "$SDDM_WALLPAPER")"
        cp "$LAST_WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null || true
        chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true
        
        exit 0
    fi
fi

# Fallback: try default wallpaper
if [ -f "$DEFAULT_WALLPAPER" ]; then
    swww img "$DEFAULT_WALLPAPER" \
        --transition-type fade \
        --transition-duration 1
    
    echo "$DEFAULT_WALLPAPER" > "$CACHE_FILE"
    mkdir -p "$(dirname "$SDDM_WALLPAPER")"
    cp "$DEFAULT_WALLPAPER" "$SDDM_WALLPAPER" 2>/dev/null || true
    chmod 644 "$SDDM_WALLPAPER" 2>/dev/null || true
else
    # No wallpaper found - use solid color
    swww img <(convert -size 1920x1080 xc:"#1e1e2e" png:-) \
        --transition-type fade \
        --transition-duration 1
fi
