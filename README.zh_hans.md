# Hosihikari.Bindings.Bedrock

Hosihikari 绑定项目的 **Bedrock / MCAPI** 表面：生成的、贴近原生风格的 **Interop** 与按符号分发的原生 **BindingShim**。

## 边界

- `Hosihikari.Bindings.Bedrock.Interop` 由 `Hosihikari/Bindings.Generator` 从 Bedrock Dedicated Server **1.21.3.01** 的符号级 IR 生成，并合并 LeviLamina **v0.13.5** 头文件补充。它映照 MCAPI 声明：record 保留生成的包装类型，单层指针与引用返回变为类型化借用包装，`optional_ref<T>` 复用该路径，不受支持的成员保留带原因的 `NotSupportedException` stub。ABI 值类型与 shim 加载器来自 `Hosihikari/Bindings.Abi`。
- `native/BindingShim/` 是 C ABI 投影，自包含：不包含游戏头文件，也不链接 import library。直接成员在 Windows 上解析 `模块基址 + rva`，在 Linux 上解析 `模块基址 + address`；虚成员按每配置 vtable 槽索引。缺少地址时回退到 `GetProcAddress`/`dlsym` 与记录的符号。命名模块不存在时，Windows 与 Linux 会回退到进程主模块，因此 `bedrock_server.exe` 与 `bedrock_server_mod.exe` 都能工作。
- 手写 Idiomatic 层延后；生成的 Interop 是当前公开表面。

## 当前状态

- Interop：`src/Hosihikari.Bindings.Bedrock.Interop/Generated/` 下 120 个生成的 C# 文件。
- BindingShim：`native/BindingShim/generated/win-x64-server/bedrock/` 与 `native/BindingShim/generated/linux-x64-server/bedrock/` 各 2,686 个函数。
- 覆盖：两个配置合计绑定 442 个声明与 7,289 个成员。

shim 以 `--symbol-dispatch` 模式发射。支持的 ABI：

- 标量与枚举底层类型；
- `std::string` / `std::string_view` 的值与 const 引用；
- 单层 `T*` / `T&`，以 `void*` 传递；
- 按值 record：小的 `triviallyCopyable` record 走整数寄存器，较大 record 走栈上临时区与隐藏返回缓冲区；只有平凡析构的 record（`AABB`、`Vec2`、`Brightness`）按字节复制，但因用户提供的拷贝构造而对调用 ABI 非平凡，始终使用隐藏引用；非平凡析构 record 使用其拷贝构造与析构符号；
- `optional_ref<T>` 参数与返回使用存在标志；
- `std::vector<T>` 参数与按值返回，元素支持标量/枚举、字符串、单层指针（以 `nint[]` 传入），或 layout 已知且平凡析构的 record；引用与指针 vector 返回仍是借用句柄；
- `std::optional<T>` 参数与返回，支持标量、字符串与 trivially copyable record；record payload 使用 layout 兼容的 blob，返回的 record 成为拥有包装；
- `std::shared_ptr<T>` 参数与返回，由 shim holder 持有一个共享引用；`std::weak_ptr<T>` 返回锁定一次形成强快照，过期时为空。

map 需要具名 key/value 类型与匹配的 hash/equality functor，符号流不携带这些信息。回调、variant、自定义拥有型包装，以及缺少可解析拷贝/析构符号的 record 保留 Interop stub。

## 生成

重新生成需要不属于本仓库的专有输入：1.21.3.01 的 `bedrock_server.pdb`、`bedrock_server.exe`、`bedrock_server_symbols.debug`，以及用于头文件补充的 LeviLamina v0.13.5 检出与 LLVM 23.1.3 构建的生成器。

```shell
powershell -File scripts/regenerate.ps1 `
  -Pdb C:\path\to\bedrock_server.pdb `
  -Exe C:\path\to\bedrock_server.exe `
  -Elf C:\path\to\bedrock_server_symbols.debug `
  -LeviLaminaRoot C:\path\to\LiteLoaderBDS
```

脚本写出符号 IR、生成或复用头文件补充、合并、发射两个配置，并更新 `src/`、`native/BindingShim/generated/` 与 `coverage/`。审查 diff 后运行 `python scripts/verify_generated.py`。

## 构建

```shell
dotnet build Hosihikari.Bindings.Bedrock.slnx -c Release
powershell -File native/BindingShim/build.ps1
./native/BindingShim/build.sh
```

生成的 shim 目录包含来自 `Bindings.Abi` 的 `hosihikari_abi.h`，原生构建因此自包含。Windows shim 用 MSVC 构建，Linux shim 用 g++（`-ldl`）；两者都不需要 BDS 头文件。

## 生成源校验

`scripts/verify_generated.py` 校验来源信息、覆盖基线、两个配置的 shim 函数数、表版本、托管表与每个生成文件的哈希。CI 构建解决方案、运行校验器、用生成器验证提交的覆盖契约，并编译 Linux 与 Windows shim。

## 数据来源

shim 内嵌从 1.21.3.01 调试符号恢复的 RVA、Itanium/MSVC 符号名与 vtable 槽。这些是生成的绑定数据，与生成器版本、IR manifest 哈希、载体哈希一起记录在 `coverage/provenance.json`。头文件补充来自公开的 LeviLamina 头文件。

## 相关仓库

- `Hosihikari/Bindings.Ir`：IR schema、模型、读写器与校验器。
- `Hosihikari/Bindings.Abi`：共享 ABI 值类型、加载器与原生头。
- `Hosihikari/Bindings.Generator`：libTooling 前端与发射器。
- `Hosihikari/Bindings.LeviLamina`：LeviLamina 表面。
- `Hosihikari/Bindings.Endstone`：Endstone 表面。

## 许可证

LGPL-3.0-or-later，见 `LICENSE.md`。
