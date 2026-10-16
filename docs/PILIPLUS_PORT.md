# PiliPlus media-kit 差异审计与移植

## 固定来源与比较方式

- 用户 fork 起点：官方 main `c533e446755f51cf53c7e57aea873f2aa5355f81`。
- PiliPlus lock 实际使用的核心：[My-Responsitories/media-kit `73771ec38176be2d984a3049c28177bce23b54a0`](https://github.com/My-Responsitories/media-kit/commit/73771ec38176be2d984a3049c28177bce23b54a0)。
- 视频输出来源：[bggRGjQaUbCoE/media-kit `fd8421d21eade4d6d12de137fa7df902fec20292`](https://github.com/bggRGjQaUbCoE/media-kit/commit/fd8421d21eade4d6d12de137fa7df902fec20292)。
- 核心 fork 与当前官方 main 的共同祖先：`e41e50c8cfb370e69612b205dcfd9f3ca80690f5`。核心的 **50 个文件**按共同祖先到 fork 的差异审计；直接用旧 fork 覆盖 main 会同时撤销官方后来的热重启、内存泄漏、iOS 音频会话、Web 等修复，因此没有采用整体覆盖。
- fork 的 media-kit 代码为 MIT，移植文件保留原版权头。新增 mpv 头文件另有 ISC 许可，保留原声明。[Android 原生库及其独立依赖许可](../libs/android/media_kit_libs_android_video/NATIVE_LIBRARIES.md)单独记录。

## 核心功能矩阵

“已覆盖”表示当前官方代码已提供对应能力；“兼容移植”表示功能被保留，但使用现有 API 的增量扩展；“不照搬”均有具体原因，不表示未经审计。

| 功能与来源 | 处理 | 本分支行为与原因 |
| --- | --- | --- |
| 预初始化配置：`7fe1bffb` 的 `PlayerConfiguration.options` | 兼容移植 | 增加同名参数，在 `mpv_initialize` 前设置；同名值不再被默认属性覆盖。`idle`、`pause`、`keep-open` 仍由状态机管理；保留原有 muted、libass、bufferSize、async 和 iosManageAudioSession。视频控制器仍负责最终输出配置。 |
| 每个媒体的 `loadfile` options：`4d68e692`、`cc139b61` | 兼容移植 | 新增 `Media.nativeOptions`，保留原有任意类型 extras/httpHeaders；没有把业务 extras 重解释为 mpv 命令。逐项复制为不可变 Map，不按 URI 继承。只有使用 options 或 fd 的列表走逐项 loadfile，其他列表仍保留官方 loadlist 路径。 |
| mpv 0.38 / client API 2.3 的 loadfile index 参数 | 移植 | 用运行库 `mpv_client_api_version` 决定是否插入 `-1`；值按 UTF-8 字节长度转义，包含逗号、引号或中文仍为单个值，不使用 fork 原有的无转义 join。 |
| 原生 FFI ABI：`e65e85f7` | 移植并重生成 | `unsigned long` 使用 `ffi.UnsignedLong`，`size_t` 使用 `ffi.Size`；使用固定 mpv v0.41.0 头文件与 ffigen 23.0.0 生成，保留 Int8 字符指针，避免 fork 的 Uint8/Uf8 API 改写。[来源及命令](../media_kit/headers/README.md)。 |
| FFI leaf 快查询：`ec7aae29` | 移植 | 仅 client_api_version/client_id/client_name/error_string/event_name/get_time_ns/get_time_us 七个短查询为 leaf。没有把可能阻塞的命令、属性、等待、创建、销毁或渲染函数标记 leaf。没有宣称未经实测的性能收益。 |
| 同步/异步 load/unload hooks | 兼容移植 | hook 类型放宽为 `FutureOr<void>`，同步结果立即继续、Future 才 await；保留 mpv hook barrier。hook 内设置 VO/wid 由视频层直接同步 FFI，避免等待同一事件循环的 async reply。 |
| 每播放器操作锁：`2c11e341` | 移植 | NativePlayer 使用实例锁，多标签的不同播放器不再共享全局操作队列；同一播放器的操作继续串行。 |
| 异步 command/property：`ab7718c6` | 已覆盖 | 官方已有异步请求编号、reply completer、错误处理及 `configuration.async`；保留官方对 immediate failure 的清理，不再用 fork 的独立 `_requests` 重写。 |
| command 指针数组和截图内存：`e6c34810` | 兼容移植 | 数组精确分配 `参数数量 + 1` 个指针并保留末尾 NULL；修复官方截图按字符串长度分配指针数组的问题。command 错误文本只带命令名，不记录 signed URL、header 或 nativeOptions。 |
| 截图改为 `ui.Image`、移除 isolate/image 依赖：`e6c34810` | 不照搬 API 删改 | 保留 JPEG/PNG/BGRA bytes 与 includeLibassSubtitles、独立 isolate 编码能力，避免纯 Dart 核心被迫依赖 dart:ui。截图安全分配部分已单独移植，现有输出格式做真实原生验证。 |
| 原生事件桥：`9cb11e61`、`73771ec3` | 使用官方等效路径 | fork 用 C wakeup→Dart NativePort，再在 Dart 排空事件；官方 release 已使用 NativeCallable wakeup→Dart 排空，并有 execmem 受限 isolate 回退。保留官方 Flutter debug/hot-restart 的 isolate 路径、清旧 wakeup callback 后再 quit 修复。Android jar 含事件桥 .so，但不将该桥作为新的强依赖加载。 |
| dispose timeout、pending request 强制报错、zone 错误转发 | 不照搬整个状态机 | 保留官方 stop→release→取消回调→延迟 destroy 顺序及热重启引用清理。fork 的固定两秒超时后继续销毁、五秒后才完成 pending requests 不能直接证明释放已安全，不用其替代现有生命周期。 |
| `NativePlayer.create`、Player typedef、同步 handle/getProperty/setProperty | 不照搬 API 替换 | 保留既有 `Player()`、平台派发和初始化等待；ctx/mpv 和 `media_kit/ffi/ffi.dart` 当前已公开。视频仅需同步 FFI 的少量 barrier 调用，不需要移除公开 Future API。 |
| `replaceSingle`、默认 `prefetch-playlist=yes`：`cc139b61` | 暂不采用专用 shortcut/default | 既有 open/add/jump/remove 可表达媒体替换。fork shortcut 仅 assert 单项、直接修改内部列表，未带本项目 source generation/position/play intent 契约；没有直接改 BiliSail 的换源行为。预取通过新 options 可显式启用，避免默认额外网络下载。 |
| 移除缓存大小及磁盘缓存：`deac6b62` | 保留用户设置，提供 options | 保留 bufferSize 及既有配置契约，新 options 可覆盖 demuxer-max-bytes、cache-on-disk 等。缓存策略由应用按用途显式设置，不能从 fork 删除默认值推导为性能提升。 |
| 不可变 PlayerState→可变字段、删 copyWith；删音量/速度/pitch/device/bitrate/playlistMode streams | 不照搬 API 删减 | 保留不可变快照与现有细粒度 streams，避免破坏应用的状态观察和多标签会话契约。没有用删除能力来降低事件量。 |
| width/height streams→record size；subtitle List→新 Subtitle 类型 | 不照搬公开模型替换 | 保留 width/height/VideoParams 和双语字幕 List API；视频使用已有 VideoParams 做同样的旋转尺寸计算。新类型、空白 trim、0 代替 null 会改变既有语义。 |
| Track.selected、const URI 构造、移除 SubtitleTrack.data；AudioDevice 可选 description、hashCode 重写 | 保留已有模型/等效状态 | 已有 Track 状态、setAudioTrack/setSubtitleTrack 能表达当前选择；保留字幕 data、audio devices/bitrate 与原构造/equality。纯 const/hash/格式化调整不视为性能证据，不为它们改公开身份语义。 |
| video-out-params 代替 video-params、playlist node 全量监听 | 保留现有观察面 | 保留官方已有视频参数、playlist-playing-pos 与选中轨道逻辑；Android Surface 用新 lifecycle 与 generation 隔离完成所需工作。没有同时切换所有状态源。 |
| 删除 Media URI/引用缓存、memory、asset、content URI、临时文件工具 | 不照搬功能删除 | 保留 URI 归一化、媒体内存文件、Android fd 所有权及 finalizer 清理。新增 nativeOptions 不进入 URI cache，避免同 URL 的旧参数影响另一媒体。 |
| Android helper 缩减、静态 MPV、NativeLibrary switch 重写 | 保留官方能力 | 新 Android jar 实际导出 mpv_lavc_set_java_vm 与完整 helper/file-descriptor/asset symbols；当前官方 helper 可继续使用。没有删除文件目录、模拟器、API level、asset 和 fd 支持；库搜索 switch 为风格改写。 |
| Web/HLS/legacy API 与原测试删除 | 不照搬功能删除 | 保留 Web 平台、HLS、对象 URL、asset loader、legacy aliases 及测试。fork 为其应用专用 native 实现，不作为本 fork 跨平台能力缩减依据。 |
| 删除多个 Dart 依赖、改为 Flutter 依赖、提高 SDK 下限 | 保留生产依赖 | core 仍是纯 Dart API，不引入 Flutter 强依赖或降低当前官方依赖修复。ffigen 作为独立生成工具包固定版本和锁文件，不进入运行时依赖。 |

## 核心 50 文件逐项覆盖索引

下表路径均相对 `media_kit/`，覆盖 `git diff --name-status e41e50c8 73771ec3 -- media_kit` 的全部文件。源 fork 的新增/删除记录不等于本次也新增/删除。

| 文件 | 审计结果 |
| --- | --- |
| `assets/web/hls1.4.10.js` | 保留 Web/HLS，未随 fork 删除。 |
| `lib/ffi/src/utf16.dart` | 官方已为 final Opaque，已覆盖。 |
| `lib/ffi/src/utf8.dart` | 保留 Utf8 类型与当前官方编码实现；不改为裸 Uint8。 |
| `lib/generated/libmpv/bindings.dart` | 已移植 ABI、leaf，固定来源真实重生成。 |
| `lib/media_kit.dart` | 保留现有公开导出与 legacy/Web。 |
| `lib/src/legacy.dart` | 保留兼容别名。 |
| `lib/src/media_kit.dart` | 保留跨平台初始化派发与现有诊断。 |
| `lib/src/models/audio_device.dart` | 保留构造器兼容及音频设备 API。 |
| `lib/src/models/audio_params.dart` | hash 风格差异不照搬。 |
| `lib/src/models/media.dart` | 不采用 fork 替换模型文件；保留现有平台拆分。 |
| `lib/src/models/media/media.dart` | 保留条件导出。 |
| `lib/src/models/media/media_native.dart` | 保留 URI/memory/headers/缓存/finalizer，增 nativeOptions。 |
| `lib/src/models/media/media_web.dart` | 保留 Web，对齐接受 nativeOptions 并明确忽略。 |
| `lib/src/models/playable.dart` | 保留已有标记接口，不改 sealed/part 结构。 |
| `lib/src/models/player_state.dart` | 保留不可变快照、copyWith、原字段。 |
| `lib/src/models/player_stream.dart` | 保留原 streams，不删除音频状态。 |
| `lib/src/models/playlist.dart` | 保留结构、构造器和相等语义。 |
| `lib/src/models/subtitle.dart` | 不采用替换公开双字幕类型的新模型。 |
| `lib/src/models/track.dart` | 保留 data 字幕、URI 和已有选择模型。 |
| `lib/src/models/video_params.dart` | 保留结构与相等语义，视频层等效使用旋转参数。 |
| `lib/src/player/native/core/fallback_bitrate_handler.dart` | 保留音频码率回退功能。 |
| `lib/src/player/native/core/initializer.dart` | 保留官方 NativeCallable/execmem/debug 路由。 |
| `lib/src/player/native/core/initializer_isolate.dart` | 保留官方释放/wakeup 与热重启修复。 |
| `lib/src/player/native/core/initializer_native_event_loop.dart` | 不回引旧桥；官方已有 wakeup 等效路径。 |
| `lib/src/player/native/core/native_library.dart` | 保留官方库发现顺序，switch 只属风格差异。 |
| `lib/src/player/native/player/player.dart` | 保留跨平台条件导出。 |
| `lib/src/player/native/player/real.dart` | 增 options/loadfile/sync hook/实例锁/安全分配及脱敏；其余保持官方状态机。 |
| `lib/src/player/native/player/stub.dart` | 保留 Web 编译 stub。 |
| `lib/src/player/native/utils/android_asset_loader.dart` | 保留 Android 字幕字体与 asset。 |
| `lib/src/player/native/utils/android_content_uri_provider.dart` | 保留 content URI fd 所有权。 |
| `lib/src/player/native/utils/android_helper.dart` | 保留完整 helper；新 arm64 资产 symbols 已检查兼容。 |
| `lib/src/player/native/utils/asset_loader.dart` | 保留 Flutter asset 支持。 |
| `lib/src/player/native/utils/isolates.dart` | 保留耗时截图/playlist 查询的 isolate 隔离。 |
| `lib/src/player/native/utils/temp_file.dart` | 保留 memory/字幕/playlist 临时文件生命周期。 |
| `lib/src/player/platform_player.dart` | 兼容增加 options，保留其他公开配置/状态与初始化契约。 |
| `lib/src/player/player.dart` | 保留包装器，不改 typedef NativePlayer。 |
| `lib/src/player/web/player/player.dart` | 保留 Web 平台。 |
| `lib/src/player/web/player/real.dart` | 保留 Web 实现。 |
| `lib/src/player/web/player/stub.dart` | 保留 native 编译 stub。 |
| `lib/src/player/web/utils/asset_loader.dart` | 保留 Web asset。 |
| `lib/src/player/web/utils/duration.dart` | 保留 Web 时间转换。 |
| `lib/src/player/web/utils/hls.dart` | 保留 HLS。 |
| `pubspec.yaml` | 保留运行时依赖/平台/SDK；生成配置移到独立工具包。 |
| `test/common/sources_web.dart` | 保留 Web 测试源。 |
| `test/src/models/media/media_test.dart` | 保留原 URI/cache/memory 测试，新增独立 nativeOptions 测试。 |
| `test/src/models/media/player_state_test.dart` | 保留不可变 state 测试。 |
| `test/src/player/native/core/initializer_test.dart` | 保留现有初始化测试。 |
| `test/src/player/native/utils/asset_loader_test.dart` | 保留 asset 行为测试。 |
| `test/src/player/player_test.dart` | 保留现有整套行为测试，不用 fork 精简版覆盖。 |
| `test/src/player/web/utils/asset_loader_test.dart` | 保留 Web asset 测试。 |

## Android 原生资产与平台边界

Android video 库单独采用 fork 固定的 `20260906`，完整 SHA-256、源 commit、mpv/FFmpeg/NDK、API24、三个发布 ABI、16KiB ELF 对齐与许可见[原生库记录](../libs/android/media_kit_libs_android_video/NATIVE_LIBRARIES.md)。保持官方 AGP/compile SDK，不照搬 fork 对构建工具的降级；没有替换 Android audio 包。

aggregate `media_kit_libs_video` 保留当前官方结构，仅 Windows 约束允许已使用的 `^1.0.11`，以便应用锁文件继续固定已验证的平台资产。没有替换 Windows、iOS、macOS、Linux 原生发布，没有删除 Apple SPM/privacy manifests、Linux Wayland 修复或 Windows 既有渲染补丁。使用 v0.41.0 client 头文件不要求所有平台同步升级运行库：符号按需懒加载，loadfile 根据运行库 API 分支。

## Android Surface 移植

视频层保留官方跨平台 API，兼容采用视频 fork 的 `SurfaceTextureEntry` 与源生命周期流程：每次 on_load 创建新 Surface，on_unload 同步 `vo=null`/`wid=0` 后释放 JNI 与 Java 引用。视频尺寸更新经互斥锁及 generation 校验，不发送隐式 seek，不再使用 SurfaceProducer wid 回调与固定延迟回收。`force-window=no` 避免 idle 窗口尺寸；提前 attach 和有效参数后 attach 两种配置均保留。

每次源加载的输出 readiness 独立；创建、尺寸、属性失败会使其失败，等待者收到原异常。它确认尺寸已提交，沿用参数兜底语义，不证明真实首帧像素已经显示。dispose 幂等且 finally 按身份移除 Dart 缓存/释放 notifier；若 mpv detach 本身失败，则保留仍可能被 VO 引用的原生 Surface，不能越过屏障释放。

17 项生命周期测试覆盖顺序、同尺寸跨源、旧异步参数、重复尺寸、无 seek、释放幂等、错误 readiness 与失败清理。整个 media_kit_video Dart analyze 通过；Java 使用真实 Flutter Android-arm64、Android 36 与 annotation JAR 编译通过。尚未据此认定 Android 实机、硬解或性能通过。

Windows 源码内容未变，`.gitattributes` 固定 Windows 源文件 LF，保证 Git checkout 后下游七文件 SHA-256 校验仍可复现。Windows/macOS/iOS/Web 视频后端未随 Android 移植覆盖。

## 核心验证结果

- 2026-10-16 在独立临时目录复制 core 源码、去掉 workspace resolution 后执行 `dart pub get`，不更改应用依赖/锁文件。
- `dart analyze lib` 及三个新增测试文件通过。
- 三个新增测试文件共 9 项通过：options/extras/headers 隔离与不可变性、loadfile 两种 API 参数布局/UTF-8 转义/非法参数拒绝、预初始化 options 的实际读回、两个真实播放器互不阻塞、同步和异步 hooks 顺序与 unload、截图 PNG/BGRA byte API。
- 原生测试使用 BiliSail 现有 Windows Release `libmpv-2.dll`；通过是核心协议/FFI 的兼容性证据，不代表 Android 硬解/Surface、macOS/iOS 或硬件性能通过。
- 真实下载 arm64 jar 校验 SHA-256；ELF 检查确认 AArch64、API24/NDK r29、LOAD 对齐 0x4000、版本 `mpv v0.41.0-dirty` / FFmpeg `n9.0.1`，并确认旧 core 所需 helper/Java VM symbols 存在。其余 ABI 仅核对发布摘要，未加载运行。
- 未运行原先使用网络媒体 fixture 的完整 media-kit 测试；应用全套检查、Android 构建和设备验收由接入任务另外记录，不将静态分析或库版本信息视为实机验收。
