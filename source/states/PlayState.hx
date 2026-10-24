package states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.input.keyboard.FlxKey;
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
import chart.StrumLineData;
import events.SongEventManager;
import graphics.SparrowCharacter;
import graphics.SparrowLoader;
import input.NoteDirection;
import minigames.BaseMinigame;
import minigames.MinigameContext;
import minigames.MinigameRegistry;
import notes.Judgment;
import notes.Note;
import notes.NoteDetector;
import notes.TimingWindows;
import play.StrumLine;
import settings.GameSettings;
import stages.Stage;
import ui.HealthBar;

private typedef ChartEntry =
{
	var note:Note;
	var sprite:FlxSprite;
	var tail:FlxSprite;
	var line:StrumLine;
	var lane:Int;
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
	static inline var STRUM_UPSCROLL_Y:Float = 80;
	static inline var STRUM_DOWNSCROLL_BOTTOM_MARGIN:Float = 150;
	static inline var STRUM_LABEL_OFFSET:Float = 42;
	static inline var STRUM_SIDE_LABEL_OFFSET:Float = 68;
	static inline var CAMERA_BASE_ZOOM:Float = 1.0;
	static inline var CAMERA_BEAT_ZOOM:Float = 0.025;
	static inline var CAMERA_ZOOM_IN_TIME:Float = 0.06;
	static inline var CAMERA_ZOOM_OUT_TIME:Float = 0.16;
	static inline var CAMERA_BEATS_PER_BUMP:Int = 4;
	static inline var CAMERA_FOCUS_SHIFT:Float = 0.06;
	static inline var CAMERA_FOCUS_TIME:Float = 0.45;
	static inline var DEBUG_PONG_TIME:Float = 8;
	static inline var DEBUG_UNDERTALE_TIME:Float = 6;

	static var EXTRA_KEY_POOL:Array<FlxKey> = [
		FlxKey.A, FlxKey.S, FlxKey.D, FlxKey.F, FlxKey.G, FlxKey.H,
		FlxKey.J, FlxKey.K, FlxKey.L, FlxKey.SEMICOLON, FlxKey.QUOTE, FlxKey.Z,
		FlxKey.X, FlxKey.C, FlxKey.V, FlxKey.B, FlxKey.N, FlxKey.M,
		FlxKey.COMMA, FlxKey.PERIOD, FlxKey.NUMPADONE, FlxKey.NUMPADTWO, FlxKey.NUMPADTHREE, FlxKey.NUMPADFOUR
	];

	public var songFolder(default, null):String;
	public var songDifficulty(default, null):String;
	public var activeMinigame(default, null):BaseMinigame;
	public var hudCamera(default, null):FlxCamera;

	var chartData:FNFChart;
	var songAudio:SongAudio;
	var noteFrames:FlxAtlasFrames;
	var stage:Stage;
	var girlfriendCharacter:SparrowCharacter;
	var strumLines:Array<StrumLine> = [];
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
	var downscroll:Bool = false;
	var strumLineY:Float = 50;
	var noteOffsetMs:Float = 0;
	var detector:NoteDetector;
	var notes:Array<Note> = [];
	var activeHolds:Array<Note> = [];
	var chart:Array<ChartEntry> = [];
	var opponentEntries:Array<ChartEntry> = [];
	var judgmentText:FlxText;
	var timerText:FlxText;
	var scoreText:FlxText;
	var healthBar:HealthBar;
	#if debug
	var debugStatsVisible:Bool = false;
	var debugChartInfoText:FlxText;
	var debugTimingInfoText:FlxText;
	#end
	var feedbackTime:Float = 0;
	var songEventManager:SongEventManager;
	var cameraZoomTween:FlxTween;
	var cameraFocusTween:FlxTween;
	var beatTimes:Array<Float> = [];
	var fallbackFocusWindows:Array<Bool> = [];
	var nextBeatIndex:Int = 0;
	var beatCount:Int = 0;
	var currentFocusKey:Int = -1;
	var minigamePersistentDraw:Bool = true;
	var minigamePersistentUpdate:Bool = false;
	var rhythmUiHidden:Bool = false;

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
		configureScrollLayout();
		noteOffsetMs = GameSettings.noteOffsetMs;
		detector = new NoteDetector(new TimingWindows());

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
		activeMinigame = null;

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
		updateHudText();

		#if debug
		if (FlxG.keys.justPressed.F3)
			toggleDebugStats();
		#end

		if (activeMinigame != null)
		{
			updateMinigameBackground(elapsed);
			return;
		}

		updateOpponentAutoPlay();
		updatePlayerInput();
		updateSustains();

		for (note in detector.collectMissedNotes(notes, songTime))
		{
			applyJudgment(Judgment.MISS, note.strumLineIndex);
			showJudgment(Judgment.MISS, songTime - note.time);
		}

		updateCharacters(elapsed);
		updateNotePositions();
		updateReceptorFlashes(elapsed);
		updateFeedback(elapsed);

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

		if (FlxG.keys.justPressed.SEVEN || FlxG.keys.justPressed.NUMPADSEVEN)
		{
			if (startMinigame("pong", DEBUG_PONG_TIME, "normal"))
				return;
		}
		else if (FlxG.keys.justPressed.EIGHT || FlxG.keys.justPressed.NUMPADEIGHT)
		{
			if (startMinigame("undertale", DEBUG_UNDERTALE_TIME, "normal"))
				return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
			openSubState(new PauseSubState(this));
		else if (FlxG.keys.justPressed.R)
			restartLevel();
	}

	function updateHudText():Void
	{
		timerText.text = '${Std.int(songTime / 10) / 100} s';
		scoreText.text = 'SCORE $score';
	}

	function updateMinigameBackground(elapsed:Float):Void
	{
		updateCharacters(elapsed);
		updateReceptorFlashes(elapsed);
		updateFeedback(elapsed);
	}

	function updateCharacters(elapsed:Float):Void
	{
		for (line in strumLines)
			line.updateCharacter(elapsed);

		if (girlfriendCharacter != null)
			girlfriendCharacter.updateCharacter(elapsed);
	}

	function updatePlayerInput():Void
	{
		for (line in strumLines)
		{
			if (!line.isPlayer)
				continue;

			for (lane in 0...line.keyCount)
			{
				if (!line.justPressed(lane))
					continue;

				var result = detector.hitNoteForLane(notes, line.index, lane, songTime);

				if (result == null)
					continue;

				applyJudgment(result.judgment, line.index);
				showJudgment(result.judgment, result.offset);
				line.sing(result.note.direction);

				if (result.judgment != Judgment.MISS)
				{
					if (result.note.hasSustain())
						beginSustain(result.note, songTime);

					flashReceptor(line, lane);
				}
			}
		}
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

	public function triggerMinigameEvent(type:String, duration:Float, difficulty:String, params:Array<Dynamic>):Void
	{
		startMinigame(type, duration, difficulty, params);
	}

	public function startMinigame(type:String, duration:Float = 15, difficulty:String = "normal", ?params:Array<Dynamic>):Bool
	{
		if (activeMinigame != null)
			return false;

		if (duration <= 0)
			duration = SongEventManager.DEFAULT_MINIGAME_TIME;

		var camera = hudCamera != null ? hudCamera : FlxG.camera;
		var context = new MinigameContext(type, duration, difficulty, params, camera);
		var minigame = MinigameRegistry.create(type, context);

		if (minigame == null)
		{
			FlxG.log.warn('Unknown minigame type: $type');
			return false;
		}

		activeMinigame = minigame;
		minigamePersistentDraw = persistentDraw;
		minigamePersistentUpdate = persistentUpdate;
		persistentDraw = false;
		persistentUpdate = true;
		hideRhythmUi();

		minigame.closeCallback = function():Void
		{
			onMinigameClosed(minigame);
		};

		openSubState(minigame);
		return true;
	}

	public function cancelMinigame():Void
	{
		if (activeMinigame != null)
			activeMinigame.cancel();
	}

	function onMinigameClosed(minigame:BaseMinigame):Void
	{
		if (minigame != activeMinigame)
			return;

		var type = minigame.context == null ? "" : minigame.context.type;
		activeMinigame = null;
		persistentDraw = minigamePersistentDraw;
		persistentUpdate = minigamePersistentUpdate;
		discardPassedMinigameNotes();
		showRhythmUi();

		FlxG.log.add('Minigame $type ended: ${minigame.result}');
	}

	function hideRhythmUi():Void
	{
		rhythmUiHidden = true;
		releaseMinigameHolds();
		setRhythmControlsVisible(false);
		hideNoteSprites();
	}

	function showRhythmUi():Void
	{
		rhythmUiHidden = false;
		setRhythmControlsVisible(true);
		updateNotePositions();
	}

	function setRhythmControlsVisible(visible:Bool):Void
	{
		for (line in strumLines)
		{
			for (receptor in line.receptors)
			{
				if (receptor != null)
					receptor.visible = visible;
			}

			for (label in line.labelTexts)
				label.visible = visible;

			if (line.sideLabel != null)
				line.sideLabel.visible = visible;
		}
	}

	function hideNoteSprites():Void
	{
		for (entry in chart)
		{
			entry.sprite.visible = false;

			if (entry.tail != null)
				entry.tail.visible = false;
		}
	}

	function releaseMinigameHolds():Void
	{
		for (note in activeHolds)
		{
			note.sustainActive = false;
			note.sustainCompleted = true;
		}

		activeHolds = [];
	}

	function discardPassedMinigameNotes():Void
	{
		if (detector == null)
			return;

		var remaining:Array<Note> = [];

		for (note in notes)
		{
			if (!note.hit && songTime >= note.time)
			{
				note.hit = true;
				note.judgment = null;
				note.sustainActive = false;
				note.sustainCompleted = true;
			}
			else
			{
				remaining.push(note);
			}
		}

		notes = remaining;

		for (entry in opponentEntries)
		{
			var note = entry.note;

			if (note.hit || songTime < note.time)
				continue;

			note.hit = true;
			note.judgment = null;
			note.sustainActive = false;
			note.sustainCompleted = true;
		}
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

	function buildRuntimeStrumLines():Void
	{
		strumLines = [];

		if (chartData == null)
			return;

		var visibleLines:Array<StrumLineData> = [];

		for (data in chartData.strumLines)
		{
			if (data != null && data.visible)
				visibleLines.push(data);
		}

		if (visibleLines.length == 0)
			return;

		var playerTotal = 0;
		var opponentTotal = 0;

		for (data in visibleLines)
		{
			if (data.isPlayer)
				playerTotal++;
			else if (data.isOpponent)
				opponentTotal++;
		}

		var playerSeen = 0;
		var opponentSeen = 0;
		var extraSeen = 0;

		for (i in 0...visibleLines.length)
		{
			var data = visibleLines[i];
			var line = new StrumLine(data);
			line.baseReceptorColor = line.isPlayer ? PLAYER_RECEPTOR_COLOR : OPPONENT_RECEPTOR_COLOR;

			if (line.isPlayer)
			{
				playerSeen++;
				line.displayLabel = playerTotal > 1 ? 'PLAYER $playerSeen' : 'PLAYER';
			}
			else if (line.isOpponent)
			{
				opponentSeen++;
				line.displayLabel = opponentTotal > 1 ? 'OPPONENT $opponentSeen' : 'OPPONENT';
			}
			else
			{
				extraSeen++;
				line.displayLabel = 'EXTRA $extraSeen';
			}

			configureLineLayout(line, i, visibleLines.length);
			configureLineKeys(line, line.isPlayer ? playerSeen - 1 : -1);
			buildLineVisuals(line);
			strumLines.push(line);
		}
	}

	function configureLineLayout(line:StrumLine, index:Int, count:Int):Void
	{
		var groupWidth = Math.min(line.keyCount * LANE_WIDTH, FlxG.width / Math.max(1, count) - 40);
		line.laneWidth = groupWidth / line.keyCount;
		line.baseY = strumLineY;

		if (line.data.strumLinePos >= 0 && line.data.strumLinePos <= 1)
		{
			line.centerX = FlxG.width * line.data.strumLinePos;
		}
		else if (count == 2 && line.isPlayer)
		{
			line.centerX = stage != null && stage.bfPosition != null ? stage.bfPosition.x : FlxG.width * 0.72;
		}
		else if (count == 2 && line.isOpponent)
		{
			line.centerX = stage != null && stage.dadPosition != null ? stage.dadPosition.x : FlxG.width * 0.28;
		}
		else
		{
			line.centerX = FlxG.width * (index + 0.5) / count;
		}
	}

	function configureLineKeys(line:StrumLine, playerOrdinal:Int):Void
	{
		if (!line.isPlayer)
			return;

		if (line.data.keys.length > 0)
		{
			for (lane in 0...line.keyCount)
			{
				if (lane >= line.data.keys.length)
					break;

				var text = line.data.keys[lane];
				var key = FlxKey.fromString(text);

				if (key == FlxKey.NONE)
				{
					var code = Std.parseInt(text);

					if (code != null)
						key = cast code;
				}

				if (key != FlxKey.NONE)
					line.setKey(lane, key);
			}

			return;
		}

		var directions = NoteDirection.all();
		var offset = playerOrdinal == 0 ? 0 : 4 + (playerOrdinal - 1) * 6;

		for (lane in 0...line.keyCount)
		{
			if (playerOrdinal == 0 && lane < directions.length)
				line.setKey(lane, GameSettings.getKey(directions[lane]));
			else
				line.setKey(lane, EXTRA_KEY_POOL[(offset + lane) % EXTRA_KEY_POOL.length]);
		}
	}

	function buildLineVisuals(line:StrumLine):Void
	{
		var labelNames = ["LEFT", "DOWN", "UP", "RIGHT"];
		var labelY = strumLineY + STRUM_LABEL_OFFSET;
		var sideLabelY = strumLineY + STRUM_SIDE_LABEL_OFFSET;
		var receptorSize = Math.max(28, Math.min(64, line.laneWidth - 6));

		for (lane in 0...line.keyCount)
		{
			var x = line.laneCenter(lane);
			var receptor = new FlxSprite(x - receptorSize * 0.5);
			receptor.makeGraphic(Std.int(receptorSize), Std.int(receptorSize), FlxColor.WHITE);
			receptor.y = strumLineY - receptor.height * 0.5;
			receptor.color = line.baseReceptorColor;
			bindToHud(receptor);
			add(receptor);
			line.receptors[lane] = receptor;

			var directionName = labelNames[lane % labelNames.length];
			var label = new FlxText(x - line.laneWidth * 0.5, labelY, line.laneWidth, directionName, line.laneWidth < 60 ? 11 : 14);
			label.alignment = FlxTextAlign.CENTER;
			label.color = line.isPlayer ? FlxColor.GRAY : 0xFF555566;
			bindToHud(label);
			add(label);
			line.labelTexts.push(label);
		}

		var groupWidth = line.laneWidth * line.keyCount;
		var sideLabel = new FlxText(line.centerX - groupWidth * 0.5, sideLabelY, groupWidth, line.label(), 14);
		sideLabel.alignment = FlxTextAlign.CENTER;
		sideLabel.color = line.isPlayer ? 0xFF88AAFF : 0xFF887788;
		bindToHud(sideLabel);
		add(sideLabel);
		line.sideLabel = sideLabel;
	}

	function loadLevel():Void
	{
		var chartPath = 'assets/songs/$songFolder/charts/$songDifficulty.json';
		var metaPath = 'assets/songs/$songFolder/meta.json';
		chartData = ChartLoader.loadSong(chartPath, metaPath);
		songEventManager = new SongEventManager(chartData.events, chartData.bpm, FlxG.camera, hudCamera, triggerMinigameEvent);
		stage = new Stage(chartData.stage);
		insert(0, stage);

		noteFrames = SparrowLoader.load(NOTE_IMAGE_PATH, NOTE_XML_PATH);

		if (noteFrames == null)
			FlxG.log.warn("Missing note atlas; using rectangular notes");

		buildRuntimeStrumLines();
		buildCharacters();
		buildChart();
		loadSongAudio();
	}

	function loadSongAudio():Void
	{
		var audioPath = 'assets/songs/$songFolder/song';
		var voiceFiles = discoverVoiceFiles(audioPath);
		var voicePaths:Array<String> = [];
		var assignments:Map<Int, Int> = new Map();
		var usedFiles:Map<String, Bool> = new Map();

		for (line in strumLines)
		{
			var file = resolveVoiceFile(line, voiceFiles, usedFiles);

			if (file == "")
				continue;

			usedFiles.set(file, true);

			var channel = voicePaths.indexOf(file);

			if (channel < 0)
			{
				channel = voicePaths.length;
				voicePaths.push(file);
			}

			line.voiceChannel = channel;
			assignments.set(line.index, channel);
		}

		songAudio = new SongAudio();
		songAudio.loadSong('$audioPath/Inst.ogg', voicePaths, assignments);
		songAudio.play();
	}

	function discoverVoiceFiles(audioPath:String):Array<String>
	{
		var files:Array<String> = [];
		var prefix = '$audioPath/';

		for (path in Assets.list())
		{
			if (!StringTools.startsWith(path, prefix))
				continue;

			var file = path.substr(prefix.length).toLowerCase();

			if (!StringTools.endsWith(file, ".ogg") || !StringTools.startsWith(file, "voices"))
				continue;

			var fullPath = prefix + path.substr(prefix.length);

			if (files.indexOf(fullPath) < 0)
				files.push(fullPath);
		}

		files.sort(function(a, b) return a < b ? -1 : a > b ? 1 : 0);
		return files;
	}

	function resolveVoiceFile(line:StrumLine, files:Array<String>, usedFiles:Map<String, Bool>):String
	{
		if (files.length == 0)
			return "";

		var wantedSuffix = normalizeVoiceSuffix(line.vocalsSuffix);

		if (wantedSuffix != "")
		{
			for (file in files)
			{
				if (normalizeVoiceSuffix(voiceSuffixFromPath(file)) == wantedSuffix)
					return file;
			}
		}

		var character = line.primaryCharacter().toLowerCase();

		for (file in files)
		{
			if (normalizeVoiceSuffix(voiceSuffixFromPath(file)).indexOf(character) >= 0)
				return file;
		}

		for (file in files)
		{
			if (normalizeVoiceSuffix(voiceSuffixFromPath(file)).indexOf(songFolder.toLowerCase()) >= 0)
				return file;
		}

		if (line.isOpponent && chartData.gfVersion != null && chartData.gfVersion != "")
		{
			var gf = chartData.gfVersion.toLowerCase();

			for (file in files)
			{
				if (normalizeVoiceSuffix(voiceSuffixFromPath(file)).indexOf(gf) >= 0)
					return file;
			}
		}

		if (files.length == 1)
			return files[0];

		for (file in files)
		{
			if (!usedFiles.exists(file))
				return file;
		}

		return files[0];
	}

	static function voiceSuffixFromPath(path:String):String
	{
		var name = path;

		if (name.lastIndexOf("/") >= 0)
			name = name.substr(name.lastIndexOf("/") + 1);

		if (name.lastIndexOf(".") >= 0)
			name = name.substr(0, name.lastIndexOf("."));

		if (StringTools.startsWith(name.toLowerCase(), "voices"))
			name = name.substr(6);

		return name;
	}

	static function normalizeVoiceSuffix(suffix:String):String
	{
		if (suffix == null)
			return "";

		var normalized = StringTools.trim(suffix.toLowerCase());

		while (StringTools.startsWith(normalized, "-") || StringTools.startsWith(normalized, "_"))
			normalized = normalized.substr(1);

		return normalized;
	}

	function buildCharacters():Void
	{
		var insertIndex = 1;

		if (stage != null && stage.gfPosition != null && hasCharacterAssets(chartData.gfVersion))
		{
			girlfriendCharacter = new SparrowCharacter(chartData.gfVersion, false);
			girlfriendCharacter.placeAt(stage.gfPosition.x, stage.gfPosition.y);
			insert(insertIndex++, girlfriendCharacter);
		}

		var playerSeen = 0;
		var opponentSeen = 0;

		for (line in strumLines)
		{
			var characterName = line.primaryCharacter();
			var character = new SparrowCharacter(characterName, line.isPlayer);
			var y = FlxG.height * 0.13;

			if (line.isPlayer)
			{
				playerSeen++;
				y = stage != null && stage.bfPosition != null ? stage.bfPosition.y : y;
			}
			else if (line.isOpponent)
			{
				opponentSeen++;
				y = stage != null && stage.dadPosition != null ? stage.dadPosition.y : y;
			}

			character.placeAt(line.centerX, y);
			line.character = character;
			insert(insertIndex++, character);
		}
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
			var line = findRuntimeLine(chartNote.strumLineIndex);

			if (line == null)
				line = fallbackRuntimeLine(chartNote.isPlayer);

			if (line == null)
				continue;

			var lane = chartNote.lane;

			if (lane < 0 || lane >= line.keyCount)
				lane = cast(chartNote.direction, Int) % line.keyCount;

			var note = new Note(chartNote.time, chartNote.direction, chartNote.sustainLength, line.index, lane);
			var sprite = createNoteSprite(line, lane);
			sprite.alpha = chartNote.isPlayer ? 1.0 : 0.5;
			var tail = chartNote.sustainLength > 0 ? createSustainSprite(line, lane) : null;

			if (tail != null)
				add(tail);

			add(sprite);

			var entry:ChartEntry = {note: note, sprite: sprite, tail: tail, line: line, lane: lane};
			chart.push(entry);

			if (chartNote.isPlayer)
				notes.push(note);
			else
				opponentEntries.push(entry);
		}
	}

	function findRuntimeLine(index:Int):StrumLine
	{
		for (line in strumLines)
		{
			if (line.index == index)
				return line;
		}

		return null;
	}

	function fallbackRuntimeLine(isPlayer:Bool):StrumLine
	{
		for (line in strumLines)
		{
			if (line.isPlayer == isPlayer)
				return line;
		}

		return strumLines.length > 0 ? strumLines[0] : null;
	}

	function createNoteSprite(line:StrumLine, lane:Int):FlxSprite
	{
		var sprite = new FlxSprite();
		var direction:NoteDirection = cast(lane % 4, NoteDirection);

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

		sprite.x = line.laneCenter(lane) - sprite.width * 0.5;
		sprite.y = -100;
		bindToHud(sprite);
		return sprite;
	}

	function createSustainSprite(line:StrumLine, lane:Int):FlxSprite
	{
		var direction:NoteDirection = cast(lane % 4, NoteDirection);
		var tail = new FlxSprite();
		tail.makeGraphic(Std.int(SUSTAIN_WIDTH), Std.int(SUSTAIN_BASE_HEIGHT), noteColor(direction));
		tail.origin.set(0, 0);
		tail.alpha = line.isPlayer ? SUSTAIN_PLAYER_ALPHA : SUSTAIN_OPPONENT_ALPHA;
		tail.x = line.laneCenter(lane) - SUSTAIN_WIDTH * 0.5;
		tail.y = -100;
		tail.visible = false;
		bindToHud(tail);
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
		var titleY = 4;
		var titleSize = 22;
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

		var judgmentY = downscroll ? 100 : 190;
		judgmentText = new FlxText(0, judgmentY, FlxG.width, "", 44);
		judgmentText.alignment = FlxTextAlign.CENTER;
		judgmentText.color = FlxColor.WHITE;
		judgmentText.cameras = [hudCamera];
		add(judgmentText);

		var errorY = downscroll ? 216 : 310;

		#if debug
		var chartInfoY = downscroll ? 156 : 250;
		var windowsY = downscroll ? 180 : 274;

		if (chartData != null)
		{
			debugChartInfoText = new FlxText(0, chartInfoY, FlxG.width,
				'${chartData.bpm} BPM  |  ${chartData.notes.length} NOTES  |  ${chartData.getPlayerNotes().length} PLAYER', 14);
			debugChartInfoText.alignment = FlxTextAlign.CENTER;
			debugChartInfoText.color = 0xFF8888AA;
			debugChartInfoText.cameras = [hudCamera];
			debugChartInfoText.visible = debugStatsVisible;
			add(debugChartInfoText);
		}

		var windows = detector.windows;
		debugTimingInfoText = new FlxText(0, windowsY, FlxG.width,
			'Sick ${windows.sickWindow} / Good ${windows.goodWindow} / Bad ${windows.badWindow} / Shit ${windows.missWindow} ms', 14);
		debugTimingInfoText.alignment = FlxTextAlign.CENTER;
		debugTimingInfoText.color = 0xFF666688;
		debugTimingInfoText.cameras = [hudCamera];
		debugTimingInfoText.visible = debugStatsVisible;
		add(debugTimingInfoText);
		#end

		if (loadError != null)
		{
			var errorText = new FlxText(0, errorY, FlxG.width, loadError, 16);
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

	function configureScrollLayout():Void
	{
		strumLineY = downscroll ? Math.max(STRUM_UPSCROLL_Y, FlxG.height - STRUM_DOWNSCROLL_BOTTOM_MARGIN) : STRUM_UPSCROLL_Y;
	}

	#if debug
	function toggleDebugStats():Void
	{
		debugStatsVisible = !debugStatsVisible;

		if (debugChartInfoText != null)
			debugChartInfoText.visible = debugStatsVisible;

		if (debugTimingInfoText != null)
			debugTimingInfoText.visible = debugStatsVisible;
	}
	#end

	function bindToHud(sprite:FlxSprite):Void
	{
		sprite.cameras = [hudCamera];
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
			flashReceptor(entry.line, entry.lane);
			entry.line.sing(entry.note.direction);
		}
	}

	function flashReceptor(line:StrumLine, lane:Int):Void
	{
		if (lane < 0 || lane >= line.receptors.length)
			return;

		var receptor = line.receptors[lane];

		if (receptor == null)
			return;

		receptor.color = RECEPTOR_FLASH_COLOR;
		line.flashTimers[lane] = RECEPTOR_FLASH_TIME;
	}

	function updateReceptorFlashes(elapsed:Float):Void
	{
		for (line in strumLines)
		{
			for (lane in 0...line.flashTimers.length)
			{
				if (line.flashTimers[lane] <= 0)
					continue;

				line.flashTimers[lane] -= elapsed;

				if (line.flashTimers[lane] <= 0 && line.receptors[lane] != null)
					line.receptors[lane].color = line.baseReceptorColor;
			}
		}
	}

	function updateNotePositions():Void
	{
		if (rhythmUiHidden)
		{
			hideNoteSprites();
			return;
		}

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
			else if (!isNoteHeld(note))
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

	function isNoteHeld(note:Note):Bool
	{
		var line = findRuntimeLine(note.strumLineIndex);
		return line != null && line.isPressed(note.lane);
	}

	function cutSustain(note:Note):Void
	{
		note.sustainActive = false;
		note.sustainDropped = true;
		health = Math.max(0, health - SUSTAIN_DROP_DAMAGE);

		if (healthBar != null)
			healthBar.setHealth(health);

		if (songAudio != null)
			songAudio.setStrumLineMuted(note.strumLineIndex, true);

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

	function applyJudgment(judgment:Judgment, strumLineIndex:Int = -1):Void
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

		if (songAudio != null && strumLineIndex >= 0)
		{
			if (judgment == Judgment.MISS || judgment == Judgment.SHIT)
				songAudio.setStrumLineMuted(strumLineIndex, true);
			else if (judgment == Judgment.SICK || judgment == Judgment.GOOD)
				songAudio.setStrumLineMuted(strumLineIndex, false);
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

}
