using System;
using System.Timers;
using Metricus.Plugin;
using System.Threading;
using System.IO;
using System.Collections.Generic;
using System.Net.Http;
using Topshelf;
using ServiceStack.Text;
using System.Threading.Tasks;

namespace Metricus
{
    class MetricusConfig
	{
		public string Host { get; set; }
		public int Interval { get; set; }
		public List<String> ActivePlugins { get; set; }
	}

	class MetricusService : ServiceControl
	{
		readonly System.Timers.Timer _timer;

		private MetricusConfig config;
		private PluginManager pluginManager;
        private Object workLocker = new Object();

		public MetricusService() 
		{
			config = JsonSerializer.DeserializeFromString<MetricusConfig> (File.ReadAllText ("config.json"));

            config.Host = GetHostNameAsync().GetAwaiter().GetResult() ?? config.Host;

            Console.WriteLine("Config loaded: {0}", config.Dump() );

			_timer = new System.Timers.Timer (config.Interval);
			_timer.Elapsed += new ElapsedEventHandler (Tick);
			pluginManager = new PluginManager (config.Host);
		}

        async Task<string> GetHostNameAsync()
        {
            // Metadata service endpoint on the local instance
            var metadataServiceEndpoint = "http://169.254.169.254/latest/meta-data/";

            try
            {
				Console.WriteLine($"Attempting to get hostname from AWS EC2 Metadata endpoint {metadataServiceEndpoint}");
                using (var httpClient = new HttpClient())
                {
                    // Define the tasks for each metadata request
                    var instanceIdTask = httpClient.GetStringAsync(metadataServiceEndpoint + "instance-id");
                    var localHostnameTask = httpClient.GetStringAsync(metadataServiceEndpoint + "local-hostname");
                    //Task<string> publicHostnameTask = httpClient.GetStringAsync(metadataServiceEndpoint + "public-hostname");

                    // Wait for all tasks to complete
                    await Task.WhenAll(instanceIdTask, localHostnameTask);

                    // Get results from completed tasks
                    var instanceId = instanceIdTask.Result;
                    var localHostname = localHostnameTask.Result;

                    // Format the string
                    return $"{instanceId}-{localHostname}";
                }
            }
            catch (HttpRequestException ex)
            {
                Console.WriteLine($"Warning: {ex.Message}. This is probably because you're running it on a non EC2. Default to MachineName in environment");
                return Environment.MachineName;
            }
        }

        public bool Start(HostControl hostControl)
		{
			this.LoadPlugins();
			_timer.Start();
			return true;
		}

		public bool StartRaw()
		{
			this.LoadPlugins();
			_timer.Start ();
			return true;
		}

		public bool Stop(HostControl hostControl)
		{
			_timer.Stop ();
			return true;
		}

		private void LoadPlugins()
		{
			string[] dllFileNames = null;

			if (Directory.Exists ("Plugins")) {
				Console.WriteLine ("Loading plugins");
				foreach (var dir in Directory.GetDirectories("Plugins")) {

					dllFileNames = Directory.GetFiles ("Plugins", "*.dll");
				}
			} else {
				Console.WriteLine ("Plugin directory not found!");
			}

			foreach (var plugin in dllFileNames) {
				Console.WriteLine (plugin);
			}


			foreach (var dir in Directory.GetDirectories("Plugins")) 
			{
				var inputPlugins = PluginLoader<IInputPlugin>.GetPlugins (dir);
				Console.WriteLine (dir.ToString());
				foreach (Type type in inputPlugins) {
					Console.WriteLine (type.Assembly.GetName ().Name);
					if (config.ActivePlugins.Contains (type.Assembly.GetName ().Name)) {
						Console.WriteLine ("Loading plugin {0}", type.Assembly.GetName ().Name);
						Activator.CreateInstance (type, pluginManager);
					}
				}

				var outputPlugins = PluginLoader<IOutputPlugin>.GetPlugins (dir);
				foreach (Type type in outputPlugins) {
					if (config.ActivePlugins.Contains (type.Assembly.GetName ().Name)) {
						Console.WriteLine ("Loading plugin {0}", type.Assembly.GetName ().Name);
						Activator.CreateInstance (type, pluginManager);
					}
				}

				var filterPlugins = PluginLoader<IFilterPlugin>.GetPlugins (dir);
				foreach (Type type in filterPlugins) {
					if (config.ActivePlugins.Contains (type.Assembly.GetName ().Name)) {
						Console.WriteLine ("Loading plugin {0}", type.Assembly.GetName ().Name);
						Activator.CreateInstance (type, pluginManager);
					}
				}
			}
		}

		private void Tick (object source, ElapsedEventArgs e)
		{
			Console.WriteLine ("Tick");
            if (Monitor.TryEnter(workLocker))
            {
                try
                {
                    var start = DateTime.Now;
                    this.pluginManager.Tick();
                    var elapsed = DateTime.Now - start;
                }
                finally
                {
                    Monitor.Exit(workLocker);
                }
            }
            else
                return;
		}
	}

	public class Program
	{
		public static void Main (string[] args)
		{
			Directory.SetCurrentDirectory(AppDomain.CurrentDomain.BaseDirectory);
			HostFactory.Run (x =>
			{
				x.Service<MetricusService>();
				x.RunAsLocalSystem();			
				x.SetServiceName("Metricus");
				x.SetDescription("Metric collection and ouput service");
				//x.UseNLog();
			});
		}
	}
}
