// Decompiled with JetBrains decompiler
// Type: Metricus.Program
// Assembly: metricus, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: 63B9C274-3255-41BD-932E-183063283854
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\metricus.exe

using System;
using System.IO;
using Topshelf;
using Topshelf.HostConfigurators;

#nullable disable
namespace Metricus
{
  public class Program
  {
    public static void Main(string[] args)
    {
      Directory.SetCurrentDirectory(AppDomain.CurrentDomain.BaseDirectory);
      int num = (int) HostFactory.Run((Action<HostConfigurator>) (x =>
      {
        x.Service<MetricusService>();
        x.RunAsLocalSystem();
        x.SetServiceName("Metricus");
        x.SetDescription("Metric collection and ouput service");
      }));
    }
  }
}
