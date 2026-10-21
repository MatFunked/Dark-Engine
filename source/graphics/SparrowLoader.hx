package graphics;

import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.Assets;

class SparrowLoader
{
	public static function load(imagePath:String, xmlPath:String):FlxAtlasFrames
	{
		try
		{
			if (!Assets.exists(imagePath) || !Assets.exists(xmlPath))
				return null;

			var image = Assets.getBitmapData(imagePath);
			var xml = Assets.getText(xmlPath);

			if (image == null || xml == null || xml == "")
				return null;

			return FlxAtlasFrames.fromSparrow(image, xml);
		}
		catch (error:Dynamic)
		{
			return null;
		}
	}
}
