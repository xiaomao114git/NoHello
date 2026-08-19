<h2 align="center">Zygisk NoHello</h2>
<p align="center">
  一个用于向 App 隐藏 root 的 Zygisk 模块。
  </br>
  </br>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  </a>
</p>

> [!NOTE]
> 本模块目前专注于向 App 隐藏 root 与 Zygisk 痕迹。
> 后续更新会逐步补充更多功能与修复。

> [!TIP]
> **v0.0.8 问题已修复 (2026-08-19)**
>
> v0.0.8 中的 FUSE/sdcard 破坏及其他 bug 已全部修复：
>
> - **FUSE/sdcard 破坏**：挂载规则分两行且 source 用逗号分隔，导致系统关键分区被
>   卸载。已合并为单行规则、source 用空格分隔、并限制 `point` 范围。
> - **开机卡死**：`resetprop -w sys.boot_completed 0` 在 Android 16 上触发 init
>   SIGABRT。改用等待循环，阻塞至 `boot_completed=1`。
> - **空指针崩溃**：`anomaly()` 按值接收 `unique_ptr<FileDescriptorInfo>` 夺走所有权，
>   导致清理列表中悬挂指针。改为裸指针传参。
> - **fork 失败静默**：`forkcall` 返回 -1（fork 失败或子进程被信号杀死）未处理，
>   root 隐藏静默失效。现在 -1 被当作 FAILURE 处理。
> - **数组越界**：`MountInfo` 构造函数在 `-` 分隔符后未检查索引边界。
>   已增加边界校验。
> - **挂载传播泄漏**：tmpfs 挂载缺少 `MS_PRIVATE` 标志。已补上。
> - **Shell 引号问题**：`check_reset_prop` 变量未加引号；`cleanup.sh` sed 用 `/` 做
>   分隔符（描述中的 `/` 会破坏命令）；`customize.sh` HAS32BIT 用未加引号的命令替换。
>   全部修复。
> - **残留文件**：`no_dirtyro_ar` 标记开机时未清理。已增加清理逻辑。

## 关于本项目

推荐使用 **release** 构建（而非 debug 构建）。debug 构建仅用于提交 bug 报告。

## 使用方法

### KernelSU / KernelSU Next 用户：
1. 安装 ZygiskNext 或 ReZygisk。
2. 在管理器中对目标 App 启用卸载（unmount）设置。
3. 如存在，关闭管理器设置中的 Umount modules。
4. 如存在，关闭 ZygiskNext/ReZygisk 设置中的 `Enforce DenyList`。

### APatch 用户：
1. 安装 ZygiskNext 或 ReZygisk。
2. 在管理器中对目标 App 启用卸载（unmount）设置。
3. 如存在，关闭 ZygiskNext/ReZygisk 设置中的 `Enforce DenyList`。

### Magisk 用户：
1. 建议将 Magisk 更新到 28.0 或更高版本（可选）。
2. 在 Magisk 设置中开启 Zygisk（不推荐）或安装 ZygiskNext/ReZygisk。
3. 关闭 Magisk 设置中的 `Enforce DenyList`。
4. 如安装了 ZygiskNext/ReZygisk，也关闭其 `Enforce DenyList`。
5. 将目标 App 加入 deny list（除非你用的是白名单机制的 Magisk 分支）。

## 白名单模式（0.0.4+）

创建空文件 `/data/adb/nohello/whitelist` 可切换为**白名单**工作模式（默认是黑名单）。

>[!WARNING]
> 白名单模式 + **Mount Rule System** 可能导致严重发热与性能问题——MRS 在每次进程创建时都会被评估。

可通过创建空文件 `/data/adb/nohello/umount_persist`（或 `umount_persists`）让 NoHello 仅在每次开机/companion 实例中评估一次 Mount Rule System 来解决。

## Hide Rule System（隐藏规则系统）

**自 0.0.8 起**，NoHello 引入 **Hide Rule System**，用于对抗反作弊对知名目录**子路径**的探测（如 `/sys/module/module_00`、`/data/local/tmp/.studio`、`/dev/pts/0`）——这类探测用于发现 root 框架、调试器与作弊工具。

对每个配置的路径，NoHello 会在目标 App 的挂载命名空间内用**空 tmpfs** 覆盖该目录，使子路径探测全部失败（sysfs 路径返回 ENOENT；`/data/local/tmp` 返回 EACCES——与干净设备一致），而目录本身仍可解析，避免触发"目录消失"启发式。

