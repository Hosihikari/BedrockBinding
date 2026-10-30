# Hosihikari.Bindings.Bedrock

[English](README.md) | [简体中文](README.zh_hans.md)

Hosihikari 绑定项目的 **Bedrock / MCAPI** 互操作面：生成的、贴近原生风格的 **Interop** 与按符号分发的原生 **绑定垫片**。

本分支面向 **BDS 1.26.51.1**，数据来自 LeviLamina `ee049f1dc` 的头文件；`v1.21.3` 分支保留从载体调试符号生成的 1.21.3.01 面。

## 边界

- `Hosihikari.Bindings.Bedrock.Interop` 由 `HosihikariProjection/BindingGenerator` 从 LeviLamina `src/mc` 与 `ll/api` 头文件树的头文件级 IR 生成。它映照 MCAPI 声明：record 保留生成的包装类型，枚举声明投影为携带头文件枚举值的 C# 枚举，单层指针与引用返回变为类型化借用包装，`optional_ref<T>` 复用该路径，不受支持的成员保留带原因的 `NotSupportedException` stub；没有可用成员的类型保留类型身份并标记 `[Obsolete]`。ABI 值类型与 shim 加载器来自 `HosihikariProjection/BindingAbi`。
- `native/BindingShim/` 是 C ABI 投影，自包含：不包含游戏头文件，也不链接 import library。每个成员在运行期向预加载器（`pl_resolve_symbol`）查询其修饰名；查询入口通过 `GetModuleHandleW`/`dlsym` 动态取得，因此没有预加载器的进程里垫片也能加载，只是调用返回 `symbol was not resolved`。解析结果按函数缓存，每个名称只查找一次。
- 手写 Idiomatic 层延后；生成的 Interop 是当前公开的互操作面。

## 当前状态

- Interop：`src/Hosihikari.Bindings.Bedrock.Interop/Generated/` 下 9,110 个生成的 C# 文件。
- 绑定垫片：`native/BindingShim/generated/win-x64-server/bedrock/` 下 128,068 个函数。
- 覆盖：`win-x64-server` 配置绑定 12,043 个声明与 92,708 个成员。
- `scripts/headers-26.51.txt` 列出解析的 5,192 个头文件。从这些头文件可达的声明都会发射；布局与字段偏移来自前端的 AST record layout，只要头文件能证明，record 就保留字段。

shim 以 `--symbol-dispatch --resolve-by-name` 模式发射。支持的 ABI：

- 标量与枚举底层类型；
- `std::string` / `std::string_view` 的值与 const 引用；
- 单层 `T*` / `T&`，以 `void*` 传递；
- 按值 record：小的 `triviallyCopyable` record 走整数寄存器，较大 record 走栈上临时区与隐藏返回缓冲区；只有平凡析构的 record 按字节复制，但因用户提供的拷贝构造而对调用 ABI 非平凡，始终使用隐藏引用；
- 类型未投影的字段以只读 `nint` 暴露字段存储地址，属性名为 `<field>_Address`；
- `optional_ref<T>` 参数与返回使用存在标志；
- `std::vector<T>` 参数与按值返回，元素支持标量/枚举、字符串、单层指针（以 `nint[]` 传入），或 layout 已知且平凡析构的 record；引用与指针 vector 返回仍是借用句柄；
- `std::optional<T>` 参数与返回，支持标量、字符串与 trivially copyable record；record payload 使用 layout 兼容的 blob，返回的 record 成为拥有包装；
- `std::shared_ptr<T>` 参数与返回，由 shim holder 持有一个共享引用；`std::weak_ptr<T>` 返回锁定一次形成强快照，过期时为空。

map 需要具名 key/value 类型与匹配的 hash/equality functor，合并后的 IR 不携带这些信息。回调、variant、自定义拥有型包装，以及缺少可证明布局的 record 保留 Interop stub。

## 生成

重新生成只需要公开输入：一份 LeviLamina `ee049f1dc` 检出，以及用 LLVM 23.1.4 构建的生成器。预编译依赖来自 LeviLamina 构建所用的本地 xmake 包仓库。

```shell
powershell -File scripts/regenerate.ps1 `
  -LeviLaminaRoot C:\path\to\LeviLamina
```

脚本解析 `scripts/headers-26.51.txt`，以 `--symbol-dispatch --resolve-by-name` 发射，并更新 `src/`、`native/BindingShim/generated/` 与 `coverage/`。迭代发射器时可传 `-SkipFrontend -IrDirectory <dir>` 复用已有 IR。审查 diff 后运行 `python scripts/verify_generated.py`。

## 构建

```shell
dotnet build Hosihikari.Bindings.Bedrock.slnx -c Release
powershell -File native/BindingShim/build.ps1
```

生成的 shim 目录包含来自 `BindingAbi` 的 `hosihikari_abi.h`，原生构建因此自包含。shim 用 MSVC 构建，不需要 BDS 头文件或 import library。

## 运行时冒烟

`tests/runtime-smoke/` 是一个插件脚本：在真实服务器进程内加载垫片，校验两个静态访问器，并构造 `HashedString`、`Core::Random` 与 `TextPacket` 后调用实例方法。`scripts/run-runtime-smoke.ps1 -ServerRoot <目录>` 会构建、部署插件、启动服务器并要求 `result=OK`。

## 发布

`release.yml` 在 `v*` 标签上运行：构建并校验已提交的面，打包 `Hosihikari.Bindings.Bedrock.Interop.<version>.nupkg`，构建 Windows 垫片并压缩为 `Hosihikari.Bindings.Bedrock.Shim-win-x64-server.zip`，两者附加到 GitHub Release。包版本写在 csproj 里（`1.26.51-r0`）。

## 生成源校验

`scripts/verify_generated.py` 校验来源信息、覆盖基线、shim 函数数、表版本、托管表与每个生成文件的哈希。CI 构建解决方案、运行校验器、用生成器验证提交的覆盖契约，并编译 Windows shim。

## 数据来源

shim 内嵌 MSVC 修饰名；这些名称与布局事实是生成的绑定数据，与生成器版本、IR manifest 哈希、载体提交与头文件数一起记录在 `coverage/provenance.json`。重新生成不需要也不包含任何专有游戏二进制或调试符号。

## 相关仓库

- `HosihikariProjection/BindingIr`：IR schema、模型、读写器与校验器。
- `HosihikariProjection/BindingAbi`：共享 ABI 值类型、加载器与原生头。
- `HosihikariProjection/BindingGenerator`：libTooling 前端与发射器。
- `HosihikariProjection/LeviLaminaBinding`：LeviLamina 互操作面。
- `HosihikariProjection/EndstoneBinding`：Endstone 互操作面。

## 许可证

LGPL-3.0-or-later，见 `LICENSE.md`。
