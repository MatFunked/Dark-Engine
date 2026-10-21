package notes;

class TimingWindows
{
	public var sickWindow:Float;
	public var goodWindow:Float;
	public var badWindow:Float;
	public var missWindow:Float;

	public function new(sickWindow:Float = 45.0, goodWindow:Float = 90.0, badWindow:Float = 135.0, missWindow:Float = 180.0)
	{
		if (sickWindow < 0 || sickWindow > goodWindow || goodWindow > badWindow || badWindow > missWindow)
			throw "TimingWindows must satisfy 0 <= sick <= good <= bad <= miss";

		this.sickWindow = sickWindow;
		this.goodWindow = goodWindow;
		this.badWindow = badWindow;
		this.missWindow = missWindow;
	}

	public function judge(noteTime:Float, songTime:Float):Judgment
	{
		return judgeOffset(noteTime - songTime);
	}

	public function judgeOffset(offset:Float):Judgment
	{
		var distance = Math.abs(offset);

		if (distance <= sickWindow)
			return Judgment.SICK;
		if (distance <= goodWindow)
			return Judgment.GOOD;
		if (distance <= badWindow)
			return Judgment.BAD;

		return Judgment.MISS;
	}

	public inline function canHit(noteTime:Float, songTime:Float):Bool
	{
		return Math.abs(noteTime - songTime) <= missWindow;
	}
}
