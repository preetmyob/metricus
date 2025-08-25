using System.Collections.Generic;

namespace Metricus.Plugin
{
  public interface IOutputPlugin
  {
    void Work(List<metric> m);
  }
}
