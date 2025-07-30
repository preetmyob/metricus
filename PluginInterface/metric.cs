// Decompiled with JetBrains decompiler
// Type: Metricus.Plugin.metric
// Assembly: PluginInterface, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: C34EB815-9AB9-443E-9926-31046FA85D8F
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\PluginInterface.dll

using System;

#nullable disable
namespace Metricus.Plugin
{
  public struct metric(
    string theCategory,
    string theType,
    string theInstance,
    float theValue,
    DateTime theTime,
    int theInterval = 10)
  {
    public float value = theValue;
    public DateTime timestamp = theTime;
    public string category = theCategory;
    public string type = theType;
    public string instance = theInstance;
    public int interval = theInterval;
    public string site = (string) null;

    public override string ToString()
    {
      return
        $"{{'site':'{(object)this.site}','category':'{(object)this.category}','type':'{(object)this.type}','instance':'{(object)this.instance}','value':{(object)this.value},'timestamp':'{(object)this.timestamp:yyyy-MM-dd HH:mm:ss}','interval':{(object)this.interval}}}";
    }
  }
}
