#!/system/bin/sh

MODDIR=${0%/*}

LOGFILE="$MODDIR/lagfix.log"
OUTDIR="/sdcard/Download/Samsung_LagFix"

# ============================================================
# 1. Prepare export directory
# ============================================================

mkdir -p "$OUTDIR" 2>/dev/null

if [ ! -d "$OUTDIR" ]; then
    echo "Samsung_LagFix: 无法创建日志导出目录"
    exit 1
fi

# ============================================================
# 2. Create diagnostic log if missing
# ============================================================

if [ ! -f "$LOGFILE" ]; then

    {
        echo "=================================================="
        echo "Samsung_LagFix Diagnostic Log"
        echo "=================================================="
        echo

        echo "===== Basic Information ====="

        echo "Time: $(date '+%F %T' 2>/dev/null)"
        echo "Module: Samsung_LagFix"
        echo "Module Version: 2.1.0"

        echo "Model: $(getprop ro.product.model 2>/dev/null)"
        echo "Android: $(getprop ro.build.version.release 2>/dev/null)"
        echo "SDK: $(getprop ro.build.version.sdk 2>/dev/null)"
        echo "Build: $(getprop ro.build.display.id 2>/dev/null)"

        echo

        echo "===== Boot Status ====="

        echo "sys.boot_completed=$(getprop sys.boot_completed 2>/dev/null)"

        echo

        echo "===== Voice Assistant Status ====="

        echo "role.ASSISTANT=$(cmd role get-role-holders android.app.role.ASSISTANT 2>/dev/null)"
        echo "secure.assistant=$(settings get secure assistant 2>/dev/null)"
        echo "secure.voice_interaction_service=$(settings get secure voice_interaction_service 2>/dev/null)"

        echo

        echo "===== Memory ====="

        grep '^MemTotal:' /proc/meminfo 2>/dev/null
        grep '^MemAvailable:' /proc/meminfo 2>/dev/null
        grep '^MemFree:' /proc/meminfo 2>/dev/null

        echo

        echo "===== Critical Processes ====="

        ps -A -o PID,PPID,USER,STATE,ARGS 2>/dev/null |
            grep -E 'system_server|surfaceflinger' |
            grep -v grep

        echo

        echo "===== Known Temporary Root Residual Check ====="

        ps -A -o PID,ARGS 2>/dev/null |
            grep -Ei \
            'cve43499|temp_root|exp_payload|cve_worker|su_temp|libcve43499' |
            grep -v grep

        echo

        echo "===== End ====="

    } > "$LOGFILE"

fi

# ============================================================
# 3. Generate output filename
# ============================================================

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S' 2>/dev/null)

if [ -z "$TIMESTAMP" ]; then
    TIMESTAMP="unknown"
fi

OUTFILE="$OUTDIR/Samsung_LagFix_$TIMESTAMP.log"

# ============================================================
# 4. Export log
# ============================================================

if cp "$LOGFILE" "$OUTFILE" 2>/dev/null; then

    chmod 644 "$OUTFILE" 2>/dev/null

    echo "Samsung_LagFix 日志已导出"
    echo
    echo "保存位置："
    echo "$OUTFILE"
    echo
    echo "日志大小："

    wc -c "$OUTFILE" 2>/dev/null

else

    echo "Samsung_LagFix: 日志导出失败"
    exit 1

fi

exit 0
