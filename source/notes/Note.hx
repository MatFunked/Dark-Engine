package notes;

import input.NoteDirection;

class Note
{
	public var time:Float;
	public var direction:NoteDirection;
	public var sustainLength:Float;
	public var hit:Bool = false;
	public var judgment:Null<Judgment>;
	public var sustainActive:Bool = false;
	public var sustainDropped:Bool = false;
	public var sustainCompleted:Bool = false;
	public var sustainLastTick:Float = 0;
	public var strumLineIndex:Int = -1;
	public var lane:Int = -1;

	public function new(time:Float, direction:NoteDirection, sustainLength:Float = 0, strumLineIndex:Int = -1, lane:Int = -1)
	{
		this.time = time;
		this.direction = direction;
		this.sustainLength = Math.max(0, sustainLength);
		this.strumLineIndex = strumLineIndex;
		this.lane = lane < 0 ? cast(direction, Int) : lane;
	}

	public inline function hasSustain():Bool
	{
		return sustainLength > 0;
	}

	public inline function getEndTime():Float
	{
		return time + sustainLength;
	}
}
