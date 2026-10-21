package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import openfl.utils.Assets;
import audio.SongAudio;
import chart.ChartLoader;
import chart.FNFChart;
import input.ArrowInput;
import input.NoteDirection;
import notes.Judgment;
import notes.Note;
import notes.NoteDetector;
import notes.TimingWindows;
import ui.HealthBar;

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
	static inline var START_HEALTH:Float = 0.5;
	static inline var SICK_HEAL:Float = 0.035;
	static inline var GOOD_HEAL:Float = 0.015;
	static inline var MISS_DAMAGE:Float = 0.05;
	static inline var RECEPTOR_FLASH_TIME:Float = 0.12;
	static inline var RECEPTOR_FLASH_COLOR:Int = 0xFFB8B8FF;
	static inline var PLAYER_RECEPTOR_COLOR:Int = 0xFF2A2A45;
	static inline var OPPONENT_RECEPTOR_COLOR:Int = 0xFF1E1E30;

	public var songFolder(default, null):String;
	public var songDifficulty(default, null):String;

	var chartData:FNFChart;
	var songAudio:SongAudio;
	var songTime:Float = 0;
	var elapsedSongTime:Float = 0;
	var health:Float = START_HEALTH;
	var gameOverTriggered:Bool = false;
	var loadError:String = null;
	var arrows:ArrowInput;
	var detector:NoteDetector;
	var notes:Array<Note> = [];
	var chart:Array<ChartEntry> = [];
	var opponentEntries:Array<ChartEntry> = [];
	var playerReceptors:Array<FlxSprite> = [null, null, null, null];
	var playerFlashTimers:Array<Float> = [0, 0, 0, 0];
	var opponentReceptors:Array<FlxSprite> = [null, null, null, null];
	var opponentFlashTimers:Array<Float> = [0, 0, 0, 0];
	var judgmentText:FlxText;
	var timerText:FlxText;
	var healthBar:HealthBar;
	var feedbackTime:Float = 0;

	public function new(?songFolder:String = "emma", ?difficulty:String = "hard")
	{
		super();
		this.songFolder = songFolder;
		this.songDifficulty = difficulty.toLowerCase();
	}

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
		if (songAudio != null)
			songAudio.destroy();

		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (songAudio != null)
			songAudio.update();

		elapsedSongTime += elapsed * 1000;

		if (songAudio != null && songAudio.isPlaying())
			songTime = songAudio.getTime() + (chartData == null ? 0 : chartData.offset);
		else
			songTime = elapsedSongTime + (chartData == null ? 0 : chartData.offset);

		updateOpponentAutoPlay();

		for (direction in arrows.justPressedDirections())
		{
			var result = detector.hitNote(notes, direction, songTime);

			if (result != null)
			{
				applyJudgment(result.judgment);
				showJudgment(result.judgment, result.offset);

				if (result.judgment != Judgment.MISS)
					flashPlayerReceptor(direction);
			}
		}

		for (note in detector.collectMissedNotes(notes, songTime))
		{
			applyJudgment(Judgment.MISS);
			showJudgment(Judgment.MISS, songTime - note.time);
		}

		updateNotePositions();
		updateReceptorFlashes(elapsed);
		updateFeedback(elapsed);

		timerText.text = '${Std.int(songTime / 10) / 100} s';

		if (health <= 0 && !gameOverTriggered)
		{
			gameOverTriggered = true;

			if (songAudio != null)
				songAudio.stop();

			FlxG.switchState(new GameOverState(songFolder, songDifficulty));
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
			openSubState(new PauseSubState(this));
		else if (FlxG.keys.justPressed.R)
			restartLevel();
	}

	public function pauseSong():Void
	{
		if (songAudio != null)
			songAudio.pause();
	}

	public function resumeSong():Void
	{
		if (songAudio != null)
			songAudio.resume();
	}

	function restartLevel():Void
	{
		FlxG.switchState(new PlayState(songFolder, songDifficulty));
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
				receptor.makeGraphic(64, 64, FlxColor.WHITE);
				receptor.color = isPlayer ? PLAYER_RECEPTOR_COLOR : OPPONENT_RECEPTOR_COLOR;
				add(receptor);

				if (isPlayer)
					playerReceptors[cast(direction, Int)] = receptor;
				else
					opponentReceptors[cast(direction, Int)] = receptor;

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
		var chartPath = 'assets/songs/$songFolder/charts/$songDifficulty.json';
		var metaPath = 'assets/songs/$songFolder/meta.json';
		chartData = ChartLoader.loadSong(chartPath, metaPath);
		buildChart();

		var audioPath = 'assets/songs/$songFolder/song';
		var singleVoicesPath = '${audioPath}/Voices.ogg';
		songAudio = new SongAudio();

		if (Assets.exists(singleVoicesPath))
		{
			songAudio.loadSingleVoices('${audioPath}/Inst.ogg', singleVoicesPath);
		}
		else
		{
			var opponentSuffix = chartData.opponentVocalsSuffix;
			var playerSuffix = chartData.playerVocalsSuffix;

			if (opponentSuffix == "" || playerSuffix == "")
				throw 'Voice tracks not found for $songFolder';

			songAudio.load('${audioPath}/Inst.ogg', '${audioPath}/Voices${opponentSuffix}.ogg', '${audioPath}/Voices${playerSuffix}.ogg');
		}

		songAudio.play();
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

			var entry:ChartEntry = {note: note, sprite: sprite};
			chart.push(entry);

			if (chartNote.isPlayer)
				notes.push(note);
			else
				opponentEntries.push(entry);
		}
	}

	function buildUi():Void
	{
		var titleText = chartData == null ? "DARK ENGINE" : '${chartData.songName.toUpperCase()} - ${songDifficulty.toUpperCase()}';
		var title = new FlxText(0, 24, FlxG.width, titleText, 28);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		timerText = new FlxText(0, 28, FlxG.width - 24, "", 14);
		timerText.alignment = FlxTextAlign.RIGHT;
		timerText.color = FlxColor.GRAY;
		add(timerText);

		healthBar = new HealthBar(FlxG.width * 0.5 - HealthBar.BAR_WIDTH * 0.5, 66);
		add(healthBar);
		healthBar.setHealth(health);

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

		var hint = new FlxText(0, FlxG.height - 32, FlxG.width, "ESC: PAUSE    R: RESTART", 14);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		add(hint);
	}

	function updateOpponentAutoPlay():Void
	{
		for (entry in opponentEntries)
		{
			if (entry.note.hit || songTime < entry.note.time)
				continue;

			entry.note.hit = true;
			entry.sprite.visible = false;
			flashOpponentReceptor(entry.note.direction);
		}
	}

	function flashPlayerReceptor(direction:NoteDirection):Void
	{
		flashReceptor(playerReceptors, playerFlashTimers, direction);
	}

	function flashOpponentReceptor(direction:NoteDirection):Void
	{
		flashReceptor(opponentReceptors, opponentFlashTimers, direction);
	}

	function flashReceptor(receptors:Array<FlxSprite>, timers:Array<Float>, direction:NoteDirection):Void
	{
		var index = cast(direction, Int);
		var receptor = receptors[index];

		if (receptor == null)
			return;

		receptor.color = RECEPTOR_FLASH_COLOR;
		timers[index] = RECEPTOR_FLASH_TIME;
	}

	function updateReceptorFlashes(elapsed:Float):Void
	{
		updateReceptorFlashGroup(playerReceptors, playerFlashTimers, PLAYER_RECEPTOR_COLOR, elapsed);
		updateReceptorFlashGroup(opponentReceptors, opponentFlashTimers, OPPONENT_RECEPTOR_COLOR, elapsed);
	}

	function updateReceptorFlashGroup(receptors:Array<FlxSprite>, timers:Array<Float>, baseColor:Int, elapsed:Float):Void
	{
		for (i in 0...timers.length)
		{
			if (timers[i] <= 0)
				continue;

			timers[i] -= elapsed;

			if (timers[i] <= 0 && receptors[i] != null)
				receptors[i].color = baseColor;
		}
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

	function applyJudgment(judgment:Judgment):Void
	{
		if (judgment == Judgment.SICK)
			health += SICK_HEAL;
		else if (judgment == Judgment.GOOD)
			health += GOOD_HEAL;
		else if (judgment == Judgment.MISS)
			health -= MISS_DAMAGE;

		health = Math.max(0, Math.min(1, health));

		if (healthBar != null)
			healthBar.setHealth(health);

		if (songAudio != null)
		{
			if (judgment == Judgment.MISS)
				songAudio.setPlayerVocalsMuted(true);
			else if (judgment == Judgment.SICK || judgment == Judgment.GOOD)
				songAudio.setPlayerVocalsMuted(false);
		}
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
