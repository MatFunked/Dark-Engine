package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class MissingFilePrompt extends FlxGroup
{
	static inline var PANEL_WIDTH:Float = 760;
	static inline var PANEL_HEIGHT:Float = 260;

	var backdrop:FlxSprite;
	var panel:FlxSprite;
	var border:FlxSprite;
	var titleText:FlxText;
	var messageText:FlxText;
	var pathText:FlxText;
	var hintText:FlxText;
	var detailText:FlxText;

	var confirmCallback:Void->Void;
	var cancelCallback:Void->Void;

	public var isOpen(default, null):Bool = false;

	public function new()
	{
		super();

		backdrop = new FlxSprite(0, 0);
		backdrop.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		backdrop.alpha = 0.78;
		add(backdrop);

		var panelX = (FlxG.width - PANEL_WIDTH) * 0.5;
		var panelY = (FlxG.height - PANEL_HEIGHT) * 0.5;

		border = new FlxSprite(panelX - 2, panelY - 2);
		border.makeGraphic(Std.int(PANEL_WIDTH + 4), Std.int(PANEL_HEIGHT + 4), 0xFF445577);
		add(border);

		panel = new FlxSprite(panelX, panelY);
		panel.makeGraphic(Std.int(PANEL_WIDTH), Std.int(PANEL_HEIGHT), 0xFF101520);
		add(panel);

		titleText = new FlxText(panelX + 24, panelY + 20, PANEL_WIDTH - 48, "", 24);
		titleText.alignment = FlxTextAlign.CENTER;
		titleText.color = 0xFFFFAA33;
		add(titleText);

		messageText = new FlxText(panelX + 24, panelY + 60, PANEL_WIDTH - 48, "", 15);
		messageText.alignment = FlxTextAlign.CENTER;
		messageText.color = FlxColor.WHITE;
		add(messageText);

		pathText = new FlxText(panelX + 24, panelY + 90, PANEL_WIDTH - 48, "", 12);
		pathText.alignment = FlxTextAlign.CENTER;
		pathText.color = 0xFFAABBCC;
		pathText.wordWrap = true;
		add(pathText);

		detailText = new FlxText(panelX + 24, panelY + 142, PANEL_WIDTH - 48, "", 13);
		detailText.alignment = FlxTextAlign.CENTER;
		detailText.color = 0xFF8899AA;
		detailText.wordWrap = true;
		add(detailText);

		hintText = new FlxText(panelX + 24, panelY + 200, PANEL_WIDTH - 48, "ENTER: CREATE TEMPLATE    ESC: CANCEL", 15);
		hintText.alignment = FlxTextAlign.CENTER;
		hintText.color = 0xFF66FF88;
		add(hintText);

		visible = false;
	}

	public function show(kind:String, path:String, ?detail:String, ?onConfirm:Void->Void, ?onCancel:Void->Void):Void
	{
		titleText.text = '${kind.toUpperCase()} NOT FOUND';
		messageText.text = "CREATE A NEW TEMPLATE?";
		pathText.text = path == null ? "UNKNOWN PATH" : path;
		detailText.text = detail == null ? "" : detail;
		confirmCallback = onConfirm;
		cancelCallback = onCancel;
		isOpen = true;
		visible = true;
	}

	public function close():Void
	{
		isOpen = false;
		visible = false;
		confirmCallback = null;
		cancelCallback = null;
	}

	public function updatePrompt():Bool
	{
		if (!isOpen)
			return false;

		if (FlxG.keys.justPressed.ENTER)
		{
			var callback = confirmCallback;
			close();

			if (callback != null)
				callback();

			return true;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			var callback = cancelCallback;
			close();

			if (callback != null)
				callback();

			return true;
		}

		return true;
	}
}
