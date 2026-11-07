# BiliSail 原生媒体依赖

2026-11-07。Dart 核心、视频插件和各平台库插件以官方 `c533e446755f51cf53c7e57aea873f2aa5355f81` 为基线，由 `CKopoer/media-kit` 维护。mpv 源码由 [CKopoer/mpv](https://github.com/CKopoer/mpv) 维护。

## 固定资产

`assets.lock.json` 是原生资产来源、镜像地址及 SHA-256 的审计清单。首批 `native-2026-11-07` 为上游二进制的逐字节镜像，不宣称已由本仓库重新编译：

- Windows x64：zhongfly `2026-10-12-88eb9f2e73` LGPL SDK，mpv `88eb9f2e73945d8bc9c133a2f67babaa9af34680`，包含 EGL client/display device-query 修复，标准 OpenGL render API。ANGLE v1.0.1 保持不变。SDK 的 DLL、import library、四份头文件分别复核，不能混用 DXGI 扩展库。
- Android：My-Responsitories `20260906/default`，mpv 0.41.0、FFmpeg 9.0.1，API 24，arm64-v8a/armeabi-v7a/x86_64。个人 mpv `codex/android-0.41` 保留必需的 Java VM hook，来源为原构建仓库 `8e50ecc027cd2443a3ef9b1a87991d37f1acdc41` 的同名补丁。辅助库、事件桥和子依赖的原发布内容保持不变；官方 Dart 核心不再依赖旧事件桥。
- macOS/iOS：官方 libmpv-darwin-build v0.7.2，保留当前官方基线的 CocoaPods、SPM 校验和平台包装。两种分发方式均指向个人仓库镜像。
- Linux：库插件从个人 mpv 的固定 0.41.0 源码构建 `libmpv.so.2`，随 Flutter bundle 分发；FFmpeg、图形驱动等依赖继续来自发行版。源码归档完整 SHA-256、构建入口和许可均保留，Linux 本机播放与打包仍需验证。

精确构建分支提交见 `builds.lock.json`。构建材料 fork 为 `CKopoer/mpv-winbuild`、`CKopoer/libmpv-android-video-build`、`CKopoer/libmpv-darwin-build`。各原始发布的构建记录和子依赖仍是首批镜像的来源，不能将修改后的个人构建脚本倒推为旧二进制的构建记录。

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

2026-11-07：核心扩展原生用例 10 项、视频生命周期／配置用例 22 项、核心与视频生产源码静态分析通过。Windows 已通过真实 D3D11/ANGLE 共享／复制、稳定 texture ID／descriptor 生命周期和 9 项释放／队列回归。Linux Ubuntu 24.04 的个人源码构建、动态依赖及 client ABI 检查通过：[run 42329760177](https://github.com/CKopoer/media-kit/actions/runs/42329760177)。Linux 本机图形播放、Flutter 打包和 Apple 设备验收不能由该构建推导。
