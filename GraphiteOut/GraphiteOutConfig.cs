namespace Metricus.Plugins;

public class GraphiteOutConfig
{
    public string Hostname { get; set; }

    public string Prefix { get; set; }

    public int Port { get; set; }

    public string Protocol { get; set; }

    public int SendBufferSize { get; set; }

    public string Servername { get; set; }

    public bool Debug { get; set; }
}