#!/usr/bin/env bash

# Event-driven workspace renamer
# Обновляется только при изменениях (эффективнее чем polling)

# Маппинг class -> icon
get_icon() {
  case "$1" in
    kitty) echo "" ;;
    alacritty|Alacritty) echo "" ;;
    firefox) echo "" ;;
    code|code-url-handler) echo "󰨞" ;;
    Creality|CrealityPrint) echo "󰆧" ;;
    org.telegram.desktop) echo "" ;;
    discord) echo "" ;;
    obsidian) echo "󱓧" ;;
    pavucontrol|org\.pulseaudio\.pavucontrol) echo "󰕾" ;;
    blueman-manager) echo "󰂯" ;;
    thunar|Thunar) echo "" ;;
    org.kde.dolphin) echo "" ;;
    vlc|VLC) echo "󰕧" ;;
    spotify) echo "" ;;
    steam) echo "" ;;
    gimp) echo "" ;;
    gedit|org\.gnome\.gedit) echo "" ;;
    pycharm|jetbrains-pycharm-ce|PyCharm) echo "󰗔" ;;
    lm-studio|lmstudio|LM\ Studio) echo "󰳆" ;;
    libreoffice-writer|Writer) echo "" ;;
    libreoffice-calc|Calc) echo "" ;;
    libreoffice-impress|Impress) echo "" ;;
    libreoffice-draw|Draw) echo "" ;;
    libreoffice-base|Base) echo "" ;;
    libreoffice-math|Math) echo "" ;;
    libreoffice-startcenter|LibreOffice) echo "" ;;
    VirtualBox|VirtualBox\ Manager) echo "" ;;
    VirtualBox|VirtualBox\ Machine) echo "" ;;
    *) echo "" ;;
  esac
}

# Хеш последнего состояния для избежания лишних обновлений
LAST_STATE=""

# Функция для обновления workspace имён
update_workspaces() {
  # Получаем список клиентов
  local clients=$(hyprctl clients -j 2>/dev/null)
  
  # Проверка валидности JSON
  if ! echo "$clients" | jq empty 2>/dev/null; then
    return
  fi
  
  # Создаём хеш текущего состояния
  local current_state=$(echo "$clients" | md5sum | cut -d' ' -f1)
  
  # Если состояние не изменилось - пропускаем обновление
  if [[ "$current_state" == "$LAST_STATE" ]]; then
    return
  fi
  
  LAST_STATE="$current_state"
  
  # Инициализация массивов
  declare -A ws_icons
  declare -A ws_has_windows

  # Обработка каждого окна
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    
    local ws=$(echo "$line" | cut -d':' -f1)
    local class=$(echo "$line" | cut -d':' -f2-)
    
    if [[ -n "$ws" && -n "$class" ]]; then
      local icon=$(get_icon "$class")
      if [[ -z "${ws_icons[$ws]}" ]]; then
        ws_icons[$ws]="$icon"
      else
        ws_icons[$ws]+=" $icon"
      fi
      ws_has_windows[$ws]=1
    fi
  done < <(echo "$clients" | jq -r '.[] | select(.mapped == true and .class and (.class | type == "string")) | "\(.workspace.id):\(.class)"' 2>/dev/null)
  
  # Обновляем имена всех workspaces (1-9)
  for ws in {1..9}; do
    local name
    if [[ -n "${ws_has_windows[$ws]}" ]]; then
      # Есть окна - показываем иконки
      name="${ws_icons[$ws]}"
    else
      # Нет окон - показываем номер
      name="$ws"
    fi
    
    # Переименовываем workspace
    hyprctl dispatch renameworkspace "$ws" "$name" >/dev/null 2>&1
  done
}

# Первичное обновление
update_workspaces

# Функция для обработки событий Hyprland
handle_events() {
  while true; do
    if [[ -S "/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" ]]; then
      socat -U - "UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null | while read -r line; do
        case "$line" in
          openwindow*|closewindow*|movewindow*|workspace*|changefloatingmode*)
            update_workspaces
            ;;
        esac
      done
    fi
    # Если соединение разорвалось - переподключаемся
    sleep 1
  done
}

# Запускаем event listener в фоне
handle_events &
EVENT_PID=$!

# Fallback polling каждые 2 секунды
while true; do
  sleep 2
  update_workspaces
done

# Cleanup при выходе
trap "kill $EVENT_PID 2>/dev/null; exit" SIGTERM SIGINT EXIT
