package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import chart.ChartLoader;
import chart.FNFChart;
import input.ArrowInput;
import input.NoteDirection;
import notes.Judgment;
import notes.Note;
import notes.NoteDetector;
import notes.TimingWindows;

private typedef ChartEntry =
{
	var note:Note;
	var sprite:FlxSprite;
}

class PlayState extends FlxState
{
	static inline var RECEPTOR_Y:Float = 560;
	static inline var LANE_WIDTH:Float = 110;
	static inline var NOTE_SPEED:Float = 0.35;
	static inline var SONG_DIFFICULTY:String = "HARD";
	static inline var SONG_CHART_PATH:String = "assets/songs/emma/charts/hard.json";
	static inline var SONG_META_PATH:String = "assets/songs/emma/meta.json";
	static inline var SONG_INST_PATH:String = "assets/songs/emma/song/Inst.ogg";

	var chartData:FNFChart;
	var songTime:Float = 0;
	var elapsedSongTime:Float = 0;
	var loadError:String = null;
	var arrows:ArrowInput;
	var detector:NoteDetector;
	var notes:Array<Note> = [];
	var chart:Array<ChartEntry> = [];
	var judgmentText:FlxText;
	var timerText:FlxText;
	var feedbackTime:Float = 0;

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF0B0B12;
		arrows = new ArrowInput();
		detector = new NoteDetector(new TimingWindows());

		buildLanes();

		try
		{
			loadLevel();
		}
		catch (error:Dynamic)
		{
			loadError = Std.string(error);
		}

