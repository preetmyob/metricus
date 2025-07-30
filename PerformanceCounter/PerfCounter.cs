// Decompiled with JetBrains decompiler
// Type: Metricus.Plugins.PerfCounter
// Assembly: PerformanceCounter, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: F6514ADB-A1A7-46BE-9C1F-BB570DC35B1D
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\Plugins\PerfCounter\PerformanceCounter.dll

using Metricus.Plugin;
using ServiceStack.Text;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Timers;

#nullable disable
namespace Metricus.Plugins
{
  public class PerfCounter : InputPlugin, IInputPlugin
  {
    private List<PerfCounter.Category> categories = new List<PerfCounter.Category>();
    private PerfCounter.PerfCounterConfig config;

    public PerfCounter(PluginManager pm)
      : base(pm)
    {
      string directoryName = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      Console.WriteLine("Loading config from {0}", (object) (directoryName + "/config.json"));
      this.config = JsonSerializer.DeserializeFromString<PerfCounter.PerfCounterConfig>(File.ReadAllText(directoryName + "/config.json"));
      Console.WriteLine("Loaded config : {0}", (object) this.config.Dump<PerfCounter.PerfCounterConfig>());
      this.LoadCounters();
    }

    public override List<metric> Work()
    {
      List<metric> metricList = new List<metric>();
      DateTime now = DateTime.Now;
      foreach (PerfCounter.Category category in this.categories)
      {
        List<Tuple<string, string>> staleCounterKeys = new List<Tuple<string, string>>();
        lock (category.counters)
        {
          foreach (KeyValuePair<Tuple<string, string>, PerformanceCounter> counter in category.counters)
          {
            PerformanceCounter performanceCounter = counter.Value;
            try
            {
              metric metric = new metric(performanceCounter.CategoryName, performanceCounter.CounterName, performanceCounter.InstanceName, performanceCounter.NextValue(), now);
              metricList.Add(metric);
            }
            catch (Exception ex)
            {
              Console.WriteLine("{0} {1}", (object) ex.GetType(), (object) ex.Message);
              if (ex.Message.Contains("does not exist in the specified Category"))
                staleCounterKeys.Add(counter.Key);
            }
          }
        }
        category.RemoveStaleCounters(staleCounterKeys);
      }
      return metricList;
    }

    private void LoadCounters()
    {
      List<PerformanceCounter> performanceCounterList = new List<PerformanceCounter>();
      foreach (PerfCounter.ConfigCategory category1 in this.config.categories)
      {
        try
        {
          Category category2 = new Category(category1.name);
          if (!string.IsNullOrEmpty(category1.instance_regex))
            category2.instanceRegex = new Regex(category1.instance_regex);
          PerformanceCounterCategory performanceCounterCategory = new PerformanceCounterCategory(category1.name);
          category2.dynamic = category1.dynamic;
          category2.dynamicInterval = category1.dynamic_interval;
          category2.counterNames = category1.counters;
          category2.namedInstances = category1.instances;
          category2.LoadInstances();
          this.categories.Add(category2);
          if (category2.dynamic)
            category2.EnableRefresh();
        }
        catch (Exception e)
        {
          Console.WriteLine(e.Message);
        }
      }
    }

    private class PerfCounterConfig
    {
      public List<PerfCounter.ConfigCategory> categories { get; set; }
    }

    private class ConfigCategory
    {
      public string name { get; set; }

      public bool dynamic { get; set; }

      public int dynamic_interval { get; set; }

      public List<string> counters { get; set; }

      public List<string> instances { get; set; }

      public string instance_regex { get; set; }
    }

    private class Category
    {
      private Timer UpdateTimer;
      public List<string> namedInstances;

      public string name { get; set; }

      public Dictionary<Tuple<string, string>, PerformanceCounter> counters { get; set; }

      public List<string> counterNames { get; set; }

      public bool dynamic { get; set; }

      public int dynamicInterval { get; set; }

      public Regex instanceRegex { get; set; }

      public Category(string name)
      {
        this.name = name;
        this.counters = new Dictionary<Tuple<string, string>, PerformanceCounter>();
      }

      public void RegisterCounter(string counterName, string instanceName = "", Regex regex = null)
      {
        Tuple<string, string> key = Tuple.Create<string, string>(counterName, instanceName);
        lock (this.counters)
        {
          if (this.counters.ContainsKey(key))
            return;
          try
          {
            if (regex != null)
            {
              if (!regex.IsMatch(instanceName))
                return;
              Console.WriteLine("Registering regex instance: " + this.name + " - " + counterName + " - " + instanceName);
              PerformanceCounter performanceCounter = new PerformanceCounter(this.name, counterName, instanceName);
              double num = (double) performanceCounter.NextValue();
              this.counters.Add(key, performanceCounter);
            }
            else
            {
              Console.WriteLine("Registering instance: " + this.name + " - " + counterName + " - " + instanceName);
              PerformanceCounter performanceCounter = new PerformanceCounter(this.name, counterName, instanceName);
              double num = (double) performanceCounter.NextValue();
              this.counters.Add(key, performanceCounter);
            }
          }
          catch (Exception ex)
          {
            Console.WriteLine("{0} {1}", (object) ex.GetType(), (object) ex.Message);
          }
        }
      }

      public void UnRegisterCounter(string counterName, string instanceName = "")
      {
        Tuple<string, string> key = Tuple.Create<string, string>(counterName, instanceName);
        lock (this.counters)
        {
          if (!this.counters.ContainsKey(key))
            return;
          this.counters.Remove(key);
        }
      }

      public void RemoveStaleCounters(List<Tuple<string, string>> staleCounterKeys)
      {
        foreach (Tuple<string, string> staleCounterKey in staleCounterKeys)
          this.UnRegisterCounter(staleCounterKey.Item1, staleCounterKey.Item2);
      }

      public void LoadInstancesOld()
      {
        foreach (string instanceName in new PerformanceCounterCategory(this.name).GetInstanceNames())
        {
          foreach (string counterName in this.counterNames)
            this.RegisterCounter(counterName, instanceName);
        }
      }

      public void LoadInstances()
      {
        foreach (string counterName in this.counterNames)
        {
          string[] instanceNames = new PerformanceCounterCategory(this.name).GetInstanceNames();
          if (this.namedInstances != null)
          {
            foreach (string namedInstance in this.namedInstances)
              this.RegisterCounter(counterName, namedInstance);
          }
          if (this.instanceRegex != null && instanceNames.Length != 0)
          {
            foreach (string instanceName in instanceNames)
              this.RegisterCounter(counterName, instanceName, this.instanceRegex);
          }
          if (this.namedInstances == null && this.instanceRegex == null)
          {
            if (instanceNames.Length == 0)
            {
              this.RegisterCounter(counterName);
            }
            else
            {
              foreach (string instanceName in instanceNames)
                this.RegisterCounter(counterName, instanceName);
            }
          }
        }
      }

      public void EnableRefresh()
      {
        if (this.dynamicInterval == 0)
          this.dynamicInterval = 300000;
        this.UpdateTimer = this.UpdateTimer ?? new Timer((double) this.dynamicInterval);
        this.UpdateTimer.Elapsed += (ElapsedEventHandler) ((m, e) => this.LoadInstances());
        this.UpdateTimer.Start();
      }
    }
  }
}
