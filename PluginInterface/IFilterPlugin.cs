using System.Collections.Generic;

namespace Metricus.Plugin
{
  public interface IFilterPlugin
  {
    List<metric> Work(List<metric> m);
  }
}
