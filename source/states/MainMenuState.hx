package states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class MainMenuState extends FlxState
{
	override public function create():Void
	{
		super.create();

		bgColor = 0xFF101820;

		var title = new FlxText(0, 0, 0, "DARK ENGINE", 64);
		title.color = FlxColor.WHITE;
		title.screenCenter();
		title.y = FlxG.height * 0.4 - title.height * 0.5;
		add(title);

		var prompt = new FlxText(0, 0, 0, "PRESS ENTER TO PLAY", 20);
		prompt.color = FlxColor.GRAY;
		prompt.screenCenter();
		prompt.y = FlxG.height * 0.6 - prompt.height * 0.5;
		add(prompt);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			FlxG.switchState(PlayState.new);
	}
}
