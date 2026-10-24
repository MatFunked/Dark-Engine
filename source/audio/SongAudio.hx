package audio;

import flixel.FlxG;
import flixel.sound.FlxSound;

class SongAudio
{
	static inline var INST_VOLUME:Float = 1.0;
	static inline var VOICE_VOLUME:Float = 1.0;

	public var inst(default, null):FlxSound;
	public var voicesGroup(default, null):Array<FlxSound> = [];
	public var voicePaths(default, null):Array<String> = [];
	public var syncThreshold:Float = 25;

	var voiceAssignments:Map<Int, Int> = new Map();
	var lineMuted:Map<Int, Bool> = new Map();
	var started:Bool = false;
	var finished:Bool = false;

	public function new() {}

	public function loadSong(instPath:String, voicePaths:Array<String>, ?voiceAssignments:Map<Int, Int>):Void
	{
		destroy();

		inst = FlxG.sound.load(instPath, INST_VOLUME, false, null, false, false);

		if (inst == null)
			throw "Could not load instrumental track";

		inst.onComplete = markFinished;

		this.voicePaths = voicePaths == null ? [] : voicePaths.copy();
		this.voiceAssignments = voiceAssignments == null ? new Map() : voiceAssignments;

		for (path in this.voicePaths)
		{
			var sound = FlxG.sound.load(path, VOICE_VOLUME, false, null, false, false);

			if (sound == null)
				continue;

			sound.onComplete = markFinished;
			voicesGroup.push(sound);
		}

		refreshVolumes();
	}

	public function play():Void
	{
		if (inst == null)
			return;

		finished = false;
		lineMuted = new Map();
		inst.play();

		for (sound in voicesGroup)
		{
			sound.play();
			sound.time = inst.time;
		}

		refreshVolumes();
		started = true;
	}

	public function setStrumLineMuted(strumLineIndex:Int, muted:Bool):Void
	{
		lineMuted.set(strumLineIndex, muted);
		refreshVolumes();
	}

	public function isStrumLineMuted(strumLineIndex:Int):Bool
	{
		return lineMuted.exists(strumLineIndex) && lineMuted.get(strumLineIndex);
	}

	public function getVoiceChannel(strumLineIndex:Int):Int
	{
		return voiceAssignments.exists(strumLineIndex) ? voiceAssignments.get(strumLineIndex) : -1;
	}

	public function update():Void
	{
		if (!started || inst == null || !inst.playing)
			return;

		syncTo(inst.time);
	}

	public function pause():Void
	{
		pauseSound(inst);

		for (sound in voicesGroup)
			pauseSound(sound);
	}

	public function resume():Void
	{
		resumeSound(inst);

		for (sound in voicesGroup)
			resumeSound(sound);
	}

	public function stop():Void
	{
		started = false;
		finished = false;
		lineMuted = new Map();
		stopSound(inst);

		for (sound in voicesGroup)
			stopSound(sound);
	}

	public function destroy():Void
	{
		stop();

		if (inst != null)
		{
			inst.destroy();
			inst = null;
		}

		for (sound in voicesGroup)
		{
			if (sound != null)
				sound.destroy();
		}

		voicesGroup = [];
		voicePaths = [];
		voiceAssignments = new Map();
		lineMuted = new Map();
	}

	public function getTime():Float
	{
		return inst == null ? 0 : inst.time;
	}

	public function isPlaying():Bool
	{
		return inst != null && inst.playing;
	}

	public function isFinished():Bool
	{
		return started && finished;
	}

	function markFinished():Void
	{
		finished = true;
	}

	function syncTo(time:Float):Void
	{
		for (sound in voicesGroup)
			syncTrack(sound, time);
	}

	function syncTrack(track:FlxSound, time:Float):Void
	{
		if (track == null || !track.playing)
			return;

		if (Math.abs(track.time - time) > syncThreshold)
			track.time = time;
	}

	function refreshVolumes():Void
	{
		if (voicesGroup.length == 0)
			return;

		var hasAssignments = false;

		for (_ in voiceAssignments.keys())
		{
			hasAssignments = true;
			break;
		}

		if (hasAssignments)
		{
			for (channel in 0...voicesGroup.length)
			{
				var audible = false;

				for (lineIndex in voiceAssignments.keys())
				{
					if (voiceAssignments.get(lineIndex) != channel)
						continue;

					if (!lineMuted.exists(lineIndex) || !lineMuted.get(lineIndex))
					{
						audible = true;
						break;
					}
				}

				voicesGroup[channel].volume = audible ? VOICE_VOLUME : 0;
			}
		}
		else
		{
			for (sound in voicesGroup)
				sound.volume = VOICE_VOLUME;
		}
	}

	inline function pauseSound(sound:FlxSound):Void
	{
		if (sound != null && sound.playing)
			sound.pause();
	}

	inline function resumeSound(sound:FlxSound):Void
	{
		if (sound != null)
			sound.resume();
	}

	inline function stopSound(sound:FlxSound):Void
	{
		if (sound != null && sound.exists)
			sound.stop();
	}
}
