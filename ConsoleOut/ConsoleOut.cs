// Decompiled with JetBrains decompiler
// Type: Metricus.Plugins.ConsoleOut
// Assembly: ConsoleOut, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: 23D96501-2B14-4F8C-BD74-6D08ECC956AF
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\Plugins\ConsoleOut\ConsoleOut.dll

using Metricus.Plugin;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;

#nullable disable
namespace Metricus.Plugins
{
  public class ConsoleOut(PluginManager pm) : OutputPlugin(pm), IOutputPlugin
  {
    public override void Work(List<metric> m)
    {
      foreach (metric metric in m)
        Console.WriteLine(JsonConvert.SerializeObject((object) metric, Formatting.Indented));
    }
  }
}
