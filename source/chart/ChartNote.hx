package chart;

import input.NoteDirection;

class ChartNote
{
	public var time:Float;
	public var direction:NoteDirection;
	public var rawData:Int;
	public var sustainLength:Float;
	public var isPlayer:Bool;
	public var noteType:String;
	public var sectionIndex:Int;

	public function new(time:Float, direction:NoteDirection, rawData:Int, sustainLength:Float = 0, isPlayer:Bool = true,
			noteType:String = "", sectionIndex:Int = -1)
	{
		this.time = time;
		this.direction = direction;
		this.rawData = rawData;
		this.sustainLength = sustainLength;
		this.isPlayer = isPlayer;
		this.noteType = noteType;
		this.sectionIndex = sectionIndex;
	}

	public inline function getEndTime():Float
	{
		return time + sustainLength;
	}
}
