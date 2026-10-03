#!/system/bin/sh

MODDIR=${0%/*}
KO_FILE="$MODDIR/lkm/nomount.ko"
NM_BIN="$MODDIR/bin/nm"
DRIVER_LOADING_SEMAPHORE="$MODDIR/.loading_driver"
DRIVER_FAIL_SEMAPHORE="$MODDIR/driver_load_failed"
# the DRIVER_LOADING_SEMAPHORE will be removed in boot-completed.sh

# If somehow metamount.sh haven't delete driver_load_failed yet
rm -f "$DRIVER_FAIL_SEMAPHORE"

# log
klog()      { echo "<6>nomount: $*" > /dev/kmsg; } # info log
klogwarn()  { echo "<4>nomount: $*" > /dev/kmsg; } # warning
klogerr()   { echo "<3>nomount: $*" > /dev/kmsg; } # error


# If kernel had build-in, just skip
if "$NM_BIN" version >/dev/null 2>&1; then
    klog "Built-in Kernel support detected."
    rm -f "$DRIVER_LOADING_SEMAPHORE" # unimportant, for user who switch from LKM to Built-in
    exit 0
fi

# Anti bootloop, only for LKM bc NM module can't save you from built-in driver bootloop
if [ -f "$DRIVER_LOADING_SEMAPHORE" ]; then
    klogerr "Bootloop detected! driver caused a crash on the last boot"
    klogwarn "Flagging failed to load LKM..."
  touch "$DRIVER_FAIL_SEMAPHORE" && sync
    exit 1
fi

touch "$DRIVER_LOADING_SEMAPHORE" && sync
klog "Built-in not found. Attempting to load LKM..."

for root_cmd in ksud apd; do
    # avoid APatch users have to run this 2 times
    command -v "$root_cmd" >/dev/null 2>&1 || continue
    "$root_cmd" insmod "$KO_FILE" >/dev/null 2>&1
    exit_code=$?

    if [ "$exit_code" -eq 0 ] && "$NM_BIN" version >/dev/null 2>&1; then
        klog "$root_cmd insmod succeeded"
        exit 0
    fi

    klogwarn "$root_cmd insmod failed code $exit_code"
    rmmod nomount 2>/dev/null
done

klog "try falling back to lkmloader"
if "$MODDIR/lkm/lkmloader" "$KO_FILE" >/dev/null 2>&1 && "$NM_BIN" version >/dev/null 2>&1; then
    klog "lkmloader succeeded"
    exit 0
fi

klogerr "lkmloader failed; LKM hasn't been loaded."
touch "$DRIVER_FAIL_SEMAPHORE" && sync
exit 1
