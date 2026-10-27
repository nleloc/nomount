#!/system/bin/sh

NOMOUNT_DATA="/data/adb/nomount"
BOOT_SEMAPHORE="$NOMOUNT_DATA/.booting"
klog()      { echo "<6>nomount: $*" > /dev/kmsg; }

if [ -f "$BOOT_SEMAPHORE" ]; then
    rm -f "$BOOT_SEMAPHORE" \
          "$NOMOUNT_DATA/.boot.lock" \
          "$NOMOUNT_DATA/.lkm.lock" \
          "$NOMOUNT_DATA/.inject.lock"
    klog "boot completed safely."
fi

exit 0
