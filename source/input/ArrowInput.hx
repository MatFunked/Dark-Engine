package input;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;

class ArrowInput
{
	public var bindings(default, null):Map<NoteDirection, Array<FlxKey>>;

	public function new()
	{
		bindings = new Map();
		resetToDefaults();
	}

	public function resetToDefaults():Void
	{
		bind(NoteDirection.LEFT, [FlxKey.LEFT]);
		bind(NoteDirection.DOWN, [FlxKey.DOWN]);
		bind(NoteDirection.UP, [FlxKey.UP]);
		bind(NoteDirection.RIGHT, [FlxKey.RIGHT]);
	}

	public function bind(direction:NoteDirection, keys:Array<FlxKey>):Void
	{
		bindings.set(direction, keys.copy());
	}

	public function addBinding(direction:NoteDirection, key:FlxKey):Void
	{
		var keys = bindings.get(direction);

		if (keys == null)
		{
			keys = [];
			bindings.set(direction, keys);
		}

		if (!keys.contains(key))
			keys.push(key);
	}

	public function isPressed(direction:NoteDirection):Bool
	{
		var keys = bindings.get(direction);
		return keys != null && FlxG.keys.anyPressed(keys);
	}

	public function justPressed(direction:NoteDirection):Bool
	{
		var keys = bindings.get(direction);
		return keys != null && FlxG.keys.anyJustPressed(keys);
	}

	public function justReleased(direction:NoteDirection):Bool
	{
		var keys = bindings.get(direction);
		return keys != null && FlxG.keys.anyJustReleased(keys);
	}

	public function pressedDirections():Array<NoteDirection>
	{
		var result:Array<NoteDirection> = [];

		for (direction in NoteDirection.all())
		{
			if (isPressed(direction))
				result.push(direction);
		}

		return result;
	}

	public function justPressedDirections():Array<NoteDirection>
	{
		var result:Array<NoteDirection> = [];

		for (direction in NoteDirection.all())
		{
			if (justPressed(direction))
				result.push(direction);
		}

		return result;
	}

}
