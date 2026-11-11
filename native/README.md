# BiliSail 原生媒体依赖

2026-11-12：Windows ANGLE 的生产者 pbuffer 不再调用 `eglBindTexImage`。
该调用将表面绑定用于采样，EGL 规定释放绑定前向它绘制的结果未定义；
原尺寸变更路径使上下文保持 current，因而在首次视频尺寸到达后触发此缺陷。
生产者继续绘制默认 framebuffer，Flutter 独立导入已完成的 D3D11 快照。
重建／释放表面前解除 current，上下文在 resize 时保留，不要求 surfaceless 支持。
`python native/test_windows_egl_surface.py` 编译实际生产方法，覆盖首次尺寸变更、
连续缩放、其他 current context 和释放；旧代码在 writable-surface 断言失败。
此为 EGL 契约回归，不能代替 Surface Pro X／Windows ARM64 的真实显示验收。
没有改变解码选择、GPU 输出默认值或原生 SDK。

2026-11-09 更新：Windows ARM64 SDK 改为已启用 OpenGL／ANGLE 的 0.41.0 LGPL
构建，替换旧归档中 `gl=disabled` 的 DLL；源码、构建材料、逐文件摘要和许可见
[ARM64 说明](../libs/windows/media_kit_libs_windows_video/windows/arm64/SOURCE.md)。
旧归档和 Vulkan loader 不再参与该目标。库插件和应用均在构建前检查实际 DLL 的
`gl`／`egl-angle` 编译能力；DLL 可加载或 PE 架构正确不能代替该检查。
视频初始化在选择渲染器后才注册纹理，失败的 GPU 状态不会进入软件输出；初始化
失败经平台通道返回，软件 stride 使用 `size_t`。原生回归入口增加初始化和软件
render API 检查。按本次授权只做离线检查，未构建应用或执行 ARM64 设备播放。

