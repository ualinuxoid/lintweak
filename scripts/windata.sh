#!/bin/bash

set -euo pipefail

declare -A EN
declare -A UK

EN[title]="WINDOWS DATA RECOVERY & DISK WIPE TOOL"
UK[title]="ІНСТРУМЕНТ ВІДНОВЛЕННЯ ДАНИХ ТА ОЧИЩЕННЯ ДИСКА WINDOWS"

EN[lang_menu]="LANGUAGE SELECTION"
UK[lang_menu]="ВИБІР МОВИ"

EN[lang_option1]="1) ENGLISH"
UK[lang_option1]="1) ENGLISH"

EN[lang_option2]="2) УКРАЇНСЬКА"
UK[lang_option2]="2) УКРАЇНСЬКА"

EN[lang_ru_notice]="!!! RUSSIAN IS NOT AND WILL NOT BE SUPPORTED !!!\RUSSIA IS TERRORIST STATE!!!"
UK[lang_ru_notice]="!!! РОСІЙСЬКА МОВА НЕ ПІДТРИМУЄТЬСЯ І НЕ БУДЕ ПІДТРИМУВАТИСЬ !!!\nРОСІЯ - КРАЇНА ТЕРРОРИСТ!!!"

EN[donate]="Support Ukrainian Armed Forces:\n  - https://savelife.in.ua/en/donate/\n  - https://bank.gov.ua/en/about/support-the-armed-forces"
UK[donate]="Підтримайте Збройні Сили України:\n  - https://savelife.in.ua/donate/\n  - https://bank.gov.ua/ua/about/support-the-armed-forces"

EN[select_prompt]="Select [1-2]: "
UK[select_prompt]="Оберіть [1-2]: "

EN[root_required]="This script must be run as root (sudo)."
UK[root_required]="Цей скрипт необхідно запускати від root (sudo)."

EN[checking_deps]="Checking dependencies..."
UK[checking_deps]="Перевірка залежностей..."

EN[deps_ok]="All dependencies satisfied."
UK[deps_ok]="Всі залежності задоволені."

EN[deps_missing]="Missing packages detected. Install required packages?"
UK[deps_missing]="Виявлено відсутні пакети. Встановити необхідні пакети?"

EN[yes]="Yes"
UK[yes]="Так"

EN[no]="No"
UK[no]="Ні"

EN[installing]="Installing packages..."
UK[installing]="Встановлення пакетів..."

EN[main_menu]="MAIN MENU"
UK[main_menu]="ГОЛОВНЕ МЕНЮ"

EN[menu_copy]="1) Recover/Copy User Data"
UK[menu_copy]="1) Відновити/Копіювати дані користувача"

EN[menu_wipe]="2) Secure Wipe Windows Disk"
UK[menu_wipe]="2) Безпечно стерти диск Windows"

EN[menu_exit]="3) Exit"
UK[menu_exit]="3) Вихід"

EN[choose_action]="Choose action: "
UK[choose_action]="Оберіть дію: "

EN[partition_scan]="Scanning for Windows (NTFS) partitions..."
UK[partition_scan]="Пошук розділів Windows (NTFS)..."

EN[partitions_found]="Found NTFS partitions:"
UK[partitions_found]="Знайдено розділи NTFS:"

EN[no_partitions]="No NTFS partitions found. Please mount manually."
UK[no_partitions]="Розділи NTFS не знайдено. Будь ласка, змонтуйте вручну."

EN[enter_source]="Enter source path (e.g., /media/windows or /mnt/sda2): "
UK[enter_source]="Введіть шлях джерела (напр., /media/windows або /mnt/sda2): "

EN[enter_dest]="Enter destination path (e.g., /media/usb/backup): "
UK[enter_dest]="Введіть шлях призначення (напр., /media/usb/backup): "

EN[dest_confirm]="Destination will be: %s. Continue?"
UK[dest_confirm]="Призначення: %s. Продовжити?"

EN[custom_ext_prompt]="Do you want to add custom file extensions?"
UK[custom_ext_prompt]="Бажаєте додати власні розширення файлів?"

EN[custom_ext_input]="Enter extensions separated by comma, WITHOUT dots and spaces (e.g., pdf,txt,csv): "
UK[custom_ext_input]="Введіть розширення через кому, БЕЗ крапок і пробілів (напр., pdf,txt,csv): "

EN[convert_prompt]="Convert Microsoft formats (docx,xlsx,pptx) to OpenDocument (odt,ods,odp)?"
UK[convert_prompt]="Конвертувати формати Microsoft (docx,xlsx,pptx) у OpenDocument (odt,ods,odp)?"

