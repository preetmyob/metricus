using Graphite;
using Metricus.Plugin;
using ServiceStack.Text;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

#nullable disable
namespace Metricus.Plugins
{
  public class GraphiteOut : OutputPlugin, IOutputPlugin
  {
    private PluginManager pm;
    private GraphiteOutConfig config;
    private MetricusGraphiteTcpClient tcpClient;
    private GraphiteUdpClient udpClient;
    private BlockingCollection<metric> MetricSpool;
    private Task WorkMetricTask;
    private int DefaultSendBufferSize = 1000;


    public GraphiteOut(PluginManager pm)
      : base(pm)
    {
      this.config = JsonSerializer.DeserializeFromString<GraphiteOutConfig>(File.ReadAllText(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) + "/config.json"));
      this.config.Servername = this.config.Servername;
      Console.WriteLine("Loaded config : {0}", (object) this.config.Dump<GraphiteOutConfig>());
      this.pm = pm;
      
      if (this.config.SendBufferSize == 0)
        this.config.SendBufferSize = this.DefaultSendBufferSize;
      
      this.MetricSpool = new BlockingCollection<metric>(this.config.SendBufferSize);
      this.WorkMetricTask = Task.Factory.StartNew((Action) (() => this.WorkMetrics()), TaskCreationOptions.LongRunning);
    }

    private async Task<string> GetHostNameAsync()
    {
      string str = "http://169.254.169.254/latest/meta-data/";
      try
      {
        Console.WriteLine("Attempting to get hostname from AWS EC2 Metadata endpoint " + str);
        using (HttpClient httpClient = new HttpClient())
        {
          Task<string> instanceIdTask = httpClient.GetStringAsync(str + "instance-id");
          Task<string> localHostnameTask = httpClient.GetStringAsync(str + "local-hostname");
          string[] strArray = await Task.WhenAll<string>(instanceIdTask, localHostnameTask);
          return instanceIdTask.Result + "-" + localHostnameTask.Result;
        }
      }
      catch (HttpRequestException ex)
      {
        Console.WriteLine("Warning: " + ex.Message + ". This is probably because you're running it on a non EC2. Default to MachineName in environment");
        return Environment.MachineName;
      }
    }

    public override void Work(List<metric> m)
    {
      foreach (metric metric in m)
        this.MetricSpool.TryAdd(metric);
    }

    protected virtual void WorkMetrics()
    {
      Action<metric> action = this.config.Protocol.ToLower() switch
      {
        "tcp" => (m => this.ShipMetricTCP(m)),
        "udp" => (m => this.ShipMetricUDP(m)),
        "sumo" => (m => this.ShipToSumo(m)),
        _ => (m => this.ShipMetricUDP(m))
      };
      
      bool flag = false;
      while (!flag)
      {
        foreach (metric consuming in MetricSpoolEnumerable)
        {
          Console.WriteLine(".");
          action(consuming);
        }
      }
    }

    protected IEnumerable<metric> MetricSpoolEnumerable => this.MetricSpool.GetConsumingEnumerable();

    private void ShipMetricUDP(metric m)
    {
      this.udpClient = this.udpClient ?? new GraphiteUdpClient(this.config.Hostname, this.config.Port, this.config.Prefix + "." + this.pm.Hostname);
      this.udpClient.Send(this.MetricPath(this.FormatMetric(m)), (int) m.value);
    }

    private void ShipMetricTCP(metric m)
    {
      bool flag = false;
      while (!flag)
      {
        try
        {
          this.tcpClient = this.tcpClient ?? new MetricusGraphiteTcpClient(this.config.Hostname, this.config.Port, this.config.Debug);
          this.tcpClient.Send(this.MetricPath(this.FormatMetric(m)), m.value);
          flag = true;
        }
        catch (Exception ex)
        {
          Console.WriteLine((object) ex);
          if (this.tcpClient != null)
            this.tcpClient.Dispose();
          this.tcpClient = (MetricusGraphiteTcpClient) null;
          Thread.Sleep(5000);
        }
      }
    }
    
    private void ShipToSumo(metric metric)
    {
      // Build Graphite format: <metric.path> <value> <timestamp>
      var metricPath = $"{(metric.site ?? "default")}.{metric.category}.{metric.type}.{metric.instance}".Replace(" ", "_");
      var timestampSeconds = ((DateTimeOffset)metric.timestamp).ToUnixTimeSeconds();
      var graphiteLine = $"{metricPath} {metric.value} {timestampSeconds}";

      Console.WriteLine($"Graphite line for sumo: {graphiteLine}");
      
      var content = new StringContent(graphiteLine, Encoding.UTF8, "application/vnd.sumologic.graphite");

      Console.WriteLine($"Graphite call content for sumo: {content.ReadAsStringAsync().Result}");

      
      try
      {
        using var client = new HttpClient();
        var sumoHttpUrl = "get-value-from-1pass-MYOB>_preet-tmp>Grafana preet-migration-admin";
        var  response = client.PostAsync(sumoHttpUrl, content).GetAwaiter().GetResult();
        
        response.EnsureSuccessStatusCode();
        Console.WriteLine("Metric posted to sumo2 successfully.");
      }
      catch (Exception ex)
      {
        Console.WriteLine("Failed to send metric to sump: " + ex.Message);
        Thread.Sleep(10_000);
        Debugger.Break();
      }
    }

    private string MetricPath(metric m)
    {
      StringBuilder builder = new StringBuilder();
      this.AppendIf(builder, this.config.Prefix);
      builder.Append(!string.IsNullOrEmpty(m.site) ? "site." : "server.");
      this.AppendIf(builder, m.site);
      this.AppendIf(builder, this.config.Servername);
      this.AppendIf(builder, m.category);
      this.AppendIf(builder, m.instance);
      if (!string.IsNullOrEmpty(m.type))
        builder.Append(m.type);
      return builder.ToString().ToLower();
    }

    private void AppendIf(StringBuilder builder, string val)
    {
      if (string.IsNullOrEmpty(val))
        return;
      builder.Append(val);
      builder.Append(".");
    }

    private metric FormatMetric(metric metric)
    { 
      const string formatReplaceMatch = "(\\s+|\\.|/|\\(|\\))";
      const string formatReplace = "_";
      
      metric.category = Regex.Replace(metric.category, formatReplaceMatch, formatReplace);
      metric.type = Regex.Replace(metric.type, formatReplaceMatch, formatReplace);
      
      if (!string.IsNullOrEmpty(metric.instance))
        if (metric.instance.Equals(metric.site, StringComparison.OrdinalIgnoreCase))
          metric.instance = (string)null;
        else
          metric.instance = Regex.Replace(metric.instance, formatReplaceMatch, formatReplace);
      else
        metric.instance = "_total";
     
      if (!string.IsNullOrEmpty(metric.site))
        metric.site = Regex.Replace(metric.site, formatReplaceMatch, formatReplace);
     
      return metric;
    }
  }
}
