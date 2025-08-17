using System;
using System.Collections.Generic;

namespace Metricus.Plugin
{
  public class PluginManager
  {
    private List<InputPlugin> inputPlugins = new List<InputPlugin>();
    private List<OutputPlugin> outputPlugins = new List<OutputPlugin>();
    private List<FilterPlugin> filterPlugins = new List<FilterPlugin>();

    public string Hostname { get; internal set; }

    public PluginManager(string hostname)
    {
      this.Hostname = hostname;
    }

    public void RegisterInputPlugin(InputPlugin plugin)
    {
      this.inputPlugins.Add(plugin);
    }

    public void RegisterOutputPlugin(OutputPlugin plugin)
    {
      this.outputPlugins.Add(plugin);
    }

    public void RegisterFilterPlugin(FilterPlugin plugin)
    {
      this.filterPlugins.Add(plugin);
    }

    public void RegisterPlugin(Plugin plugin)
    {
      Console.WriteLine("Registering plugin of type: " + plugin.GetType().BaseType);
      switch (plugin.GetType().BaseType.ToString())
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

    public void ListInputPlugins()
    {
      foreach (Plugin plugin in this.inputPlugins)
      {
      }
    }

    public void Tick()
    {
      foreach (InputPlugin inputPlugin in this.inputPlugins)
      {
        List<metric> metricList = inputPlugin.Work();
        foreach (FilterPlugin filterPlugin in this.filterPlugins)
          metricList = filterPlugin.Work(metricList);
        foreach (OutputPlugin outputPlugin in this.outputPlugins)
          outputPlugin.Work(metricList);
      }
    }
  }
}
