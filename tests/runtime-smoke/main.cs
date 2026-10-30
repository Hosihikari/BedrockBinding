using System;
using System.IO;
using System.Text;
using Microsoft.Extensions.Logging;
using Hosihikari;
using Hosihikari.Bindings.Bedrock.Interop;

// Loads the generated BindingShim inside a real BDS process and exercises the
// name-resolved surface: static constants, a constructed RNG, a constructed packet, a
// shim-owned string whose destructor is resolved by name, and a by-value record parameter
// whose copy constructor is resolved by name.
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

            var prefix = Block.BLOCK_DESCRIPTION_PREFIX();
            log.AppendLine($"block.prefix={prefix}");
            if (prefix != "tile.")
            {
                throw new InvalidOperationException($"unexpected block prefix: {prefix}");
            }

            var enchants = ItemStackBase.TAG_ENCHANTS();
            log.AppendLine($"item.enchants={enchants}");
            if (enchants != "ench")
            {
                throw new InvalidOperationException($"unexpected enchant tag: {enchants}");
            }

            using (var hashed = HashedString.Create_0d67d647("hello"))
            {
                log.AppendLine($"hashedstring.create={(hashed.Handle != 0 ? "ok" : "failed")}");
            }

            using (var random = global::Hosihikari.Bindings.Bedrock.Interop.Core.Random.Create())
            {
                log.AppendLine($"random.nextint={random.nextInt()}");
            }

            using (var packet = TextPacket.Create())
            {
                log.AppendLine($"textpacket.isvalid={packet.isValid()}");
                if (!packet.isValid())
                {
                    throw new InvalidOperationException("the constructed packet is not valid.");
                }
            }

            // HashedString is 48 bytes with non-trivial copy and destructor symbols. Copying it
            // through Create(HashedString) resolves the copy constructor by name; passing it by
            // value to ExpressionNode::unregisterQueryFunction copies it into the hidden
            // reference, and the callee destroys that copy.
            using (var hashed = HashedString.Create_0d67d647("projection-smoke"))
            using (var copy = HashedString.Create(hashed))
            {
                log.AppendLine($"hashedstring.copy={(copy.Handle != 0 ? "ok" : "failed")}");
                if (copy.Handle == 0)
                {
                    throw new InvalidOperationException("the by-value record copy constructor did not run.");
                }

                ExpressionNode.unregisterQueryFunction("projection-smoke", hashed);
                log.AppendLine("expression.unregister=ok");
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
