#!/bin/bash
# ==============================================================================
#  Ionfetch - Ultra-fast, minimal homelab & server fetch utility
# ==============================================================================

VERSION="0.2.2"
# C locale is available on every supported Linux distribution.
export LC_ALL=C

# Help & Version flags
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            cat <<EOF
Ionfetch v${VERSION}
Ultra-fast, minimal server status and homelab fetch utility.

Usage:
  ionfetch [options]

Options:
  -h, --help       Show this help message
  -v, --version    Show version information
  --no-color       Disable ANSI color output

Environment Variables:
  IONFETCH_TITLE       Custom header title (default: distro name or "CORE SERVER")
  IONFETCH_SUBTITLE    Custom subtitle (default: "HOSTNAME / <hostname>")
  IONFETCH_DISK_PATH   Path of one disk/mount to inspect (default: all storage)

EOF
            exit 0
            ;;
        -v|--version)
            echo "ionfetch v${VERSION}"
            exit 0
            ;;
        --no-color)
            NO_COLOR=1
            ;;
        '')
            ;;
        *)
            printf 'ionfetch: unknown option: %s\n' "$arg" >&2
            printf 'Try "ionfetch --help" for usage.\n' >&2
            exit 2
            ;;
    esac
done

# Colors
if [[ -n "${NO_COLOR:-}" ]]; then
    RESET='' GRAY='' LABEL='' WHITE='' GREEN='' YELLOW='' RED=''
else
    RESET=$'\e[0m'
    GRAY=$'\e[90m'
    LABEL=$'\e[37m'
    WHITE=$'\e[97m'
    GREEN=$'\e[1;92m'
    YELLOW=$'\e[93m'
    RED=$'\e[91m'
fi

# Detect OS information if available
os_name=''
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    os_name=$(awk -F= '$1=="PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release 2>/dev/null)
fi

# System information
host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "unknown")
cores=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
load=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.00")

# CPU Temperature detection (checks thermal_zone and hwmon)
cpu_temp=''
# 1. Try thermal_zone
for tz in /sys/class/thermal/thermal_zone*; do
    if [[ -f "$tz/temp" ]]; then
        t=$(cat "$tz/temp" 2>/dev/null)
        if [[ "$t" =~ ^[0-9]+$ ]] && ((t > 0)); then
            if ((t > 1000)); then
                cpu_temp=$(( (t + 500) / 1000 ))
            else
                cpu_temp=$t
            fi
            break
        fi
    fi
done

# 2. Fallback to hwmon (Intel coretemp / AMD k10temp / hardware monitors)
if [[ -z "$cpu_temp" ]]; then
    for hw in /sys/class/hwmon/hwmon*; do
        hw_name=$(cat "$hw/name" 2>/dev/null || echo "")
        for tf in "$hw"/temp*_input; do
            if [[ -f "$tf" ]]; then
                t=$(cat "$tf" 2>/dev/null)
                if [[ "$t" =~ ^[0-9]+$ ]] && ((t > 0)); then
                    if ((t > 1000)); then
                        cpu_temp=$(( (t + 500) / 1000 ))
                    else
                        cpu_temp=$t
                    fi
                    # Prioritize sensors identified as coretemp/cpu/k10
                    if [[ "$hw_name" =~ (core|cpu|k10|zen) ]]; then
                        break 2
                    fi
                    break
                fi
            fi
        done
    done
fi

