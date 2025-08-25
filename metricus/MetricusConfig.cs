// Decompiled with JetBrains decompiler
// Type: Metricus.MetricusConfig
// Assembly: metricus, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: 63B9C274-3255-41BD-932E-183063283854
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\metricus.exe

using System.Collections.Generic;

#nullable disable
namespace Metricus
{
  internal class MetricusConfig
  {
    public string Host { get; set; }

    public int Interval { get; set; }

    public List<string> ActivePlugins { get; set; }
  }
}
