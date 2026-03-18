#!/bin/bash

# --- 1. ПРОВЕРКА И УСТАНОВКА YAY ---
if ! command -v yay &> /dev/null; then
    read -p "yay не найден. Хочешь установить? (y/n): " install_yay
    if [[ "$install_yay" =~ ^[Yy]$ ]]; then
        echo "Установка yay..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay || exit
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    else
        echo "Пропуск установки пакетов (yay не найден)."
    fi
fi

# --- 2. УСТАНОВКА ПАКЕТОВ ---
if [ -f "packages.txt" ] && command -v yay &> /dev/null; then
    read -p "Установить пакеты из packages.txt? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Установка пакетов..."
        yay -S --noconfirm --needed - < packages.txt
    fi
fi

# --- 3. НАСТРОЙКА БЭКАПА ---
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

backup_and_remove() {
    local target_path="$1"
    # Проверяем, существует ли файл/папка или даже битая симссылка
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        # Создаем папку бэкапа только если нашли что бэкапить
        [ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"
        
        echo "Бэкап: $target_path"
        local relative_path=$(echo "$target_path" | sed "s|$HOME/||")
        mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
        mv "$target_path" "$BACKUP_DIR/$relative_path"
    fi
}

echo "--- Подготовка системы (удаление старых конфигов и бэкап) ---"

# --- 4. ОБРАБОТКА ~/.config ---
if [ -d "config" ]; then
    for item in config/*; do
        [ -e "$item" ] || continue
        backup_and_remove "$HOME/.config/$(basename "$item")"
    done
fi

# --- 5. ОБРАБОТКА ~/.local (ИСПРАВЛЕНО) ---
# Мы ищем только те папки/файлы, которые ЕСТЬ в твоем Dotfiles/local
if [ -d "local" ]; then
    # Проходим по всем объектам внутри local/ (например: bin, share)
    find local -mindepth 1 -maxdepth 2 | while read -r src_item; do
        # Превращаем путь "local/share/themes" в "/home/user/.local/share/themes"
        target_path=$(echo "$src_item" | sed "s|^local|$HOME/.local|")
        
        # Бэкапим только если этот конкретный путь существует в системе
        backup_and_remove "$target_path"
    done
fi

# --- 6. ОБРАБОТКА ДОМАШНЕЙ ПАПКИ (bash) ---
if [ -d "bash" ]; then
    find bash -maxdepth 1 -type f -name ".*" | while read -r f; do
        backup_and_remove "$HOME/$(basename "$f")"
    done
fi

# --- 7. ЗАПУСК STOW ---
echo "--- Установка ссылок через stow ---"
stow -v -t ~/.config/ config/
stow -v -t ~/.local/ local/
stow -v -t ~ bash/

if [ -d "$BACKUP_DIR" ]; then
    echo -e "\nГотово! Бэкапы старых файлов тут: $BACKUP_DIR"
else
    echo -e "\nГотово! Конфликтов не найдено, бэкап не потребовался."
fi
