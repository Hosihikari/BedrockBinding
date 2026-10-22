# BindingShim

Generated C ABI projection for the Bedrock (MCAPI) surface.

`generated/<configuration>/bedrock/` contains `binding_table.cpp`, `binding_table.h`, and the copied `hosihikari_abi.h`. The shim does not include game headers and does not link an import library. Direct members resolve the host module base plus the recorded RVA (Windows) or link-time address (Linux); virtual members index the per-configuration vtable slot. Missing addresses fall back to `GetProcAddress`/`dlsym` with the recorded symbol, and a missing named module falls back to the process main module.

## Build

Windows x64 with MSVC:

```powershell
./build.ps1 -Configuration win-x64-server
```

Linux x64 with g++:

```shell
./build.sh --configuration linux-x64-server
```

Both scripts produce a shared library in `artifacts/native/` by default. The generated directory is self-contained, so no additional include paths are required.

## Table

The shared table is one versioned `HosihikariBindingTableV1`. Field names are stable hashes of the member identity (`hs_method_<hash>`), so adding a function does not rename existing call sites; the ordinal remains the physical array position. `NativeMethods.Load(path)` validates the exported table version and size before use.