### 默认覆盖（内置）

| 路径 | 对抗的检测 |
|------|-----------|
| `/sys/module` | 内核模块枚举（`module_00..99`、`rwProcMem` 等，KernelSU / kp-next 痕迹） |

> `/data/local/tmp` **默认不覆盖**：`untrusted_app` 本就无法穿越 `/data/local`（两边都是 EACCES），覆盖只会多一条可见挂载、没有收益。`/sys/class/kgsl` 也默认不启用——覆盖它可能打断游戏自身的 GPU 监控（Unreal 会读 kgsl 节点做性能/温控）。如需请自行加入 hide 文件。

### 自定义

可通过 `/data/adb/nohello/hide` 追加路径，每行一个（支持 `#` 注释），可选每行 SELinux context：

```
# 示例：覆盖 GPU 节点（仅在模拟联发科捐献机时使用）
/sys/class/kgsl

# 带显式 context
/sys/module context=u:object_r:sysfs:s0
```

挂载为尽力而为：若 `context=` 挂载失败，会回退到按路径的安全 context（sysfs 路径→`sysfs`，data 路径→`shell_data_file`），绝不会用裸 tmpfs（裸 tmpfs 的 label 会让子路径探测变成 EACCES 而非 ENOENT）。

> [!WARNING]
> **检测面权衡**：用 tmpfs 覆盖目录会在 App 的 `/proc/self/mounts` 中增加非标准挂载条目（如 `tmpfs /sys/module`）、改变相对父目录的 `st_dev`、并使被覆盖目录为空（真机的 `/sys/module` 永远有内容）。在已观测的反作弊运行时 trace（access/stat 子路径探测）中这是净收益，但任何解析 mountinfo 或交叉检查 `st_dev` 的反作弊都会看到覆盖。这是纯用户态隐藏的根本局限（也是 susfs 存在的原因）；依赖前请在目标 App 上实测。

> [!IMPORTANT]
> **不要把 `/dev/pts` 加入 hide 文件**——覆盖 devpts 挂载点会破坏 App 的 `openpty()`/pts 分配。PTY 探测（`stat /dev/pts/0..9`）最好的应对是保持目标设备环境干净、不挂活跃的 root shell。

## 设备模拟（属性服务通道）

**自 0.0.8 起**，NoHello 可以向做设备指纹识别的反作弊伪装成一台"捐献机"（例如一台未 root 的华为手机）。

### 工作原理

单一通道，由 `props.conf` 驱动：

| 通道 | 机制 | 作用域 | 默认 |
|------|------|--------|------|
| **属性服务** | `resetprop` 将每条 `key=value` 写入全局属性服务（`__system_property_get` / `getprop` 均受影响） | 全局 | 关闭，需通过 `/data/adb/nohello/props_enabled` 开启 |

**可编辑**配置位于 `/data/adb/nohello/props.conf`（由 WebUI 管理）；模块目录内的副本（`$MODDIR/props.conf`）只是开机读取的出厂默认回退。`props_enabled` 存在期间 `service.sh` 每次开机都会重新应用。

> [!IMPORTANT]
> 早期设计还曾把伪造的 build.prop / cpuinfo **bind-mount** 进 App 的挂载命名空间。该方案**已放弃**：这些挂载会以 `/data/adb/...` 为 source 出现在 App 的 `/proc/self/mounts` 中——这恰恰是本模块自身 unmount 逻辑判定为可疑的指纹——而且观测到的反作弊 trace 从不读取 build.prop 文件。属性服务模拟（resetprop）是唯一通道。

### 该模拟什么（以及千万不要模拟什么）

| 可模拟 | 不可模拟 | 原因 |
|--------|---------|------|
| `ro.product.brand/model/device/name/manufacturer` | `ro.hardware` / `ro.board.platform` | SoC 属性与 `GL_RENDERER`（Adreno）、`/sys/devices/soc0`、`/proc/device-tree` 矛盾——比不模拟更强的红旗 |
| `ro.build.fingerprint`（主指纹，release-keys） | `ro.build.version.sdk` / `release` | `Build.VERSION.SDK_INT/RELEASE` 是框架内编译期常量，resetprop 改不动 → `getprop` 与 `Build.*` 自相矛盾 |
| `ro.debuggable` / `ro.secure` / `ro.adb.secure` | 子指纹（`ro.system.build.*`、`ro.vendor.build.*`） | 捐献机测试版固件带 `dev-keys`/`eng.root`——最标准的 root 指纹；主指纹已是 release-keys |

