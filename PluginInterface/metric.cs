using System;

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
	    return string.Format("{{'site':'{0}','category':'{1}','type':'{2}','instance':'{3}','value':{4},'timestamp':'{5:yyyy-MM-dd HH:mm:ss}','interval':{6}}}", (object) this.site, (object) this.category, (object) this.type, (object) this.instance, (object) this.value, (object) this.timestamp, (object) this.interval);
	  }
	}
}
