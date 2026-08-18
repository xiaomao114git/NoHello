<h2 align="center">Zygisk NoHello</h2>
<p align="center">
  A Zygisk module to hide root.
  </br>
  </br>
  <a href="README_zh-CN.md">中文文档 (简体中文)</a>
  </br>
  </br>
  <a href="https://github.com/MhmRdd/NoHello/actions/workflows/build.yml">
    <img src="https://github.com/MhmRdd/Il2Dump/actions/workflows/build.yml/badge.svg?branch=master" alt="Android CI status">
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  </a>
  </br>
  <a href="https://github.com/MhmRdd/NoHello/issues">Report Bug</a>
    ·
  <a href="https://github.com/MhmRdd/NoHello/issues">Request Feature</a>
    ·
  <a href="https://github.com/MhmRdd/NoHello/releases">Latest Release</a>
</p>

> [!CAUTION]
> **⚠️ v0.0.8 已撤回 (2026-08-18) — 请勿安装 / 请立即卸载**
>
> The v0.0.8 release (Hide Rule System / device spoofing / WebUI branch) was found to
> **break the emulated-storage (sdcard) FUSE daemon** on at least one device: after
> installing the module and rebooting, vold repeatedly fails to start the sdcard FUSE
> daemon (`Failed to start FUSE`, exit 234) and `/sdcard` becomes inaccessible
> (`Transport endpoint is not connected`). Underlying data in `/data/media/0` is **not**
> lost, but the storage mount fails until the module is removed and the device rebooted.
>
> The release and tag have been deleted. **Do not install v0.0.8.** If you already
> installed it: remove the module (`rm -rf /data/adb/modules/zygisk_nohello
> /data/adb/nohello /data/adb/post-fs-data.d/.nohello_cleanup.sh`) and reboot — storage
> recovers fully, data intact.
>
> Root cause is under investigation. The v0.0.7 upstream line remains unaffected.
>
> ---
> **v0.0.8 已撤回 (2026-08-18) — 请勿安装 / 请立即卸载**
>
> v0.0.8 版本（Hide Rule System / 设备模拟 / WebUI 分支）被发现会在至少一台设备上
> **破坏模拟存储 (sdcard) 的 FUSE 守护进程**：安装模块并重启后，vold 反复无法启动
> sdcard FUSE daemon（`Failed to start FUSE`，exit 234），`/sdcard` 不可访问
> （`Transport endpoint is not connected`）。底层数据在 `/data/media/0` 中**不会丢失**，
> 但存储挂载会一直失败，直到移除模块并重启设备。
>
> 该 release 与 tag 已删除。**请勿安装 v0.0.8。** 若已安装：移除模块
> （`rm -rf /data/adb/modules/zygisk_nohello /data/adb/nohello
> /data/adb/post-fs-data.d/.nohello_cleanup.sh`）并重启——存储会完全恢复，数据完好。
>
> 根因调查中。上游 v0.0.7 不受影响。

> [!NOTE]
> This module currently focuses to hide root & zygisk from apps.
> Updates will gradually implements changes and fixes.

## About The Project

Using the **release** build is recommended over the debug build. Only use debug builds if you are going to make a bug report.

## Usage

### KernelSU & KernelSU Next users:
1. Install ZygiskNext or ReZygisk.
2. Make sure the unmount setting is enabled for the target app in the Manager.
3. Disable Umount modules in settings for Manager (if exists).
4. Disable `Enforce DenyList` in ZygiskNext/ReZygisk settings if there is one.

### APatch users:
1. Install ZygiskNext or ReZygisk.
2. Make sure the unmount setting is enabled for the target app in the Manager.
3. Disable `Enforce DenyList` in ZygiskNext/ReZygisk settings if there is one.

### Magisk users:
1. Update your Magisk to 28.0 or newer for better hiding capabilities. (optional)
2. Turn on Zygisk in Magisk settings (unrecommended) or install ZygiskNext/ReZygisk.
3. Turn off `Enforce DenyList` in Magisk settings.
4. Disable `Enforce DenyList` in ZygiskNext/ReZygisk settings if there is one. (if installed)
5. Add the target app to the deny list unless you're using a Magisk fork with a white list instead.

## Whitelisting (0.0.4+)
You can set the working mode to **whitelist** (instead of the default **blacklist**) by creating an empty regular file `/data/adb/nohello/whitelist`.
>[!WARNING]
> Using **Mount Rule System** with **whitelist**, can cause severe overheating & performance issues, due to how MRS being evaluated each time a process spawns.

