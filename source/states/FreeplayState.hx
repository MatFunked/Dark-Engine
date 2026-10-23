package states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import mods.ModManager;
import openfl.utils.Assets;

private typedef SongEntry =
{
	var folder:String;
	var displayName:String;
	var bpm:Float;
	var available:Array<Bool>;
}

class FreeplayState extends FlxState
{
	static inline var SONG_ROOT:String = "assets/songs/";
	static inline var MAX_VISIBLE_SONGS:Int = 9;
	static var DIFFICULTY_NAMES:Array<String> = ["EASY", "NORMAL", "HARD"];
	static var DIFFICULTY_FILES:Array<String> = ["easy", "normal", "hard"];

	var songs:Array<SongEntry> = [];
	var songTexts:Array<FlxText> = [];
	var difficultyTexts:Array<FlxText> = [];
	var songNameText:FlxText;
	var songFolderText:FlxText;
	var songBpmText:FlxText;
	var songChartsText:FlxText;
	var difficultyStatusText:FlxText;
	var errorText:FlxText;
	var selectedSong:Int = 0;
	var selectedDifficulty:Int = 2;
	var listOffset:Int = 0;

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF0D1018;
		ModManager.reload();
		songs = discoverSongs();
		buildUi();

		if (songs.length > 0)
		{
			selectedDifficulty = preferredDifficulty(songs[0]);
			refreshSongList();
			refreshInfo();
		}
		else
		{
			errorText.text = 'NO SONGS FOUND IN $SONG_ROOT';
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.UP)
			moveSong(-1);
		else if (FlxG.keys.justPressed.DOWN)
			moveSong(1);

