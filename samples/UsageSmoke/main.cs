using System;
using Microsoft.Extensions.Logging;
using Hosihikari;
using Hosihikari.Bindings.Bedrock.Interop;

// A C# plugin script for the LeviLamina 26.51 loader. It loads the binding shim shipped
// next to it, calls a static MCAPI function, then constructs two game objects through
// their decorated names and calls instance methods on them.
public sealed class UsageSmokePlugin : IPlugin
{
    private IPluginContext _context = null!;

    public void OnLoad(IPluginContext context) => _context = context;

    public PluginHookResult OnEnable()
    {
        var shimPath = System.IO.Path.Combine(
            _context.PackageDirectory,
            "Hosihikari.Bindings.Bedrock.Shim.dll");
        NativeMethods.Load(shimPath);

        _context.Logger.LogInformation("block prefix: {Prefix}", Block.BLOCK_DESCRIPTION_PREFIX());

        using (var random = global::Hosihikari.Bindings.Bedrock.Interop.Core.Random.Create())
        {
            _context.Logger.LogInformation("random: {Value}", random.nextInt());
        }

        using (var packet = TextPacket.Create())
        {
            _context.Logger.LogInformation("packet valid: {Valid}", packet.isValid());
        }

        return PluginHookResult.Allow();
    }

    public PluginHookResult OnDisable() => PluginHookResult.Allow();

    public void OnUnload()
    {
    }
}
