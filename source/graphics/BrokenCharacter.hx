package graphics;

import flixel.FlxSprite;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

class BrokenCharacter
{
	public static inline var NAME:String = "broken";
	public static inline var WIDTH:Int = 180;
	public static inline var HEIGHT:Int = 360;

	static inline var HEAD_COLOR:Int = 0xFF666C78;
	static inline var BODY_COLOR:Int = 0xFF525866;
	static inline var LIMB_COLOR:Int = 0xFF464B57;

	public static function isRequested(name:String):Bool
	{
		return name == null || StringTools.trim(name) == "" || name.toLowerCase() == NAME;
	}

	public static function apply(sprite:FlxSprite):Void
	{
		var bitmap = new BitmapData(WIDTH, HEIGHT, true, 0x00000000);

		fill(bitmap, 62, 20, 56, 56, HEAD_COLOR);
		fill(bitmap, 78, 68, 24, 20, BODY_COLOR);
		fill(bitmap, 42, 84, 96, 150, BODY_COLOR);
		fill(bitmap, 14, 92, 26, 152, LIMB_COLOR);
		fill(bitmap, 140, 92, 26, 152, LIMB_COLOR);
		fill(bitmap, 48, 232, 34, 120, LIMB_COLOR);
		fill(bitmap, 98, 232, 34, 120, LIMB_COLOR);
		fill(bitmap, 38, 344, 44, 16, BODY_COLOR);
		fill(bitmap, 98, 344, 44, 16, BODY_COLOR);

		sprite.loadGraphic(bitmap);
		sprite.antialiasing = false;
		sprite.updateHitbox();
	}

	static function fill(bitmap:BitmapData, x:Int, y:Int, width:Int, height:Int, color:Int):Void
	{
		bitmap.fillRect(new Rectangle(x, y, width, height), color);
	}
}
