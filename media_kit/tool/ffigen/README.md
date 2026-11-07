# 生成绑定

工具依赖隔离在本目录，先运行 `dart pub get`。mpv 绑定沿用
`dart run ffigen --config ffigen.yaml`，头文件来源见 `../../headers/README.md`。

Windows 调试引用缓存使用进程创建时间区分重复 PID。从 media_kit 目录运行：

```powershell
dart --packages=tool/ffigen/.dart_tool/package_config.json run tool/ffigen.dart
```

读取本机安装的 Windows SDK 10.0.26100.0 与 MSVC 14.44.35207 头文件，
不复制或重新分发 SDK。可用 `WINDOWS_SDK_INCLUDE`、`VCTOOLS_INCLUDE`、
`LIBCLANG_PATH` 指定其他安装位置。只生成 GetCurrentProcess、GetProcessTimes
和 FILETIME。使用系统 DLL 动态查找，不参与 Native Assets 链接裁剪；
ffigen 23 的 RecordUse 注解不适用于 Dart 实例方法，因此不生成使用映射。
Win32 API 保持系统 ABI，生成物供各平台编译，
仅在 Windows 调试模式调用。
