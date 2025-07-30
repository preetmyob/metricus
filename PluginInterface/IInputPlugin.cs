// Decompiled with JetBrains decompiler
// Type: Metricus.Plugin.IInputPlugin
// Assembly: PluginInterface, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: C34EB815-9AB9-443E-9926-31046FA85D8F
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\PluginInterface.dll

using System.Collections.Generic;

#nullable disable
namespace Metricus.Plugin
{
  public interface IInputPlugin
  {
    List<metric> Work();
  }
}
