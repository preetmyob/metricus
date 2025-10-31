// Decompiled with JetBrains decompiler
// Type: Metricus.Plugin.SitesFilter
// Assembly: SitesFilter, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: F072D3F1-B3C6-4757-A19E-96E7215D2930
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\Plugins\SitesFilter\SitesFilter.dll

using Microsoft.Web.Administration;
using ServiceStack.Text;
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Timers;

#nullable disable
namespace Metricus.Plugin
{
  public class SitesFilter : FilterPlugin, IFilterPlugin
  {
    private SitesFilter.SitesFilterConfig config;
    private Dictionary<int, string> siteIDtoName;
    private ServerManager ServerManager;
    private Timer LoadSitesTimer;
    private object RefreshLock = new object();

    public SitesFilter(PluginManager pm)
      : base(pm)
    {
      string directoryName = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      Console.WriteLine("Loading config from {0}", (object) (directoryName + "/config.json"));
      this.config = JsonSerializer.DeserializeFromString<SitesFilter.SitesFilterConfig>(File.ReadAllText(directoryName + "/config.json"));
      Console.WriteLine("Loaded config : {0}", (object) this.config.Dump<SitesFilter.SitesFilterConfig>());
      this.siteIDtoName = new Dictionary<int, string>();
      this.LoadSites();
      this.LoadSitesTimer = new Timer(300000.0);
      this.LoadSitesTimer.Elapsed += (ElapsedEventHandler) ((o, e) => this.LoadSites());
      this.LoadSitesTimer.Start();
    }

    public override List<metric> Work(List<metric> m)
    {
      lock (this.RefreshLock)
      {
        Dictionary<string, ICategoryFilter> dictionary = new Dictionary<string, ICategoryFilter>()
        {
          {
            "w3wp.process",
            (ICategoryFilter) new SitesFilter.FilterWorkerPoolProcesses(this.ServerManager, "Process", "ID Process", this.config.Debug)
          },
          {
            "w3wp.net",
            (ICategoryFilter) new SitesFilter.FilterWorkerPoolProcesses(this.ServerManager, ".NET CLR Memory", "Process ID", this.config.Debug)
          },
          {
            "lmw3svc",
            (ICategoryFilter) new SitesFilter.FilterAspNetC(this.siteIDtoName, this.config.Debug)
          },
          {
            "w3svc",
            (ICategoryFilter) new SitesFilter.FilterW3SvcW3Wp(this.config.Debug)
          }
        };
        foreach (KeyValuePair<string, SitesFilter.ConfigCategory> category in this.config.Categories)
        {
          foreach (string filter in category.Value.Filters)
          {
            if (dictionary.ContainsKey(filter))
              m = dictionary[filter].Filter(m, category.Key, category.Value.PreserveOriginal);
          }
        }
      }
      return m;
    }

    public static string SiteNameReplacement(string siteName) => "##" + siteName + "##";

    public void LoadSites()
    {
      lock (this.RefreshLock)
      {
        try
        {
          this.ServerManager?.Dispose();
          this.ServerManager = new ServerManager();
          this.siteIDtoName.Clear();
          foreach (Site site in (ConfigurationElementCollectionBase<Site>) this.ServerManager.Sites)
            this.siteIDtoName.Add((int) site.Id, site.Name);
          this.siteIDtoName.PrintDump<Dictionary<int, string>>();
        }
        catch (Exception ex)
        {
          Console.WriteLine(string.Format("Exception {0} while loading IIS site information", (object) ex));
        }
      }
    }

    private class SitesFilterConfig
    {
      public Dictionary<string, SitesFilter.ConfigCategory> Categories { get; set; }

      public bool Debug { get; set; }
    }

    private class ConfigCategory
    {
      public List<string> Filters { get; set; }

      public bool PreserveOriginal { get; set; }
    }

    public class FilterWorkerPoolProcesses : ICategoryFilter
    {
      public static Dictionary<string, int> WpNamesToIds = new Dictionary<string, int>();
      private ServerManager serverManager;
      private readonly string processIdCounter;
      private readonly bool isDebug;
      private readonly string processIdCategory;

      public FilterWorkerPoolProcesses(
        ServerManager serverManager,
        string processIdCategory,
        string processIdCounter,
        bool isDebug = false)
      {
        this.serverManager = serverManager;
        this.processIdCounter = processIdCounter;
        this.isDebug = isDebug;
        this.processIdCategory = processIdCategory;
      }

