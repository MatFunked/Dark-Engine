package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import input.NoteDirection;
import settings.GameSettings;

class OptionsState extends FlxState
{
	static inline var ROW_COUNT:Int = 6;
	static inline var KEY_ROW_COUNT:Int = 4;
	static inline var OFFSET_ROW:Int = 4;
	static inline var DOWNSCROLL_ROW:Int = 5;
	static inline var ROW_TOP:Float = 192;
	static inline var ROW_SPACING:Float = 46;
	static inline var LABEL_X:Float = 360;
	static inline var VALUE_X:Float = 710;
	static inline var OFFSET_STEP:Float = 5;
	static inline var OFFSET_FINE_STEP:Float = 1;

	static var ROW_LABELS:Array<String> = ["LEFT KEY", "DOWN KEY", "UP KEY", "RIGHT KEY", "NOTE OFFSET", "DOWNSCROLL"];
	static var DIRECTION_LABELS:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];

	var selected:Int = 0;
	var waitingForKey:Bool = false;
	var captureDirection:Int = 0;
	var selectionBar:FlxSprite;
	var rowTexts:Array<FlxText> = [];
	var valueTexts:Array<FlxText> = [];
	var statusText:FlxText;
	var captureText:FlxText;
	var hintText:FlxText;

	override public function create():Void
	{
		super.create();

		GameSettings.load();
		bgColor = 0xFF0D1018;

		var title = new FlxText(0, 52, FlxG.width, "OPTIONS", 46);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		var subtitle = new FlxText(0, 116, FlxG.width, "CUSTOMIZE CONTROLS AND TIMING    |    POSITIVE OFFSET = NOTES LATER", 16);
		subtitle.alignment = FlxTextAlign.CENTER;
		subtitle.color = 0xFF8888AA;
		add(subtitle);

		selectionBar = new FlxSprite(350, 0);
		selectionBar.makeGraphic(580, 36, 0xFF1B2433);
		add(selectionBar);

		for (i in 0...ROW_COUNT)
		{
			var rowText = new FlxText(LABEL_X, ROW_TOP + i * ROW_SPACING, 300, "", 24);
			rowText.color = 0xFF8888AA;
			add(rowText);
			rowTexts.push(rowText);

			var valueText = new FlxText(VALUE_X, ROW_TOP + i * ROW_SPACING, 240, "", 24);
			valueText.color = FlxColor.WHITE;
			add(valueText);
			valueTexts.push(valueText);
		}

		statusText = new FlxText(0, 500, FlxG.width, "", 17);
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.color = 0xFF66FF88;
		add(statusText);

		captureText = new FlxText(0, 540, FlxG.width, "", 20);
		captureText.alignment = FlxTextAlign.CENTER;
		captureText.color = 0xFF00E5FF;
		add(captureText);

		hintText = new FlxText(0, 662, FlxG.width, "", 15);
		hintText.alignment = FlxTextAlign.CENTER;
		hintText.color = FlxColor.GRAY;
		add(hintText);

		refreshRows();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (waitingForKey)
		{
			handleKeyCapture();
			return;
		}

		if (FlxG.keys.justPressed.UP)
			moveSelection(-1);
		else if (FlxG.keys.justPressed.DOWN)
			moveSelection(1);

		if (selected < KEY_ROW_COUNT && (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE))
			beginKeyCapture();
		else if (selected == OFFSET_ROW)
			updateOffsetInput();
		else if (selected == DOWNSCROLL_ROW && (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE))
			toggleDownscroll();

		if (FlxG.keys.justPressed.R)
			resetDefaults();
		else if (FlxG.keys.justPressed.ESCAPE)
			FlxG.switchState(new MainMenuState());
	}

	function moveSelection(delta:Int):Void
	{
		selected = (selected + delta + ROW_COUNT) % ROW_COUNT;
		statusText.text = "";
		refreshRows();
	}

	function beginKeyCapture():Void
	{
		captureDirection = selected;
		waitingForKey = true;
		refreshRows();
		captureText.text = 'PRESS A KEY FOR ${DIRECTION_LABELS[captureDirection]}    ESC: CANCEL';
	}

	function handleKeyCapture():Void
	{
		if (FlxG.keys.justPressed.ESCAPE)
		{
			waitingForKey = false;
			captureText.text = "";
			statusText.text = "KEY CHANGE CANCELLED";
			refreshRows();
			return;
		}

		var keyCode = FlxG.keys.firstJustPressed();

		if (keyCode < 0)
			return;

		var key:FlxKey = cast keyCode;
		var previousKey = GameSettings.getKey(cast(captureDirection, NoteDirection));
		var swapped = GameSettings.setKey(cast(captureDirection, NoteDirection), key);

		waitingForKey = false;
		captureText.text = "";

		if (swapped >= 0)
			statusText.text = '${DIRECTION_LABELS[captureDirection]} SET TO ${keyLabel(key)}. ${DIRECTION_LABELS[swapped]} NOW USES ${keyLabel(previousKey)}.';
		else
			statusText.text = '${DIRECTION_LABELS[captureDirection]} SET TO ${keyLabel(key)}.';

		refreshRows();
	}

	function updateOffsetInput():Void
	{
		var step = FlxG.keys.pressed.SHIFT ? OFFSET_FINE_STEP : OFFSET_STEP;

		if (FlxG.keys.justPressed.LEFT)
			adjustOffset(-step);
		else if (FlxG.keys.justPressed.RIGHT)
			adjustOffset(step);
		else if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			GameSettings.setOffset(0);
			statusText.text = "NOTE OFFSET RESET TO 0 MS.";
			refreshRows();
		}
	}

	function adjustOffset(delta:Float):Void
	{
		GameSettings.setOffset(GameSettings.noteOffsetMs + delta);
		statusText.text = "";
		refreshRows();
	}

	function toggleDownscroll():Void
	{
		GameSettings.setDownscroll(!GameSettings.downscroll);
		statusText.text = GameSettings.downscroll ? "DOWNSCROLL ENABLED." : "DOWNSCROLL DISABLED.";
		refreshRows();
	}

	function resetDefaults():Void
	{
		GameSettings.resetToDefaults();
		statusText.text = "DEFAULT CONTROLS AND TIMING RESTORED.";
		refreshRows();
	}

	function refreshRows():Void
	{
		selectionBar.y = ROW_TOP + selected * ROW_SPACING - 6;

		for (i in 0...ROW_COUNT)
		{
			var isSelected = i == selected;
			var rowText = rowTexts[i];
			var valueText = valueTexts[i];

			rowText.text = (isSelected ? "> " : "  ") + ROW_LABELS[i];
			rowText.color = isSelected ? FlxColor.WHITE : 0xFF8888AA;
			valueText.text = rowValue(i);
			valueText.color = valueColor(i, isSelected);
		}

		refreshHint();
	}

	function refreshHint():Void
	{
		if (selected < KEY_ROW_COUNT)
			hintText.text = "UP/DOWN: SELECT    ENTER: REBIND KEY    R: DEFAULTS    ESC: BACK";
		else if (selected == OFFSET_ROW)
			hintText.text = "LEFT/RIGHT: ADJUST OFFSET    SHIFT: 1 MS    ENTER: RESET 0    ESC: BACK";
		else
			hintText.text = "ENTER: TOGGLE DOWNSCROLL    UP/DOWN: SELECT    R: DEFAULTS    ESC: BACK";
	}

	function rowValue(index:Int):String
	{
		if (index < KEY_ROW_COUNT)
		{
			if (waitingForKey && captureDirection == index)
				return "<PRESS A KEY>";

			return keyLabel(GameSettings.getKey(cast(index, NoteDirection)));
		}

		if (index == OFFSET_ROW)
			return formatOffset(GameSettings.noteOffsetMs);

		return GameSettings.downscroll ? "ON" : "OFF";
	}

	function valueColor(index:Int, isSelected:Bool):Int
	{
		if (index == DOWNSCROLL_ROW)
			return GameSettings.downscroll ? 0xFF66FF88 : 0xFF8888AA;

		return isSelected ? FlxColor.WHITE : 0xFFB8B8CC;
	}

	static function formatOffset(value:Float):String
	{
		var amount = Std.int(value);
		return '${amount > 0 ? "+" : ""}$amount MS';
	}

	static function keyLabel(key:FlxKey):String
	{
		if (key == FlxKey.LEFT) return "LEFT ARROW";
		if (key == FlxKey.DOWN) return "DOWN ARROW";
		if (key == FlxKey.UP) return "UP ARROW";
		if (key == FlxKey.RIGHT) return "RIGHT ARROW";
		if (key == FlxKey.SPACE) return "SPACE";
		if (key == FlxKey.ENTER) return "ENTER";
		if (key == FlxKey.SHIFT) return "SHIFT";
		if (key == FlxKey.CONTROL) return "CTRL";
		if (key == FlxKey.ALT) return "ALT";
		if (key == FlxKey.TAB) return "TAB";
		if (key == FlxKey.BACKSPACE) return "BACKSPACE";
		if (key == FlxKey.ESCAPE) return "ESC";

		var name = key.toString();
		return name == null ? 'KEY ${cast(key, Int)}' : name;
	}
}