# Primary IP Address detection (with local network fallback)
ip_addr=$(ip -4 route get 1.1.1.1 2>/dev/null |
    awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')

if [[ -z "$ip_addr" ]]; then
    ip_addr=$(ip -4 route show default 2>/dev/null |
        awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
fi

if [[ -z "$ip_addr" ]] && command -v hostname >/dev/null 2>&1; then
    ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
ip_addr=${ip_addr:-unavailable}

# Uptime
uptime_text=$(awk '{
    seconds=int($1)
    printf "%dd %02dh %02dm",
        int(seconds/86400),
        int(seconds/3600)%24,
        int(seconds/60)%60
}' /proc/uptime 2>/dev/null || echo "unavailable")

# RAM Information
read -r ram_used ram_total ram_percent < <(
    awk '
        /MemTotal:/     {total=$2}
        /MemAvailable:/ {available=$2}
        END {
            used=total-available
            if (total > 0) {
                printf "%.1f %.1f %.0f\n",
                    used/1048576, total/1048576, used/total*100
            } else {
                printf "0.0 0.0 0\n"
            }
        }
    ' /proc/meminfo 2>/dev/null
)
ram_used=${ram_used:-0.0}
ram_total=${ram_total:-0.0}
ram_percent=${ram_percent:-0}

# Disk Information. Keep one entry per real filesystem and ignore pseudo mounts.
disk_target="${IONFETCH_DISK_PATH:-}"
disk_entries=''
if [[ -n "$disk_target" ]]; then
    disk_source=$(df -PkPT "$disk_target" 2>/dev/null | awk 'NR==2 {print $1}')
    if [[ -n "$disk_source" ]]; then
        disk_entries=$(df -PkPT "$disk_target" 2>/dev/null | awk -v source="$disk_source" '
            NR > 1 && $1 == source {
                used=$4; total=$3; percent=$6; sub(/%$/, "", percent)
                mount=$7
                for (i=8; i<=NF; i++) mount=mount " " $i
                gsub(/\\040/, " ", mount)
                printf "%s\t%s\t%s\t%s\n", source, mount, used, total " " percent
                exit
            }
        ')
    fi
else
    disk_entries=$(df -PkPT 2>/dev/null | awk '
        NR == 1 {next}
        {
            source=$1; fstype=$2; total=$3; used=$4; percent=$6; sub(/%$/, "", percent)
            mount=$7
            for (i=8; i<=NF; i++) mount=mount " " $i
            gsub(/\\040/, " ", mount)
            if (fstype ~ /^(rootfs|tmpfs|devtmpfs|proc|sysfs|cgroup|cgroup2|overlay|squashfs|ramfs|securityfs|pstore|debugfs|tracefs|configfs|fusectl|mqueue|hugetlbfs|binfmt_misc|autofs|rpc_pipefs|nsfs|efivarfs|bpf|fuse\.)$/) next
            if (seen[source]++) next
            printf "%s\t%s\t%s\t%s %s\n", source, mount, used, total, percent
        }
    ')
fi

# Failed Systemd Services
if failed=$(systemctl --failed --type=service \
    --no-legend --plain --no-pager 2>/dev/null); then
    failed_count=$(printf '%s\n' "$failed" |
        awk 'NF {n++} END {print n+0}')
else
    failed=''
    failed_count='unknown'
fi

# Pending Reboot Check (Debian/Ubuntu/RHEL)
reboot_required=0
if [[ -f /var/run/reboot-required || -f /run/reboot-required ]]; then
    reboot_required=1
fi

# Resource bars
resource() {
    local label="$1" percent="${2:-0}" details="$3"
    local filled color used='' empty='' i display_label

    # Keep all resource bars aligned, even when a mount path is long.
    display_label="$label"
    if ((${#display_label} > 20)); then
        display_label="${display_label:0:17}..."
    fi

    # Clean decimal if present
    percent="${percent%.*}"
    ((percent < 0)) && percent=0
    ((percent > 100)) && percent=100
    filled=$(((percent + 9) / 10))

    if ((percent >= 90)); then
        color="$RED"
    elif ((percent >= 70)); then
        color="$YELLOW"
    else
        color="$GREEN"
    fi

    for ((i=0; i<10; i++)); do
        if ((i < filled)); then
            used+='#'
        else
            empty+='.'
        fi
    done

    printf '%s%-20s %s[%s%s%s%s%s] %s%3d%%%s  %s%s%s\n' \
        "$LABEL" "$display_label" "$RESET" \
        "$color" "$used" "$GRAY" "$empty" "$RESET" \
        "$color" "$percent" "$RESET" \
        "$WHITE" "$details" "$RESET"
}

# Display Header
title="${IONFETCH_TITLE:-${os_name:-CORE SERVER}}"
subtitle="${IONFETCH_SUBTITLE:-HOSTNAME / ${host}}"

printf '%s%s%s\n' "$GREEN" "$title" "$RESET"
printf '%s%s%s\n' "$LABEL" "$subtitle" "$RESET"
printf '%s----------------------------%s\n' "$GRAY" "$RESET"

# Metrics Display
printf '%s%-8s%s%s%s\n' \
    "$LABEL" 'IP' "$WHITE" "$ip_addr" "$RESET"
printf '%s%-8s%s%s%s\n' \
    "$LABEL" 'UPTIME' "$WHITE" "$uptime_text" "$RESET"

resource 'RAM' "$ram_percent" "$ram_used/$ram_total GiB"

if [[ -n "$disk_entries" ]]; then
    disk_number=0
    while IFS=$'\t' read -r disk_source disk_mount disk_used_kib disk_total_percent; do
        [[ -z "$disk_source" ]] && continue
        disk_number=$((disk_number + 1))
        read -r disk_total_kib disk_percent <<< "$disk_total_percent"
        disk_used_gib=$(awk -v value="$disk_used_kib" 'BEGIN {printf "%.1f", value/1048576}')
        disk_total_gib=$(awk -v value="$disk_total_kib" 'BEGIN {printf "%.1f", value/1048576}')
        resource "DISK $disk_number [$disk_mount]" "$disk_percent" "$disk_used_gib/$disk_total_gib GiB"
    done <<< "$disk_entries"
else
    printf '%s%-20s %s%s%s\n' "$LABEL" 'DISK' "$YELLOW" 'unavailable' "$RESET"
fi

# CPU Load & optional Temperature
if [[ -n "$cpu_temp" ]]; then
    temp_color="$GREEN"
    ((cpu_temp >= 80)) && temp_color="$RED"
    ((cpu_temp >= 65 && cpu_temp < 80)) && temp_color="$YELLOW"

    printf '%s%-8s%s%s / %s cores  %s(%d°C)%s\n' \
        "$LABEL" 'LOAD' "$WHITE" "$load" "$cores" \
        "$temp_color" "$cpu_temp" "$RESET"
else
    printf '%s%-8s%s%s / %s cores%s\n' \
        "$LABEL" 'LOAD' "$WHITE" "$load" "$cores" "$RESET"
fi

# Failed Services (with truncation & hint)
if [[ "$failed_count" == '0' ]]; then
    printf '%s%-8s%s0 services%s\n' \
        "$LABEL" 'FAILED' "$GREEN" "$RESET"
elif [[ "$failed_count" == 'unknown' ]]; then
    printf '%s%-8s%sunavailable%s\n' \
        "$LABEL" 'FAILED' "$YELLOW" "$RESET"
else
    printf '%s%-8s%s%s services%s\n' \
        "$LABEL" 'FAILED' "$RED" "$failed_count" "$RESET"

    local_count=0
    max_failed=3
    while read -r service rest; do
        # Filter out systemd status bullets (● or *)
        if [[ "$service" == "●" || "$service" == "*" ]]; then
            service="$rest"
        fi
        service="${service%% *}"
        if [[ -n "$service" ]]; then
            ((local_count++))
            if ((local_count <= max_failed)); then
                printf '  %s• %s%s\n' "$RED" "$service" "$RESET"
            fi
        fi
    done <<< "$failed"

    if ((local_count > max_failed)); then
        printf '  %s... and %d more (run: systemctl --failed)%s\n' \
            "$GRAY" "$((local_count - max_failed))" "$RESET"
    fi
fi

# System Pending Reboot Notice (only shown when reboot is required)
if ((reboot_required == 1)); then
    printf '%s%-8s%srequired (kernel/package update)%s\n' \
        "$LABEL" 'REBOOT' "$YELLOW" "$RESET"
fi

exit 0
