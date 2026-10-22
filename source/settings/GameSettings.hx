package settings;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import input.NoteDirection;

class GameSettings
{
	static inline var SAVE_NAME:String = "DarkEngine";
	static inline var SAVE_PATH:String = "DarkEngine";
	static inline var MIN_OFFSET:Float = -300;
	static inline var MAX_OFFSET:Float = 300;
	static inline var DEFAULT_OFFSET:Float = 0;
	static inline var DEFAULT_DOWNSCROLL:Bool = false;

	public static var leftKey:FlxKey = FlxKey.LEFT;
	public static var downKey:FlxKey = FlxKey.DOWN;
	public static var upKey:FlxKey = FlxKey.UP;
	public static var rightKey:FlxKey = FlxKey.RIGHT;
	public static var noteOffsetMs:Float = DEFAULT_OFFSET;
	public static var downscroll:Bool = DEFAULT_DOWNSCROLL;

	static var loaded:Bool = false;

	public static function load():Void
	{
		if (loaded)
			return;

		loaded = true;
		ensureSave();

		var data = FlxG.save.data;
		leftKey = readKey(data, "optionsLeftKey", FlxKey.LEFT);
		downKey = readKey(data, "optionsDownKey", FlxKey.DOWN);
		upKey = readKey(data, "optionsUpKey", FlxKey.UP);
		rightKey = readKey(data, "optionsRightKey", FlxKey.RIGHT);
		noteOffsetMs = clampOffset(readFloat(data, "optionsNoteOffsetMs", DEFAULT_OFFSET));
		downscroll = readBool(data, "optionsDownscroll", DEFAULT_DOWNSCROLL);
	}

	public static function save():Void
	{
		ensureSave();

		var data = FlxG.save.data;
		data.optionsLeftKey = cast leftKey;
		data.optionsDownKey = cast downKey;
		data.optionsUpKey = cast upKey;
		data.optionsRightKey = cast rightKey;
		data.optionsNoteOffsetMs = noteOffsetMs;
		data.optionsDownscroll = downscroll;
		FlxG.save.flush();
	}

	public static function getKey(direction:NoteDirection):FlxKey
	{
		return switch (direction)
		{
			case LEFT: leftKey;
			case DOWN: downKey;
			case UP: upKey;
			case RIGHT: rightKey;
		};
	}

	public static function setKey(direction:NoteDirection, key:FlxKey):Int
	{
		var previousKey = getKey(direction);
		var swappedIndex = -1;

		if (key == previousKey)
			return swappedIndex;

		for (other in NoteDirection.all())
		{
			if (other != direction && getKey(other) == key)
			{
				swappedIndex = cast(other, Int);
				setRawKey(other, previousKey);
				break;
			}
		}

		setRawKey(direction, key);
		save();
		return swappedIndex;
	}

	public static function resetToDefaults():Void
	{
		leftKey = FlxKey.LEFT;
		downKey = FlxKey.DOWN;
		upKey = FlxKey.UP;
		rightKey = FlxKey.RIGHT;
		noteOffsetMs = DEFAULT_OFFSET;
		downscroll = DEFAULT_DOWNSCROLL;
		save();
	}

	public static function setOffset(value:Float):Void
	{
		var clamped = clampOffset(value);

		if (clamped == noteOffsetMs)
			return;

		noteOffsetMs = clamped;
		save();
	}

	public static function setDownscroll(enabled:Bool):Void
	{
		if (downscroll == enabled)
			return;

		downscroll = enabled;
		save();
	}

	static function setRawKey(direction:NoteDirection, key:FlxKey):Void
	{
		switch (direction)
		{
			case LEFT: leftKey = key;
			case DOWN: downKey = key;
			case UP: upKey = key;
			case RIGHT: rightKey = key;
		}
	}

	static function ensureSave():Void
	{
		if (!FlxG.save.isBound)
			FlxG.save.bind(SAVE_NAME, SAVE_PATH);
	}

	static function clampOffset(value:Float):Float
	{
		return Math.round(Math.max(MIN_OFFSET, Math.min(MAX_OFFSET, value)));
	}

	static function readKey(data:Dynamic, field:String, fallback:FlxKey):FlxKey
	{
		var value:Dynamic = Reflect.field(data, field);

		if (value == null)
			return fallback;

		var key = Std.int(value);
		return key > 0 ? cast key : fallback;
	}

	static function readFloat(data:Dynamic, field:String, fallback:Float):Float
	{
		var value:Dynamic = Reflect.field(data, field);

		if (value == null)
			return fallback;

		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function readBool(data:Dynamic, field:String, fallback:Bool):Bool
	{
		var value:Dynamic = Reflect.field(data, field);

		if (value == null)
			return fallback;

		return value == true || Std.string(value).toLowerCase() == "true";
	}
}
