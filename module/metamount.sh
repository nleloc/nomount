#!/system/bin/sh

MODDIR=${0%/*}
LOADER="$MODDIR/bin/nm"
MODULES_DIR="/data/adb/modules"
BOOT_SEMAPHORE="$MODDIR/.mounting"
DRIVER_FAIL_SEMAPHORE="$MODDIR/driver_load_failed"
TARGET_PARTITIONS="system system_ext vendor odm product apex oem optics prism
                    mi_ext my_bigball my_carrier my_company my_engineering my_heytap
                    my_manifest my_preload my_product my_region my_reserve my_stock"
PROP_FILE="$MODDIR/module.prop"
BASE_DESC="A metamodule that replaces OverlayFS/MagicMount with VFS path redirection."

# this currently does not have a log for `nm` binary

# calling logcat binary every single time needs to log..
# don't over use it
log_info()  { log -t NoMount -p i "$*"; } # info log
log_warn()  { log -t NoMount -p w "$*"; } # warning
log_err()   { log -t NoMount -p e "$*"; } # error


if [ -f "$DRIVER_FAIL_SEMAPHORE" ]; then
    touch "$MODDIR/disable"
    sed -i "s|^description=.*|description=[❌ Kernel not patched / LKM failed to load] \\\\n$BASE_DESC|" "$PROP_FILE"
    rm -f "$DRIVER_FAIL_SEMAPHORE"
    exit 1
fi

if [ -f "$BOOT_SEMAPHORE" ]; then
    log_err "Anti-Bootloop triggered! Your system crashed on last boot."
    touch "$MODDIR/disable"
    sed -i "s|^description=.*|description=[🚨 Anti-Bootloop triggered] \\\\n$BASE_DESC|" "$PROP_FILE"
    rm -f "$BOOT_SEMAPHORE"
    exit 1
fi

touch "$BOOT_SEMAPHORE"

for mod_path in "$MODULES_DIR"/*; do
    [ -d "$mod_path" ] || continue
    mod_name="${mod_path##*/}"
    [ "$mod_name" = "nomount" ] && continue

    if [ -f "$mod_path/disable" ] || [ -f "$mod_path/remove" ] || [ -f "$mod_path/skip_mount" ]; then
        echo "[SKIP] Module $mod_name is disabled/removed/skipped" >> "$LOG_FILE"; continue
    fi

    for partition in $TARGET_PARTITIONS; do
        if [ -d "$mod_path/$partition" ]; then
            [ -d "/$partition" ] || [ -d "/system/$partition" ] || continue
            echo "[INFO] Mounting module: $mod_name (/$partition)" >> "$LOG_FILE"
            find -L "$mod_path/$partition" \( -type d -o -type c -o -name ".replace" \) -exec sh -c '
                for f do
                    v="${f#'"$mod_path"'}"
                    case "$v" in /system/*)
                        p="${v#/system/}"; p="${p%%/*}"
                        case "$p" in vendor|system_ext|product|odm|apex|oem|optics|prism|mi_ext|my_*)
                            v="/$p${v#/system/$p}" ;;
                        esac
                    ;; esac
                    if [ -d "$f" ]; then case "$(getfattr -n trusted.overlay.opaque "$f" 2>/dev/null)" in *"=\"y\""*) printf "%s\0" "$v";; esac
                    elif [ "${f##*/}" = ".replace" ]; then printf "%s\0" "${v%/.replace}"
                    else printf "%s\0" "$v"; fi
                done
            ' _ {} + 2>/dev/null | xargs -0 -r -n 200 "$LOADER" rule add --whiteout >> "$LOG_FILE" 2>&1

            find -L "$mod_path/$partition" \( -type f -o -type l \) ! -name ".replace" -exec sh -c '
                for f do
                    v="${f#'"$mod_path"'}"
                    case "$v" in /system/*)
                        p="${v#/system/}"; p="${p%%/*}"
                        case "$p" in vendor|system_ext|product|odm|apex|oem|optics|prism|mi_ext|my_*)
                            v="/$p${v#/system/$p}" ;;
                        esac
                    ;; esac
                    printf "%s\0%s\0" "$v" "$f"
                done
            ' _ {} + 2>/dev/null | xargs -0 -r -n 200 "$LOADER" rule add >> "$LOG_FILE" 2>&1
        fi
    done
done

echo "=== Injection Complete: $(date) ===" >> "$LOG_FILE"

rm -f "$BOOT_SEMAPHORE"
echo "[OK] Boot phase completed safely." >> "$LOG_FILE"
sed -i "s|^description=.*|description=$BASE_DESC|" "$PROP_FILE"

exit 0
