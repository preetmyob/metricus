using System.Collections.Generic;

namespace Metricus.Plugin
{
  public interface IInputPlugin
  {
    List<metric> Work();
  }
}
