using Metricus.Plugin;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;

namespace Metricus.Plugins
{
  public class ConsoleOut : OutputPlugin, IOutputPlugin
  {
    public ConsoleOut(PluginManager pm) : base(pm)
    {
    }

    public override void Work(List<metric> m)
    {
      foreach (metric metric in m)
        Console.WriteLine(JsonConvert.SerializeObject((object) metric, Formatting.Indented));
    }
  }
}
