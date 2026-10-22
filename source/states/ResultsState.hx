package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class ResultsState extends FlxState
{
	public var songName(default, null):String;
	public var songDifficulty(default, null):String;
	public var score(default, null):Int;
	public var accuracy(default, null):Float;
	public var misses(default, null):Int;
	public var sicks(default, null):Int;
	public var goods(default, null):Int;
	public var bads(default, null):Int;
	public var shits(default, null):Int;

	public function new(songName:String, difficulty:String, score:Int, accuracy:Float, misses:Int, sicks:Int, goods:Int, bads:Int, shits:Int)
	{
		super();
		this.songName = songName;
		this.songDifficulty = difficulty.toLowerCase();
		this.score = score;
		this.accuracy = accuracy;
		this.misses = misses;
		this.sicks = sicks;
		this.goods = goods;
		this.bads = bads;
		this.shits = shits;
	}

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF0B0F1A;
		buildUi();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.A))
			FlxG.switchState(new FreeplayState());
	}

	function buildUi():Void
	{
		var panel = new FlxSprite(200, 170);
		panel.makeGraphic(880, 430, 0xFF131A2A);
		panel.alpha = 0.8;
		add(panel);

		var title = new FlxText(0, 36, FlxG.width, "RESULTS", 56);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		var subtitle = new FlxText(0, 108, FlxG.width, '${songName.toUpperCase()}  -  ${songDifficulty.toUpperCase()}', 22);
		subtitle.alignment = FlxTextAlign.CENTER;
		subtitle.color = 0xFF8A93B2;
		add(subtitle);

		addStatRow("SCORE", Std.string(score), 216, FlxColor.WHITE);
		addStatRow("ACCURACY", '${formatAccuracy(accuracy)}%', 264, 0xFF88DDFF);
		addStatRow("MISSES", Std.string(misses), 312, 0xFFFF6677);

		var judgmentsHeader = new FlxText(280, 382, 520, "JUDGMENTS", 16);
		judgmentsHeader.color = 0xFF66708F;
		add(judgmentsHeader);

		addStatRow("SICK", Std.string(sicks), 418, 0xFF00E5FF);
		addStatRow("GOOD", Std.string(goods), 458, 0xFF22FF44);
		addStatRow("BAD", Std.string(bads), 498, 0xFFFFAA00);
		addStatRow("SHIT", Std.string(shits), 538, 0xFFB36BFF);

		var rank = rankFor(accuracy);
		var rankHeader = new FlxText(920, 216, 140, "RANK", 18);
		rankHeader.alignment = FlxTextAlign.CENTER;
		rankHeader.color = 0xFF66708F;
		add(rankHeader);

		var rankText = new FlxText(920, 244, 140, rank, 120);
		rankText.alignment = FlxTextAlign.CENTER;
		rankText.color = rankColor(rank);
		add(rankText);

		var hint = new FlxText(0, FlxG.height - 48, FlxG.width, "ENTER / ACCEPT: FREEPLAY", 18);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = 0xFF777F9A;
		add(hint);
	}

	function addStatRow(label:String, value:String, y:Float, valueColor:Int):Void
	{
		var labelText = new FlxText(280, y, 280, label, 24);
		labelText.color = 0xFF8A93B2;
		add(labelText);

		var valueText = new FlxText(560, y, 240, value, 24);
		valueText.alignment = FlxTextAlign.RIGHT;
		valueText.color = valueColor;
		add(valueText);
	}

	static function rankFor(accuracy:Float):String
	{
		if (accuracy >= 95)
			return "S";
		if (accuracy >= 85)
			return "A";
		if (accuracy >= 75)
			return "B";
		if (accuracy >= 65)
			return "C";

		return "F";
	}

	static function rankColor(rank:String):FlxColor
	{
		return switch (rank)
		{
			case "S": 0xFFFFD75E;
			case "A": 0xFF00E5FF;
			case "B": 0xFF22FF66;
			case "C": 0xFFFFAA33;
			default: 0xFFFF4455;
		}
	}

	static function formatAccuracy(accuracy:Float):String
	{
		return Std.string(Math.round(accuracy * 100) / 100);
	}
}
