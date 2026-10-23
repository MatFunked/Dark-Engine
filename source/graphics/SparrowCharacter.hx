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

private typedef CharacterOffset =
{
	var x:Float;
	var y:Float;
}

class SparrowCharacter extends FlxSprite
{
	static inline var CHARACTER_SCALE:Float = 0.7;
	static inline var SING_HOLD_TIME:Float = 0.36;

	public var requestedCharacterName(default, null):String;
	public var characterName(default, null):String;
	public var isPlayer(default, null):Bool;
	public var isPlaceholder(default, null):Bool = false;
	public var usedFallback(default, null):Bool = false;

	var animations:Map<String, CharacterAnimation> = [];
	var animationOffsets:Map<String, CharacterOffset> = [];
	var idleAnimation:String = "idle";
	var singTimer:Float = 0;
	var baseOffsetX:Float = 0;
	var baseOffsetY:Float = 0;
	var currentAnimation:String = null;

	public function new(characterName:String, isPlayer:Bool)
	{
		super();
		this.requestedCharacterName = characterName;
		this.characterName = characterName;
		this.isPlayer = isPlayer;

		if (BrokenCharacter.isRequested(characterName))
		{
			useBroken();
			return;
		}

		loadCharacter(characterName);
	}

	public function sing(direction:NoteDirection):Void
	{
		if (isPlaceholder)
			return;

		var name = singAnimationName(direction);

		if (!animation.exists(name))
			name = baseSingAnimationName(direction);

		if (!playAnimation(name, true))
			return;

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
		captureBaseOffset();
		applyCurrentOffset();
		x = centerX - width * 0.5;
		y = topY;
	}

	public function playAnimation(name:String, force:Bool = false):Bool
	{
		if (isPlaceholder || name == null || !animation.exists(name))
			return false;

		animation.play(name, force);
		currentAnimation = name;
		applyCurrentOffset();

		return true;
	}

	function loadCharacter(characterName:String):Void
	{
		var metadata = loadMetadata(characterName);

		if (metadata == null || metadata.nodeName != "character")
		{
			useBroken('missing or invalid character XML for "$characterName"');
			return;
		}

		var flipValue = metadata.get("flipX");
		var antialiasingValue = metadata.get("antialiasing");

		flipX = flipValue == "true";

		if (antialiasingValue == "false")
			antialiasing = false;

		loadDefaultAnimations(characterName);
		loadMetadataAnimations(metadata);

		var frames = SparrowLoader.load('assets/images/characters/$characterName.png', 'assets/images/characters/$characterName.xml');

		if (frames == null)
		{
			useBroken('missing or invalid character atlas for "$characterName"');
			return;
		}

		this.frames = frames;
		scale.set(CHARACTER_SCALE, CHARACTER_SCALE);
		updateHitbox();
		captureBaseOffset();
		buildAnimations();

		if (!animation.exists(idleAnimation))
		{
			useBroken('missing idle animation for "$characterName"');
			return;
		}

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
			animationOffsets.set(name, {x: readOffset(node.get("x")), y: readOffset(node.get("y"))});
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
		if (animation.curAnim == null || animation.curAnim.name != idleAnimation)
			playAnimation(idleAnimation);
	}

	function captureBaseOffset():Void
	{
		baseOffsetX = offset.x;
		baseOffsetY = offset.y;
	}

	function applyCurrentOffset():Void
	{
		if (isPlaceholder || currentAnimation == null)
			return;

		var data = animationOffsets.get(currentAnimation);
		offset.set(baseOffsetX + (data == null ? 0 : data.x), baseOffsetY + (data == null ? 0 : data.y));
	}

	static function readOffset(value:String):Float
	{
		if (value == null)
			return 0;

		var parsed = Std.parseFloat(value);
		return Math.isNaN(parsed) ? 0 : parsed;
	}

	function useBroken(?reason:String):Void
	{
		usedFallback = requestedCharacterName != null && StringTools.trim(requestedCharacterName).toLowerCase() != BrokenCharacter.NAME;
		characterName = BrokenCharacter.NAME;
		isPlaceholder = true;
		singTimer = 0;
		currentAnimation = null;
		baseOffsetX = 0;
		baseOffsetY = 0;
		flipX = false;
		scale.set(1, 1);
		animation.destroyAnimations();
		animations.clear();
		animationOffsets.clear();
		BrokenCharacter.apply(this);

		if (reason != null)
			FlxG.log.warn('Using broken character for "$requestedCharacterName": $reason');
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
