// Decompiled with JetBrains decompiler
// Type: Metricus.PluginLoader`1
// Assembly: metricus, Version=1.0.8808.32162, Culture=neutral, PublicKeyToken=null
// MVID: 63B9C274-3255-41BD-932E-183063283854
// Assembly location: C:\temp\metricus-0.5.0\metricus-0.5.0\metricus.exe

using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

#nullable disable
namespace Metricus
{
  public static class PluginLoader<T>
  {
    public static ICollection<Type> GetPlugins(string path)
    {
      Directory.SetCurrentDirectory(AppDomain.CurrentDomain.BaseDirectory);
      if (!Directory.Exists(path))
        return (ICollection<Type>) null;
      string[] files = Directory.GetFiles(path, "*.dll");
      ICollection<Assembly> assemblies = (ICollection<Assembly>) new List<Assembly>(files.Length);
      foreach (string assemblyFile in files)
      {
        Assembly assembly = Assembly.Load(AssemblyName.GetAssemblyName(assemblyFile));
        assemblies.Add(assembly);
      }
      Type type1 = typeof (T);
      ICollection<Type> plugins = (ICollection<Type>) new List<Type>();
      foreach (Assembly assembly in (IEnumerable<Assembly>) assemblies)
      {
        if (assembly != (Assembly) null)
        {
          foreach (Type type2 in assembly.GetTypes())
          {
            if (!type2.IsInterface && !type2.IsAbstract && type2.GetInterface(type1.FullName) != (Type) null)
              plugins.Add(type2);
          }
        }
      }
      return plugins;
    }
  }
}
