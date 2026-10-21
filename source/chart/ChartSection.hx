package chart;

class ChartSection
{
	public var index:Int;
	public var startTime:Float;
	public var endTime:Float;
	public var bpm:Float;
	public var changeBpm:Bool;
	public var mustHitSection:Bool;
	public var lengthInSteps:Int = 16;
	public var beats:Float = 4;
	public var altAnim:Bool;
	public var gfSection:Bool;
	public var notes:Array<ChartNote> = [];

	public function new(index:Int, startTime:Float, endTime:Float, bpm:Float, mustHitSection:Bool, changeBpm:Bool)
	{
		this.index = index;
		this.startTime = startTime;
		this.endTime = endTime;
		this.bpm = bpm;
		this.mustHitSection = mustHitSection;
		this.changeBpm = changeBpm;
	}

	public inline function getDuration():Float
	{
		return endTime - startTime;
	}
}
