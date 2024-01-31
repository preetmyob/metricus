using System;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Threading.Tasks;
using System.IO;
using System.Net.Sockets;
using System.Reflection;
using System.Security.Policy;
using System.Text;
using Metricus.Plugin;
using ServiceStack.Text;
using Graphite;



namespace Metricus.Plugins
{
    public class GraphiteOut : OutputPlugin, IOutputPlugin
    {
        // ReSharper disable once ClassNeverInstantiated.Local
        class GraphiteOutConfig
        {
            public String Hostname { get; set; }
            public String Prefix { get; set; }
            public int Port { get; set; }
            public string Protocol { get; set; }
            public int SendBufferSize { get; set; }
            public bool Debug { get; set; }
        }

        private PluginManager pm;
        private GraphiteOutConfig config;
        private MetricusGraphiteTcpClient tcpClient;
        private GraphiteUdpClient udpClient;
        private BlockingCollection<metric> MetricSpool;
        private Task WorkMetricTask;
        private int DefaultSendBufferSize = 1000;

        // "Match
        // one or more whitespace characters
        // OR a dot OR a forward slash
        // OR an opening parenthesis
        // OR a closing parenthesis."
        // We need to confirm if the regex can be replaced with [\s./()]
        public static readonly string FormatReplacementMatch = "(\\s+|\\.|/|\\(|\\))";
        public static readonly string FormatReplacementString = "_";

        public GraphiteOut(PluginManager pm)
            : base(pm)
        {
            var path = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

            config = JsonSerializer.DeserializeFromString<GraphiteOutConfig>(File.ReadAllText(path + "/config.json"));
            Console.WriteLine("Loaded config : {0}", config.Dump());    
            this.pm = pm;
            if (config.SendBufferSize == 0) config.SendBufferSize = DefaultSendBufferSize;
            MetricSpool = new BlockingCollection<metric>(config.SendBufferSize);
            WorkMetricTask = Task.Factory.StartNew(() => WorkMetrics(), TaskCreationOptions.LongRunning);
        }

        public override void Work(List<metric> m)
        {
            foreach (var rawMetric in m) { MetricSpool.TryAdd(rawMetric); }
        }

        private void WorkMetrics()
        {
            Action<metric> shipMethod;
            switch(config.Protocol.ToLower())
            {
                case "tcp":
                    shipMethod = (m) => ShipMetricTCP(m); break;
                case "udp":
                    shipMethod = (m) => ShipMetricUDP(m); break;
                default:
                    shipMethod = (m) => ShipMetricUDP(m); break;
            }

            Boolean done = false;
            while (!done)
            {
                foreach (var rawMetric in MetricSpool.GetConsumingEnumerable())
                {
                    shipMethod(rawMetric);
                }
            }
        }

        private void ShipMetricUDP(metric m)
        {
            udpClient = udpClient ?? new GraphiteUdpClient(config.Hostname, config.Port, config.Prefix + "." + pm.Hostname);
            var theMetric = FormatMetric(m);
            var path = MetricPath(theMetric);
            udpClient.Send(path, (int)m.value);
        }

        private void ShipMetricTCP(metric m)
        {
            bool sent = false;
            while (!sent)
            {
                try
                {
                    tcpClient = tcpClient ?? new MetricusGraphiteTcpClient(config.Hostname, config.Port, config.Debug);
                    var theMetric = FormatMetric(m);
                    var path = MetricPath(theMetric);
                    tcpClient.Send(path, m.value);
                    sent = true;
                }
                catch (Exception e) //There has been some sort of error with the client
                {
                    Console.WriteLine(e);
                    if (tcpClient != null) tcpClient.Dispose();
                    tcpClient = null;
                    System.Threading.Thread.Sleep(5000);
                }
            }
        }

        private string MetricPath(metric m)
        {



            // change advanced.env>.##localadv1##.asp_net_applications.errors_total_sec 0 1706667855
            // into advanced.env>.##localadv1##.<servername>.asp_net_applications.errors_total_sec 0 1706667855

            // prefix
            //   site
            //      servername
            //          category
            //              counter
            //                  value

            // old: natasha.production.stacks.
            //      <stackname>
            //          .counter
            //                 .value

            var bld = new StringBuilder();
            
            AppendIf(bld, config.Prefix);
            AppendIf(bld, m.site);
            AppendIf(bld, m.serverName);
            AppendIf(bld, m.category);
            AppendIf(bld, m.instance);
            if (!string.IsNullOrEmpty(m.type))
            {
                bld.Append(m.type);
            }

            return bld.ToString();
        }

        private void AppendIf(StringBuilder builder, string val)
        {
            if (!string.IsNullOrEmpty(val))
            {
                builder.Append(val);
                builder.Append(".");
            }
        }

        private metric FormatMetric(metric m)
        {
            m.category = Regex.Replace(m.category, FormatReplacementMatch, FormatReplacementString);
            m.type = Regex.Replace(m.type, FormatReplacementMatch, FormatReplacementString);

            
            if (string.IsNullOrEmpty(m.instance))
            {
                m.instance = "_total";
            }
            else if(!m.instance.Equals(m.site, StringComparison.OrdinalIgnoreCase))
            {
                m.instance = Regex.Replace(m.instance, FormatReplacementMatch, FormatReplacementString);
            }
            else
            {
                m.instance = null;
            }

            if (!string.IsNullOrEmpty(m.site))
            {
                m.site = Regex.Replace(m.site, FormatReplacementMatch, FormatReplacementString);
            }


            return m;
        }

        public class MetricusGraphiteTcpClient : IDisposable
        {
            public bool IsDebug { get; }
            public string GraphiteHostname { get; }
            public TcpClient Client { get; }
            public int Port { get; }

            public MetricusGraphiteTcpClient(string graphiteHostname, int port, bool isDebug = false)
            {
                this.IsDebug = isDebug;
                GraphiteHostname = graphiteHostname;
                this.Port = port;
                Port = port;
                Client = new TcpClient(GraphiteHostname, Port);
            }

            public void Send(string path, float value)
            {
                Send(path, value, DateTime.UtcNow);
            }

            public void Send(string path, float value, DateTime timeStamp)
            {
                var graphiteMessage =
                    $"{path} {value} {ServiceStack.Text.DateTimeExtensions.ToUnixTime(timeStamp.ToUniversalTime())}\n";
                
                if (IsDebug)
                {
                    Console.WriteLine($"Sending msg: {graphiteMessage}");
                }

                var message = Encoding.UTF8.GetBytes(graphiteMessage);
                Client.GetStream().Write(message, 0, message.Length);
            }

            public void Dispose()
            {
                Dispose(true);
                GC.SuppressFinalize(this);
            }

            protected virtual void Dispose(bool disposing)
            {
                if (!disposing) return;
                if (Client != null)
                    Client.Close();
            }

        }

    }
}

