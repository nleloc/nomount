#!/system/bin/sh

. "$MODDIR/common.sh"

if [ -f "$BOOT_SEMAPHORE" ]; then
    rm -f "$BOOT_SEMAPHORE" \
          "$NOMOUNT_DATA/.boot.lock" \
          "$NOMOUNT_DATA/.lkm.lock" \
          "$NOMOUNT_DATA/.inject.lock"
    klog "boot completed safely."
fi

if [ -f "$DUMP_RULES_FLAG" ]; then
    dump_all_rules_logcat || true
fi

exit 0
