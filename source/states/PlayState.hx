package states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.utils.Assets;
import audio.SongAudio;
import chart.ChartLoader;
import chart.ChartSection;
import chart.FNFChart;
import events.SongEventManager;
import graphics.SparrowCharacter;
import graphics.SparrowLoader;
import input.ArrowInput;
import input.NoteDirection;
import notes.Judgment;
import notes.Note;
import notes.NoteDetector;
import notes.TimingWindows;
import settings.GameSettings;
import stages.Stage;
import ui.HealthBar;

private typedef ChartEntry =
{
	var note:Note;
	var sprite:FlxSprite;
	var tail:FlxSprite;
}

class PlayState extends FlxState
{
	static inline var LANE_WIDTH:Float = 110;
	static inline var NOTE_SPEED:Float = 0.35;
	static inline var SUSTAIN_WIDTH:Float = 26;
	static inline var SUSTAIN_BASE_HEIGHT:Float = 8;
	static inline var SUSTAIN_TICK_MS:Float = 50;
	static inline var SUSTAIN_SCORE_PER_TICK:Int = 10;
	static inline var SUSTAIN_HEAL_PER_TICK:Float = 0.0025;
	static inline var SUSTAIN_DROP_DAMAGE:Float = 0.035;
	static inline var SUSTAIN_PLAYER_ALPHA:Float = 0.6;
	static inline var SUSTAIN_OPPONENT_ALPHA:Float = 0.3;
	static inline var START_HEALTH:Float = 0.5;
	static inline var SICK_HEAL:Float = 0.035;
	static inline var GOOD_HEAL:Float = 0.015;
	static inline var SHIT_DAMAGE:Float = 0.02;
	static inline var MISS_DAMAGE:Float = 0.05;
	static inline var SICK_SCORE:Int = 350;
	static inline var GOOD_SCORE:Int = 200;
	static inline var BAD_SCORE:Int = 100;
	static inline var SHIT_SCORE:Int = 50;
	static inline var SICK_WEIGHT:Float = 1.0;
	static inline var GOOD_WEIGHT:Float = 0.75;
	static inline var BAD_WEIGHT:Float = 0.5;
	static inline var SHIT_WEIGHT:Float = 0.25;
	static inline var RECEPTOR_FLASH_TIME:Float = 0.12;
	static inline var RECEPTOR_FLASH_COLOR:Int = 0xFFB8B8FF;
	static inline var PLAYER_RECEPTOR_COLOR:Int = 0xFF2A2A45;
	static inline var OPPONENT_RECEPTOR_COLOR:Int = 0xFF1E1E30;
	static inline var NOTE_IMAGE_PATH:String = "assets/images/notes/notes.png";
	static inline var NOTE_XML_PATH:String = "assets/images/notes/notes.xml";
	static inline var HUD_DOWNSCROLL_HEALTH_Y:Float = 40;
	static inline var HUD_DOWNSCROLL_SCORE_OFFSET:Float = 35;
	static inline var HUD_UPSCROLL_HEALTH_OFFSET:Float = 70;
	static inline var HUD_UPSCROLL_SCORE_OFFSET:Float = 25;
	static inline var CAMERA_BASE_ZOOM:Float = 1.0;
	static inline var CAMERA_BEAT_ZOOM:Float = 0.025;
	static inline var CAMERA_ZOOM_IN_TIME:Float = 0.06;
	static inline var CAMERA_ZOOM_OUT_TIME:Float = 0.16;
	static inline var CAMERA_BEATS_PER_BUMP:Int = 4;
	static inline var CAMERA_FOCUS_SHIFT:Float = 0.06;
	static inline var CAMERA_FOCUS_TIME:Float = 0.45;

	public var songFolder(default, null):String;
	public var songDifficulty(default, null):String;

