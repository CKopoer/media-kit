# Android 原生库来源

本包采用 PiliPlus 的 media-kit 核心 fork
[`73771ec38176be2d984a3049c28177bce23b54a0`](https://github.com/My-Responsitories/media-kit/commit/73771ec38176be2d984a3049c28177bce23b54a0)
实际固定的 Android `default` 构建；保留本仓库的 AGP、compile SDK 和其余平台的依赖配置。

- 发布：[20260906](https://github.com/My-Responsitories/libmpv-android-video-build/releases/tag/20260906)。
- 构建仓库 tag 对应提交：`8e50ecc027cd2443a3ef9b1a87991d37f1acdc41`。
- [依赖声明](https://github.com/My-Responsitories/libmpv-android-video-build/blob/8e50ecc027cd2443a3ef9b1a87991d37f1acdc41/buildscripts/include/depinfo.sh)：mpv `0.41.0`、FFmpeg `9.0.1`、libplacebo `7.360.1`、NDK `29.0.14206865`。
- [构建配置](https://github.com/My-Responsitories/libmpv-android-video-build/blob/8e50ecc027cd2443a3ef9b1a87991d37f1acdc41/buildscripts/build.sh)：Android API 24；链接器最大页大小 `16384`。
- 发布 ABI 为 `arm64-v8a`、`armeabi-v7a`、`x86_64`；此发布没有 `x86` 资产，不能声明支持该 ABI。最低 Android API 调整为 24。
- [下载脚本](https://github.com/My-Responsitories/libmpv-android-video-build/blob/8e50ecc027cd2443a3ef9b1a87991d37f1acdc41/buildscripts/include/download-deps.sh)按 mpv/FFmpeg 等版本 tag 拉取源码，但 Android helper 和原生事件桥按分支拉取，因此不能仅凭构建脚本推导逐字节可复现；分发资产由下述完整 SHA-256 固定。

| 资产 | SHA-256 |
| --- | --- |
| `default-arm64-v8a.jar` | `98df6410375cc7a4be7e6eff56f9ccd88fa52678973cc23bcf7e934ab8c8682d` |
| `default-armeabi-v7a.jar` | `75ba2199848cd6224817320ddfabb7d7ea48fb4cfb1721b0090043d5a8a38602` |
| `default-x86_64.jar` | `1caa6198de22808bd7f10fcff2923f5eb174cc42ef24569aeafb98c6597457a4` |

这些值与 fork Gradle 配置及 GitHub Release API 的资产摘要一致；Gradle 在下载后及复用缓存前校验 SHA-256。

2026-10-16 已下载并校验 arm64 资产。其 `libmpv.so` ELF 为 AArch64，Android ident 标明 API 24 / NDK r29，所有 LOAD 段对齐为 `0x4000`；库内版本字符串为 `mpv v0.41.0-dirty`、FFmpeg `n9.0.1`（mpv 构建包含仓库中的 Java VM 补丁）。arm32/x86_64 的摘要已对照发布 API，尚未在本机加载运行。

## 许可

构建仓库的 [`LICENSE`](https://github.com/My-Responsitories/libmpv-android-video-build/blob/8e50ecc027cd2443a3ef9b1a87991d37f1acdc41/LICENSE)
对 default/full 构建脚本采用 MIT 许可。原生依赖分别遵守各自许可，不能将构建脚本的 MIT 解释为所有原生依赖的许可。

- [mpv 配置](https://github.com/My-Responsitories/libmpv-android-video-build/blob/8e50ecc027cd2443a3ef9b1a87991d37f1acdc41/buildscripts/scripts/mpv.sh)设置 `-Dgpl=false`，对应 mpv 的 LGPL 构建。
- [FFmpeg default 配置](https://github.com/My-Responsitories/libmpv-android-video-build/blob/8e50ecc027cd2443a3ef9b1a87991d37f1acdc41/buildscripts/flavors/default.sh)设置 `--disable-gpl --disable-nonfree --enable-version3`，并启用 MediaCodec/JNI、libdav1d、libwebp 等依赖。
- 不采用 `encoders-gpl` 构建。下游分发仍需保留相应的原生依赖许可与源码提供义务。

构建脚本版本和 ABI 静态检查不能代替设备验证；Surface 生命周期、硬解、音视频同步和性能仍需在目标 Android 设备验收。