EN[convert_no_libreoffice]="LibreOffice not found. Conversion will be skipped."
UK[convert_no_libreoffice]="LibreOffice не знайдено. Конвертацію буде пропущено."

EN[copy_start]="Starting data recovery..."
UK[copy_start]="Початок відновлення даних..."

EN[copy_progress]="Copied: %s files"
UK[copy_progress]="Скопійовано: %s файлів"

EN[copy_complete]="Data recovery complete!"
UK[copy_complete]="Відновлення даних завершено!"

EN[convert_start]="Starting conversion to open formats..."
UK[convert_start]="Початок конвертації у відкриті формати..."

EN[convert_complete]="Conversion complete!"
UK[convert_complete]="Конвертацію завершено!"

EN[wipe_title]="SECURE DISK WIPE"
UK[wipe_title]="БЕЗПЕЧНЕ СТИРАННЯ ДИСКА"

EN[wipe_warning]="WARNING: This will DESTROY ALL DATA on the selected disk!"
UK[wipe_warning]="УВАГА: Це ЗНИЩИТЬ ВСІ ДАНІ на обраному диску!"

EN[wipe_disks]="Available disks:"
UK[wipe_disks]="Доступні диски:"

EN[wipe_select]="Enter disk to wipe (e.g., /dev/sda): "
UK[wipe_select]="Введіть диск для стирання (напр., /dev/sda): "

EN[wipe_confirm1]="Are you ABSOLUTELY SURE? This cannot be undone!"
UK[wipe_confirm1]="Ви АБСОЛЮТНО ВПЕВНЕНІ? Це неможливо скасувати!"

EN[wipe_confirm2]="Type YES (uppercase) to confirm complete destruction of data: "
UK[wipe_confirm2]="Введіть YES (великими літерами) для підтвердження повного знищення даних: "

EN[wipe_cancelled]="Disk wipe cancelled."
UK[wipe_cancelled]="Стирання диска скасовано."

EN[wipe_erasing]="Erasing disk... This may take a while."
UK[wipe_erasing]="Стираю диск... Це може зайняти деякий час."

EN[wipe_complete]="Disk wipe complete!"
UK[wipe_complete]="Стирання диска завершено!"

EN[error]="An error occurred!"
UK[error]="Виникла помилка!"

EN[press_enter]="Press Enter to continue..."
UK[press_enter]="Натисніть Enter для продовження..."

EN[goodbye]="Thank you for using this tool. Glory to Ukraine!"
UK[goodbye]="Дякуємо за використання цього інструменту. Слава Україні!"

msg() {
    local key="$1"
    if [[ "$LANG" == "UK" ]]; then
        echo -e "${UK[$key]:-${EN[$key]}}"
    else
        echo -e "${EN[$key]}"
    fi
}

select_language() {
    clear
    echo "========================================"
    echo "$(msg title)"
    echo "========================================"
    echo ""
    echo "$(msg lang_menu)"
    echo ""
    echo "$(msg lang_option1)"
    echo "$(msg lang_option2)"
    echo ""
    echo -e "\033[1;31m$(msg lang_ru_notice)\033[0m"
    echo ""
    echo -e "\033[1;33m$(msg donate)\033[0m"
    echo ""
    read -rp "$(msg select_prompt)" lang_choice

    case "$lang_choice" in
        2) LANG="UK" ;;
        *) LANG="EN" ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "$(msg root_required)"
        exit 1
    fi
}

check_deps() {
    echo "$(msg checking_deps)"

    local missing=()

    if ! command -v ntfs-3g &>/dev/null && ! modprobe ntfs3 &>/dev/null; then
        missing+=("ntfs-3g")
    fi

    if ! command -v libreoffice &>/dev/null; then
        missing+=("libreoffice")
    fi

    if ! command -v wipefs &>/dev/null; then
        missing+=("wipefs")
    fi

    if ! command -v parted &>/dev/null; then
        missing+=("parted")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing: ${missing[*]}"
        read -rp "$(msg deps_missing) [y/N]: " install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            echo "$(msg installing)"
            apt-get update -qq
            apt-get install -y "${missing[@]}"
        fi
    else
        echo "$(msg deps_ok)"
    fi

    sleep 1
}

find_windows_partitions() {
    echo "$(msg partition_scan)"

    local partitions
    partitions=$(lsblk -rno NAME,SIZE,FSTYPE | awk '$3=="ntfs" {print "/dev/"$1" ("$2")"}')

    if [[ -z "$partitions" ]]; then
        echo "$(msg no_partitions)"
        return 1
    else
        echo "$(msg partitions_found)"
        echo "$partitions"
        return 0
    fi
}

