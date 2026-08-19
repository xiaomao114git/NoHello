# shellcheck disable=SC2034
SKIPUNZIP=1

DEBUG=@DEBUG@
SONAME=@SONAME@
SUPPORTED_ABIS="@SUPPORTED_ABIS@"

if [ "$BOOTMODE" ] && [ "$KSU" ]; then
  ui_print "- Installing from KernelSU app"
  ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
  if [ "$(which magisk)" ]; then
    ui_print "*********************************************************"
    ui_print "! Multiple root implementation is NOT supported!"
    ui_print "! Please uninstall Magisk before installing Zygisk Next"
    abort    "*********************************************************"
  fi
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
  ui_print "- Installing from Magisk app"
else
  ui_print "*********************************************************"
  ui_print "! Install from recovery is not supported"
  ui_print "! Please install from KernelSU or Magisk app"
  abort    "*********************************************************"
fi

VERSION=$(grep_prop version "${TMPDIR}/module.prop")
DESCRIPTION=$(grep_prop description "${TMPDIR}/module.prop")
ui_print "- Installing $SONAME $VERSION"

# check architecture
support=false
for abi in $SUPPORTED_ABIS
do
  if [ "$ARCH" == "$abi" ]; then
    support=true
  fi
done
if [ "$support" == "false" ]; then
  abort "! Unsupported platform: $ARCH"
else
  ui_print "- Device platform: $ARCH"
fi

ui_print "- Extracting verify.sh"
unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >&2
if [ ! -f "$TMPDIR/verify.sh" ]; then
  ui_print "*********************************************************"
  ui_print "! Unable to extract verify.sh!"
  ui_print "! This zip may be corrupted, please try downloading again"
  abort    "*********************************************************"
fi
. "$TMPDIR/verify.sh"
extract "$ZIPFILE" 'customize.sh'  "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'verify.sh'     "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'sepolicy.rule' "$TMPDIR"

ui_print "- Extracting module files"
extract "$ZIPFILE" 'module.prop'     "$MODPATH"
extract "$ZIPFILE" 'post-fs-data.sh' "$MODPATH"
extract "$ZIPFILE" 'service.sh'      "$MODPATH"
extract "$ZIPFILE" 'cleanup.sh'      "$MODPATH"
echo $DESCRIPTION > $MODPATH/description
mv "$TMPDIR/sepolicy.rule" "$MODPATH"

HAS32BIT=false
[ -n "$(getprop ro.product.cpu.abilist32)" ] || [ -n "$(getprop ro.system.product.cpu.abilist32)" ] && HAS32BIT=true

if [ ! -d "$CONFIG_DIR" ]; then
  ui_print "- Creating configuration directory"
  mkdir -p "$CONFIG_DIR"
fi

mkdir "$MODPATH/zygisk"

if [ "$ARCH" = "x86" ] || [ "$ARCH" = "x64" ]; then
  if [ "$HAS32BIT" = true ]; then
    ui_print "- Extracting x86 libraries"
    extract "$ZIPFILE" "lib/x86/lib$SONAME.so" "$MODPATH/zygisk/" true
    mv "$MODPATH/zygisk/lib$SONAME.so" "$MODPATH/zygisk/x86.so"
  fi

  ui_print "- Extracting x64 libraries"
  extract "$ZIPFILE" "lib/x86_64/lib$SONAME.so" "$MODPATH/zygisk" true
  mv "$MODPATH/zygisk/lib$SONAME.so" "$MODPATH/zygisk/x86_64.so"
else
  if [ "$HAS32BIT" = true ]; then
    extract "$ZIPFILE" "lib/armeabi-v7a/lib$SONAME.so" "$MODPATH/zygisk" true
    mv "$MODPATH/zygisk/lib$SONAME.so" "$MODPATH/zygisk/armeabi-v7a.so"
  fi

  ui_print "- Extracting arm64 libraries"
  extract "$ZIPFILE" "lib/arm64-v8a/lib$SONAME.so" "$MODPATH/zygisk" true
  mv "$MODPATH/zygisk/lib$SONAME.so" "$MODPATH/zygisk/arm64-v8a.so"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644

mkdir -p /data/adb/nohello
if [ ! -e "/data/adb/nohello/umount" ]; then
  extract "$ZIPFILE" "umount" "/data/adb/nohello"
  touch "/data/adb/nohello/umount_persist"
fi
if [ ! -e "/data/adb/nohello/hide" ]; then
  extract "$ZIPFILE" "hide" "/data/adb/nohello"
fi
if [ ! -e "/data/adb/nohello/props.conf" ]; then
  extract "$ZIPFILE" "props.conf" "/data/adb/nohello"
fi
# 出厂备份(供 WebUI 恢复默认): 模块目录内保留原始 hide/props.conf
extract "$ZIPFILE" "hide" "$MODPATH"
extract "$ZIPFILE" "props.conf" "$MODPATH"
# KernelSU 模块 WebUI: webroot 必须位于模块根目录, 管理器自动设置权限/SELinux context
ui_print "- Extracting webroot"
unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH/" >&2

ui_print "- ${DESCRIPTION}"
