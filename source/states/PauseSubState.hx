package states;

import flixel.FlxG;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class PauseSubState extends FlxSubState
{
	static inline var OPTION_RESUME:Int = 0;
	static inline var OPTION_RESTART:Int = 1;
	static inline var OPTION_EXIT:Int = 2;
	static inline var OPTION_COUNT:Int = 3;

	var playState:PlayState;
	var optionTexts:Array<FlxText> = [];
	var optionLabels:Array<String> = [];
	var selectedOption:Int = OPTION_RESUME;

	public function new(playState:PlayState)
	{
		super(0xB0000000);
		this.playState = playState;
	}

	override public function create():Void
	{
		super.create();
		playState.pauseSong();

		var title = new FlxText(0, 220, FlxG.width, "PAUSED", 48);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		optionLabels = ["RESUME", "RESTART SONG", "EXIT TO MENU"];

		for (i in 0...OPTION_COUNT)
		{
			var text = new FlxText(0, 330 + i * 56, FlxG.width, optionLabels[i], 28);
			text.alignment = FlxTextAlign.CENTER;
			text.color = FlxColor.GRAY;
			add(text);
			optionTexts.push(text);
		}

		var hint = new FlxText(0, FlxG.height - 48, FlxG.width, "UP/DOWN: SELECT    ENTER: CONFIRM    ESC: RESUME", 16);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = 0xFF777788;
		add(hint);

		refreshOptions();
	}

	override public function destroy():Void
	{
		playState = null;
		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.UP)
			moveSelection(-1);
		else if (FlxG.keys.justPressed.DOWN)
			moveSelection(1);

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			activateOption();
		else if (FlxG.keys.justPressed.ESCAPE)
			resumeGame();
	}

	function moveSelection(delta:Int):Void
	{
		selectedOption = (selectedOption + delta + OPTION_COUNT) % OPTION_COUNT;
		refreshOptions();
	}

	function refreshOptions():Void
	{
		for (i in 0...optionTexts.length)
		{
			var selected = i == selectedOption;
			optionTexts[i].text = selected ? '> ${optionLabels[i]} <' : optionLabels[i];
			optionTexts[i].color = selected ? FlxColor.WHITE : FlxColor.GRAY;
		}
	}

	function activateOption():Void
	{
		switch (selectedOption)
		{
			case OPTION_RESUME:
				resumeGame();
			case OPTION_RESTART:
				FlxG.switchState(new PlayState(playState.songFolder, playState.songDifficulty));
			case OPTION_EXIT:
				FlxG.switchState(new MainMenuState());
		}
	}

	function resumeGame():Void
	{
		playState.resumeSong();
		close();
	}
}
