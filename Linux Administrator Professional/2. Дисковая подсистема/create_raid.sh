#!/usr/bin/env bash
#set -x
# Интерактивный скрипт для создания RAID-массива

set -euo pipefail  # Строгий режим: выход при ошибках, неопределённых переменных, ошибках в пайпах

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

check_command() {
    local cmd=$1

    # Проверка, что аргумент передан
    if [[ -z "$cmd" ]]; then
        log_error "Ошибка: не указано имя команды для проверки."
        return 1
    fi

    if ! command -v "$cmd" &> /dev/null; then
        log_error "Команда '$cmd' не найдена."
        return 1
    fi

    return 0
}

get_available_disks() {
    local -a disks=() # Явно объявляем массив
    local disk_pattern='^vd[b-z]$'

    # 1. Получаем список кандидатов и сразу проверяем успешность команды
    local raw_disks
    raw_disks=$(lsblk -d -n -o NAME 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Ошибка: не удалось получить список блочных устройств (lsblk)."
        return 1 # Используем return, так как это функция, а не скрипт
    fi

    # 2. Обрабатываем список в цикле (сохраняем классический подход)
    while IFS= read -r disk; do
        # Проверяем имя диска и отсутствие его в RAID-массиве
        if [[ "$disk" =~ $disk_pattern ]] && ! grep -q "$disk" /proc/mdstat 2>/dev/null; then
            disks+=("$disk")
        fi
    done < <(printf '%s\n' "$raw_disks")

    # 3. Проверка результата
    if [ ${#disks[@]} -eq 0 ]; then
        log_error "Не найдено доступных дисков для RAID."
        return 1
    fi

    # Выводим результат через пробел для удобства чтения в логах
    #log_info "Доступные диски: ${disks[*]}"

    # Возвращаем массив через глобальную переменную или просто используем внутри
    available_disks=("${disks[@]}")
}

validate_disk_indices() {
    local -a indices=("$@")
    local max_index="${#available_disks[@]}"

    for idx in "${indices[@]}"; do
        if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > max_index )); then
            echo "Ошибка: неверный номер диска '$idx'. Допустимые значения: 1..$max_index" >&2
            return 1
        fi
    done
    return 0
}

map_indices_to_disks() {
    local -a indices=("$@")
    local -a selected_disks=()

    for idx in "${indices[@]}"; do
        selected_disks+=("/dev/${available_disks[$((idx - 1))]}")
    done

    echo "${selected_disks[@]}"
}

select_disks() {
    local disk_indices indices_array

    while true; do
        read -rp "Введите номера дисков через пробел (например: 1 2): " disk_indices

        # Разбиваем строку на массив
        IFS=' ' read -ra indices_array <<< "$disk_indices"

        # Пропускаем пустые значения
        if (( ${#indices_array[@]} == 0 )); then
            echo "Ошибка: не введено ни одного номера диска." >&2
            continue
        fi

        if validate_disk_indices "${indices_array[@]}"; then
            map_indices_to_disks "${indices_array[@]}"
            return 0
        fi
    done
}

select_raid_level() {
    declare -A raid_levels=(
        [0]='RAID 0 (чередование, striping) — максимальная скорость, нет отказоустойчивости'
        [1]='RAID 1 (зеркалирование) — высокая отказоустойчивость, скорость записи может снижаться'
        [5]='RAID 5 (с чётностью) — баланс скорости и отказоустойчивости, требуется минимум 3 диска'
        [6]='RAID 6 (с двойной чётностью) — повышенная отказоустойчивость, требуется минимум 4 диска'
        [10]='RAID 10 (зеркалирование + чередование) — высокая скорость и отказоустойчивость, чётное число дисков'
    )
    local -a ordered_levels=(0 1 5 6 10)

    log_info "Доступные уровни RAID:"
    for level in "${ordered_levels[@]}"; do
        echo "  $level: ${raid_levels[$level]}"
    done

    # Цикл для запроса и валидации ввода
    while true; do
        read -rp "Выберите уровень RAID (0/1/5/6/10): " raid_level

        # Проверка, что ввод — целое число
        if [[ "$raid_level" =~ ^[0-9]+$ ]]; then
            # Проверка, что число есть в списке допустимых уровней
            if [[ " ${ordered_levels[*]} " =~ " ${raid_level} " ]]; then
                raid_level=$raid_level
                break
            fi
        fi

        # Сообщение об ошибке выводится в stderr
        log_error "Ошибка: неверный уровень RAID. Пожалуйста, выберите из списка." >&2
    done

    log_info "Выбран RAID $raid_level"
    return 0
}

validate_disk_count() {
    local -r level="$1"
    local -r count="$2"

    case "$level" in
        0)
            if (( count < 2 )); then
                log_error "RAID 0 требует минимум 2 диска."
                return 1
            fi
            ;;
        1)
            if (( count < 2 )); then
                log_error "RAID 1 требует минимум 2 диска."
                return 1
            fi
            ;;
        5)
            if (( count < 3 )); then
                log_error "RAID 5 требует минимум 3 диска."
                return 1
            fi
            ;;
        6)
            if (( count < 4 )); then
                log_error "RAID 6 требует минимум 4 диска."
                return 1
            fi
            ;;
        10)
            if (( count % 2 != 0 )); then
                log_error "RAID 10 требует чётного числа дисков."
                return 1
            fi
            ;;
        *)
            log_error "Неизвестный уровень RAID: $level"
            return 1
            ;;
    esac

    return 0
}

