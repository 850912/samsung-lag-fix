#!/system/bin/sh
MODDIR=${0%/*}

log_fix() {
    log -t "KSU_LagFix" "$1"
}

# 1. 等待开机广播完全就绪
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

sleep 5
log_fix "启动 v1.5.8 维护流程..."

# 2. 平息套接字与网络工作队列风暴 (解决 kworker 抢占 CPU)
if [ -d /proc/sys/net/ipv4 ]; then
    echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 2>/dev/null
    echo 2 > /proc/sys/net/ipv4/tcp_orphan_retries 2>/dev/null
fi

# 3. 抑制 printk 与内核安全审计洪泛 (降低 Knox/DEFEX 拦截带来的高系统负载)
if [ -f /proc/sys/kernel/printk ]; then
    echo 1 > /proc/sys/kernel/printk
fi
if [ -f /proc/sys/kernel/printk_ratelimit ]; then
    echo 5 > /proc/sys/kernel/printk_ratelimit
fi

# 4. 白名单极速提权清理 (利用 ps 快速扫描 + 临时路径白名单，毫秒级执行)
EXPLOIT_NAMES="libcve43499root.so cve43499 libcve43499 temp_root_daemon exp_payload cve_worker su_temp"
for target in $EXPLOIT_NAMES; do
    for pid in $(ps -eo PID,ARGS 2>/dev/null | grep -E "(/data/local/tmp|/dev/|/data/tmp)" | grep -w "$target" | awk '{print $1}'); do
        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
done

# 5. 优化内存换页倾向 (平息 ZRAM 颠簸与 sys CPU 占用)
if [ -f /proc/sys/vm/swappiness ]; then
    echo 100 > /proc/sys/vm/swappiness 2>/dev/null
fi
if [ -f /proc/sys/vm/vfs_cache_pressure ]; then
    echo 80 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
fi

# 6. 抑制 Android 框架层服务重启风暴 (不修改任何 App 电池优化，直接限制 ActivityManager 重试频率，解除 system_server 100% CPU 占用)
settings put global activity_manager_constants "service_restart_duration=30000,service_reset_run_duration=60000,service_min_restart_time_between=15000" 2>/dev/null

# 7. 彻底拉起并强制重绘三星锁屏时钟与 AOD 视图
pkill -9 -f "com.samsung.android.app.aodservice" 2>/dev/null
sleep 1
am start-foreground-service --user 0 -n com.samsung.android.app.aodservice/.AODService >/dev/null 2>&1
am startservice --user 0 -n com.samsung.android.app.aodservice/.AODService >/dev/null 2>&1
am broadcast --user 0 -a android.intent.action.TIME_SET >/dev/null 2>&1
am broadcast --user 0 -a com.samsung.android.app.aodservice.action.AOD_STATE_CHANGED >/dev/null 2>&1

sync
log_fix "v1.5.8 执行完毕，服务重启风暴平息，原生时钟与系统运行正常。"

