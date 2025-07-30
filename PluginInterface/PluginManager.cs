// Decompiled with JetBrains decompiler
// Type: Metricus.Plugin.PluginManager
// Assembly: PluginInterface, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: C34EB815-9AB9-443E-9926-31046FA85D8F
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\PluginInterface.dll

using System;
using System.Collections.Generic;

#nullable disable
namespace Metricus.Plugin
{
  public class PluginManager
  {
    private List<InputPlugin> inputPlugins = new List<InputPlugin>();
    private List<OutputPlugin> outputPlugins = new List<OutputPlugin>();
    private List<FilterPlugin> filterPlugins = new List<FilterPlugin>();

    public string Hostname { get; internal set; }

    public PluginManager(string hostname) => this.Hostname = hostname;

    public void RegisterInputPlugin(InputPlugin plugin) => this.inputPlugins.Add(plugin);

    public void RegisterOutputPlugin(OutputPlugin plugin) => this.outputPlugins.Add(plugin);

    public void RegisterFilterPlugin(FilterPlugin plugin) => this.filterPlugins.Add(plugin);

    public void RegisterPlugin(Metricus.Plugin.Plugin plugin)
    {
      Type baseType = plugin.GetType().BaseType;
      Console.WriteLine("Registering plugin of type: " + baseType?.ToString());
      switch (baseType?.ToString())
      {
        case "Metricus.Plugin.InputPlugin":
          this.RegisterInputPlugin((InputPlugin) plugin);
          break;
        case "Metricus.Plugin.OutputPlugin":
          this.RegisterOutputPlugin((OutputPlugin) plugin);
          break;
        case "Metricus.Plugin.FilterPlugin":
          this.RegisterFilterPlugin((FilterPlugin) plugin);
          break;
        default:
          throw new Exception("Invalid plugin type.");
      }
    }

    public void Tick()
    {
      foreach (InputPlugin inputPlugin in this.inputPlugins)
      {
        List<metric> m = inputPlugin.Work();
        foreach (FilterPlugin filterPlugin in this.filterPlugins)
          m = filterPlugin.Work(m);
        foreach (OutputPlugin outputPlugin in this.outputPlugins)
        {
          Console.WriteLine($"Calling plugin: {outputPlugin.GetType().Name}");
          outputPlugin.Work(m);
        }
      }
    }
  }
}
