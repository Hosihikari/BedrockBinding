using System;
using System.IO;
using System.Text;
using Microsoft.Extensions.Logging;
using Hosihikari;
using Hosihikari.Bindings.Bedrock.Interop;

// Loads the generated BindingShim inside a real BDS 1.21.3.01 process and reads the two
// static accessors that resolve through the carrier's symbols. The 1.21.3 surface projects
// these as static properties rather than methods.
public sealed class BedrockSmokePlugin : IPlugin
{
    private IPluginContext _context = null!;

    public void OnLoad(IPluginContext context) => _context = context;

    public PluginHookResult OnEnable()
    {
        System.IO.Directory.CreateDirectory(_context.DataDirectory);
        var resultPath = System.IO.Path.Combine(_context.DataDirectory, "bedrock-smoke.txt");
        var log = new StringBuilder();

        try
        {
            NativeMethods.Load(System.IO.Path.Combine(
                _context.PackageDirectory,
                "Hosihikari.Bindings.Bedrock.Shim.dll"));
            log.AppendLine("load=ok");

            var prefix = Block.BLOCK_DESCRIPTION_PREFIX;
            log.AppendLine($"block.prefix={prefix}");
            if (string.IsNullOrEmpty(prefix))
            {
                throw new InvalidOperationException("BLOCK_DESCRIPTION_PREFIX resolved to an empty string.");
            }

            var enchants = ItemStackBase.TAG_ENCHANTS;
            log.AppendLine($"item.enchants={enchants}");
            if (string.IsNullOrEmpty(enchants))
            {
                throw new InvalidOperationException("TAG_ENCHANTS resolved to an empty string.");
            }

            log.AppendLine("result=OK");
        }
        catch (Exception exception)
        {
            log.AppendLine("result=FAIL");
            log.AppendLine(exception.ToString());
            _context.Logger.LogInformation("bedrock smoke failed: {Error}", exception);
        }

        System.IO.File.WriteAllText(resultPath, log.ToString());
        return PluginHookResult.Allow();
    }

    public PluginHookResult OnDisable() => PluginHookResult.Allow();

    public void OnUnload()
    {
    }
}
