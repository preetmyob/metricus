using Microsoft.Web.Administration;
using ServiceStack.Text;
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Timers;

namespace Metricus.Plugin
{
    interface ICategoryFilter
    {
        List<metric> Filter(List<metric> metrics, string categoryName, bool preserveOriginal);
    }

    public class SitesFilter : FilterPlugin, IFilterPlugin
    {
        private SitesFilterConfig config;
        private Dictionary<int, string> siteIDtoName;
        private ServerManager ServerManager;
        private Timer LoadSitesTimer;
        private object RefreshLock = new object();

        public SitesFilter(PluginManager pm)
            : base(pm)
        {
            string directoryName = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            Console.WriteLine("Loading config from {0}", (object) (directoryName + "/config.json"));
            this.config = JsonSerializer.DeserializeFromString<SitesFilterConfig>(File.ReadAllText(directoryName + "/config.json"));
            Console.WriteLine("Loaded config : {0}", (object) this.config.Dump<SitesFilterConfig>());
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
                        (ICategoryFilter) new FilterWorkerPoolProcesses(this.ServerManager, "Process", "ID Process", this.config.Debug)
                    },
                    {
                        "w3wp.net",
                        (ICategoryFilter) new FilterWorkerPoolProcesses(this.ServerManager, ".NET CLR Memory", "Process ID", this.config.Debug)
                    },
                    {
                        "lmw3svc",
                        (ICategoryFilter) new FilterAspNetC(this.siteIDtoName, this.config.Debug)
                    },
                    {
                        "w3svc",
                        (ICategoryFilter) new FilterW3SvcW3Wp(this.config.Debug)
                    }
                };
                foreach (KeyValuePair<string, ConfigCategory> category in this.config.Categories)
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

        public static string SiteNameReplacement(string siteName) => $"##{siteName}##";

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
                    Console.WriteLine($"Exception {ex} while loading IIS site information");
                }
            }
        }

        private class SitesFilterConfig
        {
            public Dictionary<string, ConfigCategory> Categories { get; set; }
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
                int count = metrics.Count;
                for (int index = 0; index < count; ++index)
                {
                    metric metric = metrics[index];
                    if (this.processIdCategory.Equals(metric.category, StringComparison.InvariantCultureIgnoreCase) && metric.type.Equals(this.processIdCounter, StringComparison.InvariantCultureIgnoreCase))
                        FilterWorkerPoolProcesses.WpNamesToIds[metric.instance] = (int) metric.value;
                }
                for (int index1 = 0; index1 < count; ++index1)
                {
                    metric metric1 = metrics[index1];
                    int num;
                    if (metric1.category.Equals(categoryName, StringComparison.InvariantCultureIgnoreCase) && (!metric1.category.Equals(this.processIdCategory, StringComparison.InvariantCultureIgnoreCase) || !metric1.type.Equals(this.processIdCounter, StringComparison.InvariantCultureIgnoreCase)) && metric1.instance.StartsWith("w3wp", StringComparison.Ordinal) && FilterWorkerPoolProcesses.WpNamesToIds.TryGetValue(metric1.instance, out num))
                    {
                        for (int index2 = 0; index2 < this.serverManager.WorkerProcesses.Count; ++index2)
                        {
                            if (this.serverManager.WorkerProcesses[index2].ProcessId == num)
                            {
                                string appPoolName = this.serverManager.WorkerProcesses[index2].AppPoolName;
                                metric metric2 = metric1 with
                                {
                                    site = appPoolName,
                                    instance = (string) null
                                };
                                if (this.isDebug)
                                {
                                    Console.WriteLine($"old: {metric1}");
                                    Console.WriteLine($"new: {metric2}");
                                }
                                if (preserveOriginal)
                                    metrics.Add(metric1);
                                else
                                    metrics[index1] = metric2;
                            }
                        }
                    }
                }
                return metrics;
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
                        Match match = FilterW3SvcW3Wp.AppPoolRegex.Match(metric1.instance);
                        if (!match.Success)
                        {
                            metricList.Add(metric1);
                        }
                        else
                        {
                            string str = match.Groups["AppPool"].Value;
                            metric metric2 = metric1 with
                            {
                                site = str,
                                instance = str
                            };
                            if (this._isDebug)
                            {
                                Console.WriteLine($"old: {metric1}");
                                Console.WriteLine($"new: {metric2}");
                            }
                            metricList.Add(metric2);
                            if (preserveOriginal)
                                metricList.Add(metric1);
                        }
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
                    else if (metric1.instance.Contains(FilterAspNetC.PathSansId))
                    {
                        string str;
                        if (this.siteIdsToNames.TryGetValue(int.Parse(FilterAspNetC.MatchPathWithId.Match(metric1.instance).Groups[1].Value), out str))
                        {
                            metric2.site = str;
                            metric2.instance = str;
                            if (this._isDebug)
                            {
                                Console.WriteLine($"old: {metric1}");
                                Console.WriteLine($"new: {metric2}");
                            }
                            metricList.Add(metric2);
                        }
                        if (preserveOriginal)
                            metricList.Add(metric1);
                    }
                    else
                        metricList.Add(metric2);
                }
                return metricList;
            }
        }
    }
}
