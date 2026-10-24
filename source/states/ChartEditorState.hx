package states;

import chart.ChartEvent;
import chart.ChartNote;
import chart.ChartTimeMode;
import chart.FNFChart;
import chart.FNFChartParser;
import chart.StrumLineData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import graphics.SparrowLoader;
import haxe.Int64;
import haxe.io.Bytes;
import input.NoteDirection;
import mods.ModInfo;
import mods.ModManager;
import ui.MissingFilePrompt;
import openfl.utils.Assets;
#if sys
import openfl.media.Sound;
import sys.FileSystem;
import sys.io.File;
#end
#if (sys && lime_vorbis)
import lime.media.vorbis.VorbisFile;
#end

private typedef EditorSong =
{
	var folder:String;
	var displayName:String;
	var bpm:Float;
	var difficulties:Array<String>;
	var physicalRoot:String;
	var priority:Int;
}

private typedef MetaInfo =
{
	var displayName:String;
	var bpm:Float;
	var difficulties:Array<String>;
}

private typedef SectionRange =
{
	var start:Float;
	var end:Float;
	var bpm:Float;
	var mustHit:Bool;
}

private typedef EditorInputField =
{
	var key:String;
	var label:String;
	var x:Float;
	var y:Float;
	var w:Float;
	var h:Float;
	var background:FlxSprite;
	var labelText:FlxText;
	var valueText:FlxText;
}

private typedef EditorAudioRow =
{
	var key:String;
	var x:Float;
	var y:Float;
	var w:Float;
	var h:Float;
	var text:FlxText;
}

class ChartEditorState extends FlxState
{
	static inline var SONG_ROOT:String = "assets/songs/";
	static inline var NOTE_IMAGE_PATH:String = "assets/images/notes/notes.png";
	static inline var NOTE_XML_PATH:String = "assets/images/notes/notes.xml";

	static inline var GRID_X:Float = 336;
	static inline var GRID_Y:Float = 174;
	static inline var GRID_W:Float = 608;
	static inline var GRID_H:Float = 444;
	static inline var GRID_BOTTOM:Float = GRID_Y + GRID_H;
	static inline var PLAYER_X:Float = 656;
	static inline var LANE_WIDTH:Float = 72;
	static inline var CENTER_GAP:Float = 32;
	static inline var PLAYHEAD_Y:Float = 246;
	static inline var RECEPTOR_SIZE:Float = 52;
	static inline var NOTE_SIZE:Float = 44;
	static inline var NOTE_HEIGHT:Float = 24;
	static inline var TAIL_WIDTH:Float = 16;
	static inline var ROW_HEIGHT:Float = 26;
	static inline var SCROLL_WINDOW_MS:Float = 2000;
	static inline var PIXELS_PER_MS:Float = (GRID_BOTTOM - PLAYHEAD_Y) / SCROLL_WINDOW_MS;
	static inline var TIMELINE_Y:Float = 634;
	static inline var TIMELINE_H:Float = 14;
	static inline var LEFT_PANEL_X:Float = 12;
	static inline var RIGHT_PANEL_X:Float = 968;
	static inline var PANEL_Y:Float = 54;
	static inline var PANEL_W:Float = 300;
	static inline var PANEL_H:Float = 570;
	static inline var MAX_NOTE_SPRITES:Int = 256;
	static inline var MAX_EVENT_SPRITES:Int = 64;
	static inline var EVENT_ROWS:Int = 12;
	static inline var EVENT_ROW_HEIGHT:Float = 24;
	static inline var EVENT_LIST_Y:Float = 176;
	static inline var WAVEFORM_BINS:Int = 512;
	static inline var TIMELINE_BARS:Int = 128;
	static inline var GRID_WAVE_BARS:Int = 96;
	static inline var TIMELINE_BAR_WIDTH:Float = 5;

