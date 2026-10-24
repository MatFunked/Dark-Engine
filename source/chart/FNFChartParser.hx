package chart;

import input.NoteDirection;

class FNFChartParser
{
	public static function parse(json:String, ?timeMode:ChartTimeMode, ?fallbackBpm:Float):FNFChart
	{
		if (timeMode == null)
			timeMode = ChartTimeMode.AbsoluteMs;

		if (json != null && json.length > 0 && json.charCodeAt(0) == 0xFEFF)
			json = json.substr(1);

		var root:Dynamic;

		try
		{
			root = haxe.Json.parse(json);
		}
		catch (error:Dynamic)
		{
			throw 'Invalid FNF chart JSON: $error';
		}

		if (root == null)
			throw "Invalid FNF chart: empty root";

		var nestedSong:Dynamic = Reflect.field(root, "song");
		var songData:Dynamic = (nestedSong != null && !Std.isOfType(nestedSong, String)) ? nestedSong : root;

		var rawStrumLines:Dynamic = Reflect.field(songData, "strumLines");

		if (!Std.isOfType(rawStrumLines, Array))
			rawStrumLines = Reflect.field(root, "strumLines");

		if (Std.isOfType(rawStrumLines, Array))
			return parseStrumLines(root, songData, cast rawStrumLines, fallbackBpm == null ? 0 : fallbackBpm);

		var rawSections:Dynamic = Reflect.field(songData, "notes");

		if (!Std.isOfType(rawSections, Array))
			rawSections = Reflect.field(songData, "sections");
		if (!Std.isOfType(rawSections, Array))
			rawSections = Reflect.field(root, "sections");
		if (!Std.isOfType(rawSections, Array))
			throw "Invalid FNF chart: missing sections array";

		var chart = new FNFChart();
		chart.songName = stringValue(Reflect.field(songData, "song"), "Untitled");
		chart.bpm = numberValue(Reflect.field(songData, "bpm"), numberValue(Reflect.field(root, "bpm"), fallbackBpm == null ? 0 : fallbackBpm));

		if (chart.bpm <= 0)
			throw "Invalid FNF chart: BPM must be greater than 0";

		chart.speed = numberValue(Reflect.field(songData, "speed"), 1);
		chart.player1 = stringValue(Reflect.field(songData, "player1"), "bf");
		chart.player2 = stringValue(Reflect.field(songData, "player2"), "dad");
		chart.playerCharacter = chart.player1;
		chart.opponentCharacter = chart.player2;
		chart.gfVersion = stringValue(Reflect.field(songData, "gfVersion"), "gf");
		chart.stage = stringValue(Reflect.field(songData, "stage"), "stage");
		chart.needsVoices = boolValue(Reflect.field(songData, "needsVoices"), true);
		chart.offset = numberValue(Reflect.field(songData, "offset"), 0);

		var opponentLine = new StrumLineData(0, "dad", 4, [chart.opponentCharacter]);
		var playerLine = new StrumLineData(1, "boyfriend", 4, [chart.playerCharacter]);
		chart.strumLines.push(opponentLine);
		chart.strumLines.push(playerLine);

		var sectionsData:Array<Dynamic> = cast rawSections;
		var currentBpm = chart.bpm;
		var currentTime = 0.0;
		var initialBpmChange = new BpmChange(0, currentBpm, 0);
		chart.bpmChanges.push(initialBpmChange);

		for (i in 0...sectionsData.length)
		{
			var rawSection:Dynamic = sectionsData[i];

			if (rawSection == null)
				continue;

			var mustHitSection = boolValue(Reflect.field(rawSection, "mustHitSection"), false);
			var changeBpm = boolValue(Reflect.field(rawSection, "changeBPM"), false);
			var sectionBpm = numberValue(Reflect.field(rawSection, "bpm"), currentBpm);

			if (changeBpm && sectionBpm > 0 && sectionBpm != currentBpm)
			{
				currentBpm = sectionBpm;

				if (i == 0)
					initialBpmChange.bpm = currentBpm;
				else
					chart.bpmChanges.push(new BpmChange(currentTime, currentBpm, i));
			}

			var lengthInSteps = intValue(Reflect.field(rawSection, "lengthInSteps"), 16);

			if (lengthInSteps <= 0)
				lengthInSteps = 16;

			var beats = numberValue(Reflect.field(rawSection, "sectionBeats"), lengthInSteps / 4.0);

			if (beats <= 0)
				beats = lengthInSteps / 4.0;

			var endTime = currentTime + (60000.0 / currentBpm) * beats;
			var section = new ChartSection(i, currentTime, endTime, currentBpm, mustHitSection, changeBpm);
			section.lengthInSteps = lengthInSteps;
			section.beats = beats;
			section.altAnim = boolValue(Reflect.field(rawSection, "altAnim"), false);
			section.gfSection = boolValue(Reflect.field(rawSection, "gfSection"), false);

			var rawNotes:Dynamic = Reflect.field(rawSection, "sectionNotes");

			if (Std.isOfType(rawNotes, Array))
			{
				var sectionNotes:Array<Dynamic> = cast rawNotes;

				for (rawNote in sectionNotes)
				{
					if (!Std.isOfType(rawNote, Array))
						continue;

					var values:Array<Dynamic> = cast rawNote;

					if (values.length < 2)
						continue;

					var rawTime = numberValue(values[0], 0);
					var rawData = intValue(values[1], 0);
					var sustainLength = Math.max(0, numberValue(values[2], 0));
					var noteType = "";

					if (values.length > 3 && values[3] != null)
					{
						if (Std.isOfType(values[3], String))
							noteType = cast values[3];
						else if (Std.isOfType(values[3], Int) || Std.isOfType(values[3], Float))
							noteType = Std.string(values[3]);
					}

					var lane = rawData % 4;

					if (lane < 0)
						lane += 4;

					var direction:NoteDirection = lane;
					var isPlayer = mustHitSection == (rawData < 4);
					var lineIndex = isPlayer ? playerLine.index : opponentLine.index;
					var line = chart.strumLines[lineIndex];
					var noteTime = convertTime(rawTime, currentTime, currentBpm, timeMode);
					var note = new ChartNote(noteTime, direction, rawData, sustainLength, isPlayer, noteType, i, lineIndex, lane);
					section.notes.push(note);
					chart.notes.push(note);
					line.notes.push(note);
				}
			}

			section.notes.sort(compareNotes);
			chart.sections.push(section);
			currentTime = endTime;
		}

		chart.notes.sort(compareNotes);

		for (line in chart.strumLines)
			line.notes.sort(compareNotes);

		chart.events = parseEvents(root, songData);
		buildCameraSections(chart);
		return chart;
	}