		if (FlxG.keys.justPressed.LEFT)
			moveDifficulty(-1);
		else if (FlxG.keys.justPressed.RIGHT)
			moveDifficulty(1);

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			startSelectedSong();
		else if (FlxG.keys.justPressed.ESCAPE)
			FlxG.switchState(new MainMenuState());
	}

	function buildUi():Void
	{
		var title = new FlxText(0, 48, FlxG.width, "FREEPLAY", 42);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		var songHeader = new FlxText(120, 132, 560, "SONGS", 18);
		songHeader.color = 0xFF7777AA;
		add(songHeader);

		for (i in 0...MAX_VISIBLE_SONGS)
		{
			var text = new FlxText(120, 170 + i * 38, 560, "", 24);
			text.color = 0xFF8888AA;
			add(text);
			songTexts.push(text);
		}

		var selectedHeader = new FlxText(760, 132, 400, "SELECTED", 18);
		selectedHeader.color = 0xFF7777AA;
		add(selectedHeader);

		songNameText = new FlxText(760, 170, 400, "", 30);
		songNameText.color = FlxColor.WHITE;
		add(songNameText);

		songFolderText = new FlxText(760, 214, 400, "", 18);
		songFolderText.color = 0xFF8888AA;
		add(songFolderText);

		songBpmText = new FlxText(760, 242, 400, "", 18);
		songBpmText.color = 0xFF8888AA;
		add(songBpmText);

		songChartsText = new FlxText(760, 270, 400, "", 18);
		songChartsText.color = 0xFF8888AA;
		add(songChartsText);

		var difficultyHeader = new FlxText(760, 330, 400, "DIFFICULTY", 18);
		difficultyHeader.color = 0xFF7777AA;
		add(difficultyHeader);

		for (i in 0...DIFFICULTY_NAMES.length)
		{
			var text = new FlxText(760 + i * 130, 366, 120, "", 24);
			text.alignment = FlxTextAlign.CENTER;
			text.color = 0xFF8888AA;
			add(text);
			difficultyTexts.push(text);
		}

		difficultyStatusText = new FlxText(760, 416, 400, "", 16);
		difficultyStatusText.color = FlxColor.GRAY;
		add(difficultyStatusText);

		errorText = new FlxText(0, 472, FlxG.width, "", 20);
		errorText.alignment = FlxTextAlign.CENTER;
		errorText.color = 0xFFFF4455;
		add(errorText);

		var hint = new FlxText(0, FlxG.height - 32, FlxG.width,
			"UP/DOWN: SONG    LEFT/RIGHT: DIFFICULTY    ENTER: PLAY    ESC: MENU", 16);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		add(hint);
	}

	function moveSong(delta:Int):Void
	{
		if (songs.length == 0)
			return;

		selectedSong = (selectedSong + delta + songs.length) % songs.length;

		if (!songs[selectedSong].available[selectedDifficulty])
			selectedDifficulty = preferredDifficulty(songs[selectedSong]);

		updateListOffset();
		errorText.text = "";
		refreshSongList();
		refreshInfo();
	}

	function moveDifficulty(delta:Int):Void
	{
		if (songs.length == 0)
			return;

		selectedDifficulty = (selectedDifficulty + delta + DIFFICULTY_FILES.length) % DIFFICULTY_FILES.length;
		errorText.text = "";
		refreshInfo();
	}

	function startSelectedSong():Void
	{
		if (songs.length == 0)
			return;

		var song = songs[selectedSong];

		if (!song.available[selectedDifficulty])
		{
			errorText.text = 'NO ${DIFFICULTY_NAMES[selectedDifficulty]} CHART FOR ${song.displayName.toUpperCase()}';
			return;
		}

		FlxG.switchState(new PlayState(song.folder, DIFFICULTY_FILES[selectedDifficulty]));
	}

	function updateListOffset():Void
	{
		if (selectedSong < listOffset)
			listOffset = selectedSong;
		else if (selectedSong >= listOffset + MAX_VISIBLE_SONGS)
			listOffset = selectedSong - MAX_VISIBLE_SONGS + 1;

		var maxOffset = Std.int(Math.max(0, songs.length - MAX_VISIBLE_SONGS));

		if (listOffset > maxOffset)
			listOffset = maxOffset;
		if (listOffset < 0)
			listOffset = 0;
	}

	function refreshSongList():Void
	{
		for (i in 0...songTexts.length)
		{
			var index = listOffset + i;
			var text = songTexts[i];

			if (index >= songs.length)
			{
				text.text = "";
				continue;
			}

			var selected = index == selectedSong;
			text.text = (selected ? "> " : "  ") + songs[index].displayName;
			text.color = selected ? FlxColor.WHITE : 0xFF8888AA;
		}
	}

	function refreshInfo():Void
	{
		if (songs.length == 0)
			return;

		var song = songs[selectedSong];
		var availableNames:Array<String> = [];

		for (i in 0...DIFFICULTY_NAMES.length)
		{
			if (song.available[i])
				availableNames.push(DIFFICULTY_NAMES[i]);
		}

		songNameText.text = song.displayName;
		songFolderText.text = 'FOLDER: ${song.folder}';
		songBpmText.text = song.bpm > 0 ? '${song.bpm} BPM' : "BPM: UNKNOWN";
		songChartsText.text = availableNames.length == 0 ? "CHARTS: NONE" : 'CHARTS: ${availableNames.join(", ")}';

		for (i in 0...difficultyTexts.length)
		{
			var selected = i == selectedDifficulty;
			var available = song.available[i];
			var text = difficultyTexts[i];

			text.text = selected ? '[${DIFFICULTY_NAMES[i]}]' : DIFFICULTY_NAMES[i];
			text.color = selected ? (available ? FlxColor.WHITE : 0xFFFF4455) : (available ? 0xFF8888AA : 0xFF444455);
		}

		var available = song.available[selectedDifficulty];
		difficultyStatusText.text = available
			? 'CHART READY: charts/${DIFFICULTY_FILES[selectedDifficulty]}.json'
			: 'CHART MISSING: charts/${DIFFICULTY_FILES[selectedDifficulty]}.json';
		difficultyStatusText.color = available ? 0xFF66FF88 : 0xFFFF4455;
	}

	static function discoverSongs():Array<SongEntry>
	{
		var folders:Array<String> = [];

		for (asset in Assets.list())
		{
			if (asset.indexOf(SONG_ROOT) != 0)
				continue;

			var rest = asset.substr(SONG_ROOT.length);
			var slash = rest.indexOf("/");

			if (slash <= 0)
				continue;

			var folder = rest.substr(0, slash);

			if (folders.indexOf(folder) >= 0)
				continue;

			if (!Assets.exists('$SONG_ROOT$folder/meta.json'))
				continue;

			if (!ModManager.isSongAvailable(folder))
				continue;

			folders.push(folder);
		}

		folders.sort(compareFolders);

		var entries:Array<SongEntry> = [];

		for (folder in folders)
			entries.push(buildEntry(folder));

		return entries;
	}

	static function buildEntry(folder:String):SongEntry
	{
		var displayName = folder;
		var bpm = 0.0;
		var metaJson = Assets.getText('$SONG_ROOT$folder/meta.json');

		if (metaJson != null)
		{
			try
			{
				var meta:Dynamic = haxe.Json.parse(metaJson);

				if (meta != null)
				{
					var rawName = Reflect.field(meta, "displayName");

					if (rawName != null)
						displayName = Std.string(rawName);

					var rawBpm = Reflect.field(meta, "bpm");

					if (rawBpm != null)
					{
						var parsedBpm = Std.parseFloat(Std.string(rawBpm));

						if (!Math.isNaN(parsedBpm))
							bpm = parsedBpm;
					}
				}
			}
			catch (error:Dynamic) {}
		}

		var available:Array<Bool> = [];

		for (file in DIFFICULTY_FILES)
			available.push(Assets.exists('$SONG_ROOT$folder/charts/$file.json'));

		return {
			folder: folder,
			displayName: displayName,
			bpm: bpm,
			available: available
		};
	}

	static function preferredDifficulty(song:SongEntry):Int
	{
		for (i in 0...DIFFICULTY_FILES.length)
		{
			var index = DIFFICULTY_FILES.length - 1 - i;

			if (song.available[index])
				return index;
		}

		return DIFFICULTY_FILES.length - 1;
	}

	static function compareFolders(a:String, b:String):Int
	{
		var left = a.toLowerCase();
		var right = b.toLowerCase();

		if (left < right)
			return -1;
		if (left > right)
			return 1;

		return 0;
	}
}
