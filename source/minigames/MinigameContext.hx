package minigames;

import flixel.FlxCamera;

class MinigameContext
{
	public var type(default, null):String;
	public var duration(default, null):Float;
	public var difficulty(default, null):String;
	public var params(default, null):Array<Dynamic>;
	public var camera(default, null):FlxCamera;

	public function new(type:String, duration:Float, difficulty:String, params:Array<Dynamic>, camera:FlxCamera)
	{
		this.type = type;
		this.duration = duration;
		this.difficulty = difficulty;
		this.params = params == null ? [] : params;
		this.camera = camera;
	}
}
