package audio;

import flixel.FlxG;
import flixel.sound.FlxSound;

class SongAudio
{
	static inline var INST_VOLUME:Float = 1.0;
	static inline var VOICE_VOLUME:Float = 1.0;

	public var inst(default, null):FlxSound;
	public var opponentVoices(default, null):FlxSound;
	public var playerVoices(default, null):FlxSound;
	public var syncThreshold:Float = 25;

	var started:Bool = false;

	public function new() {}

	public function load(instPath:String, opponentVoicesPath:String, playerVoicesPath:String):Void
	{
		inst = FlxG.sound.load(instPath, INST_VOLUME, false, null, false, false);
		opponentVoices = FlxG.sound.load(opponentVoicesPath, VOICE_VOLUME, false, null, false, false);
		playerVoices = FlxG.sound.load(playerVoicesPath, VOICE_VOLUME, false, null, false, false);

		if (inst == null || opponentVoices == null || playerVoices == null)
			throw "Could not load song audio";
	}

	public function play():Void
	{
		if (inst == null || opponentVoices == null || playerVoices == null)
			return;

		inst.play();
		opponentVoices.play();
		playerVoices.play();

		opponentVoices.time = inst.time;
		playerVoices.time = inst.time;
		started = true;
	}

	public function setPlayerVocalsMuted(muted:Bool):Void
	{
		if (playerVoices == null)
			return;

		playerVoices.volume = muted ? 0.0 : VOICE_VOLUME;
	}

	public function update():Void
	{
		if (!started || inst == null || !inst.playing)
			return;

		syncTo(inst.time);
	}

	public function stop():Void
	{
		started = false;
		stopSound(inst);
		stopSound(opponentVoices);
		stopSound(playerVoices);
	}

	public function destroy():Void
	{
		stop();
	}

	public function getTime():Float
	{
		return inst == null ? 0 : inst.time;
	}

	public function isPlaying():Bool
	{
		return inst != null && inst.playing;
	}

	function syncTo(time:Float):Void
	{
		syncTrack(opponentVoices, time);
		syncTrack(playerVoices, time);
	}

	function syncTrack(track:FlxSound, time:Float):Void
	{
		if (track == null || !track.playing)
			return;

		if (Math.abs(track.time - time) > syncThreshold)
			track.time = time;
	}

	inline function stopSound(sound:FlxSound):Void
	{
		if (sound != null && sound.exists)
			sound.stop();
	}
}
