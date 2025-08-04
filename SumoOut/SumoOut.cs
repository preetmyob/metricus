using System;
using System.Net.Http;
using System.Text;
using Metricus.Plugin;

namespace Metricus.Plugins;

public class SumoOut(PluginManager pm) : GraphiteOut(pm)
{
    protected override void WorkMetrics()
    {
        bool flag = false;
        while (!flag)
        {
            foreach (metric consuming in MetricSpoolEnumerable)
            {
                ShipToSumo(consuming);
            }
        }
    }

    private void ShipToSumo(metric metric)
    {
        // Build Graphite format: <metric.path> <value> <timestamp>
        var metricPath = $"{(metric.site ?? "default")}.{metric.category}.{metric.type}.{metric.instance}".Replace(" ", "_");
        var timestampSeconds = ((DateTimeOffset)metric.timestamp).ToUnixTimeSeconds();
        var graphiteLine = $"{metricPath} {metric.value} {timestampSeconds}";

        var content = new StringContent(graphiteLine, Encoding.UTF8, "text/plain");

        try
        {
            using var client = new HttpClient();
            var sumoHttpUrl =
                "https://collectors.au.sumologic.com/receiver/v1/http/ZaVnC4dhaV1bYaWGuS_ql2MSZ_11DhKlyvQC2jhwl0lt2TMJTjhekwJic-d1DFC6uzn1TOp4Ah96LZgtgeBQKN8GV33fEiRNBpU0jV2lmrv5yRuZZCnKAg==";
            var  response = client.PostAsync(sumoHttpUrl, content).GetAwaiter().GetResult();
            response.EnsureSuccessStatusCode();
            Console.WriteLine("Metric sent successfully.");
        }
        catch (Exception ex)
        {
            Console.WriteLine("Failed to send metric: " + ex.Message);
        }
    }
}