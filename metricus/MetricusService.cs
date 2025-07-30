// Decompiled with JetBrains decompiler
// Type: Metricus.MetricusService
// Assembly: metricus, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: 63B9C274-3255-41BD-932E-183063283854
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\metricus.exe

using Metricus.Plugin;
using ServiceStack.Text;
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Timers;
using Topshelf;

#nullable disable
namespace Metricus
{
  internal class MetricusService : ServiceControl
  {
    private readonly System.Timers.Timer _timer;
    private MetricusConfig config;
    private PluginManager pluginManager;
    private object workLocker = new object();

    public MetricusService()
    {
      this.config = JsonSerializer.DeserializeFromString<MetricusConfig>(File.ReadAllText("config.json"));
      Console.WriteLine("Config loaded: {0}", (object) this.config.Dump<MetricusConfig>());
      this._timer = new System.Timers.Timer((double) this.config.Interval);
      this._timer.Elapsed += new ElapsedEventHandler(this.Tick);
      this.pluginManager = new PluginManager(this.config.Host);
    }

    public bool Start(HostControl hostControl)
    {
      this.LoadPlugins();
      this._timer.Start();
      return true;
    }

    public bool StartRaw()
    {
      this.LoadPlugins();
      this._timer.Start();
      return true;
    }

    public bool Stop(HostControl hostControl)
    {
      this._timer.Stop();
      return true;
    }

    private void LoadPlugins()
    {
      string[] strArray = (string[]) null;
      if (Directory.Exists("Plugins"))
      {
        Console.WriteLine("Loading plugins");
        foreach (string directory in Directory.GetDirectories("Plugins"))
          strArray = Directory.GetFiles("Plugins", "*.dll");
      }
      else
        Console.WriteLine("Plugin directory not found!");
      foreach (string str in strArray)
        Console.WriteLine(str);
      foreach (string directory in Directory.GetDirectories("Plugins"))
      {
        ICollection<Type> plugins = PluginLoader<IInputPlugin>.GetPlugins(directory);
        Console.WriteLine(directory.ToString());
        foreach (Type type in (IEnumerable<Type>) plugins)
        {
          Console.WriteLine(type.Assembly.GetName().Name);
          if (this.config.ActivePlugins.Contains(type.Assembly.GetName().Name))
          {
            Console.WriteLine("Loading plugin {0}", (object) type.Assembly.GetName().Name);
            Activator.CreateInstance(type, (object) this.pluginManager);
          }
        }
        foreach (Type plugin in (IEnumerable<Type>) PluginLoader<IOutputPlugin>.GetPlugins(directory))
        {
          if (this.config.ActivePlugins.Contains(plugin.Assembly.GetName().Name))
          {
            Console.WriteLine("Loading plugin {0}", (object) plugin.Assembly.GetName().Name);
            Activator.CreateInstance(plugin, (object) this.pluginManager);
          }
        }
        foreach (Type plugin in (IEnumerable<Type>) PluginLoader<IFilterPlugin>.GetPlugins(directory))
        {
          if (this.config.ActivePlugins.Contains(plugin.Assembly.GetName().Name))
          {
            Console.WriteLine("Loading plugin {0}", (object) plugin.Assembly.GetName().Name);
            Activator.CreateInstance(plugin, (object) this.pluginManager);
          }
        }
      }
    }

    private void Tick(object source, ElapsedEventArgs e)
    {
      if (!Monitor.TryEnter(this.workLocker))
        return;
      try
      {
        DateTime now = DateTime.Now;
        this.pluginManager.Tick();
        TimeSpan timeSpan = DateTime.Now - now;
      }
      finally
      {
        Monitor.Exit(this.workLocker);
      }
    }
  }
}
