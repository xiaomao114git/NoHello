#!/system/bin/sh
DEBUG=@DEBUG@

MODDIR=${0%/*}

check_reset_prop() {
  local NAME=$1
  local EXPECTED=$2
  local VALUE=$(resetprop $NAME)
  [ -z $VALUE ] || [ $VALUE = $EXPECTED ] || resetprop $NAME $EXPECTED
}

contains_reset_prop() {
  local NAME=$1
  local CONTAINS=$2
  local NEWVAL=$3
  [[ "$(resetprop $NAME)" = *"$CONTAINS"* ]] && resetprop $NAME $NEWVAL
}

resetprop -w sys.boot_completed 0

check_reset_prop "ro.boot.vbmeta.device_state" "locked"
check_reset_prop "ro.boot.verifiedbootstate" "green"
check_reset_prop "ro.boot.flash.locked" "1"
check_reset_prop "ro.boot.veritymode" "enforcing"
check_reset_prop "ro.boot.warranty_bit" "0"
check_reset_prop "ro.warranty_bit" "0"
check_reset_prop "ro.debuggable" "0"
check_reset_prop "ro.force.debuggable" "0"
check_reset_prop "ro.secure" "1"
check_reset_prop "ro.adb.secure" "1"
check_reset_prop "ro.build.type" "user"
check_reset_prop "ro.build.tags" "release-keys"
check_reset_prop "ro.vendor.boot.warranty_bit" "0"
check_reset_prop "ro.vendor.warranty_bit" "0"
check_reset_prop "vendor.boot.vbmeta.device_state" "locked"
check_reset_prop "vendor.boot.verifiedbootstate" "green"
check_reset_prop "sys.oem_unlock_allowed" "0"

# MIUI specific
check_reset_prop "ro.secureboot.lockstate" "locked"

# Realme specific
check_reset_prop "ro.boot.realmebootstate" "green"
check_reset_prop "ro.boot.realme.lockstate" "1"

# Hide that we booted from recovery when magisk is in recovery mode
contains_reset_prop "ro.bootmode" "recovery" "unknown"
contains_reset_prop "ro.boot.bootmode" "recovery" "unknown"
contains_reset_prop "vendor.boot.bootmode" "recovery" "unknown"

# ---------------------------------------------------------------------------
# Device-spoof: apply donor device properties (props.conf)
# ---------------------------------------------------------------------------
# props.conf holds key=value lines collected from a real donor device
# (e.g. Huawei WKG-AN00). The *editable* copy lives at
# /data/adb/nohello/props.conf (managed by the WebUI); the module directory
# copy is only the factory default fallback. When the enable marker exists
# (/data/adb/nohello/props_enabled), each key is applied with resetprop.
# ro.* properties can be changed by resetprop at runtime; note that
# Build.VERSION.SDK_INT / RELEASE are compile-time constants in the framework
# and cannot be spoofed — keep those out of the config (see shipped props.conf).
# ---------------------------------------------------------------------------
NOHELLO_DIR="/data/adb/nohello"
if [ -f "$NOHELLO_DIR/props.conf" ]; then
  PROPS_CONF="$NOHELLO_DIR/props.conf"
elif [ -f "$MODDIR/props.conf" ]; then
  PROPS_CONF="$MODDIR/props.conf"
else
  PROPS_CONF=""
fi

if [ -n "$PROPS_CONF" ]; then
  if [ -f "$NOHELLO_DIR/props_enabled" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        ''|\#*) continue ;;
      esac
      key="${line%%=*}"
      val="${line#*=}"
      [ -n "$key" ] || continue
      resetprop "$key" "$val"
    done < "$PROPS_CONF"
  fi
fi
