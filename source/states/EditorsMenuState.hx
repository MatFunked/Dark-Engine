package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class EditorsMenuState extends FlxState
{
	static var MENU_ITEMS:Array<String> = ["CHARACTER EDITOR", "STAGE EDITOR", "CHART EDITOR", "BACK"];
	static var MENU_TAGS:Array<String> = ["", "PLACEHOLDER", "PLACEHOLDER", ""];

	static inline var ROW_TOP:Float = 258;
	static inline var ROW_SPACING:Float = 58;
	static inline var BAR_WIDTH:Float = 660;
	static inline var BAR_HEIGHT:Float = 42;

	var selected:Int = 0;
	var selectionBar:FlxSprite;
	var menuTexts:Array<FlxText> = [];
	var statusText:FlxText;

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF0D1018;

		var title = new FlxText(0, 76, FlxG.width, "EDITORS", 48);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		var subtitle = new FlxText(0, 138, FlxG.width, "CHARACTER, STAGE AND CHART TOOLS", 16);
		subtitle.alignment = FlxTextAlign.CENTER;
		subtitle.color = 0xFF8888AA;
		add(subtitle);

		selectionBar = new FlxSprite((FlxG.width - BAR_WIDTH) * 0.5, 0);
		selectionBar.makeGraphic(Std.int(BAR_WIDTH), Std.int(BAR_HEIGHT), 0xFF1B2433);
		add(selectionBar);

		for (i in 0...MENU_ITEMS.length)
		{
			var text = new FlxText(0, ROW_TOP + i * ROW_SPACING, FlxG.width, "", 27);
			text.alignment = FlxTextAlign.CENTER;
			add(text);
			menuTexts.push(text);
		}

		statusText = new FlxText(0, 520, FlxG.width, "", 17);
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.color = 0xFF8888AA;
		add(statusText);

		var hint = new FlxText(0, 656, FlxG.width, "UP/DOWN: SELECT    ENTER: OPEN    ESC: BACK", 16);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = 0xFF666688;
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

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.switchState(new MainMenuState());
			return;
		}

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			activateSelection();
	}

	function activateSelection():Void
	{
		switch (selected)
		{
			case 0:
				FlxG.switchState(new CharacterEditorState());
			case 1:
				setStatus("STAGE EDITOR IS A PLACEHOLDER", 0xFFFFCC55);
			case 2:
				setStatus("CHART EDITOR IS A PLACEHOLDER", 0xFFFFCC55);
			case 3:
				FlxG.switchState(new MainMenuState());
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
			var tag = MENU_TAGS[i];

			menuTexts[i].text = (isSelected ? "> " : "  ") + MENU_ITEMS[i] + (tag == "" ? "" : '  [$tag]') + (isSelected ? " <" : "");
			menuTexts[i].color = isSelected ? FlxColor.WHITE : (tag == "" ? 0xFF8888AA : 0xFF66657A);
		}

		selectionBar.y = ROW_TOP + selected * ROW_SPACING - 8;

		switch (selected)
		{
			case 0:
				setStatus("EDIT CHARACTER ANIMATION OFFSETS", 0xFF66FF88);
			case 1:
				setStatus("STAGE EDITOR IS A PLACEHOLDER", 0xFFFFCC55);
			case 2:
				setStatus("CHART EDITOR IS A PLACEHOLDER", 0xFFFFCC55);
			case 3:
				setStatus("RETURN TO THE MAIN MENU", 0xFF8888AA);
		}
	}

	function setStatus(message:String, color:Int):Void
	{
		statusText.text = message;
		statusText.color = color;
	}
}
