package states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class MainMenuState extends FlxState
{
	static var MENU_ITEMS:Array<String> = ["PLAY", "OPTIONS"];

	var selected:Int = 0;
	var menuTexts:Array<FlxText> = [];

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF101820;

		var title = new FlxText(0, 0, 0, "DARK ENGINE", 64);
		title.color = FlxColor.WHITE;
		title.screenCenter();
		title.y = FlxG.height * 0.4 - title.height * 0.5;
		add(title);

		for (i in 0...MENU_ITEMS.length)
		{
			var text = new FlxText(0, 432 + i * 58, FlxG.width, "", 28);
			text.alignment = FlxTextAlign.CENTER;
			add(text);
			menuTexts.push(text);
		}

		var hint = new FlxText(0, FlxG.height - 40, FlxG.width, "UP/DOWN: SELECT    ENTER: CONFIRM", 16);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		add(hint);

		refreshMenu();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.UP)
			moveSelection(-1);
		else if (FlxG.keys.justPressed.DOWN)
			moveSelection(1);

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			if (selected == 0)
				FlxG.switchState(new FreeplayState());
			else
				FlxG.switchState(new OptionsState());
		}
	}

	function moveSelection(delta:Int):Void
	{
		selected = (selected + delta + MENU_ITEMS.length) % MENU_ITEMS.length;
		refreshMenu();
	}

	function refreshMenu():Void
	{
		for (i in 0...menuTexts.length)
		{
			var isSelected = i == selected;
			menuTexts[i].text = (isSelected ? "> " : "  ") + MENU_ITEMS[i] + (isSelected ? " <" : "");
			menuTexts[i].color = isSelected ? FlxColor.WHITE : 0xFF777788;
		}
	}
}
