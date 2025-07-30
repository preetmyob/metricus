using System;
using System.Net.Sockets;
using System.Text;

namespace Metricus.Plugins;

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
        string s = string.Format("{0} {1} {2}\n", (object) path, (object) value, (object) ServiceStack.Text.DateTimeExtensions.ToUnixTime(timeStamp.ToUniversalTime()));
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