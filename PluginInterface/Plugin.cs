namespace Metricus.Plugin
{
  public abstract class Plugin
  {
    private PluginManager pm;

    public Plugin(PluginManager pm)
    {
      this.pm = pm;
      pm.RegisterPlugin(this);
    }
  }
}
