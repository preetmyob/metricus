// Decompiled with JetBrains decompiler
// Type: Metricus.Plugin.ICategoryFilter
// Assembly: SitesFilter, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: F072D3F1-B3C6-4757-A19E-96E7215D2930
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\Plugins\SitesFilter\SitesFilter.dll

using System.Collections.Generic;

#nullable disable
namespace Metricus.Plugin
{
  internal interface ICategoryFilter
  {
    List<metric> Filter(List<metric> metrics, string categoryName, bool preserveOriginal);
  }
}
