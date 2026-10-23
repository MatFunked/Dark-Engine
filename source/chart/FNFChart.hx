package chart;

class FNFChart
{
	public var songName:String = "";
	public var bpm:Float = 0;
	public var speed:Float = 1;
	public var player1:String = "bf";
	public var player2:String = "dad";
	public var playerCharacter:String = "bf";
	public var opponentCharacter:String = "dad";
	public var gfVersion:String = "gf";
	public var stage:String = "stage";
	public var needsVoices:Bool = true;
	public var offset:Float = 0;
	public var playerVocalsSuffix:String = "";
	public var opponentVocalsSuffix:String = "";
	public var sections:Array<ChartSection> = [];
	public var bpmChanges:Array<BpmChange> = [];
	public var notes:Array<ChartNote> = [];
	public var events:Array<ChartEvent> = [];

	public function new() {}

	public function getPlayerNotes():Array<ChartNote>
	{
		var result:Array<ChartNote> = [];

		for (note in notes)
		{
			if (note.isPlayer)
				result.push(note);
		}

		return result;
	}

	public function getOpponentNotes():Array<ChartNote>
	{
		var result:Array<ChartNote> = [];

		for (note in notes)
		{
			if (!note.isPlayer)
				result.push(note);
		}

		return result;
	}
}
