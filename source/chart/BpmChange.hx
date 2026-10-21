package chart;

class BpmChange
{
	public var time:Float;
	public var bpm:Float;
	public var sectionIndex:Int;

	public function new(time:Float, bpm:Float, sectionIndex:Int = -1)
	{
		this.time = time;
		this.bpm = bpm;
		this.sectionIndex = sectionIndex;
	}
}
