package play;

import chart.StrumLineData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import graphics.SparrowCharacter;
import input.NoteDirection;

class StrumLine
{
	public var data(default, null):StrumLineData;
	public var index(default, null):Int;
	public var keyCount:Int;
	public var isPlayer:Bool;
	public var isOpponent:Bool;
	public var characters:Array<String>;
	public var vocalsSuffix:String;
	public var keys:Array<FlxKey> = [];
	public var centerX:Float = 0;
	public var laneWidth:Float = 0;
	public var baseY:Float = 0;
	public var baseReceptorColor:Int = 0xFF2A2A45;
	public var displayLabel:String = "";
	public var voiceChannel:Int = -1;
	public var receptors:Array<FlxSprite> = [];
	public var flashTimers:Array<Float> = [];
	public var labelTexts:Array<FlxText> = [];
	public var sideLabel:FlxText;
	public var character:SparrowCharacter;

	public function new(data:StrumLineData)
	{
		this.data = data;
		this.index = data.index;
		this.keyCount = data.keyCount;
		this.isPlayer = data.isPlayer;
		this.isOpponent = data.isOpponent;
		this.characters = data.characters.copy();
		this.vocalsSuffix = data.vocalsSuffix;

		for (i in 0...keyCount)
		{
			receptors.push(null);
			flashTimers.push(0);
			keys.push(FlxKey.NONE);
		}
	}

	public inline function laneCenter(lane:Int):Float
	{
		return centerX + (lane - (keyCount - 1) * 0.5) * laneWidth;
	}

	public function setKey(lane:Int, key:FlxKey):Void
	{
		if (lane < 0 || lane >= keys.length)
			return;

		keys[lane] = key;
	}

	public function isPressed(lane:Int):Bool
	{
		if (lane < 0 || lane >= keys.length || keys[lane] == FlxKey.NONE)
			return false;

		return FlxG.keys.anyPressed([keys[lane]]);
	}

	public function justPressed(lane:Int):Bool
	{
		if (lane < 0 || lane >= keys.length || keys[lane] == FlxKey.NONE)
			return false;

		return FlxG.keys.anyJustPressed([keys[lane]]);
	}

	public function primaryCharacter():String
	{
		for (character in characters)
		{
			if (character != null && character != "")
				return character;
		}

		return isPlayer ? "bf" : "dad";
	}

	public function label():String
	{
		if (displayLabel != null && displayLabel != "")
			return displayLabel;

		return data.label();
	}

	public function sing(direction:NoteDirection):Void
	{
		if (character != null)
			character.sing(direction);
	}

	public function updateCharacter(elapsed:Float):Void
	{
		if (character != null)
			character.updateCharacter(elapsed);
	}
}