	var chartData:FNFChart;
	var songAudio:SongAudio;
	var noteFrames:FlxAtlasFrames;
	var stage:Stage;
	var playerCharacter:SparrowCharacter;
	var opponentCharacter:SparrowCharacter;
	var girlfriendCharacter:SparrowCharacter;
	var songTime:Float = 0;
	var elapsedSongTime:Float = 0;
	var health:Float = START_HEALTH;
	var gameOverTriggered:Bool = false;
	var resultsTriggered:Bool = false;
	var score:Int = 0;
	var sicks:Int = 0;
	var goods:Int = 0;
	var bads:Int = 0;
	var shits:Int = 0;
	var misses:Int = 0;
	var loadError:String = null;
	var arrows:ArrowInput;
	var downscroll:Bool = false;
	var strumLineY:Float = 50;
	var noteOffsetMs:Float = 0;
	var detector:NoteDetector;
	var notes:Array<Note> = [];
	var activeHolds:Array<Note> = [];
	var chart:Array<ChartEntry> = [];
	var opponentEntries:Array<ChartEntry> = [];
	var playerReceptors:Array<FlxSprite> = [null, null, null, null];
	var playerFlashTimers:Array<Float> = [0, 0, 0, 0];
	var opponentReceptors:Array<FlxSprite> = [null, null, null, null];
	var opponentFlashTimers:Array<Float> = [0, 0, 0, 0];
	var judgmentText:FlxText;
	var timerText:FlxText;
	var scoreText:FlxText;
	var healthBar:HealthBar;
	var feedbackTime:Float = 0;
	var hudCamera:FlxCamera;
	var songEventManager:SongEventManager;
	var cameraZoomTween:FlxTween;
	var cameraFocusTween:FlxTween;
	var beatTimes:Array<Float> = [];
	var fallbackFocusWindows:Array<Bool> = [];
	var nextBeatIndex:Int = 0;
	var beatCount:Int = 0;
	var currentFocusKey:Int = -1;

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
		setupCameras();
		GameSettings.load();
		downscroll = GameSettings.downscroll;
		strumLineY = downscroll ? FlxG.height - 150 : 50;
		noteOffsetMs = GameSettings.noteOffsetMs;
		arrows = new ArrowInput();

		for (direction in NoteDirection.all())
			arrows.bind(direction, [GameSettings.getKey(direction)]);

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

