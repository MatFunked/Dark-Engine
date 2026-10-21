package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
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
	static inline var LANE_WIDTH:Float = 120;
	static inline var NOTE_SPEED:Float = 0.35;
	static inline var FIRST_NOTE_TIME:Float = 2000;
	static inline var NOTE_INTERVAL:Float = 600;

	var songTime:Float = 0;
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
		buildChart();
		buildUi();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		songTime += elapsed * 1000;

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

		for (i in 0...directions.length)
		{
			var direction = directions[i];
			var x = laneCenter(direction);

			var receptor = new FlxSprite(x - 32, RECEPTOR_Y - 32);
			receptor.makeGraphic(64, 64, 0xFF24243A);
			add(receptor);

			var label = new FlxText(x - 50, RECEPTOR_Y + 42, 100, labels[i], 14);
			label.alignment = FlxTextAlign.CENTER;
			label.color = FlxColor.GRAY;
			add(label);
		}
	}

	function buildChart():Void
	{
		var directions = NoteDirection.all();
		var colors = [0xFFC24B99, 0xFF00CFFF, 0xFF12FA05, 0xFFF9393F];

		for (i in 0...24)
		{
			var direction = directions[i % directions.length];
			var note = new Note(FIRST_NOTE_TIME + i * NOTE_INTERVAL, direction);
			var sprite = new FlxSprite(laneCenter(direction) - 28, -100);
			sprite.makeGraphic(56, 24, colors[cast(direction, Int)]);
			add(sprite);

			notes.push(note);
			chart.push({note: note, sprite: sprite});
		}
	}

	function buildUi():Void
	{
		var title = new FlxText(0, 24, FlxG.width, "ARROW INPUT TEST", 28);
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

		var windows = detector.windows;
		var info = new FlxText(0, 156, FlxG.width,
			'Sick ${windows.sickWindow} / Good ${windows.goodWindow} / Bad ${windows.badWindow} / Miss ${windows.missWindow} ms', 14);
		info.alignment = FlxTextAlign.CENTER;
		info.color = 0xFF8888AA;
		add(info);

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

	inline function laneCenter(direction:NoteDirection):Float
	{
		return FlxG.width * 0.5 + (cast(direction, Int) - 1.5) * LANE_WIDTH;
	}
}