mount_partition() {
    local part="$1"
    local mount_point="/mnt/windows_recovery_$$"

    mkdir -p "$mount_point"

    if mount | grep -q "^$part "; then
        mount | grep "^$part " | awk '{print $3}'
        return 0
    fi

    if mount -t ntfs-3g -o ro "$part" "$mount_point" 2>/dev/null || \
       mount -t ntfs -o ro "$part" "$mount_point" 2>/dev/null; then
        echo "$mount_point"
        return 0
    fi

    rmdir "$mount_point" 2>/dev/null
    return 1
}

setup_extensions() {
    EXTENSIONS=(doc docx odt rtf txt pdf xls xlsx ods ppt pptx odp csv html htm xml epub mobi md tex)
    EXTENSIONS+=(jpg jpeg png gif bmp tiff tif raw cr2 nef arw dng psd svg webp heic heif)
    EXTENSIONS+=(mp4 avi mkv mov wmv flv mpeg mpg m4v 3gp webm ts)
    EXTENSIONS+=(mp3 wav flac aac ogg wma m4a aiff opus)
}

ask_custom_extensions() {
    read -rp "$(msg custom_ext_prompt) [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        read -rp "$(msg custom_ext_input)" custom_exts
        IFS=',' read -ra custom_arr <<< "$custom_exts"
        for ext in "${custom_arr[@]}"; do
            ext=$(echo "$ext" | tr -d '[:space:]')
            [[ -n "$ext" ]] && EXTENSIONS+=("$ext")
        done
    fi
}

ask_conversion() {
    CONVERT=false
    if command -v libreoffice &>/dev/null; then
        read -rp "$(msg convert_prompt) [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            CONVERT=true
        fi
    else
        echo "$(msg convert_no_libreoffice)"
    fi
}

copy_data() {
    local source="$1"
    local dest="$2"
    local count=0

    echo "$(msg copy_start)"
    sleep 1

    local find_args=()
    local first=1
    for ext in "${EXTENSIONS[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            find_args+=(-o)
        fi
        find_args+=(-iname "*.$ext")
    done

    mkdir -p "$dest"

    while IFS= read -r -d '' file; do
        local basename_file
        basename_file=$(basename "$file")
        local ext="${basename_file##*.}"
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        case "$ext" in
            exe|dll|sys|bat|cmd|msi|ini|ico|lnk|tmp|temp|log|bin|cab|cat|drv|nls|ocx|scr|ttf|fon|pf|idx|db|dat|bak|old|sfcache|manifest|mui|acm|ax|com|cpl|dev|hlp|ins|isp|jse|msp|prf|reg|scf|shb|shs|xbap|xll) 
                continue 
                ;;
        esac

        local rel_path="${file#$source}"
        rel_path="${rel_path#/}"

        local target_file="$dest/$rel_path"
        local target_dir
        target_dir=$(dirname "$target_file")

        mkdir -p "$target_dir"

        if cp -n "$file" "$target_file" 2>/dev/null; then
            ((count++))
            if (( count % 100 == 0 )); then
                printf "\r$(msg copy_progress)" "$count"
            fi
        fi

    done < <(find "$source" -type f \( "${find_args[@]}" \) \
        -not -path "*/Windows/*" \
        -not -path "*/WINDOWS/*" \
        -not -path "*/Program Files/*" \
        -not -path "*/Program Files (x86)/*" \
        -not -path "*/ProgramData/*" \
        -not -path "*/\$Recycle.Bin/*" \
        -not -path "*/Recovery/*" \
        -not -path "*/System Volume Information/*" \
        -not -path "*/Boot/*" \
        -not -path "*/boot/*" \
        -not -path "*/temp/*" \
        -not -path "*/tmp/*" \
        -not -path "*/pagefile.sys" \
        -not -path "*/hiberfil.sys" \
        -not -path "*/swapfile.sys" \
        -print0 2>/dev/null)

    printf "\n"
    echo "$(msg copy_complete)"
    echo "$(msg copy_progress)" "$count"

    COPIED_COUNT=$count
}