		buildBeatData();
		buildUi();
		updateCameraFocus();
		updateSongEvents();
	}

	override public function destroy():Void
	{
		if (songEventManager != null)
			songEventManager.destroy();

		if (cameraZoomTween != null)
			cameraZoomTween.cancel();

		if (cameraFocusTween != null)
			cameraFocusTween.cancel();

		if (songAudio != null)
			songAudio.destroy();

		FlxG.camera.zoom = CAMERA_BASE_ZOOM;
		FlxG.camera.scroll.set(0, 0);

		if (hudCamera != null && FlxG.cameras.list.indexOf(hudCamera) >= 0)
			FlxG.cameras.remove(hudCamera);

		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (songAudio != null)
			songAudio.update();

		elapsedSongTime += elapsed * 1000;

		var rawSongTime = songAudio != null && songAudio.isPlaying() ? songAudio.getTime() : elapsedSongTime;
		var chartOffset = chartData == null ? 0 : chartData.offset;
		songTime = rawSongTime + chartOffset - noteOffsetMs;

		updateCameraBeats();
		updateSongEvents();
		updateCameraFocus();
		updateOpponentAutoPlay();

		for (direction in arrows.justPressedDirections())
		{
			var result = detector.hitNote(notes, direction, songTime);

			if (result != null)
			{
				applyJudgment(result.judgment);
				showJudgment(result.judgment, result.offset);

				if (playerCharacter != null)
					playerCharacter.sing(direction);

				if (result.judgment != Judgment.MISS)
				{
					if (result.note.hasSustain())
						beginSustain(result.note, songTime);

					flashPlayerReceptor(direction);
				}
			}
		}

		updateSustains();

		for (note in detector.collectMissedNotes(notes, songTime))
		{
			applyJudgment(Judgment.MISS);
			showJudgment(Judgment.MISS, songTime - note.time);
		}

		if (playerCharacter != null)
			playerCharacter.updateCharacter(elapsed);

		if (opponentCharacter != null)
			opponentCharacter.updateCharacter(elapsed);

		if (girlfriendCharacter != null)
			girlfriendCharacter.updateCharacter(elapsed);

		updateNotePositions();
		updateReceptorFlashes(elapsed);
		updateFeedback(elapsed);

		timerText.text = '${Std.int(songTime / 10) / 100} s';
		scoreText.text = 'SCORE $score';

		if (!resultsTriggered && songAudio != null && songAudio.isFinished())
		{
			finishSong();
			return;
		}

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

	function finishSong():Void
	{
		resultsTriggered = true;

		for (note in notes)
		{
			if (!note.hit)
			{
				note.hit = true;
				note.judgment = Judgment.MISS;
				misses++;
			}
		}

		if (songAudio != null)
			songAudio.stop();

		var totalNotes = notes.length;
		var weightedScore = sicks * SICK_WEIGHT + goods * GOOD_WEIGHT + bads * BAD_WEIGHT + shits * SHIT_WEIGHT;
		var finalAccuracy = totalNotes == 0 ? 100.0 : weightedScore / totalNotes * 100;
		var songTitle = chartData == null ? songFolder : chartData.songName;

		FlxG.switchState(new ResultsState(songTitle, songDifficulty, score, finalAccuracy, misses, sicks, goods, bads, shits));
	}

	function buildLanes():Void
	{
		var directions = NoteDirection.all();
		var labels = ["LEFT", "DOWN", "UP", "RIGHT"];

		for (isPlayer in [false, true])
		{
			var receptors = isPlayer ? playerReceptors : opponentReceptors;

			for (i in 0...directions.length)
			{
				var direction = directions[i];
				var x = laneCenter(direction, isPlayer);

				var receptor = new FlxSprite(x - 32);
				receptor.makeGraphic(64, 64, FlxColor.WHITE);
				receptor.y = strumLineY - receptor.height * 0.5;
				receptor.color = isPlayer ? PLAYER_RECEPTOR_COLOR : OPPONENT_RECEPTOR_COLOR;
				add(receptor);

				receptors[cast(direction, Int)] = receptor;

				var label = new FlxText(x - 50, strumLineY + 42, 100, labels[i], 14);
				label.alignment = FlxTextAlign.CENTER;
				label.color = isPlayer ? FlxColor.GRAY : 0xFF555566;
				add(label);
			}

			var sideLabel = new FlxText(groupCenter(isPlayer) - 80, strumLineY + 68, 160, isPlayer ? "PLAYER" : "OPPONENT", 14);
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
		songEventManager = new SongEventManager(chartData.events, chartData.bpm, FlxG.camera, hudCamera);
		stage = new Stage(chartData.stage);
		insert(0, stage);
		buildCharacters();

		noteFrames = SparrowLoader.load(NOTE_IMAGE_PATH, NOTE_XML_PATH);

		if (noteFrames == null)
			FlxG.log.warn("Missing note atlas; using rectangular notes");

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

	function buildCharacters():Void
	{
		var opponentX = stage == null || stage.dadPosition == null ? FlxG.width * 0.28 : stage.dadPosition.x;
		var opponentY = stage == null || stage.dadPosition == null ? FlxG.height * 0.13 : stage.dadPosition.y;
		var playerX = stage == null || stage.bfPosition == null ? FlxG.width * 0.72 : stage.bfPosition.x;
		var playerY = stage == null || stage.bfPosition == null ? FlxG.height * 0.13 : stage.bfPosition.y;

		var insertIndex = 1;

		if (stage != null && stage.gfPosition != null && hasCharacterAssets(chartData.gfVersion))
		{
			girlfriendCharacter = new SparrowCharacter(chartData.gfVersion, false);
			girlfriendCharacter.placeAt(stage.gfPosition.x, stage.gfPosition.y);
			insert(insertIndex++, girlfriendCharacter);
		}

		opponentCharacter = new SparrowCharacter(chartData.opponentCharacter, false);
		playerCharacter = new SparrowCharacter(chartData.playerCharacter, true);

		opponentCharacter.placeAt(opponentX, opponentY);
		playerCharacter.placeAt(playerX, playerY);

		insert(insertIndex++, opponentCharacter);
		insert(insertIndex++, playerCharacter);
	}

	static function hasCharacterAssets(characterName:String):Bool
	{
		if (characterName == null || characterName == "")
			return false;

		return Assets.exists('assets/data/characters/$characterName.xml')
			&& Assets.exists('assets/images/characters/$characterName.png')
			&& Assets.exists('assets/images/characters/$characterName.xml');
	}

	function buildChart():Void
	{
		for (chartNote in chartData.notes)
		{
			var note = new Note(chartNote.time, chartNote.direction, chartNote.sustainLength);
			var sprite = createNoteSprite(chartNote.direction, chartNote.isPlayer);
			sprite.alpha = chartNote.isPlayer ? 1.0 : 0.5;
			var tail = chartNote.sustainLength > 0 ? createSustainSprite(chartNote.direction, chartNote.isPlayer) : null;

			if (tail != null)
				add(tail);

			add(sprite);

			var entry:ChartEntry = {note: note, sprite: sprite, tail: tail};
			chart.push(entry);

			if (chartNote.isPlayer)
				notes.push(note);
			else
				opponentEntries.push(entry);
		}
	}

	function createNoteSprite(direction:NoteDirection, isPlayer:Bool):FlxSprite
	{
		var sprite = new FlxSprite();

		if (noteFrames != null)
		{
			var frame = noteFrames.getByName(noteFrameName(direction));

			if (frame != null)
			{
				sprite.frames = noteFrames;
				sprite.frame = frame;
			}
			else
			{
				makeFallbackNote(sprite, direction);
			}
		}
		else
		{
			makeFallbackNote(sprite, direction);
		}

		sprite.x = laneCenter(direction, isPlayer) - sprite.width * 0.5;
		sprite.y = -100;
		return sprite;
	}

	function createSustainSprite(direction:NoteDirection, isPlayer:Bool):FlxSprite
	{
		var tail = new FlxSprite();
		tail.makeGraphic(Std.int(SUSTAIN_WIDTH), Std.int(SUSTAIN_BASE_HEIGHT), noteColor(direction));
		tail.origin.set(0, 0);
		tail.alpha = isPlayer ? SUSTAIN_PLAYER_ALPHA : SUSTAIN_OPPONENT_ALPHA;
		tail.x = laneCenter(direction, isPlayer) - SUSTAIN_WIDTH * 0.5;
		tail.y = -100;
		tail.visible = false;
		return tail;
	}

	function makeFallbackNote(sprite:FlxSprite, direction:NoteDirection):Void
	{
		sprite.makeGraphic(56, 24, noteColor(direction));
	}

	static function noteColor(direction:NoteDirection):Int
	{
		return switch (direction)
		{
			case LEFT: 0xFFC24B99;
			case DOWN: 0xFF00CFFF;
			case UP: 0xFF12FA05;
			case RIGHT: 0xFFF9393F;
		}
	}

	static function noteFrameName(direction:NoteDirection):String
	{
		return switch (direction)
		{
			case LEFT: "noteLEFT0000";
			case DOWN: "noteDOWN0000";
			case UP: "noteUP0000";
			case RIGHT: "noteRIGHT0000";
		}
	}

	function buildUi():Void
	{
		var titleText = chartData == null ? "DARK ENGINE" : '${chartData.songName.toUpperCase()} - ${songDifficulty.toUpperCase()}';
		var titleY = downscroll ? 4 : 24;
		var titleSize = downscroll ? 22 : 28;
		var title = new FlxText(0, titleY, FlxG.width, titleText, titleSize);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		title.cameras = [hudCamera];
		add(title);

		timerText = new FlxText(0, 28, FlxG.width - 24, "", 14);
		timerText.alignment = FlxTextAlign.RIGHT;
		timerText.color = FlxColor.GRAY;
		timerText.cameras = [hudCamera];
		add(timerText);

		var healthY:Float;
		var scoreY:Float;

		if (downscroll)
		{
			healthY = HUD_DOWNSCROLL_HEALTH_Y;
			scoreY = healthY + HUD_DOWNSCROLL_SCORE_OFFSET;
		}
		else
		{
			healthY = FlxG.height - HUD_UPSCROLL_HEALTH_OFFSET;
			scoreY = healthY - HUD_UPSCROLL_SCORE_OFFSET;
		}

		var healthX = FlxG.width * 0.5 - HealthBar.BAR_WIDTH * 0.5;
		healthBar = new HealthBar(healthX, healthY);
		healthBar.setCamera(hudCamera);
		add(healthBar);
		healthBar.setHealth(health);

		scoreText = new FlxText(healthX, scoreY, HealthBar.BAR_WIDTH, "SCORE 0", 16);
		scoreText.alignment = FlxTextAlign.CENTER;
		scoreText.color = 0xFFCCCCDD;
		scoreText.cameras = [hudCamera];
		add(scoreText);

		judgmentText = new FlxText(0, 100, FlxG.width, "", 44);
		judgmentText.alignment = FlxTextAlign.CENTER;
		judgmentText.color = FlxColor.WHITE;
		judgmentText.cameras = [hudCamera];
		add(judgmentText);

		if (chartData != null)
		{
			var chartInfo = new FlxText(0, 156, FlxG.width,
				'${chartData.bpm} BPM  |  ${chartData.notes.length} NOTES  |  ${chartData.getPlayerNotes().length} PLAYER', 14);
			chartInfo.alignment = FlxTextAlign.CENTER;
			chartInfo.color = 0xFF8888AA;
			chartInfo.cameras = [hudCamera];
			add(chartInfo);
		}

		var windows = detector.windows;
		var info = new FlxText(0, 180, FlxG.width,
			'Sick ${windows.sickWindow} / Good ${windows.goodWindow} / Bad ${windows.badWindow} / Shit ${windows.missWindow} ms', 14);
		info.alignment = FlxTextAlign.CENTER;
		info.color = 0xFF666688;
		info.cameras = [hudCamera];
		add(info);

		if (loadError != null)
		{
			var errorText = new FlxText(0, 216, FlxG.width, loadError, 16);
			errorText.alignment = FlxTextAlign.CENTER;
			errorText.color = 0xFFFF4455;
			errorText.cameras = [hudCamera];
			add(errorText);
		}

		var hint = new FlxText(0, FlxG.height - 32, FlxG.width, "ESC: PAUSE    R: RESTART", 14);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		hint.cameras = [hudCamera];
		add(hint);
	}

	function setupCameras():Void
	{
		FlxG.camera.zoom = CAMERA_BASE_ZOOM;
		FlxG.camera.scroll.set(0, 0);

		hudCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		hudCamera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(hudCamera, false);
	}

	function buildBeatData():Void
	{
		beatTimes = [];
		fallbackFocusWindows = [];
		nextBeatIndex = 0;
		beatCount = 0;
		currentFocusKey = -1;

		if (chartData == null)
			return;

		var endTime = 0.0;

		for (note in chartData.notes)
			endTime = Math.max(endTime, note.time + note.sustainLength);

		if (chartData.bpmChanges.length > 0)
		{
			for (i in 0...chartData.bpmChanges.length)
			{
				var change = chartData.bpmChanges[i];

				if (change.bpm <= 0)
					continue;

				var nextTime = i + 1 < chartData.bpmChanges.length ? chartData.bpmChanges[i + 1].time : endTime + 1;
				var interval = 60000 / change.bpm;
				var time = change.time;

				while (time < nextTime)
				{
					addBeatTime(time);
					time += interval;
				}
			}
		}
		else if (chartData.bpm > 0)
		{
			var interval = 60000 / chartData.bpm;
			var time = 0.0;

			while (time <= endTime + interval)
			{
				beatTimes.push(time);
				time += interval;
			}
		}

		if (chartData.sections.length == 0 && chartData.bpm > 0)
			buildFallbackFocusWindows(60000 / chartData.bpm);
	}

	function addBeatTime(time:Float):Void
	{
		if (beatTimes.length > 0 && time - beatTimes[beatTimes.length - 1] < 0.5)
			return;

		beatTimes.push(time);
	}

	function buildFallbackFocusWindows(interval:Float):Void
	{
		if (chartData == null || chartData.notes.length == 0)
			return;

		var previous = false;
		var index = 0;

		while (index < beatTimes.length)
		{
			var start = beatTimes[index];
			var end = start + interval * CAMERA_BEATS_PER_BUMP;
			var playerNotes = 0;
			var opponentNotes = 0;

			for (note in chartData.notes)
			{
				if (note.time < start)
					continue;

				if (note.time >= end)
					break;

				if (note.isPlayer)
					playerNotes++;
				else
					opponentNotes++;
			}

			var mustHit = playerNotes > opponentNotes ? true : (opponentNotes > playerNotes ? false : previous);
			fallbackFocusWindows.push(mustHit);
			previous = mustHit;
			index += CAMERA_BEATS_PER_BUMP;
		}
	}

	function updateCameraBeats():Void
	{
		if (beatTimes.length == 0)
			return;

		while (nextBeatIndex < beatTimes.length && beatTimes[nextBeatIndex] <= songTime)
		{
			nextBeatIndex++;
			beatCount++;

			if (beatCount % CAMERA_BEATS_PER_BUMP == 0)
				bumpCamera();
		}
	}

	function updateSongEvents():Void
	{
		if (songEventManager != null)
			songEventManager.update(songTime);
	}

	function updateCameraFocus():Void
	{
		if (chartData == null || (songEventManager != null && songEventManager.hasCameraFocusEvents))
			return;

		var key:Int;
		var mustHit:Bool;

		if (chartData.sections.length > 0)
		{
			var section = currentSection(songTime);
			key = section.index;
			mustHit = section.mustHitSection;
		}
		else
		{
			if (fallbackFocusWindows.length == 0)
				return;

			key = Std.int(beatCount / CAMERA_BEATS_PER_BUMP);

			if (key < 0)
				key = 0;
			else if (key >= fallbackFocusWindows.length)
				key = fallbackFocusWindows.length - 1;

			mustHit = fallbackFocusWindows[key];
		}

		if (key == currentFocusKey)
			return;

		currentFocusKey = key;
		var targetScrollX = (mustHit ? 1 : -1) * FlxG.width * CAMERA_FOCUS_SHIFT;

		if (cameraFocusTween != null)
			cameraFocusTween.cancel();

		cameraFocusTween = FlxTween.num(FlxG.camera.scroll.x, targetScrollX, CAMERA_FOCUS_TIME, {ease: FlxEase.cubeInOut},
			function(value:Float):Void
			{
				FlxG.camera.scroll.x = value;
			});
	}

	function currentSection(time:Float):ChartSection
	{
		var sections = chartData.sections;
		var current = sections[0];

		for (section in sections)
		{
			if (section.startTime > time)
				break;

			current = section;
		}

		return current;
	}

	function bumpCamera():Void
	{
		if (songEventManager != null)
		{
			songEventManager.bumpCamera(CAMERA_BEAT_ZOOM);
			return;
		}

		if (cameraZoomTween != null)
			cameraZoomTween.cancel();

		var camera = FlxG.camera;
		cameraZoomTween = FlxTween.tween(camera, {zoom: CAMERA_BASE_ZOOM + CAMERA_BEAT_ZOOM}, CAMERA_ZOOM_IN_TIME, {
			ease: FlxEase.quadOut,
			onComplete: function(_):Void
			{
				cameraZoomTween = FlxTween.tween(camera, {zoom: CAMERA_BASE_ZOOM}, CAMERA_ZOOM_OUT_TIME, {ease: FlxEase.quadIn});
			}
		});
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

			if (opponentCharacter != null)
				opponentCharacter.sing(entry.note.direction);
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
				sprite.visible = false;
			else
			{
				var y = noteYAt(note.time, sprite.height);
				sprite.y = y;
				sprite.visible = y > -sprite.height && y < FlxG.height;
			}

			updateSustainPosition(entry);
		}
	}

	function updateSustainPosition(entry:ChartEntry):Void
	{
		var tail = entry.tail;

		if (tail == null)
			return;

		var note = entry.note;

		if (note.sustainDropped || note.sustainCompleted || note.judgment == Judgment.MISS)
		{
			tail.visible = false;
			return;
		}

		var endTime = note.getEndTime();

		if (songTime >= endTime)
		{
			tail.visible = false;
			return;
		}

		var startY = note.hit ? strumLineY : noteYAt(note.time, entry.sprite.height);
		var endY = noteYAt(endTime, entry.sprite.height);
		var top = Math.min(startY, endY);
		var bottom = Math.max(startY, endY);
		var length = bottom - top;

		if (length <= 1)
		{
			tail.visible = false;
			return;
		}

		tail.y = top;
		tail.scale.y = length / SUSTAIN_BASE_HEIGHT;
		tail.visible = top < FlxG.height && bottom > 0;
	}

	function beginSustain(note:Note, currentTime:Float):Void
	{
		note.sustainActive = true;
		note.sustainDropped = false;
		note.sustainCompleted = false;
		note.sustainLastTick = Math.max(note.time, currentTime);
		activeHolds.push(note);
	}

	function updateSustains():Void
	{
		var i = activeHolds.length - 1;

		while (i >= 0)
		{
			var note = activeHolds[i];
			var endTime = note.getEndTime();

			if (songTime >= endTime)
			{
				note.sustainActive = false;
				note.sustainCompleted = true;
				activeHolds.splice(i, 1);
			}
			else if (!arrows.isPressed(note.direction))
			{
				cutSustain(note);
				activeHolds.splice(i, 1);
			}
			else
			{
				var nextTick = note.sustainLastTick + SUSTAIN_TICK_MS;

				while (nextTick <= songTime && nextTick <= endTime)
				{
					note.sustainLastTick = nextTick;
					awardSustainTick();
					nextTick += SUSTAIN_TICK_MS;
				}
			}

			i--;
		}
	}

	function awardSustainTick():Void
	{
		score += SUSTAIN_SCORE_PER_TICK;
		health = Math.min(1, health + SUSTAIN_HEAL_PER_TICK);

		if (healthBar != null)
			healthBar.setHealth(health);
	}

	function cutSustain(note:Note):Void
	{
		note.sustainActive = false;
		note.sustainDropped = true;
		health = Math.max(0, health - SUSTAIN_DROP_DAMAGE);

		if (healthBar != null)
			healthBar.setHealth(health);

		if (songAudio != null)
			songAudio.setPlayerVocalsMuted(true);

		judgmentText.text = "HOLD CUT";
		judgmentText.color = 0xFFFF66AA;
		judgmentText.alpha = 1;
		feedbackTime = 0.8;
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
		{
			sicks++;
			score += SICK_SCORE;
			health += SICK_HEAL;
		}
		else if (judgment == Judgment.GOOD)
		{
			goods++;
			score += GOOD_SCORE;
			health += GOOD_HEAL;
		}
		else if (judgment == Judgment.BAD)
		{
			bads++;
			score += BAD_SCORE;
		}
		else if (judgment == Judgment.SHIT)
		{
			shits++;
			score += SHIT_SCORE;
			health -= SHIT_DAMAGE;
		}
		else if (judgment == Judgment.MISS)
		{
			misses++;
			health -= MISS_DAMAGE;
		}

		health = Math.max(0, Math.min(1, health));

		if (healthBar != null)
			healthBar.setHealth(health);

		if (songAudio != null)
		{
			if (judgment == Judgment.MISS || judgment == Judgment.SHIT)
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
		if (judgment == Judgment.SHIT)
			return 0xFFB36BFF;

		return 0xFFFF3344;
	}

	inline function noteYAt(time:Float, height:Float):Float
	{
		if (downscroll)
			return strumLineY - height * 0.5 - (time - songTime) * NOTE_SPEED;

		return strumLineY - height * 0.5 + (time - songTime) * NOTE_SPEED;
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
