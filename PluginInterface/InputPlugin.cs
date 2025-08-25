using System.Collections.Generic;

namespace Metricus.Plugin
{
  public abstract class InputPlugin : Plugin, IInputPlugin
  {
    public InputPlugin(PluginManager pm) : base(pm)
    {
    }

    public abstract List<metric> Work();
  }
}
