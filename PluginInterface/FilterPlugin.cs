using System.Collections.Generic;

namespace Metricus.Plugin
{
  public abstract class FilterPlugin : Plugin, IFilterPlugin
  {
    public FilterPlugin(PluginManager pm) : base(pm)
    {
    }

    public abstract List<metric> Work(List<metric> m);
  }
}
