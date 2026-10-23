package events;

import chart.ChartEvent;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class SongEventManager
{
	public static inline var FOCUS_SHIFT:Float = 0.06;
	public static inline var FOCUS_TIME:Float = 0.45;
	public static inline var DEFAULT_ZOOM_AMOUNT:Float = 0.05;
	public static inline var ZOOM_IN_TIME:Float = 0.06;
	public static inline var ZOOM_OUT_TIME:Float = 0.16;
	public static inline var DEFAULT_FLASH_TIME:Float = 0.2;
	public static inline var DEFAULT_STEPS:Float = 4;

	public var hasCameraFocusEvents(default, null):Bool = false;
	public var processedEvents(default, null):Int = 0;

	var events:Array<ChartEvent> = [];
	var nextEventIndex:Int = 0;
	var bpm:Float = 0;
	var gameCamera:FlxCamera;
	var hudCamera:FlxCamera;
	var gameBaseZoom:Float = 1;
	var hudBaseZoom:Float = 1;
	var focusTween:FlxTween;
	var zoomTween:FlxTween;

	public function new(events:Array<ChartEvent>, bpm:Float, gameCamera:FlxCamera, ?hudCamera:FlxCamera)
	{
		this.events = events == null ? [] : events.copy();
		this.events.sort(compareEvents);
		this.bpm = bpm;
		this.gameCamera = gameCamera == null ? FlxG.camera : gameCamera;
		this.hudCamera = hudCamera;
		gameBaseZoom = this.gameCamera == null ? 1 : this.gameCamera.zoom;
		hudBaseZoom = hudCamera == null ? 1 : hudCamera.zoom;

		for (event in this.events)
		{
			if (isCameraFocusEvent(event.name))
			{
				hasCameraFocusEvents = true;
				break;
			}
		}
	}

	public function update(songTime:Float):Void
	{
		while (nextEventIndex < events.length && events[nextEventIndex].time <= songTime)
		{
			var event = events[nextEventIndex++];
			processedEvents++;
			dispatch(event);
		}
	}

	public function bumpCamera(amount:Float = DEFAULT_ZOOM_AMOUNT, ?camera:FlxCamera):Void
	{
		if (camera == null)
			camera = gameCamera;

		if (camera == null)
			return;

		var baseZoom = camera == hudCamera ? hudBaseZoom : gameBaseZoom;
		var target = baseZoom + amount;

		if (zoomTween != null)
			zoomTween.cancel();

		zoomTween = FlxTween.tween(camera, {zoom: target}, ZOOM_IN_TIME, {
			ease: FlxEase.quadOut,
			onComplete: function(_):Void
			{
				zoomTween = FlxTween.tween(camera, {zoom: baseZoom}, ZOOM_OUT_TIME, {ease: FlxEase.quadIn});
			}
		});
	}

	public function destroy():Void
	{
		if (focusTween != null)
		{
			focusTween.cancel();
			focusTween = null;
		}

		if (zoomTween != null)
		{
			zoomTween.cancel();
			zoomTween = null;
		}

		events = [];
	}

	function dispatch(event:ChartEvent):Void
	{
		switch (normalizeName(event.name))
		{
			case "cameramovement", "focuschange":
				handleCameraMovement(event);
			case "camerazoom", "zoomcamera":
				handleCameraZoom(event);
			case "addcamerazoom":
				handleCameraBump(event, DEFAULT_ZOOM_AMOUNT);
			case "camerabop":
				handleCameraBump(event, 0.1);
			case "cameraflash", "flashcamera":
				handleCameraFlash(event);
		}
	}

	function handleCameraMovement(event:ChartEvent):Void
	{
		var params = event.params;
		var side = sideFromValue(param(params, 0));

		if (side < 0)
			return;

		var second = param(params, 1);

		if (second != null && !Std.isOfType(second, Bool) && isNumeric(second))
		{
			var duration = secondsDuration(numberValue(second, FOCUS_TIME));
			var ease = easeFromString(stringValue(param(params, 2), "cube"), stringValue(param(params, 3), "InOut"));
			setCameraFocus(side, duration, ease, true, numberValue(param(params, 4), 0), numberValue(param(params, 5), 0));
			return;
		}

		var tweenMovement = boolValue(second, true);
		var easeName = stringValue(param(params, 3), "CLASSIC");
		var easeMode = stringValue(param(params, 4), "In");
		var duration = easeName.toLowerCase() == "classic" ? FOCUS_TIME : stepsToSeconds(numberValue(param(params, 2), DEFAULT_STEPS));
		var ease = easeFromString(easeName, easeMode);
		setCameraFocus(side, duration, ease, tweenMovement, numberValue(param(params, 5), 0), numberValue(param(params, 6), 0));
	}

	function handleCameraZoom(event:ChartEvent):Void
	{
		var params = event.params;

		if (params.length > 0 && Std.isOfType(params[0], Bool))
		{
			var tweenZoom = boolValue(params[0], true);
			var target = numberValue(param(params, 1), 1);
			var camera = cameraFor(stringValue(param(params, 2), "camGame"));
			var steps = numberValue(param(params, 3), DEFAULT_STEPS);
			var easeName = stringValue(param(params, 4), "CLASSIC");
			var easeMode = stringValue(param(params, 5), "In");

			if (boolValue(param(params, 7), false) && camera != null)
				target *= camera.zoom;

			var duration = tweenZoom ? stepsToSeconds(steps) : 0;
			setCameraZoom(camera, target, duration, easeFromString(easeName, easeMode));
			return;
		}

		var camera = cameraFor(stringValue(param(params, 2), "camGame"));
		var target = numberValue(param(params, 0), camera == null ? gameBaseZoom : camera.zoom);
		var duration = isNumeric(param(params, 1)) ? secondsDuration(numberValue(param(params, 1), FOCUS_TIME)) : stepsToSeconds(DEFAULT_STEPS);
		var ease = easeFromString(stringValue(param(params, 3), "quad"), stringValue(param(params, 4), "InOut"));
		setCameraZoom(camera, target, duration, ease);
	}

	function handleCameraBump(event:ChartEvent, defaultAmount:Float):Void
	{
		var amount = numberValue(param(event.params, 0), defaultAmount);
		var camera = cameraFor(stringValue(param(event.params, 1), "camGame"));
		bumpCamera(amount, camera);
	}

	function handleCameraFlash(event:ChartEvent):Void
	{
		var params = event.params;
		var reversed = false;
		var color = FlxColor.WHITE;
		var duration = DEFAULT_FLASH_TIME;
		var cameraName = "camHUD";

		if (params.length > 0 && Std.isOfType(params[0], Bool))
		{
			reversed = boolValue(params[0], false);
			color = colorValue(param(params, 1), FlxColor.WHITE);
			duration = stepsToSeconds(numberValue(param(params, 2), DEFAULT_STEPS));
			cameraName = stringValue(param(params, 3), "camHUD");
		}
		else if (isNumeric(param(params, 0)))
		{
			duration = secondsDuration(numberValue(param(params, 0), DEFAULT_FLASH_TIME));
			color = colorValue(param(params, 1), FlxColor.WHITE);
			cameraName = stringValue(param(params, 2), "camHUD");
		}
		else
		{
			color = colorValue(param(params, 0), FlxColor.WHITE);
			duration = secondsDuration(numberValue(param(params, 1), DEFAULT_FLASH_TIME));
			cameraName = stringValue(param(params, 2), "camHUD");
		}

		var camera = cameraFor(cameraName);

		if (camera == null)
			return;

		if (reversed)
			camera.fade(color, duration, false, function():Void
			{
				camera.stopFX();
			}, true);
		else
			camera.flash(color, duration, null, true);
	}

	function setCameraFocus(side:Int, duration:Float, ease:Float->Float, tweenMovement:Bool, offsetX:Float, offsetY:Float):Void
	{
		if (gameCamera == null)
			return;

		var targetX = (side == 1 ? 1 : -1) * FlxG.width * FOCUS_SHIFT + offsetX;
		var targetY = offsetY;

		if (focusTween != null)
		{
			focusTween.cancel();
			focusTween = null;
		}

		if (!tweenMovement || duration <= 0)
		{
			gameCamera.scroll.set(targetX, targetY);
			return;
		}

		focusTween = FlxTween.tween(gameCamera.scroll, {x: targetX, y: targetY}, duration, {ease: ease});
	}

	function setCameraZoom(camera:FlxCamera, target:Float, duration:Float, ease:Float->Float):Void
	{
		if (camera == null)
			return;

		if (zoomTween != null)
		{
			zoomTween.cancel();
			zoomTween = null;
		}

		if (camera == gameCamera)
			gameBaseZoom = target;
		else if (camera == hudCamera)
			hudBaseZoom = target;

		if (duration <= 0)
		{
			camera.zoom = target;
			return;
		}

		zoomTween = FlxTween.tween(camera, {zoom: target}, duration, {ease: ease});
	}

	function cameraFor(name:String):FlxCamera
	{
		if (name != null && name.toLowerCase().indexOf("hud") >= 0)
			return hudCamera == null ? gameCamera : hudCamera;

		return gameCamera;
	}

	function stepsToSeconds(steps:Float):Float
	{
		if (bpm <= 0 || steps <= 0)
			return FOCUS_TIME;

		return Math.max(0.001, steps * (60000.0 / bpm / 4.0) / 1000.0);
	}

	static function secondsDuration(value:Float):Float
	{
		if (value > 10)
			value /= 1000;

		return Math.max(0.001, value);
	}

	static function isCameraFocusEvent(name:String):Bool
	{
		var normalized = normalizeName(name);
		return normalized == "cameramovement" || normalized == "focuschange";
	}

	static function normalizeName(name:String):String
	{
		if (name == null)
			return "";

		return StringTools.replace(StringTools.replace(StringTools.replace(name.toLowerCase(), " ", ""), "_", ""), "-", "");
	}

	static function sideFromValue(value:Dynamic):Int
	{
		if (value == null)
			return -1;

		if (Std.isOfType(value, Bool))
			return (cast value : Bool) ? 1 : 0;

		var side = numberValue(value, -1);
		return side >= 1 ? 1 : (side == 0 ? 0 : -1);
	}

	static function easeFromString(name:String, mode:String):Float->Float
	{
		var easeName = name == null ? "cube" : name.toLowerCase();
		var easeMode = mode == null ? "in" : mode.toLowerCase();

		if (easeName == "classic")
			return FlxEase.cubeInOut;
		if (easeName == "linear")
			return FlxEase.linear;

		var suffix = easeMode == "out" ? "Out" : (easeMode == "inout" ? "InOut" : "In");

		return switch (easeName + suffix)
		{
			case "backIn": FlxEase.backIn;
			case "backOut": FlxEase.backOut;
			case "backInOut": FlxEase.backInOut;
			case "bounceIn": FlxEase.bounceIn;
			case "bounceOut": FlxEase.bounceOut;
			case "bounceInOut": FlxEase.bounceInOut;
			case "circIn": FlxEase.circIn;
			case "circOut": FlxEase.circOut;
			case "circInOut": FlxEase.circInOut;
			case "cubeIn": FlxEase.cubeIn;
			case "cubeOut": FlxEase.cubeOut;
			case "cubeInOut": FlxEase.cubeInOut;
			case "elasticIn": FlxEase.elasticIn;
			case "elasticOut": FlxEase.elasticOut;
			case "elasticInOut": FlxEase.elasticInOut;
			case "expoIn": FlxEase.expoIn;
			case "expoOut": FlxEase.expoOut;
			case "expoInOut": FlxEase.expoInOut;
			case "quadIn": FlxEase.quadIn;
			case "quadOut": FlxEase.quadOut;
			case "quadInOut": FlxEase.quadInOut;
			case "quartIn": FlxEase.quartIn;
			case "quartOut": FlxEase.quartOut;
			case "quartInOut": FlxEase.quartInOut;
			case "quintIn": FlxEase.quintIn;
			case "quintOut": FlxEase.quintOut;
			case "quintInOut": FlxEase.quintInOut;
			case "sineIn": FlxEase.sineIn;
			case "sineOut": FlxEase.sineOut;
			case "sineInOut": FlxEase.sineInOut;
			case "smoothstepIn": FlxEase.smoothStepIn;
			case "smoothstepOut": FlxEase.smoothStepOut;
			case "smoothstepInOut": FlxEase.smoothStepInOut;
			case "smootherstepIn": FlxEase.smootherStepIn;
			case "smootherstepOut": FlxEase.smootherStepOut;
			case "smootherstepInOut": FlxEase.smootherStepInOut;
			default: FlxEase.cubeInOut;
		};
	}

	static function colorValue(value:Dynamic, fallback:FlxColor):FlxColor
	{
		if (value == null)
			return fallback;

		if (Std.isOfType(value, Int))
			return FlxColor.fromInt(cast value);

		if (Std.isOfType(value, Float))
			return FlxColor.fromInt(Std.int(cast value));

		var text = Std.string(value);
		var parsed = FlxColor.fromString(text);

		if (parsed != null)
			return parsed;

		var parsedInt = Std.parseInt(text);
		return parsedInt == null ? fallback : FlxColor.fromInt(parsedInt);
	}

	static function param(params:Array<Dynamic>, index:Int):Dynamic
	{
		return params != null && index >= 0 && index < params.length ? params[index] : null;
	}

	static function isNumeric(value:Dynamic):Bool
	{
		return Std.isOfType(value, Int) || Std.isOfType(value, Float);
	}

	static function numberValue(value:Dynamic, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
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

	static function compareEvents(a:ChartEvent, b:ChartEvent):Int
	{
		if (a.time < b.time)
			return -1;
		if (a.time > b.time)
			return 1;

		return 0;
	}
}