	static function parseEvents(root:Dynamic, songData:Dynamic):Array<ChartEvent>
	{
		var rawEvents:Dynamic = Reflect.field(root, "events");

		if (!Std.isOfType(rawEvents, Array))
			rawEvents = Reflect.field(songData, "events");

		if (!Std.isOfType(rawEvents, Array))
			return [];

		var events:Array<ChartEvent> = [];

		for (rawEvent in cast(rawEvents, Array<Dynamic>))
		{
			if (rawEvent == null)
				continue;

			var name = stringValue(Reflect.field(rawEvent, "name"), "");

			if (name == "")
				continue;

			var rawParams:Dynamic = Reflect.field(rawEvent, "params");
			var params:Array<Dynamic> = Std.isOfType(rawParams, Array) ? cast rawParams : [];
			events.push(new ChartEvent(name, numberValue(Reflect.field(rawEvent, "time"), 0), params));
		}

		events.sort(compareEvents);
		return events;
	}

	static function buildCameraSections(chart:FNFChart):Void
	{
		var cameraEvents:Array<{time:Float, mustHit:Bool}> = [];

		for (event in chart.events)
		{
			if (event.name != "Camera Movement")
				continue;

			var values = event.params;

			if (values.length == 0)
				continue;

			var rawSide = values[0];
			var side = -1.0;

			if (Std.isOfType(rawSide, Bool))
				side = (cast rawSide : Bool) ? 1 : 0;
			else
				side = numberValue(rawSide, -1);

			if (side < 0)
				continue;

			cameraEvents.push({time: event.time, mustHit: side >= 1});
		}

		if (cameraEvents.length == 0)
			return;

		cameraEvents.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

		var chartEnd = 0.0;

		for (note in chart.notes)
			chartEnd = Math.max(chartEnd, note.time + note.sustainLength);

		var beatDuration = chart.bpm > 0 ? 60000 / chart.bpm : 0;
		var index = 0;

		if (cameraEvents[0].time > 0)
		{
			var first = new ChartSection(index, 0, cameraEvents[0].time, chart.bpm, false, false);
			first.beats = beatDuration > 0 ? first.endTime / beatDuration : 0;
			first.lengthInSteps = Std.int(first.beats * 4);
			chart.sections.push(first);
			index++;
		}

		for (i in 0...cameraEvents.length)
		{
			var start = cameraEvents[i].time;
			var end = i + 1 < cameraEvents.length ? cameraEvents[i + 1].time : Math.max(chartEnd, start + beatDuration * 4);

			if (end <= start)
				continue;

			var section = new ChartSection(index, start, end, chart.bpm, cameraEvents[i].mustHit, false);
			section.beats = beatDuration > 0 ? (end - start) / beatDuration : 0;
			section.lengthInSteps = Std.int(section.beats * 4);
			chart.sections.push(section);
			index++;
		}
	}