zero_superblocks() {
    local -a disks=("$@")

    if (( ${#disks[@]} == 0 )); then
        log_warn "Список дисков для зануления суперблоков пуст. Ничего не сделано."
        return 1
    fi

    log_info "Зануление суперблоков на выбранных дисках: ${disks[*]}..."

    for disk in "${disks[@]}"; do
        if ! [ -b "$disk" ]; then
            log_warn "Диск '$disk' не существует или не является блочным устройством. Пропуск."
            continue
        fi

        if mdadm --zero-superblock --force "$disk"; then
            log_info "Суперблок успешно занулён на $disk"
        else
            log_warn "Не удалось занулить суперблок на $disk (возможно, его не было)"
        fi
    done

    return 0
}

create_raid() {
    local raid_level=$1
    local disk_devices=("${@:2}")

    # Валидация аргументов
    if [[ -z "$raid_level" || ${#disk_devices[@]} -eq 0 ]]; then
        log_error "Ошибка: не указан уровень RAID или список дисков пуст."
        return 1
    fi

    local disk_list=$(IFS=,; echo "${disk_devices[*]}")
    log_info "Создание RAID-$raid_level массива /dev/md0 из дисков: $disk_list"

    # Формирование команды mdadm
    if mdadm --create --verbose /dev/md0 \
        --level="$raid_level" \
        --raid-devices="${#disk_devices[@]}" \
        "${disk_devices[@]}" <<< "y"; then
        log_info "RAID-$raid_level массив /dev/md0 успешно создан."
    else
        log_error "Ошибка при создании RAID-$raid_level массива."
        return 1
    fi
}

wait_for_resync() {
    local mdstat="/proc/mdstat"
    log_info "Ожидание завершения ресинхронизации массива..."

    # Проверка наличия файла
    if [[ ! -f "$mdstat" ]]; then
        log_error "Файл $mdstat не найден."
        return 1
    fi

    # Локальные функции для инкапсуляции логики
    is_sync_active() {
        grep -qE "(resync|recovery)" "$mdstat"
    }

    get_sync_progress() {
        grep -Eo "[0-9.]+%" "$mdstat" | head -n1 || echo "0%"
    }

    # Основной цикл ожидания
    while is_sync_active; do
        local progress=$(get_sync_progress)
        printf "Прогресс ресинхронизации: %s " "$progress"
        sleep 5
        printf "\r"
    done

    echo "Ресинхронизация завершена."
}

ask_for_confirmation() {
    local question="$1"
    read -r -p "$question [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0 # Пользователь согласился
            ;;
        *)
            return 1 # Пользователь отказался или нажал Enter
            ;;
    esac
}

verify_raid_status_and_confirm() {
    log_info "Проверка состояния массива /dev/md0..."

    # 1. Получаем детальную информацию о массиве
    local raid_info=$(mdadm -D /dev/md0 2>&1)
    local exit_code=$?

    # 2. Проверяем, успешно ли выполнилась команда mdadm
    if [[ $exit_code -ne 0 ]]; then
        log_error "Ошибка при получении информации о массиве:"
        echo "$raid_info"
        return 1
    fi

    # 3. Выводим информацию пользователю для ознакомления
    echo "--- Информация о массиве /dev/md0 (вывод mdadm -D) ---"
    echo "$raid_info"
    echo "-----------------------------------------------------------"

    # 4. Запрашиваем подтверждение на сохранение настроек
    if ask_for_confirmation "Проверьте вывод выше. Всё ли в порядке? Нажмите Y для сохранения настроек."; then
        return 0
    else
        log_error "Операция отменена пользователем."
        return 1
    fi

}

save_raid_config() {
    local config_file="/etc/mdadm/mdadm.conf"

    log_info "Сохранение конфигурации RAID в ${config_file}..."

    # Создаём директорию, если её нет
    mkdir -p /etc/mdadm || {
        log_error "Не удалось создать директорию /etc/mdadm."
        return 1
    }

    # Сохраняем вывод mdadm в файл
    if mdadm --detail --scan | tee -a "${config_file}" > /dev/null; then
        log_info "Конфигурация RAID успешно сохранена в ${config_file}."
        return 0
    else
        log_error "Ошибка: не удалось сохранить конфигурацию RAID в ${config_file}."
        return 2
    fi
}

main() {
    log_info "=== Начало создания RAID-массива ==="

    # Проверки

    if ! check_command "mdadm"; then
        log_error "Завершение работы скрипта."
        exit 1
    fi

    if ! check_command "lsblk"; then
        log_error "Завершение работы скрипта."
        exit 1
    fi

    # Получение доступных дисков
    get_available_disks

    if [ $? -ne 0 ]; then
        log_error "Не удалось подготовить список дисков. Прерывание работы."
        exit 1
    fi

    # Вывод списка доступных дисков
    echo "Доступные диски для RAID:"
    for i in "${!available_disks[@]}"; do
        echo "  $((i + 1)). /dev/${available_disks[i]}"
    done

    # Выбор дисков
    selected_disks=($(select_disks))

    if (( ${#selected_disks[@]} > 0 )); then
        log_info "Выбраны диски: ${selected_disks[*]}"
    else
        log_error "Не удалось выбрать диски." >&2
        exit 1
    fi

    # Выбор уровня RAID
    select_raid_level

    # Проверка количества дисков для выбранного уровня RAID
    if ! validate_disk_count "$raid_level" "${#selected_disks[@]}"; then
        exit 1
    fi

    log_info "Выбрано ${#selected_disks[@]} дисков для RAID-$raid_level: ${selected_disks[*]}"

    # Подтверждение перед созданием RAID
    read -p "Продолжить создание RAID? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Создание RAID отменено пользователем."
        exit 0
    fi

    # Основные операции по созданию RAID
    zero_superblocks "${selected_disks[@]}"
    create_raid "$raid_level" "${selected_disks[@]}"
    wait_for_resync
    verify_raid_status_and_confirm
    save_raid_config

    # Финальная проверка и вывод информации
    log_info "=== Создание RAID-массива завершено успешно! ==="
    log_info "Массив /dev/md0 готов к использованию."
    log_info "Для монтирования создайте файловую систему (например: mkfs.ext4 /dev/md0)"

    # Вывод краткой сводки
    echo ""
    log_info "Сводка по массиву:"
    mdadm -D /dev/md0 | grep -E "(Array Size|Raid Level|Active Devices|State)"
}

# Обработка сигналов для корректного завершения
trap 'log_error "Скрипт прерван пользователем."; exit 1' INT TERM

# Запуск основной функции
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