	static var SNAP_LABELS:Array<String> = ["1/4", "1/8", "1/16", "1/32", "1/64"];
	static var SNAP_DIVISIONS:Array<Float> = [1, 2, 4, 8, 16];
	static var DIRECTION_NAMES:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];
	static var TOOL_NAMES:Array<String> = ["PLACE", "ERASE", "SUSTAIN"];
	static var EVENT_TYPES:Array<String> = ["Camera Movement", "Camera Zoom", "Trigger Minigame", "Camera Flash"];
	static var EVENT_PARAMS:Array<Array<Dynamic>> = [
		[[0], [1]],
		[[1.0, 1.0], [0.8, 2.0]],
		[["pong", 15, "normal"]],
		[["#FFFFFF", 0.2, "camera"], ["#000000", 0.5, "camera"]]
	];

	var songs:Array<EditorSong> = [];
	var selectedSong:Int = 0;
	var selectedDifficulty:Int = 0;
	var snapIndex:Int = 2;
	var tool:Int = 0;
	var activePlayer:Bool = true;
	var selectedDirection:Int = 0;
	var chartTime:Float = 0;
	var playing:Bool = false;
	var songLength:Float = 0;
	var chartData:FNFChart;
	var rawRoot:Dynamic;
	var rawSongData:Dynamic;
	var chartExists:Bool = false;
	var loadFailed:Bool = false;
	var dirty:Bool = false;
	var exitArmed:Bool = false;
	var chartAssetPath:String;
	var chartPhysicalPath:String;
	var audio:FlxSound;
	var voiceSounds:Array<FlxSound> = [];
	var voiceFileNames:Array<String> = [];
	var instMuted:Bool = false;
	var voicesMuted:Bool = false;
	var voiceAssignments:Map<Int, Int> = new Map();
	var voicePanelOpen:Bool = false;
	var voicePanelStage:Int = 0;
	var voicePanelLine:Int = -1;
	var voicePanelBackground:FlxSprite;
	var voicePanelTitle:FlxText;
	var voicePanelRows:Array<EditorAudioRow> = [];
	var snapButtons:Array<EditorAudioRow> = [];
	var snapButtonBackgrounds:Array<FlxSprite> = [];
	var audioWaveformPeaks:Array<Float> = null;
	var waveformSource:String = "DENSITY";
	var inputFields:Array<EditorInputField> = [];
	var audioRows:Array<EditorAudioRow> = [];
	var activeInput:String = null;
	var inputBuffer:String = "";
	var inputCaretTimer:Float = 0;
	var inputCaretOn:Bool = true;
	var noteFrames:FlxAtlasFrames;

	var noteLayer:FlxSpriteGroup;
	var tailLayer:FlxSpriteGroup;
	var eventLayer:FlxSpriteGroup;
	var receptorLayer:FlxSpriteGroup;
	var gridWaveLayer:FlxSpriteGroup;
	var timelineWaveLayer:FlxSpriteGroup;
	var cursorSprite:FlxSprite;
	var timelineFill:FlxSprite;
	var timelineMarker:FlxSprite;
	var noteSprites:Array<FlxSprite> = [];
	var tailSprites:Array<FlxSprite> = [];
	var eventSprites:Array<FlxSprite> = [];
	var timelineBars:Array<FlxSprite> = [];
	var gridWaveBars:Array<FlxSprite> = [];
	var densityBins:Array<Float> = [];

	var titleText:FlxText;
	var subtitleText:FlxText;
	var timeText:FlxText;
	var snapText:FlxText;
	var toolText:FlxText;
	var sideText:FlxText;
	var chartStatusText:FlxText;
	var hoverText:FlxText;
	var helpText:FlxText;
	var eventTypeText:FlxText;
	var eventParamText:FlxText;
	var eventHelpText:FlxText;
	var eventTexts:Array<FlxText> = [];
	var statusText:FlxText;
	var hintText:FlxText;
	var hintText2:FlxText;
	var missingPrompt:MissingFilePrompt;

	var selectedEventIndex:Int = -1;
	var eventListOffset:Int = 0;
	var eventTypeIndex:Int = 0;
	var eventParamIndex:Int = 0;
	var hoverLane:Int = -1;
	var hoverPlayer:Bool = false;
	var hoverTime:Float = 0;
	var hoverValid:Bool = false;

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF0D1018;
		ModManager.reload();
		noteFrames = SparrowLoader.load(NOTE_IMAGE_PATH, NOTE_XML_PATH);
		songs = discoverSongs();
		buildUi();

		if (songs.length > 0)
		{
			selectedSong = 0;
			selectedDifficulty = preferredDifficulty(songs[0]);
		}

		loadCurrentChart();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		handleKeyboard();
		updateMouse();
		updateInputCaret(elapsed);
		updatePlayback(elapsed);
		updateChartView();
		refreshRuntimeText();
	}

	override public function destroy():Void
	{
		destroyAudio();
		super.destroy();
	}

	function handleKeyboard():Void
	{
		if (missingPrompt != null && missingPrompt.updatePrompt())
			return;

		if (activeInput != null)
		{
			handleInputKeyboard();
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (voicePanelOpen)
			{
				closeVoicePanel();
				return;
			}

			if (dirty && !exitArmed)
			{
				exitArmed = true;
				setStatus("UNSAVED CHANGES - PRESS ESC AGAIN TO DISCARD", 0xFFFFAA33);
			}
			else
			{
				FlxG.switchState(new EditorsMenuState());
			}

			return;
		}

		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
		{
			saveChart();
			return;
		}

		if (FlxG.keys.justPressed.F5)
		{
			changeSong(-1);
			return;
		}

		if (FlxG.keys.justPressed.F6)
		{
			changeSong(1);
			return;
		}

		if (FlxG.keys.justPressed.F7)
		{
			changeDifficulty(-1);
			return;
		}

		if (FlxG.keys.justPressed.F8)
		{
			changeDifficulty(1);
			return;
		}

		if (FlxG.keys.justPressed.TAB)
		{
			cycleSnap(FlxG.keys.pressed.SHIFT ? -1 : 1);
			return;
		}

		if (FlxG.keys.justPressed.SPACE)
		{
			togglePlayback();
			return;
		}

		if (FlxG.keys.justPressed.LEFT)
		{
			seekBy(-snapMs());
			return;
		}

		if (FlxG.keys.justPressed.RIGHT)
		{
			seekBy(snapMs());
			return;
		}

		if (FlxG.keys.justPressed.UP)
		{
			seekBy(-beatMs());
			return;
		}

		if (FlxG.keys.justPressed.DOWN)
		{
			seekBy(beatMs());
			return;
		}

		if (FlxG.keys.justPressed.E)
		{
			cycleTool(1);
			return;
		}

		if (FlxG.keys.justPressed.Q)
		{
			activePlayer = !activePlayer;
			refreshInfo();
			refreshHoverText();
			return;
		}

		if (FlxG.keys.justPressed.ONE)
		{
			placeKeyboardNote(0);
			return;
		}

		if (FlxG.keys.justPressed.TWO)
		{
			placeKeyboardNote(1);
			return;
		}

		if (FlxG.keys.justPressed.THREE)
		{
			placeKeyboardNote(2);
			return;
		}

		if (FlxG.keys.justPressed.FOUR)
		{
			placeKeyboardNote(3);
			return;
		}

		if (FlxG.keys.justPressed.INSERT)
		{
			addEvent();
			return;
		}

		if (FlxG.keys.justPressed.PAGEUP)
		{
			selectEvent(-1);
			return;
		}

		if (FlxG.keys.justPressed.PAGEDOWN)
		{
			selectEvent(1);
			return;
		}

		if (FlxG.keys.justPressed.T)
		{
			cycleEventType();
			return;
		}

		if (FlxG.keys.justPressed.Y)
		{
			cycleEventParams();
			return;
		}

		if (FlxG.keys.justPressed.COMMA)
		{
			moveSelectedEvent(-snapMs());
			return;
		}

		if (FlxG.keys.justPressed.PERIOD)
		{
			moveSelectedEvent(snapMs());
			return;
		}

		if (FlxG.keys.justPressed.DELETE)
		{
			deleteAtCursor();
		}
	}

	function updateMouse():Void
	{
		if (missingPrompt != null && missingPrompt.isOpen)
			return;

		hoverValid = false;

		var mouseX = FlxG.mouse.x;
		var mouseY = FlxG.mouse.y;

		if (activeInput == null && FlxG.mouse.wheel != 0 && mouseX >= GRID_X && mouseX <= GRID_X + GRID_W
			&& mouseY >= GRID_Y && mouseY <= TIMELINE_Y + TIMELINE_H + 6)
			seekBy(-FlxG.mouse.wheel * beatMs());

		if (mouseX >= GRID_X && mouseX <= GRID_X + GRID_W && mouseY >= GRID_Y && mouseY <= GRID_BOTTOM)
			updateHover(mouseX, mouseY);

		updateCursor();

		if (FlxG.mouse.justPressed)
			handleLeftClick(mouseX, mouseY);
		else if (FlxG.mouse.justPressedRight)
			handleRightClick(mouseX, mouseY);

		refreshHoverText();
	}

	function updateHover(mouseX:Float, mouseY:Float):Void
	{
		hoverPlayer = mouseX >= PLAYER_X;
		var start = hoverPlayer ? PLAYER_X : GRID_X;
		var lane = Std.int((mouseX - start) / LANE_WIDTH);

		if (lane < 0)
			lane = 0;
		if (lane > 3)
			lane = 3;

		hoverLane = lane;
		hoverTime = snapTime(yToTime(mouseY));
		hoverValid = true;
	}

	function updateCursor():Void
	{
		if (cursorSprite == null)
			return;

		if (!hoverValid)
		{
			cursorSprite.visible = false;
			return;
		}

		cursorSprite.x = laneCenter(hoverLane, hoverPlayer) - NOTE_SIZE * 0.5;
		cursorSprite.y = timeToY(hoverTime) - NOTE_SIZE * 0.5;
		cursorSprite.color = tool == 1 ? 0x55FF4455 : (tool == 2 ? 0x55FFCC55 : 0x5588AAFF);
		cursorSprite.visible = true;
	}

	function handleLeftClick(mouseX:Float, mouseY:Float):Void
	{
		if (voicePanelOpen)
		{
			if (handleVoicePanelClick(mouseX, mouseY))
				return;
		}

		if (handleInputClick(mouseX, mouseY))
			return;

		if (handleAudioClick(mouseX, mouseY))
			return;

		if (mouseY >= TIMELINE_Y - 4 && mouseY <= TIMELINE_Y + TIMELINE_H + 4 && mouseX >= GRID_X && mouseX <= GRID_X + GRID_W)
		{
			var progress = clamp((mouseX - GRID_X) / GRID_W, 0, 1);
			seekTo(progress * songLength);
			return;
		}

		if (mouseX >= RIGHT_PANEL_X && mouseX <= RIGHT_PANEL_X + PANEL_W && mouseY >= EVENT_LIST_Y
			&& mouseY < EVENT_LIST_Y + EVENT_ROWS * EVENT_ROW_HEIGHT)
		{
			var row = Std.int((mouseY - EVENT_LIST_Y) / EVENT_ROW_HEIGHT);
			var index = eventListOffset + row;

			if (chartData != null && index >= 0 && index < chartData.events.length)
				selectEventIndex(index);

			return;
		}

		if (!hoverValid)
			return;

		switch (tool)
		{
			case 0:
				addNote(hoverTime, hoverLane, hoverPlayer, 0);
			case 1:
				eraseNoteAt(hoverTime, hoverLane, hoverPlayer);
			case 2:
				sustainNoteAt(hoverTime, hoverLane, hoverPlayer);
		}
	}

	function handleRightClick(mouseX:Float, mouseY:Float):Void
	{
		if (hoverValid)
			eraseNoteAt(hoverTime, hoverLane, hoverPlayer);
	}

	function updateInputCaret(elapsed:Float):Void
	{
		if (activeInput == null)
			return;

		inputCaretTimer += elapsed;

		if (inputCaretTimer >= 0.45)
		{
			inputCaretTimer = 0;
			inputCaretOn = !inputCaretOn;
			refreshInputFields();
		}
	}

	function handleInputKeyboard():Void
	{
		if (FlxG.keys.justPressed.ESCAPE)
		{
			cancelInput();
			return;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			commitInput();
			return;
		}

		if (FlxG.keys.justPressed.TAB)
		{
			var delta = FlxG.keys.pressed.SHIFT ? -1 : 1;

			if (commitInput())
				nextInputField(delta);

			return;
		}

		if (FlxG.keys.justPressed.BACKSPACE)
		{
			if (inputBuffer.length > 0)
				inputBuffer = inputBuffer.substr(0, inputBuffer.length - 1);

			refreshInputFields();
			return;
		}

		if (FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.ALT)
			return;

		var keyCode = FlxG.keys.firstJustPressed();

		if (keyCode < 0)
			return;

		var character = keyChar(keyCode);

		if (character == null)
			return;

		if (inputBuffer.length < 64)
			inputBuffer += character;

		refreshInputFields();
	}

	function beginInput(key:String):Void
	{
		activeInput = key;
		inputBuffer = fieldValue(key);
		inputCaretOn = true;
		inputCaretTimer = 0;
		refreshInputFields();
		setStatus('EDITING ${key.toUpperCase()} - ENTER APPLY / ESC CANCEL', 0xFF66CCFF);
	}

	function cancelInput():Void
	{
		if (activeInput == null)
			return;

		activeInput = null;
		inputBuffer = "";
		refreshInputFields();
		setStatus("EDIT CANCELLED", 0xFF8888AA);
	}

	function commitInput():Bool
	{
		if (activeInput == null)
			return true;

		var key = activeInput;
		var value = inputBuffer;
		var ok = true;

		activeInput = null;
		inputBuffer = "";

		switch (key)
		{
			case "song":
				ok = applySongInput(value);
			case "difficulty":
				ok = applyDifficultyInput(value);
			case "bpm":
				ok = applyBpmInput(value);
			case "speed":
				ok = applySpeedInput(value);
			case "offset":
				ok = applyOffsetInput(value);
		}

		if (!ok)
		{
			activeInput = key;
			inputBuffer = value;
			refreshInputFields();
			return false;
		}

		refreshInputFields();
		refreshInfo();
		return true;
	}

	function nextInputField(delta:Int):Void
	{
		var index = inputFieldIndex(activeInput);

		if (index < 0)
			return;

		beginInput(inputFields[wrapIndex(index + delta, inputFields.length)].key);
	}

	function inputFieldIndex(key:String):Int
	{
		for (i in 0...inputFields.length)
		{
			if (inputFields[i].key == key)
				return i;
		}

		return -1;
	}

	static function keyChar(keyCode:Int):String
	{
		var shift = FlxG.keys.pressed.SHIFT;

		if (keyCode >= 65 && keyCode <= 90)
		{
			var letter = String.fromCharCode(keyCode);
			return shift ? letter : letter.toLowerCase();
		}

		if (keyCode >= 48 && keyCode <= 57)
			return String.fromCharCode(keyCode);

		return switch (keyCode)
		{
			case 32: " ";
			case 188: ",";
			case 189: shift ? "_" : "-";
			case 190: ".";
			case 191: "/";
			case 186: shift ? ":" : ";";
			case 192: shift ? "~" : "`";
			case 219: shift ? "{" : "[";
			case 220: shift ? "|" : "\\";
			case 221: shift ? "}" : "]";
			case 222: shift ? "\"" : "'";
			default: null;
		}
	}

	function handleInputClick(mouseX:Float, mouseY:Float):Bool
	{
		for (field in inputFields)
		{
			if (mouseX < field.x || mouseX > field.x + field.w || mouseY < field.y || mouseY > field.y + field.h)
				continue;

			if (activeInput != field.key)
			{
				if (activeInput != null && !commitInput())
					return true;

				beginInput(field.key);
			}

			return true;
		}

		if (activeInput != null)
			return !commitInput();

		return false;
	}

	function fieldValue(key:String):String
	{
		var song = currentSong();

		return switch (key)
		{
			case "song": song == null ? "" : song.displayName;
			case "difficulty": currentDifficulty();
			case "bpm": formatNumber(bpm());
			case "speed": formatNumber(chartData == null ? 1 : chartData.speed);
			case "offset": formatNumber(chartData == null ? 0 : chartData.offset);
			default: "";
		}
	}

	function refreshInputFields():Void
	{
		for (field in inputFields)
		{
			var focused = activeInput == field.key;
			var value = focused ? inputBuffer : fieldValue(field.key);

			if (focused)
				value += inputCaretOn ? "_" : " ";

			field.valueText.text = value;
			field.valueText.color = focused ? FlxColor.WHITE : 0xFFB8B8CC;
			field.background.color = focused ? 0xFF1B2A44 : 0xFF0A0E16;
			field.labelText.color = focused ? 0xFF88AAFF : 0xFF666688;
		}
	}

	function applySongInput(raw:String):Bool
	{
		var query = StringTools.trim(raw);

		if (query == "")
		{
			setStatus("SONG NAME IS EMPTY", 0xFFFF4455);
			return false;
		}

		if (dirty)
		{
			setStatus("UNSAVED CHANGES - CTRL+S TO SAVE", 0xFFFFAA33);
			return false;
		}

		var index = findSongIndex(query);

		if (index < 0)
		{
			setStatus('SONG NOT FOUND: $query', 0xFFFF4455);
			return false;
		}

		selectedSong = index;
		selectedDifficulty = preferredDifficulty(currentSong());
		loadCurrentChart();
		setStatus('SONG: ${currentSong().displayName}', 0xFF66FF88);
		return true;
	}

	function applyDifficultyInput(raw:String):Bool
	{
		var difficulty = StringTools.trim(raw).toLowerCase();

		if (difficulty == "")
		{
			setStatus("DIFFICULTY NAME IS EMPTY", 0xFFFF4455);
			return false;
		}

		if (dirty)
		{
			setStatus("UNSAVED CHANGES - CTRL+S TO SAVE", 0xFFFFAA33);
			return false;
		}

		var song = currentSong();

		if (song == null)
		{
			setStatus("NO SONG SELECTED", 0xFFFF4455);
			return false;
		}

		var index = -1;

		for (i in 0...song.difficulties.length)
		{
			if (song.difficulties[i].toLowerCase() == difficulty)
			{
				index = i;
				break;
			}
		}

		if (index < 0)
		{
			song.difficulties.push(difficulty);
			index = song.difficulties.length - 1;
		}

		selectedDifficulty = index;
		loadCurrentChart();
		setStatus('DIFFICULTY: ${currentDifficulty().toUpperCase()}', 0xFF66FF88);
		return true;
	}

	function applyBpmInput(raw:String):Bool
	{
		var value = Std.parseFloat(StringTools.trim(raw));

		if (Math.isNaN(value) || value <= 0 || value > 1000)
		{
			setStatus("BPM MUST BE A NUMBER BETWEEN 0 AND 1000", 0xFFFF4455);
			return false;
		}

		if (chartData == null)
			return false;

		chartData.bpm = value;
		songLength = computeSongLength();
		refreshAll();
		markDirty('BPM ${formatNumber(value)}');
		return true;
	}

	function applySpeedInput(raw:String):Bool
	{
		var value = Std.parseFloat(StringTools.trim(raw));

		if (Math.isNaN(value) || value < 0.05 || value > 20)
		{
			setStatus("SPEED MUST BE A NUMBER BETWEEN 0.05 AND 20", 0xFFFF4455);
			return false;
		}

		if (chartData == null)
			return false;

		chartData.speed = value;
		refreshAll();
		markDirty('SPEED ${formatNumber(value)}');
		return true;
	}

	function applyOffsetInput(raw:String):Bool
	{
		var value = Std.parseFloat(StringTools.trim(raw));

		if (Math.isNaN(value) || value < -60000 || value > 60000)
		{
			setStatus("OFFSET MUST BE BETWEEN -60000 AND 60000 MS", 0xFFFF4455);
			return false;
		}

		if (chartData == null)
			return false;

		chartData.offset = value;
		songLength = computeSongLength();

		if (playing)
			startPlaybackAudio();
		else
			applyAudioPosition();

		refreshAll();
		markDirty('OFFSET ${formatNumber(value)} MS');
		return true;
	}

	function findSongIndex(query:String):Int
	{
		var needle = query.toLowerCase();

		for (i in 0...songs.length)
		{
			var song = songs[i];

			if (song.folder.toLowerCase() == needle || song.displayName.toLowerCase() == needle)
				return i;
		}

		for (i in 0...songs.length)
		{
			var song = songs[i];

			if (song.folder.toLowerCase().indexOf(needle) >= 0 || song.displayName.toLowerCase().indexOf(needle) >= 0)
				return i;
		}

		return -1;
	}

	function buildInputFields():Void
	{
		var defs:Array<{key:String, label:String, y:Float}> = [
			{key: "song", label: "SONG (FOLDER OR NAME)", y: 84},
			{key: "difficulty", label: "DIFFICULTY", y: 122},
			{key: "bpm", label: "BPM", y: 160},
			{key: "speed", label: "SCROLL SPEED", y: 198},
			{key: "offset", label: "OFFSET (MS)", y: 236}
		];

		for (def in defs)
		{
			var x = LEFT_PANEL_X + 8;
			var w = PANEL_W - 16;
			var label = new FlxText(x, def.y, w, def.label, 9);
			label.color = 0xFF666688;
			add(label);

			var background = new FlxSprite(x, def.y + 12);
			background.makeGraphic(Std.int(w), 20, FlxColor.WHITE);
			background.color = 0xFF0A0E16;
			add(background);

			var value = new FlxText(x + 4, def.y + 14, w - 8, "", 12);
			value.color = 0xFFB8B8CC;
			add(value);

			inputFields.push({
				key: def.key,
				label: def.label,
				x: x,
				y: def.y + 12,
				w: w,
				h: 20,
				background: background,
				labelText: label,
				valueText: value
			});
		}

		refreshInputFields();
	}

	function buildAudioRows():Void
	{
		var defs:Array<{key:String, y:Float}> = [
			{key: "inst", y: 294},
			{key: "voices", y: 314},
			{key: "assign", y: 334}
		];

		for (def in defs)
		{
			var x = LEFT_PANEL_X + 8;
			var w = PANEL_W - 16;
			var text = new FlxText(x, def.y, w, "", 10);
			text.color = 0xFF8888AA;
			add(text);
			audioRows.push({key: def.key, x: x, y: def.y - 1, w: w, h: 18, text: text});
		}

		refreshAudioTexts();
	}

	function buildSnapButtons():Void
	{
		var x = LEFT_PANEL_X + 8;
		var totalWidth = PANEL_W - 16;
		var buttonWidth = totalWidth / SNAP_LABELS.length;
		var y = 416;

		for (i in 0...SNAP_LABELS.length)
		{
			var bx = x + i * buttonWidth;
			var background = new FlxSprite(bx, y);
			background.makeGraphic(Std.int(buttonWidth - 2), 18, FlxColor.WHITE);
			background.color = 0xFF0A0E16;
			add(background);
			snapButtonBackgrounds.push(background);

			var text = new FlxText(bx, y + 1, buttonWidth - 2, SNAP_LABELS[i], 10);
			text.alignment = FlxTextAlign.CENTER;
			text.color = 0xFF7777AA;
			add(text);
			snapButtons.push({key: 'snap:$i', x: bx, y: y, w: buttonWidth - 2, h: 18, text: text});
		}

		refreshSnapButtons();
	}

	function refreshSnapButtons():Void
	{
		for (i in 0...snapButtons.length)
		{
			var selected = i == snapIndex;
			snapButtons[i].text.color = selected ? FlxColor.WHITE : 0xFF666688;
			snapButtonBackgrounds[i].color = selected ? 0xFF26304A : 0xFF0A0E16;
		}
	}

	function refreshAudioTexts():Void
	{
		for (row in audioRows)
		{
			switch (row.key)
			{
				case "inst":
					row.text.text = 'INST: ${instMuted ? "MUTED" : "ON"}';
					row.text.color = instMuted ? 0xFFFFAA33 : 0xFF66FF88;
				case "voices":
					row.text.text = 'VOICES: ${voicesMuted ? "MUTED" : "ON"}';
					row.text.color = voicesMuted ? 0xFFFFAA33 : 0xFF66FF88;
				case "assign":
					var lineCount = chartData == null ? 0 : chartData.strumLines.length;
					row.text.text = 'ASSIGN VOICES (${lineCount} LINES)...';
					row.text.color = lineCount == 0 ? 0xFF666688 : 0xFF88AAFF;
			}
		}

		refreshSnapButtons();
	}

	function handleAudioClick(mouseX:Float, mouseY:Float):Bool
	{
		for (i in 0...snapButtons.length)
		{
			var button = snapButtons[i];

			if (mouseX < button.x || mouseX > button.x + button.w || mouseY < button.y || mouseY > button.y + button.h)
				continue;

			snapIndex = i;
			refreshInfo();
			refreshHoverText();
			setStatus('SNAP SET TO ${SNAP_LABELS[i]}', 0xFF66CCFF);
			return true;
		}

		for (row in audioRows)
		{
			if (mouseX < row.x || mouseX > row.x + row.w || mouseY < row.y || mouseY > row.y + row.h)
				continue;

			switch (row.key)
			{
				case "inst":
					instMuted = !instMuted;
					updateAudioVolumes();
					refreshAudioTexts();
					setStatus(instMuted ? "INSTRUMENTAL MUTED" : "INSTRUMENTAL ON", 0xFF66CCFF);
				case "voices":
					voicesMuted = !voicesMuted;
					updateAudioVolumes();
					refreshAudioTexts();
					setStatus(voicesMuted ? "VOICES MUTED" : "VOICES ON", 0xFF66CCFF);
				case "assign":
					openVoicePanel();
			}

			return true;
		}

		return false;
	}

	function openVoicePanel():Void
	{
		if (chartData == null || chartData.strumLines.length == 0)
		{
			setStatus("NO STRUMLINES TO ASSIGN", 0xFFFFAA33);
			return;
		}

		if (voiceFileNames.length == 0)
		{
			setStatus("NO VOICE CHANNELS FOUND", 0xFFFFAA33);
			return;
		}

		voicePanelOpen = true;
		voicePanelStage = 0;
		voicePanelLine = -1;
		refreshVoicePanel();
	}

	function closeVoicePanel():Void
	{
		voicePanelOpen = false;
		voicePanelStage = 0;
		voicePanelLine = -1;
		clearVoicePanelObjects();
	}

	function clearVoicePanelObjects():Void
	{
		for (row in voicePanelRows)
			remove(row.text, true);

		voicePanelRows = [];

		if (voicePanelTitle != null)
		{
			remove(voicePanelTitle, true);
			voicePanelTitle = null;
		}

		if (voicePanelBackground != null)
		{
			remove(voicePanelBackground, true);
			voicePanelBackground = null;
		}
	}

	function refreshVoicePanel():Void
	{
		clearVoicePanelObjects();

		if (!voicePanelOpen || chartData == null)
			return;

		var x = LEFT_PANEL_X + 4;
		var y = 286;
		var w = PANEL_W - 8;
		var h = 246;

		voicePanelBackground = new FlxSprite(x, y);
		voicePanelBackground.makeGraphic(Std.int(w), Std.int(h), FlxColor.WHITE);
		voicePanelBackground.color = 0xFF080B12;
		voicePanelBackground.alpha = 0.97;
		add(voicePanelBackground);

		var titleTextValue = voicePanelStage == 0 ? "ASSIGN VOICES - SELECT STRUMLINE" : 'LINE $voicePanelLine - SELECT VOICE';
		voicePanelTitle = new FlxText(x + 8, y + 8, w - 16, titleTextValue, 11);
		voicePanelTitle.color = 0xFF88AAFF;
		add(voicePanelTitle);

		var rowX = x + 8;
		var rowW = w - 16;
		var rowY:Float = y + 30;
		var rowH = 20.0;

		if (voicePanelStage == 0)
		{
			for (line in chartData.strumLines)
			{
				var text = '${line.index}  ${line.label()}  ${line.primaryCharacter()}  ->  ${voiceFileNameForLine(line.index)}';
				addVoicePanelRow('line:${line.index}', rowX, rowY, rowW, rowH, text);
				rowY += rowH;
			}
		}
		else
		{
			addVoicePanelRow("auto", rowX, rowY, rowW, rowH, "AUTO (MATCH SUFFIX / CHARACTER)");
			rowY += rowH;

			for (i in 0...voiceFileNames.length)
			{
				addVoicePanelRow('file:$i', rowX, rowY, rowW, rowH, voiceFileNames[i]);
				rowY += rowH;
			}
		}
	}

	function addVoicePanelRow(key:String, x:Float, y:Float, w:Float, h:Float, label:String):Void
	{
		var text = new FlxText(x, y, w, label, 10);
		text.color = 0xFFB8B8CC;
		text.wordWrap = false;
		add(text);
		voicePanelRows.push({key: key, x: x, y: y - 1, w: w, h: h, text: text});
	}

	function handleVoicePanelClick(mouseX:Float, mouseY:Float):Bool
	{
		if (!voicePanelOpen)
			return false;

		var x = LEFT_PANEL_X + 4;
		var y = 286;
		var w = PANEL_W - 8;
		var h = 246;

		if (mouseX < x || mouseX > x + w || mouseY < y || mouseY > y + h)
		{
			closeVoicePanel();
			return false;
		}

		for (row in voicePanelRows)
		{
			if (mouseX < row.x || mouseX > row.x + row.w || mouseY < row.y || mouseY > row.y + row.h)
				continue;

			if (row.key == "auto")
			{
				assignVoiceForLine(voicePanelLine, -1);
			}
			else if (row.key.indexOf("line:") == 0)
			{
				voicePanelLine = Std.parseInt(row.key.substr(5));
				voicePanelStage = 1;
				refreshVoicePanel();
			}
			else if (row.key.indexOf("file:") == 0)
			{
				assignVoiceForLine(voicePanelLine, Std.parseInt(row.key.substr(5)));
			}

			return true;
		}

		return true;
	}

	function assignVoiceForLine(lineIndex:Int, voiceIndex:Int):Void
	{
		if (chartData == null)
			return;

		var data = findStrumLineData(lineIndex);

		if (data == null)
			return;

		if (voiceIndex < 0 || voiceIndex >= voiceFileNames.length)
		{
			voiceAssignments.remove(lineIndex);
			data.vocalsSuffix = "";
		}
		else
		{
			voiceAssignments.set(lineIndex, voiceIndex);
			data.vocalsSuffix = voiceSuffix(voiceFileNames[voiceIndex]);
		}

		if (data.isPlayer)
			chartData.playerVocalsSuffix = data.vocalsSuffix;
		else if (data.isOpponent)
			chartData.opponentVocalsSuffix = data.vocalsSuffix;

		updateAudioVolumes();
		refreshAudioTexts();
		refreshVoicePanel();
		markDirty('VOICE LINE $lineIndex: ${voiceIndex < 0 ? "AUTO" : voiceFileNames[voiceIndex]}');
	}

	function findStrumLineData(index:Int):StrumLineData
	{
		if (chartData == null)
			return null;

		for (data in chartData.strumLines)
		{
			if (data.index == index)
				return data;
		}

		return null;
	}

	function resolvedVoiceIndexForLine(lineIndex:Int):Int
	{
		if (voiceFileNames.length == 0)
			return -1;

		if (voiceAssignments.exists(lineIndex))
		{
			var explicit = voiceAssignments.get(lineIndex);

			if (explicit >= 0 && explicit < voiceFileNames.length)
				return explicit;
		}

		var data = findStrumLineData(lineIndex);

		if (data == null)
			return 0;

		var suffix = normalizeVoiceSuffix(data.vocalsSuffix);

		if (suffix != "")
		{
			for (i in 0...voiceFileNames.length)
			{
				if (normalizeVoiceSuffix(voiceSuffix(voiceFileNames[i])) == suffix)
					return i;
			}
		}

		var character = data.primaryCharacter().toLowerCase();

		for (i in 0...voiceFileNames.length)
		{
			if (normalizeVoiceSuffix(voiceSuffix(voiceFileNames[i])).indexOf(character) >= 0)
				return i;
		}

		var song = currentSong();

		if (song != null)
		{
			var folder = song.folder.toLowerCase();

			for (i in 0...voiceFileNames.length)
			{
				if (normalizeVoiceSuffix(voiceSuffix(voiceFileNames[i])).indexOf(folder) >= 0)
					return i;
			}
		}

		return 0;
	}

	function voiceFileNameForLine(lineIndex:Int):String
	{
		var index = resolvedVoiceIndexForLine(lineIndex);

		if (index < 0 || index >= voiceFileNames.length)
			return "NONE";

		return voiceFileNames[index];
	}

	static function voiceSuffix(file:String):String
	{
		var name = stripExtension(file);

		if (name.toLowerCase().indexOf("voices") == 0)
			name = name.substr(6);

		return name;
	}

	static function normalizeVoiceSuffix(suffix:String):String
	{
		if (suffix == null)
			return "";

		var text = suffix.toLowerCase();

		while (text.length > 0 && (text.substr(0, 1) == "-" || text.substr(0, 1) == "_"))
			text = text.substr(1);

		return text;
	}

	function updateAudioVolumes():Void
	{
		if (audio != null)
			audio.volume = instMuted ? 0 : 1;

		var audibleChannels:Map<Int, Bool> = new Map();
		var hasAssignments = false;

		if (!voicesMuted && chartData != null)
		{
			for (line in chartData.strumLines)
			{
				var index = resolvedVoiceIndexForLine(line.index);

				if (index >= 0 && index < voiceSounds.length)
				{
					audibleChannels.set(index, true);
					hasAssignments = true;
				}
			}
		}

		for (i in 0...voiceSounds.length)
		{
			var audible = !voicesMuted && (!hasAssignments || audibleChannels.exists(i));
			voiceSounds[i].volume = audible ? 1 : 0;
		}
	}

	function changeSong(delta:Int):Void
	{
		if (songs.length == 0)
			return;

		if (dirty)
		{
			setStatus("UNSAVED CHANGES - CTRL+S TO SAVE", 0xFFFFAA33);
			return;
		}

		selectedSong = wrapIndex(selectedSong + delta, songs.length);
		selectedDifficulty = preferredDifficulty(currentSong());
		loadCurrentChart();
	}

	function changeDifficulty(delta:Int):Void
	{
		var song = currentSong();

		if (song == null || song.difficulties.length == 0)
			return;

		if (dirty)
		{
			setStatus("UNSAVED CHANGES - CTRL+S TO SAVE", 0xFFFFAA33);
			return;
		}

		selectedDifficulty = wrapIndex(selectedDifficulty + delta, song.difficulties.length);
		loadCurrentChart();
	}

	function cycleSnap(delta:Int):Void
	{
		snapIndex = wrapIndex(snapIndex + delta, SNAP_LABELS.length);
		refreshInfo();
		refreshSnapButtons();
		refreshHoverText();
	}

	function cycleTool(delta:Int):Void
	{
		tool = wrapIndex(tool + delta, TOOL_NAMES.length);
		refreshInfo();
		refreshHoverText();
	}

	function placeKeyboardNote(lane:Int):Void
	{
		selectedDirection = lane;
		var sustain = FlxG.keys.pressed.SHIFT ? beatMs() : 0;
		addNote(snapTime(chartTime), lane, activePlayer, sustain);
	}

	function addNote(time:Float, lane:Int, isPlayer:Bool, sustain:Float):Void
	{
		if (chartData == null)
			return;

		time = snapTime(time);

		if (findNoteAt(time, lane, isPlayer, 0.5) != null)
		{
			setStatus("A NOTE ALREADY EXISTS AT THIS TIME", 0xFFFFAA33);
			return;
		}

		var lineIndex = primaryStrumLineIndex(isPlayer);
		var note = new ChartNote(time, cast lane, lane, Math.max(0, sustain), isPlayer, "", -1, lineIndex, lane);
		chartData.notes.push(note);

		var line = findStrumLineData(lineIndex);

		if (line != null)
			line.notes.push(note);

		chartData.notes.sort(compareNotes);
		markDirty('ADDED ${isPlayer ? "PLAYER" : "OPPONENT"} ${DIRECTION_NAMES[lane]} NOTE');
	}

	function primaryStrumLineIndex(isPlayer:Bool):Int
	{
		if (chartData != null)
		{
			for (data in chartData.strumLines)
			{
				if (data.isPlayer == isPlayer)
					return data.index;
			}
		}

		return -1;
	}

	function eraseNoteAt(time:Float, lane:Int, isPlayer:Bool):Void
	{
		if (chartData == null)
			return;

		var tolerance = Math.max(20, snapMs() * 0.6);
		var note = findNoteAt(time, lane, isPlayer, tolerance);

		if (note == null)
		{
			setStatus("NO NOTE TO ERASE", 0xFFFFAA33);
			return;
		}

		chartData.notes.remove(note);
		markDirty("ERASED NOTE");
	}

	function sustainNoteAt(time:Float, lane:Int, isPlayer:Bool):Void
	{
		if (chartData == null)
			return;

		var tolerance = Math.max(20, snapMs() * 0.6);
		var note = findNoteAt(time, lane, isPlayer, tolerance);

		if (note == null)
		{
			addNote(time, lane, isPlayer, beatMs());
			return;
		}

		note.sustainLength = Math.max(beatMs(), note.sustainLength + beatMs());
		markDirty("EXTENDED SUSTAIN");
	}

	function deleteAtCursor():Void
	{
		var time = hoverValid ? hoverTime : snapTime(chartTime);
		var lane = hoverValid ? hoverLane : selectedDirection;
		var isPlayer = hoverValid ? hoverPlayer : activePlayer;
		var tolerance = Math.max(20, snapMs() * 0.6);
		var note = findNoteAt(time, lane, isPlayer, tolerance);

		if (note != null)
		{
			chartData.notes.remove(note);
			markDirty("ERASED NOTE");
			return;
		}

		if (selectedEvent() != null)
			deleteSelectedEvent();
	}

	function findNoteAt(time:Float, lane:Int, isPlayer:Bool, tolerance:Float):ChartNote
	{
		if (chartData == null)
			return null;

		var best:ChartNote = null;
		var bestDistance = tolerance;
		var targetLine = primaryStrumLineIndex(isPlayer);

		for (note in chartData.notes)
		{
			if (note.isPlayer != isPlayer || cast(note.direction, Int) != lane)
				continue;

			if (targetLine >= 0 && note.strumLineIndex >= 0 && note.strumLineIndex != targetLine)
				continue;

			var distance = Math.abs(note.time - time);

			if (distance <= bestDistance)
			{
				best = note;
				bestDistance = distance;
			}
		}

		return best;
	}

	function markDirty(message:String):Void
	{
		dirty = true;
		exitArmed = false;
		setStatus(message + " - UNSAVED", 0xFFFFAA33);
		rebuildWaveform();
		refreshChartStatus();
		refreshRuntimeText();
	}

	function buildUi():Void
	{
		buildPanels();
		buildGrid();
		buildLayers();
		buildTexts();
		missingPrompt = new MissingFilePrompt();
		add(missingPrompt);
	}

	function buildPanels():Void
	{
		addRect(LEFT_PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 0xFF101520);
		addRect(RIGHT_PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 0xFF101520);
	}

	function buildGrid():Void
	{
		addRect(GRID_X, GRID_Y, GRID_W, GRID_H, 0xFF080B12);

		for (side in [false, true])
		{
			var start = side ? PLAYER_X : GRID_X;

			for (lane in 0...4)
			{
				var color = (lane + (side ? 1 : 0)) % 2 == 0 ? 0xFF0D1320 : 0xFF0B101A;
				addRect(start + lane * LANE_WIDTH, GRID_Y, LANE_WIDTH, GRID_H, color);
			}
		}

		addRect(GRID_X + 4 * LANE_WIDTH, GRID_Y, CENTER_GAP, GRID_H, 0xFF151B2A);

		for (side in [false, true])
		{
			var start = side ? PLAYER_X : GRID_X;

			for (lane in 0...5)
				addRect(start + lane * LANE_WIDTH, GRID_Y, 1, GRID_H, 0xFF1B2433);
		}

		var row = 0;

		while (row * ROW_HEIGHT <= GRID_H)
		{
			var color = row % 4 == 0 ? 0xFF22304A : 0xFF151B28;
			addRect(GRID_X, GRID_Y + row * ROW_HEIGHT, GRID_W, 1, color);
			row++;
		}

		addRect(GRID_X, GRID_Y, GRID_W, 2, 0xFF334466);
		addRect(GRID_X, GRID_BOTTOM - 2, GRID_W, 2, 0xFF334466);
		addRect(GRID_X, GRID_Y, 2, GRID_H, 0xFF334466);
		addRect(GRID_X + GRID_W - 2, GRID_Y, 2, GRID_H, 0xFF334466);

		addRect(GRID_X, PLAYHEAD_Y, GRID_W, 2, 0xCCFFCC55);

		addRect(GRID_X, TIMELINE_Y, GRID_W, TIMELINE_H, 0xFF1B2433);

		timelineFill = new FlxSprite(GRID_X, TIMELINE_Y);
		timelineFill.makeGraphic(Std.int(GRID_W), Std.int(TIMELINE_H), 0xFF2A6A4A);
		timelineFill.alpha = 0.35;
		timelineFill.origin.set(0, 0);
		timelineFill.scale.x = 0;
		add(timelineFill);

		timelineWaveLayer = new FlxSpriteGroup();
		add(timelineWaveLayer);

		for (i in 0...TIMELINE_BARS)
		{
			var bar = new FlxSprite();
			bar.makeGraphic(Std.int(TIMELINE_BAR_WIDTH), 1, 0xFF66FF88);
			bar.origin.set(0, 0);
			bar.visible = false;
			timelineWaveLayer.add(bar);
			timelineBars.push(bar);
		}

		timelineMarker = new FlxSprite(GRID_X, TIMELINE_Y - 4);
		timelineMarker.makeGraphic(2, Std.int(TIMELINE_H + 8), FlxColor.WHITE);
		add(timelineMarker);
	}

	function buildLayers():Void
	{
		cursorSprite = new FlxSprite();
		cursorSprite.makeGraphic(Std.int(NOTE_SIZE), Std.int(NOTE_SIZE), 0x33FFFFFF);
		cursorSprite.visible = false;
		add(cursorSprite);

		gridWaveLayer = new FlxSpriteGroup();
		add(gridWaveLayer);

		eventLayer = new FlxSpriteGroup();
		add(eventLayer);

		receptorLayer = new FlxSpriteGroup();
		add(receptorLayer);

		tailLayer = new FlxSpriteGroup();
		add(tailLayer);

		noteLayer = new FlxSpriteGroup();
		add(noteLayer);

		for (i in 0...GRID_WAVE_BARS)
		{
			var bar = new FlxSprite();
			bar.makeGraphic(1, 1, 0xFF66FF88);
			bar.origin.set(0, 0);
			bar.visible = false;
			gridWaveLayer.add(bar);
			gridWaveBars.push(bar);
		}

		for (i in 0...MAX_EVENT_SPRITES)
		{
			var marker = new FlxSprite();
			marker.makeGraphic(12, 12, 0xFFFFAA33);
			marker.visible = false;
			eventLayer.add(marker);
			eventSprites.push(marker);
		}

		var noteFrame = noteFrames == null ? null : noteFrames.getByName("noteLEFT0000");

		for (i in 0...MAX_NOTE_SPRITES)
		{
			var sprite = new FlxSprite();

			if (noteFrame != null)
			{
				sprite.frames = noteFrames;
				sprite.frame = noteFrame;
			}
			else
			{
				sprite.makeGraphic(Std.int(NOTE_SIZE), Std.int(NOTE_HEIGHT), FlxColor.WHITE);
			}

			sprite.visible = false;
			noteLayer.add(sprite);
			noteSprites.push(sprite);

			var tail = new FlxSprite();
			tail.makeGraphic(Std.int(TAIL_WIDTH), 1, FlxColor.WHITE);
			tail.origin.set(0, 0);
			tail.visible = false;
			tailLayer.add(tail);
			tailSprites.push(tail);
		}

		for (side in [false, true])
		{
			for (lane in 0...4)
			{
				var socketWidth = LANE_WIDTH - 8;
				var socketHeight = RECEPTOR_SIZE + 12;
				var socketX = laneCenter(lane, side) - socketWidth * 0.5;
				var socketY = PLAYHEAD_Y - socketHeight * 0.5;

				var border = new FlxSprite(socketX - 2, socketY - 2);
				border.makeGraphic(Std.int(socketWidth + 4), Std.int(socketHeight + 4), side ? 0xFF335588 : 0xFF553355);
				border.alpha = 0.55;
				receptorLayer.add(border);

				var socket = new FlxSprite(socketX, socketY);
				socket.makeGraphic(Std.int(socketWidth), Std.int(socketHeight), 0xFF080B12);
				socket.alpha = 0.92;
				receptorLayer.add(socket);

				var receptor = new FlxSprite();
				var frame = noteFrames == null ? null : noteFrames.getByName(noteFrameName(lane));

				if (frame != null)
				{
					receptor.frames = noteFrames;
					receptor.frame = frame;
				}
				else
				{
					receptor.makeGraphic(Std.int(RECEPTOR_SIZE), Std.int(RECEPTOR_SIZE), FlxColor.WHITE);
				}

				receptor.color = side ? 0xFF6688BB : 0xFF886688;
				receptor.alpha = 0.45;
				receptor.x = laneCenter(lane, side) - receptor.width * 0.5;
				receptor.y = PLAYHEAD_Y - receptor.height * 0.5;
				receptorLayer.add(receptor);
			}
		}
	}

	function buildTexts():Void
	{
		titleText = new FlxText(0, 10, FlxG.width, "CHART EDITOR", 28);
		titleText.alignment = FlxTextAlign.CENTER;
		titleText.color = FlxColor.WHITE;
		add(titleText);

		subtitleText = new FlxText(0, 42, FlxG.width, "", 14);
		subtitleText.alignment = FlxTextAlign.CENTER;
		subtitleText.color = 0xFF8888AA;
		add(subtitleText);

		var leftHeader = new FlxText(LEFT_PANEL_X + 8, 64, PANEL_W - 16, "CHART", 16);
		leftHeader.color = 0xFF7777AA;
		add(leftHeader);

		buildInputFields();

		var audioHeader = new FlxText(LEFT_PANEL_X + 8, 276, PANEL_W - 16, "AUDIO CHANNELS", 12);
		audioHeader.color = 0xFF7777AA;
		add(audioHeader);

		buildAudioRows();

		timeText = new FlxText(LEFT_PANEL_X + 8, 378, PANEL_W - 16, "", 12);
		timeText.color = 0xFF66FF88;
		add(timeText);

		snapText = new FlxText(LEFT_PANEL_X + 8, 398, PANEL_W - 16, "", 12);
		snapText.color = 0xFF8888AA;
		add(snapText);

		buildSnapButtons();

		toolText = new FlxText(LEFT_PANEL_X + 8, 438, PANEL_W - 16, "", 12);
		toolText.color = 0xFF8888AA;
		add(toolText);

		sideText = new FlxText(LEFT_PANEL_X + 8, 458, PANEL_W - 16, "", 12);
		sideText.color = 0xFF8888AA;
		add(sideText);

		chartStatusText = new FlxText(LEFT_PANEL_X + 8, 476, PANEL_W - 16, "", 10);
		chartStatusText.color = 0xFFAAAAAA;
		chartStatusText.wordWrap = true;
		add(chartStatusText);

		hoverText = new FlxText(LEFT_PANEL_X + 8, 550, PANEL_W - 16, "", 10);
		hoverText.color = 0xFFAAAAAA;
		hoverText.wordWrap = true;
		add(hoverText);

		helpText = new FlxText(LEFT_PANEL_X + 8, 596, PANEL_W - 16, "", 9);
		helpText.color = 0xFF666688;
		helpText.wordWrap = true;
		helpText.text = "ENTER APPLY  ESC CANCEL  TAB NEXT\nF5/F6 SONG  F7/F8 DIFF  CTRL+S SAVE";
		add(helpText);

		var rightHeader = new FlxText(RIGHT_PANEL_X + 8, 64, PANEL_W - 16, "EVENTS", 16);
		rightHeader.color = 0xFF7777AA;
		add(rightHeader);

		eventTypeText = new FlxText(RIGHT_PANEL_X + 8, 88, PANEL_W - 16, "", 14);
		eventTypeText.color = FlxColor.WHITE;
		add(eventTypeText);

		eventParamText = new FlxText(RIGHT_PANEL_X + 8, 110, PANEL_W - 16, "", 13);
		eventParamText.color = 0xFFAAAAAA;
		eventParamText.wordWrap = true;
		add(eventParamText);

		for (i in 0...EVENT_ROWS)
		{
			var row = new FlxText(RIGHT_PANEL_X + 8, EVENT_LIST_Y + i * EVENT_ROW_HEIGHT, PANEL_W - 16, "", 13);
			row.color = 0xFF8888AA;
			add(row);
			eventTexts.push(row);
		}

		eventHelpText = new FlxText(RIGHT_PANEL_X + 8, 462, PANEL_W - 16, "", 11);
		eventHelpText.color = 0xFF666688;
		eventHelpText.wordWrap = true;
		eventHelpText.text = "INSERT: ADD EVENT\nPGUP/PGDN: SELECT\nT: CYCLE TYPE\nY: CYCLE PARAMS\n, / .: MOVE BY SNAP\nDEL: ERASE NOTE OR EVENT";
		add(eventHelpText);

		for (side in [false, true])
		{
			var start = side ? PLAYER_X : GRID_X;

			for (lane in 0...4)
			{
				var label = new FlxText(start + lane * LANE_WIDTH, GRID_Y + 2, LANE_WIDTH, DIRECTION_NAMES[lane], 10);
				label.alignment = FlxTextAlign.CENTER;
				label.color = 0xFF555577;
				add(label);
			}

			var sideLabel = new FlxText(start, GRID_Y + 18, 4 * LANE_WIDTH, side ? "PLAYER" : "OPPONENT", 11);
			sideLabel.alignment = FlxTextAlign.CENTER;
			sideLabel.color = side ? 0xFF88AAFF : 0xFF887788;
			add(sideLabel);
		}

		statusText = new FlxText(0, 648, FlxG.width, "", 14);
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.color = 0xFF66FF88;
		add(statusText);

		hintText = new FlxText(0, 672, FlxG.width,
			"SPACE PLAY  |  ARROWS SEEK  |  TAB SNAP  |  1-4 PLACE  |  SHIFT+1-4 HOLD  |  E TOOL  |  Q SIDE", 11);
		hintText.alignment = FlxTextAlign.CENTER;
		hintText.color = 0xFF666688;
		add(hintText);

		hintText2 = new FlxText(0, 694, FlxG.width,
			"INSERT EVENT  |  T TYPE  |  Y PARAMS  |  PGUP/PGDN SELECT  |  ,/. MOVE  |  DEL ERASE  |  CTRL+S SAVE  |  F5/F6 SONG  |  F7/F8 DIFF  |  ESC BACK", 11);
		hintText2.alignment = FlxTextAlign.CENTER;
		hintText2.color = 0xFF666688;
		add(hintText2);
	}

	function refreshAll():Void
	{
		refreshInfo();
		refreshEventInfo();
		rebuildWaveform();
		refreshChartStatus();
		refreshRuntimeText();
		refreshHoverText();
	}

	function refreshInfo():Void
	{
		var song = currentSong();

		if (snapText != null)
		{
			snapText.text = 'SNAP: ${SNAP_LABELS[snapIndex]}';
			toolText.text = 'TOOL: ${TOOL_NAMES[tool]}';
			sideText.text = 'SIDE: ${activePlayer ? "PLAYER" : "OPPONENT"}';
			subtitleText.text = song == null ? "NO SONGS FOUND" : '${song.displayName.toUpperCase()}  -  ${currentDifficulty().toUpperCase()}';
		}

		refreshInputFields();
		refreshAudioTexts();
		refreshChartStatus();
		refreshRuntimeText();
	}

	function refreshChartStatus():Void
	{
		if (chartStatusText == null)
			return;

		if (chartData == null)
		{
			chartStatusText.text = "NO CHART";
			return;
		}

		var lines:Array<String> = [];
		lines.push('FORMAT: ${chartFormat()}');
		lines.push('NOTES: ${chartData.notes.length}   EVENTS: ${chartData.events.length}');
		lines.push('BPM: ${formatNumber(bpm())}   SPEED: ${formatNumber(chartData.speed)}');
		lines.push('OFFSET: ${formatNumber(chartData.offset)} ms   LENGTH: ${formatTime(songLength)}');
		lines.push('AUDIO: ${audioLabel()}');
		lines.push('WAVEFORM: $waveformSource');

		if (voiceFileNames.length > 0)
		{
			var voiceText = voiceFileNames.join(", ");

			if (voiceText.length > 44)
				voiceText = '${voiceFileNames[0]} +${voiceFileNames.length - 1}';

			lines.push('VOICES: $voiceText');
		}

		if (loadFailed)
			lines.push("SAVE BLOCKED: LOAD FAILED");

		chartStatusText.text = lines.join("\n");
	}

	function refreshRuntimeText():Void
	{
		if (timeText != null)
			timeText.text = 'TIME: ${formatTime(chartTime)} / ${formatTime(songLength)}';

		if (timelineFill != null)
		{
			var progress = songLength > 0 ? clamp(chartTime / songLength, 0, 1) : 0;
			timelineFill.scale.x = progress;
			timelineFill.visible = progress > 0;
			timelineMarker.x = GRID_X + GRID_W * progress - 1;
		}
	}

	function rebuildWaveform():Void
	{
		densityBins = [];

		for (i in 0...WAVEFORM_BINS)
			densityBins.push(0);

		if (chartData == null || songLength <= 0)
		{
			updateTimelineWaveform();
			return;
		}

		var audioLength = activeAudioLength();

		if (audioWaveformPeaks != null && audioWaveformPeaks.length > 0 && audioLength > 0)
		{
			for (i in 0...audioWaveformPeaks.length)
			{
				var time = chartData.offset + ((i + 0.5) / audioWaveformPeaks.length) * audioLength;
				var bin = waveformBin(time);

				if (audioWaveformPeaks[i] > densityBins[bin])
					densityBins[bin] = audioWaveformPeaks[i];
			}
		}
		else
		{
			for (note in chartData.notes)
			{
				var bin = waveformBin(note.time);
				densityBins[bin] += note.sustainLength > 0 ? 1.5 : 1.0;
			}

			for (event in chartData.events)
			{
				var bin = waveformBin(event.time);
				densityBins[bin] += 0.5;
			}

			var maxDensity = 0.0;

			for (value in densityBins)
				maxDensity = Math.max(maxDensity, value);

			if (maxDensity <= 0)
				maxDensity = 1;

			for (i in 0...densityBins.length)
				densityBins[i] /= maxDensity;
		}

		for (i in 1...densityBins.length - 1)
			densityBins[i] = (densityBins[i - 1] + densityBins[i] * 2 + densityBins[i + 1]) * 0.25;

		updateTimelineWaveform();
	}

	function waveformBin(time:Float):Int
	{
		if (songLength <= 0)
			return 0;

		var bin = Std.int(clamp(time / songLength, 0, 1) * (WAVEFORM_BINS - 1));
		return Std.int(clamp(bin, 0, WAVEFORM_BINS - 1));
	}

	function densityAt(time:Float):Float
	{
		if (densityBins.length == 0)
			return 0;

		return densityBins[waveformBin(time)];
	}

	function updateTimelineWaveform():Void
	{
		if (timelineBars.length == 0)
			return;

		var gap = 1.0;
		var step = (GRID_W - gap) / TIMELINE_BARS;
		var barWidth = Math.max(1, step - gap);

		for (i in 0...timelineBars.length)
		{
			var bar = timelineBars[i];
			var start = Std.int(i * densityBins.length / TIMELINE_BARS);
			var end = Std.int((i + 1) * densityBins.length / TIMELINE_BARS);
			var value = 0.0;
			var count = 0;

			for (j in start...end)
			{
				value += densityBins[j];
				count++;
			}

			if (count > 0)
				value /= count;

			var height = Math.max(2, value * (TIMELINE_H - 4));
			bar.x = GRID_X + i * step;
			bar.y = TIMELINE_Y + TIMELINE_H - height;
			bar.scale.set(barWidth / TIMELINE_BAR_WIDTH, height);
			bar.visible = value > 0.01;
		}
	}

	function updateGridWaveform():Void
	{
		if (gridWaveBars.length == 0)
			return;

		var centerLeft = GRID_X + 4 * LANE_WIDTH;
		var centerRight = centerLeft + CENTER_GAP;
		var centerX = (centerLeft + centerRight) * 0.5;
		var maxWidth = Math.max(2, centerRight - centerLeft - 4);

		for (i in 0...gridWaveBars.length)
		{
			var bar = gridWaveBars[i];
			var y = GRID_Y + (i + 0.5) * (GRID_H / GRID_WAVE_BARS);
			var time = yToTime(y);
			var value = densityAt(time);
			var width = Math.max(2, value * maxWidth);
			bar.x = centerX - width * 0.5;
			bar.y = y - 1;
			bar.scale.set(width, 2);
			bar.alpha = 0.3 + value * 0.5;
			bar.visible = value > 0.01;
		}
	}

	function refreshHoverText():Void
	{
		if (hoverText == null)
			return;

		if (!hoverValid)
		{
			hoverText.text = "HOVER A LANE TO INSPECT\nCLICK TO EDIT";
			return;
		}

		var note = findNoteAt(hoverTime, hoverLane, hoverPlayer, Math.max(15, snapMs() * 0.6));
		var lines:Array<String> = [];
		lines.push('HOVER: ${hoverPlayer ? "PLAYER" : "OPPONENT"} ${DIRECTION_NAMES[hoverLane]}');
		lines.push('TIME: ${formatTime(hoverTime)}');
		lines.push('SNAP: ${SNAP_LABELS[snapIndex]}');

		if (note != null)
			lines.push('NOTE: ${formatTime(note.time)}  SUSTAIN ${Std.int(note.sustainLength)} ms');
		else
			lines.push("NOTE: NONE");

		hoverText.text = lines.join("\n");
	}

	function refreshEventInfo():Void
	{
		if (chartData == null || eventTypeText == null)
			return;

		var selected = selectedEvent();

		if (selected != null)
		{
			eventTypeIndex = eventTypeIndexFor(selected.name);
			eventParamIndex = eventParamIndexFor(selected.name, selected.params);
			eventTypeText.text = 'SELECTED: ${selected.name}';
			eventParamText.text = 'TIME: ${formatTime(selected.time)}\nPARAMS: ${formatParams(selected.params)}';
		}
		else
		{
			eventTypeText.text = 'NEW EVENT: ${EVENT_TYPES[eventTypeIndex]}';
			eventParamText.text = 'PARAMS: ${formatParams(presetAt(eventParamIndex))}';
		}

		ensureEventVisible();

		for (i in 0...eventTexts.length)
		{
			var index = eventListOffset + i;

			if (index >= chartData.events.length)
			{
				eventTexts[i].text = "";
				continue;
			}

			var event = chartData.events[index];
			eventTexts[i].text = (index == selectedEventIndex ? "> " : "  ") + formatTime(event.time) + "  " + event.name;
			eventTexts[i].color = index == selectedEventIndex ? FlxColor.WHITE : 0xFF8888AA;
		}
	}

	function ensureEventVisible():Void
	{
		if (chartData == null || eventTexts.length == 0)
			return;

		if (selectedEventIndex >= 0)
		{
			if (selectedEventIndex < eventListOffset)
				eventListOffset = selectedEventIndex;
			else if (selectedEventIndex >= eventListOffset + EVENT_ROWS)
				eventListOffset = selectedEventIndex - EVENT_ROWS + 1;
		}

		var maxOffset = Std.int(Math.max(0, chartData.events.length - EVENT_ROWS));
		eventListOffset = Std.int(clamp(eventListOffset, 0, maxOffset));
	}

	function selectedEvent():ChartEvent
	{
		if (chartData == null || selectedEventIndex < 0 || selectedEventIndex >= chartData.events.length)
			return null;

		return chartData.events[selectedEventIndex];
	}

	function selectEvent(delta:Int):Void
	{
		if (chartData == null || chartData.events.length == 0)
			return;

		if (selectedEventIndex < 0)
			selectedEventIndex = delta >= 0 ? 0 : chartData.events.length - 1;
		else
			selectedEventIndex = wrapIndex(selectedEventIndex + delta, chartData.events.length);

		refreshEventInfo();
	}

	function selectEventIndex(index:Int):Void
	{
		if (chartData == null || index < 0 || index >= chartData.events.length)
			return;

		selectedEventIndex = index;
		refreshEventInfo();
	}

	function addEvent():Void
	{
		if (chartData == null)
			return;

		var event = new ChartEvent(EVENT_TYPES[eventTypeIndex], snapTime(chartTime), copyParams(presetAt(eventParamIndex)));
		chartData.events.push(event);
		chartData.events.sort(compareEvents);
		selectedEventIndex = chartData.events.indexOf(event);
		markDirty('ADDED EVENT ${event.name}');
		refreshEventInfo();
	}

	function deleteSelectedEvent():Void
	{
		var event = selectedEvent();

		if (event == null)
			return;

		chartData.events.remove(event);
		selectedEventIndex = chartData.events.length == 0 ? -1 : Std.int(Math.min(selectedEventIndex, chartData.events.length - 1));
		markDirty("ERASED EVENT");
		refreshEventInfo();
	}

	function moveSelectedEvent(delta:Float):Void
	{
		var event = selectedEvent();

		if (event == null)
			return;

		event.time = Math.max(0, event.time + delta);
		chartData.events.sort(compareEvents);
		selectedEventIndex = chartData.events.indexOf(event);
		markDirty("MOVED EVENT");
		refreshEventInfo();
	}

	function cycleEventType():Void
	{
		eventTypeIndex = wrapIndex(eventTypeIndex + 1, EVENT_TYPES.length);
		eventParamIndex = 0;
		var event = selectedEvent();

		if (event != null)
		{
			event.name = EVENT_TYPES[eventTypeIndex];
			event.params = copyParams(presetAt(0));
			markDirty('EVENT TYPE ${event.name}');
		}

		refreshEventInfo();
	}

	function cycleEventParams():Void
	{
		var presets = currentPresets();
		eventParamIndex = wrapIndex(eventParamIndex + 1, presets.length);
		var event = selectedEvent();

		if (event != null)
		{
			event.params = copyParams(presetAt(eventParamIndex));
			markDirty("CHANGED EVENT PARAMS");
		}

		refreshEventInfo();
	}

	function currentPresets():Array<Dynamic>
	{
		eventTypeIndex = wrapIndex(eventTypeIndex, EVENT_PARAMS.length);
		return EVENT_PARAMS[eventTypeIndex];
	}

	function presetAt(index:Int):Array<Dynamic>
	{
		var presets = currentPresets();

		if (presets.length == 0)
			return [];

		return cast(presets[wrapIndex(index, presets.length)], Array<Dynamic>);
	}

	function eventTypeIndexFor(name:String):Int
	{
		for (i in 0...EVENT_TYPES.length)
		{
			if (EVENT_TYPES[i] == name)
				return i;
		}

		return 0;
	}

	function eventParamIndexFor(name:String, params:Array<Dynamic>):Int
	{
		var typeIndex = eventTypeIndexFor(name);
		var presets:Array<Dynamic> = EVENT_PARAMS[typeIndex];
		var text = formatParams(params);

		for (i in 0...presets.length)
		{
			var preset:Array<Dynamic> = cast presets[i];

			if (formatParams(preset) == text)
				return i;
		}

		return 0;
	}

	function copyParams(params:Array<Dynamic>):Array<Dynamic>
	{
		var result:Array<Dynamic> = [];

		if (params != null)
		{
			for (value in params)
				result.push(value);
		}

		return result;
	}

	function formatParams(params:Array<Dynamic>):String
	{
		if (params == null)
			return "[]";

		try
		{
			return haxe.Json.stringify(params);
		}
		catch (error:Dynamic)
		{
			return Std.string(params);
		}
	}

	function audioLabel():String
	{
		if (audio != null && voiceSounds.length > 0)
			return 'INST + ${voiceSounds.length} VOICE${voiceSounds.length == 1 ? "" : "S"}';

		if (audio != null)
			return "INST.OGG";

		if (voiceSounds.length > 0)
			return '${voiceSounds.length} VOICE${voiceSounds.length == 1 ? "" : "S"} ONLY';

		return "SIMULATED";
	}

	function activeAudioLength():Float
	{
		var length = 0.0;

		if (audio != null)
			length = Math.max(length, audio.length);

		for (sound in voiceSounds)
			length = Math.max(length, sound.length);

		return length;
	}

	function applyAudioPosition():Void
	{
		if (chartData == null)
			return;

		var target = clamp(chartTime - chartData.offset, 0, activeAudioLength());

		if (audio != null)
			audio.time = clamp(target, 0, audio.length);

		for (sound in voiceSounds)
			sound.time = clamp(target, 0, sound.length);
	}

	function startPlaybackAudio():Void
	{
		applyAudioPosition();

		if (audio != null)
			audio.play();

		for (sound in voiceSounds)
			sound.play();
	}

	function updatePlayback(elapsed:Float):Void
	{
		if (!playing || chartData == null)
			return;

		if (audio != null || voiceSounds.length > 0)
		{
			var syncSound = (audio != null && audio.playing) ? audio : null;

			if (syncSound == null)
			{
				for (sound in voiceSounds)
				{
					if (sound.playing)
					{
						syncSound = sound;
						break;
					}
				}
			}

			if (syncSound == null)
				syncSound = audio;

			if (syncSound != null)
			{
				chartTime = syncSound.time + chartData.offset;

				if (audio != null && audio.playing)
				{
					for (sound in voiceSounds)
					{
						if (!sound.playing)
							continue;

						var target = clamp(audio.time, 0, sound.length);

						if (Math.abs(sound.time - target) > 80)
							sound.time = target;
					}
				}
			}

			if (chartTime >= songLength)
			{
				chartTime = songLength;
				pausePlayback();
			}
		}
		else
		{
			chartTime += elapsed * 1000;

			if (chartTime >= songLength)
			{
				chartTime = songLength;
				playing = false;
			}
		}

		if (chartTime < 0)
			chartTime = 0;
	}

	function togglePlayback():Void
	{
		if (playing)
		{
			pausePlayback();
			return;
		}

		if (chartData == null)
			return;

		if (chartTime >= songLength - 50)
			chartTime = 0;

		startPlaybackAudio();
		playing = true;
	}

	function pausePlayback():Void
	{
		playing = false;

		if (audio != null)
			audio.pause();

		for (sound in voiceSounds)
			sound.pause();
	}

	function seekTo(time:Float):Void
	{
		chartTime = clamp(time, 0, songLength);

		if (playing)
			startPlaybackAudio();
		else
			applyAudioPosition();

		refreshRuntimeText();
	}

	function seekBy(delta:Float):Void
	{
		seekTo(snapTime(chartTime) + delta);
	}

	function updateChartView():Void
	{
		if (chartData == null)
			return;

		var usedNotes = 0;
		var usedTails = 0;

		for (note in chartData.notes)
		{
			var y = timeToY(note.time);

			if (usedNotes >= noteSprites.length)
				break;

			var sprite = noteSprites[usedNotes];
			applyNoteVisual(sprite, cast(note.direction, Int));
			var halfHeight = sprite.height * 0.5;

			if (y >= GRID_Y + halfHeight && y <= GRID_BOTTOM - halfHeight)
			{
				usedNotes++;
				sprite.x = laneCenter(cast(note.direction, Int), note.isPlayer) - sprite.width * 0.5;
				sprite.y = y - halfHeight;
				sprite.alpha = note.isPlayer ? 1.0 : 0.8;
				sprite.visible = true;
			}

			if (note.sustainLength > 0 && usedTails < tailSprites.length)
			{
				var endY = timeToY(note.time + note.sustainLength);
				var top = Math.max(Math.min(y, endY), GRID_Y);
				var bottom = Math.min(Math.max(y, endY), GRID_BOTTOM);

				if (bottom - top > 1)
				{
					var tail = tailSprites[usedTails++];
					tail.x = laneCenter(cast(note.direction, Int), note.isPlayer) - TAIL_WIDTH * 0.5;
					tail.y = top;
					tail.scale.set(1, bottom - top);
					tail.color = noteColor(cast(note.direction, Int));
					tail.alpha = note.isPlayer ? 0.85 : 0.55;
					tail.visible = true;
				}
			}
		}

		for (i in usedNotes...noteSprites.length)
			noteSprites[i].visible = false;

		for (i in usedTails...tailSprites.length)
			tailSprites[i].visible = false;

		var usedEvents = 0;

		for (event in chartData.events)
		{
			var y = timeToY(event.time);

			if (y < GRID_Y + 6 || y > GRID_BOTTOM - 6)
				continue;

			if (usedEvents >= eventSprites.length)
				break;

			var marker = eventSprites[usedEvents++];
			marker.x = GRID_X + GRID_W * 0.5 - 6;
			marker.y = y - 6;
			marker.color = selectedEvent() == event ? FlxColor.WHITE : 0xFFFFAA33;
			marker.visible = true;
		}

		for (i in usedEvents...eventSprites.length)
			eventSprites[i].visible = false;

		updateGridWaveform();
	}

	function applyNoteVisual(sprite:FlxSprite, direction:Int):Void
	{
		if (noteFrames != null)
		{
			var frame = noteFrames.getByName(noteFrameName(direction));

			if (frame != null)
			{
				if (sprite.frames != noteFrames)
					sprite.frames = noteFrames;

				sprite.frame = frame;
				sprite.color = FlxColor.WHITE;
				return;
			}
		}

		sprite.color = noteColor(direction);
	}

	function loadCurrentChart():Void
	{
		destroyAudio();
		chartTime = 0;
		playing = false;
		selectedEventIndex = -1;
		eventListOffset = 0;
		dirty = false;
		exitArmed = false;
		loadFailed = false;
		chartExists = false;
		rawRoot = null;
		rawSongData = null;
		chartAssetPath = null;
		chartPhysicalPath = null;

		var song = currentSong();
		var difficulty = currentDifficulty();

		if (song == null)
		{
			chartData = createEmptyChart(null, 0);
			songLength = computeSongLength();
			refreshAll();
			setStatus("NO SONGS FOUND", 0xFFFF4455);
			return;
		}

		if (!songMetaExists(song))
		{
			chartData = createEmptyChart(song, 0);
			loadAudio();
			songLength = computeSongLength();
			refreshAll();
			requestMissingSongMeta(song);
			return;
		}

		var metaText = readMetaText(song);
		var metaBpm = metaBpmFromText(metaText);
		chartAssetPath = '$SONG_ROOT${song.folder}/charts/$difficulty.json';
		chartPhysicalPath = physicalChartPath(song, difficulty);
		var text = readChartText(song, difficulty);

		if (text == null)
		{
			chartData = createEmptyChart(song, metaBpm);
			loadAudio();
			songLength = computeSongLength();
			refreshAll();
			requestMissingChart(song, difficulty);
			return;
		}

		chartExists = true;

		try
		{
			rawRoot = haxe.Json.parse(text);
			rawSongData = nestedSong(rawRoot);
			chartData = FNFChartParser.parse(text, ChartTimeMode.AbsoluteMs, metaBpm);

			if (chartData.bpm <= 0)
				chartData.bpm = metaBpm > 0 ? metaBpm : (song.bpm > 0 ? song.bpm : 120);

			chartData.songName = song.displayName;
			loadAudio();
			songLength = computeSongLength();
			refreshAll();
			setStatus('LOADED $chartAssetPath', 0xFF66FF88);
		}
		catch (error:Dynamic)
		{
			chartData = createEmptyChart(song, metaBpm);
			rawRoot = null;
			rawSongData = null;
			loadFailed = true;
			loadAudio();
			songLength = computeSongLength();
			refreshAll();
			setStatus('CHART LOAD FAILED: ${Std.string(error)}', 0xFFFF4455);
		}
	}

	static function songMetaExists(song:EditorSong):Bool
	{
		if (song == null)
			return false;

		return fileExists(physicalMetaPath(song)) || assetExists('$SONG_ROOT${song.folder}/meta.json');
	}

	function requestMissingSongMeta(song:EditorSong):Void
	{
		#if sys
		if (missingPrompt == null || missingPrompt.isOpen)
			return;

		var path = physicalMetaPath(song);

		missingPrompt.show("SONG METADATA", path, "A minimal meta.json with display name, BPM and difficulties will be created.",
			function()
			{
				if (createSongMetaTemplate(song, path))
				{
					loadCurrentChart();

					if (missingPrompt == null || !missingPrompt.isOpen)
						setStatus('CREATED + LOADED $path', 0xFF66FF88);
				}
				else
				{
					setStatus('CREATE ERROR: $path', 0xFFFF4455);
				}
			},
			function()
			{
				setStatus('SONG METADATA NOT CREATED - LOAD CANCELLED', 0xFFFFAA33);
			});
		#else
		setStatus('SONG METADATA NOT FOUND: ${physicalMetaPath(song)}', 0xFFFF4455);
		#end
	}

	function requestMissingChart(song:EditorSong, difficulty:String):Void
	{
		#if sys
		if (missingPrompt == null || missingPrompt.isOpen)
			return;

		var path = physicalChartPath(song, difficulty);

		missingPrompt.show("CHART", path, "A minimal chart with Dad/BF strumlines and empty note arrays will be created.",
			function()
			{
				if (createChartTemplate(song, path))
				{
					loadCurrentChart();

					if (missingPrompt == null || !missingPrompt.isOpen)
						setStatus('CREATED + LOADED $path', 0xFF66FF88);
				}
				else
				{
					setStatus('CREATE ERROR: $path', 0xFFFF4455);
				}
			},
			function()
			{
				setStatus('CHART NOT CREATED - SAVE TO CREATE', 0xFFFFAA33);
			});
		#else
		setStatus('CHART NOT FOUND: ${physicalChartPath(song, difficulty)}', 0xFFFF4455);
		#end
	}

	#if sys
	static function createSongMetaTemplate(song:EditorSong, path:String):Bool
	{
		try
		{
			var directory = haxe.io.Path.directory(path);

			if (directory != null && directory != "" && !FileSystem.exists(directory))
				FileSystem.createDirectory(directory);

			var difficulties = song.difficulties.length > 0 ? song.difficulties : ["hard"];
			var data:Dynamic = {
				displayName: song.displayName,
				bpm: song.bpm > 0 ? song.bpm : 120,
				difficulties: difficulties
			};

			File.saveContent(path, haxe.Json.stringify(data, null, "\t") + "\n");
			return true;
		}
		catch (error:Dynamic)
		{
			return false;
		}
	}

	function createChartTemplate(song:EditorSong, path:String):Bool
	{
		try
		{
			var directory = haxe.io.Path.directory(path);

			if (directory != null && directory != "" && !FileSystem.exists(directory))
				FileSystem.createDirectory(directory);

			var metaBpm = metaBpmFromText(readMetaText(song));
			var bpm = metaBpm > 0 ? metaBpm : (song.bpm > 0 ? song.bpm : 120);
			var data:Dynamic = {
				songName: song.displayName,
				bpm: bpm,
				scrollSpeed: 1,
				stage: "stage",
				needsVoices: true,
				offset: 0,
				events: [],
				strumLines: createDefaultStrumLines()
			};

			File.saveContent(path, haxe.Json.stringify(data, null, "\t") + "\n");
			return true;
		}
		catch (error:Dynamic)
		{
			return false;
		}
	}
	#end

	function createEmptyChart(song:EditorSong, metaBpm:Float):FNFChart
	{
		var chart = new FNFChart();
		chart.songName = song == null ? "Untitled" : song.displayName;
		chart.bpm = metaBpm > 0 ? metaBpm : (song != null && song.bpm > 0 ? song.bpm : 120);
		chart.speed = 1;
		chart.player1 = "bf";
		chart.player2 = "dad";
		chart.playerCharacter = "bf";
		chart.opponentCharacter = "dad";
		chart.gfVersion = "gf";
		chart.stage = "stage";
		chart.needsVoices = true;
		chart.offset = 0;
		chart.strumLines.push(new StrumLineData(0, "dad", 4, [chart.opponentCharacter]));
		chart.strumLines.push(new StrumLineData(1, "bf", 4, [chart.playerCharacter]));
		return chart;
	}

	function readMetaText(song:EditorSong):String
	{
		if (song == null)
			return null;

		var text = readFileText(physicalMetaPath(song));

		if (text != null)
			return text;

		return readAssetText('$SONG_ROOT${song.folder}/meta.json');
	}

	function readChartText(song:EditorSong, difficulty:String):String
	{
		if (song == null)
			return null;

		var text = readFileText(physicalChartPath(song, difficulty));

		if (text != null)
			return text;

		return readAssetText('$SONG_ROOT${song.folder}/charts/$difficulty.json');
	}

	static function metaBpmFromText(text:String):Float
	{
		if (text == null)
			return 0;

		try
		{
			var json:Dynamic = haxe.Json.parse(stripBom(text));
			return readFloat(Reflect.field(json, "bpm"), 0);
		}
		catch (error:Dynamic)
		{
			return 0;
		}
	}

	static function stripBom(text:String):String
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			return text.substr(1);

		return text;
	}

	function audioFileExists(song:EditorSong, fileName:String):Bool
	{
		#if sys
		if (song.physicalRoot != null && fileExists('${song.physicalRoot}/song/$fileName'))
			return true;
		#end

		return assetExists('$SONG_ROOT${song.folder}/song/$fileName');
	}

	function loadSongSound(song:EditorSong, fileName:String):FlxSound
	{
		var virtualPath = '$SONG_ROOT${song.folder}/song/$fileName';

		#if sys
		if (song.physicalRoot != null)
		{
			var physicalPath = '${song.physicalRoot}/song/$fileName';

			if (fileExists(physicalPath))
			{
				try
				{
					var sound = Sound.fromFile(physicalPath);
					return FlxG.sound.load(sound, 1.0, false, null, false, false);
				}
				catch (error:Dynamic) {}
			}
		}
		#end

		try
		{
			if (assetExists(virtualPath))
				return FlxG.sound.load(virtualPath, 1.0, false, null, false, false);
		}
		catch (error:Dynamic) {}

		return null;
	}

	static function isVoiceFile(file:String):Bool
	{
		if (file == null)
			return false;

		var lower = file.toLowerCase();
		return lower.indexOf("voices") == 0 && lower.indexOf(".ogg") == lower.length - 4;
	}

	function findVoiceFileNames(song:EditorSong):Array<String>
	{
		var result:Array<String> = [];
		var seen:Map<String, Bool> = new Map();

		if (song == null)
			return result;

		var candidates = ['Voices-${song.folder}.ogg', "Voices.ogg"];

		for (candidate in candidates)
		{
			if (audioFileExists(song, candidate))
				addUniqueFile(result, seen, candidate);
		}

		#if sys
		if (song.physicalRoot != null)
		{
			var dir = '${song.physicalRoot}/song';

			try
			{
				if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
				{
					for (file in FileSystem.readDirectory(dir))
					{
						if (isVoiceFile(file))
							addUniqueFile(result, seen, file);
					}
				}
			}
			catch (error:Dynamic) {}
		}
		#end

		try
		{
			var prefix = '$SONG_ROOT${song.folder}/song/';

			for (asset in Assets.list())
			{
				if (asset.indexOf(prefix) != 0)
					continue;

				var file = asset.substr(prefix.length);

				if (file.indexOf("/") >= 0)
					continue;

				if (isVoiceFile(file))
					addUniqueFile(result, seen, file);
			}
		}
		catch (error:Dynamic) {}

		return result;
	}

	static function addUniqueFile(result:Array<String>, seen:Map<String, Bool>, file:String):Void
	{
		if (file == null)
			return;

		var key = file.toLowerCase();

		if (seen.exists(key))
			return;

		seen.set(key, true);
		result.push(file);
	}

	function onAudioComplete():Void
	{
		if (audio != null && audio.playing)
			return;

		for (sound in voiceSounds)
		{
			if (sound.playing)
				return;
		}

		pausePlayback();
	}

	function loadAudio():Void
	{
		destroyAudio();

		var song = currentSong();

		if (song == null)
			return;

		audio = loadSongSound(song, "Inst.ogg");

		if (audio != null)
			audio.onComplete = onAudioComplete;

		var files = findVoiceFileNames(song);
		var loadedFiles:Array<String> = [];

		for (file in files)
		{
			var sound = loadSongSound(song, file);

			if (sound == null)
				continue;

			sound.onComplete = onAudioComplete;
			voiceSounds.push(sound);
			loadedFiles.push(file);
		}

		voiceFileNames = loadedFiles;

		loadAudioWaveform(song);
		updateAudioVolumes();

		if (audio == null && voiceSounds.length == 0)
			FlxG.log.warn('Chart editor: no audio for ${song.folder}; using simulated playback');
	}

	function destroyAudio():Void
	{
		if (audio != null)
		{
			audio.stop();
			audio.destroy();
			audio = null;
		}

		for (sound in voiceSounds)
		{
			sound.stop();
			sound.destroy();
		}

		voiceSounds = [];
		voiceFileNames = [];
		voiceAssignments = new Map();
		closeVoicePanel();
		instMuted = false;
		voicesMuted = false;
		audioWaveformPeaks = null;
		waveformSource = "DENSITY";
	}

	function loadAudioWaveform(song:EditorSong):Void
	{
		audioWaveformPeaks = null;
		waveformSource = "DENSITY";

		var files:Array<String> = [];

		if (audioFileExists(song, "Inst.ogg"))
			files.push("Inst.ogg");

		for (file in voiceFileNames)
		{
			if (files.indexOf(file) < 0)
				files.push(file);
		}

		for (file in files)
		{
			var peaks = buildAudioWaveformPeaks(song, file);

			if (peaks == null)
				continue;

			var maxPeak = 0.0;

			for (value in peaks)
				maxPeak = Math.max(maxPeak, value);

			if (maxPeak <= 0.0001)
				continue;

			audioWaveformPeaks = peaks;
			waveformSource = "AUDIO";
			return;
		}
	}

	function buildAudioWaveformPeaks(song:EditorSong, fileName:String):Array<Float>
	{
		#if (sys && lime_vorbis)
		try
		{
			var vorbis:VorbisFile = null;

			if (song.physicalRoot != null)
			{
				var physicalPath = '${song.physicalRoot}/song/$fileName';

				if (fileExists(physicalPath))
					vorbis = VorbisFile.fromFile(physicalPath);
			}

			if (vorbis == null)
			{
				var virtualPath = '$SONG_ROOT${song.folder}/song/$fileName';

				if (assetExists(virtualPath))
				{
					var bytes = Assets.getBytes(virtualPath);

					if (bytes != null)
						vorbis = VorbisFile.fromBytes(bytes);
				}
			}

			if (vorbis == null)
				return null;

			var info = vorbis.info();
			var totalFrames = Int64.toInt(vorbis.pcmTotal());

			if (info == null || info.channels <= 0 || totalFrames <= 0)
			{
				vorbis.clear();
				return null;
			}

			var peaks:Array<Float> = [];

			for (i in 0...WAVEFORM_BINS)
				peaks.push(0);

			var buffer = Bytes.alloc(65536);
			var bytesPerFrame = info.channels * 2;
			var frameIndex = 0;
			var stride = Std.int(Math.max(1, totalFrames / 300000));

			while (frameIndex < totalFrames)
			{
				var read = vorbis.read(buffer, 0, buffer.length, false, 2, true);

				if (read <= 0)
					break;

				var frames = Std.int(read / bytesPerFrame);

				if (frames <= 0)
					break;

				var frame = 0;

				while (frame < frames)
				{
					var peak = 0.0;
					var base = frame * bytesPerFrame;

					for (channel in 0...info.channels)
					{
						var sample = buffer.getUInt16(base + channel * 2) - 32768;
						var value = Math.abs(sample) / 32768.0;

						if (value > peak)
							peak = value;
					}

					var bin = Std.int(((frameIndex + frame) / totalFrames) * (WAVEFORM_BINS - 1));

					if (bin < 0)
						bin = 0;
					if (bin >= WAVEFORM_BINS)
						bin = WAVEFORM_BINS - 1;

					if (peak > peaks[bin])
						peaks[bin] = peak;

					frame += stride;
				}

				frameIndex += frames;
			}

			vorbis.clear();

			var maxPeak = 0.0;

			for (value in peaks)
				maxPeak = Math.max(maxPeak, value);

			if (maxPeak <= 0.0001)
				return peaks;

			for (i in 0...peaks.length)
				peaks[i] = Math.pow(peaks[i] / maxPeak, 0.65);

			return peaks;
		}
		catch (error:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	function computeSongLength():Float
	{
		var end = 0.0;

		if (chartData != null)
		{
			for (note in chartData.notes)
				end = Math.max(end, note.time + note.sustainLength);

			for (event in chartData.events)
				end = Math.max(end, event.time);

			end = Math.max(end, beatMs() * 4);
		}

		var soundEnd = activeAudioLength();

		if (soundEnd > 0)
			end = Math.max(end, soundEnd + (chartData == null ? 0 : chartData.offset));

		return Math.max(4000, end);
	}

	function saveChart():Void
	{
		if (loadFailed)
		{
			setStatus("CHART FAILED TO LOAD - SAVE BLOCKED", 0xFFFF4455);
			return;
		}

		if (chartData == null)
		{
			setStatus("NO CHART TO SAVE", 0xFFFF4455);
			return;
		}

		#if sys
		var path = resolveSavePath();

		if (path == null)
		{
			setStatus("NO SAVE PATH", 0xFFFF4455);
			return;
		}

		try
		{
			if (rawRoot == null)
				createRawRoot();

			if (rawSongData == null)
				rawSongData = nestedSong(rawRoot);

			writeChartMeta(rawRoot, rawSongData);
			writeEvents(rawRoot, rawSongData);

			if (hasStrumLines())
				writeStrumLines(rawRoot, rawSongData);
			else if (hasClassicSections())
				writeClassic(rawRoot, rawSongData);
			else
			{
				Reflect.setField(rawSongData, "strumLines", createDefaultStrumLines());
				writeStrumLines(rawRoot, rawSongData);
			}

			var output = haxe.Json.stringify(rawRoot, null, "\t");
			var directory = haxe.io.Path.directory(path);

			if (directory != null && directory != "" && !FileSystem.exists(directory))
				FileSystem.createDirectory(directory);

			File.saveContent(path, output);
			chartPhysicalPath = path;
			chartExists = true;
			dirty = false;
			exitArmed = false;

			if (reloadChartFromDisk())
				setStatus('SAVED + HOT RELOADED $path', 0xFF66FF88);
			else
				setStatus('SAVED (RELOAD FAILED) $path', 0xFFFFAA33);

			refreshChartStatus();
		}
		catch (error:Dynamic)
		{
			setStatus('SAVE ERROR: ${Std.string(error)}', 0xFFFF4455);
		}
		#else
		setStatus("SAVE IS NOT AVAILABLE ON THIS TARGET", 0xFFFF4455);
		#end
	}

	function reloadChartFromDisk():Bool
	{
		var song = currentSong();
		var difficulty = currentDifficulty();
		var text = readFileText(chartPhysicalPath);

		if (text == null)
			text = readChartText(song, difficulty);

		if (text == null)
			return false;

		var wasPlaying = playing;
		var previousBpm = chartData == null ? 120 : chartData.bpm;
		var previousName = chartData == null ? null : chartData.songName;

		if (wasPlaying)
			pausePlayback();

		try
		{
			var root:Dynamic = haxe.Json.parse(text);
			var parsed = FNFChartParser.parse(text, ChartTimeMode.AbsoluteMs, previousBpm);

			if (parsed.bpm <= 0)
				parsed.bpm = previousBpm;

			if (previousName != null)
				parsed.songName = previousName;

			rawRoot = root;
			rawSongData = nestedSong(root);
			chartData = parsed;
			voiceAssignments = new Map();
			closeVoicePanel();
			loadFailed = false;
			chartExists = true;
			songLength = computeSongLength();
			chartTime = clamp(chartTime, 0, songLength);
			selectedEventIndex = -1;
			eventListOffset = 0;
			updateAudioVolumes();
			refreshAll();

			if (wasPlaying)
			{
				playing = true;
				startPlaybackAudio();
			}

			return true;
		}
		catch (error:Dynamic)
		{
			if (wasPlaying)
			{
				playing = true;
				startPlaybackAudio();
			}

			return false;
		}
	}

	function createRawRoot():Void
	{
		rawRoot = {};
		rawSongData = rawRoot;
		Reflect.setField(rawRoot, "songName", chartData.songName);
		Reflect.setField(rawRoot, "bpm", chartData.bpm);
		Reflect.setField(rawRoot, "scrollSpeed", chartData.speed);
		Reflect.setField(rawRoot, "stage", chartData.stage);
		Reflect.setField(rawRoot, "needsVoices", chartData.needsVoices);
		Reflect.setField(rawRoot, "offset", chartData.offset);
		Reflect.setField(rawRoot, "events", []);
		Reflect.setField(rawRoot, "strumLines", createDefaultStrumLines());
	}

	function writeChartMeta(root:Dynamic, songData:Dynamic):Void
	{
		if (chartData == null)
			return;

		var target = songData != null && Reflect.isObject(songData) ? songData : root;

		if (target == null)
			return;

		Reflect.setField(target, "bpm", chartData.bpm);
		Reflect.setField(target, "scrollSpeed", chartData.speed);
		Reflect.setField(target, "speed", chartData.speed);
		Reflect.setField(target, "offset", chartData.offset);
	}

	function writeEvents(root:Dynamic, songData:Dynamic):Void
	{
		var rawEvents:Array<Dynamic> = [];

		if (chartData != null)
		{
			for (event in chartData.events)
				rawEvents.push({name: event.name, time: event.time, params: event.params});
		}

		var target = root;

		if (!Std.isOfType(Reflect.field(root, "events"), Array) && songData != root && Std.isOfType(Reflect.field(songData, "events"), Array))
			target = songData;

		Reflect.setField(target, "events", rawEvents);
	}

	function writeStrumLines(root:Dynamic, songData:Dynamic):Void
	{
		if (chartData == null)
			return;

		var rawStrumLines:Dynamic = Reflect.field(songData, "strumLines");

		if (!Std.isOfType(rawStrumLines, Array))
			rawStrumLines = Reflect.field(root, "strumLines");

		var existing:Array<Dynamic> = Std.isOfType(rawStrumLines, Array) ? cast rawStrumLines : [];
		var lines:Array<Dynamic> = [];

		for (i in 0...chartData.strumLines.length)
		{
			var data = chartData.strumLines[i];
			var raw:Dynamic = i < existing.length && Reflect.isObject(existing[i]) ? existing[i] : createStrumLine(data.isPlayer ? "bf" : "dad");

			Reflect.setField(raw, "keyCount", data.keyCount);
			Reflect.setField(raw, "position", data.position);
			Reflect.setField(raw, "characters", data.characters.copy());
			Reflect.setField(raw, "vocalsSuffix", data.vocalsSuffix);
			Reflect.setField(raw, "strumScale", data.strumScale);
			Reflect.setField(raw, "visible", data.visible);
			Reflect.setField(raw, "scrollSpeed", data.scrollSpeed);

			if (data.strumLinePos >= 0)
				Reflect.setField(raw, "strumLinePos", data.strumLinePos);

			if (data.keys.length > 0)
				Reflect.setField(raw, "keys", data.keys.copy());

			var notes:Array<Dynamic> = [];

			for (note in chartData.notes)
			{
				var noteLineIndex = note.strumLineIndex;

				if (noteLineIndex < 0)
					noteLineIndex = primaryStrumLineIndex(note.isPlayer);

				if (noteLineIndex != data.index)
					continue;

				var lane = note.lane >= 0 ? note.lane : cast(note.direction, Int);
				notes.push({id: lane, sLen: note.sustainLength, time: note.time, type: noteTypeValue(note.noteType)});
			}

			notes.sort(compareDynamicNotes);
			Reflect.setField(raw, "notes", notes);
			lines.push(raw);
		}

		if (lines.length == 0)
			lines = createDefaultStrumLines();

		for (data in chartData.strumLines)
		{
			if (data.isPlayer)
			{
				chartData.playerVocalsSuffix = data.vocalsSuffix;
				break;
			}
		}

		for (data in chartData.strumLines)
		{
			if (data.isOpponent)
			{
				chartData.opponentVocalsSuffix = data.vocalsSuffix;
				break;
			}
		}

		var target:Dynamic = songData;

		if (target == null || !Reflect.isObject(target))
			target = root;

		if (songData != root && Std.isOfType(Reflect.field(songData, "strumLines"), Array))
			target = songData;
		else if (Std.isOfType(Reflect.field(root, "strumLines"), Array))
			target = root;

		Reflect.setField(target, "strumLines", lines);
	}

	function writeClassic(root:Dynamic, songData:Dynamic):Void
	{
		var rawSections:Dynamic = Reflect.field(songData, "notes");

		if (!Std.isOfType(rawSections, Array))
			rawSections = Reflect.field(songData, "sections");
		if (!Std.isOfType(rawSections, Array))
			rawSections = Reflect.field(root, "sections");
		if (!Std.isOfType(rawSections, Array))
			return;

		var sections:Array<Dynamic> = cast rawSections;
		var ranges = buildSectionRanges(sections, chartData.bpm);
		var buckets:Array<Array<Dynamic>> = [];

		for (i in 0...sections.length)
			buckets.push([]);

		if (chartData != null)
		{
			for (note in chartData.notes)
			{
				var index = note.sectionIndex;

				if (index < 0 || index >= sections.length)
					index = findRange(ranges, note.time);
				if (index < 0 || index >= ranges.length)
					continue;

				var range = ranges[index];
				var rawData = cast(note.direction, Int) + (note.isPlayer == range.mustHit ? 0 : 4);
				var values:Array<Dynamic> = [note.time, rawData, note.sustainLength, noteTypeValue(note.noteType)];
				buckets[index].push(values);
			}
		}

		for (i in 0...sections.length)
		{
			buckets[i].sort(compareNoteArrays);
			Reflect.setField(sections[i], "sectionNotes", buckets[i]);
		}
	}

	static function buildSectionRanges(sections:Array<Dynamic>, chartBpm:Float):Array<SectionRange>
	{
		var result:Array<SectionRange> = [];
		var currentTime = 0.0;
		var currentBpm = chartBpm > 0 ? chartBpm : 120;

		for (i in 0...sections.length)
		{
			var section = sections[i];
			var changeBpm = readBool(Reflect.field(section, "changeBPM"), false);
			var sectionBpm = readFloat(Reflect.field(section, "bpm"), currentBpm);

			if (changeBpm && sectionBpm > 0)
				currentBpm = sectionBpm;

			var lengthInSteps = readInt(Reflect.field(section, "lengthInSteps"), 16);

			if (lengthInSteps <= 0)
				lengthInSteps = 16;

			var beats = readFloat(Reflect.field(section, "sectionBeats"), lengthInSteps / 4.0);

			if (beats <= 0)
				beats = lengthInSteps / 4.0;

			var end = currentTime + (60000.0 / currentBpm) * beats;
			var mustHit = readBool(Reflect.field(section, "mustHitSection"), false);
			result.push({start: currentTime, end: end, bpm: currentBpm, mustHit: mustHit});
			currentTime = end;
		}

		return result;
	}

	static function findRange(ranges:Array<SectionRange>, time:Float):Int
	{
		for (i in 0...ranges.length)
		{
			var range = ranges[i];

			if (time >= range.start - 0.001 && (time < range.end - 0.001 || i == ranges.length - 1))
				return i;
		}

		return ranges.length - 1;
	}

	function hasStrumLines():Bool
	{
		return (rawRoot != null && Std.isOfType(Reflect.field(rawRoot, "strumLines"), Array))
			|| (rawSongData != null && Std.isOfType(Reflect.field(rawSongData, "strumLines"), Array));
	}

	function hasClassicSections():Bool
	{
		if (rawSongData != null)
		{
			if (Std.isOfType(Reflect.field(rawSongData, "notes"), Array) || Std.isOfType(Reflect.field(rawSongData, "sections"), Array))
				return true;
		}

		return rawRoot != null && Std.isOfType(Reflect.field(rawRoot, "sections"), Array);
	}

	function chartFormat():String
	{
		if (loadFailed)
			return "LOAD FAILED";
		if (!chartExists)
			return "NEW STRUMLINES";
		if (hasStrumLines())
			return "STRUMLINES";
		if (hasClassicSections())
			return "SECTIONS";

		return "UNKNOWN";
	}

	function resolveSavePath():String
	{
		var song = currentSong();

		if (song == null)
			return null;

		var root = song.physicalRoot;

		if (root == null)
			root = '$SONG_ROOT${song.folder}';

		return '$root/charts/${currentDifficulty()}.json';
	}

	static function noteTypeValue(noteType:String):Dynamic
	{
		if (noteType == null || noteType == "")
			return 0;

		var parsed = Std.parseFloat(noteType);

		if (!Math.isNaN(parsed))
			return parsed;

		return noteType;
	}

	static function discoverSongs():Array<EditorSong>
	{
		var entries:Map<String, EditorSong> = new Map();

		#if sys
		scanPhysicalSongs(entries);
		#end

		scanVirtualSongs(entries);

		var result:Array<EditorSong> = [];

		for (folder in entries.keys())
		{
			var entry = entries.get(folder);

			if (entry != null)
				result.push(entry);
		}

		result.sort(function(a:EditorSong, b:EditorSong):Int
		{
			var left = a.displayName.toLowerCase();
			var right = b.displayName.toLowerCase();

			if (left < right)
				return -1;
			if (left > right)
				return 1;

			return 0;
		});

		if (result.length == 0)
		{
			result.push({
				folder: "untitled",
				displayName: "Untitled",
				bpm: 120,
				difficulties: ["hard"],
				physicalRoot: null,
				priority: 0
			});
		}

		return result;
	}

	#if sys
	static function scanPhysicalSongs(entries:Map<String, EditorSong>):Void
	{
		var project = findProjectRoot();

		for (mod in ModManager.mods)
		{
			if (mod.error != null || !ModManager.isActive(mod.id))
				continue;

			for (song in mod.songs)
			{
				var sourceRoot = project == null ? null : '$project/mods/${mod.folder}/songs/$song';
				var root = sourceRoot != null && fileExists('$sourceRoot/meta.json') ? sourceRoot : '${mod.path}/songs/$song';
				var priority = sourceRoot != null && root == sourceRoot ? 4 : 2;

				if (fileExists('$root/meta.json'))
					addSong(entries, makeSong(song, root, priority));
			}
		}

		if (project != null)
			scanSongsDirectory(entries, '$project/assets/songs', 3);

		scanSongsDirectory(entries, "assets/songs", 1);

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "")
			scanSongsDirectory(entries, '$applicationDirectory/assets/songs', 1);
	}

	static function scanSongsDirectory(entries:Map<String, EditorSong>, root:String, priority:Int):Void
	{
		try
		{
			if (!FileSystem.exists(root) || !FileSystem.isDirectory(root))
				return;

			for (folder in FileSystem.readDirectory(root))
			{
				var path = '$root/$folder';

				if (FileSystem.isDirectory(path) && fileExists('$path/meta.json'))
					addSong(entries, makeSong(folder, path, priority));
			}
		}
		catch (error:Dynamic) {}
	}

	static function findProjectRoot():String
	{
		var starts:Array<String> = [];
		var cwd = Sys.getCwd();

		if (cwd != null && cwd != "")
			starts.push(cwd);

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "" && starts.indexOf(applicationDirectory) < 0)
			starts.push(applicationDirectory);

		for (start in starts)
		{
			var path = normalizePath(start);

			for (i in 0...6)
			{
				if (fileExists('$path/Project.xml') && FileSystem.exists('$path/mods'))
					return path;

				var parent = normalizePath(haxe.io.Path.directory(path));

				if (parent == null || parent == "" || parent == path)
					break;

				path = parent;
			}
		}

		return null;
	}

	static function normalizePath(path:String):String
	{
		if (path == null)
			return null;

		return path.split("\\").join("/");
	}
	#end

	static function scanVirtualSongs(entries:Map<String, EditorSong>):Void
	{
		var assets:Array<String>;

		try
		{
			assets = Assets.list();
		}
		catch (error:Dynamic)
		{
			return;
		}

		for (asset in assets)
		{
			if (asset.indexOf(SONG_ROOT) != 0 || !StringTools.endsWith(asset, "/meta.json"))
				continue;

			var rest = asset.substr(SONG_ROOT.length);
			var folder = rest.substr(0, rest.length - "/meta.json".length);

			if (folder == "" || folder.indexOf("/") >= 0)
				continue;

			if (!ModManager.isSongAvailable(folder))
				continue;

			addSong(entries, makeSong(folder, null, 0));
		}
	}

	static function makeSong(folder:String, physicalRoot:String, priority:Int):EditorSong
	{
		var metaText = physicalRoot == null ? null : readFileText('$physicalRoot/meta.json');

		if (metaText == null)
			metaText = readAssetText('$SONG_ROOT$folder/meta.json');

		var meta = parseMeta(metaText, folder, 120);
		var difficulties = meta.difficulties;

		#if sys
		if (physicalRoot != null)
			addPhysicalDifficulties(difficulties, '$physicalRoot/charts');
		#end

		return {
			folder: folder,
			displayName: meta.displayName,
			bpm: meta.bpm,
			difficulties: difficulties,
			physicalRoot: physicalRoot,
			priority: priority
		};
	}

	static function addSong(entries:Map<String, EditorSong>, song:EditorSong):Void
	{
		if (song == null)
			return;

		var existing = entries.get(song.folder);

		if (existing == null)
		{
			entries.set(song.folder, song);
			return;
		}

		if (song.priority > existing.priority || (existing.physicalRoot == null && song.physicalRoot != null))
		{
			existing.physicalRoot = song.physicalRoot;
			existing.priority = song.priority;
		}

		if (song.displayName != song.folder && (existing.displayName == existing.folder || existing.displayName == ""))
			existing.displayName = song.displayName;

		if (song.bpm > 0)
			existing.bpm = song.bpm;

		for (difficulty in song.difficulties)
		{
			if (!existing.difficulties.contains(difficulty))
				existing.difficulties.push(difficulty);
		}
	}

	static function parseMeta(text:String, fallbackName:String, fallbackBpm:Float):MetaInfo
	{
		var info:MetaInfo = {displayName: fallbackName, bpm: fallbackBpm, difficulties: ["hard"]};

		if (text == null)
			return info;

		try
		{
			var json:Dynamic = haxe.Json.parse(stripBom(text));

			if (json == null)
				return info;

			var rawName = Reflect.field(json, "displayName");

			if (rawName != null && Std.string(rawName) != "")
				info.displayName = Std.string(rawName);

			var rawBpm = Reflect.field(json, "bpm");

			if (rawBpm != null)
			{
				var parsed = Std.parseFloat(Std.string(rawBpm));

				if (!Math.isNaN(parsed) && parsed > 0)
					info.bpm = parsed;
			}

			var rawDifficulties = Reflect.field(json, "difficulties");

			if (Std.isOfType(rawDifficulties, Array))
			{
				var values:Array<Dynamic> = cast rawDifficulties;
				var difficulties:Array<String> = [];

				for (value in values)
				{
					if (value == null)
						continue;

					var difficulty = StringTools.trim(Std.string(value)).toLowerCase();

					if (difficulty != "" && !difficulties.contains(difficulty))
						difficulties.push(difficulty);
				}

				if (difficulties.length > 0)
					info.difficulties = difficulties;
			}
		}
		catch (error:Dynamic) {}

		return info;
	}

	#if sys
	static function addPhysicalDifficulties(difficulties:Array<String>, chartsRoot:String):Void
	{
		try
		{
			if (!FileSystem.exists(chartsRoot) || !FileSystem.isDirectory(chartsRoot))
				return;

			for (file in FileSystem.readDirectory(chartsRoot))
			{
				if (!StringTools.endsWith(file.toLowerCase(), ".json"))
					continue;

				var difficulty = stripExtension(file).toLowerCase();

				if (difficulty != "" && !difficulties.contains(difficulty))
					difficulties.push(difficulty);
			}
		}
		catch (error:Dynamic) {}
	}
	#end

	static function preferredDifficulty(song:EditorSong):Int
	{
		if (song == null || song.difficulties.length == 0)
			return 0;

		for (i in 0...song.difficulties.length)
		{
			var index = song.difficulties.length - 1 - i;

			if (chartFileExists(song, song.difficulties[index]))
				return index;
		}

		return song.difficulties.length - 1;
	}

	static function chartFileExists(song:EditorSong, difficulty:String):Bool
	{
		if (song == null)
			return false;

		if (fileExists(physicalChartPath(song, difficulty)))
			return true;

		return assetExists('$SONG_ROOT${song.folder}/charts/$difficulty.json');
	}

	function currentSong():EditorSong
	{
		return selectedSong >= 0 && selectedSong < songs.length ? songs[selectedSong] : null;
	}

	function currentDifficulty():String
	{
		var song = currentSong();

		if (song == null || song.difficulties.length == 0)
			return "hard";

		return song.difficulties[wrapIndex(selectedDifficulty, song.difficulties.length)];
	}

	static function physicalChartPath(song:EditorSong, difficulty:String):String
	{
		if (song == null)
			return null;

		var root = song.physicalRoot;

		if (root == null)
			root = '$SONG_ROOT${song.folder}';

		return '$root/charts/$difficulty.json';
	}

	static function physicalMetaPath(song:EditorSong):String
	{
		if (song == null)
			return null;

		var root = song.physicalRoot;

		if (root == null)
			root = '$SONG_ROOT${song.folder}';

		return '$root/meta.json';
	}

	function addRect(x:Float, y:Float, width:Float, height:Float, color:Int):FlxSprite
	{
		var sprite = new FlxSprite(x, y);
		sprite.makeGraphic(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), color);
		add(sprite);
		return sprite;
	}

	static inline function laneCenter(lane:Int, isPlayer:Bool):Float
	{
		var start = isPlayer ? PLAYER_X : GRID_X;
		return start + lane * LANE_WIDTH + LANE_WIDTH * 0.5;
	}

	inline function scrollSpeed():Float
	{
		return chartData != null && chartData.speed > 0 ? chartData.speed : 1;
	}

	inline function pixelsPerMs():Float
	{
		return PIXELS_PER_MS * scrollSpeed();
	}

	inline function timeToY(time:Float):Float
	{
		return PLAYHEAD_Y + (time - chartTime) * pixelsPerMs();
	}

	inline function yToTime(y:Float):Float
	{
		return chartTime + (y - PLAYHEAD_Y) / pixelsPerMs();
	}

	inline function bpm():Float
	{
		return chartData != null && chartData.bpm > 0 ? chartData.bpm : 120;
	}

	inline function beatMs():Float
	{
		return 60000.0 / bpm();
	}

	inline function snapMs():Float
	{
		return beatMs() / SNAP_DIVISIONS[snapIndex];
	}

	function snapTime(time:Float):Float
	{
		var step = snapMs();

		if (step <= 0)
			return Math.max(0, time);

		return Math.max(0, Math.round(time / step) * step);
	}

	static function noteFrameName(direction:Int):String
	{
		return switch (direction)
		{
			case 0: "noteLEFT0000";
			case 1: "noteDOWN0000";
			case 2: "noteUP0000";
			case 3: "noteRIGHT0000";
			default: "noteLEFT0000";
		}
	}

	static function noteColor(direction:Int):Int
	{
		return switch (direction)
		{
			case 0: 0xFFC24B99;
			case 1: 0xFF00CFFF;
			case 2: 0xFF12FA05;
			case 3: 0xFFF9393F;
			default: FlxColor.WHITE;
		}
	}

	static function formatTime(ms:Float):String
	{
		var total = Std.int(Math.max(0, ms));
		var minutes = Std.int(total / 60000);
		var seconds = Std.int((total % 60000) / 1000);
		var millis = total % 1000;
		return '${pad2(minutes)}:${pad2(seconds)}.${pad3(millis)}';
	}

	static function pad2(value:Int):String
	{
		return (value < 10 ? "0" : "") + value;
	}

	static function pad3(value:Int):String
	{
		return (value < 10 ? "00" : (value < 100 ? "0" : "")) + value;
	}

	static function formatNumber(value:Float):String
	{
		var rounded = Math.round(value * 100) / 100;
		return Std.string(rounded);
	}

	static inline function clamp(value:Float, min:Float, max:Float):Float
	{
		return value < min ? min : (value > max ? max : value);
	}

	static function wrapIndex(index:Int, length:Int):Int
	{
		if (length <= 0)
			return 0;

		return ((index % length) + length) % length;
	}

	static function compareNotes(a:ChartNote, b:ChartNote):Int
	{
		if (a.time < b.time)
			return -1;
		if (a.time > b.time)
			return 1;
		if (a.rawData < b.rawData)
			return -1;
		if (a.rawData > b.rawData)
			return 1;

		return 0;
	}

	static function compareEvents(a:ChartEvent, b:ChartEvent):Int
	{
		if (a.time < b.time)
			return -1;
		if (a.time > b.time)
			return 1;

		return 0;
	}

	static function compareDynamicNotes(a:Dynamic, b:Dynamic):Int
	{
		var at = readFloat(Reflect.field(a, "time"), 0);
		var bt = readFloat(Reflect.field(b, "time"), 0);

		if (at < bt)
			return -1;
		if (at > bt)
			return 1;

		return 0;
	}

	static function compareNoteArrays(a:Array<Dynamic>, b:Array<Dynamic>):Int
	{
		var at = readFloat(a[0], 0);
		var bt = readFloat(b[0], 0);

		if (at < bt)
			return -1;
		if (at > bt)
			return 1;

		return 0;
	}

	static function readFloat(value:Dynamic, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function readInt(value:Dynamic, fallback:Int):Int
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseInt(Std.string(value));
		return parsed == null ? fallback : parsed;
	}

	static function readBool(value:Dynamic, fallback:Bool):Bool
	{
		if (value == null)
			return fallback;

		if (Std.isOfType(value, Bool))
			return cast value;

		var text = Std.string(value).toLowerCase();

		if (text == "true" || text == "1")
			return true;
		if (text == "false" || text == "0")
			return false;

		return fallback;
	}

	static function readString(value:Dynamic, fallback:String):String
	{
		return value == null ? fallback : Std.string(value);
	}

	static function stripExtension(file:String):String
	{
		var dot = file.lastIndexOf(".");
		return dot < 0 ? file : file.substr(0, dot);
	}

	static function createStrumLine(position:String):Dynamic
	{
		return {
			keyCount: 4,
			notes: [],
			position: position,
			strumScale: 1,
			visible: true,
			scrollSpeed: 1,
			strumSpacing: 0,
			type: "strumLine",
			characters: [position == "bf" ? "bf" : "dad"],
			strumPos: {x: 0, y: 0},
			vocalsSuffix: ""
		};
	}

	static function createDefaultStrumLines():Array<Dynamic>
	{
		var lines:Array<Dynamic> = [];
		lines.push(createStrumLine("dad"));
		lines.push(createStrumLine("bf"));
		return lines;
	}

	static function findStrumLine(lines:Array<Dynamic>, player:Bool):Dynamic
	{
		for (line in lines)
		{
			var position = linePosition(line);

			if (player && (position == "bf" || position == "boyfriend" || position == "player"))
				return line;
			if (!player && (position == "dad" || position == "opponent"))
				return line;
		}

		return null;
	}

	static function linePosition(line:Dynamic):String
	{
		return readString(Reflect.field(line, "position"), "").toLowerCase();
	}

	static function nestedSong(root:Dynamic):Dynamic
	{
		if (root == null)
			return null;

		var nested = Reflect.field(root, "song");

		if (nested != null && !Std.isOfType(nested, String) && Reflect.isObject(nested))
			return nested;

		return root;
	}

	static function readFileText(path:String):String
	{
		#if sys
		try
		{
			if (path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path))
				return File.getContent(path);
		}
		catch (error:Dynamic) {}
		#end

		return null;
	}

	static function readAssetText(path:String):String
	{
		try
		{
			if (path != null && Assets.exists(path))
				return Assets.getText(path);
		}
		catch (error:Dynamic) {}

		return null;
	}

	static function fileExists(path:String):Bool
	{
		#if sys
		try
		{
			return path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path);
		}
		catch (error:Dynamic) {}
		#end

		return false;
	}

	static function assetExists(path:String):Bool
	{
		try
		{
			return path != null && Assets.exists(path);
		}
		catch (error:Dynamic) {}

		return false;
	}

	function setStatus(message:String, color:Int):Void
	{
		if (statusText == null)
			return;

		statusText.text = message;
		statusText.color = color;
	}
}
