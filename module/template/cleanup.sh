# shellcheck disable=SC2016
sed -i "s/^description=.*/description=$(cat /data/adb/modules/zygisk_nohello/description)/" /data/adb/modules/zygisk_nohello/module.prop
