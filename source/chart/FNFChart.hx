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
	public var strumLines:Array<StrumLineData> = [];

	public function new() {}

	public function getStrumLine(index:Int):StrumLineData
	{
		return index >= 0 && index < strumLines.length ? strumLines[index] : null;
	}

	public function getPlayerStrumLines():Array<StrumLineData>
	{
		var result:Array<StrumLineData> = [];

		for (line in strumLines)
		{
			if (line.isPlayer)
				result.push(line);
		}

		return result;
	}

	public function getOpponentStrumLines():Array<StrumLineData>
	{
		var result:Array<StrumLineData> = [];

		for (line in strumLines)
		{
			if (line.isOpponent)
				result.push(line);
		}

		return result;
	}

	public function getPrimaryPlayerLine():StrumLineData
	{
		for (line in strumLines)
		{
			if (line.isPlayer)
				return line;
		}

		return strumLines.length > 0 ? strumLines[strumLines.length - 1] : null;
	}

	public function getPrimaryOpponentLine():StrumLineData
	{
		for (line in strumLines)
		{
			if (line.isOpponent)
				return line;
		}

		return strumLines.length > 0 ? strumLines[0] : null;
	}

	public function getNotesForStrumLine(index:Int):Array<ChartNote>
	{
		var result:Array<ChartNote> = [];

		for (note in notes)
		{
			if (note.strumLineIndex == index)
				result.push(note);
		}

		return result;
	}

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
