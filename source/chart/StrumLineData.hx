package chart;

class StrumLineData
{
	public var index:Int;
	public var keyCount:Int;
	public var position:String;
	public var isPlayer:Bool;
	public var isOpponent:Bool;
	public var characters:Array<String>;
	public var vocalsSuffix:String;
	public var notes:Array<ChartNote> = [];
	public var keys:Array<String> = [];
	public var strumLinePos:Float = -1;
	public var strumScale:Float = 1;
	public var visible:Bool = true;
	public var scrollSpeed:Float = 1;

	public function new(index:Int, position:String, keyCount:Int = 4, ?characters:Array<String>, vocalsSuffix:String = "")
	{
		this.index = index;
		this.position = normalizePosition(position);
		this.keyCount = Std.int(Math.max(1, Math.min(12, keyCount)));
		this.characters = characters == null ? [] : characters.copy();
		this.vocalsSuffix = vocalsSuffix == null ? "" : vocalsSuffix;
		this.isPlayer = isPlayerPosition(this.position);
		this.isOpponent = isOpponentPosition(this.position);
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
		if (isPlayer)
			return "PLAYER";
		if (isOpponent)
			return "OPPONENT";

		return "EXTRA";
	}

	public static function normalizePosition(value:String):String
	{
		return value == null ? "" : StringTools.trim(value).toLowerCase();
	}

	public static function isPlayerPosition(position:String):Bool
	{
		return position == "bf" || position == "boyfriend" || position == "player" || position == "both" || position == "extra";
	}

	public static function isOpponentPosition(position:String):Bool
	{
		return position == "dad" || position == "opponent";
	}
}
