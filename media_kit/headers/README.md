# libmpv client 绑定来源

- `client.h` 来自 [mpv v0.41.0](https://github.com/mpv-player/mpv/blob/v0.41.0/include/mpv/client.h)，保留文件顶部 ISC 许可。
- 原始文件 SHA-256：`3c073236a09cb456c6e80587d5523c8771c32fb22ca014e0f99cc3d43905b75c`。
- 生成器：`ffigen 23.0.0`（pub 资产 SHA-256 `6f55d99ac1857fc063b58c3b31753df2bba417028ba98d30c6d625a385855064`），配置见 `../tool/ffigen/ffigen.yaml`，生成工具的依赖锁文件一并提交。
- 从 `media_kit/tool/ffigen` 运行 `dart pub get`，再运行 `dart run ffigen --config ffigen.yaml`。系统需安装 libclang；若未被自动发现，通过 ffigen 的 `llvm-path` 指定安装目录。

这次重生成采用 PiliPlus fork 的小型无阻塞查询 leaf 白名单，并恢复 `unsigned long`、`size_t` 的 ABI 精确映射；继续使用 `Int8` 字符指针，保持现有调用代码兼容。mpv 命令、属性、事件等待、创建、销毁和渲染函数不标记 leaf。新增符号按需懒加载，不能从头文件版本推导出已安装原生库版本。