This can be solved if you make NoHello evaluates Mount Rule System per boot/companion instance, by creating an empty regular file `/data/adb/nohello/umount_persist`/`data/adb/nohello/umount_persists`

## Hide Rule System

**Since version 0.0.8**, NoHello introduces **Hide Rule System** to counter anti-cheat detections that probe *child paths* of well-known directories (e.g. `/sys/module/module_00`, `/data/local/tmp/.studio`, `/dev/pts/0`) for root frameworks, debuggers and cheat tooling.

For each configured path, NoHello covers the directory with an **empty tmpfs** inside the target app's mount namespace, so child-path probes fail (ENOENT for sysfs paths; EACCES for `/data/local/tmp` — same as a clean device) while the directory itself still resolves — avoiding "directory vanished" heuristics.

> [!WARNING]
> **Detection-surface tradeoff**: covering a directory with tmpfs adds non-standard mount entries to the app's `/proc/self/mounts` (e.g. `tmpfs /sys/module`), changes `st_dev` vs its parent, and makes the covered directory empty (a real device's `/sys/module` always has entries). In observed anti-cheat runtime traces (access/stat child-path probing) this is a net win, but any anti-cheat that parses mountinfo or cross-checks `st_dev` will see the cover. This is the fundamental limitation of userland-only hiding (the reason susfs exists); test on the target app before relying on it.

> [!IMPORTANT]
> **Do NOT add `/dev/pts` to the hide file** — covering the devpts mount point breaks `openpty()`/pts allocation in apps. PTY probes (`stat /dev/pts/0..9`) are best handled by keeping the environment free of active root shells on the target device.

### Default coverage (built-in)

| Path | Counter |
|------|---------|
| `/sys/module` | KernelSU / kernel-module enumeration (`module_00..99`, `rwProcMem`, ...) |

> `/data/local/tmp` is intentionally **not** covered by default: `untrusted_app` cannot traverse `/data/local` anyway (EACCES either way), so the cover adds a mounts-visible entry with no benefit. `/sys/class/kgsl` is also opt-in — covering it can break the game's own GPU monitoring (Unreal reads kgsl nodes for perf/thermal). Add them via the hide file only if needed.

### Customization

Additional paths can be added via `/data/adb/nohello/hide`, one per line (`#` comments allowed), optionally with a per-line SELinux context:

```
# cover PTY detection
/dev/pts

# with explicit context
/sys/module context=u:object_r:sysfs:s0
```

Mounting is best-effort: if the `context=` mount fails, NoHello retries with a plain tmpfs.

## Device Spoofing (property service)

**Since version 0.0.8**, NoHello can impersonate a donor device (e.g. a non-rooted Huawei phone) to anti-cheats that fingerprint the device.

### How it works

A single channel driven by `props.conf`:

| Channel | Mechanism | Scope | Default |
|---------|-----------|-------|---------|
| **Property service** | `resetprop` applies each `key=value` to the global property service (`__system_property_get` / `getprop`) | System-wide | Off, opt-in via `/data/adb/nohello/props_enabled` |

The **editable** config lives at `/data/adb/nohello/props.conf` (managed by the WebUI); the module directory copy (`$MODDIR/props.conf`) is only the factory-default fallback read at boot. `service.sh` re-applies on every boot while `props_enabled` exists.

> [!IMPORTANT]
> Earlier designs also bind-mounted a spoofed build.prop / cpuinfo into the app's mount namespace. That approach was **dropped**: those mounts are visible in the app's `/proc/self/mounts` with `/data/adb/...` sources — exactly the fingerprint this module's own unmount logic treats as suspicious — and observed anti-cheat traces never read build.prop files. Property-service spoofing via resetprop is the only channel.

### What to spoof (and what NOT to)

| Do spoof | Don't spoof | Why |
|----------|-------------|-----|
| `ro.product.brand/model/device/name/manufacturer` | `ro.hardware` / `ro.board.platform` | SoC props contradict `GL_RENDERER` (Adreno), `/sys/devices/soc0`, `/proc/device-tree` — a stronger red flag than not spoofing |
| `ro.build.fingerprint` (main, release-keys) | `ro.build.version.sdk` / `release` | `Build.VERSION.SDK_INT/RELEASE` are compile-time constants in the framework; resetprop can't change them → `getprop` vs `Build.*` contradiction |
| `ro.debuggable` / `ro.secure` / `ro.adb.secure` | sub-fingerprints (`ro.system.build.*`, `ro.vendor.build.*`) | Donor test firmware carries `dev-keys`/`eng.root` — the classic root fingerprint; the main fingerprint is already release-keys |

