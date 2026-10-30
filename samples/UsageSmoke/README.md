# Usage smoke

A minimal plugin that exercises the generated surface inside a running server.

## Deploy

1. Build the managed assembly and the shim:

   ```shell
   dotnet build Hosihikari.Bindings.Bedrock.slnx -c Release
   powershell -File native/BindingShim/build.ps1
   ```

2. Copy this directory into the server's `plugins/usage-smoke/`.

3. Copy these files next to `main.cs`:

   - `src/Hosihikari.Bindings.Bedrock.Interop/bin/Release/net10.0/Hosihikari.Bindings.Bedrock.Interop.dll`
   - `src/Hosihikari.Bindings.Bedrock.Interop/bin/Release/net10.0/Hosihikari.Bindings.Abi.dll`
   - `artifacts/native/Hosihikari.Bindings.Bedrock.Shim.dll`

4. Start the server from `bedrock_server_mod.exe`. The plugin loads the shim, logs the
   block description prefix, a random value from `Core::Random`, and whether a freshly
   constructed `TextPacket` reports itself valid.

The shim resolves every member by decorated name through the preloader, so the plugin
works for any function whose name the running server exports; unresolved members report
`symbol was not resolved`.
