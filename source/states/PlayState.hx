package states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class PlayState extends FlxState
{
	override public function create():Void
	{
		super.create();

		bgColor = 0xFF102010;

		var label = new FlxText(0, 0, 0, "PLAY STATE", 48);
		label.color = FlxColor.WHITE;
		label.screenCenter();
		add(label);

		var hint = new FlxText(0, 0, 0, "PRESS ESC TO RETURN TO MENU", 16);
		hint.color = FlxColor.GRAY;
		hint.screenCenter();
		hint.y = FlxG.height - 40;
		add(hint);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE)
			FlxG.switchState(MainMenuState.new);
	}
}
