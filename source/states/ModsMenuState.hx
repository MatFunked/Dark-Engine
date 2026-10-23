package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import mods.ModInfo;
import mods.ModManager;

private typedef ModRow =
{
	var name:FlxText;
	var description:FlxText;
	var state:FlxText;
}

class ModsMenuState extends FlxState
{
	static inline var MAX_VISIBLE:Int = 7;
	static inline var ROW_TOP:Float = 176;
	static inline var ROW_SPACING:Float = 62;
	static inline var LIST_X:Float = 92;
	static inline var LIST_WIDTH:Float = 720;
	static inline var DETAIL_X:Float = 852;
	static inline var DETAIL_WIDTH:Float = 340;

	var selected:Int = 0;
	var listOffset:Int = 0;
	var mods:Array<ModInfo> = [];
	var rows:Array<ModRow> = [];
	var selectionBar:FlxSprite;
	var detailText:FlxText;
	var statusText:FlxText;

	override public function create():Void
	{
		super.create();

		ModManager.reload();
		mods = ModManager.mods;
		bgColor = 0xFF0D1018;

		var title = new FlxText(0, 40, FlxG.width, "MODS", 46);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		var subtitle = new FlxText(0, 102, FlxG.width, "ENABLE OR DISABLE INSTALLED MODS    |    DEPENDENCIES ARE VERIFIED", 16);
		subtitle.alignment = FlxTextAlign.CENTER;
		subtitle.color = 0xFF8888AA;
		add(subtitle);

		var listHeader = new FlxText(LIST_X, 144, LIST_WIDTH, "INSTALLED MODS", 18);
		listHeader.color = 0xFF7777AA;
		add(listHeader);

		var detailHeader = new FlxText(DETAIL_X, 144, DETAIL_WIDTH, "SELECTED MOD", 18);
		detailHeader.color = 0xFF7777AA;
		add(detailHeader);

		selectionBar = new FlxSprite(LIST_X - 8, 0);
		selectionBar.makeGraphic(Std.int(LIST_WIDTH + 16), 56, 0xFF1B2433);
		add(selectionBar);

		for (i in 0...MAX_VISIBLE)
		{
			var y = ROW_TOP + i * ROW_SPACING;
			var rowName = new FlxText(LIST_X + 12, y + 4, 520, "", 22);
			rowName.color = 0xFFC8C8D8;
			rowName.wordWrap = false;
			add(rowName);

			var rowDescription = new FlxText(LIST_X + 12, y + 32, 540, "", 15);
			rowDescription.color = 0xFF777788;
			rowDescription.wordWrap = false;
			add(rowDescription);

			var rowState = new FlxText(LIST_X + LIST_WIDTH - 136, y + 13, 120, "", 18);
			rowState.alignment = FlxTextAlign.CENTER;
			rowState.color = 0xFF8888AA;
			add(rowState);

			rows.push({
				name: rowName,
				description: rowDescription,
				state: rowState
			});
		}

		detailText = new FlxText(DETAIL_X, 178, DETAIL_WIDTH, "", 17);
		detailText.color = 0xFFB8B8CC;
		detailText.wordWrap = true;
		add(detailText);

		statusText = new FlxText(0, 620, FlxG.width, "", 17);
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.color = FlxColor.GRAY;
		add(statusText);

		var hint = new FlxText(0, 680, FlxG.width, "UP/DOWN: SELECT    ENTER/SPACE: TOGGLE    ESC: SAVE & BACK", 15);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		add(hint);

		refreshRows();
		refreshDetails();

		if (mods.length == 0)
			setStatus("NO MODS FOUND IN mods/", 0xFFFF4455);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.UP)
			moveSelection(-1);
		else if (FlxG.keys.justPressed.DOWN)
			moveSelection(1);

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			toggleSelected();

