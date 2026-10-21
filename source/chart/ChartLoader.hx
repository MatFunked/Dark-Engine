package chart;

import openfl.Assets;

class ChartLoader
{
	public static function load(path:String, ?timeMode:ChartTimeMode):FNFChart
	{
		var json = Assets.getText(path);

		if (json == null)
			throw 'Chart not found: $path';

		return FNFChartParser.parse(json, timeMode);
	}
}
