package chart;

class ChartEvent
{
	public var name:String;
	public var time:Float;
	public var params:Array<Dynamic>;

	public function new(name:String, time:Float, ?params:Array<Dynamic>)
	{
		this.name = name;
		this.time = time;
		this.params = params == null ? [] : params;
	}
}
