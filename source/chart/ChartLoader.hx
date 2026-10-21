package chart;

import openfl.utils.Assets;

class ChartLoader
{
	public static function load(path:String, ?timeMode:ChartTimeMode):FNFChart
	{
		var json = Assets.getText(path);

		if (json == null)
			throw 'Chart not found: $path';

		return FNFChartParser.parse(json, timeMode);
	}

	public static function loadSong(chartPath:String, ?metaPath:String, ?timeMode:ChartTimeMode):FNFChart
	{
		var json = Assets.getText(chartPath);

		if (json == null)
			throw 'Chart not found: $chartPath';

		var meta = metaPath == null ? null : loadMeta(metaPath);
		var metaBpm = meta == null ? 0.0 : numberValue(Reflect.field(meta, "bpm"), 0);
		var chart = FNFChartParser.parse(json, timeMode, metaBpm);

		if (meta != null)
		{
			var displayName = Reflect.field(meta, "displayName");

			if (displayName != null)
				chart.songName = Std.string(displayName);

			var needsVoices = Reflect.field(meta, "needsVoices");

			if (Std.isOfType(needsVoices, Bool))
				chart.needsVoices = cast needsVoices;
		}

		return chart;
	}

	static function loadMeta(path:String):Dynamic
	{
		var json = Assets.getText(path);

		if (json == null)
			return null;

		try
		{
			return haxe.Json.parse(json);
		}
		catch (error:Dynamic)
		{
			return null;
		}
	}

	static function numberValue(value:Dynamic, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}
