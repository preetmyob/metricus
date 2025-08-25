using Graphite;
using Metricus.Plugin;
using ServiceStack.Text;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

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
        public static readonly string FormatReplacementMatch = "(\\s+|\\.|/|\\(|\\))";
        public static readonly string FormatReplacementString = "_";

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
                    return $"{instanceIdTask.Result}-{localHostnameTask.Result}";
                }
            }
            catch (HttpRequestException ex)
            {
                Console.WriteLine($"Warning: {ex.Message}. This is probably because you're running it on a non EC2. Default to MachineName in environment");
                return Environment.MachineName;
            }
        }

        public override void Work(List<metric> m)
        {
            foreach (metric metric in m)
                this.MetricSpool.TryAdd(metric);
        }

        private void WorkMetrics()
        {
            Action<metric> action;
            switch (this.config.Protocol.ToLower())
            {
                case "tcp":
                    action = (Action<metric>) (m => this.ShipMetricTCP(m));
                    break;
                case "udp":
                    action = (Action<metric>) (m => this.ShipMetricUDP(m));
                    break;
                default:
                    action = (Action<metric>) (m => this.ShipMetricUDP(m));
                    break;
            }
            bool flag = false;
            while (!flag)
            {
                foreach (metric consuming in this.MetricSpool.GetConsumingEnumerable())
                    action(consuming);
            }
        }

        private void ShipMetricUDP(metric m)
        {
            this.udpClient = this.udpClient ?? new GraphiteUdpClient(this.config.Hostname, this.config.Port, $"{this.config.Prefix}.{this.pm.Hostname}");
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

        private metric FormatMetric(metric m)
        {
            m.category = Regex.Replace(m.category, FormatReplacementMatch, FormatReplacementString);
            m.type = Regex.Replace(m.type, FormatReplacementMatch, FormatReplacementString);
            m.instance = !string.IsNullOrEmpty(m.instance) ? (m.instance.Equals(m.site, StringComparison.OrdinalIgnoreCase) ? (string) null : Regex.Replace(m.instance, FormatReplacementMatch, FormatReplacementString)) : "_total";
            if (!string.IsNullOrEmpty(m.site))
                m.site = Regex.Replace(m.site, FormatReplacementMatch, FormatReplacementString);
            return m;
        }

        private class GraphiteOutConfig
        {
            public string Hostname { get; set; }
            public string Prefix { get; set; }
            public int Port { get; set; }
            public string Protocol { get; set; }
            public int SendBufferSize { get; set; }
            public string Servername { get; set; }
            public bool Debug { get; set; }
        }

        public class MetricusGraphiteTcpClient : IDisposable
        {
            private readonly bool _isDebug;

            public string GraphiteHostname { get; }
            public TcpClient Client { get; }
            public int Port { get; }

            public MetricusGraphiteTcpClient(string graphiteHostname, int port, bool isDebug = false)
            {
                this._isDebug = isDebug;
                this.GraphiteHostname = graphiteHostname;
                this.Port = port;
                this.Port = port;
                this.Client = new TcpClient(this.GraphiteHostname, this.Port);
            }

            public void Send(string path, float value) => this.Send(path, value, DateTime.UtcNow);

            public void Send(string path, float value, DateTime timeStamp)
            {
                string s = $"{path} {value} {ServiceStack.Text.DateTimeExtensions.ToUnixTime(timeStamp.ToUniversalTime())}\n";
                if (this._isDebug)
                    Console.WriteLine("Sending msg: " + s);
                byte[] bytes = Encoding.UTF8.GetBytes(s);
                this.Client.GetStream().Write(bytes, 0, bytes.Length);
            }

            public void Dispose()
            {
                this.Dispose(true);
                GC.SuppressFinalize((object) this);
            }

            protected virtual void Dispose(bool disposing)
            {
                if (!disposing || this.Client == null)
                    return;
                this.Client.Close();
            }
        }
    }
}
