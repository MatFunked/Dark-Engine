package graphics;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import input.NoteDirection;
import openfl.utils.Assets;

private typedef CharacterAnimation =
{
	var prefix:String;
	var frameRate:Float;
	var looped:Bool;
}

class SparrowCharacter extends FlxSprite
{
	static inline var CHARACTER_SCALE:Float = 0.7;
	static inline var SING_HOLD_TIME:Float = 0.36;

	public var characterName(default, null):String;
	public var isPlayer(default, null):Bool;
	public var isPlaceholder(default, null):Bool = false;

	var animations:Map<String, CharacterAnimation> = [];
	var idleAnimation:String = "idle";
	var singTimer:Float = 0;

	public function new(characterName:String, isPlayer:Bool)
	{
		super();
		this.characterName = characterName;
		this.isPlayer = isPlayer;
		loadCharacter(characterName);
	}

	public function sing(direction:NoteDirection):Void
	{
		if (isPlaceholder)
			return;

		var name = singAnimationName(direction);

		if (!animation.exists(name))
		{
			name = baseSingAnimationName(direction);

			if (!animation.exists(name))
				return;
		}

		animation.play(name, true);
		singTimer = SING_HOLD_TIME;
	}

	public function updateCharacter(elapsed:Float):Void
	{
		if (singTimer <= 0)
			return;

		singTimer -= elapsed;

		if (singTimer <= 0)
			playIdle();
	}

	public function placeAt(centerX:Float, topY:Float):Void
	{
		updateHitbox();
		x = centerX - width * 0.5;
		y = topY;
	}

	function loadCharacter(characterName:String):Void
	{
		var metadata = loadMetadata(characterName);
		var flipValue = metadata == null ? null : metadata.get("flipX");
		var antialiasingValue = metadata == null ? null : metadata.get("antialiasing");

		flipX = metadata == null ? isPlayer : flipValue == "true";

		if (antialiasingValue == "false")
			antialiasing = false;

		loadDefaultAnimations(characterName);

		if (metadata != null)
			loadMetadataAnimations(metadata);

		var frames = SparrowLoader.load('assets/images/characters/$characterName.png', 'assets/images/characters/$characterName.xml');

		if (frames == null)
		{
			isPlaceholder = true;
			FlxG.log.warn('Missing character atlas for "$characterName"; using placeholder');
			makePlaceholder();
			return;
		}

		this.frames = frames;
		scale.set(CHARACTER_SCALE, CHARACTER_SCALE);
		updateHitbox();
		buildAnimations();
		playIdle();
	}

	function loadMetadata(characterName:String):Xml
	{
		var path = 'assets/data/characters/$characterName.xml';

		if (!Assets.exists(path))
			return null;

		var text = Assets.getText(path);

		if (text == null)
			return null;

		try
		{
			var xml = Xml.parse(text);
			return xml.firstElement();
		}
		catch (error:Dynamic)
		{
			FlxG.log.warn('Invalid character metadata for "$characterName"');
			return null;
		}
	}

	function loadDefaultAnimations(characterName:String):Void
	{
		animations.set("idle", {prefix: '$characterName idle', frameRate: 24, looped: true});
		animations.set("singLEFT", {prefix: '$characterName left', frameRate: 24, looped: true});
		animations.set("singDOWN", {prefix: '$characterName down', frameRate: 24, looped: true});
		animations.set("singUP", {prefix: '$characterName up', frameRate: 24, looped: true});
		animations.set("singRIGHT", {prefix: '$characterName right', frameRate: 24, looped: true});
	}

	function loadMetadataAnimations(metadata:Xml):Void
	{
		for (node in metadata.elementsNamed("anim"))
		{
			var name = node.get("name");
			var prefix = node.get("anim");

			if (name == null || prefix == null)
				continue;

			var frameRate = 24.0;
			var rawFrameRate = node.get("fps");

			if (rawFrameRate != null)
			{
				var parsedFrameRate = Std.parseFloat(rawFrameRate);

				if (!Math.isNaN(parsedFrameRate) && parsedFrameRate > 0)
					frameRate = parsedFrameRate;
			}

			var rawLooped = node.get("loop");
			var looped = rawLooped == null || rawLooped == "true";
			animations.set(name, {prefix: prefix, frameRate: frameRate, looped: looped});
		}
	}

	function buildAnimations():Void
	{
		for (name in animations.keys())
		{
			var data = animations[name];

			if (!hasFramePrefix(data.prefix))
				continue;

			animation.addByPrefix(name, data.prefix, data.frameRate, data.looped);
		}
	}

	function hasFramePrefix(prefix:String):Bool
	{
		if (frames == null)
			return false;

		for (frame in frames.frames)
		{
			if (frame.name != null && frame.name.indexOf(prefix) == 0)
				return true;
		}

		return false;
	}

	function playIdle():Void
	{
		if (isPlaceholder || !animation.exists(idleAnimation))
			return;

		if (animation.curAnim == null || animation.curAnim.name != idleAnimation)
			animation.play(idleAnimation);
	}

	function makePlaceholder():Void
	{
		makeGraphic(180, 360, isPlayer ? 0xFF334477 : 0xFF553344);
	}

	function singAnimationName(direction:NoteDirection):String
	{
		if (!flipX)
			return baseSingAnimationName(direction);

		return switch (direction)
		{
			case LEFT: "singRIGHT";
			case DOWN: "singDOWN";
			case UP: "singUP";
			case RIGHT: "singLEFT";
		}
	}

	static function baseSingAnimationName(direction:NoteDirection):String
	{
		return switch (direction)
		{
			case LEFT: "singLEFT";
			case DOWN: "singDOWN";
			case UP: "singUP";
			case RIGHT: "singRIGHT";
		}
	}
}