随包默认配置为**华为 WKG-AN00（EMUI 13 / 鸿蒙 3，Android 10）**——已按上述规则清洗。

### 采集捐献机配置

在捐献机（未 root 的手机）上导出全部属性：

```sh
adb shell getprop > donor_getprop.txt
```

然后将需要的 `ro.*` 键整理成 `props.conf`（每行 `key=value`，支持 `#` 注释），推送到 `/data/adb/nohello/props.conf`，并套用上面的清洗规则。

### WebUI

KernelSU（及 KernelSU Next / 分支）会在管理器中显示模块内置 WebUI——打开 NoHello 模块页并点击设置图标。提供：

- 📱 **设备模拟**：切换属性服务通道、编辑 `props.conf`、保存并重新应用、恢复出厂默认
- 🛡 **隐藏路径**：查看/编辑 `/data/adb/nohello/hide`
- ⚙️ **规则与状态**：卸载计数、白名单 / umount_persist 开关、Mount Rule System 编辑器、卸载配置

> WebUI 使用官方 `kernelsu` JS 库（`exec()` API），位于 `webroot/`，遵循 [KernelSU 模块 WebUI 规范](https://kernelsu.org/zh_CN/guide/module-webui.html)。文件写入经 base64 编码通过 shell 执行，避免注入。

## Mount Rule System（挂载规则系统）

**自 0.0.5 起**，NoHello 引入 **Mount Rule System**。</br>
允许用户定义**规则**来控制挂载点如何被评估并**自动卸载**。</br>
规则完全可配置，基于挂载点的根路径、挂载路径、文件系统类型或 source 进行匹配。</br>
**MountRules** 可通过 `/data/adb/nohello/umount` 自定义。

### 规则格式

规则由多个**段**组成，每段 = 一个**关键字** + 花括号包裹的值列表：

```
<keyword> { <value1> <value2> ... }
```

有效**关键字**：

| 关键字 | 匹配对象 | 支持通配符 | 说明 |
|--------|---------|-----------|------|
| `root` | 挂载的根路径 | 是（`*`，可用 `\*` 转义） | `/proc/self/mountinfo` 中挂载的根 |
| `point` | 挂载点路径 | 是（`*`，仅开头与结尾可转义） | 文件系统挂载的位置 |
| `fs` | 文件系统类型 | 否 | 精确匹配，如 `ext4`、`erofs` 等 |
| `source` | 源设备或文件 | 是（`*`，可用 `\*` 转义） | 如 `/dev/block/xyz`、`magisk` 等 |

### 规则示例

#### 匹配挂载在 `/data/adb` 下的所有 `tmpfs`：
```
fs { "tmpfs" } point { "/data/adb/*" }
```

#### 匹配任何 source 为 `tmpfs` 的挂载：
```
source { "tmpfs" }
```

#### 精确匹配某个挂载路径：
```
point { "/mnt/specific/path" }
```

#### 匹配任何以 `data` 结尾的 source：
```
source { "*data" }
```

#### 匹配根路径以 `/acct` 开头且 fs 为 `cgroup`：
```
root { "/acct*" } fs { "cgroup" }
```

### 值引用

可以用**单引号或双引号**引用值：

```
point { "/mnt/with space" '/custom\ path' }
```

如需要可用反斜杠（`\`）转义 `*`、`{`、`}`、`"` 等字符。

### 通配符行为

仅在 `root`、`point`、`source` 中支持通配符：

- `*value*`：任意位置子串匹配
- `*value`：后缀匹配
- `value*`：前缀匹配
- 无 `*`：精确匹配

> [!NOTE]
> - 可定义**多条规则**，每条单独一行。
> - 所有规则独立评估。
> - 匹配区分大小写，并为性能做了优化。

## 贡献

欢迎一切贡献！如果你有改进建议，请 fork 本仓库并提交 PR，也可以直接提 issue。别忘了点个 star！感谢！

## 致谢

- [Zygisk Assistant](https://github.com/snake-4/Zygisk-Assistant)

## 许可证

本项目基于 [MIT License](https://opensource.org/licenses/MIT) 发布。