		buildUi();
	}

	override public function destroy():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		elapsedSongTime += elapsed * 1000;

		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			songTime = FlxG.sound.music.time + (chartData == null ? 0 : chartData.offset);
		else
			songTime = elapsedSongTime + (chartData == null ? 0 : chartData.offset);

		for (direction in arrows.justPressedDirections())
		{
			var result = detector.hitNote(notes, direction, songTime);

			if (result != null)
				showJudgment(result.judgment, result.offset);
		}

		for (note in detector.collectMissedNotes(notes, songTime))
			showJudgment(Judgment.MISS, songTime - note.time);

		updateNotePositions();
		updateFeedback(elapsed);

		timerText.text = '${Std.int(songTime / 10) / 100} s';

		if (FlxG.keys.justPressed.ESCAPE)
			FlxG.switchState(MainMenuState.new);
		else if (FlxG.keys.justPressed.R)
			FlxG.resetState();
	}

	function buildLanes():Void
	{
		var directions = NoteDirection.all();
		var labels = ["LEFT", "DOWN", "UP", "RIGHT"];

		for (isPlayer in [false, true])
		{
			for (i in 0...directions.length)
			{
				var direction = directions[i];
				var x = laneCenter(direction, isPlayer);

				var receptor = new FlxSprite(x - 32, RECEPTOR_Y - 32);
				receptor.makeGraphic(64, 64, isPlayer ? 0xFF2A2A45 : 0xFF1E1E30);
				add(receptor);

				var label = new FlxText(x - 50, RECEPTOR_Y + 42, 100, labels[i], 14);
				label.alignment = FlxTextAlign.CENTER;
				label.color = isPlayer ? FlxColor.GRAY : 0xFF555566;
				add(label);
			}

			var sideLabel = new FlxText(groupCenter(isPlayer) - 80, RECEPTOR_Y + 68, 160, isPlayer ? "PLAYER" : "OPPONENT", 14);
			sideLabel.alignment = FlxTextAlign.CENTER;
			sideLabel.color = isPlayer ? 0xFF88AAFF : 0xFF887788;
			add(sideLabel);
		}
	}

	function loadLevel():Void
	{
		chartData = ChartLoader.loadSong(SONG_CHART_PATH, SONG_META_PATH);
		buildChart();
		FlxG.sound.playMusic(SONG_INST_PATH, 1.0, false);
	}

	function buildChart():Void
	{
		var colors = [0xFFC24B99, 0xFF00CFFF, 0xFF12FA05, 0xFFF9393F];

		for (chartNote in chartData.notes)
		{
			var note = new Note(chartNote.time, chartNote.direction);
			var sprite = new FlxSprite(laneCenter(chartNote.direction, chartNote.isPlayer) - 28, -100);
			sprite.makeGraphic(56, 24, colors[cast(chartNote.direction, Int)]);
			sprite.alpha = chartNote.isPlayer ? 1.0 : 0.5;
			add(sprite);

			chart.push({note: note, sprite: sprite});

			if (chartNote.isPlayer)
				notes.push(note);
		}
	}

	function buildUi():Void
	{
		var titleText = chartData == null ? "DARK ENGINE" : '${chartData.songName.toUpperCase()} - $SONG_DIFFICULTY';
		var title = new FlxText(0, 24, FlxG.width, titleText, 28);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		timerText = new FlxText(0, 28, FlxG.width - 24, "", 14);
		timerText.alignment = FlxTextAlign.RIGHT;
		timerText.color = FlxColor.GRAY;
		add(timerText);

		judgmentText = new FlxText(0, 100, FlxG.width, "", 44);
		judgmentText.alignment = FlxTextAlign.CENTER;
		judgmentText.color = FlxColor.WHITE;
		add(judgmentText);

		if (chartData != null)
		{
			var chartInfo = new FlxText(0, 156, FlxG.width,
				'${chartData.bpm} BPM  |  ${chartData.notes.length} NOTES  |  ${chartData.getPlayerNotes().length} PLAYER', 14);
			chartInfo.alignment = FlxTextAlign.CENTER;
			chartInfo.color = 0xFF8888AA;
			add(chartInfo);
		}

		var windows = detector.windows;
		var info = new FlxText(0, 180, FlxG.width,
			'Sick ${windows.sickWindow} / Good ${windows.goodWindow} / Bad ${windows.badWindow} / Miss ${windows.missWindow} ms', 14);
		info.alignment = FlxTextAlign.CENTER;
		info.color = 0xFF666688;
		add(info);

		if (loadError != null)
		{
			var errorText = new FlxText(0, 216, FlxG.width, loadError, 16);
			errorText.alignment = FlxTextAlign.CENTER;
			errorText.color = 0xFFFF4455;
			add(errorText);
		}

		var hint = new FlxText(0, FlxG.height - 32, FlxG.width, "ESC: MENU    R: RESTART", 14);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		add(hint);
	}

	function updateNotePositions():Void
	{
		for (entry in chart)
		{
			var note = entry.note;
			var sprite = entry.sprite;

			if (note.hit)
			{
				sprite.visible = false;
				continue;
			}

			var y = RECEPTOR_Y - 12 - (note.time - songTime) * NOTE_SPEED;
			sprite.y = y;
			sprite.visible = y > -32 && y < FlxG.height;
		}
	}

	function updateFeedback(elapsed:Float):Void
	{
		if (feedbackTime <= 0)
			return;

		feedbackTime -= elapsed;
		judgmentText.alpha = Math.max(0, Math.min(1, feedbackTime * 2));
	}

	function showJudgment(judgment:Judgment, offset:Float):Void
	{
		judgmentText.text = '${judgment.label()}  ${offset >= 0 ? "+" : ""}${Std.int(offset)} ms';
		judgmentText.color = judgmentColor(judgment);
		judgmentText.alpha = 1;
		feedbackTime = 0.8;
	}

	function judgmentColor(judgment:Judgment):FlxColor
	{
		if (judgment == Judgment.SICK)
			return 0xFF00E5FF;
		if (judgment == Judgment.GOOD)
			return 0xFF22FF44;
		if (judgment == Judgment.BAD)
			return 0xFFFFAA00;

		return 0xFFFF3344;
	}

	inline function groupCenter(isPlayer:Bool):Float
	{
		return FlxG.width * (isPlayer ? 0.72 : 0.28);
	}

	inline function laneCenter(direction:NoteDirection, isPlayer:Bool):Float
	{
		return groupCenter(isPlayer) + (cast(direction, Int) - 1.5) * LANE_WIDTH;
	}
}