      public List<metric> Filter(List<metric> metrics, string categoryName, bool preserveOriginal)
      {
        // First pass: build process ID to instance name mapping
        int count = metrics.Count;
        for (int index = 0; index < count; ++index)
        {
          metric metric = metrics[index];
          if (this.processIdCategory.Equals(metric.category, StringComparison.InvariantCultureIgnoreCase) && metric.type.Equals(this.processIdCounter, StringComparison.InvariantCultureIgnoreCase))
            SitesFilter.FilterWorkerPoolProcesses.WpNamesToIds[metric.instance] = (int) metric.value;
        }
        
        // Second pass: transform metrics to use app pool names
        List<metric> result = new List<metric>();
        for (int index1 = 0; index1 < count; ++index1)
        {
          metric metric1 = metrics[index1];
          int num;
          if (metric1.category.Equals(categoryName, StringComparison.InvariantCultureIgnoreCase) && (!metric1.category.Equals(this.processIdCategory, StringComparison.InvariantCultureIgnoreCase) || !metric1.type.Equals(this.processIdCounter, StringComparison.InvariantCultureIgnoreCase)) && metric1.instance.StartsWith("w3wp", StringComparison.Ordinal) && SitesFilter.FilterWorkerPoolProcesses.WpNamesToIds.TryGetValue(metric1.instance, out num))
          {
            bool found = false;
            for (int index2 = 0; index2 < this.serverManager.WorkerProcesses.Count; ++index2)
            {
              if (this.serverManager.WorkerProcesses[index2].ProcessId == num)
              {
                string appPoolName = this.serverManager.WorkerProcesses[index2].AppPoolName;
                metric metric2 = metric1 with
                {
                  site = appPoolName,
                  instance = "_Total"
                };
                if (this.isDebug)
                {
                  Console.WriteLine(string.Format("old: {0}", (object) metric1));
                  Console.WriteLine(string.Format("new: {0}", (object) metric2));
                }
                result.Add(metric2);
                if (preserveOriginal)
                  result.Add(metric1);
                found = true;
                break;
              }
            }
            if (!found)
            {
              // Process not found in worker processes, keep original
              result.Add(metric1);
            }
          }
          else
          {
            // Metric doesn't match criteria, keep as-is
            result.Add(metric1);
          }
        }
        return result;
      }
    }

    public class FilterW3SvcW3Wp : ICategoryFilter
    {
      private readonly bool _isDebug;
      private static Regex AppPoolRegex = new Regex("\\d+_(?<AppPool>.*)");

      public FilterW3SvcW3Wp(bool isDebug = false) => this._isDebug = isDebug;

      public List<metric> Filter(List<metric> metrics, string categoryName, bool preserveOriginal)
      {
        List<metric> metricList = new List<metric>();
        foreach (metric metric1 in metrics)
        {
          if (!metric1.category.Equals(categoryName, StringComparison.InvariantCultureIgnoreCase))
          {
            metricList.Add(metric1);
          }
          else
          {
            // Skip _Total instance
            if (metric1.instance.Equals("_Total", StringComparison.InvariantCultureIgnoreCase))
            {
              if (preserveOriginal)
                metricList.Add(metric1);
              continue;
            }
            
            Match match = SitesFilter.FilterW3SvcW3Wp.AppPoolRegex.Match(metric1.instance);
            string siteName;
            
            if (match.Success)
            {
              // W3SVC_W3WP format: "8140_adv73270kdde_173606a4"
              siteName = match.Groups["AppPool"].Value;
            }
            else
            {
              // web service format: instance IS the site name "adv73270kdde_173606a4"
              siteName = metric1.instance;
            }
            
            metric metric2 = metric1 with
            {
              site = siteName,
              instance = "_Total"
            };
            
            if (this._isDebug)
            {
              Console.WriteLine(string.Format("old: {0}", (object) metric1));
              Console.WriteLine(string.Format("new: {0}", (object) metric2));
            }
            
            metricList.Add(metric2);
            if (preserveOriginal)
              metricList.Add(metric1);
          }
        }
        return metricList;
      }
    }

    public class FilterAspNetC : ICategoryFilter
    {
      private static string PathSansId = "_LM_W3SVC";
      private static Regex MatchPathWithId = new Regex("_LM_W3SVC_(\\d+)_");
      private static Regex MatchRoot = new Regex("ROOT_?");
      private readonly Dictionary<int, string> siteIdsToNames;
      private readonly bool _isDebug;

      public FilterAspNetC(Dictionary<int, string> siteIdsToNames, bool isDebug = false)
      {
        this.siteIdsToNames = siteIdsToNames;
        this._isDebug = isDebug;
      }

      public List<metric> Filter(List<metric> metrics, string categoryName, bool preserveOriginal)
      {
        List<metric> metricList = new List<metric>();
        foreach (metric metric1 in metrics)
        {
          metric metric2 = metric1;
          if (!metric1.category.Equals(categoryName, StringComparison.InvariantCultureIgnoreCase))
            metricList.Add(metric2);
          else if (metric1.instance.Contains(SitesFilter.FilterAspNetC.PathSansId))
          {
            try
            {
              Match match = SitesFilter.FilterAspNetC.MatchPathWithId.Match(metric1.instance);
              if (match.Success && match.Groups.Count > 1)
              {
                int siteId = int.Parse(match.Groups[1].Value);
                string str;
                if (this.siteIdsToNames.TryGetValue(siteId, out str))
                {
                  metric2.site = str;
                  metric2.instance = str;
                  if (this._isDebug)
                  {
                    Console.WriteLine(string.Format("old: {0}", (object) metric1));
                    Console.WriteLine(string.Format("new: {0}", (object) metric2));
                  }
                  metricList.Add(metric2);
                  if (preserveOriginal)
                    metricList.Add(metric1);
                }
                else if (this._isDebug)
                {
                  Console.WriteLine(string.Format("Site ID {0} not found in siteIdsToNames for metric: {1}", (object) siteId, (object) metric1.instance));
                }
              }
              else if (this._isDebug)
              {
                Console.WriteLine(string.Format("Regex match failed for instance: {0}", (object) metric1.instance));
              }
            }
            catch (Exception ex)
            {
              Console.WriteLine(string.Format("Error parsing site ID from instance '{0}': {1}", (object) metric1.instance, (object) ex.Message));
            }
            // Site ID lookup failed or parsing error - drop the metric as it's an internal IIS identifier
          }
          else
            metricList.Add(metric2);
        }
        return metricList;
      }
    }
  }
}