convert_files() {
    local dest="$1"

    if [[ "$CONVERT" != true ]]; then
        return
    fi

    echo "$(msg convert_start)"

    local convert_count=0

    while IFS= read -r -d '' file; do
        local dir
        dir=$(dirname "$file")
        local ext="${file##*.}"
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        local target_ext=""
        case "$ext" in
            doc|docx) target_ext="odt" ;;
            xls|xlsx) target_ext="ods" ;;
            ppt|pptx) target_ext="odp" ;;
            *) continue ;;
        esac

        local basename_noext
        basename_noext=$(basename "$file" ".$ext")
        local target_file="$dir/${basename_noext}.$target_ext"

        if [[ ! -f "$target_file" ]]; then
            if libreoffice --headless --convert-to "$target_ext" "$file" --outdir "$dir" &>/dev/null; then
                ((convert_count++))
            fi
        fi
    done < <(find "$dest" -type f \( -iname "*.doc" -o -iname "*.docx" -o -iname "*.xls" -o -iname "*.xlsx" -o -iname "*.ppt" -o -iname "*.pptx" \) -print0)

    echo "$(msg convert_complete)"
    echo "Converted: $convert_count files"
}

wipe_disk() {
    echo "========================================"
    echo "$(msg wipe_title)"
    echo "========================================"
    echo ""
    echo -e "\033[1;31m$(msg wipe_warning)\033[0m"
    echo ""

    echo "$(msg wipe_disks)"
    lsblk -dpno NAME,SIZE,MODEL,TYPE | grep -E "disk|part"
    echo ""

    read -rp "$(msg wipe_select)" disk

    if [[ ! -b "$disk" ]]; then
        echo "Error: $disk is not a valid block device!"
        return 1
    fi

    echo ""
    read -rp "$(msg wipe_confirm1) [y/N]: " confirm1
    if [[ ! "$confirm1" =~ ^[Yy]$ ]]; then
        echo "$(msg wipe_cancelled)"
        return 0
    fi

    echo ""
    read -rp "$(msg wipe_confirm2)" confirm2
    if [[ "$confirm2" != "YES" ]]; then
        echo "$(msg wipe_cancelled)"
        return 0
    fi

    echo ""
    echo "Target: $disk"
    echo "Size: $(lsblk -dno SIZE "$disk")"
    echo "Model: $(lsblk -dno MODEL "$disk")"
    echo ""
    read -rp "FINAL CONFIRMATION - Type WIPE to destroy all data: " confirm3
    if [[ "$confirm3" != "WIPE" ]]; then
        echo "$(msg wipe_cancelled)"
        return 0
    fi

    echo "$(msg wipe_erasing)"

    umount "$disk"* 2>/dev/null || true

    shred -vfz -n 1 "$disk" || true

    wipefs -af "$disk" &>/dev/null || true

    parted -s "$disk" mklabel gpt &>/dev/null || true

    echo "$(msg wipe_complete)"
}

recovery_workflow() {
    if find_windows_partitions; then
        echo ""
        read -rp "Enter partition to use (e.g., /dev/sda2) or 'm' for manual path: " part_choice

        if [[ "$part_choice" == "m" ]]; then
            read -rp "$(msg enter_source)" SOURCE
        else
            SOURCE=$(mount_partition "$part_choice")
            if [[ -z "$SOURCE" ]] || [[ ! -d "$SOURCE" ]]; then
                echo "Failed to mount partition!"
                read -rp "$(msg enter_source)" SOURCE
            fi
        fi
    else
        read -rp "$(msg enter_source)" SOURCE
    fi

    if [[ ! -d "$SOURCE" ]]; then
        echo "Error: Source path does not exist!"
        return 1
    fi

    read -rp "$(msg enter_dest)" DEST
    if [[ -z "$DEST" ]]; then
        echo "Error: Destination cannot be empty!"
        return 1
    fi

    read -rp "$(printf "$(msg dest_confirm)" "$DEST") [y/N]: " dest_confirm
    if [[ ! "$dest_confirm" =~ ^[Yy]$ ]]; then
        return 0
    fi

    setup_extensions
    ask_custom_extensions
    ask_conversion
    copy_data "$SOURCE" "$DEST"
    convert_files "$DEST"

    echo ""
    echo "$(msg copy_complete)"
    echo "Files copied to: $DEST"
}

main_menu() {
    while true; do
        clear
        echo "========================================"
        echo "$(msg title)"
        echo "========================================"
        echo ""
        echo "$(msg main_menu)"
        echo ""
        echo "$(msg menu_copy)"
        echo "$(msg menu_wipe)"
        echo "$(msg menu_exit)"
        echo ""
        read -rp "$(msg choose_action)" action

        case "$action" in
            1)
                recovery_workflow
                read -rp "$(msg press_enter)"
                ;;
            2)
                wipe_disk
                read -rp "$(msg press_enter)"
                ;;
            3)
                echo "$(msg goodbye)"
                exit 0
                ;;
            *)
                echo "Invalid choice!"
                sleep 1
                ;;
        esac
    done
}

trap 'echo ""; echo "$(msg error)"; exit 1' ERR

select_language
check_root
check_deps
main_menu