2026-11-07。Dart 核心、视频插件和各平台库插件以官方 `c533e446755f51cf53c7e57aea873f2aa5355f81` 为基线，由 `CKopoer/media-kit` 维护。mpv 源码由 [CKopoer/mpv](https://github.com/CKopoer/mpv) 维护。

## 固定资产

`assets.lock.json` 是原生资产来源、下载地址及 SHA-256 的审计清单。首批 `native-2026-11-07` 为上游二进制的逐字节镜像；Windows x64 后续由个人源码重建，其他平台继续使用原资产：

- Windows x64：个人 mpv `afd6da8843a07f463ba4c736a2ea636b1a92e23e` 的 LGPL SDK，修复 D3D11 解码表面的对齐填充区经 EGL/ANGLE 被插值采样产生边缘绿线。有填充时复用一张可见尺寸的 GPU 纹理，复制有效区域后导入；没有填充时保留原导入路径。硬解不改成 CPU copy-back，增加的 GPU 复制也不称为零复制。标准 OpenGL render API 和 ANGLE v1.0.1 保持不变。SDK 的 DLL、import library、四份头文件、许可及来源记录分别复核，不能混用 DXGI 扩展库。
- Windows ARM64：同一 mpv 提交的 LGPL aarch64 SDK，ANGLE 固定 `a96fca8d5ee2ca61e8de419e38cd577579281c9e` 的 D3D11/OpenGL 构建；原始归档逐字节镜像到 `native-windows-arm64-2026-11-07`。来源、构建材料和许可见 [ARM64 说明](../libs/windows/media_kit_libs_windows_video/windows/arm64/SOURCE.md)。库插件按目标选择归档、import library 和 DLL，解压内容逐项校验；mpv 的 ARM64 BCJ 压缩要求 7-Zip 23.01+。这不是个人重编译或设备性能验收。
- Android：My-Responsitories `20260906/default`，mpv 0.41.0、FFmpeg 9.0.1，API 24，arm64-v8a/armeabi-v7a/x86_64。个人 mpv `codex/android-0.41` 保留必需的 Java VM hook，来源为原构建仓库 `8e50ecc027cd2443a3ef9b1a87991d37f1acdc41` 的同名补丁。辅助库、事件桥和子依赖的原发布内容保持不变；官方 Dart 核心不再依赖旧事件桥。
- macOS/iOS：官方 libmpv-darwin-build v0.7.2，保留当前官方基线的 CocoaPods、SPM 校验和平台包装。两种分发方式均指向个人仓库镜像。
- Linux：库插件从个人 mpv 的固定 0.41.0 源码构建 `libmpv.so.2`，随 Flutter bundle 分发；FFmpeg、图形驱动等依赖继续来自发行版。源码归档完整 SHA-256、构建入口和许可均保留，核心优先打开随应用分发的库；已存在但损坏时明确失败，不静默改用系统库。Linux 本机播放与打包仍需验证。

精确构建分支提交见 `builds.lock.json`。Windows x64 使用 [mpv 固定工作流](https://github.com/CKopoer/mpv/blob/afd6da8843a07f463ba4c736a2ea636b1a92e23e/.github/workflows/bilisail-windows.yml) 和固定 BtbN LGPL 工具链容器；FFmpeg 保持原 DLL 的 `615b07170e30d79ad5906418ea49f81c3cbd8457` 源码，其他静态依赖来自该容器，并不声称与旧 SDK 二进制一致。`native/package_windows_sdk.py` 在 CI 归档上补充固定源依赖的原始许可文本，记录原归档摘要并逐项断言 DLL、import library、头文件和 JAR 内容不变；最终 ZIP 摘要另行固定。SDK 的 `provenance/` 保留源提交、FFmpeg 配置、Meson 构建选项、依赖版本、构建脚本和容器摘要，随应用安装到 `data/licenses/mpv/`。mpv 为 LGPL-2.1-or-later，本次 FFmpeg 配置为 LGPL-3.0-or-later；各静态子依赖继续适用各自许可。

Windows ARM64 的历史构建材料为 `CKopoer/mpv-winbuild`；Android、Apple 分别为 `CKopoer/libmpv-android-video-build`、`CKopoer/libmpv-darwin-build`。各原始发布的构建记录和子依赖仍是首批镜像的来源，不能将修改后的个人构建脚本倒推为旧二进制的构建记录。ARM64 未包含此次 EGL 边缘修复。

## 获取与验证

```sh
python native/mirror_assets.py --cache /path/to/cache
# 仅维护者建立首批镜像时显式使用原来源：
python native/mirror_assets.py --cache /path/to/cache --origin
```

Windows 的生产下载、预取与安装共用库插件的 `windows/native-assets.cmake`。已校验资产解压到其归档 SHA 命名的独立目录；失败中止，不回退旧 DLL。Android 下载和缓存使用完整 SHA-256；Apple 保留原始 tar/zip SHA-256。

## 修复边界

- `MPV_FORMAT_FLAG` 按 C int 读写，分配在 finally 中释放。
- Android 保留源代次、load/unload 屏障、同步 VO/wid 操作、无隐式 seek 的尺寸更新。公开 frame-consumed 回调提供有效尺寸后的帧信号，不覆盖 Flutter 的内部帧监听。尺寸就绪与帧消费分别等待。
- Windows 的平台消息使用每个插件实例自己的 message-only HWND，替代官方单全局实例/WndProc 接管；保留异步 Dispose 完成确认、队列合并、视口上限、稳定纹理 ID 和 descriptor COM 引用保留。
- ANGLE 同设备可直接交付；不同设备保留每个新视频帧一次的 GPU 复制，不宣称完整链路零复制。

MIT 仅覆盖 media-kit 包装源码；mpv、FFmpeg、ANGLE 和各子依赖保持各自许可。发布保留来源、构建材料与许可，镜像不改变许可范围。Windows SDK 保留 LGPL 文本，Android 的逐项许可与原始构建材料见库插件 `NATIVE_LIBRARIES.md`。源码变更和镜像不等于新的性能验收。

## 本轮验证

Windows x64 边缘修复：固定 [SDK 构建 42387266918](https://github.com/CKopoer/mpv/actions/runs/42387266918) 通过，并明确编译 `hwdec_d3d11egl.c`、断言 ANGLE 和 D3D 硬解均启用。AMD Radeon 核显（1002:164e，驱动 32.0.21042.62）200 次像素抓图通过，包含 AV1／HEVC 8／10-bit、H.264、横竖屏、对齐控制、缩放、旋转、裁剪、色度滤波、彩色边条和 4K AV1。NVIDIA RTX 4070 Ti SUPER 另有 96 次通过。直接路径实读仍为 `d3d11va`，逐侧 RGB 均值与软件参考差不超过 2/255。同编译器和依赖、仅还原旧 mapper 的 96 次控制抓图再次出现 AV1 绿线，支持将修复归因于映射边界。合成 HEVC 未复现用户原始故障；奇数尺寸、原始 HEVC 文件、ARM64 和性能／能耗未验收。应用级回归另由 BiliSail 记录。

2026-11-07：核心扩展／库选择用例 12 项、视频生命周期／配置用例 22 项、核心与视频生产源码静态分析通过。Windows 已通过真实 D3D11/ANGLE 共享／复制、稳定 texture ID／descriptor 生命周期和 9 项释放／队列回归。Linux Ubuntu 24.04 的个人源码构建、动态依赖及 client ABI 检查通过：[run 42329760177](https://github.com/CKopoer/media-kit/actions/runs/42329760177)。Linux 本机图形播放、Flutter 打包和 Apple 设备验收不能由该构建推导。
