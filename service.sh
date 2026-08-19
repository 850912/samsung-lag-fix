#!/system/bin/sh

MODDIR=${0%/*}
TAG="KSU_LagFix"
LOGFILE="$MODDIR/lagfix.log"

log_fix() {
    MSG="$1"

    # Android logcat
    log -t "$TAG" "$MSG" 2>/dev/null

    # Module log
    printf '%s %s\n' \
        "$(date '+%F %T' 2>/dev/null)" \
        "$MSG" >> "$LOGFILE"
}

# ============================================================
# 1. Prepare log
# ============================================================

touch "$LOGFILE" 2>/dev/null

# Keep log size under 64 KB.
if [ -f "$LOGFILE" ]; then
    SIZE=$(wc -c < "$LOGFILE" 2>/dev/null)

    if [ "${SIZE:-0}" -gt 65536 ]; then
        tail -c 32768 "$LOGFILE" > "$LOGFILE.tmp" 2>/dev/null

        if [ -f "$LOGFILE.tmp" ]; then
            mv "$LOGFILE.tmp" "$LOGFILE" 2>/dev/null
        fi
    fi
fi

log_fix "v2.1.0 启动：安全维护模式"

# ============================================================
# 2. Wait for Android framework
# ============================================================

BOOT_WAIT=0

while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 2

    BOOT_WAIT=$((BOOT_WAIT + 2))

    # Safety timeout: 120 seconds
    if [ "$BOOT_WAIT" -ge 120 ]; then
        log_fix "警告：等待系统启动完成超时"
        break
    fi
done

if [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; then
    log_fix "系统启动完成，等待耗时约 ${BOOT_WAIT}秒"
fi

# 预留 5 秒等待三星系统 CSC / Role 策略初始化完成
log_fix "等待三星 CSC / Role 策略初始化 5 秒"
sleep 5

# ============================================================
# 3. Dynamic Voice Assistant Self-Heal (条件自愈)
# ============================================================

GSA_PKG="com.google.android.googlequicksearchbox"
GSA_SVC="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService"

# 读取当前系统配置的 Assistant 状态
CUR_ROLE=$(cmd role get-role-holders android.app.role.ASSISTANT 2>/dev/null)
CUR_ASSIST=$(settings get secure assistant 2>/dev/null)
CUR_VOICE_SVC=$(settings get secure voice_interaction_service 2>/dev/null)

# 仅当系统 Role 或 secure assistant 设置明确为 Google 时才执行修复
if [ "$CUR_ROLE" = "$GSA_PKG" ] || echo "$CUR_ASSIST" | grep -q "$GSA_PKG"; then
    if [ "$CUR_VOICE_SVC" != "$GSA_SVC" ]; then
        settings put secure voice_interaction_service "$GSA_SVC" 2>/dev/null
        log_fix "检测到默认助手为 Google 且底层服务丢失，已自动补全 voice_interaction_service"
    else
        log_fix "Google 语音交互服务绑定正常，无需补全"
    fi
else
    log_fix "当前默认助手非 Google（Role: ${CUR_ROLE:-无}），跳过语音服务修改"
fi

# ============================================================
# 4. Known Temporary Root residual process check
# ============================================================

EXPLOIT_NAMES="
libcve43499root.so
cve43499
libcve43499
temp_root_daemon
exp_payload
cve_worker
su_temp
"

for target in $EXPLOIT_NAMES; do

    ps -A -o PID,ARGS 2>/dev/null |
    while read -r pid args; do

        [ -z "$pid" ] && continue
        [ "$pid" = "PID" ] && continue

        # Only inspect processes running from explicitly
        # temporary/root-related locations.
        case "$args" in
            /data/local/tmp/*|/data/tmp/*|/dev/*)
                ;;
            *)
                continue
                ;;
        esac

        case "$args" in
            *"$target"*)

                log_fix "发现已知临时Root残留：PID=$pid TARGET=$target"

                kill "$pid" 2>/dev/null
                sleep 1

                if kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" 2>/dev/null
                    log_fix "强制终止 PID=$pid"
                else
                    log_fix "已正常终止 PID=$pid"
                fi

                ;;
        esac

    done

done

# ============================================================
# 5. Verify residual processes
# ============================================================

REMAINING=0

for target in $EXPLOIT_NAMES; do

    if ps -A -o PID,ARGS 2>/dev/null |
        grep -E "/data/local/tmp/|/data/tmp/|/dev/" |
        grep -F "$target" >/dev/null 2>&1; then

        REMAINING=1
        log_fix "警告：仍检测到已知临时Root残留：$target"

    fi

done

if [ "$REMAINING" = "0" ]; then
    log_fix "已知临时Root残留检查：通过"
fi

# ============================================================
# 6. Check critical Android processes
# ============================================================

for proc in system_server surfaceflinger; do

    PID=$(pidof "$proc" 2>/dev/null)

    if [ -n "$PID" ]; then
        log_fix "$proc 正常运行 PID=$PID"
    else
        log_fix "警告：$proc 当前未找到"
    fi

done

# ============================================================
# 7. Memory information
# ============================================================

MEM=$(grep '^MemAvailable:' /proc/meminfo 2>/dev/null | head -n 1)

if [ -n "$MEM" ]; then
    log_fix "$MEM"
else
    log_fix "警告：无法读取 MemAvailable"
fi

# ============================================================
# 8. Basic system information
# ============================================================

MODEL=$(getprop ro.product.model 2>/dev/null)
ANDROID=$(getprop ro.build.version.release 2>/dev/null)
SDK=$(getprop ro.build.version.sdk 2>/dev/null)

[ -n "$MODEL" ] && log_fix "设备型号：$MODEL"
[ -n "$ANDROID" ] && log_fix "Android版本：$ANDROID"
[ -n "$SDK" ] && log_fix "SDK版本：$SDK"

# ============================================================
# 9. Finish
# ============================================================

log_fix "v2.1.0 执行完毕"

exit 0
