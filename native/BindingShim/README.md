# BindingShim

Generated C ABI projection for the Bedrock (MCAPI) surface.

`generated/<configuration>/bedrock/` contains `binding_table.cpp`, `binding_table.h`, and the copied `hosihikari_abi.h`. The shim does not include game headers and does not link an import library. Every member is resolved by decorated name at run time: the shim asks the preloader's `pl_resolve_symbol` for the MSVC name the frontend recorded, and caches the result per function. The lookup entry point is found with `GetModuleHandleW`/`dlsym`, so the shim loads in a process without a preloader and reports `symbol was not resolved` instead of failing to load.

## Build

Windows x64 with MSVC:

```powershell
./build.ps1 -Configuration win-x64-server
```

This branch generates the `win-x64-server` surface; `build.sh` is kept for a future Linux surface. The scripts produce a shared library in `artifacts/native/` by default. The generated directory is self-contained, so no additional include paths or libraries are required.

## Table

The shared table is one versioned `HosihikariBindingTableV1`. Field names are stable hashes of the member identity (`hs_method_<hash>`), so adding a function does not rename existing call sites; the ordinal remains the physical array position. `NativeMethods.Load(path)` validates the exported table version and size before use. The managed side reads the same array through chunk structs of at most 30,000 entries, which keeps each type under the CLR field limit.
