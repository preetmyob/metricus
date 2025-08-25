using System.Collections.Generic;

namespace Metricus.Plugin
{
  public abstract class OutputPlugin : Plugin, IOutputPlugin
  {
    public OutputPlugin(PluginManager pm) : base(pm)
    {
    }

    public abstract void Work(List<metric> m);
  }
}