	static function parseStrumLines(root:Dynamic, songData:Dynamic, rawStrumLines:Array<Dynamic>, fallbackBpm:Float):FNFChart
	{
		var chart = new FNFChart();
		chart.songName = stringValue(Reflect.field(songData, "songName"), stringValue(Reflect.field(songData, "song"), "Untitled"));
		chart.bpm = numberValue(Reflect.field(songData, "bpm"), numberValue(Reflect.field(root, "bpm"), fallbackBpm));
		chart.speed = numberValue(Reflect.field(songData, "scrollSpeed"), numberValue(Reflect.field(songData, "speed"), 1));
		chart.stage = stringValue(Reflect.field(songData, "stage"), "stage");
		chart.needsVoices = boolValue(Reflect.field(songData, "needsVoices"), true);
		chart.offset = numberValue(Reflect.field(songData, "offset"), 0);

		if (chart.bpm > 0)
			chart.bpmChanges.push(new BpmChange(0, chart.bpm, 0));

		var playerCharacterSet = false;
		var opponentCharacterSet = false;
		var playerSuffixSet = false;
		var opponentSuffixSet = false;

		for (i in 0...rawStrumLines.length)
		{
			var strumLine:Dynamic = rawStrumLines[i];

			if (strumLine == null)
				continue;

			var position = StrumLineData.normalizePosition(stringValue(Reflect.field(strumLine, "position"), ""));

			if (!StrumLineData.isPlayerPosition(position) && !StrumLineData.isOpponentPosition(position))
				position = i == 0 ? "dad" : "player";

			var keyCount = intValue(Reflect.field(strumLine, "keyCount"), 4);

			if (keyCount <= 0)
				keyCount = 4;

			var vocalsSuffix = stringValue(Reflect.field(strumLine, "vocalsSuffix"), "");
			var characters:Array<String> = [];

			var rawCharacters:Dynamic = Reflect.field(strumLine, "characters");

			if (Std.isOfType(rawCharacters, Array))
			{
				for (character in cast(rawCharacters, Array<Dynamic>))
				{
					if (character != null && Std.string(character) != "")
						characters.push(Std.string(character));
				}
			}

			var line = new StrumLineData(i, position, keyCount, characters, vocalsSuffix);
			line.strumLinePos = numberValue(Reflect.field(strumLine, "strumLinePos"), -1);
			line.strumScale = numberValue(Reflect.field(strumLine, "strumScale"), 1);
			line.visible = boolValue(Reflect.field(strumLine, "visible"), true);
			line.scrollSpeed = numberValue(Reflect.field(strumLine, "scrollSpeed"), 1);

			var rawKeys:Dynamic = Reflect.field(strumLine, "keys");

			if (!Std.isOfType(rawKeys, Array))
				rawKeys = Reflect.field(strumLine, "keyBindings");

			if (Std.isOfType(rawKeys, Array))
			{
				for (key in cast(rawKeys, Array<Dynamic>))
				{
					if (key != null)
						line.keys.push(Std.string(key));
				}
			}

			chart.strumLines.push(line);

			if (line.isPlayer && !playerCharacterSet)
			{
				chart.playerCharacter = line.primaryCharacter();
				chart.player1 = chart.playerCharacter;
				playerCharacterSet = true;
			}
			else if (line.isOpponent && !opponentCharacterSet)
			{
				chart.opponentCharacter = line.primaryCharacter();
				chart.player2 = chart.opponentCharacter;
				opponentCharacterSet = true;
			}

			if (line.isPlayer && !playerSuffixSet)
			{
				chart.playerVocalsSuffix = line.vocalsSuffix;
				playerSuffixSet = true;
			}
			else if (line.isOpponent && !opponentSuffixSet)
			{
				chart.opponentVocalsSuffix = line.vocalsSuffix;
				opponentSuffixSet = true;
			}

			var rawNotes:Dynamic = Reflect.field(strumLine, "notes");

			if (!Std.isOfType(rawNotes, Array))
				continue;

			var lineNotes:Array<Dynamic> = cast rawNotes;

			for (rawNote in lineNotes)
			{
				if (rawNote == null)
					continue;

				var lane = intValue(Reflect.field(rawNote, "id"), 0) % line.keyCount;

				if (lane < 0)
					lane += line.keyCount;

				var rawTime = numberValue(Reflect.field(rawNote, "time"), 0);
				var sustainLength = Math.max(0, numberValue(Reflect.field(rawNote, "sLen"), 0));
				var rawNoteType = Reflect.field(rawNote, "type");
				var noteType = rawNoteType == null ? "" : Std.string(rawNoteType);
				var direction:NoteDirection = cast(lane % 4, NoteDirection);
				var note = new ChartNote(rawTime, direction, lane, sustainLength, line.isPlayer, noteType, i, i, lane);
				chart.notes.push(note);
				line.notes.push(note);
			}
		}

		if (chart.strumLines.length == 0)
		{
			var fallbackOpponent = new StrumLineData(0, "dad", 4, [chart.opponentCharacter]);
			var fallbackPlayer = new StrumLineData(1, "boyfriend", 4, [chart.playerCharacter]);
			chart.strumLines.push(fallbackOpponent);
			chart.strumLines.push(fallbackPlayer);
		}

		chart.notes.sort(compareNotes);

		for (line in chart.strumLines)
			line.notes.sort(compareNotes);

		chart.events = parseEvents(root, songData);
		return chart;
	}

	static function convertTime(rawTime:Float, sectionStart:Float, bpm:Float, timeMode:ChartTimeMode):Float
	{
		return switch (timeMode)
		{
			case ChartTimeMode.AbsoluteMs: rawTime;
			case ChartTimeMode.SectionOffsetMs: sectionStart + rawTime;
			case ChartTimeMode.SectionOffsetSteps: sectionStart + rawTime * (60000.0 / bpm / 4.0);
			case ChartTimeMode.SectionOffsetBeats: sectionStart + rawTime * (60000.0 / bpm);
		};
	}

	static function compareEvents(a:ChartEvent, b:ChartEvent):Int
	{
		if (a.time < b.time)
			return -1;
		if (a.time > b.time)
			return 1;

		return 0;
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

	static function numberValue(value:Dynamic, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function intValue(value:Dynamic, fallback:Int):Int
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseInt(Std.string(value));
		return parsed == null ? fallback : parsed;
	}

	static function boolValue(value:Dynamic, fallback:Bool):Bool
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

	static function stringValue(value:Dynamic, fallback:String):String
	{
		return value == null ? fallback : Std.string(value);
	}
}
