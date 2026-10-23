package minigames;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class UndertaleMinigame extends BaseMinigame
{
	static inline var BAR_WIDTH:Float = 760;
	static inline var BAR_HEIGHT:Float = 36;
	static inline var CURSOR_WIDTH:Float = 10;

	var bar:FlxSprite;
	var target:FlxSprite;
	var cursor:FlxSprite;
	var timerText:FlxText;
	var statusText:FlxText;
	var cursorProgress:Float = 0;
	var cursorSpeed:Float;
	var targetWidth:Float;

	public function new(context:MinigameContext)
	{
		super(context);
	}

	override public function onStart():Void
	{
		cursorSpeed = speedForDifficulty(context.difficulty);
		targetWidth = widthForDifficulty(context.difficulty);

		var title = new FlxText(0, 64, FlxG.width, "UNDERTALE", 42);
		title.alignment = FlxTextAlign.CENTER;
		title.color = 0xFFFFFFFF;
		add(title);

		statusText = new FlxText(0, 116, FlxG.width, "STOP THE CURSOR IN THE GREEN ZONE", 18);
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.color = 0xFFAABBCC;
		add(statusText);

		var barX = (FlxG.width - BAR_WIDTH) * 0.5;
		var barY = FlxG.height * 0.54;

		bar = new FlxSprite(barX, barY);
		bar.makeGraphic(Std.int(BAR_WIDTH), Std.int(BAR_HEIGHT), 0xFF1A2030);
		add(bar);

		var targetX = barX + (BAR_WIDTH - targetWidth) * (0.2 + Math.random() * 0.6);
		target = new FlxSprite(targetX, barY);
		target.makeGraphic(Std.int(targetWidth), Std.int(BAR_HEIGHT), 0xFF33DD66);
		add(target);

		cursor = new FlxSprite(barX, barY - 6);
		cursor.makeGraphic(Std.int(CURSOR_WIDTH), Std.int(BAR_HEIGHT + 12), 0xFFFFE066);
		add(cursor);

		timerText = new FlxText(0, barY + 64, FlxG.width, "", 20);
		timerText.alignment = FlxTextAlign.CENTER;
		timerText.color = 0xFF99AACC;
		add(timerText);

		var hint = new FlxText(0, FlxG.height - 72, FlxG.width, "Z / SPACE / ENTER: STOP", 18);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		add(hint);
	}

	override public function onUpdate(elapsed:Float):Void
	{
		cursorProgress += elapsed * cursorSpeed;
		var phase = Math.abs((cursorProgress % 2) - 1);
		cursor.x = bar.x + phase * (BAR_WIDTH - cursor.width);
		timerText.text = '${Math.ceil(remaining)}s';

		if (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER)
		{
			var center = cursor.x + cursor.width * 0.5;

			if (center >= target.x && center <= target.x + target.width)
				win();
			else
				lose();
		}
	}

	override public function onWin():Void
	{
		statusText.text = "PERFECT";
		statusText.color = 0xFF66FF99;
		cursor.color = 0xFF66FF99;
	}

	override public function onLose():Void
	{
		statusText.text = "MISSED";
		statusText.color = 0xFFFF5566;
		cursor.color = 0xFFFF5566;
	}

	static function speedForDifficulty(difficulty:String):Float
	{
		switch (difficulty == null ? "" : difficulty.toLowerCase())
		{
			case "easy":
				return 0.55;
			case "hard":
				return 1.15;
			default:
				return 0.8;
		}
	}

	static function widthForDifficulty(difficulty:String):Float
	{
		switch (difficulty == null ? "" : difficulty.toLowerCase())
		{
			case "easy":
				return 180;
			case "hard":
				return 70;
			default:
				return 120;
		}
	}
}