		if (FlxG.keys.justPressed.ESCAPE)
		{
			ModManager.save();
			FlxG.switchState(new MainMenuState());
		}
	}

	function moveSelection(delta:Int):Void
	{
		if (mods.length == 0)
			return;

		selected = (selected + delta + mods.length) % mods.length;
		setStatus("", FlxColor.GRAY);
		refreshRows();
		refreshDetails();
	}

	function toggleSelected():Void
	{
		if (mods.length == 0)
			return;

		var mod = mods[selected];

		if (mod.error != null)
		{
			setStatus('CANNOT TOGGLE ${mod.name.toUpperCase()}: ${mod.error}', 0xFFFF4455);
			return;
		}

		if (ModManager.isActive(mod.id))
		{
			var cascaded = ModManager.setEnabled(mod.id, false);

			if (cascaded.length > 0)
				setStatus('DISABLED ${mod.name.toUpperCase()} AND ${cascaded.length} DEPENDENT(S)', 0xFFFFAA00);
			else
				setStatus('DISABLED ${mod.name.toUpperCase()}', 0xFFAAAAAA);
		}
		else
		{
			var missing = ModManager.getMissingDependencies(mod);

			if (missing.length > 0)
			{
				setStatus('MISSING DEPENDENCIES: ${missing.join(", ")}', 0xFFFF4455);
				return;
			}

			ModManager.setEnabled(mod.id, true);
			setStatus('ENABLED ${mod.name.toUpperCase()}', 0xFF66FF88);
		}

		refreshRows();
		refreshDetails();
	}

	function updateListOffset():Void
	{
		if (selected < listOffset)
			listOffset = selected;
		else if (selected >= listOffset + MAX_VISIBLE)
			listOffset = selected - MAX_VISIBLE + 1;

		var maxOffset = Std.int(Math.max(0, mods.length - MAX_VISIBLE));

		if (listOffset > maxOffset)
			listOffset = maxOffset;
		if (listOffset < 0)
			listOffset = 0;
	}

	function refreshRows():Void
	{
		if (mods.length == 0)
		{
			selectionBar.visible = false;

			for (row in rows)
			{
				row.name.text = "";
				row.description.text = "";
				row.state.text = "";
			}

			return;
		}

		selectionBar.visible = true;
		updateListOffset();
		selectionBar.y = ROW_TOP + (selected - listOffset) * ROW_SPACING - 4;

		for (i in 0...rows.length)
		{
			var index = listOffset + i;
			var row = rows[i];

			if (index >= mods.length)
			{
				row.name.text = "";
				row.description.text = "";
				row.state.text = "";
				continue;
			}

			var mod = mods[index];
			var isSelected = index == selected;
			var active = ModManager.isActive(mod.id);
			var requested = ModManager.isRequestedEnabled(mod);

			row.name.text = (isSelected ? "> " : "  ") + nameLabel(mod.name);
			row.name.color = isSelected ? FlxColor.WHITE : 0xFFC8C8D8;
			row.description.text = "  " + descriptionLabel(mod.description);
			row.description.color = isSelected ? 0xFFB8B8CC : 0xFF777788;

			if (mod.error != null)
			{
				row.state.text = "[ERROR]";
				row.state.color = 0xFFFF4455;
			}
			else if (active)
			{
				row.state.text = "[ ON ]";
				row.state.color = 0xFF66FF88;
			}
			else if (requested)
			{
				row.state.text = "[DEPS]";
				row.state.color = 0xFFFFAA00;
			}
			else
			{
				row.state.text = "[ OFF ]";
				row.state.color = isSelected ? 0xFFB8B8CC : 0xFF8888AA;
			}
		}
	}

	function refreshDetails():Void
	{
		if (mods.length == 0)
		{
			detailText.text = "NO MODS FOUND.\n\nPlace a folder containing a mod.json inside the mods directory.";
			return;
		}

		var mod = mods[selected];
		var active = ModManager.isActive(mod.id);
		var requested = ModManager.isRequestedEnabled(mod);
		var status = "INACTIVE";

		if (mod.error != null)
			status = "ERROR";
		else if (active)
			status = "ACTIVE";
		else if (requested)
			status = "BLOCKED";

		var lines:Array<String> = [];
		lines.push(mod.name);
		lines.push("");
		lines.push(mod.description == "" ? "No description." : mod.description);
		lines.push("");
		lines.push('ID: ${mod.id}');
		lines.push('FOLDER: ${mod.folder}');
		lines.push('DEFAULT: ${mod.enabledByDefault ? "ON" : "OFF"}');
		lines.push('STATUS: $status');
		lines.push('SONGS: ${mod.songs.length}');
		lines.push("");

		if (mod.error != null)
		{
			lines.push('ERROR: ${mod.error}');
		}
		else if (mod.dependencies.length == 0)
		{
			lines.push("DEPENDENCIES: NONE");
		}
		else
		{
			lines.push("DEPENDENCIES:");

			for (dependency in mod.dependencies)
				lines.push('  $dependency: ${ModManager.dependencyState(dependency)}');
		}

		detailText.text = lines.join("\n");
	}

	function setStatus(message:String, color:Int):Void
	{
		statusText.text = message;
		statusText.color = color;
	}

	static function nameLabel(name:String):String
	{
		if (name == null)
			return "";

		return name.length > 32 ? name.substr(0, 29) + "..." : name;
	}

	static function descriptionLabel(description:String):String
	{
		if (description == null || description == "")
			return "No description.";

		var text = description.split("\n")[0];

		if (text.length > 50)
			text = text.substr(0, 47) + "...";

		return text;
	}
}
