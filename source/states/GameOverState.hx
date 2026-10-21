package states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class GameOverState extends FlxState
{
	public var songFolder(default, null):String;
	public var songDifficulty(default, null):String;

	public function new(?songFolder:String = "emma", ?difficulty:String = "hard")
	{
		super();
		this.songFolder = songFolder;
		this.songDifficulty = difficulty.toLowerCase();
	}

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF180A0F;

		var title = new FlxText(0, 0, FlxG.width, "GAME OVER", 64);
		title.alignment = FlxTextAlign.CENTER;
		title.color = 0xFFFF3344;
		title.screenCenter();
		title.y = FlxG.height * 0.4 - title.height * 0.5;
		add(title);

		var prompt = new FlxText(0, 0, FlxG.width, "ENTER / R: RETRY    ESC: MENU", 20);
		prompt.alignment = FlxTextAlign.CENTER;
		prompt.color = FlxColor.GRAY;
		prompt.screenCenter();
		prompt.y = FlxG.height * 0.6 - prompt.height * 0.5;
		add(prompt);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.R)
			FlxG.switchState(new PlayState(songFolder, songDifficulty));
		else if (FlxG.keys.justPressed.ESCAPE)
			FlxG.switchState(new MainMenuState());
	}
}