The shipped default profile is a **Huawei WKG-AN00 (EMUI 13 / HarmonyOS 3, Android 10)** — already cleaned per the above rules.

### Collecting a donor device profile

On the donor (non-rooted) phone, dump all properties:

```sh
adb shell getprop > donor_getprop.txt
```

Then convert the interesting `ro.*` keys into `props.conf` (`key=value` lines, `#` comments allowed) and push it to `/data/adb/nohello/props.conf`, applying the cleaning rules above.

### WebUI

KernelSU (and KernelSU Next / forks) show the module's built-in WebUI in the manager — open the NoHello module page and tap the settings icon. It provides:

- 📱 **Device spoofing**: toggle the property-service channel, edit `props.conf`, save & re-apply, restore factory defaults
- 🛡 **Hide paths**: view/edit `/data/adb/nohello/hide`
- ⚙️ **Rules & status**: unmount count, whitelist / umount_persist toggles, Mount Rule System editor, uninstall config

> The WebUI uses the official `kernelsu` JS library (`exec()` API) and lives in `webroot/` per the [KernelSU module WebUI spec](https://kernelsu.org/zh_CN/guide/module-webui.html). File writes are base64-encoded through the shell to avoid injection.

## Mount Rule System

**Since version 0.0.5**, NoHello introduces **Mount Rule System**.</br>
This allows users to define **rules** that control how mount points are evaluated for **auto-unmounting**.</br>
Rules are fully configurable and match based on mount point properties like root path, mount path, filesystem type, or source.</br>
**MountRules** can be customized via `/data/adb/nohello/umount`.

### Rule Format

A rule is made up of **sections**, each consisting of a **keyword**, followed by a list of values enclosed in `{}`:

```
<keyword> { <value1> <value2> ... }
```

Valid **keywords** are:

| Keyword  | Matches against         | Supports Wildcards                                       | Description |
|----------|-------------------------|----------------------------------------------------------|-------------|
| `root`   | Root path of the mount  | Yes (`*`, escape by `\*`)                                | Root of the mount in `/proc/self/mountinfo` |
| `point`  | Mount point path        | Yes (`*`, escape by `\*` only at the beginning & ending) | Where the filesystem is mounted |
| `fs`     | Filesystem type         | No                                                       | Matches exact filesystem type, e.g. `ext4`, `erofs`, etc |
| `source` | Source device or file   | Yes (`*`, escape by `\*`)                                | e.g., `/dev/block/xyz`, `magisk`, etc |

### Example Rules

#### Match all `tmpfs` filesystems mounted under `/data/adb`:
```
fs { "tmpfs" } point { "/data/adb/*" }
```

#### Match anything mounted from a `tmpfs` source:
```
source { "tmpfs" }
```

#### Match a specific mount path exactly:
```
point { "/mnt/specific/path" }
```

#### Match any source ending with `data`:
```
source { "*data" }
```

#### Match root path starting with `/acct` and fs type `cgroup`:
```
root { "/acct*" } fs { "cgroup" }
```

### Quoting Values

You can quote values with **single or double quotes**:

```
point { "/mnt/with space" '/custom\ path' }
```

You may escape characters like `*`, `{`, `}`, and `"` using backslashes (`\`) if needed.

### Wildcard Behavior

Wildcards are supported only in `root`, `point`, and `source`. The supported patterns are:

- `*value*`: matches substring anywhere
- `*value`: matches suffix
- `value*`: matches prefix
- Exact match without `*`


>[!NOTE]
> - You can define **multiple rules**, each as a separate line.
> - All rules are evaluated independently.
> - Matching is case-sensitive and optimized for performance.


## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/FeatureName`)
3. Commit your Changes (`git commit -m 'Add some FeatureName'`)
4. Push to the Branch (`git push origin feature/FeatureName`)
5. Open a Pull Request.


## Acknowledgement

- [Zygisk Assistant](https://github.com/snake-4/Zygisk-Assistant)

## LICENSE

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

