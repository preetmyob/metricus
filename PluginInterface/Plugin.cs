// Decompiled with JetBrains decompiler
// Type: Metricus.Plugin.Plugin
// Assembly: PluginInterface, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: C34EB815-9AB9-443E-9926-31046FA85D8F
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\PluginInterface.dll

#nullable disable
namespace Metricus.Plugin
{
  public abstract class Plugin
  {
    private PluginManager _pm;

    protected Plugin(PluginManager pm)
    {
      this._pm = pm;
      pm.RegisterPlugin(this);
    }
  }
}
