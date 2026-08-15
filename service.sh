#!/system/bin/sh
MODDIR=${0%/*}

log_fix() {
    log -t "KSU_LagFix" "$1"
}

# 1. 等待开机广播完全就绪
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# 避开开机服务挂载最高峰
sleep 15
log_fix "启动 v1.5.3 软重启维护流程..."

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

# 4. 仅清理 CVE 临时提权残留二进制进程 (不触碰任何系统服务)
TARGET_EXPLOITS="libcve43499root.so cve43499 libcve43499 temp_root_daemon exp_payload cve_worker su_temp"
for proc in $TARGET_EXPLOITS; do
    pkill -9 -f "$proc" 2>/dev/null
done

# 5. 优化内存换页倾向 (平息 ZRAM 颠簸与 sys CPU 占用)
if [ -f /proc/sys/vm/swappiness ]; then
    echo 100 > /proc/sys/vm/swappiness 2>/dev/null
fi
if [ -f /proc/sys/vm/vfs_cache_pressure ]; then
    echo 80 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
fi

# 6. 主动唤醒并拉起三星锁屏 AOD 时钟服务 (解决官方原装时钟丢失问题)
am startservice -n com.samsung.android.app.aodservice/.AODService >/dev/null 2>&1

sync
log_fix "v1.5.3 执行完毕，原生时钟与调度恢复正常。"
