# Runtime smoke

Loads the generated BindingShim inside a real BDS **1.26.51.1** process and exercises the name-resolved surface.

## Requirements

- Windows x64.
- BDS 1.26.51.1 with LeviLamina 26.51.9 (its PreLoader provides `pl_resolve_symbol`).
- The Hosihikari host and `hosihikari-csharp` provider in `plugins/`.
- The generated BindingShim and Interop from this repository.

## Run

```shell
powershell -File scripts/run-runtime-smoke.ps1 -ServerRoot C:\path\to\bedrock-server
```

The script builds the solution and native shim, copies the plugin sources and DLLs into `plugins/bedrock-smoke`, starts the server, waits for `data/hosihikari/bedrock-smoke/bedrock-smoke.txt`, stops the server, and requires `result=OK`.

## Coverage

- `NativeMethods.Load` validates the chunked function table inside BDS.
- Static accessor `Block.BLOCK_DESCRIPTION_PREFIX()` returns `tile.` (resolved by decorated name).
- `ItemStackBase.TAG_ENCHANTS()` returns `ench`.
- `HashedString` construction and destruction, whose constructor and destructor are both found at run time (`??0`/`??1`).
- `Core::Random` construction (2,536-byte layout) and `nextInt()`.
- `TextPacket` construction (248-byte layout) and `isValid()`.
- Members whose symbol the running server does not export report `symbol was not resolved`.

Expected result:

```text
load=ok
block.prefix=tile.
item.enchants=ench
hashedstring.create=ok
random.nextint=<a 32-bit value>
textpacket.isvalid=True
result=OK
```

The smoke is not part of CI; it requires a local BDS 1.26.51.1 runtime.
