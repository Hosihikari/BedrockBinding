# Runtime smoke

Loads the generated BindingShim inside a real BDS **1.21.3.01** process and reads the static accessors the surface projects from carrier symbols.

## Requirements

- Windows x64.
- BDS 1.21.3.01 with LeviLamina v0.13.5 (the carrier this branch targets).
- The Hosihikari host and `hosihikari-csharp` provider in `plugins/`.
- The generated BindingShim and Interop from this repository.

## Run

```shell
powershell -File scripts/run-runtime-smoke.ps1 -ServerRoot C:\path\to\bedrock-server
```

The script builds the solution and native shim, copies the plugin sources and DLLs into `plugins/bedrock-smoke`, starts the server, waits for `data/hosihikari/bedrock-smoke/bedrock-smoke.txt`, stops the server, and requires `result=OK`.

## Coverage

- `NativeMethods.Load` validates the function table inside BDS.
- `Block.BLOCK_DESCRIPTION_PREFIX` resolves through the carrier's symbol and returns a non-empty string.
- `ItemStackBase.TAG_ENCHANTS` resolves through the carrier's symbol and returns a non-empty string.

Expected result (the exact strings are carrier values):

```text
load=ok
block.prefix=<value>
item.enchants=<value>
result=OK
```

The smoke is not part of CI; it requires a local BDS 1.21.3.01 runtime.
